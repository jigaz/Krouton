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
}
