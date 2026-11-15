import DriveKit
import ImageIO
import SwiftUI
import Foundation
import CryptoKit
import UniformTypeIdentifiers
import OpticalCore

// MARK: - .krut Optical Mastering Workspace Project Format, Sidecar Ticket & Encrypted Vault

public extension UTType {
    static var kroutonProject: UTType {
        UTType(filenameExtension: "krut", conformingTo: .json) ?? .json
    }
}

public struct KroutonProjectSourceRecord: Codable, Hashable, Sendable {
    public var absolutePath: String
    public var relativePath: String?
    public var bookmarkData: Data?
    public var name: String
    public var isDirectory: Bool
    public var byteSize: Int64
    public var itemCount: Int
    public var posixPermissions: String
    public var showOnMac: Bool
    public var showOnPC: Bool

    public static func redactHomePath(_ rawPath: String) -> String {
        let normalized = KroutonKrutSecurityEngine.normalizeCrossFilesystemPath(rawPath)
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        if normalized.hasPrefix(home + "/") {
            return "~/" + String(normalized.dropFirst(home.count + 1))
        }
        return normalized
    }

    public init(from entry: KroutonStagedFileEntry, relativeTo projectURL: URL? = nil) {
        self.absolutePath = Self.redactHomePath(entry.url.path)
        if let baseDir = projectURL?.deletingLastPathComponent().path,
           entry.url.path.hasPrefix(baseDir + "/") {
            let rel = String(entry.url.path.dropFirst(baseDir.count + 1))
            self.relativePath = KroutonKrutSecurityEngine.normalizeCrossFilesystemPath(rel)
        } else {
            self.relativePath = nil
        }
        self.bookmarkData = try? entry.url.bookmarkData(options: .minimalBookmark, includingResourceValuesForKeys: nil, relativeTo: nil)
        self.name = entry.name.precomposedStringWithCanonicalMapping
        self.isDirectory = entry.isDirectory
        self.byteSize = entry.byteSize
        self.itemCount = entry.itemCount
        self.posixPermissions = entry.posixPermissions
        self.showOnMac = entry.showOnMac
        self.showOnPC = entry.showOnPC
    }

    /// 4-tier cross-filesystem resolver (APFS Inode -> Safe Relative Path -> Case-Insensitive ext4/Btrfs/NTFS -> Expanded '~' Path)
    public func resolveURL(relativeTo projectURL: URL? = nil) -> (url: URL, isMissing: Bool) {
        let fm = FileManager.default
        if let bm = bookmarkData {
            var isStale = false
            if let resolved = try? URL(resolvingBookmarkData: bm, options: .withoutUI, relativeTo: nil, bookmarkDataIsStale: &isStale),
               fm.fileExists(atPath: resolved.path) {
                return (resolved, false)
            }
        }
        if let rel = relativePath, KroutonKrutSecurityEngine.isSafeRelativePath(rel),
           let baseDir = projectURL?.deletingLastPathComponent() {
            let candidate = baseDir.appendingPathComponent(rel).standardizedFileURL
            if candidate.path.hasPrefix(baseDir.standardizedFileURL.path) {
                if fm.fileExists(atPath: candidate.path) {
                    return (candidate, false)
                }
                let parentDir = candidate.deletingLastPathComponent()
                let targetLower = candidate.lastPathComponent.precomposedStringWithCanonicalMapping.lowercased()
                if let siblings = try? fm.contentsOfDirectory(at: parentDir, includingPropertiesForKeys: nil),
                   let matched = siblings.first(where: { $0.lastPathComponent.precomposedStringWithCanonicalMapping.lowercased() == targetLower }) {
                    return (matched, false)
                }
            }
        }
        let expandedAbs = (absolutePath as NSString).expandingTildeInPath
        let absURL = URL(fileURLWithPath: expandedAbs)
        return (absURL, !fm.fileExists(atPath: absURL.path))
    }
}

public struct KroutonSavedDestinationRecord: Codable, Hashable, Sendable {
    public var kindRawValue: String
    public var targetDriveID: String
    public var hardwareOrPath: String
    public var speedOrCodec: String
    public var simulationMode: Bool
    public var verifyAfterBurn: Bool
    public var compressAfterCreation: Bool
    public var copiesToBurn: Int

    public init(from item: KroutonBakeBatchItem) {
        self.kindRawValue = item.kind.rawValue
        self.targetDriveID = item.targetDriveID
        self.hardwareOrPath = item.hardwareOrPath
        self.speedOrCodec = item.speedOrCodec
        self.simulationMode = item.simulationMode
        self.verifyAfterBurn = item.verifyAfterBurn
        self.compressAfterCreation = item.compressAfterCreation
        self.copiesToBurn = item.copiesToBurn
    }

    public func toBatchItem() -> KroutonBakeBatchItem {
        let resolvedKind = KroutonBurnDestinationKind(rawValue: kindRawValue) ?? .physicalBurner
        return KroutonBakeBatchItem(
            kind: resolvedKind,
            targetDriveID: targetDriveID,
            hardwareOrPath: hardwareOrPath,
            speedOrCodec: speedOrCodec,
            simulationMode: simulationMode,
            verifyAfterBurn: verifyAfterBurn,
            compressAfterCreation: compressAfterCreation,
            copiesToBurn: copiesToBurn
        )
    }
}

public struct KroutonProjectManifest: Codable, Hashable, Sendable {
    public var schemaURL: String = KroutonWebEndpoints.krutSchemaURLString
    public var generatorURL: String = KroutonWebEndpoints.homeURLString
    public var schemaVersion: String = "1.0"
    public var savedAtISO8601: String
    public var isSidecarFile: Bool = false
    public var coreSpec: KroutonKrutCoreSpec
    public var selectedCategoryRaw: String
    public var selectedTaskID: String
    public var discVolumeTitle: String
    public var discPerformer: String
    public var discMCNBarcode: String
    public var discLabel: KroutonEmbeddedLabelSpec = KroutonEmbeddedLabelSpec()
    public var labelDiscTitle: String
    public var labelSubtitle: String
    public var labelTemplateRaw: String
    public var labelPresetIndex: Int
    public var labelShowTracklistOnDisc: Bool
    public var stagedSources: [KroutonProjectSourceRecord]
    public var activeQueue: [KroutonSavedDestinationRecord]
    public var savedQueuesByDomain: [String: [KroutonSavedDestinationRecord]]

    public static let maxAllowedKrutBytes: Int = 16 * 1024 * 1024

    public func encodePrettyJSON() throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(self)
    }

    public static func decode(from data: Data) throws -> KroutonProjectManifest {
        guard data.count <= maxAllowedKrutBytes else {
            throw CocoaError(.fileReadTooLarge)
        }
        return try JSONDecoder().decode(KroutonProjectManifest.self, from: data)
    }
}

public struct KroutonProjectFileDocument: FileDocument {
    public static var readableContentTypes: [UTType] { [.kroutonProject, .json] }
    public var jsonData: Data

    public init(jsonData: Data = Data()) {
        self.jsonData = jsonData
    }

    public init(configuration: ReadConfiguration) throws {
        self.jsonData = configuration.file.regularFileContents ?? Data()
    }

    public func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: jsonData)
    }
}

@MainActor
public final class KroutonProjectDialogBridge: ObservableObject {
    public static let shared = KroutonProjectDialogBridge()
    @Published public var isShowingExporter: Bool = false
    @Published public var isShowingImporter: Bool = false
    @Published public var exportDocument: KroutonProjectFileDocument = KroutonProjectFileDocument()
    @Published public var defaultFilename: String = "Krouton_Master.krut"
}

@MainActor
extension KroutonStateStore {
    public func buildProjectManifest(
        relativeTo projectURL: URL? = nil,
        isSidecar: Bool = false,
        verifiedSHA256: String = "",
        writeMethod: String = "DAO / SAO Sector-Exact"
    ) -> KroutonProjectManifest {
        snapshotCurrentDestinationQueue()
        var domainMap: [String: [KroutonSavedDestinationRecord]] = [:]
        for (k, v) in savedQueuesByDomain {
            domainMap[k] = v.map { KroutonSavedDestinationRecord(from: $0) }
        }
        let spec = activeFormatSpec()
        let sectorSize = (spec.workspaceKind == .redBookAudio || spec.id == "console-ps1") ? 2352 : 2048
        let core = KroutonKrutCoreSpec(
            formatID: selectedTaskID,
            volumeTitle: discVolumeTitle,
            sectorSizeBytes: sectorSize,
            totalSectorsLBA: totalStagedSectorsLBA,
            expectedPayloadBytes: totalStagedBytes,
            payloadSHA256Hex: verifiedSHA256,
            writeMethod: writeMethod,
            dualLayerBreakSectorLBA: dualLayerBreakSectorLBA,
            forceDVDROMBookType: forceDVDROMBookType,
            performOPCBeforeWrite: true,
            ephemeralAutoPurgeOnComplete: true
        )
        let activePreset = labelPresets[min(max(0, selectedLabelPresetIndex), max(0, labelPresets.count - 1))]
        let resolvedLines: [String] = !stagedFiles.isEmpty
            ? stagedFiles.prefix(8).enumerated().map { idx, f in String(format: "%02d. %@", idx + 1, f.name) }
            : redBookTracks.prefix(8).map { $0.title }
        let effectiveLabelTitle = (labelDiscTitle.isEmpty && discVolumeTitle != "KROUTON_DISC" && !discVolumeTitle.isEmpty)
            ? discVolumeTitle
            : labelDiscTitle

        let (r1, g1, b1, a1) = KroutonPureColorMath.extractSRGB(labelBgPrimaryColor)
        let (r2, g2, b2, a2) = KroutonPureColorMath.extractSRGB(labelBgSecondaryColor)
        var embeddedLabel = KroutonEmbeddedLabelSpec(
            primaryArcTitle: effectiveLabelTitle,
            bottomSubtitle: labelSubtitle,
            performer: discPerformer,
            mcnCatalogBarcode: discMCNBarcode,
            templateStyleRaw: selectedLabelTemplate.rawValue,
            trayPresetName: activePreset.name,
            outerDiameterMM: activePreset.outerDiameterMM,
            innerDiameterMM: activePreset.innerDiameterMM,
            offsetXMM: activePreset.offsetXMM,
            offsetYMM: activePreset.offsetYMM,
            showTracklistOnDisc: labelShowTracklistOnDisc,
            stampedTracklistLines: resolvedLines,
            accentPresetIndex: selectedAccentIndex,
            useHarmonySplitComplement: enableSecondaryAccentUITints,
            autoSearchQuery: autoLabelSearchQuery
        )
        embeddedLabel.backgroundStyle = labelBackgroundStyle
        embeddedLabel.backgroundPrimaryColor = KroutonRGBAColor(r: Double(r1), g: Double(g1), b: Double(b1), a: Double(a1))
        embeddedLabel.backgroundSecondaryColor = KroutonRGBAColor(r: Double(r2), g: Double(g2), b: Double(b2), a: Double(a2))
        embeddedLabel.gradientAngleDegrees = labelGradientAngle
        embeddedLabel.topArcRadiusMM = labelTopArcRadiusMM
        embeddedLabel.bottomArcRadiusMM = labelBottomArcRadiusMM
        embeddedLabel.arcLetterSpacing = labelArcLetterSpacing
        embeddedLabel.vectorShapeLayers = labelVectorShapes
        embeddedLabel.textElements = labelTextElements
        embeddedLabel.gradientMidpointRatio = labelGradientMidpoint
        embeddedLabel.bgAdjustments = labelBgAdjustments
        embeddedLabel.gpuSeedPattern = labelGPUSeedPattern
        embeddedLabel.kaleidoscopeFacetCount = labelKaleidoscopeFacets
        embeddedLabel.kaleidoscopeMirrorRig = labelKaleidoscopeRig
        embeddedLabel.kaleidoscopeChamberTumble = labelChamberTumble
        embeddedLabel.tinyPlanetRadiusRatio = labelTinyPlanetRadius
        embeddedLabel.useVisionForegroundCutout = labelUseVisionForeground

        return KroutonProjectManifest(
            savedAtISO8601: ISO8601DateFormatter().string(from: Date()),
            isSidecarFile: isSidecar,
            coreSpec: core,
            selectedCategoryRaw: selectedCategory.rawValue,
            selectedTaskID: selectedTaskID,
            discVolumeTitle: discVolumeTitle,
            discPerformer: discPerformer,
            discMCNBarcode: discMCNBarcode,
            discLabel: embeddedLabel,
            labelDiscTitle: effectiveLabelTitle,
            labelSubtitle: labelSubtitle,
            labelTemplateRaw: selectedLabelTemplate.rawValue,
            labelPresetIndex: selectedLabelPresetIndex,
            labelShowTracklistOnDisc: labelShowTracklistOnDisc,
            stagedSources: stagedFiles.map { KroutonProjectSourceRecord(from: $0, relativeTo: projectURL) },
            activeQueue: destinationQueue.map { KroutonSavedDestinationRecord(from: $0) },
            savedQueuesByDomain: domainMap
        )
    }

    public func applyProjectManifest(_ manifest: KroutonProjectManifest, projectURL: URL? = nil, driveManager: KroutonOpticalDriveBank? = nil) {
        if let cat = KroutonMasteringStation(rawValue: manifest.selectedCategoryRaw) {
            selectedCategory = cat
        }
        selectedTaskID = manifest.selectedTaskID
        discVolumeTitle = manifest.discVolumeTitle
        discPerformer = manifest.discPerformer
        discMCNBarcode = manifest.discMCNBarcode
        let lbl = manifest.discLabel
        labelDiscTitle = !lbl.primaryArcTitle.isEmpty ? lbl.primaryArcTitle : manifest.labelDiscTitle
        labelSubtitle = !lbl.bottomSubtitle.isEmpty ? lbl.bottomSubtitle : manifest.labelSubtitle
        if let tpl = KroutonCroutonLabelStyle(rawValue: lbl.templateStyleRaw) ?? KroutonCroutonLabelStyle(rawValue: manifest.labelTemplateRaw) {
            selectedLabelTemplate = tpl
        }
        selectedLabelPresetIndex = min(max(0, manifest.labelPresetIndex), max(0, labelPresets.count - 1))
        labelShowTracklistOnDisc = lbl.showTracklistOnDisc
        labelBackgroundStyle = lbl.backgroundStyle
        labelBgPrimaryColor = Color(red: lbl.backgroundPrimaryColor.r, green: lbl.backgroundPrimaryColor.g, blue: lbl.backgroundPrimaryColor.b, opacity: lbl.backgroundPrimaryColor.a)
        labelBgSecondaryColor = Color(red: lbl.backgroundSecondaryColor.r, green: lbl.backgroundSecondaryColor.g, blue: lbl.backgroundSecondaryColor.b, opacity: lbl.backgroundSecondaryColor.a)
        labelGradientAngle = lbl.gradientAngleDegrees
        labelTopArcRadiusMM = lbl.topArcRadiusMM
        labelBottomArcRadiusMM = lbl.bottomArcRadiusMM
        labelArcLetterSpacing = lbl.arcLetterSpacing
        labelVectorShapes = lbl.vectorShapeLayers
        labelTextElements = lbl.textElements
        labelGradientMidpoint = lbl.gradientMidpointRatio
        labelBgAdjustments = lbl.bgAdjustments
        labelGPUSeedPattern = lbl.gpuSeedPattern
        labelKaleidoscopeFacets = lbl.kaleidoscopeFacetCount
        labelKaleidoscopeRig = lbl.kaleidoscopeMirrorRig
        labelChamberTumble = lbl.kaleidoscopeChamberTumble
        labelTinyPlanetRadius = lbl.tinyPlanetRadiusRatio
        labelUseVisionForeground = lbl.useVisionForegroundCutout
        if let breakLBA = manifest.coreSpec.dualLayerBreakSectorLBA {
            dualLayerBreakSectorLBA = breakLBA
        }
        forceDVDROMBookType = manifest.coreSpec.forceDVDROMBookType

        var restoredDomainMap: [String: [KroutonBakeBatchItem]] = [:]
        for (k, records) in manifest.savedQueuesByDomain {
            restoredDomainMap[k] = records.map { $0.toBatchItem() }
        }
        savedQueuesByDomain = restoredDomainMap

        let restoredQueue = manifest.activeQueue.map { $0.toBatchItem() }
        if !restoredQueue.isEmpty {
            destinationQueue = restoredQueue
        }

        var missingNames: [String] = []
        var restoredFiles: [KroutonStagedFileEntry] = []
        for src in manifest.stagedSources {
            let (resolvedURL, isMissing) = src.resolveURL(relativeTo: projectURL)
            if isMissing {
                missingNames.append(src.name)
            }
            let entry = KroutonStagedFileEntry(
                url: resolvedURL,
                name: src.name,
                isDirectory: src.isDirectory,
                byteSize: src.byteSize,
                itemCount: src.itemCount,
                posixPermissions: src.posixPermissions,
                modifiedDate: Date(),
                showOnMac: src.showOnMac,
                showOnPC: src.showOnPC
            )
            restoredFiles.append(entry)
        }
        stagedFiles = restoredFiles

        if !missingNames.isEmpty {
            rejectedDropNotice = "Offline Media Notice: \(missingNames.count) source file(s) (\(missingNames.joined(separator: ", "))) could not be found at their original path."
        } else {
            rejectedDropNotice = nil
        }

        if let dm = driveManager {
            reconcileUniqueDriveAssignments(driveManager: dm)
        }
    }

    public func presentSaveKrutProjectSheet() {
        guard let data = try? buildProjectManifest().encodePrettyJSON() else { return }
        let cleanTitle = discVolumeTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? "Krouton_Master"
            : discVolumeTitle.replacingOccurrences(of: " ", with: "_")
        KroutonProjectDialogBridge.shared.exportDocument = KroutonProjectFileDocument(jsonData: data)
        KroutonProjectDialogBridge.shared.defaultFilename = "\(cleanTitle).krut"
        KroutonProjectDialogBridge.shared.isShowingExporter = true
    }

    public func presentOpenKrutProjectSheet() {
        KroutonProjectDialogBridge.shared.isShowingImporter = true
    }
}
