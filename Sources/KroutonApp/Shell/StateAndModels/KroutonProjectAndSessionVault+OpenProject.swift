import DriveKit
import Foundation
import OpticalCore
import os

// MARK: - Opening a Project

@MainActor
extension KroutonStateStore {
    private static let projectLogger = Logger(subsystem: KroutonDomainIdentity.Module.kroutonApp.subsystem, category: "ProjectFiles")

    /// Opens a `.krut` file. A file from another version opens with what it lacks filled in, and
    /// the banner says so; a file that can't be read says why instead of doing nothing.
    func openProjectFile(at url: URL, driveManager: KroutonOpticalDriveBank?) {
        let name = url.lastPathComponent
        let accessing = url.startAccessingSecurityScopedResource()
        defer { if accessing { url.stopAccessingSecurityScopedResource() } }
        do {
            let data = try Data(contentsOf: url)
            let read = try KroutonProjectManifest.decode(from: data)
            applyProjectManifest(read.value, projectURL: url, driveManager: driveManager)
            reportPersistedRepairs(read.repairs, opening: name)
        } catch {
            Self.projectLogger.error("Couldn't open \(name, privacy: .public): \(String(describing: error), privacy: .public)")
            let reason = (error as? DecodingError) != nil
                ? KroutonL10n.tr("it isn't a Krouton project, or it's damaged.")
                : error.localizedDescription
            rejectedDropNotice = String(format: KroutonL10n.tr("Couldn't open %@: %@"), name, reason)
        }
    }

    /// Adds a line to the banner when a project or session needed repairs to open, keeping any
    /// notice already there (such as files that couldn't be found). The full list goes to the log.
    func reportPersistedRepairs(_ repairs: [String], opening name: String) {
        guard !repairs.isEmpty else { return }
        for repair in repairs {
            Self.projectLogger.notice("\(name, privacy: .public) \(repair, privacy: .public)")
        }
        let leftOut = repairs.filter { $0.hasSuffix("left out") }.count
        let filled = repairs.count - leftOut
        let line = leftOut == 0
            ? String(format: KroutonL10n.tr("%@ was saved by another version of Krouton. Settings it didn't include now use their defaults: %lld."),
                     name, filled)
            : String(format: KroutonL10n.tr("%@ was saved by another version of Krouton. Settings set to their defaults: %lld. Items it couldn't read, left out: %lld."),
                     name, filled, leftOut)
        if let existing = rejectedDropNotice, !existing.isEmpty {
            rejectedDropNotice = existing + "\n" + line
        } else {
            rejectedDropNotice = line
        }
    }
}

// MARK: - Defaults for Older and Newer Files

extension KroutonProjectManifest: KroutonPersistedDefault {
    static var persistedDefault: Self {
        Self(savedAtISO8601: "", coreSpec: KroutonKrutCoreSpec(), selectedCategoryRaw: "", selectedTaskID: "",
             discVolumeTitle: "", discPerformer: "", discMCNBarcode: "", labelDiscTitle: "", labelSubtitle: "",
             labelTemplateRaw: "", labelPresetIndex: KroutonEmbeddedLabelSpec().accentPresetIndex,
             labelShowTracklistOnDisc: true, stagedSources: [], activeQueue: [], savedQueuesByDomain: [:])
    }
}

extension KroutonPersistedSessionSnapshot: KroutonPersistedDefault {
    static var persistedDefault: Self {
        Self(selectedCategoryRaw: "", selectedTaskID: "", discVolumeTitle: "", discPerformer: "", discMCNBarcode: "",
             stagedFilePaths: [], destinationQueue: [], savedAtISO8601: "")
    }
}

extension KroutonBakeBatchItem: KroutonPersistedDefault {
    static var persistedDefault: Self {
        Self(kind: .physicalBurner, hardwareOrPath: "", speedOrCodec: "", simulationMode: false,
             verifyAfterBurn: true, compressAfterCreation: false)
    }
    /// A card whose kind can't be read is left out rather than turned into a disc burner.
    static var requiredKeys: Set<String> { ["kind"] }
}

extension KroutonSavedDestinationRecord: KroutonPersistedDefault {
    static var persistedDefault: Self { Self(from: KroutonBakeBatchItem.persistedDefault) }
    static var requiredKeys: Set<String> { ["kindRawValue"] }
}

extension KroutonProjectSourceRecord: KroutonPersistedDefault {
    static var persistedDefault: Self {
        let placeholder = KroutonStagedFileEntry(url: URL(fileURLWithPath: "/"), name: "", isDirectory: false, byteSize: 0,
                                                 itemCount: 0, posixPermissions: "", modifiedDate: Date())
        var record = Self(from: placeholder)
        record.bookmarkData = nil
        return record
    }
    /// A source without its path can't be found again, so it isn't listed.
    static var requiredKeys: Set<String> { ["absolutePath"] }
}
