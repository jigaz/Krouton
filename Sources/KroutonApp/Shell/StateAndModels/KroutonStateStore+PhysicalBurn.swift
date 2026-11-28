import AudioKit
import BurnKit
import DriveKit
import Foundation
import OpticalCore

// MARK: - Burn to a Drive on This Mac

extension KroutonStateStore {
    /// Burns the deck on a local drive. Audio CDs are rendered from the editor's project and
    /// Blu-ray video becomes a UDF 2.50 image first; everything else goes to the drive bank as
    /// staged. `KroutonBurnCoordinator` runs the burn and decides what follows: the card's next
    /// pool ticket or copy and, with Auto-Load on, waiting for the next blank.
    func runPhysicalBurn(
        _ target: KroutonBakeBatchItem,
        driveManager: KroutonOpticalDriveBank,
        primarySelectedDrive: KroutonOpticalDriveInfo?,
        isAutoLoadedCopy: Bool
    ) async {
        // Checked before the image is built: a set holds the drives for as long as it burns.
        if let setTitle = KroutonBurnCoordinator.shared.runningSetTitle {
            driveManager.completionReport = refusalReport(
                "The multi-disc set \(setTitle) is burning on this Mac's drives. Wait for it to finish, or stop it, then burn again. Nothing was written.",
                title: "Burners in Use")
            return
        }
        // Building an image can take many minutes; the bank shows it as busy, so Abort works then too.
        let abortCount = driveManager.beginPreparingBurn("Preparing \(discVolumeTitle) for the Disc...")
        let prepared = await preparePhysicalBurn(driveManager: driveManager)
        driveManager.endPreparingBurn(since: abortCount)
        guard let prepared else { return }
        defer { if let folder = prepared.temporaryFolder { try? FileManager.default.removeItem(at: folder) } }
        if driveManager.abortRequestCount != abortCount {
            driveManager.completionReport = refusalReport(
                "The burn was stopped while the disc was being prepared. Nothing was written.", title: "Burn Aborted")
            return
        }
        // The drives weren't polled while the bank was busy; the blank may have been swapped.
        driveManager.refreshDrives()
        let filesToBurn = prepared.files
        let audioDisc = prepared.audioDisc
        if audioDisc == nil, let tooBig = discTooSmallMessage(filesToBurn, driveID: target.targetDriveID, driveManager: driveManager) {
            driveManager.completionReport = refusalReport(tooBig, title: "Too Big for This Disc")
            return
        }
        if let audioDisc, !audioDisc.dataSessionFiles.isEmpty,
           let tooBig = cdExtraTooBigMessage(audioDisc, driveID: target.targetDriveID, driveManager: driveManager) {
            driveManager.completionReport = refusalReport(tooBig, title: "Too Big for This Disc")
            return
        }
        let request = KroutonLocalBurnRequest(
            driveID: target.targetDriveID.isEmpty ? nil : target.targetDriveID,
            stagedFiles: filesToBurn,
            volumeTitle: discVolumeTitle,
            speedLabel: target.speedOrCodec,
            simulationMode: target.simulationMode,
            verifyDisc: target.verifyAfterBurn,
            allowOverwriteOfWrittenMedia: !isAutoLoadedCopy,
            leaveDiscOpen: self.leaveDiscOpenForMoreSessions,
            audioDisc: audioDisc,
            isoLevel1: activeBurnSupport != nil && activeFormatSpec().formatID == .dataRetroISO)
        let report = await KroutonBurnCoordinator.shared.burnOnThisMac(request, bank: driveManager)
        let step = withBurnPool { pool in
            KroutonBurnCoordinator.stepAfterBurn(
                of: target, copiesToBurn: target.copiesToBurn, succeeded: report.isSuccess, pool: &pool,
                mode: self.poolDispatchMode, autoLoadNextDisc: self.autoLoadNextDiscBatchMode)
        }
        guard case .waitForNextBlank(let completedCopy, let totalCopies) = step else { return }
        let driveKey = target.targetDriveID.isEmpty ? (driveManager.selectedDrive?.id ?? "") : target.targetDriveID
        notifyInsertNextBlank(driveName: driveManager.availableDrives.first { $0.id == driveKey }?.displayName ?? "Optical Drive")
        driveManager.startBatchAutoLoadMonitor(
            for: driveKey,
            completedCopy: completedCopy,
            totalCopies: totalCopies,
            countdownSeconds: autoLoadCountdownSeconds
        ) { [weak self] in
            guard let self, let updatedItem = self.destinationQueue.first(where: { $0.id == target.id }) else { return }
            self.executeSingleDestination(
                updatedItem,
                driveManager: driveManager,
                primarySelectedDrive: primarySelectedDrive,
                isAutoLoadedCopy: true
            )
        }
    }

    /// What a local burn writes, built from the deck: the files (or one image), or an audio CD's
    /// rendered tracks. Blu-ray video becomes a UDF 2.50 image first. On failure it says why in
    /// the bank's report, removes what it made and returns nil.
    private func preparePhysicalBurn(driveManager: KroutonOpticalDriveBank) async -> PreparedPhysicalBurn? {
        var prepared: PreparedPhysicalBurn
        do {
            let input = try await burnInputFiles()
            prepared = PreparedPhysicalBurn(files: input.files, audioDisc: nil, temporaryFolder: input.folder)
        } catch {
            driveManager.completionReport = refusalReport(error.localizedDescription, title: "Could Not Prepare the Disc")
            return nil
        }
        let removeInputFolder = { [folder = prepared.temporaryFolder] in
            if let folder { try? FileManager.default.removeItem(at: folder) }
        }
        // An audio CD is the editor's project rendered to one PCM file per track.
        if activeBurnSupport == .audioCD {
            do {
                let rendered = try await renderAudioTracks()
                removeInputFolder()
                prepared = PreparedPhysicalBurn(files: [], audioDisc: audioBurnDisc(rendered.tracks), temporaryFolder: rendered.folder)
            } catch {
                removeInputFolder()
                driveManager.completionReport = refusalReport(error.localizedDescription, title: "Could Not Prepare the Audio CD")
                return nil
            }
        }
        // Blu-ray video becomes a UDF 2.50 image first; the drive bank then burns that image.
        if activeBurnSupport == .bluRayVideo, case .success(let root) = bluRayVideoRoot() {
            do {
                let image = try await buildBluRayImage(root: root)
                removeInputFolder()
                prepared = PreparedPhysicalBurn(files: [KroutonOpticalDriveBank.inspectFileOrFolder(url: image)], audioDisc: nil,
                                                temporaryFolder: image.deletingLastPathComponent())
            } catch {
                removeInputFolder()
                driveManager.completionReport = refusalReport(error.localizedDescription, title: "Could Not Build the Blu-ray Image")
                return nil
            }
        }
        return prepared
    }

    /// Auto-Load has ejected a finished copy and waits for the next blank.
    private func notifyInsertNextBlank(driveName: String) {
        KroutonNotificationAndCompanionService.shared.dispatchEvent(
            id: "swap", title: "Insert the Next Blank",
            subtitle: "\(discVolumeTitle) finished; the next copy starts when a blank goes in.",
            driveName: driveName, store: self)
    }

    /// Says so before a write that can't fit on the blank in the drive, as reported by the drive.
    /// A disc image needs its own size; files need a little more for the file systems.
    /// Nothing is said when the drive hasn't reported its free space (the bank's 4.7 GB and
    /// 737 MB fallbacks are guesses, not measurements).
    /// CD-Extra: the audio, the second session's overhead and the data against the blank's
    /// room (80 minutes when the drive doesn't say).
    private func cdExtraTooBigMessage(_ disc: KroutonAudioBurnDisc, driveID: String,
                                      driveManager: KroutonOpticalDriveBank) -> String? {
        let drive = driveManager.availableDrives.first { $0.id == driveID } ?? driveManager.selectedDrive
        let known = drive.map { $0.isMediaBlank && $0.freeBytes > 0 && $0.freeBytes != 736_966_656 } ?? false
        let capacityFrames = known ? (drive?.freeBytes ?? 0) / 2_048 : 360_000
        return KroutonCDExtraLayout.overflowMessage(
            audioFrames: disc.totalFrames, dataBytes: cdExtraDataFiles.reduce(0) { $0 + $1.byteSize },
            capacityFrames: capacityFrames)
    }

    private func discTooSmallMessage(_ files: [KroutonStagedFileEntry], driveID: String,
                                     driveManager: KroutonOpticalDriveBank) -> String? {
        let drive = driveManager.availableDrives.first { $0.id == driveID } ?? driveManager.selectedDrive
        guard let drive, drive.isMediaPresent, drive.isMediaBlank, drive.freeBytes > 0,
              ![4_700_372_992, 736_966_656].contains(drive.freeBytes) else { return nil }
        let content = files.reduce(Int64(0)) { $0 + $1.byteSize }
        let isImage = KroutonOpticalDriveBank.soleDiscImage(in: files) != nil
        let needed = isImage ? content : content + content / 50 + 4_194_304
        guard needed > drive.freeBytes else { return nil }
        let format = { (n: Int64) in ByteCountFormatter.string(fromByteCount: n, countStyle: .file) }
        return "This needs about \(format(needed)), and the \(drive.mediaType) in the drive holds \(format(drive.freeBytes)). Use a larger disc (BD-R XL holds 100 or 128 GB) or split the files into a disc set. Nothing was written."
    }
}

// MARK: - Prepared Input

/// What `preparePhysicalBurn` built; `temporaryFolder` is removed after the burn.
private struct PreparedPhysicalBurn {
    var files: [KroutonStagedFileEntry]
    var audioDisc: KroutonAudioBurnDisc?
    var temporaryFolder: URL?
}
