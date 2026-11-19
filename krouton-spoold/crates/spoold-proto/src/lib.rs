#![forbid(unsafe_code)]
//! `spoold-proto`: the sans-I/O core of `krouton-spoold`.
//!
//! Everything here is a pure function or a state machine with no sockets, files, threads or
//! clocks. Time and bytes are passed in, so `spoold-verify` can drive every rule
//! deterministically, and the same rules are pinned byte-for-byte to the Swift client by
//! `vectors/krsp-golden-v1.txt`.
//!
//! Zero third-party dependencies by default (the `sha2` feature swaps in accelerated hashing).

pub mod cutover;
pub mod endpoint;
pub mod frame;
pub mod identity;
pub mod lease;
pub mod manifest;
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
