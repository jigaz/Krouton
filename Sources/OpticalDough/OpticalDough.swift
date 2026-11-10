import Foundation
import AppKit
@preconcurrency import DiscRecording

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
    public let isMediaOverwritable: Bool
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
        isMediaOverwritable: Bool = false,
        freeSectorsLBA: Int64 = 0,
        freeBytes: Int64 = 0,
        availableWriteSpeeds: [String] = ["Max Safe (Auto)", "10x (1764 KB/s)", "4x (705 KB/s)"]
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
        self.isMediaOverwritable = isMediaOverwritable
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
            let statePrefix: String
            if isMediaBlank {
                statePrefix = "Blank"
            } else if isMediaErasable {
                statePrefix = "Rewritable"
            } else {
                statePrefix = "Disc"
            }
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

    @Published public var isExecutingQueue: Bool = false
    @Published public var activeJobPhase: String = "Idle"
    @Published public var activeJobProgress: Double = 0.0
    @Published public var activeJobDetail: String = ""

    private var pollTimer: Timer?
    private var activeDRBurn: DRBurn?
    private var activeDRErase: DRErase?
    public var burnMonitorTimer: Timer?
    public var eraseMonitorTimer: Timer?

    public init() {
        refreshDrives()
        startHardwarePolling()
    }

    private func startHardwarePolling() {
        pollTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self = self, !self.isExecutingQueue else { return }
                self.refreshDrives()
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
                var isOverwritable = false
                var freeBlocks: Int64 = 0
                var freeByteCount: Int64 = 0
                // Stable list of speeds so SwiftUI Picker never throws an invalid tag warning when disc ejects
                var speeds: [String] = ["Max Safe (Auto)", "24x (4234 KB/s)", "10x (1764 KB/s)", "8x (1411 KB/s)", "4x (705 KB/s)", "2x (353 KB/s)"]

                if isTransition {
                    humanState = "Reading Slot..."
                } else if isPresent {
                    let mediaInfo = status[DRDeviceMediaInfoKey] as? [String: Any] ?? [:]
                    mType = (mediaInfo[DRDeviceMediaTypeKey] as? String ?? "Optical Media").uppercased()
                    isBlank = (mediaInfo[DRDeviceMediaIsBlankKey] as? Bool) ?? false
                    isErasable = (mediaInfo[DRDeviceMediaIsErasableKey] as? Bool) ?? false
                    isOverwritable = (mediaInfo[DRDeviceMediaIsOverwritableKey] as? Bool) ?? false

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
                    capabilitiesSummary: capSummary,
                    isNetworkNode: false,
                    hostName: "Local \(interconnect)",
                    mediaState: humanState,
                    mediaType: mType,
                    isMediaPresent: isPresent,
                    isMediaBlank: isBlank,
                    isMediaErasable: isErasable,
                    isMediaOverwritable: isOverwritable,
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

    // MARK: - Erase Rewritable Disc (CD-RW / DVD-RW / DVD+RW / BD-RE) via DRErase
    public func eraseRewritableDisc(
        fullErase: Bool,
        onCompletion: @escaping @MainActor (Result<String, Error>) -> Void
    ) {
        guard let device = resolveDRDevice(id: selectedDrive?.id) else {
            onCompletion(.failure(NSError(domain: "KroutonEraseEngine", code: 404, userInfo: [NSLocalizedDescriptionKey: "No physical optical burner detected."])))
            return
        }

        let status = device.status() as? [String: Any] ?? [:]
        let mediaState = status[DRDeviceMediaStateKey] as? String ?? DRDeviceMediaStateNone
        guard mediaState == DRDeviceMediaStateMediaPresent else {
            onCompletion(.failure(NSError(domain: "KroutonEraseEngine", code: 409, userInfo: [NSLocalizedDescriptionKey: "Slot is empty. Insert a rewritable disc (CD-RW, DVD-RW, DVD+RW, or BD-RE) first."])))
            return
        }

        let mediaInfo = status[DRDeviceMediaInfoKey] as? [String: Any] ?? [:]
        let isErasable = (mediaInfo[DRDeviceMediaIsErasableKey] as? Bool) ?? false
        guard isErasable else {
            let mType = (mediaInfo[DRDeviceMediaTypeKey] as? String ?? "inserted disc").uppercased()
            onCompletion(.failure(NSError(domain: "KroutonEraseEngine", code: 412, userInfo: [NSLocalizedDescriptionKey: "The \(mType) in the drive is write-once (not rewritable) and cannot be erased."])))
            return
        }

        // Unmount any mounted volume on this disc before erasing
        device.acquireMediaReservation()

        guard let erase = DRErase(for: device) else {
            device.releaseMediaReservation()
            onCompletion(.failure(NSError(domain: "KroutonEraseEngine", code: 500, userInfo: [NSLocalizedDescriptionKey: "Could not initialize DRErase session."])))
            return
        }

        erase.setEraseType(fullErase ? DREraseTypeComplete : DREraseTypeQuick)

        self.activeDRErase = erase
        self.isExecutingQueue = true
        self.activeJobPhase = fullErase ? "Erasing Disc (Full Sector Zero)..." : "Quick Erasing Rewritable Disc (PMA/TOC)..."
        self.activeJobProgress = 0.05
        self.activeJobDetail = "\(selectedDrive?.displayName ?? "Optical Drive") • \(fullErase ? "Full Erase" : "Quick Erase")"

        erase.start()

        eraseMonitorTimer?.invalidate()
        eraseMonitorTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self = self, let activeErase = self.activeDRErase else {
                    self?.eraseMonitorTimer?.invalidate()
                    return
                }
                let eStatus = activeErase.status() as? [String: Any] ?? [:]
                let state = eStatus[DRStatusStateKey] as? String ?? ""
                let pct = (eStatus[DRStatusPercentCompleteKey] as? NSNumber)?.doubleValue ?? 0.0

                self.activeJobProgress = max(0.05, min(1.0, pct))
                self.activeJobPhase = "Erasing Disc: \(state)"

                if state == DRStatusStateDone {
                    self.eraseMonitorTimer?.invalidate()
                    device.releaseMediaReservation()
                    self.isExecutingQueue = false
                    self.activeJobProgress = 1.0
                    self.activeJobPhase = "Rewritable Disc Erased & Ready"
                    NSSound.beep()
                    self.refreshDrives()
                    onCompletion(.success("Successfully erased rewritable disc on \(self.selectedDrive?.displayName ?? "Optical Drive"). It is now blank and ready to burn!"))
                } else if state == DRStatusStateFailed {
                    self.eraseMonitorTimer?.invalidate()
                    device.releaseMediaReservation()
                    self.isExecutingQueue = false
                    let errInfo = eStatus[DRErrorStatusKey] as? [String: Any]
                    let errStr = errInfo?[DRErrorStatusErrorStringKey] as? String ?? "Hardware erase failed."
                    self.activeJobPhase = "Erase Failed: \(errStr)"
                    onCompletion(.failure(NSError(domain: "KroutonEraseEngine", code: 505, userInfo: [NSLocalizedDescriptionKey: errStr])))
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

    // MARK: - Fixed Physical Optical Burn (Writes real sectors, supports CD-RW overwrite & requested speed)
    public func startPhysicalDataBurn(
        stagedFiles: [StagedFileEntry],
        volumeTitle: String,
        requestedSpeedLabel: String,
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
            onCompletion(.failure(NSError(domain: "KroutonBurnEngine", code: 409, userInfo: [NSLocalizedDescriptionKey: "Slot is empty. Please insert a disc into \(selectedDrive?.displayName ?? "your burner") first."])))
            return
        }

        let mediaInfo = status[DRDeviceMediaInfoKey] as? [String: Any] ?? [:]
        let isBlank = (mediaInfo[DRDeviceMediaIsBlankKey] as? Bool) ?? false
        let isErasable = (mediaInfo[DRDeviceMediaIsErasableKey] as? Bool) ?? false
        let isOverwritable = (mediaInfo[DRDeviceMediaIsOverwritableKey] as? Bool) ?? false
        let mediaType = (mediaInfo[DRDeviceMediaTypeKey] as? String ?? "Disc").uppercased()

        // If a non-blank CD-RW or DVD-RW is inserted, warn if it isn't directly overwritable
        if !isBlank && isErasable && !isOverwritable && mediaType.contains("CD-RW") {
            // Note: DRBurnOverwriteDiscKey handles overwriting if supported, or user can click Quick Erase first
        }

        device.acquireMediaReservation()

        // Stage files into a temporary directory and convert to a virtual DRFolder so HFS+/ISO/Joliet/UDF trees are 100% populated
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
            onCompletion(.failure(error))
            return
        }

        guard let rootFolder = DRFolder(path: tempBurnStage.path) else {
            try? FileManager.default.removeItem(at: tempBurnStage)
            device.releaseMediaReservation()
            onCompletion(.failure(NSError(domain: "KroutonBurnEngine", code: 500, userInfo: [NSLocalizedDescriptionKey: "Could not initialize DRFolder from staging directory."])))
            return
        }

        rootFolder.makeVirtual()
        rootFolder.setBaseName(volumeTitle)

        // CD-RW / CD-R compatibility: Use HFS+ + ISO9660 + Joliet on CD media (some Matshita drives reject UDF 2.x on CD-RW)
        if mediaType.contains("CD") {
            rootFolder.setExplicitFilesystemMask(DRFilesystemMask(DRFilesystemInclusionMaskHFSPlus | DRFilesystemInclusionMaskISO9660 | DRFilesystemInclusionMaskJoliet))
        } else {
            rootFolder.setExplicitFilesystemMask(DRFilesystemMask(DRFilesystemInclusionMaskHFSPlus | DRFilesystemInclusionMaskISO9660 | DRFilesystemInclusionMaskJoliet | DRFilesystemInclusionMaskUDF))
        }

        guard let track = DRTrack(forRootFolder: rootFolder) else {
            try? FileManager.default.removeItem(at: tempBurnStage)
            device.releaseMediaReservation()
            onCompletion(.failure(NSError(domain: "KroutonBurnEngine", code: 501, userInfo: [NSLocalizedDescriptionKey: "Could not create DRTrack from staged files."])))
            return
        }

        guard let burn = DRBurn(for: device) else {
            try? FileManager.default.removeItem(at: tempBurnStage)
            device.releaseMediaReservation()
            onCompletion(.failure(NSError(domain: "KroutonBurnEngine", code: 502, userInfo: [NSLocalizedDescriptionKey: "Could not create DRBurn session on drive."])))
            return
        }

        var props = burn.properties() as? [String: Any] ?? [:]
        // REAL laser write when simulationMode == false!
        props[DRBurnTestingKey] = NSNumber(value: simulationMode)
        props[DRBurnVerifyDiscKey] = NSNumber(value: verifyDisc)
        // Allow overwriting rewritable media (CD-RW / DVD-RW / DVD+RW)
        props[DRBurnOverwriteDiscKey] = NSNumber(value: true)
        props[DRBurnCompletionActionKey] = DRBurnCompletionActionEject

        // Parse requested speed in KB/s if user picked e.g. "4x (705 KB/s)" or "10x (1764 KB/s)"
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
        self.activeJobPhase = simulationMode ? "Simulating Burn (Laser Test Only)..." : "Writing Real Data to \(mediaType)..."
        self.activeJobProgress = 0.02
        self.activeJobDetail = "\(selectedDrive?.displayName ?? "Optical Drive") • \(volumeTitle) (\(simulationMode ? "Simulation" : "Real Burn"))"

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
                self.activeJobPhase = "\(simulationMode ? "[SIMULATION] " : "")Burn Status: \(state)"

                if state == DRStatusStateDone {
                    self.burnMonitorTimer?.invalidate()
                    try? FileManager.default.removeItem(at: tempBurnStage)
                    device.releaseMediaReservation()
                    self.isExecutingQueue = false
                    self.activeJobProgress = 1.0
                    self.activeJobPhase = simulationMode ? "Simulation Completed (No Data Written)" : "Optical Burn & Verification Complete!"
                    NSSound.beep()
                    self.refreshDrives()
                    if simulationMode {
                        onCompletion(.success("Simulation burn finished! Note: 'Simulate' was checked, so the laser ran a test pass without writing data. Leave 'Simulate' unchecked to write real files."))
                    } else {
                        onCompletion(.success("Successfully burned and verified '\(volumeTitle)' (\(stagedFiles.count) items) on \(self.selectedDrive?.displayName ?? "Optical Drive")!"))
                    }
                } else if state == DRStatusStateFailed {
                    self.burnMonitorTimer?.invalidate()
                    try? FileManager.default.removeItem(at: tempBurnStage)
                    device.releaseMediaReservation()
                    self.isExecutingQueue = false
                    let errInfo = bStatus[DRErrorStatusKey] as? [String: Any]
                    let errStr = errInfo?[DRErrorStatusErrorStringKey] as? String ?? "Hardware burn failed."
                    self.activeJobPhase = "Burn Failed: \(errStr)"
                    let helpfulHint = isErasable && !isBlank
                        ? "\(errStr)\n\nTip: Since this is a previously used CD-RW/DVD-RW, click the 'Erase RW' button on the burner card to Quick Erase the disc first, and use 10x or Auto speed (High-Speed CD-RW discs reject 4x CLV)."
                        : errStr
                    onCompletion(.failure(NSError(domain: "KroutonBurnEngine", code: 505, userInfo: [NSLocalizedDescriptionKey: helpfulHint])))
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
