import Darwin
import Foundation
import OpticalCore

// MARK: - HFS Image Writer (Mac OS 9 and Earlier)

public enum KroutonHFSError: Error, LocalizedError, Equatable, Sendable {
    case tooLarge
    case catalogTooLarge
    case unreadable(String)

    public var errorDescription: String? {
        switch self {
        case .tooLarge: return "Classic HFS holds at most 2 GB per volume; this is larger."
        case .catalogTooLarge: return "There are too many files and folders for one classic HFS disc."
        case .unreadable(let name): return "Krouton couldn't read \(name)."
        }
    }
}

/// Writes a classic HFS (HFS Standard) volume inside an Apple Partition Map, as Mac CD-ROMs were
/// made for System 7 through Mac OS 9. Modern macOS can't write HFS Standard (and since 10.15
/// can't read it), so Krouton writes it itself.
///
/// What a classic Mac needs and this keeps: each file's resource fork
/// (`com.apple.ResourceFork`) and Finder info (`com.apple.FinderInfo`: type, creator, flags),
/// so applications run and documents open with the right program; folders keep their Finder
/// info too. Names become Mac OS Roman, at most 31 characters (27 for the volume), with ":"
/// replaced. Hidden files (starting with ".") are left out.
///
/// Programmer's notes: layout in 512-byte sectors, from the start of the HFS partition: boot
/// blocks (0–1), master directory block (2), volume bitmap (3…), then allocation blocks: the
/// extents-overflow tree, the catalog tree, and every file's data then resource fork, each
/// contiguous so one extent describes it. An alternate MDB sits in the second-to-last sector.
/// The partition map ahead of it has a driver descriptor (block 0), the map's own entry and an
/// `Apple_HFS` entry starting at block 64. Times are Mac time (seconds since 1904, local).
public enum KroutonHFSImageWriter {
    static let mapBlocks = 64
    static let firstCNID: UInt32 = 16

    struct Item {
        var name: [UInt8]
        var url: URL
        var isDir: Bool
        var parent: Int
        var cnid: UInt32
        var children: [Int] = []
        var dataLength: UInt64 = 0
        var resource: [UInt8] = []
        var finderInfo: [UInt8] = [UInt8](repeating: 0, count: 32)
        var modified: UInt32 = 0
        /// First allocation block of each fork (checked to fit 16 bits before use).
        var dataStart: UInt64 = 0
        var resourceStart: UInt64 = 0
    }

    public struct Built: Sendable, Equatable {
        public let bytes: UInt64
        public let files: Int
        public let folders: Int
    }

    // MARK: - Build

    @discardableResult
    public static func build(folder: URL, output: URL, label: String,
                             now: Date = Date(), timeZone: TimeZone = .current) throws -> Built {
        let stamp = macTime(now, timeZone)
        var items = [Item(name: macName(label, limit: 27, fallback: "Untitled"), url: folder, isDir: true, parent: 0, cnid: 2)]
        try scan(folder, parent: 0, into: &items, timeZone: timeZone)
        items[0].modified = stamp

        // Sizes, then the allocation block size that keeps the count under 65,536.
        let forkBytes = items.reduce(UInt64(0)) { $0 + roundUp($1.dataLength, 512) + roundUp(UInt64($1.resource.count), 512) }
        let records = 2 * items.filter(\.isDir).count + items.filter { !$0.isDir }.count
        let catalogNodes = max(8, records / 3 + 16)
        let estimate = forkBytes + UInt64(catalogNodes + 8) * 512 + 64 * 1024
        var blockSize: UInt64 = 512
        while estimate / blockSize > 60_000 { blockSize += 512 }
        guard estimate < 2 * 1024 * 1024 * 1024 - 1024 * 1024 else { throw KroutonHFSError.tooLarge }

        let extentsBlocks = max(1, roundUp(512 * 4, blockSize) / blockSize)
        let catalogBlocks = roundUp(UInt64(catalogNodes) * 512, blockSize) / blockSize
        var next = extentsBlocks + catalogBlocks
        for i in items.indices where !items[i].isDir {
            if items[i].dataLength > 0 {
                items[i].dataStart = next
                next += roundUp(items[i].dataLength, blockSize) / blockSize
            }
            if !items[i].resource.isEmpty {
                items[i].resourceStart = next
                next += roundUp(UInt64(items[i].resource.count), blockSize) / blockSize
            }
        }
        let totalBlocks = next + 1
        guard totalBlocks <= 65_535 else { throw KroutonHFSError.tooLarge }
        let bitmapSectors = (Int(totalBlocks) + 4095) / 4096
        let firstBlockSector = UInt64(3 + bitmapSectors)
        let volumeSectors = firstBlockSector + totalBlocks * blockSize / 512 + 2
        let imageSectors = UInt64(mapBlocks) + volumeSectors

        // Catalog.
        let catalog = try KroutonHFSBTree.build(records: catalogRecords(items, stamp: stamp, blockSize: blockSize),
                                                maxKeyLength: 37, nodeCount: Int(catalogBlocks * blockSize / 512))
        let extents = try KroutonHFSBTree.build(records: [], maxKeyLength: 7, nodeCount: Int(extentsBlocks * blockSize / 512))

        // Write.
        FileManager.default.createFile(atPath: output.path, contents: nil)
        let out = try FileHandle(forWritingTo: output)
        defer { try? out.close() }
        try out.truncate(atOffset: imageSectors * 512)
        let base = UInt64(mapBlocks) * 512
        func put(_ offset: UInt64, _ bytes: [UInt8]) throws {
            try out.seek(toOffset: offset)
            try out.write(contentsOf: Data(bytes))
        }
        try put(0, driverDescriptor(totalBlocks: UInt32(imageSectors)))
        try put(512, mapEntry(count: 2, start: 1, length: UInt32(mapBlocks - 1), name: "Apple", type: "Apple_partition_map", status: 0x3))
        try put(1024, mapEntry(count: 2, start: UInt32(mapBlocks), length: UInt32(volumeSectors), name: "Krouton",
                               type: "Apple_HFS", status: 0x4000_0033))
        let usedBlocks = Int(next)
        var bitmap = [UInt8](repeating: 0, count: bitmapSectors * 512)
        for b in 0..<usedBlocks { bitmap[b / 8] |= 0x80 >> UInt8(b % 8) }
        try put(base + 3 * 512, bitmap)
        let blockOffset = { (block: UInt64) in base + firstBlockSector * 512 + block * blockSize }
        try put(blockOffset(0), extents)
        try put(blockOffset(extentsBlocks), catalog)
        for item in items where !item.isDir {
            if item.dataLength > 0 { try copy(item.url, to: out, at: blockOffset(item.dataStart), length: item.dataLength) }
            if !item.resource.isEmpty { try put(blockOffset(item.resourceStart), item.resource) }
        }
        let systemFolder = blessedFolder(items)
        if let systemFolder, let boot = bootBlocks(items, folder: systemFolder) { try put(base, boot) }
        var mdb = masterDirectoryBlock(items, stamp: stamp, blockSize: blockSize, totalBlocks: UInt16(totalBlocks),
                                       freeBlocks: UInt16(totalBlocks) - UInt16(usedBlocks), firstBlockSector: UInt16(firstBlockSector),
                                       extentsBlocks: UInt16(extentsBlocks), catalogBlocks: UInt16(catalogBlocks))
        // Finder info word 0 names the blessed System Folder, which a Mac boots from.
        if let systemFolder { mdb.replaceSubrange(92..<96, with: KroutonBytes.be32(items[systemFolder].cnid)) }
        try put(base + 2 * 512, mdb)
        try put(base + (volumeSectors - 2) * 512, mdb)
        let files = items.filter { !$0.isDir }.count
        return Built(bytes: imageSectors * 512, files: files, folders: items.count - files - 1)
    }

    // MARK: - System Folder

    /// The folder holding both a System file (type zsys) and a Finder (type FNDR), if any.
    static func blessedFolder(_ items: [Item]) -> Int? {
        items.indices.first { i in
            items[i].isDir && ["zsys", "FNDR"].allSatisfy { type in
                items[i].children.contains { Array(items[$0].finderInfo[0..<4]) == Array(type.utf8) }
            }
        }
    }

    /// The System file's 'boot' resource 1, which holds the volume's boot blocks.
    static func bootBlocks(_ items: [Item], folder: Int) -> [UInt8]? {
        guard let system = items[folder].children.first(where: { Array(items[$0].finderInfo[0..<4]) == Array("zsys".utf8) }) else {
            return nil
        }
        return resource(items[system].resource, type: "boot", id: 1).map { Array($0.prefix(1024)) + [UInt8](repeating: 0, count: max(0, 1024 - $0.count)) }
    }

    /// One resource from a resource fork (Inside Macintosh: More Macintosh Toolbox, 1-121).
    static func resource(_ fork: [UInt8], type: String, id: Int16) -> [UInt8]? {
        func u32(_ at: Int) -> Int? { at + 4 <= fork.count ? Int(fork[at]) << 24 | Int(fork[at + 1]) << 16 | Int(fork[at + 2]) << 8 | Int(fork[at + 3]) : nil }
        func u16(_ at: Int) -> Int? { at + 2 <= fork.count ? Int(fork[at]) << 8 | Int(fork[at + 1]) : nil }
        guard let dataStart = u32(0), let mapStart = u32(4), let typeListOffset = u16(mapStart + 24),
              let typeCount = u16(mapStart + typeListOffset) else { return nil }
        let typeList = mapStart + typeListOffset
        for t in 0...(typeCount & 0xFFFF) {
            let entry = typeList + 2 + t * 8
            guard entry + 8 <= fork.count, let count = u16(entry + 4), let refOffset = u16(entry + 6) else { return nil }
            guard Array(fork[entry..<entry + 4]) == Array(type.utf8) else { continue }
            for r in 0...count {
                let ref = typeList + refOffset + r * 12
                guard let rid = u16(ref), let attrsAndData = u32(ref + 4) else { return nil }
                guard Int16(truncatingIfNeeded: rid) == id else { continue }
                let at = dataStart + (attrsAndData & 0xFF_FFFF)
                guard let length = u32(at), at + 4 + length <= fork.count else { return nil }
                return Array(fork[(at + 4)..<(at + 4 + length)])
            }
        }
        return nil
    }

    // MARK: - Folder Scan

    static func scan(_ folder: URL, parent: Int, into items: inout [Item], timeZone: TimeZone) throws {
        let fm = FileManager.default
        let urls = try fm.contentsOfDirectory(at: folder, includingPropertiesForKeys: [.isDirectoryKey, .fileSizeKey, .contentModificationDateKey])
            .filter { !$0.lastPathComponent.hasPrefix(".") }
            .sorted { $0.lastPathComponent < $1.lastPathComponent }
        var used: [[UInt8]] = []
        for url in urls {
            let values = try url.resourceValues(forKeys: [.isDirectoryKey, .fileSizeKey, .contentModificationDateKey])
            var name = macName(url.lastPathComponent, limit: 31, fallback: "Untitled")
            var n = 1
            while used.contains(where: { KroutonHFSOrder.compare($0, name) == 0 }) {
                let tag = Array(" \(n)".utf8)
                name = Array(macName(url.lastPathComponent, limit: 31 - tag.count, fallback: "Untitled")) + tag
                n += 1
            }
            used.append(name)
            var item = Item(name: name, url: url, isDir: values.isDirectory ?? false, parent: parent,
                            cnid: firstCNID + UInt32(items.count - 1))
            item.modified = macTime(values.contentModificationDate ?? Date(), timeZone)
            if let info = xattr(url, "com.apple.FinderInfo"), info.count == 32 { item.finderInfo = info }
            if !item.isDir {
                item.dataLength = UInt64(values.fileSize ?? 0)
                item.resource = xattr(url, "com.apple.ResourceFork") ?? []
            }
            let index = items.count
            items.append(item)
            items[parent].children.append(index)
            if item.isDir { try scan(url, parent: index, into: &items, timeZone: timeZone) }
        }
    }

    static func xattr(_ url: URL, _ name: String) -> [UInt8]? {
        let size = getxattr(url.path, name, nil, 0, 0, XATTR_NOFOLLOW)
        guard size > 0 else { return nil }
        var buffer = [UInt8](repeating: 0, count: size)
        let read = getxattr(url.path, name, &buffer, size, 0, XATTR_NOFOLLOW)
        return read == size ? buffer : nil
    }

    static func copy(_ url: URL, to out: FileHandle, at offset: UInt64, length: UInt64) throws {
        guard let input = try? FileHandle(forReadingFrom: url) else { throw KroutonHFSError.unreadable(url.lastPathComponent) }
        defer { try? input.close() }
        try out.seek(toOffset: offset)
        var left = length
        while left > 0, let chunk = try input.read(upToCount: Int(min(left, 1 << 20))), !chunk.isEmpty {
            try out.write(contentsOf: chunk)
            left -= UInt64(chunk.count)
        }
    }

    // MARK: - Names and Times

    /// Mac OS Roman, ":" replaced, cut to `limit` bytes.
    static func macName(_ text: String, limit: Int, fallback: String) -> [UInt8] {
        let cleaned = text.replacingOccurrences(of: ":", with: "-").precomposedStringWithCanonicalMapping
        let bytes = cleaned.data(using: .macOSRoman, allowLossyConversion: true).map { [UInt8]($0) } ?? []
        let cut = Array(bytes.prefix(limit))
        return cut.isEmpty ? Array(fallback.utf8) : cut
    }

    /// Seconds since 1 January 1904 in local time, as classic Mac OS keeps them.
    static func macTime(_ date: Date, _ zone: TimeZone) -> UInt32 {
        let local = date.timeIntervalSince1970 + Double(zone.secondsFromGMT(for: date))
        return UInt32(clamping: Int64(local) + 2_082_844_800)
    }

    static func roundUp(_ v: UInt64, _ unit: UInt64) -> UInt64 { (v + unit - 1) / unit * unit }
}
