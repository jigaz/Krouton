import Foundation

// MARK: - AVCHD / BD-on-DVD (18 Mbps H.264 .m2ts + BDMV / CERTIFICATE Binary Authoring Engine)

public struct AVCHDClipDescriptor: Sendable, Equatable {
    public let clipIndex: Int              // 0 -> "00000", 1 -> "00001"
    public let durationSeconds: Double
    public let m2tsByteSize: Int64
    public let videoBitrateKbps: Int
    public let is1080p: Bool

    var clipName5Chars: String {
        String(format: "%05d", max(0, min(99_999, clipIndex)))
    }

    var sourcePacketCount192B: UInt32 {
        UInt32(max(1, m2tsByteSize / 192))
    }

    public init(
        clipIndex: Int,
        durationSeconds: Double,
        m2tsByteSize: Int64,
        videoBitrateKbps: Int = 16_000,
        is1080p: Bool = true
    ) {
        self.clipIndex = clipIndex
        self.durationSeconds = max(1.0, durationSeconds)
        self.m2tsByteSize = max(192, m2tsByteSize)
        self.videoBitrateKbps = max(2_000, min(18_000, videoBitrateKbps))
        self.is1080p = is1080p
    }
}

public struct AVCHDDiscStructureOutput: Sendable, Equatable {
    let rootDirectory: URL
    let bdmvDirectory: URL
    let certificateDirectory: URL
    public let clips: [AVCHDClipDescriptor]
    let totalM2TSBytes: Int64
}

public enum AVCHDOnDVDAuthoringEngine {
    /// Red-laser DVD-R / DVD+R maximum safe AVCHD bitrate (18,000 kbps = 18 Mbps)
    static let maxAVCHDOnDVDBitrateKbps: Int = 18_000
    /// Standard Blu-ray / AVCHD 45 kHz presentation timestamp clock
    static let clock45kHz: Double = 45_000.0
    static let defaultInTime45kHz: UInt32 = 9_000 // 0.200 s

    // MARK: - Binary BDMV Generators (INDX0100, MOBJ0100, MPLS0100, HDMV0100)

    /// Synthesizes a spec-compliant `index.bdmv` (`INDX0100` for AVCHD / BD-on-DVD, `INDX0200` for BD-ROM)
    /// that launches `MovieObject #0` on disc insert (`FirstPlayback`) and Top Menu press.
    public static func buildIndexBDMV(isAVCHD: Bool = true, is1080p: Bool = true) -> Data {
        var out: [UInt8] = []
        out.append(contentsOf: Array("INDX".utf8))
        out.append(contentsOf: Array((isAVCHD ? "0100" : "0200").utf8))
        // indexes_start_address = 0x0000004E (78), extension_data_start_address = 0
        appendUInt32BE(0x0000_004E, to: &out)
        appendUInt32BE(0, to: &out)
        // 24 reserved bytes (0x10..0x27)
        out.append(contentsOf: repeatElement(0, count: 24))

        // AppInfoBDMV (38 bytes: length=34 + 34 payload bytes)
        appendUInt32BE(34, to: &out)
        out.append(0x00) // reserved
        out.append(0x00) // initial_output_mode_preference = 2D
        out.append(is1080p ? 0x41 : 0x61) // video_format (4=1080p, 6=1080i) + frame_rate (1=23.976p)
        out.append(contentsOf: repeatElement(0, count: 31))

        // Indexes table at 0x4E:
        // FirstPlayback (12B) + TopMenu (12B) + number_of_Titles (2B) + 1 Title entry (12B) = 38 bytes
        appendUInt32BE(38, to: &out)
        // FirstPlayback: object_type=1 (HDMV), playback_type=0 (Movie), id_ref=0
        appendUInt16BE(0x4000, to: &out)
        appendUInt16BE(0x0000, to: &out)
        appendUInt16BE(0x0000, to: &out)
        out.append(contentsOf: repeatElement(0, count: 6))
        // TopMenu: object_type=1 (HDMV), playback_type=0 (Movie), id_ref=0
        appendUInt16BE(0x4000, to: &out)
        appendUInt16BE(0x0000, to: &out)
        appendUInt16BE(0x0000, to: &out)
        out.append(contentsOf: repeatElement(0, count: 6))
        // number_of_Titles = 1
        appendUInt16BE(1, to: &out)
        // Title #1: object_type=1 (HDMV), access_type=0, playback_type=0, id_ref=0
        appendUInt16BE(0x4000, to: &out)
        appendUInt16BE(0x0000, to: &out)
        appendUInt16BE(0x0000, to: &out)
        out.append(contentsOf: repeatElement(0, count: 6))

        return Data(out)
    }

    /// Synthesizes `MovieObject.bdmv` (`MOBJ0100` / `MOBJ0200`) with `MovieObject #0` executing:
    /// 1. `PlayPL 0` (`00000.mpls`)
    /// 2. `JumpTitle 1` (clean return/loop on completion)
    public static func buildMovieObjectBDMV(isAVCHD: Bool = true) -> Data {
        var out: [UInt8] = []
        out.append(contentsOf: Array("MOBJ".utf8))
        out.append(contentsOf: Array((isAVCHD ? "0100" : "0200").utf8))
        appendUInt32BE(0, to: &out) // extension_data_start_address
        out.append(contentsOf: repeatElement(0, count: 28)) // 0x0C..0x27 reserved

        // MovieObjects section at 0x28:
        // reserved(4) + number_of_mobjs(2) + mobj_0 header(4) + 2 commands * 12B = 34 bytes
        appendUInt32BE(34, to: &out)
        appendUInt32BE(0, to: &out)
        appendUInt16BE(1, to: &out) // number_of_mobjs = 1
        // MovieObject #0 flags (resume_intention=1, menu_call_mask=0, title_search_mask=0) + num_nav_cmds = 2
        appendUInt16BE(0x8000, to: &out)
        appendUInt16BE(2, to: &out)

        // Nav Command 0: PlayPL 0 (opcode 0x22000000, dst=0, src=0)
        appendUInt32BE(0x2200_0000, to: &out)
        appendUInt32BE(0x0000_0000, to: &out)
        appendUInt32BE(0x0000_0000, to: &out)

        // Nav Command 1: JumpTitle 1 (opcode 0x21810000, dst=1, src=0)
        appendUInt32BE(0x2181_0000, to: &out)
        appendUInt32BE(0x0000_0001, to: &out)
        appendUInt32BE(0x0000_0000, to: &out)

        return Data(out)
    }

    /// Synthesizes `PLAYLIST/00000.mpls` (`MPLS0100` / `MPLS0200`) referencing all sequential `.m2ts` clips
    /// with 45 kHz IN/OUT timestamps, H.264 (`0x1B`) + AC-3 (`0x81`) STN tables, and chapter marks.
    public static func buildPlaylistMPLS(clips: [AVCHDClipDescriptor], isAVCHD: Bool = true) -> Data {
        let activeClips = clips.isEmpty ? [AVCHDClipDescriptor(clipIndex: 0, durationSeconds: 10.0, m2tsByteSize: 192 * 100)] : clips

        // Build PlayItems payload first so we know exact PlayListMark_start_address
        var playItemsBytes: [UInt8] = []
        for (idx, clip) in activeClips.enumerated() {
            var item: [UInt8] = []
            item.append(contentsOf: Array(clip.clipName5Chars.utf8)) // 5B clip_information_file_name
            item.append(contentsOf: Array("M2TS".utf8))              // 4B clip_codec_identifier
            // reserved(11b) + is_multi_angle(1b=0) + connection_condition(4b: 0 for first, 1=seamless for subsequent)
            let connCond: UInt16 = (idx == 0) ? 0x0000 : 0x0001
            appendUInt16BE(connCond, to: &item)
            item.append(0x00) // ref_to_STC_id = 0
            let inTime = defaultInTime45kHz
            let durTicks = UInt32(max(45_000.0, clip.durationSeconds * clock45kHz))
            let outTime = inTime &+ durTicks
            appendUInt32BE(inTime, to: &item)
            appendUInt32BE(outTime, to: &item)
            // UO_mask_table (8B) + PlayItem_random_access_flag(1B) + still_mode(1B) + still_time(2B)
            item.append(contentsOf: repeatElement(0, count: 12))

            // STN_table: 1 Primary Video (PID 0x1011, H.264 0x1B) + 1 Primary Audio (PID 0x1100, AC-3 0x81)
            var stn: [UInt8] = []
            appendUInt16BE(0, to: &stn) // reserved
            stn.append(1) // num_video = 1
            stn.append(1) // num_audio = 1
            stn.append(0) // num_pg = 0
            stn.append(0) // num_ig = 0
            stn.append(0) // num_secondary_audio = 0
            stn.append(0) // num_secondary_video = 0
            stn.append(0) // num_pip_pg = 0
            stn.append(contentsOf: repeatElement(0, count: 5))

            // Video stream entry (9B) + attributes (5B)
            stn.append(9); stn.append(0x01); appendUInt16BE(0x1011, to: &stn)
            stn.append(contentsOf: repeatElement(0, count: 6))
            stn.append(5); stn.append(0x1B); stn.append(clip.is1080p ? 0x41 : 0x61)
            stn.append(contentsOf: repeatElement(0, count: 3))

            // Audio stream entry (9B) + attributes (5B)
            stn.append(9); stn.append(0x01); appendUInt16BE(0x1100, to: &stn)
            stn.append(contentsOf: repeatElement(0, count: 6))
            stn.append(5); stn.append(0x81); stn.append(0x31) // AC-3, Multi-channel, 48 kHz
            stn.append(contentsOf: Array("eng".utf8))

            appendUInt16BE(UInt16(stn.count), to: &item)
            item.append(contentsOf: stn)

            appendUInt16BE(UInt16(item.count), to: &playItemsBytes)
            playItemsBytes.append(contentsOf: item)
        }

        // PlayList section (starts at 0x3A = 58)
        var playListSection: [UInt8] = []
        let playListBodyLen = UInt32(6 + playItemsBytes.count)
        appendUInt32BE(playListBodyLen, to: &playListSection)
        appendUInt16BE(0, to: &playListSection) // reserved
        appendUInt16BE(UInt16(activeClips.count), to: &playListSection) // number_of_PlayItems
        appendUInt16BE(0, to: &playListSection) // number_of_SubPaths
        playListSection.append(contentsOf: playItemsBytes)

        let playListStartAddress: UInt32 = 0x0000_003A
        let playListMarkStartAddress: UInt32 = playListStartAddress + UInt32(playListSection.count)

        // PlayListMark section: 1 Entry-Mark (chapter) at the start of each PlayItem
        var markSection: [UInt8] = []
        let markBodyLen = UInt32(2 + activeClips.count * 14)
        appendUInt32BE(markBodyLen, to: &markSection)
        appendUInt16BE(UInt16(activeClips.count), to: &markSection)
        for idx in activeClips.indices {
            markSection.append(0x00) // reserved
            markSection.append(0x01) // mark_type = Entry-mark (chapter)
            appendUInt16BE(UInt16(idx), to: &markSection) // ref_to_PlayItem_id
            appendUInt32BE(defaultInTime45kHz, to: &markSection) // mark_time_stamp
            appendUInt16BE(0xFFFF, to: &markSection) // entry_ES_PID
            appendUInt32BE(0, to: &markSection) // duration
        }

        var out: [UInt8] = []
        out.append(contentsOf: Array("MPLS".utf8))
        out.append(contentsOf: Array((isAVCHD ? "0100" : "0200").utf8))
        appendUInt32BE(playListStartAddress, to: &out)
        appendUInt32BE(playListMarkStartAddress, to: &out)
        appendUInt32BE(0, to: &out) // extension_data_start_address
        out.append(contentsOf: repeatElement(0, count: 20)) // 0x14..0x27 reserved

        // AppInfoPlayList (18 bytes at 0x28..0x39)
        appendUInt32BE(14, to: &out)
        out.append(0x00) // reserved
        out.append(0x00) // playback_type = Sequential
        appendUInt16BE(0, to: &out)
        appendUInt32BE(0, to: &out)
        appendUInt16BE(0, to: &out)
        appendUInt32BE(0, to: &out)

        out.append(contentsOf: playListSection)
        out.append(contentsOf: markSection)
        return Data(out)
    }

    /// Synthesizes `CLIPINF/00000.clpi` (`HDMV0100` / `HDMV0200`) matching the 192-byte packet count
    /// and 45 kHz duration of `STREAM/00000.m2ts`.
    public static func buildClipInfoCLPI(clip: AVCHDClipDescriptor, isAVCHD: Bool = true) -> Data {
        let inTime = defaultInTime45kHz
        let durTicks = UInt32(max(45_000.0, clip.durationSeconds * clock45kHz))
        let outTime = inTime &+ durTicks
        let tsRecordingRate = UInt32((clip.videoBitrateKbps + 448) * 1000 / 8)

        // ClipInfo block (starts at 0x28 = 40, total 48 bytes -> ends at 0x58 = 88)
        var clipInfo: [UInt8] = []
        appendUInt32BE(44, to: &clipInfo) // length
        appendUInt16BE(0, to: &clipInfo)
        clipInfo.append(0x01) // clip_stream_type = 1 (AV stream)
        clipInfo.append(0x01) // application_type = 1 (Movie)
        appendUInt32BE(0, to: &clipInfo) // is_ATC_delta = 0
        appendUInt32BE(tsRecordingRate, to: &clipInfo)
        appendUInt32BE(clip.sourcePacketCount192B, to: &clipInfo)
        clipInfo.append(contentsOf: repeatElement(0, count: 28))

        // SequenceInfo block (at 0x58 = 88, total 36 bytes -> ends at 0x7C = 124)
        var seqInfo: [UInt8] = []
        appendUInt32BE(32, to: &seqInfo)
        seqInfo.append(0x00)
        seqInfo.append(0x01) // num_ATC_sequences = 1
        appendUInt32BE(0, to: &seqInfo) // SPN_ATC_start = 0
        seqInfo.append(0x01) // num_STC_sequences = 1
        seqInfo.append(0x00) // offset_STC_id = 0
        appendUInt16BE(0x1001, to: &seqInfo) // PCR_PID
        appendUInt32BE(0, to: &seqInfo) // SPN_STC_start = 0
        appendUInt32BE(inTime, to: &seqInfo) // presentation_start_time
        appendUInt32BE(outTime, to: &seqInfo) // presentation_end_time
        seqInfo.append(contentsOf: repeatElement(0, count: 10))

        // ProgramInfo block (at 0x7C = 124, total 36 bytes -> ends at 0xA0 = 160)
        var progInfo: [UInt8] = []
        appendUInt32BE(32, to: &progInfo)
        progInfo.append(0x00)
        progInfo.append(0x01) // num_program_sequences = 1
        appendUInt32BE(0, to: &progInfo) // SPN_program_sequence_start = 0
        appendUInt16BE(0x0100, to: &progInfo) // program_map_PID
        progInfo.append(0x02) // num_streams_in_ps = 2 (Video + Audio)
        progInfo.append(0x00)
        // Video stream PID 0x1011 (H.264 0x1B)
        appendUInt16BE(0x1011, to: &progInfo)
        progInfo.append(0x09); progInfo.append(0x1B); progInfo.append(clip.is1080p ? 0x41 : 0x61)
        progInfo.append(contentsOf: repeatElement(0, count: 7))
        // Audio stream PID 0x1100 (AC-3 0x81)
        appendUInt16BE(0x1100, to: &progInfo)
        progInfo.append(0x09); progInfo.append(0x81); progInfo.append(0x31)
        progInfo.append(contentsOf: Array("eng".utf8))
        progInfo.append(contentsOf: repeatElement(0, count: 4))

        // CPI block (at 0xA0 = 160, minimal 8B) + ClipMark block (at 0xA8 = 168, minimal 8B)
        var cpiBlock: [UInt8] = []
        appendUInt32BE(4, to: &cpiBlock); appendUInt32BE(0, to: &cpiBlock)
        var clipMarkBlock: [UInt8] = []
        appendUInt32BE(4, to: &clipMarkBlock); appendUInt32BE(0, to: &clipMarkBlock)

        var out: [UInt8] = []
        out.append(contentsOf: Array("HDMV".utf8))
        out.append(contentsOf: Array((isAVCHD ? "0100" : "0200").utf8))
        appendUInt32BE(0x0000_0058, to: &out) // SequenceInfo_start_address
        appendUInt32BE(0x0000_007C, to: &out) // ProgramInfo_start_address
        appendUInt32BE(0x0000_00A0, to: &out) // CPI_start_address
        appendUInt32BE(0x0000_00A8, to: &out) // ClipMark_start_address
        appendUInt32BE(0, to: &out)           // extension_data_start_address
        out.append(contentsOf: repeatElement(0, count: 12)) // 0x1C..0x27 reserved

        out.append(contentsOf: clipInfo)
        out.append(contentsOf: seqInfo)
        out.append(contentsOf: progInfo)
        out.append(contentsOf: cpiBlock)
        out.append(contentsOf: clipMarkBlock)
        return Data(out)
    }

    // MARK: - End-to-End AVCHD-on-DVD (18 Mbps H.264 .m2ts + BDMV Tree) Builder

    /// Transcodes staged video files into 18 Mbps (or custom capped) H.264 + AC-3 192-byte `.m2ts`
    /// streams and generates the complete `BDMV` + `CERTIFICATE` directory tree for DVD-5 / DVD-9 burning.
    static func authorAVCHDOnDVDTree(
        sourceVideoFiles: [URL],
        outputRootDirectory: URL,
        maxVideoBitrateKbps: Int = maxAVCHDOnDVDBitrateKbps,
        is1080p: Bool = true
    ) throws -> AVCHDDiscStructureOutput {
        let fm = FileManager.default
        let bdmvDir = outputRootDirectory.appendingPathComponent("BDMV")
        let backupDir = bdmvDir.appendingPathComponent("BACKUP")
        let playlistDir = bdmvDir.appendingPathComponent("PLAYLIST")
        let backupPlaylistDir = backupDir.appendingPathComponent("PLAYLIST")
        let clipinfDir = bdmvDir.appendingPathComponent("CLIPINF")
        let backupClipinfDir = backupDir.appendingPathComponent("CLIPINF")
        let streamDir = bdmvDir.appendingPathComponent("STREAM")
        let certDir = outputRootDirectory.appendingPathComponent("CERTIFICATE")
        let certBackupDir = certDir.appendingPathComponent("BACKUP")

        for dir in [
            bdmvDir, backupDir, playlistDir, backupPlaylistDir,
            clipinfDir, backupClipinfDir, streamDir,
            bdmvDir.appendingPathComponent("AUXDATA"),
            bdmvDir.appendingPathComponent("BDJO"),
            bdmvDir.appendingPathComponent("JAR"),
            bdmvDir.appendingPathComponent("META"),
            certDir, certBackupDir
        ] {
            try fm.createDirectory(at: dir, withIntermediateDirectories: true)
        }

        let clampedKbps = max(2_000, min(maxAVCHDOnDVDBitrateKbps, maxVideoBitrateKbps))
        let ffmpegURL = DVDVideoIFORelinker.locateFFmpegExecutable()
        var builtClips: [AVCHDClipDescriptor] = []
        var totalStreamBytes: Int64 = 0

        for (idx, srcURL) in sourceVideoFiles.enumerated() {
            let clipName = String(format: "%05d", idx)
            let destM2TS = streamDir.appendingPathComponent("\(clipName).m2ts")
            let srcSize = Int64((try? srcURL.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 192)
            let estDuration = max(2.0, Double(srcSize) / (Double(clampedKbps) * 1000.0 / 8.0))

            if let ffmpegURL {
                let proc = Process()
                proc.executableURL = ffmpegURL
                proc.arguments = [
                    "-y",
                    "-hide_banner",
                    "-loglevel", "error",
                    "-i", srcURL.path,
                    "-map", "0:v:0",
                    "-map", "0:a:0?",
                    "-c:v", "libx264",
                    "-profile:v", "high",
                    "-level:v", "4.1",
                    "-b:v", "\(clampedKbps)k",
                    "-maxrate", "\(clampedKbps)k",
                    "-bufsize", "\(clampedKbps)k",
                    "-g", "24",
                    "-keyint_min", "24",
                    "-pix_fmt", "yuv420p",
                    "-c:a", "ac3",
                    "-b:a", "448k",
                    "-ar", "48000",
                    "-mpegts_m2ts_mode", "1",
                    "-f", "mpegts",
                    destM2TS.path
                ]
                try proc.run()
                proc.waitUntilExit()
                guard proc.terminationStatus == 0 else {
                    throw KroutonVideoShrinkError.transcodeFailed(exitCode: proc.terminationStatus)
                }
            } else {
                // Fallback passthrough copy if input is already .m2ts and ffmpeg is not installed
                try fm.copyItem(at: srcURL, to: destM2TS)
            }

            let outBytes = Int64((try? destM2TS.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? Int(srcSize))
            totalStreamBytes += outBytes
            let clipDesc = AVCHDClipDescriptor(
                clipIndex: idx,
                durationSeconds: estDuration,
                m2tsByteSize: outBytes,
                videoBitrateKbps: clampedKbps,
                is1080p: is1080p
            )
            builtClips.append(clipDesc)

            let clpiData = buildClipInfoCLPI(clip: clipDesc, isAVCHD: true)
            try clpiData.write(to: clipinfDir.appendingPathComponent("\(clipName).clpi"))
            try clpiData.write(to: backupClipinfDir.appendingPathComponent("\(clipName).clpi"))
        }

        let indexData = buildIndexBDMV(isAVCHD: true, is1080p: is1080p)
        let mobjData = buildMovieObjectBDMV(isAVCHD: true)
        let mplsData = buildPlaylistMPLS(clips: builtClips, isAVCHD: true)

        try indexData.write(to: bdmvDir.appendingPathComponent("index.bdmv"))
        try indexData.write(to: backupDir.appendingPathComponent("index.bdmv"))
        try mobjData.write(to: bdmvDir.appendingPathComponent("MovieObject.bdmv"))
        try mobjData.write(to: backupDir.appendingPathComponent("MovieObject.bdmv"))
        try mplsData.write(to: playlistDir.appendingPathComponent("00000.mpls"))
        try mplsData.write(to: backupPlaylistDir.appendingPathComponent("00000.mpls"))

        return AVCHDDiscStructureOutput(
            rootDirectory: outputRootDirectory,
            bdmvDirectory: bdmvDir,
            certificateDirectory: certDir,
            clips: builtClips,
            totalM2TSBytes: totalStreamBytes
        )
    }

    // MARK: - Private Big-Endian Appenders

    private static func appendUInt16BE(_ v: UInt16, to buf: inout [UInt8]) {
        buf.append(UInt8((v >> 8) & 0xFF))
        buf.append(UInt8(v & 0xFF))
    }

    private static func appendUInt32BE(_ v: UInt32, to buf: inout [UInt8]) {
        buf.append(UInt8((v >> 24) & 0xFF))
        buf.append(UInt8((v >> 16) & 0xFF))
        buf.append(UInt8((v >> 8) & 0xFF))
        buf.append(UInt8(v & 0xFF))
    }
}
