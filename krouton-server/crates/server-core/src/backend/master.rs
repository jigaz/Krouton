// MARK: - backend/master.rs

//! Building a disc image from a folder (`files` jobs), with the tool each platform already has:
//!
//! | Backend | Tool | File systems |
//! |---|---|---|
//! | Linux | `xorriso -as mkisofs` | ISO 9660 (level 3) + Joliet + Rock Ridge |
//! | macOS | `hdiutil makehybrid` | ISO 9660 + Joliet + UDF; UDF only if a file is 4 GiB or larger |
//! | Windows | IMAPI2FS (`windows.rs`) | ISO 9660 + Joliet + UDF 2.50; UDF only if a file is 4 GiB or larger |
//! | Simulate | none | a placeholder image of the right size |
//!
//! xorriso does not write UDF; its ISO level 3 stores large files in several extents, which
//! Windows 10/11, macOS and Linux all read.

use super::{first_percent, run_capture, run_tool};
use crate::backend::macos::{Puppet, parse_puppet_line};
use std::fs::{self, File};
use std::io::{Seek, SeekFrom, Write};
use std::path::Path;
use std::process::Command;
use std::sync::atomic::{AtomicBool, Ordering};

pub const ISO9660: &str = "iso9660";
pub const JOLIET: &str = "joliet";
pub const ROCK_RIDGE: &str = "rockridge";
pub const UDF: &str = "udf";

/// ISO 9660 cannot hold a file of this size or larger in a single extent.
pub const ISO_FILE_LIMIT: u64 = 4 * 1024 * 1024 * 1024;

/// Everything a mastering run needs.
#[derive(Debug)]
pub struct MasterRequest<'a> {
    /// The unpacked folder; its contents become the disc's root.
    pub tree: &'a Path,
    /// Where to write the image (overwritten).
    pub output: &'a Path,
    /// The disc's name as the user typed it.
    pub label: &'a str,
    pub largest_file: u64,
    pub cancel: &'a AtomicBool,
}

// MARK: - Volume names

/// ISO 9660 volume identifier: d-characters (`A–Z 0–9 _`), at most 32.
#[must_use]
pub fn iso_volume_name(label: &str) -> String {
    let name: String = label
        .trim()
        .chars()
        .map(|c| if c.is_ascii_alphanumeric() { c.to_ascii_uppercase() } else { '_' })
        .take(32)
        .collect();
    let name = name.trim_matches('_').to_owned();
    if name.is_empty() { "KROUTON".into() } else { name }
}

/// Joliet/UDF volume name: the label as typed, without control characters, at most `max` chars.
#[must_use]
pub fn unicode_volume_name(label: &str, max: usize) -> String {
    let name: String = label.trim().chars().filter(|c| !c.is_control()).take(max).collect();
    let name = name.trim().to_owned();
    if name.is_empty() { "Krouton".into() } else { name }
}

// MARK: - xorriso (Linux)

/// Whether `xorriso` runs at all.
#[must_use]
pub fn xorriso_available(xorriso: &str) -> bool {
    let mut cmd = Command::new(xorriso);
    cmd.arg("-version");
    matches!(run_capture(cmd), Ok((Some(0), _)))
}

/// # Errors
/// A message for the user.
pub fn xorriso_master(
    xorriso: &str,
    request: &MasterRequest<'_>,
    progress: &mut dyn FnMut(Option<f64>),
) -> Result<Vec<&'static str>, String> {
    let _ = fs::remove_file(request.output);
    let mut cmd = Command::new(xorriso);
    cmd.args(["-abort_on", "FAILURE", "-as", "mkisofs", "-iso-level", "3", "-J", "-joliet-long", "-r"]);
    cmd.arg("-V").arg(iso_volume_name(request.label));
    cmd.arg("-o").arg(request.output);
    cmd.arg(request.tree);
    let mut errors = ToolOutput::default();
    let code = run_tool(cmd, request.cancel, &mut |line| {
        if line.contains("UPDATE") && line.contains('%') {
            progress(first_percent(line));
        } else {
            errors.note(line, line.contains("FAILURE") || line.contains("SORRY") || line.contains("FATAL"));
        }
    })
    .map_err(|e| format!("Could not run {xorriso}: {e}"))?;
    finish(request, code, errors.into_messages(), "xorriso")?;
    Ok(vec![ISO9660, JOLIET, ROCK_RIDGE])
}

// MARK: - hdiutil makehybrid (macOS)

/// # Errors
/// A message for the user.
pub fn hdiutil_master(
    hdiutil: &str,
    request: &MasterRequest<'_>,
    progress: &mut dyn FnMut(Option<f64>),
) -> Result<Vec<&'static str>, String> {
    let _ = fs::remove_file(request.output);
    let udf_only = request.largest_file >= ISO_FILE_LIMIT;
    let mut cmd = Command::new(hdiutil);
    cmd.args(["makehybrid", "-puppetstrings", "-udf"]);
    cmd.arg("-udf-volume-name").arg(unicode_volume_name(request.label, 32));
    if !udf_only {
        cmd.args(["-iso", "-joliet"]);
        cmd.arg("-iso-volume-name").arg(iso_volume_name(request.label));
        cmd.arg("-joliet-volume-name").arg(unicode_volume_name(request.label, 16));
    }
    cmd.arg("-default-volume-name").arg(unicode_volume_name(request.label, 32));
    cmd.arg("-o").arg(request.output);
    cmd.arg(request.tree);
    let mut errors = ToolOutput::default();
    let code = run_tool(cmd, request.cancel, &mut |line| match parse_puppet_line(line) {
        Some(Puppet::Percent(p)) => progress(p),
        Some(Puppet::Message(_)) => {}
        None => errors.note(line, line.contains("failed") || line.contains("rror")),
    })
    .map_err(|e| format!("Could not run {hdiutil}: {e}"))?;
    finish(request, code, errors.into_messages(), "hdiutil makehybrid")?;
    Ok(if udf_only { vec![UDF] } else { vec![ISO9660, JOLIET, UDF] })
}

// MARK: - Simulate

/// Writes a placeholder image as large as the files would need, with an ISO 9660 signature at
/// sector 16, in a few progress steps.
///
/// # Errors
/// Disk errors, or `Cancelled`.
pub fn simulate_master(
    request: &MasterRequest<'_>,
    progress: &mut dyn FnMut(Option<f64>),
) -> Result<Vec<&'static str>, String> {
    let mut bytes = 18 * 2048;
    for entry in walk(request.tree) {
        bytes += entry.div_ceil(2048) * 2048 + 2048;
    }
    let mut out = File::create(request.output).map_err(|e| format!("Could not create the image: {e}"))?;
    for step in 1..=4u32 {
        if request.cancel.load(Ordering::SeqCst) {
            return Err("Cancelled".into());
        }
        std::thread::sleep(std::time::Duration::from_millis(20));
        progress(Some(f64::from(step) / 4.0));
    }
    let io = |e: std::io::Error| format!("Could not write the image: {e}");
    out.set_len(bytes).map_err(io)?;
    out.seek(SeekFrom::Start(16 * 2048 + 1)).map_err(io)?;
    out.write_all(b"CD001").map_err(io)?;
    Ok(vec![ISO9660, JOLIET, UDF])
}

fn walk(dir: &Path) -> Vec<u64> {
    let mut sizes = Vec::new();
    let mut stack = vec![dir.to_path_buf()];
    while let Some(d) = stack.pop() {
        for entry in fs::read_dir(&d).into_iter().flatten().flatten() {
            match entry.metadata() {
                Ok(m) if m.is_dir() => stack.push(entry.path()),
                Ok(m) => sizes.push(m.len()),
                Err(_) => {}
            }
        }
    }
    sizes
}

// MARK: - Shared

/// A tool's error lines, plus its last few lines of any kind for when it fails without one.
#[derive(Debug, Default)]
pub struct ToolOutput {
    errors: Vec<String>,
    tail: std::collections::VecDeque<String>,
}

impl ToolOutput {
    pub fn note(&mut self, line: &str, is_error: bool) {
        let line = line.trim();
        if line.is_empty() {
            return;
        }
        if is_error {
            self.errors.push(line.to_owned());
        }
        if self.tail.len() == 3 {
            self.tail.pop_front();
        }
        self.tail.push_back(line.to_owned());
    }

    #[must_use]
    pub fn into_messages(self) -> Vec<String> {
        if self.errors.is_empty() { self.tail.into() } else { self.errors }
    }
}

/// Turns a tool's exit into a result, checking that the image really exists and is non-empty.
///
/// # Errors
/// `Cancelled`, the tool's error lines, or a missing image.
pub fn finish(request: &MasterRequest<'_>, code: Option<i32>, errors: Vec<String>, tool: &str) -> Result<(), String> {
    if request.cancel.load(Ordering::SeqCst) {
        let _ = fs::remove_file(request.output);
        return Err("Cancelled".into());
    }
    if code != Some(0) {
        let _ = fs::remove_file(request.output);
        return Err(if errors.is_empty() {
            format!("{tool} could not build the disc (exit {})", code.map_or("signal".into(), |c| c.to_string()))
        } else {
            errors.join(" | ")
        });
    }
    match fs::metadata(request.output) {
        Ok(m) if m.len() >= 18 * 2048 => Ok(()),
        _ => Err(format!("{tool} finished but wrote no image")),
    }
}

// MARK: - Tests

#[cfg(test)]
#[allow(clippy::unwrap_used, clippy::expect_used, clippy::panic)]
pub(crate) mod tests {
    use super::*;
    use crate::testutil::TempDir;

    #[test]
    fn volume_names() {
        assert_eq!(iso_volume_name("Holiday 2026 – Ünïcode!"), "HOLIDAY_2026____N_CODE");
        assert_eq!(iso_volume_name("   "), "KROUTON");
        assert_eq!(iso_volume_name(&"a".repeat(40)).len(), 32);
        assert_eq!(unicode_volume_name("Fotos – Ünïcode\n", 16), "Fotos – Ünïcode");
        assert_eq!(unicode_volume_name("\t", 16), "Krouton");
    }

    /// The image a real tool builds from a small tree, checked for the file-system signatures.
    /// Runs wherever the tool is installed; set `KROUTON_REQUIRE_MASTERING=1` (CI) to make a
    /// missing tool a failure instead of a skip.
    pub(crate) type MasterFn<'f> =
        &'f dyn Fn(&MasterRequest<'_>, &mut dyn FnMut(Option<f64>)) -> Result<Vec<&'static str>, String>;

    pub(crate) fn check_real_master(tool_available: bool, tool: &str, master: MasterFn<'_>) {
        if !tool_available {
            assert!(
                std::env::var("KROUTON_REQUIRE_MASTERING").as_deref() != Ok("1"),
                "{tool} is required on this runner"
            );
            eprintln!("skipping: {tool} not installed");
            return;
        }
        let tmp = TempDir::new("master");
        let tree = tmp.path().join("tree");
        fs::create_dir_all(tree.join("Fotos – Ünïcode")).unwrap();
        fs::write(tree.join("README.txt"), b"Burned by Krouton.\n").unwrap();
        fs::write(tree.join("Fotos – Ünïcode").join("IMG_0001.JPG"), vec![7u8; 100_000]).unwrap();
        let output = tmp.path().join("disc.iso");
        let request = MasterRequest {
            tree: &tree,
            output: &output,
            label: "Holiday 2026",
            largest_file: 100_000,
            cancel: &AtomicBool::new(false),
        };
        let systems = master(&request, &mut |_| {}).unwrap();
        let image = fs::read(&output).unwrap();
        assert!(image.len() >= 100_000 && image.len().is_multiple_of(2048), "{} bytes", image.len());
        let has = |needle: &[u8]| image.windows(needle.len()).any(|w| w == needle);
        if systems.contains(&ISO9660) {
            assert_eq!(&image[16 * 2048 + 1..16 * 2048 + 6], b"CD001", "no ISO 9660 primary volume descriptor");
            let lower = image.to_ascii_lowercase();
            assert!(lower.windows(7).any(|w| w == b"holiday"), "volume name missing");
        }
        if systems.contains(&UDF) {
            assert!(has(b"NSR02") || has(b"NSR03"), "no UDF descriptor");
        }
        assert!(has(b"Burned by Krouton.\n"), "file contents missing");
    }

    #[test]
    fn xorriso_builds_a_disc() {
        check_real_master(xorriso_available("xorriso"), "xorriso", &|r, p| xorriso_master("xorriso", r, p));
    }

    #[cfg(target_os = "macos")]
    #[test]
    fn hdiutil_builds_a_disc() {
        check_real_master(true, "hdiutil", &|r, p| hdiutil_master("/usr/bin/hdiutil", r, p));
    }

    #[test]
    fn simulate_writes_a_placeholder_and_stops_on_cancel() {
        let tmp = TempDir::new("master-sim");
        let tree = tmp.path().join("tree");
        fs::create_dir_all(&tree).unwrap();
        fs::write(tree.join("a.bin"), vec![1u8; 5000]).unwrap();
        let out = tmp.path().join("x.iso");
        let mut request = MasterRequest {
            tree: &tree,
            output: &out,
            label: "x",
            largest_file: 5000,
            cancel: &AtomicBool::new(false),
        };
        let mut steps = 0;
        assert_eq!(simulate_master(&request, &mut |_| steps += 1).unwrap(), vec![ISO9660, JOLIET, UDF]);
        let image = fs::read(&out).unwrap();
        assert_eq!(image.len() % 2048, 0);
        assert!(image.len() > 5000 + 16 * 2048);
        assert_eq!(&image[16 * 2048 + 1..16 * 2048 + 6], b"CD001");
        assert_eq!(steps, 4);
        let cancelled = AtomicBool::new(true);
        request.cancel = &cancelled;
        assert_eq!(simulate_master(&request, &mut |_| {}), Err("Cancelled".into()));
    }
}
