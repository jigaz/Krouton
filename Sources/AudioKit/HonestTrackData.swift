import AVFoundation
import Foundation

// Replacements for the hard-coded placeholders in the slice.
//
//   Placeholder in the slice                         Replacement here
//   -----------------------------------------------  --------------------------------
//   ISRC invented from a filename hash               `ISRC` validates, never invents
//   confidenceSource "ShazamKit Acoustic + AI ..."   `MetadataSource` per field
//   performer "Krouton Track Artist"                nil, and the CD-TEXT field is omitted
//   noise-word stripping + forced Title Case         conservative `FilenameTitleGuess`
//   gainMatchLUFS adds a fixed +1.2 dB               `LoudnessMeter` (ITU-R BS.1770)
//   gain silently clamped at 1.25                    `predictedOverlapPeak` + a warning
//   sin/cos "waveform" bars, fake transient tint     `PeakPyramid` from real samples
//
// Not compiled here (no Swift toolchain in my sandbox). The loudness maths was
// checked with a reference port: a 997 Hz stereo sine at -23 dBFS reads -23.00 LUFS
// at both 44.1 kHz and 48 kHz.

// MARK: - Provenance

public enum MetadataSource: String, Codable, Sendable {
    case userEntered      // typed in Krouton; always wins
    case embeddedTag      // ID3 / iTunes / BWF metadata in the file
    case cueSheet         // imported .cue
    case discLookup       // MusicBrainz or similar, by disc ID
    case filenameGuess    // parsed from the file name; show as a suggestion
}

public struct Sourced<Value: Codable & Sendable & Equatable>: Codable, Sendable, Equatable {
    public var value: Value
    public var source: MetadataSource
    public init(_ value: Value, _ source: MetadataSource) {
        self.value = value
        self.source = source
    }
}

/// Everything optional. An absent field is written nowhere: no CD-TEXT pack,
/// no cue line, no subcode.
public struct TrackMetadata: Codable, Sendable, Equatable {
    public var title: Sourced<String>?
    public var performer: Sourced<String>?
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
    public let code: String // 12 characters, no hyphens

    public init?(_ raw: String) {
        let compact = raw.uppercased().filter { !$0.isWhitespace && $0 != "-" }
        guard compact.range(of: #"^[A-Z]{2}[A-Z0-9]{3}[0-9]{7}$"#, options: .regularExpression) != nil else { return nil }
        code = compact
    }

    public var description: String {
        let c = Array(code)
        return "\(String(c[0..<2]))-\(String(c[2..<5]))-\(String(c[5..<7]))-\(String(c[7..<12]))"
    }
}

// MARK: - Reading what the file already says

public enum EmbeddedMetadataReader {
    /// Reads title, artist and ISRC from the file's own tags. Returns only what is
    /// actually present.
    public static func read(from url: URL) async -> TrackMetadata {
        var result = TrackMetadata()
        guard let items = try? await AVURLAsset(url: url).load(.metadata) else { return result }

        func string(_ identifier: AVMetadataIdentifier) async -> String? {
            guard let item = AVMetadataItem.metadataItems(from: items, filteredByIdentifier: identifier).first,
                  let text = try? await item.load(.stringValue) else { return nil }
            let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty ? nil : trimmed
        }

        if let title = await string(.commonIdentifierTitle) { result.title = Sourced(title, .embeddedTag) }
        if let artist = await string(.commonIdentifierArtist) { result.performer = Sourced(artist, .embeddedTag) }
        if let raw = await string(.id3MetadataInternationalStandardRecordingCode), let isrc = ISRC(raw) {
            result.isrc = Sourced(isrc, .embeddedTag)
        }
        // WAV/BWF files carry ISRC in the `axml` chunk rather than ID3; parse that
        // chunk separately if your sources are mastering deliverables.
        return result
    }
}

// MARK: - Filename guess (a suggestion, labelled as one)

public enum FilenameTitleGuess {
    /// Only tokens that are unambiguous export clutter, and only at the END of the
    /// name. "Final Countdown", "Radio Edit" and "Demo Tape" survive.
    private static let trailingClutter: Set<String> = [
        "final", "master", "mastered", "bounce", "v1", "v2", "v3", "v4", "v5",
        "1644", "2444", "2448", "2496", "44k", "48k", "96k",
    ]

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
public func mergeMetadata(_ candidates: TrackMetadata...) -> TrackMetadata {
    var merged = TrackMetadata()
    for candidate in candidates {
        merged.title = merged.title ?? candidate.title
        merged.performer = merged.performer ?? candidate.performer
        merged.isrc = merged.isrc ?? candidate.isrc
    }
    return merged
}
// Usage: mergeMetadata(userEdits, await EmbeddedMetadataReader.read(from: url), FilenameTitleGuess.guess(from: url))

// MARK: - Loudness (ITU-R BS.1770 integrated, gated)

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
    public static func integratedLUFS(channels: [[Float]], sampleRate: Double) -> Double? {
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

    /// Replaces the fixed +1.2 dB. Measure the last N seconds of the outgoing track
    /// and the first N seconds of the incoming one; the result is the trim to apply
    /// to the incoming track so the two sit at the same loudness.
    /// Returns nil when either side cannot be measured, in which case apply nothing
    /// and show the toggle as unavailable.
    public static func gainMatchOffsetDB(outgoingTailLUFS: Double?, incomingHeadLUFS: Double?, limit: Double = 6) -> Double? {
        guard let out = outgoingTailLUFS, let incoming = incomingHeadLUFS else { return nil }
        return min(limit, max(-limit, out - incoming))
    }
}

// In KroutonTrackTransitionSpec, replace
//     public var gainMatchLUFS: Bool
// with
//     public var gainMatchOffsetDB: Double?   // nil = off or not measurable
// and in effectiveGainIn use `incomingTrimDB + (gainMatchOffsetDB ?? 0)`.
// Show the measured figure in the UI ("Gain Match  -2.3 dB") so it is checkable.

// MARK: - Clipping instead of a silent clamp

/// Worst-case sample peak of the summed overlap, as a linear value (1.0 = full
/// scale). Replaces `min(1.25, ...)` in effectiveGainOut/In: let the gain be what
/// the user asked for, then tell them if the result clips.
///
/// `outgoing` and `incoming` are the overlap region of each track, same length,
/// one channel. Run per channel and take the maximum.
public func predictedOverlapPeak(
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
// If the peak exceeds about 0.98, show "Overlap clips by +x.x dB" and offer a
// one-click trim of both sides. Whatever gain is applied, re-dither to 16 bit
// (TPDF) when rendering the final 44.1 kHz stream; undithered gain changes on
// 16-bit audio add distortion at low levels.

// MARK: - Real waveform data

/// Min/max peak pyramid. Level 0 has one bucket per Red Book frame (588 samples at
/// 44.1 kHz); each higher level halves the resolution. Immutable and Sendable, so
/// the Canvas can read it from any thread without locks, and a redraw only ever
/// touches about one bucket per horizontal point.
public struct PeakPyramid: Sendable {
    public struct Level: Sendable {
        public let framesPerBucket: Int
        public let minima: [Float]
        public let maxima: [Float]
    }
    public static let samplesPerRedBookFrame = 588
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
// In drawTaperedDualWaveforms, replace the sin/cos expressions with
// `pyramid.columns(for:columns:)` and multiply each column by the same
// effectiveGainOut/In used for the burn. Until transient detection is real, remove
// the "Spectral" toggle rather than tinting on an amplitude threshold.
//
// Audition: render the overlap ONCE into an AVAudioPCMBuffer using the exact
// function that renders the burn stream, schedule it on a single
// AVAudioPlayerNode, and drive the green playhead from the node's sample time.
// Re-render when a drag ends (it takes milliseconds for 15 s of audio). That way
// what you hear is what gets burned, with no second DSP path to keep in sync.
