import AudioKit
import Foundation
import LabelKit
import OpticalCore
import RescueKit
import SwiftUI
import UniformTypeIdentifiers
import VideoKit

// MARK: - CopyAndRipWorkspaces — AudioUX

extension KroutonCopyAndRipWorkspaceView {
    var cdInfoEditorPopoverView: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                Image(systemName: "opticaldisc.fill")
                    .font(.system(size: 32))
                    .foregroundStyle(store.activeAccent)
                VStack(alignment: .leading, spacing: 2) {
                    Text(KroutonL10n.tr("CD Info & Metadata Tags")).font(.headline)
                    Text(mountedCDSnapshot?.musicBrainzDiscID ?? "No Disc Mounted")
                        .font(.system(size: 10, design: .monospaced)).foregroundStyle(.secondary)
                }
                Spacer()
                Button(KroutonL10n.tr("Get Track Names")) {
                    if let snap = mountedCDSnapshot {
                        lookupMusicBrainzMetadata(for: snap)
                    }
                }.buttonStyle(.borderedProminent).tint(store.uiSecondaryAccent).controlSize(.small)
            }
            Divider()
            Grid(alignment: .trailing, horizontalSpacing: 10, verticalSpacing: 8) {
                GridRow {
                    Text("Artist:").font(.caption.bold()).foregroundStyle(.secondary)
                    TextField("Artist", text: Bindable(store).cdTextAlbumPerformer).textFieldStyle(.roundedBorder)
                }
                GridRow {
                    Text("Album:").font(.caption.bold()).foregroundStyle(.secondary)
                    TextField("Album", text: Bindable(store).cdTextAlbumTitle).textFieldStyle(.roundedBorder)
                }
                GridRow {
                    Text("Composer:").font(.caption.bold()).foregroundStyle(.secondary)
                    TextField("Composer", text: $cdInfoComposer).textFieldStyle(.roundedBorder)
                }
                GridRow {
                    Text("Genre:").font(.caption.bold()).foregroundStyle(.secondary)
                    TextField("Genre", text: $cdInfoGenre).textFieldStyle(.roundedBorder)
                }
                GridRow {
                    Text("Year:").font(.caption.bold()).foregroundStyle(.secondary)
                    HStack(spacing: 8) {
                        TextField("YYYY", text: $cdInfoYear).textFieldStyle(.roundedBorder).frame(width: 70)
                        Text("Disc:").font(.caption.bold()).foregroundStyle(.secondary)
                        TextField("1", text: $cdInfoDiscNumber).textFieldStyle(.roundedBorder).frame(width: 36)
                        Text("of").font(.caption).foregroundStyle(.secondary)
                        TextField("1", text: $cdInfoDiscTotal).textFieldStyle(.roundedBorder).frame(width: 36)
                    }
                }
            }
            Toggle(KroutonL10n.tr("Album is a compilation of songs by various artists"), isOn: $cdInfoIsCompilation)
                .toggleStyle(.checkbox).font(.caption)
            Toggle(KroutonL10n.tr("Use error correction when reading Audio CDs"), isOn: $audioRipErrorCorrection)
                .toggleStyle(.checkbox).font(.caption)
            HStack {
                Spacer()
                Button(KroutonL10n.tr("OK")) { showCDInfoPopover = false }
                    .buttonStyle(.borderedProminent).tint(store.activeAccent)
            }
        }
        .padding(16)
        .frame(width: 380)
    }

    var audioCDRipWorkspaceDeck: some View {
        VStack(alignment: .leading, spacing: 8) {
            KroutonMasteringDeckCard(store: store) {
                VStack(alignment: .leading, spacing: 8) {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 195), alignment: .leading)], spacing: 8) {
                        HStack(spacing: 6) {
                            Text("Album:").font(.caption.bold()).frame(width: 44, alignment: .leading)
                            TextField("Album Title", text: Bindable(store).cdTextAlbumTitle).textFieldStyle(.roundedBorder)
                        }
                        HStack(spacing: 6) {
                            Text("Artist:").font(.caption.bold()).frame(width: 44, alignment: .leading)
                            TextField("Artist", text: Bindable(store).cdTextAlbumPerformer).textFieldStyle(.roundedBorder)
                        }
                        HStack(spacing: 6) {
                            Text("Codec:").font(.caption.bold()).frame(width: 44, alignment: .leading)
                            Picker("", selection: $audioRipCodec) {
                                Text("FLAC (Lossless)").tag("FLAC (Lossless)")
                                Text("Apple Lossless (ALAC)").tag("Apple Lossless (ALAC)")
                                Text("WAV (Uncompressed PCM)").tag("WAV (Uncompressed PCM)")
                                Text("AIFF (1:1 Red Book PCM)").tag("AIFF (1:1 Red Book PCM)")
                            }.labelsHidden().font(.caption)
                        }
                    }
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(spacing: 8) {
                            Button(audioRipSelectedTracks.count == audioRipTracks.count ? "Deselect All" : "Select All (\(audioRipTracks.count))") {
                                if audioRipSelectedTracks.count == audioRipTracks.count {
                                    audioRipSelectedTracks.removeAll()
                                } else {
                                    audioRipSelectedTracks = Set(audioRipTracks.map(\.num))
                                }
                            }.buttonStyle(.bordered).controlSize(.mini).fixedSize()
                            Button {
                                if let snap = mountedCDSnapshot { lookupMusicBrainzMetadata(for: snap) }
                                else { rescanOpticalDiscForCopyTask(isAudioRipTask: true, isShrinkTask: false, fetchMetadata: true) }
                            } label: {
                                Label(KroutonL10n.tr("Get Track Names"), systemImage: "sparkles.tv")
                            }.buttonStyle(.bordered).controlSize(.mini).fixedSize()
                            Spacer(minLength: 4)
                            Text("Out: \(copyOutputFolderPath)").font(.system(size: 10, design: .monospaced)).foregroundStyle(.secondary).lineLimit(1).truncationMode(.middle)
                        }
                        HStack(spacing: 12) {
                            Toggle(KroutonL10n.tr("Error Correction"), isOn: $audioRipErrorCorrection).toggleStyle(.checkbox).font(.caption.bold()).fixedSize()
                            Toggle(KroutonL10n.tr("AccurateRip + CRC32"), isOn: $audioRipAccurateRip).toggleStyle(.checkbox).font(.caption).fixedSize()
                            Toggle(KroutonL10n.tr("Write .CUE + .LOG"), isOn: $audioRipGenerateCueLog).toggleStyle(.checkbox).font(.caption).fixedSize()
                            Spacer(minLength: 0)
                        }
                    }
                }
            }
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach($audioRipTracks) { $trk in
                        audioTrackRowView(trk: $trk)
                        Divider()
                    }
                }
            }.background(Color.kroutonControlSurface).clipShape(RoundedRectangle(cornerRadius: 10))
        }
    }

    @ViewBuilder
    func audioTrackRowView(trk: Binding<KroutonRipTrackItem>) -> some View {
        let item = trk.wrappedValue
        let isActiveTrack = (activeRippingTrackNum == item.num && isRippingCD)
        let frac = perTrackProgress[item.num] ?? 0.0
        HStack(spacing: 10) {
            Toggle("", isOn: Binding(
                get: { audioRipSelectedTracks.contains(item.num) },
                set: { if $0 { audioRipSelectedTracks.insert(item.num) } else { audioRipSelectedTracks.remove(item.num) } }
            )).labelsHidden().toggleStyle(.checkbox)

            Text(String(format: "%02d", item.num))
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .foregroundStyle(store.activeAccent).frame(width: 24)

            VStack(alignment: .leading, spacing: 3) {
                TextField("Track Title", text: trk.title)
                    .textFieldStyle(.plain)
                    .font(.system(size: 12, weight: .semibold))
                if isActiveTrack {
                    HStack(spacing: 8) {
                        ProgressView(value: frac)
                            .frame(maxWidth: 220)
                        Text(String(format: "Converting (%.0f %%)...", frac * 100.0))
                            .font(.system(size: 10, weight: .semibold, design: .monospaced))
                            .foregroundStyle(store.activeAccent)
                    }
                } else {
                    Text("\(store.cdTextAlbumPerformer.isEmpty ? "Audio CD" : store.cdTextAlbumPerformer) • \(item.performer)")
                        .font(.system(size: 10, design: .monospaced)).foregroundStyle(.secondary).lineLimit(1)
                }
            }
            Spacer(minLength: 6)

            if audioRipAccurateRip {
                let badgeColor: Color = item.arStatus.contains("Cancelled") || item.arStatus.contains("Error")
                    ? .red
                    : (item.arStatus.contains("CRC") ? .cyan : .green)
                Text(item.arStatus)
                    .font(.system(size: 9.5, weight: .bold, design: .monospaced))
                    .foregroundStyle(badgeColor)
                    .lineLimit(1).fixedSize()
            }

            Text(item.duration)
                .font(.system(size: 11, design: .monospaced)).foregroundStyle(.secondary).fixedSize()

            if isActiveTrack {
                Button {
                    ripCancelToken.cancelledTracks.insert(item.num)
                } label: {
                    Image(systemName: "stop.circle")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.red)
                }
                .buttonStyle(.plain)
                .help("Stop converting this track")
            } else {
                Button {
                    startHardwareAudioCDExtraction(onlyTrackNumber: item.num)
                } label: {
                    Image(systemName: "arrow.clockwise.circle")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .disabled(isRippingCD)
                .help("Rip / Retry this track")
            }
        }
        .padding(.horizontal, 12).padding(.vertical, 6)
        .background(isActiveTrack ? store.activeAccent.opacity(0.10) : Color.clear)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Track \(String(format: "%02d", item.num)), \(item.title)")
        .accessibilityValue("\(audioRipSelectedTracks.contains(item.num) ? "Selected" : "Unchecked"), \(item.duration), \(item.arStatus)")
        .contextMenu {
            Button("Start / Convert Track \(String(format: "%02d", item.num))") {
                startHardwareAudioCDExtraction(onlyTrackNumber: item.num)
            }.keyboardShortcut("r", modifiers: [.command, .shift])
            Button(KroutonL10n.tr("Play Track in Default Player")) {
                if let src = mountedCDSnapshot?.tracks.first(where: { $0.trackNumber == item.num })?.sourceAIFFURL {
                    KroutonOSDesktopBridge.revealInFinder(url: src)
                }
            }
            Divider()
            Button(KroutonL10n.tr("Get Info (CD Info...)")) {
                showCDInfoPopover = true
            }.keyboardShortcut("i", modifiers: .command)
            Button(KroutonL10n.tr("Locate Source File in Finder")) {
                if let src = mountedCDSnapshot?.tracks.first(where: { $0.trackNumber == item.num })?.sourceAIFFURL {
                    KroutonOSDesktopBridge.revealInFinder(url: src)
                }
            }.keyboardShortcut("f", modifiers: [.command, .shift])
            Divider()
            Button(audioRipSelectedTracks.contains(item.num) ? "Uncheck Selection" : "Check Selection") {
                if audioRipSelectedTracks.contains(item.num) { audioRipSelectedTracks.remove(item.num) }
                else { audioRipSelectedTracks.insert(item.num) }
            }
        }
    }
}
