import CryptoKit
import Foundation
import Network
import OpticalCore
import Security

// MARK: - Bonjour Discovery

public struct SpoolNodeCapabilities: OptionSet, Sendable, Hashable {
    public let rawValue: UInt32
    public init(rawValue: UInt32) { self.rawValue = rawValue }

    public static let writesCD = SpoolNodeCapabilities(rawValue: 1 << 0)
    public static let writesDVD = SpoolNodeCapabilities(rawValue: 1 << 1)
    public static let writesBD = SpoolNodeCapabilities(rawValue: 1 << 2)
    public static let rescueReads = SpoolNodeCapabilities(rawValue: 1 << 3)
    public static let rollingSpool = SpoolNodeCapabilities(rawValue: 1 << 4)
}

public enum SpoolBonjour {
    public enum TXTKey {
        public static let version = "txtvers"
        public static let protocolVersion = "pv"
        public static let nodeID = "id"
        public static let capabilities = "caps"
    }

    /// Reads the unauthenticated hints a server advertises. Used to label browse results and
    /// match them to paired servers, never to decide trust: the TLS key pin does that.
    public static func hints(from txt: NWTXTRecord) -> (nodeID: String?, protocolVersion: Int?, capabilities: SpoolNodeCapabilities) {
        let caps = txt[TXTKey.capabilities].flatMap { UInt32($0, radix: 16) } ?? 0
        return (txt[TXTKey.nodeID], txt[TXTKey.protocolVersion].flatMap { Int($0) }, SpoolNodeCapabilities(rawValue: caps))
    }
}

// MARK: - Zero-CA TLS (Pinned Mutual TLS 1.3)

public enum SpoolTLS {
    public static let exporterLabel = "EXPORTER-krouton-spool-session"

    /// Keychain P-256 SecIdentity Mutual TLS 1.3 with out-of-band X9.63 public-key SHA-256 pin verification.
    public static func mutualTLSParameters(
        localIdentity: SecIdentity,
        isPinnedPeerKey: @escaping @Sendable (Data) -> Bool,
        verificationQueue: DispatchQueue
    ) -> NWParameters? {
        guard let secIdentity = sec_identity_create(localIdentity) else { return nil }
        let tls = NWProtocolTLS.Options()
        let options = tls.securityProtocolOptions
        sec_protocol_options_set_min_tls_protocol_version(options, .TLSv13)
        sec_protocol_options_set_local_identity(options, secIdentity)
        sec_protocol_options_set_peer_authentication_required(options, true)
        sec_protocol_options_set_verify_block(options, { _, peerTrust, complete in
            let trust = sec_trust_copy_ref(peerTrust).takeRetainedValue()
            guard let chain = SecTrustCopyCertificateChain(trust) as? [SecCertificate],
                  let leaf = chain.first,
                  let key = SecCertificateCopyKey(leaf),
                  let raw = SecKeyCopyExternalRepresentation(key, nil) as Data?,
                  let p256 = try? P256.Signing.PublicKey(x963Representation: raw) else {
                complete(false)
                return
            }
            let pin = Data(SHA256.hash(data: p256.x963Representation))
            complete(isPinnedPeerKey(pin))
        }, verificationQueue)
        return configuredTCPParameters(tls: tls)
    }

    public static func exporterSecret(of connection: NWConnection) -> Data? {
        guard let metadata = connection.metadata(definition: NWProtocolTLS.definition) as? NWProtocolTLS.Metadata else {
            return nil
        }
        let secret = exporterLabel.withCString { label in
            sec_protocol_metadata_create_secret(metadata.securityProtocolMetadata, exporterLabel.utf8.count, label, 32)
        }
        return secret.map { Data($0 as DispatchData) }
    }

    private static func configuredTCPParameters(tls: NWProtocolTLS.Options) -> NWParameters {
        let tcp = NWProtocolTCP.Options()
        tcp.noDelay = true
        tcp.enableKeepalive = true
        tcp.keepaliveIdle = 5
        tcp.connectionTimeout = 5
        let parameters = NWParameters(tls: tls, tcp: tcp)
        parameters.includePeerToPeer = false
        parameters.prohibitedInterfaceTypes = [.cellular]
        return parameters
    }
}

// MARK: - Resolved-Address Check (DNS-rebinding defense)

extension SpoolIPAddress {
    public init?(reached endpoint: NWEndpoint?) {
        guard case .hostPort(let host, _)? = endpoint else { return nil }
        switch host {
        case .ipv4(let address): self = .v4(Array(address.rawValue))
        case .ipv6(let address): self = .v6(Array(address.rawValue))
        default: return nil
        }
    }
}

// MARK: - Transport Channel

public enum SpoolTransportError: Error, Sendable, Equatable {
    case closed
    case failed(String)
}

public protocol SpoolTransportChannel: Sendable {
    func send(_ bytes: Data) async throws(SpoolTransportError)
    func receive(maximumLength: Int) async throws(SpoolTransportError) -> Data
    func cancel() async
}

public actor NWSpoolChannel: SpoolTransportChannel {
    private let connection: NWConnection

    public init(_ connection: NWConnection) {
        self.connection = connection
    }

    public func send(_ bytes: Data) async throws(SpoolTransportError) {
        let failure: NWError? = await withCheckedContinuation { resume in
            connection.send(content: bytes, completion: .contentProcessed { error in resume.resume(returning: error) })
        }
        if let failure { throw .failed(failure.localizedDescription) }
    }

    public func receive(maximumLength: Int) async throws(SpoolTransportError) -> Data {
        let result: (Data?, Bool, NWError?) = await withCheckedContinuation { resume in
            connection.receive(minimumIncompleteLength: 1, maximumLength: maximumLength) { data, _, isComplete, error in
                resume.resume(returning: (data, isComplete, error))
            }
        }
        if let error = result.2 { throw .failed(error.localizedDescription) }
        if let data = result.0, !data.isEmpty { return data }
        if result.1 { return Data() }
        throw .closed
    }

    public func cancel() {
        connection.cancel()
    }
}
