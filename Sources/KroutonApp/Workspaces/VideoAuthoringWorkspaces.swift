import VideoOven
import Tartine
import Marmalade
import OpticalDough
import SwiftUI
import UniformTypeIdentifiers
import Foundation

struct KroutonVideoAuthoringWorkspaceView: View {
    @ObservedObject var store: KroutonStateStore
    let spec: KroutonRecipeSpec
    let isCenterWorkspaceNarrow: Bool
    @Binding var fitToDiscDVD9Shrink: Bool
    let preserveMenusAndExtras: Bool
    @Binding var isDropTargeted: Bool
    let onHandleFinderDrop: ([NSItemProvider]) -> Bool

    @State private var showVideoOvenPopover: Bool = false
    @State private var videoMenuTemplate: String = "Dark Studio Chapter Grid"
    @State private var videoSystemStandard: String = "NTSC 16:9 (29.97 / 23.976p)"
    @State private var videoDualLayerBreakSector: String = "Auto Cell Boundary (LBA 2,086,912 • 16-Sector ECC Aligned)"
    @State private var avchdBitrateCap: String = "18 Mbps (3x DVD-R Safe)"
    @State private var uhdPreserveHDR10DolbyVision: Bool = true

    // Sprint 2: Per-Title Inline Stream Mux & Timestamp Chapter State
    @State private var expandedMuxEntryID: UUID? = nil
    @State private var streamMuxConfigs: [UUID: KroutonStreamMuxDescriptor] = [:]

    private var isVCDFormat: Bool {
        spec.id == "video-svcd" || spec.id == "vcd-svcd" || spec.technicalName.contains("VCD")
    }

    private var videoDeckHeaderTitle: String {
        if isVCDFormat { return "WHITE BOOK VCD 2.0 / SVCD STUDIO (MPEG-1/2 • MODE 2 XA)" }
        if spec.id == "bd-uhd" { return "4K UHD-BD HDR10 / DOLBY VISION AUTHORING STUDIO (UDF 2.60)" }
        if spec.id == "bd-on-dvd" { return "AVCHD HIGH-DEFINITION ON RED-LASER DVD STUDIO (UDF 2.50)" }
        if spec.technicalName.contains("BD") { return "BLU-RAY / BDMV AUTHORING STUDIO (UDF 2.50 / 2.60 • H.264 / HEVC)" }
        return "DVD-VIDEO AUTHORING & FIT-TO-DISC STUDIO (UDF 1.02 + ISO9660)"
    }

    private func muxFor(_ id: UUID) -> KroutonStreamMuxDescriptor {
        streamMuxConfigs[id] ?? KroutonStreamMuxDescriptor()
    }

    var body: some View {
        let isDualLayer = spec.technicalName.contains("DL") || spec.technicalName.contains("DVD-9") || spec.colloquialName.contains("50 GB") || spec.colloquialName.contains("UHD") || spec.id == "dvd-video"
        let isBluRay = spec.technicalName.contains("BD") || spec.technicalName.contains("AVCHD")
        let shrinkLabel = isVCDFormat ? "Fit-to-CD Smart MPEG-1/2 Bitrate Clamp" : (isBluRay ? "Fit-to-Disc Requantizer (BD-50 -> BD-25)" : "Fit-to-Disc Requantizer (DVD-9 -> DVD-5)")

        VStack(alignment: .leading, spacing: 10) {
            KroutonMasteringDeckCard(store: store) {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 8) {
                        Image(systemName: "film.stack.fill").foregroundStyle(store.activeAccent)
                        Text(videoDeckHeaderTitle).font(.system(size: 10, weight: .heavy, design: .monospaced)).foregroundStyle(.secondary).lineLimit(1)
                        Spacer(minLength: 4)
                        Text(isBluRay ? "BDMV + CERTIFICATE Auto-Built" : "VIDEO_TS + Empty AUDIO_TS Enforced")
                            .font(.system(size: 9, weight: .bold, design: .monospaced)).foregroundStyle(.green).lineLimit(1)
                        Button {
                            showVideoOvenPopover.toggle()
                        } label: {
                            Label("Bitrate & Fit", systemImage: "gauge.with.dots.needle.67percent").font(.system(size: 10, weight: .bold, design: .monospaced))
                        }
                        .buttonStyle(.bordered).controlSize(.small)
                        .popover(isPresented: $showVideoOvenPopover, arrowEdge: .bottom) {
                            KroutonVideoOvenPopoverView(store: store, spec: spec, isBluRay: isBluRay, isDualLayer: isDualLayer, fitToDiscDVD9Shrink: fitToDiscDVD9Shrink, preserveMenusAndExtras: preserveMenusAndExtras)
                        }
                    }

                    HStack(spacing: 12) {
                        Text("Disc Title:").font(.caption.bold())
                        TextField("KROUTON_VIDEO", text: $store.discVolumeTitle).textFieldStyle(.roundedBorder).frame(maxWidth: 165)
                        Picker("Menu:", selection: $videoMenuTemplate) {
                            Text("Dark Studio Chapter Grid").tag("Dark Studio Chapter Grid")
                            Text("No Menu (Auto-Play Title 1)").tag("No Menu (Auto-Play Title 1 on Insert)")
                            Text("Minimalist Track List").tag("Minimalist Studio Track List")
                        }.font(.caption)
                        Picker("System:", selection: $videoSystemStandard) {
                            Text("NTSC 16:9 (29.97/23.976p)").tag("NTSC 16:9 (29.97 / 23.976p)")
                            Text("PAL 16:9 (25 fps)").tag("PAL 16:9 (25 fps)")
                            Text("UHD 2160p HDR10").tag("UHD 2160p HDR10 (HEVC 10-Bit)")
                        }.font(.caption)
                    }

                    HStack(spacing: 14) {
                        Toggle(shrinkLabel, isOn: $fitToDiscDVD9Shrink).toggleStyle(.checkbox).font(.caption.bold())
                        if isDualLayer {
                            Picker("Layer Break:", selection: $videoDualLayerBreakSector) {
                                Text("Auto Cell Boundary (16-Sec ECC)").tag("Auto Cell Boundary (LBA 2,086,912 • 16-Sector ECC Aligned)")
                                Text("50/50 Balanced Split (L0 >= L1)").tag("50/50 Balanced Split (Layer 0 >= Layer 1 Rule)")
                                Text("Seamless Layer Break (SPLB)").tag("Seamless Layer Break (SPLB Flag Set)")
                            }.font(.caption)
                        }
                        if spec.id == "bd-uhd" {
                            Toggle("HDR10 / Dolby Vision Metadata", isOn: $uhdPreserveHDR10DolbyVision).toggleStyle(.checkbox).font(.caption.bold())
                        }
                        Spacer(minLength: 0)
                    }
                }
            }

            videoStagingDropZoneSection(isBluRay: isBluRay)
        }
    }

    @ViewBuilder
    private func videoStagingDropZoneSection(isBluRay: Bool) -> some View {
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
                    sfSymbol: "film.circle.fill",
                    headline: "Drop Any Video or Container (MKV, M2TS, MP4, MOV ProRes, HEVC 10-Bit, VOB, VIDEO_TS, BDMV)",
                    subtitle: "Click any staged VTS row's Mux & Chapters pill to adjust audio lip-sync delay (ms), Softsub vs. Burn-In captions, and 90 kHz PTS chapter timestamps."
                )
            } else {
                VStack(spacing: 0) {
                    HStack(spacing: 10) {
                        Text("TITLE").font(.system(size: 9, weight: .bold, design: .monospaced)).foregroundStyle(.secondary).frame(width: 48, alignment: .leading)
                        Text("VIDEO STREAM & CHAPTER TOPOLOGY").font(.system(size: 9, weight: .bold, design: .monospaced)).foregroundStyle(.secondary)
                        Spacer()
                        Text("MUX / SUBS / CHAPTERS").font(.system(size: 9, weight: .bold, design: .monospaced)).foregroundStyle(.secondary).frame(width: 195, alignment: .center)
                        Text("SECTORS").font(.system(size: 9, weight: .bold, design: .monospaced)).foregroundStyle(.secondary).frame(width: 82, alignment: .trailing)
                        Text("SIZE").font(.system(size: 9, weight: .bold, design: .monospaced)).foregroundStyle(.secondary).frame(width: 68, alignment: .trailing)
                        Spacer().frame(width: 18)
                    }
                    .padding(.horizontal, 14).padding(.vertical, 6).background(Color.black.opacity(0.18))
                    Divider()

                    ScrollView {
                        VStack(spacing: 0) {
                            ForEach(Array(store.stagedFiles.enumerated()), id: \.element.id) { idx, entry in
                                let mux = muxFor(entry.id)
                                let isExpanded = (expandedMuxEntryID == entry.id)
                                let vProbe = KroutonPantryPrepEngine.probeFile(entry.url)

                                HStack(spacing: 10) {
                                    Text(String(format: "VTS_%02d", idx + 1)).font(.system(size: 11, weight: .bold, design: .monospaced)).foregroundStyle(store.activeAccent).frame(width: 48, alignment: .leading)
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(entry.name).font(.system(size: 12, weight: .semibold)).lineLimit(1)
                                        Text("\(vProbe.shortHardwareBadge) • \(mux.compiledChapters.count) Chapters • \(videoSystemStandard)")
                                            .font(.system(size: 10)).foregroundStyle(.secondary).lineLimit(1)
                                    }
                                    Spacer()
                                    Button {
                                        withAnimation(.easeInOut(duration: 0.16)) {
                                            expandedMuxEntryID = isExpanded ? nil : entry.id
                                        }
                                    } label: {
                                        HStack(spacing: 4) {
                                            Image(systemName: "slider.horizontal.below.rectangle")
                                            Text(mux.muxBadgeSummary)
                                            Image(systemName: isExpanded ? "chevron.up" : "chevron.down").font(.system(size: 8, weight: .bold))
                                        }
                                        .font(.system(size: 9.5, weight: .bold, design: .monospaced))
                                        .padding(.horizontal, 8).padding(.vertical, 3.5)
                                        .background(Color.cyan.opacity(0.16)).foregroundStyle(Color.cyan).clipShape(Capsule())
                                    }.buttonStyle(.plain).frame(width: 195, alignment: .center)

                                    Text("\(entry.sectorsLBA) LBA").font(.system(size: 10, weight: .semibold, design: .monospaced)).foregroundStyle(store.activeAccent).frame(width: 82, alignment: .trailing)
                                    Text(ByteCountFormatter.string(fromByteCount: entry.byteSize, countStyle: .file)).font(.system(size: 11, design: .monospaced)).foregroundStyle(.secondary).frame(width: 68, alignment: .trailing)
                                    Button { store.removeStagedFile(id: entry.id) } label: { Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary) }.buttonStyle(.plain).frame(width: 18)
                                }
                                .padding(.horizontal, 14).padding(.vertical, 7)

                                if isExpanded {
                                    inlineStreamMuxDrawer(for: entry)
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

    @ViewBuilder
    private func inlineStreamMuxDrawer(for entry: KroutonLoafFileEntry) -> some View {
        let binding = Binding<KroutonStreamMuxDescriptor>(
            get: { muxFor(entry.id) },
            set: { streamMuxConfigs[entry.id] = $0 }
        )
        let muxVal = binding.wrappedValue
        let chapters = muxVal.compiledChapters

        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 12) {
                Picker("Audio Track:", selection: binding.audioLanguageCode) {
                    ForEach(["eng", "jpn", "spa", "fra", "deu"], id: \.self) { code in Text(code.uppercased()).tag(code) }
                }.font(.caption).frame(width: 135)

                Text("Lip-Sync Delay: \(String(format: "%+d ms", muxVal.audioDelayMs))")
                    .font(.system(size: 10, weight: .bold, design: .monospaced)).frame(width: 135, alignment: .leading)
                Slider(
                    value: Binding(get: { Double(muxVal.audioDelayMs) }, set: { binding.wrappedValue.audioDelayMs = Int($0.rounded()) }),
                    in: -500...500,
                    step: 25
                ).frame(width: 120)

                Picker("Subtitles:", selection: binding.subtitleMode) {
                    ForEach(KroutonSubtitleDeliveryMode.allCases) { m in Text(m.rawValue).tag(m) }
                }.font(.caption).frame(width: 245)

                Toggle("Forced Flag", isOn: binding.forcedSubtitlesOnly).toggleStyle(.checkbox).font(.caption.bold())
                Spacer()
            }

            HStack(spacing: 8) {
                Text("Timestamps:").font(.caption.bold())
                TextField("00:00:00 Opening | 00:05:00 Act I | 00:12:30 Climax", text: binding.chapterTimestampsRaw)
                    .textFieldStyle(.roundedBorder).font(.system(size: 10.5, design: .monospaced))
                Text(chapters.map { "#\($0.index) \($0.timestampText) (PTS \($0.pts90kHz))" }.prefix(3).joined(separator: " • "))
                    .font(.system(size: 9.5, design: .monospaced)).foregroundStyle(store.uiSecondaryAccent).lineLimit(1)
            }
        }
        .padding(.horizontal, 18).padding(.vertical, 8)
        .background(store.activeAccent.opacity(0.07))
    }
}
