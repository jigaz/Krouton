//! Listening, admission control and the per-connection TLS driver.

use krsp::endpoint::AddressVerdict;
use rustls::ServerConnection;
use server_core::session::ServerContext;
use server_core::{Peer, Session, Transport, drive_connection, log, spawn_reader};
use std::io::{self, Read, Write};
use std::net::{Shutdown, TcpListener, TcpStream};
use std::sync::Arc;
use std::sync::atomic::{AtomicUsize, Ordering};
use std::time::Duration;

const HANDSHAKE_TIMEOUT: Duration = Duration::from_secs(10);
const WRITE_TIMEOUT: Duration = Duration::from_secs(60);
/// The app pings every 20 s; three missed pings close the connection.
const IDLE_TIMEOUT: Duration = Duration::from_secs(70);

pub struct Listener {
    pub ctx: Arc<ServerContext>,
    pub tls: Arc<rustls::ServerConfig>,
    pub active: Arc<AtomicUsize>,
}

impl Listener {
    /// Accepts connections on `listener` forever.
    pub fn run(&self, listener: &TcpListener) {
        let policy = self.ctx.jobs.config.endpoint_policy();
        let max = self.ctx.jobs.config.max_connections;
        for stream in listener.incoming() {
            let Ok(stream) = stream else { continue };
            let Ok(addr) = stream.peer_addr() else { continue };
            if let AddressVerdict::Denied(reason) = policy.evaluate(addr.ip()) {
                log(&format!("{addr}: refused ({reason:?}); add allow_range / allow_cgnat to accept it"));
                continue;
            }
            if self.active.fetch_add(1, Ordering::SeqCst) >= max {
                self.active.fetch_sub(1, Ordering::SeqCst);
                log(&format!("{addr}: refused (max_connections = {max} reached)"));
                continue;
            }
            let (ctx, tls, active) = (Arc::clone(&self.ctx), Arc::clone(&self.tls), Arc::clone(&self.active));
            let spawned = std::thread::Builder::new().name(format!("conn-{addr}")).spawn(move || {
                if let Err(e) = handle(stream, &ctx, tls, addr.to_string()) {
                    log(&format!("{addr}: {e}"));
                }
                active.fetch_sub(1, Ordering::SeqCst);
            });
            if spawned.is_err() {
                self.active.fetch_sub(1, Ordering::SeqCst);
            }
        }
    }
}

fn handle(
    mut stream: TcpStream,
    ctx: &Arc<ServerContext>,
    tls: Arc<rustls::ServerConfig>,
    address: String,
) -> Result<(), String> {
    stream.set_nodelay(true).ok();
    // The handshake is the only blocking exchange with a deadline; a peer that stalls is dropped.
    stream.set_read_timeout(Some(HANDSHAKE_TIMEOUT)).map_err(|e| e.to_string())?;
    stream.set_write_timeout(Some(WRITE_TIMEOUT)).map_err(|e| e.to_string())?;
    let mut conn = ServerConnection::new(tls).map_err(|e| e.to_string())?;
    while conn.is_handshaking() {
        conn.complete_io(&mut stream).map_err(|e| format!("TLS handshake failed: {e}"))?;
    }
    let certificate = conn.peer_certificates().and_then(|c| c.first()).ok_or("no client certificate")?;
    let tls_pin = server_core::x509::certificate_pin(certificate).ok_or("client certificate has no P-256 key")?;
    let exporter = conn
        .export_keying_material([0u8; 32], krsp::identity::EXPORTER_LABEL, None)
        .map_err(|e| format!("TLS exporter failed: {e}"))?;

    // From here a reader thread does plain blocking reads (no timeouts: Windows leaves a socket in an
    // undefined state after a receive timeout) and this thread owns the TLS state.
    stream.set_read_timeout(None).map_err(|e| e.to_string())?;
    let incoming = spawn_reader(stream.try_clone().map_err(|e| e.to_string())?);
    let mut transport = TlsTransport { conn, sock: stream };
    let (session, first) = Session::start(Arc::clone(ctx), Peer { tls_pin, exporter, address });
    let result = drive_connection(&mut transport, &incoming, session, &first, IDLE_TIMEOUT);
    transport.close();
    result.map_err(|e| e.to_string())
}

/// rustls on top of a socket whose reads happen on another thread: ciphertext comes in through
/// `open`, plaintext goes out through `send`.
struct TlsTransport {
    conn: ServerConnection,
    sock: TcpStream,
}

impl TlsTransport {
    fn flush_tls(&mut self) -> io::Result<()> {
        while self.conn.wants_write() {
            self.conn.write_tls(&mut self.sock)?;
        }
        self.sock.flush()
    }

    fn close(&mut self) {
        self.conn.send_close_notify();
        let _ = self.flush_tls();
        let _ = self.sock.shutdown(Shutdown::Both);
    }
}

impl Transport for TlsTransport {
    fn open(&mut self, raw: &[u8]) -> io::Result<Vec<u8>> {
        let mut cursor = raw;
        let mut plaintext = Vec::new();
        while !cursor.is_empty() {
            if self.conn.read_tls(&mut cursor)? == 0 {
                break;
            }
            self.conn.process_new_packets().map_err(|e| io::Error::new(io::ErrorKind::InvalidData, e))?;
            // Drain as we go so rustls' received-plaintext buffer never fills.
            match self.conn.reader().read_to_end(&mut plaintext) {
                Ok(_) => {}
                Err(e) if e.kind() == io::ErrorKind::WouldBlock => {}
                Err(e) => return Err(e),
            }
        }
        // Alerts or key updates rustls wants to answer.
        self.flush_tls()?;
        Ok(plaintext)
    }

    fn send(&mut self, data: &[u8]) -> io::Result<()> {
        for chunk in data.chunks(16 * 1024) {
            self.conn.writer().write_all(chunk)?;
            self.flush_tls()?;
        }
        Ok(())
    }
}

// MARK: - Bonjour

/// Advertises `_krouton-spool._tcp` with the system's mDNS responder, so Krouton finds the server
/// without typing an address. Uses `dns-sd` (macOS) or `avahi-publish` (Linux, from avahi-utils);
/// on Windows, or if neither tool exists, the app connects by host name or address instead.
/// The TXT record carries only unauthenticated hints; the TLS pin proves who the server is.
pub fn advertise(name: &str, port: u16, node_id: &str) -> Option<std::process::Child> {
    let txt = [
        "txtvers=1".to_string(),
        format!("pv={}", krsp::frame::VERSION),
        format!("id={node_id}"),
        format!(
            "caps={:x}",
            krsp::identity::caps::WRITES_CD | krsp::identity::caps::WRITES_DVD | krsp::identity::caps::WRITES_BD
        ),
    ];
    let port = port.to_string();
    let attempts: [(&str, Vec<&str>); 2] = [
        ("dns-sd", vec!["-R", name, krsp::identity::SERVICE_TYPE, "local", &port]),
        ("avahi-publish", vec!["-s", name, krsp::identity::SERVICE_TYPE, &port]),
    ];
    for (tool, args) in attempts {
        let child = std::process::Command::new(tool)
            .args(&args)
            .args(&txt)
            .stdin(std::process::Stdio::null())
            .stdout(std::process::Stdio::null())
            .stderr(std::process::Stdio::null())
            .spawn();
        if let Ok(child) = child {
            log(&format!("advertising {} via {tool}", krsp::identity::SERVICE_TYPE));
            return Some(child);
        }
    }
    log("Bonjour advertisement unavailable (install avahi-utils on Linux); Krouton can still connect by address");
    None
}
