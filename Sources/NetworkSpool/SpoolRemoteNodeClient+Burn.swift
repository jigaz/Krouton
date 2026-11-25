import Foundation
import OpticalCore

// MARK: - Burning on a Krouton Server

/// How a remote burn ended.
public struct SpoolRemoteBurnOutcome: Sendable, Equatable {
    public let succeeded: Bool
    public let message: String
    public let serverName: String
    public let driveName: String
    public let job: String?
}

@MainActor
extension SpoolRemoteNodeClient {
    /// Uploads `image` (an ISO/UDF data image) to a paired server and burns it on `driveID` (or the
    /// first ready drive), streaming progress into `store[telemetryKey]`. Uploads resume across
    /// dropped connections; the burn itself runs on the server and is followed until it ends.
    public func burnImage(
        at image: URL,
        label: String,
        serverID: String,
        driveID: String?,
        options: SpoolBurnOptions,
        telemetry store: any KroutonDriveTelemetryStore,
        telemetryKey: String
    ) async -> SpoolRemoteBurnOutcome {
        await burnUpload(of: image, content: .image, label: label, serverID: serverID, driveID: driveID,
                         options: options, telemetry: store, telemetryKey: telemetryKey)
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
                                options: options, telemetry: store, telemetryKey: telemetryKey)
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

        var drive = ""
        var attempt = 0
        uploadLoop: while true {
            attempt += 1
            do {
                let connection = try await ensureSession(for: server)
                drive = try chooseDrive(driveID)
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

    private func chooseDrive(_ requested: String?) throws -> String {
        if let requested, !requested.isEmpty, remoteDrives.contains(where: { $0.id == requested }) {
            return requested
        }
        let ready = remoteDrives.first { $0.media == .blank && !$0.busy } ?? remoteDrives.first { !$0.busy } ?? remoteDrives.first
        guard let ready else { throw SpoolRemoteError(code: .unknownDrive, message: "The server has no optical drives") }
        return ready.id
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
