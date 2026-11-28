import DriveKit
import Foundation
import Observation
import OpticalCore
import Security
import WidgetKit

// MARK: - Feeding the Desktop Widget

/// Writes what's running to the shared app-group container whenever it changes by a phase or 5
/// percentage points, and asks WidgetKit to redraw. Only a build signed by the team with the app
/// group writes: macOS hands any app a group container URL, and opening one the app isn't
/// entitled to asks the person for permission (`swift run`, ad hoc builds).
@MainActor
enum KroutonWidgetBridge {
    private static var lastTasks: [KroutonWidgetSnapshot.Task]?
    private static var lastFinished: String?
    private static var lastFinishedAt: Date?
    private static var lastReportID: UUID?

    static func start() {
        guard isSignedForAppGroup, KroutonWidgetSnapshot.fileURL != nil else { return }
        if let saved = KroutonWidgetSnapshot.read() {
            lastFinished = saved.lastFinished
            lastFinishedAt = saved.lastFinishedAt
        }
        observe()
    }

    private static func observe() {
        let manager = KroutonWindowManager.shared
        withObservationTracking {
            publish(KroutonLiveStatus.items(store: manager.store, driveManager: manager.driveManager),
                    report: manager.driveManager.completionReport)
        } onChange: {
            Task { @MainActor in observe() }
        }
    }

    private static func publish(_ items: [KroutonLiveStatus.Item], report: KroutonBurnSessionReport?) {
        let tasks = items.map { item in
            KroutonWidgetSnapshot.Task(title: item.title, detail: item.detail,
                                       fraction: item.fraction.map { ($0 * 20).rounded(.down) / 20 }, symbol: item.symbol)
        }
        // "Finished" only for a burn that succeeded, named as it was burned.
        var finishedNow = false
        if let report, report.id != lastReportID {
            lastReportID = report.id
            if report.isSuccess, lastTasks?.contains(where: { $0.symbol == "opticaldisc" }) == true {
                lastFinished = report.volumeName.isEmpty ? KroutonL10n.tr("A disc") : report.volumeName
                lastFinishedAt = Date()
                finishedNow = true
            }
        }
        guard tasks != lastTasks || finishedNow else { return }
        lastTasks = tasks
        try? KroutonWidgetSnapshot(tasks: tasks, lastFinished: lastFinished, lastFinishedAt: lastFinishedAt).write()
        WidgetCenter.shared.reloadTimelines(ofKind: KroutonWidgetSnapshot.widgetKind)
    }

    // MARK: - Signing

    /// Signed with a team identifier and the app-group entitlement naming Krouton's group.
    private static var isSignedForAppGroup: Bool {
        guard let task = SecTaskCreateFromSelf(nil),
              let groups = SecTaskCopyValueForEntitlement(task, "com.apple.security.application-groups" as CFString, nil) as? [String],
              groups.contains(KroutonWidgetSnapshot.appGroup) else { return false }
        var code: SecCode?
        var staticCode: SecStaticCode?
        var info: CFDictionary?
        guard SecCodeCopySelf([], &code) == errSecSuccess, let code,
              SecCodeCopyStaticCode(code, [], &staticCode) == errSecSuccess, let staticCode,
              SecCodeCopySigningInformation(staticCode, SecCSFlags(rawValue: kSecCSSigningInformation), &info) == errSecSuccess,
              let team = (info as? [String: Any])?[kSecCodeInfoTeamIdentifier as String] as? String else { return false }
        return KroutonWidgetSnapshot.appGroup.hasPrefix(team + ".")
    }
}
