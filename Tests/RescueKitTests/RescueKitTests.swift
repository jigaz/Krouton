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
@testable import RescueKit

final class RescueKitTests: XCTestCase {
    func testBadSectorRescueDecisionAndArchivalGrade() {
        let retry = KroutonRescueEngine.evaluateSectorRescue(
            lba: 12_000,
            c2ErrorCount: 4,
            retryAttempt: 1,
            maxRetries: 5,
            fastSkipStepLBA: 16
        )
        XCTAssertEqual(retry.action, .downshiftRetry2xCLV)

        let cert = KroutonRescueEngine.evaluateArchivalDiscGrade(
            driveModel: "PIONEER BDR-S13U",
            mediaType: "M-DISC BD-R SL",
            sectorsWrittenLBA: 250_000,
            c1Rate: 0.8,
            c2Count: 0,
            jitterPercent: 6.1
        )
        XCTAssertFalse(String(describing: cert).isEmpty)
    }
}
