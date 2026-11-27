import Foundation

// MARK: - Bundling a Folder

extension SpoolBundleWriter {
    /// Finder and Spotlight bookkeeping that never belongs on a disc (AppleDouble `._*` files too).
    static let skippedNames: Set<String> = [
        ".DS_Store", ".Spotlight-V100", ".fseventsd", ".Trashes", ".TemporaryItems", ".DocumentRevisions-V100", "Icon\r",
    ]

    public struct FolderSummary: Sendable, Equatable {
        public let files: Int
        public let folders: Int
        public let bytes: UInt64
    }

    /// Writes the contents of `folder` (not the folder itself) to `output` as a bundle, folders
    /// before their contents and names (in Unicode NFC, as discs and Windows expect) in UTF-8 byte
    /// order, so the same folder always gives the same bytes. Refuses links, special files, names a disc cannot hold, and names that differ
    /// only by case, before anything is uploaded.
    public static func bundle(folder: URL, to output: URL, isCancelled: () -> Bool = { false }) throws -> FolderSummary {
        guard FileManager.default.createFile(atPath: output.path, contents: nil) else {
            throw CocoaError(.fileWriteUnknown, userInfo: [NSFilePathErrorKey: output.path])
        }
        let handle = try FileHandle(forWritingTo: output)
        defer { try? handle.close() }
        var writer = SpoolBundleWriter { try handle.write(contentsOf: $0) }
        var seen = Set<String>()
        var files = 0
        var folders = 0
        var bytes: UInt64 = 0
        let keys: Set<URLResourceKey> = [.isSymbolicLinkKey, .isDirectoryKey, .isRegularFileKey, .fileSizeKey, .contentModificationDateKey]

        func walk(_ directory: URL, prefix: String) throws {
            let names = try FileManager.default.contentsOfDirectory(atPath: directory.path)
                .filter { !skippedNames.contains($0) && !$0.hasPrefix("._") }
                .map { (onDisk: $0, nfc: $0.precomposedStringWithCanonicalMapping) }
                .sorted { $0.nfc.utf8.lexicographicallyPrecedes($1.nfc.utf8) }
            for (onDisk, name) in names {
                if isCancelled() { throw SpoolBundleError.cancelled }
                let url = directory.appendingPathComponent(onDisk)
                let path = prefix.isEmpty ? name : prefix + "/" + name
                guard seen.insert(SpoolBundleFormat.collisionKey(path)).inserted else { throw SpoolBundleError.duplicate(path) }
                let values = try url.resourceValues(forKeys: keys)
                let mtime = UInt64(max(0, values.contentModificationDate?.timeIntervalSince1970 ?? 0))
                if values.isSymbolicLink == true {
                    throw SpoolBundleError.unsupportedItem(path)
                } else if values.isDirectory == true {
                    try writer.directory(path, mtime: mtime)
                    folders += 1
                    try walk(url, prefix: path)
                } else if values.isRegularFile == true {
                    let size = UInt64(max(0, values.fileSize ?? 0))
                    let input = try FileHandle(forReadingFrom: url)
                    defer { try? input.close() }
                    try writer.file(path, size: size, mtime: mtime) { try input.read(upToCount: $0) ?? Data() }
                    files += 1
                    bytes += size
                } else {
                    throw SpoolBundleError.unsupportedItem(path)
                }
            }
        }

        try walk(folder, prefix: "")
        guard files > 0 else { throw SpoolBundleError.empty }
        try writer.finish()
        return FolderSummary(files: files, folders: folders, bytes: bytes)
    }
}
