import OpticalCore
import Foundation
@preconcurrency import DiscRecording

// MARK: - Rewritable disc erase lifecycle
//
// Same shape as the burn lifecycle: one session object owns the media reservation and
// the completion handler, and `finishEraseSession` is the only exit, so the reservation
// is always released and the completion handler is called exactly once.
//
// DiscRecording has no way to stop an erase once it has started. `abortActiveBurn`
// therefore leaves a running erase alone and says so, instead of marking the drive idle
// while it is still erasing.

@MainActor
final class KroutonActiveEraseSession {
    let erase: DRErase
    let device: DRDevice
    let driveKey: String
    let driveName: String
    let firmware: String
    let mediaType: String
    let fullErase: Bool
    var completion: (@MainActor (KroutonBurnSessionReport) -> Void)?

    init(
        erase: DRErase,
        device: DRDevice,
        driveKey: String,
        driveName: String,
        firmware: String,
        mediaType: String,
        fullErase: Bool,
        completion: @escaping @MainActor (KroutonBurnSessionReport) -> Void
    ) {
        self.erase = erase
        self.device = device
        self.driveKey = driveKey
        self.driveName = driveName
        self.firmware = firmware
        self.mediaType = mediaType
        self.fullErase = fullErase
        self.completion = completion
    }

    var operationName: String { fullErase ? "Full Sector Erase" : "Quick TOC Erase" }
}

@MainActor
extension KroutonOpticalDriveBank {
    /// Erases the rewritable disc in a drive. `onCompletion` is always called exactly once.
    public func eraseRewritableDisc(
        driveID: String? = nil,
        fullErase: Bool,
        onCompletion: @escaping @MainActor (KroutonBurnSessionReport) -> Void
    ) {
        let requestedID = driveID ?? selectedDrive?.id
        let resolvedMeta = driveForID(requestedID ?? "")
        let driveName = resolvedMeta?.displayName ?? "Optical Drive"
        let fwRev = resolvedMeta?.firmware ?? "1.0"

        func refuse(title: String, summary: String, media: String, advice: String) {
            let report = KroutonBurnSessionReport(
                isSuccess: false, title: title, summary: summary, driveModel: driveName, firmwareRevision: fwRev,
                mediaFormattedName: media, volumeName: "Erase Operation", sectorsWrittenLBA: 0, bytesWritten: 0,
                averageSpeedText: "—", peakSpeedText: "—", elapsedDurationText: "00:00", diagnosticAdvice: advice
            )
            completionReport = report
            onCompletion(report)
        }

        guard activeBurnSession == nil, activeEraseSession == nil else {
            refuse(title: "Optical Drive Busy", summary: "A burn or erase is still running.", media: "—",
                   advice: "Wait for the current operation to finish before erasing a disc.")
            return
        }
        guard let device = resolveDRDevice(id: requestedID) else {
            refuse(title: "Optical Drive Not Found",
                   summary: "Krouton could not communicate with the selected optical burner on the USB/SATA bus.", media: "None",
                   advice: "Verify that your USB optical drive has sufficient bus power and is visible in Burners & Network settings.")
            return
        }
        let status = device.status() as? [String: Any] ?? [:]
        guard (status[DRDeviceMediaStateKey] as? String ?? DRDeviceMediaStateNone) == DRDeviceMediaStateMediaPresent else {
            refuse(title: "Drive Slot Is Empty", summary: "There is currently no optical disc inserted in \(driveName).", media: "Slot Empty",
                   advice: "Insert a rewritable disc (CD-RW, DVD-RW, DVD+RW, or BD-RE) and wait a few seconds for the drive to read the Table of Contents.")
            return
        }
        let mediaInfo = status[DRDeviceMediaInfoKey] as? [String: Any] ?? [:]
        let mType = Self.formatHumanMediaType(mediaInfo[DRDeviceMediaTypeKey] as? String ?? "Disc")
        guard (mediaInfo[DRDeviceMediaIsErasableKey] as? Bool) ?? false else {
            refuse(title: "Disc Is Not Rewritable", summary: "The inserted \(mType) media is write-once and cannot be erased.", media: mType,
                   advice: "Only phase-change rewritable media (CD-RW, DVD-RW, DVD+RW, DVD-RAM, and BD-RE) support optical erasure.")
            return
        }
        guard let erase = DRErase(for: device) else {
            refuse(title: "Could Not Start Erase", summary: "DiscRecording could not create an erase for \(driveName).", media: mType,
                   advice: "Nothing was erased. Try again; if it repeats, reconnect the drive.")
            return
        }

        device.acquireMediaReservation()
        erase.setEraseType(fullErase ? DREraseTypeComplete : DREraseTypeQuick)
        let session = KroutonActiveEraseSession(
            erase: erase, device: device, driveKey: resolvedMeta?.id ?? (driveID ?? ""), driveName: driveName,
            firmware: fwRev, mediaType: mType, fullErase: fullErase, completion: onCompletion
        )
        activeEraseSession = session
        isExecutingQueue = true
        jobStartTime = Date()
        elapsedSeconds = 0
        neroSamples = []

        let laserText = mType.contains("BD") ? "405 nm Violet (BD-RE)" : (mType.contains("DVD") ? "650 nm Red (DVD-RW)" : "780 nm IR (CD-RW)")
        let strategyText = fullErase ? "Full Zero CLV" : "Quick PMA/TOC Blank"
        beginNewPhaseScopeEvent(
            for: session.driveKey,
            driveName: driveName,
            eventTitle: fullErase ? "Event: Full Sector Erase" : "Event: Quick TOC Erase",
            totalSectorsLBA: resolvedMeta?.freeSectorsLBA ?? 0,
            laserText: laserText,
            strategyText: strategyText
        )
        peakSpeedX = 0.0
        averageSpeedX = 0.0
        laserWavelengthText = laserText
        writeStrategyText = strategyText
        activeJobPhase = fullErase ? "Erasing All Sectors on \(mType)..." : "Quick Erasing \(mType) Table of Contents..."
        activeJobProgress = 0.04
        activeJobDetail = "\(driveName) • \(session.operationName)"

        erase.start()

        // Runs synchronously on the main actor; see the burn monitor for why there is no Task hop.
        eraseMonitorTimer?.invalidate()
        eraseMonitorTimer = Timer.scheduledTimer(withTimeInterval: 0.4, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.pollActiveErase()
            }
        }
    }

    private func pollActiveErase() {
        guard let session = activeEraseSession else {
            eraseMonitorTimer?.invalidate()
            eraseMonitorTimer = nil
            return
        }
        let eStatus = session.erase.status() as? [String: Any] ?? [:]
        let rawState = eStatus[DRStatusStateKey] as? String ?? ""
        let pct = (eStatus[DRStatusPercentCompleteKey] as? NSNumber)?.doubleValue ?? 0.0
        let clampedPct = max(0.04, min(1.0, pct))

        activeJobProgress = clampedPct
        activeJobPhase = Self.formatHumanBurnState(rawState, isErase: true)
        elapsedSeconds = max(1, Int(Date().timeIntervalSince(jobStartTime)))
        updateEraseScope(session, fraction: clampedPct, rawState: rawState)

        if rawState == DRStatusStateDone {
            activeJobProgress = 1.0
            activeJobPhase = "Rewritable Disc Erased & Ready"
            finishEraseSession(session, report: makeEraseReport(
                session,
                isSuccess: true,
                title: "Rewritable Disc Erased Successfully",
                summary: "The \(session.mediaType) in \(session.driveName) has been blanked and is ready for a new mastering session.",
                media: "Blank \(session.mediaType)",
                advice: "All previous session pointers have been cleared. You can now burn a new Data, Audio, or Video layout."
            ))
        } else if rawState == DRStatusStateFailed {
            let errInfo = eStatus[DRErrorStatusKey] as? [String: Any]
            let errStr = errInfo?[DRErrorStatusErrorStringKey] as? String ?? "Hardware erase failed."
            let senseStr = errInfo?[DRErrorStatusAdditionalSenseStringKey] as? String ?? ""
            activeJobPhase = "Erase Failed on \(session.driveName)"
            finishEraseSession(session, report: makeEraseReport(
                session,
                isSuccess: false,
                title: "Unable to Erase Rewritable Disc",
                summary: "\(errStr)\(senseStr.isEmpty ? "" : " (\(senseStr))")",
                media: session.mediaType,
                advice: Self.eraseFailureAdvice(driveName: session.driveName)
            ))
        }
    }

    private static func eraseFailureAdvice(driveName: String) -> String {
        if driveName.uppercased().contains("UJ-898") || driveName.uppercased().contains("MATSHITA") {
            return "Hardware Note: Vintage slot-load Matshita UJ-898 SuperDrives often reject older Low-Speed (1x–4x) or Ultra-Speed (16x–24x) CD-RW phase-change dye calibration, whereas Pioneer DVRTD08 and newer Matshita UJ265 drives support wider OPC tables. Use your Pioneer DVRTD08 or Matshita UJ265 for this CD-RW disc."
        }
        return "Try running a Full Erase instead of Quick Erase, or test the disc in another optical drive."
    }

    /// DiscRecording reports erase progress only. The Phase Scope gets that fraction and the
    /// elapsed time; speed and spindle figures are left at zero instead of being estimated.
    private func updateEraseScope(_ session: KroutonActiveEraseSession, fraction: Double, rawState: String) {
        currentSpeedX = 0.0
        currentSpeedKBs = 0.0
        currentSpindleRPM = 0
        currentSectorLBA = Int64(Double(totalTargetSectorsLBA) * fraction)
        guard !session.driveKey.isEmpty else { return }
        var dTel = driveTelemetry[session.driveKey] ?? KroutonDrivePhaseScopeTelemetry(id: session.driveKey, driveName: session.driveName)
        dTel.isActive = (rawState != DRStatusStateDone && rawState != DRStatusStateFailed)
        dTel.phaseTitle = activeJobPhase
        dTel.progressFraction = fraction
        dTel.currentSpeedX = 0.0
        dTel.currentSpeedKBs = 0.0
        dTel.currentSpindleRPM = 0
        dTel.currentSectorLBA = currentSectorLBA
        dTel.totalSectorsLBA = totalTargetSectorsLBA
        dTel.laserWavelengthText = laserWavelengthText
        dTel.writeStrategyText = writeStrategyText
        dTel.elapsedSeconds = elapsedSeconds
        dTel.appendMonotonicSample(rawFraction: fraction, speedX: 0.0, rpm: 0, kbs: 0.0)
        driveTelemetry[session.driveKey] = dTel
    }

    /// The single exit for every erase. Only the first call for a session acts.
    private func finishEraseSession(_ session: KroutonActiveEraseSession, report: KroutonBurnSessionReport) {
        guard activeEraseSession === session else { return }
        activeEraseSession = nil
        eraseMonitorTimer?.invalidate()
        eraseMonitorTimer = nil
        session.device.releaseMediaReservation()
        isExecutingQueue = false
        if var dTel = driveTelemetry[session.driveKey] {
            dTel.isActive = false
            driveTelemetry[session.driveKey] = dTel
        }
        completionReport = report
        refreshDrives()

        let completion = session.completion
        session.completion = nil
        completion?(report)
    }

    private func makeEraseReport(
        _ session: KroutonActiveEraseSession,
        isSuccess: Bool,
        title: String,
        summary: String,
        media: String,
        advice: String
    ) -> KroutonBurnSessionReport {
        let elapsed = max(0, Int(Date().timeIntervalSince(jobStartTime)))
        return KroutonBurnSessionReport(
            isSuccess: isSuccess,
            title: title,
            summary: summary,
            driveModel: session.driveName,
            firmwareRevision: session.firmware,
            mediaFormattedName: media,
            volumeName: session.operationName,
            sectorsWrittenLBA: 0, // an erase writes no user data
            bytesWritten: 0,
            averageSpeedText: "—", // DiscRecording does not report erase speed
            peakSpeedText: "—",
            elapsedDurationText: String(format: "%02d:%02d", elapsed / 60, elapsed % 60),
            diagnosticAdvice: advice
        )
    }
}
