import Foundation

// MARK: - VerifyHarness — Suite 28: Integration Reachability Ratchet
//
// A green krouton-verify proves that code is correct in isolation, not that the app uses it.
// This suite closes that gap with a ratchet:
//   1. Every `public` type in a library target needs a caller in another production file,
//      or an entry in PENDING_INTEGRATION.md (the grandfathered list, with an owner and a date).
//   2. An entry whose type now has a caller must be removed, so the list can only shrink.
//   3. An entry for a type that no longer exists must be removed.
//   4. A type that is only reached through another type's API (a return value, a thrown error)
//      is listed under "Part of a used type's API" with that owner; the owner, or the owner's
//      owner, must have a production caller, so the entry dies with the API it belongs to.
// Wiring a feature, or deleting it, is the only way to make an entry go away.

extension KroutonTestHarness {
    mutating func runVerifyIntegrationReachabilitySuite() {
        let sources = Self.repositoryRoot.appendingPathComponent("Sources")
        let listURL = Self.repositoryRoot.appendingPathComponent("PENDING_INTEGRATION.md")
        let pending = Self.pendingIntegrationEntries(at: listURL)
        let apiOwners = Self.apiOwnerEntries(at: listURL)
        let files = Self.productionSwiftSources(under: sources)

        self.runSuite("28. Integration Reachability Ratchet: Verified Is Not the Same as Wired") { h in
            h.lint(!files.isEmpty, "Suite 28 found no production sources under \(sources.path)")
            let declared = Self.publicLibraryTypes(in: files)
            let declaredNames = Set(declared.map(\.name))
            let pathOf = Dictionary(declared.map { ($0.name, $0.path) }, uniquingKeysWith: { first, _ in first })
            func hasCaller(_ name: String) -> Bool {
                files.contains { $0.key != pathOf[name] && Self.source($0.value, mentions: name) }
            }
            /// The owner is used: directly, through its own owner (a few levels), or, for a free
            /// function, by name in another file.
            func ownerIsUsed(_ owner: String, typePath: String, depth: Int = 0) -> Bool {
                guard depth < 5 else { return false }
                guard pathOf[owner] != nil else {
                    return files.contains { $0.key != typePath && Self.source($0.value, mentions: owner) }
                }
                if hasCaller(owner) { return true }
                guard let next = apiOwners[owner], let ownerPath = pathOf[owner] else { return false }
                return ownerIsUsed(next, typePath: ownerPath, depth: depth + 1)
            }
            for (name, owner) in apiOwners.sorted(by: { $0.key < $1.key }) {
                guard let path = pathOf[name] else { continue }
                // The owner's declaration or one of its extensions must use the type.
                let ownerSources = files.values.filter { src in
                    src.range(of: #"(?m)^(?:public )?(?:final )?(?:struct|enum|class|actor|protocol|extension) \#(owner)\b"#,
                              options: .regularExpression) != nil
                }
                h.lint(pathOf[owner] == nil || ownerSources.contains { Self.source($0, mentions: name) },
                       "\(name) is listed as part of \(owner)'s API, but \(owner) doesn't use it")
                h.lint(ownerIsUsed(owner, typePath: path),
                       "\(name) is listed as part of \(owner)'s API, but \(owner) has no production caller: wire it in or delete both")
            }
            for type in declared {
                let used = hasCaller(type.name)
                if apiOwners[type.name] != nil {
                    h.lint(!used, "\(type.name) is now used directly: remove it from the API list in PENDING_INTEGRATION.md")
                } else if pending.contains(type.name) {
                    h.lint(!used, "\(type.name) is now used in production: remove it from PENDING_INTEGRATION.md")
                } else {
                    h.lint(used, "\(type.name) (\(type.path)) has no production caller: wire it in, delete it, "
                           + "or add it to PENDING_INTEGRATION.md with an owner and a date")
                }
            }
            for name in (pending.union(apiOwners.keys)).sorted() where !declaredNames.contains(name) {
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

    static let apiSectionHeading = "## Part of a used type's API"

    /// Entries outside the API section: types waiting to be wired or deleted.
    static func pendingIntegrationEntries(at url: URL) -> Set<String> {
        let text = (try? String(contentsOf: url, encoding: .utf8)) ?? ""
        var names: Set<String> = []
        var inAPISection = false
        for line in text.components(separatedBy: .newlines) {
            if line.hasPrefix("## ") { inAPISection = line.hasPrefix(apiSectionHeading) }
            guard !inAPISection, line.hasPrefix("- `") else { continue }
            let afterTick = line.dropFirst(3)
            if let end = afterTick.firstIndex(of: "`") {
                names.insert(String(afterTick[..<end]))
            }
        }
        return names
    }

    /// The API section: `- `Type` — `Owner` …`, the type and the used type it belongs to.
    static func apiOwnerEntries(at url: URL) -> [String: String] {
        let text = (try? String(contentsOf: url, encoding: .utf8)) ?? ""
        var owners: [String: String] = [:]
        var inAPISection = false
        for line in text.components(separatedBy: .newlines) {
            if line.hasPrefix("## ") { inAPISection = line.hasPrefix(apiSectionHeading) }
            guard inAPISection, line.hasPrefix("- `") else { continue }
            let ticks = line.split(separator: "`", omittingEmptySubsequences: false)
            if ticks.count >= 5 { owners[String(ticks[1])] = String(ticks[3]) }
        }
        return owners
    }
}
