// MARK: - backend/probe.rs

//! What a drive can write and what is in its tray, as far as the platform's tools say. The
//! server sends it with each drive (`DriveInfo`) and checks it before a burn, so an image that
//! cannot go on a drive is refused before the laser starts instead of failing in the tool.

use krsp::control::MediaState;
use krsp::identity::caps;

#[derive(Clone, Debug, Default, PartialEq, Eq)]
pub struct DriveProbe {
    pub media: MediaState,
    /// `caps::WRITES_*` bits; `None` when the tools do not say.
    pub writes: Option<u32>,
    /// The disc in the tray, such as `DVD+R`.
    pub disc: Option<String>,
    pub free_bytes: Option<u64>,
}

impl DriveProbe {
    /// A probe that knows only the media state.
    #[must_use]
    pub fn media_only(media: MediaState) -> Self {
        Self { media, ..Self::default() }
    }

    /// Why an image of `image_bytes` cannot be burned on this drive now, or `None` when nothing
    /// known stands in the way. Unknown facts never refuse a burn.
    #[must_use]
    pub fn refusal(&self, image_bytes: u64) -> Option<String> {
        let holding = caps::families_holding(image_bytes);
        if let Some(writes) = self.writes
            && writes != 0
            && writes & holding == 0
        {
            return Some(format!(
                "This drive writes {}, and a {} image needs {}. Nothing was written.",
                caps::describe(writes),
                human_bytes(image_bytes),
                caps::describe(holding & caps::WRITES_ANY).replace(" and ", " or "),
            ));
        }
        if matches!(self.media, MediaState::Blank | MediaState::Appendable)
            && let Some(free) = self.free_bytes
            && free > 0
            && image_bytes > free
        {
            let disc = self.disc.as_deref().unwrap_or("disc");
            return Some(format!(
                "The {disc} in the drive holds {}, and the image is {}. Insert a larger disc. Nothing was written.",
                human_bytes(free),
                human_bytes(image_bytes)
            ));
        }
        None
    }
}

/// The disc families a drive writes, from the MMC profiles it reports (xorriso
/// `-list_profiles`, IMAPI2 `SupportedProfiles`). Read-only profiles (CD-ROM, DVD-ROM, BD-ROM)
/// count for nothing.
#[must_use]
pub fn writes_from_profiles(profiles: &[u16]) -> u32 {
    profiles.iter().fold(0, |writes, profile| {
        writes
            | match profile {
                0x09 | 0x0A => caps::WRITES_CD,
                0x11..=0x16 | 0x1A | 0x1B | 0x2A | 0x2B => caps::WRITES_DVD,
                0x41..=0x43 => caps::WRITES_BD,
                _ => 0,
            }
    })
}

/// The name of an MMC profile, for the disc in the tray.
#[must_use]
pub fn profile_name(profile: u16) -> Option<&'static str> {
    Some(match profile {
        0x08 => "CD-ROM",
        0x09 => "CD-R",
        0x0A => "CD-RW",
        0x10 => "DVD-ROM",
        0x11 | 0x15 | 0x16 => "DVD-R",
        0x12 => "DVD-RAM",
        0x13 | 0x14 => "DVD-RW",
        0x1A => "DVD+RW",
        0x1B => "DVD+R",
        0x2A => "DVD+RW DL",
        0x2B => "DVD+R DL",
        0x40 => "BD-ROM",
        0x41 | 0x42 => "BD-R",
        0x43 => "BD-RE",
        _ => return None,
    })
}

#[must_use]
pub fn human_bytes(bytes: u64) -> String {
    #[allow(clippy::cast_precision_loss)]
    let gb = bytes as f64 / 1_000_000_000.0;
    if gb >= 1.0 { format!("{gb:.1} GB") } else { format!("{:.0} MB", gb * 1000.0) }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn profiles_become_families() {
        assert_eq!(writes_from_profiles(&[0x08, 0x09, 0x0A]), caps::WRITES_CD);
        assert_eq!(writes_from_profiles(&[0x09, 0x1B, 0x2B, 0x10]), caps::WRITES_CD | caps::WRITES_DVD);
        assert_eq!(writes_from_profiles(&[0x40, 0x41, 0x43]), caps::WRITES_BD);
        assert_eq!(writes_from_profiles(&[0x08, 0x10, 0x40]), 0);
    }

    #[test]
    fn a_bluray_image_is_refused_on_a_dvd_burner() {
        let dvd = DriveProbe { writes: Some(caps::WRITES_CD | caps::WRITES_DVD), ..DriveProbe::default() };
        let reason = dvd.refusal(25_000_000_000);
        assert!(reason.as_deref().is_some_and(|r| r.contains("writes CD and DVD") && r.contains("Blu-ray")));
        assert_eq!(dvd.refusal(4_000_000_000), None);
    }

    #[test]
    fn a_dvd_image_is_refused_on_a_cd_burner() {
        let cd = DriveProbe { writes: Some(caps::WRITES_CD), ..DriveProbe::default() };
        assert!(cd.refusal(4_000_000_000).is_some());
        assert_eq!(cd.refusal(650_000_000), None);
    }

    #[test]
    fn a_disc_that_is_too_small_is_refused() {
        let probe = DriveProbe {
            media: MediaState::Blank,
            writes: Some(caps::WRITES_ANY),
            disc: Some("CD-R".into()),
            free_bytes: Some(737_280_000),
        };
        assert!(probe.refusal(800_000_000).is_some_and(|r| r.contains("CD-R in the drive holds")));
        assert_eq!(probe.refusal(700_000_000), None);
    }

    #[test]
    fn unknown_facts_never_refuse() {
        assert_eq!(DriveProbe::default().refusal(100_000_000_000), None);
        let no_disc = DriveProbe { media: MediaState::NoDisc, free_bytes: Some(1), ..DriveProbe::default() };
        assert_eq!(no_disc.refusal(4_000_000_000), None);
    }
}
