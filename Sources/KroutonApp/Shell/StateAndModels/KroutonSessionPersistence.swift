import AudioKit
import DriveKit
import Foundation
import Observation
import OpticalCore
import Persistence
import SwiftUI

// MARK: - KroutonSessionPersistence

struct KroutonPersistedSessionSnapshot: Codable, Sendable, Equatable {
    var selectedCategoryRaw: String
    var selectedTaskID: String
    var discVolumeTitle: String
    var discPerformer: String
    var discMCNBarcode: String
    var stagedFilePaths: [String]
    var fileReferences: [FileReference]
    var audioProject: AudioProject
    var destinationQueue: [KroutonBakeBatchItem]
    var savedAtISO8601: String

    init(
        selectedCategoryRaw: String,
        selectedTaskID: String,
        discVolumeTitle: String,
        discPerformer: String,
        discMCNBarcode: String,
        stagedFilePaths: [String],
        fileReferences: [FileReference] = [],
        audioProject: AudioProject = AudioProject(),
        destinationQueue: [KroutonBakeBatchItem],
        savedAtISO8601: String = ISO8601DateFormatter().string(from: Date())
    ) {
        self.selectedCategoryRaw = selectedCategoryRaw
        self.selectedTaskID = selectedTaskID
        self.discVolumeTitle = discVolumeTitle
        self.discPerformer = discPerformer
        self.discMCNBarcode = discMCNBarcode
        self.stagedFilePaths = stagedFilePaths
        self.fileReferences = fileReferences
        self.audioProject = audioProject
        self.destinationQueue = destinationQueue
        self.savedAtISO8601 = savedAtISO8601
    }
}

@Observable
@MainActor
final class KroutonCrashRecoveryController {
    static let shared = KroutonCrashRecoveryController()

    private let sessionDirectory: URL = {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSTemporaryDirectory())
        return base.appendingPathComponent("Krouton/Session", isDirectory: true)
    }()

    private var runLock: RunLock?
    @ObservationIgnored private lazy var sessionStore = SessionStore<KroutonPersistedSessionSnapshot>(
        directory: sessionDirectory,
        schemaVersion: 3
    )
    @ObservationIgnored public lazy var burnJournal = BurnJournal(directory: sessionDirectory)

    private var didEvaluateLaunch: Bool = false

    var showCrashRecoveryPrompt: Bool = false
    var crashReasonText: String = ""
    var pendingSnapshot: KroutonPersistedSessionSnapshot? = nil
    var missingStagedFilePaths: [String] = []
    var interruptedBurns: [BurnJournalRecord] = []

    private init() {
        NotificationCenter.default.addObserver(
            forName: KroutonOSDesktopBridge.didResignActiveNotification,
            object: nil,
            queue: .main
        ) { _ in
            Task { @MainActor in
                KroutonCrashRecoveryController.shared.saveCurrentState(from: KroutonWindowManager.shared.store)
                await KroutonCrashRecoveryController.shared.flushNow()
            }
        }
        atexit {
            // Mark clean exit in the flock() RunMarker when process exits normally
            let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
                ?? URL(fileURLWithPath: NSTemporaryDirectory())
            let lockPath = base.appendingPathComponent("Krouton/Session/run.lock").path
            let fd = open(lockPath, O_WRONLY)
            if fd >= 0 {
                _ = ftruncate(fd, 0)
                _ = fsync(fd)
                close(fd)
            }
        }
    }

    func evaluateLaunchStateAndHydrateIfClean(store: KroutonStateStore) {
        guard !didEvaluateLaunch else { return }
        didEvaluateLaunch = true

        if !KroutonPreferences.has(.rememberLastTask) {
            KroutonPreferences.set(true, for: .rememberLastTask)
        }
        let rememberEnabled = KroutonPreferences.bool(for: .rememberLastTask, default: true)
        if store.rememberLastTaskOnLaunch != rememberEnabled {
            store.rememberLastTaskOnLaunch = rememberEnabled
        }

        let acquired = try? RunLock.acquire(in: sessionDirectory)
        self.runLock = acquired?.lock
        let verdict = acquired?.verdict ?? .clean

        Task { @MainActor in
            let loaded = await sessionStore.load()
            var loadedSnap: KroutonPersistedSessionSnapshot? = nil
            if case .loaded(let payload, _, _) = loaded {
                loadedSnap = payload
            }

            let decision = restoreDecision(
                verdict: verdict,
                hasSnapshot: loadedSnap != nil,
                rememberSession: store.rememberLastTaskOnLaunch
            )

            switch decision {
            case .startFresh:
                runLock?.markRunning()
            case .restoreSilently:
                if let snap = loadedSnap {
                    await applySnapshotAsync(snap, to: store)
                }
                runLock?.markRunning()
            case .askFirst(let reason):
                pendingSnapshot = loadedSnap
                crashReasonText = (reason == .diedWhileRestoring)
                    ? "Krouton exited while restoring the previous session."
                    : "Krouton detected repeated unexpected exits."
                showCrashRecoveryPrompt = true
            }

            let unfinished = await burnJournal.interruptedJobs()
            if !unfinished.isEmpty {
                interruptedBurns = unfinished
            }

            try? await Task.sleep(for: .seconds(30))
            runLock?.markStable()
        }
    }

    func saveCurrentState(from store: KroutonStateStore) {
        guard store.rememberLastTaskOnLaunch, !showCrashRecoveryPrompt else { return }
        let paths = store.stagedFiles.map { $0.url.path }
        let refs = store.stagedFiles.map { FileReference(url: $0.url) }
        let snap = KroutonPersistedSessionSnapshot(
            selectedCategoryRaw: store.selectedCategory.rawValue,
            selectedTaskID: store.selectedTaskID,
            discVolumeTitle: store.discVolumeTitle,
            discPerformer: store.discPerformer,
            discMCNBarcode: store.discMCNBarcode,
            stagedFilePaths: paths,
            fileReferences: refs,
            audioProject: store.audioController.project,
            destinationQueue: store.destinationQueue
        )
        Task {
            await sessionStore.scheduleSave(snap)
        }
    }

    func flushNow() async {
        await sessionStore.flush()
    }

    func startEmptySession(store: KroutonStateStore) {
        showCrashRecoveryPrompt = false
        pendingSnapshot = nil
        missingStagedFilePaths.removeAll()
        store.stagedFiles.removeAll()
        store.audioController.clearAll()
        store.discVolumeTitle = ""
        store.selectedCategory = .burn
        store.selectedTaskID = "data-hybrid"
        runLock?.markRunning()
        runLock?.markStable()
        Task {
            await sessionStore.discard()
        }
    }

    func restoreCrashedSession(store: KroutonStateStore) {
        showCrashRecoveryPrompt = false
        let snap = pendingSnapshot
        pendingSnapshot = nil
        Task { @MainActor in
            if let snap {
                await applySnapshotAsync(snap, to: store)
            }
            runLock?.markRunning()
        }
    }

    func acknowledgeInterruptedBurns() {
        let jobs = interruptedBurns
        interruptedBurns.removeAll()
        Task {
            try? await burnJournal.acknowledge(jobs)
        }
    }

    func simulateUncleanCrashFlagForTesting(store: KroutonStateStore) {
        let paths = store.stagedFiles.map { $0.url.path }
        let refs = store.stagedFiles.map { FileReference(url: $0.url) }
        pendingSnapshot = KroutonPersistedSessionSnapshot(
            selectedCategoryRaw: store.selectedCategory.rawValue,
            selectedTaskID: store.selectedTaskID,
            discVolumeTitle: store.discVolumeTitle,
            discPerformer: store.discPerformer,
            discMCNBarcode: store.discMCNBarcode,
            stagedFilePaths: paths,
            fileReferences: refs,
            audioProject: store.audioController.project,
            destinationQueue: store.destinationQueue
        )
        crashReasonText = "Simulated crash-loop recovery prompt (RunLock + SessionStore)."
        showCrashRecoveryPrompt = true
    }

    private func applySnapshotAsync(_ snap: KroutonPersistedSessionSnapshot, to store: KroutonStateStore) async {
        if let cat = KroutonMasteringStation(rawValue: snap.selectedCategoryRaw) {
            store.selectedCategory = cat
        }
        store.selectedTaskID = snap.selectedTaskID
        store.discVolumeTitle = (snap.discVolumeTitle == "KROUTON_VIDEO" || snap.discVolumeTitle == "KROUTON_DISC") ? "" : snap.discVolumeTitle
        store.discPerformer = snap.discPerformer
        store.discMCNBarcode = snap.discMCNBarcode
        if !snap.destinationQueue.isEmpty {
            store.destinationQueue = snap.destinationQueue.map { $0.repairingLegacyPresets() }
        }
        store.audioController.restore(snap.audioProject)

        let refs: [FileReference] = !snap.fileReferences.isEmpty
            ? snap.fileReferences
            : snap.stagedFilePaths.map { FileReference(url: URL(fileURLWithPath: $0)) }

        let resolutions = await sessionStore.resolve(refs, timeoutPerFile: 2.0)
        var restoredEntries: [KroutonStagedFileEntry] = []
        var missingPaths: [String] = []

        for res in resolutions {
            switch res {
            case .found(let url):
                restoredEntries.append(KroutonOpticalDriveBank.inspectFileOrFolder(url: url))
            case .missing(let path):
                missingPaths.append(path)
            }
        }
        if !restoredEntries.isEmpty {
            store.stagedFiles = restoredEntries
        }
        missingStagedFilePaths = missingPaths
    }
}

struct KroutonCrashRecoveryBannerView: View {
    var store: KroutonStateStore
    var recovery = KroutonCrashRecoveryController.shared

    init(store: KroutonStateStore) {
        self.store = store
    }

    var body: some View {
        VStack(spacing: 0) {
            if recovery.showCrashRecoveryPrompt {
                HStack(spacing: 12) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(.orange)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(KroutonL10n.tr("Unexpected Shutdown Detected"))
                            .font(.system(size: 12, weight: .bold))
                        Text(recovery.crashReasonText.isEmpty
                             ? KroutonL10n.tr("Would you like to restore your previous session or start with an empty workspace?")
                             : recovery.crashReasonText)
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button {
                        recovery.restoreCrashedSession(store: store)
                    } label: {
                        Label(KroutonL10n.tr("Restore Session"), systemImage: "arrow.counterclockwise.circle.fill")
                            .font(.system(size: 11, weight: .bold))
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.orange)
                    .controlSize(.small)

                    Button(role: .destructive) {
                        recovery.startEmptySession(store: store)
                    } label: {
                        Label(KroutonL10n.tr("Start Empty"), systemImage: "trash.slash.fill")
                            .font(.system(size: 11, weight: .bold))
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(Color.orange.opacity(0.14))
                .overlay(Rectangle().fill(Color.orange.opacity(0.45)).frame(height: 1), alignment: .bottom)
            }

            if !recovery.missingStagedFilePaths.isEmpty {
                HStack(spacing: 10) {
                    Image(systemName: "folder.badge.questionmark")
                        .foregroundStyle(.yellow)
                    Text("Missing staged file(s) from saved session: \(recovery.missingStagedFilePaths.map { URL(fileURLWithPath: $0).lastPathComponent }.joined(separator: ", "))")
                        .font(.system(size: 11, weight: .medium))
                    Spacer()
                    Button(KroutonL10n.tr("Dismiss")) {
                        recovery.missingStagedFilePaths.removeAll()
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.mini)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 6)
                .background(Color.yellow.opacity(0.12))
            }

            if let unfinished = recovery.interruptedBurns.first {
                HStack(spacing: 10) {
                    Image(systemName: "opticaldisc.fill")
                        .foregroundStyle(.red)
                    Text("Interrupted burn detected on \(unfinished.deviceName) for '\(unfinished.projectTitle)' (phase: \(unfinished.phase.rawValue)) — that disc is likely unusable.")
                        .font(.system(size: 11, weight: .semibold))
                    Spacer()
                    Button(KroutonL10n.tr("Acknowledge")) {
                        recovery.acknowledgeInterruptedBurns()
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.mini)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 6)
                .background(Color.red.opacity(0.14))
            }
        }
    }
}
