import Foundation

// MARK: - Localization

/// Krouton's interface text lives in `Resources/Localizable.xcstrings`, a String Catalog that
/// Xcode's editor opens and `Scripts/extract-strings.py` keeps in step with the code. SwiftUI
/// literals (`Text("…")`, `Button("…")`) are looked up by SwiftUI itself; `tr` is for text built
/// in code. Both follow the languages macOS gives the app, which Settings can override.
enum KroutonL10n {
    static func tr(_ key: String) -> String {
        Bundle.module.localizedString(forKey: key, value: key, table: "Localizable")
    }

    /// Sets the app's own language list, as System Settings › General › Language & Region ›
    /// Applications does. macOS reads it when the app opens, so it takes effect at the next
    /// launch. `nil` follows the system languages again.
    static func applyLanguagePreference(isoCode: String?) {
        if let isoCode {
            UserDefaults.standard.set([isoCode], forKey: "AppleLanguages")
        } else {
            UserDefaults.standard.removeObject(forKey: "AppleLanguages")
        }
    }
}
