// MARK: - lease.rs

//! Fenced drive leases. Nothing in the server uses this module yet (the Swift `DriveLeaseTable`
//! it mirrored has been removed from the app). The node a drive is plugged into is its only
//! authority, so no consensus protocol is needed: a compare-and-set table plus fencing tokens.
//! Time is passed in as a `Duration` on the node's monotonic clock, which keeps this pure.

use std::collections::HashMap;
use std::fmt;
use std::time::Duration;

#[derive(Clone, Debug, PartialEq, Eq, Hash, PartialOrd, Ord)]
pub struct DriveId(pub String);

#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum LeasePhase {
    Reserved,
    /// Laser is on: the node holds the image and finishes the disc on its own. Never expires.
    Burning,
}

#[derive(Clone, Debug, PartialEq, Eq)]
pub struct DriveLease {
    pub drive: DriveId,
    pub holder: String,
    pub set_id: [u8; 16],
    pub fencing_token: u64,
    pub expires_at: Duration,
    pub phase: LeasePhase,
}

#[derive(Clone, Debug, PartialEq, Eq)]
pub enum LeaseRejection {
    UnknownDrive,
    HeldByOther { holder: String },
    StaleToken,
    NotReserved,
}

impl fmt::Display for LeaseRejection {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        match self {
            Self::UnknownDrive => write!(f, "no such drive on this node"),
            Self::HeldByOther { holder } => write!(f, "drive is leased to {holder}"),
            Self::StaleToken => write!(f, "fencing token is no longer current"),
            Self::NotReserved => write!(f, "drive has no active lease"),
        }
    }
}

impl std::error::Error for LeaseRejection {}

#[derive(Clone, Debug)]
pub struct DriveLeaseTable {
    ttl: Duration,
    leases: HashMap<DriveId, DriveLease>,
    last_token: HashMap<DriveId, u64>,
}

impl DriveLeaseTable {
    /// `boot_epoch` is persisted and incremented on every daemon start, so a token issued after a
    /// restart can never equal one a stale workstation still holds.
    #[must_use]
    pub fn new(drives: impl IntoIterator<Item = DriveId>, ttl: Duration, boot_epoch: u32) -> Self {
        let seed = u64::from(boot_epoch) << 32;
        let mut last_token = HashMap::new();
        for drive in drives {
            last_token.entry(drive).or_insert(seed);
        }
        Self { ttl, leases: HashMap::new(), last_token }
    }

    #[must_use]
    pub fn lease(&self, drive: &DriveId) -> Option<&DriveLease> {
        self.leases.get(drive)
    }

    pub fn expire(&mut self, now: Duration) {
        self.leases.retain(|_, lease| lease.phase == LeasePhase::Burning || lease.expires_at > now);
    }

    pub fn reserve(
        &mut self,
        drive: &DriveId,
        holder: &str,
        set_id: [u8; 16],
        now: Duration,
    ) -> Result<DriveLease, LeaseRejection> {
        let last = *self.last_token.get(drive).ok_or(LeaseRejection::UnknownDrive)?;
        self.expire(now);
        if let Some(existing) = self.leases.get_mut(drive) {
            // A retried reserve (its reply was lost) renews the same lease instead of failing.
            if existing.holder != holder || existing.set_id != set_id {
                return Err(LeaseRejection::HeldByOther { holder: existing.holder.clone() });
            }
            if existing.phase == LeasePhase::Reserved {
                existing.expires_at = now + self.ttl;
            }
            return Ok(existing.clone());
        }
        let lease = DriveLease {
            drive: drive.clone(),
            holder: holder.to_owned(),
            set_id,
            fencing_token: last + 1,
            expires_at: now + self.ttl,
            phase: LeasePhase::Reserved,
        };
        self.last_token.insert(drive.clone(), last + 1);
        self.leases.insert(drive.clone(), lease.clone());
        Ok(lease)
    }

    pub fn heartbeat(&mut self, drive: &DriveId, token: u64, now: Duration) -> Result<DriveLease, LeaseRejection> {
        let ttl = self.ttl;
        let lease = self.current_mut(drive, token, now)?;
        if lease.phase == LeasePhase::Reserved {
            lease.expires_at = now + ttl;
        }
        Ok(lease.clone())
    }

    /// Laser-on. Idempotent for the current token.
    pub fn commit(&mut self, drive: &DriveId, token: u64, now: Duration) -> Result<DriveLease, LeaseRejection> {
        let lease = self.current_mut(drive, token, now)?;
        lease.phase = LeasePhase::Burning;
        Ok(lease.clone())
    }

    /// The disc finished or failed on the node. Ignores a token that is not current.
    pub fn finish(&mut self, drive: &DriveId, token: u64) {
        if self.leases.get(drive).is_some_and(|l| l.fencing_token == token) {
            self.leases.remove(drive);
        }
    }

    /// The workstation gives a reserved drive back. A burning drive cannot be released this way.
    pub fn release(&mut self, drive: &DriveId, token: u64, now: Duration) -> Result<(), LeaseRejection> {
        if self.current_mut(drive, token, now)?.phase == LeasePhase::Reserved {
            self.leases.remove(drive);
        }
        Ok(())
    }

    fn current_mut(&mut self, drive: &DriveId, token: u64, now: Duration) -> Result<&mut DriveLease, LeaseRejection> {
        if !self.last_token.contains_key(drive) {
            return Err(LeaseRejection::UnknownDrive);
        }
        self.expire(now);
        let lease = self.leases.get_mut(drive).ok_or(LeaseRejection::NotReserved)?;
        if lease.fencing_token != token {
            return Err(LeaseRejection::StaleToken);
        }
        Ok(lease)
    }
}
