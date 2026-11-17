import Foundation
import OpticalCore
import SwiftUI

@MainActor
extension KroutonStateStore {
    // MARK: - Appearance Preferences Forwarding
    var enableSecondaryAccentUITints: Bool {
        get { appearance.enableSecondaryAccentUITints }
        set {
            appearance.enableSecondaryAccentUITints = newValue
            appearance.tintWindowWithWallpaper = newValue
            if !isHydratingPreferences {
                UserDefaults.standard.set(newValue, forKey: "krouton.pref.harmonyEnabled")
            }
        }
    }
    var tintWindowWithWallpaper: Bool {
        get { appearance.tintWindowWithWallpaper }
        set { appearance.tintWindowWithWallpaper = newValue }
    }
    var appearanceMode: KroutonRoastAppearanceMode {
        get { appearance.appearanceMode }
        set {
            appearance.appearanceMode = newValue
            if !isHydratingPreferences {
                UserDefaults.standard.set(newValue.rawValue, forKey: "krouton.pref.appearanceMode")
            }
        }
    }
    var selectedAccentIndex: Int {
        get { appearance.selectedAccentIndex }
        set {
            appearance.selectedAccentIndex = newValue
            if !isHydratingPreferences {
                UserDefaults.standard.set(newValue, forKey: "krouton.pref.selectedAccentIndex")
            }
        }
    }
    var iconWidgetStyle: KroutonGarnishStyleMode {
        get { appearance.iconWidgetStyle }
        set {
            appearance.iconWidgetStyle = newValue
            if !isHydratingPreferences {
                UserDefaults.standard.set(newValue.rawValue, forKey: "krouton.pref.iconWidgetStyle")
            }
        }
    }
    var folderColorMode: KroutonStageFolderColorMode {
        get { appearance.folderColorMode }
        set {
            appearance.folderColorMode = newValue
            if !isHydratingPreferences {
                UserDefaults.standard.set(newValue.rawValue, forKey: "krouton.pref.folderColorMode")
            }
        }
    }
    var sidebarIconSize: KroutonTrackIconSizeMode {
        get { appearance.sidebarIconSize }
        set {
            appearance.sidebarIconSize = newValue
            if !isHydratingPreferences {
                UserDefaults.standard.set(newValue.rawValue, forKey: "krouton.pref.sidebarIconSize")
            }
        }
    }
    var appLanguage: KroutonLanguage {
        get { appearance.appLanguage }
        set {
            appearance.appLanguage = newValue
            KroutonL10n.activeISOCode = newValue.isoCode
            if !isHydratingPreferences {
                UserDefaults.standard.set(newValue.rawValue, forKey: "krouton.pref.appLanguage")
            }
        }
    }
    var voiceOverSpokenTelemetry: Bool {
        get { appearance.voiceOverSpokenTelemetry }
        set { appearance.voiceOverSpokenTelemetry = newValue }
    }
    var a11yIncreaseContrast: Bool {
        get { appearance.a11yIncreaseContrast }
        set { appearance.a11yIncreaseContrast = newValue }
    }
    var a11yDifferentiateWithoutColor: Bool {
        get { appearance.a11yDifferentiateWithoutColor }
        set { appearance.a11yDifferentiateWithoutColor = newValue }
    }
    var a11yReduceMotion: Bool {
        get { appearance.a11yReduceMotion }
        set { appearance.a11yReduceMotion = newValue }
    }
    var rememberLastTaskOnLaunch: Bool {
        get { appearance.rememberLastTaskOnLaunch }
        set {
            appearance.rememberLastTaskOnLaunch = newValue
            if !isHydratingPreferences {
                UserDefaults.standard.set(newValue, forKey: "krouton.pref.rememberLastTask")
            }
        }
    }
    var useBase10Units: Bool {
        get { appearance.useBase10Units }
        set {
            appearance.useBase10Units = newValue
            if !isHydratingPreferences {
                UserDefaults.standard.set(newValue, forKey: "krouton.pref.useBase10Units")
            }
        }
    }

    // MARK: - Label Document Forwarding
    var selectedLabelTemplate: KroutonCroutonLabelStyle {
        get { label.selectedTemplate }
        set {
            label.selectedTemplate = newValue
            if !isHydratingPreferences {
                UserDefaults.standard.set(newValue.rawValue, forKey: "krouton.pref.labelTemplate")
            }
        }
    }
    var labelShowTracklistOnDisc: Bool { get { label.showTracklistOnDisc } set { label.showTracklistOnDisc = newValue } }
    var labelDiscTitle: String { get { label.discTitle } set { label.discTitle = newValue } }
    var labelSubtitle: String { get { label.subtitle } set { label.subtitle = newValue } }
    var autoLabelSearchQuery: String { get { label.autoSearchQuery } set { label.autoSearchQuery = newValue } }
    var labelBackgroundStyle: KroutonVectorBackgroundStyle { get { label.backgroundStyle } set { label.backgroundStyle = newValue } }
    var labelBgPrimaryColor: Color { get { label.bgPrimaryColor } set { label.bgPrimaryColor = newValue } }
    var labelBgSecondaryColor: Color { get { label.bgSecondaryColor } set { label.bgSecondaryColor = newValue } }
    var labelGradientAngle: Double { get { label.gradientAngle } set { label.gradientAngle = newValue } }
    var labelGradientMidpoint: Double { get { label.gradientMidpoint } set { label.gradientMidpoint = newValue } }
    var labelTopArcRadiusMM: Double { get { label.topArcRadiusMM } set { label.topArcRadiusMM = newValue } }
    var labelBottomArcRadiusMM: Double { get { label.bottomArcRadiusMM } set { label.bottomArcRadiusMM = newValue } }
    var labelArcLetterSpacing: Double { get { label.arcLetterSpacing } set { label.arcLetterSpacing = newValue } }
    var labelVectorShapes: [KroutonVectorShapeLayer] { get { label.vectorShapes } set { label.vectorShapes = newValue } }
    var labelGPUSeedPattern: KroutonGPUSeedPattern { get { label.gpuSeedPattern } set { label.gpuSeedPattern = newValue } }
    var labelKaleidoscopeFacets: Int { get { label.kaleidoscopeFacets } set { label.kaleidoscopeFacets = newValue } }
    var labelKaleidoscopeRig: KroutonKaleidoscopeMirrorRig { get { label.kaleidoscopeRig } set { label.kaleidoscopeRig = newValue } }
    var labelChamberTumble: Double { get { label.chamberTumble } set { label.chamberTumble = newValue } }
    var labelTinyPlanetRadius: Double { get { label.tinyPlanetRadius } set { label.tinyPlanetRadius = newValue } }
    var labelUseVisionForeground: Bool { get { label.useVisionForeground } set { label.useVisionForeground = newValue } }
    var labelTextElements: [KroutonLabelTextElement] { get { label.textElements } set { label.textElements = newValue } }
    var labelSelectedTextID: UUID? { get { label.selectedTextID } set { label.selectedTextID = newValue } }
    var labelBgAdjustments: KroutonBackgroundAdjustments { get { label.bgAdjustments } set { label.bgAdjustments = newValue } }
    var labelShowAlignmentGrid: Bool { get { label.showAlignmentGrid } set { label.showAlignmentGrid = newValue } }
    var labelCanvasZoom: Double { get { label.canvasZoom } set { label.canvasZoom = newValue } }
    var labelPresets: [KroutonDiscLabelGeometry] { get { label.presets } set { label.presets = newValue } }
    var selectedLabelPresetIndex: Int { get { label.selectedPresetIndex } set { label.selectedPresetIndex = newValue } }
    var defaultAutoLabelStyle: String { get { label.defaultAutoLabelStyle } set { label.defaultAutoLabelStyle = newValue } }
    var visionHoleAvoidance: Bool { get { label.visionHoleAvoidance } set { label.visionHoleAvoidance = newValue } }
    var customTMDBKey: String { get { label.customTMDBKey } set { label.customTMDBKey = newValue } }
    var customFanartKey: String { get { label.customFanartKey } set { label.customFanartKey = newValue } }

    // MARK: - Depot Catalogue Forwarding
    var depotChannels: [KroutonDepotFeedSubscription] { get { depot.channels } set { depot.channels = newValue } }
    var depotItems: [KroutonDepotCatalogItem] { get { depot.items } set { depot.items = newValue } }
    var customDepotFeedURL: String { get { depot.customFeedURL } set { depot.customFeedURL = newValue } }
    var autoVerifyDepotSHA256: Bool { get { depot.autoVerifySHA256 } set { depot.autoVerifySHA256 = newValue } }
    var enableVMTestBootInDepot: Bool { get { depot.enableVMTestBoot } set { depot.enableVMTestBoot = newValue } }
    var stagedDepotItemID: String? { get { depot.stagedItemID } set { depot.stagedItemID = newValue } }
    var selectedDepotHeroItemID: String? { get { depot.selectedHeroItemID } set { depot.selectedHeroItemID = newValue } }
    var depotDownloadProgress: [String: Double] { get { depot.downloadProgress } set { depot.downloadProgress = newValue } }
    var isSearchingInternetArchive: Bool { get { depot.isSearchingInternetArchive } set { depot.isSearchingInternetArchive = newValue } }
    var archiveOrgLiveCount: Int { get { depot.archiveOrgLiveCount } set { depot.archiveOrgLiveCount = newValue } }

    // MARK: - Rip & Transcode Settings Forwarding
    var defaultCrossfadeSec: Double { get { rip.defaultCrossfadeSec } set { rip.defaultCrossfadeSec = newValue } }
    var autoBeatmatchSoundAnalysis: Bool { get { rip.autoBeatmatchSoundAnalysis } set { rip.autoBeatmatchSoundAnalysis = newValue } }
    var carSafeMP3Mode: Bool { get { rip.carSafeMP3Mode } set { rip.carSafeMP3Mode = newValue } }
    var singleVideoFirstPlay: Bool { get { rip.singleVideoFirstPlay } set { rip.singleVideoFirstPlay = newValue } }
    var fitToDiscPreserveMenus: Bool { get { rip.fitToDiscPreserveMenus } set { rip.fitToDiscPreserveMenus = newValue } }
    var fitToDiscStripForeignDubs: Bool { get { rip.fitToDiscStripForeignDubs } set { rip.fitToDiscStripForeignDubs = newValue } }
    var videoToolboxTwoPassVBR: Bool { get { rip.videoToolboxTwoPassVBR } set { rip.videoToolboxTwoPassVBR = newValue } }
    var driveReadOffsetSamples: Int { get { rip.driveReadOffsetSamples } set { rip.driveReadOffsetSamples = newValue } }
    var paranoiaErrorRetries: Int { get { rip.paranoiaErrorRetries } set { rip.paranoiaErrorRetries = newValue } }
    var verifyAccurateRip: Bool { get { rip.verifyAccurateRip } set { rip.verifyAccurateRip = newValue } }
    var writeCueSheetLog: Bool { get { rip.writeCueSheetLog } set { rip.writeCueSheetLog = newValue } }
    var hardwareDeinterlaceVideo: Bool { get { rip.hardwareDeinterlaceVideo } set { rip.hardwareDeinterlaceVideo = newValue } }
    var passthroughAtmosTrueHD: Bool { get { rip.passthroughAtmosTrueHD } set { rip.passthroughAtmosTrueHD = newValue } }
    var namingTokens: [String] { get { rip.namingTokens } set { rip.namingTokens = newValue } }
    var enableNetworkServerSharing: Bool { get { rip.enableNetworkServerSharing } set { rip.enableNetworkServerSharing = newValue } }
    var serverRingBufferMB: Double { get { rip.serverRingBufferMB } set { rip.serverRingBufferMB = newValue } }
    var preStageImageToServerSSD: Bool { get { rip.preStageImageToServerSSD } set { rip.preStageImageToServerSSD = newValue } }
    var forceDVDROMBookType: Bool { get { rip.forceDVDROMBookType } set { rip.forceDVDROMBookType = newValue } }
    var disableBDDefectManagementForVideo: Bool { get { rip.disableBDDefectManagementForVideo } set { rip.disableBDDefectManagementForVideo = newValue } }
    var namingPreviewString: String { rip.namingPreviewString }
}
