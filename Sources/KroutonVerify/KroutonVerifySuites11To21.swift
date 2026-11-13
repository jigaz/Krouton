import Foundation
import OpticalDough
import Marmalade
import VideoOven
import Tartine
import Galette
import Crustini

@MainActor
func runKroutonVerifySuites11To21(_ harness: inout KroutonTestHarness) {
harness.runSuite("11. Marmalade Red Book CUE Sheet Compiler, 18B CD-Text CRC-16 & Equal-Power Crossfade") { h in
    // 11a. Equal-power crossfade energy conservation (fadeOut^2 + fadeIn^2 == 1.0)
    for step in 0...10 {
        let t = Double(step) / 10.0
        let (outG, inG) = KroutonMarmaladeModule.equalPowerCrossfadeGains(progress: t)
        let energySum = (outG * outG) + (inG * inG)
        h.check(abs(energySum - 1.0) < 1e-9, "Equal-power crossfade energy must equal 1.0 at t=\(t)")
    }

    // 11b. 18-Byte Sony/Philips CD-Text Pack & CRC-16 CCITT verification
    let packs = KroutonMarmaladeModule.buildCDTextPacks(
        packType: 0x80,
        trackNumber: 1,
        text: "KROUTON OVERDRIVE SUITE"
    )
    h.check(packs.count == 2, "23-char title + null byte must span 2 x 12-byte CD-Text packs")
    for p in packs {
        let raw = p.raw18Bytes
        h.check(raw.count == 18, "Each Sony/Philips CD-Text pack must be exactly 18 bytes")
        let recomputedCRC = KroutonMarmaladeModule.computeCDTextInvertedCRC16(Array(raw.prefix(16)))
        h.check(recomputedCRC == p.crc16Inverted, "CD-Text CRC-16 CCITT must match inverted header+payload checksum")
    }

    // 11c. Frame-accurate Red Book .cue sheet generation
    let tracks = [
        KroutonAudioCube(
            url: URL(fileURLWithPath: "/tmp/01.wav"),
            title: "Solar Overture",
            performer: "The Bakery",
            songWriter: "Greybeard",
            isrcCode: "USKRO2600001",
            durationSeconds: 10.0,
            preGapSeconds: 2.0,
            crossfadeSeconds: 0.0,
            transitionStyle: .standard2s,
            preEmphasisEnabled: true,
            copyPermittedSCMS: true
        ),
        KroutonAudioCube(
            url: URL(fileURLWithPath: "/tmp/02.wav"),
            title: "Laser Groove",
            performer: "The Bakery",
            songWriter: "Bruder",
            isrcCode: "USKRO2600002",
            durationSeconds: 20.0,
            preGapSeconds: 0.0,
            crossfadeSeconds: 2.0,
            transitionStyle: .gapless0s
        )
    ]
    let cue = KroutonMarmaladeModule.compileRedBookCueSheet(
        albumTitle: "Krouton Red Book Master",
        albumPerformer: "The Bakery",
        mcnCatalog: "0123456789012",
        tracks: tracks
    )
    h.check(cue.contains("CATALOG 0123456789012"), "CUE sheet must contain 13-digit CATALOG")
    h.check(cue.contains("INDEX 00 00:00:00") && cue.contains("INDEX 01 00:02:00"), "Track 1 pregap + program start")
    h.check(cue.contains("FLAGS DCP PRE"), "Track 1 SCMS + Pre-emphasis flags")
    // Track 1 ends at 00:02:00 + 00:10:00 = 00:12:00, and Track 2 has 0s pregap -> INDEX 01 00:12:00
    h.check(cue.contains("INDEX 01 00:12:00"), "Track 2 gapless start at exact cumulative frame 00:12:00")
}


// 12. Tartine Hybrid Data Loaf LBA Planner (ISO-9660, Joliet, UDF 2.60, El Torito & Dual-Tree Deduplication)
harness.runSuite("12. Tartine Hybrid Data LBA Planner (PVD LBA 16, El Torito LBA 17, UDF LBA 256 & Deduplication)") { h in
    let vol = KroutonTartineModule.sanitizeVolumeIdentifier("Krouton Master 2026! (v1.0)")
    h.check(vol == "KROUTON_MASTER_2026___V1_0", "ECMA-119 d-character volume label sanitization")

    let isoFile = KroutonTartineModule.sanitizeISO9660FileIdentifier("my-super-archive-2026.tar.gz")
    h.check(isoFile.hasSuffix(".GZ;1") && isoFile.count <= 31, "ISO-9660 Level 2 filename + ;1 version")

    let fiveGiB: Int64 = 5 * 1024 * 1024 * 1024
    let entries = [
        KroutonLoafFileEntry(
            url: URL(fileURLWithPath: "/tmp/SharedInstaller.pkg"),
            name: "SharedInstaller.pkg",
            isDirectory: false,
            byteSize: 4096, // 2 sectors
            itemCount: 1,
            posixPermissions: "rwxr-xr-x",
            modifiedDate: Date(),
            showOnMac: true,
            showOnPC: true
        ),
        KroutonLoafFileEntry(
            url: URL(fileURLWithPath: "/tmp/Giant4KMaster.mov"),
            name: "Giant4KMaster.mov",
            isDirectory: false,
            byteSize: fiveGiB,
            itemCount: 1,
            posixPermissions: "rw-r--r--",
            modifiedDate: Date(),
            showOnMac: true,
            showOnPC: true
        )
    ]

    let plan = KroutonTartineModule.planHybridDataLayout(
        volumeLabel: "Krouton Boot Hybrid",
        entries: entries,
        isElToritoBootable: true
    )

    h.check(plan.pvdSectorLBA == 16, "ISO-9660 PVD must sit at LBA 16")
    h.check(plan.elToritoBootRecordLBA == 17, "El Torito Boot Record must sit at LBA 17")
    h.check(plan.jolietSVDSectorLBA == 18, "Joliet SVD must shift to LBA 18 when El Torito is at LBA 17")
    h.check(plan.udfAnchorAVDPLBA == 256, "ECMA-167 UDF Anchor Volume Descriptor Pointer must sit at LBA 256")
    h.check(plan.sharedHybridExtents.count == 2, "Shared Mac+PC files must deduplicate into single physical LBA extents")
    h.check(plan.sharedHybridExtents[0].startLBA == 288 && plan.sharedHybridExtents[0].sectorCountLBA == 2, "First file starts at LBA 288 (2 sectors)")
    h.check(plan.sharedHybridExtents[1].startLBA == 290 && plan.sharedHybridExtents[1].requiresUDFMultiExtent, "Second file (>4GiB) starts monotonically at LBA 290 and flags UDF multi-extent")
    h.check(!plan.warnings.isEmpty, ">4GiB file must emit UDF multi-extent advisory")
}


// 13. VideoOven Bitrate Budget Calculator & DVD-9 -> DVD-5 Requiem Requantization Planner
harness.runSuite("13. VideoOven Optical Bitrate Budget (DVD-5/DVD-9/BD-25/BD-50) & DVD-9 Shrink Math") { h in
    h.check(KroutonVideoTargetMedium.dvd5SingleLayer.capacityBytes == 4_700_372_992, "Exact DVD-5 byte capacity (2,295,104 sectors)")
    h.check(KroutonVideoTargetMedium.dvd9DualLayer.capacityBytes == 8_547_991_552, "Exact DVD-9 byte capacity (4,173,824 sectors)")
    h.check(KroutonVideoTargetMedium.bd25SingleLayer.capacityBytes == 25_025_314_816, "Exact BD-25 byte capacity")

    // Short 30-minute program on DVD-5 should clamp strictly to the 9,800 kbps DVD-Video hardware ceiling
    let shortDVD = KroutonVideoOvenModule.computeBitrateBudget(durationSeconds: 1800, audioKbps: 448, medium: .dvd5SingleLayer)
    h.check(shortDVD.targetVideoKbps == 9_800, "Short DVD program must clamp to 9,800 kbps DVD-Video spec ceiling")
    h.check(shortDVD.vbvBufferKilobits == 1_835 && shortDVD.isSpecCompliant, "DVD VBV buffer must be 1,835 kb")

    // 2.5-hour (9000s) feature film on DVD-5 must compute a custom VBR target below 9,800 kbps to fit 100% of disc
    let featureDVD = KroutonVideoOvenModule.computeBitrateBudget(durationSeconds: 9000, audioKbps: 448, medium: .dvd5SingleLayer)
    h.check(featureDVD.targetVideoKbps > 3_000 && featureDVD.targetVideoKbps < 4_200, "150-min DVD-5 target video bitrate in [3000, 4200] kbps")
    h.check(featureDVD.estimatedDiscFillRatio > 0.98, "150-min DVD-5 bitrate budget should utilize >98% of disc capacity")

    // DVD-9 (7.2 GB main + 0.8 GB extras) -> DVD-5 shrink test with and without extras
    let mainBytes: Int64 = 6_800_000_000
    let extraBytes: Int64 = 900_000_000
    let shrinkWithExtras = KroutonVideoOvenModule.planDVD9ToDVD5Shrink(
        mainFeatureBytes: mainBytes,
        menusAndExtrasBytes: extraBytes,
        preserveMenusAndExtras: true
    )
    let shrinkMainOnly = KroutonVideoOvenModule.planDVD9ToDVD5Shrink(
        mainFeatureBytes: mainBytes,
        menusAndExtrasBytes: extraBytes,
        preserveMenusAndExtras: false
    )
    h.check(shrinkWithExtras.requiresRequantization && shrinkWithExtras.estimatedOutputBytes <= KroutonVideoTargetMedium.dvd5SingleLayer.capacityBytes,
            "DVD-9 -> DVD-5 shrink must fit strictly inside DVD-5 capacity")
    h.check(shrinkMainOnly.requantizationRatio > shrinkWithExtras.requantizationRatio,
            "Stripping extras must yield higher video quality retention ratio for the main feature")
}


// 14. Galette Disc Image Depot (.cue Parser, 2352B Mode 1 / Mode 2 -> 2048B ISO Extractor & Boot Classifier)
harness.runSuite("14. Galette Disc Image Depot (.cue Parser, 2352B->2048B BIN Extractor & Boot Classifier)") { h in
    // 14a. Multi-track Mixed-Mode .cue sheet parsing
    let sampleCue = """
    FILE "KROUTON_MIXED_MASTER.BIN" BINARY
      TRACK 01 MODE1/2352
        TITLE "Data Track"
        INDEX 01 00:00:00
      TRACK 02 AUDIO
        TITLE "Red Book Theme"
        INDEX 00 02:00:00
        INDEX 01 02:02:00
    """
    let parsedTracks = KroutonGaletteModule.parseCueSheet(sampleCue)
    h.check(parsedTracks.count == 2, "Mixed-mode CUE sheet must parse 2 tracks")
    h.check(parsedTracks[0].mode == .mode1_2352 && parsedTracks[0].index01LBA == 0, "Track 1 Mode1/2352 @ LBA 0")
    h.check(parsedTracks[1].mode == .audio2352 && parsedTracks[1].index00LBA == 9000 && parsedTracks[1].index01LBA == 9150,
            "Track 2 Audio INDEX 00 @ 02:00:00 (9000 LBA) and INDEX 01 @ 02:02:00 (9150 LBA)")

    // 14b. Raw 2352-byte Mode 1 & Mode 2 Form 1 -> 2048-byte ISO payload extraction
    var mode1Raw = Data(KroutonGaletteModule.cdRomSyncPattern) // 12 bytes
    mode1Raw.append(contentsOf: [0x00, 0x02, 0x00, 0x01])      // 4B header (00:02:00, Mode 1 = 0x01)
    let expectedPayload = Data(repeating: 0x5A, count: 2048)
    mode1Raw.append(expectedPayload)                           // 2048B user payload
    mode1Raw.append(Data(repeating: 0xEE, count: 288))         // 288B EDC/ECC parity
    h.check(mode1Raw.count == 2352, "Synthetic Mode 1 raw sector must be 2352 bytes")

    let extractedISO = KroutonGaletteModule.extractISO2048SectorFromRaw2352(mode1Raw)
    h.check(extractedISO == expectedPayload && extractedISO?.count == 2048,
            "Mode 1 2352B sector extractor must strip 16B header and 288B ECC to yield exact 2048B ISO payload")

    // 14c. Depot Boot & Media Badge classification
    let depotClass = KroutonGaletteModule.classifyDepotImage(
        byteSize: 4_100_000_000,
        signatureSampleASCII: "CD001 EL TORITO SPECIFICATION UDF NSR03"
    )
    h.check(depotClass.isBootable && depotClass.bootStandard == "El Torito x86/EFI", "El Torito boot detection")
    h.check(depotClass.detectedFilesystems.contains("ISO-9660") && depotClass.detectedFilesystems.contains("UDF"), "ISO+UDF bridge detection")
    h.check(depotClass.recommendedMediaBadge == "DVD-5 (4.7 GB SL)", "4.1 GB image must recommend DVD-5")
}


// 15. Crustini Optical Rescue Copy State Machine & Polar 300-DPI Disc Label Geometry Engine
harness.runSuite("15. Crustini Optical Rescue Copy Engine & Polar 300-DPI Label Geometry") { h in
    // 15a. Optical Rescue 3-stage state machine (Clean -> 2x CLV Downshift -> Zero-Pad Substitute)
    let clean = KroutonKrustiniModule.evaluateSectorRescue(lba: 1000, c2ErrorCount: 0, retryAttempt: 0)
    h.check(clean.action == .readCleanFullSpeed && clean.nextCursorLBA == 1001, "Clean sector advances LBA by 1 at full speed")

    let retry = KroutonKrustiniModule.evaluateSectorRescue(lba: 1000, c2ErrorCount: 4, retryAttempt: 2, maxRetries: 5)
    h.check(retry.action == .downshiftRetry2xCLV && retry.recommendedSpindleSpeedX == 2 && retry.nextCursorLBA == 1000,
            "Damaged sector under retry threshold downshifts to 2x CLV and re-reads same LBA")

    let exhausted = KroutonKrustiniModule.evaluateSectorRescue(
        lba: 1000,
        c2ErrorCount: 12,
        retryAttempt: 5,
        maxRetries: 5,
        sectorSizeBytes: 2048,
        fastSkipStepLBA: 16
    )
    h.check(exhausted.action == .substituteZeroSector && exhausted.replacementSectorBytes == 2048 && exhausted.nextCursorLBA == 1016,
            "Exhausted sector substitutes 2048B zero-pad and fast-skips 16 LBA sectors")

    // 15b. 300-DPI Disc Label Canvas (120mm @ 300 DPI = 1417 px) & Hub Annulus Hit-Testing
    let fullFace = KroutonDiscHubGeometry.fullFace120mmHub22mm
    h.check(fullFace.canvasPixelDimension(dpi: 300.0) == 1417, "120mm disc at 300 DPI must equal 1417 x 1417 pixels")

    // Center spindle hole (0, 0) must be rejected; mid-disc ring (r = 35mm) must be accepted; outside disc (r = 65mm) rejected
    h.check(!KroutonKrustiniModule.isPointInsidePrintableAnnulus(dxMM: 0.0, dyMM: 0.0, geometry: fullFace),
            "Spindle center (0,0) must be excluded from printable ink annulus")
    h.check(KroutonKrustiniModule.isPointInsidePrintableAnnulus(dxMM: 35.0, dyMM: 0.0, geometry: fullFace),
            "35mm radius must lie inside printable ink annulus")
    h.check(!KroutonKrustiniModule.isPointInsidePrintableAnnulus(dxMM: 65.0, dyMM: 0.0, geometry: fullFace),
            "65mm radius (outside 118mm diameter) must be excluded from printable ink annulus")

    // 15c. Polar-to-Cartesian curved text glyph placement invariant (every glyph sits exactly at radius R)
    let glyphs = KroutonKrustiniModule.computePolarArcGlyphLayout(
        text: "KROUTON MASTER ARCHIVE",
        centerX: 708.5,
        centerY: 708.5,
        radiusPoints: 500.0
    )
    h.check(glyphs.count == 22, "22-char title must produce 22 polar glyph placements")
    for g in glyphs {
        let dist = hypot(g.xPoints - 708.5, g.yPoints - 708.5)
        h.check(abs(dist - 500.0) < 1e-6, "Glyph '\(g.character)' must sit at exact polar radius 500.0 pt (got \(dist))")
    }
}


// 16. Deep Process Security Gate (Zero Shell Injection) & Telemetry State Machine Fuzzing
harness.runSuite("16. Zero Shell-Injection Process Gate & 500-Frame Telemetry State Machine Fuzzing") { h in
    // 16a. Scan all 21 production files to ensure Process never invokes a shell (/bin/sh, /bin/zsh, /bin/bash, -c)
    let forbiddenShellPatterns = ["/bin/sh", "/bin/bash", "/bin/zsh", "/usr/bin/env sh", "Darwin.system(", "popen("]
    let fm = FileManager.default
    if let enumerator = fm.enumerator(atPath: "Sources") {
        while let rel = enumerator.nextObject() as? String {
            guard rel.hasSuffix(".swift"), !rel.contains("KroutonVerify/") else { continue }
            let content = (try? String(contentsOfFile: "Sources/" + rel, encoding: .utf8)) ?? ""
            for pat in forbiddenShellPatterns {
                h.check(!content.contains(pat), "Forbidden shell pattern '\(pat)' found in \(rel)")
            }
        }
    }

    // 16b. Fuzz KrumbTelemetrySanitizer with out-of-order packets, NaN, Infinity, and terminal-state regressions
    var state: KrumbTelemetryPhase = .preheating
    var frac: Double = 0.0
    let batchID = UUID()

    for step in 1...250 {
        let progress = Double(step) / 250.0
        let normalFrame = KrumbTelemetryPacket(
            batchId: batchID,
            toasterId: "pioneer-01",
            state: .toastingProgress,
            fraction: progress,
            currentLba: Int64(step * 100),
            totalLba: 25000,
            effectiveSpeedX: 16.0,
            fifoFill: 0.95,
            driveBufferFill: 0.92,
            c2Errors: 0,
            etaSeconds: 45
        )
        let res = KrumbTelemetrySanitizer.sanitizeProgressTransition(previousState: state, previousFraction: frac, incomingFrame: normalFrame)
        h.check(res.fraction >= frac, "Progress must never regress during active burn")
        state = res.state
        frac = res.fraction

        // Inject a stale out-of-order frame with lower fraction + NaN buffer values
        let staleFuzzFrame = KrumbTelemetryPacket(
            batchId: batchID,
            toasterId: "pioneer-01",
            state: .toastingProgress,
            fraction: max(0.0, progress - 0.15),
            currentLba: 10,
            totalLba: 25000,
            effectiveSpeedX: .nan,
            fifoFill: .nan,
            driveBufferFill: .infinity,
            c2Errors: 0,
            etaSeconds: 99
        )
        let fuzzRes = KrumbTelemetrySanitizer.sanitizeProgressTransition(previousState: state, previousFraction: frac, incomingFrame: staleFuzzFrame)
        h.check(fuzzRes.fraction == frac, "Stale out-of-order telemetry frame must be ignored")
        h.check(fuzzRes.fifoClamp == 0.0 && fuzzRes.driveClamp == 0.0, "NaN/Infinity buffer fills must clamp safely to 0.0")
    }

    // Transition to terminal BURNT_TOAST and verify late TOASTING_PROGRESS cannot resurrect the job
    let failFrame = KrumbTelemetryPacket(
        batchId: batchID,
        toasterId: "pioneer-01",
        state: .burntToast,
        fraction: frac,
        currentLba: 12000,
        totalLba: 25000,
        effectiveSpeedX: 0.0,
        fifoFill: 0.0,
        driveBufferFill: 0.0,
        c2Errors: 99,
        etaSeconds: 0
    )
    let termRes = KrumbTelemetrySanitizer.sanitizeProgressTransition(previousState: state, previousFraction: frac, incomingFrame: failFrame)
    state = termRes.state
    h.check(state == .burntToast, "Must transition to terminal .burntToast state")

    let zombieFrame = KrumbTelemetryPacket(
        batchId: batchID,
        toasterId: "pioneer-01",
        state: .toastingProgress,
        fraction: 0.99,
        currentLba: 24900,
        totalLba: 25000,
        effectiveSpeedX: 16.0,
        fifoFill: 1.0,
        driveBufferFill: 1.0,
        c2Errors: 0,
        etaSeconds: 1
    )
    let afterZombie = KrumbTelemetrySanitizer.sanitizeProgressTransition(previousState: state, previousFraction: frac, incomingFrame: zombieFrame)
    h.check(afterZombie.state == .burntToast, "Terminal state must reject late out-of-order progress frames")
}


// 17. End-to-End 5-Module Mastering Pipeline Integration (OpticalDough + Marmalade + Tartine + VideoOven + Galette + Crustini)
harness.runSuite("17. End-to-End 5-Module Mastering & LAN Signed Dispatch Integration Pipeline") { h in
    // Step 1: Plan a Hybrid Data Loaf via Tartine
    let entries = [
        KroutonLoafFileEntry(
            url: URL(fileURLWithPath: "/tmp/KroutonBoot.efi"),
            name: "KroutonBoot.efi",
            isDirectory: false,
            byteSize: 65_536,
            itemCount: 1,
            posixPermissions: "rwxr-xr-x",
            modifiedDate: Date(),
            showOnMac: true,
            showOnPC: true
        )
    ]
    let layout = KroutonTartineModule.planHybridDataLayout(
        volumeLabel: "KROUTON_E2E_MASTER",
        entries: entries,
        isElToritoBootable: true
    )
    h.check(layout.totalSectorsLBA > 288, "Tartine E2E layout must allocate descriptors + payload + lead-out")

    // Step 2: Classify the resulting image via Galette
    let depotInfo = KroutonGaletteModule.classifyDepotImage(
        byteSize: layout.totalBytes,
        signatureSampleASCII: "CD001 EL TORITO SPECIFICATION UDF NSR03"
    )
    h.check(depotInfo.isBootable && depotInfo.recommendedMediaBadge == "CD-R (700 MB)", "Galette E2E image classification")

    // Step 3: Sign the network dispatch payload via KrumbLANSecurityEngine for a private LAN toaster
    let targetEndpoint = "http://192.168.1.77:7420/api/v1/bake"
    h.check(KrumbLANSecurityEngine.isAllowedLANEndpoint(targetEndpoint), "Private LAN toaster endpoint must pass subnet guard")

    let dispatchJSON = Data("{\"volume\":\"\(layout.volumeIdentifier)\",\"sectors\":\(layout.totalSectorsLBA)}".utf8)
    var replaySet: Set<String> = []
    let signed = KrumbLANSecurityEngine.signPayload(dispatchJSON, sharedSecret: "e2e-kitchen-secret", timestampEpochSeconds: 1_775_100_000, nonce: "e2e-001")
    let verified = KrumbLANSecurityEngine.verifyEnvelope(signed, sharedSecret: "e2e-kitchen-secret", nowEpochSeconds: 1_775_100_002, seenNonces: &replaySet)
    h.check(verified == dispatchJSON, "End-to-end signed Krumb dispatch must verify cleanly")
}


// 18. VideoOven DVD-9 -> DVD-5 Menu-Preserving Shrink, IFO Sector Pointer Relinking & Layer-Break Pause Removal
harness.runSuite("18. VideoOven DVD-9 -> DVD-5 Menu-Preserving Shrink, .IFO Relinking & Layer-Break Removal") { h in
    // Simulate a 7.85 GB Dual-Layer DVD-9 (450 MB interactive motion menus + 3 main feature cells across Layer 0 & Layer 1)
    let dvd9Cells = [
        KroutonDVD9CellDescriptor(cellID: 1, originalStartSectorLBA: 0,         originalSectorCountLBA: 1_200_000, hadDualLayerBreakPause: false),
        KroutonDVD9CellDescriptor(cellID: 2, originalStartSectorLBA: 1_200_000, originalSectorCountLBA: 1_100_000, hadDualLayerBreakPause: true), // Layer 0 -> Layer 1 break cell!
        KroutonDVD9CellDescriptor(cellID: 3, originalStartSectorLBA: 2_300_000, originalSectorCountLBA: 1_100_000, hadDualLayerBreakPause: false)
    ]
    let blueprint = KroutonVideoOvenModule.buildDVD9ToDVD5MenuShrinkBlueprint(
        ifoTableBytes: 65_536,
        menuVobBytes: 450_000_000,
        preserveMenus: true,
        sourceCells: dvd9Cells
    )

    h.check(blueprint.originalTotalBytes > KroutonVideoTargetMedium.dvd5SingleLayer.capacityBytes,
            "Source DVD-9 (7.4 GB) must exceed DVD-5 single-layer capacity before shrink")
    h.check(blueprint.fitsStrictlyOnDVD5 && blueprint.shrunkTotalBytes <= KroutonVideoTargetMedium.dvd5SingleLayer.capacityBytes,
            "Shrunk DVD-9 -> DVD-5 output (\(blueprint.shrunkTotalBytes) B) must fit strictly inside 4,700,372,992 B DVD-5 ceiling")
    h.check(blueprint.navPacksAndButtonHighlightsIntact && blueprint.menuVobRetentionRatio == 0.90,
            "Menu NV_PCK & SPU button highlight overlays must remain intact with 90% motion-menu video retention")
    h.check(blueprint.layerBreakPauseRemoved,
            "Old DVD-9 OTP layer-break pause on Cell 2 must be cleared for seamless single-layer DVD-5 playback")

    // Verify contiguous, gapless IFO cell sector relinking (Cell N+1 startLBA == Cell N endLBA + 1)
    h.check(blueprint.relinkedCells.count == 3, "All 3 PGC cells must be relinked in VTS_01_0.IFO / .BUP")
    h.check(blueprint.relinkedCells[0].relinkedStartSectorLBA == 0, "Cell 1 starts at relative VOB sector 0")
    h.check(blueprint.relinkedCells[1].relinkedStartSectorLBA == blueprint.relinkedCells[0].relinkedEndSectorLBA + 1,
            "Cell 2 relinked start LBA must immediately follow Cell 1 shrunk end LBA")
    h.check(blueprint.relinkedCells[2].relinkedStartSectorLBA == blueprint.relinkedCells[1].relinkedEndSectorLBA + 1,
            "Cell 3 relinked start LBA must immediately follow Cell 2 shrunk end LBA")
    h.check(blueprint.relinkedCells.allSatisfy { $0.seamlessPlaybackFlagSet },
            "All relinked cells on DVD-5 must have seamlessPlaybackFlagSet = true")
}

    runKroutonVerifySuites19To21(&harness)
}
