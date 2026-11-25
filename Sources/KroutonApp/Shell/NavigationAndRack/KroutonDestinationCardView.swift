import DriveKit
import Foundation
import NetworkSpool
import OpticalCore
import SwiftUI
import UniformTypeIdentifiers

// MARK: - Standalone UUID-Safe Destination Rack Card View

struct KroutonDestinationCardView: View {
    var store: KroutonStateStore
    var driveManager: KroutonOpticalDriveBank
    var spoolClient: SpoolRemoteNodeClient = .shared
    let item: KroutonBakeBatchItem
    let isRightQueueCompact: Bool
    let primarySelectedDrive: KroutonOpticalDriveInfo?

    @State var activeDiscPopoverCardID: UUID? = nil

    var body: some View {
        let cardID = item.id

        // Drives claimed by OTHER destination cards in the queue
        let otherUsedDriveIDs = Set(
            store.destinationQueue
                .filter { $0.id != cardID && $0.kind == .physicalBurner && !$0.targetDriveID.isEmpty }
                .map { $0.targetDriveID }
        )

        // Resolve THIS card's drive strictly from unclaimed drives (never steal a drive in otherUsedDriveIDs!)
        let cardDrive: KroutonOpticalDriveInfo? = {
            if let exact = driveManager.availableDrives.first(where: { $0.id == item.targetDriveID && !otherUsedDriveIDs.contains($0.id) }) {
                return exact
            }
            return driveManager.availableDrives.first(where: { !otherUsedDriveIDs.contains($0.id) })
        }()

        let activeCardDriveID = (item.kind == .networkBurner) ? "network-spool-drive" : (cardDrive?.id ?? "")

        let scopeTel = driveManager.telemetryForDrive(activeCardDriveID)
        let isFloatingOpen = scopeTel?.isFloatingWindowOpen ?? false
        let isInlineVisible = ((scopeTel?.isActive ?? false) || (scopeTel?.isManuallyPinnedInline ?? false)) && !isFloatingOpen

        return VStack(alignment: .leading, spacing: 10) {
            // Top Row: USB Burner / USB Menu + Scope + Icon-Only Eject + Remove Card
            destinationCardTopHeaderBar

            if item.kind == .physicalBurner {
                activePoolTicketSlotBanner
                physicalBurnerDriveAndSpeedSection
                physicalBurnerBatchAndOptionsSection
            } else if item.kind == .networkBurner {
                NetworkSpoolDriveCardSectionView(
                    store: store,
                    driveManager: driveManager,
                    item: item,
                    activeCardDriveID: activeCardDriveID,
                    isFloatingOpen: isFloatingOpen,
                    isInlineVisible: isInlineVisible,
                    onUpdateHost: { newHost in
                        store.updateQueueItem(cardID) { $0.hardwareOrPath = newHost }
                    },
                    onUpdateDrive: { driveID in
                        store.updateQueueItem(cardID) { $0.targetDriveID = driveID }
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
                        store.executeSingleDestination(item, driveManager: driveManager, primarySelectedDrive: primarySelectedDrive)
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
                KroutonMiniPhaseScopeView(telemetry: scopeTel, accent: store.uiSecondaryAccent) {
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
        .contextMenu {
            Button(KroutonL10n.tr("Execute Only This Destination")) {
                store.executeSingleDestination(item, driveManager: driveManager, primarySelectedDrive: primarySelectedDrive)
            }
            .keyboardShortcut("b", modifiers: .command)
            .disabled(driveManager.isExecutingQueue)
            if item.kind == .physicalBurner || item.kind == .networkBurner {
                Button(KroutonL10n.tr("Open Floating Phase Scope Telemetry")) {
                    KroutonWindowManager.shared.openFloatingPhaseScopeWindow(driveID: activeCardDriveID)
                }.keyboardShortcut("p", modifiers: [.command, .option])
                Button(KroutonL10n.tr("Run Phase Scope Diagnostic Sweep")) {
                    driveManager.runPhaseScopeTestSweep(for: activeCardDriveID, keepPinnedAfterSweep: true)
                }.keyboardShortcut("p", modifiers: [.command, .shift])
                Button(KroutonL10n.tr("Eject Optical Disc")) {
                    driveManager.ejectDrive(id: activeCardDriveID)
                }.keyboardShortcut("e", modifiers: .command)
                Menu(KroutonL10n.tr("Erase RW")) {
                    Button(KroutonL10n.tr("Quick Erase")) {
                        driveManager.eraseRewritableDisc(driveID: activeCardDriveID, fullErase: false) { _ in }
                    }
                    Button(KroutonL10n.tr("Full Erase")) {
                        driveManager.eraseRewritableDisc(driveID: activeCardDriveID, fullErase: true) { _ in }
                    }
                }
                .disabled(driveManager.isExecutingQueue)
            }
            Divider()
            Button(KroutonL10n.tr("Copy Target Hardware / Path")) {
                KroutonOSDesktopBridge.copyTextToClipboard(item.hardwareOrPath)
            }
            if store.destinationQueue.count > 1 {
                Divider()
                Button(role: .destructive) {
                    store.destinationQueue.removeAll { $0.id == cardID }
                } label: {
                    Text(KroutonL10n.tr("Remove Destination Card"))
                }
            }
        }
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
    var onSaveAsURLSelected: ((URL) -> Void)? = nil
    @State private var isShowingSaveExporter: Bool = false

    private var resolvedDefaultFilename: String {
        let ext = URL(fileURLWithPath: (pathText as NSString).expandingTildeInPath).pathExtension.lowercased()
        let activeExt = ["dmg", "iso", "cue"].contains(ext) ? ext : "dmg"
        let cleanBase = defaultVolumeTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Krouton_Master" : defaultVolumeTitle
        return "\(cleanBase).\(activeExt)"
    }

    var body: some View {
        HStack(spacing: 6) {
            TextField("~/Desktop/Krouton_Master.dmg", text: $pathText)
                .textFieldStyle(.roundedBorder)
                .font(.system(size: 11, design: .monospaced))
            Button(KroutonL10n.tr("Save As...")) {
                isShowingSaveExporter = true
            }
            .controlSize(.small)
            .fileExporter(
                isPresented: $isShowingSaveExporter,
                document: KroutonDiscImagePlaceholderDocument(),
                contentType: .diskImage,
                defaultFilename: resolvedDefaultFilename
            ) { result in
                if case .success(let savedURL) = result {
                    try? FileManager.default.removeItem(at: savedURL)
                    pathText = savedURL.path
                    onSaveAsURLSelected?(savedURL)
                }
            }
        }
    }

}

extension KroutonDestinationCardView {
    @ViewBuilder
    func speedPickerMenu(cardID: UUID, validSpeeds: [String], activeSpd: String, shortSpd: String) -> some View {
        Menu {
            ForEach(validSpeeds, id: \.self) { spd in
                Button { store.updateQueueItem(cardID) { $0.speedOrCodec = spd } } label: {
                    HStack { if activeSpd == spd { Image(systemName: "checkmark") }; Text(spd) }
                }
            }
        } label: {
            HStack(spacing: 3) {
                Image(systemName: "gauge.with.dots.needle.67percent").font(.system(size: 9.5)).foregroundStyle(store.uiSecondaryAccent)
                Text(shortSpd).font(.system(size: 10.5, weight: .semibold, design: .monospaced)).foregroundStyle(.primary).lineLimit(1)
                Image(systemName: "chevron.up.chevron.down").font(.system(size: 9, weight: .bold)).foregroundStyle(.secondary)
            }
            .padding(.horizontal, 6).padding(.vertical, 3)
            .background(Color.primary.opacity(0.06)).clipShape(RoundedRectangle(cornerRadius: 6))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Write Speed")
        .accessibilityValue(activeSpd)
        .help("Write Speed: \(activeSpd)")
    }

    @ViewBuilder
    func simCheckboxToggle(cardID: UUID, label: String) -> some View {
        Toggle(isOn: Binding(get: { item.simulationMode }, set: { val in store.updateQueueItem(cardID) { $0.simulationMode = val } })) {
            Text(label).font(.system(size: 10.5, weight: .medium)).lineLimit(1)
        }
        .toggleStyle(.checkbox).controlSize(.small)
        .accessibilityLabel(KroutonL10n.tr("Simulate Burn"))
        .help("Simulate Burn (Test laser write without committing to media)")
    }

    @ViewBuilder
    func verifyCheckboxToggle(cardID: UUID) -> some View {
        Toggle(isOn: Binding(get: { item.verifyAfterBurn }, set: { val in store.updateQueueItem(cardID) { $0.verifyAfterBurn = val } })) {
            Text(KroutonL10n.tr("Verify")).font(.system(size: 10.5, weight: .medium)).lineLimit(1)
        }
        .toggleStyle(.checkbox).controlSize(.small)
        .help("Verify written sectors against source image/files after burn")
    }

    @ViewBuilder
    func copiesStepperView(cardID: UUID) -> some View {
        Stepper(value: Binding(
            get: { max(item.copiesToBurn, store.poolTotalCopies) },
            set: { n in store.setPoolTotalCopies(n, driveManager: driveManager) }
        ), in: 1...99) {
            let count = max(item.copiesToBurn, store.poolTotalCopies)
            Text("\(count)×").font(.system(size: 10.5, weight: count > 1 ? .bold : .semibold, design: .monospaced)).lineLimit(1)
        }
        .controlSize(.small)
        .help("Total copies in burn pool: \(max(item.copiesToBurn, store.poolTotalCopies))")
    }
}
