import Foundation

// MARK: - Byte order

/// Big- and little-endian integers as bytes, for the disc formats Krouton writes and reads
/// (ISO 9660 stores both orders, HFS and MMC big-endian, UDF, WAV and .cdi little-endian).
public enum KroutonBytes {
    @inlinable public static func be16(_ v: UInt16) -> [UInt8] { [UInt8(v >> 8), UInt8(v & 0xFF)] }
    @inlinable public static func be32(_ v: UInt32) -> [UInt8] {
        [UInt8(v >> 24), UInt8(v >> 16 & 0xFF), UInt8(v >> 8 & 0xFF), UInt8(v & 0xFF)]
    }
    @inlinable public static func le32(_ v: UInt32) -> [UInt8] {
        [UInt8(v & 0xFF), UInt8(v >> 8 & 0xFF), UInt8(v >> 16 & 0xFF), UInt8(v >> 24)]
    }

    /// Reads at `at`; the caller checks there are enough bytes.
    @inlinable public static func readBE16(_ b: [UInt8], _ at: Int) -> UInt16 { UInt16(b[at]) << 8 | UInt16(b[at + 1]) }
    @inlinable public static func readBE32(_ b: [UInt8], _ at: Int) -> UInt32 {
        UInt32(b[at]) << 24 | UInt32(b[at + 1]) << 16 | UInt32(b[at + 2]) << 8 | UInt32(b[at + 3])
    }
    @inlinable public static func readLE32(_ b: [UInt8], _ at: Int) -> UInt32 {
        UInt32(b[at]) | UInt32(b[at + 1]) << 8 | UInt32(b[at + 2]) << 16 | UInt32(b[at + 3]) << 24
    }
}
