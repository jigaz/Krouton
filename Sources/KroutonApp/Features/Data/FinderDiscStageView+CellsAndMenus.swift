import ImageIO
import ImageKit
import OpticalCore
import SwiftUI
import UniformTypeIdentifiers

// MARK: - Finder Stage Icon/List Cells, Thumbnails, Status Bar & Context Menus

extension KroutonFinderDiscStageView {
    @ViewBuilder
    func iconCell(entry: KroutonStagedFileEntry) -> some View {
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
    var listCanvasView: some View {
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
    func listRow(entry: KroutonStagedFileEntry, isEven: Bool) -> some View {
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
        if blueprint.showIconPreview, !entry.isDirectory,
           let src = CGImageSourceCreateWithURL(entry.url as CFURL, nil),
           let cgImg = CGImageSourceCreateImageAtIndex(src, 0, nil) {
            Image(decorative: cgImg, scale: 1.0)
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
    var finderStatusBar: some View {
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
    func itemContextMenu(for entry: KroutonStagedFileEntry) -> some View {
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
