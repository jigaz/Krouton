import Foundation
import Network
import OpticalCore

// MARK: - Paired Servers

/// A Krouton Server this Mac has paired with. Only public material is stored (the server's TLS key
/// pin and Ed25519 identity), so `UserDefaults` is an appropriate home.
public struct SpoolPairedServer: Codable, Sendable, Equatable, Identifiable {
    public let nodeID: String
    public var name: String
    /// Host name or address, used when the server is not reachable by Bonjour name.
    public var host: String
    public var port: UInt16
    /// Bonjour service instance name, preferred when present (survives DHCP address changes).
    public var bonjourName: String?
    /// Hex SHA-256 of the server's X9.63 P-256 TLS key.
    public let serverPin: String
    /// Hex Ed25519 identity that signs every session.
    public let identityKey: String
    public let pairedAt: Date

    public var id: String { nodeID }
    public var hostPort: String { "\(host):\(port)" }

    public var endpoint: NWEndpoint {
        if let bonjourName {
            return .service(name: bonjourName, type: KroutonDomainIdentity.spoolServiceType, domain: "local.", interface: nil)
        }
        return .hostPort(host: NWEndpoint.Host(host), port: NWEndpoint.Port(rawValue: port) ?? NWEndpoint.Port(integerLiteral: 7420))
    }
}

public enum SpoolPairedServerStore {
    static let defaultsKey = "app.krouton.pairedBurnServers"

    public static func load(from defaults: UserDefaults = .standard) -> [SpoolPairedServer] {
        guard let data = defaults.data(forKey: defaultsKey),
              let servers = try? JSONDecoder().decode([SpoolPairedServer].self, from: data) else { return [] }
        return servers
    }

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
    public let name: String
    public let hostPort: String
    public let bonjourName: String?
    public let nodeID: String?
    public let isPaired: Bool
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
    public let serverLabel: String
    /// Six digits, as `123 456`.
    public let code: String
}

public struct SpoolExportedArtifact: Sendable {
    public let defaultFilename: String
    public let contentText: String
    public var data: Data { Data(contentText.utf8) }

    public init(defaultFilename: String, contentText: String) {
        self.defaultFilename = defaultFilename
        self.contentText = contentText
    }
}
