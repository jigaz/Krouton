#if canImport(XCTest)
import XCTest
#endif
import Foundation
@testable import OpticalCore

// MARK: - Fixtures

/// A record shaped like a project's lists: disc metadata needs its disc number.
private struct Shelf: Codable, Equatable {
    var discs: [KroutonDiscVolumeMetadata]
    var medium: KroutonSpanningDiscMedium
    var savedAt: Date
}

private func object<T: Encodable>(_ value: T) throws -> [String: Any] {
    try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(value)) as? [String: Any])
}

private func data(_ object: Any) throws -> Data {
    try JSONSerialization.data(withJSONObject: object)
}

// MARK: - Tests

final class PersistedJSONTests: XCTestCase {
    func testAFileThisVersionWroteReadsAsSavedWithNoRepairs() throws {
        var spec = KroutonEmbeddedLabelSpec(primaryArcTitle: "LIVE AT THE ROXY")
        spec.backgroundStyle = .gpuKaleidoscope
        spec.textElements = [KroutonLabelTextElement(text: "SIDE A")]
        let read = try KroutonPersistedJSON.decode(KroutonEmbeddedLabelSpec.self, from: JSONEncoder().encode(spec))
        XCTAssertEqual(read.value, spec)
        XCTAssertTrue(read.repairs.isEmpty)
    }

    func testFieldsAnOlderFileLacksTakeTheirDefaults() throws {
        var saved = try object(KroutonEmbeddedLabelSpec(primaryArcTitle: "OLD MIX"))
        for key in ["backgroundStyle", "kaleidoscopeFacetCount", "textElements", "bgAdjustments", "topArcRadiusMM"] {
            saved.removeValue(forKey: key)
        }
        let read = try KroutonPersistedJSON.decode(KroutonEmbeddedLabelSpec.self, from: data(saved))
        let fresh = KroutonEmbeddedLabelSpec()
        XCTAssertEqual(read.value.primaryArcTitle, "OLD MIX")
        XCTAssertEqual(read.value.backgroundStyle, fresh.backgroundStyle)
        XCTAssertEqual(read.value.kaleidoscopeFacetCount, fresh.kaleidoscopeFacetCount)
        XCTAssertEqual(read.value.textElements, [])
        XCTAssertEqual(read.value.bgAdjustments, fresh.bgAdjustments)
        XCTAssertEqual(read.value.topArcRadiusMM, fresh.topArcRadiusMM)
        XCTAssertEqual(read.repairs.count, 5)
    }

    func testAChoiceFromANewerVersionFallsBackAndTheRestIsKept() throws {
        var saved = try object(KroutonEmbeddedLabelSpec(performer: "The Kroutons"))
        saved["backgroundStyle"] = "Holographic Swirl"
        saved["gpuSeedPattern"] = 7
        let read = try KroutonPersistedJSON.decode(KroutonEmbeddedLabelSpec.self, from: data(saved))
        XCTAssertEqual(read.value.backgroundStyle, .templateDefault)
        XCTAssertEqual(read.value.gpuSeedPattern, .neonLaserPrism)
        XCTAssertEqual(read.value.performer, "The Kroutons")
        XCTAssertEqual(read.repairs.count, 2)
    }

    func testAnUnreadableListElementIsLeftOutAndTheOthersKept() throws {
        var spec = KroutonEmbeddedLabelSpec()
        spec.textElements = [KroutonLabelTextElement(text: "ONE"), KroutonLabelTextElement(text: "TWO")]
        var saved = try object(spec)
        var elements = try XCTUnwrap(saved["textElements"] as? [Any])
        elements.insert(42, at: 1)
        saved["textElements"] = elements
        let read = try KroutonPersistedJSON.decode(KroutonEmbeddedLabelSpec.self, from: data(saved))
        XCTAssertEqual(read.value.textElements.map(\.text), ["ONE", "TWO"])
        XCTAssertTrue(read.repairs.contains { $0.hasPrefix(".textElements[1]") && $0.hasSuffix("left out") })
    }

    func testAMistypedFieldTakesTheDefaultAndAnUnreadableOptionalIsEmpty() throws {
        var spec = KroutonEmbeddedLabelSpec()
        spec.planet = KroutonPlanetSettings()
        var saved = try object(spec)
        saved["kaleidoscopeFacetCount"] = 6.5
        saved["showTracklistOnDisc"] = "yes"
        saved["planet"] = "round"
        let read = try KroutonPersistedJSON.decode(KroutonEmbeddedLabelSpec.self, from: data(saved))
        XCTAssertEqual(read.value.kaleidoscopeFacetCount, 8)
        XCTAssertTrue(read.value.showTracklistOnDisc)
        XCTAssertTrue(read.value.planet == nil)
    }

    func testARecordMissingARequiredFieldIsLeftOutAndAMissingIDIsNew() throws {
        let shelf = Shelf(discs: [KroutonDiscVolumeMetadata(discNumber: 2, title: "B"), KroutonDiscVolumeMetadata(discNumber: 3, title: "C")],
                          medium: .dvd5Single, savedAt: Date(timeIntervalSinceReferenceDate: 1_000))
        var saved = try object(shelf)
        var discs = try XCTUnwrap(saved["discs"] as? [[String: Any]])
        discs[0].removeValue(forKey: "discNumber")
        discs[1].removeValue(forKey: "writeCDText")
        saved["discs"] = discs
        let read = try KroutonPersistedJSON.decode(Shelf.self, from: data(saved))
        XCTAssertEqual(read.value.discs.map(\.title), ["C"])
        XCTAssertTrue(read.value.discs[0].writeCDText)
        XCTAssertEqual(read.value.medium, .dvd5Single)
        XCTAssertEqual(read.value.savedAt, shelf.savedAt)

        var element = try object(KroutonLabelTextElement(text: "NO ID"))
        element.removeValue(forKey: "id")
        let first = try KroutonPersistedJSON.decode(KroutonLabelTextElement.self, from: data(element)).value
        let second = try KroutonPersistedJSON.decode(KroutonLabelTextElement.self, from: data(element)).value
        XCTAssertEqual(first.text, "NO ID")
        XCTAssertNotEqual(first.id, second.id)
    }

    func testISO8601DatesAndWholeNumbersFollowJSONDecoder() throws {
        let json = #"{"discs":[],"medium":"BD-R 25 GB Single-Layer","savedAt":"2026-11-27T09:30:00Z","extra":true}"#
        let read = try KroutonPersistedJSON.decode(Shelf.self, from: Data(json.utf8), iso8601Dates: true)
        XCTAssertEqual(read.value.medium, .bd25Single)
        XCTAssertEqual(read.value.savedAt, ISO8601DateFormatter().date(from: "2026-11-27T09:30:00Z"))
        XCTAssertTrue(read.repairs.isEmpty)
    }

    func testSomethingThatIsntJSONStillFails() {
        XCTAssertThrowsError(try KroutonPersistedJSON.decode(Shelf.self, from: Data("not a project".utf8)))
        // A list where an object belongs can't be repaired: the whole read fails, as before.
        XCTAssertThrowsError(try KroutonPersistedJSON.decode(Shelf.self, from: Data("[1, 2]".utf8)))
    }
}
