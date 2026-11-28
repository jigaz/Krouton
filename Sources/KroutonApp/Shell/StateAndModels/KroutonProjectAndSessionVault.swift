import CryptoKit
import DriveKit
import Foundation
import ImageIO
import Observation
import OpticalCore
import SwiftUI
import UniformTypeIdentifiers

// MARK: - .krut Optical Mastering Workspace Project Format, Sidecar Ticket & Encrypted Vault

extension UTType {
    static var kroutonProject: UTType {
        UTType(filenameExtension: "krut", conformingTo: .json) ?? .json
    }
}

struct KroutonProjectSourceRecord: Codable, Hashable, Sendable {
    var absolutePath: String
    var relativePath: String?
    var bookmarkData: Data?
    var name: String
    var isDirectory: Bool
    var byteSize: Int64
    var itemCount: Int
    var posixPermissions: String
    var showOnMac: Bool
    var showOnPC: Bool

    static func redactHomePath(_ rawPath: String) -> String {
        let normalized = KroutonKrutSecurityEngine.normalizeCrossFilesystemPath(rawPath)
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        if normalized.hasPrefix(home + "/") {
            return "~/" + String(normalized.dropFirst(home.count + 1))
        }
        return normalized
    }

    init(from entry: KroutonStagedFileEntry, relativeTo projectURL: URL? = nil) {
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
    func resolveURL(relativeTo projectURL: URL? = nil) -> (url: URL, isMissing: Bool) {
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

struct KroutonSavedDestinationRecord: Codable, Hashable, Sendable {
    var kindRawValue: String
    var targetDriveID: String
    var hardwareOrPath: String
    var speedOrCodec: String
    var simulationMode: Bool
    var verifyAfterBurn: Bool
    var compressAfterCreation: Bool
    var copiesToBurn: Int

    init(from item: KroutonBakeBatchItem) {
        self.kindRawValue = item.kind.rawValue
        self.targetDriveID = item.targetDriveID
        self.hardwareOrPath = item.hardwareOrPath
        self.speedOrCodec = item.speedOrCodec
        self.simulationMode = item.simulationMode
        self.verifyAfterBurn = item.verifyAfterBurn
        self.compressAfterCreation = item.compressAfterCreation
        self.copiesToBurn = item.copiesToBurn
    }

    /// The card, or nil when its kind is one this version doesn't know. Before 2026-11-27 an
    /// unknown kind came back as a disc burner, so a rip card could return as a burn.
    func toBatchItem() -> KroutonBakeBatchItem? {
        guard let resolvedKind = KroutonBurnDestinationKind(storedValue: kindRawValue) else { return nil }
        return KroutonBakeBatchItem(
            kind: resolvedKind,
            targetDriveID: targetDriveID,
            hardwareOrPath: hardwareOrPath,
            speedOrCodec: speedOrCodec,
            simulationMode: simulationMode,
            verifyAfterBurn: verifyAfterBurn,
            compressAfterCreation: compressAfterCreation,
            copiesToBurn: copiesToBurn
        ).repairingLegacyPresets()
    }
}

struct KroutonProjectManifest: Codable, Hashable, Sendable {
    var schemaURL: String = KroutonWebEndpoints.krutSchemaURLString
    var generatorURL: String = KroutonWebEndpoints.homeURLString
    var schemaVersion: String = "1.0"
    var savedAtISO8601: String
    var isSidecarFile: Bool = false
    var coreSpec: KroutonKrutCoreSpec
    var selectedCategoryRaw: String
    var selectedTaskID: String
    var discVolumeTitle: String
    var discPerformer: String
    var discMCNBarcode: String
    var discLabel: KroutonEmbeddedLabelSpec = KroutonEmbeddedLabelSpec()
    var labelDiscTitle: String
    var labelSubtitle: String
    var labelTemplateRaw: String
    var labelPresetIndex: Int
    var labelShowTracklistOnDisc: Bool
    var stagedSources: [KroutonProjectSourceRecord]
    var activeQueue: [KroutonSavedDestinationRecord]
    var savedQueuesByDomain: [String: [KroutonSavedDestinationRecord]]

    static let maxAllowedKrutBytes: Int = 16 * 1024 * 1024

    func encodePrettyJSON() throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(self)
    }

    /// Reads a project saved by this or another version; what an older or newer file lacks is
    /// filled in from `persistedDefault` and listed in `repairs` (see `KroutonPersistedJSON`).
    static func decode(from data: Data) throws -> KroutonPersistedJSON.Result<KroutonProjectManifest> {
        guard data.count <= maxAllowedKrutBytes else {
            throw CocoaError(.fileReadTooLarge)
        }
        return try KroutonPersistedJSON.decode(KroutonProjectManifest.self, from: data)
    }
}

struct KroutonProjectFileDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.kroutonProject, .json] }
    var jsonData: Data

    init(jsonData: Data = Data()) {
        self.jsonData = jsonData
    }

    init(configuration: ReadConfiguration) throws {
        self.jsonData = configuration.file.regularFileContents ?? Data()
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: jsonData)
    }
}

@Observable
@MainActor
final class KroutonProjectDialogBridge {
    static let shared = KroutonProjectDialogBridge()
    var isShowingExporter: Bool = false
    var isShowingImporter: Bool = false
    var exportDocument: KroutonProjectFileDocument = KroutonProjectFileDocument()
    var defaultFilename: String = "Krouton_Master.krut"
}

@MainActor
extension KroutonStateStore {
    func buildProjectManifest(
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
            forceDVDROMBookType: false,
            performOPCBeforeWrite: true,
            ephemeralAutoPurgeOnComplete: true
        )
        let activePreset = self.labelPresets[min(max(0, self.selectedLabelPresetIndex), max(0, self.labelPresets.count - 1))]
        let resolvedLines: [String] = !stagedFiles.isEmpty
            ? stagedFiles.prefix(8).enumerated().map { idx, f in String(format: "%02d. %@", idx + 1, f.name) }
            : redBookTracks.prefix(8).map { $0.title }
        let effectiveLabelTitle = (self.labelDiscTitle.isEmpty && discVolumeTitle != "KROUTON_DISC" && !discVolumeTitle.isEmpty)
            ? discVolumeTitle
            : self.labelDiscTitle

        let (r1, g1, b1, a1) = KroutonPureColorMath.extractSRGB(self.labelBgPrimaryColor)
        let (r2, g2, b2, a2) = KroutonPureColorMath.extractSRGB(self.labelBgSecondaryColor)
        var embeddedLabel = KroutonEmbeddedLabelSpec(
            primaryArcTitle: effectiveLabelTitle,
            bottomSubtitle: self.labelSubtitle,
            performer: discPerformer,
            mcnCatalogBarcode: discMCNBarcode,
            templateStyleRaw: self.selectedLabelTemplate.rawValue,
            trayPresetName: activePreset.name,
            outerDiameterMM: activePreset.outerDiameterMM,
            innerDiameterMM: activePreset.innerDiameterMM,
            offsetXMM: activePreset.offsetXMM,
            offsetYMM: activePreset.offsetYMM,
            showTracklistOnDisc: self.labelShowTracklistOnDisc,
            stampedTracklistLines: resolvedLines,
            accentPresetIndex: self.selectedAccentIndex,
            useHarmonySplitComplement: self.enableSecondaryAccentUITints,
            autoSearchQuery: self.autoLabelSearchQuery
        )
        embeddedLabel.backgroundStyle = self.labelBackgroundStyle
        embeddedLabel.backgroundPrimaryColor = KroutonRGBAColor(r: Double(r1), g: Double(g1), b: Double(b1), a: Double(a1))
        embeddedLabel.backgroundSecondaryColor = KroutonRGBAColor(r: Double(r2), g: Double(g2), b: Double(b2), a: Double(a2))
        embeddedLabel.gradientAngleDegrees = self.labelGradientAngle
        embeddedLabel.topArcRadiusMM = self.labelTopArcRadiusMM
        embeddedLabel.bottomArcRadiusMM = self.labelBottomArcRadiusMM
        embeddedLabel.arcLetterSpacing = self.labelArcLetterSpacing
        embeddedLabel.vectorShapeLayers = self.labelVectorShapes
        embeddedLabel.textElements = self.labelTextElements
        embeddedLabel.gradientMidpointRatio = self.labelGradientMidpoint
        embeddedLabel.bgAdjustments = self.labelBgAdjustments
        embeddedLabel.gpuSeedPattern = self.labelGPUSeedPattern
        embeddedLabel.kaleidoscopeFacetCount = self.labelKaleidoscopeFacets
        embeddedLabel.kaleidoscopeMirrorRig = self.labelKaleidoscopeRig
        embeddedLabel.kaleidoscopeChamberTumble = self.labelChamberTumble
        embeddedLabel.planet = self.labelPlanet
        embeddedLabel.planetPhotoPath = self.labelPlanetPhotoURL?.path
        embeddedLabel.printSettings = self.labelPrint
        embeddedLabel.useVisionForegroundCutout = self.labelUseVisionForeground

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
            labelSubtitle: self.labelSubtitle,
            labelTemplateRaw: self.selectedLabelTemplate.rawValue,
            labelPresetIndex: self.selectedLabelPresetIndex,
            labelShowTracklistOnDisc: self.labelShowTracklistOnDisc,
            stagedSources: stagedFiles.map { KroutonProjectSourceRecord(from: $0, relativeTo: projectURL) },
            activeQueue: destinationQueue.map { KroutonSavedDestinationRecord(from: $0) },
            savedQueuesByDomain: domainMap
        )
    }

    func applyProjectManifest(_ manifest: KroutonProjectManifest, projectURL: URL? = nil, driveManager: KroutonOpticalDriveBank? = nil) {
        if let cat = KroutonMasteringStation(rawValue: manifest.selectedCategoryRaw) {
            selectedCategory = cat
        }
        selectedTaskID = manifest.selectedTaskID
        discVolumeTitle = manifest.discVolumeTitle
        discPerformer = manifest.discPerformer
        discMCNBarcode = manifest.discMCNBarcode
        let lbl = manifest.discLabel
        self.labelDiscTitle = !lbl.primaryArcTitle.isEmpty ? lbl.primaryArcTitle : manifest.labelDiscTitle
        self.labelSubtitle = !lbl.bottomSubtitle.isEmpty ? lbl.bottomSubtitle : manifest.labelSubtitle
        if let tpl = KroutonCroutonLabelStyle(rawValue: lbl.templateStyleRaw) ?? KroutonCroutonLabelStyle(rawValue: manifest.labelTemplateRaw) {
            self.selectedLabelTemplate = tpl
        }
        self.selectedLabelPresetIndex = min(max(0, manifest.labelPresetIndex), max(0, self.labelPresets.count - 1))
        self.labelShowTracklistOnDisc = lbl.showTracklistOnDisc
        self.labelBackgroundStyle = lbl.backgroundStyle
        self.labelBgPrimaryColor = Color(red: lbl.backgroundPrimaryColor.r, green: lbl.backgroundPrimaryColor.g, blue: lbl.backgroundPrimaryColor.b, opacity: lbl.backgroundPrimaryColor.a)
        self.labelBgSecondaryColor = Color(red: lbl.backgroundSecondaryColor.r, green: lbl.backgroundSecondaryColor.g, blue: lbl.backgroundSecondaryColor.b, opacity: lbl.backgroundSecondaryColor.a)
        self.labelGradientAngle = lbl.gradientAngleDegrees
        self.labelTopArcRadiusMM = lbl.topArcRadiusMM
        self.labelBottomArcRadiusMM = lbl.bottomArcRadiusMM
        self.labelArcLetterSpacing = lbl.arcLetterSpacing
        self.labelVectorShapes = lbl.vectorShapeLayers
        self.labelTextElements = lbl.textElements
        self.labelGradientMidpoint = lbl.gradientMidpointRatio
        self.labelBgAdjustments = lbl.bgAdjustments
        self.labelGPUSeedPattern = lbl.gpuSeedPattern
        self.labelKaleidoscopeFacets = lbl.kaleidoscopeFacetCount
        self.labelKaleidoscopeRig = lbl.kaleidoscopeMirrorRig
        self.labelChamberTumble = lbl.kaleidoscopeChamberTumble
        self.labelPlanet = lbl.planet ?? KroutonPlanetSettings()
        self.labelPrint = lbl.printSettings ?? KroutonLabelPrintSettings()
        if let path = lbl.planetPhotoPath { loadPlanetPhoto(URL(fileURLWithPath: path)) }
        self.labelUseVisionForeground = lbl.useVisionForegroundCutout
        if let breakLBA = manifest.coreSpec.dualLayerBreakSectorLBA {
            dualLayerBreakSectorLBA = breakLBA
        }

        var restoredDomainMap: [String: [KroutonBakeBatchItem]] = [:]
        for (k, records) in manifest.savedQueuesByDomain {
            restoredDomainMap[k] = records.compactMap { $0.toBatchItem() }
        }
        savedQueuesByDomain = restoredDomainMap

        let restoredQueue = manifest.activeQueue.compactMap { $0.toBatchItem() }
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

    func presentSaveKrutProjectSheet() {
        guard let data = try? buildProjectManifest().encodePrettyJSON() else { return }
        let cleanTitle = discVolumeTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? "Krouton_Master"
            : discVolumeTitle.replacingOccurrences(of: " ", with: "_")
        KroutonProjectDialogBridge.shared.exportDocument = KroutonProjectFileDocument(jsonData: data)
        KroutonProjectDialogBridge.shared.defaultFilename = "\(cleanTitle).krut"
        KroutonProjectDialogBridge.shared.isShowingExporter = true
    }

    func presentOpenKrutProjectSheet() {
        KroutonProjectDialogBridge.shared.isShowingImporter = true
    }
}
