import Foundation
import AppKit
import DiscRecording

public struct OpticalDriveDevice: Identifiable, Hashable, Sendable {
    public let id: String
    public let vendor: String
    public let product: String
    public let firmware: String
    public let interconnect: String
    public let capabilitiesSummary: String
    public let isNetworkNode: Bool
    public let hostName: String
    public let mediaState: String
    public let mediaType: String
    public let isMediaPresent: Bool
    public let isMediaBlank: Bool
    public let isMediaErasable: Bool
    public let freeSectorsLBA: Int64
    public let freeBytes: Int64
    public let availableWriteSpeeds: [String]

    public init(
        id: String,
        vendor: String,
        product: String,
        firmware: String,
        interconnect: String = "USB",
        capabilitiesSummary: String = "DVD±R DL • CD-R/RW • CD-TEXT",
        isNetworkNode: Bool = false,
        hostName: String = "Local Mac",
        mediaState: String = "Slot Empty",
        mediaType: String = "No Disc",
        isMediaPresent: Bool = false,
        isMediaBlank: Bool = false,
        isMediaErasable: Bool = false,
        freeSectorsLBA: Int64 = 0,
        freeBytes: Int64 = 0,
        availableWriteSpeeds: [String] = ["Max Safe", "8x CAV", "4x CLV"]
    ) {
        self.id = id
        self.vendor = vendor
        self.product = product
        self.firmware = firmware
        self.interconnect = interconnect
        self.capabilitiesSummary = capabilitiesSummary
        self.isNetworkNode = isNetworkNode
        self.hostName = hostName
        self.mediaState = mediaState
        self.mediaType = mediaType
        self.isMediaPresent = isMediaPresent
        self.isMediaBlank = isMediaBlank
        self.isMediaErasable = isMediaErasable
        self.freeSectorsLBA = freeSectorsLBA
        self.freeBytes = freeBytes
        self.availableWriteSpeeds = availableWriteSpeeds
    }

    public var displayName: String {
        isNetworkNode ? "\(vendor) \(product) (\(hostName))" : "\(vendor) \(product)"
    }

    public var statusBadgeText: String {
        if isMediaPresent {
            let gb = Double(freeBytes) / 1_000_000_000.0
            let statePrefix = isMediaBlank ? "Blank" : "Disc"
            if gb >= 0.9 {
                return String(format: "%@ %@ (%.2f GB)", statePrefix, mediaType, gb)
            } else if freeBytes > 0 {
                let mb = Double(freeBytes) / 1_000_000.0
                return String(format: "%@ %@ (%.0f MB)", statePrefix, mediaType, mb)
            }
            return "\(statePrefix): \(mediaType)"
        }
        return mediaState
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

    public init(
        id: UUID = UUID(),
        url: URL,
        name: String,
        isDirectory: Bool,
        byteSize: Int64,
        itemCount: Int,
        posixPermissions: String,
        modifiedDate: Date
    ) {
        self.id = id
        self.url = url
        self.name = name
        self.isDirectory = isDirectory
        self.byteSize = byteSize
        self.itemCount = itemCount
        self.posixPermissions = posixPermissions
        self.modifiedDate = modifiedDate
    }

    public var sectorsLBA: Int64 {
        max(1, (byteSize + 2047) / 2048)
    }
}

@MainActor
public final class DriveManager: ObservableObject {
    @Published public var availableDrives: [OpticalDriveDevice] = []
    @Published public var selectedDrive: OpticalDriveDevice?
    @Published public var hardwareStatusLog: String = "Scanning IOKit / DiscRecording bus..."

    // Sprint 2 Live Burn & Image Mastering Telemetry
    @Published public var isExecutingQueue: Bool = false
    @Published public var activeJobPhase: String = "Idle"
    @Published public var activeJobProgress: Double = 0.0
    @Published public var activeJobDetail: String = ""

    private var pollTimer: Timer?
    private var activeDRBurn: DRBurn?
    private var burnMonitorTimer: Timer?

    public init() {
        refreshDrives()
        startHardwarePolling()
    }

    private func startHardwarePolling() {
        pollTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.refreshDrives()
            }
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
                var isBlank = false
                var isErasable = false
                var freeBlocks: Int64 = 0
                var freeByteCount: Int64 = 0
                var speeds: [String] = ["Max Safe (Auto)", "8x CAV", "4x CLV", "2x Mastering"]

                if isTransition {
                    humanState = "Reading Slot..."
                } else if isPresent {
                    let mediaInfo = status[DRDeviceMediaInfoKey] as? [String: Any] ?? [:]
                    mType = (mediaInfo[DRDeviceMediaTypeKey] as? String ?? "Optical Media").uppercased()
                    isBlank = (mediaInfo[DRDeviceMediaIsBlankKey] as? Bool) ?? false
                    isErasable = (mediaInfo[DRDeviceMediaIsErasableKey] as? Bool) ?? false

                    if let blocks = mediaInfo[DRDeviceMediaFreeSpaceKey] as? NSNumber {
                        freeBlocks = blocks.int64Value
                        freeByteCount = freeBlocks * 2048
                    } else if let totalBlocks = mediaInfo[DRDeviceMediaBlocksOverwritableKey] as? NSNumber, totalBlocks.int64Value > 0 {
                        freeBlocks = totalBlocks.int64Value
                        freeByteCount = freeBlocks * 2048
                    } else if isBlank {
                        if mType.contains("DVD") {
                            freeBlocks = 2_295_104
                            freeByteCount = 4_700_372_992
                        } else {
                            freeBlocks = 359_847
                            freeByteCount = 736_966_656
                        }
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
                        speeds = parsedSpeeds
                    }
                    humanState = isBlank ? "Blank \(mType) Ready" : "\(mType) Mounted"
                }

                let deviceID = "\(vendor)-\(product)-\(revision)"
                found.append(OpticalDriveDevice(
                    id: deviceID,
                    vendor: vendor,
                    product: product,
                    firmware: revision,
                    interconnect: interconnect,
                    capabilitiesSummary: capSummary,
                    isNetworkNode: false,
                    hostName: "Local \(interconnect)",
                    mediaState: humanState,
                    mediaType: mType,
                    isMediaPresent: isPresent,
                    isMediaBlank: isBlank,
                    isMediaErasable: isErasable,
                    freeSectorsLBA: freeBlocks,
                    freeBytes: freeByteCount,
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

    private func resolveDRDevice(id: String? = nil) -> DRDevice? {
        guard let devices = DRDevice.devices() as? [DRDevice], !devices.isEmpty else { return nil }
        return devices.first { dev in
            guard let targetID = id else { return true }
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
        let didEject = targetDevice.ejectMedia()
        if !didEject {
            _ = targetDevice.openTray()
        }
        hardwareStatusLog = "Sent Eject command to \(selectedDrive?.displayName ?? "Optical Drive")"
        refreshDrives()
    }

    // MARK: - Sprint 2: Real Data Disc Image Creation (.dmg / .iso) & Physical DRBurn
    public func createDiscImageFile(
        stagedFiles: [StagedFileEntry],
        volumeTitle: String,
        outputPathString: String,
        compressImage: Bool,
        enableCustomLayout: Bool,
        iconSizePx: Int
    ) async -> Result<String, Error> {
        isExecutingQueue = true
        activeJobPhase = "Staging Hybrid Volume Tree..."
        activeJobProgress = 0.15
        activeJobDetail = "Preparing \(stagedFiles.count) items for \(volumeTitle)"

        let fm = FileManager.default
        let tempRoot = fm.temporaryDirectory.appendingPathComponent("KroutonStage_\(UUID().uuidString)")

        do {
            try fm.createDirectory(at: tempRoot, withIntermediateDirectories: true)

            for (index, item) in stagedFiles.enumerated() {
                let destURL = tempRoot.appendingPathComponent(item.name)
                try fm.copyItem(at: item.url, to: destURL)
                activeJobProgress = 0.15 + (0.35 * Double(index + 1) / Double(max(1, stagedFiles.count)))
            }

            // Synthesize Windows Explorer desktop.ini / autorun.inf & Finder metadata if Custom View enabled
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
            activeJobProgress = 0.60
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

            if status == 0 {
                activeJobProgress = 1.0
                activeJobPhase = "Disc Image Created Successfully"
                activeJobDetail = expandedPath
                isExecutingQueue = false
                NSSound.beep()
                return .success(expandedPath)
            } else {
                isExecutingQueue = false
                let err = NSError(domain: "KroutonBurnEngine", code: Int(status), userInfo: [NSLocalizedDescriptionKey: "hdiutil exited with code \(status)"])
                activeJobPhase = "Image Creation Failed (Code \(status))"
                return .failure(err)
            }
        } catch {
            try? fm.removeItem(at: tempRoot)
            isExecutingQueue = false
            activeJobPhase = "Error: \(error.localizedDescription)"
            return .failure(error)
        }
    }

    public func startPhysicalDataBurn(
        stagedFiles: [StagedFileEntry],
        volumeTitle: String,
        simulationMode: Bool,
        verifyDisc: Bool,
        onCompletion: @escaping @MainActor (Result<String, Error>) -> Void
    ) {
        guard let device = resolveDRDevice(id: selectedDrive?.id) else {
            onCompletion(.failure(NSError(domain: "KroutonBurnEngine", code: 404, userInfo: [NSLocalizedDescriptionKey: "No physical optical burner detected."])))
            return
        }

        let status = device.status() as? [String: Any] ?? [:]
        let mediaState = status[DRDeviceMediaStateKey] as? String ?? DRDeviceMediaStateNone
        guard mediaState == DRDeviceMediaStateMediaPresent else {
            onCompletion(.failure(NSError(domain: "KroutonBurnEngine", code: 409, userInfo: [NSLocalizedDescriptionKey: "Slot is empty. Please insert a blank CD or DVD into \(selectedDrive?.displayName ?? "your burner") first."])))
            return
        }

        // Build virtual DRFolder containing all staged files/folders
        guard let rootFolder = DRFolder.virtualFolder(withName: volumeTitle) else {
            onCompletion(.failure(NSError(domain: "KroutonBurnEngine", code: 500, userInfo: [NSLocalizedDescriptionKey: "Could not initialize DRFolder root."])))
            return
        }
        rootFolder.setExplicitFilesystemMask(DRFilesystemMask(DRFilesystemInclusionMaskHFSPlus | DRFilesystemInclusionMaskISO9660 | DRFilesystemInclusionMaskJoliet | DRFilesystemInclusionMaskUDF))

        for entry in stagedFiles {
            if entry.isDirectory {
                if let subFolder = DRFolder(path: entry.url.path) {
                    rootFolder.addChild(subFolder)
                }
            } else {
                if let fileObj = DRFile(path: entry.url.path) {
                    rootFolder.addChild(fileObj)
                }
            }
        }

        guard let track = DRTrack(forRootFolder: rootFolder) else {
            onCompletion(.failure(NSError(domain: "KroutonBurnEngine", code: 501, userInfo: [NSLocalizedDescriptionKey: "Could not create DRTrack from staged files."])))
            return
        }

        guard let burn = DRBurn(for: device) else {
            onCompletion(.failure(NSError(domain: "KroutonBurnEngine", code: 502, userInfo: [NSLocalizedDescriptionKey: "Could not create DRBurn session on drive."])))
            return
        }

        var props = burn.properties() as? [String: Any] ?? [:]
        props[DRBurnTestingKey] = NSNumber(value: simulationMode)
        props[DRBurnVerifyDiscKey] = NSNumber(value: verifyDisc)
        burn.setProperties(props)

        self.activeDRBurn = burn
        self.isExecutingQueue = true
        self.activeJobPhase = simulationMode ? "Igniting Laser (Simulation Mode)..." : "Igniting Laser (Writing Track)..."
        self.activeJobProgress = 0.02
        self.activeJobDetail = "\(selectedDrive?.displayName ?? "Optical Drive") • \(volumeTitle)"

        burn.writeLayout(track)

        burnMonitorTimer?.invalidate()
        burnMonitorTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self = self, let activeBurn = self.activeDRBurn else {
                    self?.burnMonitorTimer?.invalidate()
                    return
                }
                let bStatus = activeBurn.status() as? [String: Any] ?? [:]
                let state = bStatus[DRStatusStateKey] as? String ?? ""
                let pct = (bStatus[DRStatusPercentCompleteKey] as? NSNumber)?.doubleValue ?? 0.0

                self.activeJobProgress = max(0.02, min(1.0, pct))
                self.activeJobPhase = "Burn Status: \(state)"

                if state == DRStatusStateDone {
                    self.burnMonitorTimer?.invalidate()
                    self.isExecutingQueue = false
                    self.activeJobProgress = 1.0
                    self.activeJobPhase = simulationMode ? "Simulation Burn Completed Successfully" : "Optical Burn & Verification Complete"
                    NSSound.beep()
                    onCompletion(.success("Burn finished on \(self.selectedDrive?.displayName ?? "Optical Drive")"))
                } else if state == DRStatusStateFailed {
                    self.burnMonitorTimer?.invalidate()
                    self.isExecutingQueue = false
                    let errInfo = bStatus[DRErrorStatusKey] as? [String: Any]
                    let errStr = errInfo?[DRErrorStatusErrorStringKey] as? String ?? "Hardware burn failed."
                    self.activeJobPhase = "Burn Failed: \(errStr)"
                    onCompletion(.failure(NSError(domain: "KroutonBurnEngine", code: 505, userInfo: [NSLocalizedDescriptionKey: errStr])))
                }
            }
        }
    }

    public func abortActiveBurn() {
        activeDRBurn?.abort()
        burnMonitorTimer?.invalidate()
        isExecutingQueue = false
        activeJobPhase = "Burn Aborted by User"
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

        return StagedFileEntry(
            url: url,
            name: url.lastPathComponent,
            isDirectory: isDir.boolValue,
            byteSize: totalBytes,
            itemCount: count,
            posixPermissions: permsString,
            modifiedDate: modDate
        )
    }
}
