import AVFoundation
import Foundation
import OpticalCore

// MARK: - Audio Length Probe
//
// The fast first pass that stops disc headers jumping around.
//
// Opening an audio file and reading its length touches only the header, so 40
// files probe in a few milliseconds in total. The full analysis (peaks,
// loudness, tags) follows at its own pace and replaces the probed figure with
// the exact one. Order of events after a drop:
//
//   1. append tracks                      -> one provisional disc, no headers
//   2. probe all (this file), ONE update  -> headers appear once, in the right place
//   3. full analysis per file             -> lengths confirmed; plan stops being provisional
//
// For lossless sources the probe is already exact, so step 3 changes nothing
// visible. For MP3 and AAC it can move by a few frames, which is why the plan
// stays marked provisional until analysis finishes.

/// Reads audio file lengths from their headers only.
public enum AudioLengthProbe {
    /// Length in Red Book frames, and whether the container states it exactly.
    public static func length(of url: URL) throws -> ItemCost {
        let file = try AVAudioFile(forReading: url)
        let rate = file.fileFormat.sampleRate
        guard rate > 0, file.length > 0 else { throw CocoaError(.fileReadCorruptFile) }
        let frames = Int64((Double(file.length) * 75.0 / rate).rounded(.up))

        let exactFormats: Set<AudioFormatID> = [kAudioFormatLinearPCM, kAudioFormatFLAC, kAudioFormatAppleLossless]
        let isExact = exactFormats.contains(file.fileFormat.streamDescription.pointee.mFormatID)
        return isExact ? .exact(frames) : .estimated(frames)
    }

    /// Probes every file off the main actor and returns once, so the caller can
    /// apply all lengths in a single model update (one plan recompute, one redraw).
    public static func lengths(of sources: [(id: UUID, url: URL)]) async -> [UUID: Result<ItemCost, any Error>] {
        await withTaskGroup(of: (UUID, Result<ItemCost, any Error>).self) { group in
            for source in sources {
                group.addTask { (source.id, Result { try length(of: source.url) }) }
            }
            var results: [UUID: Result<ItemCost, any Error>] = [:]
            for await (id, result) in group { results[id] = result }
            return results
        }
    }
}

// In AudioProjectController.add(_:):
//
//   let added = project.append(urls)                       // step 1
//   Task {
//       let probed = await AudioLengthProbe.lengths(of: added.map { ($0.id, $0.source) })
//       applyProbe(probed)                                 // step 2: one mutation, no undo entry
//       added.forEach(startAnalysis)                       // step 3
//   }
//
// `applyProbe` sets `probedFrameCount` on each track and marks failures as
// unreadable on the row. A file that cannot even be probed is not given a length.
//
// The same idea covers transcoded formats. For MP3 CD the cost of a track is
// probed duration x target bitrate, which is exact for CBR. Do not derive
// duration from the source file's size: that is only right for uncompressed PCM.
