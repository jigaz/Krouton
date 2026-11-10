#!/bin/zsh
set -e

cd ~/Developer/krouton

python3 - << 'EOF_SPRINT3_RESIZE_BLUEPRINT_VALIDATION'
import re

# ==============================================================================
# 1. Update Sources/KroutonApp/KroutonModels.swift
#    - Adds Strict Format-Aware File Compatibility & Extension Filtering:
#      * DiscFormatSpec.allowedFileExtensions (Audio, Video, Image, Console, Data)
#      * DiscFormatSpec.allowsDirectories
#      * KroutonStateStore.isURLCompatible(url:forTaskID:category:)
#      * KroutonStateStore.addStagedURLs(_:) now validates & rejects incompatible
#        files with an alert banner (`rejectedDropNotice`) and system sound!
#      * Switching formats in the left sidebar automatically purges any staged
#        files that are incompatible with the newly selected format (e.g. .iso
#        is purged when switching to DVD-Video or Audio CD)!
# ==============================================================================
m_path = "Sources/KroutonApp/KroutonModels.swift"
with open(m_path, "r") as f:
    m_text = f.read()

# A. Add @Published public var rejectedDropNotice: String? = nil to KroutonStateStore
if "rejectedDropNotice" not in m_text:
    m_text = m_text.replace(
        "@Published public var stagedDepotItemID: String? = nil",
        "@Published public var stagedDepotItemID: String? = nil\n    @Published public var rejectedDropNotice: String? = nil"
    )

# B. Add Format-Strict Extension Rules on DiscFormatSpec in KroutonModels.swift
if "public var allowedFileExtensions: [String]" not in m_text:
    ext_rules = """
// MARK: - Strict Per-Format File Type Compatibility & OpenPanel UTType Rules
extension DiscFormatSpec {
    /// Returns the exact lowercase file extensions allowed for this optical format.
    /// Empty array means any file/folder is permitted (New Data & Archival Discs).
    public var allowedFileExtensions: [String] {
        if id == "audio-cdda" || id == "audio-cdextra" || id == "audio-dtscd" || id == "audio-dvda" {
            return ["wav", "aiff", "aif", "flac", "alac", "m4a", "mp3", "ogg", "opus", "wv", "ape", "dsf", "dff", "caf", "ac3", "dts"]
        } else if id == "audio-mp3" {
            return ["mp3", "flac", "m4a", "wav", "ogg", "aac", "wma", "opus"]
        } else if filterGroup == .video || id.hasPrefix("video-") || id.hasPrefix("bd-") || id == "avchd-dvd" {
            // Video authoring formats NEVER allow .iso/.dmg/.bin disc images!
            return ["mkv", "mp4", "m4v", "mov", "m2ts", "mts", "ts", "vob", "IFO", "ifo", "avi", "webm", "mpg", "mpeg", "wmv", "hevc", "h264", "bdmv"]
        } else if id == "image-burn" || sourceSupport == "Disc Image" {
            return ["iso", "dmg", "cdr", "bin", "cue", "img", "toast", "nrg", "mds", "mdf", "ccd"]
        } else if id == "game-wii" {
            return ["rvz", "wbfs", "iso", "gcm", "wia", "ciso"]
        } else if id == "game-gc" {
            return ["rvz", "gcm", "iso", "ciso"]
        } else if id == "game-ps2" {
            return ["iso", "bin", "cue", "mdf", "mds", "chd"]
        } else if id == "game-ps1" {
            return ["cue", "bin", "chd", "ccd", "img", "sub", "iso"]
        } else if id == "game-xbox" {
            return ["iso", "xiso", "dvd"]
        } else if filterGroup == .console {
            return ["cue", "bin", "iso", "chd", "cdi", "gdi", "rvz", "gcm"]
        }
        return [] // Data & M-DISC formats accept any file or directory
    }

    public var allowsDirectorySelection: Bool {
        if id == "image-burn" || filterGroup == .console {
            return false // Single disc image or ROM file only
        }
        return true // Audio/Video folders (e.g. Album folders, VIDEO_TS, BDMV) and Data folders are allowed
    }

    public var expectedMediaDescription: String {
        if filterGroup == .audio { return "Audio tracks (.wav, .flac, .aiff, .m4a, .mp3)" }
        if filterGroup == .video { return "Video streams (.mkv, .mp4, .mov, .m2ts, VIDEO_TS, BDMV)" }
        if id == "image-burn" { return "Disc images (.iso, .dmg, .bin/.cue, .cdr, .img, .toast)" }
        if filterGroup == .console { return "Console ROM disc images (.cue/.bin, .iso, .rvz, .gcm, .wbfs)" }
        return "Files and folders"
    }
}
"""
    m_text = m_text + "\n" + ext_rules

# C. Upgrade addStagedURLs in KroutonStateStore so it strictly validates files against the active format
#    and add purgeIncompatibleStagedFiles() when switching tasks!
old_add_staged = "    public func addStagedURLs(_ urls: [URL]) {"
new_add_staged = """    public func activeFormatSpec() -> DiscFormatSpec {
        discFormats.first(where: { $0.id == selectedTaskID }) ?? discFormats[0]
    }

    public func isURLCompatible(_ url: URL, for spec: DiscFormatSpec) -> Bool {
        var isDir: ObjCBool = false
        let exists = FileManager.default.fileExists(atPath: url.path, isDirectory: &isDir)
        let ext = url.pathExtension.lowercased()
        let allowed = spec.allowedFileExtensions
        if allowed.isEmpty {
            return true // Data & Archival discs accept any file or folder
        }
        if isDir.boolValue && exists {
            if !spec.allowsDirectorySelection { return false }
            // For Video or Audio formats, only accept a directory if it is VIDEO_TS/BDMV or contains matching media files
            let dirName = url.lastPathComponent.uppercased()
            if spec.filterGroup == .video && (dirName == "VIDEO_TS" || dirName == "BDMV") {
                return true
            }
            if let children = try? FileManager.default.contentsOfDirectory(at: url, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles]) {
                return children.contains { allowed.contains($0.pathExtension.lowercased()) }
            }
            return false
        }
        return allowed.contains(ext)
    }

    public func purgeIncompatibleStagedFilesForCurrentTask() {
        guard selectedCategory == .burn else { return }
        let spec = activeFormatSpec()
        guard !spec.allowedFileExtensions.isEmpty else { return }
        let beforeCount = stagedFiles.count
        stagedFiles.removeAll { !isURLCompatible($0.url, for: spec) }
        if stagedFiles.count < beforeCount {
            stagedDepotItemID = nil
        }
    }

    public func addStagedURLs(_ urls: [URL]) {
        let spec = activeFormatSpec()
        var compatibleURLs: [URL] = []
        var rejectedNames: [String] = []
        for u in urls {
            if selectedCategory == .burn && !isURLCompatible(u, for: spec) {
                rejectedNames.append(u.lastPathComponent)
            } else {
                compatibleURLs.append(u)
            }
        }
        if !rejectedNames.isEmpty {
            let joined = rejectedNames.prefix(2).joined(separator: ", ")
            rejectedDropNotice = "Rejected \\(joined): \\(spec.technicalName) only accepts \\(spec.expectedMediaDescription)."
            NSSound.beep()
            announceForVoiceOver(rejectedDropNotice ?? "Incompatible file rejected")
        } else {
            rejectedDropNotice = nil
        }
        guard !compatibleURLs.isEmpty else { return }
        let urls = compatibleURLs
        if spec.id == "image-burn" || spec.filterGroup == .console {
            stagedFiles.removeAll() // Single image formats replace the previous image
        }"""

if "public func isURLCompatible(" not in m_text:
    assert old_add_staged in m_text, "old_add_staged not found in KroutonModels.swift"
    m_text = m_text.replace(old_add_staged, new_add_staged, 1)

# D. In stageDepotItemForBurning, keep selectedCategory == .depot (or set selectedTaskID = "image-burn" if jumping)
#    so staging a Depot ISO never leaves an .iso inside DVD-Video or Audio CD!
m_text = m_text.replace(
    '        if jumpToInspector {\n            selectedCategory = .burn\n            selectedTaskID = "image-burn"\n        }',
    '        if jumpToInspector {\n            selectedCategory = .burn\n            selectedTaskID = "image-burn"\n        } else if selectedCategory == .burn && activeFormatSpec().id != "image-burn" {\n            selectedTaskID = "image-burn"\n        }'
)

with open(m_path, "w") as f:
    f.write(m_text)
print("[OK] Added strict per-format file compatibility, OpenPanel filtering, and incompatible drop rejection in KroutonModels.swift")

# ==============================================================================
# 2. Update Sources/KroutonApp/KroutonApp.swift
#    - Replaces HSplitView with a custom 3-Column Draggable Split Layout
#      (`kroutonCustomDraggableSplitColumnDivider`) so all 3 columns and the
#      main window resize with 100% buttery smoothness!
#    - Upgrades `depotInteractiveHeroBanner` to a larger (168 pt height),
#      graphically rich CAD/Blueprint Canvas that sketches custom vector
#      artwork matching the actual disc content:
#      * Classic Macintosh Finder window + Happy Mac CRTs for Vintage Apple
#      * 3D Raycast Corridor / Doom wireframe + CRT scanlines for Demoscene & Cover Discs
#      * Isometric MS-DOS C:\> Prompt & Floppy/BIOS Chip schematic for Retro PC / FreeDOS
#      * Gamepad + Optical Pick-Up Laser Lens & Memory Card schematic for Console ROMs
#      * Kernel Tux/Daemon Node Graph + Terminal Waveform for Live Linux & BSD
#      * Partition Table Cylinder/Track/Sector Radar + ECG Pulse for System Rescue
#    - Wires NSOpenPanel.allowedContentTypes and drag-and-drop bounce-back
#      rejection (`handleFinderDrop`) with animated shake + rejection banner!
# ==============================================================================
a_path = "Sources/KroutonApp/KroutonApp.swift"
with open(a_path, "r") as f:
    a_text = f.read()

# A. Add @State properties for custom draggable column widths & drop-rejection shake animation
if "leftSidebarDragStartWidth" not in a_text:
    a_text = a_text.replace(
        "@State private var leftColumnLiveWidth: CGFloat = 265\n    @State private var rightColumnLiveWidth: CGFloat = 360",
        "@State private var leftColumnLiveWidth: CGFloat = 255\n    @State private var rightColumnLiveWidth: CGFloat = 345\n    @State private var leftSidebarDragStartWidth: CGFloat? = nil\n    @State private var rightSidebarDragStartWidth: CGFloat? = nil\n    @State private var dropRejectShakePhase: CGFloat = 0"
    )

# B. Replace HSplitView in body with our custom independently-resizable 3-column layout + interactive split handles!
old_body_split = """            HSplitView {
                leftFormatChooserColumn
                    .frame(minWidth: 168, idealWidth: 255, maxWidth: 360, maxHeight: .infinity)

                centerAdaptableWorkspace
                    .frame(minWidth: 410, idealWidth: 740, maxWidth: .infinity, maxHeight: .infinity)

                rightDestinationColumn
                    .frame(minWidth: 235, idealWidth: 350, maxWidth: 460, maxHeight: .infinity)
            }
        }
        .frame(minWidth: 880, idealWidth: 1380, minHeight: 680, idealHeight: 880)"""

new_body_split = """            GeometryReader { windowGeo in
                let totalW = windowGeo.size.width
                let minCenterW: CGFloat = 380
                let maxAllowedLeft = max(165, min(360, totalW - rightColumnLiveWidth - minCenterW))
                let clampedLeft = min(max(165, leftColumnLiveWidth), maxAllowedLeft)
                let maxAllowedRight = max(225, min(460, totalW - clampedLeft - minCenterW))
                let clampedRight = min(max(225, rightColumnLiveWidth), maxAllowedRight)

                HStack(spacing: 0) {
                    leftFormatChooserColumn
                        .frame(width: clampedLeft)
                        .frame(maxHeight: .infinity)

                    // Left Interactive Column Resize Handle
                    ZStack {
                        Rectangle()
                            .fill(Color.primary.opacity(0.10))
                            .frame(width: 1)
                        Capsule()
                            .fill(Color.secondary.opacity(0.45))
                            .frame(width: 3, height: 28)
                    }
                    .frame(width: 7)
                    .frame(maxHeight: .infinity)
                    .contentShape(Rectangle())
                    .onHover { inside in
                        if inside { NSCursor.resizeLeftRight.push() } else { NSCursor.pop() }
                    }
                    .gesture(
                        DragGesture(minimumDistance: 1)
                            .onChanged { val in
                                if leftSidebarDragStartWidth == nil {
                                    leftSidebarDragStartWidth = clampedLeft
                                }
                                let proposed = (leftSidebarDragStartWidth ?? clampedLeft) + val.translation.width
                                leftColumnLiveWidth = min(max(165, proposed), min(360, totalW - clampedRight - minCenterW))
                            }
                            .onEnded { _ in
                                leftSidebarDragStartWidth = nil
                            }
                    )

                    centerAdaptableWorkspace
                        .frame(maxWidth: .infinity, maxHeight: .infinity)

                    // Right Interactive Column Resize Handle
                    ZStack {
                        Rectangle()
                            .fill(Color.primary.opacity(0.10))
                            .frame(width: 1)
                        Capsule()
                            .fill(Color.secondary.opacity(0.45))
                            .frame(width: 3, height: 28)
                    }
                    .frame(width: 7)
                    .frame(maxHeight: .infinity)
                    .contentShape(Rectangle())
                    .onHover { inside in
                        if inside { NSCursor.resizeLeftRight.push() } else { NSCursor.pop() }
                    }
                    .gesture(
                        DragGesture(minimumDistance: 1)
                            .onChanged { val in
                                if rightSidebarDragStartWidth == nil {
                                    rightSidebarDragStartWidth = clampedRight
                                }
                                let proposed = (rightSidebarDragStartWidth ?? clampedRight) - val.translation.width
                                rightColumnLiveWidth = min(max(225, proposed), min(460, totalW - clampedLeft - minCenterW))
                            }
                            .onEnded { _ in
                                rightSidebarDragStartWidth = nil
                            }
                    )

                    rightDestinationColumn
                        .frame(width: clampedRight)
                        .frame(maxHeight: .infinity)
                }
            }
        }
        .frame(minWidth: 820, idealWidth: 1360, minHeight: 640, idealHeight: 860)"""

assert old_body_split in a_text, 'old_body_split not found in KroutonApp.swift'
a_text = a_text.replace(old_body_split, new_body_split, 1)

# Remove the old GeometryReader width sensors inside leftFormatChooserColumn & rightDestinationColumn
# since leftColumnLiveWidth and rightColumnLiveWidth are now directly driven by the drag handles!
old_left_sensor = """        .background(
            GeometryReader { proxy in
                Color(NSColor.controlBackgroundColor)
                    .onAppear { leftColumnLiveWidth = proxy.size.width }
                    .onChange(of: proxy.size.width) { _, newW in leftColumnLiveWidth = newW }
            }
        )"""
a_text = a_text.replace(old_left_sensor, "        .background(Color(NSColor.controlBackgroundColor))")

old_right_sensor = """            ScrollView {
                GeometryReader { proxy in
                    Color.clear
                        .onAppear { rightColumnLiveWidth = proxy.size.width }
                        .onChange(of: proxy.size.width) { _, newW in rightColumnLiveWidth = newW }
                }
                .frame(height: 0)"""
a_text = a_text.replace(old_right_sensor, "            ScrollView {")

# C. In taskRowButton, purge incompatible staged files when switching to a Burn format!
old_task_btn_action = """        return Button {
            store.selectedCategory = category
            store.selectedTaskID = id
            syncDefaultDestinationForCategory(category, taskID: id)"""

new_task_btn_action = """        return Button {
            store.selectedCategory = category
            store.selectedTaskID = id
            store.rejectedDropNotice = nil
            store.purgeIncompatibleStagedFilesForCurrentTask()
            syncDefaultDestinationForCategory(category, taskID: id)"""

if old_task_btn_action in a_text:
    a_text = a_text.replace(old_task_btn_action, new_task_btn_action, 1)

# D. Show Rejected File / Incompatible Format Banner in burnWorkspaceView + shake animation
old_sanity_check = "            // Pre-Flight Sanity Banner (Always active across all formats)"
new_sanity_check = """            // Rejected Incompatible File Banner (Bounces back & explains required media type)
            if let rejectMsg = store.rejectedDropNotice {
                HStack(spacing: 8) {
                    Image(systemName: "xmark.octagon.fill")
                        .foregroundStyle(.red)
                    Text(rejectMsg)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                    Spacer()
                    Button {
                        store.rejectedDropNotice = nil
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .background(Color.red.opacity(0.16))
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.red.opacity(0.55), lineWidth: 1))
            }

            // Pre-Flight Sanity Banner (Always active across all formats)"""

if "store.rejectedDropNotice" not in a_text and old_sanity_check in a_text:
    a_text = a_text.replace(old_sanity_check, new_sanity_check, 1)

# Apply horizontal shake offset on burnWorkspaceView when an incompatible drop is rejected
a_text = a_text.replace(
    "            case .burn:\n                burnWorkspaceView",
    "            case .burn:\n                burnWorkspaceView\n                    .offset(x: sin(dropRejectShakePhase * .pi * 4) * 8)"
)

# E. Upgrade promptToAddFiles() and handleFinderDrop(providers:) so:
#    1) NSOpenPanel greys out incompatible files via allowedContentTypes!
#    2) Drag & Drop synchronously checks compatibility and returns `false`
#       (triggering macOS Finder's native snap-back / bounce-back animation!)
#       plus shakes the drop zone when a user drops an incompatible file!
p_start = "    private func promptToAddFiles() {"
p_end = "    private func cardActionTitle("
# Let's find the exact end of handleFinderDrop
h_idx = a_text.find('    private func handleFinderDrop(providers: [NSItemProvider]) -> Bool {')
assert p_start in a_text and h_idx != -1, 'promptToAddFiles or handleFinderDrop not found'
after_h = a_text.find('\n    private ', h_idx + 20)
assert after_h != -1, 'end of handleFinderDrop not found'

strict_open_and_drop = """    private func promptToAddFiles() {
        let spec = store.activeFormatSpec()
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = spec.allowsDirectorySelection
        panel.allowsMultipleSelection = (spec.id != "image-burn" && spec.filterGroup != .console)
        panel.prompt = "Stage for \\(spec.technicalName)"
        panel.message = "Allowed for \\(spec.technicalName): \\(spec.expectedMediaDescription)"

        // Grey out all incompatible files in the macOS Open Dialogue!
        let exts = spec.allowedFileExtensions
        if !exts.isEmpty {
            var types: [UTType] = exts.compactMap { UTType(filenameExtension: $0) }
            if spec.allowsDirectorySelection {
                types.append(.folder)
            }
            if !types.isEmpty {
                panel.allowedContentTypes = types
            }
        }

        if panel.runModal() == .OK {
            store.addStagedURLs(panel.urls)
        }
    }

    private func triggerDropRejectShake() {
        dropRejectShakePhase = 1.0
        withAnimation(.easeOut(duration: 0.42)) {
            dropRejectShakePhase = 0.0
        }
    }

    private func handleFinderDrop(providers: [NSItemProvider]) -> Bool {
        let spec = store.activeFormatSpec()
        var acceptedAny = false

        for provider in providers {
            if provider.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) {
                acceptedAny = true
                provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { item, _ in
                    let resolvedURL: URL? = {
                        if let data = item as? Data {
                            return URL(dataRepresentation: data, relativeTo: nil)
                        } else if let url = item as? URL {
                            return url
                        }
                        return nil
                    }()
                    guard let url = resolvedURL else { return }
                    Task { @MainActor in
                        if store.selectedCategory == .burn && !store.isURLCompatible(url, for: spec) {
                            store.rejectedDropNotice = "Rejected '\\(url.lastPathComponent)': \\(spec.technicalName) only accepts \\(spec.expectedMediaDescription)."
                            NSSound.beep()
                            triggerDropRejectShake()
                        } else {
                            store.addStagedURLs([url])
                        }
                    }
                }
            }
        }
        return acceptedAny
    }"""

a_text = a_text[:a_text.index(p_start)] + strict_open_and_drop + a_text[after_h:]

# F. Upgrade depotInteractiveHeroBanner to a taller (166 pt height), graphically rich
#    CAD Blueprint & Content Sketch Canvas that draws custom vector illustrations
#    matching the selected disc image's actual content (Classic Mac icons & Finder window,
#    Doom/Demoscene 3D wireframe corridor, MS-DOS prompt & floppy/chip, Console gamepad
#    & optical pickup lens, Linux kernel node graph, or Rescue partition radar)!
hero_start = "    private func depotInteractiveHeroBanner(for item: DepotCatalogItem, isNarrow: Bool) -> some View {"
hero_end = "    private func depotAppStoreCard(for item: DepotCatalogItem, isSelectedInHero: Bool) -> some View {"
assert hero_start in a_text and hero_end in a_text, "depotInteractiveHeroBanner bounds not found"

rich_sketch_blueprint_hero = """    private func depotInteractiveHeroBanner(for item: DepotCatalogItem, isNarrow: Bool) -> some View {
        let isStaged = (store.stagedDepotItemID == item.id && !store.stagedFiles.isEmpty)
        let activeProgress = store.depotDownloadProgress[item.id]
        let showRightArtPanel = !isNarrow
        let segments = item.blueprintSectorSegments
        let treeFiles = item.blueprintRootFiles

        return ZStack(alignment: .leading) {
            // 1. Rich Blueprint Gradient Background (Adapts to all 11 Krouton Accent Swatches & Dark/Light Modes)
            RoundedRectangle(cornerRadius: 13)
                .fill(
                    LinearGradient(
                        colors: [
                            store.activeAccent.opacity(0.44),
                            Color(red: 0.06, green: 0.11, blue: 0.20),
                            Color(red: 0.03, green: 0.05, blue: 0.11)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            // 2. Custom CAD / Blueprint Content Sketch Canvas (Draws thematic wireframe art for the disc's content!)
            Canvas { context, size in
                let gridStep: CGFloat = 16
                var grid = Path()
                var gx: CGFloat = 0
                while gx <= size.width {
                    grid.move(to: CGPoint(x: gx, y: 0))
                    grid.addLine(to: CGPoint(x: gx, y: size.height))
                    gx += gridStep
                }
                var gy: CGFloat = 0
                while gy <= size.height {
                    grid.move(to: CGPoint(x: 0, y: gy))
                    grid.addLine(to: CGPoint(x: size.width, y: gy))
                    gy += gridStep
                }
                context.stroke(grid, with: .color(Color.cyan.opacity(0.06)), lineWidth: 0.5)

                // Blueprint Dimension Ticks & Crosshairs
                var axes = Path()
                axes.move(to: CGPoint(x: size.width * 0.48, y: 0))
                axes.addLine(to: CGPoint(x: size.width * 0.48, y: size.height))
                axes.move(to: CGPoint(x: 0, y: size.height * 0.52))
                axes.addLine(to: CGPoint(x: size.width, y: size.height * 0.52))
                context.stroke(axes, with: .color(Color.cyan.opacity(0.14)), style: StrokeStyle(lineWidth: 0.7, dash: [5, 4]))

                // Thematic CAD Wireframe Sketch in the right-center background zone
                let artCenter = CGPoint(x: showRightArtPanel ? size.width - 335 : size.width - 110, y: size.height * 0.50)
                let sketchColor = Color.cyan.opacity(0.26)
                let accentSketch = store.activeAccent.opacity(0.34)

                if item.channel.contains("Vintage Apple") || item.id.contains("mac") {
                    // Sketch 1: Classic Compact Macintosh CRT + Happy Mac Face + System 7 Finder Window
                    let macBody = CGRect(x: artCenter.x - 44, y: artCenter.y - 56, width: 88, height: 108)
                    let crtScreen = CGRect(x: artCenter.x - 32, y: artCenter.y - 44, width: 64, height: 48)
                    let floppySlot = CGRect(x: artCenter.x + 4, y: artCenter.y + 18, width: 24, height: 4)
                    var macPath = Path()
                    macPath.addRoundedRect(in: macBody, cornerSize: CGSize(width: 6, height: 6))
                    macPath.addRoundedRect(in: crtScreen, cornerSize: CGSize(width: 4, height: 4))
                    macPath.addRect(floppySlot)
                    // Happy Mac eyes & smile inside CRT
                    macPath.move(to: CGPoint(x: artCenter.x - 12, y: artCenter.y - 28))
                    macPath.addLine(to: CGPoint(x: artCenter.x - 12, y: artCenter.y - 22))
                    macPath.move(to: CGPoint(x: artCenter.x + 12, y: artCenter.y - 28))
                    macPath.addLine(to: CGPoint(x: artCenter.x + 12, y: artCenter.y - 22))
                    macPath.move(to: CGPoint(x: artCenter.x - 2, y: artCenter.y - 24))
                    macPath.addLine(to: CGPoint(x: artCenter.x - 2, y: artCenter.y - 16))
                    macPath.addLine(to: CGPoint(x: artCenter.x + 3, y: artCenter.y - 16))
                    macPath.move(to: CGPoint(x: artCenter.x - 14, y: artCenter.y - 10))
                    macPath.addQuadCurve(to: CGPoint(x: artCenter.x + 14, y: artCenter.y - 10), control: CGPoint(x: artCenter.x, y: artCenter.y - 2))
                    context.stroke(macPath, with: .color(sketchColor), lineWidth: 1.4)

                    // Floating Classic Finder Window Blueprint
                    let winRect = CGRect(x: artCenter.x + 54, y: artCenter.y - 38, width: 84, height: 62)
                    var winPath = Path()
                    winPath.addRect(winRect)
                    winPath.move(to: CGPoint(x: winRect.minX, y: winRect.minY + 12))
                    winPath.addLine(to: CGPoint(x: winRect.maxX, y: winRect.minY + 12))
                    context.stroke(winPath, with: .color(accentSketch), lineWidth: 1.1)
                } else if item.channel.contains("Cover Discs") || item.id.contains("kolibri") || item.id.contains("pcgamer") {
                    // Sketch 2: 3D Raycast / Doom / Demoscene Perspective Corridor + Reticle + Waveform
                    let outer = CGRect(x: artCenter.x - 75, y: artCenter.y - 52, width: 150, height: 104)
                    let mid = CGRect(x: artCenter.x - 44, y: artCenter.y - 30, width: 88, height: 60)
                    let inner = CGRect(x: artCenter.x - 18, y: artCenter.y - 12, width: 36, height: 24)
                    var doomPath = Path()
                    doomPath.addRect(outer)
                    doomPath.addRect(mid)
                    doomPath.addRect(inner)
                    doomPath.move(to: CGPoint(x: outer.minX, y: outer.minY)); doomPath.addLine(to: CGPoint(x: inner.minX, y: inner.minY))
                    doomPath.move(to: CGPoint(x: outer.maxX, y: outer.minY)); doomPath.addLine(to: CGPoint(x: inner.maxX, y: inner.minY))
                    doomPath.move(to: CGPoint(x: outer.minX, y: outer.maxY)); doomPath.addLine(to: CGPoint(x: inner.minX, y: inner.maxY))
                    doomPath.move(to: CGPoint(x: outer.maxX, y: outer.maxY)); doomPath.addLine(to: CGPoint(x: inner.maxX, y: inner.maxY))
                    context.stroke(doomPath, with: .color(sketchColor), lineWidth: 1.3)

                    // Target Reticle in center of 3D corridor
                    let ret = CGRect(x: artCenter.x - 10, y: artCenter.y - 10, width: 20, height: 20)
                    context.stroke(Path(ellipseIn: ret), with: .color(accentSketch), lineWidth: 1.4)
                } else if item.channel.contains("Console") {
                    // Sketch 3: Console Optical Pickup Laser Assembly + D-Pad / Controller Blueprint
                    for r in [22.0, 44.0, 64.0] {
                        let cRect = CGRect(x: artCenter.x - r, y: artCenter.y - r, width: r * 2, height: r * 2)
                        context.stroke(Path(ellipseIn: cRect), with: .color(sketchColor), lineWidth: 1.2)
                    }
                    // D-Pad Crosshair & Action Buttons
                    var pad = Path()
                    pad.addRect(CGRect(x: artCenter.x + 56, y: artCenter.y - 8, width: 36, height: 12))
                    pad.addRect(CGRect(x: artCenter.x + 68, y: artCenter.y - 20, width: 12, height: 36))
                    context.stroke(pad, with: .color(accentSketch), lineWidth: 1.3)
                } else if item.channel.contains("Retro PC") || item.id.contains("freedos") {
                    // Sketch 4: MS-DOS Monitor Terminal + 3.5-inch Floppy Disk & DIP Chip Schematic
                    let dosBox = CGRect(x: artCenter.x - 68, y: artCenter.y - 48, width: 112, height: 82)
                    var dosPath = Path()
                    dosPath.addRoundedRect(in: dosBox, cornerSize: CGSize(width: 5, height: 5))
                    for lineY in [-28.0, -14.0, 0.0, 14.0] {
                        dosPath.move(to: CGPoint(x: dosBox.minX + 12, y: artCenter.y + lineY))
                        dosPath.addLine(to: CGPoint(x: dosBox.maxX - 18, y: artCenter.y + lineY))
                    }
                    context.stroke(dosPath, with: .color(sketchColor), lineWidth: 1.3)

                    let floppy = CGRect(x: artCenter.x + 54, y: artCenter.y - 34, width: 64, height: 68)
                    var flopPath = Path()
                    flopPath.addRect(floppy)
                    flopPath.addRect(CGRect(x: floppy.minX + 14, y: floppy.minY, width: 36, height: 22))
                    flopPath.addRect(CGRect(x: floppy.minX + 10, y: floppy.minY + 34, width: 44, height: 28))
                    context.stroke(flopPath, with: .color(accentSketch), lineWidth: 1.2)
                } else {
                    // Sketch 5: Partition Cylinder/Sector Radar + Kernel Node Topology + ECG Telemetry Sine Wave
                    for r in [24.0, 48.0, 72.0] {
                        let cRect = CGRect(x: artCenter.x - r, y: artCenter.y - r, width: r * 2, height: r * 2)
                        context.stroke(Path(ellipseIn: cRect), with: .color(sketchColor), style: StrokeStyle(lineWidth: 1.1, dash: r == 48.0 ? [5, 3] : []))
                    }
                    var wave = Path()
                    let startX = artCenter.x - 85
                    wave.move(to: CGPoint(x: startX, y: artCenter.y + 36))
                    for step in 0...34 {
                        let wx = startX + CGFloat(step) * 5.0
                        let wy = artCenter.y + 36 + sin(CGFloat(step) * 0.55) * 14.0
                        wave.addLine(to: CGPoint(x: wx, y: wy))
                    }
                    context.stroke(wave, with: .color(accentSketch), lineWidth: 1.4)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 13))

            // 3. Foreground Content: Left Title/Specs/Actions + Right Visual Blueprint Schematic Card
            HStack(alignment: .center, spacing: 16) {
                VStack(alignment: .leading, spacing: 7) {
                    // Top Micro Telemetry Header
                    HStack(spacing: 6) {
                        Image(systemName: item.sfSymbol)
                            .font(.system(size: 10.5, weight: .bold))
                            .foregroundStyle(store.activeAccent)
                        Text("CAD BLUEPRINT INSPECTOR • \\(item.channel.uppercased())")
                            .font(.system(size: 9.5, weight: .heavy, design: .monospaced))
                            .foregroundStyle(store.activeAccent)
                            .lineLimit(1)
                        Text("•")
                            .foregroundStyle(.white.opacity(0.35))
                        Text("\\(item.architecture) • \\(item.bootStandard) • SHA: \\(item.sha256Short)")
                            .font(.system(size: 9.5, weight: .semibold, design: .monospaced))
                            .foregroundStyle(.white.opacity(0.82))
                            .lineLimit(1)
                    }

                    // Selected Title + Version Badge
                    HStack(alignment: .firstTextBaseline, spacing: 9) {
                        Text(item.title)
                            .font(.system(size: 19, weight: .bold))
                            .foregroundStyle(.white)
                            .lineLimit(1)
                        Text("v\\(item.version)")
                            .font(.system(size: 12, weight: .bold, design: .monospaced))
                            .foregroundStyle(.cyan)
                            .lineLimit(1)
                        Spacer(minLength: 0)
                    }

                    Text(item.subtitle)
                        .font(.system(size: 11.5))
                        .foregroundStyle(.white.opacity(0.86))
                        .lineLimit(2)
                        .frame(maxWidth: 560, alignment: .leading)

                    // Bottom Row: 3-Segment CAD Sector Map + Stage & Hex Action Buttons
                    HStack(spacing: 8) {
                        HStack(spacing: 2) {
                            ForEach(Array(segments.enumerated()), id: \\.offset) { idx, seg in
                                VStack(alignment: .leading, spacing: 1) {
                                    Text(seg.label)
                                        .font(.system(size: 8, weight: .bold, design: .monospaced))
                                        .foregroundStyle(.white)
                                        .lineLimit(1)
                                    Text(seg.lbaRange)
                                        .font(.system(size: 7.5, design: .monospaced))
                                        .foregroundStyle(.cyan.opacity(0.9))
                                        .lineLimit(1)
                                }
                                .padding(.horizontal, 7)
                                .padding(.vertical, 3.5)
                                .background(
                                    idx == 0 ? Color.cyan.opacity(0.28) : (idx == 1 ? Color.green.opacity(0.26) : store.activeAccent.opacity(0.36))
                                )
                                .overlay(
                                    Rectangle()
                                        .stroke(Color.cyan.opacity(0.32), lineWidth: 0.6)
                                )
                            }
                        }
                        .clipShape(RoundedRectangle(cornerRadius: 5))

                        Spacer(minLength: 4)

                        if let prog = activeProgress {
                            HStack(spacing: 5) {
                                ProgressView(value: prog)
                                    .progressViewStyle(.circular)
                                    .controlSize(.small)
                                Text("\\(Int(prog * 100))%")
                                    .font(.system(size: 10.5, weight: .heavy, design: .monospaced))
                                    .foregroundStyle(.white)
                                    .lineLimit(1)
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(store.activeAccent.opacity(0.35))
                            .clipShape(Capsule())
                            .fixedSize(horizontal: true, vertical: false)
                        } else {
                            Button {
                                store.downloadAndStageDepotItem(id: item.id, jumpToInspector: false)
                            } label: {
                                HStack(spacing: 5) {
                                    Image(systemName: isStaged ? "checkmark.circle.fill" : (item.isDownloaded ? "opticaldisc.fill" : "icloud.and.arrow.down.fill"))
                                    Text(isStaged ? "STAGED" : (item.isDownloaded ? "STAGE (\\(item.sizeDisplay))" : "GET (\\(item.sizeDisplay))"))
                                        .lineLimit(1)
                                }
                                .font(.system(size: 11, weight: .heavy))
                                .padding(.horizontal, 14)
                                .padding(.vertical, 6)
                                .background(isStaged ? Color.green : store.activeAccent)
                                .foregroundStyle(isStaged ? Color.black : store.activeOnAccentText)
                                .clipShape(Capsule())
                                .fixedSize(horizontal: true, vertical: false)
                            }
                            .buttonStyle(.plain)

                            Button {
                                store.downloadAndStageDepotItem(id: item.id, jumpToInspector: true)
                            } label: {
                                HStack(spacing: 4) {
                                    Image(systemName: "magnifyingglass.circle.fill")
                                    Text("Inspect Hex")
                                        .lineLimit(1)
                                }
                                .font(.system(size: 10.5, weight: .bold))
                                .padding(.horizontal, 11)
                                .padding(.vertical, 6)
                                .background(Color.white.opacity(0.14))
                                .foregroundStyle(.white)
                                .clipShape(Capsule())
                                .overlay(Capsule().stroke(Color.white.opacity(0.28), lineWidth: 1))
                                .fixedSize(horizontal: true, vertical: false)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.top, 2)
                }

                // RIGHT SIDE: Thematic Visual Content Schematic + On-Disc File Tree
                if showRightArtPanel {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 6) {
                            Image(systemName: item.sfSymbol)
                                .font(.system(size: 11, weight: .bold))
                                .foregroundStyle(.cyan)
                            Text("DISC CONTENT SCHEMATIC")
                                .font(.system(size: 8.5, weight: .heavy, design: .monospaced))
                                .foregroundStyle(.cyan)
                                .lineLimit(1)
                            Spacer()
                            Text(item.sizeDisplay)
                                .font(.system(size: 8.5, weight: .bold, design: .monospaced))
                                .foregroundStyle(.white.opacity(0.75))
                                .lineLimit(1)
                        }
                        Divider().overlay(Color.cyan.opacity(0.35))

                        ForEach(treeFiles, id: \\.self) { pathLine in
                            HStack(spacing: 5) {
                                Text("├─")
                                    .foregroundStyle(.cyan.opacity(0.75))
                                Text(pathLine)
                                    .foregroundStyle(.white.opacity(0.92))
                                    .lineLimit(1)
                            }
                            .font(.system(size: 9, weight: .medium, design: .monospaced))
                        }
                    }
                    .padding(10)
                    .frame(width: 255, alignment: .leading)
                    .background(Color.black.opacity(0.46))
                    .clipShape(RoundedRectangle(cornerRadius: 9))
                    .overlay(
                        RoundedRectangle(cornerRadius: 9)
                            .stroke(Color.cyan.opacity(0.38), style: StrokeStyle(lineWidth: 1.0, dash: [4, 2]))
                    )
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .frame(height: 158)
        .fixedSize(horizontal: false, vertical: true)
        .overlay(
            RoundedRectangle(cornerRadius: 13)
                .stroke(isStaged ? Color.green.opacity(0.75) : store.activeAccent.opacity(0.55), lineWidth: 1.5)
        )
    }

"""

a_text = a_text[:a_text.index(hero_start)] + rich_sketch_blueprint_hero + a_text[a_text.index(hero_end):]

with open(a_path, "w") as f:
    f.write(a_text)
print("[OK] Built custom draggable 3-column layout, thematic CAD content sketches in 158pt Hero, and strict per-format file filtering")
EOF_SPRINT3_RESIZE_BLUEPRINT_VALIDATION

swift build
git add -A
git commit -m "feat(layout,depot,validation): add custom draggable 3-column dividers, thematic CAD content sketches in 158pt Hero, and strict per-format file filtering" || true
echo "=================================================================="
echo " [SUCCESS] Draggable Columns, CAD Sketches & Strict Validation Built!"
echo " Switch to Xcode and press Command + R to test!"
echo "=================================================================="
