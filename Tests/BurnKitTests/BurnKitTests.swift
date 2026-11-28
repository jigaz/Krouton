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

// MARK: - Burn Event Journal

final class BurnEventJournalTests: XCTestCase {
    /// A crash mid-append leaves a last line without its newline. The next event used to be
    /// written onto that line, so neither decoded and the event (often the `.interrupted`
    /// failure recorded at the next launch) was lost.
    func testAnEventAfterATornLineIsKept() async throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent("BurnEventJournal_\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }
        let journal = BurnEventJournal(directory: folder)
        let set = BurnSetID()
        try await journal.append(.attemptSucceeded(set: set, disc: 1, attempt: 1, at: Date(timeIntervalSince1970: 0)))
        let file = folder.appendingPathComponent("burn-set-events.jsonl")
        let handle = try FileHandle(forWritingTo: file)
        try handle.seekToEnd()
        try handle.write(contentsOf: Data("{\"attemptFailed\":{\"set\"".utf8)) // torn, no newline
        try handle.close()

        let failed = BurnEvent.attemptFailed(set: set, disc: 2, attempt: 1, failure: .interrupted, at: Date(timeIntervalSince1970: 60))
        try await journal.append(failed)
        let events = await journal.readAll()
        XCTAssertEqual(events.count, 2)
        XCTAssertEqual(events.last, failed)
    }
}
