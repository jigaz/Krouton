import AudioKit
import Combine
import Foundation
import ImageKit
import LabelKit
import OpticalCore
import RescueKit
import SwiftUI
import VideoKit

@MainActor
final class KroutonStateStore: ObservableObject {
    // MARK: - Modular Feature Sub-Stores & Domain Models
    let labelWorkspaceSubStore = KroutonLabelWorkspaceSubStore()
    let discImageInspectorSubStore = KroutonDiscImageInspectorSubStore()
    let burnQueueSubStore = KroutonBurnQueueSubStore()
    let depotCatalogSubStore = KroutonDepotCatalogSubStore()

    @Published var appearance = AppearancePreferences()
    @Published var depot = DepotCatalogue()
    @Published var label = LabelDocument()
    @Published var rip = RipSettings()

    public static weak var shared: KroutonStateStore?
    var isHydratingPreferences: Bool = false

    // MARK: - Core Navigation, Staging & Burn Queue State
    var savedQueuesByDomain: [String: [KroutonBakeBatchItem]] = [:]
    @Published var scratchDiskPath: String = "~/Library/Caches/app.krouton.staging"
    @Published var autoPurgeScratch: Bool = true
    @Published var selectedSettingsPane: KroutonSettingsCategory = .general
    @Published var selectedCategory: KroutonMasteringStation = .burn {
        didSet {
            guard !isHydratingPreferences, rememberLastTaskOnLaunch else { return }
            UserDefaults.standard.set(selectedCategory.rawValue, forKey: "krouton.pref.lastCategory")
        }
    }
    @Published var selectedTaskID: String = "data-hybrid" {
        didSet {
            guard !isHydratingPreferences, rememberLastTaskOnLaunch else { return }
            UserDefaults.standard.set(selectedTaskID, forKey: "krouton.pref.lastTaskID")
            KroutonCrashRecoveryController.shared.saveCurrentState(from: self)
        }
    }
    @Published var bitsetVendorProfile: String = "Auto-Detect (MMC 0xFA / Pioneer / Lite-On / LG)"
    @Published var autoLoadNextDiscBatchMode: Bool = true
    @Published var autoLoadCountdownSeconds: Int = 5

    @Published var stagedFiles: [KroutonStagedFileEntry] = []
    @Published var rejectedDropNotice: String? = nil

    lazy var audioController = AudioProjectController { [weak self] _ in
        guard let self else { return }
        KroutonCrashRecoveryController.shared.saveCurrentState(from: self)
    }

    var redBookTracks: [KroutonRedBookTrack] {
        get { audioController.project.derivedRedBookCubes }
        set { }
    }

    @Published var discPerformer: String = ""
    @Published var discMCNBarcode: String = ""
    @Published var carSafeZeroPadPrefix: Bool = true
    @Published var carSafeStripAppleDouble: Bool = true
    @Published var carSafeGenerateM3U: Bool = true
    @Published var includeUDFBridge: Bool = true
    @Published var includeJolietNames: Bool = true
    @Published var allowATIPOverburn: Bool = false
    @Published var dualLayerBreakSectorLBA: Int64 = 2_086_912
    @Published var discVolumeTitle: String = ""
    @Published var dataTargetDiscMedium: KroutonSpanningDiscMedium = .dvd5Single
    @Published var targetDiscMediumByTask: [String: KroutonSpanningDiscMedium] = [:]
    @Published var dataDiscVolumeOverrides: [Int: String] = [:]
    @Published var finderLayoutBlueprint = KroutonFinderLayoutBlueprint()
    @Published var discFormats: [KroutonOpticalWorkflowSpec] = KroutonOpticalWorkflowCatalog.defaultFormats

    @Published var notificationMatrix: [KroutonKitchenEventRow] = [
        KroutonKitchenEventRow(id: "start", eventTitle: "Burn, rip, or transcode started", eventSubtitle: "Triggered when laser calibration or extraction begins", bannerEnabled: true, iPhoneEnabled: true, watchEnabled: false, soundEnabled: false),
        KroutonKitchenEventRow(id: "done", eventTitle: "Task completed & verified", eventSubtitle: "Triggered when all queued destinations finish without error", bannerEnabled: true, iPhoneEnabled: true, watchEnabled: true, soundEnabled: true),
        KroutonKitchenEventRow(id: "err", eventTitle: "Task failed or buffer underrun", eventSubtitle: "Critical hardware, media, or network link interruption", bannerEnabled: true, iPhoneEnabled: true, watchEnabled: true, soundEnabled: true),
        KroutonKitchenEventRow(id: "layer", eventTitle: "Dual-layer (L0 -> L1) break reached", eventSubtitle: "DVD-9 or BD-50 seamless layer transition point", bannerEnabled: true, iPhoneEnabled: false, watchEnabled: true, soundEnabled: false),
        KroutonKitchenEventRow(id: "swap", eventTitle: "Blank disc or tray swap required", eventSubtitle: "Multi-disc queue waiting for operator", bannerEnabled: true, iPhoneEnabled: true, watchEnabled: true, soundEnabled: true),
        KroutonKitchenEventRow(id: "depot", eventTitle: "Disc Image Depot download verified", eventSubtitle: "ISO / image downloaded and SHA-256 verified", bannerEnabled: true, iPhoneEnabled: false, watchEnabled: false, soundEnabled: true)
    ]

    @Published var destinationQueue: [KroutonBakeBatchItem] = [
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
    func refreshOpticalDrives() { KroutonWindowManager.shared.driveManager.refreshDrives() }
    func ejectActiveOpticalDisc() { KroutonWindowManager.shared.driveManager.ejectDrive(id: KroutonWindowManager.shared.driveManager.availableDrives.first?.id) }

    func multicolorPresetID(forTaskID taskID: String, category: KroutonMasteringStation) -> Int {
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

    func effectiveColorForTask(id taskID: String, category: KroutonMasteringStation) -> Color {
        if selectedAccentIndex == -1 {
            let pid = multicolorPresetID(forTaskID: taskID, category: category)
            let p = KroutonAccentColorPreset.allPresets.first(where: { $0.id == pid }) ?? resolvedAccentPreset
            return p.effectiveAccent(for: appearance.effectiveColorScheme)
        }
        return activeAccent
    }

    var activeAccent: Color {
        resolvedAccentPreset.effectiveAccent(for: appearance.effectiveColorScheme)
    }

    var activeOnAccentText: Color {
        resolvedAccentPreset.effectiveOnAccentText(for: appearance.effectiveColorScheme)
    }

    var activeLocale: Locale { appearance.activeLocale }
    var totalStagedBytes: Int64 { stagedFiles.reduce(0) { $0 + $1.byteSize } }
    var totalStagedSectorsLBA: Int64 { stagedFiles.reduce(0) { $0 + $1.sectorsLBA } }

    init() {
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
