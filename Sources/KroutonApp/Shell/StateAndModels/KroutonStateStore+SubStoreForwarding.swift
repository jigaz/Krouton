import Foundation
import OpticalCore
import SwiftUI

// MARK: - KroutonStateStore @dynamicMemberLookup Sub-Store Routing

@MainActor
extension KroutonStateStore {
    subscript<T>(dynamicMember keyPath: ReferenceWritableKeyPath<AppearancePreferences, T>) -> T {
        get { appearance[keyPath: keyPath] }
        set {
            let oldHarmony = appearance.enableSecondaryAccentUITints
            let oldLanguage = appearance.appLanguage
            appearance[keyPath: keyPath] = newValue
            syncAppearanceSideEffects(oldHarmony: oldHarmony, oldLanguage: oldLanguage)
        }
    }

    subscript<T>(dynamicMember keyPath: ReferenceWritableKeyPath<LabelDocument, T>) -> T {
        get { label[keyPath: keyPath] }
        set {
            let oldTemplate = label.selectedLabelTemplate
            label[keyPath: keyPath] = newValue
            if label.selectedLabelTemplate != oldTemplate && !isHydratingPreferences {
                KroutonPreferences.set(label.selectedLabelTemplate.rawValue, for: .labelTemplate)
            }
        }
    }

    subscript<T>(dynamicMember keyPath: ReferenceWritableKeyPath<DepotCatalogue, T>) -> T {
        get { depot[keyPath: keyPath] }
        set { depot[keyPath: keyPath] = newValue }
    }

    subscript<T>(dynamicMember keyPath: ReferenceWritableKeyPath<RipSettings, T>) -> T {
        get { rip[keyPath: keyPath] }
        set { rip[keyPath: keyPath] = newValue }
    }

    subscript<T>(dynamicMember keyPath: KeyPath<RipSettings, T>) -> T {
        rip[keyPath: keyPath]
    }

    private func syncAppearanceSideEffects(oldHarmony: Bool, oldLanguage: KroutonLanguage) {
        if appearance.enableSecondaryAccentUITints != oldHarmony {
            if !isHydratingPreferences {
                KroutonPreferences.set(appearance.enableSecondaryAccentUITints, for: .harmonyEnabled)
            }
        }
        if appearance.appLanguage != oldLanguage {
            KroutonL10n.activeISOCode = appearance.appLanguage.isoCode
            if !isHydratingPreferences {
                KroutonPreferences.set(appearance.appLanguage.rawValue, for: .appLanguage)
            }
        }
        guard !isHydratingPreferences else { return }
        KroutonPreferences.set(appearance.appearanceMode.rawValue, for: .appearanceMode)
        KroutonPreferences.set(appearance.selectedAccentIndex, for: .selectedAccentIndex)
        KroutonPreferences.set(appearance.iconWidgetStyle.rawValue, for: .iconWidgetStyle)
        KroutonPreferences.set(appearance.folderColorMode.rawValue, for: .folderColorMode)
        KroutonPreferences.set(appearance.sidebarIconSize.rawValue, for: .sidebarIconSize)
        KroutonPreferences.set(appearance.rememberLastTaskOnLaunch, for: .rememberLastTask)
        KroutonPreferences.set(appearance.useBase10Units, for: .useBase10Units)
    }
}
