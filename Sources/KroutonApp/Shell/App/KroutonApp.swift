import SwiftUI
import AppKit

struct KroutonApp: App {
    @NSApplicationDelegateAdaptor(KroutonAppDelegate.self) private var appDelegate
    @StateObject private var wm = KroutonWindowManager.shared

    init() {
        NSApplication.shared.setActivationPolicy(.regular)
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

        Settings {
            KroutonSettingsWindowView(store: wm.store, driveManager: wm.driveManager)
        }
    }
}
