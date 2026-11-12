import SwiftUI
import Foundation
import UniformTypeIdentifiers
import OpticalDough

// MARK: - Standalone Right Destination Rack Column View

struct KroutonDestinationRackColumnView: View {
    @ObservedObject var store: KroutonStateStore
    @ObservedObject var driveManager: KroutonToasterBank
    let isRightQueueCompact: Bool
    let enableCustomFinderLayoutTab: Bool
    let finderIconSize: Double
    let primarySelectedDrive: KroutonToasterInfo?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 6) {
                Label(
                    isRightQueueCompact ? "QUEUE (\(store.destinationQueue.count))" : "DESTINATIONS (\(store.destinationQueue.count))",
                    systemImage: "arrow.right.doc.on.clipboard"
                )
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(store.enableSecondaryAccentUITints ? store.activeSecondaryAccent : Color.secondary)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                Spacer(minLength: 4)
                Button {
                    store.appendContextAwareDestination(driveManager: driveManager)
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "plus")
                        if !isRightQueueCompact {
                            Text(KroutonL10n.tr("Add Output"))
                                .lineLimit(1)
                        }
                    }
                    .font(.system(size: 11, weight: .semibold))
                    .padding(.horizontal, 9)
                    .padding(.vertical, 4)
                    .background(store.uiSecondaryAccent.opacity(0.2))
                    .clipShape(Capsule())
                    .fixedSize(horizontal: true, vertical: false)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)

            Divider()

            // Iterating directly over store.destinationQueue by UUID (Zero raw array indices = Zero crashes!)
            ScrollView {
                VStack(spacing: 12) {
                    ForEach(store.destinationQueue) { item in
                        KroutonDestinationCardView(
                            store: store,
                            driveManager: driveManager,
                            item: item,
                            isRightQueueCompact: isRightQueueCompact,
                            enableCustomFinderLayoutTab: enableCustomFinderLayoutTab,
                            finderIconSize: finderIconSize,
                            primarySelectedDrive: primarySelectedDrive
                        )
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 12)
            }

            Divider()

            if driveManager.isExecutingQueue || driveManager.activeJobProgress > 0 {
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text(driveManager.activeJobPhase)
                            .font(.system(size: 11, weight: .bold))
                            .lineLimit(1)
                        Spacer()
                        Text(String(format: "%.0f%%", driveManager.activeJobProgress * 100.0))
                            .font(.system(size: 11, weight: .semibold, design: .monospaced))
                    }
                    ProgressView(value: driveManager.activeJobProgress, total: 1.0)
                        .tint(store.activeAccent)
                    if !driveManager.activeJobDetail.isEmpty {
                        Text(driveManager.activeJobDetail)
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.top, 10)
            }

            VStack(spacing: 8) {
                Button {
                    store.executeDestinationQueue(driveManager: driveManager, primarySelectedDrive: primarySelectedDrive, enableCustomFinderLayoutTab: enableCustomFinderLayoutTab, finderIconSize: finderIconSize)
                } label: {
                    HStack {
                        Image(systemName: driveManager.isExecutingQueue ? "stop.circle.fill" : store.primaryActionSymbol)
                            .font(.system(size: 15, weight: .bold))
                        Text(driveManager.isExecutingQueue ? "ABORT BURN" : store.primaryActionTitle)
                            .font(.system(size: 14, weight: .heavy, design: .rounded))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(driveManager.isExecutingQueue ? Color.red : store.activeAccent)
                    .foregroundStyle(driveManager.isExecutingQueue ? Color.white : store.activeOnAccentText)
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)

                Text("Queue Ready • \(store.stagedFiles.count) Items (\(ByteCountFormatter.string(fromByteCount: store.totalStagedBytes, countStyle: .file)))")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.secondary)
            }
            .padding(14)
        }
        .background(store.enableSecondaryAccentUITints ? store.activeAccent.opacity(0.11) : Color.clear)
        .background(Color.kroutonControlSurface)
    }
}

// MARK: - Dedicated Reactive Subview for Krumb Port 7420 Network Toaster Cards
struct KrumbNetworkToasterCardSectionView: View {
    @ObservedObject var store: KroutonStateStore
    @ObservedObject var driveManager: KroutonToasterBank
    @ObservedObject var krumb: KrumbKitchenClient = .shared

    let item: KroutonBakeBatchItem
    let activeCardDriveID: String
    let isFloatingOpen: Bool
    let isInlineVisible: Bool
    let onUpdateHost: (String) -> Void

    var body: some View {
        let firstToaster = krumb.remoteToasters.first
        VStack(alignment: .leading, spacing: 7) {
            HStack(spacing: 6) {
                Image(systemName: "server.rack")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(store.uiSecondaryAccent)
                Picker("", selection: Binding(
                    get: { item.hardwareOrPath.isEmpty ? "localhost:7420" : item.hardwareOrPath },
                    set: { newHost in
                        onUpdateHost(newHost)
                        krumb.activeEndpointHost = newHost
                    }
                )) {
                    ForEach(krumb.discoveredNodes) { node in
                        Text("\(node.name) (\(node.hostPort))").tag(node.hostPort)
                    }
                }
                .labelsHidden()

                Spacer(minLength: 4)

                Button {
                    withAnimation(.spring(response: 0.28, dampingFraction: 0.82)) {
                        if isFloatingOpen {
                            KroutonWindowManager.shared.closeFloatingPhaseScopeWindow(driveID: activeCardDriveID, suckIntoMiniGraph: true)
                        } else if isInlineVisible {
                            driveManager.setManualInlinePin(for: activeCardDriveID, isPinned: false)
                            if var t = driveManager.driveTelemetry[activeCardDriveID] {
                                t.isActive = false
                                driveManager.driveTelemetry[activeCardDriveID] = t
                            }
                        } else {
                            driveManager.setManualInlinePin(for: activeCardDriveID, isPinned: true)
                            Task {
                                _ = await krumb.executeSpoolAndBurn(
                                    endpoint: item.hardwareOrPath,
                                    stagedFiles: store.stagedFiles,
                                    audioCubes: store.redBookTracks,
                                    volumeTitle: store.discVolumeTitle,
                                    performer: store.discPerformer,
                                    mcnBarcode: store.discMCNBarcode,
                                    requestedSpeedLabel: item.speedOrCodec,
                                    simulationMode: true,
                                    driveManager: driveManager,
                                    targetDriveKey: activeCardDriveID
                                )
                            }
                        }
                    }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: isFloatingOpen ? "arrow.down.right.and.arrow.up.left" : "waveform.path.ecg")
                        Text(isFloatingOpen ? "Dock" : "Scope")
                    }
                    .font(.system(size: 10, weight: .bold))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background((isFloatingOpen || isInlineVisible) ? store.uiSecondaryAccent : store.uiSecondaryAccent.opacity(0.18))
                    .foregroundStyle((isFloatingOpen || isInlineVisible) ? Color.black.opacity(0.9) : store.uiSecondaryAccent)
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)
                .help("Stream Krumb WS /api/v1/kitchen telemetry directly into the Phase Scope")
            }

            HStack(spacing: 6) {
                Circle()
                    .fill(store.uiSecondaryAccent)
                    .frame(width: 7, height: 7)
                Text(krumb.statusBannerText)
                    .font(.system(size: 9.5, weight: .semibold, design: .monospaced))
                    .foregroundStyle(store.uiSecondaryAccent)
                    .lineLimit(1)
                Spacer(minLength: 0)
            }

            if krumb.isSpoolingLoaf {
                ProgressView(value: krumb.spoolProgressFraction, total: 1.0)
                    .tint(store.activeAccent)
                    .controlSize(.small)
            }

            HStack(spacing: 6) {
                Button {
                    Task {
                        await krumb.refreshToasters(endpoint: item.hardwareOrPath)
                    }
                } label: {
                    Label("Probe 7420", systemImage: "antenna.radiowaves.left.and.right")
                        .font(.system(size: 9.5, weight: .bold))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(store.uiSecondaryAccent.opacity(0.16))
                        .foregroundStyle(store.uiSecondaryAccent)
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)

                Button {
                    Task {
                        await krumb.runPantryCalibration(endpoint: item.hardwareOrPath)
                    }
                } label: {
                    Label("Calibrate Pantry", systemImage: "gauge.with.dots.needle.67percent")
                        .font(.system(size: 9.5, weight: .bold))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(store.activeAccent.opacity(0.16))
                        .foregroundStyle(store.activeAccent)
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)

                if let toaster = firstToaster {
                    Button {
                        Task {
                            await krumb.toggleToasterRack(toasterID: toaster.id, endpoint: item.hardwareOrPath)
                        }
                    } label: {
                        Label(toaster.rackState == .open ? "Close Rack" : "Wink Rack", systemImage: "eject.fill")
                            .font(.system(size: 9.5, weight: .bold))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(Color.primary.opacity(0.08))
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
                Spacer(minLength: 0)
            }
        }
    }
}


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
