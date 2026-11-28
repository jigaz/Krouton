#![forbid(unsafe_code)]
//! `krsp`: the sans-I/O protocol core of Krouton Server.
//!
//! KRSP v1 is the protocol between the Krouton app (Swift, `Sources/NetworkSpool`) and Krouton
//! Server. This crate holds the protocol's rules and nothing else. Everything here is a pure
//! function or a state machine with no sockets, files, threads or clocks. Time and bytes are
//! passed in, so the tests can drive every rule deterministically.
//!
//! Zero third-party dependencies, so it builds and tests offline on any target.
//!
//! # How the pieces fit
//!
//! | Layer | Modules |
//! |---|---|
//! | Wire format | [`frame`] (the 64-byte header), [`json`] (a strict JSON codec), [`control`] (every JSON control message and the session sequence) |
//! | Uploads | [`manifest`] (content-addressed extents, Merkle root, commit journal), [`pipeline`] (the receiver and sender state machines) |
//! | Folders | [`bundle`] (the tar subset a client uses to send a folder) |
//! | Trust | [`identity`] (node ID, key pins, session proofs), [`pairing`] (commit-then-reveal code comparison), [`endpoint`] (which source addresses may connect) |
//! | Helpers | [`sha256`] (portable SHA-256), [`telemetry`] (burn progress samples) |
//! | Not used by the server yet | [`lease`] (fenced drive leases) |
//!
//! `server-core` drives these state machines over real files and connections. Signatures and key
//! agreement are left to the `krouton-server` binary, which has `ring`.
//!
//! # Shared vectors
//!
//! The Swift client must produce the same bytes. Fixtures in the repository's `Vectors/` folder
//! pin both sides: `krsp-golden-v1.txt` (frames, manifests, identity and pairing), `krsp-control-v1.txt`
//! (every control message), and `krsp-bundle-v1.tar` with `krsp-bundle-names-v1.txt` (bundles).
//! The tests in `crates/krsp/tests/` check them here, and `krouton-verify` checks them in Swift.

pub mod bundle;
pub mod control;
pub mod endpoint;
pub mod frame;
pub mod identity;
pub mod json;
pub mod lease;
pub mod manifest;
pub mod pairing;
pub mod pipeline;
pub mod sha256;
pub mod telemetry;

/// Lowercase hex, for logs and golden-vector comparisons.
#[must_use]
pub fn hex(bytes: &[u8]) -> String {
    use std::fmt::Write;
    bytes.iter().fold(String::with_capacity(bytes.len() * 2), |mut out, b| {
        let _ = write!(out, "{b:02x}");
        out
    })
}

/// Parses lowercase or uppercase hex; `None` on odd length or a non-hex digit.
#[must_use]
pub fn unhex(text: &str) -> Option<Vec<u8>> {
    let text = text.trim();
    if !text.len().is_multiple_of(2) {
        return None;
    }
    (0..text.len()).step_by(2).map(|i| text.get(i..i + 2).and_then(|pair| u8::from_str_radix(pair, 16).ok())).collect()
}
