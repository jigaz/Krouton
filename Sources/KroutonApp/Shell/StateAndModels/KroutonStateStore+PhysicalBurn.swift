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
        var filesToBurn: [KroutonStagedFileEntry]
        var temporaryImageFolder: URL?
        do {
            (filesToBurn, temporaryImageFolder) = try await burnInputFiles()
        } catch {
            driveManager.completionReport = refusalReport(error.localizedDescription, title: "Could Not Prepare the Disc")
            return
        }
        var audioDisc: KroutonAudioBurnDisc?
        // An audio CD is the editor's project rendered to one PCM file per track.
        if activeBurnSupport == .audioCD {
            do {
                let rendered = try await renderAudioTracks()
                audioDisc = audioBurnDisc(rendered.tracks)
                temporaryImageFolder = rendered.folder
                filesToBurn = []
            } catch {
                driveManager.completionReport = refusalReport(error.localizedDescription, title: "Could Not Prepare the Audio CD")
                return
            }
        }
        // Blu-ray video becomes a UDF 2.50 image first; the drive bank then burns that image.
        if activeBurnSupport == .bluRayVideo, case .success(let root) = bluRayVideoRoot() {
            do {
                let image = try await buildBluRayImage(root: root)
                filesToBurn = [KroutonOpticalDriveBank.inspectFileOrFolder(url: image)]
                temporaryImageFolder = image.deletingLastPathComponent()
            } catch {
                driveManager.completionReport = refusalReport(error.localizedDescription, title: "Could Not Build the Blu-ray Image")
                return
            }
        }
        defer { if let temporaryImageFolder { try? FileManager.default.removeItem(at: temporaryImageFolder) } }
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
