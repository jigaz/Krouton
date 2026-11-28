import AudioKit
import DriveKit
import Foundation
import NetworkSpool
import OpticalCore
import SwiftUI
import UniformTypeIdentifiers

// MARK: - Destination Card

/// One card in the destination queue (the right-hand column): where the deck goes, such as a
/// burner on this Mac, a Krouton Server, a disc image file, a rip folder or a label export.
/// The card's settings live in its `KroutonBakeBatchItem`; every change goes through
/// `store.updateQueueItem`, keyed by the card's `id`.
struct KroutonDestinationCardView: View {
    var store: KroutonStateStore
    var driveManager: KroutonOpticalDriveBank
    var spoolClient: SpoolRemoteNodeClient = .shared
    let item: KroutonBakeBatchItem
    @Environment(\.kroutonLayout) var windowLayout
    var isRightQueueCompact: Bool { windowLayout.queue == .narrow }
    let primarySelectedDrive: KroutonOpticalDriveInfo?

    @State var activeDiscPopoverCardID: UUID? = nil

    var body: some View {
        let cardID = item.id

        // Drives that other cards in the queue have claimed.
        let otherUsedDriveIDs = Set(
            store.destinationQueue
                .filter { $0.id != cardID && $0.kind == .physicalBurner && !$0.targetDriveID.isEmpty }
                .map { $0.targetDriveID }
        )

        // This card's drive comes only from the unclaimed ones, never from another card.
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
            // Top row: the kind of card, the Phase Scope button, eject and remove.
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
                Text(verbatim: item.hardwareOrPath)
                    .font(.system(size: 11, weight: .semibold, design: .monospaced))
                    .foregroundStyle(.primary)
                if item.kind == .audioRip {
                    KroutonRipCodecPickerView(codec: Binding(
                        get: { item.ripCodec },
                        set: { codec in store.updateQueueItem(cardID) { $0.setRipCodec(codec) } }
                    ))
                    .fixedSize()
                    .help("The format this card rips to. Each album gets its own folder inside the one shown.")
                }
            }

            // Bottom row: options on the left, this card's own action button on the right.
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

                // Only with two or more cards: with one, it would repeat the column's main button.
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
                    .help("Run only this card (\(item.kind.title))")
                }
            }

            // The small Phase Scope: shown while the drive works or when pinned with the Scope
            // button, unless it is open in its own window.
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
            Button(KroutonL10n.tr("Run This Card Only")) {
                store.executeSingleDestination(item, driveManager: driveManager, primarySelectedDrive: primarySelectedDrive)
            }
            .keyboardShortcut("b", modifiers: .command)
            .disabled(driveManager.isExecutingQueue)
            if item.kind == .physicalBurner || item.kind == .networkBurner {
                Button(KroutonL10n.tr("Phase Scope Window")) {
                    KroutonWindowManager.shared.openFloatingPhaseScopeWindow(driveID: activeCardDriveID)
                }.keyboardShortcut("p", modifiers: [.command, .option])
                Button(KroutonL10n.tr("Reset Phase Scope")) {
                    driveManager.runPhaseScopeTestSweep(for: activeCardDriveID, keepPinnedAfterSweep: true)
                }.keyboardShortcut("p", modifiers: [.command, .shift])
                Button(KroutonL10n.tr("Eject Disc")) {
                    driveManager.ejectDrive(id: activeCardDriveID)
                }.keyboardShortcut("e", modifiers: .command)
                Menu(KroutonL10n.tr("Erase Rewritable Disc")) {
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
            Button(KroutonL10n.tr("Copy Drive or Path")) {
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

// MARK: - Disc Image Card's Path Row

/// An empty document for the Save As panel, which only picks a path: the file the panel
/// creates is deleted at once, and the image is written there when the card runs.
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
        .help("Go through the burn without writing to the disc, to test the drive and settings")
    }

    @ViewBuilder
    func verifyCheckboxToggle(cardID: UUID) -> some View {
        Toggle(isOn: Binding(get: { item.verifyAfterBurn }, set: { val in store.updateQueueItem(cardID) { $0.verifyAfterBurn = val } })) {
            Text(KroutonL10n.tr("Verify")).font(.system(size: 10.5, weight: .medium)).lineLimit(1)
        }
        .toggleStyle(.checkbox).controlSize(.small)
        .help("After the burn, read the disc back and compare it with the source")
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
