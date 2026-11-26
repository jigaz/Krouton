import AudioKit
import Foundation
import OpticalCore

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
        }
    }
}
