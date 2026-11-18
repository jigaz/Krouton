import Foundation

// MARK: - Media Classes

public enum SpoolMediaClass: String, Sendable, CaseIterable {
    case cdAudio
    case cdData
    case dvdSingleLayer
    case dvdDualLayer
    case bdSingleLayer
    case bdDualLayer

    public var bytesPerSecondAt1x: Double {
        switch self {
        case .cdAudio: 176_400
        case .cdData: 153_600
        case .dvdSingleLayer, .dvdDualLayer: 1_385_000
        case .bdSingleLayer, .bdDualLayer: 4_495_500
        }
    }

    var alwaysPrestages: Bool { self == .cdAudio }
    var stallMultiplier: Double { self == .dvdDualLayer || self == .bdDualLayer ? 2 : 1 }
}

// MARK: - Link Measurement

public struct LinkThroughputStats: Sendable, Equatable {
    public var meanBytesPerSecond: Double
    public var standardDeviation: Double
    public var sampleCount: Int
    public var isWiFi: Bool

    public init(meanBytesPerSecond: Double, standardDeviation: Double, sampleCount: Int, isWiFi: Bool) {
        self.meanBytesPerSecond = meanBytesPerSecond
        self.standardDeviation = standardDeviation
        self.sampleCount = sampleCount
        self.isWiFi = isWiFi
    }

    public init(samples: [Double], isWiFi: Bool) {
        let finite = samples.filter { $0.isFinite && $0 >= 0 }
        let mean = finite.isEmpty ? 0 : finite.reduce(0, +) / Double(finite.count)
        let variance = finite.count < 2 ? 0 : finite.reduce(0) { $0 + ($1 - mean) * ($1 - mean) } / Double(finite.count - 1)
        self.init(meanBytesPerSecond: mean, standardDeviation: variance.squareRoot(), sampleCount: finite.count, isWiFi: isWiFi)
    }
}

// MARK: - Cutover Decision

public enum SpoolStoreAndForwardReason: Sendable, Equatable {
    case mediaPolicy
    case quickToPrestage
    case unmeasuredLink
    case rollingGainTooSmall
}

public enum SpoolCutoverDecision: Sendable, Equatable {
    case storeAndForward(reason: SpoolStoreAndForwardReason)
    case rollingWindow(leadBytes: Int64)
    case refuse(neededBytes: Int64, freeBytes: Int64)
}

public enum SpoolCutoverPolicy {
    public static let confidenceZ = 2.33
    public static let quickPrestageSeconds = 60.0
    public static let minimumSamples = 8
    public static let rollingCeilingFraction = 0.8
    public static let reserveBytes: Int64 = 2 * 1_073_741_824

    public static func stallBudgetSeconds(isWiFi: Bool) -> Double {
        isWiFi ? 15 : 3
    }

    public static func requiredLeadBytes(imageBytes: Double, burnRate: Double, conservativeLinkRate: Double,
                                         stallSeconds: Double, extentBytes: Double) -> Double {
        let outageAtStart = burnRate * stallSeconds
        let deficit = imageBytes * max(0, 1 - conservativeLinkRate / burnRate)
            + min(conservativeLinkRate, burnRate) * stallSeconds
        return min(imageBytes, max(outageAtStart, deficit) + extentBytes)
    }

    public static func decide(
        imageBytes: Int64,
        media: SpoolMediaClass,
        speedX: Double,
        link: LinkThroughputStats,
        freeBytes: Int64,
        extentBytes: Int64
    ) -> SpoolCutoverDecision {
        let needed = imageBytes + reserveBytes
        guard freeBytes >= needed else { return .refuse(neededBytes: needed, freeBytes: freeBytes) }
        if media.alwaysPrestages { return .storeAndForward(reason: .mediaPolicy) }
        guard link.sampleCount >= minimumSamples, link.meanBytesPerSecond > 0 else {
            return .storeAndForward(reason: .unmeasuredLink)
        }
        let size = Double(imageBytes)
        if size / link.meanBytesPerSecond <= quickPrestageSeconds { return .storeAndForward(reason: .quickToPrestage) }

        let burnRate = media.bytesPerSecondAt1x * max(1, speedX)
        let safeLink = max(0, link.meanBytesPerSecond - confidenceZ * link.standardDeviation)
        let stall = stallBudgetSeconds(isWiFi: link.isWiFi) * media.stallMultiplier
        let lead = requiredLeadBytes(imageBytes: size, burnRate: burnRate, conservativeLinkRate: safeLink,
                                     stallSeconds: stall, extentBytes: Double(extentBytes))
        guard lead < rollingCeilingFraction * size else { return .storeAndForward(reason: .rollingGainTooSmall) }
        return .rollingWindow(leadBytes: Int64(lead.rounded(.up)))
    }
}
