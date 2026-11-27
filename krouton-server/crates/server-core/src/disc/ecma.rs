// MARK: - disc/ecma.rs

//! The small building blocks ECMA-119 (ISO 9660) and ECMA-167/UDF descriptors are made of:
//! little- and big-endian fields, descriptor tags with their checksum and CRC, OSTA CS0
//! strings, timestamps and entity identifiers.

/// Every structure here is laid out in 2048-byte sectors (logical blocks).
pub const SECTOR: u64 = 2048;
pub const SECTOR_BYTES: usize = 2048;

// MARK: - Fields

pub fn put_u16(buf: &mut [u8], at: usize, value: u16) {
    buf[at..at + 2].copy_from_slice(&value.to_le_bytes());
}

pub fn put_u32(buf: &mut [u8], at: usize, value: u32) {
    buf[at..at + 4].copy_from_slice(&value.to_le_bytes());
}

pub fn put_u64(buf: &mut [u8], at: usize, value: u64) {
    buf[at..at + 8].copy_from_slice(&value.to_le_bytes());
}

/// ECMA-119 "both-byte orders": little-endian then big-endian.
pub fn put_both_u16(buf: &mut [u8], at: usize, value: u16) {
    buf[at..at + 2].copy_from_slice(&value.to_le_bytes());
    buf[at + 2..at + 4].copy_from_slice(&value.to_be_bytes());
}

pub fn put_both_u32(buf: &mut [u8], at: usize, value: u32) {
    buf[at..at + 4].copy_from_slice(&value.to_le_bytes());
    buf[at + 4..at + 8].copy_from_slice(&value.to_be_bytes());
}

/// A sector or block count that must fit a 32-bit field.
///
/// # Errors
/// The image would be larger than any disc file system can address.
pub fn u32_of(value: u64) -> Result<u32, String> {
    u32::try_from(value).map_err(|_| "The disc would be too large to describe".to_owned())
}

/// Number of whole sectors needed for `bytes`.
#[must_use]
pub fn sectors(bytes: u64) -> u64 {
    bytes.div_ceil(SECTOR)
}

// MARK: - Descriptor tags (ECMA-167 3/7.2)

/// CRC-ITU-T (polynomial 0x1021, initial value 0), as ECMA-167 descriptor tags use.
#[must_use]
pub fn crc_itu(data: &[u8]) -> u16 {
    let mut crc: u16 = 0;
    for &byte in data {
        crc ^= u16::from(byte) << 8;
        for _ in 0..8 {
            crc = if crc & 0x8000 != 0 { (crc << 1) ^ 0x1021 } else { crc << 1 };
        }
    }
    crc
}

/// Fills in the 16-byte tag at the start of `descriptor` (whose length is the descriptor's
/// recorded length): identifier, version, serial, CRC over the body, location and checksum.
pub fn finish_tag(descriptor: &mut [u8], identifier: u16, version: u16, location: u32) {
    put_u16(descriptor, 0, identifier);
    put_u16(descriptor, 2, version);
    descriptor[4] = 0;
    descriptor[5] = 0;
    put_u16(descriptor, 6, 1); // tag serial number, the same on every descriptor
    let body_len = u16::try_from(descriptor.len() - 16).unwrap_or(u16::MAX);
    let crc = crc_itu(&descriptor[16..16 + usize::from(body_len)]);
    put_u16(descriptor, 8, crc);
    put_u16(descriptor, 10, body_len);
    put_u32(descriptor, 12, location);
    let checksum =
        descriptor[..16].iter().enumerate().filter(|(i, _)| *i != 4).fold(0u8, |sum, (_, b)| sum.wrapping_add(*b));
    descriptor[4] = checksum;
}

// MARK: - OSTA CS0 strings (UDF 2.1.1)

/// OSTA Compressed Unicode: compression ID 8 (one byte a character) when every character fits
/// in Latin-1, otherwise 16 (UTF-16 big-endian). Characters past `max_bytes` are dropped whole.
#[must_use]
pub fn cs0(text: &str, max_bytes: usize) -> Vec<u8> {
    if text.is_empty() {
        return Vec::new();
    }
    if text.chars().all(|c| u32::from(c) <= 0xFF) {
        let mut out = vec![8u8];
        for c in text.chars() {
            if out.len() + 1 > max_bytes {
                break;
            }
            out.push(u8::try_from(u32::from(c)).unwrap_or(b'_'));
        }
        out
    } else {
        let mut out = vec![16u8];
        for c in text.chars() {
            let mut units = [0u16; 2];
            let units = c.encode_utf16(&mut units);
            if out.len() + 2 * units.len() > max_bytes {
                break;
            }
            for unit in units.iter() {
                out.extend_from_slice(&unit.to_be_bytes());
            }
        }
        out
    }
}

/// A fixed-length `dstring` field: CS0 bytes, zero padding, and the used length in the last byte.
#[must_use]
pub fn dstring(text: &str, field: usize) -> Vec<u8> {
    let mut out = vec![0u8; field];
    let bytes = cs0(text, field - 1);
    out[..bytes.len()].copy_from_slice(&bytes);
    out[field - 1] = u8::try_from(bytes.len()).unwrap_or(0);
    out
}

/// The `charspec` every UDF volume uses: CS0, "OSTA Compressed Unicode".
#[must_use]
pub fn charspec() -> [u8; 64] {
    let mut out = [0u8; 64];
    out[1..24].copy_from_slice(b"OSTA Compressed Unicode");
    out
}

// MARK: - Entity identifiers (ECMA-167 1/7.4, UDF 2.1.5)

/// An entity identifier: flags 0, the identifier text and an 8-byte suffix.
#[must_use]
pub fn regid(identifier: &str, suffix: [u8; 8]) -> [u8; 32] {
    let mut out = [0u8; 32];
    let text = identifier.as_bytes();
    let len = text.len().min(23);
    out[1..=len].copy_from_slice(&text[..len]);
    out[24..32].copy_from_slice(&suffix);
    out
}

/// Suffix for domain and UDF identifiers: the UDF revision (BCD), OS class and OS identifier 0
/// ("undefined"), so the same tree gives the same bytes on every server.
#[must_use]
pub fn udf_suffix(revision: u16) -> [u8; 8] {
    let mut out = [0u8; 8];
    out[..2].copy_from_slice(&revision.to_le_bytes());
    out
}

/// Krouton's implementation identifier.
#[must_use]
pub fn implementation_id() -> [u8; 32] {
    regid("*Krouton", [0; 8])
}

// MARK: - Time

/// A calendar date and time in UTC.
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub struct Civil {
    pub year: i64,
    pub month: u8,
    pub day: u8,
    pub hour: u8,
    pub minute: u8,
    pub second: u8,
}

impl Civil {
    /// From Unix seconds (Howard Hinnant's civil-from-days).
    #[must_use]
    pub fn from_unix(secs: u64) -> Self {
        let days = i64::try_from(secs / 86_400).unwrap_or(0);
        let rem = secs % 86_400;
        let z = days + 719_468;
        let era = z.div_euclid(146_097);
        let doe = z - era * 146_097;
        let yoe = (doe - doe / 1460 + doe / 36_524 - doe / 146_096) / 365;
        let doy = doe - (365 * yoe + yoe / 4 - yoe / 100);
        let mp = (5 * doy + 2) / 153;
        let day = doy - (153 * mp + 2) / 5 + 1;
        let month = if mp < 10 { mp + 3 } else { mp - 9 };
        let small = |v: i64| u8::try_from(v).unwrap_or(0);
        let small64 = |v: u64| u8::try_from(v).unwrap_or(0);
        Self {
            year: yoe + era * 400 + i64::from(month <= 2),
            month: small(month),
            day: small(day),
            hour: small64(rem / 3600),
            minute: small64(rem % 3600 / 60),
            second: small64(rem % 60),
        }
    }

    /// ECMA-167 timestamp: type 1 (local time) at offset 0, i.e. UTC.
    #[must_use]
    pub fn udf(&self) -> [u8; 12] {
        let mut out = [0u8; 12];
        out[..2].copy_from_slice(&0x1000u16.to_le_bytes());
        let year = i16::try_from(self.year).unwrap_or(1980);
        out[2..4].copy_from_slice(&year.to_le_bytes());
        out[4] = self.month;
        out[5] = self.day;
        out[6] = self.hour;
        out[7] = self.minute;
        out[8] = self.second;
        out
    }

    /// ECMA-119 directory-record date: years since 1900, then month … second, offset 0.
    #[must_use]
    pub fn iso_record(&self) -> [u8; 7] {
        let years = u8::try_from((self.year - 1900).clamp(0, 255)).unwrap_or(0);
        [years, self.month, self.day, self.hour, self.minute, self.second, 0]
    }

    /// ECMA-119 volume-descriptor date: 16 digits ("YYYYMMDDHHMMSScc") and offset 0.
    #[must_use]
    pub fn iso_volume(&self) -> [u8; 17] {
        let text = format!(
            "{:04}{:02}{:02}{:02}{:02}{:02}00",
            self.year.clamp(0, 9999),
            self.month,
            self.day,
            self.hour,
            self.minute,
            self.second
        );
        let mut out = [0u8; 17];
        out[..16].copy_from_slice(&text.as_bytes()[..16]);
        out
    }
}

/// The "not specified" ECMA-119 volume date: sixteen '0' digits and offset 0.
#[must_use]
pub fn iso_volume_unset() -> [u8; 17] {
    let mut out = [b'0'; 17];
    out[16] = 0;
    out
}

// MARK: - Tests

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn crc_matches_the_ccitt_check_value() {
        // CRC-16/XMODEM (poly 0x1021, init 0) of "123456789".
        assert_eq!(crc_itu(b"123456789"), 0x31C3);
    }

    #[test]
    fn tag_checksum_and_crc() {
        let mut d = vec![0u8; 512];
        d[16] = 0xAB;
        finish_tag(&mut d, 2, 3, 256);
        assert_eq!(u16::from_le_bytes([d[0], d[1]]), 2);
        assert_eq!(u16::from_le_bytes([d[10], d[11]]), 496);
        assert_eq!(u16::from_le_bytes([d[8], d[9]]), crc_itu(&d[16..]));
        let sum = d[..16].iter().enumerate().filter(|(i, _)| *i != 4).fold(0u8, |s, (_, b)| s.wrapping_add(*b));
        assert_eq!(d[4], sum);
    }

    #[test]
    fn cs0_picks_the_narrowest_encoding_and_truncates_whole_characters() {
        assert_eq!(cs0("Ünï", 255), vec![8, 0xDC, b'n', 0xEF]);
        assert_eq!(cs0("–", 255), vec![16, 0x20, 0x13]);
        assert_eq!(cs0("😀", 255), vec![16, 0xD8, 0x3D, 0xDE, 0x00]);
        assert_eq!(cs0("😀", 4), vec![16]);
        assert_eq!(cs0("abcdef", 4), vec![8, b'a', b'b', b'c']);
        let field = dstring("Krouton", 32);
        assert_eq!(field.len(), 32);
        assert_eq!(field[31], 8);
        assert_eq!(&field[..8], b"\x08Krouton");
    }

    #[test]
    fn civil_dates() {
        let c = Civil::from_unix(1_795_000_000); // 2026-11-18T11:06:40Z
        assert_eq!((c.year, c.month, c.day, c.hour, c.minute, c.second), (2026, 11, 18, 11, 6, 40));
        assert_eq!(&c.iso_volume()[..16], b"2026111811064000");
        assert_eq!(c.iso_record()[0], 126);
        assert_eq!(&c.udf()[..4], &[0x00, 0x10, 0xEA, 0x07]);
    }
}
