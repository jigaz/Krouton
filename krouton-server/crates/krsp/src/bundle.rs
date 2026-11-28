// MARK: - bundle.rs

//! KRSP bundle v1: how a client sends a folder (rather than a finished disc image) for the
//! server to master. A bundle is a strict subset of the POSIX ustar/pax tar format, so `tar -tvf`
//! can list one, but the reader accepts nothing it does not need:
//!
//! * Entries are directories (`5`) and regular files (`0`). Links, devices, FIFOs, GNU long
//!   names and global pax headers are rejected.
//! * A local pax header (`x`) may carry `path`, `size` and `mtime` for the entry that follows;
//!   the writer emits one only when the name is not short printable ASCII, or the file is 8 GiB
//!   or larger.
//! * Every path must pass [`validate_path`]: relative, UTF-8, no `.`/`..`, and nothing that
//!   cannot be a file name on Windows, macOS and a disc. Clients check the same rules first
//!   (`Vectors/krsp-bundle-names-v1.txt` pins them for the Swift app).
//! * The archive ends with two zero blocks, then zero padding to a multiple of 2048 bytes so it
//!   travels through the normal resumable upload.
//!
//! The writer is deterministic (owner 0, empty user names, fixed modes), so
//! `Vectors/krsp-bundle-v1.tar` is byte-identical between the Rust and Swift writers.

use std::fmt;
use std::io::{self, Read, Write};

/// tar block size.
pub const BLOCK: u64 = 512;
/// Bundles are padded to whole 2048-byte sectors for the upload.
pub const SECTOR: u64 = 2048;
/// Longest path, in UTF-8 bytes.
pub const MAX_PATH_BYTES: usize = 1024;
/// Longest single name, in UTF-8 bytes.
pub const MAX_NAME_BYTES: usize = 255;
/// Deepest nesting, counting the file itself.
pub const MAX_DEPTH: usize = 64;
/// Largest pax header the reader accepts.
pub const MAX_PAX_BYTES: u64 = 64 * 1024;

const OCTAL_SIZE_LIMIT: u64 = 0o777_7777_7777; // 11 octal digits
const PAX_NAME: &str = "././@PaxHeader";

// MARK: - Names

/// Why a path cannot go on a disc.
#[derive(Clone, Debug, PartialEq, Eq)]
pub enum NameError {
    Empty,
    TooLong,
    NameTooLong(String),
    TooDeep,
    Absolute,
    DotSegment,
    ForbiddenCharacter { name: String, character: char },
    TrailingDotOrSpace(String),
    ReservedName(String),
}

impl fmt::Display for NameError {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        match self {
            Self::Empty => write!(f, "an empty name"),
            Self::TooLong => write!(f, "a path longer than {MAX_PATH_BYTES} bytes"),
            Self::NameTooLong(n) => write!(f, "“{n}” is longer than {MAX_NAME_BYTES} bytes"),
            Self::TooDeep => write!(f, "folders nested deeper than {MAX_DEPTH} levels"),
            Self::Absolute => write!(f, "an absolute path"),
            Self::DotSegment => write!(f, "a “.” or “..” path segment"),
            Self::ForbiddenCharacter { name, character } => {
                write!(f, "“{name}” contains {}", describe_char(*character))
            }
            Self::TrailingDotOrSpace(n) => write!(f, "“{n}” ends with a dot or a space"),
            Self::ReservedName(n) => write!(f, "“{n}” is a reserved device name on Windows"),
        }
    }
}

fn describe_char(c: char) -> String {
    if c.is_control() { format!("a control character (U+{:04X})", u32::from(c)) } else { format!("“{c}”") }
}

/// Checks one bundle path (`/`-separated, no leading or trailing `/`).
///
/// # Errors
/// The first rule the path breaks.
pub fn validate_path(path: &str) -> Result<(), NameError> {
    if path.is_empty() {
        return Err(NameError::Empty);
    }
    if path.len() > MAX_PATH_BYTES {
        return Err(NameError::TooLong);
    }
    if path.starts_with('/') {
        return Err(NameError::Absolute);
    }
    let mut depth = 0;
    for name in path.split('/') {
        depth += 1;
        validate_name(name)?;
    }
    if depth > MAX_DEPTH {
        return Err(NameError::TooDeep);
    }
    Ok(())
}

/// Checks a single file or folder name.
///
/// # Errors
/// The first rule the name breaks.
pub fn validate_name(name: &str) -> Result<(), NameError> {
    if name.is_empty() {
        return Err(NameError::Empty);
    }
    if name == "." || name == ".." {
        return Err(NameError::DotSegment);
    }
    if name.len() > MAX_NAME_BYTES {
        return Err(NameError::NameTooLong(name.to_owned()));
    }
    if let Some(character) = name.chars().find(|c| c.is_control() || "\\/:*?\"<>|".contains(*c)) {
        return Err(NameError::ForbiddenCharacter { name: name.to_owned(), character });
    }
    if name.ends_with('.') || name.ends_with(' ') {
        return Err(NameError::TrailingDotOrSpace(name.to_owned()));
    }
    let stem = name.split('.').next().unwrap_or(name).trim_end().to_ascii_uppercase();
    let reserved = matches!(stem.as_str(), "CON" | "PRN" | "AUX" | "NUL")
        || ((stem.starts_with("COM") || stem.starts_with("LPT"))
            && stem.len() == 4
            && stem.as_bytes().get(3).is_some_and(|d| (b'1'..=b'9').contains(d)));
    if reserved {
        return Err(NameError::ReservedName(name.to_owned()));
    }
    Ok(())
}

/// The key two paths collide on when the disc (or the server's file system) ignores case.
#[must_use]
pub fn collision_key(path: &str) -> String {
    path.to_lowercase()
}

// MARK: - Writer

/// Streams a bundle. Call [`BundleWriter::directory`] for a folder before anything inside it.
#[derive(Debug)]
pub struct BundleWriter<W: Write> {
    out: W,
    written: u64,
}

impl<W: Write> BundleWriter<W> {
    pub fn new(out: W) -> Self {
        Self { out, written: 0 }
    }

    /// Bytes written so far.
    #[must_use]
    pub fn written(&self) -> u64 {
        self.written
    }

    /// # Errors
    /// An invalid path, or a write error.
    pub fn directory(&mut self, path: &str, mtime: u64) -> io::Result<()> {
        validate_path(path).map_err(invalid)?;
        self.header(&format!("{path}/"), b'5', 0o755, 0, mtime)
    }

    /// Writes a file of exactly `size` bytes read from `data`.
    ///
    /// # Errors
    /// An invalid path, a short read, or a write error.
    pub fn file(&mut self, path: &str, size: u64, mtime: u64, data: &mut dyn Read) -> io::Result<()> {
        validate_path(path).map_err(invalid)?;
        self.header(path, b'0', 0o644, size, mtime)?;
        let copied = io::copy(&mut data.take(size), &mut self.out)?;
        if copied != size {
            return Err(io::Error::new(io::ErrorKind::UnexpectedEof, format!("{path} changed while it was read")));
        }
        self.written += size;
        self.pad_to(BLOCK)
    }

    /// Writes the end-of-archive blocks and sector padding, and returns the sink.
    ///
    /// # Errors
    /// A write error.
    pub fn finish(mut self) -> io::Result<W> {
        self.zeros(2 * BLOCK)?;
        self.pad_to(SECTOR)?;
        self.out.flush()?;
        Ok(self.out)
    }

    fn header(&mut self, name: &str, kind: u8, mode: u32, size: u64, mtime: u64) -> io::Result<()> {
        let short = name.len() <= 100 && name.bytes().all(|b| (0x20..0x7f).contains(&b));
        let big = size > OCTAL_SIZE_LIMIT;
        if !short || big {
            let mut records = String::new();
            if !short {
                records.push_str(&pax_record("path", name));
            }
            if big {
                records.push_str(&pax_record("size", &size.to_string()));
            }
            let block = ustar_header(PAX_NAME, b'x', 0o644, records.len() as u64, 0);
            self.put(&block)?;
            self.put(records.as_bytes())?;
            self.pad_to(BLOCK)?;
        }
        let field_name = if short { name } else { "" };
        let field_size = if big { 0 } else { size };
        let block = ustar_header(field_name, kind, mode, field_size, mtime.min(OCTAL_SIZE_LIMIT));
        self.put(&block)
    }

    fn put(&mut self, bytes: &[u8]) -> io::Result<()> {
        self.out.write_all(bytes)?;
        self.written += bytes.len() as u64;
        Ok(())
    }

    fn zeros(&mut self, mut count: u64) -> io::Result<()> {
        let zero = [0u8; 512];
        while count > 0 {
            let n = count.min(512);
            self.put(zero.get(..usize::try_from(n).unwrap_or(512)).unwrap_or(&zero))?;
            count -= n;
        }
        Ok(())
    }

    fn pad_to(&mut self, multiple: u64) -> io::Result<()> {
        let rem = self.written % multiple;
        if rem == 0 { Ok(()) } else { self.zeros(multiple - rem) }
    }
}

fn invalid(e: NameError) -> io::Error {
    io::Error::new(io::ErrorKind::InvalidInput, e.to_string())
}

/// One pax record: `"<len> <key>=<value>\n"`, where `<len>` counts the whole record.
#[must_use]
pub fn pax_record(key: &str, value: &str) -> String {
    let body = key.len() + value.len() + 3; // space, '=', '\n'
    let mut len = body + 1;
    while len != body + len.to_string().len() {
        len = body + len.to_string().len();
    }
    format!("{len} {key}={value}\n")
}

fn ustar_header(name: &str, kind: u8, mode: u32, size: u64, mtime: u64) -> [u8; 512] {
    let mut h = [0u8; 512];
    put_field(&mut h, 0, 100, name.as_bytes());
    put_octal(&mut h, 100, 8, u64::from(mode));
    put_octal(&mut h, 108, 8, 0);
    put_octal(&mut h, 116, 8, 0);
    put_octal(&mut h, 124, 12, size);
    put_octal(&mut h, 136, 12, mtime);
    put_field(&mut h, 148, 8, b"        ");
    put_field(&mut h, 156, 1, &[kind]);
    put_field(&mut h, 257, 8, b"ustar\x0000");
    let sum: u64 = h.iter().map(|b| u64::from(*b)).sum();
    put_field(&mut h, 148, 8, format!("{sum:06o}\0 ").as_bytes());
    h
}

fn put_field(h: &mut [u8; 512], at: usize, width: usize, bytes: &[u8]) {
    if let Some(slot) = h.get_mut(at..at + width.min(bytes.len())) {
        slot.copy_from_slice(bytes.get(..slot.len()).unwrap_or_default());
    }
}

fn put_octal(h: &mut [u8; 512], at: usize, width: usize, value: u64) {
    let digits = width - 1;
    put_field(h, at, width, format!("{value:0digits$o}\0").as_bytes());
}

// MARK: - Reader

#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum EntryKind {
    Directory,
    File,
}

/// One entry's metadata; a file's bytes follow and are read with [`BundleReader::copy_data`].
#[derive(Clone, Debug, PartialEq, Eq)]
pub struct Entry {
    pub path: String,
    pub kind: EntryKind,
    pub size: u64,
    pub mtime: u64,
}

#[derive(Debug)]
pub enum BundleError {
    Io(io::Error),
    /// The archive is not a valid bundle; the message says why.
    Malformed(String),
    Name {
        path: String,
        error: NameError,
    },
}

impl fmt::Display for BundleError {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        match self {
            Self::Io(e) => write!(f, "{e}"),
            Self::Malformed(m) => write!(f, "the folder archive is damaged: {m}"),
            Self::Name { path, error } => write!(f, "“{path}” can’t go on a disc: {error}"),
        }
    }
}

impl std::error::Error for BundleError {}

impl From<io::Error> for BundleError {
    fn from(e: io::Error) -> Self {
        Self::Io(e)
    }
}

fn malformed(m: impl Into<String>) -> BundleError {
    BundleError::Malformed(m.into())
}

/// Reads entries one at a time. A file's data not read with `copy_data` is skipped.
#[derive(Debug)]
pub struct BundleReader<R: Read> {
    inner: R,
    /// Data bytes of the current entry not yet consumed, then its block padding.
    remaining: u64,
    padding: u64,
    done: bool,
}

#[derive(Default)]
struct Overrides {
    path: Option<String>,
    size: Option<u64>,
    mtime: Option<u64>,
}

impl<R: Read> BundleReader<R> {
    pub fn new(inner: R) -> Self {
        Self { inner, remaining: 0, padding: 0, done: false }
    }

    /// The underlying reader (for progress counting).
    pub fn get_ref(&self) -> &R {
        &self.inner
    }

    /// The next entry, or `None` at the end-of-archive marker.
    ///
    /// # Errors
    /// Malformed headers, unsupported entry types, invalid names, or I/O errors.
    pub fn next_entry(&mut self) -> Result<Option<Entry>, BundleError> {
        self.skip_rest()?;
        if self.done {
            return Ok(None);
        }
        let mut overrides = Overrides::default();
        loop {
            let mut h = [0u8; 512];
            self.inner.read_exact(&mut h).map_err(|e| {
                if e.kind() == io::ErrorKind::UnexpectedEof { malformed("it ends in the middle") } else { e.into() }
            })?;
            if h.iter().all(|b| *b == 0) {
                self.done = true;
                return Ok(None);
            }
            check_header(&h)?;
            let kind = h.get(156).copied().unwrap_or(0);
            let size = octal(h.get(124..136).unwrap_or_default()).ok_or_else(|| malformed("a bad size field"))?;
            match kind {
                b'x' => {
                    if size > MAX_PAX_BYTES || overrides.path.is_some() || overrides.size.is_some() {
                        return Err(malformed("an oversized or repeated extended header"));
                    }
                    let mut records = vec![0u8; usize::try_from(size).unwrap_or(0)];
                    self.inner.read_exact(&mut records)?;
                    skip(&mut self.inner, round_up(size) - size)?;
                    parse_pax(&records, &mut overrides)?;
                }
                b'0' | 0 | b'5' => {
                    let size = overrides.size.unwrap_or(size);
                    let mtime = match overrides.mtime {
                        Some(t) => t,
                        None => octal(h.get(136..148).unwrap_or_default()).unwrap_or(0),
                    };
                    let raw = match overrides.path.take() {
                        Some(p) => p,
                        None => header_path(&h)?,
                    };
                    let path = raw.strip_prefix("./").unwrap_or(&raw).trim_end_matches('/').to_owned();
                    validate_path(&path).map_err(|error| BundleError::Name { path: path.clone(), error })?;
                    let entry_kind = if kind == b'5' { EntryKind::Directory } else { EntryKind::File };
                    let size = if entry_kind == EntryKind::Directory { 0 } else { size };
                    // A pax `size` can be any u64: one within a block of u64::MAX would overflow.
                    let padded = size.checked_next_multiple_of(BLOCK).ok_or_else(|| malformed("a bad size field"))?;
                    self.remaining = size;
                    self.padding = padded - size;
                    return Ok(Some(Entry { path, kind: entry_kind, size, mtime }));
                }
                b'1' | b'2' => return Err(malformed("it contains a link; only files and folders are supported")),
                other => {
                    return Err(malformed(format!(
                        "it contains an unsupported entry type '{}'",
                        char::from(other).escape_default()
                    )));
                }
            }
        }
    }

    /// Copies the current file's data to `out` in chunks, calling `keep_going` between chunks;
    /// returns `Ok(false)` if `keep_going` said stop.
    ///
    /// # Errors
    /// I/O errors, or the archive ending early.
    pub fn copy_data(&mut self, out: &mut dyn Write, keep_going: &dyn Fn() -> bool) -> Result<bool, BundleError> {
        let mut buf = vec![0u8; 256 * 1024];
        while self.remaining > 0 {
            if !keep_going() {
                return Ok(false);
            }
            let want = usize::try_from(self.remaining.min(buf.len() as u64)).unwrap_or(buf.len());
            let chunk = buf.get_mut(..want).unwrap_or_default();
            self.inner.read_exact(chunk).map_err(|e| {
                if e.kind() == io::ErrorKind::UnexpectedEof { malformed("a file is cut short") } else { e.into() }
            })?;
            out.write_all(chunk)?;
            self.remaining -= want as u64;
        }
        skip(&mut self.inner, self.padding)?;
        self.padding = 0;
        Ok(true)
    }

    fn skip_rest(&mut self) -> Result<(), BundleError> {
        skip(&mut self.inner, self.remaining + self.padding)?;
        self.remaining = 0;
        self.padding = 0;
        Ok(())
    }
}

fn round_up(n: u64) -> u64 {
    n.div_ceil(BLOCK) * BLOCK
}

fn skip(reader: &mut dyn Read, count: u64) -> Result<(), BundleError> {
    let copied = io::copy(&mut reader.take(count), &mut io::sink())?;
    if copied == count { Ok(()) } else { Err(malformed("it ends in the middle")) }
}

fn check_header(h: &[u8; 512]) -> Result<(), BundleError> {
    let magic = h.get(257..263).unwrap_or_default();
    if magic != b"ustar\0" && magic != b"ustar " {
        return Err(malformed("an entry is not in ustar format"));
    }
    let stored = octal(h.get(148..156).unwrap_or_default()).ok_or_else(|| malformed("a bad header checksum"))?;
    let sum: u64 = h.iter().enumerate().map(|(i, b)| if (148..156).contains(&i) { 32 } else { u64::from(*b) }).sum();
    if stored == sum { Ok(()) } else { Err(malformed("a header checksum does not match")) }
}

/// Parses a NUL- or space-terminated octal field. Base-256 (high bit set) is not supported.
fn octal(field: &[u8]) -> Option<u64> {
    let text: Vec<u8> =
        field.iter().copied().skip_while(|b| *b == b' ').take_while(|b| *b != 0 && *b != b' ').collect();
    if text.is_empty() {
        return Some(0);
    }
    text.iter().try_fold(0u64, |acc, d| {
        if (b'0'..=b'7').contains(d) { acc.checked_mul(8)?.checked_add(u64::from(d - b'0')) } else { None }
    })
}

fn header_path(h: &[u8; 512]) -> Result<String, BundleError> {
    let field = |range: std::ops::Range<usize>| {
        let bytes = h.get(range).unwrap_or_default();
        let end = bytes.iter().position(|b| *b == 0).unwrap_or(bytes.len());
        String::from_utf8(bytes.get(..end).unwrap_or_default().to_vec())
            .map_err(|_| malformed("a name is not valid UTF-8"))
    };
    let name = field(0..100)?;
    let prefix = field(345..500)?;
    Ok(if prefix.is_empty() { name } else { format!("{prefix}/{name}") })
}

fn parse_pax(mut records: &[u8], into: &mut Overrides) -> Result<(), BundleError> {
    while !records.is_empty() {
        let space = records.iter().position(|b| *b == b' ').ok_or_else(|| malformed("a bad extended header"))?;
        let len: usize = std::str::from_utf8(records.get(..space).unwrap_or_default())
            .ok()
            .and_then(|s| s.parse().ok())
            .filter(|l| *l > space + 1 && *l <= records.len())
            .ok_or_else(|| malformed("a bad extended header record length"))?;
        let record = records.get(space + 1..len).unwrap_or_default();
        let record = record.strip_suffix(b"\n").ok_or_else(|| malformed("an unterminated extended header record"))?;
        let text = std::str::from_utf8(record).map_err(|_| malformed("an extended header is not valid UTF-8"))?;
        let (key, value) = text.split_once('=').ok_or_else(|| malformed("an extended header record has no '='"))?;
        match key {
            "path" => into.path = Some(value.to_owned()),
            "size" => into.size = Some(value.parse().map_err(|_| malformed("a bad size in an extended header"))?),
            "mtime" => {
                let whole = value.split('.').next().unwrap_or("0");
                into.mtime = Some(whole.parse().unwrap_or(0));
            }
            // Other keys (atime, ctime, uid, uname, xattrs…) carry nothing a disc keeps.
            _ => {}
        }
        records = records.get(len..).unwrap_or_default();
    }
    Ok(())
}

// MARK: - Tests

#[cfg(test)]
#[allow(clippy::unwrap_used, clippy::expect_used, clippy::panic)]
mod tests {
    use super::*;

    fn bundle(build: impl FnOnce(&mut BundleWriter<Vec<u8>>)) -> Vec<u8> {
        let mut w = BundleWriter::new(Vec::new());
        build(&mut w);
        w.finish().unwrap()
    }

    fn entries(bytes: &[u8]) -> Result<Vec<(Entry, Vec<u8>)>, BundleError> {
        let mut r = BundleReader::new(bytes);
        let mut out = Vec::new();
        while let Some(e) = r.next_entry()? {
            let mut data = Vec::new();
            r.copy_data(&mut data, &|| true)?;
            out.push((e, data));
        }
        Ok(out)
    }

    #[test]
    fn round_trips_short_long_and_unicode_names() {
        let long = format!("Photos/{}.jpg", "very long name ".repeat(8).trim_end());
        let bytes = bundle(|w| {
            w.directory("Photos", 1_700_000_000).unwrap();
            w.file("Photos/a.txt", 5, 1_700_000_001, &mut &b"hello"[..]).unwrap();
            w.file(&long, 3, 1_700_000_002, &mut &b"abc"[..]).unwrap();
            w.file("Ünïcode ✓.txt", 0, 0, &mut &b""[..]).unwrap();
        });
        assert_eq!(bytes.len() % 2048, 0);
        let got = entries(&bytes).unwrap();
        assert_eq!(got.len(), 4);
        assert_eq!(
            got[0].0,
            Entry { path: "Photos".into(), kind: EntryKind::Directory, size: 0, mtime: 1_700_000_000 }
        );
        assert_eq!(got[1].1, b"hello");
        assert_eq!(got[2].0.path, long);
        assert_eq!(got[2].1, b"abc");
        assert_eq!(got[3].0.path, "Ünïcode ✓.txt");
    }

    #[test]
    fn pax_record_length_counts_itself() {
        assert_eq!(pax_record("path", "a"), "9 path=a\n");
        assert_eq!(pax_record("path", &"y".repeat(5)), "14 path=yyyyy\n");
        let r = pax_record("path", &"x".repeat(91));
        assert_eq!(r.len(), 101);
        assert!(r.starts_with("101 "));
    }

    #[test]
    fn rejects_links_traversal_and_bad_checksums() {
        let mut link = ustar_header("evil", b'2', 0o777, 0, 0).to_vec();
        link.extend([0u8; 1024]);
        assert!(matches!(entries(&link), Err(BundleError::Malformed(m)) if m.contains("link")));

        let mut dotdot = ustar_header("../etc/passwd", b'0', 0o644, 0, 0).to_vec();
        dotdot.extend([0u8; 1024]);
        assert!(matches!(entries(&dotdot), Err(BundleError::Name { error: NameError::DotSegment, .. })));

        let mut absolute = ustar_header("/etc/passwd", b'0', 0o644, 0, 0).to_vec();
        absolute.extend([0u8; 1024]);
        assert!(matches!(entries(&absolute), Err(BundleError::Name { error: NameError::Absolute, .. })));

        let mut corrupt = bundle(|w| w.file("a", 1, 0, &mut &b"x"[..]).unwrap());
        corrupt[10] ^= 1;
        assert!(matches!(entries(&corrupt), Err(BundleError::Malformed(_))));
    }

    #[test]
    fn rejects_truncated_archives() {
        let bytes = bundle(|w| w.file("a.bin", 4096, 0, &mut &[7u8; 4096][..]).unwrap());
        assert!(matches!(entries(&bytes[..2000]), Err(BundleError::Malformed(_))));
    }

    #[test]
    fn huge_sizes_use_a_pax_size_record() {
        let mut w = BundleWriter::new(Vec::new());
        // Only the header is checked; the data copy fails fast on the empty reader.
        let err = w.file("big.bin", OCTAL_SIZE_LIMIT + 1, 0, &mut io::empty()).unwrap_err();
        assert_eq!(err.kind(), io::ErrorKind::UnexpectedEof);
        let written = w.out.clone();
        let mut r = BundleReader::new(&written[..]);
        let e = r.next_entry().unwrap().unwrap();
        assert_eq!(e.size, OCTAL_SIZE_LIMIT + 1);
    }

    #[test]
    fn rejects_a_pax_size_that_cannot_be_padded() {
        let record = pax_record("size", &u64::MAX.to_string());
        let mut bytes = ustar_header(PAX_NAME, b'x', 0o644, record.len() as u64, 0).to_vec();
        bytes.extend_from_slice(record.as_bytes());
        bytes.resize(1024, 0);
        bytes.extend_from_slice(&ustar_header("a", b'0', 0o644, 0, 0));
        bytes.extend([0u8; 1024]);
        assert!(matches!(entries(&bytes), Err(BundleError::Malformed(m)) if m.contains("size")));
    }

    #[test]
    fn name_rules() {
        for ok in ["a", "Photos/2026/IMG 0001.JPG", "CONSOLE.txt", "com10", ".hidden", "LPT0", "a.b.c"] {
            assert_eq!(validate_path(ok), Ok(()), "{ok}");
        }
        for bad in [
            "",
            "/a",
            "a//b",
            "a/./b",
            "..",
            "a:b",
            "a\\b",
            "x\u{7}",
            "trailing.",
            "space ",
            "con",
            "Aux.txt",
            "COM1",
            "lpt9.log",
        ] {
            assert!(validate_path(bad).is_err(), "{bad:?}");
        }
        assert!(validate_path("d/".repeat(64).trim_end_matches('/')).is_ok());
        assert_eq!(validate_path("d/".repeat(65).trim_end_matches('/')), Err(NameError::TooDeep));
        assert!(matches!(validate_path(&"n".repeat(256)), Err(NameError::NameTooLong(_))));
    }
}
