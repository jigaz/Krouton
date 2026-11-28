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
    func testCDExtraLayoutCountsTheSecondSession() {
        XCTAssertEqual(KroutonCDExtraLayout.sessionOverheadFrames, 13_650)
        // 70 minutes of audio and 50 MB of data fit an 80-minute blank; 79 minutes and 50 MB don't.
        XCTAssertTrue(KroutonCDExtraLayout.overflowMessage(audioFrames: 70 * 60 * 75, dataBytes: 50_000_000, capacityFrames: 360_000) == nil)
        XCTAssertFalse(KroutonCDExtraLayout.overflowMessage(audioFrames: 79 * 60 * 75, dataBytes: 50_000_000, capacityFrames: 360_000) == nil)
        XCTAssertEqual(KroutonCDExtraLayout.dataSectors(forBytes: 0), 512)
    }

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

/// Format names describe only what Krouton writes: no Rock Ridge tree, no UDF 2.60 (the writer
/// does 2.50), and no lifetime promises.
final class WorkflowCatalogClaimsTests: XCTestCase {
    func testDisplayTextClaimsNothingTheWritersDontDo() {
        for spec in KroutonOpticalWorkflowCatalog.defaultFormats {
            let text = "\(spec.technicalName) \(spec.colloquialName) \(spec.bookOrFileSystem)"
            XCTAssertFalse(text.contains("Rock Ridge"))
            XCTAssertFalse(text.contains("UDF 2.60"))
            XCTAssertFalse(text.contains("1,000-Year"))
        }
    }
}
