// MARK: - suites.rs

//! The suites. Numbered S1.. so a failure points at one place. Every input is fixed, so a red
//! check is a real regression, never a flake.

use crate::faulty_link::{Faults, FaultyLink};
use crate::harness::Harness;
use spoold_proto::identity;
use spoold_proto::frame::{Frame, FrameDecoder, FrameHeader, FrameKind, HEADER_LEN, WireError};
use spoold_proto::manifest::{
    CommitRecord, ExtentBitmap, ManifestOffer, ManifestOfferError, TransferManifest, merkle_root,
};
use spoold_proto::pipeline::{SenderPhase, StagingReceiver, UploadSender};
use spoold_proto::{hex, unhex};
use std::collections::BTreeMap;

const GOLDEN: &str = include_str!("../../../vectors/krsp-golden-v1.txt");

pub fn run_all(h: &mut Harness) {
    h.suite("S1. Golden vectors: byte parity with the Swift client", golden_vectors);
    h.suite("S2. Framing: round-trip, fragmentation, hostile headers", framing);
    h.suite("S3. Manifest, Merkle, bitmap, journal & manifest offer", manifest_and_journal);
    h.suite("S4. Extent pipeline over a faulty link (Swift Suite 27 parity)", loopback_faults);
    crate::suites_policy::run_policy_suites(h);
    crate::hygiene_and_hal_suites::run_extended_suites(h);
}

// ---------------------------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------------------------

fn golden() -> BTreeMap<&'static str, &'static str> {
    GOLDEN
        .lines()
        .filter(|l| !l.starts_with('#'))
        .filter_map(|l| l.split_once(" = "))
        .map(|(k, v)| (k.trim(), v.trim()))
        .collect()
}

fn vector_bytes(v: &BTreeMap<&str, &str>, key: &str) -> Vec<u8> {
    v.get(key).and_then(|s| unhex(s)).unwrap_or_default()
}

/// Same deterministic bytes as Swift's `spoolTestImage()`: 102 sectors of 2352 B.
pub fn test_image() -> Vec<u8> {
    (0..102usize * 2352).map(|i| (i.wrapping_mul(31).wrapping_add(i >> 9) & 0xFF) as u8).collect()
}

fn test_manifest(image: &[u8]) -> TransferManifest {
    TransferManifest::from_image(image, 2352, 4).unwrap_or_else(|| TransferManifest::new(2352, 4, 0, Vec::new()))
}

// ---------------------------------------------------------------------------------------------
// S1
// ---------------------------------------------------------------------------------------------

fn golden_vectors(h: &mut Harness) {
    let v = golden();
    h.check(v.len() >= 30, "Golden vector file loads (vectors/krsp-golden-v1.txt)");

    let mut extent = FrameHeader::new(FrameKind::ExtentData);
    extent.extent_index = 7;
    extent.first_lba = 28;
    extent.sector_size = 2352;
    extent.payload_length = 2352 * 2;
    extent.digest = [0xAB; 32];
    h.check(hex(&extent.encode()) == v["frame.extent_header"], "Extent header bytes match the reference encoder");
    h.check(
        Frame::signal(FrameKind::Credit, 4).encode() == vector_bytes(&v, "frame.credit_4"),
        "Credit frame bytes match",
    );
    h.check(
        Frame::signal(FrameKind::ExtentAck, 7).encode() == vector_bytes(&v, "frame.ack_7"),
        "Ack frame bytes match",
    );
    let flagged = FrameHeader::decode(&vector_bytes(&v, "frame.flags_and_lba"));
    h.check(
        flagged
            .as_ref()
            .is_ok_and(|f| f.flags == 0xBEEF && f.extent_index == 0x0102_0304 && f.first_lba == 0x0102_0304_0506_0708),
        "Every multi-byte header field decodes big-endian",
    );

    let image = test_image();
    let manifest = test_manifest(&image);
    h.check(manifest.extent_count().to_string() == v["manifest.extent_count"], "Extent count matches");
    h.check(
        manifest.leaf(0).map(|l| hex(l)).as_deref() == Some(v["manifest.leaf_0"]),
        "Leaf 0 matches SHA256(0x00 || extent)",
    );
    h.check(manifest.leaf(25).map(|l| hex(l)).as_deref() == Some(v["manifest.leaf_25"]), "Short tail leaf matches");
    h.check(hex(&manifest.root) == v["manifest.root"], "Merkle root of the Suite 27 test image matches");
    let three: Vec<[u8; 32]> =
        vector_bytes(&v, "merkle.three_leaves_input").chunks_exact(32).filter_map(|c| c.try_into().ok()).collect();
    h.check(hex(&merkle_root(&three)) == v["merkle.three_leaves_root"], "Odd trailing node is promoted unchanged");
    h.check(hex(&merkle_root(&[])) == v["merkle.empty_root"], "Empty tree root is SHA256(\"\")");

    let mut bitmap = ExtentBitmap::new(26);
    for i in [0, 2, 5, 25] {
        bitmap.insert(i);
    }
    h.check(hex(bitmap.as_bytes()) == v["bitmap.set_0_2_5_25"], "Bitmap is LSB-first, byte for byte");
    let record = manifest.leaf(5).map(|leaf| CommitRecord { extent_index: 5, leaf: *leaf }.encode());
    h.check(record.map(|r| hex(&r)).as_deref() == Some(v["journal.record_5"]), "44-byte commit record matches");

    let bob: Option<[u8; 32]> = vector_bytes(&v, "identity.bob_public").try_into().ok();
    h.check(
        bob.map(|k| identity::node_id(&k)).as_deref() == Some(v["identity.bob_node_id"]),
        "Node ID = base32(SHA256(Ed25519 pub)[..16])",
    );
    let pin = identity::tls_key_pin(&vector_bytes(&v, "tls.p256_x963"));
    h.check(
        pin.map(|p| hex(&p)).as_deref() == Some(v["tls.p256_pin"]),
        "mTLS pin = SHA256(X9.63 uncompressed P-256 key)",
    );
}

// ---------------------------------------------------------------------------------------------
// S2
// ---------------------------------------------------------------------------------------------

fn framing(h: &mut Harness) {
    let mut header = FrameHeader::new(FrameKind::ExtentData);
    header.extent_index = 7;
    header.first_lba = 28;
    header.sector_size = 2352;
    header.digest = [0xAB; 32];
    let frames = vec![
        Frame::signal(FrameKind::Credit, 4),
        Frame::new(header, vec![0x5A; 2352 * 2]),
        Frame::signal(FrameKind::ExtentAck, 7),
    ];
    let wire: Vec<u8> = frames.iter().flat_map(Frame::encode).collect();

    h.check(FrameDecoder::new().push(&wire).ok() == Some(frames.clone()), "Frames round-trip in one push");
    let mut one_byte = FrameDecoder::new();
    let mut reassembled = Vec::new();
    for b in &wire {
        reassembled.extend(one_byte.push(std::slice::from_ref(b)).unwrap_or_default());
    }
    h.check(reassembled == frames && one_byte.buffered_len() == 0, "1-byte fragmentation reassembles identical frames");
    let mut link = FaultyLink::new(27, 97, Faults::default());
    let mut random = FrameDecoder::new();
    let mut from_link = Vec::new();
    for piece in link.carry(&wire) {
        from_link.extend(random.push(&piece).unwrap_or_default());
    }
    h.check(from_link == frames, "Seeded random fragmentation reassembles identical frames");

    let mut hostile = FrameHeader::new(FrameKind::Control).encode();
    hostile[24..28].copy_from_slice(&[0xFF; 4]);
    h.check(
        FrameDecoder::new().push(&hostile) == Err(WireError::PayloadTooLarge(u32::MAX)),
        "A 4 GiB length is refused before allocating",
    );
    let mut bad_magic = Frame::signal(FrameKind::Credit, 1).encode();
    bad_magic[0] ^= 0xFF;
    h.check(FrameDecoder::new().push(&bad_magic) == Err(WireError::BadMagic), "Lost alignment surfaces as BadMagic");
    let mut ragged = FrameHeader::new(FrameKind::ExtentData);
    ragged.sector_size = 2048;
    h.check(
        FrameDecoder::new().push(&Frame::new(ragged, vec![1, 2, 3]).encode()) == Err(WireError::MalformedExtentFrame),
        "Extent payloads must be whole sectors",
    );
    for size in [2048u16, 2336, 2352, 2448] {
        let mut ok = FrameHeader::new(FrameKind::ExtentData);
        ok.sector_size = size;
        h.check(
            FrameDecoder::new().push(&Frame::new(ok, vec![0; usize::from(size)]).encode()).is_ok(),
            &format!("Sector size {size} accepted"),
        );
    }
    let mut odd = FrameHeader::new(FrameKind::ExtentData);
    odd.sector_size = 2340;
    h.check(FrameDecoder::new().push(&Frame::new(odd, vec![0; 2340]).encode()).is_err(), "Sector size 2340 refused");
    let mut unknown = Frame::signal(FrameKind::Control, 0).encode();
    unknown[5] = 0x7F;
    h.check(FrameDecoder::new().push(&unknown) == Err(WireError::UnknownKind(0x7F)), "Unknown kinds are refused");
    h.check(
        FrameHeader::decode(&[0; HEADER_LEN - 1]) == Err(WireError::Truncated),
        "A short header is an error, not a panic",
    );

    // Fuzz-style: 10,000 seeded random byte strings must never panic and never yield >8 MiB frames.
    let mut rng = crate::faulty_link::SplitMix64::new(0xF022);
    let mut survived = true;
    for _ in 0..10_000 {
        let len = rng.fragment_len(200);
        let mut junk: Vec<u8> = (0..len).map(|_| (rng.next_u64() & 0xFF) as u8).collect();
        if rng.next_u64().is_multiple_of(2) && junk.len() >= 6 {
            junk[..4].copy_from_slice(&0x4B52_5350u32.to_be_bytes());
            junk[4] = 1;
        }
        let result = std::panic::catch_unwind(|| FrameDecoder::new().push(&junk));
        survived &= result.is_ok_and(|r| r.map_or(true, |f| f.iter().all(|x| x.payload.len() <= 8 * 1024 * 1024)));
    }
    h.check(survived, "10,000 seeded junk inputs: no panic, no oversized frame");
}

// ---------------------------------------------------------------------------------------------
// S3
// ---------------------------------------------------------------------------------------------

fn manifest_and_journal(h: &mut Harness) {
    let image = test_image();
    let manifest = test_manifest(&image);
    h.check(
        manifest.extent_count() == 26
            && manifest.byte_range(25) == (25 * 9408..102 * 2352)
            && manifest.first_lba(5) == 20,
        "Extents are whole sectors, LBA-aligned, with a short tail",
    );
    let bd50 = TransferManifest::new(2048, 2048, 24_438_784, vec![[0; 32]; 11_934]);
    h.check(
        bd50.image_bytes() == 50_050_629_632 && bd50.byte_range(11_933).end == 50_050_629_632,
        "BD-50 offsets stay exact in u64 (would wrap a 32-bit usize on armv7)",
    );

    let mut edited = image.clone();
    edited[123_456] ^= 1;
    h.check(test_manifest(&edited).root != manifest.root, "A one-bit change anywhere changes the root");

    h.check(
        ExtentBitmap::from_wire(26, &[0xFF, 0xFF, 0xFF, 0x04]).is_none(),
        "Wire bitmap with stray high bits refused",
    );
    h.check(ExtentBitmap::from_wire(26, &[0, 0, 0]).is_none(), "Wire bitmap of the wrong length refused");

    let mut journal = Vec::new();
    for i in [0usize, 2, 5] {
        if let Some(leaf) = manifest.leaf(i) {
            journal.extend_from_slice(&CommitRecord { extent_index: i as u32, leaf: *leaf }.encode());
        }
    }
    let mut torn = journal.clone();
    if let Some(leaf) = manifest.leaf(7) {
        torn.extend_from_slice(&CommitRecord { extent_index: 7, leaf: *leaf }.encode()[..20]);
    }
    let replayed = CommitRecord::replay(&torn, &manifest);
    h.check(
        replayed.committed_count() == 3 && replayed.contains(5) && !replayed.contains(7),
        "Torn final record is ignored",
    );
    let mut corrupt = journal.clone();
    corrupt[44 + 40] ^= 0xFF;
    let stopped = CommitRecord::replay(&corrupt, &manifest);
    h.check(stopped.committed_count() == 1 && stopped.contains(0), "Replay stops at the first corrupt record");
    let foreign = CommitRecord { extent_index: 3, leaf: [9; 32] }.encode();
    h.check(
        !CommitRecord::replay(&foreign, &manifest).contains(3),
        "Stale-journal records never mark an extent committed",
    );

    let offer = ManifestOffer::encode(&manifest);
    h.check(
        offer.as_ref().and_then(|f| ManifestOffer::decode(f).ok()).as_ref() == Some(&manifest),
        "Manifest offer round-trips",
    );
    if let Some(mut forged) = offer.clone() {
        forged.payload[3] ^= 1;
        h.check(
            ManifestOffer::decode(&forged) == Err(ManifestOfferError::RootMismatch),
            "A tampered leaf fails the root check",
        );
    }
    if let Some(mut short) = offer {
        short.payload.truncate(25 * 32);
        h.check(
            matches!(
                ManifestOffer::decode(&short),
                Err(ManifestOfferError::LeafCountMismatch { expected: 26, got: 25 })
            ),
            "A missing leaf is refused before anything is trusted",
        );
    }
}

// ---------------------------------------------------------------------------------------------
// S4
// ---------------------------------------------------------------------------------------------

#[derive(Debug)]
pub struct LoopbackRun {
    pub sender: UploadSender,
    pub receiver: StagingReceiver,
    pub staged: Vec<u8>,
    pub reconnects: usize,
    pub resume_lbas: Vec<u64>,
}

/// Pumps the real sender and receiver through the faulty link. A broken stream, a dropped
/// connection or a round without progress (an ack timeout in production) all lead to the same
/// recovery: reconnect and resume from the node's durable bitmap.
pub fn run_loopback(
    image: &[u8],
    sender_manifest: &TransferManifest,
    receiver_manifest: &TransferManifest,
    faults: Faults,
    restart_receiver: bool,
) -> LoopbackRun {
    let mut sender = UploadSender::new(sender_manifest.clone(), 3);
    let mut receiver =
        StagingReceiver::new(receiver_manifest.clone(), ExtentBitmap::new(receiver_manifest.extent_count()), 4);
    let mut staged = vec![0u8; usize::try_from(receiver_manifest.image_bytes()).unwrap_or(0)];
    let mut journal = Vec::new();
    let mut link = FaultyLink::new(0x4B52_5350, 1_500, faults);
    let (mut reconnects, mut resume_lbas, mut awaiting_resume) = (0, Vec::new(), false);
    let mut to_node = sender.connect();

    for _ in 0..400 {
        if matches!(sender.phase(), SenderPhase::Complete | SenderPhase::ManifestMismatch) {
            break;
        }
        if awaiting_resume && let Some(first) = to_node.iter().find(|f| f.header.kind == FrameKind::ExtentData) {
            resume_lbas.push(first.header.first_lba);
            awaiting_resume = false;
        }
        let mut to_workstation = Vec::new();
        let mut broken = false;
        let wire: Vec<u8> = to_node.iter().flat_map(Frame::encode).collect();
        for piece in link.carry(&wire) {
            let persist = |index: usize, bytes: &[u8]| {
                let range = receiver_manifest.byte_range(index);
                let (start, end) = (usize::try_from(range.start).unwrap_or(0), usize::try_from(range.end).unwrap_or(0));
                match (staged.get_mut(start..end), receiver_manifest.leaf(index)) {
                    (Some(dst), Some(leaf)) => {
                        dst.copy_from_slice(bytes);
                        journal.extend_from_slice(&CommitRecord { extent_index: index as u32, leaf: *leaf }.encode());
                        true
                    }
                    _ => false,
                }
            };
            match receiver.receive(&piece, persist) {
                Ok(replies) => to_workstation.extend(replies),
                Err(_) => {
                    broken = true;
                    break;
                }
            }
        }
        to_node = Vec::new();
        if !broken && link.connected {
            let back: Vec<u8> = to_workstation.iter().flat_map(Frame::encode).collect();
            for piece in link.carry_back(&back) {
                let source = |i: usize| {
                    let r = sender_manifest.byte_range(i);
                    image
                        .get(usize::try_from(r.start).unwrap_or(0)..usize::try_from(r.end).unwrap_or(0))
                        .unwrap_or(&[])
                        .to_vec()
                };
                to_node.extend(sender.receive(&piece, source).unwrap_or_default());
            }
            if !to_node.is_empty() || matches!(sender.phase(), SenderPhase::Complete | SenderPhase::ManifestMismatch) {
                continue;
            }
        }
        sender.disconnected();
        if restart_receiver {
            let replayed = CommitRecord::replay(&journal, receiver_manifest);
            receiver = StagingReceiver::new(receiver_manifest.clone(), replayed, 4);
        } else {
            receiver.connection_reset();
        }
        link.reconnect();
        reconnects += 1;
        awaiting_resume = true;
        to_node = sender.connect();
    }
    LoopbackRun { sender, receiver, staged, reconnects, resume_lbas }
}

fn loopback_faults(h: &mut Harness) {
    let image = test_image();
    let manifest = test_manifest(&image);
    let frame = HEADER_LEN as u64 + manifest.extent_bytes();
    let query = HEADER_LEN as u64 + 32;

    let clean = run_loopback(&image, &manifest, &manifest, Faults::default(), false);
    h.check(
        clean.sender.phase() == SenderPhase::Complete
            && clean.staged == image
            && clean.reconnects == 0
            && clean.sender.extents_sent == 26
            && clean.sender.peak_in_flight <= 3,
        "Clean transfer: byte-identical image, each extent once, never more than 3 in flight",
    );
    let bd25 = TransferManifest::new(2048, 2048, 12_219_392, vec![[0; 32]; 5967]);
    let window = UploadSender::max_in_flight_for_budget(32 * 1024 * 1024, &bd25);
    h.check(
        window == 7 && (window as u64 + 1) * bd25.extent_bytes() <= 32 * 1024 * 1024,
        "BD-25 in-flight + read-ahead fits 32 MiB",
    );

    let cut = Faults { disconnect_at_byte: Some(query + 5 * frame + 3_000), ..Faults::default() };
    let resumed = run_loopback(&image, &manifest, &manifest, cut.clone(), false);
    h.check(
        resumed.sender.phase() == SenderPhase::Complete && resumed.staged == image && resumed.reconnects == 1,
        "Cable pull mid-extent: one reconnect, identical image",
    );
    h.check(
        resumed.resume_lbas == [20] && resumed.sender.extents_sent == 27,
        "Resume at exactly LBA 20; extents 0-4 never resent (same as Swift)",
    );

    let restarted = run_loopback(&image, &manifest, &manifest, cut, true);
    h.check(
        restarted.sender.phase() == SenderPhase::Complete && restarted.staged == image && restarted.resume_lbas == [20],
        "Node crash: journal replay resumes at the same LBA",
    );

    let flipped = run_loopback(
        &image,
        &manifest,
        &manifest,
        Faults { flip_bit_at_byte: Some(query + 64 + 500), ..Faults::default() },
        false,
    );
    h.check(
        flipped.sender.phase() == SenderPhase::Complete
            && flipped.staged == image
            && flipped.receiver.rejected_extents() == 1
            && flipped.sender.retransmissions == 1
            && flipped.reconnects == 0,
        "Flipped bit: rejected by SHA-256, retransmitted once, never staged",
    );
    let gap = query + 64 + 100;
    let dropped = run_loopback(
        &image,
        &manifest,
        &manifest,
        Faults { drop_bytes: Some(gap..gap + 10), ..Faults::default() },
        false,
    );
    h.check(
        dropped.sender.phase() == SenderPhase::Complete && dropped.staged == image && dropped.reconnects == 1,
        "Missing bytes: framing desyncs, reconnect, identical image",
    );

    let mut other = image.clone();
    other[0] ^= 0xFF;
    let refused = run_loopback(&image, &manifest, &test_manifest(&other), Faults::default(), false);
    h.check(
        refused.sender.phase() == SenderPhase::ManifestMismatch && refused.sender.extents_sent == 0,
        "Different manifest: refused before any extent",
    );

    // A node that acks an extent it was never sent must not make the sender skip it.
    let mut wary = UploadSender::new(manifest.clone(), 3);
    let _ = wary.connect();
    let mut reply =
        Frame::new(FrameHeader::new(FrameKind::BitmapReply), ExtentBitmap::new(26).as_bytes().to_vec()).encode();
    reply.extend(Frame::signal(FrameKind::ExtentAck, 20).encode());
    let _ = wary.receive(&reply, |i| image.get(i * 9408..((i + 1) * 9408).min(image.len())).unwrap_or(&[]).to_vec());
    h.check(!wary.acknowledged().contains(20), "A stray ack for an extent never sent is ignored");

    let again = run_loopback(
        &image,
        &manifest,
        &manifest,
        Faults { disconnect_at_byte: Some(query + 5 * frame + 3_000), ..Faults::default() },
        false,
    );
    h.check(
        again.resume_lbas == resumed.resume_lbas && again.sender.extents_sent == resumed.sender.extents_sent,
        "Same seed, same faults, same run (determinism)",
    );
}

// ---------------------------------------------------------------------------------------------
