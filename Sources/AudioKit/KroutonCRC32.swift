import Foundation

/// CRC-32 as used by Ethernet, zip and EAC rip logs (reflected polynomial 0xEDB88320).
///
/// Start from `initialValue`, feed every byte through `update`, then invert the result.
/// Check value: `checksum(of: Array("123456789".utf8)) == 0xCBF43926`.
public enum KroutonCRC32 {
    /// The value to start from.
    public static let initialValue: UInt32 = 0xFFFF_FFFF

    static let table: [UInt32] = (0..<256).map { index -> UInt32 in
        var value = UInt32(index)
        for _ in 0..<8 {
            value = (value & 1) == 1 ? (value >> 1) ^ 0xEDB8_8320 : value >> 1
        }
        return value
    }

    /// Feeds one byte into `crc`.
    @inline(__always)
    public static func update(_ crc: UInt32, _ byte: UInt8) -> UInt32 {
        table[Int((crc ^ UInt32(byte)) & 0xFF)] ^ (crc >> 8)
    }

    /// The finished CRC-32 of `bytes`.
    public static func checksum<Bytes: Sequence>(of bytes: Bytes) -> UInt32 where Bytes.Element == UInt8 {
        var crc = initialValue
        for byte in bytes { crc = update(crc, byte) }
        return ~crc
    }
}
