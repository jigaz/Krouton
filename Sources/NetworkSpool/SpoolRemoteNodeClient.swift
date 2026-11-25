import CryptoKit
import Foundation
import Network
import Observation
import OpticalCore

// MARK: - Krouton Server Client

/// Talks to Krouton Servers (`krouton-server`): Bonjour discovery, pairing, an authenticated
/// session per server (pinned mutual TLS 1.3 + Ed25519 session proofs), resumable image upload,
/// and live job and burn telemetry.
@Observable
@MainActor
public final class SpoolRemoteNodeClient {
    public static let shared = SpoolRemoteNodeClient()

    public private(set) var pairedServers: [SpoolPairedServer] = SpoolPairedServerStore.load()
    public private(set) var nearbyUnpaired: [SpoolDiscoveredNode] = []
    public private(set) var remoteDrives: [SpoolDriveInfo] = []
    public private(set) var jobs: [SpoolJobInfo] = []
    public private(set) var connectedServerID: String?
    /// What the connected server reported when the session opened.
    public internal(set) var serverWelcome: SpoolServerWelcome?
    public var statusBannerText: String = "No burn server connected"
    public internal(set) var isSpoolingImage = false
    public internal(set) var spoolProgressFraction = 0.0
    public private(set) var recentEvents: [String] = []
    /// Non-nil while a pairing code is on screen.
    public internal(set) var pairingPrompt: SpoolPairingPrompt?

    var browser: NWBrowser?
    var nearbyHints: [String: (name: String, nodeID: String?, caps: SpoolNodeCapabilities)] = [:]
    var session: Session?
    var readyWaiters: [CheckedContinuation<Void, Error>] = []
    var acceptWaiters: [String: CheckedContinuation<Void, Error>] = [:]
    var uploadWaiter: CheckedContinuation<SpoolUploadSender.Phase, Error>?
    var pairingDecision: CheckedContinuation<Bool, Never>?
    var telemetryTarget: (store: any KroutonDriveTelemetryStore, key: String, job: String)?
    var lastTelemetry: [String: (SpoolTelemetryPhase, Double)] = [:]

    /// Servers outside private ranges are refused; Tailscale/ZeroTier (100.64/10) is allowed
    /// because a server is only ever reached after it was paired in person.
    let policy = SpoolEndpointPolicy(allowsOverlayCGNAT: true)

    struct Session {
        let server: SpoolPairedServer
        let connection: SpoolServerConnection
        var phase: Phase
        var events: Task<Void, Never>?
        var pinger: Task<Void, Never>?

        enum Phase { case awaitingAuth, awaitingWelcome, ready }
    }

    public init() {
        startZeroConfDiscovery()
    }

    // MARK: - Servers For Pickers

    /// Paired servers, which are the ones a disc can be sent to.
    public var discoveredNodes: [SpoolDiscoveredNode] {
        pairedServers.map {
            SpoolDiscoveredNode(id: $0.nodeID, name: $0.name, hostPort: $0.hostPort, bonjourName: $0.bonjourName,
                                nodeID: $0.nodeID, isPaired: true)
        }
    }

    public func server(withID id: String) -> SpoolPairedServer? {
        pairedServers.first { $0.nodeID == id || $0.hostPort == id }
    }

    public var deviceName: String {
        Host.current().localizedName ?? "Mac"
    }

    public func appendEventLog(_ line: String) {
        let stamp = DateFormatter.localizedString(from: Date(), dateStyle: .none, timeStyle: .medium)
        recentEvents.insert("[\(stamp)] \(line)", at: 0)
        if recentEvents.count > 200 { recentEvents.removeLast() }
    }

    public func exportEventLog() -> SpoolExportedArtifact {
        let header = "Krouton burn server log, \(Date().formatted(date: .abbreviated, time: .standard))\n"
            + "Paired servers: \(pairedServers.map { "\($0.name) (\($0.hostPort))" }.joined(separator: ", "))\n\n"
        return SpoolExportedArtifact(defaultFilename: "Krouton Burn Server Log.txt",
                                     contentText: header + recentEvents.reversed().joined(separator: "\n"))
    }

    // MARK: - Bonjour

    public func startZeroConfDiscovery() {
        browser?.cancel()
        let params = NWParameters()
        params.includePeerToPeer = false
        let browser = NWBrowser(for: .bonjourWithTXTRecord(type: KroutonDomainIdentity.spoolServiceType, domain: "local."), using: params)
        browser.browseResultsChangedHandler = { results, _ in
            let found: [(String, String?, SpoolNodeCapabilities)] = results.compactMap { result in
                guard case let .service(name, _, _, _) = result.endpoint else { return nil }
                var nodeID: String?
                var caps: SpoolNodeCapabilities = []
                if case let .bonjour(txt) = result.metadata {
                    let hints = SpoolBonjour.hints(from: txt)
                    nodeID = hints.nodeID
                    caps = hints.capabilities
                }
                return (name, nodeID, caps)
            }
            Task { @MainActor in
                SpoolRemoteNodeClient.shared.updateNearby(found)
            }
        }
        browser.start(queue: .main)
        self.browser = browser
    }

    func updateNearby(_ found: [(String, String?, SpoolNodeCapabilities)]) {
        nearbyHints = Dictionary(found.map { ($0.0, (name: $0.0, nodeID: $0.1, caps: $0.2)) }, uniquingKeysWith: { a, _ in a })
        // A paired server seen under a (new) Bonjour name is remembered under it.
        for (name, nodeID, _) in found {
            if let nodeID, let index = pairedServers.firstIndex(where: { $0.nodeID == nodeID }), pairedServers[index].bonjourName != name {
                pairedServers[index].bonjourName = name
                SpoolPairedServerStore.save(pairedServers)
            }
        }
        let pairedIDs = Set(pairedServers.map(\.nodeID))
        nearbyUnpaired = found.filter { $0.1.map { !pairedIDs.contains($0) } ?? true }.map { name, nodeID, caps in
            SpoolDiscoveredNode(id: name, name: name, hostPort: "\(name) (Bonjour)", bonjourName: name, nodeID: nodeID,
                                isPaired: false, capabilities: caps)
        }
    }

    // MARK: - Paired Server Records

    func remember(_ server: SpoolPairedServer) {
        pairedServers.removeAll { $0.nodeID == server.nodeID }
        pairedServers.append(server)
        SpoolPairedServerStore.save(pairedServers)
        updateNearby(nearbyHints.values.map { ($0.name, $0.nodeID, $0.caps) })
    }

    /// Forgets a server on this Mac (the server keeps its record until `krouton-server unpair`).
    public func forgetServer(_ id: String) async {
        if session?.server.nodeID == id { await closeSession() }
        pairedServers.removeAll { $0.nodeID == id }
        SpoolPairedServerStore.save(pairedServers)
        updateNearby(nearbyHints.values.map { ($0.name, $0.nodeID, $0.caps) })
    }

    // MARK: - Session

    /// Connects (or reuses the connection) to a paired server and waits until it is ready.
    @discardableResult
    func ensureSession(for server: SpoolPairedServer) async throws -> SpoolServerConnection {
        if let session, session.server.nodeID == server.nodeID {
            if session.phase == .ready { return session.connection }
            try await withCheckedThrowingContinuation { readyWaiters.append($0) }
            return session.connection
        }
        await closeSession()
        statusBannerText = "Connecting to \(server.name)…"
        let identity = try SpoolClientIdentity.tlsIdentity(deviceName: deviceName)
        let signing = try SpoolClientIdentity.signingKey()
        let expectedPin = SpoolHex.decode(server.serverPin)
        let connection = try await SpoolServerConnection.open(to: server.endpoint, identity: identity, policy: policy) { pin in
            pin == expectedPin
        }
        session = Session(server: server, connection: connection, phase: .awaitingAuth)
        session?.events = Task { [weak self] in
            await self?.runEvents(connection, server: server, signing: signing)
        }
        try await withCheckedThrowingContinuation { readyWaiters.append($0) }
        session?.pinger = Task { [weak self] in
            var n: UInt64 = 0
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(20))
                n += 1
                guard let self, let connection = self.session?.connection else { return }
                try? await connection.send([.ping(n)])
            }
        }
        return connection
    }

    func closeSession() async {
        guard let current = session else { return }
        session = nil
        current.events?.cancel()
        current.pinger?.cancel()
        await current.connection.close()
        connectedServerID = nil
        serverWelcome = nil
        failWaiters(SpoolServerConnection.Failure.closed)
    }

    func runEvents(_ connection: SpoolServerConnection, server: SpoolPairedServer, signing: Curve25519.Signing.PrivateKey) async {
        do {
            for try await event in connection.events {
                try await handle(event, connection: connection, server: server, signing: signing)
            }
            throw SpoolServerConnection.Failure.closed
        } catch {
            guard session?.connection === connection else { return }
            appendEventLog("\(server.name): connection ended (\(Self.describe(error)))")
            statusBannerText = "\(server.name): disconnected"
            session = nil
            connectedServerID = nil
            failWaiters(error)
        }
    }

    func failWaiters(_ error: Error) {
        readyWaiters.forEach { $0.resume(throwing: error) }
        readyWaiters.removeAll()
        acceptWaiters.values.forEach { $0.resume(throwing: error) }
        acceptWaiters.removeAll()
        uploadWaiter?.resume(throwing: error)
        uploadWaiter = nil
    }
}
