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
@testable import Persistence

final class PersistenceTests: XCTestCase {
    func testRunLockCrashDetectionLifecycle() throws {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("PersistTest_\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: dir) }

        let first = try RunLock.acquire(in: dir)
        XCTAssertEqual(first.verdict, .clean)
        first.lock?.markCleanExit()

        let second = try RunLock.acquire(in: dir)
        XCTAssertEqual(second.verdict, .clean)
        second.lock?.markCleanExit()
    }
}
