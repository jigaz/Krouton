import Foundation

// MARK: - HFS Name Order

/// Classic Mac OS sorts catalog names case-insensitively and with accents next to their base
/// letters (`RelString`). Mac OS looks names up by binary search, so the catalog must be in
/// exactly this order. The table maps each Mac OS Roman byte to its sort weight; it is Apple's
/// order as the Linux kernel's `fs/hfs/string.c` and hfsutils record it.
enum KroutonHFSOrder {
    static let weight: [UInt8] = [
        0x00, 0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07, 0x08, 0x09, 0x0A, 0x0B, 0x0C, 0x0D, 0x0E, 0x0F,
        0x10, 0x11, 0x12, 0x13, 0x14, 0x15, 0x16, 0x17, 0x18, 0x19, 0x1A, 0x1B, 0x1C, 0x1D, 0x1E, 0x1F,
        0x20, 0x22, 0x23, 0x28, 0x29, 0x2A, 0x2B, 0x2C, 0x2F, 0x30, 0x31, 0x32, 0x33, 0x34, 0x35, 0x36,
        0x37, 0x38, 0x39, 0x3A, 0x3B, 0x3C, 0x3D, 0x3E, 0x3F, 0x40, 0x41, 0x42, 0x43, 0x44, 0x45, 0x46,
        0x47, 0x48, 0x57, 0x59, 0x5D, 0x5F, 0x66, 0x68, 0x6A, 0x6C, 0x72, 0x74, 0x76, 0x78, 0x7A, 0x7E,
        0x8C, 0x8E, 0x90, 0x92, 0x95, 0x97, 0x9E, 0xA0, 0xA2, 0xA4, 0xA7, 0xA9, 0xAA, 0xAB, 0xAC, 0xAD,
        0x4E, 0x48, 0x57, 0x59, 0x5D, 0x5F, 0x66, 0x68, 0x6A, 0x6C, 0x72, 0x74, 0x76, 0x78, 0x7A, 0x7E,
        0x8C, 0x8E, 0x90, 0x92, 0x95, 0x97, 0x9E, 0xA0, 0xA2, 0xA4, 0xA7, 0xAF, 0xB0, 0xB1, 0xB2, 0xB3,
        0x4A, 0x4C, 0x5A, 0x60, 0x7B, 0x7F, 0x98, 0x4F, 0x49, 0x51, 0x4A, 0x4B, 0x4C, 0x5A, 0x60, 0x63,
        0x64, 0x65, 0x6E, 0x6F, 0x70, 0x71, 0x7B, 0x84, 0x85, 0x86, 0x7F, 0x80, 0x9A, 0x9B, 0x9C, 0x98,
        0xB4, 0xB5, 0xB6, 0xB7, 0xB8, 0xB9, 0xBA, 0x94, 0xBB, 0xBC, 0xBD, 0xBE, 0xBF, 0xC0, 0x4D, 0x81,
        0xC1, 0xC2, 0xC3, 0xC4, 0xC5, 0xC6, 0xC7, 0xC8, 0xC9, 0xCA, 0xCB, 0x55, 0x8A, 0xCC, 0x4D, 0x81,
        0xCD, 0xCE, 0xCF, 0xD0, 0xD1, 0xD2, 0xD3, 0x26, 0x27, 0xD4, 0x20, 0x49, 0x4B, 0x80, 0x82, 0x82,
        0xD5, 0xD6, 0x24, 0x25, 0x2D, 0x2E, 0xD7, 0xD8, 0xA6, 0xD9, 0xDA, 0xDB, 0xDC, 0xDD, 0xDE, 0xDF,
        0xE0, 0xE1, 0xE2, 0xE3, 0xE4, 0xE5, 0xE6, 0xE7, 0xE8, 0xE9, 0xEA, 0xEB, 0xEC, 0xED, 0xEE, 0xEF,
        0xF0, 0xF1, 0xF2, 0xF3, 0xF4, 0xF5, 0xF6, 0xF7, 0xF8, 0xF9, 0xFA, 0xFB, 0xFC, 0xFD, 0xFE, 0xFF,
    ]

    /// `RelString` without diacritical sensitivity, as HFS compares catalog names.
    static func compare(_ a: [UInt8], _ b: [UInt8]) -> Int {
        for (x, y) in zip(a, b) {
            let d = Int(weight[Int(x)]) - Int(weight[Int(y)])
            if d != 0 { return d }
        }
        return a.count - b.count
    }

    static func precedes(_ a: (parent: UInt32, name: [UInt8]), _ b: (parent: UInt32, name: [UInt8])) -> Bool {
        a.parent != b.parent ? a.parent < b.parent : compare(a.name, b.name) < 0
    }
}

// MARK: - HFS B-Trees

/// Builds the catalog and extents-overflow B-trees of an HFS volume: 512-byte nodes, a header
/// node first, leaves linked left to right, and fixed-length index keys (HFS, unlike HFS+,
/// pads every index key to the tree's maximum key length).
enum KroutonHFSBTree {
    static let nodeSize = 512

    struct Record {
        var parent: UInt32
        var name: [UInt8]
        var data: [UInt8]

        /// keyLength, reserved, parent ID, Pascal name; padded so the data starts even.
        var keyBytes: [UInt8] {
            var key: [UInt8] = [UInt8(6 + name.count), 0] + hfsBE32(parent) + [UInt8(name.count)] + name
            if key.count % 2 == 1 { key.append(0) }
            return key
        }

        /// The same key at the catalog's maximum length (37), for index nodes.
        var indexKey: [UInt8] {
            var key: [UInt8] = [37, 0] + hfsBE32(parent) + [UInt8(name.count)] + name
            key += [UInt8](repeating: 0, count: 38 - key.count)
            return key
        }
    }

    /// One node: descriptor, records from offset 14, and the offset table at the end.
    static func node(forward: UInt32, backward: UInt32, kind: Int8, height: UInt8, records: [[UInt8]]) -> [UInt8] {
        var n = [UInt8](repeating: 0, count: nodeSize)
        n.replaceSubrange(0..<4, with: hfsBE32(forward))
        n.replaceSubrange(4..<8, with: hfsBE32(backward))
        n[8] = UInt8(bitPattern: kind)
        n[9] = height
        n.replaceSubrange(10..<12, with: hfsBE16(UInt16(records.count)))
        var at = 14
        for (i, record) in records.enumerated() {
            n.replaceSubrange(at..<at + record.count, with: record)
            n.replaceSubrange((nodeSize - 2 * (i + 1))..<(nodeSize - 2 * i), with: hfsBE16(UInt16(at)))
            at += record.count
        }
        let free = nodeSize - 2 * (records.count + 1)
        n.replaceSubrange(free..<free + 2, with: hfsBE16(UInt16(at)))
        return n
    }

    static func fits(_ records: [[UInt8]], plus next: [UInt8]) -> Bool {
        14 + records.reduce(0) { $0 + $1.count } + next.count + 2 * (records.count + 2) <= nodeSize
    }

    /// The whole tree as `nodeCount` nodes (the file's size / 512). Leaves come first after the
    /// header (nodes 1...), then each index level up to the root.
    static func build(records sorted: [Record], maxKeyLength: UInt16, nodeCount: Int) throws -> [UInt8] {
        // Leaves.
        var leaves: [[[UInt8]]] = []
        var firstKeys: [Record] = []
        for r in sorted {
            let bytes = r.keyBytes + r.data
            if leaves.isEmpty || !fits(leaves[leaves.count - 1], plus: bytes) {
                leaves.append([])
                firstKeys.append(r)
            }
            leaves[leaves.count - 1].append(bytes)
        }
        var nodes: [[UInt8]] = []
        let leafBase = 1
        for (i, records) in leaves.enumerated() {
            let forward = i + 1 < leaves.count ? UInt32(leafBase + i + 1) : 0
            let backward = i > 0 ? UInt32(leafBase + i - 1) : 0
            nodes.append(node(forward: forward, backward: backward, kind: -1, height: 1, records: records))
        }
        // Index levels.
        var level: [(node: Int, key: Record)] = firstKeys.enumerated().map { (leafBase + $0.offset, $0.element) }
        var height: UInt8 = 1
        while level.count > 1 {
            height += 1
            var groups: [[(node: Int, key: Record)]] = [[]]
            for entry in level {
                let bytes = entry.key.indexKey + hfsBE32(UInt32(entry.node))
                if !fits(groups[groups.count - 1].map { $0.key.indexKey + hfsBE32(UInt32($0.node)) }, plus: bytes) {
                    groups.append([])
                }
                groups[groups.count - 1].append(entry)
            }
            let base = 1 + nodes.count
            var next: [(node: Int, key: Record)] = []
            for (i, group) in groups.enumerated() {
                let forward = i + 1 < groups.count ? UInt32(base + i + 1) : 0
                let backward = i > 0 ? UInt32(base + i - 1) : 0
                let records = group.map { $0.key.indexKey + hfsBE32(UInt32($0.node)) }
                nodes.append(node(forward: forward, backward: backward, kind: 0, height: height, records: records))
                next.append((base + i, group[0].key))
            }
            level = next
        }
        let used = 1 + nodes.count
        guard used <= nodeCount, nodeCount <= 2048 else { throw KroutonHFSError.catalogTooLarge }
        let root = sorted.isEmpty ? 0 : UInt32(level.first?.node ?? 0)
        let depth: UInt16 = sorted.isEmpty ? 0 : UInt16(height)

        // Header node: header record, 128-byte user record, node map.
        var header = [UInt8]()
        header += hfsBE16(depth) + hfsBE32(root) + hfsBE32(UInt32(sorted.count))
        header += hfsBE32(sorted.isEmpty ? 0 : UInt32(leafBase)) + hfsBE32(sorted.isEmpty ? 0 : UInt32(leafBase + leaves.count - 1))
        header += hfsBE16(UInt16(nodeSize)) + hfsBE16(maxKeyLength) + hfsBE32(UInt32(nodeCount)) + hfsBE32(UInt32(nodeCount - used))
        header += [UInt8](repeating: 0, count: 76)
        var map = [UInt8](repeating: 0, count: nodeSize - 14 - 106 - 128 - 8)
        for i in 0..<used { map[i / 8] |= 0x80 >> UInt8(i % 8) }
        let headerNode = node(forward: 0, backward: 0, kind: 1, height: 0,
                              records: [header, [UInt8](repeating: 0, count: 128), map])
        var file = headerNode
        for n in nodes { file += n }
        file += [UInt8](repeating: 0, count: (nodeCount - used) * nodeSize)
        return file
    }
}

// MARK: - Big-Endian Fields

func hfsBE16(_ v: UInt16) -> [UInt8] { [UInt8(v >> 8), UInt8(v & 0xFF)] }
func hfsBE32(_ v: UInt32) -> [UInt8] { [UInt8(v >> 24), UInt8(v >> 16 & 0xFF), UInt8(v >> 8 & 0xFF), UInt8(v & 0xFF)] }
