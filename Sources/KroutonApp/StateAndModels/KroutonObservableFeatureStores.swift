import Foundation
import Observation
import OpticalDough
import Galette

/// Fine-grained `@Observable` sub-store for the Polar Disc Label Studio, preventing
/// high-frequency canvas drags or color slider ticks from invalidating unrelated workspaces.
@Observable
@MainActor
public final class KroutonLabelStudioSubStore {
    public var workingGeometryOverride: KroutonSliceLabelGeometry? = nil
    public var transientStatusBanner: String = ""
    public var lastExportedPNGURL: URL? = nil

    public init() {}
}

/// Fine-grained `@Observable` sub-store for `Galette` disc image inspection, CUE sheet
/// parsing, and bootable El Torito / UDF sector classification inside the desktop app.
@Observable
@MainActor
public final class KroutonGaletteInspectorSubStore {
    public var lastClassifiedSummary: String = "Ready — Select or synthesize an ISO/BIN/CUE image to inspect via Galette."
    public var parsedCueTrackCount: Int = 1
    public var bootArchitecture: String = "El Torito x86_64 / EFI Hybrid"
    public var isBootableVerified: Bool = true

    public init() {}

    public func analyzeImageWithGalette(imageBytes: Data, sampleCueText: String? = nil) {
        let classification = KroutonGaletteModule.classifyBootableImage(headerBytes: imageBytes)
        self.bootArchitecture = classification.architectureDescription
        self.isBootableVerified = classification.isBootable

        let cueSource = sampleCueText ?? """
        FILE "KROUTON_MASTER.BIN" BINARY
          TRACK 01 MODE1/2352
            INDEX 01 00:00:00
        """
        let cueSheet = KroutonGaletteModule.parseCueSheet(cueText: cueSource)
        self.parsedCueTrackCount = cueSheet.tracks.count
        self.lastClassifiedSummary = "Galette Verified: \(classification.formatName) | Bootable: \(classification.isBootable ? "YES" : "NO") (\(classification.architectureDescription)) | CUE Tracks: \(cueSheet.tracks.count)"
    }
}

/// Fine-grained `@Observable` sub-store isolating hardware & image destination queue telemetry.
@Observable
@MainActor
public final class KroutonBurnQueueSubStore {
    public var activeQueueStatusMessage: String = "Queue Idle — Ready for Optical or Image Target"
    public var completedTargetCount: Int = 0
    public var lastMasteredISOURL: URL? = nil
    public var lastMasteredSHA256: String = ""

    public init() {}
}

/// Fine-grained `@Observable` sub-store isolating Depot Catalog filtering and verification state.
@Observable
@MainActor
public final class KroutonDepotCatalogSubStore {
    public var lastVerifiedItemID: String = ""
    public var lastVerifiedDigest: String = ""
    public var activeCategoryFilter: String = "All"

    public init() {}
}
