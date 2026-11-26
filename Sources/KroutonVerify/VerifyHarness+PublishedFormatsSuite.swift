import Foundation
import OpticalCore

// MARK: - VerifyHarness — Suite 33: Published File Formats

extension KroutonTestHarness {
    /// The JSON Schemas at krouton.app/schema (`docs/schema/`) promise other programs what Krouton
    /// writes. This suite encodes real values and checks every key against the schema both ways:
    /// nothing written that the schema doesn't describe, nothing required that isn't written.
    mutating func runVerifyPublishedFormatsSuite() {
        self.runSuite("33. Published Formats: krouton.app/schema Matches What Krouton Writes") { h in
            let schemas = Self.repositoryRoot.appendingPathComponent("docs/schema")

            // Disc set index, as burned onto every disc of a spanned set.
            let set = SpanSetIndex(
                setIdentifier: "urn:uuid:5f0b7c1e-0000-4000-8000-000000000001", title: "Photos 2025",
                createdAt: Date(timeIntervalSince1970: 1_767_225_600),
                discs: [.init(index: 1, volumeLabel: "PHOTOS_2025_D01",
                              files: [SpanPayloadFile(path: "2025/january/IMG_0001.HEIC", byteCount: 2_048_000,
                                                      sha256: String(repeating: "ab", count: 32))])]
            )
            if let tags = try? SpanManifest.tagFiles(for: 1, in: set),
               let index = tags["krouton-set-index.json"],
               let written = try? JSONSerialization.jsonObject(with: index) as? [String: Any],
               let schema = Self.loadSchema(schemas.appendingPathComponent("set-index/v1.json")) {
                h.lint(written["formatVersion"] as? Int == 1, "The set index must say formatVersion 1")
                Self.compare(written, against: schema, path: "set-index", into: &h)
                let disc = (written["discs"] as? [[String: Any]])?.first ?? [:]
                let discSchema = Self.child(schema, "discs")
                Self.compare(disc, against: discSchema, path: "set-index.discs[]", into: &h)
                let file = (disc["files"] as? [[String: Any]])?.first ?? [:]
                Self.compare(file, against: Self.child(discSchema, "files"), path: "set-index.discs[].files[]", into: &h)
            } else {
                h.lint(false, "The set index must encode, and docs/schema/set-index/v1.json must parse")
            }

            // The disc part of a .krut project.
            if let data = try? JSONEncoder().encode(KroutonKrutCoreSpec(totalSectorsLBA: 1000, expectedPayloadBytes: 2_048_000)),
               let written = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let schema = Self.loadSchema(schemas.appendingPathComponent("krut/v1.json")),
               let core = (schema["properties"] as? [String: Any])?["coreSpec"] as? [String: Any] {
                Self.compare(written, against: core, path: "krut.coreSpec", into: &h)
            } else {
                h.lint(false, "KroutonKrutCoreSpec must encode, and docs/schema/krut/v1.json must parse")
            }

            let feed = Self.loadSchema(schemas.appendingPathComponent("depot-feed/v1.json"))
            h.lint(feed?["$id"] as? String == "https://krouton.app/schema/depot-feed/v1.json",
                   "The depot feed schema must be published at its own address")
        }
    }

    // MARK: - Schema Helpers

    static func loadSchema(_ url: URL) -> [String: Any]? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONSerialization.jsonObject(with: data) as? [String: Any]
    }

    /// The object schema of an array property's items.
    static func child(_ schema: [String: Any], _ property: String) -> [String: Any] {
        let properties = schema["properties"] as? [String: Any] ?? [:]
        let array = properties[property] as? [String: Any] ?? [:]
        return array["items"] as? [String: Any] ?? [:]
    }

    static func compare(_ written: [String: Any], against schema: [String: Any], path: String, into h: inout KroutonTestHarness) {
        let described = Set((schema["properties"] as? [String: Any] ?? [:]).keys)
        let required = Set(schema["required"] as? [String] ?? [])
        let keys = Set(written.keys)
        let undescribed = keys.subtracting(described).sorted()
        let missing = required.subtracting(keys).sorted()
        h.lint(undescribed.isEmpty, "\(path): Krouton writes keys the schema doesn't describe: \(undescribed)")
        h.lint(missing.isEmpty, "\(path): the schema requires keys Krouton doesn't write: \(missing)")
    }
}
