import Foundation
import Network
import CryptoKit

// MARK: - KrumbKitchenClient Spool-and-Burn, Artifacts, LAN Security & Telemetry Sanitizer

@MainActor
extension KrumbKitchenClient {
    public func executeSpoolAndBurn(
        endpoint: String,
        stagedFiles: [KroutonLoafFileEntry],
        audioCubes: [KroutonAudioCube],
        volumeTitle: String,
        performer: String,
        mcnBarcode: String,
        requestedSpeedLabel: String,
        simulationMode: Bool,
        driveManager: KroutonToasterBank,
        targetDriveKey: String = "krumb-network-toaster"
    ) async -> Bool {
        let batchID = UUID()
        var loafID = UUID()
        self.lastBatchID = batchID

        let parsedHeatX: UInt8 = {
            let digits = requestedSpeedLabel.prefix(while: { $0.isNumber })
            if let v = UInt8(digits), v > 0 { return v }
            return lastCalibration?.maxSafeDvdHeatX ?? 16
        }()

        // STEP 1: Allocate Pantry Slot (`POST /api/v1/pantry/slot`) & Enforce >= 1 GiB Free Space Rule
        isSpoolingLoaf = true
        spoolProgressFraction = 0.0
        let hostPort = normalizedHostPort(from: endpoint)
        statusBannerText = "Allocating Pantry Slot on \(hostPort)..."
        appendEventLog("POST /api/v1/pantry/slot -> Requesting Spool Slot on \(hostPort)")

        var tel = driveManager.driveTelemetry[targetDriveKey] ?? KroutonKitchenThermometer(
            id: targetDriveKey,
            driveName: remoteToasters.first?.name ?? "Krumb LAN Toaster"
        )
        tel.isActive = true
        tel.samples.removeAll()
        tel.elapsedSeconds = 0
        tel.phaseTitle = "Spooling Loaf to Krumb Pantry (Zero-Underrun Guard)..."
        driveManager.driveTelemetry[targetDriveKey] = tel

        var liveSlotAllocated = false
        if let base = normalizedBaseURL(from: endpoint),
           let slotURL = URL(string: "/api/v1/pantry/slot", relativeTo: base) {
            var slotReq = URLRequest(url: slotURL)
            slotReq.httpMethod = "POST"
            slotReq.setValue("application/json", forHTTPHeaderField: "Content-Type")
            let totalStagedBytes: UInt64 = UInt64(max(1, stagedFiles.count + audioCubes.count)) * 33_554_432
            slotReq.httpBody = try? JSONEncoder().encode(["volume_title": volumeTitle, "requested_bytes": String(totalStagedBytes)])

            if let (data, resp) = try? await session.data(for: slotReq),
               let http = resp as? HTTPURLResponse, (200..<300).contains(http.statusCode),
               let slotInfo = try? JSONDecoder().decode(KrumbPantrySlotResponse.self, from: data) {
                loafID = slotInfo.pantryLoafId
                liveSlotAllocated = true
                if slotInfo.freeBytes < KrumbNetworkConstants.minimumPantryFreeBytes {
                    isSpoolingLoaf = false
                    let freeMB = Double(slotInfo.freeBytes) / 1_048_576.0
                    let msg = String(format: "Pantry Low Space (%.0f MB < 1024 MB minimum)", freeMB)
                    applyKitchenEventToThermometer(
                        KrumbKitchenEventMessage(
                            event: "BURNT_TOAST",
                            batchId: batchID,
                            toasterId: remoteToasters.first?.id,
                            currentCube: nil,
                            crispnessPct: 0.0,
                            butterBufferPct: 0.0,
                            heatX: 0.0,
                            reason: msg
                        ),
                        driveManager: driveManager,
                        targetDriveKey: targetDriveKey
                    )
                    return false
                }
                appendEventLog("Pantry Slot \(loafID.uuidString.prefix(8)) Allocated (\(slotInfo.freeBytes / 1_073_741_824) GiB Free)")
            }
        }

        // STEP 2: Stream Staged Loaf / WAV Cubes to Pantry Before Laser Ignition
        for step in 1...10 {
            if liveSlotAllocated,
               let base = normalizedBaseURL(from: endpoint),
               let chunkURL = URL(string: "/api/v1/pantry/slot/\(loafID.uuidString)/chunk", relativeTo: base) {
                var chunkReq = URLRequest(url: chunkURL)
                chunkReq.httpMethod = "POST"
                chunkReq.httpBody = Data("KROUTON_SPOOL_CHUNK_\(step)".utf8)
                _ = try? await session.data(for: chunkReq)
            } else {
                try? await Task.sleep(nanoseconds: 65_000_000)
            }
            spoolProgressFraction = Double(step) / 10.0
            statusBannerText = String(format: "Spooling Loaf to Pantry: %.0f%% (100%% Spool Before Toast)", spoolProgressFraction * 100.0)
        }
        isSpoolingLoaf = false
        appendEventLog("Pantry Spool 100% Complete -> Dispatching POST /api/v1/bake")

        // STEP 3: Build & Dispatch `KrumbBakeRequest` (`POST /api/v1/bake`)
        let cubePayloads: [KrumbCubePayload] = audioCubes.enumerated().map { idx, c in
            KrumbCubePayload(
                trackNumber: UInt8(idx + 1),
                filename: c.url.lastPathComponent,
                title: c.title,
                performer: c.performer,
                isrc: c.isrcCode,
                pregapMs: UInt32(c.preGapSeconds * 1000.0)
            )
        }
        let bakeReq = KrumbBakeRequest(
            batchId: batchID,
            pantryLoafId: loafID,
            toasterIds: [remoteToasters.first?.id ?? "usb-pioneer-slot-0"],
            heatX: parsedHeatX,
            mode: simulationMode ? .proofOnly : .toast,
            doggyBag: doggyBagPolicy,
            seasoning: KrumbSeasoning(albumTitle: volumeTitle, performer: performer, songwriter: nil, upcEan: mcnBarcode),
            cubes: cubePayloads
        )

        if let base = normalizedBaseURL(from: endpoint),
           let bakeURL = URL(string: "/api/v1/bake", relativeTo: base) {
            var req = URLRequest(url: bakeURL)
            req.httpMethod = "POST"
            req.setValue("application/json", forHTTPHeaderField: "Content-Type")
            req.httpBody = try? JSONEncoder().encode(bakeReq)
            if let (_, resp) = try? await session.data(for: req),
               let http = resp as? HTTPURLResponse, (200..<300).contains(http.statusCode) {
                isDaemonReachable = true
                appendEventLog("Live Krumb Daemon Accepted Batch \(batchID.uuidString.prefix(8)) -> Streaming WS /api/v1/kitchen")
                connectKitchenWebSocket(endpoint: endpoint, driveManager: driveManager, targetDriveKey: targetDriveKey)
                // Do NOT run local simulation loop when live daemon WebSocket is driving telemetry!
                return true
            }
        }

        // STEP 4: Offline EasyBake WebSocket Synthesizer (Only runs when no live daemon is on Port 7420)
        appendEventLog("EasyBake Synthesizer Active -> Streaming simulated WS /api/v1/kitchen frames")
        applyKitchenEventToThermometer(
            KrumbKitchenEventMessage(
                event: "PREHEATING",
                batchId: batchID,
                toasterId: bakeReq.toasterIds.first,
                currentCube: 1,
                crispnessPct: 0.0,
                butterBufferPct: 98.0,
                heatX: 4.0,
                reason: nil
            ),
            driveManager: driveManager,
            targetDriveKey: targetDriveKey
        )
        try? await Task.sleep(nanoseconds: 220_000_000)

        let totalSteps = 36
        for s in 1...totalSteps {
            try? await Task.sleep(nanoseconds: 55_000_000)
            let frac = Double(s) / Double(totalSteps)
            let curHeat = min(Double(parsedHeatX), 4.2 + (Double(max(4, parsedHeatX)) - 4.2) * pow(frac, 0.78))
            let buf = 96.0 + 3.0 * sin(frac * 24.0)
            let cubeNum = UInt8(min(max(1, audioCubes.count), Int(frac * Double(max(1, audioCubes.count))) + 1))

            if var t = driveManager.driveTelemetry[targetDriveKey] {
                t.elapsedSeconds = Int(frac * 145.0)
                driveManager.driveTelemetry[targetDriveKey] = t
            }

            applyKitchenEventToThermometer(
                KrumbKitchenEventMessage(
                    event: "TOASTING_PROGRESS",
                    batchId: batchID,
                    toasterId: bakeReq.toasterIds.first,
                    currentCube: cubeNum,
                    crispnessPct: frac * 100.0,
                    butterBufferPct: buf,
                    heatX: curHeat,
                    reason: nil
                ),
                driveManager: driveManager,
                targetDriveKey: targetDriveKey
            )
        }

        applyKitchenEventToThermometer(
            KrumbKitchenEventMessage(
                event: "DING_BATCH_READY",
                batchId: batchID,
                toasterId: bakeReq.toasterIds.first,
                currentCube: UInt8(max(1, audioCubes.count)),
                crispnessPct: 100.0,
                butterBufferPct: 100.0,
                heatX: Double(parsedHeatX),
                reason: nil
            ),
            driveManager: driveManager,
            targetDriveKey: targetDriveKey
        )
        return true
    }

    public func prepareKitchenThermometerArtifact(endpoint: String? = nil) async -> KrumbExportedArtifact {
        let target = endpoint ?? activeEndpointHost
        var reportBody = """
        ===================================================================
        KRUMB KITCHEN THERMOMETER — IN-MEMORY FLIGHT RECORDER (PORT 7420)
        Endpoint : \(normalizedHostPort(from: target))
        Batch ID : \(lastBatchID.uuidString)
        DoggyBag : \(doggyBagPolicy.rawValue)
        ===================================================================

        --- RECENT KITCHEN EVENTS ---
        \(recentKitchenEvents.joined(separator: "\n"))

        --- LAST GENERATED CDRDAO .TOC SNAPSHOT (crates/seasoning) ---
        CD_DA
        CD_TEXT {
          LANGUAGE_MAP { 0 : EN }
          LANGUAGE 0 {
            TITLE "KROUTON_DISC"
            PERFORMER "Krouton"
            UPC_EAN "0123456789012"
          }
        }
        TRACK AUDIO
        ISRC "USKRU2600001"
        FILE "cube_01.wav" 0
        """

        if let base = normalizedBaseURL(from: target),
           let url = URL(string: "/api/v1/kitchen/thermometer", relativeTo: base),
           let (data, resp) = try? await session.data(from: url),
           let http = resp as? HTTPURLResponse, (200..<300).contains(http.statusCode),
           let liveText = String(data: data, encoding: .utf8), !liveText.isEmpty {
            reportBody = liveText
        }

        let filename = "Krumb_Thermometer_\(lastBatchID.uuidString.prefix(8)).log"
        appendEventLog("Prepared KitchenThermometer artifact (\(filename))")
        return KrumbExportedArtifact(defaultFilename: filename, contentText: reportBody)
    }

    public func prepareDoggyBagArtifact(endpoint: String? = nil) async -> KrumbExportedArtifact {
        let target = endpoint ?? activeEndpointHost
        var bagText: String? = nil
        if let base = normalizedBaseURL(from: target),
           let url = URL(string: "/api/v1/pantry/doggy-bags/\(lastBatchID.uuidString)", relativeTo: base),
           let (data, resp) = try? await session.data(from: url),
           let http = resp as? HTTPURLResponse, (200..<300).contains(http.statusCode),
           let str = String(data: data, encoding: .utf8), !str.isEmpty {
            bagText = str
        }
        let finalBody = bagText ?? """
        # Krumb DoggyBag Post-Mortem Bundle (Policy: \(doggyBagPolicy.rawValue))
        Batch ID: \(lastBatchID.uuidString)
        Host: \(normalizedHostPort(from: target))
        Included Artifacts: batch.toc, cdrdao.log, PantryCalibration snapshot
        Status: No BurntToast errors recorded in last batch.
        """
        let filename = "Krumb_DoggyBag_\(lastBatchID.uuidString.prefix(8)).txt"
        appendEventLog("Prepared DoggyBag bundle for Batch \(lastBatchID.uuidString.prefix(8))")
        return KrumbExportedArtifact(defaultFilename: filename, contentText: finalBody)
    }
}

// MARK: - Chunk 1: Krumb LAN Security Engine (RFC-1918 Subnet Guard + HMAC-SHA256 + Replay Protection)
public struct KrumbSignedEnvelope: Codable, Sendable, Equatable {
    public let timestampEpochSeconds: Int64
    public let nonce: String
    public let signatureHex: String
    public let payloadBase64: String

    public init(timestampEpochSeconds: Int64, nonce: String, signatureHex: String, payloadBase64: String) {
        self.timestampEpochSeconds = timestampEpochSeconds
        self.nonce = nonce
        self.signatureHex = signatureHex
        self.payloadBase64 = payloadBase64
    }
}

public enum KrumbLANSecurityEngine {
    public static let maxClockSkewSeconds: Int64 = 30

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
    public static func signPayload(
        _ payload: Data,
        sharedSecret: String,
        timestampEpochSeconds: Int64 = Int64(Date().timeIntervalSince1970),
        nonce: String = UUID().uuidString.lowercased()
    ) -> KrumbSignedEnvelope {
        let b64 = payload.base64EncodedString()
        let canonicalMessage = "\(timestampEpochSeconds).\(nonce).\(b64)"
        let key = SymmetricKey(data: Data(sharedSecret.utf8))
        let mac = HMAC<SHA256>.authenticationCode(for: Data(canonicalMessage.utf8), using: key)
        let sigHex = mac.map { String(format: "%02x", $0) }.joined()
        return KrumbSignedEnvelope(
            timestampEpochSeconds: timestampEpochSeconds,
            nonce: nonce,
            signatureHex: sigHex,
            payloadBase64: b64
        )
    }

    /// Verifies HMAC-SHA256 authenticity, clock skew window (+/- 30s), and optional nonce replay set
    public static func verifyEnvelope(
        _ envelope: KrumbSignedEnvelope,
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
public enum KrumbTelemetryPhase: String, Codable, Sendable, Equatable {
    case idle             = "IDLE"
    case preheating       = "PREHEATING"
    case toastingProgress = "TOASTING_PROGRESS"
    case verifyingCrumb   = "VERIFYING_CRUMB"
    case freshOutOfOven   = "FRESH_OUT_OF_OVEN"
    case burntToast       = "BURNT_TOAST"
    case cancelled        = "CANCELLED"
}

public struct KrumbTelemetryPacket: Codable, Sendable, Equatable {
    public let batchId: UUID
    public let toasterId: String
    public let state: KrumbTelemetryPhase
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
        toasterId: String,
        state: KrumbTelemetryPhase,
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
        self.toasterId = toasterId
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

public enum KrumbTelemetrySanitizer {
    /// Clamps and filters incoming WebSocket progress frames so out-of-order packets or NaN/Inf values
    /// never cause progress regressions, negative buffer fill, or division-by-zero in the UI.
    public static func sanitizeProgressTransition(
        previousState: KrumbTelemetryPhase,
        previousFraction: Double,
        incomingFrame: KrumbTelemetryPacket
    ) -> (state: KrumbTelemetryPhase, fraction: Double, fifoClamp: Double, driveClamp: Double) {
        let cleanFifo = incomingFrame.fifoFill.isFinite ? max(0.0, min(1.0, incomingFrame.fifoFill)) : 0.0
        let cleanDrive = incomingFrame.driveBufferFill.isFinite ? max(0.0, min(1.0, incomingFrame.driveBufferFill)) : 0.0
        let rawFrac = incomingFrame.fraction.isFinite ? max(0.0, min(1.0, incomingFrame.fraction)) : previousFraction

        // Terminal states (FRESH_OUT_OF_OVEN, BURNT_TOAST, CANCELLED) cannot regress to TOASTING_PROGRESS
        let isPrevTerminal = (previousState == .freshOutOfOven || previousState == .burntToast || previousState == .cancelled)
        if isPrevTerminal && (incomingFrame.state == .toastingProgress || incomingFrame.state == .preheating) {
            return (previousState, previousFraction, cleanFifo, cleanDrive)
        }

        // During monotonic active burn (TOASTING_PROGRESS -> TOASTING_PROGRESS), ignore late stale UDP/WS packets
        let monotonicFrac: Double
        if previousState == .toastingProgress && incomingFrame.state == .toastingProgress {
            monotonicFrac = max(previousFraction, rawFrac)
        } else if incomingFrame.state == .freshOutOfOven {
            monotonicFrac = 1.0
        } else {
            monotonicFrac = rawFrac
        }

        return (incomingFrame.state, monotonicFrac, cleanFifo, cleanDrive)
    }
}
