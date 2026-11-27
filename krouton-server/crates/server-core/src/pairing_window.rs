//! The operator side of pairing. `krouton-server pair` (run in a terminal on the server, or over
//! SSH) opens a short pairing window and asks the operator to confirm the code; the running
//! service handles the network side. They talk through small files in `<state>/pairing/`, which
//! only the service account can write, so pairing needs both physical/SSH access to the server
//! and the person at the Mac agreeing that the codes match.
//!
//! | File | Written by | Contents |
//! |---|---|---|
//! | `open` | CLI | Unix time the window closes |
//! | `request` | service | `<code>\n<device name>` once a Mac reaches the code step |
//! | `decision` | CLI | `yes` or `no` |
//! | `result` | service | a one-line outcome for the CLI to print |

use std::path::{Path, PathBuf};
use std::time::{Duration, SystemTime, UNIX_EPOCH};

#[derive(Clone, Debug)]
pub struct PairingWindow {
    dir: PathBuf,
}

#[must_use]
pub fn unix_now() -> u64 {
    SystemTime::now().duration_since(UNIX_EPOCH).map_or(0, |d| d.as_secs())
}

impl PairingWindow {
    #[must_use]
    pub fn new(state_dir: &Path) -> Self {
        Self { dir: state_dir.join("pairing") }
    }

    fn file(&self, name: &str) -> PathBuf {
        self.dir.join(name)
    }

    fn read(&self, name: &str) -> Option<String> {
        std::fs::read_to_string(self.file(name)).ok()
    }

    fn write(&self, name: &str, text: &str) -> std::io::Result<()> {
        std::fs::create_dir_all(&self.dir)?;
        crate::secure_permissions(&self.dir);
        crate::store::write_atomically(&self.file(name), text.as_bytes())
    }

    // MARK: CLI side

    /// Opens the window for `duration`, clearing any stale exchange.
    pub fn open(&self, duration: Duration) -> std::io::Result<()> {
        self.close();
        self.write("open", &(unix_now() + duration.as_secs()).to_string())
    }

    /// Waits for a Mac to reach the code step. Returns `(code, device name)`.
    #[must_use]
    pub fn wait_request(&self, timeout: Duration) -> Option<(String, String)> {
        poll(timeout, || {
            let text = self.read("request")?;
            let (code, name) = text.split_once('\n')?;
            Some((code.trim().to_owned(), name.trim().to_owned()))
        })
    }

    pub fn decide(&self, accept: bool) -> std::io::Result<()> {
        self.write("decision", if accept { "yes" } else { "no" })
    }

    #[must_use]
    pub fn wait_result(&self, timeout: Duration) -> Option<String> {
        poll(timeout, || self.read("result"))
    }

    pub fn close(&self) {
        for name in ["open", "request", "decision", "result"] {
            let _ = crate::store::remove_if_exists(&self.file(name));
        }
    }

    // MARK: Service side

    #[must_use]
    pub fn is_open(&self) -> bool {
        self.read("open").and_then(|t| t.trim().parse::<u64>().ok()).is_some_and(|until| until > unix_now())
    }

    pub fn post_request(&self, code: &str, device: &str) -> std::io::Result<()> {
        let device: String = device.chars().filter(|c| !c.is_control()).take(64).collect();
        self.write("request", &format!("{code}\n{device}"))
    }

    /// `None` until the operator has answered.
    #[must_use]
    pub fn decision(&self) -> Option<bool> {
        self.read("decision").map(|d| d.trim() == "yes")
    }

    pub fn post_result(&self, text: &str) {
        let _ = self.write("result", text);
        let _ = crate::store::remove_if_exists(&self.file("open"));
        let _ = crate::store::remove_if_exists(&self.file("request"));
        let _ = crate::store::remove_if_exists(&self.file("decision"));
    }
}

fn poll<T>(timeout: Duration, mut f: impl FnMut() -> Option<T>) -> Option<T> {
    let deadline = std::time::Instant::now() + timeout;
    loop {
        if let Some(v) = f() {
            return Some(v);
        }
        if std::time::Instant::now() >= deadline {
            return None;
        }
        std::thread::sleep(Duration::from_millis(200));
    }
}

#[cfg(test)]
#[allow(clippy::unwrap_used)]
mod tests {
    use super::*;

    #[test]
    fn full_exchange() {
        let tmp = crate::testutil::TempDir::new("pairing");
        let cli = PairingWindow::new(tmp.path());
        let service = PairingWindow::new(tmp.path());
        assert!(!service.is_open());
        cli.open(Duration::from_secs(60)).unwrap();
        assert!(service.is_open());
        assert_eq!(cli.wait_request(Duration::from_millis(10)), None);
        service.post_request("042917", "Studio\nMac").unwrap();
        assert_eq!(cli.wait_request(Duration::from_secs(1)), Some(("042917".into(), "StudioMac".into())));
        assert_eq!(service.decision(), None);
        cli.decide(true).unwrap();
        assert_eq!(service.decision(), Some(true));
        service.post_result("Paired StudioMac");
        assert!(!service.is_open());
        assert_eq!(cli.wait_result(Duration::from_secs(1)).as_deref(), Some("Paired StudioMac"));
        cli.close();
        assert_eq!(cli.wait_result(Duration::from_millis(1)), None);
    }
}
