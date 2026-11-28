import Darwin
import Foundation

// MARK: - IP Addresses

/// An IPv4 or IPv6 address as bytes.
public enum SpoolIPAddress: Sendable, Equatable {
    case v4([UInt8])
    case v6([UInt8])

    /// The address's 4 or 16 bytes.
    public var bytes: [UInt8] {
        switch self {
        case .v4(let raw), .v6(let raw): raw
        }
    }

    /// Parses a literal: dotted IPv4 (no leading zeros), or IPv6 with optional brackets and zone.
    /// Nil for anything else.
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

/// An address block in CIDR notation, such as 192.168.0.0/16.
public struct SpoolCIDR: Sendable, Equatable {
    /// The block's address.
    public let network: SpoolIPAddress
    /// Leading bits that must match.
    public let prefixLength: Int

    /// Parses "address/length"; nil when either part is invalid.
    public init?(_ text: String) {
        let pieces = text.split(separator: "/")
        guard pieces.count == 2,
              let address = SpoolIPAddress.parse(String(pieces[0])),
              let length = Int(pieces[1]),
              (0...(address.bytes.count * 8)).contains(length) else { return nil }
        self.network = address
        self.prefixLength = length
    }

    /// True when `address` is in the block (an IPv4 block never contains an IPv6 address).
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

/// Why an address is allowed.
public enum SpoolAddressClass: String, Sendable, Equatable {
    /// 127.0.0.0/8 or ::1.
    case loopback
    /// 10/8, 172.16/12 or 192.168/16.
    case privateLAN
    /// 169.254/16 or fe80::/10.
    case linkLocal
    /// fc00::/7.
    case uniqueLocalIPv6
    /// 100.64/10 (Tailscale and similar), when allowed.
    case overlayCGNAT
    /// A range the user added.
    case trustedStudioRange
}

/// Why an address or host name is refused.
public enum SpoolEndpointDenial: Sendable, Equatable {
    /// A public internet address.
    case publicAddress
    /// 0.0.0.0/8, multicast, broadcast, :: or ff00::/8.
    case unspecifiedOrMulticast
    /// NAT64, 6to4 or Teredo, which lead to public IPv4.
    case translatedPublicAddress
    /// A name other than localhost or a .local name.
    case unsupportedHostName
}

/// Whether an address may be connected to.
public enum SpoolAddressVerdict: Sendable, Equatable {
    case allowed(SpoolAddressClass)
    case denied(SpoolEndpointDenial)
}

/// Whether a host may be connected to, before DNS.
public enum SpoolHostVerdict: Sendable, Equatable {
    /// An address literal that is allowed.
    case allowedLiteral(SpoolAddressClass)
    /// localhost or a .local name: resolve it, then check the address reached.
    case resolveThenEvaluate
    /// Refused.
    case denied(SpoolEndpointDenial)
}

// MARK: - Endpoint Policy

/// Which addresses the client may connect to: the local network only, never the public internet, so
/// a hostile name or a typo can't send an image off the LAN.
public struct SpoolEndpointPolicy: Sendable, Equatable {
    /// Also allows 100.64.0.0/10 (Tailscale and similar overlays).
    public var allowsOverlayCGNAT: Bool
    /// Extra ranges the user trusts; ranges wider than /8 (IPv4) or /32 (IPv6) are dropped.
    public private(set) var trustedRanges: [SpoolCIDR]

    /// A policy; see `isAcceptableTrustedRange` for which ranges are kept.
    public init(allowsOverlayCGNAT: Bool = false, trustedRanges: [SpoolCIDR] = []) {
        self.allowsOverlayCGNAT = allowsOverlayCGNAT
        self.trustedRanges = trustedRanges.filter(Self.isAcceptableTrustedRange)
    }

    /// False for ranges wider than /8 (IPv4) or /32 (IPv6).
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

    /// Whether `address` may be connected to. An IPv4-mapped IPv6 address is judged as its IPv4
    /// address.
    public func evaluate(_ address: SpoolIPAddress) -> SpoolAddressVerdict {
        if Self.ipv4Mapped.contains(address) { return evaluate(.v4(Array(address.bytes.suffix(4)))) }
        if Self.neverAllowed.contains(where: { $0.contains(address) }) { return .denied(.unspecifiedOrMulticast) }
        if Self.translatedPublic.contains(where: { $0.contains(address) }) { return .denied(.translatedPublicAddress) }
        if let match = Self.builtIn.first(where: { $0.range.contains(address) }) { return .allowed(match.kind) }
        if allowsOverlayCGNAT, Self.overlayCGNAT.contains(address) { return .allowed(.overlayCGNAT) }
        if trustedRanges.contains(where: { $0.contains(address) }) { return .allowed(.trustedStudioRange) }
        return .denied(.publicAddress)
    }

    /// Whether `rawHost` may be connected to: an allowed address literal, or localhost or a .local
    /// name, which must be resolved and checked again.
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
