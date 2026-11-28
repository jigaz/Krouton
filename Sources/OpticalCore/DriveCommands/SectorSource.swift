import Foundation

// MARK: - Sector Sources

/// Anything that can hand out 2048-byte user-data sectors by number: a drive through MMC, or a
/// scripted disc in tests. Rescue reads through this, so the copy engine never touches hardware.
public protocol KroutonSectorSource: Sendable {
    /// How many sectors the disc holds.
    func sectorCount() async throws(KroutonSectorReadError) -> Int64
    /// Reads `count` sectors starting at `lba`. Returns exactly `count * 2048` bytes or throws.
    func read(lba: Int64, count: Int) async throws(KroutonSectorReadError) -> [UInt8]
}

/// Why a sector read failed, split by whether retrying can help.
public enum KroutonSectorReadError: Error, LocalizedError, Sendable, Equatable {
    /// The disc could not be read there: a scratch, dye failure or dirt. Worth trying again later.
    case unreadable(String)
    /// The drive or connection failed, so going on would be pointless.
    case driveFailed(String)

    public var errorDescription: String? {
        switch self {
        case .unreadable(let reason): return "A sector couldn't be read: \(reason)."
        case .driveFailed(let reason): return "\(reason)."
        }
    }
}

/// The size of a data sector's user data.
public enum KroutonSector {
    /// 2,048 bytes: the user data of a Mode 1 CD sector, or of a DVD or Blu-ray sector.
    public static let size = 2048
}

/// Reads a disc through a drive's own MMC commands (READ CAPACITY, READ (10)).
public struct MMCSectorSource<Transport: MMCTransport>: KroutonSectorSource {
    /// The drive connection the commands go through.
    public let transport: Transport

    public init(transport: Transport) {
        self.transport = transport
    }

    public func sectorCount() async throws(KroutonSectorReadError) -> Int64 {
        let reply: [UInt8]
        do {
            reply = try await transport.execute(.readCapacity)
        } catch {
            throw .driveFailed("The drive didn't report the disc's size: \(Self.describe(error))")
        }
        guard reply.count >= 8 else { throw .driveFailed("The drive's size report was too short") }
        let lastLBA = reply[0..<4].reduce(Int64(0)) { $0 << 8 | Int64($1) }
        let blockLength = reply[4..<8].reduce(0) { $0 << 8 | Int($1) }
        guard blockLength == KroutonSector.size else {
            throw .driveFailed("The disc uses \(blockLength)-byte sectors; rescue copies 2048-byte data discs")
        }
        return lastLBA + 1
    }

    public func read(lba: Int64, count: Int) async throws(KroutonSectorReadError) -> [UInt8] {
        guard count > 0, count <= Int(UInt16.max), lba >= 0, lba + Int64(count) <= Int64(UInt32.max) else {
            throw .driveFailed("Sector range \(lba)+\(count) is out of range")
        }
        let reply: [UInt8]
        do {
            reply = try await transport.execute(.read10(lba: UInt32(lba), blocks: UInt16(count)))
        } catch {
            throw Self.classify(error)
        }
        guard reply.count == count * KroutonSector.size else {
            throw .unreadable("The drive returned \(reply.count) of \(count * KroutonSector.size) bytes")
        }
        return reply
    }

    /// A medium error (sense key 3) or a read that simply failed is worth retrying; a drive that
    /// vanished, or reports a hardware fault (key 4) or no disc, is not.
    static func classify(_ error: MMCTransportError) -> KroutonSectorReadError {
        switch error {
        case .checkCondition(let sense?) where sense.key == 0x3 || sense.key == 0xB:
            return .unreadable(sense.meaning)
        case .checkCondition(let sense?) where sense.key == 0x2 || sense.key == 0x4 || sense.key == 0x6:
            return .driveFailed(sense.meaning)
        case .checkCondition:
            return .unreadable("The drive reported an error without details")
        case .unavailable(let reason):
            return .driveFailed(reason)
        }
    }

    static func describe(_ error: MMCTransportError) -> String {
        switch error {
        case .checkCondition(let sense?): return sense.meaning
        case .checkCondition: return "an error without details"
        case .unavailable(let reason): return reason
        }
    }
}
