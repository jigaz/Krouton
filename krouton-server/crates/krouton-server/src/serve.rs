//! Listening, admission control and the per-connection TLS driver.

use krsp::endpoint::AddressVerdict;
use rustls::{ServerConnection, StreamOwned};
use server_core::session::ServerContext;
use server_core::{Peer, Session, drive_connection, log};
use std::net::{TcpListener, TcpStream};
use std::sync::Arc;
use std::sync::atomic::{AtomicUsize, Ordering};
use std::time::Duration;

const HANDSHAKE_TIMEOUT: Duration = Duration::from_secs(10);
/// Read timeout while a session runs; also how often job events are forwarded.
const POLL_INTERVAL: Duration = Duration::from_millis(50);
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
    stream: TcpStream,
    ctx: &Arc<ServerContext>,
    tls: Arc<rustls::ServerConfig>,
    address: String,
) -> Result<(), String> {
    stream.set_nodelay(true).ok();
    stream.set_read_timeout(Some(HANDSHAKE_TIMEOUT)).map_err(|e| e.to_string())?;
    stream.set_write_timeout(Some(WRITE_TIMEOUT)).map_err(|e| e.to_string())?;
    let connection = ServerConnection::new(tls).map_err(|e| e.to_string())?;
    let mut tls = StreamOwned::new(connection, stream);
    while tls.conn.is_handshaking() {
        tls.conn.complete_io(&mut tls.sock).map_err(|e| format!("TLS handshake failed: {e}"))?;
    }
    let certificate = tls.conn.peer_certificates().and_then(|c| c.first()).ok_or("no client certificate")?;
    let tls_pin = server_core::x509::certificate_pin(certificate).ok_or("client certificate has no P-256 key")?;
    let exporter = tls
        .conn
        .export_keying_material([0u8; 32], krsp::identity::EXPORTER_LABEL, None)
        .map_err(|e| format!("TLS exporter failed: {e}"))?;
    tls.sock.set_read_timeout(Some(POLL_INTERVAL)).map_err(|e| e.to_string())?;

    let (session, first) = Session::start(Arc::clone(ctx), Peer { tls_pin, exporter, address });
    let result = drive_connection(&mut tls, session, &first, IDLE_TIMEOUT);
    tls.conn.send_close_notify();
    let _ = tls.conn.complete_io(&mut tls.sock);
    result.map_err(|e| e.to_string())
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
