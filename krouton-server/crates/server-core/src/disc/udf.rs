// MARK: - disc/udf.rs

//! UDF descriptors (ECMA-167 3rd edition as profiled by OSTA UDF 1.02, 2.01 and 2.50): the
//! volume recognition sequence, anchor, volume descriptor sequence, integrity descriptor, file
//! set descriptor, (extended) file entries and file identifier descriptors.

use super::ecma::{
    Civil, SECTOR_BYTES, charspec, cs0, dstring, finish_tag, implementation_id, put_u16, put_u32, put_u64, regid,
    udf_suffix,
};

/// The longest extent UDF allows that is still a whole number of blocks.
pub const MAX_EXTENT: u64 = 0x3FFF_F800;

/// Unique ID 0 is the root directory's and 1–15 are reserved.
pub const FIRST_UNIQUE_ID: u64 = 16;

pub mod file_type {
    pub const DIRECTORY: u8 = 4;
    pub const FILE: u8 = 5;
    pub const METADATA: u8 = 250;
    pub const METADATA_MIRROR: u8 = 251;
}

/// The UDF revision written, as BCD (0x0102, 0x0201, 0x0250).
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub struct Revision(pub u16);

impl Revision {
    pub const V1_02: Self = Self(0x0102);
    pub const V2_01: Self = Self(0x0201);
    pub const V2_50: Self = Self(0x0250);

    /// Descriptor tag version: 2 for ECMA-167 2nd edition (NSR02, UDF before 2.00), else 3.
    #[must_use]
    pub fn tag_version(self) -> u16 {
        if self.0 < 0x0200 { 2 } else { 3 }
    }

    #[must_use]
    pub fn nsr(self) -> &'static [u8; 5] {
        if self.0 < 0x0200 { b"NSR02" } else { b"NSR03" }
    }

    #[must_use]
    pub fn label(self) -> &'static str {
        match self.0 {
            0x0102 => "UDF 1.02",
            0x0201 => "UDF 2.01",
            _ => "UDF 2.50",
        }
    }
}

/// Volume-wide values.
#[derive(Clone, Debug)]
pub struct Volume {
    pub revision: Revision,
    pub label: String,
    pub created: Civil,
    /// 16 hexadecimal digits that tell this volume set from any other.
    pub set_id: String,
}

impl Volume {
    fn tag(&self, d: &mut [u8], identifier: u16, location: u32) {
        finish_tag(d, identifier, self.revision.tag_version(), location);
    }

    fn domain(&self) -> [u8; 32] {
        regid("*OSTA UDF Compliant", udf_suffix(self.revision.0))
    }
}

/// A `long_ad`: an extent anywhere in the logical volume, with the target's unique ID in the
/// implementation-use bytes (UDF 2.3.10.1).
#[derive(Clone, Copy, Debug, Default, PartialEq, Eq)]
pub struct LongAd {
    pub length: u32,
    pub block: u32,
    pub partition: u16,
    pub unique: u32,
}

impl LongAd {
    fn put(&self, d: &mut [u8], at: usize) {
        put_u32(d, at, self.length);
        put_u32(d, at + 4, self.block);
        put_u16(d, at + 8, self.partition);
        put_u32(d, at + 12, self.unique);
    }
}

/// Splits `bytes` starting at `block` into extents UDF can record: `(length, block)` pairs.
#[must_use]
pub fn extents(bytes: u64, block: u32) -> Vec<(u32, u32)> {
    let mut out = Vec::new();
    let (mut left, mut at) = (bytes, u64::from(block));
    while left > 0 {
        let take = left.min(MAX_EXTENT);
        out.push((u32::try_from(take).unwrap_or(0), u32::try_from(at).unwrap_or(0)));
        left -= take;
        at += take / 2048;
    }
    out
}

// MARK: - Recognition and anchor

/// One sector of the volume recognition sequence: `BEA01`, `NSR02`/`NSR03` or `TEA01`.
#[must_use]
pub fn recognition(identifier: &[u8; 5]) -> Vec<u8> {
    let mut d = vec![0u8; SECTOR_BYTES];
    d[1..6].copy_from_slice(identifier);
    d[6] = 1;
    d
}

/// Anchor volume descriptor pointer: where the main and reserve sequences are.
#[must_use]
pub fn anchor(v: &Volume, location: u32, main: (u32, u32), reserve: (u32, u32)) -> Vec<u8> {
    let mut d = vec![0u8; 512];
    put_u32(&mut d, 16, main.0);
    put_u32(&mut d, 20, main.1);
    put_u32(&mut d, 24, reserve.0);
    put_u32(&mut d, 28, reserve.1);
    v.tag(&mut d, 2, location);
    d
}

// MARK: - Volume descriptor sequence

#[must_use]
pub fn primary(v: &Volume, vdsn: u32, location: u32) -> Vec<u8> {
    let mut d = vec![0u8; 512];
    put_u32(&mut d, 16, vdsn);
    d[24..56].copy_from_slice(&dstring(&v.label, 32));
    put_u16(&mut d, 56, 1); // volume sequence number
    put_u16(&mut d, 58, 1);
    put_u16(&mut d, 60, 2); // interchange level: a single volume
    put_u16(&mut d, 62, 2);
    put_u32(&mut d, 64, 1); // character set list: CS0
    put_u32(&mut d, 68, 1);
    d[72..200].copy_from_slice(&dstring(&format!("{}{}", v.set_id, v.label), 128));
    d[200..264].copy_from_slice(&charspec());
    d[264..328].copy_from_slice(&charspec());
    d[344..376].copy_from_slice(&implementation_id());
    d[376..388].copy_from_slice(&v.created.udf());
    d[388..420].copy_from_slice(&implementation_id());
    v.tag(&mut d, 1, location);
    d
}

/// Implementation use volume descriptor with the "*UDF LV Info" the UDF spec requires.
#[must_use]
pub fn implementation_use(v: &Volume, vdsn: u32, location: u32) -> Vec<u8> {
    let mut d = vec![0u8; 512];
    put_u32(&mut d, 16, vdsn);
    d[20..52].copy_from_slice(&regid("*UDF LV Info", udf_suffix(v.revision.0)));
    d[52..116].copy_from_slice(&charspec());
    d[116..244].copy_from_slice(&dstring(&v.label, 128));
    d[352..384].copy_from_slice(&implementation_id());
    v.tag(&mut d, 4, location);
    d
}

/// The one physical partition, read-only, so it needs no free-space bitmap.
#[must_use]
pub fn partition(v: &Volume, vdsn: u32, location: u32, start: u32, length: u32) -> Vec<u8> {
    let mut d = vec![0u8; 512];
    put_u32(&mut d, 16, vdsn);
    put_u16(&mut d, 20, 1); // allocated
    put_u16(&mut d, 22, 0); // partition number
    let mut nsr = String::from("+");
    nsr.push_str(std::str::from_utf8(v.revision.nsr()).unwrap_or("NSR03"));
    d[24..56].copy_from_slice(&regid(&nsr, [0; 8]));
    put_u32(&mut d, 184, 1); // access type: read only
    put_u32(&mut d, 188, start);
    put_u32(&mut d, 192, length);
    d[196..228].copy_from_slice(&implementation_id());
    v.tag(&mut d, 5, location);
    d
}

/// Where a UDF 2.50 metadata partition's files are, in blocks of the physical partition.
#[derive(Clone, Copy, Debug)]
pub struct MetadataMap {
    pub file: u32,
    pub mirror: u32,
    pub alignment: u16,
}

/// Logical volume descriptor: block size, domain, where the file set is, and the partition maps
/// (a type 1 map for the physical partition, plus a metadata map for UDF 2.50).
#[must_use]
pub fn logical_volume(
    v: &Volume,
    vdsn: u32,
    location: u32,
    file_set: LongAd,
    integrity: (u32, u32),
    metadata: Option<MetadataMap>,
) -> Vec<u8> {
    let mut maps = vec![1u8, 6, 1, 0, 0, 0]; // type 1: volume 1, partition 0
    if let Some(m) = metadata {
        let mut map = vec![0u8; 64];
        map[0] = 2;
        map[1] = 64;
        map[4..36].copy_from_slice(&regid("*UDF Metadata Partition", udf_suffix(v.revision.0)));
        put_u16(&mut map, 36, 1);
        put_u16(&mut map, 38, 0);
        put_u32(&mut map, 40, m.file);
        put_u32(&mut map, 44, m.mirror);
        put_u32(&mut map, 48, u32::MAX); // no bitmap: the partition is read-only
        put_u32(&mut map, 52, u32::from(m.alignment)); // allocation unit
        put_u16(&mut map, 56, m.alignment);
        map[58] = 1; // the mirror holds its own copy
        maps.extend(map);
    }
    let mut d = vec![0u8; 440 + maps.len()];
    put_u32(&mut d, 16, vdsn);
    d[20..84].copy_from_slice(&charspec());
    d[84..212].copy_from_slice(&dstring(&v.label, 128));
    put_u32(&mut d, 212, 2048);
    d[216..248].copy_from_slice(&v.domain());
    file_set.put(&mut d, 248);
    put_u32(&mut d, 264, u32::try_from(maps.len()).unwrap_or(0));
    put_u32(&mut d, 268, if metadata.is_some() { 2 } else { 1 });
    d[272..304].copy_from_slice(&implementation_id());
    put_u32(&mut d, 432, integrity.0);
    put_u32(&mut d, 436, integrity.1);
    d[440..].copy_from_slice(&maps);
    v.tag(&mut d, 6, location);
    d
}

/// Unallocated space descriptor: none, as nothing on a finished disc is free.
#[must_use]
pub fn unallocated_space(v: &Volume, vdsn: u32, location: u32) -> Vec<u8> {
    let mut d = vec![0u8; 24];
    put_u32(&mut d, 16, vdsn);
    v.tag(&mut d, 7, location);
    d
}

#[must_use]
pub fn terminating(v: &Volume, location: u32) -> Vec<u8> {
    let mut d = vec![0u8; 512];
    v.tag(&mut d, 8, location);
    d
}

/// Closed logical volume integrity descriptor: partition sizes, counts and revisions.
#[must_use]
pub fn integrity(
    v: &Volume,
    location: u32,
    partition_sizes: &[u32],
    next_unique: u64,
    files: u32,
    dirs: u32,
) -> Vec<u8> {
    let n = partition_sizes.len();
    let mut d = vec![0u8; 80 + 8 * n + 46];
    d[16..28].copy_from_slice(&v.created.udf());
    put_u32(&mut d, 28, 1); // close
    put_u64(&mut d, 40, next_unique);
    put_u32(&mut d, 72, u32::try_from(n).unwrap_or(0));
    put_u32(&mut d, 76, 46);
    for (i, size) in partition_sizes.iter().enumerate() {
        put_u32(&mut d, 80 + 4 * i, 0); // free space
        put_u32(&mut d, 80 + 4 * n + 4 * i, *size);
    }
    let iu = 80 + 8 * n;
    d[iu..iu + 32].copy_from_slice(&implementation_id());
    put_u32(&mut d, iu + 32, files);
    put_u32(&mut d, iu + 36, dirs);
    put_u16(&mut d, iu + 40, v.revision.0); // minimum read revision
    put_u16(&mut d, iu + 42, v.revision.0); // minimum write revision
    put_u16(&mut d, iu + 44, v.revision.0); // maximum write revision
    v.tag(&mut d, 9, location);
    d
}

// MARK: - File set

#[must_use]
pub fn file_set(v: &Volume, location: u32, root: LongAd) -> Vec<u8> {
    let mut d = vec![0u8; 512];
    d[16..28].copy_from_slice(&v.created.udf());
    put_u16(&mut d, 28, 3);
    put_u16(&mut d, 30, 3);
    put_u32(&mut d, 32, 1);
    put_u32(&mut d, 36, 1);
    d[48..112].copy_from_slice(&charspec());
    d[112..240].copy_from_slice(&dstring(&v.label, 128));
    d[240..304].copy_from_slice(&charspec());
    d[304..336].copy_from_slice(&dstring(&v.label, 32));
    root.put(&mut d, 400);
    d[416..448].copy_from_slice(&v.domain());
    v.tag(&mut d, 256, location);
    d
}

// MARK: - Files

/// Allocation descriptors: `short_ad` for extents in the entry's own partition, `long_ad`
/// (UDF 2.50 file data, which lives outside the metadata partition) otherwise.
#[derive(Clone, Debug, PartialEq, Eq)]
pub enum Allocation {
    Short(Vec<(u32, u32)>),
    Long(Vec<LongAd>),
}

/// What a file entry describes.
#[derive(Clone, Debug)]
pub struct Entry {
    pub file_type: u8,
    pub unique: u64,
    pub length: u64,
    pub links: u16,
    pub modified: Civil,
    pub allocation: Allocation,
}

/// A file entry, or (for UDF 2.50) an extended file entry.
///
/// # Errors
/// The file is so fragmented its descriptors would not fit one block.
pub fn file_entry(v: &Volume, location: u32, extended: bool, e: &Entry) -> Result<Vec<u8>, String> {
    let (ads, kind) = match &e.allocation {
        Allocation::Short(list) => {
            let mut b = Vec::with_capacity(8 * list.len());
            for (len, pos) in list {
                b.extend_from_slice(&len.to_le_bytes());
                b.extend_from_slice(&pos.to_le_bytes());
            }
            (b, 0u16)
        }
        Allocation::Long(list) => {
            let mut b = vec![0u8; 16 * list.len()];
            for (i, ad) in list.iter().enumerate() {
                ad.put(&mut b, 16 * i);
            }
            (b, 1u16)
        }
    };
    let head = if extended { 216 } else { 176 };
    if head + ads.len() > SECTOR_BYTES {
        return Err("A file is too large for one disc entry".into());
    }
    let blocks: u64 = e.length.div_ceil(2048);
    let mut d = vec![0u8; head + ads.len()];
    // ICB tag: strategy 4, one entry, file type, allocation descriptor type.
    put_u16(&mut d, 20, 4);
    put_u16(&mut d, 24, 1);
    d[27] = e.file_type;
    put_u16(&mut d, 34, kind);
    put_u32(&mut d, 36, u32::MAX); // uid: not specified
    put_u32(&mut d, 40, u32::MAX); // gid
    let read = 0x1084u32; // read for owner, group and others
    let search = if e.file_type == file_type::DIRECTORY { 0x0421 } else { 0 };
    put_u32(&mut d, 44, read | search);
    put_u16(&mut d, 48, e.links);
    put_u64(&mut d, 56, e.length);
    let time = e.modified.udf();
    if extended {
        put_u64(&mut d, 64, e.length); // object size
        put_u64(&mut d, 72, blocks);
        for at in [80, 92, 104, 116] {
            d[at..at + 12].copy_from_slice(&time);
        }
        put_u32(&mut d, 128, 1); // checkpoint
        d[168..200].copy_from_slice(&implementation_id());
        put_u64(&mut d, 200, e.unique);
        put_u32(&mut d, 212, u32::try_from(ads.len()).unwrap_or(0));
    } else {
        put_u64(&mut d, 64, blocks);
        for at in [72, 84, 96] {
            d[at..at + 12].copy_from_slice(&time);
        }
        put_u32(&mut d, 108, 1);
        d[128..160].copy_from_slice(&implementation_id());
        put_u64(&mut d, 160, e.unique);
        put_u32(&mut d, 172, u32::try_from(ads.len()).unwrap_or(0));
    }
    d[head..].copy_from_slice(&ads);
    v.tag(&mut d, if extended { 266 } else { 261 }, location);
    Ok(d)
}

/// Characteristics bits of a file identifier descriptor.
pub const FID_DIRECTORY: u8 = 0x02;
pub const FID_PARENT: u8 = 0x08;

/// Recorded length of a file identifier descriptor whose name takes `name_bytes` bytes of CS0.
#[must_use]
pub fn fid_len(name_bytes: usize) -> usize {
    (38 + name_bytes).next_multiple_of(4)
}

/// The CS0 bytes of a file name, as a FID records it.
#[must_use]
pub fn fid_name(name: &str) -> Vec<u8> {
    cs0(name, 255)
}

/// One file identifier descriptor; `location` is the block its first byte falls in.
#[must_use]
pub fn fid(v: &Volume, location: u32, characteristics: u8, name: &[u8], icb: LongAd) -> Vec<u8> {
    let mut d = vec![0u8; fid_len(name.len())];
    put_u16(&mut d, 16, 1); // file version number
    d[18] = characteristics;
    d[19] = u8::try_from(name.len()).unwrap_or(0);
    icb.put(&mut d, 20);
    d[38..38 + name.len()].copy_from_slice(name);
    v.tag(&mut d, 257, location);
    d
}

// MARK: - Tests

#[cfg(test)]
#[allow(clippy::unwrap_used)]
mod tests {
    use super::*;

    fn volume(revision: Revision) -> Volume {
        Volume { revision, label: "Holiday".into(), created: Civil::from_unix(0), set_id: "0123456789ABCDEF".into() }
    }

    #[test]
    fn extents_split_at_the_udf_limit() {
        assert_eq!(extents(0, 9), vec![]);
        assert_eq!(extents(5000, 9), vec![(5000, 9)]);
        let big = extents(MAX_EXTENT + 4096, 100);
        assert_eq!(big, vec![(0x3FFF_F800, 100), (4096, 100 + 0x7FFFF)]);
    }

    #[test]
    fn descriptors_have_the_right_sizes_and_tags() {
        let v = volume(Revision::V2_50);
        let lvd = logical_volume(
            &v,
            3,
            35,
            LongAd::default(),
            (4096, 64),
            Some(MetadataMap { file: 0, mirror: 1, alignment: 32 }),
        );
        assert_eq!(lvd.len(), 440 + 70);
        assert_eq!(u16::from_le_bytes([lvd[10], lvd[11]]), 494);
        assert_eq!(&lvd[440 + 6 + 5..440 + 6 + 28], b"*UDF Metadata Partition");
        let lvid = integrity(&v, 64, &[100, 32], 20, 3, 2);
        assert_eq!(lvid.len(), 80 + 16 + 46);
        let entry = Entry {
            file_type: file_type::FILE,
            unique: 16,
            length: 5000,
            links: 1,
            modified: v.created,
            allocation: Allocation::Long(vec![LongAd { length: 5000, block: 7, partition: 0, unique: 0 }]),
        };
        let efe = file_entry(&v, 2, true, &entry).unwrap();
        assert_eq!((efe.len(), u16::from_le_bytes([efe[0], efe[1]]), efe[2]), (232, 266, 3));
        let fe = file_entry(
            &volume(Revision::V1_02),
            2,
            false,
            &Entry { allocation: Allocation::Short(vec![(5000, 7)]), ..entry },
        )
        .unwrap();
        assert_eq!((fe.len(), u16::from_le_bytes([fe[0], fe[1]]), fe[2]), (184, 261, 2));
        let f = fid(&v, 9, 0, &fid_name("a.txt"), LongAd::default());
        assert_eq!(f.len(), 44);
        assert_eq!(f[19], 6);
    }
}
