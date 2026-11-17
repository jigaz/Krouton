import Foundation
import ObjectiveC.runtime
import SwiftUI
import os

// MARK: - KroutonOSDesktopBridge (Pure SwiftUI & In-Process Runtime Bridge)

enum KroutonOSDesktopBridge {
    private static let visiblyActiveLock = OSAllocatedUnfairLock(initialState: true)

    static func setApplicationVisiblyActive(_ active: Bool) {
        visiblyActiveLock.withLock { $0 = active }
    }

    static func playAcousticCue(_ cue: KroutonAcousticCue = .warning) {
        KroutonAcousticEngine.shared.play(cue)
    }

    static func copyTextToClipboard(_ text: String) {
        guard let pbClass = NSClassFromString("NSPasteboard") as? NSObject.Type,
              let generalPB = pbClass.perform(NSSelectorFromString("generalPasteboard"))?.takeUnretainedValue() as? NSObject else {
            return
        }
        _ = generalPB.perform(NSSelectorFromString("clearContents"))
        _ = generalPB.perform(NSSelectorFromString("setString:forType:"), with: text as NSString, with: "public.utf8-plain-text" as NSString)
    }

    static func revealInFinder(url: URL) {
        revealURLsInFinder([url])
    }

    static func revealURLsInFinder(_ urls: [URL]) {
        guard let firstURL = urls.first else { return }
        if let wsClass = NSClassFromString("NSWorkspace") as? NSObject.Type,
           let sharedWS = wsClass.perform(NSSelectorFromString("sharedWorkspace"))?.takeUnretainedValue() as? NSObject {
            let sel = NSSelectorFromString("activateFileViewerSelectingURLs:")
            if sharedWS.responds(to: sel) {
                _ = sharedWS.perform(sel, with: urls as NSArray)
                return
            }
        }
        Task { @MainActor in EnvironmentValues().openURL(firstURL) }
    }

    static func revealFolderInFinder(path: String) {
        let folderURL = URL(fileURLWithPath: path)
        if let wsClass = NSClassFromString("NSWorkspace") as? NSObject.Type,
           let sharedWS = wsClass.perform(NSSelectorFromString("sharedWorkspace"))?.takeUnretainedValue() as? NSObject {
            let sel = NSSelectorFromString("openURL:")
            if sharedWS.responds(to: sel) {
                _ = sharedWS.perform(sel, with: folderURL as NSURL)
                return
            }
        }
        Task { @MainActor in EnvironmentValues().openURL(folderURL) }
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

    static func isApplicationVisiblyActive() -> Bool {
        visiblyActiveLock.withLock { $0 }
    }
}
