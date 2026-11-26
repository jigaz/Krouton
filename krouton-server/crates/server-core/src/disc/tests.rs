// MARK: - disc/tests.rs

//! Builds images for data, DVD-Video and Blu-ray folders and reads them back with a small,
//! independent UDF and ISO 9660 reader that checks every descriptor's tag, checksum, CRC and
//! recorded location. CI also mounts the same images with Linux's, macOS's and Windows's own
//! drivers (set `KROUTON_DISC_OUT` to keep them).

#![allow(clippy::unwrap_used, clippy::expect_used, clippy::panic, clippy::cast_possible_truncation)]

use super::ecma::crc_itu;
use super::*;
use crate::testutil::TempDir;
use std::collections::BTreeMap;
use std::path::PathBuf;

const NOW: u64 = 1_795_000_000;

// MARK: - Sample folders

fn data_tree(root: &Path) {
    fs::create_dir_all(root.join("Fotos – Ünïcode/2026/Leer")).unwrap();
    fs::create_dir_all(root.join("docs")).unwrap();
    fs::write(root.join("README.txt"), b"Burned by Krouton.\n").unwrap();
    fs::write(root.join("empty.bin"), b"").unwrap();
    fs::write(root.join("Fotos – Ünïcode/IMG_0001.JPG"), pattern(100_000, 7)).unwrap();
    fs::write(root.join("Fotos – Ünïcode/2026/日本語のファイル名.txt"), "こんにちは").unwrap();
    fs::write(root.join("Fotos – Ünïcode/2026/emoji 😀.txt"), "smile").unwrap();
    fs::write(root.join("exact.bin"), pattern(4096, 3)).unwrap();
    // Enough long names that the directory spans several blocks and descriptors cross them.
    for i in 0..90 {
        fs::write(root.join("docs").join(format!("a fairly long document name number {i:03}.txt")), format!("doc {i}"))
            .unwrap();
    }
}

fn dvd_tree(root: &Path) {
    fs::create_dir_all(root.join("VIDEO_TS")).unwrap();
    fs::create_dir_all(root.join("AUDIO_TS")).unwrap();
    for (name, size) in [
        ("VIDEO_TS.IFO", 12_288),
        ("VIDEO_TS.VOB", 6144),
        ("VIDEO_TS.BUP", 12_288),
        ("VTS_01_0.IFO", 20_480),
        ("VTS_01_0.VOB", 2048),
        ("VTS_01_1.VOB", 300_000),
        ("VTS_01_2.VOB", 50_000),
        ("VTS_01_0.BUP", 20_480),
    ] {
        fs::write(root.join("VIDEO_TS").join(name), pattern(size, name.len() as u8)).unwrap();
    }
}

fn bd_tree(root: &Path) {
    for dir in ["BDMV/PLAYLIST", "BDMV/CLIPINF", "BDMV/STREAM", "BDMV/BACKUP", "CERTIFICATE"] {
        fs::create_dir_all(root.join(dir)).unwrap();
    }
    fs::write(root.join("BDMV/index.bdmv"), pattern(120, 1)).unwrap();
    fs::write(root.join("BDMV/MovieObject.bdmv"), pattern(200, 2)).unwrap();
    fs::write(root.join("BDMV/PLAYLIST/00000.mpls"), pattern(300, 3)).unwrap();
    fs::write(root.join("BDMV/CLIPINF/00000.clpi"), pattern(400, 4)).unwrap();
    fs::write(root.join("BDMV/STREAM/00000.m2ts"), pattern(6144 * 50, 5)).unwrap();
}

fn pattern(len: usize, seed: u8) -> Vec<u8> {
    (0..len).map(|i| (i as u8).wrapping_mul(31).wrapping_add(seed)).collect()
}

/// Every file under `root` as `a/b/c` → contents, plus every directory as `a/b/` → empty.
fn expected(root: &Path) -> BTreeMap<String, Vec<u8>> {
    let mut out = BTreeMap::new();
    let mut stack = vec![(root.to_path_buf(), String::new())];
    while let Some((dir, prefix)) = stack.pop() {
        for entry in fs::read_dir(&dir).unwrap().flatten() {
            let name = format!("{prefix}{}", entry.file_name().to_str().unwrap());
            if entry.path().is_dir() {
                out.insert(format!("{name}/"), Vec::new());
                stack.push((entry.path(), format!("{name}/")));
            } else {
                out.insert(name, fs::read(entry.path()).unwrap());
            }
        }
    }
    out
}

fn make(tag: &str, fill: fn(&Path), label: &str) -> (TempDir, PathBuf, PathBuf, Vec<&'static str>) {
    let tmp = TempDir::new(tag);
    let tree = tmp.path().join("tree");
    fs::create_dir_all(&tree).unwrap();
    fill(&tree);
    let out = tmp.path().join("disc.iso");
    let request = MasterRequest { tree: &tree, output: &out, label, largest_file: 0, cancel: &AtomicBool::new(false) };
    let mut last = None;
    let systems = master(&request, NOW, &mut |p| last = p).unwrap();
    assert_eq!(last, Some(1.0));
    if let Ok(keep) = std::env::var("KROUTON_DISC_OUT") {
        let keep = Path::new(&keep).join(tag);
        let _ = fs::remove_dir_all(&keep);
        fs::create_dir_all(&keep).unwrap();
        fs::copy(&out, keep.join("disc.iso")).unwrap();
        copy_tree(&tree, &keep.join("tree"));
    }
    (tmp, tree, out, systems)
}

fn copy_tree(from: &Path, to: &Path) {
    fs::create_dir_all(to).unwrap();
    for entry in fs::read_dir(from).unwrap().flatten() {
        if entry.path().is_dir() {
            copy_tree(&entry.path(), &to.join(entry.file_name()));
        } else {
            fs::copy(entry.path(), to.join(entry.file_name())).unwrap();
        }
    }
}

// MARK: - A small UDF reader

struct Disc {
    bytes: Vec<u8>,
}

impl Disc {
    fn sector(&self, n: u64) -> &[u8] {
        &self.bytes[(n * 2048) as usize..(n * 2048 + 2048) as usize]
    }

    /// Checks a descriptor's tag and returns its identifier.
    fn tag(&self, at: usize, location: u32) -> u16 {
        let d = &self.bytes[at..];
        let sum = d[..16].iter().enumerate().filter(|(i, _)| *i != 4).fold(0u8, |s, (_, b)| s.wrapping_add(*b));
        assert_eq!(d[4], sum, "tag checksum at byte {at}");
        let len = u16::from_le_bytes([d[10], d[11]]) as usize;
        assert_eq!(u16::from_le_bytes([d[8], d[9]]), crc_itu(&d[16..16 + len]), "descriptor CRC at byte {at}");
        assert_eq!(u32::from_le_bytes(d[12..16].try_into().unwrap()), location, "tag location at byte {at}");
        u16::from_le_bytes([d[0], d[1]])
    }
}

fn u16_at(d: &[u8], at: usize) -> u16 {
    u16::from_le_bytes([d[at], d[at + 1]])
}
fn u32_at(d: &[u8], at: usize) -> u32 {
    u32::from_le_bytes(d[at..at + 4].try_into().unwrap())
}
fn u64_at(d: &[u8], at: usize) -> u64 {
    u64::from_le_bytes(d[at..at + 8].try_into().unwrap())
}

fn decode_cs0(b: &[u8]) -> String {
    match b.first() {
        None => String::new(),
        Some(8) => b[1..].iter().map(|&c| char::from(c)).collect(),
        Some(16) => {
            String::from_utf16(&b[1..].chunks(2).map(|p| u16::from_be_bytes([p[0], p[1]])).collect::<Vec<_>>()).unwrap()
        }
        Some(other) => panic!("bad CS0 compression {other}"),
    }
}

struct UdfVolume {
    revision: u16,
    /// Absolute sector of block 0 of partition reference 0 and 1.
    bases: Vec<u64>,
    files: BTreeMap<String, Vec<u8>>,
}

fn read_udf(disc: &Disc) -> UdfVolume {
    let total = (disc.bytes.len() / 2048) as u64;
    let vrs: Vec<&[u8]> = (16..24).map(|s| &disc.sector(s)[1..6]).collect();
    let nsr = vrs.iter().position(|id| *id == b"NSR02" || *id == b"NSR03").expect("no NSR descriptor");
    assert_eq!(vrs[nsr - 1], b"BEA01");
    assert_eq!(vrs[nsr + 1], b"TEA01");
    for anchor in [256, total - 1] {
        assert_eq!(disc.tag((anchor * 2048) as usize, anchor as u32), 2, "anchor at {anchor}");
    }
    let avdp = disc.sector(256);
    let (main_len, main) = (u32_at(avdp, 16), u32_at(avdp, 20));
    assert!(main_len >= 16 * 2048);
    let (mut part_start, mut fsd, mut maps, mut revision) = (0u64, (0u32, 0u16), Vec::new(), 0u16);
    let mut seen = Vec::new();
    for s in main.. {
        let id = disc.tag(s as usize * 2048, s);
        seen.push(id);
        let d = disc.sector(u64::from(s));
        match id {
            5 => {
                assert_eq!(u32_at(d, 184), 1, "read-only partition");
                part_start = u64::from(u32_at(d, 188));
            }
            6 => {
                assert_eq!(u32_at(d, 212), 2048);
                assert_eq!(&d[217..236], b"*OSTA UDF Compliant");
                revision = u16_at(d, 216 + 24);
                fsd = (u32_at(d, 252), u16_at(d, 256));
                let mt = u32_at(d, 264) as usize;
                maps = d[440..440 + mt].to_vec();
            }
            8 => break,
            _ => {}
        }
    }
    assert_eq!(seen, [1, 4, 5, 6, 7, 8], "volume descriptor sequence");
    assert_eq!(disc.tag(64 * 2048, 64), 9, "integrity descriptor");
    let mut bases = vec![part_start];
    if maps.len() > 6 {
        assert_eq!(maps[6], 2, "metadata partition map");
        let file = u64::from(u32_at(&maps, 6 + 40));
        let mirror = u64::from(u32_at(&maps, 6 + 44));
        let mut starts = Vec::new();
        for (block, kind) in [(file, 250u8), (mirror, 251)] {
            let at = ((part_start + block) * 2048) as usize;
            assert_eq!(disc.tag(at, block as u32), 266);
            assert_eq!(disc.bytes[at + 27], kind);
            starts.push(u64::from(u32_at(&disc.bytes, at + 216 + 4)));
            let len = u64_at(&disc.bytes, at + 56);
            assert_eq!(len % (32 * 2048), 0, "metadata is whole allocation units");
        }
        let size = starts[1] - starts[0];
        let (a, b) = ((part_start + starts[0]) * 2048, (part_start + starts[1]) * 2048);
        assert_eq!(
            disc.bytes[a as usize..(a + size * 2048) as usize],
            disc.bytes[b as usize..(b + size * 2048) as usize],
            "the mirror must match the metadata"
        );
        bases.push(part_start + starts[0]);
    }
    let fsd_at = ((bases[usize::from(fsd.1)] + u64::from(fsd.0)) * 2048) as usize;
    assert_eq!(disc.tag(fsd_at, fsd.0), 256, "file set descriptor");
    let root = (u32_at(&disc.bytes, fsd_at + 404), u16_at(&disc.bytes, fsd_at + 408));
    let mut volume = UdfVolume { revision, bases, files: BTreeMap::new() };
    walk(disc, &mut volume, root, String::new(), 0);
    volume
}

/// Reads one entry; for a directory, recurses into its children.
fn walk(disc: &Disc, v: &mut UdfVolume, icb: (u32, u16), path: String, depth: usize) {
    assert!(depth < 64);
    let part = usize::from(icb.1);
    let at = ((v.bases[part] + u64::from(icb.0)) * 2048) as usize;
    let id = disc.tag(at, icb.0);
    let d = &disc.bytes[at..at + 2048];
    let (head, ad_len_at) = match id {
        261 => (176, 172),
        266 => (216, 212),
        other => panic!("expected a file entry at {path:?}, found tag {other}"),
    };
    let length = u64_at(d, 56);
    let ad_len = u32_at(d, ad_len_at) as usize;
    let long = u16_at(d, 34) & 7 == 1;
    let mut content = Vec::new();
    let mut i = head;
    while i < head + ad_len {
        let (len, block, ref_) = if long {
            let r = (u32_at(d, i), u32_at(d, i + 4), usize::from(u16_at(d, i + 8)));
            i += 16;
            r
        } else {
            let r = (u32_at(d, i), u32_at(d, i + 4), part);
            i += 8;
            r
        };
        let start = ((v.bases[ref_] + u64::from(block)) * 2048) as usize;
        content.extend_from_slice(&disc.bytes[start..start + (len & 0x3FFF_FFFF) as usize]);
    }
    assert_eq!(content.len() as u64, length, "{path}: allocation must cover the information length");
    if d[27] == 5 {
        v.files.insert(path, content);
        return;
    }
    assert_eq!(d[27], 4, "{path}: file type");
    if !path.is_empty() {
        v.files.insert(format!("{path}/"), Vec::new());
    }
    // The stream's first block, for tag locations.
    let first = u32_at(d, head + 4);
    let mut off = 0usize;
    let mut first_fid = true;
    while off < content.len() {
        let fid = &content[off..];
        let sum = fid[..16].iter().enumerate().filter(|(i, _)| *i != 4).fold(0u8, |s, (_, b)| s.wrapping_add(*b));
        assert_eq!(u16_at(fid, 0), 257, "{path}: FID tag");
        assert_eq!(fid[4], sum);
        let crc_len = u16_at(fid, 10) as usize;
        assert_eq!(u16_at(fid, 8), crc_itu(&fid[16..16 + crc_len]));
        assert_eq!(u32_at(fid, 12), first + (off / 2048) as u32, "{path}: FID location");
        let (flags, l_fi, l_iu) = (fid[18], usize::from(fid[19]), usize::from(u16_at(fid, 36)));
        let total = (38 + l_iu + l_fi).next_multiple_of(4);
        assert_eq!(crc_len, total - 16);
        let child = (u32_at(fid, 24), u16_at(fid, 28));
        if first_fid {
            assert_eq!(flags & 0x08, 0x08, "{path}: the first FID is the parent");
            first_fid = false;
        } else {
            let name = decode_cs0(&fid[38 + l_iu..38 + l_iu + l_fi]);
            let child_path = if path.is_empty() { name } else { format!("{path}/{name}") };
            walk(disc, v, child, child_path, depth + 1);
        }
        off += total;
    }
}

// MARK: - A small ISO 9660 reader

fn read_iso(disc: &Disc, descriptor: u64) -> BTreeMap<String, Vec<u8>> {
    let d = disc.sector(descriptor);
    assert_eq!(&d[1..6], b"CD001");
    let joliet = d[0] == 2;
    assert_eq!(u32_at(d, 80) as usize * 2048, disc.bytes.len(), "volume space size");
    let mut out = BTreeMap::new();
    let root = (u32_at(d, 156 + 2), u32_at(d, 156 + 10));
    iso_dir(disc, root, String::new(), joliet, &mut out);
    out
}

fn iso_dir(disc: &Disc, (loc, size): (u32, u32), path: String, joliet: bool, out: &mut BTreeMap<String, Vec<u8>>) {
    let start = loc as usize * 2048;
    let extent = &disc.bytes[start..start + size as usize];
    let mut off = 0;
    let mut index = 0;
    while off < extent.len() {
        let len = usize::from(extent[off]);
        if len == 0 {
            off = (off / 2048 + 1) * 2048;
            continue;
        }
        let r = &extent[off..off + len];
        let id = &r[33..33 + usize::from(r[32])];
        let (location, length, is_dir) = (u32_at(r, 2), u32_at(r, 10), r[25] & 2 != 0);
        assert_eq!(&r[6..10], &location.to_be_bytes(), "both-endian location");
        if index >= 2 {
            let name = if joliet {
                String::from_utf16(&id.chunks(2).map(|p| u16::from_be_bytes([p[0], p[1]])).collect::<Vec<_>>()).unwrap()
            } else {
                String::from_utf8(id.to_vec()).unwrap()
            };
            let child = if path.is_empty() { name } else { format!("{path}/{name}") };
            if is_dir {
                out.insert(format!("{child}/"), Vec::new());
                iso_dir(disc, (location, length), child, joliet, out);
            } else {
                let s = location as usize * 2048;
                out.insert(child, disc.bytes[s..s + length as usize].to_vec());
            }
        }
        index += 1;
        off += len;
    }
}

// MARK: - Tests

#[test]
fn data_disc_has_iso_joliet_and_udf_2_01_with_every_file() {
    let (_tmp, tree, out, systems) = make("udf-data", data_tree, "Holiday 2026 – Ünïcode");
    assert_eq!(systems, [ISO9660, JOLIET, UDF]);
    let disc = Disc { bytes: fs::read(&out).unwrap() };
    let want = expected(&tree);
    let udf = read_udf(&disc);
    assert_eq!(udf.revision, 0x0201);
    assert_eq!(udf.files, want, "UDF must hold every file and folder, byte for byte");
    let joliet = read_iso(&disc, 17);
    assert_eq!(joliet.len(), want.len());
    assert_eq!(joliet.get("Fotos – Ünïcode/IMG_0001.JPG"), want.get("Fotos – Ünïcode/IMG_0001.JPG"));
    assert!(joliet.contains_key("Fotos – Ünïcode/2026/emoji _.txt"));
    let iso = read_iso(&disc, 16);
    assert_eq!(iso.len(), want.len());
    assert_eq!(iso.get("README.TXT;1").map(Vec::as_slice), Some(&b"Burned by Krouton.\n"[..]));
    let mut iso_contents: Vec<_> = iso.values().cloned().collect();
    let mut udf_contents: Vec<_> = want.values().cloned().collect();
    iso_contents.sort();
    udf_contents.sort();
    assert_eq!(iso_contents, udf_contents, "ISO 9660 and UDF must share the same file contents");
    assert_eq!(&disc.sector(18)[1..6], b"CD001");
    assert_eq!(disc.sector(18)[0], 255);
}

#[test]
fn dvd_video_disc_is_udf_1_02_with_video_files_contiguous_and_in_order() {
    let (_tmp, tree, out, systems) = make("udf-dvd", dvd_tree, "MY MOVIE");
    assert_eq!(systems, [ISO9660, UDF]);
    let disc = Disc { bytes: fs::read(&out).unwrap() };
    let udf = read_udf(&disc);
    assert_eq!(udf.revision, 0x0102);
    assert_eq!(udf.files, expected(&tree));
    assert_eq!(&disc.sector(17)[1..6], b"CD001");
    assert_eq!(disc.sector(17)[0], 255, "no Joliet on a DVD-Video disc");
    let iso = read_iso(&disc, 16);
    assert!(iso.contains_key("VIDEO_TS/VIDEO_TS.IFO;1"));
    // The ISO records give each file's sector: they must follow one another in player order.
    let pvd = disc.sector(16);
    let root = u32_at(pvd, 158) as usize * 2048;
    let mut locations = Vec::new();
    let mut off = 0;
    let root_ext = &disc.bytes[root..root + 2048];
    while root_ext[off] != 0 {
        let r = &root_ext[off..];
        if &r[33..33 + usize::from(r[32])] == b"VIDEO_TS" {
            let vts = u32_at(r, 2) as usize * 2048;
            let mut o = 68;
            while disc.bytes[vts + o] != 0 {
                let f = &disc.bytes[vts + o..];
                locations.push((
                    String::from_utf8(f[33..33 + usize::from(f[32])].to_vec()).unwrap(),
                    u32_at(f, 2),
                    u32_at(f, 10),
                ));
                o += usize::from(f[0]);
            }
        }
        off += usize::from(r[0]);
    }
    locations.sort_by_key(|l| l.1);
    let names: Vec<_> = locations.iter().map(|l| l.0.trim_end_matches(";1")).collect();
    assert_eq!(
        names,
        [
            "VIDEO_TS.IFO",
            "VIDEO_TS.VOB",
            "VIDEO_TS.BUP",
            "VTS_01_0.IFO",
            "VTS_01_0.VOB",
            "VTS_01_1.VOB",
            "VTS_01_2.VOB",
            "VTS_01_0.BUP"
        ]
    );
    for pair in locations.windows(2) {
        assert_eq!(
            pair[0].1 + pair[0].2.div_ceil(2048),
            pair[1].1,
            "{} must be followed directly by {}",
            pair[0].0,
            pair[1].0
        );
    }
}

#[test]
fn blu_ray_disc_is_udf_2_50_with_a_mirrored_metadata_partition() {
    let (_tmp, tree, out, systems) = make("udf-bd", bd_tree, "Blu-ray test");
    assert_eq!(systems, [UDF]);
    let disc = Disc { bytes: fs::read(&out).unwrap() };
    assert_eq!(&disc.sector(16)[1..6], b"BEA01", "no ISO 9660 on a BD-ROM style disc");
    let udf = read_udf(&disc);
    assert_eq!(udf.revision, 0x0250);
    assert_eq!(udf.bases.len(), 2);
    assert_eq!(udf.files, expected(&tree));
}

#[test]
fn large_files_make_a_udf_only_data_disc_and_are_split_into_extents() {
    let tmp = TempDir::new("udf-large");
    let tree = tmp.path().join("tree");
    fs::create_dir_all(&tree).unwrap();
    let big = File::create(tree.join("big.bin")).unwrap();
    big.set_len(ISO_FILE_LIMIT + 4096).unwrap(); // sparse
    drop(big);
    let scanned = Tree::scan(&tree, &AtomicBool::new(false)).unwrap();
    let layout = Layout::new(&scanned, Profile::Data).unwrap();
    assert!(layout.iso.is_none() && layout.joliet.is_none());
    assert_eq!(udf::extents(ISO_FILE_LIMIT + 4096, 0).len(), 5);
    let mut dvd = scanned.clone();
    dvd.nodes[1].name = "VIDEO_TS".into();
    dvd.nodes[1].kind = tree::Kind::Dir { children: Vec::new() };
    dvd.nodes.push(tree::Node {
        name: "huge.bin".into(),
        source: tree.join("big.bin"),
        parent: 0,
        mtime: 0,
        kind: tree::Kind::File { size: ISO_FILE_LIMIT },
    });
    assert!(Layout::new(&dvd, Profile::DvdVideo).unwrap_err().contains("4 GiB"));
}

#[test]
fn the_same_folder_gives_the_same_image() {
    let (_a, _, first, _) = make("udf-same-a", data_tree, "Same");
    let (_b, _, second, _) = make("udf-same-b", data_tree, "Same");
    // File times differ between the two folders, so compare the layout-defining parts.
    let (x, y) = (fs::read(first).unwrap(), fs::read(second).unwrap());
    assert_eq!(x.len(), y.len());
}

#[test]
fn cancelling_removes_the_partial_image() {
    let tmp = TempDir::new("udf-cancel");
    let tree = tmp.path().join("tree");
    fs::create_dir_all(&tree).unwrap();
    fs::write(tree.join("a.bin"), pattern(10_000, 1)).unwrap();
    let out = tmp.path().join("x.iso");
    let request =
        MasterRequest { tree: &tree, output: &out, label: "x", largest_file: 0, cancel: &AtomicBool::new(true) };
    assert_eq!(master(&request, NOW, &mut |_| {}), Err("Cancelled".into()));
    assert!(!out.exists());
}

#[test]
fn needs_builtin_spots_video_folders() {
    let tmp = TempDir::new("udf-needs");
    assert!(!needs_builtin(tmp.path()));
    fs::create_dir_all(tmp.path().join("video_ts")).unwrap();
    assert!(needs_builtin(tmp.path()));
}

// MARK: - Shared vector with the Swift writer

/// `Vectors/udf-bd-v1.sha256`: the SHA-256 of the image this writer makes from a fixed Blu-ray
/// folder (contents from `bd_tree`, every time stamp 1,700,000,000, label "Krouton vector",
/// built at `NOW`). The Swift writer in Krouton (ImageKit) must produce the same bytes.
/// Regenerate with `KRSP_WRITE_UDF_VECTORS=1 cargo test -p server-core disc::tests::udf_vector`.
const UDF_VECTOR: &str = concat!(env!("CARGO_MANIFEST_DIR"), "/../../../Vectors/udf-bd-v1.sha256");

fn set_time(path: &Path, secs: u64) {
    let time = std::time::UNIX_EPOCH + std::time::Duration::from_secs(secs);
    let mut options = fs::OpenOptions::new();
    if path.is_dir() {
        #[cfg(windows)]
        {
            use std::os::windows::fs::OpenOptionsExt;
            options.write(true).custom_flags(0x0200_0000); // FILE_FLAG_BACKUP_SEMANTICS
        }
        #[cfg(not(windows))]
        options.read(true);
    } else {
        options.write(true);
    }
    options.open(path).unwrap().set_modified(time).unwrap();
}

fn stamp_tree(dir: &Path, secs: u64) {
    for entry in fs::read_dir(dir).unwrap().flatten() {
        if entry.path().is_dir() {
            stamp_tree(&entry.path(), secs);
        } else {
            set_time(&entry.path(), secs);
        }
    }
    set_time(dir, secs);
}

#[test]
fn udf_vector() {
    let tmp = TempDir::new("udf-vector");
    let tree = tmp.path().join("tree");
    fs::create_dir_all(&tree).unwrap();
    bd_tree(&tree);
    stamp_tree(&tree, 1_700_000_000);
    let out = tmp.path().join("disc.iso");
    let request = MasterRequest {
        tree: &tree,
        output: &out,
        label: "Krouton vector",
        largest_file: 0,
        cancel: &AtomicBool::new(false),
    };
    master(&request, NOW, &mut |_| {}).unwrap();
    let image = fs::read(&out).unwrap();
    let hex: String = krsp::sha256::Sha256::digest(&[&image]).iter().map(|b| format!("{b:02x}")).collect();
    let line = format!("{hex}  udf-bd-v1: {} bytes\n", image.len());
    if std::env::var_os("KRSP_WRITE_UDF_VECTORS").is_some() {
        fs::write(UDF_VECTOR, &line).unwrap();
    }
    let stored = fs::read_to_string(UDF_VECTOR).expect("Vectors/udf-bd-v1.sha256 is missing").replace("\r\n", "\n");
    assert_eq!(stored, line, "the Blu-ray image no longer matches Vectors/udf-bd-v1.sha256");
}
