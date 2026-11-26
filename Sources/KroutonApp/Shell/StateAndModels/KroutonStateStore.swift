import AudioKit
import Foundation
import ImageKit
import LabelKit
import Observation
import OpticalCore
import RescueKit
import SwiftUI
import VideoKit

@Observable
@MainActor
@dynamicMemberLookup
final class KroutonStateStore {
    // MARK: - Modular Feature Sub-Stores & Domain Models
    let labelWorkspaceSubStore = KroutonLabelWorkspaceSubStore()
    let burnQueueSubStore = KroutonBurnQueueSubStore()

    let appearance = AppearancePreferences()
    let depot = DepotCatalogue()
    let label = LabelDocument()
    let rip = RipSettings()
    let rescue = KroutonRescueController()
    let avchd = KroutonAVCHDController()

    static weak var shared: KroutonStateStore?
    var isHydratingPreferences: Bool = false

    // MARK: - Core Navigation, Staging & Burn Queue State
    var savedQueuesByDomain: [String: [KroutonBakeBatchItem]] = [:]
    var scratchDiskPath: String = "~/Library/Caches/app.krouton.staging"
    var autoPurgeScratch: Bool = true
    var selectedSettingsPane: KroutonSettingsCategory = .general
    var selectedCategory: KroutonMasteringStation = .burn {
        didSet {
            guard !isHydratingPreferences, self.rememberLastTaskOnLaunch else { return }
            KroutonPreferences.set(selectedCategory.rawValue, for: .lastCategory)
        }
    }
    var selectedTaskID: String = KroutonFormatID.dataHybrid.rawValue {
        didSet {
            guard !isHydratingPreferences, self.rememberLastTaskOnLaunch else { return }
            KroutonPreferences.set(selectedTaskID, for: .lastTaskID)
            KroutonCrashRecoveryController.shared.saveCurrentState(from: self)
        }
    }
    var selectedFormatID: KroutonFormatID? { KroutonFormatID(rawValue: selectedTaskID) }
    var selectedCopyTaskID: KroutonCopyTaskID? { KroutonCopyTaskID(rawValue: selectedTaskID) }
    var bitsetVendorProfile: String = "Auto-Detect (MMC 0xFA / Pioneer / Lite-On / LG)"
    var autoLoadNextDiscBatchMode: Bool = true
    var autoLoadCountdownSeconds: Int = 5

    var stagedFiles: [KroutonStagedFileEntry] = []
    var rejectedDropNotice: String? = nil

    @ObservationIgnored lazy var audioController = AudioProjectController { [weak self] _ in
        guard let self else { return }
        KroutonCrashRecoveryController.shared.saveCurrentState(from: self)
    }

    var redBookTracks: [KroutonRedBookTrack] {
        get { audioController.project.derivedRedBookCubes }
        set { }
    }

    var discPerformer: String = ""
    var discMCNBarcode: String = ""
    var carSafeZeroPadPrefix: Bool = true
    var carSafeStripAppleDouble: Bool = true
    var carSafeGenerateM3U: Bool = true
    var includeUDFBridge: Bool = true
    var includeJolietNames: Bool = true
    var allowATIPOverburn: Bool = false
    var dualLayerBreakSectorLBA: Int64 = 2_086_912
    var enableCustomFinderLayoutTab: Bool = false
    var finderIconSize: Double = 256
    var fitToDiscDVD9Shrink: Bool = true
    var preserveMenusAndExtras: Bool = true
    var cdTextAlbumTitle: String = ""
    var cdTextAlbumPerformer: String = ""
    var discVolumeTitle: String = ""
    var dataTargetDiscMedium: KroutonSpanningDiscMedium = .dvd5Single
    var targetDiscMediumByTask: [String: KroutonSpanningDiscMedium] = [:]
    var dataDiscVolumeOverrides: [Int: String] = [:]
    var finderLayoutBlueprint = KroutonFinderLayoutBlueprint()
    var discFormats: [KroutonOpticalWorkflowSpec] = KroutonOpticalWorkflowCatalog.defaultFormats

    var notificationMatrix: [KroutonKitchenEventRow] = [
        KroutonKitchenEventRow(id: "start", eventTitle: "Burn, rip, or transcode started", eventSubtitle: "Triggered when laser calibration or extraction begins", bannerEnabled: true, iPhoneEnabled: true, watchEnabled: false, soundEnabled: false),
        KroutonKitchenEventRow(id: "done", eventTitle: "Task completed & verified", eventSubtitle: "Triggered when all queued destinations finish without error", bannerEnabled: true, iPhoneEnabled: true, watchEnabled: true, soundEnabled: true),
        KroutonKitchenEventRow(id: "err", eventTitle: "Task failed or buffer underrun", eventSubtitle: "Critical hardware, media, or network link interruption", bannerEnabled: true, iPhoneEnabled: true, watchEnabled: true, soundEnabled: true),
        KroutonKitchenEventRow(id: "layer", eventTitle: "Dual-layer (L0 -> L1) break reached", eventSubtitle: "DVD-9 or BD-50 seamless layer transition point", bannerEnabled: true, iPhoneEnabled: false, watchEnabled: true, soundEnabled: false),
        KroutonKitchenEventRow(id: "swap", eventTitle: "Blank disc or tray swap required", eventSubtitle: "Multi-disc queue waiting for operator", bannerEnabled: true, iPhoneEnabled: true, watchEnabled: true, soundEnabled: true),
        KroutonKitchenEventRow(id: "depot", eventTitle: "Disc Image Depot download verified", eventSubtitle: "ISO / image downloaded and SHA-256 verified", bannerEnabled: true, iPhoneEnabled: false, watchEnabled: false, soundEnabled: true)
    ]

    var poolDispatchMode: KroutonPoolDispatchMode = .autoAssign
    var poolTotalCopies: Int = 1
    var waitingBurnPool: [KroutonPoolBurnTicket] = []
    var completedPoolTicketCount: Int = 0

    var destinationQueue: [KroutonBakeBatchItem] = [
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
        if self.selectedAccentIndex == -1 {
            let targetID = multicolorPresetID(forTaskID: selectedTaskID, category: selectedCategory)
            return KroutonAccentColorPreset.allPresets.first(where: { $0.id == targetID }) ?? KroutonAccentColorPreset.allPresets[1]
        }
        return KroutonAccentColorPreset.allPresets.first(where: { $0.id == self.selectedAccentIndex })
            ?? KroutonAccentColorPreset.allPresets.first(where: { $0.id == 8 })
            ?? KroutonAccentColorPreset.allPresets[0]
    }

    func effectiveColorForTask(id taskID: String, category: KroutonMasteringStation) -> Color {
        if self.selectedAccentIndex == -1 {
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
        appearance.load()
        if let rawTpl = KroutonPreferences.string(for: .labelTemplate),
           let tpl = KroutonCroutonLabelStyle(rawValue: rawTpl) {
            label.selectedLabelTemplate = tpl
        }
        if appearance.rememberLastTaskOnLaunch {
            if let rawCat = KroutonPreferences.string(for: .lastCategory),
               let cat = KroutonMasteringStation(rawValue: rawCat) {
                selectedCategory = cat
            }
            if let lastTask = KroutonPreferences.string(for: .lastTaskID), !lastTask.isEmpty {
                selectedTaskID = lastTask
            }
        }
    }
}
