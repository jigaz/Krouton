import SwiftUI
import AppKit
import UniformTypeIdentifiers
import OpticalDough

public final class KroutonAppDelegate: NSObject, NSApplicationDelegate {
    public func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        if let window = NSApp.windows.first {
            window.makeKeyAndOrderFront(nil)
        }
    }
}

// MARK: - Appearance & Highlight Theme
public enum AppAppearanceMode: String, CaseIterable, Identifiable {
    case auto = "Auto (System)"
    case dark = "Dark"
    case light = "Light"
    public var id: String { rawValue }

    public var colorScheme: ColorScheme? {
        switch self {
        case .auto: return nil
        case .dark: return .dark
        case .light: return .light
        }
    }
}

public enum HighlightTheme: String, CaseIterable, Identifiable {
    case toastAmber = "Toast Amber"
    case laserBlue = "405nm Laser Blue"
    case rubyRed = "650nm Ruby Red"
    case archivalGreen = "Archival Emerald"
    case titaniumCyan = "Titanium Cyan"

    public var id: String { rawValue }

    public var color: Color {
        switch self {
        case .toastAmber: return Color.orange
        case .laserBlue: return Color.blue
        case .rubyRed: return Color.red
        case .archivalGreen: return Color.green
        case .titaniumCyan: return Color.cyan
        }
    }
}

// MARK: - Seed Zone Formats (Customizable & Groupable)
public enum FormatGroupCategory: String, CaseIterable, Identifiable {
    case audio = "Audio Discs"
    case video = "Video & Blu-ray"
    case data = "Data & Custom Views"
    case copy = "Copy, Shrink & Utilities"
    case legacy = "Legacy & Console Formats"
    public var id: String { rawValue }
}

public struct SeedFormatItem: Identifiable, Hashable {
    public let id: String
    public var title: String
    public var subtitle: String
    public var sfSymbol: String
    public var group: FormatGroupCategory
    public var isEnabled: Bool
    public var defaultCapacityGB: Double
    public var supportsSplitCreationZone: Bool
}

// MARK: - Destination Queue Models
public enum DestinationKind: String, CaseIterable, Identifiable {
    case localBurner = "Physical Optical Burner"
    case sharedBurner = "Network Shared Burner"
    case discImage = "Disc Image File"
    public var id: String { rawValue }

    public var sfSymbol: String {
        switch self {
        case .localBurner: return "opticaldiscdrive.fill"
        case .sharedBurner: return "server.rack"
        case .discImage: return "externaldrive.fill.badge.plus"
        }
    }
}

public struct DestinationQueueItem: Identifiable, Hashable {
    public let id = UUID()
    public var kind: DestinationKind
    public var targetName: String
    public var writeSpeed: String
    public var simulationMode: Bool
    public var verifyAfterBurn: Bool
    public var imageFormat: String
    public var imageDestinationPath: String
    public var compressAfterCreation: Bool
}

// MARK: - Settings Sidebar Panes (macOS System Settings Style)
public enum SettingsPane: String, CaseIterable, Identifiable {
    case appearance = "Appearance"
    case seedFormats = "Formats & Seed List"
    case metadataNaming = "Metadata & Smart Naming"
    case drivesNetwork = "Recorders & Network"
    case audioVideo = "Audio & Video Mastering"
    case labelPrinting = "Disc Label Printer"
    case storageVerify = "Cache & Verification"

    public var id: String { rawValue }

    public var sfSymbol: String {
        switch self {
        case .appearance: return "paintbrush.fill"
        case .seedFormats: return "sidebar.left"
        case .metadataNaming: return "tag.fill"
        case .drivesNetwork: return "network"
        case .audioVideo: return "slider.horizontal.3"
        case .labelPrinting: return "printer.dotmatrix.fill"
        case .storageVerify: return "checkmark.shield.fill"
        }
    }

    public var badgeColor: Color {
        switch self {
        case .appearance: return .purple
        case .seedFormats: return .orange
        case .metadataNaming: return .blue
        case .drivesNetwork: return .green
        case .audioVideo: return .pink
        case .labelPrinting: return .indigo
        case .storageVerify: return .teal
        }
    }
}

// MARK: - Staged Content Models
public struct StagedItem: Identifiable, Hashable {
    public let id = UUID()
    public var name: String
    public var details: String
    public var sizeMB: Double
    public var sfSymbol: String
    public var partitionTarget: String
}

@main
struct KroutonApp: App {
    @NSApplicationDelegateAdaptor(KroutonAppDelegate.self) var appDelegate
    @StateObject private var driveManager = DriveManager()

    // Global Appearance & Settings Window State
    @State private var appearanceMode: AppAppearanceMode = .dark
    @State private var highlightTheme: HighlightTheme = .toastAmber
    @State private var showSettingsSheet: Bool = false
    @State private var selectedSettingsPane: SettingsPane = .appearance
    @State private var showLegacyFormatsInSeed: Bool = true

    // Seed Zone Format Catalog
    @State private var seedFormats: [SeedFormatItem] = [
        SeedFormatItem(id: "cd-text", title: "Audio CD (CD-TEXT)", subtitle: "Red Book DAO + Crossfades", sfSymbol: "waveform.circle.fill", group: .audio, isEnabled: true, defaultCapacityGB: 0.7, supportsSplitCreationZone: false),
        SeedFormatItem(id: "mp3-cd", title: "MP3 Audio Disc", subtitle: "Car-Safe ID3v2.3 + Playlists", sfSymbol: "music.note.list", group: .audio, isEnabled: true, defaultCapacityGB: 0.7, supportsSplitCreationZone: false),
        SeedFormatItem(id: "mixed-cd", title: "Enhanced Mixed-Mode CD", subtitle: "Red Book Audio + Data Partition", sfSymbol: "opticaldisc.fill", group: .audio, isEnabled: true, defaultCapacityGB: 0.7, supportsSplitCreationZone: true),

        SeedFormatItem(id: "dvd-video", title: "DVD-Video", subtitle: "MPEG-2 VIDEO_TS + Auto Menu", sfSymbol: "film.fill", group: .video, isEnabled: true, defaultCapacityGB: 4.7, supportsSplitCreationZone: false),
        SeedFormatItem(id: "bd-on-dvd", title: "Blu-ray Video on DVD", subtitle: "1080p AVCHD / BDMV on 4.7GB DVD", sfSymbol: "sparkles.tv.fill", group: .video, isEnabled: true, defaultCapacityGB: 4.7, supportsSplitCreationZone: false),
        SeedFormatItem(id: "bd-25", title: "25 GB Blu-ray Video", subtitle: "Single-Layer BDMV (1080p / UHD)", sfSymbol: "film.stack.fill", group: .video, isEnabled: true, defaultCapacityGB: 25.0, supportsSplitCreationZone: false),
        SeedFormatItem(id: "bd-50", title: "50 GB Blu-ray Video", subtitle: "Dual-Layer BDMV + Seamless Break", sfSymbol: "square.stack.3d.up.fill", group: .video, isEnabled: true, defaultCapacityGB: 50.0, supportsSplitCreationZone: false),

        SeedFormatItem(id: "data-custom", title: "Mac & PC Custom View Disc", subtitle: "Custom Finder Background & Huge Icons", sfSymbol: "macwindow.badge.plus", group: .data, isEnabled: true, defaultCapacityGB: 4.7, supportsSplitCreationZone: false),
        SeedFormatItem(id: "data-hybrid", title: "Hybrid Split-Partition Disc", subtitle: "Separate Mac APFS/HFS+ & Windows UDF", sfSymbol: "rectangle.split.2x1.fill", group: .data, isEnabled: true, defaultCapacityGB: 4.7, supportsSplitCreationZone: true),

        SeedFormatItem(id: "dvd9-shrink", title: "DVD-9 to 4.7 GB DVD Shrink", subtitle: "Duplicate Movie w/ Menus & Extras", sfSymbol: "arrow.down.right.and.arrow.up.left", group: .copy, isEnabled: true, defaultCapacityGB: 4.7, supportsSplitCreationZone: false),
        SeedFormatItem(id: "boot-rescue", title: "Bootable & Archive.org Disc", subtitle: "BIOS / UEFI Live OS & Rescue ISOs", sfSymbol: "terminal.fill", group: .copy, isEnabled: true, defaultCapacityGB: 4.7, supportsSplitCreationZone: false),
        SeedFormatItem(id: "disc-label", title: "Printable Disc Label (120mm)", subtitle: "18mm Hole / Epson EcoTank ET-8550", sfSymbol: "printer.dotmatrix.fill", group: .copy, isEnabled: true, defaultCapacityGB: 4.7, supportsSplitCreationZone: false),

        SeedFormatItem(id: "console-rom", title: "Console Game Disc", subtitle: "Wii, GameCube, PS1/PS2, Xbox, Dreamcast", sfSymbol: "gamecontroller.fill", group: .legacy, isEnabled: true, defaultCapacityGB: 4.7, supportsSplitCreationZone: false),
        SeedFormatItem(id: "macos9-hfs", title: "Classic Mac OS 9 Boot Disc", subtitle: "HFS Standard + Blessed System Folder", sfSymbol: "desktopcomputer", group: .legacy, isEnabled: true, defaultCapacityGB: 0.65, supportsSplitCreationZone: false)
    ]

    @State private var selectedFormatID: String = "data-custom"

    // Creation Zone State
    @State private var volumeName: String = "KROUTON_MASTER_2026"
    @State private var finderBgColor: Color = Color(red: 0.08, green: 0.14, blue: 0.28)
    @State private var finderIconSize: Double = 256
    @State private var crossfadeDuration: Double = 3.8
    @State private var dvdShrinkRatio: Double = 74.5
    @State private var discTitleText: String = "THE KROUTON SESSIONS"
    @State private var discSubtitleText: String = "MASTER ARCHIVE — DISC 1"
    @State private var innerHubMM: Double = 18.0
    @State private var outerDiameterMM: Double = 120.0

    @State private var stagedItems: [StagedItem] = [
        StagedItem(name: "Master_Project_Files", details: "Folder (macOS & Windows Shared)", sizeMB: 1420.0, sfSymbol: "folder.fill", partitionTarget: "Shared"),
        StagedItem(name: "Krouton_Universal_Installer.app", details: "macOS Application Bundle", sizeMB: 540.0, sfSymbol: "app.badge.checkmark.fill", partitionTarget: "Mac Only"),
        StagedItem(name: "Setup_Windows_x64.exe", details: "Windows PE Installer + autorun.inf", sizeMB: 490.0, sfSymbol: "pc", partitionTarget: "Windows Only"),
        StagedItem(name: "01 - Analogue Horizon.flac", details: "24-bit/96kHz -> Red Book + 3.8s Crossfade", sizeMB: 42.5, sfSymbol: "waveform", partitionTarget: "Shared")
    ]

    // Smart Naming & Metadata State (Smarter than MusicBrainz Picard)
    @State private var namingPatternTokens: [String] = ["[Track 01]", " - ", "[Artist]", " - ", "[Title]"]
    @State private var metadataProvider: String = "MusicBrainz + Apple ShazamKit (Zero-Key)"
    @State private var customTMDBKey: String = ""
    @State private var customFanartKey: String = ""

    // Destination Zone State (Single Hero by default, Expandable Queue via '+')
    @State private var destinationQueue: [DestinationQueueItem] = [
        DestinationQueueItem(
            kind: .sharedBurner,
            targetName: "Pioneer BDR-S13U-X (Server: mac-mini-burner.local)",
            writeSpeed: "8x CAV (Optimal)",
            simulationMode: false,
            verifyAfterBurn: true,
            imageFormat: ".iso (UDF / Hybrid)",
            imageDestinationPath: "~/Movies/OpticalMasters",
            compressAfterCreation: false
        )
    ]

    @State private var isBurning: Bool = false
    @State private var statusBanner: String = "Ready — 256 MB Network Ring Buffer Armed"

    private var activeFormat: SeedFormatItem {
        seedFormats.first(where: { $0.id == selectedFormatID }) ?? seedFormats[0]
    }

    var body: some Scene {
        WindowGroup("Krouton") {
            VStack(spacing: 0) {
                topWindowHeaderBar
                Divider()

                // Main Split: Seed Zone (Left) + Creation Zone (Right/Center)
                HSplitView {
                    seedZoneLeftColumn
                    creationZoneMainArea
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)

                Divider()

                // Bottom Destination Zone (Single Hero or Multi-Item Render Queue)
                destinationZoneBottomArea
            }
            // 50% larger than classic Toast (1280 x 840 default)
            .frame(minWidth: 1280, minHeight: 840)
            .preferredColorScheme(appearanceMode.colorScheme)
            .tint(highlightTheme.color)
            .sheet(isPresented: $showSettingsSheet) {
                systemStyleSettingsModal
            }
        }
        .commands {
            CommandGroup(replacing: .appSettings) {
                Button("Settings...") {
                    showSettingsSheet = true
                }
                .keyboardShortcut(",", modifiers: .command)
            }
        }
    }

    // MARK: - Top Header Bar
    private var topWindowHeaderBar: some View {
        HStack(spacing: 14) {
            HStack(spacing: 8) {
                Image(systemName: "opticaldisc.fill")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(highlightTheme.color)
                VStack(alignment: .leading, spacing: 1) {
                    Text("KROUTON")
                        .font(.system(size: 14, weight: .heavy, design: .rounded))
                    Text("Apple Silicon Optical Authoring Suite")
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            // Capacity Pill
            HStack(spacing: 10) {
                Image(systemName: "chart.pie.fill")
                    .foregroundStyle(highlightTheme.color)
                Text(String(format: "2.49 GB of %.1f GB Staged", activeFormat.defaultCapacityGB))
                    .font(.system(size: 12, weight: .semibold, design: .monospaced))
                ProgressView(value: min(2.49, activeFormat.defaultCapacityGB), total: activeFormat.defaultCapacityGB)
                    .tint(highlightTheme.color)
                    .frame(width: 140)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Color(NSColor.controlBackgroundColor))
            .clipShape(Capsule())

            Spacer()

            // Companion Status + Settings Button
            HStack(spacing: 10) {
                HStack(spacing: 5) {
                    Image(systemName: "applewatch.watchface")
                        .foregroundStyle(.green)
                    Text("Watch & iPhone Linked")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(Color(NSColor.controlBackgroundColor))
                .clipShape(Capsule())

                Button {
                    showSettingsSheet = true
                } label: {
                    Label("Settings...", systemImage: "gearshape.fill")
                        .font(.system(size: 12, weight: .semibold))
                }
                .buttonStyle(.bordered)
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 10)
        .background(.ultraThinMaterial)
    }

    // MARK: - 1. THE SEED ZONE (Left Scrollable Format Column)
    private var seedZoneLeftColumn: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Label("SEED ZONE — FORMATS", systemImage: "list.bullet.indent")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(.secondary)
                Spacer()
                Button {
                    selectedSettingsPane = .seedFormats
                    showSettingsSheet = true
                } label: {
                    Image(systemName: "slider.horizontal.3")
                        .font(.system(size: 11))
                }
                .buttonStyle(.plain)
                .help("Customize & Reorder Formats in Settings...")
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    ForEach(FormatGroupCategory.allCases) { group in
                        let groupItems = seedFormats.filter {
                            $0.group == group && $0.isEnabled && (group != .legacy || showLegacyFormatsInSeed)
                        }
                        if !groupItems.isEmpty {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(group.rawValue.uppercased())
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundStyle(.secondary)
                                    .padding(.horizontal, 10)

                                ForEach(groupItems) { item in
                                    Button {
                                        selectedFormatID = item.id
                                    } label: {
                                        HStack(spacing: 10) {
                                            Image(systemName: item.sfSymbol)
                                                .font(.system(size: 16, weight: .semibold))
                                                .foregroundStyle(selectedFormatID == item.id ? .white : highlightTheme.color)
                                                .frame(width: 24)
                                            VStack(alignment: .leading, spacing: 2) {
                                                Text(item.title)
                                                    .font(.system(size: 12, weight: .semibold))
                                                    .foregroundStyle(selectedFormatID == item.id ? .white : .primary)
                                                Text(item.subtitle)
                                                    .font(.system(size: 10))
                                                    .foregroundStyle(selectedFormatID == item.id ? .white.opacity(0.85) : .secondary)
                                                    .lineLimit(1)
                                            }
                                            Spacer()
                                        }
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 7)
                                        .background(
                                            RoundedRectangle(cornerRadius: 8)
                                                .fill(selectedFormatID == item.id ? highlightTheme.color : Color.clear)
                                        )
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                    }
                }
                .padding(10)
            }
        }
        .frame(minWidth: 270, maxWidth: 310)
        .background(Color(NSColor.controlBackgroundColor))
    }

    // MARK: - 2. THE CREATION ZONE (Main Composer / Adaptive Split Drop Area)
    private var creationZoneMainArea: some View {
        VStack(alignment: .leading, spacing: 14) {
            // Creation Zone Header & Format Toolbar
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 8) {
                        Image(systemName: activeFormat.sfSymbol)
                            .font(.title2)
                            .foregroundStyle(highlightTheme.color)
                        Text("Creation Zone — \(activeFormat.title)")
                            .font(.title3.bold())
                    }
                    Text(activeFormat.subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                HStack(spacing: 10) {
                    Button {
                        openFilePicker()
                    } label: {
                        Label("Add Files or Folders...", systemImage: "plus.rectangle.on.folder.fill")
                    }

                    Button {
                        selectedSettingsPane = .metadataNaming
                        showSettingsSheet = true
                    } label: {
                        Label("Smart Auto-Tag & Rename", systemImage: "wand.and.stars")
                    }
                }
            }

            Divider()

            // Adaptive Composer Body based on Selected Format in Seed Zone
            if activeFormat.supportsSplitCreationZone {
                splitHybridCreationView
            } else if activeFormat.id == "data-custom" {
                customFinderViewComposer
            } else if activeFormat.id == "cd-text" || activeFormat.id == "mp3-cd" {
                audioCrossfadeComposer
            } else if activeFormat.id == "dvd9-shrink" || activeFormat.id.hasPrefix("bd") || activeFormat.id == "dvd-video" {
                videoAndShrinkComposer
            } else if activeFormat.id == "disc-label" {
                printableDiscLabelComposer
            } else {
                universalDropComposer
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // Split Creation View for Hybrid CDs / Split Mac & Windows Data Partitions
    private var splitHybridCreationView: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("Split Hybrid Partition Composer — Drag files into specific OS visibility zones", systemImage: "rectangle.split.3x1.fill")
                    .font(.caption.bold())
                    .foregroundStyle(highlightTheme.color)
                Spacer()
                Text("Single burn creates isolated file system trees sharing common blocks")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 14) {
                hybridPartitionColumn(
                    title: activeFormat.id == "mixed-cd" ? "Session 1: Red Book CD Audio" : "macOS Only (APFS / HFS+)",
                    subtitle: activeFormat.id == "mixed-cd" ? "Plays in standalone CD players" : "Hidden on Windows PCs",
                    sfSymbol: activeFormat.id == "mixed-cd" ? "waveform.circle.fill" : "desktopcomputer",
                    filterKey: "Mac Only"
                )

                hybridPartitionColumn(
                    title: "Shared Cross-Platform Files",
                    subtitle: "Visible on both macOS & Windows",
                    sfSymbol: "folder.fill.badge.person.crop",
                    filterKey: "Shared"
                )

                hybridPartitionColumn(
                    title: activeFormat.id == "mixed-cd" ? "Session 2: CD-Extra Data Track" : "Windows Only (UDF / Joliet)",
                    subtitle: activeFormat.id == "mixed-cd" ? "Mounts on Mac & PC computers" : "Includes autorun.inf + .exe",
                    sfSymbol: "pc",
                    filterKey: "Windows Only"
                )
            }
        }
    }

    private func hybridPartitionColumn(title: String, subtitle: String, sfSymbol: String, filterKey: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: sfSymbol)
                    .foregroundStyle(highlightTheme.color)
                VStack(alignment: .leading, spacing: 1) {
                    Text(title).font(.subheadline.bold())
                    Text(subtitle).font(.system(size: 10)).foregroundStyle(.secondary)
                }
            }
            .padding(8)

            Divider()

            ScrollView {
                VStack(spacing: 8) {
                    ForEach(stagedItems.filter { $0.partitionTarget == filterKey || filterKey == "Shared" }) { item in
                        HStack {
                            Image(systemName: item.sfSymbol)
                                .foregroundStyle(highlightTheme.color)
                            VStack(alignment: .leading) {
                                Text(item.name).font(.system(size: 12, weight: .medium))
                                Text(item.details).font(.system(size: 10)).foregroundStyle(.secondary)
                            }
                            Spacer()
                            Text(String(format: "%.0f MB", item.sizeMB))
                                .font(.system(size: 10, design: .monospaced))
                        }
                        .padding(8)
                        .background(Color(NSColor.controlBackgroundColor))
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                    }
                }
                .padding(8)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(NSColor.textBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.secondary.opacity(0.25), lineWidth: 1))
    }

    // Custom Finder Window Background & Huge Icon Composer
    private var customFinderViewComposer: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 18) {
                HStack(spacing: 6) {
                    Text("Volume Title:")
                        .font(.caption.bold())
                    TextField("Volume Name", text: $volumeName)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 200)
                }
                ColorPicker("Finder Background:", selection: $finderBgColor)
                    .font(.caption.bold())
                HStack(spacing: 8) {
                    Text("Icon Size: \(Int(finderIconSize)) px")
                        .font(.caption.bold())
                    Slider(value: $finderIconSize, in: 64...512, step: 32)
                        .frame(width: 150)
                }
                Spacer()
                Text("Writes binary .DS_Store + Windows desktop.ini")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(10)
            .background(Color(NSColor.controlBackgroundColor))
            .clipShape(RoundedRectangle(cornerRadius: 8))

            // Simulated macOS Finder Window Canvas
            VStack(spacing: 0) {
                HStack {
                    HStack(spacing: 6) {
                        Circle().fill(.red.opacity(0.8)).frame(width: 10, height: 10)
                        Circle().fill(.yellow.opacity(0.8)).frame(width: 10, height: 10)
                        Circle().fill(.green.opacity(0.8)).frame(width: 10, height: 10)
                    }
                    Spacer()
                    Label(volumeName, systemImage: "opticaldisc")
                        .font(.system(size: 12, weight: .semibold))
                    Spacer()
                    Text("Finder Preview (\(Int(finderIconSize))x\(Int(finderIconSize)) Icons)")
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color(NSColor.windowFrameTextColor).opacity(0.08))

                Divider()

                ScrollView {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: max(120, finderIconSize * 0.55)), spacing: 28)], spacing: 24) {
                        ForEach(stagedItems) { item in
                            VStack(spacing: 8) {
                                Image(systemName: item.sfSymbol)
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: finderIconSize * 0.34, height: finderIconSize * 0.34)
                                    .foregroundStyle(highlightTheme.color)
                                    .shadow(radius: 4)
                                Text(item.name)
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundStyle(.white)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 3)
                                    .background(Color.black.opacity(0.5))
                                    .clipShape(RoundedRectangle(cornerRadius: 5))
                            }
                            .padding(10)
                        }
                    }
                    .padding(28)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(finderBgColor)
            }
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.secondary.opacity(0.3), lineWidth: 1))
        }
    }

    // Audio CD-TEXT & Jam Crossfade Composer
    private var audioCrossfadeComposer: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("ML Beat-Matched Track Crossfader & CD-TEXT Editor", systemImage: "waveform.path.ecg")
                    .font(.subheadline.bold())
                Spacer()
                Text(String(format: "Equal-Power Crossover: %.1f sec", crossfadeDuration))
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundStyle(highlightTheme.color)
                Slider(value: $crossfadeDuration, in: 0.0...8.0, step: 0.2)
                    .frame(width: 180)
            }
            .padding(10)
            .background(Color(NSColor.controlBackgroundColor))
            .clipShape(RoundedRectangle(cornerRadius: 8))

            ScrollView {
                VStack(spacing: 8) {
                    ForEach(Array(stagedItems.enumerated()), id: \.element.id) { index, item in
                        HStack(spacing: 14) {
                            Text(String(format: "%02d", index + 1))
                                .font(.system(.body, design: .monospaced))
                                .foregroundStyle(.secondary)
                            Image(systemName: "music.note")
                                .foregroundStyle(highlightTheme.color)
                            VStack(alignment: .leading) {
                                Text(item.name).fontWeight(.semibold)
                                Text("ISRC: US-KRT-26-0000\(index + 1) • CD-TEXT Ready • Car-Safe ID3v2.3")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Text(String(format: "Crossfade: %.1fs", crossfadeDuration))
                                .font(.system(.caption, design: .monospaced))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(highlightTheme.color.opacity(0.18))
                                .clipShape(Capsule())
                        }
                        .padding(10)
                        .background(Color(NSColor.controlBackgroundColor))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                }
            }

            // Visual Jam Crossover Curve
            Canvas { context, size in
                let midX = size.width * 0.5
                let spread = CGFloat(crossfadeDuration / 10.0) * size.width * 0.45

                var outPath = Path()
                outPath.move(to: CGPoint(x: 0, y: 18))
                outPath.addLine(to: CGPoint(x: midX - spread, y: 18))
                outPath.addCurve(
                    to: CGPoint(x: midX + spread, y: size.height - 14),
                    control1: CGPoint(x: midX, y: 18),
                    control2: CGPoint(x: midX, y: size.height - 14)
                )
                outPath.addLine(to: CGPoint(x: size.width, y: size.height - 14))
                context.stroke(outPath, with: .color(.cyan), lineWidth: 2.5)

                var inPath = Path()
                inPath.move(to: CGPoint(x: 0, y: size.height - 14))
                inPath.addLine(to: CGPoint(x: midX - spread, y: size.height - 14))
                inPath.addCurve(
                    to: CGPoint(x: midX + spread, y: 18),
                    control1: CGPoint(x: midX, y: size.height - 14),
                    control2: CGPoint(x: midX, y: 18)
                )
                inPath.addLine(to: CGPoint(x: size.width, y: 18))
                context.stroke(inPath, with: .color(highlightTheme.color), lineWidth: 2.5)
            }
            .frame(height: 110)
            .background(Color.black.opacity(0.7))
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
    }

    // Video & DVD-9 to DVD-5 Shrink Composer
    private var videoAndShrinkComposer: some View {
        VStack(alignment: .leading, spacing: 14) {
            GroupBox("DVD-9 (8.5 GB) to DVD-5 (4.7 GB) Menu-Preserving Requantizer & Blu-ray Authoring") {
                VStack(spacing: 12) {
                    HStack {
                        Image(systemName: "menucard.fill").foregroundStyle(.green)
                        Text("Original Interactive Menus, Chapters & Subpictures")
                        Spacer()
                        Text("100% Intact (412 MB)").font(.system(.caption, design: .monospaced)).foregroundStyle(.green)
                    }
                    Divider()
                    HStack {
                        Image(systemName: "film.fill").foregroundStyle(highlightTheme.color)
                        Text("Main Movie Feature (Hardware VideoToolbox / M2VRequant)")
                        Spacer()
                        Slider(value: $dvdShrinkRatio, in: 55...95)
                            .frame(width: 160)
                        Text(String(format: "%.1f%% (3,380 MB)", dvdShrinkRatio))
                            .font(.system(.caption, design: .monospaced))
                            .foregroundStyle(highlightTheme.color)
                    }
                    Divider()
                    HStack {
                        Image(systemName: "sparkles.tv.fill").foregroundStyle(.cyan)
                        Text("Bonus Features, Commentaries & Deleted Scenes")
                        Spacer()
                        Text("Preserved (590 MB)").font(.system(.caption, design: .monospaced)).foregroundStyle(.cyan)
                    }
                }
                .padding(10)
            }
            universalDropComposer
        }
    }

    // Printable 120mm / 18mm Disc Label Composer (Epson ET-8550)
    private var printableDiscLabelComposer: some View {
        HStack(spacing: 28) {
            VStack(alignment: .leading, spacing: 12) {
                GroupBox("Disc Label Typography & Artwork Lookup") {
                    VStack(alignment: .leading, spacing: 10) {
                        TextField("Top Arc Title", text: $discTitleText)
                            .textFieldStyle(.roundedBorder)
                        TextField("Bottom Subtitle", text: $discSubtitleText)
                            .textFieldStyle(.roundedBorder)
                        HStack {
                            Text("Hub Hole: \(Int(innerHubMM)) mm")
                                .font(.caption)
                            Slider(value: $innerHubMM, in: 15...41, step: 1)
                            Button("18mm Reset") { innerHubMM = 18.0 }
                                .font(.caption)
                        }
                    }
                    .padding(8)
                }

                GroupBox("Printer Target") {
                    VStack(alignment: .leading, spacing: 6) {
                        Label("Epson EcoTank Photo ET-8550 (Front CD/DVD Tray)", systemImage: "printer.fill")
                            .font(.subheadline.bold())
                        Text("Outer Diameter: 120.0 mm • Center Hole: 18.0 mm • Claria ET 6-Ink ColorSync")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(8)
                }
                Spacer()
            }
            .frame(maxWidth: 420)

            VStack {
                ZStack {
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [highlightTheme.color.opacity(0.85), Color.black.opacity(0.92)],
                                center: .center,
                                startRadius: 20,
                                endRadius: 150
                            )
                        )
                        .frame(width: 270, height: 270)
                        .overlay(Circle().stroke(Color.white.opacity(0.4), lineWidth: 2))

                    VStack(spacing: 110) {
                        Text(discTitleText.uppercased())
                            .font(.system(size: 13, weight: .heavy, design: .rounded))
                            .foregroundStyle(.white)
                        Text(discSubtitleText.uppercased())
                            .font(.system(size: 10, weight: .semibold, design: .monospaced))
                            .foregroundStyle(.white.opacity(0.85))
                    }

                    Circle()
                        .fill(Color(NSColor.windowBackgroundColor))
                        .frame(
                            width: CGFloat(innerHubMM / outerDiameterMM) * 270.0,
                            height: CGFloat(innerHubMM / outerDiameterMM) * 270.0
                        )
                        .overlay(Circle().stroke(highlightTheme.color, style: StrokeStyle(lineWidth: 1.5, dash: [3, 3])))
                }
                Text(String(format: "%.1f mm Circle / %.1f mm Center Hub Hole", outerDiameterMM, innerHubMM))
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private var universalDropComposer: some View {
        ScrollView {
            VStack(spacing: 8) {
                ForEach(stagedItems) { item in
                    HStack(spacing: 12) {
                        Image(systemName: item.sfSymbol)
                            .font(.title3)
                            .foregroundStyle(highlightTheme.color)
                            .frame(width: 28)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(item.name).fontWeight(.semibold)
                            Text(item.details).font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                        Text(String(format: "%.1f MB", item.sizeMB))
                            .font(.system(.caption, design: .monospaced))
                    }
                    .padding(10)
                    .background(Color(NSColor.controlBackgroundColor))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }
            }
        }
    }

    // MARK: - 3. THE DESTINATION ZONE (Single Hero Default + '+' Multi-Destination Render Queue)
    private var destinationZoneBottomArea: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label(
                    destinationQueue.count == 1
                        ? "DESTINATION ZONE — SINGLE OUTPUT"
                        : "DESTINATION ZONE — MULTI-OUTPUT RENDER QUEUE (\(destinationQueue.count) TARGETS)",
                    systemImage: destinationQueue.count == 1 ? "target" : "list.Number"
                )
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(.secondary)

                Spacer()

                // Discreet '+' Button to add destinations (Burners, Shared Burners, Disc Images)
                Menu {
                    Button {
                        addDestination(.localBurner)
                    } label: {
                        Label("Add Physical Optical Burner", systemImage: "opticaldiscdrive.fill")
                    }
                    Button {
                        addDestination(.sharedBurner)
                    } label: {
                        Label("Add Network Shared Burner (Server)", systemImage: "server.rack")
                    }
                    Button {
                        addDestination(.discImage)
                    } label: {
                        Label("Add Disc Image Output (.iso / .dmg / .toast)", systemImage: "externaldrive.fill.badge.plus")
                    }
                } label: {
                    Label("Add Destination", systemImage: "plus.circle.fill")
                        .font(.system(size: 12, weight: .semibold))
                }
                .menuStyle(.borderlessButton)
                .help("Add another burner or simultaneous disc image to the render queue")
            }

            HStack(alignment: .bottom, spacing: 18) {
                // Destination Cards (Hero full-width when 1 item; vertical queue list when > 1)
                VStack(spacing: 8) {
                    ForEach($destinationQueue) { $dest in
                        destinationRowView(item: $dest, isHeroMode: destinationQueue.count == 1)
                    }
                }
                .frame(maxWidth: .infinity)

                // Prominent Beautiful Burn Button anchored in the lower right
                Button {
                    isBurning.toggle()
                    statusBanner = isBurning
                        ? "Active: Dispatching to \(destinationQueue.count) destination(s)..."
                        : "Ready — 256 MB Network Ring Buffer Armed"
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: isBurning ? "laser.burst" : "flame.fill")
                            .font(.system(size: 20, weight: .bold))
                        VStack(alignment: .leading, spacing: 1) {
                            Text(isBurning ? "BURNING..." : (destinationQueue.count > 1 ? "BURN QUEUE (\(destinationQueue.count))" : "BURN"))
                                .font(.system(size: 15, weight: .heavy, design: .rounded))
                            Text(statusBanner)
                                .font(.system(size: 9, weight: .medium, design: .monospaced))
                                .lineLimit(1)
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.vertical, 14)
                    .background(
                        LinearGradient(
                            colors: [highlightTheme.color, highlightTheme.color.opacity(0.78)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .foregroundStyle(.black)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .shadow(color: highlightTheme.color.opacity(0.35), radius: 8, x: 0, y: 3)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 14)
        .background(.ultraThinMaterial)
    }

    private func destinationRowView(item: Binding<DestinationQueueItem>, isHeroMode: Bool) -> some View {
        HStack(spacing: 14) {
            Image(systemName: item.wrappedValue.kind.sfSymbol)
                .font(.system(size: isHeroMode ? 24 : 18, weight: .semibold))
                .foregroundStyle(highlightTheme.color)
                .frame(width: 34)

            Picker("", selection: item.kind) {
                ForEach(DestinationKind.allCases) { kind in
                    Text(kind.rawValue).tag(kind)
                }
            }
            .labelsHidden()
            .frame(width: 185)

            if item.wrappedValue.kind == .discImage {
                // Disc Image Controls
                Picker("Type:", selection: item.imageFormat) {
                    Text(".iso (Standard)").tag(".iso (UDF / Hybrid)")
                    Text(".dmg (macOS)").tag(".dmg (macOS)")
                    Text(".toast (Legacy)").tag(".toast (Legacy)")
                    Text(".bin / .cue (Raw)").tag(".bin / .cue (Raw)")
                }
                .frame(width: 175)

                TextField("Path", text: item.imageDestinationPath)
                    .textFieldStyle(.roundedBorder)
                    .frame(maxWidth: 220)

                Toggle("Compress After Creation", isOn: item.compressAfterCreation)
                    .font(.caption)
            } else {
                // Physical or Network Burner Controls
                Picker("Drive:", selection: item.targetName) {
                    Text("Pioneer BDR-S13U-X (Server: mac-mini-burner.local)").tag("Pioneer BDR-S13U-X (Server: mac-mini-burner.local)")
                    Text("LG WH16NS60 UHD (Server: mac-mini-burner.local)").tag("LG WH16NS60 UHD (Server: mac-mini-burner.local)")
                    Text("Pioneer BDR-XS07TU (Local USB-C)").tag("Pioneer BDR-XS07TU (Local USB-C)")
                }
                .frame(maxWidth: 320)

                Picker("Speed:", selection: item.writeSpeed) {
                    Text("Max Safe").tag("Max Safe")
                    Text("8x CAV (Optimal)").tag("8x CAV (Optimal)")
                    Text("4x Archival").tag("4x Archival")
                    Text("1x Mastering").tag("1x Mastering")
                }
                .frame(width: 165)

                Toggle("Simulation Mode", isOn: item.simulationMode)
                    .font(.caption)
                Toggle("Verify", isOn: item.verifyAfterBurn)
                    .font(.caption)

                Button {
                    statusBanner = "Eject command sent to \(item.wrappedValue.targetName)"
                } label: {
                    Image(systemName: "eject.fill")
                }
                .help("Eject Tray")
            }

            Spacer()

            if destinationQueue.count > 1 {
                Button {
                    destinationQueue.removeAll { $0.id == item.wrappedValue.id }
                } label: {
                    Image(systemName: "minus.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .help("Remove from Destination Queue")
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, isHeroMode ? 12 : 8)
        .background(Color(NSColor.controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(highlightTheme.color.opacity(isHeroMode ? 0.45 : 0.2), lineWidth: 1)
        )
    }

    private func addDestination(_ kind: DestinationKind) {
        destinationQueue.append(
            DestinationQueueItem(
                kind: kind,
                targetName: kind == .localBurner
                    ? "Pioneer BDR-XS07TU (Local USB-C)"
                    : "LG WH16NS60 UHD (Server: mac-mini-burner.local)",
                writeSpeed: "8x CAV (Optimal)",
                simulationMode: false,
                verifyAfterBurn: true,
                imageFormat: ".dmg (macOS)",
                imageDestinationPath: "~/Desktop/Krouton_Master.dmg",
                compressAfterCreation: true
            )
        )
    }

    // MARK: - 4. MACOS SYSTEM SETTINGS-STYLIZED SETTINGS WINDOW
    private var systemStyleSettingsModal: some View {
        NavigationSplitView {
            List(SettingsPane.allCases, selection: $selectedSettingsPane) { pane in
                HStack(spacing: 10) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 6)
                            .fill(pane.badgeColor)
                            .frame(width: 24, height: 24)
                        Image(systemName: pane.sfSymbol)
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(.white)
                    }
                    Text(pane.rawValue)
                        .font(.system(size: 13, weight: .medium))
                }
                .padding(.vertical, 3)
                .tag(pane)
            }
            .navigationSplitViewColumnWidth(min: 220, ideal: 235)
        } detail: {
            VStack(spacing: 0) {
                HStack {
                    Text(selectedSettingsPane.rawValue)
                        .font(.title3.bold())
                    Spacer()
                    Button("Done") {
                        showSettingsSheet = false
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(highlightTheme.color)
                }
                .padding(16)

                Divider()

                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        switch selectedSettingsPane {
                        case .appearance:
                            appearanceSettingsPane
                        case .seedFormats:
                            seedFormatsCustomizationPane
                        case .metadataNaming:
                            smartMetadataPicardPane
                        case .drivesNetwork:
                            drivesAndNetworkSettingsPane
                        case .audioVideo:
                            audioVideoSettingsPane
                        case .labelPrinting:
                            labelPrinterSettingsPane
                        case .storageVerify:
                            storageVerifySettingsPane
                        }
                    }
                    .padding(20)
                }
            }
        }
        .frame(width: 860, height: 580)
        .preferredColorScheme(appearanceMode.colorScheme)
    }

    private var appearanceSettingsPane: some View {
        VStack(alignment: .leading, spacing: 16) {
            GroupBox("Appearance & Window Theme") {
                VStack(alignment: .leading, spacing: 12) {
                    Picker("Appearance Mode:", selection: $appearanceMode) {
                        ForEach(AppAppearanceMode.allCases) { mode in
                            Text(mode.rawValue).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)

                    Divider()

                    Text("Highlight & Accent Color")
                        .font(.subheadline.bold())
                    HStack(spacing: 12) {
                        ForEach(HighlightTheme.allCases) { theme in
                            Button {
                                highlightTheme = theme
                            } label: {
                                HStack(spacing: 6) {
                                    Circle()
                                        .fill(theme.color)
                                        .frame(width: 14, height: 14)
                                    Text(theme.rawValue)
                                        .font(.caption.bold())
                                }
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(highlightTheme == theme ? theme.color.opacity(0.22) : Color.clear)
                                .clipShape(Capsule())
                                .overlay(Capsule().stroke(theme.color, lineWidth: highlightTheme == theme ? 1.5 : 0.4))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .padding(10)
            }
        }
    }

    private var seedFormatsCustomizationPane: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Customize Seed Zone Formats & Custom Order")
                    .font(.subheadline.bold())
                Spacer()
                Toggle("Show Legacy & Console Formats", isOn: $showLegacyFormatsInSeed)
                    .font(.caption)
            }
            Text("Enable the formats you use and arrange their custom order in the main window's left Seed Zone.")
                .font(.caption)
                .foregroundStyle(.secondary)

            ForEach(Array(seedFormats.enumerated()), id: \.element.id) { index, item in
                HStack(spacing: 12) {
                    Toggle("", isOn: $seedFormats[index].isEnabled)
                        .labelsHidden()
                    Image(systemName: item.sfSymbol)
                        .foregroundStyle(highlightTheme.color)
                        .frame(width: 22)
                    VStack(alignment: .leading) {
                        Text(item.title).font(.system(size: 12, weight: .semibold))
                        Text("\(item.group.rawValue) • \(item.subtitle)")
                            .font(.system(size: 10))
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button {
                        if index > 0 { seedFormats.swapAt(index, index - 1) }
                    } label: {
                        Image(systemName: "arrow.up")
                    }
                    .disabled(index == 0)

                    Button {
                        if index < seedFormats.count - 1 { seedFormats.swapAt(index, index + 1) }
                    } label: {
                        Image(systemName: "arrow.down")
                    }
                    .disabled(index == seedFormats.count - 1)
                }
                .padding(8)
                .background(Color(NSColor.controlBackgroundColor))
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }
        }
    }

    private var smartMetadataPicardPane: some View {
        VStack(alignment: .leading, spacing: 14) {
            GroupBox("Visual Token Naming Builder (Zero-Script Alternative to MusicBrainz Picard)") {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Click tokens to assemble how Krouton names MP3 CD tracks, CD-TEXT, and video folders—no regex or Picard scripts required.")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    HStack(spacing: 8) {
                        ForEach(["[Track 01]", "[Artist]", "[Album]", "[Title]", "[Year]", "[ISRC]", "[BPM]"], id: \.self) { token in
                            Button(token) {
                                namingPatternTokens.append(" - ")
                                namingPatternTokens.append(token)
                            }
                            .font(.system(size: 11, weight: .semibold, design: .monospaced))
                        }
                        Spacer()
                        Button("Reset") {
                            namingPatternTokens = ["[Track 01]", " - ", "[Artist]", " - ", "[Title]"]
                        }
                        .font(.caption)
                    }

                    HStack {
                        Text("Active Pattern:")
                            .font(.caption.bold())
                        Text(namingPatternTokens.joined())
                            .font(.system(size: 12, design: .monospaced))
                            .foregroundStyle(highlightTheme.color)
                    }
                    Text("Live Preview: 01 - The Krouton Trio - Analogue Horizon.mp3")
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(.green)
                }
                .padding(10)
            }

            GroupBox("Cover Art & Metadata Providers (Zero-Key + Custom API Keys)") {
                VStack(alignment: .leading, spacing: 10) {
                    Picker("Primary Lookup:", selection: $metadataProvider) {
                        Text("MusicBrainz + Apple ShazamKit + iTunes + TVMaze (Zero-Key)").tag("MusicBrainz + Apple ShazamKit (Zero-Key)")
                        Text("Custom API Keys (TMDB / Fanart.tv / Discogs)").tag("Custom API Keys")
                    }
                    TextField("Optional TMDB API Key (Movies & TV Posters)", text: $customTMDBKey)
                        .textFieldStyle(.roundedBorder)
                    TextField("Optional Fanart.tv API Key (Circular Disc Scans)", text: $customFanartKey)
                        .textFieldStyle(.roundedBorder)
                }
                .padding(10)
            }
        }
    }

    private var drivesAndNetworkSettingsPane: some View {
        GroupBox("Network Burner Server & Companion Notifications") {
            VStack(alignment: .leading, spacing: 10) {
                Toggle("Discover Shared Network Optical Drives (macOS Remote Disc & Server Nodes)", isOn: .constant(true))
                Toggle("Allocate 256 MB Server RAM Ring Buffer (Prevents Network Buffer Underruns)", isOn: .constant(true))
                Toggle("Publish Burn Progress to iPhone Dynamic Island & Apple Watch", isOn: .constant(true))
            }
            .padding(10)
        }
    }

    private var audioVideoSettingsPane: some View {
        GroupBox("Audio & Video Mastering Defaults") {
            VStack(alignment: .leading, spacing: 10) {
                Toggle("Car-Stereo Safe MP3 CDs (Enforce ID3v2.3 & Strip macOS ._* Files)", isOn: .constant(true))
                Toggle("Use Apple Intelligence / SoundAnalysis for Auto-Beatmatched Crossfades", isOn: .constant(true))
                Toggle("Default Single-Movie Video Discs to Instant First-Play (No Menu)", isOn: .constant(true))
                Toggle("Preserve All Original Menus & Extras When Shrinking DVD-9 to 4.7 GB DVD-5", isOn: .constant(true))
            }
            .padding(10)
        }
    }

    private var labelPrinterSettingsPane: some View {
        GroupBox("Epson EcoTank Photo ET-8550 Disc Tray Calibration") {
            VStack(alignment: .leading, spacing: 10) {
                Text("Default Geometry: 120.0 mm Outer Circle / 18.0 mm Center Hub Hole")
                    .font(.caption.bold())
                Toggle("Enable Claria ET 6-Color Photo Ink ColorSync Soft-Proofing", isOn: .constant(true))
                Toggle("Use Vision Subject-Detection to Keep Faces Out of the 18mm Center Hole", isOn: .constant(true))
            }
            .padding(10)
        }
    }

    private var storageVerifySettingsPane: some View {
        GroupBox("Scratch Disk, Post-Burn Verification & Parity") {
            VStack(alignment: .leading, spacing: 10) {
                Toggle("Verify Optical Sectors Against Source SHA-256 Checksum After Burn", isOn: .constant(true))
                Toggle("Embed 5% .par2 Scratch-Recovery Parity Blocks in Archival Data Discs", isOn: .constant(false))
                Toggle("Automatically Clean Staging Cache After Successful Burn", isOn: .constant(true))
            }
            .padding(10)
        }
    }

    private func openFilePicker() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = true
        if panel.runModal() == .OK {
            for url in panel.urls {
                stagedItems.append(
                    StagedItem(
                        name: url.lastPathComponent,
                        details: url.hasDirectoryPath ? "Folder" : "File",
                        sizeMB: 120.0,
                        sfSymbol: url.hasDirectoryPath ? "folder.fill" : "doc.fill",
                        partitionTarget: "Shared"
                    )
                )
            }
        }
    }
}
