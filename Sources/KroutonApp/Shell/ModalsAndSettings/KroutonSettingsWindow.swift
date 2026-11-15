import NetworkSpool
import DriveKit
import SwiftUI
import UniformTypeIdentifiers
import OpticalCore

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
    @ObservedObject var driveManager: KroutonOpticalDriveBank
    @ObservedObject var krumb: SpoolRemoteNodeClient = .shared
    @State var isShowingSpoolFileExporter: Bool = false
    @State var isShowingScratchFolderImporter: Bool = false
    @State var spoolExportDocument: SpoolPlainTextFileDocument = SpoolPlainTextFileDocument(text: "")
    @State var spoolExportDefaultFilename: String = "Krumb_Export.log"
    // Bound to store.selectedSettingsPane for direct Format Chooser deep-linking
    @State var searchText: String = ""

    @State var formatFilter: KroutonWorkflowFilterGroup = .all
    @State var formatSortOrder: [KeyPathComparator<KroutonOpticalWorkflowSpec>] = [
        .init(\.technicalName, order: .forward)
    ]
    @State var selectedFormatIDs: Set<KroutonOpticalWorkflowSpec.ID> = []
    @AppStorage("KroutonFormatTableColumnCustomization") var columnCustomization: TableColumnCustomization<KroutonOpticalWorkflowSpec>

    @State var newPresetName: String = "Custom Disc Tray Preset"
    @State var newOuterMM: Double = 120.0
    @State var newInnerMM: Double = 18.0
    @State var newOffsetX: Double = 0.0
    @State var newOffsetY: Double = 0.0

    public init(store: KroutonStateStore, driveManager: KroutonOpticalDriveBank) {
        self.store = store
        self.driveManager = driveManager
    }

    public var body: some View {
        NavigationSplitView {
            VStack(spacing: 10) {
                HStack(spacing: 6) {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(.secondary)
                    TextField(KroutonL10n.tr("Search settings"), text: $searchText)
                        .textFieldStyle(.plain)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Color.kroutonControlSurface)
                .clipShape(RoundedRectangle(cornerRadius: 7))
                .padding(.horizontal, 10)
                .padding(.top, 8)

                ScrollView {
                    VStack(alignment: .leading, spacing: 4) {
                        ForEach(KroutonSettingsCategory.allCases) { pane in
                            let isSelected = (store.selectedSettingsPane == pane)
                            Button {
                                store.selectedSettingsPane = pane
                            } label: {
                                HStack(spacing: 10) {
                                    KroutonStyledIconBadge(
                                        sfSymbol: pane.sfSymbol,
                                        tintColor: store.activeAccent,
                                        style: store.iconWidgetStyle,
                                        isSelectedRow: isSelected,
                                        onAccentText: store.activeOnAccentText,
                                        size: 22,
                                        symbolSize: 12
                                    )
                                    Text(KroutonL10n.tr(pane.rawValue))
                                        .font(.system(size: 13, weight: isSelected ? .semibold : .medium))
                                        .foregroundStyle(isSelected ? store.activeOnAccentText : .primary)
                                        .lineLimit(1)
                                    Spacer(minLength: 0)
                                }
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(
                                    RoundedRectangle(cornerRadius: 7)
                                        .fill(isSelected ? store.activeAccent : Color.clear)
                                )
                                .overlay(RoundedRectangle(cornerRadius: 7).stroke(store.a11yIncreaseContrast && isSelected ? Color.primary : Color.clear, lineWidth: 1.5))
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 10)
                    .padding(.top, 4)
                }
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
                            Text(KroutonL10n.tr(store.selectedSettingsPane.rawValue))
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
        .background(store.enableSecondaryAccentUITints ? store.activeAccent.opacity(0.11) : Color.clear)
            .background(Color.kroutonWindowSurface)
        }
        .frame(minWidth: 980, idealWidth: 1120, minHeight: 600, idealHeight: 720)
        .preferredColorScheme(store.resolvedColorScheme)
        .tint(store.activeAccent)
    }

    var generalPane: some View {
        VStack(alignment: .leading, spacing: 18) {
            settingsCard(title: "Theme, Appearance & Accent Color") {
                HStack(alignment: .center) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(KroutonL10n.tr("Color"))
                            .fontWeight(.medium)
                        Text(KroutonL10n.tr(store.selectedAccentIndex == -1 ? "Multicolor (Adapts per workspace)" : "Krouton Accent Swatch"))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    HStack(spacing: 9) {
                        ForEach(KroutonSeasoningColorPreset.allPresets) { preset in
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

                        HStack(alignment: .center, spacing: 12) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Window & UI Harmony")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundStyle(store.enableSecondaryAccentUITints ? store.activeSecondaryAccent : Color.primary)
                                Text("Tint windows & UI accents with secondary harmony color")
                                    .font(.system(size: 11))
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            KroutonDualHarmonySwitch(
                                isOn: $store.enableSecondaryAccentUITints,
                                primaryColor: store.activeAccent,
                                secondaryColor: store.activeSecondaryAccent
                            )
                        }

                        Divider()
                HStack(alignment: .center) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(KroutonL10n.tr("Icon & widget style"))
                            .fontWeight(.medium)
                        Text(KroutonL10n.tr("Controls how format badges, drive icons, and telemetry tiles render"))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    HStack(spacing: 12) {
                        ForEach(KroutonGarnishStyleMode.allCases) { style in
                            Button {
                                store.iconWidgetStyle = style
                            } label: {
                                VStack(spacing: 4) {
                                    ZStack {
                                        RoundedRectangle(cornerRadius: 9)
                                            .fill(
                                                style == .defaultStyle ? LinearGradient(colors: [store.activeAccent, store.activeAccent.opacity(0.65)], startPoint: .topLeading, endPoint: .bottomTrailing) :
                                                (style == .dark ? LinearGradient(colors: [Color(white: 0.16), Color(white: 0.08)], startPoint: .top, endPoint: .bottom) :
                                                (style == .clear ? LinearGradient(colors: [Color.primary.opacity(0.12), Color.primary.opacity(0.04)], startPoint: .top, endPoint: .bottom) :
                                                (store.resolvedColorScheme == .light
                                                    ? LinearGradient(colors: [Color(white: 0.98), Color(white: 0.93)], startPoint: .topLeading, endPoint: .bottomTrailing)
                                                    : LinearGradient(colors: [Color(white: 0.15), Color(white: 0.08)], startPoint: .topLeading, endPoint: .bottomTrailing))))
                                            )
                                            .overlay(
                                                Group {
                                                    if style == .tinted && store.enableSecondaryAccentUITints {
                                                        let pid = store.selectedAccentIndex >= 0 ? store.selectedAccentIndex : store.multicolorPresetID(forTaskID: store.selectedTaskID, category: store.selectedCategory)
                                                        let brightHarmony = KroutonStateStore.secondaryHarmonyForPresetID(pid, scheme: .dark)
                                                        RoundedRectangle(cornerRadius: 9)
                                                            .fill(store.resolvedColorScheme == .light ? brightHarmony.opacity(0.40) : store.activeSecondaryAccent.opacity(0.28))
                                                    } else if style == .tinted && store.resolvedColorScheme == .light {
                                                        RoundedRectangle(cornerRadius: 9)
                                                            .fill(store.activeAccent.opacity(0.15))
                                                    }
                                                }
                                            )
                                            .frame(width: 44, height: 38)
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 9)
                                                    .stroke(
                                                        store.iconWidgetStyle == style
                                                            ? store.uiSecondaryAccent
                                                            : (style == .tinted && store.enableSecondaryAccentUITints ? store.activeSecondaryAccent.opacity(0.55) : Color.primary.opacity(0.18)),
                                                        lineWidth: store.iconWidgetStyle == style ? 2.5 : 1.0
                                                    )
                                            )
                                        Image(systemName: "opticaldisc.fill")
                                            .font(.system(size: 18, weight: .semibold))
                                            .foregroundStyle(style == .tinted ? store.activeAccent : (style == .clear ? Color.primary : .white))
                                    }
                                    Text(KroutonL10n.tr(style.rawValue))
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
                    Text(KroutonL10n.tr("Appearance Mode"))
                        .fontWeight(.medium)
                    Spacer()
                    HStack(spacing: 8) {
                        ForEach(KroutonRoastAppearanceMode.allCases) { mode in
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
                    Text(KroutonL10n.tr("Folder color"))
                        .fontWeight(.medium)
                    Spacer()
                    HStack(spacing: 6) {
                        Image(systemName: "folder.fill")
                            .foregroundStyle(store.resolvedFolderIconColor)
                        Picker("", selection: $store.folderColorMode) {
                            ForEach(KroutonStageFolderColorMode.allCases) { fMode in
                                Text(KroutonL10n.tr(fMode.rawValue)).tag(fMode)
                            }
                        }
                        .labelsHidden()
                        .frame(width: 175)
                    }
                }
            }
                generalPaneBottomSection
        }
    }

    @ViewBuilder
    private var generalPaneBottomSection: some View {
        VStack(alignment: .leading, spacing: 14) {

            settingsCard(title: "Windows, Sidebar & Language") {
                HStack {
                    Text(KroutonL10n.tr("Sidebar icon size"))
                        .fontWeight(.medium)
                    Spacer()
                    Picker("", selection: $store.sidebarIconSize) {
                        ForEach(KroutonTrackIconSizeMode.allCases) { sz in
                            Text(KroutonL10n.tr(sz.rawValue)).tag(sz)
                        }
                    }
                    .labelsHidden()
                    .frame(width: 140)
                }
                Divider()
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(KroutonL10n.tr("Application Language (Live UI Localization)"))
                            .fontWeight(.medium)
                        Text(KroutonL10n.tr("Switches workspace headers, buttons & VoiceOver labels immediately without restarting"))
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
                HStack {
                    Toggle(KroutonL10n.tr("Automatically remember application state, staged files, and active task on launch (offers to start empty if a crash is detected)"), isOn: $store.rememberLastTaskOnLaunch)
                    Spacer()
                    Button(KroutonL10n.tr("Test Crash Prompt")) {
                        KroutonCrashRecoveryController.shared.simulateUncleanCrashFlagForTesting(store: store)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
                Divider()
                HStack {
                    Text(KroutonL10n.tr("Capacity & Addressing Units"))
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
                        Text(KroutonL10n.tr("Temporary Mastering Cache"))
                        Text(KroutonL10n.tr("Available Free Space: 412.8 GB on Macintosh HD (APFS)"))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    TextField("Path", text: $store.scratchDiskPath)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 260)
                    pillToggleButton(title: "Choose...", sfSymbol: "folder.fill", isSelected: false) {
                        isShowingScratchFolderImporter = true
                    }
                    .fileImporter(
                        isPresented: $isShowingScratchFolderImporter,
                        allowedContentTypes: [.folder],
                        allowsMultipleSelection: false
                    ) { result in
                        if case .success(let urls) = result, let url = urls.first {
                            store.scratchDiskPath = url.path
                        }
                    }
                }
                Divider()
                Toggle(KroutonL10n.tr("Automatically purge temporary muxing files after verified burn"), isOn: $store.autoPurgeScratch)
                Divider()
                HStack(spacing: 18) {
                    Label(KroutonL10n.tr("Optical MMC Access: Granted"), systemImage: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                        .font(.caption)
                    Label(KroutonL10n.tr("Local Network Discovery: Active"), systemImage: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                        .font(.caption)
                    Label(KroutonL10n.tr("FSKit Mount Extension: Registered"), systemImage: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                        .font(.caption)
                }
            }
        }
    }

    var filteredAndSortedFormats: [KroutonOpticalWorkflowSpec] {
        let filtered = store.discFormats.filter { fmt in
            switch formatFilter {
            case .all: return true
            case .enabled: return fmt.showInTaskChooser
            default: return fmt.filterGroup == formatFilter
            }
        }
        return filtered.sorted(using: formatSortOrder)
    }

    var formatChooserPane: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(KroutonL10n.tr("Format Chooser"))
                        .font(.title2.bold())
                    Text(KroutonL10n.tr("Click any column header to sort, drag column dividers to resize width, or drag headers to rearrange columns (just like Finder List View)."))
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
                    ForEach(KroutonWorkflowFilterGroup.allCases) { group in
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

            Table(of: KroutonOpticalWorkflowSpec.self, selection: $selectedFormatIDs, sortOrder: $formatSortOrder, columnCustomization: $columnCustomization) {
                TableColumn(KroutonL10n.tr("Show"), value: \.visibilitySortKey) { fmt in
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

                TableColumn(KroutonL10n.tr("Format"), value: \.technicalName) { fmt in
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

                TableColumn(KroutonL10n.tr("Year"), value: \.launchYear) { fmt in
                    Text(fmt.launchYear)
                        .font(.system(size: 11, design: .monospaced))
                }
                .width(min: 50, ideal: 58, max: 80)
                .customizationID("col-year")

                TableColumn(KroutonL10n.tr("Capacity"), value: \.capacityGB) { fmt in
                    Text(fmt.capacity)
                        .font(.system(size: 11, design: .monospaced))
                }
                .width(min: 95, ideal: 115, max: 160)
                .customizationID("col-capacity")

                TableColumn(KroutonL10n.tr("Laser"), value: \.laserType) { fmt in
                    Text(fmt.laserType)
                        .font(.system(size: 11, design: .monospaced))
                }
                .width(min: 80, ideal: 95, max: 140)
                .customizationID("col-laser")

                TableColumn(KroutonL10n.tr("Platform / Plays On"), value: \.platform) { fmt in
                    Text(fmt.platform)
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
                .width(min: 140, ideal: 185, max: 300)
                .customizationID("col-platform")

                TableColumn(KroutonL10n.tr("Status"), value: \.deprecationStatus) { fmt in
                    Text(KroutonL10n.tr(fmt.deprecationStatus))
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(fmt.deprecationStatus == "Current" ? .green : .secondary)
                }
                .width(min: 85, ideal: 105, max: 150)
                .customizationID("col-status")

                TableColumn(KroutonL10n.tr("Standard / Mode"), value: \.bookOrFileSystem) { fmt in
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
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(store.enableSecondaryAccentUITints ? store.activeSecondaryAccent.opacity(0.30) : Color.primary.opacity(0.08), lineWidth: 1))
        }
    }
}
