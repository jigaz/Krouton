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
@testable import AudioKit

final class AudioKitTests: XCTestCase {
    func testMultiDiscAudioPlanRestoresSuppressedCrossfade() {
        var proj = AudioProject(albumTitle: "CONCERT", albumPerformer: "BAND")
        proj.targetDiscMedium = .cd80Min700MB
        let _ = proj.append((1...16).map { URL(fileURLWithPath: "/tmp/t\($0).wav") })
        for i in 0..<16 {
            let tid = proj.tracks[i].id
            proj.update(tid) {
                $0.frameCount = (i == 15) ? 30_000 : 22_500
                if i == 14 {
                    $0.transitionToNext = KroutonTrackTransitionSpec(overlapSeconds: 4.0, preGapSeconds: 0.0)
                }
            }
        }
        let spanned = proj.discPlan()
        XCTAssertEqual(spanned.discs.count, 2)

        proj.remove(proj.tracks[0].id)
        proj.remove(proj.tracks[0].id)
        let collapsed = proj.discPlan()
        XCTAssertEqual(collapsed.discs.count, 1)
        XCTAssertEqual(collapsed.discs[0].layout?.last?.overlapWithPrevious, 300)
    }
}
