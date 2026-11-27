import Foundation

// MARK: - Minimal X.509 v3 Builder

/// Builds a self-signed X.509 v3 certificate for a P-256 key with ECDSA-SHA256, the only shape the
/// server accepts. `sign` receives the DER `TBSCertificate` and returns a DER ECDSA signature.
public enum SpoolSelfSignedCertificate {
    static let ecdsaWithSHA256: [UInt8] = [0x2A, 0x86, 0x48, 0xCE, 0x3D, 0x04, 0x03, 0x02]
    static let ecPublicKey: [UInt8] = [0x2A, 0x86, 0x48, 0xCE, 0x3D, 0x02, 0x01]
    static let prime256v1: [UInt8] = [0x2A, 0x86, 0x48, 0xCE, 0x3D, 0x03, 0x01, 0x07]
    static let commonNameOID: [UInt8] = [0x55, 0x04, 0x03]

    public static func make(publicKeyX963: Data, commonName: String, serial: Data, sign: (Data) -> Data?) -> Data? {
        guard publicKeyX963.count == 65, publicKeyX963.first == 0x04, !serial.isEmpty else { return nil }
        let algorithm = sequence(tlv(0x06, ecdsaWithSHA256))
        let name = sequence(tlv(0x31, sequence(tlv(0x06, commonNameOID) + tlv(0x0C, Array(commonName.prefix(64).utf8)))))
        let validity = sequence(tlv(0x17, Array("250101000000Z".utf8)) + tlv(0x18, Array("99991231235959Z".utf8)))
        let spki = sequence(sequence(tlv(0x06, ecPublicKey) + tlv(0x06, prime256v1)) + tlv(0x03, [0x00] + [UInt8](publicKeyX963)))
        let version = tlv(0xA0, tlv(0x02, [0x02]))
        let tbs = sequence(version + integer([UInt8](serial)) + algorithm + name + validity + name + spki)
        guard let signature = sign(Data(tbs)), !signature.isEmpty else { return nil }
        return Data(sequence(tbs + algorithm + tlv(0x03, [0x00] + [UInt8](signature))))
    }

    static func tlv(_ tag: UInt8, _ value: [UInt8]) -> [UInt8] {
        [tag] + length(value.count) + value
    }

    static func sequence(_ value: [UInt8]) -> [UInt8] {
        tlv(0x30, value)
    }

    /// Positive DER INTEGER: leading zeros trimmed, a 0x00 prefix when the high bit is set.
    static func integer(_ bytes: [UInt8]) -> [UInt8] {
        var b = Array(bytes.drop { $0 == 0 })
        if b.isEmpty { b = [0] }
        if b[0] & 0x80 != 0 { b.insert(0, at: 0) }
        return tlv(0x02, b)
    }

    static func length(_ n: Int) -> [UInt8] {
        if n < 0x80 { return [UInt8(n)] }
        var bytes: [UInt8] = []
        var v = n
        while v > 0 {
            bytes.insert(UInt8(v & 0xFF), at: 0)
            v >>= 8
        }
        return [0x80 | UInt8(bytes.count)] + bytes
    }
}
