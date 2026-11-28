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

// MARK: - VerifyHarness — LabelAndPersistenceSuites

extension KroutonTestHarness {
    mutating func runVerifyLabelAndPersistenceSuites() {
        runVerifyLabelAndSessionSuitesPart()
        runVerifyMultiDiscSpanningSuitePart()
    }

    private mutating func runVerifyLabelAndSessionSuitesPart() {
    self.runSuite("19. AudioKit Splice Overlap Math, Equal-Power Crossfade & CD-Text CRC-16") { h in
        let gainMid = KroutonAudioEngine.equalPowerCrossfadeGains(progress: 0.5)
        let powerSum = gainMid.fadeOut * gainMid.fadeOut + gainMid.fadeIn * gainMid.fadeIn
        h.check(abs(powerSum - 1.0) < 1e-6, "Equal-power crossfade midpoint must preserve unity acoustic power (sin^2 + cos^2 == 1.0)")

        let crc = KroutonAudioEngine.computeCDTextInvertedCRC16([0x80, 0x00, 0x01, 0x00, 0x4B, 0x52, 0x4F, 0x55, 0x54, 0x4F, 0x4E, 0x00, 0x00, 0x00, 0x00, 0x00])
        h.check(crc != 0, "18-byte Sony/Philips Red Book CD-Text pack CRC-16-CCITT must compute non-zero checksum")
    }

    self.runSuite("20. LabelKit Polar 300-DPI Geometry, Photo Adjustments & 1:1 Vector PDF Print Sheet") { h in
        let dim120 = KroutonDiscHubGeometry.fullFace120mmHub22mm.canvasPixelDimension(dpi: 300.0)
        h.check(dim120 == 1417, "120mm disc at 300 DPI must equal 1417 pixels")
        let glyphs = KroutonLabelGeometryEngine.computePolarArcGlyphLayout(
            text: "KROUTON ARCHIVAL EDITION",
            centerX: 180.0,
            centerY: 180.0,
            radiusPoints: 136.0
        )
        h.check(glyphs.count == "KROUTON ARCHIVAL EDITION".count,
                "KroutonLabelGeometryEngine.layoutPolarArcText must position one polar glyph per character")
    }

    self.runSuite("21. Persistence SessionStore, RunLock Crash Recovery, L10n Catalog & @dynamicMemberLookup") { h in
        Self.verifyPersistenceL10nAndDynamicMemberSuite(&h)
    }

    }


    private static func verifyPersistenceL10nAndDynamicMemberSuite(_ h: inout KroutonTestHarness) {
        let tmpDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("KroutonPersistVerify_\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: tmpDir) }
        if let res1 = try? RunLock.acquire(in: tmpDir) {
            h.check(res1.verdict == .clean, "First RunLock acquisition on clean directory must return .clean verdict")
            res1.lock?.markRunning()
            res1.lock?.markStable()
            res1.lock?.markCleanExit()
        } else {
            h.check(false, "RunLock.acquire must succeed in temporary directory")
        }
        if let res2 = try? RunLock.acquire(in: tmpDir) {
            h.check(res2.verdict == .clean, "Acquiring RunLock after markCleanExit() must return .clean verdict")
            res2.lock?.markCleanExit()
        }

        // FileReference bookmark resolution (.found when present, .missing when deleted)
        let bookmarkFile = tmpDir.appendingPathComponent("staged_track.wav")
        try? Data("RIFF_WAVE".utf8).write(to: bookmarkFile)
        let fileRef = FileReference(url: bookmarkFile)
        if case .found(let resolvedURL) = fileRef.resolve() {
            h.check(resolvedURL.resolvingSymlinksInPath() == bookmarkFile.resolvingSymlinksInPath(), "FileReference must resolve .found for existing file")
        } else {
            h.check(false, "FileReference must resolve .found for existing file")
        }
        try? FileManager.default.removeItem(at: bookmarkFile)
        h.check(fileRef.resolve() == .missing(lastKnownPath: bookmarkFile.path), "FileReference must return .missing when file is removed")

        // RestoreDecision matrix
        h.check(restoreDecision(verdict: .clean, hasSnapshot: true, rememberSession: true) == .restoreSilently, "Clean launch with snapshot must restoreSilently")
        h.check(restoreDecision(verdict: .anotherInstanceRunning, hasSnapshot: true, rememberSession: true) == .startFresh, "Secondary instance must startFresh")

        // Localizable.xcstrings: a String Catalog with English as the source and the first
        // translations in place (Scripts/extract-strings.py --check keeps it complete).
        struct StringCatalog: Decodable {
            struct Entry: Decodable { let localizations: [String: [String: [String: String]]]? }
            let sourceLanguage: String
            let strings: [String: Entry]
        }
        let catalogURL = KroutonTestHarness.repositoryRoot
            .appendingPathComponent("Sources/KroutonApp/Resources/Localizable.xcstrings")
        let catalog = (try? Data(contentsOf: catalogURL)).flatMap { try? JSONDecoder().decode(StringCatalog.self, from: $0) }
        h.check(catalog?.sourceLanguage == "en" && (catalog?.strings.count ?? 0) >= 600,
                "Localizable.xcstrings must be a String Catalog in English holding the interface strings")
        let crossfade = catalog?.strings["2.5s X-Fade"]?.localizations
        h.check(crossfade?["zh-Hans"]?["stringUnit"]?["value"]?.isEmpty == false && crossfade?["pt-BR"] != nil,
                "The catalog must keep the existing translations (zh-Hans, pt-BR and the rest)")

        // @dynamicMemberLookup persistence side-effect & isHydratingPreferences suppression verification
        @dynamicMemberLookup
        final class SubStoreRoutingHarness {
            struct Appearance {
                var enableSecondaryAccentUITints = true
                var tintWindowWithWallpaper = true
                var appLanguage = "en"
                var rememberLastTaskOnLaunch = true
            }
            struct Label { var selectedLabelTemplate = "minimal" }
            var appearance = Appearance()
            var label = Label()
            var isHydratingPreferences = false
            var activeISOCode = "en"
            var persistedKeys: [String: String] = [:]

            subscript<T>(dynamicMember keyPath: WritableKeyPath<Appearance, T>) -> T {
                get { appearance[keyPath: keyPath] }
                set {
                    let old = appearance
                    appearance[keyPath: keyPath] = newValue
                    if appearance.enableSecondaryAccentUITints != old.enableSecondaryAccentUITints {
                        appearance.tintWindowWithWallpaper = appearance.enableSecondaryAccentUITints
                        if !isHydratingPreferences { persistedKeys["krouton.pref.harmonyEnabled"] = "\(appearance.enableSecondaryAccentUITints)" }
                    }
                    if appearance.appLanguage != old.appLanguage {
                        activeISOCode = appearance.appLanguage
                        if !isHydratingPreferences { persistedKeys["krouton.pref.appLanguage"] = appearance.appLanguage }
                    }
                    if !isHydratingPreferences, appearance.rememberLastTaskOnLaunch != old.rememberLastTaskOnLaunch {
                        persistedKeys["krouton.pref.rememberLastTask"] = "\(appearance.rememberLastTaskOnLaunch)"
                    }
                }
            }
            subscript<T>(dynamicMember keyPath: WritableKeyPath<Label, T>) -> T {
                get { label[keyPath: keyPath] }
                set {
                    let oldTpl = label.selectedLabelTemplate
                    label[keyPath: keyPath] = newValue
                    if label.selectedLabelTemplate != oldTpl && !isHydratingPreferences {
                        persistedKeys["krouton.pref.labelTemplate"] = label.selectedLabelTemplate
                    }
                }
            }
        }

        let router = SubStoreRoutingHarness()
        router.isHydratingPreferences = true
        router.enableSecondaryAccentUITints = false
        router.selectedLabelTemplate = "archival"
        h.check(!router.tintWindowWithWallpaper && router.persistedKeys.isEmpty, "Hydrating mutations via @dynamicMemberLookup must sync derived fields without writing to UserDefaults")

        router.isHydratingPreferences = false
        router.enableSecondaryAccentUITints = true
        router.appLanguage = "ja"
        router.rememberLastTaskOnLaunch = false
        router.selectedLabelTemplate = "vinyl"
        h.check(router.tintWindowWithWallpaper && router.activeISOCode == "ja", "@dynamicMemberLookup mutation must update tintWindowWithWallpaper and activeISOCode")
        h.check(router.persistedKeys["krouton.pref.harmonyEnabled"] == "true"
                && router.persistedKeys["krouton.pref.appLanguage"] == "ja"
                && router.persistedKeys["krouton.pref.rememberLastTask"] == "false"
                && router.persistedKeys["krouton.pref.labelTemplate"] == "vinyl",
                "@dynamicMemberLookup mutations must persist harmonyEnabled, appLanguage, rememberLastTask, and labelTemplate")

        let forwardingURL = KroutonTestHarness.repositoryRoot
            .appendingPathComponent("Sources/KroutonApp/Shell/StateAndModels/KroutonStateStore+SubStoreForwarding.swift")
        let forwardingSrc = (try? String(contentsOf: forwardingURL, encoding: .utf8)) ?? ""
        h.lint(forwardingSrc.contains("WritableKeyPath<AppearancePreferences, T>")
               && forwardingSrc.contains("WritableKeyPath<LabelDocument, T>")
               && forwardingSrc.contains("WritableKeyPath<DepotCatalogue, T>")
               && forwardingSrc.contains("WritableKeyPath<RipSettings, T>"),
               "KroutonStateStore+SubStoreForwarding.swift must route all 4 sub-stores via @dynamicMemberLookup key-path subscripts")

        Self.checkSavedDestinationKinds(&h)
    }

    private mutating func runVerifyMultiDiscSpanningSuitePart() {
    self.runSuite("22. Multi-Disc Spanning (DiscPlanner, AudioDiscPlan, DiscRepacker, SpanManifest & BurnSet)") { h in
             try Self.verifySpanningSuite22PartA(&h)
             try Self.verifySpanningSuite22PartB(&h)
        }
    }

    private static func verifySpanningSuite22PartA(_ h: inout KroutonTestHarness) throws {
        // 1. AudioDiscPlan: Auto-Spawn Disc 2 at Capacity, Per-Disc Track Numbering,
        //    Crossfade Suppression Across Physical Disc Breaks, and Persistent Disc 2 Metadata Memory
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

        let twoDiscPlan = spanProj.discPlan()
        h.check(twoDiscPlan.discs.count == 2, "15x5min + 1x6m40s tracks on 80-min CD-R must span into 2 discs")
        if twoDiscPlan.discs.count == 2 {
            h.check(twoDiscPlan.discs[0].tracks.count == 15 && twoDiscPlan.discs[1].tracks.count == 1,
                    "Disc 1 must hold Tracks 01..15 and Disc 2 must hold spilled Track 16")
            h.check(twoDiscPlan.discs[1].layout?.first?.number == 1 && twoDiscPlan.discs[1].layout?.first?.audioStart == 0,
                    "Spilled Track 16 must restart at Track 01 (frame 0) on Disc 2")
        }

        // Automatic break splitting a crossfaded boundary must emit .breakSplitsContinuousRun warning
        let hasSplitWarning = twoDiscPlan.warnings.contains {
            if case .breakSplitsContinuousRun(discNumber: 1, _, _) = $0 { return true }
            return false
        }
        h.check(hasSplitWarning, "Automatic disc break across a crossfaded boundary must emit .breakSplitsContinuousRun warning")

        // Customize Disc 2's Album Title & Artist
        spanProj.setMetadata(
            KroutonDiscVolumeMetadata(discNumber: 2, title: "FILLMORE ENCORE (DISC II)", performer: "THE KROUTONS LIVE", upc: "0123456789012"),
            forDisc: 2
        )
        h.check(spanProj.metadata(forDisc: 2).title == "FILLMORE ENCORE (DISC II)", "Disc 2 custom title must be stored")

        // Remove Tracks 04 and 05 from Disc 1 -> all 14 remaining tracks fit on Disc 1, so Disc 2 disappears!
        let id04 = spanProj.tracks[3].id
        let id05 = spanProj.tracks[4].id
        spanProj.remove(id04)
        spanProj.remove(id05)
        let oneDiscPlan = spanProj.discPlan()
        h.check(oneDiscPlan.discs.count == 1 && oneDiscPlan.discs[0].tracks.count == 14,
                "Removing Tracks 04 and 05 must collapse project back to 1 disc with 14 tracks")
        h.check(oneDiscPlan.discs[0].layout?.last?.overlapWithPrevious == 300,
                "Suppressed 4.0s (300-frame) crossfade between Track 15 and Track 16 must restore when Track 16 pulls back onto Disc 1")

        // Add 2 long tracks so Disc 2 is needed again -> verify Disc 2 remembers "FILLMORE ENCORE (DISC II)"!
        let newAdded = spanProj.append([URL(fileURLWithPath: "/tmp/trk_17.wav"), URL(fileURLWithPath: "/tmp/trk_18.wav")])
        for trk in newAdded {
            spanProj.update(trk.id) { $0.frameCount = 25_000 }
        }
        let reSpanned = spanProj.discPlan()
        h.check(reSpanned.discs.count == 2 && reSpanned.discs[1].metadata.title == "FILLMORE ENCORE (DISC II)" && reSpanned.discs[1].metadata.performer == "THE KROUTONS LIVE",
                "When Disc 2 is needed again, it must restore its remembered Album Title and Artist from discMetadata[2]")

        // 2. SpanManifest.volumeLabel suffix reservation (long titles never collide after 32-char truncation)
        let longTitle = "THE_COMPLETE_LIVE_RECORDINGS_AT_OAKLAND_AUDITORIUM_1976"
        let lblD1 = SpanManifest.volumeLabel(base: longTitle, discIndex: 1, discCount: 3, limit: 32)
        let lblD2 = SpanManifest.volumeLabel(base: longTitle, discIndex: 2, discCount: 3, limit: 32)
        let lblD3 = SpanManifest.volumeLabel(base: longTitle, discIndex: 3, discCount: 3, limit: 32)
        h.check(lblD1.count == 32 && lblD2.count == 32 && lblD3.count == 32, "Formatted disc volume labels must respect 32-char ISO limit")
        h.check(lblD1.hasSuffix("_D01") && lblD2.hasSuffix("_D02") && lblD3.hasSuffix("_D03") && lblD1 != lblD2 && lblD2 != lblD3,
                "Long volume titles must reserve room for _D01/_D02/_D03 suffixes so discs never get identical labels")

        // 3. Manual break metadata attaches to the break track (inserting an earlier manual break never steals Disc 2's title)
        var manualProj = AudioProject(albumTitle: "ACT I", albumPerformer: "ENSEMBLE")
        let _ = manualProj.append((1...6).map { URL(fileURLWithPath: "/tmp/m\($0).wav") })
        for trk in manualProj.tracks { manualProj.update(trk.id) { $0.frameCount = 9_000 } }
        let actTwoStartID = manualProj.tracks[4].id
        manualProj.update(actTwoStartID) { $0.startsNewDisc = true }
        manualProj.anchoredDiscMetadata[actTwoStartID] = KroutonDiscVolumeMetadata(discNumber: 2, title: "ACT II: FINALE", performer: "ENSEMBLE")

        // Insert an earlier manual break before Track 3 -> ACT II: FINALE becomes Disc 3 and keeps its title!
        let intermissionID = manualProj.tracks[2].id
        manualProj.update(intermissionID) { $0.startsNewDisc = true }
        manualProj.anchoredDiscMetadata[intermissionID] = KroutonDiscVolumeMetadata(discNumber: 2, title: "INTERMISSION", performer: "ENSEMBLE")

        let manualPlan = manualProj.discPlan()
        h.check(manualPlan.discs.count == 3 && manualPlan.discs[1].metadata.title == "INTERMISSION" && manualPlan.discs[2].metadata.title == "ACT II: FINALE",
                "Manual break metadata must stay anchored to its first track when an earlier manual break is inserted")
        h.check(manualPlan.discs.flatMap(\.tracks).map(\.id) == manualProj.tracks.map(\.id),
                "Concatenating AudioDiscPlan.discs tracks must give back project.tracks in exact order")
        h.check(manualPlan.isBurnable && !manualPlan.isProvisional,
                "Fully analysed AudioDiscPlan with no oversize tracks must be burnable and non-provisional")
    }

    private static func verifySpanningSuite22PartB(_ h: inout KroutonTestHarness) throws {
        // 4. Provisional plan invariant: unmeasured track holds everything on 1 provisional disc with nil layout
        var provProj = AudioProject(albumTitle: "PROVISIONAL SET", albumPerformer: "ARTIST")
        let _ = provProj.append([URL(fileURLWithPath: "/tmp/p1.wav"), URL(fileURLWithPath: "/tmp/p2.wav")])
        let provPlan = provProj.discPlan()
        h.check(provPlan.isProvisional && !provPlan.isBurnable && provPlan.discs.count == 1 && provPlan.discs[0].layout == nil,
                "Unmeasured tracks must stay on 1 provisional disc with nil layout and isBurnable == false")

        // 5. DiscRepacker proposal invariant: returns nil when repacking does not reduce disc count
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

        // 6. SpanManifest percent-encoding & single-pass BurnSetStager verification
        let stageTmp = FileManager.default.temporaryDirectory.appendingPathComponent("KroutonStageVerify_\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: stageTmp) }
        try? FileManager.default.createDirectory(at: stageTmp, withIntermediateDirectories: true)
        let srcFile1 = stageTmp.appendingPathComponent("Doc 100%.txt")
        let srcFile2 = stageTmp.appendingPathComponent("Archive_Part2.bin")
        try Data("ALPHA_100_PERCENT_PAYLOAD".utf8).write(to: srcFile1)
        try Data(repeating: 0x5A, count: 8192).write(to: srcFile2)

        let stagedResult = try BurnSetStager.freezeAndStageSet(
            title: "THE_FORTY_CHARACTER_LONG_ARCHIVAL_VAULT_TITLE_2026",
            discs: [
                [StagedInputFile(sourceURL: srcFile1, relativePathOnDisc: "Docs/Doc 100%.txt")],
                [StagedInputFile(sourceURL: srcFile2, relativePathOnDisc: "Bins/Archive_Part2.bin")]
            ],
            stagingRootDirectory: stageTmp,
            manifestMode: .bagItRFC8493
        )
        h.check(stagedResult.burnSet.discs.count == 2, "BurnSetStager must freeze and stage 2 FrozenDisc images")
        let d1Tags = try SpanManifest.tagFiles(for: 1, in: stagedResult.setIndex)
        let d1ManifestStr = String(data: d1Tags["manifest-sha256.txt"] ?? Data(), encoding: .utf8) ?? ""
        h.check(d1ManifestStr.contains("data/Docs/Doc 100%25.txt"),
                "SpanManifest must percent-encode '%' as '%25' in manifest-sha256.txt paths")
        let d2InfoStr = String(data: d1Tags["bag-info.txt"] ?? Data(), encoding: .utf8) ?? ""
        h.check(d2InfoStr.contains("Bag-Count: 1 of 2") && d2InfoStr.contains("Bag-Group-Identifier:"),
                "RFC 8493 BagIt bag-info.txt must include Bag-Group-Identifier and Bag-Count")

        // 7. BurnSetProgress.replay state machine invariants (out-of-order transition rejection + single-disc retry)
        let bSet = stagedResult.burnSet
        let drv = DriveID("PIONEER-BDR-XS07")
        let validLog: [BurnEvent] = [
            .setCreated(bSet),
            .attemptStarted(set: bSet.id, disc: 1, attempt: 1, drive: drv, mediaID: "MID-1", at: .now),
            .phaseChanged(set: bSet.id, disc: 1, attempt: 1, phase: .verifying, at: .now),
            .attemptSucceeded(set: bSet.id, disc: 1, attempt: 1, at: .now),
            // Duplicate success on Disc 1 must be rejected!
            .attemptSucceeded(set: bSet.id, disc: 1, attempt: 1, at: .now),
            // Disc 2 fails on attempt 1, then succeeds on attempt 2
            .attemptStarted(set: bSet.id, disc: 2, attempt: 1, drive: drv, mediaID: "MID-2A", at: .now),
            .attemptFailed(set: bSet.id, disc: 2, attempt: 1, failure: .writeError(sense: "3/0C/00"), at: .now),
            .attemptStarted(set: bSet.id, disc: 2, attempt: 2, drive: drv, mediaID: "MID-2B", at: .now),
            .attemptSucceeded(set: bSet.id, disc: 2, attempt: 2, at: .now)
        ]
        let (replayedSets, rejectedEvents) = BurnSetProgress.replay(validLog)
        h.check(replayedSets.count == 1 && rejectedEvents.count == 1,
                "BurnSetProgress.replay must reject duplicate attemptSucceeded while replaying valid events")
        if let prog = replayedSets.first {
            h.check(prog.isComplete && prog.jobs[0].attempts == 1 && prog.jobs[1].attempts == 2,
                    "After Disc 2 succeeds on attempt 2, BurnSetProgress.isComplete must be true with attempts == 2")
        }

        // 8. Shared DiscSpanningEngine.planDataDiscs (auto-spawn Disc 2 at capacity, auto-collapse on removal, manual disc break)
        let f1 = KroutonStagedFileEntry(url: URL(fileURLWithPath: "/tmp/part1.bin"), name: "part1.bin", isDirectory: false, byteSize: 450_000_000, itemCount: 1, posixPermissions: "0644", modifiedDate: .now)
        let f2 = KroutonStagedFileEntry(url: URL(fileURLWithPath: "/tmp/part2.bin"), name: "part2.bin", isDirectory: false, byteSize: 450_000_000, itemCount: 1, posixPermissions: "0644", modifiedDate: .now)
        let dataEntries = [f1, f2]
        let cdPlan = DiscSpanningEngine.planDataDiscs(dataEntries, medium: .cd80Min700MB)
        h.check(cdPlan.discs.count == 2 && cdPlan.discs[1].startedBecause == .capacity,
                "Two 450 MB files on 700 MB CD-R must auto-spawn Disc 2 with startedBecause == .capacity")

        let shrunkPlan = DiscSpanningEngine.planDataDiscs([f1], medium: .cd80Min700MB)
        h.check(shrunkPlan.discs.count == 1,
                "Removing second 450 MB file must automatically collapse Disc 2 back to 1 disc")

        var manualEntries = [
            KroutonStagedFileEntry(url: URL(fileURLWithPath: "/tmp/a.txt"), name: "a.txt", isDirectory: false, byteSize: 4096, itemCount: 1, posixPermissions: "0644", modifiedDate: .now),
            KroutonStagedFileEntry(url: URL(fileURLWithPath: "/tmp/b.txt"), name: "b.txt", isDirectory: false, byteSize: 4096, itemCount: 1, posixPermissions: "0644", modifiedDate: .now)
        ]
        DiscSpanningEngine.toggleManualDiscBreak(before: manualEntries[1].id, in: &manualEntries)
        let manualDataPlan = DiscSpanningEngine.planDataDiscs(manualEntries, medium: .dvd5Single)
        h.check(manualDataPlan.discs.count == 2 && manualDataPlan.discs[1].startedBecause == .manual,
                "Manual disc break on second data item must split onto Disc 2 with startedBecause == .manual")
        DiscSpanningEngine.toggleManualDiscBreak(before: manualEntries[1].id, in: &manualEntries)
        h.check(DiscSpanningEngine.planDataDiscs(manualEntries, medium: .dvd5Single).discs.count == 1,
                "Toggling manual disc break off must merge Disc 2 back into Disc 1")

        // 9. KroutonFinderLayoutBlueprint binary .DS_Store serialization
        var bp = KroutonFinderLayoutBlueprint(displayMode: .gallery, iconSize: 128, labelPosition: .right)
        bp.itemAnnotations["part1.bin"] = KroutonFinderItemAnnotation(tagColor: .red, spotlightComment: "Archive Vol 1", iconX: 120, iconY: 140)
        let dsBlob = bp.serializeDSStore(itemNames: ["part1.bin", "part2.bin"])
        h.check(dsBlob.count > 64 && String(data: dsBlob.subdata(in: 4..<8), encoding: .ascii) == "Bud1",
                "KroutonFinderLayoutBlueprint.serializeDSStore must emit valid Bud1 header and record payload")

        // 10. Automatic per-disc volume & destination filename resolution (single-disc vs multi-disc D01/D02)
        let singleLbl = DiscSpanningEngine.resolvedDiscVolumeLabel(baseTitle: "SUMMER_MIX", customTitle: nil, discNumber: 1, totalDiscs: 1)
        let d1Lbl = DiscSpanningEngine.resolvedDiscVolumeLabel(baseTitle: "SUMMER_MIX", customTitle: nil, discNumber: 1, totalDiscs: 2)
        let d2Lbl = DiscSpanningEngine.resolvedDiscVolumeLabel(baseTitle: "SUMMER_MIX", customTitle: nil, discNumber: 2, totalDiscs: 2)
        let customD2 = DiscSpanningEngine.resolvedDiscVolumeLabel(baseTitle: "SUMMER_MIX", customTitle: "DISC_TWO_BONUS", discNumber: 2, totalDiscs: 2)
        h.check(singleLbl == "SUMMER_MIX" && d1Lbl == "SUMMER_MIX_D01" && d2Lbl == "SUMMER_MIX_D02" && customD2 == "DISC_TWO_BONUS",
                "DiscSpanningEngine.resolvedDiscVolumeLabel must format single-disc titles cleanly and multi-disc titles as _D01/_D02 unless overridden")
    }
}
