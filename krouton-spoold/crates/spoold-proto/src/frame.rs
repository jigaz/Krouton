// MARK: - frame.rs

//! KRSP v1 framing: a fixed 64-byte big-endian header followed by `payload_length` bytes.
//! Byte-for-byte identical to `SpoolWireFrame.swift`; `vectors/krsp-golden-v1.txt` pins it.
//!
//! ```text
//!  0 magic u32 "KRSP" | 4 version u8 | 5 kind u8 | 6 flags u16 | 8 extent_index u32
//! 12 first_lba u64 | 20 sector_size u16 | 22 reserved u16 | 24 payload_length u32
//! 28 reserved u32 | 32 digest [u8; 32]
//! ```

use std::fmt;

pub const HEADER_LEN: usize = 64;
pub const MAGIC: u32 = 0x4B52_5350;
pub const VERSION: u8 = 1;
/// Upper bound on any single payload: a hostile length can never make us allocate more.
pub const MAX_PAYLOAD: u32 = 8 * 1024 * 1024;
/// Sector sizes accepted on `ExtentData` frames (Mode 1, Mode 2 formless, CD-DA/raw, raw + 96 B subchannel).
pub const SECTOR_SIZES: [u16; 4] = [2048, 2336, 2352, 2448];

#[derive(Clone, Copy, Debug, PartialEq, Eq, Hash)]
#[repr(u8)]
pub enum FrameKind {
    BitmapQuery = 1,
    BitmapReply = 2,
    ExtentData = 3,
    ExtentAck = 4,
    ExtentReject = 5,
    Credit = 6,
    Telemetry = 7,
    Control = 8,
    ManifestMismatch = 9,
    /// Contract v1.1 proposal (not yet in the Swift client): carries the manifest's leaf digests
    /// so a node can verify extents. See `manifest::ManifestOffer`.
    ManifestOffer = 10,
}

impl FrameKind {
    #[must_use]
    pub fn from_u8(value: u8) -> Option<Self> {
        Some(match value {
            1 => Self::BitmapQuery,
            2 => Self::BitmapReply,
            3 => Self::ExtentData,
            4 => Self::ExtentAck,
            5 => Self::ExtentReject,
            6 => Self::Credit,
            7 => Self::Telemetry,
            8 => Self::Control,
            9 => Self::ManifestMismatch,
            10 => Self::ManifestOffer,
            _ => return None,
        })
    }
}

#[derive(Clone, Debug, PartialEq, Eq)]
pub enum WireError {
    BadMagic,
    UnsupportedVersion(u8),
    UnknownKind(u8),
    PayloadTooLarge(u32),
    MalformedExtentFrame,
    Truncated,
}

impl fmt::Display for WireError {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        match self {
            Self::BadMagic => write!(f, "bad magic: stream is not KRSP or lost alignment"),
            Self::UnsupportedVersion(v) => write!(f, "unsupported KRSP version {v}"),
            Self::UnknownKind(k) => write!(f, "unknown frame kind {k}"),
            Self::PayloadTooLarge(n) => write!(f, "payload length {n} exceeds {MAX_PAYLOAD}"),
            Self::MalformedExtentFrame => write!(f, "extent payload is not whole sectors of a supported size"),
            Self::Truncated => write!(f, "fewer than {HEADER_LEN} bytes"),
        }
    }
}

impl std::error::Error for WireError {}

#[derive(Clone, Debug, PartialEq, Eq)]
pub struct FrameHeader {
    pub kind: FrameKind,
    pub flags: u16,
    pub extent_index: u32,
    pub first_lba: u64,
    pub sector_size: u16,
    pub payload_length: u32,
    pub digest: [u8; 32],
}

impl FrameHeader {
    #[must_use]
    pub fn new(kind: FrameKind) -> Self {
        Self { kind, flags: 0, extent_index: 0, first_lba: 0, sector_size: 0, payload_length: 0, digest: [0; 32] }
    }

    #[must_use]
    pub fn encode(&self) -> [u8; HEADER_LEN] {
        let mut out = [0u8; HEADER_LEN];
        let fields: [(usize, &[u8]); 9] = [
            (0, &MAGIC.to_be_bytes()),
            (4, &[VERSION]),
            (5, &[self.kind as u8]),
            (6, &self.flags.to_be_bytes()),
            (8, &self.extent_index.to_be_bytes()),
            (12, &self.first_lba.to_be_bytes()),
            (20, &self.sector_size.to_be_bytes()),
            (24, &self.payload_length.to_be_bytes()),
            (32, &self.digest),
        ];
        for (offset, bytes) in fields {
            if let Some(dst) = out.get_mut(offset..offset + bytes.len()) {
                dst.copy_from_slice(bytes);
            }
        }
        out
    }

    /// Decodes the first 64 bytes of `bytes`. Reserved fields are ignored, exactly like Swift.
    pub fn decode(bytes: &[u8]) -> Result<Self, WireError> {
        let h: &[u8; HEADER_LEN] =
            bytes.get(..HEADER_LEN).and_then(|s| s.try_into().ok()).ok_or(WireError::Truncated)?;
        let [
            m0,
            m1,
            m2,
            m3,
            version,
            kind_byte,
            f0,
            f1,
            i0,
            i1,
            i2,
            i3,
            l0,
            l1,
            l2,
            l3,
            l4,
            l5,
            l6,
            l7,
            s0,
            s1,
            _,
            _,
            p0,
            p1,
            p2,
            p3,
            ..,
        ] = *h;
        if u32::from_be_bytes([m0, m1, m2, m3]) != MAGIC {
            return Err(WireError::BadMagic);
        }
        if version != VERSION {
            return Err(WireError::UnsupportedVersion(version));
        }
        let kind = FrameKind::from_u8(kind_byte).ok_or(WireError::UnknownKind(kind_byte))?;
        let payload_length = u32::from_be_bytes([p0, p1, p2, p3]);
        if payload_length > MAX_PAYLOAD {
            return Err(WireError::PayloadTooLarge(payload_length));
        }
        let mut digest = [0u8; 32];
        digest.copy_from_slice(h.get(32..64).ok_or(WireError::Truncated)?);
        let header = Self {
            kind,
            flags: u16::from_be_bytes([f0, f1]),
            extent_index: u32::from_be_bytes([i0, i1, i2, i3]),
            first_lba: u64::from_be_bytes([l0, l1, l2, l3, l4, l5, l6, l7]),
            sector_size: u16::from_be_bytes([s0, s1]),
            payload_length,
            digest,
        };
        if kind == FrameKind::ExtentData
            && (!SECTOR_SIZES.contains(&header.sector_size)
                || payload_length == 0
                || !payload_length.is_multiple_of(u32::from(header.sector_size)))
        {
            return Err(WireError::MalformedExtentFrame);
        }
        Ok(header)
    }
}

#[derive(Clone, Debug, PartialEq, Eq)]
pub struct Frame {
    pub header: FrameHeader,
    pub payload: Vec<u8>,
}

impl Frame {
    /// Builds a frame and sets `payload_length` from the payload. A payload over `MAX_PAYLOAD`
    /// produces a header every receiver refuses, so callers must not build one.
    #[must_use]
    pub fn new(mut header: FrameHeader, payload: Vec<u8>) -> Self {
        header.payload_length = u32::try_from(payload.len()).unwrap_or(u32::MAX);
        Self { header, payload }
    }

    #[must_use]
    pub fn signal(kind: FrameKind, extent_index: u32) -> Self {
        let mut header = FrameHeader::new(kind);
        header.extent_index = extent_index;
        Self::new(header, Vec::new())
    }

    /// Header + payload in one buffer (tests and small control frames). Production sends the header
    /// and the payload as two writes so a 4 MiB extent is never copied to join them.
    #[must_use]
    pub fn encode(&self) -> Vec<u8> {
        let mut out = Vec::with_capacity(HEADER_LEN + self.payload.len());
        out.extend_from_slice(&self.header.encode());
        out.extend_from_slice(&self.payload);
        out
    }
}

/// Reassembles frames from arbitrary fragments (one byte at a time is fine).
///
/// Memory is bounded: the buffer never holds more than one frame (64 B + `MAX_PAYLOAD`) plus the
/// unconsumed tail of the last `push`, because a complete frame is always drained before returning.
#[derive(Debug, Default)]
pub struct FrameDecoder {
    buffer: Vec<u8>,
}

impl FrameDecoder {
    #[must_use]
    pub fn buffered_capacity(&self) -> usize {
        self.buffer.capacity()
    }

    /// Immediately returns unused decoder heap capacity to the OS allocator when idle.
    pub fn reclaim_unused_resources(&mut self) {
        if self.buffer.is_empty() {
            self.buffer.shrink_to(0);
        } else {
            self.buffer.shrink_to_fit();
        }
    }

    #[must_use]
    pub fn new() -> Self {
        Self::default()
    }

    #[must_use]
    pub fn buffered_len(&self) -> usize {
        self.buffer.len()
    }

    /// Returns every complete frame. An error means the stream can no longer be re-synchronised:
    /// drop the connection and resume from the node's bitmap.
    pub fn push(&mut self, bytes: &[u8]) -> Result<Vec<Frame>, WireError> {
        self.buffer.extend_from_slice(bytes);
        let mut frames = Vec::new();
        let mut cursor = 0usize;
        while let Some(rest) = self.buffer.get(cursor..) {
            if rest.len() < HEADER_LEN {
                break;
            }
            let header = FrameHeader::decode(rest)?;
            let total = HEADER_LEN + header.payload_length as usize;
            let Some(payload) = rest.get(HEADER_LEN..total) else { break };
            frames.push(Frame { payload: payload.to_vec(), header });
            cursor += total;
        }
        self.buffer.drain(..cursor);
        Ok(frames)
    }

    pub fn reset(&mut self) {
        self.buffer.clear();
    }
}
