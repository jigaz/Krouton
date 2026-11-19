import CryptoKit
import Foundation
import NetworkSpool
import OpticalCore

// MARK: - VerifyHarness — Suite 27 (continued): Leases, Cutover, Endpoint Policy, Pairing & Telemetry

extension KroutonTestHarness {

    // MARK: - Lease Fencing & Partition Expiry

    static func verifySpoolLeases(_ h: inout KroutonTestHarness) {
        let bd = DriveID("node-a/bd-12x")
        let setA = UUID()
        let setB = UUID()
        var table = DriveLeaseTable(drives: [bd], ttl: .seconds(15), bootEpoch: 3)

        let first = try? table.reserve(bd, holder: "ws-a", setID: setA, at: .zero)
        h.check(first?.fencingToken == (UInt64(3) << 32) + 1, "Fencing tokens must carry the node boot epoch")
        h.check(leaseError { try table.reserve(bd, holder: "ws-b", setID: setB, at: .seconds(1)) } == .heldByOther(holder: "ws-a"),
                "A reserved drive must never be double-claimed by a second workstation")
        h.check((try? table.reserve(bd, holder: "ws-a", setID: setA, at: .seconds(2)))?.fencingToken == first?.fencingToken,
                "A retried reserve from the same holder and set must return the same lease, not a new token")

        _ = try? table.heartbeat(bd, token: first?.fencingToken ?? 0, at: .seconds(10))
        h.check(leaseError { try table.reserve(bd, holder: "ws-b", setID: setB, at: .seconds(20)) } == .heldByOther(holder: "ws-a"),
                "A heartbeat must extend the lease past its original expiry")

        let second = try? table.reserve(bd, holder: "ws-b", setID: setB, at: .seconds(26))
        h.check(second != nil && second?.fencingToken != first?.fencingToken,
                "A workstation that slept through its TTL must lose the drive to the next reserve")
        h.check(leaseError { try table.commit(bd, token: first?.fencingToken ?? 0, at: .seconds(27)) } == .staleToken,
                "The woken workstation's laser-on with its old fencing token must be refused")

        let committedOnce = try? table.commit(bd, token: second?.fencingToken ?? 0, at: .seconds(28))
        let committedRetry = try? table.commit(bd, token: second?.fencingToken ?? 0, at: .seconds(90))
        h.check(committedOnce?.phase == .burning && committedRetry == committedOnce,
                "A lost commit reply retried with the active fencing token must be idempotent")
        table.expire(at: .seconds(10_000))
        h.check(table.leases[bd]?.phase == .burning,
                "A lease that reached laser-on must never lapse: the node finishes the disc on its own")
        h.check(leaseError { try table.reserve(DriveID("ghost"), holder: "ws-a", setID: setA, at: .zero) } == .unknownDrive,
                "Leasing a drive the node does not have must be refused")
    }

    static func leaseError(_ body: () throws -> DriveLease) -> DriveLeaseRejection? {
        do {
            _ = try body()
            return nil
        } catch {
            return error as? DriveLeaseRejection
        }
    }

    // MARK: - Store-and-Forward vs Rolling Cutover

    static func verifySpoolCutover(_ h: inout KroutonTestHarness) {
        let bd25: Int64 = 25_000_000_000
        let extent: Int64 = 4_194_304
        let plenty: Int64 = 100_000_000_000
        let gigabit = LinkThroughputStats(meanBytesPerSecond: 110e6, standardDeviation: 5e6, sampleCount: 30, isWiFi: false)
        let tenGig = LinkThroughputStats(meanBytesPerSecond: 900e6, standardDeviation: 50e6, sampleCount: 30, isWiFi: false)
        let wifi = LinkThroughputStats(meanBytesPerSecond: 40e6, standardDeviation: 15e6, sampleCount: 30, isWiFi: true)

        func lead(_ decision: SpoolCutoverDecision) -> Int64? {
            if case .rollingWindow(let bytes) = decision { return bytes }
            return nil
        }

        let wired6x = SpoolCutoverPolicy.decide(imageBytes: bd25, media: .bdSingleLayer, speedX: 6, link: gigabit,
                                                freeBytes: plenty, extentBytes: extent)
        h.check(lead(wired6x).map { (80_000_000...90_000_000).contains($0) } == true,
                "BD-25 at 6x over 1GbE must go laser-on after ~85 MB (3 s cushion), not after 25 GB")
        h.check(SpoolCutoverPolicy.decide(imageBytes: bd25, media: .bdSingleLayer, speedX: 6, link: tenGig,
                                          freeBytes: plenty, extentBytes: extent) == .storeAndForward(reason: .quickToPrestage),
                "On 10GbE a BD-25 stages in under a minute, so it must simply pre-stage")
        h.check(SpoolCutoverPolicy.decide(imageBytes: bd25, media: .bdSingleLayer, speedX: 6, link: wifi,
                                          freeBytes: plenty, extentBytes: extent) == .storeAndForward(reason: .rollingGainTooSmall),
                "Noisy Wi-Fi feeding a 6x BD writer needs >80 % lead, so it must pre-stage")
        let wifi4x = SpoolCutoverPolicy.decide(imageBytes: bd25, media: .bdSingleLayer, speedX: 4, link: wifi,
                                               freeBytes: plenty, extentBytes: extent)
        h.check(lead(wifi4x).map { (17_500_000_000...18_500_000_000).contains($0) } == true,
                "At 4x the same Wi-Fi may roll, with ~18 GB committed before laser-on")
        h.check(SpoolCutoverPolicy.decide(imageBytes: 700_000_000, media: .cdAudio, speedX: 24, link: gigabit,
                                          freeBytes: plenty, extentBytes: extent) == .storeAndForward(reason: .mediaPolicy),
                "Audio CDs must always pre-stage")
        h.check(SpoolCutoverPolicy.decide(imageBytes: bd25, media: .bdSingleLayer, speedX: 6, link: gigabit,
                                          freeBytes: 20_000_000_000, extentBytes: extent)
                == .refuse(neededBytes: bd25 + SpoolCutoverPolicy.reserveBytes, freeBytes: 20_000_000_000),
                "A node without room for the whole image must refuse: Krouton never streams straight to a laser")
        let unmeasured = LinkThroughputStats(samples: [110e6, 108e6, 111e6], isWiFi: false)
        h.check(SpoolCutoverPolicy.decide(imageBytes: bd25, media: .bdSingleLayer, speedX: 6, link: unmeasured,
                                          freeBytes: plenty, extentBytes: extent) == .storeAndForward(reason: .unmeasuredLink),
                "Fewer than 8 throughput samples must never justify a rolling burn")

        let s = 100.0, r = 10.0, l = 5.0, tau = 1.0
        let b = SpoolCutoverPolicy.requiredLeadBytes(imageBytes: s, burnRate: r, conservativeLinkRate: l,
                                                     stallSeconds: tau, extentBytes: 0)
        let stagingDone = (s - b) / l
        h.check(abs(b - 55) < 1e-9 && abs((s - r * stagingDone) - r * tau) < 1e-9,
                "Lead formula: when staging finishes, exactly one stall (R·τ) of cushion must remain")
    }

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

    // MARK: - Pairing, Session Proof, Telemetry & Path Ranking

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
                "Honest pairing must show the same 6-digit code on both screens and derive the same PSK")

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

        var conflator = SpoolTelemetryConflator()
        conflator.offer(telemetryPacket("bd0", .burningProgress, 0.40))
        conflator.offer(telemetryPacket("bd0", .burningProgress, 0.41))
        conflator.offer(telemetryPacket("dvd1", .burningProgress, 0.10))
        conflator.offer(telemetryPacket("dvd1", .burnCompleted, 1.0))
        conflator.offer(telemetryPacket("dvd1", .burningProgress, 0.99))
        let drained = conflator.drain()
        h.check(drained.map(\.driveId) == ["bd0", "dvd1"] && drained.first?.fraction == 0.41
                && drained.last?.state == .burnCompleted && conflator.drain().isEmpty,
                "Telemetry must conflate to the newest packet per drive and never let a late packet overwrite a terminal state")

        let ranked = SpoolPathRanking.rank([
            SpoolPathCandidate(nodeID: "n", interfaceName: "en0", kind: .wifi),
            SpoolPathCandidate(nodeID: "n", interfaceName: "bridge0", kind: .thunderboltBridge),
            SpoolPathCandidate(nodeID: "n", interfaceName: "en7", kind: .wiredEthernet, measuredBytesPerSecond: 1.1e9)
        ])
        h.check(ranked.map(\.interfaceName) == ["en7", "bridge0", "en0"],
                "Measured throughput must outrank the static Thunderbolt > Ethernet > Wi-Fi prior")
        let incumbent = SpoolPathCandidate(nodeID: "n", interfaceName: "en7", kind: .wiredEthernet, measuredBytesPerSecond: 1.0e9)
        let barelyFaster = SpoolPathCandidate(nodeID: "n", interfaceName: "bridge0", kind: .thunderboltBridge, measuredBytesPerSecond: 1.1e9)
        h.check(!SpoolPathRanking.shouldSwitch(from: incumbent, to: barelyFaster),
                "A path only 10 % faster must not trigger a switch (25 % hysteresis prevents flapping)")
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
