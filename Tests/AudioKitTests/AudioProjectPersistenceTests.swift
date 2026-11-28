#if canImport(XCTest)
import XCTest
#endif
import Foundation
import AudioKit
import OpticalCore

final class AudioProjectPersistenceTests: XCTestCase {
    /// An album saved by another version keeps its tracks; only a track without its file is
    /// left out, and settings the file lacks take a new project's values.
    func testAnOlderAlbumOpensWithoutTheTrackItCantPlace() throws {
        var project = AudioProject(albumTitle: "Night Drive", writeCDText: false)
        project.targetDiscMedium = .cd74Min650MB
        _ = project.append(["one.flac", "two.flac", "three.flac"].map { URL(fileURLWithPath: "/Music/\($0)") })

        var saved = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(project)) as? [String: Any])
        var tracks = try XCTUnwrap(saved["tracks"] as? [[String: Any]])
        tracks[1].removeValue(forKey: "source")
        tracks[2].removeValue(forKey: "transitionToNext")
        tracks[2]["userEdited"] = ["title", "mood"]
        saved["tracks"] = tracks
        saved.removeValue(forKey: "targetDiscMedium")
        saved.removeValue(forKey: "anchoredDiscMetadata")

        let read = try KroutonPersistedJSON.decode(AudioProject.self, from: JSONSerialization.data(withJSONObject: saved))
        XCTAssertEqual(read.value.albumTitle, "Night Drive")
        XCTAssertFalse(read.value.writeCDText)
        XCTAssertEqual(read.value.targetDiscMedium, .cd80Min700MB)
        XCTAssertEqual(read.value.tracks.map(\.source.lastPathComponent), ["one.flac", "three.flac"])
        XCTAssertEqual(read.value.tracks[1].transitionToNext.preGapSeconds, KroutonTrackTransitionSpec().preGapSeconds)
        // A field the user typed that this version doesn't know is dropped; the rest stay.
        XCTAssertEqual(read.value.tracks[1].userEdited, [.title])
        XCTAssertFalse(read.repairs.isEmpty)
    }
}
