import CryptoKit
import Foundation
import os

// MARK: - Hybrid Image Builder
//
// Real disc images, built by macOS itself.
//
// `hdiutil makehybrid` writes one image whose ISO-9660, Joliet and UDF directory
// trees all point at the same file extents, with subdirectories and long names.
// Krouton hands it a staged directory and gets back a mountable, burnable .iso.
// `KroutonHybridImagePlanner` remains useful as a size preview; it does not
// describe the layout of images built here.

/// What `hdiutil makehybrid` puts in the image.
public struct KroutonHybridImageOptions: Sendable, Equatable {
    /// The volume name; clipped to each file system's limit.
    public var volumeName: String
    /// Adds an ISO 9660 tree.
    public var includeISO9660: Bool
    /// Adds a Joliet tree (long Unicode names for Windows).
    public var includeJoliet: Bool
    /// Adds a UDF tree.
    public var includeUDF: Bool
    /// Adds an HFS+ tree, which keeps Mac metadata such as custom icons and resource forks.
    public var includeHFSPlus: Bool
    /// A Finder layout to write as `.DS_Store` into the source folder before the build (see
    /// `KroutonFinderLayoutBlueprint.serializeDSStore` for its limits).
    public var finderLayout: KroutonFinderLayoutBlueprint?

    public init(
        volumeName: String,
        includeISO9660: Bool = true,
        includeJoliet: Bool = true,
        includeUDF: Bool = true,
        includeHFSPlus: Bool = false,
        finderLayout: KroutonFinderLayoutBlueprint? = nil
    ) {
        self.volumeName = volumeName
        self.includeISO9660 = includeISO9660
        self.includeJoliet = includeJoliet
        self.includeUDF = includeUDF
        self.includeHFSPlus = includeHFSPlus
        self.finderLayout = finderLayout
    }
}

/// An image `hdiutil` wrote, with its size and digest.
public struct KroutonBuiltDiscImage: Sendable, Equatable {
    /// Where the image is.
    public let url: URL
    /// Its size in bytes.
    public let byteCount: Int64
    /// Lowercase hex, no prefix.
    public let sha256Hex: String
}

/// Why an image couldn't be built. The descriptions are for the user.
public enum KroutonHybridImageError: Error, LocalizedError, Sendable, Equatable {
    case sourceDirectoryMissing(String)
    case noFilesystemSelected
    case hdiutilFailed(status: Int32, message: String)
    case outputMissing(String)
    case cancelled

    public var errorDescription: String? {
        switch self {
        case .sourceDirectoryMissing(let path): return "The folder to master does not exist: \(path)"
        case .noFilesystemSelected: return "Choose at least one filesystem (ISO-9660, Joliet, UDF or HFS+)."
        case .hdiutilFailed(let status, let message):
            return message.isEmpty ? "hdiutil makehybrid failed with status \(status)." : message
        case .outputMissing(let path): return "hdiutil reported success but no image was written at \(path)."
        case .cancelled: return "Image mastering was cancelled."
        }
    }
}

/// Lets another task stop a running `hdiutil`. Safe to cancel before, during or after the run.
public final class KroutonImageBuildCancellation: Sendable {
    private struct State {
        var process: Process?
        var cancelled = false
    }
    private let state = OSAllocatedUnfairLock(uncheckedState: State())

    /// A token that isn't cancelled.
    public init() {}

    /// True once `cancel()` was called.
    public var isCancelled: Bool {
        state.withLockUnchecked { $0.cancelled }
    }

    /// Stops the running `hdiutil`, or the next one to start.
    public func cancel() {
        let proc: Process? = state.withLockUnchecked { st in
            st.cancelled = true
            return st.process
        }
        if let proc, proc.isRunning { proc.terminate() }
    }

    /// Called once the process is running. Returns false if cancellation already happened.
    fileprivate func attach(_ running: Process) -> Bool {
        state.withLockUnchecked { st in
            st.process = running
            return !st.cancelled
        }
    }

    fileprivate func detach() {
        state.withLockUnchecked { $0.process = nil }
    }
}

/// Builds hybrid disc images from a folder with `hdiutil makehybrid` (run as a `Process` with an
/// argument array).
public enum KroutonHybridImageBuilder {
    static let hdiutilURL = URL(fileURLWithPath: "/usr/bin/hdiutil")

    /// Shortens a volume name to `limit` characters. When it has to cut, it keeps the
    /// last four characters so multi-disc suffixes such as "_D02" survive.
    public static func clippedVolumeName(_ name: String, limit: Int) -> String {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count > limit else { return trimmed }
        guard limit > 4 else { return String(trimmed.prefix(limit)) }
        return String(trimmed.prefix(limit - 4)) + String(trimmed.suffix(4))
    }

    /// The exact argument array passed to `hdiutil`. No shell is involved.
    public static func arguments(
        sourceDirectory: URL,
        outputURL: URL,
        options: KroutonHybridImageOptions
    ) throws -> [String] {
        guard options.includeISO9660 || options.includeJoliet || options.includeUDF || options.includeHFSPlus else {
            throw KroutonHybridImageError.noFilesystemSelected
        }
        let name = options.volumeName.trimmingCharacters(in: .whitespacesAndNewlines)
        let volumeName = name.isEmpty ? "KROUTON_DISC" : name

        var args = ["makehybrid", "-o", outputURL.path, "-default-volume-name", volumeName]
        if options.includeISO9660 {
            // ECMA-119 volume identifiers: 32 characters from A-Z, 0-9 and underscore.
            args += ["-iso", "-iso-volume-name", KroutonHybridImagePlanner.sanitizeVolumeIdentifier(volumeName)]
        }
        if options.includeJoliet {
            args += ["-joliet", "-joliet-volume-name", clippedVolumeName(volumeName, limit: 16)]
        }
        if options.includeUDF {
            args += ["-udf", "-udf-version", "1.02", "-udf-volume-name", clippedVolumeName(volumeName, limit: 30)]
        }
        if options.includeHFSPlus {
            args += ["-hfs", "-hfs-volume-name", clippedVolumeName(volumeName, limit: 27)]
        }
        args.append(sourceDirectory.path)
        return args
    }

    /// Streams a file through SHA-256 in 1 MiB chunks. Memory use does not grow with file size.
    public static func sha256(ofFileAt url: URL) throws -> (hex: String, byteCount: Int64) {
        let handle = try FileHandle(forReadingFrom: url)
        defer { try? handle.close() }
        var hasher = SHA256()
        var total: Int64 = 0
        while let chunk = try handle.read(upToCount: 1 << 20), !chunk.isEmpty {
            hasher.update(data: chunk)
            total += Int64(chunk.count)
        }
        return (hasher.finalize().map { String(format: "%02x", $0) }.joined(), total)
    }

    /// Builds the image and blocks until `hdiutil` exits. Call it off the main actor.
    public static func buildBlocking(
        sourceDirectory: URL,
        outputURL: URL,
        options: KroutonHybridImageOptions,
        cancellation: KroutonImageBuildCancellation = KroutonImageBuildCancellation()
    ) throws -> KroutonBuiltDiscImage {
        let fm = FileManager.default
        var isDirectory: ObjCBool = false
        guard fm.fileExists(atPath: sourceDirectory.path, isDirectory: &isDirectory), isDirectory.boolValue else {
            throw KroutonHybridImageError.sourceDirectoryMissing(sourceDirectory.path)
        }
        if let blueprint = options.finderLayout {
            let children = (try? fm.contentsOfDirectory(atPath: sourceDirectory.path))?.filter { !$0.hasPrefix(".") } ?? []
            let dsData = blueprint.serializeDSStore(itemNames: children.sorted())
            let dsURL = sourceDirectory.appendingPathComponent(".DS_Store")
            try? dsData.write(to: dsURL, options: .atomic)
        }
        let args = try arguments(sourceDirectory: sourceDirectory, outputURL: outputURL, options: options)

        try fm.createDirectory(at: outputURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        // hdiutil refuses to replace an existing image, and may add an extension of its own.
        let alternates = [
            URL(fileURLWithPath: outputURL.path + ".iso"),
            URL(fileURLWithPath: outputURL.path + ".cdr"),
            outputURL.deletingPathExtension().appendingPathExtension("cdr")
        ]
        for stale in [outputURL] + alternates where fm.fileExists(atPath: stale.path) {
            try fm.removeItem(at: stale)
        }

        // stderr goes to a file and stdout is discarded, so a chatty hdiutil can never
        // fill a pipe and stall while we wait for it to exit.
        let errorLogURL = fm.temporaryDirectory.appendingPathComponent("krouton-hdiutil-\(UUID().uuidString).log")
        fm.createFile(atPath: errorLogURL.path, contents: nil)
        defer { try? fm.removeItem(at: errorLogURL) }
        let errorLog = try FileHandle(forWritingTo: errorLogURL)
        defer { try? errorLog.close() }

        let process = Process()
        process.executableURL = hdiutilURL
        process.arguments = args
        process.standardInput = FileHandle.nullDevice
        process.standardOutput = FileHandle.nullDevice
        process.standardError = errorLog

        guard !cancellation.isCancelled else { throw KroutonHybridImageError.cancelled }
        try process.run()
        if !cancellation.attach(process) { process.terminate() }
        process.waitUntilExit()
        cancellation.detach()

        if cancellation.isCancelled {
            for partial in [outputURL] + alternates { try? fm.removeItem(at: partial) }
            throw KroutonHybridImageError.cancelled
        }
        guard process.terminationStatus == 0 else {
            let message = (try? String(contentsOf: errorLogURL, encoding: .utf8))?
                .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            throw KroutonHybridImageError.hdiutilFailed(status: process.terminationStatus, message: String(message.suffix(2000)))
        }
        if !fm.fileExists(atPath: outputURL.path),
           let written = alternates.first(where: { fm.fileExists(atPath: $0.path) }) {
            try fm.moveItem(at: written, to: outputURL)
        }
        guard fm.fileExists(atPath: outputURL.path) else {
            throw KroutonHybridImageError.outputMissing(outputURL.path)
        }

        let digest = try sha256(ofFileAt: outputURL)
        return KroutonBuiltDiscImage(url: outputURL, byteCount: digest.byteCount, sha256Hex: digest.hex)
    }

    /// Builds the image on a background thread. Cancelling the calling task stops `hdiutil`
    /// and removes the partial image.
    public static func build(
        sourceDirectory: URL,
        outputURL: URL,
        options: KroutonHybridImageOptions
    ) async throws -> KroutonBuiltDiscImage {
        let cancellation = KroutonImageBuildCancellation()
        let worker = Task.detached(priority: .userInitiated) {
            try buildBlocking(sourceDirectory: sourceDirectory, outputURL: outputURL, options: options, cancellation: cancellation)
        }
        return try await withTaskCancellationHandler {
            try await worker.value
        } onCancel: {
            cancellation.cancel()
        }
    }
}
