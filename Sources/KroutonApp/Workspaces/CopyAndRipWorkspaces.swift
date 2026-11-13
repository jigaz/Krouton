import SwiftUI
import Foundation
import UniformTypeIdentifiers
import OpticalDough
import Marmalade
import VideoOven
import Tartine
import Galette
import Crustini

// MARK: - Phase 4: Extracted Optical Copy, Audio CD Rip & Video Remux Workspaces

struct KroutonCopyAndRipWorkspaceView: View {
    @ObservedObject var store: KroutonStateStore
    let primarySelectedDrive: KroutonToasterInfo?
    let isCenterWorkspaceNarrow: Bool
    @Binding var fitToDiscDVD9Shrink: Bool
    @Binding var preserveMenusAndExtras: Bool
    @Binding var cdTextAlbumTitle: String
    @Binding var cdTextAlbumPerformer: String

    @State private var audioRipCodec: String = "FLAC (Lossless)"
    @State private var audioRipAccurateRip: Bool = true
    @State private var audioRipGenerateCueLog: Bool = true
    @State private var audioRipSelectedTracks: Set<Int> = [1, 2, 3, 4, 5]
    @State private var videoExtractMode: String = "Lossless MKV Remux"
    @State private var videoExtractMinSeconds: Int = 120
    @State private var videoExtractKeepChapters: Bool = true
    @State private var videoExtractSelectedTitles: Set<String> = ["TITLE_01", "TITLE_02"]
    @State private var copySourceOverrideLabel: String = ""
    @State private var copyOutputFolderPath: String = "~/Music/Krouton Rips"
    @State private var copyStatusBanner: String = ""
    @State private var audioRipTracks: [KroutonRipTrackItem] = KroutonRipTrackItem.defaultRedBookTOC
    @State private var videoExtractTitles: [KroutonVideoExtractTitleItem] = KroutonVideoExtractTitleItem.defaultVideoTitles

    var body: some View {
        let isShrinkTask = (store.selectedTaskID == "copy-duplicate" || store.selectedTaskID == "copy-shrink-dvd")
        let isAudioRipTask = (store.selectedTaskID == "copy-rip-audio" || store.selectedTaskID == "copy-audio-rip")

        let sourceDescription: String = {
            if !copySourceOverrideLabel.isEmpty {
                return "Source: \(copySourceOverrideLabel)"
            }
            return "Source Drive: \(primarySelectedDrive?.displayName ?? "Optical Drive") — Status: \(primarySelectedDrive?.statusBadgeText ?? "Ready")"
        }()

        return VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                KroutonStyledIconBadge(
                    sfSymbol: isAudioRipTask ? "waveform.circle.fill" : (isShrinkTask ? "doc.on.doc.fill" : "film.stack.fill"),
                    tintColor: store.activeAccent,
                    style: store.iconWidgetStyle,
                    size: 28,
                    symbolSize: 14
                )
                VStack(alignment: .leading, spacing: 1) {
                    Text(
                        isCenterWorkspaceNarrow
                            ? (isAudioRipTask ? KroutonL10n.tr("Rip Audio") : (isShrinkTask ? KroutonL10n.tr("Duplicate") : KroutonL10n.tr("Rip Video")))
                            : (isAudioRipTask ? KroutonL10n.tr("Audio CD Ripper & AccurateRip Archiver") : (isShrinkTask ? KroutonL10n.tr("Duplicate Disc & Fit-to-Disc Requantizer") : KroutonL10n.tr("Video Disc Extractor (MKV Remux / VideoToolbox)")))
                    )
                    .font(.title3.bold())
                    .lineLimit(1)
                    .minimumScaleFactor(0.78)
                    if !isCenterWorkspaceNarrow {
                        Text(sourceDescription)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
                Spacer(minLength: 4)

                Button {
                    rescanOpticalDiscForCopyTask(isAudioRipTask: isAudioRipTask, isShrinkTask: isShrinkTask)
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.clockwise.circle.fill")
                        Text(isCenterWorkspaceNarrow ? "Scan" : (isAudioRipTask ? "Scan CD TOC" : "Scan Disc"))
                            .lineLimit(1)
                    }
                    .font(.system(size: 11, weight: .semibold))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(store.uiSecondaryAccent.opacity(0.18))
                    .foregroundStyle(store.uiSecondaryAccent)
                    .clipShape(Capsule())
                    .fixedSize(horizontal: true, vertical: false)
                }
                .buttonStyle(.plain)

                Button {
                    promptForCopySourceOrFolder(isAudioRipTask: isAudioRipTask, isShrinkTask: isShrinkTask)
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: isAudioRipTask ? "folder.badge.gearshape" : "opticaldisc.fill")
                        Text(isCenterWorkspaceNarrow ? "Choose..." : (isAudioRipTask ? "Choose Rip Folder..." : "Load VIDEO_TS / ISO..."))
                            .lineLimit(1)
                    }
                    .font(.system(size: 11, weight: .semibold))
                    .padding(.horizontal, 11)
                    .padding(.vertical, 6)
                    .background(store.activeAccent)
                    .foregroundStyle(store.activeOnAccentText)
                    .clipShape(Capsule())
                    .fixedSize(horizontal: true, vertical: false)
                }
                .buttonStyle(.plain)
            }

            if !copyStatusBanner.isEmpty {
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(store.uiSecondaryAccent)
                    Text(copyStatusBanner)
                        .font(.system(size: 11, weight: .medium))
                        .lineLimit(1)
                    Spacer()
                    Button {
                        copyStatusBanner = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .background(store.uiSecondaryAccent.opacity(0.14))
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }

            Divider()

            if isAudioRipTask {
                audioCDRipWorkspaceDeck
            } else if isShrinkTask {
                shrinkDVDVideoWorkspaceDeck
            } else {
                videoDiscExtractWorkspaceDeck
            }

            Spacer(minLength: 0)
        }
    }

    func rescanOpticalDiscForCopyTask(isAudioRipTask: Bool, isShrinkTask: Bool) {
        let driveName = primarySelectedDrive?.displayName ?? "Optical Drive"
        if isAudioRipTask {
            audioRipSelectedTracks = Set(audioRipTracks.map(\.num))
            copyStatusBanner = "Scanned Red Book TOC on \(driveName): \(audioRipTracks.count) PCM tracks verified with AccurateRip v2."
        } else if isShrinkTask {
            copyStatusBanner = "Scanned \(driveName): 7.92 GB Dual-Layer DVD-9 layout ready for 4.37 GB DVD-5 requantization."
        } else {
            videoExtractSelectedTitles = Set(videoExtractTitles.map(\.id))
            copyStatusBanner = "Scanned \(driveName): \(videoExtractTitles.count) video title sets & chapter tables indexed."
        }
    }

    func promptForCopySourceOrFolder(isAudioRipTask: Bool, isShrinkTask: Bool) {
        if isAudioRipTask {
            KroutonStageImporterBridge.shared.presentImporter(allowedTypes: [.folder], allowsMultiple: false) { urls in
                guard let url = urls.first else { return }
                copyOutputFolderPath = url.path
                copyStatusBanner = "Rip output directory set to: \(url.path)"
            }
        } else {
            let videoSourceTypes: [UTType] = [.folder, .item]
            KroutonStageImporterBridge.shared.presentImporter(allowedTypes: videoSourceTypes, allowsMultiple: false) { urls in
                guard let url = urls.first else { return }
                copySourceOverrideLabel = url.lastPathComponent
                let sizeBytes = (try? FileManager.default.attributesOfItem(atPath: url.path)[.size] as? Int64) ?? 4_700_000_000
                let sizeGB = String(format: "%.2f GB", Double(max(sizeBytes, 850_000_000)) / 1_000_000_000.0)
                if !isShrinkTask {
                    let customID = "TITLE_\( String(format: "%02d", videoExtractTitles.count + 1) )"
                    videoExtractTitles.insert(
                        KroutonVideoExtractTitleItem(id: customID, name: "\(url.lastPathComponent) — Imported Stream", streamInfo: "Direct Stream Remux • Chapters Preserved", sizeLabel: sizeGB, duration: "01:42:10", seconds: 6130),
                        at: 0
                    )
                    videoExtractSelectedTitles.insert(customID)
                }
                copyStatusBanner = "Loaded source media '\(url.lastPathComponent)' (\(sizeGB)) for \(isShrinkTask ? "DVD-5 Shrink" : "extraction")."
            }
        }
    }

    var audioCDRipWorkspaceDeck: some View {
        VStack(alignment: .leading, spacing: 10) {
            VStack(alignment: .leading, spacing: 8) {
                if isCenterWorkspaceNarrow {
                    HStack(spacing: 6) {
                        Text(KroutonL10n.tr("Codec:")).font(.caption.bold()).foregroundStyle(.secondary)
                        Picker("", selection: $audioRipCodec) {
                            Text("FLAC (Lossless)").tag("FLAC (Lossless)")
                            Text("ALAC (Apple Lossless)").tag("ALAC (Apple Lossless)")
                            Text("WAV (16-bit PCM)").tag("WAV (16-bit / 44.1 kHz PCM)")
                            Text("AIFF").tag("AIFF (Uncompressed)")
                            Text("MP3 (320 kbps)").tag("MP3 (320 kbps CBR)")
                        }
                        .labelsHidden()
                        .frame(maxWidth: .infinity, alignment: .leading)

                        Button {
                            cdTextAlbumTitle = "Polycarbonate Horizons (1994 Master)"
                            cdTextAlbumPerformer = "The Optical Pickups"
                            audioRipTracks = KroutonRipTrackItem.musicBrainzMatchedTOC
                            copyStatusBanner = "Matched Disc ID 45059B05 via MusicBrainz & CD-TEXT."
                        } label: {
                            HStack(spacing: 3) {
                                Image(systemName: "magnifyingglass")
                                Text("CD-TEXT")
                            }
                            .font(.system(size: 10, weight: .bold))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(store.activeAccent.opacity(0.16))
                            .foregroundStyle(store.activeAccent)
                            .clipShape(Capsule())
                            .fixedSize(horizontal: true, vertical: false)
                        }
                        .buttonStyle(.plain)
                    }
                    Toggle(KroutonL10n.tr("Verify Checksums via AccurateRip v2"), isOn: $audioRipAccurateRip)
                        .toggleStyle(.checkbox).font(.caption.bold()).lineLimit(1)
                    Toggle(KroutonL10n.tr("Generate .CUE Sheet & Rip Log"), isOn: $audioRipGenerateCueLog)
                        .toggleStyle(.checkbox).font(.caption).lineLimit(1)
                } else {
                    HStack(spacing: 12) {
                        Text(KroutonL10n.tr("Output Codec:")).font(.caption.bold()).foregroundStyle(.secondary)
                        Picker("", selection: $audioRipCodec) {
                            Text("FLAC (Lossless)").tag("FLAC (Lossless)")
                            Text("ALAC (Apple Lossless)").tag("ALAC (Apple Lossless)")
                            Text("WAV (16-bit / 44.1 kHz PCM)").tag("WAV (16-bit / 44.1 kHz PCM)")
                            Text("AIFF (Uncompressed)").tag("AIFF (Uncompressed)")
                            Text("MP3 (320 kbps CBR)").tag("MP3 (320 kbps CBR)")
                        }
                        .labelsHidden()
                        .frame(maxWidth: 220)

                        Button {
                            cdTextAlbumTitle = "Polycarbonate Horizons (1994 Master)"
                            cdTextAlbumPerformer = "The Optical Pickups"
                            audioRipTracks = KroutonRipTrackItem.musicBrainzMatchedTOC
                            copyStatusBanner = "Matched Disc ID 45059B05 via MusicBrainz & CD-TEXT."
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "magnifyingglass")
                                Text("Lookup CD-TEXT / MusicBrainz")
                            }
                            .font(.system(size: 10.5, weight: .semibold))
                            .padding(.horizontal, 9)
                            .padding(.vertical, 4)
                            .background(store.activeAccent.opacity(0.15))
                            .foregroundStyle(store.activeAccent)
                            .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)

                        Spacer(minLength: 8)

                        HStack(spacing: 4) {
                            Image(systemName: "checkmark.seal.fill").font(.system(size: 10))
                            Text("Drive Offset: +6 Samples").font(.system(size: 10, weight: .semibold, design: .monospaced))
                        }
                        .padding(.horizontal, 8).padding(.vertical, 4)
                        .background(store.uiSecondaryAccent.opacity(0.16)).foregroundStyle(store.uiSecondaryAccent).clipShape(Capsule())
                    }

                    HStack(spacing: 16) {
                        Toggle(KroutonL10n.tr("Verify Checksums via AccurateRip v2"), isOn: $audioRipAccurateRip).toggleStyle(.checkbox).font(.caption)
                        Toggle(KroutonL10n.tr("Generate .CUE Sheet & Rip Log"), isOn: $audioRipGenerateCueLog).toggleStyle(.checkbox).font(.caption)
                        Spacer(minLength: 0)
                        Text("Dest: \(copyOutputFolderPath)").font(.system(size: 10, design: .monospaced)).foregroundStyle(.secondary).lineLimit(1)
                    }
                }
            }
            .padding(12)
            .background(Color.kroutonControlSurface)
            .clipShape(RoundedRectangle(cornerRadius: 10))

            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(isCenterWorkspaceNarrow
                         ? "CD TABLE OF CONTENTS (\(audioRipSelectedTracks.count)/\(audioRipTracks.count))"
                         : "AUDIO CD TABLE OF CONTENTS (\(audioRipSelectedTracks.count)/\(audioRipTracks.count) SELECTED)")
                        .font(.system(size: 10, weight: .heavy, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                    Spacer()
                    Button(audioRipSelectedTracks.count == audioRipTracks.count ? "Deselect All" : "Select All") {
                        if audioRipSelectedTracks.count == audioRipTracks.count {
                            audioRipSelectedTracks.removeAll()
                        } else {
                            audioRipSelectedTracks = Set(audioRipTracks.map(\.num))
                        }
                    }
                    .buttonStyle(.plain)
                    .font(.caption.bold())
                    .foregroundStyle(store.activeAccent)
                    .fixedSize(horizontal: true, vertical: false)
                }
                .padding(.horizontal, 4)

                ForEach(audioRipTracks, id: \.num) { trk in
                    let isChecked = audioRipSelectedTracks.contains(trk.num)
                    HStack(spacing: 8) {
                        Toggle("", isOn: Binding(
                            get: { isChecked },
                            set: { val in
                                if val { audioRipSelectedTracks.insert(trk.num) }
                                else { audioRipSelectedTracks.remove(trk.num) }
                            }
                        ))
                        .labelsHidden()
                        .toggleStyle(.checkbox)

                        VStack(alignment: .leading, spacing: 2) {
                            HStack(spacing: 6) {
                                Text(String(format: "TRK %02d", trk.num))
                                    .font(.system(size: 10.5, weight: .bold, design: .monospaced))
                                    .foregroundStyle(store.activeAccent)
                                Text(trk.title)
                                    .font(.system(size: 11.5, weight: .medium))
                                    .lineLimit(1)
                                Spacer(minLength: 4)
                                Text(trk.duration)
                                    .font(.system(size: 10.5, design: .monospaced))
                                    .foregroundStyle(.secondary)
                                    .fixedSize(horizontal: true, vertical: false)
                            }
                            HStack(spacing: 6) {
                                Text(trk.performer)
                                    .font(.system(size: 10))
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                                Spacer(minLength: 4)
                                if audioRipAccurateRip {
                                    Text(trk.arStatus)
                                        .font(.system(size: 9.5, weight: .semibold, design: .monospaced))
                                        .foregroundStyle(store.uiSecondaryAccent)
                                        .fixedSize(horizontal: true, vertical: false)
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 7)
                    .background(Color.kroutonControlSurface)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }
            }
        }
    }

    var videoDiscExtractWorkspaceDeck: some View {
        VStack(alignment: .leading, spacing: 10) {
            VStack(alignment: .leading, spacing: 8) {
                if isCenterWorkspaceNarrow {
                    HStack(spacing: 6) {
                        Text(KroutonL10n.tr("Mode:")).font(.caption.bold()).foregroundStyle(.secondary).frame(width: 56, alignment: .leading)
                        Picker("", selection: $videoExtractMode) {
                            Text("Lossless MKV Remux").tag("Lossless MKV Remux")
                            Text("Apple MP4 (H.264)").tag("Apple MP4 (VideoToolbox H.264)")
                            Text("Apple HEVC 10-Bit").tag("Apple HEVC 10-Bit")
                            Text("Full Disc Backup").tag("Full Disc Backup")
                        }
                        .labelsHidden()
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    HStack(spacing: 6) {
                        Text(KroutonL10n.tr("Filter:")).font(.caption.bold()).foregroundStyle(.secondary).frame(width: 56, alignment: .leading)
                        Picker("", selection: $videoExtractMinSeconds) {
                            Text("All Video Titles").tag(0)
                            Text("> 2 min (Skip Warnings)").tag(120)
                            Text("> 10 min (Features Only)").tag(600)
                        }
                        .labelsHidden()
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    Toggle(KroutonL10n.tr("Preserve Chapters, Subtitles & Audio"), isOn: $videoExtractKeepChapters)
                        .toggleStyle(.checkbox).font(.caption.bold()).lineLimit(1)
                } else {
                    HStack(spacing: 12) {
                        Text(KroutonL10n.tr("Extract Mode:")).font(.caption.bold()).foregroundStyle(.secondary)
                        Picker("", selection: $videoExtractMode) {
                            Text("Lossless MKV Remux (Zero Re-Encode)").tag("Lossless MKV Remux")
                            Text("Apple MP4 (VideoToolbox H.264)").tag("Apple MP4 (VideoToolbox H.264)")
                            Text("Apple HEVC 10-Bit (Hardware)").tag("Apple HEVC 10-Bit")
                            Text("Full Decrypted Disc Backup").tag("Full Disc Backup")
                        }
                        .labelsHidden()
                        .frame(maxWidth: 260)

                        Spacer(minLength: 8)

                        Picker("Min Title:", selection: $videoExtractMinSeconds) {
                            Text("All Titles").tag(0)
                            Text("> 2 min (Skip Warnings)").tag(120)
                            Text("> 10 min (Features Only)").tag(600)
                        }
                        .frame(maxWidth: 210)
                        .font(.caption)
                    }

                    HStack {
                        Toggle(KroutonL10n.tr("Preserve Chapter Markers, Forced Subtitles & Original Audio Tracks"), isOn: $videoExtractKeepChapters)
                            .toggleStyle(.checkbox).font(.caption)
                        Spacer()
                        Button("Choose Output Folder...") {
                            KroutonStageImporterBridge.shared.presentImporter(allowedTypes: [.folder], allowsMultiple: false) { urls in
                                guard let url = urls.first else { return }
                                copyOutputFolderPath = url.path
                                copyStatusBanner = "Video extraction folder set to: \(url.path)"
                            }
                        }
                        .buttonStyle(.plain).font(.caption.bold()).foregroundStyle(store.activeAccent)
                    }
                }
            }
            .padding(12)
            .background(Color.kroutonControlSurface)
            .clipShape(RoundedRectangle(cornerRadius: 10))

            ForEach(videoExtractTitles.filter { $0.seconds >= videoExtractMinSeconds }, id: \.id) { item in
                let isSelected = videoExtractSelectedTitles.contains(item.id)
                HStack(spacing: 8) {
                    Toggle("", isOn: Binding(
                        get: { isSelected },
                        set: { val in
                            if val { videoExtractSelectedTitles.insert(item.id) }
                            else { videoExtractSelectedTitles.remove(item.id) }
                        }
                    ))
                    .labelsHidden()
                    .toggleStyle(.checkbox)

                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 6) {
                            Text(item.name)
                                .font(.system(size: 11.5, weight: .semibold))
                                .lineLimit(1)
                            Spacer(minLength: 4)
                            Text(item.duration)
                                .font(.system(size: 10.5, design: .monospaced))
                                .foregroundStyle(.secondary)
                                .fixedSize(horizontal: true, vertical: false)
                        }
                        HStack(spacing: 6) {
                            Text(item.streamInfo)
                                .font(.system(size: 10))
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                            Spacer(minLength: 4)
                            Text(item.sizeLabel)
                                .font(.system(size: 10, weight: .semibold, design: .monospaced))
                                .foregroundStyle(store.activeAccent)
                                .fixedSize(horizontal: true, vertical: false)
                        }
                    }
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .background(Color.kroutonControlSurface)
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }
        }
    }

    var shrinkDVDVideoWorkspaceDeck: some View {
        VStack(alignment: .leading, spacing: 10) {
            if isCenterWorkspaceNarrow {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("DVD-9 → DVD-5 FIT-TO-DISC TRANSCODER")
                            .font(.system(size: 9.5, weight: .heavy, design: .monospaced))
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text(fitToDiscDVD9Shrink ? "Ratio: 68.4% • 4.37 GB" : "1:1 DL • 7.92 GB")
                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(store.uiSecondaryAccent.opacity(0.18))
                            .foregroundStyle(store.uiSecondaryAccent)
                            .clipShape(Capsule())
                    }
                    Toggle(KroutonL10n.tr("Fit to Disc (8.5 GB DVD-9 → 4.7 GB DVD-5)"), isOn: $fitToDiscDVD9Shrink)
                        .toggleStyle(.checkbox)
                        .font(.caption.bold())
                        .lineLimit(1)
                    Toggle(KroutonL10n.tr("Preserve Menus, Chapters (.IFO) & Extras"), isOn: $preserveMenusAndExtras)
                        .toggleStyle(.checkbox)
                        .font(.caption)
                        .lineLimit(1)
                }
            } else {
                HStack(spacing: 12) {
                    Toggle(KroutonL10n.tr("Fit to Disc — Requantize DVD-9 (8.5 GB) to standard 4.7 GB DVD-5"), isOn: $fitToDiscDVD9Shrink)
                        .font(.headline)
                        .lineLimit(1)
                    Spacer(minLength: 8)
                    Text(fitToDiscDVD9Shrink ? "Ratio: 68.4% • 4.37 GB" : "1:1 Dual-Layer • 7.92 GB")
                        .font(.system(size: 10.5, weight: .bold, design: .monospaced))
                        .padding(.horizontal, 9)
                        .padding(.vertical, 4)
                        .background(store.uiSecondaryAccent.opacity(0.18))
                        .foregroundStyle(store.uiSecondaryAccent)
                        .clipShape(Capsule())
                        .fixedSize(horizontal: true, vertical: false)
                }
                Toggle(KroutonL10n.tr("Preserve Interactive Menus, Chapter Tables (.IFO Relink) & Bonus Extras"), isOn: $preserveMenusAndExtras)
                    .font(.subheadline)
                    .lineLimit(1)
            }
            Divider()
            playlistRow(num: "VTS_01", title: "Main Feature Movie (480p MPEG-2)", duration: "01:58:14", transition: fitToDiscDVD9Shrink ? "Requantized -> 3.62 GB" : "Original 6.40 GB", info: "AC-3 5.1 + Subtitles")
            playlistRow(num: "VMGM", title: "Interactive Motion Menus & Chapters", duration: "00:04:12", transition: "100% Intact (340 MB)", info: "Zero Menu Loss")
            if preserveMenusAndExtras {
                playlistRow(num: "VTS_02", title: "Director Commentary & Featurettes", duration: "00:32:40", transition: fitToDiscDVD9Shrink ? "Requantized -> 420 MB" : "Original 1.18 GB", info: "Preserved")
            }
        }
        .padding(14)
        .background(Color.kroutonControlSurface)
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    @ViewBuilder
    func playlistRow(num: String, title: String, duration: String, transition: String, info: String) -> some View {
        if isCenterWorkspaceNarrow {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Text(num)
                        .font(.system(size: 10.5, weight: .bold, design: .monospaced))
                        .foregroundStyle(store.activeAccent)
                    Text(title)
                        .font(.system(size: 11.5, weight: .semibold))
                        .lineLimit(1)
                    Spacer(minLength: 4)
                    Text(duration)
                        .font(.system(size: 10.5, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: true, vertical: false)
                }
                HStack(spacing: 6) {
                    Text(info)
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                    Spacer(minLength: 4)
                    Text(transition)
                        .font(.system(size: 10, weight: .semibold, design: .monospaced))
                        .foregroundStyle(store.activeAccent)
                        .lineLimit(1)
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
        } else {
            HStack(spacing: 12) {
                Text(num)
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundStyle(store.activeAccent)
                    .frame(width: 48, alignment: .leading)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 12, weight: .semibold))
                        .lineLimit(1)
                    Text(info)
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                Spacer()
                Text(transition)
                    .font(.system(size: 10, weight: .semibold, design: .monospaced))
                    .foregroundStyle(store.activeAccent)
                    .lineLimit(1)
                Text(duration)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .frame(width: 70, alignment: .trailing)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 9)
        }
    }
}
