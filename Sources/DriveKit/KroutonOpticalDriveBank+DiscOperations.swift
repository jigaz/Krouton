import OpticalCore
import SwiftUI
import Foundation
import Combine
@preconcurrency import DiscRecording
import IOKit
import IOKit.storage
import AVFoundation
import CryptoKit

// MARK: - KroutonOpticalDriveBank Phase Scope Sweep, Eject, Erase & Disc Image Authoring

@MainActor
extension KroutonOpticalDriveBank {
    public func telemetryForDrive(_ driveID: String) -> KroutonDrivePhaseScopeTelemetry? {
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
            driveTelemetry[driveID] = KroutonDrivePhaseScopeTelemetry(id: driveID, driveName: name, isManuallyPinnedInline: !isOpen && keepInlineVisible, isFloatingWindowOpen: isOpen)
        }
    }

    public func setManualInlinePin(for driveID: String, isPinned: Bool) {
        if var tel = driveTelemetry[driveID] {
            tel.isManuallyPinnedInline = isPinned
            driveTelemetry[driveID] = tel
        } else {
            let name = driveForID(driveID)?.displayName ?? "Optical Drive"
            driveTelemetry[driveID] = KroutonDrivePhaseScopeTelemetry(id: driveID, driveName: name, isManuallyPinnedInline: isPinned)
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

        let tel = KroutonDrivePhaseScopeTelemetry(
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

                current.samples.append(KroutonBurnTelemetrySample(
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

    public func driveForID(_ id: String) -> KroutonOpticalDriveInfo? {
        if let match = availableDrives.first(where: { $0.id == id }) {
            return match
        }
        return selectedDrive ?? availableDrives.first
    }

    /// Every connected drive paired with its identifier. Two identical drives get distinct identifiers.
    static func identifiedDevices() -> [(device: DRDevice, id: String)] {
        guard let devices = DRDevice.devices() as? [DRDevice], !devices.isEmpty else { return [] }
        var baseIDs: [String] = []
        var registryPaths: [String] = []
        for dev in devices {
            let info = dev.info() as? [String: Any] ?? [:]
            baseIDs.append(KroutonDriveIdentity.baseID(
                vendor: (info[DRDeviceVendorNameKey] as? String ?? "").trimmingCharacters(in: .whitespaces),
                product: (info[DRDeviceProductNameKey] as? String ?? "Optical Drive").trimmingCharacters(in: .whitespaces),
                firmware: (info[DRDeviceFirmwareRevisionKey] as? String ?? "1.0").trimmingCharacters(in: .whitespaces)
            ))
            registryPaths.append(info[DRDeviceIORegistryEntryPathKey] as? String ?? "")
        }
        let ids = KroutonDriveIdentity.uniqueIDs(baseIDs: baseIDs, registryPaths: registryPaths)
        return zip(devices, ids).map { (device: $0, id: $1) }
    }

    /// With no identifier: the selected drive, else the first one. With an identifier: that
    /// drive or nil. It never substitutes a different drive for one that has gone away.
    func resolveDRDevice(id: String? = nil) -> DRDevice? {
        let identified = Self.identifiedDevices()
        guard let targetID = id, !targetID.isEmpty else {
            if let selectedID = selectedDrive?.id, let match = identified.first(where: { $0.id == selectedID }) {
                return match.device
            }
            return identified.first?.device
        }
        return identified.first { $0.id == targetID }?.device
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

    public func createDiscImageFile(
        stagedFiles: [KroutonStagedFileEntry],
        volumeTitle: String,
        outputPathString: String,
        compressImage: Bool,
        enableCustomLayout: Bool,
        iconSizePx: Int
    ) async -> KroutonBurnSessionReport {
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
            // Copy off the main actor; duplicate names and missing files come back as a message.
            let items = stagedFiles.map { KroutonBurnStageItem(source: $0.url, name: $0.name) }
            if let stagingError = await KroutonBurnStager.stage(items, into: tempRoot) {
                throw KroutonDiscImageError.staging(stagingError)
            }
            activeJobProgress = 0.5

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

            let args = KroutonDiscImageArguments.make(
                outputPath: expandedPath, sourcePath: tempRoot.path, volumeTitle: volumeTitle, compress: compressImage
            )

            let status = try await Task.detached { () -> Int32 in
                let proc = Process()
                proc.executableURL = URL(fileURLWithPath: "/usr/bin/hdiutil")
                proc.arguments = args
                proc.standardInput = FileHandle.nullDevice
                proc.standardOutput = FileHandle.nullDevice
                try proc.run()
                proc.waitUntilExit()
                return proc.terminationStatus
            }.value

            Task.detached(priority: .utility) { try? FileManager.default.removeItem(at: tempRoot) }
            let secs = max(1, Int(Date().timeIntervalSince(jobStartTime)))

            if status == 0 {
                activeJobProgress = 1.0
                activeJobPhase = "Disc Image Created Successfully"
                activeJobDetail = expandedPath
                isExecutingQueue = false
                /* Acoustic cue handled by KroutonApp UI layer */
                let report = KroutonBurnSessionReport(
                    isSuccess: true,
                    title: "Disc Image Mastered Successfully",
                    summary: "Created a mountable hybrid disc image containing \(stagedFiles.count) items at \(expandedPath).",
                    driveModel: "Apple DiskImages Virtual Mastering Engine",
                    firmwareRevision: "macOS 26",
                    mediaFormattedName: isISO ? "ISO9660 / Joliet / UDF / HFS+ Hybrid" : (compressImage ? "Compressed UDZO .dmg" : "Read/Write UDRW .dmg"),
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
                let report = KroutonBurnSessionReport(
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
            Task.detached(priority: .utility) { try? FileManager.default.removeItem(at: tempRoot) }
            isExecutingQueue = false
            activeJobPhase = "Error: \(error.localizedDescription)"
            let report = KroutonBurnSessionReport(
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

}
