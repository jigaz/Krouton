import AudioKit
import Foundation
import OpticalCore
import SwiftUI
import UniformTypeIdentifiers

/// CD-Extra's second session: the files a computer sees after the audio. CD players play the
/// tracks above and never read this part.
struct CDExtraDataSessionView: View {
    var store: KroutonStateStore
    @State private var isImporting = false

    private var dataBytes: Int64 { store.cdExtraDataFiles.reduce(0) { $0 + $1.byteSize } }

    private var roomLine: String {
        let audioFrames = store.audioController.project.totalFrames ?? 0
        let needed = KroutonCDExtraLayout.framesNeeded(audioFrames: audioFrames, dataBytes: dataBytes)
        let minutes = Double(needed) / 75 / 60
        let size = ByteCountFormatter.string(fromByteCount: dataBytes, countStyle: .file)
        return String(format: "%@ of data · %.1f of 80 minutes with the audio and the second session (about 3 minutes)", size, minutes)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // MARK: - Header
            HStack(spacing: 8) {
                Image(systemName: "externaldrive.fill.badge.plus")
                    .foregroundStyle(store.activeAccent)
                    .accessibilityHidden(true)
                Text(KroutonL10n.tr("Data Session"))
                    .font(.headline)
                Spacer()
                Button(KroutonL10n.tr("Add Files…")) { isImporting = true }
                    .controlSize(.small)
            }
            Text(KroutonL10n.tr("Computers open these files from the disc; CD players play the tracks above and skip them. A CDPLUS folder is added for you."))
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            // MARK: - File list
            if store.cdExtraDataFiles.isEmpty {
                Text(KroutonL10n.tr("No files yet. Add the videos, lyrics or artwork for the data session."))
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .padding(.vertical, 6)
            } else {
                ForEach(store.cdExtraDataFiles) { entry in
                    HStack(spacing: 6) {
                        Image(systemName: entry.isDirectory ? "folder.fill" : "doc.fill")
                            .foregroundStyle(.secondary)
                            .accessibilityHidden(true)
                        Text(entry.name).lineLimit(1).truncationMode(.middle)
                        Spacer()
                        Text(ByteCountFormatter.string(fromByteCount: entry.byteSize, countStyle: .file))
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(.secondary)
                        Button {
                            remove(entry)
                        } label: {
                            Image(systemName: "minus.circle")
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(KroutonL10n.tr("Remove \(entry.name)"))
                        .help(KroutonL10n.tr("Remove from the data session"))
                    }
                    .font(.caption)
                    .contextMenu {
                        Button(KroutonL10n.tr("Remove from Data Session")) { remove(entry) }
                    }
                }
                Text(roomLine)
                    .font(.caption2.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 12).fill(Color.kroutonControlSurface))
        .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(Color.primary.opacity(0.1)))
        .fileImporter(isPresented: $isImporting, allowedContentTypes: [.item, .folder], allowsMultipleSelection: true) { result in
            guard case .success(let urls) = result else { return }
            store.addCDExtraDataFiles(urls)
        }
    }

    private func remove(_ entry: KroutonStagedFileEntry) {
        store.cdExtraDataFiles.removeAll { $0.id == entry.id }
    }
}
