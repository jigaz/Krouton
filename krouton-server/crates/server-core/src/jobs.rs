// MARK: - jobs.rs

//! Jobs, queues and drive workers.
//!
//! * One worker thread per drive takes that drive's queued jobs in submission order.
//! * Job metadata lives in `<spool>/<job>/job.json`, so queued jobs and half-finished uploads
//!   survive a restart (a burn interrupted by a restart is marked failed: the disc is unknown).
//! * Events go only to connections of the Mac that owns the job; other Macs cannot see or touch it.
//! * Finished images are deleted right away; failed, cancelled and abandoned ones are kept for
//!   `keep_incomplete_hours` so the app can retry or resume without uploading again.

use crate::backend::{Backend, BurnRequest, Drive, Progress, Stage};
use crate::config::Config;
use crate::pairing_window::unix_now;
use crate::store::{IMAGE_FILE, StagedImage};
use krsp::control::{BurnOptions, DriveInfo, JobInfo, JobState, MediaState};
use krsp::json::{self, Value};
use krsp::telemetry::{TelemetryPhase, TelemetrySample};
use std::collections::HashMap;
use std::path::PathBuf;
use std::sync::atomic::{AtomicBool, AtomicU64, Ordering};
use std::sync::mpsc::{Receiver, Sender, channel};
use std::sync::{Arc, Condvar, Mutex, MutexGuard};
use std::time::{Duration, Instant};

const JOB_FILE: &str = "job.json";
const MEDIA_CACHE: Duration = Duration::from_secs(10);
const TELEMETRY_INTERVAL: Duration = Duration::from_millis(250);

/// What a connection receives about its owner's jobs.
#[derive(Clone, Debug, PartialEq)]
pub enum Event {
    Job(JobInfo),
    Telemetry { job: String, sample: TelemetrySample },
}

#[derive(Clone, Debug)]
pub struct Job {
    pub id: String,
    pub owner: String,
    pub drive: String,
    pub label: String,
    pub options: BurnOptions,
    pub state: JobState,
    pub fraction: Option<f64>,
    pub message: String,
    pub created: u64,
    pub updated: u64,
    pub image_bytes: u64,
    seq: u64,
}

#[derive(Debug, Default)]
struct State {
    jobs: HashMap<String, Job>,
    cancels: HashMap<String, Arc<AtomicBool>>,
    media: HashMap<String, (MediaState, Instant)>,
    subscribers: Vec<(u64, String, Sender<Event>)>,
    shutting_down: bool,
}

#[derive(Debug)]
pub struct JobManager {
    pub config: Config,
    backend: Box<dyn Backend>,
    drives: Vec<Drive>,
    state: Mutex<State>,
    wake: Condvar,
    seq: AtomicU64,
    next_subscriber: AtomicU64,
}

/// Why a submission was refused, mapped to a protocol error code by the session.
#[derive(Debug, PartialEq, Eq)]
pub enum SubmitError {
    UnknownDrive,
    UnknownJob,
    AlreadySubmitted,
    TooLarge,
    NoSpace { free: u64, needed: u64 },
    UnsupportedSectorSize(u32),
    Io(String),
}

impl JobManager {
    /// Discovers drives, reloads jobs from the spool directory and returns the manager. Call
    /// [`JobManager::start_workers`] to begin burning.
    pub fn new(config: Config, backend: Box<dyn Backend>) -> std::io::Result<Arc<Self>> {
        std::fs::create_dir_all(&config.spool_dir)?;
        let drives = backend.discover();
        let manager = Arc::new(Self {
            config,
            backend,
            drives,
            state: Mutex::new(State::default()),
            wake: Condvar::new(),
            seq: AtomicU64::new(1),
            next_subscriber: AtomicU64::new(1),
        });
        manager.reload();
        Ok(manager)
    }

    fn lock(&self) -> MutexGuard<'_, State> {
        self.state.lock().unwrap_or_else(std::sync::PoisonError::into_inner)
    }

    #[must_use]
    pub fn drives(&self) -> &[Drive] {
        &self.drives
    }

    #[must_use]
    pub fn backend(&self) -> &dyn Backend {
        self.backend.as_ref()
    }

    fn job_dir(&self, job: &str) -> PathBuf {
        self.config.spool_dir.join(job)
    }

    // MARK: Workers

    /// Spawns one worker per drive plus a janitor that prunes old uploads hourly.
    pub fn start_workers(self: &Arc<Self>) {
        for drive in self.drives.clone() {
            let me = Arc::clone(self);
            let name = format!("drive-{}", drive.id);
            if let Err(e) = std::thread::Builder::new().name(name).spawn(move || me.drive_loop(&drive)) {
                crate::log(&format!("could not start a drive worker: {e}"));
            }
        }
        let me = Arc::clone(self);
        std::thread::Builder::new()
            .name("janitor".into())
            .spawn(move || {
                loop {
                    me.prune();
                    let guard = me.lock();
                    if guard.shutting_down {
                        break;
                    }
                    drop(me.wake.wait_timeout(guard, Duration::from_secs(3600)));
                }
            })
            .ok();
    }

    pub fn shutdown(&self) {
        self.lock().shutting_down = true;
        self.wake.notify_all();
    }

    fn next_job_for(&self, drive: &str) -> Option<Job> {
        let mut state = self.lock();
        loop {
            if state.shutting_down {
                return None;
            }
            let next = state
                .jobs
                .values()
                .filter(|j| j.drive == drive && j.state == JobState::Queued)
                .min_by_key(|j| j.seq)
                .map(|j| j.id.clone());
            if let Some(id) = next {
                let job = state.jobs.get_mut(&id)?;
                job.state = JobState::Burning;
                job.fraction = Some(0.0);
                job.message = "Starting".into();
                job.updated = unix_now();
                let snapshot = job.clone();
                state.cancels.insert(id, Arc::new(AtomicBool::new(false)));
                drop(state);
                self.persist(&snapshot);
                self.publish_queue(drive);
                return Some(snapshot);
            }
            state = self.wake.wait(state).unwrap_or_else(std::sync::PoisonError::into_inner);
        }
    }

    fn drive_loop(&self, drive: &Drive) {
        while let Some(job) = self.next_job_for(&drive.id) {
            self.run_job(drive, &job);
        }
    }

    fn run_job(&self, drive: &Drive, job: &Job) {
        let cancel = self.lock().cancels.get(&job.id).cloned().unwrap_or_default();
        let image = self.job_dir(&job.id).join(IMAGE_FILE);
        let total_lba = job.image_bytes / 2048;
        let mut last_sent = Instant::now().checked_sub(TELEMETRY_INTERVAL).unwrap_or_else(Instant::now);
        let mut last_stage = Stage::Preparing;
        let mut on_progress = |p: Progress| {
            let state = if p.stage == Stage::Verifying { JobState::Verifying } else { JobState::Burning };
            let stage_changed = p.stage != last_stage;
            last_stage = p.stage;
            self.update(
                &job.id,
                |j| {
                    j.state = state;
                    if p.fraction.is_some() || stage_changed {
                        j.fraction = p.fraction;
                    }
                    if !p.message.is_empty() {
                        j.message.clone_from(&p.message);
                    }
                },
                stage_changed,
            );
            if last_sent.elapsed() >= TELEMETRY_INTERVAL || stage_changed {
                last_sent = Instant::now();
                let fraction = p.fraction.unwrap_or(0.0);
                #[allow(clippy::cast_possible_truncation, clippy::cast_sign_loss, clippy::cast_precision_loss)]
                let current = (fraction * total_lba as f64) as u64;
                let sample = TelemetrySample {
                    drive_id: drive.id.clone(),
                    phase: match p.stage {
                        Stage::Preparing => TelemetryPhase::Preheating,
                        Stage::Writing => TelemetryPhase::BurningProgress,
                        Stage::Verifying => TelemetryPhase::VerifyingSectors,
                    },
                    fraction,
                    current_lba: current.min(total_lba),
                    total_lba,
                    effective_speed_x: p.speed_x,
                    fifo_fill: p.fifo,
                    drive_buffer_fill: p.buffer,
                };
                self.emit(&job.owner, &Event::Telemetry { job: job.id.clone(), sample });
            }
        };
        let request =
            BurnRequest { drive, image: &image, image_bytes: job.image_bytes, options: &job.options, cancel: &cancel };
        crate::log(&format!("burn {} on {}: started ({} bytes)", job.id, drive.id, job.image_bytes));
        let outcome = self.backend.burn(&request, &mut on_progress);
        let cancelled = cancel.load(Ordering::SeqCst);
        let (state, fraction, message, phase) = match &outcome {
            Ok(()) => (JobState::Done, Some(1.0), "Done".to_owned(), TelemetryPhase::BurnCompleted),
            Err(_) if cancelled => (JobState::Cancelled, None, "Cancelled".to_owned(), TelemetryPhase::Cancelled),
            Err(e) => (JobState::Failed, None, e.clone(), TelemetryPhase::BurnFailed),
        };
        crate::log(&format!("burn {} on {}: {}", job.id, drive.id, message));
        let sample = TelemetrySample {
            drive_id: drive.id.clone(),
            phase,
            fraction: fraction.unwrap_or(0.0),
            current_lba: if state == JobState::Done { total_lba } else { 0 },
            total_lba,
            effective_speed_x: 0.0,
            fifo_fill: 0.0,
            drive_buffer_fill: 0.0,
        };
        self.emit(&job.owner, &Event::Telemetry { job: job.id.clone(), sample });
        self.update(
            &job.id,
            |j| {
                j.state = state;
                j.fraction = fraction;
                j.message = message;
            },
            true,
        );
        self.lock().cancels.remove(&job.id);
        self.lock().media.remove(&drive.id);
        if state == JobState::Done {
            // The disc is the deliverable; the staged copy can go.
            let _ = std::fs::remove_file(&image);
        }
        self.publish_queue(&drive.id);
    }

    // MARK: Submission and uploads

    /// Validates a submission and opens (or resumes) its staging directory.
    pub fn begin_upload(
        &self,
        owner: &str,
        job_id: &str,
        drive: &str,
        label: &str,
        options: &BurnOptions,
        manifest: &krsp::manifest::TransferManifest,
    ) -> Result<StagedImage, SubmitError> {
        if !self.drives.iter().any(|d| d.id == drive) {
            return Err(SubmitError::UnknownDrive);
        }
        if manifest.sector_size != 2048 {
            return Err(SubmitError::UnsupportedSectorSize(manifest.sector_size));
        }
        let bytes = manifest.image_bytes();
        if bytes > self.config.max_image_bytes {
            return Err(SubmitError::TooLarge);
        }
        {
            let state = self.lock();
            if let Some(existing) = state.jobs.get(job_id) {
                if existing.owner != owner {
                    // Never reveal that someone else's job exists.
                    return Err(SubmitError::UnknownJob);
                }
                if !matches!(existing.state, JobState::Receiving | JobState::Failed | JobState::Cancelled) {
                    return Err(SubmitError::AlreadySubmitted);
                }
            }
        }
        let dir = self.job_dir(job_id);
        let already = StagedImage::open(&dir, manifest).ok().map_or(0, |s| {
            u64::try_from(s.committed().committed_count()).unwrap_or(0).saturating_mul(manifest.extent_bytes())
        });
        let needed = bytes.saturating_sub(already).saturating_add(self.config.min_free_bytes);
        let free = crate::fsutil::free_bytes(&self.config.spool_dir).unwrap_or(0);
        if free < needed {
            return Err(SubmitError::NoSpace { free, needed });
        }
        let staged = StagedImage::open(&dir, manifest).map_err(|e| SubmitError::Io(e.to_string()))?;
        let now = unix_now();
        let job = Job {
            id: job_id.to_owned(),
            owner: owner.to_owned(),
            drive: drive.to_owned(),
            label: label.to_owned(),
            options: options.clone(),
            state: JobState::Receiving,
            fraction: Some(0.0),
            message: "Uploading".into(),
            created: now,
            updated: now,
            image_bytes: bytes,
            seq: self.seq.fetch_add(1, Ordering::SeqCst),
        };
        self.persist(&job);
        self.lock().jobs.insert(job_id.to_owned(), job);
        self.publish_queue(drive);
        Ok(staged)
    }

    /// Reports upload progress (throttled by the caller) to the owner's connections.
    pub fn upload_progress(&self, job_id: &str, committed: usize, total: usize) {
        #[allow(clippy::cast_precision_loss)]
        let f = committed as f64 / total.max(1) as f64;
        self.update(job_id, |j| j.fraction = Some(f), true);
    }

    /// Called once the last extent is durable: seals the image and queues the burn.
    pub fn finish_upload(&self, job_id: &str, staged: &mut StagedImage) -> std::io::Result<()> {
        staged.seal()?;
        let drive = self.lock().jobs.get(job_id).map(|j| j.drive.clone()).unwrap_or_default();
        self.update(
            job_id,
            |j| {
                j.state = JobState::Queued;
                j.fraction = None;
                j.message = "Waiting for the drive".into();
                j.seq = self.seq.fetch_add(1, Ordering::SeqCst);
            },
            true,
        );
        self.wake.notify_all();
        self.publish_queue(&drive);
        Ok(())
    }

    // MARK: Client actions

    #[must_use]
    pub fn job_info(&self, owner: &str, job_id: &str) -> Option<JobInfo> {
        let state = self.lock();
        let job = state.jobs.get(job_id).filter(|j| j.owner == owner)?;
        Some(Self::info(&state, job))
    }

    #[must_use]
    pub fn jobs_of(&self, owner: &str) -> Vec<JobInfo> {
        let state = self.lock();
        let mut jobs: Vec<&Job> = state.jobs.values().filter(|j| j.owner == owner).collect();
        jobs.sort_by_key(|j| j.seq);
        jobs.into_iter().map(|j| Self::info(&state, j)).collect()
    }

    /// Cancels a job of `owner`. Returns false if there is no such job (or it belongs to someone else).
    pub fn cancel(&self, owner: &str, job_id: &str) -> bool {
        let state = self.lock();
        let Some(job) = state.jobs.get(job_id).filter(|j| j.owner == owner) else { return false };
        match job.state {
            JobState::Burning | JobState::Verifying => {
                if let Some(flag) = state.cancels.get(job_id) {
                    flag.store(true, Ordering::SeqCst);
                }
                true
            }
            JobState::Receiving | JobState::Queued => {
                let drive = job.drive.clone();
                drop(state);
                self.update(
                    job_id,
                    |j| {
                        j.state = JobState::Cancelled;
                        j.fraction = None;
                        j.message = "Cancelled".into();
                    },
                    true,
                );
                self.publish_queue(&drive);
                true
            }
            _ => true,
        }
    }

    pub fn eject(&self, drive: &str) -> Result<(), String> {
        let d = self.drives.iter().find(|d| d.id == drive).ok_or("Unknown drive")?;
        let busy = self
            .lock()
            .jobs
            .values()
            .any(|j| j.drive == drive && matches!(j.state, JobState::Burning | JobState::Verifying));
        if busy {
            return Err("The drive is burning".into());
        }
        self.lock().media.remove(drive);
        self.backend.eject(d)
    }

    #[must_use]
    pub fn drive_infos(&self) -> Vec<DriveInfo> {
        self.drives
            .iter()
            .map(|d| {
                let (queue, busy) = {
                    let state = self.lock();
                    let active = |j: &&Job| {
                        j.drive == d.id && matches!(j.state, JobState::Queued | JobState::Burning | JobState::Verifying)
                    };
                    let queue = state.jobs.values().filter(active).count();
                    let busy = state
                        .jobs
                        .values()
                        .any(|j| j.drive == d.id && matches!(j.state, JobState::Burning | JobState::Verifying));
                    (u32::try_from(queue).unwrap_or(u32::MAX), busy)
                };
                DriveInfo { id: d.id.clone(), name: d.name.clone(), media: self.media(d, busy), queue, busy }
            })
            .collect()
    }

    fn media(&self, drive: &Drive, busy: bool) -> MediaState {
        if busy {
            return MediaState::Blank;
        }
        if let Some((m, at)) = self.lock().media.get(&drive.id)
            && at.elapsed() < MEDIA_CACHE
        {
            return *m;
        }
        let m = self.backend.media(drive);
        self.lock().media.insert(drive.id.clone(), (m, Instant::now()));
        m
    }

    // MARK: Subscriptions

    /// Registers a connection for `owner`'s events. Drop the receiver to unsubscribe.
    pub fn subscribe(&self, owner: &str) -> (u64, Receiver<Event>) {
        let (tx, rx) = channel();
        let id = self.next_subscriber.fetch_add(1, Ordering::SeqCst);
        self.lock().subscribers.push((id, owner.to_owned(), tx));
        (id, rx)
    }

    pub fn unsubscribe(&self, id: u64) {
        self.lock().subscribers.retain(|(s, _, _)| *s != id);
    }

    fn emit(&self, owner: &str, event: &Event) {
        self.lock().subscribers.retain(|(_, who, tx)| who != owner || tx.send(event.clone()).is_ok());
    }

    // MARK: Internals

    fn info(state: &State, job: &Job) -> JobInfo {
        let ahead = state
            .jobs
            .values()
            .filter(|o| o.drive == job.drive && o.id != job.id)
            .filter(|o| match o.state {
                JobState::Burning | JobState::Verifying => {
                    !matches!(job.state, JobState::Burning | JobState::Verifying)
                }
                JobState::Queued => {
                    job.state == JobState::Receiving || (job.state == JobState::Queued && o.seq < job.seq)
                }
                _ => false,
            })
            .count();
        JobInfo {
            job: job.id.clone(),
            drive: job.drive.clone(),
            label: job.label.clone(),
            state: job.state,
            fraction: job.fraction,
            queue_ahead: if job.state.is_terminal() { 0 } else { u32::try_from(ahead).unwrap_or(u32::MAX) },
            message: job.message.clone(),
        }
    }

    fn update(&self, job_id: &str, change: impl FnOnce(&mut Job), persist: bool) {
        let (snapshot, info) = {
            let mut state = self.lock();
            let Some(job) = state.jobs.get_mut(job_id) else { return };
            change(job);
            job.updated = unix_now();
            let snapshot = job.clone();
            let info = Self::info(&state, &snapshot);
            (snapshot, info)
        };
        if persist {
            self.persist(&snapshot);
        }
        self.emit(&snapshot.owner, &Event::Job(info));
    }

    /// Re-sends job info to every owner with a job on `drive`, since their queue positions moved.
    fn publish_queue(&self, drive: &str) {
        let infos: Vec<(String, JobInfo)> = {
            let state = self.lock();
            state
                .jobs
                .values()
                .filter(|j| j.drive == drive && matches!(j.state, JobState::Receiving | JobState::Queued))
                .map(|j| (j.owner.clone(), Self::info(&state, j)))
                .collect()
        };
        for (owner, info) in infos {
            self.emit(&owner, &Event::Job(info));
        }
    }

    fn persist(&self, job: &Job) {
        let value = Value::object([
            ("id", job.id.as_str().into()),
            ("owner", job.owner.as_str().into()),
            ("drive", job.drive.as_str().into()),
            ("label", job.label.as_str().into()),
            ("speed", job.options.speed.into()),
            ("verify", job.options.verify.into()),
            ("simulate", job.options.simulate.into()),
            ("eject", job.options.eject.into()),
            ("state", job.state.wire_name().into()),
            ("message", job.message.as_str().into()),
            ("created", job.created.into()),
            ("updated", job.updated.into()),
            ("imageBytes", job.image_bytes.into()),
            ("seq", job.seq.into()),
        ]);
        let dir = self.job_dir(&job.id);
        if dir.exists() {
            let _ = crate::store::write_atomically(&dir.join(JOB_FILE), value.to_json().as_bytes());
        }
    }

    fn reload(&self) {
        let Ok(entries) = std::fs::read_dir(&self.config.spool_dir) else { return };
        let mut max_seq = 0;
        let mut state = self.lock();
        for entry in entries.flatten() {
            let Some(job) = std::fs::read(entry.path().join(JOB_FILE))
                .ok()
                .and_then(|b| json::parse(&b).ok())
                .and_then(|v| parse_job(&v))
            else {
                continue;
            };
            max_seq = max_seq.max(job.seq);
            let mut job = job;
            if matches!(job.state, JobState::Burning | JobState::Verifying) {
                job.state = JobState::Failed;
                job.fraction = None;
                job.message = "The server restarted during this burn; check the disc".into();
            }
            if job.state == JobState::Queued && !entry.path().join(IMAGE_FILE).exists() {
                job.state = JobState::Failed;
                job.message = "The staged image is missing".into();
            }
            state.jobs.insert(job.id.clone(), job);
        }
        self.seq.store(max_seq + 1, Ordering::SeqCst);
        let changed: Vec<Job> = state.jobs.values().filter(|j| j.state == JobState::Failed).cloned().collect();
        drop(state);
        for job in changed {
            self.persist(&job);
        }
    }

    /// Deletes finished jobs' directories after a day, and incomplete or failed uploads after
    /// `keep_incomplete_hours`.
    pub fn prune(&self) {
        let now = unix_now();
        let keep = self.config.keep_incomplete_hours.saturating_mul(3600);
        let doomed: Vec<String> = self
            .lock()
            .jobs
            .values()
            .filter(|j| match j.state {
                JobState::Done => now.saturating_sub(j.updated) > 24 * 3600,
                JobState::Failed | JobState::Cancelled | JobState::Receiving => now.saturating_sub(j.updated) > keep,
                _ => false,
            })
            .map(|j| j.id.clone())
            .collect();
        for id in doomed {
            let _ = std::fs::remove_dir_all(self.job_dir(&id));
            self.lock().jobs.remove(&id);
        }
    }
}

fn parse_job(v: &Value) -> Option<Job> {
    let s = |k: &str| v.get(k).and_then(Value::as_str).map(str::to_owned);
    let n = |k: &str| v.get(k).and_then(Value::as_u64);
    let b = |k: &str| v.get(k).and_then(Value::as_bool);
    let id = s("id")?;
    if !krsp::control::is_safe_identifier(&id) {
        return None;
    }
    Some(Job {
        id,
        owner: s("owner")?,
        drive: s("drive")?,
        label: s("label")?,
        options: BurnOptions {
            speed: u32::try_from(n("speed")?).ok()?,
            verify: b("verify")?,
            simulate: b("simulate")?,
            eject: b("eject")?,
        },
        state: JobState::from_wire(&s("state")?)?,
        fraction: None,
        message: s("message")?,
        created: n("created")?,
        updated: n("updated")?,
        image_bytes: n("imageBytes")?,
        seq: n("seq")?,
    })
}
