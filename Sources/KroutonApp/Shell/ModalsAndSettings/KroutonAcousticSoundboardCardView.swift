import SwiftUI

// MARK: - Sound Lab

/// Settings › Accessibility & Language › Sound Lab: plays Krouton's built-in sounds, and a
/// macOS system sound with the synth's effects (speed, reverse, bit depth, ring modulation)
/// applied. Nothing here is saved; each notification's own sound is chosen in Notifications.
struct KroutonAcousticSoundboardCardView: View {
    let accent: Color

    @State private var selectedOSSound: String = "Glass"
    @State private var dspRate: Double = 1.0
    @State private var dspReversed: Bool = false
    @State private var dspCrushBits: Double = 0
    @State private var dspRingModHz: Double = 0
    @State private var lastPlayedLabel: String = "Ready"

    private let osSounds = [
        "Basso", "Blow", "Bottle", "Frog", "Funk", "Glass", "Hero",
        "Morse", "Ping", "Pop", "Purr", "Sosumi", "Submarine", "Tink"
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(KroutonL10n.tr("Play Krouton's sounds, or shape a system sound and hear the result."))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Text(lastPlayedLabel)
                    .font(.system(size: 10, weight: .semibold, design: .monospaced))
                    .foregroundStyle(accent)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(accent.opacity(0.14))
                    .clipShape(Capsule())
            }

            Text(KroutonL10n.tr("Krouton's Sounds"))
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.secondary)

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 155), spacing: 8)], spacing: 8) {
                cueButton("Staged Pip (1046 Hz)", symbol: "tray.and.arrow.down.fill", cue: .staged)
                cueButton("Calibration (880→1318 Hz)", symbol: "waveform.path.ecg", cue: .notice)
                cueButton("Toaster Ding (Success)", symbol: "checkmark.seal.fill", cue: .success)
                cueButton("Burnt Toast (Warning)", symbol: "exclamationmark.triangle.fill", cue: .warning)
            }

            Divider()

            Text(KroutonL10n.tr("Shaped System Sounds"))
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.secondary)

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 155), spacing: 8)], spacing: 8) {
                cueButton("Reverse Glass", symbol: "sparkles", cue: .reverseGlass)
                cueButton("Fast Purr (2.2x Spindle)", symbol: "OpticalDisc", fallbackSymbol: "opticaldisc", cue: .fastPurr)
                cueButton("Deep Frog (0.58x Servo)", symbol: "speaker.zzz.fill", cue: .deepFrog)
                cueButton("Tray Lock (Rev Bottle)", symbol: "lock.rotation", cue: .trayLock)
            }

            Divider()

            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(KroutonL10n.tr("Shape a System Sound"))
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.secondary)
                    Spacer()
                    Picker(KroutonL10n.tr("Source"), selection: $selectedOSSound) {
                        ForEach(osSounds, id: \.self) { name in
                            Text(name).tag(name)
                        }
                    }
                    .labelsHidden()
                    .frame(width: 130)

                    Toggle(KroutonL10n.tr("Reverse"), isOn: $dspReversed)
                        .toggleStyle(.checkbox)
                        .font(.system(size: 11, weight: .medium))

                    Button {
                        var cue = KroutonAcousticCue.osSound(selectedOSSound, rate: dspRate, reversed: dspReversed, gain: 0.85)
                        if Int(dspCrushBits) > 0 {
                            cue = cue.bitcrushed(bits: Int(dspCrushBits))
                        }
                        if dspRingModHz > 0 {
                            cue = cue.ringModulated(hz: dspRingModHz)
                        }
                        lastPlayedLabel = "\(selectedOSSound) @ \(String(format: "%.2fx", dspRate))\(dspReversed ? " REV" : "")"
                        KroutonOSDesktopBridge.playAcousticCue(cue)
                    } label: {
                        Label(KroutonL10n.tr("Play"), systemImage: "play.fill")
                            .font(.system(size: 11, weight: .bold))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(accent.opacity(0.22))
                            .clipShape(Capsule())
                            .overlay(Capsule().stroke(accent.opacity(0.55), lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                }

                HStack(spacing: 16) {
                    HStack(spacing: 6) {
                        Text("Rate/Pitch: \(String(format: "%.2fx", dspRate))")
                            .font(.system(size: 10, design: .monospaced))
                            .frame(width: 95, alignment: .leading)
                        Slider(value: $dspRate, in: 0.35...2.50, step: 0.05)
                    }
                    HStack(spacing: 6) {
                        Text(dspCrushBits == 0 ? "Bitcrush: Off" : "Bitcrush: \(Int(dspCrushBits))-bit")
                            .font(.system(size: 10, design: .monospaced))
                            .frame(width: 95, alignment: .leading)
                        Slider(value: $dspCrushBits, in: 0...12, step: 1)
                    }
                    HStack(spacing: 6) {
                        Text(dspRingModHz == 0 ? "RingMod: Off" : "RingMod: \(Int(dspRingModHz))Hz")
                            .font(.system(size: 10, design: .monospaced))
                            .frame(width: 95, alignment: .leading)
                        Slider(value: $dspRingModHz, in: 0...600, step: 25)
                    }
                }
            }
        }
    }

    private func cueButton(
        _ title: String,
        symbol: String,
        fallbackSymbol: String? = nil,
        cue: KroutonAcousticCue
    ) -> some View {
        Button {
            lastPlayedLabel = title
            KroutonOSDesktopBridge.playAcousticCue(cue)
        } label: {
            HStack(spacing: 6) {
                Image(systemName: fallbackSymbol ?? symbol)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(accent)
                Text(KroutonL10n.tr(title))
                    .font(.system(size: 11, weight: .medium))
                    .lineLimit(1)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(Color.primary.opacity(0.05))
            .clipShape(RoundedRectangle(cornerRadius: 7))
            .overlay(
                RoundedRectangle(cornerRadius: 7)
                    .stroke(Color.primary.opacity(0.12), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}
