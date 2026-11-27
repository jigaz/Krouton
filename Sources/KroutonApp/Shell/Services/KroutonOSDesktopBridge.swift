import Foundation
import SwiftUI
import os

// MARK: - KroutonOSDesktopBridge (desktop services; AppKit calls go through KroutonAppKitBridge)

enum KroutonOSDesktopBridge {
    static func playAcousticCue(_ cue: KroutonAcousticCue = .warning) {
        KroutonAcousticEngine.shared.play(cue)
    }

    @MainActor
    static func copyTextToClipboard(_ text: String) {
        KroutonAppKitBridge.copyToClipboard(text)
    }

    @MainActor
    static func revealInFinder(url: URL) {
        revealURLsInFinder([url])
    }

    @MainActor
    static func revealURLsInFinder(_ urls: [URL]) {
        guard !urls.isEmpty else { return }
        KroutonAppKitBridge.selectInFinder(urls)
    }

    /// Opens the folder itself in Finder (SwiftUI's openURL does this for a folder).
    @MainActor
    static func revealFolderInFinder(path: String) {
        EnvironmentValues().openURL(URL(fileURLWithPath: path, isDirectory: true))
    }

    static func isSystemDarkMode() -> Bool {
        UserDefaults.standard.string(forKey: "AppleInterfaceStyle") == "Dark"
    }

    static func postVoiceOverAnnouncement(_ message: String) {
        Task { @MainActor in AccessibilityNotification.Announcement(message).post() }
    }

    static var didBecomeActiveNotification: Notification.Name { Notification.Name("KroutonDidBecomeActive") }
    static var didResignActiveNotification: Notification.Name { Notification.Name("KroutonDidResignActive") }
    static var didChangeWindowOcclusionNotification: Notification.Name { Notification.Name("KroutonOcclusion") }

}
