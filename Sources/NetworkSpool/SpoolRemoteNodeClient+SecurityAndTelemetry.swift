import CryptoKit
import Foundation
import Network
import OpticalCore

// MARK: - SpoolRemoteNodeClient Spool-and-Burn, Artifacts, LAN Security & Telemetry Sanitizer

@MainActor
extension SpoolRemoteNodeClient {
    public func executeSpoolAndBurn(
        endpoint: String,
        stagedFiles: [KroutonStagedFileEntry],
        audioTracks: [KroutonRedBookTrack],
        volumeTitle: String,
        performer: String,
        mcnBarcode: String,
        requestedSpeedLabel: String,
        simulationMode: Bool,
        driveManager: any KroutonDriveTelemetryStore,
        targetDriveKey: String = "network-spool-drive"
    ) async -> Bool {
        let batchID = UUID()
        self.lastBatchID = batchID

        let parsedHeatX: UInt8 = {
            let digits = requestedSpeedLabel.prefix(while: { $0.isNumber })
            if let v = UInt8(digits), v > 0 { return v }
            return lastCalibration?.maxSafeDvdHeatX ?? 16
        }()

        isSpoolingImage = true
        spoolProgressFraction = 0.0
        let hostPort = normalizedHostPort(from: endpoint)
        statusBannerText = "Allocating Spool Cache Slot on \(hostPort)..."
        appendEventLog("POST /api/v1/spool/slot -> Requesting Spool Slot on \(hostPort)")

        var tel = driveManager.driveTelemetry[targetDriveKey] ?? KroutonDrivePhaseScopeTelemetry(
            id: targetDriveKey,
            driveName: remoteDrives.first?.name ?? "Remote LAN Optical Drive"
        )
        tel.isActive = true
        tel.samples.removeAll()
        tel.elapsedSeconds = 0
        tel.phaseTitle = "Connecting to Spool Daemon on \(hostPort)..."
        driveManager.driveTelemetry[targetDriveKey] = tel

        func failSpool(_ reason: String) -> Bool {
            isSpoolingImage = false
            isDaemonReachable = false
            applySpoolEventToTelemetry(
                SpoolNodeEventMessage(
                    event: "BURN_FAILED",
                    batchId: batchID,
                    driveId: remoteDrives.first?.id,
                    currentCube: nil,
                    crispnessPct: 0.0,
                    butterBufferPct: 0.0,
                    heatX: 0.0,
                    reason: reason
                ),
                driveManager: driveManager,
                targetDriveKey: targetDriveKey
            )
            return false
        }

        guard let base = normalizedBaseURL(from: endpoint),
              let slotURL = URL(string: "/api/v1/spool/slot", relativeTo: base) else {
            return failSpool("Invalid spool endpoint: \(hostPort)")
        }

        let stagedDataBytes = stagedFiles.reduce(Int64(0)) { $0 + max(0, $1.byteSize) }
        let audioDataBytes = audioTracks.reduce(Int64(0)) { $0 + max(0, $1.redBookByteSize) }
        let totalStagedBytes = UInt64(max(0, stagedDataBytes + audioDataBytes))

        var slotReq = URLRequest(url: slotURL)
        slotReq.httpMethod = "POST"
        slotReq.setValue("application/json", forHTTPHeaderField: "Content-Type")
        slotReq.httpBody = try? JSONEncoder().encode(["volume_title": volumeTitle, "requested_bytes": String(totalStagedBytes)])

        guard let (slotData, slotResp) = try? await session.data(for: slotReq),
              let slotHTTP = slotResp as? HTTPURLResponse,
              (200..<300).contains(slotHTTP.statusCode),
              let slotInfo = try? JSONDecoder().decode(SpoolDriveSlotResponse.self, from: slotData) else {
            return failSpool("Spool daemon unreachable on \(hostPort).")
        }

        let spoolJobID = slotInfo.spoolJobId
        if slotInfo.freeBytes < SpoolNetworkConstants.minimumSpoolFreeBytes {
            let freeMB = Double(slotInfo.freeBytes) / 1_048_576.0
            return failSpool(String(format: "Spool Cache Low Space (%.0f MB < 1024 MB minimum)", freeMB))
        }
        appendEventLog("Spool Cache Slot \(spoolJobID.uuidString.prefix(8)) Allocated (\(slotInfo.freeBytes / 1_073_741_824) GiB Free)")

        guard let chunkURL = URL(string: "/api/v1/spool/slot/\(spoolJobID.uuidString)/chunk", relativeTo: base) else {
            return failSpool("Could not construct spool chunk URL.")
        }

        let sourceURLs: [URL] = stagedFiles.map(\.url) + audioTracks.map(\.url)
        let chunkSize = 65_536
        var bytesSent: UInt64 = 0
        for fileURL in sourceURLs {
            guard let handle = try? FileHandle(forReadingFrom: fileURL) else {
                return failSpool("Could not read staged file: \(fileURL.lastPathComponent)")
            }
            defer { try? handle.close() }
            while let chunk = try? handle.read(upToCount: chunkSize), !chunk.isEmpty {
                var chunkReq = URLRequest(url: chunkURL)
                chunkReq.httpMethod = "POST"
                chunkReq.httpBody = chunk
                guard let (_, cResp) = try? await session.data(for: chunkReq),
                      let cHTTP = cResp as? HTTPURLResponse,
                      (200..<300).contains(cHTTP.statusCode) else {
                    return failSpool("Chunk upload failed on \(hostPort) while sending \(fileURL.lastPathComponent).")
                }
                bytesSent += UInt64(chunk.count)
                if totalStagedBytes > 0 {
                    spoolProgressFraction = min(1.0, Double(bytesSent) / Double(totalStagedBytes))
                }
                statusBannerText = String(format: "Spooling Image to Cache: %.0f%%", spoolProgressFraction * 100.0)
            }
        }
        spoolProgressFraction = 1.0
        isSpoolingImage = false
        appendEventLog("Spool Cache Upload Complete -> Dispatching POST /api/v1/bake")

        let cubePayloads: [SpoolTrackPayload] = audioTracks.enumerated().map { idx, c in
            SpoolTrackPayload(
                trackNumber: UInt8(idx + 1),
                filename: c.url.lastPathComponent,
                title: c.title,
                performer: c.performer,
                isrc: c.isrcCode.isEmpty ? nil : c.isrcCode,
                pregapMs: UInt32(c.preGapSeconds * 1000.0)
            )
        }
        guard let targetRemoteDriveID = remoteDrives.first?.id else {
            return failSpool("No remote optical drives reported by \(hostPort).")
        }
        let bakeReq = SpoolBurnRequest(
            batchId: batchID,
            spoolJobId: spoolJobID,
            driveIds: [targetRemoteDriveID],
            heatX: parsedHeatX,
            mode: simulationMode ? .proofOnly : .burnMedia,
            retentionPolicy: retentionPolicy,
            masteringOptions: SpoolMasteringOptions(albumTitle: volumeTitle, performer: performer, songwriter: nil, upcEan: mcnBarcode),
            cubes: cubePayloads
        )

        guard let bakeURL = URL(string: "/api/v1/bake", relativeTo: base) else {
            return failSpool("Could not construct /api/v1/bake URL.")
        }
        var req = URLRequest(url: bakeURL)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try? JSONEncoder().encode(bakeReq)
        guard let (_, resp) = try? await session.data(for: req),
              let http = resp as? HTTPURLResponse,
              (200..<300).contains(http.statusCode) else {
            return failSpool("Remote daemon rejected /api/v1/bake request on \(hostPort).")
        }

        isDaemonReachable = true
        appendEventLog("Remote Spool Daemon Accepted Batch \(batchID.uuidString.prefix(8)) -> Streaming WS /api/v1/spool/events")
        connectKitchenWebSocket(endpoint: endpoint, driveManager: driveManager, targetDriveKey: targetDriveKey)
        return true
    }

    public func preparePhaseScopeTelemetryArtifact(endpoint: String? = nil) async -> SpoolExportedArtifact {
        let target = endpoint ?? activeEndpointHost
        if let base = normalizedBaseURL(from: target),
           let url = URL(string: "/api/v1/spool/telemetry", relativeTo: base),
           let (data, resp) = try? await session.data(from: url),
           let http = resp as? HTTPURLResponse, (200..<300).contains(http.statusCode),
           let liveText = String(data: data, encoding: .utf8), !liveText.isEmpty {
            let filename = "Spool_Telemetry_\(lastBatchID.uuidString.prefix(8)).log"
            appendEventLog("Exported live telemetry artifact (\(filename))")
            return SpoolExportedArtifact(defaultFilename: filename, contentText: liveText)
        }

        let reportBody = """
        ===================================================================
        OPTICAL SPOOL TELEMETRY — CLIENT EVENT LOG (PORT 7420)
        Endpoint : \(normalizedHostPort(from: target)) (Daemon Unreachable)
        Batch ID : \(lastBatchID.uuidString)
        Retention Policy : \(retentionPolicy.rawValue)
        ===================================================================

        --- RECENT CLIENT EVENTS ---
        \(recentKitchenEvents.joined(separator: "\n"))
        """
        let filename = "Spool_Telemetry_\(lastBatchID.uuidString.prefix(8)).log"
        appendEventLog("Prepared client event log artifact (\(filename))")
        return SpoolExportedArtifact(defaultFilename: filename, contentText: reportBody)
    }

    public func prepareDiagnosticBundleArtifact(endpoint: String? = nil) async -> SpoolExportedArtifact {
        let target = endpoint ?? activeEndpointHost
        if let base = normalizedBaseURL(from: target),
           let url = URL(string: "/api/v1/spool/diagnostics/\(lastBatchID.uuidString)", relativeTo: base),
           let (data, resp) = try? await session.data(from: url),
           let http = resp as? HTTPURLResponse, (200..<300).contains(http.statusCode),
           let str = String(data: data, encoding: .utf8), !str.isEmpty {
            let filename = "Spool_Diagnostics_\(lastBatchID.uuidString.prefix(8)).txt"
            appendEventLog("Exported live diagnostic bundle for Batch \(lastBatchID.uuidString.prefix(8))")
            return SpoolExportedArtifact(defaultFilename: filename, contentText: str)
        }
        let finalBody = """
        # Optical Spool Diagnostic Bundle (Policy: \(retentionPolicy.rawValue))
        Batch ID: \(lastBatchID.uuidString)
        Host: \(normalizedHostPort(from: target))
        Status: Spool daemon unreachable on \(normalizedHostPort(from: target)); no remote diagnostic bundle available.
        """
        let filename = "Spool_Diagnostics_\(lastBatchID.uuidString.prefix(8)).txt"
        appendEventLog("Prepared offline diagnostic note for Batch \(lastBatchID.uuidString.prefix(8))")
        return SpoolExportedArtifact(defaultFilename: filename, contentText: finalBody)
    }
}

// MARK: - Chunk 1: Krumb LAN Security Engine (RFC-1918 Subnet Guard + HMAC-SHA256 + Replay Protection)
public struct SpoolSignedEnvelope: Codable, Sendable, Equatable {
    let timestampEpochSeconds: Int64
    let nonce: String
    let signatureHex: String
    let payloadBase64: String

    public init(timestampEpochSeconds: Int64, nonce: String, signatureHex: String, payloadBase64: String) {
        self.timestampEpochSeconds = timestampEpochSeconds
        self.nonce = nonce
        self.signatureHex = signatureHex
        self.payloadBase64 = payloadBase64
    }
}

public enum SpoolLANSecurityEngine {
    static let maxClockSkewSeconds: Int64 = 30

    /// Validates that an endpoint host belongs strictly to loopback, mDNS (.local), or RFC-1918 / RFC-3927 private LAN ranges.
    public static func isAllowedLANEndpoint(_ rawEndpoint: String) -> Bool {
        let trimmed = rawEndpoint.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !trimmed.isEmpty else { return false }

        // Strip scheme if present
        var hostPart = trimmed
        for prefix in ["http://", "https://", "ws://", "wss://"] {
            if hostPart.hasPrefix(prefix) {
                hostPart = String(hostPart.dropFirst(prefix.count))
                break
            }
        }
        // Strip path if present
        if let slashIdx = hostPart.firstIndex(of: "/") {
            hostPart = String(hostPart[..<slashIdx])
        }
        // Handle IPv6 brackets [::1]:7420 or host:port
        if hostPart.hasPrefix("[") {
            if let closeBracket = hostPart.firstIndex(of: "]") {
                let ipv6 = String(hostPart[hostPart.index(after: hostPart.startIndex)..<closeBracket])
                return ipv6 == "::1" || ipv6.hasPrefix("fe80:") || ipv6.hasPrefix("fd") || ipv6.hasPrefix("fc")
            }
            return false
        }
        if let colonIdx = hostPart.firstIndex(of: ":") {
            hostPart = String(hostPart[..<colonIdx])
        }

        if hostPart == "localhost" || hostPart.hasSuffix(".local") || hostPart.hasSuffix(".local.") || hostPart.hasSuffix(".lan") {
            return true
        }

        // Check IPv4 octets
        let parts = hostPart.split(separator: ".", omittingEmptySubsequences: false)
        if parts.count == 4, let o0 = Int(parts[0]), let o1 = Int(parts[1]), let o2 = Int(parts[2]), let o3 = Int(parts[3]) {
            guard (0...255).contains(o0), (0...255).contains(o1), (0...255).contains(o2), (0...255).contains(o3) else {
                return false
            }
            if o0 == 127 { return true }                                  // 127.0.0.0/8 Loopback
            if o0 == 10 { return true }                                   // 10.0.0.0/8 RFC-1918 Class A
            if o0 == 172 && (16...31).contains(o1) { return true }        // 172.16.0.0/12 RFC-1918 Class B
            if o0 == 192 && o1 == 168 { return true }                     // 192.168.0.0/16 RFC-1918 Class C
            if o0 == 169 && o1 == 254 { return true }                     // 169.254.0.0/16 Link-Local Bonjour
            return false
        }

        return false
    }

    /// Computes a deterministic HMAC-SHA256 signature over `timestamp.nonce.payloadBase64`
    static func signPayload(
        _ payload: Data,
        sharedSecret: String,
        timestampEpochSeconds: Int64 = Int64(Date().timeIntervalSince1970),
        nonce: String = UUID().uuidString.lowercased()
    ) -> SpoolSignedEnvelope {
        let b64 = payload.base64EncodedString()
        let canonicalMessage = "\(timestampEpochSeconds).\(nonce).\(b64)"
        let key = SymmetricKey(data: Data(sharedSecret.utf8))
        let mac = HMAC<SHA256>.authenticationCode(for: Data(canonicalMessage.utf8), using: key)
        let sigHex = mac.map { String(format: "%02x", $0) }.joined()
        return SpoolSignedEnvelope(
            timestampEpochSeconds: timestampEpochSeconds,
            nonce: nonce,
            signatureHex: sigHex,
            payloadBase64: b64
        )
    }

    /// Verifies HMAC-SHA256 authenticity, clock skew window (+/- 30s), and optional nonce replay set
    static func verifyEnvelope(
        _ envelope: SpoolSignedEnvelope,
        sharedSecret: String,
        nowEpochSeconds: Int64 = Int64(Date().timeIntervalSince1970),
        seenNonces: inout Set<String>
    ) -> Data? {
        guard !envelope.nonce.isEmpty else { return nil }
        guard abs(nowEpochSeconds - envelope.timestampEpochSeconds) <= maxClockSkewSeconds else {
            return nil
        }
        guard !seenNonces.contains(envelope.nonce) else {
            return nil
        }
        guard let rawPayload = Data(base64Encoded: envelope.payloadBase64) else {
            return nil
        }

        let expected = signPayload(
            rawPayload,
            sharedSecret: sharedSecret,
            timestampEpochSeconds: envelope.timestampEpochSeconds,
            nonce: envelope.nonce
        )

        guard expected.signatureHex == envelope.signatureHex.lowercased() else {
            return nil
        }
        seenNonces.insert(envelope.nonce)
        return rawPayload
    }
}

// MARK: - Chunk 7: Deterministic Telemetry State Machine & Monotonic Progress Filter
public enum SpoolTelemetryPhase: String, Codable, Sendable, Equatable {
    case idle             = "IDLE"
    case preheating       = "PREHEATING"
    case burningProgress = "BURNING_PROGRESS"
    case verifyingSectors   = "VERIFYING_SECTORS"
    case burnCompleted   = "BURN_COMPLETED"
    case burnFailed       = "BURN_FAILED"
    case cancelled        = "CANCELLED"
}

public struct SpoolTelemetryPacket: Codable, Sendable, Equatable {
    public let batchId: UUID
    public let driveId: String
    public let state: SpoolTelemetryPhase
    public let fraction: Double
    public let currentLba: Int64
    public let totalLba: Int64
    public let effectiveSpeedX: Double
    public let fifoFill: Double
    public let driveBufferFill: Double
    public let c2Errors: Int
    public let etaSeconds: Int

    public init(
        batchId: UUID,
        driveId: String,
        state: SpoolTelemetryPhase,
        fraction: Double,
        currentLba: Int64,
        totalLba: Int64,
        effectiveSpeedX: Double,
        fifoFill: Double,
        driveBufferFill: Double,
        c2Errors: Int,
        etaSeconds: Int
    ) {
        self.batchId = batchId
        self.driveId = driveId
        self.state = state
        self.fraction = fraction
        self.currentLba = currentLba
        self.totalLba = totalLba
        self.effectiveSpeedX = effectiveSpeedX
        self.fifoFill = fifoFill
        self.driveBufferFill = driveBufferFill
        self.c2Errors = c2Errors
        self.etaSeconds = etaSeconds
    }
}

public enum SpoolTelemetrySanitizer {
    /// Clamps and filters incoming WebSocket progress frames so out-of-order packets or NaN/Inf values
    /// never cause progress regressions, negative buffer fill, or division-by-zero in the UI.
    public static func sanitizeProgressTransition(
        previousState: SpoolTelemetryPhase,
        previousFraction: Double,
        incomingFrame: SpoolTelemetryPacket
    ) -> (state: SpoolTelemetryPhase, fraction: Double, fifoClamp: Double, driveClamp: Double) {
        let cleanFifo = incomingFrame.fifoFill.isFinite ? max(0.0, min(1.0, incomingFrame.fifoFill)) : 0.0
        let cleanDrive = incomingFrame.driveBufferFill.isFinite ? max(0.0, min(1.0, incomingFrame.driveBufferFill)) : 0.0
        let rawFrac = incomingFrame.fraction.isFinite ? max(0.0, min(1.0, incomingFrame.fraction)) : previousFraction

        // Terminal states (BURN_COMPLETED, BURN_FAILED, CANCELLED) cannot regress to BURNING_PROGRESS
        let isPrevTerminal = (previousState == .burnCompleted || previousState == .burnFailed || previousState == .cancelled)
        if isPrevTerminal && (incomingFrame.state == .burningProgress || incomingFrame.state == .preheating) {
            return (previousState, previousFraction, cleanFifo, cleanDrive)
        }

        // During monotonic active burn (BURNING_PROGRESS -> BURNING_PROGRESS), ignore late stale UDP/WS packets
        let monotonicFrac: Double
        if previousState == .burningProgress && incomingFrame.state == .burningProgress {
            monotonicFrac = max(previousFraction, rawFrac)
        } else if incomingFrame.state == .burnCompleted {
            monotonicFrac = 1.0
        } else {
            monotonicFrac = rawFrac
        }

        return (incomingFrame.state, monotonicFrac, cleanFifo, cleanDrive)
    }
}

/// Reads a binary sector frame for LAN spooling (from temporary staging payload if present on disk, or big-endian frame header).
func kroutonReadSpoolChunkBytes(chunkIndex: Int, chunkSize: Int) -> Data {
    let stagingURL = FileManager.default.temporaryDirectory
        .appendingPathComponent("KroutonDepotStaging", isDirectory: true)
        .appendingPathComponent("Krouton_Master_Output.iso")
    if FileManager.default.fileExists(atPath: stagingURL.path) {
        do {
            let handle = try FileHandle(forReadingFrom: stagingURL)
            defer { try? handle.close() }
            let offset = UInt64(max(0, chunkIndex) * max(512, chunkSize))
            try handle.seek(toOffset: offset)
            if let data = try handle.read(upToCount: max(512, chunkSize)), !data.isEmpty {
                return data
            }
        } catch {
            KroutonDiagnostics.networkLogger.error("Spool chunk read error at index \(chunkIndex): \(error.localizedDescription, privacy: .public)")
        }
    }
    var sectorHeader = Data(count: max(64, min(4096, chunkSize)))
    let idxBE = UInt32(max(0, chunkIndex)).bigEndian
    withUnsafeBytes(of: idxBE) { raw in
        for i in 0..<4 { sectorHeader[i] = raw[i] }
    }
    return sectorHeader
}
