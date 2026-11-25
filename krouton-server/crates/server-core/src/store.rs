// MARK: - store.rs

//! Durable, resumable staging of one uploaded image.
//!
//! Layout of `<spool>/<job>/`:
//!
//! | File | Contents |
//! |---|---|
//! | `manifest.krsp` | The client's `ManifestOffer` frame, verbatim (leaf digests + root). |
//! | `journal.krsp` | Append-only 44-byte commit records, one per durable extent. |
//! | `image.part` | The image being written, extent by extent, at its final offsets. |
//! | `image.iso` | The same file after every extent is committed (renamed, then fsynced). |
//!
//! Every extent is written at its offset, flushed to disk, and only then journalled and
//! acknowledged, so after a crash or power cut the journal never claims an extent that is not on
//! disk. Replay stops at the first torn record and truncates the journal there; anything after it
//! is simply sent again (extent writes are idempotent).

use krsp::frame::{FrameDecoder, MAX_PAYLOAD};
use krsp::manifest::{COMMIT_RECORD_LEN, CommitRecord, ExtentBitmap, ManifestOffer, TransferManifest};
use std::fs::{self, File, OpenOptions};
use std::io::{self, Read, Write};
use std::path::{Path, PathBuf};

pub const MANIFEST_FILE: &str = "manifest.krsp";
pub const JOURNAL_FILE: &str = "journal.krsp";
pub const PARTIAL_FILE: &str = "image.part";
pub const IMAGE_FILE: &str = "image.iso";

#[derive(Debug)]
pub struct StagedImage {
    dir: PathBuf,
    manifest: TransferManifest,
    committed: ExtentBitmap,
    image: Option<File>,
    journal: Option<File>,
}

impl StagedImage {
    /// Opens (or creates) the staging directory for `manifest`. If the directory already holds a
    /// different manifest, the old upload is discarded and a new one starts.
    pub fn open(dir: &Path, manifest: &TransferManifest) -> io::Result<Self> {
        fs::create_dir_all(dir)?;
        let manifest_path = dir.join(MANIFEST_FILE);
        let same = load_manifest(dir).is_ok_and(|existing| existing == *manifest);
        if !same {
            for name in [JOURNAL_FILE, PARTIAL_FILE, IMAGE_FILE] {
                remove_if_exists(&dir.join(name))?;
            }
            let frame = ManifestOffer::encode(manifest)
                .ok_or_else(|| io::Error::new(io::ErrorKind::InvalidInput, "manifest cannot be encoded"))?;
            write_atomically(&manifest_path, &frame.encode())?;
        }

        // An already-complete upload (the server restarted after the rename) needs no files open.
        if dir.join(IMAGE_FILE).exists() {
            let mut committed = ExtentBitmap::new(manifest.extent_count());
            for i in 0..manifest.extent_count() {
                committed.insert(i);
            }
            return Ok(Self { dir: dir.to_owned(), manifest: manifest.clone(), committed, image: None, journal: None });
        }

        let mut journal_bytes = Vec::new();
        let journal_path = dir.join(JOURNAL_FILE);
        if journal_path.exists() {
            File::open(&journal_path)?.read_to_end(&mut journal_bytes)?;
        }
        let valid_len = valid_journal_prefix(&journal_bytes);
        let committed = CommitRecord::replay(journal_bytes.get(..valid_len).unwrap_or_default(), manifest);

        let journal = OpenOptions::new().create(true).append(true).open(&journal_path)?;
        if (valid_len as u64) < journal.metadata()?.len() {
            journal.set_len(valid_len as u64)?;
            journal.sync_all()?;
        }
        let image =
            OpenOptions::new().create(true).truncate(false).read(true).write(true).open(dir.join(PARTIAL_FILE))?;
        if image.metadata()?.len() != manifest.image_bytes() {
            image.set_len(manifest.image_bytes())?;
        }
        Ok(Self {
            dir: dir.to_owned(),
            manifest: manifest.clone(),
            committed,
            image: Some(image),
            journal: Some(journal),
        })
    }

    #[must_use]
    pub fn manifest(&self) -> &TransferManifest {
        &self.manifest
    }

    #[must_use]
    pub fn committed(&self) -> &ExtentBitmap {
        &self.committed
    }

    #[must_use]
    pub fn is_complete(&self) -> bool {
        self.committed.is_complete()
    }

    /// Makes one verified extent durable. Call only with bytes whose leaf digest matched the
    /// manifest (the `StagingReceiver` guarantees this).
    pub fn commit(&mut self, index: usize, bytes: &[u8]) -> io::Result<()> {
        if self.committed.contains(index) {
            return Ok(());
        }
        let leaf = *self
            .manifest
            .leaf(index)
            .ok_or_else(|| io::Error::new(io::ErrorKind::InvalidInput, "extent out of range"))?;
        let (Some(image), Some(journal)) = (self.image.as_mut(), self.journal.as_mut()) else {
            return Err(io::Error::other("image already sealed"));
        };
        write_all_at(image, bytes, self.manifest.byte_range(index).start)?;
        image.sync_data()?;
        let index_u32 =
            u32::try_from(index).map_err(|_| io::Error::new(io::ErrorKind::InvalidInput, "extent index"))?;
        journal.write_all(&CommitRecord { extent_index: index_u32, leaf }.encode())?;
        journal.sync_data()?;
        self.committed.insert(index);
        Ok(())
    }

    /// Once every extent is committed: flush, rename `image.part` → `image.iso`, and return its
    /// path. Idempotent.
    pub fn seal(&mut self) -> io::Result<PathBuf> {
        let final_path = self.dir.join(IMAGE_FILE);
        if final_path.exists() {
            return Ok(final_path);
        }
        if !self.committed.is_complete() {
            return Err(io::Error::other("upload is not complete"));
        }
        if let Some(image) = self.image.take() {
            image.sync_all()?;
        }
        self.journal = None;
        fs::rename(self.dir.join(PARTIAL_FILE), &final_path)?;
        sync_dir(&self.dir);
        remove_if_exists(&self.dir.join(JOURNAL_FILE))?;
        Ok(final_path)
    }
}

/// Reads back the manifest stored by a previous `open` (used after a server restart).
pub fn load_manifest(dir: &Path) -> io::Result<TransferManifest> {
    let bytes = fs::read(dir.join(MANIFEST_FILE))?;
    if bytes.len() > MAX_PAYLOAD as usize + krsp::frame::HEADER_LEN {
        return Err(io::Error::new(io::ErrorKind::InvalidData, "manifest file too large"));
    }
    let mut decoder = FrameDecoder::new();
    let frame = decoder
        .push(&bytes)
        .ok()
        .and_then(|mut frames| frames.pop())
        .ok_or_else(|| io::Error::new(io::ErrorKind::InvalidData, "manifest file is not a KRSP frame"))?;
    ManifestOffer::decode(&frame).map_err(|_| io::Error::new(io::ErrorKind::InvalidData, "manifest file is corrupt"))
}

/// Length of the journal prefix made of whole records whose checksums verify.
fn valid_journal_prefix(journal: &[u8]) -> usize {
    let mut len = 0;
    for record in journal.chunks_exact(COMMIT_RECORD_LEN) {
        let (body, check) = record.split_at(36);
        if krsp::sha256::Sha256::digest(&[body]).get(..8) != Some(check) {
            break;
        }
        len += COMMIT_RECORD_LEN;
    }
    len
}

pub fn remove_if_exists(path: &Path) -> io::Result<()> {
    match fs::remove_file(path) {
        Err(e) if e.kind() != io::ErrorKind::NotFound => Err(e),
        _ => Ok(()),
    }
}

/// Writes `bytes` to `path` via a temporary file and rename, so readers never see half a file.
pub fn write_atomically(path: &Path, bytes: &[u8]) -> io::Result<()> {
    let tmp = path.with_extension("tmp");
    {
        let mut file = File::create(&tmp)?;
        file.write_all(bytes)?;
        file.sync_all()?;
    }
    fs::rename(&tmp, path)?;
    if let Some(parent) = path.parent() {
        sync_dir(parent);
    }
    Ok(())
}

/// Best-effort directory fsync so a rename survives power loss (a no-op where unsupported).
fn sync_dir(dir: &Path) {
    #[cfg(unix)]
    if let Ok(d) = File::open(dir) {
        let _ = d.sync_all();
    }
    #[cfg(not(unix))]
    let _ = dir;
}

#[cfg(unix)]
fn write_all_at(file: &File, bytes: &[u8], offset: u64) -> io::Result<()> {
    std::os::unix::fs::FileExt::write_all_at(file, bytes, offset)
}

#[cfg(windows)]
fn write_all_at(file: &File, mut bytes: &[u8], mut offset: u64) -> io::Result<()> {
    use std::os::windows::fs::FileExt;
    while !bytes.is_empty() {
        let n = file.seek_write(bytes, offset)?;
        if n == 0 {
            return Err(io::Error::new(io::ErrorKind::WriteZero, "seek_write wrote nothing"));
        }
        bytes = bytes.get(n..).unwrap_or_default();
        offset += n as u64;
    }
    Ok(())
}

#[cfg(test)]
#[allow(clippy::unwrap_used, clippy::indexing_slicing, clippy::cast_possible_truncation)]
mod tests {
    use super::*;
    use crate::testutil::TempDir;

    fn image() -> Vec<u8> {
        (0..40usize * 2048).map(|i| (i * 7 + (i >> 11)) as u8).collect()
    }

    #[test]
    fn commits_survive_reopen_and_torn_journal_tail() {
        let tmp = TempDir::new("store");
        let data = image();
        let manifest = TransferManifest::from_image(&data, 2048, 4).unwrap();
        let extent = |i: usize| {
            let r = manifest.byte_range(i);
            data[r.start as usize..r.end as usize].to_vec()
        };
        {
            let mut staged = StagedImage::open(tmp.path(), &manifest).unwrap();
            for i in [0, 3, 4] {
                staged.commit(i, &extent(i)).unwrap();
            }
        }
        // Simulate a power cut halfway through appending a record.
        let mut journal = OpenOptions::new().append(true).open(tmp.path().join(JOURNAL_FILE)).unwrap();
        journal.write_all(&[0xAA; 20]).unwrap();
        drop(journal);

        let mut staged = StagedImage::open(tmp.path(), &manifest).unwrap();
        assert_eq!(staged.committed().committed_count(), 3);
        assert_eq!(fs::metadata(tmp.path().join(JOURNAL_FILE)).unwrap().len(), 3 * COMMIT_RECORD_LEN as u64);
        for i in 0..manifest.extent_count() {
            staged.commit(i, &extent(i)).unwrap();
        }
        let path = staged.seal().unwrap();
        assert_eq!(fs::read(&path).unwrap(), data);
        assert!(!tmp.path().join(JOURNAL_FILE).exists());

        // After the seal a reopen reports everything committed without touching the image.
        let reopened = StagedImage::open(tmp.path(), &manifest).unwrap();
        assert!(reopened.is_complete());
        assert_eq!(load_manifest(tmp.path()).unwrap(), manifest);
    }

    #[test]
    fn a_different_manifest_restarts_the_upload() {
        let tmp = TempDir::new("store-restart");
        let data = image();
        let first = TransferManifest::from_image(&data, 2048, 4).unwrap();
        let mut staged = StagedImage::open(tmp.path(), &first).unwrap();
        let r = first.byte_range(0);
        staged.commit(0, &data[r.start as usize..r.end as usize]).unwrap();
        drop(staged);
        let mut other = data.clone();
        other[0] ^= 1;
        let second = TransferManifest::from_image(&other, 2048, 4).unwrap();
        let staged = StagedImage::open(tmp.path(), &second).unwrap();
        assert_eq!(staged.committed().committed_count(), 0);
        assert!(staged.seal_check_incomplete());
    }

    impl StagedImage {
        fn seal_check_incomplete(mut self) -> bool {
            self.seal().is_err()
        }
    }
}
