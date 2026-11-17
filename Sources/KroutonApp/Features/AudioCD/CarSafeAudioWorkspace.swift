import Foundation
import OpticalCore
import SwiftUI
import UniformTypeIdentifiers

// MARK: - CarSafeAudioWorkspace

struct KroutonCarSafeAudioWorkspaceView: View {
    @ObservedObject var store: KroutonStateStore
    let spec: KroutonOpticalWorkflowSpec
    let isCenterWorkspaceNarrow: Bool
    @Binding var isDropTargeted: Bool
    let onHandleFinderDrop: ([NSItemProvider]) -> Bool

    @State private var carSafeZeroPadNumbers: Bool = true
    @State private var carSafeStripAppleDouble: Bool = true
    @State private var carSafeEnforceID3v23: Bool = true
    @State private var carSafeGenerateM3U: Bool = true
    @State private var carSafeStripArtwork: Bool = true
    @State private var carSafeForceJointStereo: Bool = true
    @State private var carSafeLowPassFilter: Bool = true
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
                                Text("~112 kbps VBR MP3 (Super Long Play)").tag("~112 kbps VBR MP3 (Joint Stereo • 19 kHz LPF)")
                                Text("16-Bit FLAC / WAV Direct").tag("16-Bit FLAC / WAV Passthrough (Modern Head Units)")
                            }.labelsHidden().font(.caption)
                        }
                    }
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 225), alignment: .leading)], spacing: 6) {
                        Toggle(KroutonL10n.tr("Zero-Pad Prefixes (001 - Title.mp3)"), isOn: $carSafeZeroPadNumbers).toggleStyle(.checkbox).font(.caption.bold())
                        Toggle(KroutonL10n.tr("Strip macOS .DS_Store & ._* Forks"), isOn: $carSafeStripAppleDouble).toggleStyle(.checkbox).font(.caption.bold())
                        Toggle(KroutonL10n.tr("Write Root .M3U Playlist"), isOn: $carSafeGenerateM3U).toggleStyle(.checkbox).font(.caption)
                        Toggle(KroutonL10n.tr("Enforce ID3v2.3 ISO-8859-1 Tags"), isOn: $carSafeEnforceID3v23).toggleStyle(.checkbox).font(.caption)
                        Toggle(KroutonL10n.tr("Strip ID3 Cover Art & Lyrics (Max Capacity)"), isOn: $carSafeStripArtwork).toggleStyle(.checkbox).font(.caption).foregroundStyle(carSafeTranscodeTarget.contains("112") ? .primary : .secondary)
                        Toggle(KroutonL10n.tr("Force Joint Stereo (Phase Correlated)"), isOn: $carSafeForceJointStereo).toggleStyle(.checkbox).font(.caption).foregroundStyle(carSafeTranscodeTarget.contains("112") ? .primary : .secondary)
                        Toggle(KroutonL10n.tr("19 kHz Lame Low-Pass Filter"), isOn: $carSafeLowPassFilter).toggleStyle(.checkbox).font(.caption).foregroundStyle(carSafeTranscodeTarget.contains("112") ? .primary : .secondary)
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
                    let plan = store.dataDiscPlan(forFormatID: spec.id)
                    let activeMedium = store.resolvedDataDiscMedium(forFormatID: spec.id)
                    let oversizeIDs: Set<UUID> = Set(plan.issues.compactMap { issue in
                        if case .itemExceedsDisc(let id, _, _) = issue { return id }
                        return nil
                    })
                    ScrollView {
                        VStack(spacing: 0) {
                            ForEach(plan.discs) { disc in
                                if plan.discs.count > 1 || !oversizeIDs.isEmpty {
                                    DataDiscHeaderBannerView(
                                        store: store,
                                        disc: disc,
                                        totalDiscs: plan.discs.count,
                                        medium: activeMedium,
                                        hasOversizeItem: disc.items.contains { oversizeIDs.contains($0.id) }
                                    )
                                }
                                ForEach(Array(disc.items.enumerated()), id: \.element.id) { idx, entry in
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
                                    Button { store.removeStagedFile(id: entry.id) } label: { Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary) }.buttonStyle(.plain).accessibilityLabel(KroutonL10n.tr("Remove Item")).help(KroutonL10n.tr("Remove Item"))
                                }
                                .padding(.horizontal, 14).padding(.vertical, 8)
                                .contextMenu {
                                    if (store.stagedFiles.firstIndex(where: { $0.id == entry.id }) ?? 0) > 0 {
                                        Button(entry.startsNewDisc ? "Merge Back With Previous Disc" : "Start New Disc Here (Disc Break)") {
                                            store.toggleDataManualDiscBreak(before: entry.id)
                                        }
                                    }
                                }
                                Divider()
                            }
                            }
                        }
                    }
                }
            }
            .onDrop(of: [.fileURL], isTargeted: $isDropTargeted, perform: onHandleFinderDrop)
        }
    }
}
