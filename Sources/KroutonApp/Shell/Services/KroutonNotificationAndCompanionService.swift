import Foundation
import Observation
import SwiftUI
@preconcurrency import UserNotifications

// MARK: - KroutonNotificationAndCompanionService

/// Posts the app's notifications: a macOS banner, a sound and a VoiceOver announcement, as
/// Settings › Notifications chooses for each event. There is no iPhone or Apple Watch side:
/// Krouton has no companion app, so those switches were removed.
@Observable
@MainActor
final class KroutonNotificationAndCompanionService {
    static let shared = KroutonNotificationAndCompanionService()

    var lastDispatchedBannerText: String = "No notifications dispatched in this session."

    private init() {}

    func dispatchEvent(
        id eventID: String,
        title: String,
        subtitle: String,
        progress: Double = 1.0,
        driveName: String = "Optical Drive",
        speedLabel: String = "Max Safe",
        store: KroutonStateStore
    ) {
        let matchedRow = store.notificationMatrix.first(where: { $0.id == eventID })
        let bannerOn = matchedRow?.bannerEnabled ?? true
        let soundOn = matchedRow?.soundEnabled ?? false

        let stamp = DateFormatter.localizedString(from: Date(), dateStyle: .none, timeStyle: .medium)
        if bannerOn {
            lastDispatchedBannerText = "[\(stamp)] \(title) — \(subtitle)"
            postSystemNotificationIfBundled(id: eventID, title: title, body: subtitle, playSound: soundOn)
        }
        if soundOn, let sound = matchedRow?.sound {
            // A real drive gets its own pitch; tests and events without a drive don't.
            let voice = store.distinctDriveVoices && driveName != "Optical Drive" ? driveName : nil
            KroutonOSDesktopBridge.playAcousticCue(sound.cue(forDrive: voice))
        }
        if store.voiceOverSpokenTelemetry {
            store.announceForVoiceOver("\(title). \(subtitle)")
        }
    }

    private func postSystemNotificationIfBundled(id: String, title: String, body: String, playSound: Bool) {
        guard Bundle.main.bundleIdentifier != nil else { return }
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, _ in
            guard granted else { return }
            let content = UNMutableNotificationContent()
            content.title = title
            content.body = body
            if playSound {
                content.sound = .default
            }
            let req = UNNotificationRequest(
                identifier: "krouton.\(id).\(UUID().uuidString)",
                content: content,
                trigger: nil
            )
            UNUserNotificationCenter.current().add(req)
        }
    }
}
