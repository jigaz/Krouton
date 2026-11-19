#![forbid(unsafe_code)]

// MARK: - Cross-Platform Optical Drive HAL, Virtual Drive Simulator & USB Bus Power Arbiter

use std::collections::BTreeMap;
use spoold_mmc::{ScsiCdb, ScsiSense};

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct DriveDescriptor {
    pub id: String,
    pub vendor_model: String,
    pub usb_bus_id: String,
    pub max_current_ma: u16,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum HalError {
    DeviceBusy,
    OutOfBoundsLba,
    BufferLengthMismatch,
    TrayLocked,
    IoFailure,
}

pub trait OpticalDrive {
    fn descriptor(&self) -> &DriveDescriptor;
    fn execute(&mut self, cdb: &ScsiCdb, buffer: &mut [u8]) -> Result<ScsiSense, HalError>;
    fn reclaim_unused_resources(&mut self);
}

// MARK: - Deterministic In-Memory Virtual MMC-6 Optical Drive

#[derive(Debug)]
pub struct VirtualMmcOpticalDrive {
    desc: DriveDescriptor,
    sector_size: usize,
    total_sectors: u32,
    storage: Vec<u8>,
    bad_sectors: Vec<u32>,
    tray_locked: bool,
    cache_synchronized: bool,
    session_closed: bool,
}

impl VirtualMmcOpticalDrive {
    pub fn new(id: &str, bus_id: &str, sector_size: usize, total_sectors: u32) -> Self {
        Self {
            desc: DriveDescriptor {
                id: id.to_owned(),
                vendor_model: "KROUTON VIRTUAL BD-RE".to_owned(),
                usb_bus_id: bus_id.to_owned(),
                max_current_ma: 1500,
            },
            sector_size,
            total_sectors,
            storage: Vec::new(),
            bad_sectors: Vec::new(),
            tray_locked: false,
            cache_synchronized: false,
            session_closed: false,
        }
    }

    pub fn inject_c2_bad_sector(&mut self, lba: u32) {
        self.bad_sectors.push(lba);
    }

    pub fn is_session_closed(&self) -> bool {
        self.session_closed
    }

    pub fn storage_capacity(&self) -> usize {
        self.storage.capacity()
    }
}

impl OpticalDrive for VirtualMmcOpticalDrive {
    fn descriptor(&self) -> &DriveDescriptor {
        &self.desc
    }

    fn execute(&mut self, cdb: &ScsiCdb, buffer: &mut [u8]) -> Result<ScsiSense, HalError> {
        let opcode = cdb.bytes[0];
        match opcode {
            0x00 => Ok(ScsiSense::OK),
            0x1E => {
                self.tray_locked = (cdb.bytes[4] & 0x01) != 0;
                Ok(ScsiSense::OK)
            }
            0x1B => {
                let load_eject = (cdb.bytes[4] & 0x02) != 0;
                if load_eject && self.tray_locked {
                    return Err(HalError::TrayLocked);
                }
                Ok(ScsiSense::OK)
            }
            0x5C => {
                if buffer.len() < 12 {
                    return Err(HalError::BufferLengthMismatch);
                }
                buffer[..12].fill(0);
                // 4 MiB total internal drive FIFO, 3 MiB available
                buffer[4..8].copy_from_slice(&4_194_304u32.to_be_bytes());
                buffer[8..12].copy_from_slice(&3_145_728u32.to_be_bytes());
                Ok(ScsiSense::OK)
            }
            0x2A => {
                let lba = u32::from_be_bytes([cdb.bytes[2], cdb.bytes[3], cdb.bytes[4], cdb.bytes[5]]);
                let blocks = u16::from_be_bytes([cdb.bytes[7], cdb.bytes[8]]) as u32;
                let end_lba = lba.saturating_add(blocks);
                if end_lba > self.total_sectors {
                    return Err(HalError::OutOfBoundsLba);
                }
                let needed_bytes = (blocks as usize).saturating_mul(self.sector_size);
                if buffer.len() < needed_bytes {
                    return Err(HalError::BufferLengthMismatch);
                }
                let byte_end = (end_lba as usize).saturating_mul(self.sector_size);
                if self.storage.len() < byte_end {
                    self.storage.resize(byte_end, 0);
                }
                let byte_start = (lba as usize).saturating_mul(self.sector_size);
                self.storage[byte_start..byte_start + needed_bytes]
                    .copy_from_slice(&buffer[..needed_bytes]);
                self.cache_synchronized = false;
                Ok(ScsiSense::OK)
            }
            0x35 => {
                self.cache_synchronized = true;
                Ok(ScsiSense::OK)
            }
            0x5B => {
                self.session_closed = true;
                Ok(ScsiSense::OK)
            }
            0xBE => {
                let lba = u32::from_be_bytes([cdb.bytes[2], cdb.bytes[3], cdb.bytes[4], cdb.bytes[5]]);
                if self.bad_sectors.contains(&lba) {
                    return Ok(ScsiSense { sense_key: 0x03, asc: 0x11, ascq: 0x00 });
                }
                let blocks = u32::from_be_bytes([0, cdb.bytes[6], cdb.bytes[7], cdb.bytes[8]]);
                let needed_bytes = (blocks as usize).saturating_mul(self.sector_size);
                let byte_start = (lba as usize).saturating_mul(self.sector_size);
                let byte_end = byte_start.saturating_add(needed_bytes);
                if buffer.len() < needed_bytes || byte_end > self.storage.len() {
                    return Err(HalError::OutOfBoundsLba);
                }
                buffer[..needed_bytes].copy_from_slice(&self.storage[byte_start..byte_end]);
                Ok(ScsiSense::OK)
            }
            _ => Ok(ScsiSense::OK),
        }
    }

    fn reclaim_unused_resources(&mut self) {
        self.storage.clear();
        self.storage.shrink_to(0);
        self.bad_sectors.clear();
        self.bad_sectors.shrink_to(0);
    }
}

// MARK: - USB Hub Power & Spin-Up / OPC Calibration Arbiter (Ported from Swift BurnKit)

#[derive(Debug, Default)]
pub struct UsbBusPowerArbiter {
    active_calibration_on_bus: BTreeMap<String, String>,
}

impl UsbBusPowerArbiter {
    pub fn new() -> Self {
        Self::default()
    }

    /// Ensures only one drive on a shared USB root hub draws peak spin-up + OPC laser calibration current (~1.8A) at a time.
    pub fn try_acquire_spinup_and_opc(&mut self, bus_id: &str, drive_id: &str) -> bool {
        if let Some(holder) = self.active_calibration_on_bus.get(bus_id) {
            return holder == drive_id;
        }
        self.active_calibration_on_bus.insert(bus_id.to_owned(), drive_id.to_owned());
        true
    }

    pub fn complete_opc_transition_to_steady_burn(&mut self, bus_id: &str, drive_id: &str) {
        if self.active_calibration_on_bus.get(bus_id).map(String::as_str) == Some(drive_id) {
            self.active_calibration_on_bus.remove(bus_id);
        }
    }
}
