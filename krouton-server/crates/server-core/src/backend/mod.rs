// MARK: - backend/mod.rs

//! Burn backends: one per platform, each driving the burn tool the OS already ships or that a
//! package manager installs in one line. Using the native tools (rather than raw SCSI) keeps the
//! server free of `unsafe` and drivers, and they handle the per-drive quirks.
//!
//! | Backend | Tool | Progress | Verify |
//! |---|---|---|---|
//! | macOS 12+ | `hdiutil burn -puppetstrings` | percent | `hdiutil -verifyburn` |
//! | Linux (Debian, Raspberry Pi OS, Proxmox, Synology…) | `xorriso -as cdrecord` | percent, FIFO, buffer, speed | read-back compare |
//! | Windows 10/11 | IMAPI2 via PowerShell | indeterminate | read-back compare |
//! | Simulate | none | percent | simulated |

pub mod linux;
pub mod macos;
pub mod master;
pub mod simulate;
pub mod windows;

pub use master::MasterRequest;

use crate::config::{BackendKind, Config};
use krsp::control::{BurnOptions, MediaState};
use std::io::{self, Read};
use std::path::Path;
use std::process::{Command, Stdio};
use std::sync::atomic::{AtomicBool, Ordering};
use std::sync::mpsc;
use std::time::Duration;

#[derive(Clone, Debug, PartialEq, Eq)]
pub struct Drive {
    /// Stable, file-name-safe identifier sent to clients (`sr0`, `mac-1`, `D`, `sim-1`).
    pub id: String,
    /// Human-readable vendor and model.
    pub name: String,
    /// What the burn tool is given (`/dev/sr0`, an IOService path, `D:`).
    pub device: String,
}

#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum Stage {
    Preparing,
    Writing,
    Verifying,
}

#[derive(Clone, Debug, PartialEq)]
pub struct Progress {
    pub stage: Stage,
    /// 0…1 within the whole job (writing then verifying), `None` when the tool cannot say.
    pub fraction: Option<f64>,
    pub speed_x: f64,
    pub fifo: f64,
    pub buffer: f64,
    pub message: String,
}

impl Progress {
    #[must_use]
    pub fn new(stage: Stage, fraction: Option<f64>, message: impl Into<String>) -> Self {
        Self { stage, fraction, speed_x: 0.0, fifo: 0.0, buffer: 0.0, message: message.into() }
    }
}

/// Everything a burn needs to know.
#[derive(Debug)]
pub struct BurnRequest<'a> {
    pub drive: &'a Drive,
    pub image: &'a Path,
    pub image_bytes: u64,
    pub options: &'a BurnOptions,
    pub cancel: &'a AtomicBool,
}

pub trait Backend: Send + Sync + std::fmt::Debug {
    fn kind(&self) -> BackendKind;
    fn discover(&self) -> Vec<Drive>;
    fn media(&self, drive: &Drive) -> MediaState;
    /// Blocks until the burn (and verification, if requested) ends. `Err` carries a message for
    /// the user. Must return promptly once `cancel` is set.
    fn burn(&self, request: &BurnRequest<'_>, progress: &mut dyn FnMut(Progress)) -> Result<(), String>;
    fn eject(&self, drive: &Drive) -> Result<(), String>;
    /// File systems [`Backend::master`] builds (see `master.rs`), or empty when the tool it
    /// needs is missing. Called once at startup.
    fn file_systems(&self) -> Vec<&'static str>;
    /// Builds a disc image from a folder for a `files` job. `progress` gets 0…1 (or `None` when
    /// the tool cannot say). Returns the file systems written. Must return promptly once
    /// `request.cancel` is set.
    fn master(
        &self,
        request: &MasterRequest<'_>,
        progress: &mut dyn FnMut(Option<f64>),
    ) -> Result<Vec<&'static str>, String>;
    /// Problems that would stop a burn (missing tool, no permission), for `krouton-server check`.
    fn diagnose(&self) -> Vec<String>;
}

/// Builds the backend the configuration asks for.
#[must_use]
pub fn from_config(config: &Config) -> Box<dyn Backend> {
    match config.backend.resolved() {
        BackendKind::Simulate => {
            Box::new(simulate::SimulatedBackend::new(config.simulate_drives, config.simulate_seconds))
        }
        BackendKind::MacOs => Box::new(macos::MacBackend::new(config.hdiutil.clone(), config.drives.clone())),
        BackendKind::Windows => Box::new(windows::WindowsBackend::new(
            config.powershell.clone(),
            config.state_dir.clone(),
            config.drives.clone(),
        )),
        BackendKind::Linux | BackendKind::Auto => {
            Box::new(linux::LinuxBackend::new(config.xorriso.clone(), config.drives.clone()))
        }
    }
}

// MARK: - Child processes

/// One line of tool output. Tools that redraw a progress line with `\r` produce a line per redraw.
#[derive(Debug)]
pub enum ToolEvent {
    Line(String),
    Exited(Option<i32>),
}

/// Runs `command`, streaming stdout and stderr lines to `on_line`, killing the child if `cancel`
/// is set. Returns the exit code (`None` if killed by a signal or cancelled).
pub fn run_tool(mut command: Command, cancel: &AtomicBool, on_line: &mut dyn FnMut(&str)) -> io::Result<Option<i32>> {
    command.stdin(Stdio::null()).stdout(Stdio::piped()).stderr(Stdio::piped());
    let mut child = command.spawn()?;
    let (tx, rx) = mpsc::channel::<String>();
    let mut readers = Vec::new();
    if let Some(out) = child.stdout.take() {
        let tx = tx.clone();
        readers.push(std::thread::spawn(move || split_lines(out, &tx)));
    }
    if let Some(err) = child.stderr.take() {
        let tx = tx.clone();
        readers.push(std::thread::spawn(move || split_lines(err, &tx)));
    }
    drop(tx);
    let status = loop {
        match rx.recv_timeout(Duration::from_millis(200)) {
            Ok(line) => on_line(&line),
            Err(mpsc::RecvTimeoutError::Timeout) => {}
            Err(mpsc::RecvTimeoutError::Disconnected) => {
                // Both pipes closed: the child is exiting.
                break child.wait()?;
            }
        }
        if cancel.load(Ordering::SeqCst) {
            let _ = child.kill();
            let _ = child.wait();
            // Not joining the readers: a grandchild may still hold the pipes open. They end on
            // their own when the last writer goes away.
            return Ok(None);
        }
        if let Some(status) = child.try_wait()? {
            // Drain whatever is still buffered in the pipes.
            for r in readers.drain(..) {
                let _ = r.join();
            }
            while let Ok(line) = rx.try_recv() {
                on_line(&line);
            }
            break status;
        }
    };
    for r in readers {
        let _ = r.join();
    }
    Ok(status.code())
}

/// Runs a short command and returns its combined output (for discovery and status queries).
pub fn run_capture(mut command: Command) -> io::Result<(Option<i32>, String)> {
    let output = command.stdin(Stdio::null()).output()?;
    let mut text = String::from_utf8_lossy(&output.stdout).into_owned();
    text.push_str(&String::from_utf8_lossy(&output.stderr));
    Ok((output.status.code(), text))
}

fn split_lines(mut reader: impl Read, tx: &mpsc::Sender<String>) {
    let mut buf = [0u8; 4096];
    let mut line = Vec::new();
    loop {
        match reader.read(&mut buf) {
            Ok(0) | Err(_) => break,
            Ok(n) => {
                for &b in buf.get(..n).unwrap_or_default() {
                    if b == b'\n' || b == b'\r' {
                        if !line.is_empty() {
                            let _ = tx.send(String::from_utf8_lossy(&line).into_owned());
                            line.clear();
                        }
                    } else if line.len() < 4096 {
                        line.push(b);
                    }
                }
            }
        }
    }
    if !line.is_empty() {
        let _ = tx.send(String::from_utf8_lossy(&line).into_owned());
    }
}

// MARK: - Read-back verification

/// Compares the first `image_bytes` of `device` with `image`, reporting progress from
/// `start_fraction` to 1. Retries opening the device for a while: drives need a few seconds after
/// a burn before the new disc is readable.
pub fn verify_readback(
    device: &Path,
    image: &Path,
    image_bytes: u64,
    cancel: &AtomicBool,
    start_fraction: f64,
    progress: &mut dyn FnMut(Progress),
) -> Result<(), String> {
    const CHUNK: usize = 1024 * 1024;
    let mut disc = None;
    for attempt in 0..15 {
        match std::fs::File::open(device) {
            Ok(f) => {
                disc = Some(f);
                break;
            }
            Err(e) if attempt == 14 => return Err(format!("Could not open {} to verify: {e}", device.display())),
            Err(_) => std::thread::sleep(Duration::from_secs(2)),
        }
        if cancel.load(Ordering::SeqCst) {
            return Err("Cancelled".into());
        }
    }
    let mut disc = disc.ok_or_else(|| "Could not open the drive to verify".to_string())?;
    let mut source = std::fs::File::open(image).map_err(|e| format!("Could not reopen the image: {e}"))?;
    let mut a = vec![0u8; CHUNK];
    let mut b = vec![0u8; CHUNK];
    let mut done: u64 = 0;
    let mut last_report = 0u64;
    while done < image_bytes {
        if cancel.load(Ordering::SeqCst) {
            return Err("Cancelled".into());
        }
        let want = usize::try_from((image_bytes - done).min(CHUNK as u64)).unwrap_or(CHUNK);
        let (Some(da), Some(db)) = (a.get_mut(..want), b.get_mut(..want)) else { break };
        source.read_exact(da).map_err(|e| format!("Image read failed during verify: {e}"))?;
        disc.read_exact(db).map_err(|e| format!("Disc read failed at byte {done}: {e}"))?;
        if da != db {
            let offset = done + da.iter().zip(db.iter()).position(|(x, y)| x != y).unwrap_or(0) as u64;
            return Err(format!("Verification failed: the disc differs from the image at sector {}", offset / 2048));
        }
        done += want as u64;
        if done - last_report >= 32 * CHUNK as u64 || done == image_bytes {
            last_report = done;
            #[allow(clippy::cast_precision_loss)]
            let f = start_fraction + (1.0 - start_fraction) * (done as f64 / image_bytes.max(1) as f64);
            progress(Progress::new(Stage::Verifying, Some(f), "Verifying"));
        }
    }
    Ok(())
}

/// Parses the first `NN.N%` or `NN%` token in `line` as a 0…1 fraction.
#[must_use]
pub fn first_percent(line: &str) -> Option<f64> {
    let end = line.find('%')?;
    let head = line.get(..end)?;
    let start = head.rfind(|c: char| !(c.is_ascii_digit() || c == '.')).map_or(0, |i| i + 1);
    let value: f64 = head.get(start..)?.parse().ok()?;
    (0.0..=100.0).contains(&value).then_some(value / 100.0)
}

#[cfg(test)]
#[allow(clippy::unwrap_used)]
mod tests {
    use super::*;

    #[test]
    fn percent_tokens() {
        assert_eq!(first_percent("xorriso : UPDATE : Writing:  1234s  12.5%  fifo 100%"), Some(0.125));
        assert_eq!(first_percent("fifo 100%"), Some(1.0));
        assert_eq!(first_percent("no percent"), None);
        assert_eq!(first_percent("250%"), None);
    }

    #[cfg(unix)]
    #[test]
    fn run_tool_streams_lines_and_cancels() {
        let mut lines = Vec::new();
        let mut cmd = Command::new("sh");
        cmd.args(["-c", "printf 'a\\rb\\nc\\n'; printf 'err\\n' >&2; exit 3"]);
        let code = run_tool(cmd, &AtomicBool::new(false), &mut |l| lines.push(l.to_owned())).unwrap();
        assert_eq!(code, Some(3));
        lines.sort();
        assert_eq!(lines, ["a", "b", "c", "err"]);

        let cancel = AtomicBool::new(true);
        let mut cmd = Command::new("sh");
        cmd.args(["-c", "sleep 30"]);
        let started = std::time::Instant::now();
        assert_eq!(run_tool(cmd, &cancel, &mut |_| {}).unwrap(), None);
        assert!(started.elapsed() < Duration::from_secs(5));
    }

    #[test]
    fn readback_detects_mismatch() {
        let tmp = crate::testutil::TempDir::new("verify");
        let image = tmp.path().join("image.iso");
        let disc = tmp.path().join("disc.bin");
        let data: Vec<u8> = (0..3 * 1024 * 1024 + 4096).map(|i| (i % 251) as u8).collect();
        std::fs::write(&image, &data).unwrap();
        let mut burned = data.clone();
        burned.extend_from_slice(&[0; 8192]); // discs read past the image end; only the image length is compared
        std::fs::write(&disc, &burned).unwrap();
        let n = data.len() as u64;
        let mut last = 0.0;
        verify_readback(&disc, &image, n, &AtomicBool::new(false), 0.8, &mut |p| last = p.fraction.unwrap()).unwrap();
        assert!((last - 1.0).abs() < 1e-9);
        burned[2048 * 700 + 5] ^= 1;
        std::fs::write(&disc, &burned).unwrap();
        let err = verify_readback(&disc, &image, n, &AtomicBool::new(false), 0.8, &mut |_| {}).unwrap_err();
        assert!(err.contains("sector 700"), "{err}");
    }
}
