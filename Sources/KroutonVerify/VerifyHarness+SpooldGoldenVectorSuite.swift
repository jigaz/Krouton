import CryptoKit
import Foundation
import NetworkSpool

// MARK: - VerifyHarness — Suite 29: KRSP Golden Vectors (Swift <-> Rust spoold parity)
//
// Reads Vectors/krsp-golden-v1.txt, the same file krouton-spoold-verify (Rust) checks. An
// independent Python implementation produced it (tools/gen_golden_vectors.py in the spoold repo).
// If this suite and the Rust harness both pass, the two daemons agree byte for byte.

extension KroutonTestHarness {
    mutating func runVerifySpooldGoldenVectorSuite() {
        let url = Self.repositoryRoot.appendingPathComponent("Vectors/krsp-golden-v1.txt")
        let vectors = Self.goldenVectors(at: url)
        self.runSuite("29. KRSP Golden Vectors: Byte Parity With krouton-spoold (Rust)") { h in
            h.check(vectors.count >= 30, "Golden vector file loads from \(url.path)")
            Self.verifyGoldenFramesAndManifest(&h, vectors)
            Self.verifyGoldenIdentityAndPairing(&h, vectors)
        }
    }

    // MARK: - Frames, Manifest, Bitmap & Journal

    static func verifyGoldenFramesAndManifest(_ h: inout KroutonTestHarness, _ v: [String: String]) {
        let extent = SpoolFrameHeader(kind: .extentData, extentIndex: 7, firstLBA: 28, sectorSize: 2352,
                                      payloadLength: 2352 * 2, digest: [UInt8](repeating: 0xAB, count: 32))
        h.check(Self.goldenHex(extent.encoded()) == v["frame.extent_header"], "Extent header bytes match the reference")
        h.check(Self.goldenHex(SpoolFrame.signal(.credit, extentIndex: 4).encoded()) == v["frame.credit_4"], "Credit frame bytes match")
        h.check(Self.goldenHex(SpoolFrame.signal(.extentAck, extentIndex: 7).encoded()) == v["frame.ack_7"], "Ack frame bytes match")

        let image = Self.spoolTestImage()
        let manifest = SpoolTransferManifest(image: image, sectorSize: 2352, sectorsPerExtent: 4)
        h.check(manifest.map { String($0.extentCount) } == v["manifest.extent_count"], "Extent count matches")
        h.check(manifest.map { Self.goldenHex($0.leafDigests[0]) } == v["manifest.leaf_0"], "Leaf 0 matches")
        h.check(manifest.map { Self.goldenHex($0.leafDigests[25]) } == v["manifest.leaf_25"], "Short tail leaf matches")
        h.check(manifest.map { Self.goldenHex($0.root) } == v["manifest.root"], "Merkle root matches")

        let three = Self.goldenBytes(v["merkle.three_leaves_input"])
        let leaves = stride(from: 0, to: three.count, by: 32).map { Array(three[$0..<min($0 + 32, three.count)]) }
        let threeRoot = SpoolTransferManifest(sectorSize: 2048, sectorsPerExtent: 1, totalSectors: 3, leafDigests: leaves).root
        h.check(Self.goldenHex(threeRoot) == v["merkle.three_leaves_root"], "Odd trailing node is promoted unchanged")

        var bitmap = ExtentBitmap(count: 26)
        for index in [0, 2, 5, 25] { bitmap.insert(index) }
        h.check(Self.goldenHex(bitmap.bytes) == v["bitmap.set_0_2_5_25"], "Bitmap is LSB-first")
        if let manifest {
            let record = ExtentCommitRecord(extentIndex: 5, leafDigest: manifest.leafDigests[5]).encoded()
            h.check(Self.goldenHex(record) == v["journal.record_5"], "44-byte commit record matches")
            let offer = manifest.encodeManifestOffer()
            let decodedOffer = offer.flatMap { SpoolTransferManifest(manifestOffer: $0) }
            h.check(decodedOffer == manifest, "Kind-10 ManifestOffer frame round-trips identically to Rust spoold-proto")
        }
    }

    // MARK: - Identity, Pin, Pairing & Session Proof

    static func verifyGoldenIdentityAndPairing(_ h: inout KroutonTestHarness, _ v: [String: String]) {
        guard let alice = try? Curve25519.Signing.PrivateKey(rawRepresentation: Data(Self.goldenBytes(v["pairing.alice_seed"]))),
              let bob = try? Curve25519.Signing.PrivateKey(rawRepresentation: Data(Self.goldenBytes(v["identity.bob_seed"]))),
              let aliceEph = try? Curve25519.KeyAgreement.PrivateKey(rawRepresentation: Data(Self.goldenBytes(v["pairing.alice_ephemeral_secret"]))),
              let bobEph = try? Curve25519.KeyAgreement.PrivateKey(rawRepresentation: Data(Self.goldenBytes(v["pairing.bob_ephemeral_secret"]))) else {
            h.check(false, "Golden keys must load")
            return
        }
        h.check(Self.goldenHex(Array(bob.publicKey.rawRepresentation)) == v["identity.bob_public"], "Ed25519 seed -> public key matches")
        h.check(SpoolNodeID.make(from: bob.publicKey) == v["identity.bob_node_id"], "Node ID matches")
        let x963 = Self.goldenBytes(v["tls.p256_x963"])
        let pinMatches = (try? P256.Signing.PublicKey(x963Representation: x963))
            .map { Self.goldenHex(Array(SHA256.hash(data: $0.x963Representation))) == v["tls.p256_pin"] } ?? false
        h.check(pinMatches, "mTLS pin = SHA256(X9.63 P-256 key) matches")

        let helloA = SpoolPairing.makeHello(identity: alice.publicKey, ephemeral: aliceEph, nonce: Data(repeating: 1, count: 16))
        let helloB = SpoolPairing.makeHello(identity: bob.publicKey, ephemeral: bobEph, nonce: Data(repeating: 2, count: 16))
        h.check(Self.goldenHex(Array(helloA.encoded)) == v["pairing.hello_alice"] && Self.goldenHex(Array(helloB.encoded)) == v["pairing.hello_bob"],
                "Pairing hellos match")
        h.check(Self.goldenHex(Array(SpoolPairing.commitment(to: helloB))) == v["pairing.commitment_bob"], "Commitment matches")
        let atA = try? SpoolPairing.complete(isInitiator: true, ownHello: helloA, ownEphemeral: aliceEph,
                                             peerHello: helloB, peerCommitment: SpoolPairing.commitment(to: helloB))
        let atB = try? SpoolPairing.complete(isInitiator: false, ownHello: helloB, ownEphemeral: bobEph,
                                             peerHello: helloA, peerCommitment: nil)
        h.check(atA?.shortAuthenticationCode == v["pairing.code"] && atB?.shortAuthenticationCode == v["pairing.code"],
                "Both ends show the reference 6-digit code")
        h.check(atA.map { Self.goldenHex(Array($0.pairingKey.withUnsafeBytes { Data($0) })) } == v["pairing.key"], "Pairing key matches")

        let exporter = Data(Self.goldenBytes(v["session.exporter"]))
        let signature = Data(Self.goldenBytes(v["session.signature_bob_node"]))
        h.check(SpoolSessionProof.verify(signature, exporter: exporter, role: "node", pinnedKey: bob.publicKey),
                "Reference session proof verifies against the pinned key")
        h.check(!SpoolSessionProof.verify(signature, exporter: exporter, role: "workstation", pinnedKey: bob.publicKey),
                "Session proof is bound to its role")
    }

    // MARK: - Parsing Helpers

    static func goldenVectors(at url: URL) -> [String: String] {
        let text = (try? String(contentsOf: url, encoding: .utf8)) ?? ""
        var out: [String: String] = [:]
        for line in text.components(separatedBy: .newlines) where !line.hasPrefix("#") {
            guard let range = line.range(of: " = ") else { continue }
            out[String(line[..<range.lowerBound])] = String(line[range.upperBound...])
        }
        return out
    }

    private static func goldenHex(_ bytes: [UInt8]) -> String {
        bytes.map { String(format: "%02x", $0) }.joined()
    }

    private static func goldenBytes(_ hexString: String?) -> [UInt8] {
        guard let hexString, hexString.count.isMultiple(of: 2) else { return [] }
        var out: [UInt8] = []
        var index = hexString.startIndex
        while index < hexString.endIndex {
            let next = hexString.index(index, offsetBy: 2)
            guard let byte = UInt8(hexString[index..<next], radix: 16) else { return [] }
            out.append(byte)
            index = next
        }
        return out
    }
}
