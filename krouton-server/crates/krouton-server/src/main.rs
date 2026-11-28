#![forbid(unsafe_code)]
//! `krouton-server`: the burn box for Krouton.
//!
//! ```text
//! krouton-server init      create the configuration and keys (once)
//! krouton-server run       serve (what the service runs)
//! krouton-server pair      let a Mac pair; confirm the 6-digit code it shows
//! krouton-server clients   list paired Macs        krouton-server unpair <name>
//! krouton-server check     diagnose the setup      krouton-server version
//! ```
//! Every command accepts `--home <dir>` (default: `$KROUTON_SERVER_HOME`, else the platform's
//! service directory), which holds `server.conf`, the keys, paired clients and the spool.
//!
//! This crate is the thin layer around `server-core`: the command line (this file), the
//! server's keys and the `NodeCrypto` implementation on `ring` (`crypto`), the rustls
//! configuration with pinned keys (`tls`), and the TCP listener, admission control and Bonjour
//! advertisement (`serve`). It is the only crate with third-party dependencies.

mod crypto;
mod serve;
mod tls;

use server_core::clients::ClientStore;
use server_core::config::{BackendKind, Config};
use server_core::jobs::JobManager;
use server_core::pairing_window::PairingWindow;
use server_core::session::{SERVER_VERSION, ServerContext};
use std::io::{BufRead, Write};
use std::net::TcpListener;
use std::path::{Path, PathBuf};
use std::process::ExitCode;
use std::sync::atomic::AtomicUsize;
use std::sync::{Arc, Mutex};
use std::time::Duration;

const CONFIG_FILE: &str = "server.conf";

fn main() -> ExitCode {
    let mut args: Vec<String> = std::env::args().skip(1).collect();
    let home = take_option(&mut args, "--home").map_or_else(default_home, PathBuf::from);
    let command = if args.is_empty() { "help".to_string() } else { args.remove(0) };
    let result = match command.as_str() {
        "init" => init(&home, &mut args),
        "run" => run(&home),
        "pair" => pair(&home, &mut args),
        "clients" => clients(&home),
        "unpair" => unpair(&home, &args),
        "check" => check(&home),
        "version" | "--version" | "-V" => {
            println!("krouton-server {SERVER_VERSION} (KRSP v{})", krsp::frame::VERSION);
            Ok(())
        }
        "help" | "--help" | "-h" => {
            print_help(&home);
            Ok(())
        }
        other => Err(format!("Unknown command `{other}`. Run `krouton-server help`.")),
    };
    match result {
        Ok(()) => ExitCode::SUCCESS,
        Err(message) => {
            eprintln!("krouton-server: {message}");
            ExitCode::FAILURE
        }
    }
}

fn print_help(home: &Path) {
    println!(
        "Krouton Server {SERVER_VERSION}: burn discs from Krouton on another computer.\n\n\
         Usage: krouton-server [--home DIR] <command>\n\n\
         Commands:\n  \
         init [--backend auto|macos|linux|windows|simulate] [--name NAME]\n                 create the configuration and keys\n  \
         run            start serving (the installed service runs this)\n  \
         pair [--minutes N]\n                 let a Mac pair, after you confirm the code it shows\n  \
         clients        list paired Macs\n  \
         unpair NAME    remove a paired Mac\n  \
         check          check the setup and drives\n  \
         version        print the version\n\n\
         Home directory: {}",
        home.display()
    );
}

fn take_option(args: &mut Vec<String>, name: &str) -> Option<String> {
    let i = args.iter().position(|a| a == name)?;
    args.remove(i);
    (i < args.len()).then(|| args.remove(i))
}

fn default_home() -> PathBuf {
    if let Some(dir) = std::env::var_os("KROUTON_SERVER_HOME") {
        return PathBuf::from(dir);
    }
    if cfg!(target_os = "macos") {
        let home = std::env::var_os("HOME").map_or_else(|| PathBuf::from("/tmp"), PathBuf::from);
        home.join("Library/Application Support/Krouton Server")
    } else if cfg!(windows) {
        std::env::var_os("ProgramData")
            .map_or_else(|| PathBuf::from(r"C:\ProgramData"), PathBuf::from)
            .join("Krouton Server")
    } else {
        PathBuf::from("/var/lib/krouton-server")
    }
}

fn load_config(home: &Path) -> Result<Config, String> {
    match std::fs::read_to_string(home.join(CONFIG_FILE)) {
        Ok(text) => Config::parse(&text, home),
        Err(e) if e.kind() == std::io::ErrorKind::NotFound => Ok(Config::defaults(home)),
        Err(e) => Err(format!("Could not read {}: {e}", home.join(CONFIG_FILE).display())),
    }
}

fn hex_groups(bytes: &[u8]) -> String {
    krsp::hex(bytes).as_bytes().chunks(8).map(|c| String::from_utf8_lossy(c).into_owned()).collect::<Vec<_>>().join(" ")
}

// MARK: - init

fn init(home: &Path, args: &mut Vec<String>) -> Result<(), String> {
    let backend = match take_option(args, "--backend").as_deref() {
        None | Some("auto") => BackendKind::Auto,
        Some("macos") => BackendKind::MacOs,
        Some("linux") => BackendKind::Linux,
        Some("windows") => BackendKind::Windows,
        Some("simulate") => BackendKind::Simulate,
        Some(other) => return Err(format!("Unknown backend `{other}`")),
    };
    let name = take_option(args, "--name");
    std::fs::create_dir_all(home).map_err(|e| format!("Could not create {}: {e}", home.display()))?;
    let config_path = home.join(CONFIG_FILE);
    if config_path.exists() {
        println!("Keeping existing {}", config_path.display());
    } else {
        let mut text = Config::starter_file(backend);
        if let Some(name) = &name {
            let clean: String = name.chars().filter(|c| !c.is_control()).take(64).collect();
            text = text.replacen(
                &format!("name = {}", server_core::config::default_name()),
                &format!("name = {clean}"),
                1,
            );
        }
        server_core::store::write_atomically(&config_path, text.as_bytes()).map_err(|e| e.to_string())?;
        println!("Wrote {}", config_path.display());
    }
    let config = load_config(home)?;
    for created in crypto::ensure_keys(home, &config.name)? {
        println!("Created {created}");
    }
    let identity = crypto::load_identity(home)?;
    println!("\nServer name : {}", config.name);
    println!("Node ID     : {}", identity.node_id());
    println!("Key pin     : {}", hex_groups(&tls::server_pin(home)?));
    println!("\nNext: start the service, then run `krouton-server pair` to add a Mac.");
    Ok(())
}

// MARK: - run

fn run(home: &Path) -> Result<(), String> {
    let config = load_config(home)?;
    for created in crypto::ensure_keys(home, &config.name)? {
        server_core::log(&format!("created {created}"));
    }
    let identity = crypto::load_identity(home)?;
    let node_id = identity.node_id();
    let tls = tls::server_config(home)?;
    let (clients, warnings) = ClientStore::load(home);
    for w in warnings {
        server_core::log(&w);
    }
    let listen = config.listen.clone();
    let name = config.name.clone();
    let backend = server_core::backend::from_config(&config);
    let backend_name = backend.kind().name();
    let jobs = JobManager::new(config, backend).map_err(|e| format!("Could not open the spool directory: {e}"))?;
    server_core::log(&format!(
        "Krouton Server {SERVER_VERSION} \"{name}\" node {node_id}, key pin {}",
        hex_groups(&tls::server_pin(home)?)
    ));
    server_core::log(&format!(
        "backend {backend_name}, {} drive(s): {}",
        jobs.drives().len(),
        jobs.drives().iter().map(|d| format!("{} ({})", d.id, d.name)).collect::<Vec<_>>().join(", ")
    ));
    if jobs.drives().is_empty() {
        server_core::log("warning: no drives found; run `krouton-server check`");
    }
    for problem in jobs.backend().diagnose() {
        server_core::log(&format!("warning: {problem}"));
    }
    jobs.start_workers();
    let ctx = Arc::new(ServerContext {
        jobs,
        clients,
        crypto: Box::new(identity),
        pairing: PairingWindow::new(home),
        pairing_busy: Mutex::new(false),
        server_name: name.clone(),
        node_id: node_id.clone(),
    });
    let listener = Arc::new(serve::Listener { ctx, tls, active: Arc::new(AtomicUsize::new(0)) });
    let mut threads = Vec::new();
    let mut port = krsp::identity::DEFAULT_PORT;
    for addr in listen {
        let socket = TcpListener::bind(addr).map_err(|e| format!("Could not listen on {addr}: {e}"))?;
        server_core::log(&format!("listening on {addr}"));
        port = addr.port();
        let l = Arc::clone(&listener);
        threads.push(std::thread::spawn(move || l.run(&socket)));
    }
    let _bonjour = serve::advertise(&name, port, &node_id, listener.ctx.jobs.advertised_writes());
    for t in threads {
        let _ = t.join();
    }
    Ok(())
}

// MARK: - pair

fn pair(home: &Path, args: &mut Vec<String>) -> Result<(), String> {
    let minutes: u64 = take_option(args, "--minutes")
        .map_or(Ok(5), |m| m.parse().map_err(|_| "--minutes must be a number".to_string()))?;
    let config = load_config(home)?;
    if !home.join(crypto::IDENTITY_FILE).exists() {
        return Err(format!("{} has no keys yet. Run `krouton-server init` first.", home.display()));
    }
    let window = PairingWindow::new(home);
    window
        .open(Duration::from_secs(minutes.clamp(1, 60) * 60))
        .map_err(|e| format!("Could not open the pairing window (run as the service user?): {e}"))?;
    let host = server_core::config::default_name();
    println!("Pairing is open for {minutes} minute(s).");
    println!(
        "In Krouton: Settings › Burners & Network › Krouton Servers, then click Connect next to \"{}\"",
        config.name
    );
    println!(
        "(or use Pair by Address with {host}.local or this computer's IP address, port {}).\n",
        config.listen.first().map_or(krsp::identity::DEFAULT_PORT, std::net::SocketAddr::port)
    );
    println!("Waiting for a Mac… (Ctrl-C to cancel)");
    let Some((code, device)) = window.wait_request(Duration::from_secs(minutes * 60)) else {
        window.close();
        return Err("No Mac tried to pair. Is the service running? (`krouton-server check`)".into());
    };
    let (a, b) = code.split_at(code.len().min(3));
    print!("\n\"{device}\" wants to pair and shows the code  {a} {b}\nDoes Krouton show the same code? [y/N] ");
    let _ = std::io::stdout().flush();
    let mut answer = String::new();
    let _ = std::io::stdin().lock().read_line(&mut answer);
    let accept = matches!(answer.trim(), "y" | "Y" | "yes" | "Yes");
    window.decide(accept).map_err(|e| e.to_string())?;
    if accept {
        println!("Confirmed. Now confirm in Krouton too…");
    }
    let outcome = window.wait_result(Duration::from_secs(150)).unwrap_or_else(|| "No answer from the service.".into());
    window.close();
    println!("{outcome}");
    Ok(())
}

// MARK: - clients / unpair

fn clients(home: &Path) -> Result<(), String> {
    let (store, warnings) = ClientStore::load(home);
    for w in warnings {
        eprintln!("warning: {w}");
    }
    let all = store.all();
    if all.is_empty() {
        println!("No paired Macs. Run `krouton-server pair` to add one.");
    }
    for c in all {
        println!("{:<32} paired {}  key {}", c.name, server_core::timestamp(c.paired_at), &krsp::hex(&c.tls_pin)[..16]);
    }
    Ok(())
}

fn unpair(home: &Path, args: &[String]) -> Result<(), String> {
    let which = args.join(" ");
    if which.is_empty() {
        return Err("Usage: krouton-server unpair <name or key prefix>".into());
    }
    let (store, _) = ClientStore::load(home);
    match store.remove(&which).map_err(|e| e.to_string())? {
        0 => Err(format!("No paired Mac matches `{which}` (see `krouton-server clients`)")),
        n => {
            println!("Removed {n}. Restart the service so open connections are dropped.");
            Ok(())
        }
    }
}

// MARK: - check

fn check(home: &Path) -> Result<(), String> {
    let mut problems = Vec::new();
    println!("Home        : {}", home.display());
    let config = load_config(home)?;
    println!("Name        : {}", config.name);
    println!("Listen      : {}", config.listen.iter().map(ToString::to_string).collect::<Vec<_>>().join(", "));
    println!("Backend     : {}", config.backend.resolved().name());
    match crypto::load_identity(home) {
        Ok(id) => println!("Node ID     : {}", id.node_id()),
        Err(e) => problems.push(e),
    }
    match tls::server_config(home).and_then(|_| tls::server_pin(home)) {
        Ok(pin) => println!("Key pin     : {}", hex_groups(&pin)),
        Err(e) => problems.push(e),
    }
    let (clients, warnings) = ClientStore::load(home);
    problems.extend(warnings);
    println!("Paired Macs : {}", clients.all().len());
    match server_core::fsutil::free_bytes(&config.spool_dir) {
        Some(free) => {
            println!("Spool       : {} ({} GiB free)", config.spool_dir.display(), free >> 30);
            if free < config.min_free_bytes {
                problems.push(format!("Less than min_free_gib free in {}", config.spool_dir.display()));
            }
        }
        None => problems.push(format!("Could not read free space for {}", config.spool_dir.display())),
    }
    let backend = server_core::backend::from_config(&config);
    let drives = backend.discover();
    for d in &drives {
        println!("Drive       : {} {} ({}), media: {}", d.id, d.name, d.device, backend.media(d).wire_name());
    }
    let systems = backend.file_systems();
    if systems.is_empty() {
        println!("Folders     : not supported (the Mac must send finished disc images)");
    } else {
        println!("Folders     : built into {}", systems.join(" + "));
    }
    problems.extend(backend.diagnose());
    if problems.is_empty() {
        println!("\nAll good.");
        Ok(())
    } else {
        println!();
        for p in &problems {
            println!("Problem: {p}");
        }
        Err(format!("{} problem(s) found", problems.len()))
    }
}

#[cfg(test)]
#[allow(clippy::unwrap_used, clippy::expect_used, clippy::indexing_slicing, clippy::panic)]
mod tls_tests {
    //! Real TLS 1.3 end to end: a rustls client with a P-256 client certificate (what Krouton's
    //! Keychain identity presents) connects, both sides check key pins, both derive the same
    //! exporter and verify each other's Ed25519 session proof, then Hello → Welcome.
    use super::*;
    use krsp::control::Control;
    use krsp::frame::FrameDecoder;
    use krsp::identity::{EXPORTER_LABEL, ROLE_NODE, ROLE_WORKSTATION, session_proof_message};
    use ring::signature::{ED25519, Ed25519KeyPair, KeyPair, UnparsedPublicKey};
    use rustls::client::danger::{HandshakeSignatureValid, ServerCertVerified, ServerCertVerifier};
    use rustls::pki_types::{CertificateDer, PrivateKeyDer, PrivatePkcs8KeyDer, ServerName, UnixTime};
    use rustls::{ClientConfig, ClientConnection, DigitallySignedStruct, SignatureScheme, StreamOwned};
    use server_core::clients::ClientRecord;
    use std::io::{Read, Write};
    use std::net::TcpStream;

    #[derive(Debug)]
    struct PinnedServer {
        pin: [u8; 32],
        algorithms: rustls::crypto::WebPkiSupportedAlgorithms,
    }

    impl ServerCertVerifier for PinnedServer {
        fn verify_server_cert(
            &self,
            end_entity: &CertificateDer<'_>,
            _intermediates: &[CertificateDer<'_>],
            _server_name: &ServerName<'_>,
            _ocsp: &[u8],
            _now: UnixTime,
        ) -> Result<ServerCertVerified, rustls::Error> {
            if server_core::x509::certificate_pin(end_entity) == Some(self.pin) {
                Ok(ServerCertVerified::assertion())
            } else {
                Err(rustls::Error::General("server key pin mismatch".into()))
            }
        }
        fn verify_tls12_signature(
            &self,
            _: &[u8],
            _: &CertificateDer<'_>,
            _: &DigitallySignedStruct,
        ) -> Result<HandshakeSignatureValid, rustls::Error> {
            Err(rustls::Error::General("TLS 1.2".into()))
        }
        fn verify_tls13_signature(
            &self,
            m: &[u8],
            c: &CertificateDer<'_>,
            d: &DigitallySignedStruct,
        ) -> Result<HandshakeSignatureValid, rustls::Error> {
            rustls::crypto::verify_tls13_signature(m, c, d, &self.algorithms)
        }
        fn supported_verify_schemes(&self) -> Vec<SignatureScheme> {
            vec![SignatureScheme::ECDSA_NISTP256_SHA256]
        }
    }

    fn read_control(tls: &mut StreamOwned<ClientConnection, TcpStream>, decoder: &mut FrameDecoder) -> Control {
        let mut buf = [0u8; 65536];
        loop {
            let n = tls.read(&mut buf).unwrap();
            assert!(n > 0, "server closed the connection");
            if let Some(frame) =
                decoder.push(&buf[..n]).unwrap().into_iter().find(|f| f.header.kind == krsp::frame::FrameKind::Control)
            {
                return Control::from_frame(&frame).unwrap();
            }
        }
    }

    #[test]
    fn pinned_mutual_tls_session() {
        let tmp = server_core::testutil::TempDir::new("tls");
        let home = tmp.path();
        let mut config = Config::defaults(home);
        config.backend = BackendKind::Simulate;
        crypto::ensure_keys(home, "TLS Test").unwrap();
        let server_pin = tls::server_pin(home).unwrap();
        let identity = crypto::load_identity(home).unwrap();
        let node_key = server_core::NodeCrypto::identity_public(&identity);

        // The Mac's keys: a P-256 TLS certificate and an Ed25519 identity, already paired.
        let client_key = rcgen::KeyPair::generate_for(&rcgen::PKCS_ECDSA_P256_SHA256).unwrap();
        let client_cert =
            rcgen::CertificateParams::new(vec!["studio-mac".to_string()]).unwrap().self_signed(&client_key).unwrap();
        let client_pin = server_core::x509::certificate_pin(client_cert.der()).unwrap();
        let mac_identity = Ed25519KeyPair::from_seed_unchecked(&[0x5A; 32]).unwrap();
        let mac_public: [u8; 32] = mac_identity.public_key().as_ref().try_into().unwrap();
        let (clients, _) = ClientStore::load(home);
        clients
            .upsert(ClientRecord { tls_pin: client_pin, identity: mac_public, paired_at: 1, name: "Studio Mac".into() })
            .unwrap();

        let backend = server_core::backend::from_config(&config);
        let jobs = JobManager::new(config, backend).unwrap();
        let ctx = Arc::new(ServerContext {
            jobs,
            clients,
            crypto: Box::new(identity),
            pairing: PairingWindow::new(home),
            pairing_busy: Mutex::new(false),
            server_name: "TLS Test".into(),
            node_id: krsp::identity::node_id(&node_key),
        });
        let listener = Arc::new(serve::Listener {
            ctx,
            tls: tls::server_config(home).unwrap(),
            active: Arc::new(AtomicUsize::new(0)),
        });
        let socket = TcpListener::bind("127.0.0.1:0").unwrap();
        let addr = socket.local_addr().unwrap();
        std::thread::spawn(move || listener.run(&socket));

        let provider = Arc::new(rustls::crypto::ring::default_provider());
        let client_config = ClientConfig::builder_with_provider(Arc::clone(&provider))
            .with_protocol_versions(&[&rustls::version::TLS13])
            .unwrap()
            .dangerous()
            .with_custom_certificate_verifier(Arc::new(PinnedServer {
                pin: server_pin,
                algorithms: provider.signature_verification_algorithms,
            }))
            .with_client_auth_cert(
                vec![client_cert.der().clone()],
                PrivateKeyDer::Pkcs8(PrivatePkcs8KeyDer::from(client_key.serialize_der())),
            )
            .unwrap();
        let conn =
            ClientConnection::new(Arc::new(client_config), ServerName::try_from("krouton-server.local").unwrap())
                .unwrap();
        let sock = TcpStream::connect(addr).unwrap();
        sock.set_read_timeout(Some(Duration::from_secs(10))).unwrap();
        let mut tls = StreamOwned::new(conn, sock);
        while tls.conn.is_handshaking() {
            tls.conn.complete_io(&mut tls.sock).unwrap();
        }
        let exporter = tls.conn.export_keying_material([0u8; 32], EXPORTER_LABEL, None).unwrap();
        let mut decoder = FrameDecoder::new();

        // The server proves its identity over this very TLS session.
        let Control::Auth { identity_key, signature } = read_control(&mut tls, &mut decoder) else {
            panic!("expected auth")
        };
        assert_eq!(identity_key, node_key);
        UnparsedPublicKey::new(&ED25519, identity_key)
            .verify(&session_proof_message(&exporter, ROLE_NODE), &signature)
            .expect("server session proof must verify against the client's exporter");

        let proof: [u8; 64] =
            mac_identity.sign(&session_proof_message(&exporter, ROLE_WORKSTATION)).as_ref().try_into().unwrap();
        let mut out = Control::Auth { identity_key: mac_public, signature: proof }.to_frame().encode();
        out.extend(Control::Hello { app: "test".into(), device_name: "Studio Mac".into() }.to_frame().encode());
        tls.write_all(&out).unwrap();
        tls.flush().unwrap();
        let welcome = read_control(&mut tls, &mut decoder);
        let Control::Welcome { server_name, drives, .. } = welcome else { panic!("expected welcome, got {welcome:?}") };
        assert_eq!(server_name, "TLS Test");
        assert!(!drives.is_empty());
    }
}
