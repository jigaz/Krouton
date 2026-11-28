import Foundation

// MARK: - Selectable Physical Media Capacities & Per-Disc Volume Metadata

/// A disc size the user can pick for spanning, with how much audio or data it holds. The raw values
/// are display names and are saved in projects.
public enum KroutonSpanningDiscMedium: String, CaseIterable, Identifiable, Codable, Sendable {
    case cd74Min650MB   = "CD-R 74 min / 650 MB"
    case cd80Min700MB   = "CD-R 80 min / 700 MB"
    case cd90Min800MB   = "CD-R 90 min / 800 MB (Overburn)"
    case miniDVD80mm    = "Mini-DVD 80mm (1.46 GB)"
    case dvd5Single     = "DVD-5 Single-Layer (4.7 GB)"
    case dvd9Dual       = "DVD-9 Dual-Layer (8.54 GB)"
    case bd25Single     = "BD-R 25 GB Single-Layer"
    case bd50Dual       = "BD-R 50 GB Dual-Layer"
    case bdxl100Triple  = "BDXL 100 GB Triple-Layer"
    case bdxl128Quad    = "BDXL 128 GB Quad-Layer"

    public var id: String { rawValue }

    /// Audio capacity in CD frames (75 a second). Media that aren't CDs report an 80-minute CD.
    public var maxRedBookFrames: Int64 {
        switch self {
        case .cd74Min650MB:  return 74 * 60 * 75          // 333,000 frames (74:00:00)
        case .cd80Min700MB:  return (79 * 60 + 57) * 75   // 359,775 frames (79:57:00)
        case .cd90Min800MB:  return 89 * 60 * 75          // 400,500 frames (89:00:00)
        case .miniDVD80mm:   return 150_000
        default:             return (79 * 60 + 57) * 75
        }
    }

    /// Data capacity in 2,048-byte sectors, set slightly below each medium's full size.
    public var maxDataSectors2048: Int64 {
        switch self {
        case .cd74Min650MB:  return 332_000
        case .cd80Min700MB:  return 358_800
        case .cd90Min800MB:  return 399_000
        case .miniDVD80mm:   return 712_000
        case .dvd5Single:    return 2_292_000
        case .dvd9Dual:      return 4_168_000
        case .bd25Single:    return 12_210_000
        case .bd50Dual:      return 24_420_000
        case .bdxl100Triple: return 48_800_000
        case .bdxl128Quad:   return 62_450_000
        }
    }

    /// Data capacity in bytes.
    public var maxPayloadBytes: Int64 {
        maxDataSectors2048 * 2048
    }

    /// Returns true when the format supports selecting a target physical disc storage size in the workspace header.
    public static func supportsTargetDiscSizeSelection(forFormatID formatID: String) -> Bool {
        if KroutonFormatID(rawValue: formatID) == .imageBurn || formatID.hasPrefix("console-") {
            return false
        }
        return !allowedMedia(forFormatID: formatID).isEmpty
    }

    /// The disc size a format starts with.
    public static func defaultMedium(forFormatID formatID: String) -> KroutonSpanningDiscMedium {
        switch KroutonFormatID(rawValue: formatID) {
        case .cdDA, .cdExtra, .dtsCD, .vcdSVCD, .macos9HFS, .photoCD, .dataRetroISO, .mp3CD:
            return .cd80Min700MB
        case .bd25, .mdiscVault, .dataUDFModern:
            return .bd25Single
        case .bd50:
            return .bd50Dual
        case .bdUHD:
            return .bdxl100Triple
        default:
            return .dvd5Single
        }
    }

    /// The disc sizes a format can be burned to; empty for image burns and console formats.
    public static func allowedMedia(forFormatID formatID: String) -> [KroutonSpanningDiscMedium] {
        if KroutonFormatID(rawValue: formatID) == .imageBurn || formatID.hasPrefix("console-") {
            return []
        }
        switch KroutonFormatID(rawValue: formatID) {
        case .cdDA, .cdExtra, .dtsCD, .vcdSVCD, .macos9HFS, .photoCD, .dataRetroISO:
            return [.cd74Min650MB, .cd80Min700MB, .cd90Min800MB]
        case .mp3CD:
            return [.cd74Min650MB, .cd80Min700MB, .cd90Min800MB, .dvd5Single, .dvd9Dual]
        case .dvdVideo, .dvdAudio, .dvdRAM:
            return [.miniDVD80mm, .dvd5Single, .dvd9Dual]
        case .bdOnDVD:
            // AVCHD: from a 4.7 GB DVD-5 up to a 128 GB BDXL
            return [.dvd5Single, .dvd9Dual, .bd25Single, .bd50Dual, .bdxl100Triple, .bdxl128Quad]
        case .bd25, .bd50, .bdUHD:
            return [.bd25Single, .bd50Dual, .bdxl100Triple, .bdxl128Quad]
        case .mdiscVault:
            return [.dvd5Single, .bd25Single, .bd50Dual, .bdxl100Triple, .bdxl128Quad]
        default:
            // Data discs (hybrid, UDF 2.50, Apple and the rest): every size from 650 MB to 128 GB
            return [
                .cd74Min650MB,
                .cd80Min700MB,
                .cd90Min800MB,
                .miniDVD80mm,
                .dvd5Single,
                .dvd9Dual,
                .bd25Single,
                .bd50Dual,
                .bdxl100Triple,
                .bdxl128Quad
            ]
        }
    }
}

/// Per-disc names for a multi-disc set: the album title and performer for CD-Text, the UPC/EAN
/// catalog number, and the volume label.
public struct KroutonDiscVolumeMetadata: Equatable, Codable, Sendable {
    public var discNumber: Int
    public var title: String
    public var performer: String
    public var upc: String
    public var volumeLabel: String
    public var writeCDText: Bool

    public init(
        discNumber: Int,
        title: String = "",
        performer: String = "",
        upc: String = "",
        volumeLabel: String = "",
        writeCDText: Bool = true
    ) {
        self.discNumber = max(1, discNumber)
        self.title = title
        self.performer = performer
        self.upc = upc
        self.volumeLabel = volumeLabel
        self.writeCDText = writeCDText
    }
}
