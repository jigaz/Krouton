import AVFoundation
import Foundation

// MARK: - Honest Track Data
//
// Track metadata, loudness, clipping and waveform data that come from the file or
// the user, never made up: ISRCs are checked, never invented; every field says
// where it came from (`MetadataSource`); an unknown performer stays nil, so no
// CD-Text field is written; file names give only a conservative suggestion
// (`FilenameTitleGuess`); loudness is measured to ITU-R BS.1770 (`LoudnessMeter`);
// clipping is reported (`predictedOverlapPeak`), not clamped; waveforms come from
// real samples (`PeakPyramid`).
//
// Not wired up yet: `mergeMetadata`, `predictedOverlapPeak` and `PeakPyramid` have
// no caller in the app, and the measured loudness isn't used for gain matching.

// MARK: - Provenance

/// Where a metadata value came from.
public enum MetadataSource: String, Codable, Sendable {
    /// Typed in Krouton; always wins.
    case userEntered
    /// ID3, iTunes or BWF metadata in the file.
    case embeddedTag
    /// An imported .cue sheet.
    case cueSheet
    /// MusicBrainz or similar, by disc ID.
    case discLookup
    /// Parsed from the file name; show it as a suggestion.
    case filenameGuess
}

/// A value and where it came from.
public struct Sourced<Value: Codable & Sendable & Equatable>: Codable, Sendable, Equatable {
    /// The value.
    public var value: Value
    /// Where it came from.
    public var source: MetadataSource
    public init(_ value: Value, _ source: MetadataSource) {
        self.value = value
        self.source = source
    }
}

/// Everything optional. An absent field is written nowhere: no CD-TEXT pack,
/// no cue line, no subcode.
public struct TrackMetadata: Codable, Sendable, Equatable {
    /// The title, if known.
    public var title: Sourced<String>?
    /// The performer, if known.
    public var performer: Sourced<String>?
    /// The ISRC, if known.
    public var isrc: Sourced<ISRC>?
    public init(title: Sourced<String>? = nil, performer: Sourced<String>? = nil, isrc: Sourced<ISRC>? = nil) {
        self.title = title
        self.performer = performer
        self.isrc = isrc
    }
}

// MARK: - ISRC

/// ISO 3901: 2 letters (country) + 3 alphanumerics (registrant) + 2 digits (year)
/// + 5 digits (designation). Krouton can check the shape. It cannot issue one:
/// codes come from the rights holder's registrant allocation.
public struct ISRC: Codable, Sendable, Equatable, CustomStringConvertible {
    /// 12 characters, no hyphens.
    public let code: String

    /// Accepts the code with or without spaces and hyphens; nil when its shape is wrong.
    public init?(_ raw: String) {
        let compact = raw.uppercased().filter { !$0.isWhitespace && $0 != "-" }
        guard compact.range(of: #"^[A-Z]{2}[A-Z0-9]{3}[0-9]{7}$"#, options: .regularExpression) != nil else { return nil }
        code = compact
    }

    /// The code with hyphens, as US-KRO-26-00001.
    public var description: String {
        let c = Array(code)
        return "\(String(c[0..<2]))-\(String(c[2..<5]))-\(String(c[5..<7]))-\(String(c[7..<12]))"
    }
}

// MARK: - Filename guess (a suggestion, labelled as one)

/// Suggests a title and performer from a file name.
public enum FilenameTitleGuess {
    /// Only tokens that are unambiguous export clutter, and only at the END of the
    /// name. "Final Countdown", "Radio Edit" and "Demo Tape" survive.
    private static let trailingClutter: Set<String> = [
        "final", "master", "mastered", "bounce", "v1", "v2", "v3", "v4", "v5",
        "1644", "2444", "2448", "2496", "44k", "48k", "96k",
    ]

    /// Strips a leading track number and trailing export words, splits "Artist - Title", and
    /// fixes the case only of names that are all one case. Never guesses an ISRC.
    public static func guess(from url: URL) -> TrackMetadata {
        var name = url.deletingPathExtension().lastPathComponent
        if !name.contains(" ") { name = name.replacingOccurrences(of: "_", with: " ") }
        // Leading track number: "03 ", "03. ", "03 - ", "03) "
        name = name.replacingOccurrences(of: #"^\s*\d{1,3}\s*[-.)]?\s+"#, with: "", options: .regularExpression)

        var performer: String?
        if let separator = name.range(of: " - ") {
            let left = name[..<separator.lowerBound].trimmingCharacters(in: .whitespaces)
            let right = name[separator.upperBound...].trimmingCharacters(in: .whitespaces)
            if !left.isEmpty, !right.isEmpty {
                performer = left
                name = right
            }
        }

        var words = name.split(separator: " ").map(String.init)
        while words.count > 1, let last = words.last, trailingClutter.contains(last.lowercased()) {
            words.removeLast()
        }
        // Keep the user's capitalisation. Only fix names that are entirely one case.
        var title = words.joined(separator: " ")
        if title == title.lowercased() || title == title.uppercased() { title = title.capitalized }

        return TrackMetadata(
            title: title.isEmpty ? nil : Sourced(title, .filenameGuess),
            performer: performer.map { Sourced($0, .filenameGuess) },
            isrc: nil // never guessed
        )
    }
}

/// Merge order: later sources only fill gaps left by earlier ones.
func mergeMetadata(_ candidates: TrackMetadata...) -> TrackMetadata {
    var merged = TrackMetadata()
    for candidate in candidates {
        merged.title = merged.title ?? candidate.title
        merged.performer = merged.performer ?? candidate.performer
        merged.isrc = merged.isrc ?? candidate.isrc
    }
    return merged
}
// Meant to be called with the user's edits, then the file's tags, then the file name guess.

// MARK: - Loudness (ITU-R BS.1770 integrated, gated)

/// Integrated loudness to ITU-R BS.1770 (K-weighting, 400 ms blocks, absolute and relative gates).
public enum LoudnessMeter {
    private struct Biquad {
        var b0, b1, b2, a1, a2: Double
        var z1 = 0.0, z2 = 0.0
        mutating func process(_ x: Double) -> Double {
            let y = b0 * x + z1
            z1 = b1 * x - a1 * y + z2
            z2 = b2 * x - a2 * y
            return y
        }
    }

    /// K-weighting for any sample rate (the published tables are 48 kHz only).
    private static func kWeighting(sampleRate fs: Double) -> (shelf: Biquad, highPass: Biquad) {
        var f0 = 1681.974450955533, q = 0.7071752369554196
        let gainDB = 3.999843853973347
        var k = tan(.pi * f0 / fs)
        let vh = pow(10, gainDB / 20), vb = pow(vh, 0.4996667741545416)
        var a0 = 1 + k / q + k * k
        let shelf = Biquad(b0: (vh + vb * k / q + k * k) / a0, b1: 2 * (k * k - vh) / a0,
                           b2: (vh - vb * k / q + k * k) / a0, a1: 2 * (k * k - 1) / a0, a2: (1 - k / q + k * k) / a0)
        f0 = 38.13547087602444; q = 0.5003270373238773
        k = tan(.pi * f0 / fs)
        a0 = 1 + k / q + k * k
        let highPass = Biquad(b0: 1, b1: -2, b2: 1, a1: 2 * (k * k - 1) / a0, a2: (1 - k / q + k * k) / a0)
        return (shelf, highPass)
    }

    /// Integrated loudness in LUFS for mono or stereo float samples in -1...1.
    /// Returns nil for silence or for clips shorter than one 400 ms block.
    ///
    /// Plain loops: fine for the 10-30 s windows around a transition. For whole
    /// albums, run it when files are staged, off the main actor, or swap the inner
    /// loop for vDSP biquads.
    static func integratedLUFS(channels: [[Float]], sampleRate: Double) -> Double? {
        guard let frameCount = channels.map(\.count).min(), !channels.isEmpty else { return nil }
        let block = Int((0.4 * sampleRate).rounded()), hop = Int((0.1 * sampleRate).rounded())
        guard frameCount >= block else { return nil }

        // Squared, K-weighted signal summed across channels (L and R weigh 1.0).
        var energy = [Double](repeating: 0, count: frameCount)
        for channel in channels {
            var (shelf, highPass) = kWeighting(sampleRate: sampleRate)
            for i in 0..<frameCount {
                let y = highPass.process(shelf.process(Double(channel[i])))
                energy[i] += y * y
            }
        }

        var blockPowers: [Double] = []
        var start = 0
        while start + block <= frameCount {
            var sum = 0.0
            for i in start..<(start + block) { sum += energy[i] }
            blockPowers.append(sum / Double(block))
            start += hop
        }

        func lufs(_ power: Double) -> Double { power > 0 ? -0.691 + 10 * log10(power) : -.infinity }
        let aboveAbsolute = blockPowers.filter { lufs($0) > -70 }
        guard !aboveAbsolute.isEmpty else { return nil }
        let relativeGate = lufs(aboveAbsolute.reduce(0, +) / Double(aboveAbsolute.count)) - 10
        let gated = aboveAbsolute.filter { lufs($0) > relativeGate }
        guard !gated.isEmpty else { return nil }
        return lufs(gated.reduce(0, +) / Double(gated.count))
    }
}

// Proposal for gain matching: replace `KroutonTrackTransitionSpec.gainMatchLUFS` (a
// flag nothing reads) with a measured `gainMatchOffsetDB: Double?` added to the
// incoming trim, and show the figure in the UI so it can be checked.

// MARK: - Clipping instead of a silent clamp

/// Worst-case sample peak of the summed overlap, as a linear value (1.0 = full
/// scale): the gain stays what the user asked for, and this says whether the result
/// clips.
///
/// `outgoing` and `incoming` are the overlap region of each track, same length,
/// one channel. Run per channel and take the maximum.
func predictedOverlapPeak(
    outgoing: [Float], incoming: [Float],
    gainOut: (Double) -> Double, gainIn: (Double) -> Double
) -> Double {
    let n = min(outgoing.count, incoming.count)
    guard n > 1 else { return 0 }
    var peak = 0.0
    for i in 0..<n {
        let t = Double(i) / Double(n - 1)
        let mixed = Double(outgoing[i]) * gainOut(t) + Double(incoming[i]) * gainIn(t)
        peak = max(peak, abs(mixed))
    }
    return peak
}
// Proposal: above about 0.98, show "Overlap clips by +x.x dB" and offer a one-click
// trim of both sides. Whatever gain is applied, re-dither to 16 bit
// (TPDF) when rendering the final 44.1 kHz stream; undithered gain changes on
// 16-bit audio add distortion at low levels.

// MARK: - Waveform Data

/// Min/max peak pyramid. Level 0 has one bucket per Red Book frame (588 samples at
/// 44.1 kHz); each higher level halves the resolution. Immutable and Sendable, so
/// the Canvas can read it from any thread without locks, and a redraw only ever
/// touches about one bucket per horizontal point.
public struct PeakPyramid: Sendable {
    /// One resolution of the pyramid.
    public struct Level: Sendable {
        let framesPerBucket: Int
        let minima: [Float]
        /// The highest sample in each bucket.
        public let maxima: [Float]
    }
    static let samplesPerRedBookFrame = 588
    /// Level 0 first (one bucket per CD frame), each next one half as fine.
    public let levels: [Level]

    /// `mono` is the channel-averaged signal resampled to 44.1 kHz. Build this once
    /// when a file is staged, off the main actor, and cache it next to the session.
    public init(mono: [Float]) {
        let size = Self.samplesPerRedBookFrame
        var minima: [Float] = [], maxima: [Float] = []
        var start = 0
        while start < mono.count {
            let slice = mono[start..<min(start + size, mono.count)]
            minima.append(slice.min() ?? 0)
            maxima.append(slice.max() ?? 0)
            start += size
        }
        var built = [Level(framesPerBucket: 1, minima: minima, maxima: maxima)]
        while let last = built.last, last.minima.count > 64 {
            var lo: [Float] = [], hi: [Float] = []
            var i = 0
            while i < last.minima.count {
                let j = min(i + 1, last.minima.count - 1)
                lo.append(min(last.minima[i], last.minima[j]))
                hi.append(max(last.maxima[i], last.maxima[j]))
                i += 2
            }
            built.append(Level(framesPerBucket: last.framesPerBucket * 2, minima: lo, maxima: hi))
        }
        levels = built
    }

    /// Returns `columns` (min, max) pairs covering `frames` (Red Book frames).
    public func columns(for frames: Range<Int>, columns: Int) -> [(min: Float, max: Float)] {
        guard columns > 0, !frames.isEmpty, let finest = levels.first else { return [] }
        let framesPerColumn = max(1, frames.count / columns)
        // Coarsest level that still has at least one bucket per column.
        let level = levels.last { $0.framesPerBucket <= framesPerColumn } ?? finest
        var result: [(min: Float, max: Float)] = []
        result.reserveCapacity(columns)
        for column in 0..<columns {
            let firstFrame = frames.lowerBound + column * frames.count / columns
            let lastFrame = frames.lowerBound + (column + 1) * frames.count / columns
            let a = min(level.minima.count - 1, max(0, firstFrame / level.framesPerBucket))
            let b = min(level.minima.count - 1, max(a, (lastFrame - 1) / level.framesPerBucket))
            var lo = Float.greatestFiniteMagnitude, hi = -Float.greatestFiniteMagnitude
            for bucket in a...b {
                lo = min(lo, level.minima[bucket])
                hi = max(hi, level.maxima[bucket])
            }
            result.append((lo, hi))
        }
        return result
    }
}
// Proposal: draw the splice editor's waveforms from `pyramid.columns(for:columns:)`
// times the same `effectiveGainOut`/`effectiveGainIn` the burn uses, built when a
// file is staged (see PENDING_INTEGRATION.md). The audition already renders through
// `CrossfadeRenderer`, the same gains the burn uses.
