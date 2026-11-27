import AudioKit
import BurnKit
import CryptoKit
import Foundation
import Observation
import OpticalCore
import os

// MARK: - Observation Granularity Probes (var + WritableKeyPath vs let + ReferenceWritableKeyPath)

@Observable
final class VerifyProbeLeaf {
    var a: Int = 0
    var b: Int = 0
}

@Observable
@dynamicMemberLookup
final class VerifyProbeCoarseStore {
    var leaf = VerifyProbeLeaf()
    subscript<T>(dynamicMember keyPath: WritableKeyPath<VerifyProbeLeaf, T>) -> T {
        get { leaf[keyPath: keyPath] }
        set { leaf[keyPath: keyPath] = newValue }
    }
}

@Observable
@dynamicMemberLookup
final class VerifyProbeFineStore {
    let leaf = VerifyProbeLeaf()
    subscript<T>(dynamicMember keyPath: ReferenceWritableKeyPath<VerifyProbeLeaf, T>) -> T {
        get { leaf[keyPath: keyPath] }
        set { leaf[keyPath: keyPath] = newValue }
    }
}

// MARK: - VerifyHarness — Peer Agent Synthesis Suites (Q1–Q6)

extension KroutonTestHarness {
    static func observationNotifiesReader(_ read: () -> Void, after write: () -> Void) -> Bool {
        let fired = OSAllocatedUnfairLock(initialState: false)
        withObservationTracking(read) {
            fired.withLock { $0 = true }
        }
        write()
        return fired.withLock { $0 }
    }

    mutating func runVerifyPeerAgentSynthesisSuites() {
        runVerifyLateBindingAndObservationSuites()
        runVerifyCloneStagerBusAndAudioSuites()
        runVerifyDistributedSpoolSuite()
    }

    private mutating func runVerifyLateBindingAndObservationSuites() {
        self.runSuite("23. Late-Binding BurnClaimLedger & Non-Stranding Pool") { h in
            let dFast = DriveID("b1-24x")
            let dSlow = DriveID("b2-10x")
            var ledger = BurnClaimLedger(discs: Array(1...7), drivesFastestFirst: [dFast, dSlow])
            _ = ledger.offer(to: dFast)
            _ = ledger.offer(to: dSlow) // Burner 2 peeks Disc 2, but its tray is never touched
            for _ in 1...7 {
                _ = ledger.offer(to: dFast)
                let committed = ledger.commit(drive: dFast)
                h.check(committed != nil, "Burner 1 must always be able to commit the next disc")
                ledger.release(drive: dFast, succeeded: true, requeue: false)
            }
            h.check(ledger.isDrained && ledger.finished.sorted() == Array(1...7),
                    "An untouched Burner 2 tray must never hold Disc 2 hostage: Burner 1 completes all 7 discs")

            var race = BurnClaimLedger(discs: [1, 2], drivesFastestFirst: [dFast, dSlow])
            _ = race.offer(to: dFast)
            _ = race.offer(to: dSlow)
            let c1 = race.commit(drive: dFast)
            let c2 = race.commit(drive: dSlow)
            h.check(c1 != nil && c2 != nil && c1 != c2, "Simultaneous commits across two drives must never receive the same disc")
        }

        self.runSuite("24. Leaf-Granular @Observable Forwarding (let Sub-Store + ReferenceWritableKeyPath)") { h in
            let coarse = VerifyProbeCoarseStore()
            h.check(Self.observationNotifiesReader({ _ = coarse.b }, after: { coarse.a = 1 }),
                    "Baseline: var sub-store + WritableKeyPath falsely invalidates readers of sibling leaves")
            let fine = VerifyProbeFineStore()
            h.check(!Self.observationNotifiesReader({ _ = fine.b }, after: { fine.a = 1 }),
                    "let sub-store + ReferenceWritableKeyPath must NOT invalidate readers of sibling leaves")
            h.check(Self.observationNotifiesReader({ _ = fine.a }, after: { fine.a = 2 }),
                    "let sub-store + ReferenceWritableKeyPath must invalidate readers of the mutated leaf")
        }
    }

    private mutating func runVerifyCloneStagerBusAndAudioSuites() {
        self.runSuite("25. APFS fclonefileat CoW Staging, In-Place Edit Isolation & BusArbitrationState") { h in
            let cloneTmp = FileManager.default.temporaryDirectory.appendingPathComponent("KroutonCloneVerify_\(UUID().uuidString)")
            defer { try? FileManager.default.removeItem(at: cloneTmp) }
            try? FileManager.default.createDirectory(at: cloneTmp, withIntermediateDirectories: true)
            let cloneSrc = cloneTmp.appendingPathComponent("source.bin")
            let original = Data(repeating: 0xAB, count: 256 * 1024)
            try? original.write(to: cloneSrc)
            let cloneDst = cloneTmp.appendingPathComponent("stage/source.bin")
            if let staged = try? BurnSetStager.stageAndHash(from: cloneSrc, to: cloneDst) {
                let expected = SHA256.hash(data: original).map { String(format: "%02x", $0) }.joined()
                h.check(staged.method == .clonedOnAPFS && staged.sha256Hex == expected && staged.byteCount == Int64(original.count),
                        "Same-volume APFS staging must use fclonefileat and hash the staged clone")
                if let writer = try? FileHandle(forWritingTo: cloneSrc) {
                    try? writer.write(contentsOf: Data([0x00]))
                    try? writer.close()
                }
                let afterEditData = (try? Data(contentsOf: cloneDst)) ?? Data()
                let frozenHash = SHA256.hash(data: afterEditData).map { String(format: "%02x", $0) }.joined()
                h.check(frozenHash == expected, "In-place mutation of source file after staging must not alter the frozen APFS clone")
            } else {
                h.check(false, "BurnSetStager.stageAndHash must succeed in temporary directory")
            }

            let dA = DriveID("usb-24x")
            let dB = DriveID("usb-10x")
            let dC = DriveID("usb-4x")
            var bus = BusArbitrationState()
            bus.request(dA)
            bus.request(dB)
            bus.request(dC)
            h.check(bus.grant(at: .zero) == dA && bus.grant(at: .seconds(1)) == nil,
                    "First burner spins up alone; remaining burners wait during lead-in/OPC")
            bus.reachedSteadyWriting(dA)
            h.check(bus.grant(at: .seconds(5)) == nil && bus.grant(at: .seconds(10)) == dB,
                    "Second burner waits out the 10s stagger window after first burner reaches steady writing")
            h.check(bus.grant(at: .seconds(56)) == dC,
                    "A burner stuck in calibration releases the spin-up token after spinUpTimeout (45s)")

            var starved = BusArbitrationState()
            let dry = DriveBufferSample(drive: dA, driveBufferFill: 0.10, hostFIFOFill: 0.95, effectiveSpeedX: 12.0)
            for i in 0..<3 { starved.record(dry, at: .seconds(i)) }
            starved.request(dB)
            h.check(starved.grant(at: .seconds(20)) == nil,
                    "Arbiter must hold new spin-ups while an active burner's buffer drains with a full host FIFO")
            let healthy = DriveBufferSample(drive: dA, driveBufferFill: 0.90, hostFIFOFill: 0.90, effectiveSpeedX: 16.0)
            for i in 0..<5 { starved.record(healthy, at: .seconds(21 + i)) }
            h.check(starved.grant(at: .seconds(30)) == dB, "Arbiter must resume spin-up grants after 5 healthy buffer samples")
        }

        self.runSuite("26. Lock-Free CrossfadeParameterMailbox, Disc-Break Suppression & Render Parity") { h in
            let spec = KroutonTrackTransitionSpec(
                overlapSeconds: 2.0,
                fadeOutCurve: .sCurveHermite,
                fadeInCurve: .equalPower,
                curveTension: 0.4,
                outgoingTrimDB: -3.0,
                incomingTrimDB: 1.5,
                fadeOutMidTrim: 0.1,
                fadeInMidTrim: -0.1
            )
            let params = CrossfadeRenderParams(spec: spec, sampleRate: 44_100, suppressedAtDiscBoundary: false)
            let maxDrift = (0...100).map { Double($0) / 100.0 }.map { t -> Double in
                let g = params.gains(at: t)
                return max(abs(g.out - spec.effectiveGainOut(at: t)), abs(g.in - spec.effectiveGainIn(at: t)))
            }.max() ?? 1.0
            h.check(maxDrift < 1e-12, "Real-time CrossfadeRenderParams.gains must match KroutonTrackTransitionSpec.effectiveGain* to < 1e-12")

            let suppressed = CrossfadeRenderParams(spec: spec, sampleRate: 44_100, suppressedAtDiscBoundary: true)
            h.check(suppressed.overlapFrames == 0, "Crossfade spilling across a physical disc boundary must suppress overlapFrames to 0")

            let mailbox = CrossfadeParameterMailbox(params)
            let first = mailbox.exchange(lastSeen: 0, playheadFrame: 0)
            h.check(first?.generation == 1 && mailbox.exchange(lastSeen: 1, playheadFrame: 64) == nil,
                    "Render thread must copy parameters only when generation advances")
            var dragged = params
            dragged.overlapFrames = 44_100
            mailbox.publish(dragged)
            h.check(mailbox.exchange(lastSeen: 1, playheadFrame: 128)?.params.overlapFrames == 44_100 && mailbox.playheadFrame == 128,
                    "MainActor slider update must reach the next render exchange without blocking and report playheadFrame")
            var fourPointSpec = KroutonTrackTransitionSpec(
                overlapSeconds: 2.5,
                fadeOutMidTrim: 0.15,
                fadeOutThreeQuarterTrim: -0.20,
                fadeInQuarterTrim: -0.15,
                fadeInMidTrim: 0.22
            )
            let geom5s = SpliceCanvasGeometry(size: CGSize(width: 800, height: 180), spec: fourPointSpec, horizontalZoom: 3.0)
            h.check(abs(geom5s.effectiveSpanSeconds - 5.0) < 1e-6, "Crossfade 3.0x default zoom must show an exact 5.0-second total viewport")
            h.check(geom5s.fadeOutMidHandle != nil && geom5s.fadeOutQ3Handle != nil && geom5s.fadeInQ1Handle != nil && geom5s.fadeInMidHandle != nil,
                    "All 4 independent quarter-point Bezier diamond handles (1/4 & 3/4 on Fade-Out and Fade-In) must spawn when trims are active")
            fourPointSpec.fadeOutMidTrim = nil
            fourPointSpec.fadeOutThreeQuarterTrim = nil
            fourPointSpec.fadeInQuarterTrim = nil
            fourPointSpec.fadeInMidTrim = nil
            let resetGeom = SpliceCanvasGeometry(size: CGSize(width: 800, height: 180), spec: fourPointSpec, horizontalZoom: 3.0)
            h.check(resetGeom.fadeOutMidHandle == nil && resetGeom.fadeOutQ3Handle == nil && resetGeom.fadeInQ1Handle == nil && resetGeom.fadeInMidHandle == nil,
                    "Resetting quarter-point trims to nil must hide all 4 quarter-point handles")
        }
    }
}
