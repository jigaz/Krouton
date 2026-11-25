//! Linux backend (Debian, Ubuntu, Raspberry Pi OS, Proxmox VE, Synology/Unraid with a static
//! build): `xorriso -as cdrecord` writes CD, DVD and Blu-ray from one tool that every distro
//! packages (`apt install xorriso`). Drives are discovered from sysfs, so nothing else is needed.

use super::{Backend, BurnRequest, Drive, Progress, Stage, first_percent, run_capture, run_tool, verify_readback};
use crate::config::BackendKind;
use krsp::control::MediaState;
use std::path::{Path, PathBuf};
use std::process::Command;
use std::sync::atomic::Ordering;

#[derive(Debug)]
pub struct LinuxBackend {
    xorriso: String,
    explicit: Vec<String>,
    sysfs: PathBuf,
}

impl LinuxBackend {
    #[must_use]
    pub fn new(xorriso: String, explicit: Vec<String>) -> Self {
        Self { xorriso, explicit, sysfs: PathBuf::from("/sys/block") }
    }

    #[cfg(test)]
    fn with_sysfs(sysfs: PathBuf) -> Self {
        Self { xorriso: "xorriso".into(), explicit: Vec::new(), sysfs }
    }
}

impl Backend for LinuxBackend {
    fn kind(&self) -> BackendKind {
        BackendKind::Linux
    }

    fn discover(&self) -> Vec<Drive> {
        if !self.explicit.is_empty() {
            return self
                .explicit
                .iter()
                .map(|dev| {
                    let id =
                        Path::new(dev).file_name().map_or_else(|| dev.clone(), |n| n.to_string_lossy().into_owned());
                    let name = sysfs_model(&self.sysfs, &id).unwrap_or_else(|| dev.clone());
                    Drive { id: sanitize_id(&id), name, device: dev.clone() }
                })
                .collect();
        }
        let mut found: Vec<Drive> = std::fs::read_dir(&self.sysfs)
            .into_iter()
            .flatten()
            .flatten()
            .filter_map(|entry| {
                let id = entry.file_name().to_string_lossy().into_owned();
                id.starts_with("sr").then(|| Drive {
                    name: sysfs_model(&self.sysfs, &id).unwrap_or_else(|| format!("Optical drive {id}")),
                    device: format!("/dev/{id}"),
                    id,
                })
            })
            .collect();
        found.sort_by(|a, b| a.id.cmp(&b.id));
        found
    }

    fn media(&self, drive: &Drive) -> MediaState {
        let mut cmd = Command::new(&self.xorriso);
        cmd.args(["-outdev", &drive.device]);
        run_capture(cmd).map_or(MediaState::Unknown, |(_, text)| parse_media_status(&text))
    }

    fn burn(&self, request: &BurnRequest<'_>, progress: &mut dyn FnMut(Progress)) -> Result<(), String> {
        let o = request.options;
        let mut cmd = Command::new(&self.xorriso);
        cmd.args(["-as", "cdrecord", "-v", &format!("dev={}", request.drive.device), "fs=16m"]);
        if o.speed > 0 {
            cmd.arg(format!("speed={}", o.speed));
        }
        if o.simulate {
            cmd.arg("-dummy");
        }
        cmd.arg(request.image);
        let write_share = if o.verify && !o.simulate { 0.85 } else { 1.0 };
        progress(Progress::new(Stage::Preparing, Some(0.0), "Starting xorriso"));
        let mut tail: Vec<String> = Vec::new();
        let code = run_tool(cmd, request.cancel, &mut |line| {
            if let Some(mut p) = parse_progress_line(line) {
                p.fraction = p.fraction.map(|f| f * write_share);
                progress(p);
            }
            if tail.len() == 6 {
                tail.remove(0);
            }
            tail.push(line.to_owned());
        })
        .map_err(|e| format!("Could not run {}: {e}. Install it with `sudo apt install xorriso`.", self.xorriso))?;
        if request.cancel.load(Ordering::SeqCst) {
            return Err("Cancelled during the write; the disc is probably unusable".into());
        }
        if code != Some(0) {
            return Err(format!(
                "xorriso failed ({}): {}",
                code.map_or("killed".into(), |c| c.to_string()),
                tail.join(" | ")
            ));
        }
        if o.verify && !o.simulate {
            verify_readback(
                Path::new(&request.drive.device),
                request.image,
                request.image_bytes,
                request.cancel,
                write_share,
                progress,
            )?;
        }
        if o.eject {
            let _ = self.eject(request.drive);
        }
        Ok(())
    }

    fn eject(&self, drive: &Drive) -> Result<(), String> {
        let mut cmd = Command::new(&self.xorriso);
        cmd.args(["-outdev", &drive.device, "-eject", "all"]);
        match run_capture(cmd) {
            Ok((Some(0), _)) => Ok(()),
            Ok((_, text)) => Err(text.lines().last().unwrap_or("eject failed").to_owned()),
            Err(e) => Err(e.to_string()),
        }
    }

    fn file_systems(&self) -> Vec<&'static str> {
        if super::master::xorriso_available(&self.xorriso) {
            vec![super::master::ISO9660, super::master::JOLIET, super::master::ROCK_RIDGE]
        } else {
            Vec::new()
        }
    }

    fn master(
        &self,
        request: &super::MasterRequest<'_>,
        progress: &mut dyn FnMut(Option<f64>),
    ) -> Result<Vec<&'static str>, String> {
        super::master::xorriso_master(&self.xorriso, request, progress)
    }

    fn diagnose(&self) -> Vec<String> {
        let mut problems = Vec::new();
        let mut cmd = Command::new(&self.xorriso);
        cmd.arg("-version");
        if run_capture(cmd).is_err() {
            problems.push(format!("{} is not installed: run `sudo apt install xorriso`", self.xorriso));
        }
        let drives = self.discover();
        if drives.is_empty() {
            problems.push("No optical drives found under /sys/block (is the burner plugged in and powered?)".into());
        }
        for d in drives {
            if let Err(e) = std::fs::OpenOptions::new().read(true).write(true).open(&d.device) {
                problems.push(format!(
                    "Cannot open {} read/write ({e}): add the service user to the `cdrom` group",
                    d.device
                ));
            }
        }
        problems
    }
}

fn sysfs_model(sysfs: &Path, id: &str) -> Option<String> {
    let read =
        |f: &str| std::fs::read_to_string(sysfs.join(id).join("device").join(f)).ok().map(|s| s.trim().to_owned());
    let name =
        [read("vendor"), read("model")].into_iter().flatten().filter(|s| !s.is_empty()).collect::<Vec<_>>().join(" ");
    (!name.is_empty()).then_some(name)
}

fn sanitize_id(s: &str) -> String {
    let id: String =
        s.chars().map(|c| if c.is_ascii_alphanumeric() || c == '-' || c == '_' { c } else { '-' }).take(32).collect();
    if id.is_empty() { "drive".into() } else { id }
}

/// Reads xorriso's `Media status :` line.
#[must_use]
pub fn parse_media_status(text: &str) -> MediaState {
    let Some(line) = text.lines().find(|l| l.trim_start().starts_with("Media status")) else {
        return if text.contains("No media") || text.contains("not present") {
            MediaState::NoDisc
        } else {
            MediaState::Unknown
        };
    };
    if line.contains("not present") || line.contains("is not") && line.contains("loaded") {
        MediaState::NoDisc
    } else if line.contains("blank") {
        MediaState::Blank
    } else if line.contains("appendable") {
        MediaState::Appendable
    } else if line.contains("closed") || line.contains("written") {
        MediaState::Complete
    } else {
        MediaState::Unknown
    }
}

/// Understands both progress styles xorriso prints in cdrecord emulation:
/// `Track 01:  120 of  700 MB written (fifo 100%) [buf  97%]  16.0x.` and the native
/// `xorriso : UPDATE : Writing:  12345s  42.1%  fifo 100%  buf  97%  16.0xD`.
#[must_use]
pub fn parse_progress_line(line: &str) -> Option<Progress> {
    let words: Vec<&str> = line.split_whitespace().collect();
    let fraction = if let Some(i) = words.iter().position(|w| *w == "of") {
        let done: f64 = words.get(i.checked_sub(1)?)?.parse().ok()?;
        let total: f64 = words.get(i + 1)?.parse().ok()?;
        if !line.contains("MB written") || total <= 0.0 {
            return None;
        }
        (done / total).clamp(0.0, 1.0)
    } else if line.contains("Writing") {
        first_percent(line)?
    } else {
        return None;
    };
    let percent_after = |key: &str| {
        let i = line.find(key)?;
        first_percent(line.get(i..)?)
    };
    let speed = words
        .iter()
        .rev()
        .find_map(|w| {
            let w = w.trim_end_matches('.');
            let w = w
                .strip_suffix("xD")
                .or_else(|| w.strip_suffix("xC"))
                .or_else(|| w.strip_suffix("xB"))
                .or_else(|| w.strip_suffix('x'))?;
            w.parse::<f64>().ok()
        })
        .unwrap_or(0.0);
    let mut p = Progress::new(Stage::Writing, Some(fraction), "Writing");
    p.fifo = percent_after("fifo").unwrap_or(0.0);
    p.buffer = percent_after("buf").unwrap_or(0.0);
    p.speed_x = speed;
    Some(p)
}

#[cfg(test)]
#[allow(clippy::unwrap_used)]
mod tests {
    use super::*;

    #[test]
    fn media_status_lines() {
        let blank = "Drive current: -outdev '/dev/sr0'\nMedia current: DVD+R\nMedia status : is blank\nMedia summary: 0 sessions";
        assert_eq!(parse_media_status(blank), MediaState::Blank);
        assert_eq!(parse_media_status("Media status : is written , is appendable"), MediaState::Appendable);
        assert_eq!(parse_media_status("Media status : is written , is closed"), MediaState::Complete);
        assert_eq!(parse_media_status("Media status : is not present"), MediaState::NoDisc);
        assert_eq!(parse_media_status("libburn : SORRY : No media detected"), MediaState::NoDisc);
        assert_eq!(parse_media_status("garbage"), MediaState::Unknown);
    }

    #[test]
    fn progress_lines() {
        let p = parse_progress_line("Track 01:  175 of  700 MB written (fifo 100%) [buf  97%]  16.0x.").unwrap();
        assert!((p.fraction.unwrap() - 0.25).abs() < 1e-9);
        assert!((p.fifo - 1.0).abs() < 1e-9);
        assert!((p.buffer - 0.97).abs() < 1e-9);
        assert!((p.speed_x - 16.0).abs() < 1e-9);
        let p = parse_progress_line("xorriso : UPDATE : Writing:     1234s   42.1%   fifo  88%  buf  97%    6.0xD")
            .unwrap();
        assert!((p.fraction.unwrap() - 0.421).abs() < 1e-9);
        assert!((p.fifo - 0.88).abs() < 1e-9);
        assert!((p.speed_x - 6.0).abs() < 1e-9);
        assert!(parse_progress_line("Starting to write CD/DVD at speed 16.0 in real SAO mode").is_none());
        assert!(
            parse_progress_line("Track 01: Total bytes read/written: 734003200/734003200 (358400 sectors).").is_none()
        );
        assert!(parse_progress_line("1 of 2 tracks").is_none());
    }

    #[test]
    fn discovers_drives_from_sysfs() {
        let tmp = crate::testutil::TempDir::new("sysfs");
        for (id, vendor, model) in
            [("sr1", "PIONEER ", "BD-RW BDR-XD08"), ("sr0", "ASUS", "SDRW-08D2S-U"), ("sda", "ATA", "Disk")]
        {
            let dev = tmp.path().join(id).join("device");
            std::fs::create_dir_all(&dev).unwrap();
            std::fs::write(dev.join("vendor"), vendor).unwrap();
            std::fs::write(dev.join("model"), model).unwrap();
        }
        let drives = LinuxBackend::with_sysfs(tmp.path().to_owned()).discover();
        assert_eq!(drives.len(), 2);
        assert_eq!(drives[0], Drive { id: "sr0".into(), name: "ASUS SDRW-08D2S-U".into(), device: "/dev/sr0".into() });
        assert_eq!(drives[1].name, "PIONEER BD-RW BDR-XD08");
    }
}
