import Foundation

// CD-TEXT block compiler.
//
// Replaces `KroutonMarmaladeModule.buildCDTextPacks`, which packed one string at a
// time. A CD-TEXT block is compiled as a whole, because:
//
//   1. All strings of one pack type (album, track 1, track 2, ...) form ONE byte
//      stream, each string NUL-terminated, cut into 12-byte payloads. A string
//      starts right after the previous string's NUL, even mid-pack. Padding each
//      string to a pack boundary makes players read the padding NULs as empty
//      strings for the following tracks, so titles shift.
//   2. Header byte 1 is the track of the FIRST payload byte; header byte 3 carries
//      how many characters of that string sit in earlier packs (capped at 15).
//   3. Sequence numbers run 0...n across the whole block, not per string.
//   4. Every block ends with three 0x8F size-info packs that many players need
//      before they show anything.
//   5. Text is ISO 8859-1 (or MS-JIS in a double-byte block), never UTF-8.
//
// WHEN YOU NEED THIS: only if you hand raw packs to the drive yourself or export a
// `.cdt` file. cdrdao (CD_TEXT in the TOC file) and DiscRecording (DRCDTextBlock)
// both do this packing for you from plain strings; prefer them if that is your path.
//
// Not compiled here (no Swift toolchain in my sandbox). The algorithm was checked
// with a line-for-line reference port: CRC check value, contiguous packing, and a
// round trip through an independent decoder.

public enum CDTextField: UInt8, CaseIterable, Sendable, Codable {
    case title = 0x80
    case performer = 0x81
    case songwriter = 0x82
    case composer = 0x83
    case arranger = 0x84
    case message = 0x85
    /// Album entry = UPC/EAN (13 digits). Track entries = ISRC (12 characters).
    case upcOrISRC = 0x8E
}

public struct CDTextInput: Sendable {
    /// Album-level strings (header track number 0).
    public var album: [CDTextField: String]
    /// One dictionary per audio track, in disc order.
    public var tracks: [[CDTextField: String]]
    public var firstTrackNumber: UInt8
    /// 0x09 = English. See the language table in MMC-3 Annex J / EBU Tech 3264.
    public var languageCode: UInt8

    public init(
        album: [CDTextField: String],
        tracks: [[CDTextField: String]],
        firstTrackNumber: UInt8 = 1,
        languageCode: UInt8 = 0x09
    ) {
        self.album = album
        self.tracks = tracks
        self.firstTrackNumber = firstTrackNumber
        self.languageCode = languageCode
    }
}

public struct CDTextBlock: Sendable, Equatable {
    /// 18-byte packs in block order.
    public let packs: [[UInt8]]
    /// Fields whose text could not be represented exactly in ISO 8859-1.
    public let warnings: [String]

    /// Concatenated packs, as the drive expects them.
    public var packBytes: [UInt8] { packs.flatMap { $0 } }

    /// `.cdt` layout used by cdrecord's `textfile=`: a 4-byte READ TOC style header
    /// (big-endian length of everything after the length field, two reserved bytes).
    public var cdtFileBytes: [UInt8] {
        let body = packBytes
        let length = body.count + 2
        return [UInt8((length >> 8) & 0xFF), UInt8(length & 0xFF), 0, 0] + body
    }
}

public enum CDTextError: Error, Equatable {
    case noTracks
    case tooManyTracks(Int)
    /// Conservative ceiling of 255 packs per block (one-byte sequence number).
    case tooManyPacks(Int)
}

public enum CDTextBlockCompiler {

    public static func compile(_ input: CDTextInput, blockNumber: UInt8 = 0) throws -> CDTextBlock {
        guard !input.tracks.isEmpty else { throw CDTextError.noTracks }
        guard Int(input.firstTrackNumber) + input.tracks.count - 1 <= 99 else {
            throw CDTextError.tooManyTracks(input.tracks.count)
        }
        let block = blockNumber & 0x07
        var warnings: [String] = []
        var packs: [[UInt8]] = []
        var packCounts = [UInt8](repeating: 0, count: 16)
        var sequence = 0

        // Ascending pack-type order is required.
        for field in CDTextField.allCases.sorted(by: { $0.rawValue < $1.rawValue }) {
            let rawStrings = [input.album[field] ?? ""] + input.tracks.map { $0[field] ?? "" }
            // If nobody has this field, omit the pack type entirely. If anybody has
            // it, every track gets an entry (an empty one is a lone NUL).
            guard rawStrings.contains(where: { !$0.isEmpty }) else { continue }

            // Build the per-type byte stream, remembering for each byte which track
            // it belongs to and how many characters of that string precede it.
            var stream: [(byte: UInt8, track: UInt8, charsBefore: Int)] = []
            for (index, raw) in rawStrings.enumerated() {
                let trackByte: UInt8 = index == 0 ? 0 : input.firstTrackNumber + UInt8(index - 1)
                let encoded = encodeLatin1(raw)
                if encoded.lossy {
                    warnings.append("\(field) for \(index == 0 ? "album" : "track \(trackByte)") was approximated for ISO 8859-1")
                }
                for (k, byte) in encoded.bytes.enumerated() {
                    stream.append((byte, trackByte, k))
                }
                stream.append((0x00, trackByte, encoded.bytes.count)) // terminator
            }

            var offset = 0
            while offset < stream.count {
                let chunk = stream[offset..<min(offset + 12, stream.count)]
                var payload = chunk.map(\.byte)
                // Only the LAST pack of a pack type is zero-padded.
                payload.append(contentsOf: [UInt8](repeating: 0, count: 12 - payload.count))
                let first = chunk[chunk.startIndex]
                let positionNibble = UInt8(min(15, first.charsBefore))
                let header: [UInt8] = [field.rawValue, first.track, UInt8(sequence & 0xFF), (block << 4) | positionNibble]
                packs.append(seal(header + payload))
                packCounts[Int(field.rawValue - 0x80)] += 1
                sequence += 1
                offset += 12
            }
        }

        // Size info: 36 bytes spread over three 0x8F packs.
        packCounts[15] = 3
        let totalPacks = sequence + 3
        guard totalPacks <= 255 else { throw CDTextError.tooManyPacks(totalPacks) }

        var sizeInfo: [UInt8] = [
            0x00,                                                  // character code: ISO 8859-1
            input.firstTrackNumber,
            input.firstTrackNumber + UInt8(input.tracks.count - 1),
            0x00,                                                  // no Mode 2 packs, no copyright flags
        ]
        sizeInfo += packCounts                                     // counts for 0x80...0x8F
        var lastSequenceOfBlock = [UInt8](repeating: 0, count: 8)
        lastSequenceOfBlock[Int(block)] = UInt8(totalPacks - 1)
        var languageOfBlock = [UInt8](repeating: 0, count: 8)
        languageOfBlock[Int(block)] = input.languageCode
        sizeInfo += lastSequenceOfBlock + languageOfBlock
        assert(sizeInfo.count == 36)

        for part in 0..<3 {
            let header: [UInt8] = [0x8F, UInt8(part), UInt8(sequence & 0xFF), block << 4]
            packs.append(seal(header + Array(sizeInfo[(part * 12)..<(part * 12 + 12)])))
            sequence += 1
        }
        return CDTextBlock(packs: packs, warnings: warnings)
    }

    /// CRC-16, polynomial 0x1021, initial value 0, result inverted, stored big-endian.
    /// Check value: `crc16Inverted(Array("123456789".utf8)) == 0xCE3C`.
    public static func crc16Inverted(_ bytes: [UInt8]) -> UInt16 {
        var crc: UInt16 = 0
        for byte in bytes {
            crc ^= UInt16(byte) << 8
            for _ in 0..<8 {
                crc = (crc & 0x8000) != 0 ? (crc << 1) ^ 0x1021 : crc << 1
            }
        }
        return ~crc
    }

    private static func seal(_ sixteen: [UInt8]) -> [UInt8] {
        precondition(sixteen.count == 16)
        let crc = crc16Inverted(sixteen)
        return sixteen + [UInt8(crc >> 8), UInt8(crc & 0xFF)]
    }

    // MARK: - Text encoding

    private static let typographicFallbacks: [Unicode.Scalar: String] = [
        "\u{2018}": "'", "\u{2019}": "'", "\u{201A}": ",", "\u{201C}": "\"", "\u{201D}": "\"",
        "\u{2013}": "-", "\u{2014}": "-", "\u{2026}": "...", "\u{2022}": "*", "\u{00A0}": " ",
    ]

    /// Encodes to ISO 8859-1, dropping control characters. Characters outside
    /// Latin-1 are folded (diacritics stripped, smart quotes straightened); anything
    /// still unrepresentable becomes "?" and sets `lossy`.
    ///
    /// Note: the CD-TEXT character set differs from true ISO 8859-1 in a handful of
    /// code points. For Western European text they agree; test anything exotic on a
    /// real player.
    public static func encodeLatin1(_ string: String) -> (bytes: [UInt8], lossy: Bool) {
        var bytes: [UInt8] = []
        var lossy = false
        for scalar in string.precomposedStringWithCanonicalMapping.unicodeScalars {
            let v = scalar.value
            if (0x20...0x7E).contains(v) || (0xA1...0xFF).contains(v) {
                bytes.append(UInt8(v))
                continue
            }
            if v < 0x20 || (0x7F...0x9F).contains(v) { continue } // control characters: drop
            let replacement = typographicFallbacks[scalar]
                ?? String(scalar).folding(options: [.diacriticInsensitive, .widthInsensitive], locale: nil)
            let ascii = replacement.unicodeScalars.filter { (0x20...0x7E).contains($0.value) }
            if ascii.isEmpty || ascii.count != replacement.unicodeScalars.count {
                bytes.append(UInt8(ascii: "?"))
            } else {
                bytes.append(contentsOf: ascii.map { UInt8($0.value) })
            }
            lossy = true
        }
        return (bytes, lossy)
    }
}

// Invariants worth adding to krouton-verify:
//   - every pack is 18 bytes and its CRC verifies
//   - sequence numbers are 0..<packs.count with no gaps
//   - joining the payloads of one pack type and splitting on NUL yields
//     [album, track 1, ..., track N] exactly (round trip)
//   - size-info counts equal the actual number of packs per type
//   - a golden comparison against `cdrdao` or `cdrskin --cdtext_to_v07t` output for
//     the same strings, captured once and checked in
