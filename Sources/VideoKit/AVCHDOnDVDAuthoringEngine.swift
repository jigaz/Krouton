import Foundation

// MARK: - AVCHD / BD-on-DVD Authoring

/// A finished `BDMV` + `CERTIFICATE` folder, ready to be put on a UDF 2.50 disc.
public struct KroutonAVCHDDisc: Sendable, Equatable {
    /// The folder holding `BDMV` and `CERTIFICATE`.
    public let root: URL
    /// The clips, in play order.
    public let clips: [KroutonBDMVClip]
    /// The video bitrate the clips were encoded at.
    public let videoKbps: Int
}

/// Why authoring stopped. The descriptions are for the user.
public enum KroutonAVCHDError: Error, LocalizedError, Sendable, Equatable {
    case ffmpegMissing
    case noSources
    case tooLong(minutes: Int)
    case encodeFailed(file: String, message: String)
    case cancelled

    public var errorDescription: String? {
        switch self {
        case .ffmpegMissing:
            return "Making a high-definition disc needs ffmpeg. Install it (for example: brew install ffmpeg) and try again."
        case .noSources:
            return "Add at least one video file first."
        case .tooLong(let minutes):
            return "\(minutes) minutes of high-definition video won't fit this disc at a watchable quality. Use a dual-layer DVD or fewer clips."
        case .encodeFailed(let file, let message):
            return "ffmpeg couldn't convert \(file): \(message)"
        case .cancelled:
            return "Cancelled."
        }
    }
}

/// Turns ordinary video files into an AVCHD disc that Blu-ray players with AVCHD support play
/// from a DVD: each file is converted to Blu-ray H.264 + AC-3 in a 192-byte-packet
/// `.m2ts`, then analyzed so the playlist and clip files carry its real times and key frames.
public enum AVCHDOnDVDAuthoringEngine {
    /// AVCHD on DVD caps the video at 18 Mbit/s.
    public static let maxVideoKbps = 18_000
    static let minVideoKbps = 4_000
    static let audioKbps = 448

    /// Reports progress (0 to 1) and a status line.
    public typealias Progress = @Sendable (_ fraction: Double, _ status: String) -> Void

    /// Builds the disc folder in `root` (which must be empty or not exist yet).
    public static func author(
        sources: [URL],
        into root: URL,
        capacityBytes: Int64,
        progress: Progress = { _, _ in },
        isCancelled: @escaping @Sendable () -> Bool = { false }
    ) throws -> KroutonAVCHDDisc {
        guard !sources.isEmpty else { throw KroutonAVCHDError.noSources }
        guard let ffmpeg = DVDVideoIFORelinker.locateFFmpegExecutable() else { throw KroutonAVCHDError.ffmpegMissing }
        let ffprobe = ffmpeg.deletingLastPathComponent().appendingPathComponent("ffprobe")
        let probes = sources.map { probe($0, ffprobe: ffprobe) }
        let totalSeconds = probes.map(\.duration).reduce(0, +)
        let videoKbps = try fittingBitrate(seconds: totalSeconds, capacityBytes: capacityBytes)

        let fm = FileManager.default
        let bdmv = root.appendingPathComponent("BDMV")
        for dir in ["PLAYLIST", "CLIPINF", "STREAM", "AUXDATA", "BDJO", "JAR", "META", "BACKUP/PLAYLIST", "BACKUP/CLIPINF", "BACKUP/BDJO"] {
            try fm.createDirectory(at: bdmv.appendingPathComponent(dir), withIntermediateDirectories: true)
        }
        try fm.createDirectory(at: root.appendingPathComponent("CERTIFICATE/BACKUP"), withIntermediateDirectories: true)

        // One format for the whole title: players handle a change of frame rate between play
        // items badly, so every clip is converted to the first one's.
        let format = KroutonBDMVVideoFormat.nearest(framesPerSecond: probes[0].framesPerSecond)
        var clips: [KroutonBDMVClip] = []
        var doneSeconds = 0.0
        for (index, source) in sources.enumerated() {
            let name = String(format: "%05d", index)
            let output = bdmv.appendingPathComponent("STREAM/\(name).m2ts")
            let span = max(probes[index].duration, 1)
            let base = doneSeconds
            try encode(
                ffmpeg: ffmpeg,
                arguments: encodeArguments(source: source, output: output, format: format, videoKbps: videoKbps),
                duration: span,
                file: source.lastPathComponent,
                isCancelled: isCancelled
            ) { seconds in
                progress(min(0.99, (base + seconds) / max(totalSeconds, 1)), "Converting \(source.lastPathComponent)")
            }
            doneSeconds += span
            let analysis = try KroutonM2TSAnalyzer.analyze(url: output)
            let rate = UInt32((videoKbps + videoKbps / 10 + audioKbps + 640) * 1000 / 8)
            let clip = KroutonBDMVClip(name: name, analysis: analysis, format: format, recordingRate: rate)
            clips.append(clip)
            let info = KroutonBDMVWriter.clipInfo(clip)
            try info.write(to: bdmv.appendingPathComponent("CLIPINF/\(name).clpi"))
            try info.write(to: bdmv.appendingPathComponent("BACKUP/CLIPINF/\(name).clpi"))
        }
        let files: [(String, Data)] = [
            ("index.bdmv", KroutonBDMVWriter.index(format: clips[0].format)),
            ("MovieObject.bdmv", KroutonBDMVWriter.movieObject()),
            ("PLAYLIST/00000.mpls", KroutonBDMVWriter.playlist(clips: clips)),
        ]
        for (path, data) in files {
            try data.write(to: bdmv.appendingPathComponent(path))
            try data.write(to: bdmv.appendingPathComponent("BACKUP/\(path)"))
        }
        progress(1, "Disc folder ready")
        return KroutonAVCHDDisc(root: root, clips: clips, videoKbps: videoKbps)
    }

    /// The highest video bit rate (up to 18 Mbit/s) at which `seconds` of video fits, leaving
    /// room for audio and the transport stream's packet overhead.
    public static func fittingBitrate(seconds: Double, capacityBytes: Int64) throws -> Int {
        let usable = Double(capacityBytes) * 0.97 * 188 / 192 * 0.94 // file system, packets, muxing
        let kbps = Int(usable * 8 / max(seconds, 1) / 1000) - audioKbps
        guard kbps >= minVideoKbps else { throw KroutonAVCHDError.tooLong(minutes: Int((seconds / 60).rounded(.up))) }
        return min(maxVideoKbps, kbps)
    }

    /// The ffmpeg arguments for one clip: x264 in Blu-ray-compatible mode (level 4.1, one-second
    /// GOPs, four slices, access-unit delimiters, VBV within the Blu-ray limits), AC-3 at 448 kbit/s,
    /// scaled and padded to the format's frame size, in a 192-byte-packet transport stream.
    public static func encodeArguments(source: URL, output: URL, format: KroutonBDMVVideoFormat, videoKbps: Int) -> [String] {
        let keyint = Int(format.framesPerSecond.rounded())
        var x264 = "bluray-compat=1:level=4.1:keyint=\(keyint):min-keyint=1:slices=4:aud=1:nal-hrd=vbr"
            + ":vbv-maxrate=\(min(maxVideoKbps, videoKbps + videoKbps / 4)):vbv-bufsize=15000:b-pyramid=strict:open-gop=0"
        if format.interlaced {
            x264 += ":fake-interlaced=1:pic-struct=1"
        }
        let (w, h) = (format.width, format.height)
        return [
            "-y", "-hide_banner", "-nostdin", "-loglevel", "error", "-progress", "pipe:1", "-nostats",
            "-i", source.path,
            "-map", "0:v:0", "-map", "0:a:0?", "-sn", "-dn",
            "-vf", "scale=\(w):\(h):force_original_aspect_ratio=decrease,pad=\(w):\(h):(ow-iw)/2:(oh-ih)/2,setsar=1,fps=\(format.ffmpegRate),format=yuv420p",
            "-c:v", "libx264", "-preset", "medium", "-profile:v", "high",
            "-b:v", "\(videoKbps)k", "-x264-params", x264,
            "-c:a", "ac3", "-b:a", "\(audioKbps)k", "-ar", "48000",
            "-af", "aformat=channel_layouts=stereo|5.1|mono",
            "-f", "mpegts", "-mpegts_m2ts_mode", "1",
            output.path,
        ]
    }

    // MARK: - ffprobe and ffmpeg

    struct Probe: Equatable {
        var framesPerSecond = 23.976
        var duration = 0.0
    }

    /// Frame rate and duration from ffprobe, if it is installed next to ffmpeg.
    static func probe(_ url: URL, ffprobe: URL) -> Probe {
        var result = Probe()
        guard FileManager.default.isExecutableFile(atPath: ffprobe.path) else { return result }
        let process = Process()
        process.executableURL = ffprobe
        process.arguments = ["-v", "error", "-select_streams", "v:0", "-show_entries", "stream=r_frame_rate:format=duration",
                             "-of", "default=noprint_wrappers=1", url.path]
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice
        guard (try? process.run()) != nil else { return result }
        let text = String(decoding: pipe.fileHandleForReading.readDataToEndOfFile(), as: UTF8.self)
        process.waitUntilExit()
        for line in text.split(separator: "\n") {
            let parts = line.split(separator: "=", maxSplits: 1).map(String.init)
            guard parts.count == 2 else { continue }
            if parts[0] == "r_frame_rate" {
                let ratio = parts[1].split(separator: "/").compactMap { Double($0) }
                if ratio.count == 2, ratio[1] > 0 { result.framesPerSecond = ratio[0] / ratio[1] }
            } else if parts[0] == "duration", let seconds = Double(parts[1]) {
                result.duration = seconds
            }
        }
        return result
    }

    private static func encode(
        ffmpeg: URL,
        arguments: [String],
        duration: Double,
        file: String,
        isCancelled: @escaping @Sendable () -> Bool,
        progress: (Double) -> Void
    ) throws {
        let process = Process()
        process.executableURL = ffmpeg
        process.arguments = arguments
        let out = Pipe(), err = Pipe()
        process.standardOutput = out
        process.standardError = err
        try process.run()
        let reader = out.fileHandleForReading
        var buffer = ""
        while true {
            if isCancelled() {
                process.terminate()
                process.waitUntilExit()
                throw KroutonAVCHDError.cancelled
            }
            let data = reader.availableData
            if data.isEmpty { break }
            buffer += String(decoding: data, as: UTF8.self)
            while let newline = buffer.firstIndex(of: "\n") {
                let line = buffer[..<newline]
                if line.hasPrefix("out_time_us="), let us = Double(line.dropFirst(12)) {
                    progress(min(duration, us / 1_000_000))
                }
                buffer.removeSubrange(...newline)
            }
        }
        process.waitUntilExit()
        guard process.terminationStatus == 0 else {
            let message = String(decoding: err.fileHandleForReading.readDataToEndOfFile(), as: UTF8.self)
                .split(separator: "\n").last.map(String.init) ?? "exit \(process.terminationStatus)"
            throw KroutonAVCHDError.encodeFailed(file: file, message: message)
        }
    }
}
