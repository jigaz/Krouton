import Foundation

/// Collects results for `krouton-verify` and for the XCTest bridge in `Tests/KroutonVerifyTests`.
///
/// Two kinds of result are counted separately so the summary means what it says:
///   - `check`: a behaviour assertion. Code ran and produced this value.
///   - `lint`: a source-text rule (file size, banned symbol, required directory). No code ran.
struct KroutonTestHarness {
    var passed = 0
    var lintPassed = 0
    var failed = 0
    var failures: [String] = []
    /// When false, nothing is printed; the XCTest bridge reports through `failures` instead.
    var printsProgress = true

    /// The package root, found from this file's own location so the suites do not depend on
    /// the working directory. (`Sources/KroutonVerify/VerifyHarness.swift` -> three levels up.)
    static let repositoryRoot: URL = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .deletingLastPathComponent()

    mutating func check(_ condition: @autoclosure () -> Bool, _ message: String) {
        if condition() {
            passed += 1
        } else {
            recordFailure(message)
        }
    }

    mutating func lint(_ condition: @autoclosure () -> Bool, _ message: String) {
        if condition() {
            lintPassed += 1
        } else {
            recordFailure(message)
        }
    }

    private mutating func recordFailure(_ message: String) {
        failed += 1
        failures.append(message)
        if printsProgress { print("  ❌ FAIL: \(message)") }
    }

    mutating func runSuite(_ title: String, _ block: (inout KroutonTestHarness) throws -> Void) {
        let beforeFail = failed
        do {
            try block(&self)
            if failed == beforeFail, printsProgress {
                print("  ✅ PASS: \(title)")
            }
        } catch {
            failed += 1
            failures.append("\(title): \(error)")
            if printsProgress { print("  ❌ ERROR in \(title): \(error)") }
        }
    }
}

/// Finds every function and initializer body in a Swift source file and measures it in lines.
/// It is a line scanner, not a parser: it skips strings and comments, then matches braces.
/// Computed properties such as a SwiftUI `body` are not functions and are not measured.
// MARK: - Function Length Scanner

enum VerifyFunctionLengthScanner {
    struct Function: Equatable {
        let name: String
        let startLine: Int
        let lineCount: Int
    }

    private static let declaration = try! NSRegularExpression(
        pattern: #"^\s*(?:@[A-Za-z_]+(?:\([^)]*\))?\s+)*(?:(?:public|private|fileprivate|internal|open|static|class|final|override|mutating|nonmutating|nonisolated|convenience|required|isolated|package)(?:\([a-z]+\))?\s+)*(func\s+[A-Za-z_`][A-Za-z0-9_`]*|init[?!]?(?=\s*[(<]))"#
    )
    private static let bodyContinuations = ["{", "where", "->", "throws", "async", "rethrows"]

    static func functions(in source: String) -> [Function] {
        let lines = source.components(separatedBy: "\n")
        var inBlockComment = false
        var inMultilineString = false
        let code = lines.map { codeOnly($0, inBlockComment: &inBlockComment, inMultilineString: &inMultilineString) }

        var found: [Function] = []
        for start in code.indices {
            let line = code[start]
            let range = NSRange(line.startIndex..<line.endIndex, in: line)
            guard let match = declaration.firstMatch(in: line, range: range),
                  let nameRange = Range(match.range(at: 1), in: line) else { continue }

            var parenDepth = 0
            var braceDepth = 0
            var opened = false
            var endLine: Int?
            var cursor = start
            scan: while cursor < code.count {
                for character in code[cursor] {
                    if !opened {
                        if character == "(" { parenDepth += 1 }
                        else if character == ")" { parenDepth -= 1 }
                        else if character == "{" && parenDepth == 0 { opened = true; braceDepth = 1 }
                    } else if character == "{" {
                        braceDepth += 1
                    } else if character == "}" {
                        braceDepth -= 1
                        if braceDepth == 0 { endLine = cursor; break scan }
                    }
                }
                if !opened && parenDepth == 0 {
                    // The signature is complete. If no body follows, this is a protocol requirement.
                    let next = cursor + 1 < code.count ? code[cursor + 1].trimmingCharacters(in: .whitespaces) : ""
                    if !bodyContinuations.contains(where: { next.hasPrefix($0) }) { break }
                }
                cursor += 1
            }
            if let endLine {
                found.append(Function(name: String(line[nameRange]), startLine: start + 1, lineCount: endLine - start + 1))
            }
        }
        return found
    }

    /// Returns `line` with string literals and comments removed, so their braces are not counted.
    private static func codeOnly(_ line: String, inBlockComment: inout Bool, inMultilineString: inout Bool) -> String {
        let chars = Array(line)
        var out = ""
        var index = 0
        func hasPrefix(_ text: String, at position: Int) -> Bool {
            let wanted = Array(text)
            guard position + wanted.count <= chars.count else { return false }
            return Array(chars[position..<position + wanted.count]) == wanted
        }
        while index < chars.count {
            if inMultilineString {
                guard let close = (index..<chars.count).first(where: { hasPrefix("\"\"\"", at: $0) }) else { return out }
                inMultilineString = false
                index = close + 3
                continue
            }
            if inBlockComment {
                guard let close = (index..<chars.count).first(where: { hasPrefix("*/", at: $0) }) else { return out }
                inBlockComment = false
                index = close + 2
                continue
            }
            if hasPrefix("//", at: index) { break }
            if hasPrefix("/*", at: index) { inBlockComment = true; index += 2; continue }
            if hasPrefix("\"\"\"", at: index) { inMultilineString = true; index += 3; continue }
            if chars[index] == "\"" {
                index += 1
                while index < chars.count && chars[index] != "\"" {
                    index += chars[index] == "\\" ? 2 : 1
                }
                index += 1
                continue
            }
            out.append(chars[index])
            index += 1
        }
        return out
    }
}
