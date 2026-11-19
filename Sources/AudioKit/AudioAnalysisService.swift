import AVFoundation
import Foundation

// Everything Krouton learns by opening an audio file, done once per file, off the
// main actor.
//
// Replaces `SpliceWaveformCache` (the NSLock-guarded static dictionaries) and its
// callers in view bodies. Differences that matter:
//
//   - No file is opened on the main actor, ever. Views receive a finished,
//     immutable `TrackAnalysis` or a "pending"/"failed" state.
//   - A file that cannot be decoded throws. The old code fell back to turning the
//     file's raw bytes into an envelope, then to a random-number waveform, and to
//     a 210 s duration. Those looked real on screen and fed real calculations.
//   - Peaks are true sample values. The old cache normalised to 0.92 full scale.
//   - Length is an exact frame count from the file, not seconds as a Double.
//

public struct TrackAnalysis: Sendable {
    public let sampleRate: Double
    /// Length rounded UP to whole Red Book frames (the stream is zero-padded to match).
    public let redBookFrames: Int64
    /// First `windowSeconds` of the track.
    public let headPeaks: FramePeaks
    /// Last `windowSeconds` of the track; the last element is the final frame.
    public let tailPeaks: FramePeaks
    /// BS.1770 loudness of each window, for gain matching across a transition.
    let headLUFS: Double?
    let tailLUFS: Double?
    // Metadata exactly as found. Nil means the file did not say.
    public let title: String?
    public let performer: String?
    public let album: String?
    public let isrc: String?
    /// Tempo in BPM estimated from the 75 Hz frame onset envelope (nil if rhythmic pulse is weak).
    public let estimatedBPM: Double?
}

public enum AudioAnalysisError: LocalizedError {
    case empty(URL)
    case unreadable(URL, reason: String)

    public var errorDescription: String? {
        switch self {
        case .empty(let url): return "\(url.lastPathComponent) contains no audio."
        case .unreadable(let url, let reason): return "\(url.lastPathComponent) could not be read: \(reason)"
        }
    }
}

public actor AudioAnalysisService {
    public static let shared = AudioAnalysisService()

    /// Must cover the longest crossfade (15 s) with margin.
    static let windowSeconds: Double = 35
    private static let maxConcurrentDecodes = 4
    private static let maxCachedAnalyses = 64

    /// A changed file (same path, new size or date) is analysed again.
    private struct Key: Hashable {
        let path: String
        let modified: Date?
        let size: Int64
    }

    private var cache: [Key: TrackAnalysis] = [:]
    private var accessOrder: [Key] = []
    private var inFlight: [Key: Task<TrackAnalysis, Error>] = [:]
    private var activeDecodes = 0
    private var waiters: [CheckedContinuation<Void, Never>] = []

    public init() {}

    /// Returns the cached analysis, joins one already running, or starts one.
    /// Dropping 99 files starts 99 calls; only a few decode at a time.
    public func analysis(for url: URL) async throws -> TrackAnalysis {
        let key = Self.key(for: url)
        if let hit = cache[key] {
            accessOrder.removeAll { $0 == key }
            accessOrder.append(key)
            return hit
        }
        if let running = inFlight[key] { return try await running.value }

        let task = Task<TrackAnalysis, Error> {
            await self.acquireDecodeSlot()
            defer { self.releaseDecodeSlot() }
            // Detached so the decode itself runs in parallel, not on this actor.
            return try await Task.detached(priority: .userInitiated) {
                try await Self.analyse(url)
            }.value
        }
        inFlight[key] = task
        defer { inFlight[key] = nil }
        let result = try await task.value
        while cache.count >= Self.maxCachedAnalyses, !accessOrder.isEmpty {
            let oldest = accessOrder.removeFirst()
            cache.removeValue(forKey: oldest)
        }
        cache[key] = result
        accessOrder.removeAll { $0 == key }
        accessOrder.append(key)
        return result
    }

    /// Returns cached analysis buffers immediately to the system when leaving audio workspaces.
    public func purgeCache() {
        cache.removeAll(keepingCapacity: false)
        accessOrder.removeAll(keepingCapacity: false)
    }

    // MARK: - Concurrency limit

    private func acquireDecodeSlot() async {
        if activeDecodes < Self.maxConcurrentDecodes {
            activeDecodes += 1
            return
        }
        await withCheckedContinuation { waiters.append($0) }
    }

    private func releaseDecodeSlot() {
        if waiters.isEmpty {
            activeDecodes -= 1
        } else {
            waiters.removeFirst().resume() // hand the slot straight to the next waiter
        }
    }

    private static func key(for url: URL) -> Key {
        let values = try? url.resourceValues(forKeys: [.contentModificationDateKey, .fileSizeKey])
        return Key(path: url.path, modified: values?.contentModificationDate, size: Int64(values?.fileSize ?? 0))
    }

    // MARK: - The work (runs detached)

    private static func analyse(_ url: URL) async throws -> TrackAnalysis {
        let file: AVAudioFile
        do { file = try AVAudioFile(forReading: url) } catch {
            throw AudioAnalysisError.unreadable(url, reason: error.localizedDescription)
        }
        let rate = file.processingFormat.sampleRate
        let length = file.length
        guard rate > 0, length > 0 else { throw AudioAnalysisError.empty(url) }

        let windowFrames = min(Int64(windowSeconds * rate), length)
        let head = try readWindow(file, url: url, start: 0, count: windowFrames)
        let tail = try readWindow(file, url: url, start: length - windowFrames, count: windowFrames)
        let tags = await readTags(url)

        let hPeaks = framePeaks(head, sampleRate: rate, alignToEnd: false)
        let tPeaks = framePeaks(tail, sampleRate: rate, alignToEnd: true)
        return TrackAnalysis(
            sampleRate: rate,
            redBookFrames: Int64((Double(length) * 75.0 / rate).rounded(.up)),
            headPeaks: hPeaks,
            tailPeaks: tPeaks,
            headLUFS: LoudnessMeter.integratedLUFS(channels: head, sampleRate: rate),
            tailLUFS: LoudnessMeter.integratedLUFS(channels: tail, sampleRate: rate),
            title: tags.title,
            performer: tags.performer,
            album: tags.album,
            isrc: tags.isrc,
            estimatedBPM: estimateBPM(headPeaks: hPeaks, tailPeaks: tPeaks)
        )
    }

    /// Decodes `count` frames starting at `start` as float channels (at most two).
    private static func readWindow(_ file: AVAudioFile, url: URL, start: Int64, count: Int64) throws -> [[Float]] {
        let format = file.processingFormat
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(count)) else {
            throw AudioAnalysisError.unreadable(url, reason: "could not allocate a decode buffer")
        }
        file.framePosition = start
        do { try file.read(into: buffer, frameCount: AVAudioFrameCount(count)) } catch {
            throw AudioAnalysisError.unreadable(url, reason: error.localizedDescription)
        }
        guard let data = buffer.floatChannelData, buffer.frameLength > 0 else {
            throw AudioAnalysisError.unreadable(url, reason: "the decoder returned no samples")
        }
        let frames = Int(buffer.frameLength)
        return (0..<min(2, Int(format.channelCount))).map { channel in
            Array(UnsafeBufferPointer(start: data[channel], count: frames))
        }
    }

    /// One absolute peak per Red Book frame, at the file's own sample rate.
    /// The peak is the larger of the channels, because each channel is burned
    /// separately and either one can clip.
    private static func framePeaks(_ channels: [[Float]], sampleRate: Double, alignToEnd: Bool) -> FramePeaks {
        guard let sampleCount = channels.map(\.count).min(), sampleCount > 0 else { return FramePeaks(values: []) }
        let samplesPerFrame = sampleRate / 75.0
        let frameCount = max(1, Int(Double(sampleCount) / samplesPerFrame))
        // For a tail window the LAST bucket must end exactly at the end of the file.
        let offset = alignToEnd ? Double(sampleCount) - Double(frameCount) * samplesPerFrame : 0

        var values = [Float](repeating: 0, count: frameCount)
        for frame in 0..<frameCount {
            let lower = max(0, Int(offset + Double(frame) * samplesPerFrame))
            let upper = min(sampleCount, Int(offset + Double(frame + 1) * samplesPerFrame))
            var peak: Float = 0
            for channel in channels {
                for i in lower..<max(lower, upper) { peak = max(peak, abs(channel[i])) }
            }
            values[frame] = peak
        }
        return FramePeaks(values: values)
    }

    /// Embedded tags first; the file name only as a labelled last resort for the title.
    private static func readTags(_ url: URL) async -> (title: String?, performer: String?, album: String?, isrc: String?) {
        let items = (try? await AVURLAsset(url: url).load(.metadata)) ?? []

        func text(_ identifier: AVMetadataIdentifier) async -> String? {
            guard let item = AVMetadataItem.metadataItems(from: items, filteredByIdentifier: identifier).first,
                  let value = try? await item.load(.stringValue) else { return nil }
            let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty ? nil : trimmed
        }

        let guess = FilenameTitleGuess.guess(from: url)
        let embeddedTitle = await text(.commonIdentifierTitle)
        let embeddedArtist = await text(.commonIdentifierArtist)
        return (
            title: embeddedTitle ?? guess.title?.value,
            performer: embeddedArtist ?? guess.performer?.value,
            album: await text(.commonIdentifierAlbumName),
            isrc: await text(.id3MetadataInternationalStandardRecordingCode)
        )
    }

    /// Estimates tempo in [72, 175] BPM via half-wave-rectified onset autocorrelation over 75 Hz Red Book frame peaks.
    public static func estimateBPM(headPeaks: FramePeaks, tailPeaks: FramePeaks) -> Double? {
        let vals = headPeaks.values.count >= 450 ? headPeaks.values : tailPeaks.values
        guard vals.count >= 300 else { return nil }
        let n = min(vals.count, 1_500)
        var onset = [Float](repeating: 0, count: n)
        var energySum: Float = 0
        for i in 1..<n {
            let diff = max(0, vals[i] - vals[i - 1])
            onset[i] = diff
            energySum += diff
        }
        guard energySum > 0.25 else { return nil }
        // Lag in 75 Hz frames for 72..175 BPM: lag = 75 * 60 / BPM -> 26..62 frames
        var bestLag = 37
        var bestScore: Float = -1
        for lag in 26...62 {
            var score: Float = 0
            for i in lag..<n {
                score += onset[i] * onset[i - lag]
            }
            if score > bestScore {
                bestScore = score
                bestLag = lag
            }
        }
        guard bestScore > 0 else { return nil }
        let bpm = (75.0 * 60.0) / Double(bestLag)
        return (bpm * 2.0).rounded() / 2.0
    }
}
