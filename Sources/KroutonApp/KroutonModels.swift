import SwiftUI
import AppKit
import OpticalDough

public struct AccentColorPreset: Identifiable, Hashable, Sendable {
    public let id: Int
    public let primary: Color
    public let secondary: Color
    public let isMonochrome: Bool

    public static let allPresets: [AccentColorPreset] = [
        AccentColorPreset(id: 0, primary: Color.orange, secondary: Color.orange, isMonochrome: false),
        AccentColorPreset(id: 1, primary: Color(red: 0.35, green: 0.52, blue: 0.78), secondary: Color.blue, isMonochrome: false),
        AccentColorPreset(id: 2, primary: Color.blue, secondary: Color.cyan, isMonochrome: false),
        AccentColorPreset(id: 3, primary: Color.indigo, secondary: Color.purple, isMonochrome: false),
        AccentColorPreset(id: 4, primary: Color.red, secondary: Color.red, isMonochrome: false),
        AccentColorPreset(id: 5, primary: Color.green, secondary: Color.mint, isMonochrome: false),
        AccentColorPreset(id: 6, primary: Color.cyan, secondary: Color.teal, isMonochrome: false),
        AccentColorPreset(id: 7, primary: Color.pink, secondary: Color.pink, isMonochrome: false),
        AccentColorPreset(id: 8, primary: Color.yellow, secondary: Color.orange, isMonochrome: false),
        AccentColorPreset(id: 9, primary: Color.primary, secondary: Color.secondary, isMonochrome: true)
    ]
}

public enum AppAppearanceMode: String, CaseIterable, Identifiable, Sendable {
    case auto = "Auto"
    case dark = "Dark"
    case light = "Light"
    public var id: String { rawValue }

    public var sfSymbol: String {
        switch self {
        case .auto: return "circle.lefthalf.filled"
        case .dark: return "moon.fill"
        case .light: return "sun.max.fill"
        }
    }

    public var colorScheme: ColorScheme? {
        switch self {
        case .auto: return nil
        case .dark: return .dark
        case .light: return .light
        }
    }
}

public enum TaskMasterCategory: String, CaseIterable, Identifiable, Sendable {
    case burn = "BURN"
    case copy = "COPY"
    case label = "LABEL"
    public var id: String { rawValue }
}

public struct DiscFormatSpec: Identifiable, Hashable, Sendable {
    public let id: String
    public var showInTaskChooser: Bool
    public var technicalName: String
    public var colloquialName: String
    public var launchYear: String
    public var capacity: String
    public var capacityGB: Double
    public var laserType: String
    public var platform: String
    public var deprecationStatus: String
    public var sourceSupport: String
    public var bookOrFileSystem: String
    public var sfSymbol: String
    public var isMediaPlaylist: Bool
    public var isDataDisc: Bool
}

public struct LabelGeometryPreset: Identifiable, Hashable, Sendable {
    public var id = UUID()
    public var name: String
    public var outerDiameterMM: Double
    public var innerDiameterMM: Double
    public var offsetXMM: Double
    public var offsetYMM: Double
}

public struct NotificationEventRow: Identifiable, Hashable, Sendable {
    public let id: String
    public var eventTitle: String
    public var eventSubtitle: String
    public var bannerEnabled: Bool
    public var iPhoneEnabled: Bool
    public var watchEnabled: Bool
    public var soundEnabled: Bool
}

public enum DestinationOutputKind: String, CaseIterable, Identifiable, Sendable {
    case physicalBurner = "Physical Burner"
    case networkBurner = "Network Server Burner"
    case discImage = "Disc Image File"
    case audioRip = "Audio Rip (ALAC / AAC / FLAC)"
    case videoExtract = "Video Transcode (H.265 / HEVC)"
    case discPrinter = "Disc Printer (Epson ET-8550)"
    case pdfVector = "Vector PDF Label"
    public var id: String { rawValue }

    public var sfSymbol: String {
        switch self {
        case .physicalBurner: return "opticaldiscdrive.fill"
        case .networkBurner: return "server.rack"
        case .discImage: return "externaldrive.fill.badge.plus"
        case .audioRip: return "waveform.badge.plus"
        case .videoExtract: return "film.stack"
        case .discPrinter: return "printer.dotmatrix.fill"
        case .pdfVector: return "doc.richtext.fill"
        }
    }
}

public struct DestinationQueueItem: Identifiable, Hashable, Sendable {
    public let id = UUID()
    public var kind: DestinationOutputKind
    public var hardwareOrPath: String
    public var speedOrCodec: String
    public var simulationMode: Bool
    public var verifyAfterBurn: Bool
    public var compressAfterCreation: Bool
}

 
@MainActor public final class KroutonStateStore: ObservableObject {
    @Published public var appearanceMode: AppAppearanceMode = .dark
    @Published public var selectedAccentIndex: Int = 1
    @Published public var rememberLastTaskOnLaunch: Bool = true
    @Published public var useBase10Units: Bool = true
    @Published public var scratchDiskPath: String = "~/Library/Caches/app.krouton.staging"
    @Published public var autoPurgeScratch: Bool = true
    @Published public var showMenuBarHelper: Bool = true

    @Published public var selectedCategory: TaskMasterCategory = .burn
    @Published public var selectedTaskID: String = "cd-da"

    @Published public var discFormats: [DiscFormatSpec] = [
        DiscFormatSpec(id: "cd-da", showInTaskChooser: true, technicalName: "CD-DA (Red Book)", colloquialName: "Audio CD w/ CD-TEXT", launchYear: "1982", capacity: "700 MB / 80m", capacityGB: 0.7, laserType: "780nm IR", platform: "All CD / DVD / BD Players", deprecationStatus: "Current", sourceSupport: "New & Image", bookOrFileSystem: "IEC 60908 Red Book", sfSymbol: "waveform.circle.fill", isMediaPlaylist: true, isDataDisc: false),
        DiscFormatSpec(id: "mp3-cd", showInTaskChooser: true, technicalName: "ISO9660 / UDF Audio", colloquialName: "MP3 / FLAC Audio Disc", launchYear: "1998", capacity: "700 MB / 4.7 GB", capacityGB: 0.7, laserType: "780nm / 650nm", platform: "Car Stereos, PC/Mac, DVD Decks", deprecationStatus: "Current", sourceSupport: "New & Image", bookOrFileSystem: "ISO9660 + Joliet (ID3v2.3)", sfSymbol: "music.note.list", isMediaPlaylist: true, isDataDisc: false),
        DiscFormatSpec(id: "cd-extra", showInTaskChooser: true, technicalName: "CD-Extra (Blue Book)", colloquialName: "Enhanced Mixed-Mode CD", launchYear: "1995", capacity: "700 MB", capacityGB: 0.7, laserType: "780nm IR", platform: "CD Players + Mac/PC", deprecationStatus: "2008 (Legacy)", sourceSupport: "New & Image", bookOrFileSystem: "Multi-Session Red + Yellow", sfSymbol: "opticaldisc.fill", isMediaPlaylist: true, isDataDisc: true),
        DiscFormatSpec(id: "data-hybrid", showInTaskChooser: true, technicalName: "UDF / HFS+ / APFS / ISO", colloquialName: "Mac & PC Data Disc", launchYear: "1985", capacity: "700 MB - 128 GB", capacityGB: 4.7, laserType: "All Lasers", platform: "macOS, Windows, Linux", deprecationStatus: "Current", sourceSupport: "New & Image", bookOrFileSystem: "Hybrid HFS+ / UDF 2.60", sfSymbol: "externaldrive.fill.badge.plus", isMediaPlaylist: false, isDataDisc: true),
        DiscFormatSpec(id: "dvd-video", showInTaskChooser: true, technicalName: "DVD-Video (DVD-5 / DVD-9)", colloquialName: "Standard Movie DVD", launchYear: "1996", capacity: "4.7 GB / 8.5 GB", capacityGB: 4.7, laserType: "650nm Red", platform: "Standalone DVD & BD Players", deprecationStatus: "Current", sourceSupport: "New & Image", bookOrFileSystem: "UDF 1.02 Bridge (VIDEO_TS)", sfSymbol: "film.fill", isMediaPlaylist: true, isDataDisc: false),
        DiscFormatSpec(id: "bd-on-dvd", showInTaskChooser: true, technicalName: "AVCHD / BD-5 / BD-9", colloquialName: "Blu-ray Video on DVD", launchYear: "2006", capacity: "4.7 GB / 8.5 GB", capacityGB: 4.7, laserType: "650nm Red", platform: "Blu-ray Players, PS3/PS4/PS5", deprecationStatus: "Current", sourceSupport: "New & Image", bookOrFileSystem: "UDF 2.50 (BDMV on DVD)", sfSymbol: "sparkles.tv.fill", isMediaPlaylist: true, isDataDisc: false),
        DiscFormatSpec(id: "bd-25", showInTaskChooser: true, technicalName: "BD-R / BD-RE SL", colloquialName: "25 GB Blu-ray Video", launchYear: "2006", capacity: "25.0 GB", capacityGB: 25.0, laserType: "405nm Violet", platform: "Blu-ray Players & Consoles", deprecationStatus: "Current", sourceSupport: "New & Image", bookOrFileSystem: "UDF 2.50 / 2.60 (BDMV)", sfSymbol: "film.stack.fill", isMediaPlaylist: true, isDataDisc: false),
        DiscFormatSpec(id: "bd-50", showInTaskChooser: true, technicalName: "BD-R DL Dual-Layer", colloquialName: "50 GB Blu-ray Video", launchYear: "2006", capacity: "50.0 GB", capacityGB: 50.0, laserType: "405nm Violet", platform: "Blu-ray Players & Consoles", deprecationStatus: "Current", sourceSupport: "New & Image", bookOrFileSystem: "UDF 2.50 Dual-Layer", sfSymbol: "square.stack.3d.up.fill", isMediaPlaylist: true, isDataDisc: false),
        DiscFormatSpec(id: "bd-uhd", showInTaskChooser: true, technicalName: "BDXL / UHD-BD (TL / QL)", colloquialName: "4K UHD Atmos Blu-ray", launchYear: "2016", capacity: "66 / 100 / 128 GB", capacityGB: 100.0, laserType: "405nm Violet", platform: "4K UHD Players, Xbox/PS5", deprecationStatus: "Current", sourceSupport: "New & Image", bookOrFileSystem: "UDF 2.60 HEVC 10-bit HDR", sfSymbol: "4k.tv.fill", isMediaPlaylist: true, isDataDisc: false),
        DiscFormatSpec(id: "boot-eltorito", showInTaskChooser: true, technicalName: "El Torito / UEFI / APM", colloquialName: "Bootable OS & Rescue Disc", launchYear: "1995", capacity: "700 MB - 25 GB", capacityGB: 4.7, laserType: "All Lasers", platform: "PC BIOS/UEFI & Mac EFI/OF", deprecationStatus: "Current", sourceSupport: "New & Image", bookOrFileSystem: "ISO9660 + El Torito + ESP", sfSymbol: "terminal.fill", isMediaPlaylist: false, isDataDisc: true),
        DiscFormatSpec(id: "console-rom", showInTaskChooser: true, technicalName: "Console Optical Image", colloquialName: "Wii, GC, PS1/PS2, Xbox, DC", launchYear: "1994", capacity: "650 MB - 8.5 GB", capacityGB: 4.7, laserType: "780nm / 650nm", platform: "Retro Consoles & Emulators", deprecationStatus: "Archival", sourceSupport: "Image Only", bookOrFileSystem: "2352-Byte Raw / XDVDFS / RVZ", sfSymbol: "gamecontroller.fill", isMediaPlaylist: false, isDataDisc: false),
        DiscFormatSpec(id: "macos9-hfs", showInTaskChooser: false, technicalName: "HFS Standard (APM)", colloquialName: "Classic Mac System 7 / OS 9", launchYear: "1985", capacity: "650 MB", capacityGB: 0.65, laserType: "780nm IR", platform: "68k & PowerPC Macintoshes", deprecationStatus: "2002 (Obsolete)", sourceSupport: "New & Image", bookOrFileSystem: "Apple Partition Map + HFS", sfSymbol: "desktopcomputer", isMediaPlaylist: false, isDataDisc: true),
        DiscFormatSpec(id: "sacd-r", showInTaskChooser: false, technicalName: "Scarlet Book DSD", colloquialName: "SACD-R Audiophile Disc", launchYear: "1999", capacity: "4.7 GB", capacityGB: 4.7, laserType: "650nm Red", platform: "SACD Compatible Players", deprecationStatus: "2011 (Niche)", sourceSupport: "New & Image", bookOrFileSystem: "UDF 1.02 Scarlet Book", sfSymbol: "hifispeaker.fill", isMediaPlaylist: true, isDataDisc: false),
        DiscFormatSpec(id: "vcd-svcd", showInTaskChooser: false, technicalName: "White Book VCD / SVCD", colloquialName: "Video CD (MPEG-1 / 2)", launchYear: "1993", capacity: "700 MB", capacityGB: 0.7, laserType: "780nm IR", platform: "VCD & DVD Players", deprecationStatus: "2005 (Obsolete)", sourceSupport: "New & Image", bookOrFileSystem: "Mode 2 Form 2 (2324-Byte)", sfSymbol: "play.tv.fill", isMediaPlaylist: true, isDataDisc: false),
        DiscFormatSpec(id: "cd-g", showInTaskChooser: false, technicalName: "Red Book + R-W Subchannel", colloquialName: "Karaoke CD+G", launchYear: "1985", capacity: "700 MB", capacityGB: 0.7, laserType: "780nm IR", platform: "Karaoke Decks", deprecationStatus: "2010 (Legacy)", sourceSupport: "Image Only", bookOrFileSystem: "Raw 96-Byte Subchannel", sfSymbol: "mic.fill", isMediaPlaylist: true, isDataDisc: false)
    ]

    @Published public var labelPresets: [LabelGeometryPreset] = [
        LabelGeometryPreset(name: "Epson ET-8550 Full Hub (120mm / 18mm)", outerDiameterMM: 120.0, innerDiameterMM: 18.0, offsetXMM: 0.0, offsetYMM: 0.0),
        LabelGeometryPreset(name: "Standard Inkjet Disc (118mm / 23mm)", outerDiameterMM: 118.0, innerDiameterMM: 23.0, offsetXMM: 0.0, offsetYMM: 0.0),
        LabelGeometryPreset(name: "Non-Hub Standard (118mm / 41mm)", outerDiameterMM: 118.0, innerDiameterMM: 41.0, offsetXMM: 0.0, offsetYMM: 0.0),
        LabelGeometryPreset(name: "80mm Mini-CD / GameCube (80mm / 18mm)", outerDiameterMM: 80.0, innerDiameterMM: 18.0, offsetXMM: 0.0, offsetYMM: 0.0)
    ]
    @Published public var selectedLabelPresetIndex: Int = 0
    @Published public var defaultAutoLabelStyle: String = "Full-Bleed Artwork + Arc Typography"
    @Published public var visionHoleAvoidance: Bool = true
    @Published public var customTMDBKey: String = ""
    @Published public var customFanartKey: String = ""

    @Published public var defaultCrossfadeSec: Double = 3.5
    @Published public var autoBeatmatchSoundAnalysis: Bool = true
    @Published public var carSafeMP3Mode: Bool = true
    @Published public var singleVideoFirstPlay: Bool = true

    @Published public var driveReadOffsetSamples: Int = 48
    @Published public var paranoiaErrorRetries: Int = 16
    @Published public var verifyAccurateRip: Bool = true
    @Published public var writeCueSheetLog: Bool = true
    @Published public var hardwareDeinterlaceVideo: Bool = true
    @Published public var passthroughAtmosTrueHD: Bool = true
    @Published public var namingTokens: [String] = ["[Track 01]", " - ", "[Artist]", " - ", "[Title]"]

    @Published public var enableNetworkServerSharing: Bool = true
    @Published public var serverRingBufferMB: Double = 256.0
    @Published public var preStageImageToServerSSD: Bool = true
    @Published public var forceDVDROMBookType: Bool = true
    @Published public var disableBDDefectManagementForVideo: Bool = true

    @Published public var notificationMatrix: [NotificationEventRow] = [
        NotificationEventRow(id: "start", eventTitle: "Burn, rip, or transcode started", eventSubtitle: "Triggered when laser calibration or extraction begins", bannerEnabled: true, iPhoneEnabled: true, watchEnabled: false, soundEnabled: false),
        NotificationEventRow(id: "done", eventTitle: "Task completed & verified", eventSubtitle: "Triggered when all queued destinations finish without error", bannerEnabled: true, iPhoneEnabled: true, watchEnabled: true, soundEnabled: true),
        NotificationEventRow(id: "err", eventTitle: "Task failed or buffer underrun", eventSubtitle: "Critical hardware, media, or network link interruption", bannerEnabled: true, iPhoneEnabled: true, watchEnabled: true, soundEnabled: true),
        NotificationEventRow(id: "layer", eventTitle: "Dual-layer (L0 -> L1) break reached", eventSubtitle: "DVD-9 or BD-50 seamless layer transition point", bannerEnabled: true, iPhoneEnabled: false, watchEnabled: true, soundEnabled: false),
        NotificationEventRow(id: "swap", eventTitle: "Blank disc or tray swap required", eventSubtitle: "Multi-disc queue waiting for operator", bannerEnabled: true, iPhoneEnabled: true, watchEnabled: true, soundEnabled: true),
        NotificationEventRow(id: "node", eventTitle: "Network burner server status change", eventSubtitle: "krouton-node connected or disconnected on LAN", bannerEnabled: true, iPhoneEnabled: false, watchEnabled: false, soundEnabled: false)
    ]

    @Published public var destinationQueue: [DestinationQueueItem] = [
        DestinationQueueItem(
            kind: .networkBurner,
            hardwareOrPath: "Pioneer BDR-S13U-X (krouton-server.local)",
            speedOrCodec: "8x CAV (Optimal)",
            simulationMode: false,
            verifyAfterBurn: true,
            compressAfterCreation: false
        )
    ]

    public var activeAccent: Color {
        AccentColorPreset.allPresets[selectedAccentIndex].primary
    }

    public init() {}
}
