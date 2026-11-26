import DriveKit
import Foundation
import ImageKit
import NetworkSpool
import OpticalCore

// MARK: - Burning on a Krouton Server

@MainActor
extension KroutonStateStore {
    /// Sends the deck to the Krouton Server and drive chosen on the destination card. Telemetry
    /// streams into the card's Phase Scope. What is sent:
    /// - one staged .iso/.cdr: that image, as it is (wrapping it in a new data disc, as this used
    ///   to, burned the image as a file);
    /// - Blu-ray video and large-file UDF data: a UDF 2.50 image from `KroutonUDFImageWriter`;
    /// - DVD-Video: the files themselves (`burnFolder`), so the server's own writer builds the
    ///   disc with VIDEO_TS first and in player order, as hdiutil can't promise;
    /// - anything else: an ISO 9660 + Joliet + UDF image of the staged files (`hdiutil makehybrid`).
    /// `burnRefusal(for:)` has already stopped formats the server can't burn, audio CDs included.
    func runNetworkBurn(_ target: KroutonBakeBatchItem, driveManager: KroutonOpticalDriveBank) async {
        let telemetryKey = "network-spool-drive"
        driveManager.setManualInlinePin(for: telemetryKey, isPinned: true)
        let started = Date()
        if activeFormatSpec().formatID == .dvdVideo, SpoolRemoteNodeClient.shared.serverWelcome?.buildsDiscsFromFolders != false {
            await runNetworkFolderBurn(target, driveManager: driveManager, started: started)
            return
        }
        // MP3 conversion, PAR2, the Finder layout, large-file UDF and .gcm renaming happen here.
        let input: (files: [KroutonStagedFileEntry], folder: URL?)
        do {
            input = try await burnInputFiles()
        } catch {
            driveManager.completionReport = networkReport(ok: false, title: "Could Not Prepare the Disc", summary: error.localizedDescription,
                                                          server: "", drive: "", bytes: 0, started: started)
            return
        }
        defer { if let folder = input.folder { try? FileManager.default.removeItem(at: folder) } }
        let sole = KroutonOpticalDriveBank.soleDiscImage(in: input.files)
        if let sole, !["iso", "cdr"].contains(sole.pathExtension.lowercased()) {
            driveManager.completionReport = networkReport(ok: false, title: "Burn This Image on This Mac",
                                                          summary: "Krouton Server burns .iso images; .\(sole.pathExtension) images burn on a drive connected to this Mac.",
                                                          server: "", drive: "", bytes: 0, started: started)
            return
        }
        let built: URL?
        if let sole {
            built = sole
        } else if activeBurnSupport == .bluRayVideo, case .success(let root) = bluRayVideoRoot() {
            built = try? await buildBluRayImage(root: root)
        } else {
            built = await masterImageForNetworkBurn(input.files)
        }
        guard let image = built else {
            driveManager.completionReport = networkReport(ok: false, title: "Could Not Build the Disc Image",
                                                          summary: "Add files to the disc, then try again.",
                                                          server: "", drive: "", bytes: 0, started: started)
            return
        }
        defer { if sole == nil { try? FileManager.default.removeItem(at: image.deletingLastPathComponent()) } }
        let bytes = (try? FileManager.default.attributesOfItem(atPath: image.path)[.size] as? Int64) ?? 0
        let options = SpoolBurnOptions(speed: Int(target.speedOrCodec.prefix { $0.isNumber }) ?? 0,
                                       verify: target.verifyAfterBurn, simulate: target.simulationMode, eject: true)
        let outcome: SpoolRemoteBurnOutcome = await SpoolRemoteNodeClient.shared.burnImage(
            at: image, label: discVolumeTitle, serverID: target.hardwareOrPath, driveID: target.targetDriveID,
            options: options, telemetry: driveManager, telemetryKey: telemetryKey
        )
        driveManager.completionReport = networkReport(
            ok: outcome.succeeded,
            title: outcome.succeeded ? "Burned on \(outcome.serverName)" : "Remote Burn Did Not Finish",
            summary: outcome.message, server: outcome.serverName, drive: outcome.driveName, bytes: bytes, started: started,
            verified: target.verifyAfterBurn
        )
    }

    /// Copies the deck into a temporary folder and sends that folder for the server to master.
    private func runNetworkFolderBurn(_ target: KroutonBakeBatchItem, driveManager: KroutonOpticalDriveBank, started: Date) async {
        let tree = FileManager.default.temporaryDirectory.appendingPathComponent("KroutonNetworkFolder_\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: tree) }
        guard let entries = dvdVideoItems(stagedFiles) else {
            driveManager.completionReport = networkReport(ok: false, title: "Could Not Prepare the Disc",
                                                          summary: "Add the folder that holds VIDEO_TS (or VIDEO_TS and AUDIO_TS themselves).",
                                                          server: "", drive: "", bytes: 0, started: started)
            return
        }
        let items = entries.map { KroutonBurnStageItem(source: $0.url, name: $0.name) }
        if let stagingError = await KroutonBurnStager.stage(items, into: tree) {
            driveManager.completionReport = networkReport(ok: false, title: "Could Not Prepare the Disc", summary: stagingError,
                                                          server: "", drive: "", bytes: 0, started: started)
            return
        }
        let bytes = stagedFiles.reduce(0) { $0 + $1.byteSize }
        let options = SpoolBurnOptions(speed: Int(target.speedOrCodec.prefix { $0.isNumber }) ?? 0,
                                       verify: target.verifyAfterBurn, simulate: target.simulationMode, eject: true)
        let outcome = await SpoolRemoteNodeClient.shared.burnFolder(
            at: tree, label: discVolumeTitle, serverID: target.hardwareOrPath, driveID: target.targetDriveID,
            options: options, telemetry: driveManager, telemetryKey: "network-spool-drive"
        )
        driveManager.completionReport = networkReport(
            ok: outcome.succeeded,
            title: outcome.succeeded ? "Burned on \(outcome.serverName)" : "Remote Burn Did Not Finish",
            summary: outcome.message, server: outcome.serverName, drive: outcome.driveName, bytes: bytes, started: started,
            verified: target.verifyAfterBurn
        )
    }

    /// Stages the files and builds the image in a fresh temporary folder. The HFS+ tree is left out:
    /// a server burns 2048-byte-sector data images (ISO/UDF), which every OS can read.
    func masterImageForNetworkBurn(_ files: [KroutonStagedFileEntry]) async -> URL? {
        guard !files.isEmpty else { return nil }
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("KroutonNetworkBurn_\(UUID().uuidString)", isDirectory: true)
        let tree = root.appendingPathComponent("Tree", isDirectory: true)
        let output = root.appendingPathComponent("disc.iso")
        let items = files.map { KroutonBurnStageItem(source: $0.url, name: $0.name) }
        if let stagingError = await KroutonBurnStager.stage(items, into: tree) {
            KroutonDiagnostics.masteringLogger.error("Network burn staging failed: \(stagingError, privacy: .public)")
            try? FileManager.default.removeItem(at: root)
            return nil
        }
        do {
            let built = try await KroutonHybridImageBuilder.build(
                sourceDirectory: tree,
                outputURL: output,
                options: KroutonHybridImageOptions(volumeName: discVolumeTitle, finderLayout: enableCustomFinderLayoutTab ? finderLayoutBlueprint : nil)
            )
            try? FileManager.default.removeItem(at: tree)
            return built.url
        } catch {
            KroutonDiagnostics.masteringLogger.error("Network burn mastering failed: \(error.localizedDescription, privacy: .public)")
            try? FileManager.default.removeItem(at: root)
            return nil
        }
    }

    private func networkReport(ok: Bool, title: String, summary: String, server: String, drive: String,
                               bytes: Int64, started: Date, verified: Bool = false) -> KroutonBurnSessionReport {
        let elapsed = max(1, Int(Date().timeIntervalSince(started)))
        return KroutonBurnSessionReport(
            isSuccess: ok,
            title: title,
            summary: summary,
            driveModel: drive.isEmpty ? "Krouton Server" : drive,
            firmwareRevision: server.isEmpty ? "-" : server,
            mediaFormattedName: networkDiscDescription,
            volumeName: discVolumeTitle,
            sectorsWrittenLBA: ok ? bytes / 2048 : 0,
            bytesWritten: ok ? bytes : 0,
            averageSpeedText: "-",
            peakSpeedText: "-",
            elapsedDurationText: String(format: "%02d:%02d", elapsed / 60, elapsed % 60),
            diagnosticAdvice: ok ? (verified ? "The server read the disc back and it matched." : "Verify was off, so the disc wasn't read back.")
                : "See Settings › Burners & Network › Save Log, and the server's log (`krouton-server check`)."
        )
    }

    /// What a network burn put on the disc, for its report.
    private var networkDiscDescription: String {
        switch activeFormatSpec().formatID {
        case .dvdVideo: return "DVD-Video (ISO 9660 + UDF 1.02, mastered by the server)"
        case .dataUDFModern: return "UDF 2.50 data disc"
        case .bd25, .bd50, .bdUHD: return "Blu-ray video (UDF 2.50)"
        default: return activeBurnSupport == .discImage || stagedFiles.count == 1 && KroutonOpticalDriveBank.soleDiscImage(in: stagedFiles) != nil
            ? "Disc image, as it is" : "Data disc (ISO 9660 + Joliet + UDF)"
        }
    }
}
