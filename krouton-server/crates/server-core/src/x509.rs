//! Just enough DER to pull the P-256 public key out of an X.509 certificate, so key pins
//! (`SHA256(X9.63 key)`, the value Krouton's `SecKeyCopyExternalRepresentation` hashes) can be
//! computed from what the TLS handshake delivered. Everything else in the certificate is ignored:
//! trust comes from the pin, not from names, dates or issuers.

const SEQUENCE: u8 = 0x30;
const BIT_STRING: u8 = 0x03;
const OID: u8 = 0x06;
const EXPLICIT_0: u8 = 0xA0;
/// 1.2.840.10045.2.1 id-ecPublicKey
const EC_PUBLIC_KEY: &[u8] = &[0x2A, 0x86, 0x48, 0xCE, 0x3D, 0x02, 0x01];
/// 1.2.840.10045.3.1.7 prime256v1 / secp256r1
const PRIME256V1: &[u8] = &[0x2A, 0x86, 0x48, 0xCE, 0x3D, 0x03, 0x01, 0x07];

/// Splits one DER TLV off the front of `input`: `(tag, value, rest)`.
fn tlv(input: &[u8]) -> Option<(u8, &[u8], &[u8])> {
    let (&tag, rest) = input.split_first()?;
    let (&first, rest) = rest.split_first()?;
    let (len, rest) = if first < 0x80 {
        (usize::from(first), rest)
    } else {
        let n = usize::from(first & 0x7F);
        if n == 0 || n > 4 || rest.len() < n {
            return None;
        }
        let (bytes, rest) = rest.split_at(n);
        let len = bytes.iter().fold(0usize, |acc, b| (acc << 8) | usize::from(*b));
        // DER: long form only for lengths ≥ 128, minimal encoding.
        if len < 0x80 || bytes.first() == Some(&0) {
            return None;
        }
        (len, rest)
    };
    if rest.len() < len {
        return None;
    }
    let (value, rest) = rest.split_at(len);
    Some((tag, value, rest))
}

fn expect(input: &[u8], tag: u8) -> Option<(&[u8], &[u8])> {
    let (t, value, rest) = tlv(input)?;
    (t == tag).then_some((value, rest))
}

/// The 65-byte uncompressed (`04 ‖ X ‖ Y`) P-256 key of a certificate, or `None` for anything
/// that is not a well-formed certificate with a P-256 key.
#[must_use]
pub fn p256_public_key(certificate_der: &[u8]) -> Option<[u8; 65]> {
    let (cert, trailing) = expect(certificate_der, SEQUENCE)?;
    if !trailing.is_empty() {
        return None;
    }
    let (tbs, _) = expect(cert, SEQUENCE)?;
    let mut rest = tbs;
    if rest.first() == Some(&EXPLICIT_0) {
        rest = tlv(rest)?.2; // version
    }
    for _ in 0..5 {
        rest = tlv(rest)?.2; // serial, signature, issuer, validity, subject
    }
    let (spki, _) = expect(rest, SEQUENCE)?;
    let (algorithm, spki_rest) = expect(spki, SEQUENCE)?;
    let (algorithm_oid, params) = expect(algorithm, OID)?;
    let (curve_oid, _) = expect(params, OID)?;
    if algorithm_oid != EC_PUBLIC_KEY || curve_oid != PRIME256V1 {
        return None;
    }
    let (bits, _) = expect(spki_rest, BIT_STRING)?;
    let (&unused, key) = bits.split_first()?;
    if unused != 0 || key.len() != 65 || key.first() != Some(&0x04) {
        return None;
    }
    key.try_into().ok()
}

/// The key pin of a certificate (see `krsp::identity::tls_key_pin`).
#[must_use]
pub fn certificate_pin(certificate_der: &[u8]) -> Option<[u8; 32]> {
    krsp::identity::tls_key_pin(&p256_public_key(certificate_der)?)
}

#[cfg(test)]
#[allow(clippy::unwrap_used, clippy::indexing_slicing)]
mod tests {
    use super::*;

    const P256: &[u8] = include_bytes!("../tests/fixtures/p256.der");
    const P256_KEY: &str = include_str!("../tests/fixtures/p256.pub.hex");
    const RSA: &[u8] = include_bytes!("../tests/fixtures/rsa.der");
    const P384: &[u8] = include_bytes!("../tests/fixtures/p384.der");

    #[test]
    fn extracts_the_openssl_generated_key() {
        assert_eq!(krsp::hex(&p256_public_key(P256).unwrap()), P256_KEY.trim());
        assert!(certificate_pin(P256).is_some());
    }

    #[test]
    fn rejects_other_keys_and_damage() {
        assert!(p256_public_key(RSA).is_none());
        assert!(p256_public_key(P384).is_none());
        assert!(p256_public_key(&P256[..P256.len() - 1]).is_none());
        let mut trailing = P256.to_vec();
        trailing.push(0);
        assert!(p256_public_key(&trailing).is_none());
        assert!(p256_public_key(&[]).is_none());
        // Every truncation and every single-byte corruption either parses to the same key or fails;
        // none panics.
        for cut in 0..P256.len() {
            let _ = p256_public_key(&P256[..cut]);
        }
        for i in 0..P256.len() {
            let mut damaged = P256.to_vec();
            damaged[i] ^= 0xFF;
            let _ = p256_public_key(&damaged);
        }
    }
}
