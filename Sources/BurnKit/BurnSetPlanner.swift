import Foundation
import OpticalCore

// Turns "these files and folders, on discs of this size" into the per-disc file
// lists that BurnSetStager freezes. Folders are expanded to their files, so a
// folder larger than one disc continues on the next disc with its paths intact.
//
// The space estimate is deliberately conservative, and it is only an estimate:
// the caller must still compare each finished image with the disc capacity
// (`BurnSetPlanError.imageExceedsDisc`) before anything is burned.

public struct SpanInputFile: Identifiable, Sendable, Equatable {
    /// Path on the disc, "/"-separated. Unique within a set.
    public let relativePath: String
    public let sourceURL: URL
    public let byteCount: Int64
    public var id: String { relativePath }

    public init(relativePath: String, sourceURL: URL, byteCount: Int64) {
        self.relativePath = relativePath
        self.sourceURL = sourceURL
        self.byteCount = byteCount
    }
}

public enum BurnSetPlanError: Error, LocalizedError, Sendable, Equatable {
    case nothingToBurn
    case duplicatePath(String)
    case fileTooLarge(path: String, bytes: Int64, capacityBytes: Int64)
    case discTooSmall(capacityBytes: Int64)
    case imageExceedsDisc(discIndex: Int, imageBytes: Int64, capacityBytes: Int64)

    public var errorDescription: String? {
        let format = ByteCountFormatter()
        format.countStyle = .file
        switch self {
        case .nothingToBurn:
            return "There are no files to burn."
        case .duplicatePath(let path):
            return "Two items would land at the same place on disc: \(path). Rename or remove one of them."
        case .fileTooLarge(let path, let bytes, let capacity):
            return "\(path) is \(format.string(fromByteCount: bytes)), which is larger than one disc holds (\(format.string(fromByteCount: capacity)) usable). Choose a larger disc type."
        case .discTooSmall(let capacity):
            return "A \(format.string(fromByteCount: capacity)) disc is too small for a set with this many files. Choose a larger disc type."
        case .imageExceedsDisc(let index, let imageBytes, let capacity):
            return "The image for Disc \(index) came out at \(format.string(fromByteCount: imageBytes)), over the \(format.string(fromByteCount: capacity)) disc size. Nothing was burned. Choose a larger disc type."
        }
    }
}

public enum BurnSetPlanner {
    public static let sectorSize: Int64 = 2048

    /// Space a file takes on disc for planning: its data rounded up to whole sectors,
    /// plus one sector for its directory entries across the ISO, Joliet and UDF trees.
    public static func plannedBytes(forFileOfSize bytes: Int64) -> Int64 {
        ((max(0, bytes) + sectorSize - 1) / sectorSize) * sectorSize + sectorSize
    }

    /// Disc capacity left for files after filesystem structures and the set manifests.
    /// The manifests list every file in the set on every disc, so the reserve grows with `totalFileCount`.
    public static func usableBytes(discCapacityBytes: Int64, totalFileCount: Int) -> Int64 {
        let fixedReserve = max(Int64(8 * 1024 * 1024), discCapacityBytes / 64)
        return discCapacityBytes - fixedReserve - Int64(totalFileCount) * 512
    }

    /// Expands staged items into individual files, sorted by their path on disc.
    /// Folders are walked recursively; `.DS_Store` files and anything that is not a regular file are skipped.
    public static func expand(_ entries: [(url: URL, name: String)]) throws -> [SpanInputFile] {
        let fm = FileManager.default
        let keys: [URLResourceKey] = [.isRegularFileKey, .fileSizeKey]
        var files: [SpanInputFile] = []
        var seen = Set<String>()

        func add(_ url: URL, at path: String) throws {
            guard url.lastPathComponent != ".DS_Store" else { return }
            let values = try url.resourceValues(forKeys: Set(keys))
            guard values.isRegularFile == true else { return }
            // Joliet and HFS+ are case-insensitive, so compare paths that way.
            guard seen.insert(path.lowercased()).inserted else { throw BurnSetPlanError.duplicatePath(path) }
            files.append(SpanInputFile(relativePath: path, sourceURL: url, byteCount: Int64(values.fileSize ?? 0)))
        }

        for entry in entries {
            var isDirectory: ObjCBool = false
            guard fm.fileExists(atPath: entry.url.path, isDirectory: &isDirectory) else {
                throw CocoaError(.fileNoSuchFile, userInfo: [NSFilePathErrorKey: entry.url.path])
            }
            if isDirectory.boolValue {
                guard let walker = fm.enumerator(
                    at: entry.url, includingPropertiesForKeys: keys, options: [.producesRelativePathURLs]
                ) else { continue }
                for case let child as URL in walker {
                    try add(child, at: entry.name + "/" + child.relativePath)
                }
            } else {
                try add(entry.url, at: entry.name)
            }
        }
        guard !files.isEmpty else { throw BurnSetPlanError.nothingToBurn }
        return files.sorted { $0.relativePath < $1.relativePath }
    }

    /// Splits `files` across discs in order, filling each disc before starting the next.
    public static func plan(_ files: [SpanInputFile], discCapacityBytes: Int64) throws -> [[StagedInputFile]] {
        guard !files.isEmpty else { throw BurnSetPlanError.nothingToBurn }
        let usable = usableBytes(discCapacityBytes: discCapacityBytes, totalFileCount: files.count)
        guard usable > sectorSize else { throw BurnSetPlanError.discTooSmall(capacityBytes: discCapacityBytes) }

        let planner = DiscPlanner<SpanInputFile>(capacity: DiscCapacity(units: usable)) { file, _ in
            ItemCost.exact(plannedBytes(forFileOfSize: file.byteCount))
        }
        let result = planner.plan(files)
        for issue in result.issues {
            if case .itemExceedsDisc(let id, _, _) = issue, let file = files.first(where: { $0.id == id }) {
                throw BurnSetPlanError.fileTooLarge(path: file.relativePath, bytes: file.byteCount, capacityBytes: usable)
            }
        }
        return result.discs.map { disc in
            disc.items.map { StagedInputFile(sourceURL: $0.sourceURL, relativePathOnDisc: $0.relativePath) }
        }
    }
}
