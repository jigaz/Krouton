import DriveKit
import Foundation
import NetworkSpool
import OpticalCore
import SwiftUI
import UniformTypeIdentifiers

// MARK: - Standalone Right Destination Rack Column View

struct KroutonDestinationRackColumnView: View {
    var store: KroutonStateStore
    var driveManager: KroutonOpticalDriveBank
    let isRightQueueCompact: Bool
    let primarySelectedDrive: KroutonOpticalDriveInfo?
    var burnSet: KroutonBurnSetController = .shared
    @State private var showBurnSetSheet = false

    /// Multi-disc sets are built from the staged file list, so they are offered for data workflows only.
    private var offersMultiDiscSet: Bool {
        store.selectedCategory == .burn
            && store.discFormats.first(where: { $0.id == store.selectedTaskID })?.workspaceKind == .dataAndArchival
    }

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

            // Two-Zone Queue: Upper Active Assigned Burners (Primary Accent) + Visual Divider + Lower Waiting Pool (Secondary Accent)
            ScrollView {
                VStack(spacing: 12) {
                    ForEach(store.destinationQueue) { item in
                        KroutonDestinationCardView(
                            store: store,
                            driveManager: driveManager,
                            item: item,
                            isRightQueueCompact: isRightQueueCompact,
                            primarySelectedDrive: primarySelectedDrive
                        )
                    }

                    if shouldShowBurnPoolZone {
                        waitingBurnPoolDividerAndZone
                    }
                }
                .padding(.horizontal, isRightQueueCompact ? 10 : 12)
                .padding(.vertical, 12)
                .frame(maxWidth: .infinity)
            }
            .onAppear {
                store.syncSpannedDestinations(driveManager: driveManager)
            }
            .onChange(of: store.activeSpannedDiscLabels()) { _, _ in
                store.syncSpannedDestinations(driveManager: driveManager)
            }
            .onChange(of: store.audioController.project) { _, _ in
                store.syncSpannedDestinations(driveManager: driveManager)
            }
            .onChange(of: driveManager.availableDrives) { _, _ in
                store.syncSpannedDestinations(driveManager: driveManager)
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
                    store.executeDestinationQueue(driveManager: driveManager, primarySelectedDrive: primarySelectedDrive)
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: driveManager.isExecutingQueue ? "stop.circle.fill" : store.primaryActionSymbol)
                            .font(.system(size: 14, weight: .bold))
                        Text(driveManager.isExecutingQueue ? "ABORT OPERATION" : store.primaryActionTitle)
                            .font(.system(size: 13.5, weight: .heavy, design: .rounded))
                            .lineLimit(1)
                            .minimumScaleFactor(0.82)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, 18)
                    .padding(.vertical, 12)
                    .background(driveManager.isExecutingQueue ? Color.red : store.activeAccent)
                    .foregroundStyle(driveManager.isExecutingQueue ? Color.white : store.activeOnAccentText)
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)
                .disabled(burnSet.isBusy) // the drives belong to the running set

                Text(store.queueStatusSummaryText)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)

                if offersMultiDiscSet || burnSet.phase != .idle {
                    Button {
                        showBurnSetSheet = true
                    } label: {
                        Label(burnSet.isBusy ? "Multi-Disc Set in Progress..." : "Burn as Multi-Disc Set...",
                              systemImage: "square.stack.3d.up.fill")
                            .font(.system(size: 11, weight: .semibold))
                            .lineLimit(1)
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(store.activeAccent)
                    .disabled(driveManager.isExecutingQueue)
                    .help("Split the staged files across several discs, burn them on every connected burner, and verify each one")
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
        }
        .background(store.enableSecondaryAccentUITints ? store.activeAccent.opacity(0.11) : Color.clear)
        .background(Color.kroutonControlSurface)
        .sheet(isPresented: $showBurnSetSheet) {
            KroutonBurnSetSheetView(store: store)
        }
    }
}

// MARK: - Network Burner Card Section (Krouton Server)
struct NetworkSpoolDriveCardSectionView: View {
    var store: KroutonStateStore
    var driveManager: KroutonOpticalDriveBank
    var spoolClient: SpoolRemoteNodeClient = .shared

    let item: KroutonBakeBatchItem
    let activeCardDriveID: String
    let isFloatingOpen: Bool
    let isInlineVisible: Bool
    let onUpdateHost: (String) -> Void
    let onUpdateDrive: (String) -> Void

    private var selectedServerID: String {
        spoolClient.server(withID: item.hardwareOrPath)?.nodeID ?? spoolClient.pairedServers.first?.nodeID ?? ""
    }

    private var isConnectedToSelection: Bool {
        !selectedServerID.isEmpty && spoolClient.connectedServerID == selectedServerID
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack(spacing: 6) {
                Image(systemName: "server.rack")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(store.uiSecondaryAccent)
                if spoolClient.pairedServers.isEmpty {
                    Text(KroutonL10n.tr("Pair a Krouton Server in Settings › Burners & Network"))
                        .font(.system(size: 10.5, weight: .semibold))
                        .foregroundStyle(.secondary)
                } else {
                    Picker("", selection: Binding(
                        get: { selectedServerID },
                        set: { newID in
                            onUpdateHost(newID)
                            onUpdateDrive("")
                            Task { await spoolClient.refreshRemoteDrives(serverID: newID) }
                        }
                    )) {
                        ForEach(spoolClient.discoveredNodes) { node in
                            Text(node.name).tag(node.id)
                        }
                    }
                    .labelsHidden()
                    .accessibilityLabel("Krouton Server")
                }
                Spacer(minLength: 4)
                scopeButton
            }

            if isConnectedToSelection, !spoolClient.remoteDrives.isEmpty {
                Picker("", selection: Binding(
                    get: { item.targetDriveID.isEmpty ? (spoolClient.remoteDrives.first?.id ?? "") : item.targetDriveID },
                    set: { onUpdateDrive($0) }
                )) {
                    ForEach(spoolClient.remoteDrives) { drive in
                        Text("\(drive.name) (\(KroutonSettingsWindowView.describe(drive)))").tag(drive.id)
                    }
                }
                .labelsHidden()
                .accessibilityLabel("Drive on the Krouton Server")
            }

            HStack(spacing: 6) {
                Circle()
                    .fill(isConnectedToSelection ? store.uiSecondaryAccent : Color.secondary)
                    .frame(width: 7, height: 7)
                Text(spoolClient.statusBannerText)
                    .font(.system(size: 9.5, weight: .semibold, design: .monospaced))
                    .foregroundStyle(store.uiSecondaryAccent)
                    .lineLimit(1)
                Spacer(minLength: 0)
            }

            if spoolClient.isSpoolingImage {
                ProgressView(value: spoolClient.spoolProgressFraction, total: 1.0)
                    .tint(store.activeAccent)
                    .controlSize(.small)
            }

            HStack(spacing: 6) {
                capsuleButton(isConnectedToSelection ? "Refresh" : "Connect", symbol: "arrow.clockwise", tint: store.uiSecondaryAccent) {
                    Task { await spoolClient.refreshRemoteDrives(serverID: selectedServerID) }
                }
                .disabled(selectedServerID.isEmpty)
                if isConnectedToSelection, let drive = spoolClient.remoteDrives.first(where: { $0.id == item.targetDriveID }) ?? spoolClient.remoteDrives.first {
                    capsuleButton("Eject", symbol: "eject.fill", tint: .primary) {
                        Task { await spoolClient.ejectRemoteDrive(drive.id, serverID: selectedServerID) }
                    }
                    .disabled(drive.busy)
                }
                Spacer(minLength: 0)
            }
        }
        .task(id: selectedServerID) {
            if !selectedServerID.isEmpty, !isConnectedToSelection {
                await spoolClient.refreshRemoteDrives(serverID: selectedServerID)
            }
        }
    }

    private var scopeButton: some View {
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
            .fixedSize(horizontal: true, vertical: false)
        }
        .buttonStyle(.plain)
        .help("Show the remote burn's live telemetry in the Phase Scope")
    }

    private func capsuleButton(_ title: String, symbol: String, tint: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: symbol)
                .font(.system(size: 9.5, weight: .bold))
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(tint.opacity(0.16))
                .foregroundStyle(tint)
                .clipShape(Capsule())
                .fixedSize(horizontal: true, vertical: false)
        }
        .buttonStyle(.plain)
    }
}
