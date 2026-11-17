import Foundation
import OpticalCore
import SwiftUI

/// Feature model owning appearance, accent palette, localization, unit, and accessibility preferences.
/// Consolidates the four previously duplicated colour-scheme resolution blocks into one place.
struct AppearancePreferences: Equatable, Sendable {
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

    mutating func load(from defaults: UserDefaults = .standard) {
        if defaults.object(forKey: "krouton.pref.selectedAccentIndex") != nil {
            selectedAccentIndex = defaults.integer(forKey: "krouton.pref.selectedAccentIndex")
        }
        if defaults.object(forKey: "krouton.pref.harmonyEnabled") != nil {
            enableSecondaryAccentUITints = defaults.bool(forKey: "krouton.pref.harmonyEnabled")
            tintWindowWithWallpaper = enableSecondaryAccentUITints
        }
        if let rawApp = defaults.string(forKey: "krouton.pref.appearanceMode"),
           let mode = KroutonRoastAppearanceMode(rawValue: rawApp) {
            appearanceMode = mode
        }
        if let rawStyle = defaults.string(forKey: "krouton.pref.iconWidgetStyle"),
           let style = KroutonGarnishStyleMode(rawValue: rawStyle) {
            iconWidgetStyle = style
        }
        if let rawFolder = defaults.string(forKey: "krouton.pref.folderColorMode"),
           let fMode = KroutonStageFolderColorMode(rawValue: rawFolder) {
            folderColorMode = fMode
        }
        if let rawSize = defaults.string(forKey: "krouton.pref.sidebarIconSize"),
           let sSize = KroutonTrackIconSizeMode(rawValue: rawSize) {
            sidebarIconSize = sSize
        }
        if let rawLang = defaults.string(forKey: "krouton.pref.appLanguage"),
           let lang = KroutonLanguage(rawValue: rawLang) {
            appLanguage = lang
            KroutonL10n.activeISOCode = lang.isoCode
        }
        if defaults.object(forKey: "krouton.pref.useBase10Units") != nil {
            useBase10Units = defaults.bool(forKey: "krouton.pref.useBase10Units")
        }
        if defaults.object(forKey: "krouton.pref.rememberLastTask") != nil {
            rememberLastTaskOnLaunch = defaults.bool(forKey: "krouton.pref.rememberLastTask")
        }
    }
}
