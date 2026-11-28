import SwiftUI

struct KroutonApp: App {
    @NSApplicationDelegateAdaptor(KroutonAppDelegate.self) private var appDelegate
    @State private var wm = KroutonWindowManager.shared

    init() {
        KroutonAppKitBridge.becomeRegularApp()
        KroutonWidgetBridge.start()
    }

    /// The menu bar item is there always, never, or only while something runs.
    private var menuBarStatusShown: Binding<Bool> {
        let shown: Bool
        switch wm.store.menuBarStatusMode {
        case .always: shown = true
        case .never: shown = false
        // Only the running flags, so the scene isn't rebuilt at every progress tick.
        case .whileWorking: shown = KroutonLiveStatus.isAnythingRunning(store: wm.store, driveManager: wm.driveManager)
        }
        return .constant(shown)
    }

    var body: some Scene {
        Window("Krouton", id: "main") {
            KroutonMainWorkspaceView(store: wm.store, driveManager: wm.driveManager)
                .modifier(KroutonSceneActionBinder())
        }
        .defaultSize(width: 1380, height: 880)
        .commands {
            KroutonWorkspaceCommands(wm: wm)
        }

        Window("Krouton Settings", id: "settings") {
            KroutonSettingsWindowView(store: wm.store, driveManager: wm.driveManager)
                .modifier(KroutonSceneActionBinder())
        }
        .defaultSize(width: 1120, height: 720)

        WindowGroup("Phase Scope", id: "phase-scope", for: String.self) { $driveID in
            let targetID = driveID ?? "network-spool-drive"
            KroutonFloatingPhaseScopeView(
                driveID: targetID,
                store: wm.store,
                driveManager: wm.driveManager,
                onDockInline: { KroutonWindowManager.shared.closeFloatingPhaseScopeWindow(driveID: targetID) }
            )
            .modifier(KroutonSceneActionBinder())
            .onDisappear { wm.driveManager.setFloatingScopeOpen(for: targetID, isOpen: false, keepInlineVisible: true) }
        }
        .defaultSize(width: 780, height: 520)

        Window("Track Montage Editor", id: "track-montage") {
            KroutonFloatingTrackMontageWindowView(store: wm.store)
                .modifier(KroutonSceneActionBinder())
        }
        .defaultSize(width: 960, height: 280)

        Window("Krouton User Manual", id: "user-manual") {
            KroutonUserManualWindowView(store: wm.store, driveManager: wm.driveManager)
                .modifier(KroutonSceneActionBinder())
        }
        .defaultSize(width: 980, height: 660)

        Settings {
            KroutonSettingsWindowView(store: wm.store, driveManager: wm.driveManager)
        }

        MenuBarExtra(isInserted: menuBarStatusShown) {
            KroutonMenuBarStatusView(store: wm.store, driveManager: wm.driveManager)
        } label: {
            KroutonMenuBarStatusLabel(store: wm.store, driveManager: wm.driveManager)
        }
        .menuBarExtraStyle(.window)
    }
}
