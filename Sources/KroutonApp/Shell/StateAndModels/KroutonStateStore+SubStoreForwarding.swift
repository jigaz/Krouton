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
                KroutonPreferences.set(label.selectedLabelTemplate.rawValue, for: .labelTemplate)
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
                KroutonPreferences.set(updated.enableSecondaryAccentUITints, for: .harmonyEnabled)
            }
        }
        if updated.appLanguage != old.appLanguage {
            KroutonL10n.activeISOCode = updated.appLanguage.isoCode
            if !isHydratingPreferences {
                KroutonPreferences.set(updated.appLanguage.rawValue, for: .appLanguage)
            }
        }
        guard !isHydratingPreferences else { return }
        if updated.appearanceMode != old.appearanceMode {
            KroutonPreferences.set(updated.appearanceMode.rawValue, for: .appearanceMode)
        }
        if updated.selectedAccentIndex != old.selectedAccentIndex {
            KroutonPreferences.set(updated.selectedAccentIndex, for: .selectedAccentIndex)
        }
        if updated.iconWidgetStyle != old.iconWidgetStyle {
            KroutonPreferences.set(updated.iconWidgetStyle.rawValue, for: .iconWidgetStyle)
        }
        if updated.folderColorMode != old.folderColorMode {
            KroutonPreferences.set(updated.folderColorMode.rawValue, for: .folderColorMode)
        }
        if updated.sidebarIconSize != old.sidebarIconSize {
            KroutonPreferences.set(updated.sidebarIconSize.rawValue, for: .sidebarIconSize)
        }
        if updated.rememberLastTaskOnLaunch != old.rememberLastTaskOnLaunch {
            KroutonPreferences.set(updated.rememberLastTaskOnLaunch, for: .rememberLastTask)
        }
        if updated.useBase10Units != old.useBase10Units {
            KroutonPreferences.set(updated.useBase10Units, for: .useBase10Units)
        }
    }
}
