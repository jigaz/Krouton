import AudioKit
import DriveKit
import Foundation
import ImageKit
import NetworkSpool
import OpticalCore
import SwiftUI
import VideoKit

// MARK: - Destination Queue Management & Execution Helpers on KroutonStateStore
@MainActor
extension KroutonStateStore {
    func updateQueueItem(_ id: UUID, mutate: @escaping (inout KroutonBakeBatchItem) -> Void) {
        guard let idx = destinationQueue.firstIndex(where: { $0.id == id }) else { return }
        mutate(&destinationQueue[idx])
        savedQueuesByDomain[currentDestinationDomainKey] = destinationQueue
    }
    /// Format-aware Disc Image extension (.cue/.bin for Red Book & Raw CD Consoles, .dmg for macOS HFS+/APFS, .iso for Hybrid/UDF/Video/DVD)
    var defaultDiscImageTarget: (path: String, description: String) {
        let cleanTitle = discVolumeTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? (selectedTaskID == "dvd-video" ? "DVD_VIDEO" : "KROUTON_DISC")
            : discVolumeTitle.replacingOccurrences(of: " ", with: "_")
        if selectedCategory == .copy {
            if selectedTaskID == "copy-rip-audio" {
                return ("~/Music/Krouton Rips/\(cleanTitle).cue", "Red Book .BIN + .CUE Archival Image")
            } else if selectedTaskID == "copy-rip-video" {
                return ("~/Movies/Krouton Extracts/\(cleanTitle).iso", "Decrypted Video .ISO Image")
            }
            return ("~/Desktop/Disc_Backup.iso", "1:1 Archival Sector .ISO Image")
        }
        let spec = activeFormatSpec()
        switch spec.id {
        case "cd-da", "cd-extra", "dts-cd", "cd-g", "console-ps1", "console-saturn", "console-3do", "console-dc":
            return ("~/Desktop/\(cleanTitle).cue", "2,352-Byte Raw .BIN + .CUE Image")
        case "data-apple-apfs", "macos9-hfs":
            return ("~/Desktop/\(cleanTitle).dmg", "Apple HFS+ / APFS Disk Image")
        default:
            return ("~/Desktop/\(cleanTitle).iso", "Sector-Exact .ISO Optical Image")
        }
    }
    /// Strict task-aware allowed destination types (never offer Video Transcode on Audio CD or Burners on Rip tasks!)
    var allowedDestinationsForCurrentCategory: [KroutonBurnDestinationKind] {
        switch selectedCategory {
        case .depot:
            return [.physicalBurner, .networkBurner]
        case .burn:
            if selectedTaskID == "image-burn" {
                return [.physicalBurner, .networkBurner]
            }
            return [.physicalBurner, .networkBurner, .discImage]
        case .copy:
            switch selectedTaskID {
            case "copy-rip-audio", "copy-audio-rip":
                return [.audioRip, .discImage]
            case "copy-rip-video":
                return [.videoExtract, .discImage]
            default: // "copy-duplicate"
                return [.physicalBurner, .networkBurner, .discImage]
            }
        case .label:
            return [.discPrinter, .pdfVector]
        }
    }
    func reconcileUniqueDriveAssignments(driveManager: KroutonOpticalDriveBank) {
        let allowed = allowedDestinationsForCurrentCategory
        var claimedIDs = Set<String>()
        for idx in destinationQueue.indices {
            // 1. If a card's kind is incompatible with the active task, convert it to the task's primary valid kind
            if !allowed.contains(destinationQueue[idx].kind), let fallbackKind = allowed.first {
                destinationQueue[idx].kind = fallbackKind
                switch fallbackKind {
                case .audioRip:
                    destinationQueue[idx].targetDriveID = ""
                    destinationQueue[idx].hardwareOrPath = "~/Music/Krouton Rips/FLAC Lossless"
                    destinationQueue[idx].speedOrCodec = "FLAC (Lossless) + AccurateRip"
                case .videoExtract:
                    destinationQueue[idx].targetDriveID = ""
                    destinationQueue[idx].hardwareOrPath = "~/Movies/Krouton Extracts"
                    destinationQueue[idx].speedOrCodec = "Lossless MKV Remux"
                case .discPrinter:
                    destinationQueue[idx].targetDriveID = ""
                    destinationQueue[idx].hardwareOrPath = ""
                    destinationQueue[idx].speedOrCodec = ""
                case .pdfVector:
                    destinationQueue[idx].targetDriveID = ""
                    destinationQueue[idx].hardwareOrPath = "~/Desktop/\(discVolumeTitle)_Label.pdf"
                    destinationQueue[idx].speedOrCodec = "300 DPI Vector PDF Proof"
                case .discImage:
                    let imgTarget = defaultDiscImageTarget
                    destinationQueue[idx].targetDriveID = ""
                    destinationQueue[idx].hardwareOrPath = imgTarget.path
                    destinationQueue[idx].speedOrCodec = imgTarget.description
                case .networkBurner:
                    destinationQueue[idx].targetDriveID = ""
                    destinationQueue[idx].hardwareOrPath = "localhost:7420"
                    destinationQueue[idx].speedOrCodec = "Max Safe (Auto)"
                case .physicalBurner:
                    break
                }
            }
            // 2. Enforce strict 1-drive-per-card exclusivity across all .physicalBurner cards
            guard destinationQueue[idx].kind == .physicalBurner else { continue }
            guard !driveManager.availableDrives.isEmpty else { continue }
            let currentID = destinationQueue[idx].targetDriveID
            let isValidDrive = driveManager.availableDrives.contains(where: { $0.id == currentID })
            if isValidDrive && !claimedIDs.contains(currentID) {
                claimedIDs.insert(currentID)
                if let matched = driveManager.availableDrives.first(where: { $0.id == currentID }) {
                    destinationQueue[idx].hardwareOrPath = matched.displayName
                }
            } else if let nextFree = driveManager.availableDrives.first(where: { !claimedIDs.contains($0.id) }) {
                destinationQueue[idx].targetDriveID = nextFree.id
                destinationQueue[idx].hardwareOrPath = nextFree.displayName
                claimedIDs.insert(nextFree.id)
            } else {
                // All connected USB burners are already claimed by earlier cards in the queue!
                if allowed.contains(.discImage) {
                    let imgTarget = defaultDiscImageTarget
                    destinationQueue[idx].kind = .discImage
                    destinationQueue[idx].targetDriveID = ""
                    destinationQueue[idx].hardwareOrPath = imgTarget.path
                    destinationQueue[idx].speedOrCodec = imgTarget.description
                } else {
                    destinationQueue[idx].kind = .networkBurner
                    destinationQueue[idx].targetDriveID = ""
                    destinationQueue[idx].hardwareOrPath = "localhost:7420"
                    destinationQueue[idx].speedOrCodec = "Max Safe (Auto)"
                }
            }
        }
    }
    func cardActionTitle(for kind: KroutonBurnDestinationKind) -> String {
        switch kind {
        case .physicalBurner, .networkBurner: return "Burn Disc"
        case .discImage: return "Save Image"
        case .audioRip: return "Rip Audio"
        case .videoExtract: return "Extract Video"
        case .discPrinter: return "Print Label"
        case .pdfVector: return "Save PDF"
        }
    }
    func cardActionSymbol(for kind: KroutonBurnDestinationKind) -> String {
        switch kind {
        case .physicalBurner, .networkBurner: return "flame.fill"
        case .discImage: return "internaldrive.fill"
        case .audioRip: return "waveform"
        case .videoExtract: return "film"
        case .discPrinter: return "printer.fill"
        case .pdfVector: return "doc.richtext.fill"
        }
    }
    var primaryActionTitle: String {
        let count = destinationQueue.count
        switch selectedCategory {
        case .burn:
            return "BURN (\(count))"
        case .depot:
            return "GET & BURN ISO (\(count))"
        case .copy:
            switch selectedTaskID {
            case "copy-rip-audio", "copy-audio-rip":
                return "RIP AUDIO CD (\(count))"
            case "copy-rip-video":
                return "EXTRACT VIDEO (\(count))"
            default:
                return "DUPLICATE DISC (\(count))"
            }
        case .label:
            return "PRINT LABEL (\(count))"
        }
    }
    var primaryActionSymbol: String {
        switch selectedCategory {
        case .burn: return "flame.fill"
        case .depot: return "arrow.down.doc.fill"
        case .copy:
            switch selectedTaskID {
            case "copy-rip-audio", "copy-audio-rip": return "waveform.badge.plus"
            case "copy-rip-video": return "film.stack.fill"
            default: return "doc.on.doc.fill"
            }
        case .label: return "printer.fill"
        }
    }
    var queueStatusSummaryText: String {
        switch selectedCategory {
        case .burn:
            return "Queue Ready • \(stagedFiles.count) Items (\(ByteCountFormatter.string(fromByteCount: totalStagedBytes, countStyle: .file)))"
        case .depot:
            let item = depotItems.first(where: { $0.id == selectedDepotHeroItemID }) ?? depotItems[0]
            return "Depot Ready • \(item.title) (\(item.sizeDisplay))"
        case .copy:
            switch selectedTaskID {
            case "copy-rip-audio", "copy-audio-rip":
                if let cd = KroutonRealCDExtractor.scanMountedAudioCD() { return "Audio Rip Ready • \(cd.tracks.count) Red Book Tracks (\(ByteCountFormatter.string(fromByteCount: cd.totalPCMBytes, countStyle: .file)))" }
                return "Audio Rip Ready • Insert Red Book Audio CD"
            case "copy-rip-video":
                return "Video Extract • \(stagedFiles.count) Source(s) (\(ByteCountFormatter.string(fromByteCount: totalStagedBytes, countStyle: .file)))"
            default:
                return "Disc Duplicator • \(ByteCountFormatter.string(fromByteCount: totalStagedBytes, countStyle: .file)) Staged"
            }
        case .label:
            return "Canvas Ready • 300-DPI Polar Vector Disc Label"
        }
    }
    /// Maps any (category, taskID) pair to its logical Destination Domain bucket
    static func destinationDomainKey(category: KroutonMasteringStation, taskID: String) -> String {
        switch category {
        case .burn, .depot:
            return "domain.opticalBurn"
        case .copy:
            if taskID == "copy-rip-audio" || taskID == "copy-audio-rip" {
                return "domain.audioRip"
            } else if taskID == "copy-rip-video" {
                return "domain.videoExtract"
            }
            return "domain.opticalBurn" // Duplicate Disc shares optical burn hardware & ISO targets!
        case .label:
            return "domain.discLabel"
        }
    }
    var currentDestinationDomainKey: String {
        Self.destinationDomainKey(category: selectedCategory, taskID: selectedTaskID)
    }
    /// Saves the active destinationQueue into the current domain bucket
    func snapshotCurrentDestinationQueue() {
        let key = currentDestinationDomainKey
        if !destinationQueue.isEmpty {
            savedQueuesByDomain[key] = destinationQueue
        }
    }
    /// Non-destructive destination switcher:
    /// 1. Saves the outgoing queue in savedQueuesByDomain[outgoingDomain]
    /// 2. If switching within the same domain (e.g. Audio CD -> DVD-Video -> Hybrid Data), keeps compatible
    ///    USB Burner & LAN Server cards and updates any .discImage extension (.cue <-> .iso <-> .dmg)!
    /// 3. If switching to a different domain (e.g. Label -> Audio CD -> Label), restores the saved queue for that domain!
    func syncDefaultDestinationForCategory(_ category: KroutonMasteringStation, taskID: String, driveManager: KroutonOpticalDriveBank) {
        let targetDomain = Self.destinationDomainKey(category: category, taskID: taskID)
        let allowed = allowedDestinationsForCurrentCategory
        // 1. Check if we already have a saved queue for the target domain (or compatible cards in the current queue)
        let candidateQueue: [KroutonBakeBatchItem] = {
            if let saved = savedQueuesByDomain[targetDomain], !saved.isEmpty {
                return saved
            }
            let compatibleCurrent = destinationQueue.filter { allowed.contains($0.kind) }
            if !compatibleCurrent.isEmpty {
                return compatibleCurrent
            }
            return []
        }()
        if !candidateQueue.isEmpty {
            var restored = candidateQueue.filter { allowed.contains($0.kind) }
            // Update any .discImage card's file extension (.cue vs .iso vs .dmg) to match the new format!
            let imgTarget = defaultDiscImageTarget
            for i in restored.indices where restored[i].kind == .discImage {
                let currentPath = restored[i].hardwareOrPath
                let dir = (currentPath as NSString).deletingLastPathComponent
                let baseDir = dir.isEmpty ? "~/Desktop" : dir
                let ext = (imgTarget.path as NSString).pathExtension
                let cleanTitle = discVolumeTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                    ? (selectedTaskID == "dvd-video" ? "DVD_VIDEO" : "KROUTON_DISC")
                    : discVolumeTitle.replacingOccurrences(of: " ", with: "_")
                restored[i].hardwareOrPath = "\(baseDir)/\(cleanTitle).\(ext)"
                restored[i].speedOrCodec = imgTarget.description
            }
            if !restored.isEmpty {
                destinationQueue = restored
                reconcileUniqueDriveAssignments(driveManager: driveManager)
                savedQueuesByDomain[targetDomain] = destinationQueue
                return
            }
        }
        // 2. First time visiting this domain: seed its default destination card
        let firstDrive = driveManager.availableDrives.first
        let currentDriveName = firstDrive?.displayName ?? "Optical Drive"
        let currentDriveID = firstDrive?.id ?? ""
        switch category {
        case .burn, .depot:
            destinationQueue = [
                KroutonBakeBatchItem(kind: .physicalBurner, targetDriveID: currentDriveID, hardwareOrPath: currentDriveName, speedOrCodec: "Max Safe (Auto)", simulationMode: false, verifyAfterBurn: true, compressAfterCreation: false)
            ]
        case .copy:
            if taskID == "copy-rip-audio" || taskID == "copy-audio-rip" {
                destinationQueue = [
                    KroutonBakeBatchItem(kind: .audioRip, targetDriveID: "", hardwareOrPath: "~/Music/Krouton Rips/FLAC Lossless", speedOrCodec: "FLAC (Lossless) + AccurateRip", simulationMode: false, verifyAfterBurn: true, compressAfterCreation: false)
                ]
            } else if taskID == "copy-rip-video" {
                destinationQueue = [
                    KroutonBakeBatchItem(kind: .videoExtract, targetDriveID: "", hardwareOrPath: "~/Movies/Krouton Extracts", speedOrCodec: "Lossless MKV Remux", simulationMode: false, verifyAfterBurn: false, compressAfterCreation: false)
                ]
            } else {
                destinationQueue = [
                    KroutonBakeBatchItem(kind: .physicalBurner, targetDriveID: currentDriveID, hardwareOrPath: currentDriveName, speedOrCodec: "Max Safe (Auto)", simulationMode: false, verifyAfterBurn: true, compressAfterCreation: false)
                ]
            }
        case .label:
            destinationQueue = [
                KroutonBakeBatchItem(kind: .discPrinter, targetDriveID: "", hardwareOrPath: "Epson EcoTank Photo ET-8550 (CD/DVD Tray)", speedOrCodec: "Claria ET 6-Ink • 120mm / 18mm", simulationMode: false, verifyAfterBurn: false, compressAfterCreation: false)
            ]
        }
        savedQueuesByDomain[targetDomain] = destinationQueue
    }
    func appendContextAwareDestination(driveManager: KroutonOpticalDriveBank) {
        switch selectedCategory {
        case .depot:
            let usedDriveIDs = Set(destinationQueue.filter { $0.kind == .physicalBurner }.map { $0.targetDriveID })
            if let nextUnusedDrive = driveManager.availableDrives.first(where: { !usedDriveIDs.contains($0.id) }) {
                destinationQueue.append(
                    KroutonBakeBatchItem(kind: .physicalBurner, targetDriveID: nextUnusedDrive.id, hardwareOrPath: nextUnusedDrive.displayName, speedOrCodec: "Max Safe (Auto)", simulationMode: false, verifyAfterBurn: true, compressAfterCreation: false)
                )
            } else {
                destinationQueue.append(
                    KroutonBakeBatchItem(kind: .networkBurner, targetDriveID: "", hardwareOrPath: "localhost:7420", speedOrCodec: "Max Safe (Auto)", simulationMode: false, verifyAfterBurn: true, compressAfterCreation: false)
                )
            }
        case .burn:
            let usedDriveIDs = Set(destinationQueue.filter { $0.kind == .physicalBurner }.map { $0.targetDriveID })
            if let nextUnusedDrive = driveManager.availableDrives.first(where: { !usedDriveIDs.contains($0.id) }) {
                destinationQueue.append(
                    KroutonBakeBatchItem(kind: .physicalBurner, targetDriveID: nextUnusedDrive.id, hardwareOrPath: nextUnusedDrive.displayName, speedOrCodec: "Max Safe (Auto)", simulationMode: false, verifyAfterBurn: true, compressAfterCreation: false)
                )
            } else if selectedTaskID == "image-burn" {
                destinationQueue.append(
                    KroutonBakeBatchItem(kind: .networkBurner, targetDriveID: "", hardwareOrPath: "localhost:7420", speedOrCodec: "Max Safe (Auto)", simulationMode: false, verifyAfterBurn: true, compressAfterCreation: false)
                )
            } else {
                let imgTarget = defaultDiscImageTarget
                destinationQueue.append(
                    KroutonBakeBatchItem(kind: .discImage, targetDriveID: "", hardwareOrPath: imgTarget.path, speedOrCodec: imgTarget.description, simulationMode: false, verifyAfterBurn: true, compressAfterCreation: true)
                )
            }
        case .copy:
            if selectedTaskID == "copy-rip-audio" || selectedTaskID == "copy-audio-rip" {
                let hasCueBackup = destinationQueue.contains(where: { $0.kind == .discImage })
                if !hasCueBackup {
                    let imgTarget = defaultDiscImageTarget
                    destinationQueue.append(
                        KroutonBakeBatchItem(kind: .discImage, targetDriveID: "", hardwareOrPath: imgTarget.path, speedOrCodec: imgTarget.description, simulationMode: false, verifyAfterBurn: true, compressAfterCreation: false)
                    )
                } else {
                    destinationQueue.append(
                        KroutonBakeBatchItem(kind: .audioRip, targetDriveID: "", hardwareOrPath: "~/Music/Krouton Rips/MP3 320kbps", speedOrCodec: "MP3 (320 kbps CBR)", simulationMode: false, verifyAfterBurn: true, compressAfterCreation: false)
                    )
                }
            } else if selectedTaskID == "copy-rip-video" {
                let hasIsoBackup = destinationQueue.contains(where: { $0.kind == .discImage })
                if !hasIsoBackup {
                    let imgTarget = defaultDiscImageTarget
                    destinationQueue.append(
                        KroutonBakeBatchItem(kind: .discImage, targetDriveID: "", hardwareOrPath: imgTarget.path, speedOrCodec: imgTarget.description, simulationMode: false, verifyAfterBurn: true, compressAfterCreation: false)
                    )
                } else {
                    destinationQueue.append(
                        KroutonBakeBatchItem(kind: .videoExtract, targetDriveID: "", hardwareOrPath: "~/Movies/Krouton Extracts/HEVC_10Bit", speedOrCodec: "Apple HEVC 10-Bit (.mp4)", simulationMode: false, verifyAfterBurn: false, compressAfterCreation: false)
                    )
                }
            } else {
                let imgTarget = defaultDiscImageTarget
                destinationQueue.append(
                    KroutonBakeBatchItem(kind: .discImage, targetDriveID: "", hardwareOrPath: imgTarget.path, speedOrCodec: imgTarget.description, simulationMode: false, verifyAfterBurn: true, compressAfterCreation: false)
                )
            }
        case .label:
            destinationQueue.append(
                KroutonBakeBatchItem(kind: .pdfVector, targetDriveID: "", hardwareOrPath: "~/Desktop/Epson_ET8550_Label_120mm.pdf", speedOrCodec: "300 DPI Vector PDF Proof", simulationMode: false, verifyAfterBurn: false, compressAfterCreation: false)
            )
        }
    }
}
