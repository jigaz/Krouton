import Foundation
import Network
import OpticalCore

// MARK: - Paired Servers

/// A Krouton Server this Mac has paired with. Only public material is stored (the server's TLS key
/// pin and Ed25519 identity), so `UserDefaults` is an appropriate home.
public struct SpoolPairedServer: Codable, Sendable, Equatable, Identifiable {
    /// The server's node ID.
    public let nodeID: String
    /// The server's name.
    public var name: String
    /// Host name or address, used when the server is not reachable by Bonjour name.
    public var host: String
    /// The server's TCP port.
    public var port: UInt16
    /// Bonjour service instance name, preferred when present (survives DHCP address changes).
    public var bonjourName: String?
    /// Hex SHA-256 of the server's X9.63 P-256 TLS key.
    public let serverPin: String
    /// Hex Ed25519 identity that signs every session.
    public let identityKey: String
    /// When pairing finished.
    public let pairedAt: Date

    public var id: String { nodeID }
    /// "host:port".
    public var hostPort: String { "\(host):\(port)" }

    /// Where to connect: the Bonjour service when its name is known, otherwise host and port.
    public var endpoint: NWEndpoint {
        if let bonjourName {
            return .service(name: bonjourName, type: KroutonDomainIdentity.spoolServiceType, domain: "local.", interface: nil)
        }
        return .hostPort(host: NWEndpoint.Host(host), port: NWEndpoint.Port(rawValue: port) ?? NWEndpoint.Port(integerLiteral: 7420))
    }
}

/// Saves the paired servers in `UserDefaults` as JSON.
public enum SpoolPairedServerStore {
    static let defaultsKey = "app.krouton.pairedBurnServers"

    /// The saved servers; empty when there are none or they can't be read.
    public static func load(from defaults: UserDefaults = .standard) -> [SpoolPairedServer] {
        guard let data = defaults.data(forKey: defaultsKey),
              let servers = try? JSONDecoder().decode([SpoolPairedServer].self, from: data) else { return [] }
        return servers
    }

    /// Saves `servers`, replacing the list.
    public static func save(_ servers: [SpoolPairedServer], to defaults: UserDefaults = .standard) {
        if let data = try? JSONEncoder().encode(servers) {
            defaults.set(data, forKey: defaultsKey)
        }
    }
}

// MARK: - Discovered & Burnable Servers

/// A server shown in pickers: either paired (burnable) or seen nearby via Bonjour (pairable).
public struct SpoolDiscoveredNode: Identifiable, Hashable, Sendable {
    /// The node ID for paired servers; the Bonjour instance name for unpaired ones.
    public let id: String
    /// The server's name.
    public let name: String
    /// "host:port", or the Bonjour name.
    public let hostPort: String
    /// The Bonjour instance name, when known.
    public let bonjourName: String?
    /// The node ID, when known (always for paired servers).
    public let nodeID: String?
    /// True for paired servers, which can burn.
    public let isPaired: Bool
    /// The Bonjour `caps` hint, unauthenticated.
    public let capabilities: SpoolNodeCapabilities

    public init(id: String, name: String, hostPort: String, bonjourName: String? = nil, nodeID: String? = nil,
                isPaired: Bool, capabilities: SpoolNodeCapabilities = []) {
        self.id = id
        self.name = name
        self.hostPort = hostPort
        self.bonjourName = bonjourName
        self.nodeID = nodeID
        self.isPaired = isPaired
        self.capabilities = capabilities
    }
}

// MARK: - Pairing Prompt & Exports

/// Shown while a pairing waits for the person at this Mac to compare codes.
public struct SpoolPairingPrompt: Identifiable, Sendable, Equatable {
    public let id = UUID()
    /// The server's name or address.
    public let serverLabel: String
    /// Six digits, as `123 456`.
    public let code: String
}

/// A text file to save, with its suggested name.
public struct SpoolExportedArtifact: Sendable {
    /// The suggested file name.
    public let defaultFilename: String
    /// The file's text.
    public let contentText: String
    /// The text as UTF-8.
    public var data: Data { Data(contentText.utf8) }

    public init(defaultFilename: String, contentText: String) {
        self.defaultFilename = defaultFilename
        self.contentText = contentText
    }
}
