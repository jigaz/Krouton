//! The resumable extent pipeline end to end: the app-side sender and the server-side receiver,
//! connected through a deterministic faulty link (fragmentation, a dropped connection, a flipped
//! bit, missing bytes). The image must arrive complete and exact every time.
#![allow(clippy::unwrap_used, clippy::expect_used, clippy::indexing_slicing, clippy::cast_possible_truncation)]

mod faulty_link;

use faulty_link::{Faults, FaultyLink};
use krsp::frame::Frame;
use krsp::manifest::{ExtentBitmap, TransferManifest};
use krsp::pipeline::{SenderPhase, StagingReceiver, UploadSender};

fn test_image() -> Vec<u8> {
    (0..102usize * 2352).map(|i| (i.wrapping_mul(31).wrapping_add(i >> 9) & 0xFF) as u8).collect()
}

fn encode(frames: &[Frame]) -> Vec<u8> {
    frames.iter().flat_map(Frame::encode).collect()
}

/// Runs the upload to completion (or `max_rounds`), reconnecting after every drop.
fn transfer(seed: u64, faults: Faults) -> (Vec<u8>, SenderPhase, u32) {
    let image = test_image();
    let manifest = TransferManifest::from_image(&image, 2352, 4).unwrap();
    let mut staged = vec![0u8; image.len()];
    let mut receiver = StagingReceiver::new(manifest.clone(), ExtentBitmap::new(manifest.extent_count()), 4);
    let mut sender = UploadSender::new(manifest.clone(), 3);
    let mut link = FaultyLink::new(seed, 700, faults);
    let mut reconnects = 0;
    let mut outbound = encode(&sender.connect());

    for _ in 0..10_000 {
        if matches!(sender.phase(), SenderPhase::Complete) {
            break;
        }
        if !link.connected {
            reconnects += 1;
            link.reconnect();
            receiver.connection_reset();
            sender.disconnected();
            outbound = encode(&sender.connect());
        }
        let mut replies = Vec::new();
        for piece in link.carry(&std::mem::take(&mut outbound)) {
            let persist = |index: usize, bytes: &[u8]| {
                let range = manifest.byte_range(index);
                staged[range.start as usize..range.end as usize].copy_from_slice(bytes);
                true
            };
            match receiver.receive(&piece, persist) {
                Ok(frames) => replies.extend(frames),
                // A corrupted header (bad magic) is unrecoverable on this connection: drop it.
                Err(_) => link.connected = false,
            }
        }
        if !link.connected {
            continue;
        }
        let image_ref = &image;
        for piece in link.carry_back(&encode(&replies)) {
            let frames = sender
                .receive(&piece, |i| {
                    let r = manifest.byte_range(i);
                    image_ref[r.start as usize..r.end as usize].to_vec()
                })
                .unwrap();
            outbound.extend(encode(&frames));
        }
        if outbound.is_empty() && !matches!(sender.phase(), SenderPhase::Complete) {
            // Stalled (e.g. bytes vanished mid-frame): TCP would surface this as a timeout.
            link.connected = false;
        }
    }
    (staged, sender.phase(), reconnects)
}

#[test]
fn clean_link_delivers_exact_image() {
    let (staged, phase, reconnects) = transfer(1, Faults::default());
    assert_eq!(phase, SenderPhase::Complete);
    assert_eq!(reconnects, 0);
    assert_eq!(staged, test_image());
}

#[test]
fn survives_disconnect_bitflip_and_loss_across_seeds() {
    for seed in 0..24 {
        let faults = Faults {
            disconnect_at_byte: Some(40_000 + seed * 1_000),
            flip_bit_at_byte: Some(90_000 + seed * 37),
            drop_bytes: Some(150_000 + seed * 11..150_100 + seed * 11),
        };
        let (staged, phase, reconnects) = transfer(seed, faults);
        assert_eq!(phase, SenderPhase::Complete, "seed {seed}");
        assert!(reconnects >= 1, "seed {seed}");
        assert_eq!(staged, test_image(), "seed {seed}");
    }
}

#[test]
fn resume_skips_committed_extents() {
    let image = test_image();
    let manifest = TransferManifest::from_image(&image, 2352, 4).unwrap();
    let mut committed = ExtentBitmap::new(manifest.extent_count());
    for i in 0..20 {
        committed.insert(i);
    }
    let mut receiver = StagingReceiver::new(manifest.clone(), committed, 8);
    let mut sender = UploadSender::new(manifest.clone(), 8);
    let mut sent = Vec::new();
    let mut outbound = encode(&sender.connect());
    while !matches!(sender.phase(), SenderPhase::Complete) {
        let replies = receiver.receive(&std::mem::take(&mut outbound), |i, _| {
            sent.push(i);
            true
        });
        let frames = sender
            .receive(&encode(&replies.unwrap()), |i| {
                let r = manifest.byte_range(i);
                image[r.start as usize..r.end as usize].to_vec()
            })
            .unwrap();
        outbound = encode(&frames);
    }
    sent.sort_unstable();
    assert_eq!(sent, (20..manifest.extent_count()).collect::<Vec<_>>());
}
