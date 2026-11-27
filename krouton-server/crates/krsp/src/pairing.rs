// MARK: - pairing.rs

//! First-time pairing (`SpoolPairing.swift`): commit-then-reveal numeric comparison.
//!
//! The server (responder) commits to its hello before seeing the app's, so a man in the middle
//! cannot grind ephemeral keys until the 6-digit codes match: it gets one guess, a 1-in-a-million
//! chance, and a mismatch is visible to both people comparing codes.
//!
//! The elliptic-curve parts (X25519 agreement, Ed25519 identities) live in the binary crate; this
//! module is the transcript, commitment and key derivation, pinned by the golden vectors.

use crate::control::PAIRING_HELLO_LEN;
use crate::sha256::Sha256;

const COMMIT_LABEL: &[u8] = b"krouton-spool-commit-v1";
const TRANSCRIPT_LABEL: &[u8] = b"krouton-spool-pairing-v1";

/// `identity (Ed25519, 32) ‖ ephemeral (X25519, 32) ‖ nonce (16)`.
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub struct PairingHello {
    pub identity_key: [u8; 32],
    pub ephemeral_key: [u8; 32],
    pub nonce: [u8; 16],
}

impl PairingHello {
    #[must_use]
    pub fn encode(&self) -> [u8; PAIRING_HELLO_LEN] {
        let mut out = [0u8; PAIRING_HELLO_LEN];
        let (id, rest) = out.split_at_mut(32);
        let (eph, nonce) = rest.split_at_mut(32);
        id.copy_from_slice(&self.identity_key);
        eph.copy_from_slice(&self.ephemeral_key);
        nonce.copy_from_slice(&self.nonce);
        out
    }

    #[must_use]
    pub fn decode(bytes: &[u8; PAIRING_HELLO_LEN]) -> Self {
        let mut hello = Self { identity_key: [0; 32], ephemeral_key: [0; 32], nonce: [0; 16] };
        let (id, rest) = bytes.split_at(32);
        let (eph, nonce) = rest.split_at(32);
        hello.identity_key.copy_from_slice(id);
        hello.ephemeral_key.copy_from_slice(eph);
        hello.nonce.copy_from_slice(nonce);
        hello
    }
}

/// `SHA256("krouton-spool-commit-v1" ‖ hello)`.
#[must_use]
pub fn commitment(hello: &PairingHello) -> [u8; 32] {
    Sha256::digest(&[COMMIT_LABEL, &hello.encode()])
}

/// `SHA256("krouton-spool-pairing-v1" ‖ initiator hello ‖ responder hello)`, the HKDF salt.
#[must_use]
pub fn transcript_salt(initiator: &PairingHello, responder: &PairingHello) -> [u8; 32] {
    Sha256::digest(&[TRANSCRIPT_LABEL, &initiator.encode(), &responder.encode()])
}

#[derive(Clone, Debug, PartialEq, Eq)]
pub struct PairingSecrets {
    /// Six digits, zero-padded, shown on both screens.
    pub code: String,
    /// Long-term pairing key (reserved for PSK resumption; not needed by the pinned-TLS flow).
    pub key: [u8; 32],
}

/// Derives the code and key from the X25519 shared secret, exactly like CryptoKit's
/// `hkdfDerivedSymmetricKey(using: SHA256, salt:, sharedInfo:, outputByteCount:)`.
#[must_use]
pub fn derive(shared_secret: &[u8; 32], salt: &[u8; 32]) -> PairingSecrets {
    let mut code_key = [0u8; 8];
    hkdf_sha256(salt, shared_secret, b"sas", &mut code_key);
    let mut key = [0u8; 32];
    hkdf_sha256(salt, shared_secret, b"pairing-key", &mut key);
    let code = u64::from_be_bytes(code_key) % 1_000_000;
    PairingSecrets { code: format!("{code:06}"), key }
}

/// Constant-time equality for digests and MACs.
#[must_use]
pub fn ct_eq(a: &[u8], b: &[u8]) -> bool {
    a.len() == b.len() && a.iter().zip(b).fold(0u8, |acc, (x, y)| acc | (x ^ y)) == 0
}

// MARK: - HMAC-SHA256 / HKDF-SHA256 (RFC 2104 / RFC 5869)

#[must_use]
pub fn hmac_sha256(key: &[u8], message: &[u8]) -> [u8; 32] {
    let mut block = [0u8; 64];
    if key.len() > 64 {
        block.get_mut(..32).unwrap_or_default().copy_from_slice(&Sha256::digest(&[key]));
    } else {
        block.get_mut(..key.len()).unwrap_or_default().copy_from_slice(key);
    }
    let ipad: Vec<u8> = block.iter().map(|b| b ^ 0x36).collect();
    let opad: Vec<u8> = block.iter().map(|b| b ^ 0x5c).collect();
    let inner = Sha256::digest(&[&ipad, message]);
    Sha256::digest(&[&opad, &inner])
}

/// Fills `out` (at most 255 × 32 bytes) with HKDF-Expand(HKDF-Extract(salt, ikm), info).
pub fn hkdf_sha256(salt: &[u8], ikm: &[u8], info: &[u8], out: &mut [u8]) {
    let prk = hmac_sha256(salt, ikm);
    let mut previous: Vec<u8> = Vec::new();
    for (i, chunk) in out.chunks_mut(32).enumerate() {
        let counter = u8::try_from(i + 1).unwrap_or(u8::MAX);
        let block = hmac_sha256(&prk, &[previous.as_slice(), info, &[counter]].concat());
        chunk.copy_from_slice(block.get(..chunk.len()).unwrap_or_default());
        previous = block.to_vec();
    }
}

#[cfg(test)]
#[allow(clippy::unwrap_used)]
mod tests {
    use super::*;
    use crate::{hex, unhex};

    #[test]
    fn rfc4231_hmac_and_rfc5869_hkdf() {
        // RFC 4231 test case 2.
        assert_eq!(
            hex(&hmac_sha256(b"Jefe", b"what do ya want for nothing?")),
            "5bdcc146bf60754e6a042426089575c75a003f089d2739839dec58b964ec3843"
        );
        // RFC 4231 test case 6 (key longer than the block).
        assert_eq!(
            hex(&hmac_sha256(&[0xaa; 131], b"Test Using Larger Than Block-Size Key - Hash Key First")),
            "60e431591ee0b67f0d8a26aacbf5b77f8e0bc6213728c5140546040f0ee37f54"
        );
        // RFC 5869 test case 1.
        let mut okm = [0u8; 42];
        hkdf_sha256(
            &unhex("000102030405060708090a0b0c").unwrap(),
            &[0x0b; 22],
            &unhex("f0f1f2f3f4f5f6f7f8f9").unwrap(),
            &mut okm,
        );
        assert_eq!(hex(&okm), "3cb25f25faacd57a90434f64d0362f2a2d2d0a90cf1a5a4c5db02d56ecc4c5bf34007208d5b887185865");
    }

    #[test]
    fn hello_round_trip() {
        let hello = PairingHello { identity_key: [1; 32], ephemeral_key: [2; 32], nonce: [3; 16] };
        assert_eq!(PairingHello::decode(&hello.encode()), hello);
        assert!(ct_eq(&[1, 2], &[1, 2]) && !ct_eq(&[1, 2], &[1, 3]) && !ct_eq(&[1], &[1, 2]));
    }
}
