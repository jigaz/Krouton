import AudioToolbox
import Foundation
import os

// MARK: - AccurateRip Disc Identity

/// A disc's AccurateRip identity, worked out from its table of contents, and where its
/// database entry lives.
///
/// Programmer's notes: `trackStarts` are the audio tracks' start sectors as the TOC gives
/// them (track 1 normally at 0) and `leadout` is the lead-out sector. id1 sums the starts and
/// the lead-out; id2 weights each by its track number (sector 0 counts as 1); the third part
/// is the old freedb/CDDB disc ID. The database is served over plain HTTP only.
public struct KroutonAccurateRipDiscID: Sendable, Equatable {
    public let trackCount: Int
    public let id1: UInt32
    public let id2: UInt32
    public let cddb: UInt32

    public init(trackStarts: [Int], leadout: Int) {
        trackCount = trackStarts.count
        var a: UInt32 = 0, b: UInt32 = 0
        for (i, start) in trackStarts.enumerated() {
            a &+= UInt32(truncatingIfNeeded: start)
            b &+= UInt32(truncatingIfNeeded: max(start, 1)) &* UInt32(i + 1)
        }
        a &+= UInt32(truncatingIfNeeded: leadout)
        b &+= UInt32(truncatingIfNeeded: max(leadout, 1)) &* UInt32(trackStarts.count + 1)
        id1 = a
        id2 = b
        func digitSum(_ n: Int) -> Int { var n = n, s = 0; while n > 0 { s += n % 10; n /= 10 }; return s }
        let n = trackStarts.reduce(0) { $0 + digitSum(($1 + 150) / 75) }
        let seconds = (leadout + 150) / 75 - ((trackStarts.first ?? 0) + 150) / 75
        cddb = UInt32((n % 255) << 24 | seconds << 8 | trackStarts.count)
    }

    public var url: URL {
        func hex(_ v: UInt32) -> String { String(v & 0xF, radix: 16) }
        let name = String(format: "dBAR-%03d-%08x-%08x-%08x.bin", trackCount, id1, id2, cddb)
        return URL(string: "http://www.accuraterip.com/accuraterip/\(hex(id1))/\(hex(id1 >> 4))/\(hex(id1 >> 8))/\(name)")!
    }
}

// MARK: - Results

/// How one track compared with the database.
public struct KroutonAccurateRipTrackResult: Sendable, Equatable {
    public let number: Int
    /// The track's AccurateRip v1 checksum at the drive offset found.
    public let crc: UInt32
    /// How many submitted rips have this checksum; 0 means none match.
    public let confidence: Int
    /// The highest confidence of any checksum submitted for this track.
    public let bestConfidence: Int
}

public struct KroutonAccurateRipReport: Sendable, Equatable {
    /// Samples by which this drive's reads are shifted, as found by matching the database.
    public let driveOffset: Int
    public let tracks: [KroutonAccurateRipTrackResult]
    public var allAccurate: Bool { !tracks.isEmpty && tracks.allSatisfy { $0.confidence > 0 } }
}

// MARK: - Verifier

/// Checks a rip against AccurateRip.
///
/// Programmer's notes: macOS reads audio CDs without offset correction, so a track's checksum
/// is computed at every read offset within ±`offsetRange` samples and the offset where most
/// tracks match the database wins: that is the drive's read offset. For each track the samples
/// just outside it are taken from its neighbours (and are silence before the first track and
/// after the last), as a corrected rip would hold them. AccurateRip v1 sums each 32-bit stereo
/// sample times its 1-based position, leaving out the first five frames of the first track and
/// the last five of the last; that sum slides one sample in constant time, so all offsets cost
/// one pass. Only v1 is compared: v2 sums can't slide, and most database entries carry v1.
public enum KroutonAccurateRipVerifier {
    public static let offsetRange = 2_940
    static let skip = 5 * 588

    /// Fetches the disc's entry; nil when the disc isn't in the database.
    public static func fetch(_ disc: KroutonAccurateRipDiscID) async throws -> Data? {
        let (data, response) = try await URLSession.shared.data(from: disc.url)
        if let http = response as? HTTPURLResponse, http.statusCode == 404 { return nil }
        return data
    }

    /// Each track's submitted checksums with their confidence, from all of the entry's chunks.
    static func parse(_ data: Data, trackCount: Int) -> [[(confidence: Int, crc: UInt32)]] {
        var result = Array(repeating: [(confidence: Int, crc: UInt32)](), count: trackCount)
        let bytes = [UInt8](data)
        func le32(_ at: Int) -> UInt32 {
            UInt32(bytes[at]) | UInt32(bytes[at + 1]) << 8 | UInt32(bytes[at + 2]) << 16 | UInt32(bytes[at + 3]) << 24
        }
        var at = 0
        while at + 13 <= bytes.count {
            let count = Int(bytes[at])
            at += 13
            guard count == trackCount, at + count * 9 <= bytes.count else { break }
            for t in 0..<count {
                result[t].append((Int(bytes[at]), le32(at + 1)))
                at += 9
            }
        }
        return result
    }

    /// Reads a ripped file's samples (16-bit stereo, one UInt32 per sample frame).
    static func readSamples(_ url: URL) throws -> [UInt32] {
        var ref: ExtAudioFileRef?
        guard ExtAudioFileOpenURL(url as CFURL, &ref) == noErr, let file = ref else {
            throw CocoaError(.fileReadCorruptFile)
        }
        defer { ExtAudioFileDispose(file) }
        var format = AudioStreamBasicDescription(
            mSampleRate: 44_100, mFormatID: kAudioFormatLinearPCM,
            mFormatFlags: kAudioFormatFlagIsSignedInteger | kAudioFormatFlagIsPacked,
            mBytesPerPacket: 4, mFramesPerPacket: 1, mBytesPerFrame: 4, mChannelsPerFrame: 2,
            mBitsPerChannel: 16, mReserved: 0)
        guard ExtAudioFileSetProperty(file, kExtAudioFileProperty_ClientDataFormat,
                                      UInt32(MemoryLayout<AudioStreamBasicDescription>.size), &format) == noErr else {
            throw CocoaError(.fileReadCorruptFile)
        }
        var samples: [UInt32] = []
        var chunk = [UInt32](repeating: 0, count: 44_100)
        while true {
            var frames = UInt32(chunk.count)
            let status = chunk.withUnsafeMutableBytes { raw -> OSStatus in
                var list = AudioBufferList(mNumberBuffers: 1, mBuffers: AudioBuffer(
                    mNumberChannels: 2, mDataByteSize: UInt32(raw.count), mData: raw.baseAddress))
                return ExtAudioFileRead(file, &frames, &list)
            }
            guard status == noErr else { throw CocoaError(.fileReadCorruptFile) }
            if frames == 0 { break }
            samples += chunk[0..<Int(frames)].map { UInt32(littleEndian: $0) }
        }
        return samples
    }

    /// v1 checksums of one track at every offset in -range...range. `padded` holds `range`
    /// samples before the track and `range` after it.
    static func slidingCRCs(padded: [UInt32], count: Int, isFirst: Bool, isLast: Bool, range: Int) -> [UInt32] {
        let lo = isFirst ? skip - 1 : 0
        let hi = isLast ? count - skip : count      // positions lo..<hi, 0-based within the track
        guard hi > lo else { return Array(repeating: 0, count: 2 * range + 1) }
        // At offset o, position i reads padded[range + o + i] and is weighted (i + 1).
        var crc: UInt32 = 0, window: UInt32 = 0
        let base = 0   // at offset -range, position i reads padded[i]
        for i in lo..<hi {
            let s = padded[base + i]
            crc &+= s &* UInt32(i + 1)
            window &+= s
        }
        var out = [crc]
        out.reserveCapacity(2 * range + 1)
        for step in 0..<(2 * range) {
            // Move one sample later: every weight drops by one, the first sample leaves,
            // and the next sample comes in with the last weight.
            let leaving = padded[base + step + lo]
            let entering = padded[base + step + hi]
            crc = crc &- window &- leaving &* UInt32(lo) &+ entering &* UInt32(hi)
            window = window &- leaving &+ entering
            out.append(crc)
        }
        return out
    }

    /// Compares ripped tracks (in disc order, every track of the disc) with an entry.
    public static func verify(files: [URL], database: Data) throws -> KroutonAccurateRipReport {
        let range = offsetRange
        let entries = parse(database, trackCount: files.count)
        var crcs: [[UInt32]] = []
        var next = try readSamples(files[0])
        var before: [UInt32] = []
        for t in 0..<files.count {
            let track = next
            next = t + 1 < files.count ? try readSamples(files[t + 1]) : []
            let after = Array(next.prefix(range))
            let padded = [UInt32](repeating: 0, count: range - before.count) + before
                + track + after + [UInt32](repeating: 0, count: range - after.count)
            crcs.append(slidingCRCs(padded: padded, count: track.count, isFirst: t == 0, isLast: t == files.count - 1, range: range))
            before = Array(track.suffix(range))
        }
        // The offset where most tracks match wins; offset 0 wins ties.
        var bestOffset = 0, bestScore = -1
        for index in 0...(2 * range) {
            let score = (0..<files.count).filter { t in entries[t].contains { $0.crc == crcs[t][index] && $0.confidence > 0 } }.count
            let offset = index - range
            if score > bestScore || (score == bestScore && abs(offset) < abs(bestOffset)) {
                bestScore = score
                bestOffset = offset
            }
        }
        let index = bestOffset + range
        let tracks = (0..<files.count).map { t -> KroutonAccurateRipTrackResult in
            let crc = crcs[t][index]
            return KroutonAccurateRipTrackResult(
                number: t + 1, crc: crc,
                confidence: entries[t].filter { $0.crc == crc }.map(\.confidence).max() ?? 0,
                bestConfidence: entries[t].map(\.confidence).max() ?? 0)
        }
        return KroutonAccurateRipReport(driveOffset: bestOffset, tracks: tracks)
    }

    // MARK: - Checking a Finished Rip

    public enum Outcome: Sendable, Equatable {
        case checked(KroutonAccurateRipReport)
        case notInDatabase
        case failed(String)
    }

    /// Fetches the entry and compares the rip, for the ripper's own queue. Never call it on the
    /// main thread or from inside a task.
    public static func checkBlocking(files: [URL], disc: KroutonAccurateRipDiscID) -> Outcome {
        let done = DispatchSemaphore(value: 0)
        let box = KroutonOutcomeBox()
        Task {
            do {
                if let data = try await fetch(disc) {
                    box.set(.checked(try verify(files: files, database: data)))
                } else {
                    box.set(.notInDatabase)
                }
            } catch {
                box.set(.failed(error.localizedDescription))
            }
            done.signal()
        }
        done.wait()
        return box.value
    }
}

/// Carries `checkBlocking`'s outcome out of its task.
final class KroutonOutcomeBox: Sendable {
    private let state = OSAllocatedUnfairLock<KroutonAccurateRipVerifier.Outcome>(initialState: .failed("No result"))
    func set(_ value: KroutonAccurateRipVerifier.Outcome) { state.withLock { $0 = value } }
    var value: KroutonAccurateRipVerifier.Outcome { state.withLock { $0 } }
}
