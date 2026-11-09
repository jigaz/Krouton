import SwiftUI
import AppKit
import OpticalDough

@MainActor
final class KroutonWindowManager {
    static let shared = KroutonWindowManager()
    private var settingsWindow: NSWindow?

    func openSettingsWindow(store: KroutonStateStore) {
        if let existing = settingsWindow {
            existing.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let hostingController = NSHostingController(rootView: KroutonSettingsWindowView(store: store))
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 1020, height: 680),
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
                    KroutonWindowManager.shared.openSettingsWindow(store: store)
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

    var body: some View {
        VStack(spacing: 0) {
            topProToolbar
            Divider()

            HSplitView {
                leftTaskChooserColumn
                    .frame(minWidth: 255, idealWidth: 275, maxWidth: 310)

                centerAdaptableWorkspace
                    .frame(minWidth: 580, maxWidth: .infinity, maxHeight: .infinity)

                rightDestinationColumn
                    .frame(minWidth: 320, idealWidth: 350, maxWidth: 390)
            }
        }
        .frame(minWidth: 1280, idealWidth: 1380, minHeight: 820, idealHeight: 880)
        .background(Color(NSColor.windowBackgroundColor))
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
                    Text("Optical Mastering & Archival Suite")
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            HStack(spacing: 10) {
                Image(systemName: "chart.bar.fill")
                    .foregroundStyle(store.activeAccent)
                    .font(.system(size: 11))
                Text(store.useBase10Units ? "3.42 GB of 4.7 GB Staged" : "3.18 GiB of 4.37 GiB (1,793,024 LBA)")
                    .font(.system(size: 11, weight: .semibold, design: .monospaced))
                ProgressView(value: 3.42, total: 4.7)
                    .tint(store.activeAccent)
                    .frame(width: 120)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 6)
            .background(Color(NSColor.controlBackgroundColor))
            .clipShape(Capsule())

            Spacer()

            HStack(spacing: 8) {
                Button {
                    KroutonWindowManager.shared.openSettingsWindow(store: store)
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

    private var leftTaskChooserColumn: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Label("TASK CHOOSER", systemImage: "sidebar.left")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(.secondary)
                Spacer()
                Button {
                    KroutonWindowManager.shared.openSettingsWindow(store: store)
                } label: {
                    Image(systemName: "slider.horizontal.3")
                        .font(.system(size: 11))
                }
                .buttonStyle(.plain)
                .help("Customize visible formats in Settings -> Task Chooser")
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

    private var centerAdaptableWorkspace: some View {
        VStack(alignment: .leading, spacing: 14) {
            switch store.selectedCategory {
            case .burn:
                burnWorkspaceView
            case .copy:
                copyWorkspaceView
            case .label:
                labelWorkspaceView
            }
        }
        .padding(18)
    }

    private var burnWorkspaceView: some View {
        let activeSpec = store.discFormats.first(where: { $0.id == store.selectedTaskID }) ?? store.discFormats[0]
        return VStack(alignment: .leading, spacing: 14) {
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
                Button {
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "plus.rectangle.on.folder.fill")
                        Text("Add Media or Files...")
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color(NSColor.controlBackgroundColor))
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }

            Divider()

            if activeSpec.isMediaPlaylist {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Label("Track Playlist & Subcode / Chapter Inspector", systemImage: "music.note.list")
                            .font(.headline)
                        Spacer()
                        Label(String(format: "Auto-Crossfade: %.1fs (SoundAnalysis Active)", store.defaultCrossfadeSec), systemImage: "waveform.path.ecg")
                            .font(.caption)
                            .foregroundStyle(store.activeAccent)
                    }

                    VStack(spacing: 0) {
                        playlistRow(num: "01", title: "Analogue Horizon (Master Take)", duration: "04:18:22", transition: "2.0s Pre-Gap", info: "ISRC: US-KR1-26-00001 • CD-TEXT")
                        Divider()
                        playlistRow(num: "02", title: "Oakland Midnight Transit", duration: "05:02:10", transition: String(format: "%.1fs Equal-Power Crossfade", store.defaultCrossfadeSec), info: "ISRC: US-KR1-26-00002 • 124 BPM")
                        Divider()
                        playlistRow(num: "03", title: "Pacific Fog & Neon", duration: "06:44:00", transition: "0.0s Gapless Lock", info: "ISRC: US-KR1-26-00003 • 124 BPM")
                    }
                    .background(Color(NSColor.controlBackgroundColor))
                    .clipShape(RoundedRectangle(cornerRadius: 10))

                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text("Transition Crossfade Envelope (Track 01 -> Track 02)")
                                .font(.caption.bold())
                            Spacer()
                            Slider(value: $store.defaultCrossfadeSec, in: 0.0...8.0, step: 0.5)
                                .frame(width: 180)
                        }
                        ZStack {
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color.black.opacity(0.75))
                                .frame(height: 110)
                            HStack(spacing: 0) {
                                Text("Outgoing Track 01 Fade-Out")
                                    .font(.caption2)
                                    .foregroundStyle(.orange)
                                    .padding(.leading, 14)
                                Spacer()
                                Image(systemName: "waveform.path")
                                    .font(.system(size: 36))
                                    .foregroundStyle(store.activeAccent)
                                Spacer()
                                Text("Incoming Track 02 Beat-Locked Fade-In")
                                    .font(.caption2)
                                    .foregroundStyle(.cyan)
                                    .padding(.trailing, 14)
                            }
                        }
                    }
                }
                Spacer()
            } else {
                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 12) {
                        Button {
                            activeDataWorkspaceTab = 0
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: "list.bullet.indent")
                                Text("File System Tree")
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(activeDataWorkspaceTab == 0 ? store.activeAccent.opacity(0.22) : Color.clear)
                            .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)

                        Toggle("Customize Finder & Explorer Window Layout", isOn: $enableCustomFinderLayoutTab)
                            .toggleStyle(.checkbox)
                            .onChange(of: enableCustomFinderLayoutTab) { _, enabled in
                                activeDataWorkspaceTab = enabled ? 1 : 0
                            }

                        if enableCustomFinderLayoutTab {
                            Button {
                                activeDataWorkspaceTab = 1
                            } label: {
                                HStack(spacing: 6) {
                                    Image(systemName: "macwindow.badge.plus")
                                    Text("Custom Window & Icons Tab")
                                }
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(activeDataWorkspaceTab == 1 ? store.activeAccent.opacity(0.22) : Color.clear)
                                .clipShape(Capsule())
                            }
                            .buttonStyle(.plain)
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
                                    HStack(spacing: 42) {
                                        VStack {
                                            Image(systemName: "app.gift.fill")
                                                .font(.system(size: min(finderIconSize * 0.28, 96)))
                                                .foregroundStyle(.white)
                                            Text("Krouton_Archive.pkg")
                                                .font(.caption.bold())
                                                .foregroundStyle(.white)
                                        }
                                        VStack {
                                            Image(systemName: "folder.fill")
                                                .font(.system(size: min(finderIconSize * 0.28, 96)))
                                                .foregroundStyle(store.activeAccent)
                                            Text("Extras & Artwork")
                                                .font(.caption.bold())
                                                .foregroundStyle(.white)
                                        }
                                    }
                                )
                        }
                    } else {
                        VStack(spacing: 0) {
                            playlistRow(num: "DIR", title: "/Applications & Utilities", duration: "1.84 GB", transition: "HFS+ / APFS + UDF", info: "Permissions: rwxr-xr-x")
                            Divider()
                            playlistRow(num: "DIR", title: "/Project_Masters_2026", duration: "1.58 GB", transition: "Hybrid Shared", info: "SHA-256 Verified")
                            Divider()
                            playlistRow(num: "SYS", title: ".DS_Store & autorun.inf", duration: "64 KB", transition: enableCustomFinderLayoutTab ? "Custom View Active" : "Standard View", info: "Auto-Generated")
                        }
                        .background(Color(NSColor.controlBackgroundColor))
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                        Spacer()
                    }
                }
            }
        }
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
                    Text("Source Drive: Pioneer BDR-S13U-X — Disc Detected: Dual-Layer Movie DVD-9 (7.94 GB)")
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
                        .frame(width: 280, height: 280)
                        .overlay(Circle().stroke(Color.white.opacity(0.35), lineWidth: 1.5))

                    VStack {
                        Text(labelDiscTitle)
                            .font(.system(size: 13, weight: .heavy, design: .rounded))
                            .foregroundStyle(.white)
                            .padding(.top, 28)
                        Spacer()
                        Text(labelSubtitle)
                            .font(.system(size: 10, weight: .semibold, design: .monospaced))
                            .foregroundStyle(.white.opacity(0.85))
                            .padding(.bottom, 28)
                    }
                    .frame(width: 280, height: 280)

                    Circle()
                        .fill(Color(NSColor.windowBackgroundColor))
                        .frame(
                            width: CGFloat(preset.innerDiameterMM / preset.outerDiameterMM) * 280.0,
                            height: CGFloat(preset.innerDiameterMM / preset.outerDiameterMM) * 280.0
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

            VStack(spacing: 8) {
                Button {
                } label: {
                    HStack {
                        Image(systemName: primaryActionSymbol)
                            .font(.system(size: 15, weight: .bold))
                        Text(primaryActionTitle)
                            .font(.system(size: 14, weight: .heavy, design: .rounded))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(store.activeAccent)
                    .foregroundStyle(.white)
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)

                Text("Server Ring Buffer: \(Int(store.serverRingBufferMB)) MB Ready • BookType: DVD-ROM")
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
            }
            .padding(14)
        }
        .background(Color(NSColor.controlBackgroundColor))
    }

    private func destinationCard(index: Int, item: DestinationQueueItem) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: item.kind.sfSymbol)
                    .foregroundStyle(store.activeAccent)
                Picker("", selection: $store.destinationQueue[index].kind) {
                    ForEach(allowedDestinationsForCurrentCategory) { kind in
                        Text(kind.rawValue).tag(kind)
                    }
                }
                .labelsHidden()
                Spacer()
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

            Text(item.hardwareOrPath)
                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                .foregroundStyle(.primary)

            HStack {
                Text("Profile / Speed:")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Text(item.speedOrCodec)
                    .font(.caption.bold())
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

    private var allowedDestinationsForCurrentCategory: [DestinationOutputKind] {
        switch store.selectedCategory {
        case .burn:
            return [.networkBurner, .physicalBurner, .discImage]
        case .copy:
            return [.networkBurner, .physicalBurner, .discImage, .audioRip, .videoExtract]
        case .label:
            return [.discPrinter, .pdfVector]
        }
    }

    private func syncDefaultDestinationForCategory(_ category: TaskMasterCategory, taskID: String) {
        switch category {
        case .burn:
            store.destinationQueue = [
                DestinationQueueItem(kind: .networkBurner, hardwareOrPath: "Pioneer BDR-S13U-X (krouton-server.local)", speedOrCodec: "8x CAV (Optimal)", simulationMode: false, verifyAfterBurn: true, compressAfterCreation: false)
            ]
        case .copy:
            if taskID == "copy-rip-audio" {
                store.destinationQueue = [
                    DestinationQueueItem(kind: .audioRip, hardwareOrPath: "~/Music/Krouton Rips/Apple Lossless", speedOrCodec: "ALAC (.m4a) + AccurateRip", simulationMode: false, verifyAfterBurn: true, compressAfterCreation: false)
                ]
            } else if taskID == "copy-rip-video" {
                store.destinationQueue = [
                    DestinationQueueItem(kind: .videoExtract, hardwareOrPath: "~/Movies/Krouton Extracts", speedOrCodec: "H.265 (HEVC 10-bit Hardware)", simulationMode: false, verifyAfterBurn: false, compressAfterCreation: false)
                ]
            } else {
                store.destinationQueue = [
                    DestinationQueueItem(kind: .networkBurner, hardwareOrPath: "Pioneer BDR-S13U-X (krouton-server.local)", speedOrCodec: "Fit-to-Disc 4.7 GB DVD-5", simulationMode: false, verifyAfterBurn: true, compressAfterCreation: false)
                ]
            }
        case .label:
            store.destinationQueue = [
                DestinationQueueItem(kind: .discPrinter, hardwareOrPath: "Epson EcoTank Photo ET-8550 (CD/DVD Tray)", speedOrCodec: "Claria ET 6-Ink • 120mm / 18mm", simulationMode: false, verifyAfterBurn: false, compressAfterCreation: false)
            ]
        }
    }

    private func appendContextAwareDestination() {
        switch store.selectedCategory {
        case .burn:
            store.destinationQueue.append(
                DestinationQueueItem(kind: .discImage, hardwareOrPath: "~/Desktop/Krouton_Master.dmg", speedOrCodec: "Hybrid UDF / HFS+ Image", simulationMode: false, verifyAfterBurn: true, compressAfterCreation: true)
            )
        case .copy:
            store.destinationQueue.append(
                DestinationQueueItem(kind: .discImage, hardwareOrPath: "~/Desktop/Disc_Backup.iso", speedOrCodec: "1:1 Archival Sector Image", simulationMode: false, verifyAfterBurn: true, compressAfterCreation: false)
            )
        case .label:
            store.destinationQueue.append(
                DestinationQueueItem(kind: .pdfVector, hardwareOrPath: "~/Desktop/Epson_ET8550_Label_120mm.pdf", speedOrCodec: "300 DPI Vector PDF Proof", simulationMode: false, verifyAfterBurn: false, compressAfterCreation: false)
            )
        }
    }

    private var primaryActionTitle: String {
        switch store.selectedCategory {
        case .burn: return "BURN (\(store.destinationQueue.count))"
        case .copy: return "START COPY / EXTRACT (\(store.destinationQueue.count))"
        case .label: return "PRINT LABEL (\(store.destinationQueue.count))"
        }
    }

    private var primaryActionSymbol: String {
        switch store.selectedCategory {
        case .burn: return "flame.fill"
        case .copy: return "doc.on.doc.fill"
        case .label: return "printer.fill"
        }
    }
}
