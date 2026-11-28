import Foundation

// MARK: - Label

// What each saved label setting starts as when a project from another version lacks it: the
// same values a new label starts with.

extension KroutonEmbeddedLabelSpec: KroutonPersistedDefault {
    public static var persistedDefault: Self { Self() }
}

extension KroutonLabelTextElement: KroutonPersistedDefault {
    public static var persistedDefault: Self { Self() }
}

extension KroutonBackgroundAdjustments: KroutonPersistedDefault {
    public static var persistedDefault: Self { Self() }
}

extension KroutonPlanetSettings: KroutonPersistedDefault {
    public static var persistedDefault: Self { Self() }
}

extension KroutonLabelPrintSettings: KroutonPersistedDefault {
    public static var persistedDefault: Self { Self() }
}

extension KroutonRGBAColor: KroutonPersistedDefault {
    public static var persistedDefault: Self { Self(r: 0, g: 0, b: 0, a: 1) }
}

// MARK: - Label Choices

// A choice a later version added and this one doesn't know falls back to the first, plainest one.

extension KroutonVectorBackgroundStyle: KroutonPersistedDefault {
    public static var persistedDefault: Self { .templateDefault }
}

extension KroutonGPUSeedPattern: KroutonPersistedDefault {
    public static var persistedDefault: Self { .neonLaserPrism }
}

extension KroutonKaleidoscopeMirrorRig: KroutonPersistedDefault {
    public static var persistedDefault: Self { .twoMirrorRosette }
}

extension KroutonVectorShapeKind: KroutonPersistedDefault {
    public static var persistedDefault: Self { .line }
}

extension KroutonPlanetSettings.Projection: KroutonPersistedDefault {
    public static var persistedDefault: Self { .stereographic }
}

extension KroutonPlanetSettings.Orientation: KroutonPersistedDefault {
    public static var persistedDefault: Self { .planet }
}

extension KroutonPlanetSettings.Seam: KroutonPersistedDefault {
    public static var persistedDefault: Self { .wrap }
}

extension KroutonLabelPrintSettings.Target: KroutonPersistedDefault {
    public static var persistedDefault: Self { .discTray }
}

// MARK: - Discs

extension KroutonSpanningDiscMedium: KroutonPersistedDefault {
    public static var persistedDefault: Self { .cd80Min700MB }
}

extension KroutonKrutCoreSpec: KroutonPersistedDefault {
    public static var persistedDefault: Self { Self() }
}

extension KroutonDiscVolumeMetadata: KroutonPersistedDefault {
    public static var persistedDefault: Self { Self(discNumber: 1) }
    /// Metadata without its disc number would land on disc 1.
    public static var requiredKeys: Set<String> { ["discNumber"] }
}
