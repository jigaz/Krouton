#![forbid(unsafe_code)]
// MARK: - lib.rs

//! First-time pairing and per-session identity proofs, byte-compatible with `SpoolPairing.swift`.
//!
//! No cryptography is implemented here: X25519, Ed25519 and HKDF-SHA256 come from the audited
//! RustCrypto / dalek crates. This crate only fixes the transcript layout, and
//! `tests/golden.rs` pins that layout to vectors computed by an independent implementation.
//!
//! ```text
//! responder ─► commitment = SHA256("krouton-spool-commit-v1" ‖ responderHello)
//! initiator ─► initiatorHello   (Ed25519 pub ‖ X25519 ephemeral pub ‖ 16-byte nonce = 80 B)
//! responder ─► responderHello   (initiator checks it against the commitment)
//! both      ─► same 6-digit code; a person confirms it on both ends
//! ```

use ed25519_dalek::{Signature, Signer, SigningKey, VerifyingKey};
use hkdf::Hkdf;
use sha2::{Digest, Sha256};
use std::fmt;
use x25519_dalek::{PublicKey, StaticSecret};
use zeroize::Zeroizing;

pub const HELLO_LEN: usize = 80;
const COMMIT_LABEL: &[u8] = b"krouton-spool-commit-v1";
const TRANSCRIPT_LABEL: &[u8] = b"krouton-spool-pairing-v1";
const SESSION_LABEL: &[u8] = b"krouton-spool-session-v1|";

#[derive(Clone, Debug, PartialEq, Eq)]
pub enum PairingError {
    MalformedHello,
    CommitmentMismatch,
    /// The peer's X25519 key is a low-order point (all-zero shared secret): an active attack.
    NonContributoryKey,
}

impl fmt::Display for PairingError {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        match self {
            Self::MalformedHello => write!(f, "pairing hello is malformed"),
            Self::CommitmentMismatch => write!(f, "revealed hello does not match the earlier commitment"),
            Self::NonContributoryKey => write!(f, "peer ephemeral key is a low-order point"),
        }
    }
}

impl std::error::Error for PairingError {}

#[derive(Clone, Debug, PartialEq, Eq)]
pub struct PairingHello {
    pub identity_key: [u8; 32],
    pub ephemeral_key: [u8; 32],
    pub nonce: [u8; 16],
}

impl PairingHello {
    #[must_use]
    pub fn new(identity: &VerifyingKey, ephemeral: &StaticSecret, nonce: [u8; 16]) -> Self {
        Self { identity_key: identity.to_bytes(), ephemeral_key: PublicKey::from(ephemeral).to_bytes(), nonce }
    }

    #[must_use]
    pub fn encode(&self) -> [u8; HELLO_LEN] {
        let mut out = [0u8; HELLO_LEN];
        let (identity, rest) = out.split_at_mut(32);
        let (ephemeral, nonce) = rest.split_at_mut(32);
        identity.copy_from_slice(&self.identity_key);
        ephemeral.copy_from_slice(&self.ephemeral_key);
        nonce.copy_from_slice(&self.nonce);
        out
    }

    pub fn decode(bytes: &[u8]) -> Result<Self, PairingError> {
        let bytes: &[u8; HELLO_LEN] = bytes.try_into().map_err(|_| PairingError::MalformedHello)?;
        let (identity, rest) = bytes.split_at(32);
        let (ephemeral, nonce) = rest.split_at(32);
        Ok(Self {
            identity_key: identity.try_into().map_err(|_| PairingError::MalformedHello)?,
            ephemeral_key: ephemeral.try_into().map_err(|_| PairingError::MalformedHello)?,
            nonce: nonce.try_into().map_err(|_| PairingError::MalformedHello)?,
        })
    }
}

#[must_use]
pub fn commitment(hello: &PairingHello) -> [u8; 32] {
    Sha256::new().chain_update(COMMIT_LABEL).chain_update(hello.encode()).finalize().into()
}

pub struct PairingResult {
    /// Shown on both ends; a person must confirm they match.
    pub code: String,
    /// Stored per peer node ID. Wiped from memory when dropped.
    pub pairing_key: Zeroizing<[u8; 32]>,
    /// Pinned; every later session must prove possession of the matching private key.
    pub peer_identity: VerifyingKey,
    pub peer_node_id: String,
}

impl fmt::Debug for PairingResult {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        f.debug_struct("PairingResult")
            .field("code", &self.code)
            .field("pairing_key", &"<redacted>")
            .field("peer_node_id", &self.peer_node_id)
            .finish_non_exhaustive()
    }
}

/// The initiator passes the responder's earlier commitment; the responder passes `None`.
pub fn complete(
    is_initiator: bool,
    own: &PairingHello,
    own_ephemeral: &StaticSecret,
    peer: &PairingHello,
    peer_commitment: Option<&[u8; 32]>,
) -> Result<PairingResult, PairingError> {
    if is_initiator && peer_commitment.is_none() {
        return Err(PairingError::CommitmentMismatch);
    }
    if let Some(expected) = peer_commitment
        && !constant_time_eq(&commitment(peer), expected)
    {
        return Err(PairingError::CommitmentMismatch);
    }
    let peer_identity = VerifyingKey::from_bytes(&peer.identity_key).map_err(|_| PairingError::MalformedHello)?;
    let shared = own_ephemeral.diffie_hellman(&PublicKey::from(peer.ephemeral_key));
    if !shared.was_contributory() {
        return Err(PairingError::NonContributoryKey);
    }
    let (first, second) = if is_initiator { (own, peer) } else { (peer, own) };
    let salt: [u8; 32] = Sha256::new()
        .chain_update(TRANSCRIPT_LABEL)
        .chain_update(first.encode())
        .chain_update(second.encode())
        .finalize()
        .into();
    let hkdf = Hkdf::<Sha256>::new(Some(&salt), shared.as_bytes());
    let mut code_bytes = Zeroizing::new([0u8; 8]);
    let mut pairing_key = Zeroizing::new([0u8; 32]);
    // Both lengths are far below HKDF-SHA256's 8,160-byte limit, so expand cannot fail.
    hkdf.expand(b"sas", code_bytes.as_mut()).map_err(|_| PairingError::MalformedHello)?;
    hkdf.expand(b"pairing-key", pairing_key.as_mut()).map_err(|_| PairingError::MalformedHello)?;
    let code = u64::from_be_bytes(*code_bytes) % 1_000_000;
    Ok(PairingResult {
        code: format!("{code:06}"),
        pairing_key,
        peer_node_id: spoold_proto::identity::node_id(&peer.identity_key),
        peer_identity,
    })
}

/// `"krouton-spool-session-v1|" ‖ role ‖ "|" ‖ exporter`. The role string stops a signature being
/// reflected back at its sender; the exporter binds it to one TLS session.
#[must_use]
pub fn session_message(exporter: &[u8], role: &str) -> Vec<u8> {
    [SESSION_LABEL, role.as_bytes(), b"|", exporter].concat()
}

#[must_use]
pub fn sign_session(exporter: &[u8], role: &str, identity: &SigningKey) -> [u8; 64] {
    identity.sign(&session_message(exporter, role)).to_bytes()
}

/// Strict verification: rejects non-canonical and small-order signatures and keys.
#[must_use]
pub fn verify_session(signature: &[u8; 64], exporter: &[u8], role: &str, pinned: &VerifyingKey) -> bool {
    pinned.verify_strict(&session_message(exporter, role), &Signature::from_bytes(signature)).is_ok()
}

fn constant_time_eq(a: &[u8; 32], b: &[u8; 32]) -> bool {
    a.iter().zip(b).fold(0u8, |diff, (x, y)| diff | (x ^ y)) == 0
}

// MARK: - Seed-Based Helpers for Deterministic Verification & CLI Pairing

impl PairingHello {
    #[must_use]
    pub fn from_seeds(identity_seed: &[u8; 32], ephemeral_seed: &[u8; 32], nonce: [u8; 16]) -> Self {
        let id = SigningKey::from_bytes(identity_seed).verifying_key();
        let eph = StaticSecret::from(*ephemeral_seed);
        Self::new(&id, &eph, nonce)
    }
}

pub fn complete_from_seeds(
    is_initiator: bool,
    own: &PairingHello,
    own_ephemeral_seed: &[u8; 32],
    peer: &PairingHello,
    peer_commitment: Option<&[u8; 32]>,
) -> Result<PairingResult, PairingError> {
    let eph = StaticSecret::from(*own_ephemeral_seed);
    complete(is_initiator, own, &eph, peer, peer_commitment)
}

#[must_use]
pub fn sign_session_from_seed(
    exporter: &[u8],
    role: &str,
    identity_seed: &[u8; 32],
) -> [u8; 64] {
    let key = SigningKey::from_bytes(identity_seed);
    sign_session(exporter, role, &key)
}

#[must_use]
pub fn verify_session_from_bytes(
    signature: &[u8; 64],
    exporter: &[u8],
    role: &str,
    pinned_public_key: &[u8; 32],
) -> bool {
    let Ok(vk) = VerifyingKey::from_bytes(pinned_public_key) else {
        return false;
    };
    verify_session(signature, exporter, role, &vk)
}
