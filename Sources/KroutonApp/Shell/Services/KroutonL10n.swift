import Foundation

// MARK: - Global Bundle.module JSON & .lproj Localization Resolver
enum KroutonL10n {
    private static let isoCodeLock = NSLock()
    nonisolated(unsafe) private static var _activeISOCodeStorage: String = "en"

    private static let jsonCatalog: [String: [String: String]] = {
        let candidateURLs: [URL?] = [
            Bundle.main.url(forResource: "LocalizableCatalog", withExtension: "json"),
            Bundle.module.url(forResource: "LocalizableCatalog", withExtension: "json")
        ]
        for url in candidateURLs.compactMap({ $0 }) {
            if let data = try? Data(contentsOf: url),
               let decoded = try? JSONDecoder().decode([String: [String: String]].self, from: data) {
                return decoded
            }
        }
        return [:]
    }()

    static var activeISOCode: String {
        get { isoCodeLock.lock(); defer { isoCodeLock.unlock() }; return _activeISOCodeStorage }
        set { isoCodeLock.lock(); _activeISOCodeStorage = newValue; isoCodeLock.unlock() }
    }

    static func tr(_ key: String) -> String {
        let code = activeISOCode
        if code == "en" || code.isEmpty {
            return key
        }
        let shortCode = String(code.prefix(2))
        if let translations = jsonCatalog[key] {
            if let exact = translations[code] {
                return exact
            }
            if let prefixMatch = translations[shortCode] {
                return prefixMatch
            }
        }
        if let lprojPath = Bundle.module.path(forResource: code, ofType: "lproj"),
           let langBundle = Bundle(path: lprojPath) {
            let localized = langBundle.localizedString(forKey: key, value: key, table: "Localizable")
            if localized != key {
                return localized
            }
        }
        if let fallbackPath = Bundle.module.path(forResource: shortCode, ofType: "lproj"),
           let langBundle = Bundle(path: fallbackPath) {
            return langBundle.localizedString(forKey: key, value: key, table: "Localizable")
        }
        return Bundle.module.localizedString(forKey: key, value: key, table: "Localizable")
    }
}
