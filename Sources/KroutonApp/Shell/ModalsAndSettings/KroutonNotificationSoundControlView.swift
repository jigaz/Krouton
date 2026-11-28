import SwiftUI

// MARK: - A Notification's Sound Picker

/// Picks an event's sound from Krouton's synth voices or the system sounds, plays it, and opens
/// the synth's effects (pitch, reverse, lo-fi, metallic) to shape it.
struct KroutonNotificationSoundControlView: View {
    @Binding var sound: KroutonNotificationSound
    let isEnabled: Bool
    let accent: Color
    @State private var isShaping = false

    var body: some View {
        HStack(spacing: 6) {
            Menu {
                Section(KroutonL10n.tr("Krouton Synth")) {
                    ForEach(KroutonNotificationSound.voices) { voice in
                        Button { choose(voice.id) } label: { Label(voice.name, systemImage: voice.symbol) }
                    }
                }
                Section(KroutonL10n.tr("System Sounds")) {
                    ForEach(KroutonNotificationSound.systemSounds, id: \.self) { name in
                        Button(name) { choose("system:" + name) }
                    }
                }
            } label: {
                Text(verbatim: sound.name + (sound.isShaped ? " ✦" : ""))
                    .lineLimit(1)
            }
            .fixedSize()
            .help(KroutonL10n.tr("Sound for this notification"))

            Button { preview() } label: { Image(systemName: "play.fill") }
                .buttonStyle(.borderless)
                .accessibilityLabel(KroutonL10n.tr("Play the Sound"))
                .help(KroutonL10n.tr("Play the Sound"))

            Button { isShaping.toggle() } label: { Image(systemName: "slider.horizontal.3") }
                .buttonStyle(.borderless)
                .foregroundStyle(sound.isShaped ? accent : .secondary)
                .accessibilityLabel(KroutonL10n.tr("Shape the Sound"))
                .help(KroutonL10n.tr("Shape the Sound"))
                .popover(isPresented: $isShaping, arrowEdge: .bottom) { shaper }
        }
        .disabled(!isEnabled)
        .contextMenu {
            Button(KroutonL10n.tr("Play the Sound")) { preview() }
            Button(KroutonL10n.tr("Remove Effects")) { clearEffects() }
                .disabled(!sound.isShaped)
        }
    }

    // MARK: - Effects

    private var shaper: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(String(format: KroutonL10n.tr("Shape %@"), sound.name))
                .font(.headline)
            slider(KroutonL10n.tr("Pitch"), value: $sound.pitch, in: -12...12, step: 1,
                   shown: sound.pitch == 0 ? KroutonL10n.tr("as recorded") : String(format: "%+.0f st", sound.pitch))
            Toggle(KroutonL10n.tr("Play backwards"), isOn: $sound.reversed)
            slider(KroutonL10n.tr("Lo-fi"), value: Binding(get: { Double(sound.lofiBits == 0 ? 13 : sound.lofiBits) },
                                                          set: { sound.lofiBits = $0 >= 13 ? 0 : Int($0) }),
                   in: 2...13, step: 1, shown: sound.lofiBits == 0 ? KroutonL10n.tr("clean") : "\(sound.lofiBits)-bit")
            slider(KroutonL10n.tr("Metallic"), value: $sound.metallicHz, in: 0...1200, step: 20,
                   shown: sound.metallicHz == 0 ? KroutonL10n.tr("off") : "\(Int(sound.metallicHz)) Hz")
            HStack {
                Button(KroutonL10n.tr("Remove Effects")) { clearEffects() }
                    .disabled(!sound.isShaped)
                Spacer()
                Button(KroutonL10n.tr("Play")) { preview() }
                    .keyboardShortcut(.defaultAction)
            }
        }
        .padding(14)
        .frame(width: 300)
        .onChange(of: sound) { preview() }
    }

    private func slider(_ title: String, value: Binding<Double>, in range: ClosedRange<Double>, step: Double, shown: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack {
                Text(title)
                Spacer()
                Text(verbatim: shown)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(.secondary)
            }
            Slider(value: value, in: range, step: step)
                .accessibilityLabel(title)
                .accessibilityValue(shown)
        }
    }

    private func choose(_ source: String) {
        sound.source = source
        preview()
    }

    private func clearEffects() {
        sound = KroutonNotificationSound(source: sound.source)
    }

    private func preview() {
        KroutonOSDesktopBridge.playAcousticCue(sound.cue())
    }
}
