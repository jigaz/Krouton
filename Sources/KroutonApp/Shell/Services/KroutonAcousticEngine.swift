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

// MARK: - Unified Synthesis & DSP Engine

/// Thread-safe, pure `AVFoundation` audio synthesis and DSP engine.
///
/// Unifies procedural waveform generation and macOS system `.aiff` loading into a single
/// `44.1 kHz` mono `Float32` DSP pipeline with lazy `AVAudioPCMBuffer` memoization.
public final class KroutonAcousticEngine: @unchecked Sendable {
    public static let shared = KroutonAcousticEngine()

    public static let sampleRate: Double = 44_100.0

    private let lock = NSLock()
    private let engine = AVAudioEngine()
    private let player = AVAudioPlayerNode()
    private let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1)!
    private var cache: [KroutonAcousticCue: AVAudioPCMBuffer] = [:]

    private init() {
        engine.attach(player)
        engine.connect(player, to: engine.mainMixerNode, format: format)
    }

    /// Plays the specified `KroutonAcousticCue`, lazily synthesizing or loading+augmenting its buffer
    /// on first invocation and replaying from RAM on all subsequent calls.
    public func play(_ cue: KroutonAcousticCue) {
        if cue.source == .systemAlert {
            AudioServicesPlaySystemSound(kSystemSoundID_UserPreferredAlert)
            return
        }
        lock.lock()
        defer { lock.unlock() }

        let buffer: AVAudioPCMBuffer
        if let cached = cache[cue] {
            buffer = cached
        } else if let built = buildBuffer(for: cue) {
            cache[cue] = built
            buffer = built
        } else {
            return
        }

        if !engine.isRunning {
            try? engine.start()
        }
        player.stop()
        player.scheduleBuffer(buffer, at: nil, options: .interrupts, completionHandler: nil)
        player.play()
    }

    /// Clears the in-memory `AVAudioPCMBuffer` cache.
    public func purgeCache() {
        lock.lock()
        cache.removeAll()
        lock.unlock()
    }

    // MARK: - Unified Source Acquisition + Single-Pass DSP Pipeline

    private func buildBuffer(for cue: KroutonAcousticCue) -> AVAudioPCMBuffer? {
        let rawSamples: [Float]
        switch cue.source {
        case .systemAlert:
            return nil
        case .procedural(let preset):
            rawSamples = synthesizeRawSamples(for: preset)
        case .osSound(let name):
            guard let loaded = loadMonoSamplesFromOSSound(named: name) else { return nil }
            rawSamples = loaded
        }
        return finalizeBuffer(from: rawSamples, dsp: cue.dsp)
    }

    /// Generates unit-amplitude (`-1.0 ... 1.0`) 44.1kHz samples for a procedural preset.
    private func synthesizeRawSamples(for preset: KroutonAcousticCue.ProceduralPreset) -> [Float] {
        let duration: Double
        let generator: (Double) -> Double

        switch preset {
        case .stagedPip:
            duration = 0.045
            generator = { t in
                exp(-t * 95.0) * sin(2.0 * .pi * 1046.5 * t)
            }
        case .calibrationNotice:
            duration = 0.16
            generator = { t in
                let freq = t < 0.075 ? 880.0 : 1318.5
                let localT = t < 0.075 ? t : (t - 0.075)
                return exp(-localT * 32.0) * sin(2.0 * .pi * freq * localT)
            }
        case .toasterDing:
            duration = 0.85
            generator = { t in
                let attack = min(1.0, t / 0.004)
                let b1 = exp(-t * 4.5) * sin(2.0 * .pi * 987.77 * t)
                let b2 = 0.65 * exp(-t * 5.5) * sin(2.0 * .pi * 1479.98 * t)
                let b3 = 0.35 * exp(-t * 18.0) * sin(2.0 * .pi * 2959.96 * t)
                return attack * (b1 + b2 + b3) * 0.55
            }
        case .burntToastGuard:
            duration = 0.28
            generator = { t in
                let pulse = (t < 0.11 || (t > 0.14 && t < 0.26)) ? 1.0 : 0.0
                let env = exp(-t * 6.0) * pulse
                let tone = sin(2.0 * .pi * 165.0 * t)
                    + 0.5 * sin(2.0 * .pi * 220.0 * t)
                    + 0.25 * sin(2.0 * .pi * 330.0 * t)
                return env * tone * 0.58
            }
        }

        let count = max(1, Int(Self.sampleRate * duration))
        return (0..<count).map { i in
            Float(generator(Double(i) / Self.sampleRate))
        }
    }

    /// Reads any `/System/Library/Sounds/<name>.aiff` file, mixes stereo down to mono, and normalizes
    /// its sample rate ratio to `44.1 kHz`.
    private func loadMonoSamplesFromOSSound(named name: String) -> [Float]? {
        let url = URL(fileURLWithPath: "/System/Library/Sounds/\(name).aiff")
        guard let file = try? AVAudioFile(forReading: url) else { return nil }
        let srcFormat = file.processingFormat
        let srcFrames = Int(file.length)
        guard srcFrames > 0,
              let srcBuf = AVAudioPCMBuffer(pcmFormat: srcFormat, frameCapacity: AVAudioFrameCount(srcFrames)),
              (try? file.read(into: srcBuf)) != nil,
              let channels = srcBuf.floatChannelData else { return nil }

        let chCount = Int(srcFormat.channelCount)
        let ratio = srcFormat.sampleRate / Self.sampleRate
        let outCount = max(1, Int(Double(srcFrames) / ratio))
        var mono = [Float](repeating: 0, count: outCount)

        for i in 0..<outCount {
            let srcPos = Double(i) * ratio
            let idx0 = min(srcFrames - 1, Int(srcPos))
            let idx1 = min(srcFrames - 1, idx0 + 1)
            let frac = Float(srcPos - Double(idx0))
            var sum: Float = 0
            for ch in 0..<chCount {
                let s0 = channels[ch][idx0]
                let s1 = channels[ch][idx1]
                sum += s0 * (1.0 - frac) + s1 * frac
            }
            mono[i] = sum / Float(max(1, chCount))
        }
        return mono
    }

    /// Single-pass DSP transform: applies time-reversal, linear-interpolated rate/pitch scaling,
    /// optional ring modulation, optional bitcrushing, gain scaling, and 8ms boundary de-clicking.
    private func finalizeBuffer(
        from raw: [Float],
        dsp: KroutonAcousticCue.DSPConfig
    ) -> AVAudioPCMBuffer? {
        let srcCount = raw.count
        guard srcCount > 0 else { return nil }

        let outFrames = max(1, Int(Double(srcCount) / dsp.rate))
        guard let outBuf = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(outFrames)),
              let dst = outBuf.floatChannelData?[0] else { return nil }
        outBuf.frameLength = AVAudioFrameCount(outFrames)

        let fadeFrames = min(350, outFrames / 4)
        let quantLevels: Float = dsp.crushBits > 0 ? pow(2.0, Float(dsp.crushBits)) : 0

        for i in 0..<outFrames {
            let srcPos = Double(i) * dsp.rate
            let idx0 = min(srcCount - 1, Int(srcPos))
            let idx1 = min(srcCount - 1, idx0 + 1)
            let frac = Float(srcPos - Double(idx0))

            let rIdx0 = dsp.reversed ? (srcCount - 1 - idx0) : idx0
            let rIdx1 = dsp.reversed ? (srcCount - 1 - idx1) : idx1

            var sample = raw[rIdx0] * (1.0 - frac) + raw[rIdx1] * frac

            if dsp.ringModHz > 0 {
                let t = Double(i) / Self.sampleRate
                sample *= Float(sin(2.0 * .pi * dsp.ringModHz * t))
            }

            if quantLevels > 0 {
                sample = (sample * quantLevels).rounded() / quantLevels
            }

            var env: Float = 1.0
            if fadeFrames > 0 {
                if i < fadeFrames {
                    env = Float(i) / Float(fadeFrames)
                } else if i > outFrames - fadeFrames {
                    env = Float(outFrames - i) / Float(fadeFrames)
                }
            }

            dst[i] = max(-1.0, min(1.0, sample * dsp.gain * env))
        }
        return outBuf
    }
}

// MARK: - Declarative SwiftUI Modifier

public extension View {
    /// Declarative SwiftUI modifier that triggers a `KroutonAcousticCue` and synchronized trackpad
    /// haptic feedback whenever `trigger` satisfies `condition`.
    func acousticFeedback<T: Equatable>(
        _ cue: KroutonAcousticCue,
        trigger: T,
        condition: @escaping (T, T) -> Bool = { _, _ in true }
    ) -> some View {
        self
            .onChange(of: trigger) { oldValue, newValue in
                if condition(oldValue, newValue) {
                    KroutonOSDesktopBridge.playAcousticCue(cue)
                }
            }
            .sensoryFeedback(
                cue.hapticRole == .warning ? .error : (cue.hapticRole == .success ? .success : .impact),
                trigger: trigger
            ) { oldValue, newValue in
                condition(oldValue, newValue)
            }
    }
}
