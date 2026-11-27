import Foundation

// MARK: - BDMV Navigation Files

/// A video format Blu-ray players accept, with the codes `index.bdmv`, playlists and clip
/// files record. 25 and 29.97 frames a second are only allowed as 1080i, so progressive
/// material at those rates is encoded "fake interlaced" (progressive frames, interlaced flags).
public struct KroutonBDMVVideoFormat: Sendable, Equatable {
    public let width: Int
    public let height: Int
    public let interlaced: Bool
    /// Frames a second, as ffmpeg's `fps` filter takes it.
    public let ffmpegRate: String
    public let framesPerSecond: Double
    /// Blu-ray frame-rate code: 1 23.976, 2 24, 3 25, 4 29.97, 6 50, 7 59.94.
    public let rateCode: UInt8

    /// Blu-ray video-format code: 4 1080i, 5 720p, 6 1080p.
    public var formatCode: UInt8 { height == 1080 ? (interlaced ? 4 : 6) : 5 }

    public static let film = Self(width: 1920, height: 1080, interlaced: false, ffmpegRate: "24000/1001", framesPerSecond: 23.976, rateCode: 1)
    public static let cinema = Self(width: 1920, height: 1080, interlaced: false, ffmpegRate: "24", framesPerSecond: 24, rateCode: 2)
    public static let pal = Self(width: 1920, height: 1080, interlaced: true, ffmpegRate: "25", framesPerSecond: 25, rateCode: 3)
    public static let ntsc = Self(width: 1920, height: 1080, interlaced: true, ffmpegRate: "30000/1001", framesPerSecond: 29.97, rateCode: 4)
    public static let hd50 = Self(width: 1280, height: 720, interlaced: false, ffmpegRate: "50", framesPerSecond: 50, rateCode: 6)
    public static let hd60 = Self(width: 1280, height: 720, interlaced: false, ffmpegRate: "60000/1001", framesPerSecond: 59.94, rateCode: 7)

    /// The legal format closest to a source's frame rate (30 becomes 29.97, 60 becomes 59.94).
    public static func nearest(framesPerSecond fps: Double) -> Self {
        let all = [film, cinema, pal, ntsc, hd50, hd60]
        guard fps > 0 else { return film }
        return all.min { abs($0.framesPerSecond - fps) < abs($1.framesPerSecond - fps) } ?? film
    }
}

/// One clip on the disc: `STREAM/<name>.m2ts` and `CLIPINF/<name>.clpi`.
public struct KroutonBDMVClip: Sendable, Equatable {
    public let name: String
    public let analysis: KroutonM2TSAnalysis
    public let format: KroutonBDMVVideoFormat
    /// Highest transport-stream rate, bytes a second.
    public let recordingRate: UInt32

    public init(name: String, analysis: KroutonM2TSAnalysis, format: KroutonBDMVVideoFormat, recordingRate: UInt32) {
        self.name = name
        self.analysis = analysis
        self.format = format
        self.recordingRate = recordingRate
    }

    /// 45 kHz, as playlists and clip files count time.
    var inTime: UInt32 { UInt32(truncatingIfNeeded: analysis.firstPTS / 2) }
    var outTime: UInt32 { UInt32(truncatingIfNeeded: analysis.endPTS / 2) }
}

/// Writes `index.bdmv`, `MovieObject.bdmv`, `PLAYLIST/00000.mpls` and `CLIPINF/*.clpi` as the
/// BD-ROM specification (version 0200) lays them out: one title that plays every clip in
/// order, with a chapter at each clip and every five minutes within one.
public enum KroutonBDMVWriter {
    static let version = "0200"

    // MARK: - index.bdmv

    public static func index(format: KroutonBDMVVideoFormat) -> Data {
        var w = KroutonBEWriter()
        w.ascii("INDX" + version)
        w.u32(78) // indexes start: 40 + AppInfoBDMV (4 + 34)
        w.u32(0)
        w.zeros(24)
        w.u32(34)
        w.u8(0) // 2D output, no 3D content
        w.u8(format.formatCode << 4 | format.rateCode)
        w.zeros(32)
        // Indexes: First Playback, Top Menu and title 1 all run movie object 0.
        w.u32(12 + 12 + 2 + 12)
        for _ in 0..<2 {
            w.u32(1 << 30) // HDMV object
            w.u16(0) // movie playback
            w.u16(0) // movie object 0
            w.u32(0)
        }
        w.u16(1)
        w.u32(1 << 30)
        w.u16(0)
        w.u16(0)
        w.u32(0)
        return w.data
    }

    // MARK: - MovieObject.bdmv

    /// Movie object 0: `PlayPL 0`.
    public static func movieObject() -> Data {
        var w = KroutonBEWriter()
        w.ascii("MOBJ" + version)
        w.u32(0)
        w.zeros(28)
        w.u32(4 + 2 + 4 + 12)
        w.u32(0)
        w.u16(1)
        w.u16(0x8000) // resume intention; menu call and title search allowed
        w.u16(1)
        // PlayPL with an immediate operand: operand count 1, branch group, play sub-group.
        w.u32(0x2280_0000)
        w.u32(0) // playlist 00000
        w.u32(0)
        return w.data
    }

    // MARK: - PLAYLIST/00000.mpls

    public static func playlist(clips: [KroutonBDMVClip], chapterEvery seconds: Double = 300) -> Data {
        var items = KroutonBEWriter()
        for clip in clips {
            var item = KroutonBEWriter()
            item.ascii(clip.name)
            item.ascii("M2TS")
            item.u16(1) // not multi-angle; connection condition 1 (not seamless)
            item.u8(0)
            item.u32(clip.inTime)
            item.u32(clip.outTime)
            item.zeros(8) // user-operation mask
            item.u8(0)
            item.u8(0) // no still
            item.u16(0)
            item.put(streamTable(clip))
            items.u16(UInt16(item.count))
            items.put(item.bytes)
        }
        var marks: [(item: UInt16, time: UInt32)] = []
        for (index, clip) in clips.enumerated() {
            for time in chapterTimes(clip, every: seconds) {
                marks.append((UInt16(index), time))
            }
        }
        var w = KroutonBEWriter()
        w.ascii("MPLS" + version)
        let listStart = 58
        let listLength = 4 + 6 + items.count
        w.u32(UInt32(listStart))
        w.u32(UInt32(listStart + listLength))
        w.u32(0)
        w.zeros(20)
        w.u32(14) // AppInfoPlayList
        w.u8(0)
        w.u8(1) // sequential playback
        w.u16(0)
        w.zeros(8)
        w.u16(0)
        w.u32(UInt32(6 + items.count))
        w.u16(0)
        w.u16(UInt16(clips.count))
        w.u16(0) // sub-paths
        w.put(items.bytes)
        w.u32(UInt32(2 + 14 * marks.count))
        w.u16(UInt16(marks.count))
        for mark in marks {
            w.u8(0)
            w.u8(1) // entry mark: a chapter
            w.u16(mark.item)
            w.u32(mark.time)
            w.u16(0xFFFF)
            w.u32(0)
        }
        return w.data
    }

    /// The clip's start, then the key frame nearest every `seconds` after it.
    static func chapterTimes(_ clip: KroutonBDMVClip, every seconds: Double) -> [UInt32] {
        var times = [clip.inTime]
        let step = UInt64(seconds * 90_000)
        guard step > 0 else { return times }
        var target = clip.analysis.firstPTS + step
        let points = clip.analysis.entryPoints.map(\.pts)
        while target + step / 4 < clip.analysis.endPTS {
            if let nearest = points.min(by: { $0.distance(to: target).magnitude < $1.distance(to: target).magnitude }) {
                let time = UInt32(truncatingIfNeeded: nearest / 2)
                if time > times.last ?? 0 { times.append(time) }
            }
            target += step
        }
        return times
    }

    private static func streamTable(_ clip: KroutonBDMVClip) -> [UInt8] {
        let a = clip.analysis
        var w = KroutonBEWriter()
        w.u16(0)
        w.u8(1) // primary video
        w.u8(a.audioPID == nil ? 0 : 1)
        w.zeros(5) // PG, IG, secondary audio, secondary video, PiP PG
        w.zeros(5)
        w.put(streamEntry(pid: a.videoPID))
        w.u8(5)
        w.u8(a.videoCoding)
        w.u8(clip.format.formatCode << 4 | clip.format.rateCode)
        w.zeros(3)
        if let audio = a.audioPID {
            w.put(streamEntry(pid: audio))
            w.u8(5)
            w.u8(a.audioCoding)
            w.u8(a.audioPresentation << 4 | 1) // 48 kHz
            w.ascii("und")
        }
        var out = KroutonBEWriter()
        out.u16(UInt16(w.count))
        out.put(w.bytes)
        return out.bytes
    }

    private static func streamEntry(pid: UInt16) -> [UInt8] {
        var w = KroutonBEWriter()
        w.u8(9)
        w.u8(1) // a stream of the play item's own clip
        w.u16(pid)
        w.zeros(6)
        return w.bytes
    }

    // MARK: - CLIPINF/*.clpi

    public static func clipInfo(_ clip: KroutonBDMVClip) -> Data {
        let a = clip.analysis
        var info = KroutonBEWriter()
        info.u16(0)
        info.u8(1) // AV stream
        info.u8(1) // main TS of a movie
        info.u32(0) // no ATC delta
        info.u32(clip.recordingRate)
        info.u32(a.sourcePackets)
        info.zeros(128)
        info.u16(30) // TS type info
        info.u8(0x80)
        info.ascii("HDMV")
        info.zeros(25)

        var sequence = KroutonBEWriter()
        sequence.u8(0)
        sequence.u8(1) // one ATC sequence
        sequence.u32(0)
        sequence.u8(1) // one STC sequence
        sequence.u8(0)
        sequence.u16(a.pcrPID == 0 ? a.videoPID : a.pcrPID)
        sequence.u32(0)
        sequence.u32(clip.inTime)
        sequence.u32(clip.outTime)

        var program = KroutonBEWriter()
        program.u8(0)
        program.u8(1)
        program.u32(0)
        program.u16(a.programMapPID)
        program.u8(a.audioPID == nil ? 1 : 2)
        program.u8(0)
        program.u16(a.videoPID)
        var videoAttr = [UInt8](repeating: 0, count: 21)
        videoAttr[0] = a.videoCoding
        videoAttr[1] = clip.format.formatCode << 4 | clip.format.rateCode
        videoAttr[2] = 3 << 4 // 16:9
        program.u8(21)
        program.put(videoAttr)
        if let audio = a.audioPID {
            program.u16(audio)
            var audioAttr = [UInt8](repeating: 0, count: 21)
            audioAttr[0] = a.audioCoding
            audioAttr[1] = a.audioPresentation << 4 | 1
            audioAttr.replaceSubrange(2..<5, with: Array("und".utf8))
            program.u8(21)
            program.put(audioAttr)
        }

        let epMap = entryPointMap(pid: a.videoPID, points: a.entryPoints)
        let sequenceStart = 40 + 4 + info.count
        let programStart = sequenceStart + 4 + sequence.count
        let cpiStart = programStart + 4 + program.count
        let markStart = cpiStart + 4 + 2 + epMap.count
        var w = KroutonBEWriter()
        w.ascii("HDMV" + version)
        w.u32(UInt32(sequenceStart))
        w.u32(UInt32(programStart))
        w.u32(UInt32(cpiStart))
        w.u32(UInt32(markStart))
        w.u32(0)
        w.zeros(12)
        for block in [info, sequence, program] {
            w.u32(UInt32(block.count))
            w.put(block.bytes)
        }
        w.u32(UInt32(2 + epMap.count))
        w.u16(1) // CPI type 1: EP map
        w.put(epMap)
        w.u32(0) // no clip marks
        return w.data
    }

    /// The EP map for one video stream: coarse entries (PTS bits 32–19, full SPN) each pointing
    /// at the first of their fine entries (PTS bits 19–9, SPN bits 16–0).
    static func entryPointMap(pid: UInt16, points: [KroutonM2TSAnalysis.EntryPoint]) -> [UInt8] {
        var coarse: [(fine: UInt32, pts: UInt32, spn: UInt32)] = []
        var lastKey: (UInt64, UInt32)?
        for (i, point) in points.enumerated() {
            let key = (point.pts >> 19, point.sourcePacket >> 17)
            if lastKey.map({ $0 != key }) ?? true {
                coarse.append((UInt32(i), UInt32(truncatingIfNeeded: point.pts >> 19) & 0x3FFF, point.sourcePacket))
                lastKey = key
            }
        }
        var w = KroutonBEWriter()
        w.u8(0)
        w.u8(1) // one stream
        w.u16(pid)
        // reserved 10 bits, stream type 4 (video), coarse count 16, fine count 18
        w.bits(0, 10)
        w.bits(1, 4)
        w.bits(UInt64(coarse.count), 16)
        w.bits(UInt64(points.count), 18)
        w.u32(14) // this stream's map starts right after the header
        w.u32(UInt32(4 + 8 * coarse.count))
        for c in coarse {
            w.bits(UInt64(c.fine), 18)
            w.bits(UInt64(c.pts), 14)
            w.u32(c.spn)
        }
        for point in points {
            w.bits(0, 1)
            w.bits(1, 3) // the I picture ends within the first 131,072 bytes
            w.bits((point.pts >> 9) & 0x7FF, 11)
            w.bits(UInt64(point.sourcePacket & 0x1_FFFF), 17)
        }
        return w.bytes
    }
}

// MARK: - Big-Endian Writer

/// Big-endian bytes and bit fields, MSB first.
struct KroutonBEWriter {
    private(set) var bytes: [UInt8] = []
    private var accumulator: UInt64 = 0
    private var pending = 0

    var count: Int { bytes.count }
    var data: Data { Data(bytes) }

    mutating func u8(_ v: UInt8) { bytes.append(v) }
    mutating func u16(_ v: UInt16) { bytes += [UInt8(v >> 8), UInt8(v & 0xFF)] }
    mutating func u32(_ v: UInt32) { bytes += [UInt8(v >> 24), UInt8(v >> 16 & 0xFF), UInt8(v >> 8 & 0xFF), UInt8(v & 0xFF)] }
    mutating func zeros(_ n: Int) { bytes += [UInt8](repeating: 0, count: n) }
    mutating func ascii(_ s: String) { bytes += Array(s.utf8) }
    mutating func put(_ b: [UInt8]) { bytes += b }

    /// Appends the low `count` bits of `value`; whole bytes are flushed as they fill.
    mutating func bits(_ value: UInt64, _ count: Int) {
        for shift in stride(from: count - 1, through: 0, by: -1) {
            accumulator = accumulator << 1 | (value >> UInt64(shift) & 1)
            pending += 1
            if pending == 8 {
                bytes.append(UInt8(accumulator & 0xFF))
                accumulator = 0
                pending = 0
            }
        }
    }
}
