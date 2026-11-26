import AudioKit
import Foundation
import OpticalCore
import VideoKit

// MARK: - VerifyHarness — Suite 37: Audio CD Rendering

/// Three 5-second tones: a 2-second pause after track 1, a 1-second crossfade after track 2.
/// The render must cut the program exactly where the layout says, put the pause in track 2's
/// pregap, and keep the crossfade inside the tracks with no gap; the BIN/CUE export must hold
/// the same program, pause included.
extension KroutonTestHarness {
    mutating func runVerifyAudioDiscSuite() {
        self.runSuite("37. Audio CD: Project Rendered to Red Book Tracks, Pauses and Crossfades Exact") { h in
            let dir = FileManager.default.temporaryDirectory
                .appendingPathComponent("KroutonAudioDiscVerify_\(UUID().uuidString)", isDirectory: true)
            try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            defer { try? FileManager.default.removeItem(at: dir) }

            var urls: [URL] = []
            for i in 1...3 {
                let url = dir.appendingPathComponent("tone\(i).wav")
                try KroutonAudioEngine.synthesizeTestToneWAV(at: url, durationSeconds: 5.0)
                urls.append(url)
            }
            var project = AudioProject(albumTitle: "Verify", albumPerformer: "Krouton", upc: "012345678905")
            let added = project.append(urls)
            for (i, track) in added.enumerated() {
                project.update(track.id) { t in
                    t.frameCount = 375
                    t.title = "Tone \(i + 1)"
                    if i == 0 { _ = t.setISRC("us-k7r-26-00001") }
                    t.transitionToNext.overlapSeconds = i == 1 ? 1.0 : 0.0
                    t.transitionToNext.preGapSeconds = i == 0 ? 2.0 : 0.0
                }
            }

            let tracks = try KroutonAudioDiscRenderer.render(project: project, into: dir.appendingPathComponent("render"))
            h.check(tracks.count == 3, "Audio CD: one rendered track per project track")
            h.check(tracks.map(\.pregapFrames) == [150, 150, 0],
                    "Audio CD: 2 s before track 1, the chosen 2 s pause before track 2, none into a crossfade")
            h.check(tracks[0].frames == 375, "Audio CD: track 1 ends where the pause begins")
            let program = tracks.reduce(0) { $0 + $1.frames } + tracks.dropFirst().reduce(0) { $0 + $1.pregapFrames }
            h.check(program == 375 + 150 + 375 + 375 - 75,
                    "Audio CD: tracks and pauses add up to the program, with the 1 s crossfade overlapped")
            let sizes = tracks.map { (try? FileManager.default.attributesOfItem(atPath: $0.pcm.path)[.size] as? Int) ?? -1 }
            h.check(zip(sizes, tracks).allSatisfy { $0 == Int($1.frames) * 2352 }, "Audio CD: every PCM file is whole 2,352-byte frames")
            if let pcm = try? Data(contentsOf: tracks[0].pcm) {
                let peak = stride(from: 0, to: min(pcm.count, 44_100 * 4), by: 2).map { i in
                    abs(Int(Int16(littleEndian: pcm.withUnsafeBytes { $0.loadUnaligned(fromByteOffset: i, as: Int16.self) })))
                }.max() ?? 0
                h.check(peak > 1_000, "Audio CD: the rendered track holds the tone, not silence")
            }
            h.check(tracks[0].isrc == "USK7R2600001" && tracks[1].title == "Tone 2", "Audio CD: titles and ISRCs carried per track")

            let cue = dir.appendingPathComponent("disc.cue")
            try KroutonAudioDiscRenderer.writeBinCue(tracks, project: project, cueURL: cue)
            let text = (try? String(contentsOf: cue, encoding: .utf8)) ?? ""
            h.check(text.contains("CATALOG 0012345678905") && text.contains("ISRC USK7R2600001"),
                    "Audio CD image: UPC-A becomes the 13-digit catalog number; the ISRC is written")
            h.check(text.contains("TRACK 02 AUDIO") && text.contains("INDEX 00 00:05:00") && text.contains("INDEX 01 00:07:00"),
                    "Audio CD image: track 2's pause is INDEX 00 at 0:05, its start INDEX 01 at 0:07")
            let bin = dir.appendingPathComponent("disc.bin")
            let binSize = (try? FileManager.default.attributesOfItem(atPath: bin.path)[.size] as? Int) ?? -1
            h.check(binSize == Int(program) * 2352, "Audio CD image: the .bin holds the whole program, pause included")

            var tooShort = project
            tooShort.update(added[2].id) { $0.frameCount = 100 }
            var refused = false
            do { _ = try KroutonAudioDiscRenderer.render(project: tooShort, into: dir.appendingPathComponent("short")) } catch {
                if case .blocked? = error as? KroutonAudioRenderError { refused = true }
            }
            h.check(refused, "Audio CD: a track under 4 s stops the render with an explanation")
            try Self.verifyCarMP3Preparer(&h, dir: dir, tones: urls)
            try Self.verifyTagWriter(&h, dir: dir, tone: urls[0])
        }
    }

    /// The MP3 CD folder: names in play order, Joliet-safe, the playlist, no hidden files, and
    /// the encoder settings each switch stands for.
    private static func verifyCarMP3Preparer(_ h: inout KroutonTestHarness, dir: URL, tones: [URL]) throws {
        var options = KroutonCarAudioOptions()
        let odd = URL(fileURLWithPath: "/tmp/AC/DC: Back?In*Black.flac")
        h.check(KroutonCarAudioDiscPreparer.discName(for: odd, index: 6, options: options) == "007 - DC_ Back_In_Black.mp3",
                "MP3 CD: zero-padded play order, characters Joliet refuses replaced")
        let args = KroutonCarAudioDiscPreparer.ffmpegArguments(input: odd, output: URL(fileURLWithPath: "/tmp/o.mp3"), options: options)
        h.check(args.contains("320k") && args.contains("-joint_stereo") && args.contains("19000") && args.contains("-write_id3v1")
                && !args.contains("attached_pic"), "MP3 CD: 320k CBR, joint stereo, 19 kHz low-pass, ID3v2.3 + v1, art dropped")
        options.profile = .vbrLong
        options.stripArtwork = false
        options.enforceID3v23 = false
        let vbr = KroutonCarAudioDiscPreparer.ffmpegArguments(input: odd, output: URL(fileURLWithPath: "/tmp/o.mp3"), options: options)
        h.check(vbr.contains("-q:a") && vbr.contains("attached_pic") && vbr.contains("4"), "MP3 CD: VBR, art kept, ID3v2.4 when asked")

        let album = dir.appendingPathComponent("Album", isDirectory: true)
        try FileManager.default.createDirectory(at: album, withIntermediateDirectories: true)
        try FileManager.default.copyItem(at: tones[1], to: album.appendingPathComponent("02 b.wav"))
        try FileManager.default.copyItem(at: tones[2], to: album.appendingPathComponent("01 a.wav"))
        try Data("x".utf8).write(to: album.appendingPathComponent("._01 a.wav"))
        try Data("x".utf8).write(to: album.appendingPathComponent("cover.jpg"))
        var copy = KroutonCarAudioOptions()
        copy.profile = .passthrough
        let out = try KroutonCarAudioDiscPreparer.prepare(sources: [tones[0], album], options: copy,
                                                          into: dir.appendingPathComponent("car"), ffmpeg: nil)
        let names = (try? FileManager.default.contentsOfDirectory(atPath: out.path).sorted()) ?? []
        h.check(names == ["001 - tone1.wav", "002 - 01 a.wav", "003 - 02 b.wav", "PLAYLIST.M3U"],
                "MP3 CD: deck order, folders opened by name, no hidden or non-audio files, a playlist")
        var mp3 = KroutonCarAudioOptions()
        mp3.profile = .cbr192
        var missing = false
        do { _ = try KroutonCarAudioDiscPreparer.prepare(sources: [tones[0]], options: mp3, into: dir.appendingPathComponent("car2"), ffmpeg: nil) }
        catch { missing = (error as? KroutonCarAudioError) == .ffmpegMissing }
        h.check(missing, "MP3 CD: converting without ffmpeg stops with advice")
    }

    /// Tags go into each container's own place, and the audio bytes are left alone.
    private static func verifyTagWriter(_ h: inout KroutonTestHarness, dir: URL, tone: URL) throws {
        var tags = KroutonAudioTags()
        tags.title = "Solar Echoes"
        tags.artist = "Krouton"
        tags.album = "Verify"
        tags.trackNumber = 3

        let wav = dir.appendingPathComponent("tagged.wav")
        try FileManager.default.copyItem(at: tone, to: wav)
        let before = try Data(contentsOf: wav)
        h.check(KroutonAudioTagWriter.writeBlocking(tags, to: wav), "Tags: WAV written")
        let after = try Data(contentsOf: wav)
        let riff = after.subdata(in: 4..<8).withUnsafeBytes { $0.loadUnaligned(as: UInt32.self) }
        h.check(after.prefix(before.count) == before && UInt32(littleEndian: riff) == UInt32(after.count - 8)
                && after.range(of: Data("INAMSolar".utf8)) == nil && after.range(of: Data("Solar Echoes".utf8)) != nil
                && after.range(of: Data("LIST".utf8)) != nil,
                "Tags: WAV gets a LIST/INFO chunk after the audio, RIFF size fixed, audio untouched")

        // A minimal FLAC: marker, a STREAMINFO (34 bytes), an old comment, then frame bytes.
        var flac: [UInt8] = Array("fLaC".utf8) + [0x00, 0, 0, 34] + [UInt8](repeating: 7, count: 34)
        flac += [0x84, 0, 0, 11] + [3, 0, 0, 0] + Array("old".utf8) + [0, 0, 0, 0]
        flac += [0xFF, 0xF8, 1, 2, 3]
        let flacURL = dir.appendingPathComponent("tagged.flac")
        try Data(flac).write(to: flacURL)
        h.check(KroutonAudioTagWriter.writeBlocking(tags, to: flacURL), "Tags: FLAC written")
        let out = [UInt8]((try? Data(contentsOf: flacURL)) ?? Data())
        let text = String(decoding: out, as: UTF8.self)
        h.check(out.count > 42 && out[4] == 0x00 && out[42] == 0x84 && text.contains("TITLE=Solar Echoes")
                && text.contains("TRACKNUMBER=3") && !text.contains("old") && Array(out.suffix(5)) == [0xFF, 0xF8, 1, 2, 3],
                "Tags: FLAC's old comment replaced after STREAMINFO, last-block flag moved, frames untouched")
    }
}
