import CryptoKit
import Foundation

// MARK: - Content-Addressed Transfer Manifest

/// An image cut into extents, each with a SHA-256 leaf digest, and the Merkle root over them. The
/// client offers it before uploading; the server checks every extent against its leaf, so a
/// resumed upload only resends what is missing or wrong.
public struct SpoolTransferManifest: Sendable, Equatable {
    /// 2,048 sectors: 4 MiB extents for 2,048-byte sectors.
    public static let defaultSectorsPerExtent = 2048

    /// Bytes per sector.
    public let sectorSize: Int
    /// Sectors per extent; the last extent may be shorter.
    public let sectorsPerExtent: Int
    /// Sectors in the image.
    public let totalSectors: Int
    /// One 32-byte leaf digest per extent, in order.
    public let leafDigests: [[UInt8]]
    /// The Merkle root over the leaves.
    public let root: [UInt8]

    /// A manifest from leaf digests computed elsewhere, as `forImage(at:)` does.
    public init(sectorSize: Int, sectorsPerExtent: Int = defaultSectorsPerExtent, totalSectors: Int, leafDigests: [[UInt8]]) {
        self.sectorSize = sectorSize
        self.sectorsPerExtent = sectorsPerExtent
        self.totalSectors = totalSectors
        self.leafDigests = leafDigests
        self.root = Self.merkleRoot(leafDigests)
    }

    /// A manifest of an image held in memory; nil when it isn't a whole number of sectors.
    public init?(image: [UInt8], sectorSize: Int, sectorsPerExtent: Int = defaultSectorsPerExtent) {
        guard sectorSize > 0, sectorsPerExtent > 0, !image.isEmpty, image.count % sectorSize == 0 else { return nil }
        let extentBytes = sectorSize * sectorsPerExtent
        let leaves = stride(from: 0, to: image.count, by: extentBytes).map { start in
            Self.leafDigest(image[start..<min(start + extentBytes, image.count)])
        }
        self.init(sectorSize: sectorSize, sectorsPerExtent: sectorsPerExtent,
                  totalSectors: image.count / sectorSize, leafDigests: leaves)
    }

    /// How many extents.
    public var extentCount: Int { leafDigests.count }
    /// Bytes in a full extent.
    public var extentBytes: Int { sectorSize * sectorsPerExtent }
    /// Bytes in the image.
    public var imageBytes: Int { totalSectors * sectorSize }

    /// The image bytes of extent `index`.
    public func byteRange(ofExtent index: Int) -> Range<Int> {
        let start = index * extentBytes
        return start..<min(start + extentBytes, imageBytes)
    }

    /// The first sector of extent `index`.
    public func firstLBA(ofExtent index: Int) -> UInt64 {
        UInt64(index * sectorsPerExtent)
    }

    // MARK: - Merkle Tree (RFC 6962 domain separation)

    /// SHA-256 of 0x00 followed by the extent's bytes. Inner nodes hash 0x01 and their two
    /// children, as in RFC 6962; an odd node moves up a level unchanged.
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

/// Which extents the server has committed, one bit per extent, least significant bit first.
public struct ExtentBitmap: Sendable, Equatable {
    /// Extents the bitmap covers.
    public let count: Int
    /// The bits, as sent on the wire.
    public private(set) var bytes: [UInt8]

    /// An empty bitmap.
    public init(count: Int) {
        self.count = max(0, count)
        self.bytes = [UInt8](repeating: 0, count: (max(0, count) + 7) / 8)
    }

    /// A bitmap from the wire; nil when the length is wrong or bits past `count` are set.
    public init?(count: Int, bytes: [UInt8]) {
        guard count >= 0, bytes.count == (count + 7) / 8 else { return nil }
        if count % 8 != 0, let last = bytes.last {
            let validBits = UInt8((1 << (count % 8)) - 1)
            guard last & ~validBits == 0 else { return nil }
        }
        self.count = count
        self.bytes = bytes
    }

    /// True when extent `index` is committed.
    public func contains(_ index: Int) -> Bool {
        index >= 0 && index < count && bytes[index / 8] & (1 << UInt8(index % 8)) != 0
    }

    /// Marks extent `index` committed.
    public mutating func insert(_ index: Int) {
        guard index >= 0, index < count else { return }
        bytes[index / 8] |= 1 << UInt8(index % 8)
    }

    /// Extents committed.
    public var committedCount: Int { bytes.reduce(0) { $0 + $1.nonzeroBitCount } }
    /// True when every extent is committed.
    public var isComplete: Bool { committedCount == count }
    /// The extents not committed, in order.
    public var missing: [Int] { (0..<count).filter { !contains($0) } }
}

// MARK: - Manifest Offer Frames (kind 10)

public extension SpoolTransferManifest {
    /// The most extents an offer may list (262,144: 8 MiB of leaves).
    static let maxManifestLeaves = 262_144
    private static let allowedSectorSizes: Set<UInt16> = [2048, 2336, 2352, 2448]
    private static let maxOfferPayloadBytes = 8 * 1024 * 1024

    /// The offer frame: sectors per extent in the extent-index field, total sectors in the
    /// first-LBA field, the root as the digest, and the leaves as the payload. Nil when the
    /// manifest can't be sent.
    func encodeManifestOffer() -> SpoolFrame? {
        guard self.sectorsPerExtent > 0,
              self.totalSectors > 0,
              let sectorSizeU16 = UInt16(exactly: self.sectorSize),
              let sectorsPerExtentU32 = UInt32(exactly: self.sectorsPerExtent),
              let totalSectorsU64 = UInt64(exactly: self.totalSectors),
              Self.allowedSectorSizes.contains(sectorSizeU16),
              self.leafDigests.count == self.extentCount,
              self.leafDigests.count <= Self.maxManifestLeaves else {
            return nil
        }
        var payload = [UInt8]()
        payload.reserveCapacity(self.leafDigests.count * 32)
        for leaf in self.leafDigests {
            guard leaf.count == 32 else { return nil }
            payload.append(contentsOf: leaf)
        }
        guard payload.count <= Self.maxOfferPayloadBytes else { return nil }
        let header = SpoolFrameHeader(
            kind: .manifestOffer,
            flags: 0,
            extentIndex: sectorsPerExtentU32,
            firstLBA: totalSectorsU64,
            sectorSize: sectorSizeU16,
            payloadLength: UInt32(payload.count),
            digest: self.root
        )
        return SpoolFrame(header: header, payload: payload)
    }

    /// Reads an offer frame; nil unless every field is valid and the leaves hash to the root.
    init?(manifestOffer frame: SpoolFrame) {
        let h = frame.header
        guard h.kind == .manifestOffer,
              h.flags == 0,
              Self.allowedSectorSizes.contains(h.sectorSize),
              h.extentIndex > 0,
              h.firstLBA > 0,
              let totalSectorsInt = Int(exactly: h.firstLBA),
              frame.payload.count % 32 == 0 else {
            return nil
        }
        let leafCount = frame.payload.count / 32
        guard leafCount > 0, leafCount <= Self.maxManifestLeaves else { return nil }
        let spx = UInt64(h.extentIndex)
        let expectedLeaves = Int((h.firstLBA + (spx - 1)) / spx)
        guard leafCount == expectedLeaves else { return nil }

        var leaves: [[UInt8]] = []
        leaves.reserveCapacity(leafCount)
        for i in 0..<leafCount {
            let start = i * 32
            leaves.append(Array(frame.payload[start..<(start + 32)]))
        }
        let candidate = SpoolTransferManifest(
            sectorSize: Int(h.sectorSize),
            sectorsPerExtent: Int(h.extentIndex),
            totalSectors: totalSectorsInt,
            leafDigests: leaves
        )
        guard candidate.root == h.digest else { return nil }
        self = candidate
    }
}
