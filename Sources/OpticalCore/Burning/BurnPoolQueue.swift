import Foundation

// MARK: - Multi-Burner Pool and Waiting Queue

/// What happens when a burner in the pool finishes a disc. The raw values are display names and are
/// saved.
public enum KroutonPoolDispatchMode: String, CaseIterable, Identifiable, Codable, Sendable {
    case autoAssign = "Auto-Assign"
    case askOperator = "Ask / Manual"

    public var id: String { rawValue }

    /// The SF Symbols name for the mode's icon.
    public var sfSymbol: String {
        switch self {
        case .autoAssign: return "bolt.horizontal.circle.fill"
        case .askOperator: return "hand.raised.circle.fill"
        }
    }

    /// One sentence about the mode, for its picker.
    public var summaryText: String {
        switch self {
        case .autoAssign:
            return "Automatically promotes the next waiting disc into whichever burner finishes first (fastest burner prioritized)."
        case .askOperator:
            return "Holds waiting discs below the divider until you approve or manually promote a task into an available burner."
        }
    }
}

/// One disc to burn in the pool: which disc of a span and which copy.
public struct KroutonPoolBurnTicket: Identifiable, Hashable, Codable, Sendable {
    public var id: UUID
    /// Position in the queue, from 0; the waiting list is kept in this order.
    public var sequenceNumber: Int
    /// Which disc of the span, from 1.
    public var spannedDiscNumber: Int
    /// How many discs the span has.
    public var totalSpannedDiscs: Int
    /// Which copy, from 1.
    public var copyNumber: Int
    /// How many copies of each disc.
    public var totalCopies: Int
    /// The volume label this disc is burned with.
    public var volumeLabel: String
    /// Roughly how much the disc holds.
    public var estimatedBytes: Int64
    /// A drive the ticket should go to, when the user chose one.
    public var preferredDriveID: String?

    public init(
        id: UUID = UUID(),
        sequenceNumber: Int,
        spannedDiscNumber: Int,
        totalSpannedDiscs: Int,
        copyNumber: Int,
        totalCopies: Int,
        volumeLabel: String,
        estimatedBytes: Int64,
        preferredDriveID: String? = nil
    ) {
        self.id = id
        self.sequenceNumber = sequenceNumber
        self.spannedDiscNumber = spannedDiscNumber
        self.totalSpannedDiscs = max(1, totalSpannedDiscs)
        self.copyNumber = max(1, copyNumber)
        self.totalCopies = max(1, totalCopies)
        self.volumeLabel = volumeLabel
        self.estimatedBytes = estimatedBytes
        self.preferredDriveID = preferredDriveID
    }

    /// "Disc 2 of 3", "Copy 4 of 20", or both.
    public var badgeTitle: String {
        if totalSpannedDiscs > 1 && totalCopies > 1 {
            return "Disc \(spannedDiscNumber)/\(totalSpannedDiscs) • Copy \(copyNumber)/\(totalCopies)"
        } else if totalSpannedDiscs > 1 {
            return "Disc \(spannedDiscNumber) of \(totalSpannedDiscs)"
        } else if totalCopies > 1 {
            return "Copy \(copyNumber) of \(totalCopies)"
        } else {
            return "Disc 1 of 1"
        }
    }

    /// A compact form of `badgeTitle` for narrow rows.
    public var shortQueueBadge: String {
        if totalSpannedDiscs > 1 && totalCopies > 1 {
            return "D\(spannedDiscNumber)•C\(copyNumber)"
        } else if totalSpannedDiscs > 1 {
            return "DISC \(spannedDiscNumber)/\(totalSpannedDiscs)"
        } else {
            return "COPY \(copyNumber)/\(totalCopies)"
        }
    }
}

/// A burner as the pool ranks it.
public struct KroutonPoolDriveDescriptor: Identifiable, Hashable, Codable, Sendable {
    /// The drive's ID.
    public let id: String
    /// The drive's display name.
    public let displayName: String
    /// The drive's top write speed, at least 1x.
    public let maxWriteSpeedX: Double

    public init(id: String, displayName: String, maxWriteSpeedX: Double) {
        self.id = id
        self.displayName = displayName
        self.maxWriteSpeedX = max(1.0, maxWriteSpeedX)
    }
}

/// The destination queue's multi-burner pool: which ticket each drive is burning or waiting to
/// start, and the tickets still waiting.
public struct KroutonDrivePoolState: Equatable, Codable, Sendable {
    /// The ticket each drive is burning or about to burn.
    public private(set) var assignedByDriveID: [String: KroutonPoolBurnTicket] = [:]
    /// In `.askOperator` mode, the ticket offered to each drive until the user approves it.
    public private(set) var pendingApprovalByDriveID: [String: KroutonPoolBurnTicket] = [:]
    /// How many tickets each drive finished.
    public private(set) var completedCountByDriveID: [String: Int] = [:]
    /// Tickets not yet given to a drive, in sequence order.
    public private(set) var waitingTasks: [KroutonPoolBurnTicket] = []
    /// Tickets that finished, in the order they finished.
    public private(set) var completedTickets: [KroutonPoolBurnTicket] = []

    public init() {}

    /// Tickets not yet finished.
    public var totalRemainingCount: Int {
        assignedByDriveID.count + pendingApprovalByDriveID.count + waitingTasks.count
    }

    /// True once at least one ticket finished and none is left.
    public var isComplete: Bool {
        assignedByDriveID.isEmpty && pendingApprovalByDriveID.isEmpty && waitingTasks.isEmpty && !completedTickets.isEmpty
    }

    /// Ranks drives from fastest write speed to slowest (e.g. 24x -> 10x -> 4x) with deterministic ID tie-breaking.
    public static func rankDrivesFastestFirst(_ drives: [KroutonPoolDriveDescriptor]) -> [KroutonPoolDriveDescriptor] {
        drives.sorted { lhs, rhs in
            if abs(lhs.maxWriteSpeedX - rhs.maxWriteSpeedX) > 0.001 {
                return lhs.maxWriteSpeedX > rhs.maxWriteSpeedX
            }
            return lhs.id < rhs.id
        }
    }

    /// Builds the ordered queue of burn tickets for single-disc multi-copy (e.g. 20 copies),
    /// multi-disc spanning (e.g. 7 spanned discs), or multi-copy spanned sets.
    public static func buildTickets(
        spannedVolumeLabels: [String],
        perDiscBytes: [Int64],
        totalCopies: Int
    ) -> [KroutonPoolBurnTicket] {
        let labels = spannedVolumeLabels.isEmpty ? ["KROUTON_DISC"] : spannedVolumeLabels
        let spanCount = labels.count
        let copies = max(1, totalCopies)
        var result: [KroutonPoolBurnTicket] = []
        var seq = 1
        for copyIdx in 1...copies {
            for spanIdx in 1...spanCount {
                let label = labels[spanIdx - 1]
                let bytes = (spanIdx - 1) < perDiscBytes.count ? perDiscBytes[spanIdx - 1] : (perDiscBytes.first ?? 0)
                result.append(
                    KroutonPoolBurnTicket(
                        sequenceNumber: seq,
                        spannedDiscNumber: spanIdx,
                        totalSpannedDiscs: spanCount,
                        copyNumber: copyIdx,
                        totalCopies: copies,
                        volumeLabel: label,
                        estimatedBytes: bytes
                    )
                )
                seq += 1
            }
        }
        return result
    }

    /// Populates the pool from a ticket list and assigns initial upper slots to the active drives in fastest-first order.
    /// Any remaining tickets stay in `waitingTasks` (the lower waiting pool below the divider).
    public mutating func populateAndAssignInitialSlots(
        tickets: [KroutonPoolBurnTicket],
        activeDrives: [KroutonPoolDriveDescriptor]
    ) {
        assignedByDriveID.removeAll()
        pendingApprovalByDriveID.removeAll()
        completedCountByDriveID.removeAll()
        completedTickets.removeAll()
        waitingTasks = tickets

        let rankedDrives = Self.rankDrivesFastestFirst(activeDrives)
        for drive in rankedDrives {
            guard let idx = nextEligibleWaitingIndex(forDriveID: drive.id) else { break }
            let ticket = waitingTasks.remove(at: idx)
            assignedByDriveID[drive.id] = ticket
        }
    }

    /// Completes the current ticket on `driveID` and advances the queue according to `dispatchMode`.
    /// - In `.autoAssign`: immediately promotes the next waiting ticket into `assignedByDriveID[driveID]`.
    /// - In `.askOperator`: stages the next waiting ticket in `pendingApprovalByDriveID[driveID]` for user confirmation.
    @discardableResult
    public mutating func completeActiveAndAdvance(
        driveID: String,
        dispatchMode: KroutonPoolDispatchMode
    ) -> KroutonPoolBurnTicket? {
        if let finished = assignedByDriveID.removeValue(forKey: driveID) {
            completedTickets.append(finished)
            completedCountByDriveID[driveID, default: 0] += 1
        }
        guard let nextIdx = nextEligibleWaitingIndex(forDriveID: driveID) else {
            return nil
        }
        let nextTicket = waitingTasks.remove(at: nextIdx)
        switch dispatchMode {
        case .autoAssign:
            assignedByDriveID[driveID] = nextTicket
        case .askOperator:
            pendingApprovalByDriveID[driveID] = nextTicket
        }
        return nextTicket
    }

    /// Operator approves the pending ticket on `driveID`, promoting it into the active assigned slot.
    @discardableResult
    public mutating func approvePendingTicket(forDriveID driveID: String) -> KroutonPoolBurnTicket? {
        guard let ticket = pendingApprovalByDriveID.removeValue(forKey: driveID) else {
            if let idx = nextEligibleWaitingIndex(forDriveID: driveID) {
                let pulled = waitingTasks.remove(at: idx)
                assignedByDriveID[driveID] = pulled
                return pulled
            }
            return nil
        }
        assignedByDriveID[driveID] = ticket
        return ticket
    }

    /// Manually promotes a specific waiting ticket from the lower waiting pool into an upper burner slot.
    /// If that burner slot already held an unstarted ticket, the previous ticket is returned to the waiting pool.
    @discardableResult
    public mutating func manuallyPromoteWaitingTicket(_ ticketID: UUID, toDriveID driveID: String) -> KroutonPoolBurnTicket? {
        guard let idx = waitingTasks.firstIndex(where: { $0.id == ticketID }) else { return nil }
        let chosen = waitingTasks.remove(at: idx)
        if var previousPending = pendingApprovalByDriveID.removeValue(forKey: driveID) {
            previousPending.preferredDriveID = nil
            waitingTasks.insert(previousPending, at: 0)
        }
        if var previousAssigned = assignedByDriveID.removeValue(forKey: driveID) {
            previousAssigned.preferredDriveID = nil
            waitingTasks.insert(previousAssigned, at: 0)
        }
        sortWaitingTasksBySequence()
        assignedByDriveID[driveID] = chosen
        return chosen
    }

    private func nextEligibleWaitingIndex(forDriveID driveID: String) -> Int? {
        if let pinnedIdx = waitingTasks.firstIndex(where: { $0.preferredDriveID == driveID }) {
            return pinnedIdx
        }
        return waitingTasks.firstIndex(where: { $0.preferredDriveID == nil })
    }

    private mutating func sortWaitingTasksBySequence() {
        waitingTasks.sort { $0.sequenceNumber < $1.sequenceNumber }
    }
}

extension KroutonOpticalDriveInfo {
    /// Extracts the maximum numeric write speed multiplier (e.g. `24.0` from `"24x (3,600 KB/s)"` or `capabilitiesSummary`).
    public var parsedMaxWriteSpeedX: Double {
        var best: Double = 0.0
        let candidates = availableWriteSpeeds + [capabilitiesSummary]
        for text in candidates {
            let pattern = #"(\d+(?:\.\d+)?)x"#
            if let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) {
                let nsRange = NSRange(text.startIndex..<text.endIndex, in: text)
                for match in regex.matches(in: text, options: [], range: nsRange) {
                    if let r = Range(match.range(at: 1), in: text),
                       let val = Double(text[r]) {
                        best = max(best, val)
                    }
                }
            }
        }
        return best > 0 ? best : 16.0
    }
}

// MARK: - Burn Claim Ledger (late binding)

/// What the ledger looks like to the UI: the disc each drive holds, and the discs still waiting or
/// finished.
public struct BurnPoolSnapshot: Sendable, Equatable {
    /// One drive's disc.
    public struct Slot: Sendable, Equatable {
        public let drive: DriveID
        public let discIndex: Int
        /// True once the drive claimed the disc; false while it is only offered.
        public let isCommitted: Bool
        /// True while the offer waits for the user.
        public let awaitingOperator: Bool

        public init(drive: DriveID, discIndex: Int, isCommitted: Bool, awaitingOperator: Bool) {
            self.drive = drive
            self.discIndex = discIndex
            self.isCommitted = isCommitted
            self.awaitingOperator = awaitingOperator
        }
    }

    /// One slot per drive holding a disc, fastest drive first.
    public let active: [Slot]
    /// Discs no drive holds yet.
    public let waiting: [Int]
    /// Discs that burned.
    public let finished: [Int]

    public init(active: [Slot] = [], waiting: [Int] = [], finished: [Int] = []) {
        self.active = active
        self.waiting = waiting
        self.finished = finished
    }
}

/// Hands out the discs of a set to drives as they become ready. A disc is offered to an idle drive,
/// and claimed (committed) only when a usable blank is in its tray, so a slow drive never holds a
/// disc another drive could burn.
public struct BurnClaimLedger: Sendable, Equatable {
    /// Discs not yet claimed, in order.
    public private(set) var waiting: [Int]
    /// The disc shown to each idle drive.
    public private(set) var offered: [DriveID: Int] = [:]
    /// The disc each drive claimed.
    public private(set) var committed: [DriveID: Int] = [:]
    /// Drives whose offer waits for the user. Nothing adds to it yet.
    public private(set) var awaitingOperator: Set<DriveID> = []
    /// Discs that burned, in the order they finished.
    public private(set) var finished: [Int] = []
    private let driveOrder: [DriveID]

    public init(discs: [Int], drivesFastestFirst: [DriveID]) {
        self.waiting = discs
        self.driveOrder = drivesFastestFirst
    }

    /// Non-exclusive soft peek: prefers a disc no other idle tray is currently offering, else shares the first waiting disc.
    public mutating func offer(to drive: DriveID) -> Int? {
        if let current = committed[drive] { return current }
        let shown = Set(offered.values)
        let pick = waiting.first { !shown.contains($0) } ?? waiting.first
        offered[drive] = pick
        return pick
    }

    /// Atomic claim once a usable blank is confirmed in the tray.
    public mutating func commit(drive: DriveID) -> Int? {
        let peeked = offered.removeValue(forKey: drive)
        let chosen = peeked.flatMap { p in waiting.contains(p) ? p : nil } ?? waiting.first
        guard let disc = chosen, let pos = waiting.firstIndex(of: disc) else { return nil }
        waiting.remove(at: pos)
        committed[drive] = disc
        awaitingOperator.remove(drive)
        return disc
    }

    /// Ends a drive's claim: the disc goes back to `waiting` when `requeue`, to `finished` when
    /// `succeeded`, and is otherwise dropped.
    public mutating func release(drive: DriveID, succeeded: Bool, requeue: Bool) {
        offered.removeValue(forKey: drive)
        awaitingOperator.remove(drive)
        guard let disc = committed.removeValue(forKey: drive) else { return }
        if requeue {
            waiting.append(disc)
            waiting.sort()
        } else if succeeded {
            finished.append(disc)
        }
    }

    /// Takes back an offer to a drive that is no longer idle. A committed disc stays claimed.
    public mutating func withdraw(drive: DriveID) {
        offered.removeValue(forKey: drive)
        awaitingOperator.remove(drive)
    }

    /// True when no disc is waiting or claimed.
    public var isDrained: Bool {
        waiting.isEmpty && committed.isEmpty
    }

    public var snapshot: BurnPoolSnapshot {
        let slots: [BurnPoolSnapshot.Slot] = driveOrder.compactMap { d in
            if let c = committed[d] {
                return .init(drive: d, discIndex: c, isCommitted: true, awaitingOperator: false)
            }
            if let o = offered[d] {
                return .init(drive: d, discIndex: o, isCommitted: false, awaitingOperator: awaitingOperator.contains(d))
            }
            return nil
        }
        let offeredSet = Set(offered.values)
        return BurnPoolSnapshot(
            active: slots,
            waiting: waiting.filter { !offeredSet.contains($0) },
            finished: finished
        )
    }
}
