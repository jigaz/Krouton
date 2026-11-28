import Foundation
import OpticalCore

// MARK: - Buffer Samples and the Arbitration State

/// One buffer and write-speed reading from a burner. Fills are clamped to 0…1, and values that
/// aren't finite are dropped.
public struct DriveBufferSample: Sendable, Equatable {
    /// The drive the reading is from.
    public let drive: DriveID
    /// The drive's buffer fill, 0…1, when known.
    public let driveBufferFill: Double?
    /// The host-side write buffer's fill, 0…1, when known.
    public let hostFIFOFill: Double?
    /// The write speed, as a multiple of 1x.
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

/// Decides which drive may spin up and start writing next, so drives on one bus or power supply
/// don't all start at once. A drive asks with `request`, gets the token from `grant`, and gives it
/// back with `reachedSteadyWriting`. While any drive's buffer is starving, new spin-ups wait. Pure
/// state: time is passed in, so it is tested without a clock.
public struct BusArbitrationState: Sendable, Equatable {
    /// The timings and thresholds.
    public struct Policy: Sendable, Equatable {
        /// The least time between two spin-ups.
        public var spinUpSpacing: Duration = .seconds(10)
        /// How long a drive may hold the token before it is taken back.
        public var spinUpTimeout: Duration = .seconds(45)
        /// The longest a starving drive holds back new spin-ups.
        public var maxStarvationHold: Duration = .seconds(90)
        /// Below this drive buffer fill (with a full host buffer), a sample counts as starved.
        public var lowDriveBuffer: Double = 0.35
        /// At or above this host buffer fill, a low drive buffer means the bus is the bottleneck.
        public var fullHostFIFO: Double = 0.80
        /// Without buffer readings, a speed below this fraction of the drive's peak counts as
        /// starved.
        public var speedSagRatio: Double = 0.60
        /// Starved samples in a row before a drive counts as starving.
        public var samplesToTrip: Int = 3
        /// Healthy samples in a row before it no longer does.
        public var samplesToClear: Int = 5

        public init() {}
    }

    /// The timings and thresholds in use.
    public let policy: Policy
    /// Drives waiting to spin up, in order.
    public private(set) var queue: [DriveID] = []
    /// The drive spinning up now, if any.
    public private(set) var holder: DriveID?
    /// Drives whose buffers are starving.
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

    /// Puts a drive in line to spin up.
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

    /// Takes the token back from a drive that is writing steadily.
    public mutating func reachedSteadyWriting(_ drive: DriveID) {
        if holder == drive { holder = nil }
    }

    /// Removes a drive entirely: from the line, the token and the starvation counts.
    public mutating func withdraw(_ drive: DriveID) {
        queue.removeAll { $0 == drive }
        if holder == drive { holder = nil }
        strikes[drive] = nil
        clears[drive] = nil
        peakSpeed[drive] = nil
        starving.remove(drive)
        if starving.isEmpty { starvingSince = nil }
    }

    /// Counts a buffer reading towards the drive's starving or healthy streak.
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

// MARK: - Arbiter

/// `BusArbitrationState` behind an actor with a real clock, for `BurnSetScheduler`: a drive awaits
/// `acquireSpinUp` before it writes. Nothing calls `record` yet, so starvation never holds a
/// spin-up back (see PENDING_INTEGRATION.md).
public actor BurnPowerAndBandwidthArbiter {
    private var state: BusArbitrationState
    private var waiters: [DriveID: CheckedContinuation<Void, Never>] = [:]
    private var recheckScheduled = false
    private let origin = ContinuousClock.now

    public init(policy: BusArbitrationState.Policy = .init()) {
        self.state = BusArbitrationState(policy: policy)
    }

    private var now: Duration { ContinuousClock.now - origin }

    /// Waits until this drive may spin up. Returns at once when the task is cancelled.
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

    /// Gives the token back once the drive writes steadily.
    public func reachedSteadyWriting(_ drive: DriveID) {
        state.reachedSteadyWriting(drive)
        grantDue()
    }

    /// Removes a drive, waking it if it was waiting.
    public func withdraw(_ drive: DriveID) {
        state.withdraw(drive)
        waiters.removeValue(forKey: drive)?.resume()
        grantDue()
    }

    /// Records a buffer reading.
    public func record(_ sample: DriveBufferSample) {
        state.record(sample, at: now)
        grantDue()
    }

    private func grantDue() {
        while let granted = state.grant(at: now) {
            waiters.removeValue(forKey: granted)?.resume()
        }
        // Spacing and starvation holds expire with time, not with an event: while anyone is waiting,
        // look again shortly, or a second drive would wait until the first one finished its disc.
        if !waiters.isEmpty, !recheckScheduled {
            recheckScheduled = true
            Task { [weak self] in
                try? await Task.sleep(for: .milliseconds(500))
                await self?.recheck()
            }
        }
    }

    private func recheck() {
        recheckScheduled = false
        grantDue()
    }
}
