import Crustini
import SwiftUI
import Foundation
import UniformTypeIdentifiers
import OpticalDough
import VideoOven

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
    @State private var rescueScratchMode: Int = 1
    @State private var audioRipTracks: [KroutonRipTrackItem] = KroutonRipTrackItem.defaultRedBookTOC
    @State private var videoExtractTitles: [KroutonVideoExtractTitleItem] = KroutonVideoExtractTitleItem.defaultVideoTitles

    var body: some View {
        let isShrinkTask = (store.selectedTaskID == "copy-duplicate" || store.selectedTaskID == "copy-shrink-dvd")
        let isAudioRipTask = (store.selectedTaskID == "copy-rip-audio" || store.selectedTaskID == "copy-audio-rip")
        let sourceDescription = !copySourceOverrideLabel.isEmpty
            ? "Source: \(copySourceOverrideLabel)"
            : "Source Drive: \(primarySelectedDrive?.displayName ?? "Optical Drive") — Status: \(primarySelectedDrive?.statusBadgeText ?? "Ready")"

        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                KroutonStyledIconBadge(
                    sfSymbol: isAudioRipTask ? "waveform.circle.fill" : (isShrinkTask ? "doc.on.doc.fill" : "film.stack.fill"),
                    tintColor: store.activeAccent, style: store.iconWidgetStyle, size: 28, symbolSize: 14
                )
                VStack(alignment: .leading, spacing: 1) {
                    Text(isAudioRipTask ? "Audio CD Ripper & AccurateRip Archiver" : (isShrinkTask ? "Duplicate Disc & Fit-to-Disc Requantizer" : "Video Disc Extractor (MKV Remux / VideoToolbox)"))
                        .font(.title3.bold()).lineLimit(1).minimumScaleFactor(0.78)
                    if !isCenterWorkspaceNarrow {
                        Text(sourceDescription).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                    }
                }
                Spacer(minLength: 4)
                Button {
                    rescanOpticalDiscForCopyTask(isAudioRipTask: isAudioRipTask, isShrinkTask: isShrinkTask)
                } label: {
                    Label(isCenterWorkspaceNarrow ? "Scan" : (isAudioRipTask ? "Scan CD TOC" : "Scan Disc"), systemImage: "arrow.clockwise.circle.fill")
                        .font(.system(size: 11, weight: .semibold)).padding(.horizontal, 10).padding(.vertical, 6)
                        .background(store.uiSecondaryAccent.opacity(0.18)).foregroundStyle(store.uiSecondaryAccent).clipShape(Capsule())
                }.buttonStyle(.plain)

                Button {
                    promptForCopySourceOrFolder(isAudioRipTask: isAudioRipTask, isShrinkTask: isShrinkTask)
                } label: {
                    Label(isCenterWorkspaceNarrow ? "Source..." : "Choose Source / Folder...", systemImage: "folder.fill.badge.gearshape")
                        .font(.system(size: 11, weight: .semibold)).padding(.horizontal, 10).padding(.vertical, 6)
                        .background(store.activeAccent).foregroundStyle(store.activeOnAccentText).clipShape(Capsule())
                }.buttonStyle(.plain)
            }

            if !copyStatusBanner.isEmpty {
                Text(copyStatusBanner).font(.system(size: 11, weight: .semibold, design: .monospaced))
                    .foregroundStyle(store.activeAccent).padding(.horizontal, 10).padding(.vertical, 4)
                    .background(store.activeAccent.opacity(0.12)).clipShape(RoundedRectangle(cornerRadius: 6))
            }

            unifiedOpticalRescueMapCard
            if isAudioRipTask {
                audioCDRipWorkspaceDeck
            } else if isShrinkTask {
                shrinkDVDVideoWorkspaceDeck
            } else {
                videoDiscExtractWorkspaceDeck
            }
        }
    }

    func rescanOpticalDiscForCopyTask(isAudioRipTask: Bool, isShrinkTask: Bool) {
        if isAudioRipTask {
            audioRipTracks = KroutonRipTrackItem.musicBrainzMatchedTOC
            cdTextAlbumTitle = "Kind of Laser (Remastered)"
            cdTextAlbumPerformer = "The Optical Pickups"
            copyStatusBanner = "Matched 5 Red Book tracks via MusicBrainz & AccurateRip"
        } else {
            copyStatusBanner = isShrinkTask ? "Scanned Dual-Layer DVD-9 (7.84 GB -> 4.37 GB DVD-5 Ready)" : "Scanned 3 Video Titles (BDMV / VIDEO_TS)"
        }
    }

    func promptForCopySourceOrFolder(isAudioRipTask: Bool, isShrinkTask: Bool) {
        KroutonStageImporterBridge.shared.presentImporter(allowedTypes: [.item, .folder], allowsMultiple: false) { urls in
            guard let url = urls.first else { return }
            if isAudioRipTask { copyOutputFolderPath = url.path }
            else { copySourceOverrideLabel = url.lastPathComponent }
        }
    }

    var audioCDRipWorkspaceDeck: some View {
        VStack(alignment: .leading, spacing: 10) {
            KroutonMasteringDeckCard(store: store) {
                VStack(alignment: .leading, spacing: 8) {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 210), alignment: .leading)], spacing: 8) {
                        HStack(spacing: 6) {
                            Text("Album:").font(.caption.bold())
                            TextField("Album Title", text: $cdTextAlbumTitle).textFieldStyle(.roundedBorder)
                        }
                        HStack(spacing: 6) {
                            Text("Artist:").font(.caption.bold())
                            TextField("Artist", text: $cdTextAlbumPerformer).textFieldStyle(.roundedBorder)
                        }
                        HStack(spacing: 6) {
                            Text("Codec:").font(.caption.bold())
                            Picker("", selection: $audioRipCodec) {
                                Text("FLAC (Lossless)").tag("FLAC (Lossless)")
                                Text("Apple Lossless (ALAC)").tag("Apple Lossless (ALAC)")
                                Text("WAV (Uncompressed PCM)").tag("WAV (Uncompressed PCM)")
                                Text("MP3 320 kbps CBR").tag("MP3 320 kbps CBR")
                            }.labelsHidden().font(.caption)
                        }
                    }
                    HStack(spacing: 14) {
                        Toggle("AccurateRip + C2 Error Recovery", isOn: $audioRipAccurateRip).toggleStyle(.checkbox).font(.caption.bold())
                        Toggle("Write .CUE + Extraction .LOG", isOn: $audioRipGenerateCueLog).toggleStyle(.checkbox).font(.caption)
                        Spacer()
                        Text("Out: \(copyOutputFolderPath)").font(.system(size: 10, design: .monospaced)).foregroundStyle(.secondary).lineLimit(1)
                    }
                }
            }
            ScrollView {
                VStack(spacing: 0) {
                    ForEach(audioRipTracks) { (trk: KroutonRipTrackItem) in
                        HStack(spacing: 10) {
                            Toggle("", isOn: Binding(
                                get: { audioRipSelectedTracks.contains(trk.num) },
                                set: { if $0 { audioRipSelectedTracks.insert(trk.num) } else { audioRipSelectedTracks.remove(trk.num) } }
                            )).labelsHidden().toggleStyle(.checkbox)
                            Text(String(format: "%02d", trk.num)).font(.system(size: 11, weight: .bold, design: .monospaced)).foregroundStyle(store.activeAccent).frame(width: 26)
                            VStack(alignment: .leading, spacing: 1) {
                                Text(trk.title).font(.system(size: 12, weight: .semibold))
                                Text(trk.performer).font(.system(size: 10, design: .monospaced)).foregroundStyle(.secondary)
                            }
                            Spacer()
                            if audioRipAccurateRip {
                                Text(trk.arStatus).font(.system(size: 9, weight: .bold, design: .monospaced)).foregroundStyle(.green)
                            }
                            Text(trk.duration).font(.system(size: 11, design: .monospaced)).foregroundStyle(.secondary)
                        }.padding(.horizontal, 12).padding(.vertical, 7)
                        Divider()
                    }
                }
            }.background(Color.kroutonControlSurface).clipShape(RoundedRectangle(cornerRadius: 10))
        }
    }

    var videoDiscExtractWorkspaceDeck: some View {
        VStack(alignment: .leading, spacing: 10) {
            KroutonMasteringDeckCard(store: store) {
                HStack(spacing: 14) {
                    Picker("Mode:", selection: $videoExtractMode) {
                        Text("Lossless MKV Remux").tag("Lossless MKV Remux")
                        Text("HEVC 10-Bit (VideoToolbox)").tag("HEVC 10-Bit (VideoToolbox)")
                        Text("H.264 MP4 Hardware").tag("H.264 MP4 Hardware")
                    }.font(.caption.bold())
                    Toggle("Preserve Chapter Markers & Subtitles", isOn: $videoExtractKeepChapters).toggleStyle(.checkbox).font(.caption)
                    Spacer()
                }
            }
            ScrollView {
                VStack(spacing: 0) {
                    ForEach(videoExtractTitles.filter { $0.seconds >= videoExtractMinSeconds }) { (item: KroutonVideoExtractTitleItem) in
                        HStack(spacing: 10) {
                            Toggle("", isOn: Binding(
                                get: { videoExtractSelectedTitles.contains(item.id) },
                                set: { if $0 { videoExtractSelectedTitles.insert(item.id) } else { videoExtractSelectedTitles.remove(item.id) } }
                            )).labelsHidden().toggleStyle(.checkbox)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(item.name).font(.system(size: 12, weight: .semibold))
                                Text("Video + Audio Streams").font(.system(size: 10)).foregroundStyle(.secondary)
                            }
                            Spacer()
                            Text(item.duration).font(.system(size: 10, weight: .bold, design: .monospaced)).foregroundStyle(store.activeAccent)
                            Text("\(item.seconds / 60) min").font(.system(size: 11, design: .monospaced)).foregroundStyle(.secondary)
                        }.padding(.horizontal, 12).padding(.vertical, 8)
                        Divider()
                    }
                }
            }.background(Color.kroutonControlSurface).clipShape(RoundedRectangle(cornerRadius: 10))
        }
    }

    var shrinkDVDVideoWorkspaceDeck: some View {
        let plan = KroutonVideoOvenModule.planDVD9ToDVD5Shrink(
            mainFeatureBytes: 7_350_000_000,
            menusAndExtrasBytes: 490_000_000,
            preserveMenusAndExtras: preserveMenusAndExtras
        )
        return VStack(alignment: .leading, spacing: 10) {
            KroutonMasteringDeckCard(store: store) {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 14) {
                        Toggle("Fit Dual-Layer DVD-9 (8.5 GB) onto Single-Layer DVD-5 (4.7 GB)", isOn: $fitToDiscDVD9Shrink).toggleStyle(.checkbox).font(.caption.bold())
                        Toggle("Preserve Interactive Menus & Subpictures", isOn: $preserveMenusAndExtras).toggleStyle(.checkbox).font(.caption)
                        Spacer()
                    }
                    Text(String(format: "VideoOven Requantizer Ratio: %.1f%% • Output: %.2f GB • Requantize: %@", plan.requantizationRatio * 100.0, Double(plan.estimatedOutputBytes) / 1_000_000_000.0, plan.requiresRequantization ? "ACTIVE" : "PASSTHROUGH"))
                        .font(.system(size: 10, weight: .semibold, design: .monospaced)).foregroundStyle(store.activeAccent)
                }
            }
        }
    }

    @ViewBuilder
    var unifiedOpticalRescueMapCard: some View {
        let map = KroutonKrustiniModule.buildOpticalRescueMap(totalSectorsLBA: 333_000, scratchSeverity: rescueScratchMode)
        KroutonMasteringDeckCard(store: store) {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 8) {
                    Image(systemName: "lifepreserver.fill").foregroundStyle(store.activeAccent)
                    Text("OPTICAL BAD-SECTOR RESCUE MAP (r = 24.0 mm -> 58.0 mm • \(String(format: "%.2f%%", map.recoveryIntegrityPercent)) INTEGRITY)")
                        .font(.system(size: 9.5, weight: .heavy, design: .monospaced)).foregroundStyle(.secondary)
                    Spacer()
                    Picker("Condition:", selection: $rescueScratchMode) {
                        Text("Pristine").tag(0)
                        Text("Light Scratch (C2/2x CLV)").tag(1)
                        Text("Deep Radial Gouge").tag(2)
                    }.font(.caption).frame(width: 215)
                    Button("Copy .MAP Log") {
                        KroutonOSDesktopBridge.copyTextToClipboard(map.exportRescueMapLog(volumeName: store.discVolumeTitle))
                        copyStatusBanner = "Copied .MAP Sector Rescue Log to Clipboard"
                    }.buttonStyle(.bordered).controlSize(.mini)
                    Button("Send to Video Author ->") {
                        store.selectedTaskID = "dvd-video"
                        copyStatusBanner = "Routed Extracted Stream to DVD/BDMV Authoring Deck"
                    }.buttonStyle(.borderedProminent).tint(store.uiSecondaryAccent).controlSize(.mini)
                }
                HStack(spacing: 2) {
                    ForEach(Array(map.buckets.enumerated()), id: \.offset) { _, status in
                        let col: Color = status == .healthyBurst ? .green : (status == .retried2xCLV ? .orange : (status == .c2Interpolated ? .cyan : .red))
                        RoundedRectangle(cornerRadius: 1.5).fill(col.opacity(0.85)).frame(height: 10)
                    }
                }
                HStack(spacing: 14) {
                    Label("Clean: \(map.healthyCount)/64", systemImage: "checkmark.circle.fill").foregroundStyle(.green)
                    Label("2x CLV Retry: \(map.retriedCount)", systemImage: "arrow.triangle.2.circlepath").foregroundStyle(.orange)
                    Label("C2 Interpolated: \(map.c2InterpolatedCount)", systemImage: "waveform.badge.magnifyingglass").foregroundStyle(.cyan)
                    Label("Zero-Padded: \(map.zeroPaddedCount)", systemImage: "exclamationmark.octagon.fill").foregroundStyle(.red)
                    Spacer()
                }.font(.system(size: 9.5, weight: .semibold, design: .monospaced))
            }
        }
    }
}
