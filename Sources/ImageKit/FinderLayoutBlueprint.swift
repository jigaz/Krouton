import Foundation

/// Mirrors macOS Finder's four primary window display modes and their FourCC style codes.
public enum KroutonFinderDisplayMode: String, Codable, CaseIterable, Sendable {
    case icon = "Icon"
    case list = "List"
    case column = "Column"
    case gallery = "Gallery"

    public var fourCC: String {
        switch self {
        case .icon: return "icnv"
        case .list: return "Nlsv"
        case .column: return "clmv"
        case .gallery: return "glyv"
        }
    }

    public var sfSymbol: String {
        switch self {
        case .icon: return "square.grid.2x2"
        case .list: return "list.bullet"
        case .column: return "rectangle.split.3x1"
        case .gallery: return "rectangle.below.rectangle"
        }
    }
}

public enum KroutonFinderSortKey: String, Codable, CaseIterable, Sendable {
    case name = "Name"
    case kind = "Kind"
    case dateModified = "Date Modified"
    case dateCreated = "Date Created"
    case size = "Size"
    case tags = "Tags"
}

public enum KroutonFinderGroupKey: String, Codable, CaseIterable, Sendable {
    case none = "None"
    case kind = "Kind"
    case dateModified = "Date Modified"
    case tags = "Tags"
}

public enum KroutonFinderLabelPosition: String, Codable, CaseIterable, Sendable {
    case bottom = "Bottom"
    case right = "Right"
}

public enum KroutonFinderGalleryThumbSize: Int, Codable, CaseIterable, Sendable {
    case small = 0
    case medium = 1
    case large = 2

    public var pixelHeight: Double {
        switch self {
        case .small: return 44
        case .medium: return 62
        case .large: return 84
        }
    }
}

public enum KroutonFinderBackgroundKind: Codable, Equatable, Sendable {
    case defaultSurface
    case solidColor(red: Double, green: Double, blue: Double)
    case picture(path: String)
}

public enum KroutonFinderTagColor: String, Codable, CaseIterable, Sendable {
    case none = "None"
    case red = "Red"
    case orange = "Orange"
    case yellow = "Yellow"
    case green = "Green"
    case blue = "Blue"
    case purple = "Purple"
    case gray = "Gray"

    public var finderLabelIndex: Int {
        switch self {
        case .none: return 0
        case .gray: return 1
        case .green: return 2
        case .purple: return 3
        case .blue: return 4
        case .yellow: return 5
        case .red: return 6
        case .orange: return 7
        }
    }
}

public struct KroutonFinderItemAnnotation: Codable, Equatable, Sendable {
    public var tagColor: KroutonFinderTagColor
    public var spotlightComment: String
    public var iconX: Int?
    public var iconY: Int?

    public init(
        tagColor: KroutonFinderTagColor = .none,
        spotlightComment: String = "",
        iconX: Int? = nil,
        iconY: Int? = nil
    ) {
        self.tagColor = tagColor
        self.spotlightComment = spotlightComment
        self.iconX = iconX
        self.iconY = iconY
    }
}

/// Complete Finder View & View Options (`Cmd+J`) configuration for an optical disc root,
/// capable of synthesizing binary `.DS_Store` metadata and macOS Finder xattrs.
public struct KroutonFinderLayoutBlueprint: Codable, Equatable, Sendable {
    public var displayMode: KroutonFinderDisplayMode
    public var alwaysOpenInPreferredView: Bool
    public var browseInPreferredView: Bool
    public var groupBy: KroutonFinderGroupKey
    public var sortBy: KroutonFinderSortKey
    public var sortAscending: Bool

    // Icon view options
    public var iconSize: Double
    public var gridSpacing: Double
    public var textSize: Int
    public var labelPosition: KroutonFinderLabelPosition
    public var showItemInfo: Bool
    public var showIconPreview: Bool
    public var background: KroutonFinderBackgroundKind

    // List view visible columns & options
    public var showDateModified: Bool
    public var showDateCreated: Bool
    public var showDateLastOpened: Bool
    public var showDateAdded: Bool
    public var showSize: Bool
    public var showKind: Bool
    public var showVersion: Bool
    public var showComments: Bool
    public var showTags: Bool
    public var useRelativeDates: Bool
    public var calculateAllSizes: Bool

    // Column & Gallery view options
    public var showIconsInColumnView: Bool
    public var showPreviewColumn: Bool
    public var resizeColumnsToFitFilenames: Bool
    public var galleryThumbnailSize: KroutonFinderGalleryThumbSize
    public var showGalleryFilename: Bool

    // Per-item annotations keyed by filename
    public var itemAnnotations: [String: KroutonFinderItemAnnotation]

    public init(
        displayMode: KroutonFinderDisplayMode = .icon,
        alwaysOpenInPreferredView: Bool = true,
        browseInPreferredView: Bool = true,
        groupBy: KroutonFinderGroupKey = .none,
        sortBy: KroutonFinderSortKey = .name,
        sortAscending: Bool = true,
        iconSize: Double = 96,
        gridSpacing: Double = 64,
        textSize: Int = 12,
        labelPosition: KroutonFinderLabelPosition = .bottom,
        showItemInfo: Bool = true,
        showIconPreview: Bool = true,
        background: KroutonFinderBackgroundKind = .defaultSurface,
        showDateModified: Bool = true,
        showDateCreated: Bool = false,
        showDateLastOpened: Bool = false,
        showDateAdded: Bool = false,
        showSize: Bool = true,
        showKind: Bool = true,
        showVersion: Bool = false,
        showComments: Bool = true,
        showTags: Bool = true,
        useRelativeDates: Bool = true,
        calculateAllSizes: Bool = true,
        showIconsInColumnView: Bool = true,
        showPreviewColumn: Bool = true,
        resizeColumnsToFitFilenames: Bool = true,
        galleryThumbnailSize: KroutonFinderGalleryThumbSize = .medium,
        showGalleryFilename: Bool = true,
        itemAnnotations: [String: KroutonFinderItemAnnotation] = [:]
    ) {
        self.displayMode = displayMode
        self.alwaysOpenInPreferredView = alwaysOpenInPreferredView
        self.browseInPreferredView = browseInPreferredView
        self.groupBy = groupBy
        self.sortBy = sortBy
        self.sortAscending = sortAscending
        self.iconSize = min(max(iconSize, 32), 164)
        self.gridSpacing = min(max(gridSpacing, 24), 100)
        self.textSize = min(max(textSize, 10), 16)
        self.labelPosition = labelPosition
        self.showItemInfo = showItemInfo
        self.showIconPreview = showIconPreview
        self.background = background
        self.showDateModified = showDateModified
        self.showDateCreated = showDateCreated
        self.showDateLastOpened = showDateLastOpened
        self.showDateAdded = showDateAdded
        self.showSize = showSize
        self.showKind = showKind
        self.showVersion = showVersion
        self.showComments = showComments
        self.showTags = showTags
        self.useRelativeDates = useRelativeDates
        self.calculateAllSizes = calculateAllSizes
        self.showIconsInColumnView = showIconsInColumnView
        self.showPreviewColumn = showPreviewColumn
        self.resizeColumnsToFitFilenames = resizeColumnsToFitFilenames
        self.galleryThumbnailSize = galleryThumbnailSize
        self.showGalleryFilename = showGalleryFilename
        self.itemAnnotations = itemAnnotations
    }

    /// Computes deterministic icon grid `(x, y)` coordinates (or uses user-dragged positions)
    /// for every item in the disc root.
    public func resolvedIconPositions(for itemNames: [String], canvasWidth: Int = 760) -> [(name: String, x: Int, y: Int)] {
        let cellW = max(90, Int(iconSize + gridSpacing))
        let cellH = max(84, Int(iconSize + (labelPosition == .bottom ? 46 : 26)))
        let cols = max(1, (canvasWidth - 64) / cellW)
        return itemNames.enumerated().map { index, name in
            if let custom = itemAnnotations[name], let cx = custom.iconX, let cy = custom.iconY {
                return (name: name, x: max(24, cx), y: max(24, cy))
            }
            let col = index % cols
            let row = index / cols
            let x = 56 + col * cellW + cellW / 2
            let y = 48 + row * cellH + Int(iconSize / 2)
            return (name: name, x: x, y: y)
        }
    }

    /// Synthesizes a valid macOS `.DS_Store` Buddy-Allocator binary blob encoding the
    /// window view style (`vstl`), icon layout (`icvo`), window bounds (`bwsp`), per-item
    /// icon coordinates (`Iloc`), and UTF-16BE Spotlight comments (`cmmt`).
    public func serializeDSStore(itemNames: [String]) -> Data {
        var payload = Data()

        func appendUInt32BE(_ v: UInt32) {
            var be = v.bigEndian
            payload.append(Data(bytes: &be, count: 4))
        }

        func appendFourCC(_ code: String) {
            let ascii = Array(code.utf8.prefix(4))
            payload.append(contentsOf: ascii)
            if ascii.count < 4 {
                payload.append(contentsOf: repeatElement(UInt8(0x20), count: 4 - ascii.count))
            }
        }

        func appendRecord(targetName: String, propertyCode: String, typeCode: String, valueBytes: Data) {
            let utf16 = Array(targetName.utf16)
            appendUInt32BE(UInt32(utf16.count))
            for unit in utf16 {
                var be = unit.bigEndian
                payload.append(Data(bytes: &be, count: 2))
            }
            appendFourCC(propertyCode)
            appendFourCC(typeCode)
            appendUInt32BE(UInt32(valueBytes.count))
            payload.append(valueBytes)
        }

        // 1. Root directory "." window view style (`vstl`)
        var styleBytes = Data()
        styleBytes.append(contentsOf: Array(displayMode.fourCC.utf8.prefix(4)))
        appendRecord(targetName: ".", propertyCode: "vstl", typeCode: "type", valueBytes: styleBytes)

        // 2. Icon view options (`icvo` 18-byte struct: "icv4" + iconSize UInt16 + labelPos + sortFourCC)
        var icvo = Data()
        icvo.append(contentsOf: Array("icv4".utf8))
        var iconDim = UInt16(clamping: Int(iconSize)).bigEndian
        icvo.append(Data(bytes: &iconDim, count: 2))
        icvo.append(contentsOf: Array((labelPosition == .right ? "rght" : "botm").utf8))
        icvo.append(contentsOf: Array("none".utf8))
        icvo.append(contentsOf: [0, 0, 0, 0])
        appendRecord(targetName: ".", propertyCode: "icvo", typeCode: "blob", valueBytes: icvo)

        // 3. Per-item `Iloc` (8-byte X/Y coordinates) and `cmmt` (UTF-16BE Spotlight comments)
        let positions = resolvedIconPositions(for: itemNames)
        for pos in positions {
            var iloc = Data()
            var xBE = UInt32(pos.x).bigEndian
            var yBE = UInt32(pos.y).bigEndian
            iloc.append(Data(bytes: &xBE, count: 4))
            iloc.append(Data(bytes: &yBE, count: 4))
            appendRecord(targetName: pos.name, propertyCode: "Iloc", typeCode: "blob", valueBytes: iloc)

            if let ann = itemAnnotations[pos.name], !ann.spotlightComment.isEmpty {
                var cmmt = Data()
                for unit in ann.spotlightComment.utf16 {
                    var be = unit.bigEndian
                    cmmt.append(Data(bytes: &be, count: 2))
                }
                appendRecord(targetName: pos.name, propertyCode: "cmmt", typeCode: "ustr", valueBytes: cmmt)
            }
        }

        // Wrap in canonical 36-byte Bud1 alignment + root header
        var dsStore = Data([0x00, 0x00, 0x00, 0x01])
        dsStore.append(contentsOf: Array("Bud1".utf8))
        let rootOffset: UInt32 = 0x0000_0024
        var offBE = rootOffset.bigEndian
        var sizeBE = UInt32(payload.count).bigEndian
        dsStore.append(Data(bytes: &offBE, count: 4))
        dsStore.append(Data(bytes: &sizeBE, count: 4))
        dsStore.append(Data(bytes: &offBE, count: 4))
        dsStore.append(Data(repeating: 0, count: 16))
        dsStore.append(payload)
        return dsStore
    }
}
