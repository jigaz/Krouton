import AudioKit
import DriveKit
import Foundation
import OpticalCore

// MARK: - Burn to a Drive on This Mac

extension KroutonStateStore {
    /// Burns the deck on a local drive. Audio CDs are rendered from the editor's project and
    /// Blu-ray video becomes a UDF 2.50 image first; everything else goes to the drive bank as
    /// staged. A burn that finishes advances the burn pool and, with auto-load on, waits for the
    /// next blank.
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
        let burnSucceeded = await withCheckedContinuation { (continuation: CheckedContinuation<Bool, Never>) in
            driveManager.startPhysicalDataBurn(
                driveID: target.targetDriveID.isEmpty ? nil : target.targetDriveID,
                stagedFiles: filesToBurn,
                volumeTitle: discVolumeTitle,
                requestedSpeedLabel: target.speedOrCodec,
                simulationMode: target.simulationMode,
                verifyDisc: target.verifyAfterBurn,
                allowOverwriteOfWrittenMedia: !isAutoLoadedCopy,
                leaveDiscOpen: self.leaveDiscOpenForMoreSessions,
                audioDisc: audioDisc,
                isoLevel1: activeBurnSupport != nil && activeFormatSpec().formatID == .dataRetroISO
            ) { report in
                continuation.resume(returning: report.isSuccess)
            }
        }
        if burnSucceeded && (!waitingBurnPool.isEmpty || target.assignedPoolTicket != nil) {
            let nextTicket = advancePoolAfterCardBurnCompleted(cardID: target.id)
            if let nextTicket, poolDispatchMode == .autoAssign, autoLoadNextDiscBatchMode {
                let driveKey = target.targetDriveID.isEmpty ? (driveManager.selectedDrive?.id ?? "") : target.targetDriveID
                notifyInsertNextBlank()
            driveManager.startBatchAutoLoadMonitor(
                    for: driveKey,
                    completedCopy: max(1, nextTicket.sequenceNumber - 1),
                    totalCopies: max(nextTicket.totalCopies, nextTicket.totalSpannedDiscs),
                    countdownSeconds: autoLoadCountdownSeconds
                ) { [weak self] in
                    guard let self = self else { return }
                    if let updatedItem = self.destinationQueue.first(where: { $0.id == target.id }) {
                        self.executeSingleDestination(
                            updatedItem,
                            driveManager: driveManager,
                            primarySelectedDrive: primarySelectedDrive,
                            isAutoLoadedCopy: true
                        )
                    }
                }
            }
        } else if burnSucceeded && target.copiesToBurn > 1 && autoLoadNextDiscBatchMode {
            let finishedCount = target.completedCopies + 1
            if finishedCount < target.copiesToBurn {
                updateQueueItem(target.id) { $0.completedCopies = finishedCount }
                let driveKey = target.targetDriveID.isEmpty ? (driveManager.selectedDrive?.id ?? "") : target.targetDriveID
                notifyInsertNextBlank()
            driveManager.startBatchAutoLoadMonitor(
                    for: driveKey,
                    completedCopy: finishedCount,
                    totalCopies: target.copiesToBurn,
                    countdownSeconds: autoLoadCountdownSeconds
                ) { [weak self] in
                    guard let self = self else { return }
                    if let updatedItem = self.destinationQueue.first(where: { $0.id == target.id }) {
                        self.executeSingleDestination(
                            updatedItem,
                            driveManager: driveManager,
                            primarySelectedDrive: primarySelectedDrive,
                            isAutoLoadedCopy: true
                        )
                    }
                }
            } else {
                updateQueueItem(target.id) { $0.completedCopies = 0 }
            }
        }
    }

    /// Auto-Load has ejected a finished copy and waits for the next blank.
    private func notifyInsertNextBlank() {
        KroutonNotificationAndCompanionService.shared.dispatchEvent(
            id: "swap", title: "Insert the Next Blank",
            subtitle: "\(discVolumeTitle) finished; the next copy starts when a blank goes in.", store: self)
    }

    /// Says so before a write that can't fit on the blank in the drive, as reported by the drive.
    /// A disc image needs its own size; files need a little more for the file systems.
    /// Nothing is said when the drive hasn't reported its free space (the bank's 4.7 GB and
    /// 737 MB fallbacks are guesses, not measurements).
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
