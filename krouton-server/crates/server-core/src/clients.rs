//! Paired Krouton installs, in `clients.list`: one line per Mac,
//! `<tls-key-pin hex> <ed25519 identity hex> <paired-at unix seconds> <device name>`.
//! To revoke a Mac, delete its line (or run `krouton-server unpair <name>`) and restart.

use krsp::{hex, unhex};
use std::path::{Path, PathBuf};
use std::sync::Mutex;

pub const CLIENTS_FILE: &str = "clients.list";

#[derive(Clone, Debug, PartialEq, Eq)]
pub struct ClientRecord {
    /// SHA-256 of the client's P-256 TLS key (X9.63).
    pub tls_pin: [u8; 32],
    /// The client's Ed25519 identity, which signs every session.
    pub identity: [u8; 32],
    pub paired_at: u64,
    pub name: String,
}

impl ClientRecord {
    /// Job ownership key: the identity, so a Mac keeps its jobs if it rotates its TLS key.
    #[must_use]
    pub fn owner(&self) -> String {
        hex(&self.identity)
    }

    fn line(&self) -> String {
        let name: String = self.name.chars().filter(|c| !c.is_control()).collect();
        format!("{} {} {} {}", hex(&self.tls_pin), hex(&self.identity), self.paired_at, name)
    }

    fn parse(line: &str) -> Option<Self> {
        let mut parts = line.trim().splitn(4, ' ');
        let tls_pin = unhex(parts.next()?)?.try_into().ok()?;
        let identity = unhex(parts.next()?)?.try_into().ok()?;
        let paired_at = parts.next()?.parse().ok()?;
        let name = parts.next().unwrap_or("Unnamed Mac").to_owned();
        Some(Self { tls_pin, identity, paired_at, name })
    }
}

#[derive(Debug)]
pub struct ClientStore {
    path: PathBuf,
    records: Mutex<Vec<ClientRecord>>,
}

impl ClientStore {
    /// Loads `clients.list` from `state_dir` (missing = no clients). Malformed lines are reported
    /// and skipped rather than trusted.
    pub fn load(state_dir: &Path) -> (Self, Vec<String>) {
        let path = state_dir.join(CLIENTS_FILE);
        let mut warnings = Vec::new();
        let mut records = Vec::new();
        if let Ok(text) = std::fs::read_to_string(&path) {
            for (n, line) in text.lines().enumerate() {
                if line.trim().is_empty() || line.trim_start().starts_with('#') {
                    continue;
                }
                match ClientRecord::parse(line) {
                    Some(r) => records.push(r),
                    None => warnings.push(format!("{} line {} is malformed and was ignored", CLIENTS_FILE, n + 1)),
                }
            }
        }
        (Self { path, records: Mutex::new(records) }, warnings)
    }

    #[must_use]
    pub fn by_pin(&self, pin: &[u8; 32]) -> Option<ClientRecord> {
        self.records.lock().ok()?.iter().find(|r| krsp::pairing::ct_eq(&r.tls_pin, pin)).cloned()
    }

    #[must_use]
    pub fn all(&self) -> Vec<ClientRecord> {
        self.records.lock().map(|r| r.clone()).unwrap_or_default()
    }

    /// Adds or replaces (same TLS pin or same identity) a client and saves the file.
    pub fn upsert(&self, record: ClientRecord) -> std::io::Result<()> {
        let mut records = self.records.lock().map_err(|_| std::io::Error::other("client store poisoned"))?;
        records.retain(|r| r.tls_pin != record.tls_pin && r.identity != record.identity);
        records.push(record);
        Self::save(&self.path, &records)
    }

    /// Removes clients whose name or pin prefix matches `which`; returns how many were removed.
    pub fn remove(&self, which: &str) -> std::io::Result<usize> {
        let mut records = self.records.lock().map_err(|_| std::io::Error::other("client store poisoned"))?;
        let before = records.len();
        records.retain(|r| {
            !(r.name.eq_ignore_ascii_case(which) || (which.len() >= 8 && hex(&r.tls_pin).starts_with(which)))
        });
        let removed = before - records.len();
        if removed > 0 {
            Self::save(&self.path, &records)?;
        }
        Ok(removed)
    }

    fn save(path: &Path, records: &[ClientRecord]) -> std::io::Result<()> {
        let mut text =
            String::from("# Paired Krouton apps: <tls pin> <identity> <paired at> <name>. Delete a line to revoke.\n");
        for r in records {
            text.push_str(&r.line());
            text.push('\n');
        }
        crate::store::write_atomically(path, text.as_bytes())?;
        crate::secure_permissions(path);
        Ok(())
    }
}

#[cfg(test)]
#[allow(clippy::unwrap_used)]
mod tests {
    use super::*;

    #[test]
    fn upsert_lookup_remove_persist() {
        let tmp = crate::testutil::TempDir::new("clients");
        let (store, warnings) = ClientStore::load(tmp.path());
        assert!(warnings.is_empty());
        let mac = ClientRecord { tls_pin: [1; 32], identity: [2; 32], paired_at: 5, name: "Studio Mac\nevil".into() };
        store.upsert(mac.clone()).unwrap();
        store
            .upsert(ClientRecord { tls_pin: [3; 32], identity: [4; 32], paired_at: 6, name: "Laptop".into() })
            .unwrap();
        std::fs::write(
            tmp.path().join(CLIENTS_FILE),
            std::fs::read_to_string(tmp.path().join(CLIENTS_FILE)).unwrap() + "garbage line\n",
        )
        .unwrap();

        let (reloaded, warnings) = ClientStore::load(tmp.path());
        assert_eq!(warnings.len(), 1);
        assert_eq!(reloaded.by_pin(&[1; 32]).unwrap().name, "Studio Macevil");
        assert!(reloaded.by_pin(&[9; 32]).is_none());
        // Re-pairing the same identity with a new TLS key replaces the old record.
        reloaded.upsert(ClientRecord { tls_pin: [7; 32], ..mac }).unwrap();
        assert!(reloaded.by_pin(&[1; 32]).is_none());
        assert_eq!(reloaded.all().len(), 2);
        assert_eq!(reloaded.remove("laptop").unwrap(), 1);
        assert_eq!(ClientStore::load(tmp.path()).0.all().len(), 1);
    }
}
