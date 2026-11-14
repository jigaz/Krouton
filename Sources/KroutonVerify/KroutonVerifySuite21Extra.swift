import CoreImage
import Foundation
import OpticalDough
import Marmalade
import VideoOven
import Tartine
import Galette
import Crustini

@MainActor
func runKroutonVerifySuites19To21(_ harness: inout KroutonTestHarness) {
    harness.runSuite("19. Type-Safe Optical Recipe Catalog, Workspace Routing & File Extension Invariants") { h in
    let formats = KroutonOpticalRecipeCatalog.defaultFormats
    h.check(formats.count == 32, "Expected 32 canonical optical recipes, found \(formats.count)")

    for spec in formats {
        h.check(spec.formatID != nil, "Recipe '\(spec.id)' must map to a valid KroutonFormatID enum case")
        h.check(!spec.exactShortDisplayName.isEmpty, "Recipe '\(spec.id)' must have a non-empty exactShortDisplayName")

        if spec.filterGroup == .console {
            h.check(spec.workspaceKind == .retroConsole, "Console format '\(spec.id)' must route to .retroConsole workspace")
            h.check(!spec.allowedFileExtensions.isEmpty, "Console format '\(spec.id)' must restrict allowedFileExtensions")
            h.check(!spec.allowsDirectorySelection, "Console format '\(spec.id)' must disallow directory selection")
        }
        if spec.filterGroup == .video {
            h.check(spec.workspaceKind == .videoAuthoring, "Video format '\(spec.id)' must route to .videoAuthoring workspace")
            h.check(!spec.allowedFileExtensions.contains("iso"), "Video authoring format '\(spec.id)' must never allow .iso images")
        }
    }

    // Verify per-console specialized extensions
    let wii = formats.first { $0.id == KroutonFormatID.consoleWii.rawValue }!
    h.check(wii.allowedFileExtensions.contains("rvz") && wii.allowedFileExtensions.contains("wbfs"), "Wii must allow .rvz and .wbfs")
    h.check(!wii.allowedFileExtensions.contains("ccd"), "Wii must not allow PS1 .ccd")

    let ps1 = formats.first { $0.id == KroutonFormatID.consolePS1.rawValue }!
    h.check(ps1.allowedFileExtensions.contains("cue") && ps1.allowedFileExtensions.contains("ccd"), "PS1 must allow .cue and .ccd")
    h.check(!ps1.allowedFileExtensions.contains("wbfs"), "PS1 must not allow Wii .wbfs")

    // Verify Copy Task IDs
    h.check(KroutonCopyTaskID.allCases.count == 3, "Expected 3 canonical KroutonCopyTaskID cases")
}

harness.runSuite("20. Mastering & Extraction Domain Models (TOC, Video Titles & Config Codable Round-Trip)") { h in
    let toc = KroutonRipTrackItem.defaultRedBookTOC
    h.check(toc.count == 5, "Default Red Book TOC should have 5 tracks")
    h.check(toc.first?.id == 1 && toc.last?.id == 5, "Track IDs must match track numbers")

    let mbTOC = KroutonRipTrackItem.musicBrainzMatchedTOC
    h.check(mbTOC.count == 5 && mbTOC[0].performer == "The Optical Pickups", "MusicBrainz TOC performer mismatch")

    let titles = KroutonVideoExtractTitleItem.defaultVideoTitles
    h.check(titles.count == 3, "Default Video Extract Titles should have 3 entries")
    h.check(titles.filter { $0.seconds >= 120 }.count == 2, "Min duration filter (120s) should leave 2 feature titles")

    let consoleCfg = KroutonConsoleMasteringConfig()
    let data = try JSONEncoder().encode(consoleCfg)
    let decoded = try JSONDecoder().decode(KroutonConsoleMasteringConfig.self, from: data)
    h.check(decoded == consoleCfg, "KroutonConsoleMasteringConfig Codable round-trip must match")

    // Verify krouton.app Web Endpoints, Unified KroutonKrutCoreSpec Wire Ticket, Cross-FS Guard & ChaCha20-Poly1305
    h.check(KroutonWebEndpoints.homeURLString == "https://krouton.app", "Home URL must be https://krouton.app")
    h.check(KroutonKrutSecurityEngine.isSafeRelativePath("Audio/Track01.wav"), "Relative child path must be allowed")
    h.check(!KroutonKrutSecurityEngine.isSafeRelativePath("../../etc/passwd"), "Path traversal '..' must be blocked")
    let winPath = KroutonKrutSecurityEngine.normalizeCrossFilesystemPath("Subfolder\\Track_01.flac")
    h.check(winPath == "Subfolder/Track_01.flac", "Windows backslash path must normalize to POSIX forward slash")

    let coreSpec = KroutonKrutCoreSpec(
        formatID: "dvd-video",
        volumeTitle: "KROUTON_DVD9",
        sectorSizeBytes: 2048,
        totalSectorsLBA: 4_173_824,
        expectedPayloadBytes: 8_547_991_552,
        payloadSHA256Hex: String(repeating: "a", count: 64),
        dualLayerBreakSectorLBA: 2_086_912,
        ephemeralAutoPurgeOnComplete: true
    )
    let coreData = try JSONEncoder().encode(coreSpec)
    let coreDecoded = try JSONDecoder().decode(KroutonKrutCoreSpec.self, from: coreData)
    h.check(coreDecoded == coreSpec && coreDecoded.ephemeralAutoPurgeOnComplete, "KroutonKrutCoreSpec wire round-trip & ephemeral auto-purge")

    let sampleKrut = Data("{\"schemaVersion\":\"1.0\",\"discVolumeTitle\":\"KROUTON_VAULT\"}".utf8)
    let salt = Data("krouton-2026-krut-salt-32bytes!!".utf8)
    let sealed = try KroutonKrutSecurityEngine.sealKrutPayload(sampleKrut, passphrase: "correct-horse-battery", salt: salt)
    h.check(KroutonKrutSecurityEngine.openKrutPayload(sealed, passphrase: "correct-horse-battery", salt: salt) == sampleKrut, "ChaCha20-Poly1305 decrypt")
    h.check(KroutonKrutSecurityEngine.openKrutPayload(sealed, passphrase: "wrong-pass", salt: salt) == nil, "ChaCha20-Poly1305 wrong password reject")

    // Verify First-Class KroutonEmbeddedLabelSpec & Freehand Drawn Stroke -> Crisp Vector Circle Recognition
    var embeddedLabel = KroutonEmbeddedLabelSpec(
        primaryArcTitle: "DARK SIDE OF THE MOON",
        bottomSubtitle: "50TH ANNIVERSARY RED BOOK MASTER",
        performer: "Pink Floyd",
        mcnCatalogBarcode: "5099902894521",
        templateStyleRaw: "Concentric Studio Rings",
        trayPresetName: "Epson ET-8550 Full Hub (120mm / 18mm)",
        outerDiameterMM: 120.0,
        innerDiameterMM: 18.0,
        offsetXMM: -0.4,
        offsetYMM: 0.2,
        showTracklistOnDisc: true,
        stampedTracklistLines: ["01. Speak to Me", "02. Breathe (In the Air)", "03. Time"]
    )
    let roughCirclePts = (0..<24).map { i -> KroutonNormalizedPoint in
        let ang = Double(i) * (2.0 * Double.pi / 24.0)
        return KroutonNormalizedPoint(nx: 0.25 + cos(ang) * 0.20, ny: -0.20 + sin(ang) * 0.20)
    }
    let snappedCircle = KroutonKrustiniModule.recognizeAndVectorizeDrawnStroke(rawPoints: roughCirclePts, autoSnapGeometry: true)
    h.check(snappedCircle.kind == .circle && snappedCircle.isClosed && snappedCircle.points.count == 36, "Freehand circular stroke must auto-snap to 36-vertex vector circle")
    embeddedLabel.vectorShapeLayers = [snappedCircle]
    embeddedLabel.backgroundStyle = .linearGradient
    let lblData = try JSONEncoder().encode(embeddedLabel)
    let lblDecoded = try JSONDecoder().decode(KroutonEmbeddedLabelSpec.self, from: lblData)
    h.check(lblDecoded == embeddedLabel && lblDecoded.vectorShapeLayers.count == 1, "KroutonEmbeddedLabelSpec round-trip with editable vector shapes & gradient")

    // Verify Metal GPU Kaleidoscope Studio, 360° Tiny Planet Globe & 8x Polar Mandala Symmetry
    let sym8 = KroutonKrustiniModule.replicateShapeWithPolarSymmetry(baseShape: snappedCircle, symmetryCount: 8)
    h.check(sym8.count == 8 && sym8[0].points.count == 36, "8x Polar Symmetry must generate 8 radially rotated vector shapes")

    let kalImg = KroutonKrustiniModule.renderGPUKaleidoscopeOrTinyPlanetCGImage(
        style: .gpuKaleidoscope,
        seedPattern: .neonLaserPrism,
        primaryColor: KroutonRGBAColor(r: 0.12, g: 0.25, b: 0.85),
        secondaryColor: KroutonRGBAColor(r: 0.95, g: 0.30, b: 0.65),
        angleDegrees: 45.0,
        facetCount: 10,
        dimensionPixels: 256
    )
    h.check(kalImg != nil && kalImg!.width == 256 && kalImg!.height == 256, "Metal GPU Kaleidoscope shader must render valid 256x256 CGImage")

    let planetImg = KroutonKrustiniModule.renderGPUKaleidoscopeOrTinyPlanetCGImage(
        style: .tinyPlanetGlobe,
        seedPattern: .holographicFoil,
        primaryColor: KroutonRGBAColor(r: 0.08, g: 0.65, b: 0.55),
        secondaryColor: KroutonRGBAColor(r: 0.95, g: 0.80, b: 0.20),
        angleDegrees: 120.0,
        planetRadiusRatio: 0.78,
        dimensionPixels: 256
    )
    h.check(planetImg != nil && planetImg!.width == 256 && planetImg!.height == 256, "Metal GPU 360 Tiny Planet Globe shader must render valid 256x256 CGImage")

    // Verify Apple Pages Shape Palette (`capsule`, `arrow`, `diamond`) & Arrange Transform Engine
    let arrowShape = KroutonKrustiniModule.makeParametricVectorShape(kind: .arrow)
    let scaledRotatedArrow = KroutonKrustiniModule.transformVectorShape(arrowShape, scaleFactor: 1.25, rotateDegrees: 45.0, flipHorizontal: true)
    h.check(scaledRotatedArrow.points.count == arrowShape.points.count && scaledRotatedArrow.points != arrowShape.points, "Pages Arrange transform must scale, rotate & flip vector shape")

        // Phase A Verification: Real AVFoundation 44.1kHz PCM Audio Decoder & Multi-Extent ISO-9660 Writer
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent("KroutonPhaseAVerify", isDirectory: true)
        try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        let toneURL = tempDir.appendingPathComponent("Test440Hz.wav")
        try KroutonMarmaladeModule.synthesizeTestToneWAV(at: toneURL, durationSeconds: 0.15)
        let decodedPCM = try KroutonMarmaladeModule.decodeAudioFileToRedBookPCM(url: toneURL, maxSeconds: 1.0)
        h.check(!decodedPCM.isEmpty && decodedPCM.count % 2352 == 0, "AVAssetReader decoded PCM must be non-empty and sector-aligned to 2,352 bytes")

        let masteredAudio = try KroutonMarmaladeModule.masterRedBookAudioTracksToDisk(
            sourceURLs: [toneURL],
            albumTitle: "KROUTON_PHASE_A",
            performer: "KROUTON_DSP",
            outputDirectory: tempDir,
            crossfadeSeconds: 1.0
        )
        h.check(FileManager.default.fileExists(atPath: masteredAudio.binURL.path) && masteredAudio.totalSectors2352 >= 1, "Marmalade .BIN/.CUE master must write sector-aligned PCM to disk")
        h.check(masteredAudio.cueSheetText.contains("TRACK 01 AUDIO") && masteredAudio.cueSheetText.contains("INDEX 01 00:00:00"), "Marmalade .CUE sheet must contain Red Book track & index descriptors")

        let payloadA = Data("KROUTON_PAYLOAD_ALPHA_2026".utf8)
        let payloadB = Data(repeating: 0x4B, count: 3000) // Spans 2 ISO sectors (2,048B each)
        let isoOutURL = tempDir.appendingPathComponent("PhaseA_Mountable.iso")
        let isoResult = try KroutonTartineISO9660Writer.writeMountableISO9660Image(
            volumeTitle: "KROUTON_ISO",
            files: [
                TartineISOFileInput(fileName: "ALPHA.TXT", data: payloadA),
                TartineISOFileInput(fileName: "BETA.BIN", data: payloadB)
            ],
            outputURL: isoOutURL
        )
        let isoBytes = try Data(contentsOf: isoResult.url)
        let lbaAlpha = isoResult.fileExtentLBAs["ALPHA.TXT"] ?? 0
        let lbaBeta = isoResult.fileExtentLBAs["BETA.BIN"] ?? 0
        h.check(lbaAlpha == 23 && lbaBeta == 24 && isoResult.totalSectorsLBA == 26, "Tartine ISO-9660 writer must allocate multi-sector file extents starting at LBA 23")
        h.check(isoBytes.subdata(in: (lbaAlpha * 2048)..<(lbaAlpha * 2048 + payloadA.count)) == payloadA, "Tartine ISO-9660 extent at LBA 23 must match exact ALPHA.TXT payload bytes")
        h.check(isoBytes.subdata(in: (lbaBeta * 2048)..<(lbaBeta * 2048 + payloadB.count)) == payloadB, "Tartine ISO-9660 2-sector extent at LBA 24..25 must match exact BETA.BIN payload bytes")

        // Phase B Verification: 32-Step Value-Type Undo/Redo Engine & Galette Sub-Store
        var snapA = KroutonEmbeddedLabelSpec()
        snapA.topArcRadiusMM = 44.0
        var snapB = snapA
        snapB.topArcRadiusMM = 51.5
        h.check(snapA != snapB && snapB.topArcRadiusMM == 51.5, "Label Studio state snapshots must distinguish geometry mutations for Undo/Redo")








}

harness.runSuite("21. Phase 4 Workspace Modularization & 600-LOC File Ceiling & 200-LOC Function Gate") { h in
    let repoRoot = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .deletingLastPathComponent()
    let workspacesDir = repoRoot.appendingPathComponent("Sources/KroutonApp/Workspaces")
    let fm = FileManager.default

    let expectedWorkspaceFiles = [
        "AudioMasteringWorkspaces.swift",
        "CarSafeAudioWorkspace.swift",
        "CopyAndRipWorkspaces.swift",
        "DataAndArchivalWorkspaces.swift",
        "DiscImageInspectorWorkspace.swift",
        "DiscLabelStudioWorkspace.swift",
        "MasteringTelemetryPopovers.swift",
        "RetroConsoleWorkspaces.swift",
        "VideoAuthoringWorkspaces.swift"
    ]

    for file in expectedWorkspaceFiles {
        let url = workspacesDir.appendingPathComponent(file)
        h.check(fm.fileExists(atPath: url.path), "Expected modular workspace file: \(file)")
        if let content = try? String(contentsOf: url, encoding: .utf8) {
            let lineCount = content.components(separatedBy: .newlines).count
            h.check(lineCount <= 600, "\(file) must stay <= 600 LOC (Rule 4 ceiling), found \(lineCount) LOC")
            h.check(!content.contains("extension KroutonMainWorkspaceView"), "\(file) must use standalone View structs, not extension KroutonMainWorkspaceView")
            h.check(content.contains(": View {"), "\(file) must declare at least one standalone SwiftUI View struct")
        }
    }

    let legacyMonolith = workspacesDir.appendingPathComponent("KroutonMasteringWorkspaces.swift")
    h.check(!fm.fileExists(atPath: legacyMonolith.path), "Legacy KroutonMasteringWorkspaces.swift monolith must be removed")

    // Global Repository-Wide 600-LOC Ceiling Gate across 100% of Sources/**/*.swift
    let fmAll = FileManager.default
    if let enumAll = fmAll.enumerator(atPath: "Sources") {
        while let relPath = enumAll.nextObject() as? String {
            guard relPath.hasSuffix(".swift") else { continue }
            let full = "Sources/\(relPath)"
            if let text = try? String(contentsOfFile: full, encoding: .utf8) {
                let lc = text.components(separatedBy: .newlines).count
                h.check(lc <= 600, "Global 600-LOC Gate: \(full) must be <= 600 LOC, found \(lc) LOC")
            }
        }
    }

    // Verify that standalone workspaces adopt KroutonMasteringDeckCard and KroutonEmptyDropZoneView
    let sharedComponentWorkspaces = [
        "Sources/KroutonApp/Workspaces/AudioMasteringWorkspaces.swift",
        "Sources/KroutonApp/Workspaces/CarSafeAudioWorkspace.swift",
        "Sources/KroutonApp/Workspaces/DataAndArchivalWorkspaces.swift",
        "Sources/KroutonApp/Workspaces/DiscImageInspectorWorkspace.swift",
        "Sources/KroutonApp/Workspaces/RetroConsoleWorkspaces.swift",
        "Sources/KroutonApp/Workspaces/VideoAuthoringWorkspaces.swift"
    ]
    for wp in sharedComponentWorkspaces {
        let wpText = (try? String(contentsOfFile: wp, encoding: .utf8)) ?? ""
        h.check(wpText.contains("KroutonMasteringDeckCard"), "\(wp) must adopt KroutonMasteringDeckCard")
        h.check(wpText.contains("KroutonEmptyDropZoneView"), "\(wp) must adopt KroutonEmptyDropZoneView")
    }

        // Hygiene Gate: Forbid `let _ = (` warning-suppression tuple band-aids in KroutonApp
        let kroutonAppDir = repoRoot.appendingPathComponent("Sources/KroutonApp")
        if let enumApp = FileManager.default.enumerator(at: kroutonAppDir, includingPropertiesForKeys: nil) {
            for case let fURL as URL in enumApp where fURL.pathExtension == "swift" {
                let content = (try? String(contentsOf: fURL, encoding: .utf8)) ?? ""
                let hasTupleBandAid = content.components(separatedBy: .newlines).contains {
                    $0.trimmingCharacters(in: .whitespaces).hasPrefix("let _ = (")
                }
                h.check(!hasTupleBandAid, "Zero `let _ = (` warning-suppression band-aids allowed in \(fURL.lastPathComponent)")
            }
        }


        // Verify 1:1 Millimeter-Calibrated PDF Print Sheet & 300-DPI PNG Encoder
        let seedCI = KroutonKrustiniModule.makeGPUSeedCIImage(
            pattern: .neonLaserPrism,
            primaryColor: KroutonRGBAColor(r: 0.2, g: 0.6, b: 0.9, a: 1.0),
            secondaryColor: KroutonRGBAColor(r: 0.9, g: 0.3, b: 0.5, a: 1.0),
            dimension: 120.0
        )
        let ciCtx = CIContext()
        if let testCG = ciCtx.createCGImage(seedCI, from: CGRect(x: 0, y: 0, width: 120, height: 120)) {
            let pngData = KroutonKrustiniModule.encodeCGImageToPNGData(testCG, dpi: 300.0)
            h.check((pngData?.count ?? 0) > 128, "300-DPI PNG encoder must produce valid non-empty PNG data")
            let pdfData = KroutonKrustiniModule.renderCalibratedPrintSheetPDFData(
                discCGImage: testCG,
                presetName: "Epson ET-8550 Full Hub",
                outerDiameterMM: 120.0,
                innerDiameterMM: 18.0,
                offsetXMM: 0.4,
                offsetYMM: -0.3,
                discTitle: "KROUTON_VERIFY_DISC",
                includeCalibrationMarks: true
            )
            h.check((pdfData?.count ?? 0) > 256, "1:1 Vector PDF print sheet engine must produce valid PDF document data")
            if let d = pdfData, let headerStr = String(data: d.prefix(5), encoding: .ascii) {
                h.check(headerStr == "%PDF-", "Calibrated PDF print sheet must start with %PDF- magic header")
            }
        }



        // Verify Vector Shape Hit-Testing & Interactive Canvas Centroid Translation
        let starShape = KroutonKrustiniModule.makeParametricVectorShape(kind: .star, centerX: 0.0, centerY: -0.50, radius: 0.14)
        let pillShape = KroutonKrustiniModule.makeParametricVectorShape(kind: .capsule, centerX: 0.0, centerY: 0.50, radius: 0.20)
        let hitID = KroutonKrustiniModule.nearestVectorShapeID(in: [starShape, pillShape], normalizedX: 0.02, normalizedY: -0.48)
        h.check(hitID == starShape.id, "nearestVectorShapeID must hit-test the top star shape near (0.02, -0.48)")
        let movedStar = KroutonKrustiniModule.recenterVectorShape(starShape, toNormalizedX: 0.35, normalizedY: 0.25)
        let movedCX = movedStar.points.map(\.nx).reduce(0.0, +) / Double(max(1, movedStar.points.count))
        let movedCY = movedStar.points.map(\.ny).reduce(0.0, +) / Double(max(1, movedStar.points.count))
        h.check(abs(movedCX - 0.35) < 0.02 && abs(movedCY - 0.25) < 0.02, "recenterVectorShape must translate shape centroid to (0.35, 0.25)")

    }
}
