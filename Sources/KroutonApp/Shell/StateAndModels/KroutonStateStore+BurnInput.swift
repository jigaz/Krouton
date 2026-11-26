import DriveKit
import Foundation
import ImageKit
import OpticalCore
import VideoKit

// MARK: - KroutonStateStore — What Actually Goes on the Disc

@MainActor
extension KroutonStateStore {
    /// The files a data burn or disc image should carry. Usually the deck as staged; for an MP3
    /// CD, the folder `KroutonCarAudioDiscPreparer` builds from it with the workspace's options
    /// (converted, renamed, with a playlist); for M-DISC with PAR2 on, a copy of the deck with
    /// par2 recovery files beside it. Then, on data discs, the Finder layout's `.DS_Store` when
    /// that switch is on, and for the large-file UDF format the whole set as one UDF 2.50 image
    /// (`KroutonUDFImageWriter`), which the drive bank burns as an image. `folder` is temporary
    /// and the caller removes it.
    func burnInputFiles() async throws -> (files: [KroutonStagedFileEntry], folder: URL?) {
        guard activeBurnSupport != nil else { return (stagedFiles, nil) }
        let format = activeFormatSpec().formatID
        var input: (files: [KroutonStagedFileEntry], folder: URL?)
        switch format {
        case .mp3CD: input = try await carMP3Files()
        case .mdiscVault where mdiscParityPercent > 0: input = try await filesWithParity()
        default: input = try asISONamedImage((stagedFiles, nil))
        }
        if activeBurnSupport == .dataDisc, format != .mp3CD, enableCustomFinderLayoutTab {
            input = try withFinderLayout(input)
        }
        if format == .dataUDFModern { input = try await asUDFImage(input, profile: .bluRay) }
        if format == .dvdVideo {
            guard let items = dvdVideoItems(input.files) else {
                throw KroutonBurnInputError(message: "Add the folder that holds VIDEO_TS (or VIDEO_TS and AUDIO_TS themselves). Nothing was written.")
            }
            input = try await asUDFImage((items, input.folder), profile: .dvdVideo)
        }
        return input
    }

    // MARK: - Finder Layout, UDF 2.50 and Renamed Images

    /// A GameCube `.gcm` is a plain ISO image under another name; DiscRecording and Krouton
    /// Server go by the name, so a clone named `.iso` is burned instead (instant on APFS).
    private func asISONamedImage(
        _ input: (files: [KroutonStagedFileEntry], folder: URL?)
    ) throws -> (files: [KroutonStagedFileEntry], folder: URL?) {
        guard input.files.count == 1, let only = input.files.first, only.url.pathExtension.lowercased() == "gcm" else { return input }
        let folder = FileManager.default.temporaryDirectory
            .appendingPathComponent("KroutonGCM_\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let iso = folder.appendingPathComponent(only.url.deletingPathExtension().lastPathComponent).appendingPathExtension("iso")
        try FileManager.default.copyItem(at: only.url, to: iso)
        return ([KroutonOpticalDriveBank.inspectFileOrFolder(url: iso)], folder)
    }

    /// Adds the `.DS_Store` that gives the disc's root window the Finder View tab's layout.
    private func withFinderLayout(
        _ input: (files: [KroutonStagedFileEntry], folder: URL?)
    ) throws -> (files: [KroutonStagedFileEntry], folder: URL?) {
        let folder = input.folder ?? FileManager.default.temporaryDirectory
            .appendingPathComponent("KroutonLayout_\(UUID().uuidString)", isDirectory: true)
        let layout = folder.appendingPathComponent("Layout", isDirectory: true)
        try FileManager.default.createDirectory(at: layout, withIntermediateDirectories: true)
        let names = input.files.map(\.name).filter { !$0.hasPrefix(".") }.sorted()
        let store = layout.appendingPathComponent(".DS_Store")
        try finderLayoutBlueprint.serializeDSStore(itemNames: names).write(to: store, options: .atomic)
        return (input.files.filter { $0.name != ".DS_Store" } + [KroutonOpticalDriveBank.inspectFileOrFolder(url: store)], folder)
    }

    /// The deck's items with VIDEO_TS at the top: a lone folder holding VIDEO_TS stands for its
    /// contents. Nil when there is no VIDEO_TS to put at the top.
    func dvdVideoItems(_ files: [KroutonStagedFileEntry]) -> [KroutonStagedFileEntry]? {
        func hasVideoTS(_ entries: [KroutonStagedFileEntry]) -> Bool {
            entries.contains { $0.isDirectory && $0.name.uppercased() == "VIDEO_TS" }
        }
        if hasVideoTS(files) { return files }
        guard files.count == 1, let only = files.first, only.isDirectory else { return nil }
        let children = ((try? FileManager.default.contentsOfDirectory(at: only.url, includingPropertiesForKeys: nil)) ?? [])
            .filter { !$0.lastPathComponent.hasPrefix(".") }
            .map { KroutonOpticalDriveBank.inspectFileOrFolder(url: $0) }
        return hasVideoTS(children) ? children : nil
    }

    /// Stages the files and writes them as one image with Krouton's own writer: UDF 2.50 for
    /// large-file data (any file size; macOS, Windows 10 and later, Linux), or ISO 9660 + UDF
    /// 1.02 with VIDEO_TS in player order for DVD-Video.
    private func asUDFImage(
        _ input: (files: [KroutonStagedFileEntry], folder: URL?),
        profile: KroutonUDFImageWriter.Profile
    ) async throws -> (files: [KroutonStagedFileEntry], folder: URL?) {
        let folder = FileManager.default.temporaryDirectory
            .appendingPathComponent("KroutonUDF_\(UUID().uuidString)", isDirectory: true)
        defer { if let old = input.folder { try? FileManager.default.removeItem(at: old) } }
        let tree = folder.appendingPathComponent("Tree", isDirectory: true)
        let items = input.files.map { KroutonBurnStageItem(source: $0.url, name: $0.name) }
        if let stagingError = await KroutonBurnStager.stage(items, into: tree) {
            try? FileManager.default.removeItem(at: folder)
            throw KroutonBurnInputError(message: stagingError)
        }
        let image = folder.appendingPathComponent("disc.iso")
        do {
            try Self.ensureScratchSpace(for: input.files.reduce(Int64(0)) { $0 + $1.byteSize })
        } catch {
            try? FileManager.default.removeItem(at: folder)
            throw error
        }
        let label = discVolumeTitle
        do {
            _ = try await Task.detached(priority: .userInitiated) {
                try KroutonUDFImageWriter.build(folder: tree, output: image, label: label, profile: profile)
            }.value
        } catch {
            try? FileManager.default.removeItem(at: folder)
            throw error
        }
        try? FileManager.default.removeItem(at: tree)
        return ([KroutonOpticalDriveBank.inspectFileOrFolder(url: image)], folder)
    }

    private func filesWithParity() async throws -> (files: [KroutonStagedFileEntry], folder: URL?) {
        let folder = FileManager.default.temporaryDirectory
            .appendingPathComponent("KroutonParity_\(UUID().uuidString)", isDirectory: true)
        let tree = folder.appendingPathComponent("Disc", isDirectory: true)
        let items = stagedFiles.map { KroutonBurnStageItem(source: $0.url, name: $0.name) }
        if let stagingError = await KroutonBurnStager.stage(items, into: tree) {
            try? FileManager.default.removeItem(at: folder)
            throw KroutonBurnInputError(message: stagingError)
        }
        let percent = Int(mdiscParityPercent)
        do {
            try await Task.detached(priority: .userInitiated) {
                try KroutonParityWriter.addRecovery(to: tree, percent: percent, par2: KroutonParityWriter.locatePar2())
            }.value
        } catch {
            try? FileManager.default.removeItem(at: folder)
            throw error
        }
        return (Self.entries(in: tree), folder)
    }

    private static func entries(in tree: URL) -> [KroutonStagedFileEntry] {
        let names = ((try? FileManager.default.contentsOfDirectory(atPath: tree.path)) ?? []).sorted()
        return names.map { KroutonOpticalDriveBank.inspectFileOrFolder(url: tree.appendingPathComponent($0)) }
    }

    private func carMP3Files() async throws -> (files: [KroutonStagedFileEntry], folder: URL?) {
        let sources = stagedFiles.map(\.url)
        let options = carAudioOptions
        let folder = FileManager.default.temporaryDirectory
            .appendingPathComponent("KroutonCarMP3_\(UUID().uuidString)", isDirectory: true)
        do {
            let tree = try await Task.detached(priority: .userInitiated) {
                try KroutonCarAudioDiscPreparer.prepare(
                    sources: sources, options: options, into: folder.appendingPathComponent("Disc", isDirectory: true),
                    ffmpeg: OpticalDiscVolumeScanner.locateFFmpeg())
            }.value
            return (Self.entries(in: tree), folder)
        } catch {
            try? FileManager.default.removeItem(at: folder)
            throw error
        }
    }
}

extension KroutonStateStore {
    /// Stops before building an image the temporary folder's disk can't hold: a 100 GB UHD
    /// Blu-ray needs 100 GB free while it is written, and running out halfway fails late.
    nonisolated static func ensureScratchSpace(for bytes: Int64) throws {
        let tmp = FileManager.default.temporaryDirectory
        guard let free = try? tmp.resourceValues(forKeys: [.volumeAvailableCapacityForImportantUsageKey])
            .volumeAvailableCapacityForImportantUsage else { return }
        let needed = bytes + bytes / 50 + 268_435_456
        guard needed > free else { return }
        let format = { (n: Int64) in ByteCountFormatter.string(fromByteCount: n, countStyle: .file) }
        throw KroutonBurnInputError(message: "Building this disc image needs about \(format(needed)) free on the startup disk, and \(format(free)) is free. Free some space and try again. Nothing was written.")
    }
}

/// A problem preparing the files, with the words the report shows.
struct KroutonBurnInputError: LocalizedError, Equatable {
    let message: String
    var errorDescription: String? { message }
}
