import CoreImage
import CryptoKit
import Foundation
import OpticalCore
import AudioKit
import VideoKit
import ImageKit
import LabelKit
import RescueKit

@MainActor
func runKroutonVerifySuites11To21(_ harness: inout KroutonTestHarness) {
    harness.runSuite("8. Hardware Acceleration Codec Matrix & Container Stream Probing") { h in
    let matrix = KroutonMediaPrepEngine.liveHardwareCodecMatrix
    h.check(matrix.count >= 6, "Expected at least 6 codec rows in hardware matrix")

    let mkvProbe = KroutonMediaPrepEngine.probeFile(URL(fileURLWithPath: "/tmp/concert.mkv"))
    h.check(mkvProbe.fileExtension == "MKV" && mkvProbe.isHardwareAccelerated, "MKV hardware probe")

    let flacProbe = KroutonMediaPrepEngine.probeFile(URL(fileURLWithPath: "/tmp/master.flac"))
    h.check(flacProbe.accelerationTier == .accelerateSIMD, "FLAC Accelerate SIMD tier")
    }

    harness.runSuite("9. Red Book CD-Text, ISRC (ISO 3901) & MCN Sanitizer Constraints") { h in
    let sanitizedText = KroutonSeasoningSanitizer.sanitize("Café   Krouton — Live!\n\t")
    h.check(!sanitizedText.isEmpty && sanitizedText.allSatisfy { $0.isASCII }, "CD-Text ASCII sanitization")

    let isrc = KroutonSeasoningSanitizer.sanitizeISRC("us-kro-26-00001-extra")
    h.check(isrc == "USKRO2600001" && isrc.count == 12, "ISRC 12-char normalization")

    let mcn = KroutonSeasoningSanitizer.sanitizeMCN("0123-4567-89012-abc")
    h.check(mcn == "0123456789012" && mcn.count == 13, "MCN 13-digit EAN-13 normalization")
    }

    harness.runSuite("10. Red Book Audio Cube Frame (75 fps) & PCM Byte (2352 B/frame) Math") { h in
    let cube = KroutonAudioCube(
        url: URL(fileURLWithPath: "/tmp/test.wav"),
        title: "Track 01",
        performer: "Krouton Trio",
        songWriter: "Greybeard",
        isrcCode: "USKRO2600001",
        durationSeconds: 10.0,
        preGapSeconds: 2.0,
        crossfadeSeconds: 0.0,
        transitionStyle: .standard2s
    )
    h.check(cube.totalRedBookFrames == 900, "Expected 900 Red Book frames for 10s + 2s pregap")
    h.check(cube.redBookByteSize == 900 * 2352, "Expected 2,116,800 Red Book bytes")
    h.check(cube.formattedDurationMMSSFF == "00:10:00", "Expected 00:10:00 MM:SS:FF formatting")
    }

    harness.runSuite("11. AudioKit Red Book CUE Sheet Compiler, 18B CD-Text CRC-16 & Equal-Power Crossfade") { h in
    // 11a. Equal-power crossfade energy conservation (fadeOut^2 + fadeIn^2 == 1.0)
    for step in 0...10 {
        let t = Double(step) / 10.0
        let (outG, inG) = KroutonAudioEngine.equalPowerCrossfadeGains(progress: t)
        let energySum = (outG * outG) + (inG * inG)
        h.check(abs(energySum - 1.0) < 1e-9, "Equal-power crossfade energy must equal 1.0 at t=\(t)")
    }

    // 11b. 18-Byte Sony/Philips CD-Text Pack & CRC-16 CCITT verification
    let packs = KroutonAudioEngine.buildCDTextPacks(
        packType: 0x80,
        trackNumber: 1,
        text: "KROUTON OVERDRIVE SUITE"
    )
    h.check(packs.count == 2, "23-char title + null byte must span 2 x 12-byte CD-Text packs")
    for p in packs {
        let raw = p.raw18Bytes
        h.check(raw.count == 18, "Each Sony/Philips CD-Text pack must be exactly 18 bytes")
        let recomputedCRC = KroutonAudioEngine.computeCDTextInvertedCRC16(Array(raw.prefix(16)))
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
    let cue = KroutonAudioEngine.compileRedBookCueSheet(
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

    harness.runSuite("12. VideoKit Optical Bitrate Budget (DVD-5/DVD-9/BD-25/BD-50) & DVD-9 Shrink Math") { h in
    h.check(KroutonVideoTargetMedium.dvd5SingleLayer.capacityBytes == 4_700_372_992, "Exact DVD-5 byte capacity (2,295,104 sectors)")
    h.check(KroutonVideoTargetMedium.dvd9DualLayer.capacityBytes == 8_547_991_552, "Exact DVD-9 byte capacity (4,173,824 sectors)")
    h.check(KroutonVideoTargetMedium.bd25SingleLayer.capacityBytes == 25_025_314_816, "Exact BD-25 byte capacity")

    // Short 30-minute program on DVD-5 should clamp strictly to the 9,800 kbps DVD-Video hardware ceiling
    let shortDVD = KroutonVideoAuthoringEngine.computeBitrateBudget(durationSeconds: 1800, audioKbps: 448, medium: .dvd5SingleLayer)
    h.check(shortDVD.targetVideoKbps == 9_800, "Short DVD program must clamp to 9,800 kbps DVD-Video spec ceiling")
    h.check(shortDVD.vbvBufferKilobits == 1_835 && shortDVD.isSpecCompliant, "DVD VBV buffer must be 1,835 kb")

    // 2.5-hour (9000s) feature film on DVD-5 must compute a custom VBR target below 9,800 kbps to fit 100% of disc
    let featureDVD = KroutonVideoAuthoringEngine.computeBitrateBudget(durationSeconds: 9000, audioKbps: 448, medium: .dvd5SingleLayer)
    h.check(featureDVD.targetVideoKbps > 3_000 && featureDVD.targetVideoKbps < 4_200, "150-min DVD-5 target video bitrate in [3000, 4200] kbps")
    h.check(featureDVD.estimatedDiscFillRatio > 0.98, "150-min DVD-5 bitrate budget should utilize >98% of disc capacity")

    // DVD-9 (7.2 GB main + 0.8 GB extras) -> DVD-5 shrink test with and without extras
    let mainBytes: Int64 = 6_800_000_000
    let extraBytes: Int64 = 900_000_000
    let shrinkWithExtras = KroutonVideoAuthoringEngine.planDVD9ToDVD5Shrink(
        mainFeatureBytes: mainBytes,
        menusAndExtrasBytes: extraBytes,
        preserveMenusAndExtras: true
    )
    let shrinkMainOnly = KroutonVideoAuthoringEngine.planDVD9ToDVD5Shrink(
        mainFeatureBytes: mainBytes,
        menusAndExtrasBytes: extraBytes,
        preserveMenusAndExtras: false
    )
    h.check(shrinkWithExtras.requiresRequantization && shrinkWithExtras.estimatedOutputBytes <= KroutonVideoTargetMedium.dvd5SingleLayer.capacityBytes,
            "DVD-9 -> DVD-5 shrink must fit strictly inside DVD-5 capacity")
    h.check(shrinkMainOnly.requantizationRatio > shrinkWithExtras.requantizationRatio,
            "Stripping extras must yield higher video quality retention ratio for the main feature")
    }

    harness.runSuite("13. VideoKit DVD-9 -> DVD-5 Menu-Preserving Shrink, .IFO Relinking & Layer-Break Removal") { h in
    // Simulate a 7.85 GB Dual-Layer DVD-9 (450 MB interactive motion menus + 3 main feature cells across Layer 0 & Layer 1)
    let dvd9Cells = [
        KroutonDVD9CellDescriptor(cellID: 1, originalStartSectorLBA: 0,         originalSectorCountLBA: 1_200_000, hadDualLayerBreakPause: false),
        KroutonDVD9CellDescriptor(cellID: 2, originalStartSectorLBA: 1_200_000, originalSectorCountLBA: 1_100_000, hadDualLayerBreakPause: true), // Layer 0 -> Layer 1 break cell!
        KroutonDVD9CellDescriptor(cellID: 3, originalStartSectorLBA: 2_300_000, originalSectorCountLBA: 1_100_000, hadDualLayerBreakPause: false)
    ]
    let blueprint = KroutonVideoAuthoringEngine.buildDVD9ToDVD5MenuShrinkBlueprint(
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

    harness.runSuite("14. Multi-Disc Spanning (DiscPlanner, AudioDiscPlan, DiscRepacker & SpanManifest)") { h in
        var spanProj = AudioProject(albumTitle: "LIVE AT THE FILLMORE", albumPerformer: "THE KROUTONS")
        spanProj.targetDiscMedium = .cd80Min700MB // 359,775 frames (79:57:00)
        let _ = spanProj.append((1...16).map { URL(fileURLWithPath: String(format: "/tmp/trk_%02d.wav", $0)) })

        for i in 0..<16 {
            let tid = spanProj.tracks[i].id
            spanProj.update(tid) {
                $0.title = String(format: "Song %02d", i + 1)
                $0.frameCount = (i == 15) ? 30_000 : 22_500
                $0.transitionToNext = (i == 14)
                    ? KroutonTrackTransitionSpec(overlapSeconds: 4.0, preGapSeconds: 0.0)
                    : KroutonTrackTransitionSpec(overlapSeconds: 0.0, preGapSeconds: 0.0)
            }
        }

        let twoDiscs = spanProj.discPlan()
        h.check(twoDiscs.discs.count == 2, "15x5min + 1x6m40s tracks on 80-min CD-R must span into 2 discs")
        if twoDiscs.discs.count == 2 {
            h.check(twoDiscs.discs[0].tracks.count == 15 && twoDiscs.discs[1].tracks.count == 1,
                    "Disc 1 must hold Tracks 01..15 and Disc 2 must hold spilled Track 16")
            h.check(twoDiscs.discs[1].layout?.first?.number == 1 && twoDiscs.discs[1].layout?.first?.audioStart == 0,
                    "Spilled Track 16 must restart at Track 01 (frame 0) on Disc 2")
        }

        let hasSplitWarning = twoDiscs.warnings.contains {
            if case .breakSplitsContinuousRun(discNumber: 1, _, _) = $0 { return true }
            return false
        }
        h.check(hasSplitWarning, "Automatic disc break across a crossfaded boundary must emit .breakSplitsContinuousRun warning")

        spanProj.setMetadata(
            KroutonDiscVolumeMetadata(discNumber: 2, title: "FILLMORE ENCORE (DISC II)", performer: "THE KROUTONS LIVE", upc: "0123456789012"),
            forDisc: 2
        )
        h.check(spanProj.metadata(forDisc: 2).title == "FILLMORE ENCORE (DISC II)", "Disc 2 custom title must be stored")

        let id04 = spanProj.tracks[3].id
        let id05 = spanProj.tracks[4].id
        spanProj.remove(id04)
        spanProj.remove(id05)
        let oneDisc = spanProj.discPlan()
        h.check(oneDisc.discs.count == 1 && oneDisc.discs[0].tracks.count == 14,
                "Removing Tracks 04 and 05 must collapse project back to 1 disc with 14 tracks")
        h.check(oneDisc.discs[0].layout?.last?.overlapWithPrevious == 300,
                "Suppressed 4.0s (300-frame) crossfade between Track 15 and Track 16 must restore when Track 16 pulls back onto Disc 1")

        let newAdded = spanProj.append([URL(fileURLWithPath: "/tmp/trk_17.wav"), URL(fileURLWithPath: "/tmp/trk_18.wav")])
        for trk in newAdded {
            spanProj.update(trk.id) { $0.frameCount = 25_000 }
        }
        let reSpanned = spanProj.discPlan()
        h.check(reSpanned.discs.count == 2 && reSpanned.discs[1].metadata.title == "FILLMORE ENCORE (DISC II)" && reSpanned.discs[1].metadata.performer == "THE KROUTONS LIVE",
                "When Disc 2 is needed again, it must restore its remembered Album Title and Artist from discMetadata[2]")

        let longTitle = "THE_COMPLETE_LIVE_RECORDINGS_AT_OAKLAND_AUDITORIUM_1976"
        let lblD1 = SpanManifest.volumeLabel(base: longTitle, discIndex: 1, discCount: 3, limit: 32)
        let lblD2 = SpanManifest.volumeLabel(base: longTitle, discIndex: 2, discCount: 3, limit: 32)
        let lblD3 = SpanManifest.volumeLabel(base: longTitle, discIndex: 3, discCount: 3, limit: 32)
        h.check(lblD1.count == 32 && lblD2.count == 32 && lblD3.count == 32, "Formatted disc volume labels must respect 32-char ISO limit")
        h.check(lblD1.hasSuffix("_D01") && lblD2.hasSuffix("_D02") && lblD3.hasSuffix("_D03") && lblD1 != lblD2 && lblD2 != lblD3,
                "Long volume titles must reserve room for _D01/_D02/_D03 suffixes so discs never get identical labels")

        var manualProj = AudioProject(albumTitle: "ACT I", albumPerformer: "ENSEMBLE")
        let _ = manualProj.append((1...6).map { URL(fileURLWithPath: "/tmp/m\($0).wav") })
        for trk in manualProj.tracks { manualProj.update(trk.id) { $0.frameCount = 9_000 } }
        let actTwoStartID = manualProj.tracks[4].id
        manualProj.update(actTwoStartID) { $0.startsNewDisc = true }
        manualProj.anchoredDiscMetadata[actTwoStartID] = KroutonDiscVolumeMetadata(discNumber: 2, title: "ACT II: FINALE", performer: "ENSEMBLE")
        let intermissionID = manualProj.tracks[2].id
        manualProj.update(intermissionID) { $0.startsNewDisc = true }
        manualProj.anchoredDiscMetadata[intermissionID] = KroutonDiscVolumeMetadata(discNumber: 2, title: "INTERMISSION", performer: "ENSEMBLE")

        let manualPlan = manualProj.discPlan()
        h.check(manualPlan.discs.count == 3 && manualPlan.discs[1].metadata.title == "INTERMISSION" && manualPlan.discs[2].metadata.title == "ACT II: FINALE",
                "Manual break metadata must stay anchored to its first track when an earlier manual break is inserted")
        h.check(manualPlan.discs.flatMap(\.tracks).map(\.id) == manualProj.tracks.map(\.id),
                "Concatenating AudioDiscPlan.discs tracks must give back project.tracks in exact order")

        struct MockDataItem: Identifiable, Sendable { let id: String; let bytes: Int64 }
        let gb: Int64 = 1_000_000_000
        let alreadyOptimal = [MockDataItem(id: "1", bytes: 2 * gb), MockDataItem(id: "2", bytes: 2 * gb)]
        let noOpProposal = DiscRepacker.proposal(for: alreadyOptimal, capacityUnits: 5 * gb, currentDiscCount: 1, size: \.bytes)
        h.check(noOpProposal == nil, "DiscRepacker.proposal must return nil when repacking cannot reduce currentDiscCount")
        let fragItems = [
            MockDataItem(id: "A", bytes: 3 * gb),
            MockDataItem(id: "B", bytes: 3 * gb),
            MockDataItem(id: "C", bytes: Int64(1.4 * Double(gb))),
            MockDataItem(id: "D", bytes: Int64(1.4 * Double(gb)))
        ]
        let goodProposal = DiscRepacker.proposal(for: fragItems, capacityUnits: Int64(4.6 * Double(gb)), currentDiscCount: 3, size: \.bytes)
        h.check(goodProposal?.discCount == 2 && goodProposal?.order.count == 4,
                "DiscRepacker.proposal must reduce 3-disc fragmented set to 2 discs while preserving all 4 items")
    }

    runKroutonVerifySuites19To21(&harness)
}
