import CryptoKit
import Darwin
import Foundation
import ImageKit
import OpticalCore

// MARK: - Append-Only JSONL BurnEventJournal (with readAll() for BurnSetProgress.replay)

public actor BurnEventJournal {
    private let url: URL

    public init(directory: URL, filename: String = "burn-set-events.jsonl") {
        self.url = directory.appendingPathComponent(filename)
    }

    public func append(_ event: BurnEvent) throws {
        let dir = url.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        var line = try encoder.encode(event)
        line.append(0x0A)
        if !FileManager.default.fileExists(atPath: url.path) {
            FileManager.default.createFile(atPath: url.path, contents: nil)
        }
        let handle = try FileHandle(forUpdating: url)
        defer { try? handle.close() }
        let end = try handle.seekToEnd()
        // A crash mid-write leaves a last line without its newline; this event must not join it,
        // or both fail to decode and the event is lost.
        if end > 0 {
            try handle.seek(toOffset: end - 1)
            if try handle.read(upToCount: 1) != Data([0x0A]) { line.insert(0x0A, at: 0) }
            try handle.seekToEnd()
        }
        try handle.write(contentsOf: line)
        try handle.synchronize()
    }

    public func readAll() -> [BurnEvent] {
        guard let text = try? String(contentsOf: url, encoding: .utf8) else { return [] }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        var events: [BurnEvent] = []
        for line in text.split(separator: "\n") {
            if let evt = try? decoder.decode(BurnEvent.self, from: Data(line.utf8)) {
                events.append(evt)
            }
        }
        return events
    }
}

// MARK: - Single-Read Streaming Set Stager (Reads Each Source File ONCE to Copy & Hash)

public struct StagedInputFile: Sendable, Equatable {
    public let sourceURL: URL
    public let relativePathOnDisc: String

    public init(sourceURL: URL, relativePathOnDisc: String? = nil) {
        self.sourceURL = sourceURL
        let raw = (relativePathOnDisc ?? sourceURL.lastPathComponent)
            .precomposedStringWithCanonicalMapping
            .replacingOccurrences(of: "\\", with: "/")
        let safeParts = raw
            .split(separator: "/", omittingEmptySubsequences: true)
            .filter { $0 != "." && $0 != ".." }
            .map(String.init)
        let fallback = sourceURL.lastPathComponent
            .replacingOccurrences(of: "\\", with: "/")
            .split(separator: "/", omittingEmptySubsequences: true)
            .filter { $0 != "." && $0 != ".." }
            .map(String.init)
            .joined(separator: "_")
        self.relativePathOnDisc = safeParts.isEmpty ? (fallback.isEmpty ? "staged-item" : fallback) : safeParts.joined(separator: "/")
    }
}

public enum BurnSetStager {
    public enum ManifestMode: Sendable {
        case bagItRFC8493      // Places payload under data/ + bagit.txt, bag-info.txt, manifest-sha256.txt, krouton-set-index.json
        case rootSHA256Sums    // Places payload at disc root / + SHA256SUMS, krouton-set-index.json
    }

    /// Streams `sourceURL` into `destinationURL` in 256 KiB chunks, updating a `SHA256` hasher
    /// on the exact bytes written so the file is read ONCE and cannot change between hashing and staging.
    public enum StageMethod: Sendable, Equatable {
        case clonedOnAPFS
        case streamedCopy
    }

    struct SourceFileStamp: Equatable {
        let dev: dev_t
        let ino: ino_t
        let size: off_t
        let mtimeSec: Int
        let mtimeNsec: Int
        let ctimeSec: Int
        let ctimeNsec: Int

        init?(fd: Int32) {
            var s = stat()
            guard fstat(fd, &s) == 0 else { return nil }
            dev = s.st_dev
            ino = s.st_ino
            size = s.st_size
            mtimeSec = s.st_mtimespec.tv_sec
            mtimeNsec = s.st_mtimespec.tv_nsec
            ctimeSec = s.st_ctimespec.tv_sec
            ctimeNsec = s.st_ctimespec.tv_nsec
        }
    }

    /// Stages a source file using descriptor-pinned APFS copy-on-write (`fclonefileat`) when supported,
    /// falling back to `copyAndHashSinglePass` across volumes, and verifies via `fstat` that the source
    /// did not mutate mid-clone. Always hashes the staged file so the digest matches the frozen bytes.
    public static func stageAndHash(
        from sourceURL: URL,
        to destinationURL: URL
    ) throws -> (byteCount: Int64, sha256Hex: String, method: StageMethod) {
        let fm = FileManager.default
        try fm.createDirectory(at: destinationURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        for _ in 0..<3 {
            if fm.fileExists(atPath: destinationURL.path) {
                try fm.removeItem(at: destinationURL)
            }
            let fd = open(sourceURL.path, O_RDONLY)
            guard fd >= 0 else { break }
            defer { close(fd) }
            guard let before = SourceFileStamp(fd: fd) else { break }

            if fclonefileat(fd, AT_FDCWD, destinationURL.path, 0) == 0 {
                let (bytes, sha) = try hashStagedFile(at: destinationURL)
                if SourceFileStamp(fd: fd) == before && bytes == Int64(before.size) {
                    return (bytes, sha, .clonedOnAPFS)
                }
            } else {
                let code = errno
                if code != EINTR && code != EAGAIN {
                    break
                }
            }
        }
        let copied = try copyAndHashSinglePass(from: sourceURL, to: destinationURL)
        return (copied.byteCount, copied.sha256Hex, .streamedCopy)
    }

    static func hashStagedFile(at url: URL) throws -> (byteCount: Int64, sha256Hex: String) {
        let handle = try FileHandle(forReadingFrom: url)
        defer { try? handle.close() }
        var hasher = SHA256()
        var total: Int64 = 0
        while let chunk = try handle.read(upToCount: 512 * 1024), !chunk.isEmpty {
            hasher.update(data: chunk)
            total += Int64(chunk.count)
        }
        return (total, hasher.finalize().map { String(format: "%02x", $0) }.joined())
    }

    static func copyAndHashSinglePass(from sourceURL: URL, to destinationURL: URL) throws -> (byteCount: Int64, sha256Hex: String) {
        let fm = FileManager.default
        try fm.createDirectory(at: destinationURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        if fm.fileExists(atPath: destinationURL.path) {
            try fm.removeItem(at: destinationURL)
        }
        let inHandle = try FileHandle(forReadingFrom: sourceURL)
        defer { try? inHandle.close() }
        fm.createFile(atPath: destinationURL.path, contents: nil)
        let outHandle = try FileHandle(forWritingTo: destinationURL)
        defer { try? outHandle.close() }

        var hasher = SHA256()
        var totalBytes: Int64 = 0
        let chunkSize = 256 * 1024
        while true {
            guard let chunk = try inHandle.read(upToCount: chunkSize), !chunk.isEmpty else { break }
            hasher.update(data: chunk)
            try outHandle.write(contentsOf: chunk)
            totalBytes += Int64(chunk.count)
        }
        try outHandle.synchronize()
        let digestHex = hasher.finalize().map { String(format: "%02x", $0) }.joined()
        return (totalBytes, digestHex)
    }

    /// Stages all discs of a spanned set in two phases:
    /// 1. Copies each source file ONCE into its disc staging directory while hashing its exact bytes.
    /// 2. Writes the cross-disc `SpanManifest` (`krouton-set-index.json` + `manifest-sha256.txt` or `SHA256SUMS`)
    ///    into every disc directory and masters each disc into a mountable hybrid image with its own SHA-256.
    /// This runs `hdiutil` and blocks until it exits, so call it off the main actor.
    public static func freezeAndStageSet(
        setID: BurnSetID = BurnSetID(),
        title: String,
        discs: [[StagedInputFile]],
        stagingRootDirectory: URL,
        manifestMode: ManifestMode = .bagItRFC8493,
        createdAt: Date = Date()
    ) throws -> (burnSet: BurnSet, setIndex: SpanSetIndex) {
        let fm = FileManager.default
        let setDir = stagingRootDirectory.appendingPathComponent(setID.raw.uuidString, isDirectory: true)
        if fm.fileExists(atPath: setDir.path) {
            try? fm.removeItem(at: setDir)
        }
        try fm.createDirectory(at: setDir, withIntermediateDirectories: true)

        let discCount = discs.count
        var indexDiscs: [SpanSetIndex.Disc] = []
        var discStageDirs: [Int: URL] = [:]

        // Pass 1: Single-read copy + SHA-256 hash of every payload file across all discs
        for (offset, discFiles) in discs.enumerated() {
            let discIndex = offset + 1
            let volLabel = SpanManifest.volumeLabel(base: title, discIndex: discIndex, discCount: discCount)
            let discDir = setDir.appendingPathComponent(String(format: "Disc_%02d_%@", discIndex, volLabel), isDirectory: true)
            try fm.createDirectory(at: discDir, withIntermediateDirectories: true)
            discStageDirs[discIndex] = discDir

            var payloadRecords: [SpanPayloadFile] = []
            for item in discFiles {
                let relSubpath = manifestMode == .bagItRFC8493
                    ? "data/\(item.relativePathOnDisc)"
                    : item.relativePathOnDisc
                let dstURL = discDir.appendingPathComponent(relSubpath)
                let (bytes, sha, _) = try stageAndHash(from: item.sourceURL, to: dstURL)
                payloadRecords.append(SpanPayloadFile(path: item.relativePathOnDisc, byteCount: bytes, sha256: sha))
            }
            indexDiscs.append(SpanSetIndex.Disc(index: discIndex, volumeLabel: volLabel, files: payloadRecords))
        }

        let spanSetIndex = SpanSetIndex(
            setIdentifier: setID.raw.uuidString,
            title: title,
            createdAt: createdAt,
            discs: indexDiscs
        )

        // Pass 2: Write manifest tag files onto every disc and seal each disc's frozen image + SHA-256
        var frozenDiscs: [FrozenDisc] = []
        for discEntry in indexDiscs {
            guard let discDir = discStageDirs[discEntry.index] else { continue }
            let manifestFiles: [String: Data] = try {
                switch manifestMode {
                case .bagItRFC8493:
                    return try SpanManifest.tagFiles(for: discEntry.index, in: spanSetIndex)
                case .rootSHA256Sums:
                    return try SpanManifest.rootChecksumFiles(for: discEntry.index, in: spanSetIndex)
                }
            }()

            for (name, data) in manifestFiles {
                try data.write(to: discDir.appendingPathComponent(name), options: .atomic)
            }

            let imageURL = setDir.appendingPathComponent(String(format: "%@.iso", discEntry.volumeLabel))
            let (imageBytes, imageSHA256) = try buildFrozenDiscImage(fromDirectory: discDir, volumeLabel: discEntry.volumeLabel, outputURL: imageURL)
            try? fm.removeItem(at: discDir)
            frozenDiscs.append(FrozenDisc(
                index: discEntry.index,
                volumeLabel: discEntry.volumeLabel,
                imageURL: imageURL,
                imageSHA256: imageSHA256,
                imageBytes: imageBytes
            ))
        }

        let burnSet = BurnSet(id: setID, title: title, createdAt: createdAt, discs: frozenDiscs)
        return (burnSet, spanSetIndex)
    }

    /// Masters `dir` into a mountable ISO-9660 + Joliet + UDF image with `hdiutil makehybrid` and
    /// hashes the finished file. The image is built once and frozen; every attempt burns these bytes.
    private static func buildFrozenDiscImage(fromDirectory dir: URL, volumeLabel: String, outputURL: URL) throws -> (Int64, String) {
        let built = try KroutonHybridImageBuilder.buildBlocking(
            sourceDirectory: dir,
            outputURL: outputURL,
            options: KroutonHybridImageOptions(volumeName: volumeLabel)
        )
        return (built.byteCount, built.sha256Hex)
    }
}
