#if canImport(XCTest)
import XCTest
#endif
import Foundation
@testable import ImageKit

final class HFSImageWriterTests: XCTestCase {
    /// 600 files with 31-character names fill three to a catalog leaf, and the index nodes above
    /// them took the tree past the old `records / 3 + 16` node estimate, so the build failed
    /// with "too many files and folders" on an ordinary CD.
    func testSixHundredLongNamesFitTheCatalog() throws {
        let base = FileManager.default.temporaryDirectory.appendingPathComponent("HFSWriter_\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: base) }
        let tree = base.appendingPathComponent("tree")
        try FileManager.default.createDirectory(at: tree, withIntermediateDirectories: true)
        for i in 0..<600 {
            let name = "Photograph from the trip " + String(100_000 + i)
            XCTAssertEqual(name.count, 31)
            try Data([UInt8(i & 0xFF)]).write(to: tree.appendingPathComponent(name))
        }
        let built = try KroutonHFSImageWriter.build(folder: tree, output: base.appendingPathComponent("disc.cdr"), label: "Trip",
                                                     now: Date(timeIntervalSince1970: 1_795_000_000),
                                                     timeZone: TimeZone(identifier: "UTC")!)
        XCTAssertEqual(built.files, 600)
    }

    func testNodesNeededIsTheLeastNodeCountBuildAccepts() throws {
        let name = [UInt8](repeating: UInt8(ascii: "a"), count: 31)
        let records = (0..<600).map { _ in KroutonHFSBTree.Record(parent: 2, name: name, data: [UInt8](repeating: 0, count: 102)) }
        let needed = KroutonHFSBTree.nodesNeeded(records: records)
        XCTAssertGreaterThan(needed, 600 / 3 + 16)
        let tree = try KroutonHFSBTree.build(records: records, maxKeyLength: 37, nodeCount: needed)
        XCTAssertEqual(tree.count, needed * KroutonHFSBTree.nodeSize)
        var rejected = false
        do { _ = try KroutonHFSBTree.build(records: records, maxKeyLength: 37, nodeCount: needed - 1) } catch { rejected = true }
        XCTAssertTrue(rejected)
    }
}
