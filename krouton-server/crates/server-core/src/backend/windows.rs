//! Windows 10/11 backend (x86 and x64): IMAPI2, the burn engine built into Windows, driven by a
//! small PowerShell script the server writes next to its state. Arguments are passed as separate
//! `-File` parameters (never spliced into script text), and drive letters are validated first.
//!
//! IMAPI2's `Write` is synchronous and its progress events do not reach a non-interactive
//! PowerShell host, so writing shows as indeterminate; read-back verification reports a real
//! percentage afterwards.

use super::{Backend, BurnRequest, Drive, Progress, Stage, run_capture, run_tool, verify_readback};
use crate::config::BackendKind;
use krsp::control::MediaState;
use std::path::{Path, PathBuf};
use std::process::Command;
use std::sync::atomic::Ordering;

const SCRIPT_NAME: &str = "krouton-imapi2.ps1";

/// The IMAPI2 helper. `MEDIA:`, `DRIVE:`, `MESSAGE:` and `ERROR:` prefixes are parsed by the server.
pub const IMAPI2_SCRIPT: &str = r#"param(
  [Parameter(Mandatory = $true)][ValidateSet('list', 'status', 'burn', 'eject')][string]$Action,
  [string]$Drive = '',
  [string]$Image = ''
)
$ErrorActionPreference = 'Stop'
function Find-Recorder([string]$Letter) {
  $master = New-Object -ComObject IMAPI2.MsftDiscMaster2
  foreach ($id in $master) {
    $r = New-Object -ComObject IMAPI2.MsftDiscRecorder2
    $r.InitializeDiscRecorder($id)
    foreach ($p in $r.VolumePathNames) { if ($p.TrimEnd('\') -ieq $Letter) { return $r } }
  }
  throw "No disc burner at $Letter"
}
try {
  switch ($Action) {
    'list' {
      $master = New-Object -ComObject IMAPI2.MsftDiscMaster2
      foreach ($id in $master) {
        $r = New-Object -ComObject IMAPI2.MsftDiscRecorder2
        $r.InitializeDiscRecorder($id)
        $letter = $r.VolumePathNames | Select-Object -First 1
        if ($letter) { Write-Output ('DRIVE:{0}|{1} {2}' -f $letter.TrimEnd('\'), $r.VendorId.Trim(), $r.ProductId.Trim()) }
      }
    }
    'status' {
      $r = Find-Recorder $Drive
      $f = New-Object -ComObject IMAPI2.MsftDiscFormat2Data
      if (-not $f.IsCurrentMediaSupported($r)) { Write-Output 'MEDIA:noDisc'; break }
      $f.Recorder = $r
      $s = [int]$f.CurrentMediaStatus
      if ($s -band 0x2) { Write-Output 'MEDIA:blank' }
      elseif ($s -band 0x4) { Write-Output 'MEDIA:appendable' }
      else { Write-Output 'MEDIA:complete' }
    }
    'burn' {
      Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
using System.Runtime.InteropServices.ComTypes;
public static class KroutonStream {
  [DllImport("shlwapi.dll", CharSet = CharSet.Unicode, ExactSpelling = true, PreserveSig = false)]
  static extern void SHCreateStreamOnFileEx(string file, uint mode, uint attributes, bool create, IStream template, out IStream stream);
  public static IStream Open(string path) { IStream s; SHCreateStreamOnFileEx(path, 0x20, 0x80, false, null, out s); return s; }
}
'@
      $r = Find-Recorder $Drive
      $f = New-Object -ComObject IMAPI2.MsftDiscFormat2Data
      $f.Recorder = $r
      $f.ClientName = 'Krouton Server'
      $f.ForceMediaToBeClosed = $true
      if (-not $f.MediaHeuristicallyBlank) { throw 'The disc in the drive is not blank' }
      $stream = [KroutonStream]::Open($Image)
      Write-Output 'MESSAGE:Writing'
      $f.Write($stream)
      Write-Output 'MESSAGE:Written'
    }
    'eject' { (Find-Recorder $Drive).EjectMedia() }
  }
  exit 0
} catch {
  Write-Output ('ERROR:' + $_.Exception.Message)
  exit 1
}
"#;

#[derive(Debug)]
pub struct WindowsBackend {
    powershell: String,
    state_dir: PathBuf,
    explicit: Vec<String>,
}

impl WindowsBackend {
    #[must_use]
    pub fn new(powershell: String, state_dir: PathBuf, explicit: Vec<String>) -> Self {
        Self { powershell, state_dir, explicit }
    }

    fn script(&self) -> Result<PathBuf, String> {
        let path = self.state_dir.join(SCRIPT_NAME);
        if std::fs::read_to_string(&path).ok().as_deref() != Some(IMAPI2_SCRIPT) {
            crate::store::write_atomically(&path, IMAPI2_SCRIPT.as_bytes())
                .map_err(|e| format!("Could not write {}: {e}", path.display()))?;
        }
        Ok(path)
    }

    fn command(&self, action: &str, drive: Option<&str>, image: Option<&Path>) -> Result<Command, String> {
        let mut cmd = Command::new(&self.powershell);
        cmd.args(["-NoProfile", "-NonInteractive", "-ExecutionPolicy", "Bypass", "-File"]);
        cmd.arg(self.script()?);
        cmd.args(["-Action", action]);
        if let Some(d) = drive {
            if !is_drive_letter(d) {
                return Err(format!("{d:?} is not a drive letter"));
            }
            cmd.args(["-Drive", d]);
        }
        if let Some(i) = image {
            cmd.arg("-Image").arg(i);
        }
        Ok(cmd)
    }
}

/// `D:` style, nothing else.
#[must_use]
pub fn is_drive_letter(s: &str) -> bool {
    let b = s.as_bytes();
    b.len() == 2 && b.first().is_some_and(u8::is_ascii_alphabetic) && b.get(1) == Some(&b':')
}

/// Parses `DRIVE:D:|PIONEER BD-RW BDR-XD08` lines.
#[must_use]
pub fn parse_drive_lines(text: &str) -> Vec<Drive> {
    text.lines()
        .filter_map(|l| {
            let (letter, name) = l.trim().strip_prefix("DRIVE:")?.split_once('|')?;
            let letter = letter.trim().to_ascii_uppercase();
            is_drive_letter(&letter).then(|| Drive {
                id: letter.trim_end_matches(':').to_owned(),
                name: if name.trim().is_empty() { format!("Drive {letter}") } else { name.trim().to_owned() },
                device: letter.clone(),
            })
        })
        .collect()
}

#[must_use]
pub fn parse_media_line(text: &str) -> MediaState {
    text.lines().find_map(|l| l.trim().strip_prefix("MEDIA:")).map_or(MediaState::Unknown, MediaState::from_wire)
}

impl Backend for WindowsBackend {
    fn kind(&self) -> BackendKind {
        BackendKind::Windows
    }

    fn discover(&self) -> Vec<Drive> {
        let found = self
            .command("list", None, None)
            .ok()
            .and_then(|cmd| run_capture(cmd).ok())
            .map(|(_, text)| parse_drive_lines(&text))
            .unwrap_or_default();
        if self.explicit.is_empty() {
            return found;
        }
        found.into_iter().filter(|d| self.explicit.iter().any(|e| e.eq_ignore_ascii_case(&d.device))).collect()
    }

    fn media(&self, drive: &Drive) -> MediaState {
        self.command("status", Some(&drive.device), None)
            .ok()
            .and_then(|cmd| run_capture(cmd).ok())
            .map_or(MediaState::Unknown, |(_, text)| parse_media_line(&text))
    }

    fn burn(&self, request: &BurnRequest<'_>, progress: &mut dyn FnMut(Progress)) -> Result<(), String> {
        let o = request.options;
        if o.simulate {
            return Err("Test burns are not supported by Windows IMAPI2; untick Simulate".into());
        }
        let cmd = self.command("burn", Some(&request.drive.device), Some(request.image))?;
        let write_share = if o.verify { 0.7 } else { 1.0 };
        let mut error = None;
        progress(Progress::new(Stage::Preparing, Some(0.0), "Starting IMAPI2"));
        let code = run_tool(cmd, request.cancel, &mut |line| {
            let line = line.trim();
            if let Some(m) = line.strip_prefix("MESSAGE:") {
                let done = m == "Written";
                progress(Progress::new(Stage::Writing, done.then_some(write_share), m));
            } else if let Some(e) = line.strip_prefix("ERROR:") {
                error = Some(e.to_owned());
            }
        })
        .map_err(|e| format!("Could not run PowerShell: {e}"))?;
        if request.cancel.load(Ordering::SeqCst) {
            return Err("Cancelled during the write; the disc is probably unusable".into());
        }
        if code != Some(0) {
            return Err(error.unwrap_or_else(|| "IMAPI2 burn failed".into()));
        }
        if o.verify {
            let raw = PathBuf::from(format!(r"\\.\{}", request.drive.device));
            verify_readback(&raw, request.image, request.image_bytes, request.cancel, write_share, progress)?;
        }
        if o.eject {
            let _ = self.eject(request.drive);
        }
        Ok(())
    }

    fn eject(&self, drive: &Drive) -> Result<(), String> {
        let cmd = self.command("eject", Some(&drive.device), None)?;
        match run_capture(cmd) {
            Ok((Some(0), _)) => Ok(()),
            Ok((_, text)) => {
                Err(text.lines().find_map(|l| l.strip_prefix("ERROR:")).unwrap_or("eject failed").to_owned())
            }
            Err(e) => Err(e.to_string()),
        }
    }

    fn diagnose(&self) -> Vec<String> {
        let mut problems = Vec::new();
        if let Err(e) = self.script() {
            problems.push(e);
        }
        if self.discover().is_empty() {
            problems.push(
                "IMAPI2 reports no disc burners (is the drive connected? is the service running as an administrator?)"
                    .into(),
            );
        }
        problems
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn parses_helper_output() {
        let drives = parse_drive_lines("DRIVE:e:|PIONEER BD-RW BDR-XD08\r\nnoise\r\nDRIVE:F:| \r\nDRIVE:../x|bad\r\n");
        assert_eq!(drives.len(), 2);
        assert_eq!(drives.first().map(|d| (d.id.as_str(), d.device.as_str())), Some(("E", "E:")));
        assert_eq!(drives.get(1).map(|d| d.name.as_str()), Some("Drive F:"));
        assert_eq!(parse_media_line("MEDIA:blank\r\n"), MediaState::Blank);
        assert_eq!(parse_media_line("ERROR:x"), MediaState::Unknown);
        assert!(is_drive_letter("Z:"));
        assert!(!is_drive_letter("ZZ:") && !is_drive_letter("C:\\") && !is_drive_letter("1:"));
    }

    #[test]
    fn script_takes_parameters_never_interpolated_text() {
        assert!(IMAPI2_SCRIPT.starts_with("param("));
        assert!(!IMAPI2_SCRIPT.contains("Invoke-Expression"));
    }
}
