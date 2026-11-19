import Foundation

// MARK: - VerifyHarness — Suite 28: Integration Reachability Ratchet
//
// A green krouton-verify proves that code is correct in isolation, not that the app uses it.
// This suite closes that gap with a ratchet:
//   1. Every `public` type in a library target needs a caller in another production file,
//      or an entry in PENDING_INTEGRATION.md (the grandfathered list, with an owner and a date).
//   2. An entry whose type now has a caller must be removed, so the list can only shrink.
//   3. An entry for a type that no longer exists must be removed.
// Wiring a feature, or deleting it, is the only way to make an entry go away.

extension KroutonTestHarness {
    mutating func runVerifyIntegrationReachabilitySuite() {
        let sources = Self.repositoryRoot.appendingPathComponent("Sources")
        let pending = Self.pendingIntegrationEntries(at: Self.repositoryRoot.appendingPathComponent("PENDING_INTEGRATION.md"))
        let files = Self.productionSwiftSources(under: sources)

        self.runSuite("28. Integration Reachability Ratchet: Verified Is Not the Same as Wired") { h in
            h.lint(!files.isEmpty, "Suite 28 found no production sources under \(sources.path)")
            let declared = Self.publicLibraryTypes(in: files)
            let declaredNames = Set(declared.map(\.name))
            for type in declared {
                let hasCaller = files.contains { $0.key != type.path && Self.source($0.value, mentions: type.name) }
                if pending.contains(type.name) {
                    h.lint(!hasCaller, "\(type.name) is now used in production: remove it from PENDING_INTEGRATION.md")
                } else {
                    h.lint(hasCaller, "\(type.name) (\(type.path)) has no production caller: wire it in, delete it, "
                           + "or add it to PENDING_INTEGRATION.md with an owner and a date")
                }
            }
            for name in pending.sorted() where !declaredNames.contains(name) {
                h.lint(false, "PENDING_INTEGRATION.md lists \(name), which is no longer a public library type: remove the entry")
            }
        }
    }

    // MARK: - Source Scanning

    static func productionSwiftSources(under root: URL) -> [String: String] {
        guard let walker = FileManager.default.enumerator(at: root, includingPropertiesForKeys: nil) else { return [:] }
        var sources: [String: String] = [:]
        for case let url as URL in walker where url.pathExtension == "swift" && !url.path.contains("/KroutonVerify/") {
            let relative = url.path.replacingOccurrences(of: root.path + "/", with: "")
            sources[relative] = (try? String(contentsOf: url, encoding: .utf8)) ?? ""
        }
        return sources
    }

    static func publicLibraryTypes(in files: [String: String]) -> [(path: String, name: String)] {
        let pattern = #"(?m)^public (?:final )?(?:struct|enum|class|actor|protocol) ([A-Za-z_][A-Za-z0-9_]*)"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return [] }
        var found: [(path: String, name: String)] = []
        for (path, source) in files where !path.hasPrefix("KroutonApp/") {
            let range = NSRange(source.startIndex..., in: source)
            for match in regex.matches(in: source, range: range) {
                if let name = Range(match.range(at: 1), in: source) {
                    found.append((path, String(source[name])))
                }
            }
        }
        return found.sorted { $0.name < $1.name }
    }

    static func source(_ text: String, mentions name: String) -> Bool {
        text.range(of: #"\b\#(name)\b"#, options: .regularExpression) != nil
    }

    static func pendingIntegrationEntries(at url: URL) -> Set<String> {
        let text = (try? String(contentsOf: url, encoding: .utf8)) ?? ""
        var names: Set<String> = []
        for line in text.components(separatedBy: .newlines) where line.hasPrefix("- `") {
            let afterTick = line.dropFirst(3)
            if let end = afterTick.firstIndex(of: "`") {
                names.insert(String(afterTick[..<end]))
            }
        }
        return names
    }
}
