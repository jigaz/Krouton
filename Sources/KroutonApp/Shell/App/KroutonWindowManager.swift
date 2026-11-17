import AppKit
import DriveKit
import OpticalCore
import SwiftUI

@MainActor
final class KroutonWindowManager: ObservableObject {
    static let shared = KroutonWindowManager()
    let store = KroutonStateStore()
    let driveManager = KroutonOpticalDriveBank()
    var openWindowAction: OpenWindowAction?
    var dismissWindowAction: DismissWindowAction?

    func bindSceneActions(openWindow: OpenWindowAction, dismissWindow: DismissWindowAction) {
        self.openWindowAction = openWindow
        self.dismissWindowAction = dismissWindow
    }

    func openFloatingPhaseScopeWindow(driveID: String) {
        let targetID = driveManager.driveForID(driveID)?.id ?? driveID
        guard !targetID.isEmpty else { return }
        driveManager.setFloatingScopeOpen(for: targetID, isOpen: true)
        openWindowAction?(id: "phase-scope", value: targetID)
    }

    func closeFloatingPhaseScopeWindow(driveID: String, suckIntoMiniGraph: Bool = true) {
        driveManager.setFloatingScopeOpen(for: driveID, isOpen: false, keepInlineVisible: suckIntoMiniGraph)
        dismissWindowAction?(id: "phase-scope", value: driveID)
    }

    func openMainWindow() { openWindowAction?(id: "main") }

    func openSettingsWindow(store: KroutonStateStore, driveManager: KroutonOpticalDriveBank, pane: KroutonSettingsCategory? = nil) {
        if let p = pane { store.selectedSettingsPane = p }
        openWindowAction?(id: "settings")
    }
}

struct KroutonSceneActionBinder: ViewModifier {
    @Environment(\.openWindow) private var openWindow
    @Environment(\.dismissWindow) private var dismissWindow
    @Environment(\.scenePhase) private var scenePhase

    func body(content: Content) -> some View {
        content
            .onAppear {
                NSApplication.shared.setActivationPolicy(.regular)
                NSApplication.shared.activate(ignoringOtherApps: true)
                KroutonWindowManager.shared.bindSceneActions(openWindow: openWindow, dismissWindow: dismissWindow)
                KroutonCrashRecoveryController.shared.evaluateLaunchStateAndHydrateIfClean(store: KroutonWindowManager.shared.store)
            }
            .onChange(of: scenePhase) { _, phase in
                let active = (phase == .active)
                KroutonOSDesktopBridge.setApplicationVisiblyActive(active)
                NotificationCenter.default.post(name: active ? KroutonOSDesktopBridge.didBecomeActiveNotification : KroutonOSDesktopBridge.didResignActiveNotification, object: nil)
            }
    }
}
