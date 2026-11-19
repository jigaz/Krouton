//! krouton-spoold: headless remote disc-burning server for Krouton.
//!
//! ```text
//! krouton-spoold run   --config <spoold.conf> [--log <file>]
//! krouton-spoold check --config <spoold.conf>     # validate config, pins, cert/key, burner, drives
//! krouton-spoold fingerprint <cert.pem>           # pin line for clients.pins
//! ```
//!
//! Thread per connection (see `server.rs`), bounded separately for in-progress TLS
//! handshakes (`max_handshakes`) and authenticated sessions (`max_connections`); one burn
//! worker per drive.

use krouton_spoold::server::Server;
use krouton_spoold::{platform, tls};
use spoold_core::burner::{Burner, HdiutilBurner, ImapiBurner, SimulatedBurner, XorrisoBurner};
use spoold_core::config::{Backend, Config};
use spoold_core::digest::Digester;
use spoold_core::pins::{fingerprint_hex, PinSet};
use spoold_core::spool::{SpoolEnv, Spooler};
use spoold_core::{info, warn};
use std::net::TcpListener;
use std::path::Path;
use std::process::ExitCode;
use std::sync::Arc;
use std::time::Duration;

const USAGE: &str = "usage:
  krouton-spoold run --config <spoold.conf> [--log <file>]
  krouton-spoold check --config <spoold.conf>
  krouton-spoold fingerprint <cert.pem>
  krouton-spoold --version";

const HANDSHAKE_TIMEOUT: Duration = Duration::from_secs(5);

fn main() -> ExitCode {
    let args: Vec<String> = std::env::args().skip(1).collect();
    let a: Vec<&str> = args.iter().map(String::as_str).collect();
    let result = match a.as_slice() {
        ["run", "--config", path] => run(Path::new(path)),
        ["run", "--config", path, "--log", log] => spoold_core::log::to_file(Path::new(log))
            .map_err(|e| format!("log file {log}: {e}"))
            .and_then(|_| run(Path::new(path))),
        ["check", "--config", path] => check(Path::new(path)).map(|_| ()),
        ["fingerprint", path] => tls::load_cert_der(Path::new(path)).map(|der| {
            println!("{}  <client-name>", fingerprint_hex(&platform::sha256(der.as_ref())));
        }),
        ["--version"] => {
            println!(
                "krouton-spoold {} (protocol v{}, {}-{})",
                env!("CARGO_PKG_VERSION"),
                spoold_core::PROTO_VERSION,
                std::env::consts::OS,
                std::env::consts::ARCH
            );
            Ok(())
        }
        _ => Err(USAGE.to_string()),
    };
    match result {
        Ok(()) => ExitCode::SUCCESS,
        Err(e) => {
            eprintln!("krouton-spoold: {e}");
            ExitCode::FAILURE
        }
    }
}

struct Loaded {
    config: Config,
    pins: Arc<PinSet>,
    tls: Arc<rustls::ServerConfig>,
}

fn check(path: &Path) -> Result<Loaded, String> {
    let config = Config::load(path)?;
    let pins_text =
        std::fs::read_to_string(&config.clients).map_err(|e| format!("{}: {e}", config.clients.display()))?;
    let pins = Arc::new(PinSet::parse(&pins_text).map_err(|e| format!("{}: {e}", config.clients.display()))?);
    if pins.is_empty() {
        return Err(format!("{}: no clients pinned; nobody could connect", config.clients.display()));
    }
    warn_if_readable_by_others(&config.key);
    let tls = tls::server_config(&config.cert, &config.key, Arc::clone(&pins))?;
    std::fs::create_dir_all(&config.spool_dir).map_err(|e| format!("spool dir {}: {e}", config.spool_dir.display()))?;
    let notes = platform::preflight(&config)?;
    let server_fp = fingerprint_hex(&platform::sha256(tls::load_cert_der(&config.cert)?.as_ref()));
    println!(
        "config ok: {} client(s) pinned, {} drive(s): {}",
        pins.len(),
        config.drives.len(),
        config.drives.iter().map(|d| format!("{} ({})", d.name, d.id)).collect::<Vec<_>>().join(", ")
    );
    for n in notes {
        println!("  {n}");
    }
    println!("server certificate pin (enter it in Krouton): {server_fp}");
    Ok(Loaded { config, pins, tls })
}

#[cfg(unix)]
fn warn_if_readable_by_others(key: &Path) {
    use std::os::unix::fs::PermissionsExt;
    if let Ok(m) = std::fs::metadata(key) {
        if m.permissions().mode() & 0o077 != 0 {
            warn!("{} is readable by group/others; chmod 600 it", key.display());
        }
    }
}

#[cfg(not(unix))]
fn warn_if_readable_by_others(_: &Path) {
    // On Windows the installer restricts the config directory's ACL instead.
}

fn make_burner(c: &Config, digester: Arc<dyn Digester>) -> Result<Arc<dyn Burner>, String> {
    Ok(match c.backend {
        Backend::Hdiutil => Arc::new(HdiutilBurner::new(c.start_timeout)),
        Backend::Xorriso => Arc::new(XorrisoBurner::new(digester, c.start_timeout)),
        Backend::Imapi => Arc::new(
            ImapiBurner::install(&c.spool_dir, digester, c.start_timeout)
                .map_err(|e| format!("installing IMAPI helper into {}: {e}", c.spool_dir.display()))?,
        ),
        Backend::Simulate => {
            warn!("backend = simulate: no disc will actually be written");
            Arc::new(SimulatedBurner::default())
        }
    })
}

fn run(path: &Path) -> Result<(), String> {
    let Loaded { config, pins, tls } = check(path)?;
    let digester: Arc<dyn Digester> = Arc::new(platform::Ring);
    let burner = make_burner(&config, Arc::clone(&digester))?;
    let env = SpoolEnv {
        digester,
        free_space: Some(Arc::new(|p: &Path| platform::free_space(p))),
        min_free_bytes: config.min_free_bytes,
    };
    let spool = Spooler::start(&config.spool_dir, config.max_image_bytes, config.drives.clone(), burner, env)
        .map_err(|e| format!("spool dir {}: {e}", config.spool_dir.display()))?;
    let listener = TcpListener::bind(&config.listen).map_err(|e| format!("bind {}: {e}", config.listen))?;
    info!(
        "krouton-spoold {} listening on {} as `{}` ({:?} backend)",
        env!("CARGO_PKG_VERSION"),
        config.listen,
        config.server_name,
        config.backend
    );
    let server = Server {
        tls,
        pins,
        spool,
        name: config.server_name.clone().into(),
        max_sessions: config.max_connections,
        max_handshakes: config.max_handshakes,
        handshake_timeout: HANDSHAKE_TIMEOUT,
    };
    Arc::new(server).serve(listener);
    Err("listener stopped".into())
}
