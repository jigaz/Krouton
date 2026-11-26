import Foundation

// MARK: - UDF Image Writer

/// Builds a disc image from a folder in one of two profiles of Krouton Server's writer
/// (`krouton-server/crates/server-core/src/disc`), ported line for line so the same folder gives
/// the same bytes on both (`Vectors/udf-bd-v1.sha256`, `Vectors/udf-dvd-v1.sha256`):
///
/// - `.bluRay`: UDF 2.50 with a duplicated metadata partition and no ISO 9660, as BD-ROM, BD-R
///   and AVCHD discs are laid out. Also used for large-file data discs. `hdiutil` can't write it.
/// - `.dvdVideo`: ISO 9660 level 1 + UDF 1.02, with the VIDEO_TS files first and in the order
///   players expect (VIDEO_TS.IFO/VOB/BUP, then each title set's IFO, VOBs and BUP), which
///   DiscRecording and `hdiutil` don't promise.
///
/// Layout, in 2048-byte sectors: the ISO 9660 descriptors (DVD only) and the recognition
/// sequence from 16, volume descriptor sequences (32, 48), integrity descriptor (64), anchor
/// (256), then one read-only partition from 257: for Blu-ray the metadata file entries and the
/// metadata partition (file set, entries, directories) twice in 64 KiB units; for DVD the file
/// set, entries and directories, then the ISO path tables and directories; then file contents.
/// A second anchor ends it.
public enum KroutonUDFImageWriter {
    public enum Profile: Sendable, Equatable {
        case bluRay
        case dvdVideo
    }

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
        profile: Profile = .bluRay,
        now: UInt64 = UInt64(max(0, Date().timeIntervalSince1970)),
        progress: (Double) -> Void = { _ in },
        isCancelled: () -> Bool = { false }
    ) throws -> Built {
        let nodes = try scan(folder)
        let layout = try Layout(nodes: nodes, profile: profile)
        let volume = KroutonUDFVolume(label: volumeName(label), created: KroutonUDFTime(unix: now),
                                      setID: setID(label: label, now: now, count: nodes.count),
                                      revision: profile == .dvdVideo ? 0x0102 : 0x0250)
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
            try writeVolume(&image, nodes: nodes, layout: layout, volume: volume, label: label, now: now)
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
        var profile: Profile
        var entryBlock: [UInt32]
        var streamBlock: [UInt32]
        var streamLength: [UInt64]
        var metaStart: UInt64 = 0
        var mirrorStart: UInt64 = 0
        var fileBlock: [UInt32]
        var partitionLength: UInt64
        /// DVD-Video: the ISO 9660 names, path tables (L, M) and each directory's sector.
        var iso: ISONames?
        var isoTables: (UInt32, UInt32) = (0, 0)
        var isoDirs: [UInt32] = []

        var metadata: Bool { profile == .bluRay }
        var totalSectors: UInt64 { KroutonUDFImageWriter.partitionStart + partitionLength + 1 }
        var metadataBlocks: UInt64 { mirrorStart - metaStart }
        /// The partition reference of the file set: 1 (the metadata map) for UDF 2.50.
        var namespacePartition: UInt16 { metadata ? 1 : 0 }

        init(nodes: [Node], profile: Profile) throws {
            self.profile = profile
            if profile == .dvdVideo, nodes.contains(where: { $0.size >= 4 << 30 }) {
                throw KroutonUDFError.dvdFileTooLarge
            }
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
            var cursor = next
            let align = KroutonUDFImageWriter.align
            if profile == .bluRay {
                let size = (next + align - 1) / align * align
                metaStart = align
                mirrorStart = metaStart + size
                cursor = mirrorStart + size
            } else {
                let names = ISONames(nodes: nodes, level1: true)
                let base = KroutonUDFImageWriter.partitionStart
                let table = (names.pathTableBytes + 2047) / 2048
                isoTables = (try u32(base + cursor), try u32(base + cursor + table))
                cursor += 2 * table
                isoDirs = Array(repeating: 0, count: n)
                for dir in names.pathOrder {
                    isoDirs[dir] = try u32(base + cursor)
                    cursor += (names.dirBytes[dir] + 2047) / 2048
                }
                iso = names
            }
            if profile == .bluRay { cursor = (cursor + align - 1) / align * align }
            fileBlock = Array(repeating: 0, count: n)
            for i in KroutonUDFImageWriter.fileOrder(nodes, profile: profile) where nodes[i].size > 0 {
                fileBlock[i] = try u32(cursor)
                cursor += (nodes[i].size + 2047) / 2048
            }
            partitionLength = cursor
            _ = try u32(KroutonUDFImageWriter.partitionStart + cursor + 1)
        }

        func icb(_ i: Int) -> KroutonUDFLongAD {
            KroutonUDFLongAD(length: 2048, block: entryBlock[i], partition: namespacePartition,
                             unique: UInt32(truncatingIfNeeded: KroutonUDFImageWriter.uniqueID(i)))
        }
    }

    // MARK: - File Order

    /// Where file contents go. For DVD-Video, `VIDEO_TS` comes first in the order players expect.
    static func fileOrder(_ nodes: [Node], profile: Profile) -> [Int] {
        var first: [Int] = []
        if profile == .dvdVideo,
           let video = nodes[0].children.first(where: { nodes[$0].isDir && asciiUpper(nodes[$0].name) == "VIDEO_TS" }) {
            first = nodes[video].children.filter { !nodes[$0].isDir }.sorted {
                let a = dvdKey(nodes[$0].name), b = dvdKey(nodes[$1].name)
                if a != b { return a < b }
                return nodes[$0].name.utf8.lexicographicallyPrecedes(nodes[$1].name.utf8)
            }
        }
        let placed = Set(first)
        return first + nodes.indices.filter { !nodes[$0].isDir && !placed.contains($0) }
    }

    /// VIDEO_TS.IFO/VOB/BUP, then for each title set its IFO, menu VOB, title VOBs 1–9 and BUP;
    /// anything else after them by name.
    static func dvdKey(_ name: String) -> (UInt8, UInt32, UInt8) {
        let upper = asciiUpper(name)
        func rank(_ ext: Substring) -> UInt8? {
            switch ext {
            case "IFO": return 0
            case "VOB": return 1
            case "BUP": return 11
            default: return nil
            }
        }
        if upper.hasPrefix("VIDEO_TS."), let r = rank(upper.dropFirst(9)) { return (0, 0, r == 11 ? 2 : r) }
        let b = Array(upper.utf8)
        if b.count == 12, upper.count == 12, upper.hasPrefix("VTS_"), b[6] == UInt8(ascii: "_"), b[8] == UInt8(ascii: ".") {
            let chars = Array(upper)
            if let title = UInt32(String(chars[4..<6])), let part = chars[7].wholeNumberValue, part < 10,
               let r = rank(Substring(String(chars[9...]))) {
                return (1, title, r == 1 ? 1 + UInt8(part) : r)
            }
        }
        return (2, 0, 0)
    }

    static func asciiUpper(_ text: String) -> String {
        String(String.UnicodeScalarView(text.unicodeScalars.map { ("a"..."z").contains($0) ? Unicode.Scalar($0.value - 32)! : $0 }))
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

        /// The partition holding the file set: both copies of the metadata partition for UDF
        /// 2.50, the physical partition otherwise.
        func putNamespace(_ block: UInt64, _ bytes: [UInt8]) throws {
            let base = KroutonUDFImageWriter.partitionStart
            if layout.metadata {
                try put(base + layout.metaStart + block, bytes)
                try put(base + layout.mirrorStart + block, bytes)
            } else {
                try put(base + block, bytes)
            }
        }
    }

    static func writeVolume(_ image: inout SectorFile, nodes: [Node], layout: Layout, volume v: KroutonUDFVolume,
                            label: String, now: UInt64) throws {
        let total = layout.totalSectors
        // Volume recognition: the ISO 9660 descriptors first when there is a bridge, then UDF's.
        var sector: UInt64 = 16
        if let iso = layout.iso {
            try image.put(sector, iso.volumeDescriptor(name: KroutonISO.volumeName(label), sectors: try u32(total), created: now,
                                                       rootSector: layout.isoDirs[0], lTable: layout.isoTables.0, mTable: layout.isoTables.1))
            try image.put(sector + 1, KroutonISO.terminator())
            sector += 2
        }
        for (offset, id) in ["BEA01", v.nsr, "TEA01"].enumerated() {
            try image.put(sector + UInt64(offset), KroutonUDF.recognition(id))
        }
        let partitionLength = try u32(layout.partitionLength)
        let map = layout.metadata ? KroutonUDF.MetadataMap(file: 0, mirror: 1, alignment: 32) : nil
        let fileSet = KroutonUDFLongAD(length: 2048, block: 0, partition: layout.namespacePartition, unique: 0)
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
        let sizes = layout.metadata ? [partitionLength, try u32(layout.metadataBlocks)] : [partitionLength]
        try image.put(64, KroutonUDF.integrity(v, location: 64, partitionSizes: sizes, nextUnique: firstUniqueID + UInt64(nodes.count),
                                               files: UInt32(nodes.count - 1 - folders), folders: UInt32(folders)))
        try image.put(65, KroutonUDF.terminating(v, location: 65))
        let vds = (UInt32(16 * 2048), UInt32(32)), reserve = (UInt32(16 * 2048), UInt32(48))
        try image.put(256, KroutonUDF.anchor(v, location: 256, main: vds, reserve: reserve))
        let last = try u32(total - 1)
        try image.put(total - 1, KroutonUDF.anchor(v, location: last, main: vds, reserve: reserve))

        if layout.metadata {
            let metaBytes = layout.metadataBlocks * 2048
            let metadataFiles: [(UInt32, KroutonUDF.FileType, UInt64)] =
                [(0, .metadata, layout.metaStart), (1, .metadataMirror, layout.mirrorStart)]
            for (block, type, start) in metadataFiles {
                let startBlock = try u32(start)
                let entry = KroutonUDF.Entry(fileType: type, unique: 0, length: metaBytes, links: 1, modified: v.created,
                                             allocation: .short(KroutonUDF.extents(metaBytes, block: startBlock)))
                try image.put(partitionStart + UInt64(block), try KroutonUDF.fileEntry(v, location: block, entry: entry))
            }
        }

        try image.putNamespace(0, KroutonUDF.fileSet(v, location: 0, root: layout.icb(0)))
        try image.putNamespace(1, KroutonUDF.terminating(v, location: 1))
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
                let allocation: KroutonUDF.Allocation = layout.metadata
                    ? .long(pieces.map { KroutonUDFLongAD(length: $0.length, block: $0.block, partition: 0, unique: 0) })
                    : .short(pieces)
                entry = KroutonUDF.Entry(fileType: .file, unique: uniqueID(i), length: node.size, links: 1, modified: modified,
                                         allocation: allocation)
            }
            try image.putNamespace(UInt64(layout.entryBlock[i]),
                                   try KroutonUDF.fileEntry(v, location: layout.entryBlock[i], extended: layout.metadata, entry: entry))
            if node.isDir {
                try image.putNamespace(UInt64(layout.streamBlock[i]), directoryStream(i, nodes: nodes, layout: layout, volume: v))
            }
        }

        // DVD-Video: ISO 9660 path tables and directories, pointing at the same file contents.
        if let iso = layout.iso {
            let fileSector = nodes.indices.map { nodes[$0].size > 0 ? UInt32(partitionStart) + layout.fileBlock[$0] : 0 }
            let (l, m) = iso.pathTables(nodes: nodes, dirSector: layout.isoDirs)
            try image.put(UInt64(layout.isoTables.0), l)
            try image.put(UInt64(layout.isoTables.1), m)
            for (at, extent) in iso.directories(nodes: nodes, dirSector: layout.isoDirs, fileSector: fileSector) {
                try image.put(UInt64(at), extent)
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
    case dvdFileTooLarge

    public var errorDescription: String? {
        switch self {
        case .nameTooLong(let name): return "“\(name)” is too long a name for a disc."
        case .tooLarge: return "The disc would be too large to describe."
        case .tooFragmented: return "A file is too large for one disc entry."
        case .changed(let name): return "\(name) changed while the disc was being built."
        case .dvdFileTooLarge: return "A DVD-Video disc can't hold a file of 4 GiB or more."
        }
    }
}
