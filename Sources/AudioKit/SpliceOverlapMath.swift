import CoreGraphics
import Foundation

public struct FramePeaks: Equatable, Sendable {
    public let id: UUID
    public let values: [Float]
    public let maximum: Float

    public init(values: [Float]) {
        self.id = UUID()
        self.values = values
        self.maximum = values.max() ?? 0
    }

    public static func == (lhs: FramePeaks, rhs: FramePeaks) -> Bool { lhs.id == rhs.id }

    public func peak(in range: Range<Int>) -> Float? {
        let lower = max(range.lowerBound, 0), upper = min(range.upperBound, values.count)
        guard lower < upper else { return nil }
        var result: Float = 0
        for i in lower..<upper { result = max(result, values[i]) }
        return result
    }
}

public enum SpliceOverlapMath {
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

    public static func dBFS(_ linear: Double) -> Double? {
        linear > 0 ? 20 * log10(linear) : nil
    }
}

// MARK: - Track Montage Editor Pure Geometry & Track-Aware Sub-Index Partitioning

public struct SpliceSubIndexDescriptor: Identifiable, Equatable, Sendable {
    public var id: Int { arrayIndex }
    /// Index into `spec.subIndexRatios` so drag gestures mutate the exact element
    let arrayIndex: Int
    /// X coordinate in canvas space
    public let x: CGFloat
    /// Normalized canvas ratio (0.05 ... 0.95)
    public let ratio: Double
    /// True when the marker sits to the right of `INDEX 01` (belongs to Incoming Track N+1)
    public let isIncomingTrack: Bool
    /// Red Book sub-index number within its owning track (`2` = INDEX 02, `3` = INDEX 03, ...)
    public let redBookIndexNumber: Int
}

public struct SpliceCanvasGeometry: Equatable, Sendable {
    static let restingLeft = 0.20
    static let restingRight = 0.80
    static let railTravel = 0.42
    static let baseTimelineSpanSeconds: Double = 34.0
    static let timelineSpanSeconds: Double = 34.0
    public static let rulerHeight: CGFloat = 24
    static let handleSlop: CGFloat = 10

    public let size: CGSize
    public let horizontalZoom: Double
    public let effectiveSpanSeconds: Double
    public let zoneX0: CGFloat
    public let zoneX1: CGFloat
    public let index01X: CGFloat
    let index01RatioInCanvas: Double
    let subIndexXs: [CGFloat]
    public let subIndexDescriptors: [SpliceSubIndexDescriptor]
    public let centerHandle: CGPoint
    public let fadeOutMidAnchor: CGPoint
    public let fadeInMidAnchor: CGPoint
    public let fadeOutMidHandle: CGPoint?
    public let fadeInMidHandle: CGPoint?

    public init(size: CGSize, spec: KroutonTrackTransitionSpec, horizontalZoom: Double = 1.0) {
        let w = max(180, size.width), h = max(36, size.height)
        self.size = CGSize(width: w, height: h)
        let zoom = max(1.0, min(3.0, horizontalZoom))
        self.horizontalZoom = zoom
        let span = Self.baseTimelineSpanSeconds / zoom
        self.effectiveSpanSeconds = span

        if !spec.isCrossfading && spec.preGapSeconds <= 0.01 {
            let midX = w * 0.5
            zoneX0 = midX
            zoneX1 = midX
            index01X = midX
        } else if spec.isCrossfading {
            let baseHalf = max(0.06, min(0.42, (spec.overlapSeconds / span) * 0.44))
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

        let outAnchorPoint = CGPoint(x: zoneX0 + zoneW * 0.25, y: yForGain(spec.effectiveGainOut(at: 0.25)))
        let inAnchorPoint  = CGPoint(x: zoneX0 + zoneW * 0.75, y: yForGain(spec.effectiveGainIn(at: 0.75)))
        fadeOutMidAnchor = outAnchorPoint
        fadeInMidAnchor  = inAnchorPoint
        fadeOutMidHandle = spec.fadeOutMidTrim != nil ? outAnchorPoint : nil
        fadeInMidHandle  = spec.fadeInMidTrim != nil ? inAnchorPoint : nil

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

    public func hitTest(_ p: CGPoint) -> SpliceDragTarget? {
        if p.y < Self.rulerHeight {
            for desc in subIndexDescriptors where abs(p.x - desc.x) <= Self.handleSlop * 1.6 {
                return .subIndexFlag(desc.arrayIndex)
            }
            if abs(p.x - index01X) <= Self.handleSlop * 1.8 { return .indexFlag }
        }
        if let outH = fadeOutMidHandle, hypot(p.x - outH.x, p.y - outH.y) <= Self.handleSlop * 1.4 {
            return .fadeOutMidHandle
        }
        if let inH = fadeInMidHandle, hypot(p.x - inH.x, p.y - inH.y) <= Self.handleSlop * 1.4 {
            return .fadeInMidHandle
        }
        let d0 = abs(p.x - zoneX0), d1 = abs(p.x - zoneX1)
        if min(d0, d1) <= Self.handleSlop { return d0 <= d1 ? .fadeOutRail : .fadeInRail }
        if p.x > zoneX0, p.x < zoneX1, p.y >= Self.rulerHeight { return .curveBody }
        return nil
    }

    /// Checks whether a click or hover point falls in the hidden vicinity (<= 18 pt) of an unspawned mid-curve handle.
    public func hitTestHiddenMidCurveVicinity(_ p: CGPoint) -> SpliceDragTarget? {
        guard p.y >= Self.rulerHeight, zoneX1 - zoneX0 > 32 else { return nil }
        let radius: CGFloat = 18.0
        let dOut = hypot(p.x - fadeOutMidAnchor.x, p.y - fadeOutMidAnchor.y)
        let dIn  = hypot(p.x - fadeInMidAnchor.x, p.y - fadeInMidAnchor.y)
        if fadeOutMidHandle == nil && dOut <= radius && dOut <= dIn {
            return .fadeOutMidHandle
        }
        if fadeInMidHandle == nil && dIn <= radius {
            return .fadeInMidHandle
        }
        return nil
    }
}

public enum SpliceDragTarget: Equatable, Sendable {
    case indexFlag
    case subIndexFlag(Int)
    case fadeOutRail
    case fadeInRail
    case fadeOutMidHandle
    case fadeInMidHandle
    case curveBody
}

public struct SpliceDragSession: Equatable, Sendable {
    public enum Axis: Sendable { case horizontal, vertical }

    public let target: SpliceDragTarget
    public let startSpec: KroutonTrackTransitionSpec
    let startGeometry: SpliceCanvasGeometry
    let grabOffsetX: CGFloat
    public private(set) var lockedAxis: Axis?

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
        case .fadeOutMidHandle, .fadeInMidHandle, .curveBody: grabOffsetX = 0
        }
    }

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
