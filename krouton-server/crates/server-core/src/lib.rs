#![forbid(unsafe_code)]
//! `server-core`: everything Krouton Server does except TLS and elliptic-curve crypto.
//!
//! Zero third-party dependencies. The binary crate supplies the TLS stream and a [`NodeCrypto`]
//! implementation; everything else (protocol sessions, pairing, staging, queues, burn backends)
//! is here and tested without network or hardware.

pub mod backend;
pub mod clients;
pub mod config;
pub mod fsutil;
pub mod jobs;
pub mod pairing_window;
pub mod session;
pub mod store;
#[doc(hidden)]
pub mod testutil;

pub use session::{Ephemeral, NodeCrypto, Peer, ServerContext, Session};

use krsp::frame::{Frame, FrameDecoder};
use std::io::{self, Read, Write};
use std::time::{Duration, Instant};

/// Writes one log line to stderr (systemd's journal, launchd's log file or the Windows task's
/// log), with control characters escaped so a client-chosen name cannot forge log lines.
pub fn log(message: &str) {
    let clean: String = message
        .chars()
        .flat_map(|c| if c.is_control() { c.escape_default().collect::<Vec<_>>() } else { vec![c] })
        .collect();
    eprintln!("{} {clean}", timestamp(pairing_window::unix_now()));
}

/// `YYYY-MM-DDTHH:MM:SSZ` from Unix seconds (proleptic Gregorian, no time-zone database needed).
#[must_use]
pub fn timestamp(secs: u64) -> String {
    let days = i64::try_from(secs / 86_400).unwrap_or(0);
    let rem = secs % 86_400;
    // Howard Hinnant's civil-from-days.
    let z = days + 719_468;
    let era = z.div_euclid(146_097);
    let doe = z - era * 146_097;
    let yoe = (doe - doe / 1460 + doe / 36_524 - doe / 146_096) / 365;
    let doy = doe - (365 * yoe + yoe / 4 - yoe / 100);
    let mp = (5 * doy + 2) / 153;
    let d = doy - (153 * mp + 2) / 5 + 1;
    let m = if mp < 10 { mp + 3 } else { mp - 9 };
    let y = yoe + era * 400 + i64::from(m <= 2);
    format!("{y:04}-{m:02}-{d:02}T{:02}:{:02}:{:02}Z", rem / 3600, rem % 3600 / 60, rem % 60)
}

/// Owner-only permissions for keys and pairing files (Unix). On Windows the installer puts the
/// state directory under an ACL that only SYSTEM and Administrators can read.
pub fn secure_permissions(path: &std::path::Path) {
    #[cfg(unix)]
    {
        use std::os::unix::fs::PermissionsExt;
        let mode = if path.is_dir() { 0o700 } else { 0o600 };
        let _ = std::fs::set_permissions(path, std::fs::Permissions::from_mode(mode));
    }
    #[cfg(not(unix))]
    let _ = path;
}

/// Runs a session over an established, authenticated-at-TLS-level stream until either side
/// closes or the peer is silent for `idle`. The stream must have a short read timeout (the loop
/// uses it to interleave job events with reads).
pub fn drive_connection<S: Read + Write>(
    stream: &mut S,
    mut session: Session,
    first: &[Frame],
    idle: Duration,
) -> io::Result<()> {
    write_frames(stream, first)?;
    if session.is_closed() {
        return Ok(());
    }
    let mut decoder = FrameDecoder::new();
    let mut buf = vec![0u8; 256 * 1024];
    let mut last_heard = Instant::now();
    loop {
        match stream.read(&mut buf) {
            Ok(0) => return Ok(()),
            Ok(n) => {
                last_heard = Instant::now();
                let frames = match decoder.push(buf.get(..n).unwrap_or_default()) {
                    Ok(frames) => frames,
                    Err(e) => {
                        let reply = krsp::control::Control::Error {
                            code: krsp::control::ErrorCode::BadRequest,
                            message: e.to_string(),
                            job: None,
                        };
                        let _ = write_frames(stream, &[reply.to_frame()]);
                        return Err(io::Error::new(io::ErrorKind::InvalidData, e.to_string()));
                    }
                };
                for frame in frames {
                    let out = session.on_frame(&frame);
                    write_frames(stream, &out)?;
                    if session.is_closed() {
                        return Ok(());
                    }
                }
            }
            Err(e)
                if matches!(
                    e.kind(),
                    io::ErrorKind::WouldBlock | io::ErrorKind::TimedOut | io::ErrorKind::Interrupted
                ) => {}
            Err(e) => return Err(e),
        }
        let out = session.tick();
        write_frames(stream, &out)?;
        if session.is_closed() {
            return Ok(());
        }
        if last_heard.elapsed() > idle {
            return Ok(());
        }
    }
}

fn write_frames<S: Write>(stream: &mut S, frames: &[Frame]) -> io::Result<()> {
    if frames.is_empty() {
        return Ok(());
    }
    for frame in frames {
        stream.write_all(&frame.encode())?;
    }
    stream.flush()
}

#[cfg(test)]
mod tests {
    #[test]
    fn timestamps() {
        assert_eq!(super::timestamp(0), "1970-01-01T00:00:00Z");
        assert_eq!(super::timestamp(1_795_604_719), "2026-11-25T11:05:19Z");
        assert_eq!(super::timestamp(951_782_400), "2000-02-29T00:00:00Z");
    }
}
