import SwiftUI
import AppKit
import UniformTypeIdentifiers
import OpticalDough

@MainActor
final class KroutonWindowManager {
    static let shared = KroutonWindowManager()
    private var settingsWindow: NSWindow?

    func openSettingsWindow(store: KroutonStateStore, driveManager: DriveManager) {
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

final class KroutonAppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            NSApp.activate(ignoringOtherApps: true)
            for window in NSApp.windows {
                window.makeKeyAndOrderFront(nil)
            }
        }
    }
}

@main
struct KroutonApp: App {
    @NSApplicationDelegateAdaptor(KroutonAppDelegate.self) var appDelegate
    @StateObject private var store = KroutonStateStore()
    @StateObject private var driveManager = DriveManager()

    var body: some Scene {
        WindowGroup("Krouton") {
            KroutonMainWorkspaceView(store: store, driveManager: driveManager)
                .preferredColorScheme(store.appearanceMode.colorScheme)
                .tint(store.activeAccent)
        }
        .windowResizability(.contentMinSize)
        .commands {
            CommandGroup(replacing: .appSettings) {
                Button("Settings...") {
                    KroutonWindowManager.shared.openSettingsWindow(store: store, driveManager: driveManager)
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
    @State private var showNeroTelemetryDeck: Bool = true
    @State private var finderBgColor: Color = Color(red: 0.13, green: 0.17, blue: 0.24)
    @State private var finderIconSize: Double = 256
    @State private var fitToDiscDVD9Shrink: Bool = true
    @State private var preserveMenusAndExtras: Bool = true
    @State private var labelDiscTitle: String = "THE KROUTON ARCHIVE"
    @State private var labelSubtitle: String = "2026 MASTER EDITION"
    @State private var autoLabelSearchQuery: String = "Dark Side of the Moon"
    @State private var depotSearchQuery: String = ""
    @State private var isDropTargeted: Bool = false

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
                    .frame(minWidth: 350, idealWidth: 380, maxWidth: 430)
            }
        }
        .frame(minWidth: 1320, idealWidth: 1420, minHeight: 840, idealHeight: 900)
        .background(Color(NSColor.windowBackgroundColor))
        // Spacious, Properly Formatted Diagnostic & Mastering Summary Sheet
        .sheet(item: $driveManager.completionReport) { report in
            KroutonMasteringReportSheet(report: report, accent: store.activeAccent) {
                driveManager.completionReport = nil
            }
        }
    }

    // MARK: - Top Pro Toolbar (Clean Header + Nero Telemetry Toggle + Settings)
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
                    withAnimation(.easeInOut(duration: 0.2)) {
                        showNeroTelemetryDeck.toggle()
                    }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "waveform.path.ecg.rectangle.fill")
                        Text(showNeroTelemetryDeck ? "Hide Nero Speed Deck" : "Show Nero Speed Deck")
                    }
                    .font(.system(size: 11, weight: .semibold))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(showNeroTelemetryDeck ? store.activeAccent.opacity(0.22) : Color(NSColor.controlBackgroundColor))
                    .clipShape(Capsule())
                    .overlay(Capsule().stroke(showNeroTelemetryDeck ? store.activeAccent : Color.secondary.opacity(0.3), lineWidth: 1))
                }
                .buttonStyle(.plain)

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

    // MARK: - LEFT COLUMN: FORMAT CHOOSER
    private var leftFormatChooserColumn: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Label("FORMAT CHOOSER", systemImage: "list.bullet.rectangle")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(.secondary)
                Spacer()
                Button {
                    KroutonWindowManager.shared.openSettingsWindow(store: store, driveManager: driveManager)
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
                    .foregroundStyle(isSelected ? .white : store.activeAccent)
                    .frame(width: 20)

                VStack(alignment: .leading, spacing: 1) {
                    Text(title)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(isSelected ? .white : .primary)
                        .lineLimit(1)
                    Text(colloquial)
                        .font(.system(size: 10))
                        .foregroundStyle(isSelected ? .white.opacity(0.85) : .secondary)
                        .lineLimit(1)
                }
                Spacer()
                Text(badge)
                    .font(.system(size: 9, weight: .medium, design: .monospaced))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(isSelected ? Color.white.opacity(0.2) : Color.secondary.opacity(0.15))
                    .foregroundStyle(isSelected ? .white : .secondary)
                    .clipShape(Capsule())
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(isSelected ? store.activeAccent : Color.clear)
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
    }

    // MARK: - CENTER COLUMN: ADAPTABLE WORKSPACE + INTEGRATED CAPACITY BAR + NERO TELEMETRY DECK
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

            // Classic Nero CD-DVD Speed Oscilloscope & Nerd Telemetry Deck
            if showNeroTelemetryDeck || driveManager.isExecutingQueue {
                neroSpeedGraphAndNerdTelemetryDeck
            }
        }
        .padding(16)
    }

    // Integrated Space Available / Used Graph inside Central Workspace
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
                    // Used Space Fill
                    RoundedRectangle(cornerRadius: 6)
                        .fill(
                            LinearGradient(
                                colors: isOverburn ? [.red, .orange] : [store.activeAccent, store.activeAccent.opacity(0.65)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: max(4, geo.size.width * CGFloat(ratio)))
                    // 90% Lead-Out Warning Tick Mark
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

    // Classic Nero CD-DVD Speed Oscilloscope Graph + Nerd Stats Deck
    private var neroSpeedGraphAndNerdTelemetryDeck: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                HStack(spacing: 6) {
                    Circle()
                        .fill(driveManager.isExecutingQueue ? Color.green : Color.secondary)
                        .frame(width: 8, height: 8)
                    Text("NERO CD-DVD SPEED OSCILLOSCOPE & HARDWARE TELEMETRY")
                        .font(.system(size: 10, weight: .heavy, design: .monospaced))
                        .foregroundStyle(.secondary)
                }
                Spacer()
                HStack(spacing: 14) {
                    HStack(spacing: 4) {
                        Rectangle().fill(Color.green).frame(width: 12, height: 2.5)
                        Text("Write Speed (X / KB/s)")
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundStyle(.green)
                    }
                    HStack(spacing: 4) {
                        Rectangle().fill(Color.yellow).frame(width: 12, height: 2.5)
                        Text("Spindle Velocity (RPM)")
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundStyle(.yellow)
                    }
                    HStack(spacing: 4) {
                        Rectangle().fill(Color.red).frame(width: 10, height: 2.5)
                        Text("LBA Cursor")
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundStyle(.red)
                    }
                }
            }

            HStack(spacing: 12) {
                // Left: Classic Nero Black + Royal Blue Grid Canvas with Green Speed Curve & Yellow RPM Curve
                ZStack {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color(red: 0.02, green: 0.03, blue: 0.07))

                    Canvas { context, size in
                        let cols = 10
                        let rows = 6
                        let gridColor = Color(red: 0.08, green: 0.16, blue: 0.68).opacity(0.85)

                        for c in 0...cols {
                            let x = size.width * CGFloat(c) / CGFloat(cols)
                            var p = Path()
                            p.move(to: CGPoint(x: x, y: 0))
                            p.addLine(to: CGPoint(x: x, y: size.height))
                            context.stroke(p, with: .color(gridColor), lineWidth: 0.75)
                        }
                        for r in 0...rows {
                            let y = size.height * CGFloat(r) / CGFloat(rows)
                            var p = Path()
                            p.move(to: CGPoint(x: 0, y: y))
                            p.addLine(to: CGPoint(x: size.width, y: y))
                            context.stroke(p, with: .color(gridColor), lineWidth: 0.75)
                        }

                        let samples = driveManager.neroSamples
                        if samples.count > 1 {
                            let maxScaleX: Double = 24.0
                            let maxScaleRPM: Double = 6000.0

                            var speedPath = Path()
                            var rpmPath = Path()

                            for (idx, s) in samples.enumerated() {
                                let x = size.width * CGFloat(min(1.0, max(0.0, s.progressFraction)))
                                let ySpeed = size.height * (1.0 - CGFloat(min(1.0, s.speedMultiplierX / maxScaleX)))
                                let yRPM = size.height * (1.0 - CGFloat(min(1.0, s.spindleRPM / maxScaleRPM)))

                                if idx == 0 {
                                    speedPath.move(to: CGPoint(x: x, y: ySpeed))
                                    rpmPath.move(to: CGPoint(x: x, y: yRPM))
                                } else {
                                    speedPath.addLine(to: CGPoint(x: x, y: ySpeed))
                                    rpmPath.addLine(to: CGPoint(x: x, y: yRPM))
                                }
                            }

                            context.stroke(rpmPath, with: .color(.yellow), lineWidth: 1.6)
                            context.stroke(speedPath, with: .color(.green), lineWidth: 2.0)

                            // Red vertical LBA cursor line at current progress
                            if let last = samples.last {
                                let cursorX = size.width * CGFloat(min(1.0, max(0.0, last.progressFraction)))
                                var cursorPath = Path()
                                cursorPath.move(to: CGPoint(x: cursorX, y: 0))
                                cursorPath.addLine(to: CGPoint(x: cursorX, y: size.height))
                                context.stroke(cursorPath, with: .color(.red), lineWidth: 1.5)
                            }
                        } else {
                            // Subtle standby P-CAV reference curve when idle
                            var refSpeed = Path()
                            var refRPM = Path()
                            for i in 0...40 {
                                let frac = CGFloat(i) / 40.0
                                let x = size.width * frac
                                let yS = size.height * (0.78 - 0.45 * frac)
                                let yR = size.height * (0.48 + 0.08 * frac)
                                if i == 0 {
                                    refSpeed.move(to: CGPoint(x: x, y: yS))
                                    refRPM.move(to: CGPoint(x: x, y: yR))
                                } else {
                                    refSpeed.addLine(to: CGPoint(x: x, y: yS))
                                    refRPM.addLine(to: CGPoint(x: x, y: yR))
                                }
                            }
                            context.stroke(refRPM, with: .color(.yellow.opacity(0.32)), lineWidth: 1.2)
                            context.stroke(refSpeed, with: .color(.green.opacity(0.38)), lineWidth: 1.5)
                        }
                    }
                    .padding(4)

                    // Axis overlays
                    VStack {
                        HStack {
                            Text("24x").font(.system(size: 9, design: .monospaced)).foregroundStyle(.green.opacity(0.8))
                            Spacer()
                            Text(driveManager.activeJobPhase)
                                .font(.system(size: 10, weight: .bold, design: .monospaced))
                                .foregroundStyle(.white.opacity(0.9))
                            Spacer()
                            Text("6000 RPM").font(.system(size: 9, design: .monospaced)).foregroundStyle(.yellow.opacity(0.8))
                        }
                        Spacer()
                        HStack {
                            Text("0x (Lead-In)").font(.system(size: 9, design: .monospaced)).foregroundStyle(.secondary)
                            Spacer()
                            Text("LBA \(driveManager.currentSectorLBA) / \(driveManager.totalTargetSectorsLBA)")
                                .font(.system(size: 9, design: .monospaced))
                                .foregroundStyle(.cyan)
                            Spacer()
                            Text("Outer Rim (Lead-Out)").font(.system(size: 9, design: .monospaced)).foregroundStyle(.secondary)
                        }
                    }
                    .padding(8)
                }
                .frame(height: 135)
                .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.blue.opacity(0.45), lineWidth: 1))

                // Right: Live Nerd Telemetry Readout Grid
                VStack(alignment: .leading, spacing: 5) {
                    nerdStatRow(label: "LIVE SPEED:", value: String(format: "%.1fx (%.0f KB/s)", driveManager.currentSpeedX, driveManager.currentSpeedKBs), color: .green)
                    nerdStatRow(label: "AVERAGE / PEAK:", value: String(format: "%.1fx / %.1fx", driveManager.averageSpeedX, driveManager.peakSpeedX), color: .primary)
                    nerdStatRow(label: "SPINDLE VELOCITY:", value: "\(driveManager.currentSpindleRPM) RPM (\(driveManager.writeStrategyText))", color: .yellow)
                    nerdStatRow(label: "DRIVE BUFFER:", value: String(format: "%.0f%% (BURN-Proof Armed)", driveManager.driveBufferFillPercent), color: .cyan)
                    nerdStatRow(label: "LASER / OPC:", value: driveManager.laserWavelengthText, color: .orange)
                    nerdStatRow(label: "ELAPSED TIME:", value: String(format: "%02d:%02d • Track %02d", driveManager.elapsedSeconds / 60, driveManager.elapsedSeconds % 60, driveManager.activeTrackNumber), color: .secondary)
                }
                .frame(width: 245)
                .padding(8)
                .background(Color.black.opacity(0.25))
                .clipShape(RoundedRectangle(cornerRadius: 6))
            }
        }
        .padding(12)
        .background(Color(NSColor.controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.primary.opacity(0.1), lineWidth: 1))
    }

    private func nerdStatRow(label: String, value: String, color: Color) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 9, weight: .bold, design: .monospaced))
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .font(.system(size: 10, weight: .semibold, design: .monospaced))
                .foregroundStyle(color)
                .lineLimit(1)
        }
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
                .clipShape(Capsule())
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
                                    Text(item.version)
                                        .font(.system(size: 10, weight: .semibold, design: .monospaced))
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(Color.secondary.opacity(0.15))
                                        .clipShape(Capsule())
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
                        Image(systemName: "plus.rectangle.on.folder.fill")
                        Text(activeSpec.sourceSupport == "Image Only" ? "Select Disc Image / ROM..." : "Add Media or Files...")
                    }
                    .font(.system(size: 12, weight: .semibold))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(store.activeAccent)
                    .foregroundStyle(.white)
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }

            Divider()

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

                if activeSpec.isDataDisc {
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
                        Label("File List", systemImage: "list.bullet.indent")
                            .font(.caption.bold())
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer()
            }

            if activeDataWorkspaceTab == 1 && enableCustomFinderLayoutTab && activeSpec.isDataDisc {
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
                            Text("Drag & Drop Files, Folders, or Disc Images Here from Finder")
                                .font(.headline)
                            Text("Or click 'Add Media or Files...' above to add items to the File List.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    } else {
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

                                        Text("\(entry.sectorsLBA) LBA")
                                            .font(.system(size: 10, weight: .medium, design: .monospaced))
                                            .padding(.horizontal, 8)
                                            .padding(.vertical, 3)
                                            .background(store.activeAccent.opacity(0.15))
                                            .clipShape(Capsule())

                                        Text(ByteCountFormatter.string(fromByteCount: entry.byteSize, countStyle: .file))
                                            .font(.system(size: 11, design: .monospaced))
                                            .foregroundStyle(.secondary)
                                            .frame(width: 80, alignment: .trailing)

                                        Button {
                                            store.removeStagedFile(id: entry.id)
                                        } label: {
                                            Image(systemName: "xmark.circle.fill")
                                                .foregroundStyle(.secondary)
                                        }
                                        .buttonStyle(.plain)
                                    }
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 9)
                                    Divider()
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
                .font(.system(size: 10, weight: .medium))
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(store.activeAccent.opacity(0.15))
                .clipShape(Capsule())
            Text(duration)
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(.secondary)
                .frame(width: 70, alignment: .trailing)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
    }

    // MARK: - RIGHT COLUMN: MULTI-DRIVE DESTINATIONS (INDEPENDENT DRIVE BINDINGS!)
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

            ScrollView {
                VStack(spacing: 12) {
                    ForEach(Array(store.destinationQueue.enumerated()), id: \.element.id) { idx, item in
                        destinationCard(index: idx, item: item)
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
                    .foregroundStyle(.white)
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

    private func destinationCard(index: Int, item: DestinationQueueItem) -> some View {
        // Resolve THIS card's specific optical drive by item.targetDriveID!
        let cardDrive = driveManager.driveForID(item.targetDriveID)
        let activeCardDriveID = cardDrive?.id ?? ""
        let validSpeeds = cardDrive?.availableWriteSpeeds ?? ["Max Safe (Auto)", "24x (4234 KB/s)", "10x (1764 KB/s)", "8x (1411 KB/s)", "4x (705 KB/s)", "2x (353 KB/s)"]

        return VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Image(systemName: item.kind.sfSymbol)
                    .foregroundStyle(store.activeAccent)
                Picker("", selection: $store.destinationQueue[index].kind) {
                    ForEach(allowedDestinationsForCurrentCategory) { kind in
                        Text(kind.rawValue).tag(kind)
                    }
                }
                .labelsHidden()
                Spacer()
                if item.kind == .physicalBurner {
                    Menu {
                        Button("Quick Erase (Fast TOC Blank — ~30s)") {
                            driveManager.eraseRewritableDisc(driveID: activeCardDriveID, fullErase: false) { _ in }
                        }
                        Button("Full Erase (Zero All Sectors)") {
                            driveManager.eraseRewritableDisc(driveID: activeCardDriveID, fullErase: true) { _ in }
                        }
                    } label: {
                        HStack(spacing: 3) {
                            Image(systemName: "eraser.fill")
                            Text("Erase RW")
                        }
                        .font(.system(size: 10, weight: .semibold))
                    }
                    .menuStyle(.borderlessButton)
                    .fixedSize()
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .background(store.activeAccent.opacity(0.16))
                    .clipShape(Capsule())
                    .help("Erase rewritable disc in \(cardDrive?.displayName ?? "this burner")")

                    Button {
                        driveManager.ejectDrive(id: activeCardDriveID)
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "eject.fill")
                            Text("Eject")
                        }
                        .font(.system(size: 10, weight: .semibold))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Color.secondary.opacity(0.15))
                        .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                    .help("Eject \(cardDrive?.displayName ?? "Disc")")
                }
                if store.destinationQueue.count > 1 {
                    Button {
                        store.destinationQueue.remove(at: index)
                    } label: {
                        Image(systemName: "minus.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
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
                    // Per-Card Independent Drive Picker! Changing Card 2 will NOT change Card 1!
                    Picker("Drive:", selection: Binding(
                        get: {
                            activeCardDriveID
                        },
                        set: { newDriveID in
                            store.destinationQueue[index].targetDriveID = newDriveID
                            if let chosen = driveManager.driveForID(newDriveID) {
                                store.destinationQueue[index].hardwareOrPath = chosen.displayName
                                driveManager.selectedDrive = chosen
                            }
                        }
                    )) {
                        ForEach(driveManager.availableDrives) { d in
                            Text(d.displayName).tag(d.id)
                        }
                    }
                    .labelsHidden()

                    if let activeDrive = cardDrive {
                        HStack(spacing: 6) {
                            HStack(spacing: 5) {
                                Circle()
                                    .fill(activeDrive.isMediaPresent ? Color.green : Color.secondary)
                                    .frame(width: 7, height: 7)
                                Text(activeDrive.statusBadgeText)
                                    .font(.system(size: 10, weight: .semibold))
                            }
                            .padding(.horizontal, 9)
                            .padding(.vertical, 4)
                            .background((activeDrive.isMediaPresent ? Color.green : Color.secondary).opacity(0.15))
                            .foregroundStyle(activeDrive.isMediaPresent ? .green : .secondary)
                            .clipShape(Capsule())

                            Text("FW \(activeDrive.firmware)")
                                .font(.system(size: 10, design: .monospaced))
                                .padding(.horizontal, 7)
                                .padding(.vertical, 4)
                                .background(Color.secondary.opacity(0.12))
                                .foregroundStyle(.secondary)
                                .clipShape(Capsule())

                            Spacer()
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
                            validSpeeds.contains(store.destinationQueue[index].speedOrCodec)
                                ? store.destinationQueue[index].speedOrCodec
                                : "Max Safe (Auto)"
                        },
                        set: { newVal in
                            store.destinationQueue[index].speedOrCodec = newVal
                        }
                    )) {
                        ForEach(validSpeeds, id: \.self) { spd in
                            Text(spd).tag(spd)
                        }
                    }
                    .labelsHidden()
                    .frame(width: 155)
                }
            } else if item.kind == .networkBurner {
                Text(item.hardwareOrPath)
                    .font(.system(size: 11, weight: .semibold, design: .monospaced))
                HStack(spacing: 6) {
                    HStack(spacing: 5) {
                        Circle().fill(Color.green).frame(width: 7, height: 7)
                        Text("LAN Node Online (256 MB Ring Buffer)")
                            .font(.system(size: 10, weight: .semibold))
                    }
                    .padding(.horizontal, 9)
                    .padding(.vertical, 4)
                    .background(Color.green.opacity(0.15))
                    .foregroundStyle(.green)
                    .clipShape(Capsule())
                    Spacer()
                }
            } else if item.kind == .discImage {
                HStack(spacing: 6) {
                    TextField("~/Desktop/Krouton_Master.dmg", text: $store.destinationQueue[index].hardwareOrPath)
                        .textFieldStyle(.roundedBorder)
                        .font(.system(size: 11, design: .monospaced))
                    Button("Save As...") {
                        let panel = NSSavePanel()
                        panel.nameFieldStringValue = "\(store.discVolumeTitle).dmg"
                        if panel.runModal() == .OK, let url = panel.url {
                            store.destinationQueue[index].hardwareOrPath = url.path
                        }
                    }
                    .controlSize(.small)
                }
            } else {
                Text(item.hardwareOrPath)
                    .font(.system(size: 11, weight: .semibold, design: .monospaced))
                    .foregroundStyle(.primary)
            }

            if item.kind == .physicalBurner || item.kind == .networkBurner {
                HStack(spacing: 12) {
                    Toggle("Simulate", isOn: $store.destinationQueue[index].simulationMode)
                        .font(.caption)
                    Toggle("Verify", isOn: $store.destinationQueue[index].verifyAfterBurn)
                        .font(.caption)
                }
            } else if item.kind == .discImage {
                Toggle("Compress Image After Creation", isOn: $store.destinationQueue[index].compressAfterCreation)
                    .font(.caption)
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
                switch target.kind {
                case .discImage:
                    _ = await driveManager.createDiscImageFile(
                        stagedFiles: store.stagedFiles,
                        volumeTitle: store.discVolumeTitle,
                        outputPathString: target.hardwareOrPath,
                        compressImage: target.compressAfterCreation,
                        enableCustomLayout: enableCustomFinderLayoutTab,
                        iconSizePx: Int(finderIconSize)
                    )

                case .physicalBurner:
                    driveManager.startPhysicalDataBurn(
                        driveID: target.targetDriveID,
                        stagedFiles: store.stagedFiles,
                        volumeTitle: store.discVolumeTitle,
                        requestedSpeedLabel: target.speedOrCodec,
                        simulationMode: target.simulationMode,
                        verifyDisc: target.verifyAfterBurn
                    ) { _ in }

                default:
                    break
                }
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

    // Smart Multi-Burner Queueing: Automatically picks the next unused physical drive when you click '+ Add Output'!
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

// MARK: - Spacious, Cleanly Formatted Diagnostic & Mastering Summary Sheet (560 x 390 pt)
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

            // Structured Hardware & Session Telemetry Table
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

            // Hardware / Media Diagnostic Note
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
