@preconcurrency import DiscRecording
import Foundation
import OpticalCore

// MARK: - KroutonOpticalDriveBank Burn Session Operations

@MainActor
extension KroutonOpticalDriveBank {
    /// How long to wait for the drive to confirm an abort before giving up on it.
    static let burnAbortGraceSeconds: TimeInterval = 60

    /// Starts a burn. With `audioDisc` it burns a Red Book audio CD (see
    /// `beginAudioBurn`); a single staged disc image (.iso, .cdr, .dmg, .cue/.bin, .toc) is burned
    /// as an image; anything else becomes a data disc. `onCompletion` is always called exactly once,
    /// including when the burn is refused before it starts or is aborted.
    ///
    /// Called only through `KroutonBurnCoordinator.burnOnThisMac` (BurnKit), which keeps it and the
    /// multi-disc set scheduler off each other's drives. It doesn't know the selected format: data
    /// discs are DiscRecording's ISO 9660 + Joliet (+ UDF 1.02 on DVD/BD) + HFS+, audio CDs arrive as rendered PCM tracks,
    /// and classic HFS, UDF 2.50 and Blu-ray video arrive as images. The app decides beforehand
    /// what may reach it (`KroutonFormatID.burnSupport`, `KroutonStateStore.burnRefusal(for:)`).
    ///
    /// - Parameter allowOverwriteOfWrittenMedia: pass true only when a person started
    ///   this burn. With false, rewritable media that already holds data is refused
    ///   instead of erased.
    public func startPhysicalDataBurn(
        driveID: String? = nil,
        stagedFiles: [KroutonStagedFileEntry],
        volumeTitle: String,
        requestedSpeedLabel: String,
        simulationMode: Bool,
        verifyDisc: Bool,
        allowOverwriteOfWrittenMedia: Bool = false,
        leaveDiscOpen: Bool = false,
        audioDisc: KroutonAudioBurnDisc? = nil,
        isoLevel1: Bool = false,
        onCompletion: @escaping @MainActor (KroutonBurnSessionReport) -> Void
    ) {
        let requestedID = driveID ?? selectedDrive?.id
        let resolvedMeta = driveForID(requestedID ?? "")
        let driveName = resolvedMeta?.displayName ?? "Optical Drive"
        let fwRev = resolvedMeta?.firmware ?? "—"

        func refuse(title: String, summary: String, media: String, advice: String) {
            let report = KroutonBurnSessionReport(
                isSuccess: false, title: title, summary: summary, driveModel: driveName, firmwareRevision: fwRev,
                mediaFormattedName: media, volumeName: volumeTitle, sectorsWrittenLBA: 0, bytesWritten: 0,
                averageSpeedText: "—", peakSpeedText: "—", elapsedDurationText: "00:00", diagnosticAdvice: advice
            )
            completionReport = report
            onCompletion(report)
        }

        if stagedFiles.count == 1, let only = stagedFiles.first,
           let reason = Self.unburnableImageExtensions[only.url.pathExtension.lowercased()] {
            refuse(title: "Can't Burn This Image", summary: reason, media: "—",
                   advice: "Nothing was written. Krouton burns .iso, .cdr, .dmg, .cue/.bin and .toc images as they are.")
            return
        }
        guard activeBurnSession == nil else {
            refuse(title: "Optical Burner Busy", summary: "Another burn is still running.", media: "—",
                   advice: "Wait for the current burn to finish, or abort it, before starting another.")
            return
        }
        guard let device = resolveDRDevice(id: requestedID) else {
            refuse(title: "Optical Burner Disconnected", summary: "Could not locate \(driveName) on the hardware bus.", media: "None",
                   advice: "Reconnect your optical drive and verify it appears in the Destination card.")
            return
        }
        let status = device.status() as? [String: Any] ?? [:]
        guard (status[DRDeviceMediaStateKey] as? String ?? DRDeviceMediaStateNone) == DRDeviceMediaStateMediaPresent else {
            refuse(title: "No Disc in Optical Drive", summary: "The slot on \(driveName) is currently empty.", media: "Slot Empty",
                   advice: "Insert a blank or rewritable disc into \(driveName) before starting the burn queue.")
            return
        }

        let mediaInfo = status[DRDeviceMediaInfoKey] as? [String: Any] ?? [:]
        let isErasable = (mediaInfo[DRDeviceMediaIsErasableKey] as? Bool) ?? false
        let mediaType = Self.formatHumanMediaType(mediaInfo[DRDeviceMediaTypeKey] as? String ?? "Disc")
        let decision = KroutonBurnMediaPolicy.evaluate(
            isBlank: (mediaInfo[DRDeviceMediaIsBlankKey] as? Bool) ?? false,
            isErasable: isErasable,
            isOverwritable: (mediaInfo[DRDeviceMediaIsOverwritableKey] as? Bool) ?? false,
            isAppendable: (mediaInfo[DRDeviceMediaIsAppendableKey] as? Bool) ?? false,
            allowOverwrite: allowOverwriteOfWrittenMedia
        )
        let overwrite: Bool
        switch decision {
        case .proceed(let overwriteExistingData):
            overwrite = overwriteExistingData
        case .refuseWouldDestroyData:
            refuse(title: "Disc Already Contains Data",
                   summary: "The \(mediaType) in \(driveName) is not blank, and this burn was not started by hand, so it was not erased.",
                   media: mediaType,
                   advice: "Swap in a blank disc, or start the burn yourself to overwrite this one.")
            return
        case .refuseNotWritable:
            refuse(title: "Disc Is Not Writable", summary: "The \(mediaType) in \(driveName) is closed and cannot take more data.",
                   media: mediaType, advice: "Insert a blank or rewritable disc.")
            return
        }

        var context = KroutonBurnJobContext(
            driveKey: resolvedMeta?.id ?? (driveID ?? ""),
            driveName: driveName,
            firmware: fwRev,
            mediaType: mediaType,
            isErasable: isErasable,
            volumeTitle: volumeTitle,
            itemCount: stagedFiles.count,
            totalBytes: stagedFiles.reduce(0) { $0 + $1.byteSize },
            totalLBA: max(1, stagedFiles.reduce(0) { $0 + $1.sectorsLBA }),
            requestedSpeedLabel: requestedSpeedLabel,
            simulationMode: simulationMode,
            verifyDisc: verifyDisc,
            overwriteExistingData: overwrite
        )
        context.leaveDiscOpen = leaveDiscOpen
        context.imageFileURL = Self.soleDiscImage(in: stagedFiles)
        if let audioDisc { context.adopt(audioDisc) }
        context.isoLevel1 = isoLevel1
        let stageURL = FileManager.default.temporaryDirectory.appendingPathComponent("KroutonHardwareStage_\(UUID().uuidString)")
        let session = KroutonActiveBurnSession(context: context, device: device, stageURL: stageURL, completion: onCompletion)

        device.acquireMediaReservation()
        activeBurnSession = session
        isExecutingQueue = true
        jobStartTime = Date()
        elapsedSeconds = 0
        neroSamples = []
        peakSpeedX = 0.0
        averageSpeedX = 0.0
        activeJobProgress = 0.01
        activeJobPhase = "Staging \(stagedFiles.count) Item(s) for \(driveName)..."
        activeJobDetail = "\(driveName) • \(volumeTitle)"

        // Audio tracks are produced straight from their rendered PCM; nothing to stage.
        if let audioDisc {
            beginAudioBurn(session, disc: audioDisc)
            return
        }
        // A disc image is read in place by DiscRecording; there is nothing to stage.
        if let imageURL = context.imageFileURL {
            imageURL.pathExtension.lowercased() == "cdi" ? beginDiscJugglerBurn(session, imageURL: imageURL) : beginImageBurn(session, imageURL: imageURL)
            return
        }

        // The copy can be many gigabytes; it runs off the main actor so the UI stays live.
        let items = stagedFiles.map { KroutonBurnStageItem(source: $0.url, name: $0.name) }
        session.stagingTask = Task { [weak self] in
            let stagingError = await KroutonBurnStager.stage(items, into: stageURL)
            guard let self, self.activeBurnSession === session else { return }
            if session.abortRequestedAt != nil {
                self.finishBurnSession(session, report: self.abortedReport(for: session, driveConfirmed: true))
            } else if let stagingError {
                self.finishBurnSession(session, report: self.makeBurnReport(
                    context, isSuccess: false, title: "Could Not Prepare Burn", summary: stagingError,
                    sectors: 0, bytes: 0,
                    advice: "Check that every staged item still exists and that the startup disk has room for a temporary copy."
                ))
            } else {
                self.beginStagedBurn(session, stagedFiles: stagedFiles)
            }
        }
    }

    /// Builds the DiscRecording layout from the staged copy and starts writing.
    private func beginStagedBurn(_ session: KroutonActiveBurnSession, stagedFiles: [KroutonStagedFileEntry]) {
        let context = session.context
        func failSetup(_ what: String) {
            finishBurnSession(session, report: makeBurnReport(
                context, isSuccess: false, title: "Could Not Prepare Burn", summary: what, sectors: 0, bytes: 0,
                advice: "Nothing was written to the disc. Try again; if it repeats, reconnect the drive."
            ))
        }

        guard let rootFolder = DRFolder(path: session.stageURL.path) else {
            failSetup("DiscRecording could not read the staged files.")
            return
        }
        rootFolder.makeVirtual()
        rootFolder.setBaseName(context.volumeTitle)

        let pcMask: UInt32 = context.mediaType.contains("CD")
            ? UInt32(DRFilesystemInclusionMaskISO9660 | DRFilesystemInclusionMaskJoliet)
            : UInt32(DRFilesystemInclusionMaskISO9660 | DRFilesystemInclusionMaskJoliet | DRFilesystemInclusionMaskUDF)
        let macMask: UInt32 = UInt32(DRFilesystemInclusionMaskHFSPlus)
        rootFolder.setExplicitFilesystemMask(DRFilesystemMask(macMask | pcMask))
        if context.isoLevel1 { rootFolder.setProperty(NSNumber(value: 1), forKey: DRISOLevel, inFilesystem: DRISO9660) }

        // Per-file OS visibility (Mac HFS+ vs PC ISO/Joliet/UDF)
        if let children = rootFolder.children() as? [DRFSObject] {
            for child in children {
                let childName = child.baseName()
                guard let entry = stagedFiles.first(where: { $0.name == childName }) else { continue }
                var itemMask: UInt32 = 0
                if entry.showOnMac { itemMask |= macMask }
                if entry.showOnPC { itemMask |= pcMask }
                if itemMask == 0 { itemMask = macMask | pcMask }
                child.setExplicitFilesystemMask(DRFilesystemMask(itemMask))
            }
        }

        guard let track = DRTrack(forRootFolder: rootFolder), let burn = DRBurn(for: session.device) else {
            failSetup("DiscRecording could not create a burn for \(context.driveName).")
            return
        }

        startWriting(session, burn: burn, layout: track)
    }

    /// Burns a disc image as it is: every sector, boot records and all, in the image's own layout.
    private func beginImageBurn(_ session: KroutonActiveBurnSession, imageURL: URL) {
        let context = session.context
        guard let layout = DRBurn.layout(forImageFile: imageURL.path), let burn = DRBurn(for: session.device) else {
            finishBurnSession(session, report: makeBurnReport(
                context, isSuccess: false, title: "Could Not Read Disc Image",
                summary: "DiscRecording could not read \(imageURL.lastPathComponent) as a disc image.",
                sectors: 0, bytes: 0,
                advice: "Nothing was written. Check the image in the Disc Image Depot; a .cue sheet needs its .bin files beside it."
            ))
            return
        }
        startWriting(session, burn: burn, layout: layout)
    }

    /// Applies the burn settings, writes the layout and starts watching progress.
    func startWriting(_ session: KroutonActiveBurnSession, burn: DRBurn, layout: Any) {
        let context = session.context
        var props = burn.properties() as? [String: Any] ?? [:]
        props[DRBurnTestingKey] = NSNumber(value: context.simulationMode)
        props[DRBurnVerifyDiscKey] = NSNumber(value: context.verifyDisc)
        props[DRBurnOverwriteDiscKey] = NSNumber(value: context.overwriteExistingData)
        props[DRBurnAppendableKey] = NSNumber(value: context.leaveDiscOpen)
        props[DRBurnCompletionActionKey] = DRBurnCompletionActionEject
        props[DRBurnRequestedSpeedKey] = NSNumber(value: Self.requestedSpeedKBs(from: context.requestedSpeedLabel))
        burn.setProperties(props)

        session.burn = burn
        jobStartTime = Date()
        let eventLabel = context.simulationMode
            ? (context.verifyDisc ? "Event: Simulation + Verify" : "Event: Simulation Write")
            : (context.verifyDisc ? "Event: Write + Verify" : "Event: Write (No Verify)")
        beginNewPhaseScopeEvent(
            for: context.driveKey,
            driveName: context.driveName,
            eventTitle: eventLabel,
            totalSectorsLBA: context.totalLBA,
            laserText: context.laserText,
            strategyText: context.strategyText
        )
        totalTargetSectorsLBA = context.totalLBA
        laserWavelengthText = context.laserText
        writeStrategyText = context.strategyText
        activeJobPhase = context.simulationMode ? "Simulating Burn (Laser Test Only)..." : "Calibrating Laser & Writing to \(context.mediaType)..."
        activeJobProgress = 0.02

        burn.writeLayout(layout)

        // The timer fires on the main run loop, so the poll runs synchronously on the
        // main actor. No Task hop means a slow tick cannot queue a second completion.
        burnMonitorTimer?.invalidate()
        burnMonitorTimer = Timer.scheduledTimer(withTimeInterval: 0.4, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.pollActiveBurn()
            }
        }
    }

    /// "Max" unless the label carries an explicit "(NNNN KB/s)" figure.
    static func requestedSpeedKBs(from label: String) -> Float {
        if let openParen = label.firstIndex(of: "("),
           let kbsRange = label.range(of: " KB/s"),
           openParen < kbsRange.lowerBound {
            let number = label[label.index(after: openParen)..<kbsRange.lowerBound].trimmingCharacters(in: .whitespaces)
            if let speedKBs = Float(number), speedKBs > 0 { return speedKBs }
        }
        return 65535.0 // DRBurnSpeedMax
    }

    private func pollActiveBurn() {
        guard let session = activeBurnSession, let burn = session.burn else {
            burnMonitorTimer?.invalidate()
            burnMonitorTimer = nil
            return
        }
        let context = session.context
        let bStatus = burn.status() as? [String: Any] ?? [:]
        let rawState = bStatus[DRStatusStateKey] as? String ?? ""
        updateBurnTelemetry(session, status: bStatus, rawState: rawState)

        let reachedEnd = ((bStatus[DRStatusPercentCompleteKey] as? NSNumber)?.doubleValue ?? 0.0) >= 0.999
        if rawState == DRStatusStateDone && session.abortRequestedAt != nil && !reachedEnd {
            finishBurnSession(session, report: abortedReport(for: session, driveConfirmed: true))
        } else if rawState == DRStatusStateDone {
            // A burn that completed before an abort took effect still completed.
            activeJobProgress = 1.0
            activeJobPhase = context.simulationMode ? "Simulation Completed" : "Optical Burn & Verification Complete!"
            let advice = context.verifyDisc
                ? "Session closed and verified against the source. The disc is ready for macOS Finder, Windows Explorer, and standalone hardware players."
                : "Session closed. Verification was turned off for this burn, so the written data was not read back."
            finishBurnSession(session, report: makeBurnReport(
                context,
                isSuccess: true,
                title: context.simulationMode ? "Simulation Burn Completed" : "Optical Disc Burn Complete",
                summary: context.simulationMode
                    ? "Completed a full laser simulation pass on \(context.driveName). Because Simulation Mode was enabled, no sectors were permanently written."
                    : "Successfully wrote and closed '\(context.volumeTitle)' (\(context.itemCount) items) onto \(context.mediaType) using \(context.driveName).",
                sectors: context.totalLBA,
                bytes: context.totalBytes,
                advice: advice
            ))
        } else if rawState == DRStatusStateFailed {
            if session.abortRequestedAt != nil {
                finishBurnSession(session, report: abortedReport(for: session, driveConfirmed: true))
                return
            }
            let errInfo = bStatus[DRErrorStatusKey] as? [String: Any]
            let errStr = errInfo?[DRErrorStatusErrorStringKey] as? String ?? "Hardware burn failed."
            let senseStr = errInfo?[DRErrorStatusAdditionalSenseStringKey] as? String ?? ""
            activeJobPhase = "Burn Failed on \(context.driveName)"
            let advice: String
            if context.driveName.uppercased().contains("UJ-898") && context.mediaType.contains("RW") {
                advice = "Hardware Note: The slot-loading Matshita UJ-898 frequently rejects CD-RW phase-change dye calibration. Your Pioneer DVRTD08 and Matshita UJ265 drives have broader OPC tables and handle this CD-RW media reliably."
            } else {
                advice = "If this is a previously written rewritable disc, run 'Erase RW -> Quick Erase' first, or select a slower write speed."
            }
            finishBurnSession(session, report: makeBurnReport(
                context,
                isSuccess: false,
                title: "Optical Burn Failed",
                summary: "\(errStr)\(senseStr.isEmpty ? "" : " — Hardware Sense: \(senseStr)")",
                sectors: currentSectorLBA,
                bytes: currentSectorLBA * 2048,
                advice: advice
            ))
        } else if let requested = session.abortRequestedAt,
                  Date().timeIntervalSince(requested) > Self.burnAbortGraceSeconds {
            finishBurnSession(session, report: abortedReport(for: session, driveConfirmed: false))
        }
    }

    private func updateBurnTelemetry(_ session: KroutonActiveBurnSession, status bStatus: [String: Any], rawState: String) {
        let context = session.context
        let pct = (bStatus[DRStatusPercentCompleteKey] as? NSNumber)?.doubleValue ?? 0.0
        let clampedPct = max(0.0, min(1.0, pct))
        let divisor = context.speedDivisor
        let reportedKBs = max(0.0, (bStatus[DRStatusCurrentSpeedKey] as? NSNumber)?.doubleValue ?? 0.0)
        let speedX = divisor > 0 ? (reportedKBs / divisor) : 0.0

        currentSpeedKBs = reportedKBs
        currentSpeedX = speedX
        if speedX > peakSpeedX { peakSpeedX = speedX }
        currentSpindleRPM = 0
        currentSectorLBA = Int64(Double(context.totalLBA) * clampedPct)
        activeTrackNumber = (bStatus[DRStatusCurrentTrackKey] as? NSNumber)?.intValue ?? 1
        elapsedSeconds = max(1, Int(Date().timeIntervalSince(jobStartTime)))
        driveBufferFillPercent = 0.0
        activeJobProgress = clampedPct
        if session.abortRequestedAt == nil {
            activeJobPhase = Self.formatHumanBurnState(rawState, isErase: false)
        }

        neroSamples.append(KroutonBurnTelemetrySample(
            progressFraction: clampedPct,
            speedMultiplierX: speedX,
            spindleRPM: 0.0,
            throughputKBs: reportedKBs
        ))
        if speedX > 0 {
            session.speedSumX += speedX
            session.speedSampleCount += 1
            averageSpeedX = session.speedSumX / Double(session.speedSampleCount)
        }

        guard !context.driveKey.isEmpty else { return }
        var dTel = driveTelemetry[context.driveKey] ?? KroutonDrivePhaseScopeTelemetry(id: context.driveKey, driveName: context.driveName)
        dTel.isActive = (rawState != DRStatusStateDone && rawState != DRStatusStateFailed)
        dTel.phaseTitle = activeJobPhase
        dTel.progressFraction = clampedPct
        dTel.currentSpeedX = speedX
        dTel.currentSpeedKBs = reportedKBs
        if speedX > dTel.peakSpeedX { dTel.peakSpeedX = speedX }
        dTel.averageSpeedX = averageSpeedX
        dTel.currentSpindleRPM = currentSpindleRPM
        dTel.currentSectorLBA = currentSectorLBA
        dTel.totalSectorsLBA = context.totalLBA
        dTel.bufferFillPercent = driveBufferFillPercent
        dTel.laserWavelengthText = laserWavelengthText
        dTel.writeStrategyText = writeStrategyText
        dTel.elapsedSeconds = elapsedSeconds
        dTel.appendMonotonicSample(rawFraction: clampedPct, speedX: speedX, rpm: currentSpindleRPM, kbs: reportedKBs)
        driveTelemetry[context.driveKey] = dTel
    }

    /// The single exit for every burn. Safe to call more than once; only the first call acts.
    func finishBurnSession(_ session: KroutonActiveBurnSession, report: KroutonBurnSessionReport) {
        guard activeBurnSession === session else { return }
        activeBurnSession = nil
        burnMonitorTimer?.invalidate()
        burnMonitorTimer = nil
        session.stagingTask?.cancel()
        session.device.releaseMediaReservation()

        let stageURL = session.stageURL
        Task.detached(priority: .utility) {
            try? FileManager.default.removeItem(at: stageURL)
        }

        isExecutingQueue = false
        if var dTel = driveTelemetry[session.context.driveKey] {
            dTel.isActive = false
            driveTelemetry[session.context.driveKey] = dTel
        }
        completionReport = report
        refreshDrives()

        let completion = session.completion
        session.completion = nil
        completion?(report)
    }

    /// Asks the drive to stop. The session stays open until the drive confirms (or the
    /// grace period runs out), so the reservation and staged files are not pulled out
    /// from under a drive that is still writing. Called by `abortActiveBurn`.
    func stopActiveOperation() {
        guard let session = activeBurnSession else {
            if let eraseSession = activeEraseSession {
                // DiscRecording cannot stop an erase. Keep tracking it so the drive is not shown as idle.
                activeJobDetail = "An erase cannot be interrupted. Waiting for \(eraseSession.driveName) to finish."
                return
            }
            burnMonitorTimer?.invalidate()
            isExecutingQueue = false
            activeJobPhase = "Operation Aborted by User"
            return
        }
        guard session.abortRequestedAt == nil else { return }
        session.abortRequestedAt = Date()
        activeJobPhase = "Aborting — Waiting for \(session.context.driveName) to Stop..."
        if let burn = session.burn {
            burn.abort()
        } else {
            session.stagingTask?.cancel()
        }
    }

    private func abortedReport(for session: KroutonActiveBurnSession, driveConfirmed: Bool) -> KroutonBurnSessionReport {
        let context = session.context
        let reachedDisc = session.burn != nil && !context.simulationMode
        activeJobPhase = "Operation Aborted by User"
        let advice: String
        if !driveConfirmed {
            advice = "\(context.driveName) did not confirm the abort within \(Int(Self.burnAbortGraceSeconds)) seconds. Power-cycle the drive before using it again."
        } else if reachedDisc {
            advice = context.isErasable
                ? "The disc was partly written. Erase it before reusing it."
                : "The disc was partly written. Write-once media that was interrupted is usually not reusable."
        } else {
            advice = "Nothing was written to the disc."
        }
        return makeBurnReport(
            context,
            isSuccess: false,
            title: "Burn Aborted",
            summary: "The burn of '\(context.volumeTitle)' on \(context.driveName) was stopped before it finished.",
            sectors: reachedDisc ? currentSectorLBA : 0,
            bytes: reachedDisc ? currentSectorLBA * 2048 : 0,
            advice: advice
        )
    }

    func makeBurnReport(
        _ context: KroutonBurnJobContext,
        isSuccess: Bool,
        title: String,
        summary: String,
        sectors: Int64,
        bytes: Int64,
        advice: String
    ) -> KroutonBurnSessionReport {
        let elapsed = max(0, Int(Date().timeIntervalSince(jobStartTime)))
        return KroutonBurnSessionReport(
            isSuccess: isSuccess,
            title: title,
            summary: summary,
            driveModel: context.driveName,
            firmwareRevision: context.firmware,
            mediaFormattedName: context.mediaType,
            volumeName: context.volumeTitle,
            sectorsWrittenLBA: sectors,
            bytesWritten: bytes,
            averageSpeedText: averageSpeedX > 0 ? String(format: "%.1fx (%.0f KB/s)", averageSpeedX, averageSpeedX * context.speedDivisor) : "—",
            peakSpeedText: peakSpeedX > 0 ? String(format: "%.1fx (%.0f KB/s)", peakSpeedX, peakSpeedX * context.speedDivisor) : "—",
            elapsedDurationText: String(format: "%02d:%02d", elapsed / 60, elapsed % 60),
            diagnosticAdvice: advice
        )
    }
}
