import Foundation
import OpticalCore

// MARK: - Burning on a Krouton Server

/// How a remote burn ended.
public struct SpoolRemoteBurnOutcome: Sendable, Equatable {
    /// True when the disc burned (and verified, if asked).
    public let succeeded: Bool
    /// What happened, for the user.
    public let message: String
    /// The server it ran on.
    public let serverName: String
    /// The drive it ran on.
    public let driveName: String
    /// The job's ID, once the server accepted it.
    public let job: String?
}

@MainActor
extension SpoolRemoteNodeClient {
    /// Uploads `image` (an ISO/UDF data image) to a paired server and burns it on `driveID` (or the
    /// first drive that can), streaming progress into `store[telemetryKey]`. Uploads resume across
    /// dropped connections; the burn itself runs on the server and is followed until it ends.
    ///
    /// - Parameter needs: the disc families the format takes (a Blu-ray Video project needs a
    ///   Blu-ray disc whatever its size); nil for any. A drive that can't write the job, or whose
    ///   disc can't hold it, is refused before anything is uploaded.
    public func burnImage(
        at image: URL,
        label: String,
        serverID: String,
        driveID: String?,
        needs: SpoolNodeCapabilities? = nil,
        options: SpoolBurnOptions,
        telemetry store: any KroutonDriveTelemetryStore,
        telemetryKey: String
    ) async -> SpoolRemoteBurnOutcome {
        await burnUpload(of: image, content: .image, label: label, serverID: serverID, driveID: driveID,
                         needs: needs, options: options, telemetry: store, telemetryKey: telemetryKey)
    }

    /// Sends the contents of `folder` to a server that builds the disc itself
    /// (`SpoolServerWelcome.buildsDiscsFromFolders`), then burns it like `burnImage`. The folder is
    /// packed into a temporary KRSP bundle first, so problems such as links or names a disc cannot
    /// hold are reported before anything is uploaded. This is how a Mac without its own mastering
    /// tools, or an iPad, burns data discs.
    public func burnFolder(
        at folder: URL,
        label: String,
        serverID: String,
        driveID: String?,
        needs: SpoolNodeCapabilities? = nil,
        options: SpoolBurnOptions,
        telemetry store: any KroutonDriveTelemetryStore,
        telemetryKey: String
    ) async -> SpoolRemoteBurnOutcome {
        guard server(withID: serverID) ?? pairedServers.first != nil else {
            return Self.notPaired
        }
        let bundle = FileManager.default.temporaryDirectory
            .appendingPathComponent("krouton-\(UUID().uuidString).krspbundle")
        defer { try? FileManager.default.removeItem(at: bundle) }
        statusBannerText = "Packing \(label)…"
        do {
            let summary = try await Task.detached(priority: .userInitiated) {
                try SpoolBundleWriter.bundle(folder: folder, to: bundle)
            }.value
            appendEventLog("Packed \(label): \(summary.files) files in \(summary.folders) folders")
        } catch {
            statusBannerText = error.localizedDescription
            return SpoolRemoteBurnOutcome(succeeded: false, message: error.localizedDescription,
                                          serverName: "", driveName: "", job: nil)
        }
        return await burnUpload(of: bundle, content: .files, label: label, serverID: serverID, driveID: driveID,
                                needs: needs, options: options, telemetry: store, telemetryKey: telemetryKey)
    }

    private static var notPaired: SpoolRemoteBurnOutcome {
        SpoolRemoteBurnOutcome(succeeded: false, message: "Pair a burn server first (Settings › Burners & Network).",
                               serverName: "", driveName: "", job: nil)
    }

    private func burnUpload(
        of image: URL,
        content: SpoolUploadContent,
        label: String,
        serverID: String,
        driveID: String?,
        needs: SpoolNodeCapabilities?,
        options: SpoolBurnOptions,
        telemetry store: any KroutonDriveTelemetryStore,
        telemetryKey: String
    ) async -> SpoolRemoteBurnOutcome {
        guard let server = server(withID: serverID) ?? pairedServers.first else {
            return Self.notPaired
        }
        let job = UUID().uuidString
        telemetryTarget = (store, telemetryKey, job)
        lastTelemetry[job] = nil
        isSpoolingImage = true
        spoolProgressFraction = 0
        defer { isSpoolingImage = false }

        statusBannerText = "Preparing \(label) for \(server.name)…"
        let manifest: SpoolTransferManifest
        do {
            manifest = try await Task.detached(priority: .userInitiated) { try SpoolTransferManifest.forImage(at: image) }.value
        } catch {
            return outcome(false, "Could not read the upload: \(error.localizedDescription)", server, "", job)
        }
        guard let offer = manifest.encodeManifestOffer() else {
            return outcome(false, "The image is too large to describe in one manifest", server, "", job)
        }
        let imageBytes = (try? FileManager.default.attributesOfItem(atPath: image.path)[.size] as? Int64) ?? 0

        var drive = ""
        var attempt = 0
        uploadLoop: while true {
            attempt += 1
            do {
                let connection = try await ensureSession(for: server)
                // What is in the trays now, not when the session opened, then the check.
                await awaitFreshDrives(on: connection)
                drive = try SpoolDriveInfo.choose(from: remoteDrives, requested: driveID, imageBytes: imageBytes, needs: needs).get().id
                let submit = SpoolControl.submit(job: job, drive: drive, label: label, content: content, options: options)
                try await withCheckedThrowingContinuation { (waiter: CheckedContinuation<Void, Error>) in
                    acceptWaiters[job] = waiter
                    Task {
                        do {
                            try await connection.send(frames: [submit.frame(), offer])
                        } catch {
                            acceptWaiters.removeValue(forKey: job)?.resume(throwing: error)
                        }
                    }
                }
                appendEventLog("\(server.name): \(attempt == 1 ? "uploading" : "resuming upload of") \(label)")
                let phase = try await withCheckedThrowingContinuation { (waiter: CheckedContinuation<SpoolUploadSender.Phase, Error>) in
                    uploadWaiter = waiter
                    Task {
                        do {
                            try await connection.startUpload(file: image, manifest: manifest)
                        } catch {
                            uploadWaiter?.resume(throwing: error)
                            uploadWaiter = nil
                        }
                    }
                }
                switch phase {
                case .complete:
                    break uploadLoop
                case .sourceChanged:
                    return outcome(false, "The file changed while it was being uploaded", server, drive, job)
                default:
                    throw SpoolServerConnection.Failure.protocolError("Upload stopped (\(phase))")
                }
            } catch let remote as SpoolRemoteError where remote.code != .internalError {
                return outcome(false, remote.message, server, drive, job)
            } catch {
                guard attempt < 6, !Task.isCancelled else {
                    return outcome(false, "Upload to \(server.name) failed: \(Self.describe(error))", server, drive, job)
                }
                statusBannerText = "Connection to \(server.name) lost; resuming…"
                await closeSession()
                try? await Task.sleep(for: .seconds(min(30, 2 << attempt)))
            }
        }

        spoolProgressFraction = 1
        statusBannerText = "\(label) uploaded; waiting for \(server.name)"
        let final = await waitForTerminalState(job: job, server: server)
        let driveName = remoteDrives.first { $0.id == drive }?.name ?? drive
        return outcome(final.state == .done, Self.describe(final), server, driveName, job)
    }

    /// Asks for the drives again and waits up to five seconds for the answer.
    private func awaitFreshDrives(on connection: SpoolServerConnection) async {
        let before = remoteDrivesRevision
        try? await connection.send([.listDrives])
        for _ in 0..<25 where remoteDrivesRevision == before {
            try? await Task.sleep(for: .milliseconds(200))
        }
    }

    /// Follows a job until it finishes, reconnecting and re-watching if the connection drops
    /// during a long burn. Gives up after roughly half an hour without contact.
    private func waitForTerminalState(job: String, server: SpoolPairedServer) async -> SpoolJobInfo {
        var failures = 0
        while !Task.isCancelled {
            if let info = jobs.first(where: { $0.job == job }), info.state.isTerminal {
                return info
            }
            if session?.server.nodeID != server.nodeID || session?.phase != .ready {
                do {
                    try await ensureSession(for: server).send([.watch(job: job)])
                    failures = 0
                } catch {
                    failures += 1
                    if failures > 90 { break }
                }
            }
            try? await Task.sleep(for: .seconds(2))
        }
        return SpoolJobInfo(job: job, drive: "", label: "The burn", state: .failed, fraction: nil, queueAhead: 0,
                            message: "lost contact with \(server.name); check it with `krouton-server` or retry later")
    }

    private func outcome(_ ok: Bool, _ message: String, _ server: SpoolPairedServer, _ drive: String, _ job: String) -> SpoolRemoteBurnOutcome {
        statusBannerText = message
        appendEventLog("\(server.name): \(message)")
        return SpoolRemoteBurnOutcome(succeeded: ok, message: message, serverName: server.name, driveName: drive, job: job)
    }
}
