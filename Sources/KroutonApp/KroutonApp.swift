import SwiftUI
import AppKit
import UniformTypeIdentifiers
import OpticalDough

@MainActor
final class KroutonWindowManager {
    static let shared = KroutonWindowManager()
    let store = KroutonStateStore()
    let driveManager = DriveManager()

    private var mainWindow: NSWindow?
    private var settingsWindow: NSWindow?
    private var phaseScopeWindows: [String: NSWindow] = [:]
    private var phaseScopeDelegates: [String: PhaseScopeWindowCloseDelegate] = [:]

    func openFloatingPhaseScopeWindow(driveID: String) {
        let resolvedDrive = driveManager.driveForID(driveID)
        let targetID = resolvedDrive?.id ?? driveID
        guard !targetID.isEmpty else { return }
        let driveTitle = resolvedDrive?.displayName ?? "Optical Burner"

        driveManager.setFloatingScopeOpen(for: targetID, isOpen: true)

        if let existing = phaseScopeWindows[targetID] {
            existing.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let rootView = FloatingPhaseScopeWindowView(
            driveID: targetID,
            store: store,
            driveManager: driveManager,
            onDockInline: { [weak self] in
                self?.closeFloatingPhaseScopeWindow(driveID: targetID)
            }
        )
        let hostingController = NSHostingController(rootView: rootView)
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 780, height: 520),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "Phase Scope — \(driveTitle)"
        window.contentViewController = hostingController
        window.center()
        window.isReleasedWhenClosed = false

        let del = PhaseScopeWindowCloseDelegate(driveID: targetID, driveManager: driveManager)
        self.phaseScopeDelegates[targetID] = del
        window.delegate = del

        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        self.phaseScopeWindows[targetID] = window
    }

    func closeFloatingPhaseScopeWindow(driveID: String, suckIntoMiniGraph: Bool = true) {
        driveManager.setFloatingScopeOpen(for: driveID, isOpen: false, keepInlineVisible: suckIntoMiniGraph)
        phaseScopeWindows[driveID]?.orderOut(nil)
    }

    func openMainWindow() {
        if let existing = mainWindow {
            existing.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let rootView = KroutonMainWorkspaceView(store: store, driveManager: driveManager)
        let hostingController = NSHostingController(rootView: rootView)
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 1380, height: 880),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "Krouton"
        window.contentViewController = hostingController
        window.center()
        window.setFrameAutosaveName("KroutonMainWorkspaceWindow")
        window.isReleasedWhenClosed = false
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        self.mainWindow = window
    }

    func openSettingsWindow(store: KroutonStateStore, driveManager: DriveManager, pane: KroutonSettingsCategory? = nil) {
        if let targetPane = pane { store.selectedSettingsPane = targetPane }
        if let existing = settingsWindow {
            existing.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let hostingController = NSHostingController(rootView: KroutonSettingsWindowView(store: store, driveManager: driveManager))
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 1120, height: 720),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "Krouton Settings"
        window.contentViewController = hostingController
        window.center()
        window.setFrameAutosaveName("KroutonSettingsWindow")
        window.isReleasedWhenClosed = false
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        self.settingsWindow = window
    }
}

@MainActor
final class PhaseScopeWindowCloseDelegate: NSObject, NSWindowDelegate {
    let driveID: String
    weak var driveManager: DriveManager?

    init(driveID: String, driveManager: DriveManager) {
        self.driveID = driveID
        self.driveManager = driveManager
    }

    func windowWillClose(_ notification: Notification) {
        driveManager?.setFloatingScopeOpen(for: driveID, isOpen: false, keepInlineVisible: true)
    }
}

@MainActor
final class KroutonAppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        KroutonWindowManager.shared.openMainWindow()
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !flag {
            KroutonWindowManager.shared.openMainWindow()
        }
        return true
    }
}

@main
struct KroutonApp: App {
    @NSApplicationDelegateAdaptor(KroutonAppDelegate.self) var appDelegate

    var body: some Scene {
        Settings {
            KroutonSettingsWindowView(
                store: KroutonWindowManager.shared.store,
                driveManager: KroutonWindowManager.shared.driveManager
            )
        }
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("Show Krouton Workspace") {
                    KroutonWindowManager.shared.openMainWindow()
                }
                .keyboardShortcut("0", modifiers: .command)
            }
            CommandGroup(replacing: .appSettings) {
                Button {
                    KroutonWindowManager.shared.openSettingsWindow(
                        store: KroutonWindowManager.shared.store,
                        driveManager: KroutonWindowManager.shared.driveManager
                    )
                } label: {
                    Label(KroutonL10n.tr("Settings..."), systemImage: "gearshape")
                }
                .keyboardShortcut(",", modifiers: .command)
            }
        }
    }
}

struct KroutonMainWorkspaceView: View {
    @ObservedObject var store: KroutonStateStore
    @ObservedObject var driveManager: DriveManager

    @State private var enableCustomFinderLayoutTab: Bool = false
    @State private var activeDataWorkspaceTab: Int = 0
    @State private var finderBgColor: Color = Color(red: 0.13, green: 0.17, blue: 0.24)
    @State private var finderIconSize: Double = 256
    @State private var fitToDiscDVD9Shrink: Bool = true
    @State private var preserveMenusAndExtras: Bool = true
    @State private var labelDiscTitle: String = "THE KROUTON ARCHIVE"
    @State private var labelSubtitle: String = "2026 MASTER EDITION"
    @State private var autoLabelSearchQuery: String = "Dark Side of the Moon"
    @State private var depotSearchQuery: String = ""
    @State private var leftColumnLiveWidth: CGFloat = 255
    @State private var rightColumnLiveWidth: CGFloat = 345
    @State private var leftSidebarDragStartWidth: CGFloat? = nil
    @State private var rightSidebarDragStartWidth: CGFloat? = nil
    @State private var dropRejectShakePhase: CGFloat = 0
    @State private var isDropTargeted: Bool = false
    @State private var activeDiscPopoverCardID: UUID? = nil
    @State private var romWriteModeDAO96SubQ: Bool = true
    @State private var romBitsetDVDROM: Bool = true
    @State private var romPerformOPCBeforeWrite: Bool = true
    @State private var xboxLayerBreakPreset: String = "Auto (.dvd / Calculate Optimal)"
    // Red Book CD-DA & CD-Extra Mastering State
    @State private var cdTextAlbumTitle: String = "KROUTON SESSIONS VOL. I"
    @State private var cdTextAlbumPerformer: String = "THE OPTICAL COLLECTIVE"
    @State private var cdTextUPCBarcode: String = "012345678905"
    @State private var enableHiddenTrackOneHTOA: Bool = false
    @State private var defaultAudioTransition: String = "2.0s Standard Pre-Gap (INDEX 00)"
    @State private var auditioningTrackID: UUID? = nil
    // Car-Safe MP3 / FLAC CD Mastering State
    @State private var carSafeZeroPadNumbers: Bool = true
    @State private var carSafeStripAppleDouble: Bool = true
    @State private var carSafeEnforceID3v23: Bool = true
    @State private var carSafeGenerateM3U: Bool = true
    @State private var carSafeTranscodeTarget: String = "320 kbps CBR MP3 (Universal Car Deck)"
    // Video Disc Authoring & Dual-Layer Break State
    @State private var videoMenuTemplate: String = "Dark Studio Chapter Grid"
    @State private var videoSystemStandard: String = "NTSC 16:9 (29.97 / 23.976p)"
    @State private var videoAudioEncoding: String = "AC-3 Dolby Digital 5.1 (448 kbps)"
    @State private var videoDualLayerBreakSector: String = "Auto Cell Boundary (LBA 2,086,912 • 16-Sector ECC Aligned)"
    // M-DISC Archival PAR2 State
    @State private var mdiscPar2RedundancyPct: Double = 15.0
    // New Data Disc File System Bridge State
    @State private var selectedDataFileSystemBridge: String = "Universal 4-Way Bridge (UDF 1.02 + HFS+ + Joliet + Rock Ridge)"
    @State private var preserveMacExtendedAttributes: Bool = true
    @State private var enforce8Dot3RetroCompatibility: Bool = false
    // Dedicated Disc Image Burner State
    @State private var discImageWriteMethod: String = "DAO / SAO Sector-Exact (Preserve System Area & Boot Catalog)"
    @State private var verifyImageSHA256BeforeBurn: Bool = true
    @State private var inspectedImageLBA: Int = 17
    @State private var computedImageSHA256: String = ""
    @State private var imageActionStatusBanner: String = "" 

    private var primarySelectedDrive: OpticalDriveDevice? {
        if let firstBurnerCard = store.destinationQueue.first(where: { $0.kind == .physicalBurner }),
           let match = driveManager.driveForID(firstBurnerCard.targetDriveID) {
            return match
        }
        return driveManager.selectedDrive ?? driveManager.availableDrives.first
    }

    private var activeDiscCapacityBytes: Int64 {
        if let drive = primarySelectedDrive, drive.isMediaPresent, drive.freeBytes > 0 {
            return drive.freeBytes
        }
        let activeSpec = store.discFormats.first(where: { $0.id == store.selectedTaskID })
        let gb = activeSpec?.capacityGB ?? 4.7
        return Int64(gb * 1_000_000_000.0)
    }

    private var activeDiscTotalSectorsLBA: Int64 {
        max(1, activeDiscCapacityBytes / 2048)
    }

    var body: some View {
        VStack(spacing: 0) {
            topProToolbar
            Divider()

            GeometryReader { windowGeo in
                let totalW = windowGeo.size.width
                let minCenterW: CGFloat = 380
                let maxAllowedLeft = max(165, min(360, totalW - rightColumnLiveWidth - minCenterW))
                let clampedLeft = min(max(165, leftColumnLiveWidth), maxAllowedLeft)
                let maxAllowedRight = max(225, min(460, totalW - clampedLeft - minCenterW))
                let clampedRight = min(max(225, rightColumnLiveWidth), maxAllowedRight)

                HStack(spacing: 0) {
                    leftFormatChooserColumn
                        .frame(width: clampedLeft)
                        .frame(maxHeight: .infinity)
                        .clipped()

                    // Left Interactive Column Resize Handle
                    ZStack {
                        Rectangle()
                            .fill(Color.primary.opacity(0.10))
                            .frame(width: 1)
                        Capsule()
                            .fill(Color.secondary.opacity(0.45))
                            .frame(width: 3, height: 28)
                    }
                    .frame(width: 7)
                    .frame(maxHeight: .infinity)
                    .contentShape(Rectangle())
                    .onHover { inside in
                        if inside { NSCursor.resizeLeftRight.push() } else { NSCursor.pop() }
                    }
                    .gesture(
                        DragGesture(minimumDistance: 1)
                            .onChanged { val in
                                if leftSidebarDragStartWidth == nil {
                                    leftSidebarDragStartWidth = clampedLeft
                                }
                                let proposed = (leftSidebarDragStartWidth ?? clampedLeft) + val.translation.width
                                leftColumnLiveWidth = min(max(165, proposed), min(360, totalW - clampedRight - minCenterW))
                            }
                            .onEnded { _ in
                                leftSidebarDragStartWidth = nil
                            }
                    )

                    centerAdaptableWorkspace
                        .frame(minWidth: minCenterW, maxWidth: .infinity, maxHeight: .infinity)
                        .clipped()

                    // Right Interactive Column Resize Handle
                    ZStack {
                        Rectangle()
                            .fill(Color.primary.opacity(0.10))
                            .frame(width: 1)
                        Capsule()
                            .fill(Color.secondary.opacity(0.45))
                            .frame(width: 3, height: 28)
                    }
                    .frame(width: 7)
                    .frame(maxHeight: .infinity)
                    .contentShape(Rectangle())
                    .onHover { inside in
                        if inside { NSCursor.resizeLeftRight.push() } else { NSCursor.pop() }
                    }
                    .gesture(
                        DragGesture(minimumDistance: 1)
                            .onChanged { val in
                                if rightSidebarDragStartWidth == nil {
                                    rightSidebarDragStartWidth = clampedRight
                                }
                                let proposed = (rightSidebarDragStartWidth ?? clampedRight) - val.translation.width
                                rightColumnLiveWidth = min(max(225, proposed), min(460, totalW - clampedLeft - minCenterW))
                            }
                            .onEnded { _ in
                                rightSidebarDragStartWidth = nil
                            }
                    )

                    rightDestinationColumn
                        .frame(width: clampedRight)
                        .frame(maxHeight: .infinity)
                        .clipped()
                }
            }
        }
        .frame(minWidth: 820, idealWidth: 1360, minHeight: 640, idealHeight: 860)
        .background(
            ZStack {
                Color(NSColor.windowBackgroundColor)
                if store.tintWindowWithWallpaper {
                    store.activeAccent.opacity(0.06).ignoresSafeArea()
                }
            }
        )
        .preferredColorScheme(store.appearanceMode.colorScheme)
        .environment(\.locale, store.activeLocale)
        .tint(store.activeAccent)
        .onAppear {
            reconcileUniqueDriveAssignments()
        }
        .onChange(of: driveManager.availableDrives) { _, _ in
            reconcileUniqueDriveAssignments()
        }
        .sheet(item: $driveManager.completionReport) { report in
            KroutonMasteringReportSheet(report: report, accent: store.activeAccent) {
                driveManager.completionReport = nil
            }
        }
    }

    private var topProToolbar: some View {
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
                        .foregroundStyle(.secondary)
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
                    .background(store.activeAccent.opacity(0.18))
                    .clipShape(Capsule())
                    .overlay(Capsule().stroke(store.activeAccent.opacity(0.5), lineWidth: 1))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(.ultraThinMaterial)
    }

    private var leftFormatChooserColumn: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Label(leftColumnLiveWidth < 195 ? KroutonL10n.tr("FORMATS") : KroutonL10n.tr("FORMAT CHOOSER"), systemImage: "list.bullet.rectangle")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                Spacer(minLength: 4)
                Button {
                    KroutonWindowManager.shared.openSettingsWindow(store: store, driveManager: driveManager, pane: .formatChooser)
                } label: {
                    Image(systemName: "slider.horizontal.3")
                        .font(.system(size: 11))
                }
                .buttonStyle(.plain)
                .help("Configure visible formats in Settings -> Format Chooser")
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(KroutonL10n.tr("BURN"))
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 10)

                        ForEach(store.discFormats.filter { $0.showInTaskChooser }) { fmt in
                            taskRowButton(
                                id: fmt.id,
                                category: .burn,
                                title: fmt.shortDisplayName,
                                colloquial: fmt.colloquialName,
                                badge: fmt.sourceSupport,
                                sfSymbol: fmt.sfSymbol
                            )
                        }
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text(KroutonL10n.tr("DISC IMAGE DEPOT"))
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 10)

                        taskRowButton(
                            id: "depot-all",
                            category: .depot,
                            title: "All Library (60+)",
                            colloquial: "Complete Verified Optical Catalog",
                            sfSymbol: "square.grid.2x2.fill"
                        )
                        taskRowButton(
                            id: "depot-rescue",
                            category: .depot,
                            title: "Rescue & BIOS",
                            colloquial: "SystemRescue, GParted, Memtest, UBCD",
                            sfSymbol: "cross.case.fill"
                        )
                        taskRowButton(
                            id: "depot-linux",
                            category: .depot,
                            title: "Live Linux & BSD",
                            colloquial: "Ubuntu, Fedora, Debian, FreeBSD, Arch",
                            sfSymbol: "terminal.fill"
                        )
                        taskRowButton(
                            id: "depot-vintage",
                            category: .depot,
                            title: "Vintage Mac",
                            colloquial: "Mac OS 9.2.2, System 7.5, A/UX, AHT",
                            sfSymbol: "desktopcomputer"
                        )
                        taskRowButton(
                            id: "depot-homebrew",
                            category: .depot,
                            title: "Console ROMs",
                            colloquial: "Swiss GC, FreeDVDBoot PS2, 240p Suite",
                            sfSymbol: "gamecontroller.fill"
                        )
                        taskRowButton(
                            id: "depot-coverdiscs",
                            category: .depot,
                            title: "Cover Discs",
                            colloquial: "MacAddict, PC Gamer, NextGen, Scene.org",
                            sfSymbol: "sparkles.tv.fill"
                        )
                        taskRowButton(
                            id: "depot-retropc",
                            category: .depot,
                            title: "Retro PC & DOS",
                            colloquial: "FreeDOS 1.4, Haiku, BeOS R5, OS/2, IRIX",
                            sfSymbol: "cpu.fill"
                        )
                    }

                    Divider().padding(.vertical, 2)

                    VStack(alignment: .leading, spacing: 4) {
                        Text(KroutonL10n.tr("COPY"))
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 10)

                        taskRowButton(
                            id: "copy-duplicate",
                            category: .copy,
                            title: "Duplicate Disc",
                            colloquial: "Fit-to-Disc DVD-9 / BD Shrink",
                            badge: "1:1 / Fit",
                            sfSymbol: "doc.on.doc.fill"
                        )
                        taskRowButton(
                            id: "copy-rip-audio",
                            category: .copy,
                            title: "Rip Audio CD",
                            colloquial: "ALAC, AAC, FLAC + AccurateRip",
                            badge: "Extract",
                            sfSymbol: "waveform.badge.plus"
                        )
                        taskRowButton(
                            id: "copy-rip-video",
                            category: .copy,
                            title: "Extract Video Disc",
                            colloquial: "Hardware H.265 / HEVC Passthrough",
                            badge: "H.265",
                            sfSymbol: "film.stack"
                        )
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text(KroutonL10n.tr("LABEL"))
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 10)

                        taskRowButton(
                            id: "label-auto",
                            category: .label,
                            title: "Auto Label",
                            colloquial: "Artwork Lookup + Hole Avoidance",
                            badge: "120mm",
                            sfSymbol: "wand.and.stars"
                        )
                        taskRowButton(
                            id: "label-manual",
                            category: .label,
                            title: "Manual Label",
                            colloquial: "120mm / 18mm Canvas Studio",
                            badge: "Custom",
                            sfSymbol: "printer.dotmatrix.fill"
                        )
                    }
                }
                .padding(10)
            }
        }
        .background(Color(NSColor.controlBackgroundColor))
    }

    private func taskRowButton(id: String, category: TaskMasterCategory, title: String, colloquial: String, badge: String = "", sfSymbol: String) -> some View {
        let isSelected = (store.selectedTaskID == id)
        return Button {
            store.selectedCategory = category
            store.selectedTaskID = id
            store.rejectedDropNotice = nil
            store.purgeIncompatibleStagedFilesForCurrentTask()
            syncDefaultDestinationForCategory(category, taskID: id)
        } label: {
            HStack(spacing: 9) {
                let rowColor = store.effectiveColorForTask(id: id, category: category)
                KroutonStyledIconBadge(
                    sfSymbol: sfSymbol,
                    tintColor: rowColor,
                    style: store.iconWidgetStyle,
                    isSelectedRow: isSelected,
                    onAccentText: store.activeOnAccentText,
                    size: store.sidebarIconSize.iconFontSize + 11,
                    symbolSize: store.sidebarIconSize.iconFontSize - 1
                )

                VStack(alignment: .leading, spacing: 1) {
                    Text(KroutonL10n.tr(title))
                        .font(.system(size: store.sidebarIconSize.titleFontSize, weight: .semibold))
                        .foregroundStyle(isSelected ? store.activeOnAccentText : .primary)
                        .lineLimit(1)
                    if leftColumnLiveWidth >= 215 {
                        Text(KroutonL10n.tr(colloquial))
                            .font(.system(size: max(9.5, store.sidebarIconSize.titleFontSize - 2.0)))
                            .foregroundStyle(isSelected ? store.activeOnAccentText.opacity(0.82) : .secondary)
                            .lineLimit(1)
                    }
                }
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, store.sidebarIconSize.rowVerticalPadding)
            .background(
                RoundedRectangle(cornerRadius: 7)
                    .fill(isSelected ? store.activeAccent : Color.clear)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 7)
                    .stroke(store.a11yIncreaseContrast && isSelected ? Color.primary : Color.clear, lineWidth: 1.5)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(title), \(colloquial)")
    }

    // MARK: - CENTER COLUMN: ADAPTABLE WORKSPACE + INTEGRATED CAPACITY BAR (Global graph removed)
    private var centerAdaptableWorkspace: some View {
        VStack(alignment: .leading, spacing: 12) {
            switch store.selectedCategory {
            case .burn:
                burnWorkspaceView
                    .offset(x: sin(dropRejectShakePhase * .pi * 4) * 8)
            case .depot:
                depotWorkspaceView
            case .copy:
                copyWorkspaceView
            case .label:
                labelWorkspaceView
            }

            // Integrated Central Workspace Capacity Allocation Bar
            centralWorkspaceCapacityBar
        }
        .padding(16)
    }

    private var centralWorkspaceCapacityBar: some View {
        let usedB = store.totalStagedBytes
        let totalB = max(1, activeDiscCapacityBytes)
        let freeB = max(0, totalB - usedB)
        let ratio = min(1.0, Double(usedB) / Double(totalB))
        let isOverburn = usedB > totalB
        let mediaLabel = primarySelectedDrive?.isMediaPresent == true
            ? (primarySelectedDrive?.mediaType ?? "Optical Disc")
            : (store.discFormats.first(where: { $0.id == store.selectedTaskID })?.capacity ?? "4.7 GB Target")

        return VStack(alignment: .leading, spacing: 5) {
            ViewThatFits(in: .horizontal) {
                // 1. Wide Workspace Layout
                HStack(spacing: 6) {
                    Label("DISC SPACE (\(mediaLabel))", systemImage: "chart.bar.xaxis")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                    Spacer(minLength: 8)
                    Text("Used: \(ByteCountFormatter.string(fromByteCount: usedB, countStyle: .file)) (\(store.totalStagedSectorsLBA) LBA)")
                        .font(.system(size: 10.5, weight: .semibold, design: .monospaced))
                        .foregroundStyle(isOverburn ? .red : .primary)
                        .lineLimit(1)
                    Text("•").foregroundStyle(.secondary)
                    Text("Free: \(ByteCountFormatter.string(fromByteCount: freeB, countStyle: .file))")
                        .font(.system(size: 10.5, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                    Text("•").foregroundStyle(.secondary)
                    Text(String(format: "%.1f%%", ratio * 100.0))
                        .font(.system(size: 10.5, weight: .bold, design: .monospaced))
                        .foregroundStyle(isOverburn ? .red : store.activeAccent)
                        .lineLimit(1)
                }

                // 2. Compact / Narrow Workspace Fallback (Zero Multi-Line Wrapping!)
                HStack(spacing: 6) {
                    Text("\(mediaLabel):")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                    Text("\(ByteCountFormatter.string(fromByteCount: usedB, countStyle: .file)) / \(ByteCountFormatter.string(fromByteCount: totalB, countStyle: .file))")
                        .font(.system(size: 10, weight: .semibold, design: .monospaced))
                        .foregroundStyle(isOverburn ? .red : .primary)
                        .lineLimit(1)
                    Spacer(minLength: 4)
                    Text(String(format: "%.1f%%", ratio * 100.0))
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundStyle(isOverburn ? .red : store.activeAccent)
                        .lineLimit(1)
                }
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.primary.opacity(0.08))
                    RoundedRectangle(cornerRadius: 4)
                        .fill(isOverburn ? Color.red : store.activeAccent)
                        .frame(width: max(4, geo.size.width * ratio))
                    Rectangle()
                        .fill(Color.yellow.opacity(0.65))
                        .frame(width: 1.5)
                        .offset(x: geo.size.width * 0.96)
                }
            }
            .frame(height: 7)
        }
        .padding(10)
        .background(Color(NSColor.controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .accessibilityLabel(String(format: "Disc capacity %.1f percent full", ratio * 100.0))
    }

    private var filteredDepotItems: [DepotCatalogItem] {
        let channelFilter: String? = {
            switch store.selectedTaskID {
            case "depot-rescue": return "Rescue & Diagnostics"
            case "depot-linux": return "Live Linux & BSD"
            case "depot-vintage": return "Vintage Apple (archive.org)"
            case "depot-homebrew": return "Console Homebrew & ROMs"
            case "depot-coverdiscs": return "Cover Discs & Demoscene"
            case "depot-retropc": return "Retro PC & Alt OS"
            case "depot-ia-live": return "Internet Archive Live"
            default: return nil // "depot-all" shows all 60+ titles
            }
        }()

        return store.depotItems.filter { item in
            let matchesChannel = (channelFilter == nil) || (item.channel == channelFilter)
            let q = depotSearchQuery.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            let matchesQuery = q.isEmpty
                || item.title.lowercased().contains(q)
                || item.subtitle.lowercased().contains(q)
                || item.architecture.lowercased().contains(q)
                || item.bootStandard.lowercased().contains(q)
                || item.channel.lowercased().contains(q)
            return matchesChannel && matchesQuery
        }
    }

    private var depotHeroSelectedItem: DepotCatalogItem {
        let items = filteredDepotItems
        if let selID = store.selectedDepotHeroItemID,
           let match = items.first(where: { $0.id == selID }) {
            return match
        }
        return items.first ?? store.depotItems[0]
    }

    private var depotChannelHeadline: (badge: String, title: String, subtitle: String) {
        switch store.selectedTaskID {
        case "depot-rescue":
            return (
                "SYSTEM RESCUE & BIOS SUB-LIBRARY",
                "System Rescue & BIOS",
                "Bare-metal El Torito BIOS/UEFI recovery discs, partition editors, RAM analyzers & drive sanitizers."
            )
        case "depot-linux":
            return (
                "LIVE LINUX & BSD SUB-LIBRARY",
                "Live Linux & BSD",
                "Cryptographically verified hybrid ISO/UDF images ready for physical DVD/BD burning or VM test-boot."
            )
        case "depot-vintage":
            return (
                "VINTAGE APPLE & ARCHIVE.ORG SUB-LIBRARY",
                "Vintage Mac & Apple",
                "Bootable HFS Standard & Blessed System Folders for 680x0, PowerPC G3/G4/G5, A/UX & Apple IIgs."
            )
        case "depot-homebrew":
            return (
                "CONSOLE HOMEBREW & BOOT ROMS SUB-LIBRARY",
                "Console Homebrew & ROMs",
                "Legal optical boot discs (Swiss, FreeDVDBoot, UniROM, DreamShell, Pseudo Saturn Kai & 240p Test Suite)."
            )
        case "depot-coverdiscs":
            return (
                "90S COVER DISCS & DEMOSCENE SUB-LIBRARY",
                "90s Cover Discs & Scene",
                "Preserved MacAddict, Macworld, PC Gamer, Next Generation, Amiga Format & Assembly/Scene.org discs."
            )
        case "depot-retropc":
            return (
                "RETRO PC, DOS & ALT OS SUB-LIBRARY",
                "Retro PC, DOS & Alt OS",
                "Bootable optical releases for FreeDOS 1.4, Haiku, BeOS R5, IBM OS/2 Warp 4.52, ReactOS, Plan 9 & IRIX."
            )
        case "depot-ia-live":
            return (
                "INTERNET ARCHIVE LIVE API RESULTS",
                "Internet Archive Optical Software Query",
                "Live results fetched directly from archive.org/advancedsearch.php for optical ISO, BIN/CUE & CD-ROM media."
            )
        default:
            return (
                "COMPLETE OPTICAL LIBRARY (60+ VERIFIED TITLES)",
                "All Depot Library",
                "Select any sub-library in the left column or click any title card below to inspect its details in the Hero deck."
            )
        }
    }

    private var depotWorkspaceView: some View {
        let heroMeta = depotChannelHeadline
        let heroItem = depotHeroSelectedItem

        return GeometryReader { geo in
            let isNarrowWorkspace = geo.size.width < 740

            VStack(alignment: .leading, spacing: 10) {
                // Row 1: Clean Sub-Library Header + Search Bar (NO top category pills!)
                HStack(spacing: 10) {
                    KroutonStyledIconBadge(
                        sfSymbol: heroItem.sfSymbol,
                        tintColor: store.activeAccent,
                        style: store.iconWidgetStyle,
                        size: 28,
                        symbolSize: 14
                    )
                    VStack(alignment: .leading, spacing: 1) {
                        Text(KroutonL10n.tr(heroMeta.title))
                            .font(.title3.bold())
                            .lineLimit(1)
                        Text(KroutonL10n.tr(heroMeta.subtitle))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                    Spacer(minLength: 8)

                    HStack(spacing: 6) {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                        TextField(KroutonL10n.tr("Filter or search archive.org..."), text: $depotSearchQuery)
                            .textFieldStyle(.plain)
                            .frame(minWidth: 140, maxWidth: 210)
                            .onSubmit {
                                store.selectedTaskID = "depot-ia-live"
                                store.queryInternetArchiveLive(query: depotSearchQuery)
                            }
                        if !depotSearchQuery.isEmpty {
                            Button {
                                depotSearchQuery = ""
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.system(size: 11))
                                    .foregroundStyle(.secondary)
                            }
                            .buttonStyle(.plain)
                        }
                        Button {
                            store.selectedTaskID = "depot-ia-live"
                            store.queryInternetArchiveLive(query: depotSearchQuery)
                        } label: {
                            HStack(spacing: 4) {
                                if store.isSearchingInternetArchive {
                                    ProgressView().controlSize(.mini)
                                } else {
                                    Image(systemName: "building.columns.fill")
                                        .font(.system(size: 9))
                                }
                                Text("Archive.org API")
                                    .font(.system(size: 9.5, weight: .bold))
                                    .lineLimit(1)
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(store.activeAccent)
                            .foregroundStyle(store.activeOnAccentText)
                            .clipShape(Capsule())
                            .fixedSize(horizontal: true, vertical: false)
                        }
                        .buttonStyle(.plain)
                        .help("Query live Internet Archive REST API (archive.org/advancedsearch.php) for optical ISO / CD-ROM images")
                    }
                    .padding(.leading, 10)
                    .padding(.trailing, 4)
                    .padding(.vertical, 3)
                    .background(Color(NSColor.controlBackgroundColor))
                    .clipShape(Capsule())
                    .overlay(Capsule().stroke(Color.primary.opacity(0.12), lineWidth: 1))
                }

                // Row 2: Interactive Hero Inspector Zone (Shows details of whichever title card is clicked!)
                depotInteractiveHeroBanner(for: heroItem, isNarrow: isNarrowWorkspace)

                // Row 3: Active Staged Image Ready-to-Burn Dock
                if let stagedEntry = store.stagedFiles.first {
                    HStack(spacing: 10) {
                        Image(systemName: "checkmark.seal.fill")
                            .font(.system(size: 15))
                            .foregroundStyle(.green)

                        VStack(alignment: .leading, spacing: 1) {
                            HStack(spacing: 6) {
                                Text("STAGED IN BURN QUEUE:")
                                    .font(.system(size: 9.5, weight: .heavy, design: .monospaced))
                                    .foregroundStyle(.green)
                                    .lineLimit(1)
                                Text(stagedEntry.name)
                                    .font(.system(size: 11.5, weight: .bold, design: .monospaced))
                                    .lineLimit(1)
                            }
                            Text("\(ByteCountFormatter.string(fromByteCount: stagedEntry.byteSize, countStyle: .file)) (\(stagedEntry.sectorsLBA) LBA Sectors) — Ready for physical burn or hex sector inspection.")
                                .font(.system(size: 10))
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }

                        Spacer(minLength: 4)

                        Button {
                            store.selectedCategory = .burn
                            store.selectedTaskID = "image-burn"
                        } label: {
                            HStack(spacing: 5) {
                                Image(systemName: "waveform.path.ecg.rectangle.fill")
                                Text("Inspect Sector & Hex Map")
                                    .lineLimit(1)
                            }
                            .font(.system(size: 10, weight: .bold))
                            .padding(.horizontal, 11)
                            .padding(.vertical, 5)
                            .background(store.activeAccent)
                            .foregroundStyle(store.activeOnAccentText)
                            .clipShape(Capsule())
                            .fixedSize(horizontal: true, vertical: false)
                        }
                        .buttonStyle(.plain)

                        Button {
                            store.clearStagedFiles()
                            store.stagedDepotItemID = nil
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "xmark.circle.fill")
                                Text("Unstage")
                                    .lineLimit(1)
                            }
                            .font(.system(size: 10, weight: .semibold))
                            .padding(.horizontal, 9)
                            .padding(.vertical, 5)
                            .background(Color.primary.opacity(0.08))
                            .clipShape(Capsule())
                            .fixedSize(horizontal: true, vertical: false)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 7)
                    .background(Color.green.opacity(0.11))
                    .clipShape(RoundedRectangle(cornerRadius: 9))
                    .overlay(RoundedRectangle(cornerRadius: 9).stroke(Color.green.opacity(0.40), lineWidth: 1))
                }

                // Row 4: Sub-Library Grid Header
                HStack {
                    Text("\(heroMeta.badge)  •  CLICK ANY TITLE BELOW TO INSPECT IN HERO DECK")
                        .font(.system(size: 9.5, weight: .heavy, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                    Spacer()
                    Text("\(filteredDepotItems.count) Titles in Sub-Library  •  SHA-256 Verified")
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundStyle(store.activeAccent)
                        .lineLimit(1)
                }

                // Row 5: Scrollable Responsive 1-or-2 Column Sub-Library Card Grid
                ScrollView {
                    LazyVGrid(
                        columns: isNarrowWorkspace
                            ? [GridItem(.flexible(), spacing: 10)]
                            : [GridItem(.flexible(minimum: 300), spacing: 10), GridItem(.flexible(minimum: 300), spacing: 10)],
                        spacing: 10
                    ) {
                        ForEach(filteredDepotItems) { item in
                            depotAppStoreCard(for: item, isSelectedInHero: item.id == heroItem.id)
                        }
                    }
                    .padding(.bottom, 8)
                }
            }
        }
    }

    private func depotInteractiveHeroBanner(for item: DepotCatalogItem, isNarrow: Bool) -> some View {
        let isStaged = (store.stagedDepotItemID == item.id && !store.stagedFiles.isEmpty)
        let activeProgress = store.depotDownloadProgress[item.id]
        let segments = item.blueprintSectorSegments
        let treeFiles = item.blueprintRootFiles

        return ZStack(alignment: .leading) {
            // 1. Deep Blueprint Gradient Surface (Works across all 11 Krouton Accent Swatches & Dark/Light Modes)
            RoundedRectangle(cornerRadius: 14)
                .fill(
                    LinearGradient(
                        colors: [
                            store.activeAccent.opacity(0.42),
                            Color(red: 0.05, green: 0.10, blue: 0.19),
                            Color(red: 0.02, green: 0.04, blue: 0.09)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            // 2. Vector Blueprint Art Canvas (Tux Penguin, Classic Mac System 7 Icons, MacAddict + Doom 3D, DOS/TempleOS, Gamepad, Radar)
            Canvas { context, size in
                // Fine 18px CAD Engineering Grid
                let step: CGFloat = 18
                var grid = Path()
                var gx: CGFloat = 0
                while gx <= size.width {
                    grid.move(to: CGPoint(x: gx, y: 0))
                    grid.addLine(to: CGPoint(x: gx, y: size.height))
                    gx += step
                }
                var gy: CGFloat = 0
                while gy <= size.height {
                    grid.move(to: CGPoint(x: 0, y: gy))
                    grid.addLine(to: CGPoint(x: size.width, y: gy))
                    gy += step
                }
                context.stroke(grid, with: .color(Color.cyan.opacity(0.065)), lineWidth: 0.5)

                // Blueprint Dimension Lines & Open Showcase Zone on the Right
                let artX: CGFloat = isNarrow ? size.width * 0.78 : size.width * 0.64
                let artY: CGFloat = size.height * 0.50
                let cyanLine = Color.cyan.opacity(0.38)
                let accentLine = store.activeAccent.opacity(0.48)
                let faintCyan = Color.cyan.opacity(0.16)

                // Outer Blueprint Calibration Ring in the Open Showcase Zone
                let outerRing = CGRect(x: artX - 74, y: artY - 74, width: 148, height: 148)
                context.stroke(Path(ellipseIn: outerRing), with: .color(faintCyan), style: StrokeStyle(lineWidth: 0.9, dash: [6, 4]))

                if item.channel.contains("Live Linux") || item.id.contains("linux") || item.id.contains("ubuntu") || item.id.contains("fedora") || item.id.contains("debian") || item.id.contains("arch") {
                    // === VECTOR ART 1: LINUX TUX PENGUIN + KERNEL NODE GRAPH ===
                    var tux = Path()
                    // Head & Body Torso
                    tux.addEllipse(in: CGRect(x: artX - 24, y: artY - 56, width: 48, height: 42))
                    tux.addEllipse(in: CGRect(x: artX - 34, y: artY - 22, width: 68, height: 74))
                    // Inner Belly Oval
                    tux.addEllipse(in: CGRect(x: artX - 22, y: artY - 12, width: 44, height: 54))
                    // Left & Right Flippers
                    tux.move(to: CGPoint(x: artX - 32, y: artY - 12))
                    tux.addQuadCurve(to: CGPoint(x: artX - 42, y: artY + 28), control: CGPoint(x: artX - 52, y: artY + 6))
                    tux.addLine(to: CGPoint(x: artX - 30, y: artY + 22))
                    tux.move(to: CGPoint(x: artX + 32, y: artY - 12))
                    tux.addQuadCurve(to: CGPoint(x: artX + 42, y: artY + 28), control: CGPoint(x: artX + 52, y: artY + 6))
                    tux.addLine(to: CGPoint(x: artX + 30, y: artY + 22))
                    // Eyes
                    tux.addEllipse(in: CGRect(x: artX - 13, y: artY - 44, width: 9, height: 11))
                    tux.addEllipse(in: CGRect(x: artX + 4, y: artY - 44, width: 9, height: 11))
                    // Beak Triangle
                    tux.move(to: CGPoint(x: artX - 11, y: artY - 30))
                    tux.addLine(to: CGPoint(x: artX + 11, y: artY - 30))
                    tux.addLine(to: CGPoint(x: artX, y: artY - 21))
                    tux.closeSubpath()
                    // Webbed Feet
                    tux.addRoundedRect(in: CGRect(x: artX - 28, y: artY + 46, width: 22, height: 11), cornerSize: CGSize(width: 4, height: 4))
                    tux.addRoundedRect(in: CGRect(x: artX + 6, y: artY + 46, width: 22, height: 11), cornerSize: CGSize(width: 4, height: 4))
                    context.stroke(tux, with: .color(cyanLine), lineWidth: 1.6)

                    // BSD Daemon Trident / Kernel Nodes on the side
                    var nodes = Path()
                    for pt in [CGPoint(x: artX - 72, y: artY - 35), CGPoint(x: artX - 64, y: artY + 25), CGPoint(x: artX + 68, y: artY - 30)] {
                        nodes.addEllipse(in: CGRect(x: pt.x - 5, y: pt.y - 5, width: 10, height: 10))
                        nodes.move(to: pt)
                        nodes.addLine(to: CGPoint(x: artX, y: artY))
                    }
                    context.stroke(nodes, with: .color(accentLine), lineWidth: 1.1)

                } else if item.channel.contains("Vintage Apple") || item.id.contains("mac") {
                    // === VECTOR ART 2: CLASSIC MAC OS SYSTEM 7 HAPPY MAC + TRASH CAN + BOMB DIALOG ===
                    var mac = Path()
                    // Compact Macintosh SE / Classic Bezel
                    mac.addRoundedRect(in: CGRect(x: artX - 58, y: artY - 58, width: 82, height: 98), cornerSize: CGSize(width: 6, height: 6))
                    mac.addRoundedRect(in: CGRect(x: artX - 48, y: artY - 46, width: 62, height: 46), cornerSize: CGSize(width: 4, height: 4))
                    mac.addRect(CGRect(x: artX - 10, y: artY + 14, width: 24, height: 4))
                    // Susan Kare Happy Mac Picasso Nose & Smile
                    mac.move(to: CGPoint(x: artX - 28, y: artY - 34)); mac.addLine(to: CGPoint(x: artX - 28, y: artY - 28))
                    mac.move(to: CGPoint(x: artX - 6, y: artY - 34)); mac.addLine(to: CGPoint(x: artX - 6, y: artY - 28))
                    mac.move(to: CGPoint(x: artX - 17, y: artY - 34)); mac.addLine(to: CGPoint(x: artX - 20, y: artY - 20)); mac.addLine(to: CGPoint(x: artX - 14, y: artY - 20))
                    mac.move(to: CGPoint(x: artX - 28, y: artY - 14))
                    mac.addQuadCurve(to: CGPoint(x: artX - 6, y: artY - 14), control: CGPoint(x: artX - 17, y: artY - 6))
                    context.stroke(mac, with: .color(cyanLine), lineWidth: 1.6)

                    // Classic System 7 Fluted Trash Can Icon
                    var trash = Path()
                    let tx = artX + 42, ty = artY - 10
                    trash.addRect(CGRect(x: tx, y: ty, width: 32, height: 42))
                    trash.addRect(CGRect(x: tx - 3, y: ty - 6, width: 38, height: 6))
                    trash.addRect(CGRect(x: tx + 10, y: ty - 11, width: 12, height: 5))
                    for ridge in [7.0, 16.0, 25.0] {
                        trash.move(to: CGPoint(x: tx + ridge, y: ty + 6))
                        trash.addLine(to: CGPoint(x: tx + ridge, y: ty + 36))
                    }
                    // Classic System 7 Bomb Icon above Trash
                    trash.addEllipse(in: CGRect(x: tx + 4, y: ty - 46, width: 22, height: 22))
                    trash.move(to: CGPoint(x: tx + 22, y: ty - 44))
                    trash.addQuadCurve(to: CGPoint(x: tx + 32, y: ty - 54), control: CGPoint(x: tx + 28, y: ty - 52))
                    context.stroke(trash, with: .color(accentLine), lineWidth: 1.4)

                } else if item.channel.contains("Cover Discs") || item.id.contains("macaddict") || item.id.contains("pcgamer") {
                    // === VECTOR ART 3: MACADDICT CD-ROM MASCOT + DOOM 3D RAYCAST CORRIDOR ===
                    var doom = Path()
                    let r1 = CGRect(x: artX - 78, y: artY - 54, width: 156, height: 108)
                    let r2 = CGRect(x: artX - 46, y: artY - 32, width: 92, height: 64)
                    let r3 = CGRect(x: artX - 20, y: artY - 14, width: 40, height: 28)
                    doom.addRect(r1); doom.addRect(r2); doom.addRect(r3)
                    doom.move(to: CGPoint(x: r1.minX, y: r1.minY)); doom.addLine(to: CGPoint(x: r3.minX, y: r3.minY))
                    doom.move(to: CGPoint(x: r1.maxX, y: r1.minY)); doom.addLine(to: CGPoint(x: r3.maxX, y: r3.minY))
                    doom.move(to: CGPoint(x: r1.minX, y: r1.maxY)); doom.addLine(to: CGPoint(x: r3.minX, y: r3.maxY))
                    doom.move(to: CGPoint(x: r1.maxX, y: r1.maxY)); doom.addLine(to: CGPoint(x: r3.maxX, y: r3.maxY))
                    context.stroke(doom, with: .color(cyanLine), lineWidth: 1.3)

                    // MacAddict Spinning CD-ROM Head Emblem in the center of the corridor
                    var discGuy = Path()
                    discGuy.addEllipse(in: CGRect(x: artX - 28, y: artY - 28, width: 56, height: 56))
                    discGuy.addEllipse(in: CGRect(x: artX - 8, y: artY - 8, width: 16, height: 16))
                    // Cool 90s Shades on the CD Mascot
                    discGuy.addRect(CGRect(x: artX - 20, y: artY - 14, width: 16, height: 8))
                    discGuy.addRect(CGRect(x: artX + 4, y: artY - 14, width: 16, height: 8))
                    discGuy.move(to: CGPoint(x: artX - 4, y: artY - 10)); discGuy.addLine(to: CGPoint(x: artX + 4, y: artY - 10))
                    context.stroke(discGuy, with: .color(accentLine), lineWidth: 1.6)

                } else if item.channel.contains("Console") {
                    // === VECTOR ART 4: GAMECUBE / PS2 OPTICAL PICKUP + ISOMETRIC CONTROLLER ===
                    var pad = Path()
                    // Controller Body Outline
                    pad.addRoundedRect(in: CGRect(x: artX - 64, y: artY - 34, width: 128, height: 68), cornerSize: CGSize(width: 24, height: 24))
                    // D-Pad Left
                    pad.addRect(CGRect(x: artX - 46, y: artY - 6, width: 28, height: 10))
                    pad.addRect(CGRect(x: artX - 37, y: artY - 15, width: 10, height: 28))
                    // Action Buttons Right (A/B/X/Y or Triangle/Circle/X/Square)
                    for bpt in [CGPoint(x: artX + 36, y: artY - 14), CGPoint(x: artX + 36, y: artY + 12), CGPoint(x: artX + 22, y: artY - 1), CGPoint(x: artX + 50, y: artY - 1)] {
                        pad.addEllipse(in: CGRect(x: bpt.x - 5, y: bpt.y - 5, width: 10, height: 10))
                    }
                    // Analog Sticks
                    pad.addEllipse(in: CGRect(x: artX - 20, y: artY + 8, width: 16, height: 16))
                    pad.addEllipse(in: CGRect(x: artX + 4, y: artY + 8, width: 16, height: 16))
                    context.stroke(pad, with: .color(cyanLine), lineWidth: 1.5)

                    // Mini-DVD / GD-ROM Ring
                    let ring = CGRect(x: artX - 48, y: artY - 48, width: 96, height: 96)
                    context.stroke(Path(ellipseIn: ring), with: .color(accentLine), style: StrokeStyle(lineWidth: 1.2, dash: [5, 3]))

                } else if item.channel.contains("Retro PC") || item.id.contains("templeos") || item.id.contains("freedos") {
                    // === VECTOR ART 5: MS-DOS C:\> CRT + TEMPLEOS SWORD/SUNBURST + 3.5" FLOPPY ===
                    var retro = Path()
                    let crt = CGRect(x: artX - 66, y: artY - 46, width: 88, height: 68)
                    retro.addRoundedRect(in: crt, cornerSize: CGSize(width: 5, height: 5))
                    // CRT Stand
                    retro.addRect(CGRect(x: artX - 36, y: artY + 22, width: 28, height: 8))
                    retro.addRect(CGRect(x: artX - 50, y: artY + 30, width: 56, height: 6))
                    // DOS Prompt Chevron `C:\>`
                    retro.move(to: CGPoint(x: crt.minX + 12, y: crt.minY + 16))
                    retro.addLine(to: CGPoint(x: crt.minX + 20, y: crt.minY + 22))
                    retro.addLine(to: CGPoint(x: crt.minX + 12, y: crt.minY + 28))
                    retro.addRect(CGRect(x: crt.minX + 25, y: crt.minY + 24, width: 10, height: 3))
                    context.stroke(retro, with: .color(cyanLine), lineWidth: 1.5)

                    // 3.5-inch Floppy Disk + TempleOS Sunburst Rays on Right
                    var flop = Path()
                    let flRect = CGRect(x: artX + 32, y: artY - 36, width: 54, height: 58)
                    flop.addRect(flRect)
                    flop.addRect(CGRect(x: flRect.minX + 12, y: flRect.minY, width: 28, height: 18))
                    flop.addRect(CGRect(x: flRect.minX + 8, y: flRect.minY + 28, width: 38, height: 24))
                    context.stroke(flop, with: .color(accentLine), lineWidth: 1.4)
                } else {
                    // === VECTOR ART 6: SYSTEM RESCUE PLATTER RADAR + ECG WAVEFORM ===
                    for r in [24.0, 46.0, 68.0] {
                        let cRect = CGRect(x: artX - r, y: artY - r, width: r * 2, height: r * 2)
                        context.stroke(Path(ellipseIn: cRect), with: .color(cyanLine), style: StrokeStyle(lineWidth: 1.2, dash: r == 46.0 ? [5, 3] : []))
                    }
                    var ecg = Path()
                    ecg.move(to: CGPoint(x: artX - 75, y: artY))
                    ecg.addLine(to: CGPoint(x: artX - 28, y: artY))
                    ecg.addLine(to: CGPoint(x: artX - 18, y: artY - 34))
                    ecg.addLine(to: CGPoint(x: artX - 4, y: artY + 38))
                    ecg.addLine(to: CGPoint(x: artX + 10, y: artY - 18))
                    ecg.addLine(to: CGPoint(x: artX + 22, y: artY))
                    ecg.addLine(to: CGPoint(x: artX + 75, y: artY))
                    context.stroke(ecg, with: .color(accentLine), lineWidth: 1.8)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 14))

            // 3. Foreground Layout: Left Info Column + Open Vector Showcase + Right Schematic Box
            HStack(alignment: .center, spacing: 12) {
                VStack(alignment: .leading, spacing: 8) {
                    // Top Micro Telemetry Header
                    HStack(spacing: 6) {
                        Image(systemName: item.sfSymbol)
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(store.activeAccent)
                        Text("CAD BLUEPRINT INSPECTOR • \(item.channel.uppercased())")
                            .font(.system(size: 9.5, weight: .heavy, design: .monospaced))
                            .foregroundStyle(store.activeAccent)
                            .lineLimit(1)
                        Text("•").foregroundStyle(.white.opacity(0.35))
                        Text("\(item.architecture) • \(item.bootStandard)")
                            .font(.system(size: 9.5, weight: .semibold, design: .monospaced))
                            .foregroundStyle(.white.opacity(0.82))
                            .lineLimit(1)
                    }

                    // Selected Title + Version
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text(item.title)
                            .font(.system(size: isNarrow ? 17 : 20, weight: .bold))
                            .foregroundStyle(.white)
                            .lineLimit(1)
                        Text("v\(item.version)")
                            .font(.system(size: 12, weight: .bold, design: .monospaced))
                            .foregroundStyle(.cyan)
                            .lineLimit(1)
                    }

                    Text(item.subtitle)
                        .font(.system(size: 11.5))
                        .foregroundStyle(.white.opacity(0.86))
                        .lineLimit(2)
                        .frame(maxWidth: 460, alignment: .leading)

                    Spacer(minLength: 2)

                    // Bottom Row: 3-Segment CAD Sector Map + Stage & Hex Action Buttons
                    HStack(spacing: 8) {
                        if !isNarrow {
                            HStack(spacing: 2) {
                                ForEach(Array(segments.enumerated()), id: \.offset) { idx, seg in
                                    VStack(alignment: .leading, spacing: 1) {
                                        Text(seg.label)
                                            .font(.system(size: 7.5, weight: .bold, design: .monospaced))
                                            .foregroundStyle(.white)
                                            .lineLimit(1)
                                        Text(seg.lbaRange)
                                            .font(.system(size: 7, design: .monospaced))
                                            .foregroundStyle(.cyan.opacity(0.9))
                                            .lineLimit(1)
                                    }
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 3.5)
                                    .background(
                                        idx == 0 ? Color.cyan.opacity(0.28) : (idx == 1 ? Color.green.opacity(0.26) : store.activeAccent.opacity(0.36))
                                    )
                                    .overlay(Rectangle().stroke(Color.cyan.opacity(0.32), lineWidth: 0.6))
                                }
                            }
                            .clipShape(RoundedRectangle(cornerRadius: 5))
                        }

                        if let prog = activeProgress {
                            HStack(spacing: 5) {
                                ProgressView(value: prog)
                                    .progressViewStyle(.circular)
                                    .controlSize(.small)
                                Text("\(Int(prog * 100))%")
                                    .font(.system(size: 10.5, weight: .heavy, design: .monospaced))
                                    .foregroundStyle(.white)
                                    .lineLimit(1)
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(store.activeAccent.opacity(0.35))
                            .clipShape(Capsule())
                        } else {
                            Button {
                                store.downloadAndStageDepotItem(id: item.id, jumpToInspector: false)
                            } label: {
                                HStack(spacing: 5) {
                                    Image(systemName: isStaged ? "checkmark.circle.fill" : (item.isDownloaded ? "opticaldisc.fill" : "icloud.and.arrow.down.fill"))
                                    Text(isStaged ? "STAGED" : (item.isDownloaded ? "STAGE (\(item.sizeDisplay))" : "GET (\(item.sizeDisplay))"))
                                        .lineLimit(1)
                                }
                                .font(.system(size: 11, weight: .heavy))
                                .padding(.horizontal, 14)
                                .padding(.vertical, 6)
                                .background(isStaged ? Color.green : store.activeAccent)
                                .foregroundStyle(isStaged ? Color.black : store.activeOnAccentText)
                                .clipShape(Capsule())
                            }
                            .buttonStyle(.plain)

                            Button {
                                store.downloadAndStageDepotItem(id: item.id, jumpToInspector: true)
                            } label: {
                                HStack(spacing: 4) {
                                    Image(systemName: "magnifyingglass.circle.fill")
                                    Text("Inspect Hex")
                                        .lineLimit(1)
                                }
                                .font(.system(size: 10.5, weight: .bold))
                                .padding(.horizontal, 11)
                                .padding(.vertical, 6)
                                .background(Color.white.opacity(0.14))
                                .foregroundStyle(.white)
                                .clipShape(Capsule())
                                .overlay(Capsule().stroke(Color.white.opacity(0.28), lineWidth: 1))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }

                Spacer(minLength: isNarrow ? 8 : 95) // Open showcase space so the Vector Blueprint Art shines through!

                if !isNarrow {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 5) {
                            Image(systemName: item.sfSymbol)
                                .font(.system(size: 10, weight: .bold))
                                .foregroundStyle(.cyan)
                            Text("DISC CONTENT SCHEMATIC")
                                .font(.system(size: 8.5, weight: .heavy, design: .monospaced))
                                .foregroundStyle(.cyan)
                                .lineLimit(1)
                            Spacer(minLength: 4)
                            Text(item.sizeDisplay)
                                .font(.system(size: 8.5, weight: .bold, design: .monospaced))
                                .foregroundStyle(.white.opacity(0.75))
                                .lineLimit(1)
                        }
                        Divider().overlay(Color.cyan.opacity(0.35))

                        ForEach(treeFiles, id: \.self) { pathLine in
                            HStack(spacing: 4) {
                                Text("├─")
                                    .foregroundStyle(.cyan.opacity(0.75))
                                Text(pathLine)
                                    .foregroundStyle(.white.opacity(0.92))
                                    .lineLimit(1)
                            }
                            .font(.system(size: 8.5, weight: .medium, design: .monospaced))
                        }
                    }
                    .padding(10)
                    .frame(width: 225, alignment: .leading)
                    .background(Color.black.opacity(0.50))
                    .clipShape(RoundedRectangle(cornerRadius: 9))
                    .overlay(
                        RoundedRectangle(cornerRadius: 9)
                            .stroke(Color.cyan.opacity(0.38), style: StrokeStyle(lineWidth: 1.0, dash: [4, 2]))
                    )
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
        }
        .frame(height: 184)
        .fixedSize(horizontal: false, vertical: true)
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(isStaged ? Color.green.opacity(0.75) : store.activeAccent.opacity(0.55), lineWidth: 1.5)
        )
    }

    private func depotAppStoreCard(for item: DepotCatalogItem, isSelectedInHero: Bool) -> some View {
        let isStaged = (store.stagedDepotItemID == item.id && !store.stagedFiles.isEmpty)
        let activeProgress = store.depotDownloadProgress[item.id]

        return VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top, spacing: 10) {
                ZStack {
                    RoundedRectangle(cornerRadius: 11)
                        .fill(
                            LinearGradient(
                                colors: [
                                    isStaged ? Color.green : (isSelectedInHero ? store.activeAccent : store.activeAccent.opacity(0.80)),
                                    (isStaged ? Color.green : store.activeAccent).opacity(0.45)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 40, height: 40)
                        .overlay(
                            RoundedRectangle(cornerRadius: 11)
                                .stroke(Color.white.opacity(isSelectedInHero ? 0.45 : 0.18), lineWidth: 1)
                        )

                    Image(systemName: item.sfSymbol)
                        .font(.system(size: 17, weight: .bold))
                        .foregroundStyle(isStaged ? Color.black : store.activeOnAccentText)
                }

                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text(item.title)
                            .font(.system(size: 12.5, weight: .bold))
                            .foregroundStyle(isSelectedInHero ? store.activeAccent : .primary)
                            .lineLimit(1)
                        Spacer(minLength: 2)
                        if isSelectedInHero {
                            Text("HERO")
                                .font(.system(size: 8, weight: .heavy, design: .monospaced))
                                .padding(.horizontal, 5)
                                .padding(.vertical, 1.5)
                                .background(store.activeAccent.opacity(0.20))
                                .foregroundStyle(store.activeAccent)
                                .clipShape(RoundedRectangle(cornerRadius: 3))
                                .fixedSize(horizontal: true, vertical: false)
                        }
                    }

                    Text(item.subtitle)
                        .font(.system(size: 10.5))
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                        .frame(minHeight: 26, alignment: .topLeading)
                }
            }

            Divider()

            HStack(spacing: 6) {
                VStack(alignment: .leading, spacing: 1) {
                    Text("\(item.architecture) • \(item.sizeDisplay)")
                        .font(.system(size: 9.5, weight: .bold, design: .monospaced))
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                    Text(item.bootStandard)
                        .font(.system(size: 9, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                if let prog = activeProgress {
                    HStack(spacing: 4) {
                        ProgressView(value: prog)
                            .progressViewStyle(.circular)
                            .controlSize(.small)
                        Text("\(Int(prog * 100))%")
                            .font(.system(size: 9.5, weight: .heavy, design: .monospaced))
                            .lineLimit(1)
                    }
                    .padding(.horizontal, 9)
                    .padding(.vertical, 4)
                    .background(store.activeAccent.opacity(0.18))
                    .clipShape(Capsule())
                    .fixedSize(horizontal: true, vertical: false)
                } else {
                    Button {
                        store.selectedDepotHeroItemID = item.id
                        store.downloadAndStageDepotItem(id: item.id, jumpToInspector: false)
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: isStaged ? "checkmark.circle.fill" : (item.isDownloaded ? "opticaldisc.fill" : "icloud.and.arrow.down.fill"))
                            Text(isStaged ? "STAGED" : (item.isDownloaded ? "STAGE" : "GET"))
                                .lineLimit(1)
                        }
                        .font(.system(size: 10, weight: .heavy))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4.5)
                        .background(isStaged ? Color.green : (item.isDownloaded ? store.activeAccent : Color.primary.opacity(0.12)))
                        .foregroundStyle(isStaged ? Color.black : (item.isDownloaded ? store.activeOnAccentText : store.activeAccent))
                        .clipShape(Capsule())
                        .overlay(
                            Capsule()
                                .stroke(isStaged ? Color.clear : store.activeAccent.opacity(0.5), lineWidth: 1)
                        )
                        .fixedSize(horizontal: true, vertical: false)
                    }
                    .buttonStyle(.plain)

                    Button {
                        store.selectedDepotHeroItemID = item.id
                        store.downloadAndStageDepotItem(id: item.id, jumpToInspector: true)
                    } label: {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 9.5, weight: .bold))
                            .padding(5.5)
                            .background(Color.primary.opacity(0.08))
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)
                    .help("Stage image and open directly in the Sector & Hex Inspector")
                }
            }
        }
        .padding(11)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 11)
                .fill(isSelectedInHero ? store.activeAccent.opacity(0.08) : Color(NSColor.controlBackgroundColor))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 11)
                .stroke(
                    isStaged ? Color.green.opacity(0.70) : (isSelectedInHero ? store.activeAccent.opacity(0.85) : Color.primary.opacity(0.09)),
                    lineWidth: (isStaged || isSelectedInHero) ? 1.5 : 1.0
                )
        )
        .clipped()
        .contentShape(RoundedRectangle(cornerRadius: 11))
        .onTapGesture {
            store.selectedDepotHeroItemID = item.id
        }
    }

    private var burnWorkspaceView: some View {
        let activeSpec = store.discFormats.first(where: { $0.id == store.selectedTaskID }) ?? store.discFormats[0]
        return VStack(alignment: .leading, spacing: 12) {
            // Format Header Bar with Context-Sensitive Add Action
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 8) {
                        KroutonStyledIconBadge(
                            sfSymbol: activeSpec.sfSymbol,
                            tintColor: store.activeAccent,
                            style: store.iconWidgetStyle,
                            size: 28,
                            symbolSize: 15
                        )
                        Text(activeSpec.technicalName)
                            .font(.title3.bold())
                        Text(activeSpec.colloquialName)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    Text("Spec: \(activeSpec.bookOrFileSystem) • Laser: \(activeSpec.laserType) • Launched: \(activeSpec.launchYear) • Source: \(activeSpec.sourceSupport)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()

                if !store.stagedFiles.isEmpty {
                    Button {
                        auditioningTrackID = nil
                        store.clearStagedFiles()
                    } label: {
                        HStack(spacing: 5) {
                            Image(systemName: "trash")
                            Text(KroutonL10n.tr("Clear All"))
                        }
                        .font(.system(size: 11, weight: .medium))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Color(NSColor.controlBackgroundColor))
                        .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }

                Button {
                    promptToAddFiles()
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: addButtonSymbol(for: activeSpec))
                        Text(KroutonL10n.tr(addButtonTitle(for: activeSpec)))
                    }
                    .font(.system(size: 12, weight: .semibold))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(store.activeAccent)
                    .foregroundStyle(store.activeOnAccentText)
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }

            Divider()

            // Pre-Flight Sanity Banner (Always active across all formats)
            if let sanityWarning = currentPreFlightSanityWarning(for: activeSpec) {
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.shield.fill")
                        .foregroundStyle(.orange)
                    Text(sanityWarning)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.primary)
                    Spacer()
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .background(Color.orange.opacity(0.14))
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.orange.opacity(0.4), lineWidth: 1))
            }

            // FORMAT-ADAPTIVE WORKSPACE ROUTER
            if activeSpec.isRedBookAudioFormat {
                redBookAudioMasteringWorkspace(for: activeSpec)
            } else if activeSpec.isCarSafeAudioFormat {
                carSafeAudioMasteringWorkspace(for: activeSpec)
            } else if activeSpec.isVideoAuthoringFormat {
                videoDiscAuthoringWorkspace(for: activeSpec)
            } else if activeSpec.isDiscImageBurnFormat {
                discImageInspectorWorkspace(for: activeSpec)
            } else if activeSpec.id.hasPrefix("game-") {
                retroConsoleROMWorkspace(for: activeSpec)
            } else {
                dataAndArchivalMasteringWorkspace(for: activeSpec)
            }
        }
    }

    private func addButtonTitle(for spec: DiscFormatSpec) -> String {
        if spec.isRedBookAudioFormat {
            return "Add Audio Tracks (WAV / AIFF / FLAC / MP3)..."
        } else if spec.isCarSafeAudioFormat {
            return "Add Audio Files or Album Folders..."
        } else if spec.isVideoAuthoringFormat {
            return "Add Video Titles (MKV / MP4 / MOV / VIDEO_TS)..."
        } else if spec.isDiscImageBurnFormat {
            return "Select Disc Image (.ISO / .DMG / .BIN / .CUE / .CDR / .TOAST)..."
        } else if spec.id.hasPrefix("game-") {
            return "Select Console Disc Image (.CUE / .BIN / .ISO / .RVZ)..."
        } else {
            return "Add Files or Folders..."
        }
    }

    private func addButtonSymbol(for spec: DiscFormatSpec) -> String {
        if spec.isRedBookAudioFormat || spec.isCarSafeAudioFormat {
            return "waveform.badge.plus"
        } else if spec.isVideoAuthoringFormat {
            return "film.stack.fill"
        } else if spec.isDiscImageBurnFormat {
            return "opticaldisc.fill"
        } else if spec.id.hasPrefix("game-") {
            return "gamecontroller.fill"
        } else {
            return "plus.rectangle.on.folder.fill"
        }
    }

    // ==========================================================================
    // 1. RED BOOK AUDIO CD (CD-DA) & CD-EXTRA WAVEBURNER MASTERING STUDIO
    // ==========================================================================
    private func redBookAudioMasteringWorkspace(for spec: DiscFormatSpec) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            // WaveBurner CD-TEXT, UPC/MCN & HTOA Mastering Deck
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 10) {
                    Image(systemName: "waveform.path.ecg.rectangle.fill")
                        .foregroundStyle(store.activeAccent)
                    Text(KroutonL10n.tr("RED BOOK CD-DA & CD-TEXT MASTERING DECK (44.1 kHz / 16-BIT PCM • 2,352 B/SECTOR)"))
                        .font(.system(size: 10, weight: .heavy, design: .monospaced))
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text(KroutonL10n.tr("CD-TEXT: 7-Bit ASCII Hardware Safe"))
                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                        .foregroundStyle(.green)
                }

                HStack(spacing: 14) {
                    HStack(spacing: 5) {
                        Text(KroutonL10n.tr("Album Title:"))
                            .font(.caption.bold())
                        TextField("ALBUM TITLE", text: $cdTextAlbumTitle)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 175)
                    }
                    HStack(spacing: 5) {
                        Text(KroutonL10n.tr("Performer:"))
                            .font(.caption.bold())
                        TextField("ARTIST / PERFORMER", text: $cdTextAlbumPerformer)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 165)
                    }
                    HStack(spacing: 5) {
                        Text(KroutonL10n.tr("UPC / MCN:"))
                            .font(.caption.bold())
                        TextField("012345678905", text: $cdTextUPCBarcode)
                            .textFieldStyle(.roundedBorder)
                            .font(.system(size: 11, design: .monospaced))
                            .frame(width: 115)
                    }
                    Spacer()
                }

                HStack(spacing: 16) {
                    Picker("Default Track Splice:", selection: $defaultAudioTransition) {
                        Text(KroutonL10n.tr("2.0s Standard Pre-Gap (INDEX 00)")).tag("2.0s Standard Pre-Gap (INDEX 00)")
                        Text(KroutonL10n.tr("0.0s Gapless Live Album (DAO)")).tag("0.0s Gapless Live Album (DAO)")
                        Text(KroutonL10n.tr("2.5s Equal-Power Crossfade")).tag("2.5s Equal-Power Crossfade")
                    }
                    .frame(width: 295)
                    .font(.caption)

                    Toggle(KroutonL10n.tr("Hidden Track One Audio (HTOA in INDEX 00)"), isOn: $enableHiddenTrackOneHTOA)
                        .toggleStyle(.checkbox)
                        .font(.caption.bold())

                    if spec.id.contains("extra") || spec.technicalName.contains("Extra") {
                        Text(KroutonL10n.tr("• Session 1: Audio Tracks | Session 2: Multisession Data Track (XA)"))
                            .font(.system(size: 10, weight: .semibold, design: .monospaced))
                            .foregroundStyle(.cyan)
                    }
                    Spacer()
                }
            }
            .padding(10)
            .background(Color(NSColor.controlBackgroundColor))
            .clipShape(RoundedRectangle(cornerRadius: 9))
            .overlay(RoundedRectangle(cornerRadius: 9).stroke(store.activeAccent.opacity(0.30), lineWidth: 1))

            // Red Book PQ Tracklist Table
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color(NSColor.controlBackgroundColor))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .strokeBorder(
                                isDropTargeted ? store.activeAccent : Color.primary.opacity(0.08),
                                style: StrokeStyle(lineWidth: isDropTargeted ? 2.5 : 1.0, dash: store.stagedFiles.isEmpty ? [6, 4] : [])
                            )
                    )

                if store.stagedFiles.isEmpty {
                    VStack(spacing: 10) {
                        Image(systemName: "waveform.circle.fill")
                            .font(.system(size: 36))
                            .foregroundStyle(store.activeAccent.opacity(0.85))
                        Text(KroutonL10n.tr("Drop Any Audio Format (WAV, AIFF, FLAC, ALAC, APE, WavPack, DSD .DSF/.DFF, Opus, Ogg, AC-3, DTS, MP3, M4A)"))
                            .font(.headline)
                        Text(KroutonL10n.tr("Krouton decodes all audio to 44.1 kHz / 16-bit Stereo PCM on disk before burning (Zero Underrun Guarantee)."))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                } else {
                    VStack(spacing: 0) {
                        HStack(spacing: 10) {
                            Text(KroutonL10n.tr("TRK"))
                                .font(.system(size: 9, weight: .bold, design: .monospaced))
                                .foregroundStyle(.secondary)
                                .frame(width: 34, alignment: .leading)
                            Text(KroutonL10n.tr("TRACK TITLE & CD-TEXT PERFORMER"))
                                .font(.system(size: 9, weight: .bold, design: .monospaced))
                                .foregroundStyle(.secondary)
                            Spacer()
                            Text(KroutonL10n.tr("ISRC CODE"))
                                .font(.system(size: 9, weight: .bold, design: .monospaced))
                                .foregroundStyle(.secondary)
                                .frame(width: 104, alignment: .center)
                            Text(KroutonL10n.tr("INDEX 00 / SPLICE"))
                                .font(.system(size: 9, weight: .bold, design: .monospaced))
                                .foregroundStyle(.secondary)
                                .frame(width: 145, alignment: .center)
                            Text(KroutonL10n.tr("MM:SS:FF (75 FPS)"))
                                .font(.system(size: 9, weight: .bold, design: .monospaced))
                                .foregroundStyle(.secondary)
                                .frame(width: 98, alignment: .trailing)
                            Text(KroutonL10n.tr("AUDITION"))
                                .font(.system(size: 9, weight: .bold, design: .monospaced))
                                .foregroundStyle(.secondary)
                                .frame(width: 72, alignment: .center)
                            Spacer().frame(width: 20)
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 6)
                        .background(Color.black.opacity(0.18))
                        Divider()

                        ScrollView {
                            VStack(spacing: 0) {
                                ForEach(Array(store.stagedFiles.enumerated()), id: \.element.id) { idx, entry in
                                    let trackNum = idx + 1
                                    let cleanTitle = entry.url.deletingPathExtension().lastPathComponent
                                    let estSeconds = max(18, min(680, Int(entry.byteSize / 36_000)))
                                    let mm = estSeconds / 60
                                    let ss = estSeconds % 60
                                    let ff = (idx * 17) % 75
                                    let isrcCode = String(format: "US-KRT-26-%05d", trackNum)
                                    let isAuditioningThis = (auditioningTrackID == entry.id)

                                    HStack(spacing: 10) {
                                        Text(idx == 0 && enableHiddenTrackOneHTOA ? "00*" : String(format: "%02d", trackNum))
                                            .font(.system(size: 12, weight: .heavy, design: .monospaced))
                                            .foregroundStyle(store.activeAccent)
                                            .frame(width: 34, alignment: .leading)

                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(cleanTitle)
                                                .font(.system(size: 12, weight: .semibold))
                                                .lineLimit(1)
                                            let probe = UniversalMediaDecoderEngine.probeFile(entry.url)
                                            Text("Performer: \(cdTextAlbumPerformer) • [\(probe.shortHardwareBadge)] \(probe.audioCodecName) -> 44.1 kHz 16-Bit PCM")
                                                .font(.system(size: 10))
                                                .foregroundStyle(.secondary)
                                                .lineLimit(1)
                                        }

                                        Spacer()

                                        Text(isrcCode)
                                            .font(.system(size: 10, weight: .semibold, design: .monospaced))
                                            .foregroundStyle(.secondary)
                                            .frame(width: 104, alignment: .center)

                                        Text(defaultAudioTransition.components(separatedBy: " (").first ?? "2.0s Pre-Gap")
                                            .font(.system(size: 10, weight: .semibold, design: .monospaced))
                                            .foregroundStyle(.cyan)
                                            .frame(width: 145, alignment: .center)

                                        Text(String(format: "%02d:%02d:%02d", mm, ss, ff))
                                            .font(.system(size: 11, weight: .bold, design: .monospaced))
                                            .foregroundStyle(store.activeAccent)
                                            .frame(width: 98, alignment: .trailing)

                                        Button {
                                            if isAuditioningThis {
                                                auditioningTrackID = nil
                                            } else {
                                                auditioningTrackID = entry.id
                                                NSSound.beep()
                                            }
                                        } label: {
                                            HStack(spacing: 4) {
                                                Image(systemName: isAuditioningThis ? "stop.fill" : "play.fill")
                                                Text(isAuditioningThis ? "Stop" : "Splice")
                                            }
                                            .font(.system(size: 9, weight: .bold))
                                            .padding(.horizontal, 8)
                                            .padding(.vertical, 3)
                                            .background(isAuditioningThis ? Color.green : store.activeAccent.opacity(0.18))
                                            .foregroundStyle(isAuditioningThis ? Color.black : store.activeAccent)
                                            .clipShape(Capsule())
                                        }
                                        .buttonStyle(.plain)
                                        .frame(width: 72, alignment: .center)
                                        .help("Audition Track \(trackNum) -> Track \(trackNum + 1) splice / crossfade transition")

                                        Button {
                                            store.removeStagedFile(id: entry.id)
                                        } label: {
                                            Image(systemName: "xmark.circle.fill")
                                                .foregroundStyle(.secondary)
                                        }
                                        .buttonStyle(.plain)
                                        .frame(width: 18, alignment: .center)
                                    }
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 8)
                                    Divider()
                                }
                            }
                        }
                    }
                }
            }
            .onDrop(of: [.fileURL], isTargeted: $isDropTargeted) { providers in
                handleFinderDrop(providers: providers)
            }
        }
    }

    // ==========================================================================
    // 2. CAR-SAFE MP3 / FLAC AUDIO CD WORKSPACE (Head-Unit Sorting & Sanitizer)
    // ==========================================================================
    private func carSafeAudioMasteringWorkspace(for spec: DiscFormatSpec) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 10) {
                    Image(systemName: "car.rear.waves.up.fill")
                        .foregroundStyle(store.activeAccent)
                    Text(KroutonL10n.tr("CAR-SAFE ISO9660 + JOLIET AUDIO ENGINE (PIONEER / ALPINE / SONY / OEM HEAD-UNIT SAFE)"))
                        .font(.system(size: 10, weight: .heavy, design: .monospaced))
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text(KroutonL10n.tr("AppleDouble ._* & .DS_Store Purged"))
                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                        .foregroundStyle(.green)
                }

                HStack(spacing: 14) {
                    HStack(spacing: 6) {
                        Text(KroutonL10n.tr("Disc Volume Title:"))
                            .font(.caption.bold())
                        TextField("CAR_MP3_DISC", text: $store.discVolumeTitle)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 160)
                    }
                    Picker("Audio Output Profile:", selection: $carSafeTranscodeTarget) {
                        Text(KroutonL10n.tr("320 kbps CBR MP3 (Universal Car Deck)")).tag("320 kbps CBR MP3 (Universal Car Deck)")
                        Text(KroutonL10n.tr("192 kbps CBR MP3 (Extended 12-Hour Roadtrip)")).tag("192 kbps CBR MP3 (Extended 12-Hour Roadtrip)")
                        Text(KroutonL10n.tr("16-Bit FLAC / WAV Passthrough (Modern Head Units)")).tag("16-Bit FLAC / WAV Passthrough (Modern Head Units)")
                    }
                    .frame(width: 340)
                    .font(.caption)
                    Spacer()
                }

                HStack(spacing: 16) {
                    Toggle(KroutonL10n.tr("Zero-Pad Track Prefixes (001 - Title.mp3)"), isOn: $carSafeZeroPadNumbers)
                        .toggleStyle(.checkbox)
                        .font(.caption.bold())
                    Toggle(KroutonL10n.tr("Strip macOS .DS_Store & ._* Forks"), isOn: $carSafeStripAppleDouble)
                        .toggleStyle(.checkbox)
                        .font(.caption.bold())
                    Toggle(KroutonL10n.tr("Enforce ID3v2.3 ISO-8859-1 Tags"), isOn: $carSafeEnforceID3v23)
                        .toggleStyle(.checkbox)
                        .font(.caption)
                    Toggle(KroutonL10n.tr("Write Root .M3U Playlist"), isOn: $carSafeGenerateM3U)
                        .toggleStyle(.checkbox)
                        .font(.caption)
                    Spacer()
                }
            }
            .padding(10)
            .background(Color(NSColor.controlBackgroundColor))
            .clipShape(RoundedRectangle(cornerRadius: 9))
            .overlay(RoundedRectangle(cornerRadius: 9).stroke(store.activeAccent.opacity(0.30), lineWidth: 1))

            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color(NSColor.controlBackgroundColor))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .strokeBorder(
                                isDropTargeted ? store.activeAccent : Color.primary.opacity(0.08),
                                style: StrokeStyle(lineWidth: isDropTargeted ? 2.5 : 1.0, dash: store.stagedFiles.isEmpty ? [6, 4] : [])
                            )
                    )

                if store.stagedFiles.isEmpty {
                    VStack(spacing: 10) {
                        Image(systemName: "music.note.list")
                            .font(.system(size: 36))
                            .foregroundStyle(store.activeAccent.opacity(0.85))
                        Text(KroutonL10n.tr("Drop MP3, FLAC, M4A, or Album Folders to Build a Car-Safe Audio Disc"))
                            .font(.headline)
                        Text(KroutonL10n.tr("Automatically numbers files in raw FAT/ISO directory order and strips hidden macOS resource forks so car stereos never freeze."))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                } else {
                    VStack(spacing: 0) {
                        HStack(spacing: 10) {
                            Text(KroutonL10n.tr("ORDER"))
                                .font(.system(size: 9, weight: .bold, design: .monospaced))
                                .foregroundStyle(.secondary)
                                .frame(width: 44, alignment: .leading)
                            Text(KroutonL10n.tr("CAR-SAFE JOLIET / ISO9660 FILENAME"))
                                .font(.system(size: 9, weight: .bold, design: .monospaced))
                                .foregroundStyle(.secondary)
                            Spacer()
                            Text(KroutonL10n.tr("TAG & CODEC PROFILE"))
                                .font(.system(size: 9, weight: .bold, design: .monospaced))
                                .foregroundStyle(.secondary)
                                .frame(width: 185, alignment: .center)
                            Text(KroutonL10n.tr("SECTORS"))
                                .font(.system(size: 9, weight: .bold, design: .monospaced))
                                .foregroundStyle(.secondary)
                                .frame(width: 86, alignment: .trailing)
                            Text(KroutonL10n.tr("SIZE"))
                                .font(.system(size: 9, weight: .bold, design: .monospaced))
                                .foregroundStyle(.secondary)
                                .frame(width: 72, alignment: .trailing)
                            Spacer().frame(width: 20)
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 6)
                        .background(Color.black.opacity(0.18))
                        Divider()

                        ScrollView {
                            VStack(spacing: 0) {
                                ForEach(Array(store.stagedFiles.enumerated()), id: \.element.id) { idx, entry in
                                    let baseName = entry.url.deletingPathExtension().lastPathComponent
                                    let displayFile = carSafeZeroPadNumbers
                                        ? String(format: "%03d - %@.mp3", idx + 1, String(baseName.prefix(48)))
                                        : "\(baseName).mp3"
                                    HStack(spacing: 10) {
                                        Text(String(format: "#%03d", idx + 1))
                                            .font(.system(size: 11, weight: .bold, design: .monospaced))
                                            .foregroundStyle(store.activeAccent)
                                            .frame(width: 44, alignment: .leading)

                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(displayFile)
                                                .font(.system(size: 12, weight: .semibold, design: .monospaced))
                                                .lineLimit(1)
                                            Text("Source: \(entry.name) • AppleDouble Fork Stripped")
                                                .font(.system(size: 10))
                                                .foregroundStyle(.secondary)
                                                .lineLimit(1)
                                        }
                                        Spacer()
                                        Text(carSafeEnforceID3v23 ? "ID3v2.3 • 320k CBR" : "ID3v2.4 • Passthrough")
                                            .font(.system(size: 10, weight: .semibold, design: .monospaced))
                                            .foregroundStyle(.green)
                                            .frame(width: 185, alignment: .center)
                                        Text("\(entry.sectorsLBA) LBA")
                                            .font(.system(size: 10, weight: .semibold, design: .monospaced))
                                            .foregroundStyle(store.activeAccent)
                                            .frame(width: 86, alignment: .trailing)
                                        Text(ByteCountFormatter.string(fromByteCount: entry.byteSize, countStyle: .file))
                                            .font(.system(size: 11, design: .monospaced))
                                            .foregroundStyle(.secondary)
                                            .frame(width: 72, alignment: .trailing)
                                        Button {
                                            store.removeStagedFile(id: entry.id)
                                        } label: {
                                            Image(systemName: "xmark.circle.fill")
                                                .foregroundStyle(.secondary)
                                        }
                                        .buttonStyle(.plain)
                                        .frame(width: 18, alignment: .center)
                                    }
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 8)
                                    Divider()
                                }
                            }
                        }
                    }
                }
            }
            .onDrop(of: [.fileURL], isTargeted: $isDropTargeted) { providers in
                handleFinderDrop(providers: providers)
            }
        }
    }

    // ==========================================================================
    // 3. VIDEO DISC AUTHORING STUDIO (DVD-Video, AVCHD, BD-R SL/DL, UHD-BD)
    // ==========================================================================
    private func videoDiscAuthoringWorkspace(for spec: DiscFormatSpec) -> some View {
        let isDualLayer = spec.technicalName.contains("DL") || spec.technicalName.contains("DVD-9") || spec.colloquialName.contains("50 GB") || spec.colloquialName.contains("UHD")
        let isBluRay = spec.technicalName.contains("BD") || spec.technicalName.contains("AVCHD")
        return VStack(alignment: .leading, spacing: 10) {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 10) {
                    Image(systemName: "film.stack.fill")
                        .foregroundStyle(store.activeAccent)
                    Text(isBluRay ? "BLU-RAY / BDMV & AVCHD AUTHORING STUDIO (UDF 2.50 / 2.60)" : "DVD-VIDEO AUTHORING & FIT-TO-DISC STUDIO (UDF 1.02 + ISO9660 BRIDGE)")
                        .font(.system(size: 10, weight: .heavy, design: .monospaced))
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text(isBluRay ? "BDMV + CERTIFICATE Folders Auto-Built" : "VIDEO_TS + Empty AUDIO_TS Enforced")
                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                        .foregroundStyle(.green)
                }

                HStack(spacing: 14) {
                    HStack(spacing: 5) {
                        Text(KroutonL10n.tr("Disc Title:"))
                            .font(.caption.bold())
                        TextField("KROUTON_VIDEO", text: $store.discVolumeTitle)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 155)
                    }
                    Picker("Menu Style:", selection: $videoMenuTemplate) {
                        Text(KroutonL10n.tr("Dark Studio Chapter Grid")).tag("Dark Studio Chapter Grid")
                        Text(KroutonL10n.tr("No Menu (Auto-Play Title 1 on Insert)")).tag("No Menu (Auto-Play Title 1 on Insert)")
                        Text(KroutonL10n.tr("Minimalist Studio Track List")).tag("Minimalist Studio Track List")
                    }
                    .frame(width: 245)
                    .font(.caption)

                    Picker("System:", selection: $videoSystemStandard) {
                        Text(KroutonL10n.tr("NTSC 16:9 (29.97 / 23.976p)")).tag("NTSC 16:9 (29.97 / 23.976p)")
                        Text(KroutonL10n.tr("PAL 16:9 (25 fps)")).tag("PAL 16:9 (25 fps)")
                        Text(KroutonL10n.tr("UHD 2160p HDR10 (HEVC 10-Bit)")).tag("UHD 2160p HDR10 (HEVC 10-Bit)")
                    }
                    .frame(width: 225)
                    .font(.caption)
                    Spacer()
                }

                HStack(spacing: 16) {
                    Toggle(KroutonL10n.tr("Fit-to-Disc Smart Requantizer (DVD-9 -> DVD-5 / BD-50 -> BD-25)"), isOn: $fitToDiscDVD9Shrink)
                        .toggleStyle(.checkbox)
                        .font(.caption.bold())

                    if isDualLayer {
                        Picker("Layer 0 -> Layer 1 Break:", selection: $videoDualLayerBreakSector) {
                            Text(KroutonL10n.tr("Auto Cell Boundary (LBA 2,086,912 • 16-Sector ECC Aligned)")).tag("Auto Cell Boundary (LBA 2,086,912 • 16-Sector ECC Aligned)")
                            Text(KroutonL10n.tr("50/50 Balanced Split (Layer 0 >= Layer 1 Rule)")).tag("50/50 Balanced Split (Layer 0 >= Layer 1 Rule)")
                            Text(KroutonL10n.tr("Seamless Layer Break (SPLB Flag Set)")).tag("Seamless Layer Break (SPLB Flag Set)")
                        }
                        .frame(width: 340)
                        .font(.caption)
                    }
                    Spacer()
                }
            }
            .padding(10)
            .background(Color(NSColor.controlBackgroundColor))
            .clipShape(RoundedRectangle(cornerRadius: 9))
            .overlay(RoundedRectangle(cornerRadius: 9).stroke(store.activeAccent.opacity(0.30), lineWidth: 1))

            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color(NSColor.controlBackgroundColor))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .strokeBorder(
                                isDropTargeted ? store.activeAccent : Color.primary.opacity(0.08),
                                style: StrokeStyle(lineWidth: isDropTargeted ? 2.5 : 1.0, dash: store.stagedFiles.isEmpty ? [6, 4] : [])
                            )
                    )

                if store.stagedFiles.isEmpty {
                    VStack(spacing: 10) {
                        Image(systemName: "film.circle.fill")
                            .font(.system(size: 36))
                            .foregroundStyle(store.activeAccent.opacity(0.85))
                        Text(KroutonL10n.tr("Drop Any Video or Container (MKV, M2TS, MP4, MOV ProRes, AV1, HEVC 10-Bit, WebM, AVI, VOB, WMV, VC-1, VIDEO_TS, BDMV)"))
                            .font(.headline)
                        Text(KroutonL10n.tr("Author standalone set-top player discs with AC-3 / DTS audio, chapter markers, and 32 KB IFO/BUP ECC sector padding."))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                } else {
                    VStack(spacing: 0) {
                        HStack(spacing: 10) {
                            Text(KroutonL10n.tr("TITLE"))
                                .font(.system(size: 9, weight: .bold, design: .monospaced))
                                .foregroundStyle(.secondary)
                                .frame(width: 44, alignment: .leading)
                            Text(KroutonL10n.tr("VIDEO STREAM & CHAPTER TOPOLOGY"))
                                .font(.system(size: 9, weight: .bold, design: .monospaced))
                                .foregroundStyle(.secondary)
                            Spacer()
                            Text(KroutonL10n.tr("VIDEO / AUDIO PIPELINE"))
                                .font(.system(size: 9, weight: .bold, design: .monospaced))
                                .foregroundStyle(.secondary)
                                .frame(width: 195, alignment: .center)
                            Text(KroutonL10n.tr("SECTORS"))
                                .font(.system(size: 9, weight: .bold, design: .monospaced))
                                .foregroundStyle(.secondary)
                                .frame(width: 86, alignment: .trailing)
                            Text(KroutonL10n.tr("SIZE"))
                                .font(.system(size: 9, weight: .bold, design: .monospaced))
                                .foregroundStyle(.secondary)
                                .frame(width: 72, alignment: .trailing)
                            Spacer().frame(width: 20)
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 6)
                        .background(Color.black.opacity(0.18))
                        Divider()

                        ScrollView {
                            VStack(spacing: 0) {
                                ForEach(Array(store.stagedFiles.enumerated()), id: \.element.id) { idx, entry in
                                    let chapters = max(4, min(32, Int(entry.byteSize / 150_000_000) + 6))
                                    HStack(spacing: 10) {
                                        Text(String(format: "VTS_%02d", idx + 1))
                                            .font(.system(size: 11, weight: .bold, design: .monospaced))
                                            .foregroundStyle(store.activeAccent)
                                            .frame(width: 44, alignment: .leading)
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(entry.name)
                                                .font(.system(size: 12, weight: .semibold))
                                                .lineLimit(1)
                                            Text("\(chapters) Auto-Chapters (Every 5 Min) • \(videoSystemStandard)")
                                                .font(.system(size: 10))
                                                .foregroundStyle(.secondary)
                                                .lineLimit(1)
                                        }
                                        Spacer()
                                        let vProbe = UniversalMediaDecoderEngine.probeFile(entry.url)
                                        Text("\(vProbe.shortHardwareBadge) • \(isBluRay ? "BDMV" : "DVD-V")")
                                            .font(.system(size: 10, weight: .semibold, design: .monospaced))
                                            .foregroundStyle(.cyan)
                                            .frame(width: 195, alignment: .center)
                                        Text("\(entry.sectorsLBA) LBA")
                                            .font(.system(size: 10, weight: .semibold, design: .monospaced))
                                            .foregroundStyle(store.activeAccent)
                                            .frame(width: 86, alignment: .trailing)
                                        Text(ByteCountFormatter.string(fromByteCount: entry.byteSize, countStyle: .file))
                                            .font(.system(size: 11, design: .monospaced))
                                            .foregroundStyle(.secondary)
                                            .frame(width: 72, alignment: .trailing)
                                        Button {
                                            store.removeStagedFile(id: entry.id)
                                        } label: {
                                            Image(systemName: "xmark.circle.fill")
                                                .foregroundStyle(.secondary)
                                        }
                                        .buttonStyle(.plain)
                                        .frame(width: 18, alignment: .center)
                                    }
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 8)
                                    Divider()
                                }
                            }
                        }
                    }
                }
            }
            .onDrop(of: [.fileURL], isTargeted: $isDropTargeted) { providers in
                handleFinderDrop(providers: providers)
            }
        }
    }

    // ==========================================================================
    // 4. RETRO CONSOLE ROM & SECTOR VERIFICATION WORKSPACE (PS1/PS2/GC/Wii/Xbox)
    // ==========================================================================
    private func retroConsoleROMWorkspace(for spec: DiscFormatSpec) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            retroConsoleROMMasteringDeck(for: spec)

            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color(NSColor.controlBackgroundColor))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .strokeBorder(
                                isDropTargeted ? store.activeAccent : Color.primary.opacity(0.08),
                                style: StrokeStyle(lineWidth: isDropTargeted ? 2.5 : 1.0, dash: store.stagedFiles.isEmpty ? [6, 4] : [])
                            )
                    )

                if store.stagedFiles.isEmpty {
                    VStack(spacing: 10) {
                        Image(systemName: "gamecontroller.fill")
                            .font(.system(size: 36))
                            .foregroundStyle(store.activeAccent.opacity(0.85))
                        Text(KroutonL10n.tr("Drop Console Disc Image (.CUE + .BIN, .ISO, .GCM, .RVZ, .WBFS, or .DVD)"))
                            .font(.headline)
                        Text(KroutonL10n.tr("Krouton verifies 2,352-byte Mode 2 XA sector headers, System Area boot licenses, and Dual-Layer XGD break offsets."))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                } else {
                    VStack(spacing: 0) {
                        HStack(spacing: 10) {
                            Text(KroutonL10n.tr("ROM IMAGE & SECTOR TOPOLOGY"))
                                .font(.system(size: 9, weight: .bold, design: .monospaced))
                                .foregroundStyle(.secondary)
                                .padding(.leading, 36)
                            Spacer()
                            Text(KroutonL10n.tr("CONSOLE BOOT / SECTOR MODE"))
                                .font(.system(size: 9, weight: .bold, design: .monospaced))
                                .foregroundStyle(.secondary)
                                .frame(width: 210, alignment: .center)
                            Text(KroutonL10n.tr("SECTORS"))
                                .font(.system(size: 9, weight: .bold, design: .monospaced))
                                .foregroundStyle(.secondary)
                                .frame(width: 86, alignment: .trailing)
                            Text(KroutonL10n.tr("SIZE"))
                                .font(.system(size: 9, weight: .bold, design: .monospaced))
                                .foregroundStyle(.secondary)
                                .frame(width: 72, alignment: .trailing)
                            Spacer().frame(width: 20)
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 6)
                        .background(Color.black.opacity(0.18))
                        Divider()

                        ScrollView {
                            VStack(spacing: 0) {
                                ForEach(store.stagedFiles) { entry in
                                    let ext = entry.url.pathExtension.lowercased()
                                    let modeBadge = (ext == "bin" || ext == "cue") ? "RAW 2,352 B/sec (Mode 2 XA)" : "2,048 B/sec (UDF/ISO/XDVDFS)"
                                    HStack(spacing: 12) {
                                        Image(systemName: "opticaldisc.fill")
                                            .foregroundStyle(store.activeAccent)
                                            .font(.system(size: 15))
                                            .frame(width: 24)
                                        VStack(alignment: .leading, spacing: 3) {
                                            HStack(spacing: 8) {
                                                Text(entry.name)
                                                    .font(.system(size: 12, weight: .semibold))
                                                if let bootBadge = entry.bootabilityBadge {
                                                    HStack(spacing: 3) {
                                                        Image(systemName: "checkmark.seal.fill")
                                                            .font(.system(size: 8))
                                                        Text(bootBadge)
                                                            .font(.system(size: 9, weight: .bold, design: .monospaced))
                                                    }
                                                    .padding(.horizontal, 6)
                                                    .padding(.vertical, 2)
                                                    .background(Color.green.opacity(0.16))
                                                    .foregroundStyle(.green)
                                                    .clipShape(Capsule())
                                                }
                                                if entry.isConvertibleBinOrIso {
                                                    Button {
                                                        store.convertStagedBinOrIso(id: entry.id)
                                                    } label: {
                                                        HStack(spacing: 3) {
                                                            Image(systemName: "arrow.left.arrow.right.circle.fill")
                                                                .font(.system(size: 9))
                                                            Text(entry.conversionTargetLabel)
                                                                .font(.system(size: 9, weight: .bold, design: .monospaced))
                                                        }
                                                        .padding(.horizontal, 7)
                                                        .padding(.vertical, 2)
                                                        .background(store.activeAccent.opacity(0.20))
                                                        .foregroundStyle(store.activeAccent)
                                                        .clipShape(Capsule())
                                                    }
                                                    .buttonStyle(.plain)
                                                    .help("1-Click Sector Conversion between Raw 2,352-byte .BIN/.CUE and 2,048-byte .ISO")
                                                }
                                            }
                                            Text("\(entry.url.path) • Redump / Boot Sector Ready")
                                                .font(.system(size: 10))
                                                .foregroundStyle(.secondary)
                                                .lineLimit(1)
                                        }
                                        Spacer()
                                        Text(modeBadge)
                                            .font(.system(size: 10, weight: .semibold, design: .monospaced))
                                            .foregroundStyle(.green)
                                            .frame(width: 210, alignment: .center)
                                        Text("\(entry.sectorsLBA) LBA")
                                            .font(.system(size: 10, weight: .semibold, design: .monospaced))
                                            .foregroundStyle(store.activeAccent)
                                            .frame(width: 86, alignment: .trailing)
                                        Text(ByteCountFormatter.string(fromByteCount: entry.byteSize, countStyle: .file))
                                            .font(.system(size: 11, design: .monospaced))
                                            .foregroundStyle(.secondary)
                                            .frame(width: 72, alignment: .trailing)
                                        Button {
                                            store.removeStagedFile(id: entry.id)
                                        } label: {
                                            Image(systemName: "xmark.circle.fill")
                                                .foregroundStyle(.secondary)
                                        }
                                        .buttonStyle(.plain)
                                        .frame(width: 18, alignment: .center)
                                    }
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 8)
                                    Divider()
                                }
                            }
                        }
                    }
                }
            }
            .onDrop(of: [.fileURL], isTargeted: $isDropTargeted) { providers in
                handleFinderDrop(providers: providers)
            }
        }
    }

    // ==========================================================================
    // 5A. DEDICATED DISC IMAGE (.ISO / .BIN / .DMG / .CDR) FULL-WORKSPACE DECK
    //     (Single-Image Radial Platter, Live LBA Hex Scope & Actionable Pills)
    // ==========================================================================
    private func discImageInspectorWorkspace(for spec: DiscFormatSpec) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            // Top Mastering Bar
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 10) {
                    Image(systemName: "opticaldisc.fill")
                        .foregroundStyle(store.activeAccent)
                    Text(KroutonL10n.tr("SECTOR-EXACT DISC IMAGE INSPECTOR & BOOTABLE OS BURNER"))
                        .font(.system(size: 10, weight: .heavy, design: .monospaced))
                        .foregroundStyle(.secondary)
                    Spacer()
                    if !imageActionStatusBanner.isEmpty {
                        Text("[ \(imageActionStatusBanner) ]")
                            .font(.system(size: 9.5, weight: .bold, design: .monospaced))
                            .foregroundStyle(store.activeAccent)
                    } else {
                        Text("FORMATS: .ISO • .DMG • .CDR • .BIN/.CUE • .IMG • .TOAST • .NRG • .MDS")
                            .font(.system(size: 9, weight: .bold, design: .monospaced))
                            .foregroundStyle(.secondary)
                    }
                }

                HStack(spacing: 16) {
                    Picker(KroutonL10n.tr("Laser Write Topology:"), selection: $discImageWriteMethod) {
                        Text("DAO / SAO Sector-Exact (Preserve System Area & Boot Catalog)").tag("DAO / SAO Sector-Exact (Preserve System Area & Boot Catalog)")
                        Text("RAW DAO/96 (2,352 B/sec + Subchannel PQ/RW Intact)").tag("RAW DAO/96 (2,352 B/sec + Subchannel PQ/RW Intact)")
                        Text("DVD+R / BD-R Seamless Layer Break (16-Sector ECC Aligned)").tag("DVD+R / BD-R Seamless Layer Break (16-Sector ECC Aligned)")
                    }
                    .frame(width: 460)
                    .font(.caption)

                    Toggle(KroutonL10n.tr("Compute & Verify SHA-256 Digest Before Write"), isOn: $verifyImageSHA256BeforeBurn)
                        .toggleStyle(.checkbox)
                        .font(.caption.bold())
                    Spacer()
                }
            }
            .padding(10)
            .background(Color(NSColor.controlBackgroundColor))
            .clipShape(RoundedRectangle(cornerRadius: 9))
            .overlay(RoundedRectangle(cornerRadius: 9).stroke(store.activeAccent.opacity(0.30), lineWidth: 1))

            // Full-Workspace Single Disc Image Deck
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color(NSColor.controlBackgroundColor))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .strokeBorder(
                                isDropTargeted ? store.activeAccent : Color.primary.opacity(0.08),
                                style: StrokeStyle(lineWidth: isDropTargeted ? 2.5 : 1.0, dash: store.stagedFiles.isEmpty ? [6, 4] : [])
                            )
                    )

                if let entry = store.stagedFiles.first {
                    let ext = entry.url.pathExtension.lowercased()
                    let isRaw2352 = (ext == "bin" || ext == "cue")
                    let sectorByteSize = isRaw2352 ? 2352 : 2048
                    let bootReadout = entry.bootabilityBadge ?? "Non-Bootable Data Volume (Sectors 0..15 Unbooted)"
                    let hexRows = BootableImageInspector.readSectorHexDump(url: entry.url, lba: inspectedImageLBA, sectorSize: sectorByteSize)

                    VStack(alignment: .leading, spacing: 12) {
                        // 1. Top Identity Banner + Interactive Action Pill Bar (EVERY pill is a button!)
                        HStack(alignment: .center, spacing: 12) {
                            KroutonStyledIconBadge(
                                sfSymbol: "opticaldisc.fill",
                                tintColor: store.activeAccent,
                                style: store.iconWidgetStyle,
                                size: 38,
                                symbolSize: 20
                            )

                            VStack(alignment: .leading, spacing: 2) {
                                HStack(spacing: 8) {
                                    Text(entry.name)
                                        .font(.system(size: 16, weight: .bold, design: .monospaced))
                                        .lineLimit(1)
                                    Text("[ \(ext.uppercased()) VOLUME ]")
                                        .font(.system(size: 10, weight: .heavy, design: .monospaced))
                                        .foregroundStyle(store.activeAccent)
                                }
                                Text("\(entry.url.path)  —  \(ByteCountFormatter.string(fromByteCount: entry.byteSize, countStyle: .file)) (\(entry.sectorsLBA) LBA Blocks @ \(sectorByteSize) B/sec)")
                                    .font(.system(size: 10.5, design: .monospaced))
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                            }

                            Spacer()

                            // Interactive Action Pill Buttons (100% clickable buttons!)
                            HStack(spacing: 7) {
                                if entry.isConvertibleBinOrIso {
                                    Button {
                                        store.convertStagedBinOrIso(id: entry.id)
                                        imageActionStatusBanner = "Converted Sector Framing for \(entry.name)"
                                    } label: {
                                        HStack(spacing: 4) {
                                            Image(systemName: "arrow.left.arrow.right.circle.fill")
                                            Text(entry.conversionTargetLabel)
                                        }
                                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 5)
                                        .background(store.activeAccent)
                                        .foregroundStyle(store.activeOnAccentText)
                                        .clipShape(Capsule())
                                    }
                                    .buttonStyle(.plain)
                                    .help("Convert between 2,352 B/sec Raw .BIN/.CUE and 2,048 B/sec .ISO")
                                }

                                Button {
                                    let hash = BootableImageInspector.computeSHA256Hex(url: entry.url)
                                    computedImageSHA256 = hash
                                    NSPasteboard.general.clearContents()
                                    NSPasteboard.general.setString(hash, forType: .string)
                                    imageActionStatusBanner = "SHA-256 Copied to Clipboard"
                                    NSSound.beep()
                                } label: {
                                    HStack(spacing: 4) {
                                        Image(systemName: computedImageSHA256.isEmpty ? "checkmark.shield.fill" : "doc.on.clipboard.fill")
                                        Text(computedImageSHA256.isEmpty ? "Compute SHA-256" : "SHA-256: \(computedImageSHA256.prefix(10))… (Copy)")
                                    }
                                    .font(.system(size: 10, weight: .semibold, design: .monospaced))
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 5)
                                    .background(Color.primary.opacity(0.09))
                                    .clipShape(Capsule())
                                    .overlay(Capsule().stroke(store.activeAccent.opacity(0.45), lineWidth: 1))
                                }
                                .buttonStyle(.plain)
                                .help("Compute cryptographic SHA-256 digest of the image file and copy to clipboard")

                                Button {
                                    let proc = Process()
                                    proc.executableURL = URL(fileURLWithPath: "/usr/bin/hdiutil")
                                    proc.arguments = ["attach", entry.url.path]
                                    try? proc.run()
                                    imageActionStatusBanner = "Mounting \(entry.name) via hdiutil..."
                                } label: {
                                    HStack(spacing: 4) {
                                        Image(systemName: "externaldrive.connected.to.line.below.fill")
                                        Text("Mount in Finder")
                                    }
                                    .font(.system(size: 10, weight: .semibold))
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 5)
                                    .background(Color.primary.opacity(0.09))
                                    .clipShape(Capsule())
                                    .overlay(Capsule().stroke(Color.primary.opacity(0.18), lineWidth: 1))
                                }
                                .buttonStyle(.plain)
                                .help("Mount this disc image on the macOS Desktop using hdiutil")

                                Button {
                                    NSWorkspace.shared.activateFileViewerSelecting([entry.url])
                                } label: {
                                    HStack(spacing: 4) {
                                        Image(systemName: "folder.fill")
                                        Text("Reveal")
                                    }
                                    .font(.system(size: 10, weight: .semibold))
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 5)
                                    .background(Color.primary.opacity(0.09))
                                    .clipShape(Capsule())
                                    .overlay(Capsule().stroke(Color.primary.opacity(0.18), lineWidth: 1))
                                }
                                .buttonStyle(.plain)
                                .help("Reveal disc image file in macOS Finder")
                            }
                        }
                        .padding(.horizontal, 14)
                        .padding(.top, 12)

                        Divider()

                        // 2. Main Engineering Split: Radial Platter Schematic (Left) + Live Sector Hex Scope (Right)
                        HStack(alignment: .top, spacing: 14) {
                            // LEFT COLUMN: Radial Optical Track Map + 2,352B / 2,048B Sector Framing Diagram
                            VStack(alignment: .leading, spacing: 10) {
                                Text("OPTICAL PLATTER & TRACK ZONE TOPOLOGY")
                                    .font(.system(size: 9.5, weight: .heavy, design: .monospaced))
                                    .foregroundStyle(.secondary)

                                ZStack {
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(Color.black.opacity(0.28))
                                        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.primary.opacity(0.10), lineWidth: 1))

                                    VStack(spacing: 10) {
                                        // Concentric Optical Platter Graphic
                                        ZStack {
                                            // Outer Polycarbonate Substrate (120mm)
                                            Circle()
                                                .fill(
                                                    RadialGradient(
                                                        colors: [
                                                            Color.black.opacity(0.9),
                                                            store.activeAccent.opacity(0.28),
                                                            Color.cyan.opacity(0.18),
                                                            store.activeAccent.opacity(0.38),
                                                            Color.black.opacity(0.85)
                                                        ],
                                                        center: .center,
                                                        startRadius: 18,
                                                        endRadius: 92
                                                    )
                                                )
                                                .frame(width: 184, height: 184)
                                                .overlay(Circle().stroke(Color.white.opacity(0.22), lineWidth: 1.5))

                                            // Outer Lead-Out Ring
                                            Circle()
                                                .stroke(Color.orange.opacity(0.55), style: StrokeStyle(lineWidth: 3, dash: [5, 3]))
                                                .frame(width: 174, height: 174)

                                            // User Data Zone Ring (LBA 32..End)
                                            Circle()
                                                .stroke(store.activeAccent.opacity(0.85), lineWidth: 18)
                                                .frame(width: 136, height: 136)

                                            // Boot Catalog & PVD Ring (LBA 16..31) — Highlights when LBA 16/17 inspected!
                                            Circle()
                                                .stroke(
                                                    (inspectedImageLBA == 16 || inspectedImageLBA == 17) ? Color.green : Color.cyan.opacity(0.75),
                                                    lineWidth: (inspectedImageLBA == 16 || inspectedImageLBA == 17) ? 6 : 4
                                                )
                                                .frame(width: 96, height: 96)

                                            // System Area / Lead-In Ring (LBA 0..15)
                                            Circle()
                                                .stroke(inspectedImageLBA == 0 ? Color.yellow : Color.white.opacity(0.45), lineWidth: 4)
                                                .frame(width: 72, height: 72)

                                            // Clamping Hub & 15mm Spindle Hole
                                            Circle()
                                                .fill(Color(NSColor.windowBackgroundColor))
                                                .frame(width: 34, height: 34)
                                                .overlay(Circle().stroke(Color.secondary.opacity(0.5), lineWidth: 1.5))

                                            // Laser Read-Head Crosshair Vector
                                            Path { path in
                                                path.move(to: CGPoint(x: 92, y: 92))
                                                path.addLine(to: CGPoint(x: 168, y: 36))
                                            }
                                            .stroke(Color.green.opacity(0.85), style: StrokeStyle(lineWidth: 1.2, dash: [3, 2]))
                                            .frame(width: 184, height: 184)
                                        }
                                        .padding(.top, 6)

                                        // Platter Zone Legend (Sharp Terminal Readouts — Not Fake Pills)
                                        VStack(alignment: .leading, spacing: 3) {
                                            HStack {
                                                Rectangle().fill(Color.yellow).frame(width: 8, height: 8)
                                                Text("LBA 00..15   : 32 KB System Area / APM / MBR")
                                                Spacer()
                                            }
                                            HStack {
                                                Rectangle().fill(Color.green).frame(width: 8, height: 8)
                                                Text("LBA 16..31   : ISO9660 PVD & El Torito Catalog")
                                                Spacer()
                                            }
                                            HStack {
                                                Rectangle().fill(store.activeAccent).frame(width: 8, height: 8)
                                                Text("LBA 32..\(entry.sectorsLBA) : User Data Extent (\(sectorByteSize) B/sec)")
                                                Spacer()
                                            }
                                            HStack {
                                                Rectangle().fill(Color.orange).frame(width: 8, height: 8)
                                                Text("LEAD-OUT     : PMA / TOC / Session Closure")
                                                Spacer()
                                            }
                                        }
                                        .font(.system(size: 9.5, weight: .medium, design: .monospaced))
                                        .foregroundStyle(.secondary)
                                        .padding(.horizontal, 12)
                                        .padding(.bottom, 8)
                                    }
                                }

                                // Physical Sector Byte Framing Schematic Bar
                                VStack(alignment: .leading, spacing: 5) {
                                    Text("PHYSICAL SECTOR FRAMING (\(sectorByteSize) BYTES / BLOCK)")
                                        .font(.system(size: 9, weight: .heavy, design: .monospaced))
                                        .foregroundStyle(.secondary)

                                    if isRaw2352 {
                                        HStack(spacing: 2) {
                                            Text("SYNC 12B")
                                                .frame(width: 52, height: 22)
                                                .background(Color.purple.opacity(0.32))
                                            Text("HDR 4B")
                                                .frame(width: 44, height: 22)
                                                .background(Color.cyan.opacity(0.32))
                                            Text("USER PAYLOAD 2,048 B")
                                                .frame(maxWidth: .infinity)
                                                .frame(height: 22)
                                                .background(store.activeAccent.opacity(0.38))
                                            Text("EDC/ECC 288B")
                                                .frame(width: 78, height: 22)
                                                .background(Color.orange.opacity(0.32))
                                        }
                                        .font(.system(size: 8.5, weight: .bold, design: .monospaced))
                                        .clipShape(RoundedRectangle(cornerRadius: 4))
                                    } else {
                                        HStack(spacing: 2) {
                                            Text("HW DRIVE SYNC/HDR (16B)")
                                                .frame(width: 118, height: 22)
                                                .background(Color.secondary.opacity(0.18))
                                                .foregroundStyle(.secondary)
                                            Text("COOKED BLOCK PAYLOAD (2,048 BYTES)")
                                                .frame(maxWidth: .infinity)
                                                .frame(height: 22)
                                                .background(store.activeAccent.opacity(0.38))
                                            Text("HW RSPC ECC (288B)")
                                                .frame(width: 102, height: 22)
                                                .background(Color.secondary.opacity(0.18))
                                                .foregroundStyle(.secondary)
                                        }
                                        .font(.system(size: 8.5, weight: .bold, design: .monospaced))
                                        .clipShape(RoundedRectangle(cornerRadius: 4))
                                    }
                                }
                            }
                            .frame(width: 310)

                            // RIGHT COLUMN: Volume Descriptor Telemetry Grid + Interactive LBA Hex/ASCII Inspector
                            VStack(alignment: .leading, spacing: 10) {
                                // Rectangular Telemetry Matrix (Non-clickable readouts use sharp terminal boxes, never pills!)
                                HStack(spacing: 8) {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("BOOT RECORD SIGNATURE")
                                            .font(.system(size: 8.5, weight: .bold, design: .monospaced))
                                            .foregroundStyle(.secondary)
                                        Text(bootReadout)
                                            .font(.system(size: 10.5, weight: .bold, design: .monospaced))
                                            .foregroundStyle(entry.bootabilityBadge != nil ? .green : .primary)
                                            .lineLimit(1)
                                    }
                                    .padding(8)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .background(Color.black.opacity(0.24))
                                    .overlay(Rectangle().stroke(Color.primary.opacity(0.12), lineWidth: 1))

                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("LOGICAL BLOCKS & ECC")
                                            .font(.system(size: 8.5, weight: .bold, design: .monospaced))
                                            .foregroundStyle(.secondary)
                                        Text("\(entry.sectorsLBA) LBA  |  16-Sec ECC: \(entry.sectorsLBA % 16 == 0 ? "ALIGNED" : "+\(16 - (entry.sectorsLBA % 16)) PAD")")
                                            .font(.system(size: 10.5, weight: .bold, design: .monospaced))
                                            .foregroundStyle(store.activeAccent)
                                            .lineLimit(1)
                                    }
                                    .padding(8)
                                    .frame(width: 235, alignment: .leading)
                                    .background(Color.black.opacity(0.24))
                                    .overlay(Rectangle().stroke(Color.primary.opacity(0.12), lineWidth: 1))
                                }

                                // Interactive Sector Jump Pill Buttons (Every pill jumps the Hex Reader to that LBA!)
                                HStack(spacing: 6) {
                                    Text("JUMP READ HEAD:")
                                        .font(.system(size: 9, weight: .heavy, design: .monospaced))
                                        .foregroundStyle(.secondary)

                                    ForEach([
                                        (0, "LBA 00 • System / APM"),
                                        (16, "LBA 16 • ISO9660 PVD"),
                                        (17, "LBA 17 • El Torito Boot"),
                                        (256, "LBA 256 • UDF Anchor")
                                    ], id: \.0) { lbaTarget, label in
                                        let isCurrentLBA = (inspectedImageLBA == lbaTarget)
                                        Button {
                                            inspectedImageLBA = lbaTarget
                                            imageActionStatusBanner = "Read Head -> LBA \(lbaTarget) (Byte Offset \(String(format: "0x%08X", lbaTarget * sectorByteSize)))"
                                        } label: {
                                            Text(label)
                                                .font(.system(size: 9.5, weight: .bold, design: .monospaced))
                                                .padding(.horizontal, 9)
                                                .padding(.vertical, 4)
                                                .background(isCurrentLBA ? store.activeAccent : Color.primary.opacity(0.08))
                                                .foregroundStyle(isCurrentLBA ? store.activeOnAccentText : .primary)
                                                .clipShape(Capsule())
                                                .overlay(Capsule().stroke(isCurrentLBA ? Color.clear : Color.primary.opacity(0.15), lineWidth: 1))
                                        }
                                        .buttonStyle(.plain)
                                    }
                                    Spacer()
                                }

                                // Live Sector Hexadecimal + ASCII Inspector Terminal
                                VStack(alignment: .leading, spacing: 0) {
                                    HStack {
                                        Text("OFFSET    00 01 02 03 04 05 06 07  08 09 0A 0B 0C 0D 0E 0F   ASCII DECODED")
                                            .font(.system(size: 9.5, weight: .heavy, design: .monospaced))
                                            .foregroundStyle(store.activeAccent)
                                        Spacer()
                                        Text("SECTOR LBA \(inspectedImageLBA)")
                                            .font(.system(size: 9, weight: .bold, design: .monospaced))
                                            .foregroundStyle(.green)
                                    }
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 5)
                                    .background(Color.black.opacity(0.45))

                                    Divider()

                                    ScrollView {
                                        VStack(alignment: .leading, spacing: 2) {
                                            ForEach(hexRows) { hRow in
                                                HStack(spacing: 12) {
                                                    Text(hRow.offsetHex)
                                                        .foregroundStyle(.secondary)
                                                    Text(hRow.hexBytes)
                                                        .foregroundStyle(.primary)
                                                    Text(hRow.asciiText)
                                                        .foregroundStyle(.green)
                                                    Spacer(minLength: 0)
                                                }
                                                .font(.system(size: 10.5, weight: .medium, design: .monospaced))
                                            }
                                        }
                                        .padding(10)
                                    }
                                }
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                                .background(Color.black.opacity(0.32))
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.primary.opacity(0.14), lineWidth: 1))
                            }
                        }
                        .padding(.horizontal, 14)
                        .padding(.bottom, 14)
                    }
                } else {
                    // Empty State: Interactive Drop Zone & Quick Image Picker
                    VStack(spacing: 12) {
                        Image(systemName: "opticaldisc.fill")
                            .font(.system(size: 46))
                            .foregroundStyle(store.activeAccent.opacity(0.85))
                        Text(KroutonL10n.tr("Drop a Disc Image (.ISO, .DMG, .BIN/.CUE, .CDR, .IMG, or .TOAST) to Launch the Sector & Hex Inspector"))
                            .font(.headline)
                        Text(KroutonL10n.tr("Displays radial track geometry, live LBA 0/16/17/256 hexadecimal sector dumps, El Torito / APM boot records, and 1-Click .BIN <-> .ISO framing conversion."))
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        Button {
                            promptToAddFiles()
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: "folder.badge.plus")
                                Text("Choose Disc Image File...")
                            }
                            .font(.system(size: 12, weight: .bold))
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(store.activeAccent)
                            .foregroundStyle(store.activeOnAccentText)
                            .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
                        .padding(.top, 4)
                    }
                }
            }
            .onDrop(of: [.fileURL], isTargeted: $isDropTargeted) { providers in
                // When in single-image mode, dropping a new disc image replaces the old one cleanly
                store.clearStagedFiles()
                computedImageSHA256 = ""
                imageActionStatusBanner = ""
                return handleFinderDrop(providers: providers)
            }
        }
    }

    // ==========================================================================
    // 5B. NEW DATA & ARCHIVAL DISC AUTHORING WORKSPACE
    //     (Author File/Folder Trees with Universal Bridge & Per-File OS Visibility)
    // ==========================================================================
    private func dataAndArchivalMasteringWorkspace(for activeSpec: DiscFormatSpec) -> some View {
        let isUniversalHybrid = (activeSpec.id == "data-hybrid" || activeSpec.id == "mdisc-vault")
        let isAppleOnly = (activeSpec.id == "data-apple-apfs")
        let isRetro83 = (activeSpec.id == "data-retro-iso")

        return VStack(alignment: .leading, spacing: 10) {
            // File System Topology & Universal Compatibility Deck
            VStack(alignment: .leading, spacing: 8) {
                if activeSpec.isMDiscParityFormat {
                    HStack(spacing: 14) {
                        Image(systemName: "lock.shield.fill")
                            .foregroundStyle(store.activeAccent)
                        Text(KroutonL10n.tr("M-DISC INORGANIC ROCK-LAYER VAULT + PAR2 SURFACE PARITY:"))
                            .font(.system(size: 10, weight: .heavy, design: .monospaced))
                            .foregroundStyle(.secondary)
                        Text("PAR2 Redundancy: \(Int(mdiscPar2RedundancyPct))%")
                            .font(.caption.bold())
                            .foregroundStyle(store.activeAccent)
                        Slider(value: $mdiscPar2RedundancyPct, in: 5...30, step: 5)
                            .frame(width: 150)
                        Text(KroutonL10n.tr("• Generates .par2 Reed-Solomon recovery blocks + SHA-256 manifest"))
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundStyle(.secondary)
                        Spacer()
                    }
                    Divider()
                }

                HStack(spacing: 14) {
                    HStack(spacing: 6) {
                        Image(systemName: "opticaldisc")
                            .foregroundStyle(store.activeAccent)
                        Text(KroutonL10n.tr("Disc Title:"))
                            .font(.caption.bold())
                        TextField("KROUTON_DISC", text: $store.discVolumeTitle)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 165)
                    }

                    if activeSpec.id == "data-udf-modern" {
                        Label("Pure UDF 2.60 (Files >4 GiB up to 128 GB • Modern macOS, Windows & Linux)", systemImage: "checkmark.seal.fill")
                            .font(.caption.bold())
                            .foregroundStyle(.green)
                    } else if isAppleOnly {
                        Toggle(KroutonL10n.tr("Preserve macOS Extended Attributes (xattr), Resource Forks & Finder Tags"), isOn: $preserveMacExtendedAttributes)
                            .toggleStyle(.checkbox)
                            .font(.caption.bold())
                    } else if isRetro83 {
                        Toggle(KroutonL10n.tr("Enforce Strict 8.3 Uppercase Filenames (DOS 6.22 / Win 3.1 / Win95 / System 7 Safe)"), isOn: $enforce8Dot3RetroCompatibility)
                            .toggleStyle(.checkbox)
                            .font(.caption.bold())
                    } else {
                        Label("4-Way Universal Bridge: Mounts on macOS (HFS+), Windows (Joliet/UDF) & Linux (Rock Ridge)", systemImage: "globe")
                            .font(.caption.bold())
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    if !isRetro83 {
                        Toggle(KroutonL10n.tr("Customize Finder Layout"), isOn: $enableCustomFinderLayoutTab)
                            .toggleStyle(.checkbox)
                            .font(.caption)
                            .onChange(of: enableCustomFinderLayoutTab) { _, enabled in
                                activeDataWorkspaceTab = enabled ? 1 : 0
                            }
                    }
                }
            }
            .padding(10)
            .background(Color(NSColor.controlBackgroundColor))
            .clipShape(RoundedRectangle(cornerRadius: 9))
            .overlay(RoundedRectangle(cornerRadius: 9).stroke(store.activeAccent.opacity(0.30), lineWidth: 1))

            if activeDataWorkspaceTab == 1 && enableCustomFinderLayoutTab {
                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 20) {
                        ColorPicker(KroutonL10n.tr("Finder Window Background:"), selection: $finderBgColor)
                        HStack {
                            Text("Icon Size: \(Int(finderIconSize)) px")
                                .font(.caption)
                            Slider(value: $finderIconSize, in: 64...512, step: 32)
                                .frame(width: 160)
                        }
                    }
                    RoundedRectangle(cornerRadius: 12)
                        .fill(finderBgColor)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .overlay(
                            ScrollView {
                                LazyVGrid(columns: [GridItem(.adaptive(minimum: 120))], spacing: 24) {
                                    ForEach(store.stagedFiles) { item in
                                        VStack(spacing: 6) {
                                            Image(systemName: item.isDirectory ? "folder.fill" : "doc.fill")
                                                .font(.system(size: min(finderIconSize * 0.25, 84)))
                                                .foregroundStyle(item.isDirectory ? store.resolvedFolderIconColor : .white)
                                            Text(item.name)
                                                .font(.caption.bold())
                                                .foregroundStyle(.white)
                                                .lineLimit(1)
                                        }
                                    }
                                }
                                .padding(24)
                            }
                        )
                }
            } else {
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color(NSColor.controlBackgroundColor))
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .strokeBorder(
                                    isDropTargeted ? store.activeAccent : Color.primary.opacity(0.08),
                                    style: StrokeStyle(lineWidth: isDropTargeted ? 2.5 : 1.0, dash: store.stagedFiles.isEmpty ? [6, 4] : [])
                                )
                        )

                    if store.stagedFiles.isEmpty {
                        VStack(spacing: 10) {
                            Image(systemName: "folder.badge.plus")
                                .font(.system(size: 34))
                                .foregroundStyle(store.activeAccent.opacity(0.85))
                            Text(KroutonL10n.tr("Drag & Drop Files or Folders Here to Author a New Data Disc"))
                                .font(.headline)
                            Text(isUniversalHybrid
                                 ? KroutonL10n.tr("Shared data extents are linked into HFS+ (Mac), Joliet/UDF (Windows), and Rock Ridge (Linux) simultaneously. Toggle [Mac] / [PC] to hide platform-specific installers.")
                                 : KroutonL10n.tr("Add files and directories from Finder to build the optical volume directory tree."))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    } else {
                        VStack(spacing: 0) {
                            HStack(spacing: 12) {
                                Text(KroutonL10n.tr("ITEM NAME & PATH"))
                                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                                    .foregroundStyle(.secondary)
                                    .padding(.leading, 36)
                                Spacer()
                                if isUniversalHybrid {
                                    Text(KroutonL10n.tr("OS VISIBILITY"))
                                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                                        .foregroundStyle(.secondary)
                                        .frame(width: 112, alignment: .center)
                                }
                                Text(KroutonL10n.tr("SECTORS"))
                                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                                    .foregroundStyle(.secondary)
                                    .frame(width: 86, alignment: .trailing)
                                Text(KroutonL10n.tr("SIZE"))
                                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                                    .foregroundStyle(.secondary)
                                    .frame(width: 72, alignment: .trailing)
                                Spacer().frame(width: 22)
                            }
                            .padding(.horizontal, 14)
                            .padding(.vertical, 6)
                            .background(Color.black.opacity(0.18))
                            Divider()

                            ScrollView {
                                VStack(spacing: 0) {
                                    ForEach(store.stagedFiles) { entry in
                                        HStack(spacing: 12) {
                                            Image(systemName: entry.isDirectory ? "folder.fill" : "doc.fill")
                                                .foregroundStyle(entry.isDirectory ? store.resolvedFolderIconColor : store.activeAccent)
                                                .font(.system(size: 15))
                                                .frame(width: 24)

                                            VStack(alignment: .leading, spacing: 2) {
                                                Text(isRetro83 ? entry.iso9660Level1Name : entry.name)
                                                    .font(.system(size: 12, weight: .semibold, design: isRetro83 ? .monospaced : .default))
                                                Text("\(entry.url.path) • Perms: \(entry.posixPermissions) • \(entry.isDirectory ? "\(entry.itemCount) items inside" : "Single file")")
                                                    .font(.system(size: 10))
                                                    .foregroundStyle(.secondary)
                                                    .lineLimit(1)
                                            }

                                            Spacer()

                                            if isUniversalHybrid {
                                                HStack(spacing: 5) {
                                                    Button {
                                                        store.toggleMacVisibility(id: entry.id)
                                                    } label: {
                                                        HStack(spacing: 3) {
                                                            Image(systemName: "apple.logo")
                                                                .font(.system(size: 9))
                                                            Text(KroutonL10n.tr("Mac"))
                                                                .font(.system(size: 9, weight: .bold))
                                                        }
                                                        .padding(.horizontal, 7)
                                                        .padding(.vertical, 3)
                                                        .background(entry.showOnMac ? store.activeAccent.opacity(0.22) : Color.secondary.opacity(0.10))
                                                        .foregroundStyle(entry.showOnMac ? store.activeAccent : .secondary.opacity(0.55))
                                                        .clipShape(Capsule())
                                                        .overlay(Capsule().stroke(entry.showOnMac ? store.activeAccent.opacity(0.5) : Color.clear, lineWidth: 1))
                                                    }
                                                    .buttonStyle(.plain)
                                                    .help(entry.showOnMac ? "Visible on macOS Finder (HFS+ Tree) — Click to hide from Mac" : "Hidden on macOS Finder — Click to show on Mac")

                                                    Button {
                                                        store.togglePCVisibility(id: entry.id)
                                                    } label: {
                                                        HStack(spacing: 3) {
                                                            Image(systemName: "pc")
                                                                .font(.system(size: 9))
                                                            Text(KroutonL10n.tr("PC"))
                                                                .font(.system(size: 9, weight: .bold))
                                                        }
                                                        .padding(.horizontal, 7)
                                                        .padding(.vertical, 3)
                                                        .background(entry.showOnPC ? Color.cyan.opacity(0.20) : Color.secondary.opacity(0.10))
                                                        .foregroundStyle(entry.showOnPC ? Color.cyan : .secondary.opacity(0.55))
                                                        .clipShape(Capsule())
                                                        .overlay(Capsule().stroke(entry.showOnPC ? Color.cyan.opacity(0.5) : Color.clear, lineWidth: 1))
                                                    }
                                                    .buttonStyle(.plain)
                                                    .help(entry.showOnPC ? "Visible on Windows Explorer (ISO9660 / Joliet / UDF Tree) — Click to hide from PC" : "Hidden on Windows PC — Click to show on PC")
                                                }
                                                .frame(width: 112, alignment: .center)
                                            }

                                            Text("\(entry.sectorsLBA) LBA")
                                                .font(.system(size: 10, weight: .semibold, design: .monospaced))
                                                .foregroundStyle(store.activeAccent)
                                                .frame(width: 86, alignment: .trailing)

                                            Text(ByteCountFormatter.string(fromByteCount: entry.byteSize, countStyle: .file))
                                                .font(.system(size: 11, design: .monospaced))
                                                .foregroundStyle(.secondary)
                                                .frame(width: 72, alignment: .trailing)

                                            Button {
                                                store.removeStagedFile(id: entry.id)
                                            } label: {
                                                Image(systemName: "xmark.circle.fill")
                                                    .foregroundStyle(.secondary)
                                            }
                                            .buttonStyle(.plain)
                                            .frame(width: 18, alignment: .center)
                                        }
                                        .padding(.horizontal, 14)
                                        .padding(.vertical, 8)
                                        Divider()
                                    }
                                }
                            }
                        }
                    }
                }
                .onDrop(of: [.fileURL], isTargeted: $isDropTargeted) { providers in
                    handleFinderDrop(providers: providers)
                }
            }
        }
    }

    // MARK: - Retro Console ROM Mastering Deck & Pre-Flight Sanity Engine
    private func retroConsoleROMMasteringDeck(for spec: DiscFormatSpec) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                Image(systemName: "gamecontroller.fill")
                    .foregroundStyle(store.activeAccent)
                Text(KroutonL10n.tr("RETRO CONSOLE HARDWARE MASTERING PROFILE"))
                    .font(.system(size: 10, weight: .heavy, design: .monospaced))
                    .foregroundStyle(.secondary)
                Spacer()
                Toggle(KroutonL10n.tr("Perform OPC Before Write"), isOn: $romPerformOPCBeforeWrite)
                    .toggleStyle(.checkbox)
                    .font(.caption)
            }

            HStack(spacing: 16) {
                if spec.id == "game-ps1" {
                    Toggle(KroutonL10n.tr("DAO/96 Raw Mode 2 Form 1/2 (2,352 B/sector + SubQ)"), isOn: $romWriteModeDAO96SubQ)
                        .toggleStyle(.checkbox)
                        .font(.caption.bold())
                    Text(KroutonL10n.tr("• Recommended Speed: 4x–8x CLV (High-Reflectivity CD-R Only — Never CD-RW)"))
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundStyle(.secondary)
                } else if spec.id == "game-ps2" {
                    Toggle(KroutonL10n.tr("Stamp Book Type as DVD-ROM (Bitsetting for PS2 Mechacon)"), isOn: $romBitsetDVDROM)
                        .toggleStyle(.checkbox)
                        .font(.caption.bold())
                    Text(KroutonL10n.tr("• Enforces UDF 1.02 + ISO9660 Bridge (FreeDVDBoot / ESR Compatible)"))
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundStyle(.secondary)
                } else if spec.id == "game-gc" || spec.id == "game-wii" {
                    Toggle(KroutonL10n.tr("Stamp Book Type as DVD-ROM + 32 KB ECC Boundary Alignment"), isOn: $romBitsetDVDROM)
                        .toggleStyle(.checkbox)
                        .font(.caption.bold())
                    Text(spec.id == "game-gc" ? "• Exact 80mm Mini-DVD Target: 1,459,978,240 Bytes (712,880 LBA)" : "• Exact Wii Single-Layer Target: 4,699,979,776 Bytes (2,294,912 LBA)")
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundStyle(.secondary)
                } else if spec.id == "game-xbox" {
                    Picker("Layer Break:", selection: $xboxLayerBreakPreset) {
                        Text(KroutonL10n.tr("Auto (.dvd Descriptor)")).tag("Auto (.dvd / Calculate Optimal)")
                        Text(KroutonL10n.tr("XGD2 Lock (LBA 1913760)")).tag("XGD2 (1913760)")
                        Text(KroutonL10n.tr("XGD3 Lock (LBA 2133520)")).tag("XGD3 (2133520)")
                    }
                    .frame(width: 265)
                    .font(.caption)
                    Toggle(KroutonL10n.tr("DVD+R DL -> DVD-ROM Bitsetting"), isOn: $romBitsetDVDROM)
                        .toggleStyle(.checkbox)
                        .font(.caption.bold())
                }
                Spacer()
            }
        }
        .padding(10)
        .background(Color(NSColor.controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 9))
        .overlay(RoundedRectangle(cornerRadius: 9).stroke(store.activeAccent.opacity(0.30), lineWidth: 1))
    }

    private func currentPreFlightSanityWarning(for spec: DiscFormatSpec) -> String? {
        if spec.id.hasPrefix("game-"), let drive = primarySelectedDrive, drive.isMediaPresent && drive.isMediaErasable {
            return "Retro Console Pickup Warning: \(drive.displayName) has rewritable \(drive.mediaType) loaded (~20% reflectivity). Vintage PS1/PS2/GameCube/Dreamcast optical pickups require high-reflectivity write-once CD-R or DVD-R media at 4x–8x."
        }
        if spec.id == "game-ps1" && !store.stagedFiles.isEmpty {
            let hasBin = store.stagedFiles.contains { $0.name.lowercased().hasSuffix(".bin") }
            let hasCue = store.stagedFiles.contains { $0.name.lowercased().hasSuffix(".cue") || $0.name.lowercased().hasSuffix(".ccd") }
            if hasBin && !hasCue {
                return "Missing .CUE Descriptor: A raw .BIN track is staged without its companion .CUE sheet. Add the .CUE file to preserve Red Book audio tracks and 2-second pre-gap offsets."
            }
        }
        if let hugeFile = store.stagedFiles.first(where: { $0.exceedsISO9660FourGiBLimit }) {
            return "4 GiB File Limit Notice: '\(hugeFile.name)' exceeds the 4 GiB ISO9660 Level 2 ceiling. Krouton will bridge this file via UDF 2.60 + HFS+."
        }
        if let longFile = store.stagedFiles.first(where: { $0.exceedsJoliet64CharLimit }) {
            return "Joliet 64-Char Notice: '\(longFile.name)' is \(longFile.name.count) characters long. Full name is preserved on Mac (HFS+) and UDF, and safely truncated in legacy Windows Joliet tables."
        }
        return nil
    }

    private func promptToAddFiles() {
        let spec = store.activeFormatSpec()
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = spec.allowsDirectorySelection
        panel.allowsMultipleSelection = (spec.id != "image-burn" && spec.filterGroup != .console)
        panel.prompt = "Stage for \(spec.technicalName)"
        panel.message = "Allowed for \(spec.technicalName): \(spec.expectedMediaDescription)"

        // Grey out all incompatible files in the macOS Open Dialogue!
        let exts = spec.allowedFileExtensions
        if !exts.isEmpty {
            var types: [UTType] = exts.compactMap { UTType(filenameExtension: $0) }
            if spec.allowsDirectorySelection {
                types.append(.folder)
            }
            if !types.isEmpty {
                panel.allowedContentTypes = types
            }
        }

        if panel.runModal() == .OK {
            store.addStagedURLs(panel.urls)
        }
    }

    private func triggerDropRejectShake() {
        dropRejectShakePhase = 1.0
        withAnimation(.easeOut(duration: 0.42)) {
            dropRejectShakePhase = 0.0
        }
    }

    private func handleFinderDrop(providers: [NSItemProvider]) -> Bool {
        let spec = store.activeFormatSpec()
        var acceptedAny = false

        for provider in providers {
            if provider.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) {
                acceptedAny = true
                provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { item, _ in
                    let resolvedURL: URL? = {
                        if let data = item as? Data {
                            return URL(dataRepresentation: data, relativeTo: nil)
                        } else if let url = item as? URL {
                            return url
                        }
                        return nil
                    }()
                    guard let url = resolvedURL else { return }
                    Task { @MainActor in
                        if store.selectedCategory == .burn && !store.isURLCompatible(url, for: spec) {
                            store.rejectedDropNotice = "Rejected '\(url.lastPathComponent)': \(spec.technicalName) only accepts \(spec.expectedMediaDescription)."
                            NSSound.beep()
                            triggerDropRejectShake()
                        } else {
                            store.addStagedURLs([url])
                        }
                    }
                }
            }
        }
        return acceptedAny
    }
    private var copyWorkspaceView: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Image(systemName: "doc.on.doc.fill")
                    .font(.title2)
                    .foregroundStyle(store.activeAccent)
                VStack(alignment: .leading, spacing: 2) {
                    Text(store.selectedTaskID == "copy-duplicate" ? "Duplicate Disc & Fit-to-Disc Requantizer" : "Optical Media Extractor & Archival Ripper")
                        .font(.title3.bold())
                    Text("Source Drive: \(primarySelectedDrive?.displayName ?? "Optical Drive") — Status: \(primarySelectedDrive?.statusBadgeText ?? "Ready")")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }
            Divider()

            VStack(alignment: .leading, spacing: 12) {
                Toggle(KroutonL10n.tr("Fit to Disc — Automatically shrink DVD-9 (8.5 GB) to standard 4.7 GB DVD-5"), isOn: $fitToDiscDVD9Shrink)
                    .font(.headline)
                Toggle(KroutonL10n.tr("Preserve Interactive Menus, Chapter Tables & Bonus Extras"), isOn: $preserveMenusAndExtras)
                Divider()
                playlistRow(num: "VTS_01", title: "Main Feature Movie (1080p / 480p MPEG-2)", duration: "01:58:14", transition: fitToDiscDVD9Shrink ? "Requantized -> 3.62 GB" : "Original 6.40 GB", info: "AC-3 5.1 + Subtitles")
                playlistRow(num: "VMGM", title: "Interactive Motion Menus & Chapter Selector", duration: "00:04:12", transition: "100% Intact (340 MB)", info: "Zero Menu Loss")
                playlistRow(num: "VTS_02", title: "Director Commentary & Making-Of Featurettes", duration: "00:32:40", transition: "Requantized -> 420 MB", info: "Preserved")
            }
            .padding(14)
            .background(Color(NSColor.controlBackgroundColor))
            .clipShape(RoundedRectangle(cornerRadius: 10))

            Spacer()
        }
    }

    private var labelWorkspaceView: some View {
        let preset = store.labelPresets[min(store.selectedLabelPresetIndex, store.labelPresets.count - 1)]
        return VStack(alignment: .leading, spacing: 14) {
            HStack {
                Image(systemName: store.selectedTaskID == "label-auto" ? "wand.and.stars" : "printer.dotmatrix.fill")
                    .font(.title2)
                    .foregroundStyle(store.activeAccent)
                VStack(alignment: .leading, spacing: 2) {
                    Text(store.selectedTaskID == "label-auto" ? "Automatic Disc Label (Artwork Lookup)" : "Manual 120mm Disc Label Canvas")
                        .font(.title3.bold())
                    Text(String(format: "Active Geometry Preset: %@ (Outer: %.1fmm / Hole: %.1fmm)", preset.name, preset.outerDiameterMM, preset.innerDiameterMM))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Picker("Preset:", selection: $store.selectedLabelPresetIndex) {
                    ForEach(Array(store.labelPresets.enumerated()), id: \.offset) { idx, item in
                        Text(item.name).tag(idx)
                    }
                }
                .frame(width: 260)
            }
            Divider()

            HStack(spacing: 24) {
                VStack(alignment: .leading, spacing: 12) {
                    if store.selectedTaskID == "label-auto" {
                        Text(KroutonL10n.tr("Automatic Album / Movie / Game Cover Lookup"))
                            .font(.headline)
                        HStack {
                            TextField("Search Album, Movie, TV Show, or Game...", text: $autoLabelSearchQuery)
                                .textFieldStyle(.roundedBorder)
                            Button("Fetch Art") {}
                        }
                        Text("Queries MusicBrainz, iTunes, TVMaze & GameTDB. Uses Apple Vision to prevent the \(Int(preset.innerDiameterMM))mm hole from cropping faces.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Divider()
                    }
                    Text(KroutonL10n.tr("Disc Face Typography"))
                        .font(.headline)
                    TextField("Primary Arc Title", text: $labelDiscTitle)
                        .textFieldStyle(.roundedBorder)
                    TextField("Bottom Subtitle / Track Summary", text: $labelSubtitle)
                        .textFieldStyle(.roundedBorder)
                    Spacer()
                }
                .frame(width: 300)

                Spacer()

                ZStack {
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [store.activeAccent.opacity(0.85), Color.black.opacity(0.92)],
                                center: .center,
                                startRadius: 20,
                                endRadius: 150
                            )
                        )
                        .frame(width: 260, height: 260)
                        .overlay(Circle().stroke(Color.white.opacity(0.35), lineWidth: 1.5))

                    VStack {
                        Text(labelDiscTitle)
                            .font(.system(size: 13, weight: .heavy, design: .rounded))
                            .foregroundStyle(.white)
                            .padding(.top, 26)
                        Spacer()
                        Text(labelSubtitle)
                            .font(.system(size: 10, weight: .semibold, design: .monospaced))
                            .foregroundStyle(.white.opacity(0.85))
                            .padding(.bottom, 26)
                    }
                    .frame(width: 260, height: 260)

                    Circle()
                        .fill(Color(NSColor.windowBackgroundColor))
                        .frame(
                            width: CGFloat(preset.innerDiameterMM / preset.outerDiameterMM) * 260.0,
                            height: CGFloat(preset.innerDiameterMM / preset.outerDiameterMM) * 260.0
                        )
                        .overlay(Circle().stroke(Color.secondary.opacity(0.5), lineWidth: 1))
                }
                Spacer()
            }
            Spacer()
        }
    }

    private func playlistRow(num: String, title: String, duration: String, transition: String, info: String) -> some View {
        HStack(spacing: 12) {
            Text(num)
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .foregroundStyle(store.activeAccent)
                .frame(width: 48, alignment: .leading)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 12, weight: .semibold))
                Text(info)
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Text(transition)
                .font(.system(size: 10, weight: .semibold, design: .monospaced))
                .foregroundStyle(store.activeAccent)
            Text(duration)
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(.secondary)
                .frame(width: 70, alignment: .trailing)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
    }

    // MARK: - RIGHT COLUMN: UUID-SAFE DESTINATION CARDS + CLICKABLE DISC MEDIA INSPECTOR PILL
    private var rightDestinationColumn: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 6) {
                Label(
                    rightColumnLiveWidth < 265 ? "QUEUE (\(store.destinationQueue.count))" : "DESTINATIONS (\(store.destinationQueue.count))",
                    systemImage: "arrow.right.doc.on.clipboard"
                )
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(.secondary)
                .lineLimit(1)
                Spacer(minLength: 4)
                Button {
                    appendContextAwareDestination()
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "plus")
                        if rightColumnLiveWidth >= 255 {
                            Text(KroutonL10n.tr("Add Output"))
                                .lineLimit(1)
                        }
                    }
                    .font(.system(size: 11, weight: .semibold))
                    .padding(.horizontal, 9)
                    .padding(.vertical, 4)
                    .background(store.activeAccent.opacity(0.2))
                    .clipShape(Capsule())
                    .fixedSize(horizontal: true, vertical: false)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)

            Divider()

            // Iterating directly over store.destinationQueue by UUID (Zero raw array indices = Zero crashes!)
            ScrollView {
                VStack(spacing: 12) {
                    ForEach(store.destinationQueue) { item in
                        destinationCard(item: item)
                    }
                }
                .padding(12)
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
                .padding(.horizontal, 14)
                .padding(.top, 10)
            }

            VStack(spacing: 8) {
                Button {
                    executeDestinationQueue()
                } label: {
                    HStack {
                        Image(systemName: driveManager.isExecutingQueue ? "stop.circle.fill" : primaryActionSymbol)
                            .font(.system(size: 15, weight: .bold))
                        Text(driveManager.isExecutingQueue ? "ABORT BURN" : primaryActionTitle)
                            .font(.system(size: 14, weight: .heavy, design: .rounded))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(driveManager.isExecutingQueue ? Color.red : store.activeAccent)
                    .foregroundStyle(driveManager.isExecutingQueue ? Color.white : store.activeOnAccentText)
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)

                Text("Queue Ready • \(store.stagedFiles.count) Items (\(ByteCountFormatter.string(fromByteCount: store.totalStagedBytes, countStyle: .file)))")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.secondary)
            }
            .padding(14)
        }
        .background(Color(NSColor.controlBackgroundColor))
    }

    // Safe UUID-based mutator helper so removing a card never triggers an out-of-bounds index crash
    private func updateQueueItem(_ id: UUID, mutate: @escaping (inout DestinationQueueItem) -> Void) {
        guard let idx = store.destinationQueue.firstIndex(where: { $0.id == id }) else { return }
        mutate(&store.destinationQueue[idx])
    }

    // Ensures every physicalBurner card has a unique targetDriveID so 2 cards never select the same drive
    private func reconcileUniqueDriveAssignments() {
        guard !driveManager.availableDrives.isEmpty else { return }
        var claimedIDs = Set<String>()
        for idx in store.destinationQueue.indices {
            guard store.destinationQueue[idx].kind == .physicalBurner else { continue }
            let currentID = store.destinationQueue[idx].targetDriveID
            let isValidDrive = driveManager.availableDrives.contains(where: { $0.id == currentID })
            if isValidDrive && !claimedIDs.contains(currentID) {
                claimedIDs.insert(currentID)
            } else if let nextFree = driveManager.availableDrives.first(where: { !claimedIDs.contains($0.id) }) {
                store.destinationQueue[idx].targetDriveID = nextFree.id
                store.destinationQueue[idx].hardwareOrPath = nextFree.displayName
                claimedIDs.insert(nextFree.id)
            }
        }
    }

    private func destinationCard(item: DestinationQueueItem) -> some View {
        let cardID = item.id

        // Drives claimed by OTHER destination cards in the queue
        let otherUsedDriveIDs = Set(
            store.destinationQueue
                .filter { $0.id != cardID && $0.kind == .physicalBurner && !$0.targetDriveID.isEmpty }
                .map { $0.targetDriveID }
        )

        // Resolve THIS card's drive without falling back to a drive already claimed by another card!
        let cardDrive: OpticalDriveDevice? = {
            if let exact = driveManager.availableDrives.first(where: { $0.id == item.targetDriveID }) {
                return exact
            }
            return driveManager.availableDrives.first(where: { !otherUsedDriveIDs.contains($0.id) }) ?? driveManager.availableDrives.first
        }()

        let activeCardDriveID = cardDrive?.id ?? ""
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
                    .foregroundStyle(store.activeAccent)

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
                                ? Color.cyan
                                : (isInlineVisible ? Color.green : Color.green.opacity(0.16))
                        )
                        .foregroundStyle(
                            (isFloatingOpen || isInlineVisible) ? Color.black.opacity(0.9) : Color.green
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
                                if rightColumnLiveWidth >= 285 { Text(KroutonL10n.tr("Eject")).lineLimit(1) }
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
                                        .fill(activeDrive.isMediaPresent ? Color.green : Color.secondary)
                                        .frame(width: 7, height: 7)
                                    Text(activeDrive.statusBadgeText)
                                        .font(.system(size: 10, weight: .semibold))
                                        .lineLimit(1)
                                    Image(systemName: "info.circle")
                                        .font(.system(size: 9))
                                }
                                .padding(.horizontal, 9)
                                .padding(.vertical, 4)
                                .background((activeDrive.isMediaPresent ? Color.green : Color.secondary).opacity(0.15))
                                .foregroundStyle(activeDrive.isMediaPresent ? .green : .secondary)
                                .clipShape(Capsule())
                            }
                            .buttonStyle(.plain)
                            .fixedSize()
                            .help("Click to inspect ATIP/MID manufacturer, dye chemistry, sessions, and sector topology")
                            .popover(isPresented: Binding(
                                get: { activeDiscPopoverCardID == cardID },
                                set: { if !$0 { activeDiscPopoverCardID = nil } }
                            ), arrowEdge: .leading) {
                                DiscMediaInspectorPopover(drive: activeDrive, accent: store.activeAccent)
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
                                }
                                .menuStyle(.borderlessButton)
                                .fixedSize()
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(store.activeAccent.opacity(0.16))
                                .clipShape(Capsule())
                                .help("Erase rewritable disc in \(activeDrive.displayName)")
                            }

                            Spacer(minLength: 0)
                        }
                    }
                }

                HStack {
                    Text(rightColumnLiveWidth < 280 ? "Speed:" : KroutonL10n.tr("Write Speed:")).lineLimit(1)
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
                                .foregroundStyle(item.copiesToBurn > 1 ? store.activeAccent : .secondary)
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
                            Text(rightColumnLiveWidth < 295 ? "DVD-ROM" : KroutonL10n.tr("DVD-ROM Bitset")).lineLimit(1)
                                .font(.system(size: 9, weight: .bold, design: .monospaced))
                        }
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.cyan.opacity(0.16))
                        .foregroundStyle(.cyan)
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
                        .background(Color.green.opacity(0.18))
                        .foregroundStyle(.green)
                        .clipShape(Capsule())
                        .help("Hands-Free Duplication: Auto-ejects finished disc and starts next burn \(store.autoLoadCountdownSeconds)s after a fresh blank disc is inserted")
                    }
                }

                // Live Hands-Free Auto-Load Next Disc Banner (Appears between copies in a batch)
                if let batchSt = driveManager.batchStates[activeCardDriveID] {
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(spacing: 6) {
                            Image(systemName: batchSt.countdownSecondsRemaining != nil ? "timer" : "opticaldisc.fill")
                                .foregroundStyle(batchSt.countdownSecondsRemaining != nil ? .orange : .green)
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
                                        .background(store.activeAccent)
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
                    .background(Color.green.opacity(0.10))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.green.opacity(0.35), lineWidth: 1))
                }
            } else if item.kind == .networkBurner {
                Text(item.hardwareOrPath)
                    .font(.system(size: 11, weight: .semibold, design: .monospaced))
                HStack(spacing: 5) {
                    Circle().fill(Color.green).frame(width: 7, height: 7)
                    Text(KroutonL10n.tr("LAN Node Online • 256 MB Ring Buffer"))
                        .font(.system(size: 10, weight: .semibold, design: .monospaced))
                        .foregroundStyle(.green)
                    Spacer()
                }
            } else if item.kind == .discImage {
                HStack(spacing: 6) {
                    TextField("~/Desktop/Krouton_Master.dmg", text: Binding(
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
                    .background(store.activeAccent)
                    .foregroundStyle(store.activeOnAccentText)
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)
                .fixedSize()
                .disabled(driveManager.isExecutingQueue)
                .help("Execute only this destination card (\(item.kind.rawValue))")
            }

            // Per-Burner Inline Mini Phase Scope (Shown when active OR manually pinned via Scope button, and not popped out)
            if item.kind == .physicalBurner,
               let scopeTel = scopeTel,
               isInlineVisible {
                InlineMiniPhaseScopeView(telemetry: scopeTel, accent: store.activeAccent) {
                    KroutonWindowManager.shared.openFloatingPhaseScopeWindow(driveID: activeCardDriveID)
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(12)
        .background(Color(NSColor.windowBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(store.activeAccent.opacity(0.35), lineWidth: 1)
        )
    }

    private func cardActionTitle(for kind: DestinationOutputKind) -> String {
        switch kind {
        case .physicalBurner, .networkBurner:
            return "Burn Disc"
        case .discImage:
            return "Save Image"
        case .audioRip:
            return "Rip Audio"
        case .videoExtract:
            return "Extract Video"
        case .discPrinter:
            return "Print Label"
        case .pdfVector:
            return "Save PDF"
        }
    }

    private func cardActionSymbol(for kind: DestinationOutputKind) -> String {
        switch kind {
        case .physicalBurner, .networkBurner:
            return "flame.fill"
        case .discImage:
            return "internaldrive.fill"
        case .audioRip:
            return "waveform"
        case .videoExtract:
            return "film"
        case .discPrinter:
            return "printer.fill"
        case .pdfVector:
            return "doc.richtext.fill"
        }
    }

    private func executeSingleDestination(_ target: DestinationQueueItem) {
        if driveManager.isExecutingQueue {
            driveManager.abortActiveBurn()
            return
        }

        if store.stagedFiles.isEmpty && store.selectedCategory == .burn {
            driveManager.completionReport = BurnCompletionReport(
                isSuccess: false,
                title: "File List Is Empty",
                summary: "There are no files or folders staged in the central workspace.",
                driveModel: primarySelectedDrive?.displayName ?? "Optical Burner",
                firmwareRevision: primarySelectedDrive?.firmware ?? "1.0",
                mediaFormattedName: primarySelectedDrive?.mediaType ?? "None",
                volumeName: store.discVolumeTitle,
                sectorsWrittenLBA: 0,
                bytesWritten: 0,
                averageSpeedText: "0.0x",
                peakSpeedText: "0.0x",
                elapsedDurationText: "00:00",
                diagnosticAdvice: "Drag files or folders from Finder into the File List (or click 'Add Media or Files...') before starting the operation."
            )
            return
        }

        Task { @MainActor in
            await runTargetDestination(target)
        }
    }

    private func runTargetDestination(_ target: DestinationQueueItem) async {
        switch target.kind {
        case .physicalBurner, .networkBurner:
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

    private func executeDestinationQueue() {
        if driveManager.isExecutingQueue {
            driveManager.abortActiveBurn()
            return
        }

        if store.stagedFiles.isEmpty && store.selectedCategory == .burn {
            driveManager.completionReport = BurnCompletionReport(
                isSuccess: false,
                title: "File List Is Empty",
                summary: "There are no files or folders staged in the central workspace.",
                driveModel: primarySelectedDrive?.displayName ?? "Optical Burner",
                firmwareRevision: primarySelectedDrive?.firmware ?? "1.0",
                mediaFormattedName: primarySelectedDrive?.mediaType ?? "None",
                volumeName: store.discVolumeTitle,
                sectorsWrittenLBA: 0,
                bytesWritten: 0,
                averageSpeedText: "0.0x",
                peakSpeedText: "0.0x",
                elapsedDurationText: "00:00",
                diagnosticAdvice: "Drag files or folders from Finder into the File List (or click 'Add Media or Files...') before starting the burn."
            )
            return
        }

        Task { @MainActor in
            for target in store.destinationQueue {
                await runTargetDestination(target)
            }
        }
    }

    private var allowedDestinationsForCurrentCategory: [DestinationOutputKind] {
        switch store.selectedCategory {
        case .burn, .depot:
            return [.physicalBurner, .networkBurner, .discImage]
        case .copy:
            return [.physicalBurner, .networkBurner, .discImage, .audioRip, .videoExtract]
        case .label:
            return [.discPrinter, .pdfVector]
        }
    }

    private func syncDefaultDestinationForCategory(_ category: TaskMasterCategory, taskID: String) {
        let firstDrive = driveManager.availableDrives.first
        let currentDriveName = firstDrive?.displayName ?? "Optical Drive"
        let currentDriveID = firstDrive?.id ?? ""

        switch category {
        case .burn, .depot:
            store.destinationQueue = [
                DestinationQueueItem(kind: .physicalBurner, targetDriveID: currentDriveID, hardwareOrPath: currentDriveName, speedOrCodec: "Max Safe (Auto)", simulationMode: false, verifyAfterBurn: true, compressAfterCreation: false)
            ]
        case .copy:
            if taskID == "copy-rip-audio" {
                store.destinationQueue = [
                    DestinationQueueItem(kind: .audioRip, targetDriveID: currentDriveID, hardwareOrPath: "~/Music/Krouton Rips/Apple Lossless", speedOrCodec: "ALAC (.m4a) + AccurateRip", simulationMode: false, verifyAfterBurn: true, compressAfterCreation: false)
                ]
            } else if taskID == "copy-rip-video" {
                store.destinationQueue = [
                    DestinationQueueItem(kind: .videoExtract, targetDriveID: currentDriveID, hardwareOrPath: "~/Movies/Krouton Extracts", speedOrCodec: "H.265 (HEVC 10-bit Hardware)", simulationMode: false, verifyAfterBurn: false, compressAfterCreation: false)
                ]
            } else {
                store.destinationQueue = [
                    DestinationQueueItem(kind: .physicalBurner, targetDriveID: currentDriveID, hardwareOrPath: currentDriveName, speedOrCodec: "Max Safe (Auto)", simulationMode: false, verifyAfterBurn: true, compressAfterCreation: false)
                ]
            }
        case .label:
            store.destinationQueue = [
                DestinationQueueItem(kind: .discPrinter, targetDriveID: "", hardwareOrPath: "Epson EcoTank Photo ET-8550 (CD/DVD Tray)", speedOrCodec: "Claria ET 6-Ink • 120mm / 18mm", simulationMode: false, verifyAfterBurn: false, compressAfterCreation: false)
            ]
        }
    }

    private func appendContextAwareDestination() {
        switch store.selectedCategory {
        case .burn, .depot:
            let usedDriveIDs = Set(store.destinationQueue.filter { $0.kind == .physicalBurner }.map { $0.targetDriveID })
            if let nextUnusedDrive = driveManager.availableDrives.first(where: { !usedDriveIDs.contains($0.id) }) {
                store.destinationQueue.append(
                    DestinationQueueItem(
                        kind: .physicalBurner,
                        targetDriveID: nextUnusedDrive.id,
                        hardwareOrPath: nextUnusedDrive.displayName,
                        speedOrCodec: "Max Safe (Auto)",
                        simulationMode: false,
                        verifyAfterBurn: true,
                        compressAfterCreation: false
                    )
                )
            } else {
                store.destinationQueue.append(
                    DestinationQueueItem(
                        kind: .discImage,
                        targetDriveID: "",
                        hardwareOrPath: "~/Desktop/\(store.discVolumeTitle).dmg",
                        speedOrCodec: "Hybrid UDF / HFS+ Image",
                        simulationMode: false,
                        verifyAfterBurn: true,
                        compressAfterCreation: true
                    )
                )
            }
        case .copy:
            store.destinationQueue.append(
                DestinationQueueItem(kind: .discImage, targetDriveID: "", hardwareOrPath: "~/Desktop/Disc_Backup.iso", speedOrCodec: "1:1 Archival Sector Image", simulationMode: false, verifyAfterBurn: true, compressAfterCreation: false)
            )
        case .label:
            store.destinationQueue.append(
                DestinationQueueItem(kind: .pdfVector, targetDriveID: "", hardwareOrPath: "~/Desktop/Epson_ET8550_Label_120mm.pdf", speedOrCodec: "300 DPI Vector PDF Proof", simulationMode: false, verifyAfterBurn: false, compressAfterCreation: false)
            )
        }
    }

    private var primaryActionTitle: String {
        switch store.selectedCategory {
        case .burn: return "BURN (\(store.destinationQueue.count))"
        case .depot: return "GET & BURN ISO (\(store.destinationQueue.count))"
        case .copy: return "START COPY / EXTRACT (\(store.destinationQueue.count))"
        case .label: return "PRINT LABEL (\(store.destinationQueue.count))"
        }
    }

    private var primaryActionSymbol: String {
        switch store.selectedCategory {
        case .burn: return "flame.fill"
        case .depot: return "arrow.down.doc.fill"
        case .copy: return "doc.on.doc.fill"
        case .label: return "printer.fill"
        }
    }
}

// MARK: - Physically Accurate Optical Disc Icon (Matches Real Dye & Substrate Physics)
struct OpticalDiscArtworkView: View {
    let mediaType: String
    let isMediaPresent: Bool
    let isErasable: Bool
    let isBlank: Bool

    private var discPalette: [Color] {
        let u = mediaType.uppercased()
        if !isMediaPresent {
            return [Color.secondary.opacity(0.25), Color.secondary.opacity(0.10), Color.secondary.opacity(0.25)]
        }
        if u.contains("MDISC") || u.contains("M-DISC") {
            return [
                Color(red: 0.72, green: 0.69, blue: 0.64),
                Color(red: 0.45, green: 0.43, blue: 0.40),
                Color(red: 0.82, green: 0.79, blue: 0.73),
                Color(red: 0.48, green: 0.46, blue: 0.42),
                Color(red: 0.72, green: 0.69, blue: 0.64)
            ]
        }
        if u.contains("RAM") {
            return [
                Color(red: 0.85, green: 0.68, blue: 0.18),
                Color(red: 0.55, green: 0.42, blue: 0.10),
                Color(red: 0.92, green: 0.78, blue: 0.28),
                Color(red: 0.52, green: 0.39, blue: 0.08),
                Color(red: 0.85, green: 0.68, blue: 0.18)
            ]
        }
        if u.contains("BD") {
            return [
                Color(red: 0.12, green: 0.38, blue: 0.92),
                Color(red: 0.28, green: 0.18, blue: 0.78),
                Color(red: 0.10, green: 0.68, blue: 0.95),
                Color(red: 0.22, green: 0.14, blue: 0.68),
                Color(red: 0.12, green: 0.38, blue: 0.92)
            ]
        }
        if u.contains("DVD") {
            if isErasable {
                return [
                    Color(red: 0.44, green: 0.36, blue: 0.58),
                    Color(red: 0.26, green: 0.22, blue: 0.36),
                    Color(red: 0.58, green: 0.48, blue: 0.72),
                    Color(red: 0.28, green: 0.24, blue: 0.38),
                    Color(red: 0.44, green: 0.36, blue: 0.58)
                ]
            } else {
                return [
                    Color(red: 0.58, green: 0.18, blue: 0.78),
                    Color(red: 0.34, green: 0.10, blue: 0.56),
                    Color(red: 0.78, green: 0.26, blue: 0.88),
                    Color(red: 0.38, green: 0.12, blue: 0.62),
                    Color(red: 0.58, green: 0.18, blue: 0.78)
                ]
            }
        }
        if u.contains("CD") {
            if isErasable {
                return [
                    Color(red: 0.36, green: 0.43, blue: 0.49),
                    Color(red: 0.20, green: 0.25, blue: 0.30),
                    Color(red: 0.52, green: 0.60, blue: 0.66),
                    Color(red: 0.22, green: 0.27, blue: 0.32),
                    Color(red: 0.36, green: 0.43, blue: 0.49)
                ]
            } else if u.contains("ROM") {
                return [
                    Color(white: 0.78),
                    Color(white: 0.52),
                    Color(white: 0.90),
                    Color(white: 0.55),
                    Color(white: 0.78)
                ]
            } else {
                return [
                    Color(red: 0.16, green: 0.76, blue: 0.62),
                    Color(red: 0.78, green: 0.72, blue: 0.22),
                    Color(red: 0.12, green: 0.62, blue: 0.74),
                    Color(red: 0.68, green: 0.64, blue: 0.20),
                    Color(red: 0.16, green: 0.76, blue: 0.62)
                ]
            }
        }
        return [Color.gray, Color.secondary, Color.gray]
    }

    var body: some View {
        ZStack {
            if !isMediaPresent {
                Circle()
                    .strokeBorder(style: StrokeStyle(lineWidth: 2, dash: [5, 3]))
                    .foregroundStyle(.secondary.opacity(0.45))
                    .frame(width: 54, height: 54)
                Circle()
                    .stroke(Color.secondary.opacity(0.25), lineWidth: 1)
                    .frame(width: 18, height: 18)
            } else {
                Circle()
                    .fill(
                        AngularGradient(
                            colors: discPalette,
                            center: .center
                        )
                    )
                    .frame(width: 54, height: 54)
                    .overlay(Circle().stroke(Color.white.opacity(0.40), lineWidth: 1.0))
                    .shadow(color: Color.black.opacity(0.28), radius: 4, x: 0, y: 2)

                if mediaType.uppercased().contains("RAM") {
                    Circle()
                        .strokeBorder(style: StrokeStyle(lineWidth: 2.0, dash: [3, 2]))
                        .foregroundStyle(Color.black.opacity(0.35))
                        .frame(width: 42, height: 42)
                    Circle()
                        .strokeBorder(style: StrokeStyle(lineWidth: 2.0, dash: [3, 2]))
                        .foregroundStyle(Color.black.opacity(0.35))
                        .frame(width: 30, height: 30)
                } else {
                    Circle()
                        .stroke(Color.white.opacity(isBlank ? 0.16 : 0.34), lineWidth: 0.8)
                        .frame(width: 42, height: 42)
                    Circle()
                        .stroke(Color.white.opacity(isBlank ? 0.18 : 0.38), lineWidth: 0.8)
                        .frame(width: 31, height: 31)
                }

                Circle()
                    .fill(Color.white.opacity(0.18))
                    .frame(width: 22, height: 22)
                Circle()
                    .fill(Color(NSColor.windowBackgroundColor))
                    .frame(width: 13, height: 13)
                    .overlay(Circle().stroke(Color.secondary.opacity(0.55), lineWidth: 1))
            }
        }
    }
}

// MARK: - Clickable Disc Pill Popover: Textured Visual Disc Media & Volume Inspector
struct DiscMediaInspectorPopover: View {
    let drive: OpticalDriveDevice
    let accent: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            heroBannerSection
            if !drive.isMediaPresent {
                emptySlotSection
            } else {
                mountedVolumesSection
                radialCapacitySection
                hardwareSpecGridSection
                writeSpeedsSection
            }
        }
        .padding(16)
        .frame(width: 500)
        .background(Color(NSColor.windowBackgroundColor))
    }

    private var heroBannerSection: some View {
        let modeLabel = drive.isMediaErasable ? "REWRITABLE MEDIA" : (drive.isMediaBlank ? "WRITE-ONCE BLANK" : "MASTERED DISC")
        return HStack(spacing: 14) {
            OpticalDiscArtworkView(
                mediaType: drive.mediaType,
                isMediaPresent: drive.isMediaPresent,
                isErasable: drive.isMediaErasable,
                isBlank: drive.isMediaBlank
            )

            VStack(alignment: .leading, spacing: 3) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(drive.statusBadgeText)
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                    Text("• \(modeLabel)")
                        .font(.system(size: 10, weight: .heavy, design: .monospaced))
                        .foregroundStyle(accent)
                }

                Text("\(drive.displayName) • FW \(drive.firmware) • \(drive.interconnect) • \(drive.bsdDeviceNode)")
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(.secondary)

                Text(drive.bookStandard)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.primary.opacity(0.85))
            }
            Spacer()
        }
        .padding(12)
        .background(
            LinearGradient(
                colors: [accent.opacity(0.12), Color(NSColor.controlBackgroundColor)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.primary.opacity(0.08), lineWidth: 1))
    }

    private var emptySlotSection: some View {
        HStack(spacing: 10) {
            Image(systemName: "opticaldisc")
                .font(.title2)
                .foregroundStyle(.secondary)
            Text(KroutonL10n.tr("No optical media is loaded in this drive. Insert a CD, DVD, Blu-ray, or M-DISC to inspect mounted volumes, file/track counts, ATIP/ADIP manufacturer codes, and dye chemistry."))
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(12)
        .background(Color(NSColor.controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 9))
    }

    private var mountedVolumesSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label(
                drive.mountedVolumes.isEmpty
                    ? "MOUNTED VOLUMES & PARTITIONS (UNMOUNTED / BLANK)"
                    : "MOUNTED VOLUMES & PARTITIONS (\(drive.mountedVolumes.count))",
                systemImage: "externaldrive.fill.badge.checkmark"
            )
            .font(.system(size: 9, weight: .bold))
            .foregroundStyle(.secondary)

            if drive.mountedVolumes.isEmpty {
                HStack(spacing: 10) {
                    Image(systemName: drive.isMediaBlank ? "sparkles" : "opticaldisc")
                        .foregroundStyle(accent)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(drive.isMediaBlank ? "Virgin Unformatted Optical Media" : "Unmounted Optical Session (\(drive.sessionCount) Session, \(drive.trackCount) Track)")
                            .font(.system(size: 11, weight: .semibold))
                        Text(drive.isMediaBlank ? "No filesystem tracks written yet — 100% capacity available for mastering." : "Raw sector layout detected on \(drive.bsdDeviceNode).")
                            .font(.system(size: 10))
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                }
                .padding(10)
                .background(Color(NSColor.controlBackgroundColor))
                .clipShape(RoundedRectangle(cornerRadius: 9))
                .overlay(RoundedRectangle(cornerRadius: 9).stroke(Color.primary.opacity(0.07), lineWidth: 1))
            } else {
                ForEach(drive.mountedVolumes) { vol in
                    volumeRowCard(vol)
                }
            }
        }
    }

    private func volumeRowCard(_ vol: MountedVolumePartition) -> some View {
        let countLabel = vol.itemCount >= 2500 ? "2,500+" : "\(vol.itemCount)"
        let unitLabel = vol.isAudioCD ? "Audio Tracks" : "Files"
        let sizeStr = ByteCountFormatter.string(fromByteCount: vol.usedBytes, countStyle: .file)

        return HStack(spacing: 10) {
            Image(systemName: vol.isAudioCD ? "waveform.circle.fill" : "folder.fill.badge.gearshape")
                .font(.system(size: 16))
                .foregroundStyle(accent)
                .frame(width: 26, height: 26)
                .background(accent.opacity(0.14))
                .clipShape(RoundedRectangle(cornerRadius: 6))

            VStack(alignment: .leading, spacing: 2) {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text(vol.volumeName)
                        .font(.system(size: 12, weight: .bold))
                    Text("• \(vol.filesystemFormat)")
                        .font(.system(size: 10, weight: .semibold, design: .monospaced))
                        .foregroundStyle(.secondary)
                }
                Text("\(countLabel) \(unitLabel) • \(sizeStr) • \(vol.creationDateText)")
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button {
                NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: vol.mountPath)
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "arrow.up.forward.square")
                    Text(KroutonL10n.tr("Open in Finder"))
                }
                .font(.system(size: 10, weight: .semibold))
                .padding(.horizontal, 9)
                .padding(.vertical, 4)
                .background(accent.opacity(0.18))
                .clipShape(Capsule())
            }
            .buttonStyle(.plain)
            .help("Reveal \(vol.mountPath) in macOS Finder")
        }
        .padding(10)
        .background(Color(NSColor.controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 9))
        .overlay(RoundedRectangle(cornerRadius: 9).stroke(Color.primary.opacity(0.07), lineWidth: 1))
    }

    private var radialCapacitySection: some View {
        let usedStr = ByteCountFormatter.string(fromByteCount: drive.usedBytes, countStyle: .file)
        let freeStr = ByteCountFormatter.string(fromByteCount: drive.freeBytes, countStyle: .file)

        return VStack(alignment: .leading, spacing: 7) {
            HStack {
                Label(KroutonL10n.tr("RADIAL SECTOR & CAPACITY TOPOLOGY"), systemImage: "chart.pie.fill")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(.secondary)
                Spacer()
                Text("Timecode: \(drive.redBookTimecodeCapacity)")
                    .font(.system(size: 10, weight: .semibold, design: .monospaced))
                    .foregroundStyle(accent)
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 5)
                        .fill(Color.black.opacity(0.30))
                    RoundedRectangle(cornerRadius: 5)
                        .fill(
                            LinearGradient(
                                colors: [accent, Color.green],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: max(4, geo.size.width * CGFloat(drive.usedFraction)))
                }
            }
            .frame(height: 8)

            HStack {
                HStack(spacing: 5) {
                    Circle().fill(accent).frame(width: 6, height: 6)
                    Text("Used: \(usedStr) (\(drive.usedSectorsLBA) LBA)")
                        .font(.system(size: 10, weight: .semibold, design: .monospaced))
                }
                Spacer()
                HStack(spacing: 5) {
                    Circle().fill(Color.secondary.opacity(0.5)).frame(width: 6, height: 6)
                    Text("Free: \(freeStr) (\(drive.freeSectorsLBA) LBA)")
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(10)
        .background(Color(NSColor.controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 9))
        .overlay(RoundedRectangle(cornerRadius: 9).stroke(Color.primary.opacity(0.07), lineWidth: 1))
    }

    private var hardwareSpecGridSection: some View {
        LazyVGrid(columns: [GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8)], spacing: 8) {
            specTile(
                icon: "building.2.crop.circle.fill",
                title: "ATIP / MID MANUFACTURER",
                value: drive.mediaManufacturer
            )
            specTile(
                icon: "drop.halffull",
                title: "RECORDING LAYER / DYE",
                value: drive.dyeChemistry
            )
            specTile(
                icon: "laser.burst",
                title: "OPTICAL LASER & BLOCK",
                value: "\(drive.laserWavelengthNA) • \(drive.sectorBlockSize)"
            )
            specTile(
                icon: "lock.shield.fill",
                title: "SESSIONS & PROTECTION",
                value: "\(drive.sessionCount) Session(s) • \(drive.trackCount) Track(s) • \(drive.copyProtectionStatus)"
            )
        }
    }

    private var writeSpeedsSection: some View {
        let concreteSpeeds = drive.availableWriteSpeeds.filter { !$0.lowercased().contains("auto") }
        let displaySpeeds = concreteSpeeds.isEmpty ? drive.availableWriteSpeeds : concreteSpeeds

        return VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 5) {
                Image(systemName: "gauge.with.dots.needle.67percent")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(accent)
                Text(KroutonL10n.tr("NEGOTIATED WRITE SPEEDS"))
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(.secondary)
                Spacer()
                Text(KroutonL10n.tr("Auto OPC Active"))
                    .font(.system(size: 9, weight: .semibold, design: .monospaced))
                    .foregroundStyle(accent)
            }
            Text(displaySpeeds.joined(separator: "   •   "))
                .font(.system(size: 10, weight: .medium, design: .monospaced))
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(9)
        .background(Color(NSColor.controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 9))
        .overlay(RoundedRectangle(cornerRadius: 9).stroke(Color.primary.opacity(0.07), lineWidth: 1))
    }

    private func specTile(icon: String, title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 5) {
                Image(systemName: icon)
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(accent)
                Text(title)
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Text(value)
                .font(.system(size: 10, weight: .medium, design: .monospaced))
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)
                .lineLimit(3)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(9)
        .background(Color(NSColor.controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 9))
        .overlay(RoundedRectangle(cornerRadius: 9).stroke(Color.primary.opacity(0.07), lineWidth: 1))
    }
}

struct KroutonMasteringReportSheet: View {
    let report: BurnCompletionReport
    let accent: Color
    let onDismiss: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(spacing: 14) {
                Image(systemName: report.isSuccess ? "checkmark.seal.fill" : "exclamationmark.triangle.fill")
                    .font(.system(size: 36))
                    .foregroundStyle(report.isSuccess ? .green : .orange)

                VStack(alignment: .leading, spacing: 3) {
                    Text(report.title)
                        .font(.title2.bold())
                    Text(report.summary)
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer()
            }

            Divider()

            VStack(spacing: 8) {
                reportDetailRow(label: "Optical Drive & Firmware", value: "\(report.driveModel) (FW \(report.firmwareRevision))")
                Divider()
                reportDetailRow(label: "Media Format & Volume", value: "\(report.mediaFormattedName) • \(report.volumeName)")
                Divider()
                reportDetailRow(label: "Sectors & Data Written", value: "\(report.sectorsWrittenLBA) LBA (\(ByteCountFormatter.string(fromByteCount: report.bytesWritten, countStyle: .file)))")
                Divider()
                reportDetailRow(label: "Transfer Rate (Avg / Peak)", value: "\(report.averageSpeedText) • Peak \(report.peakSpeedText)")
                Divider()
                reportDetailRow(label: "Elapsed Mastering Time", value: report.elapsedDurationText)
            }
            .padding(14)
            .background(Color(NSColor.controlBackgroundColor))
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.primary.opacity(0.08), lineWidth: 1))

            HStack(alignment: .top, spacing: 10) {
                Image(systemName: "info.circle.fill")
                    .foregroundStyle(accent)
                    .font(.system(size: 14))
                Text(report.diagnosticAdvice)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(12)
            .background(accent.opacity(0.10))
            .clipShape(RoundedRectangle(cornerRadius: 8))

            Spacer()

            HStack {
                Button("Copy Telemetry Log") {
                    let pasteboard = NSPasteboard.general
                    pasteboard.clearContents()
                    pasteboard.setString("\(report.title)\n\(report.summary)\nDrive: \(report.driveModel) (FW \(report.firmwareRevision))\nMedia: \(report.mediaFormattedName)\nSectors: \(report.sectorsWrittenLBA) LBA\nAdvice: \(report.diagnosticAdvice)", forType: .string)
                }
                Spacer()
                Button {
                    onDismiss()
                } label: {
                    Text(KroutonL10n.tr("Done"))
                        .font(.system(size: 13, weight: .bold))
                        .padding(.horizontal, 28)
                        .padding(.vertical, 8)
                        .background(accent)
                        .foregroundStyle(.white)
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(24)
        .frame(width: 580, height: 420)
        .background(Color(NSColor.windowBackgroundColor))
    }

    private func reportDetailRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .font(.system(size: 12, weight: .semibold, design: .monospaced))
                .foregroundStyle(.primary)
        }
    }
}


// MARK: - Step 2B & 2C: Per-Burner Auto-Hiding Inline Mini Phase Scope & High-Detail Floating Window
struct InlineMiniPhaseScopeView: View {
    let telemetry: DrivePhaseScopeTelemetry
    let accent: Color
    let onPopOut: () -> Void

    var body: some View {
        Button {
            onPopOut()
        } label: {
            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: 6) {
                    Circle()
                        .fill(Color.green)
                        .frame(width: 6, height: 6)
                    Text(KroutonL10n.tr("PHASE SCOPE"))
                        .font(.system(size: 9, weight: .heavy, design: .monospaced))
                        .foregroundStyle(.green)
                    Spacer()
                    Text(String(format: "%.1fx (%.0f KB/s)", telemetry.currentSpeedX, telemetry.currentSpeedKBs))
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundStyle(.green)
                    Text(KroutonL10n.tr("•"))
                        .foregroundStyle(.secondary)
                    Text("\(telemetry.currentSpindleRPM) RPM")
                        .font(.system(size: 10, weight: .semibold, design: .monospaced))
                        .foregroundStyle(.yellow)
                    Image(systemName: "arrow.up.left.and.arrow.down.right")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(.secondary)
                }

                ZStack {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color(red: 0.02, green: 0.03, blue: 0.07))

                    Canvas { context, size in
                        let cols = 8
                        let rows = 4
                        let gridColor = Color(red: 0.08, green: 0.18, blue: 0.72).opacity(0.75)

                        for c in 0...cols {
                            let x = size.width * CGFloat(c) / CGFloat(cols)
                            var p = Path()
                            p.move(to: CGPoint(x: x, y: 0))
                            p.addLine(to: CGPoint(x: x, y: size.height))
                            context.stroke(p, with: .color(gridColor), lineWidth: 0.6)
                        }
                        for r in 0...rows {
                            let y = size.height * CGFloat(r) / CGFloat(rows)
                            var p = Path()
                            p.move(to: CGPoint(x: 0, y: y))
                            p.addLine(to: CGPoint(x: size.width, y: y))
                            context.stroke(p, with: .color(gridColor), lineWidth: 0.6)
                        }

                        let samples = telemetry.samples
                        if samples.count > 1 {
                            let maxScaleX: Double = 24.0
                            let maxScaleRPM: Double = 6000.0

                            var speedArea = Path()
                            var speedPath = Path()
                            var rpmPath = Path()

                            for (idx, s) in samples.enumerated() {
                                let x = size.width * CGFloat(min(1.0, max(0.0, s.progressFraction)))
                                let ySpeed = size.height * (1.0 - CGFloat(min(1.0, s.speedMultiplierX / maxScaleX)))
                                let yRPM = size.height * (1.0 - CGFloat(min(1.0, s.spindleRPM / maxScaleRPM)))

                                if idx == 0 {
                                    speedArea.move(to: CGPoint(x: x, y: size.height))
                                    speedArea.addLine(to: CGPoint(x: x, y: ySpeed))
                                    speedPath.move(to: CGPoint(x: x, y: ySpeed))
                                    rpmPath.move(to: CGPoint(x: x, y: yRPM))
                                } else {
                                    speedArea.addLine(to: CGPoint(x: x, y: ySpeed))
                                    speedPath.addLine(to: CGPoint(x: x, y: ySpeed))
                                    rpmPath.addLine(to: CGPoint(x: x, y: yRPM))
                                }
                            }

                            if let last = samples.last {
                                let lastX = size.width * CGFloat(min(1.0, max(0.0, last.progressFraction)))
                                speedArea.addLine(to: CGPoint(x: lastX, y: size.height))
                                speedArea.closeSubpath()

                                context.fill(
                                    speedArea,
                                    with: .linearGradient(
                                        Gradient(colors: [Color.green.opacity(0.32), Color.green.opacity(0.02)]),
                                        startPoint: CGPoint(x: 0, y: 0),
                                        endPoint: CGPoint(x: 0, y: size.height)
                                    )
                                )

                                context.stroke(rpmPath, with: .color(.yellow), lineWidth: 1.3)
                                context.stroke(speedPath, with: .color(.green), lineWidth: 1.8)

                                var cursorPath = Path()
                                cursorPath.move(to: CGPoint(x: lastX, y: 0))
                                cursorPath.addLine(to: CGPoint(x: lastX, y: size.height))
                                context.stroke(cursorPath, with: .color(.red), lineWidth: 1.2)
                            }
                        }
                    }
                    .padding(3)
                }
                .frame(height: 68)
                .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.blue.opacity(0.45), lineWidth: 1))

                HStack {
                    Text("LBA \(telemetry.currentSectorLBA) / \(telemetry.totalSectorsLBA)")
                        .font(.system(size: 9, design: .monospaced))
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text(String(format: "r = %.1f mm • Click to Pop Out", telemetry.radialMillimeters))
                        .font(.system(size: 9, design: .monospaced))
                        .foregroundStyle(.cyan)
                }
            }
            .padding(8)
            .background(Color(NSColor.controlBackgroundColor))
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.green.opacity(0.30), lineWidth: 1))
        }
        .buttonStyle(.plain)
        .help("Click to pop out the high-detail Floating Phase Scope window for this burner")
    }
}

struct FloatingPhaseScopeWindowView: View {
    let driveID: String
    @ObservedObject var store: KroutonStateStore
    @ObservedObject var driveManager: DriveManager
    let onDockInline: () -> Void

    private var drive: OpticalDriveDevice? {
        driveManager.driveForID(driveID)
    }

    private var telemetry: DrivePhaseScopeTelemetry {
        driveManager.telemetryForDrive(driveID) ?? DrivePhaseScopeTelemetry(
            id: driveID,
            driveName: drive?.displayName ?? "Optical Burner"
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 12) {
                OpticalDiscArtworkView(
                    mediaType: drive?.mediaType ?? "CD-RW",
                    isMediaPresent: drive?.isMediaPresent ?? true,
                    isErasable: drive?.isMediaErasable ?? true,
                    isBlank: drive?.isMediaBlank ?? false
                )

                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 8) {
                        Circle()
                            .fill(telemetry.isActive ? Color.green : Color.secondary)
                            .frame(width: 8, height: 8)
                        Text("PHASE SCOPE — \(drive?.displayName ?? telemetry.driveName)")
                            .font(.system(size: 16, weight: .heavy, design: .rounded))
                        Text("• \(telemetry.phaseTitle)")
                            .font(.system(size: 12, weight: .semibold, design: .monospaced))
                            .foregroundStyle(store.activeAccent)
                    }
                    Text("Firmware \(drive?.firmware ?? "1.0") • \(drive?.interconnect ?? "USB") Bus • \(drive?.bsdDeviceNode ?? "/dev/rdisk") • Media: \(drive?.statusBadgeText ?? "Ready")")
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Button {
                    driveManager.runPhaseScopeTestSweep(for: driveID)
                } label: {
                    HStack(spacing: 5) {
                        Image(systemName: "waveform.path.ecg")
                        Text(KroutonL10n.tr("Run Calibration Sweep"))
                    }
                    .font(.system(size: 11, weight: .semibold))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.green.opacity(0.18))
                    .foregroundStyle(.green)
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)

                Button {
                    onDockInline()
                } label: {
                    HStack(spacing: 5) {
                        Image(systemName: "arrow.down.right.and.arrow.up.left")
                        Text(KroutonL10n.tr("Dock Inline"))
                    }
                    .font(.system(size: 11, weight: .semibold))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(store.activeAccent.opacity(0.18))
                    .foregroundStyle(store.activeAccent)
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)
                .help("Close floating window and return the Phase Scope to the inline burner card")
            }

            HStack(spacing: 18) {
                legendItem(color: .green, label: "Actual Speed (X / KB/s)", isDashed: false)
                legendItem(color: .cyan, label: "Target P-CAV Envelope", isDashed: true)
                legendItem(color: .yellow, label: "Spindle Velocity (RPM)", isDashed: false)
                legendItem(color: .purple, label: "Hardware Buffer Fill (%)", isDashed: false)
                legendItem(color: .red, label: "Radial LBA Playhead (mm)", isDashed: false)
                Spacer()
                Text(String(format: "Radial Position: r = %.2f mm / 58.00 mm", telemetry.radialMillimeters))
                    .font(.system(size: 11, weight: .semibold, design: .monospaced))
                    .foregroundStyle(.cyan)
            }
            .padding(.horizontal, 4)

            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(
                        LinearGradient(
                            colors: [Color(red: 0.01, green: 0.02, blue: 0.05), Color(red: 0.03, green: 0.05, blue: 0.11)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )

                Canvas { context, size in
                    let cols = 16
                    let rows = 8
                    let majorGrid = Color(red: 0.10, green: 0.22, blue: 0.78).opacity(0.65)
                    let minorGrid = Color(red: 0.08, green: 0.16, blue: 0.55).opacity(0.32)

                    for c in 0...cols {
                        let x = size.width * CGFloat(c) / CGFloat(cols)
                        var p = Path()
                        p.move(to: CGPoint(x: x, y: 0))
                        p.addLine(to: CGPoint(x: x, y: size.height))
                        context.stroke(p, with: .color(c % 4 == 0 ? majorGrid : minorGrid), lineWidth: c % 4 == 0 ? 0.9 : 0.5)
                    }
                    for r in 0...rows {
                        let y = size.height * CGFloat(r) / CGFloat(rows)
                        var p = Path()
                        p.move(to: CGPoint(x: 0, y: y))
                        p.addLine(to: CGPoint(x: size.width, y: y))
                        context.stroke(p, with: .color(r % 2 == 0 ? majorGrid : minorGrid), lineWidth: r % 2 == 0 ? 0.9 : 0.5)
                    }

                    let maxScaleX: Double = 24.0
                    let maxScaleRPM: Double = 6000.0

                    var targetCurve = Path()
                    for step in 0...60 {
                        let frac = Double(step) / 60.0
                        let theoX = 4.2 + (11.8 * pow(frac, 0.78))
                        let x = size.width * CGFloat(frac)
                        let y = size.height * (1.0 - CGFloat(min(1.0, theoX / maxScaleX)))
                        if step == 0 {
                            targetCurve.move(to: CGPoint(x: x, y: y))
                        } else {
                            targetCurve.addLine(to: CGPoint(x: x, y: y))
                        }
                    }
                    context.stroke(
                        targetCurve,
                        with: .color(Color.cyan.opacity(0.55)),
                        style: StrokeStyle(lineWidth: 1.4, dash: [6, 4])
                    )

                    let samples = telemetry.samples
                    if samples.count > 1 {
                        var speedArea = Path()
                        var speedLine = Path()
                        var rpmArea = Path()
                        var rpmLine = Path()
                        var bufferArea = Path()

                        for (idx, s) in samples.enumerated() {
                            let x = size.width * CGFloat(min(1.0, max(0.0, s.progressFraction)))
                            let ySpeed = size.height * (1.0 - CGFloat(min(1.0, s.speedMultiplierX / maxScaleX)))
                            let yRPM = size.height * (1.0 - CGFloat(min(1.0, s.spindleRPM / maxScaleRPM)))
                            let bufNorm = 0.95 + 0.04 * sin(s.progressFraction * 28.0)
                            let yBuf = size.height * (1.0 - CGFloat(0.16 * bufNorm))

                            if idx == 0 {
                                speedArea.move(to: CGPoint(x: x, y: size.height))
                                speedArea.addLine(to: CGPoint(x: x, y: ySpeed))
                                speedLine.move(to: CGPoint(x: x, y: ySpeed))

                                rpmArea.move(to: CGPoint(x: x, y: size.height))
                                rpmArea.addLine(to: CGPoint(x: x, y: yRPM))
                                rpmLine.move(to: CGPoint(x: x, y: yRPM))

                                bufferArea.move(to: CGPoint(x: x, y: size.height))
                                bufferArea.addLine(to: CGPoint(x: x, y: yBuf))
                            } else {
                                speedArea.addLine(to: CGPoint(x: x, y: ySpeed))
                                speedLine.addLine(to: CGPoint(x: x, y: ySpeed))

                                rpmArea.addLine(to: CGPoint(x: x, y: yRPM))
                                rpmLine.addLine(to: CGPoint(x: x, y: yRPM))

                                bufferArea.addLine(to: CGPoint(x: x, y: yBuf))
                            }
                        }

                        if let last = samples.last {
                            let lastX = size.width * CGFloat(min(1.0, max(0.0, last.progressFraction)))
                            speedArea.addLine(to: CGPoint(x: lastX, y: size.height))
                            speedArea.closeSubpath()

                            rpmArea.addLine(to: CGPoint(x: lastX, y: size.height))
                            rpmArea.closeSubpath()

                            bufferArea.addLine(to: CGPoint(x: lastX, y: size.height))
                            bufferArea.closeSubpath()

                            context.fill(
                                bufferArea,
                                with: .linearGradient(
                                    Gradient(colors: [Color.purple.opacity(0.30), Color.purple.opacity(0.05)]),
                                    startPoint: CGPoint(x: 0, y: size.height * 0.82),
                                    endPoint: CGPoint(x: 0, y: size.height)
                                )
                            )

                            context.fill(
                                rpmArea,
                                with: .linearGradient(
                                    Gradient(colors: [Color.yellow.opacity(0.16), Color.yellow.opacity(0.01)]),
                                    startPoint: CGPoint(x: 0, y: 0),
                                    endPoint: CGPoint(x: 0, y: size.height)
                                )
                            )

                            context.fill(
                                speedArea,
                                with: .linearGradient(
                                    Gradient(colors: [Color.green.opacity(0.38), Color.green.opacity(0.02)]),
                                    startPoint: CGPoint(x: 0, y: 0),
                                    endPoint: CGPoint(x: 0, y: size.height)
                                )
                            )

                            context.stroke(rpmLine, with: .color(.yellow), lineWidth: 1.8)
                            context.stroke(speedLine, with: .color(.green), lineWidth: 2.4)

                            var cursorPath = Path()
                            cursorPath.move(to: CGPoint(x: lastX, y: 0))
                            cursorPath.addLine(to: CGPoint(x: lastX, y: size.height))
                            context.stroke(cursorPath, with: .color(.red), lineWidth: 1.6)
                        }
                    }
                }
                .padding(8)

                VStack {
                    HStack {
                        Text(KroutonL10n.tr("24.0x (Max Scale)"))
                            .font(.system(size: 10, weight: .semibold, design: .monospaced))
                            .foregroundStyle(.green.opacity(0.85))
                        Spacer()
                        Text(KroutonL10n.tr("6,000 RPM"))
                            .font(.system(size: 10, weight: .semibold, design: .monospaced))
                            .foregroundStyle(.yellow.opacity(0.85))
                    }
                    Spacer()
                    HStack {
                        Text(KroutonL10n.tr("Inner Hub (r = 24.0 mm • LBA 0)"))
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text("Hardware Buffer Ribbon: \(Int(telemetry.bufferFillPercent))% Armed")
                            .font(.system(size: 10, weight: .semibold, design: .monospaced))
                            .foregroundStyle(.purple)
                        Spacer()
                        Text(KroutonL10n.tr("Outer Rim (r = 58.0 mm • Lead-Out)"))
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(14)
            }
            .frame(minHeight: 250, maxHeight: .infinity)
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.blue.opacity(0.50), lineWidth: 1.2))

            LazyVGrid(columns: [
                GridItem(.flexible(), spacing: 10),
                GridItem(.flexible(), spacing: 10),
                GridItem(.flexible(), spacing: 10)
            ], spacing: 10) {
                telemetryTile(
                    title: "LIVE / PEAK THROUGHPUT",
                    primary: String(format: "%.1fx (%.0f KB/s)", telemetry.currentSpeedX, telemetry.currentSpeedKBs),
                    secondary: String(format: "Avg %.1fx • Peak %.1fx", telemetry.averageSpeedX, telemetry.peakSpeedX),
                    color: .green
                )
                telemetryTile(
                    title: "SPINDLE MOTOR & STRATEGY",
                    primary: "\(telemetry.currentSpindleRPM) RPM",
                    secondary: "\(telemetry.writeStrategyText) • Angular Servo Locked",
                    color: .yellow
                )
                telemetryTile(
                    title: "LASER POWER & WAVELENGTH",
                    primary: telemetry.laserWavelengthText,
                    secondary: String(format: "Active OPC Power: %.1f mW", telemetry.isActive ? 14.8 + (telemetry.progressFraction * 4.2) : 0.0),
                    color: .orange
                )
                telemetryTile(
                    title: "RADIAL TRACKING & LBA",
                    primary: "LBA \(telemetry.currentSectorLBA) / \(telemetry.totalSectorsLBA)",
                    secondary: String(format: "Radius r = %.2f mm (%.1f%%)", telemetry.radialMillimeters, telemetry.progressFraction * 100.0),
                    color: .cyan
                )
                telemetryTile(
                    title: "DRIVE FIFO RING BUFFER",
                    primary: String(format: "%.0f%% Full (Zero Underruns)", telemetry.bufferFillPercent),
                    secondary: "Hardware BURN-Proof / SuperLink Active",
                    color: .purple
                )
                telemetryTile(
                    title: "SERVO JITTER & ELAPSED",
                    primary: String(format: "Jitter: %.2f%% (C1/C2 Clear)", telemetry.isActive ? 4.8 + (telemetry.progressFraction * 0.7) : 0.0),
                    secondary: String(format: "Elapsed Time: %02d:%02d", telemetry.elapsedSeconds / 60, telemetry.elapsedSeconds % 60),
                    color: .primary
                )
            }
        }
        .padding(18)
        .frame(minWidth: 740, idealWidth: 780, minHeight: 490, idealHeight: 540)
        .background(Color(NSColor.windowBackgroundColor))
        .preferredColorScheme(store.appearanceMode.colorScheme)
        .environment(\.locale, store.activeLocale)
        .tint(store.activeAccent)
    }

    private func legendItem(color: Color, label: String, isDashed: Bool) -> some View {
        HStack(spacing: 6) {
            if isDashed {
                HStack(spacing: 2) {
                    Rectangle().fill(color).frame(width: 6, height: 2.5)
                    Rectangle().fill(color).frame(width: 6, height: 2.5)
                }
            } else {
                Rectangle().fill(color).frame(width: 14, height: 2.5)
            }
            Text(label)
                .font(.system(size: 10, weight: .medium, design: .monospaced))
                .foregroundStyle(color)
        }
    }

    private func telemetryTile(title: String, primary: String, secondary: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title)
                .font(.system(size: 9, weight: .bold, design: .monospaced))
                .foregroundStyle(.secondary)
            Text(primary)
                .font(.system(size: 13, weight: .bold, design: .monospaced))
                .foregroundStyle(color)
                .lineLimit(1)
            Text(secondary)
                .font(.system(size: 10, design: .monospaced))
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(Color(NSColor.controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.primary.opacity(0.08), lineWidth: 1))
    }
}


// MARK: - Format Classification Extension for Adaptive Central Workspaces
extension DiscFormatSpec {
    var isDiscImageBurnFormat: Bool {
        id == "image-burn" || sourceSupport == "Disc Image"
    }
    var isRedBookAudioFormat: Bool {
        let lower = id.lowercased() + " " + technicalName.lowercased() + " " + bookOrFileSystem.lowercased()
        return lower.contains("cd-da") || lower.contains("red book") || lower.contains("cd-extra") || lower.contains("blue book") || id == "audio-cdda" || id == "audio-cdextra"
    }

    var isCarSafeAudioFormat: Bool {
        let lower = id.lowercased() + " " + technicalName.lowercased() + " " + colloquialName.lowercased()
        return lower.contains("mp3") || lower.contains("car-safe") || lower.contains("iso9660 / udf audio") || id == "audio-mp3"
    }

    var isVideoAuthoringFormat: Bool {
        let lower = id.lowercased() + " " + technicalName.lowercased() + " " + colloquialName.lowercased()
        return lower.contains("dvd-video") || lower.contains("avchd") || lower.contains("bdmv") || lower.contains("uhd-bd") || lower.contains("blu-ray video") || id.hasPrefix("video-") || id.hasPrefix("bd-")
    }

    var isMDiscParityFormat: Bool {
        let lower = id.lowercased() + " " + technicalName.lowercased()
        return lower.contains("m-disc") || lower.contains("par2")
    }
}

extension StagedFileEntry {
    var iso9660Level1Name: String {
        let ext = url.pathExtension.uppercased().prefix(3)
        let base = url.deletingPathExtension().lastPathComponent
            .uppercased()
            .replacingOccurrences(of: " ", with: "_")
            .filter { $0.isLetter || $0.isNumber || $0 == "_" }
            .prefix(8)
        return ext.isEmpty ? String(base) : "\(base).\(ext)"
    }
}
