import DriveKit
import NetworkSpool
import OpticalCore
import SwiftUI
import UniformTypeIdentifiers

// MARK: - KroutonSettingsWindow

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
        }
    }
}

struct KroutonSettingsWindowView: View {
    var store: KroutonStateStore
    var driveManager: KroutonOpticalDriveBank
    var spoolClient: SpoolRemoteNodeClient = .shared
    @State var isShowingSpoolFileExporter: Bool = false
    @State var isShowingScratchFolderImporter: Bool = false
    @State var spoolExportDocument: SpoolPlainTextFileDocument = SpoolPlainTextFileDocument(text: "")
    @State var spoolExportDefaultFilename: String = "Spool_Export.log"
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

    init(store: KroutonStateStore, driveManager: KroutonOpticalDriveBank) {
        self.store = store
        self.driveManager = driveManager
    }

    var body: some View {
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

}
