import CryptoKit
import Foundation

// The files that make each disc of a set self-describing, in BagIt form
// (RFC 8493), plus a volume-label builder that keeps the disc number.
//
// Every disc carries:
//
//   bagit.txt                 declares the format
//   manifest-sha256.txt       SHA-256 of every payload file ON THIS DISC
//   bag-info.txt              which set this is, and "2 of 3"
//   krouton-set-index.json    every file on every disc of the set, with digests
//   tagmanifest-sha256.txt    digests of the four files above
//   data/…                    the payload
//
// The two manifests are in the format `shasum -a 256 -c` reads, so a disc can
// be verified decades from now with a stock command and no Krouton.
//
// Layout cost: BagIt puts the payload under `data/`. If you would rather keep
// the user's files at the root, write the same manifest as `SHA256SUMS` beside
// them and skip the bag; you lose tool recognition and keep everything else.
//
// These builders are pure: they take digests that were computed while the image
// was being written (one read of each source file), and return text.

// MARK: - SpanManifest

public struct SpanPayloadFile: Codable, Sendable, Equatable {
    /// Path as readers will see it on the mounted disc: UDF or Joliet name,
    /// forward slashes, relative to `data/`.
    public let path: String
    public let byteCount: Int64
    public let sha256: String

    public init(path: String, byteCount: Int64, sha256: String) {
        // One canonical Unicode form, so a manifest written on macOS matches the
        // names Windows and Linux report.
        self.path = path.precomposedStringWithCanonicalMapping
        self.byteCount = byteCount
        self.sha256 = sha256.lowercased()
    }
}

public struct SpanSetIndex: Codable, Sendable, Equatable {
    public struct Disc: Codable, Sendable, Equatable {
        public let index: Int
        public let volumeLabel: String
        public let files: [SpanPayloadFile]

        public init(index: Int, volumeLabel: String, files: [SpanPayloadFile]) {
            self.index = index
            self.volumeLabel = volumeLabel
            self.files = files
        }
    }
    let formatVersion: Int
    public let setIdentifier: String
    public let title: String
    public let createdAt: Date
    public let discs: [Disc]

    public init(setIdentifier: String, title: String, createdAt: Date, discs: [Disc]) {
        self.formatVersion = 1
        self.setIdentifier = setIdentifier
        self.title = title
        self.createdAt = createdAt
        self.discs = discs
    }
}

public enum SpanManifest {

    /// Tag files for one disc, keyed by file name, ready to place at the disc root.
    public static func tagFiles(for discIndex: Int, in set: SpanSetIndex) throws -> [String: Data] {
        guard let disc = set.discs.first(where: { $0.index == discIndex }) else {
            throw CocoaError(.fileNoSuchFile)
        }
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        encoder.dateEncodingStrategy = .iso8601

        var files: [String: Data] = [
            "bagit.txt": Data("BagIt-Version: 1.0\nTag-File-Character-Encoding: UTF-8\n".utf8),
            "manifest-sha256.txt": Data(payloadManifest(disc.files).utf8),
            "bag-info.txt": Data(bagInfo(disc: disc, set: set).utf8),
            "krouton-set-index.json": try encoder.encode(set),
        ]
        // The tag manifest covers the other tag files. It cannot list itself.
        let tagLines = files.keys.sorted().map { name in
            "\(hex(SHA256.hash(data: files[name] ?? Data())))  \(name)\n"
        }
        files["tagmanifest-sha256.txt"] = Data(tagLines.joined().utf8)
        return files
    }

    static func payloadManifest(_ files: [SpanPayloadFile]) -> String {
        files.sorted { $0.path < $1.path }
            .map { "\($0.sha256)  data/\(encodePath($0.path))\n" }
            .joined()
    }

    static func bagInfo(disc: SpanSetIndex.Disc, set: SpanSetIndex) -> String {
        let octets = disc.files.reduce(Int64(0)) { $0 + $1.byteCount }
        let day = ISO8601DateFormatter.string(from: set.createdAt, timeZone: .gmt, formatOptions: [.withFullDate])
        return [
            "Bag-Group-Identifier: \(set.setIdentifier)",
            "Bag-Count: \(disc.index) of \(set.discs.count)",
            "Bagging-Date: \(day)",
            "Payload-Oxum: \(octets).\(disc.files.count)",
            "External-Description: \(set.title), disc \(disc.index) of \(set.discs.count) (\(disc.volumeLabel))",
            "Bag-Software-Agent: Krouton",
        ].joined(separator: "\n") + "\n"
    }

    /// BagIt requires these three characters to be percent-encoded in manifest paths.
    static func encodePath(_ path: String) -> String {
        path.replacingOccurrences(of: "%", with: "%25")
            .replacingOccurrences(of: "\n", with: "%0A")
            .replacingOccurrences(of: "\r", with: "%0D")
    }

    static func hex(_ digest: SHA256.Digest) -> String {
        digest.map { String(format: "%02x", $0) }.joined()
    }

    /// An ISO 9660 volume identifier (A-Z, 0-9, underscore; 32 characters) that
    /// always ends in the disc number. The base is shortened to make room, so two
    /// discs of a set can never end up with the same label. Pass `limit: 16` for
    /// the Joliet descriptor.
    public static func volumeLabel(base: String, discIndex: Int, discCount: Int, limit: Int = 32) -> String {
        let cleaned = String(base.uppercased().unicodeScalars.map { scalar -> Character in
            let isAllowed = ("A"..."Z").contains(scalar) || ("0"..."9").contains(scalar)
            return isAllowed ? Character(scalar) : "_"
        })
        let trimmed = cleaned.trimmingCharacters(in: CharacterSet(charactersIn: "_"))
        let stem = trimmed.isEmpty ? "DISC" : trimmed
        guard discCount > 1 else { return String(stem.prefix(limit)) }

        let digits = max(2, String(discCount).count)
        let suffix = "_D" + String(format: "%0\(digits)d", discIndex)
        return String(stem.prefix(max(1, limit - suffix.count))) + suffix
    }

    /// Root-level manifest alternative (`SHA256SUMS` + `krouton-set-index.json`) for Data discs
    /// where the user wants their files at the disc root (`/`) instead of inside BagIt's `data/` directory.
    /// Verifiable on any OS via `shasum -a 256 -c SHA256SUMS`.
    public static func rootChecksumFiles(for discIndex: Int, in set: SpanSetIndex) throws -> [String: Data] {
        guard let disc = set.discs.first(where: { $0.index == discIndex }) else {
            throw CocoaError(.fileNoSuchFile)
        }
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        encoder.dateEncodingStrategy = .iso8601
        let sums = disc.files.sorted { $0.path < $1.path }
            .map { "\($0.sha256)  \(encodePath($0.path))\n" }
            .joined()
        return [
            "SHA256SUMS": Data(sums.utf8),
            "krouton-set-index.json": try encoder.encode(set),
        ]
    }
}
