//! TLS 1.3 with mutual authentication and no certificate authority.
//!
//! * The server presents its self-signed P-256 certificate; Krouton trusts it by key pin.
//! * The client must present a P-256 certificate and prove possession of its key (rustls checks
//!   the CertificateVerify signature). Whether that key is *trusted* is decided after the
//!   handshake by the session: a pinned, paired Mac proceeds; an unknown key may only pair, and
//!   only while the operator has opened a pairing window.
//! * No session resumption or tickets: every connection does a full handshake with fresh proof.

use crate::crypto::{TLS_CERT_FILE, TLS_KEY_FILE};
use rustls::client::danger::HandshakeSignatureValid;
use rustls::crypto::{CryptoProvider, WebPkiSupportedAlgorithms};
use rustls::pki_types::{CertificateDer, PrivateKeyDer, PrivatePkcs8KeyDer, UnixTime};
use rustls::server::danger::{ClientCertVerified, ClientCertVerifier};
use rustls::{DigitallySignedStruct, DistinguishedName, SignatureScheme};
use std::path::Path;
use std::sync::Arc;

/// Accepts any client certificate that carries a P-256 key; trust is decided by pin afterwards.
#[derive(Debug)]
pub struct AnyP256ClientKey {
    algorithms: WebPkiSupportedAlgorithms,
}

impl ClientCertVerifier for AnyP256ClientKey {
    fn offer_client_auth(&self) -> bool {
        true
    }

    fn client_auth_mandatory(&self) -> bool {
        true
    }

    fn root_hint_subjects(&self) -> &[DistinguishedName] {
        &[]
    }

    fn verify_client_cert(
        &self,
        end_entity: &CertificateDer<'_>,
        _intermediates: &[CertificateDer<'_>],
        _now: UnixTime,
    ) -> Result<ClientCertVerified, rustls::Error> {
        if server_core::x509::p256_public_key(end_entity).is_some() {
            Ok(ClientCertVerified::assertion())
        } else {
            Err(rustls::Error::InvalidCertificate(rustls::CertificateError::BadEncoding))
        }
    }

    fn verify_tls12_signature(
        &self,
        _message: &[u8],
        _cert: &CertificateDer<'_>,
        _dss: &DigitallySignedStruct,
    ) -> Result<HandshakeSignatureValid, rustls::Error> {
        // TLS 1.2 is disabled in the server config; refuse outright if it is ever reached.
        Err(rustls::Error::PeerIncompatible(rustls::PeerIncompatible::Tls12NotOffered))
    }

    fn verify_tls13_signature(
        &self,
        message: &[u8],
        cert: &CertificateDer<'_>,
        dss: &DigitallySignedStruct,
    ) -> Result<HandshakeSignatureValid, rustls::Error> {
        rustls::crypto::verify_tls13_signature(message, cert, dss, &self.algorithms)
    }

    fn supported_verify_schemes(&self) -> Vec<SignatureScheme> {
        vec![SignatureScheme::ECDSA_NISTP256_SHA256]
    }
}

/// Builds the server's rustls configuration from the key files in `state_dir`.
pub fn server_config(state_dir: &Path) -> Result<Arc<rustls::ServerConfig>, String> {
    let cert =
        std::fs::read(state_dir.join(TLS_CERT_FILE)).map_err(|e| format!("Could not read {TLS_CERT_FILE}: {e}"))?;
    let key = std::fs::read(state_dir.join(TLS_KEY_FILE)).map_err(|e| format!("Could not read {TLS_KEY_FILE}: {e}"))?;
    let provider: Arc<CryptoProvider> = Arc::new(rustls::crypto::ring::default_provider());
    let verifier = Arc::new(AnyP256ClientKey { algorithms: provider.signature_verification_algorithms });
    let mut config = rustls::ServerConfig::builder_with_provider(Arc::clone(&provider))
        .with_protocol_versions(&[&rustls::version::TLS13])
        .map_err(|e| e.to_string())?
        .with_client_cert_verifier(verifier)
        .with_single_cert(vec![CertificateDer::from(cert)], PrivateKeyDer::Pkcs8(PrivatePkcs8KeyDer::from(key)))
        .map_err(|e| format!("The TLS key and certificate do not match: {e}"))?;
    config.session_storage = Arc::new(rustls::server::NoServerSessionStorage {});
    config.send_tls13_tickets = 0;
    Ok(Arc::new(config))
}

/// The server's own key pin (what the Krouton app stores when pairing).
pub fn server_pin(state_dir: &Path) -> Result<[u8; 32], String> {
    let cert = std::fs::read(state_dir.join(TLS_CERT_FILE)).map_err(|e| e.to_string())?;
    server_core::x509::certificate_pin(&cert).ok_or_else(|| "The TLS certificate does not hold a P-256 key".into())
}
