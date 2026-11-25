// MARK: - jobs/mastering.rs

//! The mastering worker: one thread that turns uploaded folders (`files` jobs) into disc images,
//! one job at a time, then hands them to their drive's queue.
//!
//! `image.iso` (the uploaded bundle) → `tree/` (unpacked, `extract.rs`) → `mastering.iso`
//! (built by the backend's tool) → renamed to `disc.iso` once complete. The bundle is kept until
//! the job is done, so a retry after a failed burn neither uploads nor masters again; `tree/` is
//! deleted as soon as the image exists.

use super::{IMAGE_FILE, Job, JobManager, MASTER_TEMP, MASTERED_FILE, TREE_DIR};
use crate::backend::MasterRequest;
use crate::extract::extract_bundle;
use krsp::control::JobState;
use std::path::Path;
use std::sync::Arc;
use std::sync::atomic::{AtomicBool, Ordering};
use std::time::{Duration, Instant};

/// Share of the mastering progress bar spent unpacking.
const UNPACK_SHARE: f64 = 0.3;
const UPDATE_INTERVAL: Duration = Duration::from_millis(500);

impl JobManager {
    pub(super) fn mastering_loop(&self) {
        while let Some(job) = self.next_mastering_job() {
            self.master_job(&job);
        }
    }

    fn next_mastering_job(&self) -> Option<Job> {
        let mut state = self.lock();
        loop {
            if state.shutting_down {
                return None;
            }
            let next = state
                .jobs
                .values()
                .filter(|j| j.state == JobState::Mastering && !state.cancels.contains_key(&j.id))
                .min_by_key(|j| j.seq)
                .map(|j| j.id.clone());
            if let Some(id) = next {
                // The cancel flag doubles as "the worker has this job" (see `cancel`).
                state.cancels.insert(id.clone(), Arc::new(AtomicBool::new(false)));
                return state.jobs.get(&id).cloned();
            }
            state = self.wake.wait(state).unwrap_or_else(std::sync::PoisonError::into_inner);
        }
    }

    fn master_job(&self, job: &Job) {
        let dir = self.job_dir(&job.id);
        let cancel = self.lock().cancels.get(&job.id).cloned().unwrap_or_default();
        let disc = dir.join(MASTERED_FILE);
        crate::log(&format!("master {}: started", job.id));
        let outcome = if disc.exists() { Ok(Vec::new()) } else { self.build(job, &dir, &cancel) };
        let _ = std::fs::remove_dir_all(dir.join(TREE_DIR));
        let _ = std::fs::remove_file(dir.join(MASTER_TEMP));
        self.lock().cancels.remove(&job.id);
        if !self.lock().jobs.get(&job.id).is_some_and(|j| j.state == JobState::Mastering) {
            return; // cancelled before the worker saw the flag
        }
        match outcome {
            Ok(systems) => {
                let bytes = std::fs::metadata(&disc).map_or(0, |m| m.len());
                let built = if systems.is_empty() { String::new() } else { format!(" ({})", describe(&systems)) };
                crate::log(&format!("master {}: built {bytes} bytes{built}", job.id));
                self.update(
                    &job.id,
                    |j| {
                        j.state = JobState::Queued;
                        j.fraction = None;
                        j.image_bytes = bytes;
                        j.message = format!("Disc built{built}; waiting for the drive");
                        j.seq = self.seq.fetch_add(1, Ordering::SeqCst);
                    },
                    true,
                );
                self.wake.notify_all();
            }
            Err(message) => {
                let cancelled = cancel.load(Ordering::SeqCst);
                crate::log(&format!("master {}: {message}", job.id));
                self.update(
                    &job.id,
                    |j| {
                        j.state = if cancelled { JobState::Cancelled } else { JobState::Failed };
                        j.fraction = None;
                        j.message = if cancelled { "Cancelled".into() } else { message };
                    },
                    true,
                );
            }
        }
        self.publish_queue(&job.drive);
    }

    fn build(&self, job: &Job, dir: &Path, cancel: &AtomicBool) -> Result<Vec<&'static str>, String> {
        let tree = dir.join(TREE_DIR);
        let mut last = Instant::now().checked_sub(UPDATE_INTERVAL).unwrap_or_else(Instant::now);
        let extracted = extract_bundle(&dir.join(IMAGE_FILE), &tree, cancel, &mut |fraction, so_far| {
            if last.elapsed() >= UPDATE_INTERVAL {
                last = Instant::now();
                let message = format!("Unpacking: {} files", so_far.files);
                self.update(&job.id, |j| (j.fraction, j.message) = (Some(fraction * UNPACK_SHARE), message), false);
            }
        })?;
        self.update(
            &job.id,
            |j| {
                (j.fraction, j.message) =
                    (Some(UNPACK_SHARE), format!("Building the disc from {} files", extracted.files))
            },
            true,
        );
        let temp = dir.join(MASTER_TEMP);
        let request = MasterRequest {
            tree: &tree,
            output: &temp,
            label: &job.label,
            largest_file: extracted.largest_file,
            cancel,
        };
        let systems = self.backend.master(&request, &mut |p| {
            if last.elapsed() >= UPDATE_INTERVAL {
                last = Instant::now();
                self.update(&job.id, |j| j.fraction = p.map(|p| UNPACK_SHARE + (1.0 - UNPACK_SHARE) * p), false);
            }
        })?;
        std::fs::rename(&temp, dir.join(MASTERED_FILE)).map_err(|e| format!("Could not keep the built image: {e}"))?;
        Ok(systems)
    }
}

/// `ISO 9660 + Joliet + UDF`.
fn describe(systems: &[&str]) -> String {
    systems
        .iter()
        .map(|s| match *s {
            "iso9660" => "ISO 9660",
            "joliet" => "Joliet",
            "rockridge" => "Rock Ridge",
            "udf" => "UDF",
            other => other,
        })
        .collect::<Vec<_>>()
        .join(" + ")
}
