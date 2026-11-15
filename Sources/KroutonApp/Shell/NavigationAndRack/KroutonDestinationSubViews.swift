import NetworkSpool
import DriveKit
import SwiftUI
import Foundation
import UniformTypeIdentifiers
import OpticalCore

// MARK: - Standalone Right Destination Rack Column View

struct KroutonDestinationRackColumnView: View {
    @ObservedObject var store: KroutonStateStore
    @ObservedObject var driveManager: KroutonOpticalDriveBank
    let isRightQueueCompact: Bool
    let enableCustomFinderLayoutTab: Bool
    let finderIconSize: Double
    let primarySelectedDrive: KroutonOpticalDriveInfo?
    @ObservedObject var burnSet: KroutonBurnSetController = .shared
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
                .padding(.horizontal, isRightQueueCompact ? 10 : 12)
                .padding(.vertical, 12)
                .frame(maxWidth: .infinity)
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

// MARK: - Dedicated Reactive Subview for Krumb Port 7420 Network Toaster Cards
struct NetworkSpoolDriveCardSectionView: View {
    @ObservedObject var store: KroutonStateStore
    @ObservedObject var driveManager: KroutonOpticalDriveBank
    @ObservedObject var spoolClient: SpoolRemoteNodeClient = .shared

    let item: KroutonBakeBatchItem
    let activeCardDriveID: String
    let isFloatingOpen: Bool
    let isInlineVisible: Bool
    let onUpdateHost: (String) -> Void

    var body: some View {
        let firstOpticalDrive = spoolClient.remoteDrives.first
        VStack(alignment: .leading, spacing: 7) {
            HStack(spacing: 6) {
                Image(systemName: "server.rack")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(store.uiSecondaryAccent)
                let validHosts = spoolClient.discoveredNodes.map(\.hostPort)
                let resolvedHost = validHosts.contains(item.hardwareOrPath)
                    ? item.hardwareOrPath
                    : (spoolClient.discoveredNodes.first?.hostPort ?? "localhost:7420")

                Picker("", selection: Binding(
                    get: { resolvedHost },
                    set: { newHost in
                        onUpdateHost(newHost)
                        spoolClient.activeEndpointHost = newHost
                    }
                )) {
                    ForEach(spoolClient.discoveredNodes) { node in
                        Text("\(node.name) (\(node.hostPort))").tag(node.hostPort)
                    }
                }
                .labelsHidden()
                .accessibilityLabel("Remote Optical Spool Server Node")

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
                            // Opening the scope only shows it. It no longer starts a spool job.
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
                .help("Stream remote spool telemetry directly into the Phase Scope")
            }

            HStack(spacing: 6) {
                Circle()
                    .fill(store.uiSecondaryAccent)
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
                Button {
                    Task {
                        await spoolClient.refreshRemoteDrives(endpoint: item.hardwareOrPath)
                    }
                } label: {
                    Label("Refresh", systemImage: "arrow.clockwise")
                        .font(.system(size: 9.5, weight: .bold))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(store.uiSecondaryAccent.opacity(0.16))
                        .foregroundStyle(store.uiSecondaryAccent)
                        .clipShape(Capsule())
                    .fixedSize(horizontal: true, vertical: false)
                }
                .buttonStyle(.plain)

                Button {
                    Task {
                        await spoolClient.runSpoolCalibration(endpoint: item.hardwareOrPath)
                    }
                } label: {
                    Label("Test Cache", systemImage: "gauge.with.dots.needle.67percent")
                        .font(.system(size: 9.5, weight: .bold))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(store.activeAccent.opacity(0.16))
                        .foregroundStyle(store.activeAccent)
                        .clipShape(Capsule())
                    .fixedSize(horizontal: true, vertical: false)
                }
                .buttonStyle(.plain)

                if let remoteDrive = firstOpticalDrive {
                    Button {
                        Task {
                            await spoolClient.toggleDriveTray(driveID: remoteDrive.id, endpoint: item.hardwareOrPath)
                        }
                    } label: {
                        Label(remoteDrive.rackState == .open ? "Close Tray" : "Identify", systemImage: "eject.fill")
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
