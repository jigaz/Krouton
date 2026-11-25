//! The whole server over real TCP sockets with the simulated drive backend: pairing with
//! operator confirmation, session authentication, a resumable upload interrupted mid-way, the
//! burn with telemetry, job isolation between two Macs, and rejection of unpaired peers.
//!
//! TLS is the binary's job; here the "peer pin" and "exporter" the TLS layer would supply are
//! fixed per connection, and Ed25519/X25519 are replaced by a deterministic stand-in.
#![allow(
    clippy::unwrap_used,
    clippy::expect_used,
    clippy::indexing_slicing,
    clippy::cast_possible_truncation,
    clippy::panic
)]

use krsp::control::{BurnOptions, Control, ErrorCode, JobState};
use krsp::frame::{Frame, FrameDecoder, FrameKind};
use krsp::identity::{ROLE_NODE, ROLE_WORKSTATION, session_proof_message};
use krsp::manifest::{ManifestOffer, TransferManifest};
use krsp::pairing::{PairingHello, commitment, derive, transcript_salt};
use krsp::pipeline::{SenderPhase, UploadSender};
use krsp::sha256::Sha256;
use server_core::clients::ClientStore;
use server_core::config::{BackendKind, Config};
use server_core::jobs::JobManager;
use server_core::pairing_window::PairingWindow;
use server_core::testutil::TempDir;
use server_core::{
    Ephemeral, NodeCrypto, Peer, PlainTransport, ServerContext, Session, drive_connection, spawn_reader,
};
use std::io::{Read, Write};
use std::net::{TcpListener, TcpStream};
use std::sync::{Arc, Mutex};
use std::time::{Duration, Instant};

// MARK: - Stand-in crypto (structure only; the binary uses ring)

fn fake_sign(public: &[u8; 32], message: &[u8]) -> [u8; 64] {
    let a = Sha256::digest(&[b"sig-a", public, message]);
    let b = Sha256::digest(&[b"sig-b", public, message]);
    let mut out = [0u8; 64];
    out[..32].copy_from_slice(&a);
    out[32..].copy_from_slice(&b);
    out
}

#[derive(Debug)]
struct FakeCrypto {
    public: [u8; 32],
}

#[derive(Debug)]
struct FakeEphemeral([u8; 32]);

impl Ephemeral for FakeEphemeral {
    fn public(&self) -> [u8; 32] {
        self.0
    }
    fn agree(self: Box<Self>, peer: &[u8; 32]) -> Option<[u8; 32]> {
        Some(fake_shared(&self.0, peer))
    }
}

/// Symmetric in its arguments, like a real DH result.
fn fake_shared(a: &[u8; 32], b: &[u8; 32]) -> [u8; 32] {
    let (lo, hi) = if a < b { (a, b) } else { (b, a) };
    Sha256::digest(&[b"dh", lo, hi])
}

impl NodeCrypto for FakeCrypto {
    fn identity_public(&self) -> [u8; 32] {
        self.public
    }
    fn sign(&self, message: &[u8]) -> [u8; 64] {
        fake_sign(&self.public, message)
    }
    fn verify(&self, public: &[u8; 32], message: &[u8], signature: &[u8; 64]) -> bool {
        fake_sign(public, message) == *signature
    }
    fn ephemeral(&self) -> Box<dyn Ephemeral> {
        Box::new(FakeEphemeral([0xE5; 32]))
    }
    fn random16(&self) -> [u8; 16] {
        [0x16; 16]
    }
}

// MARK: - Harness

const NODE_KEY: [u8; 32] = [0xAA; 32];

struct Harness {
    _tmp: TempDir,
    addr: std::net::SocketAddr,
    ctx: Arc<ServerContext>,
    /// The TLS pin + exporter the "TLS layer" reports for the next accepted connection.
    next_peer: Arc<Mutex<([u8; 32], [u8; 32])>>,
}

fn start_server() -> Harness {
    let tmp = TempDir::new("e2e");
    let mut config = Config::defaults(tmp.path());
    config.backend = BackendKind::Simulate;
    config.simulate_drives = 2;
    config.simulate_seconds = 1;
    config.min_free_bytes = 0;
    let backend = server_core::backend::from_config(&config);
    let jobs = JobManager::new(config, backend).unwrap();
    jobs.start_workers();
    let (clients, _) = ClientStore::load(tmp.path());
    let ctx = Arc::new(ServerContext {
        jobs,
        clients,
        crypto: Box::new(FakeCrypto { public: NODE_KEY }),
        pairing: PairingWindow::new(tmp.path()),
        pairing_busy: Mutex::new(false),
        server_name: "Test Burner".into(),
        node_id: krsp::identity::node_id(&NODE_KEY),
    });
    let listener = TcpListener::bind("127.0.0.1:0").unwrap();
    let addr = listener.local_addr().unwrap();
    let next_peer = Arc::new(Mutex::new(([0u8; 32], [0u8; 32])));
    let (c, np) = (Arc::clone(&ctx), Arc::clone(&next_peer));
    std::thread::spawn(move || {
        for stream in listener.incoming() {
            let stream = stream.unwrap();
            let (tls_pin, exporter) = *np.lock().unwrap();
            let ctx = Arc::clone(&c);
            std::thread::spawn(move || {
                let incoming = spawn_reader(stream.try_clone().unwrap());
                let peer = Peer { tls_pin, exporter, address: "test".into() };
                let (session, first) = Session::start(ctx, peer);
                let mut transport = PlainTransport(stream.try_clone().unwrap());
                let _ = drive_connection(&mut transport, &incoming, session, &first, Duration::from_secs(30));
                let _ = stream.shutdown(std::net::Shutdown::Both);
            });
        }
    });
    Harness { _tmp: tmp, addr, ctx, next_peer }
}

struct Client {
    stream: TcpStream,
    decoder: FrameDecoder,
    inbox: Vec<Frame>,
}

impl Client {
    fn connect(h: &Harness, tls_pin: [u8; 32], exporter: [u8; 32]) -> Self {
        *h.next_peer.lock().unwrap() = (tls_pin, exporter);
        let stream = TcpStream::connect(h.addr).unwrap();
        stream.set_read_timeout(Some(Duration::from_millis(50))).unwrap();
        // Give the accept thread time to read `next_peer` before another connect changes it.
        std::thread::sleep(Duration::from_millis(50));
        Self { stream, decoder: FrameDecoder::new(), inbox: Vec::new() }
    }

    fn send(&mut self, frames: &[Frame]) {
        for f in frames {
            self.stream.write_all(&f.encode()).unwrap();
        }
    }

    fn send_control(&mut self, c: Control) {
        self.send(&[c.to_frame()]);
    }

    fn pump(&mut self) -> bool {
        let mut buf = [0u8; 65536];
        match self.stream.read(&mut buf) {
            Ok(0) => false,
            Ok(n) => {
                self.inbox.extend(self.decoder.push(&buf[..n]).unwrap());
                true
            }
            Err(_) => true,
        }
    }

    /// Waits for (and removes) the first frame matching `pred`.
    fn expect(&mut self, what: &str, pred: impl Fn(&Frame) -> bool) -> Frame {
        let deadline = Instant::now() + Duration::from_secs(20);
        loop {
            if let Some(i) = self.inbox.iter().position(&pred) {
                return self.inbox.remove(i);
            }
            assert!(
                Instant::now() < deadline,
                "timed out waiting for {what}; inbox: {:?}",
                self.inbox
                    .iter()
                    .map(|f| Control::from_frame(f)
                        .map(|c| c.type_name().to_owned())
                        .unwrap_or_else(|_| format!("{:?}", f.header.kind)))
                    .collect::<Vec<_>>()
            );
            if !self.pump() {
                assert!(self.inbox.iter().any(&pred), "connection closed while waiting for {what}");
            }
        }
    }

    fn expect_control(&mut self, what: &str, pred: impl Fn(&Control) -> bool) -> Control {
        let f = self.expect(what, |f| Control::from_frame(f).is_ok_and(|c| pred(&c)));
        Control::from_frame(&f).unwrap()
    }

    fn is_closed_by_server(&mut self) -> bool {
        let deadline = Instant::now() + Duration::from_secs(5);
        while Instant::now() < deadline {
            if !self.pump() {
                return true;
            }
        }
        false
    }
}

/// Pairs a Mac with identity `identity` and TLS pin `pin`; `operator_accepts` is the server-side answer.
fn pair(h: &Harness, identity: [u8; 32], pin: [u8; 32], operator_accepts: bool) -> Control {
    let window = PairingWindow::new(&h.ctx.jobs.config.state_dir);
    window.open(Duration::from_secs(60)).unwrap();
    let operator = std::thread::spawn(move || {
        let (code, device) = window.wait_request(Duration::from_secs(10)).expect("no pairing request");
        window.decide(operator_accepts).unwrap();
        let result = window.wait_result(Duration::from_secs(10));
        window.close();
        (code, device, result)
    });

    let mut c = Client::connect(h, pin, [1; 32]);
    c.send_control(Control::PairStart { device_name: "Studio Mac".into() });
    let server_commit = match c.expect_control("pairCommit", |m| matches!(m, Control::PairCommit { .. })) {
        Control::PairCommit { commitment } => commitment,
        _ => unreachable!(),
    };
    let my_ephemeral = [0x42; 32];
    let mine = PairingHello { identity_key: identity, ephemeral_key: my_ephemeral, nonce: [7; 16] };
    c.send_control(Control::PairHello { hello: mine.encode() });
    let theirs = match c.expect_control("pairHello", |m| matches!(m, Control::PairHello { .. })) {
        Control::PairHello { hello } => PairingHello::decode(&hello),
        _ => unreachable!(),
    };
    assert_eq!(commitment(&theirs), server_commit, "server must honour its commitment");
    assert_eq!(theirs.identity_key, NODE_KEY);
    let my_code = derive(&fake_shared(&my_ephemeral, &theirs.ephemeral_key), &transcript_salt(&mine, &theirs)).code;
    c.send_control(Control::PairConfirm { accepted: true });
    let result = c.expect_control("pairResult", |m| matches!(m, Control::PairResult { .. }));
    let (operator_code, device, outcome) = operator.join().unwrap();
    assert_eq!(operator_code, my_code, "both screens must show the same code");
    assert_eq!(device, "Studio Mac");
    assert!(outcome.is_some());
    result
}

fn authenticate(h: &Harness, identity: [u8; 32], pin: [u8; 32], exporter: [u8; 32]) -> Client {
    let mut c = Client::connect(h, pin, exporter);
    let server_auth = c.expect_control("server auth", |m| matches!(m, Control::Auth { .. }));
    let Control::Auth { identity_key, signature } = server_auth else { unreachable!() };
    assert_eq!(identity_key, NODE_KEY);
    assert_eq!(signature, fake_sign(&NODE_KEY, &session_proof_message(&exporter, ROLE_NODE)));
    c.send_control(Control::Auth {
        identity_key: identity,
        signature: fake_sign(&identity, &session_proof_message(&exporter, ROLE_WORKSTATION)),
    });
    c.send_control(Control::Hello { app: "Krouton test".into(), device_name: "Studio Mac".into() });
    c
}

fn test_image() -> Vec<u8> {
    (0..600usize * 2048).map(|i| ((i * 13) ^ (i >> 10)) as u8).collect()
}

/// Uploads until `stop_after` extents are acked (or completion); returns the sender.
fn upload(c: &mut Client, image: &[u8], manifest: &TransferManifest, stop_after: Option<usize>) -> UploadSender {
    let mut sender = UploadSender::new(manifest.clone(), 4);
    let first = sender.connect();
    c.send(&first);
    let extent = |i: usize| {
        let r = manifest.byte_range(i);
        image[r.start as usize..r.end as usize].to_vec()
    };
    let deadline = Instant::now() + Duration::from_secs(30);
    while !matches!(sender.phase(), SenderPhase::Complete) {
        assert!(Instant::now() < deadline, "upload stalled in {:?}", sender.phase());
        if stop_after.is_some_and(|n| sender.acknowledged().committed_count() >= n) {
            return sender;
        }
        c.pump();
        let pipeline: Vec<Frame> = {
            let (keep, take): (Vec<Frame>, Vec<Frame>) = c
                .inbox
                .drain(..)
                .partition(|f| f.header.kind == FrameKind::Control || f.header.kind == FrameKind::Telemetry);
            c.inbox = keep;
            take
        };
        let bytes: Vec<u8> = pipeline.iter().flat_map(Frame::encode).collect();
        if !bytes.is_empty() {
            let out = sender.receive(&bytes, extent).unwrap();
            c.send(&out);
        }
        if let Some(err) = c.inbox.iter().find_map(|f| match Control::from_frame(f) {
            Ok(Control::Error { message, .. }) => Some(message),
            _ => None,
        }) {
            panic!("server error during upload: {err}");
        }
    }
    sender
}

// MARK: - Tests

#[test]
fn pair_upload_resume_burn_and_isolation() {
    let h = start_server();
    let mac = [0x11; 32];
    let mac_pin = [0x21; 32];

    // An unpaired Mac outside a pairing window is told so and disconnected.
    let mut stranger = Client::connect(&h, mac_pin, [1; 32]);
    let refused = stranger.expect_control("refusal", |m| matches!(m, Control::Error { .. }));
    assert!(matches!(refused, Control::Error { code: ErrorCode::NotAuthenticated, .. }));
    assert!(stranger.is_closed_by_server());

    // Pairing: both sides agree on the code, the operator confirms.
    let result = pair(&h, mac, mac_pin, true);
    assert!(matches!(result, Control::PairResult { accepted: true, .. }));
    assert_eq!(h.ctx.clients.by_pin(&mac_pin).unwrap().identity, mac);

    // Authenticated session.
    let mut c = authenticate(&h, mac, mac_pin, [9; 32]);
    let welcome = c.expect_control("welcome", |m| matches!(m, Control::Welcome { .. }));
    let Control::Welcome { drives, server_name, .. } = welcome else { unreachable!() };
    assert_eq!(server_name, "Test Burner");
    assert_eq!(drives.len(), 2);

    // Submit, upload half, drop the connection.
    let image = test_image();
    let manifest = TransferManifest::from_image(&image, 2048, 16).unwrap();
    let job = "6F1C2D3E-0000-4000-8000-000000000001".to_string();
    let submit = Control::Submit {
        job: job.clone(),
        drive: "sim-1".into(),
        label: "Holiday".into(),
        options: BurnOptions::default(),
    };
    c.send(&[submit.to_frame(), ManifestOffer::encode(&manifest).unwrap()]);
    c.expect_control("accepted", |m| matches!(m, Control::Accepted { .. }));
    upload(&mut c, &image, &manifest, Some(10));
    drop(c);
    std::thread::sleep(Duration::from_millis(200));

    // Reconnect and resume: only the missing extents are sent.
    let mut c = authenticate(&h, mac, mac_pin, [10; 32]);
    let jobs = c.expect_control("jobs", |m| matches!(m, Control::Jobs { .. }));
    let Control::Jobs { jobs } = jobs else { unreachable!() };
    assert_eq!(jobs.len(), 1);
    assert_eq!(jobs[0].state, JobState::Receiving);
    let submit = Control::Submit {
        job: job.clone(),
        drive: "sim-1".into(),
        label: "Holiday".into(),
        options: BurnOptions::default(),
    };
    c.send(&[submit.to_frame(), ManifestOffer::encode(&manifest).unwrap()]);
    c.expect_control("accepted again", |m| matches!(m, Control::Accepted { .. }));
    let sender = upload(&mut c, &image, &manifest, None);
    assert!(sender.acknowledged().is_complete());
    assert_eq!(sender.acknowledged().committed_count(), manifest.extent_count());

    // Queued → burning (with telemetry) → done.
    c.expect_control("burning", |m| matches!(m, Control::Job(j) if j.state == JobState::Burning));
    c.expect("telemetry", |f| {
        f.header.kind == FrameKind::Telemetry && String::from_utf8_lossy(&f.payload).contains("BURNING_PROGRESS")
    });
    let done = c.expect_control("done", |m| matches!(m, Control::Job(j) if j.state.is_terminal()));
    let Control::Job(done) = done else { unreachable!() };
    assert_eq!(done.state, JobState::Done, "{}", done.message);
    c.expect("final telemetry", |f| {
        f.header.kind == FrameKind::Telemetry && String::from_utf8_lossy(&f.payload).contains("BURN_COMPLETED")
    });

    // A second paired Mac cannot see, watch or cancel the first Mac's job.
    let other = [0x33; 32];
    let other_pin = [0x34; 32];
    assert!(matches!(pair(&h, other, other_pin, true), Control::PairResult { accepted: true, .. }));
    let mut o = authenticate(&h, other, other_pin, [11; 32]);
    let Control::Jobs { jobs } = o.expect_control("other jobs", |m| matches!(m, Control::Jobs { .. })) else {
        unreachable!()
    };
    assert!(jobs.is_empty());
    o.send_control(Control::Watch { job: job.clone() });
    assert!(matches!(
        o.expect_control("unknown job", |m| matches!(m, Control::Error { .. })),
        Control::Error { code: ErrorCode::UnknownJob, .. }
    ));
    o.send_control(Control::Cancel { job: job.clone() });
    assert!(matches!(
        o.expect_control("unknown job", |m| matches!(m, Control::Error { .. })),
        Control::Error { code: ErrorCode::UnknownJob, .. }
    ));
}

#[test]
fn bad_session_proof_and_operator_rejection_are_refused() {
    let h = start_server();
    let mac = [0x51; 32];
    let pin = [0x52; 32];

    // The operator says no: nothing is stored.
    assert!(matches!(pair(&h, mac, pin, false), Control::PairResult { accepted: false, .. }));
    assert!(h.ctx.clients.by_pin(&pin).is_none());

    assert!(matches!(pair(&h, mac, pin, true), Control::PairResult { accepted: true, .. }));
    // A proof made for a different TLS session (exporter) is rejected.
    let mut c = Client::connect(&h, pin, [5; 32]);
    c.expect_control("server auth", |m| matches!(m, Control::Auth { .. }));
    c.send_control(Control::Auth {
        identity_key: mac,
        signature: fake_sign(&mac, &session_proof_message(&[6; 32], ROLE_WORKSTATION)),
    });
    assert!(matches!(
        c.expect_control("refusal", |m| matches!(m, Control::Error { .. })),
        Control::Error { code: ErrorCode::NotAuthenticated, .. }
    ));
    assert!(c.is_closed_by_server());
}

#[test]
fn rejects_unsupported_images_and_unknown_drives() {
    let h = start_server();
    let mac = [0x61; 32];
    let pin = [0x62; 32];
    assert!(matches!(pair(&h, mac, pin, true), Control::PairResult { accepted: true, .. }));
    let mut c = authenticate(&h, mac, pin, [3; 32]);
    c.expect_control("welcome", |m| matches!(m, Control::Welcome { .. }));

    let audio = TransferManifest::from_image(&vec![0u8; 2352 * 8], 2352, 4).unwrap();
    c.send(&[
        Control::Submit {
            job: "a1".into(),
            drive: "sim-1".into(),
            label: "CD".into(),
            options: BurnOptions::default(),
        }
        .to_frame(),
        ManifestOffer::encode(&audio).unwrap(),
    ]);
    let e = c.expect_control("sector size error", |m| matches!(m, Control::Error { .. }));
    assert!(
        matches!(&e, Control::Error { code: ErrorCode::BadRequest, message, .. } if message.contains("2048")),
        "{e:?}"
    );

    let data = TransferManifest::from_image(&vec![0u8; 2048 * 8], 2048, 4).unwrap();
    c.send(&[
        Control::Submit { job: "a2".into(), drive: "nope".into(), label: "X".into(), options: BurnOptions::default() }
            .to_frame(),
        ManifestOffer::encode(&data).unwrap(),
    ]);
    assert!(matches!(
        c.expect_control("unknown drive", |m| matches!(m, Control::Error { .. })),
        Control::Error { code: ErrorCode::UnknownDrive, .. }
    ));

    c.send_control(Control::Ping { n: 77 });
    assert!(matches!(c.expect_control("pong", |m| matches!(m, Control::Pong { .. })), Control::Pong { n: 77 }));
}

#[test]
fn resubmitting_a_failed_job_reuses_the_staged_image() {
    let h = start_server();
    let mac = [0x71; 32];
    let pin = [0x72; 32];
    assert!(matches!(pair(&h, mac, pin, true), Control::PairResult { accepted: true, .. }));
    let mut c = authenticate(&h, mac, pin, [4; 32]);
    c.expect_control("welcome", |m| matches!(m, Control::Welcome { .. }));
    let image = test_image();
    let manifest = TransferManifest::from_image(&image, 2048, 16).unwrap();
    // A test burn is refused by nothing in the simulator, so cancel the queued job to make it "failed".
    let options = BurnOptions { speed: 0, verify: false, simulate: false, eject: false };
    let submit = Control::Submit {
        job: "retry-1".into(),
        drive: "sim-2".into(),
        label: "Retry".into(),
        options: options.clone(),
    };
    c.send(&[submit.to_frame(), ManifestOffer::encode(&manifest).unwrap()]);
    c.expect_control("accepted", |m| matches!(m, Control::Accepted { .. }));
    upload(&mut c, &image, &manifest, None);
    c.send_control(Control::Cancel { job: "retry-1".into() });
    c.expect_control("cancelled", |m| matches!(m, Control::Job(j) if j.state.is_terminal()));

    // The same job again: accepted at once, the sender completes from the bitmap alone, and it burns.
    let submit = Control::Submit { job: "retry-1".into(), drive: "sim-2".into(), label: "Retry".into(), options };
    c.send(&[submit.to_frame(), ManifestOffer::encode(&manifest).unwrap()]);
    c.expect_control("accepted again", |m| matches!(m, Control::Accepted { .. }));
    let sender = upload(&mut c, &image, &manifest, None);
    assert!(sender.acknowledged().is_complete());
    let done = c.expect_control("done", |m| matches!(m, Control::Job(j) if j.state == JobState::Done));
    assert!(matches!(done, Control::Job(_)));
}
