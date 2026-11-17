import ImageKit
import OpticalCore
import SwiftUI
import UniformTypeIdentifiers

struct KroutonFinderDiscStageView: View {
    @ObservedObject var store: KroutonStateStore
    @Binding var blueprint: KroutonFinderLayoutBlueprint
    @Binding var isDropTargeted: Bool
    let onHandleFinderDrop: ([NSItemProvider]) -> Bool
    let onInspectLBA: () -> Void

    @State var selectedItemID: UUID?
    @State var selectedFolderURL: URL?
    @State private var searchQuery: String = ""
    @State private var showViewOptionsPopover: Bool = false
    @State private var dragOffsets: [String: CGSize] = [:]

    var filteredEntries: [KroutonStagedFileEntry] {
        let base = store.stagedFiles.filter { entry in
            searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            || entry.name.localizedCaseInsensitiveContains(searchQuery)
        }
        return base.sorted { a, b in
            let asc = blueprint.sortAscending
            switch blueprint.sortBy {
            case .name:
                return asc ? a.name.localizedStandardCompare(b.name) == .orderedAscending : a.name.localizedStandardCompare(b.name) == .orderedDescending
            case .size:
                return asc ? a.byteSize < b.byteSize : a.byteSize > b.byteSize
            case .kind:
                let ka = a.isDirectory ? "Folder" : a.url.pathExtension
                let kb = b.isDirectory ? "Folder" : b.url.pathExtension
                return asc ? ka.localizedStandardCompare(kb) == .orderedAscending : ka.localizedStandardCompare(kb) == .orderedDescending
            case .dateModified, .dateCreated:
                return asc ? a.name < b.name : a.name > b.name
            case .tags:
                let ta = annotation(for: a.name).tagColor.rawValue
                let tb = annotation(for: b.name).tagColor.rawValue
                return asc ? ta < tb : ta > tb
            }
        }
    }

    var selectedEntry: KroutonStagedFileEntry? {
        if let id = selectedItemID, let match = filteredEntries.first(where: { $0.id == id }) {
            return match
        }
        return filteredEntries.first
    }

    var body: some View {
        VStack(spacing: 0) {
            finderToolbar
            Divider()
            ZStack {
                finderBackgroundLayer
                if store.stagedFiles.isEmpty {
                    KroutonEmptyDropZoneView(
                        store: store,
                        isDropTargeted: isDropTargeted,
                        sfSymbol: "macwindow.on.rectangle",
                        symbolSize: 34,
                        headline: "Drop Files or Folders to Author a Custom Finder Disc Layout",
                        subtitle: "Arrange icons, assign Finder color tags, write Spotlight comments, or switch between Icon, List, Column, and Gallery views. Krouton writes a real .DS_Store into your hybrid image."
                    )
                } else {
                    activeViewCanvas
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .onDrop(of: [.fileURL], isTargeted: $isDropTargeted) { providers in
                onHandleFinderDrop(providers)
            }
            Divider()
            finderStatusBar
        }
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .strokeBorder(isDropTargeted ? store.activeAccent : Color.primary.opacity(0.10), lineWidth: isDropTargeted ? 2.5 : 1.0)
        )
    }

    @ViewBuilder
    private var finderToolbar: some View {
        HStack(spacing: 8) {
            Picker("", selection: $blueprint.displayMode) {
                ForEach(KroutonFinderDisplayMode.allCases, id: \.self) { mode in
                    Image(systemName: mode.sfSymbol)
                        .help("\(mode.rawValue) View")
                        .tag(mode)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .frame(width: 148)

            Menu {
                ForEach(KroutonFinderSortKey.allCases, id: \.self) { key in
                    Button {
                        if blueprint.sortBy == key {
                            blueprint.sortAscending.toggle()
                        } else {
                            blueprint.sortBy = key
                            blueprint.sortAscending = true
                        }
                    } label: {
                        HStack {
                            Text(key.rawValue)
                            if blueprint.sortBy == key {
                                Image(systemName: blueprint.sortAscending ? "chevron.up" : "chevron.down")
                            }
                        }
                    }
                }
            } label: {
                Label(blueprint.sortBy.rawValue, systemImage: "arrow.up.arrow.down")
                    .font(.system(size: 10.5, weight: .semibold))
            }
            .menuStyle(.borderlessButton)
            .fixedSize()

            if let current = selectedEntry {
                tagSwatchStrip(for: current.name)
            }

            Spacer(minLength: 4)

            HStack(spacing: 4) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
                TextField("Search", text: $searchQuery)
                    .textFieldStyle(.plain)
                    .font(.system(size: 11))
                    .frame(width: 96)
            }
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(Color.primary.opacity(0.07))
            .clipShape(RoundedRectangle(cornerRadius: 6))

            Button {
                showViewOptionsPopover.toggle()
            } label: {
                Label("View Options", systemImage: "slider.horizontal.3")
                    .font(.system(size: 10.5, weight: .semibold))
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            .keyboardShortcut("j", modifiers: .command)
            .popover(isPresented: $showViewOptionsPopover, arrowEdge: .bottom) {
                KroutonFinderViewOptionsPopover(store: store, blueprint: $blueprint) {
                    dragOffsets.removeAll()
                    for key in blueprint.itemAnnotations.keys {
                        blueprint.itemAnnotations[key]?.iconX = nil
                        blueprint.itemAnnotations[key]?.iconY = nil
                    }
                }
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Color.black.opacity(0.24))
    }

    @ViewBuilder
    private func tagSwatchStrip(for itemName: String) -> some View {
        let currentTag = annotation(for: itemName).tagColor
        HStack(spacing: 4) {
            ForEach([KroutonFinderTagColor.red, .orange, .yellow, .green, .blue, .purple, .gray], id: \.self) { tag in
                Button {
                    var ann = annotation(for: itemName)
                    ann.tagColor = (ann.tagColor == tag) ? .none : tag
                    blueprint.itemAnnotations[itemName] = ann
                } label: {
                    Circle()
                        .fill(swiftColor(for: tag))
                        .frame(width: 10, height: 10)
                        .overlay(
                            Circle().stroke(Color.white, lineWidth: currentTag == tag ? 1.5 : 0)
                        )
                }
                .buttonStyle(.plain)
                .help("Tag \(itemName) as \(tag.rawValue)")
            }
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 3)
        .background(Color.primary.opacity(0.06))
        .clipShape(Capsule())
    }

    @ViewBuilder
    private var finderBackgroundLayer: some View {
        switch blueprint.background {
        case .defaultSurface:
            Color.kroutonControlSurface
        case .solidColor(let r, let g, let b):
            Color(red: r, green: g, blue: b)
        case .picture(let path):
            if let nsImg = NSImage(contentsOfFile: path) {
                Image(nsImage: nsImg)
                    .resizable()
                    .scaledToFill()
                    .overlay(Color.black.opacity(0.22))
            } else {
                Color.kroutonControlSurface
            }
        }
    }

    @ViewBuilder
    private var activeViewCanvas: some View {
        switch blueprint.displayMode {
        case .icon:
            iconCanvasView
        case .list:
            listCanvasView
        case .column:
            columnCanvasView
        case .gallery:
            galleryCanvasView
        }
    }

    @ViewBuilder
    private var iconCanvasView: some View {
        let minColWidth = max(110, blueprint.iconSize + blueprint.gridSpacing * 0.65)
        ScrollView {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: minColWidth), spacing: blueprint.gridSpacing * 0.45)], spacing: blueprint.gridSpacing * 0.45) {
                ForEach(filteredEntries) { entry in
                    iconCell(entry: entry)
                        .offset(dragOffsets[entry.name] ?? .zero)
                        .gesture(
                            DragGesture()
                                .onChanged { value in
                                    dragOffsets[entry.name] = value.translation
                                }
                                .onEnded { value in
                                    var ann = annotation(for: entry.name)
                                    ann.iconX = max(32, (ann.iconX ?? 96) + Int(value.translation.width))
                                    ann.iconY = max(32, (ann.iconY ?? 96) + Int(value.translation.height))
                                    blueprint.itemAnnotations[entry.name] = ann
                                }
                        )
                        .onTapGesture {
                            selectedItemID = entry.id
                        }
                        .contextMenu { itemContextMenu(for: entry) }
                }
            }
            .padding(20)
        }
    }

    @ViewBuilder
    private func iconCell(entry: KroutonStagedFileEntry) -> some View {
        let isSelected = (selectedEntry?.id == entry.id)
        let ann = annotation(for: entry.name)
        let iconDim = min(max(blueprint.iconSize * 0.68, 28), 116)

        if blueprint.labelPosition == .right {
            HStack(spacing: 10) {
                itemThumbnail(for: entry, size: iconDim)
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 4) {
                        if ann.tagColor != .none {
                            Circle().fill(swiftColor(for: ann.tagColor)).frame(width: 8, height: 8)
                        }
                        Text(entry.name)
                            .font(.system(size: CGFloat(blueprint.textSize), weight: .semibold))
                            .lineLimit(2)
                    }
                    if blueprint.showItemInfo {
                        Text(ByteCountFormatter.string(fromByteCount: entry.byteSize, countStyle: .file))
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer(minLength: 0)
            }
            .padding(8)
            .background(isSelected ? store.activeAccent.opacity(0.24) : Color.black.opacity(0.18))
            .clipShape(RoundedRectangle(cornerRadius: 8))
        } else {
            VStack(spacing: 6) {
                itemThumbnail(for: entry, size: iconDim)
                    .padding(6)
                    .background(isSelected ? store.activeAccent.opacity(0.25) : Color.clear)
                    .clipShape(RoundedRectangle(cornerRadius: 8))

                HStack(spacing: 4) {
                    if ann.tagColor != .none {
                        Circle().fill(swiftColor(for: ann.tagColor)).frame(width: 8, height: 8)
                    }
                    Text(entry.name)
                        .font(.system(size: CGFloat(blueprint.textSize), weight: .semibold))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 1)
                        .background(isSelected ? store.activeAccent : Color.clear)
                        .foregroundStyle(isSelected ? store.activeOnAccentText : .primary)
                        .clipShape(RoundedRectangle(cornerRadius: 4))
                        .lineLimit(2)
                        .multilineTextAlignment(.center)
                }

                if blueprint.showItemInfo {
                    Text(entry.isDirectory ? "\(entry.itemCount) items" : ByteCountFormatter.string(fromByteCount: entry.byteSize, countStyle: .file))
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundStyle(.secondary)
                }
            }
            .padding(6)
        }
    }

    @ViewBuilder
    private var listCanvasView: some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                Text("Name").font(.system(size: 10, weight: .bold)).foregroundStyle(.secondary).frame(maxWidth: .infinity, alignment: .leading)
                if blueprint.showSize {
                    Text("Size").font(.system(size: 10, weight: .bold)).foregroundStyle(.secondary).frame(width: 72, alignment: .trailing)
                }
                if blueprint.showKind {
                    Text("Kind").font(.system(size: 10, weight: .bold)).foregroundStyle(.secondary).frame(width: 88, alignment: .leading)
                }
                if blueprint.showTags {
                    Text("Tags").font(.system(size: 10, weight: .bold)).foregroundStyle(.secondary).frame(width: 64, alignment: .leading)
                }
                if blueprint.showComments {
                    Text("Comments").font(.system(size: 10, weight: .bold)).foregroundStyle(.secondary).frame(width: 140, alignment: .leading)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Color.black.opacity(0.22))

            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(Array(filteredEntries.enumerated()), id: \.element.id) { idx, entry in
                        listRow(entry: entry, isEven: idx.isMultiple(of: 2))
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func listRow(entry: KroutonStagedFileEntry, isEven: Bool) -> some View {
        let isSelected = (selectedEntry?.id == entry.id)
        let ann = annotation(for: entry.name)

        HStack(spacing: 10) {
            HStack(spacing: 6) {
                itemThumbnail(for: entry, size: 16)
                Text(entry.name)
                    .font(.system(size: CGFloat(blueprint.textSize), weight: .medium))
                    .lineLimit(1)
                Spacer(minLength: 4)
                if ann.tagColor != .none {
                    Circle().fill(swiftColor(for: ann.tagColor)).frame(width: 8, height: 8)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            if blueprint.showSize {
                Text(ByteCountFormatter.string(fromByteCount: entry.byteSize, countStyle: .file))
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .frame(width: 72, alignment: .trailing)
            }
            if blueprint.showKind {
                Text(entry.isDirectory ? "Folder" : (entry.url.pathExtension.isEmpty ? "Document" : "\(entry.url.pathExtension.uppercased()) file"))
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .frame(width: 88, alignment: .leading)
            }
            if blueprint.showTags {
                Text(ann.tagColor == .none ? "—" : ann.tagColor.rawValue)
                    .font(.system(size: 10.5))
                    .foregroundStyle(ann.tagColor == .none ? .secondary : swiftColor(for: ann.tagColor))
                    .frame(width: 64, alignment: .leading)
            }
            if blueprint.showComments {
                TextField("Add comment…", text: Binding(
                    get: { annotation(for: entry.name).spotlightComment },
                    set: { newVal in
                        var updated = annotation(for: entry.name)
                        updated.spotlightComment = newVal
                        blueprint.itemAnnotations[entry.name] = updated
                    }
                ))
                .textFieldStyle(.plain)
                .font(.system(size: 10.5))
                .frame(width: 140, alignment: .leading)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 5)
        .background(isSelected ? store.activeAccent.opacity(0.28) : (isEven ? Color.white.opacity(0.025) : Color.clear))
        .contentShape(Rectangle())
        .onTapGesture {
            selectedItemID = entry.id
            if entry.isDirectory { selectedFolderURL = entry.url }
        }
        .contextMenu { itemContextMenu(for: entry) }
    }

    @ViewBuilder
    func itemThumbnail(for entry: KroutonStagedFileEntry, size: CGFloat) -> some View {
        if blueprint.showIconPreview, !entry.isDirectory, let nsImg = NSImage(contentsOf: entry.url) {
            Image(nsImage: nsImg)
                .resizable()
                .scaledToFit()
                .frame(width: size, height: size)
                .clipShape(RoundedRectangle(cornerRadius: 4))
        } else {
            Image(systemName: entry.isDirectory ? "folder.fill" : "doc.fill")
                .font(.system(size: size * 0.78))
                .foregroundStyle(entry.isDirectory ? store.resolvedFolderIconColor : store.activeAccent)
                .frame(width: size, height: size)
        }
    }

    @ViewBuilder
    private var finderStatusBar: some View {
        let totalBytes = filteredEntries.reduce(Int64(0)) { $0 + $1.byteSize }
        HStack {
            Spacer()
            Text("\(filteredEntries.count) items, \(ByteCountFormatter.string(fromByteCount: totalBytes, countStyle: .file)) staged • .DS_Store \(blueprint.displayMode.fourCC) active")
                .font(.system(size: 10.5))
                .foregroundStyle(.secondary)
            Spacer()
        }
        .padding(.vertical, 4)
        .background(Color.black.opacity(0.22))
    }

    @ViewBuilder
    private func itemContextMenu(for entry: KroutonStagedFileEntry) -> some View {
        Button(KroutonL10n.tr("Reveal in Finder")) { KroutonOSDesktopBridge.revealURLsInFinder([entry.url]) }
        Button(KroutonL10n.tr("Inspect Hybrid ISO/UDF LBA Layout")) { onInspectLBA() }
        Divider()
        Button(role: .destructive) { store.removeStagedFile(id: entry.id) } label: { Text("Remove from Stage") }
    }

    func annotation(for name: String) -> KroutonFinderItemAnnotation {
        blueprint.itemAnnotations[name] ?? KroutonFinderItemAnnotation()
    }

    func swiftColor(for tag: KroutonFinderTagColor) -> Color {
        switch tag {
        case .none: return .clear
        case .red: return .red
        case .orange: return .orange
        case .yellow: return .yellow
        case .green: return .green
        case .blue: return .blue
        case .purple: return .purple
        case .gray: return .gray
        }
    }
}
