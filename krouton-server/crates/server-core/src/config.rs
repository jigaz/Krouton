// MARK: - config.rs

//! `server.conf`: one `key = value` per line, `#` starts a comment. Unknown keys are errors (a
//! typo should not silently fall back to a default on a box that burns discs unattended).
//!
//! ```text
//! name = Basement Burner
//! listen = 0.0.0.0:7420
//! backend = auto              # auto | macos | linux | windows | simulate
//! max_image_gib = 128
//! min_free_gib = 2
//! allow_cgnat = false         # true to accept Tailscale/ZeroTier 100.64.0.0/10 peers
//! allow_range = 10.8.0.0/24   # extra trusted ranges (VPN subnets); repeatable
//! drive = /dev/sr1            # optional: only use these drives; repeatable
//! ```

use krsp::endpoint::{Cidr, EndpointPolicy};
use std::net::SocketAddr;
use std::path::{Path, PathBuf};

#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum BackendKind {
    Auto,
    MacOs,
    Linux,
    Windows,
    Simulate,
}

impl BackendKind {
    fn parse(s: &str) -> Option<Self> {
        Some(match s {
            "auto" => Self::Auto,
            "macos" => Self::MacOs,
            "linux" => Self::Linux,
            "windows" => Self::Windows,
            "simulate" => Self::Simulate,
            _ => return None,
        })
    }

    /// `Auto` resolved for the platform the binary was built for.
    #[must_use]
    pub fn resolved(self) -> Self {
        match self {
            Self::Auto if cfg!(target_os = "macos") => Self::MacOs,
            Self::Auto if cfg!(target_os = "windows") => Self::Windows,
            Self::Auto => Self::Linux,
            other => other,
        }
    }

    #[must_use]
    pub fn name(self) -> &'static str {
        match self {
            Self::Auto => "auto",
            Self::MacOs => "macos",
            Self::Linux => "linux",
            Self::Windows => "windows",
            Self::Simulate => "simulate",
        }
    }
}

#[derive(Clone, Debug)]
pub struct Config {
    pub name: String,
    pub listen: Vec<SocketAddr>,
    pub state_dir: PathBuf,
    pub spool_dir: PathBuf,
    pub backend: BackendKind,
    /// Explicit drive device paths/letters; empty = discover.
    pub drives: Vec<String>,
    pub max_image_bytes: u64,
    pub min_free_bytes: u64,
    pub allow_cgnat: bool,
    pub allow_ranges: Vec<Cidr>,
    pub max_connections: usize,
    pub simulate_drives: u32,
    pub simulate_seconds: u64,
    /// How long a failed or abandoned upload is kept for a retry or resume before it is deleted.
    pub keep_incomplete_hours: u64,
    pub xorriso: String,
    pub hdiutil: String,
    pub powershell: String,
}

const GIB: u64 = 1024 * 1024 * 1024;

impl Config {
    /// Defaults rooted at `state_dir` (where keys, paired clients and the spool live).
    #[must_use]
    pub fn defaults(state_dir: &Path) -> Self {
        Self {
            name: default_name(),
            listen: vec![SocketAddr::from(([0, 0, 0, 0], krsp::identity::DEFAULT_PORT))],
            state_dir: state_dir.to_owned(),
            spool_dir: state_dir.join("spool"),
            backend: BackendKind::Auto,
            drives: Vec::new(),
            max_image_bytes: 128 * GIB,
            min_free_bytes: 2 * GIB,
            allow_cgnat: false,
            allow_ranges: Vec::new(),
            max_connections: 16,
            simulate_drives: 2,
            simulate_seconds: 30,
            keep_incomplete_hours: 48,
            xorriso: "xorriso".into(),
            hdiutil: "/usr/bin/hdiutil".into(),
            powershell: "powershell.exe".into(),
        }
    }

    /// Parses `text`; relative paths resolve against `state_dir`.
    pub fn parse(text: &str, state_dir: &Path) -> Result<Self, String> {
        let mut c = Self::defaults(state_dir);
        let mut listen_seen = false;
        let mut spool_seen = false;
        for (n, raw) in text.lines().enumerate() {
            let line = raw.split('#').next().unwrap_or_default().trim();
            if line.is_empty() {
                continue;
            }
            let err = |m: &str| format!("server.conf line {}: {m}", n + 1);
            let (key, value) = line.split_once('=').ok_or_else(|| err("expected `key = value`"))?;
            let (key, value) = (key.trim(), value.trim());
            let number = || value.parse::<u64>().map_err(|_| err(&format!("{key} must be a whole number")));
            let boolean = || match value {
                "true" | "yes" | "on" => Ok(true),
                "false" | "no" | "off" => Ok(false),
                _ => Err(err(&format!("{key} must be true or false"))),
            };
            match key {
                "name" => {
                    if value.is_empty() || value.chars().count() > 64 {
                        return Err(err("name must be 1-64 characters"));
                    }
                    c.name = value.to_owned();
                }
                "listen" => {
                    if !listen_seen {
                        c.listen.clear();
                        listen_seen = true;
                    }
                    c.listen.push(value.parse().map_err(|_| err("listen must be address:port, e.g. 0.0.0.0:7420"))?);
                }
                "spool_dir" => {
                    c.spool_dir = state_dir.join(value);
                    spool_seen = true;
                }
                "backend" => {
                    c.backend = BackendKind::parse(value)
                        .ok_or_else(|| err("backend must be auto, macos, linux, windows or simulate"))?;
                }
                "drive" => c.drives.push(value.to_owned()),
                "max_image_gib" => c.max_image_bytes = number()?.saturating_mul(GIB),
                "min_free_gib" => c.min_free_bytes = number()?.saturating_mul(GIB),
                "allow_cgnat" => c.allow_cgnat = boolean()?,
                "allow_range" => {
                    let cidr =
                        Cidr::parse(value).ok_or_else(|| err("allow_range must be a CIDR block, e.g. 10.8.0.0/24"))?;
                    if !EndpointPolicy::is_acceptable_trusted_range(&cidr) {
                        return Err(err("allow_range is too broad (IPv4 needs /8 or longer, IPv6 /32 or longer)"));
                    }
                    c.allow_ranges.push(cidr);
                }
                "max_connections" => c.max_connections = usize::try_from(number()?.clamp(1, 256)).unwrap_or(16),
                "simulate_drives" => c.simulate_drives = u32::try_from(number()?.clamp(1, 8)).unwrap_or(1),
                "simulate_seconds" => c.simulate_seconds = number()?.clamp(1, 3600),
                "keep_incomplete_hours" => c.keep_incomplete_hours = number()?,
                "xorriso" => c.xorriso = value.to_owned(),
                "hdiutil" => c.hdiutil = value.to_owned(),
                "powershell" => c.powershell = value.to_owned(),
                other => return Err(err(&format!("unknown setting `{other}`"))),
            }
        }
        if !spool_seen {
            c.spool_dir = state_dir.join("spool");
        }
        Ok(c)
    }

    /// Which client source addresses may connect at all (before TLS).
    #[must_use]
    pub fn endpoint_policy(&self) -> EndpointPolicy {
        EndpointPolicy::new(self.allow_cgnat, self.allow_ranges.iter().copied())
    }

    /// A commented starter file for `krouton-server init`.
    #[must_use]
    pub fn starter_file(backend: BackendKind) -> String {
        format!(
            "# Krouton Server configuration. Restart the service after editing.\n\
             name = {}\n\
             listen = 0.0.0.0:{}\n\
             # auto picks hdiutil on macOS, xorriso on Linux and IMAPI2 on Windows.\n\
             # `simulate` exercises everything without a burner.\n\
             backend = {}\n\
             max_image_gib = 128\n\
             min_free_gib = 2\n\
             # Accept peers on Tailscale/ZeroTier (100.64.0.0/10):\n\
             allow_cgnat = false\n\
             # Extra trusted ranges, e.g. a WireGuard subnet:\n\
             # allow_range = 10.8.0.0/24\n\
             # Only use these drives (default: every drive found):\n\
             # drive = /dev/sr0\n",
            default_name(),
            krsp::identity::DEFAULT_PORT,
            backend.name()
        )
    }
}

/// The machine's host name, or a generic fallback.
#[must_use]
pub fn default_name() -> String {
    let from_env = std::env::var("COMPUTERNAME").or_else(|_| std::env::var("HOSTNAME")).ok();
    let from_file = || std::fs::read_to_string("/etc/hostname").ok().map(|s| s.trim().to_owned());
    from_env
        .or_else(from_file)
        .filter(|s| !s.is_empty())
        .map(|s| s.trim_end_matches(".local").chars().take(64).collect())
        .unwrap_or_else(|| "Krouton Server".into())
}

#[cfg(test)]
#[allow(clippy::unwrap_used)]
mod tests {
    use super::*;

    #[test]
    fn parses_starter_and_overrides() {
        let dir = Path::new("/srv/krouton");
        let starter = Config::parse(&Config::starter_file(BackendKind::Simulate), dir).unwrap();
        assert_eq!(starter.backend, BackendKind::Simulate);
        assert_eq!(starter.listen.len(), 1);
        assert_eq!(starter.spool_dir, dir.join("spool"));

        let c = Config::parse(
            "name = Pi Burner\nlisten = 0.0.0.0:7420\nlisten = [::]:7420 # v6 too\nallow_cgnat = yes\n\
             allow_range = 10.8.0.0/24\ndrive = /dev/sr1\nmax_image_gib = 1\nspool_dir = /mnt/usb/spool\n",
            dir,
        )
        .unwrap();
        assert_eq!(c.name, "Pi Burner");
        assert_eq!(c.listen.len(), 2);
        assert!(c.allow_cgnat);
        assert_eq!(c.allow_ranges.len(), 1);
        assert_eq!(c.drives, ["/dev/sr1"]);
        assert_eq!(c.max_image_bytes, GIB);
        assert_eq!(c.spool_dir, PathBuf::from("/mnt/usb/spool"));
    }

    #[test]
    fn rejects_typos_and_unsafe_values() {
        let dir = Path::new("/x");
        for bad in [
            "nmae = x",
            "backend = cdrecord",
            "allow_range = 0.0.0.0/0",
            "listen = 7420",
            "max_image_gib = lots",
            "oops",
        ] {
            assert!(Config::parse(bad, dir).is_err(), "{bad}");
        }
    }
}
