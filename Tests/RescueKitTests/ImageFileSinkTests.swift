#if canImport(XCTest)
import XCTest
#endif
import Foundation
import RescueKit

final class ImageFileSinkTests: XCTestCase {
    private func scratchURL() -> URL {
        FileManager.default.temporaryDirectory.appendingPathComponent("krouton-sink-\(UUID().uuidString).iso")
    }

    /// A fresh rescue over an older image of the same name must not leave that image's bytes in
    /// the sectors it never reads.
    func testFreshRescueEmptiesAnOlderImage() throws {
        let url = scratchURL()
        defer { try? FileManager.default.removeItem(at: url) }
        try Data(repeating: 0xAB, count: 8192).write(to: url)

        let sink = try KroutonImageFileSink(url: url, totalBytes: 8192, keepingExistingData: false)
        try sink.write([UInt8](repeating: 0x11, count: 2048), atByte: 0)
        try sink.close()

        let bytes = try Data(contentsOf: url)
        XCTAssertEqual(bytes.count, 8192)
        XCTAssertTrue(bytes.prefix(2048).allSatisfy { $0 == 0x11 })
        XCTAssertTrue(bytes.dropFirst(2048).allSatisfy { $0 == 0 })
    }

    /// Resuming keeps what the earlier attempt copied.
    func testResumedRescueKeepsTheImage() throws {
        let url = scratchURL()
        defer { try? FileManager.default.removeItem(at: url) }
        try Data(repeating: 0xAB, count: 8192).write(to: url)

        let sink = try KroutonImageFileSink(url: url, totalBytes: 8192)
        try sink.write([UInt8](repeating: 0x11, count: 2048), atByte: 2048)
        try sink.close()

        let bytes = try Data(contentsOf: url)
        XCTAssertEqual(bytes.count, 8192)
        XCTAssertTrue(bytes.prefix(2048).allSatisfy { $0 == 0xAB })
        XCTAssertTrue(bytes.dropFirst(2048).prefix(2048).allSatisfy { $0 == 0x11 })
    }
}
