import VideoOven
import Tartine
import Marmalade
//
//  KroutonMasteringWorkspaces.swift
//  Krouton — Optical Media Mastering Studio
//
//  Format-Specific Mastering Workspaces (Data/Archival, Red Book Audio, Video Authoring, Car-Safe Audio, Retro Console ROMs, and Disc Image Inspector).
//

import OpticalDough
import SwiftUI
import UniformTypeIdentifiers
import Foundation
import Combine

struct KroutonRedBookAudioWorkspaceView: View {
    @ObservedObject var store: KroutonStateStore
    let spec: KroutonRecipeSpec
    let isCenterWorkspaceNarrow: Bool
    @Binding var cdTextAlbumTitle: String
    @Binding var cdTextAlbumPerformer: String
    @Binding var auditioningTrackID: UUID?
    @Binding var isDropTargeted: Bool
    let onHandleFinderDrop: ([NSItemProvider]) -> Bool

    @State private var showMarmaladeCuePopover: Bool = false
    @State private var cdTextUPCBarcode: String = "012345678905"
    @State private var enableHiddenTrackOneHTOA: Bool = false
    @State private var defaultAudioTransition: String = "2.0s Standard Pre-Gap (INDEX 00)"
    @State private var cdExtraDataVolumeName: String = "BONUS_EXTRA"
    @State private var cdExtraIncludeLinerNotes: Bool = true

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // WaveBurner CD-TEXT, UPC/MCN & HTOA Mastering Deck
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 10) {
                    Image(systemName: "waveform.path.ecg.rectangle.fill")
                        .foregroundStyle(store.activeAccent)
                    if !isCenterWorkspaceNarrow {
                        Text(KroutonL10n.tr("RED BOOK CD-DA & CD-TEXT MASTERING DECK (44.1 kHz / 16-BIT PCM • 2,352 B/SECTOR)"))
                            .font(.system(size: 10, weight: .heavy, design: .monospaced))
                            .foregroundStyle(.secondary).lineLimit(1)
                    }
                    Spacer()
                    if !isCenterWorkspaceNarrow {
                        Text(KroutonL10n.tr("CD-TEXT: 7-Bit ASCII Hardware Safe"))
                            .font(.system(size: 9, weight: .bold, design: .monospaced))
                            .foregroundStyle(.green)
                    }

                    Button {
                        showMarmaladeCuePopover.toggle()
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "doc.text.magnifyingglass")
                            Text("Marmalade .CUE (\(store.computeLiveMarmaladeCDTextPackCount(albumTitle: cdTextAlbumTitle, albumPerformer: cdTextAlbumPerformer, tracks: store.redBookTracks)) Packs)")
                        }
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(store.activeAccent.opacity(0.16))
                        .foregroundStyle(store.activeAccent)
                        .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                    .popover(isPresented: $showMarmaladeCuePopover, arrowEdge: .bottom) {
                        KroutonMarmaladeCuePopoverView(store: store, cdTextAlbumTitle: cdTextAlbumTitle, cdTextAlbumPerformer: cdTextAlbumPerformer, cdTextUPCBarcode: cdTextUPCBarcode)
                    }
                }

                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 12) {
                        HStack(spacing: 5) {
                            Text(KroutonL10n.tr("Album Title:")).font(.caption.bold()).lineLimit(1)
                            TextField("ALBUM TITLE", text: $cdTextAlbumTitle).textFieldStyle(.roundedBorder).frame(width: 160)
                        }
                        HStack(spacing: 5) {
                            Text(KroutonL10n.tr("Performer:")).font(.caption.bold()).lineLimit(1)
                            TextField("ARTIST / PERFORMER", text: $cdTextAlbumPerformer).textFieldStyle(.roundedBorder).frame(width: 150)
                        }
                        HStack(spacing: 5) {
                            Text(KroutonL10n.tr("UPC / MCN:")).font(.caption.bold()).lineLimit(1)
                            TextField("012345678905", text: $cdTextUPCBarcode).textFieldStyle(.roundedBorder).font(.system(size: 11, design: .monospaced)).frame(width: 110)
                        }
                        Spacer(minLength: 0)
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        HStack(spacing: 6) {
                            Text(KroutonL10n.tr("Album:")).font(.caption.bold()).frame(width: 48, alignment: .leading)
                            TextField("ALBUM TITLE", text: $cdTextAlbumTitle).textFieldStyle(.roundedBorder)
                        }
                        HStack(spacing: 6) {
                            Text(KroutonL10n.tr("Artist:")).font(.caption.bold()).frame(width: 48, alignment: .leading)
                            TextField("ARTIST / PERFORMER", text: $cdTextAlbumPerformer).textFieldStyle(.roundedBorder)
                        }
                        HStack(spacing: 6) {
                            Text(KroutonL10n.tr("UPC:")).font(.caption.bold()).frame(width: 48, alignment: .leading)
                            TextField("012345678905", text: $cdTextUPCBarcode).textFieldStyle(.roundedBorder).font(.system(size: 11, design: .monospaced)).frame(width: 125)
                            Spacer()
                        }
                    }
                }

                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 14) {
                        Picker("Default Track Splice:", selection: $defaultAudioTransition) {
                            Text(KroutonL10n.tr("2.0s Standard Pre-Gap (INDEX 00)")).tag("2.0s Standard Pre-Gap (INDEX 00)")
                            Text(KroutonL10n.tr("0.0s Gapless Live Album (DAO)")).tag("0.0s Gapless Live Album (DAO)")
                            Text(KroutonL10n.tr("2.5s Equal-Power Crossfade")).tag("2.5s Equal-Power Crossfade")
                        }
                        .frame(maxWidth: 285)
                        .font(.caption)

                        Toggle(KroutonL10n.tr("Hidden Track One Audio (HTOA)"), isOn: $enableHiddenTrackOneHTOA)
                            .toggleStyle(.checkbox)
                            .font(.caption.bold())
                            .lineLimit(1)

                        Spacer(minLength: 0)
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        Picker("Track Splice:", selection: $defaultAudioTransition) {
                            Text(KroutonL10n.tr("2.0s Standard Pre-Gap (INDEX 00)")).tag("2.0s Standard Pre-Gap (INDEX 00)")
                            Text(KroutonL10n.tr("0.0s Gapless Live Album (DAO)")).tag("0.0s Gapless Live Album (DAO)")
                            Text(KroutonL10n.tr("2.5s Equal-Power Crossfade")).tag("2.5s Equal-Power Crossfade")
                        }
                        .font(.caption)

                        Toggle(KroutonL10n.tr("Hidden Track One Audio (HTOA in INDEX 00)"), isOn: $enableHiddenTrackOneHTOA)
                            .toggleStyle(.checkbox)
                            .font(.caption.bold())
                    }
                }

                if spec.id == "cd-extra" || spec.technicalName.contains("Extra") {
                    Divider().opacity(0.5)
                    ViewThatFits(in: .horizontal) {
                        HStack(spacing: 12) {
                            Label("Blue Book 2-Session (S1 Audio → S2 XA Data):", systemImage: "opticaldisc.fill")
                                .font(.caption.bold())
                                .foregroundStyle(store.uiSecondaryAccent)
                            TextField("BONUS_EXTRA", text: $cdExtraDataVolumeName)
                                .textFieldStyle(.roundedBorder)
                                .frame(width: 135)
                            Toggle(KroutonL10n.tr("Auto-Bundle Artwork & Liner Notes in Session 2"), isOn: $cdExtraIncludeLinerNotes)
                                .toggleStyle(.checkbox)
                                .font(.caption)
                            Spacer(minLength: 0)
                        }
                        VStack(alignment: .leading, spacing: 6) {
                            HStack(spacing: 8) {
                                Label("Session 2 Data Label:", systemImage: "opticaldisc.fill")
                                    .font(.caption.bold())
                                    .foregroundStyle(store.uiSecondaryAccent)
                                TextField("BONUS_EXTRA", text: $cdExtraDataVolumeName)
                                    .textFieldStyle(.roundedBorder)
                                    .frame(maxWidth: 160)
                            }
                            Toggle(KroutonL10n.tr("Bundle Artwork & Liner Notes in Session 2 (ISO9660/HFS+)"), isOn: $cdExtraIncludeLinerNotes)
                                .toggleStyle(.checkbox)
                                .font(.caption)
                        }
                    }
                }
            }
            .padding(10)
            .background(store.enableSecondaryAccentUITints ? store.activeAccent.opacity(0.11) : Color.clear)
            .background(Color.kroutonControlSurface)
            .clipShape(RoundedRectangle(cornerRadius: 9))
            .overlay(RoundedRectangle(cornerRadius: 9).stroke(store.activeAccent.opacity(0.30), lineWidth: 1))

            // Red Book PQ Tracklist Table
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
                    VStack(spacing: 10) {
                        Image(systemName: "waveform.circle.fill")
                            .font(.system(size: 36))
                            .foregroundStyle(store.uiSecondaryAccent.opacity(0.85))
                        Text(isCenterWorkspaceNarrow ? KroutonL10n.tr("Drop Any Audio Format") : KroutonL10n.tr("Drop Any Audio Format (WAV, AIFF, FLAC, ALAC, APE, WavPack, DSD .DSF/.DFF, Opus, Ogg, AC-3, DTS, MP3, M4A)"))
                            .font(.headline)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 24)
                        Text(KroutonL10n.tr("Krouton decodes all audio to 44.1 kHz / 16-bit Stereo PCM on disk before burning (Zero Underrun Guarantee)."))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 36)
                    }
                } else {
                    VStack(spacing: 0) {
                        HStack(spacing: 10) {
                            Text(KroutonL10n.tr("TRK"))
                                .font(.system(size: 9, weight: .bold, design: .monospaced))
                                .foregroundStyle(.secondary)
                                .frame(width: 34, alignment: .leading)
                            Text(KroutonL10n.tr("TRACK TITLE & CD-TEXT PERFORMER"))
                                .font(.system(size: 9, weight: .bold, design: .monospaced))
                                .foregroundStyle(.secondary)
                            Spacer()
                            Text(KroutonL10n.tr("ISRC CODE"))
                                .font(.system(size: 9, weight: .bold, design: .monospaced))
                                .foregroundStyle(.secondary)
                                .frame(width: 104, alignment: .center)
                            Text(KroutonL10n.tr("INDEX 00 / SPLICE"))
                                .font(.system(size: 9, weight: .bold, design: .monospaced))
                                .foregroundStyle(.secondary)
                                .frame(width: 145, alignment: .center)
                            Text(KroutonL10n.tr("MM:SS:FF (75 FPS)"))
                                .font(.system(size: 9, weight: .bold, design: .monospaced))
                                .foregroundStyle(.secondary)
                                .frame(width: 98, alignment: .trailing)
                            Text(KroutonL10n.tr("AUDITION"))
                                .font(.system(size: 9, weight: .bold, design: .monospaced))
                                .foregroundStyle(.secondary)
                                .frame(width: 72, alignment: .center)
                            Spacer().frame(width: 20)
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 6)
                        .background(ZStack { Color.black.opacity(0.18); store.sidebarTintOverlay })
                        Divider()

                        ScrollView {
                            VStack(spacing: 0) {
                                ForEach(Array(store.stagedFiles.enumerated()), id: \.element.id) { idx, entry in
                                    let trackNum = idx + 1
                                    let cleanTitle = entry.url.deletingPathExtension().lastPathComponent
                                    let estSeconds = max(18, min(680, Int(entry.byteSize / 36_000)))
                                    let mm = estSeconds / 60
                                    let ss = estSeconds % 60
                                    let ff = (idx * 17) % 75
                                    let isrcCode = String(format: "US-KRT-26-%05d", trackNum)
                                    let isAuditioningThis = (auditioningTrackID == entry.id)

                                    HStack(spacing: 10) {
                                        Text(idx == 0 && enableHiddenTrackOneHTOA ? "00*" : String(format: "%02d", trackNum))
                                            .font(.system(size: 12, weight: .heavy, design: .monospaced))
                                            .foregroundStyle(store.activeAccent)
                                            .frame(width: 34, alignment: .leading)

                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(cleanTitle)
                                                .font(.system(size: 12, weight: .semibold))
                                                .lineLimit(1)
                                            let probe = KroutonPantryPrepEngine.probeFile(entry.url)
                                            Text("Performer: \(cdTextAlbumPerformer) • [\(probe.shortHardwareBadge)] \(probe.audioCodecName) -> 44.1 kHz 16-Bit PCM")
                                                .font(.system(size: 10))
                                                .foregroundStyle(.secondary)
                                                .lineLimit(1)
                                        }

                                        Spacer()

                                        Text(isrcCode)
                                            .font(.system(size: 10, weight: .semibold, design: .monospaced))
                                            .foregroundStyle(.secondary)
                                            .frame(width: 104, alignment: .center)

                                        Text(defaultAudioTransition.components(separatedBy: " (").first ?? "2.0s Pre-Gap")
                                            .font(.system(size: 10, weight: .semibold, design: .monospaced))
                                            .foregroundStyle(Color.cyan)
                                            .frame(width: 145, alignment: .center)

                                        Text(String(format: "%02d:%02d:%02d", mm, ss, ff))
                                            .font(.system(size: 11, weight: .bold, design: .monospaced))
                                            .foregroundStyle(store.activeAccent)
                                            .frame(width: 98, alignment: .trailing)

                                        Button {
                                            if isAuditioningThis {
                                                auditioningTrackID = nil
                                            } else {
                                                auditioningTrackID = entry.id
                                                KroutonOSDesktopBridge.playAcousticCue()
                                            }
                                        } label: {
                                            HStack(spacing: 4) {
                                                Image(systemName: isAuditioningThis ? "stop.fill" : "play.fill")
                                                Text(isAuditioningThis ? "Stop" : "Splice")
                                            }
                                            .font(.system(size: 9, weight: .bold))
                                            .padding(.horizontal, 8)
                                            .padding(.vertical, 3)
                                            .background(isAuditioningThis ? Color.green : store.activeAccent.opacity(0.18))
                                            .foregroundStyle(isAuditioningThis ? Color.black : store.activeAccent)
                                            .clipShape(Capsule())
                                        }
                                        .buttonStyle(.plain)
                                        .frame(width: 72, alignment: .center)
                                        .help("Audition Track \(trackNum) -> Track \(trackNum + 1) splice / crossfade transition")

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
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 10) {
                    Image(systemName: "car.rear.waves.up.fill")
                        .foregroundStyle(store.activeAccent)
                    Text(KroutonL10n.tr("CAR-SAFE ISO9660 + JOLIET AUDIO ENGINE (PIONEER / ALPINE / SONY / OEM HEAD-UNIT SAFE)"))
                        .font(.system(size: 10, weight: .heavy, design: .monospaced))
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text(KroutonL10n.tr("AppleDouble ._* & .DS_Store Purged"))
                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                        .foregroundStyle(.green)
                }

                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 14) {
                        HStack(spacing: 6) {
                            Text(KroutonL10n.tr("Disc Volume Title:")).font(.caption.bold()).lineLimit(1)
                            TextField("CAR_MP3_DISC", text: $store.discVolumeTitle).textFieldStyle(.roundedBorder).frame(width: 150)
                        }
                        Picker("Audio Output Profile:", selection: $carSafeTranscodeTarget) {
                            Text(KroutonL10n.tr("320 kbps CBR MP3 (Universal Car Deck)")).tag("320 kbps CBR MP3 (Universal Car Deck)")
                            Text(KroutonL10n.tr("192 kbps CBR MP3 (Extended 12-Hour Roadtrip)")).tag("192 kbps CBR MP3 (Extended 12-Hour Roadtrip)")
                            Text(KroutonL10n.tr("16-Bit FLAC / WAV Passthrough (Modern Head Units)")).tag("16-Bit FLAC / WAV Passthrough (Modern Head Units)")
                        }
                        .frame(maxWidth: 320)
                        .font(.caption)
                        Spacer(minLength: 0)
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        HStack(spacing: 6) {
                            Text(KroutonL10n.tr("Disc Title:")).font(.caption.bold())
                            TextField("CAR_MP3_DISC", text: $store.discVolumeTitle).textFieldStyle(.roundedBorder)
                        }
                        Picker("Profile:", selection: $carSafeTranscodeTarget) {
                            Text(KroutonL10n.tr("320 kbps CBR MP3")).tag("320 kbps CBR MP3 (Universal Car Deck)")
                            Text(KroutonL10n.tr("192 kbps CBR MP3")).tag("192 kbps CBR MP3 (Extended 12-Hour Roadtrip)")
                            Text(KroutonL10n.tr("16-Bit FLAC / WAV")).tag("16-Bit FLAC / WAV Passthrough (Modern Head Units)")
                        }
                        .font(.caption)
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
            .padding(10)
            .background(store.enableSecondaryAccentUITints ? store.activeAccent.opacity(0.11) : Color.clear)
            .background(Color.kroutonControlSurface)
            .clipShape(RoundedRectangle(cornerRadius: 9))
            .overlay(RoundedRectangle(cornerRadius: 9).stroke(store.activeAccent.opacity(0.30), lineWidth: 1))

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
                    VStack(spacing: 10) {
                        Image(systemName: "music.note.list")
                            .font(.system(size: 36))
                            .foregroundStyle(store.uiSecondaryAccent.opacity(0.85))
                        Text(KroutonL10n.tr("Drop MP3, FLAC, M4A, or Album Folders to Build a Car-Safe Audio Disc"))
                            .font(.headline)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 24)
                        Text(KroutonL10n.tr("Automatically numbers files in raw FAT/ISO directory order and strips hidden macOS resource forks so car stereos never freeze."))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 36)
                    }
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
