//! The server's long-term keys and the [`NodeCrypto`] implementation, all on `ring`.
//!
//! | File in the state directory | What |
//! |---|---|
//! | `identity.ed25519.pk8` | Ed25519 identity (PKCS#8). Its hash is the node ID; it signs every session. |
//! | `tls-key.p256.pk8` | P-256 TLS key (PKCS#8). Its pin is what Krouton trusts. |
//! | `tls-cert.der` | Self-signed certificate for that key (names and dates are irrelevant: trust is by pin). |

use ring::agreement::{self, EphemeralPrivateKey, UnparsedPublicKey, X25519};
use ring::rand::{SecureRandom, SystemRandom};
use ring::signature::{ED25519, Ed25519KeyPair, KeyPair};
use server_core::{Ephemeral, NodeCrypto};
use std::path::Path;

pub const IDENTITY_FILE: &str = "identity.ed25519.pk8";
pub const TLS_KEY_FILE: &str = "tls-key.p256.pk8";
pub const TLS_CERT_FILE: &str = "tls-cert.der";

pub struct RingCrypto {
    identity: Ed25519KeyPair,
    rng: SystemRandom,
}

impl std::fmt::Debug for RingCrypto {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        f.debug_struct("RingCrypto")
            .field("identity", &krsp::hex(self.identity.public_key().as_ref()))
            .finish_non_exhaustive()
    }
}

impl RingCrypto {
    pub fn from_pkcs8(pkcs8: &[u8]) -> Result<Self, String> {
        let identity = Ed25519KeyPair::from_pkcs8(pkcs8).map_err(|e| format!("identity key is invalid: {e}"))?;
        Ok(Self { identity, rng: SystemRandom::new() })
    }

    /// Deterministic identity from a 32-byte seed (golden-vector tests only).
    pub fn from_seed(seed: &[u8; 32]) -> Result<Self, String> {
        let identity = Ed25519KeyPair::from_seed_unchecked(seed).map_err(|e| e.to_string())?;
        Ok(Self { identity, rng: SystemRandom::new() })
    }

    #[must_use]
    pub fn node_id(&self) -> String {
        krsp::identity::node_id(&self.identity_public())
    }
}

impl NodeCrypto for RingCrypto {
    fn identity_public(&self) -> [u8; 32] {
        let mut out = [0u8; 32];
        out.copy_from_slice(self.identity.public_key().as_ref());
        out
    }

    fn sign(&self, message: &[u8]) -> [u8; 64] {
        let mut out = [0u8; 64];
        out.copy_from_slice(self.identity.sign(message).as_ref());
        out
    }

    fn verify(&self, public: &[u8; 32], message: &[u8], signature: &[u8; 64]) -> bool {
        ring::signature::UnparsedPublicKey::new(&ED25519, public).verify(message, signature).is_ok()
    }

    fn ephemeral(&self) -> Box<dyn Ephemeral> {
        match EphemeralPrivateKey::generate(&X25519, &self.rng) {
            Ok(secret) => {
                let mut public = [0u8; 32];
                if let Ok(p) = secret.compute_public_key() {
                    public.copy_from_slice(p.as_ref());
                }
                Box::new(RingEphemeral { secret: Some(secret), public })
            }
            // The OS RNG failing is unrecoverable; an ephemeral that never agrees fails pairing safely.
            Err(_) => Box::new(RingEphemeral { secret: None, public: [0; 32] }),
        }
    }

    fn random16(&self) -> [u8; 16] {
        let mut out = [0u8; 16];
        let _ = self.rng.fill(&mut out);
        out
    }
}

struct RingEphemeral {
    secret: Option<EphemeralPrivateKey>,
    public: [u8; 32],
}

impl std::fmt::Debug for RingEphemeral {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        f.debug_struct("RingEphemeral").field("public", &krsp::hex(&self.public)).finish_non_exhaustive()
    }
}

impl Ephemeral for RingEphemeral {
    fn public(&self) -> [u8; 32] {
        self.public
    }

    fn agree(self: Box<Self>, peer: &[u8; 32]) -> Option<[u8; 32]> {
        let secret = self.secret?;
        agreement::agree_ephemeral(secret, &UnparsedPublicKey::new(&X25519, peer), |shared| {
            let mut out = [0u8; 32];
            out.copy_from_slice(shared);
            out
        })
        .ok()
    }
}

// MARK: - Key files

/// Creates any missing key files in `state_dir` (never overwrites). Returns what was created.
pub fn ensure_keys(state_dir: &Path, server_name: &str) -> Result<Vec<&'static str>, String> {
    std::fs::create_dir_all(state_dir).map_err(|e| format!("Could not create {}: {e}", state_dir.display()))?;
    server_core::secure_permissions(state_dir);
    let mut created = Vec::new();
    let identity_path = state_dir.join(IDENTITY_FILE);
    if !identity_path.exists() {
        let pkcs8 = Ed25519KeyPair::generate_pkcs8(&SystemRandom::new())
            .map_err(|e| format!("Could not generate the identity: {e}"))?;
        write_secret(&identity_path, pkcs8.as_ref())?;
        created.push(IDENTITY_FILE);
    }
    let key_path = state_dir.join(TLS_KEY_FILE);
    let cert_path = state_dir.join(TLS_CERT_FILE);
    if !key_path.exists() || !cert_path.exists() {
        let key = rcgen::KeyPair::generate_for(&rcgen::PKCS_ECDSA_P256_SHA256)
            .map_err(|e| format!("Could not generate the TLS key: {e}"))?;
        let mut params =
            rcgen::CertificateParams::new(vec!["krouton-server.local".to_string()]).map_err(|e| e.to_string())?;
        params.distinguished_name.push(rcgen::DnType::CommonName, server_name);
        let cert = params.self_signed(&key).map_err(|e| format!("Could not create the TLS certificate: {e}"))?;
        write_secret(&key_path, &key.serialize_der())?;
        server_core::store::write_atomically(&cert_path, cert.der()).map_err(|e| e.to_string())?;
        created.push(TLS_KEY_FILE);
        created.push(TLS_CERT_FILE);
    }
    Ok(created)
}

fn write_secret(path: &Path, bytes: &[u8]) -> Result<(), String> {
    server_core::store::write_atomically(path, bytes)
        .map_err(|e| format!("Could not write {}: {e}", path.display()))?;
    server_core::secure_permissions(path);
    Ok(())
}

pub fn load_identity(state_dir: &Path) -> Result<RingCrypto, String> {
    let bytes = std::fs::read(state_dir.join(IDENTITY_FILE))
        .map_err(|e| format!("Could not read {IDENTITY_FILE}: {e} (run `krouton-server init`)"))?;
    RingCrypto::from_pkcs8(&bytes)
}

#[cfg(test)]
#[allow(clippy::unwrap_used, clippy::indexing_slicing)]
mod tests {
    use super::*;
    use krsp::identity::{ROLE_NODE, session_proof_message};

    const GOLDEN: &str = include_str!("../../../../Vectors/krsp-golden-v1.txt");

    fn golden(key: &str) -> Vec<u8> {
        let line = GOLDEN.lines().find(|l| l.starts_with(&format!("{key} = "))).unwrap();
        krsp::unhex(line.split_once(" = ").unwrap().1).unwrap()
    }

    #[test]
    fn ed25519_matches_cryptokit_vectors() {
        let seed: [u8; 32] = golden("identity.bob_seed").try_into().unwrap();
        let bob = RingCrypto::from_seed(&seed).unwrap();
        assert_eq!(bob.identity_public().to_vec(), golden("identity.bob_public"));
        let exporter = golden("session.exporter");
        let message = session_proof_message(&exporter, ROLE_NODE);
        assert_eq!(message, golden("session.message"));
        let signature = bob.sign(&message);
        assert_eq!(signature.to_vec(), golden("session.signature_bob_node"));
        assert!(bob.verify(&bob.identity_public(), &message, &signature));
        assert!(!bob.verify(&bob.identity_public(), &session_proof_message(&exporter, "workstation"), &signature));
    }

    #[test]
    fn x25519_agreement_is_symmetric() {
        let a = RingCrypto::from_seed(&[1; 32]).unwrap();
        let (ea, eb) = (a.ephemeral(), a.ephemeral());
        let (pa, pb) = (ea.public(), eb.public());
        assert_eq!(ea.agree(&pb), eb.agree(&pa));
    }

    #[test]
    fn keys_are_created_once_and_pin_parses() {
        let tmp = server_core::testutil::TempDir::new("keys");
        let created = ensure_keys(tmp.path(), "Test").unwrap();
        assert_eq!(created.len(), 3);
        assert!(ensure_keys(tmp.path(), "Test").unwrap().is_empty());
        let cert = std::fs::read(tmp.path().join(TLS_CERT_FILE)).unwrap();
        assert!(server_core::x509::certificate_pin(&cert).is_some(), "rcgen certificate must carry a P-256 key");
        assert_eq!(load_identity(tmp.path()).unwrap().node_id().len(), 26);
    }
}
