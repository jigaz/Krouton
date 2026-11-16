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

func runVerifyArchitectureAndShellSuites(_ harness: inout KroutonTestHarness) {
    let fm = FileManager.default
    let rootURL = KroutonTestHarness.repositoryRoot
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
    harness.lint(allSwiftFiles.count > 50, "Source tree not found under \(sourcesURL.path); the source-rule suites would pass without checking anything")

    // -------------------------------------------------------------------------
    // SUITE 1: 11-Target Functional Module Architecture, Hardware Isolation & Zero Banned Symbols
    // -------------------------------------------------------------------------
    harness.runSuite("1. 11-Target Clean Modular Architecture, DriveKit Hardware Isolation & Zero Banned Symbols") { h in
        h.check(KroutonDomainIdentity.domainName == "krouton.app", "Canonical domain must be krouton.app")
        h.check(KroutonDomainIdentity.reverseDNSPrefix == "app.krouton", "Reverse-DNS prefix must be app.krouton")
        h.check(KroutonDomainIdentity.Module.allCases.count == 11, "KroutonDomainIdentity.Module must enumerate all 11 targets")
        h.check(KroutonDomainIdentity.Module.driveKit.subsystem == "app.krouton.drivekit", "DriveKit subsystem must be app.krouton.drivekit")

        let culinaryTypeRegex = try! NSRegularExpression(
            pattern: #"\b(?:struct|enum|class|actor|protocol|typealias)\s+[A-Za-z0-9_]*(?:Toaster|Toast|Loaf|AudioCube|Cube|Recipe|Bakery|Pantry|Crustini|Krustini|Crust|Slice|Dough|Oven|Marmalade|Tartine|Galette|Krumb|Crumb|Baguette|Brioche)[A-Za-z0-9_]*"#,
            options: [.caseInsensitive]
        )
        var culinaryTypeViolations: [String] = []
        for fileURL in allSwiftFiles {
            let content = (try? String(contentsOf: fileURL, encoding: .utf8)) ?? ""
            for line in content.components(separatedBy: .newlines) {
                let trimmed = line.trimmingCharacters(in: .whitespaces)
                if trimmed.hasPrefix("//") { continue }
                let range = NSRange(trimmed.startIndex..<trimmed.endIndex, in: trimmed)
                if culinaryTypeRegex.firstMatch(in: trimmed, options: [], range: range) != nil {
                    culinaryTypeViolations.append("\(fileURL.lastPathComponent): \(trimmed)")
                }
            }
        }
        h.lint(culinaryTypeViolations.isEmpty, "Zero culinary type declarations allowed across Sources/: \(culinaryTypeViolations.joined(separator: ", "))")
        let expectedModules = [
            "OpticalCore", "DriveKit", "BurnKit", "AudioKit", "ImageKit",
            "RescueKit", "LabelKit", "VideoKit", "NetworkSpool", "Persistence", "KroutonApp"
        ]
        for mod in expectedModules {
            let modDir = sourcesURL.appendingPathComponent(mod)
            h.lint(fm.fileExists(atPath: modDir.path), "Expected functional module target directory: Sources/\(mod)")
        }

        let bannedTokens = ["NS" + "Alert", "NS" + "Panel", "NS" + "Window", "NS" + "ViewRepresentable", "WK" + "WebView"]
        for fileURL in allSwiftFiles {
            let src = (try? String(contentsOf: fileURL, encoding: .utf8)) ?? ""
            let relPath = fileURL.path.replacingOccurrences(of: rootURL.path + "/", with: "")

            for token in bannedTokens {
                h.lint(!src.contains(token), "\(relPath) must not reference banned AppKit/WebKit symbol \(token)")
            }

            // Hardware Isolation Gate: ONLY Sources/DriveKit/ may import DiscRecording or IOKit
            if !relPath.hasPrefix("Sources/DriveKit/") {
                let importsDiscRecording = src.range(of: #"^(?:@preconcurrency\s+)?import\s+DiscRecording\b"#, options: .regularExpression) != nil
                let importsIOKit = src.range(of: #"^import\s+IOKit\b"#, options: .regularExpression) != nil
                h.lint(!importsDiscRecording, "\(relPath) must not import DiscRecording outside Sources/DriveKit/")
                h.lint(!importsIOKit, "\(relPath) must not import IOKit outside Sources/DriveKit/")
            }
        }
    }

    harness.runSuite("2. Shell/ & Features/ Modularization, 600-LOC File Ceiling & 200-LOC Function Gate") { h in
        let shellDirs = ["App", "StateAndModels", "DesignSystem", "NavigationAndRack", "ModalsAndSettings", "Services"]
        for dir in shellDirs {
            let p = sourcesURL.appendingPathComponent("KroutonApp/Shell/\(dir)").path
            h.lint(fm.fileExists(atPath: p), "Missing KroutonApp/Shell directory: \(dir)")
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
            h.lint(fm.fileExists(atPath: p), "Expected modular feature workspace file: Features/\(rel)")
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
            h.lint(content.contains("KroutonMasteringDeckCard"), "Features/\(rel) must adopt KroutonMasteringDeckCard")
            h.lint(content.contains("KroutonEmptyDropZoneView"), "Features/\(rel) must adopt KroutonEmptyDropZoneView")
        }

        for fileURL in allSwiftFiles {
            let src = (try? String(contentsOf: fileURL, encoding: .utf8)) ?? ""
            let lines = src.components(separatedBy: .newlines)
            let relPath = fileURL.path.replacingOccurrences(of: rootURL.path + "/", with: "")
            h.lint(lines.count <= 600, "\(relPath) (\(lines.count) LOC) exceeds 600-LOC file ceiling")
            let longFunctions = VerifyFunctionLengthScanner.functions(in: src).filter { $0.lineCount > 200 }
            let described = longFunctions.map { "\($0.name) at line \($0.startLine) (\($0.lineCount) lines)" }.joined(separator: ", ")
            h.lint(longFunctions.isEmpty, "\(relPath) has functions over the 200-line ceiling: \(described)")
        }
        verifyMenuAndContextualShortcutParity(&h)
    }

    harness.runSuite("3. Functional Kit Modules & Type-Safe Optical Workflow Catalog Routing") { h in
    h.check(KroutonAudioEngine.version == "0.1.0-alpha.1", "AudioKit version")
    h.check(KroutonVideoAuthoringEngine.version == "0.1.0-alpha.1", "VideoKit version")
    h.check(KroutonHybridImagePlanner.version == "0.1.0-alpha.1", "ImageKit Hybrid Planner version")
    h.check(KroutonDiscImageDepot.version == "0.1.0-alpha.1", "ImageKit Depot version")
    h.check(KroutonLabelGeometryEngine.version == "0.1.0-alpha.1", "LabelKit version")
    let autoTrack = KroutonTrackAutoIdentifier.identifyTrack(url: URL(fileURLWithPath: "/tmp/01 - Solar Echoes.wav"), trackNumber: 1, fallbackPerformer: "Krouton Studio")
    h.check(!autoTrack.title.isEmpty && !autoTrack.performer.isEmpty, "KroutonTrackAutoIdentifier must parse track metadata conservatively")
    let pyramid = PeakPyramid(mono: [Float](repeating: 0.42, count: 1176))
    h.check(!pyramid.levels.isEmpty && pyramid.levels[0].maxima.count == 2, "PeakPyramid must compute 588-sample Red Book frame peaks")
    h.check(SpoolLANSecurityEngine.isAllowedLANEndpoint("http://192.168.1.50:7420") && !SpoolLANSecurityEngine.isAllowedLANEndpoint("https://example.com:7420"), "SpoolLANSecurityEngine must enforce RFC-1918 / mDNS LAN boundary")


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
}

private func verifyMenuAndContextualShortcutParity(_ h: inout KroutonTestHarness) {
    let repoRoot = KroutonTestHarness.repositoryRoot
    let menuCmdURL = repoRoot.appendingPathComponent("Sources/KroutonApp/Shell/App/KroutonMenuCommands.swift")
    let menuCmdText = (try? String(contentsOf: menuCmdURL, encoding: .utf8)) ?? ""
    h.lint(menuCmdText.contains("CommandGroup(replacing: .appSettings)"), "KroutonMenuCommands must register canonical .appSettings CommandGroup")
    for notif in ["kroutonMenuScanTOC", "kroutonMenuRipSelected", "kroutonMenuShowCDInfo", "kroutonMenuInspectHybridLBA", "kroutonMenuInspectAudioCue", "kroutonMenuInspectVideoBitrate"] {
        h.lint(menuCmdText.contains("static let \(notif)") && menuCmdText.contains(".\(notif)"), "KroutonMenuCommands must declare and post \(notif)")
    }
    for fmtID in ["data-hybrid", "cd-da", "dvd-video", "bd-r-sl", "m-disc", "image-burn", "copy-rescue"] {
        h.lint(menuCmdText.contains("\"\(fmtID)\""), "KroutonMenuCommands must route workflow task ID \(fmtID)")
    }
    let popoverBindings: [(String, String, String)] = [
        ("Sources/KroutonApp/Features/Data/DataAndArchivalWorkspaces.swift", ".kroutonMenuInspectHybridLBA", "showHybridLBAMapPopover = true"),
        ("Sources/KroutonApp/Features/AudioCD/AudioMasteringWorkspaces.swift", ".kroutonMenuInspectAudioCue", "showAudioCuePopover = true"),
        ("Sources/KroutonApp/Features/Video/VideoAuthoringWorkspaces.swift", ".kroutonMenuInspectVideoBitrate", "showVideoBitratePopover = true")
    ]
    for (relPath, notifName, stateAssign) in popoverBindings {
        let fileText = (try? String(contentsOf: repoRoot.appendingPathComponent(relPath), encoding: .utf8)) ?? ""
        h.lint(fileText.contains(".onReceive(NotificationCenter.default.publisher(for: \(notifName)))") && fileText.contains(stateAssign), "\(relPath) must wire .onReceive(\(notifName)) to \(stateAssign)")
    }
    let contextMenuFiles = [
        "Sources/KroutonApp/Features/Data/DataAndArchivalWorkspaces.swift",
        "Sources/KroutonApp/Features/AudioCD/AudioMasteringWorkspaces.swift",
        "Sources/KroutonApp/Features/Rip/CopyAndRipWorkspaces+AudioUX.swift",
        "Sources/KroutonApp/Shell/NavigationAndRack/KroutonDestinationRackViews.swift",
        "Sources/KroutonApp/Shell/NavigationAndRack/KroutonNavigationAndTelemetryBars.swift",
        "Sources/KroutonApp/Features/Label/DiscLabelWorkspace.swift",
        "Sources/KroutonApp/Features/Label/DiscLabelWorkspaceShapesInspector.swift",
        "Sources/KroutonApp/Features/Depot/KroutonDepotCatalogViews.swift"
    ]
    for relPath in contextMenuFiles {
        let fileText = (try? String(contentsOf: repoRoot.appendingPathComponent(relPath), encoding: .utf8)) ?? ""
        h.lint(fileText.contains(".contextMenu") && fileText.contains(".keyboardShortcut("), "\(relPath) must provide .contextMenu with .keyboardShortcut badges")
    }
}
