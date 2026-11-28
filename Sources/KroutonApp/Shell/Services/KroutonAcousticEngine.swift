import AVFoundation
import AudioToolbox
import Foundation
import SwiftUI
import os

// MARK: - Sound Engine

/// Thread-safe, pure `AVFoundation` audio synthesis and DSP engine.
///
/// Unifies procedural waveform generation and macOS system `.aiff` loading into a single
/// `44.1 kHz` mono `Float32` DSP pipeline with lazy `AVAudioPCMBuffer` memoization.
final class KroutonAcousticEngine: Sendable {
    static let shared = KroutonAcousticEngine()

    static let sampleRate: Double = 44_100.0

    private struct EngineState {
        let engine = AVAudioEngine()
        let player = AVAudioPlayerNode()
        let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1)!
        var cache: [KroutonAcousticCue: AVAudioPCMBuffer] = [:]
    }

    private let stateLock: OSAllocatedUnfairLock<EngineState>

    private init() {
        let initial = EngineState()
        initial.engine.attach(initial.player)
        initial.engine.connect(initial.player, to: initial.engine.mainMixerNode, format: initial.format)
        self.stateLock = OSAllocatedUnfairLock(uncheckedState: initial)
    }

    /// Plays the specified `KroutonAcousticCue`, lazily synthesizing or loading+augmenting its buffer
    /// on first invocation and replaying from RAM on all subsequent calls.
    func play(_ cue: KroutonAcousticCue) {
        if cue.source == .systemAlert {
            AudioServicesPlaySystemSound(kSystemSoundID_UserPreferredAlert)
            return
        }
        stateLock.withLockUnchecked { st in
            let buffer: AVAudioPCMBuffer
            if let cached = st.cache[cue] {
                buffer = cached
            } else if let built = buildBuffer(for: cue, format: st.format) {
                st.cache[cue] = built
                buffer = built
            } else {
                return
            }

            if !st.engine.isRunning {
                try? st.engine.start()
            }
            st.player.stop()
            st.player.scheduleBuffer(buffer, at: nil, options: .interrupts, completionHandler: nil)
            st.player.play()
        }
    }

    // MARK: - Loading and Shaping Samples

    private func buildBuffer(for cue: KroutonAcousticCue, format: AVAudioFormat) -> AVAudioPCMBuffer? {
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
        guard let monoFormat = AVAudioFormat(standardFormatWithSampleRate: Self.sampleRate, channels: 1),
              let outBuf = AVAudioPCMBuffer(pcmFormat: monoFormat, frameCapacity: AVAudioFrameCount(outFrames)),
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
