import AVFoundation
import AudioToolbox
import Foundation
import SwiftUI

// MARK: - Composable Acoustic Recipe

/// A composable, hashable acoustic recipe that unifies procedural synthesis, macOS system `.aiff`
/// audio files, and real-time DSP transformations (time-reversal, pitch/speed resampling,
/// ring modulation, and bitcrushing) under a single cacheable value type.
public struct KroutonAcousticCue: Hashable, Sendable {

    /// The underlying audio generator source.
    public enum Source: Hashable, Sendable {
        /// Built-in procedural waveforms synthesized mathematically in RAM.
        case procedural(ProceduralPreset)
        /// Any macOS system sound located in `/System/Library/Sounds/<name>.aiff`.
        case osSound(String)
        /// Delegates directly to the user's preferred macOS system alert beep.
        case systemAlert
    }

    /// Built-in zero-file mathematical synthesis presets tailored for Krouton's studio & bakery UX.
    public enum ProceduralPreset: String, Hashable, Sendable, CaseIterable {
        /// 45ms 1046.5Hz (C6) tactile click-pip when staging files or disc images.
        case stagedPip
        /// Two-step 880Hz -> 1318.5Hz (A5 -> E6) studio calibration telemetry blip.
        case calibrationNotice
        /// Warm metallic B5 + F#6 + B6 overtone "Toaster Ding" chord for completed burns/rips.
        case toasterDing
        /// Dual-pulse low harmonic buzzer (165Hz/220Hz/330Hz) for rejected drops or burn-lock guards.
        case burntToastGuard
    }

    /// Unified Digital Signal Processing (DSP) parameters applied to any `Source`.
    public struct DSPConfig: Hashable, Sendable {
        /// Playback speed & pitch multiplier (`1.0` = original, `2.0` = +1 octave / 2x speed, `0.5` = -1 octave).
        public var rate: Double = 1.0
        /// Reverses the temporal sample order before envelope shaping.
        public var reversed: Bool = false
        /// Linear output amplitude multiplier (`0.0 ... 2.0`).
        public var gain: Float = 0.85
        /// Optional ring-modulation carrier frequency in Hz (`0` disables ring modulation).
        public var ringModHz: Double = 0.0
        /// Optional bit-depth quantization (`1 ... 16`; `0` disables bitcrushing).
        public var crushBits: Int = 0

        public init(
            rate: Double = 1.0,
            reversed: Bool = false,
            gain: Float = 0.85,
            ringModHz: Double = 0.0,
            crushBits: Int = 0
        ) {
            self.rate = max(0.1, min(8.0, rate))
            self.reversed = reversed
            self.gain = max(0.0, min(2.0, gain))
            self.ringModHz = max(0.0, ringModHz)
            self.crushBits = max(0, min(16, crushBits))
        }
    }

    /// Maps the acoustic cue to a synchronized macOS Force Touch trackpad haptic response.
    public enum HapticRole: Hashable, Sendable {
        case impact, success, warning
    }

    public var source: Source
    public var dsp: DSPConfig
    public var hapticRole: HapticRole

    public init(source: Source, dsp: DSPConfig = DSPConfig(), hapticRole: HapticRole = .impact) {
        self.source = source
        self.dsp = dsp
        self.hapticRole = hapticRole
    }

    // MARK: - Canonical Semantic Presets

    /// Tactile 45ms studio pip when files or disc images are accepted into the staging rack.
    public static let staged = KroutonAcousticCue(
        source: .procedural(.stagedPip),
        dsp: DSPConfig(gain: 0.35),
        hapticRole: .impact
    )

    /// Two-tone 880Hz -> 1318.5Hz studio calibration pip for status checks and telemetry tests.
    public static let notice = KroutonAcousticCue(
        source: .procedural(.calibrationNotice),
        dsp: DSPConfig(gain: 0.30),
        hapticRole: .impact
    )

    /// Warm multi-partial "Toaster Ding" chord when an optical burn, image master, or CD rip succeeds.
    public static let success = KroutonAcousticCue(
        source: .procedural(.toasterDing),
        dsp: DSPConfig(gain: 0.34),
        hapticRole: .success
    )

    /// Low dual-pulse "Burnt Toast" buzzer when a file drop is rejected or quit is blocked mid-burn.
    public static let warning = KroutonAcousticCue(
        source: .procedural(.burntToastGuard),
        dsp: DSPConfig(gain: 0.30),
        hapticRole: .warning
    )

    /// macOS `Glass.aiff` played backwards (ethereal vacuum whoosh-chime).
    public static let reverseGlass = KroutonAcousticCue(
        source: .osSound("Glass"),
        dsp: DSPConfig(rate: 1.0, reversed: true, gain: 0.75),
        hapticRole: .success
    )

    /// macOS `Purr.aiff` accelerated 2.2x (crisp mechanical optical spindle trill).
    public static let fastPurr = KroutonAcousticCue(
        source: .osSound("Purr"),
        dsp: DSPConfig(rate: 2.2, reversed: false, gain: 0.75),
        hapticRole: .impact
    )

    /// macOS `Frog.aiff` pitched down 0.58x (deep industrial servo thud).
    public static let deepFrog = KroutonAcousticCue(
        source: .osSound("Frog"),
        dsp: DSPConfig(rate: 0.58, reversed: false, gain: 0.80),
        hapticRole: .warning
    )

    /// macOS `Bottle.aiff` reversed at 1.35x speed (pneumatic optical tray lock).
    public static let trayLock = KroutonAcousticCue(
        source: .osSound("Bottle"),
        dsp: DSPConfig(rate: 1.35, reversed: true, gain: 0.75),
        hapticRole: .impact
    )

    /// Standard macOS user-preferred alert sound.
    public static let systemAlert = KroutonAcousticCue(
        source: .systemAlert,
        hapticRole: .warning
    )

    /// Creates a cue from any `/System/Library/Sounds/<name>.aiff` file (`Basso`, `Blow`, `Bottle`,
    /// `Frog`, `Funk`, `Glass`, `Hero`, `Morse`, `Ping`, `Pop`, `Purr`, `Sosumi`, `Submarine`, `Tink`).
    public static func osSound(
        _ name: String,
        rate: Double = 1.0,
        reversed: Bool = false,
        gain: Float = 0.80
    ) -> KroutonAcousticCue {
        KroutonAcousticCue(
            source: .osSound(name),
            dsp: DSPConfig(rate: rate, reversed: reversed, gain: gain)
        )
    }

    // MARK: - Fluent Composable Modifiers

    /// Returns a copy of this cue resampled at `rate` (`> 1.0` faster/higher, `< 1.0` slower/deeper).
    public func pitched(_ rate: Double) -> KroutonAcousticCue {
        var copy = self
        copy.dsp.rate = max(0.1, min(8.0, rate))
        return copy
    }

    /// Returns a time-reversed copy of this cue.
    public func reversed(_ isReversed: Bool = true) -> KroutonAcousticCue {
        var copy = self
        copy.dsp.reversed = isReversed
        return copy
    }

    /// Returns a copy of this cue with adjusted output gain (`0.0 ... 2.0`).
    public func gain(_ level: Float) -> KroutonAcousticCue {
        var copy = self
        copy.dsp.gain = max(0.0, min(2.0, level))
        return copy
    }

    /// Returns a copy of this cue modulated with a metallic ring-modulator carrier frequency.
    public func ringModulated(hz: Double) -> KroutonAcousticCue {
        var copy = self
        copy.dsp.ringModHz = max(0.0, hz)
        return copy
    }

    /// Returns a retro lo-fi bitcrushed copy quantized to `bits` resolution (`1 ... 16`).
    public func bitcrushed(bits: Int) -> KroutonAcousticCue {
        var copy = self
        copy.dsp.crushBits = max(1, min(16, bits))
        return copy
    }
}
