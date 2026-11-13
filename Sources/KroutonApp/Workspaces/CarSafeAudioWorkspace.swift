import SwiftUI
import Foundation
import UniformTypeIdentifiers
import Combine
import OpticalDough
import Marmalade
import Tartine

// MARK: - Standalone Car-Safe ISO9660 + Joliet MP3/FLAC Mastering Workspace View

struct KroutonCarSafeAudioWorkspaceView: View {
    @ViewBuilder
    private func carSafeProfilePicker(compact: Bool) -> some View {
        Picker("", selection: $carSafeTranscodeTarget) {
            Text(KroutonL10n.tr(compact ? "320 kbps CBR MP3 (Car Safe)" : "320 kbps CBR MP3 (Universal Car Deck)")).tag("320 kbps CBR MP3 (Universal Car Deck)")
            Text(KroutonL10n.tr(compact ? "192 kbps CBR MP3 (12-Hr Trip)" : "192 kbps CBR MP3 (Extended 12-Hour Roadtrip)")).tag("192 kbps CBR MP3 (Extended 12-Hour Roadtrip)")
            Text(KroutonL10n.tr(compact ? "16-Bit FLAC / WAV Direct" : "16-Bit FLAC / WAV Passthrough (Modern Head Units)")).tag("16-Bit FLAC / WAV Passthrough (Modern Head Units)")
        }
        .labelsHidden()
        .font(.caption)
        .accessibilityLabel(KroutonL10n.tr("Audio Output Profile"))
    }

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
                    Image(systemName: "car.rear.waves.up.fill")
                        .foregroundStyle(store.activeAccent)
                        .accessibilityHidden(true)
                    Text(isCenterWorkspaceNarrow
                         ? KroutonL10n.tr("CAR-SAFE ISO9660 + JOLIET")
                         : KroutonL10n.tr("CAR-SAFE ISO9660 + JOLIET AUDIO ENGINE (PIONEER / ALPINE / SONY / OEM HEAD-UNIT SAFE)"))
                        .font(.system(size: 10, weight: .heavy, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                    Spacer(minLength: 4)
                    Text(isCenterWorkspaceNarrow
                         ? KroutonL10n.tr("AppleDouble Purged")
                         : KroutonL10n.tr("AppleDouble ._* & .DS_Store Purged"))
                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                        .foregroundStyle(.green)
                        .lineLimit(1)
                        .fixedSize(horizontal: true, vertical: false)
                }

                if isCenterWorkspaceNarrow {
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(spacing: 6) {
                            Text(KroutonL10n.tr("Disc Title:")).font(.caption.bold()).frame(width: 66, alignment: .leading)
                            TextField("CAR_MP3_DISC", text: $store.discVolumeTitle)
                                .textFieldStyle(.roundedBorder)
                                .accessibilityLabel(KroutonL10n.tr("Disc Volume Title"))
                        }
                        HStack(spacing: 6) {
                            Text(KroutonL10n.tr("Profile:")).font(.caption.bold()).frame(width: 66, alignment: .leading)
                            carSafeProfilePicker(compact: true).frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                } else {
                    HStack(spacing: 14) {
                        HStack(spacing: 6) {
                            Text(KroutonL10n.tr("Disc Volume Title:")).font(.caption.bold()).lineLimit(1)
                            TextField("CAR_MP3_DISC", text: $store.discVolumeTitle)
                                .textFieldStyle(.roundedBorder)
                                .frame(minWidth: 165, maxWidth: 230)
                                .accessibilityLabel(KroutonL10n.tr("Disc Volume Title"))
                        }
                        HStack(spacing: 6) {
                            Text(KroutonL10n.tr("Audio Output Profile:")).font(.caption.bold()).lineLimit(1)
                            carSafeProfilePicker(compact: false).fixedSize(horizontal: true, vertical: false)
                        }
                        Spacer(minLength: 0)
                    }
                }

                LazyVGrid(columns: [GridItem(.adaptive(minimum: 225), alignment: .leading)], spacing: 6) {
                    Toggle(KroutonL10n.tr("Zero-Pad Prefixes (001 - Title.mp3)"), isOn: $carSafeZeroPadNumbers)
                        .toggleStyle(.checkbox)
                        .font(.caption.bold())
                    Toggle(KroutonL10n.tr("Strip macOS .DS_Store & ._* Forks"), isOn: $carSafeStripAppleDouble)
                        .toggleStyle(.checkbox)
                        .font(.caption.bold())
                    Toggle(KroutonL10n.tr("Enforce ID3v2.3 ISO-8859-1 Tags"), isOn: $carSafeEnforceID3v23)
                        .toggleStyle(.checkbox)
                        .font(.caption)
                    Toggle(KroutonL10n.tr("Write Root .M3U Playlist"), isOn: $carSafeGenerateM3U)
                        .toggleStyle(.checkbox)
                        .font(.caption)
                }
                }
            }

            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color.kroutonControlSurface)
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .strokeBorder(
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
                    VStack(spacing: 0) {
                        HStack(spacing: 10) {
                            Text(KroutonL10n.tr("ORDER"))
                                .font(.system(size: 9, weight: .bold, design: .monospaced))
                                .foregroundStyle(.secondary)
                                .frame(width: 44, alignment: .leading)
                            Text(KroutonL10n.tr("CAR-SAFE JOLIET / ISO9660 FILENAME"))
                                .font(.system(size: 9, weight: .bold, design: .monospaced))
                                .foregroundStyle(.secondary)
                            Spacer()
                            Text(KroutonL10n.tr("TAG & CODEC PROFILE"))
                                .font(.system(size: 9, weight: .bold, design: .monospaced))
                                .foregroundStyle(.secondary)
                                .frame(width: 185, alignment: .center)
                            Text(KroutonL10n.tr("SECTORS"))
                                .font(.system(size: 9, weight: .bold, design: .monospaced))
                                .foregroundStyle(.secondary)
                                .frame(width: 86, alignment: .trailing)
                            Text(KroutonL10n.tr("SIZE"))
                                .font(.system(size: 9, weight: .bold, design: .monospaced))
                                .foregroundStyle(.secondary)
                                .frame(width: 72, alignment: .trailing)
                            Spacer().frame(width: 20)
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 6)
                        .background(ZStack { Color.black.opacity(0.18); store.sidebarTintOverlay })
                        Divider()

                        ScrollView {
                            VStack(spacing: 0) {
                                ForEach(Array(store.stagedFiles.enumerated()), id: \.element.id) { idx, entry in
                                    let baseName = entry.url.deletingPathExtension().lastPathComponent
                                    let displayFile = carSafeZeroPadNumbers
                                        ? String(format: "%03d - %@.mp3", idx + 1, String(baseName.prefix(48)))
                                        : "\(baseName).mp3"
                                    HStack(spacing: 10) {
                                        Text(String(format: "#%03d", idx + 1))
                                            .font(.system(size: 11, weight: .bold, design: .monospaced))
                                            .foregroundStyle(store.activeAccent)
                                            .frame(width: 44, alignment: .leading)

                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(displayFile)
                                                .font(.system(size: 12, weight: .semibold, design: .monospaced))
                                                .lineLimit(1)
                                            Text("Source: \(entry.name) • AppleDouble Fork Stripped")
                                                .font(.system(size: 10))
                                                .foregroundStyle(.secondary)
                                                .lineLimit(1)
                                        }
                                        Spacer()
                                        Text(carSafeEnforceID3v23 ? "ID3v2.3 • 320k CBR" : "ID3v2.4 • Passthrough")
                                            .font(.system(size: 10, weight: .semibold, design: .monospaced))
                                            .foregroundStyle(.green)
                                            .frame(width: 185, alignment: .center)
                                        Text("\(entry.sectorsLBA) LBA")
                                            .font(.system(size: 10, weight: .semibold, design: .monospaced))
                                            .contentTransition(.numericText())
                                            .foregroundStyle(store.activeAccent)
                                            .frame(width: 86, alignment: .trailing)
                                        Text(ByteCountFormatter.string(fromByteCount: entry.byteSize, countStyle: .file))
                                            .font(.system(size: 11, design: .monospaced))
                                            .foregroundStyle(.secondary)
                                            .frame(width: 72, alignment: .trailing)
                                        Button {
                                            store.removeStagedFile(id: entry.id)
                                        } label: {
                                            Image(systemName: "xmark.circle.fill")
                                                .foregroundStyle(.secondary)
                                        }
                                        .buttonStyle(.plain)
                                        .frame(width: 18, alignment: .center)
                                    }
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 8)
                                    Divider()
                                }
                            }
                        }
                    }
                }
            }
            .onDrop(of: [.fileURL], isTargeted: $isDropTargeted) { providers in
                onHandleFinderDrop(providers)
            }
        }
    }

}
