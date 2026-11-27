// MARK: - disc/iso.rs

//! The ISO 9660 side of a bridge disc (ECMA-119), and its Joliet supplement: names, directory
//! extents, path tables and volume descriptors. File contents are shared with UDF, so only the
//! directories here take space of their own.

use super::ecma::{Civil, SECTOR, SECTOR_BYTES, iso_volume_unset, put_both_u16, put_both_u32, put_u32};
use super::tree::Tree;
use std::collections::HashSet;

/// Which namespace a [`Names`] describes.
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum Flavor {
    /// Upper-case `NAME.EXT;1`, 8.3 at level 1 (DVD-Video), up to 30 characters at level 2.
    Iso { level1: bool },
    /// UCS-2 names of up to 64 characters.
    Joliet,
}

/// One namespace's names and the sizes they lead to.
#[derive(Clone, Debug)]
pub struct Names {
    pub flavor: Flavor,
    /// Recorded identifier bytes for every node (empty for the root).
    pub ids: Vec<Vec<u8>>,
    /// Every directory's children in recorded order.
    pub order: Vec<Vec<usize>>,
    /// Directories in path-table order (the root first).
    pub path_order: Vec<usize>,
    /// Bytes of each directory's extent (whole sectors; 0 for files).
    pub dir_bytes: Vec<u64>,
    pub path_table_bytes: u64,
}

impl Names {
    #[must_use]
    pub fn plan(tree: &Tree, flavor: Flavor) -> Self {
        let count = tree.nodes.len();
        let mut ids = vec![Vec::new(); count];
        let mut order = vec![Vec::new(); count];
        for (dir, node) in tree.nodes.iter().enumerate().filter(|(_, n)| n.is_dir()) {
            let mut used = HashSet::new();
            for &child in node.children() {
                let c = &tree.nodes[child];
                ids[child] = match flavor {
                    Flavor::Iso { level1 } => iso_id(&c.name, c.is_dir(), level1, &mut used),
                    Flavor::Joliet => joliet_id(&c.name, &mut used),
                };
            }
            let mut children = node.children().to_vec();
            children.sort_by(|&a, &b| sort_key(&ids[a], flavor).cmp(&sort_key(&ids[b], flavor)));
            order[dir] = children;
        }
        let mut path_order = vec![0];
        let mut at = 0;
        while at < path_order.len() {
            let dir = path_order[at];
            path_order.extend(order[dir].iter().copied().filter(|&c| tree.nodes[c].is_dir()));
            at += 1;
        }
        let mut dir_bytes = vec![0; count];
        for &dir in &path_order {
            let mut used = 0u64;
            let mut size = SECTOR;
            for len in [34u64, 34].into_iter().chain(order[dir].iter().map(|&c| record_len(ids[c].len()))) {
                if used + len > SECTOR {
                    size += SECTOR;
                    used = 0;
                }
                used += len;
            }
            dir_bytes[dir] = size;
        }
        let path_table_bytes =
            path_order.iter().map(|&d| if d == 0 { 10 } else { path_record_len(ids[d].len()) }).sum();
        Self { flavor, ids, order, path_order, dir_bytes, path_table_bytes }
    }

    /// The extents of every directory, in path-table order. `dir_sector` gives each
    /// directory's first sector, `file_sector` each file's (0 for an empty file).
    #[must_use]
    pub fn directories(&self, tree: &Tree, dir_sector: &[u32], file_sector: &[u32]) -> Vec<(u32, Vec<u8>)> {
        let mut out = Vec::new();
        for &dir in &self.path_order {
            let node = &tree.nodes[dir];
            let mut extent = vec![0u8; usize::try_from(self.dir_bytes[dir]).unwrap_or(0)];
            let date = Civil::from_unix(node.mtime).iso_record();
            let me = self.record(&[0], dir_sector[dir], self.dir_bytes[dir], true, date);
            let parent = node.parent;
            let up = self.record(
                &[1],
                dir_sector[parent],
                self.dir_bytes[parent],
                true,
                Civil::from_unix(tree.nodes[parent].mtime).iso_record(),
            );
            let mut at = 0usize;
            let records = [me, up].into_iter().chain(self.order[dir].iter().map(|&c| {
                let n = &tree.nodes[c];
                let (location, size) =
                    if n.is_dir() { (dir_sector[c], self.dir_bytes[c]) } else { (file_sector[c], n.size()) };
                self.record(&self.ids[c], location, size, n.is_dir(), Civil::from_unix(n.mtime).iso_record())
            }));
            for record in records {
                if at % SECTOR_BYTES + record.len() > SECTOR_BYTES {
                    at = at.next_multiple_of(SECTOR_BYTES);
                }
                extent[at..at + record.len()].copy_from_slice(&record);
                at += record.len();
            }
            out.push((dir_sector[dir], extent));
        }
        out
    }

    fn record(&self, id: &[u8], location: u32, size: u64, is_dir: bool, date: [u8; 7]) -> Vec<u8> {
        let len = usize::try_from(record_len(id.len())).unwrap_or(34);
        let mut r = vec![0u8; len];
        r[0] = u8::try_from(len).unwrap_or(0);
        put_both_u32(&mut r, 2, location);
        put_both_u32(&mut r, 10, u32::try_from(size).unwrap_or(u32::MAX));
        r[18..25].copy_from_slice(&date);
        r[25] = if is_dir { 2 } else { 0 };
        put_both_u16(&mut r, 28, 1);
        r[32] = u8::try_from(id.len()).unwrap_or(0);
        r[33..33 + id.len()].copy_from_slice(id);
        r
    }

    /// The little-endian (type L) and big-endian (type M) path tables.
    #[must_use]
    pub fn path_tables(&self, tree: &Tree, dir_sector: &[u32]) -> (Vec<u8>, Vec<u8>) {
        let mut number = vec![0u16; self.ids.len()];
        let (mut l, mut m) = (Vec::new(), Vec::new());
        for (index, &dir) in self.path_order.iter().enumerate() {
            number[dir] = u16::try_from(index + 1).unwrap_or(u16::MAX);
            let id: &[u8] = if dir == 0 { &[0] } else { &self.ids[dir] };
            let parent = if dir == 0 { 1 } else { number[tree.nodes[dir].parent] };
            for (table, big) in [(&mut l, false), (&mut m, true)] {
                table.push(u8::try_from(id.len()).unwrap_or(0));
                table.push(0);
                let (loc, par) = if big {
                    (dir_sector[dir].to_be_bytes(), parent.to_be_bytes())
                } else {
                    (dir_sector[dir].to_le_bytes(), parent.to_le_bytes())
                };
                table.extend_from_slice(&loc);
                table.extend_from_slice(&par);
                table.extend_from_slice(id);
                if id.len() % 2 == 1 {
                    table.push(0);
                }
            }
        }
        (l, m)
    }

    /// The primary (ISO) or supplementary (Joliet) volume descriptor.
    #[must_use]
    pub fn volume_descriptor(&self, volume: &Volume<'_>, root_sector: u32, l_table: u32, m_table: u32) -> Vec<u8> {
        let joliet = self.flavor == Flavor::Joliet;
        let mut d = vec![0u8; SECTOR_BYTES];
        d[0] = if joliet { 2 } else { 1 };
        d[1..6].copy_from_slice(b"CD001");
        d[6] = 1;
        let text = |d: &mut [u8], at: usize, width: usize, value: &str| {
            if joliet {
                let mut units = value.encode_utf16().flat_map(u16::to_be_bytes).collect::<Vec<_>>();
                units.truncate(width & !1);
                units.resize(width & !1, 0);
                for pair in units.chunks_mut(2).skip(value.encode_utf16().count()) {
                    pair.copy_from_slice(&[0, 0x20]);
                }
                d[at..at + (width & !1)].copy_from_slice(&units);
                if width % 2 == 1 {
                    d[at + width - 1] = 0x20;
                }
            } else {
                let bytes = value.as_bytes();
                for i in 0..width {
                    d[at + i] = bytes.get(i).copied().unwrap_or(b' ');
                }
            }
        };
        text(&mut d, 8, 32, "");
        let name = if joliet { volume.joliet_name } else { volume.iso_name };
        text(&mut d, 40, 32, name);
        put_both_u32(&mut d, 80, volume.sectors);
        if joliet {
            d[88..91].copy_from_slice(b"%/E"); // UCS-2 level 3
        }
        put_both_u16(&mut d, 120, 1);
        put_both_u16(&mut d, 124, 1);
        put_both_u16(&mut d, 128, 2048);
        put_both_u32(&mut d, 132, u32::try_from(self.path_table_bytes).unwrap_or(0));
        put_u32(&mut d, 140, l_table);
        d[148..152].copy_from_slice(&m_table.to_be_bytes());
        let root = self.record(&[0], root_sector, self.dir_bytes[0], true, volume.created.iso_record());
        d[156..190].copy_from_slice(&root);
        text(&mut d, 190, 128, "");
        text(&mut d, 318, 128, "");
        text(&mut d, 446, 128, "");
        text(&mut d, 574, 128, if joliet { "Krouton Server" } else { "KROUTON SERVER" });
        for at in [702, 739, 776] {
            text(&mut d, at, 37, "");
        }
        d[813..830].copy_from_slice(&volume.created.iso_volume());
        d[830..847].copy_from_slice(&volume.created.iso_volume());
        d[847..864].copy_from_slice(&iso_volume_unset());
        d[864..881].copy_from_slice(&iso_volume_unset());
        d[881] = 1;
        d
    }
}

/// Volume-wide values for the descriptors.
#[derive(Clone, Copy, Debug)]
pub struct Volume<'a> {
    pub iso_name: &'a str,
    pub joliet_name: &'a str,
    pub sectors: u32,
    pub created: Civil,
}

/// The descriptor-set terminator that ends the ISO 9660 descriptors.
#[must_use]
pub fn terminator() -> Vec<u8> {
    let mut d = vec![0u8; SECTOR_BYTES];
    d[0] = 255;
    d[1..6].copy_from_slice(b"CD001");
    d[6] = 1;
    d
}

fn record_len(id_len: usize) -> u64 {
    let len = 33 + id_len;
    (len + len % 2) as u64
}

fn path_record_len(id_len: usize) -> u64 {
    (8 + id_len + id_len % 2) as u64
}

fn sort_key(id: &[u8], flavor: Flavor) -> (Vec<u8>, Vec<u8>) {
    match flavor {
        Flavor::Iso { .. } => {
            let text = id.split(|&b| b == b';').next().unwrap_or(id);
            let mut parts = text.splitn(2, |&b| b == b'.');
            (parts.next().unwrap_or(&[]).to_vec(), parts.next().unwrap_or(&[]).to_vec())
        }
        Flavor::Joliet => (id.to_vec(), Vec::new()),
    }
}

// MARK: - Names

fn d_chars(text: &str) -> String {
    text.chars().map(|c| if c.is_ascii_alphanumeric() { c.to_ascii_uppercase() } else { '_' }).collect()
}

fn iso_id(name: &str, is_dir: bool, level1: bool, used: &mut HashSet<String>) -> Vec<u8> {
    let (base_limit, ext_limit, total) = match (is_dir, level1) {
        (true, true) => (8, 0, 8),
        (true, false) => (31, 0, 31),
        (false, true) => (8, 3, 11),
        (false, false) => (30, 30, 30),
    };
    let (base, ext) = match name.rfind('.') {
        Some(dot) if !is_dir && dot > 0 => (d_chars(&name[..dot]), d_chars(&name[dot + 1..])),
        _ => (d_chars(name), String::new()),
    };
    let ext: String = ext.chars().take(ext_limit).collect();
    let room = base_limit.min(total - ext.len()).max(1);
    let mut stem: String = base.chars().take(room).collect();
    if stem.is_empty() {
        stem.push('_');
    }
    let mut candidate = stem.clone();
    let mut n = 1u32;
    while !used.insert(format!("{candidate}.{ext}")) {
        let tag = format!("~{n}");
        candidate = format!("{}{tag}", stem.chars().take(room.saturating_sub(tag.len()).max(1)).collect::<String>());
        n += 1;
    }
    if is_dir { candidate.into_bytes() } else { format!("{candidate}.{ext};1").into_bytes() }
}

fn joliet_id(name: &str, used: &mut HashSet<String>) -> Vec<u8> {
    let clean: Vec<u16> = name
        .chars()
        .map(|c| if c.is_control() || "*/:;?\\".contains(c) || u32::from(c) > 0xFFFF { '_' } else { c })
        .collect::<String>()
        .encode_utf16()
        .collect();
    let dot = clean.iter().rposition(|&u| u == u16::from(b'.')).filter(|&d| d > 0 && clean.len() - d <= 11);
    let (stem, ext) = dot.map_or((clean.as_slice(), &[][..]), |d| (&clean[..d], &clean[d..]));
    let fit = |stem: &[u16], tag: &[u16]| -> Vec<u16> {
        let room = 64 - ext.len() - tag.len();
        stem.iter().take(room).chain(tag).chain(ext).copied().collect()
    };
    let mut candidate = fit(stem, &[]);
    let mut n = 1u32;
    while !used.insert(String::from_utf16_lossy(&candidate).to_lowercase()) {
        let tag: Vec<u16> = format!("~{n}").encode_utf16().collect();
        candidate = fit(stem, &tag);
        n += 1;
    }
    candidate.iter().flat_map(|u| u.to_be_bytes()).collect()
}

// MARK: - Tests

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn iso_names_are_upper_case_unique_and_short() {
        let mut used = HashSet::new();
        assert_eq!(iso_id("VIDEO_TS.IFO", false, true, &mut used), b"VIDEO_TS.IFO;1");
        assert_eq!(iso_id("Fotos – Ünïcode", true, false, &mut used), b"FOTOS____N_CODE");
        assert_eq!(iso_id("readme", false, false, &mut used), b"README.;1");
        assert_eq!(iso_id("ReadMe", false, false, &mut used), b"README~1.;1");
        let long = iso_id(&format!("{}.jpeg", "x".repeat(60)), false, false, &mut used);
        assert_eq!(long.len(), 30 + 1 + 2);
        assert!(long.ends_with(b".JPEG;1"));
        let mut dvd = HashSet::new();
        assert_eq!(iso_id("holiday-video.mpeg", false, true, &mut dvd), b"HOLIDAY_.MPE;1");
    }

    #[test]
    fn joliet_names_keep_unicode_and_extensions() {
        let mut used = HashSet::new();
        let id = joliet_id("Fotos – Ünïcode", &mut used);
        assert_eq!(
            String::from_utf16_lossy(&id.chunks(2).map(|p| u16::from_be_bytes([p[0], p[1]])).collect::<Vec<_>>()),
            "Fotos – Ünïcode"
        );
        let long = joliet_id(&format!("{}.jpeg", "y".repeat(100)), &mut used);
        assert_eq!(long.len(), 128);
        let again = joliet_id(&format!("{}.JPEG", "Y".repeat(100)), &mut used);
        let text =
            String::from_utf16_lossy(&again.chunks(2).map(|p| u16::from_be_bytes([p[0], p[1]])).collect::<Vec<_>>());
        assert!(text.ends_with("~1.JPEG"), "{text}");
        assert_eq!(
            joliet_id("a:b?.txt", &mut used),
            "a_b_.txt".encode_utf16().flat_map(u16::to_be_bytes).collect::<Vec<_>>()
        );
    }
}
