import AudioToolbox
import DriveKit
import Foundation
import ImageIO
import NetworkSpool
import OpticalCore
import SwiftUI
import UniformTypeIdentifiers

// MARK: - Main Workspace View

struct KroutonMainWorkspaceView: View {
    var store: KroutonStateStore
    var driveManager: KroutonOpticalDriveBank

    @State var leftColumnLiveWidth: CGFloat = 196
    @State var rightColumnLiveWidth: CGFloat = 315
    @State var leftSidebarDragStartWidth: CGFloat? = nil
    @State var rightSidebarDragStartWidth: CGFloat? = nil
    @State var dropRejectShakePhase: CGFloat = 0
    @State var isLeftSidebarCollapsed: Bool = false
    @State var isRightSidebarCollapsed: Bool = false
    /// The columns' sizes, published to them as `\.kroutonLayout`; nil until the first layout.
    @State var windowLayout: KroutonWindowLayout? = nil
    @State var isDropTargeted: Bool = false

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
        mainContentStack
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
            .sheet(item: Bindable(driveManager).completionReport) { report in
                KroutonMasteringReportSheet(report: report, accent: store.activeAccent) {
                    driveManager.completionReport = nil
                }
            }
            .modifier(KroutonStageImporterModifier(store: store))
            .modifier(KroutonProjectSheetModifier(store: store, driveManager: driveManager))
            .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("krouton.toggleLeftSidebar"))) { _ in
                withAnimation(kroutonMotion(.spring(response: 0.32, dampingFraction: 0.78))) { isLeftSidebarCollapsed.toggle() }
            }
            .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("krouton.toggleRightSidebar"))) { _ in
                withAnimation(kroutonMotion(.spring(response: 0.32, dampingFraction: 0.78))) { isRightSidebarCollapsed.toggle() }
            }
    }

    private var mainContentStack: some View {
        VStack(spacing: 0) {
            topProToolbar
            Divider()
            KroutonCrashRecoveryBannerView(store: store)
            GeometryReader { windowGeo in
                splitColumnsLayout(windowSize: windowGeo.size)
            }
        }
    }

    var topProToolbar: some View {
        HStack(spacing: 14) {
            Button {
                withAnimation(kroutonMotion(.spring(response: 0.32, dampingFraction: 0.78))) {
                    isLeftSidebarCollapsed.toggle()
                }
            } label: {
                Image(systemName: "sidebar.left")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(isLeftSidebarCollapsed ? store.activeAccent : .secondary)
                    .padding(6)
                    .background(Color.primary.opacity(isLeftSidebarCollapsed ? 0.12 : 0.06))
                    .clipShape(RoundedRectangle(cornerRadius: 6))
            }
            .buttonStyle(.plain)
            .help("Toggle Left Format Chooser Sidebar (^⌘S)")

            HStack(spacing: 9) {
                KroutonBrandLogoView(size: 26, tintColor: store.enableSecondaryAccentUITints ? store.activeAccent : nil)
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
                toolbarManualAndToursMenu

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

                Button {
                    withAnimation(kroutonMotion(.spring(response: 0.32, dampingFraction: 0.78))) {
                        isRightSidebarCollapsed.toggle()
                    }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "sidebar.right")
                        if isRightSidebarCollapsed && !driveManager.availableDrives.isEmpty {
                            Text("\(driveManager.availableDrives.count)")
                                .font(.system(size: 10, weight: .bold, design: .monospaced))
                                .padding(.horizontal, 4)
                                .padding(.vertical, 1)
                                .background(store.activeAccent)
                                .foregroundStyle(store.activeOnAccentText)
                                .clipShape(Capsule())
                        }
                    }
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(isRightSidebarCollapsed ? store.activeAccent : .secondary)
                    .padding(6)
                    .background(Color.primary.opacity(isRightSidebarCollapsed ? 0.12 : 0.06))
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                }
                .buttonStyle(.plain)
                .help("Toggle Right Destination Queue Sidebar (⌥⌘S)")
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(store.enableSecondaryAccentUITints ? store.activeAccent.opacity(0.14) : Color.clear)
        .background(.ultraThinMaterial)
    }

    private var toolbarManualAndToursMenu: some View {
        Menu {
            Button {
                KroutonWindowManager.shared.openUserManualWindow()
            } label: {
                Label(KroutonL10n.tr("Krouton User Manual & Search..."), systemImage: "book.closed.fill")
            }
            Divider()
            ForEach(KroutonGuidedTutorialID.allCases) { tour in
                Button {
                    KroutonGuidedTutorialController.shared.start(tour, store: store, driveManager: driveManager)
                } label: {
                    Label(tour.title, systemImage: tour.sfSymbol)
                }
            }
            if KroutonGuidedTutorialController.shared.isRunning {
                Divider()
                Button(role: .destructive) {
                    KroutonGuidedTutorialController.shared.stop()
                } label: {
                    Label(KroutonL10n.tr("Exit Active Guided Tutorial"), systemImage: "xmark.circle")
                }
            }
        } label: {
            HStack(spacing: 5) {
                Image(systemName: "questionmark.circle.fill")
                Text(KroutonL10n.tr("Manual & Tours"))
            }
            .font(.system(size: 12, weight: .semibold))
            .padding(.horizontal, 11)
            .padding(.vertical, 6)
            .background(Color.primary.opacity(0.08))
            .clipShape(Capsule())
        }
        .menuStyle(.borderlessButton)
        .fixedSize()
    }

    var centerAdaptableWorkspace: some View {
        VStack(alignment: .leading, spacing: 12) {
            Group {
                switch store.selectedCategory {
                case .burn:
                    KroutonBurnStationWorkspaceView(
                        store: store,
                        primarySelectedDrive: primarySelectedDrive,
                        isDropTargeted: $isDropTargeted,
                        onPromptToAddFiles: promptToAddFiles,
                        onHandleFinderDrop: handleFinderDrop(providers:)
                    )
                    .offset(x: sin(dropRejectShakePhase * .pi * 4) * 8)
                case .depot:
                    KroutonDepotWorkspaceView(store: store)
                case .copy:
                    KroutonCopyAndRipWorkspaceView(
                        store: store,
                        primarySelectedDrive: primarySelectedDrive
                    )
                case .label:
                    KroutonDiscLabelWorkspaceView(store: store)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)

            if store.selectedCategory != .label {
                KroutonCentralWorkspaceCapacityBarView(store: store, activeDiscCapacityBytes: activeDiscCapacityBytes, primarySelectedDrive: primarySelectedDrive)
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}
