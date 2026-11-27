import AudioKit
import SwiftUI

// MARK: - SpliceWaveformCanvas — VoiceOver

extension SpliceWaveformCanvas {
    /// "2.5-second crossfade: equal-power fade out, S-curve fade in" or "2-second pause".
    nonisolated static func spokenDescription(_ spec: KroutonTrackTransitionSpec, mode: SpliceTransitionMode) -> String {
        switch mode {
        case .crossfade:
            let curve = { (c: KroutonCrossfadeCurve) in c.rawValue.components(separatedBy: " (").first ?? c.rawValue }
            return String(format: "%.1f-second crossfade: %@ fade out, %@ fade in",
                          spec.overlapSeconds, curve(spec.fadeOutCurve), curve(spec.fadeInCurve))
        case .gap:
            return String(format: "%.1f-second pause", spec.preGapSeconds)
        case .gapless:
            return "Gapless: the next track starts straight away"
        }
    }
}
