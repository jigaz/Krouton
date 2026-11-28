import Foundation
import OpticalCore

// MARK: - Opening Projects Saved by Another Version

// What a saved audio setting starts as when a file lacks it: the values a new project uses.
// `AudioTrack` has none on purpose: a track can't be guessed without its file, so a track that
// can't be read is left out of the list and the rest open.

extension AudioProject: KroutonPersistedDefault {
    public static var persistedDefault: Self { Self() }
}

extension KroutonTrackTransitionSpec: KroutonPersistedDefault {
    public static var persistedDefault: Self { Self() }
}

extension KroutonCrossfadeCurve: KroutonPersistedDefault {
    public static var persistedDefault: Self { .equalPower }
}
