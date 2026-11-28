#if canImport(XCTest)
import XCTest
#endif
import Foundation
@testable import ImageKit

final class DiscImageDepotTests: XCTestCase {
    /// 147 sectors of 2048 bytes is also 128 × 2352: without a sync pattern it is an ISO and is
    /// copied as it is, not cut into "raw" sectors.
    func testISOWhoseSizeDividesBy2352IsCopiedUnchanged() throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("DepotISO_\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }
        let source = dir.appendingPathComponent("plain.bin")
        let iso = Data((0..<(147 * 2048)).map { UInt8(truncatingIfNeeded: $0 &* 31 &+ 7) })
        XCTAssertEqual(iso.count % 2352, 0)
        try iso.write(to: source)
        let output = dir.appendingPathComponent("plain.iso")
        let written = try DiscImageDepotOperations.extractRawBinToISO(sourceURL: source, outputISOURL: output)
        XCTAssertEqual(written, Int64(iso.count))
        XCTAssertEqual(try Data(contentsOf: output), iso)
    }
}
