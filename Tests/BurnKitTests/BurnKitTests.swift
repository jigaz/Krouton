#if canImport(XCTest)
import XCTest
#else
import Foundation
open class XCTestCase { public init() {} }
public func XCTAssertEqual<T: Equatable>(_ a: T, _ b: T) { precondition(a == b) }
public func XCTAssertNotEqual<T: Equatable>(_ a: T, _ b: T) { precondition(a != b) }
public func XCTAssertTrue(_ cond: Bool) { precondition(cond) }
public func XCTAssertFalse(_ cond: Bool) { precondition(!cond) }
public func XCTAssertGreaterThan<T: Comparable>(_ a: T, _ b: T) { precondition(a > b) }
public func XCTAssertGreaterThanOrEqual<T: Comparable>(_ a: T, _ b: T) { precondition(a >= b) }
public func XCTAssertLessThan<T: Comparable>(_ a: T, _ b: T) { precondition(a < b) }
#endif
@testable import OpticalCore
@testable import BurnKit

final class BurnKitTests: XCTestCase {
    func testSinglePassStagerAndReplayStateMachine() throws {
        let tmp = FileManager.default.temporaryDirectory.appendingPathComponent("BurnKitTests_\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: tmp) }
        try FileManager.default.createDirectory(at: tmp, withIntermediateDirectories: true)

        let f1 = tmp.appendingPathComponent("Track 100%.wav")
        try Data("PAYLOAD_100".utf8).write(to: f1)

        let res = try BurnSetStager.freezeAndStageSet(
            title: "TEST_ARCHIVE_SET",
            discs: [[StagedInputFile(sourceURL: f1, relativePathOnDisc: "Audio/Track 100%.wav")]],
            stagingRootDirectory: tmp,
            manifestMode: .bagItRFC8493
        )
        XCTAssertEqual(res.burnSet.discs.count, 1)

        let tags = try SpanManifest.tagFiles(for: 1, in: res.setIndex)
        let manifest = String(data: tags["manifest-sha256.txt"] ?? Data(), encoding: .utf8) ?? ""
        XCTAssertTrue(manifest.contains("data/Audio/Track 100%25.wav"))
    }
}
