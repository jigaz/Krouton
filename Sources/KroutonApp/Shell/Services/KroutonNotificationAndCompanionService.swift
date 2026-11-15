import Foundation
import SwiftUI
@preconcurrency import UserNotifications
import OpticalCore

public struct KroutonCompanionLivePayload: Codable, Sendable, Equatable {
    public var eventID: String
    public var title: String
    public var subtitle: String
    public var progressFraction: Double
    public var driveName: String
    public var speedLabel: String
    public var iPhoneLiveActivityActive: Bool
    public var appleWatchSmartStackActive: Bool
    public var timestampISO8601: String

    public init(
        eventID: String,
        title: String,
        subtitle: String,
        progressFraction: Double,
        driveName: String,
        speedLabel: String,
        iPhoneLiveActivityActive: Bool,
        appleWatchSmartStackActive: Bool,
        timestampISO8601: String
    ) {
        self.eventID = eventID
        self.title = title
        self.subtitle = subtitle
        self.progressFraction = progressFraction
        self.driveName = driveName
        self.speedLabel = speedLabel
        self.iPhoneLiveActivityActive = iPhoneLiveActivityActive
        self.appleWatchSmartStackActive = appleWatchSmartStackActive
        self.timestampISO8601 = timestampISO8601
    }
}

@MainActor
public final class KroutonNotificationAndCompanionService: ObservableObject {
    public static let shared = KroutonNotificationAndCompanionService()

    @Published public var latestCompanionPayload = KroutonCompanionLivePayload(
        eventID: "idle",
        title: "Optical Workspace Ready",
        subtitle: "Standing by for Burn, Rip, or Verification",
        progressFraction: 0.0,
        driveName: "Optical Drive",
        speedLabel: "Idle",
        iPhoneLiveActivityActive: true,
        appleWatchSmartStackActive: true,
        timestampISO8601: ISO8601DateFormatter().string(from: Date())
    )

    @Published public var lastDispatchedBannerText: String = "No notifications dispatched in this session."

    private init() {}

    public func dispatchEvent(
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
        let iPhoneOn = matchedRow?.iPhoneEnabled ?? true
        let watchOn = matchedRow?.watchEnabled ?? true
        let soundOn = matchedRow?.soundEnabled ?? false

        let stamp = DateFormatter.localizedString(from: Date(), dateStyle: .none, timeStyle: .medium)
        if bannerOn {
            lastDispatchedBannerText = "[\(stamp)] \(title) — \(subtitle)"
            postSystemNotificationIfBundled(id: eventID, title: title, body: subtitle, playSound: soundOn)
        }
        if soundOn {
            KroutonOSDesktopBridge.playAcousticCue()
        }
        if iPhoneOn || watchOn {
            let payload = KroutonCompanionLivePayload(
                eventID: eventID,
                title: title,
                subtitle: subtitle,
                progressFraction: min(1.0, max(0.0, progress)),
                driveName: driveName,
                speedLabel: speedLabel,
                iPhoneLiveActivityActive: iPhoneOn,
                appleWatchSmartStackActive: watchOn,
                timestampISO8601: ISO8601DateFormatter().string(from: Date())
            )
            latestCompanionPayload = payload
            persistCompanionPayload(payload)
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

    private func persistCompanionPayload(_ payload: KroutonCompanionLivePayload) {
        guard let data = try? JSONEncoder().encode(payload) else { return }
        UserDefaults.standard.set(data, forKey: "krouton.companion.latestPayload")
        if let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first {
            let dir = appSupport.appendingPathComponent("Krouton", isDirectory: true)
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            try? data.write(to: dir.appendingPathComponent("companion-live-status.json"), options: .atomic)
        }
    }
}
