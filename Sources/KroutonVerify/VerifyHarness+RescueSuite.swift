import Foundation
import OpticalCore
import RescueKit
import os

// MARK: - VerifyHarness — Suite 34: Disc Rescue

/// A scratched disc: every sector holds a known pattern, some never read, some read on a later try.
actor ScratchedDisc: KroutonSectorSource {
    let sectors: Int64
    let dead: Set<Int64>
    /// Sectors that fail this many times, then read.
    var flaky: [Int64: Int]
    private(set) var reads = 0
    private(set) var singleSectorReads = 0

    init(sectors: Int64, dead: Set<Int64>, flaky: [Int64: Int] = [:]) {
        self.sectors = sectors
        self.dead = dead
        self.flaky = flaky
    }

    static func pattern(_ lba: Int64) -> UInt8 { UInt8(truncatingIfNeeded: lba % 251 + 1) }

    func sectorCount() async throws(KroutonSectorReadError) -> Int64 { sectors }

    func read(lba: Int64, count: Int) async throws(KroutonSectorReadError) -> [UInt8] {
        reads += 1
        if count == 1 { singleSectorReads += 1 }
        let range = lba..<(lba + Int64(count))
        if range.contains(where: { dead.contains($0) }) { throw .unreadable("Unrecovered read error") }
        for sector in range {
            if let remaining = flaky[sector], remaining > 0 {
                flaky[sector] = remaining - 1
                throw .unreadable("Unrecovered read error")
            }
        }
        return range.flatMap { [UInt8](repeating: Self.pattern($0), count: KroutonSector.size) }
    }
}

final class MemorySink: KroutonSectorSink {
    let storage: OSAllocatedUnfairLock<[UInt8]>

    init(bytes: Int) {
        storage = OSAllocatedUnfairLock(initialState: [UInt8](repeating: 0, count: bytes))
    }

    func write(_ bytes: [UInt8], atByte offset: Int64) throws {
        storage.withLock { buffer in
            buffer.replaceSubrange(Int(offset)..<Int(offset) + bytes.count, with: bytes)
        }
    }

    func sector(_ lba: Int64) -> ArraySlice<UInt8> {
        let start = Int(lba) * KroutonSector.size
        return storage.withLock { $0[start..<start + KroutonSector.size] }
    }
}

extension KroutonTestHarness {
    mutating func runVerifyRescueSuite() {
        self.runSuite("34. Disc Rescue: ddrescue-Style Passes, Mapfiles and Resuming") { h in
            let dead: Set<Int64> = Set(100..<110).union([300, 450])
            let disc = ScratchedDisc(sectors: 600, dead: dead, flaky: [451: 2])
            let sink = MemorySink(bytes: 600 * KroutonSector.size)
            let rescuer = KroutonDiscRescuer(source: disc, sink: sink, plan: KroutonRescuePlan(clusterSectors: 16, minimumSkipSectors: 8))
            let outcome = Self.blockingResult { try await rescuer.run() }
            guard case .success(let map) = outcome else {
                h.lint(false, "The rescue must finish on a scratched disc: \(outcome)")
                return
            }
            let size = Int64(KroutonSector.size)
            h.lint(map.totalBytes == 600 * size, "The map must cover the whole disc")
            h.lint(map.isComplete, "Nothing may be left untried after the passes")
            h.lint(map.bytes(.badSector) == Int64(dead.count) * size,
                   "Exactly the dead sectors stay bad (got \(map.bytes(.badSector) / size)); sector 451 reads on retry")
            h.lint(map.bytes(.finished) == (600 - Int64(dead.count)) * size, "Every other sector must be copied")

            var contentOK = true
            for lba in Int64(0)..<600 {
                let expected: UInt8 = dead.contains(lba) ? 0 : ScratchedDisc.pattern(lba)
                if sink.sector(lba).contains(where: { $0 != expected }) { contentOK = false }
            }
            h.lint(contentOK, "Copied sectors must hold the disc's bytes and bad sectors must stay zero")

            let reads = Self.blocking { await disc.reads }
            let singles = Self.blocking { await disc.singleSectorReads }
            h.lint(reads < 140, "Skipping past damage must keep the read count low (\(reads) reads for 600 sectors)")
            h.lint(singles < 80, "Single-sector reads must stay near the damaged areas (\(singles))")

            // The mapfile survives a round trip, and ddrescue's own lower-case files parse.
            let text = map.mapfile()
            h.lint(KroutonRescueMap.parse(mapfile: text) == map, "A Krouton mapfile must read back unchanged")
            let ddrescue = """
            # Mapfile. Created by GNU ddrescue version 1.28
            # current_pos  current_status  current_pass
            0x000c8000     /               1
            #      pos        size  status
            0x00000000  0x000c8000  +
            0x000c8000  0x00000800  /
            0x000c8800  0x00007800  -
            """
            let parsed = KroutonRescueMap.parse(mapfile: ddrescue)
            h.lint(parsed?.blocks.count == 3 && parsed?.phase == .scraping && parsed?.totalBytes == 0xD0000,
                   "A GNU ddrescue mapfile must parse")
            h.lint(KroutonRescueMap.parse(mapfile: "0x0 ? 1\n0x800 0x800 +\n") == nil, "A map with a gap must be refused")

            // Resume after cleaning the disc: only the bad sectors are read again.
            let cleaned = ScratchedDisc(sectors: 600, dead: [])
            let again = KroutonDiscRescuer(source: cleaned, sink: sink, plan: KroutonRescuePlan(retryPasses: 1))
            if case .success(let resumed) = Self.blockingResult({ try await again.run(resuming: map) }) {
                let rereads = Self.blocking { await cleaned.reads }
                h.lint(resumed.bytes(.finished) == 600 * size, "A resumed rescue must finish the disc")
                h.lint(rereads == dead.count, "A resumed rescue must reread only the bad sectors (\(rereads) reads)")
            } else {
                h.lint(false, "Resuming the rescue must succeed")
            }

            // MMC READ (10) and READ CAPACITY are encoded as the spec says.
            h.lint(MMCCommand.read10(lba: 0x0102_0304, blocks: 0x0506).cdb == [0x28, 0, 1, 2, 3, 4, 0, 5, 6, 0],
                   "READ (10) must put the LBA and length big-endian in the CDB")
            h.lint(MMCCommand.read10(lba: 0, blocks: 16).allocationLength == 16 * 2048, "READ (10) must allocate 2048 bytes a sector")
            h.lint(MMCCommand.readCapacity.cdb.first == 0x25 && MMCCommand.readCapacity.allocationLength == 8,
                   "READ CAPACITY must be a 10-byte CDB with an 8-byte reply")
        }
    }

    /// Runs async work to completion from the synchronous harness.
    static func blockingResult<T: Sendable>(_ work: @escaping @Sendable () async throws -> T) -> Result<T, any Error> {
        let box = OSAllocatedUnfairLock<Result<T, any Error>?>(initialState: nil)
        let done = DispatchSemaphore(value: 0)
        Task.detached {
            do {
                let value = try await work()
                box.withLock { $0 = .success(value) }
            } catch {
                box.withLock { $0 = .failure(error) }
            }
            done.signal()
        }
        done.wait()
        return box.withLock { $0 } ?? .failure(CancellationError())
    }
}
