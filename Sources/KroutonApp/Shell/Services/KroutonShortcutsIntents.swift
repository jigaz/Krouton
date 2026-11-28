import AppIntents
import DriveKit
import Foundation
import ImageKit
import OpticalCore
import VideoKit

// MARK: - Disc Sizes for Shortcuts

enum KroutonShortcutDiscMedium: String, AppEnum, CaseIterable, Sendable {
    case cd650MB   = "CD-R 74 min / 650 MB"
    case cd700MB   = "CD-R 80 min / 700 MB"
    case cd800MB   = "CD-R 90 min / 800 MB (Overburn)"
    case miniDVD   = "Mini-DVD 80mm (1.46 GB)"
    case dvd5      = "DVD-5 Single-Layer (4.7 GB)"
    case dvd9      = "DVD-9 Dual-Layer (8.54 GB)"
    case bd25      = "BD-R 25 GB Single-Layer"
    case bd50      = "BD-R 50 GB Dual-Layer"
    case bdxl100   = "BDXL 100 GB Triple-Layer"
    case bdxl128   = "BDXL 128 GB Quad-Layer"

    static let typeDisplayRepresentation = TypeDisplayRepresentation(name: "Optical Disc Size")

    static let caseDisplayRepresentations: [KroutonShortcutDiscMedium: DisplayRepresentation] = [
        .cd650MB: "CD-R 650 MB (74 min)",
        .cd700MB: "CD-R 700 MB (80 min)",
        .cd800MB: "CD-R 800 MB (90 min Overburn)",
        .miniDVD: "Mini-DVD 1.46 GB (80mm)",
        .dvd5:    "DVD-5 Single-Layer (4.7 GB)",
        .dvd9:    "DVD-9 Dual-Layer (8.54 GB)",
        .bd25:    "BD-R Single-Layer (25 GB)",
        .bd50:    "BD-R Dual-Layer (50 GB)",
        .bdxl100: "BDXL Triple-Layer (100 GB)",
        .bdxl128: "BDXL Quad-Layer (128 GB)"
    ]

    var spanningMedium: KroutonSpanningDiscMedium {
        KroutonSpanningDiscMedium(rawValue: rawValue) ?? .dvd5Single
    }
}

// MARK: - List Drives

struct KroutonListOpticalDrivesIntent: AppIntent {
    static let title: LocalizedStringResource = "List Optical Drives & Media Status"
    static let description = IntentDescription("Scans connected USB, SATA, FireWire, and Thunderbolt optical drives and reports loaded disc capacity and ATIP/MID manufacturer.")
    static let openAppWhenRun: Bool = false

    init() {}

    @MainActor
    func perform() async throws -> some IntentResult & ReturnsValue<String> & ProvidesDialog {
        let bank = KroutonOpticalDriveBank()
        bank.refreshDrives()
        let drives = bank.availableDrives
        if drives.isEmpty {
            let msg = "No optical drives detected. Connect a USB/Thunderbolt optical burner or check cable power."
            return .result(value: msg, dialog: IntentDialog(stringLiteral: msg))
        }
        let lines = drives.map { d -> String in
            let freeStr = ByteCountFormatter.string(fromByteCount: d.freeBytes, countStyle: .file)
            return "• \(d.displayName) [FW \(d.firmware)] (\(d.bsdDeviceNode)): \(d.statusBadgeText) — Free: \(freeStr) (\(d.freeSectorsLBA) LBA) • MID: \(d.mediaManufacturer)"
        }
        let summary = lines.joined(separator: "\n")
        return .result(value: summary, dialog: IntentDialog(stringLiteral: summary))
    }
}

// MARK: - Inspect a Disc Image

struct KroutonInspectDiscImageIntent: AppIntent {
    static let title: LocalizedStringResource = "Inspect Optical Disc Image"
    static let description = IntentDescription("Inspects an .ISO, .DMG, .BIN, or .CUE disc image for El Torito / APM bootability, filesystems, 2048-byte LBA sector count, and optional SHA-256 digest.")
    static let openAppWhenRun: Bool = false

    @Parameter(title: "Disc Image Path", description: "POSIX path to an .iso, .dmg, .bin, or .cue file")
    var imagePath: String

    @Parameter(title: "Compute SHA-256 Checksum", default: false)
    var computeSHA256: Bool

    init() {}

    func perform() async throws -> some IntentResult & ReturnsValue<String> & ProvidesDialog {
        let expanded = (imagePath as NSString).expandingTildeInPath
        let url = URL(fileURLWithPath: expanded)
        guard FileManager.default.fileExists(atPath: url.path) else {
            throw NSError(domain: "KroutonShortcuts", code: 404, userInfo: [NSLocalizedDescriptionKey: "Disc image not found at \(expanded)"])
        }
        let report = DiscImageDepotOperations.inspectImageFile(at: url)
        let c = report.classification
        var parts: [String] = [
            "Image: \(url.lastPathComponent)",
            "Filesystems: \(c.detectedFilesystems.joined(separator: ", "))",
            "Bootable: \(c.isBootable ? "Yes (\(c.bootStandard))" : "No")",
            "Sectors (2048B): \(c.totalSectors2048) LBA",
            "Recommended Blank Media: \(c.recommendedMediaBadge)"
        ]
        if !report.cueTracks.isEmpty {
            parts.append("CUE Tracks: \(report.cueTracks.count)")
        }
        if computeSHA256 {
            let sha = KroutonElToritoBootInspector.computeSHA256Hex(url: url)
            parts.append("SHA-256: \(sha ?? "couldn't read the image")")
        }
        let summary = parts.joined(separator: "\n")
        return .result(value: summary, dialog: IntentDialog(stringLiteral: summary))
    }
}

// MARK: - Plan a Multi-Disc Set

struct KroutonPlanMultiDiscSpanIntent: AppIntent {
    static let title: LocalizedStringResource = "Calculate Multi-Disc Spanning Plan"
    static let description = IntentDescription("Calculates how many optical discs are required to span a list of files or folders for a selected target disc storage size (650 MB CD-R up to 128 GB BDXL).")
    static let openAppWhenRun: Bool = false

    @Parameter(title: "Target Disc Size", default: .dvd5)
    var targetDiscSize: KroutonShortcutDiscMedium

    @Parameter(title: "File or Folder Paths", description: "Paths to stage and span across discs")
    var filePaths: [String]

    init() {}

    @MainActor
    func perform() async throws -> some IntentResult & ReturnsValue<String> & ProvidesDialog {
        let entries: [KroutonStagedFileEntry] = filePaths.compactMap { raw in
            let path = (raw as NSString).expandingTildeInPath
            let url = URL(fileURLWithPath: path)
            guard FileManager.default.fileExists(atPath: url.path) else { return nil }
            return KroutonOpticalDriveBank.inspectFileOrFolder(url: url)
        }
        let medium = targetDiscSize.spanningMedium
        let plan = DiscSpanningEngine.planDataDiscs(entries, medium: medium)
        let totalBytes = entries.reduce(Int64(0)) { $0 + $1.byteSize }
        let totalStr = ByteCountFormatter.string(fromByteCount: totalBytes, countStyle: .file)
        let capStr = ByteCountFormatter.string(fromByteCount: medium.maxPayloadBytes, countStyle: .file)
        let summary = "Target: \(medium.rawValue) (\(capStr)/disc) • Items: \(entries.count) (\(totalStr)) -> \(max(1, plan.discs.count)) Disc(s) Required"
        return .result(value: summary, dialog: IntentDialog(stringLiteral: summary))
    }
}

// MARK: - Make a Hybrid Disc Image

struct KroutonBuildHybridISOIntent: AppIntent {
    static let title: LocalizedStringResource = "Master Hybrid UDF/ISO-9660 Disc Image"
    static let description = IntentDescription("Builds a mountable hybrid UDF + ISO-9660 + Joliet .iso optical disc image from a source folder.")
    static let openAppWhenRun: Bool = false

    @Parameter(title: "Source Folder Path")
    var sourceFolderPath: String

    @Parameter(title: "Output .ISO Path", default: "~/Desktop/KROUTON_MASTER.iso")
    var outputISOPath: String

    @Parameter(title: "Volume Title", default: "KROUTON_DISC")
    var volumeTitle: String

    init() {}

    func perform() async throws -> some IntentResult & ReturnsValue<String> & ProvidesDialog {
        let srcURL = URL(fileURLWithPath: (sourceFolderPath as NSString).expandingTildeInPath)
        let outURL = URL(fileURLWithPath: (outputISOPath as NSString).expandingTildeInPath)
        let writtenBytes = try OpticalDiscVolumeScanner.buildOpticalISOImage(
            sourceDirectory: srcURL,
            outputISOURL: outURL,
            volumeName: volumeTitle
        )
        let sizeStr = ByteCountFormatter.string(fromByteCount: writtenBytes, countStyle: .file)
        let msg = "Mastered \(outURL.lastPathComponent) (\(sizeStr), \(writtenBytes / 2048) LBA) at \(outURL.path)"
        return .result(value: msg, dialog: IntentDialog(stringLiteral: msg))
    }
}

// MARK: - Open a Workspace

struct KroutonOpenWorkspaceIntent: AppIntent {
    static let title: LocalizedStringResource = "Open Krouton Mastering Format"
    static let description = IntentDescription("Opens the Krouton macOS app directly into the specified optical format workspace (e.g., cd-da, dvd-video, bd-on-dvd, data-hybrid).")
    static let openAppWhenRun: Bool = true

    @Parameter(title: "Format ID", default: "data-hybrid")
    var formatID: String

    init() {}

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let store = KroutonWindowManager.shared.store
        if store.discFormats.contains(where: { $0.id == formatID }) {
            store.selectedCategory = .burn
            store.selectedTaskID = formatID
        }
        KroutonWindowManager.shared.openMainWindow()
        return .result(dialog: IntentDialog(stringLiteral: "Opened Krouton workspace: \(formatID)"))
    }
}

// MARK: - App Shortcuts

struct KroutonShortcutsProvider: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: KroutonListOpticalDrivesIntent(),
            phrases: [
                "List optical drives in \(.applicationName)",
                "Check optical burner status in \(.applicationName)"
            ],
            shortTitle: "Optical Drives",
            systemImageName: "opticaldisc.fill"
        )
        AppShortcut(
            intent: KroutonInspectDiscImageIntent(),
            phrases: [
                "Inspect disc image with \(.applicationName)",
                "Verify ISO checksum in \(.applicationName)"
            ],
            shortTitle: "Inspect Disc Image",
            systemImageName: "magnifyingglass.circle.fill"
        )
        AppShortcut(
            intent: KroutonPlanMultiDiscSpanIntent(),
            phrases: [
                "Plan multi-disc span in \(.applicationName)",
                "Calculate disc spanning with \(.applicationName)"
            ],
            shortTitle: "Plan Disc Span",
            systemImageName: "square.stack.3d.up.fill"
        )
        AppShortcut(
            intent: KroutonOpenWorkspaceIntent(),
            phrases: [
                "Open \(.applicationName) mastering workspace"
            ],
            shortTitle: "Open Workspace",
            systemImageName: "laser.burst"
        )
    }
}
