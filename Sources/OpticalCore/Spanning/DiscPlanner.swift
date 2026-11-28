import Foundation

// MARK: - Disc Planner
//
// One spanning algorithm for every list-based format. The planner knows nothing
// about audio, files or formats; a workspace describes its items through three
// small closures:
//
//   cost            how many units an item adds, given what precedes it on the disc
//   startsNewDisc   whether the user put a manual break before it
//   capacity        units per disc and, where the format has one, an item limit
//
// Design choices worth copying elsewhere in the app:
//
//   - "Not measured yet" is a value (`nil` cost), not a stand-in number. The
//     plan reports it and refuses to invent disc boundaries from it.
//   - "Measured approximately" is also a value (`isExact == false`). The plan is
//     usable for display and marked provisional; burning needs exact costs.
//   - Problems come back as data (`issues`), not as clamped numbers or logs.
//   - The plan is derived, never stored. Persist the flat list; recompute this.

/// How much room an item takes on a disc, in the capacity's units.
public struct ItemCost: Sendable, Equatable {
    /// The item's size.
    public var units: Int64
    /// False while the figure comes from a header probe or a bitrate estimate.
    public var isExact: Bool

    public init(units: Int64, isExact: Bool) {
        self.units = units
        self.isExact = isExact
    }

    /// A measured cost.
    public static func exact(_ units: Int64) -> ItemCost { ItemCost(units: units, isExact: true) }
    /// A cost from an estimate; a plan that uses one is provisional.
    public static func estimated(_ units: Int64) -> ItemCost { ItemCost(units: units, isExact: false) }
}

/// How much one disc holds.
public struct DiscCapacity: Sendable, Equatable {
    /// Red Book frames for audio; sectors or bytes for data. The planner does not care which.
    public var units: Int64
    /// 99 for anything with a CD track table; `.max` otherwise.
    public var maxItems: Int

    public init(units: Int64, maxItems: Int = .max) {
        self.units = units
        self.maxItems = maxItems
    }
}

/// Why a disc in a plan starts where it does.
public enum DiscBreakReason: Sendable, Equatable {
    case firstDisc
    case capacity   // the next item did not fit
    case itemLimit  // the disc already held `maxItems`
    case manual     // the user asked for a break here
}

/// One disc of a plan: its items in order and how full it is.
public struct PlannedDisc<Item: Identifiable & Sendable>: Identifiable, Sendable {
    /// The disc's number, from 1.
    public let number: Int
    public let items: [Item]
    /// Units the items take, counting their effect on each other.
    public let usedUnits: Int64
    public let capacityUnits: Int64
    /// Why this disc starts here.
    public let startedBecause: DiscBreakReason

    public var id: Int { number }
}

/// A problem that stops a plan from being burned.
public enum DiscPlanIssue<ID: Hashable & Sendable>: Sendable, Equatable {
    /// These items have no cost yet. The plan holds everything on one
    /// provisional disc until they do, so headers never appear and then move.
    case unmeasured([ID])
    /// A single item is larger than a blank disc. It gets a disc to itself so
    /// the list stays readable, but the plan cannot be burned.
    case itemExceedsDisc(id: ID, units: Int64, capacity: Int64)
}

/// Items split into discs, with any problems. Derived from the list each time; never saved.
public struct DiscPlan<Item: Identifiable & Sendable>: Sendable where Item.ID: Sendable {
    public let discs: [PlannedDisc<Item>]
    public let issues: [DiscPlanIssue<Item.ID>]
    /// True while any cost is an estimate. Show it; do not burn from it.
    public let isProvisional: Bool

    /// True when there is at least one disc, no issue and no estimated cost.
    public var isBurnable: Bool { !discs.isEmpty && issues.isEmpty && !isProvisional }
}

/// Splits an ordered list of items into discs, in order, starting a new disc when the next item
/// doesn't fit, the item limit is reached, or the user put a break there.
public struct DiscPlanner<Item: Identifiable & Sendable> where Item.ID: Sendable {
    /// What each disc holds.
    public var capacity: DiscCapacity
    /// Cost of `item` when it follows `previous` on the same disc, or when it is
    /// first on a disc (`previous == nil`). Return nil if it has not been measured.
    ///
    /// Audio uses `previous`: a 2 s pause adds 150 frames, a crossfade subtracts
    /// the overlap. Data ignores it.
    public var cost: (_ item: Item, _ previous: Item?) -> ItemCost?
    /// Whether the user put a manual disc break before an item.
    public var startsNewDisc: (Item) -> Bool

    public init(
        capacity: DiscCapacity,
        startsNewDisc: @escaping (Item) -> Bool = { _ in false },
        cost: @escaping (_ item: Item, _ previous: Item?) -> ItemCost?
    ) {
        self.capacity = capacity
        self.startsNewDisc = startsNewDisc
        self.cost = cost
    }

    /// Plans `items` in order. While any item has no cost, everything stays on one provisional
    /// disc.
    public func plan(_ items: [Item]) -> DiscPlan<Item> {
        guard !items.isEmpty else { return DiscPlan(discs: [], issues: [], isProvisional: false) }

        let unmeasured = items.filter { cost($0, nil) == nil }.map(\.id)
        if !unmeasured.isEmpty {
            let holding = PlannedDisc(number: 1, items: items, usedUnits: 0,
                                      capacityUnits: capacity.units, startedBecause: .firstDisc)
            return DiscPlan(discs: [holding], issues: [.unmeasured(unmeasured)], isProvisional: true)
        }

        var discs: [PlannedDisc<Item>] = []
        var issues: [DiscPlanIssue<Item.ID>] = []
        var current: [Item] = []
        var used: Int64 = 0
        var reason = DiscBreakReason.firstDisc
        var sawEstimate = false

        func closeDisc() {
            discs.append(PlannedDisc(number: discs.count + 1, items: current, usedUnits: used,
                                     capacityUnits: capacity.units, startedBecause: reason))
        }

        for item in items {
            guard let alone = cost(item, nil) else { continue } // unreachable: checked above
            sawEstimate = sawEstimate || !alone.isExact
            if alone.units > capacity.units {
                issues.append(.itemExceedsDisc(id: item.id, units: alone.units, capacity: capacity.units))
            }
            guard let previous = current.last else {
                current = [item]
                used = alone.units
                continue
            }

            let appended = cost(item, previous) ?? alone
            sawEstimate = sawEstimate || !appended.isExact
            let breakReason: DiscBreakReason? =
                startsNewDisc(item) ? .manual
                : current.count >= capacity.maxItems ? .itemLimit
                : used + appended.units > capacity.units ? .capacity
                : nil

            if let breakReason {
                closeDisc()
                reason = breakReason
                current = [item]
                used = alone.units
            } else {
                current.append(item)
                used += appended.units
            }
        }
        closeDisc()
        return DiscPlan(discs: discs, issues: issues, isProvisional: sawEstimate)
    }
}

// MARK: - Repacking (data and archival workspaces only)

/// First-fit decreasing, expressed as a REORDER of the flat list.
///
/// The model stays a flat, sequential list: applying the returned order and
/// running `DiscPlanner.plan` gives exactly these discs. So "Repack to use fewer
/// discs" is one undoable list edit, not a second layout mode.
///
/// Only valid where cost does not depend on neighbours and order carries no
/// meaning. Never offer it for audio, video or playlists.
public enum DiscRepacker {
    /// A new order for the list, and how many discs it plans to.
    public struct Proposal<Item> {
        public let order: [Item]
        public let discCount: Int
    }

    private struct Bin {
        var free: Int64
        var indices: [Int]
        var isOversize: Bool
    }

    /// Returns nil when repacking would not reduce the number of discs, so the
    /// UI can disable the action instead of shuffling the list for nothing.
    public static func proposal<Item>(
        for items: [Item],
        capacityUnits: Int64,
        currentDiscCount: Int,
        size: (Item) -> Int64
    ) -> Proposal<Item>? {
        let sizes = items.map(size)
        // Largest first; ties keep their original order so the result is deterministic.
        let bySize = items.indices.sorted { sizes[$0] != sizes[$1] ? sizes[$0] > sizes[$1] : $0 < $1 }

        var bins: [Bin] = []
        for index in bySize {
            let needed = sizes[index]
            if let fit = bins.firstIndex(where: { !$0.isOversize && $0.free >= needed }) {
                bins[fit].free -= needed
                bins[fit].indices.append(index)
            } else {
                bins.append(Bin(free: capacityUnits - needed, indices: [index], isOversize: needed > capacityUnits))
            }
        }
        guard bins.count < currentDiscCount else { return nil }

        // Inside a disc, keep the user's original relative order. Do not reorder
        // the discs themselves: the sequential planner reproduces these bins only
        // in first-fit order.
        let order = bins.flatMap { $0.indices.sorted() }.map { items[$0] }
        return Proposal(order: order, discCount: bins.count)
    }
}

// krouton-verify Suite 22 checks the planner (manual breaks, the item limit, oversize items)
// and that a repack proposal is offered only when it saves a disc.
