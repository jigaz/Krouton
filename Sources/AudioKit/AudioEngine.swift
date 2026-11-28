import Foundation
import OpticalCore

// MARK: - CD-Text Packs, Timecodes and Cue Sheets

/// One 18-byte CD-Text pack, as `KroutonAudioEngine.buildCDTextPacks` builds it.
public struct KroutonCDTextPack: Sendable, Equatable {
    /// The pack type: 0x80 title, 0x81 performer, 0x8E UPC/ISRC.
    public let packType: UInt8
    /// 0 for the album, 1 to 99 for a track.
    public let trackNumber: UInt8
    let sequenceNumber: UInt8
    let blockAndCharPos: UInt8
    let payload12Bytes: [UInt8]
    /// The pack's CRC-16 (CCITT polynomial 0x1021, inverted).
    public let crc16Inverted: UInt16

    /// The pack as 18 bytes: header, payload, CRC.
    public var raw18Bytes: [UInt8] {
        var bytes: [UInt8] = [packType, trackNumber, sequenceNumber, blockAndCharPos]
        bytes.append(contentsOf: payload12Bytes.prefix(12))
        while bytes.count < 16 { bytes.append(0) }
        bytes.append(UInt8((crc16Inverted >> 8) & 0xFF))
        bytes.append(UInt8(crc16Inverted & 0xFF))
        return bytes
    }
}

/// Audio CD helpers: timecodes, crossfade gains, CD-Text packs and cue sheets.
public struct KroutonAudioEngine {
    /// The module version krouton-verify checks.
    public static let version = "0.1.0-alpha.1"

    /// A CD frame count (75 a second) as MM:SS:FF.
    public static func formatFramesToMMSSFF(_ totalFrames: Int64) -> String {
        let clamped = max(0, totalFrames)
        let ff = clamped % 75
        let totalSeconds = clamped / 75
        let ss = totalSeconds % 60
        let mm = totalSeconds / 60
        return String(format: "%02d:%02d:%02d", mm, ss, ff)
    }

    /// Equal-power crossfade gains at progress `t` (0…1): fadeOut² + fadeIn² = 1.
    public static func equalPowerCrossfadeGains(progress t: Double) -> (fadeOut: Double, fadeIn: Double) {
        let clamped = max(0.0, min(1.0, t))
        let angle = clamped * (.pi / 2.0)
        return (cos(angle), sin(angle))
    }

    /// The CD-Text pack CRC over the first 16 bytes: CRC-16 CCITT (polynomial 0x1021, initial 0),
    /// inverted.
    public static func computeCDTextInvertedCRC16(_ headerAndPayload16Bytes: [UInt8]) -> UInt16 {
        var crc: UInt16 = 0x0000
        for byte in headerAndPayload16Bytes.prefix(16) {
            crc ^= UInt16(byte) << 8
            for _ in 0..<8 {
                if (crc & 0x8000) != 0 {
                    crc = (crc << 1) ^ 0x1021
                } else {
                    crc <<= 1
                }
            }
        }
        return ~crc
    }

    /// Packs one string into 18-byte CD-Text packs, each string padded to a pack boundary and
    /// the character position always 0. A real block needs `CDTextBlockCompiler`, which packs all
    /// strings of a type together; only krouton-verify calls this.
    public static func buildCDTextPacks(
        packType: UInt8,
        trackNumber: UInt8,
        text: String,
        startSequence: UInt8 = 0
    ) -> [KroutonCDTextPack] {
        let clean = KroutonCDTextSanitizer.sanitize(text)
        var nullTerminated = Array(clean.utf8)
        nullTerminated.append(0x00)

        var packs: [KroutonCDTextPack] = []
        var seq = startSequence
        var idx = 0

        while idx < nullTerminated.count {
            let chunkEnd = min(idx + 12, nullTerminated.count)
            var payload = Array(nullTerminated[idx..<chunkEnd])
            while payload.count < 12 { payload.append(0x00) }

            let headerAndPayload: [UInt8] = [packType, trackNumber, seq, 0x00] + payload
            let crc = computeCDTextInvertedCRC16(headerAndPayload)
            packs.append(
                KroutonCDTextPack(
                    packType: packType,
                    trackNumber: trackNumber,
                    sequenceNumber: seq,
                    blockAndCharPos: 0x00,
                    payload12Bytes: payload,
                    crc16Inverted: crc
                )
            )
            seq &+= 1
            idx += 12
        }
        return packs
    }

    /// A cue sheet for `tracks` in one BINARY file: CATALOG, TITLE and PERFORMER, then per track
    /// its ISRC, FLAGS (DCP, PRE), INDEX 00 for a pause and INDEX 01. The app uses
    /// `AudioProject.compileCueSheet()` and falls back to this.
    public static func compileRedBookCueSheet(
        albumTitle: String,
        albumPerformer: String,
        mcnCatalog: String = "",
        masterBinFilename: String = "KROUTON_AUDIO_MASTER.BIN",
        tracks: [KroutonRedBookTrack]
    ) -> String {
        var lines: [String] = []
        let cleanMCN = KroutonCDTextSanitizer.sanitizeMCN(mcnCatalog)
        if cleanMCN.count == 13 {
            lines.append("CATALOG \(cleanMCN)")
        }
        lines.append("TITLE \"\(KroutonCDTextSanitizer.sanitize(albumTitle))\"")
        lines.append("PERFORMER \"\(KroutonCDTextSanitizer.sanitize(albumPerformer))\"")
        lines.append("FILE \"\(masterBinFilename)\" BINARY")

        var cursorFrames: Int64 = 0
        for (idx, cube) in tracks.enumerated() {
            let trackNum = idx + 1
            lines.append(String(format: "  TRACK %02d AUDIO", trackNum))
            lines.append("    TITLE \"\(KroutonCDTextSanitizer.sanitize(cube.title))\"")
            lines.append("    PERFORMER \"\(KroutonCDTextSanitizer.sanitize(cube.performer))\"")

            let cleanISRC = KroutonCDTextSanitizer.sanitizeISRC(cube.isrcCode)
            if cleanISRC.count == 12 {
                lines.append("    ISRC \(cleanISRC)")
            }

            var flags: [String] = []
            if cube.copyPermittedSCMS { flags.append("DCP") }
            if cube.preEmphasisEnabled { flags.append("PRE") }
            if !flags.isEmpty {
                lines.append("    FLAGS \(flags.joined(separator: " "))")
            }

            let pregapFrames = Int64((max(0.0, cube.preGapSeconds) * 75.0).rounded())
            if pregapFrames > 0 {
                lines.append("    INDEX 00 \(formatFramesToMMSSFF(cursorFrames))")
                cursorFrames += pregapFrames
            }
            lines.append("    INDEX 01 \(formatFramesToMMSSFF(cursorFrames))")
            let audioFrames = Int64((max(0.0, cube.durationSeconds) * 75.0).rounded())
            cursorFrames += audioFrames
        }

        return lines.joined(separator: "\n") + "\n"
    }
}

// MARK: - Crossfade Curves and Track Transitions

/// The shape of a fade. The raw values are display names and are saved.
public enum KroutonCrossfadeCurve: String, CaseIterable, Identifiable, Codable, Sendable {
    case equalPower = "Equal-Power (cos/sin)"
    case sCurveHermite = "S-Curve (Smooth Hermite)"
    case linear = "Linear Ramp"
    case exponential = "Exponential Punch"

    public var id: String { rawValue }

    /// The fade-in gain (0…1) at progress `t` (0…1).
    public func gainIn(at t: Double) -> Double {
        let x = max(0.0, min(1.0, t))
        switch self {
        case .equalPower:
            return sin(x * (.pi / 2.0))
        case .sCurveHermite:
            return x * x * (3.0 - 2.0 * x)
        case .linear:
            return x
        case .exponential:
            return x * x
        }
    }

    /// The fade-out gain (0…1) at progress `t` (0…1).
    public func gainOut(at t: Double) -> Double {
        let x = max(0.0, min(1.0, t))
        switch self {
        case .equalPower:
            return cos(x * (.pi / 2.0))
        case .sCurveHermite:
            let inv = 1.0 - x
            return inv * inv * (3.0 - 2.0 * inv)
        case .linear:
            return 1.0 - x
        case .exponential:
            let inv = 1.0 - x
            return inv * inv
        }
    }
}

/// How one track hands over to the next on an audio CD: a pause, a gapless cut or a crossfade, with
/// its curves and gains. Values are clamped to their ranges on creation.
public struct KroutonTrackTransitionSpec: Identifiable, Hashable, Codable, Sendable {
    public var id: UUID
    /// How long the two tracks overlap, 0 to 30 s; 0 is a cut or a pause.
    public var overlapSeconds: Double
    /// The pause before the next track (INDEX 00), 0 to 4 s.
    public var preGapSeconds: Double
    /// The curve the outgoing track fades on.
    public var fadeOutCurve: KroutonCrossfadeCurve
    /// The curve the incoming track fades on.
    public var fadeInCurve: KroutonCrossfadeCurve
    /// Bends both curves, -1 (dips) to 1 (bulges); 0 leaves them as they are.
    public var curveTension: Double
    /// Where in the overlap the next track's INDEX 01 falls, 0.15 to 0.85.
    public var spliceIndex01Ratio: Double
    /// Gain on the outgoing track, -12 to +6 dB.
    public var outgoingTrimDB: Double
    /// Gain on the incoming track, -12 to +6 dB.
    public var incomingTrimDB: Double
    /// Lets the fade-out start and the fade-in end move apart from the overlap's edges.
    public var asymmetricUnlinked: Bool
    /// With `asymmetricUnlinked`, where the fade-out starts, 0 to 0.45 of the overlap.
    public var fadeOutStartRatio: Double
    /// With `asymmetricUnlinked`, where the fade-in ends, 0.55 to 1 of the overlap.
    public var fadeInEndRatio: Double
    var spectralTransientTint: Bool
    var gainMatchLUFS: Bool
    /// Extra index marks (INDEX 02 and on) placed in the splice editor around this boundary, as
    /// fractions (0.05 to 0.95) of its view, sorted. The cue sheet maps marks before INDEX 01
    /// into this track and marks after it into the next.
    public var subIndexRatios: [Double]
    /// 1/4-point (t = 0.25) handle trim on the Fade-Out curve (-0.45 ... +0.45)
    public var fadeOutMidTrim: Double?
    /// 3/4-point (t = 0.75) handle trim on the Fade-Out curve (-0.45 ... +0.45)
    public var fadeOutThreeQuarterTrim: Double?
    /// 1/4-point (t = 0.25) handle trim on the Fade-In curve (-0.45 ... +0.45)
    public var fadeInQuarterTrim: Double?
    /// 3/4-point (t = 0.75) handle trim on the Fade-In curve (-0.45 ... +0.45)
    public var fadeInMidTrim: Double?

    public init(
        id: UUID = UUID(),
        overlapSeconds: Double = 0.0,
        preGapSeconds: Double = 2.0,
        fadeOutCurve: KroutonCrossfadeCurve = .equalPower,
        fadeInCurve: KroutonCrossfadeCurve = .equalPower,
        curveTension: Double = 0.0,
        spliceIndex01Ratio: Double = 0.50,
        outgoingTrimDB: Double = 0.0,
        incomingTrimDB: Double = 0.0,
        asymmetricUnlinked: Bool = false,
        fadeOutStartRatio: Double = 0.0,
        fadeInEndRatio: Double = 1.0,
        spectralTransientTint: Bool = true,
        gainMatchLUFS: Bool = false,
        subIndexRatios: [Double] = [],
        fadeOutMidTrim: Double? = nil,
        fadeOutThreeQuarterTrim: Double? = nil,
        fadeInQuarterTrim: Double? = nil,
        fadeInMidTrim: Double? = nil
    ) {
        self.id = id
        self.overlapSeconds = max(0.0, min(30.0, overlapSeconds))
        self.preGapSeconds = max(0.0, min(4.0, preGapSeconds))
        self.fadeOutCurve = fadeOutCurve
        self.fadeInCurve = fadeInCurve
        self.curveTension = max(-1.0, min(1.0, curveTension))
        self.spliceIndex01Ratio = max(0.15, min(0.85, spliceIndex01Ratio))
        self.outgoingTrimDB = max(-12.0, min(6.0, outgoingTrimDB))
        self.incomingTrimDB = max(-12.0, min(6.0, incomingTrimDB))
        self.asymmetricUnlinked = asymmetricUnlinked
        self.fadeOutStartRatio = max(0.0, min(0.45, fadeOutStartRatio))
        self.fadeInEndRatio = max(0.55, min(1.0, fadeInEndRatio))
        self.spectralTransientTint = spectralTransientTint
        self.gainMatchLUFS = gainMatchLUFS
        self.subIndexRatios = subIndexRatios.map { max(0.05, min(0.95, $0)) }.sorted()
        self.fadeOutMidTrim = fadeOutMidTrim.map { max(-0.45, min(0.45, $0)) }
        self.fadeOutThreeQuarterTrim = fadeOutThreeQuarterTrim.map { max(-0.45, min(0.45, $0)) }
        self.fadeInQuarterTrim = fadeInQuarterTrim.map { max(-0.45, min(0.45, $0)) }
        self.fadeInMidTrim = fadeInMidTrim.map { max(-0.45, min(0.45, $0)) }
    }

    /// The outgoing track's gain at progress `t` (0…1) through the overlap, with tension, handle
    /// trims and its dB trim applied.
    public func effectiveGainOut(at t: Double) -> Double {
        let start = asymmetricUnlinked ? fadeOutStartRatio : 0.0
        let normT = t <= start ? 0.0 : min(1.0, (t - start) / max(0.05, 1.0 - start))
        let base = fadeOutCurve.gainOut(at: normT)
        let expPower = pow(2.0, -curveTension * 1.35)
        var shaped = pow(max(0.0, min(1.0, base)), expPower)
        if let q1 = fadeOutMidTrim {
            let bell = 4.0 * normT * (1.0 - normT)
            shaped = max(0.0, min(1.0, shaped + q1 * bell))
        }
        if let q3 = fadeOutThreeQuarterTrim {
            let skewQ3 = 6.75 * normT * normT * (1.0 - normT)
            shaped = max(0.0, min(1.0, shaped + q3 * skewQ3))
        }
        let trimLinear = pow(10.0, outgoingTrimDB / 20.0)
        return max(0.0, shaped * trimLinear)
    }

    /// The incoming track's gain at progress `t` (0…1) through the overlap, with tension, handle
    /// trims and its dB trim applied.
    public func effectiveGainIn(at t: Double) -> Double {
        let end = asymmetricUnlinked ? fadeInEndRatio : 1.0
        let normT = t >= end ? 1.0 : max(0.0, t / max(0.05, end))
        let base = fadeInCurve.gainIn(at: normT)
        let expPower = pow(2.0, -curveTension * 1.35)
        var shaped = pow(max(0.0, min(1.0, base)), expPower)
        if let q1 = fadeInQuarterTrim {
            let skewQ1 = 6.75 * normT * (1.0 - normT) * (1.0 - normT)
            shaped = max(0.0, min(1.0, shaped + q1 * skewQ1))
        }
        if let q3 = fadeInMidTrim {
            let bell = 4.0 * normT * (1.0 - normT)
            shaped = max(0.0, min(1.0, shaped + q3 * bell))
        }
        let trimLinear = pow(10.0, incomingTrimDB / 20.0)
        return max(0.0, shaped * trimLinear)
    }

    /// True for an overlap of at least 0.1 s.
    public var isCrossfading: Bool { overlapSeconds >= 0.1 }
    /// The overlap in CD frames.
    public var overlapRedBookFrames: Int64 { Int64((overlapSeconds * 75.0).rounded()) }
    /// The pause in CD frames; 0 while crossfading.
    public var preGapRedBookFrames: Int64 { isCrossfading ? 0 : Int64((preGapSeconds * 75.0).rounded()) }
}

// MARK: - Track Title Suggestions

/// A title and performer suggested for a staged file.
public struct KroutonIdentifiedTrackMetadata: Sendable, Equatable {
    public let title: String
    public let performer: String
    /// Always empty: an ISRC can't be guessed.
    public let isrcCode: String
    let confidenceSource: String
}

/// Suggests track metadata for staged files. Not wired into the app yet (see
/// PENDING_INTEGRATION.md).
public enum KroutonTrackAutoIdentifier {
    /// A title and performer guessed from the file name with `FilenameTitleGuess`, or "Track NN"
    /// and `fallbackPerformer`. It never makes up an ISRC, and it says where each value came from.
    public static func identifyTrack(
        url: URL,
        trackNumber: Int,
        fallbackPerformer: String,
        byteSize: Int64 = 0
    ) -> KroutonIdentifiedTrackMetadata {
        let guessed = FilenameTitleGuess.guess(from: url)
        let title = guessed.title?.value ?? "Track \(String(format: "%02d", trackNumber))"
        let trimmedFallback = fallbackPerformer.trimmingCharacters(in: .whitespacesAndNewlines)
        let performer = guessed.performer?.value ?? trimmedFallback
        let sourceLabel = guessed.title?.source.rawValue ?? MetadataSource.filenameGuess.rawValue
        return KroutonIdentifiedTrackMetadata(
            title: KroutonCDTextSanitizer.sanitize(title),
            performer: performer.isEmpty ? "" : KroutonCDTextSanitizer.sanitize(performer),
            isrcCode: "",
            confidenceSource: sourceLabel
        )
    }
}

/// The three kinds of transition the splice editor offers.
public enum SpliceTransitionMode: String, CaseIterable, Identifiable, Sendable {
    case gap = "Gap"
    case gapless = "Gapless"
    case crossfade = "Crossfade"
    public var id: String { rawValue }
}

extension KroutonTrackTransitionSpec {
    /// This transition changed to `mode`, keeping what still applies: a 2 s pause for a gap, 2.5 s
    /// of overlap for a new crossfade.
    public func switched(to mode: SpliceTransitionMode) -> KroutonTrackTransitionSpec {
        var updated = self
        switch mode {
        case .gap:
            updated.overlapSeconds = 0
            updated.preGapSeconds = preGapSeconds > 0.1 ? preGapSeconds : 2.0
        case .gapless:
            updated.overlapSeconds = 0
            updated.preGapSeconds = 0
        case .crossfade:
            updated.overlapSeconds = overlapSeconds >= 0.25 ? overlapSeconds : 2.5
            updated.preGapSeconds = 0
        }
        return updated
    }
}
