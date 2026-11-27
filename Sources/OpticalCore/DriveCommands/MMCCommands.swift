import Foundation

// MARK: - MMC Command Descriptor Blocks

/// The SCSI Multimedia Commands (MMC; the freely published Mt. Fuji document, SNIA INF-TA-1010, is
/// the same command set) that Krouton sends straight to a drive, without DiscRecording. These are
/// pure bytes, so they are tested without hardware and reusable by any transport: IOKit on macOS,
/// a DriverKit extension on iPad, or SG_IO on Linux.
public enum MMCCommand: Sendable, Equatable {
    case testUnitReady
    case requestSense(allocation: UInt8)
    case inquiry(allocation: UInt16)
    /// GET CONFIGURATION with RT = 0 (all features) from `startingFeature`.
    case getConfiguration(startingFeature: UInt16, allocation: UInt16)
    case readDiscInformation(allocation: UInt16)
    /// READ CAPACITY (10): the last readable sector and the sector size.
    case readCapacity
    /// READ (10): `blocks` user-data sectors (2048 bytes on a CD-ROM, DVD or BD) from `lba`.
    case read10(lba: UInt32, blocks: UInt16)

    public var operationCode: UInt8 {
        switch self {
        case .testUnitReady: 0x00
        case .requestSense: 0x03
        case .inquiry: 0x12
        case .getConfiguration: 0x46
        case .readDiscInformation: 0x51
        case .readCapacity: 0x25
        case .read10: 0x28
        }
    }

    /// Bytes the drive may return (the transfer length to set up).
    public var allocationLength: Int {
        switch self {
        case .testUnitReady: 0
        case .requestSense(let n): Int(n)
        case .inquiry(let n), .getConfiguration(_, let n), .readDiscInformation(let n): Int(n)
        case .readCapacity: 8
        case .read10(_, let blocks): Int(blocks) * 2048
        }
    }

    /// The command descriptor block: 6 bytes for the old commands, 10 for the MMC ones.
    public var cdb: [UInt8] {
        switch self {
        case .testUnitReady:
            [0x00, 0, 0, 0, 0, 0]
        case .requestSense(let n):
            [0x03, 0, 0, 0, n, 0]
        case .inquiry(let n):
            [0x12, 0, 0, UInt8(n >> 8), UInt8(n & 0xFF), 0]
        case .getConfiguration(let start, let n):
            [0x46, 0x00, UInt8(start >> 8), UInt8(start & 0xFF), 0, 0, 0, UInt8(n >> 8), UInt8(n & 0xFF), 0]
        case .readDiscInformation(let n):
            [0x51, 0x00, 0, 0, 0, 0, 0, UInt8(n >> 8), UInt8(n & 0xFF), 0]
        case .readCapacity:
            [0x25, 0, 0, 0, 0, 0, 0, 0, 0, 0]
        case .read10(let lba, let blocks):
            [0x28, 0x00, UInt8(lba >> 24), UInt8((lba >> 16) & 0xFF), UInt8((lba >> 8) & 0xFF), UInt8(lba & 0xFF),
             0, UInt8(blocks >> 8), UInt8(blocks & 0xFF), 0]
        }
    }
}

// MARK: - Responses

/// Standard INQUIRY data: who made the drive and what firmware it runs.
public struct MMCInquiry: Sendable, Equatable {
    public let peripheralDeviceType: UInt8
    public let vendor: String
    public let product: String
    public let revision: String

    /// Type 5 is a CD/DVD/BD (multimedia) device.
    public var isMultimediaDevice: Bool { peripheralDeviceType == 0x05 }

    public init?(_ data: [UInt8]) {
        guard data.count >= 36 else { return nil }
        peripheralDeviceType = data[0] & 0x1F
        vendor = Self.ascii(data[8..<16])
        product = Self.ascii(data[16..<32])
        revision = Self.ascii(data[32..<36])
    }

    static func ascii(_ bytes: ArraySlice<UInt8>) -> String {
        String(decoding: bytes.map { (0x20..<0x7F).contains($0) ? $0 : 0x20 }, as: UTF8.self)
            .trimmingCharacters(in: .whitespaces)
    }
}

/// A media type a drive knows (an MMC "profile").
public struct MMCProfile: Sendable, Hashable {
    public let number: UInt16

    public init(_ number: UInt16) { self.number = number }

    public var name: String {
        switch number {
        case 0x0000: "No current profile"
        case 0x0002: "Removable disk"
        case 0x0008: "CD-ROM"
        case 0x0009: "CD-R"
        case 0x000A: "CD-RW"
        case 0x0010: "DVD-ROM"
        case 0x0011: "DVD-R"
        case 0x0012: "DVD-RAM"
        case 0x0013: "DVD-RW (restricted overwrite)"
        case 0x0014: "DVD-RW (sequential)"
        case 0x0015: "DVD-R DL (sequential)"
        case 0x0016: "DVD-R DL (layer jump)"
        case 0x001A: "DVD+RW"
        case 0x001B: "DVD+R"
        case 0x002A: "DVD+RW DL"
        case 0x002B: "DVD+R DL"
        case 0x0040: "BD-ROM"
        case 0x0041: "BD-R (sequential)"
        case 0x0042: "BD-R (random)"
        case 0x0043: "BD-RE"
        case 0x0050: "HD DVD-ROM"
        case 0x0051: "HD DVD-R"
        case 0x0052: "HD DVD-RAM"
        default: String(format: "Profile 0x%04X", number)
        }
    }

    /// Recordable or rewritable media (what a burner can write).
    public var isWritable: Bool {
        [0x0009, 0x000A, 0x0011, 0x0012, 0x0013, 0x0014, 0x0015, 0x0016, 0x001A, 0x001B, 0x002A, 0x002B,
         0x0041, 0x0042, 0x0043, 0x0051, 0x0052].contains(number)
    }
}

/// GET CONFIGURATION: the profile of the disc in the tray, and every profile the drive supports
/// (from the Profile List feature, 0x0000).
public struct MMCConfiguration: Sendable, Equatable {
    public let currentProfile: MMCProfile
    public let supportedProfiles: [MMCProfile]
    /// Feature codes the drive reported (current or not).
    public let featureCodes: [UInt16]

    public init?(_ data: [UInt8]) {
        guard data.count >= 8 else { return nil }
        let length = Int(MMCBytes.u32(data, 0))
        let end = min(data.count, length + 4)
        currentProfile = MMCProfile(MMCBytes.u16(data, 6))
        var profiles: [MMCProfile] = []
        var features: [UInt16] = []
        var offset = 8
        while offset + 4 <= end {
            let code = MMCBytes.u16(data, offset)
            let additional = Int(data[offset + 3])
            let body = offset + 4
            guard body + additional <= end else { break }
            features.append(code)
            if code == 0x0000 {
                var p = body
                while p + 4 <= body + additional {
                    profiles.append(MMCProfile(MMCBytes.u16(data, p)))
                    p += 4
                }
            }
            offset = body + additional
        }
        supportedProfiles = profiles
        featureCodes = features
    }

    /// Whether the drive can write any recordable media at all.
    public var canWrite: Bool { supportedProfiles.contains { $0.isWritable } }
}

/// READ DISC INFORMATION (standard disc information, data type 000b).
public struct MMCDiscInformation: Sendable, Equatable {
    public enum Status: UInt8, Sendable {
        case blank = 0, incomplete = 1, finalized = 2, other = 3
    }

    public let status: Status
    public let lastSessionState: UInt8
    public let erasable: Bool
    public let firstTrack: Int
    public let sessions: Int
    public let lastTrackInLastSession: Int

    public init?(_ data: [UInt8]) {
        guard data.count >= 12 else { return nil }
        erasable = data[2] & 0x10 != 0
        lastSessionState = (data[2] >> 2) & 0x03
        status = Status(rawValue: data[2] & 0x03) ?? .other
        firstTrack = Int(data[3])
        sessions = Int(data[9]) << 8 | Int(data[4])
        lastTrackInLastSession = Int(data[11]) << 8 | Int(data[6])
    }
}

/// Fixed-format sense data: why the last command failed.
public struct MMCSense: Sendable, Equatable, CustomStringConvertible {
    public let key: UInt8
    public let asc: UInt8
    public let ascq: UInt8

    public init?(_ data: [UInt8]) {
        guard data.count >= 14, data[0] & 0x7E == 0x70 else { return nil }
        key = data[2] & 0x0F
        asc = data[12]
        ascq = data[13]
    }

    /// `3/0C/00`, as burn logs and drive reports write it.
    public var description: String { String(format: "%X/%02X/%02X", key, asc, ascq) }

    public var meaning: String {
        switch (key, asc, ascq) {
        case (0x2, 0x3A, _): "No disc in the drive"
        case (0x2, 0x04, 0x01): "The drive is becoming ready"
        case (0x2, 0x04, _): "The drive is not ready"
        case (0x3, 0x0C, _): "Write error"
        case (0x3, 0x11, _): "Unrecovered read error"
        case (0x5, 0x20, _): "The drive does not support this command"
        case (0x5, 0x24, _): "Invalid field in the command"
        case (0x5, 0x30, _): "Incompatible medium"
        case (0x6, 0x28, _): "The disc was changed"
        case (0x6, 0x29, _): "The drive was reset"
        default: "Sense key \(key)"
        }
    }
}

enum MMCBytes {
    static func u16(_ d: [UInt8], _ i: Int) -> UInt16 { KroutonBytes.readBE16(d, i) }
    static func u32(_ d: [UInt8], _ i: Int) -> UInt32 { KroutonBytes.readBE32(d, i) }
}

// MARK: - Transport

/// Sends one command to a drive and returns the bytes it sent back, or throws with its sense data.
/// The macOS implementation lives in DriveKit; verify suites use a scripted drive.
public protocol MMCTransport: Sendable {
    func execute(_ command: MMCCommand) async throws(MMCTransportError) -> [UInt8]
}

public enum MMCTransportError: Error, Sendable, Equatable {
    case checkCondition(MMCSense?)
    case unavailable(String)
}

/// What Krouton learns about a drive by asking it directly.
public struct MMCDriveReport: Sendable, Equatable {
    public let inquiry: MMCInquiry
    public let configuration: MMCConfiguration?
    public let disc: MMCDiscInformation?

    /// Asks the drive who it is, what it supports, and what disc is loaded. Only reads.
    public static func read(from transport: some MMCTransport) async throws(MMCTransportError) -> MMCDriveReport {
        let identity = try await transport.execute(.inquiry(allocation: 96))
        guard let inquiry = MMCInquiry(identity) else { throw .unavailable("The drive sent a short INQUIRY reply") }
        let configuration = try? await transport.execute(.getConfiguration(startingFeature: 0, allocation: 2048))
        let disc = try? await transport.execute(.readDiscInformation(allocation: 34))
        return MMCDriveReport(inquiry: inquiry, configuration: configuration.flatMap(MMCConfiguration.init),
                              disc: disc.flatMap(MMCDiscInformation.init))
    }
}
