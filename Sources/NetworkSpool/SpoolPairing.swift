import CryptoKit
import Foundation

// MARK: - Node Identity

public enum SpoolNodeID {
    public static func make(from key: Curve25519.Signing.PublicKey) -> String {
        base32(Array(SHA256.hash(data: key.rawRepresentation).prefix(16)))
    }

    static func base32(_ bytes: [UInt8]) -> String {
        let alphabet = Array("abcdefghijklmnopqrstuvwxyz234567")
        var out = ""
        var buffer = 0
        var bits = 0
        for byte in bytes {
            buffer = ((buffer & ((1 << bits) - 1)) << 8) | Int(byte)
            bits += 8
            while bits >= 5 {
                out.append(alphabet[(buffer >> (bits - 5)) & 31])
                bits -= 5
            }
        }
        if bits > 0 { out.append(alphabet[(buffer << (5 - bits)) & 31]) }
        return out
    }
}

// MARK: - First-Time Pairing (commit-then-reveal numeric comparison)

public struct SpoolPairingHello: Sendable, Equatable {
    public let identityKey: Data
    public let ephemeralKey: Data
    public let nonce: Data

    public var encoded: Data { identityKey + ephemeralKey + nonce }
}

public struct SpoolPairingResult: Sendable {
    public let shortAuthenticationCode: String
    public let pairingKey: SymmetricKey
    public let peerIdentityKey: Curve25519.Signing.PublicKey
    public let peerNodeID: String
}

public enum SpoolPairingError: Error, Sendable, Equatable {
    case malformedHello
    case commitmentMismatch
}

public enum SpoolPairing {
    public static func makeHello(
        identity: Curve25519.Signing.PublicKey,
        ephemeral: Curve25519.KeyAgreement.PrivateKey,
        nonce: Data
    ) -> SpoolPairingHello {
        SpoolPairingHello(identityKey: identity.rawRepresentation,
                          ephemeralKey: ephemeral.publicKey.rawRepresentation,
                          nonce: nonce)
    }

    public static func commitment(to hello: SpoolPairingHello) -> Data {
        Data(SHA256.hash(data: Data("krouton-spool-commit-v1".utf8) + hello.encoded))
    }

    public static func complete(
        isInitiator: Bool,
        ownHello: SpoolPairingHello,
        ownEphemeral: Curve25519.KeyAgreement.PrivateKey,
        peerHello: SpoolPairingHello,
        peerCommitment: Data?
    ) throws(SpoolPairingError) -> SpoolPairingResult {
        if let peerCommitment, commitment(to: peerHello) != peerCommitment { throw .commitmentMismatch }
        guard peerHello.nonce.count == 16,
              let peerEphemeral = try? Curve25519.KeyAgreement.PublicKey(rawRepresentation: peerHello.ephemeralKey),
              let peerIdentity = try? Curve25519.Signing.PublicKey(rawRepresentation: peerHello.identityKey),
              let shared = try? ownEphemeral.sharedSecretFromKeyAgreement(with: peerEphemeral) else {
            throw .malformedHello
        }
        let (first, second) = isInitiator ? (ownHello, peerHello) : (peerHello, ownHello)
        let transcript = Data("krouton-spool-pairing-v1".utf8) + first.encoded + second.encoded
        let salt = Data(SHA256.hash(data: transcript))
        let codeKey = shared.hkdfDerivedSymmetricKey(using: SHA256.self, salt: salt,
                                                     sharedInfo: Data("sas".utf8), outputByteCount: 8)
        let pairingKey = shared.hkdfDerivedSymmetricKey(using: SHA256.self, salt: salt,
                                                        sharedInfo: Data("pairing-key".utf8), outputByteCount: 32)
        let code = codeKey.withUnsafeBytes { raw in raw.reduce(UInt64(0)) { ($0 << 8) | UInt64($1) } } % 1_000_000
        return SpoolPairingResult(
            shortAuthenticationCode: String(format: "%06llu", code),
            pairingKey: pairingKey,
            peerIdentityKey: peerIdentity,
            peerNodeID: SpoolNodeID.make(from: peerIdentity)
        )
    }
}

// MARK: - Per-Session Identity Proof (channel binding)

public enum SpoolSessionProof {
    public static func sign(exporter: Data, role: String, identity: Curve25519.Signing.PrivateKey) throws -> Data {
        try identity.signature(for: message(exporter: exporter, role: role))
    }

    public static func verify(_ signature: Data, exporter: Data, role: String,
                              pinnedKey: Curve25519.Signing.PublicKey) -> Bool {
        pinnedKey.isValidSignature(signature, for: message(exporter: exporter, role: role))
    }

    static func message(exporter: Data, role: String) -> Data {
        Data("krouton-spool-session-v1|\(role)|".utf8) + exporter
    }
}
