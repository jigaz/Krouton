#![forbid(unsafe_code)]
//! `server-core`: everything Krouton Server does except TLS and elliptic-curve crypto.
//!
//! Zero third-party dependencies. The binary crate supplies the TLS stream and a [`NodeCrypto`]
//! implementation; everything else (protocol sessions, pairing, staging, queues, burn backends)
//! is here and tested without network or hardware.

pub mod backend;
pub mod clients;
pub mod config;
pub mod extract;
pub mod fsutil;
pub mod jobs;
pub mod pairing_window;
pub mod session;
pub mod store;
#[doc(hidden)]
pub mod testutil;
pub mod x509;

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

/// The connection's byte layer: TLS in the binary, plain TCP in tests.
pub trait Transport {
    /// Turns bytes read from the socket into application bytes (decrypting, for TLS).
    fn open(&mut self, raw: &[u8]) -> io::Result<Vec<u8>>;
    /// Sends application bytes (encrypting, for TLS) and flushes them to the socket.
    fn send(&mut self, data: &[u8]) -> io::Result<()>;
}

/// Plain TCP, for tests and for tools that terminate TLS elsewhere.
#[derive(Debug)]
pub struct PlainTransport(pub std::net::TcpStream);

impl Transport for PlainTransport {
    fn open(&mut self, raw: &[u8]) -> io::Result<Vec<u8>> {
        Ok(raw.to_vec())
    }

    fn send(&mut self, data: &[u8]) -> io::Result<()> {
        self.0.write_all(data)?;
        self.0.flush()
    }
}

/// What the reader thread passes on: bytes, end of stream (empty), or an error.
pub type Incoming = io::Result<Vec<u8>>;

/// Reads `reader` on its own thread with plain blocking reads (no timeouts: on Windows a timed-out
/// receive leaves the socket in an undefined state) and forwards what arrives. The thread ends
/// at end of stream, on an error, or when the receiver is dropped and the socket is shut down.
pub fn spawn_reader<R: Read + Send + 'static>(mut reader: R) -> std::sync::mpsc::Receiver<Incoming> {
    let (tx, rx) = std::sync::mpsc::channel();
    let spawned = std::thread::Builder::new().name("conn-reader".into()).spawn(move || {
        let mut buf = vec![0u8; 64 * 1024];
        loop {
            match reader.read(&mut buf) {
                Ok(0) => {
                    let _ = tx.send(Ok(Vec::new()));
                    return;
                }
                Ok(n) => {
                    if tx.send(Ok(buf.get(..n).unwrap_or_default().to_vec())).is_err() {
                        return;
                    }
                }
                Err(e) if e.kind() == io::ErrorKind::Interrupted => {}
                Err(e) => {
                    let _ = tx.send(Err(e));
                    return;
                }
            }
        }
    });
    if let Err(e) = spawned {
        log(&format!("could not start a reader thread: {e}"));
    }
    rx
}

/// How often job events are forwarded while the peer is quiet.
const TICK: Duration = Duration::from_millis(50);

/// Runs a session until either side closes or the peer is silent for `idle`. Bytes arrive from
/// `incoming` (see [`spawn_reader`]); this thread owns the transport (and so the TLS state), so
/// no lock is needed and the socket is never read with a timeout.
pub fn drive_connection<T: Transport>(
    transport: &mut T,
    incoming: &std::sync::mpsc::Receiver<Incoming>,
    mut session: Session,
    first: &[Frame],
    idle: Duration,
) -> io::Result<()> {
    send_frames(transport, first)?;
    if session.is_closed() {
        return Ok(());
    }
    let mut decoder = FrameDecoder::new();
    let mut last_heard = Instant::now();
    loop {
        match incoming.recv_timeout(TICK) {
            Ok(Ok(raw)) if raw.is_empty() => return Ok(()),
            Ok(Ok(raw)) => {
                last_heard = Instant::now();
                let data = transport.open(&raw)?;
                let frames = match decoder.push(&data) {
                    Ok(frames) => frames,
                    Err(e) => {
                        let reply = krsp::control::Control::Error {
                            code: krsp::control::ErrorCode::BadRequest,
                            message: e.to_string(),
                            job: None,
                        };
                        let _ = send_frames(transport, &[reply.to_frame()]);
                        return Err(io::Error::new(io::ErrorKind::InvalidData, e.to_string()));
                    }
                };
                for frame in frames {
                    let out = session.on_frame(&frame);
                    send_frames(transport, &out)?;
                    if session.is_closed() {
                        return Ok(());
                    }
                }
            }
            Ok(Err(e)) => return Err(e),
            Err(std::sync::mpsc::RecvTimeoutError::Timeout) => {}
            Err(std::sync::mpsc::RecvTimeoutError::Disconnected) => return Ok(()),
        }
        let out = session.tick();
        send_frames(transport, &out)?;
        if session.is_closed() || last_heard.elapsed() > idle {
            return Ok(());
        }
    }
}

fn send_frames<T: Transport>(transport: &mut T, frames: &[Frame]) -> io::Result<()> {
    if frames.is_empty() {
        return Ok(());
    }
    let bytes: Vec<u8> = frames.iter().flat_map(Frame::encode).collect();
    transport.send(&bytes)
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
