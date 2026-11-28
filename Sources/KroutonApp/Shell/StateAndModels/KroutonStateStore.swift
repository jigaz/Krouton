import AudioKit
import Foundation
import ImageKit
import Observation
import OpticalCore
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
    var autoLoadNextDiscBatchMode: Bool = true
    var autoLoadCountdownSeconds: Int = 5

    var stagedFiles: [KroutonStagedFileEntry] = []
    /// CD-Extra: the files for the data session after the audio (the tracks are the Audio CD
    /// editor's project, as on an audio CD).
    var cdExtraDataFiles: [KroutonStagedFileEntry] = []
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
    var dualLayerBreakSectorLBA: Int64 = 2_086_912
    var enableCustomFinderLayoutTab: Bool = false
    var fitToDiscDVD9Shrink: Bool = true
    var preserveMenusAndExtras: Bool = true
    var cdTextAlbumTitle: String = ""
    var cdTextAlbumPerformer: String = ""
    var discVolumeTitle: String = ""
    /// The MP3 CD workspace's switches; `burnInputFiles()` applies them before every MP3 CD burn.
    var carAudioOptions = KroutonCarAudioOptions()
    /// M-DISC recovery data as a percentage of the files (0 = none); see `burnInputFiles()`.
    var mdiscParityPercent: Double = 10
    var targetDiscMediumByTask: [String: KroutonSpanningDiscMedium] = [:]
    var dataDiscVolumeOverrides: [Int: String] = [:]
    var finderLayoutBlueprint = KroutonFinderLayoutBlueprint()
    var discFormats: [KroutonOpticalWorkflowSpec] = KroutonOpticalWorkflowCatalog.defaultFormats

    var notificationMatrix: [KroutonKitchenEventRow] = KroutonStateStore.defaultNotificationMatrix {
        didSet { if !isHydratingPreferences { KroutonPreferences.saveNotificationEvents(notificationMatrix) } }
    }
    /// Each drive's notifications sound at its own pitch (Settings › Notifications).
    var distinctDriveVoices: Bool = true {
        didSet { if !isHydratingPreferences { KroutonPreferences.set(distinctDriveVoices, for: .distinctDriveVoices) } }
    }
    /// Auto-Label tidies raw titles with the on-device model (Settings › Labels & Printers).
    var labelSuggestionsEnabled: Bool = true {
        didSet { if !isHydratingPreferences { KroutonPreferences.set(labelSuggestionsEnabled, for: .labelSuggestions) } }
    }
    /// When the menu bar shows Krouton's progress (Settings › Notifications).
    var menuBarStatusMode: KroutonLiveStatus.MenuBarMode = .whileWorking {
        didSet { if !isHydratingPreferences { KroutonPreferences.set(menuBarStatusMode.rawValue, for: .menuBarStatus) } }
    }

    var poolDispatchMode: KroutonPoolDispatchMode = .autoAssign
    var poolTotalCopies: Int = 1
    var waitingBurnPool: [KroutonPoolBurnTicket] = []
    var completedPoolTicketCount: Int = 0

    var destinationQueue: [KroutonBakeBatchItem] = KroutonStateStore.defaultDestinationQueue

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
        KroutonCloudSettings.start(store: self)
    }

    func hydratePreferencesFromUserDefaults() {
        isHydratingPreferences = true
        defer { isHydratingPreferences = false }
        appearance.load()
        notificationMatrix = KroutonPreferences.notificationEvents(defaults: Self.defaultNotificationMatrix)
        distinctDriveVoices = KroutonPreferences.bool(for: .distinctDriveVoices, default: true)
        labelSuggestionsEnabled = KroutonPreferences.bool(for: .labelSuggestions, default: true)
        label.labelPresets = LabelDocument.savedLabelPresets()
        label.selectedLabelPresetIndex = min(label.selectedLabelPresetIndex, max(0, label.labelPresets.count - 1))
        menuBarStatusMode = KroutonPreferences.string(for: .menuBarStatus).flatMap(KroutonLiveStatus.MenuBarMode.init(rawValue:)) ?? .whileWorking
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
