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
@testable import ImageKit

final class ImageKitTests: XCTestCase {
    func testHybridDataLBAPlanner() {
        let entry = KroutonLoafFileEntry(
            url: URL(fileURLWithPath: "/tmp/readme.txt"),
            name: "readme.txt",
            isDirectory: false,
            byteSize: 4096,
            itemCount: 1,
            posixPermissions: "rw-r--r--",
            modifiedDate: Date()
        )
        let plan = KroutonTartineModule.planHybridDataLayout(
            volumeLabel: "KROUTON_DATA",
            entries: [entry],
            isElToritoBootable: false
        )
        XCTAssertEqual(plan.pvdSectorLBA, 16)
    }
}
