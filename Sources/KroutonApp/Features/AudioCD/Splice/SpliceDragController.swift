import AudioKit
import SwiftUI

@MainActor
// MARK: - SpliceDragController

public final class TrackMontageWindowState: ObservableObject {
    public static let shared = TrackMontageWindowState()
    @Published public var isFloatingWindowOpen: Bool = false
    @Published public var activeTrackID: UUID? = nil
    /// GPU-backed "foosh" warp phase: 0.0 = resting, 1.0 = mid-flight launch/dock impulse
    @Published public var fooshPhase: Double = 0.0
    /// Vertical height multiplier: 0.50 (50%) ... 2.00 (200%), base height = 174 pt
    @Published public var heightScale: Double = 1.0
    /// Horizontal zoom factor: 3.0 (default 11.3s precision span) or 1.0 (Zoom Out 34s concert span)
    @Published public var horizontalZoom: Double = 3.0
    public static let baseCanvasHeight: CGFloat = 174.0

    public var scaledCanvasHeight: CGFloat {
        Self.baseCanvasHeight * CGFloat(max(0.50, min(2.00, heightScale)))
    }
    public var miniGhostCanvasHeight: CGFloat {
        Self.baseCanvasHeight * 0.25
    }

    /// Triggers a GPU-composited "foosh" launch or dock animation across the inline & floating views
    public func triggerFooshTransition(openingFloating: Bool, action: @escaping @MainActor () -> Void) {
        withAnimation(.spring(response: 0.22, dampingFraction: 0.68)) {
            fooshPhase = openingFloating ? 1.0 : -1.0
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.13) {
            withAnimation(.spring(response: 0.34, dampingFraction: 0.76)) {
                action()
                self.fooshPhase = 0.0
            }
        }
    }
}

/// GPU-backed Metal offscreen (`drawingGroup`) 3D perspective + scale + blur "foosh" transition modifier
public struct KroutonGPUFooshTransitionModifier: ViewModifier {
    let phase: Double
    let isFloatingSurface: Bool

    public func body(content: Content) -> some View {
        let mag = abs(phase)
        let scaleX: CGFloat = 1.0 - CGFloat(mag * 0.14)
        let scaleY: CGFloat = 1.0 - CGFloat(mag * 0.32)
        let yShift: CGFloat = CGFloat(phase) * (isFloatingSurface ? 28.0 : -34.0)
        let tiltDeg: Double = phase * (isFloatingSurface ? -14.0 : 16.0)

        content
            .drawingGroup(opaque: false)
            .scaleEffect(x: max(0.5, scaleX), y: max(0.35, scaleY), anchor: .center)
            .rotation3DEffect(
                .degrees(tiltDeg),
                axis: (x: 1.0, y: 0.0, z: 0.0),
                perspective: 0.45
            )
            .offset(y: yShift)
            .blur(radius: CGFloat(mag * 6.5))
            .opacity(1.0 - mag * 0.42)
    }
}

struct SpliceDragModifier: ViewModifier {
    let spec: KroutonTrackTransitionSpec
    @Binding var hoverPoint: CGPoint?
    @Binding var activeTarget: SpliceDragTarget?
    @Binding var hoveredHiddenMidTarget: SpliceDragTarget?
    let geometry: SpliceCanvasGeometry
    let onPreview: (KroutonTrackTransitionSpec) -> Void
    let onCommit: (_ old: KroutonTrackTransitionSpec, _ new: KroutonTrackTransitionSpec) -> Void

    @State private var session: SpliceDragSession?
    @State private var hovered: SpliceDragTarget?
    @State private var fineControl = false

    func body(content: Content) -> some View {
        let base = content
            .contentShape(Rectangle())
            .gesture(dragGesture)
            .simultaneousGesture(doubleTapResetGesture)
            .simultaneousGesture(singleTapSpawnMidHandleGesture)
            .onContinuousHover(coordinateSpace: .local) { phase in
                switch phase {
                case .active(let point):
                    hoverPoint = point
                    let hit = geometry.hitTest(point)
                    hovered = hit
                    activeTarget = session?.target ?? hit
                    hoveredHiddenMidTarget = (spec.isCrossfading && hit == .curveBody)
                        ? geometry.hitTestHiddenMidCurveVicinity(point)
                        : nil
                case .ended:
                    hoverPoint = nil
                    hovered = nil
                    activeTarget = session?.target
                    hoveredHiddenMidTarget = nil
                }
            }
        if #available(macOS 15.0, *) {
            base
                .onModifierKeysChanged(mask: .option) { _, new in fineControl = new.contains(.option) }
                .pointerStyle(pointerStyle(for: session?.target ?? hovered ?? hoveredHiddenMidTarget))
        } else {
            base
        }
    }

    private var dragGesture: some Gesture {
        DragGesture(minimumDistance: 2, coordinateSpace: .local)
            .onChanged { value in
                hoverPoint = value.location
                if session == nil {
                    session = SpliceDragSession(start: value.startLocation, spec: spec, geometry: geometry)
                    activeTarget = session?.target
                }
                guard var active = session else { return }
                let updated = active.spec(location: value.location, translation: value.translation, fine: fineControl)
                session = active
                onPreview(updated)
            }
            .onEnded { _ in
                if let finished = session, finished.startSpec != spec {
                    onCommit(finished.startSpec, spec)
                }
                session = nil
                activeTarget = hovered
            }
    }

    /// Single-click in the hidden vicinity of the Fade-Out (t=0.25) or Fade-In (t=0.75) curve midpoint spawns that handle.
    private var singleTapSpawnMidHandleGesture: some Gesture {
        SpatialTapGesture(count: 1, coordinateSpace: .local)
            .onEnded { event in
                guard spec.isCrossfading,
                      let hiddenTarget = geometry.hitTestHiddenMidCurveVicinity(event.location) else { return }
                let old = spec
                var updated = spec
                switch hiddenTarget {
                case .fadeOutMidHandle:
                    if updated.fadeOutMidTrim == nil { updated.fadeOutMidTrim = 0.0 }
                case .fadeInMidHandle:
                    if updated.fadeInMidTrim == nil { updated.fadeInMidTrim = 0.0 }
                default:
                    break
                }
                if updated != old {
                    onCommit(old, updated)
                }
            }
    }

    /// Double-clicking an added mid-curve handle removes ONLY that handle and snaps that curve back to normal.
    private var doubleTapResetGesture: some Gesture {
        SpatialTapGesture(count: 2, coordinateSpace: .local)
            .onEnded { event in
                let old = spec
                var updated = spec
                switch geometry.hitTest(event.location) {
                case .fadeOutMidHandle?:
                    updated.fadeOutMidTrim = nil
                case .fadeInMidHandle?:
                    updated.fadeInMidTrim = nil
                case .indexFlag?:
                    updated.spliceIndex01Ratio = 0.50
                case .subIndexFlag(let idx)?:
                    if updated.subIndexRatios.indices.contains(idx) {
                        updated.subIndexRatios.remove(at: idx)
                    }
                case .fadeOutRail?, .fadeInRail?:
                    if updated.isCrossfading { updated.overlapSeconds = 2.5 }
                    else if updated.preGapSeconds > 0.01 { updated.preGapSeconds = 2.0 }
                case .curveBody?, nil:
                    updated.curveTension = 0.0
                    updated.spliceIndex01Ratio = 0.50
                }
                if updated != old {
                    onCommit(old, updated)
                }
            }
    }

    @available(macOS 15.0, *)
    private func pointerStyle(for target: SpliceDragTarget?) -> PointerStyle? {
        switch target {
        case .indexFlag?, .subIndexFlag?, .fadeOutRail?, .fadeInRail?: return .columnResize
        case .fadeOutMidHandle?, .fadeInMidHandle?: return .rowResize
        case .curveBody?: return session == nil ? .grabIdle : .grabActive
        case nil: return nil
        }
    }
}
