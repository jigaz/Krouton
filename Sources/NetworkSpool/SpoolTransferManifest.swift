import CryptoKit
import Foundation

// MARK: - Content-Addressed Transfer Manifest

public struct SpoolTransferManifest: Sendable, Equatable {
    public static let defaultSectorsPerExtent = 2048

    public let sectorSize: Int
    public let sectorsPerExtent: Int
    public let totalSectors: Int
    public let leafDigests: [[UInt8]]
    public let root: [UInt8]

    public init(sectorSize: Int, sectorsPerExtent: Int = defaultSectorsPerExtent, totalSectors: Int, leafDigests: [[UInt8]]) {
        self.sectorSize = sectorSize
        self.sectorsPerExtent = sectorsPerExtent
        self.totalSectors = totalSectors
        self.leafDigests = leafDigests
        self.root = Self.merkleRoot(leafDigests)
    }

    public init?(image: [UInt8], sectorSize: Int, sectorsPerExtent: Int = defaultSectorsPerExtent) {
        guard sectorSize > 0, sectorsPerExtent > 0, !image.isEmpty, image.count % sectorSize == 0 else { return nil }
        let extentBytes = sectorSize * sectorsPerExtent
        let leaves = stride(from: 0, to: image.count, by: extentBytes).map { start in
            Self.leafDigest(image[start..<min(start + extentBytes, image.count)])
        }
        self.init(sectorSize: sectorSize, sectorsPerExtent: sectorsPerExtent,
                  totalSectors: image.count / sectorSize, leafDigests: leaves)
    }

    public var extentCount: Int { leafDigests.count }
    public var extentBytes: Int { sectorSize * sectorsPerExtent }
    public var imageBytes: Int { totalSectors * sectorSize }

    public func byteRange(ofExtent index: Int) -> Range<Int> {
        let start = index * extentBytes
        return start..<min(start + extentBytes, imageBytes)
    }

    public func firstLBA(ofExtent index: Int) -> UInt64 {
        UInt64(index * sectorsPerExtent)
    }

    // MARK: - Merkle Tree (RFC 6962 domain separation)

    public static func leafDigest<D: DataProtocol>(_ bytes: D) -> [UInt8] {
        var hasher = SHA256()
        hasher.update(data: [UInt8(0x00)])
        hasher.update(data: bytes)
        return Array(hasher.finalize())
    }

    static func merkleRoot(_ leaves: [[UInt8]]) -> [UInt8] {
        guard !leaves.isEmpty else { return Array(SHA256.hash(data: [UInt8]())) }
        var level = leaves
        while level.count > 1 {
            var next: [[UInt8]] = []
            next.reserveCapacity((level.count + 1) / 2)
            for left in stride(from: 0, to: level.count, by: 2) {
                guard left + 1 < level.count else {
                    next.append(level[left])
                    continue
                }
                var hasher = SHA256()
                hasher.update(data: [UInt8(0x01)])
                hasher.update(data: level[left])
                hasher.update(data: level[left + 1])
                next.append(Array(hasher.finalize()))
            }
            level = next
        }
        return level[0]
    }
}

// MARK: - Committed-Extent Bitmap

public struct ExtentBitmap: Sendable, Equatable {
    public let count: Int
    public private(set) var bytes: [UInt8]

    public init(count: Int) {
        self.count = max(0, count)
        self.bytes = [UInt8](repeating: 0, count: (max(0, count) + 7) / 8)
    }

    public init?(count: Int, bytes: [UInt8]) {
        guard count >= 0, bytes.count == (count + 7) / 8 else { return nil }
        if count % 8 != 0, let last = bytes.last {
            let validBits = UInt8((1 << (count % 8)) - 1)
            guard last & ~validBits == 0 else { return nil }
        }
        self.count = count
        self.bytes = bytes
    }

    public func contains(_ index: Int) -> Bool {
        index >= 0 && index < count && bytes[index / 8] & (1 << UInt8(index % 8)) != 0
    }

    public mutating func insert(_ index: Int) {
        guard index >= 0, index < count else { return }
        bytes[index / 8] |= 1 << UInt8(index % 8)
    }

    public var committedCount: Int { bytes.reduce(0) { $0 + $1.nonzeroBitCount } }
    public var isComplete: Bool { committedCount == count }
    public var missing: [Int] { (0..<count).filter { !contains($0) } }
}

// MARK: - Extent Commit Journal (append-only, torn-write safe)

public struct ExtentCommitRecord: Sendable, Equatable {
    public static let byteCount = 44

    public let extentIndex: UInt32
    public let leafDigest: [UInt8]

    public init(extentIndex: UInt32, leafDigest: [UInt8]) {
        self.extentIndex = extentIndex
        self.leafDigest = leafDigest
    }

    public func encoded() -> [UInt8] {
        var body: [UInt8] = []
        SpoolBytes.append(extentIndex, to: &body)
        body.append(contentsOf: leafDigest.prefix(32))
        return body + Self.check(body)
    }

    static func check(_ body: [UInt8]) -> [UInt8] {
        Array(SHA256.hash(data: body).prefix(8))
    }

    public static func replay(_ journal: [UInt8], against manifest: SpoolTransferManifest) -> ExtentBitmap {
        var bitmap = ExtentBitmap(count: manifest.extentCount)
        var offset = 0
        while offset + byteCount <= journal.count {
            let body = Array(journal[offset..<(offset + 36)])
            guard Array(journal[(offset + 36)..<(offset + byteCount)]) == check(body) else { break }
            let index = Int(SpoolBytes.read(UInt32.self, from: body, at: 0))
            if index < manifest.extentCount, Array(body[4..<36]) == manifest.leafDigests[index] {
                bitmap.insert(index)
            }
            offset += byteCount
        }
        return bitmap
    }
}
