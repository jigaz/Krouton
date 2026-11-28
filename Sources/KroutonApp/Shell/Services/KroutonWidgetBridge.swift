import DriveKit
import Foundation
import Observation
import OpticalCore
import WidgetKit

// MARK: - Feeding the Desktop Widget

/// Writes what's running to the shared app-group container whenever it changes by a phase or 5
/// percentage points, and asks WidgetKit to redraw. A build without the app group (`swift run`)
/// has no container, so nothing is written.
@MainActor
enum KroutonWidgetBridge {
    private static var lastTasks: [KroutonWidgetSnapshot.Task]?
    private static var lastFinished: String?
    private static var lastFinishedAt: Date?

    static func start() {
        guard KroutonWidgetSnapshot.fileURL != nil else { return }
        if let saved = KroutonWidgetSnapshot.read() {
            lastFinished = saved.lastFinished
            lastFinishedAt = saved.lastFinishedAt
        }
        observe()
    }

    private static func observe() {
        let manager = KroutonWindowManager.shared
        withObservationTracking {
            publish(KroutonLiveStatus.items(store: manager.store, driveManager: manager.driveManager), store: manager.store)
        } onChange: {
            Task { @MainActor in observe() }
        }
    }

    private static func publish(_ items: [KroutonLiveStatus.Item], store: KroutonStateStore) {
        let tasks = items.map { item in
            KroutonWidgetSnapshot.Task(title: item.title, detail: item.detail,
                                       fraction: item.fraction.map { ($0 * 20).rounded(.down) / 20 }, symbol: item.symbol)
        }
        guard tasks != lastTasks else { return }
        if let previous = lastTasks, previous.contains(where: { $0.symbol == "opticaldisc" }),
           !tasks.contains(where: { $0.symbol == "opticaldisc" }) {
            lastFinished = store.discVolumeTitle.isEmpty ? KroutonL10n.tr("A disc") : store.discVolumeTitle
            lastFinishedAt = Date()
        }
        lastTasks = tasks
        try? KroutonWidgetSnapshot(tasks: tasks, lastFinished: lastFinished, lastFinishedAt: lastFinishedAt).write()
        WidgetCenter.shared.reloadTimelines(ofKind: KroutonWidgetSnapshot.widgetKind)
    }
}
