// MARK: - sha256.rs

//! SHA-256 behind one small API.
//!
//! A portable FIPS 180-4 implementation, so `krsp` builds with zero dependencies (and offline).
//! Checked against the NIST vectors below and the shared golden vectors in `Vectors/`.

/// Incremental SHA-256.
#[derive(Clone, Debug)]
pub struct Sha256 {
    inner: portable::State,
}

impl Default for Sha256 {
    fn default() -> Self {
        Self::new()
    }
}

impl Sha256 {
    #[must_use]
    pub fn new() -> Self {
        Self { inner: portable::State::new() }
    }

    pub fn update(&mut self, data: &[u8]) {
        self.inner.update(data);
    }

    #[must_use]
    pub fn finalize(self) -> [u8; 32] {
        self.inner.finalize()
    }

    /// One-shot hash of the concatenation of `parts`.
    #[must_use]
    pub fn digest(parts: &[&[u8]]) -> [u8; 32] {
        let mut hasher = Self::new();
        for part in parts {
            hasher.update(part);
        }
        hasher.finalize()
    }
}

mod portable {
    const K: [u32; 64] = [
        0x428a_2f98,
        0x7137_4491,
        0xb5c0_fbcf,
        0xe9b5_dba5,
        0x3956_c25b,
        0x59f1_11f1,
        0x923f_82a4,
        0xab1c_5ed5,
        0xd807_aa98,
        0x1283_5b01,
        0x2431_85be,
        0x550c_7dc3,
        0x72be_5d74,
        0x80de_b1fe,
        0x9bdc_06a7,
        0xc19b_f174,
        0xe49b_69c1,
        0xefbe_4786,
        0x0fc1_9dc6,
        0x240c_a1cc,
        0x2de9_2c6f,
        0x4a74_84aa,
        0x5cb0_a9dc,
        0x76f9_88da,
        0x983e_5152,
        0xa831_c66d,
        0xb003_27c8,
        0xbf59_7fc7,
        0xc6e0_0bf3,
        0xd5a7_9147,
        0x06ca_6351,
        0x1429_2967,
        0x27b7_0a85,
        0x2e1b_2138,
        0x4d2c_6dfc,
        0x5338_0d13,
        0x650a_7354,
        0x766a_0abb,
        0x81c2_c92e,
        0x9272_2c85,
        0xa2bf_e8a1,
        0xa81a_664b,
        0xc24b_8b70,
        0xc76c_51a3,
        0xd192_e819,
        0xd699_0624,
        0xf40e_3585,
        0x106a_a070,
        0x19a4_c116,
        0x1e37_6c08,
        0x2748_774c,
        0x34b0_bcb5,
        0x391c_0cb3,
        0x4ed8_aa4a,
        0x5b9c_ca4f,
        0x682e_6ff3,
        0x748f_82ee,
        0x78a5_636f,
        0x84c8_7814,
        0x8cc7_0208,
        0x90be_fffa,
        0xa450_6ceb,
        0xbef9_a3f7,
        0xc671_78f2,
    ];
    const H0: [u32; 8] =
        [0x6a09_e667, 0xbb67_ae85, 0x3c6e_f372, 0xa54f_f53a, 0x510e_527f, 0x9b05_688c, 0x1f83_d9ab, 0x5be0_cd19];

    #[derive(Clone, Debug)]
    pub(super) struct State {
        h: [u32; 8],
        block: [u8; 64],
        filled: usize,
        total_bytes: u64,
    }

    impl State {
        pub(super) fn new() -> Self {
            Self { h: H0, block: [0; 64], filled: 0, total_bytes: 0 }
        }

        pub(super) fn update(&mut self, mut data: &[u8]) {
            self.total_bytes = self.total_bytes.wrapping_add(data.len() as u64);
            while !data.is_empty() {
                let take = (64 - self.filled).min(data.len());
                let (head, rest) = data.split_at(take);
                if let Some(dst) = self.block.get_mut(self.filled..self.filled + take) {
                    dst.copy_from_slice(head);
                }
                self.filled += take;
                data = rest;
                if self.filled == 64 {
                    let block = self.block;
                    compress(&mut self.h, &block);
                    self.filled = 0;
                }
            }
        }

        pub(super) fn finalize(mut self) -> [u8; 32] {
            let bit_length = self.total_bytes.wrapping_mul(8);
            let mut padding = [0u8; 72];
            if let Some(first) = padding.first_mut() {
                *first = 0x80;
            }
            let pad_len = if self.filled < 56 { 56 - self.filled } else { 120 - self.filled };
            let total = self.total_bytes;
            self.update(padding.get(..pad_len).unwrap_or(&[]));
            self.update(&bit_length.to_be_bytes());
            self.total_bytes = total;
            let mut out = [0u8; 32];
            for (chunk, word) in out.chunks_exact_mut(4).zip(self.h) {
                chunk.copy_from_slice(&word.to_be_bytes());
            }
            out
        }
    }

    // Fixed-size arrays indexed by loop bounds the compiler can see: every index is in range.
    #[allow(clippy::indexing_slicing)]
    fn compress(h: &mut [u32; 8], block: &[u8; 64]) {
        let mut w = [0u32; 64];
        for (word, bytes) in w.iter_mut().zip(block.chunks_exact(4)) {
            *word = u32::from_be_bytes([bytes[0], bytes[1], bytes[2], bytes[3]]);
        }
        for i in 16..64 {
            let s0 = w[i - 15].rotate_right(7) ^ w[i - 15].rotate_right(18) ^ (w[i - 15] >> 3);
            let s1 = w[i - 2].rotate_right(17) ^ w[i - 2].rotate_right(19) ^ (w[i - 2] >> 10);
            w[i] = w[i - 16].wrapping_add(s0).wrapping_add(w[i - 7]).wrapping_add(s1);
        }
        let [mut a, mut b, mut c, mut d, mut e, mut f, mut g, mut hh] = *h;
        for (k, wi) in K.iter().zip(w) {
            let s1 = e.rotate_right(6) ^ e.rotate_right(11) ^ e.rotate_right(25);
            let ch = (e & f) ^ (!e & g);
            let t1 = hh.wrapping_add(s1).wrapping_add(ch).wrapping_add(*k).wrapping_add(wi);
            let s0 = a.rotate_right(2) ^ a.rotate_right(13) ^ a.rotate_right(22);
            let maj = (a & b) ^ (a & c) ^ (b & c);
            let t2 = s0.wrapping_add(maj);
            hh = g;
            g = f;
            f = e;
            e = d.wrapping_add(t1);
            d = c;
            c = b;
            b = a;
            a = t1.wrapping_add(t2);
        }
        for (state, value) in h.iter_mut().zip([a, b, c, d, e, f, g, hh]) {
            *state = state.wrapping_add(value);
        }
    }
}

#[cfg(test)]
#[allow(clippy::unwrap_used, clippy::indexing_slicing, clippy::cast_possible_truncation)]
mod tests {
    use super::Sha256;

    fn hex(bytes: &[u8]) -> String {
        bytes.iter().map(|b| format!("{b:02x}")).collect()
    }

    #[test]
    fn nist_vectors() {
        assert_eq!(hex(&Sha256::digest(&[b""])), "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855");
        assert_eq!(hex(&Sha256::digest(&[b"abc"])), "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad");
        assert_eq!(
            hex(&Sha256::digest(&[b"abcdbcdecdefdefgefghfghighijhijkijkljklmklmnlmnomnopnopq"])),
            "248d6a61d20638b8e5c026930c3e6039a33ce45964ff2167f6ecedd419db06c1"
        );
    }

    #[test]
    fn million_a_in_odd_chunks() {
        let mut hasher = Sha256::new();
        let chunk = [b'a'; 997];
        let mut left = 1_000_000usize;
        while left > 0 {
            let n = left.min(chunk.len());
            hasher.update(&chunk[..n]);
            left -= n;
        }
        assert_eq!(hex(&hasher.finalize()), "cdc76e5c9914fb9281a1c7e284d73e67f1809a48a497200e046d39ccc7112cd0");
    }

    #[test]
    fn every_padding_boundary_matches_one_shot() {
        let data: Vec<u8> = (0..300u32).map(|i| (i * 7 % 251) as u8).collect();
        for len in [55, 56, 57, 63, 64, 65, 119, 120, 128] {
            let mut split = Sha256::new();
            split.update(&data[..len / 2]);
            split.update(&data[len / 2..len]);
            assert_eq!(split.finalize(), Sha256::digest(&[&data[..len]]), "len {len}");
        }
    }
}
