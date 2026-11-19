// MARK: - cutover.rs

//! Store-and-forward vs rolling-window cutover (`SpoolCutoverPolicy.swift`). Pure arithmetic.

#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum MediaClass {
    CdAudio,
    CdData,
    DvdSingleLayer,
    DvdDualLayer,
    BdSingleLayer,
    BdDualLayer,
}

impl MediaClass {
    /// Bytes per second the drive consumes from the image file at 1x.
    #[must_use]
    pub fn bytes_per_second_at_1x(self) -> f64 {
        match self {
            Self::CdAudio => 176_400.0,
            Self::CdData => 153_600.0,
            Self::DvdSingleLayer | Self::DvdDualLayer => 1_385_000.0,
            Self::BdSingleLayer | Self::BdDualLayer => 4_495_500.0,
        }
    }

    fn always_prestages(self) -> bool {
        self == Self::CdAudio
    }

    fn stall_multiplier(self) -> f64 {
        if matches!(self, Self::DvdDualLayer | Self::BdDualLayer) { 2.0 } else { 1.0 }
    }
}

#[derive(Clone, Copy, Debug, PartialEq)]
pub struct LinkStats {
    pub mean_bytes_per_second: f64,
    pub standard_deviation: f64,
    pub sample_count: usize,
    pub is_wifi: bool,
}

impl LinkStats {
    /// From per-extent throughput samples (bytes/s). Non-finite and negative samples are dropped.
    #[must_use]
    pub fn from_samples(samples: &[f64], is_wifi: bool) -> Self {
        let finite: Vec<f64> = samples.iter().copied().filter(|s| s.is_finite() && *s >= 0.0).collect();
        let n = finite.len() as f64;
        let mean = if finite.is_empty() { 0.0 } else { finite.iter().sum::<f64>() / n };
        let variance = if finite.len() < 2 {
            0.0
        } else {
            finite.iter().map(|s| (s - mean) * (s - mean)).sum::<f64>() / (n - 1.0)
        };
        Self { mean_bytes_per_second: mean, standard_deviation: variance.sqrt(), sample_count: finite.len(), is_wifi }
    }
}

#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum StoreAndForwardReason {
    MediaPolicy,
    QuickToPrestage,
    UnmeasuredLink,
    RollingGainTooSmall,
}

#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum CutoverDecision {
    StoreAndForward(StoreAndForwardReason),
    /// Laser-on once `lead_bytes` are committed; the rest streams in during the burn.
    RollingWindow {
        lead_bytes: u64,
    },
    /// The node cannot hold the whole image. Krouton never streams straight to a laser.
    Refuse {
        needed_bytes: u64,
        free_bytes: u64,
    },
}

pub const CONFIDENCE_Z: f64 = 2.33;
pub const QUICK_PRESTAGE_SECONDS: f64 = 60.0;
pub const MINIMUM_SAMPLES: usize = 8;
pub const ROLLING_CEILING_FRACTION: f64 = 0.8;
pub const RESERVE_BYTES: u64 = 2 * 1_073_741_824;

#[must_use]
pub fn stall_budget_seconds(is_wifi: bool) -> f64 {
    if is_wifi { 15.0 } else { 3.0 }
}

/// `B = min(S, max(R·τ, S·max(0, 1 − L/R) + min(L, R)·τ) + E)`
#[must_use]
pub fn required_lead_bytes(image: f64, burn_rate: f64, safe_link: f64, stall_seconds: f64, extent: f64) -> f64 {
    let outage_at_start = burn_rate * stall_seconds;
    let deficit = image * (1.0 - safe_link / burn_rate).max(0.0) + safe_link.min(burn_rate) * stall_seconds;
    image.min(outage_at_start.max(deficit) + extent)
}

#[must_use]
pub fn decide(
    image_bytes: u64,
    media: MediaClass,
    speed_x: f64,
    link: &LinkStats,
    free_bytes: u64,
    extent_bytes: u64,
) -> CutoverDecision {
    let needed = image_bytes.saturating_add(RESERVE_BYTES);
    if free_bytes < needed {
        return CutoverDecision::Refuse { needed_bytes: needed, free_bytes };
    }
    if media.always_prestages() {
        return CutoverDecision::StoreAndForward(StoreAndForwardReason::MediaPolicy);
    }
    if link.sample_count < MINIMUM_SAMPLES
        || link.mean_bytes_per_second <= 0.0
        || !link.mean_bytes_per_second.is_finite()
    {
        return CutoverDecision::StoreAndForward(StoreAndForwardReason::UnmeasuredLink);
    }
    let size = image_bytes as f64;
    if size / link.mean_bytes_per_second <= QUICK_PRESTAGE_SECONDS {
        return CutoverDecision::StoreAndForward(StoreAndForwardReason::QuickToPrestage);
    }
    let burn_rate = media.bytes_per_second_at_1x() * speed_x.max(1.0);
    let safe_link = (link.mean_bytes_per_second - CONFIDENCE_Z * link.standard_deviation).max(0.0);
    let stall = stall_budget_seconds(link.is_wifi) * media.stall_multiplier();
    let lead = required_lead_bytes(size, burn_rate, safe_link, stall, extent_bytes as f64);
    if lead >= ROLLING_CEILING_FRACTION * size {
        return CutoverDecision::StoreAndForward(StoreAndForwardReason::RollingGainTooSmall);
    }
    // `lead` is finite, non-negative and ≤ image_bytes here, so the conversion is exact enough.
    #[allow(clippy::cast_possible_truncation, clippy::cast_sign_loss)]
    let lead_bytes = lead.ceil() as u64;
    CutoverDecision::RollingWindow { lead_bytes }
}
