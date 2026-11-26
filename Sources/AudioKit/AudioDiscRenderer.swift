import Foundation
import OpticalCore

// MARK: - Audio Disc Renderer

/// One rendered track, ready for a Red Book burn: raw 16-bit little-endian stereo PCM at
/// 44.1 kHz, a whole number of 2,352-byte frames, and the pregap (silence) the drive writes
/// before it.
public struct KroutonRenderedAudioTrack: Sendable, Equatable {
    public let number: Int
    public let pcm: URL
    /// Length in Red Book frames (1/75 s), without the pregap.
    public let frames: Int64
    /// Silence before the track, in frames: 150 (2 s) before track 1 as Red Book requires,
    /// the chosen pause before a later track, 0 for gapless joins and crossfades.
    public let pregapFrames: Int64
    public let title: String
    public let performer: String
    public let isrc: String
}

public enum KroutonAudioRenderError: Error, LocalizedError, Sendable, Equatable {
    case blocked(String)
    case decodeFailed(String)
    case cancelled

    public var errorDescription: String? {
        switch self {
        case .blocked(let why): return why
        case .decodeFailed(let file): return "Krouton couldn't read the audio in \(file)."
        case .cancelled: return "Cancelled."
        }
    }
}

/// Renders an `AudioProject` exactly as the disc will play: the project's layout gives every
/// track's start, pause and crossfade, and crossfades are mixed with `CrossfadeRenderParams` —
/// the same gains the Splice editor's live audition uses — so what you previewed is what is
/// burned. The program is cut at each track's INDEX 01: a pause becomes the next track's
/// pregap, which the drive writes as digital silence, and a crossfade's mixed audio up to the
/// splice point stays at the end of the earlier track.
///
/// Programmer's notes: memory stays bounded by decoding a track only while the window touches
/// it (at most three are ever held, for back-to-back crossfades). Positions are in samples
/// (588 per frame); every cut is frame-aligned because the layout is.
public enum KroutonAudioDiscRenderer {
    static let samplesPerFrame: Int64 = 588
    static let firstTrackPregap: Int64 = 150

    public static func render(
        project: AudioProject,
        into directory: URL,
        progress: (Double) -> Void = { _ in },
        isCancelled: () -> Bool = { false }
    ) throws -> [KroutonRenderedAudioTrack] {
        let (layout, issues) = project.layout()
        guard let layout else {
            throw KroutonAudioRenderError.blocked("Some tracks are still being analysed. Wait for their lengths, then burn.")
        }
        try check(issues: issues, project: project)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

        let tracks = project.tracks
        let n = tracks.count
        let spf = samplesPerFrame
        let start = layout.map { $0.audioStart * spf }
        let length = tracks.map { ($0.frameCount ?? 0) * spf }
        let overlap = layout.map { $0.overlapWithPrevious * spf }
        let params = tracks.map {
            CrossfadeRenderParams(spec: $0.transitionToNext, sampleRate: 44_100, suppressedAtDiscBoundary: false)
        }
        let end = start[n - 1] + length[n - 1]
        var cache: [Int: [Int16]] = [:]

        func samples(_ j: Int) throws -> [Int16] {
            if let hit = cache[j] { return hit }
            let data: Data
            do {
                data = try KroutonAudioEngine.decodeAudioFileToRedBookPCM(url: tracks[j].source)
            } catch {
                throw KroutonAudioRenderError.decodeFailed(tracks[j].source.lastPathComponent)
            }
            var pcm = [Int16](repeating: 0, count: Int(length[j]) * 2)
            data.withUnsafeBytes { raw in
                let available = min(pcm.count, raw.count / 2)
                for k in 0..<available {
                    pcm[k] = Int16(littleEndian: raw.loadUnaligned(fromByteOffset: k * 2, as: Int16.self))
                }
            }
            cache[j] = pcm
            return pcm
        }

        func gain(_ j: Int, at s: Int64) -> Double {
            var g = 1.0
            if j > 0, overlap[j] > 0, s < start[j] + overlap[j] {
                g *= params[j - 1].gains(at: Double(s - start[j]) / Double(overlap[j])).in
            }
            if j < n - 1, overlap[j + 1] > 0, s >= start[j + 1] {
                g *= params[j].gains(at: Double(s - start[j + 1]) / Double(overlap[j + 1])).out
            }
            return g
        }

        var rendered: [KroutonRenderedAudioTrack] = []
        let chunk = spf * 75 // one second
        for i in 0..<n {
            let from = i == 0 ? 0 : layout[i].index01 * spf
            let to = i < n - 1 ? (layout[i + 1].index00 ?? layout[i + 1].index01) * spf : end
            let url = directory.appendingPathComponent(String(format: "track%02d.pcm", i + 1))
            FileManager.default.createFile(atPath: url.path, contents: nil)
            let out = try FileHandle(forWritingTo: url)
            defer { try? out.close() }
            var s = from
            while s < to {
                if isCancelled() { throw KroutonAudioRenderError.cancelled }
                let count = min(chunk, to - s)
                var mix = [Double](repeating: 0, count: Int(count) * 2)
                for j in 0..<n where start[j] < s + count && start[j] + length[j] > s {
                    let pcm = try samples(j)
                    let lo = max(s, start[j]), hi = min(s + count, start[j] + length[j])
                    for t in lo..<hi {
                        let g = gain(j, at: t)
                        let src = Int(t - start[j]) * 2, dst = Int(t - s) * 2
                        mix[dst] += Double(pcm[src]) * g
                        mix[dst + 1] += Double(pcm[src + 1]) * g
                    }
                }
                var bytes = Data(count: mix.count * 2)
                bytes.withUnsafeMutableBytes { raw in
                    for (k, value) in mix.enumerated() {
                        let clipped = Int16(max(-32_768, min(32_767, value.rounded())))
                        raw.storeBytes(of: clipped.littleEndian, toByteOffset: k * 2, as: Int16.self)
                    }
                }
                try out.write(contentsOf: bytes)
                s += count
                // Drop decoded tracks the window has passed.
                for key in cache.keys where start[key] + length[key] <= s { cache[key] = nil }
                progress(Double(s) / Double(max(1, end)))
            }
            let pregap: Int64 = i == 0 ? firstTrackPregap
                : layout[i].index00.map { layout[i].index01 - $0 } ?? 0
            let track = tracks[i]
            rendered.append(KroutonRenderedAudioTrack(
                number: i + 1, pcm: url, frames: (to - from) / spf, pregapFrames: pregap,
                title: track.title.isEmpty ? track.source.deletingPathExtension().lastPathComponent : track.title,
                performer: track.performer.isEmpty ? project.albumPerformer : track.performer,
                isrc: track.isrc))
        }
        return rendered
    }

    /// The 13-digit Media Catalog Number for a UPC-A (12 digits, given a leading 0) or an EAN-13,
    /// or "" when the field holds neither.
    public static func mediaCatalogNumber(_ upc: String) -> String {
        let digits = upc.filter(\.isNumber)
        switch digits.count {
        case 12: return "0" + digits
        case 13: return digits
        default: return ""
        }
    }

    /// Stops a burn the layout says would be wrong or impossible.
    static func check(issues: [AudioProjectIssue], project: AudioProject) throws {
        if project.discPlan().discs.count > 1 {
            throw KroutonAudioRenderError.blocked("This project needs more than one CD. Remove tracks or split it into separate projects, then burn each.")
        }
        for issue in issues {
            switch issue {
            case .noTracks:
                throw KroutonAudioRenderError.blocked("Add audio tracks first.")
            case .tooManyTracks(let count), .tooManyTracksOnDisc(_, let count):
                throw KroutonAudioRenderError.blocked("A CD holds at most 99 tracks; this one has \(count).")
            case .trackTooShort(let id, _):
                let name = project.track(id)?.title ?? "A track"
                throw KroutonAudioRenderError.blocked("\(name.isEmpty ? "A track" : name) is shorter than the 4 seconds a CD track must last.")
            case .exceedsCapacity(let frames, let capacity):
                throw KroutonAudioRenderError.blocked("The tracks run \(frames / 4500) minutes; the disc holds \(capacity / 4500).")
            case .notAnalysed:
                throw KroutonAudioRenderError.blocked("Some tracks are still being analysed. Wait for their lengths, then burn.")
            case .trackExceedsDiscCapacity, .overlapTrimmed, .automaticBreakSplitsContinuousRun:
                continue
            }
        }
    }
}

// MARK: - BIN/CUE export

extension KroutonAudioDiscRenderer {
    /// Joins rendered tracks into one raw `.bin` and writes the `.cue` beside it, so the disc
    /// can be burned later (Burn Disc Image) or by another app. Track 1's two-second pregap is
    /// left implied, as every burner expects; later pauses are written as silence and marked
    /// with INDEX 00.
    public static func writeBinCue(
        _ tracks: [KroutonRenderedAudioTrack],
        project: AudioProject,
        cueURL: URL
    ) throws {
        let binURL = cueURL.deletingPathExtension().appendingPathExtension("bin")
        FileManager.default.createFile(atPath: binURL.path, contents: nil)
        let out = try FileHandle(forWritingTo: binURL)
        defer { try? out.close() }

        func msf(_ frames: Int64) -> String {
            String(format: "%02d:%02d:%02d", frames / 4500, (frames / 75) % 60, frames % 75)
        }
        func quoted(_ text: String) -> String {
            "\"" + KroutonCDTextSanitizer.sanitize(text).replacingOccurrences(of: "\"", with: "'") + "\""
        }

        var lines: [String] = []
        let mcn = mediaCatalogNumber(project.upc)
        if !mcn.isEmpty { lines.append("CATALOG \(mcn)") }
        if project.writeCDText {
            if !project.albumPerformer.isEmpty { lines.append("PERFORMER \(quoted(project.albumPerformer))") }
            if !project.albumTitle.isEmpty { lines.append("TITLE \(quoted(project.albumTitle))") }
        }
        lines.append("FILE \"\(binURL.lastPathComponent)\" BINARY")
        var position: Int64 = 0
        for track in tracks {
            lines.append(String(format: "  TRACK %02d AUDIO", track.number))
            let isrc = KroutonCDTextSanitizer.sanitizeISRC(track.isrc)
            if isrc.count == 12 { lines.append("    ISRC \(isrc)") }
            if project.writeCDText {
                if !track.title.isEmpty { lines.append("    TITLE \(quoted(track.title))") }
                if !track.performer.isEmpty { lines.append("    PERFORMER \(quoted(track.performer))") }
            }
            if track.number > 1, track.pregapFrames > 0 {
                lines.append("    INDEX 00 \(msf(position))")
                try out.write(contentsOf: Data(count: Int(track.pregapFrames) * 2352))
                position += track.pregapFrames
            }
            lines.append("    INDEX 01 \(msf(position))")
            let source = try FileHandle(forReadingFrom: track.pcm)
            defer { try? source.close() }
            while let chunk = try source.read(upToCount: 1 << 20), !chunk.isEmpty {
                try out.write(contentsOf: chunk)
            }
            position += track.frames
        }
        try (lines.joined(separator: "\r\n") + "\r\n").write(to: cueURL, atomically: true, encoding: .utf8)
    }
}
