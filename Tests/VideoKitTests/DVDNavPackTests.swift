#if canImport(XCTest)
import XCTest
#endif
import Foundation
@testable import VideoKit

final class DVDNavPackTests: XCTestCase {
    /// NV_PCKs at sectors 0, 2 and 5 of seven: the VOBU_SRI of each must follow the DVD-Video
    /// order (FWDI Video, FWDI 240 ... 1, FWDI Next, BWDI Prev, BWDI 1 ... 240, BWDI Video).
    func testSearchPointersLandInTheirOwnSlots() {
        var vob = [UInt8](repeating: 0, count: 7 * 2048)
        for sector in [0, 2, 5] {
            let base = sector * 2048
            for (at, value) in [(0, 0xBA), (38, 0xBF), (0x0400, 0xBF)] {
                vob[base + at + 2] = 0x01
                vob[base + at + 3] = UInt8(value)
            }
        }
        let (patched, starts, _) = DVDVideoIFORelinker.scanAndPatchTitleVOBs(Data(vob))
        XCTAssertEqual(starts, [0, 2, 5])
        let bytes = [UInt8](patched)
        func entry(_ sector: Int, _ offset: Int) -> UInt32 {
            DVDVideoIFORelinker.readUInt32BE(bytes, at: sector * 2048 + 0x04F1 + offset)
        }
        let none: UInt32 = 0x3FFF_FFFF
        // The middle VOBU: one VOBU each way.
        XCTAssertEqual(entry(2, 0), 0x8000_0003)    // FWDI Video
        XCTAssertEqual(entry(2, 4), none)           // FWDI 240
        XCTAssertEqual(entry(2, 72), none)          // FWDI 2
        XCTAssertEqual(entry(2, 76), 0x8000_0003)   // FWDI 1
        XCTAssertEqual(entry(2, 80), 0x8000_0003)   // FWDI Next
        XCTAssertEqual(entry(2, 84), 0x8000_0002)   // BWDI Prev
        XCTAssertEqual(entry(2, 88), 0x8000_0002)   // BWDI 1
        XCTAssertEqual(entry(2, 92), none)          // BWDI 2
        XCTAssertEqual(entry(2, 160), none)         // BWDI 240
        XCTAssertEqual(entry(2, 164), 0x8000_0002)  // BWDI Video
        // The first VOBU reaches two VOBUs ahead with FWDI 2.
        XCTAssertEqual(entry(0, 72), 0x8000_0005)
        XCTAssertEqual(entry(0, 84), none)
        // The last VOBU reaches two back with BWDI 2.
        XCTAssertEqual(entry(5, 92), 0x8000_0005)
        XCTAssertEqual(entry(5, 80), none)
    }

    /// A relinked cell is seamless on one clock (seamless_play 0x08 set, STC discontinuity 0x02
    /// clear) and its last-VOBU address is the start of its last VOBU, not its first.
    func testRelinkedCellPlaybackFlagsAndLastVOBU() {
        var ifo = [UInt8](repeating: 0, count: 3 * 2048)
        DVDVideoIFORelinker.writeUInt32BE(1, into: &ifo, at: 0x00CC)    // VTS_PGCITI at sector 1
        DVDVideoIFORelinker.writeUInt32BE(2, into: &ifo, at: 0x00E0)    // VTS_C_ADT at sector 2
        let table = 2048, pgc = table + 16
        DVDVideoIFORelinker.writeUInt16BE(1, into: &ifo, at: table)
        DVDVideoIFORelinker.writeUInt32BE(16, into: &ifo, at: table + 8 + 4)
        ifo[pgc + 3] = 1
        DVDVideoIFORelinker.writeUInt16BE(0xEC, into: &ifo, at: pgc + 0xE8)
        DVDVideoIFORelinker.writeUInt16BE(0xEC + 24, into: &ifo, at: pgc + 0xEA)
        ifo[pgc + 0xEC] = 0x02                                         // not seamless, STC discontinuity
        DVDVideoIFORelinker.writeUInt16BE(1, into: &ifo, at: pgc + 0xEC + 24)
        ifo[pgc + 0xEC + 24 + 3] = 1
        let cell = DVDVideoRelinkedCellRange(vobID: 1, cellID: 1, startSector: 0, endSector: 6)
        let out = [UInt8](DVDVideoIFORelinker.relinkVTSIFO(ifoData: Data(ifo), menuVobSectors: 0, titleVobSectors: 7,
                                                            vobuStartSectors: [0, 2, 5], cells: [cell]))
        let playback = pgc + 0xEC
        XCTAssertEqual(out[playback], 0x08)
        XCTAssertEqual(DVDVideoIFORelinker.readUInt32BE(out, at: playback + 0x08), 0)
        XCTAssertEqual(DVDVideoIFORelinker.readUInt32BE(out, at: playback + 0x10), 5)
        XCTAssertEqual(DVDVideoIFORelinker.readUInt32BE(out, at: playback + 0x14), 6)
    }
}
