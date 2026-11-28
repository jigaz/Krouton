import Foundation
import os

// MARK: - Crossfade Parameters (plain values, safe to read on the audio thread)

/// A transition reduced to plain numbers for rendering, in sample frames at the render's
/// sample rate (not CD frames). Built once from a `KroutonTrackTransitionSpec`, so the audio
/// thread does no allocation or string work.
public struct CrossfadeRenderParams: Sendable, Equatable {
    /// Sample frames of overlap; 0 when not crossfading.
    public var overlapFrames: Int
    /// Sample frames of silence before the next track; 0 while crossfading.
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

    /// The parameters for `spec` at `sampleRate`. With `suppressedAtDiscBoundary` (a disc change
    /// between the two tracks) the crossfade becomes a pause.
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

    /// The outgoing and incoming linear gains at progress `t` (0…1) through the overlap, the same
    /// as `KroutonTrackTransitionSpec.effectiveGainOut` and `effectiveGainIn`.
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

// MARK: - Parameter Mailbox

/// Hands new crossfade parameters from the UI to the audio thread. The UI side takes the lock;
/// the audio side only tries it (`withLockIfAvailable`), so it never waits.
public final class CrossfadeParameterMailbox: Sendable {
    private struct Slot: Sendable {
        var params: CrossfadeRenderParams
        var generation: UInt64 = 1
        var playheadFrame: Int = 0
    }

    private let slot: OSAllocatedUnfairLock<Slot>

    /// A mailbox holding `initial`.
    public init(_ initial: CrossfadeRenderParams) {
        slot = OSAllocatedUnfairLock(initialState: Slot(params: initial))
    }

    /// Posts new parameters (UI side).
    public func publish(_ params: CrossfadeRenderParams) {
        slot.withLock {
            $0.params = params
            $0.generation &+= 1
        }
    }

    /// For the audio thread: records the playhead and returns the parameters if they changed
    /// since `lastSeen`. Never blocks; returns nil when the lock is busy or nothing changed.
    public func exchange(lastSeen: UInt64, playheadFrame: Int) -> (params: CrossfadeRenderParams, generation: UInt64)? {
        let fresh = slot.withLockIfAvailable { s -> (params: CrossfadeRenderParams, generation: UInt64)? in
            s.playheadFrame = playheadFrame
            return s.generation == lastSeen ? nil : (s.params, s.generation)
        }
        return fresh ?? nil
    }

    /// The playhead the audio thread last reported (UI side).
    public var playheadFrame: Int {
        slot.withLock { $0.playheadFrame }
    }
}

// MARK: - Crossfade Renderer

/// Stereo samples as two `Float` arrays of equal length.
public struct StereoPCM: Sendable {
    public let left: [Float]
    public let right: [Float]
    public var frameCount: Int { left.count }

    public init(left: [Float], right: [Float]) {
        self.left = left
        self.right = right
    }
}

/// Where a render is: the next output frame, and the parameters in use with their generation.
public struct CrossfadeRenderCursor: Sendable {
    public var frame: Int = 0
    public var generation: UInt64 = 0
    public var params: CrossfadeRenderParams

    public init(params: CrossfadeRenderParams) {
        self.params = params
    }
}

/// Renders the audition of one transition: the end of the outgoing track, the overlap or pause,
/// then the start of the incoming one.
public enum CrossfadeRenderer {
    /// Fills `frameCount` frames of `left` and `right` from `cursor.frame` on and advances the
    /// cursor. `preRollFrames` of the outgoing track play before the overlap starts.
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
