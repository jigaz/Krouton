import Foundation

// MARK: - DiscJuggler (.cdi) images

/// The track layout of a DiscJuggler `.cdi` image, the usual form of self-booting Dreamcast
/// discs: session 1 holds audio (often one short track) and session 2 one data track whose
/// file system expects to start at a fixed address (11,702 for a 302-frame audio track).
///
/// Programmer's notes: the format is undocumented; this follows the layout cdirip reads. The
/// last 8 bytes give the version and the descriptor position (for version 3.5, its distance
/// from the end). The descriptor lists sessions, each with its tracks: two 10-byte start marks,
/// the file name, pregap and length, mode (0 audio, 1 Mode 1, 2 Mode 2), start address, total
/// length and sector size code (0: 2,048, 1: 2,336, 2: 2,352).
/// Track data lies in the file in order from byte 0, each track's pregap first.
public struct KroutonDiscJugglerImage: Sendable, Equatable {
    public enum Mode: UInt32, Sendable { case audio = 0, mode1 = 1, mode2 = 2 }

    public struct Track: Sendable, Equatable {
        public let session: Int
        public let mode: Mode
        /// Bytes per sector in the file.
        public let sectorSize: Int
        public let pregapFrames: Int64
        public let frames: Int64
        /// Disc address of the track's first frame after the pregap.
        public let startLBA: Int64
        /// File offset of that frame.
        public let fileOffset: Int64

        /// Where the 2,048 bytes of user data sit inside each data sector of the file.
        public var userDataOffset: Int {
            switch (mode, sectorSize) {
            case (.mode2, 2_336): return 8
            case (.mode2, 2_352): return 24
            case (.mode1, 2_352): return 16
            default: return 0
            }
        }
    }

    public static let version2: UInt32 = 0x8000_0004
    public static let version3: UInt32 = 0x8000_0005
    public static let version35: UInt32 = 0x8000_0006

    public let version: UInt32
    public let tracks: [Track]

    public struct ParseError: Error, LocalizedError, Sendable {
        public let message: String
        public var errorDescription: String? { message }
    }

    // MARK: - Reading

    /// Reads the descriptor at the end of the file; the track data itself isn't read.
    public static func read(_ url: URL) throws -> Self {
        let handle = try FileHandle(forReadingFrom: url)
        defer { try? handle.close() }
        let length = Int64(try handle.seekToEnd())
        guard length > 8 else { throw ParseError(message: "\(url.lastPathComponent) is too short to be a .cdi image.") }
        try handle.seek(toOffset: UInt64(length - 8))
        let tail = [UInt8](handle.readData(ofLength: 8))
        let version = KroutonBytes.readLE32(tail, 0), pointer = Int64(KroutonBytes.readLE32(tail, 4))
        let start = version == version35 ? length - pointer : pointer
        guard [version2, version3, version35].contains(version), start > 0, start < length - 8 else {
            throw ParseError(message: "\(url.lastPathComponent) isn't a DiscJuggler image Krouton can read (version 2, 3 or 3.5).")
        }
        try handle.seek(toOffset: UInt64(start))
        let descriptor = [UInt8](handle.readData(ofLength: Int(length - 8 - start)))
        return try parse(descriptor: descriptor, version: version, fileLength: length)
    }

    /// Parses the descriptor (the bytes from its position up to the 8-byte tail).
    public static func parse(descriptor bytes: [UInt8], version: UInt32, fileLength: Int64) throws -> Self {
        var cursor = Cursor(bytes: bytes)
        let mark: [UInt8] = [0, 0, 0x01, 0, 0, 0, 0xFF, 0xFF, 0xFF, 0xFF]
        var tracks: [Track] = []
        var position: Int64 = 0
        let sessions = try cursor.u16()
        for session in 1...max(1, sessions) where sessions > 0 {
            let count = try cursor.u16()
            for _ in 0..<count {
                if try cursor.u32() != 0 { try cursor.skip(8) }
                guard try cursor.take(10) == mark, try cursor.take(10) == mark else {
                    throw ParseError(message: "This .cdi image's track list is in a layout Krouton doesn't know.")
                }
                try cursor.skip(4)
                try cursor.skip(Int(try cursor.u8()))
                try cursor.skip(11 + 4 + 4)
                if try cursor.u32() == 0x8000_0000 { try cursor.skip(8) }
                try cursor.skip(2)
                let pregap = Int64(try cursor.u32()), frames = Int64(try cursor.u32())
                try cursor.skip(6)
                let modeValue = try cursor.u32()
                try cursor.skip(12)
                let startLBA = Int64(try cursor.u32()), total = Int64(try cursor.u32())
                try cursor.skip(16)
                let sizes: [UInt32: Int] = [0: 2_048, 1: 2_336, 2: 2_352]
                guard let mode = Mode(rawValue: modeValue), let size = sizes[try cursor.u32()], total >= frames + pregap else {
                    throw ParseError(message: "Track \(tracks.count + 1) of this .cdi image has a mode or sector size Krouton can't burn.")
                }
                try cursor.skip(29)
                if version != version2 {
                    try cursor.skip(5)
                    if try cursor.u32() == 0xFFFF_FFFF { try cursor.skip(78) }
                }
                tracks.append(Track(session: session, mode: mode, sectorSize: size, pregapFrames: pregap,
                                    frames: frames, startLBA: startLBA, fileOffset: position + pregap * Int64(size)))
                position += total * Int64(size)
            }
            try cursor.skip(4 + 8 + (version == version2 ? 0 : 1))
        }
        guard !tracks.isEmpty, position <= fileLength else {
            throw ParseError(message: "This .cdi image's track list doesn't match the file; it may be incomplete.")
        }
        return Self(version: version, tracks: tracks)
    }

    // MARK: - Burning plan

    /// Audio in session 1, one data track in session 2, at the address the image expects: a
    /// burn puts session 2's data after the first lead-out (6,750 frames), the next lead-in
    /// (4,500) and its pregap, and the game only boots if that lands where it was mastered.
    public func audioDataPlan() throws -> (audio: [Track], data: Track) {
        let audio = tracks.filter { $0.session == 1 }
        let second = tracks.filter { $0.session == 2 }
        guard !audio.isEmpty, audio.allSatisfy({ $0.mode == .audio }), second.count == 1,
              tracks.count == audio.count + 1, let data = second.first, data.mode != .audio else {
            throw ParseError(message: "Krouton burns .cdi images laid out as audio then data (session 1 audio, session 2 one data track), the usual self-booting Dreamcast layout. This image is laid out differently. Nothing was written.")
        }
        guard let last = audio.last else { throw ParseError(message: "This .cdi image has no audio session.") }
        let expected = last.startLBA + last.frames + 6_750 + 4_500 + data.pregapFrames
        guard data.startLBA == expected else {
            throw ParseError(message: "This image's data starts at sector \(data.startLBA), but burned after its audio it would start at \(expected), and the game wouldn't boot. Nothing was written.")
        }
        return (audio, data)
    }

    // MARK: - Bytes


    struct Cursor {
        let bytes: [UInt8]
        var offset = 0

        mutating func take(_ n: Int) throws -> [UInt8] {
            guard n >= 0, offset + n <= bytes.count else {
                throw ParseError(message: "This .cdi image's track list ends early; it may be damaged.")
            }
            defer { offset += n }
            return Array(bytes[offset..<(offset + n)])
        }
        mutating func skip(_ n: Int) throws { _ = try take(n) }
        mutating func u8() throws -> UInt8 { try take(1)[0] }
        mutating func u16() throws -> Int { let b = try take(2); return Int(b[0]) | Int(b[1]) << 8 }
        mutating func u32() throws -> UInt32 { KroutonBytes.readLE32(try take(4), 0) }
    }
}
