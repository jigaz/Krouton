import ImageKit
import OpticalCore
import SwiftUI

extension KroutonFinderDiscStageView {
    @ViewBuilder
    var columnCanvasView: some View {
        HStack(spacing: 0) {
            ScrollView {
                LazyVStack(spacing: 1) {
                    ForEach(filteredEntries) { entry in
                        let isSel = (selectedEntry?.id == entry.id)
                        HStack(spacing: 6) {
                            if blueprint.showIconsInColumnView {
                                itemThumbnail(for: entry, size: 15)
                            }
                            Text(entry.name)
                                .font(.system(size: CGFloat(blueprint.textSize)))
                                .lineLimit(1)
                            Spacer()
                            if annotation(for: entry.name).tagColor != .none {
                                Circle().fill(swiftColor(for: annotation(for: entry.name).tagColor)).frame(width: 7, height: 7)
                            }
                            if entry.isDirectory {
                                Image(systemName: "chevron.right").font(.system(size: 9)).foregroundStyle(.secondary)
                            }
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(isSel ? store.activeAccent.opacity(0.30) : Color.clear)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            selectedItemID = entry.id
                            selectedFolderURL = entry.isDirectory ? entry.url : nil
                        }
                    }
                }
                .padding(.vertical, 6)
            }
            .frame(width: blueprint.resizeColumnsToFitFilenames ? 225 : 185)

            Divider()

            if let folderURL = selectedFolderURL,
               let subItems = try? FileManager.default.contentsOfDirectory(at: folderURL, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles]) {
                ScrollView {
                    LazyVStack(spacing: 1) {
                        ForEach(subItems.prefix(80), id: \.path) { child in
                            HStack(spacing: 6) {
                                Image(systemName: child.hasDirectoryPath ? "folder.fill" : "doc.fill")
                                    .font(.system(size: 12))
                                    .foregroundStyle(child.hasDirectoryPath ? store.resolvedFolderIconColor : store.activeAccent)
                                Text(child.lastPathComponent)
                                    .font(.system(size: 12))
                                    .lineLimit(1)
                                Spacer()
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                        }
                    }
                    .padding(.vertical, 6)
                }
                .frame(width: 195)
                Divider()
            }

            if blueprint.showPreviewColumn, let entry = selectedEntry {
                previewInspectorPane(for: entry)
            } else {
                Spacer(minLength: 0)
            }
        }
    }

    @ViewBuilder
    var galleryCanvasView: some View {
        HStack(spacing: 0) {
            VStack(spacing: 0) {
                if let entry = selectedEntry {
                    VStack(spacing: 10) {
                        Spacer(minLength: 8)
                        itemThumbnail(for: entry, size: 148)
                        if blueprint.showGalleryFilename {
                            Text(entry.name)
                                .font(.headline)
                                .lineLimit(1)
                        }
                        Spacer(minLength: 8)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }

                Divider()

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(filteredEntries) { entry in
                            let isSel = (selectedEntry?.id == entry.id)
                            let thumbH = CGFloat(blueprint.galleryThumbnailSize.pixelHeight)
                            VStack(spacing: 4) {
                                itemThumbnail(for: entry, size: thumbH)
                                    .padding(4)
                                    .background(isSel ? store.activeAccent.opacity(0.30) : Color.black.opacity(0.20))
                                    .clipShape(RoundedRectangle(cornerRadius: 6))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 6)
                                            .stroke(isSel ? store.activeAccent : Color.clear, lineWidth: 1.5)
                                    )
                            }
                            .onTapGesture { selectedItemID = entry.id }
                        }
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                }
                .background(Color.black.opacity(0.20))
            }

            if blueprint.showPreviewColumn, let entry = selectedEntry {
                Divider()
                previewInspectorPane(for: entry)
            }
        }
    }

    @ViewBuilder
    func previewInspectorPane(for entry: KroutonStagedFileEntry) -> some View {
        let ann = annotation(for: entry.name)
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Spacer()
                itemThumbnail(for: entry, size: 84)
                Spacer()
            }
            Text(entry.name)
                .font(.system(size: 13, weight: .bold))
                .lineLimit(2)
            Text("\(entry.isDirectory ? "Folder" : "File") • \(ByteCountFormatter.string(fromByteCount: entry.byteSize, countStyle: .file))")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)

            Divider()

            Group {
                infoLine("LBA Sectors", "\(entry.sectorsLBA) sectors")
                infoLine("Permissions", entry.posixPermissions)
                infoLine("Finder Tag", ann.tagColor.rawValue)
            }

            Text("Spotlight Comment")
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(.secondary)
            TextField("Add Finder comment…", text: Binding(
                get: { annotation(for: entry.name).spotlightComment },
                set: { newVal in
                    var updated = annotation(for: entry.name)
                    updated.spotlightComment = newVal
                    blueprint.itemAnnotations[entry.name] = updated
                }
            ))
            .textFieldStyle(.roundedBorder)
            .font(.system(size: 11))

            Spacer(minLength: 0)
        }
        .padding(12)
        .frame(width: 215)
        .background(Color.black.opacity(0.16))
    }

    @ViewBuilder
    func infoLine(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label).font(.system(size: 10.5)).foregroundStyle(.secondary)
            Spacer()
            Text(value).font(.system(size: 10.5, weight: .semibold, design: .monospaced))
        }
    }

}
