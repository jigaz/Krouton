#if canImport(XCTest)
import XCTest
#endif
import Foundation
import OpticalCore

/// The main window's column sizes. Suite 39 compares them with the flags they replaced; these
/// pin the edges of each breakpoint.
final class WindowLayoutTests: XCTestCase {
    func testFirstLayoutUsesTheStartingBreakpoint() {
        let narrow = KroutonWindowLayout.forWidths(sidebar: 214, workspace: 519, queue: 354, previous: nil)
        XCTAssertEqual(narrow, KroutonWindowLayout(sidebar: .narrow, workspace: .narrow, queue: .narrow))
        let regular = KroutonWindowLayout.forWidths(sidebar: 215, workspace: 520, queue: 355, previous: nil)
        XCTAssertEqual(regular, .regular)
    }

    func testRegularTurnsNarrowOnlyBelowTheLowerEdge() {
        let b = KroutonWindowLayout.workspaceBreakpoint
        XCTAssertEqual(b.size(forWidth: 510, previous: .regular), .regular)
        XCTAssertEqual(b.size(forWidth: 509.5, previous: .regular), .narrow)
    }

    func testNarrowTurnsRegularOnlyAboveTheUpperEdge() {
        let b = KroutonWindowLayout.workspaceBreakpoint
        XCTAssertEqual(b.size(forWidth: 535, previous: .narrow), .narrow)
        XCTAssertEqual(b.size(forWidth: 535.5, previous: .narrow), .regular)
    }

    func testColumnsAreIndependent() {
        let start = KroutonWindowLayout.regular
        let next = KroutonWindowLayout.forWidths(sidebar: 300, workspace: 700, queue: 300, previous: start)
        XCTAssertEqual(next, KroutonWindowLayout(sidebar: .regular, workspace: .regular, queue: .narrow))
    }

    func testEveryGapIsAboveItsLowerEdge() {
        for b in [KroutonWindowLayout.sidebarBreakpoint, .workspaceBreakpoint, .queueBreakpoint] {
            XCTAssertTrue(b.regularAbove > b.narrowBelow)
            XCTAssertTrue(b.startsNarrowBelow >= b.narrowBelow && b.startsNarrowBelow <= b.regularAbove)
        }
    }
}
