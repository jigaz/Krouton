#if canImport(XCTest)
import XCTest
#endif
import Foundation
import DriveKit

final class DriveBurnPreflightTests: XCTestCase {
    // MARK: - Drive identifiers

    func testUniqueDriveKeepsItsSavedIdentifier() {
        let ids = KroutonDriveIdentity.uniqueIDs(
            baseIDs: ["PIONEER-BD-RW BDR-XD08-1.02", "HL-DT-ST-DVDRAM GP65NB60-RF01"],
            registryPaths: ["IOService:/usb/port2", "IOService:/usb/port1"]
        )
        XCTAssertEqual(ids, ["PIONEER-BD-RW BDR-XD08-1.02", "HL-DT-ST-DVDRAM GP65NB60-RF01"])
    }

    func testIdenticalDrivesGetDistinctIdentifiersOrderedByPort() {
        let base = "PIONEER-BD-RW BDR-XD08-1.02"
        let ids = KroutonDriveIdentity.uniqueIDs(
            baseIDs: [base, base, base],
            registryPaths: ["IOService:/usb/port3", "IOService:/usb/port1", "IOService:/usb/port2"]
        )
        XCTAssertEqual(ids, ["\(base)#3", base, "\(base)#2"])
        XCTAssertEqual(Set(ids).count, 3)
    }

    func testIdentifiersDoNotDependOnEnumerationOrder() {
        let base = "PLEXTOR-PX-716A-1.11"
        let forward = KroutonDriveIdentity.uniqueIDs(baseIDs: [base, base], registryPaths: ["a", "b"])
        let reversed = KroutonDriveIdentity.uniqueIDs(baseIDs: [base, base], registryPaths: ["b", "a"])
        XCTAssertEqual(forward, [base, "\(base)#2"])
        XCTAssertEqual(reversed, ["\(base)#2", base])
    }

    // MARK: - Overwrite policy

    func testBlankDiscNeverNeedsOverwrite() {
        let decision = KroutonBurnMediaPolicy.evaluate(
            isBlank: true, isErasable: true, isOverwritable: false, isAppendable: true, allowOverwrite: false
        )
        XCTAssertEqual(decision, .proceed(overwriteExistingData: false))
    }

    func testWrittenRewritableIsRefusedUnlessAPersonStartedTheBurn() {
        let unattended = KroutonBurnMediaPolicy.evaluate(
            isBlank: false, isErasable: true, isOverwritable: false, isAppendable: false, allowOverwrite: false
        )
        XCTAssertEqual(unattended, .refuseWouldDestroyData)

        let byHand = KroutonBurnMediaPolicy.evaluate(
            isBlank: false, isErasable: true, isOverwritable: false, isAppendable: false, allowOverwrite: true
        )
        XCTAssertEqual(byHand, .proceed(overwriteExistingData: true))
    }

    func testFormattedOverwritableMediaCountsAsHoldingData() {
        let decision = KroutonBurnMediaPolicy.evaluate(
            isBlank: false, isErasable: false, isOverwritable: true, isAppendable: false, allowOverwrite: false
        )
        XCTAssertEqual(decision, .refuseWouldDestroyData)
    }

    func testOpenWriteOnceDiscAppendsWithoutOverwrite() {
        let decision = KroutonBurnMediaPolicy.evaluate(
            isBlank: false, isErasable: false, isOverwritable: false, isAppendable: true, allowOverwrite: true
        )
        XCTAssertEqual(decision, .proceed(overwriteExistingData: false))
    }

    func testClosedWriteOnceDiscIsRefused() {
        let decision = KroutonBurnMediaPolicy.evaluate(
            isBlank: false, isErasable: false, isOverwritable: false, isAppendable: false, allowOverwrite: true
        )
        XCTAssertEqual(decision, .refuseNotWritable)
    }

    // MARK: - Staging

    func testStagingCopiesItemsAndRejectsDuplicateNames() async throws {
        let fm = FileManager.default
        let tmp = fm.temporaryDirectory.appendingPathComponent("DriveBurnPreflightTests_\(UUID().uuidString)")
        defer { try? fm.removeItem(at: tmp) }
        try fm.createDirectory(at: tmp, withIntermediateDirectories: true)
        let source = tmp.appendingPathComponent("source.txt")
        try Data("payload".utf8).write(to: source)

        let goodStage = tmp.appendingPathComponent("stage-ok")
        let ok = await KroutonBurnStager.stage(
            [KroutonBurnStageItem(source: source, name: "One.txt"), KroutonBurnStageItem(source: source, name: "Two.txt")],
            into: goodStage
        )
        XCTAssertTrue(ok == nil)
        XCTAssertTrue(fm.fileExists(atPath: goodStage.appendingPathComponent("One.txt").path))
        XCTAssertTrue(fm.fileExists(atPath: goodStage.appendingPathComponent("Two.txt").path))

        let clash = await KroutonBurnStager.stage(
            [KroutonBurnStageItem(source: source, name: "Notes.txt"), KroutonBurnStageItem(source: source, name: "NOTES.TXT")],
            into: tmp.appendingPathComponent("stage-clash")
        )
        XCTAssertTrue(clash != nil)

        let missing = await KroutonBurnStager.stage(
            [KroutonBurnStageItem(source: tmp.appendingPathComponent("gone.bin"), name: "gone.bin")],
            into: tmp.appendingPathComponent("stage-missing")
        )
        XCTAssertTrue(missing != nil)
    }
}
