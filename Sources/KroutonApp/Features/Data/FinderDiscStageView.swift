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
    @State var searchQuery: String = ""
    @State var showViewOptionsPopover: Bool = false
    @State var dragOffsets: [String: CGSize] = [:]

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
    var finderToolbar: some View {
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
    func tagSwatchStrip(for itemName: String) -> some View {
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
    var finderBackgroundLayer: some View {
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
    var activeViewCanvas: some View {
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
    var iconCanvasView: some View {
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
}
