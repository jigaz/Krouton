import DriveKit
import Foundation

// MARK: - What Krouton Is Doing Right Now

/// The work in progress that the menu bar shows: a burn, a rescue, an AVCHD build, Depot downloads.
/// Read from the stores, so the menu bar follows them with no timers of its own.
@MainActor
enum KroutonLiveStatus {
    /// When the progress item is in the menu bar (Settings › Notifications).
    enum MenuBarMode: String, CaseIterable, Identifiable, Sendable {
        case whileWorking = "While Krouton is working"
        case always = "Always"
        case never = "Never"
        var id: String { rawValue }
    }

    struct Item: Identifiable, Equatable {
        let id: String
        let title: String
        let detail: String
        /// 0…1, or nil when the length isn't known yet.
        let fraction: Double?
        let symbol: String
    }

    static func items(store: KroutonStateStore, driveManager: KroutonOpticalDriveBank) -> [Item] {
        var items: [Item] = []
        if driveManager.isExecutingQueue {
            let progress = min(1, max(0, driveManager.activeJobProgress))
            items.append(Item(id: "burn", title: driveManager.activeJobPhase.isEmpty ? KroutonL10n.tr("Burning") : driveManager.activeJobPhase,
                              detail: driveManager.activeJobDetail, fraction: progress > 0 ? progress : nil, symbol: "opticaldisc"))
        }
        if store.rescue.isRunning {
            let map = store.rescue.map
            let total = Double(map?.totalBytes ?? 0)
            items.append(Item(id: "rescue", title: KroutonL10n.tr("Rescuing a disc"), detail: store.rescue.status,
                              fraction: total > 0 ? Double(map?.currentPosition ?? 0) / total : nil, symbol: "bandage"))
        }
        if store.avchd.isRunning {
            items.append(Item(id: "avchd", title: KroutonL10n.tr("Making an AVCHD disc image"), detail: store.avchd.status,
                              fraction: store.avchd.fraction > 0 ? store.avchd.fraction : nil, symbol: "film"))
        }
        for (itemID, fraction) in store.depotDownloadProgress.sorted(by: { $0.key < $1.key }) {
            let name = store.depotItems.first { $0.id == itemID }?.title ?? itemID
            items.append(Item(id: "depot-" + itemID, title: String(format: KroutonL10n.tr("Downloading %@"), name),
                              detail: KroutonL10n.tr("Disc Image Depot"), fraction: fraction, symbol: "arrow.down.circle"))
        }
        return items
    }

    /// The menu bar label: the furthest-behind task's percentage, so it reads as time left.
    static func labelText(_ items: [Item]) -> String {
        guard !items.isEmpty else { return "" }
        let known = items.compactMap(\.fraction)
        guard let slowest = known.min() else { return items.count > 1 ? "\(items.count)" : "" }
        return "\(Int((slowest * 100).rounded()))%"
    }
}
