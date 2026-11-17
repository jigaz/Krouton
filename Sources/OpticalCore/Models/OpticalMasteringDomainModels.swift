import CryptoKit
import Foundation

// MARK: - Phase 3: Strongly-Typed Mastering & Extraction Domain Models

public struct KroutonRipTrackItem: Identifiable, Hashable, Codable, Sendable {
    public var id: Int { num }
    public var num: Int
    public var title: String
    public var performer: String
    public var duration: String
    public var arStatus: String

    public init(num: Int, title: String, performer: String, duration: String, arStatus: String) {
        self.num = num
        self.title = title
        self.performer = performer
        self.duration = duration
        self.arStatus = arStatus
    }

    public static let defaultRedBookTOC: [KroutonRipTrackItem] = []
    public static let musicBrainzMatchedTOC: [KroutonRipTrackItem] = []
}

public struct KroutonVideoExtractTitleItem: Identifiable, Hashable, Codable, Sendable {
    public var id: String
    public var name: String
    public var streamInfo: String
    public var sizeLabel: String
    public var duration: String
    public var seconds: Int

    public init(id: String, name: String, streamInfo: String, sizeLabel: String, duration: String, seconds: Int) {
        self.id = id
        self.name = name
        self.streamInfo = streamInfo
        self.sizeLabel = sizeLabel
        self.duration = duration
        self.seconds = seconds
    }

    public static let defaultVideoTitles: [KroutonVideoExtractTitleItem] = []
}

public struct KroutonConsoleMasteringConfig: Equatable, Codable, Sendable {
    public var romWriteModeDAO96SubQ: Bool = true
    public var romBitsetDVDROM: Bool = true
    public var romPerformOPCBeforeWrite: Bool = true
    public var xboxLayerBreakPreset: String = "Auto (.dvd / Calculate Optimal)"
    public var ps1AutoMergeMultiBinAndCHD: Bool = true
    public var wiiLayerMode: String = "Auto-Detect (DVD5 4.7GB / DVD9 LBA 2084960)"

    public init() {}
}

public enum KroutonWebEndpoints {
    public static let homeURLString = "https://krouton.app"
    public static let krutSchemaURLString = "https://krouton.app/schema/krut/v1.json"

}

// MARK: - Unified Hardware-Agnostic .krut Core Mastering Spec (Shared by Local .krut Sidecars & Krumb LAN Wire Protocol)

public struct KroutonKrutCoreSpec: Codable, Hashable, Sendable {
    var specVersion: String
    public var formatID: String
    public var volumeTitle: String
    public var sectorSizeBytes: Int
    public var totalSectorsLBA: Int64
    public var expectedPayloadBytes: Int64
    public var payloadSHA256Hex: String
    public var writeMethod: String
    public var dualLayerBreakSectorLBA: Int64?
    public var forceDVDROMBookType: Bool
    public var performOPCBeforeWrite: Bool
    public var ephemeralAutoPurgeOnComplete: Bool

    public init(
        specVersion: String = "1.0",
        formatID: String = "data-hybrid",
        volumeTitle: String = "KROUTON_DISC",
        sectorSizeBytes: Int = 2048,
        totalSectorsLBA: Int64 = 0,
        expectedPayloadBytes: Int64 = 0,
        payloadSHA256Hex: String = "",
        writeMethod: String = "DAO / SAO Sector-Exact",
        dualLayerBreakSectorLBA: Int64? = nil,
        forceDVDROMBookType: Bool = true,
        performOPCBeforeWrite: Bool = true,
        ephemeralAutoPurgeOnComplete: Bool = true
    ) {
        self.specVersion = specVersion
        self.formatID = formatID
        self.volumeTitle = volumeTitle
        self.sectorSizeBytes = sectorSizeBytes
        self.totalSectorsLBA = totalSectorsLBA
        self.expectedPayloadBytes = expectedPayloadBytes
        self.payloadSHA256Hex = payloadSHA256Hex
        self.writeMethod = writeMethod
        self.dualLayerBreakSectorLBA = dualLayerBreakSectorLBA
        self.forceDVDROMBookType = forceDVDROMBookType
        self.performOPCBeforeWrite = performOPCBeforeWrite
        self.ephemeralAutoPurgeOnComplete = ephemeralAutoPurgeOnComplete
    }

    enum CodingKeys: String, CodingKey {
        case specVersion = "spec_version"
        case formatID = "format_id"
        case volumeTitle = "volume_title"
        case sectorSizeBytes = "sector_size_bytes"
        case totalSectorsLBA = "total_sectors_lba"
        case expectedPayloadBytes = "expected_payload_bytes"
        case payloadSHA256Hex = "payload_sha256_hex"
        case writeMethod = "write_method"
        case dualLayerBreakSectorLBA = "dual_layer_break_lba"
        case forceDVDROMBookType = "force_dvdrom_book_type"
        case performOPCBeforeWrite = "perform_opc_before_write"
        case ephemeralAutoPurgeOnComplete = "ephemeral_auto_purge_on_complete"
    }
}

// MARK: - Cross-Filesystem Path Sanitizer & ChaCha20-Poly1305 .krut Encryption Engine

public enum KroutonKrutSecurityEngine {
    /// Rejects relative paths attempting directory traversal ('..') or root escapes across NTFS, exFAT, ext4, Btrfs & APFS
    public static func isSafeRelativePath(_ relPath: String) -> Bool {
        let normalized = relPath.replacingOccurrences(of: "\\", with: "/")
        if normalized.hasPrefix("/") || normalized.hasPrefix("~") { return false }
        let parts = normalized.split(separator: "/", omittingEmptySubsequences: false).map(String.init)
        return !parts.contains("..")
    }

    /// Normalizes Windows backslashes and NFD decomposed Unicode to NFC for NTFS / exFAT / ext4 / Btrfs compatibility
    public static func normalizeCrossFilesystemPath(_ rawPath: String) -> String {
        rawPath.replacingOccurrences(of: "\\", with: "/").precomposedStringWithCanonicalMapping
    }

    /// Encrypts a .krut payload with AEAD ChaCha20-Poly1305 and HKDF-SHA256
    public static func sealKrutPayload(_ plainData: Data, passphrase: String, salt: Data) throws -> Data {
        let key = HKDF<SHA256>.deriveKey(
            inputKeyMaterial: SymmetricKey(data: Data(passphrase.precomposedStringWithCanonicalMapping.utf8)),
            salt: salt,
            info: Data("app.krouton.optical.krut.v1".utf8),
            outputByteCount: 32
        )
        return try ChaChaPoly.seal(plainData, using: key).combined
    }

    /// Opens and authenticates an AEAD ChaCha20-Poly1305 .krut payload (rejects wrong passphrase or bit-tampering)
    public static func openKrutPayload(_ combinedData: Data, passphrase: String, salt: Data) -> Data? {
        let key = HKDF<SHA256>.deriveKey(
            inputKeyMaterial: SymmetricKey(data: Data(passphrase.precomposedStringWithCanonicalMapping.utf8)),
            salt: salt,
            info: Data("app.krouton.optical.krut.v1".utf8),
            outputByteCount: 32
        )
        guard let box = try? ChaChaPoly.SealedBox(combined: combinedData) else { return nil }
        return try? ChaChaPoly.open(box, using: key)
    }
}

// MARK: - Editable Vector Disc Label Scene Graph Models (Stored in Every .krut File)

public struct KroutonRGBAColor: Codable, Hashable, Sendable {
    public var r: Double
    public var g: Double
    public var b: Double
    public var a: Double

    public init(r: Double, g: Double, b: Double, a: Double = 1.0) {
        self.r = r
        self.g = g
        self.b = b
        self.a = a
    }
}

public enum KroutonVectorBackgroundStyle: String, Codable, CaseIterable, Identifiable, Sendable {
    case templateDefault = "Template Default"
    case solidColor      = "Solid Color"
    case linearGradient  = "Linear Gradient"
    case radialGradient  = "Radial Gradient"
    case angularGradient = "Angular Sweep"
    case gpuKaleidoscope = "GPU Kaleidoscope"
    case tinyPlanetGlobe = "360° Tiny Planet"
    public var id: String { rawValue }
}

public struct KroutonBackgroundAdjustments: Codable, Hashable, Sendable {
    public var blurRadius: Double = 0.0
    public var brightness: Double = 0.0
    public var contrast: Double = 1.0
    public var hueDegrees: Double = 0.0
    public var saturation: Double = 1.0

    public init(
        blurRadius: Double = 0.0,
        brightness: Double = 0.0,
        contrast: Double = 1.0,
        hueDegrees: Double = 0.0,
        saturation: Double = 1.0
    ) {
        self.blurRadius = blurRadius
        self.brightness = brightness
        self.contrast = contrast
        self.hueDegrees = hueDegrees
        self.saturation = saturation
    }

    public var isIdentity: Bool {
        abs(blurRadius) < 0.05 &&
        abs(brightness) < 0.005 &&
        abs(contrast - 1.0) < 0.005 &&
        abs(hueDegrees) < 0.1 &&
        abs(saturation - 1.0) < 0.005
    }
}

public enum KroutonKaleidoscopeMirrorRig: String, Codable, CaseIterable, Identifiable, Sendable {
    case twoMirrorRosette  = "2-Mirror Mandala"
    case threeMirrorPrism  = "3-Mirror Triangle Lattice"
    case eightFoldStarTile = "8-Fold Star Tile"
    public var id: String { rawValue }
}

public enum KroutonGPUSeedPattern: String, Codable, CaseIterable, Identifiable, Sendable {
    case neonLaserPrism   = "Neon Laser Prism"
    case cyberSunburst    = "Cyber Sunburst Horizon"
    case holographicFoil  = "Holographic Lenticular Foil"
    case cmykHalftone     = "Retro CMYK Halftone"
    public var id: String { rawValue }
}

public enum KroutonVectorShapeKind: String, Codable, CaseIterable, Identifiable, Sendable {
    case line           = "Diagonal Line"
    case curveArc       = "Bezier Arc"
    case roundedRect    = "Rounded Square"
    case circle         = "Circle"
    case triangle       = "Triangle"
    case pentagon       = "Pentagon"
    case rectangle      = "Square"
    case diamond        = "Diamond"
    case capsule        = "Capsule Pill"
    case parallelogram  = "Parallelogram"
    case arrow          = "Arrow"
    case star           = "5-Point Star"
    case concentricRing = "Concentric Ring"
    case polygon        = "Polygon"
    case smoothBezier   = "Smooth Curve"
    case visionContour  = "Vision Contour"
    public var id: String { rawValue }
}

public struct KroutonNormalizedPoint: Codable, Hashable, Sendable {
    public var nx: Double
    public var ny: Double

    public init(nx: Double, ny: Double) {
        self.nx = nx
        self.ny = ny
    }
}

public struct KroutonLabelTextElement: Codable, Hashable, Identifiable, Sendable {
    public var id: UUID
    public var text: String
    public var isCurvedArc: Bool
    public var radiusMM: Double
    public var angleDegrees: Double
    public var fontSizePoints: Double
    public var letterTracking: Double
    public var isBottomUpright: Bool
    public var isBold: Bool
    public var hasDropShadow: Bool = false
    public var fontDesignRaw: String
    public var color: KroutonRGBAColor

    public init(
        id: UUID = UUID(),
        text: String = "NEW DISC TITLE",
        isCurvedArc: Bool = true,
        radiusMM: Double = 44.0,
        angleDegrees: Double = 0.0,
        fontSizePoints: Double = 16.0,
        letterTracking: Double = 1.0,
        isBottomUpright: Bool = false,
        isBold: Bool = true,
        fontDesignRaw: String = "Default",
        color: KroutonRGBAColor = KroutonRGBAColor(r: 0.10, g: 0.11, b: 0.14, a: 1.0)
    ) {
        self.id = id
        self.text = text
        self.isCurvedArc = isCurvedArc
        self.radiusMM = radiusMM
        self.angleDegrees = angleDegrees
        self.fontSizePoints = fontSizePoints
        self.letterTracking = letterTracking
        self.isBottomUpright = isBottomUpright
        self.isBold = isBold
        self.fontDesignRaw = fontDesignRaw
        self.color = color
    }
}

public struct KroutonVectorShapeLayer: Codable, Hashable, Identifiable, Sendable {
    public var id: UUID
    public var name: String
    public var kind: KroutonVectorShapeKind
    public var points: [KroutonNormalizedPoint]
    public var strokeWidthPoints: Double
    public var isClosed: Bool
    public var strokeColor: KroutonRGBAColor
    public var fillColor: KroutonRGBAColor?

    public init(
        id: UUID = UUID(),
        name: String,
        kind: KroutonVectorShapeKind,
        points: [KroutonNormalizedPoint],
        strokeWidthPoints: Double = 2.2,
        isClosed: Bool = true,
        strokeColor: KroutonRGBAColor = KroutonRGBAColor(r: 0.25, g: 0.88, b: 0.96, a: 1.0),
        fillColor: KroutonRGBAColor? = nil
    ) {
        self.id = id
        self.name = name
        self.kind = kind
        self.points = points
        self.strokeWidthPoints = strokeWidthPoints
        self.isClosed = isClosed
        self.strokeColor = strokeColor
        self.fillColor = fillColor
    }
}

public struct KroutonEmbeddedLabelSpec: Codable, Hashable, Sendable {
    var specVersion: String
    public var primaryArcTitle: String
    public var bottomSubtitle: String
    public var performer: String
    public var mcnCatalogBarcode: String
    public var templateStyleRaw: String
    public var trayPresetName: String
    public var outerDiameterMM: Double
    public var innerDiameterMM: Double
    public var offsetXMM: Double
    public var offsetYMM: Double
    public var showTracklistOnDisc: Bool
    public var stampedTracklistLines: [String]
    public var accentPresetIndex: Int
    public var useHarmonySplitComplement: Bool
    public var autoSearchQuery: String
    public var backgroundStyle: KroutonVectorBackgroundStyle = .templateDefault
    public var backgroundPrimaryColor: KroutonRGBAColor = KroutonRGBAColor(r: 0.08, g: 0.10, b: 0.15)
    public var backgroundSecondaryColor: KroutonRGBAColor = KroutonRGBAColor(r: 0.18, g: 0.36, b: 0.62)
    public var gradientAngleDegrees: Double = 45.0
    public var gpuSeedPattern: KroutonGPUSeedPattern = .neonLaserPrism
    public var kaleidoscopeFacetCount: Int = 8
    public var kaleidoscopeMirrorRig: KroutonKaleidoscopeMirrorRig = .twoMirrorRosette
    public var kaleidoscopeChamberTumble: Double = 0.35
    public var tinyPlanetRadiusRatio: Double = 0.72
    public var useVisionForegroundCutout: Bool = false
    public var topArcRadiusMM: Double = 47.0
    public var bottomArcRadiusMM: Double = 45.0
    public var arcLetterSpacing: Double = 1.0
    public var textElements: [KroutonLabelTextElement] = []
    public var gradientMidpointRatio: Double = 0.50
    public var bgAdjustments: KroutonBackgroundAdjustments = KroutonBackgroundAdjustments()
    public var vectorShapeLayers: [KroutonVectorShapeLayer] = []
    var renderedPreviewPNGBase64: String?

    public init(
        specVersion: String = "1.0",
        primaryArcTitle: String = "THE KROUTON ARCHIVE",
        bottomSubtitle: String = "2026 MASTER EDITION",
        performer: String = "The Kroutons",
        mcnCatalogBarcode: String = "0123456789012",
        templateStyleRaw: String = "Synth Technical Grid",
        trayPresetName: String = "Epson ET-8550 Full Hub (120mm / 18mm)",
        outerDiameterMM: Double = 120.0,
        innerDiameterMM: Double = 18.0,
        offsetXMM: Double = 0.0,
        offsetYMM: Double = 0.0,
        showTracklistOnDisc: Bool = true,
        stampedTracklistLines: [String] = [],
        accentPresetIndex: Int = 8,
        useHarmonySplitComplement: Bool = true,
        autoSearchQuery: String = "",
        renderedPreviewPNGBase64: String? = nil
    ) {
        self.specVersion = specVersion
        self.primaryArcTitle = primaryArcTitle
        self.bottomSubtitle = bottomSubtitle
        self.performer = performer
        self.mcnCatalogBarcode = mcnCatalogBarcode
        self.templateStyleRaw = templateStyleRaw
        self.trayPresetName = trayPresetName
        self.outerDiameterMM = outerDiameterMM
        self.innerDiameterMM = innerDiameterMM
        self.offsetXMM = offsetXMM
        self.offsetYMM = offsetYMM
        self.showTracklistOnDisc = showTracklistOnDisc
        self.stampedTracklistLines = stampedTracklistLines
        self.accentPresetIndex = accentPresetIndex
        self.useHarmonySplitComplement = useHarmonySplitComplement
        self.autoSearchQuery = autoSearchQuery
        self.renderedPreviewPNGBase64 = renderedPreviewPNGBase64
    }
}
