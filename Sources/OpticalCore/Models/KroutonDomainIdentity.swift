import Foundation
import OSLog

/// The identifiers every module shares: the web domain (`krouton.app`), the reverse-DNS prefix
/// (`app.krouton`), document types, the Bonjour service, log subsystems and the app's folders.
public enum KroutonDomainIdentity: Sendable {
    // MARK: - Canonical Domain & Reverse-DNS Prefix
    /// The project's web domain.
    public static let domainName = "krouton.app"
    /// The prefix of every bundle, UTI and log subsystem identifier.
    public static let reverseDNSPrefix = "app.krouton"

    // MARK: - Web Endpoints (krouton.app)
    /// The user manual; each chapter lives at `manual/<slug>/` (built from Resources/Manual).
    public static let manualURL = URL(string: "https://krouton.app/manual/")!
    /// Where users send a report about how a drive behaved.
    public static let driveReportURL = URL(string: "https://krouton.app/drives/")!
    /// Where users open a bug report (GitHub issues).
    public static let problemReportURL = URL(string: "https://github.com/jigaz/Krouton/issues/new")!

    // MARK: - Uniform Type Identifiers (UTIs)
    /// The document types Krouton declares. Only `project` is listed in the app's Info.plist today.
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
    /// The TCP port Krouton Server listens on by default.
    public static let spoolDefaultPort: UInt16 = 7420

    // MARK: - 11 Architectural Modules & OSLog Subsystems
    /// The 11 library and app modules, each with its own log subsystem.
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

        /// The module's log subsystem, for example `"app.krouton.drivekit"`.
        public var subsystem: String {
            "\(KroutonDomainIdentity.reverseDNSPrefix).\(rawValue)"
        }
    }

    // MARK: - Standardized Application Support & Staging Directories
    /// `~/Library/Application Support/app.krouton`, or a folder in the temporary directory when
    /// there is none.
    public static func applicationSupportRootDirectory(
        fileManager: FileManager = .default
    ) -> URL {
        let base = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? fileManager.temporaryDirectory
        return base.appendingPathComponent(reverseDNSPrefix, isDirectory: true)
    }

    /// The `Sessions` folder inside the Application Support root.
    public static func sessionVaultDirectory(
        fileManager: FileManager = .default
    ) -> URL {
        applicationSupportRootDirectory(fileManager: fileManager)
            .appendingPathComponent("Sessions", isDirectory: true)
    }

    /// `~/Library/Caches/app.krouton/StagingCache`, where burn sets stage frozen copies of their
    /// sources. It is a cache folder, so macOS may delete it.
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
