import Darwin
import Foundation

// MARK: - IP Addresses

public enum SpoolIPAddress: Sendable, Equatable {
    case v4([UInt8])
    case v6([UInt8])

    public var bytes: [UInt8] {
        switch self {
        case .v4(let raw), .v6(let raw): raw
        }
    }

    public static func parse(_ literal: String) -> SpoolIPAddress? {
        var text = literal
        if text.hasPrefix("["), text.hasSuffix("]") { text = String(text.dropFirst().dropLast()) }
        if let octets = parseIPv4(text) { return .v4(octets) }
        let unzoned = text.split(separator: "%", maxSplits: 1, omittingEmptySubsequences: false).first.map(String.init) ?? text
        guard unzoned.contains(":") else { return nil }
        var storage = in6_addr()
        guard inet_pton(AF_INET6, unzoned, &storage) == 1 else { return nil }
        return .v6(withUnsafeBytes(of: storage) { Array($0) })
    }

    static func parseIPv4(_ text: String) -> [UInt8]? {
        let parts = text.split(separator: ".", omittingEmptySubsequences: false)
        guard parts.count == 4 else { return nil }
        var octets: [UInt8] = []
        for part in parts {
            guard (1...3).contains(part.count),
                  part.allSatisfy({ $0.isASCII && $0.isNumber }),
                  part.count == 1 || part.first != "0",
                  let value = UInt8(part) else { return nil }
            octets.append(value)
        }
        return octets
    }
}

// MARK: - CIDR Blocks

public struct SpoolCIDR: Sendable, Equatable {
    public let network: SpoolIPAddress
    public let prefixLength: Int

    public init?(_ text: String) {
        let pieces = text.split(separator: "/")
        guard pieces.count == 2,
              let address = SpoolIPAddress.parse(String(pieces[0])),
              let length = Int(pieces[1]),
              (0...(address.bytes.count * 8)).contains(length) else { return nil }
        self.network = address
        self.prefixLength = length
    }

    public func contains(_ address: SpoolIPAddress) -> Bool {
        let lhs = network.bytes
        let rhs = address.bytes
        guard lhs.count == rhs.count else { return false }
        var remaining = prefixLength
        for i in 0..<lhs.count where remaining > 0 {
            let take = min(8, remaining)
            let mask = UInt8(truncatingIfNeeded: 0xFF << (8 - take))
            guard lhs[i] & mask == rhs[i] & mask else { return false }
            remaining -= take
        }
        return true
    }
}

// MARK: - Verdicts

public enum SpoolAddressClass: String, Sendable, Equatable {
    case loopback
    case privateLAN
    case linkLocal
    case uniqueLocalIPv6
    case overlayCGNAT
    case trustedStudioRange
}

public enum SpoolEndpointDenial: Sendable, Equatable {
    case publicAddress
    case unspecifiedOrMulticast
    case translatedPublicAddress
    case unsupportedHostName
}

public enum SpoolAddressVerdict: Sendable, Equatable {
    case allowed(SpoolAddressClass)
    case denied(SpoolEndpointDenial)
}

public enum SpoolHostVerdict: Sendable, Equatable {
    case allowedLiteral(SpoolAddressClass)
    case resolveThenEvaluate
    case denied(SpoolEndpointDenial)
}

// MARK: - Endpoint Policy

public struct SpoolEndpointPolicy: Sendable, Equatable {
    public var allowsOverlayCGNAT: Bool
    public private(set) var trustedRanges: [SpoolCIDR]

    public init(allowsOverlayCGNAT: Bool = false, trustedRanges: [SpoolCIDR] = []) {
        self.allowsOverlayCGNAT = allowsOverlayCGNAT
        self.trustedRanges = trustedRanges.filter(Self.isAcceptableTrustedRange)
    }

    public static func isAcceptableTrustedRange(_ range: SpoolCIDR) -> Bool {
        switch range.network {
        case .v4: range.prefixLength >= 8
        case .v6: range.prefixLength >= 32
        }
    }

    static let builtIn: [(range: SpoolCIDR, kind: SpoolAddressClass)] = [
        (SpoolCIDR("127.0.0.0/8")!, .loopback),
        (SpoolCIDR("::1/128")!, .loopback),
        (SpoolCIDR("10.0.0.0/8")!, .privateLAN),
        (SpoolCIDR("172.16.0.0/12")!, .privateLAN),
        (SpoolCIDR("192.168.0.0/16")!, .privateLAN),
        (SpoolCIDR("169.254.0.0/16")!, .linkLocal),
        (SpoolCIDR("fe80::/10")!, .linkLocal),
        (SpoolCIDR("fc00::/7")!, .uniqueLocalIPv6)
    ]
    static let overlayCGNAT = SpoolCIDR("100.64.0.0/10")!
    static let ipv4Mapped = SpoolCIDR("::ffff:0:0/96")!
    static let neverAllowed = [
        SpoolCIDR("0.0.0.0/8")!, SpoolCIDR("224.0.0.0/4")!, SpoolCIDR("255.255.255.255/32")!,
        SpoolCIDR("::/128")!, SpoolCIDR("ff00::/8")!
    ]
    static let translatedPublic = [
        SpoolCIDR("64:ff9b::/96")!, SpoolCIDR("64:ff9b:1::/48")!, SpoolCIDR("2002::/16")!, SpoolCIDR("2001::/32")!
    ]

    public func evaluate(_ address: SpoolIPAddress) -> SpoolAddressVerdict {
        if Self.ipv4Mapped.contains(address) { return evaluate(.v4(Array(address.bytes.suffix(4)))) }
        if Self.neverAllowed.contains(where: { $0.contains(address) }) { return .denied(.unspecifiedOrMulticast) }
        if Self.translatedPublic.contains(where: { $0.contains(address) }) { return .denied(.translatedPublicAddress) }
        if let match = Self.builtIn.first(where: { $0.range.contains(address) }) { return .allowed(match.kind) }
        if allowsOverlayCGNAT, Self.overlayCGNAT.contains(address) { return .allowed(.overlayCGNAT) }
        if trustedRanges.contains(where: { $0.contains(address) }) { return .allowed(.trustedStudioRange) }
        return .denied(.publicAddress)
    }

    public func evaluate(host rawHost: String) -> SpoolHostVerdict {
        let host = rawHost.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if let address = SpoolIPAddress.parse(host) {
            switch evaluate(address) {
            case .allowed(let kind): return .allowedLiteral(kind)
            case .denied(let reason): return .denied(reason)
            }
        }
        let name = host.hasSuffix(".") ? String(host.dropLast()) : host
        let isLocalName = name == "localhost"
            || (name.hasSuffix(".local") && name.count > ".local".count)
        guard isLocalName, name.allSatisfy({ $0.isASCII && ($0.isLetter || $0.isNumber || $0 == "-" || $0 == ".") }) else {
            return .denied(.unsupportedHostName)
        }
        return .resolveThenEvaluate
    }
}
