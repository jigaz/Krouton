import AudioKit
import DriveKit
import Foundation
import NetworkSpool
import OpticalCore
import SwiftUI

// MARK: - Destination Queue Burn & Export Execution Pipeline

extension KroutonStateStore {
    func executeSingleDestination(
        _ target: KroutonBakeBatchItem,
        driveManager: KroutonOpticalDriveBank,
        primarySelectedDrive: KroutonOpticalDriveInfo?,
        isAutoLoadedCopy: Bool = false
    ) {
        if driveManager.isExecutingQueue {
            guard !isAutoLoadedCopy else { return }
            driveManager.abortActiveBurn()
            return
        }
        if stagedFiles.isEmpty && selectedCategory == .burn {
            driveManager.completionReport = KroutonBurnSessionReport(
                isSuccess: false,
                title: "File List Is Empty",
                summary: "There are no files or folders staged in the central workspace.",
                driveModel: primarySelectedDrive?.displayName ?? "Optical Burner",
                firmwareRevision: primarySelectedDrive?.firmware ?? "—",
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
                firmwareRevision: primarySelectedDrive?.firmware ?? "—",
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
            id: "start", title: "Optical Mastering Started", subtitle: "\(target.kind.title) • \(discVolumeTitle)",
            progress: 0.05, driveName: drvName, speedLabel: target.speedOrCodec, store: self
        )
        defer {
            let rep = driveManager.completionReport
            let ok = rep?.isSuccess ?? true
            KroutonNotificationAndCompanionService.shared.dispatchEvent(
                id: ok ? "done" : "err", title: rep?.title ?? "Mastering Task Complete",
                subtitle: rep?.summary ?? "\(target.kind.title) finished for \(discVolumeTitle)",
                progress: ok ? 1.0 : 0.0, driveName: drvName, speedLabel: target.speedOrCodec, store: self
            )
        }
        // Formats Krouton can't make yet stop here, before anything is staged or written.
        if let refusal = burnRefusal(for: target.kind) {
            driveManager.completionReport = refusalReport(refusal)
            return
        }
        switch target.kind {
        case .networkBurner:
            await runNetworkBurn(target, driveManager: driveManager)
        case .physicalBurner:
            await runPhysicalBurn(target, driveManager: driveManager, primarySelectedDrive: primarySelectedDrive,
                                  isAutoLoadedCopy: isAutoLoadedCopy)
        case .discImage:
            if activeBurnSupport == .audioCD {
                do {
                    let cue = try await saveAudioDiscImage(path: target.hardwareOrPath)
                    driveManager.completionReport = refusalReport(
                        "Wrote \(cue.lastPathComponent) and its .bin: the audio CD as it will play, ready for Burn Disc Image.",
                        title: "Audio CD Image Saved", ok: true)
                } catch {
                    driveManager.completionReport = refusalReport(error.localizedDescription, title: "Could Not Save the Audio CD Image")
                }
                return
            }
            if activeBurnSupport == .bluRayVideo, case .success(let root) = bluRayVideoRoot() {
                let path = NSString(string: target.hardwareOrPath).expandingTildeInPath
                let output = URL(fileURLWithPath: path).pathExtension.lowercased() == "iso"
                    ? URL(fileURLWithPath: path) : URL(fileURLWithPath: path).deletingPathExtension().appendingPathExtension("iso")
                do {
                    let image = try await buildBluRayImage(root: root, output: output)
                    driveManager.completionReport = refusalReport(
                        "Wrote \(image.lastPathComponent): UDF 2.50, ready to burn to a BD-R.", title: "Blu-ray Image Saved", ok: true)
                } catch {
                    driveManager.completionReport = refusalReport(error.localizedDescription, title: "Could Not Build the Blu-ray Image")
                }
                return
            }
            let input: (files: [KroutonStagedFileEntry], folder: URL?)
            do {
                input = try await burnInputFiles()
            } catch {
                driveManager.completionReport = refusalReport(error.localizedDescription, title: "Could Not Prepare the Disc")
                return
            }
            defer { if let folder = input.folder { try? FileManager.default.removeItem(at: folder) } }
            // Large-file UDF and DVD-Video arrive as a finished image from Krouton's writer.
            if [.dataUDFModern, .dvdVideo, .macos9HFS].contains(activeFormatSpec().formatID), let image = input.files.first?.url {
                let path = NSString(string: target.hardwareOrPath).expandingTildeInPath
                let output = URL(fileURLWithPath: path).deletingPathExtension().appendingPathExtension(image.pathExtension)
                do {
                    try? FileManager.default.removeItem(at: output)
                    try FileManager.default.moveItem(at: image, to: output)
                    driveManager.completionReport = refusalReport(
                        "Wrote \(output.lastPathComponent), ready for Burn Disc Image.", title: "Disc Image Saved", ok: true)
                } catch {
                    driveManager.completionReport = refusalReport(error.localizedDescription, title: "Could Not Save the UDF Image")
                }
                return
            }
            let _ = await driveManager.createDiscImageFile(
                stagedFiles: input.files,
                volumeTitle: discVolumeTitle,
                outputPathString: target.hardwareOrPath,
                compressImage: target.compressAfterCreation
            )
        case .discPrinter, .pdfVector:
            executeLabelDestinationExport()
        case .videoExtract:
            // Extraction runs from the workspace, where the titles are chosen; a queue card can't pick them.
            driveManager.completionReport = KroutonBurnSessionReport(
                isSuccess: false, title: "Extract From the Workspace",
                summary: "Choose the titles in the Video Disc Extractor and click Extract. Nothing was written.",
                driveModel: primarySelectedDrive?.displayName ?? "Optical Drive", firmwareRevision: "-",
                mediaFormattedName: "-", volumeName: discVolumeTitle, sectorsWrittenLBA: 0, bytesWritten: 0,
                averageSpeedText: "-", peakSpeedText: "-", elapsedDurationText: "00:00",
                diagnosticAdvice: "See Help › Krouton User Manual › Video, copying and other formats."
            )
        case .audioRip:
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
                    firmwareRevision: primarySelectedDrive?.firmware ?? "—",
                    mediaFormattedName: "Red Book Audio CD (\(liveCD.tracks.count) Audio Tracks)",
                    volumeName: liveCD.albumTitle,
                    sectorsWrittenLBA: Int64(liveCD.leadoutBlockLBA),
                    bytesWritten: totalBytes,
                    averageSpeedText: String(format: "%.1fx", avgX),
                    peakSpeedText: "-",
                    elapsedDurationText: String(format: "%02d:%02d", elapsed / 60, elapsed % 60),
                    diagnosticAdvice: failedTracks == 0
                        ? "All \(okTracks) tracks were read. To check them against AccurateRip, rip from the Audio CD Ripper in Copy."
                        : "\(failedTracks) track(s) couldn't be read. The Audio CD Ripper in Copy retries and checks against AccurateRip."
                )
                KroutonOSDesktopBridge.revealInFinder(url: outDir)
                return
            }
            // Before 2026-11-26 this fell through to building an ISO of the deck in a temporary
            // folder that nothing ever read.
            driveManager.completionReport = refusalReport(
                "Insert an audio CD, choose Rip Audio CD under Copy, then rip again. Nothing was written.",
                title: "No Audio CD to Rip")
        }
    }
}
