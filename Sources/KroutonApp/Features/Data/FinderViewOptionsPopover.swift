import ImageKit
import OpticalCore
import SwiftUI
import UniformTypeIdentifiers

// MARK: - FinderViewOptionsPopover

struct KroutonFinderViewOptionsPopover: View {
    @ObservedObject var store: KroutonStateStore
    @Binding var blueprint: KroutonFinderLayoutBlueprint
    let onResetPositions: () -> Void
    @State private var showBackgroundImporter: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(KroutonL10n.tr(store.discVolumeTitle.isEmpty ? "Disc View Options" : store.discVolumeTitle))
                    .font(.headline)
                    .lineLimit(1)
                Spacer()
                Text("⌘J")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.primary.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: 4))
            }

            Divider()

            Toggle("Always open in \(blueprint.displayMode.rawValue.lowercased()) view", isOn: $blueprint.alwaysOpenInPreferredView)
                .toggleStyle(.checkbox)
                .font(.caption.bold())
            Toggle("Browse in \(blueprint.displayMode.rawValue.lowercased()) view", isOn: $blueprint.browseInPreferredView)
                .toggleStyle(.checkbox)
                .font(.caption)
                .padding(.leading, 14)

            Divider()

            sortAndGroupSection

            Divider()

            modeSpecificSection

            Divider()

            HStack(spacing: 8) {
                Button(KroutonL10n.tr("Reset Layout")) {
                    onResetPositions()
                }
                .buttonStyle(.bordered)
                .controlSize(.small)

                Spacer()

                Button(KroutonL10n.tr("Use as Defaults")) {
                    blueprint.alwaysOpenInPreferredView = true
                }
                .buttonStyle(.borderedProminent)
                .tint(store.activeAccent)
                .controlSize(.small)
            }
        }
        .padding(14)
        .frame(width: 288)
        .fileImporter(
            isPresented: $showBackgroundImporter,
            allowedContentTypes: [.image],
            allowsMultipleSelection: false
        ) { result in
            if case .success(let urls) = result, let url = urls.first {
                blueprint.background = .picture(path: url.path)
            }
        }
    }

    @ViewBuilder
    private var sortAndGroupSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            if blueprint.displayMode != .gallery {
                HStack {
                    Text("Group By:").font(.caption.bold()).frame(width: 68, alignment: .trailing)
                    Picker("", selection: $blueprint.groupBy) {
                        ForEach(KroutonFinderGroupKey.allCases, id: \.self) { key in
                            Text(key.rawValue).tag(key)
                        }
                    }
                    .labelsHidden()
                    .controlSize(.small)
                }
            }
            HStack {
                Text("Sort By:").font(.caption.bold()).frame(width: 68, alignment: .trailing)
                Picker("", selection: $blueprint.sortBy) {
                    ForEach(KroutonFinderSortKey.allCases, id: \.self) { key in
                        Text(key.rawValue).tag(key)
                    }
                }
                .labelsHidden()
                .controlSize(.small)
            }
        }
    }

    @ViewBuilder
    private var modeSpecificSection: some View {
        switch blueprint.displayMode {
        case .icon:
            iconModeOptions
        case .list:
            listModeOptions
        case .column:
            columnModeOptions
        case .gallery:
            galleryModeOptions
        }
    }

    @ViewBuilder
    private var iconModeOptions: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Icon size:").font(.caption.bold())
                Text("\(Int(blueprint.iconSize))×\(Int(blueprint.iconSize))")
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(.secondary)
                Spacer()
            }
            Slider(value: $blueprint.iconSize, in: 32...164, step: 4)

            HStack {
                Text("Grid spacing:").font(.caption.bold())
                Spacer()
                Text("\(Int(blueprint.gridSpacing)) pt")
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(.secondary)
            }
            Slider(value: $blueprint.gridSpacing, in: 24...100, step: 4)

            HStack {
                Text("Text size:").font(.caption.bold())
                Picker("", selection: $blueprint.textSize) {
                    ForEach([10, 11, 12, 13, 14, 16], id: \.self) { sz in
                        Text("\(sz)").tag(sz)
                    }
                }
                .labelsHidden()
                .frame(width: 68)
                .controlSize(.small)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("Label position:").font(.caption.bold())
                Picker("", selection: $blueprint.labelPosition) {
                    ForEach(KroutonFinderLabelPosition.allCases, id: \.self) { pos in
                        Text(pos.rawValue).tag(pos)
                    }
                }
                .pickerStyle(.radioGroup)
                .horizontalRadioGroupLayout()
                .labelsHidden()
            }

            Toggle(KroutonL10n.tr("Show item info"), isOn: $blueprint.showItemInfo).toggleStyle(.checkbox).font(.caption)
            Toggle(KroutonL10n.tr("Show icon preview"), isOn: $blueprint.showIconPreview).toggleStyle(.checkbox).font(.caption)

            Divider()
            backgroundPickerSection
        }
    }

    @ViewBuilder
    private var backgroundPickerSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Background:").font(.caption.bold())
            HStack(spacing: 8) {
                Button(KroutonL10n.tr("Default")) { blueprint.background = .defaultSurface }
                    .buttonStyle(.bordered).controlSize(.mini)
                ColorPicker("", selection: Binding(
                    get: {
                        if case .solidColor(let r, let g, let b) = blueprint.background {
                            return Color(red: r, green: g, blue: b)
                        }
                        return Color(red: 0.13, green: 0.17, blue: 0.24)
                    },
                    set: { newColor in
                        if let comps = newColor.cgColor?.components, comps.count >= 3 {
                            blueprint.background = .solidColor(red: Double(comps[0]), green: Double(comps[1]), blue: Double(comps[2]))
                        }
                    }
                ))
                .labelsHidden()
                Button(KroutonL10n.tr("Picture…")) { showBackgroundImporter = true }
                    .buttonStyle(.bordered).controlSize(.mini)
            }
        }
    }

    @ViewBuilder
    private var listModeOptions: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text("Show Columns:").font(.caption.bold())
            Toggle(KroutonL10n.tr("Date Modified"), isOn: $blueprint.showDateModified).toggleStyle(.checkbox).font(.caption)
            Toggle(KroutonL10n.tr("Date Created"), isOn: $blueprint.showDateCreated).toggleStyle(.checkbox).font(.caption)
            Toggle(KroutonL10n.tr("Size"), isOn: $blueprint.showSize).toggleStyle(.checkbox).font(.caption)
            Toggle(KroutonL10n.tr("Kind"), isOn: $blueprint.showKind).toggleStyle(.checkbox).font(.caption)
            Toggle(KroutonL10n.tr("Comments"), isOn: $blueprint.showComments).toggleStyle(.checkbox).font(.caption)
            Toggle(KroutonL10n.tr("Tags"), isOn: $blueprint.showTags).toggleStyle(.checkbox).font(.caption)
            Divider()
            Toggle(KroutonL10n.tr("Use relative dates"), isOn: $blueprint.useRelativeDates).toggleStyle(.checkbox).font(.caption)
            Toggle(KroutonL10n.tr("Calculate all sizes"), isOn: $blueprint.calculateAllSizes).toggleStyle(.checkbox).font(.caption)
            Toggle(KroutonL10n.tr("Show icon preview"), isOn: $blueprint.showIconPreview).toggleStyle(.checkbox).font(.caption)
        }
    }

    @ViewBuilder
    private var columnModeOptions: some View {
        VStack(alignment: .leading, spacing: 6) {
            Toggle(KroutonL10n.tr("Show icons"), isOn: $blueprint.showIconsInColumnView).toggleStyle(.checkbox).font(.caption)
            Toggle(KroutonL10n.tr("Show icon preview"), isOn: $blueprint.showIconPreview).toggleStyle(.checkbox).font(.caption)
            Toggle(KroutonL10n.tr("Show preview column"), isOn: $blueprint.showPreviewColumn).toggleStyle(.checkbox).font(.caption)
            Toggle(KroutonL10n.tr("Resize columns to fit filenames"), isOn: $blueprint.resizeColumnsToFitFilenames).toggleStyle(.checkbox).font(.caption)
        }
    }

    @ViewBuilder
    private var galleryModeOptions: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Thumbnail size:").font(.caption.bold())
            Picker("", selection: $blueprint.galleryThumbnailSize) {
                Text("Small").tag(KroutonFinderGalleryThumbSize.small)
                Text("Medium").tag(KroutonFinderGalleryThumbSize.medium)
                Text("Large").tag(KroutonFinderGalleryThumbSize.large)
            }
            .pickerStyle(.segmented)
            .labelsHidden()

            Toggle(KroutonL10n.tr("Show preview column"), isOn: $blueprint.showPreviewColumn).toggleStyle(.checkbox).font(.caption)
            Toggle(KroutonL10n.tr("Show icon preview"), isOn: $blueprint.showIconPreview).toggleStyle(.checkbox).font(.caption)
            Toggle(KroutonL10n.tr("Show filename"), isOn: $blueprint.showGalleryFilename).toggleStyle(.checkbox).font(.caption)
        }
    }
}
