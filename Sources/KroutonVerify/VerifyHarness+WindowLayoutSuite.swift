import Foundation
import OpticalCore

// MARK: - VerifyHarness — Suite 39: Window Layout

/// The main window's columns switch to short labels when they get narrow. Until 2026-11-27 that
/// was five flags passed through initializers; now it is one `KroutonWindowLayout` in the
/// SwiftUI environment. This suite checks that the switch happens at exactly the widths it did
/// before (the short labels were sized for them), that every label whose text depends on it is
/// held to one line, and that no view goes back to taking a flag through its initializer.
extension KroutonTestHarness {
    mutating func runVerifyWindowLayoutSuite() {
        self.runSuite("39. Window Layout: Breakpoints Carried Over, Labels Held to One Line") { h in
            Self.checkBreakpointsMatchTheOldFlags(&h)
            Self.checkNoFlicker(&h)
            try Self.checkViewsReadTheEnvironment(&h)
        }
    }

    // MARK: - The Flags Before 2026-11-27

    /// The old flag logic, copied from `KroutonMainWorkspaceView` as it was: a first value on
    /// appear, then a change only past the far side of the gap.
    private struct OldFlag {
        let appearBelow: Double
        let narrowBelow: Double
        let regularAbove: Double
        var value: Bool? = nil

        mutating func update(_ width: Double) -> Bool {
            switch value {
            case nil: value = width < appearBelow
            case false?: if width < narrowBelow { value = true }
            case true?: if width > regularAbove { value = false }
            }
            return value!
        }
    }

    private static func checkBreakpointsMatchTheOldFlags(_ h: inout KroutonTestHarness) {
        var seed: UInt64 = 0x4B52_4F55_544F_4E21
        func nextWidth(in range: ClosedRange<Double>) -> Double {
            seed = seed &* 6_364_136_223_846_793_005 &+ 1_442_695_040_888_963_407
            let unit = Double(seed >> 11) / Double(1 << 53)
            return (range.lowerBound + unit * (range.upperBound - range.lowerBound)).rounded()
        }
        var mismatches = 0
        for _ in 0..<400 {
            var sidebar = OldFlag(appearBelow: 215, narrowBelow: 215, regularAbove: 228)
            var workspace = OldFlag(appearBelow: 520, narrowBelow: 510, regularAbove: 535)
            var queue = OldFlag(appearBelow: 355, narrowBelow: 355, regularAbove: 368)
            var layout: KroutonWindowLayout? = nil
            for _ in 0..<40 {
                let (s, w, q) = (nextWidth(in: 182...340), nextWidth(in: 345...900), nextWidth(in: 262...440))
                let next = KroutonWindowLayout.forWidths(sidebar: s, workspace: w, queue: q, previous: layout)
                let old = (sidebar.update(s), workspace.update(w), queue.update(q))
                if (next.sidebar == .narrow, next.workspace == .narrow, next.queue == .narrow) != old { mismatches += 1 }
                layout = next
            }
        }
        h.check(mismatches == 0, "KroutonWindowLayout must switch at the widths the old flags did (\(mismatches) of 16,000 steps differ)")
        h.check(KroutonWindowLayout.workspaceBreakpoint == KroutonColumnBreakpoint(narrowBelow: 510, regularAbove: 535, startsNarrowBelow: 520)
                && KroutonWindowLayout.sidebarBreakpoint == KroutonColumnBreakpoint(narrowBelow: 215, regularAbove: 228, startsNarrowBelow: 215)
                && KroutonWindowLayout.queueBreakpoint == KroutonColumnBreakpoint(narrowBelow: 355, regularAbove: 368, startsNarrowBelow: 355),
                "The breakpoints the short labels were sized for must not move without the labels")
    }

    /// Dragging a splitter slowly across a breakpoint and back changes the size once each way.
    private static func checkNoFlicker(_ h: inout KroutonTestHarness) {
        var layout: KroutonWindowLayout? = nil
        var changes = 0
        let down = stride(from: 700.0, through: 345.0, by: -0.5)
        let up = stride(from: 345.0, through: 700.0, by: 0.5)
        for width in Array(down) + Array(up) {
            let next = KroutonWindowLayout.forWidths(sidebar: 300, workspace: width, queue: 400, previous: layout)
            if let layout, layout.workspace != next.workspace { changes += 1 }
            layout = next
        }
        h.check(changes == 2, "A slow drag across the workspace breakpoint and back must switch twice, not \(changes) times")
        let jitter = [512.0, 509.0, 511.0, 509.5, 520.0, 534.0, 530.0, 535.0]
        var sizes: [KroutonColumnSize] = []
        var current: KroutonWindowLayout? = .forWidths(sidebar: 300, workspace: 540, queue: 400, previous: nil)
        for width in jitter {
            current = .forWidths(sidebar: 300, workspace: width, queue: 400, previous: current)
            sizes.append(current!.workspace)
        }
        h.check(sizes == [.regular, .narrow, .narrow, .narrow, .narrow, .narrow, .narrow, .narrow],
                "Inside the gap (510–535) the workspace must keep the size it had")
    }

    // MARK: - Views

    private static let layoutFlags = ["isCenterWorkspaceNarrow", "isRightQueueCompact", "isLeftSidebarUltraSkinny"]

    private static func checkViewsReadTheEnvironment(_ h: inout KroutonTestHarness) throws {
        let appRoot = KroutonTestHarness.repositoryRoot.appendingPathComponent("Sources/KroutonApp")
        let files = FileManager.default.enumerator(at: appRoot, includingPropertiesForKeys: nil)?
            .compactMap { $0 as? URL }.filter { $0.pathExtension == "swift" } ?? []
        var passedAsArgument: [String] = []
        var unheld: [String] = []
        var labels = 0
        var publishes = false
        for url in files {
            let source = try String(contentsOf: url, encoding: .utf8)
            let name = url.lastPathComponent
            if source.contains(".environment(\\.kroutonLayout,") { publishes = true }
            for flag in layoutFlags {
                if source.contains("\(flag): \(flag)") || source.contains("let \(flag): Bool") || source.contains("@State var \(flag)") {
                    passedAsArgument.append("\(name) (\(flag))")
                }
            }
            for label in layoutDependentLabels(in: source) {
                labels += 1
                if !label.isHeldToOneLine { unheld.append("\(name):\(label.line) \(label.text)") }
            }
        }
        h.lint(publishes, "KroutonMainWorkspaceView must publish the window layout with .environment(\\.kroutonLayout, …)")
        h.lint(passedAsArgument.isEmpty, "Views read the window layout from the environment, not through initializers: \(passedAsArgument.joined(separator: ", "))")
        h.lint(labels >= 15, "Expected the layout-dependent labels (found \(labels)); has the scan stopped matching the views?")
        h.lint(unheld.isEmpty, "A label whose text depends on the window layout needs .lineLimit(1) or .fixedSize(), or it can wrap: \(unheld.joined(separator: "; "))")
    }

    struct LayoutLabel {
        let line: Int
        let text: String
        let isHeldToOneLine: Bool
    }

    /// Every `Text(` or `Label(` whose arguments mention a layout flag, or that sits inside an
    /// `if` testing one, with whether its modifier chain holds it to one line.
    static func layoutDependentLabels(in source: String) -> [LayoutLabel] {
        let chars = Array(source.utf16)
        let text = source as NSString
        let flags = layoutFlags.joined(separator: "|")
        var guarded: [Range<Int>] = []
        let ifPattern = try! NSRegularExpression(pattern: #"\bif\s+!?(\#(flags))\b[^{]*\{"#)
        for match in ifPattern.matches(in: source, range: NSRange(location: 0, length: text.length)) {
            let open = match.range.location + match.range.length - 1
            if let close = matching(chars, from: open, open: 123, close: 125) { guarded.append(open..<close) }
        }
        let callPattern = try! NSRegularExpression(pattern: #"(?<![\w.])(Text|Label)\("#)
        var labels: [LayoutLabel] = []
        for match in callPattern.matches(in: source, range: NSRange(location: 0, length: text.length)) {
            let open = match.range.location + match.range.length - 1
            guard let close = matching(chars, from: open, open: 40, close: 41) else { continue }
            let arguments = text.substring(with: NSRange(location: open, length: close - open))
            let inside = guarded.contains { $0.contains(match.range.location) }
            guard inside || layoutFlags.contains(where: arguments.contains) else { continue }
            let after = text.substring(with: NSRange(location: close + 1, length: min(600, text.length - close - 1)))
            let chain = modifierChain(after)
            let line = text.substring(to: match.range.location).components(separatedBy: "\n").count
            let call = text.substring(with: NSRange(location: match.range.location, length: min(60, close + 1 - match.range.location)))
            labels.append(LayoutLabel(line: line, text: call,
                                      isHeldToOneLine: chain.contains(".lineLimit(") || chain.contains(".fixedSize(")))
        }
        return labels
    }

    /// The `.modifier(…)` lines that follow a call, up to the first line that isn't one.
    private static func modifierChain(_ after: String) -> String {
        var chain = ""
        var rest = Substring(after)
        while true {
            let trimmed = rest.drop { $0 == " " || $0 == "\n" }
            guard trimmed.first == "." else { return chain }
            let end = trimmed.firstIndex(of: "\n") ?? trimmed.endIndex
            chain += trimmed[..<end]
            rest = trimmed[end...]
        }
    }

    /// The index of the bracket that closes the one at `from`, skipping string literals.
    private static func matching(_ chars: [UInt16], from: Int, open: UInt16, close: UInt16) -> Int? {
        var depth = 0
        var i = from
        var inString = false
        while i < chars.count {
            let c = chars[i]
            if c == 34 { inString.toggle() }
            else if c == 92, inString { i += 1 }
            else if !inString {
                if c == open { depth += 1 }
                if c == close { depth -= 1; if depth == 0 { return i } }
            }
            i += 1
        }
        return nil
    }
}
