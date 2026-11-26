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
    /// par2 recovery files beside it. `folder` is temporary and the caller removes it.
    func burnInputFiles() async throws -> (files: [KroutonStagedFileEntry], folder: URL?) {
        guard activeBurnSupport != nil else { return (stagedFiles, nil) }
        switch activeFormatSpec().formatID {
        case .mp3CD: return try await carMP3Files()
        case .mdiscVault where mdiscParityPercent > 0: return try await filesWithParity()
        default: return (stagedFiles, nil)
        }
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

/// A problem preparing the files, with the words the report shows.
struct KroutonBurnInputError: LocalizedError, Equatable {
    let message: String
    var errorDescription: String? { message }
}
