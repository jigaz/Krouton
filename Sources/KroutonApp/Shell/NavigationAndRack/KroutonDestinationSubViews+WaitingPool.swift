import DriveKit
import Foundation
import OpticalCore
import SwiftUI

// MARK: - Burner Card's Ticket Banner and the Waiting Pool

extension KroutonDestinationCardView {
    @ViewBuilder
    var activePoolTicketSlotBanner: some View {
        let cardID = item.id
        let isMultiTicketPool = !store.waitingBurnPool.isEmpty
            || store.poolTotalCopies > 1
            || store.activeSpannedDiscLabels().count > 1
            || item.pendingApprovalTicket != nil

        if isMultiTicketPool {
            if let pending = item.pendingApprovalTicket {
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 6) {
                        Image(systemName: "hand.raised.circle.fill")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(store.uiSecondaryAccent)
                        VStack(alignment: .leading, spacing: 1) {
                            Text("NEXT IN LINE READY: \(pending.badgeTitle.uppercased())")
                                .font(.system(size: 9.5, weight: .heavy, design: .monospaced))
                                .foregroundStyle(store.uiSecondaryAccent)
                            Text("Insert blank disc & approve to assign '\(pending.volumeLabel)' to this burner.")
                                .font(.system(size: 10))
                                .foregroundStyle(.secondary)
                        }
                        Spacer(minLength: 0)
                    }
                    HStack(spacing: 6) {
                        Button {
                            withAnimation(kroutonMotion(.spring(response: 0.26, dampingFraction: 0.82))) {
                                store.approvePendingTicketOnCard(cardID)
                            }
                        } label: {
                            Label("Approve & Assign", systemImage: "arrow.up.circle.fill")
                                .font(.system(size: 10, weight: .bold))
                                .padding(.horizontal, 9)
                                .padding(.vertical, 4)
                                .background(store.activeAccent)
                                .foregroundStyle(store.activeOnAccentText)
                                .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)

                        Button {
                            withAnimation(kroutonMotion(.spring(response: 0.26, dampingFraction: 0.82))) {
                                store.skipDriveForPendingTicket(onCardID: cardID)
                            }
                        } label: {
                            Label("Return to Waiting Pool", systemImage: "arrow.down.to.line.compact")
                                .font(.system(size: 10, weight: .semibold))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(store.uiSecondaryAccent.opacity(0.18))
                                .foregroundStyle(store.uiSecondaryAccent)
                                .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
                        Spacer(minLength: 0)
                    }
                }
                .padding(8)
                .background(store.uiSecondaryAccent.opacity(0.14))
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(store.uiSecondaryAccent.opacity(0.45), lineWidth: 1))
            } else if let assigned = item.assignedPoolTicket {
                HStack(spacing: 6) {
                    Image(systemName: "flame.circle.fill")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(store.activeAccent)
                    VStack(alignment: .leading, spacing: 1) {
                        HStack(spacing: 5) {
                            Text("ACTIVE SLOT • \(assigned.badgeTitle.uppercased())")
                                .font(.system(size: 9.5, weight: .heavy, design: .monospaced))
                                .foregroundStyle(store.activeAccent)
                            Text(assigned.volumeLabel)
                                .font(.system(size: 10, weight: .semibold, design: .monospaced))
                                .foregroundStyle(.primary)
                                .lineLimit(1)
                        }
                    }
                    Spacer(minLength: 4)
                    if !store.waitingBurnPool.isEmpty {
                        Button {
                            withAnimation(kroutonMotion(.spring(response: 0.26, dampingFraction: 0.82))) {
                                _ = store.advancePoolAfterCardBurnCompleted(cardID: cardID)
                            }
                        } label: {
                            HStack(spacing: 3) {
                                Image(systemName: "checkmark.circle")
                                Text("Next")
                            }
                            .font(.system(size: 9.5, weight: .bold))
                            .padding(.horizontal, 7)
                            .padding(.vertical, 3)
                            .background(store.activeAccent.opacity(0.16))
                            .foregroundStyle(store.activeAccent)
                            .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
                        .help("Mark this slot's current disc finished and pull the next waiting task from the pool")
                    }
                    Button {
                        withAnimation(kroutonMotion(.spring(response: 0.26, dampingFraction: 0.82))) {
                            store.demoteAssignedTicketToWaitingPool(fromCardID: cardID)
                        }
                    } label: {
                        Image(systemName: "arrow.down.circle")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(store.uiSecondaryAccent)
                    }
                    .buttonStyle(.plain)
                    .help("Move this task back down into the Waiting Burn Pool")
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
                .background(store.activeAccent.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 7))
                .overlay(RoundedRectangle(cornerRadius: 7).stroke(store.activeAccent.opacity(0.35), lineWidth: 1))
            } else {
                HStack(spacing: 6) {
                    Image(systemName: "tray.and.arrow.down.fill")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.secondary)
                    Text("BURNER AVAILABLE • WAITING FOR TASK")
                        .font(.system(size: 9.5, weight: .bold, design: .monospaced))
                        .foregroundStyle(.secondary)
                    Spacer(minLength: 4)
                    if let firstWaiting = store.waitingBurnPool.first {
                        Button {
                            withAnimation(kroutonMotion(.spring(response: 0.26, dampingFraction: 0.82))) {
                                store.promoteWaitingTicket(firstWaiting.id, toCardID: cardID, driveManager: driveManager)
                            }
                        } label: {
                            Label("Pull Next ↑", systemImage: "arrow.up.circle.fill")
                                .font(.system(size: 9.5, weight: .bold))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(store.uiSecondaryAccent)
                                .foregroundStyle(store.activeOnAccentText)
                                .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
                .background(Color.primary.opacity(0.05))
                .clipShape(RoundedRectangle(cornerRadius: 7))
            }
        }
    }
}

// MARK: - KroutonDestinationRackColumnView — Divider and Waiting Pool

extension KroutonDestinationRackColumnView {
    var shouldShowBurnPoolZone: Bool {
        let hasBurner = store.destinationQueue.contains { $0.kind == .physicalBurner }
        guard hasBurner else { return false }
        return !store.waitingBurnPool.isEmpty
            || store.poolTotalCopies > 1
            || store.activeSpannedDiscLabels().count > 1
            || driveManager.availableDrives.count > 1
    }

    @ViewBuilder
    var waitingBurnPoolDividerAndZone: some View {
        let secondaryTint = store.enableSecondaryAccentUITints ? store.activeSecondaryAccent : store.uiSecondaryAccent
        let activeBurnerCards = store.destinationQueue.filter { $0.kind == .physicalBurner }
        let unpooledDriveCount = max(0, driveManager.availableDrives.count - activeBurnerCards.count)

        VStack(alignment: .leading, spacing: 10) {
            // Graphical Visual Divider Separating Upper Active Assigned Queue from Lower Waiting Burn Pool
            VStack(spacing: 6) {
                HStack(spacing: 8) {
                    Rectangle()
                        .fill(LinearGradient(colors: [secondaryTint.opacity(0.15), secondaryTint.opacity(0.85)], startPoint: .leading, endPoint: .trailing))
                        .frame(height: 2)

                    HStack(spacing: 5) {
                        Image(systemName: "arrow.up.arrow.down.circle.fill")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(secondaryTint)
                        Text("WAITING BURN POOL (\(store.waitingBurnPool.count))")
                            .font(.system(size: 10, weight: .heavy, design: .monospaced))
                            .foregroundStyle(secondaryTint)
                            .fixedSize()
                    }
                    .padding(.horizontal, 9)
                    .padding(.vertical, 4)
                    .background(secondaryTint.opacity(0.16))
                    .clipShape(Capsule())
                    .overlay(Capsule().stroke(secondaryTint.opacity(0.48), lineWidth: 1))

                    Rectangle()
                        .fill(LinearGradient(colors: [secondaryTint.opacity(0.85), secondaryTint.opacity(0.15)], startPoint: .leading, endPoint: .trailing))
                        .frame(height: 2)
                }

                // Pool Policy & Multi-Burner Controls Bar
                HStack(spacing: 6) {
                    Menu {
                        ForEach(KroutonPoolDispatchMode.allCases) { mode in
                            Button {
                                store.poolDispatchMode = mode
                            } label: {
                                HStack {
                                    if store.poolDispatchMode == mode { Image(systemName: "checkmark") }
                                    Text(mode.rawValue)
                                }
                            }
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: store.poolDispatchMode.sfSymbol)
                                .font(.system(size: 9.5, weight: .bold))
                            Text(store.poolDispatchMode.rawValue)
                                .font(.system(size: 10, weight: .bold))
                            Image(systemName: "chevron.up.chevron.down")
                                .font(.system(size: 8, weight: .bold))
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(secondaryTint.opacity(0.18))
                        .foregroundStyle(secondaryTint)
                        .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                    .help(store.poolDispatchMode.summaryText)

                    if unpooledDriveCount > 0 {
                        Button {
                            withAnimation(kroutonMotion(.spring(response: 0.28, dampingFraction: 0.82))) {
                                store.poolAllConnectedBurners(driveManager: driveManager)
                            }
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "opticaldiscdrive.fill")
                                Text("Pool +\(unpooledDriveCount) Drive\(unpooledDriveCount == 1 ? "" : "s")")
                            }
                            .font(.system(size: 10, weight: .bold)).padding(.horizontal, 8).padding(.vertical, 4)
                            .background(secondaryTint).foregroundStyle(store.activeOnAccentText).clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
                        .help("Add all connected optical burners to the upper active pool (fastest burner prioritized first)")
                    }

                    Spacer(minLength: 2)

                    Stepper(value: Binding(get: { store.poolTotalCopies }, set: { store.setPoolTotalCopies($0, driveManager: driveManager) }), in: 1...99) {
                        Text("\(store.poolTotalCopies) Cop\(store.poolTotalCopies == 1 ? "y" : "ies")")
                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                            .foregroundStyle(secondaryTint)
                    }
                    .controlSize(.mini)
                }
            }
            .padding(.top, 4)

            // Lower Waiting Area Container (Secondary Harmony Theme Color)
            VStack(alignment: .leading, spacing: 8) {
                if store.waitingBurnPool.isEmpty {
                    HStack(spacing: 8) {
                        Image(systemName: "checkmark.seal.fill")
                            .font(.system(size: 12))
                            .foregroundStyle(secondaryTint)
                        Text("All queued discs are assigned to active burner slots above. Increase Copies or stage a multi-disc spanned set to queue waiting tasks here.")
                            .font(.system(size: 10))
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(10)
                } else {
                    ForEach(Array(store.waitingBurnPool.enumerated()), id: \.element.id) { idx, ticket in
                        waitingPoolTicketRow(index: idx + 1, ticket: ticket, activeBurners: activeBurnerCards, secondaryTint: secondaryTint)
                    }
                }
            }
            .padding(10)
            .background(secondaryTint.opacity(0.13))
            .background(Color.kroutonWindowSurface)
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(style: StrokeStyle(lineWidth: 1.2, dash: [5, 3])).foregroundStyle(secondaryTint.opacity(0.55)))
        }
    }

    @ViewBuilder
    private func waitingPoolTicketRow(
        index: Int,
        ticket: KroutonPoolBurnTicket,
        activeBurners: [KroutonBakeBatchItem],
        secondaryTint: Color
    ) -> some View {
        let sizeText = ByteCountFormatter.string(fromByteCount: max(0, ticket.estimatedBytes), countStyle: .file)
        HStack(spacing: 8) {
            Text("#\(index)")
                .font(.system(size: 10, weight: .heavy, design: .monospaced))
                .foregroundStyle(store.activeOnAccentText)
                .padding(.horizontal, 6)
                .padding(.vertical, 3)
                .background(secondaryTint)
                .clipShape(Capsule())

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(ticket.badgeTitle)
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(.primary)
                    Text(ticket.volumeLabel)
                        .font(.system(size: 10, weight: .semibold, design: .monospaced))
                        .foregroundStyle(secondaryTint)
                        .lineLimit(1)
                }
                Text("\(sizeText) • \(store.poolDispatchMode == .autoAssign ? "Auto-assigns to next free burner" : "Waiting for operator promotion")")
                    .font(.system(size: 9.5))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 4)

            if activeBurners.count <= 1 {
                Button {
                    withAnimation(kroutonMotion(.spring(response: 0.26, dampingFraction: 0.82))) {
                        store.promoteWaitingTicket(ticket.id, toCardID: activeBurners.first?.id, driveManager: driveManager)
                    }
                } label: {
                    HStack(spacing: 3) {
                        Image(systemName: "arrow.up.to.line.compact")
                        if !isRightQueueCompact {
                            Text("Promote")
                                .lineLimit(1)
                                .fixedSize()
                        }
                    }
                    .font(.system(size: 10, weight: .bold)).padding(.horizontal, 8).padding(.vertical, 4)
                    .background(secondaryTint.opacity(0.22)).foregroundStyle(secondaryTint).clipShape(Capsule())
                }
                .buttonStyle(.plain)
                .help("Move this waiting task across the divider into the active burner slot above")
            } else {
                Menu {
                    Button {
                        withAnimation(kroutonMotion(.spring(response: 0.26, dampingFraction: 0.82))) {
                            store.promoteWaitingTicket(ticket.id, toCardID: nil, driveManager: driveManager)
                        }
                    } label: {
                        Label("Promote to Fastest Free Burner", systemImage: "bolt.fill")
                    }
                    Divider()
                    ForEach(activeBurners) { burnerCard in
                        Button {
                            withAnimation(kroutonMotion(.spring(response: 0.26, dampingFraction: 0.82))) {
                                store.promoteWaitingTicket(ticket.id, toCardID: burnerCard.id, driveManager: driveManager)
                            }
                        } label: {
                            Label("Assign to \(burnerCard.hardwareOrPath.isEmpty ? "Burner" : burnerCard.hardwareOrPath)", systemImage: "opticaldiscdrive.fill")
                        }
                    }
                } label: {
                    HStack(spacing: 3) {
                        Image(systemName: "arrow.up.to.line.compact")
                        if !isRightQueueCompact {
                            Text("Assign ↑")
                                .lineLimit(1)
                                .fixedSize()
                        }
                    }
                    .font(.system(size: 10, weight: .bold)).padding(.horizontal, 8).padding(.vertical, 4)
                    .background(secondaryTint.opacity(0.22)).foregroundStyle(secondaryTint).clipShape(Capsule())
                }
                .buttonStyle(.plain)
                .help("Promote this waiting task into an active burner slot above")
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(Color.kroutonControlSurface.opacity(0.85))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(secondaryTint.opacity(0.28), lineWidth: 1))
    }
}
