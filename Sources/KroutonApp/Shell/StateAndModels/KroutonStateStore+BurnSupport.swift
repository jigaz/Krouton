import AudioKit
import DriveKit
import Foundation
import ImageKit
import OpticalCore

// MARK: - KroutonStateStore — What a Burn Will Really Produce

/// Programmer's notes: every burn, local or on a Krouton Server, and every disc-image card asks
/// `burnRefusal(for:)` first. Formats whose disc Krouton can't make yet (see
/// `KroutonFormatID.burnSupport`) stop here with a report, before anything is staged, so a
/// blank is never spent on the wrong kind of disc. Blu-ray video goes through the UDF 2.50
/// writer, which DiscRecording (UDF 1.02) can't replace: BD players need 2.50.
@MainActor
extension KroutonStateStore {
    /// The selected format's burn support, or nil outside the Burn workspace (the Depot and the
    /// Copy tasks stage their own disc images).
    var activeBurnSupport: KroutonBurnSupport? {
        selectedCategory == .burn ? activeFormatSpec().formatID?.burnSupport : nil
    }

    /// Why a destination of this kind can't run on the current deck, or nil if it can.
    func burnRefusal(for kind: KroutonBurnDestinationKind) -> String? {
        guard [.physicalBurner, .networkBurner, .discImage].contains(kind), let support = activeBurnSupport else { return nil }
        switch support {
        case .notYet(let reason):
            return reason
        case .dataDisc:
            if activeFormatSpec().formatID == .dataRetroISO, kind != .physicalBurner {
                return "DOS 8.3 discs are written by a burner on this Mac, which can limit the names to ISO 9660 Level 1. Nothing was written."
            }
            return nil
        case .discImage:
            if kind == .discImage {
                return "The deck already holds a disc image; burn it, or copy the file itself."
            }
            guard stagedFiles.count == 1, let only = stagedFiles.first, !only.isDirectory else {
                return "Add one disc image: .iso, .cue (with its .bin), .dmg, .cdr or .toc. Nothing was written."
            }
            let ext = only.url.pathExtension.lowercased()
            if kind == .networkBurner, !["iso", "cdr", "gcm"].contains(ext) {
                return "Krouton Server burns .iso images. Burn this .\(ext) image on a drive connected to this Mac."
            }
            // Recognised-but-unburnable images (.cdi, .wbfs…) are refused by the drive bank with their own advice.
            let known = ext == "gcm" || KroutonOpticalDriveBank.burnableImageExtensions.contains(ext)
                || KroutonOpticalDriveBank.unburnableImageExtensions[ext] != nil
            return known ? nil : "Krouton can't burn a .\(ext) file as a disc image. Add an .iso, .cue/.bin, .dmg, .cdr or .toc."
        case .bluRayVideo:
            if case .failure(let error) = bluRayVideoRoot() { return error.message }
            return nil
        case .audioCD:
            if kind == .networkBurner {
                return "Krouton Server burns data discs and disc images. Burn audio CDs on a drive connected to this Mac, or save a disc image (.cue/.bin) and send that. Nothing was written."
            }
            let project = audioController.project
            if project.tracks.isEmpty {
                return "Add tracks in the Audio CD editor first. The CD is burned from the editor's track list. Nothing was written."
            }
            if activeFormatSpec().formatID == .cdExtra {
                if kind == .discImage {
                    return "A .cue/.bin image holds one session, so it can't carry CD-Extra's data. Burn the CD-Extra on a drive connected to this Mac. Nothing was written."
                }
                if cdExtraDataFiles.isEmpty {
                    return "Add the files for the data session under Data Session, or choose Audio CD for the music alone. Nothing was written."
                }
            }
            if activeFormatSpec().formatID == .dtsCD {
                if let track = project.tracks.first(where: { !KroutonAudioDiscRenderer.isRedBookWAV($0.source) }) {
                    return "\(track.source.lastPathComponent) isn't a 44.1 kHz 16-bit stereo WAV. A DTS CD needs the DTS-encoded WAV files exactly as they are; converting them would destroy the DTS stream. Nothing was written."
                }
                if project.tracks.dropLast().contains(where: { $0.transitionToNext.isCrossfading }) {
                    return "A crossfade would mix two DTS streams into noise. Use pauses or gapless joins on a DTS CD. Nothing was written."
                }
            }
            return nil
        }
    }

    // MARK: - Audio CD

    /// Renders the Audio CD editor's project off the main actor, into a new temporary folder
    /// the caller removes. Throws the renderer's own explanation when the project can't be a
    /// single CD (tracks unanalysed, too long, too short, more than 99).
    func renderAudioTracks() async throws -> (tracks: [KroutonRenderedAudioTrack], folder: URL) {
        let project = audioController.project
        let folder = FileManager.default.temporaryDirectory
            .appendingPathComponent("KroutonAudioCD_\(UUID().uuidString)", isDirectory: true)
        do {
            let tracks = try await Task.detached(priority: .userInitiated) {
                try KroutonAudioDiscRenderer.render(project: project, into: folder)
            }.value
            return (tracks, folder)
        } catch {
            try? FileManager.default.removeItem(at: folder)
            throw error
        }
    }

    /// CD-Extra: adds files and folders to the data session, once each.
    func addCDExtraDataFiles(_ urls: [URL]) {
        for url in urls where !cdExtraDataFiles.contains(where: { $0.url == url }) {
            cdExtraDataFiles.append(KroutonOpticalDriveBank.inspectFileOrFolder(url: url))
        }
    }

    /// What the drive bank burns for the rendered tracks.
    func audioBurnDisc(_ rendered: [KroutonRenderedAudioTrack]) -> KroutonAudioBurnDisc {
        let project = audioController.project
        return KroutonAudioBurnDisc(
            tracks: rendered.map {
                KroutonAudioBurnTrack(pcm: $0.pcm, frames: $0.frames, pregapFrames: $0.pregapFrames,
                                      title: $0.title, performer: $0.performer, isrc: $0.isrc)
            },
            albumTitle: project.albumTitle,
            albumPerformer: project.albumPerformer,
            mediaCatalogNumber: KroutonAudioDiscRenderer.mediaCatalogNumber(project.upc),
            writeCDText: project.writeCDText,
            dataSessionFiles: activeFormatSpec().formatID == .cdExtra ? cdExtraDataFiles.map(\.url) : [],
            dataVolumeName: discVolumeTitle)
    }

    /// Renders the project and saves it as a `.cue` + `.bin` pair at `path`.
    func saveAudioDiscImage(path: String) async throws -> URL {
        let project = audioController.project
        var cue = URL(fileURLWithPath: NSString(string: path).expandingTildeInPath)
        if cue.pathExtension.lowercased() != "cue" { cue = cue.deletingPathExtension().appendingPathExtension("cue") }
        let (tracks, folder) = try await renderAudioTracks()
        defer { try? FileManager.default.removeItem(at: folder) }
        let target = cue
        try await Task.detached(priority: .userInitiated) {
            try KroutonAudioDiscRenderer.writeBinCue(tracks, project: project, cueURL: target)
        }.value
        return target
    }

    // MARK: - Blu-ray Video

    /// The folder to put at the root of a Blu-ray disc: the staged folder that holds `BDMV`, or
    /// the folder holding staged `BDMV` (and `CERTIFICATE`) when nothing else is beside them.
    func bluRayVideoRoot() -> Result<URL, KroutonBluRayRootError> {
        let fm = FileManager.default
        func hasBDMV(_ url: URL) -> Bool {
            var isDir: ObjCBool = false
            return fm.fileExists(atPath: url.appendingPathComponent("BDMV").path, isDirectory: &isDir) && isDir.boolValue
        }
        func checked(_ root: URL) -> Result<URL, KroutonBluRayRootError> {
            KroutonBDMVFolder.problem(root: root).map { .failure(KroutonBluRayRootError(message: $0)) } ?? .success(root)
        }
        if stagedFiles.count == 1, let only = stagedFiles.first, only.isDirectory, hasBDMV(only.url) {
            return checked(only.url)
        }
        let names = Set(stagedFiles.map { $0.name.uppercased() })
        if names.contains("BDMV"), names.isSubset(of: ["BDMV", "CERTIFICATE"]),
           let parent = stagedFiles.first?.url.deletingLastPathComponent(),
           stagedFiles.allSatisfy({ $0.url.deletingLastPathComponent() == parent }) {
            let beside = (try? fm.contentsOfDirectory(atPath: parent.path)) ?? []
            if beside.filter({ !$0.hasPrefix(".") }).allSatisfy({ ["BDMV", "CERTIFICATE"].contains($0.uppercased()) }) {
                return checked(parent)
            }
        }
        return .failure(KroutonBluRayRootError(message:
            "Add one folder that holds an authored BDMV folder (or BDMV itself, on its own). Nothing was written."))
    }

    /// Writes the Blu-ray folder as a UDF 2.50 image, off the main actor. With no `output`, the
    /// image goes in a new temporary folder the caller removes.
    func buildBluRayImage(root: URL, output: URL? = nil) async throws -> URL {
        let target = output ?? FileManager.default.temporaryDirectory
            .appendingPathComponent("KroutonBluRay_\(UUID().uuidString)", isDirectory: true)
            .appendingPathComponent("disc.iso")
        try FileManager.default.createDirectory(at: target.deletingLastPathComponent(), withIntermediateDirectories: true)
        if output == nil { try Self.ensureScratchSpace(for: Self.folderBytes(root)) }
        let label = discVolumeTitle
        _ = try await Task.detached(priority: .userInitiated) {
            try KroutonUDFImageWriter.build(folder: root, output: target, label: label, leaveOut: KroutonBDMVFolder.leftOut)
        }.value
        return target
    }

    /// Total size of the files under `root`.
    nonisolated static func folderBytes(_ root: URL) -> Int64 {
        let walker = FileManager.default.enumerator(at: root, includingPropertiesForKeys: [.fileSizeKey])
        var total: Int64 = 0
        while let url = walker?.nextObject() as? URL {
            total += Int64((try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0)
        }
        return total
    }

    /// A short report for a destination that didn't burn (or, with `ok`, that only wrote a file).
    func refusalReport(_ summary: String, title: String = "Nothing Was Written", ok: Bool = false) -> KroutonBurnSessionReport {
        KroutonBurnSessionReport(
            isSuccess: ok, title: title, summary: summary, driveModel: "—", firmwareRevision: "—",
            mediaFormattedName: "—", volumeName: discVolumeTitle, sectorsWrittenLBA: 0, bytesWritten: 0,
            averageSpeedText: "—", peakSpeedText: "—", elapsedDurationText: "00:00",
            diagnosticAdvice: "See Help › Krouton User Manual for what each format can do today."
        )
    }
}

struct KroutonBluRayRootError: Error, Equatable {
    let message: String
}
