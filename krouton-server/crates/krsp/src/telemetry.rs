//! Burn progress samples, sent in `Telemetry` (kind 7) frames (see [`crate::control::telemetry_frame`]).
//!
//! [`TelemetryConflator`] keeps the newest sample per drive between sends and never lets a late
//! progress sample overwrite a terminal state. Nothing in the server uses it yet.

use std::collections::HashMap;

#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum TelemetryPhase {
    Idle,
    Preheating,
    BurningProgress,
    VerifyingSectors,
    BurnCompleted,
    BurnFailed,
    Cancelled,
}

impl TelemetryPhase {
    /// The exact strings the Swift `SpoolTelemetryPhase` enum encodes.
    #[must_use]
    pub fn wire_name(self) -> &'static str {
        match self {
            Self::Idle => "IDLE",
            Self::Preheating => "PREHEATING",
            Self::BurningProgress => "BURNING_PROGRESS",
            Self::VerifyingSectors => "VERIFYING_SECTORS",
            Self::BurnCompleted => "BURN_COMPLETED",
            Self::BurnFailed => "BURN_FAILED",
            Self::Cancelled => "CANCELLED",
        }
    }

    #[must_use]
    pub fn is_terminal(self) -> bool {
        matches!(self, Self::BurnCompleted | Self::BurnFailed | Self::Cancelled)
    }
}

#[derive(Clone, Debug, PartialEq)]
pub struct TelemetrySample {
    pub drive_id: String,
    pub phase: TelemetryPhase,
    pub fraction: f64,
    pub current_lba: u64,
    pub total_lba: u64,
    pub effective_speed_x: f64,
    pub fifo_fill: f64,
    pub drive_buffer_fill: f64,
}

#[derive(Debug, Default)]
pub struct TelemetryConflator {
    latest: HashMap<String, TelemetrySample>,
    order: Vec<String>,
}

impl TelemetryConflator {
    #[must_use]
    pub fn new() -> Self {
        Self::default()
    }

    pub fn offer(&mut self, sample: TelemetrySample) {
        match self.latest.get(&sample.drive_id) {
            Some(existing) if existing.phase.is_terminal() && !sample.phase.is_terminal() => return,
            Some(_) => {}
            None => self.order.push(sample.drive_id.clone()),
        }
        self.latest.insert(sample.drive_id.clone(), sample);
    }

    /// One sample per drive, in first-seen order; empties the conflator (memory returns to zero).
    pub fn drain(&mut self) -> Vec<TelemetrySample> {
        let order = std::mem::take(&mut self.order);
        let pending = order.iter().filter_map(|id| self.latest.remove(id)).collect();
        self.latest = HashMap::new();
        pending
    }
}
