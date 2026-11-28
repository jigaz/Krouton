#if canImport(XCTest)
import XCTest
#endif
import Foundation
import RescueKit

final class ArchivalGradeTests: XCTestCase {
    func testNoMeasurementsMeansNoGrade() {
        let cert = KroutonRescueEngine.evaluateArchivalDiscGrade(driveModel: "PIONEER BDR-XD08", mediaType: "BD-R", sectorsWrittenLBA: 1000)
        XCTAssertEqual(cert.gradeBadge, "NOT MEASURED")
        XCTAssertTrue(cert.certificateText.contains("NOT MEASURED"))
        XCTAssertFalse(cert.certificateText.contains("ARCHIVAL MASTER"))
        XCTAssertFalse(cert.certificateText.contains("Compliant"))
    }

    func testPartialMeasurementsAlsoMeanNoGrade() {
        let cert = KroutonRescueEngine.evaluateArchivalDiscGrade(
            driveModel: "D", mediaType: "M", sectorsWrittenLBA: 1, c1Rate: 0.5, c2Count: nil, jitterPercent: 5.0
        )
        XCTAssertEqual(cert.gradeBadge, "NOT MEASURED")
    }

    func testRealMeasurementsStillGrade() {
        let cert = KroutonRescueEngine.evaluateArchivalDiscGrade(
            driveModel: "D", mediaType: "M", sectorsWrittenLBA: 1, c1Rate: 0.8, c2Count: 0, jitterPercent: 6.1
        )
        XCTAssertEqual(cert.gradeBadge, "A+ ARCHIVAL MASTER")
        // Nothing checked the grade against a standard, so the certificate claims none.
        XCTAssertFalse(cert.certificateText.contains("Compliant"))
        XCTAssertFalse(cert.certificateText.contains("ISO/IEC"))
        XCTAssertFalse(cert.certificateText.contains("ECMA"))
    }
}
