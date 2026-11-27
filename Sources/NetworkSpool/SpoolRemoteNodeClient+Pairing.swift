import CryptoKit
import Foundation
import Network
import OpticalCore

// MARK: - Pairing With a Krouton Server

@MainActor
extension SpoolRemoteNodeClient {
    /// Pairs with the server at `host` (or Bonjour instance `bonjourName`). The operator must have
    /// run `krouton-server pair` there. Shows `pairingPrompt` with the 6-digit code until the person
    /// at this Mac answers `confirmPairingCode(_:)`; the operator confirms the same code on the server.
    /// Returns the paired server, or nil (with `statusBannerText` saying why).
    @discardableResult
    public func pair(host: String, port: UInt16 = 7420, bonjourName: String? = nil) async -> SpoolPairedServer? {
        let label = bonjourName ?? host
        if bonjourName == nil, !SpoolLANSecurityEngine.isAllowedLANEndpoint(host) {
            statusBannerText = "\(host) is not a local network address or .local name"
            return nil
        }
        let endpoint: NWEndpoint = bonjourName.map {
            .service(name: $0, type: KroutonDomainIdentity.spoolServiceType, domain: "local.", interface: nil)
        } ?? .hostPort(host: NWEndpoint.Host(host), port: NWEndpoint.Port(rawValue: port) ?? 7420)
        statusBannerText = "Pairing with \(label)…"
        do {
            let identity = try SpoolClientIdentity.tlsIdentity(deviceName: deviceName)
            let signing = try SpoolClientIdentity.signingKey()
            // Any server key is accepted for this one connection: the code comparison decides trust,
            // and the key seen here is the one pinned afterwards.
            let connection = try await SpoolServerConnection.open(to: endpoint, identity: identity, policy: policy) { _ in true }
            defer { Task { await connection.close() } }
            let paired = try await runPairing(connection, signing: signing, label: label)
            let server = SpoolPairedServer(nodeID: paired.nodeID, name: paired.serverName, host: bonjourName ?? host, port: port,
                                           bonjourName: bonjourName, serverPin: SpoolHex.encode(connection.serverPin),
                                           identityKey: SpoolHex.encode(paired.identity), pairedAt: Date())
            remember(server)
            statusBannerText = "Paired with \(server.name)"
            appendEventLog("Paired with \(server.name) (node \(server.nodeID))")
            return server
        } catch {
            pairingPrompt = nil
            pairingDecision?.resume(returning: false)
            pairingDecision = nil
            statusBannerText = "Pairing with \(label) failed: \(Self.describe(error))"
            appendEventLog(statusBannerText)
            return nil
        }
    }

    /// The answer of the person at this Mac to "Does the server show this code?".
    public func confirmPairingCode(_ matches: Bool) {
        pairingPrompt = nil
        pairingDecision?.resume(returning: matches)
        pairingDecision = nil
    }

    private func runPairing(_ connection: SpoolServerConnection, signing: Curve25519.Signing.PrivateKey,
                            label: String) async throws -> (nodeID: String, serverName: String, identity: Data) {
        // The iterator stays a plain local (as in a `for try await` loop): capturing it in a
        // nested function would make it main-actor state that `next()` then has to send away.
        var events = connection.events.makeAsyncIterator()
        var message: SpoolControl?
        try await connection.send([.pairStart(deviceName: deviceName)])
        message = nil
        while message == nil, let event = try await events.next() { message = try Self.pairingControl(from: event) }
        guard case .pairCommit(let commitment) = try Self.require(message) else { throw SpoolServerConnection.Failure.protocolError("Expected a commitment") }

        let ephemeral = Curve25519.KeyAgreement.PrivateKey()
        var nonce = Data(count: 16)
        for i in nonce.indices { nonce[i] = UInt8.random(in: 0...255) }
        let own = SpoolPairing.makeHello(identity: signing.publicKey, ephemeral: ephemeral, nonce: nonce)
        try await connection.send([.pairHello(own.encoded)])
        message = nil
        while message == nil, let event = try await events.next() { message = try Self.pairingControl(from: event) }
        guard case .pairHello(let raw) = try Self.require(message), raw.count == 80 else {
            throw SpoolServerConnection.Failure.protocolError("Expected the server's hello")
        }
        let bytes = [UInt8](raw)
        let peer = SpoolPairingHello(identityKey: Data(bytes[0..<32]), ephemeralKey: Data(bytes[32..<64]), nonce: Data(bytes[64..<80]))
        let result: SpoolPairingResult = try SpoolPairing.complete(isInitiator: true, ownHello: own, ownEphemeral: ephemeral,
                                               peerHello: peer, peerCommitment: commitment)

        let code = result.shortAuthenticationCode
        let matches = await withCheckedContinuation { continuation in
            pairingDecision = continuation
            pairingPrompt = SpoolPairingPrompt(serverLabel: label, code: "\(code.prefix(3)) \(code.suffix(3))")
        }
        try await connection.send([.pairConfirm(accepted: matches)])
        guard matches else { throw SpoolRemoteError(code: .pairingRejected, message: "The codes did not match") }
        statusBannerText = "Waiting for \(label) to confirm the code…"

        message = nil
        while message == nil, let event = try await events.next() { message = try Self.pairingControl(from: event) }
        guard case .pairResult(let accepted, let nodeID, let serverName) = try Self.require(message) else {
            throw SpoolServerConnection.Failure.protocolError("Expected the pairing result")
        }
        guard accepted else { throw SpoolRemoteError(code: .pairingRejected, message: "The server's operator declined") }
        guard nodeID == SpoolNodeID.make(from: result.peerIdentityKey) else {
            throw SpoolRemoteError(code: .pairingRejected, message: "The server's node ID does not match its identity key")
        }
        return (nodeID, serverName, result.peerIdentityKey.rawRepresentation)
    }

    /// The control message carried by a pairing-time event; `nil` for anything else.
    private static func pairingControl(from event: SpoolServerConnection.Event) throws -> SpoolControl? {
        guard case .control(let message) = event else { return nil }
        if case .error(_, let text, _) = message { throw SpoolRemoteError(code: .pairingRejected, message: text) }
        return message
    }

    /// The message a pairing step waited for, or `.closed` when the stream ended first.
    private static func require(_ message: SpoolControl?) throws -> SpoolControl {
        guard let message else { throw SpoolServerConnection.Failure.closed }
        return message
    }
}
