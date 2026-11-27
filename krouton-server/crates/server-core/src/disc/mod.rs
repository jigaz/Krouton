// MARK: - disc/mod.rs

//! Krouton Server's own disc mastering: builds an ISO 9660 / Joliet / UDF image from a folder
//! with no outside tool, the same bytes on every platform.
//!
//! | Folder | File systems | Why |
//! |---|---|---|
//! | `VIDEO_TS` at the top | ISO 9660 (8.3) + UDF 1.02 | what DVD-Video players read; video files first and in player order |
//! | `BDMV` at the top | UDF 2.50 with a metadata partition | what BD-ROM uses |
//! | anything else | ISO 9660 + Joliet + UDF 2.01 | readable everywhere; UDF 2.01 alone with a file of 4 GiB or more |
//!
//! Layout, in 2048-byte sectors: system area (0–15), ISO 9660 descriptors then the UDF
//! recognition sequence (16–), the UDF volume descriptor sequences (32 and 48), the integrity
//! descriptor (64), the anchor (256), then one read-only partition from sector 257 holding the
//! UDF file set, entries and directories (in a duplicated metadata partition for UDF 2.50), the
//! ISO 9660 path tables and directories, and the file contents, which ISO 9660 and UDF share.
//! A second anchor ends the image.

pub mod ecma;
pub mod iso;
pub mod tree;
pub mod udf;

pub use tree::{Profile, Tree};

use crate::backend::MasterRequest;
use crate::backend::master::{ISO_FILE_LIMIT, ISO9660, JOLIET, UDF, iso_volume_name, unicode_volume_name};
use ecma::{Civil, SECTOR, sectors, u32_of};
use iso::{Flavor, Names};
use std::fs::{self, File};
use std::io::{Read, Seek, SeekFrom, Write};
use std::path::Path;
use std::sync::atomic::{AtomicBool, Ordering};
use udf::{Allocation, Entry, LongAd, MetadataMap, Revision, file_type};

const MAIN_VDS: u32 = 32;
const RESERVE_VDS: u32 = 48;
const VDS_SECTORS: u32 = 16;
const INTEGRITY: u32 = 64;
const ANCHOR: u32 = 256;
const PARTITION: u32 = 257;
/// UDF 2.50 metadata is allocated in 64 KiB units, a Blu-ray ECC block.
const ALIGN: u64 = 32;

/// Builds the image for `request.tree` at `request.output`. `now` (Unix seconds) dates the
/// volume. Returns the file systems written.
///
/// # Errors
/// A message for the user, or `Cancelled`. The partial image is removed.
pub fn master(
    request: &MasterRequest<'_>,
    now: u64,
    progress: &mut dyn FnMut(Option<f64>),
) -> Result<Vec<&'static str>, String> {
    let tree = Tree::scan(request.tree, request.cancel)?;
    let result = build(&tree, request.output, request.label, now, request.cancel, progress);
    if result.is_err() {
        let _ = fs::remove_file(request.output);
    }
    result
}

/// Whether `tree` should be mastered here even on a platform with its own tool: DVD-Video and
/// Blu-ray folders need the file order and UDF revision only this writer guarantees.
#[must_use]
pub fn needs_builtin(tree: &Path) -> bool {
    let has = |name: &str| {
        fs::read_dir(tree)
            .into_iter()
            .flatten()
            .flatten()
            .any(|e| e.file_name().to_str().is_some_and(|n| n.eq_ignore_ascii_case(name)) && e.path().is_dir())
    };
    has("VIDEO_TS") || has("BDMV")
}

// MARK: - Layout

/// Where everything goes, in blocks of the physical partition unless noted.
#[derive(Debug)]
struct Layout {
    revision: Revision,
    iso: Option<Names>,
    joliet: Option<Names>,
    metadata: bool,
    /// Per node, in the partition that holds the file set (the metadata partition for UDF 2.50).
    entry_block: Vec<u32>,
    stream_block: Vec<u32>,
    stream_len: Vec<u64>,
    meta_start: u64,
    mirror_start: u64,
    file_block: Vec<u32>,
    iso_tables: [(u32, u32); 2],
    iso_dirs: [Vec<u32>; 2],
    partition_len: u64,
}

impl Layout {
    fn new(tree: &Tree, profile: Profile) -> Result<Self, String> {
        let large = tree.largest_file() >= ISO_FILE_LIMIT;
        let (revision, iso, joliet, metadata) = match profile {
            Profile::Data => (Revision::V2_01, !large, !large, false),
            Profile::DvdVideo if large => {
                return Err("A DVD-Video disc can't hold a file of 4 GiB or more".into());
            }
            Profile::DvdVideo => (Revision::V1_02, true, false, false),
            Profile::BluRay => (Revision::V2_50, false, false, true),
        };
        let n = tree.nodes.len();
        let mut entry_block = vec![0u32; n];
        let mut stream_block = vec![0u32; n];
        let mut stream_len = vec![0u64; n];
        let mut next: u64 = 2; // file set descriptor, then its terminator
        for (i, node) in tree.nodes.iter().enumerate() {
            entry_block[i] = u32_of(next)?;
            next += 1;
            if node.is_dir() {
                let names: usize =
                    node.children().iter().map(|&c| udf::fid_len(udf::fid_name(&tree.nodes[c].name).len())).sum();
                stream_len[i] = (udf::fid_len(0) + names) as u64;
                stream_block[i] = u32_of(next)?;
                next += sectors(stream_len[i]);
            }
        }
        let mut cursor = next;
        let (mut meta_start, mut mirror_start) = (0, 0);
        if metadata {
            let size = next.next_multiple_of(ALIGN);
            meta_start = ALIGN;
            mirror_start = meta_start + size;
            cursor = mirror_start + size;
        }
        let level1 = profile == Profile::DvdVideo;
        let iso = iso.then(|| Names::plan(tree, Flavor::Iso { level1 }));
        let joliet = joliet.then(|| Names::plan(tree, Flavor::Joliet));
        let mut iso_tables = [(0, 0); 2];
        let mut iso_dirs = [vec![0u32; n], vec![0u32; n]];
        for (k, names) in [&iso, &joliet].into_iter().enumerate() {
            let Some(names) = names else { continue };
            let table = sectors(names.path_table_bytes);
            iso_tables[k] = (u32_of(u64::from(PARTITION) + cursor)?, u32_of(u64::from(PARTITION) + cursor + table)?);
            cursor += 2 * table;
            for &dir in &names.path_order {
                iso_dirs[k][dir] = u32_of(u64::from(PARTITION) + cursor)?;
                cursor += sectors(names.dir_bytes[dir]);
            }
        }
        if metadata {
            cursor = cursor.next_multiple_of(ALIGN);
        }
        let mut file_block = vec![0u32; n];
        for i in tree.file_order(profile) {
            let size = tree.nodes[i].size();
            if size > 0 {
                file_block[i] = u32_of(cursor)?;
                cursor += sectors(size);
            }
        }
        u32_of(u64::from(PARTITION) + cursor + 1)?;
        Ok(Self {
            revision,
            iso,
            joliet,
            metadata,
            entry_block,
            stream_block,
            stream_len,
            meta_start,
            mirror_start,
            file_block,
            iso_tables,
            iso_dirs,
            partition_len: cursor,
        })
    }

    fn total_sectors(&self) -> u64 {
        u64::from(PARTITION) + self.partition_len + 1
    }

    fn metadata_blocks(&self) -> u64 {
        self.mirror_start - self.meta_start
    }

    /// The partition reference of the file set: 1 (the metadata map) for UDF 2.50.
    fn namespace_partition(&self) -> u16 {
        u16::from(self.metadata)
    }

    fn unique(i: usize) -> u64 {
        if i == 0 { 0 } else { udf::FIRST_UNIQUE_ID + (i as u64 - 1) }
    }

    fn icb(&self, i: usize) -> LongAd {
        LongAd {
            length: 2048,
            block: self.entry_block[i],
            partition: self.namespace_partition(),
            unique: u32::try_from(Self::unique(i) & 0xFFFF_FFFF).unwrap_or(0),
        }
    }
}

// MARK: - Writing

struct Image<'a> {
    file: File,
    layout: &'a Layout,
}

impl Image<'_> {
    fn put(&mut self, sector: u64, bytes: &[u8]) -> Result<(), String> {
        let io = |e: std::io::Error| format!("Could not write the image: {e}");
        self.file.seek(SeekFrom::Start(sector * SECTOR)).map_err(io)?;
        self.file.write_all(bytes).map_err(io)
    }

    /// Writes into the partition holding the file set: both copies of the metadata partition
    /// for UDF 2.50, the physical partition otherwise.
    fn put_namespace(&mut self, block: u64, bytes: &[u8]) -> Result<(), String> {
        let base = u64::from(PARTITION);
        if self.layout.metadata {
            let (meta, mirror) = (self.layout.meta_start, self.layout.mirror_start);
            self.put(base + meta + block, bytes)?;
            self.put(base + mirror + block, bytes)
        } else {
            self.put(base + block, bytes)
        }
    }
}

/// Writes the image for an already-scanned tree.
///
/// # Errors
/// A message for the user, or `Cancelled`.
pub fn build(
    tree: &Tree,
    output: &Path,
    label: &str,
    now: u64,
    cancel: &AtomicBool,
    progress: &mut dyn FnMut(Option<f64>),
) -> Result<Vec<&'static str>, String> {
    let profile = tree.profile();
    let layout = Layout::new(tree, profile)?;
    let total = layout.total_sectors();
    let created = Civil::from_unix(now);
    let volume = udf::Volume {
        revision: layout.revision,
        label: unicode_volume_name(label, 126),
        created,
        set_id: format!(
            "{:08X}{:08X}",
            now & 0xFFFF_FFFF,
            fnv(label.as_bytes()) ^ (tree.nodes.len() as u64 & 0xFFFF_FFFF)
        ),
    };
    let file = File::create(output).map_err(|e| format!("Could not create the image: {e}"))?;
    file.set_len(total * SECTOR).map_err(|e| format!("Not enough space for the image: {e}"))?;
    let mut image = Image { file, layout: &layout };
    progress(Some(0.0));

    // Volume recognition: ISO 9660 descriptors first when there is a bridge, then UDF's.
    let mut sector = 16u64;
    let iso_volume = iso::Volume {
        iso_name: &iso_volume_name(label),
        joliet_name: &unicode_volume_name(label, 16),
        sectors: u32_of(total)?,
        created,
    };
    for (k, names) in [&layout.iso, &layout.joliet].into_iter().enumerate() {
        if let Some(names) = names {
            let (l, m) = layout.iso_tables[k];
            image.put(sector, &names.volume_descriptor(&iso_volume, layout.iso_dirs[k][0], l, m))?;
            sector += 1;
        }
    }
    if layout.iso.is_some() {
        image.put(sector, &iso::terminator())?;
        sector += 1;
    }
    for id in [b"BEA01", layout.revision.nsr(), b"TEA01"] {
        image.put(sector, &udf::recognition(id))?;
        sector += 1;
    }

    // Volume descriptor sequences, integrity, anchors.
    let v = &volume;
    let metadata_map = layout.metadata.then_some(MetadataMap { file: 0, mirror: 1, alignment: 32 });
    let file_set_ad = LongAd { length: 2048, block: 0, partition: layout.namespace_partition(), unique: 0 };
    for start in [MAIN_VDS, RESERVE_VDS] {
        let s = u64::from(start);
        image.put(s, &udf::primary(v, 0, start))?;
        image.put(s + 1, &udf::implementation_use(v, 1, start + 1))?;
        image.put(s + 2, &udf::partition(v, 2, start + 2, PARTITION, u32_of(layout.partition_len)?))?;
        image.put(s + 3, &udf::logical_volume(v, 3, start + 3, file_set_ad, (2 * 2048, INTEGRITY), metadata_map))?;
        image.put(s + 4, &udf::unallocated_space(v, 4, start + 4))?;
        image.put(s + 5, &udf::terminating(v, start + 5))?;
    }
    let mut sizes = vec![u32_of(layout.partition_len)?];
    if layout.metadata {
        sizes.push(u32_of(layout.metadata_blocks())?);
    }
    let dirs = tree.nodes.iter().skip(1).filter(|n| n.is_dir()).count() as u64;
    let files = tree.nodes.len() as u64 - 1 - dirs;
    let next_unique = udf::FIRST_UNIQUE_ID + tree.nodes.len() as u64;
    image
        .put(u64::from(INTEGRITY), &udf::integrity(v, INTEGRITY, &sizes, next_unique, u32_of(files)?, u32_of(dirs)?))?;
    image.put(u64::from(INTEGRITY) + 1, &udf::terminating(v, INTEGRITY + 1))?;
    let vds = (VDS_SECTORS * 2048, MAIN_VDS);
    let reserve = (VDS_SECTORS * 2048, RESERVE_VDS);
    image.put(u64::from(ANCHOR), &udf::anchor(v, ANCHOR, vds, reserve))?;
    image.put(total - 1, &udf::anchor(v, u32_of(total - 1)?, vds, reserve))?;

    // UDF 2.50: the metadata file and its mirror, in the physical partition.
    if layout.metadata {
        let bytes = layout.metadata_blocks() * SECTOR;
        for (block, kind, start) in
            [(0u32, file_type::METADATA, layout.meta_start), (1, file_type::METADATA_MIRROR, layout.mirror_start)]
        {
            let entry = Entry {
                file_type: kind,
                unique: 0,
                length: bytes,
                links: 1,
                modified: created,
                allocation: Allocation::Short(udf::extents(bytes, u32_of(start)?)),
            };
            image.put(u64::from(PARTITION + block), &udf::file_entry(v, block, true, &entry)?)?;
        }
    }

    write_file_set(&mut image, tree, v)?;
    write_iso(&mut image, tree)?;
    copy_contents(&mut image, tree, profile, cancel, progress)?;
    image.file.sync_all().map_err(|e| format!("Could not write the image: {e}"))?;
    let mut systems = Vec::new();
    if layout.iso.is_some() {
        systems.push(ISO9660);
    }
    if layout.joliet.is_some() {
        systems.push(JOLIET);
    }
    systems.push(UDF);
    Ok(systems)
}

/// The file set descriptor, then every entry and directory.
fn write_file_set(image: &mut Image<'_>, tree: &Tree, v: &udf::Volume) -> Result<(), String> {
    let layout = image.layout;
    let root = layout.icb(0);
    image.put_namespace(0, &udf::file_set(v, 0, root))?;
    image.put_namespace(1, &udf::terminating(v, 1))?;
    for (i, node) in tree.nodes.iter().enumerate() {
        let entry = if node.is_dir() {
            let subdirs = node.children().iter().filter(|&&c| tree.nodes[c].is_dir()).count();
            Entry {
                file_type: file_type::DIRECTORY,
                unique: Layout::unique(i),
                length: layout.stream_len[i],
                links: u16::try_from(1 + subdirs).unwrap_or(u16::MAX),
                modified: Civil::from_unix(node.mtime),
                allocation: Allocation::Short(udf::extents(layout.stream_len[i], layout.stream_block[i])),
            }
        } else {
            let pieces = udf::extents(node.size(), layout.file_block[i]);
            let allocation = if layout.metadata {
                Allocation::Long(
                    pieces.iter().map(|&(length, block)| LongAd { length, block, partition: 0, unique: 0 }).collect(),
                )
            } else {
                Allocation::Short(pieces)
            };
            Entry {
                file_type: file_type::FILE,
                unique: Layout::unique(i),
                length: node.size(),
                links: 1,
                modified: Civil::from_unix(node.mtime),
                allocation,
            }
        };
        let fe = udf::file_entry(v, layout.entry_block[i], layout.metadata, &entry)
            .map_err(|e| format!("{e}: {}", tree.path_of(i)))?;
        image.put_namespace(u64::from(layout.entry_block[i]), &fe)?;
        if node.is_dir() {
            let start = layout.stream_block[i];
            let mut stream = Vec::with_capacity(usize::try_from(layout.stream_len[i]).unwrap_or(0));
            let parent = (udf::FID_DIRECTORY | udf::FID_PARENT, Vec::new(), layout.icb(node.parent));
            let children = node.children().iter().map(|&c| {
                let flags = if tree.nodes[c].is_dir() { udf::FID_DIRECTORY } else { 0 };
                (flags, udf::fid_name(&tree.nodes[c].name), layout.icb(c))
            });
            for (flags, name, icb) in std::iter::once(parent).chain(children) {
                let block = start + u32_of(stream.len() as u64 / SECTOR)?;
                stream.extend(udf::fid(v, block, flags, &name, icb));
            }
            image.put_namespace(u64::from(start), &stream)?;
        }
    }
    Ok(())
}

/// ISO 9660 and Joliet path tables and directories.
fn write_iso(image: &mut Image<'_>, tree: &Tree) -> Result<(), String> {
    let layout = image.layout;
    let file_sector: Vec<u32> =
        layout.file_block.iter().zip(&tree.nodes).map(|(&b, n)| if n.size() > 0 { PARTITION + b } else { 0 }).collect();
    for (k, names) in [&layout.iso, &layout.joliet].into_iter().enumerate() {
        let Some(names) = names else { continue };
        let (l_at, m_at) = layout.iso_tables[k];
        let (l, m) = names.path_tables(tree, &layout.iso_dirs[k]);
        image.put(u64::from(l_at), &l)?;
        image.put(u64::from(m_at), &m)?;
        for (at, extent) in names.directories(tree, &layout.iso_dirs[k], &file_sector) {
            image.put(u64::from(at), &extent)?;
        }
    }
    Ok(())
}

/// Copies every file's contents to its place, reporting progress by bytes.
fn copy_contents(
    image: &mut Image<'_>,
    tree: &Tree,
    profile: Profile,
    cancel: &AtomicBool,
    progress: &mut dyn FnMut(Option<f64>),
) -> Result<(), String> {
    let total = tree.total_bytes().max(1);
    let mut done = 0u64;
    let mut buffer = vec![0u8; 1 << 20];
    for i in tree.file_order(profile) {
        let node = &tree.nodes[i];
        if node.size() == 0 {
            continue;
        }
        let mut source = File::open(&node.source).map_err(|e| format!("Could not read {}: {e}", tree.path_of(i)))?;
        let at = u64::from(PARTITION) + u64::from(image.layout.file_block[i]);
        image.file.seek(SeekFrom::Start(at * SECTOR)).map_err(|e| format!("Could not write the image: {e}"))?;
        let mut left = node.size();
        while left > 0 {
            if cancel.load(Ordering::SeqCst) {
                return Err("Cancelled".into());
            }
            let want = usize::try_from(left.min(buffer.len() as u64)).unwrap_or(buffer.len());
            let got =
                source.read(&mut buffer[..want]).map_err(|e| format!("Could not read {}: {e}", tree.path_of(i)))?;
            if got == 0 {
                return Err(format!("{} changed while the disc was being built", tree.path_of(i)));
            }
            image.file.write_all(&buffer[..got]).map_err(|e| format!("Could not write the image: {e}"))?;
            left -= got as u64;
            done += got as u64;
            progress(Some(done as f64 / total as f64));
        }
    }
    Ok(())
}

fn fnv(bytes: &[u8]) -> u64 {
    bytes.iter().fold(0x811C_9DC5u64, |h, &b| (h ^ u64::from(b)).wrapping_mul(0x0100_0193)) & 0xFFFF_FFFF
}

#[cfg(test)]
mod tests;
