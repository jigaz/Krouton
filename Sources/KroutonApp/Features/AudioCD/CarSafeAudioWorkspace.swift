import Foundation
import OpticalCore
import SwiftUI
import UniformTypeIdentifiers
import VideoKit

// MARK: - CarSafeAudioWorkspace

struct KroutonCarSafeAudioWorkspaceView: View {
    var store: KroutonStateStore
    let spec: KroutonOpticalWorkflowSpec
    @Environment(\.kroutonLayout) var windowLayout
    var isCenterWorkspaceNarrow: Bool { windowLayout.workspace == .narrow }
    @Binding var isDropTargeted: Bool
    let onHandleFinderDrop: ([NSItemProvider]) -> Bool

    // The switches live in `store.carAudioOptions`; `KroutonCarAudioDiscPreparer` (VideoKit)
    // applies them when the disc is burned or saved as an image. The track list previews the
    // names the disc will get.
    private var options: Binding<KroutonCarAudioOptions> { Bindable(store).carAudioOptions }

    private var profileLabel: String {
        let o = store.carAudioOptions
        switch o.profile {
        case .cbr320: return "\(o.enforceID3v23 ? "ID3v2.3" : "ID3v2.4") • 320k CBR"
        case .cbr192: return "\(o.enforceID3v23 ? "ID3v2.3" : "ID3v2.4") • 192k CBR"
        case .vbrLong: return "\(o.enforceID3v23 ? "ID3v2.3" : "ID3v2.4") • VBR ~115k"
        case .passthrough: return "copied as it is"
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            KroutonMasteringDeckCard(store: store) {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 8) {
                        Image(systemName: "car.rear.waves.up.fill").foregroundStyle(store.activeAccent)
                        Text(isCenterWorkspaceNarrow ? "CAR-SAFE ISO9660 + JOLIET" : "CAR-SAFE ISO9660 + JOLIET AUDIO ENGINE (OEM HEAD-UNIT SAFE)")
                            .font(.system(size: 10, weight: .heavy, design: .monospaced)).foregroundStyle(.secondary).lineLimit(1)
                        Spacer(minLength: 4)
                        Text("No hidden files").font(.system(size: 9, weight: .bold, design: .monospaced)).foregroundStyle(.green)
                            .help("Only the audio is put on the disc: no .DS_Store or ._ files.")
                    }
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 230), alignment: .leading)], spacing: 8) {
                        HStack(spacing: 6) {
                            Text("Disc Title:").font(.caption.bold())
                            TextField("CAR_MP3_DISC", text: Bindable(store).discVolumeTitle).textFieldStyle(.roundedBorder)
                        }
                        HStack(spacing: 6) {
                            Text("Profile:").font(.caption.bold())
                            Picker("", selection: options.profile) {
                                Text("320 kbps CBR MP3 (Car Safe)").tag(KroutonCarAudioOptions.Profile.cbr320)
                                Text("192 kbps CBR MP3 (12-Hr Trip)").tag(KroutonCarAudioOptions.Profile.cbr192)
                                Text("~115 kbps VBR MP3 (Super Long Play)").tag(KroutonCarAudioOptions.Profile.vbrLong)
                                Text("Files As They Are (No Conversion)").tag(KroutonCarAudioOptions.Profile.passthrough)
                            }.labelsHidden().font(.caption)
                        }
                    }
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 225), alignment: .leading)], spacing: 6) {
                        let converting = store.carAudioOptions.needsFFmpeg
                        Toggle(KroutonL10n.tr("Zero-Pad Prefixes (001 - Title.mp3)"), isOn: options.zeroPadNumbers).toggleStyle(.checkbox).font(.caption.bold())
                        Toggle(KroutonL10n.tr("Write Root .M3U Playlist"), isOn: options.generateM3U).toggleStyle(.checkbox).font(.caption)
                        Toggle(KroutonL10n.tr("ID3v2.3 + ID3v1 Tags"), isOn: options.enforceID3v23).toggleStyle(.checkbox).font(.caption).disabled(!converting)
                        Toggle(KroutonL10n.tr("Strip Cover Art & Lyrics"), isOn: options.stripArtwork).toggleStyle(.checkbox).font(.caption).disabled(!converting)
                        Toggle(KroutonL10n.tr("Joint Stereo"), isOn: options.forceJointStereo).toggleStyle(.checkbox).font(.caption).disabled(!converting)
                        Toggle(KroutonL10n.tr("19 kHz Low-Pass Filter"), isOn: options.lowPass19kHz).toggleStyle(.checkbox).font(.caption).disabled(!converting)
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
                                let displayFile = KroutonCarAudioDiscPreparer.discName(for: entry.url, index: idx, options: store.carAudioOptions)
                                HStack(spacing: 10) {
                                    Text(String(format: "#%03d", idx + 1)).font(.system(size: 11, weight: .bold, design: .monospaced)).foregroundStyle(store.activeAccent).frame(width: 44, alignment: .leading)
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(displayFile).font(.system(size: 12, weight: .semibold, design: .monospaced)).lineLimit(1)
                                        Text("Source: \(entry.name) • \(profileLabel)").font(.system(size: 10)).foregroundStyle(.secondary).lineLimit(1)
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
