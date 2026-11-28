import CryptoKit
import Foundation

// MARK: - Node Identity

/// A node's ID: the first 16 bytes of SHA-256 of its Ed25519 public key, in lowercase base32
/// without padding (26 characters).
public enum SpoolNodeID {
    /// The ID of `key`.
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

/// One side's pairing hello: its Ed25519 identity key, an X25519 ephemeral key and a 16-byte nonce.
public struct SpoolPairingHello: Sendable, Equatable {
    /// The Ed25519 identity public key (32 bytes).
    public let identityKey: Data
    /// The X25519 ephemeral public key (32 bytes).
    public let ephemeralKey: Data
    /// 16 random bytes.
    public let nonce: Data

    /// The three fields joined, 80 bytes, as sent.
    public var encoded: Data { identityKey + ephemeralKey + nonce }
}

/// What pairing establishes.
public struct SpoolPairingResult: Sendable {
    /// The six-digit code both screens show; the user confirms they match.
    public let shortAuthenticationCode: String
    /// A key both sides derived from the exchange.
    public let pairingKey: SymmetricKey
    /// The peer's identity key, to pin.
    public let peerIdentityKey: Curve25519.Signing.PublicKey
    /// The peer's node ID.
    public let peerNodeID: String
}

/// Why pairing failed.
public enum SpoolPairingError: Error, Sendable, Equatable {
    /// The peer's hello had a bad key or nonce.
    case malformedHello
    /// The peer's hello didn't match what it committed to first.
    case commitmentMismatch
}

/// First-time pairing by numeric comparison with commit-then-reveal: the responder commits to its
/// hello before seeing the initiator's, so neither side can pick its keys to steer the six-digit
/// code. Both derive the code and a pairing key from an X25519 exchange and the transcript.
public enum SpoolPairing {
    /// Builds this side's hello.
    public static func makeHello(
        identity: Curve25519.Signing.PublicKey,
        ephemeral: Curve25519.KeyAgreement.PrivateKey,
        nonce: Data
    ) -> SpoolPairingHello {
        SpoolPairingHello(identityKey: identity.rawRepresentation,
                          ephemeralKey: ephemeral.publicKey.rawRepresentation,
                          nonce: nonce)
    }

    /// SHA-256 of a fixed label and the hello, sent before the hello itself.
    public static func commitment(to hello: SpoolPairingHello) -> Data {
        Data(SHA256.hash(data: Data("krouton-spool-commit-v1".utf8) + hello.encoded))
    }

    /// Checks the peer's hello against its commitment (the initiator, which received one, must
    /// pass it; the other side checks one if given) and derives the code and the pairing key.
    public static func complete(
        isInitiator: Bool,
        ownHello: SpoolPairingHello,
        ownEphemeral: Curve25519.KeyAgreement.PrivateKey,
        peerHello: SpoolPairingHello,
        peerCommitment: Data?
    ) throws(SpoolPairingError) -> SpoolPairingResult {
        if isInitiator {
            guard let peerCommitment else { throw .commitmentMismatch }
            let expected = commitment(to: peerHello)
            guard expected.count == peerCommitment.count,
                  zip(expected, peerCommitment).reduce(UInt8(0), { $0 | ($1.0 ^ $1.1) }) == 0 else {
                throw .commitmentMismatch
            }
        } else if let peerCommitment {
            let expected = commitment(to: peerHello)
            guard expected.count == peerCommitment.count,
                  zip(expected, peerCommitment).reduce(UInt8(0), { $0 | ($1.0 ^ $1.1) }) == 0 else {
                throw .commitmentMismatch
            }
        }
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

/// Binds a connection to a pinned identity: each side signs the TLS exporter secret and its role
/// with its Ed25519 key, and the other checks it against the key pinned at pairing.
public enum SpoolSessionProof {
    /// Signs the exporter secret and role.
    public static func sign(exporter: Data, role: String, identity: Curve25519.Signing.PrivateKey) throws -> Data {
        try identity.signature(for: message(exporter: exporter, role: role))
    }

    /// True when `signature` is `pinnedKey`'s over the exporter secret and role.
    public static func verify(_ signature: Data, exporter: Data, role: String,
                              pinnedKey: Curve25519.Signing.PublicKey) -> Bool {
        pinnedKey.isValidSignature(signature, for: message(exporter: exporter, role: role))
    }

    static func message(exporter: Data, role: String) -> Data {
        Data("krouton-spool-session-v1|\(role)|".utf8) + exporter
    }
}
