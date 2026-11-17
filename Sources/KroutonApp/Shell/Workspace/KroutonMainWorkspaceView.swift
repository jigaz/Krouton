import AudioToolbox
import DriveKit
import Foundation
import ImageIO
import NetworkSpool
import OpticalCore
import SwiftUI
import UniformTypeIdentifiers

struct KroutonMainWorkspaceView: View {
    @ObservedObject var store: KroutonStateStore
    @ObservedObject var driveManager: KroutonOpticalDriveBank
    @ObservedObject var spoolClient: SpoolRemoteNodeClient = .shared

    @State var enableCustomFinderLayoutTab: Bool = false
    @State var finderIconSize: Double = 256
    @State var fitToDiscDVD9Shrink: Bool = true
    @State var preserveMenusAndExtras: Bool = true
    @State var leftColumnLiveWidth: CGFloat = 196
    @State var rightColumnLiveWidth: CGFloat = 315
    @State var leftSidebarDragStartWidth: CGFloat? = nil
    @State var rightSidebarDragStartWidth: CGFloat? = nil
    @State var dropRejectShakePhase: CGFloat = 0
    @State var isLeftSidebarCompact: Bool = false
    @State var isLeftSidebarUltraSkinny: Bool = false
    @State var isRightQueueCompact: Bool = false
    @State var isCenterWorkspaceNarrow: Bool = false
    @State var isCenterWorkspaceUltraCompact: Bool = false
    @State var isDropTargeted: Bool = false
    // Red Book Audio CD & CD-Extra Mastering State
    @State var cdTextAlbumTitle: String = ""
    @State var cdTextAlbumPerformer: String = ""
    @State var auditioningTrackID: UUID? = nil
    // Car-Safe MP3 / FLAC CD Mastering State
    // Video Disc Authoring & Dual-Layer Break State
    // M-DISC Archival PAR2 State
    // New Data Disc File System Bridge State
    // Dedicated Disc Image Burner State

    var primarySelectedDrive: KroutonOpticalDriveInfo? {
        if let firstBurnerCard = store.destinationQueue.first(where: { $0.kind == .physicalBurner }),
           let match = driveManager.driveForID(firstBurnerCard.targetDriveID) {
            return match
        }
        return driveManager.selectedDrive ?? driveManager.availableDrives.first
    }

    var activeDiscCapacityBytes: Int64 {
        if let drive = primarySelectedDrive, drive.isMediaPresent, drive.freeBytes > 0 {
            return drive.freeBytes
        }
        if KroutonSpanningDiscMedium.supportsTargetDiscSizeSelection(forFormatID: store.selectedTaskID) {
            return store.resolvedDataDiscMedium(forFormatID: store.selectedTaskID).maxPayloadBytes
        }
        let activeSpec = store.discFormats.first(where: { $0.id == store.selectedTaskID })
        let gb = activeSpec?.capacityGB ?? 4.7
        return Int64(gb * 1_000_000_000.0)
    }

    var body: some View {
        VStack(spacing: 0) {
            topProToolbar
            Divider()
            KroutonCrashRecoveryBannerView(store: store)

            GeometryReader { windowGeo in
                let totalW = windowGeo.size.width
                let minLeftW: CGFloat = 182
                let maxLeftW: CGFloat = 340
                let minCenterW: CGFloat = 345
                let minRightW: CGFloat = 262
                let maxRightW: CGFloat = 440
                let splittersW: CGFloat = 22
                let maxAllowedLeft = max(minLeftW, min(maxLeftW, totalW - max(minRightW, rightColumnLiveWidth) - minCenterW - splittersW))
                let clampedLeft = min(max(minLeftW, leftColumnLiveWidth), maxAllowedLeft)
                let maxAllowedRight = max(minRightW, min(maxRightW, totalW - clampedLeft - minCenterW - splittersW))
                let clampedRight = min(max(minRightW, rightColumnLiveWidth), maxAllowedRight)

                let centerLiveW = max(0, totalW - clampedLeft - clampedRight - 22)

                HStack(spacing: 0) {
                    KroutonLeftFormatChooserColumnView(store: store, driveManager: driveManager, isLeftSidebarUltraSkinny: isLeftSidebarUltraSkinny)
                        .frame(width: clampedLeft)
                        .frame(maxHeight: .infinity)
                        .clipped()

                    ZStack {
                        Rectangle().fill(Color.primary.opacity(0.10)).frame(width: 1)
                        Capsule().fill(Color.secondary.opacity(0.45)).frame(width: 3, height: 28)
                    }
                    .frame(width: 11)
                    .frame(maxHeight: .infinity)
                    .contentShape(Rectangle())
                    .gesture(
                        DragGesture(minimumDistance: 1, coordinateSpace: .global)
                            .onChanged { val in
                                if leftSidebarDragStartWidth == nil { leftSidebarDragStartWidth = clampedLeft }
                                let startW = leftSidebarDragStartWidth ?? clampedLeft
                                let maxL = max(182, min(340, totalW - clampedRight - minCenterW - 22))
                                let newW = min(max(182, startW + val.translation.width), maxL)
                                var tx = Transaction(); tx.disablesAnimations = true
                                withTransaction(tx) {
                                    leftColumnLiveWidth = newW
                                    if !isLeftSidebarCompact && newW < 258 { isLeftSidebarCompact = true }
                                    else if isLeftSidebarCompact && newW > 272 { isLeftSidebarCompact = false }
                                    if !isLeftSidebarUltraSkinny && newW < 215 { isLeftSidebarUltraSkinny = true }
                                    else if isLeftSidebarUltraSkinny && newW > 228 { isLeftSidebarUltraSkinny = false }
                                }
                            }
                            .onEnded { _ in
                                leftColumnLiveWidth = clampedLeft
                                leftSidebarDragStartWidth = nil
                            }
                    )

                    centerAdaptableWorkspace
                        .frame(width: centerLiveW)
                        .frame(maxHeight: .infinity)
                        .clipped()

                    ZStack {
                        Rectangle().fill(Color.primary.opacity(0.10)).frame(width: 1)
                        Capsule().fill(Color.secondary.opacity(0.45)).frame(width: 3, height: 28)
                    }
                    .frame(width: 11)
                    .frame(maxHeight: .infinity)
                    .contentShape(Rectangle())
                    .gesture(
                        DragGesture(minimumDistance: 1, coordinateSpace: .global)
                            .onChanged { val in
                                if rightSidebarDragStartWidth == nil { rightSidebarDragStartWidth = clampedRight }
                                let startW = rightSidebarDragStartWidth ?? clampedRight
                                let maxR = max(minRightW, min(440, totalW - clampedLeft - minCenterW - 22))
                                let newW = min(max(minRightW, startW - val.translation.width), maxR)
                                var tx = Transaction(); tx.disablesAnimations = true
                                withTransaction(tx) {
                                    rightColumnLiveWidth = newW
                                    if !isRightQueueCompact && newW < 355 { isRightQueueCompact = true }
                                    else if isRightQueueCompact && newW > 368 { isRightQueueCompact = false }
                                }
                            }
                            .onEnded { _ in
                                rightColumnLiveWidth = clampedRight
                                rightSidebarDragStartWidth = nil
                            }
                    )

                    KroutonDestinationRackColumnView(
                        store: store,
                        driveManager: driveManager,
                        isRightQueueCompact: isRightQueueCompact,
                        enableCustomFinderLayoutTab: enableCustomFinderLayoutTab,
                        finderIconSize: finderIconSize,
                        primarySelectedDrive: primarySelectedDrive
                    )
                        .frame(width: clampedRight)
                        .frame(maxHeight: .infinity)
                        .clipped()
                }
                .frame(width: totalW, alignment: .leading)
                .coordinateSpace(name: "KroutonSplitSpace")
                .onAppear {
                    isLeftSidebarCompact = clampedLeft < 265
                    isLeftSidebarUltraSkinny = clampedLeft < 215
                    isRightQueueCompact = clampedRight < 355
                    isCenterWorkspaceUltraCompact = centerLiveW < 500
                    isCenterWorkspaceNarrow = centerLiveW < 520
                }
                .onChange(of: clampedRight) { _, newRightW in
                    var tx = Transaction(); tx.disablesAnimations = true
                    withTransaction(tx) {
                        if !isRightQueueCompact && newRightW < 355 { isRightQueueCompact = true }
                        else if isRightQueueCompact && newRightW > 368 { isRightQueueCompact = false }
                    }
                }
                .onChange(of: clampedLeft) { _, newLeftW in
                    var tx = Transaction(); tx.disablesAnimations = true
                    withTransaction(tx) {
                        if !isLeftSidebarCompact && newLeftW < 258 { isLeftSidebarCompact = true }
                        else if isLeftSidebarCompact && newLeftW > 272 { isLeftSidebarCompact = false }
                        if !isLeftSidebarUltraSkinny && newLeftW < 215 { isLeftSidebarUltraSkinny = true }
                        else if isLeftSidebarUltraSkinny && newLeftW > 228 { isLeftSidebarUltraSkinny = false }
                    }
                }
                .onChange(of: centerLiveW) { _, newCenterW in
                    // Hysteresis deadband (705pt <-> 735pt) for Center Workspace 1-Column / 2-Column & Hero Schematic box!
                    var tx = Transaction()
                    tx.disablesAnimations = true
                    withTransaction(tx) {
                        if !isCenterWorkspaceNarrow && newCenterW < 510 {
                            isCenterWorkspaceNarrow = true
                        } else if isCenterWorkspaceNarrow && newCenterW > 535 {
                            isCenterWorkspaceNarrow = false
                        }
                        if !isCenterWorkspaceUltraCompact && newCenterW < 495 {
                            isCenterWorkspaceUltraCompact = true
                        } else if isCenterWorkspaceUltraCompact && newCenterW > 515 {
                            isCenterWorkspaceUltraCompact = false
                        }
                    }
                }
            }
        }
        .frame(minWidth: 1180, idealWidth: 1380, minHeight: 720, idealHeight: 880)
        .background(store.enableSecondaryAccentUITints ? store.activeAccent.opacity(0.11) : Color.clear)
        .background(Color.kroutonWindowSurface)
        .preferredColorScheme(store.resolvedColorScheme)
        .environment(\.locale, store.activeLocale)
        .tint(store.activeAccent)
        .onAppear { store.reconcileUniqueDriveAssignments(driveManager: driveManager) }
        .onChange(of: driveManager.availableDrives) { _, _ in store.reconcileUniqueDriveAssignments(driveManager: driveManager) }
        .onChange(of: store.selectedTaskID) { _, _ in store.reconcileUniqueDriveAssignments(driveManager: driveManager) }
        .onChange(of: store.selectedCategory) { _, _ in store.reconcileUniqueDriveAssignments(driveManager: driveManager) }
        .sheet(item: $driveManager.completionReport) { report in
            KroutonMasteringReportSheet(report: report, accent: store.activeAccent) {
                driveManager.completionReport = nil
            }
        }
        .modifier(KroutonStageImporterModifier(store: store))
        .modifier(KroutonProjectSheetModifier(store: store, driveManager: driveManager))
    }

    var topProToolbar: some View {
        HStack(spacing: 16) {
            HStack(spacing: 9) {
                Image(systemName: "opticaldisc.fill")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(store.activeAccent)
                VStack(alignment: .leading, spacing: 1) {
                    Text(KroutonL10n.tr("KROUTON"))
                        .font(.system(size: 13, weight: .heavy, design: .rounded))
                    Text("\(driveManager.availableDrives.count) Optical Drive(s) Online • \(driveManager.hardwareStatusLog)")
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundStyle(store.enableSecondaryAccentUITints ? store.activeSecondaryAccent.opacity(0.90) : Color.secondary)
                        .lineLimit(1)
                }
            }

            Spacer()

            HStack(spacing: 10) {
                Button {
                    KroutonWindowManager.shared.openSettingsWindow(store: store, driveManager: driveManager)
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "gearshape.fill")
                        Text(KroutonL10n.tr("Settings..."))
                    }
                    .font(.system(size: 12, weight: .semibold))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(store.uiSecondaryAccent.opacity(0.18))
                    .clipShape(Capsule())
                    .overlay(Capsule().stroke(store.uiSecondaryAccent.opacity(0.5), lineWidth: 1))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(store.enableSecondaryAccentUITints ? store.activeAccent.opacity(0.14) : Color.clear)
        .background(.ultraThinMaterial)
    }

    // MARK: - CENTER COLUMN: ADAPTABLE WORKSPACE + INTEGRATED CAPACITY BAR (Global graph removed)
    var centerAdaptableWorkspace: some View {
        VStack(alignment: .leading, spacing: 12) {
            Group {
                switch store.selectedCategory {
                case .burn:
                    KroutonBurnStationWorkspaceView(
                        store: store,
                        primarySelectedDrive: primarySelectedDrive,
                        isCenterWorkspaceNarrow: isCenterWorkspaceNarrow,
                        enableCustomFinderLayoutTab: $enableCustomFinderLayoutTab,
                        finderIconSize: $finderIconSize,
                        fitToDiscDVD9Shrink: $fitToDiscDVD9Shrink,
                        preserveMenusAndExtras: preserveMenusAndExtras,
                        cdTextAlbumTitle: $cdTextAlbumTitle,
                        cdTextAlbumPerformer: $cdTextAlbumPerformer,
                        auditioningTrackID: $auditioningTrackID,
                        isDropTargeted: $isDropTargeted,
                        onPromptToAddFiles: promptToAddFiles,
                        onHandleFinderDrop: handleFinderDrop(providers:)
                    )
                        .offset(x: sin(dropRejectShakePhase * .pi * 4) * 8)
                case .depot:
                    KroutonDepotWorkspaceView(store: store, isCenterWorkspaceNarrow: isCenterWorkspaceNarrow)
                case .copy:
                    KroutonCopyAndRipWorkspaceView(
                        store: store,
                        primarySelectedDrive: primarySelectedDrive,
                        isCenterWorkspaceNarrow: isCenterWorkspaceNarrow,
                        fitToDiscDVD9Shrink: $fitToDiscDVD9Shrink,
                        preserveMenusAndExtras: $preserveMenusAndExtras,
                        cdTextAlbumTitle: $cdTextAlbumTitle,
                        cdTextAlbumPerformer: $cdTextAlbumPerformer
                    )
                case .label:
                    KroutonDiscLabelWorkspaceView(store: store)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)

            // Integrated Central Workspace Capacity Allocation Bar (Hidden in Label Designer mode)
            if store.selectedCategory != .label {
                KroutonCentralWorkspaceCapacityBarView(store: store, activeDiscCapacityBytes: activeDiscCapacityBytes, primarySelectedDrive: primarySelectedDrive)
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}
