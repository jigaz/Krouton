#if canImport(XCTest)
import XCTest
#endif
import Foundation
import DriveKit

final class DiscImageArgumentsTests: XCTestCase {
    func testISOOutputBuildsAHybridWithUDF() {
        let args = KroutonDiscImageArguments.make(
            outputPath: "/Users/me/Desktop/Backup.ISO", sourcePath: "/tmp/Stage Tree", volumeTitle: "My Backup", compress: true
        )
        XCTAssertEqual(args.first ?? "", "makehybrid")
        for flag in ["-iso", "-joliet", "-udf", "-hfs"] {
            XCTAssertTrue(args.contains(flag))
        }
        XCTAssertEqual(args.last ?? "", "/tmp/Stage Tree")
        XCTAssertEqual(args[(args.firstIndex(of: "-default-volume-name") ?? 0) + 1], "My Backup")
        XCTAssertEqual(args[(args.firstIndex(of: "-o") ?? 0) + 1], "/Users/me/Desktop/Backup.ISO")
    }

    func testCDROutputIsAlsoAnOpticalImage() {
        XCTAssertTrue(KroutonDiscImageArguments.isOpticalImage(outputPath: "/tmp/disc.cdr"))
        XCTAssertFalse(KroutonDiscImageArguments.isOpticalImage(outputPath: "/tmp/disc.dmg"))
    }

    func testDMGOutputHonoursCompression() {
        let compressed = KroutonDiscImageArguments.make(outputPath: "/tmp/a.dmg", sourcePath: "/tmp/s", volumeTitle: "V", compress: true)
        let plain = KroutonDiscImageArguments.make(outputPath: "/tmp/a.dmg", sourcePath: "/tmp/s", volumeTitle: "V", compress: false)
        XCTAssertEqual(compressed.first ?? "", "create")
        XCTAssertEqual(compressed[(compressed.firstIndex(of: "-format") ?? 0) + 1], "UDZO")
        XCTAssertEqual(plain[(plain.firstIndex(of: "-format") ?? 0) + 1], "UDRW")
        XCTAssertEqual(compressed.last ?? "", "/tmp/a.dmg")
    }
}
