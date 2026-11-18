import AppKit
import DriveKit
import Observation
import OpticalCore
import SwiftUI

@MainActor
// MARK: - KroutonAppDelegate

final class KroutonAppDelegate: NSObject, NSApplicationDelegate {
    private var appearanceObserver: NSKeyValueObservation?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApplication.shared.setActivationPolicy(.regular)
        let store = KroutonWindowManager.shared.store
        applyDynamicDockIcon(for: store)
        bindBurnTelemetryAndPowerGuard()

        bindDockIconObservation()

        appearanceObserver = NSApp.observe(\.effectiveAppearance, options: [.new]) { [weak self] _, _ in
            Task { @MainActor in
                guard let self else { return }
                self.applyDynamicDockIcon(for: KroutonWindowManager.shared.store)
            }
        }

        DistributedNotificationCenter.default().addObserver(
            forName: Notification.Name("AppleInterfaceThemeChangedNotification"),
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                guard let self else { return }
                self.applyDynamicDockIcon(for: KroutonWindowManager.shared.store)
            }
        }

        NSApplication.shared.activate(ignoringOtherApps: true)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            if NSApplication.shared.windows.filter({ $0.isVisible }).isEmpty {
                KroutonWindowManager.shared.openMainWindow()
            }
            NSApplication.shared.activate(ignoringOtherApps: true)
            NSApplication.shared.windows.first?.makeKeyAndOrderFront(nil)
        }
    }

    func applyDynamicDockIcon(for store: KroutonStateStore) {
        let styleRaw = store.iconWidgetStyle.rawValue.lowercased()

        // When set to Default/System, let macOS natively switch Default/Dark/Tinted/Clear via Assets.car!
        if styleRaw == "default" || styleRaw == "system" || styleRaw == "auto" {
            NSApplication.shared.applicationIconImage = nil
            NSApplication.shared.dockTile.display()
            return
        }

        let iconStem: String
        var shouldTint = false

        if styleRaw.contains("clear") {
            iconStem = "AppIcon-Clear"
        } else if styleRaw.contains("tint") {
            iconStem = "AppIcon-Tinted"
            shouldTint = true
        } else if styleRaw.contains("dark") {
            iconStem = "AppIcon-Dark"
        } else if styleRaw.contains("light") {
            iconStem = "AppIcon-Light"
        } else {
            NSApplication.shared.applicationIconImage = nil
            NSApplication.shared.dockTile.display()
            return
        }

        let candidates: [URL] = [
            Bundle.main.url(forResource: iconStem, withExtension: "icns"),
            Bundle.module.url(forResource: iconStem, withExtension: "icns"),
            Bundle.main.url(forResource: "AppIcon", withExtension: "icns"),
            Bundle.module.url(forResource: "AppIcon", withExtension: "icns")
        ].compactMap { $0 }

        guard let icnsURL = candidates.first(where: { FileManager.default.fileExists(atPath: $0.path) }),
              let baseIcon = NSImage(contentsOf: icnsURL) else { return }

        if shouldTint {
            NSApplication.shared.applicationIconImage = Self.tintMonochromeIcon(baseIcon, with: NSColor(store.activeAccent))
        } else {
            NSApplication.shared.applicationIconImage = baseIcon
        }
        NSApplication.shared.dockTile.display()
    }

    private static func tintMonochromeIcon(_ source: NSImage, with accent: NSColor) -> NSImage {
        let size = NSSize(width: 512, height: 512)
        let out = NSImage(size: size)
        out.lockFocus()
        let rect = NSRect(origin: .zero, size: size)
        source.draw(in: rect, from: .zero, operation: .sourceOver, fraction: 1.0)
        accent.withAlphaComponent(0.65).setFill()
        rect.fill(using: .sourceAtop)
        out.unlockFocus()
        return out
    }

    func bindDockIconObservation() {
        let store = KroutonWindowManager.shared.store
        withObservationTracking {
            _ = store.iconWidgetStyle
            _ = store.selectedAccentIndex
            _ = store.selectedCategory
            _ = store.selectedTaskID
            _ = store.appearanceMode
            self.applyDynamicDockIcon(for: store)
        } onChange: { [weak self] in
            Task { @MainActor [weak self] in
                self?.bindDockIconObservation()
            }
        }
    }

    func bindBurnTelemetryAndPowerGuard() {
        let dm = KroutonWindowManager.shared.driveManager
        withObservationTracking {
            if dm.isExecutingQueue {
                KroutonPowerAndBurnAssertion.shared.acquire(reason: dm.activeJobPhase.isEmpty ? "Krouton Optical Burn" : dm.activeJobPhase)
                let pct = Int((min(1.0, max(0.0, dm.activeJobProgress)) * 100.0).rounded())
                NSApplication.shared.dockTile.badgeLabel = pct > 0 ? "\(pct)%" : "BURN"
            } else {
                KroutonPowerAndBurnAssertion.shared.releaseAssertion()
                if NSApplication.shared.dockTile.badgeLabel != nil {
                    NSApplication.shared.dockTile.badgeLabel = nil
                }
            }
        } onChange: { [weak self] in
            Task { @MainActor [weak self] in
                self?.bindBurnTelemetryAndPowerGuard()
            }
        }
    }

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        let dm = KroutonWindowManager.shared.driveManager
        if dm.isExecutingQueue {
            let store = KroutonWindowManager.shared.store
            store.rejectedDropNotice = KroutonL10n.tr("Active optical operation in progress — abort the job in the Destination Queue before quitting so media is not damaged.")
            KroutonOSDesktopBridge.playAcousticCue()
            KroutonWindowManager.shared.openMainWindow()
            NSApplication.shared.activate(ignoringOtherApps: true)
            return .terminateCancel
        }
        KroutonPowerAndBurnAssertion.shared.releaseAssertion()
        return .terminateNow
    }

    func application(_ application: NSApplication, open urls: [URL]) {
        let store = KroutonWindowManager.shared.store
        for url in urls where FileManager.default.fileExists(atPath: url.path) {
            let ext = url.pathExtension.lowercased()
            if ["iso", "dmg", "cdr", "bin", "cue", "mds", "nrg"].contains(ext) {
                store.selectedCategory = .burn
                store.selectedTaskID = KroutonFormatID.imageBurn.rawValue
            }
            if !store.stagedFiles.contains(where: { $0.url.standardizedFileURL == url.standardizedFileURL }) {
                let entry = KroutonOpticalDriveBank.inspectFileOrFolder(url: url)
                store.stagedFiles.append(entry)
            }
        }
        KroutonWindowManager.shared.openMainWindow()
        NSApplication.shared.activate(ignoringOtherApps: true)
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !flag {
            KroutonWindowManager.shared.openMainWindow()
        }
        NSApplication.shared.activate(ignoringOtherApps: true)
        return true
    }
}
