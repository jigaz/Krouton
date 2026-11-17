import DriveKit
import AudioKit
import OpticalCore
import SwiftUI
import Foundation

// MARK: - Automatic Right-Column Destination Rack Synchronization for Multi-Disc Spanning

@MainActor
extension KroutonStateStore {

    /// Computes the active spanning disc count & resolved per-disc volume labels across
    /// Audio CD (`audioController.discPlan`) and all staged file/media workspaces (`dataDiscPlan`).
    public func activeSpannedDiscLabels() -> [String] {
        guard selectedCategory == .burn else { return [] }
        let spec = activeFormatSpec()
        if spec.filterGroup == .audio && spec.id != "mp3-cd" {
            let plan = audioController.project.discPlan()
            let total = max(1, plan.discs.count)
            return (1...total).map { dNum in
                let custom = plan.discs.first(where: { $0.number == dNum })?.metadata.volumeLabel
                return DiscSpanningEngine.resolvedDiscVolumeLabel(
                    baseTitle: discVolumeTitle,
                    customTitle: custom,
                    discNumber: dNum,
                    totalDiscs: total,
                    fallback: "AUDIO_CD"
                )
            }
        }
        let plan = dataDiscPlan(forFormatID: spec.id)
        let total = max(1, plan.discs.count)
        let fallback = (selectedTaskID == "dvd-video") ? "DVD_VIDEO" : "KROUTON_DISC"
        return (1...total).map { dNum in
            DiscSpanningEngine.resolvedDiscVolumeLabel(
                baseTitle: discVolumeTitle,
                customTitle: dataDiscVolumeOverrides[dNum],
                discNumber: dNum,
                totalDiscs: total,
                fallback: fallback
            )
        }
    }

    /// Automatically adds, renames, or removes right-column destination cards to match the
    /// active multi-disc spanning plan (`Disc 1`, `Disc 2`, `Disc 3`…).
    public func syncSpannedDestinations(driveManager: KroutonOpticalDriveBank) {
        guard selectedCategory == .burn else { return }
        let labels = activeSpannedDiscLabels()
        let requiredDiscs = max(1, labels.count)
        let baseTarget = defaultDiscImageTarget
        let ext = (baseTarget.path as NSString).pathExtension

        func sanitizedFileStem(_ raw: String) -> String {
            let cleaned = raw.trimmingCharacters(in: .whitespacesAndNewlines).replacingOccurrences(of: " ", with: "_")
            return cleaned.isEmpty ? "KROUTON_DISC" : cleaned
        }

        // 1. Remove any auto-spawned destination cards whose disc number is no longer needed
        destinationQueue.removeAll { item in
            if let dNum = item.spannedDiscNumber, dNum > requiredDiscs {
                return true
            }
            return false
        }

        // 2. Tag Disc 1 on the primary card when multi-disc spanning is active (clear when single-disc)
        if !destinationQueue.isEmpty {
            if requiredDiscs > 1 {
                if destinationQueue[0].spannedDiscNumber == nil {
                    destinationQueue[0].spannedDiscNumber = 1
                }
            } else if destinationQueue[0].spannedDiscNumber == 1 {
                destinationQueue[0].spannedDiscNumber = nil
            }
        }

        // 3. Ensure every spanned disc 2...requiredDiscs has a destination card in the right column
        if requiredDiscs > 1 {
            let templateKind = destinationQueue.first?.kind ?? .discImage
            for dNum in 2...requiredDiscs {
                if !destinationQueue.contains(where: { $0.spannedDiscNumber == dNum }) {
                    let stem = sanitizedFileStem(labels[dNum - 1])
                    let usedDriveIDs = Set(destinationQueue.filter { $0.kind == .physicalBurner }.map(\.targetDriveID))
                    if templateKind == .physicalBurner,
                       let freeDrive = driveManager.availableDrives.first(where: { !usedDriveIDs.contains($0.id) }) {
                        destinationQueue.append(
                            KroutonBakeBatchItem(
                                kind: .physicalBurner,
                                targetDriveID: freeDrive.id,
                                hardwareOrPath: freeDrive.displayName,
                                speedOrCodec: "Max Safe (Auto)",
                                simulationMode: false,
                                verifyAfterBurn: true,
                                compressAfterCreation: false,
                                spannedDiscNumber: dNum
                            )
                        )
                    } else {
                        destinationQueue.append(
                            KroutonBakeBatchItem(
                                kind: .discImage,
                                targetDriveID: "",
                                hardwareOrPath: "~/Desktop/\(stem).\(ext)",
                                speedOrCodec: baseTarget.description,
                                simulationMode: false,
                                verifyAfterBurn: true,
                                compressAfterCreation: false,
                                spannedDiscNumber: dNum
                            )
                        )
                    }
                }
            }
        }

        // 4. Keep all spanned .discImage paths & descriptions synchronized with current disc labels
        for idx in destinationQueue.indices {
            let dNum = destinationQueue[idx].spannedDiscNumber ?? (idx == 0 ? 1 : nil)
            if destinationQueue[idx].kind == .discImage, let dNum, dNum >= 1, dNum <= labels.count {
                let currentPath = destinationQueue[idx].hardwareOrPath
                let dir = (currentPath as NSString).deletingLastPathComponent
                let baseDir = dir.isEmpty ? "~/Desktop" : dir
                let stem = sanitizedFileStem(labels[dNum - 1])
                destinationQueue[idx].hardwareOrPath = "\(baseDir)/\(stem).\(ext)"
                destinationQueue[idx].speedOrCodec = baseTarget.description
            }
        }

        // Sort spanned cards in ascending disc order while keeping unspanned extra cards intact
        destinationQueue.sort { lhs, rhs in
            switch (lhs.spannedDiscNumber, rhs.spannedDiscNumber) {
            case let (a?, b?): return a < b
            case (_?, nil):    return true
            case (nil, _?):    return false
            case (nil, nil):   return false
            }
        }
        savedQueuesByDomain[currentDestinationDomainKey] = destinationQueue
    }
}
