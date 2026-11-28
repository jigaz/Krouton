import Foundation
import OpticalCore

// MARK: - Burn Set Scheduler
//
// Runs a frozen set across however many drives are connected.
//
// Structure:
//   - `OpticalDrive` is a protocol, so the scheduler is tested with a scripted
//     fake drive and never needs hardware. DiscRecording sits behind it.
//   - One child task per drive, inside a task group. Each drive pulls the next
//     disc that still needs burning from the actor, so one drive burns the set in
//     order and three drives burn three discs at once with the same code.
//   - The actor owns the queue. Two drives can never take the same disc because
//     taking one is a single actor-isolated step.
//   - Every state change is appended to the journal BEFORE the UI hears about it.
//   - A disc that fails stays failed; nothing retries write-once media on its
//     own. `run(only:)` is how the user retries exactly the discs they choose.

/// The blank disc a drive found for one disc of the set.
public struct BlankMedia: Sendable, Equatable {
    /// Identifies the blank: a manufacturer (ATIP or MID) string, or the media type when the
    /// drive reports none.
    public let mediaID: String
    /// Space on this disc, as the drive reports it, not from a table.
    public let capacityBytes: Int64

    public init(mediaID: String, capacityBytes: Int64) {
        self.mediaID = mediaID
        self.capacityBytes = capacityBytes
    }
}

/// What a drive asks the user to insert for one disc of the set.
public struct BlankRequest: Sendable, Equatable {
    /// The set's title.
    public let setTitle: String
    /// The disc's number, from 1.
    public let discIndex: Int
    /// How many discs the set has.
    public let discCount: Int
    /// The disc's volume label.
    public let volumeLabel: String
    /// The least space the blank must have.
    public let minimumBytes: Int64
}

/// A burner as the scheduler sees it: wait for a blank, write an image, verify it, eject.
/// `DiscRecordingOpticalDrive` is the real one; krouton-verify uses a scripted one.
public protocol OpticalDrive: Sendable {
    /// Identifies the drive across reconnections.
    var id: DriveID { get }
    /// The drive's name, for prompts.
    var displayName: String { get }
    /// The drive's top write speed; faster drives are asked for discs first.
    var maxWriteSpeedX: Double { get }
    /// Waits for a blank that satisfies the request, prompting through the UI.
    /// Throws `BurnFailure.mediaRejected` if the user supplies something unusable,
    /// `.cancelledByUser` if they dismiss the prompt.
    func waitForBlank(_ request: BlankRequest) async throws(BurnFailure) -> BlankMedia
    /// Writes the image, reporting each phase.
    func write(image: URL, onPhase: @Sendable (BurnPhase) async -> Void) async throws(BurnFailure)
    /// Reads the disc back and compares it with the image's SHA-256.
    func verify(againstSHA256 digest: String, byteCount: Int64) async throws(BurnFailure)
    /// Ejects the disc.
    func eject() async
}

extension OpticalDrive {
    /// 16x when a drive doesn't say.
    public var maxWriteSpeedX: Double { 16.0 }
}

/// Where the scheduler records every event before the UI hears of it.
public protocol BurnJournaling: Sendable {
    /// Appends an event durably.
    func append(_ event: BurnEvent) async throws
}

/// What the scheduler reports to the UI as it runs.
public enum BurnSchedulerEvent: Sendable {
    /// A drive waits for the user to insert a blank.
    case waitingForBlank(drive: DriveID, request: BlankRequest)
    /// A disc's job changed state.
    case discChanged(DiscJob)
    /// Tell the user which physical disc this is before it leaves the tray.
    case ejected(drive: DriveID, discIndex: Int, volumeLabel: String, succeeded: Bool)
    /// The run ended; the set's progress as it stands.
    case finished(BurnSetProgress)
}

/// Burns a frozen set on every given drive at once; see the comment at the top of this file.
public actor BurnSetScheduler {
    private var progress: BurnSetProgress
    private var claimed: Set<Int> = []
    private var allowed: Set<Int>?
    private var isRunning = false
    private let drives: [any OpticalDrive]
    private let journal: any BurnJournaling
    private let continuation: AsyncStream<BurnSchedulerEvent>.Continuation
    /// Lets one drive at a time go through lead-in and power calibration, so several drives on one
    /// USB hub never spin up together and starve each other of power or bandwidth.
    private let arbiter: BurnPowerAndBandwidthArbiter

    /// The UI observes this with `for await event in scheduler.events`.
    public nonisolated let events: AsyncStream<BurnSchedulerEvent>

    /// - Parameter progress: from `BurnSetProgress.replay`, so a resumed set
    ///   starts with its finished discs already finished.
    public init(progress: BurnSetProgress, drives: [any OpticalDrive], journal: any BurnJournaling,
                spinUpPolicy: BusArbitrationState.Policy = .init()) {
        self.progress = progress
        self.arbiter = BurnPowerAndBandwidthArbiter(policy: spinUpPolicy)
        self.drives = drives.sorted { $0.maxWriteSpeedX > $1.maxWriteSpeedX }
        self.journal = journal
        (events, continuation) = AsyncStream.makeStream(of: BurnSchedulerEvent.self)
    }

    /// Burns every disc that still needs it, or only `discs` when retrying.
    /// Cancelling the calling task stops each drive at its next safe point.
    @discardableResult
    public func run(only discs: Set<Int>? = nil) async -> BurnSetProgress {
        guard !isRunning else { return progress } // one run at a time per set
        isRunning = true
        defer { isRunning = false }
        allowed = discs
        claimed = []
        await withTaskGroup(of: Void.self) { group in
            for drive in drives {
                group.addTask { await self.work(on: drive) }
            }
        }
        continuation.yield(.finished(progress))
        return progress
    }

    // MARK: - Queue (actor-isolated, so claims are atomic)

    private func claimNextDisc() -> FrozenDisc? {
        let next = progress.remaining.first { job in
            !claimed.contains(job.disc.index) && (allowed?.contains(job.disc.index) ?? true)
        }
        guard let next else { return nil }
        claimed.insert(next.disc.index)
        return next.disc
    }

    /// Journal first, then state, then UI. If the journal write fails the event
    /// is not applied: the log must never be behind what the user was shown.
    private func record(_ event: BurnEvent, disc index: Int) async throws {
        try await journal.append(event)
        try progress.apply(event, disc: index)
        if let job = progress.jobs.first(where: { $0.disc.index == index }) {
            continuation.yield(.discChanged(job))
        }
    }

    // MARK: - One drive's loop

    private func work(on drive: any OpticalDrive) async {
        while !Task.isCancelled, let disc = claimNextDisc() {
            let outcome = await burn(disc, on: drive)
            await drive.eject()
            continuation.yield(.ejected(drive: drive.id, discIndex: disc.index,
                                        volumeLabel: disc.volumeLabel, succeeded: outcome == nil))
            // A drive that vanished cannot take another disc. The remaining discs
            // stay in the queue for the other drives, or for a later resume.
            // Likewise if the user dismissed the blank-disc prompt on this drive.
            if outcome == .driveDisconnected || outcome == .cancelledByUser { return }
        }
    }

    /// Returns nil on success, otherwise why this attempt failed.
    private func burn(_ disc: FrozenDisc, on drive: any OpticalDrive) async -> BurnFailure? {
        let setID = progress.set.id
        let attempt = (progress.jobs.first { $0.disc.index == disc.index }?.attempts ?? 0) + 1
        let request = BlankRequest(setTitle: progress.set.title, discIndex: disc.index,
                                   discCount: progress.set.discs.count,
                                   volumeLabel: disc.volumeLabel, minimumBytes: disc.imageBytes)
        var started = false
        do {
            continuation.yield(.waitingForBlank(drive: drive.id, request: request))
            let media = try await drive.waitForBlank(request)
            // The planning table is a default; the disc in the tray has the final say.
            guard media.capacityBytes >= disc.imageBytes else {
                throw BurnFailure.mediaRejected(reason: "This blank holds less than the disc image needs.")
            }

            try await record(.attemptStarted(set: setID, disc: disc.index, attempt: attempt,
                                             drive: drive.id, mediaID: media.mediaID, at: .now), disc: disc.index)
            started = true

            // Arbitration only matters when several drives can spin up at once.
            let arbitrated = drives.count > 1
            if arbitrated { await arbiter.acquireSpinUp(for: drive.id) }
            do {
                try await drive.write(image: disc.imageURL) { phase in
                    if arbitrated, phase == .writing { await self.arbiter.reachedSteadyWriting(drive.id) }
                    try? await self.record(.phaseChanged(set: setID, disc: disc.index, attempt: attempt,
                                                         phase: phase, at: .now), disc: disc.index)
                }
            } catch {
                if arbitrated { await arbiter.withdraw(drive.id) }
                throw error
            }
            if arbitrated { await arbiter.withdraw(drive.id) }
            try await record(.phaseChanged(set: setID, disc: disc.index, attempt: attempt,
                                           phase: .verifying, at: .now), disc: disc.index)
            try await drive.verify(againstSHA256: disc.imageSHA256, byteCount: disc.imageBytes)

            try await record(.attemptSucceeded(set: setID, disc: disc.index, attempt: attempt, at: .now),
                             disc: disc.index)
            return nil
        } catch {
            let failure = (error as? BurnFailure) ?? .writeError(sense: error.localizedDescription)
            // Only an attempt that reached the disc is journalled as failed. A
            // refused blank or a dismissed prompt spoiled nothing.
            if started {
                try? await record(.attemptFailed(set: setID, disc: disc.index, attempt: attempt,
                                                 failure: failure, at: .now), disc: disc.index)
            } else {
                // Nothing was written (rejected blank, dismissed prompt, or unplugged before laser ignition):
                // release the claim so this drive or another pooled burner can burn the disc.
                claimed.remove(disc.index)
            }
            return failure
        }
    }
}

// Using it:
//
//   let (sets, _) = BurnSetProgress.replay(try await journal.readAll())
//   let scheduler = BurnSetScheduler(progress: sets[0], drives: connectedDrives, journal: journal)
//   let burn = Task { await scheduler.run() }                    // every remaining disc
//   for await event in scheduler.events { model.handle(event) }  // on the main actor
//   ...
//   Task { await scheduler.run(only: [2]) }                      // retry Disc 2 alone
//   burn.cancel()                                                // stop at the next safe point
//
// `krouton-verify` drives this with a scripted drive (KroutonVerify/ScriptedOpticalDrive.swift):
// a failure on Disc 2 of 3 leaves 1 and 3 done, `run(only: [2])` writes exactly one more attempt,
// and two drives never receive the same disc.
//
// Before allowing more than one drive at a time, stage every image on local SSD
// and check each drive has its own power; two bus-powered drives on one hub is
// the classic way to spoil both discs.

extension BurnEventJournal: BurnJournaling {}
