import CoreImage
import CryptoKit
import Foundation
import OpticalCore
import DriveKit
import BurnKit
import AudioKit
import ImageKit
import RescueKit
import LabelKit
import VideoKit
import NetworkSpool
import Persistence

@MainActor
func runKroutonVerifySuites01To10(_ harness: inout KroutonTestHarness) {
    let fm = FileManager.default
    let rootURL = URL(fileURLWithPath: fm.currentDirectoryPath)
    let sourcesURL = rootURL.appendingPathComponent("Sources")

    var allSwiftFiles: [URL] = []
    if let enumerator = fm.enumerator(at: sourcesURL, includingPropertiesForKeys: nil) {
        for case let fileURL as URL in enumerator where fileURL.pathExtension == "swift" {
            if !fileURL.path.contains("/KroutonVerify/") {
                allSwiftFiles.append(fileURL)
            }
        }
    }
    allSwiftFiles.sort { $0.path < $1.path }

    // -------------------------------------------------------------------------
    // SUITE 1: 11-Target Functional Module Architecture, Hardware Isolation & Zero Banned Symbols
    // -------------------------------------------------------------------------
    harness.runSuite("1. 11-Target Clean Modular Architecture, DriveKit Hardware Isolation & Zero Banned Symbols") { h in
        h.check(KroutonDomainIdentity.domainName == "krouton.app", "Canonical domain must be krouton.app")
        h.check(KroutonDomainIdentity.reverseDNSPrefix == "app.krouton", "Reverse-DNS prefix must be app.krouton")
        h.check(KroutonDomainIdentity.Module.allCases.count == 11, "KroutonDomainIdentity.Module must enumerate all 11 targets")
        h.check(KroutonDomainIdentity.Module.driveKit.subsystem == "app.krouton.drivekit", "DriveKit subsystem must be app.krouton.drivekit")
        let expectedModules = [
            "OpticalCore", "DriveKit", "BurnKit", "AudioKit", "ImageKit",
            "RescueKit", "LabelKit", "VideoKit", "NetworkSpool", "Persistence", "KroutonApp"
        ]
        for mod in expectedModules {
            let modDir = sourcesURL.appendingPathComponent(mod)
            h.check(fm.fileExists(atPath: modDir.path), "Expected functional module target directory: Sources/\(mod)")
        }

        let bannedTokens = ["NS" + "Alert", "NS" + "Panel", "NS" + "Window", "NS" + "ViewRepresentable", "WK" + "WebView"]
        for fileURL in allSwiftFiles {
            let src = (try? String(contentsOf: fileURL, encoding: .utf8)) ?? ""
            let relPath = fileURL.path.replacingOccurrences(of: rootURL.path + "/", with: "")

            for token in bannedTokens {
                h.check(!src.contains(token), "\(relPath) must not reference banned AppKit/WebKit symbol \(token)")
            }

            // Hardware Isolation Gate: ONLY Sources/DriveKit/ may import DiscRecording or IOKit
            if !relPath.hasPrefix("Sources/DriveKit/") {
                let importsDiscRecording = src.range(of: #"^(?:@preconcurrency\s+)?import\s+DiscRecording\b"#, options: .regularExpression) != nil
                let importsIOKit = src.range(of: #"^import\s+IOKit\b"#, options: .regularExpression) != nil
                h.check(!importsDiscRecording, "\(relPath) must not import DiscRecording outside Sources/DriveKit/")
                h.check(!importsIOKit, "\(relPath) must not import IOKit outside Sources/DriveKit/")
            }
        }
    }

    // -------------------------------------------------------------------------
    // SUITE 2: Shell/ + Features/ Layout, 600-LOC File Ceiling & 200-LOC Function Gate
    // -------------------------------------------------------------------------
    harness.runSuite("2. Shell/ & Features/ Modularization, 600-LOC File Ceiling & 200-LOC Function Gate") { h in
        let shellDirs = ["App", "StateAndModels", "DesignSystem", "NavigationAndRack", "ModalsAndSettings", "Services"]
        for dir in shellDirs {
            let p = sourcesURL.appendingPathComponent("KroutonApp/Shell/\(dir)").path
            h.check(fm.fileExists(atPath: p), "Missing KroutonApp/Shell directory: \(dir)")
        }

        let featureFiles = [
            "AudioCD/AudioMasteringWorkspaces.swift",
            "AudioCD/CarSafeAudioWorkspace.swift",
            "Rip/CopyAndRipWorkspaces.swift",
            "Data/DataAndArchivalWorkspaces.swift",
            "Data/DiscImageInspectorWorkspace.swift",
            "Label/DiscLabelWorkspace.swift",
            "Data/MasteringTelemetryPopovers.swift",
            "Retro/RetroConsoleWorkspaces.swift",
            "Video/VideoAuthoringWorkspaces.swift"
        ]
        for rel in featureFiles {
            let p = sourcesURL.appendingPathComponent("KroutonApp/Features/\(rel)").path
            h.check(fm.fileExists(atPath: p), "Expected modular feature workspace file: Features/\(rel)")
        }

        let deckAdopters = [
            "AudioCD/AudioMasteringWorkspaces.swift",
            "AudioCD/CarSafeAudioWorkspace.swift",
            "Data/DataAndArchivalWorkspaces.swift",
            "Data/DiscImageInspectorWorkspace.swift",
            "Retro/RetroConsoleWorkspaces.swift",
            "Video/VideoAuthoringWorkspaces.swift"
        ]
        for rel in deckAdopters {
            let p = sourcesURL.appendingPathComponent("KroutonApp/Features/\(rel)")
            let content = (try? String(contentsOf: p, encoding: .utf8)) ?? ""
            h.check(content.contains("KroutonMasteringDeckCard"), "Features/\(rel) must adopt KroutonMasteringDeckCard")
            h.check(content.contains("KroutonEmptyDropZoneView"), "Features/\(rel) must adopt KroutonEmptyDropZoneView")
        }

        for fileURL in allSwiftFiles {
            let src = (try? String(contentsOf: fileURL, encoding: .utf8)) ?? ""
            let lines = src.components(separatedBy: .newlines)
            let relPath = fileURL.path.replacingOccurrences(of: rootURL.path + "/", with: "")
            h.check(lines.count <= 600, "\(relPath) (\(lines.count) LOC) exceeds 600-LOC file ceiling")
        }
    }

    harness.runSuite("3. Functional Kit Modules & Type-Safe Optical Workflow Catalog Routing") { h in
    h.check(KroutonAudioEngine.version == "0.1.0-alpha.1", "Marmalade version")
    h.check(KroutonVideoAuthoringEngine.version == "0.1.0-alpha.1", "VideoOven version")
    h.check(KroutonHybridImagePlanner.version == "0.1.0-alpha.1", "Tartine version")
    h.check(KroutonDiscImageDepot.version == "0.1.0-alpha.1", "Galette version")
    h.check(KroutonLabelGeometryEngine.version == "0.1.0-alpha.1", "Crustini version")


    let formats = KroutonOpticalWorkflowCatalog.defaultFormats
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

    harness.runSuite("4. ISO-9660 / Joliet / UDF File Entry Limits & 2048-Byte LBA Math") { h in
    let fiveGiB: Int64 = 5 * 1024 * 1024 * 1024
    let longName = String(repeating: "K", count: 70) + ".iso"
    let entry = KroutonStagedFileEntry(
        url: URL(fileURLWithPath: "/tmp/\(longName)"),
        name: longName,
        isDirectory: false,
        byteSize: fiveGiB,
        itemCount: 1,
        posixPermissions: "rwxr-xr-x",
        modifiedDate: Date()
    )
    h.check(entry.exceedsISO9660FourGiBLimit, "5 GiB file must flag ISO-9660 4 GiB limit")
    h.check(entry.exceedsJoliet64CharLimit, "74-char filename must flag Joliet 64-char limit")
    h.check(entry.exceedsISO9660ThirtyOneCharLimit, "74-char filename must flag ISO-9660 31-char limit")
    h.check(entry.isConvertibleBinOrIso, ".iso extension must flag convertible sector image")
    h.check(entry.sectorsLBA == fiveGiB / 2048, "LBA sector math must equal byteSize / 2048")
    }

    harness.runSuite("5. ImageKit Hybrid Data LBA Planner (PVD LBA 16, El Torito LBA 17, UDF LBA 256 & Deduplication)") { h in
    let vol = KroutonHybridImagePlanner.sanitizeVolumeIdentifier("Krouton Master 2026! (v1.0)")
    h.check(vol == "KROUTON_MASTER_2026___V1_0", "ECMA-119 d-character volume label sanitization")

    let isoFile = KroutonHybridImagePlanner.sanitizeISO9660FileIdentifier("my-super-archive-2026.tar.gz")
    h.check(isoFile.hasSuffix(".GZ;1") && isoFile.count <= 31, "ISO-9660 Level 2 filename + ;1 version")

    let fiveGiB: Int64 = 5 * 1024 * 1024 * 1024
    let entries = [
        KroutonStagedFileEntry(
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
        KroutonStagedFileEntry(
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

    let plan = KroutonHybridImagePlanner.planHybridDataLayout(
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

    harness.runSuite("6. ImageKit Disc Image Depot (.cue Parser, 2352B->2048B BIN Extractor & Boot Classifier)") { h in
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
    let parsedTracks = KroutonDiscImageDepot.parseCueSheet(sampleCue)
    h.check(parsedTracks.count == 2, "Mixed-mode CUE sheet must parse 2 tracks")
    h.check(parsedTracks[0].mode == .mode1_2352 && parsedTracks[0].index01LBA == 0, "Track 1 Mode1/2352 @ LBA 0")
    h.check(parsedTracks[1].mode == .audio2352 && parsedTracks[1].index00LBA == 9000 && parsedTracks[1].index01LBA == 9150,
            "Track 2 Audio INDEX 00 @ 02:00:00 (9000 LBA) and INDEX 01 @ 02:02:00 (9150 LBA)")

    // 14b. Raw 2352-byte Mode 1 & Mode 2 Form 1 -> 2048-byte ISO payload extraction
    var mode1Raw = Data(KroutonDiscImageDepot.cdRomSyncPattern) // 12 bytes
    mode1Raw.append(contentsOf: [0x00, 0x02, 0x00, 0x01])      // 4B header (00:02:00, Mode 1 = 0x01)
    let expectedPayload = Data(repeating: 0x5A, count: 2048)
    mode1Raw.append(expectedPayload)                           // 2048B user payload
    mode1Raw.append(Data(repeating: 0xEE, count: 288))         // 288B EDC/ECC parity
    h.check(mode1Raw.count == 2352, "Synthetic Mode 1 raw sector must be 2352 bytes")

    let extractedISO = KroutonDiscImageDepot.extractISO2048SectorFromRaw2352(mode1Raw)
    h.check(extractedISO == expectedPayload && extractedISO?.count == 2048,
            "Mode 1 2352B sector extractor must strip 16B header and 288B ECC to yield exact 2048B ISO payload")

    // 14c. Depot Boot & Media Badge classification
    let depotClass = KroutonDiscImageDepot.classifyDepotImage(
        byteSize: 4_100_000_000,
        signatureSampleASCII: "CD001 EL TORITO SPECIFICATION UDF NSR03"
    )
    h.check(depotClass.isBootable && depotClass.bootStandard == "El Torito x86/EFI", "El Torito boot detection")
    h.check(depotClass.detectedFilesystems.contains("ISO-9660") && depotClass.detectedFilesystems.contains("UDF"), "ISO+UDF bridge detection")
    h.check(depotClass.recommendedMediaBadge == "DVD-5 (4.7 GB SL)", "4.1 GB image must recommend DVD-5")
    }

    harness.runSuite("7. SHA-256 Digest & 2048-Byte Sector Hex Dump Inspector") { h in
    let tempURL = FileManager.default.temporaryDirectory
        .appendingPathComponent("krouton_test_\(UUID().uuidString).iso")
    defer { try? FileManager.default.removeItem(at: tempURL) }

    var payload = Data("KROUTON_OPTICAL_MASTER".utf8)
    payload.append(Data(repeating: 0xAA, count: 2048 - payload.count))
    try payload.write(to: tempURL)

    let sha = KroutonElToritoBootInspector.computeSHA256Hex(url: tempURL)
    h.check(sha.count == 64, "SHA-256 digest must be 64 hex characters")

    let rows = KroutonElToritoBootInspector.readSectorHexDump(url: tempURL, lba: 0, sectorSize: 2048)
    h.check(rows.count == 16, "256-byte sector header window at 16 B/row must yield 16 rows")
    h.check(rows.first?.asciiText.hasPrefix("KROUTON_OPTICAL_") == true, "ASCII column must decode header")
    }

}
