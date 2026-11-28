// MARK: - extract.rs

//! Unpacks an uploaded KRSP bundle (`krsp::bundle`) into a folder for the mastering tool.
//!
//! The bundle reader already refuses links, absolute paths, `..` and names a disc cannot hold;
//! this adds the file-system rules: no two entries may differ only by letter case (they would
//! collide on Windows, macOS and the disc), files are created with `create_new` so nothing is
//! ever overwritten or followed, and the entry count is capped.

use krsp::bundle::{BundleReader, EntryKind, collision_key};
use std::collections::HashSet;
use std::fs::{self, File};
use std::io::{self, BufReader, BufWriter, Read, Write};
use std::path::{Path, PathBuf};
use std::sync::atomic::{AtomicBool, Ordering};
use std::time::{Duration, SystemTime};

/// More entries than any disc file system handles comfortably.
pub const MAX_ENTRIES: u64 = 250_000;

#[derive(Clone, Copy, Debug, Default, PartialEq, Eq)]
pub struct Extracted {
    pub files: u64,
    pub folders: u64,
    pub bytes: u64,
    pub largest_file: u64,
}

/// Counts bytes read, for progress.
#[derive(Debug)]
struct Counting<R> {
    inner: R,
    count: u64,
}

impl<R: Read> Read for Counting<R> {
    fn read(&mut self, buf: &mut [u8]) -> io::Result<usize> {
        let n = self.inner.read(buf)?;
        self.count += n as u64;
        Ok(n)
    }
}

/// Extracts `archive` into `tree` (which is emptied first). `progress` gets 0…1.
///
/// # Errors
/// A message for the user: a rejected name, a damaged archive, a disk error, or `Cancelled`.
pub fn extract_bundle(
    archive: &Path,
    tree: &Path,
    cancel: &AtomicBool,
    progress: &mut dyn FnMut(f64, &Extracted),
) -> Result<Extracted, String> {
    if tree.exists() {
        fs::remove_dir_all(tree).map_err(|e| format!("Could not clear the work folder: {e}"))?;
    }
    fs::create_dir_all(tree).map_err(|e| format!("Could not create the work folder: {e}"))?;
    let total = fs::metadata(archive).map_err(|e| format!("The upload is missing: {e}"))?.len().max(1);
    let file = File::open(archive).map_err(|e| format!("Could not open the upload: {e}"))?;
    let mut reader = BundleReader::new(Counting { inner: BufReader::with_capacity(1 << 20, file), count: 0 });
    let mut seen = HashSet::new();
    let mut folders: Vec<(PathBuf, u64)> = Vec::new();
    let mut summary = Extracted::default();
    let keep_going = || !cancel.load(Ordering::SeqCst);

    while let Some(entry) = reader.next_entry().map_err(|e| e.to_string())? {
        if !keep_going() {
            return Err("Cancelled".into());
        }
        if summary.files + summary.folders >= MAX_ENTRIES {
            return Err(format!("The folder has more than {MAX_ENTRIES} files and folders"));
        }
        if !seen.insert(collision_key(&entry.path)) {
            return Err(format!(
                "“{}” appears twice (names that differ only in upper and lower case count as the same name)",
                entry.path
            ));
        }
        let target = entry.path.split('/').fold(tree.to_path_buf(), |p, part| p.join(part));
        match entry.kind {
            EntryKind::Directory => {
                fs::create_dir_all(&target).map_err(|e| format!("Could not create “{}”: {e}", entry.path))?;
                folders.push((target, entry.mtime));
                summary.folders += 1;
            }
            EntryKind::File => {
                if let Some(parent) = target.parent() {
                    fs::create_dir_all(parent)
                        .map_err(|e| format!("Could not create a folder for “{}”: {e}", entry.path))?;
                }
                let out = File::create_new(&target).map_err(|e| format!("Could not create “{}”: {e}", entry.path))?;
                let mut writer = BufWriter::with_capacity(1 << 20, out);
                if !reader.copy_data(&mut writer, &keep_going).map_err(|e| e.to_string())? {
                    return Err("Cancelled".into());
                }
                writer.flush().map_err(|e| format!("Could not write “{}”: {e}", entry.path))?;
                let out = writer.into_inner().map_err(|e| format!("Could not write “{}”: {e}", entry.path))?;
                let _ = out.set_modified(time_from(entry.mtime));
                summary.files += 1;
                summary.bytes += entry.size;
                summary.largest_file = summary.largest_file.max(entry.size);
            }
        }
        #[allow(clippy::cast_precision_loss)]
        progress(reader.get_ref().count as f64 / total as f64, &summary);
    }
    if summary.files == 0 {
        return Err("The folder has no files to burn".into());
    }
    // Folder times last (deepest first), since creating children touches them. Best effort:
    // Windows cannot open a folder as a file without extra flags.
    for (path, mtime) in folders.iter().rev() {
        if let Ok(dir) = File::open(path) {
            let _ = dir.set_modified(time_from(*mtime));
        }
    }
    Ok(summary)
}

/// A bundle's mtime as a file time. The value comes from the client (a pax `mtime` record can be
/// any `u64`), and `SystemTime + Duration` panics past the platform's range, which would take the
/// whole server down (release builds abort on panic): out-of-range times become the epoch.
fn time_from(seconds: u64) -> SystemTime {
    SystemTime::UNIX_EPOCH.checked_add(Duration::from_secs(seconds)).unwrap_or(SystemTime::UNIX_EPOCH)
}

// MARK: - Tests

#[cfg(test)]
#[allow(clippy::unwrap_used, clippy::expect_used, clippy::panic, clippy::indexing_slicing)]
mod tests {
    use super::*;
    use crate::testutil::TempDir;
    use krsp::bundle::BundleWriter;

    fn archive(dir: &Path, build: impl FnOnce(&mut BundleWriter<Vec<u8>>)) -> PathBuf {
        let mut w = BundleWriter::new(Vec::new());
        build(&mut w);
        let path = dir.join("bundle.tar");
        fs::write(&path, w.finish().unwrap()).unwrap();
        path
    }

    #[test]
    fn extracts_files_folders_and_times() {
        let tmp = TempDir::new("extract");
        let a = archive(tmp.path(), |w| {
            w.directory("Photos", 1_700_000_000).unwrap();
            w.file("Photos/a.jpg", 3, 1_700_000_100, &mut &b"abc"[..]).unwrap();
            w.file("deep/er/b.txt", 1, 0, &mut &b"b"[..]).unwrap();
        });
        let tree = tmp.path().join("tree");
        let mut last = 0.0;
        let got = extract_bundle(&a, &tree, &AtomicBool::new(false), &mut |f, _| last = f).unwrap();
        assert_eq!(got, Extracted { files: 2, folders: 1, bytes: 4, largest_file: 3 });
        assert_eq!(fs::read(tree.join("Photos").join("a.jpg")).unwrap(), b"abc");
        assert_eq!(fs::read(tree.join("deep").join("er").join("b.txt")).unwrap(), b"b");
        let mtime = fs::metadata(tree.join("Photos").join("a.jpg")).unwrap().modified().unwrap();
        assert_eq!(mtime, time_from(1_700_000_100));
        assert!(last > 0.5);
    }

    #[test]
    fn refuses_case_collisions_empty_bundles_and_stops_on_cancel() {
        let tmp = TempDir::new("extract-bad");
        let tree = tmp.path().join("tree");
        let a = archive(tmp.path(), |w| {
            w.file("Readme.txt", 1, 0, &mut &b"a"[..]).unwrap();
            w.file("README.TXT", 1, 0, &mut &b"b"[..]).unwrap();
        });
        let err = extract_bundle(&a, &tree, &AtomicBool::new(false), &mut |_, _| {}).unwrap_err();
        assert!(err.contains("appears twice"), "{err}");

        let a = archive(tmp.path(), |w| w.directory("empty", 0).unwrap());
        let err = extract_bundle(&a, &tree, &AtomicBool::new(false), &mut |_, _| {}).unwrap_err();
        assert!(err.contains("no files"), "{err}");

        let a = archive(tmp.path(), |w| w.file("a", 1, 0, &mut &b"a"[..]).unwrap());
        let err = extract_bundle(&a, &tree, &AtomicBool::new(true), &mut |_, _| {}).unwrap_err();
        assert_eq!(err, "Cancelled");
    }

    #[test]
    fn an_out_of_range_pax_mtime_does_not_panic() {
        // A pax header (`x`) whose `mtime` is u64::MAX, then a one-byte file. The writer never emits
        // this, so the bytes are put together by hand, as a hostile client would.
        let tmp = TempDir::new("extract-mtime");
        let record = krsp::bundle::pax_record("mtime", &u64::MAX.to_string());
        let mut tar = header("././@PaxHeader", b'x', record.len() as u64);
        tar.extend_from_slice(record.as_bytes());
        tar.resize(1024, 0);
        tar.extend_from_slice(&header("a.txt", b'0', 1));
        tar.push(b'a');
        tar.resize(tar.len() + 511 + 1024, 0);
        let path = tmp.path().join("bundle.tar");
        fs::write(&path, &tar).unwrap();
        let tree = tmp.path().join("tree");
        let got = extract_bundle(&path, &tree, &AtomicBool::new(false), &mut |_, _| {}).unwrap();
        assert_eq!(got.files, 1);
        assert_eq!(fs::read(tree.join("a.txt")).unwrap(), b"a");
    }

    /// A minimal ustar header with a valid checksum.
    fn header(name: &str, kind: u8, size: u64) -> Vec<u8> {
        let mut h = vec![0u8; 512];
        h[..name.len()].copy_from_slice(name.as_bytes());
        h[100..108].copy_from_slice(b"0000644\0");
        h[124..136].copy_from_slice(format!("{size:011o}\0").as_bytes());
        h[136..148].copy_from_slice(b"00000000000\0");
        h[156] = kind;
        h[257..265].copy_from_slice(b"ustar\x0000");
        h[148..156].copy_from_slice(b"        ");
        let sum: u32 = h.iter().map(|b| u32::from(*b)).sum();
        h[148..156].copy_from_slice(format!("{sum:06o}\0 ").as_bytes());
        h
    }

    #[test]
    fn a_damaged_upload_is_reported_not_extracted_past() {
        let tmp = TempDir::new("extract-damaged");
        let a = archive(tmp.path(), |w| w.file("a.bin", 5000, 0, &mut &[1u8; 5000][..]).unwrap());
        let bytes = fs::read(&a).unwrap();
        fs::write(&a, &bytes[..3000]).unwrap();
        let err = extract_bundle(&a, &tmp.path().join("tree"), &AtomicBool::new(false), &mut |_, _| {}).unwrap_err();
        assert!(err.contains("damaged"), "{err}");
    }
}
