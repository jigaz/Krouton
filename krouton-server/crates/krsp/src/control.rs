// MARK: - control.rs

//! KRSP v1 control channel: `Control` (kind 8) frames carry one UTF-8 JSON object whose `"type"`
//! field names the message. `Telemetry` (kind 7) frames carry a `SpoolTelemetryPacket` object.
//! Field names are camelCase so Swift's default `Codable` maps them without `CodingKeys`.
//!
//! A session is:
//!
//! ```text
//! TLS 1.3, both sides present P-256 certificates and check each other's key pin
//! S→C Auth{identityKey, signature}       C→S Auth{identityKey, signature}   (Ed25519 over the TLS exporter)
//! C→S Hello{app, deviceName}             S→C Welcome{…drives…}
//! C→S Submit{job, drive, …} + ManifestOffer(kind 10)   S→C Accepted{job}
//!     BitmapQuery/ExtentData…  ⇄  BitmapReply/Credit/ExtentAck…   (resumable; see pipeline.rs)
//! S→C Job{state: queued…burning…done}, Telemetry frames while burning
//! C→S Watch / Cancel / ListJobs / Eject / Ping at any time
//! ```
//!
//! Pairing runs on a connection whose client certificate is not yet pinned, and only while the
//! operator has opened a pairing window on the server (`krouton-server pair`):
//!
//! ```text
//! C→S PairStart{deviceName}   S→C PairCommit{commitment}   C→S PairHello{hello}   S→C PairHello{hello}
//! both show the 6-digit code; C→S PairConfirm{accepted}; operator confirms on the server
//! S→C PairResult{accepted, nodeId, serverName}
//! ```

use crate::frame::{Frame, FrameHeader, FrameKind};
use crate::json::{self, JsonError, Value};
use crate::{hex, unhex};

// MARK: - Shared Types

/// Lifecycle of one burn job on the server. Wire names are lowercase.
#[derive(Clone, Copy, Debug, PartialEq, Eq, Hash)]
pub enum JobState {
    /// Waiting for (or receiving) the upload.
    Receiving,
    /// A folder upload is being unpacked and built into a disc image on the server.
    Mastering,
    /// Upload complete and verified against the manifest root; waiting for the drive.
    Queued,
    Burning,
    Verifying,
    Done,
    Failed,
    Cancelled,
}

impl JobState {
    pub const ALL: [Self; 8] = [
        Self::Receiving,
        Self::Mastering,
        Self::Queued,
        Self::Burning,
        Self::Verifying,
        Self::Done,
        Self::Failed,
        Self::Cancelled,
    ];

    #[must_use]
    pub fn wire_name(self) -> &'static str {
        match self {
            Self::Receiving => "receiving",
            Self::Mastering => "mastering",
            Self::Queued => "queued",
            Self::Burning => "burning",
            Self::Verifying => "verifying",
            Self::Done => "done",
            Self::Failed => "failed",
            Self::Cancelled => "cancelled",
        }
    }

    #[must_use]
    pub fn from_wire(name: &str) -> Option<Self> {
        Self::ALL.into_iter().find(|s| s.wire_name() == name)
    }

    #[must_use]
    pub fn is_terminal(self) -> bool {
        matches!(self, Self::Done | Self::Failed | Self::Cancelled)
    }
}

/// What the drive reports about the disc in the tray.
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum MediaState {
    Unknown,
    NoDisc,
    Blank,
    Appendable,
    Complete,
}

impl MediaState {
    #[must_use]
    pub fn wire_name(self) -> &'static str {
        match self {
            Self::Unknown => "unknown",
            Self::NoDisc => "noDisc",
            Self::Blank => "blank",
            Self::Appendable => "appendable",
            Self::Complete => "complete",
        }
    }

    #[must_use]
    pub fn from_wire(name: &str) -> Self {
        [Self::NoDisc, Self::Blank, Self::Appendable, Self::Complete]
            .into_iter()
            .find(|s| s.wire_name() == name)
            .unwrap_or(Self::Unknown)
    }
}

#[derive(Clone, Debug, PartialEq)]
pub struct DriveInfo {
    pub id: String,
    pub name: String,
    pub media: MediaState,
    /// Jobs queued or burning on this drive.
    pub queue: u32,
    pub busy: bool,
}

#[derive(Clone, Debug, PartialEq)]
pub struct JobInfo {
    pub job: String,
    pub drive: String,
    pub label: String,
    pub state: JobState,
    /// 0…1, or `None` when the backend cannot report progress (indeterminate).
    pub fraction: Option<f64>,
    /// Jobs that burn on the same drive before this one.
    pub queue_ahead: u32,
    pub message: String,
}

#[derive(Clone, Debug, PartialEq, Eq)]
pub struct BurnOptions {
    /// Write speed multiplier; 0 = the drive's maximum.
    pub speed: u32,
    pub verify: bool,
    /// Laser-off test write where the backend supports it.
    pub simulate: bool,
    pub eject: bool,
}

impl Default for BurnOptions {
    fn default() -> Self {
        Self { speed: 0, verify: true, simulate: false, eject: true }
    }
}

/// What a `submit` uploads.
#[derive(Clone, Copy, Debug, Default, PartialEq, Eq)]
pub enum Content {
    /// A finished 2048-byte-sector disc image (ISO/UDF), burned as is.
    #[default]
    Image,
    /// A KRSP bundle (`bundle.rs`) of a folder, which the server masters into an image first.
    Files,
}

impl Content {
    #[must_use]
    pub fn wire_name(self) -> &'static str {
        match self {
            Self::Image => "image",
            Self::Files => "files",
        }
    }

    #[must_use]
    pub fn from_wire(name: &str) -> Option<Self> {
        [Self::Image, Self::Files].into_iter().find(|c| c.wire_name() == name)
    }
}

/// Stable error codes (camelCase on the wire) so the app can localize them.
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum ErrorCode {
    BadRequest,
    NotAuthenticated,
    UnknownDrive,
    UnknownJob,
    NoSpace,
    TooLarge,
    ManifestRejected,
    DriveBusy,
    PairingClosed,
    PairingRejected,
    Internal,
}

impl ErrorCode {
    const ALL: [Self; 11] = [
        Self::BadRequest,
        Self::NotAuthenticated,
        Self::UnknownDrive,
        Self::UnknownJob,
        Self::NoSpace,
        Self::TooLarge,
        Self::ManifestRejected,
        Self::DriveBusy,
        Self::PairingClosed,
        Self::PairingRejected,
        Self::Internal,
    ];

    #[must_use]
    pub fn wire_name(self) -> &'static str {
        match self {
            Self::BadRequest => "badRequest",
            Self::NotAuthenticated => "notAuthenticated",
            Self::UnknownDrive => "unknownDrive",
            Self::UnknownJob => "unknownJob",
            Self::NoSpace => "noSpace",
            Self::TooLarge => "tooLarge",
            Self::ManifestRejected => "manifestRejected",
            Self::DriveBusy => "driveBusy",
            Self::PairingClosed => "pairingClosed",
            Self::PairingRejected => "pairingRejected",
            Self::Internal => "internal",
        }
    }

    #[must_use]
    pub fn from_wire(name: &str) -> Self {
        Self::ALL.into_iter().find(|c| c.wire_name() == name).unwrap_or(Self::Internal)
    }
}

// MARK: - Messages

/// Length of an encoded `SpoolPairingHello`: Ed25519 identity ‖ X25519 ephemeral ‖ 16-byte nonce.
pub const PAIRING_HELLO_LEN: usize = 80;

#[derive(Clone, Debug, PartialEq)]
pub enum Control {
    // Both directions
    Auth {
        identity_key: [u8; 32],
        signature: [u8; 64],
    },
    Ping {
        n: u64,
    },
    Pong {
        n: u64,
    },
    Error {
        code: ErrorCode,
        message: String,
        job: Option<String>,
    },

    // Client → server
    Hello {
        app: String,
        device_name: String,
    },
    ListDrives,
    Submit {
        job: String,
        drive: String,
        label: String,
        content: Content,
        options: BurnOptions,
    },
    Watch {
        job: String,
    },
    Cancel {
        job: String,
    },
    ListJobs,
    Eject {
        drive: String,
    },
    PairStart {
        device_name: String,
    },
    PairHello {
        hello: [u8; PAIRING_HELLO_LEN],
    },
    PairConfirm {
        accepted: bool,
    },

    // Server → client
    Welcome {
        server_name: String,
        node_id: String,
        version: String,
        max_image_bytes: u64,
        free_bytes: u64,
        /// File systems this server builds for `files` jobs (`iso9660`, `joliet`, `rockridge`,
        /// `udf`); empty when it cannot master folders.
        file_systems: Vec<String>,
        drives: Vec<DriveInfo>,
    },
    Drives {
        drives: Vec<DriveInfo>,
    },
    Accepted {
        job: String,
    },
    Job(JobInfo),
    Jobs {
        jobs: Vec<JobInfo>,
    },
    PairCommit {
        commitment: [u8; 32],
    },
    PairResult {
        accepted: bool,
        node_id: String,
        server_name: String,
    },
}

#[derive(Clone, Debug, PartialEq, Eq)]
pub enum ControlError {
    NotControl,
    Json(JsonError),
    UnknownType(String),
    MissingField(&'static str),
}

impl std::fmt::Display for ControlError {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        match self {
            Self::NotControl => write!(f, "not a control frame"),
            Self::Json(e) => write!(f, "{e}"),
            Self::UnknownType(t) => write!(f, "unknown control message type {t:?}"),
            Self::MissingField(name) => write!(f, "control message is missing or has an invalid {name:?}"),
        }
    }
}

impl std::error::Error for ControlError {}

// MARK: - Encode

impl Control {
    #[must_use]
    pub fn type_name(&self) -> &'static str {
        match self {
            Self::Auth { .. } => "auth",
            Self::Ping { .. } => "ping",
            Self::Pong { .. } => "pong",
            Self::Error { .. } => "error",
            Self::Hello { .. } => "hello",
            Self::ListDrives => "listDrives",
            Self::Submit { .. } => "submit",
            Self::Watch { .. } => "watch",
            Self::Cancel { .. } => "cancel",
            Self::ListJobs => "listJobs",
            Self::Eject { .. } => "eject",
            Self::PairStart { .. } => "pairStart",
            Self::PairHello { .. } => "pairHello",
            Self::PairConfirm { .. } => "pairConfirm",
            Self::Welcome { .. } => "welcome",
            Self::Drives { .. } => "drives",
            Self::Accepted { .. } => "accepted",
            Self::Job(_) => "job",
            Self::Jobs { .. } => "jobs",
            Self::PairCommit { .. } => "pairCommit",
            Self::PairResult { .. } => "pairResult",
        }
    }

    #[must_use]
    pub fn to_value(&self) -> Value {
        let mut fields: Vec<(String, Value)> = vec![("type".into(), self.type_name().into())];
        let mut put = |k: &str, v: Value| fields.push((k.to_owned(), v));
        match self {
            Self::Auth { identity_key, signature } => {
                put("identityKey", hex(identity_key).into());
                put("signature", hex(signature).into());
            }
            Self::Ping { n } | Self::Pong { n } => put("n", (*n).into()),
            Self::Error { code, message, job } => {
                put("code", code.wire_name().into());
                put("message", message.as_str().into());
                put("job", job.clone().into());
            }
            Self::Hello { app, device_name } => {
                put("app", app.as_str().into());
                put("deviceName", device_name.as_str().into());
            }
            Self::ListDrives | Self::ListJobs => {}
            Self::Submit { job, drive, label, content, options } => {
                put("job", job.as_str().into());
                put("drive", drive.as_str().into());
                put("label", label.as_str().into());
                put("content", content.wire_name().into());
                put("speed", options.speed.into());
                put("verify", options.verify.into());
                put("simulate", options.simulate.into());
                put("eject", options.eject.into());
            }
            Self::Watch { job } | Self::Cancel { job } | Self::Accepted { job } => put("job", job.as_str().into()),
            Self::Eject { drive } => put("drive", drive.as_str().into()),
            Self::PairStart { device_name } => put("deviceName", device_name.as_str().into()),
            Self::PairHello { hello } => put("hello", hex(hello).into()),
            Self::PairConfirm { accepted } => put("accepted", (*accepted).into()),
            Self::Welcome { server_name, node_id, version, max_image_bytes, free_bytes, file_systems, drives } => {
                put("serverName", server_name.as_str().into());
                put("nodeId", node_id.as_str().into());
                put("version", version.as_str().into());
                put("maxImageBytes", (*max_image_bytes).into());
                put("freeBytes", (*free_bytes).into());
                put("fileSystems", file_systems.iter().map(|f| Value::from(f.as_str())).collect::<Vec<_>>().into());
                put("drives", drives.iter().map(drive_value).collect::<Vec<_>>().into());
            }
            Self::Drives { drives } => put("drives", drives.iter().map(drive_value).collect::<Vec<_>>().into()),
            Self::Job(info) => {
                if let Value::Object(job) = job_value(info) {
                    fields.extend(job);
                }
            }
            Self::Jobs { jobs } => put("jobs", jobs.iter().map(job_value).collect::<Vec<_>>().into()),
            Self::PairCommit { commitment } => put("commitment", hex(commitment).into()),
            Self::PairResult { accepted, node_id, server_name } => {
                put("accepted", (*accepted).into());
                put("nodeId", node_id.as_str().into());
                put("serverName", server_name.as_str().into());
            }
        }
        Value::Object(fields)
    }

    #[must_use]
    pub fn to_frame(&self) -> Frame {
        Frame::new(FrameHeader::new(FrameKind::Control), self.to_value().to_json().into_bytes())
    }
}

fn drive_value(d: &DriveInfo) -> Value {
    Value::object([
        ("id", d.id.as_str().into()),
        ("name", d.name.as_str().into()),
        ("media", d.media.wire_name().into()),
        ("queue", d.queue.into()),
        ("busy", d.busy.into()),
    ])
}

fn job_value(j: &JobInfo) -> Value {
    Value::object([
        ("job", j.job.as_str().into()),
        ("drive", j.drive.as_str().into()),
        ("label", j.label.as_str().into()),
        ("state", j.state.wire_name().into()),
        ("fraction", j.fraction.into()),
        ("queueAhead", j.queue_ahead.into()),
        ("message", j.message.as_str().into()),
    ])
}

// MARK: - Decode

/// Longest string field accepted from a peer (names, labels, messages).
pub const MAX_TEXT: usize = 256;

fn text(v: &Value, key: &'static str) -> Result<String, ControlError> {
    v.get(key)
        .and_then(Value::as_str)
        .filter(|s| s.chars().count() <= MAX_TEXT)
        .map(str::to_owned)
        .ok_or(ControlError::MissingField(key))
}

/// Job and drive identifiers: 1…64 chars of `[A-Za-z0-9._-]`, so they are safe as file names.
#[must_use]
pub fn is_safe_identifier(s: &str) -> bool {
    !s.is_empty()
        && s.len() <= 64
        && !s.starts_with('.')
        && s.bytes().all(|b| b.is_ascii_alphanumeric() || b"._-".contains(&b))
}

fn ident(v: &Value, key: &'static str) -> Result<String, ControlError> {
    let s = text(v, key)?;
    if is_safe_identifier(&s) { Ok(s) } else { Err(ControlError::MissingField(key)) }
}

fn flag(v: &Value, key: &'static str) -> Result<bool, ControlError> {
    v.get(key).and_then(Value::as_bool).ok_or(ControlError::MissingField(key))
}

fn uint(v: &Value, key: &'static str) -> Result<u64, ControlError> {
    v.get(key).and_then(Value::as_u64).ok_or(ControlError::MissingField(key))
}

fn uint32(v: &Value, key: &'static str) -> Result<u32, ControlError> {
    u32::try_from(uint(v, key)?).map_err(|_| ControlError::MissingField(key))
}

fn bytes<const N: usize>(v: &Value, key: &'static str) -> Result<[u8; N], ControlError> {
    v.get(key)
        .and_then(Value::as_str)
        .and_then(unhex)
        .and_then(|b| <[u8; N]>::try_from(b).ok())
        .ok_or(ControlError::MissingField(key))
}

fn drive_from(v: &Value) -> Result<DriveInfo, ControlError> {
    Ok(DriveInfo {
        id: ident(v, "id")?,
        name: text(v, "name")?,
        media: MediaState::from_wire(&text(v, "media")?),
        queue: uint32(v, "queue")?,
        busy: flag(v, "busy")?,
    })
}

fn job_from(v: &Value) -> Result<JobInfo, ControlError> {
    Ok(JobInfo {
        job: ident(v, "job")?,
        drive: ident(v, "drive")?,
        label: text(v, "label")?,
        state: JobState::from_wire(&text(v, "state")?).ok_or(ControlError::MissingField("state"))?,
        fraction: v.get("fraction").and_then(Value::as_f64).filter(|f| f.is_finite()).map(|f| f.clamp(0.0, 1.0)),
        queue_ahead: uint32(v, "queueAhead")?,
        message: text(v, "message")?,
    })
}

fn list<T>(v: &Value, key: &'static str, each: fn(&Value) -> Result<T, ControlError>) -> Result<Vec<T>, ControlError> {
    v.get(key).and_then(Value::as_array).ok_or(ControlError::MissingField(key))?.iter().map(each).collect()
}

impl Control {
    pub fn from_value(v: &Value) -> Result<Self, ControlError> {
        let kind = v.get("type").and_then(Value::as_str).ok_or(ControlError::MissingField("type"))?;
        Ok(match kind {
            "auth" => Self::Auth { identity_key: bytes(v, "identityKey")?, signature: bytes(v, "signature")? },
            "ping" => Self::Ping { n: uint(v, "n")? },
            "pong" => Self::Pong { n: uint(v, "n")? },
            "error" => Self::Error {
                code: ErrorCode::from_wire(&text(v, "code")?),
                message: text(v, "message")?,
                job: v.get("job").and_then(Value::as_str).filter(|s| is_safe_identifier(s)).map(str::to_owned),
            },
            "hello" => Self::Hello { app: text(v, "app")?, device_name: text(v, "deviceName")? },
            "listDrives" => Self::ListDrives,
            "submit" => Self::Submit {
                job: ident(v, "job")?,
                drive: ident(v, "drive")?,
                label: text(v, "label")?,
                content: match v.get("content") {
                    None => Content::Image,
                    Some(c) => c.as_str().and_then(Content::from_wire).ok_or(ControlError::MissingField("content"))?,
                },
                options: BurnOptions {
                    speed: uint32(v, "speed")?,
                    verify: flag(v, "verify")?,
                    simulate: flag(v, "simulate")?,
                    eject: flag(v, "eject")?,
                },
            },
            "watch" => Self::Watch { job: ident(v, "job")? },
            "cancel" => Self::Cancel { job: ident(v, "job")? },
            "listJobs" => Self::ListJobs,
            "eject" => Self::Eject { drive: ident(v, "drive")? },
            "pairStart" => Self::PairStart { device_name: text(v, "deviceName")? },
            "pairHello" => Self::PairHello { hello: bytes(v, "hello")? },
            "pairConfirm" => Self::PairConfirm { accepted: flag(v, "accepted")? },
            "welcome" => Self::Welcome {
                server_name: text(v, "serverName")?,
                node_id: text(v, "nodeId")?,
                version: text(v, "version")?,
                max_image_bytes: uint(v, "maxImageBytes")?,
                free_bytes: uint(v, "freeBytes")?,
                file_systems: match v.get("fileSystems") {
                    None => Vec::new(),
                    Some(_) => list(v, "fileSystems", |f| {
                        f.as_str()
                            .filter(|s| is_safe_identifier(s))
                            .map(str::to_owned)
                            .ok_or(ControlError::MissingField("fileSystems"))
                    })?,
                },
                drives: list(v, "drives", drive_from)?,
            },
            "drives" => Self::Drives { drives: list(v, "drives", drive_from)? },
            "accepted" => Self::Accepted { job: ident(v, "job")? },
            "job" => Self::Job(job_from(v)?),
            "jobs" => Self::Jobs { jobs: list(v, "jobs", job_from)? },
            "pairCommit" => Self::PairCommit { commitment: bytes(v, "commitment")? },
            "pairResult" => Self::PairResult {
                accepted: flag(v, "accepted")?,
                node_id: text(v, "nodeId")?,
                server_name: text(v, "serverName")?,
            },
            other => return Err(ControlError::UnknownType(other.chars().take(32).collect())),
        })
    }

    pub fn from_frame(frame: &Frame) -> Result<Self, ControlError> {
        if frame.header.kind != FrameKind::Control {
            return Err(ControlError::NotControl);
        }
        Self::from_value(&json::parse(&frame.payload).map_err(ControlError::Json)?)
    }
}

// MARK: - Telemetry (kind 7)

/// Encodes a live burn sample as the Swift `SpoolTelemetryPacket` JSON (default `Codable` keys).
#[must_use]
pub fn telemetry_frame(job: &str, sample: &crate::telemetry::TelemetrySample, eta_seconds: Option<u64>) -> Frame {
    let value = Value::object([
        ("batchId", job.into()),
        ("driveId", sample.drive_id.as_str().into()),
        ("state", sample.phase.wire_name().into()),
        ("fraction", sample.fraction.into()),
        ("currentLba", sample.current_lba.into()),
        ("totalLba", sample.total_lba.into()),
        ("effectiveSpeedX", sample.effective_speed_x.into()),
        ("fifoFill", sample.fifo_fill.into()),
        ("driveBufferFill", sample.drive_buffer_fill.into()),
        ("c2Errors", 0u32.into()),
        ("etaSeconds", eta_seconds.unwrap_or(0).into()),
    ]);
    Frame::new(FrameHeader::new(FrameKind::Telemetry), value.to_json().into_bytes())
}

#[cfg(test)]
#[allow(clippy::unwrap_used)]
mod tests {
    use super::*;

    fn samples() -> Vec<Control> {
        let drive = DriveInfo {
            id: "drive-1".into(),
            name: "PIONEER BDR-XD08".into(),
            media: MediaState::Blank,
            queue: 2,
            busy: true,
        };
        let job = JobInfo {
            job: "0C5E1B2A-7F11-4C51-9C5E-2F6C9B1D0E77".into(),
            drive: "drive-1".into(),
            label: "Holiday 2026".into(),
            state: JobState::Burning,
            fraction: Some(0.25),
            queue_ahead: 0,
            message: "Writing track 1".into(),
        };
        vec![
            Control::Auth { identity_key: [7; 32], signature: [9; 64] },
            Control::Ping { n: 3 },
            Control::Pong { n: 3 },
            Control::Error { code: ErrorCode::NoSpace, message: "low".into(), job: Some("j1".into()) },
            Control::Error { code: ErrorCode::BadRequest, message: "x".into(), job: None },
            Control::Hello { app: "Krouton 1.0.1".into(), device_name: "Studio Mac".into() },
            Control::ListDrives,
            Control::Submit {
                job: "j1".into(),
                drive: "drive-1".into(),
                label: "L".into(),
                content: Content::Files,
                options: BurnOptions::default(),
            },
            Control::Watch { job: "j1".into() },
            Control::Cancel { job: "j1".into() },
            Control::ListJobs,
            Control::Eject { drive: "drive-1".into() },
            Control::PairStart { device_name: "Studio Mac".into() },
            Control::PairHello { hello: [1; PAIRING_HELLO_LEN] },
            Control::PairConfirm { accepted: true },
            Control::Welcome {
                server_name: "basement".into(),
                node_id: "cms3qugcq4mrn2xcapyo7q6ita".into(),
                version: "0.2.0".into(),
                max_image_bytes: 100_000_000_000,
                free_bytes: 5,
                file_systems: vec!["iso9660".into(), "joliet".into()],
                drives: vec![drive.clone()],
            },
            Control::Drives { drives: vec![drive] },
            Control::Accepted { job: "j1".into() },
            Control::Job(job.clone()),
            Control::Jobs { jobs: vec![job.clone(), JobInfo { fraction: None, ..job }] },
            Control::PairCommit { commitment: [4; 32] },
            Control::PairResult { accepted: true, node_id: "n".into(), server_name: "s".into() },
        ]
    }

    #[test]
    fn every_message_round_trips_through_a_frame() {
        for message in samples() {
            let frame = message.to_frame();
            assert_eq!(frame.header.kind, FrameKind::Control);
            assert_eq!(Control::from_frame(&frame).unwrap(), message, "{}", message.type_name());
        }
    }

    #[test]
    fn wire_shape_is_stable() {
        let text = Control::Submit {
            job: "j1".into(),
            drive: "d".into(),
            label: "L".into(),
            content: Content::Image,
            options: BurnOptions::default(),
        }
        .to_value()
        .to_json();
        assert_eq!(
            text,
            r#"{"type":"submit","job":"j1","drive":"d","label":"L","content":"image","speed":0,"verify":true,"simulate":false,"eject":true}"#
        );
    }

    #[test]
    fn older_clients_default_to_image_content_and_no_file_systems() {
        let v = json::parse(br#"{"type":"submit","job":"j","drive":"d","label":"L","speed":0,"verify":true,"simulate":false,"eject":true}"#).unwrap();
        assert!(matches!(Control::from_value(&v).unwrap(), Control::Submit { content: Content::Image, .. }));
        let v = json::parse(br#"{"type":"submit","job":"j","drive":"d","label":"L","content":"tarball","speed":0,"verify":true,"simulate":false,"eject":true}"#).unwrap();
        assert_eq!(Control::from_value(&v), Err(ControlError::MissingField("content")));
        let v = json::parse(br#"{"type":"welcome","serverName":"s","nodeId":"n","version":"1","maxImageBytes":1,"freeBytes":1,"drives":[]}"#).unwrap();
        assert!(
            matches!(Control::from_value(&v).unwrap(), Control::Welcome { file_systems, .. } if file_systems.is_empty())
        );
    }

    #[test]
    fn rejects_unsafe_identifiers_and_oversized_text() {
        for job in ["../etc/passwd", "", ".hidden", "a/b", "a b", &"x".repeat(65)] {
            let v = Value::object([("type", "watch".into()), ("job", job.into())]);
            assert!(Control::from_value(&v).is_err(), "accepted {job:?}");
        }
        let v = Value::object([
            ("type", "hello".into()),
            ("app", "x".repeat(MAX_TEXT + 1).into()),
            ("deviceName", "d".into()),
        ]);
        assert!(Control::from_value(&v).is_err());
        let v = Value::object([("type", "nope".into())]);
        assert_eq!(Control::from_value(&v), Err(ControlError::UnknownType("nope".into())));
        let v = Value::object([("type", "auth".into()), ("identityKey", "00".into()), ("signature", "00".into())]);
        assert!(Control::from_value(&v).is_err());
    }

    #[test]
    fn telemetry_matches_swift_packet_keys() {
        let sample = crate::telemetry::TelemetrySample {
            drive_id: "drive-1".into(),
            phase: crate::telemetry::TelemetryPhase::BurningProgress,
            fraction: 0.5,
            current_lba: 10,
            total_lba: 20,
            effective_speed_x: 8.0,
            fifo_fill: 1.0,
            drive_buffer_fill: 0.75,
        };
        let frame = telemetry_frame("J", &sample, Some(30));
        assert_eq!(frame.header.kind, FrameKind::Telemetry);
        assert_eq!(
            String::from_utf8(frame.payload).unwrap(),
            r#"{"batchId":"J","driveId":"drive-1","state":"BURNING_PROGRESS","fraction":0.5,"currentLba":10,"totalLba":20,"effectiveSpeedX":8,"fifoFill":1,"driveBufferFill":0.75,"c2Errors":0,"etaSeconds":30}"#
        );
    }
}
