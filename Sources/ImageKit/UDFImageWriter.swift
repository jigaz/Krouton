import Foundation

// MARK: - UDF 2.50 Image Writer

/// Builds a Blu-ray style disc image (UDF 2.50 with a duplicated metadata partition, no ISO
/// 9660) from a folder, the way BD-ROM, BD-R and AVCHD/BD-on-DVD discs are laid out.
/// `hdiutil makehybrid` cannot write UDF 2.50, so Krouton writes it itself.
///
/// This is the Blu-ray profile of Krouton Server's writer (`krouton-server/crates/server-core/
/// src/disc`) ported line for line: the same folder gives the same bytes on both, which
/// `Vectors/udf-bd-v1.sha256` pins, and the server's CI mounts that writer's images with the
/// Linux, macOS and Windows drivers.
///
/// Layout, in 2048-byte sectors: recognition sequence (16–18), volume descriptor sequences
/// (32, 48), integrity descriptor (64), anchor (256), then one read-only partition from 257:
/// the metadata file entry and its mirror's, the metadata partition (file set, entries and
/// directories) and its copy in 64 KiB units, then file contents. A second anchor ends it.
public enum KroutonUDFImageWriter {
    static let partitionStart: UInt64 = 257
    static let align: UInt64 = 32
    static let firstUniqueID: UInt64 = 16

    public struct Built: Sendable, Equatable {
        public let sectors: UInt64
        public let files: Int
        public let folders: Int
    }

    /// One file or folder, in breadth-first order with names sorted by their UTF-8 bytes.
    struct Node {
        var name: String
        var url: URL
        var parent: Int
        var mtime: UInt64
        var isDir: Bool
        var size: UInt64
        var children: [Int] = []
    }

    /// Writes the image of `folder` to `output`. `now` (Unix seconds) dates the volume.
    public static func build(
        folder: URL,
        output: URL,
        label: String,
        now: UInt64 = UInt64(max(0, Date().timeIntervalSince1970)),
        progress: (Double) -> Void = { _ in },
        isCancelled: () -> Bool = { false }
    ) throws -> Built {
        let nodes = try scan(folder)
        let layout = try Layout(nodes: nodes)
        let volume = KroutonUDFVolume(label: volumeName(label), created: KroutonUDFTime(unix: now),
                                      setID: setID(label: label, now: now, count: nodes.count))
        let fm = FileManager.default
        if fm.fileExists(atPath: output.path) { try fm.removeItem(at: output) }
        guard fm.createFile(atPath: output.path, contents: nil) else {
            throw CocoaError(.fileWriteUnknown, userInfo: [NSFilePathErrorKey: output.path])
        }
        do {
            let handle = try FileHandle(forWritingTo: output)
            defer { try? handle.close() }
            try handle.truncate(atOffset: layout.totalSectors * 2048)
            var image = SectorFile(handle: handle, layout: layout)
            try writeVolume(&image, nodes: nodes, layout: layout, volume: volume)
            try copyContents(&image, nodes: nodes, layout: layout, progress: progress, isCancelled: isCancelled)
            try handle.synchronize()
        } catch {
            try? fm.removeItem(at: output)
            throw error
        }
        let folders = nodes.dropFirst().filter(\.isDir).count
        return Built(sectors: layout.totalSectors, files: nodes.count - 1 - folders, folders: folders)
    }

    // MARK: - Folder

    static func scan(_ root: URL) throws -> [Node] {
        let keys: [URLResourceKey] = [.isDirectoryKey, .isRegularFileKey, .fileSizeKey, .contentModificationDateKey]
        func mtime(_ values: URLResourceValues) -> UInt64 {
            UInt64(max(0, (values.contentModificationDate ?? Date(timeIntervalSince1970: 0)).timeIntervalSince1970.rounded(.down)))
        }
        let rootValues = try root.resourceValues(forKeys: Set(keys))
        var nodes = [Node(name: "", url: root, parent: 0, mtime: mtime(rootValues), isDir: true, size: 0)]
        var next = 0
        while next < nodes.count {
            if nodes[next].isDir {
                var entries: [Node] = []
                for url in try FileManager.default.contentsOfDirectory(at: nodes[next].url, includingPropertiesForKeys: keys) {
                    let values = try url.resourceValues(forKeys: Set(keys))
                    let isDir = values.isDirectory == true
                    guard isDir || values.isRegularFile == true else { continue }
                    let name = url.lastPathComponent
                    guard KroutonUDF.cs0(name, max: Int.max).count <= 255 else {
                        throw KroutonUDFError.nameTooLong(name)
                    }
                    entries.append(Node(name: name, url: url, parent: next, mtime: mtime(values), isDir: isDir,
                                        size: isDir ? 0 : UInt64(values.fileSize ?? 0)))
                }
                entries.sort { $0.name.utf8.lexicographicallyPrecedes($1.name.utf8) }
                let first = nodes.count
                nodes[next].children = Array(first..<first + entries.count)
                nodes += entries
            }
            next += 1
        }
        return nodes
    }

    /// The label as typed, without control characters, at most 126 characters.
    static func volumeName(_ label: String) -> String {
        let scalars = label.trimmingCharacters(in: .whitespacesAndNewlines).unicodeScalars
            .filter { $0.properties.generalCategory != .control }
        let name = String(String.UnicodeScalarView(scalars.prefix(126))).trimmingCharacters(in: .whitespacesAndNewlines)
        return name.isEmpty ? "Krouton" : name
    }

    static func setID(label: String, now: UInt64, count: Int) -> String {
        var hash: UInt64 = 0x811C_9DC5
        for byte in label.utf8 { hash = (hash ^ UInt64(byte)) &* 0x0100_0193 }
        hash &= 0xFFFF_FFFF
        return String(format: "%08llX%08llX", now & 0xFFFF_FFFF, hash ^ (UInt64(count) & 0xFFFF_FFFF))
    }

    // MARK: - Layout

    struct Layout {
        var entryBlock: [UInt32]
        var streamBlock: [UInt32]
        var streamLength: [UInt64]
        var metaStart: UInt64
        var mirrorStart: UInt64
        var fileBlock: [UInt32]
        var partitionLength: UInt64

        var totalSectors: UInt64 { KroutonUDFImageWriter.partitionStart + partitionLength + 1 }
        var metadataBlocks: UInt64 { mirrorStart - metaStart }

        init(nodes: [Node]) throws {
            let n = nodes.count
            entryBlock = Array(repeating: 0, count: n)
            streamBlock = Array(repeating: 0, count: n)
            streamLength = Array(repeating: 0, count: n)
            var next: UInt64 = 2 // file set descriptor and its terminator
            for (i, node) in nodes.enumerated() {
                entryBlock[i] = try u32(next)
                next += 1
                if node.isDir {
                    let names = node.children.reduce(0) { $0 + KroutonUDF.fidLength(KroutonUDF.cs0(nodes[$1].name).count) }
                    streamLength[i] = UInt64(KroutonUDF.fidLength(0) + names)
                    streamBlock[i] = try u32(next)
                    next += (streamLength[i] + 2047) / 2048
                }
            }
            let size = (next + KroutonUDFImageWriter.align - 1) / KroutonUDFImageWriter.align * KroutonUDFImageWriter.align
            metaStart = KroutonUDFImageWriter.align
            mirrorStart = metaStart + size
            var cursor = mirrorStart + size
            fileBlock = Array(repeating: 0, count: n)
            for (i, node) in nodes.enumerated() where !node.isDir && node.size > 0 {
                fileBlock[i] = try u32(cursor)
                cursor += (node.size + 2047) / 2048
            }
            partitionLength = cursor
            _ = try u32(KroutonUDFImageWriter.partitionStart + cursor + 1)
        }

        func icb(_ i: Int) -> KroutonUDFLongAD {
            KroutonUDFLongAD(length: 2048, block: entryBlock[i], partition: 1,
                             unique: UInt32(truncatingIfNeeded: KroutonUDFImageWriter.uniqueID(i)))
        }
    }

    static func uniqueID(_ i: Int) -> UInt64 { i == 0 ? 0 : firstUniqueID + UInt64(i - 1) }

    static func u32(_ value: UInt64) throws -> UInt32 {
        guard let v = UInt32(exactly: value) else { throw KroutonUDFError.tooLarge }
        return v
    }

    // MARK: - Writing

    struct SectorFile {
        let handle: FileHandle
        let layout: Layout

        func put(_ sector: UInt64, _ bytes: [UInt8]) throws {
            try handle.seek(toOffset: sector * 2048)
            try handle.write(contentsOf: bytes)
        }

        /// Both copies of the metadata partition.
        func putMetadata(_ block: UInt64, _ bytes: [UInt8]) throws {
            try put(KroutonUDFImageWriter.partitionStart + layout.metaStart + block, bytes)
            try put(KroutonUDFImageWriter.partitionStart + layout.mirrorStart + block, bytes)
        }
    }

    static func writeVolume(_ image: inout SectorFile, nodes: [Node], layout: Layout, volume v: KroutonUDFVolume) throws {
        let total = layout.totalSectors
        for (offset, id) in ["BEA01", "NSR03", "TEA01"].enumerated() {
            try image.put(16 + UInt64(offset), KroutonUDF.recognition(id))
        }
        let partitionLength = try u32(layout.partitionLength)
        let map = KroutonUDF.MetadataMap(file: 0, mirror: 1, alignment: 32)
        let fileSet = KroutonUDFLongAD(length: 2048, block: 0, partition: 1, unique: 0)
        for start in [UInt32(32), 48] {
            let s = UInt64(start)
            try image.put(s, KroutonUDF.primary(v, vdsn: 0, location: start))
            try image.put(s + 1, KroutonUDF.implementationUse(v, vdsn: 1, location: start + 1))
            try image.put(s + 2, KroutonUDF.partition(v, vdsn: 2, location: start + 2, start: UInt32(partitionStart), length: partitionLength))
            try image.put(s + 3, KroutonUDF.logicalVolume(v, vdsn: 3, location: start + 3, fileSet: fileSet, integrity: (4096, 64), metadata: map))
            try image.put(s + 4, KroutonUDF.unallocatedSpace(v, vdsn: 4, location: start + 4))
            try image.put(s + 5, KroutonUDF.terminating(v, location: start + 5))
        }
        let folders = nodes.dropFirst().filter(\.isDir).count
        let metadataLength = try u32(layout.metadataBlocks)
        let sizes = [partitionLength, metadataLength]
        try image.put(64, KroutonUDF.integrity(v, location: 64, partitionSizes: sizes, nextUnique: firstUniqueID + UInt64(nodes.count),
                                               files: UInt32(nodes.count - 1 - folders), folders: UInt32(folders)))
        try image.put(65, KroutonUDF.terminating(v, location: 65))
        let vds = (UInt32(16 * 2048), UInt32(32)), reserve = (UInt32(16 * 2048), UInt32(48))
        try image.put(256, KroutonUDF.anchor(v, location: 256, main: vds, reserve: reserve))
        let last = try u32(total - 1)
        try image.put(total - 1, KroutonUDF.anchor(v, location: last, main: vds, reserve: reserve))

        let metaBytes = layout.metadataBlocks * 2048
        let metadataFiles: [(UInt32, KroutonUDF.FileType, UInt64)] =
            [(0, .metadata, layout.metaStart), (1, .metadataMirror, layout.mirrorStart)]
        for (block, type, start) in metadataFiles {
            let startBlock = try u32(start)
            let entry = KroutonUDF.Entry(fileType: type, unique: 0, length: metaBytes, links: 1, modified: v.created,
                                         allocation: .short(KroutonUDF.extents(metaBytes, block: startBlock)))
            try image.put(partitionStart + UInt64(block), try KroutonUDF.fileEntry(v, location: block, entry: entry))
        }

        try image.putMetadata(0, KroutonUDF.fileSet(v, location: 0, root: layout.icb(0)))
        try image.putMetadata(1, KroutonUDF.terminating(v, location: 1))
        for (i, node) in nodes.enumerated() {
            let modified = KroutonUDFTime(unix: node.mtime)
            let entry: KroutonUDF.Entry
            if node.isDir {
                let subfolders = node.children.filter { nodes[$0].isDir }.count
                entry = KroutonUDF.Entry(fileType: .directory, unique: uniqueID(i), length: layout.streamLength[i],
                                         links: UInt16(min(Int(UInt16.max), 1 + subfolders)), modified: modified,
                                         allocation: .short(KroutonUDF.extents(layout.streamLength[i], block: layout.streamBlock[i])))
            } else {
                let pieces = KroutonUDF.extents(node.size, block: layout.fileBlock[i])
                entry = KroutonUDF.Entry(fileType: .file, unique: uniqueID(i), length: node.size, links: 1, modified: modified,
                                         allocation: .long(pieces.map { KroutonUDFLongAD(length: $0.length, block: $0.block, partition: 0, unique: 0) }))
            }
            try image.putMetadata(UInt64(layout.entryBlock[i]), try KroutonUDF.fileEntry(v, location: layout.entryBlock[i], entry: entry))
            if node.isDir {
                try image.putMetadata(UInt64(layout.streamBlock[i]), directoryStream(i, nodes: nodes, layout: layout, volume: v))
            }
        }
    }

    static func directoryStream(_ i: Int, nodes: [Node], layout: Layout, volume v: KroutonUDFVolume) -> [UInt8] {
        let start = layout.streamBlock[i]
        var stream: [UInt8] = []
        var records = [(UInt8(KroutonUDF.fidDirectory | KroutonUDF.fidParent), [UInt8](), layout.icb(nodes[i].parent))]
        for child in nodes[i].children {
            records.append((nodes[child].isDir ? KroutonUDF.fidDirectory : 0, KroutonUDF.cs0(nodes[child].name), layout.icb(child)))
        }
        for (flags, name, icb) in records {
            let block = start + UInt32(stream.count / 2048)
            stream += KroutonUDF.fid(v, location: block, characteristics: flags, name: name, icb: icb)
        }
        return stream
    }

    static func copyContents(_ image: inout SectorFile, nodes: [Node], layout: Layout,
                             progress: (Double) -> Void, isCancelled: () -> Bool) throws {
        let total = max(1, nodes.reduce(UInt64(0)) { $0 + $1.size })
        var done: UInt64 = 0
        for (i, node) in nodes.enumerated() where !node.isDir && node.size > 0 {
            let source = try FileHandle(forReadingFrom: node.url)
            defer { try? source.close() }
            try image.handle.seek(toOffset: (partitionStart + UInt64(layout.fileBlock[i])) * 2048)
            var left = node.size
            while left > 0 {
                if isCancelled() { throw CancellationError() }
                guard let chunk = try source.read(upToCount: Int(min(left, 1 << 20))), !chunk.isEmpty else {
                    throw KroutonUDFError.changed(node.name)
                }
                try image.handle.write(contentsOf: chunk)
                left -= UInt64(chunk.count)
                done += UInt64(chunk.count)
                progress(Double(done) / Double(total))
            }
        }
    }
}

enum KroutonUDFError: Error, LocalizedError, Sendable, Equatable {
    case nameTooLong(String)
    case tooLarge
    case tooFragmented
    case changed(String)

    public var errorDescription: String? {
        switch self {
        case .nameTooLong(let name): return "“\(name)” is too long a name for a disc."
        case .tooLarge: return "The disc would be too large to describe."
        case .tooFragmented: return "A file is too large for one disc entry."
        case .changed(let name): return "\(name) changed while the disc was being built."
        }
    }
}
