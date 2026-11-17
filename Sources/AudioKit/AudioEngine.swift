import Foundation
import OpticalCore

public struct KroutonCDTextPack: Sendable, Equatable {
    public let packType: UInt8       // 0x80 = Title, 0x81 = Performer, 0x8E = UPC/ISRC
    public let trackNumber: UInt8    // 0 = Album-level, 1..99 = Track-level
    let sequenceNumber: UInt8
    let blockAndCharPos: UInt8
    let payload12Bytes: [UInt8]
    public let crc16Inverted: UInt16 // Inverted CRC-16 CCITT (poly 0x1021)

    public var raw18Bytes: [UInt8] {
        var bytes: [UInt8] = [packType, trackNumber, sequenceNumber, blockAndCharPos]
        bytes.append(contentsOf: payload12Bytes.prefix(12))
        while bytes.count < 16 { bytes.append(0) }
        bytes.append(UInt8((crc16Inverted >> 8) & 0xFF))
        bytes.append(UInt8(crc16Inverted & 0xFF))
        return bytes
    }
}

public struct KroutonAudioEngine {
    public static let version = "0.1.0-alpha.1"

    /// Converts a Red Book frame count (75 frames/sec) into canonical MM:SS:FF timecode
    public static func formatFramesToMMSSFF(_ totalFrames: Int64) -> String {
        let clamped = max(0, totalFrames)
        let ff = clamped % 75
        let totalSeconds = clamped / 75
        let ss = totalSeconds % 60
        let mm = totalSeconds / 60
        return String(format: "%02d:%02d:%02d", mm, ss, ff)
    }

    /// Equal-power crossfade gains: fadeOut^2 + fadeIn^2 == 1.0 across t in [0, 1]
    public static func equalPowerCrossfadeGains(progress t: Double) -> (fadeOut: Double, fadeIn: Double) {
        let clamped = max(0.0, min(1.0, t))
        let angle = clamped * (.pi / 2.0)
        return (cos(angle), sin(angle))
    }

    /// Standard Red Book CD-Text CRC-16 CCITT (polynomial 0x1021, initial 0x0000, bitwise inverted per IEC 60908)
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

    /// Packs a sanitized string into 18-byte Sony/Philips CD-Text packs for the given packType and trackNumber
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

    /// Compiles a frame-accurate Red Book .cue sheet for a sequence of KroutonRedBookTrack tracks
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

// MARK: - Sprint 1: Pro Crossfade Envelope Curves & Per-Boundary Transition Spec

public enum KroutonCrossfadeCurve: String, CaseIterable, Identifiable, Codable, Sendable {
    case equalPower = "Equal-Power (cos/sin)"
    case sCurveHermite = "S-Curve (Smooth Hermite)"
    case linear = "Linear Ramp"
    case exponential = "Exponential Punch"

    public var id: String { rawValue }

    /// Evaluates normalized single-channel gain in [0, 1] for fade-in at progress t in [0, 1]
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

    /// Evaluates normalized single-channel gain in [0, 1] for fade-out at progress t in [0, 1]
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

public struct KroutonTrackTransitionSpec: Identifiable, Hashable, Codable, Sendable {
    public var id: UUID
    public var overlapSeconds: Double      // 0.0s (Splice) .. 30.0s Crossfade
    public var preGapSeconds: Double       // 0.0s (Gapless) .. 4.0s INDEX 00 Pause
    public var fadeOutCurve: KroutonCrossfadeCurve
    public var fadeInCurve: KroutonCrossfadeCurve
    public var curveTension: Double        // -1.0 (Concave Dip) .. 0.0 .. +1.0 (Convex Boost)
    public var spliceIndex01Ratio: Double  // 0.15 .. 0.85 position of Red Book INDEX 01 marker
    var outgoingTrimDB: Double      // -12.0 .. +6.0 dB
    var incomingTrimDB: Double      // -12.0 .. +6.0 dB
    var asymmetricUnlinked: Bool
    var fadeOutStartRatio: Double   // 0.0 .. 0.45
    var fadeInEndRatio: Double      // 0.55 .. 1.0
    var spectralTransientTint: Bool
    var gainMatchLUFS: Bool
    public var subIndexRatios: [Double]
    public var fadeOutMidTrim: Double?
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
        self.fadeInMidTrim = fadeInMidTrim.map { max(-0.45, min(0.45, $0)) }
    }

    public func effectiveGainOut(at t: Double) -> Double {
        let start = asymmetricUnlinked ? fadeOutStartRatio : 0.0
        let normT = t <= start ? 0.0 : min(1.0, (t - start) / max(0.05, 1.0 - start))
        let base = fadeOutCurve.gainOut(at: normT)
        let expPower = pow(2.0, -curveTension * 1.35)
        var shaped = pow(max(0.0, min(1.0, base)), expPower)
        if let mid = fadeOutMidTrim {
            let bell = 4.0 * normT * (1.0 - normT)
            shaped = max(0.0, min(1.0, shaped + mid * bell))
        }
        let trimLinear = pow(10.0, outgoingTrimDB / 20.0)
        return max(0.0, shaped * trimLinear)
    }

    public func effectiveGainIn(at t: Double) -> Double {
        let end = asymmetricUnlinked ? fadeInEndRatio : 1.0
        let normT = t >= end ? 1.0 : max(0.0, t / max(0.05, end))
        let base = fadeInCurve.gainIn(at: normT)
        let expPower = pow(2.0, -curveTension * 1.35)
        var shaped = pow(max(0.0, min(1.0, base)), expPower)
        if let mid = fadeInMidTrim {
            let bell = 4.0 * normT * (1.0 - normT)
            shaped = max(0.0, min(1.0, shaped + mid * bell))
        }
        let trimLinear = pow(10.0, incomingTrimDB / 20.0)
        return max(0.0, shaped * trimLinear)
    }

    public var isCrossfading: Bool { overlapSeconds >= 0.1 }
    public var overlapRedBookFrames: Int64 { Int64((overlapSeconds * 75.0).rounded()) }
    public var preGapRedBookFrames: Int64 { isCrossfading ? 0 : Int64((preGapSeconds * 75.0).rounded()) }

    func predictedPeak(outgoing: [Float], incoming: [Float]) -> Double {
        predictedOverlapPeak(
            outgoing: outgoing,
            incoming: incoming,
            gainOut: { effectiveGainOut(at: $0) },
            gainIn: { effectiveGainIn(at: $0) }
        )
    }

    var badgeSummary: String {
        if isCrossfading {
            return String(format: "%.1fs X-Fade (%@)", overlapSeconds, fadeOutCurve == fadeInCurve ? fadeOutCurve.rawValue.components(separatedBy: " ").first ?? "EqPwr" : "Asym")
        } else if preGapSeconds <= 0.01 {
            return "0.0s Gapless (DAO)"
        } else {
            return String(format: "%.1fs INDEX 00", preGapSeconds)
        }
    }
}

// MARK: - Sprint 1: 3-Tier Acoustic / AI Track & CD-TEXT Auto-Identifier

public struct KroutonIdentifiedTrackMetadata: Sendable, Equatable {
    public let title: String
    public let performer: String
    public let isrcCode: String
    let confidenceSource: String
}

public enum KroutonTrackAutoIdentifier {
    /// Conservative filename suggestion using FilenameTitleGuess: never invents ISRCs or fake performer names,
    /// preserves legitimate words ("Final Countdown", "Radio Edit", "Demo Tape"), and labels provenance honestly.
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

public enum SpliceTransitionMode: String, CaseIterable, Identifiable, Sendable {
    case gap = "Gap"
    case gapless = "Gapless"
    case crossfade = "Crossfade"
    public var id: String { rawValue }
}

extension KroutonTrackTransitionSpec {
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
