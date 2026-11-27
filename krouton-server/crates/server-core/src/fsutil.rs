//! Free-space queries without `unsafe`: `df -Pk` on Unix (macOS, Linux, BusyBox) and PowerShell
//! on Windows. Both are present on every supported system.

use std::path::Path;
use std::process::Command;

/// Bytes available to unprivileged writers on the file system holding `path`, or `None` if the
/// query fails (callers then refuse uploads rather than guess).
#[must_use]
pub fn free_bytes(path: &Path) -> Option<u64> {
    let probe = existing_ancestor(path)?;
    #[cfg(windows)]
    {
        // The path travels in an environment variable, never in the command text.
        let mut cmd = Command::new("powershell.exe");
        cmd.args([
            "-NoProfile",
            "-NonInteractive",
            "-Command",
            "(Get-Item -LiteralPath $env:KROUTON_FREE_PATH).PSDrive.Free",
        ]);
        cmd.env("KROUTON_FREE_PATH", probe);
        let (_, out) = crate::backend::run_capture(cmd).ok()?;
        out.lines().find_map(|l| l.trim().parse().ok())
    }
    #[cfg(not(windows))]
    {
        let mut cmd = Command::new("df");
        cmd.arg("-Pk").arg(probe);
        let (_, out) = crate::backend::run_capture(cmd).ok()?;
        parse_df(&out)
    }
}

fn existing_ancestor(path: &Path) -> Option<&Path> {
    path.ancestors().find(|p| p.exists())
}

/// POSIX `df -Pk`: the 4th column of the last line is available 1024-byte blocks.
#[must_use]
pub fn parse_df(text: &str) -> Option<u64> {
    let line = text.lines().rfind(|l| !l.trim().is_empty())?;
    let kb: u64 = line.split_whitespace().nth(3)?.parse().ok()?;
    kb.checked_mul(1024)
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn parses_posix_df() {
        let out = "Filesystem     1024-blocks      Used Available Capacity Mounted on\n/dev/root        30298612  6000000  22985368      21% /\n";
        assert_eq!(parse_df(out), Some(22_985_368 * 1024));
        assert_eq!(parse_df("garbage"), None);
    }

    #[cfg(unix)]
    #[test]
    fn queries_the_real_temp_dir() {
        assert!(free_bytes(&std::env::temp_dir().join("does/not/exist/yet")).is_some_and(|b| b > 0));
    }
}
