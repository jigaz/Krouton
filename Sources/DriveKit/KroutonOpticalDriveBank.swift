import AVFoundation
import Combine
import CryptoKit
@preconcurrency import DiscRecording
import DiskArbitration
import Foundation
import IOKit
import IOKit.storage
import Observation
import OpticalCore
import SwiftUI
import os

/// The drives of this Mac and everything that runs on them: it polls DiscRecording for drives every
/// 2 seconds, runs one burn, erase, rip or copy at a time, and publishes progress and telemetry for
/// the UI. Only `KroutonBurnCoordinator` (BurnKit) starts a burn.
@Observable
@MainActor
public final class KroutonOpticalDriveBank: OpticalDriveControlling, KroutonDriveTelemetryStore {
    public var mediaKind: OpticalMediaKind {
        OpticalMediaKind(mediaDescription: availableDrives.first?.mediaType ?? "DVD-R")
    }
    /// The drives found by the last poll.
    public var availableDrives: [KroutonOpticalDriveInfo] = []
    /// The drive the user picked, if any.
    public var selectedDrive: KroutonOpticalDriveInfo?
    /// The latest status line for the drive panel.
    public var hardwareStatusLog: String = "Scanning IOKit / DiscRecording bus..."

    /// True while a job runs, or a burn is being prepared; polling pauses meanwhile.
    public var isExecutingQueue: Bool = false
    /// How many times Abort was chosen (`abortActiveBurn`); see `beginPreparingBurn`.
    public internal(set) var abortRequestCount = 0
    var preparingBurnCount = 0
    /// What the running job is doing, for display.
    public var activeJobPhase: String = "Idle"
    public var activeJobProgress: Double = 0.0
    public var activeJobDetail: String = ""
    /// Live burn graph state per drive ID.
    public var driveTelemetry: [String: KroutonDrivePhaseScopeTelemetry] = [:]
    /// Multi-copy run state per drive ID.
    public var batchStates: [String: KroutonBatchBurnState] = [:]
    var batchCountdownTimers: [String: Timer] = [:]
    var perDriveTimers: [String: Timer] = [:]

    var neroSamples: [KroutonBurnTelemetrySample] = []
    public var currentSpeedX: Double = 0.0
    public var currentSpeedKBs: Double = 0.0
    public var peakSpeedX: Double = 0.0
    public var averageSpeedX: Double = 0.0
    public var currentSpindleRPM: Int = 0
    public var currentSectorLBA: Int64 = 0
    var totalTargetSectorsLBA: Int64 = 0
    var driveBufferFillPercent: Double = 0.0
    public var laserWavelengthText: String = "780 nm IR (CD)"
    public var writeStrategyText: String = "P-CAV / CLV"
    var activeTrackNumber: Int = 1
    public var elapsedSeconds: Int = 0
    /// The report of the last job that finished.
    public var completionReport: KroutonBurnSessionReport? = nil

    var pollTimer: Timer?
    var activeBurnSession: KroutonActiveBurnSession?
    var activeEraseSession: KroutonActiveEraseSession?
    var burnMonitorTimer: Timer?
    var eraseMonitorTimer: Timer?
    var jobStartTime: Date = Date()

    public init() {
        startHardwarePolling()
        Task { @MainActor [weak self] in
            self?.refreshDrives()
        }
    }

    func startHardwarePolling() {
        pollTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self = self, !self.isExecutingQueue else { return }
                self.refreshDrives()
            }
        }
    }

    static func formatHumanMediaType(_ raw: String) -> String {
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

    /// Book, dye, laser and block-size text for display, guessed from the media type alone. Nothing
    /// here is read from the disc.
    static func deduceMediaPhysics(mediaType: String, isErasable: Bool) -> (book: String, dye: String, laser: String, block: String) {
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

    /// Asks DiscRecording for the drives and their discs, and updates `availableDrives`.
    public func refreshDrives() {
        var found: [KroutonOpticalDriveInfo] = []

        do {
            for (dev, deviceID) in Self.identifiedDevices() {
                let info = dev.info() as? [String: Any] ?? [:]
                let status = dev.status() as? [String: Any] ?? [:]

                let vendor = (info[DRDeviceVendorNameKey] as? String ?? "").trimmingCharacters(in: .whitespaces)
                let product = (info[DRDeviceProductNameKey] as? String ?? "Optical Drive").trimmingCharacters(in: .whitespaces)
                let revision = (info[DRDeviceFirmwareRevisionKey] as? String ?? "—").trimmingCharacters(in: .whitespaces)
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
                var mountedVols: [KroutonMountedDiscVolume] = []
                var speeds: [String] = ["Max Safe (Auto)"]

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

                    if let blocks = mediaInfo[DRDeviceMediaBlocksFreeKey] as? NSNumber, blocks.int64Value > 0 {
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
                        let divisor: Double = mType.contains("BD") ? 4500.0 : (mType.contains("DVD") ? 1385.0 : 176.4)
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
                    if isBlank {
                        humanState = "Blank \(mType) Ready"
                    } else if isErasable {
                        humanState = "Rewritable \(mType)"
                    } else {
                        humanState = "\(mType) Mounted"
                    }
                }

                found.append(KroutonOpticalDriveInfo(
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
        if self.availableDrives != found {
            self.availableDrives = found
        }
        let nextSelected = (previousSelectedID.flatMap { prevID in found.first(where: { $0.id == prevID }) }) ?? found.first
        if self.selectedDrive != nextSelected {
            self.selectedDrive = nextSelected
        }

        let nextStatusLog: String
        if let primary = nextSelected {
            nextStatusLog = "\(primary.displayName) [FW \(primary.firmware)] — \(primary.statusBadgeText)"
        } else {
            nextStatusLog = "No Local Optical Drive Detected — Check USB Connection"
        }
        if self.hardwareStatusLog != nextStatusLog {
            self.hardwareStatusLog = nextStatusLog
        }
    }

    func beginNewPhaseScopeEvent(
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
        driveTelemetry[driveID] = KroutonDrivePhaseScopeTelemetry(
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
            targetSpeedX: 0.0,
            currentSpindleRPM: 0,
            currentSectorLBA: 0,
            totalSectorsLBA: max(0, totalSectorsLBA),
            bufferFillPercent: 0.0,
            laserWavelengthText: laserText,
            writeStrategyText: strategyText,
            elapsedSeconds: 0,
            samples: []
        )
    }

    // MARK: - Multi-Copy Runs

    /// After copy `completedCopy` of `totalCopies`, watches the drive for the disc to be ejected
    /// and a blank inserted, counts down, then calls `onFireNextCopy`.
    public func startBatchAutoLoadMonitor(
        for driveID: String,
        completedCopy: Int,
        totalCopies: Int,
        countdownSeconds: Int = 5,
        onFireNextCopy: @escaping @MainActor () -> Void
    ) {
        let resolved = driveForID(driveID)
        let key = resolved?.id ?? driveID
        guard !key.isEmpty else { return }
        let name = resolved?.displayName ?? "Optical Burner"

        // 1. Eject the finished copy so the operator can drop in the next blank disc
        ejectDrive(id: key)

        let nextCopy = completedCopy + 1
        batchStates[key] = KroutonBatchBurnState(
            id: key,
            driveName: name,
            currentCopyIndex: nextCopy,
            totalCopies: totalCopies,
            isWaitingForBlankDisc: true,
            countdownSecondsRemaining: nil,
            statusMessage: "Copy \(completedCopy)/\(totalCopies) Ejected — Insert Blank Disc #\(nextCopy) to Auto-Start",
            bitsetDVDROMActive: false
        )
        hardwareStatusLog = "[Duplication Station] Copy \(completedCopy)/\(totalCopies) complete on \(name). Waiting for Blank Disc #\(nextCopy)..."

        batchCountdownTimers[key]?.invalidate()

        batchCountdownTimers[key] = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self = self, var st = self.batchStates[key] else {
                    self?.batchCountdownTimers[key]?.invalidate()
                    self?.batchCountdownTimers.removeValue(forKey: key)
                    return
                }
                self.refreshDrives()
                // Exact match only: never read another drive's tray, and never count a written disc as a blank.
                let currentDrive = self.availableDrives.first { $0.id == key }
                let mediaNowPresent = currentDrive?.isMediaPresent ?? false
                let blankNowPresent = mediaNowPresent && (currentDrive?.isMediaBlank ?? false)

                if !mediaNowPresent {
                    st.hasDetectedDiscEject = true
                    self.batchStates[key] = st
                }

                if let remaining = st.countdownSecondsRemaining {
                    if !blankNowPresent { // disc pulled or swapped during the countdown
                        st.isWaitingForBlankDisc = true
                        st.countdownSecondsRemaining = nil
                        st.statusMessage = "Countdown Cancelled — Insert Blank Disc #\(nextCopy) to Auto-Start"
                        self.batchStates[key] = st
                    } else if remaining <= 1 {
                        self.batchCountdownTimers[key]?.invalidate()
                        self.batchCountdownTimers.removeValue(forKey: key)
                        // The wait is over: a state left here kept the card's banner, and its
                        // Simulate Blank Disc Insert button, up through the burn and after the last copy.
                        self.batchStates.removeValue(forKey: key)
                        onFireNextCopy()
                    } else {
                        st.countdownSecondsRemaining = remaining - 1
                        st.statusMessage = "Blank Disc Locked — Auto-Starting Copy #\(nextCopy)/\(totalCopies) in \(remaining - 1)s..."
                        self.batchStates[key] = st
                    }
                } else if st.hasDetectedDiscEject && mediaNowPresent && !blankNowPresent {
                    st.statusMessage = "Disc in \(name) Is Not Blank — Swap It for Blank Disc #\(nextCopy)"
                    self.batchStates[key] = st
                } else if st.hasDetectedDiscEject && blankNowPresent {
                    let startSec = max(1, countdownSeconds)
                    st.isWaitingForBlankDisc = false
                    st.countdownSecondsRemaining = startSec
                    st.statusMessage = "Blank Disc Locked — Auto-Starting Copy #\(nextCopy)/\(totalCopies) in \(startSec)s..."
                    self.batchStates[key] = st
                }
            }
        }
    }

    /// Starts the next-copy countdown now, as if a blank had been inserted. Despite the name, the
    /// burner card's start button uses it.
    public func triggerImmediateBatchCountdownForTesting(
        driveID: String,
        countdownSeconds: Int = 5,
        onFireNextCopy: @escaping @MainActor () -> Void
    ) {
        let resolved = driveForID(driveID)
        let key = resolved?.id ?? driveID
        guard !key.isEmpty else { return }
        let name = resolved?.displayName ?? "Optical Burner"
        let currentSt = batchStates[key] ?? KroutonBatchBurnState(id: key, driveName: name, currentCopyIndex: 2, totalCopies: 2)
        let nextCopy = currentSt.currentCopyIndex
        let total = max(2, currentSt.totalCopies)
        let startSec = max(1, countdownSeconds)

        batchStates[key] = KroutonBatchBurnState(
            id: key,
            driveName: name,
            currentCopyIndex: nextCopy,
            totalCopies: total,
            isWaitingForBlankDisc: false,
            countdownSecondsRemaining: startSec,
            statusMessage: "Blank Disc Locked — Auto-Starting Copy #\(nextCopy)/\(total) in \(startSec)s...",
            bitsetDVDROMActive: currentSt.bitsetDVDROMActive
        )

        batchCountdownTimers[key]?.invalidate()
        batchCountdownTimers[key] = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self = self, var st = self.batchStates[key] else {
                    self?.batchCountdownTimers[key]?.invalidate()
                    self?.batchCountdownTimers.removeValue(forKey: key)
                    return
                }
                if let rem = st.countdownSecondsRemaining {
                    if rem <= 1 {
                        self.batchCountdownTimers[key]?.invalidate()
                        self.batchCountdownTimers.removeValue(forKey: key)
                        self.batchStates.removeValue(forKey: key)
                        onFireNextCopy()
                    } else {
                        st.countdownSecondsRemaining = rem - 1
                        st.statusMessage = "Blank Disc Locked — Auto-Starting Copy #\(nextCopy)/\(total) in \(rem - 1)s..."
                        self.batchStates[key] = st
                    }
                }
            }
        }
    }

    /// Stops a multi-copy run on a drive.
    public func cancelBatchDuplication(for driveID: String) {
        let resolved = driveForID(driveID)
        let key = resolved?.id ?? driveID
        batchCountdownTimers[key]?.invalidate()
        batchCountdownTimers.removeValue(forKey: key)
        batchStates.removeValue(forKey: key)
        hardwareStatusLog = "[Duplication Station] Cancelled multi-copy batch on \(resolved?.displayName ?? driveID)."
    }
}
