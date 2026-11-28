import BurnKit
import Foundation
import Observation
import OpticalCore
import SwiftUI

// MARK: - Multi-Disc Set Controller

/// Runs a multi-disc set for the Burn as Multi-Disc Set window (`KroutonBurnSetSheetView`):
/// plan, stage and freeze the files, run `BurnSetScheduler` on every connected burner, and show
/// each disc's status. Everything shown is derived from the scheduler's events, which are
/// journalled first, so a set survives a quit and resumes with its finished discs still finished.
@Observable
@MainActor
final class KroutonBurnSetController {
    static let shared = KroutonBurnSetController()

    enum Phase: Equatable {
        case idle
        case preparing
        case running
        case finished
    }

    enum DiscStatus: Equatable {
        case pending
        case active(String)
        case done
        case failed(String)
    }

    struct DiscRow: Identifiable, Equatable {
        let id: Int
        let volumeLabel: String
        let imageBytes: Int64
        var status: DiscStatus
    }

    struct DriveRow: Identifiable, Equatable {
        let id: String
        let name: String
        var message: String
    }

    private(set) var phase: Phase = .idle
    private(set) var setTitle = ""
    private(set) var discs: [DiscRow] = []
    private(set) var drives: [DriveRow] = []
    private(set) var notice: String?
    private(set) var isStopping = false
    /// An unfinished set found in the journal whose images are still on disk.
    private(set) var resumable: BurnSetProgress?

    var isBusy: Bool { phase == .preparing || phase == .running }
    var hasUnfinishedDiscs: Bool { progress.map { !$0.isComplete } ?? false }

    private let journal: BurnEventJournal
    private let stagingRoot: URL
    private var progress: BurnSetProgress?
    private var connected: [DiscRecordingOpticalDrive] = []
    private var workTask: Task<Void, Never>?

    init(
        journalDirectory: URL = KroutonDomainIdentity.applicationSupportRootDirectory().appendingPathComponent("BurnSets", isDirectory: true),
        stagingRoot: URL = KroutonDomainIdentity.ephemeralBurnCacheDirectory().appendingPathComponent("BurnSets", isDirectory: true)
    ) {
        self.journal = BurnEventJournal(directory: journalDirectory)
        self.stagingRoot = stagingRoot
    }

    // MARK: - Starting

    /// Plans the staged items across discs of `discCapacityBytes`, builds one image per disc,
    /// then burns them on every connected burner.
    func start(title: String, entries: [KroutonStagedFileEntry], discCapacityBytes: Int64) {
        guard !isBusy else { return }
        let cleanTitle = title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "KROUTON_SET" : title
        setTitle = cleanTitle
        discs = []
        drives = []
        notice = nil
        resumable = nil
        progress = nil
        phase = .preparing

        let inputs = entries.map { (url: $0.url, name: $0.name) }
        let root = stagingRoot
        let setID = BurnSetID()
        let journal = journal
        workTask = Task { [weak self] in
            do {
                // Walking folders, copying, hashing and running hdiutil all block; keep them off the main actor.
                let burnSet = try await Task.detached(priority: .userInitiated) { () -> BurnSet in
                    let files = try BurnSetPlanner.expand(inputs)
                    let plan = try BurnSetPlanner.plan(files, discCapacityBytes: discCapacityBytes)
                    let staged = try BurnSetStager.freezeAndStageSet(
                        setID: setID, title: cleanTitle, discs: plan, stagingRootDirectory: root
                    )
                    if let oversize = staged.burnSet.discs.first(where: { $0.imageBytes > discCapacityBytes }) {
                        throw BurnSetPlanError.imageExceedsDisc(
                            discIndex: oversize.index, imageBytes: oversize.imageBytes, capacityBytes: discCapacityBytes
                        )
                    }
                    return staged.burnSet
                }.value
                try await journal.append(.setCreated(burnSet))
                await self?.run(BurnSetProgress(set: burnSet))
            } catch {
                Self.removeStagedSet(setID, under: root)
                self?.notice = error.localizedDescription
                self?.phase = .finished
            }
        }
    }

    /// Burns the discs of the current set that are still pending or failed.
    func burnRemainingDiscs() {
        guard phase == .finished, let progress, !progress.isComplete else { return }
        workTask = Task { [weak self] in await self?.run(progress) }
    }

    /// Looks in the journal for a set that was interrupted or left unfinished.
    func loadResumableSet() async {
        guard phase == .idle else { return }
        let (sets, _) = BurnSetProgress.replay(await journal.readAll())
        var latest: BurnSetProgress?
        for found in sets where !found.isComplete {
            var current = found
            // A burn that was running when Krouton quit did not finish; record that before offering a resume.
            for job in found.interrupted {
                let event = BurnEvent.attemptFailed(
                    set: found.id, disc: job.disc.index, attempt: job.attempts, failure: .interrupted, at: .now
                )
                guard (try? await journal.append(event)) != nil else { continue }
                try? current.apply(event, disc: job.disc.index)
            }
            let imagesPresent = current.set.discs.allSatisfy { FileManager.default.fileExists(atPath: $0.imageURL.path) }
            if imagesPresent { latest = current }
        }
        if phase == .idle { resumable = latest }
    }

    func resumeFoundSet() {
        guard !isBusy, let found = resumable else { return }
        resumable = nil
        setTitle = found.set.title
        notice = nil
        workTask = Task { [weak self] in await self?.run(found) }
    }

    /// Deletes the staged images of the found set, which also stops it being offered again.
    func discardFoundSet() {
        guard let found = resumable else { return }
        Self.removeStagedSet(found.set.id, under: stagingRoot)
        resumable = nil
    }

    // MARK: - Stopping

    /// Lets discs that are being written finish, then stops. No disc is spoiled.
    func stopAfterCurrentDiscs() {
        guard phase == .running else { return }
        isStopping = true
        workTask?.cancel()
    }

    /// Stops every drive immediately. Discs that are being written are spoiled.
    func abortNow() {
        guard phase == .running else { return }
        isStopping = true
        connected.forEach { $0.abortCurrentDisc() }
        workTask?.cancel()
    }

    /// Returns to the start screen. An unfinished set stays in the journal and can be resumed later.
    func dismissFinishedSet() {
        guard phase == .finished else { return }
        phase = .idle
        discs = []
        drives = []
        notice = nil
        progress = nil
    }

    // MARK: - Running

    private func run(_ startingProgress: BurnSetProgress) async {
        progress = startingProgress
        rebuildDiscRows(from: startingProgress)
        isStopping = false
        notice = nil
        // The set takes every burner; the coordinator refuses while the queue or the drive bank uses one.
        let coordinator = KroutonBurnCoordinator.shared
        if let refusal = coordinator.beginSet(title: startingProgress.set.title,
                                              driveBankIsBusy: KroutonWindowManager.shared.driveManager.isExecutingQueue) {
            notice = refusal
            phase = .finished
            return
        }
        defer { coordinator.endSet() }
        // The set's burns don't go through the drive bank, whose busy flag holds the app's sleep
        // assertion; without this the Mac could idle-sleep in the middle of a disc.
        let activity = ProcessInfo.processInfo.beginActivity(
            options: [.userInitiated, .idleSystemSleepDisabled, .suddenTerminationDisabled],
            reason: "Burning the multi-disc set \(startingProgress.set.title)")
        defer { ProcessInfo.processInfo.endActivity(activity) }
        phase = .running

        let found = await DiscRecordingOpticalDrive.connectedDrives { [weak self] driveID, message in
            self?.setDriveMessage(driveID.raw, message)
        }
        guard !found.isEmpty else {
            notice = "No optical burner is connected. Connect one, then choose Burn Remaining Discs."
            phase = .finished
            return
        }
        connected = found
        drives = found.map { DriveRow(id: $0.id.raw, name: $0.displayName, message: "Starting...") }

        let scheduler = BurnSetScheduler(progress: startingProgress, drives: found, journal: journal)
        let listener = Task { [weak self] in
            for await event in scheduler.events {
                self?.handle(event)
                if case .finished = event { break }
            }
        }
        // Runs inside this task, so cancelling `workTask` reaches every drive's loop.
        _ = await scheduler.run()
        await listener.value
        connected = []
    }

    private func handle(_ event: BurnSchedulerEvent) {
        switch event {
        case .waitingForBlank(let drive, let request):
            let size = Self.byteText(request.minimumBytes)
            setDriveMessage(drive.raw, "Insert a blank disc (at least \(size)) for Disc \(request.discIndex) of \(request.discCount): \(request.volumeLabel)")
        case .discChanged(let job):
            updateRow(for: job)
            if case .inProgress(_, let drive, let burnPhase) = job.state {
                setDriveMessage(drive.raw, "\(Self.phaseText(burnPhase)) Disc \(job.disc.index): \(job.disc.volumeLabel)")
            }
        case .ejected(let drive, let discIndex, let volumeLabel, let succeeded):
            setDriveMessage(drive.raw, succeeded
                ? "Disc \(discIndex) is finished. Label it \(volumeLabel)."
                : "Disc \(discIndex) (\(volumeLabel)) was not completed. Set that disc aside.")
        case .finished(let finalProgress):
            progress = finalProgress
            rebuildDiscRows(from: finalProgress)
            for index in drives.indices { drives[index].message = "Idle" }
            isStopping = false
            phase = .finished
            if finalProgress.isComplete {
                Self.removeStagedSet(finalProgress.set.id, under: stagingRoot)
                let count = finalProgress.jobs.count
                notice = count == 1 ? "The disc was burned and verified." : "All \(count) discs were burned and verified."
            } else {
                let left = finalProgress.remaining.count
                notice = "\(left) disc\(left == 1 ? "" : "s") still need\(left == 1 ? "s" : "") burning. The staged images are kept so you can continue."
            }
        }
    }

    private func setDriveMessage(_ driveID: String, _ message: String) {
        guard let index = drives.firstIndex(where: { $0.id == driveID }) else { return }
        drives[index].message = message
    }

    private func rebuildDiscRows(from progress: BurnSetProgress) {
        discs = progress.jobs.map {
            DiscRow(id: $0.disc.index, volumeLabel: $0.disc.volumeLabel, imageBytes: $0.disc.imageBytes, status: status(for: $0))
        }
    }

    private func updateRow(for job: DiscJob) {
        guard let index = discs.firstIndex(where: { $0.id == job.disc.index }) else { return }
        discs[index].status = status(for: job)
    }

    private func status(for job: DiscJob) -> DiscStatus {
        switch job.state {
        case .pending:
            return .pending
        case .inProgress(_, let drive, let burnPhase):
            let name = drives.first { $0.id == drive.raw }?.name ?? drive.raw
            return .active("\(Self.phaseText(burnPhase)) on \(name)")
        case .done:
            return .done
        case .failed(let attempt, let failure):
            return .failed("Attempt \(attempt): \(Self.failureText(failure))")
        }
    }

    // MARK: - Text

    static func phaseText(_ phase: BurnPhase) -> String {
        switch phase {
        case .writing: return "Writing"
        case .closing: return "Closing"
        case .verifying: return "Verifying"
        }
    }

    static func failureText(_ failure: BurnFailure) -> String {
        switch failure {
        case .mediaRejected(let reason): return reason
        case .writeError(let sense): return sense
        case .verifyMismatch(let sector): return "The disc did not read back the same as the image (first difference at sector \(sector))."
        case .driveDisconnected: return "The drive was disconnected."
        case .interrupted: return "Krouton quit while this disc was being burned."
        case .cancelledByUser: return "Stopped before it finished."
        }
    }

    static func byteText(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }

    private nonisolated static func removeStagedSet(_ setID: BurnSetID, under root: URL) {
        let directory = root.appendingPathComponent(setID.raw.uuidString, isDirectory: true)
        Task.detached(priority: .utility) {
            try? FileManager.default.removeItem(at: directory)
        }
    }
}
