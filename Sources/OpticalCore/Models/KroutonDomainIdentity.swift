import Foundation
import OSLog

/// Canonical reverse-DNS (`app.krouton`), web (`krouton.app`), UTI, filesystem,
/// and OSLog subsystem identity shared across all 11 Krouton modules.
public enum KroutonDomainIdentity: Sendable {
    // MARK: - Canonical Domain & Reverse-DNS Prefix
    public static let domainName = "krouton.app"
    public static let reverseDNSPrefix = "app.krouton"

    // MARK: - Web Endpoints (krouton.app)
    public static let documentationURL = URL(string: "https://krouton.app/docs")!
    public static let archivalVerifyURL = URL(string: "https://krouton.app/verify")!

    // MARK: - Uniform Type Identifiers (UTIs)
    public enum UTI: String, Sendable, CaseIterable {
        case project       = "app.krouton.project"
        case burnSet       = "app.krouton.burnset"
        case discLabel     = "app.krouton.label"
        case rescueMap     = "app.krouton.rescue-map"
        case archivalCert  = "app.krouton.archival-certificate"
    }

    // MARK: - Bonjour & NetworkSpool
    /// Also list this under NSBonjourServices in the app's Info.plist, with an
    /// NSLocalNetworkUsageDescription, or browsing silently finds nothing under Local Network privacy.
    public static let spoolServiceType = "_krouton-spool._tcp"
    public static let spoolDefaultPort: UInt16 = 7420

    // MARK: - 11 Architectural Modules & OSLog Subsystems
    public enum Module: String, Sendable, CaseIterable {
        case opticalCore  = "opticalcore"
        case driveKit     = "drivekit"
        case burnKit      = "burnkit"
        case audioKit     = "audiokit"
        case imageKit     = "imagekit"
        case rescueKit    = "rescuekit"
        case labelKit     = "labelkit"
        case videoKit     = "videokit"
        case networkSpool = "networkspool"
        case persistence  = "persistence"
        case kroutonApp   = "kroutonapp"

        /// Returns e.g. `"app.krouton.drivekit"`
        public var subsystem: String {
            "\(KroutonDomainIdentity.reverseDNSPrefix).\(rawValue)"
        }

        /// Returns a dispatch queue label e.g. `"app.krouton.drivekit.io"`
        func queueLabel(_ suffix: String) -> String {
            "\(subsystem).\(suffix)"
        }

        /// Returns a configured `os.Logger` for this module and category.
        public func logger(category: String = "default") -> Logger {
            Logger(subsystem: subsystem, category: category)
        }
    }

    // MARK: - Standardized Application Support & Staging Directories
    public static func applicationSupportRootDirectory(
        fileManager: FileManager = .default
    ) -> URL {
        let base = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? fileManager.temporaryDirectory
        return base.appendingPathComponent(reverseDNSPrefix, isDirectory: true)
    }

    public static func sessionVaultDirectory(
        fileManager: FileManager = .default
    ) -> URL {
        applicationSupportRootDirectory(fileManager: fileManager)
            .appendingPathComponent("Sessions", isDirectory: true)
    }

    public static func ephemeralBurnCacheDirectory(
        fileManager: FileManager = .default
    ) -> URL {
        let caches = fileManager.urls(for: .cachesDirectory, in: .userDomainMask).first
            ?? fileManager.temporaryDirectory
        return caches
            .appendingPathComponent(reverseDNSPrefix, isDirectory: true)
            .appendingPathComponent("StagingCache", isDirectory: true)
    }
}
