import AudioToolbox
import DriveKit
import Foundation
import ImageIO
import NetworkSpool
import OpticalCore
import SwiftUI
import UniformTypeIdentifiers

public enum KroutonOSDesktopBridge {
    private static let activeLock = NSLock()
    nonisolated(unsafe) private static var _isVisiblyActive: Bool = true

    public static func setApplicationVisiblyActive(_ active: Bool) {
        activeLock.lock()
        _isVisiblyActive = active
        activeLock.unlock()
    }

    public static func revealInFinder(url: URL) { _ = LSOpenCFURLRef(url as CFURL, nil) }
    public static func playAcousticCue(_ cue: KroutonAcousticCue = .warning) {
        KroutonAcousticEngine.shared.play(cue)
    }

    public static func copyTextToClipboard(_ text: String) {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/usr/bin/pbcopy")
        let pipe = Pipe()
        p.standardInput = pipe
        if (try? p.run()) != nil {
            pipe.fileHandleForWriting.write(Data(text.utf8))
            try? pipe.fileHandleForWriting.close()
            p.waitUntilExit()
        }
    }

    public static func revealURLsInFinder(_ urls: [URL]) {
        guard let u = urls.first else { return }
        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/usr/bin/open")
        p.arguments = ["-R", u.path]
        try? p.run()
    }

    public static func revealFolderInFinder(path: String) {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/usr/bin/open")
        p.arguments = [path]
        try? p.run()
    }

    @MainActor
    public static func printSwiftUIView<V: View>(_ view: V) {
        let renderer = ImageRenderer(content: view)
        renderer.scale = 2.0
        guard let cg = renderer.cgImage,
              let data = CFDataCreateMutable(nil, 0),
              let dst = CGImageDestinationCreateWithData(data, UTType.png.identifier as CFString, 1, nil) else { return }
        CGImageDestinationAddImage(dst, cg, nil)
        guard CGImageDestinationFinalize(dst) else { return }
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("Krouton-Print.png")
        try? (data as Data).write(to: url, options: .atomic)
        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/usr/bin/open")
        p.arguments = ["-a", "Preview", url.path]
        try? p.run()
    }

    public static func isSystemDarkMode() -> Bool {
        UserDefaults.standard.string(forKey: "AppleInterfaceStyle") == "Dark"
    }

    public static func postVoiceOverAnnouncement(_ message: String) {
        Task { @MainActor in AccessibilityNotification.Announcement(message).post() }
    }

    public static var didBecomeActiveNotification: Notification.Name { Notification.Name("KroutonDidBecomeActive") }
    public static var didResignActiveNotification: Notification.Name { Notification.Name("KroutonDidResignActive") }
    public static var didChangeWindowOcclusionNotification: Notification.Name { Notification.Name("KroutonOcclusion") }

    public static func isApplicationVisiblyActive() -> Bool {
        activeLock.lock()
        defer { activeLock.unlock() }
        return _isVisiblyActive
    }
}
