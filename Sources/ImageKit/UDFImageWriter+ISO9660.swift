import Foundation

// MARK: - ISO 9660 Bridge (DVD-Video)

/// The ISO 9660 side of a DVD-Video bridge disc (ECMA-119, level 1: 8.3 upper-case names),
/// ported from Krouton Server's `disc/iso.rs` so the same folder gives the same bytes
/// (`Vectors/udf-dvd-v1.sha256`). File contents are shared with UDF; only the directories and
/// path tables take space of their own.
extension KroutonUDFImageWriter {
    struct ISONames {
        /// Recorded identifier bytes for every node (empty for the root).
        var ids: [[UInt8]]
        /// Every directory's children in recorded order.
        var order: [[Int]]
        /// Directories in path-table order (the root first).
        var pathOrder: [Int]
        /// Bytes of each directory's extent (whole sectors; 0 for files).
        var dirBytes: [UInt64]
        var pathTableBytes: UInt64

        init(nodes: [Node], level1: Bool) {
            let count = nodes.count
            var ids = Array(repeating: [UInt8](), count: count)
            var order = Array(repeating: [Int](), count: count)
            for (dir, node) in nodes.enumerated() where node.isDir {
                var used = Set<String>()
                for child in node.children {
                    ids[child] = Self.isoID(nodes[child].name, isDir: nodes[child].isDir, level1: level1, used: &used)
                }
                let keyed = node.children.enumerated().map { (position: $0.offset, node: $0.element, key: Self.sortKey(ids[$0.element])) }
                order[dir] = keyed.sorted {
                    if $0.key.0 != $1.key.0 { return $0.key.0.lexicographicallyPrecedes($1.key.0) }
                    if $0.key.1 != $1.key.1 { return $0.key.1.lexicographicallyPrecedes($1.key.1) }
                    return $0.position < $1.position
                }.map(\.node)
            }
            var pathOrder = [0]
            var at = 0
            while at < pathOrder.count {
                pathOrder += order[pathOrder[at]].filter { nodes[$0].isDir }
                at += 1
            }
            var dirBytes = Array(repeating: UInt64(0), count: count)
            for dir in pathOrder {
                var used: UInt64 = 0, size: UInt64 = 2048
                for length in [34, 34] + order[dir].map({ Self.recordLength(ids[$0].count) }) {
                    if used + length > 2048 {
                        size += 2048
                        used = 0
                    }
                    used += length
                }
                dirBytes[dir] = size
            }
            self.ids = ids
            self.order = order
            self.pathOrder = pathOrder
            self.dirBytes = dirBytes
            pathTableBytes = pathOrder.reduce(0) { $0 + ($1 == 0 ? 10 : Self.pathRecordLength(ids[$1].count)) }
        }

        static func recordLength(_ idLength: Int) -> UInt64 { UInt64(33 + idLength + (33 + idLength) % 2) }
        static func pathRecordLength(_ idLength: Int) -> UInt64 { UInt64(8 + idLength + idLength % 2) }

        /// Name, then extension, ignoring the ";1" version.
        static func sortKey(_ id: [UInt8]) -> ([UInt8], [UInt8]) {
            let text = id.split(separator: UInt8(ascii: ";"), maxSplits: 1, omittingEmptySubsequences: false).first.map(Array.init) ?? id
            guard let dot = text.firstIndex(of: UInt8(ascii: ".")) else { return (text, []) }
            return (Array(text[..<dot]), Array(text[(dot + 1)...]))
        }

        static func dChars(_ text: Substring) -> String {
            String(text.unicodeScalars.map { $0.isASCII && ($0.properties.isAlphabetic || ("0"..."9").contains($0)) ? Character(String($0).uppercased()) : "_" })
        }

        static func isoID(_ name: String, isDir: Bool, level1: Bool, used: inout Set<String>) -> [UInt8] {
            let (baseLimit, extLimit, total) = switch (isDir, level1) {
            case (true, true): (8, 0, 8)
            case (true, false): (31, 0, 31)
            case (false, true): (8, 3, 11)
            case (false, false): (30, 30, 30)
            }
            var base: String, ext: String
            if !isDir, let dot = name.lastIndex(of: "."), dot > name.startIndex {
                base = dChars(name[..<dot])
                ext = dChars(name[name.index(after: dot)...])
            } else {
                base = dChars(name[...])
                ext = ""
            }
            ext = String(ext.prefix(extLimit))
            let room = max(1, min(baseLimit, total - ext.count))
            var stem = String(base.prefix(room))
            if stem.isEmpty { stem = "_" }
            var candidate = stem
            var n = 1
            while !used.insert("\(candidate).\(ext)").inserted {
                let tag = "~\(n)"
                candidate = String(stem.prefix(max(1, room - tag.count))) + tag
                n += 1
            }
            return Array((isDir ? candidate : "\(candidate).\(ext);1").utf8)
        }

        // MARK: Records and extents

        func record(_ id: [UInt8], location: UInt32, size: UInt64, isDir: Bool, date: [UInt8]) -> [UInt8] {
            let length = Int(Self.recordLength(id.count))
            var r = [UInt8](repeating: 0, count: length)
            r[0] = UInt8(length)
            KroutonISO.putBoth32(&r, 2, location)
            KroutonISO.putBoth32(&r, 10, UInt32(clamping: size))
            r.replaceSubrange(18..<25, with: date)
            r[25] = isDir ? 2 : 0
            KroutonISO.putBoth16(&r, 28, 1)
            r[32] = UInt8(id.count)
            r.replaceSubrange(33..<33 + id.count, with: id)
            return r
        }

        /// Every directory's extent, in path-table order.
        func directories(nodes: [Node], dirSector: [UInt32], fileSector: [UInt32]) -> [(UInt32, [UInt8])] {
            pathOrder.map { dir in
                let node = nodes[dir]
                var extent = [UInt8](repeating: 0, count: Int(dirBytes[dir]))
                let parent = node.parent
                var records = [
                    record([0], location: dirSector[dir], size: dirBytes[dir], isDir: true, date: KroutonISO.recordDate(node.mtime)),
                    record([1], location: dirSector[parent], size: dirBytes[parent], isDir: true, date: KroutonISO.recordDate(nodes[parent].mtime)),
                ]
                for child in order[dir] {
                    let c = nodes[child]
                    let (location, size) = c.isDir ? (dirSector[child], dirBytes[child]) : (fileSector[child], c.size)
                    records.append(record(ids[child], location: location, size: size, isDir: c.isDir, date: KroutonISO.recordDate(c.mtime)))
                }
                var at = 0
                for r in records {
                    if at % 2048 + r.count > 2048 { at = (at + 2047) / 2048 * 2048 }
                    extent.replaceSubrange(at..<at + r.count, with: r)
                    at += r.count
                }
                return (dirSector[dir], extent)
            }
        }

        /// The little-endian (type L) and big-endian (type M) path tables.
        func pathTables(nodes: [Node], dirSector: [UInt32]) -> ([UInt8], [UInt8]) {
            var number = Array(repeating: UInt16(0), count: ids.count)
            var l: [UInt8] = [], m: [UInt8] = []
            for (index, dir) in pathOrder.enumerated() {
                number[dir] = UInt16(clamping: index + 1)
                let id: [UInt8] = dir == 0 ? [0] : ids[dir]
                let parent = dir == 0 ? UInt16(1) : number[nodes[dir].parent]
                let loc = dirSector[dir]
                for big in [false, true] {
                    var entry: [UInt8] = [UInt8(id.count), 0]
                    entry += big ? KroutonISO.be32(loc) : KroutonISO.le32(loc)
                    entry += big ? [UInt8(parent >> 8), UInt8(parent & 0xFF)] : [UInt8(parent & 0xFF), UInt8(parent >> 8)]
                    entry += id
                    if id.count % 2 == 1 { entry.append(0) }
                    if big { m += entry } else { l += entry }
                }
            }
            return (l, m)
        }

        /// The primary volume descriptor.
        func volumeDescriptor(name: String, sectors: UInt32, created: UInt64, rootSector: UInt32,
                              lTable: UInt32, mTable: UInt32) -> [UInt8] {
            var d = [UInt8](repeating: 0, count: 2048)
            d[0] = 1
            d.replaceSubrange(1..<6, with: Array("CD001".utf8))
            d[6] = 1
            func text(_ at: Int, _ width: Int, _ value: String) {
                let bytes = Array(value.utf8)
                for i in 0..<width { d[at + i] = i < bytes.count ? bytes[i] : UInt8(ascii: " ") }
            }
            text(8, 32, "")
            text(40, 32, name)
            KroutonISO.putBoth32(&d, 80, sectors)
            KroutonISO.putBoth16(&d, 120, 1)
            KroutonISO.putBoth16(&d, 124, 1)
            KroutonISO.putBoth16(&d, 128, 2048)
            KroutonISO.putBoth32(&d, 132, UInt32(clamping: pathTableBytes))
            d.replaceSubrange(140..<144, with: KroutonISO.le32(lTable))
            d.replaceSubrange(148..<152, with: KroutonISO.be32(mTable))
            let root = record([0], location: rootSector, size: dirBytes[0], isDir: true, date: KroutonISO.recordDate(created))
            d.replaceSubrange(156..<190, with: root)
            text(190, 128, ""); text(318, 128, ""); text(446, 128, "")
            text(574, 128, "KROUTON SERVER")
            for at in [702, 739, 776] { text(at, 37, "") }
            d.replaceSubrange(813..<830, with: KroutonISO.volumeDate(created))
            d.replaceSubrange(830..<847, with: KroutonISO.volumeDate(created))
            d.replaceSubrange(847..<864, with: KroutonISO.unsetDate)
            d.replaceSubrange(864..<881, with: KroutonISO.unsetDate)
            d[881] = 1
            return d
        }
    }
}

// MARK: - ISO 9660 Fields

enum KroutonISO {
    static func le32(_ v: UInt32) -> [UInt8] { [UInt8(v & 0xFF), UInt8(v >> 8 & 0xFF), UInt8(v >> 16 & 0xFF), UInt8(v >> 24)] }
    static func be32(_ v: UInt32) -> [UInt8] { le32(v).reversed() }

    static func putBoth16(_ d: inout [UInt8], _ at: Int, _ v: UInt16) {
        d.replaceSubrange(at..<at + 4, with: [UInt8(v & 0xFF), UInt8(v >> 8), UInt8(v >> 8), UInt8(v & 0xFF)])
    }

    static func putBoth32(_ d: inout [UInt8], _ at: Int, _ v: UInt32) {
        d.replaceSubrange(at..<at + 8, with: le32(v) + be32(v))
    }

    /// Directory-record date: years since 1900, month, day, hour, minute, second, UTC.
    static func recordDate(_ unix: UInt64) -> [UInt8] {
        let t = KroutonUDFTime(unix: unix)
        return [UInt8(clamping: max(0, min(255, t.year - 1900))), t.month, t.day, t.hour, t.minute, t.second, 0]
    }

    /// Volume-descriptor date: "YYYYMMDDHHMMSScc" and offset 0.
    static func volumeDate(_ unix: UInt64) -> [UInt8] {
        let t = KroutonUDFTime(unix: unix)
        let text = String(format: "%04ld%02ld%02ld%02ld%02ld%02ld00", Int(max(0, min(9999, t.year))), Int(t.month), Int(t.day),
                          Int(t.hour), Int(t.minute), Int(t.second))
        return Array(text.utf8.prefix(16)) + [0]
    }

    static let unsetDate: [UInt8] = [UInt8](repeating: UInt8(ascii: "0"), count: 16) + [0]

    static func terminator() -> [UInt8] {
        var d = [UInt8](repeating: 0, count: 2048)
        d[0] = 255
        d.replaceSubrange(1..<6, with: Array("CD001".utf8))
        d[6] = 1
        return d
    }

    /// The ISO 9660 volume name: upper-case letters, digits and "_", at most 32.
    static func volumeName(_ label: String) -> String {
        let mapped = String(label.trimmingCharacters(in: .whitespacesAndNewlines).unicodeScalars.prefix(32).map {
            $0.isASCII && ($0.properties.isAlphabetic || ("0"..."9").contains($0)) ? Character(String($0).uppercased()) : "_"
        })
        let trimmed = mapped.trimmingCharacters(in: CharacterSet(charactersIn: "_"))
        return trimmed.isEmpty ? "KROUTON" : trimmed
    }
}
