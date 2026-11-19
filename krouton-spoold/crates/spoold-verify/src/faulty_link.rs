//! Deterministic in-memory stand-in for one TCP connection. Same SplitMix64 constants and fault
//! semantics as Swift's `SimulatedFaultyTransport`, so a given seed fragments identically in both
//! harnesses and their traces can be compared.
//!
//! A reliable byte stream cannot silently lose one packet, so "loss" is modelled as what TCP
//! actually surfaces: a dropped connection, or bytes damaged/missing past the transport checksums
//! (caught by the extent SHA-256 or by the frame magic).

#[derive(Clone, Debug)]
pub struct SplitMix64 {
    state: u64,
}

impl SplitMix64 {
    pub fn new(seed: u64) -> Self {
        Self { state: seed }
    }

    pub fn next_u64(&mut self) -> u64 {
        self.state = self.state.wrapping_add(0x9E37_79B9_7F4A_7C15);
        let mut z = self.state;
        z = (z ^ (z >> 30)).wrapping_mul(0xBF58_476D_1CE4_E5B9);
        z = (z ^ (z >> 27)).wrapping_mul(0x94D0_49BB_1331_11EB);
        z ^ (z >> 31)
    }

    /// Uniform-ish in `1..=max` (same modulo reduction as the Swift harness).
    pub fn fragment_len(&mut self, max: usize) -> usize {
        let span = max.max(1) as u64;
        1 + usize::try_from(self.next_u64() % span).unwrap_or(0)
    }
}

#[derive(Clone, Debug, Default)]
pub struct Faults {
    pub disconnect_at_byte: Option<u64>,
    pub flip_bit_at_byte: Option<u64>,
    pub drop_bytes: Option<std::ops::Range<u64>>,
}

#[derive(Debug)]
pub struct FaultyLink {
    rng: SplitMix64,
    max_fragment: usize,
    faults: Faults,
    forward_offset: u64,
    pub connected: bool,
}

impl FaultyLink {
    pub fn new(seed: u64, max_fragment: usize, faults: Faults) -> Self {
        Self {
            rng: SplitMix64::new(seed),
            max_fragment: max_fragment.max(1),
            faults,
            forward_offset: 0,
            connected: true,
        }
    }

    /// Workstation → node: arbitrary fragmentation plus the scheduled one-shot faults.
    pub fn carry(&mut self, bytes: &[u8]) -> Vec<Vec<u8>> {
        if !self.connected {
            return Vec::new();
        }
        let mut delivered = Vec::with_capacity(bytes.len());
        let mut processed = 0u64;
        for &byte in bytes {
            let offset = self.forward_offset + processed;
            if self.faults.disconnect_at_byte.is_some_and(|cut| offset >= cut) {
                self.faults.disconnect_at_byte = None;
                self.connected = false;
                break;
            }
            processed += 1;
            if self.faults.drop_bytes.as_ref().is_some_and(|r| r.contains(&offset)) {
                continue;
            }
            if self.faults.flip_bit_at_byte == Some(offset) {
                delivered.push(byte ^ 0x10);
                continue;
            }
            delivered.push(byte);
        }
        self.forward_offset += processed;
        if self.faults.drop_bytes.as_ref().is_some_and(|r| self.forward_offset >= r.end) {
            self.faults.drop_bytes = None;
        }
        if self.faults.flip_bit_at_byte.is_some_and(|flip| self.forward_offset > flip) {
            self.faults.flip_bit_at_byte = None;
        }
        self.fragment(&delivered)
    }

    /// Node → workstation: reliable, still fragmented.
    pub fn carry_back(&mut self, bytes: &[u8]) -> Vec<Vec<u8>> {
        if self.connected { self.fragment(bytes) } else { Vec::new() }
    }

    pub fn reconnect(&mut self) {
        self.connected = true;
    }

    fn fragment(&mut self, bytes: &[u8]) -> Vec<Vec<u8>> {
        let mut pieces = Vec::new();
        let mut rest = bytes;
        while !rest.is_empty() {
            let take = self.rng.fragment_len(self.max_fragment).min(rest.len());
            let (head, tail) = rest.split_at(take);
            pieces.push(head.to_vec());
            rest = tail;
        }
        pieces
    }
}
