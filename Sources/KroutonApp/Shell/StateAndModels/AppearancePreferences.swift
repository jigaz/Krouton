import Foundation
import Observation
import OpticalCore
import SwiftUI

// MARK: - Typed Preference Keys & Access Layer

enum KroutonPreferenceKey: String, CaseIterable, Sendable {
    case selectedAccentIndex = "krouton.pref.selectedAccentIndex"
    case harmonyEnabled = "krouton.pref.harmonyEnabled"
    case appearanceMode = "krouton.pref.appearanceMode"
    case iconWidgetStyle = "krouton.pref.iconWidgetStyle"
    case folderColorMode = "krouton.pref.folderColorMode"
    case sidebarIconSize = "krouton.pref.sidebarIconSize"
    case appLanguage = "krouton.pref.appLanguage"
    case useBase10Units = "krouton.pref.useBase10Units"
    case rememberLastTask = "krouton.pref.rememberLastTask"
    case labelTemplate = "krouton.pref.labelTemplate"
    case lastCategory = "krouton.pref.lastCategory"
    case lastTaskID = "krouton.pref.lastTaskID"
    case burnSetMedium = "krouton.pref.burnSetMedium"
}

enum KroutonPreferences {
    static func string(for key: KroutonPreferenceKey) -> String? {
        UserDefaults.standard.string(forKey: key.rawValue)
    }
    static func bool(for key: KroutonPreferenceKey, default defaultValue: Bool = false) -> Bool {
        UserDefaults.standard.object(forKey: key.rawValue) != nil
            ? UserDefaults.standard.bool(forKey: key.rawValue)
            : defaultValue
    }
    static func integer(for key: KroutonPreferenceKey) -> Int? {
        UserDefaults.standard.object(forKey: key.rawValue) != nil
            ? UserDefaults.standard.integer(forKey: key.rawValue)
            : nil
    }
    static func set(_ value: Any?, for key: KroutonPreferenceKey) {
        UserDefaults.standard.set(value, forKey: key.rawValue)
    }
    static func has(_ key: KroutonPreferenceKey) -> Bool {
        UserDefaults.standard.object(forKey: key.rawValue) != nil
    }
}

/// Feature model owning appearance, accent palette, localization, unit, and accessibility preferences.
/// Consolidates the four previously duplicated colour-scheme resolution blocks into one place.
// MARK: - AppearancePreferences

@Observable
@MainActor
final class AppearancePreferences {
    var enableSecondaryAccentUITints: Bool = false
    var tintWindowWithWallpaper: Bool = false
    var appearanceMode: KroutonRoastAppearanceMode = .auto
    var selectedAccentIndex: Int = 8
    var iconWidgetStyle: KroutonGarnishStyleMode = .defaultStyle
    var folderColorMode: KroutonStageFolderColorMode = .automatic
    var sidebarIconSize: KroutonTrackIconSizeMode = .medium
    var appLanguage: KroutonLanguage = .english
    var voiceOverSpokenTelemetry: Bool = true
    var a11yIncreaseContrast: Bool = false
    var a11yDifferentiateWithoutColor: Bool = true
    var a11yReduceMotion: Bool = false
    var rememberLastTaskOnLaunch: Bool = true
    var useBase10Units: Bool = true

    init() {}

    /// Single source of truth for SwiftUI `.preferredColorScheme(...)` (`nil` when `.auto`).
    var resolvedColorScheme: ColorScheme? {
        appearanceMode.colorScheme
    }

    /// Single source of truth for concrete `.light` / `.dark` accent evaluation.
    @MainActor
    var effectiveColorScheme: ColorScheme {
        if let explicit = appearanceMode.colorScheme {
            return explicit
        }
        return KroutonOSDesktopBridge.isSystemDarkMode() ? .dark : .light
    }

    var activeLocale: Locale {
        Locale(identifier: appLanguage.isoCode)
    }

    func load() {
        if let acc = KroutonPreferences.integer(for: .selectedAccentIndex) {
            selectedAccentIndex = acc
        }
        if KroutonPreferences.has(.harmonyEnabled) {
            enableSecondaryAccentUITints = KroutonPreferences.bool(for: .harmonyEnabled)
            tintWindowWithWallpaper = enableSecondaryAccentUITints
        }
        if let rawApp = KroutonPreferences.string(for: .appearanceMode),
           let mode = KroutonRoastAppearanceMode(rawValue: rawApp) {
            appearanceMode = mode
        }
        if let rawStyle = KroutonPreferences.string(for: .iconWidgetStyle),
           let style = KroutonGarnishStyleMode(rawValue: rawStyle) {
            iconWidgetStyle = style
        }
        if let rawFolder = KroutonPreferences.string(for: .folderColorMode),
           let fMode = KroutonStageFolderColorMode(rawValue: rawFolder) {
            folderColorMode = fMode
        }
        if let rawSize = KroutonPreferences.string(for: .sidebarIconSize),
           let sSize = KroutonTrackIconSizeMode(rawValue: rawSize) {
            sidebarIconSize = sSize
        }
        if let rawLang = KroutonPreferences.string(for: .appLanguage),
           let lang = KroutonLanguage(rawValue: rawLang) {
            appLanguage = lang
            KroutonL10n.activeISOCode = lang.isoCode
        }
        if KroutonPreferences.has(.useBase10Units) {
            useBase10Units = KroutonPreferences.bool(for: .useBase10Units)
        }
        if KroutonPreferences.has(.rememberLastTask) {
            rememberLastTaskOnLaunch = KroutonPreferences.bool(for: .rememberLastTask)
        }
    }
}
