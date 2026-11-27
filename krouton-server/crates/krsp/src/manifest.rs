// MARK: - manifest.rs

//! Content-addressed transfer manifest, committed-extent bitmap and the 44-byte commit journal.
//! Byte-for-byte identical to `SpoolTransferManifest.swift`.
//!
//! All byte offsets are `u64`: on armv7 (`usize` = 32 bits) a 50 GB Blu-ray offset would
//! silently wrap if it ever passed through `usize`.

use crate::frame::{Frame, FrameHeader, FrameKind, MAX_PAYLOAD, SECTOR_SIZES};
use crate::sha256::Sha256;
use std::ops::Range;

pub const DEFAULT_SECTORS_PER_EXTENT: u32 = 2048;

/// RFC 6962-style leaf hash: `SHA256(0x00 || extent)`.
#[must_use]
pub fn leaf_digest(extent: &[u8]) -> [u8; 32] {
    Sha256::digest(&[&[0x00], extent])
}

/// RFC 6962-style tree with an odd trailing node promoted unchanged, as in Swift.
#[must_use]
pub fn merkle_root(leaves: &[[u8; 32]]) -> [u8; 32] {
    if leaves.is_empty() {
        return Sha256::digest(&[]);
    }
    let mut level = leaves.to_vec();
    while level.len() > 1 {
        level = level
            .chunks(2)
            .map(|pair| match pair {
                [left, right] => Sha256::digest(&[&[0x01], left, right]),
                [only] => *only,
                _ => [0; 32],
            })
            .collect();
    }
    level.first().copied().unwrap_or([0; 32])
}

#[derive(Clone, Debug, PartialEq, Eq)]
pub struct TransferManifest {
    pub sector_size: u32,
    pub sectors_per_extent: u32,
    pub total_sectors: u64,
    pub leaves: Vec<[u8; 32]>,
    pub root: [u8; 32],
}

impl TransferManifest {
    #[must_use]
    pub fn new(sector_size: u32, sectors_per_extent: u32, total_sectors: u64, leaves: Vec<[u8; 32]>) -> Self {
        let root = merkle_root(&leaves);
        Self { sector_size, sectors_per_extent, total_sectors, leaves, root }
    }

    /// Builds a manifest for an in-memory image (tests). The daemon hashes files extent by extent.
    #[must_use]
    pub fn from_image(image: &[u8], sector_size: u32, sectors_per_extent: u32) -> Option<Self> {
        let sector = usize::try_from(sector_size).ok()?;
        if sector == 0 || sectors_per_extent == 0 || image.is_empty() || !image.len().is_multiple_of(sector) {
            return None;
        }
        let extent = sector.checked_mul(usize::try_from(sectors_per_extent).ok()?)?;
        let leaves = image.chunks(extent).map(leaf_digest).collect();
        Some(Self::new(sector_size, sectors_per_extent, (image.len() / sector) as u64, leaves))
    }

    #[must_use]
    pub fn extent_count(&self) -> usize {
        self.leaves.len()
    }

    #[must_use]
    pub fn expected_extent_count(&self) -> u64 {
        self.total_sectors.div_ceil(u64::from(self.sectors_per_extent.max(1)))
    }

    #[must_use]
    pub fn extent_bytes(&self) -> u64 {
        u64::from(self.sector_size) * u64::from(self.sectors_per_extent)
    }

    #[must_use]
    pub fn image_bytes(&self) -> u64 {
        self.total_sectors * u64::from(self.sector_size)
    }

    #[must_use]
    pub fn byte_range(&self, extent: usize) -> Range<u64> {
        let start = (extent as u64).saturating_mul(self.extent_bytes());
        start.min(self.image_bytes())..start.saturating_add(self.extent_bytes()).min(self.image_bytes())
    }

    #[must_use]
    pub fn first_lba(&self, extent: usize) -> u64 {
        (extent as u64).saturating_mul(u64::from(self.sectors_per_extent))
    }

    #[must_use]
    pub fn leaf(&self, extent: usize) -> Option<&[u8; 32]> {
        self.leaves.get(extent)
    }
}

// ---------------------------------------------------------------------------------------------
// Manifest offer (contract v1.1 proposal)
// ---------------------------------------------------------------------------------------------

/// How the node learns the leaf digests. KRSP v1 never sends them: `BitmapQuery` carries only the
/// root, so a v1 node cannot verify a single extent. Proposed encoding (kind 10):
/// `extent_index` = sectors per extent, `first_lba` = total sectors, `sector_size` = sector size,
/// `digest` = Merkle root, payload = the leaves concatenated (≤ 262,144 leaves = 1 TiB at 4 MiB).
#[derive(Debug)]
pub struct ManifestOffer;

#[derive(Clone, Debug, PartialEq, Eq)]
pub enum ManifestOfferError {
    WrongKind,
    UnsupportedSectorSize(u16),
    BadGeometry,
    LeafCountMismatch { expected: u64, got: u64 },
    RootMismatch,
}

impl ManifestOffer {
    #[must_use]
    pub fn encode(manifest: &TransferManifest) -> Option<Frame> {
        let mut header = FrameHeader::new(FrameKind::ManifestOffer);
        header.extent_index = manifest.sectors_per_extent;
        header.first_lba = manifest.total_sectors;
        header.sector_size = u16::try_from(manifest.sector_size).ok()?;
        header.digest = manifest.root;
        let payload: Vec<u8> = manifest.leaves.iter().flatten().copied().collect();
        (payload.len() <= MAX_PAYLOAD as usize).then(|| Frame::new(header, payload))
    }

    /// Rebuilds and re-derives everything; nothing in the frame is trusted until the root matches.
    pub fn decode(frame: &Frame) -> Result<TransferManifest, ManifestOfferError> {
        let h = &frame.header;
        if h.kind != FrameKind::ManifestOffer {
            return Err(ManifestOfferError::WrongKind);
        }
        if !SECTOR_SIZES.contains(&h.sector_size) {
            return Err(ManifestOfferError::UnsupportedSectorSize(h.sector_size));
        }
        if h.extent_index == 0 || h.first_lba == 0 || !frame.payload.len().is_multiple_of(32) {
            return Err(ManifestOfferError::BadGeometry);
        }
        let leaves: Vec<[u8; 32]> = frame.payload.as_chunks::<32>().0.to_vec();
        let manifest = TransferManifest::new(u32::from(h.sector_size), h.extent_index, h.first_lba, leaves);
        let expected = manifest.expected_extent_count();
        if manifest.extent_count() as u64 != expected {
            return Err(ManifestOfferError::LeafCountMismatch { expected, got: manifest.extent_count() as u64 });
        }
        if manifest.root != h.digest {
            return Err(ManifestOfferError::RootMismatch);
        }
        Ok(manifest)
    }
}

// ---------------------------------------------------------------------------------------------
// Committed-extent bitmap
// ---------------------------------------------------------------------------------------------

/// One bit per extent, LSB-first: `bytes[i / 8] & (1 << (i % 8))`.
#[derive(Clone, Debug, PartialEq, Eq)]
pub struct ExtentBitmap {
    count: usize,
    bytes: Vec<u8>,
}

impl ExtentBitmap {
    #[must_use]
    pub fn new(count: usize) -> Self {
        Self { count, bytes: vec![0; count.div_ceil(8)] }
    }

    /// Accepts a wire bitmap only if its length is exact and no bit is set past `count`.
    #[must_use]
    pub fn from_wire(count: usize, bytes: &[u8]) -> Option<Self> {
        if bytes.len() != count.div_ceil(8) {
            return None;
        }
        let spare = count % 8;
        if spare != 0 {
            let valid: u8 = (1u8 << spare) - 1;
            if bytes.last().is_some_and(|last| last & !valid != 0) {
                return None;
            }
        }
        Some(Self { count, bytes: bytes.to_vec() })
    }

    #[must_use]
    pub fn count(&self) -> usize {
        self.count
    }

    #[must_use]
    pub fn as_bytes(&self) -> &[u8] {
        &self.bytes
    }

    #[must_use]
    pub fn contains(&self, index: usize) -> bool {
        index < self.count && self.bytes.get(index / 8).is_some_and(|b| b & (1 << (index % 8)) != 0)
    }

    pub fn insert(&mut self, index: usize) {
        if index < self.count
            && let Some(byte) = self.bytes.get_mut(index / 8)
        {
            *byte |= 1 << (index % 8);
        }
    }

    #[must_use]
    pub fn committed_count(&self) -> usize {
        self.bytes.iter().map(|b| b.count_ones() as usize).sum()
    }

    #[must_use]
    pub fn is_complete(&self) -> bool {
        self.committed_count() == self.count
    }

    #[must_use]
    pub fn missing(&self) -> Vec<usize> {
        (0..self.count).filter(|i| !self.contains(*i)).collect()
    }
}

// ---------------------------------------------------------------------------------------------
// 44-byte commit journal
// ---------------------------------------------------------------------------------------------

pub const COMMIT_RECORD_LEN: usize = 44;

/// `extent_index u32 BE || leaf digest [32] || SHA256(first 36 bytes)[..8]`.
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub struct CommitRecord {
    pub extent_index: u32,
    pub leaf: [u8; 32],
}

impl CommitRecord {
    #[must_use]
    pub fn encode(&self) -> [u8; COMMIT_RECORD_LEN] {
        let mut out = [0u8; COMMIT_RECORD_LEN];
        let (body, check) = out.split_at_mut(36);
        let (index, leaf) = body.split_at_mut(4);
        index.copy_from_slice(&self.extent_index.to_be_bytes());
        leaf.copy_from_slice(&self.leaf);
        let digest = Sha256::digest(&[body]);
        let (digest_head, _) = digest.split_at(8);
        check.copy_from_slice(digest_head);
        out
    }

    /// Rebuilds the committed bitmap after a crash. Stops at the first torn or corrupt record
    /// (everything after it is resent, which is safe because extent writes are idempotent) and
    /// ignores records whose digest disagrees with `manifest` (a stale journal).
    #[must_use]
    pub fn replay(journal: &[u8], manifest: &TransferManifest) -> ExtentBitmap {
        let mut bitmap = ExtentBitmap::new(manifest.extent_count());
        for record in journal.as_chunks::<COMMIT_RECORD_LEN>().0 {
            let (body, check) = record.split_at(36);
            if Sha256::digest(&[body]).get(..8) != Some(check) {
                break;
            }
            let (index_bytes, leaf) = body.split_at(4);
            let index = u32::from_be_bytes(index_bytes.try_into().unwrap_or([0xFF; 4])) as usize;
            if manifest.leaf(index).is_some_and(|expected| expected.as_slice() == leaf) {
                bitmap.insert(index);
            }
        }
        bitmap
    }
}
