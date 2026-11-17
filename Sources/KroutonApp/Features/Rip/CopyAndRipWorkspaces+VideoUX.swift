import Foundation
import OpticalCore
import SwiftUI
import VideoKit

// MARK: - CopyAndRipWorkspaces — VideoUX

extension KroutonCopyAndRipWorkspaceView {
    func promptForCopySourceOrFolder(isAudioRipTask: Bool, isShrinkTask: Bool) {
        KroutonStageImporterBridge.shared.presentImporter(allowedTypes: [.folder], allowsMultiple: false) { urls in
            guard let url = urls.first else { return }
            let fm = FileManager.default
            if fm.fileExists(atPath: url.appendingPathComponent(".TOC.plist").path) {
                copySourceOverrideLabel = url.path
                rescanOpticalDiscForCopyTask(isAudioRipTask: true, isShrinkTask: false, fetchMetadata: true)
            } else if !isAudioRipTask && (
                url.lastPathComponent.uppercased() == "VIDEO_TS" ||
                url.lastPathComponent.uppercased() == "BDMV" ||
                fm.fileExists(atPath: url.appendingPathComponent("VIDEO_TS").path) ||
                fm.fileExists(atPath: url.appendingPathComponent("BDMV").path) ||
                url.path.hasPrefix("/Volumes/")
            ) {
                copySourceOverrideLabel = url.path
                rescanOpticalDiscForCopyTask(isAudioRipTask: false, isShrinkTask: isShrinkTask, fetchMetadata: false)
            } else {
                copyOutputFolderPath = url.path
                copyStatusBanner = "Output folder set to \(url.path)"
            }
        }
    }

    func startVideoOrDiscExtraction(isShrinkTask: Bool) {
        guard !isRippingCD else { return }
        let disc = scannedVideoDisc ?? OpticalDiscVolumeScanner.scanMountedVideoOrDataDisc(preferredPath: copySourceOverrideLabel)
        guard let activeDisc = disc else {
            copyStatusBanner = "Insert a Video/Data disc or click 'Folder...' to select a VIDEO_TS, BDMV, or volume directory first."
            return
        }
        scannedVideoDisc = activeDisc

        let token = KroutonRipCancelToken()
        ripCancelToken = token
        isRippingCD = true
        ripProgressFraction = 0.02

        if isShrinkTask {
            let destDir = URL(fileURLWithPath: ("~/Desktop" as NSString).expandingTildeInPath)
            let safeName = activeDisc.volumeTitle.replacingOccurrences(of: " ", with: "_")
            let isoURL = destDir.appendingPathComponent("\(safeName).iso")
            let shouldShrink = store.fitToDiscDVD9Shrink && activeDisc.totalBytes > 4_700_000_000 && activeDisc.discKind.contains("VIDEO_TS")
            let preserveMenus = store.preserveMenusAndExtras
            copyStatusBanner = shouldShrink
                ? "Requantizing DVD-9 -> DVD-5 and building \(isoURL.lastPathComponent)..."
                : "Building 1:1 Hybrid UDF/ISO image \(isoURL.lastPathComponent)..."

            Task.detached(priority: .userInitiated) {
                do {
                    var sourceToImage = URL(fileURLWithPath: activeDisc.mountPath)
                    var tempShrinkRoot: URL? = nil
                    if shouldShrink {
                        let tmp = FileManager.default.temporaryDirectory.appendingPathComponent("KroutonDVDShrink_\(UUID().uuidString)")
                        tempShrinkRoot = tmp
                        let vtsIn = URL(fileURLWithPath: activeDisc.mountPath).appendingPathComponent("VIDEO_TS")
                        let vtsOut = tmp.appendingPathComponent("VIDEO_TS")
                        _ = try KroutonVideoAuthoringEngine.executeDVD9ToDVD5ShrinkOnDisk(
                            sourceVideoTSDirectory: FileManager.default.fileExists(atPath: vtsIn.path) ? vtsIn : URL(fileURLWithPath: activeDisc.mountPath),
                            outputVideoTSDirectory: vtsOut,
                            preserveMenus: preserveMenus
                        )
                        sourceToImage = tmp
                    }
                    defer {
                        if let tmp = tempShrinkRoot { try? FileManager.default.removeItem(at: tmp) }
                    }
                    let writtenBytes = try OpticalDiscVolumeScanner.buildOpticalISOImage(
                        sourceDirectory: sourceToImage,
                        outputISOURL: isoURL,
                        volumeName: activeDisc.volumeTitle
                    )
                    let sizeStr = ByteCountFormatter.string(fromByteCount: writtenBytes, countStyle: .file)
                    await MainActor.run {
                        isRippingCD = false
                        ripProgressFraction = 1.0
                        copyStatusBanner = "Created \(isoURL.path) (\(sizeStr))"
                    }
                } catch {
                    await MainActor.run {
                        isRippingCD = false
                        ripProgressFraction = 0.0
                        copyStatusBanner = "ISO Creation Failed: \(error.localizedDescription)"
                    }
                }
            }
        } else {
            let selectedIDs = videoExtractSelectedTitles
            let chosenTitles = activeDisc.titles.filter { selectedIDs.contains($0.id) && $0.seconds >= videoExtractMinSeconds }
            guard !chosenTitles.isEmpty else {
                isRippingCD = false
                copyStatusBanner = "Select at least one video title to extract."
                return
            }
            let outRoot = URL(fileURLWithPath: ("~/Movies/Krouton Extracts" as NSString).expandingTildeInPath)
                .appendingPathComponent(activeDisc.volumeTitle.replacingOccurrences(of: "/", with: "_"))
            copyStatusBanner = "Extracting \(chosenTitles.count) title(s) from \(activeDisc.volumeTitle)..."

            Task.detached(priority: .userInitiated) {
                var extractedCount = 0
                var totalWritten: Int64 = 0
                let countD = Double(chosenTitles.count)
                for (idx, item) in chosenTitles.enumerated() {
                    if token.isCancelled { break }
                    guard let segments = activeDisc.titleSegmentURLs[item.id], !segments.isEmpty else { continue }
                    do {
                        let res = try OpticalDiscVolumeScanner.extractTitleSegments(
                            titleID: item.id,
                            segments: segments,
                            volumeTitle: activeDisc.volumeTitle,
                            outputDirectory: outRoot,
                            shouldCancel: { token.isCancelled },
                            onProgress: { frac in
                                let overall = (Double(idx) + frac) / countD
                                Task { @MainActor in ripProgressFraction = overall }
                            }
                        )
                        extractedCount += 1
                        totalWritten += res.bytesWritten
                    } catch {
                        break
                    }
                }
                let sizeStr = ByteCountFormatter.string(fromByteCount: totalWritten, countStyle: .file)
                await MainActor.run {
                    isRippingCD = false
                    ripProgressFraction = extractedCount > 0 ? 1.0 : 0.0
                    copyStatusBanner = token.isCancelled
                        ? "Cancelled video extraction."
                        : "Extracted \(extractedCount) Title(s) (\(sizeStr)) to \(outRoot.path)"
                }
            }
        }
    }

}
