import Foundation
import NetworkSpool

// MARK: - VerifyHarness — Suite 27 (continued): Folder Bundles for Server-Side Mastering

extension KroutonTestHarness {
    /// A folder sent to Krouton Server must reach it exactly as the Rust reader expects:
    /// `Vectors/krsp-bundle-v1.tar` is the Rust writer's output, and both the Swift writer and a walk
    /// of the same folder on disk must reproduce it byte for byte. The name rules must agree line by
    /// line with `Vectors/krsp-bundle-names-v1.txt`.
    static func verifyKroutonServerBundles(_ h: inout KroutonTestHarness) {
        let vectors = Self.repositoryRoot.appendingPathComponent("Vectors")
        let golden = (try? Data(contentsOf: vectors.appendingPathComponent("krsp-bundle-v1.tar"))) ?? Data()
        h.check(golden.count >= 4096 && golden.count % 2048 == 0, "The bundle vector must load and be sector-aligned")

        let entries = Self.canonicalBundleEntries()
        var built = Data()
        var writer = SpoolBundleWriter { built.append($0) }
        do {
            for (path, contents, mtime) in entries {
                guard let contents else {
                    try writer.directory(path, mtime: mtime)
                    continue
                }
                var offset = 0
                try writer.file(path, size: UInt64(contents.count), mtime: mtime) { count in
                    let chunk = contents.subdata(in: offset..<min(contents.count, offset + count))
                    offset += chunk.count
                    return chunk
                }
            }
            try writer.finish()
        } catch {
            h.check(false, "The canonical bundle must write: \(error)")
        }
        h.check(built == golden, "The Swift bundle writer must produce Vectors/krsp-bundle-v1.tar byte for byte")

        let folderResult = Self.bundleCanonicalFolder(entries)
        h.check(folderResult == golden, "Bundling the same folder from disk (Finder litter skipped) must give the same bytes")

        Self.verifyBundleNameVectors(&h, vectors.appendingPathComponent("krsp-bundle-names-v1.txt"))
        Self.verifyBundleRefusals(&h)
    }

    /// The entries of `krouton-server/crates/krsp/tests/bundle_vectors.rs`, in the same order.
    static func canonicalBundleEntries() -> [(String, Data?, UInt64)] {
        let photos = "Holiday 2026/Fotos \u{2013} \u{dc}n\u{ef}code"
        let longName = "Holiday 2026/" + String(repeating: "a-very-long-file-name-that-needs-a-pax-header", count: 2) + ".txt"
        let jpeg = Data((0..<3).flatMap { _ in (0...255).map { UInt8($0) } })
        return [
            ("Holiday 2026", nil, 1_767_225_600),
            (photos, nil, 1_767_225_602),
            (photos + "/IMG_0001.JPG", jpeg, 1_767_225_603),
            ("Holiday 2026/README.txt", Data("Burned by Krouton.\n".utf8), 1_767_225_601),
            (longName, Data("long\n".utf8), 1_767_225_604),
            ("empty.bin", Data(), 0),
        ]
    }

    /// Recreates the canonical entries as real files (plus a `.DS_Store`) and bundles the folder.
    static func bundleCanonicalFolder(_ entries: [(String, Data?, UInt64)]) -> Data? {
        let fm = FileManager.default
        let root = fm.temporaryDirectory.appendingPathComponent("krouton-bundle-\(UUID().uuidString)")
        let source = root.appendingPathComponent("source")
        defer { try? fm.removeItem(at: root) }
        do {
            try fm.createDirectory(at: source, withIntermediateDirectories: true)
            for (path, contents, mtime) in entries {
                let url = source.appendingPathComponent(path)
                if let contents {
                    try contents.write(to: url)
                    try fm.setAttributes([.modificationDate: Date(timeIntervalSince1970: TimeInterval(mtime))], ofItemAtPath: url.path)
                } else {
                    try fm.createDirectory(at: url, withIntermediateDirectories: true)
                }
            }
            try Data([0x00, 0x00, 0x00, 0x01]).write(to: source.appendingPathComponent("Holiday 2026/.DS_Store"))
            // Folder times last, deepest first: writing their contents moved them.
            for (path, contents, mtime) in entries.reversed() where contents == nil {
                try fm.setAttributes([.modificationDate: Date(timeIntervalSince1970: TimeInterval(mtime))],
                                     ofItemAtPath: source.appendingPathComponent(path).path)
            }
            let output = root.appendingPathComponent("out.krspbundle")
            _ = try SpoolBundleWriter.bundle(folder: source, to: output)
            return try Data(contentsOf: output)
        } catch {
            return nil
        }
    }

    static func verifyBundleNameVectors(_ h: inout KroutonTestHarness, _ url: URL) {
        let lines = ((try? String(contentsOf: url, encoding: .utf8)) ?? "")
            .components(separatedBy: "\n")
            .filter { $0.hasPrefix("accept ") || $0.hasPrefix("reject ") }
        h.check(lines.count >= 30, "The bundle name vectors must load (\(url.lastPathComponent))")
        var disagreements: [String] = []
        for line in lines {
            let accept = line.hasPrefix("accept ")
            let json = Data(line.dropFirst(7).utf8)
            guard let name = (try? JSONSerialization.jsonObject(with: json, options: .fragmentsAllowed)) as? String else {
                disagreements.append(line)
                continue
            }
            if (SpoolBundleFormat.problem(with: name) == nil) != accept {
                disagreements.append(line)
            }
        }
        h.check(disagreements.isEmpty, "The app and the server must accept and reject the same names: \(disagreements.prefix(3))")
    }

    static func verifyBundleRefusals(_ h: inout KroutonTestHarness) {
        let fm = FileManager.default
        let root = fm.temporaryDirectory.appendingPathComponent("krouton-bundle-bad-\(UUID().uuidString)")
        defer { try? fm.removeItem(at: root) }
        func attempt(_ setUp: (URL) throws -> Void) -> SpoolBundleError? {
            let folder = root.appendingPathComponent(UUID().uuidString)
            do {
                try fm.createDirectory(at: folder, withIntermediateDirectories: true)
                try setUp(folder)
                _ = try SpoolBundleWriter.bundle(folder: folder, to: root.appendingPathComponent(UUID().uuidString))
                return nil
            } catch let error as SpoolBundleError {
                return error
            } catch {
                return .cancelled
            }
        }
        let link = attempt { folder in
            try Data("x".utf8).write(to: folder.appendingPathComponent("real.txt"))
            try fm.createSymbolicLink(atPath: folder.appendingPathComponent("alias").path, withDestinationPath: "real.txt")
        }
        h.check(link == .unsupportedItem("alias"), "A symbolic link must be refused before upload, by name")
        let reserved = attempt { try Data("x".utf8).write(to: $0.appendingPathComponent("aux.txt")) }
        var reservedRefused = false
        if case .name("aux.txt", _)? = reserved { reservedRefused = true }
        h.check(reservedRefused, "A Windows device name must be refused, by name")
        h.check(attempt { _ in } == .empty, "An empty folder must be refused")
        let litterOnly = attempt { try Data([0]).write(to: $0.appendingPathComponent(".DS_Store")) }
        h.check(litterOnly == .empty, "A folder holding only Finder litter counts as empty")
    }
}
