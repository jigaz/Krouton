#if canImport(XCTest)
import XCTest
#endif
import BurnKit
import Foundation
import OpticalCore

// MARK: - Burn Pool & Coordinator

/// A burner card as the pool sees it, without the app.
private struct Card: KroutonPoolSlotCard, Equatable {
    let id = UUID()
    var isPooledBurner = true
    var targetDriveID: String
    var assignedPoolTicket: KroutonPoolBurnTicket?
    var pendingApprovalTicket: KroutonPoolBurnTicket?
    var spannedDiscNumber: Int?
    var completedCopies = 0
}

private func tickets(discs: Int, copies: Int) -> [KroutonPoolBurnTicket] {
    KroutonDrivePoolState.buildTickets(spannedVolumeLabels: (1...discs).map { "DISC_\($0)" },
                                       perDiscBytes: [700_000_000], totalCopies: copies)
}

final class BurnQueuePoolTests: XCTestCase {
    func testFillGivesEachBurnerOneTicketInOrder() {
        var pool = KroutonBurnQueuePool(cards: [Card(targetDriveID: "a"), Card(targetDriveID: "b")], waiting: [], completedTicketCount: 4)
        pool.fill(with: tickets(discs: 3, copies: 1))
        XCTAssertEqual(pool.cards.map { $0.assignedPoolTicket?.spannedDiscNumber }, [1, 2])
        XCTAssertEqual(pool.cards.map(\.spannedDiscNumber), [1, 2])
        XCTAssertEqual(pool.waiting.map(\.spannedDiscNumber), [3])
        XCTAssertEqual(pool.completedTicketCount, 0)
    }

    func testFillSkipsCardsThatAreNotBurners() {
        var rip = Card(targetDriveID: "")
        rip.isPooledBurner = false
        var pool = KroutonBurnQueuePool(cards: [rip, Card(targetDriveID: "a")], waiting: [], completedTicketCount: 0)
        pool.fill(with: tickets(discs: 1, copies: 2))
        XCTAssertTrue(pool.cards[0].assignedPoolTicket == nil)
        XCTAssertEqual(pool.cards[1].assignedPoolTicket?.copyNumber, 1)
        XCTAssertEqual(pool.waiting.count, 1)
    }

    func testAdvanceAutoAssignTakesTheNextTicketAndCountsTheFinishedOne() {
        var pool = KroutonBurnQueuePool(cards: [Card(targetDriveID: "a")], waiting: [], completedTicketCount: 0)
        pool.fill(with: tickets(discs: 1, copies: 3))
        let card = pool.cards[0].id
        let next = pool.advanceAfterBurn(cardID: card, mode: .autoAssign)
        XCTAssertEqual(next?.copyNumber, 2)
        XCTAssertEqual(pool.cards[0].assignedPoolTicket?.copyNumber, 2)
        XCTAssertEqual(pool.cards[0].completedCopies, 1)
        XCTAssertEqual(pool.completedTicketCount, 1)
    }

    func testAdvanceAskOperatorHoldsTheNextTicketForApproval() {
        var pool = KroutonBurnQueuePool(cards: [Card(targetDriveID: "a")], waiting: [], completedTicketCount: 0)
        pool.fill(with: tickets(discs: 2, copies: 1))
        let card = pool.cards[0].id
        pool.advanceAfterBurn(cardID: card, mode: .askOperator)
        XCTAssertTrue(pool.cards[0].assignedPoolTicket == nil)
        XCTAssertEqual(pool.cards[0].pendingApprovalTicket?.spannedDiscNumber, 2)
        pool.approvePending(cardID: card)
        XCTAssertEqual(pool.cards[0].assignedPoolTicket?.spannedDiscNumber, 2)
        XCTAssertEqual(pool.cards[0].spannedDiscNumber, 2)
    }

    func testAdvancePrefersATicketPinnedToTheDrive() {
        var all = tickets(discs: 3, copies: 1)
        all[2].preferredDriveID = "a"
        var pool = KroutonBurnQueuePool(cards: [Card(targetDriveID: "a")], waiting: [], completedTicketCount: 0)
        pool.fill(with: all)
        XCTAssertEqual(pool.advanceAfterBurn(cardID: pool.cards[0].id, mode: .autoAssign)?.spannedDiscNumber, 3)
    }

    func testSkipReturnsThePendingTicketInSequence() {
        var pool = KroutonBurnQueuePool(cards: [Card(targetDriveID: "a")], waiting: [], completedTicketCount: 0)
        pool.fill(with: tickets(discs: 3, copies: 1))
        let card = pool.cards[0].id
        pool.advanceAfterBurn(cardID: card, mode: .askOperator)
        pool.skipPending(cardID: card)
        XCTAssertTrue(pool.cards[0].pendingApprovalTicket == nil)
        XCTAssertEqual(pool.waiting.map(\.spannedDiscNumber), [2, 3])
    }

    func testPromoteSwapsWhatTheCardHeldBackIntoTheWaitingTickets() {
        var pool = KroutonBurnQueuePool(cards: [Card(targetDriveID: "a")], waiting: [], completedTicketCount: 0)
        pool.fill(with: tickets(discs: 3, copies: 1))
        let third = pool.waiting[1].id
        pool.promote(third, toCardID: pool.cards[0].id)
        XCTAssertEqual(pool.cards[0].assignedPoolTicket?.spannedDiscNumber, 3)
        XCTAssertEqual(pool.waiting.map(\.spannedDiscNumber), [1, 2])
    }

    func testDemoteEmptiesTheCard() {
        var pool = KroutonBurnQueuePool(cards: [Card(targetDriveID: "a")], waiting: [], completedTicketCount: 0)
        pool.fill(with: tickets(discs: 2, copies: 1))
        pool.demote(cardID: pool.cards[0].id)
        XCTAssertTrue(pool.cards[0].assignedPoolTicket == nil)
        XCTAssertTrue(pool.cards[0].spannedDiscNumber == nil)
        XCTAssertEqual(pool.waiting.map(\.spannedDiscNumber), [1, 2])
    }
}

final class BurnCoordinatorTests: XCTestCase {
    @MainActor func testAFailedBurnChangesNothing() {
        var pool = KroutonBurnQueuePool(cards: [Card(targetDriveID: "a")], waiting: [], completedTicketCount: 0)
        pool.fill(with: tickets(discs: 1, copies: 3))
        let before = pool.cards
        let step = KroutonBurnCoordinator.stepAfterBurn(of: pool.cards[0], copiesToBurn: 3, succeeded: false, pool: &pool,
                                                        mode: .autoAssign, autoLoadNextDisc: true)
        XCTAssertEqual(step, .finished)
        XCTAssertEqual(pool.cards, before)
    }

    @MainActor func testPoolWithAutoLoadWaitsForTheNextBlank() {
        var pool = KroutonBurnQueuePool(cards: [Card(targetDriveID: "a")], waiting: [], completedTicketCount: 0)
        pool.fill(with: tickets(discs: 1, copies: 3))
        let step = KroutonBurnCoordinator.stepAfterBurn(of: pool.cards[0], copiesToBurn: 3, succeeded: true, pool: &pool,
                                                        mode: .autoAssign, autoLoadNextDisc: true)
        XCTAssertEqual(step, .waitForNextBlank(completedCopy: 1, totalCopies: 3))
        XCTAssertEqual(pool.cards[0].assignedPoolTicket?.copyNumber, 2)
    }

    @MainActor func testPoolWithoutAutoLoadOnlyAdvances() {
        var pool = KroutonBurnQueuePool(cards: [Card(targetDriveID: "a")], waiting: [], completedTicketCount: 0)
        pool.fill(with: tickets(discs: 1, copies: 2))
        let step = KroutonBurnCoordinator.stepAfterBurn(of: pool.cards[0], copiesToBurn: 2, succeeded: true, pool: &pool,
                                                        mode: .autoAssign, autoLoadNextDisc: false)
        XCTAssertEqual(step, .finished)
        XCTAssertEqual(pool.cards[0].assignedPoolTicket?.copyNumber, 2)
    }

    @MainActor func testAskOperatorNeverStartsTheNextDiscOnItsOwn() {
        var pool = KroutonBurnQueuePool(cards: [Card(targetDriveID: "a")], waiting: [], completedTicketCount: 0)
        pool.fill(with: tickets(discs: 2, copies: 1))
        let step = KroutonBurnCoordinator.stepAfterBurn(of: pool.cards[0], copiesToBurn: 1, succeeded: true, pool: &pool,
                                                        mode: .askOperator, autoLoadNextDisc: true)
        XCTAssertEqual(step, .finished)
        XCTAssertEqual(pool.cards[0].pendingApprovalTicket?.spannedDiscNumber, 2)
    }

    @MainActor func testCopiesWithoutAPoolCountUpThenReset() {
        var pool = KroutonBurnQueuePool(cards: [Card(targetDriveID: "a")], waiting: [], completedTicketCount: 0)
        var steps: [KroutonAfterBurnStep] = []
        for _ in 0..<3 {
            steps.append(KroutonBurnCoordinator.stepAfterBurn(of: pool.cards[0], copiesToBurn: 3, succeeded: true, pool: &pool,
                                                              mode: .autoAssign, autoLoadNextDisc: true))
        }
        XCTAssertEqual(steps, [.waitForNextBlank(completedCopy: 1, totalCopies: 3),
                               .waitForNextBlank(completedCopy: 2, totalCopies: 3), .finished])
        XCTAssertEqual(pool.cards[0].completedCopies, 0)
    }

    @MainActor func testASetCantStartWhileTheDriveBankIsBusy() {
        let coordinator = KroutonBurnCoordinator()
        XCTAssertFalse(coordinator.beginSet(title: "Photos", driveBankIsBusy: true) == nil)
        XCTAssertFalse(coordinator.isSetRunning)
    }

    @MainActor func testOnlyOneSetAtATime() {
        let coordinator = KroutonBurnCoordinator()
        XCTAssertTrue(coordinator.beginSet(title: "Photos", driveBankIsBusy: false) == nil)
        XCTAssertTrue(coordinator.isSetRunning)
        XCTAssertFalse(coordinator.beginSet(title: "Music", driveBankIsBusy: false) == nil)
        coordinator.endSet()
        XCTAssertFalse(coordinator.isSetRunning)
        XCTAssertTrue(coordinator.beginSet(title: "Music", driveBankIsBusy: false) == nil)
    }
}
