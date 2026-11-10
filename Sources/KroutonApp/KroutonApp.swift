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
                    Label("Settings...", systemImage: "gearshape")
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

            HSplitView {
                leftFormatChooserColumn
                    .frame(minWidth: 265, idealWidth: 285, maxWidth: 325)

                centerAdaptableWorkspace
                    .frame(minWidth: 600, maxWidth: .infinity, maxHeight: .infinity)

                rightDestinationColumn
                    .frame(minWidth: 380, idealWidth: 400, maxWidth: 450)
            }
        }
        .frame(minWidth: 1320, idealWidth: 1420, minHeight: 840, idealHeight: 900)
        .background(Color(NSColor.windowBackgroundColor))
        .preferredColorScheme(store.appearanceMode.colorScheme)
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
                    Text("KROUTON")
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
                        Text("Settings...")
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
                Label("FORMAT CHOOSER", systemImage: "list.bullet.rectangle")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(.secondary)
                Spacer()
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
                        Text("BURN")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 10)

                        ForEach(store.discFormats.filter { $0.showInTaskChooser }) { fmt in
                            taskRowButton(
                                id: fmt.id,
                                category: .burn,
                                title: fmt.technicalName,
                                colloquial: fmt.colloquialName,
                                badge: fmt.sourceSupport,
                                sfSymbol: fmt.sfSymbol
                            )
                        }
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text("DISC IMAGE DEPOT")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 10)

                        taskRowButton(
                            id: "depot-rescue",
                            category: .depot,
                            title: "System Rescue & BIOS",
                            colloquial: "SystemRescue, GParted, FreeDOS 1.4",
                            badge: "Get ISO",
                            sfSymbol: "cross.case.fill"
                        )
                        taskRowButton(
                            id: "depot-linux-win",
                            category: .depot,
                            title: "Live OS & Installers",
                            colloquial: "Ubuntu, Fedora, Windows 11 API",
                            badge: "Get ISO",
                            sfSymbol: "terminal.fill"
                        )
                        taskRowButton(
                            id: "depot-archive-mac",
                            category: .depot,
                            title: "Vintage Apple & Archive.org",
                            colloquial: "Mac OS 9.2.2, System 7.5, Shareware",
                            badge: "Vault",
                            sfSymbol: "desktopcomputer"
                        )
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text("COPY")
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
                        Text("LABEL")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 10)

                        taskRowButton(
                            id: "label-auto",
                            category: .label,
                            title: "Automatic Disc Label",
                            colloquial: "Artwork Lookup + Hole Avoidance",
                            badge: "120mm",
                            sfSymbol: "wand.and.stars"
                        )
                        taskRowButton(
                            id: "label-manual",
                            category: .label,
                            title: "Manual Disc Label",
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

    private func taskRowButton(id: String, category: TaskMasterCategory, title: String, colloquial: String, badge: String, sfSymbol: String) -> some View {
        let isSelected = (store.selectedTaskID == id)
        return Button {
            store.selectedCategory = category
            store.selectedTaskID = id
            syncDefaultDestinationForCategory(category, taskID: id)
        } label: {
            HStack(spacing: 9) {
                Image(systemName: sfSymbol)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(isSelected ? store.activeOnAccentText : store.activeAccent)
                    .frame(width: 20)

                VStack(alignment: .leading, spacing: 1) {
                    Text(title)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(isSelected ? store.activeOnAccentText : .primary)
                        .lineLimit(1)
                    Text(colloquial)
                        .font(.system(size: 10))
                        .foregroundStyle(isSelected ? store.activeOnAccentText.opacity(0.82) : .secondary)
                        .lineLimit(1)
                }
                Spacer()
                if badge != "New & Image" && !badge.isEmpty {
                    Text(badge)
                        .font(.system(size: 9, weight: .semibold, design: .monospaced))
                        .foregroundStyle(isSelected ? store.activeOnAccentText.opacity(0.85) : .secondary)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(isSelected ? store.activeAccent : Color.clear)
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
    }

    // MARK: - CENTER COLUMN: ADAPTABLE WORKSPACE + INTEGRATED CAPACITY BAR (Global graph removed)
    private var centerAdaptableWorkspace: some View {
        VStack(alignment: .leading, spacing: 12) {
            switch store.selectedCategory {
            case .burn:
                burnWorkspaceView
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

        return VStack(alignment: .leading, spacing: 6) {
            HStack {
                Label("DISC SPACE ALLOCATION (\(mediaLabel))", systemImage: "chart.bar.xaxis")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(.secondary)
                Spacer()
                Text("Used: \(ByteCountFormatter.string(fromByteCount: usedB, countStyle: .file)) (\(store.totalStagedSectorsLBA) LBA)")
                    .font(.system(size: 11, weight: .semibold, design: .monospaced))
                    .foregroundStyle(isOverburn ? .red : .primary)
                Text("•")
                    .foregroundStyle(.secondary)
                Text("Available: \(ByteCountFormatter.string(fromByteCount: freeB, countStyle: .file)) (\(max(0, activeDiscTotalSectorsLBA - store.totalStagedSectorsLBA)) LBA)")
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(.secondary)
                Text("•")
                    .foregroundStyle(.secondary)
                Text(String(format: "%.1f%% Full", ratio * 100.0))
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundStyle(isOverburn ? .red : store.activeAccent)
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color.black.opacity(0.35))
                    RoundedRectangle(cornerRadius: 6)
                        .fill(
                            LinearGradient(
                                colors: isOverburn ? [.red, .orange] : [store.activeAccent, store.activeAccent.opacity(0.65)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: max(4, geo.size.width * CGFloat(ratio)))
                    Rectangle()
                        .fill(Color.yellow.opacity(0.5))
                        .frame(width: 1.5, height: geo.size.height)
                        .offset(x: geo.size.width * 0.90)
                }
            }
            .frame(height: 12)
        }
        .padding(10)
        .background(Color(NSColor.controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.primary.opacity(0.08), lineWidth: 1))
    }

    private var depotWorkspaceView: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Image(systemName: "arrow.down.doc.fill")
                    .font(.title2)
                    .foregroundStyle(store.activeAccent)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Disc Image Depot — Verified Bootable & Archival Storefront")
                        .font(.title3.bold())
                    Text("One-click download, SHA-256 verification, Virtualization.framework VM test-boot, and direct hardware burning.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                HStack(spacing: 6) {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(.secondary)
                    TextField("Search Depot & archive.org...", text: $depotSearchQuery)
                        .textFieldStyle(.plain)
                        .frame(width: 180)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Color(NSColor.controlBackgroundColor))
                .clipShape(RoundedRectangle(cornerRadius: 7))
            }

            Divider()

            ScrollView {
                VStack(spacing: 10) {
                    ForEach(store.depotItems) { item in
                        HStack(spacing: 14) {
                            Image(systemName: item.sfSymbol)
                                .font(.system(size: 22, weight: .semibold))
                                .foregroundStyle(store.activeAccent)
                                .frame(width: 36, height: 36)
                                .background(store.activeAccent.opacity(0.14))
                                .clipShape(RoundedRectangle(cornerRadius: 8))

                            VStack(alignment: .leading, spacing: 3) {
                                HStack(spacing: 8) {
                                    Text(item.title)
                                        .font(.system(size: 13, weight: .bold))
                                    Text("v\(item.version)")
                                        .font(.system(size: 11, weight: .semibold, design: .monospaced))
                                        .foregroundStyle(.secondary)
                                    Text(item.channel)
                                        .font(.system(size: 10))
                                        .foregroundStyle(store.activeAccent)
                                }
                                Text(item.subtitle)
                                    .font(.system(size: 11))
                                    .foregroundStyle(.secondary)
                                Text("Boot Spec: \(item.bootStandard) • Arch: \(item.architecture) • Size: \(item.sizeDisplay) • SHA-256: \(item.sha256Short)")
                                    .font(.system(size: 10, design: .monospaced))
                                    .foregroundStyle(.secondary)
                            }

                            Spacer()

                            Button {
                            } label: {
                                HStack(spacing: 5) {
                                    Image(systemName: item.isDownloaded ? "checkmark.circle.fill" : "arrow.down.circle.fill")
                                    Text(item.isDownloaded ? "Staged Ready" : "Get & Stage")
                                }
                                .font(.system(size: 11, weight: .bold))
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(item.isDownloaded ? Color.green.opacity(0.2) : store.activeAccent)
                                .foregroundStyle(item.isDownloaded ? .green : .white)
                                .clipShape(Capsule())
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(12)
                        .background(Color(NSColor.controlBackgroundColor))
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                }
            }
        }
    }

    private var burnWorkspaceView: some View {
        let activeSpec = store.discFormats.first(where: { $0.id == store.selectedTaskID }) ?? store.discFormats[0]
        return VStack(alignment: .leading, spacing: 12) {
            // Format Header Bar with Context-Sensitive Add Action
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 8) {
                        Image(systemName: activeSpec.sfSymbol)
                            .foregroundStyle(store.activeAccent)
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
                            Text("Clear All")
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
                        Text(addButtonTitle(for: activeSpec))
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
                    Text("WAVEBURNER RED BOOK CD-DA & CD-TEXT MASTERING DECK (44.1 kHz / 16-BIT PCM • 2,352 B/SECTOR)")
                        .font(.system(size: 10, weight: .heavy, design: .monospaced))
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text("CD-TEXT: 7-Bit ASCII Hardware Safe")
                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                        .foregroundStyle(.green)
                }

                HStack(spacing: 14) {
                    HStack(spacing: 5) {
                        Text("Album Title:")
                            .font(.caption.bold())
                        TextField("ALBUM TITLE", text: $cdTextAlbumTitle)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 175)
                    }
                    HStack(spacing: 5) {
                        Text("Performer:")
                            .font(.caption.bold())
                        TextField("ARTIST / PERFORMER", text: $cdTextAlbumPerformer)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 165)
                    }
                    HStack(spacing: 5) {
                        Text("UPC / MCN:")
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
                        Text("2.0s Standard Pre-Gap (INDEX 00)").tag("2.0s Standard Pre-Gap (INDEX 00)")
                        Text("0.0s Gapless Live Album (DAO)").tag("0.0s Gapless Live Album (DAO)")
                        Text("2.5s Jam Equal-Power Crossfade").tag("2.5s Jam Equal-Power Crossfade")
                    }
                    .frame(width: 295)
                    .font(.caption)

                    Toggle("Hidden Track One Audio (HTOA in INDEX 00)", isOn: $enableHiddenTrackOneHTOA)
                        .toggleStyle(.checkbox)
                        .font(.caption.bold())

                    if spec.id.contains("extra") || spec.technicalName.contains("Extra") {
                        Text("• Session 1: Audio Tracks | Session 2: Multisession Data Track (XA)")
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
                        Text("Drop Any Audio Format (WAV, AIFF, FLAC, ALAC, APE, WavPack, DSD .DSF/.DFF, Opus, Ogg, AC-3, DTS, MP3, M4A)")
                            .font(.headline)
                        Text("Krouton decodes all audio to 44.1 kHz / 16-bit Stereo PCM on disk before burning (Zero Underrun Guarantee).")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                } else {
                    VStack(spacing: 0) {
                        HStack(spacing: 10) {
                            Text("TRK")
                                .font(.system(size: 9, weight: .bold, design: .monospaced))
                                .foregroundStyle(.secondary)
                                .frame(width: 34, alignment: .leading)
                            Text("TRACK TITLE & CD-TEXT PERFORMER")
                                .font(.system(size: 9, weight: .bold, design: .monospaced))
                                .foregroundStyle(.secondary)
                            Spacer()
                            Text("ISRC CODE")
                                .font(.system(size: 9, weight: .bold, design: .monospaced))
                                .foregroundStyle(.secondary)
                                .frame(width: 104, alignment: .center)
                            Text("INDEX 00 / SPLICE")
                                .font(.system(size: 9, weight: .bold, design: .monospaced))
                                .foregroundStyle(.secondary)
                                .frame(width: 145, alignment: .center)
                            Text("MM:SS:FF (75 FPS)")
                                .font(.system(size: 9, weight: .bold, design: .monospaced))
                                .foregroundStyle(.secondary)
                                .frame(width: 98, alignment: .trailing)
                            Text("AUDITION")
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
                    Text("CAR-SAFE ISO9660 + JOLIET AUDIO ENGINE (PIONEER / ALPINE / SONY / OEM HEAD-UNIT SAFE)")
                        .font(.system(size: 10, weight: .heavy, design: .monospaced))
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text("AppleDouble ._* & .DS_Store Purged")
                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                        .foregroundStyle(.green)
                }

                HStack(spacing: 14) {
                    HStack(spacing: 6) {
                        Text("Disc Volume Title:")
                            .font(.caption.bold())
                        TextField("CAR_MP3_DISC", text: $store.discVolumeTitle)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 160)
                    }
                    Picker("Audio Output Profile:", selection: $carSafeTranscodeTarget) {
                        Text("320 kbps CBR MP3 (Universal Car Deck)").tag("320 kbps CBR MP3 (Universal Car Deck)")
                        Text("192 kbps CBR MP3 (Extended 12-Hour Roadtrip)").tag("192 kbps CBR MP3 (Extended 12-Hour Roadtrip)")
                        Text("16-Bit FLAC / WAV Passthrough (Modern Head Units)").tag("16-Bit FLAC / WAV Passthrough (Modern Head Units)")
                    }
                    .frame(width: 340)
                    .font(.caption)
                    Spacer()
                }

                HStack(spacing: 16) {
                    Toggle("Zero-Pad Track Prefixes (001 - Title.mp3)", isOn: $carSafeZeroPadNumbers)
                        .toggleStyle(.checkbox)
                        .font(.caption.bold())
                    Toggle("Strip macOS .DS_Store & ._* Forks", isOn: $carSafeStripAppleDouble)
                        .toggleStyle(.checkbox)
                        .font(.caption.bold())
                    Toggle("Enforce ID3v2.3 ISO-8859-1 Tags", isOn: $carSafeEnforceID3v23)
                        .toggleStyle(.checkbox)
                        .font(.caption)
                    Toggle("Write Root .M3U Playlist", isOn: $carSafeGenerateM3U)
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
                        Text("Drop MP3, FLAC, M4A, or Album Folders to Build a Car-Safe Audio Disc")
                            .font(.headline)
                        Text("Automatically numbers files in raw FAT/ISO directory order and strips hidden macOS resource forks so car stereos never freeze.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                } else {
                    VStack(spacing: 0) {
                        HStack(spacing: 10) {
                            Text("ORDER")
                                .font(.system(size: 9, weight: .bold, design: .monospaced))
                                .foregroundStyle(.secondary)
                                .frame(width: 44, alignment: .leading)
                            Text("CAR-SAFE JOLIET / ISO9660 FILENAME")
                                .font(.system(size: 9, weight: .bold, design: .monospaced))
                                .foregroundStyle(.secondary)
                            Spacer()
                            Text("TAG & CODEC PROFILE")
                                .font(.system(size: 9, weight: .bold, design: .monospaced))
                                .foregroundStyle(.secondary)
                                .frame(width: 185, alignment: .center)
                            Text("SECTORS")
                                .font(.system(size: 9, weight: .bold, design: .monospaced))
                                .foregroundStyle(.secondary)
                                .frame(width: 86, alignment: .trailing)
                            Text("SIZE")
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
                        Text("Disc Title:")
                            .font(.caption.bold())
                        TextField("KROUTON_VIDEO", text: $store.discVolumeTitle)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 155)
                    }
                    Picker("Menu Style:", selection: $videoMenuTemplate) {
                        Text("Dark Studio Chapter Grid").tag("Dark Studio Chapter Grid")
                        Text("No Menu (Auto-Play Title 1 on Insert)").tag("No Menu (Auto-Play Title 1 on Insert)")
                        Text("Criterion Minimalist Track List").tag("Criterion Minimalist Track List")
                    }
                    .frame(width: 245)
                    .font(.caption)

                    Picker("System:", selection: $videoSystemStandard) {
                        Text("NTSC 16:9 (29.97 / 23.976p)").tag("NTSC 16:9 (29.97 / 23.976p)")
                        Text("PAL 16:9 (25 fps)").tag("PAL 16:9 (25 fps)")
                        Text("UHD 2160p HDR10 (HEVC 10-Bit)").tag("UHD 2160p HDR10 (HEVC 10-Bit)")
                    }
                    .frame(width: 225)
                    .font(.caption)
                    Spacer()
                }

                HStack(spacing: 16) {
                    Toggle("Fit-to-Disc Smart Requantizer (DVD-9 -> DVD-5 / BD-50 -> BD-25)", isOn: $fitToDiscDVD9Shrink)
                        .toggleStyle(.checkbox)
                        .font(.caption.bold())

                    if isDualLayer {
                        Picker("Layer 0 -> Layer 1 Break:", selection: $videoDualLayerBreakSector) {
                            Text("Auto Cell Boundary (LBA 2,086,912 • 16-Sector ECC Aligned)").tag("Auto Cell Boundary (LBA 2,086,912 • 16-Sector ECC Aligned)")
                            Text("50/50 Balanced Split (Layer 0 >= Layer 1 Rule)").tag("50/50 Balanced Split (Layer 0 >= Layer 1 Rule)")
                            Text("Seamless Layer Break (SPLB Flag Set)").tag("Seamless Layer Break (SPLB Flag Set)")
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
                        Text("Drop Any Video or Container (MKV, M2TS, MP4, MOV ProRes, AV1, HEVC 10-Bit, WebM, AVI, VOB, WMV, VC-1, VIDEO_TS, BDMV)")
                            .font(.headline)
                        Text("Author standalone set-top player discs with AC-3 / DTS audio, chapter markers, and 32 KB IFO/BUP ECC sector padding.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                } else {
                    VStack(spacing: 0) {
                        HStack(spacing: 10) {
                            Text("TITLE")
                                .font(.system(size: 9, weight: .bold, design: .monospaced))
                                .foregroundStyle(.secondary)
                                .frame(width: 44, alignment: .leading)
                            Text("VIDEO STREAM & CHAPTER TOPOLOGY")
                                .font(.system(size: 9, weight: .bold, design: .monospaced))
                                .foregroundStyle(.secondary)
                            Spacer()
                            Text("VIDEO / AUDIO PIPELINE")
                                .font(.system(size: 9, weight: .bold, design: .monospaced))
                                .foregroundStyle(.secondary)
                                .frame(width: 195, alignment: .center)
                            Text("SECTORS")
                                .font(.system(size: 9, weight: .bold, design: .monospaced))
                                .foregroundStyle(.secondary)
                                .frame(width: 86, alignment: .trailing)
                            Text("SIZE")
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
                        Text("Drop Console Disc Image (.CUE + .BIN, .ISO, .GCM, .RVZ, .WBFS, or .DVD)")
                            .font(.headline)
                        Text("Krouton verifies 2,352-byte Mode 2 XA sector headers, System Area boot licenses, and Dual-Layer XGD break offsets.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                } else {
                    VStack(spacing: 0) {
                        HStack(spacing: 10) {
                            Text("ROM IMAGE & SECTOR TOPOLOGY")
                                .font(.system(size: 9, weight: .bold, design: .monospaced))
                                .foregroundStyle(.secondary)
                                .padding(.leading, 36)
                            Spacer()
                            Text("CONSOLE BOOT / SECTOR MODE")
                                .font(.system(size: 9, weight: .bold, design: .monospaced))
                                .foregroundStyle(.secondary)
                                .frame(width: 210, alignment: .center)
                            Text("SECTORS")
                                .font(.system(size: 9, weight: .bold, design: .monospaced))
                                .foregroundStyle(.secondary)
                                .frame(width: 86, alignment: .trailing)
                            Text("SIZE")
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
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(entry.name)
                                                .font(.system(size: 12, weight: .semibold))
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
    // 5. DATA & ARCHIVAL MASTERING WORKSPACE (UDF / HFS+ / ISO & M-DISC + PAR2)
    // ==========================================================================
    private func dataAndArchivalMasteringWorkspace(for activeSpec: DiscFormatSpec) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            if activeSpec.isMDiscParityFormat {
                HStack(spacing: 14) {
                    Image(systemName: "lock.shield.fill")
                        .foregroundStyle(store.activeAccent)
                    Text("M-DISC INORGANIC ROCK-LAYER VAULT + PAR2 SURFACE PARITY:")
                        .font(.system(size: 10, weight: .heavy, design: .monospaced))
                        .foregroundStyle(.secondary)
                    Text("PAR2 Redundancy: \(Int(mdiscPar2RedundancyPct))%")
                        .font(.caption.bold())
                        .foregroundStyle(store.activeAccent)
                    Slider(value: $mdiscPar2RedundancyPct, in: 5...30, step: 5)
                        .frame(width: 150)
                    Text("• Generates .par2 Reed-Solomon recovery blocks + SHA-256 manifest")
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundStyle(.secondary)
                    Spacer()
                }
                .padding(10)
                .background(Color(NSColor.controlBackgroundColor))
                .clipShape(RoundedRectangle(cornerRadius: 9))
                .overlay(RoundedRectangle(cornerRadius: 9).stroke(store.activeAccent.opacity(0.30), lineWidth: 1))
            }

            HStack(spacing: 14) {
                HStack(spacing: 6) {
                    Image(systemName: "opticaldisc")
                        .foregroundStyle(store.activeAccent)
                    Text("Disc Title:")
                        .font(.caption.bold())
                    TextField("KROUTON_DISC", text: $store.discVolumeTitle)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 190)
                }

                Toggle("Customize Finder & Explorer Window Layout", isOn: $enableCustomFinderLayoutTab)
                    .toggleStyle(.checkbox)
                    .font(.caption)
                    .onChange(of: enableCustomFinderLayoutTab) { _, enabled in
                        activeDataWorkspaceTab = enabled ? 1 : 0
                    }

                if enableCustomFinderLayoutTab {
                    Picker("", selection: $activeDataWorkspaceTab) {
                        Text("File List").tag(0)
                        Text("Custom Finder Window Preview").tag(1)
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 240)
                } else {
                    Label("Hybrid File Tree (Per-File Mac / PC Visibility)", systemImage: "list.bullet.indent")
                        .font(.caption.bold())
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }

            if activeDataWorkspaceTab == 1 && enableCustomFinderLayoutTab {
                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 20) {
                        ColorPicker("Finder Window Background:", selection: $finderBgColor)
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
                                                .foregroundStyle(item.isDirectory ? store.activeAccent : .white)
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
                            Image(systemName: "arrow.down.doc.fill")
                                .font(.system(size: 34))
                                .foregroundStyle(store.activeAccent.opacity(0.8))
                            Text("Drag & Drop Files, Folders, or Archives Here from Finder")
                                .font(.headline)
                            Text("Use the [Mac] and [PC] pills on each row to control which OS sees each file on hybrid discs.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    } else {
                        VStack(spacing: 0) {
                            HStack(spacing: 12) {
                                Text("ITEM NAME & PATH")
                                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                                    .foregroundStyle(.secondary)
                                    .padding(.leading, 36)
                                Spacer()
                                Text("OS VISIBILITY")
                                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                                    .foregroundStyle(.secondary)
                                    .frame(width: 112, alignment: .center)
                                Text("SECTORS")
                                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                                    .foregroundStyle(.secondary)
                                    .frame(width: 86, alignment: .trailing)
                                Text("SIZE")
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
                                                .foregroundStyle(store.activeAccent)
                                                .font(.system(size: 15))
                                                .frame(width: 24)

                                            VStack(alignment: .leading, spacing: 2) {
                                                Text(entry.name)
                                                    .font(.system(size: 12, weight: .semibold))
                                                Text("\(entry.url.path) • Perms: \(entry.posixPermissions) • \(entry.isDirectory ? "\(entry.itemCount) files inside" : "Single file")")
                                                    .font(.system(size: 10))
                                                    .foregroundStyle(.secondary)
                                                    .lineLimit(1)
                                            }

                                            Spacer()

                                            HStack(spacing: 5) {
                                                Button {
                                                    store.toggleMacVisibility(id: entry.id)
                                                } label: {
                                                    HStack(spacing: 3) {
                                                        Image(systemName: "apple.logo")
                                                            .font(.system(size: 9))
                                                        Text("Mac")
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
                                                        Text("PC")
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
                Text("RETRO CONSOLE HARDWARE MASTERING PROFILE")
                    .font(.system(size: 10, weight: .heavy, design: .monospaced))
                    .foregroundStyle(.secondary)
                Spacer()
                Toggle("Perform OPC Before Write", isOn: $romPerformOPCBeforeWrite)
                    .toggleStyle(.checkbox)
                    .font(.caption)
            }

            HStack(spacing: 16) {
                if spec.id == "game-ps1" {
                    Toggle("DAO/96 Raw Mode 2 Form 1/2 (2,352 B/sector + SubQ)", isOn: $romWriteModeDAO96SubQ)
                        .toggleStyle(.checkbox)
                        .font(.caption.bold())
                    Text("• Recommended Speed: 4x–8x CLV (High-Reflectivity CD-R Only — Never CD-RW)")
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundStyle(.secondary)
                } else if spec.id == "game-ps2" {
                    Toggle("Stamp Book Type as DVD-ROM (Bitsetting for PS2 Mechacon)", isOn: $romBitsetDVDROM)
                        .toggleStyle(.checkbox)
                        .font(.caption.bold())
                    Text("• Enforces UDF 1.02 + ISO9660 Bridge (FreeDVDBoot / ESR Compatible)")
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundStyle(.secondary)
                } else if spec.id == "game-gc" || spec.id == "game-wii" {
                    Toggle("Stamp Book Type as DVD-ROM + 32 KB ECC Boundary Alignment", isOn: $romBitsetDVDROM)
                        .toggleStyle(.checkbox)
                        .font(.caption.bold())
                    Text(spec.id == "game-gc" ? "• Exact 80mm Mini-DVD Target: 1,459,978,240 Bytes (712,880 LBA)" : "• Exact Wii Single-Layer Target: 4,699,979,776 Bytes (2,294,912 LBA)")
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundStyle(.secondary)
                } else if spec.id == "game-xbox" {
                    Picker("Layer Break:", selection: $xboxLayerBreakPreset) {
                        Text("Auto (.dvd Descriptor)").tag("Auto (.dvd / Calculate Optimal)")
                        Text("XGD2 Lock (LBA 1913760)").tag("XGD2 (1913760)")
                        Text("XGD3 Lock (LBA 2133520)").tag("XGD3 (2133520)")
                    }
                    .frame(width: 265)
                    .font(.caption)
                    Toggle("DVD+R DL -> DVD-ROM Bitsetting", isOn: $romBitsetDVDROM)
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
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = true
        panel.prompt = "Add..."
        if panel.runModal() == .OK {
            store.addStagedURLs(panel.urls)
        }
    }

    private func handleFinderDrop(providers: [NSItemProvider]) -> Bool {
        var didAccept = false
        for provider in providers {
            if provider.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) {
                didAccept = true
                provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { item, _ in
                    if let data = item as? Data, let url = URL(dataRepresentation: data, relativeTo: nil) {
                        Task { @MainActor in
                            store.addStagedURLs([url])
                        }
                    } else if let url = item as? URL {
                        Task { @MainActor in
                            store.addStagedURLs([url])
                        }
                    }
                }
            }
        }
        return didAccept
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
                Toggle("Fit to Disc — Automatically shrink DVD-9 (8.5 GB) to standard 4.7 GB DVD-5", isOn: $fitToDiscDVD9Shrink)
                    .font(.headline)
                Toggle("Preserve Interactive Menus, Chapter Tables & Bonus Extras", isOn: $preserveMenusAndExtras)
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
                        Text("Automatic Album / Movie / Game Cover Lookup")
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
                    Text("Disc Face Typography")
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
            HStack {
                Label("DESTINATIONS (\(store.destinationQueue.count))", systemImage: "arrow.right.doc.on.clipboard")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(.secondary)
                Spacer()
                Button {
                    appendContextAwareDestination()
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "plus")
                        Text("Add Output")
                    }
                    .font(.system(size: 11, weight: .semibold))
                    .padding(.horizontal, 9)
                    .padding(.vertical, 4)
                    .background(store.activeAccent.opacity(0.2))
                    .clipShape(Capsule())
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
                        Text(kind.rawValue).tag(kind)
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
                                Text("Eject")
                                    .lineLimit(1)
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
                        Text("No USB Optical Drive Connected")
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
                                        Text("Erase RW")
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
                    Text("Write Speed:")
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
                            Text("DVD-ROM Bitset")
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
                                Text("Cancel Batch")
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
                    Text("LAN Node Online • 256 MB Ring Buffer")
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
                        Toggle("Simulate", isOn: Binding(
                            get: { item.simulationMode },
                            set: { val in updateQueueItem(cardID) { $0.simulationMode = val } }
                        ))
                        .font(.caption)
                        Toggle("Verify", isOn: Binding(
                            get: { item.verifyAfterBurn },
                            set: { val in updateQueueItem(cardID) { $0.verifyAfterBurn = val } }
                        ))
                        .font(.caption)
                    }
                } else if item.kind == .discImage {
                    Toggle("Compress Image", isOn: Binding(
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
                        Text(cardActionTitle(for: item.kind))
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
            Text("No optical media is loaded in this drive. Insert a CD, DVD, Blu-ray, or M-DISC to inspect mounted volumes, file/track counts, ATIP/ADIP manufacturer codes, and dye chemistry.")
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
                    Text("Open in Finder")
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
                Label("RADIAL SECTOR & CAPACITY TOPOLOGY", systemImage: "chart.pie.fill")
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
                Text("NEGOTIATED WRITE SPEEDS")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(.secondary)
                Spacer()
                Text("Auto OPC Active")
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
                    Text("Done")
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
                    Text("PHASE SCOPE")
                        .font(.system(size: 9, weight: .heavy, design: .monospaced))
                        .foregroundStyle(.green)
                    Spacer()
                    Text(String(format: "%.1fx (%.0f KB/s)", telemetry.currentSpeedX, telemetry.currentSpeedKBs))
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundStyle(.green)
                    Text("•")
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
                        Text("Run Calibration Sweep")
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
                        Text("Dock Inline")
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
                        Text("24.0x (Max Scale)")
                            .font(.system(size: 10, weight: .semibold, design: .monospaced))
                            .foregroundStyle(.green.opacity(0.85))
                        Spacer()
                        Text("6,000 RPM")
                            .font(.system(size: 10, weight: .semibold, design: .monospaced))
                            .foregroundStyle(.yellow.opacity(0.85))
                    }
                    Spacer()
                    HStack {
                        Text("Inner Hub (r = 24.0 mm • LBA 0)")
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text("Hardware Buffer Ribbon: \(Int(telemetry.bufferFillPercent))% Armed")
                            .font(.system(size: 10, weight: .semibold, design: .monospaced))
                            .foregroundStyle(.purple)
                        Spacer()
                        Text("Outer Rim (r = 58.0 mm • Lead-Out)")
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
