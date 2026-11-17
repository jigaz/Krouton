import Foundation

// MARK: - Global Bundle.module .lproj Localization Resolver
public enum KroutonL10n {
    private static let isoCodeLock = NSLock()
    nonisolated(unsafe) private static var _activeISOCodeStorage: String = "en"
    public static var activeISOCode: String {
        get { isoCodeLock.lock(); defer { isoCodeLock.unlock() }; return _activeISOCodeStorage }
        set { isoCodeLock.lock(); _activeISOCodeStorage = newValue; isoCodeLock.unlock() }
    }

    public static func tr(_ key: String) -> String {
        let code = activeISOCode
        if let lprojPath = Bundle.module.path(forResource: code, ofType: "lproj"),
           let langBundle = Bundle(path: lprojPath) {
            let localized = langBundle.localizedString(forKey: key, value: key, table: "Localizable")
            if localized != key {
                return localized
            }
        }
        if let fallbackPath = Bundle.module.path(forResource: String(code.prefix(2)), ofType: "lproj"),
           let langBundle = Bundle(path: fallbackPath) {
            return langBundle.localizedString(forKey: key, value: key, table: "Localizable")
        }
        return Bundle.module.localizedString(forKey: key, value: key, table: "Localizable")
    }
}
