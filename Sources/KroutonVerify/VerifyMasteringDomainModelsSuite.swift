import AudioKit
import BurnKit
import CoreImage
import CryptoKit
import DriveKit
import Foundation
import ImageKit
import LabelKit
import NetworkSpool
import OpticalCore
import Persistence
import RescueKit
import VideoKit

func runVerifyMasteringDomainModelsSuite(_ harness: inout KroutonTestHarness) {
    harness.runSuite("15. Mastering & Extraction Domain Models (TOC, Video Titles, Track Montage & Config Round-Trip)") { h in
    h.check(KroutonRipTrackItem.defaultRedBookTOC.isEmpty, "Default Red Book TOC must be empty (no fake tracks)")
    h.check(KroutonRipTrackItem.musicBrainzMatchedTOC.isEmpty, "MusicBrainz fallback TOC must be empty")
    h.check(KroutonVideoExtractTitleItem.defaultVideoTitles.isEmpty, "Default Video Titles must be empty")
    let sampleTrack = KroutonRipTrackItem(num: 1, title: "Track 01", performer: "", duration: "04:34:23", arStatus: "Ready")
    h.check(sampleTrack.id == 1, "Track ID must match track number")

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
        templateStyleRaw: "Concentric Workspace Rings",
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
    let snappedCircle = KroutonLabelGeometryEngine.recognizeAndVectorizeDrawnStroke(rawPoints: roughCirclePts, autoSnapGeometry: true)
    h.check(snappedCircle.kind == .circle && snappedCircle.isClosed && snappedCircle.points.count == 36, "Freehand circular stroke must auto-snap to 36-vertex vector circle")
    embeddedLabel.vectorShapeLayers = [snappedCircle]
    embeddedLabel.backgroundStyle = .linearGradient
    let lblData = try JSONEncoder().encode(embeddedLabel)
    let lblDecoded = try JSONDecoder().decode(KroutonEmbeddedLabelSpec.self, from: lblData)
    h.check(lblDecoded == embeddedLabel && lblDecoded.vectorShapeLayers.count == 1, "KroutonEmbeddedLabelSpec round-trip with editable vector shapes & gradient")

    // Verify Metal GPU Kaleidoscope Workspace, 360° Tiny Planet Globe & 8x Polar Mandala Symmetry
    let sym8 = KroutonLabelGeometryEngine.replicateShapeWithPolarSymmetry(baseShape: snappedCircle, symmetryCount: 8)
    h.check(sym8.count == 8 && sym8[0].points.count == 36, "8x Polar Symmetry must generate 8 radially rotated vector shapes")

    let kalImg = KroutonLabelGeometryEngine.renderGPUKaleidoscopeOrTinyPlanetCGImage(
        style: .gpuKaleidoscope,
        seedPattern: .neonLaserPrism,
        primaryColor: KroutonRGBAColor(r: 0.12, g: 0.25, b: 0.85),
        secondaryColor: KroutonRGBAColor(r: 0.95, g: 0.30, b: 0.65),
        angleDegrees: 45.0,
        facetCount: 10,
        dimensionPixels: 256
    )
    h.check(kalImg != nil && kalImg!.width == 256 && kalImg!.height == 256, "Metal GPU Kaleidoscope shader must render valid 256x256 CGImage")

    let planetImg = KroutonLabelGeometryEngine.renderGPUKaleidoscopeOrTinyPlanetCGImage(
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
    let arrowShape = KroutonLabelGeometryEngine.makeParametricVectorShape(kind: .arrow)
    let scaledRotatedArrow = KroutonLabelGeometryEngine.transformVectorShape(arrowShape, scaleFactor: 1.25, rotateDegrees: 45.0, flipHorizontal: true)
    h.check(scaledRotatedArrow.points.count == arrowShape.points.count && scaledRotatedArrow.points != arrowShape.points, "Pages Arrange transform must scale, rotate & flip vector shape")

        // Phase A Verification: Real AVFoundation 44.1kHz PCM Audio Decoder & Multi-Extent ISO-9660 Writer
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent("KroutonPhaseAVerify", isDirectory: true)
        try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        let toneURL = tempDir.appendingPathComponent("Test440Hz.wav")
        try KroutonAudioEngine.synthesizeTestToneWAV(at: toneURL, durationSeconds: 0.15)
        let decodedPCM = try KroutonAudioEngine.decodeAudioFileToRedBookPCM(url: toneURL, maxSeconds: 1.0)
        h.check(!decodedPCM.isEmpty && decodedPCM.count % 2352 == 0, "AVAssetReader decoded PCM must be non-empty and sector-aligned to 2,352 bytes")

        let masteredAudio = try KroutonAudioEngine.masterRedBookAudioTracksToDisk(
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
        let isoResult = try KroutonHybridISO9660Writer.writeMountableISO9660Image(
            volumeTitle: "KROUTON_ISO",
            files: [
                HybridISOFileInput(fileName: "ALPHA.TXT", data: payloadA),
                HybridISOFileInput(fileName: "BETA.BIN", data: payloadB)
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
        h.check(snapA != snapB && snapB.topArcRadiusMM == 51.5, "Label Workspace state snapshots must distinguish geometry mutations for Undo/Redo")

        // Verify AudioProject Layout & UserEdited Invariants
        var proj = AudioProject()
        let u1 = URL(fileURLWithPath: "/tmp/track01.wav")
        let u2 = URL(fileURLWithPath: "/tmp/track02.wav")
        let u3 = URL(fileURLWithPath: "/tmp/track03.wav")
        let added = proj.append([u1, u2, u3])
        h.check(added.count == 3 && proj.tracks.count == 3, "AudioProject.append must add 3 distinct tracks")
        for trk in proj.tracks {
            var g = KroutonTrackTransitionSpec()
            g.overlapSeconds = 0
            g.preGapSeconds = 2.0
            proj.update(trk.id) { $0.frameCount = 450; $0.transitionToNext = g }
        }
        let (layNoX, issuesNoX) = proj.layout()
        h.check(issuesNoX.isEmpty && layNoX?.count == 3, "Analysed 3-track project must produce a clean layout")
        if let lay = layNoX {
            for idx in 0..<lay.count {
                if idx > 0 { h.check(lay[idx].audioStart >= lay[idx - 1].audioStart, "audioStart must be non-decreasing") }
                if let i00 = lay[idx].index00 { h.check(i00 <= lay[idx].index01, "index00 <= index01 where index00 exists") }
            }
            h.check(proj.totalFrames == (450 * 3 + 150 * 2), "With no crossfades, totalFrames must equal sum(frameCount) + sum(gaps)")
        }
        let id1 = proj.tracks[0].id, id2 = proj.tracks[1].id
        proj.update(id1) { $0.title = "Custom Typed Title"; $0.userEdited.insert(.title) }
        proj.update(id1) { $0.applyScanned(title: "Scanned Tag Title", performer: "Scanned Artist", isrc: "USABC2600001") }
        h.check(proj.track(id1)?.title == "Custom Typed Title", "applyScanned must never overwrite a field listed in userEdited")
        h.check(proj.track(id1)?.performer == "Scanned Artist" && proj.track(id1)?.isrc == "USABC2600001", "applyScanned must populate unedited fields and valid ISRC")
        let snapTrack2 = proj.track(id2)
        proj.move(id1, by: 1)
        h.check(proj.track(id2) == snapTrack2, "move must never mutate any other track's fields")

        // Verify SpliceOverlapMath Invariants
        var xSpec = KroutonTrackTransitionSpec()
        xSpec.overlapSeconds = 2.0
        xSpec.preGapSeconds = 0.0
        xSpec.fadeOutCurve = .equalPower
        xSpec.fadeInCurve = .equalPower
        let silentPeaks = FramePeaks(values: [Float](repeating: 0, count: 200))
        h.check(SpliceOverlapMath.peakUpperBound(outgoingTail: silentPeaks, incomingHead: silentPeaks, spec: xSpec) == 0.0, "Silence on both sides must give 0.0 peak bound")
        let unityPeaks = FramePeaks(values: [Float](repeating: 1.0, count: 200))
        if let eqBound = SpliceOverlapMath.peakUpperBound(outgoingTail: unityPeaks, incomingHead: unityPeaks, spec: xSpec) {
            h.check(abs(eqBound - sqrt(2.0)) < 0.03, "Full-scale on both sides with equal-power curves must give ~1.414 (+3.0 dB)")
        }
        let shortPeaks = FramePeaks(values: [Float](repeating: 0.8, count: 50))
        h.check(SpliceOverlapMath.peakUpperBound(outgoingTail: shortPeaks, incomingHead: unityPeaks, spec: xSpec) == nil, "Overlap longer than analysed window must return nil, never a guess")

        // Verify AudioProject -> .CUE Compiler (Boundary N -> N+1 Pregap & Crossfade Splice Placement)
        var cueProj = AudioProject(albumTitle: "RUMOURS", albumPerformer: "FLEETWOOD MAC", upc: "0075992731324", writeCDText: true)
        let _ = cueProj.append([
            URL(fileURLWithPath: "/tmp/01_Second_Hand_News.wav"),
            URL(fileURLWithPath: "/tmp/02_Dreams.wav"),
            URL(fileURLWithPath: "/tmp/03_Never_Going_Back.wav")
        ])
        let c1 = cueProj.tracks[0].id, c2 = cueProj.tracks[1].id, c3 = cueProj.tracks[2].id
        // Track 1 (450 frames = 00:06:00) followed by a 2.0s (150 frames) pause before Track 2
        cueProj.update(c1) {
            $0.title = "Second Hand News"
            $0.frameCount = 450
            $0.transitionToNext = KroutonTrackTransitionSpec(overlapSeconds: 0.0, preGapSeconds: 2.0)
        }
        // Track 2 (600 frames = 00:08:00) followed by a 2.0s (150 frames) crossfade into Track 3 (50% splice ratio)
        cueProj.update(c2) {
            $0.title = "Dreams"
            $0.frameCount = 600
            $0.transitionToNext = KroutonTrackTransitionSpec(overlapSeconds: 2.0, preGapSeconds: 0.0, spliceIndex01Ratio: 0.50)
        }
        cueProj.update(c3) {
            $0.title = "Never Going Back Again"
            $0.frameCount = 450
        }
        let compiledCue = cueProj.compileCueSheet() ?? ""
        h.check(compiledCue.contains("CATALOG 0075992731324"), ".CUE compiler must emit validated 13-digit CATALOG")
        h.check(compiledCue.contains("  TRACK 01 AUDIO\n    TITLE \"Second Hand News\"\n    PERFORMER \"FLEETWOOD MAC\"\n    INDEX 01 00:00:00"), "TRACK 01 must start at INDEX 01 00:00:00 with no INDEX 00 from its own transitionToNext")
        h.check(compiledCue.contains("  TRACK 02 AUDIO\n    TITLE \"Dreams\"\n    PERFORMER \"FLEETWOOD MAC\"\n    INDEX 00 00:06:00\n    INDEX 01 00:08:00"), "Track 1's 2s pause must land as TRACK 02's INDEX 00 (00:06:00) -> INDEX 01 (00:08:00)")
        // Track 2 audio runs 600..1200f (00:08:00..00:16:00). A 150f crossfade starts Track 3 audio at 1050f (00:14:00) and places INDEX 01 at 1050 + 75 = 1125f (00:15:00)
        h.check(compiledCue.contains("  TRACK 03 AUDIO\n    TITLE \"Never Going Back Again\"\n    PERFORMER \"FLEETWOOD MAC\"\n    INDEX 01 00:15:00"), "Track 2's 2s crossfade (50% ratio) must place TRACK 03 INDEX 01 at 00:15:00 with no INDEX 00")

        // Verify Track Montage Editor: 30s Crossfade Clamping, 1x/3x Zoom Geometry & Track-Aware INDEX 02..99 .CUE Emission
        let maxFadeSpec = KroutonTrackTransitionSpec(
            overlapSeconds: 45.0,
            preGapSeconds: 0.0,
            subIndexRatios: [0.75, 0.25, 1.40, 0.01]
        )
        h.check(maxFadeSpec.overlapSeconds == 30.0 && maxFadeSpec.overlapRedBookFrames == 2250,
                "KroutonTrackTransitionSpec must clamp overlapSeconds ceiling to 30.0s (2,250 Red Book frames)")
        h.check(maxFadeSpec.subIndexRatios == [0.05, 0.25, 0.75, 0.95],
                "subIndexRatios must clamp to [0.05, 0.95] and sort ascending")

        let canvasSize = CGSize(width: 600, height: 174)
        let fade4s = KroutonTrackTransitionSpec(
            overlapSeconds: 4.0,
            preGapSeconds: 0.0,
            spliceIndex01Ratio: 0.50,
            subIndexRatios: [0.35, 0.15, 0.82, 0.64]
        )
        let geom1x = SpliceCanvasGeometry(size: canvasSize, spec: fade4s, horizontalZoom: 1.0)
        let geom3x = SpliceCanvasGeometry(size: canvasSize, spec: fade4s, horizontalZoom: 3.0)
        h.check(abs(geom1x.effectiveSpanSeconds - 34.0) < 1e-6, "1x horizontal zoom must span 34.0 seconds")
        h.check(abs(geom3x.effectiveSpanSeconds - (34.0 / 3.0)) < 1e-6, "3x horizontal zoom must span 11.333 seconds")
        h.check((geom3x.zoneX1 - geom3x.zoneX0) > (geom1x.zoneX1 - geom1x.zoneX0) * 2.2,
                "3x zoom must widen the rendered crossfade zone proportionally vs 1x zoom")
        h.check(geom1x.subIndexDescriptors.count == 4, "Expected 4 track-aware subIndexDescriptors")
        if geom1x.subIndexDescriptors.count == 4 {
            let d0 = geom1x.subIndexDescriptors[0]
            let d1 = geom1x.subIndexDescriptors[1]
            let d2 = geom1x.subIndexDescriptors[2]
            let d3 = geom1x.subIndexDescriptors[3]
            h.check(!d0.isIncomingTrack && d0.redBookIndexNumber == 2, "First left-of-INDEX-01 marker must be Outgoing Track INDEX 02")
            h.check(!d1.isIncomingTrack && d1.redBookIndexNumber == 3, "Second left-of-INDEX-01 marker must be Outgoing Track INDEX 03")
            h.check(d2.isIncomingTrack && d2.redBookIndexNumber == 2, "First right-of-INDEX-01 marker must switch to Incoming Track INDEX 02")
            h.check(d3.isIncomingTrack && d3.redBookIndexNumber == 3, "Second right-of-INDEX-01 marker must be Incoming Track INDEX 03")
        }

        // Verify AudioProject.compileCueSheet emits left-of-INDEX-01 sub-indexes on Track 1 and right-of-INDEX-01 sub-indexes on Track 2
        var subCueProj = AudioProject(albumTitle: "LIVE CONCERT MONTAGE", albumPerformer: "KROUTON ENSEMBLE", writeCDText: true)
        let _ = subCueProj.append([
            URL(fileURLWithPath: "/tmp/01_Overture.wav"),
            URL(fileURLWithPath: "/tmp/02_Finale.wav")
        ])
        let t1ID = subCueProj.tracks[0].id, t2ID = subCueProj.tracks[1].id
        subCueProj.update(t1ID) {
            $0.title = "Overture"
            $0.frameCount = 900
            $0.transitionToNext = KroutonTrackTransitionSpec(
                overlapSeconds: 0.0,
                preGapSeconds: 0.0,
                spliceIndex01Ratio: 0.50,
                subIndexRatios: [0.25, 0.50, 0.75]
            )
        }
        subCueProj.update(t2ID) {
            $0.title = "Finale"
            $0.frameCount = 900
        }
        let subCueText = subCueProj.compileCueSheet() ?? ""
        h.check(subCueText.contains("  TRACK 01 AUDIO\n    TITLE \"Overture\"\n    PERFORMER \"KROUTON ENSEMBLE\"\n    INDEX 01 00:00:00\n    INDEX 02 00:03:00\n    INDEX 03 00:06:00"),
                "Left-of-INDEX-01 subIndexRatios (0.25, 0.50) must emit as TRACK 01 INDEX 02 and INDEX 03")

        // Verify Drag Reordering, CD-TEXT Constraint Enforcement & Multi-Track Batch Operations
        let rawDirtyText = "  “Live” — in Oakland\u{0007}\u{001B} — " + String(repeating: "A", count: 80)
        let sanitizedText = AudioProject.sanitizeCDTextField(rawDirtyText)
        h.check(sanitizedText.count <= 60 && !sanitizedText.contains("\u{0007}") && sanitizedText.contains("\"Live\" -- in Oakland"),
                "AudioProject.sanitizeCDTextField must fold curly quotes/em-dashes, strip control chars, and cap at 60 chars")
        h.check(AudioProject.sanitizeUPCField("0123-4567-89012-999") == "0123456789012",
                "AudioProject.sanitizeUPCField must keep only digits and cap at 13 characters")

        var batchProj = AudioProject(albumTitle: "BATCH TEST", albumPerformer: "THE CHECKBOXES")
        let _ = batchProj.append([
            URL(fileURLWithPath: "/tmp/a.wav"),
            URL(fileURLWithPath: "/tmp/b.wav"),
            URL(fileURLWithPath: "/tmp/c.wav")
        ])
        let idA = batchProj.tracks[0].id, idB = batchProj.tracks[1].id, idC = batchProj.tracks[2].id
        batchProj.moveTrack(from: 2, to: 0)
        h.check(batchProj.tracks.map(\.id) == [idC, idA, idB], "moveTrack(from: 2, to: 0) must move Track C to index 0")

        let selSet: Set<UUID> = [idC, idB]
        batchProj.applyBatchPerformer("Featured Guest", to: selSet)
        h.check(batchProj.track(idC)?.performer == "Featured Guest" && batchProj.track(idA)?.performer == "",
                "applyBatchPerformer must update only selected tracks")

        let assignedCount = batchProj.assignSequentialISRCs(baseISRC: "US-KRO-26-00010", to: selSet)
        h.check(assignedCount == 2 && batchProj.track(idC)?.isrc == "USKRO2600010" && batchProj.track(idB)?.isrc == "USKRO2600011",
                "assignSequentialISRCs must assign incrementing ISO 3901 ISRCs in disc order to selected tracks")


        // Verify On-Demand Mid-Curve Handles (Hidden by default -> Click to Spawn -> Drag -> Double-Click to Remove)
        var midSpec = KroutonTrackTransitionSpec(overlapSeconds: 6.0, preGapSeconds: 0.0)
        h.check(midSpec.fadeOutMidTrim == nil && midSpec.fadeInMidTrim == nil,
                "Mid-curve handles must be nil (hidden) by default")
        let geomBefore = SpliceCanvasGeometry(size: CGSize(width: 600, height: 174), spec: midSpec, horizontalZoom: 3.0)
        h.check(geomBefore.fadeOutMidHandle == nil && geomBefore.fadeInMidHandle == nil,
                "SpliceCanvasGeometry must not expose active mid handles while trims are nil")
        h.check(geomBefore.hitTestHiddenMidCurveVicinity(geomBefore.fadeOutMidAnchor) == .fadeOutMidHandle,
                "Clicking near t=0.25 on Fade-Out curve must hit-test hidden .fadeOutMidHandle")
        h.check(geomBefore.hitTestHiddenMidCurveVicinity(geomBefore.fadeInMidAnchor) == .fadeInMidHandle,
                "Clicking near t=0.75 on Fade-In curve must hit-test hidden .fadeInMidHandle")

        // Spawn only Fade-Out mid handle and drag it upward
        let baseGainOut25 = midSpec.effectiveGainOut(at: 0.25)
        let baseGainIn75  = midSpec.effectiveGainIn(at: 0.75)
        midSpec.fadeOutMidTrim = 0.0
        let geomWithOut = SpliceCanvasGeometry(size: CGSize(width: 600, height: 174), spec: midSpec, horizontalZoom: 3.0)
        h.check(geomWithOut.fadeOutMidHandle != nil && geomWithOut.fadeInMidHandle == nil,
                "Spawning Fade-Out mid handle must leave Fade-In mid handle hidden")
        if var outMidSession = SpliceDragSession(start: geomWithOut.fadeOutMidAnchor, spec: midSpec, geometry: geomWithOut) {
            h.check(outMidSession.target == .fadeOutMidHandle, "Hit-test on spawned Fade-Out mid handle must latch .fadeOutMidHandle")
            let bentSpec = outMidSession.spec(
                location: CGPoint(x: geomWithOut.fadeOutMidAnchor.x, y: geomWithOut.fadeOutMidAnchor.y - 30),
                translation: CGSize(width: 0, height: -30)
            )
            h.check((bentSpec.fadeOutMidTrim ?? 0) > 0.10 && bentSpec.effectiveGainOut(at: 0.25) > baseGainOut25,
                    "Dragging Fade-Out mid handle upward must boost effectiveGainOut(at: 0.25)")
            h.check(abs(bentSpec.effectiveGainIn(at: 0.75) - baseGainIn75) < 1e-9,
                    "Dragging Fade-Out mid handle must not alter Fade-In curve")
            h.check(abs(bentSpec.effectiveGainOut(at: 0.0) - 1.0) < 1e-9 && abs(bentSpec.effectiveGainOut(at: 1.0) - 0.0) < 1e-9,
                    "Mid-curve handle bell modulation must keep t=0 and t=1 endpoints pinned")
        } else {
            h.check(false, "Expected SpliceDragSession to latch .fadeOutMidHandle")
        }


        h.check(subCueText.contains("  TRACK 02 AUDIO\n    TITLE \"Finale\"\n    PERFORMER \"KROUTON ENSEMBLE\"\n    INDEX 01 00:12:00\n    INDEX 02"),
                "Right-of-INDEX-01 subIndexRatio (0.75) must cross into TRACK 02 as TRACK 02 INDEX 02")
    }
}
