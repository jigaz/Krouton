//! Node identity encodings: node ID, Bonjour TXT hints and the mTLS key pin. Only hashing and
//! encoding here; key generation and signatures live in the `krouton-server` crate.

use crate::sha256::Sha256;
use std::collections::BTreeMap;

pub const SERVICE_TYPE: &str = "_krouton-spool._tcp";
pub const DEFAULT_PORT: u16 = 7420;

pub mod caps {
    pub const WRITES_CD: u32 = 1 << 0;
    pub const WRITES_DVD: u32 = 1 << 1;
    pub const WRITES_BD: u32 = 1 << 2;
    pub const RESCUE_READS: u32 = 1 << 3;
    pub const ROLLING_SPOOL: u32 = 1 << 4;
    pub const KNOWN: u32 = WRITES_CD | WRITES_DVD | WRITES_BD | RESCUE_READS | ROLLING_SPOOL;
    pub const WRITES_ANY: u32 = WRITES_CD | WRITES_DVD | WRITES_BD;

    /// The largest image each disc family holds: a 99-minute CD-R, a dual-layer DVD±R, a
    /// quad-layer BD-R XL.
    pub const CD_MAX_BYTES: u64 = 912_384_000;
    pub const DVD_MAX_BYTES: u64 = 8_547_991_552;
    pub const BD_MAX_BYTES: u64 = 128_001_769_472;

    /// The disc families (`WRITES_*` bits) whose largest disc holds an image of `bytes`.
    #[must_use]
    pub const fn families_holding(bytes: u64) -> u32 {
        let mut families = 0;
        if bytes <= CD_MAX_BYTES {
            families |= WRITES_CD;
        }
        if bytes <= DVD_MAX_BYTES {
            families |= WRITES_DVD;
        }
        if bytes <= BD_MAX_BYTES {
            families |= WRITES_BD;
        }
        families
    }

    /// Names a set of `WRITES_*` bits for people: "CD and DVD".
    #[must_use]
    pub fn describe(writes: u32) -> String {
        let names: Vec<&str> = [(WRITES_CD, "CD"), (WRITES_DVD, "DVD"), (WRITES_BD, "Blu-ray")]
            .into_iter()
            .filter(|(bit, _)| writes & bit != 0)
            .map(|(_, name)| name)
            .collect();
        match names.as_slice() {
            [] => "no discs".to_owned(),
            [one] => (*one).to_owned(),
            [rest @ .., last] => format!("{} and {last}", rest.join(", ")),
        }
    }
}

const BASE32: &[u8; 32] = b"abcdefghijklmnopqrstuvwxyz234567";

/// Lowercase RFC 4648 base32 without padding.
#[must_use]
pub fn base32_lower(bytes: &[u8]) -> String {
    let mut out = String::with_capacity(bytes.len().div_ceil(5) * 8);
    let mut buffer: u32 = 0;
    let mut bits: u32 = 0;
    for byte in bytes {
        buffer = ((buffer & ((1 << bits) - 1)) << 8) | u32::from(*byte);
        bits += 8;
        while bits >= 5 {
            out.push(BASE32.get(((buffer >> (bits - 5)) & 31) as usize).map_or('?', |b| char::from(*b)));
            bits -= 5;
        }
    }
    if bits > 0 {
        out.push(BASE32.get(((buffer << (5 - bits)) & 31) as usize).map_or('?', |b| char::from(*b)));
    }
    out
}

/// 26 characters: base32 of the first 16 bytes of SHA-256 over the raw 32-byte Ed25519 public key.
#[must_use]
pub fn node_id(ed25519_public: &[u8; 32]) -> String {
    let digest = Sha256::digest(&[ed25519_public]);
    base32_lower(digest.get(..16).unwrap_or(&[]))
}

#[must_use]
pub fn is_well_formed_node_id(id: &str) -> bool {
    id.len() == 26 && id.bytes().all(|b| BASE32.contains(&b))
}

/// The mTLS pin: SHA-256 over the 65-byte X9.63 uncompressed P-256 public key (`04 || X || Y`),
/// the same bytes `SecKeyCopyExternalRepresentation` returns on the Swift side.
#[must_use]
pub fn tls_key_pin(p256_x963: &[u8]) -> Option<[u8; 32]> {
    (p256_x963.len() == 65 && p256_x963.first() == Some(&0x04)).then(|| Sha256::digest(&[p256_x963]))
}

/// Unauthenticated Bonjour hints. Used to group browse results and decide whether to connect,
/// never to make a trust decision: the session's TLS pin proves who the peer is.
#[derive(Clone, Debug, PartialEq, Eq)]
pub struct TxtHints {
    pub node_id: String,
    pub protocol_version: u8,
    pub capabilities: u32,
}

impl TxtHints {
    #[must_use]
    pub fn to_pairs(&self) -> Vec<(&'static str, String)> {
        vec![
            ("txtvers", "1".to_owned()),
            ("pv", self.protocol_version.to_string()),
            ("id", self.node_id.clone()),
            ("caps", format!("{:x}", self.capabilities)),
        ]
    }

    /// Strict: unknown txtvers, a malformed id or capability bits we don't know are all refused, so
    /// a hostile advertisement cannot smuggle state into the UI.
    #[must_use]
    pub fn parse(pairs: &BTreeMap<String, String>) -> Option<Self> {
        if pairs.get("txtvers").map(String::as_str) != Some("1") {
            return None;
        }
        let protocol_version: u8 = pairs.get("pv")?.parse().ok()?;
        let node_id = pairs.get("id")?.clone();
        let capabilities = u32::from_str_radix(pairs.get("caps")?, 16).ok()?;
        (is_well_formed_node_id(&node_id) && capabilities & !caps::KNOWN == 0).then_some(Self {
            node_id,
            protocol_version,
            capabilities,
        })
    }
}

// MARK: - Session proof (channel binding)

/// TLS 1.3 exporter label both sides use for the session proof (`SpoolTLS.exporterLabel`).
pub const EXPORTER_LABEL: &[u8] = b"EXPORTER-krouton-spool-session";
/// Role the server signs as.
pub const ROLE_NODE: &str = "node";
/// Role the Krouton app signs as.
pub const ROLE_WORKSTATION: &str = "workstation";

/// `"krouton-spool-session-v1|" ‖ role ‖ "|" ‖ exporter`, the bytes each side signs with its
/// Ed25519 identity. The role stops a signature being reflected back at its author.
#[must_use]
pub fn session_proof_message(exporter: &[u8], role: &str) -> Vec<u8> {
    [b"krouton-spool-session-v1|".as_slice(), role.as_bytes(), b"|", exporter].concat()
}
