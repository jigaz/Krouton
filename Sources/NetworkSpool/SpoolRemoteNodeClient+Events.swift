import CryptoKit
import Foundation
import OpticalCore

// MARK: - Session Events, Drives & Jobs

@MainActor
extension SpoolRemoteNodeClient {
    static let appName = "Krouton"

    func handle(_ event: SpoolServerConnection.Event, connection: SpoolServerConnection, server: SpoolPairedServer,
                signing: Curve25519.Signing.PrivateKey) async throws {
        switch event {
        case .control(let message):
            try await handle(message, connection: connection, server: server, signing: signing)
        case .telemetry(let packet):
            applyTelemetry(packet)
        case .upload(let acknowledged, let total, let phase):
            spoolProgressFraction = total > 0 ? Double(acknowledged) / Double(total) : 0
            if case .streaming = phase {
                statusBannerText = String(format: "Uploading to %@: %.0f%%", server.name, spoolProgressFraction * 100)
            } else if case .awaitingBitmap = phase {
                return
            } else {
                uploadWaiter?.resume(returning: phase)
                uploadWaiter = nil
            }
        }
    }

    private func handle(_ message: SpoolControl, connection: SpoolServerConnection, server: SpoolPairedServer,
                        signing: Curve25519.Signing.PrivateKey) async throws {
        switch message {
        case .auth(let key, let signature):
            // The server must prove it holds the identity pinned at pairing, over this TLS session.
            guard session?.phase == .awaitingAuth,
                  key == SpoolHex.decode(server.identityKey),
                  let pinned = try? Curve25519.Signing.PublicKey(rawRepresentation: key),
                  SpoolSessionProof.verify(signature, exporter: connection.exporter, role: "node", pinnedKey: pinned) else {
                throw SpoolServerConnection.Failure.untrustedServer
            }
            let proof = try SpoolSessionProof.sign(exporter: connection.exporter, role: "workstation", identity: signing)
            try await connection.send([
                .auth(identityKey: signing.publicKey.rawRepresentation, signature: proof),
                .hello(app: Self.appName, deviceName: deviceName)
            ])
            session?.phase = .awaitingWelcome
        case .welcome(let welcome):
            serverWelcome = welcome
            remoteDrives = welcome.drives
            connectedServerID = server.nodeID
            session?.phase = .ready
            let free = ByteCountFormatter.string(fromByteCount: Int64(clamping: welcome.freeBytes), countStyle: .file)
            statusBannerText = "\(welcome.serverName): \(welcome.drives.count) drive\(welcome.drives.count == 1 ? "" : "s"), \(free) free"
            appendEventLog("Connected to \(welcome.serverName) (Krouton Server \(welcome.version))")
            if welcome.nodeID != server.nodeID {
                appendEventLog("Warning: \(welcome.serverName) reports node \(welcome.nodeID), paired as \(server.nodeID)")
            }
            readyWaiters.forEach { $0.resume() }
            readyWaiters.removeAll()
        case .drives(let drives):
            remoteDrives = drives
        case .jobs(let list):
            jobs = list
        case .job(let info):
            upsert(info)
        case .accepted(let job):
            acceptWaiters.removeValue(forKey: job)?.resume()
        case .error(let code, let text, let job):
            appendEventLog("\(server.name): \(text)")
            let failure = SpoolRemoteError(code: code, message: text)
            if let job, let waiter = acceptWaiters.removeValue(forKey: job) {
                waiter.resume(throwing: failure)
            } else if session?.phase != .ready {
                throw failure
            } else if uploadWaiter != nil {
                uploadWaiter?.resume(throwing: failure)
                uploadWaiter = nil
            } else {
                statusBannerText = text
            }
        case .pong, .ping:
            break
        default:
            appendEventLog("\(server.name): ignored unexpected \(message)")
        }
    }

    func upsert(_ info: SpoolJobInfo) {
        if let index = jobs.firstIndex(where: { $0.job == info.job }) {
            jobs[index] = info
        } else {
            jobs.append(info)
        }
        if telemetryTarget?.job == info.job {
            statusBannerText = Self.describe(info)
        }
    }

    static func describe(_ job: SpoolJobInfo) -> String {
        switch job.state {
        case .receiving: return "Uploading \(job.label)"
        case .queued: return job.queueAhead == 0 ? "\(job.label): next in line" : "\(job.label): \(job.queueAhead) ahead in the queue"
        case .burning, .verifying:
            let pct = job.fraction.map { String(format: " %.0f%%", $0 * 100) } ?? ""
            return "\(job.label): \(job.message)\(pct)"
        case .done: return "\(job.label): burned and verified"
        case .failed: return "\(job.label) failed: \(job.message)"
        case .cancelled: return "\(job.label): cancelled"
        }
    }

    static func describe(_ error: Error) -> String {
        switch error {
        case let remote as SpoolRemoteError: return remote.message
        case SpoolServerConnection.Failure.unreachable(let why): return "unreachable: \(why)"
        case SpoolServerConnection.Failure.refusedAddress(let reason): return "the server resolved to a non-local address (\(reason))"
        case SpoolServerConnection.Failure.untrustedServer: return "the server could not prove its paired identity"
        case SpoolServerConnection.Failure.closed: return "closed"
        case SpoolServerConnection.Failure.protocolError(let why): return why
        case let identity as SpoolClientIdentityError: return "this Mac's keys are unavailable (\(identity))"
        case let pairing as SpoolPairingError:
            return pairing == .commitmentMismatch ? "the server changed its key mid-pairing (possible interception)" : "the server's pairing message was malformed"
        default: return error.localizedDescription
        }
    }

    // MARK: - Telemetry Into the Phase Scope

    func applyTelemetry(_ packet: SpoolTelemetryPacket) {
        guard let target = telemetryTarget, packet.batchId.uuidString.caseInsensitiveCompare(target.job) == .orderedSame else { return }
        let previous = lastTelemetry[target.job] ?? (.idle, 0)
        let clean = SpoolTelemetrySanitizer.sanitizeProgressTransition(previousState: previous.0, previousFraction: previous.1,
                                                                        incomingFrame: packet)
        lastTelemetry[target.job] = (clean.state, clean.fraction)
        var tel = target.store.driveTelemetry[target.key]
            ?? KroutonDrivePhaseScopeTelemetry(id: target.key, driveName: remoteDrives.first { $0.id == packet.driveId }?.name ?? "Krouton Server")
        let speed = packet.effectiveSpeedX.isFinite ? max(0, packet.effectiveSpeedX) : 0
        tel.isActive = !(clean.state == .burnCompleted || clean.state == .burnFailed || clean.state == .cancelled)
        tel.phaseTitle = switch clean.state {
        case .preheating: "Spinning up"
        case .burningProgress: String(format: "Writing (%.0f%%)", clean.fraction * 100)
        case .verifyingSectors: String(format: "Verifying (%.0f%%)", clean.fraction * 100)
        case .burnCompleted: "Burned and verified"
        case .burnFailed: "Burn failed"
        case .cancelled: "Cancelled"
        case .idle: "Waiting"
        }
        tel.progressFraction = clean.fraction
        tel.currentSpeedX = speed
        tel.currentSpeedKBs = speed * 1_385
        tel.peakSpeedX = max(tel.peakSpeedX, speed)
        if speed > 0 { tel.averageSpeedX = tel.averageSpeedX == 0 ? speed : tel.averageSpeedX * 0.85 + speed * 0.15 }
        tel.bufferFillPercent = clean.driveClamp * 100
        tel.totalSectorsLBA = packet.totalLba
        tel.currentSectorLBA = packet.currentLba
        tel.samples.append(KroutonBurnTelemetrySample(progressFraction: clean.fraction, speedMultiplierX: speed,
                                                      spindleRPM: 0, throughputKBs: speed * 1_385))
        target.store.driveTelemetry[target.key] = tel
    }

    // MARK: - Drives & Jobs

    /// Connects to `serverID` (a paired server's node ID) and refreshes its drives and jobs.
    public func refreshRemoteDrives(serverID: String? = nil) async {
        guard let server = serverID.flatMap({ self.server(withID: $0) }) ?? pairedServers.first else {
            statusBannerText = "No burn servers paired yet"
            return
        }
        do {
            let connection = try await ensureSession(for: server)
            try await connection.send([.listDrives, .listJobs])
        } catch {
            statusBannerText = "\(server.name): \(Self.describe(error))"
            appendEventLog(statusBannerText)
        }
    }

    public func ejectRemoteDrive(_ driveID: String, serverID: String) async {
        guard let server = server(withID: serverID) else { return }
        do {
            try await ensureSession(for: server).send([.eject(drive: driveID)])
            appendEventLog("\(server.name): eject \(driveID)")
        } catch {
            statusBannerText = "\(server.name): \(Self.describe(error))"
        }
    }

    public func cancelJob(_ job: String) async {
        guard let connection = session?.connection else { return }
        try? await connection.send([.cancel(job: job)])
    }
}

/// An error the server reported, with its stable code.
public struct SpoolRemoteError: Error, Sendable, Equatable {
    public let code: SpoolErrorCode
    public let message: String
}
