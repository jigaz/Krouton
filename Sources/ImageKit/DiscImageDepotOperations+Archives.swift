import Foundation

// MARK: - DiscImageDepotOperations — Archives

extension DiscImageDepotOperations {
    /// macOS's bsdtar (libarchive) reads zip, 7z and compressed tar archives.
    static let tarURL = URL(fileURLWithPath: "/usr/bin/tar")

    /// Extracts the named members of a zip, 7z or tar archive into `folder`, keeping their paths.
    /// Members are passed after `--` as separate arguments, so no name is ever read as an option,
    /// and no shell is involved. libarchive refuses absolute paths and `..` unless told otherwise.
    public static func extractArchiveMembers(_ members: [String], from archive: URL, into folder: URL) throws {
        guard !members.isEmpty else { return }
        let process = Process()
        process.executableURL = tarURL
        process.arguments = ["-x", "-f", archive.path, "-C", folder.path, "--"] + members
        let errors = Pipe()
        process.standardOutput = FileHandle.nullDevice
        process.standardError = errors
        try process.run()
        let message = errors.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        guard process.terminationStatus == 0 else {
            let text = String(decoding: message, as: UTF8.self).trimmingCharacters(in: .whitespacesAndNewlines)
            throw NSError(domain: "DiscImageDepotOperations", code: Int(process.terminationStatus), userInfo: [
                NSLocalizedDescriptionKey: text.isEmpty ? "Could not unpack \(archive.lastPathComponent)." : text,
            ])
        }
    }
}
