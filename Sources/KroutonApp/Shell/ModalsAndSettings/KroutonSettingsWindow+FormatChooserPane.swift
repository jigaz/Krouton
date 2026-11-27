import NetworkSpool
import OpticalCore
import SwiftUI
import UniformTypeIdentifiers

// MARK: - Settings Window: Format Chooser Table Pane

extension KroutonSettingsWindowView {
    var filteredAndSortedFormats: [KroutonOpticalWorkflowSpec] {
        let q = trimmedSearchQuery.lowercased()
        let filtered = store.discFormats.filter { fmt in
            let groupMatch: Bool = {
                switch formatFilter {
                case .all: return true
                case .enabled: return fmt.showInTaskChooser
                default: return fmt.filterGroup == formatFilter
                }
            }()
            guard groupMatch else { return false }
            guard !q.isEmpty else { return true }
            let hay = "\(fmt.technicalName) \(fmt.colloquialName) \(fmt.platform) \(fmt.bookOrFileSystem) \(fmt.laserType)".lowercased()
            return q.split(separator: " ").allSatisfy { hay.contains($0) }
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
