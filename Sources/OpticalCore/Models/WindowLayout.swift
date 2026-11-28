import Foundation

// MARK: - Column Sizes

/// How much room one column of the main window has. A view in a narrow column shows its short
/// labels and leaves out secondary text, so nothing has to wrap.
public enum KroutonColumnSize: String, Sendable, Equatable, CaseIterable {
    case regular
    case narrow
}

/// When a column counts as narrow, with a gap so a label doesn't flicker between its long and
/// short form while a splitter is dragged across the line: a regular column turns narrow below
/// `narrowBelow`, and a narrow one turns regular again above `regularAbove`. The first layout,
/// with nothing to compare to, uses `startsNarrowBelow`.
public struct KroutonColumnBreakpoint: Sendable, Equatable {
    public let narrowBelow: Double
    public let regularAbove: Double
    public let startsNarrowBelow: Double

    public init(narrowBelow: Double, regularAbove: Double, startsNarrowBelow: Double) {
        self.narrowBelow = narrowBelow
        self.regularAbove = regularAbove
        self.startsNarrowBelow = startsNarrowBelow
    }

    /// The size for `width`, given the size the column had before (nil for the first layout).
    public func size(forWidth width: Double, previous: KroutonColumnSize?) -> KroutonColumnSize {
        switch previous {
        case nil: return width < startsNarrowBelow ? .narrow : .regular
        case .regular?: return width < narrowBelow ? .narrow : .regular
        case .narrow?: return width > regularAbove ? .regular : .narrow
        }
    }
}

// MARK: - Window Layout

/// The sizes of the main window's three columns: the format sidebar, the workspace and the
/// destination queue. They resize separately, so each has its own size.
///
/// The breakpoints are the ones the separate flags used before 2026-11-27
/// (`isLeftSidebarUltraSkinny`, `isCenterWorkspaceNarrow`, `isRightQueueCompact`), whose short
/// labels were sized for them. Change one only together with the labels it guards.
public struct KroutonWindowLayout: Sendable, Equatable {
    /// The format sidebar.
    public var sidebar: KroutonColumnSize
    /// The center workspace.
    public var workspace: KroutonColumnSize
    /// The destination queue.
    public var queue: KroutonColumnSize

    public init(sidebar: KroutonColumnSize = .regular, workspace: KroutonColumnSize = .regular,
                queue: KroutonColumnSize = .regular) {
        self.sidebar = sidebar
        self.workspace = workspace
        self.queue = queue
    }

    /// Every column regular.
    public static let regular = KroutonWindowLayout()

    /// Breakpoints for the format sidebar, in points.
    public static let sidebarBreakpoint = KroutonColumnBreakpoint(narrowBelow: 215, regularAbove: 228, startsNarrowBelow: 215)
    /// Breakpoints for the workspace, in points.
    public static let workspaceBreakpoint = KroutonColumnBreakpoint(narrowBelow: 510, regularAbove: 535, startsNarrowBelow: 520)
    /// Breakpoints for the destination queue, in points.
    public static let queueBreakpoint = KroutonColumnBreakpoint(narrowBelow: 355, regularAbove: 368, startsNarrowBelow: 355)

    /// The layout for these column widths. Pass the previous layout to keep the gap between
    /// the breakpoints; nil for the first layout of a window.
    public static func forWidths(sidebar: Double, workspace: Double, queue: Double,
                                 previous: KroutonWindowLayout?) -> KroutonWindowLayout {
        KroutonWindowLayout(
            sidebar: sidebarBreakpoint.size(forWidth: sidebar, previous: previous?.sidebar),
            workspace: workspaceBreakpoint.size(forWidth: workspace, previous: previous?.workspace),
            queue: queueBreakpoint.size(forWidth: queue, previous: previous?.queue))
    }
}
