// MARK: - session.rs

//! One connection's protocol state machine, independent of sockets and TLS.
//!
//! The transport (TLS in the binary, plain TCP in tests) supplies the peer's certificate pin
//! and the TLS exporter secret, feeds decoded frames to [`Session::on_frame`], calls
//! [`Session::tick`] a few times a second, and writes whatever frames come back.

use crate::clients::{ClientRecord, ClientStore};
use crate::jobs::{Event, JobManager, Submission, SubmitError};
use crate::pairing_window::{PairingWindow, unix_now};
use crate::store::StagedImage;
use krsp::control::{BurnOptions, Content, Control, ErrorCode, telemetry_frame};
use krsp::frame::{Frame, FrameKind};
use krsp::identity::{ROLE_NODE, ROLE_WORKSTATION, session_proof_message};
use krsp::manifest::ManifestOffer;
use krsp::pairing::{PairingHello, commitment, ct_eq, derive, transcript_salt};
use krsp::pipeline::StagingReceiver;
use std::sync::mpsc::Receiver;
use std::sync::{Arc, Mutex};
use std::time::{Duration, Instant};

pub const SERVER_VERSION: &str = env!("CARGO_PKG_VERSION");
/// How long the operator and the Mac user have to compare codes.
const PAIRING_DECISION_TIMEOUT: Duration = Duration::from_secs(120);
/// Extents the client may have in flight (each up to ~5 MB).
const UPLOAD_WINDOW: u32 = 4;

/// Ed25519 and X25519, provided by the binary (ring). Kept behind a trait so `server-core` stays
/// dependency-free and its tests can run with a stand-in.
pub trait NodeCrypto: Send + Sync + std::fmt::Debug {
    fn identity_public(&self) -> [u8; 32];
    fn sign(&self, message: &[u8]) -> [u8; 64];
    fn verify(&self, public: &[u8; 32], message: &[u8], signature: &[u8; 64]) -> bool;
    /// A fresh X25519 key pair for one pairing attempt.
    fn ephemeral(&self) -> Box<dyn Ephemeral>;
    /// 16 bytes from the OS CSPRNG (pairing nonces).
    fn random16(&self) -> [u8; 16];
}

pub trait Ephemeral: Send + std::fmt::Debug {
    fn public(&self) -> [u8; 32];
    /// Consumes the secret; `None` for an invalid (low-order) peer key.
    fn agree(self: Box<Self>, peer: &[u8; 32]) -> Option<[u8; 32]>;
}

/// Everything shared by all connections.
#[derive(Debug)]
pub struct ServerContext {
    pub jobs: Arc<JobManager>,
    pub clients: ClientStore,
    pub crypto: Box<dyn NodeCrypto>,
    pub pairing: PairingWindow,
    /// Only one pairing at a time.
    pub pairing_busy: Mutex<bool>,
    pub server_name: String,
    pub node_id: String,
}

/// What the transport knows about the peer after the TLS handshake.
#[derive(Clone, Debug)]
pub struct Peer {
    pub tls_pin: [u8; 32],
    pub exporter: [u8; 32],
    pub address: String,
}

#[derive(Debug)]
enum Phase {
    /// Pinned client: waiting for its Auth proof.
    AwaitAuth(ClientRecord),
    /// Authenticated; Hello may arrive at any time, then normal traffic.
    Ready(ClientRecord),
    /// Unknown client during an open pairing window.
    Pairing(PairingStep),
    Closed,
}

#[derive(Debug)]
enum PairingStep {
    Start,
    Hello { device: String, own: PairingHello, ephemeral: Box<dyn Ephemeral> },
    Confirm { device: String, peer: PairingHello, client_ok: Option<bool>, deadline: Instant },
}

#[derive(Debug)]
struct Upload {
    job: String,
    staged: StagedImage,
    receiver: StagingReceiver,
    last_progress: Instant,
    /// Every extent was already on the server (a resubmission after the upload had finished):
    /// the bitmap query is still answered, so the app's sender completes, but nothing is queued twice.
    already_complete: bool,
}

#[derive(Debug)]
struct PendingSubmit {
    job: String,
    drive: String,
    label: String,
    content: Content,
    options: BurnOptions,
}

#[derive(Debug)]
pub struct Session {
    ctx: Arc<ServerContext>,
    peer: Peer,
    phase: Phase,
    pending: Option<PendingSubmit>,
    upload: Option<Upload>,
    events: Option<(u64, Receiver<Event>)>,
    holds_pairing_lock: bool,
}

impl Session {
    /// Starts a session and returns it with the frames to send first.
    pub fn start(ctx: Arc<ServerContext>, peer: Peer) -> (Self, Vec<Frame>) {
        let (phase, out) = match ctx.clients.by_pin(&peer.tls_pin) {
            Some(client) => {
                let message = session_proof_message(&peer.exporter, ROLE_NODE);
                let auth =
                    Control::Auth { identity_key: ctx.crypto.identity_public(), signature: ctx.crypto.sign(&message) };
                (Phase::AwaitAuth(client), vec![auth.to_frame()])
            }
            None if ctx.pairing.is_open() => (Phase::Pairing(PairingStep::Start), Vec::new()),
            None => (
                Phase::Closed,
                vec![error(
                    ErrorCode::NotAuthenticated,
                    "This Mac is not paired with this server. Run `krouton-server pair` on the server, then add it again in Krouton.",
                    None,
                )],
            ),
        };
        crate::log(&format!(
            "{}: connected ({})",
            peer.address,
            match &phase {
                Phase::AwaitAuth(c) => format!("paired: {}", c.name),
                Phase::Pairing(_) => "pairing".into(),
                _ => "not paired, refused".into(),
            }
        ));
        let session = Self { ctx, peer, phase, pending: None, upload: None, events: None, holds_pairing_lock: false };
        (session, out)
    }

    #[must_use]
    pub fn is_closed(&self) -> bool {
        matches!(self.phase, Phase::Closed)
    }

    /// Handles one frame from the client.
    pub fn on_frame(&mut self, frame: &Frame) -> Vec<Frame> {
        match &self.phase {
            Phase::Closed => Vec::new(),
            Phase::Pairing(_) => self.on_pairing_frame(frame),
            Phase::AwaitAuth(_) => self.on_auth_frame(frame),
            Phase::Ready(_) => self.on_ready_frame(frame),
        }
    }

    /// Periodic work: forwards job events and advances pairing.
    pub fn tick(&mut self) -> Vec<Frame> {
        let mut out = Vec::new();
        if let Phase::Pairing(PairingStep::Confirm { .. }) = self.phase {
            out.extend(self.advance_pairing());
        }
        if let Some((_, rx)) = &self.events {
            for event in rx.try_iter().take(256) {
                out.push(match event {
                    Event::Job(info) => Control::Job(info).to_frame(),
                    Event::Telemetry { job, sample } => telemetry_frame(&job, &sample, None),
                });
            }
        }
        out
    }

    // MARK: Authentication

    fn on_auth_frame(&mut self, frame: &Frame) -> Vec<Frame> {
        let Phase::AwaitAuth(client) = &self.phase else { return Vec::new() };
        let client = client.clone();
        match Control::from_frame(frame) {
            Ok(Control::Auth { identity_key, signature }) => {
                let message = session_proof_message(&self.peer.exporter, ROLE_WORKSTATION);
                if ct_eq(&identity_key, &client.identity) && self.ctx.crypto.verify(&identity_key, &message, &signature)
                {
                    let owner = client.owner();
                    self.events = Some(self.ctx.jobs.subscribe(&owner));
                    crate::log(&format!("{}: authenticated as {}", self.peer.address, client.name));
                    self.phase = Phase::Ready(client);
                    Vec::new()
                } else {
                    self.close_with(ErrorCode::NotAuthenticated, "Session proof did not verify")
                }
            }
            _ => self.close_with(ErrorCode::NotAuthenticated, "Expected auth"),
        }
    }

    // MARK: Normal traffic

    fn owner(&self) -> String {
        match &self.phase {
            Phase::Ready(c) => c.owner(),
            _ => String::new(),
        }
    }

    fn on_ready_frame(&mut self, frame: &Frame) -> Vec<Frame> {
        match frame.header.kind {
            FrameKind::Control => match Control::from_frame(frame) {
                Ok(message) => self.on_control(message),
                Err(e) => vec![error(ErrorCode::BadRequest, &e.to_string(), None)],
            },
            FrameKind::ManifestOffer => self.on_manifest(frame),
            FrameKind::BitmapQuery | FrameKind::ExtentData => self.on_upload_frame(frame),
            _ => vec![error(ErrorCode::BadRequest, "Unexpected frame kind", None)],
        }
    }

    fn on_control(&mut self, message: Control) -> Vec<Frame> {
        let owner = self.owner();
        let jobs = &self.ctx.jobs;
        match message {
            Control::Hello { app, device_name } => {
                crate::log(&format!("{}: hello from {device_name} ({app})", self.peer.address));
                let free = crate::fsutil::free_bytes(&jobs.config.spool_dir).unwrap_or(0);
                let mut out = vec![
                    Control::Welcome {
                        server_name: self.ctx.server_name.clone(),
                        node_id: self.ctx.node_id.clone(),
                        version: SERVER_VERSION.into(),
                        max_image_bytes: jobs.config.max_image_bytes,
                        free_bytes: free.saturating_sub(jobs.config.min_free_bytes),
                        file_systems: jobs.file_systems().to_vec(),
                        drives: jobs.drive_infos(),
                    }
                    .to_frame(),
                ];
                out.push(Control::Jobs { jobs: jobs.jobs_of(&owner) }.to_frame());
                out
            }
            Control::ListDrives => vec![Control::Drives { drives: jobs.drive_infos() }.to_frame()],
            Control::ListJobs => vec![Control::Jobs { jobs: jobs.jobs_of(&owner) }.to_frame()],
            Control::Ping { n } => vec![Control::Pong { n }.to_frame()],
            Control::Watch { job } => match jobs.job_info(&owner, &job) {
                Some(info) => vec![Control::Job(info).to_frame()],
                None => vec![error(ErrorCode::UnknownJob, "No such job", Some(job))],
            },
            Control::Cancel { job } => {
                if jobs.cancel(&owner, &job) {
                    if self.upload.as_ref().is_some_and(|u| u.job == job) {
                        self.upload = None;
                    }
                    Vec::new()
                } else {
                    vec![error(ErrorCode::UnknownJob, "No such job", Some(job))]
                }
            }
            Control::Eject { drive } => match jobs.eject(&drive) {
                Ok(()) => vec![Control::Drives { drives: jobs.drive_infos() }.to_frame()],
                Err(e) => vec![error(ErrorCode::DriveBusy, &e, None)],
            },
            Control::Submit { job, drive, label, content, options } => {
                if self.upload.is_some() || self.pending.is_some() {
                    return vec![error(ErrorCode::BadRequest, "Finish the current upload first", Some(job))];
                }
                self.pending = Some(PendingSubmit { job, drive, label, content, options });
                Vec::new()
            }
            Control::Auth { .. } => Vec::new(),
            other => {
                vec![error(ErrorCode::BadRequest, &format!("{} is not a client message", other.type_name()), None)]
            }
        }
    }

    fn on_manifest(&mut self, frame: &Frame) -> Vec<Frame> {
        let Some(submit) = self.pending.take() else {
            return vec![error(ErrorCode::BadRequest, "Send submit before the manifest", None)];
        };
        let manifest = match ManifestOffer::decode(frame) {
            Ok(m) => m,
            Err(_) => return vec![error(ErrorCode::ManifestRejected, "The manifest is malformed", Some(submit.job))],
        };
        let owner = self.owner();
        let submission = Submission {
            owner: &owner,
            job: &submit.job,
            drive: &submit.drive,
            label: &submit.label,
            content: submit.content,
            options: &submit.options,
        };
        match self.ctx.jobs.begin_upload(&submission, &manifest) {
            Ok(mut staged) => {
                let mut out = vec![Control::Accepted { job: submit.job.clone() }.to_frame()];
                let already_complete = staged.is_complete();
                if already_complete {
                    // A retry of a failed job whose image is still staged, or a resubmission after the
                    // last extent landed: no upload needed, the burn is queued right away.
                    if let Err(e) = self.ctx.jobs.finish_upload(&submit.job, &mut staged) {
                        out.push(error(ErrorCode::Internal, &e.to_string(), Some(submit.job)));
                        return out;
                    }
                }
                let receiver = StagingReceiver::new(manifest, staged.committed().clone(), UPLOAD_WINDOW);
                crate::log(&format!(
                    "{}: upload {} {}",
                    self.peer.address,
                    submit.job,
                    if already_complete { "already complete" } else { "started" }
                ));
                self.upload =
                    Some(Upload { job: submit.job, staged, receiver, last_progress: Instant::now(), already_complete });
                out
            }
            Err(e) => {
                let (code, message) = match e {
                    SubmitError::UnknownDrive => (ErrorCode::UnknownDrive, "No such drive on this server".to_owned()),
                    SubmitError::UnknownJob => (ErrorCode::UnknownJob, "No such job".to_owned()),
                    SubmitError::AlreadySubmitted => {
                        (ErrorCode::BadRequest, "This job was already submitted".to_owned())
                    }
                    SubmitError::TooLarge => {
                        (ErrorCode::TooLarge, "The image is larger than this server accepts".to_owned())
                    }
                    SubmitError::NoSpace { free, needed } => (
                        ErrorCode::NoSpace,
                        format!("Not enough space on the server: {} MB free, {} MB needed", free >> 20, needed >> 20),
                    ),
                    SubmitError::UnsupportedSectorSize(s) => (
                        ErrorCode::BadRequest,
                        format!(
                            "Only 2048-byte data images (ISO/UDF) can be burned remotely; this one uses {s}-byte sectors"
                        ),
                    ),
                    SubmitError::MasteringUnavailable => (
                        ErrorCode::BadRequest,
                        "This server can’t build discs from folders (on Linux, install xorriso)".to_owned(),
                    ),
                    SubmitError::Io(e) => (ErrorCode::Internal, e),
                };
                vec![error(code, &message, Some(submit.job))]
            }
        }
    }

    fn on_upload_frame(&mut self, frame: &Frame) -> Vec<Frame> {
        let owner = self.owner();
        let Some(upload) = self.upload.as_mut() else {
            return vec![error(ErrorCode::BadRequest, "No upload in progress", None)];
        };
        if upload.already_complete {
            // Answer the bitmap query (all present); there is nothing to persist.
            let replies = upload.receiver.handle_frame(frame, |_, _| false);
            if frame.header.kind == FrameKind::BitmapQuery {
                self.upload = None;
            }
            return replies;
        }
        let still_wanted =
            self.ctx.jobs.job_info(&owner, &upload.job).is_some_and(|j| j.state == krsp::control::JobState::Receiving);
        if !still_wanted {
            self.upload = None;
            return Vec::new();
        }
        let mut io_error = None;
        let staged = &mut upload.staged;
        let replies = upload.receiver.handle_frame(frame, |index, bytes| match staged.commit(index, bytes) {
            Ok(()) => true,
            Err(e) => {
                io_error = Some(e.to_string());
                false
            }
        });
        let mut out = replies;
        if let Some(e) = io_error {
            let job = upload.job.clone();
            self.upload = None;
            out.push(error(ErrorCode::Internal, &format!("Could not write to the spool disk: {e}"), Some(job)));
            return out;
        }
        if upload.staged.is_complete() {
            let job = upload.job.clone();
            let result = self.ctx.jobs.finish_upload(&job, &mut upload.staged);
            self.upload = None;
            crate::log(&format!("{}: upload {job} complete", self.peer.address));
            if let Err(e) = result {
                out.push(error(ErrorCode::Internal, &e.to_string(), Some(job)));
            }
        } else if upload.last_progress.elapsed() >= Duration::from_millis(500) {
            upload.last_progress = Instant::now();
            let c = upload.staged.committed();
            self.ctx.jobs.upload_progress(&upload.job, c.committed_count(), c.count());
        }
        out
    }

    // MARK: Pairing

    fn on_pairing_frame(&mut self, frame: &Frame) -> Vec<Frame> {
        let Ok(message) = Control::from_frame(frame) else {
            return self.close_with(ErrorCode::BadRequest, "Pairing expects control messages");
        };
        let Phase::Pairing(step) = std::mem::replace(&mut self.phase, Phase::Closed) else { return Vec::new() };
        match (step, message) {
            (PairingStep::Start, Control::PairStart { device_name }) => {
                if !self.ctx.pairing.is_open() {
                    return self.close_with(ErrorCode::PairingClosed, "The pairing window on the server has closed");
                }
                let Ok(mut busy) = self.ctx.pairing_busy.lock() else { return Vec::new() };
                if *busy {
                    drop(busy);
                    return self.close_with(ErrorCode::PairingClosed, "Another Mac is pairing right now");
                }
                *busy = true;
                drop(busy);
                self.holds_pairing_lock = true;
                let ephemeral = self.ctx.crypto.ephemeral();
                let own = PairingHello {
                    identity_key: self.ctx.crypto.identity_public(),
                    ephemeral_key: ephemeral.public(),
                    nonce: self.ctx.crypto.random16(),
                };
                let device: String = device_name.chars().filter(|c| !c.is_control()).take(64).collect();
                self.phase = Phase::Pairing(PairingStep::Hello { device, own, ephemeral });
                vec![Control::PairCommit { commitment: commitment(&own) }.to_frame()]
            }
            (PairingStep::Hello { device, own, ephemeral }, Control::PairHello { hello }) => {
                let peer = PairingHello::decode(&hello);
                let Some(shared) = ephemeral.agree(&peer.ephemeral_key) else {
                    return self.close_with(ErrorCode::PairingRejected, "Invalid pairing key");
                };
                // The app is the initiator: its hello comes first in the transcript.
                let secrets = derive(&shared, &transcript_salt(&peer, &own));
                if self.ctx.pairing.post_request(&secrets.code, &device).is_err() {
                    return self.close_with(ErrorCode::Internal, "Could not reach the pairing prompt");
                }
                crate::log(&format!("{}: pairing {device}, waiting for the operator to confirm", self.peer.address));
                self.phase = Phase::Pairing(PairingStep::Confirm {
                    device,
                    peer,
                    client_ok: None,
                    deadline: Instant::now() + PAIRING_DECISION_TIMEOUT,
                });
                vec![Control::PairHello { hello: own.encode() }.to_frame()]
            }
            (PairingStep::Confirm { device, peer, deadline, .. }, Control::PairConfirm { accepted }) => {
                self.phase = Phase::Pairing(PairingStep::Confirm { device, peer, client_ok: Some(accepted), deadline });
                self.advance_pairing()
            }
            _ => self.close_with(ErrorCode::PairingRejected, "Unexpected pairing message"),
        }
    }

    fn advance_pairing(&mut self) -> Vec<Frame> {
        let Phase::Pairing(PairingStep::Confirm { device, peer, client_ok, deadline }) = &self.phase else {
            return Vec::new();
        };
        let operator = self.ctx.pairing.decision();
        let timed_out = Instant::now() >= *deadline;
        let verdict = match (operator, *client_ok) {
            (Some(false), _) | (_, Some(false)) => Some(false),
            (Some(true), Some(true)) => Some(true),
            _ if timed_out => Some(false),
            _ => None,
        };
        let Some(accepted) = verdict else { return Vec::new() };
        let device = device.clone();
        let identity = peer.identity_key;
        let out = if accepted {
            let record =
                ClientRecord { tls_pin: self.peer.tls_pin, identity, paired_at: unix_now(), name: device.clone() };
            match self.ctx.clients.upsert(record) {
                Ok(()) => {
                    self.ctx.pairing.post_result(&format!("Paired with {device}."));
                    crate::log(&format!("{}: paired {device}", self.peer.address));
                    vec![
                        Control::PairResult {
                            accepted: true,
                            node_id: self.ctx.node_id.clone(),
                            server_name: self.ctx.server_name.clone(),
                        }
                        .to_frame(),
                    ]
                }
                Err(e) => {
                    self.ctx.pairing.post_result(&format!("Pairing failed: {e}"));
                    vec![error(ErrorCode::Internal, &format!("Could not save the pairing: {e}"), None)]
                }
            }
        } else {
            let why = if timed_out { "timed out" } else { "was rejected" };
            self.ctx.pairing.post_result(&format!("Pairing with {device} {why}."));
            vec![
                Control::PairResult {
                    accepted: false,
                    node_id: String::new(),
                    server_name: self.ctx.server_name.clone(),
                }
                .to_frame(),
            ]
        };
        self.release_pairing_lock();
        self.phase = Phase::Closed;
        out
    }

    fn release_pairing_lock(&mut self) {
        if self.holds_pairing_lock {
            if let Ok(mut busy) = self.ctx.pairing_busy.lock() {
                *busy = false;
            }
            self.holds_pairing_lock = false;
        }
    }

    fn close_with(&mut self, code: ErrorCode, message: &str) -> Vec<Frame> {
        crate::log(&format!("{}: closing: {message}", self.peer.address));
        self.release_pairing_lock();
        self.phase = Phase::Closed;
        vec![error(code, message, None)]
    }
}

impl Drop for Session {
    fn drop(&mut self) {
        if let Phase::Pairing(PairingStep::Confirm { device, .. }) = &self.phase {
            self.ctx.pairing.post_result(&format!("{device} disconnected before pairing finished."));
        }
        self.release_pairing_lock();
        if let Some((id, _)) = self.events.take() {
            self.ctx.jobs.unsubscribe(id);
        }
    }
}

fn error(code: ErrorCode, message: &str, job: Option<String>) -> Frame {
    Control::Error { code, message: message.to_owned(), job }.to_frame()
}
