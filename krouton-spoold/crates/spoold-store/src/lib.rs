#![forbid(unsafe_code)]

// MARK: - Durable Extent Journal Replay, Torn-Tail Truncation & Rolling-Window Watermark

use std::sync::atomic::{AtomicU64, Ordering};
use spoold_proto::manifest::{COMMIT_RECORD_LEN, CommitRecord, ExtentBitmap, TransferManifest};

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct ReplayedJournal {
    pub bitmap: ExtentBitmap,
    pub valid_byte_len: usize,
    pub contiguous_committed_sectors: u64,
}

/// Replays 44-byte `CommitRecord` entries, truncating any torn tail record left by a power cut
/// and computing the contiguous committed LBA watermark for rolling-window burns.
#[must_use]
pub fn replay_and_measure_journal(
    manifest: &TransferManifest,
    journal_bytes: &[u8],
) -> ReplayedJournal {
    let bitmap = CommitRecord::replay(journal_bytes, manifest);
    let valid_byte_len = bitmap.committed_count().saturating_mul(COMMIT_RECORD_LEN);

    let sector_bytes = u64::from(manifest.sector_size.max(1));
    let mut contiguous_sectors = 0u64;
    for idx in 0..manifest.extent_count() {
        if bitmap.contains(idx) {
            let range = manifest.byte_range(idx);
            contiguous_sectors += (range.end.saturating_sub(range.start)) / sector_bytes;
        } else {
            break;
        }
    }

    ReplayedJournal {
        bitmap,
        valid_byte_len,
        contiguous_committed_sectors: contiguous_sectors,
    }
}

/// Lock-free contiguous LBA watermark shared between the network extent writer and optical drive reader.
#[derive(Debug, Default)]
pub struct RollingCommitWatermark {
    committed_sectors: AtomicU64,
}

impl RollingCommitWatermark {
    #[must_use]
    pub const fn new() -> Self {
        Self { committed_sectors: AtomicU64::new(0) }
    }

    pub fn advance_to(&self, contiguous_sectors: u64) {
        self.committed_sectors.fetch_max(contiguous_sectors, Ordering::Release);
    }

    #[must_use]
    pub fn load(&self) -> u64 {
        self.committed_sectors.load(Ordering::Acquire)
    }
}

/// Checks if a Linux sysfs block device path resides on a Raspberry Pi microSD card (`mmcblk*`)
/// so large DVD/BD spool jobs can require an external USB SSD instead of wearing out the boot SD card.
#[must_use]
pub fn is_raspberry_pi_sdcard_device(device_name: &str) -> bool {
    let base = device_name.rsplit('/').next().unwrap_or(device_name);
    base.starts_with("mmcblk")
}
