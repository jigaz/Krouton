import Foundation
import OpticalCore
import SwiftUI

// MARK: - KroutonStateStore @dynamicMemberLookup Sub-Store Routing

@MainActor
extension KroutonStateStore {
    subscript<T>(dynamicMember keyPath: WritableKeyPath<AppearancePreferences, T>) -> T {
        get { appearance[keyPath: keyPath] }
        set {
            let old = appearance
            appearance[keyPath: keyPath] = newValue
            syncAppearanceSideEffects(from: old, to: appearance)
        }
    }

    subscript<T>(dynamicMember keyPath: WritableKeyPath<LabelDocument, T>) -> T {
        get { label[keyPath: keyPath] }
        set {
            let oldTemplate = label.selectedLabelTemplate
            label[keyPath: keyPath] = newValue
            if label.selectedLabelTemplate != oldTemplate && !isHydratingPreferences {
                UserDefaults.standard.set(label.selectedLabelTemplate.rawValue, forKey: "krouton.pref.labelTemplate")
            }
        }
    }

    subscript<T>(dynamicMember keyPath: WritableKeyPath<DepotCatalogue, T>) -> T {
        get { depot[keyPath: keyPath] }
        set { depot[keyPath: keyPath] = newValue }
    }

    subscript<T>(dynamicMember keyPath: WritableKeyPath<RipSettings, T>) -> T {
        get { rip[keyPath: keyPath] }
        set { rip[keyPath: keyPath] = newValue }
    }

    subscript<T>(dynamicMember keyPath: KeyPath<RipSettings, T>) -> T {
        rip[keyPath: keyPath]
    }

    private func syncAppearanceSideEffects(from old: AppearancePreferences, to updated: AppearancePreferences) {
        if updated.enableSecondaryAccentUITints != old.enableSecondaryAccentUITints {
            appearance.tintWindowWithWallpaper = updated.enableSecondaryAccentUITints
            if !isHydratingPreferences {
                UserDefaults.standard.set(updated.enableSecondaryAccentUITints, forKey: "krouton.pref.harmonyEnabled")
            }
        }
        if updated.appLanguage != old.appLanguage {
            KroutonL10n.activeISOCode = updated.appLanguage.isoCode
            if !isHydratingPreferences {
                UserDefaults.standard.set(updated.appLanguage.rawValue, forKey: "krouton.pref.appLanguage")
            }
        }
        guard !isHydratingPreferences else { return }
        if updated.appearanceMode != old.appearanceMode {
            UserDefaults.standard.set(updated.appearanceMode.rawValue, forKey: "krouton.pref.appearanceMode")
        }
        if updated.selectedAccentIndex != old.selectedAccentIndex {
            UserDefaults.standard.set(updated.selectedAccentIndex, forKey: "krouton.pref.selectedAccentIndex")
        }
        if updated.iconWidgetStyle != old.iconWidgetStyle {
            UserDefaults.standard.set(updated.iconWidgetStyle.rawValue, forKey: "krouton.pref.iconWidgetStyle")
        }
        if updated.folderColorMode != old.folderColorMode {
            UserDefaults.standard.set(updated.folderColorMode.rawValue, forKey: "krouton.pref.folderColorMode")
        }
        if updated.sidebarIconSize != old.sidebarIconSize {
            UserDefaults.standard.set(updated.sidebarIconSize.rawValue, forKey: "krouton.pref.sidebarIconSize")
        }
        if updated.rememberLastTaskOnLaunch != old.rememberLastTaskOnLaunch {
            UserDefaults.standard.set(updated.rememberLastTaskOnLaunch, forKey: "krouton.pref.rememberLastTask")
        }
        if updated.useBase10Units != old.useBase10Units {
            UserDefaults.standard.set(updated.useBase10Units, forKey: "krouton.pref.useBase10Units")
        }
    }
}
