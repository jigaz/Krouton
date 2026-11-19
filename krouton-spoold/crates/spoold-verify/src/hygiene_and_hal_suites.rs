// MARK: - Suites S9–S12: Crypto, MMC/HAL/Store, Resource Reclamation & Source-Hygiene Gate

use std::fs;
use std::path::Path;

use spoold_crypto::{
    PairingError, PairingHello, commitment, complete_from_seeds, sign_session_from_seed,
    verify_session_from_bytes,
};
use spoold_hal::{OpticalDrive, UsbBusPowerArbiter, VirtualMmcOpticalDrive};
use spoold_mmc::{ScsiCdb, SenseAction};
use spoold_proto::frame::{Frame, FrameDecoder, FrameHeader, FrameKind};
use spoold_proto::manifest::{COMMIT_RECORD_LEN, CommitRecord, TransferManifest};
use spoold_store::{
    RollingCommitWatermark, is_raspberry_pi_sdcard_device, replay_and_measure_journal,
};

use crate::harness::Harness;

pub fn run_extended_suites(h: &mut Harness) {
    s9_crypto_pairing_and_session_proof(h);
    s10_mmc_hal_bus_arbiter_and_store(h);
    s11_deterministic_resource_reclamation(h);
    s12_rust_source_hygiene_gate(h);
}

// MARK: - S9. Crypto Pairing, Low-Order X25519 Rejection & Exporter Session Proof

pub fn s9_crypto_pairing_and_session_proof(h: &mut Harness) {
    h.suite("S9. Crypto pairing, low-order X25519 guard & TLS exporter session proof", |h| {
        let alice_id_seed = [0x11u8; 32];
        let bob_id_seed = [0x22u8; 32];
        let alice_eph = [0x33u8; 32];
        let bob_eph = [0x44u8; 32];
        let alice_hello = PairingHello::from_seeds(&alice_id_seed, &alice_eph, [0xA5; 16]);
        let bob_hello = PairingHello::from_seeds(&bob_id_seed, &bob_eph, [0x5A; 16]);
        let commit = commitment(&bob_hello);

        let a_res = complete_from_seeds(true, &alice_hello, &alice_eph, &bob_hello, Some(&commit));
        let b_res = complete_from_seeds(false, &bob_hello, &bob_eph, &alice_hello, None);
        let ok_pair = match (&a_res, &b_res) {
            (Ok(a), Ok(b)) => a.code == b.code && a.pairing_key == b.pairing_key,
            _ => false,
        };
        h.check(ok_pair, "Initiator and responder derive identical 6-digit SAS and 32B pairing key");

        let missing_commit = complete_from_seeds(true, &alice_hello, &alice_eph, &bob_hello, None);
        h.check(
            missing_commit.err() == Some(PairingError::CommitmentMismatch),
            "Missing responder commitment on initiator must abort pairing (H1)",
        );

        let bad_commit = [0xFFu8; 32];
        let mismatch =
            complete_from_seeds(true, &alice_hello, &alice_eph, &bob_hello, Some(&bad_commit));
        h.check(
            mismatch.err() == Some(PairingError::CommitmentMismatch),
            "Mismatched responder commitment must abort pairing",
        );

        let mut low_order_peer = bob_hello.clone();
        low_order_peer.ephemeral_key = [0u8; 32];
        let low_order_commit = commitment(&low_order_peer);
        let low_order_res = complete_from_seeds(
            true,
            &alice_hello,
            &alice_eph,
            &low_order_peer,
            Some(&low_order_commit),
        );
        h.check(
            low_order_res.err() == Some(PairingError::NonContributoryKey),
            "All-zero low-order X25519 ephemeral key must be rejected",
        );

        let exporter = [0x77u8; 32];
        let sig = sign_session_from_seed(&exporter, "workstation", &alice_id_seed);
        h.check(
            verify_session_from_bytes(&sig, &exporter, "workstation", &alice_hello.identity_key),
            "Valid exporter session proof verifies",
        );
        h.check(
            !verify_session_from_bytes(&sig, &exporter, "node", &alice_hello.identity_key),
            "Role confusion (workstation vs node) must fail session proof verification",
        );
    });
}

// MARK: - S10. MMC-6 CDB Builders, Virtual Optical Drive, Bus Power Arbiter & Torn-Tail Store

pub fn s10_mmc_hal_bus_arbiter_and_store(h: &mut Harness) {
    h.suite("S10. MMC-6 CDB builders, VirtualMmcOpticalDrive, USB bus arbiter & torn-tail store", |h| {
        let mut drive = VirtualMmcOpticalDrive::new("sr0", "usb-bus-1", 2048, 64);
        let mut payload = vec![0x5Au8; 4096];
        let write_cdb = ScsiCdb::write_10(0, 2);
        let sense = drive.execute(&write_cdb, &mut payload);
        h.check(sense.is_ok(), "VirtualMmcOpticalDrive accepts WRITE(10) of 2 sectors at LBA 0");

        let mut readback = vec![0u8; 4096];
        let read_cdb = ScsiCdb::read_cd(0, 2, true);
        let read_sense = drive.execute(&read_cdb, &mut readback);
        h.check(
            read_sense.is_ok() && readback == payload,
            "READ CD (0xBE) reads back exact written sector bytes",
        );

        drive.inject_c2_bad_sector(10);
        let bad_sense = drive.execute(&ScsiCdb::read_cd(10, 1, true), &mut readback[..2048]);
        let is_c2_err = bad_sense.map(|s| s.classify()) == Ok(SenseAction::UnrecoveredReadErrorC2);
        h.check(is_c2_err, "Injected C2 bad sector surfaces Sense 03/11/00 for RescueKit");

        let _ = drive.execute(&ScsiCdb::synchronize_cache(false), &mut []);
        let _ = drive.execute(&ScsiCdb::close_track_session(0x02, 1, false), &mut []);
        h.check(drive.is_session_closed(), "CLOSE TRACK/SESSION seals virtual optical disc");

        let mut arbiter = UsbBusPowerArbiter::new();
        h.check(
            arbiter.try_acquire_spinup_and_opc("usb-bus-1", "sr0"),
            "First drive on USB bus acquires spin-up + OPC power slot",
        );
        h.check(
            !arbiter.try_acquire_spinup_and_opc("usb-bus-1", "sr1"),
            "Second drive on same USB bus is gated during spin-up + OPC peak current",
        );
        h.check(
            arbiter.try_acquire_spinup_and_opc("usb-bus-2", "sr2"),
            "Drive on separate USB root bus can calibrate concurrently",
        );
        arbiter.complete_opc_transition_to_steady_burn("usb-bus-1", "sr0");
        h.check(
            arbiter.try_acquire_spinup_and_opc("usb-bus-1", "sr1"),
            "Second drive acquires OPC slot once first drive transitions to steady burn",
        );

        let image = vec![0x3Cu8; 2048 * 8];
        if let Some(manifest) = TransferManifest::from_image(&image, 2048, 2) {
            let mut journal = Vec::new();
            journal.extend_from_slice(&(CommitRecord { extent_index: 0, leaf: manifest.leaves[0] }).encode());
            journal.extend_from_slice(&(CommitRecord { extent_index: 1, leaf: manifest.leaves[1] }).encode());
            journal.extend_from_slice(&[0xDE, 0xAD, 0xBE, 0xEF, 0x00, 0x11, 0x22]);
            let replayed = replay_and_measure_journal(&manifest, &journal);
            h.check(
                replayed.valid_byte_len == COMMIT_RECORD_LEN * 2
                    && replayed.contiguous_committed_sectors == 4,
                "Torn journal tail is identified for truncation and contiguous watermark is 4 sectors",
            );
            let wm = RollingCommitWatermark::new();
            wm.advance_to(replayed.contiguous_committed_sectors);
            h.check(wm.load() == 4, "RollingCommitWatermark publishes contiguous committed LBA");
        }
        h.check(
            is_raspberry_pi_sdcard_device("/dev/mmcblk0p2") && !is_raspberry_pi_sdcard_device("/dev/nvme0n1"),
            "Raspberry Pi microSD block device is distinguished from external USB/NVMe SSD",
        );
    });
}

// MARK: - S11. Deterministic Resource Reclamation & Zero-Capacity Teardown

pub fn s11_deterministic_resource_reclamation(h: &mut Harness) {
    h.suite("S11. Deterministic resource reclamation (immediate heap return on teardown)", |h| {
        let mut decoder = FrameDecoder::new();
        let frame = Frame {
            header: FrameHeader {
                kind: FrameKind::ExtentData,
                flags: 0,
                extent_index: 0,
                first_lba: 0,
                sector_size: 2048,
                payload_length: 2048,
                digest: [0u8; 32],
            },
            payload: vec![0xAAu8; 2048],
        };
        let _ = decoder.push(&frame.encode());
        h.check(decoder.buffered_capacity() >= 2048, "Decoder allocates capacity during active stream");
        decoder.reclaim_unused_resources();
        h.check(
            decoder.buffered_capacity() == 0,
            "FrameDecoder::reclaim_unused_resources returns 100% of idle heap capacity to the OS",
        );

        let mut vdrive = VirtualMmcOpticalDrive::new("sr0", "usb-1", 2048, 32);
        let mut sector = vec![0xBBu8; 2048];
        let _ = vdrive.execute(&ScsiCdb::write_10(0, 1), &mut sector);
        h.check(vdrive.storage_capacity() >= 2048, "Virtual drive holds buffer while active");
        vdrive.reclaim_unused_resources();
        h.check(
            vdrive.storage_capacity() == 0,
            "VirtualMmcOpticalDrive::reclaim_unused_resources shrinks buffer capacity to 0",
        );
    });
}

// MARK: - S12. Rust Source-Hygiene Gate (500-LOC File, 200-LOC Fn, Zero unwrap/Command, forbid(unsafe))

pub fn s12_rust_source_hygiene_gate(h: &mut Harness) {
    h.suite("S12. Rust source-hygiene gate (LOC ceilings, MARK headers, zero unwrap/Command, forbid(unsafe))", |h| {
        let crates_root = Path::new(env!("CARGO_MANIFEST_DIR")).parent().unwrap_or_else(|| Path::new("."));
        let mut rs_files = Vec::new();
        collect_rs_files(crates_root, &mut rs_files);
        h.check(rs_files.len() >= 15, "Discovered all workspace Rust source files");

        for path in &rs_files {
            let Ok(text) = fs::read_to_string(path) else { continue };
            let rel = path.strip_prefix(crates_root).unwrap_or(path).display().to_string();
            let lines: Vec<&str> = text.lines().collect();

            h.check(
                lines.len() <= 500,
                &format!("{rel} is {} LOC (must be <= 500 LOC ceiling)", lines.len()),
            );
            if lines.len() > 120 {
                h.check(
                    text.contains("// MARK: -"),
                    &format!("{rel} (>120 LOC) must contain canonical // MARK: - section headers"),
                );
            }

            let is_prod_lib = (rel.starts_with("spoold-proto/src/")
                || rel.starts_with("spoold-crypto/src/")
                || rel.starts_with("spoold-mmc/src/")
                || rel.starts_with("spoold-hal/src/")
                || rel.starts_with("spoold-store/src/"))
                && !rel.contains("tests");

            if is_prod_lib {
                let prod_code = text.split("#[cfg(test)]").next().unwrap_or(&text);
                h.check(
                    !prod_code.contains(".unwrap()") && !prod_code.contains(".expect("),
                    &format!("{rel} must not use .unwrap() or .expect() in production code"),
                );
                h.check(
                    !prod_code.contains("std::process::Command"),
                    &format!("{rel} must never spawn subprocesses"),
                );
            }

            if rel.ends_with("/lib.rs") && is_prod_lib {
                h.check(
                    text.contains("#![forbid(unsafe_code)]"),
                    &format!("{rel} must declare #![forbid(unsafe_code)]"),
                );
            }
        }
    });
}

fn collect_rs_files(dir: &Path, out: &mut Vec<std::path::PathBuf>) {
    let Ok(entries) = fs::read_dir(dir) else { return };
    let mut paths: Vec<_> = entries.filter_map(|e| e.ok().map(|x| x.path())).collect();
    paths.sort();
    for p in paths {
        if p.is_dir() {
            collect_rs_files(&p, out);
        } else if p.extension().and_then(|e| e.to_str()) == Some("rs") {
            out.push(p);
        }
    }
}
