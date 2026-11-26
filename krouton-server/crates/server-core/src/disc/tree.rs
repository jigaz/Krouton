// MARK: - disc/tree.rs

//! The folder to master, read once into memory: every directory and file in breadth-first
//! order with names sorted, which kind of disc it is (data, DVD-Video or Blu-ray), and the order
//! file contents are laid out on the disc.

use super::ecma::cs0;
use std::cmp::Ordering;
use std::fs;
use std::path::{Path, PathBuf};
use std::sync::atomic::{AtomicBool, Ordering as AtomicOrdering};

/// What the folder is, which decides the file systems written.
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum Profile {
    /// Anything else: ISO 9660 + Joliet + UDF 2.01 (UDF 2.01 only with a file of 4 GiB or more).
    Data,
    /// A `VIDEO_TS` folder at the top: ISO 9660 + UDF 1.02, video files first and in order.
    DvdVideo,
    /// A `BDMV` folder at the top: UDF 2.50 with a metadata partition, as BD-ROM uses.
    BluRay,
}

#[derive(Clone, Debug, PartialEq, Eq)]
pub enum Kind {
    Dir { children: Vec<usize> },
    File { size: u64 },
}

#[derive(Clone, Debug)]
pub struct Node {
    pub name: String,
    pub source: PathBuf,
    pub parent: usize,
    /// Unix seconds.
    pub mtime: u64,
    pub kind: Kind,
}

impl Node {
    #[must_use]
    pub fn is_dir(&self) -> bool {
        matches!(self.kind, Kind::Dir { .. })
    }

    #[must_use]
    pub fn size(&self) -> u64 {
        match self.kind {
            Kind::File { size } => size,
            Kind::Dir { .. } => 0,
        }
    }

    #[must_use]
    pub fn children(&self) -> &[usize] {
        match &self.kind {
            Kind::Dir { children } => children,
            Kind::File { .. } => &[],
        }
    }
}

/// Node 0 is the root; every directory's children come after it.
#[derive(Clone, Debug)]
pub struct Tree {
    pub nodes: Vec<Node>,
}

impl Tree {
    /// Reads `root`. Links and special files are skipped (the bundle reader never creates them).
    ///
    /// # Errors
    /// A message for the user: an unreadable folder, a name UDF cannot hold, or `Cancelled`.
    pub fn scan(root: &Path, cancel: &AtomicBool) -> Result<Self, String> {
        let mtime = |m: &fs::Metadata| {
            m.modified().ok().and_then(|t| t.duration_since(std::time::UNIX_EPOCH).ok()).map_or(0, |d| d.as_secs())
        };
        let meta = fs::metadata(root).map_err(|e| format!("Could not read the folder: {e}"))?;
        let mut nodes = vec![Node {
            name: String::new(),
            source: root.to_path_buf(),
            parent: 0,
            mtime: mtime(&meta),
            kind: Kind::Dir { children: Vec::new() },
        }];
        let mut next = 0;
        while next < nodes.len() {
            if cancel.load(AtomicOrdering::SeqCst) {
                return Err("Cancelled".into());
            }
            if nodes[next].is_dir() {
                let dir = nodes[next].source.clone();
                let mut entries = Vec::new();
                for entry in fs::read_dir(&dir).map_err(|e| format!("Could not read {}: {e}", dir.display()))? {
                    let entry = entry.map_err(|e| format!("Could not read {}: {e}", dir.display()))?;
                    let name = entry
                        .file_name()
                        .into_string()
                        .map_err(|n| format!("{} is not a valid Unicode name", n.to_string_lossy()))?;
                    let meta = fs::symlink_metadata(entry.path()).map_err(|e| format!("Could not read {name}: {e}"))?;
                    let kind = if meta.is_dir() {
                        Kind::Dir { children: Vec::new() }
                    } else if meta.is_file() {
                        Kind::File { size: meta.len() }
                    } else {
                        continue;
                    };
                    if cs0(&name, usize::MAX).len() > 255 {
                        return Err(format!(
                            "“{name}” is too long a name for a disc (at most 254 Latin letters or 127 other characters)"
                        ));
                    }
                    entries.push(Node { name, source: entry.path(), parent: next, mtime: mtime(&meta), kind });
                }
                entries.sort_by(|a, b| a.name.cmp(&b.name));
                let first = nodes.len();
                let ids: Vec<usize> = (first..first + entries.len()).collect();
                nodes.extend(entries);
                nodes[next].kind = Kind::Dir { children: ids };
            }
            next += 1;
        }
        Ok(Self { nodes })
    }

    #[must_use]
    pub fn largest_file(&self) -> u64 {
        self.nodes.iter().map(Node::size).max().unwrap_or(0)
    }

    #[must_use]
    pub fn total_bytes(&self) -> u64 {
        self.nodes.iter().map(Node::size).sum()
    }

    /// The top-level directory called `name` (in any letter case).
    #[must_use]
    pub fn top_dir(&self, name: &str) -> Option<usize> {
        self.nodes[0]
            .children()
            .iter()
            .copied()
            .find(|&i| self.nodes[i].is_dir() && self.nodes[i].name.eq_ignore_ascii_case(name))
    }

    #[must_use]
    pub fn profile(&self) -> Profile {
        if self.top_dir("BDMV").is_some() {
            Profile::BluRay
        } else if self.top_dir("VIDEO_TS").is_some() {
            Profile::DvdVideo
        } else {
            Profile::Data
        }
    }

    /// `a/b/c`, for messages.
    #[must_use]
    pub fn path_of(&self, mut id: usize) -> String {
        let mut parts = Vec::new();
        while id != 0 {
            parts.push(self.nodes[id].name.as_str());
            id = self.nodes[id].parent;
        }
        parts.reverse();
        parts.join("/")
    }

    /// The order file contents are laid out. For DVD-Video, `VIDEO_TS` comes first in the order
    /// players expect (menu, then each title set's IFO, VOBs and BUP), one file after another.
    #[must_use]
    pub fn file_order(&self, profile: Profile) -> Vec<usize> {
        let mut first: Vec<usize> = Vec::new();
        if profile == Profile::DvdVideo
            && let Some(video) = self.top_dir("VIDEO_TS")
        {
            first = self.nodes[video].children().iter().copied().filter(|&i| !self.nodes[i].is_dir()).collect();
            first.sort_by(|&a, &b| dvd_order(&self.nodes[a].name, &self.nodes[b].name));
        }
        let rest = (0..self.nodes.len()).filter(|i| !self.nodes[*i].is_dir() && !first.contains(i));
        first.iter().copied().chain(rest).collect()
    }
}

/// Where a `VIDEO_TS` file goes: VIDEO_TS.IFO/VOB/BUP, then for each title set its IFO, menu
/// VOB, title VOBs 1–9 and BUP; anything else after them by name.
fn dvd_key(name: &str) -> (u8, u32, u8) {
    let upper = name.to_ascii_uppercase();
    let ext_rank = |ext: &str| match ext {
        "IFO" => Some(0u8),
        "VOB" => Some(1),
        "BUP" => Some(11),
        _ => None,
    };
    if let Some(rank) = upper.strip_prefix("VIDEO_TS.").and_then(ext_rank) {
        return (0, 0, if rank == 11 { 2 } else { rank });
    }
    // VTS_nn_p.EXT
    let bytes = upper.as_bytes();
    if bytes.len() == 12 && upper.starts_with("VTS_") && bytes[6] == b'_' && bytes[8] == b'.' {
        let title = upper[4..6].parse::<u32>().ok();
        let part = (bytes[7] as char).to_digit(10);
        if let (Some(title), Some(part), Some(rank)) = (title, part, ext_rank(&upper[9..])) {
            let sub = match rank {
                1 => 1 + u8::try_from(part).unwrap_or(9),
                other => other,
            };
            return (1, title, sub);
        }
    }
    (2, 0, 0)
}

fn dvd_order(a: &str, b: &str) -> Ordering {
    dvd_key(a).cmp(&dvd_key(b)).then_with(|| a.cmp(b))
}

// MARK: - Tests

#[cfg(test)]
#[allow(clippy::unwrap_used)]
mod tests {
    use super::*;
    use crate::testutil::TempDir;

    #[test]
    fn dvd_files_come_first_in_player_order() {
        let tmp = TempDir::new("disc-tree");
        let root = tmp.path();
        fs::create_dir_all(root.join("VIDEO_TS")).unwrap();
        fs::create_dir_all(root.join("AUDIO_TS")).unwrap();
        for name in [
            "VTS_01_0.BUP",
            "VTS_01_2.VOB",
            "VIDEO_TS.BUP",
            "VTS_01_1.VOB",
            "VTS_02_0.IFO",
            "VIDEO_TS.IFO",
            "VTS_01_0.VOB",
            "VIDEO_TS.VOB",
            "VTS_01_0.IFO",
            "VTS_02_1.VOB",
            "notes.txt",
        ] {
            fs::write(root.join("VIDEO_TS").join(name), name).unwrap();
        }
        fs::write(root.join("Extras.txt"), "x").unwrap();
        let tree = Tree::scan(root, &AtomicBool::new(false)).unwrap();
        assert_eq!(tree.profile(), Profile::DvdVideo);
        let names: Vec<_> = tree.file_order(Profile::DvdVideo).iter().map(|&i| tree.nodes[i].name.clone()).collect();
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
                "VTS_01_0.BUP",
                "VTS_02_0.IFO",
                "VTS_02_1.VOB",
                "notes.txt",
                "Extras.txt",
            ]
        );
        assert_eq!(tree.path_of(*tree.file_order(Profile::DvdVideo).first().unwrap()), "VIDEO_TS/VIDEO_TS.IFO");
    }

    #[test]
    fn profiles_and_name_limits() {
        let tmp = TempDir::new("disc-tree2");
        fs::create_dir_all(tmp.path().join("BDMV/STREAM")).unwrap();
        let tree = Tree::scan(tmp.path(), &AtomicBool::new(false)).unwrap();
        assert_eq!(tree.profile(), Profile::BluRay);
        assert_eq!(tree.nodes.len(), 3);
        let long = TempDir::new("disc-tree3");
        // One character outside Latin-1 makes every character take two bytes.
        fs::write(long.path().join(format!("ā{}", "a".repeat(200))), "").unwrap();
        assert!(Tree::scan(long.path(), &AtomicBool::new(false)).unwrap_err().contains("too long"));
    }
}
