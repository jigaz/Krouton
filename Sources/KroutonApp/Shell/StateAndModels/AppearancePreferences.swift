import SwiftUI
import Foundation
import OpticalCore

/// Feature model owning appearance, accent palette, localization, unit, and accessibility preferences.
/// Consolidates the four previously duplicated colour-scheme resolution blocks into one place.
public struct AppearancePreferences: Equatable, Sendable {
    public var enableSecondaryAccentUITints: Bool = false
    public var tintWindowWithWallpaper: Bool = false
    public var appearanceMode: KroutonRoastAppearanceMode = .auto
    public var selectedAccentIndex: Int = 8
    public var iconWidgetStyle: KroutonGarnishStyleMode = .defaultStyle
    public var folderColorMode: KroutonStageFolderColorMode = .automatic
    public var sidebarIconSize: KroutonTrackIconSizeMode = .medium
    public var appLanguage: KroutonLanguage = .english
    public var voiceOverSpokenTelemetry: Bool = true
    public var a11yIncreaseContrast: Bool = false
    public var a11yDifferentiateWithoutColor: Bool = true
    public var a11yReduceMotion: Bool = false
    public var rememberLastTaskOnLaunch: Bool = true
    public var useBase10Units: Bool = true

    public init() {}

    /// Single source of truth for SwiftUI `.preferredColorScheme(...)` (`nil` when `.auto`).
    public var resolvedColorScheme: ColorScheme? {
        appearanceMode.colorScheme
    }

    /// Single source of truth for concrete `.light` / `.dark` accent evaluation.
    @MainActor
    public var effectiveColorScheme: ColorScheme {
        if let explicit = appearanceMode.colorScheme {
            return explicit
        }
        return KroutonOSDesktopBridge.isSystemDarkMode() ? .dark : .light
    }

    public var activeLocale: Locale {
        Locale(identifier: appLanguage.isoCode)
    }

    public mutating func load(from defaults: UserDefaults = .standard) {
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
