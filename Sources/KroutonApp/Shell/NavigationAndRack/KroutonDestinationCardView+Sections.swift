import Foundation
import OpticalCore
import SwiftUI

// MARK: - KroutonDestinationCardView — Sections

extension KroutonDestinationCardView {
    @ViewBuilder
    var destinationCardTopHeaderBar: some View {
        let cardID = item.id

        // Drives that other cards in the queue have claimed.
        let otherUsedDriveIDs = Set(
            store.destinationQueue
                .filter { $0.id != cardID && $0.kind == .physicalBurner && !$0.targetDriveID.isEmpty }
                .map { $0.targetDriveID }
        )

        // This card's drive comes only from the unclaimed ones, never from another card.
        let hasUnclaimedPhysicalBurner = driveManager.availableDrives.contains(where: { !otherUsedDriveIDs.contains($0.id) })
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

        let isDriveBusy = driveManager.isExecutingQueue || (scopeTel?.isActive == true)
        let canEject = (cardDrive?.isMediaPresent == true) && !isDriveBusy
        HStack(spacing: 5) {
                if let discNum = item.spannedDiscNumber {
                    Text("DISC \(discNum)")
                        .font(.system(size: 9, weight: .heavy, design: .monospaced))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2.5)
                        .background(store.uiSecondaryAccent.opacity(0.22))
                        .foregroundStyle(store.uiSecondaryAccent)
                        .clipShape(Capsule())
                }
                Menu {
                    ForEach(store.allowedDestinationsForCurrentCategory) { kind in
                        let isUSBAlreadyExhausted = (kind == .physicalBurner && item.kind != .physicalBurner && !hasUnclaimedPhysicalBurner)
                        Button {
                            guard !isUSBAlreadyExhausted else { return }
                            store.updateQueueItem(cardID) { qItem in
                                qItem.kind = kind
                                switch kind {
                                case .physicalBurner:
                                    if let freeDrive = driveManager.availableDrives.first(where: { !otherUsedDriveIDs.contains($0.id) }) {
                                        qItem.targetDriveID = freeDrive.id
                                        qItem.hardwareOrPath = freeDrive.displayName
                                    }
                                case .networkBurner:
                                    qItem.targetDriveID = ""
                                    if spoolClient.server(withID: qItem.hardwareOrPath) == nil {
                                        qItem.hardwareOrPath = spoolClient.pairedServers.first?.nodeID ?? ""
                                    }
                                case .discImage:
                                    let imgTarget = store.defaultDiscImageTarget
                                    qItem.targetDriveID = ""
                                    qItem.hardwareOrPath = imgTarget.path
                                    qItem.speedOrCodec = imgTarget.description
                                case .audioRip:
                                    qItem.becomeAudioRip()
                                case .videoExtract, .discPrinter, .pdfVector:
                                    let preset = kind == .videoExtract ? KroutonBakeBatchItem.videoExtract() : KroutonBakeBatchItem.label(kind)
                                    qItem.targetDriveID = ""
                                    qItem.hardwareOrPath = preset.hardwareOrPath
                                    qItem.speedOrCodec = preset.speedOrCodec
                                }
                            }
                            store.reconcileUniqueDriveAssignments(driveManager: driveManager)
                        } label: {
                            HStack {
                                if item.kind == kind { Image(systemName: "checkmark") }
                                Text(
                                    kind == .physicalBurner
                                        ? (isUSBAlreadyExhausted ? KroutonL10n.tr("USB Burner — In Use") : KroutonL10n.tr("USB Burner"))
                                        : KroutonL10n.tr(kind.title)
                                )
                            }
                        }
                        .disabled(isUSBAlreadyExhausted)
                    }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: item.kind.sfSymbol)
                            .foregroundStyle(store.uiSecondaryAccent)
                        Text(
                            isRightQueueCompact ? item.kind.compactBadgeTitle : (item.kind == .physicalBurner ? KroutonL10n.tr("USB Burner") : KroutonL10n.tr(item.kind.title))
                        )
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                        Image(systemName: "chevron.up.chevron.down")
                            .font(.system(size: 9, weight: .bold))
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
                        withAnimation(kroutonMotion(.spring(response: 0.28, dampingFraction: 0.82))) {
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
                    .accessibilityLabel(isFloatingOpen ? "Dock Phase Scope Inline" : "Toggle Phase Scope")
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
                        .accessibilityLabel("Eject \(cardDrive?.displayName ?? "Disc")")
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
                    .accessibilityLabel(KroutonL10n.tr("Remove Destination Card"))
                    .help(KroutonL10n.tr("Remove Destination Card"))
                }
            }
    }
}
