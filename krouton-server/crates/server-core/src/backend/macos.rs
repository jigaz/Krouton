//! macOS backend (macOS 12 Monterey or later, Intel or Apple Silicon): `hdiutil burn` with
//! `-puppetstrings` for machine-readable progress, `drutil` for discovery, media status and eject.
//! Both ship with macOS. DiscRecording needs a logged-in user session, so the installer sets the
//! server up as a LaunchAgent of the auto-login user rather than a system daemon.

use super::{Backend, BurnRequest, Drive, Progress, Stage, run_capture, run_tool};
use crate::config::BackendKind;
use krsp::control::MediaState;
use std::process::Command;
use std::sync::atomic::Ordering;

const DRUTIL: &str = "/usr/bin/drutil";

#[derive(Debug)]
pub struct MacBackend {
    hdiutil: String,
    explicit: Vec<String>,
}

impl MacBackend {
    #[must_use]
    pub fn new(hdiutil: String, explicit: Vec<String>) -> Self {
        Self { hdiutil, explicit }
    }

    fn burn_device_paths(&self) -> Vec<String> {
        let mut cmd = Command::new(&self.hdiutil);
        cmd.args(["burn", "-list"]);
        run_capture(cmd).map(|(_, text)| parse_hdiutil_list(&text)).unwrap_or_default()
    }

    fn drive_index(drive: &Drive) -> &str {
        drive.id.strip_prefix("mac-").unwrap_or("1")
    }
}

impl Backend for MacBackend {
    fn kind(&self) -> BackendKind {
        BackendKind::MacOs
    }

    fn discover(&self) -> Vec<Drive> {
        let mut cmd = Command::new(DRUTIL);
        cmd.arg("list");
        let listed = run_capture(cmd).map(|(_, text)| parse_drutil_list(&text)).unwrap_or_default();
        // hdiutil only needs `-device` when there is more than one burner; it then wants the
        // IOService path, which `hdiutil burn -list` prints in the same registry order.
        let paths =
            if self.explicit.is_empty() && listed.len() > 1 { self.burn_device_paths() } else { self.explicit.clone() };
        listed
            .into_iter()
            .enumerate()
            .map(|(i, (index, name))| Drive {
                id: format!("mac-{index}"),
                name,
                device: paths.get(i).cloned().unwrap_or_default(),
            })
            .collect()
    }

    fn media(&self, drive: &Drive) -> MediaState {
        let mut cmd = Command::new(DRUTIL);
        cmd.args(["status", "-drive", Self::drive_index(drive)]);
        run_capture(cmd).map_or(MediaState::Unknown, |(_, text)| parse_drutil_status(&text))
    }

    fn burn(&self, request: &BurnRequest<'_>, progress: &mut dyn FnMut(Progress)) -> Result<(), String> {
        let o = request.options;
        let mut cmd = Command::new(&self.hdiutil);
        cmd.arg("burn").arg(request.image).arg("-puppetstrings");
        cmd.arg(if o.verify { "-verifyburn" } else { "-noverifyburn" });
        cmd.arg(if o.eject { "-eject" } else { "-noeject" });
        if o.speed > 0 {
            cmd.args(["-speed", &o.speed.to_string()]);
        }
        if o.simulate {
            cmd.arg("-testburn");
        }
        if !request.drive.device.is_empty() {
            cmd.args(["-device", &request.drive.device]);
        }
        let write_share = if o.verify && !o.simulate { 0.8 } else { 1.0 };
        let mut stage = Stage::Preparing;
        let mut message = String::from("Preparing");
        let mut errors: Vec<String> = Vec::new();
        progress(Progress::new(Stage::Preparing, Some(0.0), "Starting hdiutil"));
        let code = run_tool(cmd, request.cancel, &mut |line| match parse_puppet_line(line) {
            Some(Puppet::Message(m)) => {
                if m.contains("Verif") {
                    stage = Stage::Verifying;
                } else if m.contains("Writing") || m.contains("Burning") {
                    stage = Stage::Writing;
                }
                message.clone_from(&m);
                progress(Progress::new(stage, None, m));
            }
            Some(Puppet::Percent(p)) => {
                let fraction = p.map(|p| match stage {
                    Stage::Verifying => write_share + (1.0 - write_share) * p,
                    _ => p * write_share,
                });
                progress(Progress::new(stage, fraction, message.clone()));
            }
            None => {
                if line.contains("failed") || line.contains("error") || line.contains("Error") {
                    errors.push(line.trim().to_owned());
                }
            }
        })
        .map_err(|e| format!("Could not run {}: {e}", self.hdiutil))?;
        if request.cancel.load(Ordering::SeqCst) {
            return Err("Cancelled during the write; the disc is probably unusable".into());
        }
        if code == Some(0) {
            Ok(())
        } else if errors.is_empty() {
            Err(format!("hdiutil burn failed (exit {})", code.map_or("signal".into(), |c| c.to_string())))
        } else {
            Err(errors.join(" | "))
        }
    }

    fn eject(&self, drive: &Drive) -> Result<(), String> {
        let mut cmd = Command::new(DRUTIL);
        cmd.args(["eject", "-drive", Self::drive_index(drive)]);
        match run_capture(cmd) {
            Ok((Some(0), _)) => Ok(()),
            Ok((_, text)) => Err(text.trim().to_owned()),
            Err(e) => Err(e.to_string()),
        }
    }

    fn diagnose(&self) -> Vec<String> {
        let mut problems = Vec::new();
        if !std::path::Path::new(&self.hdiutil).exists() {
            problems.push(format!("{} not found", self.hdiutil));
        }
        if self.discover().is_empty() {
            problems.push("`drutil list` shows no burners (is the drive connected and powered?)".into());
        }
        problems
    }
}

#[derive(Debug, PartialEq)]
pub enum Puppet {
    /// `None` = indeterminate (hdiutil prints -1).
    Percent(Option<f64>),
    Message(String),
}

#[must_use]
pub fn parse_puppet_line(line: &str) -> Option<Puppet> {
    let line = line.trim();
    if let Some(p) = line.strip_prefix("PERCENT:") {
        let v: f64 = p.trim().parse().ok()?;
        return Some(Puppet::Percent((0.0..=100.0).contains(&v).then_some(v / 100.0)));
    }
    line.strip_prefix("MESSAGE:").map(|m| Puppet::Message(m.trim().to_owned()))
}

/// `drutil list` rows: `1  PIONEER  BD-RW   BDR-XD07  1.04  USB  Unsupported`.
#[must_use]
pub fn parse_drutil_list(text: &str) -> Vec<(String, String)> {
    text.lines()
        .filter_map(|line| {
            let words: Vec<&str> = line.split_whitespace().collect();
            let index = words.first()?;
            if !index.chars().all(|c| c.is_ascii_digit()) || words.len() < 5 {
                return None;
            }
            // Columns: index, vendor + product (several words), Rev, Bus, SupportLevel (one or two
            // words, e.g. "Unsupported" or "Apple Shipping"). Anchor on the bus column.
            const BUSES: [&str; 7] = ["USB", "ATAPI", "SATA", "FireWire", "SCSI", "Thunderbolt", "PCIe"];
            let bus = words.iter().rposition(|w| BUSES.contains(w)).unwrap_or(words.len().saturating_sub(2));
            let name = words.get(1..bus.checked_sub(1)?)?.join(" ");
            (!name.is_empty()).then(|| ((*index).to_owned(), name))
        })
        .collect()
}

/// `hdiutil burn -list` prints one `IOService:/…` path per burner.
#[must_use]
pub fn parse_hdiutil_list(text: &str) -> Vec<String> {
    text.lines().map(str::trim).filter(|l| l.starts_with("IOService:")).map(str::to_owned).collect()
}

#[must_use]
pub fn parse_drutil_status(text: &str) -> MediaState {
    if text.contains("No Media") || text.contains("No media") {
        return MediaState::NoDisc;
    }
    let writability = text.lines().find(|l| l.contains("Writability")).unwrap_or_default().to_ascii_lowercase();
    if writability.contains("blank") {
        MediaState::Blank
    } else if writability.contains("appendable") {
        MediaState::Appendable
    } else if text.contains("Type:") {
        MediaState::Complete
    } else {
        MediaState::Unknown
    }
}

#[cfg(test)]
#[allow(clippy::unwrap_used)]
mod tests {
    use super::*;

    #[test]
    fn puppetstrings() {
        assert_eq!(parse_puppet_line("PERCENT:12.500000"), Some(Puppet::Percent(Some(0.125))));
        assert_eq!(parse_puppet_line("PERCENT:-1.000000"), Some(Puppet::Percent(None)));
        assert_eq!(parse_puppet_line("MESSAGE:Verifying burn…"), Some(Puppet::Message("Verifying burn…".into())));
        assert_eq!(parse_puppet_line("hdiutil: burn failed - No media"), None);
    }

    #[test]
    fn drutil_output() {
        let list = "   Vendor   Product           Rev   Bus       SupportLevel\n\
                    1  PIONEER  BD-RW   BDR-XD07  1.04  USB       Unsupported\n\
                    2  HL-DT-ST DVDRW  GX50N      RR06  USB       Apple Shipping\n";
        let drives = parse_drutil_list(list);
        assert_eq!(
            drives,
            vec![("1".into(), "PIONEER BD-RW BDR-XD07".into()), ("2".into(), "HL-DT-ST DVDRW GX50N".into())]
        );
        assert_eq!(parse_drutil_status(" Vendor   Product\n Type: No Media Inserted"), MediaState::NoDisc);
        assert_eq!(
            parse_drutil_status("           Type: DVD+R\n    Writability: appendable, blank"),
            MediaState::Blank
        );
        assert_eq!(parse_drutil_status("           Type: CD-R\n    Writability: appendable"), MediaState::Appendable);
        assert_eq!(parse_drutil_status("           Type: DVD-ROM\n"), MediaState::Complete);
        assert_eq!(
            parse_hdiutil_list("IOService:/AppleARMPE/arm-io/IODVDServices\n\tPIONEER BD-RW\n"),
            vec!["IOService:/AppleARMPE/arm-io/IODVDServices".to_string()]
        );
    }
}
