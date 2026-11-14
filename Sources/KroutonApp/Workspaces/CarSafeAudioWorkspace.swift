import SwiftUI
import UniformTypeIdentifiers
import Foundation
import OpticalDough

struct KroutonCarSafeAudioWorkspaceView: View {
    @ObservedObject var store: KroutonStateStore
    let spec: KroutonRecipeSpec
    let isCenterWorkspaceNarrow: Bool
    @Binding var isDropTargeted: Bool
    let onHandleFinderDrop: ([NSItemProvider]) -> Bool

    @State private var carSafeZeroPadNumbers: Bool = true
    @State private var carSafeStripAppleDouble: Bool = true
    @State private var carSafeEnforceID3v23: Bool = true
    @State private var carSafeGenerateM3U: Bool = true
    @State private var carSafeTranscodeTarget: String = "320 kbps CBR MP3 (Universal Car Deck)"

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            KroutonMasteringDeckCard(store: store) {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 8) {
                        Image(systemName: "car.rear.waves.up.fill").foregroundStyle(store.activeAccent)
                        Text(isCenterWorkspaceNarrow ? "CAR-SAFE ISO9660 + JOLIET" : "CAR-SAFE ISO9660 + JOLIET AUDIO ENGINE (OEM HEAD-UNIT SAFE)")
                            .font(.system(size: 10, weight: .heavy, design: .monospaced)).foregroundStyle(.secondary).lineLimit(1)
                        Spacer(minLength: 4)
                        Text("AppleDouble Purged").font(.system(size: 9, weight: .bold, design: .monospaced)).foregroundStyle(.green)
                    }
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 230), alignment: .leading)], spacing: 8) {
                        HStack(spacing: 6) {
                            Text("Disc Title:").font(.caption.bold())
                            TextField("CAR_MP3_DISC", text: $store.discVolumeTitle).textFieldStyle(.roundedBorder)
                        }
                        HStack(spacing: 6) {
                            Text("Profile:").font(.caption.bold())
                            Picker("", selection: $carSafeTranscodeTarget) {
                                Text("320 kbps CBR MP3 (Car Safe)").tag("320 kbps CBR MP3 (Universal Car Deck)")
                                Text("192 kbps CBR MP3 (12-Hr Trip)").tag("192 kbps CBR MP3 (Extended 12-Hour Roadtrip)")
                                Text("16-Bit FLAC / WAV Direct").tag("16-Bit FLAC / WAV Passthrough (Modern Head Units)")
                            }.labelsHidden().font(.caption)
                        }
                    }
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 225), alignment: .leading)], spacing: 6) {
                        Toggle("Zero-Pad Prefixes (001 - Title.mp3)", isOn: $carSafeZeroPadNumbers).toggleStyle(.checkbox).font(.caption.bold())
                        Toggle("Strip macOS .DS_Store & ._* Forks", isOn: $carSafeStripAppleDouble).toggleStyle(.checkbox).font(.caption.bold())
                        Toggle("Enforce ID3v2.3 ISO-8859-1 Tags", isOn: $carSafeEnforceID3v23).toggleStyle(.checkbox).font(.caption)
                        Toggle("Write Root .M3U Playlist", isOn: $carSafeGenerateM3U).toggleStyle(.checkbox).font(.caption)
                    }
                }
            }

            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color.kroutonControlSurface)
                    .overlay(
                        RoundedRectangle(cornerRadius: 10).strokeBorder(
                            isDropTargeted ? store.activeAccent : Color.primary.opacity(0.08),
                            style: StrokeStyle(lineWidth: isDropTargeted ? 2.5 : 1.0, dash: store.stagedFiles.isEmpty ? [6, 4] : [])
                        )
                    )

                if store.stagedFiles.isEmpty {
                    KroutonEmptyDropZoneView(
                        store: store,
                        isDropTargeted: isDropTargeted,
                        sfSymbol: "music.note.list",
                        headline: "Drop MP3, FLAC, M4A, or Album Folders to Build a Car-Safe Audio Disc",
                        subtitle: "Automatically numbers files in raw FAT/ISO directory order and strips hidden macOS resource forks so car stereos never freeze."
                    )
                } else {
                    ScrollView {
                        VStack(spacing: 0) {
                            ForEach(Array(store.stagedFiles.enumerated()), id: \.element.id) { idx, entry in
                                let baseName = entry.url.deletingPathExtension().lastPathComponent
                                let displayFile = carSafeZeroPadNumbers ? String(format: "%03d - %@.mp3", idx + 1, String(baseName.prefix(48))) : "\(baseName).mp3"
                                HStack(spacing: 10) {
                                    Text(String(format: "#%03d", idx + 1)).font(.system(size: 11, weight: .bold, design: .monospaced)).foregroundStyle(store.activeAccent).frame(width: 44, alignment: .leading)
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(displayFile).font(.system(size: 12, weight: .semibold, design: .monospaced)).lineLimit(1)
                                        Text("Source: \(entry.name) • \(carSafeEnforceID3v23 ? "ID3v2.3 • 320k CBR" : "ID3v2.4 • Passthrough")").font(.system(size: 10)).foregroundStyle(.secondary).lineLimit(1)
                                    }
                                    Spacer()
                                    Text("\(entry.sectorsLBA) LBA").font(.system(size: 10, weight: .semibold, design: .monospaced)).foregroundStyle(store.activeAccent)
                                    Text(ByteCountFormatter.string(fromByteCount: entry.byteSize, countStyle: .file)).font(.system(size: 11, design: .monospaced)).foregroundStyle(.secondary)
                                    Button { store.removeStagedFile(id: entry.id) } label: { Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary) }.buttonStyle(.plain)
                                }
                                .padding(.horizontal, 14).padding(.vertical, 8)
                                Divider()
                            }
                        }
                    }
                }
            }
            .onDrop(of: [.fileURL], isTargeted: $isDropTargeted, perform: onHandleFinderDrop)
        }
    }
}
