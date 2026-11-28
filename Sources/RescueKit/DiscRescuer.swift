import Foundation
import OpticalCore

// MARK: - Disc Rescuer

/// Where rescued sectors go. Writes may arrive out of order; unwritten areas read back as zeros.
public protocol KroutonSectorSink: Sendable {
    /// Writes `bytes` at byte `offset` of the destination.
    func write(_ bytes: [UInt8], atByte offset: Int64) throws
    /// Flushes and releases the destination once the rescue ends.
    func close() throws
}

extension KroutonSectorSink {
    public func close() throws {}
}

/// An image file on disk. Unread sectors stay zero-filled (sparse on APFS).
public final class KroutonImageFileSink: KroutonSectorSink {
    let handle: FileHandle

    /// Opens the file at `url`, creating it if needed, and sets its length to `totalBytes`.
    /// Bytes already in it are kept, so a rescue can resume.
    public init(url: URL, totalBytes: Int64) throws {
        if !FileManager.default.fileExists(atPath: url.path) {
            FileManager.default.createFile(atPath: url.path, contents: nil)
        }
        handle = try FileHandle(forWritingTo: url)
        try handle.truncate(atOffset: UInt64(max(0, totalBytes)))
    }

    public func write(_ bytes: [UInt8], atByte offset: Int64) throws {
        try handle.seek(toOffset: UInt64(offset))
        try handle.write(contentsOf: bytes)
    }

    public func close() throws {
        try handle.synchronize()
        try handle.close()
    }
}

/// How hard to try. The defaults suit a scratched CD or DVD in a typical drive.
public struct KroutonRescuePlan: Sendable, Equatable {
    /// Sectors per read in the first pass (64 KiB).
    public var clusterSectors: Int = 32
    /// How far to jump after a failed read in the first pass, at least; doubles while reads keep failing.
    public var minimumSkipSectors: Int = 64
    /// The longest jump after failed reads in the first pass.
    public var maximumSkipSectors: Int = 16_384
    /// Extra attempts on each bad sector after scraping.
    public var retryPasses: Int = 1

    public init(clusterSectors: Int = 32, minimumSkipSectors: Int = 64, maximumSkipSectors: Int = 16_384, retryPasses: Int = 1) {
        self.clusterSectors = max(1, min(clusterSectors, 512))
        self.minimumSkipSectors = max(1, minimumSkipSectors)
        self.maximumSkipSectors = max(self.minimumSkipSectors, maximumSkipSectors)
        self.retryPasses = max(0, retryPasses)
    }
}

/// Copies a damaged disc the way GNU ddrescue does: everything easy first, the hard parts later.
///
/// 1. **Copy**: read large clusters forward; on an error, mark the cluster for trimming and skip
///    ahead (further each time it fails again), so a scratch costs seconds, not hours.
/// 2. **Trim**: read single sectors in from both edges of each failed area until each edge hits
///    an error; the middle is left for scraping.
/// 3. **Scrape**: read every remaining sector one at a time.
/// 4. **Retry**: give each bad sector another chance.
///
/// The map is updated after every read, so a rescue can stop at any point and carry on later.
public struct KroutonDiscRescuer: Sendable {
    /// Called with the map after each read.
    public typealias Progress = @Sendable (KroutonRescueMap) -> Void

    /// Where sectors are read from.
    public let source: any KroutonSectorSource
    /// Where rescued sectors are written.
    public let sink: any KroutonSectorSink
    /// How hard to try.
    public let plan: KroutonRescuePlan

    public init(source: any KroutonSectorSource, sink: any KroutonSectorSink, plan: KroutonRescuePlan = KroutonRescuePlan()) {
        self.source = source
        self.sink = sink
        self.plan = plan
    }

    /// Runs (or resumes) the rescue. Stops early if the drive fails or the task is cancelled;
    /// the returned map says how far it got either way.
    public func run(resuming previous: KroutonRescueMap? = nil, progress: Progress = { _ in }) async throws -> KroutonRescueMap {
        let sectors = try await source.sectorCount()
        let total = sectors * Int64(KroutonSector.size)
        var map = previous.flatMap { $0.totalBytes == total ? $0 : nil } ?? KroutonRescueMap(totalBytes: total)
        let size = Int64(KroutonSector.size)

        // 1. Copy.
        map.phase = .copying
        var skip = Int64(plan.minimumSkipSectors)
        for block in map.blocks(.nonTried) {
            var lba = block.position / size
            let end = block.end / size
            while lba < end {
                try Task.checkCancellation()
                let count = Int(min(Int64(plan.clusterSectors), end - lba))
                map.currentPosition = lba * size
                if try await copy(lba: lba, count: count, into: &map) {
                    skip = Int64(plan.minimumSkipSectors)
                    lba += Int64(count)
                } else {
                    // Leave the skipped stretch untried for now; it is tried again below.
                    let jump = min(skip, end - lba - Int64(count))
                    map.mark((lba * size)..<((lba + Int64(count)) * size), as: .nonTrimmed)
                    lba += Int64(count) + max(0, jump)
                    skip = min(skip * 2, Int64(plan.maximumSkipSectors))
                }
                progress(map)
            }
        }
        // Areas jumped over are copied cluster by cluster without further skipping.
        for block in map.blocks(.nonTried) {
            var lba = block.position / size
            while lba < block.end / size {
                try Task.checkCancellation()
                let count = Int(min(Int64(plan.clusterSectors), block.end / size - lba))
                if try await !copy(lba: lba, count: count, into: &map) {
                    map.mark((lba * size)..<((lba + Int64(count)) * size), as: .nonTrimmed)
                }
                lba += Int64(count)
                progress(map)
            }
        }

        // 2. Trim.
        map.phase = .trimming
        for block in map.blocks(.nonTrimmed) {
            var first = block.position / size
            var last = block.end / size - 1
            // From the leading edge forward until a sector fails...
            while first <= last {
                try Task.checkCancellation()
                let readable = try await copy(lba: first, count: 1, into: &map)
                if !readable { map.mark(first * size..<(first + 1) * size, as: .badSector) }
                first += 1
                if !readable { break }
            }
            // ...then from the trailing edge backward.
            while last >= first {
                try Task.checkCancellation()
                let readable = try await copy(lba: last, count: 1, into: &map)
                if !readable { map.mark(last * size..<(last + 1) * size, as: .badSector) }
                last -= 1
                if !readable { break }
            }
            if first <= last { map.mark(first * size..<(last + 1) * size, as: .nonScraped) }
            progress(map)
        }

        // 3. Scrape, then 4. retry.
        map.phase = .scraping
        try await readEachSector(in: .nonScraped, map: &map, progress: progress)
        map.phase = .retrying
        for retry in 0..<plan.retryPasses {
            map.pass = retry + 2
            try await readEachSector(in: .badSector, map: &map, progress: progress)
        }
        map.phase = .finished
        map.currentPosition = total
        progress(map)
        return map
    }

    private func readEachSector(in status: KroutonRescueMap.Status, map: inout KroutonRescueMap, progress: Progress) async throws {
        let size = Int64(KroutonSector.size)
        for block in map.blocks(status) {
            for lba in (block.position / size)..<(block.end / size) {
                try Task.checkCancellation()
                map.currentPosition = lba * size
                if try await !copy(lba: lba, count: 1, into: &map) {
                    map.mark(lba * size..<(lba + 1) * size, as: .badSector)
                }
                progress(map)
            }
        }
    }

    /// One read. Success writes the bytes and marks them finished. A read error returns false;
    /// a failing drive throws, which ends the rescue with the map as it stands.
    private func copy(lba: Int64, count: Int, into map: inout KroutonRescueMap) async throws -> Bool {
        let bytes: [UInt8]
        do {
            bytes = try await source.read(lba: lba, count: count)
        } catch {
            switch error {
            case .unreadable: return false
            case .driveFailed: throw error
            }
        }
        let size = Int64(KroutonSector.size)
        try sink.write(bytes, atByte: lba * size)
        map.mark((lba * size)..<((lba + Int64(count)) * size), as: .finished)
        return true
    }
}
