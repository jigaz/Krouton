import SwiftUI
import AudioKit

struct SpliceWorkspaceView: View {
    let trackNumber: Int
    var totalTransitions: Int = 1
    let outgoingTitle: String
    let incomingTitle: String
    let spec: KroutonTrackTransitionSpec
    let outgoing: TrackAnalysis?
    let incoming: TrackAnalysis?
    var primaryColor: Color = Color(red: 0.38, green: 0.56, blue: 0.84)
    var harmonyColor: Color = Color(red: 0.98, green: 0.36, blue: 0.76)
    var isFloatingWindow: Bool = false
    var onStepTransition: (Int) -> Void = { _ in }
    let onPreview: (KroutonTrackTransitionSpec) -> Void
    let onCommit: (KroutonTrackTransitionSpec) -> Void
    let onAudition: () -> Void

    @Environment(\.openWindow) private var openWindow
    @Environment(\.dismissWindow) private var dismissWindow
    @ObservedObject private var montageState = TrackMontageWindowState.shared

    @State private var comparison = ABComparison()
    @State private var showSum = false
    @State private var superimposed = true
    @State private var highlightLoudFrames = false
    @State private var dragStartHeightScale: Double? = nil

    private var palette: SplicePalette {
        SplicePalette(outgoing: primaryColor, incoming: harmonyColor, highlight: .yellow)
    }

    private var snapshot: SpliceCanvasSnapshot {
        SpliceCanvasSnapshot(
            spec: spec,
            outgoingTail: outgoing?.tailPeaks,
            incomingHead: incoming?.headPeaks,
            superimposed: superimposed,
            showSum: showSum,
            highlightLoudFrames: highlightLoudFrames,
            horizontalZoom: montageState.horizontalZoom,
            isMiniGhostMode: !isFloatingWindow && montageState.isFloatingWindowOpen
        )
    }

    private var peakReadout: String {
        guard let outgoing, let incoming,
              let bound = SpliceOverlapMath.peakUpperBound(outgoingTail: outgoing.tailPeaks, incomingHead: incoming.headPeaks, spec: spec),
              let decibels = SpliceOverlapMath.dBFS(bound) else { return "Sum peak: n/a" }
        return String(format: "Sum peak ≤ %+.1f dBFS", decibels)
    }

    var body: some View {
        if !isFloatingWindow && montageState.isFloatingWindowOpen {
            // 25% current height ghosted, non-editable mini duplicate waveform with no controls or labels
            GeometryReader { proxy in
                let miniGeom = SpliceCanvasGeometry(
                    size: proxy.size,
                    spec: spec,
                    horizontalZoom: montageState.horizontalZoom
                )
                SpliceWaveformCanvas(snapshot: snapshot, geometry: miniGeom, palette: palette)
                    .equatable()
            }
            .frame(height: montageState.miniGhostCanvasHeight)
            .background(Color(red: 0.05, green: 0.06, blue: 0.08).opacity(0.55))
            .clipShape(RoundedRectangle(cornerRadius: 6))
            .opacity(0.46)
            .allowsHitTesting(false)
            .padding(.horizontal, 16)
            .padding(.vertical, 6)
        } else {
            VStack(alignment: .leading, spacing: 8) {
                SpliceHeaderBar(
                    trackNumber: trackNumber,
                    totalTransitions: totalTransitions,
                    snapshot: snapshot,
                    peakReadout: peakReadout,
                    activeSlot: comparison.active,
                    primaryColor: primaryColor,
                    isFloatingWindow: isFloatingWindow,
                    onSelectMode: { onCommit(spec.switched(to: $0)) },
                    onSelectSlot: { onCommit(comparison.switchSlot(to: $0, current: spec)) },
                    onAddSubIndex: {
                        var updated = spec
                        let existing = updated.subIndexRatios
                        let candidate = existing.isEmpty ? 0.22 : min(0.92, (existing.last ?? 0.22) + 0.16)
                        updated.subIndexRatios.append(candidate)
                        updated.subIndexRatios.sort()
                        onCommit(updated)
                    },
                    onStepTransition: onStepTransition,
                    onToggleFloatingWindow: {
                        if isFloatingWindow {
                            montageState.triggerFooshTransition(openingFloating: false) {
                                montageState.isFloatingWindowOpen = false
                                dismissWindow(id: "track-montage")
                            }
                        } else {
                            openWindow(id: "track-montage")
                            montageState.triggerFooshTransition(openingFloating: true) {
                                montageState.isFloatingWindowOpen = true
                            }
                        }
                    }
                )

                if isFloatingWindow {
                    SpliceCanvasArea(
                        snapshot: snapshot,
                        palette: palette,
                        trackNumber: trackNumber,
                        outgoingTitle: outgoingTitle,
                        incomingTitle: incomingTitle,
                        onPreview: onPreview,
                        onCommit: onCommit
                    )
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .frame(minHeight: 110)
                } else {
                    SpliceCanvasArea(
                        snapshot: snapshot,
                        palette: palette,
                        trackNumber: trackNumber,
                        outgoingTitle: outgoingTitle,
                        incomingTitle: incomingTitle,
                        onPreview: onPreview,
                        onCommit: onCommit
                    )
                    .frame(height: montageState.scaledCanvasHeight)

                    // Inline-only Drag Resizer Handle (50% - 200% vertical height adjustment)
                    HStack {
                        Spacer()
                        Capsule()
                            .fill(Color.secondary.opacity(0.35))
                            .frame(width: 42, height: 4)
                        Spacer()
                    }
                    .frame(height: 8)
                    .contentShape(Rectangle())
                    .gesture(
                        DragGesture(minimumDistance: 1)
                            .onChanged { val in
                                if dragStartHeightScale == nil {
                                    dragStartHeightScale = montageState.heightScale
                                }
                                let base = dragStartHeightScale ?? 1.0
                                let deltaScale = Double(val.translation.height / TrackMontageWindowState.baseCanvasHeight)
                                montageState.heightScale = min(2.0, max(0.5, base + deltaScale))
                            }
                            .onEnded { _ in
                                dragStartHeightScale = nil
                            }
                    )
                    .help("Drag vertically to resize inline Track Montage Editor height")
                }

                SpliceControlsBar(
                    snapshot: snapshot,
                    superimposed: $superimposed,
                    showSum: $showSum,
                    highlightLoudFrames: $highlightLoudFrames,
                    onPreview: onPreview,
                    onCommit: onCommit,
                    onAudition: onAudition
                )
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .modifier(KroutonGPUFooshTransitionModifier(phase: montageState.fooshPhase, isFloatingSurface: isFloatingWindow))
        }
    }
}

struct ABComparison: Equatable {
    enum Slot: String, CaseIterable { case a = "A", b = "B" }
    private(set) var active: Slot = .a
    private var stored: [Slot: KroutonTrackTransitionSpec] = [:]

    mutating func switchSlot(to slot: Slot, current: KroutonTrackTransitionSpec) -> KroutonTrackTransitionSpec {
        stored[active] = current
        active = slot
        return stored[slot] ?? current
    }
}

/// Independent Floating Window View for the Track Montage Editor (Normal Resizable & Fullscreen-Capable Window)
public struct KroutonFloatingTrackMontageWindowView: View {
    @ObservedObject var store: KroutonStateStore
    @ObservedObject private var montageState = TrackMontageWindowState.shared
    @ObservedObject private var auditioner = SpliceAudioAuditioner.shared

    public init(store: KroutonStateStore) {
        self.store = store
    }

    private var controller: AudioProjectController { store.audioController }
    private var project: AudioProject { controller.project }

    private var resolvedTrackIndex: Int {
        if let id = montageState.activeTrackID,
           let idx = project.tracks.firstIndex(where: { $0.id == id }),
           idx < max(0, project.tracks.count - 1) {
            return idx
        }
        return 0
    }

    public var body: some View {
        Group {
            if project.tracks.count >= 2 {
                let idx = resolvedTrackIndex
                let totalTransitions = max(1, project.tracks.count - 1)
                let track = project.tracks[idx]
                let trackID = track.id
                let nextTrack = project.track(after: trackID)
                let outTitle = track.title.isEmpty ? track.source.deletingPathExtension().lastPathComponent : track.title
                let inTitle = nextTrack.map { $0.title.isEmpty ? $0.source.deletingPathExtension().lastPathComponent : $0.title } ?? "Lead-Out"

                SpliceWorkspaceView(
                    trackNumber: idx + 1,
                    totalTransitions: totalTransitions,
                    outgoingTitle: outTitle,
                    incomingTitle: inTitle,
                    spec: controller.transition(after: trackID),
                    outgoing: controller.readyAnalysis(trackID),
                    incoming: nextTrack.flatMap { controller.readyAnalysis($0.id) },
                    primaryColor: store.activeAccent,
                    harmonyColor: store.uiSecondaryAccent,
                    isFloatingWindow: true,
                    onStepTransition: { delta in
                        let nextIdx = min(max(0, idx + delta), totalTransitions - 1)
                        montageState.activeTrackID = project.tracks[nextIdx].id
                    },
                    onPreview: { controller.preview($0, after: trackID) },
                    onCommit: { controller.commitTransition($0, after: trackID) },
                    onAudition: {
                        auditioner.startTransitionAudition(
                            trackID: trackID,
                            outgoingURL: track.source,
                            incomingURL: nextTrack?.source,
                            spec: controller.transition(after: trackID)
                        )
                    }
                )
            } else {
                VStack(spacing: 10) {
                    Image(systemName: "waveform.path.ecg.rectangle.fill")
                        .font(.system(size: 32))
                        .foregroundStyle(store.activeAccent)
                    Text("Track Montage Editor")
                        .font(.headline)
                    Text("Stage at least two audio tracks in the Audio CD deck to edit transitions and crossfades.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(24)
            }
        }
        .frame(minWidth: 860, maxWidth: .infinity, minHeight: 220, maxHeight: .infinity)
        .background(Color.kroutonWindowSurface)
        .preferredColorScheme(store.resolvedColorScheme)
        .onAppear {
            montageState.isFloatingWindowOpen = true
        }
        .onDisappear {
            montageState.isFloatingWindowOpen = false
        }
    }
}
