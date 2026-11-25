import Foundation

// MARK: - VerifyHarness — Suite 31: Portable Core

extension KroutonTestHarness {
    /// Libraries an iPad build of Krouton would share with the Mac app. They may depend only on
    /// each other, import nothing macOS-only, and touch macOS-only symbols only inside
    /// `#if os(macOS)`. CI also compiles them for iPadOS (`.github/workflows/ci.yml`), which catches
    /// the macOS-only APIs inside shared frameworks that no text rule can see.
    static let portableModules: Set<String> = ["OpticalCore", "AudioKit", "LabelKit", "RescueKit", "Persistence", "NetworkSpool"]

    static let macOnlyModules: Set<String> = [
        "AppKit", "Cocoa", "IOKit", "DiskArbitration", "DiscRecording", "DiscRecordingUI", "SystemConfiguration",
        "ServiceManagement", "Carbon", "Quartz", "DriveKit", "BurnKit", "ImageKit", "VideoKit", "KroutonApp",
    ]

    static let macOnlySymbols = [
        "Process()", "NSWorkspace", "Host.current", "SecIdentityCreateWithCertificate", "SCDynamicStore",
        "homeDirectoryForCurrentUser", "NSColor", "NSImage", "NSView", "NSFont", "NSScreen", "NSApplication",
        "NSPasteboard", "NSBezierPath", "NSAppearance",
    ]

    mutating func runVerifyPortableCoreSuite() {
        self.runSuite("31. Portable Core: Shared Libraries Stay Free of macOS-Only Frameworks (iPad-Ready)") { h in
            let root = Self.repositoryRoot
            let package = (try? String(contentsOf: root.appendingPathComponent("Package.swift"), encoding: .utf8)) ?? ""
            h.lint(package.contains(".iOS(.v17)"), "Package.swift must list iOS 17 so CI can build the portable core for iPad")
            for module in Self.portableModules.sorted() {
                guard let dependencies = Self.targetDependencies(of: module, in: package) else {
                    h.lint(false, "Package.swift must declare the portable target \(module)")
                    continue
                }
                let foreign = dependencies.filter { !Self.portableModules.contains($0) }
                h.lint(foreign.isEmpty, "\(module) is portable, so it may depend only on portable modules, not \(foreign)")
            }

            var violations: [String] = []
            var files = 0
            for module in Self.portableModules.sorted() {
                let folder = root.appendingPathComponent("Sources/\(module)")
                let enumerator = FileManager.default.enumerator(at: folder, includingPropertiesForKeys: nil)
                while let url = enumerator?.nextObject() as? URL {
                    guard url.pathExtension == "swift", let text = try? String(contentsOf: url, encoding: .utf8) else { continue }
                    files += 1
                    violations += Self.macOnlyUses(in: text).map { "\(module)/\(url.lastPathComponent): \($0)" }
                }
            }
            h.lint(files > 40, "The portable modules' sources must be found (\(files) files)")
            h.lint(violations.isEmpty, "Portable modules must not use macOS-only frameworks outside #if os(macOS): \(violations.prefix(6))")

            let sample = """
            import Foundation
            #if os(macOS)
            import AppKit
            let color = NSColor.red
            #elseif os(iOS)
            let fine = 1
            #else
            let p = Process()
            #endif
            #if !os(macOS)
            let q = NSWorkspace.shared
            #endif
            // NSImage in a comment is fine
            let r = Host.current()
            """
            h.lint(Self.macOnlyUses(in: sample) == ["Process()", "NSWorkspace", "Host.current"],
                   "The scanner must skip #if os(macOS) branches only, and flag macOS-only symbols everywhere else")
        }
    }

    /// The macOS-only imports and symbols `source` uses outside `#if os(macOS)` / `#if canImport(AppKit)`.
    static func macOnlyUses(in source: String) -> [String] {
        var found: [String] = []
        var branches: [Bool] = [] // per open #if: is the active branch macOS-only?
        for raw in source.components(separatedBy: .newlines) {
            let line = raw.trimmingCharacters(in: .whitespaces)
            if line.hasPrefix("#if") {
                branches.append(isMacOnlyCondition(line))
            } else if line.hasPrefix("#elseif") || line.hasPrefix("#else") {
                if !branches.isEmpty { branches[branches.count - 1] = line.hasPrefix("#elseif") && isMacOnlyCondition(line) }
            } else if line.hasPrefix("#endif") {
                _ = branches.popLast()
            } else if branches.contains(true) || line.hasPrefix("//") || line.isEmpty {
                continue
            } else if line.hasPrefix("import ") || line.hasPrefix("@preconcurrency import ") || line.hasPrefix("@testable import ") {
                let module = line.split(separator: " ").last.map(String.init) ?? ""
                if macOnlyModules.contains(module) { found.append("import \(module)") }
            } else {
                found += macOnlySymbols.filter { line.contains($0) }
            }
        }
        return found
    }

    static func isMacOnlyCondition(_ line: String) -> Bool {
        let positive = line.contains("os(macOS)") || line.contains("canImport(AppKit)")
        return positive && !line.contains("!os(macOS)") && !line.contains("!canImport(AppKit)")
    }

    /// The quoted dependency names of a one-line `.target(name: "X", dependencies: [...])`, or nil.
    static func targetDependencies(of module: String, in package: String) -> [String]? {
        guard let line = package.components(separatedBy: .newlines).first(where: { $0.contains(".target(name: \"\(module)\"") }) else {
            return nil
        }
        guard let open = line.range(of: "dependencies: ["), let close = line.range(of: "]", range: open.upperBound..<line.endIndex) else {
            return []
        }
        return line[open.upperBound..<close.lowerBound]
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: CharacterSet(charactersIn: " \"")) }
            .filter { !$0.isEmpty }
    }
}
