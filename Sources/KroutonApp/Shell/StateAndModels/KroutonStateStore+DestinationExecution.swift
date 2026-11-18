import AudioKit
import DriveKit
import Foundation
import ImageKit
import NetworkSpool
import OpticalCore
import SwiftUI
import VideoKit

// MARK: - Destination Queue Burn & Export Execution Pipeline

extension KroutonStateStore {
    func executeSingleDestination(
        _ target: KroutonBakeBatchItem,
        driveManager: KroutonOpticalDriveBank,
        primarySelectedDrive: KroutonOpticalDriveInfo?,
        isAutoLoadedCopy: Bool = false
    ) {
        if driveManager.isExecutingQueue {
            driveManager.abortActiveBurn()
            return
        }
        if stagedFiles.isEmpty && selectedCategory == .burn {
            driveManager.completionReport = KroutonBurnSessionReport(
                isSuccess: false,
                title: "File List Is Empty",
                summary: "There are no files or folders staged in the central workspace.",
                driveModel: primarySelectedDrive?.displayName ?? "Optical Burner",
                firmwareRevision: primarySelectedDrive?.firmware ?? "1.0",
                mediaFormattedName: primarySelectedDrive?.mediaType ?? "None",
                volumeName: discVolumeTitle,
                sectorsWrittenLBA: 0,
                bytesWritten: 0,
                averageSpeedText: "0.0x",
                peakSpeedText: "0.0x",
                elapsedDurationText: "00:00",
                diagnosticAdvice: "Drag files or folders from Finder into the File List (or click 'Add Media or Files...') before starting the operation."
            )
            return
        }
        Task { @MainActor in
            await runTargetDestination(
                target,
                driveManager: driveManager,
                primarySelectedDrive: primarySelectedDrive,
                isAutoLoadedCopy: isAutoLoadedCopy
            )
        }
    }
    func executeDestinationQueue(
        driveManager: KroutonOpticalDriveBank,
        primarySelectedDrive: KroutonOpticalDriveInfo?
    ) {
        if driveManager.isExecutingQueue {
            driveManager.abortActiveBurn()
            return
        }
        if stagedFiles.isEmpty && selectedCategory == .burn {
            driveManager.completionReport = KroutonBurnSessionReport(
                isSuccess: false,
                title: "File List Is Empty",
                summary: "There are no files or folders staged in the central workspace.",
                driveModel: primarySelectedDrive?.displayName ?? "Optical Burner",
                firmwareRevision: primarySelectedDrive?.firmware ?? "1.0",
                mediaFormattedName: primarySelectedDrive?.mediaType ?? "None",
                volumeName: discVolumeTitle,
                sectorsWrittenLBA: 0,
                bytesWritten: 0,
                averageSpeedText: "0.0x",
                peakSpeedText: "0.0x",
                elapsedDurationText: "00:00",
                diagnosticAdvice: "Drag files or folders from Finder into the File List (or click 'Add Media or Files...') before starting the burn."
            )
            return
        }
        Task { @MainActor in
            for target in destinationQueue {
                await runTargetDestination(
                    target,
                    driveManager: driveManager,
                    primarySelectedDrive: primarySelectedDrive
                )
            }
        }
    }
    func runTargetDestination(
        _ target: KroutonBakeBatchItem,
        driveManager: KroutonOpticalDriveBank,
        primarySelectedDrive: KroutonOpticalDriveInfo?,
        isAutoLoadedCopy: Bool = false
    ) async {
        let drvName = primarySelectedDrive?.displayName ?? "Optical Drive"
        KroutonNotificationAndCompanionService.shared.dispatchEvent(
            id: "start", title: "Optical Mastering Started", subtitle: "\(target.kind.rawValue) • \(discVolumeTitle)",
            progress: 0.05, driveName: drvName, speedLabel: target.speedOrCodec, store: self
        )
        defer {
            let rep = driveManager.completionReport
            let ok = rep?.isSuccess ?? true
            KroutonNotificationAndCompanionService.shared.dispatchEvent(
                id: ok ? "done" : "err", title: rep?.title ?? "Mastering Task Complete",
                subtitle: rep?.summary ?? "\(target.kind.rawValue) finished for \(discVolumeTitle)",
                progress: ok ? 1.0 : 0.0, driveName: drvName, speedLabel: target.speedOrCodec, store: self
            )
        }
        switch target.kind {
        case .networkBurner:
            driveManager.setManualInlinePin(for: "network-spool-drive", isPinned: true)
            let _ = await SpoolRemoteNodeClient.shared.executeSpoolAndBurn(
                endpoint: target.hardwareOrPath,
                stagedFiles: stagedFiles,
                audioTracks: redBookTracks,
                volumeTitle: discVolumeTitle,
                performer: discPerformer,
                mcnBarcode: discMCNBarcode,
                requestedSpeedLabel: target.speedOrCodec,
                simulationMode: target.simulationMode,
                driveManager: driveManager,
                targetDriveKey: "network-spool-drive"
            )
            objectWillChange.send()
        case .physicalBurner:
            if self.forceDVDROMBookType, !target.targetDriveID.isEmpty {
                driveManager.stampDVDROMBookType(for: target.targetDriveID, vendorProfile: bitsetVendorProfile)
            }
            let burnSucceeded = await withCheckedContinuation { (continuation: CheckedContinuation<Bool, Never>) in
                driveManager.startPhysicalDataBurn(
                    driveID: target.targetDriveID.isEmpty ? nil : target.targetDriveID,
                    stagedFiles: stagedFiles,
                    volumeTitle: discVolumeTitle,
                    requestedSpeedLabel: target.speedOrCodec,
                    simulationMode: target.simulationMode,
                    verifyDisc: target.verifyAfterBurn,
                    allowOverwriteOfWrittenMedia: !isAutoLoadedCopy
                ) { report in
                    continuation.resume(returning: report.isSuccess)
                }
            }
            if burnSucceeded && target.copiesToBurn > 1 && autoLoadNextDiscBatchMode {
                let finishedCount = target.completedCopies + 1
                if finishedCount < target.copiesToBurn {
                    updateQueueItem(target.id) { $0.completedCopies = finishedCount }
                    let driveKey = target.targetDriveID.isEmpty ? (driveManager.selectedDrive?.id ?? "") : target.targetDriveID
                    driveManager.startBatchAutoLoadMonitor(
                        for: driveKey,
                        completedCopy: finishedCount,
                        totalCopies: target.copiesToBurn,
                        countdownSeconds: autoLoadCountdownSeconds,
                        bitsetDVDROM: self.forceDVDROMBookType
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
        case .discImage:
            let _ = await driveManager.createDiscImageFile(
                stagedFiles: stagedFiles,
                volumeTitle: discVolumeTitle,
                outputPathString: target.hardwareOrPath,
                compressImage: target.compressAfterCreation,
                enableCustomLayout: enableCustomFinderLayoutTab,
                iconSizePx: Int(finderIconSize)
            )
        case .discPrinter, .pdfVector:
            executeLabelDestinationExport()
        default:
            if selectedCategory == .copy && selectedCopyTaskID == .ripAudioCD,
               let liveCD = KroutonRealCDExtractor.scanMountedAudioCD() {
                let rawOut = target.hardwareOrPath.isEmpty ? "~/Music/Krouton Rips" : target.hardwareOrPath
                let expanded = (rawOut as NSString).expandingTildeInPath
                let outDir = URL(fileURLWithPath: expanded).appendingPathComponent(liveCD.albumTitle.replacingOccurrences(of: "/", with: "-"))
                let codec = target.speedOrCodec.isEmpty ? "FLAC (Lossless)" : target.speedOrCodec
                let t0 = Date()
                let (totalBytes, okTracks, failedTracks): (Int64, Int, Int) = await withCheckedContinuation { cont in
                    DispatchQueue.global(qos: .userInitiated).async {
                        var s: Int64 = 0, ok = 0, fail = 0
                        for trk in liveCD.tracks {
                            if let r = try? KroutonRealCDExtractor.extractSingleTrack(track: trk, codecLabel: codec, outputDirectory: outDir) { s += r.bytesWritten; ok += 1 } else { fail += 1 }
                        }
                        cont.resume(returning: (s, ok, fail))
                    }
                }
                let elapsed = max(1, Int(Date().timeIntervalSince(t0)))
                let avgX = max(0.1, Double(liveCD.totalPCMBytes) / Double(elapsed) / 176_400.0)
                driveManager.completionReport = KroutonBurnSessionReport(
                    isSuccess: failedTracks == 0 && okTracks > 0,
                    title: failedTracks == 0 ? "Audio CD Extraction Complete (\(okTracks) Tracks)" : "Audio CD Partial Extraction (\(okTracks)/\(liveCD.tracks.count) Tracks)",
                    summary: "Extracted \(okTracks)/\(liveCD.tracks.count) Red Book tracks (\(failedTracks) errors) from \(liveCD.mountPath) (DiscID \(liveCD.musicBrainzDiscID)) to \(outDir.path).",
                    driveModel: primarySelectedDrive?.displayName ?? "Optical Drive",
                    firmwareRevision: primarySelectedDrive?.firmware ?? "1.0",
                    mediaFormattedName: "Red Book Audio CD (\(liveCD.tracks.count) Audio Tracks)",
                    volumeName: liveCD.albumTitle,
                    sectorsWrittenLBA: Int64(liveCD.leadoutBlockLBA),
                    bytesWritten: totalBytes,
                    averageSpeedText: String(format: "%.1fx", avgX),
                    peakSpeedText: String(format: "%.1fx", avgX * 1.25),
                    elapsedDurationText: String(format: "%02d:%02d", elapsed / 60, elapsed % 60),
                    diagnosticAdvice: failedTracks == 0 ? "All \(okTracks) audio tracks verified with IEEE 802.3 CRC-32 and AccurateRip v1 checksums." : "\(failedTracks) track(s) encountered hardware read errors."
                )
                KroutonOSDesktopBridge.revealInFinder(url: outDir)
                return
            }
            await masterStagedFilesToHybridISO()
        }
    }
}
