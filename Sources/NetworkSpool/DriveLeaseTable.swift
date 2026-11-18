import Foundation
import OpticalCore

// MARK: - Remote Drive Leases

public struct DriveLease: Sendable, Equatable {
    public enum Phase: Sendable, Equatable {
        case reserved
        case burning
    }

    public let drive: DriveID
    public let holder: String
    public let setID: UUID
    public let fencingToken: UInt64
    public internal(set) var expiresAt: Duration
    public internal(set) var phase: Phase
}

public enum DriveLeaseRejection: Error, Sendable, Equatable {
    case unknownDrive
    case heldByOther(holder: String)
    case staleToken
    case notReserved
}

// MARK: - Lease Table (node side, pure: time is passed in)

public struct DriveLeaseTable: Sendable, Equatable {
    public let ttl: Duration
    public private(set) var leases: [DriveID: DriveLease] = [:]
    private var lastToken: [DriveID: UInt64]

    public init(drives: [DriveID], ttl: Duration = .seconds(15), bootEpoch: UInt32 = 0) {
        self.ttl = ttl
        let seed = UInt64(bootEpoch) << 32
        self.lastToken = Dictionary(drives.map { ($0, seed) }, uniquingKeysWith: { first, _ in first })
    }

    public mutating func expire(at now: Duration) {
        leases = leases.filter { $0.value.phase == .burning || $0.value.expiresAt > now }
    }

    public mutating func reserve(_ drive: DriveID, holder: String, setID: UUID, at now: Duration) throws(DriveLeaseRejection) -> DriveLease {
        guard let last = lastToken[drive] else { throw .unknownDrive }
        expire(at: now)
        if var existing = leases[drive] {
            guard existing.holder == holder, existing.setID == setID else { throw .heldByOther(holder: existing.holder) }
            if existing.phase == .reserved { existing.expiresAt = now + ttl }
            leases[drive] = existing
            return existing
        }
        let lease = DriveLease(drive: drive, holder: holder, setID: setID, fencingToken: last + 1,
                               expiresAt: now + ttl, phase: .reserved)
        lastToken[drive] = last + 1
        leases[drive] = lease
        return lease
    }

    public mutating func heartbeat(_ drive: DriveID, token: UInt64, at now: Duration) throws(DriveLeaseRejection) -> DriveLease {
        var lease = try current(drive, token: token, at: now)
        if lease.phase == .reserved { lease.expiresAt = now + ttl }
        leases[drive] = lease
        return lease
    }

    /// Laser-on. Idempotent if a commit reply was lost and the holder retries with the active token.
    public mutating func commit(_ drive: DriveID, token: UInt64, at now: Duration) throws(DriveLeaseRejection) -> DriveLease {
        var lease = try current(drive, token: token, at: now)
        lease.phase = .burning
        leases[drive] = lease
        return lease
    }

    public mutating func finish(_ drive: DriveID, token: UInt64) {
        if leases[drive]?.fencingToken == token { leases[drive] = nil }
    }

    public mutating func release(_ drive: DriveID, token: UInt64, at now: Duration) throws(DriveLeaseRejection) {
        let lease = try current(drive, token: token, at: now)
        guard lease.phase == .reserved else { return }
        leases[drive] = nil
    }

    private mutating func current(_ drive: DriveID, token: UInt64, at now: Duration) throws(DriveLeaseRejection) -> DriveLease {
        guard lastToken[drive] != nil else { throw .unknownDrive }
        expire(at: now)
        guard let lease = leases[drive] else { throw .notReserved }
        guard lease.fencingToken == token else { throw .staleToken }
        return lease
    }
}
