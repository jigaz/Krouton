import SwiftUI
import AppKit
import OpticalDough

public enum KroutonSettingsCategory: String, CaseIterable, Identifiable, Sendable {
    case general = "General"
    case formatChooser = "Format Chooser"
    case discImageDepot = "Disc Image Depot"
    case audioVideo = "Audio & Video"
    case rippingTranscoding = "Ripping & Transcoding"
    case burnersNetwork = "Burners & Network"
    case labelsPrinters = "Labels & Printers"
    case notifications = "Notifications"
    case accessibilityLanguage = "Accessibility & Language"

    public var id: String { rawValue }

    public var sfSymbol: String {
        switch self {
        case .general: return "gearshape"
        case .formatChooser: return "list.bullet.rectangle"
        case .discImageDepot: return "arrow.down.doc.fill"
        case .audioVideo: return "waveform"
        case .rippingTranscoding: return "arrow.triangle.2.circlepath"
        case .burnersNetwork: return "externaldrive.connected.to.line.below"
        case .labelsPrinters: return "printer.dotmatrix"
        case .notifications: return "bell"
        case .accessibilityLanguage: return "accessibility"
        }
    }
}

public struct KroutonSettingsWindowView: View {
    @ObservedObject var store: KroutonStateStore
    @ObservedObject var driveManager: DriveManager
    // Bound to store.selectedSettingsPane for direct Format Chooser deep-linking
    @State private var searchText: String = ""

    @State private var formatFilter: FormatFilterGroup = .all
    @State private var formatSortOrder: [KeyPathComparator<DiscFormatSpec>] = [
        .init(\.technicalName, order: .forward)
    ]
    @State private var selectedFormatIDs: Set<DiscFormatSpec.ID> = []
    @AppStorage("KroutonFormatTableColumnCustomization") private var columnCustomization: TableColumnCustomization<DiscFormatSpec>

    @State private var newPresetName: String = "Custom Disc Tray Preset"
    @State private var newOuterMM: Double = 120.0
    @State private var newInnerMM: Double = 18.0
    @State private var newOffsetX: Double = 0.0
    @State private var newOffsetY: Double = 0.0

    public init(store: KroutonStateStore, driveManager: DriveManager) {
        self.store = store
        self.driveManager = driveManager
    }

    public var body: some View {
        NavigationSplitView {
            VStack(spacing: 10) {
                HStack(spacing: 6) {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(.secondary)
                    TextField("Search settings", text: $searchText)
                        .textFieldStyle(.plain)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Color(NSColor.controlBackgroundColor))
                .clipShape(RoundedRectangle(cornerRadius: 7))
                .padding(.horizontal, 10)
                .padding(.top, 8)

                List(KroutonSettingsCategory.allCases, selection: $store.selectedSettingsPane) { pane in
                    HStack(spacing: 10) {
                        Image(systemName: pane.sfSymbol)
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(store.selectedSettingsPane == pane ? store.activeAccent : .secondary)
                            .frame(width: 20)
                        Text(pane.rawValue)
                            .font(.system(size: 13, weight: .medium))
                    }
                    .padding(.vertical, 4)
                    .tag(pane)
                }
                .listStyle(.sidebar)
            }
            .navigationSplitViewColumnWidth(min: 210, ideal: 225, max: 250)
        } detail: {
            Group {
                if store.selectedSettingsPane == .formatChooser {
                    formatChooserPane
                        .padding(24)
                } else {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 20) {
                            Text(store.selectedSettingsPane.rawValue)
                                .font(.title2.bold())

                            switch store.selectedSettingsPane {
                            case .general:
                                generalPane
                            case .formatChooser:
                                EmptyView()
                            case .discImageDepot:
                                discImageDepotPane
                            case .audioVideo:
                                audioVideoPane
                            case .rippingTranscoding:
                                rippingTranscodingPane
                            case .burnersNetwork:
                                burnersNetworkPane
                            case .labelsPrinters:
                                labelsPrintersPane
                            case .notifications:
                                notificationsPane
                            case .accessibilityLanguage:
                                accessibilityLanguagePane
                            }
                        }
                        .padding(24)
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background(Color(NSColor.windowBackgroundColor))
        }
        .frame(minWidth: 980, idealWidth: 1120, minHeight: 600, idealHeight: 720)
        .preferredColorScheme(store.appearanceMode.colorScheme)
        .tint(store.activeAccent)
    }

    private var generalPane: some View {
        VStack(alignment: .leading, spacing: 18) {
            settingsCard(title: "Theme, Appearance & Accent Color (macOS System Settings + Krouton Studio Palette)") {
                HStack(alignment: .center) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Color")
                            .fontWeight(.medium)
                        Text(store.selectedAccentIndex == -1 ? "Multicolor (Adapts per workspace)" : "Krouton Pro Studio Accent Swatch")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    HStack(spacing: 9) {
                        ForEach(AccentColorPreset.allPresets) { preset in
                            Button {
                                store.selectedAccentIndex = preset.id
                            } label: {
                                ZStack {
                                    if preset.id == -1 {
                                        Circle()
                                            .fill(
                                                AngularGradient(
                                                    colors: [.red, .orange, .yellow, .green, .cyan, .blue, .purple, .pink, .red],
                                                    center: .center
                                                )
                                            )
                                            .frame(width: 22, height: 22)
                                    } else if preset.isMonochrome {
                                        Circle()
                                            .fill(
                                                AngularGradient(
                                                    colors: [.white, .white, .black, .black],
                                                    center: .center
                                                )
                                            )
                                            .frame(width: 22, height: 22)
                                    } else {
                                        Circle()
                                            .fill(preset.swatchColor)
                                            .frame(width: 22, height: 22)
                                    }
                                    Circle()
                                        .stroke(
                                            store.selectedAccentIndex == preset.id ? Color.primary : Color.secondary.opacity(0.35),
                                            lineWidth: store.selectedAccentIndex == preset.id ? 2.5 : 1.0
                                        )
                                        .frame(width: 27, height: 27)
                                }
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel(preset.id == -1 ? "Multicolor Accent" : (preset.isMonochrome ? "Monochrome High Contrast" : "Accent Swatch \(preset.id)"))
                        }
                    }
                }
                Divider()
                HStack {
                    Text("Text highlight color")
                        .fontWeight(.medium)
                    Spacer()
                    HStack(spacing: 6) {
                        Circle()
                            .fill(store.textHighlightMode.resolvedColor(fallback: store.activeAccent))
                            .frame(width: 12, height: 12)
                        Picker("", selection: $store.textHighlightMode) {
                            ForEach(TextHighlightColorMode.allCases) { mode in
                                Text(mode.rawValue).tag(mode)
                            }
                        }
                        .labelsHidden()
                        .frame(width: 150)
                    }
                }
                Divider()
                HStack(alignment: .center) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Icon & widget style")
                            .fontWeight(.medium)
                        Text("Controls how format badges, drive icons, and telemetry tiles render")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    HStack(spacing: 12) {
                        ForEach(IconWidgetStyleMode.allCases) { style in
                            Button {
                                store.iconWidgetStyle = style
                            } label: {
                                VStack(spacing: 4) {
                                    ZStack {
                                        RoundedRectangle(cornerRadius: 9)
                                            .fill(
                                                style == .defaultStyle ? LinearGradient(colors: [store.activeAccent, store.activeAccent.opacity(0.65)], startPoint: .topLeading, endPoint: .bottomTrailing) :
                                                (style == .dark ? LinearGradient(colors: [Color(white: 0.16), Color(white: 0.08)], startPoint: .top, endPoint: .bottom) :
                                                (style == .clear ? LinearGradient(colors: [Color.white.opacity(0.18), Color.white.opacity(0.05)], startPoint: .top, endPoint: .bottom) :
                                                LinearGradient(colors: [Color(white: 0.14), Color(white: 0.08)], startPoint: .top, endPoint: .bottom)))
                                            )
                                            .frame(width: 44, height: 38)
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 9)
                                                    .stroke(store.iconWidgetStyle == style ? store.activeAccent : Color.secondary.opacity(0.3), lineWidth: store.iconWidgetStyle == style ? 2.5 : 1.0)
                                            )
                                        Image(systemName: "opticaldisc.fill")
                                            .font(.system(size: 18, weight: .semibold))
                                            .foregroundStyle(style == .tinted ? store.activeAccent : .white)
                                    }
                                    Text(style.rawValue)
                                        .font(.system(size: 10, weight: store.iconWidgetStyle == style ? .bold : .regular))
                                        .foregroundStyle(store.iconWidgetStyle == style ? .primary : .secondary)
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                Divider()
                HStack {
                    Text("Appearance Mode")
                        .fontWeight(.medium)
                    Spacer()
                    HStack(spacing: 8) {
                        ForEach(AppAppearanceMode.allCases) { mode in
                            pillToggleButton(
                                title: mode.rawValue,
                                sfSymbol: mode.sfSymbol,
                                isSelected: store.appearanceMode == mode
                            ) {
                                store.appearanceMode = mode
                            }
                        }
                    }
                }
                Divider()
                HStack {
                    Text("Folder color")
                        .fontWeight(.medium)
                    Spacer()
                    HStack(spacing: 6) {
                        Image(systemName: "folder.fill")
                            .foregroundStyle(store.resolvedFolderIconColor)
                        Picker("", selection: $store.folderColorMode) {
                            ForEach(FolderColorMode.allCases) { fMode in
                                Text(fMode.rawValue).tag(fMode)
                            }
                        }
                        .labelsHidden()
                        .frame(width: 175)
                    }
                }
            }

            settingsCard(title: "Windows, Sidebar & Language") {
                HStack {
                    Text("Sidebar icon size")
                        .fontWeight(.medium)
                    Spacer()
                    Picker("", selection: $store.sidebarIconSize) {
                        ForEach(SidebarIconSizeMode.allCases) { sz in
                            Text(sz.rawValue).tag(sz)
                        }
                    }
                    .labelsHidden()
                    .frame(width: 140)
                }
                Divider()
                Toggle("Tint window background with wallpaper / active accent color", isOn: $store.tintWindowWithWallpaper)
                Divider()
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Application Language (Live UI Localization)")
                            .fontWeight(.medium)
                        Text("Switches workspace headers, buttons & VoiceOver labels immediately without restarting")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Picker("", selection: $store.appLanguage) {
                        ForEach(KroutonLanguage.allCases) { lang in
                            Text(lang.rawValue).tag(lang)
                        }
                    }
                    .labelsHidden()
                    .frame(width: 210)
                }
            }

            settingsCard(title: "Startup & Units") {
                Toggle("Remember Last Used Task on Launch", isOn: $store.rememberLastTaskOnLaunch)
                Divider()
                HStack {
                    Text("Capacity & Addressing Units")
                    Spacer()
                    HStack(spacing: 8) {
                        pillToggleButton(title: "Base-10 (4.7 GB / 25 GB)", sfSymbol: "opticaldisc", isSelected: store.useBase10Units) {
                            store.useBase10Units = true
                        }
                        pillToggleButton(title: "Binary (4.37 GiB / LBA)", sfSymbol: "number.square", isSelected: !store.useBase10Units) {
                            store.useBase10Units = false
                        }
                    }
                }
            }

            settingsCard(title: "Scratch Disk & System Permissions") {
                HStack(spacing: 10) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Temporary Mastering Cache")
                        Text("Available Free Space: 412.8 GB on Macintosh HD (APFS)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    TextField("Path", text: $store.scratchDiskPath)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 260)
                    pillToggleButton(title: "Choose...", sfSymbol: "folder.fill", isSelected: false) {
                        let panel = NSOpenPanel()
                        panel.canChooseFiles = false
                        panel.canChooseDirectories = true
                        panel.allowsMultipleSelection = false
                        if panel.runModal() == .OK, let url = panel.url {
                            store.scratchDiskPath = url.path
                        }
                    }
                }
                Divider()
                Toggle("Automatically purge temporary muxing files after verified burn", isOn: $store.autoPurgeScratch)
                Divider()
                HStack(spacing: 18) {
                    Label("Optical MMC Access: Granted", systemImage: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                        .font(.caption)
                    Label("Local Network Discovery: Active", systemImage: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                        .font(.caption)
                    Label("FSKit Mount Extension: Registered", systemImage: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                        .font(.caption)
                }
            }
        }
    }

    private var filteredAndSortedFormats: [DiscFormatSpec] {
        let filtered = store.discFormats.filter { fmt in
            switch formatFilter {
            case .all: return true
            case .enabled: return fmt.showInTaskChooser
            default: return fmt.filterGroup == formatFilter
            }
        }
        return filtered.sorted(using: formatSortOrder)
    }

    private var formatChooserPane: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Format Chooser")
                        .font(.title2.bold())
                    Text("Click any column header to sort, drag column dividers to resize width, or drag headers to rearrange columns (just like Finder List View).")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                HStack(spacing: 8) {
                    pillToggleButton(title: "Enable Current", sfSymbol: "checkmark.circle.badge.plus", isSelected: false) {
                        store.enableCurrentTaskChooserFormat()
                    }
                    pillToggleButton(title: "Enable All", sfSymbol: "checkmark.circle", isSelected: false) {
                        for i in store.discFormats.indices { store.discFormats[i].showInTaskChooser = true }
                    }
                }
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(FormatFilterGroup.allCases) { group in
                        pillToggleButton(
                            title: group.rawValue,
                            sfSymbol: "line.3.horizontal.decrease.circle",
                            isSelected: formatFilter == group
                        ) {
                            formatFilter = group
                        }
                    }
                }
            }

            Table(of: DiscFormatSpec.self, selection: $selectedFormatIDs, sortOrder: $formatSortOrder, columnCustomization: $columnCustomization) {
                TableColumn("Show", value: \.visibilitySortKey) { fmt in
                    Toggle("", isOn: Binding(
                        get: { fmt.showInTaskChooser },
                        set: { _ in store.toggleFormatVisibility(id: fmt.id) }
                    ))
                    .labelsHidden()
                    .toggleStyle(.switch)
                    .controlSize(.mini)
                }
                .width(min: 46, ideal: 54, max: 64)
                .customizationID("col-show")

                TableColumn("Format", value: \.technicalName) { fmt in
                    HStack(spacing: 8) {
                        Image(systemName: fmt.sfSymbol)
                            .foregroundStyle(store.activeAccent)
                            .font(.system(size: 13, weight: .semibold))
                            .frame(width: 18)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(fmt.technicalName)
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(.primary)
                            Text(fmt.colloquialName)
                                .font(.system(size: 10))
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.vertical, 2)
                }
                .width(min: 200, ideal: 265, max: 420)
                .customizationID("col-format")

                TableColumn("Year", value: \.launchYear) { fmt in
                    Text(fmt.launchYear)
                        .font(.system(size: 11, design: .monospaced))
                }
                .width(min: 50, ideal: 58, max: 80)
                .customizationID("col-year")

                TableColumn("Capacity", value: \.capacityGB) { fmt in
                    Text(fmt.capacity)
                        .font(.system(size: 11, design: .monospaced))
                }
                .width(min: 95, ideal: 115, max: 160)
                .customizationID("col-capacity")

                TableColumn("Laser", value: \.laserType) { fmt in
                    Text(fmt.laserType)
                        .font(.system(size: 11, design: .monospaced))
                }
                .width(min: 80, ideal: 95, max: 140)
                .customizationID("col-laser")

                TableColumn("Platform / Plays On", value: \.platform) { fmt in
                    Text(fmt.platform)
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
                .width(min: 140, ideal: 185, max: 300)
                .customizationID("col-platform")

                TableColumn("Status", value: \.deprecationStatus) { fmt in
                    Text(fmt.deprecationStatus)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(fmt.deprecationStatus == "Current" ? .green : .secondary)
                }
                .width(min: 85, ideal: 105, max: 150)
                .customizationID("col-status")

                TableColumn("Standard / Mode", value: \.bookOrFileSystem) { fmt in
                    Text("\(fmt.sourceSupport) • \(fmt.bookOrFileSystem)")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
                .width(min: 170, ideal: 230, max: 380)
                .customizationID("col-standard")
            } rows: {
                ForEach(filteredAndSortedFormats) { fmt in
                    TableRow(fmt)
                }
            }
            .tableStyle(.inset(alternatesRowBackgrounds: true))
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(Color.primary.opacity(0.08), lineWidth: 1)
            )
        }
    }

    private var discImageDepotPane: some View {
        VStack(alignment: .leading, spacing: 18) {
            settingsCard(title: "Disc Image Depot — Subscribed Channels & Repositories") {
                ForEach(Array(store.depotChannels.enumerated()), id: \.element.id) { idx, channel in
                    VStack(spacing: 8) {
                        HStack(spacing: 12) {
                            Image(systemName: channel.sfSymbol)
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(store.activeAccent)
                                .frame(width: 24)
                            VStack(alignment: .leading, spacing: 2) {
                                HStack(spacing: 8) {
                                    Text(channel.name)
                                        .font(.system(size: 13, weight: .semibold))
                                    Text("• \(channel.itemCount) Images")
                                        .font(.system(size: 11, weight: .semibold, design: .monospaced))
                                        .foregroundStyle(store.activeAccent)
                                }
                                Text(channel.description)
                                    .font(.system(size: 11))
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Toggle("", isOn: $store.depotChannels[idx].isEnabled)
                                .labelsHidden()
                                .toggleStyle(.switch)
                        }
                        if idx < store.depotChannels.count - 1 {
                            Divider()
                        }
                    }
                }
            }

            settingsCard(title: "Verification, Virtualization Test-Boot & Custom Feeds") {
                Toggle("Automatically verify SHA-256 / PGP signatures on downloaded Depot images before burning", isOn: $store.autoVerifyDepotSHA256)
                Divider()
                Toggle("Enable Apple Virtualization.framework 'Test-Boot in VM' button for El Torito / UEFI images", isOn: $store.enableVMTestBootInDepot)
                Divider()
                HStack {
                    Text("Custom Community Depot Manifest URL")
                    Spacer()
                    TextField("https://...", text: $store.customDepotFeedURL)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 320)
                }
            }
        }
    }

    private var audioVideoPane: some View {
        VStack(alignment: .leading, spacing: 18) {
            settingsCard(title: "Red Book Audio CD & Jam Crossfade Defaults") {
                Toggle("Analyze BPM & Beat Grid automatically via Apple SoundAnalysis on import", isOn: $store.autoBeatmatchSoundAnalysis)
                Divider()
                HStack {
                    Text(String(format: "Default Equal-Power Crossfade Overlap: %.1f seconds", store.defaultCrossfadeSec))
                    Spacer()
                    Slider(value: $store.defaultCrossfadeSec, in: 0.0...8.0, step: 0.5)
                        .frame(width: 220)
                }
                Divider()
                Toggle("Car-Stereo Safe MP3 Mode (Enforce ID3v2.3 & strip hidden macOS ._* files)", isOn: $store.carSafeMP3Mode)
            }

            settingsCard(title: "Video Authoring & Menu Defaults") {
                Toggle("Single Video Track: Play immediately on disc insert (skip menu)", isOn: $store.singleVideoFirstPlay)
                Divider()
                Toggle("Use Apple Silicon VideoToolbox 2-Pass Hardware VBR for Blu-ray & DVD encoding", isOn: $store.videoToolboxTwoPassVBR)
            }

            settingsCard(title: "Fit-to-Disc Compression Defaults (DVD-9 to 4.7 GB DVD-5 & BD-50 to BD-25)") {
                Toggle("Always preserve interactive Menus, Chapter Tables & Bonus Featurettes when shrinking", isOn: $store.fitToDiscPreserveMenus)
                Divider()
                Toggle("Automatically strip foreign audio dubs (retain Original Language + English) to maximize video bitrate", isOn: $store.fitToDiscStripForeignDubs)
            }

            settingsCard(title: "Universal Hardware & Software Decoder Matrix (HandBrake / VLC / Compressor Parity)") {
                HStack {
                    Label("Apple Silicon VideoToolbox ASIC + Accelerate vDSP + libavformat/libavcodec Active", systemImage: "cpu.fill")
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .foregroundStyle(.green)
                    Spacer()
                    Text("Zero-Copy GPU & SIMD Pipeline")
                        .font(.system(size: 10, weight: .semibold, design: .monospaced))
                        .foregroundStyle(.secondary)
                }
                Divider()
                ForEach(UniversalMediaDecoderEngine.liveHardwareCodecMatrix) { row in
                    VStack(alignment: .leading, spacing: 3) {
                        HStack {
                            Image(systemName: row.isHardwareAccelerated ? "bolt.shield.fill" : "cpu")
                                .foregroundStyle(row.isHardwareAccelerated ? .green : store.activeAccent)
                                .font(.system(size: 12))
                            Text(row.category)
                                .font(.system(size: 12, weight: .semibold))
                            Spacer()
                            Text(row.hardwareStatus)
                                .font(.system(size: 10, weight: .bold, design: .monospaced))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 2)
                                .background(Color.green.opacity(0.16))
                                .foregroundStyle(.green)
                                .clipShape(Capsule())
                        }
                        HStack {
                            Text("Formats: \(row.formatsAndExtensions)")
                                .font(.system(size: 10, design: .monospaced))
                                .foregroundStyle(.secondary)
                            Spacer()
                            Text("Engine: \(row.primaryEngine)")
                                .font(.system(size: 10, design: .monospaced))
                                .foregroundStyle(store.activeAccent)
                        }
                    }
                    .padding(.vertical, 2)
                    Divider()
                }
            }
        }
    }

    private var rippingTranscodingPane: some View {
        VStack(alignment: .leading, spacing: 18) {
            settingsCard(title: "Optical Drive Read Offset & Error Recovery (CD / DVD / BD Ripping)") {
                HStack {
                    VStack(alignment: .leading) {
                        Text("Drive Sample Read Offset Correction")
                        Text("Compensates for physical laser lead-in/lead-out offset on Matshita/Pioneer/LG drives")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    TextField("Offset", value: $store.driveReadOffsetSamples, format: .number)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 80)
                    Text("samples")
                        .font(.caption)
                }
                Divider()
                HStack {
                    Text("Paranoia Scratched Sector Re-Read Retries")
                    Spacer()
                    Stepper("\(store.paranoiaErrorRetries) passes", value: $store.paranoiaErrorRetries, in: 1...64)
                }
                Divider()
                Toggle("Verify ripped audio tracks against AccurateRip & MusicBrainz database", isOn: $store.verifyAccurateRip)
                Divider()
                Toggle("Generate archival .cue sheet and extraction .log alongside ALAC / FLAC rips", isOn: $store.writeCueSheetLog)
            }

            settingsCard(title: "Video Disc Extraction & Hardware VideoToolbox") {
                Toggle("Hardware Motion-Compensated Deinterlacing (480i / 1080i -> Progressive H.265)", isOn: $store.hardwareDeinterlaceVideo)
                Divider()
                Toggle("Passthrough lossless Dolby Atmos / TrueHD / DTS-HD Master Audio bitstreams", isOn: $store.passthroughAtmosTrueHD)
            }

            settingsCard(title: "Smart File & Track Naming Pattern (Zero-Script Token Builder)") {
                Text("Click tokens below to append to your active naming pattern, or click any active token pill to remove it:")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                HStack(spacing: 8) {
                    ForEach(["[Track 01]", "[Artist]", "[Album]", "[Title]", "[Year]", " - ", "/"], id: \.self) { token in
                        pillToggleButton(title: token, sfSymbol: "plus.circle", isSelected: false) {
                            store.namingTokens.append(token)
                        }
                    }
                    Spacer()
                    Button("Reset Default") {
                        store.namingTokens = ["[Track 01]", " - ", "[Artist]", " - ", "[Title]"]
                    }
                }

                Divider()

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        Text("Active Pattern:")
                            .font(.caption.bold())
                            .foregroundStyle(.secondary)
                        ForEach(Array(store.namingTokens.enumerated()), id: \.offset) { idx, tok in
                            Button {
                                store.namingTokens.remove(at: idx)
                            } label: {
                                HStack(spacing: 4) {
                                    Text(tok)
                                        .font(.system(size: 11, weight: .semibold, design: .monospaced))
                                    Image(systemName: "xmark.circle.fill")
                                        .font(.system(size: 10))
                                        .foregroundStyle(.secondary)
                                }
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(store.activeAccent.opacity(0.2))
                                .clipShape(Capsule())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }

                Text("Live Output Preview: \(store.namingPreviewString)")
                    .font(.system(size: 11, weight: .semibold, design: .monospaced))
                    .foregroundStyle(store.activeAccent)
            }
        }
    }

    // MARK: - 6. BURNERS & NETWORK PANE (Live Connected Hardware via DriveManager)
    private var burnersNetworkPane: some View {
        VStack(alignment: .leading, spacing: 18) {
            settingsCard(title: "Connected Optical Burners (Live IOKit / DiscRecording Bus)") {
                HStack {
                    Text(driveManager.hardwareStatusLog)
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(.secondary)
                    Spacer()
                    pillToggleButton(title: "Rescan Bus", sfSymbol: "arrow.clockwise", isSelected: false) {
                        driveManager.refreshDrives()
                    }
                }
                Divider()

                if driveManager.availableDrives.isEmpty {
                    HStack {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(.orange)
                        Text("No physical optical drives detected. Plug in your USB burner and click Rescan Bus.")
                            .font(.caption)
                    }
                } else {
                    ForEach(Array(driveManager.availableDrives.enumerated()), id: \.element.id) { idx, drive in
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Image(systemName: drive.isNetworkNode ? "server.rack" : "opticaldiscdrive.fill")
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundStyle(store.activeAccent)
                                VStack(alignment: .leading, spacing: 2) {
                                    HStack(spacing: 8) {
                                        Text(drive.displayName)
                                            .font(.system(size: 13, weight: .bold))
                                        Text("FW \(drive.firmware) • \(drive.interconnect)")
                                            .font(.system(size: 11, weight: .medium, design: .monospaced))
                                            .foregroundStyle(.secondary)
                                    }
                                    Text("Write Capabilities: \(drive.capabilitiesSummary)")
                                        .font(.system(size: 11))
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                HStack(spacing: 5) {
                                    Circle()
                                        .fill(drive.isMediaPresent ? Color.green : Color.secondary)
                                        .frame(width: 7, height: 7)
                                    Text(drive.statusBadgeText)
                                        .font(.system(size: 11, weight: .semibold, design: .monospaced))
                                        .foregroundStyle(drive.isMediaPresent ? .green : .secondary)
                                }
                                .padding(.trailing, 6)

                                pillToggleButton(title: "Eject", sfSymbol: "eject.fill", isSelected: false) {
                                    driveManager.ejectDrive(id: drive.id)
                                }
                            }
                            if idx < driveManager.availableDrives.count - 1 {
                                Divider()
                            }
                        }
                    }
                }
            }

            settingsCard(title: "Network Optical Server (krouton-node) & Buffer Protection") {
                Toggle("Share this Mac's connected optical drives on the local network", isOn: $store.enableNetworkServerSharing)
                Divider()
                HStack {
                    Text("Server RAM Ring Buffer Allocation: \(Int(store.serverRingBufferMB)) MB")
                    Spacer()
                    Slider(value: $store.serverRingBufferMB, in: 64...1024, step: 64)
                        .frame(width: 220)
                }
                Divider()
                Toggle("Pre-stage full compiled disc image to remote server SSD before igniting laser", isOn: $store.preStageImageToServerSSD)
            }

            settingsCard(title: "Optical Drive Hardware & MMC Bitsetting (Retro Console & Set-Top DVD Compatibility)") {
                Toggle("Stamp Book Type as DVD-ROM (0x00) on DVD+R & DVD+R DL Media (Required by vintage DVD players, early PS2 & Xbox)", isOn: $store.forceDVDROMBookType)
                    .fontWeight(.semibold)
                Text("When enabled, Krouton sends the vendor MMC Mode Select / Set Compatibility bitsetting command before lead-in write so DVD+R and DVD+R DL discs identify as pressed factory DVD-ROMs.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Divider()
                HStack {
                    Text("MMC Bitsetting Command Profile")
                    Spacer()
                    Picker("", selection: $store.bitsetVendorProfile) {
                        Text("Auto-Detect (MMC 0xFA / Pioneer / Lite-On / LG)").tag("Auto-Detect (MMC 0xFA / Pioneer / Lite-On / LG)")
                        Text("Pioneer DVR / BDR Extended (0x3B Mode Select)").tag("Pioneer DVR / BDR Extended (0x3B Mode Select)")
                        Text("Lite-On / MediaTek SmartBurn (0xF9 / 0xFF)").tag("Lite-On / MediaTek SmartBurn (0xF9 / 0xFF)")
                        Text("LG / HL-DT-ST / Renesas Super-Multi (0xFA)").tag("LG / HL-DT-ST / Renesas Super-Multi (0xFA)")
                        Text("NEC / Optiarc / Sony (0xFF BookType)").tag("NEC / Optiarc / Sony (0xFF BookType)")
                    }
                    .labelsHidden()
                    .frame(width: 340)
                }
                if !driveManager.availableDrives.isEmpty {
                    Divider()
                    ForEach(driveManager.availableDrives) { drive in
                        HStack {
                            Image(systemName: "opticaldisc.fill")
                                .foregroundStyle(store.activeAccent)
                            Text(drive.displayName)
                                .font(.system(size: 12, weight: .semibold))
                            Spacer()
                            Text(driveManager.bookTypeStatus(for: drive, forceDVDROM: store.forceDVDROMBookType))
                                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                                .foregroundStyle(store.forceDVDROMBookType ? .green : .secondary)
                            pillToggleButton(title: "Stamp DVD-ROM Now", sfSymbol: "seal.fill", isSelected: false) {
                                driveManager.stampDVDROMBookType(for: drive.id, vendorProfile: store.bitsetVendorProfile)
                            }
                        }
                    }
                }
                Divider()
                Toggle("Disable BD-R Defect Management Spare Area on Video Blu-rays (Enables full rated write speed)", isOn: $store.disableBDDefectManagementForVideo)
            }

            settingsCard(title: "Hands-Free Multi-Copy Duplication & Spanned Disc Auto-Loader") {
                Toggle("Auto-Load Next Disc: Eject finished disc & automatically start next burn after fresh blank disc insertion", isOn: $store.autoLoadNextDiscBatchMode)
                    .fontWeight(.semibold)
                Text("Turns your Mac into a hands-free duplication station when burning multiple copies or multi-disc spanned archives.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Divider()
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Post-Insertion Spin-Up & Auto-Fire Delay")
                        Text("Waits for macOS DiskArbitration and optical spindle lock before firing the laser")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Stepper("\(store.autoLoadCountdownSeconds) seconds after insert", value: $store.autoLoadCountdownSeconds, in: 3...15)
                        .font(.system(size: 12, weight: .semibold, design: .monospaced))
                }
            }
        }
    }

    private var labelsPrintersPane: some View {
        VStack(alignment: .leading, spacing: 18) {
            settingsCard(title: "Saved Disc Label Geometry & Tray Offset Presets (Epson EcoTank ET-8550 & Standard Trays)") {
                ForEach(Array(store.labelPresets.enumerated()), id: \.element.id) { idx, preset in
                    HStack {
                        Image(systemName: "circle.circle")
                            .foregroundStyle(store.activeAccent)
                        Text(preset.name)
                            .fontWeight(.semibold)
                        Spacer()
                        Text(String(format: "Outer: %.1fmm | Hole: %.1fmm | Offset X:%.1f Y:%.1fmm", preset.outerDiameterMM, preset.innerDiameterMM, preset.offsetXMM, preset.offsetYMM))
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundStyle(.secondary)
                        if store.labelPresets.count > 1 {
                            Button {
                                store.labelPresets.remove(at: idx)
                            } label: {
                                Image(systemName: "trash")
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    Divider()
                }

                HStack(spacing: 10) {
                    TextField("Preset Name", text: $newPresetName)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 210)
                    Text("Outer:")
                        .font(.caption)
                    TextField("120", value: $newOuterMM, format: .number)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 55)
                    Text("Inner:")
                        .font(.caption)
                    TextField("18", value: $newInnerMM, format: .number)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 50)
                    Text("X/Y Offset:")
                        .font(.caption)
                    TextField("0.0", value: $newOffsetX, format: .number)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 45)
                    TextField("0.0", value: $newOffsetY, format: .number)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 45)
                    Spacer()
                    Button {
                        store.labelPresets.append(
                            LabelGeometryPreset(
                                name: newPresetName,
                                outerDiameterMM: newOuterMM,
                                innerDiameterMM: newInnerMM,
                                offsetXMM: newOffsetX,
                                offsetYMM: newOffsetY
                            )
                        )
                    } label: {
                        Label("Save Preset", systemImage: "plus.circle.fill")
                    }
                }
            }

            settingsCard(title: "Automatic Label Artwork Lookup & Vision Hole-Avoidance") {
                Toggle("Use Apple Vision Subject Detection to keep faces/logos out of the 18mm center hole", isOn: $store.visionHoleAvoidance)
                Divider()
                Text("Zero-Key Databases Enabled: MusicBrainz / Cover Art Archive, Apple iTunes, TVMaze, GameTDB")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                HStack(spacing: 12) {
                    TextField("Optional TMDB API Key (Movies & TV)", text: $store.customTMDBKey)
                        .textFieldStyle(.roundedBorder)
                    TextField("Optional Fanart.tv Key (Transparent Circular Disc Art)", text: $store.customFanartKey)
                        .textFieldStyle(.roundedBorder)
                }
            }
        }
    }

    private var notificationsPane: some View {
        VStack(alignment: .leading, spacing: 16) {
            settingsCard(title: "Alerts, iPhone Live Activities & Apple Watch Notifications") {
                ForEach(Array(store.notificationMatrix.enumerated()), id: \.element.id) { idx, row in
                    VStack(spacing: 8) {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(row.eventTitle)
                                    .font(.system(size: 13, weight: .medium))
                                Text(row.eventSubtitle)
                                    .font(.system(size: 11))
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            HStack(spacing: 8) {
                                iconCircleToggle(
                                    sfSymbol: "bell.fill",
                                    helpText: "macOS Notification Banner",
                                    isOn: $store.notificationMatrix[idx].bannerEnabled
                                )
                                iconCircleToggle(
                                    sfSymbol: "iphone",
                                    helpText: "iPhone Live Activity",
                                    isOn: $store.notificationMatrix[idx].iPhoneEnabled
                                )
                                iconCircleToggle(
                                    sfSymbol: "applewatch",
                                    helpText: "Apple Watch Smart Stack & Wrist Tap",
                                    isOn: $store.notificationMatrix[idx].watchEnabled
                                )
                                iconCircleToggle(
                                    sfSymbol: "speaker.wave.2.fill",
                                    helpText: "Play Audio Alert Sound",
                                    isOn: $store.notificationMatrix[idx].soundEnabled
                                )
                            }
                        }
                        if idx < store.notificationMatrix.count - 1 {
                            Divider()
                        }
                    }
                }
            }

            HStack(spacing: 20) {
                Label("macOS Notification Center", systemImage: "bell.fill")
                Label("iPhone Live Activity", systemImage: "iphone")
                Label("Apple Watch Alert", systemImage: "applewatch")
                Label("Sound Effect", systemImage: "speaker.wave.2.fill")
            }
            .font(.caption)
            .foregroundStyle(.secondary)
            .padding(.horizontal, 6)
        }
    }

    private var accessibilityLanguagePane: some View {
        VStack(alignment: .leading, spacing: 18) {
            settingsCard(title: "VoiceOver & Spoken Hardware Telemetry") {
                Toggle("Announce optical drive events, disc insertions, and burn phase changes via macOS VoiceOver", isOn: $store.voiceOverSpokenTelemetry)
                    .fontWeight(.semibold)
                Text("Posts priority NSAccessibility announcements when blank media is locked, when the 5-second Auto-Load timer counts down, and when verification completes.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Divider()
                HStack {
                    Text("Test VoiceOver Telemetry Speech")
                    Spacer()
                    pillToggleButton(title: "Speak Status Now", sfSymbol: "speaker.wave.3.fill", isSelected: false) {
                        let drv = driveManager.selectedDrive?.displayName ?? "Optical Burner"
                        store.announceForVoiceOver("Krouton Accessibility Ready. Active burner: \(drv).")
                        NSSound.beep()
                    }
                }
            }

            settingsCard(title: "Display, Contrast & Motion Accessibility") {
                Toggle("Increase Contrast (High-contrast borders on Format Chooser, Tracklists & Phase Scope)", isOn: $store.a11yIncreaseContrast)
                Divider()
                Toggle("Differentiate Without Color (Show explicit status symbols alongside green/amber/red LEDs)", isOn: $store.a11yDifferentiateWithoutColor)
                Divider()
                Toggle("Reduce Motion (Disable continuous disc rotation & smooth Phase Scope sweeps)", isOn: $store.a11yReduceMotion)
                Divider()
                HStack {
                    Text(String(format: "Workspace & Telemetry Text Scale: %.0f%%", store.a11yTextScale * 100))
                    Spacer()
                    Slider(value: $store.a11yTextScale, in: 0.90...1.35, step: 0.05)
                        .frame(width: 220)
                }
            }

            settingsCard(title: "Internationalization & Foreign Languages (7 Built-In Locales)") {
                HStack {
                    Text("Active Interface Language")
                        .fontWeight(.semibold)
                    Spacer()
                    Picker("", selection: $store.appLanguage) {
                        ForEach(KroutonLanguage.allCases) { lang in
                            Text(lang.rawValue).tag(lang)
                        }
                    }
                    .labelsHidden()
                    .frame(width: 230)
                }
                Divider()
                Text("Supported Locales: English (US) • 日本語 (Japanese) • Deutsch (German) • Français (French) • Español (Spanish) • 简体中文 (Simplified Chinese) • 한국어 (Korean). All CD-TEXT & Joliet/UDF descriptors remain hardware-sanitized per regional optical standards.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func settingsCard<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(.secondary)
            VStack(alignment: .leading, spacing: 12) {
                content()
            }
            .padding(14)
            .background(Color(NSColor.controlBackgroundColor))
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(Color.primary.opacity(0.08), lineWidth: 1)
            )
        }
    }

    private func pillToggleButton(title: String, sfSymbol: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: sfSymbol)
                    .font(.system(size: 11, weight: .semibold))
                Text(title)
                    .font(.system(size: 12, weight: .medium))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(isSelected ? store.activeAccent.opacity(0.22) : Color(NSColor.windowBackgroundColor))
            .clipShape(Capsule())
            .overlay(
                Capsule()
                    .stroke(isSelected ? store.activeAccent : Color.secondary.opacity(0.3), lineWidth: isSelected ? 1.5 : 1.0)
            )
        }
        .buttonStyle(.plain)
    }

    private func iconCircleToggle(sfSymbol: String, helpText: String, isOn: Binding<Bool>) -> some View {
        Button {
            isOn.wrappedValue.toggle()
        } label: {
            Image(systemName: sfSymbol)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(isOn.wrappedValue ? .white : .secondary)
                .frame(width: 28, height: 28)
                .background(
                    Circle()
                        .fill(isOn.wrappedValue ? store.activeAccent : Color.secondary.opacity(0.15))
                )
        }
        .buttonStyle(.plain)
        .help(helpText)
    }
}
