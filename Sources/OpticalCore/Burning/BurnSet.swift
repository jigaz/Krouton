import Foundation

// A multi-disc burn as data: a frozen set, per-disc jobs, and an event log.
//
// The journal stores events (what happened), and every status on screen is
// computed from them by a pure function. That gives three things for free:
//
//   - Retry of one disc is just another attempt appended for that disc.
//   - After a crash, replaying the log shows exactly which disc was mid-burn.
//   - The whole state machine is testable with arrays, no drive required.
//
// Disc states are an enum with a transition function, so an impossible sequence
// (verifying a disc that never started, finishing one twice) is rejected where
// it is recorded instead of producing a confusing UI later.

// MARK: - BurnSet

/// Identifies a burn set in the journal.
public struct BurnSetID: Hashable, Codable, Sendable {
    public let raw: UUID
    public init(_ raw: UUID = UUID()) { self.raw = raw }
}

/// Identifies a drive across launches and reconnections.
public struct DriveID: Hashable, Codable, Sendable {
    /// Stable hardware identity (vendor + product + serial), not a BSD name.
    public let raw: String
    public init(_ raw: String) { self.raw = raw }
}

/// One disc of a set, fully staged and immutable. Because the image and its hash
/// are fixed here, any number of attempts produce the same disc, and no disc
/// depends on another having been burned.
public struct FrozenDisc: Codable, Sendable, Identifiable, Equatable {
    public let index: Int            // 1-based position in the set
    public let volumeLabel: String
    /// The staged image to burn.
    public let imageURL: URL
    /// Lowercase hex SHA-256 of the image, for verifying the burned disc.
    public let imageSHA256: String
    /// The image's size in bytes.
    public let imageBytes: Int64
    public var id: Int { index }

    public init(index: Int, volumeLabel: String, imageURL: URL, imageSHA256: String, imageBytes: Int64) {
        self.index = index
        self.volumeLabel = volumeLabel
        self.imageURL = imageURL
        self.imageSHA256 = imageSHA256
        self.imageBytes = imageBytes
    }
}

/// Created when the user presses Burn. From this moment the plan cannot change:
/// editing the project produces a NEW set, so Disc 2 can never drift out of step
/// with a Disc 1 that already exists.
public struct BurnSet: Codable, Sendable, Identifiable, Equatable {
    public let id: BurnSetID
    /// The set's title, as the user named it.
    public let title: String
    public let createdAt: Date
    /// The discs, in order.
    public let discs: [FrozenDisc]

    public init(id: BurnSetID = BurnSetID(), title: String, createdAt: Date = Date(), discs: [FrozenDisc]) {
        self.id = id
        self.title = title
        self.createdAt = createdAt
        self.discs = discs
    }
}

/// Why one attempt at one disc failed.
public enum BurnFailure: Error, Codable, Sendable, Equatable {
    case mediaRejected(reason: String)            // wrong type, not blank, too small
    case writeError(sense: String)                // decoded sense key / ASC / ASCQ
    case verifyMismatch(firstBadSector: Int64)
    case driveDisconnected
    case interrupted                              // Krouton exited mid-attempt
    case cancelledByUser
}

/// The stage a disc attempt is in.
public enum BurnPhase: String, Codable, Sendable { case writing, closing, verifying }

/// One line of the burn journal. Every status on screen is derived from these.
public enum BurnEvent: Codable, Sendable, Equatable {
    case setCreated(BurnSet)
    case attemptStarted(set: BurnSetID, disc: Int, attempt: Int, drive: DriveID, mediaID: String, at: Date)
    case phaseChanged(set: BurnSetID, disc: Int, attempt: Int, phase: BurnPhase, at: Date)
    case attemptSucceeded(set: BurnSetID, disc: Int, attempt: Int, at: Date)
    case attemptFailed(set: BurnSetID, disc: Int, attempt: Int, failure: BurnFailure, at: Date)

    var setID: BurnSetID {
        switch self {
        case .setCreated(let set): return set.id
        case .attemptStarted(let id, _, _, _, _, _), .phaseChanged(let id, _, _, _, _),
             .attemptSucceeded(let id, _, _, _), .attemptFailed(let id, _, _, _, _): return id
        }
    }
}

/// Where one disc stands, derived from its events.
public enum DiscJobState: Sendable, Equatable {
    case pending
    case inProgress(attempt: Int, drive: DriveID, phase: BurnPhase)
    case done(attempt: Int, drive: DriveID, mediaID: String)
    case failed(attempt: Int, failure: BurnFailure)

    var isFinished: Bool { if case .done = self { true } else { false } }
    var canStart: Bool {
        switch self {
        case .pending, .failed: true
        case .inProgress, .done: false
        }
    }
}

/// An event that doesn't fit the disc's state, such as a success for an attempt that never started.
public struct BurnTransitionError: Error, Equatable {
    public let disc: Int
    public let from: DiscJobState
    public let event: BurnEvent
}

/// One disc of a set and its state.
public struct DiscJob: Sendable, Equatable, Identifiable {
    public let disc: FrozenDisc
    /// Where the disc stands.
    public private(set) var state: DiscJobState = .pending
    /// How many attempts have started, from 0.
    public private(set) var attempts = 0
    private var currentMediaID = ""
    public var id: Int { disc.index }

    public init(disc: FrozenDisc) { self.disc = disc }

    /// The only place a disc changes state. Anything out of order throws.
    public mutating func apply(_ event: BurnEvent) throws(BurnTransitionError) {
        switch (state, event) {
        case (_, .attemptStarted(_, _, let attempt, let drive, let mediaID, _))
            where state.canStart && attempt == attempts + 1:
            attempts = attempt
            currentMediaID = mediaID
            state = .inProgress(attempt: attempt, drive: drive, phase: .writing)

        case (.inProgress(let attempt, let drive, _), .phaseChanged(_, _, let eventAttempt, let phase, _))
            where attempt == eventAttempt:
            state = .inProgress(attempt: attempt, drive: drive, phase: phase)

        case (.inProgress(let attempt, let drive, _), .attemptSucceeded(_, _, let eventAttempt, _))
            where attempt == eventAttempt:
            state = .done(attempt: attempt, drive: drive, mediaID: currentMediaID)

        case (.inProgress(let attempt, _, _), .attemptFailed(_, _, let eventAttempt, let failure, _))
            where attempt == eventAttempt:
            state = .failed(attempt: attempt, failure: failure)

        default:
            throw BurnTransitionError(disc: disc.index, from: state, event: event)
        }
    }
}

/// Everything the UI needs about one set, rebuilt from the journal on demand.
public struct BurnSetProgress: Sendable, Equatable, Identifiable {
    /// The frozen set.
    public let set: BurnSet
    /// One job per disc, in order.
    public private(set) var jobs: [DiscJob]
    public var id: BurnSetID { self.set.id }

    /// True when every disc burned.
    public var isComplete: Bool { jobs.allSatisfy(\.state.isFinished) }
    /// Discs that still need a successful burn: what "Retry" and "Resume" queue.
    public var remaining: [DiscJob] { jobs.filter(\.state.canStart) }
    /// Non-empty right after an unclean exit. Show these, then record them as interrupted.
    public var interrupted: [DiscJob] {
        jobs.filter { if case .inProgress = $0.state { true } else { false } }
    }

    public init(set: BurnSet) {
        self.set = set
        self.jobs = set.discs.map(DiscJob.init)
    }

    /// Applies an event to the disc with number `index`.
    public mutating func apply(_ event: BurnEvent, disc index: Int) throws(BurnTransitionError) {
        guard let position = jobs.firstIndex(where: { $0.disc.index == index }) else {
            throw BurnTransitionError(disc: index, from: .pending, event: event)
        }
        try jobs[position].apply(event)
    }

    /// Replays a journal. Events that do not fit (a torn or duplicated line) are
    /// returned, not silently dropped, so a damaged journal is visible.
    public static func replay(_ events: [BurnEvent]) -> (sets: [BurnSetProgress], rejected: [BurnTransitionError]) {
        var byID: [BurnSetID: BurnSetProgress] = [:]
        var order: [BurnSetID] = []
        var rejected: [BurnTransitionError] = []

        for event in events {
            switch event {
            case .setCreated(let set):
                if byID[set.id] == nil { order.append(set.id) }
                byID[set.id] = byID[set.id] ?? BurnSetProgress(set: set)
            case .attemptStarted(let id, let disc, _, _, _, _), .phaseChanged(let id, let disc, _, _, _),
                 .attemptSucceeded(let id, let disc, _, _), .attemptFailed(let id, let disc, _, _, _):
                do throws(BurnTransitionError) {
                    guard byID[id] != nil else { throw BurnTransitionError(disc: disc, from: .pending, event: event) }
                    try byID[id]?.apply(event, disc: disc)
                } catch {
                    rejected.append(error)
                }
            }
        }
        return (order.compactMap { byID[$0] }, rejected)
    }
}

// At launch, `KroutonBurnSetController.loadResumableSet` (in the app) replays the journal,
// records every disc that was mid-burn as `.interrupted` (on write-once media that disc is
// spoiled), and offers to resume a set that isn't complete; resuming burns `remaining` only.
//
// krouton-verify Suites 22 and 30 check replay and retry. Cases worth unit tests here, none of
// which need a drive: a second success for the same attempt throws; a failure on disc 2 leaves
// discs 1 and 3 untouched; replaying any prefix of a valid log rejects nothing.
