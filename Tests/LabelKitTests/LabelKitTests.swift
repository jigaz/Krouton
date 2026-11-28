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
@testable import LabelKit

final class LabelKitTests: XCTestCase {
    func testPolar300DPILayoutAndGlyphArc() {
        XCTAssertEqual(KroutonDiscHubGeometry.fullFace120mmHub22mm.canvasPixelDimension(dpi: 300.0), 1417)
        let glyphs = KroutonLabelGeometryEngine.computePolarArcGlyphLayout(
            text: "KROUTON",
            centerX: 180.0,
            centerY: 180.0,
            radiusPoints: 130.0
        )
        XCTAssertEqual(glyphs.count, 7)
    }

    func testAutoLabelSummaryAndRimClaimOnlyWhatIsApplied() async {
        let composed = await AutoLabelComposer.compose(
            albumTitle: "Summer Tapes", albumPerformer: "The Band", formatBadge: "cd-da",
            items: [AutoLabelInputItem(url: nil, title: "One"), AutoLabelInputItem(url: nil, title: "Two")])
        XCTAssertFalse(composed.rimBannerText.contains("KROUTON"))
        XCTAssertTrue(composed.rimBannerText.hasPrefix("SUMMER TAPES"))
        XCTAssertFalse(composed.summary.contains("Vision"))
        XCTAssertFalse(composed.summary.contains("artwork"))
        XCTAssertTrue(composed.summary.contains("title and subtitle"))
    }
}
