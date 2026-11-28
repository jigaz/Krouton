import Foundation
import OpticalCore

// MARK: - Destination Queue Burn Pool

/// A burner card in the destination queue, as the pool sees it: which drive it is, which
/// ticket (disc of a set, copy of a run) it is burning or offered, and how many it has done.
public protocol KroutonPoolSlotCard {
    var id: UUID { get }
    /// True for a card that burns on a drive of this Mac; only those take tickets.
    var isPooledBurner: Bool { get }
    var targetDriveID: String { get }
    var assignedPoolTicket: KroutonPoolBurnTicket? { get set }
    var pendingApprovalTicket: KroutonPoolBurnTicket? { get set }
    var spannedDiscNumber: Int? { get set }
    var completedCopies: Int { get set }
}

/// The burn pool of the destination queue: each burner card holds the ticket it burns next
/// (or one waiting for the operator's approval), and the rest wait below the divider.
///
/// Until 2026-11-27 this lived in `KroutonStateStore`; it moved here unchanged so it can be
/// tested, and so `KroutonBurnCoordinator` decides what follows a burn in one place.
public struct KroutonBurnQueuePool<Card: KroutonPoolSlotCard> {
    public var cards: [Card]
    public var waiting: [KroutonPoolBurnTicket]
    /// Tickets finished since the pool was last filled.
    public var completedTicketCount: Int

    public init(cards: [Card], waiting: [KroutonPoolBurnTicket], completedTicketCount: Int) {
        self.cards = cards
        self.waiting = waiting
        self.completedTicketCount = completedTicketCount
    }

    private var burnerIndices: [Int] { cards.indices.filter { cards[$0].isPooledBurner } }

    // MARK: - Filling

    /// Gives each burner card, in the cards' order, the next ticket; the rest wait. Clears
    /// pending approvals and the finished count.
    public mutating func fill(with tickets: [KroutonPoolBurnTicket]) {
        completedTicketCount = 0
        var remaining = tickets
        for index in burnerIndices {
            cards[index].pendingApprovalTicket = nil
            if !remaining.isEmpty {
                assign(remaining.removeFirst(), to: index)
            } else {
                cards[index].assignedPoolTicket = nil
                cards[index].spannedDiscNumber = nil
            }
        }
        waiting = remaining
    }

    // MARK: - Moving Tickets

    /// Moves a waiting ticket onto a burner card: the one given, else the first idle one, else
    /// the first. Whatever that card held goes back to the waiting tickets.
    public mutating func promote(_ ticketID: UUID, toCardID targetCardID: UUID? = nil) {
        guard let waitIndex = waiting.firstIndex(where: { $0.id == ticketID }) else { return }
        let burners = burnerIndices
        guard !burners.isEmpty else { return }
        let chosen: Int = {
            if let targetCardID, let match = cards.firstIndex(where: { $0.id == targetCardID && $0.isPooledBurner }) {
                return match
            }
            if let idle = burners.first(where: { cards[$0].assignedPoolTicket == nil && cards[$0].pendingApprovalTicket == nil }) {
                return idle
            }
            return burners[0]
        }()
        let promoted = waiting.remove(at: waitIndex)
        if let previousPending = cards[chosen].pendingApprovalTicket {
            waiting.insert(previousPending, at: 0)
            cards[chosen].pendingApprovalTicket = nil
        }
        if let previousAssigned = cards[chosen].assignedPoolTicket {
            waiting.insert(previousAssigned, at: 0)
        }
        sortWaiting()
        assign(promoted, to: chosen)
    }

    /// Moves a card's tickets back to the waiting tickets.
    public mutating func demote(cardID: UUID) {
        guard let index = cards.firstIndex(where: { $0.id == cardID }) else { return }
        if let pending = cards[index].pendingApprovalTicket {
            waiting.insert(pending, at: 0)
            cards[index].pendingApprovalTicket = nil
        }
        if let assigned = cards[index].assignedPoolTicket {
            waiting.insert(assigned, at: 0)
            cards[index].assignedPoolTicket = nil
            cards[index].spannedDiscNumber = nil
        }
        sortWaiting()
    }

    /// A card finished its ticket: counts it, then gives the card the next waiting ticket (one
    /// pinned to its drive first). With `.askOperator` the ticket waits for approval instead.
    /// Returns the ticket the card got, if any.
    @discardableResult
    public mutating func advanceAfterBurn(cardID: UUID, mode: KroutonPoolDispatchMode) -> KroutonPoolBurnTicket? {
        guard let index = cards.firstIndex(where: { $0.id == cardID }) else { return nil }
        if cards[index].assignedPoolTicket != nil {
            completedTicketCount += 1
            cards[index].completedCopies += 1
        }
        cards[index].assignedPoolTicket = nil
        cards[index].pendingApprovalTicket = nil
        cards[index].spannedDiscNumber = nil

        guard !waiting.isEmpty else { return nil }
        let driveID = cards[index].targetDriveID
        let nextIndex = waiting.firstIndex(where: { $0.preferredDriveID == driveID })
            ?? waiting.firstIndex(where: { $0.preferredDriveID == nil })
            ?? 0
        let next = waiting.remove(at: nextIndex)
        switch mode {
        case .autoAssign: assign(next, to: index)
        case .askOperator: cards[index].pendingApprovalTicket = next
        }
        return next
    }

    /// The operator approves a card's pending ticket, or, with none pending, gives it the first
    /// waiting one.
    public mutating func approvePending(cardID: UUID) {
        guard let index = cards.firstIndex(where: { $0.id == cardID }) else { return }
        if let pending = cards[index].pendingApprovalTicket {
            cards[index].pendingApprovalTicket = nil
            assign(pending, to: index)
        } else if !waiting.isEmpty {
            assign(waiting.removeFirst(), to: index)
        }
    }

    /// The operator skips this card for its pending ticket, which goes back to the waiting tickets.
    public mutating func skipPending(cardID: UUID) {
        guard let index = cards.firstIndex(where: { $0.id == cardID }),
              let pending = cards[index].pendingApprovalTicket else { return }
        cards[index].pendingApprovalTicket = nil
        waiting.insert(pending, at: 0)
        sortWaiting()
    }

    // MARK: - Helpers

    private mutating func assign(_ ticket: KroutonPoolBurnTicket, to index: Int) {
        cards[index].assignedPoolTicket = ticket
        cards[index].spannedDiscNumber = ticket.totalSpannedDiscs > 1 ? ticket.spannedDiscNumber : nil
    }

    private mutating func sortWaiting() {
        waiting.sort { $0.sequenceNumber < $1.sequenceNumber }
    }
}
