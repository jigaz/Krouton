import Foundation

// MARK: - Telemetry Conflation (node side)

public struct SpoolTelemetryConflator: Sendable {
    private var latest: [String: SpoolTelemetryPacket] = [:]
    private var order: [String] = []

    public init() {}

    public mutating func offer(_ packet: SpoolTelemetryPacket) {
        if let existing = latest[packet.driveId] {
            if Self.isTerminal(existing.state), !Self.isTerminal(packet.state) { return }
        } else {
            order.append(packet.driveId)
        }
        latest[packet.driveId] = packet
    }

    public mutating func drain() -> [SpoolTelemetryPacket] {
        let pending = order.compactMap { latest[$0] }
        latest.removeAll(keepingCapacity: true)
        order.removeAll(keepingCapacity: true)
        return pending
    }

    static func isTerminal(_ phase: SpoolTelemetryPhase) -> Bool {
        phase == .burnCompleted || phase == .burnFailed || phase == .cancelled
    }
}
