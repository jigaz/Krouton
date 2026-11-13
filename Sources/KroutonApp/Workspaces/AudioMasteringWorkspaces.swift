import VideoOven
import Tartine
import Marmalade

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

    @ViewBuilder
    private func trackSplicePicker(compact: Bool) -> some View {
        Picker("", selection: $defaultAudioTransition) {
            Text(KroutonL10n.tr(compact ? "2.0s Standard Pre-Gap (IDX 00)" : "2.0s Standard Pre-Gap (INDEX 00)")).tag("2.0s Standard Pre-Gap (INDEX 00)")
            Text(KroutonL10n.tr(compact ? "0.0s Gapless Live (DAO)" : "0.0s Gapless Live Album (DAO)")).tag("0.0s Gapless Live Album (DAO)")
            Text(KroutonL10n.tr("2.5s Equal-Power Crossfade")).tag("2.5s Equal-Power Crossfade")
        }
        .labelsHidden()
        .font(.caption)
        .accessibilityLabel(KroutonL10n.tr("Default Track Splice"))
    }

    private var deckHeaderTitle: String {
        switch spec.id {
        case "cd-extra":
            return isCenterWorkspaceNarrow ? "BLUE BOOK CD-EXTRA DECK" : "BLUE BOOK 2-SESSION AUDIO + XA DATA DECK (S1 CD-DA • S2 ISO9660/HFS+)"
        case "dts-cd":
            return isCenterWorkspaceNarrow ? "DTS-CD 5.1 SURROUND DECK" : "IEC 61937 5.1 DTS-CD SURROUND MASTERING DECK (14-BIT PCM WRAPPER)"
        case "dvd-audio":
            return isCenterWorkspaceNarrow ? "DVD-AUDIO HI-RES DECK" : "DVD-AUDIO HIGH-RESOLUTION MASTERING DECK (AUDIO_TS • 24-BIT / 192 kHz MLP)"
        case "sacd-r":
            return isCenterWorkspaceNarrow ? "SCARLET BOOK SACD DECK" : "SCARLET BOOK DSD / SACD-R MASTERING DECK (1-BIT 2.8224 MHz DSD64)"
        case "cd-g":
            return isCenterWorkspaceNarrow ? "RED BOOK + R-W KARAOKE DECK" : "RED BOOK CD+G KARAOKE MASTERING DECK (96-BYTE R-W SUBCHANNEL GRAPHICS)"
        default:
            return isCenterWorkspaceNarrow ? "RED BOOK CD-DA DECK" : "RED BOOK CD-DA & CD-TEXT MASTERING DECK (44.1 kHz / 16-BIT PCM • 2,352 B/SECTOR)"
        }
    }

    private var deckSafetyBadgeText: String {
        switch spec.id {
        case "dts-cd": return "5.1 Coax / TOSLINK Bitstream Safe"
        case "dvd-audio": return "24-Bit / 192 kHz Lossless MLP"
        case "sacd-r": return "1-Bit DSD64 Scarlet Book"
        default: return KroutonL10n.tr("CD-TEXT: 7-Bit ASCII Hardware Safe")
        }
    }

    private var dropZoneFormatSubtitle: String {
        switch spec.id {
        case "dts-cd": return "Encapsulates 5.1 Surround DTS/AC-3 streams into 44.1 kHz / 16-bit IEC 61937 Red Book frames for S/PDIF receivers."
        case "dvd-audio": return "Authors high-resolution 24-bit / 96–192 kHz Stereo & 5.1 MLP PCM streams into an AUDIO_TS optical volume."
        case "sacd-r": return "Packages 1-Bit 2.8224 MHz DSD (.DSF / .DFF) or high-res PCM into a Scarlet Book UDF 1.02 SACD-R disc image."
        case "cd-g": return "Interleaves 44.1 kHz Stereo PCM audio with raw 96-byte R–W subchannel graphics packets (.cdg + .wav/.mp3 or .bin/.cue)."
        default:
            return "Krouton decodes all audio to 44.1 kHz / 16-bit Stereo PCM on disk before burning (Zero Underrun Guarantee)."
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // WaveBurner CD-TEXT, UPC/MCN & HTOA Mastering Deck
            KroutonMasteringDeckCard(store: store) {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 8) {
                        Image(systemName: spec.sfSymbol)
                            .foregroundStyle(store.activeAccent)
                            .accessibilityHidden(true)

                        Text(deckHeaderTitle)
                            .font(.system(size: 10, weight: .heavy, design: .monospaced))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)

                        Spacer(minLength: 4)

                        if !isCenterWorkspaceNarrow {
                            Text(deckSafetyBadgeText)
                                .font(.system(size: 9, weight: .bold, design: .monospaced))
                                .foregroundStyle(.green)
                                .lineLimit(1)
                        }

                        Button {
                            showMarmaladeCuePopover.toggle()
                        } label: {
                            let packs = store.computeLiveMarmaladeCDTextPackCount(albumTitle: cdTextAlbumTitle, albumPerformer: cdTextAlbumPerformer, tracks: store.redBookTracks)
                            HStack(spacing: 4) {
                                Image(systemName: "doc.text.magnifyingglass")
                                Text(isCenterWorkspaceNarrow ? ".CUE (\(packs) Packs)" : "Marmalade .CUE (\(packs) Packs)")
                                    .lineLimit(1)
                            }
                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(store.activeAccent.opacity(0.16))
                            .foregroundStyle(store.activeAccent)
                            .clipShape(Capsule())
                            .fixedSize(horizontal: true, vertical: false)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Inspect Marmalade Red Book CUE Sheet and CD-Text Packs")
                        .popover(isPresented: $showMarmaladeCuePopover, arrowEdge: .bottom) {
                            KroutonMarmaladeCuePopoverView(store: store, cdTextAlbumTitle: cdTextAlbumTitle, cdTextAlbumPerformer: cdTextAlbumPerformer, cdTextUPCBarcode: cdTextUPCBarcode)
                        }
                    }

                    if isCenterWorkspaceNarrow {
                        VStack(alignment: .leading, spacing: 6) {
                            HStack(spacing: 6) {
                                Text(KroutonL10n.tr("Album:")).font(.caption.bold()).frame(width: 52, alignment: .leading)
                                TextField("ALBUM TITLE", text: $cdTextAlbumTitle)
                                    .textFieldStyle(.roundedBorder)
                                    .accessibilityLabel(KroutonL10n.tr("Album Title"))
                            }
                            HStack(spacing: 6) {
                                Text(KroutonL10n.tr("Artist:")).font(.caption.bold()).frame(width: 52, alignment: .leading)
                                TextField("ARTIST / PERFORMER", text: $cdTextAlbumPerformer)
                                    .textFieldStyle(.roundedBorder)
                                    .accessibilityLabel(KroutonL10n.tr("Performer"))
                            }
                            HStack(spacing: 6) {
                                Text(KroutonL10n.tr("UPC:")).font(.caption.bold()).frame(width: 52, alignment: .leading)
                                TextField("012345678905", text: $cdTextUPCBarcode)
                                    .textFieldStyle(.roundedBorder)
                                    .font(.system(size: 11, design: .monospaced))
                                    .frame(maxWidth: 145)
                                    .accessibilityLabel(KroutonL10n.tr("UPC or MCN Barcode"))
                                Spacer(minLength: 0)
                            }
                            HStack(spacing: 6) {
                                Text(KroutonL10n.tr("Splice:")).font(.caption.bold()).frame(width: 52, alignment: .leading)
                                trackSplicePicker(compact: true)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                            Toggle(KroutonL10n.tr("Hidden Track One Audio (HTOA in INDEX 00)"), isOn: $enableHiddenTrackOneHTOA)
                                .toggleStyle(.checkbox)
                                .font(.caption.bold())
                                .lineLimit(1)
                        }
                    } else {
                        HStack(spacing: 12) {
                            HStack(spacing: 6) {
                                Text(KroutonL10n.tr("Album Title:")).font(.caption.bold()).lineLimit(1)
                                TextField("ALBUM TITLE", text: $cdTextAlbumTitle)
                                    .textFieldStyle(.roundedBorder)
                                    .frame(minWidth: 185, maxWidth: .infinity)
                                    .accessibilityLabel(KroutonL10n.tr("Album Title"))
                            }
                            HStack(spacing: 6) {
                                Text(KroutonL10n.tr("Performer:")).font(.caption.bold()).lineLimit(1)
                                TextField("ARTIST / PERFORMER", text: $cdTextAlbumPerformer)
                                    .textFieldStyle(.roundedBorder)
                                    .frame(minWidth: 185, maxWidth: .infinity)
                                    .accessibilityLabel(KroutonL10n.tr("Performer"))
                            }
                        }

                        HStack(spacing: 14) {
                            HStack(spacing: 6) {
                                Text(KroutonL10n.tr("UPC / MCN:")).font(.caption.bold()).lineLimit(1)
                                TextField("012345678905", text: $cdTextUPCBarcode)
                                    .textFieldStyle(.roundedBorder)
                                    .font(.system(size: 11, design: .monospaced))
                                    .frame(width: 120)
                                    .accessibilityLabel(KroutonL10n.tr("UPC or MCN Barcode"))
                            }

                            HStack(spacing: 6) {
                                Text(KroutonL10n.tr("Default Track Splice:")).font(.caption.bold()).lineLimit(1)
                                trackSplicePicker(compact: false)
                                    .fixedSize(horizontal: true, vertical: false)
                            }

                            Toggle(KroutonL10n.tr("Hidden Track One Audio (HTOA)"), isOn: $enableHiddenTrackOneHTOA)
                                .toggleStyle(.checkbox)
                                .font(.caption.bold())
                                .lineLimit(1)

                            Spacer(minLength: 0)
                        }
                    }

                    if spec.id == "cd-extra" || spec.technicalName.contains("Extra") {
                        Divider().opacity(0.5)
                        if isCenterWorkspaceNarrow {
                            VStack(alignment: .leading, spacing: 6) {
                                HStack(spacing: 8) {
                                    Label("Session 2 Data Label:", systemImage: "opticaldisc.fill")
                                        .font(.caption.bold())
                                        .foregroundStyle(store.uiSecondaryAccent)
                                    TextField("BONUS_EXTRA", text: $cdExtraDataVolumeName)
                                        .textFieldStyle(.roundedBorder)
                                }
                                Toggle(KroutonL10n.tr("Bundle Artwork & Liner Notes in Session 2"), isOn: $cdExtraIncludeLinerNotes)
                                    .toggleStyle(.checkbox)
                                    .font(.caption)
                                    .lineLimit(1)
                            }
                        } else {
                            HStack(spacing: 12) {
                                Label("Blue Book 2-Session (S1 Audio → S2 XA Data):", systemImage: "opticaldisc.fill")
                                    .font(.caption.bold())
                                    .foregroundStyle(store.uiSecondaryAccent)
                                TextField("BONUS_EXTRA", text: $cdExtraDataVolumeName)
                                    .textFieldStyle(.roundedBorder)
                                    .frame(width: 145)
                                Toggle(KroutonL10n.tr("Auto-Bundle Artwork & Liner Notes in Session 2"), isOn: $cdExtraIncludeLinerNotes)
                                    .toggleStyle(.checkbox)
                                    .font(.caption)
                                Spacer(minLength: 0)
                            }
                        }
                    }
                }
            }

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
                    KroutonEmptyDropZoneView(
                        store: store,
                        isDropTargeted: isDropTargeted,
                        sfSymbol: "waveform.circle.fill",
                        headline: isCenterWorkspaceNarrow ? "Drop Any Audio Format" : "Drop Any Audio Format (WAV, AIFF, FLAC, ALAC, APE, WavPack, DSD .DSF/.DFF, Opus, Ogg, AC-3, DTS, MP3, M4A)",
                        subtitle: dropZoneFormatSubtitle
                    )
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
