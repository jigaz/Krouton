import DriveKit
import NetworkSpool
import OpticalCore
import SwiftUI
import UniformTypeIdentifiers

// MARK: - KroutonSettingsWindow & Live Search Index

enum KroutonSettingsCategory: String, CaseIterable, Identifiable, Sendable {
    case general = "General"
    case formatChooser = "Format Chooser"
    case discImageDepot = "Disc Image Depot"
    case audioVideo = "Audio & Video"
    case rippingTranscoding = "Ripping & Transcoding"
    case burnersNetwork = "Burners & Network"
    case labelsPrinters = "Labels & Printers"
    case notifications = "Notifications"
    case accessibilityLanguage = "Accessibility & Language"
    case storageAndReset = "Storage & Reset"

    var id: String { rawValue }

    var sfSymbol: String {
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
        case .storageAndReset: return "arrow.counterclockwise.circle"
        }
    }

    var searchKeywords: String {
        switch self {
        case .general:
            return "general icloud sync other macs theme appearance accent color multicolor harmony tint icon widget style dark light auto folder color sidebar language localization startup remember crash recovery units base-10 binary lba scratch disk cache purge permissions mmc fskit"
        case .formatChooser:
            return "format chooser table columns show visible iso-9660 joliet udf m-disc red book audio cd dvd blu-ray bdxl wii gamecube ps1 ps2 xbox laser capacity year"
        case .discImageDepot:
            return "disc image depot subscribed channels repositories rescue linux vintage mac console homebrew cover discs sha-256 pgp verify virtualization vm test-boot el torito uefi custom manifest feed url"
        case .audioVideo:
            return "audio video red book cd crossfade overlap bpm beat grid soundanalysis car-stereo safe mp3 id3v2.3 authoring menu first play videotoolbox 2-pass vbr fit-to-disc compression dvd-9 dvd-5 bd-50 bd-25 shrink preserve menus strip foreign dubs hardware software decoder codec matrix"
        case .rippingTranscoding:
            return "ripping transcoding optical drive sample read offset correction error recovery paranoia scratched sector retries accuraterip musicbrainz cue sheet log video extraction deinterlacing dolby atmos truehd dts-hd smart file track naming pattern token builder"
        case .burnersNetwork:
            return "burners network connected optical drives iokit discrecording bus rescan quick erase rw eject headless lan spool daemon 7420 mdns calibrate cache diagnostic bundle telemetry retention share auto-load next disc hands-free duplication countdown"
        case .labelsPrinters:
            return "labels printers saved disc label geometry tray offset presets epson ecotank et-8550 outer inner hub hole diameter mm automatic artwork lookup apple vision subject detection hole-avoidance musicbrainz itunes tvmaze gametdb tmdb fanart api key"
        case .notifications:
            return "notifications menu bar progress live status alerts macos banner audio sound effect telemetry feed test alert"
        case .accessibilityLanguage:
            return "accessibility language voiceover spoken hardware telemetry speech acoustic soundboard dsp lab display increase contrast differentiate without color reduce motion internationalization foreign languages locale english japanese german french spanish chinese korean"
        case .storageAndReset:
            return "storage reset defaults clear empty caches cache purge disk space session forget burn history journal servers pairing identity keychain start over factory"
        }
    }

    func matches(query: String) -> Bool {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !trimmed.isEmpty else { return true }
        let haystack = (rawValue + " " + searchKeywords).lowercased()
        return trimmed.split(separator: " ").allSatisfy { haystack.contains($0) }
    }
}

struct KroutonSettingsWindowView: View {
    var store: KroutonStateStore
    var driveManager: KroutonOpticalDriveBank
    var spoolClient: SpoolRemoteNodeClient = .shared
    @State var isShowingSpoolFileExporter: Bool = false
    @State var spoolExportDocument: SpoolPlainTextFileDocument = SpoolPlainTextFileDocument(text: "")
    @State var spoolExportDefaultFilename: String = "Krouton Burn Server Log.txt"
    @State var burnServerAddressDraft: String = ""
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

    init(store: KroutonStateStore, driveManager: KroutonOpticalDriveBank) {
        self.store = store
        self.driveManager = driveManager
    }

    var trimmedSearchQuery: String {
        searchText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var isSearchingSettings: Bool {
        !trimmedSearchQuery.isEmpty
    }

    var matchingCategories: [KroutonSettingsCategory] {
        guard isSearchingSettings else { return KroutonSettingsCategory.allCases }
        let direct = KroutonSettingsCategory.allCases.filter { $0.matches(query: trimmedSearchQuery) }
        if !direct.isEmpty { return direct }
        let formatHits = store.discFormats.contains {
            $0.technicalName.localizedCaseInsensitiveContains(trimmedSearchQuery)
            || $0.colloquialName.localizedCaseInsensitiveContains(trimmedSearchQuery)
            || $0.platform.localizedCaseInsensitiveContains(trimmedSearchQuery)
        }
        return formatHits ? [.formatChooser] : []
    }

    var body: some View {
        NavigationSplitView {
            VStack(spacing: 10) {
                HStack(spacing: 6) {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(.secondary)
                    TextField(KroutonL10n.tr("Search settings"), text: $searchText)
                        .textFieldStyle(.plain)
                    if isSearchingSettings {
                        Button {
                            searchText = ""
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(.secondary)
                        }
                        .buttonStyle(.plain)
                        .help("Clear settings search")
                    }
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
                            let isMatch = matchingCategories.contains(pane)
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
                                    if isSearchingSettings && isMatch {
                                        Circle()
                                            .fill(isSelected ? store.activeOnAccentText : store.activeAccent)
                                            .frame(width: 6, height: 6)
                                    }
                                }
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(
                                    RoundedRectangle(cornerRadius: 7)
                                        .fill(isSelected ? store.activeAccent : Color.clear)
                                )
                                .overlay(RoundedRectangle(cornerRadius: 7).stroke(store.a11yIncreaseContrast && isSelected ? Color.primary : Color.clear, lineWidth: 1.5))
                                .opacity(isSearchingSettings && !isMatch ? 0.35 : 1.0)
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
            .onChange(of: trimmedSearchQuery) { _, newQuery in
                guard !newQuery.isEmpty else { return }
                let matches = matchingCategories
                if let first = matches.first, !matches.contains(store.selectedSettingsPane) {
                    store.selectedSettingsPane = first
                }
            }
        } detail: {
            detailContentView
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .background(store.enableSecondaryAccentUITints ? store.activeAccent.opacity(0.11) : Color.clear)
                .background(Color.kroutonWindowSurface)
        }
        .frame(minWidth: 980, idealWidth: 1120, minHeight: 600, idealHeight: 720)
        .preferredColorScheme(store.resolvedColorScheme)
        .tint(store.activeAccent)
    }

    @ViewBuilder
    private var detailContentView: some View {
        if isSearchingSettings && matchingCategories.isEmpty {
            VStack(spacing: 10) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 32))
                    .foregroundStyle(.secondary)
                Text("No Settings Matching '\(trimmedSearchQuery)'")
                    .font(.headline)
                Text("Try searching for terms like Crossfade, BPM, AccurateRip, 7420, VoiceOver, or Scratch.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(24)
        } else if store.selectedSettingsPane == .formatChooser && (!isSearchingSettings || matchingCategories == [.formatChooser]) {
            formatChooserPane
                .padding(24)
        } else {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    if isSearchingSettings {
                        HStack(spacing: 8) {
                            Image(systemName: "sparkle.magnifyingglass")
                                .foregroundStyle(store.activeAccent)
                            Text("Search Results for '\(trimmedSearchQuery)' (\(matchingCategories.count) Categor\(matchingCategories.count == 1 ? "y" : "ies"))")
                                .font(.headline)
                            Spacer()
                            ForEach(matchingCategories) { cat in
                                pillToggleButton(title: cat.rawValue, sfSymbol: cat.sfSymbol, isSelected: store.selectedSettingsPane == cat) {
                                    store.selectedSettingsPane = cat
                                }
                            }
                        }
                        ForEach(matchingCategories) { cat in
                            if cat == .formatChooser {
                                formatChooserPane
                                    .frame(minHeight: 320)
                            } else {
                                VStack(alignment: .leading, spacing: 12) {
                                    Label(KroutonL10n.tr(cat.rawValue), systemImage: cat.sfSymbol)
                                        .font(.title3.bold())
                                        .foregroundStyle(store.activeAccent)
                                    paneView(for: cat)
                                }
                            }
                        }
                    } else {
                        Text(KroutonL10n.tr(store.selectedSettingsPane.rawValue))
                            .font(.title2.bold())
                        paneView(for: store.selectedSettingsPane)
                    }
                }
                .padding(24)
            }
        }
    }

    @ViewBuilder
    private func paneView(for category: KroutonSettingsCategory) -> some View {
        switch category {
        case .general: generalPane
        case .formatChooser: EmptyView()
        case .discImageDepot: discImageDepotPane
        case .audioVideo: audioVideoPane
        case .rippingTranscoding: rippingTranscodingPane
        case .burnersNetwork: burnersNetworkPane
        case .labelsPrinters: labelsPrintersPane
        case .notifications: notificationsPane
        case .accessibilityLanguage: accessibilityLanguagePane
        case .storageAndReset: KroutonStorageAndResetPaneView(store: store)
        }
    }
}
