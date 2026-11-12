import SwiftUI
import Foundation
import OpticalDough
import Marmalade
import VideoOven
import Tartine
import Galette
import Crustini

struct KroutonTestHarness {
    var passed = 0
    var failed = 0

    mutating func check(_ condition: @autoclosure () -> Bool, _ message: String) {
        if condition() {
            passed += 1
        } else {
            failed += 1
            print("  ❌ FAIL: \(message)")
        }
    }

    mutating func runSuite(_ title: String, _ block: (inout KroutonTestHarness) throws -> Void) {
        let beforeFail = failed
        do {
            try block(&self)
            if failed == beforeFail {
                print("  ✅ PASS: \(title)")
            }
        } catch {
            failed += 1
            print("  ❌ ERROR in \(title): \(error)")
        }
    }
}

print("=== KROUTON ARCHITECTURE & CORE INVARIANT SUITE (krouton-verify) ===")
var harness = KroutonTestHarness()

harness.runSuite("1. 21/21 (100%) AppKit-Free Clean Architecture & Zero Banned Symbols Gate") { h in
    let repoRoot = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .deletingLastPathComponent()
    let sourcesURL = repoRoot.appendingPathComponent("Sources")

    let fm = FileManager.default
    let enumerator = fm.enumerator(at: sourcesURL, includingPropertiesForKeys: nil)!
    var swiftFiles: [URL] = []
    for case let fileURL as URL in enumerator where fileURL.pathExtension == "swift" {
        if !fileURL.path.contains("/KroutonVerify/") {
            swiftFiles.append(fileURL)
        }
    }
    h.check(swiftFiles.count == 21, "Expected 21 production Swift files, found \(swiftFiles.count)")

    let bannedEverywhere = [
        "import AppKit", "NSWindow", "NSApp", "NSPasteboard", "NSWorkspace", "NSColor",
        "NSOpenPanel",
        "NSSavePanel",
        "NSSound",
        "NSBitmapImageRep",
        "NSAccessibility",
        ".nsImage"
    ]

    var filesImportingAppKit: [String] = []
    for fileURL in swiftFiles {
        let relPath = fileURL.path.replacingOccurrences(of: repoRoot.path + "/", with: "")
        let content = try String(contentsOf: fileURL, encoding: .utf8)
        let activeLines = content
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.hasPrefix("//") && !$0.hasPrefix("/*") }

        for line in activeLines {
            if line.hasPrefix("import AppKit") {
                filesImportingAppKit.append(relPath)
            }
            for banned in bannedEverywhere {
                h.check(!line.contains(banned), "Banned symbol \(banned) in \(relPath): \(line)")
            }
        }
    }
    h.check(
        filesImportingAppKit.isEmpty,
        "AppKit must only be imported in KroutonApp.swift, found: \(filesImportingAppKit)"
    )
}

harness.runSuite("2. Specialized Bakery Sub-Modules (Marmalade, VideoOven, Tartine, Galette, Crustini)") { h in
    h.check(KroutonMarmaladeModule.version == "0.1.0-alpha.1", "Marmalade version")
    h.check(KroutonVideoOvenModule.version == "0.1.0-alpha.1", "VideoOven version")
    h.check(KroutonTartineModule.version == "0.1.0-alpha.1", "Tartine version")
    h.check(KroutonGaletteModule.version == "0.1.0-alpha.1", "Galette version")
    h.check(KroutonKrustiniModule.version == "0.1.0-alpha.1", "Crustini version")
}

harness.runSuite("3. Red Book CD-Text, ISRC (ISO 3901) & MCN Sanitizer Constraints") { h in
    let sanitizedText = KroutonSeasoningSanitizer.sanitize("Café   Krouton — Live!\n\t")
    h.check(!sanitizedText.isEmpty && sanitizedText.allSatisfy { $0.isASCII }, "CD-Text ASCII sanitization")

    let isrc = KroutonSeasoningSanitizer.sanitizeISRC("us-kro-26-00001-extra")
    h.check(isrc == "USKRO2600001" && isrc.count == 12, "ISRC 12-char normalization")

    let mcn = KroutonSeasoningSanitizer.sanitizeMCN("0123-4567-89012-abc")
    h.check(mcn == "0123456789012" && mcn.count == 13, "MCN 13-digit EAN-13 normalization")
}

harness.runSuite("4. Red Book Audio Cube Frame (75 fps) & PCM Byte (2352 B/frame) Math") { h in
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

harness.runSuite("5. ISO-9660 / Joliet / UDF File Entry Limits & 2048-Byte LBA Math") { h in
    let fiveGiB: Int64 = 5 * 1024 * 1024 * 1024
    let longName = String(repeating: "K", count: 70) + ".iso"
    let entry = KroutonLoafFileEntry(
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

harness.runSuite("6. SHA-256 Digest & 2048-Byte Sector Hex Dump Inspector") { h in
    let tempURL = FileManager.default.temporaryDirectory
        .appendingPathComponent("krouton_test_\(UUID().uuidString).iso")
    defer { try? FileManager.default.removeItem(at: tempURL) }

    var payload = Data("KROUTON_OPTICAL_MASTER".utf8)
    payload.append(Data(repeating: 0xAA, count: 2048 - payload.count))
    try payload.write(to: tempURL)

    let sha = KroutonLoafBootInspector.computeSHA256Hex(url: tempURL)
    h.check(sha.count == 64, "SHA-256 digest must be 64 hex characters")

    let rows = KroutonLoafBootInspector.readSectorHexDump(url: tempURL, lba: 0, sectorSize: 2048)
    h.check(rows.count == 16, "256-byte sector header window at 16 B/row must yield 16 rows")
    h.check(rows.first?.asciiText.hasPrefix("KROUTON_OPTICAL_") == true, "ASCII column must decode header")
}

harness.runSuite("7. Hardware Acceleration Codec Matrix & Container Stream Probing") { h in
    let matrix = KroutonPantryPrepEngine.liveHardwareCodecMatrix
    h.check(matrix.count >= 6, "Expected at least 6 codec rows in hardware matrix")

    let mkvProbe = KroutonPantryPrepEngine.probeFile(URL(fileURLWithPath: "/tmp/concert.mkv"))
    h.check(mkvProbe.fileExtension == "MKV" && mkvProbe.isHardwareAccelerated, "MKV hardware probe")

    let flacProbe = KroutonPantryPrepEngine.probeFile(URL(fileURLWithPath: "/tmp/master.flac"))
    h.check(flacProbe.accelerationTier == .accelerateSIMD, "FLAC Accelerate SIMD tier")
}

harness.runSuite("8. Krumb Wire Protocol Codable Round-Trip & mDNS Host Sanitization") { h in
    h.check(KrumbNetworkConstants.defaultPort == 7420, "Krumb default TCP port 7420")
    h.check(KrumbNetworkConstants.minimumPantryFreeBytes == 1_073_741_824, "1 GiB Pantry minimum rule")

    let host = KrumbKitchenClient.sanitizeMdnsHostname("Mac Studio (2)")
    h.check(host == "mac-studio-2" && !host.contains(" "), "mDNS RFC-1123 hostname label sanitizer")

    let req = KrumbBakeRequest(
        batchId: UUID(),
        pantryLoafId: UUID(),
        toasterIds: ["pioneer-bdr-xs07s"],
        heatX: 16,
        mode: .toast,
        doggyBag: .notesOnlyOnFailure,
        seasoning: KrumbSeasoning(albumTitle: "Krouton Sessions", performer: "VentureCorp"),
        cubes: [
            KrumbCubePayload(trackNumber: 1, filename: "01.wav", title: "Overture", performer: "VentureCorp", isrc: "USKRO2600001", pregapMs: 2000)
        ]
    )

    let data = try JSONEncoder().encode(req)
    let jsonString = String(data: data, encoding: .utf8)!
    h.check(jsonString.contains("pantry_loaf_id") && jsonString.contains("doggy_bag"), "Snake-case wire keys")

    let decoded = try JSONDecoder().decode(KrumbBakeRequest.self, from: data)
    h.check(decoded.batchId == req.batchId && decoded.heatX == 16 && decoded.mode == .toast, "Round-trip decode")
}


// 9. Pure IEEE-754 RGB <-> HSB Bijective Math & 10-Swatch Display-P3 Harmony Engine
harness.runSuite("9. IEEE-754 RGB <-> HSB Round-Trip & 10-Swatch Display-P3 Harmony Polarity") { h in
    // 9a. Test all 6 HSV Hue Sectors (0..5) + Neutral Grayscale (s = 0)
    let testRGBSamples: [(CGFloat, CGFloat, CGFloat)] = [
        (0.95, 0.18, 0.22), // Sector 0: Laser Crimson
        (0.92, 0.68, 0.12), // Sector 1: Solar Gold
        (0.18, 0.88, 0.34), // Sector 2: Oscilloscope Green
        (0.14, 0.82, 0.86), // Sector 3: Analog Seafoam Teal
        (0.22, 0.38, 0.96), // Sector 4: Laser Cobalt Blue
        (0.88, 0.20, 0.78), // Sector 5: Synth Magenta
        (0.45, 0.45, 0.45), // Achromatic Titanium Neutral
        (0.00, 0.00, 0.00), // Pure Black
        (1.00, 1.00, 1.00)  // Pure White
    ]

    for (r, g, b) in testRGBSamples {
        let (hue, sat, val) = KroutonPureColorMath.rgbToHSB(r: r, g: g, b: b)
        h.check(hue >= 0.0 && hue <= 1.0, "Hue must be normalized in [0, 1]")
        h.check(sat >= 0.0 && sat <= 1.0, "Saturation must be normalized in [0, 1]")
        h.check(val >= 0.0 && val <= 1.0, "Brightness/Value must be normalized in [0, 1]")

        let (r2, g2, b2) = KroutonPureColorMath.hsbToRGB(h: hue, s: sat, v: val)
        h.check(abs(r - r2) < 1e-4 && abs(g - g2) < 1e-4 && abs(b - b2) < 1e-4,
                "RGB -> HSB -> RGB round-trip drift exceeded 1e-4 for (\(r), \(g), \(b)) -> (\(r2), \(g2), \(b2))")
    }

    // 9b. Verify all 10 Swatch Presets (0..9) in Dark & Light mode produce distinct, valid Display-P3 colors
    //     and obey the WCAG Luminance Polarity Invariant (Dark mode harmony brighter than Light mode studio ink)
    for presetID in 0...9 {
        let darkColor  = KroutonPureColorMath.secondaryHarmonyForPresetID(presetID, scheme: .dark)
        let lightColor = KroutonPureColorMath.secondaryHarmonyForPresetID(presetID, scheme: .light)

        let (dr, dg, db, da) = KroutonPureColorMath.extractSRGB(darkColor)
        let (lr, lg, lb, la) = KroutonPureColorMath.extractSRGB(lightColor)

        h.check(da == 1.0 && la == 1.0, "Swatch #\(presetID) opacity must be 1.0")

        // Rec. 709 relative luminance approximation
        let darkLuma  = 0.2126 * dr + 0.7152 * dg + 0.0722 * db
        let lightLuma = 0.2126 * lr + 0.7152 * lg + 0.0722 * lb

        h.check(
            darkLuma > lightLuma,
            "Swatch #\(presetID) Dark Mode phosphor luma (\(darkLuma)) must exceed Light Mode ink luma (\(lightLuma))"
        )
    }
}


// 10. LAN Network Security (RFC-1918 Subnet Guard, HMAC-SHA256 Wire Signing & Replay Protection)
harness.runSuite("10. Krumb LAN Security Engine (RFC-1918 Subnet Guard, HMAC-SHA256 & Anti-Replay)") { h in
    // 10a. Allowed LAN / Loopback / mDNS endpoints
    let allowedEndpoints = [
        "localhost:7420",
        "http://127.0.0.1:7420/api/v1/toasters",
        "ws://192.168.1.42:7420/ws/kitchen",
        "10.0.14.8:7420",
        "172.16.0.5:7420",
        "172.31.255.254:7420",
        "169.254.12.34:7420",
        "krumb-pi3b.local:7420",
        "[::1]:7420",
        "[fe80::1]:7420"
    ]
    for ep in allowedEndpoints {
        h.check(KrumbLANSecurityEngine.isAllowedLANEndpoint(ep), "Expected LAN endpoint '\(ep)' to be allowed")
    }

    // 10b. Blocked Public WAN / Malformed endpoints
    let blockedEndpoints = [
        "8.8.8.8:7420",
        "1.1.1.1:7420",
        "172.15.0.1:7420",
        "172.32.0.1:7420",
        "192.169.1.1:7420",
        "http://evil.example.com:7420",
        "999.999.999.999:7420",
        ""
    ]
    for ep in blockedEndpoints {
        h.check(!KrumbLANSecurityEngine.isAllowedLANEndpoint(ep), "Expected public/invalid endpoint '\(ep)' to be BLOCKED")
    }

    // 10c. HMAC-SHA256 Signing, Tamper Rejection, Clock Skew & Nonce Replay Protection
    let secret = "krouton-kitchen-lan-key-2026"
    let payload = Data("{\"action\":\"toast\",\"heat_x\":16}".utf8)
    let now: Int64 = 1_775_000_000
    var seenNonces: Set<String> = []

    let env = KrumbLANSecurityEngine.signPayload(payload, sharedSecret: secret, timestampEpochSeconds: now, nonce: "nonce-001")
    h.check(env.signatureHex.count == 64, "HMAC-SHA256 hex signature must be 64 characters")

    // First verification succeeds
    let verifiedData = KrumbLANSecurityEngine.verifyEnvelope(env, sharedSecret: secret, nowEpochSeconds: now + 5, seenNonces: &seenNonces)
    h.check(verifiedData == payload, "Authentic HMAC-SHA256 envelope must verify and return exact payload")

    // Replay with same nonce must fail
    let replayAttempt = KrumbLANSecurityEngine.verifyEnvelope(env, sharedSecret: secret, nowEpochSeconds: now + 6, seenNonces: &seenNonces)
    h.check(replayAttempt == nil, "Replayed nonce must be rejected")

    // Expired timestamp (> 30s skew) must fail
    let expiredEnv = KrumbLANSecurityEngine.signPayload(payload, sharedSecret: secret, timestampEpochSeconds: now - 60, nonce: "nonce-002")
    let expiredAttempt = KrumbLANSecurityEngine.verifyEnvelope(expiredEnv, sharedSecret: secret, nowEpochSeconds: now, seenNonces: &seenNonces)
    h.check(expiredAttempt == nil, "Stale timestamp outside +/-30s window must be rejected")

    // Tampered payload must fail
    let tamperedEnv = KrumbSignedEnvelope(
        timestampEpochSeconds: now,
        nonce: "nonce-003",
        signatureHex: env.signatureHex,
        payloadBase64: Data("{\"action\":\"toast\",\"heat_x\":99}".utf8).base64EncodedString()
    )
    let tamperedAttempt = KrumbLANSecurityEngine.verifyEnvelope(tamperedEnv, sharedSecret: secret, nowEpochSeconds: now, seenNonces: &seenNonces)
    h.check(tamperedAttempt == nil, "Tampered payload with forged signature must be rejected")
}


// 11. Marmalade Red Book CUE Compiler, 18-Byte CD-Text CRC-16 Packager & Equal-Power Crossfade
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

print("\n🎯 SUMMARY: \(harness.passed) assertions passed, \(harness.failed) failed.")
if harness.failed > 0 {
    exit(1)
}
