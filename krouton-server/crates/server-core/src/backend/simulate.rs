//! A drive-less backend: every step of a real job (upload, queue, write, verify, eject) with
//! realistic timing and telemetry, so a server can be tested end to end before a burner is plugged in.

use super::{Backend, BurnRequest, Drive, Progress, Stage};
use crate::config::BackendKind;
use krsp::control::MediaState;
use std::sync::atomic::Ordering;
use std::time::{Duration, Instant};

#[derive(Debug)]
pub struct SimulatedBackend {
    drives: u32,
    seconds: u64,
}

impl SimulatedBackend {
    #[must_use]
    pub fn new(drives: u32, seconds: u64) -> Self {
        Self { drives: drives.max(1), seconds: seconds.max(1) }
    }
}

impl Backend for SimulatedBackend {
    fn kind(&self) -> BackendKind {
        BackendKind::Simulate
    }

    fn discover(&self) -> Vec<Drive> {
        (1..=self.drives)
            .map(|n| Drive {
                id: format!("sim-{n}"),
                name: format!("Simulated BD-RE Drive {n}"),
                device: format!("sim{n}"),
            })
            .collect()
    }

    fn media(&self, _drive: &Drive) -> MediaState {
        MediaState::Blank
    }

    /// A simulated drive writes every family and holds any image.
    fn probe(&self, drive: &Drive) -> super::DriveProbe {
        super::DriveProbe {
            writes: Some(krsp::identity::caps::WRITES_ANY),
            ..super::DriveProbe::media_only(self.media(drive))
        }
    }

    fn burn(&self, request: &BurnRequest<'_>, progress: &mut dyn FnMut(Progress)) -> Result<(), String> {
        // The image must really be there and complete, exactly as a real burn would need.
        let len = std::fs::metadata(request.image).map_err(|e| format!("Image missing: {e}"))?.len();
        if len != request.image_bytes {
            return Err(format!("Image is {len} bytes, expected {}", request.image_bytes));
        }
        let total = Duration::from_secs(self.seconds);
        let write_share = if request.options.verify { 0.8 } else { 1.0 };
        let speed = if request.options.speed == 0 { 8.0 } else { f64::from(request.options.speed) };
        let started = Instant::now();
        progress(Progress::new(Stage::Preparing, Some(0.0), "Spinning up"));
        loop {
            if request.cancel.load(Ordering::SeqCst) {
                return Err("Cancelled".into());
            }
            let f = (started.elapsed().as_secs_f64() / total.as_secs_f64()).min(1.0);
            let (stage, message) =
                if f < write_share { (Stage::Writing, "Writing") } else { (Stage::Verifying, "Verifying") };
            let mut p = Progress::new(stage, Some(f), message);
            p.speed_x = if stage == Stage::Writing { speed } else { 0.0 };
            p.fifo = 1.0;
            p.buffer = 0.95;
            progress(p);
            if f >= 1.0 {
                return Ok(());
            }
            std::thread::sleep(Duration::from_millis(250));
        }
    }

    fn eject(&self, _drive: &Drive) -> Result<(), String> {
        Ok(())
    }

    fn file_systems(&self) -> Vec<&'static str> {
        vec![super::master::ISO9660, super::master::JOLIET, super::master::UDF]
    }

    fn master(
        &self,
        request: &super::MasterRequest<'_>,
        progress: &mut dyn FnMut(Option<f64>),
    ) -> Result<Vec<&'static str>, String> {
        super::master::simulate_master(request, progress)
    }

    fn diagnose(&self) -> Vec<String> {
        Vec::new()
    }
}
