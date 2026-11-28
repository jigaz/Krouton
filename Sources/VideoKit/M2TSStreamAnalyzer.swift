import Foundation

// MARK: - M2TS Stream Analyzer

/// What a Blu-ray / AVCHD clip file needs to know about its `.m2ts` stream: which PIDs carry
/// video and audio, the first and last presentation times, and an entry point for every
/// key frame (where a player may start or seek to).
public struct KroutonM2TSAnalysis: Sendable, Equatable {
    /// A key frame: its time and the source packet it starts in.
    public struct EntryPoint: Sendable, Equatable {
        /// 90 kHz presentation time stamp of the key frame.
        public let pts: UInt64
        /// Index of the 192-byte source packet where its PES packet starts.
        public let sourcePacket: UInt32

        public init(pts: UInt64, sourcePacket: UInt32) {
            self.pts = pts
            self.sourcePacket = sourcePacket
        }
    }

    /// The PID of the program map table.
    public var programMapPID: UInt16 = 0x0100
    /// The PID that carries the program clock.
    public var pcrPID: UInt16 = 0
    /// The video stream's PID.
    public var videoPID: UInt16 = 0
    /// The video stream type from the PMT (0x1B for H.264).
    public var videoCoding: UInt8 = 0
    /// The first audio stream's PID, when there is one.
    public var audioPID: UInt16?
    /// The audio stream type from the PMT (0x81 for AC-3).
    public var audioCoding: UInt8 = 0
    /// Blu-ray audio presentation type: 1 mono, 3 stereo, 6 multi-channel.
    public var audioPresentation: UInt8 = 3
    /// How many 192-byte packets the file has.
    public var sourcePackets: UInt32 = 0
    /// 90 kHz, of the earliest and (end of the) latest video frame.
    public var firstPTS: UInt64 = 0
    /// See `firstPTS`.
    public var endPTS: UInt64 = 0
    /// One per key frame, in order.
    public var entryPoints: [EntryPoint] = []

    public init() {}

    /// Duration in seconds.
    public var duration: Double { Double(endPTS &- firstPTS) / 90_000 }
}

enum KroutonM2TSError: Error, LocalizedError, Sendable, Equatable {
    case notM2TS(String)
    case noVideo(String)

    public var errorDescription: String? {
        switch self {
        case .notM2TS(let name): return "\(name) is not a Blu-ray transport stream (192-byte packets)."
        case .noVideo(let name): return "\(name) has no H.264 video Krouton can find key frames in."
        }
    }
}

/// Reads an `.m2ts` file once, front to back, in 1 MiB pieces.
public struct KroutonM2TSAnalyzer: Sendable {
    /// A Blu-ray source packet: a 4-byte arrival time stamp and a 188-byte transport packet.
    public static let packetSize = 192

    private var result = KroutonM2TSAnalysis()
    private var packetIndex: UInt32 = 0
    private var minPTS = UInt64.max
    private var maxPTS: UInt64 = 0
    private var lastPTS: UInt64?
    private var frameDuration = UInt64.max
    private var sawAudioHeader = false

    public init() {}

    /// Analyzes the file at `url`.
    public static func analyze(url: URL) throws -> KroutonM2TSAnalysis {
        let name = url.lastPathComponent
        let handle = try FileHandle(forReadingFrom: url)
        defer { try? handle.close() }
        var analyzer = KroutonM2TSAnalyzer()
        let chunk = packetSize * 5_461
        while let data = try handle.read(upToCount: chunk), !data.isEmpty {
            guard data.count % packetSize == 0 || data.count < chunk else { throw KroutonM2TSError.notM2TS(name) }
            try analyzer.feed([UInt8](data), name: name)
        }
        return try analyzer.finish(name: name)
    }

    /// Feeds whole 192-byte source packets.
    public mutating func feed(_ bytes: [UInt8], name: String = "The stream") throws {
        var at = 0
        while at + Self.packetSize <= bytes.count {
            guard bytes[at + 4] == 0x47 else { throw KroutonM2TSError.notM2TS(name) }
            packet(bytes, ts: at + 4)
            packetIndex &+= 1
            at += Self.packetSize
        }
    }

    /// The analysis, once every byte was fed in. Throws when the file isn't 192-byte packets or no
    /// H.264 key frame was found.
    public func finish(name: String = "The stream") throws -> KroutonM2TSAnalysis {
        guard result.videoPID != 0, minPTS != .max, !result.entryPoints.isEmpty else {
            throw KroutonM2TSError.noVideo(name)
        }
        var out = result
        out.sourcePackets = packetIndex
        out.firstPTS = minPTS
        out.endPTS = maxPTS + (frameDuration == .max ? 3_754 : frameDuration)
        return out
    }

    // MARK: - Packets

    private mutating func packet(_ b: [UInt8], ts: Int) {
        let pid = (UInt16(b[ts + 1] & 0x1F) << 8) | UInt16(b[ts + 2])
        let unitStart = b[ts + 1] & 0x40 != 0
        let control = (b[ts + 3] >> 4) & 0x3
        var payload = ts + 4
        var randomAccess = false
        if control & 0x2 != 0 {
            let length = Int(b[ts + 4])
            if length > 0 { randomAccess = b[ts + 5] & 0x40 != 0 }
            payload += 1 + length
        }
        let end = ts + 188
        guard control & 0x1 != 0, payload < end else { return }
        if pid == 0, unitStart {
            parsePAT(b, from: payload, to: end)
        } else if pid == result.programMapPID, unitStart {
            parsePMT(b, from: payload, to: end)
        } else if pid == result.videoPID, unitStart {
            video(b, from: payload, to: end, randomAccess: randomAccess)
        } else if pid == result.audioPID, unitStart, !sawAudioHeader {
            audio(b, from: payload, to: end)
        }
    }

    private mutating func parsePAT(_ b: [UInt8], from start: Int, to end: Int) {
        let at = start + 1 + Int(b[start]) // pointer field
        guard at + 12 <= end else { return }
        // Section header (8 bytes), then the first program: number (2) + PID (2).
        var entry = at + 8
        while entry + 4 <= end - 4 {
            let program = (UInt16(b[entry]) << 8) | UInt16(b[entry + 1])
            let pid = (UInt16(b[entry + 2] & 0x1F) << 8) | UInt16(b[entry + 3])
            if program != 0 {
                result.programMapPID = pid
                return
            }
            entry += 4
        }
    }

    private mutating func parsePMT(_ b: [UInt8], from start: Int, to end: Int) {
        let at = start + 1 + Int(b[start])
        guard at + 12 <= end else { return }
        let sectionLength = (Int(b[at + 1] & 0x0F) << 8) | Int(b[at + 2])
        let sectionEnd = min(end, at + 3 + sectionLength - 4) // without the CRC
        result.pcrPID = (UInt16(b[at + 8] & 0x1F) << 8) | UInt16(b[at + 9])
        let infoLength = (Int(b[at + 10] & 0x0F) << 8) | Int(b[at + 11])
        var entry = at + 12 + infoLength
        while entry + 5 <= sectionEnd {
            let type = b[entry]
            let pid = (UInt16(b[entry + 1] & 0x1F) << 8) | UInt16(b[entry + 2])
            let esInfo = (Int(b[entry + 3] & 0x0F) << 8) | Int(b[entry + 4])
            if [0x1B, 0x02, 0xEA, 0x24].contains(type), result.videoPID == 0 {
                result.videoPID = pid
                result.videoCoding = type
            } else if (0x80...0x86).contains(type) || type == 0xA1 || type == 0xA2, result.audioPID == nil {
                result.audioPID = pid
                result.audioCoding = type
            }
            entry += 5 + esInfo
        }
    }

    /// The PES header's PTS, and where its payload starts.
    private static func pesPTS(_ b: [UInt8], from start: Int, to end: Int) -> (UInt64, Int)? {
        guard start + 14 <= end, b[start] == 0, b[start + 1] == 0, b[start + 2] == 1, b[start + 7] & 0x80 != 0 else {
            return nil
        }
        let p = start + 9
        let pts = (UInt64(b[p] >> 1) & 0x7) << 30 | UInt64(b[p + 1]) << 22 | UInt64(b[p + 2] >> 1) << 15
            | UInt64(b[p + 3]) << 7 | UInt64(b[p + 4] >> 1)
        return (pts, start + 9 + Int(b[start + 8]))
    }

    private mutating func video(_ b: [UInt8], from start: Int, to end: Int, randomAccess: Bool) {
        guard let (pts, payload) = Self.pesPTS(b, from: start, to: end) else { return }
        minPTS = min(minPTS, pts)
        maxPTS = max(maxPTS, pts)
        if let last = lastPTS, pts != last {
            let gap = pts > last ? pts - last : last - pts
            frameDuration = min(frameDuration, gap)
        }
        lastPTS = pts
        if randomAccess || Self.startsWithIDR(b, from: payload, to: end) {
            result.entryPoints.append(.init(pts: pts, sourcePacket: packetIndex))
        }
    }

    /// Whether the access unit carries an IDR slice or a sequence parameter set early on.
    private static func startsWithIDR(_ b: [UInt8], from start: Int, to end: Int) -> Bool {
        var i = start
        while i + 3 < end {
            if b[i] == 0, b[i + 1] == 0, b[i + 2] == 1 {
                let type = b[i + 3] & 0x1F
                if type == 5 || type == 7 { return true }
                if type == 1 { return false }
                i += 3
            } else {
                i += 1
            }
        }
        return false
    }

    private mutating func audio(_ b: [UInt8], from start: Int, to end: Int) {
        guard let (_, payload) = Self.pesPTS(b, from: start, to: end) else { return }
        sawAudioHeader = true
        guard result.audioCoding == 0x81 else { return } // AC-3: read the channel mode
        var i = payload
        while i + 7 < end {
            if b[i] == 0x0B, b[i + 1] == 0x77 {
                let acmod = b[i + 6] >> 5
                result.audioPresentation = acmod == 1 ? 1 : (acmod >= 3 ? 6 : 3)
                return
            }
            i += 1
        }
    }
}
