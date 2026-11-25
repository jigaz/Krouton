import Foundation

// MARK: - Multi-Burner Work-Stealing Pool & Waiting Queue State Machine

public enum KroutonPoolDispatchMode: String, CaseIterable, Identifiable, Codable, Sendable {
    case autoAssign = "Auto-Assign"
    case askOperator = "Ask / Manual"

    public var id: String { rawValue }

    public var sfSymbol: String {
        switch self {
        case .autoAssign: return "bolt.horizontal.circle.fill"
        case .askOperator: return "hand.raised.circle.fill"
        }
    }

    public var summaryText: String {
        switch self {
        case .autoAssign:
            return "Automatically promotes the next waiting disc into whichever burner finishes first (fastest burner prioritized)."
        case .askOperator:
            return "Holds waiting discs below the divider until you approve or manually promote a task into an available burner."
        }
    }
}

public struct KroutonPoolBurnTicket: Identifiable, Hashable, Codable, Sendable {
    public var id: UUID
    public var sequenceNumber: Int
    public var spannedDiscNumber: Int
    public var totalSpannedDiscs: Int
    public var copyNumber: Int
    public var totalCopies: Int
    public var volumeLabel: String
    public var estimatedBytes: Int64
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

public struct KroutonPoolDriveDescriptor: Identifiable, Hashable, Codable, Sendable {
    public let id: String
    public let displayName: String
    public let maxWriteSpeedX: Double

    public init(id: String, displayName: String, maxWriteSpeedX: Double) {
        self.id = id
        self.displayName = displayName
        self.maxWriteSpeedX = max(1.0, maxWriteSpeedX)
    }
}

public struct KroutonDrivePoolState: Equatable, Codable, Sendable {
    public private(set) var assignedByDriveID: [String: KroutonPoolBurnTicket] = [:]
    public private(set) var pendingApprovalByDriveID: [String: KroutonPoolBurnTicket] = [:]
    public private(set) var completedCountByDriveID: [String: Int] = [:]
    public private(set) var waitingTasks: [KroutonPoolBurnTicket] = []
    public private(set) var completedTickets: [KroutonPoolBurnTicket] = []

    public init() {}

    public var totalRemainingCount: Int {
        assignedByDriveID.count + pendingApprovalByDriveID.count + waitingTasks.count
    }

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

    /// Returns a drive's pending-approval or unstarted assigned ticket back to the front of `waitingTasks`
    /// so another available burner can claim it.
    public mutating func returnTicketToWaitingPool(fromDriveID driveID: String) {
        if var pending = pendingApprovalByDriveID.removeValue(forKey: driveID) {
            pending.preferredDriveID = nil
            waitingTasks.insert(pending, at: 0)
            sortWaitingTasksBySequence()
        } else if var assigned = assignedByDriveID.removeValue(forKey: driveID) {
            assigned.preferredDriveID = nil
            waitingTasks.insert(assigned, at: 0)
            sortWaitingTasksBySequence()
        }
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

// MARK: - Late-Binding BurnClaimLedger

public struct BurnClaimLedger: Sendable, Equatable {
    public private(set) var waiting: [Int]
    public private(set) var offered: [DriveID: Int] = [:]
    public private(set) var committed: [DriveID: Int] = [:]
    public private(set) var awaitingOperator: Set<DriveID> = []
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

    public mutating func markAwaitingOperator(_ drive: DriveID) {
        awaitingOperator.insert(drive)
    }

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

    public mutating func withdraw(drive: DriveID) {
        offered.removeValue(forKey: drive)
        awaitingOperator.remove(drive)
    }

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
