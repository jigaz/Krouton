import SwiftUI
import Foundation
import OpticalDough

// MARK: - Destination Queue Management & Execution Helpers on KroutonStateStore

@MainActor
extension KroutonStateStore {
    func updateQueueItem(_ id: UUID, mutate: @escaping (inout KroutonBakeBatchItem) -> Void) {
        guard let idx = destinationQueue.firstIndex(where: { $0.id == id }) else { return }
        mutate(&destinationQueue[idx])
    }

    func reconcileUniqueDriveAssignments(driveManager: KroutonToasterBank) {
        guard !driveManager.availableDrives.isEmpty else { return }
        var claimedIDs = Set<String>()
        for idx in destinationQueue.indices {
            guard destinationQueue[idx].kind == .physicalBurner else { continue }
            let currentID = destinationQueue[idx].targetDriveID
            let isValidDrive = driveManager.availableDrives.contains(where: { $0.id == currentID })
            if isValidDrive && !claimedIDs.contains(currentID) {
                claimedIDs.insert(currentID)
            } else if let nextFree = driveManager.availableDrives.first(where: { !claimedIDs.contains($0.id) }) {
                destinationQueue[idx].targetDriveID = nextFree.id
                destinationQueue[idx].hardwareOrPath = nextFree.displayName
                claimedIDs.insert(nextFree.id)
            }
        }
    }

    func cardActionTitle(for kind: KroutonToasterOutputKind) -> String {
        switch kind {
        case .physicalBurner, .networkBurner: return "Burn Disc"
        case .discImage: return "Save Image"
        case .audioRip: return "Rip Audio"
        case .videoExtract: return "Extract Video"
        case .discPrinter: return "Print Label"
        case .pdfVector: return "Save PDF"
        }
    }

    func cardActionSymbol(for kind: KroutonToasterOutputKind) -> String {
        switch kind {
        case .physicalBurner, .networkBurner: return "flame.fill"
        case .discImage: return "internaldrive.fill"
        case .audioRip: return "waveform"
        case .videoExtract: return "film"
        case .discPrinter: return "printer.fill"
        case .pdfVector: return "doc.richtext.fill"
        }
    }

    var allowedDestinationsForCurrentCategory: [KroutonToasterOutputKind] {
        switch selectedCategory {
        case .burn, .depot: return [.physicalBurner, .networkBurner, .discImage]
        case .copy: return [.physicalBurner, .networkBurner, .discImage, .audioRip, .videoExtract]
        case .label: return [.discPrinter, .pdfVector]
        }
    }

    var primaryActionTitle: String {
        switch selectedCategory {
        case .burn: return "BURN (\(destinationQueue.count))"
        case .depot: return "GET & BURN ISO (\(destinationQueue.count))"
        case .copy: return "START COPY / EXTRACT (\(destinationQueue.count))"
        case .label: return "PRINT LABEL (\(destinationQueue.count))"
        }
    }

    var primaryActionSymbol: String {
        switch selectedCategory {
        case .burn: return "flame.fill"
        case .depot: return "arrow.down.doc.fill"
        case .copy: return "doc.on.doc.fill"
        case .label: return "printer.fill"
        }
    }

    func syncDefaultDestinationForCategory(_ category: KroutonBakeryStation, taskID: String, driveManager: KroutonToasterBank) {
        let firstDrive = driveManager.availableDrives.first
        let currentDriveName = firstDrive?.displayName ?? "Optical Drive"
        let currentDriveID = firstDrive?.id ?? ""

        switch category {
        case .burn, .depot:
            destinationQueue = [
                KroutonBakeBatchItem(kind: .physicalBurner, targetDriveID: currentDriveID, hardwareOrPath: currentDriveName, speedOrCodec: "Max Safe (Auto)", simulationMode: false, verifyAfterBurn: true, compressAfterCreation: false)
            ]
        case .copy:
            if taskID == "copy-rip-audio" {
                destinationQueue = [
                    KroutonBakeBatchItem(kind: .audioRip, targetDriveID: currentDriveID, hardwareOrPath: "~/Music/Krouton Rips/Apple Lossless", speedOrCodec: "ALAC (.m4a) + AccurateRip", simulationMode: false, verifyAfterBurn: true, compressAfterCreation: false)
                ]
            } else if taskID == "copy-rip-video" {
                destinationQueue = [
                    KroutonBakeBatchItem(kind: .videoExtract, targetDriveID: currentDriveID, hardwareOrPath: "~/Movies/Krouton Extracts", speedOrCodec: "H.265 (HEVC 10-bit Hardware)", simulationMode: false, verifyAfterBurn: false, compressAfterCreation: false)
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
    }

    func appendContextAwareDestination(driveManager: KroutonToasterBank) {
        switch selectedCategory {
        case .burn, .depot:
            let usedDriveIDs = Set(destinationQueue.filter { $0.kind == .physicalBurner }.map { $0.targetDriveID })
            if let nextUnusedDrive = driveManager.availableDrives.first(where: { !usedDriveIDs.contains($0.id) }) {
                destinationQueue.append(
                    KroutonBakeBatchItem(
                        kind: .physicalBurner,
                        targetDriveID: nextUnusedDrive.id,
                        hardwareOrPath: nextUnusedDrive.displayName,
                        speedOrCodec: "Max Safe (Auto)",
                        simulationMode: false,
                        verifyAfterBurn: true,
                        compressAfterCreation: false
                    )
                )
            } else {
                destinationQueue.append(
                    KroutonBakeBatchItem(
                        kind: .discImage,
                        targetDriveID: "",
                        hardwareOrPath: "~/Desktop/\(discVolumeTitle).dmg",
                        speedOrCodec: "Hybrid UDF / HFS+ Image",
                        simulationMode: false,
                        verifyAfterBurn: true,
                        compressAfterCreation: true
                    )
                )
            }
        case .copy:
            destinationQueue.append(
                KroutonBakeBatchItem(kind: .discImage, targetDriveID: "", hardwareOrPath: "~/Desktop/Disc_Backup.iso", speedOrCodec: "1:1 Archival Sector Image", simulationMode: false, verifyAfterBurn: true, compressAfterCreation: false)
            )
        case .label:
            destinationQueue.append(
                KroutonBakeBatchItem(kind: .pdfVector, targetDriveID: "", hardwareOrPath: "~/Desktop/Epson_ET8550_Label_120mm.pdf", speedOrCodec: "300 DPI Vector PDF Proof", simulationMode: false, verifyAfterBurn: false, compressAfterCreation: false)
            )
        }
    }

    func executeSingleDestination(
        _ target: KroutonBakeBatchItem,
        driveManager: KroutonToasterBank,
        primarySelectedDrive: KroutonToasterInfo?,
        enableCustomFinderLayoutTab: Bool,
        finderIconSize: Double
    ) {
        if driveManager.isExecutingQueue {
            driveManager.abortActiveBurn()
            return
        }
        if stagedFiles.isEmpty && selectedCategory == .burn {
            driveManager.completionReport = KroutonToastReport(
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
                enableCustomFinderLayoutTab: enableCustomFinderLayoutTab,
                finderIconSize: finderIconSize
            )
        }
    }

    func executeDestinationQueue(
        driveManager: KroutonToasterBank,
        primarySelectedDrive: KroutonToasterInfo?,
        enableCustomFinderLayoutTab: Bool,
        finderIconSize: Double
    ) {
        if driveManager.isExecutingQueue {
            driveManager.abortActiveBurn()
            return
        }
        if stagedFiles.isEmpty && selectedCategory == .burn {
            driveManager.completionReport = KroutonToastReport(
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
                    primarySelectedDrive: primarySelectedDrive,
                    enableCustomFinderLayoutTab: enableCustomFinderLayoutTab,
                    finderIconSize: finderIconSize
                )
            }
        }
    }

    func runTargetDestination(
        _ target: KroutonBakeBatchItem,
        driveManager: KroutonToasterBank,
        primarySelectedDrive: KroutonToasterInfo?,
        enableCustomFinderLayoutTab: Bool,
        finderIconSize: Double
    ) async {
        switch target.kind {
        case .networkBurner:
            driveManager.setManualInlinePin(for: "krumb-network-toaster", isPinned: true)
            let _ = await KrumbKitchenClient.shared.executeSpoolAndBurn(
                endpoint: target.hardwareOrPath,
                stagedFiles: stagedFiles,
                audioCubes: redBookTracks,
                volumeTitle: discVolumeTitle,
                performer: discPerformer,
                mcnBarcode: discMCNBarcode,
                requestedSpeedLabel: target.speedOrCodec,
                simulationMode: target.simulationMode,
                driveManager: driveManager,
                targetDriveKey: "krumb-network-toaster"
            )
            objectWillChange.send()
        case .physicalBurner:
            if forceDVDROMBookType, !target.targetDriveID.isEmpty {
                driveManager.stampDVDROMBookType(for: target.targetDriveID, vendorProfile: bitsetVendorProfile)
            }
            let burnSucceeded = await withCheckedContinuation { (continuation: CheckedContinuation<Bool, Never>) in
                driveManager.startPhysicalDataBurn(
                    driveID: target.targetDriveID.isEmpty ? nil : target.targetDriveID,
                    stagedFiles: stagedFiles,
                    volumeTitle: discVolumeTitle,
                    requestedSpeedLabel: target.speedOrCodec,
                    simulationMode: target.simulationMode,
                    verifyDisc: target.verifyAfterBurn
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
                        bitsetDVDROM: forceDVDROMBookType
                    ) { [weak self] in
                        guard let self = self else { return }
                        if let updatedItem = self.destinationQueue.first(where: { $0.id == target.id }) {
                            self.executeSingleDestination(
                                updatedItem,
                                driveManager: driveManager,
                                primarySelectedDrive: primarySelectedDrive,
                                enableCustomFinderLayoutTab: enableCustomFinderLayoutTab,
                                finderIconSize: finderIconSize
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
        default:
            try? await Task.sleep(nanoseconds: 500_000_000)
        }
    }
}
