import Foundation

// MARK: - Car-Safe MP3 Disc Options

/// What the MP3 CD workspace's switches do to the files before they are burned.
public struct KroutonCarAudioOptions: Sendable, Equatable, Codable {
    public enum Profile: String, Sendable, Equatable, Codable, CaseIterable {
        /// 320 kbps constant bit rate: plays in every MP3 head unit.
        case cbr320
        /// 192 kbps constant bit rate: about 1.7 times as much music per disc.
        case cbr192
        /// LAME VBR quality 6 (about 115 kbps): the most music per disc.
        case vbrLong
        /// The files as they are, renamed and listed but not converted.
        case passthrough
    }

    public var profile: Profile = .cbr320
    /// "001 - Title.mp3", so head units that sort by name play the disc in order.
    public var zeroPadNumbers = true
    public var generateM3U = true
    /// ID3v2.3 with an ID3v1 tag too; off writes ID3v2.4 (ffmpeg's default).
    public var enforceID3v23 = true
    /// Leaves out embedded cover art, which some head units choke on.
    public var stripArtwork = true
    public var forceJointStereo = true
    /// LAME's 19 kHz low-pass, which spends the bits where they are heard.
    public var lowPass19kHz = true

    public init() {}

    public var needsFFmpeg: Bool { profile != .passthrough }
}

public enum KroutonCarAudioError: Error, LocalizedError, Sendable, Equatable {
    case ffmpegMissing
    case noAudio
    case conversionFailed(String)

    public var errorDescription: String? {
        switch self {
        case .ffmpegMissing:
            return "Converting to MP3 needs ffmpeg (Homebrew: brew install ffmpeg). Or choose 16-Bit FLAC / WAV Direct to burn the files as they are. Nothing was written."
        case .noAudio:
            return "None of the staged files is audio Krouton can put on an MP3 disc. Nothing was written."
        case .conversionFailed(let file):
            return "ffmpeg couldn't convert \(file). Nothing was written."
        }
    }
}

// MARK: - Car-Safe MP3 Disc Preparer

/// Builds the folder that goes on a car MP3 disc: every audio file from the deck (folders
/// opened, in deck order, then by name), converted with ffmpeg's LAME encoder or copied as it
/// is, renamed in play order, with an `.m3u` at the root. Nothing hidden is carried over, so no
/// `.DS_Store` or `._` AppleDouble files reach the disc.
///
/// Programmer's notes: ffmpeg runs once per file with an explicit argument array (no shell).
/// `-map 0:a:0` keeps only the first audio stream, which is how cover art is dropped; with art
/// kept, the picture stream is copied as an attached picture. Names are cut to 60 characters
/// and stripped of the characters Joliet refuses, so the data-disc writer never renames them.
public enum KroutonCarAudioDiscPreparer {
    static let audioExtensions: Set<String> = ["mp3", "flac", "m4a", "wav", "aiff", "aif", "ogg", "aac", "wma", "opus", "alac", "caf"]

    /// The audio files a deck stands for, in burn order.
    public static func audioFiles(in sources: [URL]) -> [URL] {
        let fm = FileManager.default
        var result: [URL] = []
        for source in sources {
            var isDir: ObjCBool = false
            guard fm.fileExists(atPath: source.path, isDirectory: &isDir) else { continue }
            if isDir.boolValue {
                let walker = fm.enumerator(at: source, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles])
                var found: [URL] = []
                while let next = walker?.nextObject() as? URL {
                    if audioExtensions.contains(next.pathExtension.lowercased()) { found.append(next) }
                }
                result += found.sorted { $0.path.localizedStandardCompare($1.path) == .orderedAscending }
            } else if audioExtensions.contains(source.pathExtension.lowercased()), !source.lastPathComponent.hasPrefix(".") {
                result.append(source)
            }
        }
        return result
    }

    /// The file name a track gets on the disc.
    public static func discName(for source: URL, index: Int, options: KroutonCarAudioOptions) -> String {
        let forbidden = CharacterSet(charactersIn: "*/:;?\\\"<>|")
        let base = source.deletingPathExtension().lastPathComponent
            .components(separatedBy: forbidden).joined(separator: "_")
        let ext = options.profile == .passthrough ? source.pathExtension.lowercased() : "mp3"
        let stem = options.zeroPadNumbers ? String(format: "%03d - %@", index + 1, base) : base
        return String(stem.prefix(60)) + "." + ext
    }

    /// The ffmpeg arguments that convert one file.
    public static func ffmpegArguments(input: URL, output: URL, options: KroutonCarAudioOptions) -> [String] {
        var args = ["-nostdin", "-hide_banner", "-loglevel", "error", "-y", "-i", input.path, "-map", "0:a:0"]
        if !options.stripArtwork {
            args += ["-map", "0:v?", "-c:v", "copy", "-disposition:v", "attached_pic"]
        }
        args += ["-map_metadata", "0", "-c:a", "libmp3lame", "-ar", "44100"]
        switch options.profile {
        case .cbr320: args += ["-b:a", "320k"]
        case .cbr192: args += ["-b:a", "192k"]
        case .vbrLong, .passthrough: args += ["-q:a", "6"]
        }
        if options.forceJointStereo { args += ["-joint_stereo", "1"] }
        if options.lowPass19kHz { args += ["-cutoff", "19000"] }
        if options.stripArtwork { args += ["-metadata", "lyrics=", "-metadata", "UNSYNCEDLYRICS="] }
        args += options.enforceID3v23 ? ["-id3v2_version", "3", "-write_id3v1", "1"] : ["-id3v2_version", "4"]
        return args + [output.path]
    }

    /// Writes the disc's folder into `directory` and returns it. Runs ffmpeg once per file, so
    /// call it off the main actor.
    public static func prepare(
        sources: [URL],
        options: KroutonCarAudioOptions,
        into directory: URL,
        ffmpeg: URL?,
        progress: (Double) -> Void = { _ in }
    ) throws -> URL {
        let files = audioFiles(in: sources)
        guard !files.isEmpty else { throw KroutonCarAudioError.noAudio }
        if options.needsFFmpeg, ffmpeg == nil { throw KroutonCarAudioError.ffmpegMissing }
        let fm = FileManager.default
        try fm.createDirectory(at: directory, withIntermediateDirectories: true)
        var names: [String] = []
        for (index, file) in files.enumerated() {
            let name = discName(for: file, index: index, options: options)
            let output = directory.appendingPathComponent(name)
            if fm.fileExists(atPath: output.path) { try fm.removeItem(at: output) }
            if let ffmpeg, options.needsFFmpeg {
                let process = Process()
                process.executableURL = ffmpeg
                process.arguments = ffmpegArguments(input: file, output: output, options: options)
                process.standardOutput = FileHandle.nullDevice
                process.standardError = FileHandle.nullDevice
                try process.run()
                process.waitUntilExit()
                guard process.terminationStatus == 0, fm.fileExists(atPath: output.path) else {
                    throw KroutonCarAudioError.conversionFailed(file.lastPathComponent)
                }
            } else {
                try fm.copyItem(at: file, to: output)
            }
            names.append(name)
            progress(Double(index + 1) / Double(files.count))
        }
        if options.generateM3U {
            let playlist = "#EXTM3U\r\n" + names.joined(separator: "\r\n") + "\r\n"
            try Data(playlist.utf8).write(to: directory.appendingPathComponent("PLAYLIST.M3U"))
        }
        return directory
    }
}
