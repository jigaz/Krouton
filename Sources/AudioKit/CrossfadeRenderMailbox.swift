import Foundation
import os

// MARK: - Scalar-Only Real-Time Crossfade Parameters (Zero ARC Traffic on Audio Thread)

public struct CrossfadeRenderParams: Sendable, Equatable {
    public var overlapFrames: Int
    public var preGapFrames: Int
    public var fadeOutCurve: KroutonCrossfadeCurve
    public var fadeInCurve: KroutonCrossfadeCurve
    public var shapeExponent: Double
    public var fadeOutStart: Double
    public var fadeInEnd: Double
    public var fadeOutMidTrim: Double
    public var fadeOutThreeQuarterTrim: Double
    public var fadeInQuarterTrim: Double
    public var fadeInMidTrim: Double
    public var outgoingTrimLinear: Double
    public var incomingTrimLinear: Double

    public init(spec: KroutonTrackTransitionSpec, sampleRate: Double, suppressedAtDiscBoundary: Bool) {
        let crossfade = spec.isCrossfading && !suppressedAtDiscBoundary
        overlapFrames = crossfade ? Int((spec.overlapSeconds * sampleRate).rounded()) : 0
        preGapFrames = crossfade ? 0 : Int((spec.preGapSeconds * sampleRate).rounded())
        fadeOutCurve = spec.fadeOutCurve
        fadeInCurve = spec.fadeInCurve
        shapeExponent = pow(2.0, -spec.curveTension * 1.35)
        fadeOutStart = spec.asymmetricUnlinked ? spec.fadeOutStartRatio : 0.0
        fadeInEnd = spec.asymmetricUnlinked ? spec.fadeInEndRatio : 1.0
        fadeOutMidTrim = spec.fadeOutMidTrim ?? 0.0
        fadeOutThreeQuarterTrim = spec.fadeOutThreeQuarterTrim ?? 0.0
        fadeInQuarterTrim = spec.fadeInQuarterTrim ?? 0.0
        fadeInMidTrim = spec.fadeInMidTrim ?? 0.0
        outgoingTrimLinear = pow(10.0, spec.outgoingTrimDB / 20.0)
        incomingTrimLinear = pow(10.0, spec.incomingTrimDB / 20.0)
    }

    /// Evaluates outgoing and incoming linear gains at normalized crossfade progress `t` in [0, 1].
    public func gains(at t: Double) -> (out: Double, in: Double) {
        let outT = t <= fadeOutStart ? 0.0 : min(1.0, (t - fadeOutStart) / max(0.05, 1.0 - fadeOutStart))
        let inT = t >= fadeInEnd ? 1.0 : max(0.0, t / max(0.05, fadeInEnd))
        return (
            shapeOut(fadeOutCurve.gainOut(at: outT), t: outT) * outgoingTrimLinear,
            shapeIn(fadeInCurve.gainIn(at: inT), t: inT) * incomingTrimLinear
        )
    }

    private func shapeOut(_ base: Double, t: Double) -> Double {
        var shaped = pow(max(0.0, min(1.0, base)), shapeExponent)
        if fadeOutMidTrim != 0.0 {
            shaped = max(0.0, min(1.0, shaped + fadeOutMidTrim * 4.0 * t * (1.0 - t)))
        }
        if fadeOutThreeQuarterTrim != 0.0 {
            shaped = max(0.0, min(1.0, shaped + fadeOutThreeQuarterTrim * 6.75 * t * t * (1.0 - t)))
        }
        return max(0.0, shaped)
    }

    private func shapeIn(_ base: Double, t: Double) -> Double {
        var shaped = pow(max(0.0, min(1.0, base)), shapeExponent)
        if fadeInQuarterTrim != 0.0 {
            shaped = max(0.0, min(1.0, shaped + fadeInQuarterTrim * 6.75 * t * (1.0 - t) * (1.0 - t)))
        }
        if fadeInMidTrim != 0.0 {
            shaped = max(0.0, min(1.0, shaped + fadeInMidTrim * 4.0 * t * (1.0 - t)))
        }
        return max(0.0, shaped)
    }
}

// MARK: - Non-Blocking Single-Writer Mailbox (OSAllocatedUnfairLock.withLockIfAvailable)

public final class CrossfadeParameterMailbox: Sendable {
    private struct Slot: Sendable {
        var params: CrossfadeRenderParams
        var generation: UInt64 = 1
        var playheadFrame: Int = 0
    }

    private let slot: OSAllocatedUnfairLock<Slot>

    public init(_ initial: CrossfadeRenderParams) {
        slot = OSAllocatedUnfairLock(initialState: Slot(params: initial))
    }

    public func publish(_ params: CrossfadeRenderParams) {
        slot.withLock {
            $0.params = params
            $0.generation &+= 1
        }
    }

    /// Audio render thread: never blocks. Returns nil on lock contention or when generation is unchanged.
    public func exchange(lastSeen: UInt64, playheadFrame: Int) -> (params: CrossfadeRenderParams, generation: UInt64)? {
        let fresh = slot.withLockIfAvailable { s -> (params: CrossfadeRenderParams, generation: UInt64)? in
            s.playheadFrame = playheadFrame
            return s.generation == lastSeen ? nil : (s.params, s.generation)
        }
        return fresh ?? nil
    }

    public var playheadFrame: Int {
        slot.withLock { $0.playheadFrame }
    }
}

// MARK: - Pure Real-Time Stereo Crossfade Renderer

public struct StereoPCM: Sendable {
    public let left: [Float]
    public let right: [Float]
    public var frameCount: Int { left.count }

    public init(left: [Float], right: [Float]) {
        self.left = left
        self.right = right
    }
}

public struct CrossfadeRenderCursor: Sendable {
    public var frame: Int = 0
    public var generation: UInt64 = 0
    public var params: CrossfadeRenderParams

    public init(params: CrossfadeRenderParams) {
        self.params = params
    }
}

public enum CrossfadeRenderer {
    public static func render(
        left: UnsafeMutableBufferPointer<Float>,
        right: UnsafeMutableBufferPointer<Float>,
        frameCount: Int,
        cursor: inout CrossfadeRenderCursor,
        preRollFrames: Int,
        outgoing: StereoPCM,
        incoming: StereoPCM
    ) {
        let p = cursor.params
        let overlap = p.overlapFrames
        let outOrigin = outgoing.frameCount - (preRollFrames + overlap)
        let inOrigin = preRollFrames + (overlap > 0 ? 0 : p.preGapFrames)
        let count = min(frameCount, min(left.count, right.count))
        for i in 0..<count {
            let f = cursor.frame + i
            var gOut = f < preRollFrames + overlap ? 1.0 : 0.0
            var gIn = f >= inOrigin ? 1.0 : 0.0
            if overlap > 0, f >= preRollFrames, f < preRollFrames + overlap {
                (gOut, gIn) = p.gains(at: Double(f - preRollFrames) / Double(overlap))
            }
            var l = 0.0
            var r = 0.0
            let o = outOrigin + f
            if gOut > 0.0, o >= 0, o < outgoing.frameCount {
                l += Double(outgoing.left[o]) * gOut
                r += Double(outgoing.right[o]) * gOut
            }
            let n = f - inOrigin
            if gIn > 0.0, n >= 0, n < incoming.frameCount {
                l += Double(incoming.left[n]) * gIn
                r += Double(incoming.right[n]) * gIn
            }
            left[i] = Float(l)
            right[i] = Float(r)
        }
        cursor.frame += count
    }
}
