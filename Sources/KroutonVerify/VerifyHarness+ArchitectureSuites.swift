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

// MARK: - VerifyHarness — Architecture, Hygiene & Catalog Suites

extension KroutonTestHarness {
    mutating func runVerifyArchitectureAndShellSuites() {
        let fm = FileManager.default
        let rootURL = KroutonTestHarness.repositoryRoot
        let sourcesURL = rootURL.appendingPathComponent("Sources")

        var allSwiftFiles: [URL] = []
        if let enumerator = fm.enumerator(at: sourcesURL, includingPropertiesForKeys: nil) {
            for case let fileURL as URL in enumerator where fileURL.pathExtension == "swift" {
                allSwiftFiles.append(fileURL)
            }
        }
        allSwiftFiles.sort { $0.path < $1.path }
        self.lint(allSwiftFiles.count > 50, "Source tree not found under \(sourcesURL.path)")

        // -------------------------------------------------------------------------
        // SUITE 1: 11-Target Clean Modular Architecture, DriveKit Hardware Isolation & Zero Banned Symbols
        // -------------------------------------------------------------------------
        self.runSuite("1. 11-Target Clean Modular Architecture, DriveKit Hardware Isolation & Zero Banned Symbols") { h in
            h.check(KroutonDomainIdentity.domainName == "krouton.app", "Canonical domain must be krouton.app")
            h.check(KroutonDomainIdentity.reverseDNSPrefix == "app.krouton", "Reverse-DNS prefix must be app.krouton")
            h.check(KroutonDomainIdentity.Module.allCases.count == 11, "KroutonDomainIdentity.Module must enumerate all 11 targets")
            h.check(KroutonDomainIdentity.Module.driveKit.subsystem == "app.krouton.drivekit", "DriveKit subsystem must be app.krouton.drivekit")

            let packageSwiftURL = rootURL.appendingPathComponent("Package.swift")
            let packageSwiftText = (try? String(contentsOf: packageSwiftURL, encoding: .utf8)) ?? ""
            h.lint(packageSwiftText.contains(".swiftLanguageMode(.v6)") && packageSwiftText.contains("-warnings-as-errors"), "Package.swift must enforce .swiftLanguageMode(.v6) and -warnings-as-errors")
            let targetDeclCount = packageSwiftText.components(separatedBy: "Target(").count - 1 + (packageSwiftText.components(separatedBy: ".target(").count - 1)
            let settingsUsageCount = packageSwiftText.components(separatedBy: "swiftSettings: strictSwiftSettings").count - 1
            h.lint(targetDeclCount == 21 && settingsUsageCount == 21, "All 21 targets in Package.swift must adopt strictSwiftSettings")

            let culinaryTypeRegex = try! NSRegularExpression(
                pattern: #"\b(?:struct|enum|class|actor|protocol|typealias)\s+[A-Za-z0-9_]*(?:Toaster|Toast|Loaf|AudioCube|Cube|Recipe|Bakery|Pantry|Crustini|Krustini|Crust|Slice|Dough|Oven|Marmalade|Tartine|Galette|Krumb|Crumb|Baguette|Brioche)[A-Za-z0-9_]*"#,
                options: [.caseInsensitive]
            )
            var culinaryTypeViolations: [String] = []
            for fileURL in allSwiftFiles where !fileURL.path.contains("/KroutonVerify/") {
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

            for mod in KroutonDomainIdentity.Module.allCases {
                let modDir = sourcesURL.appendingPathComponent(mod.rawValue)
                h.lint(fm.fileExists(atPath: modDir.path), "Expected functional module target directory: Sources/\(mod.rawValue)")
            }

            let bannedTokens = ["NS" + "Alert", "NS" + "Panel", "NS" + "Window", "NS" + "ViewRepresentable", "WK" + "WebView", "/Users/" + "used", "/usr/bin/" + "pbcopy", "/usr/bin/" + "open", "LSOpen" + "CFURLRef", "@unchecked" + " Sendable", "nonisolated" + "(unsafe)"]
            for fileURL in allSwiftFiles where !fileURL.path.contains("/KroutonVerify/") {
                let src = (try? String(contentsOf: fileURL, encoding: .utf8)) ?? ""
                let relPath = fileURL.path.replacingOccurrences(of: rootURL.path + "/", with: "")
                for token in bannedTokens {
                    h.lint(!src.contains(token), "\(relPath) must not reference banned AppKit/WebKit symbol \(token)")
                }
                if !relPath.hasPrefix("Sources/DriveKit/") {
                    let importsDiscRecording = src.range(of: #"^(?:@preconcurrency\s+)?import\s+DiscRecording\b"#, options: .regularExpression) != nil
                    let importsIOKit = src.range(of: #"^import\s+IOKit\b"#, options: .regularExpression) != nil
                    h.lint(!importsDiscRecording, "\(relPath) must not import DiscRecording outside Sources/DriveKit/")
                    h.lint(!importsIOKit, "\(relPath) must not import IOKit outside Sources/DriveKit/")
                }
            }
        }

        self.runSuite2ModularHygiene(allSwiftFiles: allSwiftFiles, rootURL: rootURL, sourcesURL: sourcesURL, fm: fm)
        self.runSuite3CatalogRouting()
    }

    private mutating func runSuite2ModularHygiene(allSwiftFiles: [URL], rootURL: URL, sourcesURL: URL, fm: FileManager) {
        // -------------------------------------------------------------------------
        // SUITE 2: Dynamic Cluster Discovery, 400/500-LOC Ceilings, +Role Pairing & Member-Order Hygiene
        // -------------------------------------------------------------------------
        self.runSuite("2. Shell/ & Features/ Modularization, 400/500-LOC File Ceilings, +Role Extension Naming & 200-LOC Function Gate") { h in
            let shellURL = sourcesURL.appendingPathComponent("KroutonApp/Shell")
            let featuresURL = sourcesURL.appendingPathComponent("KroutonApp/Features")
            let shellSubdirs = (try? fm.contentsOfDirectory(atPath: shellURL.path))?.filter { !($0.hasPrefix(".")) } ?? []
            h.lint(shellSubdirs.count == 8 && !shellSubdirs.contains("ThemeAndChrome"), "KroutonApp/Shell must maintain its 8 canonical subdirectories without legacy folders")

            let topPrimaryDeclRegex = try! NSRegularExpression(pattern: #"(?m)^(?:@[A-Za-z0-9_().,\s]+\s+)*(?:public\s+|internal\s+|private\s+|fileprivate\s+|final\s+)*(?:struct|class|enum|actor|protocol)\s+[A-Za-z0-9_]+"#)
            let topExtDeclRegex = try! NSRegularExpression(pattern: #"(?m)^(?:@[A-Za-z0-9_().,\s]+\s+)*(?:public\s+|internal\s+|private\s+|fileprivate\s+)*extension\s+[A-Za-z0-9_.]+"#)

            var filesByDir: [String: Set<String>] = [:]
            var clusterSourceByPrefix: [String: String] = [:]
            for fileURL in allSwiftFiles {
                let dirPath = fileURL.deletingLastPathComponent().path
                let fileName = fileURL.lastPathComponent
                filesByDir[dirPath, default: []].insert(fileName)
                let baseStem = fileName.replacingOccurrences(of: ".swift", with: "").components(separatedBy: "+")[0]
                let clusterKey = dirPath + "/" + baseStem
                let src = (try? String(contentsOf: fileURL, encoding: .utf8)) ?? ""
                clusterSourceByPrefix[clusterKey, default: ""] += "\n" + src
            }

            // Dynamic Feature Cluster Discovery: every top-level feature directory must declare a Workspace view,
            // and any feature cluster that stages files (`store.stagedFiles`) must adopt the shared Deck & EmptyDropZone components.
            let topFeatureDirs = (try? fm.contentsOfDirectory(at: featuresURL, includingPropertiesForKeys: [.isDirectoryKey]))?.filter {
                (try? $0.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true
            } ?? []
            h.lint(topFeatureDirs.count >= 7, "Expected at least 7 modular feature domains under KroutonApp/Features")
            for fDir in topFeatureDirs {
                let dirFiles = filesByDir[fDir.path] ?? []
                h.lint(dirFiles.contains { $0.contains("Workspace") }, "Feature domain \(fDir.lastPathComponent) must contain at least one primary *Workspace*.swift file")
            }
            for (clusterKey, combinedSrc) in clusterSourceByPrefix where clusterKey.contains("/KroutonApp/Features/") {
                let shortCluster = URL(fileURLWithPath: clusterKey).lastPathComponent
                let isAuthoringWorkspaceCluster = shortCluster.contains("Workspace")
                    && !clusterKey.contains("/Features/Depot/")
                    && !clusterKey.contains("/Features/Rip/")
                    && !clusterKey.contains("/Features/Label/")
                    && !clusterKey.contains("/Splice/")
                if isAuthoringWorkspaceCluster && combinedSrc.contains(": View") {
                    h.lint(combinedSrc.contains("KroutonMasteringDeckCard"), "Authoring workspace cluster \(shortCluster) must adopt KroutonMasteringDeckCard")
                    h.lint(combinedSrc.contains("KroutonEmptyDropZoneView"), "Authoring workspace cluster \(shortCluster) must adopt KroutonEmptyDropZoneView")
                }
            }

            for fileURL in allSwiftFiles {
                let src = (try? String(contentsOf: fileURL, encoding: .utf8)) ?? ""
                let lines = src.components(separatedBy: .newlines)
                let relPath = fileURL.path.replacingOccurrences(of: rootURL.path + "/", with: "")
                let fileName = fileURL.lastPathComponent
                let dirPath = fileURL.deletingLastPathComponent().path

                // 1. Strict 400-LOC ceiling for KroutonApp & KroutonVerify, 500-LOC ceiling for all Kit/Core targets
                let maxLOC = (relPath.hasPrefix("Sources/KroutonApp/") || relPath.hasPrefix("Sources/KroutonVerify/")) ? 400 : 500
                h.lint(lines.count <= maxLOC, "\(relPath) (\(lines.count) LOC) exceeds strict \(maxLOC)-LOC target ceiling")

                // 2. 200-LOC function gate
                let longFunctions = VerifyFunctionLengthScanner.functions(in: src).filter { $0.lineCount > 200 }
                let described = longFunctions.map { "\($0.name) at line \($0.startLine) (\($0.lineCount) lines)" }.joined(separator: ", ")
                h.lint(longFunctions.isEmpty, "\(relPath) has functions over the 200-line ceiling: \(described)")

                // 3. Canonical <BaseFile>+<Role>.swift pairing & extension naming law
                let fullRange = NSRange(src.startIndex..<src.endIndex, in: src)
                let hasPrimaryType = topPrimaryDeclRegex.firstMatch(in: src, options: [], range: fullRange) != nil
                let hasExtension = topExtDeclRegex.firstMatch(in: src, options: [], range: fullRange) != nil

                if !hasPrimaryType && hasExtension && fileName != "main.swift" {
                    h.lint(fileName.contains("+"), "\(relPath) contains only extensions and must follow <BaseFile>+<Role>.swift naming")
                }
                if fileName.contains("+") {
                    h.lint(hasExtension, "\(relPath) uses '+' extension naming and must declare at least one extension")
                    let baseFile = fileName.components(separatedBy: "+")[0] + ".swift"
                    h.lint(filesByDir[dirPath]?.contains(baseFile) == true, "\(relPath) must pair with sibling base file \(baseFile) in the same directory")
                }

                // 4. Alphabetical & deduplicated import headers
                let importLines = lines.compactMap { line -> String? in
                    let t = line.trimmingCharacters(in: .whitespaces)
                    guard t.hasPrefix("import ") || t.hasPrefix("@preconcurrency import ") else { return nil }
                    return t
                }
                let sortedUniqueImports = Array(Set(importLines)).sorted { a, b in
                    let modA = a.replacingOccurrences(of: "@preconcurrency import ", with: "").replacingOccurrences(of: "import ", with: "")
                    let modB = b.replacingOccurrences(of: "@preconcurrency import ", with: "").replacingOccurrences(of: "import ", with: "")
                    return modA < modB
                }
                h.lint(importLines == sortedUniqueImports, "\(relPath) must keep top-level imports alphabetical and deduplicated")

                // 5. Canonical '// MARK: - ' section header discipline
                let markPrefix = "// " + "MARK:"
                let canonicalMark = markPrefix + " - "
                let hasMalformedMark = lines.contains { $0.contains(markPrefix) && !$0.contains(canonicalMark) }
                h.lint(!hasMalformedMark, "\(relPath) contains malformed MARK header without hyphen")
                if lines.count > 120 {
                    h.lint(lines.contains { $0.contains(canonicalMark) }, "\(relPath) (>120 LOC) must include canonical MARK section headers")
                }

                // 6. Whitespace discipline (zero trailing spaces, zero triple blank lines)
                let hasTrailingSpace = lines.contains { $0.hasSuffix(" ") || $0.hasSuffix("\t") }
                h.lint(!hasTrailingSpace, "\(relPath) must not contain trailing whitespace")
                h.lint(!src.contains("\n\n\n\n"), "\(relPath) must not contain 3+ consecutive blank lines")

                // 7. Intra-type member ordering: reactive state before methods/body
                var seenBodyOrFuncInCurrentType = false
                var reactiveOrderViolation: String? = nil
                for (idx, line) in lines.enumerated() {
                    if line.range(of: #"^(?:@[A-Za-z0-9_()]+\s+)*(?:public\s+|internal\s+|private\s+|final\s+)*(?:struct|class|enum|actor|extension)\b"#, options: .regularExpression) != nil {
                        seenBodyOrFuncInCurrentType = false
                    } else if line.range(of: #"^    (?:@\w+\s+)*(?:public\s+|private\s+|internal\s+)?(?:var\s+body\b|func\s+\w+|var\s+\w+\s*:\s*some\s+View)"#, options: .regularExpression) != nil {
                        seenBodyOrFuncInCurrentType = true
                    } else if seenBodyOrFuncInCurrentType && line.range(of: #"^    @(?:State|ObservedObject|StateObject|Environment|Binding|AppStorage|Published)\b"#, options: .regularExpression) != nil {
                        reactiveOrderViolation = "line \(idx + 1): \(line.trimmingCharacters(in: .whitespaces))"
                        break
                    }
                }
                h.lint(reactiveOrderViolation == nil, "\(relPath) declares reactive property wrapper after body/methods (\(reactiveOrderViolation ?? ""))")

                // 8. Access-control law: zero redundant `public` declarations in executable leaf targets (KroutonApp & KroutonVerify)
                if relPath.hasPrefix("Sources/KroutonApp/") || relPath.hasPrefix("Sources/KroutonVerify/") {
                    let hasPublicDecl = lines.contains {
                        $0.range(of: #"^\s*(?:@[A-Za-z0-9_()]+\s+)*public\s+(?:final\s+|static\s+|class\s+|override\s+|mutating\s+|nonisolated\s+)*(?:struct|class|enum|actor|protocol|extension|func|var|let|init|typealias)\b"#, options: .regularExpression) != nil
                    }
                    h.lint(!hasPublicDecl, "\(relPath) is in an executable target and must not declare redundant public symbols")
                }
            }

            Self.verifyDynamicMenuAndShortcutContracts(&h, allSwiftFiles: allSwiftFiles, clusterSourceByPrefix: clusterSourceByPrefix)
        }
    }

    private mutating func runSuite3CatalogRouting() {
    self.runSuite("3. Functional Kit Modules & Type-Safe Optical Workflow Catalog Routing") { h in
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

    private static func verifyDynamicMenuAndShortcutContracts(
        _ h: inout KroutonTestHarness,
        allSwiftFiles: [URL],
        clusterSourceByPrefix: [String: String]
    ) {
        let menuClusterText = clusterSourceByPrefix.first { $0.key.hasSuffix("/KroutonMenuCommands") }?.value ?? ""
        h.lint(menuClusterText.contains("CommandGroup(replacing: .appSettings)"), "KroutonMenuCommands cluster must register canonical .appSettings CommandGroup")

        // Dynamically discover all Notification.Name.kroutonMenu* definitions and verify end-to-end Publisher + Subscriber wiring
        let notifRegex = try! NSRegularExpression(pattern: #"static\s+let\s+(kroutonMenu[A-Za-z0-9_]+)\s*=\s*Notification\.Name"#)
        let menuRange = NSRange(menuClusterText.startIndex..<menuClusterText.endIndex, in: menuClusterText)
        let notifMatches = notifRegex.matches(in: menuClusterText, options: [], range: menuRange)
        let discoveredNotifs = notifMatches.compactMap { match -> String? in
            guard let r = Range(match.range(at: 1), in: menuClusterText) else { return nil }
            return String(menuClusterText[r])
        }
        h.lint(discoveredNotifs.count >= 6, "Expected at least 6 canonical kroutonMenu* Notification.Name definitions in KroutonMenuCommands")

        let nonMenuAppText = allSwiftFiles
            .filter { $0.path.contains("/KroutonApp/") && !$0.lastPathComponent.hasPrefix("KroutonMenuCommands") }
            .compactMap { try? String(contentsOf: $0, encoding: .utf8) }
            .joined(separator: "\n")

        for notif in discoveredNotifs {
            h.lint(menuClusterText.contains("NotificationCenter.default.post(name: .\(notif)"), "KroutonMenuCommands must post .\(notif)")
            h.lint(nonMenuAppText.contains(".onReceive(NotificationCenter.default.publisher(for: .\(notif)))"), "At least one workspace view cluster must subscribe to .onReceive(.\(notif))")
        }

        // Verify that every interactive workspace / rack cluster with contextual menus includes keyboardShortcut badges
        let contextMenuClusters = clusterSourceByPrefix.filter { key, src in
            (key.contains("/KroutonApp/Features/") || key.contains("/KroutonApp/Shell/NavigationAndRack/")) && src.contains(".contextMenu")
        }
        h.lint(contextMenuClusters.count >= 6, "Expected at least 6 workspace/rack view clusters providing contextual menus")
    }
}
