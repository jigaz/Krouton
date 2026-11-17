import SwiftUI
import Foundation
import Combine
import OpticalCore
import AudioKit
import VideoKit
import ImageKit
import LabelKit
import RescueKit

@MainActor
public final class KroutonStateStore: ObservableObject {
    public func refreshOpticalDrives() { KroutonWindowManager.shared.driveManager.refreshDrives() }
    public func ejectActiveOpticalDisc() { KroutonWindowManager.shared.driveManager.ejectDrive(id: KroutonWindowManager.shared.driveManager.availableDrives.first?.id) }

    // MARK: - Modular Feature Sub-Stores & Domain Models
    public let labelWorkspaceSubStore = KroutonLabelWorkspaceSubStore()
    public let discImageInspectorSubStore = KroutonDiscImageInspectorSubStore()
    public let burnQueueSubStore = KroutonBurnQueueSubStore()
    public let depotCatalogSubStore = KroutonDepotCatalogSubStore()

    @Published public var appearance = AppearancePreferences()
    @Published public var depot = DepotCatalogue()
    @Published public var label = LabelDocument()
    @Published public var rip = RipSettings()

    public static weak var shared: KroutonStateStore?
    var isHydratingPreferences: Bool = false

    // MARK: - Appearance Preferences Forwarding
    public var enableSecondaryAccentUITints: Bool {
        get { appearance.enableSecondaryAccentUITints }
        set {
            appearance.enableSecondaryAccentUITints = newValue
            appearance.tintWindowWithWallpaper = newValue
            if !isHydratingPreferences {
                UserDefaults.standard.set(newValue, forKey: "krouton.pref.harmonyEnabled")
            }
        }
    }
    public var tintWindowWithWallpaper: Bool {
        get { appearance.tintWindowWithWallpaper }
        set { appearance.tintWindowWithWallpaper = newValue }
    }
    public var appearanceMode: KroutonRoastAppearanceMode {
        get { appearance.appearanceMode }
        set {
            appearance.appearanceMode = newValue
            if !isHydratingPreferences {
                UserDefaults.standard.set(newValue.rawValue, forKey: "krouton.pref.appearanceMode")
            }
        }
    }
    public var selectedAccentIndex: Int {
        get { appearance.selectedAccentIndex }
        set {
            appearance.selectedAccentIndex = newValue
            if !isHydratingPreferences {
                UserDefaults.standard.set(newValue, forKey: "krouton.pref.selectedAccentIndex")
            }
        }
    }
    public var iconWidgetStyle: KroutonGarnishStyleMode {
        get { appearance.iconWidgetStyle }
        set {
            appearance.iconWidgetStyle = newValue
            if !isHydratingPreferences {
                UserDefaults.standard.set(newValue.rawValue, forKey: "krouton.pref.iconWidgetStyle")
            }
        }
    }
    public var folderColorMode: KroutonStageFolderColorMode {
        get { appearance.folderColorMode }
        set {
            appearance.folderColorMode = newValue
            if !isHydratingPreferences {
                UserDefaults.standard.set(newValue.rawValue, forKey: "krouton.pref.folderColorMode")
            }
        }
    }
    public var sidebarIconSize: KroutonTrackIconSizeMode {
        get { appearance.sidebarIconSize }
        set {
            appearance.sidebarIconSize = newValue
            if !isHydratingPreferences {
                UserDefaults.standard.set(newValue.rawValue, forKey: "krouton.pref.sidebarIconSize")
            }
        }
    }
    public var appLanguage: KroutonLanguage {
        get { appearance.appLanguage }
        set {
            appearance.appLanguage = newValue
            KroutonL10n.activeISOCode = newValue.isoCode
            if !isHydratingPreferences {
                UserDefaults.standard.set(newValue.rawValue, forKey: "krouton.pref.appLanguage")
            }
        }
    }
    public var voiceOverSpokenTelemetry: Bool {
        get { appearance.voiceOverSpokenTelemetry }
        set { appearance.voiceOverSpokenTelemetry = newValue }
    }
    public var a11yIncreaseContrast: Bool {
        get { appearance.a11yIncreaseContrast }
        set { appearance.a11yIncreaseContrast = newValue }
    }
    public var a11yDifferentiateWithoutColor: Bool {
        get { appearance.a11yDifferentiateWithoutColor }
        set { appearance.a11yDifferentiateWithoutColor = newValue }
    }
    public var a11yReduceMotion: Bool {
        get { appearance.a11yReduceMotion }
        set { appearance.a11yReduceMotion = newValue }
    }
    public var rememberLastTaskOnLaunch: Bool {
        get { appearance.rememberLastTaskOnLaunch }
        set {
            appearance.rememberLastTaskOnLaunch = newValue
            if !isHydratingPreferences {
                UserDefaults.standard.set(newValue, forKey: "krouton.pref.rememberLastTask")
            }
        }
    }
    public var useBase10Units: Bool {
        get { appearance.useBase10Units }
        set {
            appearance.useBase10Units = newValue
            if !isHydratingPreferences {
                UserDefaults.standard.set(newValue, forKey: "krouton.pref.useBase10Units")
            }
        }
    }

    // MARK: - Label Document Forwarding
    public var selectedLabelTemplate: KroutonCroutonLabelStyle {
        get { label.selectedTemplate }
        set {
            label.selectedTemplate = newValue
            if !isHydratingPreferences {
                UserDefaults.standard.set(newValue.rawValue, forKey: "krouton.pref.labelTemplate")
            }
        }
    }
    public var labelShowTracklistOnDisc: Bool { get { label.showTracklistOnDisc } set { label.showTracklistOnDisc = newValue } }
    public var labelDiscTitle: String { get { label.discTitle } set { label.discTitle = newValue } }
    public var labelSubtitle: String { get { label.subtitle } set { label.subtitle = newValue } }
    public var autoLabelSearchQuery: String { get { label.autoSearchQuery } set { label.autoSearchQuery = newValue } }
    public var labelBackgroundStyle: KroutonVectorBackgroundStyle { get { label.backgroundStyle } set { label.backgroundStyle = newValue } }
    public var labelBgPrimaryColor: Color { get { label.bgPrimaryColor } set { label.bgPrimaryColor = newValue } }
    public var labelBgSecondaryColor: Color { get { label.bgSecondaryColor } set { label.bgSecondaryColor = newValue } }
    public var labelGradientAngle: Double { get { label.gradientAngle } set { label.gradientAngle = newValue } }
    public var labelGradientMidpoint: Double { get { label.gradientMidpoint } set { label.gradientMidpoint = newValue } }
    public var labelTopArcRadiusMM: Double { get { label.topArcRadiusMM } set { label.topArcRadiusMM = newValue } }
    public var labelBottomArcRadiusMM: Double { get { label.bottomArcRadiusMM } set { label.bottomArcRadiusMM = newValue } }
    public var labelArcLetterSpacing: Double { get { label.arcLetterSpacing } set { label.arcLetterSpacing = newValue } }
    public var labelVectorShapes: [KroutonVectorShapeLayer] { get { label.vectorShapes } set { label.vectorShapes = newValue } }
    public var labelDrawAutoSnap: Bool { get { label.drawAutoSnap } set { label.drawAutoSnap = newValue } }
    public var isLabelVectorDrawMode: Bool { get { label.isVectorDrawMode } set { label.isVectorDrawMode = newValue } }
    public var labelGPUSeedPattern: KroutonGPUSeedPattern { get { label.gpuSeedPattern } set { label.gpuSeedPattern = newValue } }
    public var labelKaleidoscopeFacets: Int { get { label.kaleidoscopeFacets } set { label.kaleidoscopeFacets = newValue } }
    public var labelKaleidoscopeRig: KroutonKaleidoscopeMirrorRig { get { label.kaleidoscopeRig } set { label.kaleidoscopeRig = newValue } }
    public var labelChamberTumble: Double { get { label.chamberTumble } set { label.chamberTumble = newValue } }
    public var labelTinyPlanetRadius: Double { get { label.tinyPlanetRadius } set { label.tinyPlanetRadius = newValue } }
    public var labelUseVisionForeground: Bool { get { label.useVisionForeground } set { label.useVisionForeground = newValue } }
    public var labelPolarSymmetryCount: Int { get { label.polarSymmetryCount } set { label.polarSymmetryCount = newValue } }
    public var labelTextElements: [KroutonLabelTextElement] { get { label.textElements } set { label.textElements = newValue } }
    public var labelSelectedTextID: UUID? { get { label.selectedTextID } set { label.selectedTextID = newValue } }
    public var labelBgAdjustments: KroutonBackgroundAdjustments { get { label.bgAdjustments } set { label.bgAdjustments = newValue } }
    public var labelShowAlignmentGrid: Bool { get { label.showAlignmentGrid } set { label.showAlignmentGrid = newValue } }
    public var labelCanvasZoom: Double { get { label.canvasZoom } set { label.canvasZoom = newValue } }
    public var labelPresets: [KroutonDiscLabelGeometry] { get { label.presets } set { label.presets = newValue } }
    public var selectedLabelPresetIndex: Int { get { label.selectedPresetIndex } set { label.selectedPresetIndex = newValue } }
    public var defaultAutoLabelStyle: String { get { label.defaultAutoLabelStyle } set { label.defaultAutoLabelStyle = newValue } }
    public var visionHoleAvoidance: Bool { get { label.visionHoleAvoidance } set { label.visionHoleAvoidance = newValue } }
    public var customTMDBKey: String { get { label.customTMDBKey } set { label.customTMDBKey = newValue } }
    public var customFanartKey: String { get { label.customFanartKey } set { label.customFanartKey = newValue } }

    // MARK: - Depot Catalogue Forwarding
    public var depotChannels: [KroutonDepotFeedSubscription] { get { depot.channels } set { depot.channels = newValue } }
    public var depotItems: [KroutonDepotCatalogItem] { get { depot.items } set { depot.items = newValue } }
    public var customDepotFeedURL: String { get { depot.customFeedURL } set { depot.customFeedURL = newValue } }
    public var autoVerifyDepotSHA256: Bool { get { depot.autoVerifySHA256 } set { depot.autoVerifySHA256 = newValue } }
    public var enableVMTestBootInDepot: Bool { get { depot.enableVMTestBoot } set { depot.enableVMTestBoot = newValue } }
    public var stagedDepotItemID: String? { get { depot.stagedItemID } set { depot.stagedItemID = newValue } }
    public var selectedDepotHeroItemID: String? { get { depot.selectedHeroItemID } set { depot.selectedHeroItemID = newValue } }
    public var depotDownloadProgress: [String: Double] { get { depot.downloadProgress } set { depot.downloadProgress = newValue } }
    public var isSearchingInternetArchive: Bool { get { depot.isSearchingInternetArchive } set { depot.isSearchingInternetArchive = newValue } }
    public var archiveOrgLiveCount: Int { get { depot.archiveOrgLiveCount } set { depot.archiveOrgLiveCount = newValue } }

    // MARK: - Rip & Transcode Settings Forwarding
    public var defaultCrossfadeSec: Double { get { rip.defaultCrossfadeSec } set { rip.defaultCrossfadeSec = newValue } }
    public var autoBeatmatchSoundAnalysis: Bool { get { rip.autoBeatmatchSoundAnalysis } set { rip.autoBeatmatchSoundAnalysis = newValue } }
    public var carSafeMP3Mode: Bool { get { rip.carSafeMP3Mode } set { rip.carSafeMP3Mode = newValue } }
    public var singleVideoFirstPlay: Bool { get { rip.singleVideoFirstPlay } set { rip.singleVideoFirstPlay = newValue } }
    public var fitToDiscPreserveMenus: Bool { get { rip.fitToDiscPreserveMenus } set { rip.fitToDiscPreserveMenus = newValue } }
    public var fitToDiscStripForeignDubs: Bool { get { rip.fitToDiscStripForeignDubs } set { rip.fitToDiscStripForeignDubs = newValue } }
    public var videoToolboxTwoPassVBR: Bool { get { rip.videoToolboxTwoPassVBR } set { rip.videoToolboxTwoPassVBR = newValue } }
    public var driveReadOffsetSamples: Int { get { rip.driveReadOffsetSamples } set { rip.driveReadOffsetSamples = newValue } }
    public var paranoiaErrorRetries: Int { get { rip.paranoiaErrorRetries } set { rip.paranoiaErrorRetries = newValue } }
    public var verifyAccurateRip: Bool { get { rip.verifyAccurateRip } set { rip.verifyAccurateRip = newValue } }
    public var writeCueSheetLog: Bool { get { rip.writeCueSheetLog } set { rip.writeCueSheetLog = newValue } }
    public var hardwareDeinterlaceVideo: Bool { get { rip.hardwareDeinterlaceVideo } set { rip.hardwareDeinterlaceVideo = newValue } }
    public var passthroughAtmosTrueHD: Bool { get { rip.passthroughAtmosTrueHD } set { rip.passthroughAtmosTrueHD = newValue } }
    public var namingTokens: [String] { get { rip.namingTokens } set { rip.namingTokens = newValue } }
    public var enableNetworkServerSharing: Bool { get { rip.enableNetworkServerSharing } set { rip.enableNetworkServerSharing = newValue } }
    public var serverRingBufferMB: Double { get { rip.serverRingBufferMB } set { rip.serverRingBufferMB = newValue } }
    public var preStageImageToServerSSD: Bool { get { rip.preStageImageToServerSSD } set { rip.preStageImageToServerSSD = newValue } }
    public var forceDVDROMBookType: Bool { get { rip.forceDVDROMBookType } set { rip.forceDVDROMBookType = newValue } }
    public var disableBDDefectManagementForVideo: Bool { get { rip.disableBDDefectManagementForVideo } set { rip.disableBDDefectManagementForVideo = newValue } }
    public var namingPreviewString: String { rip.namingPreviewString }

    // MARK: - Core Navigation, Staging & Burn Queue State
    public var savedQueuesByDomain: [String: [KroutonBakeBatchItem]] = [:]
    @Published public var scratchDiskPath: String = "~/Library/Caches/app.krouton.staging"
    @Published public var autoPurgeScratch: Bool = true
    @Published public var selectedSettingsPane: KroutonSettingsCategory = .general
    @Published public var selectedCategory: KroutonMasteringStation = .burn {
        didSet {
            guard !isHydratingPreferences, rememberLastTaskOnLaunch else { return }
            UserDefaults.standard.set(selectedCategory.rawValue, forKey: "krouton.pref.lastCategory")
        }
    }
    @Published public var selectedTaskID: String = "data-hybrid" {
        didSet {
            guard !isHydratingPreferences, rememberLastTaskOnLaunch else { return }
            UserDefaults.standard.set(selectedTaskID, forKey: "krouton.pref.lastTaskID")
            KroutonCrashRecoveryController.shared.saveCurrentState(from: self)
        }
    }
    @Published public var bitsetVendorProfile: String = "Auto-Detect (MMC 0xFA / Pioneer / Lite-On / LG)"
    @Published public var autoLoadNextDiscBatchMode: Bool = true
    @Published public var autoLoadCountdownSeconds: Int = 5

    @Published public var stagedFiles: [KroutonStagedFileEntry] = []
    @Published public var rejectedDropNotice: String? = nil

    lazy var audioController = AudioProjectController { [weak self] _ in
        guard let self else { return }
        KroutonCrashRecoveryController.shared.saveCurrentState(from: self)
    }

    public var redBookTracks: [KroutonRedBookTrack] {
        get { audioController.project.derivedRedBookCubes }
        set { }
    }

    @Published public var discPerformer: String = ""
    @Published public var discMCNBarcode: String = ""
    @Published public var carSafeZeroPadPrefix: Bool = true
    @Published public var carSafeStripAppleDouble: Bool = true
    @Published public var carSafeGenerateM3U: Bool = true
    @Published public var includeUDFBridge: Bool = true
    @Published public var includeJolietNames: Bool = true
    @Published public var allowATIPOverburn: Bool = false
    @Published public var dualLayerBreakSectorLBA: Int64 = 2_086_912
    @Published public var discVolumeTitle: String = ""
    @Published public var dataTargetDiscMedium: KroutonSpanningDiscMedium = .dvd5Single
    @Published public var targetDiscMediumByTask: [String: KroutonSpanningDiscMedium] = [:]
    @Published public var dataDiscVolumeOverrides: [Int: String] = [:]
    @Published public var finderLayoutBlueprint = KroutonFinderLayoutBlueprint()
    @Published public var discFormats: [KroutonOpticalWorkflowSpec] = KroutonOpticalWorkflowCatalog.defaultFormats

    @Published public var notificationMatrix: [KroutonKitchenEventRow] = [
        KroutonKitchenEventRow(id: "start", eventTitle: "Burn, rip, or transcode started", eventSubtitle: "Triggered when laser calibration or extraction begins", bannerEnabled: true, iPhoneEnabled: true, watchEnabled: false, soundEnabled: false),
        KroutonKitchenEventRow(id: "done", eventTitle: "Task completed & verified", eventSubtitle: "Triggered when all queued destinations finish without error", bannerEnabled: true, iPhoneEnabled: true, watchEnabled: true, soundEnabled: true),
        KroutonKitchenEventRow(id: "err", eventTitle: "Task failed or buffer underrun", eventSubtitle: "Critical hardware, media, or network link interruption", bannerEnabled: true, iPhoneEnabled: true, watchEnabled: true, soundEnabled: true),
        KroutonKitchenEventRow(id: "layer", eventTitle: "Dual-layer (L0 -> L1) break reached", eventSubtitle: "DVD-9 or BD-50 seamless layer transition point", bannerEnabled: true, iPhoneEnabled: false, watchEnabled: true, soundEnabled: false),
        KroutonKitchenEventRow(id: "swap", eventTitle: "Blank disc or tray swap required", eventSubtitle: "Multi-disc queue waiting for operator", bannerEnabled: true, iPhoneEnabled: true, watchEnabled: true, soundEnabled: true),
        KroutonKitchenEventRow(id: "depot", eventTitle: "Disc Image Depot download verified", eventSubtitle: "ISO / image downloaded and SHA-256 verified", bannerEnabled: true, iPhoneEnabled: false, watchEnabled: false, soundEnabled: true)
    ]

    @Published public var destinationQueue: [KroutonBakeBatchItem] = [
        KroutonBakeBatchItem(
            kind: .physicalBurner,
            hardwareOrPath: "",
            speedOrCodec: "Max Safe (Auto)",
            simulationMode: false,
            verifyAfterBurn: true,
            compressAfterCreation: false
        )
    ]

    // MARK: - Single Consolidated Colour-Scheme & Accent Resolution
    public func multicolorPresetID(forTaskID taskID: String, category: KroutonMasteringStation) -> Int {
        switch category {
        case .depot: return 4
        case .copy:  return 1
        case .label: return 0
        case .burn:
            if let spec = discFormats.first(where: { $0.id == taskID }) {
                switch spec.filterGroup {
                case .audio:   return 3
                case .video:   return 5
                case .console: return 7
                case .legacy:  return 8
                case .data, .all, .enabled:
                    return spec.id.contains("mdisc") ? 2 : 6
                }
            }
            return 6
        }
    }

    private var resolvedAccentPreset: KroutonAccentColorPreset {
        if selectedAccentIndex == -1 {
            let targetID = multicolorPresetID(forTaskID: selectedTaskID, category: selectedCategory)
            return KroutonAccentColorPreset.allPresets.first(where: { $0.id == targetID }) ?? KroutonAccentColorPreset.allPresets[1]
        }
        return KroutonAccentColorPreset.allPresets.first(where: { $0.id == selectedAccentIndex })
            ?? KroutonAccentColorPreset.allPresets.first(where: { $0.id == 8 })
            ?? KroutonAccentColorPreset.allPresets[0]
    }

    public func effectiveColorForTask(id taskID: String, category: KroutonMasteringStation) -> Color {
        if selectedAccentIndex == -1 {
            let pid = multicolorPresetID(forTaskID: taskID, category: category)
            let p = KroutonAccentColorPreset.allPresets.first(where: { $0.id == pid }) ?? resolvedAccentPreset
            return p.effectiveAccent(for: appearance.effectiveColorScheme)
        }
        return activeAccent
    }

    public var activeAccent: Color {
        resolvedAccentPreset.effectiveAccent(for: appearance.effectiveColorScheme)
    }

    public var activeOnAccentText: Color {
        resolvedAccentPreset.effectiveOnAccentText(for: appearance.effectiveColorScheme)
    }

    public var activeLocale: Locale { appearance.activeLocale }
    public var totalStagedBytes: Int64 { stagedFiles.reduce(0) { $0 + $1.byteSize } }
    public var totalStagedSectorsLBA: Int64 { stagedFiles.reduce(0) { $0 + $1.sectorsLBA } }

    public init() {
        Self.shared = self
        hydratePreferencesFromUserDefaults()
    }

    func hydratePreferencesFromUserDefaults() {
        isHydratingPreferences = true
        defer { isHydratingPreferences = false }
        let defaults = UserDefaults.standard
        appearance.load(from: defaults)
        if let rawTpl = defaults.string(forKey: "krouton.pref.labelTemplate"),
           let tpl = KroutonCroutonLabelStyle(rawValue: rawTpl) {
            label.selectedTemplate = tpl
        }
        if appearance.rememberLastTaskOnLaunch {
            if let rawCat = defaults.string(forKey: "krouton.pref.lastCategory"),
               let cat = KroutonMasteringStation(rawValue: rawCat) {
                selectedCategory = cat
            }
            if let lastTask = defaults.string(forKey: "krouton.pref.lastTaskID"), !lastTask.isEmpty {
                selectedTaskID = lastTask
            }
        }
    }
}
