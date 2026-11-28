import Foundation

// MARK: - Burn Preflight
//
// Pure decision logic for the physical burn path. Nothing here touches
// DiscRecording, so it is covered by ordinary unit tests without a drive.

/// Builds drive identifiers that stay unique when two identical drives are attached.
public enum KroutonDriveIdentity {
    static func baseID(vendor: String, product: String, firmware: String) -> String {
        "\(vendor)-\(product)-\(firmware)"
    }

    /// Returns one identifier per input, in the same order.
    ///
    /// A drive whose base identifier is unique keeps it unchanged, so identifiers
    /// already saved in sessions and queue items stay valid. Drives that share a
    /// base identifier are ordered by IORegistry path (which follows the port they
    /// are plugged into); the first keeps the base identifier and the rest get
    /// "#2", "#3", ... appended.
    public static func uniqueIDs(baseIDs: [String], registryPaths: [String]) -> [String] {
        var result = baseIDs
        var indicesByBase: [String: [Int]] = [:]
        for (index, base) in baseIDs.enumerated() {
            indicesByBase[base, default: []].append(index)
        }
        for (base, indices) in indicesByBase where indices.count > 1 {
            let ordered = indices.sorted { lhs, rhs in
                let lhsPath = lhs < registryPaths.count ? registryPaths[lhs] : ""
                let rhsPath = rhs < registryPaths.count ? registryPaths[rhs] : ""
                return lhsPath == rhsPath ? lhs < rhs : lhsPath < rhsPath
            }
            for (rank, index) in ordered.enumerated() where rank > 0 {
                result[index] = "\(base)#\(rank + 1)"
            }
        }
        return result
    }
}

/// What to do with the disc that is in the tray when a burn is requested.
public enum KroutonBurnMediaDecision: Equatable, Sendable {
    /// Start the burn. `overwriteExistingData` is passed to DiscRecording as-is.
    case proceed(overwriteExistingData: Bool)
    /// The disc holds data that the burn would erase, and nobody approved that.
    case refuseWouldDestroyData
    /// The disc is closed write-once media.
    case refuseNotWritable
}

/// Decides whether a burn may use the disc in the tray.
public enum KroutonBurnMediaPolicy {
    /// Blank discs and open write-once discs proceed; rewritable discs with data proceed only
    /// when `allowOverwrite`; closed write-once discs are refused.
    ///
    /// - Parameter allowOverwrite: true only when a person started this burn with
    ///   this disc in the drive. Unattended continuations (auto-load batches) pass false.
    public static func evaluate(
        isBlank: Bool,
        isErasable: Bool,
        isOverwritable: Bool,
        isAppendable: Bool,
        allowOverwrite: Bool
    ) -> KroutonBurnMediaDecision {
        if isBlank {
            return .proceed(overwriteExistingData: false)
        }
        if isErasable || isOverwritable {
            return allowOverwrite ? .proceed(overwriteExistingData: true) : .refuseWouldDestroyData
        }
        if isAppendable {
            // Adding a session to open write-once media leaves the earlier sessions intact.
            return .proceed(overwriteExistingData: false)
        }
        return .refuseNotWritable
    }
}

/// Why preparing a disc image failed. The message is for the user.
public enum KroutonDiscImageError: Error, LocalizedError, Sendable, Equatable {
    case staging(String)

    public var errorDescription: String? {
        switch self {
        case .staging(let message): return message
        }
    }
}

/// Argument arrays for the "save as disc image" destination. No shell is involved.
public enum KroutonDiscImageArguments {
    /// ".iso" and ".cdr" outputs are hybrid optical images; anything else is a .dmg.
    public static func isOpticalImage(outputPath: String) -> Bool {
        let lower = outputPath.lowercased()
        return lower.hasSuffix(".iso") || lower.hasSuffix(".cdr")
    }

    /// The `hdiutil` arguments: `makehybrid` (HFS+, ISO 9660, Joliet and UDF) for .iso and .cdr,
    /// otherwise `create` with an HFS+ .dmg, compressed (UDZO) or read-write (UDRW).
    public static func make(outputPath: String, sourcePath: String, volumeTitle: String, compress: Bool) -> [String] {
        if isOpticalImage(outputPath: outputPath) {
            return ["makehybrid", "-o", outputPath, "-hfs", "-iso", "-joliet", "-udf",
                    "-default-volume-name", volumeTitle, sourcePath]
        }
        return ["create", "-ov", "-srcfolder", sourcePath, "-volname", volumeTitle, "-fs", "HFS+",
                "-format", compress ? "UDZO" : "UDRW", outputPath]
    }
}

/// One file or folder to copy into the temporary burn stage.
public struct KroutonBurnStageItem: Sendable, Equatable {
    /// The file or folder to copy.
    public let source: URL
    /// Its name in the stage, and so on the disc.
    public let name: String

    public init(source: URL, name: String) {
        self.source = source
        self.name = name
    }
}

/// Copies the files of a data burn into a temporary folder, so the burn reads a fixed copy.
public enum KroutonBurnStager {
    /// Copies `items` into a new directory at `stageURL`, off the caller's actor.
    /// Returns nil on success, otherwise a message suitable for the burn report.
    /// Cancelling the calling task stops the copy before the next item.
    public static func stage(_ items: [KroutonBurnStageItem], into stageURL: URL) async -> String? {
        let worker = Task.detached(priority: .userInitiated) { () -> String? in
            let fm = FileManager.default
            do {
                try fm.createDirectory(at: stageURL, withIntermediateDirectories: true)
                var usedNames = Set<String>()
                for item in items {
                    if Task.isCancelled { return "Staging was cancelled." }
                    // HFS+ and Joliet are case-insensitive, so "a.txt" and "A.TXT" collide on disc.
                    guard usedNames.insert(item.name.lowercased()).inserted else {
                        return "Two staged items are both named \"\(item.name)\". Rename or remove one of them."
                    }
                    try fm.copyItem(at: item.source, to: stageURL.appendingPathComponent(item.name))
                }
                return nil
            } catch {
                return "Could not stage files for burning: \(error.localizedDescription)"
            }
        }
        return await withTaskCancellationHandler {
            await worker.value
        } onCancel: {
            worker.cancel()
        }
    }
}
