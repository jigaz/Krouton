// MARK: - endpoint.rs

//! Address policy for incoming and outgoing spool connections (`SpoolEndpointPolicy.swift`).
//!
//! The daemon applies `evaluate` to `TcpStream::peer_addr()` BEFORE the TLS handshake. It is
//! defence in depth: the real boundary is mutual TLS with pinned keys.

use std::net::{IpAddr, Ipv4Addr, Ipv6Addr};

#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum AddressClass {
    Loopback,
    PrivateLan,
    LinkLocal,
    UniqueLocalV6,
    OverlayCgnat,
    TrustedStudioRange,
}

#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum Denial {
    PublicAddress,
    UnspecifiedOrMulticast,
    TranslatedPublicAddress,
    UnsupportedHostName,
}

#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum AddressVerdict {
    Allowed(AddressClass),
    Denied(Denial),
}

#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum HostVerdict {
    AllowedLiteral(AddressClass),
    /// `localhost` or a `.local` name: resolve, then evaluate EVERY address actually connected to.
    ResolveThenEvaluate,
    Denied(Denial),
}

/// Strict literal parsing. Rust's `Ipv4Addr` parser already rejects leading zeros, so
/// "010.0.0.1" (octal 8.0.0.1 to classic resolvers) never parses. Brackets and an IPv6 "%zone"
/// suffix are stripped, as in Swift.
#[must_use]
pub fn parse_ip_literal(literal: &str) -> Option<IpAddr> {
    let text = literal.strip_prefix('[').and_then(|s| s.strip_suffix(']')).unwrap_or(literal);
    if let Ok(v4) = text.parse::<Ipv4Addr>() {
        return Some(IpAddr::V4(v4));
    }
    let unzoned = text.split('%').next().unwrap_or(text);
    unzoned.contains(':').then(|| unzoned.parse::<Ipv6Addr>().ok().map(IpAddr::V6)).flatten()
}

#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub struct Cidr {
    network: IpAddr,
    prefix: u8,
}

impl Cidr {
    #[must_use]
    pub fn parse(text: &str) -> Option<Self> {
        let (address, length) = text.split_once('/')?;
        let network = parse_ip_literal(address)?;
        let prefix: u8 = length.parse().ok()?;
        let max = if network.is_ipv4() { 32 } else { 128 };
        (prefix <= max).then_some(Self { network, prefix })
    }

    #[must_use]
    pub fn prefix(&self) -> u8 {
        self.prefix
    }

    #[must_use]
    pub fn contains(&self, address: IpAddr) -> bool {
        match (self.network, address) {
            (IpAddr::V4(net), IpAddr::V4(ip)) => {
                let mask = u32::MAX.checked_shl(32 - u32::from(self.prefix)).unwrap_or(0);
                u32::from(net) & mask == u32::from(ip) & mask
            }
            (IpAddr::V6(net), IpAddr::V6(ip)) => {
                let mask = u128::MAX.checked_shl(128 - u32::from(self.prefix)).unwrap_or(0);
                u128::from(net) & mask == u128::from(ip) & mask
            }
            _ => false,
        }
    }
}

const BUILT_IN: [(&str, AddressClass); 8] = [
    ("127.0.0.0/8", AddressClass::Loopback),
    ("::1/128", AddressClass::Loopback),
    ("10.0.0.0/8", AddressClass::PrivateLan),
    ("172.16.0.0/12", AddressClass::PrivateLan),
    ("192.168.0.0/16", AddressClass::PrivateLan),
    ("169.254.0.0/16", AddressClass::LinkLocal),
    ("fe80::/10", AddressClass::LinkLocal),
    ("fc00::/7", AddressClass::UniqueLocalV6), // includes Tailscale's fd7a:115c:a1e0::/48
];
const NEVER: [&str; 5] = ["0.0.0.0/8", "224.0.0.0/4", "255.255.255.255/32", "::/128", "ff00::/8"];
/// IPv6 forms that carry a public IPv4 address: NAT64 (well-known and local-use), 6to4, Teredo.
const TRANSLATED: [&str; 4] = ["64:ff9b::/96", "64:ff9b:1::/48", "2002::/16", "2001::/32"];
const OVERLAY_CGNAT: &str = "100.64.0.0/10";

fn any_contains(ranges: &[&str], address: IpAddr) -> bool {
    ranges.iter().filter_map(|r| Cidr::parse(r)).any(|c| c.contains(address))
}

#[derive(Clone, Debug, Default, PartialEq, Eq)]
pub struct EndpointPolicy {
    /// 100.64.0.0/10 is shared CGNAT space: Tailscale uses it, and so do ISPs. Opt-in only.
    pub allows_overlay_cgnat: bool,
    trusted: Vec<Cidr>,
}

impl EndpointPolicy {
    /// Over-wide ranges (shorter than /8 for IPv4, /32 for IPv6) are dropped: no "trust everything".
    #[must_use]
    pub fn new(allows_overlay_cgnat: bool, trusted: impl IntoIterator<Item = Cidr>) -> Self {
        let trusted = trusted.into_iter().filter(Self::is_acceptable_trusted_range).collect();
        Self { allows_overlay_cgnat, trusted }
    }

    /// At least /8 for IPv4 and /32 for IPv6.
    #[must_use]
    pub fn is_acceptable_trusted_range(range: &Cidr) -> bool {
        range.prefix >= if range.network.is_ipv4() { 8 } else { 32 }
    }

    #[must_use]
    pub fn trusted_ranges(&self) -> &[Cidr] {
        &self.trusted
    }

    /// The decision that matters, made on the address a connection actually came from or reached.
    #[must_use]
    pub fn evaluate(&self, address: IpAddr) -> AddressVerdict {
        if let IpAddr::V6(v6) = address
            && let Some(v4) = v6.to_ipv4_mapped()
        {
            return self.evaluate(IpAddr::V4(v4));
        }
        if any_contains(&NEVER, address) {
            return AddressVerdict::Denied(Denial::UnspecifiedOrMulticast);
        }
        if any_contains(&TRANSLATED, address) {
            return AddressVerdict::Denied(Denial::TranslatedPublicAddress);
        }
        if let Some((_, class)) =
            BUILT_IN.iter().find(|(range, _)| Cidr::parse(range).is_some_and(|c| c.contains(address)))
        {
            return AddressVerdict::Allowed(*class);
        }
        if self.allows_overlay_cgnat && any_contains(&[OVERLAY_CGNAT], address) {
            return AddressVerdict::Allowed(AddressClass::OverlayCgnat);
        }
        if self.trusted.iter().any(|c| c.contains(address)) {
            return AddressVerdict::Allowed(AddressClass::TrustedStudioRange);
        }
        AddressVerdict::Denied(Denial::PublicAddress)
    }

    /// Pre-flight on a typed host. Only IP literals, `localhost` and `.local` names pass; `.lan` and
    /// every other DNS name are refused, because a name can be rebound after any check on it.
    #[must_use]
    pub fn evaluate_host(&self, raw: &str) -> HostVerdict {
        let host = raw.trim().to_ascii_lowercase();
        if let Some(address) = parse_ip_literal(&host) {
            return match self.evaluate(address) {
                AddressVerdict::Allowed(class) => HostVerdict::AllowedLiteral(class),
                AddressVerdict::Denied(reason) => HostVerdict::Denied(reason),
            };
        }
        let name = host.strip_suffix('.').unwrap_or(&host);
        let is_local = name == "localhost" || (name.len() > ".local".len() && name.ends_with(".local"));
        let clean = name.chars().all(|c| c.is_ascii_alphanumeric() || c == '-' || c == '.');
        if is_local && clean {
            HostVerdict::ResolveThenEvaluate
        } else {
            HostVerdict::Denied(Denial::UnsupportedHostName)
        }
    }
}
