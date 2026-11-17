import Foundation
import ImageKit
import Observation
import OpticalCore
import SwiftUI

/// Value-type snapshot of the Polar Disc Label Workspace canvas for 32-level Undo/Redo (`Cmd+Z` / `Cmd+Shift+Z`).
// MARK: - KroutonObservableFeatureStores

public struct KroutonLabelCanvasSnapshot: Equatable, Sendable {
    public var templateStyle: KroutonCroutonLabelStyle
    public var backgroundStyle: KroutonVectorBackgroundStyle
    public var vectorShapes: [KroutonVectorShapeLayer]
    public var primaryRGBA: KroutonRGBAColor
    public var secondaryRGBA: KroutonRGBAColor
    public var gradientMidpoint: Double
    public var gradientAngle: Double
    public var gpuSeedPattern: KroutonGPUSeedPattern
    public var kaleidoscopeRig: KroutonKaleidoscopeMirrorRig
    public var kaleidoscopeFacets: Int
    public var chamberTumble: Double
    public var tinyPlanetRadius: Double
    public var bgAdjustments: KroutonBackgroundAdjustments
    public var textElements: [KroutonLabelTextElement]
    public var selectedTextID: UUID?
    public var workingGeometryOverride: KroutonDiscLabelGeometry?

    @MainActor
    public init(from store: KroutonStateStore, overrideGeometry: KroutonDiscLabelGeometry?) {
        let (r1, g1, b1, a1) = KroutonPureColorMath.extractSRGB(store.labelBgPrimaryColor)
        let (r2, g2, b2, a2) = KroutonPureColorMath.extractSRGB(store.labelBgSecondaryColor)
        self.templateStyle = store.selectedLabelTemplate
        self.backgroundStyle = store.labelBackgroundStyle
        self.vectorShapes = store.labelVectorShapes
        self.primaryRGBA = KroutonRGBAColor(r: Double(r1), g: Double(g1), b: Double(b1), a: Double(a1))
        self.secondaryRGBA = KroutonRGBAColor(r: Double(r2), g: Double(g2), b: Double(b2), a: Double(a2))
        self.gradientMidpoint = store.labelGradientMidpoint
        self.gradientAngle = store.labelGradientAngle
        self.gpuSeedPattern = store.labelGPUSeedPattern
        self.kaleidoscopeRig = store.labelKaleidoscopeRig
        self.kaleidoscopeFacets = store.labelKaleidoscopeFacets
        self.chamberTumble = store.labelChamberTumble
        self.tinyPlanetRadius = store.labelTinyPlanetRadius
        self.bgAdjustments = store.labelBgAdjustments
        self.textElements = store.labelTextElements
        self.selectedTextID = store.labelSelectedTextID
        self.workingGeometryOverride = overrideGeometry
    }

    /// Epsilon-tolerant comparison so ColorPicker / Slider float rounding never triggers a false edit after Undo/Redo.
    public func isMeaningfullyDifferent(from other: KroutonLabelCanvasSnapshot) -> Bool {
        if templateStyle != other.templateStyle { return true }
        if backgroundStyle != other.backgroundStyle { return true }
        if vectorShapes != other.vectorShapes { return true }
        if gpuSeedPattern != other.gpuSeedPattern { return true }
        if kaleidoscopeRig != other.kaleidoscopeRig { return true }
        if kaleidoscopeFacets != other.kaleidoscopeFacets { return true }
        if workingGeometryOverride != other.workingGeometryOverride { return true }
        if bgAdjustments != other.bgAdjustments { return true }
        if abs(gradientMidpoint - other.gradientMidpoint) > 0.002 { return true }
        if abs(gradientAngle - other.gradientAngle) > 0.05 { return true }
        if abs(chamberTumble - other.chamberTumble) > 0.002 { return true }
        if abs(tinyPlanetRadius - other.tinyPlanetRadius) > 0.002 { return true }
        if !Self.rgbaNearEqual(primaryRGBA, other.primaryRGBA) { return true }
        if !Self.rgbaNearEqual(secondaryRGBA, other.secondaryRGBA) { return true }
        if textElements.count != other.textElements.count { return true }
        for (a, b) in zip(textElements, other.textElements) {
            if a.id != b.id || a.text != b.text || a.isCurvedArc != b.isCurvedArc ||
               a.isBottomUpright != b.isBottomUpright || a.isBold != b.isBold ||
               a.hasDropShadow != b.hasDropShadow || a.fontDesignRaw != b.fontDesignRaw ||
               abs(a.radiusMM - b.radiusMM) > 0.02 || abs(a.angleDegrees - b.angleDegrees) > 0.05 ||
               abs(a.fontSizePoints - b.fontSizePoints) > 0.05 || abs(a.letterTracking - b.letterTracking) > 0.005 ||
               !Self.rgbaNearEqual(a.color, b.color) {
                return true
            }
        }
        return false
    }

    private static func rgbaNearEqual(_ a: KroutonRGBAColor, _ b: KroutonRGBAColor) -> Bool {
        abs(a.r - b.r) < 0.004 && abs(a.g - b.g) < 0.004 && abs(a.b - b.b) < 0.004 && abs(a.a - b.a) < 0.004
    }

    @MainActor
    public func apply(to store: KroutonStateStore) -> KroutonDiscLabelGeometry? {
        store.selectedLabelTemplate = templateStyle
        store.labelBackgroundStyle = backgroundStyle
        store.labelVectorShapes = vectorShapes
        store.labelBgPrimaryColor = Color(red: primaryRGBA.r, green: primaryRGBA.g, blue: primaryRGBA.b, opacity: primaryRGBA.a)
        store.labelBgSecondaryColor = Color(red: secondaryRGBA.r, green: secondaryRGBA.g, blue: secondaryRGBA.b, opacity: secondaryRGBA.a)
        store.labelGradientMidpoint = gradientMidpoint
        store.labelGradientAngle = gradientAngle
        store.labelGPUSeedPattern = gpuSeedPattern
        store.labelKaleidoscopeRig = kaleidoscopeRig
        store.labelKaleidoscopeFacets = kaleidoscopeFacets
        store.labelChamberTumble = chamberTumble
        store.labelTinyPlanetRadius = tinyPlanetRadius
        store.labelBgAdjustments = bgAdjustments
        store.labelTextElements = textElements
        if let sel = selectedTextID, textElements.contains(where: { $0.id == sel }) {
            store.labelSelectedTextID = sel
        } else {
            store.labelSelectedTextID = textElements.last?.id
        }
        return workingGeometryOverride
    }
}

/// Cursor-based 32-step Undo/Redo engine for the Polar Disc Label Workspace.
@Observable
@MainActor
public final class KroutonLabelWorkspaceSubStore {
    public var workingGeometryOverride: KroutonDiscLabelGeometry? = nil
    public var transientStatusBanner: String = ""
    public var isFreehandDrawMode: Bool = false
    public var autoSnapFreehandShapes: Bool = true
    public var lastExportedPNGURL: URL? = nil
    public private(set) var timeline: [KroutonLabelCanvasSnapshot] = []
    public private(set) var cursor: Int = -1
    public let maxHistoryDepth: Int = 32
    private var suppressRecordingUntil: TimeInterval = 0
    private var lastEditTimestamp: TimeInterval = 0

    public init() {}

    public var canUndo: Bool { cursor > 0 && timeline.indices.contains(cursor - 1) }
    public var canRedo: Bool { cursor >= 0 && (cursor + 1) < timeline.count }

    public func seedInitialSnapshotIfNeeded(from store: KroutonStateStore) {
        if timeline.isEmpty {
            let initial = KroutonLabelCanvasSnapshot(from: store, overrideGeometry: workingGeometryOverride)
            timeline = [initial]
            cursor = 0
        }
    }

    /// Called before an explicit discrete action or automatically via `.onChange` when canvas state changes.
    public func recordUndoSnapshot(from store: KroutonStateStore, coalesceWindow: TimeInterval = 0.0) {
        let now = ProcessInfo.processInfo.systemUptime
        guard now >= suppressRecordingUntil else { return }
        seedInitialSnapshotIfNeeded(from: store)
        let current = KroutonLabelCanvasSnapshot(from: store, overrideGeometry: workingGeometryOverride)
        guard timeline.indices.contains(cursor) else { return }
        guard current.isMeaningfullyDifferent(from: timeline[cursor]) else { return }

        if cursor < timeline.count - 1 {
            timeline.removeSubrange((cursor + 1)..<timeline.count)
        }
        if coalesceWindow > 0, (now - lastEditTimestamp) < coalesceWindow, cursor > 0 {
            timeline[cursor] = current
        } else {
            timeline.append(current)
            if timeline.count > maxHistoryDepth {
                timeline.removeFirst(timeline.count - maxHistoryDepth)
            }
            cursor = timeline.count - 1
        }
        lastEditTimestamp = now
        store.objectWillChange.send()
    }

    public func undo(into store: KroutonStateStore) {
        seedInitialSnapshotIfNeeded(from: store)
        // Flush any unrecorded live state into the timeline before stepping back
        let live = KroutonLabelCanvasSnapshot(from: store, overrideGeometry: workingGeometryOverride)
        if timeline.indices.contains(cursor), live.isMeaningfullyDifferent(from: timeline[cursor]) {
            if cursor < timeline.count - 1 {
                timeline.removeSubrange((cursor + 1)..<timeline.count)
            }
            timeline.append(live)
            cursor = timeline.count - 1
        }
        guard cursor > 0 else { return }
        cursor -= 1
        suppressRecordingUntil = ProcessInfo.processInfo.systemUptime + 0.35
        lastEditTimestamp = 0
        workingGeometryOverride = timeline[cursor].apply(to: store)
        store.objectWillChange.send()
    }

    public func redo(into store: KroutonStateStore) {
        guard (cursor + 1) < timeline.count else { return }
        cursor += 1
        suppressRecordingUntil = ProcessInfo.processInfo.systemUptime + 0.35
        lastEditTimestamp = 0
        workingGeometryOverride = timeline[cursor].apply(to: store)
        store.objectWillChange.send()
    }
}

/// Fine-grained `@Observable` sub-store for `Galette` disc image inspection and CUE sheet parsing.
@Observable
@MainActor
public final class KroutonDiscImageInspectorSubStore {
    public var lastClassifiedSummary: String = ""
    public var parsedCueTrackCount: Int = 0
    public var bootArchitecture: String = ""
    public var isBootableVerified: Bool = false

    public init() {}

    public func analyzeImageWithDiscDepot(imageBytes: Data, sampleCueText: String? = nil) {
        let classification = KroutonDiscImageDepot.classifyBootableImage(headerBytes: imageBytes)
        self.bootArchitecture = classification.architectureDescription
        self.isBootableVerified = classification.isBootable
        let cueSource = sampleCueText ?? "FILE \"KROUTON_MASTER.BIN\" BINARY\n  TRACK 01 MODE1/2352\n    INDEX 01 00:00:00\n"
        let cueSheet = KroutonDiscImageDepot.parseCueSheet(cueText: cueSource)
        self.parsedCueTrackCount = cueSheet.tracks.count
        self.lastClassifiedSummary = "Image Verified: \(classification.formatName) | Bootable: \(classification.isBootable ? "YES" : "NO") (\(classification.architectureDescription)) | CUE Tracks: \(cueSheet.tracks.count)"
    }
}

/// Fine-grained `@Observable` sub-store isolating hardware & image destination queue telemetry.
@Observable
@MainActor
public final class KroutonBurnQueueSubStore {
    public var activeQueueStatusMessage: String = ""
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
