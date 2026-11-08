import SwiftUI
import AppKit
import UniformTypeIdentifiers
import OpticalDough

// Ensures SwiftPM executable launches as a foreground macOS GUI app
// and fixes the _NSGlassEffectWindow canBecomeKeyWindow issue on macOS 26.
public final class KroutonAppDelegate: NSObject, NSApplicationDelegate {
    public func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        if let window = NSApp.windows.first {
            window.makeKeyAndOrderFront(nil)
        }
    }
}

public enum KroutonWorkspaceTab: String, CaseIterable, Identifiable {
    case data = "Data"
    case audio = "Audio"
    case video = "Video"
    case copyShrink = "Copy / Shrink"
    case boot = "Tartine Boot"
    case label = "Galette Label"
    case crustini = "Crustini"

    public var id: String { rawValue }

    public var sfSymbol: String {
        switch self {
        case .data: return "externaldrive.fill.badge.plus"
        case .audio: return "waveform.circle.fill"
        case .video: return "film.stack.fill"
        case .copyShrink: return "doc.on.doc.fill"
        case .boot: return "terminal.fill"
        case .label: return "printer.dotmatrix.fill"
        case .crustini: return "cpu.fill"
        }
    }
}

public struct StagedFileItem: Identifiable, Hashable {
    public let id = UUID()
    public var name: String
    public var sizeMB: Double
    public var kind: String
    public var sfSymbol: String
}

public struct AudioTrackRow: Identifiable, Hashable {
    public let id = UUID()
    public var number: Int
    public var title: String
    public var artist: String
    public var isrc: String
    public var duration: String
    public var crossfadeSec: Double
}

public struct ArchiveBootItem: Identifiable, Hashable {
    public let id = UUID()
    public var title: String
    public var archiveID: String
    public var category: String
    public var sizeMB: Int
    public var bootMode: String
}

@main
struct KroutonApp: App {
    @NSApplicationDelegateAdaptor(KroutonAppDelegate.self) var appDelegate
    @StateObject private var driveManager = DriveManager()

    @State private var selectedTab: KroutonWorkspaceTab = .data
    @State private var selectedDiscCapacityGB: Double = 4.7
    @State private var usedCapacityGB: Double = 4.35

    // Data & Custom Finder View (.DS_Store) State
    @State private var volumeName: String = "KROUTON_ARCHIVE_2026"
    @State private var finderBgColor: Color = Color(red: 0.09, green: 0.15, blue: 0.33)
    @State private var finderIconSize: Double = 256
    @State private var finderGridSpacing: Double = 96
    @State private var generateWindowsAutorun: Bool = true
    @State private var stagedFiles: [StagedFileItem] = [
        StagedFileItem(name: "Master_Project_Assets", sizeMB: 1420.0, kind: "Folder", sfSymbol: "folder.fill"),
        StagedFileItem(name: "Krouton_Universal_Installer.dmg", sizeMB: 680.5, kind: "Disk Image", sfSymbol: "opticaldiscdrive.fill"),
        StagedFileItem(name: "Session_Notes_2026.pdf", sizeMB: 24.2, kind: "PDF Document", sfSymbol: "doc.richtext.fill"),
        StagedFileItem(name: "Bonus_4K_Trailer.mov", sizeMB: 2225.0, kind: "QuickTime Movie", sfSymbol: "film.fill")
    ]

    // Audio & Jam Crossfade State
    @State private var audioSubMode: String = "Red Book CD-TEXT"
    @State private var autoJamCrossfade: Bool = true
    @State private var carSafeMP3Mode: Bool = true
    @State private var globalCrossfadeSec: Double = 3.8
    @State private var audioTracks: [AudioTrackRow] = [
        AudioTrackRow(number: 1, title: "Analogue Horizon (Intro)", artist: "The Krouton Trio", isrc: "US-KRT-26-00001", duration: "03:42", crossfadeSec: 3.8),
        AudioTrackRow(number: 2, title: "650 Nanometers", artist: "The Krouton Trio", isrc: "US-KRT-26-00002", duration: "04:15", crossfadeSec: 4.2),
        AudioTrackRow(number: 3, title: "Lead-In Groove", artist: "The Krouton Trio", isrc: "US-KRT-26-00003", duration: "05:01", crossfadeSec: 2.5),
        AudioTrackRow(number: 4, title: "Subchannel Q (Live)", artist: "The Krouton Trio", isrc: "US-KRT-26-00004", duration: "06:18", crossfadeSec: 0.0)
    ]

    // Video & DVD-9 Shrink State
    @State private var videoPreset: String = "BD-on-DVD (AVCHD)"
    @State private var menuBehavior: String = "Auto (1 Track = First-Play)"
    @State private var dvd9ToDvd5Shrink: Bool = true
    @State private var preserveMenusAndExtras: Bool = true
    @State private var requantRatio: Double = 74.2

    // Tartine Boot & Archive.org State
    @State private var archiveSearchQuery: String = ""
    @State private var selectedBootItem: ArchiveBootItem?
    @State private var showVMPreviewSheet: Bool = false
    @State private var bootCatalog: [ArchiveBootItem] = [
        ArchiveBootItem(title: "SystemRescue 11.03 (Live Recovery + ZFS/APFS)", archiveID: "systemrescue-11-amd64", category: "System Rescue", sizeMB: 854, bootMode: "UEFI + BIOS El Torito"),
        ArchiveBootItem(title: "FreeDOS 1.4 Full + BIOS Flash Room", archiveID: "freedos-1.4-live", category: "DOS / Firmware", sizeMB: 412, bootMode: "BIOS El Torito"),
        ArchiveBootItem(title: "Ubuntu 26.04 LTS Desktop Live (ARM64 / x86_64)", archiveID: "ubuntu-26.04-live", category: "Linux Live", sizeMB: 4620, bootMode: "UEFI + BIOS Hybrid"),
        ArchiveBootItem(title: "Mac OS 9.2.2 Universal Install CD (archive.org)", archiveID: "macos-922-universal", category: "Vintage Mac (archive.org)", sizeMB: 645, bootMode: "Apple Partition Map (HFS)"),
        ArchiveBootItem(title: "Windows 11 25H2 Recovery + TPM Bypass ISO", archiveID: "win11-25h2-custom", category: "Windows Boot", sizeMB: 4480, bootMode: "UEFI UDF")
    ]

    // Galette 120mm / 18mm Epson ET-8550 Label State
    @State private var discTitleText: String = "THE KROUTON SESSIONS"
    @State private var discSubtitleText: String = "DISC 1 — MASTER ARCHIVE 2026"
    @State private var innerHubDiameterMM: Double = 18.0
    @State private var outerDiameterMM: Double = 120.0
    @State private var xOffsetMM: Double = 0.0
    @State private var yOffsetMM: Double = 0.0
    @State private var labelAccentColor: Color = Color(red: 0.14, green: 0.28, blue: 0.58)
    @State private var artworkLookupQuery: String = ""
    @State private var artworkSourceProvider: String = "MusicBrainz / Cover Art Archive (No Key)"

    // Crustini Experimental State
    @State private var enableMacOS9HFS: Bool = true
    @State private var enableConsoleRebuilder: Bool = true
    @State private var enableHTOA: Bool = false
    @State private var enableLightScribe: Bool = false

    // Burn Simulation State
    @State private var isBurning: Bool = false
    @State private var burnStatusMessage: String = "Ready — 256 MB Server Ring Buffer Armed"

    var body: some Scene {
        WindowGroup("Krouton v0.1.0-alpha.3") {
            VStack(spacing: 0) {
                topModeShelf
                Divider()
                HSplitView {
                    leftInspectorDrawer
                    centerWorkspaceArea
                }
                Divider()
                bottomRecorderBar
            }
            .frame(minWidth: 1060, minHeight: 680)
            .sheet(isPresented: $showVMPreviewSheet) {
                vmTestBootSheet
            }
        }
    }

    // MARK: - Top Toast-Homage Mode Shelf
    private var topModeShelf: some View {
        HStack(spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "opticaldisc.fill")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(.orange)
                VStack(alignment: .leading, spacing: 1) {
                    Text("KROUTON")
                        .font(.system(size: 13, weight: .heavy, design: .rounded))
                    Text("v0.1.0-alpha.3")
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.trailing, 8)

            ForEach(KroutonWorkspaceTab.allCases) { tab in
                Button {
                    selectedTab = tab
                    updateCapacityForTab(tab)
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: tab.sfSymbol)
                        Text(tab.rawValue)
                            .font(.system(size: 12, weight: .semibold))
                    }
                    .padding(.horizontal, 11)
                    .padding(.vertical, 7)
                    .background(selectedTab == tab ? Color.orange.opacity(0.24) : Color.clear)
                    .overlay(
                        RoundedRectangle(cornerRadius: 7)
                            .stroke(selectedTab == tab ? Color.orange.opacity(0.7) : Color.clear, lineWidth: 1)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 7))
                }
                .buttonStyle(.plain)
            }

            Spacer()

            HStack(spacing: 6) {
                Image(systemName: "applewatch.watchface")
                    .foregroundStyle(.green)
                Text("Watch & iPhone Activity Ready")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(Color(NSColor.controlBackgroundColor))
            .clipShape(Capsule())
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(.ultraThinMaterial)
    }

    // MARK: - Left Inspector Drawer
    private var leftInspectorDrawer: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                Text("\(selectedTab.rawValue.uppercased()) INSPECTOR")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(.secondary)

                switch selectedTab {
                case .data:
                    Group {
                        Text("Volume Label")
                            .font(.caption.bold())
                        TextField("Volume Name", text: $volumeName)
                            .textFieldStyle(.roundedBorder)
                        Toggle("Hybrid Mac (HFS+/APFS) & PC (UDF)", isOn: .constant(true))
                        Toggle("Strip macOS ._* for Windows", isOn: .constant(true))
                        Divider()
                        Text("Custom Finder View (.DS_Store)")
                            .font(.subheadline.bold())
                        ColorPicker("Window Background", selection: $finderBgColor)
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Icon Size: \(Int(finderIconSize)) x \(Int(finderIconSize)) px")
                                .font(.caption)
                            Slider(value: $finderIconSize, in: 64...512, step: 32)
                        }
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Grid Spacing: \(Int(finderGridSpacing)) pt")
                                .font(.caption)
                            Slider(value: $finderGridSpacing, in: 48...160, step: 16)
                        }
                        Toggle("Write Windows autorun.inf + desktop.ini", isOn: $generateWindowsAutorun)
                    }

                case .audio:
                    Group {
                        Picker("Disc Mode", selection: $audioSubMode) {
                            Text("Red Book CD-TEXT").tag("Red Book CD-TEXT")
                            Text("Car-Safe MP3 CD").tag("Car-Safe MP3 CD")
                        }
                        .pickerStyle(.segmented)

                        Divider()
                        Toggle("Write Binary CD-TEXT & ISRC", isOn: .constant(true))
                        Toggle("ML Auto-Jam Beat Crossfades", isOn: $autoJamCrossfade)
                        VStack(alignment: .leading, spacing: 4) {
                            Text(String(format: "Default Crossover: %.1f sec", globalCrossfadeSec))
                                .font(.caption)
                            Slider(value: $globalCrossfadeSec, in: 0.0...8.0, step: 0.2)
                        }
                        Divider()
                        Toggle("Car-Stereo Safe MP3 Mode", isOn: $carSafeMP3Mode)
                        Text("Enforces strict ID3v2.3 tags, writes root .m3u8/.m3u playlists, and strips hidden ._* AppleDouble files.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                case .video:
                    Group {
                        Picker("Target Format", selection: $videoPreset) {
                            Text("DVD-Video (4.7 GB)").tag("DVD-Video (4.7 GB)")
                            Text("BD-on-DVD (AVCHD)").tag("BD-on-DVD (AVCHD)")
                            Text("Blu-ray 25 GB (BD-25)").tag("Blu-ray 25 GB (BD-25)")
                            Text("Blu-ray 50 GB (BD-50)").tag("Blu-ray 50 GB (BD-50)")
                        }
                        Divider()
                        Picker("Menu Generator", selection: $menuBehavior) {
                            Text("Auto (1 Track = First-Play)").tag("Auto (1 Track = First-Play)")
                            Text("Minimalist Chapter Menu").tag("Minimalist Chapter Menu")
                            Text("Sequential Playlist (No Menu)").tag("Sequential Playlist (No Menu)")
                        }
                        Toggle("Hardware VideoToolbox Encode", isOn: .constant(true))
                        Toggle("Passthrough Dolby Atmos / AC3", isOn: .constant(true))
                    }

                case .copyShrink:
                    Group {
                        Toggle("Fit DVD-9 (8.5 GB) to DVD-5 (4.7 GB)", isOn: $dvd9ToDvd5Shrink)
                        Toggle("Preserve All Menus & Subtitles", isOn: $preserveMenusAndExtras)
                        Toggle("Keep Bonus Features & Extras", isOn: .constant(true))
                        Divider()
                        VStack(alignment: .leading, spacing: 4) {
                            Text(String(format: "M2VRequant Ratio: %.1f%%", requantRatio))
                                .font(.caption.bold())
                            Slider(value: $requantRatio, in: 55.0...95.0, step: 0.5)
                        }
                        Text("Uses compressed-domain MPEG-2 requantization to fit an 8.5 GB movie onto a standard 4.7 GB DVD-R in ~3 minutes.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                case .boot:
                    Group {
                        Text("El Torito & UEFI Boot Builder")
                            .font(.subheadline.bold())
                        Toggle("BIOS El Torito Boot Catalog", isOn: .constant(true))
                        Toggle("UEFI ESP FAT32 Boot Image", isOn: .constant(true))
                        Toggle("Apple Partition Map (PPC/68k)", isOn: .constant(false))
                        Divider()
                        Button {
                            showVMPreviewSheet = true
                        } label: {
                            Label("Test Boot in macOS VM", systemImage: "play.desktopcomputer")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.orange)
                    }

                case .label:
                    Group {
                        Text("Epson EcoTank Photo ET-8550")
                            .font(.subheadline.bold())
                        Text("Tray: Front Straight-Pass CD/DVD\nInk: Claria ET 6-Color Photo")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Divider()
                        VStack(alignment: .leading, spacing: 4) {
                            Text(String(format: "Outer Diameter: %.1f mm", outerDiameterMM))
                                .font(.caption)
                            Slider(value: $outerDiameterMM, in: 116.0...120.0, step: 0.5)
                        }
                        VStack(alignment: .leading, spacing: 4) {
                            Text(String(format: "Center Hub Hole: %.1f mm", innerHubDiameterMM))
                                .font(.caption)
                            Slider(value: $innerHubDiameterMM, in: 15.0...41.0, step: 1.0)
                        }
                        HStack {
                            Button("18mm Standard") { innerHubDiameterMM = 18.0 }
                                .font(.caption)
                            Button("23mm Hub") { innerHubDiameterMM = 23.0 }
                                .font(.caption)
                        }
                        Divider()
                        ColorPicker("Disc Tint", selection: $labelAccentColor)
                        VStack(alignment: .leading, spacing: 4) {
                            Text(String(format: "Tray X/Y Calib: %.1f, %.1f mm", xOffsetMM, yOffsetMM))
                                .font(.caption)
                            HStack {
                                Slider(value: $xOffsetMM, in: -2.0...2.0, step: 0.1)
                                Slider(value: $yOffsetMM, in: -2.0...2.0, step: 0.1)
                            }
                        }
                    }

                case .crustini:
                    Group {
                        Text("Experimental & Vintage Modes")
                            .font(.subheadline.bold())
                        Toggle("Classic Mac OS 9 HFS Standard", isOn: $enableMacOS9HFS)
                        Toggle("Console ROM Sector Rebuilder", isOn: $enableConsoleRebuilder)
                        Toggle("Hidden Track One Audio (HTOA)", isOn: $enableHTOA)
                        Toggle("LightScribe & DiscT@2 Etching", isOn: $enableLightScribe)
                    }
                }
                Spacer()
            }
            .padding(16)
        }
        .frame(minWidth: 265, maxWidth: 300)
        .background(Color(NSColor.controlBackgroundColor))
    }

    // MARK: - Center Interactive Workspace
    private var centerWorkspaceArea: some View {
        VStack(alignment: .leading, spacing: 14) {
            switch selectedTab {
            case .data:
                dataWorkspaceView
            case .audio:
                audioWorkspaceView
            case .video, .copyShrink:
                videoAndShrinkWorkspaceView
            case .boot:
                tartineBootWorkspaceView
            case .label:
                galetteLabelWorkspaceView
            case .crustini:
                crustiniWorkspaceView
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // 1. DATA & CUSTOM FINDER VIEW WORKSPACE
    private var dataWorkspaceView: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("Custom Finder Window Preview (.DS_Store + Windows Explorer)", systemImage: "macwindow.badge.plus")
                    .font(.title3.bold())
                Spacer()
                Button {
                    openFilePickerToStage()
                } label: {
                    Label("Add Files / Folders...", systemImage: "plus.rectangle.on.folder.fill")
                }
            }

            // Mock macOS Finder Window Preview
            VStack(spacing: 0) {
                HStack {
                    HStack(spacing: 6) {
                        Circle().fill(.red.opacity(0.8)).frame(width: 10, height: 10)
                        Circle().fill(.yellow.opacity(0.8)).frame(width: 10, height: 10)
                        Circle().fill(.green.opacity(0.8)).frame(width: 10, height: 10)
                    }
                    Spacer()
                    Label(volumeName.isEmpty ? "UNTITLED_DISC" : volumeName, systemImage: "opticaldisc")
                        .font(.system(size: 12, weight: .semibold))
                    Spacer()
                    Text("Read-Only Optical (.DS_Store Active)")
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color(NSColor.windowFrameTextColor).opacity(0.08))

                Divider()

                ScrollView {
                    LazyVGrid(
                        columns: [GridItem(.adaptive(minimum: max(110, finderIconSize * 0.55)), spacing: finderGridSpacing * 0.3)],
                        spacing: 22
                    ) {
                        ForEach(stagedFiles) { item in
                            VStack(spacing: 8) {
                                Image(systemName: item.sfSymbol)
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: finderIconSize * 0.36, height: finderIconSize * 0.36)
                                    .foregroundStyle(.orange)
                                    .shadow(radius: 4)
                                Text(item.name)
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundStyle(.white)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(Color.black.opacity(0.45))
                                    .clipShape(RoundedRectangle(cornerRadius: 4))
                                Text(String(format: "%.1f MB", item.sizeMB))
                                    .font(.system(size: 10, design: .monospaced))
                                    .foregroundStyle(.white.opacity(0.75))
                            }
                            .padding(8)
                        }
                    }
                    .padding(24)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(finderBgColor)
            }
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.secondary.opacity(0.3), lineWidth: 1))
        }
    }

    // 2. AUDIO & JAM CROSSFADE WORKSPACE
    private var audioWorkspaceView: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Label("Marmalade Audio Mastering — \(audioSubMode)", systemImage: "waveform.circle.fill")
                    .font(.title3.bold())
                Spacer()
                Button {
                    globalCrossfadeSec = 4.2
                } label: {
                    Label("Auto-Beatmatch Transitions (SoundAnalysis)", systemImage: "wand.and.stars")
                }
            }

            // Track Table
            Table(audioTracks) {
                TableColumn("#") { row in Text("\(row.number)").font(.system(.body, design: .monospaced)) }.width(30)
                TableColumn("Track Title (CD-TEXT)") { row in Text(row.title).fontWeight(.medium) }
                TableColumn("Performer") { row in Text(row.artist) }
                TableColumn("ISRC Subcode") { row in Text(row.isrc).font(.system(.caption, design: .monospaced)) }
                TableColumn("Duration") { row in Text(row.duration).font(.system(.body, design: .monospaced)) }.width(70)
                TableColumn("Jam Crossfade") { row in
                    Text(String(format: "%.1f s", row.crossfadeSec > 0 ? globalCrossfadeSec : 0.0))
                        .font(.system(.caption, design: .monospaced))
                        .foregroundStyle(.orange)
                }.width(95)
            }
            .frame(minHeight: 200)

            // Roxio Jam Homage Visual Crossfade Envelope
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Label("Roxio Jam Visual Crossover Envelope (Track 01 Out -> Track 02 In)", systemImage: "waveform.path.ecg")
                        .font(.caption.bold())
                    Spacer()
                    Text(String(format: "Equal-Power Overlap: %.2f sec | PQ Index 01 Locked", globalCrossfadeSec))
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(.orange)
                }

                Canvas { context, size in
                    let midX = size.width * 0.5
                    let spread = CGFloat(globalCrossfadeSec / 10.0) * size.width * 0.45

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
                    context.stroke(inPath, with: .color(.orange), lineWidth: 2.5)

                    var indexLine = Path()
                    indexLine.move(to: CGPoint(x: midX, y: 0))
                    indexLine.addLine(to: CGPoint(x: midX, y: size.height))
                    context.stroke(indexLine, with: .color(.green), style: StrokeStyle(lineWidth: 1.5, dash: [4, 4]))
                }
                .frame(height: 105)
                .background(Color.black.opacity(0.65))
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }
        }
    }

    // 3. VIDEO & DVD-9 TO DVD-5 SHRINK WORKSPACE
    private var videoAndShrinkWorkspaceView: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Label("VideoOven — \(videoPreset) & DVD-9 to DVD-5 Smart Requantizer", systemImage: "film.stack.fill")
                    .font(.title3.bold())
                Spacer()
                Text("Menu Behavior: \(menuBehavior)")
                    .font(.caption)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(Color.orange.opacity(0.2))
                    .clipShape(Capsule())
            }

            GroupBox("DVD-9 (7.94 GB Source) -> DVD-5 (4.38 GB Target) Stream Allocation") {
                VStack(spacing: 10) {
                    HStack {
                        Image(systemName: "menucard.fill").foregroundStyle(.green)
                        Text("Interactive Motion Menus & Subpictures (VTS_01_0.VOB)")
                        Spacer()
                        Text("100% Preserved (412 MB)")
                            .font(.system(.caption, design: .monospaced))
                            .foregroundStyle(.green)
                    }
                    Divider()
                    HStack {
                        Image(systemName: "film.fill").foregroundStyle(.orange)
                        Text("Main Feature Title 01 (1h 58m, MPEG-2 + AC3 5.1)")
                        Spacer()
                        Text(String(format: "%.1f%% Requantized (3,340 MB)", requantRatio))
                            .font(.system(.caption, design: .monospaced))
                            .foregroundStyle(.orange)
                    }
                    Divider()
                    HStack {
                        Image(systemName: "sparkles.tv.fill").foregroundStyle(.cyan)
                        Text("Bonus Features, Trailers & Deleted Scenes (Titles 02-05)")
                        Spacer()
                        Text("62.0% Requantized (628 MB)")
                            .font(.system(.caption, design: .monospaced))
                            .foregroundStyle(.cyan)
                    }
                }
                .padding(8)
            }

            GroupBox("Supported High-Definition Optical Profiles") {
                HStack(spacing: 16) {
                    VStack(alignment: .leading, spacing: 4) {
                        Label("Blu-ray Video on DVD (BD-5 / BD-9)", systemImage: "opticaldisc")
                            .font(.subheadline.bold())
                        Text("Authors 1080p H.264 BDMV / AVCHD structures onto standard 4.7 GB DVD-R media for Blu-ray players.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Divider()
                    VStack(alignment: .leading, spacing: 4) {
                        Label("BD-25 (25 GB) & BD-50 (50 GB Dual-Layer)", systemImage: "opticaldisc.fill")
                            .font(.subheadline.bold())
                        Text("Full UDF 2.50 / 2.60 BDMV mastering with automatic Layer-0 to Layer-1 seamless cell break placement.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(8)
            }
            Spacer()
        }
    }

    // 4. TARTINE BOOT & ARCHIVE.ORG WORKSPACE
    private var tartineBootWorkspaceView: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("Tartine Boot Studio & Internet Archive (archive.org) Optical Browser", systemImage: "terminal.fill")
                    .font(.title3.bold())
                Spacer()
                TextField("Search archive.org ISOs...", text: $archiveSearchQuery)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 240)
            }

            Table(bootCatalog, selection: $selectedBootItem.animation()) {
                TableColumn("Disc Image Title") { item in Text(item.title).fontWeight(.medium) }
                TableColumn("Source / Archive ID") { item in Text(item.archiveID).font(.system(.caption, design: .monospaced)) }
                TableColumn("Category") { item in Text(item.category) }.width(140)
                TableColumn("Boot Architecture") { item in Text(item.bootMode).font(.caption) }.width(160)
                TableColumn("Size") { item in Text("\(item.sizeMB) MB").font(.system(.body, design: .monospaced)) }.width(80)
            }
        }
    }

    // 5. GALETTE 120MM / 18MM EPSON ET-8550 DISC LABEL WORKSPACE
    private var galetteLabelWorkspaceView: some View {
        HStack(spacing: 24) {
            VStack(alignment: .leading, spacing: 14) {
                Label("Galette — 120mm / 18mm Disc Face Studio", systemImage: "printer.dotmatrix.fill")
                    .font(.title3.bold())

                GroupBox("Disc Typography & Metadata") {
                    VStack(alignment: .leading, spacing: 10) {
                        TextField("Top Arc Title", text: $discTitleText)
                            .textFieldStyle(.roundedBorder)
                        TextField("Bottom Subtitle", text: $discSubtitleText)
                            .textFieldStyle(.roundedBorder)
                    }
                    .padding(6)
                }

                GroupBox("Zero-Key & Custom API Cover Lookup") {
                    VStack(alignment: .leading, spacing: 10) {
                        Picker("Provider", selection: $artworkSourceProvider) {
                            Text("MusicBrainz / Cover Art Archive (No Key)").tag("MusicBrainz / Cover Art Archive (No Key)")
                            Text("Apple iTunes Search (No Key)").tag("Apple iTunes Search (No Key)")
                            Text("GameTDB Circular Scans (No Key)").tag("GameTDB Circular Scans (No Key)")
                            Text("TMDB / Fanart.tv (Custom API Key)").tag("TMDB / Fanart.tv (Custom API Key)")
                        }
                        HStack {
                            TextField("Album, Movie, TV Show, or Game...", text: $artworkLookupQuery)
                                .textFieldStyle(.roundedBorder)
                            Button("Fetch Art") {}
                        }
                    }
                    .padding(6)
                }

                HStack {
                    Button {
                    } label: {
                        Label("Print to Epson ET-8550 CD Tray", systemImage: "printer.fill")
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.orange)

                    Button {
                    } label: {
                        Label("Export 120mm Vector PDF", systemImage: "arrow.down.doc.fill")
                    }
                }
                Spacer()
            }
            .frame(maxWidth: 420)

            // Live 120.0mm / 18.0mm Circular Disc Canvas
            VStack {
                ZStack {
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [labelAccentColor.opacity(0.95), Color.black.opacity(0.92)],
                                center: .center,
                                startRadius: 20,
                                endRadius: 150
                            )
                        )
                        .frame(width: 280, height: 280)
                        .overlay(Circle().stroke(Color.white.opacity(0.35), lineWidth: 2))
                        .shadow(radius: 12)

                    VStack(spacing: 110) {
                        Text(discTitleText.uppercased())
                            .font(.system(size: 13, weight: .heavy, design: .rounded))
                            .foregroundStyle(.white)
                        Text(discSubtitleText.uppercased())
                            .font(.system(size: 10, weight: .semibold, design: .monospaced))
                            .foregroundStyle(.orange)
                    }

                    // Clamping Ring Guide (41mm)
                    Circle()
                        .stroke(Color.white.opacity(0.22), style: StrokeStyle(lineWidth: 1, dash: [4, 4]))
                        .frame(width: 95, height: 95)

                    // 18.0mm Center Hub Cutout
                    Circle()
                        .fill(Color(NSColor.windowBackgroundColor))
                        .frame(
                            width: CGFloat(innerHubDiameterMM / outerDiameterMM) * 280.0,
                            height: CGFloat(innerHubDiameterMM / outerDiameterMM) * 280.0
                        )
                        .overlay(
                            Circle()
                                .stroke(Color.orange, style: StrokeStyle(lineWidth: 1.5, dash: [3, 3]))
                        )
                }
                Text(String(format: "Geometry: %.1f mm Outer / %.1f mm Center Hole (Epson ET-8550 Calibrated)", outerDiameterMM, innerHubDiameterMM))
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .padding(.top, 8)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    // 6. CRUSTINI VINTAGE & CONSOLE WORKSPACE
    private var crustiniWorkspaceView: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label("Crustini Experimental & Retro Format Vault", systemImage: "cpu.fill")
                .font(.title3.bold())

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 14) {
                GroupBox("Console Game Optical Foundry") {
                    VStack(alignment: .leading, spacing: 6) {
                        Label("PS1 / PS2 / Saturn / Dreamcast / GameCube / Wii / Xbox", systemImage: "gamecontroller.fill")
                            .font(.subheadline.bold())
                            .foregroundStyle(.orange)
                        Text("Directly reconstructs optical sectors from archival .chd, .rvz, .wbfs, .xiso, .cdi, and .gdi images with 2,352-byte EDC/ECC regeneration.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(6)
                }

                GroupBox("Classic Mac HFS Standard (System 7 - OS 9)") {
                    VStack(alignment: .leading, spacing: 6) {
                        Label("Bootable Apple Partition Map (APM)", systemImage: "desktopcomputer")
                            .font(.subheadline.bold())
                            .foregroundStyle(.orange)
                        Text("Writes legacy HFS Standard file systems and blesses vintage System Folders so 68k and PowerPC Macs can boot directly from CD-R.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(6)
                }

                GroupBox("Hidden Track One Audio (HTOA) & SACD-R") {
                    VStack(alignment: .leading, spacing: 6) {
                        Label("Index 00 Pre-Gap Audio & Scarlet Book DSD", systemImage: "waveform.badge.magnifyingglass")
                            .font(.subheadline.bold())
                            .foregroundStyle(.orange)
                        Text("Mastering support for secret pre-gap audio before Track 01 Index 01, plus .dsf / .dff Scarlet Book SACD-R authoring.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(6)
                }

                GroupBox("LightScribe, Labelflash & Yamaha DiscT@2") {
                    VStack(alignment: .leading, spacing: 6) {
                        Label("USBDriverKit Optical Laser Etching", systemImage: "laser.burst")
                            .font(.subheadline.bold())
                            .foregroundStyle(.orange)
                        Text("User-space DriverKit control for legacy LightScribe label coats and data-side DiscT@2 grayscale artwork.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(6)
                }
            }
            Spacer()
        }
    }

    // MARK: - Bottom Recorder Bar
    private var bottomRecorderBar: some View {
        HStack(spacing: 16) {
            HStack(spacing: 8) {
                Image(systemName: (driveManager.selectedDrive?.isNetworkNode == true) ? "network" : "internaldrive.fill")
                    .foregroundStyle(.orange)
                Picker("Recorder:", selection: $driveManager.selectedDrive) {
                    ForEach(driveManager.availableDrives) { drive in
                        Text(drive.displayName).tag(Optional(drive))
                    }
                }
                .frame(width: 290)

                Button {
                    driveManager.refreshDrives()
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .help("Rescan Local & krouton-node Network Drives")

                Button {
                    burnStatusMessage = "Eject command sent to \(driveManager.selectedDrive?.displayName ?? "Drive")"
                } label: {
                    Image(systemName: "eject.fill")
                }
                .help("Eject Optical Tray")
            }

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(String(format: "%.2f GB of %.1f GB staged — %@", usedCapacityGB, selectedDiscCapacityGB, burnStatusMessage))
                        .font(.system(size: 11, weight: .medium, design: .monospaced))
                    Spacer()
                    Picker("", selection: $selectedDiscCapacityGB) {
                        Text("CD (700 MB)").tag(0.7)
                        Text("DVD-5 (4.7 GB)").tag(4.7)
                        Text("DVD-9 (8.5 GB)").tag(8.5)
                        Text("BD-25 (25 GB)").tag(25.0)
                        Text("BD-50 (50 GB)").tag(50.0)
                    }
                    .labelsHidden()
                    .frame(width: 140)
                }
                ProgressView(value: min(usedCapacityGB, selectedDiscCapacityGB), total: selectedDiscCapacityGB)
                    .tint(.orange)
            }

            Button {
                isBurning.toggle()
                burnStatusMessage = isBurning
                    ? "Streaming to \(driveManager.selectedDrive?.hostName ?? "Recorder") (Buffer 100%)"
                    : "Ready — 256 MB Server Ring Buffer Armed"
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: isBurning ? "laser.burst" : "flame.fill")
                    Text(isBurning ? "BURNING..." : "BURN")
                        .font(.system(size: 13, weight: .heavy))
                }
                .padding(.horizontal, 18)
                .padding(.vertical, 10)
                .background(Color.orange)
                .foregroundStyle(.black)
                .clipShape(Capsule())
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(.ultraThinMaterial)
    }

    // MARK: - Helpers
    private func updateCapacityForTab(_ tab: KroutonWorkspaceTab) {
        switch tab {
        case .audio:
            selectedDiscCapacityGB = 0.7
            usedCapacityGB = 0.58
        case .video, .copyShrink:
            selectedDiscCapacityGB = 4.7
            usedCapacityGB = 4.38
        default:
            selectedDiscCapacityGB = 4.7
            usedCapacityGB = 4.35
        }
    }

    private func openFilePickerToStage() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = true
        if panel.runModal() == .OK {
            for url in panel.urls {
                stagedFiles.append(
                    StagedFileItem(
                        name: url.lastPathComponent,
                        sizeMB: 128.0,
                        kind: url.hasDirectoryPath ? "Folder" : "File",
                        sfSymbol: url.hasDirectoryPath ? "folder.fill" : "doc.fill"
                    )
                )
            }
        }
    }

    private var vmTestBootSheet: some View {
        VStack(spacing: 14) {
            HStack {
                Label("Tartine Virtualization.framework Test-Boot Preview", systemImage: "play.desktopcomputer")
                    .font(.headline)
                Spacer()
                Button("Close VM") { showVMPreviewSheet = false }
            }
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.black)
                .frame(width: 560, height: 320)
                .overlay(
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Krouton EFI Virtual Machine Firmware v26.0 (Apple Silicon Virtualization.framework)")
                        Text("Mounting El Torito / UEFI Optical Image: SystemRescue-11.03.iso...")
                        Text("[  OK  ] Reached target Optical Live Rescue Environment.")
                        Text("root@sysrescue:~# _")
                    }
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundStyle(.green)
                    .padding(20),
                    alignment: .topLeading
                )
        }
        .padding(20)
    }
}
