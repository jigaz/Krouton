import BurnKit
import Foundation
import OpticalCore
import os

// MARK: - VerifyHarness — Suite 30: Burn Set Scheduler (retry, isolation, spin-up arbitration)

/// An in-memory journal: the scheduler's events in order.
actor MemoryBurnJournal: BurnJournaling {
    private(set) var events: [BurnEvent] = []

    func append(_ event: BurnEvent) async throws {
        events.append(event)
    }
}

extension KroutonTestHarness {
    mutating func runVerifyBurnSetSchedulerSuite() {
        self.runSuite("30. Burn Set Scheduler: Retry Only What Failed, One Disc Per Drive, Staggered Spin-Up") { h in
            let discs = (1...4).map {
                FrozenDisc(index: $0, volumeLabel: "SET_D0\($0)", imageURL: URL(fileURLWithPath: "/tmp/krouton-set-disc\($0).iso"),
                           imageSHA256: "", imageBytes: 650_000_000)
            }
            let threeDiscSet = BurnSet(title: "Three", discs: Array(discs.prefix(3)))
            let instant: BusArbitrationState.Policy = {
                var policy = BusArbitrationState.Policy()
                policy.spinUpSpacing = .zero
                return policy
            }()

            // One drive, Disc 2 fails: Discs 1 and 3 still burn, and a retry of Disc 2 alone finishes the set.
            let flaky = ScriptedOpticalDrive(id: "solo", displayName: "Solo", script: [.succeed(), .failWrite(sense: "3/0C/00"), .succeed()])
            let first = Self.blocking {
                await BurnSetScheduler(progress: BurnSetProgress(set: threeDiscSet), drives: [flaky], journal: MemoryBurnJournal()).run()
            }
            h.check(Self.doneIndices(first) == [1, 3] && Self.failedIndices(first) == [2],
                    "A failure on Disc 2 of 3 must leave Discs 1 and 3 burned and only Disc 2 failed")
            let retryDrive = ScriptedOpticalDrive(id: "solo", displayName: "Solo", script: [.succeed()])
            let retried = Self.blocking {
                await BurnSetScheduler(progress: first, drives: [retryDrive], journal: MemoryBurnJournal()).run(only: [2])
            }
            let retryBurns = Self.blocking { await retryDrive.burnedImageURLs }
            h.check(Self.doneIndices(retried) == [1, 2, 3] && retryBurns == [discs[1].imageURL],
                    "run(only: [2]) must burn exactly Disc 2 once more and finish the set")

            // Two drives sharing four discs: every disc burns exactly once, on exactly one drive.
            let fast = ScriptedOpticalDrive(id: "fast", displayName: "Fast", maxWriteSpeedX: 24, script: [])
            let slow = ScriptedOpticalDrive(id: "slow", displayName: "Slow", maxWriteSpeedX: 8, script: [])
            let shared = Self.blocking {
                await BurnSetScheduler(progress: BurnSetProgress(set: BurnSet(title: "Four", discs: discs)),
                                       drives: [slow, fast], journal: MemoryBurnJournal(), spinUpPolicy: instant).run()
            }
            let burned = Self.blocking { await fast.burnedImageURLs + slow.burnedImageURLs }
            h.check(Self.doneIndices(shared) == [1, 2, 3, 4] && burned.count == 4 && Set(burned).count == 4,
                    "Two drives must never receive the same disc, and every disc must be burned once")

            // Spin-up arbitration: the second drive waits out the spacing, then gets the token on a timer
            // (no further event needed), instead of waiting for the first drive's whole disc.
            let spaced: BusArbitrationState.Policy = {
                var policy = BusArbitrationState.Policy()
                policy.spinUpSpacing = .milliseconds(300)
                return policy
            }()
            let order = Self.blocking { () -> [String] in
                let arbiter = BurnPowerAndBandwidthArbiter(policy: spaced)
                let a = DriveID("a"), b = DriveID("b")
                await arbiter.acquireSpinUp(for: a)
                await arbiter.reachedSteadyWriting(a)
                let started = ContinuousClock.now
                await arbiter.acquireSpinUp(for: b)
                let waited = ContinuousClock.now - started
                return [waited >= .milliseconds(250) && waited < .seconds(3) ? "spaced" : "wrong:\(waited)"]
            }
            h.check(order == ["spaced"], "A second drive must spin up after the spacing elapses while the first is still writing")

            // A blank smaller than the image is refused before anything is written, and the disc stays queued.
            let small = ScriptedOpticalDrive(id: "small", displayName: "Small", script: [.rejectBlank(capacityBytes: 100_000_000), .cancelAtPrompt])
            let refused = Self.blocking {
                await BurnSetScheduler(progress: BurnSetProgress(set: BurnSet(title: "One", discs: [discs[0]])),
                                       drives: [small], journal: MemoryBurnJournal()).run()
            }
            let smallBurns = Self.blocking { await small.burnedImageURLs }
            h.check(smallBurns.isEmpty && Self.doneIndices(refused).isEmpty && refused.remaining.count == 1,
                    "An undersized blank must never be written, and the disc must stay in the queue")
        }
    }

    static func doneIndices(_ progress: BurnSetProgress) -> [Int] {
        progress.jobs.compactMap { job in
            if case .done = job.state { return job.disc.index }
            return nil
        }
    }

    static func failedIndices(_ progress: BurnSetProgress) -> [Int] {
        progress.jobs.compactMap { job in
            if case .failed = job.state { return job.disc.index }
            return nil
        }
    }

    /// Runs async work to completion from the synchronous harness.
    static func blocking<T: Sendable>(_ work: @escaping @Sendable () async -> T) -> T {
        let result = OSAllocatedUnfairLock<T?>(initialState: nil)
        let done = DispatchSemaphore(value: 0)
        Task.detached {
            let value = await work()
            result.withLock { $0 = value }
            done.signal()
        }
        done.wait()
        guard let value = result.withLock({ $0 }) else { preconditionFailure("blocking work produced no value") }
        return value
    }
}
