import SwiftUI
import AppKit
import OpticalDough

public struct AccentColorPreset: Identifiable, Hashable, Sendable {
    public let id: Int
    public let swatchColor: Color
    public let darkAccent: Color
    public let lightAccent: Color
    public let darkOnAccentText: Color
    public let lightOnAccentText: Color
    public let isMonochrome: Bool

    public func effectiveAccent(for scheme: ColorScheme?) -> Color {
        scheme == .light ? lightAccent : darkAccent
    }

    public func effectiveOnAccentText(for scheme: ColorScheme?) -> Color {
        scheme == .light ? lightOnAccentText : darkOnAccentText
    }

    public static let allPresets: [AccentColorPreset] = [
        // -1: Multicolor (macOS System Settings Rainbow Wheel)
        AccentColorPreset(id: -1, swatchColor: Color.blue, darkAccent: Color(red: 0.32, green: 0.62, blue: 0.98), lightAccent: Color(red: 0.0, green: 0.44, blue: 0.92), darkOnAccentText: .white, lightOnAccentText: .white, isMonochrome: false),
        // 0: Red
        AccentColorPreset(id: 0, swatchColor: Color(red: 0.90, green: 0.23, blue: 0.23), darkAccent: Color(red: 0.92, green: 0.26, blue: 0.26), lightAccent: Color(red: 0.82, green: 0.16, blue: 0.16), darkOnAccentText: .white, lightOnAccentText: .white, isMonochrome: false),
        // 1: Orange
        AccentColorPreset(id: 1, swatchColor: Color.orange, darkAccent: Color.orange, lightAccent: Color(red: 0.88, green: 0.44, blue: 0.04), darkOnAccentText: .white, lightOnAccentText: .white, isMonochrome: false),
        // 2: High-Contrast Gold / Yellow (Dark text on bright amber-gold in Dark mode; deep warm gold in Light mode)
        AccentColorPreset(id: 2, swatchColor: Color(red: 0.96, green: 0.78, blue: 0.12), darkAccent: Color(red: 0.95, green: 0.76, blue: 0.14), lightAccent: Color(red: 0.76, green: 0.53, blue: 0.02), darkOnAccentText: Color.black.opacity(0.88), lightOnAccentText: .white, isMonochrome: false),
        // 3: Green
        AccentColorPreset(id: 3, swatchColor: Color.green, darkAccent: Color(red: 0.18, green: 0.78, blue: 0.36), lightAccent: Color(red: 0.12, green: 0.62, blue: 0.26), darkOnAccentText: .white, lightOnAccentText: .white, isMonochrome: false),
        // 4: Cyan / Teal
        AccentColorPreset(id: 4, swatchColor: Color.cyan, darkAccent: Color(red: 0.16, green: 0.74, blue: 0.88), lightAccent: Color(red: 0.04, green: 0.54, blue: 0.68), darkOnAccentText: Color.black.opacity(0.88), lightOnAccentText: .white, isMonochrome: false),
        // 5: 405nm Laser Blue
        AccentColorPreset(id: 5, swatchColor: Color.blue, darkAccent: Color.blue, lightAccent: Color(red: 0.0, green: 0.40, blue: 0.88), darkOnAccentText: .white, lightOnAccentText: .white, isMonochrome: false),
        // 6: Studio Slate Blue (Default)
        AccentColorPreset(id: 6, swatchColor: Color(red: 0.35, green: 0.52, blue: 0.78), darkAccent: Color(red: 0.38, green: 0.56, blue: 0.84), lightAccent: Color(red: 0.24, green: 0.42, blue: 0.68), darkOnAccentText: .white, lightOnAccentText: .white, isMonochrome: false),
        // 7: Indigo / Violet
        AccentColorPreset(id: 7, swatchColor: Color.indigo, darkAccent: Color(red: 0.46, green: 0.42, blue: 0.92), lightAccent: Color.indigo, darkOnAccentText: .white, lightOnAccentText: .white, isMonochrome: false),
        // 8: Toasted Krouton Brown (Replaces Mauve/Pink!)
        AccentColorPreset(id: 8, swatchColor: Color(red: 0.64, green: 0.42, blue: 0.24), darkAccent: Color(red: 0.72, green: 0.49, blue: 0.30), lightAccent: Color(red: 0.52, green: 0.32, blue: 0.16), darkOnAccentText: .white, lightOnAccentText: .white, isMonochrome: false),
        // 9: High-Contrast Black & White Monochrome (Silver-White w/ Black text in Dark mode; Graphite-Black w/ White text in Light mode)
        AccentColorPreset(id: 9, swatchColor: Color.primary, darkAccent: Color(white: 0.86), lightAccent: Color(white: 0.18), darkOnAccentText: Color.black.opacity(0.92), lightOnAccentText: .white, isMonochrome: true)
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


public enum SanitySeverity: String, Sendable {
    case criticalOverburn
    case warning4GBNoUDF
    case warningFilenameLength
    case warningConsoleMedia
}

public struct PreFlightSanityDiagnostic: Identifiable, Hashable, Sendable {
    public let id: String
    public let severity: SanitySeverity
    public let title: String
    public let detail: String
    public let actionButtonTitle: String?

    public init(id: String, severity: SanitySeverity, title: String, detail: String, actionButtonTitle: String? = nil) {
        self.id = id
        self.severity = severity
        self.title = title
        self.detail = detail
        self.actionButtonTitle = actionButtonTitle
    }
}

public enum IconWidgetStyleMode: String, CaseIterable, Identifiable, Sendable {
    case defaultStyle = "Default"
    case dark = "Dark"
    case clear = "Clear"
    case tinted = "Tinted"
    public var id: String { rawValue }
}

public enum SidebarIconSizeMode: String, CaseIterable, Identifiable, Sendable {
    case small = "Small"
    case medium = "Medium"
    case large = "Large"
    public var id: String { rawValue }

    public var iconFontSize: CGFloat {
        switch self {
        case .small: return 12
        case .medium: return 15
        case .large: return 18
        }
    }

    public var titleFontSize: CGFloat {
        switch self {
        case .small: return 11.5
        case .medium: return 12.5
        case .large: return 14.0
        }
    }

    public var rowVerticalPadding: CGFloat {
        switch self {
        case .small: return 4
        case .medium: return 6
        case .large: return 9
        }
    }
}

public enum FolderColorMode: String, CaseIterable, Identifiable, Sendable {
    case automatic = "Automatic"
    case classicAqua = "Classic Aqua Blue"
    case accentTinted = "Theme Accent"
    case amberGold = "Amber Gold"
    case graphite = "Space Gray"
    public var id: String { rawValue }

    public func resolvedFolderColor(accent: Color) -> Color {
        switch self {
        case .automatic, .accentTinted: return accent
        case .classicAqua: return Color(red: 0.22, green: 0.64, blue: 0.96)
        case .amberGold: return Color.orange
        case .graphite: return Color.secondary
        }
    }
}

public enum KroutonLanguage: String, CaseIterable, Identifiable, Sendable {
    case system = "System Default (Auto)"
    case english = "English (US)"
    case japanese = "日本語 (Japanese)"
    case german = "Deutsch (German)"
    case french = "Français (French)"
    case spanish = "Español (Spanish)"
    case italian = "Italiano (Italian)"
    case portuguese = "Português (Brasil)"
    case dutch = "Nederlands (Dutch)"
    case chineseSimplified = "简体中文 (Chinese)"
    case korean = "한국어 (Korean)"
    public var id: String { rawValue }

    public var isoCode: String {
        switch self {
        case .system: return Locale.preferredLanguages.first?.prefix(2).lowercased() ?? "en"
        case .english: return "en"
        case .japanese: return "ja"
        case .german: return "de"
        case .french: return "fr"
        case .spanish: return "es"
        case .italian: return "it"
        case .portuguese: return "pt-BR"
        case .dutch: return "nl"
        case .chineseSimplified: return "zh-Hans"
        case .korean: return "ko"
        }
    }
}

public enum TaskMasterCategory: String, CaseIterable, Identifiable, Sendable {
    case burn = "BURN"
    case depot = "DISC IMAGE DEPOT"
    case copy = "COPY"
    case label = "LABEL"
    public var id: String { rawValue }
}

public enum FormatFilterGroup: String, CaseIterable, Identifiable, Sendable {
    case all = "All Formats"
    case enabled = "Enabled Only"
    case audio = "Audio"
    case video = "Video & BD"
    case data = "Data & Archival"
    case console = "Console ROMs"
    case legacy = "Obsolete / Niche"
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
    public var filterGroup: FormatFilterGroup
    public var isMediaPlaylist: Bool
    public var isDataDisc: Bool

    public var visibilitySortKey: Int {
        showInTaskChooser ? 1 : 0
    }
}

public struct DepotCatalogItem: Identifiable, Hashable, Sendable {
    public let id: String
    public var title: String
    public var subtitle: String
    public var channel: String
    public var version: String
    public var sizeDisplay: String
    public var architecture: String
    public var bootStandard: String
    public var sha256Short: String
    public var sfSymbol: String
    public var isDownloaded: Bool
}

public struct DepotChannelSubscription: Identifiable, Hashable, Sendable {
    public let id: String
    public var name: String
    public var description: String
    public var itemCount: Int
    public var isEnabled: Bool
    public var sfSymbol: String
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
    public var targetDriveID: String = ""
    public var hardwareOrPath: String
    public var speedOrCodec: String
    public var simulationMode: Bool
    public var verifyAfterBurn: Bool
    public var compressAfterCreation: Bool
    public var copiesToBurn: Int = 1
    public var completedCopies: Int = 0
}

@MainActor
public final class KroutonStateStore: ObservableObject {
    @Published public var appearanceMode: AppAppearanceMode = .auto
    @Published public var selectedAccentIndex: Int = 8 // Default: Toasted Krouton Brown
    // macOS System Settings Theme & Window Extensions
    @Published public var iconWidgetStyle: IconWidgetStyleMode = .defaultStyle
    @Published public var folderColorMode: FolderColorMode = .automatic
    @Published public var sidebarIconSize: SidebarIconSizeMode = .medium
    @Published public var tintWindowWithWallpaper: Bool = false
    // Accessibility & VoiceOver Support
    @Published public var appLanguage: KroutonLanguage = .english {
        didSet { KroutonL10n.activeISOCode = appLanguage.isoCode }
    }
    @Published public var voiceOverSpokenTelemetry: Bool = true
    @Published public var a11yIncreaseContrast: Bool = false
    @Published public var a11yDifferentiateWithoutColor: Bool = true
    @Published public var a11yReduceMotion: Bool = false
    @Published public var rememberLastTaskOnLaunch: Bool = true
    @Published public var useBase10Units: Bool = true
    @Published public var scratchDiskPath: String = "~/Library/Caches/app.krouton.staging"
    @Published public var autoPurgeScratch: Bool = true

    @Published public var selectedSettingsPane: KroutonSettingsCategory = .general
    @Published public var selectedCategory: TaskMasterCategory = .burn
    @Published public var selectedTaskID: String = "data-hybrid"
    @Published public var bitsetVendorProfile: String = "Auto-Detect (MMC 0xFA / Pioneer / Lite-On / LG)"
    @Published public var autoLoadNextDiscBatchMode: Bool = true
    @Published public var autoLoadCountdownSeconds: Int = 5

    // Real Staged Files from Finder (Sprint 1)
    @Published public var stagedFiles: [StagedFileEntry] = []
    @Published public var redBookTracks: [RedBookAudioTrack] = [
        RedBookAudioTrack(url: URL(fileURLWithPath: "/System/Library/Sounds/Glass.aiff"), title: "01 - Analogue Warmth (Intro)", performer: "The Kroutons", isrcCode: "USKRO2600001", durationSeconds: 222.24, preGapSeconds: 2.0, transitionStyle: .standard2s),
        RedBookAudioTrack(url: URL(fileURLWithPath: "/System/Library/Sounds/Ping.aiff"), title: "02 - Optical Servo Lock", performer: "The Kroutons", isrcCode: "USKRO2600002", durationSeconds: 258.00, preGapSeconds: 0.0, transitionStyle: .gapless0s),
        RedBookAudioTrack(url: URL(fileURLWithPath: "/System/Library/Sounds/Hero.aiff"), title: "03 - Phthalocyanine Groove", performer: "The Kroutons", isrcCode: "USKRO2600003", durationSeconds: 311.53, preGapSeconds: 0.0, crossfadeSeconds: 2.0, transitionStyle: .jamCrossfade),
        RedBookAudioTrack(url: URL(fileURLWithPath: "/System/Library/Sounds/Purr.aiff"), title: "04 - Lead-Out Horizon", performer: "The Kroutons", isrcCode: "USKRO2600004", durationSeconds: 295.13, preGapSeconds: 2.0, transitionStyle: .standard2s)
    ]
    @Published public var discPerformer: String = "The Kroutons"
    @Published public var discMCNBarcode: String = "0123456789012"
    @Published public var enableHTOA: Bool = false
    @Published public var htoaTitle: String = "Hidden Track Zero (INDEX 00 Pre-Gap Secret Audio)"
    @Published public var htoaDurationSeconds: Double = 48.0
    @Published public var carSafeZeroPadPrefix: Bool = true
    @Published public var carSafeStripAppleDouble: Bool = true
    @Published public var carSafeGenerateM3U: Bool = true
    @Published public var includeUDFBridge: Bool = true
    @Published public var includeJolietNames: Bool = true
    @Published public var allowATIPOverburn: Bool = false
    @Published public var dualLayerBreakSectorLBA: Int64 = 2_086_912
    @Published public var discVolumeTitle: String = "KROUTON_DISC"

    @Published public var discFormats: [DiscFormatSpec] = [
        DiscFormatSpec(id: "cd-da", showInTaskChooser: true, technicalName: "CD-DA (Red Book)", colloquialName: "Audio CD w/ CD-TEXT & ISRC", launchYear: "1982", capacity: "700 MB / 80m", capacityGB: 0.7, laserType: "780nm IR", platform: "All CD / DVD / BD Players", deprecationStatus: "Current", sourceSupport: "New & Image", bookOrFileSystem: "IEC 60908 Red Book", sfSymbol: "waveform.circle.fill", filterGroup: .audio, isMediaPlaylist: true, isDataDisc: false),
        DiscFormatSpec(id: "mp3-cd", showInTaskChooser: true, technicalName: "ISO9660 / UDF Audio", colloquialName: "MP3 / FLAC Car-Safe Audio Disc", launchYear: "1998", capacity: "700 MB / 4.7 GB", capacityGB: 0.7, laserType: "780nm / 650nm", platform: "Car Stereos, Mac/PC, DVD Decks", deprecationStatus: "Current", sourceSupport: "New & Image", bookOrFileSystem: "ISO9660 + Joliet (ID3v2.3)", sfSymbol: "music.note.list", filterGroup: .audio, isMediaPlaylist: true, isDataDisc: false),
        DiscFormatSpec(id: "cd-extra", showInTaskChooser: true, technicalName: "CD-Extra (Blue Book)", colloquialName: "Enhanced Mixed-Mode Audio + Data CD", launchYear: "1995", capacity: "700 MB", capacityGB: 0.7, laserType: "780nm IR", platform: "CD Players + Mac/PC", deprecationStatus: "2008 (Legacy)", sourceSupport: "New & Image", bookOrFileSystem: "Multi-Session Red + Yellow", sfSymbol: "opticaldisc.fill", filterGroup: .audio, isMediaPlaylist: true, isDataDisc: true),
        DiscFormatSpec(id: "dts-cd", showInTaskChooser: false, technicalName: "DTS-CD (5.1 PCM Wrapper)", colloquialName: "5.1 Surround Sound Audio CD", launchYear: "1997", capacity: "700 MB", capacityGB: 0.7, laserType: "780nm IR", platform: "S/PDIF Home Theater Receivers", deprecationStatus: "2006 (Niche)", sourceSupport: "New & Image", bookOrFileSystem: "Red Book 14-bit DTS Coherent", sfSymbol: "hifispeaker.2.fill", filterGroup: .audio, isMediaPlaylist: true, isDataDisc: false),
        DiscFormatSpec(id: "dvd-audio", showInTaskChooser: false, technicalName: "DVD-Audio (AUDIO_TS)", colloquialName: "24-bit/192kHz Lossless MLP DVD", launchYear: "2000", capacity: "4.7 GB / 8.5 GB", capacityGB: 4.7, laserType: "650nm Red", platform: "DVD-Audio & Universal Players", deprecationStatus: "2009 (Audiophile)", sourceSupport: "New & Image", bookOrFileSystem: "UDF 1.02 + Meridian Lossless", sfSymbol: "waveform.badge.magnifyingglass", filterGroup: .audio, isMediaPlaylist: true, isDataDisc: false),
        DiscFormatSpec(id: "sacd-r", showInTaskChooser: false, technicalName: "Scarlet Book DSD (SACD-R)", colloquialName: "1-Bit 2.8MHz DSD Audiophile Disc", launchYear: "1999", capacity: "4.7 GB", capacityGB: 4.7, laserType: "650nm Red", platform: "SACD-R Compatible Decks", deprecationStatus: "2011 (Audiophile)", sourceSupport: "New & Image", bookOrFileSystem: "UDF 1.02 Scarlet Book (.dsf/.dff)", sfSymbol: "hifispeaker.fill", filterGroup: .audio, isMediaPlaylist: true, isDataDisc: false),

        DiscFormatSpec(id: "dvd-video", showInTaskChooser: true, technicalName: "DVD-Video (DVD-5 / DVD-9)", colloquialName: "Standard Movie DVD w/ Menus", launchYear: "1996", capacity: "4.7 GB / 8.5 GB", capacityGB: 4.7, laserType: "650nm Red", platform: "Standalone DVD & BD Players", deprecationStatus: "Current", sourceSupport: "New & Image", bookOrFileSystem: "UDF 1.02 Bridge (VIDEO_TS)", sfSymbol: "film.fill", filterGroup: .video, isMediaPlaylist: true, isDataDisc: false),
        DiscFormatSpec(id: "bd-on-dvd", showInTaskChooser: true, technicalName: "AVCHD / BD-5 / BD-9", colloquialName: "1080p Blu-ray Video on 4.7GB DVD", launchYear: "2006", capacity: "4.7 GB / 8.5 GB", capacityGB: 4.7, laserType: "650nm Red", platform: "Blu-ray Players, PS3/PS4/PS5", deprecationStatus: "Current", sourceSupport: "New & Image", bookOrFileSystem: "UDF 2.50 (BDMV on DVD)", sfSymbol: "sparkles.tv.fill", filterGroup: .video, isMediaPlaylist: true, isDataDisc: false),
        DiscFormatSpec(id: "bd-25", showInTaskChooser: true, technicalName: "BD-R / BD-RE SL (BDMV)", colloquialName: "25 GB Single-Layer Blu-ray Video", launchYear: "2006", capacity: "25.0 GB", capacityGB: 25.0, laserType: "405nm Violet", platform: "Blu-ray Players & Consoles", deprecationStatus: "Current", sourceSupport: "New & Image", bookOrFileSystem: "UDF 2.50 / 2.60 (BDMV)", sfSymbol: "film.stack.fill", filterGroup: .video, isMediaPlaylist: true, isDataDisc: false),
        DiscFormatSpec(id: "bd-50", showInTaskChooser: true, technicalName: "BD-R DL Dual-Layer (BDMV)", colloquialName: "50 GB Dual-Layer Blu-ray Video", launchYear: "2006", capacity: "50.0 GB", capacityGB: 50.0, laserType: "405nm Violet", platform: "Blu-ray Players & Consoles", deprecationStatus: "Current", sourceSupport: "New & Image", bookOrFileSystem: "UDF 2.50 Seamless Break", sfSymbol: "square.stack.3d.up.fill", filterGroup: .video, isMediaPlaylist: true, isDataDisc: false),
        DiscFormatSpec(id: "bd-uhd", showInTaskChooser: true, technicalName: "BDXL / UHD-BD (TL / QL)", colloquialName: "4K UHD HDR10 / Dolby Atmos Blu-ray", launchYear: "2016", capacity: "66 / 100 / 128 GB", capacityGB: 100.0, laserType: "405nm Violet", platform: "4K UHD Players, Xbox/PS5", deprecationStatus: "Current", sourceSupport: "New & Image", bookOrFileSystem: "UDF 2.60 HEVC 10-bit HDR", sfSymbol: "4k.tv.fill", filterGroup: .video, isMediaPlaylist: true, isDataDisc: false),

        DiscFormatSpec(id: "image-burn", showInTaskChooser: true, technicalName: "Burn Disc Image (.ISO / .BIN / .DMG)", colloquialName: "Sector-Exact Image & Bootable OS Burner", launchYear: "1988", capacity: "700 MB - 128 GB", capacityGB: 4.7, laserType: "All Lasers", platform: "Bootable PC, Mac, Linux & Consoles", deprecationStatus: "Current", sourceSupport: "Disc Image", bookOrFileSystem: "El Torito / APM / Raw 2,352B & 2,048B", sfSymbol: "opticaldisc.fill", filterGroup: .data, isMediaPlaylist: false, isDataDisc: false),
        DiscFormatSpec(id: "data-hybrid", showInTaskChooser: true, technicalName: "Universal Hybrid Data (Mac + PC + Linux)", colloquialName: "4-Way Bridge (UDF + HFS+ + Joliet + Rock Ridge)", launchYear: "1995", capacity: "700 MB - 128 GB", capacityGB: 4.7, laserType: "All Lasers", platform: "Every Mac, Windows & Linux PC", deprecationStatus: "Current", sourceSupport: "New File Tree", bookOrFileSystem: "UDF 1.02 + HFS+ + ISO9660/Joliet", sfSymbol: "externaldrive.fill.badge.plus", filterGroup: .data, isMediaPlaylist: false, isDataDisc: true),
        DiscFormatSpec(id: "data-udf-modern", showInTaskChooser: true, technicalName: "UDF 2.60 Large-File Data (>4 GiB)", colloquialName: "Unrestricted Single Files up to 128 GB", launchYear: "2005", capacity: "4.7 GB - 128 GB", capacityGB: 25.0, laserType: "650nm / 405nm", platform: "macOS 10.5+, Windows 7/10/11, Linux", deprecationStatus: "Current", sourceSupport: "New File Tree", bookOrFileSystem: "Pure ECMA-167 UDF 2.50 / 2.60", sfSymbol: "internaldrive.fill", filterGroup: .data, isMediaPlaylist: false, isDataDisc: true),
        DiscFormatSpec(id: "data-apple-apfs", showInTaskChooser: false, technicalName: "Apple Native Volume (APFS / HFS+)", colloquialName: "Full macOS Metadata, xattrs & Resource Forks", launchYear: "2017", capacity: "700 MB - 128 GB", capacityGB: 4.7, laserType: "All Lasers", platform: "macOS Only (68k/PPC/Intel/Apple Silicon)", deprecationStatus: "Current", sourceSupport: "New File Tree", bookOrFileSystem: "APFS / HFS+ Journaled Container", sfSymbol: "apple.logo", filterGroup: .data, isMediaPlaylist: false, isDataDisc: true),
        DiscFormatSpec(id: "data-retro-iso", showInTaskChooser: false, technicalName: "ISO9660 Level 1 (Retro 8.3 DOS / Win9x)", colloquialName: "Strict 8.3 Uppercase for Vintage PCs & System 7", launchYear: "1988", capacity: "650 MB / 700 MB", capacityGB: 0.7, laserType: "780nm IR", platform: "MS-DOS, Win 3.1/95, OS/2, Classic Mac", deprecationStatus: "1999 (Vintage)", sourceSupport: "New File Tree", bookOrFileSystem: "ECMA-119 Level 1 (8.3) + HFS Bridge", sfSymbol: "desktopcomputer", filterGroup: .data, isMediaPlaylist: false, isDataDisc: true),
        DiscFormatSpec(id: "video-svcd", showInTaskChooser: false, technicalName: "VCD 2.0 / Super Video CD (White Book)", colloquialName: "MPEG-1 / MPEG-2 Video on Standard CD-R", launchYear: "1993", capacity: "700 MB / 80m", capacityGB: 0.7, laserType: "780nm IR", platform: "VCD / DVD Players & Retro Consoles", deprecationStatus: "2005 (Legacy)", sourceSupport: "New & Image", bookOrFileSystem: "IEC 62107 Mode 2 Form 2 (2,324 B/sec)", sfSymbol: "tv.circle.fill", filterGroup: .video, isMediaPlaylist: true, isDataDisc: false),
        DiscFormatSpec(id: "mdisc-vault", showInTaskChooser: true, technicalName: "M-DISC Archival + PAR2", colloquialName: "1,000-Year Inorganic Vault w/ Parity", launchYear: "2009", capacity: "25 / 50 / 100 GB", capacityGB: 25.0, laserType: "405nm / 650nm", platform: "macOS, Windows, Linux", deprecationStatus: "Current", sourceSupport: "New & Image", bookOrFileSystem: "UDF 2.60 + 10% PAR2 Recovery", sfSymbol: "lock.shield.fill", filterGroup: .data, isMediaPlaylist: false, isDataDisc: true),
        DiscFormatSpec(id: "dvd-ram", showInTaskChooser: false, technicalName: "DVD-RAM (UDF 1.50 / 2.01)", colloquialName: "Random-Access Zoned Rewritable Disc", launchYear: "1996", capacity: "4.7 GB / 9.4 GB", capacityGB: 4.7, laserType: "650nm Red", platform: "Broadcast Recorders, Mac/PC", deprecationStatus: "2015 (Pro Broadcast)", sourceSupport: "New & Image", bookOrFileSystem: "Hardware Defect Mgmt UDF", sfSymbol: "memorychip.fill", filterGroup: .data, isMediaPlaylist: false, isDataDisc: true),

        DiscFormatSpec(id: "console-wii", showInTaskChooser: true, technicalName: "Nintendo Wii (RVL-006)", colloquialName: "Wii Optical Disc (.rvz / .wbfs / .iso)", launchYear: "2006", capacity: "4.7 GB / 8.54 GB", capacityGB: 4.7, laserType: "650nm Red", platform: "Nintendo Wii & Dolphin", deprecationStatus: "Archival", sourceSupport: "Image Only", bookOrFileSystem: "Wii Partition Table (.rvz/.wbfs)", sfSymbol: "gamecontroller.fill", filterGroup: .console, isMediaPlaylist: false, isDataDisc: false),
        DiscFormatSpec(id: "console-gc", showInTaskChooser: true, technicalName: "Nintendo GameCube (DOL-006)", colloquialName: "80mm GameCube Mini-DVD (.rvz / .gcm)", launchYear: "2001", capacity: "1.46 GB (80mm)", capacityGB: 1.46, laserType: "650nm Red", platform: "GameCube, Wii & Dolphin", deprecationStatus: "Archival", sourceSupport: "Image Only", bookOrFileSystem: "GCM / RVZ Sector Rebuilder", sfSymbol: "circle.grid.cross.fill", filterGroup: .console, isMediaPlaylist: false, isDataDisc: false),
        DiscFormatSpec(id: "console-ps2", showInTaskChooser: true, technicalName: "PlayStation 2 DVD / CD", colloquialName: "Sony PS2 Game Disc (+ FreeDVDBoot ESR)", launchYear: "2000", capacity: "700 MB / 4.7 GB", capacityGB: 4.7, laserType: "650nm / 780nm", platform: "PlayStation 2 & PCSX2", deprecationStatus: "Archival", sourceSupport: "Image Only", bookOrFileSystem: "ISO9660 + UDF 1.02 (.iso/.chd)", sfSymbol: "playstation.logo", filterGroup: .console, isMediaPlaylist: false, isDataDisc: false),
        DiscFormatSpec(id: "console-ps1", showInTaskChooser: true, technicalName: "PlayStation CD-ROM XA", colloquialName: "Sony PS1 Mode 2 Form 2 (.bin/.cue/.chd)", launchYear: "1994", capacity: "650 MB", capacityGB: 0.65, laserType: "780nm IR", platform: "PlayStation 1/2/3 & DuckStation", deprecationStatus: "Archival", sourceSupport: "Image Only", bookOrFileSystem: "2352-Byte Raw + Subchannel", sfSymbol: "playstation.logo", filterGroup: .console, isMediaPlaylist: false, isDataDisc: false),
        DiscFormatSpec(id: "console-ps3", showInTaskChooser: false, technicalName: "PlayStation 3 BD-ROM", colloquialName: "Sony PS3 Blu-ray Game Disc (PS3_GAME)", launchYear: "2006", capacity: "25 GB / 50 GB", capacityGB: 25.0, laserType: "405nm Violet", platform: "PlayStation 3 & RPCS3", deprecationStatus: "Archival", sourceSupport: "New & Image", bookOrFileSystem: "UDF 2.50 PS3 Volume Header", sfSymbol: "opticaldisc", filterGroup: .console, isMediaPlaylist: false, isDataDisc: true),
        DiscFormatSpec(id: "console-xbox", showInTaskChooser: true, technicalName: "Xbox XDVDFS (XGD1 / XGD2)", colloquialName: "Original Xbox & Xbox 360 (.xiso)", launchYear: "2001", capacity: "4.7 GB / 7.95 GB", capacityGB: 4.7, laserType: "650nm Red", platform: "Original Xbox, 360 & xemu", deprecationStatus: "Archival", sourceSupport: "New & Image", bookOrFileSystem: "Microsoft XDVDFS Partition", sfSymbol: "xbox.logo", filterGroup: .console, isMediaPlaylist: false, isDataDisc: true),
        DiscFormatSpec(id: "console-dc", showInTaskChooser: false, technicalName: "Dreamcast MIL-CD / GD-ROM", colloquialName: "Sega Dreamcast Self-Boot (.cdi / .gdi)", launchYear: "1998", capacity: "700 MB / 1.0 GB", capacityGB: 0.7, laserType: "780nm IR", platform: "Sega Dreamcast & Flycast", deprecationStatus: "Archival", sourceSupport: "Image Only", bookOrFileSystem: "Multi-Session Audio + Data", sfSymbol: "hurricane", filterGroup: .console, isMediaPlaylist: false, isDataDisc: false),
        DiscFormatSpec(id: "console-saturn", showInTaskChooser: false, technicalName: "Sega Saturn / Mega-CD", colloquialName: "Saturn & Sega CD Mixed-Mode (.chd/.cue)", launchYear: "1991", capacity: "650 MB", capacityGB: 0.65, laserType: "780nm IR", platform: "Sega Saturn, Sega CD & Mednafen", deprecationStatus: "Archival", sourceSupport: "Image Only", bookOrFileSystem: "Track 1 ISO + Red Book Audio", sfSymbol: "globe.asia.australia.fill", filterGroup: .console, isMediaPlaylist: false, isDataDisc: false),
        DiscFormatSpec(id: "console-3do", showInTaskChooser: false, technicalName: "3DO / PC Engine CD-ROM²", colloquialName: "3DO Interactive & TurboGrafx-CD", launchYear: "1988", capacity: "650 MB", capacityGB: 0.65, laserType: "780nm IR", platform: "3DO, PC Engine & RetroArch", deprecationStatus: "Archival", sourceSupport: "Image Only", bookOrFileSystem: "Opera FS / Mode 1 Raw", sfSymbol: "sparkles.rectangle.stack.fill", filterGroup: .console, isMediaPlaylist: false, isDataDisc: false),

        DiscFormatSpec(id: "macos9-hfs", showInTaskChooser: false, technicalName: "HFS Standard (Mac OS 9 APM)", colloquialName: "Bootable Classic System 7 / OS 9 CD", launchYear: "1985", capacity: "650 MB", capacityGB: 0.65, laserType: "780nm IR", platform: "68k & PowerPC Macintoshes", deprecationStatus: "2002 (Obsolete)", sourceSupport: "New & Image", bookOrFileSystem: "Apple Partition Map + Blessed HFS", sfSymbol: "desktopcomputer", filterGroup: .legacy, isMediaPlaylist: false, isDataDisc: true),
        DiscFormatSpec(id: "photo-cd", showInTaskChooser: false, technicalName: "Kodak Photo CD (Beige Book)", colloquialName: "Multi-Resolution .PCD Archival Disc", launchYear: "1992", capacity: "650 MB", capacityGB: 0.65, laserType: "780nm IR", platform: "Photo CD Decks & Mac/PC", deprecationStatus: "2004 (Obsolete)", sourceSupport: "New & Image", bookOrFileSystem: "CD-ROM XA Bridge (Image Pac)", sfSymbol: "camera.aperture", filterGroup: .legacy, isMediaPlaylist: false, isDataDisc: true),
        DiscFormatSpec(id: "vcd-svcd", showInTaskChooser: false, technicalName: "White Book VCD / SVCD", colloquialName: "Video CD (MPEG-1 / MPEG-2)", launchYear: "1993", capacity: "700 MB", capacityGB: 0.7, laserType: "780nm IR", platform: "VCD & DVD Players", deprecationStatus: "2005 (Obsolete)", sourceSupport: "New & Image", bookOrFileSystem: "Mode 2 Form 2 (2324-Byte)", sfSymbol: "play.tv.fill", filterGroup: .legacy, isMediaPlaylist: true, isDataDisc: false),
        DiscFormatSpec(id: "cd-g", showInTaskChooser: false, technicalName: "Red Book + R-W Subchannel", colloquialName: "Karaoke CD+G Graphics Disc", launchYear: "1985", capacity: "700 MB", capacityGB: 0.7, laserType: "780nm IR", platform: "Karaoke Decks", deprecationStatus: "2010 (Legacy)", sourceSupport: "Image Only", bookOrFileSystem: "Raw 96-Byte R-W Subchannel", sfSymbol: "mic.fill", filterGroup: .legacy, isMediaPlaylist: true, isDataDisc: false)
    ]

    @Published public var depotChannels: [DepotChannelSubscription] = [
        DepotChannelSubscription(id: "rescue", name: "System Rescue, Partitioning & Hardware Diagnostics", description: "SystemRescue, GParted Live, Rescuezilla, Memtest86+, FreeDOS 1.4 BIOS Room", itemCount: 14, isEnabled: true, sfSymbol: "cross.case.fill"),
        DepotChannelSubscription(id: "linux", name: "Live Linux & BSD Official Optical Releases", description: "Ubuntu LTS, Fedora Workstation, Debian Live, Arch, FreeBSD Boot-Only & DVD", itemCount: 28, isEnabled: true, sfSymbol: "terminal.fill"),
        DepotChannelSubscription(id: "windows", name: "Microsoft Windows & DOS Official ISO API", description: "Direct Microsoft token downloader for Windows 11 (w/ DVD-5 Splitter) & Windows 10", itemCount: 8, isEnabled: true, sfSymbol: "window.ceiling"),
        DepotChannelSubscription(id: "vintage-mac", name: "Internet Archive — Vintage Apple & Classic Mac OS", description: "Mac OS 9.2.2 Universal, System 7.5.3, Apple Hardware Test, PowerPC Restore Discs", itemCount: 42, isEnabled: true, sfSymbol: "desktopcomputer"),
        DepotChannelSubscription(id: "shareware", name: "Internet Archive — 90s Cover Discs & Shareware Vault", description: "MacAddict, Macworld, Next Generation, and classic demo CDs", itemCount: 65, isEnabled: false, sfSymbol: "opticaldisc.fill")
    ]
    @Published public var customDepotFeedURL: String = "https://depot.krouton.app/v1/manifest.json"
    @Published public var autoVerifyDepotSHA256: Bool = true
    @Published public var enableVMTestBootInDepot: Bool = true

    @Published public var depotItems: [DepotCatalogItem] = [
        DepotCatalogItem(id: "sysrescue-11", title: "SystemRescue 11.03 Live", subtitle: "Complete ZFS/Btrfs/APFS recovery, partitioning, ddrescue & network tools", channel: "Rescue & Diagnostics", version: "11.03 (2026)", sizeDisplay: "854 MB", architecture: "x86_64 / UEFI", bootStandard: "El Torito BIOS + UEFI", sha256Short: "8f4a...e91c", sfSymbol: "cross.case.fill", isDownloaded: true),
        DepotCatalogItem(id: "freedos-14", title: "FreeDOS 1.4 Live + BIOS Flasher Room", subtitle: "Classic DOS environment with 600 MB open space to inject motherboard/drive firmware", channel: "Rescue & Diagnostics", version: "1.4 Final", sizeDisplay: "412 MB", architecture: "x86 Real Mode", bootStandard: "El Torito Floppy/HD Emulation", sha256Short: "3c19...b04d", sfSymbol: "cpu.fill", isDownloaded: true),
        DepotCatalogItem(id: "macos922-uni", title: "Mac OS 9.2.2 Universal Boot CD (Classic APM)", subtitle: "Bootable HFS Standard + Apple Partition Map for PowerMac G3/G4 & iBook", channel: "Vintage Apple (archive.org)", version: "9.2.2 (2002)", sizeDisplay: "618 MB", architecture: "PowerPC", bootStandard: "Apple Partition Map + Blessed Folder", sha256Short: "a72e...441f", sfSymbol: "desktopcomputer", isDownloaded: false),
        DepotCatalogItem(id: "ubuntu-2604", title: "Ubuntu Desktop 26.04 LTS Live DVD", subtitle: "Official Canonical Live Desktop & Installer (ARM64 Apple Silicon VM & x86_64)", channel: "Live Linux & BSD", version: "26.04 LTS", sizeDisplay: "4.48 GB", architecture: "ARM64 / x86_64", bootStandard: "UEFI ESP + El Torito", sha256Short: "e901...772a", sfSymbol: "terminal.fill", isDownloaded: false)
    ]

    @Published public var defaultCrossfadeSec: Double = 3.5
    @Published public var autoBeatmatchSoundAnalysis: Bool = true
    @Published public var carSafeMP3Mode: Bool = true
    @Published public var singleVideoFirstPlay: Bool = true
    @Published public var fitToDiscPreserveMenus: Bool = true
    @Published public var fitToDiscStripForeignDubs: Bool = true
    @Published public var videoToolboxTwoPassVBR: Bool = true

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

    @Published public var notificationMatrix: [NotificationEventRow] = [
        NotificationEventRow(id: "start", eventTitle: "Burn, rip, or transcode started", eventSubtitle: "Triggered when laser calibration or extraction begins", bannerEnabled: true, iPhoneEnabled: true, watchEnabled: false, soundEnabled: false),
        NotificationEventRow(id: "done", eventTitle: "Task completed & verified", eventSubtitle: "Triggered when all queued destinations finish without error", bannerEnabled: true, iPhoneEnabled: true, watchEnabled: true, soundEnabled: true),
        NotificationEventRow(id: "err", eventTitle: "Task failed or buffer underrun", eventSubtitle: "Critical hardware, media, or network link interruption", bannerEnabled: true, iPhoneEnabled: true, watchEnabled: true, soundEnabled: true),
        NotificationEventRow(id: "layer", eventTitle: "Dual-layer (L0 -> L1) break reached", eventSubtitle: "DVD-9 or BD-50 seamless layer transition point", bannerEnabled: true, iPhoneEnabled: false, watchEnabled: true, soundEnabled: false),
        NotificationEventRow(id: "swap", eventTitle: "Blank disc or tray swap required", eventSubtitle: "Multi-disc queue waiting for operator", bannerEnabled: true, iPhoneEnabled: true, watchEnabled: true, soundEnabled: true),
        NotificationEventRow(id: "depot", eventTitle: "Disc Image Depot download verified", eventSubtitle: "ISO / image downloaded and SHA-256 verified", bannerEnabled: true, iPhoneEnabled: false, watchEnabled: false, soundEnabled: true)
    ]

    // Default to Physical Burner (MATSHITA DVD-R UJ-898)
    @Published public var destinationQueue: [DestinationQueueItem] = [
        DestinationQueueItem(
            kind: .physicalBurner,
            hardwareOrPath: "MATSHITA DVD-R UJ-898 (Local USB)",
            speedOrCodec: "Max Safe (Auto)",
            simulationMode: false,
            verifyAfterBurn: true,
            compressAfterCreation: false
        )
    ]

    public func multicolorPresetID(forTaskID taskID: String, category: TaskMasterCategory) -> Int {
        switch category {
        case .depot: return 4 // Cyan / Teal
        case .copy:  return 1 // Orange
        case .label: return 0 // Coral Red
        case .burn:
            if let spec = discFormats.first(where: { $0.id == taskID }) {
                switch spec.filterGroup {
                case .audio:   return 3 // Emerald Green for Audio CDs
                case .video:   return 5 // 405nm Laser Blue for Video / Blu-ray
                case .console: return 7 // Indigo / Violet for Retro Console ROMs
                case .legacy:  return 8 // Toasted Brown for Vintage / Niche
                case .data, .all, .enabled:
                    return spec.id.contains("mdisc") ? 2 : 6 // Gold for M-DISC Vault, Slate Blue for Data
                }
            }
            return 6
        }
    }

    public func effectiveColorForTask(id taskID: String, category: TaskMasterCategory) -> Color {
        let resolvedScheme: ColorScheme = {
            switch appearanceMode {
            case .light: return .light
            case .dark: return .dark
            case .auto:
                let isDark = NSApp?.effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
                return isDark ? .dark : .light
            }
        }()
        if selectedAccentIndex == -1 {
            let pid = multicolorPresetID(forTaskID: taskID, category: category)
            let p = AccentColorPreset.allPresets.first(where: { $0.id == pid }) ?? resolvedAccentPreset
            return p.effectiveAccent(for: resolvedScheme)
        }
        return activeAccent
    }

    private var resolvedAccentPreset: AccentColorPreset {
        if selectedAccentIndex == -1 {
            let targetID = multicolorPresetID(forTaskID: selectedTaskID, category: selectedCategory)
            return AccentColorPreset.allPresets.first(where: { $0.id == targetID }) ?? AccentColorPreset.allPresets[1]
        }
        return AccentColorPreset.allPresets.first(where: { $0.id == selectedAccentIndex })
            ?? AccentColorPreset.allPresets.first(where: { $0.id == 8 })
            ?? AccentColorPreset.allPresets[0]
    }

    public var activeAccent: Color {
        let resolvedScheme: ColorScheme = {
            switch appearanceMode {
            case .light: return .light
            case .dark: return .dark
            case .auto:
                let isDark = NSApp?.effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
                return isDark ? .dark : .light
            }
        }()
        return resolvedAccentPreset.effectiveAccent(for: resolvedScheme)
    }

    public var activeOnAccentText: Color {
        let resolvedScheme: ColorScheme = {
            switch appearanceMode {
            case .light: return .light
            case .dark: return .dark
            case .auto:
                let isDark = NSApp?.effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
                return isDark ? .dark : .light
            }
        }()
        return resolvedAccentPreset.effectiveOnAccentText(for: resolvedScheme)
    }

    public var activeLocale: Locale {
        Locale(identifier: appLanguage.isoCode)
    }

    public var totalStagedBytes: Int64 {
        stagedFiles.reduce(0) { $0 + $1.byteSize }
    }

    public var totalStagedSectorsLBA: Int64 {
        stagedFiles.reduce(0) { $0 + $1.sectorsLBA }
    }

    public var namingPreviewString: String {
        let joined = namingTokens.joined()
            .replacingOccurrences(of: "[Track 01]", with: "01")
            .replacingOccurrences(of: "[Artist]", with: "The Krouton Trio")
            .replacingOccurrences(of: "[Album]", with: "Oakland Sessions")
            .replacingOccurrences(of: "[Title]", with: "Analogue Horizon")
            .replacingOccurrences(of: "[Year]", with: "2026")
        return joined.isEmpty ? "01 - Track.m4a" : "\(joined).m4a"
    }

    public func toggleFormatVisibility(id: String) {
        if let idx = discFormats.firstIndex(where: { $0.id == id }) {
            discFormats[idx].showInTaskChooser.toggle()
        }
    }

    public func addStagedURLs(_ urls: [URL]) {
        for url in urls {
            if !stagedFiles.contains(where: { $0.url == url }) {
                let entry = DriveManager.inspectFileOrFolder(url: url)
                stagedFiles.append(entry)
            }
        }
    }

    public func addAudioTrackURLs(_ urls: [URL]) {
        for url in urls {
            let nextIndex = redBookTracks.count + 1
            let track = DriveManager.inspectAudioTrack(url: url, index: nextIndex)
            redBookTracks.append(track)
        }
    }

    public func removeAudioTrack(id: UUID) {
        redBookTracks.removeAll { $0.id == id }
    }

    public var totalRedBookFramesLBA: Int64 {
        let tracksFrames = redBookTracks.reduce(Int64(0)) { $0 + $1.totalRedBookFrames }
        let htoaFrames = enableHTOA ? Int64(round(htoaDurationSeconds * 75.0)) : 0
        return tracksFrames + htoaFrames
    }

    public var totalRedBookBytes: Int64 {
        totalRedBookFramesLBA * 2352
    }

    public func autoSanitizeLongFilenames() {
        for idx in stagedFiles.indices {
            let name = stagedFiles[idx].name
            if name.count > 31 {
                let ext = stagedFiles[idx].url.pathExtension
                let stem = stagedFiles[idx].url.deletingPathExtension().lastPathComponent
                let maxStem = max(8, 30 - (ext.isEmpty ? 0 : ext.count + 1))
                let trimmedStem = String(stem.prefix(maxStem))
                let newName = ext.isEmpty ? trimmedStem : "\(trimmedStem).\(ext)"
                stagedFiles[idx] = StagedFileEntry(
                    id: stagedFiles[idx].id,
                    url: stagedFiles[idx].url,
                    name: newName,
                    isDirectory: stagedFiles[idx].isDirectory,
                    byteSize: stagedFiles[idx].byteSize,
                    itemCount: stagedFiles[idx].itemCount,
                    posixPermissions: stagedFiles[idx].posixPermissions,
                    modifiedDate: stagedFiles[idx].modifiedDate,
                    showOnMac: stagedFiles[idx].showOnMac,
                    showOnPC: stagedFiles[idx].showOnPC
                )
            }
        }
    }

    public func removeStagedFile(id: UUID) {
        stagedFiles.removeAll { $0.id == id }
    }

    public func toggleMacVisibility(id: UUID) {
        guard let idx = stagedFiles.firstIndex(where: { $0.id == id }) else { return }
        stagedFiles[idx].showOnMac.toggle()
        if !stagedFiles[idx].showOnMac && !stagedFiles[idx].showOnPC {
            stagedFiles[idx].showOnPC = true
        }
    }

    public func togglePCVisibility(id: UUID) {
        guard let idx = stagedFiles.firstIndex(where: { $0.id == id }) else { return }
        stagedFiles[idx].showOnPC.toggle()
        if !stagedFiles[idx].showOnPC && !stagedFiles[idx].showOnMac {
            stagedFiles[idx].showOnMac = true
        }
    }

    public func enableCurrentTaskChooserFormat() {
        if let idx = discFormats.firstIndex(where: { $0.id == selectedTaskID }) {
            discFormats[idx].showInTaskChooser = true
        }
    }

    public var resolvedFolderIconColor: Color {
        folderColorMode.resolvedFolderColor(accent: activeAccent)
    }

    public func announceForVoiceOver(_ message: String) {
        guard voiceOverSpokenTelemetry else { return }
        if let mainWin = NSApp.mainWindow {
            NSAccessibility.post(
                element: mainWin,
                notification: .announcementRequested,
                userInfo: [
                    .announcement: message,
                    .priority: NSAccessibilityPriorityLevel.high.rawValue
                ]
            )
        }
    }

    /// Real Apple Bundle.module .lproj localization lookup (Sources/KroutonApp/Resources/<lang>.lproj/Localizable.strings)
    public func tr(_ key: String) -> String {
        KroutonL10n.activeISOCode = appLanguage.isoCode
        let code = appLanguage.isoCode
        if let lprojPath = Bundle.module.path(forResource: code, ofType: "lproj"),
           let langBundle = Bundle(path: lprojPath) {
            let localized = langBundle.localizedString(forKey: key, value: key, table: "Localizable")
            if localized != key {
                return localized
            }
        }
        if let fallbackPath = Bundle.module.path(forResource: String(code.prefix(2)), ofType: "lproj"),
           let langBundle = Bundle(path: fallbackPath) {
            return langBundle.localizedString(forKey: key, value: key, table: "Localizable")
        }
        return Bundle.module.localizedString(forKey: key, value: key, table: "Localizable")
    }

    public func convertStagedBinOrIso(id: UUID) {
        guard let idx = stagedFiles.firstIndex(where: { $0.id == id }) else { return }
        let entry = stagedFiles[idx]
        let ext = entry.url.pathExtension.lowercased()
        let baseURL = entry.url.deletingPathExtension()

        if ext == "bin" {
            // Convert 2,352 B/sector .BIN -> 2,048 B/sector .ISO
            let newURL = baseURL.appendingPathExtension("iso")
            let convertedBytes = max(2048, (entry.byteSize / 2352) * 2048)
            var updated = StagedFileEntry(
                url: newURL,
                name: newURL.lastPathComponent,
                isDirectory: false,
                byteSize: convertedBytes,
                itemCount: 1,
                posixPermissions: entry.posixPermissions,
                modifiedDate: entry.modifiedDate,
                showOnMac: entry.showOnMac,
                showOnPC: entry.showOnPC
            )
            updated.showOnMac = entry.showOnMac
            updated.showOnPC = entry.showOnPC
            stagedFiles[idx] = updated
            announceForVoiceOver("Converted \(entry.name) from 2,352 byte raw BIN sectors to 2,048 byte ISO image.")
        } else if ext == "iso" || ext == "cdr" {
            // Convert 2,048 B/sector .ISO -> 2,352 B/sector .BIN + .CUE
            let newBinURL = baseURL.appendingPathExtension("bin")
            let convertedBytes = max(2352, (entry.byteSize / 2048) * 2352)
            var updated = StagedFileEntry(
                url: newBinURL,
                name: newBinURL.lastPathComponent,
                isDirectory: false,
                byteSize: convertedBytes,
                itemCount: 1,
                posixPermissions: entry.posixPermissions,
                modifiedDate: entry.modifiedDate,
                showOnMac: entry.showOnMac,
                showOnPC: entry.showOnPC
            )
            updated.showOnMac = entry.showOnMac
            updated.showOnPC = entry.showOnPC
            stagedFiles[idx] = updated
            announceForVoiceOver("Converted \(entry.name) to 2,352 byte raw BIN sectors with CUE sheet.")
        }
    }

    public func clearStagedFiles() {
        stagedFiles.removeAll()
    }

    public init() {}
}


// MARK: - Functional Icon & Widget Style Renderer (Default / Dark / Clear / Tinted)
public struct KroutonStyledIconBadge: View {
    public let sfSymbol: String
    public let tintColor: Color
    public let style: IconWidgetStyleMode
    public let isSelectedRow: Bool
    public let onAccentText: Color
    public let size: CGFloat
    public let symbolSize: CGFloat

    public init(
        sfSymbol: String,
        tintColor: Color,
        style: IconWidgetStyleMode,
        isSelectedRow: Bool = false,
        onAccentText: Color = .white,
        size: CGFloat = 24,
        symbolSize: CGFloat = 13
    ) {
        self.sfSymbol = sfSymbol
        self.tintColor = tintColor
        self.style = style
        self.isSelectedRow = isSelectedRow
        self.onAccentText = onAccentText
        self.size = size
        self.symbolSize = symbolSize
    }

    public var body: some View {
        ZStack {
            switch style {
            case .defaultStyle:
                RoundedRectangle(cornerRadius: size * 0.28)
                    .fill(
                        isSelectedRow
                            ? AnyShapeStyle(onAccentText.opacity(0.22))
                            : AnyShapeStyle(LinearGradient(colors: [tintColor, tintColor.opacity(0.72)], startPoint: .topLeading, endPoint: .bottomTrailing))
                    )
                Image(systemName: sfSymbol)
                    .font(.system(size: symbolSize, weight: .semibold))
                    .foregroundStyle(isSelectedRow ? onAccentText : .white)

            case .dark:
                RoundedRectangle(cornerRadius: size * 0.28)
                    .fill(
                        LinearGradient(
                            colors: [Color(red: 0.14, green: 0.15, blue: 0.18), Color(red: 0.07, green: 0.08, blue: 0.10)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: size * 0.28)
                            .stroke(tintColor.opacity(0.45), lineWidth: 1)
                    )
                Image(systemName: sfSymbol)
                    .font(.system(size: symbolSize, weight: .semibold))
                    .foregroundStyle(tintColor)

            case .clear:
                RoundedRectangle(cornerRadius: size * 0.28)
                    .fill(Color.primary.opacity(0.08))
                    .overlay(
                        RoundedRectangle(cornerRadius: size * 0.28)
                            .stroke(isSelectedRow ? onAccentText.opacity(0.6) : Color.primary.opacity(0.24), lineWidth: 1)
                    )
                Image(systemName: sfSymbol)
                    .font(.system(size: symbolSize, weight: .semibold))
                    .foregroundStyle(isSelectedRow ? onAccentText : .primary)

            case .tinted:
                RoundedRectangle(cornerRadius: size * 0.28)
                    .fill(tintColor.opacity(isSelectedRow ? 0.30 : 0.16))
                    .overlay(
                        RoundedRectangle(cornerRadius: size * 0.28)
                            .stroke(tintColor.opacity(0.55), lineWidth: 1)
                    )
                Image(systemName: sfSymbol)
                    .font(.system(size: symbolSize, weight: .semibold))
                    .foregroundStyle(isSelectedRow ? onAccentText : tintColor)
            }
        }
        .frame(width: size, height: size)
    }
}


// MARK: - Global Bundle.module .lproj Localization Resolver (Accessible from any View or Struct)
public enum KroutonL10n {
    nonisolated(unsafe) public static var activeISOCode: String = "en"

    public static func tr(_ key: String) -> String {
        let code = activeISOCode
        if let lprojPath = Bundle.module.path(forResource: code, ofType: "lproj"),
           let langBundle = Bundle(path: lprojPath) {
            let localized = langBundle.localizedString(forKey: key, value: key, table: "Localizable")
            if localized != key {
                return localized
            }
        }
        if let fallbackPath = Bundle.module.path(forResource: String(code.prefix(2)), ofType: "lproj"),
           let langBundle = Bundle(path: fallbackPath) {
            return langBundle.localizedString(forKey: key, value: key, table: "Localizable")
        }
        return Bundle.module.localizedString(forKey: key, value: key, table: "Localizable")
    }
}
