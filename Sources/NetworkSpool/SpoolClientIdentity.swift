import CryptoKit
import Foundation
import Security

// MARK: - This Mac's Krouton Server Identity
//
// Two keys, both created on first use and kept in the login keychain:
//   * an Ed25519 identity, which signs every session (servers pin it at pairing), and
//   * a P-256 TLS key with a self-signed certificate. Network.framework needs a `SecIdentity` for
//     client authentication, so key and certificate live in the keychain; servers trust the key
//     by pin (SHA-256 of its X9.63 bytes), never by the certificate's names or dates.

public enum SpoolClientIdentityError: Error, Sendable, Equatable {
    case keychain(OSStatus)
    case keyGeneration(String)
    case certificate
}

public enum SpoolClientIdentity {
    static let service = "app.krouton.spool"
    static let identityAccount = "identity.ed25519"
    static let tlsKeyTag = Data("app.krouton.spool.tls-key".utf8)
    static let certificateLabel = "Krouton Burn Server Client"

    // MARK: - Ed25519 identity

    /// The Ed25519 identity, created and stored on first use.
    public static func signingKey() throws(SpoolClientIdentityError) -> Curve25519.Signing.PrivateKey {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: identityAccount,
            kSecReturnData as String: true
        ]
        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        if status == errSecSuccess, let raw = result as? Data,
           let key = try? Curve25519.Signing.PrivateKey(rawRepresentation: raw) {
            return key
        }
        guard status == errSecItemNotFound || status == errSecSuccess else { throw .keychain(status) }
        let key = Curve25519.Signing.PrivateKey()
        let add: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: identityAccount,
            kSecAttrLabel as String: "Krouton Burn Server Identity",
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly,
            kSecValueData as String: key.rawRepresentation
        ]
        let added = SecItemAdd(add as CFDictionary, nil)
        guard added == errSecSuccess else { throw .keychain(added) }
        return key
    }

    /// Deletes this device's Ed25519 identity, TLS key and certificate from the keychain. New ones
    /// are made on next use, so every Krouton Server has to be paired again.
    public static func forget() {
        let items: [[String: Any]] = [
            [kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: service, kSecAttrAccount as String: identityAccount],
            [kSecClass as String: kSecClassKey, kSecAttrApplicationTag as String: tlsKeyTag],
            [kSecClass as String: kSecClassCertificate, kSecAttrLabel as String: certificateLabel]
        ]
        for query in items { SecItemDelete(query as CFDictionary) }
    }

    // MARK: - TLS identity

    /// The TLS `SecIdentity` (P-256 key + self-signed certificate), created on first use.
    public static func tlsIdentity(deviceName: String) throws(SpoolClientIdentityError) -> SecIdentity {
        let key = try tlsPrivateKey()
        if let existing = existingCertificate() {
            if let identity = identity(for: existing) {
                return identity
            }
            // A certificate left from an older key: replace it.
            let query: [String: Any] = [kSecClass as String: kSecClassCertificate, kSecAttrLabel as String: certificateLabel]
            SecItemDelete(query as CFDictionary)
        }
        let certificate = try createCertificate(for: key, commonName: deviceName)
        guard let identity = identity(for: certificate) else { throw .keychain(errSecItemNotFound) }
        return identity
    }

    /// Pairs the stored certificate with its private key. macOS has a direct call; iPadOS finds
    /// the identity the keychain forms from a certificate and the key whose hash it matches.
    static func identity(for certificate: SecCertificate) -> SecIdentity? {
        #if os(macOS)
        var identity: SecIdentity?
        return SecIdentityCreateWithCertificate(nil, certificate, &identity) == errSecSuccess ? identity : nil
        #else
        let query: [String: Any] = [
            kSecClass as String: kSecClassIdentity,
            kSecAttrLabel as String: certificateLabel,
            kSecReturnRef as String: true
        ]
        var result: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess, let found = result,
              CFGetTypeID(found) == SecIdentityGetTypeID() else { return nil }
        return unsafeDowncast(found, to: SecIdentity.self)
        #endif
    }

    static func tlsPrivateKey() throws(SpoolClientIdentityError) -> SecKey {
        let query: [String: Any] = [
            kSecClass as String: kSecClassKey,
            kSecAttrApplicationTag as String: tlsKeyTag,
            kSecAttrKeyType as String: kSecAttrKeyTypeECSECPrimeRandom,
            kSecReturnRef as String: true
        ]
        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        if status == errSecSuccess, let found = result, CFGetTypeID(found) == SecKeyGetTypeID() {
            return unsafeDowncast(found, to: SecKey.self)
        }
        let attributes: [String: Any] = [
            kSecAttrKeyType as String: kSecAttrKeyTypeECSECPrimeRandom,
            kSecAttrKeySizeInBits as String: 256,
            kSecPrivateKeyAttrs as String: [
                kSecAttrIsPermanent as String: true,
                kSecAttrApplicationTag as String: tlsKeyTag,
                kSecAttrLabel as String: "Krouton Burn Server TLS Key"
            ] as [String: Any]
        ]
        var error: Unmanaged<CFError>?
        guard let key = SecKeyCreateRandomKey(attributes as CFDictionary, &error) else {
            throw .keyGeneration(error?.takeRetainedValue().localizedDescription ?? "unknown error")
        }
        return key
    }

    static func existingCertificate() -> SecCertificate? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassCertificate,
            kSecAttrLabel as String: certificateLabel,
            kSecReturnRef as String: true
        ]
        var result: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess, let found = result,
              CFGetTypeID(found) == SecCertificateGetTypeID() else { return nil }
        return unsafeDowncast(found, to: SecCertificate.self)
    }

    static func createCertificate(for key: SecKey, commonName: String) throws(SpoolClientIdentityError) -> SecCertificate {
        guard let publicKey = SecKeyCopyPublicKey(key),
              let x963 = SecKeyCopyExternalRepresentation(publicKey, nil) as Data? else { throw .certificate }
        let der = SpoolSelfSignedCertificate.make(publicKeyX963: x963, commonName: commonName,
                                                  serial: Data((0..<16).map { _ in UInt8.random(in: 0...255) })) { tbs in
            var error: Unmanaged<CFError>?
            return SecKeyCreateSignature(key, .ecdsaSignatureMessageX962SHA256, tbs as CFData, &error) as Data?
        }
        guard let der, let certificate = SecCertificateCreateWithData(nil, der as CFData) else { throw .certificate }
        let add: [String: Any] = [
            kSecClass as String: kSecClassCertificate,
            kSecValueRef as String: certificate,
            kSecAttrLabel as String: certificateLabel
        ]
        let status = SecItemAdd(add as CFDictionary, nil)
        guard status == errSecSuccess || status == errSecDuplicateItem else { throw .keychain(status) }
        return certificate
    }

    /// The key pin servers store for a certificate: SHA-256 over its X9.63 P-256 public key.
    public static func pin(of certificate: SecCertificate) -> Data? {
        guard let key = SecCertificateCopyKey(certificate),
              let raw = SecKeyCopyExternalRepresentation(key, nil) as Data?,
              raw.count == 65, raw.first == 0x04 else { return nil }
        return Data(SHA256.hash(data: raw))
    }
}
