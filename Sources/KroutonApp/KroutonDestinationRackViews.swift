//
//  KroutonDestinationRackViews.swift
//  Krouton — Optical Media Mastering Studio
//
//  Right-Column Hardware Burner / Image Destination Cards, Queue Execution, and Volume Rows.
//

import AppKit
import OpticalDough
import SwiftUI
import UniformTypeIdentifiers
import Foundation
import Combine

extension KroutonMainWorkspaceView {
    func destinationCard(item: KroutonBakeBatchItem) -> some View {
        let cardID = item.id

        // Drives claimed by OTHER destination cards in the queue
        let otherUsedDriveIDs = Set(
            store.destinationQueue
                .filter { $0.id != cardID && $0.kind == .physicalBurner && !$0.targetDriveID.isEmpty }
                .map { $0.targetDriveID }
        )

        // Resolve THIS card's drive without falling back to a drive already claimed by another card!
        let cardDrive: KroutonToasterInfo? = {
            if let exact = driveManager.availableDrives.first(where: { $0.id == item.targetDriveID }) {
                return exact
            }
            return driveManager.availableDrives.first(where: { !otherUsedDriveIDs.contains($0.id) }) ?? driveManager.availableDrives.first
        }()

        let activeCardDriveID = (item.kind == .networkBurner) ? "krumb-network-toaster" : (cardDrive?.id ?? "")
        let validSpeeds = cardDrive?.availableWriteSpeeds ?? ["Max Safe (Auto)", "24x (4234 KB/s)", "10x (1764 KB/s)", "8x (1411 KB/s)", "4x (705 KB/s)", "2x (353 KB/s)"]

        let scopeTel = driveManager.telemetryForDrive(activeCardDriveID)
        let isFloatingOpen = scopeTel?.isFloatingWindowOpen ?? false
        let isInlineVisible = ((scopeTel?.isActive ?? false) || (scopeTel?.isManuallyPinnedInline ?? false)) && !isFloatingOpen

        let isDriveBusy = driveManager.isExecutingQueue || (scopeTel?.isActive == true)
        let canEject = (cardDrive?.isMediaPresent == true) && !isDriveBusy
        let canErase = (cardDrive?.isMediaPresent == true) && (cardDrive?.isMediaErasable == true) && !isDriveBusy

        return VStack(alignment: .leading, spacing: 10) {
            // Top Row: Output Kind Picker + Scope Toggle/Dock Button + (Conditional) Eject + Remove Card
            HStack(spacing: 6) {
                Image(systemName: item.kind.sfSymbol)
                    .foregroundStyle(store.uiSecondaryAccent)

                Picker("", selection: Binding(
                    get: { item.kind },
                    set: {
                        let newKind = $0
                        updateQueueItem(cardID) { $0.kind = newKind }
                        reconcileUniqueDriveAssignments()
                    }
                )) {
                    ForEach(allowedDestinationsForCurrentCategory) { kind in
                        Text(KroutonL10n.tr(kind.rawValue)).tag(kind)
                    }
                }
                .labelsHidden()
                .frame(minWidth: 135, maxWidth: 175)
                .layoutPriority(1)

                Spacer(minLength: 4)

                if item.kind == .physicalBurner {
                    // Scope Button: Overrides auto-hide! If floating window is open, changes style and sucks it back into a mini graph when pressed!
                    Button {
                        withAnimation(.spring(response: 0.28, dampingFraction: 0.82)) {
                            if isFloatingOpen {
                                // Suck floating window back into inline mini graph!
                                KroutonWindowManager.shared.closeFloatingPhaseScopeWindow(driveID: activeCardDriveID, suckIntoMiniGraph: true)
                            } else if isInlineVisible {
                                // Manual override: hide the inline mini graph
                                driveManager.setManualInlinePin(for: activeCardDriveID, isPinned: false)
                                if var t = driveManager.driveTelemetry[activeCardDriveID] {
                                    t.isActive = false
                                    driveManager.driveTelemetry[activeCardDriveID] = t
                                }
                            } else {
                                // Manual override: pin inline mini graph open & run calibration sweep
                                driveManager.setManualInlinePin(for: activeCardDriveID, isPinned: true)
                                driveManager.runPhaseScopeTestSweep(for: activeCardDriveID, keepPinnedAfterSweep: true)
                            }
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: isFloatingOpen ? "arrow.down.right.and.arrow.up.left" : "waveform.path.ecg")
                            Text(isFloatingOpen ? "Dock Scope" : "Scope")
                                .lineLimit(1)
                        }
                        .font(.system(size: 10, weight: .bold))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(
                            isFloatingOpen
                                ? (store.enableSecondaryAccentUITints ? store.activeSecondaryAccent : store.uiSecondaryAccent)
                                : (isInlineVisible ? store.uiSecondaryAccent : store.uiSecondaryAccent.opacity(0.18))
                        )
                        .foregroundStyle(
                            (isFloatingOpen || isInlineVisible) ? Color.black.opacity(0.9) : store.uiSecondaryAccent
                        )
                        .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                    .fixedSize()
                    .help(isFloatingOpen ? "Pull Floating Phase Scope window back into the inline mini graph" : (isInlineVisible ? "Hide inline Phase Scope mini graph" : "Show inline Phase Scope mini graph (overrides auto-hide)"))

                    if canEject {
                        Button {
                            driveManager.ejectDrive(id: activeCardDriveID)
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "eject.fill")
                                if !isRightQueueCompact { Text(KroutonL10n.tr("Eject")).lineLimit(1) }
                            }
                            .font(.system(size: 10, weight: .semibold))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(Color.secondary.opacity(0.15))
                            .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
                        .fixedSize()
                        .help("Eject \(cardDrive?.displayName ?? "Disc")")
                    }
                }

                if store.destinationQueue.count > 1 {
                    Button {
                        store.destinationQueue.removeAll { $0.id == cardID }
                        reconcileUniqueDriveAssignments()
                    } label: {
                        Image(systemName: "minus.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                    .help("Remove this output from the queue (releases its drive for other cards)")
                }
            }

            if item.kind == .physicalBurner {
                if driveManager.availableDrives.isEmpty {
                    HStack {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(.orange)
                        Text(KroutonL10n.tr("No USB Optical Drive Connected"))
                            .font(.system(size: 11, weight: .semibold))
                    }
                } else {
                    // Custom Hardware Drive Menu: Shows all drives, greys out drives selected in other cards, and never shows '(In Use)' on the active drive!
                    Menu {
                        ForEach(driveManager.availableDrives) { d in
                            let isTakenByOther = otherUsedDriveIDs.contains(d.id)
                            Button {
                                guard !isTakenByOther else { return }
                                updateQueueItem(cardID) { qItem in
                                    qItem.targetDriveID = d.id
                                    qItem.hardwareOrPath = d.displayName
                                    driveManager.selectedDrive = d
                                }
                            } label: {
                                HStack {
                                    if d.id == activeCardDriveID {
                                        Image(systemName: "checkmark")
                                    }
                                    Text(isTakenByOther ? "\(d.displayName) — In Use" : d.displayName)
                                }
                            }
                            .disabled(isTakenByOther)
                        }
                    } label: {
                        HStack {
                            Text(cardDrive?.displayName ?? "Select Optical Burner")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(.primary)
                                .lineLimit(1)
                            Spacer()
                            Image(systemName: "chevron.up.chevron.down")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundStyle(.secondary)
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(store.enableSecondaryAccentUITints ? store.uiSecondaryAccent.opacity(0.11) : Color.clear)
            .background(Color(NSColor.controlBackgroundColor))
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                        .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.primary.opacity(0.12), lineWidth: 1))
                    }
                    .buttonStyle(.plain)

                    if let activeDrive = cardDrive {
                        HStack(spacing: 8) {
                            Button {
                                activeDiscPopoverCardID = (activeDiscPopoverCardID == cardID) ? nil : cardID
                            } label: {
                                HStack(spacing: 5) {
                                    Circle()
                                        .fill(activeDrive.isMediaPresent ? store.uiSecondaryAccent : Color.secondary)
                                        .frame(width: 7, height: 7)
                                    Text(activeDrive.statusBadgeText)
                                        .font(.system(size: 10, weight: .semibold))
                                        .lineLimit(1)
                                    Image(systemName: "info.circle")
                                        .font(.system(size: 9))
                                }
                                .padding(.horizontal, 9)
                                .padding(.vertical, 4)
                                .background((activeDrive.isMediaPresent ? store.uiSecondaryAccent : Color.secondary).opacity(0.15))
                                .foregroundStyle(activeDrive.isMediaPresent ? store.uiSecondaryAccent : .secondary)
                                .clipShape(Capsule())
                            }
                            .buttonStyle(.plain)
                            .fixedSize()
                            .help("Click to inspect ATIP/MID manufacturer, dye chemistry, sessions, and sector topology")
                            .popover(isPresented: Binding(
                                get: { activeDiscPopoverCardID == cardID },
                                set: { if !$0 { activeDiscPopoverCardID = nil } }
                            ), arrowEdge: .leading) {
                                KroutonSliceMediaPopover(drive: activeDrive, accent: store.uiSecondaryAccent)
                            }

                            if canErase {
                                Menu {
                                    Button("Quick Erase (Fast TOC Blank — ~30s)") {
                                        driveManager.eraseRewritableDisc(driveID: activeCardDriveID, fullErase: false) { _ in }
                                    }
                                    Button("Full Erase (Zero All Sectors)") {
                                        driveManager.eraseRewritableDisc(driveID: activeCardDriveID, fullErase: true) { _ in }
                                    }
                                } label: {
                                    HStack(spacing: 4) {
                                        Image(systemName: "eraser.fill")
                                        Text(KroutonL10n.tr("Erase RW"))
                                            .lineLimit(1)
                                    }
                                    .font(.system(size: 10, weight: .semibold))
                                    .foregroundStyle(store.uiSecondaryAccent)
                                }
                                .menuStyle(.borderlessButton)
                                .tint(store.uiSecondaryAccent)
                                .fixedSize()
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(store.uiSecondaryAccent.opacity(0.16))
                                .clipShape(Capsule())
                                .help("Erase rewritable disc in \(activeDrive.displayName)")
                            }

                            Spacer(minLength: 0)
                        }
                    }
                }

                HStack {
                    Text(isRightQueueCompact ? "Speed:" : KroutonL10n.tr("Write Speed:")).lineLimit(1)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Picker("", selection: Binding(
                        get: {
                            validSpeeds.contains(item.speedOrCodec) ? item.speedOrCodec : "Max Safe (Auto)"
                        },
                        set: { newVal in
                            updateQueueItem(cardID) { $0.speedOrCodec = newVal }
                        }
                    )) {
                        ForEach(validSpeeds, id: \.self) { spd in
                            Text(spd).tag(spd)
                        }
                    }
                    .labelsHidden()
                    .frame(width: 155)
                }

                // Multi-Copy Batch & Book Type Bitsetting Row
                HStack(spacing: 8) {
                    Stepper(value: Binding(
                        get: { item.copiesToBurn },
                        set: { newCopies in updateQueueItem(cardID) { $0.copiesToBurn = max(1, min(99, newCopies)) } }
                    ), in: 1...99) {
                        HStack(spacing: 4) {
                            Image(systemName: item.copiesToBurn > 1 ? "square.stack.3d.up.fill" : "doc.on.doc")
                                .font(.system(size: 10))
                                .foregroundStyle(item.copiesToBurn > 1 ? store.uiSecondaryAccent : .secondary)
                            Text(item.copiesToBurn > 1 ? "Batch: \(item.copiesToBurn) Copies" : "Copies: 1")
                                .font(.system(size: 11, weight: item.copiesToBurn > 1 ? .bold : .regular, design: .monospaced))
                        }
                    }
                    .controlSize(.small)

                    Spacer(minLength: 4)

                    if store.forceDVDROMBookType {
                        HStack(spacing: 3) {
                            Image(systemName: "seal.fill")
                                .font(.system(size: 8))
                            Text(isRightQueueCompact ? "DVD-ROM" : KroutonL10n.tr("DVD-ROM Bitset")).lineLimit(1)
                                .font(.system(size: 9, weight: .bold, design: .monospaced))
                        }
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background((store.enableSecondaryAccentUITints ? store.activeSecondaryAccent : store.uiSecondaryAccent).opacity(0.16))
                        .foregroundStyle((store.enableSecondaryAccentUITints ? store.activeSecondaryAccent : store.uiSecondaryAccent))
                        .clipShape(Capsule())
                        .help("MMC Bitsetting Active: Stamps DVD+R / DVD+R DL lead-in Book Type as DVD-ROM (0x00)")
                    }

                    if item.copiesToBurn > 1 && store.autoLoadNextDiscBatchMode {
                        HStack(spacing: 3) {
                            Image(systemName: "arrow.triangle.2.circlepath.circle.fill")
                                .font(.system(size: 9))
                            Text("Auto-Load (\(store.autoLoadCountdownSeconds)s)")
                                .font(.system(size: 9, weight: .bold, design: .monospaced))
                        }
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(store.uiSecondaryAccent.opacity(0.18))
                        .foregroundStyle(store.uiSecondaryAccent)
                        .clipShape(Capsule())
                        .help("Hands-Free Duplication: Auto-ejects finished disc and starts next burn \(store.autoLoadCountdownSeconds)s after a fresh blank disc is inserted")
                    }
                }

                // Live Hands-Free Auto-Load Next Disc Banner (Appears between copies in a batch)
                if let batchSt = driveManager.batchStates[activeCardDriveID] {
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(spacing: 6) {
                            Image(systemName: batchSt.countdownSecondsRemaining != nil ? "timer" : "opticaldisc.fill")
                                .foregroundStyle(batchSt.countdownSecondsRemaining != nil ? .orange : store.uiSecondaryAccent)
                            Text(batchSt.statusMessage)
                                .font(.system(size: 10, weight: .bold, design: .monospaced))
                                .foregroundStyle(.primary)
                                .lineLimit(2)
                            Spacer()
                        }
                        HStack(spacing: 8) {
                            if batchSt.countdownSecondsRemaining == nil {
                                Button {
                                    driveManager.triggerImmediateBatchCountdownForTesting(
                                        driveID: activeCardDriveID,
                                        countdownSeconds: store.autoLoadCountdownSeconds
                                    ) {
                                        executeSingleDestination(item)
                                    }
                                } label: {
                                    Text("Simulate Blank Disc Insert (\(store.autoLoadCountdownSeconds)s)")
                                        .font(.system(size: 9, weight: .bold))
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 3)
                                        .background(store.uiSecondaryAccent)
                                        .foregroundStyle(store.activeOnAccentText)
                                        .clipShape(Capsule())
                                }
                                .buttonStyle(.plain)
                            }
                            Button {
                                driveManager.cancelBatchDuplication(for: activeCardDriveID)
                            } label: {
                                Text(KroutonL10n.tr("Cancel Batch"))
                                    .font(.system(size: 9, weight: .semibold))
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 3)
                                    .background(Color.red.opacity(0.18))
                                    .foregroundStyle(.red)
                                    .clipShape(Capsule())
                            }
                            .buttonStyle(.plain)
                            Spacer()
                        }
                    }
                    .padding(8)
                    .background(store.uiSecondaryAccent.opacity(0.10))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(store.uiSecondaryAccent.opacity(0.38), lineWidth: 1))
                }
            } else if item.kind == .networkBurner {
                KrumbNetworkToasterCardSectionView(
                    store: store,
                    driveManager: driveManager,
                    item: item,
                    activeCardDriveID: activeCardDriveID,
                    isFloatingOpen: isFloatingOpen,
                    isInlineVisible: isInlineVisible,
                    onUpdateHost: { newHost in
                        updateQueueItem(cardID) { $0.hardwareOrPath = newHost }
                    }
                )
            } else if item.kind == .discImage {
                HStack(spacing: 6) {
                    TextField("~/Desktop/Kruton_Master.dmg", text: Binding(
                        get: { item.hardwareOrPath },
                        set: { newPath in updateQueueItem(cardID) { $0.hardwareOrPath = newPath } }
                    ))
                    .textFieldStyle(.roundedBorder)
                    .font(.system(size: 11, design: .monospaced))
                    Button("Save As...") {
                        let panel = NSSavePanel()
                        panel.nameFieldStringValue = "\(store.discVolumeTitle).dmg"
                        if panel.runModal() == .OK, let url = panel.url {
                            updateQueueItem(cardID) { $0.hardwareOrPath = url.path }
                        }
                    }
                    .controlSize(.small)
                }
            } else {
                Text(item.hardwareOrPath)
                    .font(.system(size: 11, weight: .semibold, design: .monospaced))
                    .foregroundStyle(.primary)
            }

            // Bottom Row: Options on Left + Dedicated Per-Card Action Button on Right
            HStack(spacing: 10) {
                if item.kind == .physicalBurner || item.kind == .networkBurner {
                    HStack(spacing: 10) {
                        Toggle(KroutonL10n.tr("Simulate"), isOn: Binding(
                            get: { item.simulationMode },
                            set: { val in updateQueueItem(cardID) { $0.simulationMode = val } }
                        ))
                        .font(.caption)
                        Toggle(KroutonL10n.tr("Verify"), isOn: Binding(
                            get: { item.verifyAfterBurn },
                            set: { val in updateQueueItem(cardID) { $0.verifyAfterBurn = val } }
                        ))
                        .font(.caption)
                    }
                } else if item.kind == .discImage {
                    Toggle(KroutonL10n.tr("Compress Image"), isOn: Binding(
                        get: { item.compressAfterCreation },
                        set: { val in updateQueueItem(cardID) { $0.compressAfterCreation = val } }
                    ))
                    .font(.caption)
                }

                Spacer(minLength: 4)

                Button {
                    executeSingleDestination(item)
                } label: {
                    HStack(spacing: 5) {
                        Image(systemName: cardActionSymbol(for: item.kind))
                            .font(.system(size: 10, weight: .bold))
                        Text(KroutonL10n.tr(cardActionTitle(for: item.kind)))
                            .font(.system(size: 11, weight: .bold, design: .rounded))
                            .lineLimit(1)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 5)
                    .background(store.uiSecondaryAccent)
                    .foregroundStyle(store.activeOnAccentText)
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)
                .fixedSize()
                .disabled(driveManager.isExecutingQueue)
                .help("Execute only this destination card (\(item.kind.rawValue))")
            }

            // Per-Burner Inline Mini Phase Scope (Shown when active OR manually pinned via Scope button, and not popped out)
            if (item.kind == .physicalBurner || item.kind == .networkBurner),
               let scopeTel = scopeTel,
               isInlineVisible {
                KroutonMiniThermometerView(telemetry: scopeTel, accent: store.uiSecondaryAccent) {
                    KroutonWindowManager.shared.openFloatingPhaseScopeWindow(driveID: activeCardDriveID)
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(12)
        .background(store.enableSecondaryAccentUITints ? store.uiSecondaryAccent.opacity(0.11) : Color.clear)
            .background(Color(NSColor.windowBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(store.uiSecondaryAccent.opacity(0.35), lineWidth: 1))
    }

    func runTargetDestination(_ target: KroutonBakeBatchItem) async {
        switch target.kind {
        case .networkBurner:
            driveManager.setManualInlinePin(for: "krumb-network-toaster", isPinned: true)
            let _ = await KrumbKitchenClient.shared.executeSpoolAndBurn(
                endpoint: target.hardwareOrPath,
                stagedFiles: store.stagedFiles,
                audioCubes: store.redBookTracks,
                volumeTitle: store.discVolumeTitle,
                performer: store.discPerformer,
                mcnBarcode: store.discMCNBarcode,
                requestedSpeedLabel: target.speedOrCodec,
                simulationMode: target.simulationMode,
                driveManager: driveManager,
                targetDriveKey: "krumb-network-toaster"
            )
            store.objectWillChange.send()
        case .physicalBurner:
            if store.forceDVDROMBookType, !target.targetDriveID.isEmpty {
                driveManager.stampDVDROMBookType(for: target.targetDriveID, vendorProfile: store.bitsetVendorProfile)
            }
            let burnSucceeded = await withCheckedContinuation { (continuation: CheckedContinuation<Bool, Never>) in
                driveManager.startPhysicalDataBurn(
                    driveID: target.targetDriveID.isEmpty ? nil : target.targetDriveID,
                    stagedFiles: store.stagedFiles,
                    volumeTitle: store.discVolumeTitle,
                    requestedSpeedLabel: target.speedOrCodec,
                    simulationMode: target.simulationMode,
                    verifyDisc: target.verifyAfterBurn
                ) { report in
                    continuation.resume(returning: report.isSuccess)
                }
            }
            if burnSucceeded && target.copiesToBurn > 1 && store.autoLoadNextDiscBatchMode {
                let finishedCount = target.completedCopies + 1
                if finishedCount < target.copiesToBurn {
                    updateQueueItem(target.id) { $0.completedCopies = finishedCount }
                    let driveKey = target.targetDriveID.isEmpty ? (driveManager.selectedDrive?.id ?? "") : target.targetDriveID
                    driveManager.startBatchAutoLoadMonitor(
                        for: driveKey,
                        completedCopy: finishedCount,
                        totalCopies: target.copiesToBurn,
                        countdownSeconds: store.autoLoadCountdownSeconds,
                        bitsetDVDROM: store.forceDVDROMBookType
                    ) {
                        if let updatedItem = store.destinationQueue.first(where: { $0.id == target.id }) {
                            executeSingleDestination(updatedItem)
                        }
                    }
                } else {
                    updateQueueItem(target.id) { $0.completedCopies = 0 }
                }
            }
        case .discImage:
            let _ = await driveManager.createDiscImageFile(
                stagedFiles: store.stagedFiles,
                volumeTitle: store.discVolumeTitle,
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
