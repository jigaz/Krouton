import SwiftUI
import Foundation
import UniformTypeIdentifiers
import OpticalDough

// MARK: - Standalone UUID-Safe Destination Rack Card View

struct KroutonDestinationCardView: View {
    @ObservedObject var store: KroutonStateStore
    @ObservedObject var driveManager: KroutonToasterBank
    @ObservedObject var krumb: KrumbKitchenClient = .shared
    let item: KroutonBakeBatchItem
    let isRightQueueCompact: Bool
    let enableCustomFinderLayoutTab: Bool
    let finderIconSize: Double
    let primarySelectedDrive: KroutonToasterInfo?

    @State private var activeDiscPopoverCardID: UUID? = nil

    var body: some View {
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

        return VStack(alignment: .leading, spacing: 10) {
            // Top Row: USB Burner / USB Menu + Scope + Icon-Only Eject + Remove Card
            HStack(spacing: 5) {
                Menu {
                    ForEach(store.allowedDestinationsForCurrentCategory) { kind in
                        Button {
                            store.updateQueueItem(cardID) { $0.kind = kind }
                            store.reconcileUniqueDriveAssignments(driveManager: driveManager)
                        } label: {
                            HStack {
                                if item.kind == kind { Image(systemName: "checkmark") }
                                Text(kind == .physicalBurner ? KroutonL10n.tr("USB Burner") : KroutonL10n.tr(kind.rawValue))
                            }
                        }
                    }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: item.kind.sfSymbol)
                            .foregroundStyle(store.uiSecondaryAccent)
                        Text(
                            item.kind == .physicalBurner
                                ? (isRightQueueCompact ? "USB" : KroutonL10n.tr("USB Burner"))
                                : (isRightQueueCompact ? "ISO" : KroutonL10n.tr(item.kind.rawValue))
                        )
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                        Image(systemName: "chevron.up.chevron.down")
                            .font(.system(size: 8.5, weight: .bold))
                            .foregroundStyle(.secondary)
                    }
                    .padding(.horizontal, 7)
                    .padding(.vertical, 4)
                    .background(Color.primary.opacity(0.06))
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                }
                .buttonStyle(.plain)

                Spacer(minLength: 2)

                if item.kind == .physicalBurner {
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
                                driveManager.runPhaseScopeTestSweep(for: activeCardDriveID, keepPinnedAfterSweep: true)
                            }
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: isFloatingOpen ? "arrow.down.right.and.arrow.up.left" : "waveform.path.ecg")
                            if !isRightQueueCompact { Text(isFloatingOpen ? "Dock" : "Scope").lineLimit(1) }
                        }
                        .font(.system(size: 10, weight: .bold))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 4)
                        .background(
                            isFloatingOpen
                                ? (store.enableSecondaryAccentUITints ? store.activeSecondaryAccent : store.uiSecondaryAccent)
                                : (isInlineVisible ? store.uiSecondaryAccent : store.uiSecondaryAccent.opacity(0.18))
                        )
                        .foregroundStyle((isFloatingOpen || isInlineVisible) ? Color.black.opacity(0.9) : store.uiSecondaryAccent)
                        .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                    .fixedSize()
                    .help(isFloatingOpen ? "Pull Floating Phase Scope window back into inline mini graph" : "Toggle inline Phase Scope mini graph")

                    if canEject {
                        Button {
                            driveManager.ejectDrive(id: activeCardDriveID)
                        } label: {
                            Group {
                                if isRightQueueCompact {
                                    Image(systemName: "eject.fill")
                                        .font(.system(size: 10, weight: .semibold))
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 4)
                                } else {
                                    HStack(spacing: 4) {
                                        Image(systemName: "eject.fill")
                                        Text(KroutonL10n.tr("Eject")).lineLimit(1)
                                    }
                                    .font(.system(size: 10, weight: .semibold))
                                    .padding(.horizontal, 7)
                                    .padding(.vertical, 3)
                                }
                            }
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
                        store.reconcileUniqueDriveAssignments(driveManager: driveManager)
                    } label: {
                        Image(systemName: "minus.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }

            if item.kind == .physicalBurner {
                if driveManager.availableDrives.isEmpty {
                    HStack {
                        Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.orange)
                        Text(KroutonL10n.tr("No USB Optical Drive Connected")).font(.system(size: 11, weight: .semibold))
                    }
                } else {
                    Menu {
                        ForEach(driveManager.availableDrives) { d in
                            let isTakenByOther = otherUsedDriveIDs.contains(d.id)
                            Button {
                                guard !isTakenByOther else { return }
                                store.updateQueueItem(cardID) { qItem in
                                    qItem.targetDriveID = d.id
                                    qItem.hardwareOrPath = d.displayName
                                    driveManager.selectedDrive = d
                                }
                            } label: {
                                HStack {
                                    if d.id == activeCardDriveID { Image(systemName: "checkmark") }
                                    Text(isTakenByOther ? "\(d.displayName) — In Use" : d.displayName)
                                }
                            }
                            .disabled(isTakenByOther)
                        }
                    } label: {
                        HStack(spacing: 6) {
                            Text(cardDrive?.displayName ?? "Select Optical Burner")
                                .font(.system(size: 11.5, weight: .medium))
                                .foregroundStyle(.primary)
                                .lineLimit(1)
                                .truncationMode(.middle)
                            Spacer(minLength: 4)
                            Image(systemName: "chevron.up.chevron.down")
                                .font(.system(size: 9.5, weight: .bold))
                                .foregroundStyle(.secondary)
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 5)
                        .background(store.enableSecondaryAccentUITints ? store.uiSecondaryAccent.opacity(0.11) : Color.clear)
                        .background(Color.kroutonControlSurface)
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                        .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.primary.opacity(0.12), lineWidth: 1))
                    }
                    .buttonStyle(.plain)

                    if let activeDrive = cardDrive {
                        HStack(spacing: 6) {
                            Button {
                                activeDiscPopoverCardID = (activeDiscPopoverCardID == cardID) ? nil : cardID
                            } label: {
                                HStack(spacing: 4) {
                                    Circle()
                                        .fill(activeDrive.isMediaPresent ? store.uiSecondaryAccent : Color.secondary)
                                        .frame(width: 6, height: 6)
                                    Text(activeDrive.statusBadgeText)
                                        .font(.system(size: 10, weight: .semibold))
                                        .lineLimit(1)
                                    Image(systemName: "info.circle")
                                        .font(.system(size: 9))
                                }
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background((activeDrive.isMediaPresent ? store.uiSecondaryAccent : Color.secondary).opacity(0.15))
                                .foregroundStyle(activeDrive.isMediaPresent ? store.uiSecondaryAccent : .secondary)
                                .clipShape(Capsule())
                            }
                            .buttonStyle(.plain)
                            .popover(isPresented: Binding(
                                get: { activeDiscPopoverCardID == cardID },
                                set: { if !$0 { activeDiscPopoverCardID = nil } }
                            ), arrowEdge: .leading) {
                                KroutonSliceMediaPopover(drive: activeDrive, accent: store.uiSecondaryAccent)
                            }
                            Spacer(minLength: 0)
                        }
                    }
                }

                // Consolidated Single-Row: Speed ('Max') + Sim + Verify + Copies ('1x')
                HStack(spacing: 5) {
                    let activeSpd = validSpeeds.contains(item.speedOrCodec) ? item.speedOrCodec : "Max Safe (Auto)"
                    let shortSpd = activeSpd.hasPrefix("Max") ? "Max" : (activeSpd.components(separatedBy: " ").first ?? activeSpd)

                    Menu {
                        ForEach(validSpeeds, id: \.self) { spd in
                            Button {
                                store.updateQueueItem(cardID) { $0.speedOrCodec = spd }
                            } label: {
                                HStack {
                                    if activeSpd == spd { Image(systemName: "checkmark") }
                                    Text(spd)
                                }
                            }
                        }
                    } label: {
                        HStack(spacing: 3) {
                            Image(systemName: "gauge.with.dots.needle.67percent")
                                .font(.system(size: 9.5))
                                .foregroundStyle(store.uiSecondaryAccent)
                            Text(shortSpd)
                                .font(.system(size: 10.5, weight: .semibold, design: .monospaced))
                                .foregroundStyle(.primary)
                                .lineLimit(1)
                            Image(systemName: "chevron.up.chevron.down")
                                .font(.system(size: 8, weight: .bold))
                                .foregroundStyle(.secondary)
                        }
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(Color.primary.opacity(0.06))
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                    }
                    .buttonStyle(.plain)
                    .fixedSize()
                    .help("Write Speed: \(activeSpd)")

                    Spacer(minLength: 2)

                    Toggle(isOn: Binding(
                        get: { item.simulationMode },
                        set: { val in store.updateQueueItem(cardID) { $0.simulationMode = val } }
                    )) {
                        Text(isRightQueueCompact ? "Sim" : KroutonL10n.tr("Simulate"))
                            .font(.system(size: 10.5, weight: .medium))
                            .lineLimit(1)
                    }
                    .toggleStyle(.checkbox)
                    .controlSize(.small)
                    .fixedSize()
                    .help("Simulate Burn (Test laser write without committing to media)")

                    Spacer(minLength: 2)

                    Toggle(isOn: Binding(
                        get: { item.verifyAfterBurn },
                        set: { val in store.updateQueueItem(cardID) { $0.verifyAfterBurn = val } }
                    )) {
                        Text(KroutonL10n.tr("Verify"))
                            .font(.system(size: 10.5, weight: .medium))
                            .lineLimit(1)
                    }
                    .toggleStyle(.checkbox)
                    .controlSize(.small)
                    .fixedSize()
                    .help("Verify written sectors against source image/files after burn")

                    Spacer(minLength: 2)

                    Stepper(value: Binding(
                        get: { item.copiesToBurn },
                        set: { newCopies in store.updateQueueItem(cardID) { $0.copiesToBurn = max(1, min(99, newCopies)) } }
                    ), in: 1...99) {
                        Text("\(item.copiesToBurn)×")
                            .font(.system(size: 10.5, weight: item.copiesToBurn > 1 ? .bold : .semibold, design: .monospaced))
                            .lineLimit(1)
                    }
                    .controlSize(.small)
                    .fixedSize()
                    .help("Copies to burn: \(item.copiesToBurn)")
                }

                if (store.forceDVDROMBookType && !isRightQueueCompact) || (item.copiesToBurn > 1 && store.autoLoadNextDiscBatchMode) {
                    HStack(spacing: 6) {
                        if store.forceDVDROMBookType && !isRightQueueCompact {
                            HStack(spacing: 3) {
                                Image(systemName: "seal.fill")
                                    .font(.system(size: 8))
                                Text(KroutonL10n.tr("DVD-ROM Bitset")).lineLimit(1)
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
                        }
                        Spacer(minLength: 0)
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
                                        store.executeSingleDestination(item, driveManager: driveManager, primarySelectedDrive: primarySelectedDrive, enableCustomFinderLayoutTab: enableCustomFinderLayoutTab, finderIconSize: finderIconSize)
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
                        store.updateQueueItem(cardID) { $0.hardwareOrPath = newHost }
                    }
                )
            } else if item.kind == .discImage {
                KroutonDiscImageTargetRowView(
                    defaultVolumeTitle: store.discVolumeTitle,
                    pathText: Binding(
                        get: { item.hardwareOrPath },
                        set: { newPath in store.updateQueueItem(cardID) { $0.hardwareOrPath = newPath } }
                    )
                )
            } else {
                Text(item.hardwareOrPath)
                    .font(.system(size: 11, weight: .semibold, design: .monospaced))
                    .foregroundStyle(.primary)
            }

            // Bottom Row: Options on Left + Dedicated Per-Card Action Button on Right
            HStack(spacing: 10) {
                if item.kind == .physicalBurner || item.kind == .networkBurner {
                } else if item.kind == .discImage {
                    Toggle(KroutonL10n.tr("Compress Image"), isOn: Binding(
                        get: { item.compressAfterCreation },
                        set: { val in store.updateQueueItem(cardID) { $0.compressAfterCreation = val } }
                    ))
                    .font(.caption)
                }

                Spacer(minLength: 4)

                // Only show per-card action button when multiple destinations are queued
                // (avoids duplicating the primary green action button at the bottom of the column!)
                if store.destinationQueue.count > 1 {
                    Button {
                        store.executeSingleDestination(item, driveManager: driveManager, primarySelectedDrive: primarySelectedDrive, enableCustomFinderLayoutTab: enableCustomFinderLayoutTab, finderIconSize: finderIconSize)
                    } label: {
                        HStack(spacing: 5) {
                            Image(systemName: store.cardActionSymbol(for: item.kind))
                                .font(.system(size: 10, weight: .bold))
                            if !isRightQueueCompact {
                                Text(KroutonL10n.tr(store.cardActionTitle(for: item.kind)))
                                    .font(.system(size: 11, weight: .bold, design: .rounded))
                                    .lineLimit(1)
                            }
                        }
                        .padding(.horizontal, 10)
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
            .background(Color.kroutonWindowSurface)
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(store.uiSecondaryAccent.opacity(0.35), lineWidth: 1))
    }

}

// MARK: - Pure SwiftUI Disc Image Destination Path Row (.fileExporter)
struct KroutonDiscImagePlaceholderDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.data, .diskImage] }
    init() {}
    init(configuration: ReadConfiguration) throws {}
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: Data())
    }
}

struct KroutonDiscImageTargetRowView: View {
    let defaultVolumeTitle: String
    @Binding var pathText: String
    @State private var isShowingSaveExporter: Bool = false

    var body: some View {
        HStack(spacing: 6) {
            TextField("~/Desktop/Krouton_Master.dmg", text: $pathText)
                .textFieldStyle(.roundedBorder)
                .font(.system(size: 11, design: .monospaced))
            Button("Save As...") {
                isShowingSaveExporter = true
            }
            .controlSize(.small)
            .fileExporter(
                isPresented: $isShowingSaveExporter,
                document: KroutonDiscImagePlaceholderDocument(),
                contentType: .diskImage,
                defaultFilename: "\(defaultVolumeTitle).dmg"
            ) { result in
                if case .success(let savedURL) = result {
                    pathText = savedURL.path
                }
            }
        }
    }
}
