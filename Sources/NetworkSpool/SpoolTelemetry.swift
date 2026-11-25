import Foundation

// MARK: - Host Entry Guard

/// Checks a host the user typed before Krouton connects to it: loopback, `.local` names and
/// private, link-local or unique-local addresses only, with no userinfo or query smuggling.
/// The address actually reached is checked again after connecting (`SpoolEndpointPolicy`).
public enum SpoolLANSecurityEngine {
    /// Validates that an endpoint host belongs strictly to loopback, mDNS (.local), or RFC-1918 / RFC-3927 private LAN ranges.
    public static func isAllowedLANEndpoint(_ rawEndpoint: String) -> Bool {
        let trimmed = rawEndpoint.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !trimmed.isEmpty else { return false }

        var hostPart = trimmed
        for prefix in ["http://", "https://", "ws://", "wss://"] {
            if hostPart.hasPrefix(prefix) {
                hostPart = String(hostPart.dropFirst(prefix.count))
                break
            }
        }
        // Strip path, query, or fragment so http://evil.com?.local cannot smuggle a fake suffix
        if let cutIdx = hostPart.firstIndex(where: { $0 == "/" || $0 == "?" || $0 == "#" }) {
            hostPart = String(hostPart[..<cutIdx])
        }
        // Reject userinfo (user@host)
        guard !hostPart.contains("@"), !hostPart.isEmpty else { return false }

        if hostPart.hasPrefix("[") {
            guard let closeBracket = hostPart.firstIndex(of: "]") else { return false }
            hostPart = String(hostPart[...closeBracket])
        } else if let colonIdx = hostPart.firstIndex(of: ":") {
            hostPart = String(hostPart[..<colonIdx])
        }

        let verdict: SpoolHostVerdict = SpoolEndpointPolicy().evaluate(host: hostPart)
        switch verdict {
        case .allowedLiteral, .resolveThenEvaluate:
            return true
        case .denied:
            return false
        }
    }
}

// MARK: - Burn Telemetry (kind-7 frames) & Monotonic Progress Filter
public enum SpoolTelemetryPhase: String, Codable, Sendable, Equatable {
    case idle             = "IDLE"
    case preheating       = "PREHEATING"
    case burningProgress = "BURNING_PROGRESS"
    case verifyingSectors   = "VERIFYING_SECTORS"
    case burnCompleted   = "BURN_COMPLETED"
    case burnFailed       = "BURN_FAILED"
    case cancelled        = "CANCELLED"
}

public struct SpoolTelemetryPacket: Codable, Sendable, Equatable {
    public let batchId: UUID
    public let driveId: String
    public let state: SpoolTelemetryPhase
    public let fraction: Double
    public let currentLba: Int64
    public let totalLba: Int64
    public let effectiveSpeedX: Double
    public let fifoFill: Double
    public let driveBufferFill: Double
    public let c2Errors: Int
    public let etaSeconds: Int

    public init(
        batchId: UUID,
        driveId: String,
        state: SpoolTelemetryPhase,
        fraction: Double,
        currentLba: Int64,
        totalLba: Int64,
        effectiveSpeedX: Double,
        fifoFill: Double,
        driveBufferFill: Double,
        c2Errors: Int,
        etaSeconds: Int
    ) {
        self.batchId = batchId
        self.driveId = driveId
        self.state = state
        self.fraction = fraction
        self.currentLba = currentLba
        self.totalLba = totalLba
        self.effectiveSpeedX = effectiveSpeedX
        self.fifoFill = fifoFill
        self.driveBufferFill = driveBufferFill
        self.c2Errors = c2Errors
        self.etaSeconds = etaSeconds
    }
}

public enum SpoolTelemetrySanitizer {
    /// Clamps and filters incoming WebSocket progress frames so out-of-order packets or NaN/Inf values
    /// never cause progress regressions, negative buffer fill, or division-by-zero in the UI.
    public static func sanitizeProgressTransition(
        previousState: SpoolTelemetryPhase,
        previousFraction: Double,
        incomingFrame: SpoolTelemetryPacket
    ) -> (state: SpoolTelemetryPhase, fraction: Double, fifoClamp: Double, driveClamp: Double) {
        let cleanFifo = incomingFrame.fifoFill.isFinite ? max(0.0, min(1.0, incomingFrame.fifoFill)) : 0.0
        let cleanDrive = incomingFrame.driveBufferFill.isFinite ? max(0.0, min(1.0, incomingFrame.driveBufferFill)) : 0.0
        let rawFrac = incomingFrame.fraction.isFinite ? max(0.0, min(1.0, incomingFrame.fraction)) : previousFraction

        // Terminal states (BURN_COMPLETED, BURN_FAILED, CANCELLED) cannot regress to BURNING_PROGRESS
        let isPrevTerminal = (previousState == .burnCompleted || previousState == .burnFailed || previousState == .cancelled)
        if isPrevTerminal && (incomingFrame.state == .burningProgress || incomingFrame.state == .preheating) {
            return (previousState, previousFraction, cleanFifo, cleanDrive)
        }

        // During monotonic active burn (BURNING_PROGRESS -> BURNING_PROGRESS), ignore late stale UDP/WS packets
        let monotonicFrac: Double
        if previousState == .burningProgress && incomingFrame.state == .burningProgress {
            monotonicFrac = max(previousFraction, rawFrac)
        } else if incomingFrame.state == .burnCompleted {
            monotonicFrac = 1.0
        } else {
            monotonicFrac = rawFrac
        }

        return (incomingFrame.state, monotonicFrac, cleanFifo, cleanDrive)
    }
}
