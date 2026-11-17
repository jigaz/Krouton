import Foundation
import OpticalCore

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

public struct BlankMedia: Sendable, Equatable {
    public let mediaID: String       // manufacturer / ATIP or MID string
    public let capacityBytes: Int64  // as reported by THIS disc, not a table
}

public struct BlankRequest: Sendable, Equatable {
    public let setTitle: String
    public let discIndex: Int
    public let discCount: Int
    public let volumeLabel: String
    public let minimumBytes: Int64
}

public protocol OpticalDrive: Sendable {
    var id: DriveID { get }
    var displayName: String { get }
    /// Waits for a blank that satisfies the request, prompting through the UI.
    /// Throws `BurnFailure.mediaRejected` if the user supplies something unusable,
    /// `.cancelledByUser` if they dismiss the prompt.
    func waitForBlank(_ request: BlankRequest) async throws(BurnFailure) -> BlankMedia
    func write(image: URL, onPhase: @Sendable (BurnPhase) async -> Void) async throws(BurnFailure)
    func verify(againstSHA256 digest: String, byteCount: Int64) async throws(BurnFailure)
    func eject() async
}

public protocol BurnJournaling: Sendable {
    func append(_ event: BurnEvent) async throws
}

public enum BurnSchedulerEvent: Sendable {
    case waitingForBlank(drive: DriveID, request: BlankRequest)
    case discChanged(DiscJob)
    /// Tell the user which physical disc this is before it leaves the tray.
    case ejected(drive: DriveID, discIndex: Int, volumeLabel: String, succeeded: Bool)
    case finished(BurnSetProgress)
}

public actor BurnSetScheduler {
    private var progress: BurnSetProgress
    private var claimed: Set<Int> = []
    private var allowed: Set<Int>?
    private var isRunning = false
    private let drives: [any OpticalDrive]
    private let journal: any BurnJournaling
    private let continuation: AsyncStream<BurnSchedulerEvent>.Continuation

    /// The UI observes this with `for await event in scheduler.events`.
    public nonisolated let events: AsyncStream<BurnSchedulerEvent>

    /// - Parameter progress: from `BurnSetProgress.replay`, so a resumed set
    ///   starts with its finished discs already finished.
    public init(progress: BurnSetProgress, drives: [any OpticalDrive], journal: any BurnJournaling) {
        self.progress = progress
        self.drives = drives
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

            try await drive.write(image: disc.imageURL) { phase in
                try? await self.record(.phaseChanged(set: setID, disc: disc.index, attempt: attempt,
                                                     phase: phase, at: .now), disc: disc.index)
            }
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
            }
            // The disc stays claimed for the rest of this run, so nothing retries it
            // automatically. The next `run` starts with a clean slate.
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
// A fake drive for tests is a dozen lines: an actor with a script such as
// [.succeed, .fail(.writeError(sense: "3/0C/00")), .disconnect]. With it you can
// assert, without hardware, that a failure on Disc 2 of 3 leaves 1 and 3 done,
// that `run(only: [2])` writes exactly one more attempt, and that two drives
// never receive the same disc.
//
// Before allowing more than one drive at a time, stage every image on local SSD
// and check each drive has its own power; two bus-powered drives on one hub is
// the classic way to spoil both discs.

extension BurnEventJournal: BurnJournaling {}

/// Deterministic scripted optical drive actor for testing single-drive retry, USB disconnects,
/// blank capacity rejection, and multi-drive concurrent queue claiming without physical media.
public actor ScriptedOpticalDrive: OpticalDrive {
    public enum Step: Sendable {
        case succeed(mediaID: String = "TAIYO-YUDEN-CDR", capacityBytes: Int64 = 737_280_000)
        case rejectBlank(capacityBytes: Int64)
        case failWrite(sense: String)
        case disconnectMidWrite
        case cancelAtPrompt
    }

    public nonisolated let id: DriveID
    public nonisolated let displayName: String
    private var steps: [Step]
    private var currentStep: Step = .succeed()
    public private(set) var burnedImageURLs: [URL] = []
    public private(set) var ejectCount: Int = 0

    public init(id: String, displayName: String, script: [Step]) {
        self.id = DriveID(id)
        self.displayName = displayName
        self.steps = script
    }

    public func waitForBlank(_ request: BlankRequest) async throws(BurnFailure) -> BlankMedia {
        let next = steps.isEmpty ? Step.succeed() : steps.removeFirst()
        currentStep = next
        switch next {
        case .succeed(let mid, let cap):
            return BlankMedia(mediaID: mid, capacityBytes: cap)
        case .rejectBlank(let cap):
            return BlankMedia(mediaID: " UNDERSIZED-BLANK", capacityBytes: cap)
        case .failWrite, .disconnectMidWrite:
            return BlankMedia(mediaID: "TEST-BLANK", capacityBytes: max(request.minimumBytes + 4096, 737_280_000))
        case .cancelAtPrompt:
            throw BurnFailure.cancelledByUser
        }
    }

    public func write(image: URL, onPhase: @Sendable (BurnPhase) async -> Void) async throws(BurnFailure) {
        await onPhase(.writing)
        switch currentStep {
        case .failWrite(let sense):
            throw BurnFailure.writeError(sense: sense)
        case .disconnectMidWrite:
            throw BurnFailure.driveDisconnected
        default:
            await onPhase(.closing)
            burnedImageURLs.append(image)
        }
    }

    public func verify(againstSHA256 digest: String, byteCount: Int64) async throws(BurnFailure) {
        // Verify that the staged file matches the expected byteCount
    }

    public func eject() async {
        ejectCount += 1
    }
}
