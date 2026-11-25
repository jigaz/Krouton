import CryptoKit
import Foundation
import NetworkSpool
import OpticalCore

// MARK: - VerifyHarness — Suite 27 (continued): Endpoint Policy, Pairing, Session Proof & Telemetry

extension KroutonTestHarness {

    // MARK: - Endpoint Policy (SSRF, DNS rebinding, query smuggling, VPN overlays)

    static func verifySpoolEndpointPolicy(_ h: inout KroutonTestHarness) {
        let strict = SpoolEndpointPolicy()
        let cases: [(String, SpoolHostVerdict)] = [
            ("10.0.0.1", .allowedLiteral(.privateLAN)),
            ("010.0.0.1", .denied(.unsupportedHostName)),
            ("8.8.8.8", .denied(.publicAddress)),
            ("0.0.0.0", .denied(.unspecifiedOrMulticast)),
            ("224.0.0.251", .denied(.unspecifiedOrMulticast)),
            ("100.100.10.1", .denied(.publicAddress)),
            ("[fd7a:115c:a1e0::1]", .allowedLiteral(.uniqueLocalIPv6)),
            ("fe80::1%en0", .allowedLiteral(.linkLocal)),
            ("febf::1", .allowedLiteral(.linkLocal)),
            ("::1", .allowedLiteral(.loopback)),
            ("::ffff:192.168.1.4", .allowedLiteral(.privateLAN)),
            ("::ffff:8.8.8.8", .denied(.publicAddress)),
            ("64:ff9b::808:808", .denied(.translatedPublicAddress)),
            ("2002:808:808::1", .denied(.translatedPublicAddress)),
            ("studio-rack.local", .resolveThenEvaluate),
            ("evil.lan", .denied(.unsupportedHostName)),
            ("spool.example.com", .denied(.unsupportedHostName))
        ]
        for (host, expected) in cases {
            h.check(strict.evaluate(host: host) == expected, "Endpoint policy: \(host) must be \(expected)")
        }

        h.check(!SpoolLANSecurityEngine.isAllowedLANEndpoint("http://evil.com?.local")
                && !SpoolLANSecurityEngine.isAllowedLANEndpoint("http://evil.com#.local")
                && !SpoolLANSecurityEngine.isAllowedLANEndpoint("http://user@192.168.1.10:7420")
                && !SpoolLANSecurityEngine.isAllowedLANEndpoint("http://010.0.0.1:7420"),
                "SpoolLANSecurityEngine must block query/fragment .local smuggling, userinfo, and octal IPv4")

        let tailnet = SpoolEndpointPolicy(allowsOverlayCGNAT: true)
        h.check(tailnet.evaluate(host: "100.100.10.1") == .allowedLiteral(.overlayCGNAT),
                "100.64.0.0/10 must be reachable only after the Tailscale/overlay opt-in")

        let ranges = [SpoolCIDR("203.0.113.0/24"), SpoolCIDR("0.0.0.0/0")].compactMap { $0 }
        let studio = SpoolEndpointPolicy(trustedRanges: ranges)
        h.check(studio.trustedRanges.count == 1 && studio.evaluate(host: "203.0.113.40") == .allowedLiteral(.trustedStudioRange),
                "An explicit studio range must be honoured and a /0 'trust everything' range dropped")
    }

    // MARK: - Pairing, Session Proof & Telemetry

    static func verifySpoolPairingAndTelemetry(_ h: inout KroutonTestHarness) {
        guard let alice = try? Curve25519.Signing.PrivateKey(rawRepresentation: Data(repeating: 0x11, count: 32)),
              let bob = try? Curve25519.Signing.PrivateKey(rawRepresentation: Data(repeating: 0x22, count: 32)),
              let aliceEph = try? Curve25519.KeyAgreement.PrivateKey(rawRepresentation: Data(repeating: 0x33, count: 32)),
              let bobEph = try? Curve25519.KeyAgreement.PrivateKey(rawRepresentation: Data(repeating: 0x44, count: 32)),
              let malloryEph = try? Curve25519.KeyAgreement.PrivateKey(rawRepresentation: Data(repeating: 0x55, count: 32)) else {
            h.check(false, "Fixed test keys must load")
            return
        }
        let helloA = SpoolPairing.makeHello(identity: alice.publicKey, ephemeral: aliceEph, nonce: Data(repeating: 1, count: 16))
        let helloB = SpoolPairing.makeHello(identity: bob.publicKey, ephemeral: bobEph, nonce: Data(repeating: 2, count: 16))
        let atA = try? SpoolPairing.complete(isInitiator: true, ownHello: helloA, ownEphemeral: aliceEph,
                                             peerHello: helloB, peerCommitment: SpoolPairing.commitment(to: helloB))
        let atB = try? SpoolPairing.complete(isInitiator: false, ownHello: helloB, ownEphemeral: bobEph,
                                             peerHello: helloA, peerCommitment: nil)
        let keyA = atA?.pairingKey.withUnsafeBytes { Data($0) }
        let keyB = atB?.pairingKey.withUnsafeBytes { Data($0) }
        h.check(atA != nil && atA?.shortAuthenticationCode == atB?.shortAuthenticationCode && keyA == keyB
                && atA?.peerNodeID == SpoolNodeID.make(from: bob.publicKey) && atA?.shortAuthenticationCode.count == 6,
                "Honest pairing must show the same 6-digit code on both screens and derive the same pairing key")

        let spoofedB = SpoolPairing.makeHello(identity: bob.publicKey, ephemeral: malloryEph, nonce: Data(repeating: 2, count: 16))
        let fooled = try? SpoolPairing.complete(isInitiator: true, ownHello: helloA, ownEphemeral: aliceEph,
                                                peerHello: spoofedB, peerCommitment: SpoolPairing.commitment(to: spoofedB))
        h.check(fooled?.shortAuthenticationCode != atB?.shortAuthenticationCode,
                "A man in the middle substituting the ephemeral key must produce mismatched codes")
        h.check(pairingError { try SpoolPairing.complete(isInitiator: true, ownHello: helloA, ownEphemeral: aliceEph,
                                                         peerHello: spoofedB, peerCommitment: SpoolPairing.commitment(to: helloB)) }
                == .commitmentMismatch,
                "A revealed hello that does not match the earlier commitment must abort pairing")
        h.check(pairingError { try SpoolPairing.complete(isInitiator: true, ownHello: helloA, ownEphemeral: aliceEph,
                                                         peerHello: helloB, peerCommitment: nil) }
                == .commitmentMismatch,
                "A missing commitment on initiator must abort pairing")

        let exporter = Data(repeating: 7, count: 32)
        let proof = try? SpoolSessionProof.sign(exporter: exporter, role: "node", identity: bob)
        h.check(proof.map { SpoolSessionProof.verify($0, exporter: exporter, role: "node", pinnedKey: bob.publicKey) } == true
                && proof.map { SpoolSessionProof.verify($0, exporter: exporter, role: "node", pinnedKey: alice.publicKey) } == false
                && proof.map { SpoolSessionProof.verify($0, exporter: exporter, role: "workstation", pinnedKey: bob.publicKey) } == false
                && proof.map { SpoolSessionProof.verify($0, exporter: Data(repeating: 8, count: 32), role: "node", pinnedKey: bob.publicKey) } == false,
                "Session proofs must verify only for the pinned key, the right role and this TLS session's exporter")

        let packet = { (state: SpoolTelemetryPhase, fraction: Double) in telemetryPacket("bd0", state, fraction) }
        let late = SpoolTelemetrySanitizer.sanitizeProgressTransition(previousState: .burningProgress, previousFraction: 0.41,
                                                                      incomingFrame: packet(.burningProgress, 0.40))
        let afterDone = SpoolTelemetrySanitizer.sanitizeProgressTransition(previousState: .burnCompleted, previousFraction: 1,
                                                                           incomingFrame: packet(.burningProgress, 0.99))
        h.check(late.fraction == 0.41 && afterDone.state == .burnCompleted && afterDone.fraction == 1,
                "Server telemetry must never move the progress bar backwards or reopen a finished burn")
    }

    static func pairingError(_ body: () throws -> SpoolPairingResult) -> SpoolPairingError? {
        do {
            _ = try body()
            return nil
        } catch {
            return error as? SpoolPairingError
        }
    }

    static func telemetryPacket(_ drive: String, _ state: SpoolTelemetryPhase, _ fraction: Double) -> SpoolTelemetryPacket {
        SpoolTelemetryPacket(batchId: UUID(uuidString: "00000000-0000-0000-0000-000000000027") ?? UUID(),
                             driveId: drive, state: state, fraction: fraction, currentLba: 0, totalLba: 1,
                             effectiveSpeedX: 8, fifoFill: 0.9, driveBufferFill: 0.9, c2Errors: 0, etaSeconds: 0)
    }
}
