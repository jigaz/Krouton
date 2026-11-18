import Foundation
import OpticalCore

// MARK: - Telemetry Sample & Pure Bus Arbitration State Machine

/// One buffer-health and write-speed reading from an active burner. NaN/Infinity values are sanitized.
public struct DriveBufferSample: Sendable, Equatable {
    public let drive: DriveID
    public let driveBufferFill: Double?
    public let hostFIFOFill: Double?
    public let effectiveSpeedX: Double

    public init(drive: DriveID, driveBufferFill: Double?, hostFIFOFill: Double?, effectiveSpeedX: Double) {
        func clampUnit(_ value: Double?) -> Double? {
            value.flatMap { $0.isFinite ? min(1.0, max(0.0, $0)) : nil }
        }
        self.drive = drive
        self.driveBufferFill = clampUnit(driveBufferFill)
        self.hostFIFOFill = clampUnit(hostFIFOFill)
        self.effectiveSpeedX = effectiveSpeedX.isFinite ? max(0.0, effectiveSpeedX) : 0.0
    }
}

public struct BusArbitrationState: Sendable, Equatable {
    public struct Policy: Sendable, Equatable {
        public var spinUpSpacing: Duration = .seconds(10)
        public var spinUpTimeout: Duration = .seconds(45)
        public var maxStarvationHold: Duration = .seconds(90)
        public var lowDriveBuffer: Double = 0.35
        public var fullHostFIFO: Double = 0.80
        public var speedSagRatio: Double = 0.60
        public var samplesToTrip: Int = 3
        public var samplesToClear: Int = 5

        public init() {}
    }

    public let policy: Policy
    public private(set) var queue: [DriveID] = []
    public private(set) var holder: DriveID?
    public private(set) var starving: Set<DriveID> = []
    private var holderSince: Duration = .zero
    private var lastGrant: Duration?
    private var starvingSince: Duration?
    private var strikes: [DriveID: Int] = [:]
    private var clears: [DriveID: Int] = [:]
    private var peakSpeed: [DriveID: Double] = [:]

    public init(policy: Policy = Policy()) {
        self.policy = policy
    }

    public mutating func request(_ drive: DriveID) {
        guard holder != drive, !queue.contains(drive) else { return }
        queue.append(drive)
    }

    /// Returns the drive allowed to begin lead-in/OPC at `now`, if spacing and bus health permit.
    public mutating func grant(at now: Duration) -> DriveID? {
        if holder != nil {
            guard now - holderSince >= policy.spinUpTimeout else { return nil }
            holder = nil
        }
        guard let next = queue.first else { return nil }
        if let last = lastGrant, now - last < policy.spinUpSpacing { return nil }
        if !starving.isEmpty, let since = starvingSince, now - since < policy.maxStarvationHold { return nil }
        queue.removeFirst()
        holder = next
        holderSince = now
        lastGrant = now
        return next
    }

    public mutating func reachedSteadyWriting(_ drive: DriveID) {
        if holder == drive { holder = nil }
    }

    public mutating func withdraw(_ drive: DriveID) {
        queue.removeAll { $0 == drive }
        if holder == drive { holder = nil }
        strikes[drive] = nil
        clears[drive] = nil
        peakSpeed[drive] = nil
        starving.remove(drive)
        if starving.isEmpty { starvingSince = nil }
    }

    public mutating func record(_ sample: DriveBufferSample, at now: Duration) {
        let peak = max(peakSpeed[sample.drive] ?? 0.0, sample.effectiveSpeedX)
        peakSpeed[sample.drive] = peak
        let busStarved: Bool
        if let driveFill = sample.driveBufferFill, let hostFill = sample.hostFIFOFill {
            busStarved = driveFill < policy.lowDriveBuffer && hostFill >= policy.fullHostFIFO
        } else {
            busStarved = peak > 0.0 && sample.effectiveSpeedX < peak * policy.speedSagRatio
        }
        if busStarved {
            clears[sample.drive] = 0
            strikes[sample.drive, default: 0] += 1
            if strikes[sample.drive, default: 0] >= policy.samplesToTrip,
               starving.insert(sample.drive).inserted,
               starvingSince == nil {
                starvingSince = now
            }
        } else {
            strikes[sample.drive] = 0
            clears[sample.drive, default: 0] += 1
            if clears[sample.drive, default: 0] >= policy.samplesToClear,
               starving.remove(sample.drive) != nil,
               starving.isEmpty {
                starvingSince = nil
            }
        }
    }
}

// MARK: - BurnPowerAndBandwidthArbiter Actor

public actor BurnPowerAndBandwidthArbiter {
    private var state: BusArbitrationState
    private var waiters: [DriveID: CheckedContinuation<Void, Never>] = [:]
    private let origin = ContinuousClock.now

    public init(policy: BusArbitrationState.Policy = .init()) {
        self.state = BusArbitrationState(policy: policy)
    }

    private var now: Duration { ContinuousClock.now - origin }

    public func acquireSpinUp(for drive: DriveID) async {
        await withTaskCancellationHandler {
            await withCheckedContinuation { (resume: CheckedContinuation<Void, Never>) in
                guard !Task.isCancelled else { return resume.resume() }
                state.request(drive)
                waiters[drive] = resume
                grantDue()
            }
        } onCancel: {
            Task { await self.withdraw(drive) }
        }
    }

    public func reachedSteadyWriting(_ drive: DriveID) {
        state.reachedSteadyWriting(drive)
        grantDue()
    }

    public func withdraw(_ drive: DriveID) {
        state.withdraw(drive)
        waiters.removeValue(forKey: drive)?.resume()
        grantDue()
    }

    public func record(_ sample: DriveBufferSample) {
        state.record(sample, at: now)
        grantDue()
    }

    private func grantDue() {
        while let granted = state.grant(at: now) {
            waiters.removeValue(forKey: granted)?.resume()
        }
    }
}
