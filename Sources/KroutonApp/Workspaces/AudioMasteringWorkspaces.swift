import VideoOven
import Tartine
import Marmalade
import OpticalDough
import SwiftUI
import UniformTypeIdentifiers
import Foundation

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

    // Sprint 1: Per-Track Inline Crossfade Drawer & AI/ShazamKit Auto-Identified Overrides
    @State private var expandedTransitionTrackID: UUID? = nil
    @State private var trackTransitions: [UUID: KroutonTrackTransitionSpec] = [:]
    @State private var identifiedTitles: [UUID: String] = [:]
    @State private var identifiedPerformers: [UUID: String] = [:]
    @State private var identifiedISRCs: [UUID: String] = [:]
    @State private var autoIDStatusBanner: String = ""

    private var deckHeaderTitle: String {
        switch spec.id {
        case "cd-extra": return "BLUE BOOK 2-SESSION AUDIO + XA DATA DECK"
        case "dts-cd": return "IEC 61937 5.1 DTS-CD SURROUND MASTERING DECK"
        case "dvd-audio": return "DVD-AUDIO HIGH-RESOLUTION MASTERING DECK (24-BIT / 192 kHz MLP)"
        case "sacd-r": return "SCARLET BOOK DSD / SACD-R MASTERING DECK (1-BIT DSD64)"
        case "cd-g": return "RED BOOK CD+G KARAOKE MASTERING DECK (R-W SUBCHANNEL)"
        default: return "RED BOOK CD-DA & CD-TEXT MASTERING DECK (44.1 kHz / 16-BIT PCM)"
        }
    }

    private func transitionFor(_ id: UUID) -> KroutonTrackTransitionSpec {
        trackTransitions[id] ?? KroutonTrackTransitionSpec(
            overlapSeconds: defaultAudioTransition.contains("Crossfade") ? 2.5 : 0.0,
            preGapSeconds: defaultAudioTransition.contains("0.0s") ? 0.0 : 2.0
        )
    }

    private func runAutoIdentifyAllTracks() {
        var newCubes: [KroutonAudioCube] = []
        for (idx, entry) in store.stagedFiles.enumerated() {
            let meta = KroutonTrackAutoIdentifier.identifyTrack(
                url: entry.url,
                trackNumber: idx + 1,
                fallbackPerformer: cdTextAlbumPerformer,
                byteSize: entry.byteSize
            )
            identifiedTitles[entry.id] = meta.title
            identifiedPerformers[entry.id] = meta.performer
            identifiedISRCs[entry.id] = meta.isrcCode
            let tr = transitionFor(entry.id)
            newCubes.append(KroutonAudioCube(
                id: entry.id,
                url: entry.url,
                title: meta.title,
                performer: meta.performer,
                isrcCode: meta.isrcCode,
                durationSeconds: Double(max(18, min(680, Int(entry.byteSize / 36_000)))),
                preGapSeconds: tr.preGapSeconds,
                crossfadeSeconds: tr.overlapSeconds,
                transitionStyle: tr.isCrossfading ? .jamCrossfade : (tr.preGapSeconds <= 0.01 ? .gapless0s : .standard2s)
            ))
        }
        if !newCubes.isEmpty { store.redBookTracks = newCubes }
        autoIDStatusBanner = "ShazamKit + AI Tagged \(store.stagedFiles.count) Track(s)"
    }

    private func moveTrack(at index: Int, delta: Int) {
        let dest = index + delta
        guard dest >= 0 && dest < store.stagedFiles.count else { return }
        store.stagedFiles.swapAt(index, dest)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            audioMasteringDeckHeaderSection

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
                        sfSymbol: "waveform.circle.fill",
                        headline: "Drop Any Audio Format (WAV, AIFF, FLAC, ALAC, DSD, Opus, MP3, M4A)",
                        subtitle: "Click any track boundary pill to sculpt Equal-Power / S-Curve crossfades or run ShazamKit + AI Auto-ID for hardware-safe CD-TEXT."
                    )
                } else {
                    VStack(spacing: 0) {
                        HStack(spacing: 10) {
                            Text("ORDER / TRK").font(.system(size: 9, weight: .bold, design: .monospaced)).foregroundStyle(.secondary).frame(width: 68, alignment: .leading)
                            Text("TRACK TITLE & CD-TEXT PERFORMER").font(.system(size: 9, weight: .bold, design: .monospaced)).foregroundStyle(.secondary)
                            Spacer()
                            Text("ISRC (ISO 3901)").font(.system(size: 9, weight: .bold, design: .monospaced)).foregroundStyle(.secondary).frame(width: 104, alignment: .center)
                            Text("CROSSFADE / SPLICE").font(.system(size: 9, weight: .bold, design: .monospaced)).foregroundStyle(.secondary).frame(width: 155, alignment: .center)
                            Text("MM:SS:FF").font(.system(size: 9, weight: .bold, design: .monospaced)).foregroundStyle(.secondary).frame(width: 78, alignment: .trailing)
                            Text("AUDITION").font(.system(size: 9, weight: .bold, design: .monospaced)).foregroundStyle(.secondary).frame(width: 68, alignment: .center)
                        }
                        .padding(.horizontal, 14).padding(.vertical, 6)
                        .background(Color.black.opacity(0.18))
                        Divider()

                        ScrollView {
                            VStack(spacing: 0) {
                                ForEach(Array(store.stagedFiles.enumerated()), id: \.element.id) { idx, entry in
                                    trackRowView(idx: idx, entry: entry)
                                    if expandedTransitionTrackID == entry.id {
                                        inlineCrossfadeDrawer(for: entry, trackNum: idx + 1)
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

    @ViewBuilder
    private func trackRowView(idx: Int, entry: KroutonLoafFileEntry) -> some View {
        let trackNum = idx + 1
        let dispTitle = identifiedTitles[entry.id] ?? entry.url.deletingPathExtension().lastPathComponent
        let dispPerf = identifiedPerformers[entry.id] ?? cdTextAlbumPerformer
        let dispISRC = identifiedISRCs[entry.id] ?? String(format: "USKRT26%05d", trackNum)
        let estSeconds = max(18, min(680, Int(entry.byteSize / 36_000)))
        let tr = transitionFor(entry.id)
        let isExpanded = (expandedTransitionTrackID == entry.id)
        let isAuditioningThis = (auditioningTrackID == entry.id)

        HStack(spacing: 10) {
            HStack(spacing: 3) {
                VStack(spacing: 1) {
                    Button { moveTrack(at: idx, delta: -1) } label: { Image(systemName: "chevron.up").font(.system(size: 8, weight: .bold)) }
                        .buttonStyle(.plain).disabled(idx == 0)
                    Button { moveTrack(at: idx, delta: 1) } label: { Image(systemName: "chevron.down").font(.system(size: 8, weight: .bold)) }
                        .buttonStyle(.plain).disabled(idx == store.stagedFiles.count - 1)
                }.foregroundStyle(.secondary)
                Text(idx == 0 && enableHiddenTrackOneHTOA ? "00*" : String(format: "%02d", trackNum))
                    .font(.system(size: 12, weight: .heavy, design: .monospaced)).foregroundStyle(store.activeAccent)
            }.frame(width: 68, alignment: .leading)

            VStack(alignment: .leading, spacing: 2) {
                Text(dispTitle).font(.system(size: 12, weight: .semibold)).lineLimit(1)
                let probe = KroutonPantryPrepEngine.probeFile(entry.url)
                Text("Performer: \(dispPerf) • [\(probe.shortHardwareBadge)] -> 44.1 kHz 16-Bit PCM")
                    .font(.system(size: 10)).foregroundStyle(.secondary).lineLimit(1)
            }
            Spacer()
            Text(dispISRC).font(.system(size: 10, weight: .semibold, design: .monospaced)).foregroundStyle(.secondary).frame(width: 104, alignment: .center)

            Button {
                withAnimation(.easeInOut(duration: 0.16)) {
                    expandedTransitionTrackID = isExpanded ? nil : entry.id
                }
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: tr.isCrossfading ? "waveform.path.ecg" : "arrow.left.and.right.Righttriangle.left.righttriangle.right")
                    Text(tr.badgeSummary)
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down").font(.system(size: 8, weight: .bold))
                }
                .font(.system(size: 9.5, weight: .bold, design: .monospaced))
                .padding(.horizontal, 8).padding(.vertical, 3.5)
                .background((tr.isCrossfading ? store.uiSecondaryAccent : Color.cyan).opacity(0.16))
                .foregroundStyle(tr.isCrossfading ? store.uiSecondaryAccent : Color.cyan)
                .clipShape(Capsule())
            }
            .buttonStyle(.plain).frame(width: 155, alignment: .center)

            Text(String(format: "%02d:%02d:%02d", estSeconds / 60, estSeconds % 60, (idx * 17) % 75))
                .font(.system(size: 11, weight: .bold, design: .monospaced)).foregroundStyle(store.activeAccent).frame(width: 78, alignment: .trailing)

            Button {
                auditioningTrackID = isAuditioningThis ? nil : entry.id
                if !isAuditioningThis { KroutonOSDesktopBridge.playAcousticCue() }
            } label: {
                Text(isAuditioningThis ? "Stop" : "Splice")
                    .font(.system(size: 9, weight: .bold)).padding(.horizontal, 8).padding(.vertical, 3)
                    .background(isAuditioningThis ? Color.green : store.activeAccent.opacity(0.18))
                    .foregroundStyle(isAuditioningThis ? Color.black : store.activeAccent).clipShape(Capsule())
            }.buttonStyle(.plain).frame(width: 52)

            Button { store.removeStagedFile(id: entry.id) } label: { Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary) }.buttonStyle(.plain)
        }
        .padding(.horizontal, 14).padding(.vertical, 7)
    }

    @ViewBuilder
    private func inlineCrossfadeDrawer(for entry: KroutonLoafFileEntry, trackNum: Int) -> some View {
        let binding = Binding<KroutonTrackTransitionSpec>(
            get: { transitionFor(entry.id) },
            set: { trackTransitions[entry.id] = $0 }
        )
        let specVal = binding.wrappedValue

        HStack(spacing: 14) {
            Canvas { context, size in
                var outPath = Path()
                var inPath = Path()
                for step in 0...40 {
                    let t = Double(step) / 40.0
                    let x = size.width * CGFloat(t)
                    let yOut = size.height * (1.0 - CGFloat(specVal.fadeOutCurve.gainOut(at: t)))
                    let yIn = size.height * (1.0 - CGFloat(specVal.fadeInCurve.gainIn(at: t)))
                    if step == 0 {
                        outPath.move(to: CGPoint(x: x, y: yOut))
                        inPath.move(to: CGPoint(x: x, y: yIn))
                    } else {
                        outPath.addLine(to: CGPoint(x: x, y: yOut))
                        inPath.addLine(to: CGPoint(x: x, y: yIn))
                    }
                }
                context.stroke(outPath, with: .color(store.activeAccent), lineWidth: 2.0)
                context.stroke(inPath, with: .color(store.uiSecondaryAccent), lineWidth: 2.0)
            }
            .frame(width: 150, height: 48)
            .padding(6).background(Color.black.opacity(0.32)).clipShape(RoundedRectangle(cornerRadius: 6))

            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 12) {
                    Text("Track \(trackNum) -> \(trackNum + 1) Overlap: \(String(format: "%.1fs", specVal.overlapSeconds)) (\(specVal.overlapRedBookFrames) Frames)")
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                    Slider(value: binding.overlapSeconds, in: 0.0...15.0, step: 0.5).frame(width: 130)
                    Text("INDEX 00 Pre-Gap: \(String(format: "%.1fs", specVal.preGapSeconds))")
                        .font(.system(size: 10, design: .monospaced)).foregroundStyle(.secondary)
                    Slider(value: binding.preGapSeconds, in: 0.0...4.0, step: 0.5).frame(width: 90).disabled(specVal.isCrossfading)
                }
                HStack(spacing: 12) {
                    Picker("Fade-Out:", selection: binding.fadeOutCurve) {
                        ForEach(KroutonCrossfadeCurve.allCases) { c in Text(c.rawValue).tag(c) }
                    }.font(.caption).frame(width: 220)
                    Picker("Fade-In:", selection: binding.fadeInCurve) {
                        ForEach(KroutonCrossfadeCurve.allCases) { c in Text(c.rawValue).tag(c) }
                    }.font(.caption).frame(width: 220)
                    Spacer()
                }
            }
        }
        .padding(.horizontal, 18).padding(.vertical, 8)
        .background(store.activeAccent.opacity(0.07))
    }

    @ViewBuilder
    private var audioMasteringDeckHeaderSection: some View {
        KroutonMasteringDeckCard(store: store) {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    Image(systemName: spec.sfSymbol).foregroundStyle(store.activeAccent)
                    Text(deckHeaderTitle).font(.system(size: 10, weight: .heavy, design: .monospaced)).foregroundStyle(.secondary).lineLimit(1)
                    Spacer(minLength: 4)
                    if !autoIDStatusBanner.isEmpty {
                        Text(autoIDStatusBanner).font(.system(size: 9, weight: .bold, design: .monospaced)).foregroundStyle(.green)
                    }
                    Button {
                        store.stampProjectTracklistOrManifestOnDisc()
                        autoIDStatusBanner = "Synced Tracklist to Disc Label Studio"
                    } label: {
                        Label("Sync to Label", systemImage: "opticaldisc").font(.system(size: 10, weight: .bold))
                    }.buttonStyle(.bordered).controlSize(.small)
                    Button {
                        runAutoIdentifyAllTracks()
                    } label: {
                        Label("Auto-ID CD-TEXT", systemImage: "wand.and.stars").font(.system(size: 10, weight: .bold))
                    }.buttonStyle(.borderedProminent).tint(store.uiSecondaryAccent).controlSize(.small)

                    Button {
                        showMarmaladeCuePopover.toggle()
                    } label: {
                        let packs = store.computeLiveMarmaladeCDTextPackCount(albumTitle: cdTextAlbumTitle, albumPerformer: cdTextAlbumPerformer, tracks: store.redBookTracks)
                        Label(".CUE (\(packs) Packs)", systemImage: "doc.text.magnifyingglass").font(.system(size: 10, weight: .bold, design: .monospaced))
                    }
                    .buttonStyle(.bordered).controlSize(.small)
                    .popover(isPresented: $showMarmaladeCuePopover, arrowEdge: .bottom) {
                        KroutonMarmaladeCuePopoverView(store: store, cdTextAlbumTitle: cdTextAlbumTitle, cdTextAlbumPerformer: cdTextAlbumPerformer, cdTextUPCBarcode: cdTextUPCBarcode)
                    }
                }

                HStack(spacing: 10) {
                    Text("Album:").font(.caption.bold())
                    TextField("ALBUM TITLE", text: $cdTextAlbumTitle).textFieldStyle(.roundedBorder)
                    Text("Artist:").font(.caption.bold())
                    TextField("PERFORMER", text: $cdTextAlbumPerformer).textFieldStyle(.roundedBorder)
                    Text("UPC/MCN:").font(.caption.bold())
                    TextField("012345678905", text: $cdTextUPCBarcode).textFieldStyle(.roundedBorder).font(.system(size: 11, design: .monospaced)).frame(width: 115)
                    Toggle("HTOA (INDEX 00)", isOn: $enableHiddenTrackOneHTOA).toggleStyle(.checkbox).font(.caption.bold())
                }
            }
        }
    }
}
