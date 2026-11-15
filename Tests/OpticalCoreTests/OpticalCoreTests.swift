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

final class OpticalCoreTests: XCTestCase {
    func testSpanManifestVolumeLabelSuffixes() {
        let longTitle = "THE_COMPLETE_LIVE_RECORDINGS_AT_OAKLAND_AUDITORIUM_1976"
        let d1 = SpanManifest.volumeLabel(base: longTitle, discIndex: 1, discCount: 3, limit: 32)
        let d2 = SpanManifest.volumeLabel(base: longTitle, discIndex: 2, discCount: 3, limit: 32)
        XCTAssertEqual(d1.count, 32)
        XCTAssertNotEqual(d1, d2)
        XCTAssertTrue(d1.hasSuffix("_D01"))
        XCTAssertTrue(d2.hasSuffix("_D02"))
    }

    func testDomainIdentitySubsystemsAndUTIs() {
        XCTAssertEqual(KroutonDomainIdentity.domainName, "krouton.app")
        XCTAssertEqual(KroutonDomainIdentity.reverseDNSPrefix, "app.krouton")
        XCTAssertEqual(KroutonDomainIdentity.Module.allCases.count, 11)
        XCTAssertEqual(KroutonDomainIdentity.Module.driveKit.subsystem, "app.krouton.drivekit")
        XCTAssertEqual(KroutonDomainIdentity.UTI.burnSet.rawValue, "app.krouton.burnset")
        XCTAssertTrue(KroutonDomainIdentity.sessionVaultDirectory().path.contains("app.krouton"))
    }
}
