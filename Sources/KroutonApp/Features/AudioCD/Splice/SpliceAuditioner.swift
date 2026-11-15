import SwiftUI
import AVFoundation
import AudioKit

@MainActor
public final class SpliceAudioAuditioner: ObservableObject {
    public static let shared = SpliceAudioAuditioner()
    @Published public var isPlaying: Bool = false
    @Published public var playheadProgress: Double = 0.0
    @Published public var activeTrackID: UUID? = nil
    @Published public var leadLagSeconds: Double = 3.0 // ±3s, ±5s, ±10s pre/post-roll

    private var playerOut: AVAudioPlayer?
    private var playerIn: AVAudioPlayer?
    private var timer: Timer?

    public func stop() {
        timer?.invalidate()
        timer = nil
        playerOut?.stop()
        playerIn?.stop()
        playerOut = nil
        playerIn = nil
        isPlaying = false
        activeTrackID = nil
        playheadProgress = 0.0
    }

    public func startTransitionAudition(
        trackID: UUID? = nil,
        outgoingURL: URL?,
        incomingURL: URL?,
        spec: KroutonTrackTransitionSpec
    ) {
        if isPlaying {
            stop()
            return
        }
        let preRoll: Double = max(1.0, min(15.0, leadLagSeconds))
        let postRoll: Double = max(1.0, min(15.0, leadLagSeconds))
        let zoneSec: Double = spec.isCrossfading
            ? max(0.5, min(30.0, spec.overlapSeconds))
            : max(0.0, min(4.0, spec.preGapSeconds))
        let totalDur = preRoll + zoneSec + postRoll

        if let outURL = outgoingURL, let pOut = try? AVAudioPlayer(contentsOf: outURL) {
            pOut.prepareToPlay()
            let tailNeeded = preRoll + (spec.isCrossfading ? zoneSec : 0.0)
            pOut.currentTime = max(0.0, pOut.duration - tailNeeded)
            pOut.volume = 1.0
            pOut.play()
            self.playerOut = pOut
        }

        if let inURL = incomingURL, let pIn = try? AVAudioPlayer(contentsOf: inURL) {
            pIn.prepareToPlay()
            pIn.currentTime = 0.0
            pIn.volume = 0.0
            self.playerIn = pIn
        }

        guard playerOut != nil || playerIn != nil else { return }
        isPlaying = true
        activeTrackID = trackID
        playheadProgress = 0.0
        let startTime = Date()

        timer = Timer.scheduledTimer(withTimeInterval: 1.0 / 30.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self, self.isPlaying else { return }
                let elapsed = Date().timeIntervalSince(startTime)
                if elapsed >= totalDur {
                    self.stop()
                    return
                }
                self.playheadProgress = min(1.0, max(0.0, elapsed / totalDur))

                let inStartSec = spec.isCrossfading ? preRoll : (preRoll + zoneSec)
                if elapsed >= inStartSec, let pIn = self.playerIn, !pIn.isPlaying {
                    pIn.play()
                }

                if spec.isCrossfading {
                    if elapsed < preRoll {
                        self.playerOut?.volume = 1.0
                        self.playerIn?.volume = 0.0
                    } else if elapsed <= preRoll + zoneSec {
                        let t = (elapsed - preRoll) / max(0.05, zoneSec)
                        self.playerOut?.volume = Float(min(1.0, max(0.0, spec.effectiveGainOut(at: t))))
                        self.playerIn?.volume = Float(min(1.0, max(0.0, spec.effectiveGainIn(at: t))))
                    } else {
                        self.playerOut?.stop()
                        self.playerIn?.volume = 1.0
                    }
                } else {
                    if elapsed >= preRoll { self.playerOut?.stop() }
                    if elapsed >= inStartSec { self.playerIn?.volume = 1.0 }
                }
            }
        }
    }
}
