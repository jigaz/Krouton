import Foundation

// MARK: - A Notification's Sound

/// The sound a notification plays: one of Krouton's synth voices or a macOS system sound, shaped
/// by the synth's effects (pitch, reverse, lo-fi, metallic). Saved with Settings › Notifications.
struct KroutonNotificationSound: Hashable, Codable, Sendable {
    /// A `Voice` id, or `system:<name>` for a sound in /System/Library/Sounds.
    var source: String
    /// Semitones up or down, −12…12.
    var pitch: Double = 0
    var reversed: Bool = false
    /// 0 = clean; otherwise the bit depth, 2…12 (lower is crunchier).
    var lofiBits: Int = 0
    /// 0 = off; otherwise a ring-modulator frequency in Hz.
    var metallicHz: Double = 0

    struct Voice: Identifiable, Sendable {
        let id: String
        let name: String
        let symbol: String
        let cue: KroutonAcousticCue
    }

    /// Krouton's own voices, synthesised in memory or shaped from a system sound.
    static let voices: [Voice] = [
        Voice(id: "toaster-ding", name: "Toaster Ding", symbol: "checkmark.seal.fill", cue: .success),
        Voice(id: "burnt-toast", name: "Burnt Toast", symbol: "exclamationmark.triangle.fill", cue: .warning),
        Voice(id: "staged-pip", name: "Pip", symbol: "tray.and.arrow.down.fill", cue: .staged),
        Voice(id: "calibration", name: "Calibration Blip", symbol: "waveform.path.ecg", cue: .notice),
        Voice(id: "spindle", name: "Spindle Trill", symbol: "opticaldisc", cue: .fastPurr),
        Voice(id: "tray-lock", name: "Tray Lock", symbol: "lock.rotation", cue: .trayLock),
        Voice(id: "reverse-glass", name: "Reverse Glass", symbol: "sparkles", cue: .reverseGlass),
        Voice(id: "servo-thud", name: "Servo Thud", symbol: "speaker.zzz.fill", cue: .deepFrog),
        Voice(id: "system-alert", name: "System Alert", symbol: "bell", cue: .systemAlert),
    ]

    static let systemSounds = ["Basso", "Blow", "Bottle", "Frog", "Funk", "Glass", "Hero",
                               "Morse", "Ping", "Pop", "Purr", "Sosumi", "Submarine", "Tink"]

    var name: String {
        if source.hasPrefix("system:") { return String(source.dropFirst(7)) }
        return Self.voices.first { $0.id == source }?.name ?? source
    }

    var isShaped: Bool { pitch != 0 || reversed || lofiBits != 0 || metallicHz != 0 }

    // MARK: - Playing

    /// The cue to play. With `driveName`, each drive gets its own interval, so you can tell by ear
    /// which of several burners finished or needs a disc.
    func cue(forDrive driveName: String? = nil) -> KroutonAcousticCue {
        var cue: KroutonAcousticCue
        if source.hasPrefix("system:") {
            cue = .osSound(String(source.dropFirst(7)))
        } else {
            cue = Self.voices.first { $0.id == source }?.cue ?? .success
        }
        let semitones = pitch + (driveName.map(Self.driveInterval) ?? 0)
        cue.dsp = KroutonAcousticCue.DSPConfig(
            rate: cue.dsp.rate * pow(2, semitones / 12),
            reversed: reversed ? !cue.dsp.reversed : cue.dsp.reversed,
            gain: cue.dsp.gain,
            ringModHz: metallicHz > 0 ? metallicHz : cue.dsp.ringModHz,
            crushBits: lofiBits > 0 ? lofiBits : cue.dsp.crushBits)
        return cue
    }

    /// Unison, a fifth, a third, an octave or a fourth below, picked from the drive's name so the
    /// same drive always sounds the same.
    static func driveInterval(_ driveName: String) -> Double {
        let intervals: [Double] = [0, 7, 4, 12, -5]
        var hash: UInt32 = 0x811C_9DC5
        for byte in driveName.utf8 { hash = (hash ^ UInt32(byte)) &* 0x0100_0193 }
        return intervals[Int(hash % UInt32(intervals.count))]
    }
}

// MARK: - Saved Notifications

extension KroutonPreferences {
    /// Settings › Notifications as saved: each event's banner, sound and voice. Events this version
    /// adds keep their defaults; ones it no longer has are dropped.
    static func notificationEvents(defaults: [KroutonKitchenEventRow]) -> [KroutonKitchenEventRow] {
        guard let text = string(for: .notificationEvents), let data = text.data(using: .utf8),
              let saved = try? JSONDecoder().decode([KroutonKitchenEventRow.Saved].self, from: data) else { return defaults }
        let byID = Dictionary(saved.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        return defaults.map { row in
            guard let mine = byID[row.id] else { return row }
            var merged = row
            merged.bannerEnabled = mine.bannerEnabled
            merged.soundEnabled = mine.soundEnabled
            merged.sound = mine.sound
            return merged
        }
    }

    static func saveNotificationEvents(_ rows: [KroutonKitchenEventRow]) {
        let saved = rows.map { KroutonKitchenEventRow.Saved(id: $0.id, bannerEnabled: $0.bannerEnabled, soundEnabled: $0.soundEnabled, sound: $0.sound) }
        if let data = try? JSONEncoder().encode(saved) { set(String(decoding: data, as: UTF8.self), for: .notificationEvents) }
    }
}

extension KroutonKitchenEventRow {
    /// What is saved of a row; the titles come from this version.
    struct Saved: Codable {
        let id: String
        let bannerEnabled: Bool
        let soundEnabled: Bool
        let sound: KroutonNotificationSound
    }
}
