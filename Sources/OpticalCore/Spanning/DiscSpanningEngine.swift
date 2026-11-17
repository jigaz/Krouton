import Foundation

/// Shared protocol for sequential optical items (Audio tracks or Data staged entries)
/// that support manual disc breaks and automatic capacity-based multi-disc spanning.
public protocol DiscBreakableItem: Identifiable, Sendable {
    var startsNewDisc: Bool { get set }
}

extension KroutonStagedFileEntry: DiscBreakableItem {}

/// Shared multi-disc spanning utilities reused across Audio CD, Data/Archival, and Burn Set workflows.
public enum DiscSpanningEngine {
    /// Returns true when `itemID` is a non-first item eligible for a manual disc break.
    public static func canToggleManualDiscBreak<Item: Identifiable>(
        before itemID: Item.ID,
        in items: [Item]
    ) -> Bool {
        guard let idx = items.firstIndex(where: { $0.id == itemID }) else { return false }
        return idx > 0
    }

    /// Toggles a manual disc break before `itemID` in `items` (no-op for index 0).
    @discardableResult
    public static func toggleManualDiscBreak<Item: DiscBreakableItem>(
        before itemID: Item.ID,
        in items: inout [Item]
    ) -> Bool {
        guard canToggleManualDiscBreak(before: itemID, in: items),
              let idx = items.firstIndex(where: { $0.id == itemID }) else { return false }
        items[idx].startsNewDisc.toggle()
        return items[idx].startsNewDisc
    }

    /// Plans sequential data discs over `entries` for the selected optical medium capacity,
    /// automatically spawning Disc 2+ when cumulative 2048-byte sectors exceed capacity and
    /// automatically collapsing trailing discs when items are removed.
    public static func planDataDiscs(
        _ entries: [KroutonStagedFileEntry],
        medium: KroutonSpanningDiscMedium
    ) -> DiscPlan<KroutonStagedFileEntry> {
        let capacity = DiscCapacity(units: max(1, medium.maxDataSectors2048))
        let planner = DiscPlanner<KroutonStagedFileEntry>(
            capacity: capacity,
            startsNewDisc: { $0.startsNewDisc }
        ) { entry, _ in
            ItemCost(units: max(1, entry.sectorsLBA), isExact: true)
        }
        return planner.plan(entries)
    }

    /// Resolves a per-disc volume identifier (`MY_DISC_D01`, `MY_DISC_D02`, etc.) or custom override.
    public static func resolvedDiscVolumeLabel(
        baseTitle: String,
        customTitle: String?,
        discNumber: Int,
        totalDiscs: Int,
        fallback: String = "KROUTON_DISC"
    ) -> String {
        if let custom = customTitle?.trimmingCharacters(in: .whitespacesAndNewlines), !custom.isEmpty {
            return custom
        }
        let trimmed = baseTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        let seed = trimmed.isEmpty ? fallback : trimmed
        guard totalDiscs > 1 else { return seed }
        return String(format: "%@_D%02d", seed, discNumber)
    }
}
