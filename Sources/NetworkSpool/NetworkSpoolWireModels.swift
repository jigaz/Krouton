import Combine
import CryptoKit
import Foundation
import Network
import OpticalCore

//
//  KrumbWireProtocol.swift
//  OpticalDough — The Bakery Ecosystem (Krouton Client <-> Krumb Port 7420 Rust Daemon)
//

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
    static let mdnsServiceType = "_krouton-spool._tcp"
    static let mdnsFullDomain  = "_krouton-spool._tcp.local."
    static let defaultPort: UInt16 = 7420
    static let minimumSpoolFreeBytes: UInt64 = 1_073_741_824 // >= 1 GiB free rule
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
    let isSimulatedFallback: Bool

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
    var upcEan: String?

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
    var pregapMs: UInt32

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
    let maxSafeCdHeatX: UInt8
    let maxSafeDvdHeatX: UInt8
    let maxSafeBdHeatX: UInt8
    let canSustain16xDvd: Bool

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
    let spoolJobId: UUID
    let spoolPath: String
    public let freeBytes: UInt64

    enum CodingKeys: String, CodingKey {
        case spoolJobId = "spool_job_id"
        case spoolPath    = "spool_path"
        case freeBytes    = "free_bytes"
    }
}

public struct SpoolBurnRequest: Codable, Sendable {
    public let batchId: UUID
    let spoolJobId: UUID
    let driveIds: [String]
    let heatX: UInt8
    public let mode: SpoolBurnMode
    public let retentionPolicy: SpoolArtifactRetentionPolicy
    let masteringOptions: SpoolMasteringOptions?
    let cubes: [SpoolTrackPayload]
    let krutCoreSpec: KroutonKrutCoreSpec?

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
    let currentCube: UInt8?
    let crispnessPct: Double?
    let butterBufferPct: Double?
    let heatX: Double?
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
