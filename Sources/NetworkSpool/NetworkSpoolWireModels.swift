import OpticalCore
import CryptoKit
//
//  KrumbWireProtocol.swift
//  OpticalDough — The Bakery Ecosystem (Krouton Client <-> Krumb Port 7420 Rust Daemon)
//

import Foundation
import Combine
import Network

// MARK: - 1. Canonical Bakery Typealiases (Old Names -> Real Bakery Structs in OpticalDough.swift)
public typealias DriveManager                = any KroutonDriveTelemetryStore
public typealias OpticalDriveDevice          = KroutonOpticalDriveInfo
public typealias DrivePhaseScopeTelemetry    = KroutonDrivePhaseScopeTelemetry
public typealias NeroTelemetrySample         = KroutonBurnTelemetrySample
public typealias StagedFileEntry             = KroutonStagedFileEntry
public typealias RedBookAudioTrack           = KroutonRedBookTrack
public typealias AudioTransitionStyle        = KroutonTrackPregapStyle
public typealias CDTextSanitizer             = KroutonCDTextSanitizer
public typealias RedBookAuditionEngine       = KroutonAudioPreviewEngine
public typealias BootableImageInspector      = KroutonElToritoBootInspector
public typealias MountedVolumePartition      = KroutonMountedDiscVolume
public typealias BatchDuplicationState       = KroutonBatchBurnState
public typealias BurnCompletionReport        = KroutonBurnSessionReport
public typealias HardwareAccelerationTier    = KroutonHeatTier
public typealias MediaStreamProbeResult      = KroutonStreamProbeResult
public typealias CodecCapabilityRow          = KroutonWorkflowCodecRow
public typealias UniversalMediaDecoderEngine = KroutonMediaPrepEngine
public typealias OpticalDriveTelemetry       = KroutonDrivePhaseScopeTelemetry
public typealias DrivePhaseScopeSample       = KroutonBurnTelemetrySample

// MARK: - 2. Krumb LAN Daemon Constants & `crates/recipe` Wire Structs (Port 7420)
public enum SpoolNetworkConstants {
    public static let mdnsServiceType = "_krouton-spool._tcp"
    public static let mdnsFullDomain  = "_krouton-spool._tcp.local."
    public static let defaultPort: UInt16 = 7420
    public static let minimumSpoolFreeBytes: UInt64 = 1_073_741_824 // >= 1 GiB free rule
}

public enum SpoolRackState: String, Codable, Sendable {
    case closed = "Closed"
    case open   = "Open"
    case locked = "Locked"
}

public enum SpoolDiscMedia: String, Codable, Sendable {
    case empty          = "Empty"
    case blankCdR       = "BlankCdR"
    case blankCdRw      = "BlankCdRw"
    case blankDvdR      = "BlankDvdR"
    case blankBdR       = "BlankBdR"
    case completedDisc = "CompletedDisc"
}

public enum SpoolBurnMode: String, Codable, Sendable {
    case proofOnly = "ProofOnly"
    case burnMedia = "BurnMedia"
}

public enum SpoolArtifactRetentionPolicy: String, Codable, Sendable, CaseIterable, Identifiable {
    case none               = "None"
    case notesOnlyOnFailure = "NotesOnlyOnFailure"
    case fullDiscImage           = "FullDiscImage"
    public var id: String { rawValue }
}

public struct SpoolDiscoveredNode: Identifiable, Hashable, Sendable {
    public let id: String
    public let name: String
    public let hostPort: String
    public let isSimulatedFallback: Bool

    public init(id: String, name: String, hostPort: String, isSimulatedFallback: Bool = false) {
        self.id = id
        self.name = name
        self.hostPort = hostPort
        self.isSimulatedFallback = isSimulatedFallback
    }
}

public struct SpoolRemoteDriveInfo: Codable, Identifiable, Sendable {
    public let id: String
    public let name: String
    public let rackState: SpoolRackState
    public let sliceMedia: SpoolDiscMedia
    public let isSimulatedDrive: Bool

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case rackState  = "rack_state"
        case sliceMedia = "slice_media"
        case isSimulatedDrive = "is_simulated_drive"
    }

    public init(id: String, name: String, rackState: SpoolRackState = .closed, sliceMedia: SpoolDiscMedia = .blankCdR, isSimulatedDrive: Bool = true) {
        self.id = id
        self.name = name
        self.rackState = rackState
        self.sliceMedia = sliceMedia
        self.isSimulatedDrive = isSimulatedDrive
    }
}

public struct SpoolMasteringOptions: Codable, Sendable {
    public var albumTitle: String
    public var performer: String
    public var songwriter: String?
    public var upcEan: String?

    enum CodingKeys: String, CodingKey {
        case albumTitle = "album_title"
        case performer
        case songwriter
        case upcEan     = "upc_ean"
    }

    public init(albumTitle: String, performer: String, songwriter: String? = nil, upcEan: String? = nil) {
        self.albumTitle = albumTitle
        self.performer = performer
        self.songwriter = songwriter
        self.upcEan = upcEan
    }
}

public struct SpoolTrackPayload: Codable, Sendable {
    public var trackNumber: UInt8
    public var filename: String
    public var title: String
    public var performer: String
    public var isrc: String?
    public var pregapMs: UInt32

    enum CodingKeys: String, CodingKey {
        case trackNumber = "track_number"
        case filename
        case title
        case performer
        case isrc
        case pregapMs    = "pregap_ms"
    }

    public init(trackNumber: UInt8, filename: String, title: String, performer: String, isrc: String? = nil, pregapMs: UInt32 = 2000) {
        self.trackNumber = trackNumber
        self.filename = filename
        self.title = title
        self.performer = performer
        self.isrc = isrc
        self.pregapMs = pregapMs
    }
}

public struct SpoolDriveCalibrationResult: Codable, Sendable {
    public let freeBytes: UInt64
    public let maxSafeCdHeatX: UInt8
    public let maxSafeDvdHeatX: UInt8
    public let maxSafeBdHeatX: UInt8
    public let canSustain16xDvd: Bool

    enum CodingKeys: String, CodingKey {
        case freeBytes        = "free_bytes"
        case maxSafeCdHeatX   = "max_safe_cd_heat_x"
        case maxSafeDvdHeatX  = "max_safe_dvd_heat_x"
        case maxSafeBdHeatX   = "max_safe_bd_heat_x"
        case canSustain16xDvd = "can_sustain_16x_dvd"
    }

    public init(freeBytes: UInt64, maxSafeCdHeatX: UInt8, maxSafeDvdHeatX: UInt8, maxSafeBdHeatX: UInt8, canSustain16xDvd: Bool) {
        self.freeBytes = freeBytes
        self.maxSafeCdHeatX = maxSafeCdHeatX
        self.maxSafeDvdHeatX = maxSafeDvdHeatX
        self.maxSafeBdHeatX = maxSafeBdHeatX
        self.canSustain16xDvd = canSustain16xDvd
    }
}

public struct SpoolDriveSlotResponse: Codable, Sendable {
    public let spoolJobId: UUID
    public let spoolPath: String
    public let freeBytes: UInt64

    enum CodingKeys: String, CodingKey {
        case spoolJobId = "spool_job_id"
        case spoolPath    = "spool_path"
        case freeBytes    = "free_bytes"
    }
}

public struct SpoolBurnRequest: Codable, Sendable {
    public let batchId: UUID
    public let spoolJobId: UUID
    public let driveIds: [String]
    public let heatX: UInt8
    public let mode: SpoolBurnMode
    public let retentionPolicy: SpoolArtifactRetentionPolicy
    public let masteringOptions: SpoolMasteringOptions?
    public let cubes: [SpoolTrackPayload]
    public let krutCoreSpec: KroutonKrutCoreSpec?

    enum CodingKeys: String, CodingKey {
        case batchId = "batch_id"
        case spoolJobId = "spool_job_id"
        case driveIds = "drive_ids"
        case heatX = "heat_x"
        case mode
        case retentionPolicy = "retention_policy"
        case masteringOptions
        case cubes
        case krutCoreSpec = "krut_core_spec"
    }

    public init(
        batchId: UUID,
        spoolJobId: UUID,
        driveIds: [String],
        heatX: UInt8,
        mode: SpoolBurnMode,
        retentionPolicy: SpoolArtifactRetentionPolicy,
        masteringOptions: SpoolMasteringOptions?,
        cubes: [SpoolTrackPayload],
        krutCoreSpec: KroutonKrutCoreSpec? = nil
    ) {
        self.batchId = batchId
        self.spoolJobId = spoolJobId
        self.driveIds = driveIds
        self.heatX = heatX
        self.mode = mode
        self.retentionPolicy = retentionPolicy
        self.masteringOptions = masteringOptions
        self.cubes = cubes
        self.krutCoreSpec = krutCoreSpec
    }
}

public struct SpoolNodeEventMessage: Codable, Sendable {
    public let event: String
    public let batchId: UUID?
    public let driveId: String?
    public let currentCube: UInt8?
    public let crispnessPct: Double?
    public let butterBufferPct: Double?
    public let heatX: Double?
    public let reason: String?

    enum CodingKeys: String, CodingKey {
        case event
        case batchId         = "batch_id"
        case driveId       = "drive_id"
        case currentCube     = "current_cube"
        case crispnessPct    = "crispness_pct"
        case butterBufferPct = "butter_buffer_pct"
        case heatX           = "heat_x"
        case reason
    }
}

// MARK: - 3. `SpoolRemoteNodeClient` (mDNS + REST + Spool-and-Burn + WebSocket -> Phase Scope)
public struct SpoolExportedArtifact: Sendable {
    public let defaultFilename: String
    public let contentText: String
    public var data: Data { Data(contentText.utf8) }

    public init(defaultFilename: String, contentText: String) {
        self.defaultFilename = defaultFilename
        self.contentText = contentText
    }
}

@MainActor
public final class SpoolRemoteNodeClient: ObservableObject {
    public static let shared = SpoolRemoteNodeClient()

    @Published public var activeEndpointHost: String = "localhost:7420"
    @Published public var retentionPolicy: SpoolArtifactRetentionPolicy = .notesOnlyOnFailure
    @Published public var discoveredNodes: [SpoolDiscoveredNode] = [
        SpoolDiscoveredNode(id: "localhost", name: "Localhost (Port 7420)", hostPort: "localhost:7420", isSimulatedFallback: false)
    ]
    @Published public var remoteDrives: [SpoolRemoteDriveInfo] = []
    @Published public var lastCalibration: SpoolDriveCalibrationResult? = nil
    @Published public var statusBannerText: String = "Spool Daemon Offline (Port 7420)"
    @Published public var isDaemonReachable: Bool = false
    @Published public var isWebSocketConnected: Bool = false
    @Published public var isSpoolingImage: Bool = false
    @Published public var spoolProgressFraction: Double = 0.0
    @Published public var lastBatchID: UUID = UUID()
    @Published public var recentKitchenEvents: [String] = [
        "[mDNS] Listening for _krouton-spool._tcp.local. on Port 7420",
        "[SpoolCache] 1.0 GiB minimum free space rule armed",
        "[DriveBank] 2500ms staggered spin-up breaker active"
    ]

    var mdnsBrowser: NWBrowser?
    var webSocketTask: URLSessionWebSocketTask?
    let session: URLSession = {
        let cfg = URLSessionConfiguration.ephemeral
        cfg.timeoutIntervalForRequest = 2.0
        cfg.timeoutIntervalForResource = 5.0
        return URLSession(configuration: cfg)
    }()

    public init() {
        startZeroConfDiscovery()
    }

    public func appendEventLog(_ line: String) {
        let stamp = DateFormatter.localizedString(from: Date(), dateStyle: .none, timeStyle: .medium)
        recentKitchenEvents.insert("[\(stamp)] \(line)", at: 0)
        if recentKitchenEvents.count > 40 {
            recentKitchenEvents.removeLast()
        }
    }

    public func startZeroConfDiscovery() {
        mdnsBrowser?.cancel()
        let params = NWParameters()
        params.includePeerToPeer = true
        let browser = NWBrowser(for: .bonjour(type: SpoolNetworkConstants.mdnsServiceType, domain: "local."), using: params)
        browser.browseResultsChangedHandler = { [weak self] results, _ in
            Task { @MainActor in
                guard let self else { return }
                var found: [SpoolDiscoveredNode] = [
                    SpoolDiscoveredNode(id: "localhost", name: "Localhost (Port 7420)", hostPort: "localhost:7420", isSimulatedFallback: false)
                ]
                for res in results {
                    if case let .service(name, _, _, _) = res.endpoint {
                        let safeHost = Self.sanitizeMdnsHostname(name)
                        found.append(SpoolDiscoveredNode(id: name, name: "\(name) (_krouton-spool._tcp)", hostPort: "\(safeHost).local:\(SpoolNetworkConstants.defaultPort)", isSimulatedFallback: false))
                    }
                }
                self.discoveredNodes = found
            }
        }
        browser.start(queue: .main)
        self.mdnsBrowser = browser
    }

    nonisolated public static func sanitizeMdnsHostname(_ rawName: String) -> String {
        let lowered = rawName.lowercased()
        let allowed = lowered.map { ch -> Character in
            if ch.isLetter || ch.isNumber || ch == "-" { return ch }
            return "-"
        }
        let collapsed = String(allowed)
            .replacingOccurrences(of: "--+", with: "-", options: .regularExpression)
            .trimmingCharacters(in: CharacterSet(charactersIn: "-"))
        return collapsed.isEmpty ? "spool-node" : collapsed
    }

    func normalizedHostPort(from hostOrPath: String) -> String {
        let raw = hostOrPath.trimmingCharacters(in: .whitespacesAndNewlines)
        if raw.isEmpty { return activeEndpointHost }
        let stripped = raw
            .replacingOccurrences(of: "spool://", with: "")
            .replacingOccurrences(of: "http://", with: "")
            .replacingOccurrences(of: "https://", with: "")
            .replacingOccurrences(of: "ws://", with: "")
            .split(separator: " ").first.map(String.init) ?? activeEndpointHost
        let hostOnly = stripped.split(separator: "/").first.map(String.init) ?? activeEndpointHost
        return hostOnly.contains(":") ? hostOnly : "\(hostOnly):\(SpoolNetworkConstants.defaultPort)"
    }

    func normalizedBaseURL(from hostOrPath: String) -> URL? {
        URL(string: "http://\(normalizedHostPort(from: hostOrPath))")
    }

    public func refreshRemoteDrives(endpoint: String? = nil) async {
        let target = endpoint ?? activeEndpointHost
        guard let base = normalizedBaseURL(from: target),
              let url = URL(string: "/api/v1/drives", relativeTo: base) else { return }

        do {
            let (data, resp) = try await session.data(from: url)
            if let http = resp as? HTTPURLResponse, (200..<300).contains(http.statusCode),
               let decoded = try? JSONDecoder().decode([SpoolRemoteDriveInfo].self, from: data) {
                self.remoteDrives = decoded
                self.isDaemonReachable = true
                self.statusBannerText = "Spool Daemon Online (\(decoded.count) Drive\(decoded.count == 1 ? "" : "s") on \(normalizedHostPort(from: target)))"
                appendEventLog("GET /api/v1/drives -> \(decoded.count) Optical Drive(s) online")
                connectKitchenWebSocket(endpoint: target)
                return
            }
        } catch {}
        self.remoteDrives = []
        self.isDaemonReachable = false
        self.statusBannerText = "Spool Daemon Unreachable on \(normalizedHostPort(from: target))"
        appendEventLog("GET /api/v1/drives failed on \(normalizedHostPort(from: target)) (Daemon Offline)")
    }

    public func toggleDriveTray(driveID: String, endpoint: String? = nil) async {
        let target = endpoint ?? activeEndpointHost
        if let idx = remoteDrives.firstIndex(where: { $0.id == driveID }) {
            let current = remoteDrives[idx]
            let nextRack: SpoolRackState = (current.rackState == .open) ? .closed : .open
            remoteDrives[idx] = SpoolRemoteDriveInfo(
                id: current.id,
                name: current.name,
                rackState: nextRack,
                sliceMedia: current.sliceMedia,
                isSimulatedDrive: current.isSimulatedDrive
            )
            statusBannerText = "Rack \(nextRack.rawValue.uppercased()): \(current.name)"
            appendEventLog("POST /api/v1/drives/\(driveID)/rack -> \(nextRack.rawValue)")
        }

        guard let base = normalizedBaseURL(from: target),
              let url = URL(string: "/api/v1/drives/\(driveID)/rack", relativeTo: base) else { return }
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let isOpenNow = remoteDrives.first(where: { $0.id == driveID })?.rackState == .open
        req.httpBody = try? JSONEncoder().encode(["open": isOpenNow])
        _ = try? await session.data(for: req)
    }

    public func runSpoolCalibration(endpoint: String? = nil) async {
        let target = endpoint ?? activeEndpointHost
        if let base = normalizedBaseURL(from: target),
           let url = URL(string: "/api/v1/spool/calibrate", relativeTo: base) {
            var req = URLRequest(url: url)
            req.httpMethod = "POST"
            if let (data, resp) = try? await session.data(for: req),
               let http = resp as? HTTPURLResponse, (200..<300).contains(http.statusCode),
               let cal = try? JSONDecoder().decode(SpoolDriveCalibrationResult.self, from: data) {
                self.lastCalibration = cal
                self.isDaemonReachable = true
                let gb = Double(cal.freeBytes) / 1_073_741_824.0
                self.statusBannerText = String(format: "Spool Cache Calibrated: %.1f GB Free • Max Safe Heat %dx CD / %dx DVD", gb, cal.maxSafeCdHeatX, cal.maxSafeDvdHeatX)
                appendEventLog(statusBannerText)
                return
            }
        }
        self.lastCalibration = nil
        self.isDaemonReachable = false
        self.statusBannerText = "Spool Cache Calibration Failed (Daemon Unreachable on \(normalizedHostPort(from: target)))"
        appendEventLog("POST /api/v1/spool/calibrate failed on \(normalizedHostPort(from: target))")
    }

    public func connectKitchenWebSocket(endpoint: String? = nil, driveManager: (any KroutonDriveTelemetryStore)? = nil, targetDriveKey: String = "network-spool-drive") {
        webSocketTask?.cancel(with: .goingAway, reason: nil)
        let hostPort = normalizedHostPort(from: endpoint ?? activeEndpointHost)
        guard let wsURL = URL(string: "ws://\(hostPort)/api/v1/spool/events") else { return }

        let task = session.webSocketTask(with: wsURL)
        self.webSocketTask = task
        task.resume()
        self.isWebSocketConnected = true
        appendEventLog("Connected WS /api/v1/spool/events on \(hostPort)")

        receiveNextWebSocketMessage(task: task, driveManager: driveManager, targetDriveKey: targetDriveKey)
    }

    func receiveNextWebSocketMessage(task: URLSessionWebSocketTask, driveManager: (any KroutonDriveTelemetryStore)?, targetDriveKey: String) {
        task.receive { [weak self] result in
            Task { @MainActor in
                guard let self else { return }
                switch result {
                case .success(let msg):
                    let rawData: Data? = {
                        switch msg {
                        case .string(let s): return s.data(using: .utf8)
                        case .data(let d):   return d
                        @unknown default:    return nil
                        }
                    }()
                    if let data = rawData,
                       let evt = try? JSONDecoder().decode(SpoolNodeEventMessage.self, from: data) {
                        self.applySpoolEventToTelemetry(evt, driveManager: driveManager, targetDriveKey: targetDriveKey)
                    }
                    self.receiveNextWebSocketMessage(task: task, driveManager: driveManager, targetDriveKey: targetDriveKey)
                case .failure:
                    self.isWebSocketConnected = false
                }
            }
        }
    }

    public func applySpoolEventToTelemetry(
        _ evt: SpoolNodeEventMessage,
        driveManager: (any KroutonDriveTelemetryStore)?,
        targetDriveKey: String
    ) {
        if let batchId = evt.batchId {
            self.lastBatchID = batchId
        }
        guard let bank = driveManager else { return }
        var tel = bank.driveTelemetry[targetDriveKey] ?? KroutonDrivePhaseScopeTelemetry(
            id: targetDriveKey,
            driveName: remoteDrives.first?.name ?? "Remote LAN Optical Drive"
        )

        switch evt.event {
        case "PREHEATING":
            tel.isActive = true
            tel.phaseTitle = "Drive Spin-Up Stabilization (2500ms Staggered Spin-Up)"
            statusBannerText = "PREHEATING • Locking Rack & Igniting Laser"
            appendEventLog("WS SPINUP -> Drive \(evt.driveId ?? targetDriveKey)")

        case "BURNING_PROGRESS":
            let frac = min(1.0, max(0.0, (evt.crispnessPct ?? 0.0) / 100.0))
            let heatX = max(0.0, evt.heatX ?? 0.0)
            let bufPct = max(0.0, evt.butterBufferPct ?? 0.0)
            let kbs = heatX * 176.4

            tel.isActive = true
            tel.phaseTitle = String(format: "Writing Track #%d (%.0f%% Complete)", evt.currentCube ?? 1, frac * 100.0)
            tel.progressFraction = frac
            tel.currentSpeedX = heatX
            tel.currentSpeedKBs = kbs
            if heatX > tel.peakSpeedX { tel.peakSpeedX = heatX }
            if heatX > 0 {
                tel.averageSpeedX = (tel.averageSpeedX == 0) ? heatX : ((tel.averageSpeedX * 0.85) + (heatX * 0.15))
            }
            tel.currentSpindleRPM = 0
            tel.bufferFillPercent = bufPct
            tel.currentSectorLBA = Int64(Double(tel.totalSectorsLBA) * frac)
            tel.samples.append(
                KroutonBurnTelemetrySample(
                    progressFraction: frac,
                    speedMultiplierX: heatX,
                    spindleRPM: 0.0,
                    throughputKBs: kbs
                )
            )
            statusBannerText = String(format: "BURNING %.0f%% • %.1fx Speed • Drive FIFO %.0f%%", frac * 100.0, heatX, bufPct)

        case "DING_BATCH_READY":
            tel.isActive = false
            tel.progressFraction = 1.0
            tel.phaseTitle = "Batch Complete (Disc Verified)"
            statusBannerText = "BATCH_COMPLETE • Optical Disc Verified!"
            appendEventLog("WS DING_BATCH_READY -> Batch \(evt.batchId?.uuidString.prefix(8) ?? "OK")")

        case "BURN_FAILED":
            tel.isActive = false
            tel.phaseTitle = "Burn Failed: \(evt.reason ?? "Hardware Error")"
            statusBannerText = "BURN_FAILED • Diagnostic Bundle Preserved"
            appendEventLog("WS BURN_FAILED -> \(evt.reason ?? "Unknown error")")

        default:
            break
        }
        bank.driveTelemetry[targetDriveKey] = tel
    }

}
