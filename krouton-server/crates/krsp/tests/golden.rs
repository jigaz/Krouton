//! Byte parity with the Swift client. `Vectors/krsp-golden-v1.txt` (repo root) is the same file
//! the app's `krouton-verify` golden-vector suite checks, so a change on either side that breaks
//! the wire shows up here and there.
#![allow(clippy::unwrap_used, clippy::expect_used, clippy::indexing_slicing, clippy::cast_possible_truncation)]

use krsp::frame::{Frame, FrameHeader, FrameKind};
use krsp::manifest::{CommitRecord, ExtentBitmap, ManifestOffer, TransferManifest, merkle_root};
use krsp::{hex, identity, unhex};
use std::collections::BTreeMap;

const GOLDEN: &str = include_str!("../../../../Vectors/krsp-golden-v1.txt");

fn golden() -> BTreeMap<&'static str, &'static str> {
    GOLDEN
        .lines()
        .filter(|l| !l.starts_with('#'))
        .filter_map(|l| l.split_once(" = "))
        .map(|(k, v)| (k.trim(), v.trim()))
        .collect()
}

fn bytes(v: &BTreeMap<&str, &str>, key: &str) -> Vec<u8> {
    unhex(v[key]).unwrap()
}

/// Same deterministic bytes as Swift's `spoolTestImage()`: 102 sectors of 2352 B.
fn test_image() -> Vec<u8> {
    (0..102usize * 2352).map(|i| (i.wrapping_mul(31).wrapping_add(i >> 9) & 0xFF) as u8).collect()
}

#[test]
fn frames_match_reference_bytes() {
    let v = golden();
    let mut extent = FrameHeader::new(FrameKind::ExtentData);
    extent.extent_index = 7;
    extent.first_lba = 28;
    extent.sector_size = 2352;
    extent.payload_length = 2352 * 2;
    extent.digest = [0xAB; 32];
    assert_eq!(hex(&extent.encode()), v["frame.extent_header"]);
    assert_eq!(Frame::signal(FrameKind::Credit, 4).encode(), bytes(&v, "frame.credit_4"));
    assert_eq!(Frame::signal(FrameKind::ExtentAck, 7).encode(), bytes(&v, "frame.ack_7"));
    let flagged = FrameHeader::decode(&bytes(&v, "frame.flags_and_lba")).unwrap();
    assert_eq!(flagged.flags, 0xBEEF);
    assert_eq!(flagged.extent_index, 0x0102_0304);
    assert_eq!(flagged.first_lba, 0x0102_0304_0506_0708);
}

#[test]
fn manifest_merkle_bitmap_and_journal_match() {
    let v = golden();
    let image = test_image();
    let manifest = TransferManifest::from_image(&image, 2352, 4).unwrap();
    assert_eq!(manifest.extent_count().to_string(), v["manifest.extent_count"]);
    assert_eq!(manifest.total_sectors.to_string(), v["manifest.total_sectors"]);
    assert_eq!(hex(manifest.leaf(0).unwrap()), v["manifest.leaf_0"]);
    assert_eq!(hex(manifest.leaf(25).unwrap()), v["manifest.leaf_25"]);
    assert_eq!(hex(&manifest.root), v["manifest.root"]);

    let three: Vec<[u8; 32]> =
        bytes(&v, "merkle.three_leaves_input").chunks_exact(32).map(|c| c.try_into().unwrap()).collect();
    assert_eq!(hex(&merkle_root(&three)), v["merkle.three_leaves_root"]);
    assert_eq!(hex(&merkle_root(&[])), v["merkle.empty_root"]);

    let mut bitmap = ExtentBitmap::new(26);
    for i in [0, 2, 5, 25] {
        bitmap.insert(i);
    }
    assert_eq!(hex(bitmap.as_bytes()), v["bitmap.set_0_2_5_25"]);
    let record = CommitRecord { extent_index: 5, leaf: *manifest.leaf(5).unwrap() }.encode();
    assert_eq!(hex(&record), v["journal.record_5"]);

    // Kind-10 ManifestOffer round-trips and carries the root in the header digest.
    let offer = ManifestOffer::encode(&manifest).unwrap();
    assert_eq!(offer.header.digest, manifest.root);
    assert_eq!(ManifestOffer::decode(&offer).unwrap(), manifest);
}

#[test]
fn identity_and_pins_match() {
    let v = golden();
    let bob: [u8; 32] = bytes(&v, "identity.bob_public").try_into().unwrap();
    assert_eq!(identity::node_id(&bob), v["identity.bob_node_id"]);
    let pin = identity::tls_key_pin(&bytes(&v, "tls.p256_x963")).unwrap();
    assert_eq!(hex(&pin), v["tls.p256_pin"]);
}

#[test]
fn session_message_layout_matches() {
    let v = golden();
    let exporter = bytes(&v, "session.exporter");
    assert_eq!(identity::session_proof_message(&exporter, identity::ROLE_NODE), bytes(&v, "session.message"));
}

#[test]
fn pairing_commitment_and_salt_match() {
    use krsp::pairing::{PairingHello, commitment, transcript_salt};
    let v = golden();
    let alice = PairingHello::decode(&bytes(&v, "pairing.hello_alice").try_into().unwrap());
    let bob = PairingHello::decode(&bytes(&v, "pairing.hello_bob").try_into().unwrap());
    assert_eq!(hex(&commitment(&bob)), v["pairing.commitment_bob"]);
    assert_eq!(hex(&transcript_salt(&alice, &bob)), v["pairing.salt"]);
}
