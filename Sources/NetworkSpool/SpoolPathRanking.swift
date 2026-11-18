import Foundation

// MARK: - Multi-Homed Path Ranking (pure)

public enum SpoolLinkKind: Int, Sendable, Comparable, CaseIterable {
    case other = 0
    case wifi = 1
    case wiredEthernet = 2
    case thunderboltBridge = 3

    public static func < (lhs: Self, rhs: Self) -> Bool { lhs.rawValue < rhs.rawValue }

    public static func classify(isWiFi: Bool, isWired: Bool, interfaceName: String) -> SpoolLinkKind {
        if interfaceName.hasPrefix("bridge") { return .thunderboltBridge }
        if isWired { return .wiredEthernet }
        if isWiFi { return .wifi }
        return .other
    }
}

public struct SpoolPathCandidate: Sendable, Equatable {
    public let nodeID: String
    public let interfaceName: String
    public let kind: SpoolLinkKind
    public var measuredBytesPerSecond: Double?

    public init(nodeID: String, interfaceName: String, kind: SpoolLinkKind, measuredBytesPerSecond: Double? = nil) {
        self.nodeID = nodeID
        self.interfaceName = interfaceName
        self.kind = kind
        self.measuredBytesPerSecond = measuredBytesPerSecond
    }
}

public enum SpoolPathRanking {
    public static let switchHysteresis = 1.25

    public static func rank(_ candidates: [SpoolPathCandidate]) -> [SpoolPathCandidate] {
        candidates.sorted { lhs, rhs in
            switch (lhs.measuredBytesPerSecond, rhs.measuredBytesPerSecond) {
            case let (l?, r?) where l != r: return l > r
            case (.some, nil): return true
            case (nil, .some): return false
            default: break
            }
            if lhs.kind != rhs.kind { return lhs.kind > rhs.kind }
            return lhs.interfaceName < rhs.interfaceName
        }
    }

    public static func shouldSwitch(from current: SpoolPathCandidate, to best: SpoolPathCandidate) -> Bool {
        guard current != best else { return false }
        guard let challenger = best.measuredBytesPerSecond, let incumbent = current.measuredBytesPerSecond else {
            return best.kind > current.kind && current.measuredBytesPerSecond == nil
        }
        return challenger >= incumbent * switchHysteresis
    }
}
