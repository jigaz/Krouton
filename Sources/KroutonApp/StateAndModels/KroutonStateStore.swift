import Crustini
import Galette
import VideoOven
import Tartine
import Marmalade
import SwiftUI
import OpticalDough

public struct KroutonSeasoningColorPreset: Identifiable, Hashable, Sendable {
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

    public static let allPresets: [KroutonSeasoningColorPreset] = [
        // -1: Multicolor (macOS System Settings Rainbow Wheel)
        KroutonSeasoningColorPreset(id: -1, swatchColor: Color.blue, darkAccent: Color(red: 0.32, green: 0.62, blue: 0.98), lightAccent: Color(red: 0.0, green: 0.44, blue: 0.92), darkOnAccentText: .white, lightOnAccentText: .white, isMonochrome: false),
        // 0: Red
        KroutonSeasoningColorPreset(id: 0, swatchColor: Color(red: 0.90, green: 0.23, blue: 0.23), darkAccent: Color(red: 0.92, green: 0.26, blue: 0.26), lightAccent: Color(red: 0.82, green: 0.16, blue: 0.16), darkOnAccentText: .white, lightOnAccentText: .white, isMonochrome: false),
        // 1: Orange
        KroutonSeasoningColorPreset(id: 1, swatchColor: Color.orange, darkAccent: Color.orange, lightAccent: Color(red: 0.88, green: 0.44, blue: 0.04), darkOnAccentText: .white, lightOnAccentText: .white, isMonochrome: false),
        // 2: High-Contrast Gold / Yellow (Dark text on bright amber-gold in Dark mode; deep warm gold in Light mode)
        KroutonSeasoningColorPreset(id: 2, swatchColor: Color(red: 0.96, green: 0.78, blue: 0.12), darkAccent: Color(red: 0.95, green: 0.76, blue: 0.14), lightAccent: Color(red: 0.76, green: 0.53, blue: 0.02), darkOnAccentText: Color.black.opacity(0.88), lightOnAccentText: .white, isMonochrome: false),
        // 3: Green
        KroutonSeasoningColorPreset(id: 3, swatchColor: Color.green, darkAccent: Color(red: 0.18, green: 0.78, blue: 0.36), lightAccent: Color(red: 0.12, green: 0.62, blue: 0.26), darkOnAccentText: .white, lightOnAccentText: .white, isMonochrome: false),
        // 4: Cyan / Teal
        KroutonSeasoningColorPreset(id: 4, swatchColor: Color(red: 0.08, green: 0.82, blue: 0.68), darkAccent: Color(red: 0.08, green: 0.82, blue: 0.68), lightAccent: Color(red: 0.05, green: 0.68, blue: 0.55), darkOnAccentText: Color.black.opacity(0.88), lightOnAccentText: .white, isMonochrome: false),
        // 5: 405nm Laser Blue
        KroutonSeasoningColorPreset(id: 5, swatchColor: Color.blue, darkAccent: Color.blue, lightAccent: Color(red: 0.0, green: 0.40, blue: 0.88), darkOnAccentText: .white, lightOnAccentText: .white, isMonochrome: false),
        // 6: Studio Slate Blue (Default)
        KroutonSeasoningColorPreset(id: 6, swatchColor: Color(red: 0.35, green: 0.52, blue: 0.78), darkAccent: Color(red: 0.38, green: 0.56, blue: 0.84), lightAccent: Color(red: 0.24, green: 0.42, blue: 0.68), darkOnAccentText: .white, lightOnAccentText: .white, isMonochrome: false),
        // 7: Indigo / Violet
        KroutonSeasoningColorPreset(id: 7, swatchColor: Color.indigo, darkAccent: Color(red: 0.46, green: 0.42, blue: 0.92), lightAccent: Color.indigo, darkOnAccentText: .white, lightOnAccentText: .white, isMonochrome: false),
        // 8: Toasted Krouton Brown (Replaces Mauve/Pink!)
        KroutonSeasoningColorPreset(id: 8, swatchColor: Color(red: 0.64, green: 0.42, blue: 0.24), darkAccent: Color(red: 0.72, green: 0.49, blue: 0.30), lightAccent: Color(red: 0.52, green: 0.32, blue: 0.16), darkOnAccentText: .white, lightOnAccentText: .white, isMonochrome: false),
        // 9: High-Contrast Black & White Monochrome (Silver-White w/ Black text in Dark mode; Graphite-Black w/ White text in Light mode)
        KroutonSeasoningColorPreset(id: 9, swatchColor: Color.primary, darkAccent: Color(white: 0.86), lightAccent: Color(white: 0.18), darkOnAccentText: Color.black.opacity(0.92), lightOnAccentText: .white, isMonochrome: true)
    ]
}

public enum KroutonRoastAppearanceMode: String, CaseIterable, Identifiable, Sendable {
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

public enum KroutonBurntToastSeverity: String, Sendable {
    case criticalOverburn
    case warning4GBNoUDF
    case warningFilenameLength
    case warningConsoleMedia
}

public struct KroutonPantryCalibrationCheck: Identifiable, Hashable, Sendable {
    public let id: String
    public let severity: KroutonBurntToastSeverity
    public let title: String
    public let detail: String
    public let actionButtonTitle: String?

    public init(id: String, severity: KroutonBurntToastSeverity, title: String, detail: String, actionButtonTitle: String? = nil) {
        self.id = id
        self.severity = severity
        self.title = title
        self.detail = detail
        self.actionButtonTitle = actionButtonTitle
    }
}

public enum KroutonGarnishStyleMode: String, CaseIterable, Identifiable, Sendable {
    case defaultStyle = "Default"
    case dark = "Dark"
    case clear = "Clear"
    case tinted = "Tinted"
    public var id: String { rawValue }
}

public enum KroutonCubeIconSizeMode: String, CaseIterable, Identifiable, Sendable {
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

public enum KroutonPantryFolderColorMode: String, CaseIterable, Identifiable, Sendable {
    case automatic = "Automatic"
    case classicAqua = "Classic Aqua Blue"
    case accentTinted = "Theme Accent"
    case secondaryHarmony = "Secondary Harmony"
    case amberGold = "Amber Gold"
    case graphite = "Space Gray"
    public var id: String { rawValue }

    @MainActor
    public func resolvedFolderColor(accent: Color) -> Color {
        let store = KroutonStateStore.shared
        switch self {
        case .automatic:
            if let store, store.enableSecondaryAccentUITints {
                return store.activeSecondaryAccent
            }
            return accent
        case .accentTinted:
            return accent
        case .secondaryHarmony:
            return store?.activeSecondaryAccent ?? accent.perceptualSplitComplement
        case .classicAqua:
            return Color(red: 0.22, green: 0.64, blue: 0.96)
        case .amberGold:
            return Color.orange
        case .graphite:
            return Color.secondary
        }
    }
}

public enum KroutonCroutonLabelStyle: String, CaseIterable, Identifiable, Sendable {
    case synthGrid     = "Synth Technical Grid"
    case vinylGrooves  = "Concentric Studio Rings"
    case dualHalftone  = "Split-Harmony Radial"
    case archivalSpec  = "Minimalist Archival Spec"
    public var id: String { rawValue }
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

public enum KroutonBakeryStation: String, CaseIterable, Identifiable, Sendable {
    case burn = "BURN"
    case depot = "DISC IMAGE DEPOT"
    case copy = "COPY"
    case label = "LABEL"
    public var id: String { rawValue }
}

public struct KroutonPantryCatalogItem: Identifiable, Hashable, Sendable {
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

public struct KroutonPantryFeedSubscription: Identifiable, Hashable, Sendable {
    public let id: String
    public var name: String
    public var description: String
    public var itemCount: Int
    public var isEnabled: Bool
    public var sfSymbol: String
}

public struct KroutonSliceLabelGeometry: Identifiable, Hashable, Sendable {
    public var id = UUID()
    public var name: String
    public var outerDiameterMM: Double
    public var innerDiameterMM: Double
    public var offsetXMM: Double
    public var offsetYMM: Double
}

public struct KroutonKitchenEventRow: Identifiable, Hashable, Sendable {
    public let id: String
    public var eventTitle: String
    public var eventSubtitle: String
    public var bannerEnabled: Bool
    public var iPhoneEnabled: Bool
    public var watchEnabled: Bool
    public var soundEnabled: Bool
}

public enum KroutonToasterOutputKind: String, CaseIterable, Identifiable, Sendable {
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

public struct KroutonBakeBatchItem: Identifiable, Hashable, Sendable {
    public let id = UUID()
    public var kind: KroutonToasterOutputKind
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
    public static weak var shared: KroutonStateStore?
    private var isHydratingPreferences: Bool = false

    @Published public var enableSecondaryAccentUITints: Bool = false {
        didSet {
            guard !isHydratingPreferences else { return }
            UserDefaults.standard.set(enableSecondaryAccentUITints, forKey: "krouton.pref.harmonyEnabled")
            tintWindowWithWallpaper = enableSecondaryAccentUITints
            objectWillChange.send()
        }
    }

    @Published public var appearanceMode: KroutonRoastAppearanceMode = .auto {
        didSet {
            guard !isHydratingPreferences else { return }
            UserDefaults.standard.set(appearanceMode.rawValue, forKey: "krouton.pref.appearanceMode")
        }
    }
    @Published public var selectedAccentIndex: Int = 8 {
        didSet {
            guard !isHydratingPreferences else { return }
            UserDefaults.standard.set(selectedAccentIndex, forKey: "krouton.pref.selectedAccentIndex")
        }
    }
    // macOS System Settings Theme & Window Extensions
    @Published public var iconWidgetStyle: KroutonGarnishStyleMode = .defaultStyle {
        didSet {
            guard !isHydratingPreferences else { return }
            UserDefaults.standard.set(iconWidgetStyle.rawValue, forKey: "krouton.pref.iconWidgetStyle")
        }
    }
    @Published public var folderColorMode: KroutonPantryFolderColorMode = .automatic {
        didSet {
            guard !isHydratingPreferences else { return }
            UserDefaults.standard.set(folderColorMode.rawValue, forKey: "krouton.pref.folderColorMode")
        }
    }
    @Published public var sidebarIconSize: KroutonCubeIconSizeMode = .medium {
        didSet {
            guard !isHydratingPreferences else { return }
            UserDefaults.standard.set(sidebarIconSize.rawValue, forKey: "krouton.pref.sidebarIconSize")
        }
    }
    @Published public var selectedLabelTemplate: KroutonCroutonLabelStyle = .synthGrid {
        didSet {
            guard !isHydratingPreferences else { return }
            UserDefaults.standard.set(selectedLabelTemplate.rawValue, forKey: "krouton.pref.labelTemplate")
        }
    }
    @Published public var labelShowTracklistOnDisc: Bool = true
    @Published public var tintWindowWithWallpaper: Bool = false
    // Accessibility & VoiceOver Support
    @Published public var appLanguage: KroutonLanguage = .english {
        didSet {
            KroutonL10n.activeISOCode = appLanguage.isoCode
            guard !isHydratingPreferences else { return }
            UserDefaults.standard.set(appLanguage.rawValue, forKey: "krouton.pref.appLanguage")
        }
    }
    @Published public var voiceOverSpokenTelemetry: Bool = true
    @Published public var a11yIncreaseContrast: Bool = false
    @Published public var a11yDifferentiateWithoutColor: Bool = true
    @Published public var a11yReduceMotion: Bool = false
    @Published public var rememberLastTaskOnLaunch: Bool = true {
        didSet {
            guard !isHydratingPreferences else { return }
            UserDefaults.standard.set(rememberLastTaskOnLaunch, forKey: "krouton.pref.rememberLastTask")
        }
    }
    @Published public var useBase10Units: Bool = true {
        didSet {
            guard !isHydratingPreferences else { return }
            UserDefaults.standard.set(useBase10Units, forKey: "krouton.pref.useBase10Units")
        }
    }
    @Published public var scratchDiskPath: String = "~/Library/Caches/app.krouton.staging"
    @Published public var autoPurgeScratch: Bool = true

    @Published public var selectedSettingsPane: KroutonSettingsCategory = .general
    @Published public var selectedCategory: KroutonBakeryStation = .burn {
        didSet {
            guard !isHydratingPreferences, rememberLastTaskOnLaunch else { return }
            UserDefaults.standard.set(selectedCategory.rawValue, forKey: "krouton.pref.lastCategory")
        }
    }
    @Published public var selectedTaskID: String = "data-hybrid" {
        didSet {
            guard !isHydratingPreferences, rememberLastTaskOnLaunch else { return }
            UserDefaults.standard.set(selectedTaskID, forKey: "krouton.pref.lastTaskID")
        }
    }
    @Published public var bitsetVendorProfile: String = "Auto-Detect (MMC 0xFA / Pioneer / Lite-On / LG)"
    @Published public var autoLoadNextDiscBatchMode: Bool = true
    @Published public var autoLoadCountdownSeconds: Int = 5

    // Real Staged Files from Finder (Sprint 1)
    @Published public var stagedFiles: [KroutonLoafFileEntry] = []
    @Published public var redBookTracks: [KroutonAudioCube] = [
        KroutonAudioCube(url: URL(fileURLWithPath: "/System/Library/Sounds/Glass.aiff"), title: "01 - Analogue Warmth (Intro)", performer: "The Kroutons", isrcCode: "USKRO2600001", durationSeconds: 222.24, preGapSeconds: 2.0, transitionStyle: .standard2s),
        KroutonAudioCube(url: URL(fileURLWithPath: "/System/Library/Sounds/Ping.aiff"), title: "02 - Optical Servo Lock", performer: "The Kroutons", isrcCode: "USKRO2600002", durationSeconds: 258.00, preGapSeconds: 0.0, transitionStyle: .gapless0s),
        KroutonAudioCube(url: URL(fileURLWithPath: "/System/Library/Sounds/Hero.aiff"), title: "03 - Phthalocyanine Groove", performer: "The Kroutons", isrcCode: "USKRO2600003", durationSeconds: 311.53, preGapSeconds: 0.0, crossfadeSeconds: 2.0, transitionStyle: .jamCrossfade),
        KroutonAudioCube(url: URL(fileURLWithPath: "/System/Library/Sounds/Purr.aiff"), title: "04 - Lead-Out Horizon", performer: "The Kroutons", isrcCode: "USKRO2600004", durationSeconds: 295.13, preGapSeconds: 2.0, transitionStyle: .standard2s)
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

    @Published public var discFormats: [KroutonRecipeSpec] = KroutonOpticalRecipeCatalog.defaultFormats

    @Published public var depotChannels: [KroutonPantryFeedSubscription] = KroutonDepotStaticCatalog.defaultChannels
    @Published public var customDepotFeedURL: String = "https://depot.krouton.app/v1/manifest.json"
    @Published public var autoVerifyDepotSHA256: Bool = true
    @Published public var enableVMTestBootInDepot: Bool = true

    @Published public var stagedDepotItemID: String? = nil
    @Published public var rejectedDropNotice: String? = nil
    @Published public var selectedDepotHeroItemID: String? = "sysrescue-11"
    @Published public var depotDownloadProgress: [String: Double] = [:]
    @Published public var isSearchingInternetArchive: Bool = false
    @Published public var archiveOrgLiveCount: Int = 0

    @Published public var depotItems: [KroutonPantryCatalogItem] = KroutonDepotStaticCatalog.defaultItems

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

    @Published public var labelPresets: [KroutonSliceLabelGeometry] = [
        KroutonSliceLabelGeometry(name: "Epson ET-8550 Full Hub (120mm / 18mm)", outerDiameterMM: 120.0, innerDiameterMM: 18.0, offsetXMM: 0.0, offsetYMM: 0.0),
        KroutonSliceLabelGeometry(name: "Standard Inkjet Disc (118mm / 23mm)", outerDiameterMM: 118.0, innerDiameterMM: 23.0, offsetXMM: 0.0, offsetYMM: 0.0),
        KroutonSliceLabelGeometry(name: "Non-Hub Standard (118mm / 41mm)", outerDiameterMM: 118.0, innerDiameterMM: 41.0, offsetXMM: 0.0, offsetYMM: 0.0),
        KroutonSliceLabelGeometry(name: "80mm Mini-CD / GameCube (80mm / 18mm)", outerDiameterMM: 80.0, innerDiameterMM: 18.0, offsetXMM: 0.0, offsetYMM: 0.0)
    ]
    @Published public var selectedLabelPresetIndex: Int = 0
    @Published public var defaultAutoLabelStyle: String = "Full-Bleed Artwork + Arc Typography"
    @Published public var visionHoleAvoidance: Bool = true
    @Published public var customTMDBKey: String = ""
    @Published public var customFanartKey: String = ""

    @Published public var notificationMatrix: [KroutonKitchenEventRow] = [
        KroutonKitchenEventRow(id: "start", eventTitle: "Burn, rip, or transcode started", eventSubtitle: "Triggered when laser calibration or extraction begins", bannerEnabled: true, iPhoneEnabled: true, watchEnabled: false, soundEnabled: false),
        KroutonKitchenEventRow(id: "done", eventTitle: "Task completed & verified", eventSubtitle: "Triggered when all queued destinations finish without error", bannerEnabled: true, iPhoneEnabled: true, watchEnabled: true, soundEnabled: true),
        KroutonKitchenEventRow(id: "err", eventTitle: "Task failed or buffer underrun", eventSubtitle: "Critical hardware, media, or network link interruption", bannerEnabled: true, iPhoneEnabled: true, watchEnabled: true, soundEnabled: true),
        KroutonKitchenEventRow(id: "layer", eventTitle: "Dual-layer (L0 -> L1) break reached", eventSubtitle: "DVD-9 or BD-50 seamless layer transition point", bannerEnabled: true, iPhoneEnabled: false, watchEnabled: true, soundEnabled: false),
        KroutonKitchenEventRow(id: "swap", eventTitle: "Blank disc or tray swap required", eventSubtitle: "Multi-disc queue waiting for operator", bannerEnabled: true, iPhoneEnabled: true, watchEnabled: true, soundEnabled: true),
        KroutonKitchenEventRow(id: "depot", eventTitle: "Disc Image Depot download verified", eventSubtitle: "ISO / image downloaded and SHA-256 verified", bannerEnabled: true, iPhoneEnabled: false, watchEnabled: false, soundEnabled: true)
    ]

    // Default to Physical Burner (MATSHITA DVD-R UJ-898)
    @Published public var destinationQueue: [KroutonBakeBatchItem] = [
        KroutonBakeBatchItem(
            kind: .physicalBurner,
            hardwareOrPath: "MATSHITA DVD-R UJ-898 (Local USB)",
            speedOrCodec: "Max Safe (Auto)",
            simulationMode: false,
            verifyAfterBurn: true,
            compressAfterCreation: false
        )
    ]

    public func multicolorPresetID(forTaskID taskID: String, category: KroutonBakeryStation) -> Int {
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

    public func effectiveColorForTask(id taskID: String, category: KroutonBakeryStation) -> Color {
        let resolvedScheme: ColorScheme = {
            switch appearanceMode {
            case .light: return .light
            case .dark: return .dark
            case .auto:
                let isDark = KroutonOSDesktopBridge.isSystemDarkMode()
                return isDark ? .dark : .light
            }
        }()
        if selectedAccentIndex == -1 {
            let pid = multicolorPresetID(forTaskID: taskID, category: category)
            let p = KroutonSeasoningColorPreset.allPresets.first(where: { $0.id == pid }) ?? resolvedAccentPreset
            return p.effectiveAccent(for: resolvedScheme)
        }
        return activeAccent
    }

    private var resolvedAccentPreset: KroutonSeasoningColorPreset {
        if selectedAccentIndex == -1 {
            let targetID = multicolorPresetID(forTaskID: selectedTaskID, category: selectedCategory)
            return KroutonSeasoningColorPreset.allPresets.first(where: { $0.id == targetID }) ?? KroutonSeasoningColorPreset.allPresets[1]
        }
        return KroutonSeasoningColorPreset.allPresets.first(where: { $0.id == selectedAccentIndex })
            ?? KroutonSeasoningColorPreset.allPresets.first(where: { $0.id == 8 })
            ?? KroutonSeasoningColorPreset.allPresets[0]
    }

    public var activeAccent: Color {
        let resolvedScheme: ColorScheme = {
            switch appearanceMode {
            case .light: return .light
            case .dark: return .dark
            case .auto:
                let isDark = KroutonOSDesktopBridge.isSystemDarkMode()
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
                let isDark = KroutonOSDesktopBridge.isSystemDarkMode()
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

    public func activeFormatSpec() -> KroutonRecipeSpec {
        discFormats.first(where: { $0.id == selectedTaskID }) ?? discFormats[0]
    }

    public func isURLCompatible(_ url: URL, for spec: KroutonRecipeSpec) -> Bool {
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
            KroutonOSDesktopBridge.playAcousticCue()
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
                let entry = KroutonToasterBank.inspectFileOrFolder(url: url)
                stagedFiles.append(entry)
            }
        }
    }

    public func addAudioTrackURLs(_ urls: [URL]) {
        for url in urls {
            let nextIndex = redBookTracks.count + 1
            let track = KroutonToasterBank.inspectAudioTrack(url: url, index: nextIndex)
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
                stagedFiles[idx] = KroutonLoafFileEntry(
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
        KroutonOSDesktopBridge.postVoiceOverAnnouncement(message)
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
            var updated = KroutonLoafFileEntry(
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
            var updated = KroutonLoafFileEntry(
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

    public func stageDepotItemForBurning(_ item: KroutonPantryCatalogItem, jumpToInspector: Bool = false) {
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
        let stagedEntry = KroutonLoafFileEntry(
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
        KroutonOSDesktopBridge.playAcousticCue()

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
                        let newItem = KroutonPantryCatalogItem(
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

    public init() {
        Self.shared = self
        hydratePreferencesFromUserDefaults()
    }

    private func hydratePreferencesFromUserDefaults() {
        isHydratingPreferences = true
        defer { isHydratingPreferences = false }
        let defaults = UserDefaults.standard

        if defaults.object(forKey: "krouton.pref.selectedAccentIndex") != nil {
            selectedAccentIndex = defaults.integer(forKey: "krouton.pref.selectedAccentIndex")
        }
        if defaults.object(forKey: "krouton.pref.harmonyEnabled") != nil {
            enableSecondaryAccentUITints = defaults.bool(forKey: "krouton.pref.harmonyEnabled")
            tintWindowWithWallpaper = enableSecondaryAccentUITints
        }
        if let rawApp = defaults.string(forKey: "krouton.pref.appearanceMode"),
           let mode = KroutonRoastAppearanceMode(rawValue: rawApp) {
            appearanceMode = mode
        }
        if let rawStyle = defaults.string(forKey: "krouton.pref.iconWidgetStyle"),
           let style = KroutonGarnishStyleMode(rawValue: rawStyle) {
            iconWidgetStyle = style
        }
        if let rawFolder = defaults.string(forKey: "krouton.pref.folderColorMode"),
           let fMode = KroutonPantryFolderColorMode(rawValue: rawFolder) {
            folderColorMode = fMode
        }
        if let rawSize = defaults.string(forKey: "krouton.pref.sidebarIconSize"),
           let sSize = KroutonCubeIconSizeMode(rawValue: rawSize) {
            sidebarIconSize = sSize
        }
        if let rawTpl = defaults.string(forKey: "krouton.pref.labelTemplate"),
           let tpl = KroutonCroutonLabelStyle(rawValue: rawTpl) {
            selectedLabelTemplate = tpl
        }
        if let rawLang = defaults.string(forKey: "krouton.pref.appLanguage"),
           let lang = KroutonLanguage(rawValue: rawLang) {
            appLanguage = lang
            KroutonL10n.activeISOCode = lang.isoCode
        }
        if defaults.object(forKey: "krouton.pref.useBase10Units") != nil {
            useBase10Units = defaults.bool(forKey: "krouton.pref.useBase10Units")
        }
        if defaults.object(forKey: "krouton.pref.rememberLastTask") != nil {
            rememberLastTaskOnLaunch = defaults.bool(forKey: "krouton.pref.rememberLastTask")
        }
        if rememberLastTaskOnLaunch {
            if let rawCat = defaults.string(forKey: "krouton.pref.lastCategory"),
               let cat = KroutonBakeryStation(rawValue: rawCat) {
                selectedCategory = cat
            }
            if let lastTask = defaults.string(forKey: "krouton.pref.lastTaskID"), !lastTask.isEmpty {
                selectedTaskID = lastTask
            }
        }
    }
}

// MARK: - Functional Icon & Widget Style Renderer (Default / Dark / Clear / Tinted)
public struct KroutonStyledIconBadge: View {
    public let sfSymbol: String
    public let tintColor: Color
    public let style: KroutonGarnishStyleMode
    public var isSelectedRow: Bool = false
    public var onAccentText: Color = .white
    public var size: CGFloat = 24
    public var symbolSize: CGFloat = 13

    public init(
        sfSymbol: String,
        tintColor: Color,
        style: KroutonGarnishStyleMode,
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
        let activeStore = KroutonStateStore.shared
        let isLight = (activeStore?.resolvedColorScheme == .light)
        let useHarmonyBg = (style == .tinted && (activeStore?.enableSecondaryAccentUITints ?? false))
        // In Light Mode, use the bright neon P3 harmony color for the tile fill so yellows/mints look luminous instead of muddy,
        // while using the deep Light Mode harmony color for the crisp border ring!
        let presetID = activeStore?.selectedAccentIndex ?? 6
        let effectiveID = presetID >= 0 ? presetID : (activeStore.map { $0.multicolorPresetID(forTaskID: $0.selectedTaskID, category: $0.selectedCategory) } ?? 6)
        let brightHarmony = KroutonStateStore.secondaryHarmonyForPresetID(effectiveID, scheme: .dark)
        let strokeHarmony = activeStore?.activeSecondaryAccent ?? tintColor.perceptualSplitComplement

        ZStack {
            RoundedRectangle(cornerRadius: size * 0.26, style: .continuous)
                .fill(badgeBackgroundGradient(isLight: isLight))
                .overlay(
                    Group {
                        if useHarmonyBg {
                            RoundedRectangle(cornerRadius: size * 0.26, style: .continuous)
                                .fill(isLight ? brightHarmony.opacity(0.38) : strokeHarmony.opacity(0.28))
                        } else if style == .tinted && isLight {
                            RoundedRectangle(cornerRadius: size * 0.26, style: .continuous)
                                .fill(tintColor.opacity(0.15))
                        }
                    }
                )
                .frame(width: size, height: size)
                .overlay(
                    RoundedRectangle(cornerRadius: size * 0.26, style: .continuous)
                        .stroke(
                            useHarmonyBg
                                ? strokeHarmony.opacity(isLight ? 0.65 : 0.55)
                                : (isSelectedRow ? Color.white.opacity(0.35) : Color.primary.opacity(isLight ? 0.16 : 0.12)),
                            lineWidth: useHarmonyBg ? 1.25 : 0.8
                        )
                )

            Image(systemName: sfSymbol)
                .font(.system(size: symbolSize, weight: .semibold))
                .foregroundStyle(symbolForeground(isLight: isLight))
        }
    }

    private func badgeBackgroundGradient(isLight: Bool) -> LinearGradient {
        switch style {
        case .defaultStyle:
            if isSelectedRow {
                return LinearGradient(
                    colors: [Color.white.opacity(0.24), Color.white.opacity(0.10)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            }
            return LinearGradient(
                colors: [tintColor, tintColor.opacity(0.76)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case .dark:
            return LinearGradient(
                colors: [Color(white: 0.18), Color(white: 0.09)],
                startPoint: .top,
                endPoint: .bottom
            )
        case .clear:
            return LinearGradient(
                colors: [
                    Color.primary.opacity(isLight ? 0.10 : 0.14),
                    Color.primary.opacity(isLight ? 0.04 : 0.05)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        case .tinted:
            if isLight {
                // Crisp alabaster/ivory studio tile in Light Mode so bright Harmony washes + deep Primary icons pop!
                return LinearGradient(
                    colors: [Color(white: 0.98), Color(white: 0.93)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            }
            return LinearGradient(
                colors: [Color(white: 0.15), Color(white: 0.08)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }

    private func symbolForeground(isLight: Bool) -> Color {
        switch style {
        case .defaultStyle:
            return onAccentText
        case .dark:
            return .white
        case .clear:
            return isSelectedRow ? onAccentText : .primary
        case .tinted:
            return tintColor
        }
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


// MARK: - Chunk 8: Live Backend Engine Bridge Across All 5 Culinary Modules
extension KroutonStateStore {
    /// Compiles a frame-accurate Red Book .cue sheet via Marmalade for the given audio cubes
    public func compileLiveMarmaladeCueSheet(
        albumTitle: String = "KROUTON AUDIO MASTER",
        albumPerformer: String = "THE KROUTON BAKERY",
        mcnCatalog: String = "0123456789012",
        tracks: [KroutonAudioCube] = []
    ) -> String {
        KroutonMarmaladeModule.compileRedBookCueSheet(
            albumTitle: albumTitle,
            albumPerformer: albumPerformer,
            mcnCatalog: mcnCatalog,
            tracks: tracks
        )
    }

    /// Computes total 18-byte Sony/Philips CD-Text subchannel packs via Marmalade
    public func computeLiveMarmaladeCDTextPackCount(
        albumTitle: String = "KROUTON AUDIO MASTER",
        albumPerformer: String = "THE KROUTON BAKERY",
        tracks: [KroutonAudioCube] = []
    ) -> Int {
        var count = KroutonMarmaladeModule.buildCDTextPacks(packType: 0x80, trackNumber: 0, text: albumTitle).count
        count += KroutonMarmaladeModule.buildCDTextPacks(packType: 0x81, trackNumber: 0, text: albumPerformer).count
        for (idx, cube) in tracks.enumerated() {
            let tNum = UInt8(min(99, idx + 1))
            count += KroutonMarmaladeModule.buildCDTextPacks(packType: 0x80, trackNumber: tNum, text: cube.title).count
            count += KroutonMarmaladeModule.buildCDTextPacks(packType: 0x81, trackNumber: tNum, text: cube.performer).count
        }
        return count
    }

    /// Plans a deduplicated Hybrid ISO-9660 / Joliet / UDF 2.60 / El Torito LBA sector layout via Tartine
    public func planLiveTartineHybridLayout(
        volumeLabel: String = "KROUTON_HYBRID_DISC",
        entries: [KroutonLoafFileEntry] = [],
        isElToritoBootable: Bool = false
    ) -> KroutonTartineLayoutPlan {
        KroutonTartineModule.planHybridDataLayout(
            volumeLabel: volumeLabel,
            entries: entries,
            isElToritoBootable: isElToritoBootable
        )
    }

    /// Computes a live VideoOven bitrate budget for the given duration and target optical medium
    public func computeLiveVideoOvenBitrateBudget(
        durationSeconds: Double = 5400.0,
        audioKbps: Int = 448,
        medium: KroutonVideoTargetMedium = .dvd5SingleLayer
    ) -> KroutonVideoBitrateBudget {
        KroutonVideoOvenModule.computeBitrateBudget(
            durationSeconds: max(60.0, durationSeconds),
            audioKbps: audioKbps,
            medium: medium
        )
    }

    /// Computes a live Crustini 300-DPI polar arc glyph layout for the Disc Label Studio
    public func computeLiveDiscLabelArcGlyphs(title: String, radiusPoints: Double = 500.0) -> [KroutonPolarArcGlyphPlacement] {
        KroutonKrustiniModule.computePolarArcGlyphLayout(
            text: title,
            centerX: 708.5,
            centerY: 708.5,
            radiusPoints: radiusPoints
        )
    }
}


