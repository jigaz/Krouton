import CoreGraphics
import Foundation

// MARK: - Overlap Peaks

/// The peak of each CD frame of a stretch of audio, as the analysis reads it. Two values
/// are equal only when they are the same analysis (`id`), so comparing them is cheap.
public struct FramePeaks: Equatable, Sendable {
    /// Identifies the analysis these peaks came from.
    public let id: UUID
    /// One peak per CD frame, 0 to 1.
    public let values: [Float]
    /// The highest of `values`.
    public let maximum: Float

    public init(values: [Float]) {
        self.id = UUID()
        self.values = values
        self.maximum = values.max() ?? 0
    }

    public static func == (lhs: FramePeaks, rhs: FramePeaks) -> Bool { lhs.id == rhs.id }
}

/// Predicts how loud a crossfade gets.
public enum SpliceOverlapMath {
    /// An upper bound for the peak of the mixed overlap, from each frame's peaks and the larger
    /// gain at either edge of the frame. Nil when not crossfading or when the peaks don't cover the
    /// overlap.
    public static func peakUpperBound(
        outgoingTail: FramePeaks,
        incomingHead: FramePeaks,
        spec: KroutonTrackTransitionSpec
    ) -> Double? {
        guard spec.isCrossfading else { return nil }
        let frames = Int(spec.overlapRedBookFrames)
        guard frames > 0, outgoingTail.values.count >= frames, incomingHead.values.count >= frames else { return nil }

        let tailStart = outgoingTail.values.count - frames
        var peak = 0.0
        var gainOutAtStart = spec.effectiveGainOut(at: 0)
        var gainInAtStart = spec.effectiveGainIn(at: 0)
        for k in 0..<frames {
            let t1 = Double(k + 1) / Double(frames)
            let gainOutAtEnd = spec.effectiveGainOut(at: t1)
            let gainInAtEnd = spec.effectiveGainIn(at: t1)
            let out = Double(outgoingTail.values[tailStart + k]) * max(gainOutAtStart, gainOutAtEnd)
            let incoming = Double(incomingHead.values[k]) * max(gainInAtStart, gainInAtEnd)
            peak = max(peak, out + incoming)
            gainOutAtStart = gainOutAtEnd
            gainInAtStart = gainInAtEnd
        }
        return peak
    }

    /// `linear` in dB relative to full scale; nil for 0.
    public static func dBFS(_ linear: Double) -> Double? {
        linear > 0 ? 20 * log10(linear) : nil
    }
}

// MARK: - Splice Editor Geometry and Sub-Index Marks

/// One extra index mark in the splice editor.
public struct SpliceSubIndexDescriptor: Identifiable, Equatable, Sendable {
    public var id: Int { arrayIndex }
    /// Index into `spec.subIndexRatios`, so a drag changes the right mark.
    let arrayIndex: Int
    /// X position on the canvas.
    public let x: CGFloat
    /// Position as a fraction of the canvas (0.05 to 0.95).
    public let ratio: Double
    /// True when the mark is right of INDEX 01, so it belongs to the next track.
    public let isIncomingTrack: Bool
    /// Its index number within its track: 2 for INDEX 02, 3 for INDEX 03 and so on.
    public let redBookIndexNumber: Int
}

/// Where everything in the splice editor is drawn for a transition at a canvas size and zoom: the
/// overlap zone, INDEX 01, index marks and curve handles. Pure geometry, shared by drawing and hit
/// testing.
public struct SpliceCanvasGeometry: Equatable, Sendable {
    static let baseTimelineSpanSeconds: Double = 15.0
    /// The height of the ruler with the index flags.
    public static let rulerHeight: CGFloat = 24
    static let handleSlop: CGFloat = 10

    /// The canvas size.
    public let size: CGSize
    /// The zoom factor.
    public let horizontalZoom: Double
    /// Seconds shown across the canvas at this zoom.
    public let effectiveSpanSeconds: Double
    /// The overlap zone's left edge.
    public let zoneX0: CGFloat
    /// The overlap zone's right edge.
    public let zoneX1: CGFloat
    /// INDEX 01's position.
    public let index01X: CGFloat
    let index01RatioInCanvas: Double
    let subIndexXs: [CGFloat]
    /// The extra index marks.
    public let subIndexDescriptors: [SpliceSubIndexDescriptor]
    /// The curve-body handle.
    public let centerHandle: CGPoint
    public let fadeOutMidAnchor: CGPoint
    public let fadeOutQ3Anchor: CGPoint
    public let fadeInQ1Anchor: CGPoint
    public let fadeInMidAnchor: CGPoint
    /// The fade-out's quarter handle, when it is in use.
    public let fadeOutMidHandle: CGPoint?
    public let fadeOutQ3Handle: CGPoint?
    public let fadeInQ1Handle: CGPoint?
    public let fadeInMidHandle: CGPoint?
    /// The span to draw while the overlap is being stretched, if it is.
    public let rubberBandSpan: Double?

    /// Lays out the editor for `spec`.
    public init(size: CGSize, spec: KroutonTrackTransitionSpec, horizontalZoom: Double = 1.0, rubberBandSpan: Double? = nil) {
        self.rubberBandSpan = rubberBandSpan
        let w = max(180, size.width), h = max(36, size.height)
        self.size = CGSize(width: w, height: h)
        let zoom = max(1.0, min(3.0, horizontalZoom))
        self.horizontalZoom = zoom
        let rawSpan = Self.baseTimelineSpanSeconds / zoom
        let baseSpan = rubberBandSpan ?? (spec.isCrossfading ? max(rawSpan, spec.overlapSeconds * 1.25) : rawSpan)
        self.effectiveSpanSeconds = baseSpan

        if !spec.isCrossfading && spec.preGapSeconds <= 0.01 {
            let midX = w * 0.5
            zoneX0 = midX
            zoneX1 = midX
            index01X = midX
        } else if spec.isCrossfading {
            let activeSpan = effectiveSpanSeconds
            let half: Double
            if rubberBandSpan != nil {
                half = (spec.overlapSeconds / activeSpan) * 0.36
            } else if zoom >= 2.0 {
                half = 0.36
            } else {
                half = max(0.14, min(0.22, (spec.overlapSeconds / activeSpan) * 0.46))
            }
            let baseHalf = max(0.08, min(0.47, half))
            let baseLeft = 0.5 - baseHalf
            let baseRight = 0.5 + baseHalf
            let left = baseLeft + (spec.asymmetricUnlinked ? spec.fadeOutStartRatio * 0.22 : 0)
            let right = baseRight - (spec.asymmetricUnlinked ? (1 - spec.fadeInEndRatio) * 0.22 : 0)
            zoneX0 = w * CGFloat(max(0.06, min(0.46, left)))
            zoneX1 = w * CGFloat(min(0.94, max(0.54, right)))
            let zoneW = max(24, zoneX1 - zoneX0)
            index01X = zoneX0 + zoneW * CGFloat(spec.spliceIndex01Ratio)
        } else {
            let gapHalf = max(0.05, min(0.32, (spec.preGapSeconds / 6.0) * 0.32))
            zoneX0 = w * CGFloat(0.5 - gapHalf)
            zoneX1 = w * CGFloat(0.5 + gapHalf)
            index01X = zoneX1
        }
        let idx01Norm = Double(index01X / max(1, w))
        self.index01RatioInCanvas = idx01Norm

        let zoneW = max(24, zoneX1 - zoneX0)
        let bodyH = max(16, h - Self.rulerHeight)
        func yForGain(_ g: Double) -> CGFloat {
            Self.rulerHeight + bodyH * (1 - CGFloat(min(1, max(0, g)) * 0.86 + 0.07))
        }
        let midGain = 0.5 * (spec.effectiveGainOut(at: 0.5) + spec.effectiveGainIn(at: 0.5))
        centerHandle = CGPoint(x: zoneX0 + zoneW * 0.5, y: h * CGFloat(1 - min(0.90, max(0.12, midGain))))

        let outQ1Point = CGPoint(x: zoneX0 + zoneW * 0.25, y: yForGain(spec.effectiveGainOut(at: 0.25)))
        let outQ3Point = CGPoint(x: zoneX0 + zoneW * 0.75, y: yForGain(spec.effectiveGainOut(at: 0.75)))
        let inQ1Point  = CGPoint(x: zoneX0 + zoneW * 0.25, y: yForGain(spec.effectiveGainIn(at: 0.25)))
        let inQ3Point  = CGPoint(x: zoneX0 + zoneW * 0.75, y: yForGain(spec.effectiveGainIn(at: 0.75)))
        fadeOutMidAnchor = outQ1Point
        fadeOutQ3Anchor  = outQ3Point
        fadeInQ1Anchor   = inQ1Point
        fadeInMidAnchor  = inQ3Point
        fadeOutMidHandle = spec.fadeOutMidTrim != nil ? outQ1Point : nil
        fadeOutQ3Handle  = spec.fadeOutThreeQuarterTrim != nil ? outQ3Point : nil
        fadeInQ1Handle   = spec.fadeInQuarterTrim != nil ? inQ1Point : nil
        fadeInMidHandle  = spec.fadeInMidTrim != nil ? inQ3Point : nil

        let rawXs = spec.subIndexRatios.map { ratio in
            w * CGFloat(max(0.05, min(0.95, ratio)))
        }
        self.subIndexXs = rawXs

        // Partition by INDEX 01 boundary and number chronologically left-to-right within each track!
        let indexed = spec.subIndexRatios.enumerated().map { (idx, r) -> (Int, Double, CGFloat) in
            let clamped = max(0.05, min(0.95, r))
            return (idx, clamped, w * CGFloat(clamped))
        }.sorted { $0.1 < $1.1 }

        var outCounter = 2
        var inCounter = 2
        var descriptors: [SpliceSubIndexDescriptor] = []
        for (origIdx, ratio, xPos) in indexed {
            let isIncoming = (xPos > index01X)
            let num: Int
            if isIncoming {
                num = inCounter
                inCounter += 1
            } else {
                num = outCounter
                outCounter += 1
            }
            descriptors.append(SpliceSubIndexDescriptor(
                arrayIndex: origIdx,
                x: xPos,
                ratio: ratio,
                isIncomingTrack: isIncoming,
                redBookIndexNumber: min(99, num)
            ))
        }
        self.subIndexDescriptors = descriptors
    }

    /// What a click at `p` grabs: an index flag on the ruler, a curve handle, a zone edge, or the
    /// curve body.
    public func hitTest(_ p: CGPoint) -> SpliceDragTarget? {
        if p.y < Self.rulerHeight {
            for desc in subIndexDescriptors where abs(p.x - desc.x) <= Self.handleSlop * 1.6 {
                return .subIndexFlag(desc.arrayIndex)
            }
            if abs(p.x - index01X) <= Self.handleSlop * 1.8 { return .indexFlag }
        }
        let activeHandles: [(CGPoint?, SpliceDragTarget)] = [
            (fadeOutMidHandle, .fadeOutMidHandle),
            (fadeOutQ3Handle, .fadeOutQ3Handle),
            (fadeInQ1Handle, .fadeInQ1Handle),
            (fadeInMidHandle, .fadeInMidHandle)
        ]
        if let nearest = activeHandles
            .compactMap({ pt, target in pt.map { (hypot(p.x - $0.x, p.y - $0.y), target) } })
            .filter({ $0.0 <= Self.handleSlop * 1.45 })
            .min(by: { $0.0 < $1.0 }) {
            return nearest.1
        }
        let d0 = abs(p.x - zoneX0), d1 = abs(p.x - zoneX1)
        if min(d0, d1) <= Self.handleSlop { return d0 <= d1 ? .fadeOutRail : .fadeInRail }
        if p.x > zoneX0, p.x < zoneX1, p.y >= Self.rulerHeight { return .curveBody }
        return nil
    }

    /// The hidden curve handle within 18 pt of `p`, if any: a quarter-point handle that isn't
    /// shown yet, which a click there creates.
    public func hitTestHiddenMidCurveVicinity(_ p: CGPoint) -> SpliceDragTarget? {
        guard p.y >= Self.rulerHeight, zoneX1 - zoneX0 > 32 else { return nil }
        let radius: CGFloat = 18.0
        let candidates: [( Bool, CGPoint, SpliceDragTarget )] = [
            (fadeOutMidHandle == nil, fadeOutMidAnchor, .fadeOutMidHandle),
            (fadeOutQ3Handle == nil,  fadeOutQ3Anchor,  .fadeOutQ3Handle),
            (fadeInQ1Handle == nil,   fadeInQ1Anchor,   .fadeInQ1Handle),
            (fadeInMidHandle == nil,  fadeInMidAnchor,  .fadeInMidHandle)
        ]
        return candidates
            .filter { $0.0 }
            .map { (hypot(p.x - $0.1.x, p.y - $0.1.y), $0.2) }
            .filter { $0.0 <= radius }
            .min(by: { $0.0 < $1.0 })?.1
    }
}

/// What a drag in the splice editor moves.
public enum SpliceDragTarget: Equatable, Sendable {
    case indexFlag
    case subIndexFlag(Int)
    case fadeOutRail
    case fadeInRail
    case fadeOutMidHandle
    case fadeOutQ3Handle
    case fadeInQ1Handle
    case fadeInMidHandle
    case curveBody
}

/// One drag in the splice editor: what it grabbed, the transition when it started, and the axis it
/// locked to.
public struct SpliceDragSession: Equatable, Sendable {
    /// The direction a drag locked to.
    public enum Axis: Sendable { case horizontal, vertical }

    /// What the drag moves.
    public let target: SpliceDragTarget
    /// The transition when the drag started.
    public let startSpec: KroutonTrackTransitionSpec
    let startGeometry: SpliceCanvasGeometry
    let grabOffsetX: CGFloat
    public private(set) var lockedAxis: Axis?

    /// Starts a drag at `start`; nil when nothing is there.
    public init?(start: CGPoint, spec: KroutonTrackTransitionSpec, geometry: SpliceCanvasGeometry) {
        guard let target = geometry.hitTest(start) else { return nil }
        self.target = target
        self.startSpec = spec
        self.startGeometry = geometry
        switch target {
        case .indexFlag: grabOffsetX = start.x - geometry.index01X
        case .subIndexFlag(let i):
            let sx = geometry.subIndexXs.indices.contains(i) ? geometry.subIndexXs[i] : start.x
            grabOffsetX = start.x - sx
        case .fadeOutRail: grabOffsetX = start.x - geometry.zoneX0
        case .fadeInRail: grabOffsetX = start.x - geometry.zoneX1
        case .fadeOutMidHandle, .fadeOutQ3Handle, .fadeInQ1Handle, .fadeInMidHandle, .curveBody: grabOffsetX = 0
        }
    }

    /// The transition with the drag applied at `location`. `fine` makes the change smaller.
    public mutating func spec(location: CGPoint, translation: CGSize, fine: Bool = false) -> KroutonTrackTransitionSpec {
        var spec = startSpec
        let g = startGeometry
        let w = g.size.width, h = g.size.height
        let handleX = location.x - grabOffsetX
        let scale = fine ? 0.25 : 1.0
        let span = g.effectiveSpanSeconds

        switch target {
        case .indexFlag:
            guard startSpec.isCrossfading else { return startSpec }
            let ratio = Double((handleX - g.zoneX0) / max(24, g.zoneX1 - g.zoneX0))
            spec.spliceIndex01Ratio = clamp(ratio, 0.15, 0.85)

        case .subIndexFlag(let idx):
            guard spec.subIndexRatios.indices.contains(idx) else { return startSpec }
            var ratio = clamp(Double(handleX / max(1, w)), 0.05, 0.95)
            // Keep a ±0.025 guard exclusion margin around INDEX 01 so a sub-index never overlaps INDEX 01
            let idx01R = g.index01RatioInCanvas
            if abs(ratio - idx01R) < 0.025 {
                ratio = ratio < idx01R ? max(0.05, idx01R - 0.025) : min(0.95, idx01R + 0.025)
            }
            spec.subIndexRatios[idx] = ratio

        case .fadeOutRail:
            if startSpec.isCrossfading {
                let deltaSec = -Double(translation.width / w) * span * scale
                spec.overlapSeconds = quantizeToFrames(clamp(startSpec.overlapSeconds + deltaSec, 0.5, 30.0))
            } else if startSpec.preGapSeconds > 0.01 {
                let deltaSec = -Double(translation.width / w) * 6.0 * scale
                spec.preGapSeconds = quantizeToFrames(clamp(startSpec.preGapSeconds + deltaSec, 0.25, 4.0))
            }

        case .fadeInRail:
            if startSpec.isCrossfading {
                let deltaSec = Double(translation.width / w) * span * scale
                spec.overlapSeconds = quantizeToFrames(clamp(startSpec.overlapSeconds + deltaSec, 0.5, 30.0))
            } else if startSpec.preGapSeconds > 0.01 {
                let deltaSec = Double(translation.width / w) * 6.0 * scale
                spec.preGapSeconds = quantizeToFrames(clamp(startSpec.preGapSeconds + deltaSec, 0.25, 4.0))
            }

        case .fadeOutMidHandle:
            guard startSpec.isCrossfading else { return startSpec }
            let startTrim = startSpec.fadeOutMidTrim ?? 0.0
            let delta = -Double(translation.height / max(40, h - SpliceCanvasGeometry.rulerHeight)) * 1.35 * scale
            spec.fadeOutMidTrim = clamp(startTrim + delta, -0.45, 0.45)

        case .fadeOutQ3Handle:
            guard startSpec.isCrossfading else { return startSpec }
            let startTrim = startSpec.fadeOutThreeQuarterTrim ?? 0.0
            let delta = -Double(translation.height / max(40, h - SpliceCanvasGeometry.rulerHeight)) * 1.35 * scale
            spec.fadeOutThreeQuarterTrim = clamp(startTrim + delta, -0.45, 0.45)

        case .fadeInQ1Handle:
            guard startSpec.isCrossfading else { return startSpec }
            let startTrim = startSpec.fadeInQuarterTrim ?? 0.0
            let delta = -Double(translation.height / max(40, h - SpliceCanvasGeometry.rulerHeight)) * 1.35 * scale
            spec.fadeInQuarterTrim = clamp(startTrim + delta, -0.45, 0.45)

        case .fadeInMidHandle:
            guard startSpec.isCrossfading else { return startSpec }
            let startTrim = startSpec.fadeInMidTrim ?? 0.0
            let delta = -Double(translation.height / max(40, h - SpliceCanvasGeometry.rulerHeight)) * 1.35 * scale
            spec.fadeInMidTrim = clamp(startTrim + delta, -0.45, 0.45)

        case .curveBody:
            guard startSpec.isCrossfading else { return startSpec }
            if lockedAxis == nil, max(abs(translation.width), abs(translation.height)) > 5 {
                lockedAxis = abs(translation.width) > abs(translation.height) ? .horizontal : .vertical
            }
            switch lockedAxis {
            case .vertical?:
                let delta = -Double(translation.height / h) * 2.0 * scale
                spec.curveTension = clamp(startSpec.curveTension + delta, -1.0, 1.0)
            case .horizontal?:
                let delta = Double(translation.width / w) * span * scale
                spec.overlapSeconds = quantizeToFrames(clamp(startSpec.overlapSeconds + delta, 0.5, 30.0))
            case nil:
                break
            }
        }
        return spec
    }

    private func clamp<T: Comparable>(_ v: T, _ lo: T, _ hi: T) -> T { min(hi, max(lo, v)) }
    private func quantizeToFrames(_ seconds: Double) -> Double { (seconds * 75).rounded() / 75 }
}
