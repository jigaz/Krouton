import Foundation
import Security

// MARK: - Settings in iCloud

/// Keeps Krouton's settings the same on each of your Macs through iCloud's key-value store, when
/// you turn it on in Settings › General. Only appearance, units, notifications and the label
/// template travel; this Mac's language, session, drives, servers and keys stay here.
///
/// iCloud needs Krouton signed with the iCloud key-value entitlement and a Developer ID
/// provisioning profile (`Scripts/bundle-app.sh` adds both when `Packaging/Krouton.provisionprofile`
/// is there). A copy without them says so and keeps its settings on this Mac.
@MainActor
enum KroutonCloudSettings {
    /// The settings that travel.
    nonisolated static let syncedKeys: [KroutonPreferenceKey] = [
        .selectedAccentIndex, .harmonyEnabled, .appearanceMode, .iconWidgetStyle, .folderColorMode,
        .sidebarIconSize, .useBase10Units, .labelTemplate, .notificationEvents, .distinctDriveVoices, .menuBarStatus,
    ]
    /// When the values in iCloud were last written, so a Mac turning sync on can tell if any are there.
    nonisolated static let stampKey = "krouton.cloud.savedAt"

    private static var observer: NSObjectProtocol?

    enum Availability: Equatable {
        case available
        /// This build isn't signed for iCloud (a development or ad hoc build).
        case notSigned
        /// No iCloud account is signed in on this Mac.
        case noAccount
    }

    static var availability: Availability {
        guard hasKeyValueEntitlement else { return .notSigned }
        return FileManager.default.ubiquityIdentityToken == nil ? .noAccount : .available
    }

    static var isOn: Bool { KroutonPreferences.bool(for: .syncSettingsWithICloud) }

    /// When the settings in iCloud were saved, if a Mac ever saved them.
    static var cloudSavedAt: Date? {
        let seconds = NSUbiquitousKeyValueStore.default.double(forKey: stampKey)
        return seconds > 0 ? Date(timeIntervalSince1970: seconds) : nil
    }

    // MARK: - Turning It On and Off

    /// Starts syncing. `useCloud` takes the settings already in iCloud (another Mac's); otherwise
    /// this Mac's settings replace them.
    static func turnOn(useCloud: Bool, store: KroutonStateStore) {
        KroutonPreferences.set(true, for: .syncSettingsWithICloud)
        NSUbiquitousKeyValueStore.default.synchronize()
        if useCloud { pull(into: store) } else { pushAll() }
        startObserving(store: store)
    }

    /// Stops syncing. The settings stay as they are on this Mac, and the copy in iCloud stays for
    /// your other Macs.
    static func turnOff() {
        KroutonPreferences.set(false, for: .syncSettingsWithICloud)
        if let observer { NotificationCenter.default.removeObserver(observer) }
        observer = nil
    }

    /// At launch: listen for changes from other Macs and take what changed while Krouton was closed.
    static func start(store: KroutonStateStore) {
        guard isOn, availability == .available else { return }
        NSUbiquitousKeyValueStore.default.synchronize()
        pull(into: store)
        startObserving(store: store)
    }

    // MARK: - Moving Values

    /// Called by `KroutonPreferences.set` for every change made on this Mac.
    nonisolated static func didChange(_ key: KroutonPreferenceKey, to value: Any?) {
        guard syncedKeys.contains(key), KroutonPreferences.bool(for: .syncSettingsWithICloud) else { return }
        let cloud = NSUbiquitousKeyValueStore.default
        cloud.set(value, forKey: key.rawValue)
        cloud.set(Date().timeIntervalSince1970, forKey: stampKey)
    }

    static func pushAll() {
        for key in syncedKeys {
            NSUbiquitousKeyValueStore.default.set(KroutonPreferences.object(for: key), forKey: key.rawValue)
        }
        NSUbiquitousKeyValueStore.default.set(Date().timeIntervalSince1970, forKey: stampKey)
    }

    /// Copies iCloud's values into this Mac's settings and shows them.
    static func pull(into store: KroutonStateStore, keys: [String]? = nil) {
        let cloud = NSUbiquitousKeyValueStore.default
        let wanted = keys.map { Set($0) }
        for key in syncedKeys where wanted?.contains(key.rawValue) ?? true {
            guard let value = cloud.object(forKey: key.rawValue) else { continue }
            KroutonPreferences.setLocally(value, for: key)
        }
        store.hydratePreferencesFromUserDefaults()
    }

    /// Erases the copy in iCloud (Reset Settings, with sync on, resets every Mac).
    static func eraseCloudCopy() {
        let cloud = NSUbiquitousKeyValueStore.default
        for key in syncedKeys { cloud.removeObject(forKey: key.rawValue) }
        cloud.removeObject(forKey: stampKey)
    }

    private static func startObserving(store: KroutonStateStore) {
        guard observer == nil else { return }
        observer = NotificationCenter.default.addObserver(
            forName: NSUbiquitousKeyValueStore.didChangeExternallyNotification,
            object: NSUbiquitousKeyValueStore.default, queue: .main
        ) { note in
            let keys = note.userInfo?[NSUbiquitousKeyValueStoreChangedKeysKey] as? [String]
            MainActor.assumeIsolated { pull(into: store, keys: keys) }
        }
    }

    // MARK: - Signing

    /// Whether this copy of Krouton carries the iCloud key-value entitlement.
    private static var hasKeyValueEntitlement: Bool {
        guard let task = SecTaskCreateFromSelf(nil) else { return false }
        let value = SecTaskCopyValueForEntitlement(task, "com.apple.developer.ubiquity-kvstore-identifier" as CFString, nil)
        return value != nil
    }
}
