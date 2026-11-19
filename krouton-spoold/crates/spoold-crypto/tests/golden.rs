//! Pins pairing and session proofs to `vectors/krsp-golden-v1.txt`, which an independent Python
//! implementation (hashlib + `cryptography`) produced. Swift's `krouton-verify` checks the same file.
#![allow(clippy::unwrap_used, clippy::expect_used, clippy::indexing_slicing, clippy::panic)]

use ed25519_dalek::SigningKey;
use spoold_crypto::{PairingError, PairingHello, commitment, complete, sign_session, verify_session};
use spoold_proto::unhex;
use std::collections::BTreeMap;
use x25519_dalek::StaticSecret;

const GOLDEN: &str = include_str!("../../../vectors/krsp-golden-v1.txt");

fn vectors() -> BTreeMap<&'static str, Vec<u8>> {
    GOLDEN
        .lines()
        .filter(|l| !l.starts_with('#'))
        .filter_map(|l| l.split_once(" = "))
        .filter_map(|(k, v)| unhex(v).map(|bytes| (k.trim(), bytes)))
        .collect()
}

fn text(key: &str) -> &'static str {
    GOLDEN.lines().find_map(|l| l.strip_prefix(&format!("{key} = "))).expect("vector present")
}

fn arr<const N: usize>(v: &BTreeMap<&str, Vec<u8>>, key: &str) -> [u8; N] {
    v[key].as_slice().try_into().expect("vector length")
}

struct Parties {
    alice_eph: StaticSecret,
    bob_eph: StaticSecret,
    hello_a: PairingHello,
    hello_b: PairingHello,
}

fn parties(v: &BTreeMap<&str, Vec<u8>>) -> Parties {
    let alice = SigningKey::from_bytes(&arr(v, "pairing.alice_seed"));
    let bob = SigningKey::from_bytes(&arr(v, "identity.bob_seed"));
    let alice_eph = StaticSecret::from(arr::<32>(v, "pairing.alice_ephemeral_secret"));
    let bob_eph = StaticSecret::from(arr::<32>(v, "pairing.bob_ephemeral_secret"));
    let hello_a = PairingHello::new(&alice.verifying_key(), &alice_eph, [1; 16]);
    let hello_b = PairingHello::new(&bob.verifying_key(), &bob_eph, [2; 16]);
    Parties { alice_eph, bob_eph, hello_a, hello_b }
}

#[test]
fn hellos_and_commitment_match_reference() {
    let v = vectors();
    let p = parties(&v);
    assert_eq!(p.hello_a.encode().as_slice(), v["pairing.hello_alice"].as_slice());
    assert_eq!(p.hello_b.encode().as_slice(), v["pairing.hello_bob"].as_slice());
    assert_eq!(commitment(&p.hello_b).as_slice(), v["pairing.commitment_bob"].as_slice());
    assert_eq!(PairingHello::decode(&p.hello_a.encode()).unwrap(), p.hello_a);
}

#[test]
fn both_ends_derive_reference_code_and_key() {
    let v = vectors();
    let p = parties(&v);
    let at_alice = complete(true, &p.hello_a, &p.alice_eph, &p.hello_b, Some(&commitment(&p.hello_b))).unwrap();
    let at_bob = complete(false, &p.hello_b, &p.bob_eph, &p.hello_a, None).unwrap();
    assert_eq!(at_alice.code, text("pairing.code"));
    assert_eq!(at_bob.code, text("pairing.code"));
    assert_eq!(at_alice.pairing_key.as_slice(), v["pairing.key"].as_slice());
    assert_eq!(*at_alice.pairing_key, *at_bob.pairing_key);
    assert_eq!(at_alice.peer_node_id, text("identity.bob_node_id"));
}

#[test]
fn mismatched_commitment_aborts() {
    let v = vectors();
    let p = parties(&v);
    let wrong = commitment(&p.hello_a);
    let err = complete(true, &p.hello_a, &p.alice_eph, &p.hello_b, Some(&wrong)).unwrap_err();
    assert_eq!(err, PairingError::CommitmentMismatch);
}

#[test]
fn substituted_ephemeral_changes_the_code() {
    let v = vectors();
    let p = parties(&v);
    let mallory_eph = StaticSecret::from([0x55; 32]);
    let bob = SigningKey::from_bytes(&arr(&v, "identity.bob_seed"));
    let spoofed = PairingHello::new(&bob.verifying_key(), &mallory_eph, [2; 16]);
    let fooled = complete(true, &p.hello_a, &p.alice_eph, &spoofed, Some(&commitment(&spoofed))).unwrap();
    assert_ne!(fooled.code, text("pairing.code"));
}

#[test]
fn low_order_peer_key_is_refused() {
    let v = vectors();
    let p = parties(&v);
    let mut evil = p.hello_b.clone();
    evil.ephemeral_key = [0; 32];
    let err = complete(true, &p.hello_a, &p.alice_eph, &evil, Some(&commitment(&evil))).unwrap_err();
    assert_eq!(err, PairingError::NonContributoryKey);
}

#[test]
fn session_proof_matches_reference_and_binds_role_and_exporter() {
    let v = vectors();
    let bob = SigningKey::from_bytes(&arr(&v, "identity.bob_seed"));
    let exporter = &v["session.exporter"];
    let reference: [u8; 64] = arr(&v, "session.signature_bob_node");
    // Ed25519 (RFC 8032) is deterministic, so our signature must equal the reference byte for byte.
    assert_eq!(sign_session(exporter, "node", &bob), reference);
    assert!(verify_session(&reference, exporter, "node", &bob.verifying_key()));
    assert!(!verify_session(&reference, exporter, "workstation", &bob.verifying_key()));
    assert!(!verify_session(&reference, &[8; 32], "node", &bob.verifying_key()));
    let alice = SigningKey::from_bytes(&arr(&v, "pairing.alice_seed"));
    assert!(!verify_session(&reference, exporter, "node", &alice.verifying_key()));
}
