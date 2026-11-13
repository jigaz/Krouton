import SwiftUI
import Foundation
import Combine
import OpticalDough
import Marmalade
import VideoOven
import Tartine
import Galette
import Crustini

@MainActor
public final class KroutonStateStore: ObservableObject {
    public static weak var shared: KroutonStateStore?
    var isHydratingPreferences: Bool = false

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
    @Published public var labelDiscTitle: String = "THE KROUTON ARCHIVE"
    @Published public var labelSubtitle: String = "2026 MASTER EDITION"
    @Published public var autoLabelSearchQuery: String = "Dark Side of the Moon"
    @Published public var labelBackgroundStyle: KroutonVectorBackgroundStyle = .templateDefault
    @Published public var labelBgPrimaryColor: Color = Color(red: 0.09, green: 0.12, blue: 0.20)
    @Published public var labelBgSecondaryColor: Color = Color(red: 0.20, green: 0.48, blue: 0.78)
    @Published public var labelGradientAngle: Double = 45.0
    @Published public var labelTopArcRadiusMM: Double = 47.0
    @Published public var labelBottomArcRadiusMM: Double = 45.0
    @Published public var labelArcLetterSpacing: Double = 1.0
    @Published public var labelVectorShapes: [KroutonVectorShapeLayer] = []
    @Published public var labelDrawAutoSnap: Bool = true
    @Published public var isLabelVectorDrawMode: Bool = false
    public var savedQueuesByDomain: [String: [KroutonBakeBatchItem]] = [:]
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

    public init() {
        Self.shared = self
        hydratePreferencesFromUserDefaults()
    }

    func hydratePreferencesFromUserDefaults() {
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


