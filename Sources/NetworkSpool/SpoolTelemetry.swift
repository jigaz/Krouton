import Foundation

// MARK: - Host Entry Guard

/// Checks a host the user typed before Krouton connects to it: loopback, `.local` names and
/// private, link-local or unique-local addresses only, with no userinfo or query smuggling.
/// The address actually reached is checked again after connecting (`SpoolEndpointPolicy`).
public enum SpoolLANSecurityEngine {
    /// True when the host in `rawEndpoint` (with or without a scheme, port or path) passes the
    /// default `SpoolEndpointPolicy`: an allowed address literal, localhost or a .local name.
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

// MARK: - Burn Telemetry (kind-7 frames) and the Progress Filter

/// A burn's phase in a telemetry frame. The raw values are on the wire.
public enum SpoolTelemetryPhase: String, Codable, Sendable, Equatable {
    case idle             = "IDLE"
    case preheating       = "PREHEATING"
    case burningProgress = "BURNING_PROGRESS"
    case verifyingSectors   = "VERIFYING_SECTORS"
    case burnCompleted   = "BURN_COMPLETED"
    case burnFailed       = "BURN_FAILED"
    case cancelled        = "CANCELLED"
}

/// One telemetry frame from the server about a running job. The field names are on the wire.
public struct SpoolTelemetryPacket: Codable, Sendable, Equatable {
    /// The job, by the UUID the client gave it in `submit`.
    public let batchId: UUID
    /// The drive.
    public let driveId: String
    /// The phase.
    public let state: SpoolTelemetryPhase
    /// Progress, 0 to 1.
    public let fraction: Double
    /// The sector being written.
    public let currentLba: Int64
    /// Sectors to write.
    public let totalLba: Int64
    /// The write speed, as a multiple of 1x.
    public let effectiveSpeedX: Double
    /// The server's write buffer fill, 0 to 1.
    public let fifoFill: Double
    /// The drive's buffer fill, 0 to 1.
    public let driveBufferFill: Double
    /// Always 0 from Krouton Server today.
    public let c2Errors: Int
    /// Seconds left, as the server estimates.
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

/// Makes telemetry safe to show.
public enum SpoolTelemetrySanitizer {
    /// Clamps an incoming telemetry frame against the last state shown, so a late frame or a NaN
    /// or infinite value never makes progress go backwards, a finished burn look active again,
    /// or a buffer fill leave 0…1.
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

        // While burning, a frame that arrives late can't move progress backwards.
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
