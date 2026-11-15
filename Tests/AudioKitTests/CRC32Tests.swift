#if canImport(XCTest)
import XCTest
#endif
import Foundation
import AudioKit

final class CRC32Tests: XCTestCase {
    func testStandardCheckValue() {
        XCTAssertEqual(KroutonCRC32.checksum(of: Array("123456789".utf8)), 0xCBF4_3926)
    }

    func testEmptyInputIsZero() {
        XCTAssertEqual(KroutonCRC32.checksum(of: [UInt8]()), 0)
    }

    func testIncrementalUpdateMatchesOneShot() {
        let bytes = (0..<4096).map { UInt8(truncatingIfNeeded: $0 &* 37 &+ 11) }
        var crc = KroutonCRC32.initialValue
        for byte in bytes { crc = KroutonCRC32.update(crc, byte) }
        XCTAssertEqual(~crc, KroutonCRC32.checksum(of: bytes))
    }

    func testSingleBitChangeChangesTheChecksum() {
        var bytes = [UInt8](repeating: 0xA5, count: 2352)
        let before = KroutonCRC32.checksum(of: bytes)
        bytes[1000] ^= 0x01
        XCTAssertNotEqual(before, KroutonCRC32.checksum(of: bytes))
    }
}
