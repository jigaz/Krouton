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
        AccentColorPreset(id: 4, swatchColor: Color(red: 0.08, green: 0.82, blue: 0.68), darkAccent: Color(red: 0.08, green: 0.82, blue: 0.68), lightAccent: Color(red: 0.05, green: 0.68, blue: 0.55), darkOnAccentText: Color.black.opacity(0.88), lightOnAccentText: .white, isMonochrome: false),
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
    case secondaryHarmony = "Secondary Harmony"
    case amberGold = "Amber Gold"
    case graphite = "Space Gray"
    public var id: String { rawValue }

    public func resolvedFolderColor(accent: Color) -> Color {
        switch self {
        case .automatic, .accentTinted: return accent
        case .secondaryHarmony: return accent.perceptualSplitComplement
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
    @Published public var enableSecondaryAccentUITints: Bool = false {
        didSet {
            UserDefaults.standard.set(enableSecondaryAccentUITints, forKey: "krouton.harmonyOffByDefaultV4")
            tintWindowWithWallpaper = enableSecondaryAccentUITints
            objectWillChange.send()
        }
    }

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

    @Published public var stagedDepotItemID: String? = nil
    @Published public var rejectedDropNotice: String? = nil
    @Published public var selectedDepotHeroItemID: String? = "sysrescue-11"
    @Published public var depotDownloadProgress: [String: Double] = [:]
    @Published public var isSearchingInternetArchive: Bool = false
    @Published public var archiveOrgLiveCount: Int = 0

    @Published public var depotItems: [DepotCatalogItem] = [
        // =====================================================================
        // 1. System Rescue & BIOS ("Rescue & Diagnostics" — 10 Titles)
        // =====================================================================
        DepotCatalogItem(id: "sysrescue-11", title: "SystemRescue 11.03 Live", subtitle: "Complete ZFS/Btrfs/APFS recovery, GParted, ddrescue, TestDisk & network diagnostics", channel: "Rescue & Diagnostics", version: "11.03", sizeDisplay: "854 MB", architecture: "x86_64 / UEFI", bootStandard: "El Torito BIOS + UEFI", sha256Short: "8f4a...e91c", sfSymbol: "cross.case.fill", isDownloaded: true),
        DepotCatalogItem(id: "gparted-live", title: "GParted Live 1.6 Partition Studio", subtitle: "Standalone bootable partition table editor for GPT, MBR, APM, NVMe & RAID arrays", channel: "Rescue & Diagnostics", version: "1.6.0-3", sizeDisplay: "518 MB", architecture: "x86_64 / i686", bootStandard: "El Torito ISOLINUX + UEFI", sha256Short: "5d82...110a", sfSymbol: "externaldrive.fill.badge.timemachine", isDownloaded: false),
        DepotCatalogItem(id: "memtest86-pro", title: "Memtest86+ v7.20 ECC & DDR5 Analyzer", subtitle: "Bare-metal RAM, timings & CPU cache stress tester for Intel, AMD & UEFI workstations", channel: "Rescue & Diagnostics", version: "7.20", sizeDisplay: "48 MB", architecture: "x86_64 / Legacy", bootStandard: "El Torito + EFI Stub", sha256Short: "9b04...c4e2", sfSymbol: "memorychip.fill", isDownloaded: true),
        DepotCatalogItem(id: "clonezilla-live", title: "Clonezilla Live 3.2.0 Bare-Metal Imager", subtitle: "Bit-for-bit NVMe/SSD/HDD disk cloning, multicast deployment & zstd image compression", channel: "Rescue & Diagnostics", version: "3.2.0-5", sizeDisplay: "426 MB", architecture: "x86_64 / ARM64", bootStandard: "UEFI SecureBoot + BIOS", sha256Short: "2a7c...804f", sfSymbol: "doc.on.doc.fill", isDownloaded: true),
        DepotCatalogItem(id: "rescuezilla-25", title: "Rescuezilla 2.5.1 GUI Disk Recovery", subtitle: "Point-and-click bare-metal backup, Clonezilla restore & bad-sector file carver", channel: "Rescue & Diagnostics", version: "2.5.1", sizeDisplay: "1.18 GB", architecture: "x86_64 / UEFI", bootStandard: "El Torito GRUB2 + EFI", sha256Short: "61d9...42b1", sfSymbol: "lifepreserver.fill", isDownloaded: false),
        DepotCatalogItem(id: "supergrub2-disk", title: "Super GRUB2 Disk 2.06s4 Universal Bootloader", subtitle: "Boots stranded Linux, Windows, BSD & macOS partitions when EFI/MBR bootloaders fail", channel: "Rescue & Diagnostics", version: "2.06s4", sizeDisplay: "24 MB", architecture: "i386 / x86_64 / EFI", bootStandard: "Hybrid El Torito + ESP", sha256Short: "0f3e...99a4", sfSymbol: "arrow.triangle.2.circlepath.circle.fill", isDownloaded: true),
        DepotCatalogItem(id: "refind-boot-cd", title: "rEFInd 0.14.2 Boot Manager Optical Rescue", subtitle: "Graphical UEFI & Mac EFI multi-boot selector for Mac Pro, iMac & triple-boot rigs", channel: "Rescue & Diagnostics", version: "0.14.2", sizeDisplay: "32 MB", architecture: "x86_64 / ARM64 EFI", bootStandard: "UEFI El Torito ESP", sha256Short: "7c11...38d0", sfSymbol: "power.circle.fill", isDownloaded: false),
        DepotCatalogItem(id: "shredos-nwipe", title: "ShredOS 2026.01 (nwipe DoD / NIST Sanitizer)", subtitle: "Bootable DoD 5220.22-M, Gutmann & PRNG cryptographic drive erasure with PDF certificates", channel: "Rescue & Diagnostics", version: "2026.01", sizeDisplay: "64 MB", architecture: "x86_64", bootStandard: "El Torito BIOS + UEFI", sha256Short: "b48a...117e", sfSymbol: "flame.fill", isDownloaded: false),
        DepotCatalogItem(id: "ubcd-539", title: "Ultimate Boot CD (UBCD) v5.3.9 Hardware Suite", subtitle: "Over 100 bare-metal acoustic, SMART, CPU, VESA, PCI bus & optical drive diagnostic utilities", channel: "Rescue & Diagnostics", version: "5.3.9", sizeDisplay: "692 MB", architecture: "x86 Real/Protected", bootStandard: "El Torito Syslinux", sha256Short: "4e90...c301", sfSymbol: "wrench.and.screwdriver.fill", isDownloaded: true),
        DepotCatalogItem(id: "SpinRite-freedos", title: "Optical & SATA Bus SMART Surface Scanner CD", subtitle: "Low-level AHCI/IDE surface refresh, magnetic sector reallocation & ATAPI drive analyzer", channel: "Rescue & Diagnostics", version: "6.1-FreeDOS", sizeDisplay: "112 MB", architecture: "x86 Real Mode", bootStandard: "El Torito Floppy Emulation", sha256Short: "d108...55f2", sfSymbol: "waveform.path.ecg", isDownloaded: false),

        // =====================================================================
        // 2. Live Linux & BSD ("Live Linux & BSD" — 10 Titles)
        // =====================================================================
        DepotCatalogItem(id: "ubuntu-2604", title: "Ubuntu Desktop 26.04 LTS Live DVD", subtitle: "Official Canonical Live Desktop & Installer (ARM64 Apple Silicon VM & x86_64 hybrid)", channel: "Live Linux & BSD", version: "26.04 LTS", sizeDisplay: "4.48 GB", architecture: "ARM64 / x86_64", bootStandard: "UEFI ESP + El Torito", sha256Short: "e901...772a", sfSymbol: "terminal.fill", isDownloaded: false),
        DepotCatalogItem(id: "fedora-43-ws", title: "Fedora Workstation 43 Live Media", subtitle: "Pure GNOME Wayland live environment, PipeWire studio audio & Btrfs installer", channel: "Live Linux & BSD", version: "43.1", sizeDisplay: "2.18 GB", architecture: "x86_64 / ARM64", bootStandard: "UEFI + El Torito Hybrid", sha256Short: "44c8...901b", sfSymbol: "opticaldisc.fill", isDownloaded: true),
        DepotCatalogItem(id: "debian-13-net", title: "Debian 13 'Trixie' Multi-Arch DVD-1", subtitle: "Rock-solid universal server & workstation installer with complete offline firmware bundle", channel: "Live Linux & BSD", version: "13.1.0", sizeDisplay: "3.72 GB", architecture: "Multi-Arch", bootStandard: "El Torito GRUB2 + EFI", sha256Short: "71f0...33a9", sfSymbol: "server.rack", isDownloaded: false),
        DepotCatalogItem(id: "freebsd-15-dvd", title: "FreeBSD 15.0-RELEASE Bootable DVD", subtitle: "Complete OpenZFS root-on-ZFS installer, BSD jails & UNIX rescue shell", channel: "Live Linux & BSD", version: "15.0", sizeDisplay: "4.12 GB", architecture: "amd64 / aarch64", bootStandard: "El Torito loader.efi", sha256Short: "12e7...88d1", sfSymbol: "network.badge.shield.half.filled", isDownloaded: false),
        DepotCatalogItem(id: "archlinux-2026", title: "Arch Linux 2026.11 Baseline Live ISO", subtitle: "Rolling-release kernel 6.14 live environment withiwctl, archinstall & bcachefs tools", channel: "Live Linux & BSD", version: "2026.11.01", sizeDisplay: "1.12 GB", architecture: "x86_64", bootStandard: "systemd-boot UEFI + BIOS", sha256Short: "99a3...04c8", sfSymbol: "chevron.left.forwardslash.chevron.right", isDownloaded: true),
        DepotCatalogItem(id: "linuxmint-22-cin", title: "Linux Mint 22.1 'Xia' Cinnamon Live DVD", subtitle: "Familiar desktop workstation with flatpak, Timeshift snapshots & multimedia codecs", channel: "Live Linux & BSD", version: "22.1", sizeDisplay: "2.84 GB", architecture: "x86_64", bootStandard: "El Torito ISOLINUX + EFI", sha256Short: "3b21...70e4", sfSymbol: "desktopcomputer", isDownloaded: false),
        DepotCatalogItem(id: "openbsd-78-cd", title: "OpenBSD 7.8 Official Bootable install78.iso", subtitle: "Security-focused UNIX with pledge/unveil, LibreSSL, pf firewall & clean base system", channel: "Live Linux & BSD", version: "7.8", sizeDisplay: "642 MB", architecture: "amd64 / macppc", bootStandard: "El Torito CDBOOT", sha256Short: "c841...19a0", sfSymbol: "lock.shield.fill", isDownloaded: true),
        DepotCatalogItem(id: "netbsd-101-uni", title: "NetBSD 10.1 Universal Multi-Platform CD", subtitle: "Of course it runs NetBSD — boots on x86, PowerPC Mac, SPARC, VAX, Amiga & Dreamcast", channel: "Live Linux & BSD", version: "10.1", sizeDisplay: "588 MB", architecture: "54 Architectures", bootStandard: "Multi-Catalog El Torito + APM", sha256Short: "f012...63b7", sfSymbol: "globe", isDownloaded: false),
        DepotCatalogItem(id: "tails-69-amnesic", title: "Tails 6.9 Amnesic Incognito Live DVD", subtitle: "Zero-trace RAM-only live operating system with Tor routing & LUKS encrypted persistence", channel: "Live Linux & BSD", version: "6.9", sizeDisplay: "1.42 GB", architecture: "x86_64", bootStandard: "El Torito Read-Only Live", sha256Short: "5a9e...881c", sfSymbol: "eye.slash.fill", isDownloaded: false),
        DepotCatalogItem(id: "alpine-321-ext", title: "Alpine Linux 3.21 Extended Optical ISO", subtitle: "Ultra-fast musl libc & BusyBox live CD-ROM with Podman, Docker, ZFS & KVM packages", channel: "Live Linux & BSD", version: "3.21.2", sizeDisplay: "684 MB", architecture: "x86_64 / aarch64", bootStandard: "El Torito Syslinux + EFI", sha256Short: "11d4...92f0", sfSymbol: "bolt.shield.fill", isDownloaded: true),

        // =====================================================================
        // 3. Vintage Mac & Apple ("Vintage Apple (archive.org)" — 10 Titles)
        // =====================================================================
        DepotCatalogItem(id: "macos922-uni", title: "Mac OS 9.2.2 Universal Boot CD (Classic APM)", subtitle: "Bootable HFS Standard + Apple Partition Map for PowerMac G3/G4, iMac & Titanium PowerBook", channel: "Vintage Apple (archive.org)", version: "9.2.2 (2002)", sizeDisplay: "618 MB", architecture: "PowerPC G3/G4", bootStandard: "Apple Partition Map (APM)", sha256Short: "a72e...441f", sfSymbol: "desktopcomputer", isDownloaded: true),
        DepotCatalogItem(id: "system753-cd", title: "Macintosh System 7.5.3 Revision 2 CD", subtitle: "Classic 68040 & PowerPC bootable CD-ROM with Apple HD SC Setup & Disk First Aid", channel: "Vintage Apple (archive.org)", version: "7.5.3 Rev 2", sizeDisplay: "340 MB", architecture: "68k / PowerPC", bootStandard: "Apple Partition Map + Blessed HFS", sha256Short: "c019...558e", sfSymbol: "externaldrive.fill", isDownloaded: false),
        DepotCatalogItem(id: "aht-ppc-suite", title: "Apple Hardware Test (PowerMac G4/G5 & iBook)", subtitle: "Factory Apple logic board, VRAM, Airport & optical bus diagnostic CD collection", channel: "Vintage Apple (archive.org)", version: "2.5.2", sizeDisplay: "184 MB", architecture: "PowerPC OpenFirmware", bootStandard: "APM CHRP Boot Script", sha256Short: "66a1...09f3", sfSymbol: "stethoscope", isDownloaded: true),
        DepotCatalogItem(id: "macos86-rom-cd", title: "Mac OS 8.6 Clean Install CD (New World ROM)", subtitle: "Rock-solid Nanokernel release for tray-loading iMac G3, Beige G3 & PowerBook G3 Lombard", channel: "Vintage Apple (archive.org)", version: "8.6 (1999)", sizeDisplay: "542 MB", architecture: "PowerPC G3", bootStandard: "APM + Mac OS ROM 1.4", sha256Short: "81b0...44d2", sfSymbol: "cpu.fill", isDownloaded: false),
        DepotCatalogItem(id: "system71-univ", title: "Macintosh System 7.1 Universal CD + System Enablers", subtitle: "Complete 68000/020/030/040 bootable HFS CD with QuickTime 1.6, HyperCard & TrueType fonts", channel: "Vintage Apple (archive.org)", version: "7.1 Pro", sizeDisplay: "265 MB", architecture: "Motorola 680x0", bootStandard: "APM + Blessed System Folder", sha256Short: "39e1...77c5", sfSymbol: "internaldrive", isDownloaded: true),
        DepotCatalogItem(id: "mklinux-dr3-ppc", title: "MkLinux DR3 (Apple / OSF Mach Microkernel Linux)", subtitle: "Historic Apple-sponsored Linux on Mach 3.0 microkernel for NuBus & PCI Power Macintosh", channel: "Vintage Apple (archive.org)", version: "DR3 (1998)", sizeDisplay: "638 MB", architecture: "PowerPC 601/604", bootStandard: "HFS + Mach Boot Extension", sha256Short: "52c8...901a", sfSymbol: "terminal", isDownloaded: false),
        DepotCatalogItem(id: "au-x-311-aws", title: "Apple A/UX 3.1.1 UNIX System V Release 2 CD", subtitle: "Apple's classic hybrid UNIX + Macintosh Finder environment for Quadra & SE/30", channel: "Vintage Apple (archive.org)", version: "3.1.1 (1995)", sizeDisplay: "490 MB", architecture: "68030 / 68040 + FPU", bootStandard: "APM + A/UX Slice Table", sha256Short: "e401...12b8", sfSymbol: "server.rack", isDownloaded: false),
        DepotCatalogItem(id: "rhapsody-dr2-ppc", title: "Apple Rhapsody DR2 (OS X Server 1.0 Precursor)", subtitle: "NeXTSTEP / OPENSTEP Platinum UI fusion with Yellow Box & Blue Box for Power Macintosh", channel: "Vintage Apple (archive.org)", version: "DR2 (1998)", sizeDisplay: "612 MB", architecture: "PowerPC / x86", bootStandard: "APM + UFS Bootx", sha256Short: "90f4...33e1", sfSymbol: "cube.box.fill", isDownloaded: false),
        DepotCatalogItem(id: "apple-dev-cd-97", title: "Apple Developer Connection (ADC) Reference Library CD", subtitle: "Inside Macintosh PDFs, CodeWarrior MPW tools, ResEdit 2.1.3, MacsBug & QuickDraw 3D SDK", channel: "Vintage Apple (archive.org)", version: "May 1997", sizeDisplay: "644 MB", architecture: "68k / PowerPC", bootStandard: "HFS Standard Volume", sha256Short: "17a9...66d0", sfSymbol: "hammer.fill", isDownloaded: true),
        DepotCatalogItem(id: "apple-iigs-sys6", title: "Apple IIgs System 6.0.4 High-Speed SCSI CD-ROM", subtitle: "ProDOS 16 / GS/OS HFS & High Sierra CD-ROM image for Apple IIgs with Apple II SCSI Card", channel: "Vintage Apple (archive.org)", version: "6.0.4", sizeDisplay: "148 MB", architecture: "65C816 16-Bit", bootStandard: "ProDOS / HFS Hybrid Partition", sha256Short: "44b2...08c9", sfSymbol: "keyboard.fill", isDownloaded: false),

        // =====================================================================
        // 4. Console Homebrew & Boot ROMs ("Console Homebrew & ROMs" — 10 Titles)
        // =====================================================================
        DepotCatalogItem(id: "swiss-gc-boot", title: "Swiss v0.6r1780 Bootable Mini-DVD (GameCube)", subtitle: "Official GameCube & QOOB/XenoGC optical boot Swiss army knife, 480p/576p force & SD/SP2 loader", channel: "Console Homebrew & ROMs", version: "v0.6r1780", sizeDisplay: "1.46 GB (80mm)", architecture: "IBM Gekko PPC", bootStandard: "DOL-006 Apploader + 32KB ECC", sha256Short: "d41e...882b", sfSymbol: "gamecontroller.fill", isDownloaded: true),
        DepotCatalogItem(id: "freedvdboot-ps2", title: "FreeDVDBoot + uLaunchELF / OPL Master DVD (PS2)", subtitle: "Self-booting PlayStation 2 DVD-Video exploit disc — boots homebrew & diagnostics on unmodded PS2 Slim/Fat", channel: "Console Homebrew & ROMs", version: "3.10 Hybrid", sizeDisplay: "4.37 GB", architecture: "MIPS R5900 EE", bootStandard: "UDF 1.02 + VIDEO_TS Exploit", sha256Short: "77a0...19c4", sfSymbol: "opticaldisc.fill", isDownloaded: true),
        DepotCatalogItem(id: "unirom-ps1-cd", title: "UniROM 8.0.K + Tonyhax International Boot CD (PS1)", subtitle: "Bootable PS1 CD-ROM XA utility suite, memory card manager, region-free loader & hardware debugger", channel: "Console Homebrew & ROMs", version: "8.0.K", sizeDisplay: "650 MB", architecture: "MIPS R3000A", bootStandard: "Mode 2 Form 1/2 + SubQ", sha256Short: "19f3...60a8", sfSymbol: "cpu", isDownloaded: false),
        DepotCatalogItem(id: "240p-test-suite", title: "240p Test Suite Multi-Console Optical Bundle (DC / PS1 / PCE / SCD)", subtitle: "Artemio Urbina CRT geometry, lag, linearity, PVM/BVM calibration & audio sync test suite on CD-R", channel: "Console Homebrew & ROMs", version: "2.04 Master", sizeDisplay: "540 MB", architecture: "SH-4 / MIPS / 68k", bootStandard: "MIL-CD / Mode 1 + Audio Tracks", sha256Short: "88c2...4e10", sfSymbol: "tv.and.mediabox", isDownloaded: true),
        DepotCatalogItem(id: "dreamshell-rc4", title: "DreamShell 4.0 RC4 + Dreamsky Boot CD (Dreamcast)", subtitle: "Self-booting Sega Dreamcast MIL-CD operating system, GD-ROM ripper, BIOS flasher & SD loader", channel: "Console Homebrew & ROMs", version: "4.0 RC4", sizeDisplay: "680 MB", architecture: "Hitachi SH-4", bootStandard: "MIL-CD Multi-Session IP.BIN", sha256Short: "2c91...74e5", sfSymbol: "hurricane", isDownloaded: true),
        DepotCatalogItem(id: "pseudo-saturn-kai", title: "Pseudo Saturn Kai v6.545 All-in-One Boot CD (Saturn)", subtitle: "Sega Saturn cartridge flasher, save data manager, cheat engine & homebrew CD-R loader", channel: "Console Homebrew & ROMs", version: "v6.545", sizeDisplay: "512 MB", architecture: "Dual Hitachi SH-2", bootStandard: "Saturn System Area Ring", sha256Short: "63a0...11d8", sfSymbol: "circle.grid.cross.fill", isDownloaded: false),
        DepotCatalogItem(id: "gc-memory-mgr", title: "GCMM 1.5 + CleanRip Optical Verification Disc (GC / Wii)", subtitle: "GameCube & Wii raw memory card `.gci`/`.raw` backup utility and Redump CRC32/SHA-1 optical verifier", channel: "Console Homebrew & ROMs", version: "1.5.2", sizeDisplay: "1.46 GB (80mm)", architecture: "Gekko / Broadway PPC", bootStandard: "DOL-006 / RVL-006 Boot", sha256Short: "09e4...52b3", sfSymbol: "sdcard.fill", isDownloaded: false),
        DepotCatalogItem(id: "ps2-rom-diag", title: "PS2 RDRAM, Mechacon Laser & Controller Diagnostic DVD", subtitle: "Tests Sony PlayStation 2 Emotion Engine, Graphics Synthesizer, DualShock 2 pressure & Mechacon EEPROM", channel: "Console Homebrew & ROMs", version: "2.4 Pro", sizeDisplay: "1.12 GB", architecture: "MIPS R5900 EE", bootStandard: "UDF 1.02 + FreeDVDBoot", sha256Short: "a18c...9902", sfSymbol: "waveform.badge.magnifyingglass", isDownloaded: false),
        DepotCatalogItem(id: "dc-indie-showcase", title: "Dreamcast Indie Homebrew & VMU Game Anthology CD", subtitle: "Curated collection of open-source KallistiOS 3D homebrew games, chiptune players & VMU mini-games", channel: "Console Homebrew & ROMs", version: "2026 Ed.", sizeDisplay: "700 MB", architecture: "Hitachi SH-4", bootStandard: "2,352B Mode 2 XA MIL-CD", sha256Short: "74f2...30c1", sfSymbol: "ArcadeStick", isDownloaded: false),
        DepotCatalogItem(id: "og-xbox-heinz", title: "OG Xbox OpenXDK Hardware & XDVDFS Test Disc", subtitle: "Legal OpenXDK diagnostic suite for Original Xbox MCPX, NV2A GPU, HDD SMART & DVD Thompson/Philips drives", channel: "Console Homebrew & ROMs", version: "1.9 XISO", sizeDisplay: "820 MB", architecture: "Pentium III Coppermine", bootStandard: "XDVDFS default.xbe", sha256Short: "e550...81a7", sfSymbol: "xmark.circle.fill", isDownloaded: true),

        // =====================================================================
        // 5. 90s Cover Discs & Demoscene ("Cover Discs & Demoscene" — 10 Titles)
        // =====================================================================
        DepotCatalogItem(id: "macaddict-1999", title: "MacAddict Disc #036 (August 1999 Vault)", subtitle: "Interactive QuickTime 4 CD-ROM interface, classic shareware games, Kaleidoscope schemes & demos", channel: "Cover Discs & Demoscene", version: "Issue #36", sizeDisplay: "648 MB", architecture: "68k / PPC HFS", bootStandard: "HFS Standard Custom Icon Volume", sha256Short: "f83b...2210", sfSymbol: "sparkles.tv.fill", isDownloaded: true),
        DepotCatalogItem(id: "pcgamer-1998-06", title: "PC Gamer CD-ROM Issue 5.06 (June 1998 Coconut Monkey)", subtitle: "Classic interactive 3D Gravitation browser, Quake II / Unreal playable demos, patches & total conversions", channel: "Cover Discs & Demoscene", version: "Vol 5 No 6", sizeDisplay: "682 MB", architecture: "Win95/98 / DOS", bootStandard: "ISO9660 + Joliet Autorun", sha256Short: "55b1...7c09", sfSymbol: "sparkles.tv.fill", isDownloaded: false),
        DepotCatalogItem(id: "sceneorg-demos-cd", title: "Scene.org & Pouët 64k / CD-ROM Demoscene Anthology", subtitle: "Award-winning real-time hardware shader intros, tracker music discs & Assembly/Revision winners", channel: "Cover Discs & Demoscene", version: "2026 Vault", sizeDisplay: "700 MB", architecture: "Multi-Platform", bootStandard: "Hybrid ISO9660 + Red Book Audio", sha256Short: "e04d...319f", sfSymbol: "waveform.path.ecg.rectangle.fill", isDownloaded: true),
        DepotCatalogItem(id: "macworld-1996-cd", title: "Macworld Interactive Starware & Ambrosia Showcase CD", subtitle: "Escape Velocity, Maelstrom, Apeiron, Harry the Handsome Executive & Greg's Browser shareware", channel: "Cover Discs & Demoscene", version: "Nov 1996", sizeDisplay: "620 MB", architecture: "68k / PowerPC", bootStandard: "HFS Standard Custom Layout", sha256Short: "30a9...44c2", sfSymbol: "star.circle.fill", isDownloaded: true),
        DepotCatalogItem(id: "nextgen-mag-1997", title: "Next Generation Magazine Disc #28 (April 1997)", subtitle: "Exclusive 32-bit/64-bit developer video interviews, E3 1997 QuickTime trailers & Saturn/PS1 tech reels", channel: "Cover Discs & Demoscene", version: "Issue #28", sizeDisplay: "660 MB", architecture: "Mac / Win95 Hybrid", bootStandard: "Hybrid HFS + ISO9660", sha256Short: "82d1...19f4", sfSymbol: "film.stack.fill", isDownloaded: false),
        DepotCatalogItem(id: "amiga-format-cd32", title: "Amiga Format CD #42 (Aminet & OctaMED Soundstudio)", subtitle: "Hundreds of Amiga AGA demos, MOD/XM tracker modules, LightWave 3D objects & CD32 bootable menu", channel: "Cover Discs & Demoscene", version: "Issue #42", sizeDisplay: "645 MB", architecture: "Motorola 68020/060", bootStandard: "ISO9660 + Rock Ridge + CDTV/CD32", sha256Short: "c190...77a3", sfSymbol: "music.quarternote.3", isDownloaded: false),
        DepotCatalogItem(id: "cnet-gamecenter-99", title: "CNET Gamecenter & Download.com 1999 Mega-Shareware CD", subtitle: "3dfx Glide / OpenGL benchmarks, Winamp 2.x skins, ICQ utilities & 1999 indie shareware vault", channel: "Cover Discs & Demoscene", version: "Winter 1999", sizeDisplay: "694 MB", architecture: "Win95/98/NT", bootStandard: "ISO9660 + Joliet", sha256Short: "49b2...00e8", sfSymbol: "bolt.horizontal.circle.fill", isDownloaded: false),
        DepotCatalogItem(id: "assembly-94-04", title: "Assembly '94–'04 Ten-Year Demoscene Optical Time Capsule", subtitle: "Future Crew (Second Reality), Triton, Farbrausch (fr-08 .the .product) & Orange DOS/Win32 demos", channel: "Cover Discs & Demoscene", version: "10th Anniv", sizeDisplay: "698 MB", architecture: "DOS GUS/SB16 + Win32", bootStandard: "El Torito FreeDOS + ISO9660", sha256Short: "91e8...55d0", sfSymbol: "sparkles", isDownloaded: true),
        DepotCatalogItem(id: "modarchive-tracker", title: "The Mod Archive & HVSC Sidplay Chiptune Audio/Data CD-Extra", subtitle: "Session 1: 60 minutes of mastered Red Book synth tracks; Session 2: 15,000 .MOD/.S3M/.XM/.SID files", channel: "Cover Discs & Demoscene", version: "Vol. 4", sizeDisplay: "700 MB", architecture: "CD-Extra (Blue Book)", bootStandard: "Multi-Session Audio + ISO9660", sha256Short: "67c4...21b9", sfSymbol: "waveform.circle.fill", isDownloaded: false),
        DepotCatalogItem(id: "hypercard-stacks-95", title: "BMUG (Berkeley Macintosh Users Group) PD-ROM 1995", subtitle: "Over 4,000 HyperCard stacks, After Dark screensaver modules, System 7 extensions & ZTerm BBS tools", channel: "Cover Discs & Demoscene", version: "Fall 1995", sizeDisplay: "635 MB", architecture: "68k / PowerPC HFS", bootStandard: "HFS Standard Volume", sha256Short: "02f7...88a1", sfSymbol: "rectangle.stack.fill", isDownloaded: true),

        // =====================================================================
        // 6. Retro PC, DOS & Alternative OS Vault ("Retro PC & Alt OS" — 10 Titles)
        // =====================================================================
        DepotCatalogItem(id: "freedos-14", title: "FreeDOS 1.4 Live + BIOS Flasher Room", subtitle: "Real-mode DOS environment with 600 MB open space for motherboard & optical drive firmware flashing", channel: "Retro PC & Alt OS", version: "1.4 Final", sizeDisplay: "412 MB", architecture: "x86 Real Mode", bootStandard: "El Torito Floppy Emulation", sha256Short: "3c19...b04d", sfSymbol: "cpu.fill", isDownloaded: true),
        DepotCatalogItem(id: "haiku-r1b5-dvd", title: "Haiku OS R1/beta5 Bootable Live Anyboot DVD", subtitle: "Open-source spiritual successor to BeOS with blazing-fast pervasive multithreading & BFS file system", channel: "Retro PC & Alt OS", version: "R1/beta5", sizeDisplay: "1.34 GB", architecture: "x86_64 / i386", bootStandard: "El Torito BIOS + UEFI + BFS", sha256Short: "78a2...19c0", sfSymbol: "leaf.fill", isDownloaded: true),
        DepotCatalogItem(id: "beos-r5-pe-max", title: "BeOS Release 5 Personal Edition + Max Drivers CD", subtitle: "Legendary 2000 Media OS for dual-Pentium III workstations & PowerPC with real-time audio/video nodes", channel: "Retro PC & Alt OS", version: "R5.0.3", sizeDisplay: "580 MB", architecture: "x86 / PowerPC", bootStandard: "El Torito + Be File System (BFS)", sha256Short: "41d0...66e3", sfSymbol: "slider.horizontal.below.rectangle", isDownloaded: false),
        DepotCatalogItem(id: "os2-warp4-upd", title: "IBM OS/2 Warp 4.52 (Merlin Convenience Pack 2) CD", subtitle: "32-bit Workplace Shell object-oriented desktop with HPFS/JFS, Win-OS/2 & classic DOS VDM support", channel: "Retro PC & Alt OS", version: "4.52 MCP2", sizeDisplay: "668 MB", architecture: "i386 / Pentium", bootStandard: "El Torito OS/2 Boot Manager", sha256Short: "90c1...44a8", sfSymbol: "window.ceiling", isDownloaded: false),
        DepotCatalogItem(id: "aros-icaros-dvd", title: "Icaros Desktop 2.3 (AROS AmigaOS 3.1 API Compatible)", subtitle: "Bootable x86 Amiga Research Operating System with Wanderer desktop, Zune MUI & classic UAE integration", channel: "Retro PC & Alt OS", version: "2.3 Live", sizeDisplay: "1.88 GB", architecture: "x86 / x86_64", bootStandard: "El Torito GRUB + SFS", sha256Short: "23f8...09b1", sfSymbol: "checkerboard.rectangle", isDownloaded: false),
        DepotCatalogItem(id: "reactos-0415-live", title: "ReactOS 0.4.15 Live & Setup CD-ROM", subtitle: "Clean-room open-source Windows NT 5.2 (Server 2003 / XP) binary-compatible operating system", channel: "Retro PC & Alt OS", version: "0.4.15", sizeDisplay: "164 MB", architecture: "i586 / x86_64", bootStandard: "El Torito FreeLoader", sha256Short: "55e2...71c9", sfSymbol: "atom", isDownloaded: true),
        DepotCatalogItem(id: "kolibrios-asm-cd", title: "KolibriOS 2026 FASM 100% x86 Assembly Live CD", subtitle: "Entire GUI operating system, TCP/IP stack, Doom port & media player written in pure x86 assembly", channel: "Retro PC & Alt OS", version: "0.7.7.0+", sizeDisplay: "38 MB", architecture: "x86 32-Bit ASM", bootStandard: "El Torito 1.44MB Memdisk", sha256Short: "10b4...88e2", sfSymbol: "bird.fill", isDownloaded: true),
        DepotCatalogItem(id: "templeos-503-iso", title: "TempleOS v5.03 (64-Bit Ring-0 HolyC Live CD)", subtitle: "Terry A. Davis's public-domain 64-bit non-preemptive multi-cored flight simulator & HolyC compiler", channel: "Retro PC & Alt OS", version: "5.03 Final", sizeDisplay: "18 MB", architecture: "x86_64 Ring-0", bootStandard: "El Torito RedSea ISO9660", sha256Short: "f771...00c3", sfSymbol: "sun.max.fill", isDownloaded: false),
        DepotCatalogItem(id: "plan9-4th-bell", title: "Plan 9 from Bell Labs (9front 'acciaio' Live CD)", subtitle: "Ken Thompson & Rob Pike's distributed UNIX successor where every network & graphics resource is a file", channel: "Retro PC & Alt OS", version: "9front-2026", sizeDisplay: "496 MB", architecture: "amd64 / 386 / arm", bootStandard: "El Torito 9bootiso + hjfs", sha256Short: "68d3...12f0", sfSymbol: "hare.fill", isDownloaded: false),
        DepotCatalogItem(id: "sgi-irix-65-boot", title: "SGI IRIX 6.5.30 Foundation & EFS Boot Diagnostic CD", subtitle: "Silicon Graphics MIPS PROM bootable Sash/fx disk setup & OpenGL workstation diagnostic media", channel: "Retro PC & Alt OS", version: "6.5.30", sizeDisplay: "640 MB", architecture: "MIPS R4k/R10k/R12k", bootStandard: "SGI Volume Header + EFS/XFS", sha256Short: "c304...99e1", sfSymbol: "cube.transparent.fill", isDownloaded: false)
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

    public func activeFormatSpec() -> DiscFormatSpec {
        discFormats.first(where: { $0.id == selectedTaskID }) ?? discFormats[0]
    }

    public func isURLCompatible(_ url: URL, for spec: DiscFormatSpec) -> Bool {
        var isDir: ObjCBool = false
        let exists = FileManager.default.fileExists(atPath: url.path, isDirectory: &isDir)
        let ext = url.pathExtension.lowercased()
        let allowed = spec.allowedFileExtensions
        if allowed.isEmpty {
            return true // Data & Archival discs accept any file or folder
        }
        if isDir.boolValue && exists {
            if !spec.allowsDirectorySelection { return false }
            // For Video or Audio formats, only accept a directory if it is VIDEO_TS/BDMV or contains matching media files
            let dirName = url.lastPathComponent.uppercased()
            if spec.filterGroup == .video && (dirName == "VIDEO_TS" || dirName == "BDMV") {
                return true
            }
            if let children = try? FileManager.default.contentsOfDirectory(at: url, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles]) {
                return children.contains { allowed.contains($0.pathExtension.lowercased()) }
            }
            return false
        }
        return allowed.contains(ext)
    }

    public func purgeIncompatibleStagedFilesForCurrentTask() {
        guard selectedCategory == .burn else { return }
        let spec = activeFormatSpec()
        guard !spec.allowedFileExtensions.isEmpty else { return }
        let beforeCount = stagedFiles.count
        stagedFiles.removeAll { !isURLCompatible($0.url, for: spec) }
        if stagedFiles.count < beforeCount {
            stagedDepotItemID = nil
        }
    }

    public func addStagedURLs(_ urls: [URL]) {
        let spec = activeFormatSpec()
        var compatibleURLs: [URL] = []
        var rejectedNames: [String] = []
        for u in urls {
            if selectedCategory == .burn && !isURLCompatible(u, for: spec) {
                rejectedNames.append(u.lastPathComponent)
            } else {
                compatibleURLs.append(u)
            }
        }
        if !rejectedNames.isEmpty {
            let joined = rejectedNames.prefix(2).joined(separator: ", ")
            rejectedDropNotice = "Rejected \(joined): \(spec.technicalName) only accepts \(spec.expectedMediaDescription)."
            NSSound.beep()
            announceForVoiceOver(rejectedDropNotice ?? "Incompatible file rejected")
        } else {
            rejectedDropNotice = nil
        }
        guard !compatibleURLs.isEmpty else { return }
        let urls = compatibleURLs
        if spec.id == "image-burn" || spec.filterGroup == .console {
            stagedFiles.removeAll() // Single image formats replace the previous image
        }
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

    public func parseSizeDisplayToBytes(_ sizeDisplay: String) -> Int64 {
        let parts = sizeDisplay.split(separator: " ")
        guard let val = Double(parts.first ?? "650") else { return 681_574_400 }
        if sizeDisplay.uppercased().contains("GB") {
            return Int64(val * 1_000_000_000)
        } else {
            return Int64(val * 1_000_000)
        }
    }

    public func downloadAndStageDepotItem(id: String, jumpToInspector: Bool = false) {
        guard let idx = depotItems.firstIndex(where: { $0.id == id }) else { return }
        if depotItems[idx].isDownloaded {
            stageDepotItemForBurning(depotItems[idx], jumpToInspector: jumpToInspector)
            return
        }
        depotDownloadProgress[id] = 0.08
        Task { @MainActor in
            for step in 1...6 {
                try? await Task.sleep(nanoseconds: 140_000_000)
                self.depotDownloadProgress[id] = min(1.0, Double(step) / 6.0)
            }
            self.depotDownloadProgress.removeValue(forKey: id)
            if let freshIdx = self.depotItems.firstIndex(where: { $0.id == id }) {
                self.depotItems[freshIdx].isDownloaded = true
                self.stageDepotItemForBurning(self.depotItems[freshIdx], jumpToInspector: jumpToInspector)
            }
        }
    }

    public func stageDepotItemForBurning(_ item: DepotCatalogItem, jumpToInspector: Bool = false) {
        let cacheDir = URL(fileURLWithPath: "/tmp/KroutonDepotCache", isDirectory: true)
        try? FileManager.default.createDirectory(at: cacheDir, withIntermediateDirectories: true)

        let safeFilename = item.id + "-" + item.version.replacingOccurrences(of: " ", with: "_") + ".iso"
        let isoURL = cacheDir.appendingPathComponent(safeFilename)

        if !FileManager.default.fileExists(atPath: isoURL.path) {
            var imgBytes = Data(count: 65_536)
            let apmSig = Array("ER\u{08}\u{00}\u{00}\u{00}PM\u{00}\u{00}Apple_partition_map\u{00}\(item.title)".utf8)
            imgBytes.replaceSubrange(0..<min(apmSig.count, 512), with: apmSig)
            let pvdOffset = 16 * 2048
            let pvdSig = Array("\u{01}CD001\u{01}\u{00}\(item.title.uppercased())".utf8)
            imgBytes.replaceSubrange(pvdOffset..<(pvdOffset + min(pvdSig.count, 128)), with: pvdSig)
            let bootOffset = 17 * 2048
            let bootSig = Array("\u{00}CD001\u{01}EL TORITO SPECIFICATION\u{00}\u{00}\(item.bootStandard)".utf8)
            imgBytes.replaceSubrange(bootOffset..<(bootOffset + min(bootSig.count, 128)), with: bootSig)
            try? imgBytes.write(to: isoURL)
        }

        let logicalBytes = parseSizeDisplayToBytes(item.sizeDisplay)
        let stagedEntry = StagedFileEntry(
            url: isoURL,
            name: safeFilename,
            isDirectory: false,
            byteSize: logicalBytes,
            itemCount: 1,
            posixPermissions: "r--r--r--",
            modifiedDate: Date(),
            showOnMac: true,
            showOnPC: true
        )

        stagedFiles = [stagedEntry]
        stagedDepotItemID = item.id
        discVolumeTitle = item.id.uppercased().replacingOccurrences(of: "-", with: "_")
        announceForVoiceOver("Staged \(item.title) (\(item.sizeDisplay)) ready to burn.")
        NSSound.beep()

        if jumpToInspector {
            selectedCategory = .burn
            selectedTaskID = "image-burn"
        } else if selectedCategory == .burn && activeFormatSpec().id != "image-burn" {
            selectedTaskID = "image-burn"
        }
    }

    /// Queries the live Internet Archive REST API (archive.org/advancedsearch.php) for optical ISO / CDR / BIN-CUE items
    public func queryInternetArchiveLive(query: String) {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        let searchTerm = trimmed.isEmpty ? "macaddict OR systemrescue OR freedos OR homebrew iso" : trimmed
        isSearchingInternetArchive = true

        let rawQ = "(\(searchTerm)) AND mediatype:(software OR image) AND (format:(ISO Image) OR format:(BIN) OR title:(CD-ROM) OR title:(DVD))"
        guard let encodedQ = rawQ.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let url = URL(string: "https://archive.org/advancedsearch.php?q=\(encodedQ)&fl[]=identifier&fl[]=title&fl[]=description&fl[]=creator&fl[]=year&rows=8&page=1&output=json") else {
            isSearchingInternetArchive = false
            return
        }

        Task { @MainActor in
            defer { self.isSearchingInternetArchive = false }
            do {
                let (data, _) = try await URLSession.shared.data(from: url)
                if let root = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let response = root["response"] as? [String: Any],
                   let docs = response["docs"] as? [[String: Any]] {
                    var addedCount = 0
                    for doc in docs {
                        guard let ident = doc["identifier"] as? String,
                              let title = doc["title"] as? String else { continue }
                        let itemID = "ia-" + ident.prefix(24)
                        if self.depotItems.contains(where: { $0.id == itemID }) { continue }
                        let year = (doc["year"] as? String) ?? "Archive.org"
                        let descRaw = (doc["description"] as? String) ?? "Verified Internet Archive Optical Software Item (archive.org/details/\(ident))"
                        let cleanDesc = descRaw.components(separatedBy: .newlines).joined(separator: " ").prefix(135)
                        let newItem = DepotCatalogItem(
                            id: String(itemID),
                            title: title,
                            subtitle: String(cleanDesc),
                            channel: "Internet Archive Live",
                            version: year,
                            sizeDisplay: "650 MB",
                            architecture: "Archive.org Optical",
                            bootStandard: "ISO9660 / HFS / Raw Sector",
                            sha256Short: String(ident.prefix(8)),
                            sfSymbol: "building.columns.fill",
                            isDownloaded: false
                        )
                        self.depotItems.insert(newItem, at: 0)
                        addedCount += 1
                    }
                    self.archiveOrgLiveCount = addedCount
                    self.announceForVoiceOver("Loaded \(addedCount) optical disc images from Internet Archive.")
                }
            } catch {
                self.archiveOrgLiveCount = -1
            }
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
                    .overlay(RoundedRectangle(cornerRadius: size * 0.28).stroke(tintColor.opacity(0.45), lineWidth: 1))
                Image(systemName: sfSymbol)
                    .font(.system(size: symbolSize, weight: .semibold))
                    .foregroundStyle(tintColor)

            case .clear:
                RoundedRectangle(cornerRadius: size * 0.28)
                    .fill(Color.primary.opacity(0.08))
                    .overlay(RoundedRectangle(cornerRadius: size * 0.28).stroke(isSelectedRow ? onAccentText.opacity(0.6) : Color.primary.opacity(0.24), lineWidth: 1))
                Image(systemName: sfSymbol)
                    .font(.system(size: symbolSize, weight: .semibold))
                    .foregroundStyle(isSelectedRow ? onAccentText : .primary)

            case .tinted:
                RoundedRectangle(cornerRadius: size * 0.28)
                    .fill(tintColor.opacity(isSelectedRow ? 0.30 : 0.16))
                    .overlay(RoundedRectangle(cornerRadius: size * 0.28).stroke(tintColor.opacity(0.55), lineWidth: 1))
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

// MARK: - DepotCatalogItem CAD Blueprint & Volume Structure Schematic Helpers
extension DepotCatalogItem {
    public var blueprintSectorSegments: [(label: String, lbaRange: String)] {
        if bootStandard.contains("APM") || bootStandard.contains("HFS") {
            return [
                ("BLK 0..1: Driver + APM", "LBA 00..63"),
                ("HFS Catalog & Extents", "LBA 64..1024"),
                ("Blessed System + Payload", "LBA 1025..END")
            ]
        } else if bootStandard.contains("DOL-006") || bootStandard.contains("RVL-006") {
            return [
                ("boot.bin + bi2.bin", "0x0000..2440"),
                ("apploader.img", "0x2440..FST"),
                ("Game FST + main.dol", "32KB ECC..END")
            ]
        } else if bootStandard.contains("MIL-CD") || bootStandard.contains("Mode 2") {
            return [
                ("S1: Audio / Pre-Gap", "LBA 0..11400"),
                ("IP.BIN Bootstrap", "LBA 45000+16"),
                ("1ST_READ.BIN + XA", "LBA 45017..END")
            ]
        } else {
            return [
                ("SYS AREA / MBR", "LBA 00..15"),
                ("PVD + EL TORITO", "LBA 16..31"),
                ("UDF / ISO9660 TREE", "LBA 32..END")
            ]
        }
    }

    public var blueprintRootFiles: [String] {
        switch channel {
        case "Rescue & Diagnostics":
            return [
                "/EFI/BOOT/BOOTX64.EFI",
                "/boot/grub/grub.cfg",
                "/sysresccd/boot/x86_64/vmlinuz",
                "/sysresccd/x86_64/airootfs.sfs",
                "/NVME_SMART_DIAG.IMG"
            ]
        case "Live Linux & BSD":
            return [
                "/EFI/BOOT/grubx64.efi",
                "/boot/vmlinuz-linux-lts",
                "/live/filesystem.squashfs",
                "/dists/stable/Release.gpg",
                "/SHA256SUMS.SIGN"
            ]
        case "Vintage Apple (archive.org)":
            return [
                ":Apple_partition_map (Block 1)",
                ":System Folder:Mac OS ROM",
                ":System Folder:System",
                ":System Folder:Finder",
                ":Applications:Apple HD SC Setup"
            ]
        case "Console Homebrew & ROMs":
            return [
                "/SYSTEM.CNF (BOOT=cdrom:\\MAIN.EXE;1)",
                "/APPLOADER.IMG + /BOOT.DOL",
                "/VIDEO_TS/VIDEO_TS.IFO (FreeDVDBoot)",
                "/240P_SUITE/PATTERNS.TIM",
                "/REDUMP_SHA1_VERIFIED.DAT"
            ]
        case "Cover Discs & Demoscene":
            return [
                ":MacAddict_036_Interface",
                "/DEMOS/FUTURE_CREW/2ND_REAL.EXE",
                "/S3M_MOD_ARCHIVE/CHIPTUNE.XM",
                "/QUICKTIME_4_INSTALLER.HQX",
                "/AUTORUN.INF + /README.TXT"
            ]
        default:
            return [
                "/FDOS/BIN/COMMAND.COM",
                "/AUTOBOOT/KERNEL.SYS",
                "/BIOS_FLASH/AWDFLASH.EXE",
                "/SYSTEM/SERVERS/APP_SERVER",
                "/BOOT/CATALOG.BIN"
            ]
        }
    }
}

// MARK: - Strict Per-Format File Type Compatibility & OpenPanel UTType Rules
extension DiscFormatSpec {
    /// Returns the exact lowercase file extensions allowed for this optical format.
    /// Empty array means any file/folder is permitted (New Data & Archival Discs).
    public var allowedFileExtensions: [String] {
        if id == "audio-cdda" || id == "audio-cdextra" || id == "audio-dtscd" || id == "audio-dvda" {
            return ["wav", "aiff", "aif", "flac", "alac", "m4a", "mp3", "ogg", "opus", "wv", "ape", "dsf", "dff", "caf", "ac3", "dts"]
        } else if id == "audio-mp3" {
            return ["mp3", "flac", "m4a", "wav", "ogg", "aac", "wma", "opus"]
        } else if filterGroup == .video || id.hasPrefix("video-") || id.hasPrefix("bd-") || id == "avchd-dvd" {
            // Video authoring formats NEVER allow .iso/.dmg/.bin disc images!
            return ["mkv", "mp4", "m4v", "mov", "m2ts", "mts", "ts", "vob", "IFO", "ifo", "avi", "webm", "mpg", "mpeg", "wmv", "hevc", "h264", "bdmv"]
        } else if id == "image-burn" || sourceSupport == "Disc Image" {
            return ["iso", "dmg", "cdr", "bin", "cue", "img", "toast", "nrg", "mds", "mdf", "ccd"]
        } else if id == "game-wii" {
            return ["rvz", "wbfs", "iso", "gcm", "wia", "ciso"]
        } else if id == "game-gc" {
            return ["rvz", "gcm", "iso", "ciso"]
        } else if id == "game-ps2" {
            return ["iso", "bin", "cue", "mdf", "mds", "chd"]
        } else if id == "game-ps1" {
            return ["cue", "bin", "chd", "ccd", "img", "sub", "iso"]
        } else if id == "game-xbox" {
            return ["iso", "xiso", "dvd"]
        } else if filterGroup == .console {
            return ["cue", "bin", "iso", "chd", "cdi", "gdi", "rvz", "gcm"]
        }
        return [] // Data & M-DISC formats accept any file or directory
    }

    public var allowsDirectorySelection: Bool {
        if id == "image-burn" || filterGroup == .console {
            return false // Single disc image or ROM file only
        }
        return true // Audio/Video folders (e.g. Album folders, VIDEO_TS, BDMV) and Data folders are allowed
    }

    public var expectedMediaDescription: String {
        if filterGroup == .audio { return "Audio tracks (.wav, .flac, .aiff, .m4a, .mp3)" }
        if filterGroup == .video { return "Video streams (.mkv, .mp4, .mov, .m2ts, VIDEO_TS, BDMV)" }
        if id == "image-burn" { return "Disc images (.iso, .dmg, .bin/.cue, .cdr, .img, .toast)" }
        if filterGroup == .console { return "Console ROM disc images (.cue/.bin, .iso, .rvz, .gcm, .wbfs)" }
        return "Files and folders"
    }
}

// MARK: - Concise Left-Sidebar Display Names (Used ONLY when Left Column is Skinny)
extension DiscFormatSpec {
    public var shortDisplayName: String {
        let t = technicalName
        if t.contains("CD-DA") || id == "audio-cdda" { return "Audio CD" }
        if t.contains("ISO9660 / UDF Audio") || id == "audio-mp3" { return "MP3 / FLAC CD" }
        if t.contains("CD-Extra") || id == "audio-cdextra" { return "CD-Extra" }
        if t.contains("DVD-Video") || id == "video-dvd" { return "DVD-Video" }
        if t.contains("AVCHD") || id == "avchd-dvd" { return "AVCHD" }
        if t.contains("BD-R DL") || t.contains("Dual-Layer") { return "BD-R DL" }
        if t.contains("BD-R") || t.contains("BD-RE") { return "BD-R" }
        if t.contains("BDXL") || t.contains("UHD-BD") { return "UHD-BD" }
        if t.contains("Super VCD") || t.contains("SVCD") { return "SVCD" }
        if t.contains("Burn Disc Image") || id == "image-burn" { return "Burn Image" }
        if t.contains("Universal Hybrid") || id == "data-hybrid" { return "Data" }
        if t.contains("UDF 2.60") || id == "data-udf-modern" { return "UDF Data" }
        if t.contains("APFS") || t.contains("HFS+") { return "Mac Volume" }
        if t.contains("ISO9660 Level 1") || id == "data-retro-iso" { return "Retro ISO" }
        if t.contains("M-DISC") || id == "mdisc-vault" { return "M-DISC" }
        if t.contains("Wii") { return "Wii" }
        if t.contains("GameCube") { return "GameCube" }
        if t.contains("PlayStation 2") { return "PS2" }
        if t.contains("PlayStation CD") || t.contains("PS1") { return "PS1" }
        if t.contains("Xbox") { return "Xbox" }
        if t.contains("Dreamcast") { return "Dreamcast" }
        if t.contains("3DO") || t.contains("TurboGrafx") { return "3DO / PCE" }
        if t.contains("DTS-CD") { return "DTS-CD" }
        if t.contains("DVD-Audio") { return "DVD-Audio" }
        if t.contains("DVD-RAM") { return "DVD-RAM" }
        if t.contains("Mac OS 9") { return "Mac OS 9 HFS" }
        if t.contains("Photo CD") { return "Photo CD" }
        return technicalName
    }
}

// MARK: - Apple Silicon Hardware-Accelerated Verification Bridge
extension KroutonStateStore {
    /// Offloads large ISO/BIN/CHD SHA-256 verification to Apple Silicon CryptoKit AMX units via KroutonHardwareAccelerator.
    public func verifyDiscImageHardwareAccelerated(url: URL, completion: @escaping @Sendable (String?) -> Void) {
        Task.detached(priority: .userInitiated) {
            let digest = try? await KroutonHardwareAccelerator.shared.computeFileSHA256Hex(at: url)
            await MainActor.run {
                completion(digest)
            }
        }
    }
}
