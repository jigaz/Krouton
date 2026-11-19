#![forbid(unsafe_code)]

// MARK: - MMC-6 SCSI Command Descriptor Blocks (CDB) & Sense Decoder

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum DataDirection {
    None,
    FromDrive,
    ToDrive,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub struct ScsiCdb {
    pub bytes: [u8; 12],
    pub len: u8,
    pub direction: DataDirection,
}

// MARK: - Pure MMC-6 CDB Constructors

impl ScsiCdb {
    pub const fn as_slice(&self) -> &[u8] {
        match self.len {
            6 => &self.bytes.split_at(6).0,
            10 => &self.bytes.split_at(10).0,
            _ => &self.bytes,
        }
    }

    /// 0x00 TEST UNIT READY
    pub const fn test_unit_ready() -> Self {
        Self { bytes: [0; 12], len: 6, direction: DataDirection::None }
    }

    /// 0x03 REQUEST SENSE
    pub const fn request_sense(alloc_len: u8) -> Self {
        let mut b = [0u8; 12];
        b[0] = 0x03;
        b[4] = alloc_len;
        Self { bytes: b, len: 6, direction: DataDirection::FromDrive }
    }

    /// 0x1B START STOP UNIT (eject / load / spin locate)
    pub const fn start_stop_unit(start: bool, load_eject: bool) -> Self {
        let mut b = [0u8; 12];
        b[0] = 0x1B;
        b[4] = (if load_eject { 0x02 } else { 0x00 }) | (if start { 0x01 } else { 0x00 });
        Self { bytes: b, len: 6, direction: DataDirection::None }
    }

    /// 0x1E PREVENT ALLOW MEDIUM REMOVAL
    pub const fn set_tray_lock(locked: bool) -> Self {
        let mut b = [0u8; 12];
        b[0] = 0x1E;
        b[4] = if locked { 0x01 } else { 0x00 };
        Self { bytes: b, len: 6, direction: DataDirection::None }
    }

    /// 0x35 SYNCHRONIZE CACHE (10)
    pub const fn synchronize_cache(immediate: bool) -> Self {
        let mut b = [0u8; 12];
        b[0] = 0x35;
        b[1] = if immediate { 0x02 } else { 0x00 };
        Self { bytes: b, len: 10, direction: DataDirection::None }
    }

    /// 0x46 GET CONFIGURATION
    pub const fn get_configuration(starting_feature: u16, alloc_len: u16) -> Self {
        let mut b = [0u8; 12];
        b[0] = 0x46;
        let sf = starting_feature.to_be_bytes();
        let al = alloc_len.to_be_bytes();
        b[2] = sf[0];
        b[3] = sf[1];
        b[7] = al[0];
        b[8] = al[1];
        Self { bytes: b, len: 10, direction: DataDirection::FromDrive }
    }

    /// 0x51 READ DISC INFORMATION
    pub const fn read_disc_information(alloc_len: u16) -> Self {
        let mut b = [0u8; 12];
        b[0] = 0x51;
        let al = alloc_len.to_be_bytes();
        b[7] = al[0];
        b[8] = al[1];
        Self { bytes: b, len: 10, direction: DataDirection::FromDrive }
    }

    /// 0x5C READ BUFFER CAPACITY (drive internal FIFO fill telemetry)
    pub const fn read_buffer_capacity() -> Self {
        let mut b = [0u8; 12];
        b[0] = 0x5C;
        b[8] = 12;
        Self { bytes: b, len: 10, direction: DataDirection::FromDrive }
    }

    /// 0x5B CLOSE TRACK / SESSION
    pub const fn close_track_session(close_function: u8, track_number: u16, immediate: bool) -> Self {
        let mut b = [0u8; 12];
        b[0] = 0x5B;
        b[1] = if immediate { 0x01 } else { 0x00 };
        b[2] = close_function & 0x07;
        let tn = track_number.to_be_bytes();
        b[4] = tn[0];
        b[5] = tn[1];
        Self { bytes: b, len: 10, direction: DataDirection::None }
    }

    /// 0x5D SEND CUE SHEET (Red Book DAO / SAO Audio CD mastering)
    pub const fn send_cue_sheet(cue_sheet_byte_len: u32) -> Self {
        let mut b = [0u8; 12];
        b[0] = 0x5D;
        let l = cue_sheet_byte_len.to_be_bytes();
        b[6] = l[1];
        b[7] = l[2];
        b[8] = l[3];
        Self { bytes: b, len: 10, direction: DataDirection::ToDrive }
    }

    /// 0x2A WRITE (10)
    pub const fn write_10(lba: u32, transfer_blocks: u16) -> Self {
        let mut b = [0u8; 12];
        b[0] = 0x2A;
        let l = lba.to_be_bytes();
        let c = transfer_blocks.to_be_bytes();
        b[2] = l[0];
        b[3] = l[1];
        b[4] = l[2];
        b[5] = l[3];
        b[7] = c[0];
        b[8] = c[1];
        Self { bytes: b, len: 10, direction: DataDirection::ToDrive }
    }

    /// 0xBE READ CD (raw 2352-byte extraction + optional 294-byte C2 error pointers for RescueKit)
    pub const fn read_cd(lba: u32, transfer_blocks: u32, include_c2_error_pointers: bool) -> Self {
        let mut b = [0u8; 12];
        b[0] = 0xBE;
        let l = lba.to_be_bytes();
        let c = transfer_blocks.to_be_bytes();
        b[2] = l[0];
        b[3] = l[1];
        b[4] = l[2];
        b[5] = l[3];
        b[6] = c[1];
        b[7] = c[2];
        b[8] = c[3];
        // 0xF8 = Sync + All Headers + User Data + EDC/ECC; 0x02 = 294-byte C2 error pointer block
        b[9] = 0xF8 | (if include_c2_error_pointers { 0x02 } else { 0x00 });
        Self { bytes: b, len: 12, direction: DataDirection::FromDrive }
    }
}

// MARK: - SCSI Sense Key / ASC / ASCQ Classification

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub struct ScsiSense {
    pub sense_key: u8,
    pub asc: u8,
    pub ascq: u8,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum SenseAction {
    Ok,
    DriveBusyLongWriteInProgress,
    DriveBecomingReady,
    MediumNotPresent,
    UnrecoveredReadErrorC2,
    WriteErrorBufferUnderrun,
    FatalHardwareOrCommandError,
}

impl ScsiSense {
    pub const OK: Self = Self { sense_key: 0, asc: 0, ascq: 0 };

    pub fn from_fixed_sense_buffer(buf: &[u8]) -> Self {
        if buf.len() < 14 {
            return Self::OK;
        }
        Self {
            sense_key: buf[2] & 0x0F,
            asc: buf[12],
            ascq: buf[13],
        }
    }

    pub const fn classify(self) -> SenseAction {
        match (self.sense_key, self.asc, self.ascq) {
            (0x00, _, _) | (0x01, _, _) => SenseAction::Ok,
            (0x02, 0x04, 0x07) | (0x02, 0x04, 0x08) => SenseAction::DriveBusyLongWriteInProgress,
            (0x02, 0x04, 0x01) => SenseAction::DriveBecomingReady,
            (0x02, 0x3A, _) => SenseAction::MediumNotPresent,
            (0x03, 0x11, _) => SenseAction::UnrecoveredReadErrorC2,
            (0x03, 0x0C, 0x09) => SenseAction::WriteErrorBufferUnderrun,
            _ => SenseAction::FatalHardwareOrCommandError,
        }
    }
}
