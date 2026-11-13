import CryptoKit
//
//  KrumbWireProtocol.swift
//  OpticalDough — The Bakery Ecosystem (Krouton Client <-> Krumb Port 7420 Rust Daemon)
//

import Foundation
import Combine
import Network

// MARK: - 1. Canonical Bakery Typealiases (Old Names -> Real Bakery Structs in OpticalDough.swift)
public typealias DriveManager                = KroutonToasterBank
public typealias OpticalDriveDevice          = KroutonToasterInfo
public typealias DrivePhaseScopeTelemetry    = KroutonKitchenThermometer
public typealias NeroTelemetrySample         = KroutonToastingSample
public typealias StagedFileEntry             = KroutonLoafFileEntry
public typealias RedBookAudioTrack           = KroutonAudioCube
public typealias AudioTransitionStyle        = KroutonCubePregapStyle
public typealias CDTextSanitizer             = KroutonSeasoningSanitizer
public typealias RedBookAuditionEngine       = KroutonCubeTasterEngine
public typealias BootableImageInspector      = KroutonLoafBootInspector
public typealias MountedVolumePartition      = KroutonMountedSlice
public typealias BatchDuplicationState       = KroutonBatchToastState
public typealias BurnCompletionReport        = KroutonToastReport
public typealias HardwareAccelerationTier    = KroutonHeatTier
public typealias MediaStreamProbeResult      = KroutonCubeProbeResult
public typealias CodecCapabilityRow          = KroutonRecipeCodecRow
public typealias UniversalMediaDecoderEngine = KroutonPantryPrepEngine
public typealias OpticalDriveTelemetry       = KroutonKitchenThermometer
public typealias DrivePhaseScopeSample       = KroutonToastingSample

// MARK: - 2. Krumb LAN Daemon Constants & `crates/recipe` Wire Structs (Port 7420)
public enum KrumbNetworkConstants {
    public static let mdnsServiceType = "_krumb._tcp"
    public static let mdnsFullDomain  = "_krumb._tcp.local."
    public static let defaultPort: UInt16 = 7420
    public static let minimumPantryFreeBytes: UInt64 = 1_073_741_824 // >= 1 GiB free rule
}

public enum KrumbRackState: String, Codable, Sendable {
    case closed = "Closed"
    case open   = "Open"
    case locked = "Locked"
}

public enum KrumbSliceMedia: String, Codable, Sendable {
    case empty          = "Empty"
    case blankCdR       = "BlankCdR"
    case blankCdRw      = "BlankCdRw"
    case blankDvdR      = "BlankDvdR"
    case blankBdR       = "BlankBdR"
    case toastedCrouton = "ToastedCrouton"
}

public enum KrumbBakeMode: String, Codable, Sendable {
    case proofOnly = "ProofOnly"
    case toast     = "Toast"
}

public enum KrumbDoggyBagPolicy: String, Codable, Sendable, CaseIterable, Identifiable {
    case none               = "None"
    case notesOnlyOnFailure = "NotesOnlyOnFailure"
    case fullLoaf           = "FullLoaf"
    public var id: String { rawValue }
}

public struct KrumbDiscoveredNode: Identifiable, Hashable, Sendable {
    public let id: String
    public let name: String
    public let hostPort: String
    public let isEasyBakeFallback: Bool

    public init(id: String, name: String, hostPort: String, isEasyBakeFallback: Bool = false) {
        self.id = id
        self.name = name
        self.hostPort = hostPort
        self.isEasyBakeFallback = isEasyBakeFallback
    }
}

public struct KrumbRemoteToasterInfo: Codable, Identifiable, Sendable {
    public let id: String
    public let name: String
    public let rackState: KrumbRackState
    public let sliceMedia: KrumbSliceMedia
    public let isEasyBake: Bool

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case rackState  = "rack_state"
        case sliceMedia = "slice_media"
        case isEasyBake = "is_easy_bake"
    }

    public init(id: String, name: String, rackState: KrumbRackState = .closed, sliceMedia: KrumbSliceMedia = .blankCdR, isEasyBake: Bool = true) {
        self.id = id
        self.name = name
        self.rackState = rackState
        self.sliceMedia = sliceMedia
        self.isEasyBake = isEasyBake
    }
}

public struct KrumbSeasoning: Codable, Sendable {
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

public struct KrumbCubePayload: Codable, Sendable {
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

public struct KrumbPantryCalibrationResult: Codable, Sendable {
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

public struct KrumbPantrySlotResponse: Codable, Sendable {
    public let pantryLoafId: UUID
    public let spoolPath: String
    public let freeBytes: UInt64

    enum CodingKeys: String, CodingKey {
        case pantryLoafId = "pantry_loaf_id"
        case spoolPath    = "spool_path"
        case freeBytes    = "free_bytes"
    }
}

public struct KrumbBakeRequest: Codable, Sendable {
    public let batchId: UUID
    public let pantryLoafId: UUID
    public let toasterIds: [String]
    public let heatX: UInt8
    public let mode: KrumbBakeMode
    public let doggyBag: KrumbDoggyBagPolicy
    public let seasoning: KrumbSeasoning?
    public let cubes: [KrumbCubePayload]
    public let krutCoreSpec: KroutonKrutCoreSpec?

    enum CodingKeys: String, CodingKey {
        case batchId = "batch_id"
        case pantryLoafId = "pantry_loaf_id"
        case toasterIds = "toaster_ids"
        case heatX = "heat_x"
        case mode
        case doggyBag = "doggy_bag"
        case seasoning
        case cubes
        case krutCoreSpec = "krut_core_spec"
    }

    public init(
        batchId: UUID,
        pantryLoafId: UUID,
        toasterIds: [String],
        heatX: UInt8,
        mode: KrumbBakeMode,
        doggyBag: KrumbDoggyBagPolicy,
        seasoning: KrumbSeasoning?,
        cubes: [KrumbCubePayload],
        krutCoreSpec: KroutonKrutCoreSpec? = nil
    ) {
        self.batchId = batchId
        self.pantryLoafId = pantryLoafId
        self.toasterIds = toasterIds
        self.heatX = heatX
        self.mode = mode
        self.doggyBag = doggyBag
        self.seasoning = seasoning
        self.cubes = cubes
        self.krutCoreSpec = krutCoreSpec
    }
}

public struct KrumbKitchenEventMessage: Codable, Sendable {
    public let event: String
    public let batchId: UUID?
    public let toasterId: String?
    public let currentCube: UInt8?
    public let crispnessPct: Double?
    public let butterBufferPct: Double?
    public let heatX: Double?
    public let reason: String?

    enum CodingKeys: String, CodingKey {
        case event
        case batchId         = "batch_id"
        case toasterId       = "toaster_id"
        case currentCube     = "current_cube"
        case crispnessPct    = "crispness_pct"
        case butterBufferPct = "butter_buffer_pct"
        case heatX           = "heat_x"
        case reason
    }
}

// MARK: - 3. `KrumbKitchenClient` (mDNS + REST + Spool-and-Burn + WebSocket -> Phase Scope)
public struct KrumbExportedArtifact: Sendable {
    public let defaultFilename: String
    public let contentText: String
    public var data: Data { Data(contentText.utf8) }

    public init(defaultFilename: String, contentText: String) {
        self.defaultFilename = defaultFilename
        self.contentText = contentText
    }
}

@MainActor
public final class KrumbKitchenClient: ObservableObject {
    public static let shared = KrumbKitchenClient()

    @Published public var activeEndpointHost: String = "localhost:7420"
    @Published public var doggyBagPolicy: KrumbDoggyBagPolicy = .notesOnlyOnFailure
    @Published public var discoveredNodes: [KrumbDiscoveredNode] = [
        KrumbDiscoveredNode(id: "local-easybake", name: "Local Burn Server", hostPort: "localhost:7420", isEasyBakeFallback: true),
        KrumbDiscoveredNode(id: "lan-pi3b", name: "LAN Optical Server (pi3b)", hostPort: "krumb-pi3b.local:7420", isEasyBakeFallback: true)
    ]
    @Published public var remoteToasters: [KrumbRemoteToasterInfo] = [
        KrumbRemoteToasterInfo(id: "usb-pioneer-slot-0", name: "Remote Drive #1 (PIONEER BD-RW)", rackState: .closed, sliceMedia: .blankCdR, isEasyBake: true),
        KrumbRemoteToasterInfo(id: "usb-plextor-slot-1", name: "Remote Drive #2 (PLEXTOR PX-716A)", rackState: .closed, sliceMedia: .blankDvdR, isEasyBake: true)
    ]
    @Published public var lastCalibration: KrumbPantryCalibrationResult? = KrumbPantryCalibrationResult(
        freeBytes: 48_318_382_080,
        maxSafeCdHeatX: 24,
        maxSafeDvdHeatX: 16,
        maxSafeBdHeatX: 6,
        canSustain16xDvd: true
    )
    @Published public var statusBannerText: String = "Burn Server Online • 2 Remote Drives Ready"
    @Published public var isDaemonReachable: Bool = false
    @Published public var isWebSocketConnected: Bool = false
    @Published public var isSpoolingLoaf: Bool = false
    @Published public var spoolProgressFraction: Double = 0.0
    @Published public var lastBatchID: UUID = UUID()
    @Published public var recentKitchenEvents: [String] = [
        "[mDNS] Listening for _krumb._tcp.local. on Port 7420",
        "[Pantry] 1.0 GiB minimum free space rule armed",
        "[ToasterBank] 2500ms staggered spin-up breaker active"
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
        let browser = NWBrowser(for: .bonjour(type: KrumbNetworkConstants.mdnsServiceType, domain: "local."), using: params)
        browser.browseResultsChangedHandler = { [weak self] results, _ in
            Task { @MainActor in
                guard let self else { return }
                var found: [KrumbDiscoveredNode] = [
                    KrumbDiscoveredNode(id: "local-easybake", name: "Local Burn Server", hostPort: "localhost:7420", isEasyBakeFallback: true)
                ]
                for res in results {
                    if case let .service(name, _, _, _) = res.endpoint {
                        let safeHost = Self.sanitizeMdnsHostname(name)
                        found.append(KrumbDiscoveredNode(id: name, name: "\(name) (_krumb._tcp)", hostPort: "\(safeHost).local:\(KrumbNetworkConstants.defaultPort)", isEasyBakeFallback: false))
                    }
                }
                if found.count == 1 {
                    found.append(KrumbDiscoveredNode(id: "lan-pi3b", name: "LAN Optical Server (Standby)", hostPort: "krumb-pi3b.local:7420", isEasyBakeFallback: true))
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
        return collapsed.isEmpty ? "krumb-node" : collapsed
    }

    func normalizedHostPort(from hostOrPath: String) -> String {
        let raw = hostOrPath.trimmingCharacters(in: .whitespacesAndNewlines)
        if raw.isEmpty { return activeEndpointHost }
        let stripped = raw
            .replacingOccurrences(of: "krumb://", with: "")
            .replacingOccurrences(of: "http://", with: "")
            .replacingOccurrences(of: "https://", with: "")
            .replacingOccurrences(of: "ws://", with: "")
            .split(separator: " ").first.map(String.init) ?? activeEndpointHost
        let hostOnly = stripped.split(separator: "/").first.map(String.init) ?? activeEndpointHost
        return hostOnly.contains(":") ? hostOnly : "\(hostOnly):\(KrumbNetworkConstants.defaultPort)"
    }

    func normalizedBaseURL(from hostOrPath: String) -> URL? {
        URL(string: "http://\(normalizedHostPort(from: hostOrPath))")
    }

    public func refreshToasters(endpoint: String? = nil) async {
        let target = endpoint ?? activeEndpointHost
        guard let base = normalizedBaseURL(from: target),
              let url = URL(string: "/api/v1/toasters", relativeTo: base) else { return }

        do {
            let (data, resp) = try await session.data(from: url)
            if let http = resp as? HTTPURLResponse, (200..<300).contains(http.statusCode),
               let decoded = try? JSONDecoder().decode([KrumbRemoteToasterInfo].self, from: data) {
                self.remoteToasters = decoded
                self.isDaemonReachable = true
                self.statusBannerText = "Krumb Online (\(decoded.count) Toaster\(decoded.count == 1 ? "" : "s") on \(normalizedHostPort(from: target)))"
                appendEventLog("GET /api/v1/toasters -> \(decoded.count) Toaster(s) online")
                connectKitchenWebSocket(endpoint: target)
                return
            }
        } catch {}
        self.isDaemonReachable = false
        self.statusBannerText = "EasyBake Standby • \(remoteToasters.count) Virtual Toasters (Port 7420)"
        appendEventLog("Probe \(normalizedHostPort(from: target)) -> Using 2-Slot EasyBake virtual ToasterBank")
    }

    public func toggleToasterRack(toasterID: String, endpoint: String? = nil) async {
        let target = endpoint ?? activeEndpointHost
        if let idx = remoteToasters.firstIndex(where: { $0.id == toasterID }) {
            let current = remoteToasters[idx]
            let nextRack: KrumbRackState = (current.rackState == .open) ? .closed : .open
            remoteToasters[idx] = KrumbRemoteToasterInfo(
                id: current.id,
                name: current.name,
                rackState: nextRack,
                sliceMedia: current.sliceMedia,
                isEasyBake: current.isEasyBake
            )
            statusBannerText = "Rack \(nextRack.rawValue.uppercased()): \(current.name)"
            appendEventLog("POST /api/v1/toasters/\(toasterID)/rack -> \(nextRack.rawValue)")
        }

        guard let base = normalizedBaseURL(from: target),
              let url = URL(string: "/api/v1/toasters/\(toasterID)/rack", relativeTo: base) else { return }
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let isOpenNow = remoteToasters.first(where: { $0.id == toasterID })?.rackState == .open
        req.httpBody = try? JSONEncoder().encode(["open": isOpenNow])
        _ = try? await session.data(for: req)
    }

    public func runPantryCalibration(endpoint: String? = nil) async {
        let target = endpoint ?? activeEndpointHost
        if let base = normalizedBaseURL(from: target),
           let url = URL(string: "/api/v1/pantry/calibrate", relativeTo: base) {
            var req = URLRequest(url: url)
            req.httpMethod = "POST"
            if let (data, resp) = try? await session.data(for: req),
               let http = resp as? HTTPURLResponse, (200..<300).contains(http.statusCode),
               let cal = try? JSONDecoder().decode(KrumbPantryCalibrationResult.self, from: data) {
                self.lastCalibration = cal
                self.isDaemonReachable = true
                let gb = Double(cal.freeBytes) / 1_073_741_824.0
                self.statusBannerText = String(format: "Pantry Calibrated: %.1f GB Free • Max Safe Heat %dx CD / %dx DVD", gb, cal.maxSafeCdHeatX, cal.maxSafeDvdHeatX)
                appendEventLog(statusBannerText)
                return
            }
        }
        let simulated = KrumbPantryCalibrationResult(
            freeBytes: 48_318_382_080,
            maxSafeCdHeatX: 24,
            maxSafeDvdHeatX: 16,
            maxSafeBdHeatX: 6,
            canSustain16xDvd: true
        )
        self.lastCalibration = simulated
        let gb = Double(simulated.freeBytes) / 1_073_741_824.0
        self.statusBannerText = String(format: "Remote Pantry Unverified (Daemon Offline — Local Hardware Only)", gb, simulated.maxSafeCdHeatX, simulated.maxSafeDvdHeatX)
        appendEventLog("POST /api/v1/pantry/calibrate -> \(statusBannerText)")
    }

    public func connectKitchenWebSocket(endpoint: String? = nil, driveManager: KroutonToasterBank? = nil, targetDriveKey: String = "krumb-network-toaster") {
        webSocketTask?.cancel(with: .goingAway, reason: nil)
        let hostPort = normalizedHostPort(from: endpoint ?? activeEndpointHost)
        guard let wsURL = URL(string: "ws://\(hostPort)/api/v1/kitchen") else { return }

        let task = session.webSocketTask(with: wsURL)
        self.webSocketTask = task
        task.resume()
        self.isWebSocketConnected = true
        appendEventLog("Connected WS /api/v1/kitchen on \(hostPort)")

        receiveNextWebSocketMessage(task: task, driveManager: driveManager, targetDriveKey: targetDriveKey)
    }

    func receiveNextWebSocketMessage(task: URLSessionWebSocketTask, driveManager: KroutonToasterBank?, targetDriveKey: String) {
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
                       let evt = try? JSONDecoder().decode(KrumbKitchenEventMessage.self, from: data) {
                        self.applyKitchenEventToThermometer(evt, driveManager: driveManager, targetDriveKey: targetDriveKey)
                    }
                    self.receiveNextWebSocketMessage(task: task, driveManager: driveManager, targetDriveKey: targetDriveKey)
                case .failure:
                    self.isWebSocketConnected = false
                }
            }
        }
    }

    public func applyKitchenEventToThermometer(
        _ evt: KrumbKitchenEventMessage,
        driveManager: KroutonToasterBank?,
        targetDriveKey: String
    ) {
        if let batchId = evt.batchId {
            self.lastBatchID = batchId
        }
        guard let bank = driveManager else { return }
        var tel = bank.driveTelemetry[targetDriveKey] ?? KroutonKitchenThermometer(
            id: targetDriveKey,
            driveName: remoteToasters.first?.name ?? "Krumb LAN Toaster"
        )

        switch evt.event {
        case "PREHEATING":
            tel.isActive = true
            tel.phaseTitle = "Krumb Preheating (2500ms Staggered Spin-Up)"
            statusBannerText = "PREHEATING • Locking Rack & Igniting Laser"
            appendEventLog("WS PREHEATING -> Toaster \(evt.toasterId ?? targetDriveKey)")

        case "TOASTING_PROGRESS":
            let frac = min(1.0, max(0.0, (evt.crispnessPct ?? 0.0) / 100.0))
            let heatX = evt.heatX ?? (4.2 + 11.8 * pow(frac, 0.78))
            let bufPct = evt.butterBufferPct ?? 96.0
            let rpm = 1850.0 + (heatX * 195.0)
            let kbs = heatX * 176.4

            tel.isActive = true
            tel.phaseTitle = String(format: "Toasting Cube #%d (%.0f%% Crispness)", evt.currentCube ?? 1, frac * 100.0)
            tel.progressFraction = frac
            tel.currentSpeedX = heatX
            tel.currentSpeedKBs = kbs
            tel.peakSpeedX = max(tel.peakSpeedX, heatX)
            tel.averageSpeedX = (tel.averageSpeedX == 0) ? heatX : ((tel.averageSpeedX * 0.85) + (heatX * 0.15))
            tel.currentSpindleRPM = Int(rpm)
            tel.bufferFillPercent = bufPct
            tel.currentSectorLBA = Int64(Double(tel.totalSectorsLBA) * frac)
            tel.samples.append(
                KroutonToastingSample(
                    progressFraction: frac,
                    speedMultiplierX: heatX,
                    spindleRPM: rpm,
                    throughputKBs: kbs
                )
            )
            statusBannerText = String(format: "TOASTING %.0f%% • %.1fx Heat • Butter Buffer %.0f%%", frac * 100.0, heatX, bufPct)

        case "DING_BATCH_READY":
            tel.isActive = false
            tel.progressFraction = 1.0
            tel.phaseTitle = "Ding! Batch Ready (Toasted Crouton)"
            statusBannerText = "DING_BATCH_READY • Fresh Crouton Toasted!"
            appendEventLog("WS DING_BATCH_READY -> Batch \(evt.batchId?.uuidString.prefix(8) ?? "OK")")

        case "BURNT_TOAST":
            tel.isActive = false
            tel.phaseTitle = "Burnt Toast: \(evt.reason ?? "Hardware Error")"
            statusBannerText = "BURNT_TOAST • DoggyBag Preserved"
            appendEventLog("WS BURNT_TOAST -> \(evt.reason ?? "Unknown error")")

        default:
            break
        }
        bank.driveTelemetry[targetDriveKey] = tel
    }

}
