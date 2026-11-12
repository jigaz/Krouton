import Foundation
import OpticalDough

public struct KroutonCDTextPack: Sendable, Equatable {
    public let packType: UInt8       // 0x80 = Title, 0x81 = Performer, 0x8E = UPC/ISRC
    public let trackNumber: UInt8    // 0 = Album-level, 1..99 = Track-level
    public let sequenceNumber: UInt8
    public let blockAndCharPos: UInt8
    public let payload12Bytes: [UInt8]
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

public struct KroutonMarmaladeModule {
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
        let clean = KroutonSeasoningSanitizer.sanitize(text)
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

    /// Compiles a frame-accurate Red Book .cue sheet for a sequence of KroutonAudioCube tracks
    public static func compileRedBookCueSheet(
        albumTitle: String,
        albumPerformer: String,
        mcnCatalog: String = "",
        masterBinFilename: String = "KROUTON_AUDIO_MASTER.BIN",
        tracks: [KroutonAudioCube]
    ) -> String {
        var lines: [String] = []
        let cleanMCN = KroutonSeasoningSanitizer.sanitizeMCN(mcnCatalog)
        if cleanMCN.count == 13 {
            lines.append("CATALOG \(cleanMCN)")
        }
        lines.append("TITLE \"\(KroutonSeasoningSanitizer.sanitize(albumTitle))\"")
        lines.append("PERFORMER \"\(KroutonSeasoningSanitizer.sanitize(albumPerformer))\"")
        lines.append("FILE \"\(masterBinFilename)\" BINARY")

        var cursorFrames: Int64 = 0
        for (idx, cube) in tracks.enumerated() {
            let trackNum = idx + 1
            lines.append(String(format: "  TRACK %02d AUDIO", trackNum))
            lines.append("    TITLE \"\(KroutonSeasoningSanitizer.sanitize(cube.title))\"")
            lines.append("    PERFORMER \"\(KroutonSeasoningSanitizer.sanitize(cube.performer))\"")

            let cleanISRC = KroutonSeasoningSanitizer.sanitizeISRC(cube.isrcCode)
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
