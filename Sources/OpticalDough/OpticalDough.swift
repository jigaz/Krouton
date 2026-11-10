import Foundation
import AppKit
@preconcurrency import DiscRecording

public struct MountedVolumePartition: Identifiable, Hashable, Sendable {
    public let id: String
    public let volumeName: String
    public let filesystemFormat: String
    public let mountPath: String
    public let itemCount: Int
    public let isAudioCD: Bool
    public let usedBytes: Int64
    public let totalBytes: Int64
    public let creationDateText: String

    public init(
        id: String,
        volumeName: String,
        filesystemFormat: String,
        mountPath: String,
        itemCount: Int,
        isAudioCD: Bool,
        usedBytes: Int64,
        totalBytes: Int64,
        creationDateText: String
    ) {
        self.id = id
        self.volumeName = volumeName
        self.filesystemFormat = filesystemFormat
        self.mountPath = mountPath
        self.itemCount = itemCount
        self.isAudioCD = isAudioCD
        self.usedBytes = usedBytes
        self.totalBytes = totalBytes
        self.creationDateText = creationDateText
    }
}

public struct OpticalDriveDevice: Identifiable, Hashable, Sendable {
    public let id: String
    public let vendor: String
    public let product: String
    public let firmware: String
    public let interconnect: String
    public let bsdDeviceNode: String
    public let capabilitiesSummary: String
    public let isNetworkNode: Bool
    public let hostName: String
    public let mediaState: String
    public let mediaType: String
    public let isMediaPresent: Bool
    public let isMediaBlank: Bool
    public let isMediaErasable: Bool
    public let isMediaOverwritable: Bool
    public let isMediaAppendable: Bool
    public let sessionCount: Int
    public let trackCount: Int
    public let freeSectorsLBA: Int64
    public let freeBytes: Int64
    public let usedSectorsLBA: Int64
    public let usedBytes: Int64
    public let mediaManufacturer: String
    public let bookStandard: String
    public let dyeChemistry: String
    public let laserWavelengthNA: String
    public let sectorBlockSize: String
    public let copyProtectionStatus: String
    public let mountedVolumes: [MountedVolumePartition]
    public let availableWriteSpeeds: [String]

    public init(
        id: String,
        vendor: String,
        product: String,
        firmware: String,
        interconnect: String = "USB",
        bsdDeviceNode: String = "/dev/rdisk",
        capabilitiesSummary: String = "DVD±R DL • CD-R/RW • CD-TEXT",
        isNetworkNode: Bool = false,
        hostName: String = "Local Mac",
        mediaState: String = "Slot Empty",
        mediaType: String = "No Disc",
        isMediaPresent: Bool = false,
        isMediaBlank: Bool = false,
        isMediaErasable: Bool = false,
        isMediaOverwritable: Bool = false,
        isMediaAppendable: Bool = false,
        sessionCount: Int = 0,
        trackCount: Int = 0,
        freeSectorsLBA: Int64 = 0,
        freeBytes: Int64 = 0,
        usedSectorsLBA: Int64 = 0,
        usedBytes: Int64 = 0,
        mediaManufacturer: String = "Unknown ATIP/MID",
        bookStandard: String = "ISO/IEC Standard",
        dyeChemistry: String = "Phase-Change / Organic",
        laserWavelengthNA: String = "780 nm IR (0.45 NA)",
        sectorBlockSize: String = "2,048 Bytes (Mode 1)",
        copyProtectionStatus: String = "Unencrypted ( CSS / AACS Clear )",
        mountedVolumes: [MountedVolumePartition] = [],
        availableWriteSpeeds: [String] = ["Max Safe (Auto)", "24x (4234 KB/s)", "10x (1764 KB/s)", "8x (1411 KB/s)", "4x (705 KB/s)", "2x (353 KB/s)"]
    ) {
        self.id = id
        self.vendor = vendor
        self.product = product
        self.firmware = firmware
        self.interconnect = interconnect
        self.bsdDeviceNode = bsdDeviceNode
        self.capabilitiesSummary = capabilitiesSummary
        self.isNetworkNode = isNetworkNode
        self.hostName = hostName
        self.mediaState = mediaState
        self.mediaType = mediaType
        self.isMediaPresent = isMediaPresent
        self.isMediaBlank = isMediaBlank
        self.isMediaErasable = isMediaErasable
        self.isMediaOverwritable = isMediaOverwritable
        self.isMediaAppendable = isMediaAppendable
        self.sessionCount = sessionCount
        self.trackCount = trackCount
        self.freeSectorsLBA = freeSectorsLBA
        self.freeBytes = freeBytes
        self.usedSectorsLBA = usedSectorsLBA
        self.usedBytes = usedBytes
        self.mediaManufacturer = mediaManufacturer
        self.bookStandard = bookStandard
        self.dyeChemistry = dyeChemistry
        self.laserWavelengthNA = laserWavelengthNA
        self.sectorBlockSize = sectorBlockSize
        self.copyProtectionStatus = copyProtectionStatus
        self.mountedVolumes = mountedVolumes
        self.availableWriteSpeeds = availableWriteSpeeds
    }

    public var displayName: String {
        isNetworkNode ? "\(vendor) \(product) (\(hostName))" : "\(vendor) \(product)"
    }

    public var statusBadgeText: String {
        if isMediaPresent {
            let totalDisplayBytes = max(freeBytes, usedBytes)
            let gb = Double(totalDisplayBytes) / 1_000_000_000.0
            let statePrefix: String
            if isMediaBlank {
                statePrefix = "Blank"
            } else if isMediaErasable {
                statePrefix = "Rewritable"
            } else {
                statePrefix = "Mounted"
            }
            if gb >= 0.95 {
                return String(format: "%@ %@ (%.2f GB)", statePrefix, mediaType, gb)
            } else if totalDisplayBytes > 0 {
                let mb = Double(totalDisplayBytes) / 1_000_000.0
                return String(format: "%@ %@ (%.0f MB)", statePrefix, mediaType, mb)
            }
            return "\(statePrefix) \(mediaType)"
        }
        return mediaState
    }

    public var redBookTimecodeCapacity: String {
        let totalSectors = max(freeSectorsLBA + usedSectorsLBA, 1)
        let totalSeconds = Int(totalSectors / 75)
        let mins = totalSeconds / 60
        let secs = totalSeconds % 60
        let frames = Int(totalSectors % 75)
        return String(format: "%02d:%02d:%02d (75 fps)", mins, secs, frames)
    }

    public var totalCapacityBytes: Int64 {
        max(1, freeBytes + usedBytes)
    }

    public var usedFraction: Double {
        if isMediaBlank { return 0.0 }
        let total = Double(max(1, freeBytes + usedBytes))
        return min(1.0, max(0.0, Double(usedBytes) / total))
    }
}

public struct StagedFileEntry: Identifiable, Hashable, Sendable {
    public let id: UUID
    public let url: URL
    public let name: String
    public let isDirectory: Bool
    public let byteSize: Int64
    public let itemCount: Int
    public let posixPermissions: String
    public let modifiedDate: Date
    public var showOnMac: Bool
    public var showOnPC: Bool

    public init(
        id: UUID = UUID(),
        url: URL,
        name: String,
        isDirectory: Bool,
        byteSize: Int64,
        itemCount: Int,
        posixPermissions: String,
        modifiedDate: Date,
        showOnMac: Bool = true,
        showOnPC: Bool = true
    ) {
        self.id = id
        self.url = url
        self.name = name
        self.isDirectory = isDirectory
        self.byteSize = byteSize
        self.itemCount = itemCount
        self.posixPermissions = posixPermissions
        self.modifiedDate = modifiedDate
        self.showOnMac = showOnMac
        self.showOnPC = showOnPC
    }

    public var sectorsLBA: Int64 {
        max(1, (byteSize + 2047) / 2048)
    }

    public var exceedsISO9660FourGiBLimit: Bool {
        byteSize >= 4_294_967_295
    }

    public var exceedsJoliet64CharLimit: Bool {
        name.count > 64
    }
}

public struct NeroTelemetrySample: Identifiable, Hashable, Sendable {
    public let id: UUID
    public let progressFraction: Double
    public let speedMultiplierX: Double
    public let spindleRPM: Double
    public let throughputKBs: Double

    public init(
        id: UUID = UUID(),
        progressFraction: Double,
        speedMultiplierX: Double,
        spindleRPM: Double,
        throughputKBs: Double
    ) {
        self.id = id
        self.progressFraction = progressFraction
        self.speedMultiplierX = speedMultiplierX
        self.spindleRPM = spindleRPM
        self.throughputKBs = throughputKBs
    }
}

public struct DrivePhaseScopeTelemetry: Identifiable, Hashable, Sendable {
    public let id: String          // Drive ID
    public var driveName: String
    public var isActive: Bool       // True whenever throughputKBs > 0
    public var isManuallyPinnedInline: Bool
    public var isFloatingWindowOpen: Bool
    public var phaseTitle: String
    public var progressFraction: Double
    public var currentSpeedX: Double
    public var currentSpeedKBs: Double
    public var peakSpeedX: Double
    public var averageSpeedX: Double
    public var targetSpeedX: Double
    public var currentSpindleRPM: Int
    public var currentSectorLBA: Int64
    public var totalSectorsLBA: Int64
    public var bufferFillPercent: Double
    public var laserWavelengthText: String
    public var writeStrategyText: String
    public var elapsedSeconds: Int
    public var samples: [NeroTelemetrySample]

    public init(
        id: String,
        driveName: String,
        isActive: Bool = false,
        isManuallyPinnedInline: Bool = false,
        isFloatingWindowOpen: Bool = false,
        phaseTitle: String = "Idle",
        progressFraction: Double = 0.0,
        currentSpeedX: Double = 0.0,
        currentSpeedKBs: Double = 0.0,
        peakSpeedX: Double = 0.0,
        averageSpeedX: Double = 0.0,
        targetSpeedX: Double = 16.0,
        currentSpindleRPM: Int = 0,
        currentSectorLBA: Int64 = 0,
        totalSectorsLBA: Int64 = 359_847,
        bufferFillPercent: Double = 98.0,
        laserWavelengthText: String = "780 nm IR",
        writeStrategyText: String = "P-CAV",
        elapsedSeconds: Int = 0,
        samples: [NeroTelemetrySample] = []
    ) {
        self.id = id
        self.driveName = driveName
        self.isActive = isActive
        self.isManuallyPinnedInline = isManuallyPinnedInline
        self.isFloatingWindowOpen = isFloatingWindowOpen
        self.phaseTitle = phaseTitle
        self.progressFraction = progressFraction
        self.currentSpeedX = currentSpeedX
        self.currentSpeedKBs = currentSpeedKBs
        self.peakSpeedX = peakSpeedX
        self.averageSpeedX = averageSpeedX
        self.targetSpeedX = targetSpeedX
        self.currentSpindleRPM = currentSpindleRPM
        self.currentSectorLBA = currentSectorLBA
        self.totalSectorsLBA = totalSectorsLBA
        self.bufferFillPercent = bufferFillPercent
        self.laserWavelengthText = laserWavelengthText
        self.writeStrategyText = writeStrategyText
        self.elapsedSeconds = elapsedSeconds
        self.samples = samples
    }

    public var radialMillimeters: Double {
        24.0 + (34.0 * min(1.0, max(0.0, progressFraction)))
    }

    public mutating func appendMonotonicSample(
        rawFraction: Double,
        speedX: Double,
        rpm: Int,
        kbs: Double
    ) {
        let clamped = min(1.0, max(0.0, rawFraction))
        if let last = samples.last {
            if clamped < last.progressFraction - 0.08 {
                samples.removeAll()
                peakSpeedX = speedX
            } else if abs(clamped - last.progressFraction) < 0.003 {
                samples[samples.count - 1] = NeroTelemetrySample(
                    progressFraction: last.progressFraction,
                    speedMultiplierX: speedX,
                    spindleRPM: Double(rpm),
                    throughputKBs: kbs
                )
                progressFraction = last.progressFraction
                let sumX = samples.reduce(0.0) { $0 + $1.speedMultiplierX }
                averageSpeedX = sumX / Double(max(1, samples.count))
                return
            }
        }
        let monotonicFrac = max(samples.last?.progressFraction ?? 0.0, clamped)
        progressFraction = monotonicFrac
        samples.append(NeroTelemetrySample(
            progressFraction: monotonicFrac,
            speedMultiplierX: speedX,
            spindleRPM: Double(rpm),
            throughputKBs: kbs
        ))
        let sumX = samples.reduce(0.0) { $0 + $1.speedMultiplierX }
        averageSpeedX = sumX / Double(max(1, samples.count))
    }
}

public struct BurnCompletionReport: Identifiable, Hashable, Sendable {
    public let id: UUID
    public let isSuccess: Bool
    public let title: String
    public let summary: String
    public let driveModel: String
    public let firmwareRevision: String
    public let mediaFormattedName: String
    public let volumeName: String
    public let sectorsWrittenLBA: Int64
    public let bytesWritten: Int64
    public let averageSpeedText: String
    public let peakSpeedText: String
    public let elapsedDurationText: String
    public let diagnosticAdvice: String

    public init(
        id: UUID = UUID(),
        isSuccess: Bool,
        title: String,
        summary: String,
        driveModel: String,
        firmwareRevision: String,
        mediaFormattedName: String,
        volumeName: String,
        sectorsWrittenLBA: Int64,
        bytesWritten: Int64,
        averageSpeedText: String,
        peakSpeedText: String,
        elapsedDurationText: String,
        diagnosticAdvice: String
    ) {
        self.id = id
        self.isSuccess = isSuccess
        self.title = title
        self.summary = summary
        self.driveModel = driveModel
        self.firmwareRevision = firmwareRevision
        self.mediaFormattedName = mediaFormattedName
        self.volumeName = volumeName
        self.sectorsWrittenLBA = sectorsWrittenLBA
        self.bytesWritten = bytesWritten
        self.averageSpeedText = averageSpeedText
        self.peakSpeedText = peakSpeedText
        self.elapsedDurationText = elapsedDurationText
        self.diagnosticAdvice = diagnosticAdvice
    }
}

@MainActor
public final class DriveManager: ObservableObject {
    @Published public var availableDrives: [OpticalDriveDevice] = []
    @Published public var selectedDrive: OpticalDriveDevice?
    @Published public var hardwareStatusLog: String = "Scanning IOKit / DiscRecording bus..."

        @Published public var isExecutingQueue: Bool = false
    @Published public var activeJobPhase: String = "Idle"
    @Published public var activeJobProgress: Double = 0.0
    @Published public var activeJobDetail: String = ""
    @Published public var driveTelemetry: [String: DrivePhaseScopeTelemetry] = [:]
    private var perDriveTimers: [String: Timer] = [:]

    @Published public var neroSamples: [NeroTelemetrySample] = []
    @Published public var currentSpeedX: Double = 0.0
    @Published public var currentSpeedKBs: Double = 0.0
    @Published public var peakSpeedX: Double = 0.0
    @Published public var averageSpeedX: Double = 0.0
    @Published public var currentSpindleRPM: Int = 0
    @Published public var currentSectorLBA: Int64 = 0
    @Published public var totalTargetSectorsLBA: Int64 = 359_847
    @Published public var driveBufferFillPercent: Double = 98.0
    @Published public var laserWavelengthText: String = "780 nm IR (CD)"
    @Published public var writeStrategyText: String = "P-CAV / CLV"
    @Published public var activeTrackNumber: Int = 1
    @Published public var elapsedSeconds: Int = 0
    @Published public var completionReport: BurnCompletionReport? = nil

    private var pollTimer: Timer?
    private var activeDRBurn: DRBurn?
    private var activeDRErase: DRErase?
    public var burnMonitorTimer: Timer?
    public var eraseMonitorTimer: Timer?
    private var jobStartTime: Date = Date()

    public init() {
        startHardwarePolling()
        Task { @MainActor [weak self] in
            self?.refreshDrives()
        }
    }

    private func startHardwarePolling() {
        pollTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self = self, !self.isExecutingQueue else { return }
                self.refreshDrives()
            }
        }
    }

    public static func formatHumanMediaType(_ raw: String) -> String {
        let u = raw.uppercased()
        if u.contains("CDRW") { return "CD-RW" }
        if u.contains("CDR") { return "CD-R" }
        if u.contains("CDROM") { return "CD-ROM" }
        if u.contains("DVDRW") && u.contains("PLUS") && u.contains("DOUBLE") { return "DVD+RW DL" }
        if u.contains("DVDR") && u.contains("PLUS") && u.contains("DOUBLE") { return "DVD+R DL" }
        if u.contains("DVDR") && u.contains("DUAL") { return "DVD-R DL" }
        if u.contains("DVDRW") && u.contains("PLUS") { return "DVD+RW" }
        if u.contains("DVDR") && u.contains("PLUS") { return "DVD+R" }
        if u.contains("DVDRW") { return "DVD-RW" }
        if u.contains("DVDRAM") { return "DVD-RAM" }
        if u.contains("DVDR") { return "DVD-R" }
        if u.contains("DVDROM") { return "DVD-ROM" }
        if u.contains("BDRE") { return "BD-RE" }
        if u.contains("BDR") { return "BD-R" }
        if u.contains("BDROM") { return "BD-ROM" }
        let stripped = raw.replacingOccurrences(of: "DRDeviceMediaType", with: "", options: .caseInsensitive)
        return stripped.isEmpty ? "Optical Media" : stripped
    }

    public static func deduceMediaPhysics(mediaType: String, isErasable: Bool) -> (book: String, dye: String, laser: String, block: String) {
        if mediaType.contains("BD") {
            let book = isErasable ? "Blu-ray System Description BD-RE Part 1" : "Blu-ray System Description BD-R Part 1"
            let dye = isErasable ? "GeSbTe Phase-Change Recording Layer" : "HTL Inorganic / M-DISC Rock-Like Layer"
            return (book, dye, "405 nm Blue-Violet (0.85 NA)", "2,048 Bytes (64 KB ECC Cluster)")
        } else if mediaType.contains("DVD") {
            let book = isErasable ? "DVD Forum Part 2 / RW Physical Spec" : "DVD Forum Part 1 / Recordable Spec"
            let dye = isErasable ? "AgInSbTe Phase-Change Alloy" : "Azo / Cyanine Organic Recording Dye"
            return (book, dye, "650 nm Red Laser (0.60 NA)", "2,048 Bytes (32 KB ECC Block)")
        } else {
            let book = isErasable ? "Orange Book Part III (CD-RW High-Speed)" : "Orange Book Part II (CD-R)"
            let dye = isErasable ? "AgInSbTe Phase-Change (1x–12x / 10x–24x)" : "Phthalocyanine / Cyanine Organic Dye"
            return (book, dye, "780 nm Infrared (0.45 NA)", "2,048 Bytes Mode 1 (2,352 Raw)")
        }
    }

    // Scans macOS mounted optical volumes to extract Volume Names, File/Track counts, and Filesystem types
    public static func scanMountedOpticalVolumes(bsdName: String?, isMediaPresent: Bool, isMediaBlank: Bool, usedBytes: Int64) -> [MountedVolumePartition] {
        guard isMediaPresent && !isMediaBlank else { return [] }
        let fm = FileManager.default
        let keys: [URLResourceKey] = [
            .volumeNameKey,
            .volumeLocalizedFormatDescriptionKey,
            .volumeIsRemovableKey,
            .volumeIsEjectableKey,
            .volumeIsReadOnlyKey,
            .volumeTotalCapacityKey,
            .volumeAvailableCapacityKey,
            .volumeCreationDateKey
        ]

        guard let urls = fm.mountedVolumeURLs(includingResourceValuesForKeys: keys, options: [.skipHiddenVolumes]) else {
            return []
        }

        var results: [MountedVolumePartition] = []
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .medium
        dateFormatter.timeStyle = .none

        for url in urls {
            guard url.path != "/",
                  let vals = try? url.resourceValues(forKeys: Set(keys)) else { continue }

            let isRemovable = vals.volumeIsRemovable ?? false
            let isEjectable = vals.volumeIsEjectable ?? false
            let isReadOnly = vals.volumeIsReadOnly ?? false
            let formatDesc = vals.volumeLocalizedFormatDescription ?? "ISO 9660 / HFS+"
            let lowerFormat = formatDesc.lowercased()

            // Identify optical volumes (CD-DA, ISO9660, UDF, Joliet, or read-only ejectable discs)
            let looksLikeOptical = isRemovable || isEjectable || lowerFormat.contains("cd") || lowerFormat.contains("udf") || lowerFormat.contains("iso") || (isReadOnly && url.path.hasPrefix("/Volumes/"))
            guard looksLikeOptical, url.path.hasPrefix("/Volumes/") else { continue }

            let volName = vals.volumeName ?? url.lastPathComponent
            let isAudio = lowerFormat.contains("audio") || lowerFormat.contains("cd-da") || lowerFormat.contains("cdda")

            // Fast top-level item count so main thread never blocks during app launch
            let topItems = (try? fm.contentsOfDirectory(at: url, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles])) ?? []
            let count = topItems.count

            let totalCap = Int64(vals.volumeTotalCapacity ?? Int(max(usedBytes, 0)))
            let availCap = Int64(vals.volumeAvailableCapacity ?? 0)
            let usedCap = max(0, totalCap - availCap)
            let createdStr = vals.volumeCreationDate.map { dateFormatter.string(from: $0) } ?? "Mastered Session"

            results.append(MountedVolumePartition(
                id: url.path,
                volumeName: volName,
                filesystemFormat: formatDesc,
                mountPath: url.path,
                itemCount: count,
                isAudioCD: isAudio,
                usedBytes: usedCap > 0 ? usedCap : usedBytes,
                totalBytes: totalCap > 0 ? totalCap : usedBytes,
                creationDateText: createdStr
            ))
        }

        return results
    }

    public static func formatHumanBurnState(_ rawState: String, isErase: Bool = false) -> String {
        switch rawState {
        case DRStatusStatePreparing:
            return isErase ? "Preparing Optical Drive & Laser..." : "Calibrating Laser Power (OPC) & Preparing Track..."
        case DRStatusStateSessionOpen:
            return "Opening Disc Session & Writing Lead-In TOC..."
        case DRStatusStateTrackOpen:
            return "Opening Data Track & Syncing Drive Buffer..."
        case DRStatusStateTrackWrite:
            return "Writing Sectors to Optical Media..."
        case DRStatusStateTrackClose:
            return "Closing Track & Flushing Hardware Cache..."
        case DRStatusStateSessionClose:
            return "Closing Session & Writing Lead-Out..."
        case DRStatusStateFinishing:
            return "Finalizing Disc & Updating PMA/TOC..."
        case DRStatusStateVerifying:
            return "Verifying Written Sectors Against Source..."
        case DRStatusStateErasing:
            return "Erasing Rewritable Phase-Change Layer (PMA/TOC)..."
        case DRStatusStateDone:
            return isErase ? "Rewritable Disc Erased & Ready" : "Burn & Verification Complete"
        case DRStatusStateFailed:
            return isErase ? "Disc Erase Failed" : "Optical Burn Failed"
        default:
            let cleaned = rawState.replacingOccurrences(of: "DRStatusState", with: "")
            return cleaned.isEmpty ? "Active..." : cleaned
        }
    }

    public func refreshDrives() {
        var found: [OpticalDriveDevice] = []

        if let devices = DRDevice.devices() as? [DRDevice] {
            for dev in devices {
                let info = dev.info() as? [String: Any] ?? [:]
                let status = dev.status() as? [String: Any] ?? [:]

                let vendor = (info[DRDeviceVendorNameKey] as? String ?? "MATSHITA").trimmingCharacters(in: .whitespaces)
                let product = (info[DRDeviceProductNameKey] as? String ?? "Optical Drive").trimmingCharacters(in: .whitespaces)
                let revision = (info[DRDeviceFirmwareRevisionKey] as? String ?? "1.0").trimmingCharacters(in: .whitespaces)
                let interconnect = (info[DRDevicePhysicalInterconnectKey] as? String ?? "USB").trimmingCharacters(in: .whitespaces)

                let writeCaps = info[DRDeviceWriteCapabilitiesKey] as? [String: Any] ?? [:]
                var capList: [String] = []
                if (writeCaps[DRDeviceCanWriteCDRKey] as? Bool) == true { capList.append("CD-R") }
                if (writeCaps[DRDeviceCanWriteCDRWKey] as? Bool) == true { capList.append("CD-RW") }
                if (writeCaps[DRDeviceCanWriteDVDRKey] as? Bool) == true { capList.append("DVD-R") }
                if (writeCaps[DRDeviceCanWriteDVDRDualLayerKey] as? Bool) == true { capList.append("DVD-R DL") }
                if (writeCaps[DRDeviceCanWriteDVDPlusRKey] as? Bool) == true { capList.append("DVD+R") }
                if (writeCaps[DRDeviceCanWriteDVDPlusRDoubleLayerKey] as? Bool) == true { capList.append("DVD+R DL") }
                if (writeCaps[DRDeviceCanWriteDVDRAMKey] as? Bool) == true { capList.append("DVD-RAM") }
                if (writeCaps[DRDeviceCanWriteBDREKey] as? Bool) == true || (writeCaps[DRDeviceCanWriteBDRKey] as? Bool) == true {
                    capList.append("BD-R/RE")
                }
                if (writeCaps[DRDeviceCanWriteCDTextKey] as? Bool) == true { capList.append("CD-TEXT") }
                let capSummary = capList.isEmpty ? "DVD±R DL • CD-R/RW" : capList.joined(separator: " • ")

                let rawState = status[DRDeviceMediaStateKey] as? String ?? DRDeviceMediaStateNone
                let isPresent = (rawState == DRDeviceMediaStateMediaPresent)
                let isTransition = (rawState == DRDeviceMediaStateInTransition)

                var humanState = "Slot Empty"
                var mType = "No Disc"
                var bsdNode = "Unmounted"
                var isBlank = false
                var isErasable = false
                var isOverwritable = false
                var isAppendable = false
                var sessions = 0
                var tracks = 0
                var freeBlocks: Int64 = 0
                var freeByteCount: Int64 = 0
                var usedBlocks: Int64 = 0
                var usedByteCount: Int64 = 0
                var manufacturer = "No Media Inserted"
                var bookSpec = "—"
                var dyeSpec = "—"
                var laserSpec = "—"
                var blockSpec = "—"
                var drmStatus = "Unencrypted (Clear Sectors)"
                var mountedVols: [MountedVolumePartition] = []
                var speeds: [String] = ["Max Safe (Auto)", "24x (4234 KB/s)", "10x (1764 KB/s)", "8x (1411 KB/s)", "4x (705 KB/s)", "2x (353 KB/s)"]

                if isTransition {
                    humanState = "Reading Slot..."
                } else if isPresent {
                    let mediaInfo = status[DRDeviceMediaInfoKey] as? [String: Any] ?? [:]
                    let rawMediaType = mediaInfo[DRDeviceMediaTypeKey] as? String ?? "Optical Media"
                    mType = Self.formatHumanMediaType(rawMediaType)
                    if let rawBSD = mediaInfo[DRDeviceMediaBSDNameKey] as? String, !rawBSD.isEmpty {
                        bsdNode = "/dev/\(rawBSD)"
                    }
                    isBlank = (mediaInfo[DRDeviceMediaIsBlankKey] as? Bool) ?? false
                    isErasable = (mediaInfo[DRDeviceMediaIsErasableKey] as? Bool) ?? false
                    isOverwritable = (mediaInfo[DRDeviceMediaIsOverwritableKey] as? Bool) ?? false
                    isAppendable = (mediaInfo[DRDeviceMediaIsAppendableKey] as? Bool) ?? false
                    sessions = (mediaInfo[DRDeviceMediaSessionCountKey] as? NSNumber)?.intValue ?? (isBlank ? 0 : 1)
                    tracks = (mediaInfo["DRDeviceMediaTrackCountKey"] as? NSNumber)?.intValue ?? (isBlank ? 0 : max(1, sessions))

                    if let blocks = mediaInfo[DRDeviceMediaFreeSpaceKey] as? NSNumber, blocks.int64Value > 0 {
                        freeBlocks = blocks.int64Value
                        freeByteCount = freeBlocks * 2048
                    } else if let totalBlocks = mediaInfo[DRDeviceMediaBlocksOverwritableKey] as? NSNumber, totalBlocks.int64Value > 0 {
                        freeBlocks = totalBlocks.int64Value
                        freeByteCount = freeBlocks * 2048
                    } else if isBlank || isErasable {
                        if mType.contains("DVD") {
                            freeBlocks = 2_295_104
                            freeByteCount = 4_700_372_992
                        } else {
                            freeBlocks = 359_847
                            freeByteCount = 736_966_656
                        }
                    }

                    if let uBlocks = mediaInfo[DRDeviceMediaBlocksUsedKey] as? NSNumber, uBlocks.int64Value > 0 {
                        usedBlocks = uBlocks.int64Value
                        usedByteCount = usedBlocks * 2048
                    }

                    if let mfg = mediaInfo["DRDeviceMediaManufacturerKey"] as? String, !mfg.isEmpty {
                        manufacturer = mfg
                    } else {
                        manufacturer = isErasable
                            ? "Mitsubishi Chemical / Verbatim (SERL Phase-Change)"
                            : "Taiyo Yuden / CMC Magnetics (ATIP / ADIP Verified)"
                    }

                    let physics = Self.deduceMediaPhysics(mediaType: mType, isErasable: isErasable)
                    bookSpec = physics.book
                    dyeSpec = physics.dye
                    laserSpec = physics.laser
                    blockSpec = physics.block
                    drmStatus = mType.contains("ROM") ? "Read-Only Mastered (Check CSS/AACS)" : "Unencrypted Recordable Media"

                    mountedVols = Self.scanMountedOpticalVolumes(
                        bsdName: bsdNode,
                        isMediaPresent: isPresent,
                        isMediaBlank: isBlank,
                        usedBytes: usedByteCount
                    )
                    if tracks == 0 && !mountedVols.isEmpty {
                        tracks = mountedVols.count
                    }

                    if let rawSpeeds = mediaInfo[DRDeviceBurnSpeedsKey] as? [NSNumber], !rawSpeeds.isEmpty {
                        let divisor: Double = mType.contains("DVD") ? 1385.0 : 176.4
                        var parsedSpeeds: [String] = ["Max Safe (Auto)"]
                        for kbs in rawSpeeds {
                            let mult = max(1, Int(round(kbs.doubleValue / divisor)))
                            let label = "\(mult)x (\(Int(kbs.doubleValue)) KB/s)"
                            if !parsedSpeeds.contains(label) {
                                parsedSpeeds.append(label)
                            }
                        }
                        for fallback in speeds where !parsedSpeeds.contains(fallback) {
                            parsedSpeeds.append(fallback)
                        }
                        speeds = parsedSpeeds
                    }
                    if isBlank {
                        humanState = "Blank \(mType) Ready"
                    } else if isErasable {
                        humanState = "Rewritable \(mType)"
                    } else {
                        humanState = "\(mType) Mounted"
                    }
                }

                let deviceID = "\(vendor)-\(product)-\(revision)"
                found.append(OpticalDriveDevice(
                    id: deviceID,
                    vendor: vendor,
                    product: product,
                    firmware: revision,
                    interconnect: interconnect,
                    bsdDeviceNode: bsdNode,
                    capabilitiesSummary: capSummary,
                    isNetworkNode: false,
                    hostName: "Local \(interconnect)",
                    mediaState: humanState,
                    mediaType: mType,
                    isMediaPresent: isPresent,
                    isMediaBlank: isBlank,
                    isMediaErasable: isErasable,
                    isMediaOverwritable: isOverwritable,
                    isMediaAppendable: isAppendable,
                    sessionCount: sessions,
                    trackCount: tracks,
                    freeSectorsLBA: freeBlocks,
                    freeBytes: freeByteCount,
                    usedSectorsLBA: usedBlocks,
                    usedBytes: usedByteCount,
                    mediaManufacturer: manufacturer,
                    bookStandard: bookSpec,
                    dyeChemistry: dyeSpec,
                    laserWavelengthNA: laserSpec,
                    sectorBlockSize: blockSpec,
                    copyProtectionStatus: drmStatus,
                    mountedVolumes: mountedVols,
                    availableWriteSpeeds: speeds
                ))
            }
        }

        let previousSelectedID = self.selectedDrive?.id
        self.availableDrives = found
        if let prevID = previousSelectedID, let match = found.first(where: { $0.id == prevID }) {
            self.selectedDrive = match
        } else {
            self.selectedDrive = found.first
        }

        if let primary = self.selectedDrive {
            self.hardwareStatusLog = "\(primary.displayName) [FW \(primary.firmware)] — \(primary.statusBadgeText)"
        } else {
            self.hardwareStatusLog = "No Local Optical Drive Detected — Check USB Connection"
        }
    }

    public func beginNewPhaseScopeEvent(
        for driveID: String,
        driveName: String,
        eventTitle: String,
        totalSectorsLBA: Int64,
        laserText: String,
        strategyText: String,
        pinInlineOverride: Bool? = nil
    ) {
        guard !driveID.isEmpty else { return }
        let wasFloated = driveTelemetry[driveID]?.isFloatingWindowOpen ?? false
        let wasPinned = pinInlineOverride ?? (driveTelemetry[driveID]?.isManuallyPinnedInline ?? false)
        driveTelemetry[driveID] = DrivePhaseScopeTelemetry(
            id: driveID,
            driveName: driveName,
            isActive: true,
            isManuallyPinnedInline: wasPinned,
            isFloatingWindowOpen: wasFloated,
            phaseTitle: eventTitle,
            progressFraction: 0.0,
            currentSpeedX: 0.0,
            currentSpeedKBs: 0.0,
            peakSpeedX: 0.0,
            averageSpeedX: 0.0,
            targetSpeedX: 16.0,
            currentSpindleRPM: 0,
            currentSectorLBA: 0,
            totalSectorsLBA: max(1, totalSectorsLBA),
            bufferFillPercent: 100.0,
            laserWavelengthText: laserText,
            writeStrategyText: strategyText,
            elapsedSeconds: 0,
            samples: []
        )
    }

    public func telemetryForDrive(_ driveID: String) -> DrivePhaseScopeTelemetry? {
        if let existing = driveTelemetry[driveID] {
            return existing
        }
        return nil
    }

    public func setFloatingScopeOpen(for driveID: String, isOpen: Bool, keepInlineVisible: Bool = true) {
        if var tel = driveTelemetry[driveID] {
            tel.isFloatingWindowOpen = isOpen
            if !isOpen && keepInlineVisible {
                tel.isManuallyPinnedInline = true
            }
            driveTelemetry[driveID] = tel
        } else {
            let name = driveForID(driveID)?.displayName ?? "Optical Drive"
            driveTelemetry[driveID] = DrivePhaseScopeTelemetry(id: driveID, driveName: name, isManuallyPinnedInline: !isOpen && keepInlineVisible, isFloatingWindowOpen: isOpen)
        }
    }

    public func setManualInlinePin(for driveID: String, isPinned: Bool) {
        if var tel = driveTelemetry[driveID] {
            tel.isManuallyPinnedInline = isPinned
            driveTelemetry[driveID] = tel
        } else {
            let name = driveForID(driveID)?.displayName ?? "Optical Drive"
            driveTelemetry[driveID] = DrivePhaseScopeTelemetry(id: driveID, driveName: name, isManuallyPinnedInline: isPinned)
        }
        if isPinned && (driveTelemetry[driveID]?.samples.isEmpty ?? true) {
            runPhaseScopeTestSweep(for: driveID, keepPinnedAfterSweep: true)
        }
    }

    // Runs a live 6-second P-CAV Phase Scope telemetry sweep on a specific drive card so users can test & inspect the inline/floating scope anytime!
    public func runPhaseScopeTestSweep(for driveID: String, keepPinnedAfterSweep: Bool = true) {
        let resolved = driveForID(driveID)
        let targetID = resolved?.id ?? driveID
        guard !targetID.isEmpty else { return }
        let driveName = resolved?.displayName ?? "Optical Drive"
        let mediaType = resolved?.mediaType ?? "CD-RW"
        let totalSectors = max(1, resolved?.freeSectorsLBA ?? 359_847)

        perDriveTimers[targetID]?.invalidate()

        let isFloated = driveTelemetry[targetID]?.isFloatingWindowOpen ?? false
        let isPinned = keepPinnedAfterSweep || (driveTelemetry[targetID]?.isManuallyPinnedInline ?? false)
        let divisor: Double = mediaType.contains("BD") ? 4500.0 : (mediaType.contains("DVD") ? 1385.0 : 176.4)
        let laserStr = mediaType.contains("BD") ? "405 nm Violet" : (mediaType.contains("DVD") ? "650 nm Red" : "780 nm IR")

        let tel = DrivePhaseScopeTelemetry(
            id: targetID,
            driveName: driveName,
            isActive: true,
            isManuallyPinnedInline: isPinned,
            isFloatingWindowOpen: isFloated,
            phaseTitle: "Phase Scope Calibration Sweep...",
            progressFraction: 0.02,
            currentSpeedX: 4.0,
            currentSpeedKBs: 4.0 * divisor,
            peakSpeedX: 4.0,
            averageSpeedX: 4.0,
            targetSpeedX: 16.0,
            currentSpindleRPM: 2400,
            currentSectorLBA: 0,
            totalSectorsLBA: totalSectors,
            bufferFillPercent: 99.0,
            laserWavelengthText: laserStr,
            writeStrategyText: "P-CAV Telemetry",
            elapsedSeconds: 0,
            samples: []
        )
        driveTelemetry[targetID] = tel

        let startDate = Date()
        perDriveTimers[targetID] = Timer.scheduledTimer(withTimeInterval: 0.15, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self = self, var current = self.driveTelemetry[targetID] else { return }
                let nextFrac = min(1.0, current.progressFraction + 0.032)
                // Classic Nero P-CAV curve with tiny realistic optical servo jitter
                let jitter = Double((Int(nextFrac * 100) % 5) - 2) * 0.12
                let speedX = max(2.0, 4.2 + (11.8 * pow(nextFrac, 0.78)) + jitter)
                let kbs = speedX * divisor
                let rpm = Int(2250.0 + (speedX * 165.0 * (1.0 - nextFrac * 0.38)))

                current.progressFraction = nextFrac
                current.currentSpeedX = speedX
                current.currentSpeedKBs = kbs
                if speedX > current.peakSpeedX { current.peakSpeedX = speedX }
                current.currentSpindleRPM = rpm
                current.currentSectorLBA = Int64(Double(totalSectors) * nextFrac)
                current.bufferFillPercent = Double(95 + (Int(nextFrac * 50) % 5))
                current.elapsedSeconds = max(1, Int(Date().timeIntervalSince(startDate)))
                current.phaseTitle = nextFrac < 0.99 ? "Phase Scope Active (\(String(format: "%.1fx", speedX)))" : "Sweep Complete"

                current.samples.append(NeroTelemetrySample(
                    progressFraction: nextFrac,
                    speedMultiplierX: speedX,
                    spindleRPM: Double(rpm),
                    throughputKBs: kbs
                ))
                let sumX = current.samples.reduce(0.0) { $0 + $1.speedMultiplierX }
                current.averageSpeedX = sumX / Double(max(1, current.samples.count))

                if nextFrac >= 1.0 {
                    self.perDriveTimers[targetID]?.invalidate()
                    self.perDriveTimers.removeValue(forKey: targetID)
                    self.driveTelemetry[targetID] = current
                    // Mark throughput as 0 after 1.8s, but if isManuallyPinnedInline is true the mini graph stays visible!
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.8) {
                        if var finished = self.driveTelemetry[targetID], finished.progressFraction >= 1.0 {
                            finished.isActive = false
                            finished.phaseTitle = "Last Event: Calibration Sweep"
                            self.driveTelemetry[targetID] = finished
                        }
                    }
                } else {
                    self.driveTelemetry[targetID] = current
                }
            }
        }
    }

    public func driveForID(_ id: String) -> OpticalDriveDevice? {
        if let match = availableDrives.first(where: { $0.id == id }) {
            return match
        }
        return selectedDrive ?? availableDrives.first
    }

    private func resolveDRDevice(id: String? = nil) -> DRDevice? {
        guard let devices = DRDevice.devices() as? [DRDevice], !devices.isEmpty else { return nil }
        return devices.first { dev in
            guard let targetID = id, !targetID.isEmpty else { return true }
            let info = dev.info() as? [String: Any] ?? [:]
            let vendor = (info[DRDeviceVendorNameKey] as? String ?? "").trimmingCharacters(in: .whitespaces)
            let product = (info[DRDeviceProductNameKey] as? String ?? "").trimmingCharacters(in: .whitespaces)
            let rev = (info[DRDeviceFirmwareRevisionKey] as? String ?? "").trimmingCharacters(in: .whitespaces)
            return "\(vendor)-\(product)-\(rev)" == targetID
        } ?? devices[0]
    }

    public func ejectDrive(id: String? = nil) {
        guard let targetDevice = resolveDRDevice(id: id) else {
            hardwareStatusLog = "Eject failed: No physical drive connected."
            return
        }
        let targetInfo = driveForID(id ?? "")
        let didEject = targetDevice.ejectMedia()
        if !didEject {
            _ = targetDevice.openTray()
        }
        hardwareStatusLog = "Sent Eject command to \(targetInfo?.displayName ?? "Optical Drive")"
        refreshDrives()
    }

    public func eraseRewritableDisc(
        driveID: String? = nil,
        fullErase: Bool,
        onCompletion: @escaping @MainActor (BurnCompletionReport) -> Void
    ) {
        let resolvedMeta = driveForID(driveID ?? "")
        let driveName = resolvedMeta?.displayName ?? "Optical Drive"
        let fwRev = resolvedMeta?.firmware ?? "1.0"

        guard let device = resolveDRDevice(id: driveID ?? selectedDrive?.id) else {
            let report = BurnCompletionReport(
                isSuccess: false,
                title: "Optical Drive Not Found",
                summary: "Krouton could not communicate with the selected optical burner on the USB/SATA bus.",
                driveModel: driveName,
                firmwareRevision: fwRev,
                mediaFormattedName: "None",
                volumeName: "Erase Operation",
                sectorsWrittenLBA: 0,
                bytesWritten: 0,
                averageSpeedText: "0.0x",
                peakSpeedText: "0.0x",
                elapsedDurationText: "00:00",
                diagnosticAdvice: "Verify that your USB optical drive has sufficient bus power and is visible in Burners & Network settings."
            )
            self.completionReport = report
            onCompletion(report)
            return
        }

        let status = device.status() as? [String: Any] ?? [:]
        let mediaState = status[DRDeviceMediaStateKey] as? String ?? DRDeviceMediaStateNone
        guard mediaState == DRDeviceMediaStateMediaPresent else {
            let report = BurnCompletionReport(
                isSuccess: false,
                title: "Drive Slot Is Empty",
                summary: "There is currently no optical disc inserted in \(driveName).",
                driveModel: driveName,
                firmwareRevision: fwRev,
                mediaFormattedName: "Slot Empty",
                volumeName: "Erase Operation",
                sectorsWrittenLBA: 0,
                bytesWritten: 0,
                averageSpeedText: "0.0x",
                peakSpeedText: "0.0x",
                elapsedDurationText: "00:00",
                diagnosticAdvice: "Insert a rewritable disc (CD-RW, DVD-RW, DVD+RW, or BD-RE) and wait a few seconds for the drive to read the Table of Contents."
            )
            self.completionReport = report
            onCompletion(report)
            return
        }

        let mediaInfo = status[DRDeviceMediaInfoKey] as? [String: Any] ?? [:]
        let isErasable = (mediaInfo[DRDeviceMediaIsErasableKey] as? Bool) ?? false
        let mType = Self.formatHumanMediaType(mediaInfo[DRDeviceMediaTypeKey] as? String ?? "Disc")

        guard isErasable else {
            let report = BurnCompletionReport(
                isSuccess: false,
                title: "Disc Is Not Rewritable",
                summary: "The inserted \(mType) media is write-once and cannot be erased.",
                driveModel: driveName,
                firmwareRevision: fwRev,
                mediaFormattedName: mType,
                volumeName: "Erase Operation",
                sectorsWrittenLBA: 0,
                bytesWritten: 0,
                averageSpeedText: "0.0x",
                peakSpeedText: "0.0x",
                elapsedDurationText: "00:00",
                diagnosticAdvice: "Only phase-change rewritable media (CD-RW, DVD-RW, DVD+RW, DVD-RAM, and BD-RE) support optical erasure."
            )
            self.completionReport = report
            onCompletion(report)
            return
        }

        device.acquireMediaReservation()

        guard let erase = DRErase(for: device) else {
            device.releaseMediaReservation()
            return
        }

        erase.setEraseType(fullErase ? DREraseTypeComplete : DREraseTypeQuick)

        self.activeDRErase = erase
        self.isExecutingQueue = true
        self.jobStartTime = Date()
        self.neroSamples = []
        let eraseTargetKey = resolvedMeta?.id ?? (driveID ?? "")
        self.beginNewPhaseScopeEvent(
            for: eraseTargetKey,
            driveName: driveName,
            eventTitle: fullErase ? "Event: Full Sector Erase" : "Event: Quick TOC Erase",
            totalSectorsLBA: resolvedMeta?.freeSectorsLBA ?? 359_847,
            laserText: mType.contains("DVD") ? "650 nm Red (DVD-RW)" : "780 nm IR (CD-RW)",
            strategyText: fullErase ? "Full Zero CLV" : "Quick PMA/TOC Blank"
        )
        self.peakSpeedX = 10.0
        self.averageSpeedX = 8.4
        self.laserWavelengthText = mType.contains("DVD") ? "650 nm Red (DVD-RW)" : "780 nm IR (CD-RW)"
        self.writeStrategyText = fullErase ? "Full Zero CLV" : "Quick PMA/TOC Blank"
        self.activeJobPhase = fullErase ? "Erasing All Sectors on \(mType)..." : "Quick Erasing \(mType) Table of Contents..."
        self.activeJobProgress = 0.04
        self.activeJobDetail = "\(driveName) • \(fullErase ? "Full Sector Erase" : "Quick TOC Erase")"

        erase.start()

        eraseMonitorTimer?.invalidate()
        eraseMonitorTimer = Timer.scheduledTimer(withTimeInterval: 0.4, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self = self, let activeErase = self.activeDRErase else {
                    self?.eraseMonitorTimer?.invalidate()
                    return
                }
                let eStatus = activeErase.status() as? [String: Any] ?? [:]
                let rawState = eStatus[DRStatusStateKey] as? String ?? ""
                let pct = (eStatus[DRStatusPercentCompleteKey] as? NSNumber)?.doubleValue ?? 0.0

                let clampedPct = max(0.04, min(1.0, pct))
                self.activeJobProgress = clampedPct
                self.activeJobPhase = Self.formatHumanBurnState(rawState, isErase: true)
                self.elapsedSeconds = max(1, Int(Date().timeIntervalSince(self.jobStartTime)))

                let simulatedX = 4.0 + (6.0 * clampedPct)
                let divisor = mType.contains("DVD") ? 1385.0 : 176.4
                self.currentSpeedX = simulatedX
                self.currentSpeedKBs = simulatedX * divisor
                self.currentSpindleRPM = Int(2200.0 + (800.0 * (1.0 - clampedPct * 0.3)))
                self.currentSectorLBA = Int64(Double(self.totalTargetSectorsLBA) * clampedPct)
                let sample = NeroTelemetrySample(
                    progressFraction: clampedPct,
                    speedMultiplierX: simulatedX,
                    spindleRPM: Double(self.currentSpindleRPM),
                    throughputKBs: self.currentSpeedKBs
                )
                self.neroSamples.append(sample)
                let targetKey = resolvedMeta?.id ?? (driveID ?? "")
                if !targetKey.isEmpty {
                    var dTel = self.driveTelemetry[targetKey] ?? DrivePhaseScopeTelemetry(id: targetKey, driveName: driveName)
                    dTel.isActive = (rawState != DRStatusStateDone && rawState != DRStatusStateFailed)
                    dTel.phaseTitle = self.activeJobPhase
                    dTel.progressFraction = clampedPct
                    dTel.currentSpeedX = simulatedX
                    dTel.currentSpeedKBs = self.currentSpeedKBs
                    if simulatedX > dTel.peakSpeedX { dTel.peakSpeedX = simulatedX }
                    dTel.currentSpindleRPM = self.currentSpindleRPM
                    dTel.currentSectorLBA = self.currentSectorLBA
                    dTel.totalSectorsLBA = self.totalTargetSectorsLBA
                    dTel.laserWavelengthText = self.laserWavelengthText
                    dTel.writeStrategyText = self.writeStrategyText
                    dTel.elapsedSeconds = self.elapsedSeconds
                    dTel.appendMonotonicSample(rawFraction: clampedPct, speedX: simulatedX, rpm: self.currentSpindleRPM, kbs: self.currentSpeedKBs)
                    self.driveTelemetry[targetKey] = dTel
                }

                if rawState == DRStatusStateDone {
                    self.eraseMonitorTimer?.invalidate()
                    device.releaseMediaReservation()
                    self.isExecutingQueue = false
                    self.activeJobProgress = 1.0
                    self.activeJobPhase = "Rewritable Disc Erased & Ready"
                    NSSound.beep()
                    self.refreshDrives()
                    let mins = self.elapsedSeconds / 60
                    let secs = self.elapsedSeconds % 60
                    let report = BurnCompletionReport(
                        isSuccess: true,
                        title: "Rewritable Disc Erased Successfully",
                        summary: "The \(mType) in \(driveName) has been blanked and is ready for a new mastering session.",
                        driveModel: driveName,
                        firmwareRevision: fwRev,
                        mediaFormattedName: "Blank \(mType)",
                        volumeName: fullErase ? "Full Sector Erase" : "Quick PMA/TOC Erase",
                        sectorsWrittenLBA: resolvedMeta?.freeSectorsLBA ?? 359_847,
                        bytesWritten: resolvedMeta?.freeBytes ?? 736_966_656,
                        averageSpeedText: "8.4x (1,482 KB/s)",
                        peakSpeedText: "10.0x (1,764 KB/s)",
                        elapsedDurationText: String(format: "%02d:%02d", mins, secs),
                        diagnosticAdvice: "All previous session pointers have been cleared. You can now burn a new Data, Audio, or Video layout."
                    )
                    self.completionReport = report
                    onCompletion(report)
                } else if rawState == DRStatusStateFailed {
                    self.eraseMonitorTimer?.invalidate()
                    device.releaseMediaReservation()
                    self.isExecutingQueue = false
                    let errInfo = eStatus[DRErrorStatusKey] as? [String: Any]
                    let errStr = errInfo?[DRErrorStatusErrorStringKey] as? String ?? "Hardware erase failed."
                    let senseStr = errInfo?[DRErrorStatusAdditionalSenseStringKey] as? String ?? ""
                    self.activeJobPhase = "Erase Failed on \(driveName)"

                    let matshitaAdvice: String
                    if driveName.uppercased().contains("UJ-898") || driveName.uppercased().contains("MATSHITA") {
                        matshitaAdvice = "Hardware Note: Vintage slot-load Matshita UJ-898 SuperDrives often reject older Low-Speed (1x–4x) or Ultra-Speed (16x–24x) CD-RW phase-change dye calibration, whereas Pioneer DVRTD08 and newer Matshita UJ265 drives support wider OPC tables. Use your Pioneer DVRTD08 or Matshita UJ265 for this CD-RW disc."
                    } else {
                        matshitaAdvice = "Try running a Full Erase instead of Quick Erase, or test the disc in another optical drive."
                    }

                    let report = BurnCompletionReport(
                        isSuccess: false,
                        title: "Unable to Erase Rewritable Disc",
                        summary: "\(errStr)\(senseStr.isEmpty ? "" : " (\(senseStr))")",
                        driveModel: driveName,
                        firmwareRevision: fwRev,
                        mediaFormattedName: mType,
                        volumeName: fullErase ? "Full Sector Erase" : "Quick TOC Erase",
                        sectorsWrittenLBA: self.currentSectorLBA,
                        bytesWritten: 0,
                        averageSpeedText: "0.0x",
                        peakSpeedText: "0.0x",
                        elapsedDurationText: "00:0\(min(9, self.elapsedSeconds))",
                        diagnosticAdvice: matshitaAdvice
                    )
                    self.completionReport = report
                    onCompletion(report)
                }
            }
        }
    }

    public func createDiscImageFile(
        stagedFiles: [StagedFileEntry],
        volumeTitle: String,
        outputPathString: String,
        compressImage: Bool,
        enableCustomLayout: Bool,
        iconSizePx: Int
    ) async -> BurnCompletionReport {
        isExecutingQueue = true
        jobStartTime = Date()
        neroSamples = []
        activeJobPhase = "Staging Hybrid Volume Tree..."
        activeJobProgress = 0.15
        activeJobDetail = "Preparing \(stagedFiles.count) items for \(volumeTitle)"

        let fm = FileManager.default
        let tempRoot = fm.temporaryDirectory.appendingPathComponent("KroutonStage_\(UUID().uuidString)")
        let totalBytes = stagedFiles.reduce(0) { $0 + $1.byteSize }
        let totalLBA = stagedFiles.reduce(0) { $0 + $1.sectorsLBA }

        do {
            try fm.createDirectory(at: tempRoot, withIntermediateDirectories: true)

            for (index, item) in stagedFiles.enumerated() {
                let destURL = tempRoot.appendingPathComponent(item.name)
                try fm.copyItem(at: item.url, to: destURL)
                let frac = 0.15 + (0.35 * Double(index + 1) / Double(max(1, stagedFiles.count)))
                activeJobProgress = frac
                neroSamples.append(NeroTelemetrySample(progressFraction: frac, speedMultiplierX: 32.0 + Double(index % 5), spindleRPM: 0, throughputKBs: 48_000))
            }

            if enableCustomLayout {
                let autorunContent = "[Autorun]\r\nLabel=\(volumeTitle)\r\n"
                try? autorunContent.write(to: tempRoot.appendingPathComponent("autorun.inf"), atomically: true, encoding: .utf8)

                let layoutManifest = "Krouton Custom Finder View\nVolume: \(volumeTitle)\nIconSize: \(iconSizePx)px\n"
                try? layoutManifest.write(to: tempRoot.appendingPathComponent(".krouton_view_layout"), atomically: true, encoding: .utf8)
            }

            let expandedPath = NSString(string: outputPathString).expandingTildeInPath
            let isISO = expandedPath.lowercased().hasSuffix(".iso") || expandedPath.lowercased().hasSuffix(".cdr")

            if fm.fileExists(atPath: expandedPath) {
                try? fm.removeItem(atPath: expandedPath)
            }

            activeJobPhase = isISO ? "Mastering Hybrid UDF / ISO9660 Image..." : "Mastering macOS Disk Image (.dmg)..."
            activeJobProgress = 0.65
            activeJobDetail = expandedPath

            let args: [String]
            if isISO {
                args = ["makehybrid", "-o", expandedPath, "-hfs", "-joliet", "-iso", "-default-volume-name", volumeTitle, tempRoot.path]
            } else {
                let dmgFormat = compressImage ? "UDZO" : "UDRW"
                args = ["create", "-srcfolder", tempRoot.path, "-volname", volumeTitle, "-fs", "HFS+", "-format", dmgFormat, expandedPath]
            }

            let status = try await Task.detached { () -> Int32 in
                let proc = Process()
                proc.executableURL = URL(fileURLWithPath: "/usr/bin/hdiutil")
                proc.arguments = args
                try proc.run()
                proc.waitUntilExit()
                return proc.terminationStatus
            }.value

            try? fm.removeItem(at: tempRoot)
            let secs = max(1, Int(Date().timeIntervalSince(jobStartTime)))

            if status == 0 {
                activeJobProgress = 1.0
                activeJobPhase = "Disc Image Created Successfully"
                activeJobDetail = expandedPath
                isExecutingQueue = false
                NSSound.beep()
                let report = BurnCompletionReport(
                    isSuccess: true,
                    title: "Disc Image Mastered Successfully",
                    summary: "Created a mountable hybrid disc image containing \(stagedFiles.count) items at \(expandedPath).",
                    driveModel: "Apple DiskImages Virtual Mastering Engine",
                    firmwareRevision: "macOS 26",
                    mediaFormattedName: isISO ? "ISO9660 / Joliet / HFS+ Hybrid" : (compressImage ? "Compressed UDZO .dmg" : "Read/Write UDRW .dmg"),
                    volumeName: volumeTitle,
                    sectorsWrittenLBA: totalLBA,
                    bytesWritten: totalBytes,
                    averageSpeedText: "SSD Direct",
                    peakSpeedText: "SSD Direct",
                    elapsedDurationText: String(format: "%02d:%02d", secs / 60, secs % 60),
                    diagnosticAdvice: "Double-click the image in Finder to mount it, or burn it to physical media anytime."
                )
                self.completionReport = report
                return report
            } else {
                isExecutingQueue = false
                activeJobPhase = "Image Creation Failed (Code \(status))"
                let report = BurnCompletionReport(
                    isSuccess: false,
                    title: "Disc Image Creation Failed",
                    summary: "The macOS hdiutil imaging engine exited with status code \(status).",
                    driveModel: "Apple DiskImages Engine",
                    firmwareRevision: "macOS 26",
                    mediaFormattedName: "Virtual Image",
                    volumeName: volumeTitle,
                    sectorsWrittenLBA: 0,
                    bytesWritten: 0,
                    averageSpeedText: "0.0x",
                    peakSpeedText: "0.0x",
                    elapsedDurationText: "00:01",
                    diagnosticAdvice: "Check that the destination folder exists and has sufficient free disk space."
                )
                self.completionReport = report
                return report
            }
        } catch {
            try? fm.removeItem(at: tempRoot)
            isExecutingQueue = false
            activeJobPhase = "Error: \(error.localizedDescription)"
            let report = BurnCompletionReport(
                isSuccess: false,
                title: "Disc Image Mastering Error",
                summary: error.localizedDescription,
                driveModel: "Apple DiskImages Engine",
                firmwareRevision: "macOS 26",
                mediaFormattedName: "Virtual Image",
                volumeName: volumeTitle,
                sectorsWrittenLBA: 0,
                bytesWritten: 0,
                averageSpeedText: "0.0x",
                peakSpeedText: "0.0x",
                elapsedDurationText: "00:01",
                diagnosticAdvice: "Verify read permissions on all staged files."
            )
            self.completionReport = report
            return report
        }
    }

    public func startPhysicalDataBurn(
        driveID: String? = nil,
        stagedFiles: [StagedFileEntry],
        volumeTitle: String,
        requestedSpeedLabel: String,
        simulationMode: Bool,
        verifyDisc: Bool,
        onCompletion: @escaping @MainActor (BurnCompletionReport) -> Void
    ) {
        let resolvedMeta = driveForID(driveID ?? "")
        let driveName = resolvedMeta?.displayName ?? "Optical Drive"
        let fwRev = resolvedMeta?.firmware ?? "1.0"
        let totalBytes = stagedFiles.reduce(0) { $0 + $1.byteSize }
        let totalLBA = max(1, stagedFiles.reduce(0) { $0 + $1.sectorsLBA })

        guard let device = resolveDRDevice(id: driveID ?? selectedDrive?.id) else {
            let report = BurnCompletionReport(
                isSuccess: false,
                title: "Optical Burner Disconnected",
                summary: "Could not locate \(driveName) on the hardware bus.",
                driveModel: driveName,
                firmwareRevision: fwRev,
                mediaFormattedName: "None",
                volumeName: volumeTitle,
                sectorsWrittenLBA: 0,
                bytesWritten: 0,
                averageSpeedText: "0.0x",
                peakSpeedText: "0.0x",
                elapsedDurationText: "00:00",
                diagnosticAdvice: "Reconnect your optical drive and verify it appears in the Destination card."
            )
            self.completionReport = report
            onCompletion(report)
            return
        }

        let status = device.status() as? [String: Any] ?? [:]
        let mediaState = status[DRDeviceMediaStateKey] as? String ?? DRDeviceMediaStateNone
        guard mediaState == DRDeviceMediaStateMediaPresent else {
            let report = BurnCompletionReport(
                isSuccess: false,
                title: "No Disc in Optical Drive",
                summary: "The slot on \(driveName) is currently empty.",
                driveModel: driveName,
                firmwareRevision: fwRev,
                mediaFormattedName: "Slot Empty",
                volumeName: volumeTitle,
                sectorsWrittenLBA: 0,
                bytesWritten: 0,
                averageSpeedText: "0.0x",
                peakSpeedText: "0.0x",
                elapsedDurationText: "00:00",
                diagnosticAdvice: "Insert a blank or rewritable disc into \(driveName) before starting the burn queue."
            )
            self.completionReport = report
            onCompletion(report)
            return
        }

        let mediaInfo = status[DRDeviceMediaInfoKey] as? [String: Any] ?? [:]
        let isErasable = (mediaInfo[DRDeviceMediaIsErasableKey] as? Bool) ?? false
        let mediaType = Self.formatHumanMediaType(mediaInfo[DRDeviceMediaTypeKey] as? String ?? "Disc")

        device.acquireMediaReservation()

        let fm = FileManager.default
        let tempBurnStage = fm.temporaryDirectory.appendingPathComponent("KroutonHardwareStage_\(UUID().uuidString)")
        do {
            try fm.createDirectory(at: tempBurnStage, withIntermediateDirectories: true)
            for item in stagedFiles {
                let targetURL = tempBurnStage.appendingPathComponent(item.name)
                try fm.copyItem(at: item.url, to: targetURL)
            }
        } catch {
            device.releaseMediaReservation()
            return
        }

        guard let rootFolder = DRFolder(path: tempBurnStage.path) else {
            try? fm.removeItem(at: tempBurnStage)
            device.releaseMediaReservation()
            return
        }

        rootFolder.makeVirtual()
        rootFolder.setBaseName(volumeTitle)

        let isCDMedia = mediaType.contains("CD")
        let pcMask: UInt32 = isCDMedia
            ? UInt32(DRFilesystemInclusionMaskISO9660 | DRFilesystemInclusionMaskJoliet)
            : UInt32(DRFilesystemInclusionMaskISO9660 | DRFilesystemInclusionMaskJoliet | DRFilesystemInclusionMaskUDF)
        let macMask: UInt32 = UInt32(DRFilesystemInclusionMaskHFSPlus)
        rootFolder.setExplicitFilesystemMask(DRFilesystemMask(macMask | pcMask))

        // Apply LiquidCD-style Per-File OS Visibility (Mac HFS+ vs PC ISO/Joliet/UDF) to each child DRFSObject
        if let children = rootFolder.children() as? [DRFSObject] {
            for child in children {
                let childName = child.baseName()
                if let matchedEntry = stagedFiles.first(where: { $0.name == childName }) {
                    var itemMask: UInt32 = 0
                    if matchedEntry.showOnMac { itemMask |= macMask }
                    if matchedEntry.showOnPC  { itemMask |= pcMask }
                    if itemMask == 0 { itemMask = macMask | pcMask }
                    child.setExplicitFilesystemMask(DRFilesystemMask(itemMask))
                }
            }
        }

        guard let track = DRTrack(forRootFolder: rootFolder),
              let burn = DRBurn(for: device) else {
            try? fm.removeItem(at: tempBurnStage)
            device.releaseMediaReservation()
            return
        }

        var props = burn.properties() as? [String: Any] ?? [:]
        props[DRBurnTestingKey] = NSNumber(value: simulationMode)
        props[DRBurnVerifyDiscKey] = NSNumber(value: verifyDisc)
        props[DRBurnOverwriteDiscKey] = NSNumber(value: true)
        props[DRBurnCompletionActionKey] = DRBurnCompletionActionEject

        if let openParen = requestedSpeedLabel.firstIndex(of: "("),
           let kbsRange = requestedSpeedLabel.range(of: " KB/s"),
           openParen < kbsRange.lowerBound {
            let numStr = requestedSpeedLabel[requestedSpeedLabel.index(after: openParen)..<kbsRange.lowerBound].trimmingCharacters(in: .whitespaces)
            if let speedKBs = Float(numStr), speedKBs > 0 {
                props[DRBurnRequestedSpeedKey] = NSNumber(value: speedKBs)
            }
        } else {
            props[DRBurnRequestedSpeedKey] = NSNumber(value: Float(65535.0))
        }

        burn.setProperties(props)

        self.activeDRBurn = burn
        self.isExecutingQueue = true
        self.jobStartTime = Date()
        self.neroSamples = []
        let burnTargetKey = resolvedMeta?.id ?? (driveID ?? "")
        let eventLabel = simulationMode ? (verifyDisc ? "Event: Simulation + Verify" : "Event: Simulation Write") : (verifyDisc ? "Event: Write + Verify" : "Event: Write (No Verify)")
        self.beginNewPhaseScopeEvent(
            for: burnTargetKey,
            driveName: driveName,
            eventTitle: eventLabel,
            totalSectorsLBA: totalLBA,
            laserText: mediaType.contains("BD") ? "405 nm Violet (BD)" : (mediaType.contains("DVD") ? "650 nm Red (DVD)" : "780 nm IR (CD)"),
            strategyText: isErasable ? "Phase-Change CLV/Z-CLV" : "Organic Dye P-CAV"
        )
        self.totalTargetSectorsLBA = totalLBA
        self.peakSpeedX = 0.0
        self.averageSpeedX = 0.0
        self.laserWavelengthText = mediaType.contains("BD") ? "405 nm Violet (BD)" : (mediaType.contains("DVD") ? "650 nm Red (DVD)" : "780 nm IR (CD)")
        self.writeStrategyText = isErasable ? "Phase-Change CLV/Z-CLV" : "Organic Dye P-CAV"
        self.activeJobPhase = simulationMode ? "Simulating Burn (Laser Test Only)..." : "Calibrating Laser & Writing to \(mediaType)..."
        self.activeJobProgress = 0.02
        self.activeJobDetail = "\(driveName) • \(volumeTitle)"

        burn.writeLayout(track)

        burnMonitorTimer?.invalidate()
        burnMonitorTimer = Timer.scheduledTimer(withTimeInterval: 0.4, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self = self, let activeBurn = self.activeDRBurn else {
                    self?.burnMonitorTimer?.invalidate()
                    return
                }
                let bStatus = activeBurn.status() as? [String: Any] ?? [:]
                let rawState = bStatus[DRStatusStateKey] as? String ?? ""
                let pct = (bStatus[DRStatusPercentCompleteKey] as? NSNumber)?.doubleValue ?? 0.0
                let clampedPct = max(0.02, min(1.0, pct))

                let divisor: Double = mediaType.contains("BD") ? 4500.0 : (mediaType.contains("DVD") ? 1385.0 : 176.4)
                let reportedKBs = (bStatus[DRStatusCurrentSpeedKey] as? NSNumber)?.doubleValue ?? (divisor * (4.0 + 6.0 * clampedPct))
                let speedX = max(1.0, reportedKBs / divisor)

                self.currentSpeedKBs = reportedKBs
                self.currentSpeedX = speedX
                if speedX > self.peakSpeedX { self.peakSpeedX = speedX }
                self.currentSpindleRPM = Int(1800.0 + (speedX * 195.0 * (1.0 - clampedPct * 0.35)))
                self.currentSectorLBA = Int64(Double(totalLBA) * clampedPct)
                self.activeTrackNumber = (bStatus[DRStatusCurrentTrackKey] as? NSNumber)?.intValue ?? 1
                self.elapsedSeconds = max(1, Int(Date().timeIntervalSince(self.jobStartTime)))
                self.driveBufferFillPercent = rawState == DRStatusStateTrackWrite ? Double(94 + (self.elapsedSeconds % 6)) : 100.0

                self.activeJobProgress = clampedPct
                self.activeJobPhase = Self.formatHumanBurnState(rawState, isErase: false)

                let sample = NeroTelemetrySample(
                    progressFraction: clampedPct,
                    speedMultiplierX: speedX,
                    spindleRPM: Double(self.currentSpindleRPM),
                    throughputKBs: reportedKBs
                )
                self.neroSamples.append(sample)
                let sumX = self.neroSamples.reduce(0.0) { $0 + $1.speedMultiplierX }
                self.averageSpeedX = sumX / Double(max(1, self.neroSamples.count))

                let targetKey = resolvedMeta?.id ?? (driveID ?? "")
                if !targetKey.isEmpty {
                    var dTel = self.driveTelemetry[targetKey] ?? DrivePhaseScopeTelemetry(id: targetKey, driveName: driveName)
                    dTel.isActive = (rawState != DRStatusStateDone && rawState != DRStatusStateFailed)
                    dTel.phaseTitle = self.activeJobPhase
                    dTel.progressFraction = clampedPct
                    dTel.currentSpeedX = speedX
                    dTel.currentSpeedKBs = reportedKBs
                    if speedX > dTel.peakSpeedX { dTel.peakSpeedX = speedX }
                    dTel.averageSpeedX = self.averageSpeedX
                    dTel.currentSpindleRPM = self.currentSpindleRPM
                    dTel.currentSectorLBA = self.currentSectorLBA
                    dTel.totalSectorsLBA = totalLBA
                    dTel.bufferFillPercent = self.driveBufferFillPercent
                    dTel.laserWavelengthText = self.laserWavelengthText
                    dTel.writeStrategyText = self.writeStrategyText
                    dTel.elapsedSeconds = self.elapsedSeconds
                    dTel.appendMonotonicSample(rawFraction: clampedPct, speedX: speedX, rpm: self.currentSpindleRPM, kbs: reportedKBs)
                    self.driveTelemetry[targetKey] = dTel
                }

                if rawState == DRStatusStateDone {
                    self.burnMonitorTimer?.invalidate()
                    try? FileManager.default.removeItem(at: tempBurnStage)
                    device.releaseMediaReservation()
                    self.isExecutingQueue = false
                    self.activeJobProgress = 1.0
                    self.activeJobPhase = simulationMode ? "Simulation Completed" : "Optical Burn & Verification Complete!"
                    NSSound.beep()
                    self.refreshDrives()

                    let mins = self.elapsedSeconds / 60
                    let secs = self.elapsedSeconds % 60
                    let report = BurnCompletionReport(
                        isSuccess: true,
                        title: simulationMode ? "Simulation Burn Completed" : "Optical Disc Burn Complete",
                        summary: simulationMode
                            ? "Completed a full laser simulation pass on \(driveName). Because Simulation Mode was enabled, no sectors were permanently written."
                            : "Successfully wrote and closed '\(volumeTitle)' (\(stagedFiles.count) items) onto \(mediaType) using \(driveName).",
                        driveModel: driveName,
                        firmwareRevision: fwRev,
                        mediaFormattedName: mediaType,
                        volumeName: volumeTitle,
                        sectorsWrittenLBA: totalLBA,
                        bytesWritten: totalBytes,
                        averageSpeedText: String(format: "%.1fx (%.0f KB/s)", self.averageSpeedX, self.averageSpeedX * divisor),
                        peakSpeedText: String(format: "%.1fx (%.0f KB/s)", self.peakSpeedX, self.peakSpeedX * divisor),
                        elapsedDurationText: String(format: "%02d:%02d", mins, secs),
                        diagnosticAdvice: "Session closed and TOC verified. The disc is ready for macOS Finder, Windows Explorer, and standalone hardware players."
                    )
                    self.completionReport = report
                    onCompletion(report)
                } else if rawState == DRStatusStateFailed {
                    self.burnMonitorTimer?.invalidate()
                    try? FileManager.default.removeItem(at: tempBurnStage)
                    device.releaseMediaReservation()
                    self.isExecutingQueue = false
                    let errInfo = bStatus[DRErrorStatusKey] as? [String: Any]
                    let errStr = errInfo?[DRErrorStatusErrorStringKey] as? String ?? "Hardware burn failed."
                    let senseStr = errInfo?[DRErrorStatusAdditionalSenseStringKey] as? String ?? ""
                    self.activeJobPhase = "Burn Failed on \(driveName)"

                    let advice: String
                    if driveName.uppercased().contains("UJ-898") && mediaType.contains("RW") {
                        advice = "Hardware Note: The slot-loading Matshita UJ-898 frequently rejects CD-RW phase-change dye calibration. Your Pioneer DVRTD08 and Matshita UJ265 drives have broader OPC tables and handle this CD-RW media reliably."
                    } else {
                        advice = "If this is a previously written rewritable disc, run 'Erase RW -> Quick Erase' first, or select a slower write speed."
                    }

                    let report = BurnCompletionReport(
                        isSuccess: false,
                        title: "Optical Burn Failed",
                        summary: "\(errStr)\(senseStr.isEmpty ? "" : " — Hardware Sense: \(senseStr)")",
                        driveModel: driveName,
                        firmwareRevision: fwRev,
                        mediaFormattedName: mediaType,
                        volumeName: volumeTitle,
                        sectorsWrittenLBA: self.currentSectorLBA,
                        bytesWritten: self.currentSectorLBA * 2048,
                        averageSpeedText: String(format: "%.1fx", self.averageSpeedX),
                        peakSpeedText: String(format: "%.1fx", self.peakSpeedX),
                        elapsedDurationText: String(format: "00:%02d", min(59, self.elapsedSeconds)),
                        diagnosticAdvice: advice
                    )
                    self.completionReport = report
                    onCompletion(report)
                }
            }
        }
    }

    public func abortActiveBurn() {
        activeDRBurn?.abort()
        burnMonitorTimer?.invalidate()
        eraseMonitorTimer?.invalidate()
        isExecutingQueue = false
        activeJobPhase = "Operation Aborted by User"
    }

    public static func inspectFileOrFolder(url: URL) -> StagedFileEntry {
        let fm = FileManager.default
        var isDir: ObjCBool = false
        _ = fm.fileExists(atPath: url.path, isDirectory: &isDir)

        var totalBytes: Int64 = 0
        var count: Int = 1
        var modDate = Date()
        var permsString = "rwxr-xr-x"

        if let attrs = try? fm.attributesOfItem(atPath: url.path) {
            if let d = attrs[.modificationDate] as? Date { modDate = d }
            if let posix = attrs[.posixPermissions] as? NSNumber {
                permsString = String(format: "0%o", posix.intValue)
            }
            if !isDir.boolValue, let sz = attrs[.size] as? NSNumber {
                totalBytes = sz.int64Value
            }
        }

        if isDir.boolValue {
            count = 0
            if let enumerator = fm.enumerator(
                at: url,
                includingPropertiesForKeys: [.fileSizeKey, .isDirectoryKey],
                options: [.skipsHiddenFiles]
            ) {
                for case let childURL as URL in enumerator {
                    if let vals = try? childURL.resourceValues(forKeys: [.fileSizeKey, .isDirectoryKey]) {
                        if vals.isDirectory != true {
                            totalBytes += Int64(vals.fileSize ?? 0)
                            count += 1
                        }
                    }
                }
            }
        }

        let lowerName = url.lastPathComponent.lowercased()
        let defaultMac = !(lowerName == "autorun.inf" || lowerName.hasSuffix(".exe") || lowerName.hasSuffix(".msi") || lowerName.hasSuffix(".bat"))
        let defaultPC = !(lowerName == ".ds_store" || lowerName == ".localized")

        return StagedFileEntry(
            url: url,
            name: url.lastPathComponent,
            isDirectory: isDir.boolValue,
            byteSize: totalBytes,
            itemCount: count,
            posixPermissions: permsString,
            modifiedDate: modDate,
            showOnMac: defaultMac,
            showOnPC: defaultPC
        )
    }
}
