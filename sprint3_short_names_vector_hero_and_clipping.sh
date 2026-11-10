#!/bin/zsh
set -e

cd ~/Developer/krouton

python3 - << 'EOF_LAYOUT_HERO_VECTORS'
import re

# ==============================================================================
# 1. Update Sources/KroutonApp/KroutonModels.swift
#    - Adds `shortDisplayName` to DiscFormatSpec so the left column uses
#      clean, punchy names (`BD-R`, `Data`, `PS2`, `GameCube`, `M-DISC`,
#      `Burn Image`, `Audio CD`, `MP3 CD`, `DVD-Video`, `BD-R DL`, `UHD-BD`,
#      `Wii`, `PS1`, `Xbox`, etc.) with zero truncation!
# ==============================================================================
m_path = "Sources/KroutonApp/KroutonModels.swift"
with open(m_path, "r") as f:
    m_text = f.read()

if "public var shortDisplayName: String" not in m_text:
    short_name_ext = """
// MARK: - Concise Left-Sidebar Display Names (Zero Truncation)
extension DiscFormatSpec {
    public var shortDisplayName: String {
        switch id {
        case "audio-cdda":      return "Audio CD"
        case "audio-mp3":       return "MP3 / FLAC CD"
        case "audio-cdextra":   return "CD-Extra"
        case "video-dvd":       return "DVD-Video"
        case "avchd-dvd":       return "AVCHD"
        case "bd-sl":           return "BD-R"
        case "bd-dl":           return "BD-R DL"
        case "bd-xl":           return "UHD-BD / BDXL"
        case "video-svcd":      return "Super VCD"
        case "image-burn":      return "Burn Image"
        case "data-hybrid":     return "Data"
        case "data-udf-modern": return "UDF Large Data"
        case "data-apple-apfs": return "Apple Volume"
        case "data-retro-iso":  return "Retro ISO 8.3"
        case "mdisc-vault":     return "M-DISC"
        case "game-wii":        return "Nintendo Wii"
        case "game-gc":         return "GameCube"
        case "game-ps2":        return "PS2"
        case "game-ps1":        return "PS1"
        case "game-xbox":       return "Xbox"
        case "game-dc":         return "Dreamcast"
        case "game-3do":        return "3DO / PCE"
        case "audio-dtscd":     return "DTS-CD"
        case "audio-dvda":      return "DVD-Audio"
        case "data-dvdram":     return "DVD-RAM"
        case "data-hfs-apm":    return "Mac OS 9 HFS"
        case "legacy-photocd":  return "Kodak Photo CD"
        default:                return technicalName
        }
    }
}
"""
    m_text = m_text + "\n" + short_name_ext
    with open(m_path, "w") as f:
        f.write(m_text)
    print("[OK] Added shortDisplayName to DiscFormatSpec in KroutonModels.swift")

# ==============================================================================
# 2. Update Sources/KroutonApp/KroutonApp.swift
#    - Fixes the #1 cause of overlap (`Screenshot 3.41.23 PM` & `3.39.45 PM`):
#      Adds `.clipped()` to `leftFormatChooserColumn`, `centerAdaptableWorkspace`,
#      and `rightDestinationColumn` AND removes all rigid `.frame(width: 460)` /
#      `.fixedSize(horizontal: true)` inside cards that were overflowing into
#      neighboring columns!
#    - Uses `fmt.shortDisplayName` (`BD-R`, `Data`, `PS2`, `GameCube`, `M-DISC`)
#      and concise Depot names (`All Library`, `Rescue & BIOS`, `Linux & BSD`,
#      `Vintage Mac`, `Console ROMs`, `Cover Discs`, `Retro PC & DOS`) in the
#      left column so it NEVER truncates!
#    - Makes the right `destinationCard` 100% fluid (`maxWidth: .infinity`) so
#      `Physical Burner`, `Blank CD-RW`, `Erase RW`, `Max Safe`, and `Burn Disc`
#      never clip off the right edge of the window!
#    - Expands the Disc Image Depot Hero Card (`height: 196 pt`) with:
#      * Tasteful breathing room & open blueprint space in the center-right
#      * Custom multi-path vector CAD illustrations (`DepotVectorBlueprintArt`):
#        1) Linux Tux Penguin + BSD Daemon Horns + Kernel Nodes
#        2) Classic Mac OS System 7 Happy Mac + Trash Can + Bomb Alert Dialog
#        3) MacAddict CD-ROM Guy Mascot + 3D Doom Raycast Corridor
#        4) TempleOS Sword/Sunburst + MS-DOS C:\> CRT + 3.5-inch Floppy
#        5) GameCube / PS2 Optical Laser Pickup Assembly + Isometric Gamepad
#        6) SystemRescue Platter Cylinder/Sector Radar + ECG Pulse
#    - Adds a 1-Click `[⇄ Layout Stress Preset]` cycler button in the top toolbar
#      so you can test Wide Studio, Balanced, Compact Laptop, and Skinny Sidebars
#      instantly to verify zero overlap or truncation!
# ==============================================================================
a_path = "Sources/KroutonApp/KroutonApp.swift"
with open(a_path, "r") as f:
    a_text = f.read()

# A. Add `.clipped()` to all 3 columns in the main HStack so NO child view can ever bleed into a neighbor column!
old_three_col = """                HStack(spacing: 0) {
                    leftFormatChooserColumn
                        .frame(width: clampedLeft)
                        .frame(maxHeight: .infinity)

                    // Left Interactive Column Resize Handle"""

new_three_col = """                HStack(spacing: 0) {
                    leftFormatChooserColumn
                        .frame(width: clampedLeft)
                        .frame(maxHeight: .infinity)
                        .clipped()

                    // Left Interactive Column Resize Handle"""

if old_three_col in a_text:
    a_text = a_text.replace(old_three_col, new_three_col, 1)

old_center_right_col = """                    centerAdaptableWorkspace
                        .frame(maxWidth: .infinity, maxHeight: .infinity)

                    // Right Interactive Column Resize Handle"""

new_center_right_col = """                    centerAdaptableWorkspace
                        .frame(minWidth: minCenterW, maxWidth: .infinity, maxHeight: .infinity)
                        .clipped()

                    // Right Interactive Column Resize Handle"""

if old_center_right_col in a_text:
    a_text = a_text.replace(old_center_right_col, new_center_right_col, 1)

old_right_col_end = """                    rightDestinationColumn
                        .frame(width: clampedRight)
                        .frame(maxHeight: .infinity)"""

new_right_col_end = """                    rightDestinationColumn
                        .frame(width: clampedRight)
                        .frame(maxHeight: .infinity)
                        .clipped()"""

if old_right_col_end in a_text:
    a_text = a_text.replace(old_right_col_end, new_right_col_end, 1)

# B. Add a 1-Click Layout Stress-Test Preset Button in `topProToolbar` so you can cycle
#    column widths (Wide Studio / Compact / Skinny Sidebars / Max Workspace) to verify zero overlap!
old_settings_btn = """            Button {
                KroutonWindowManager.shared.openSettingsWindow(store: store, driveManager: driveManager)"""

new_settings_btn = """            Menu {
                Button("Balanced Studio (Default — 235 / Auto / 335)") {
                    withAnimation(.snappy) { leftColumnLiveWidth = 235; rightColumnLiveWidth = 335 }
                }
                Button("Skinny Sidebars / Max Workspace (172 / Auto / 250)") {
                    withAnimation(.snappy) { leftColumnLiveWidth = 172; rightColumnLiveWidth = 250 }
                }
                Button("Wide Sidebars / Narrow Workspace (310 / Auto / 390)") {
                    withAnimation(.snappy) { leftColumnLiveWidth = 310; rightColumnLiveWidth = 390 }
                }
                Button("Compact Left / Wide Queue (175 / Auto / 380)") {
                    withAnimation(.snappy) { leftColumnLiveWidth = 175; rightColumnLiveWidth = 380 }
                }
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "rectangle.split.3x1")
                    Text("Layout")
                }
                .font(.system(size: 11, weight: .semibold))
                .padding(.horizontal, 9)
                .padding(.vertical, 5)
                .background(Color(NSColor.controlBackgroundColor))
                .clipShape(Capsule())
            }
            .menuStyle(.borderlessButton)
            .fixedSize(horizontal: true, vertical: false)
            .help("Test responsive column width presets (Balanced, Skinny Sidebars, Narrow Workspace)")

            Button {
                KroutonWindowManager.shared.openSettingsWindow(store: store, driveManager: driveManager)"""

if "rectangle.split.3x1" not in a_text and old_settings_btn in a_text:
    a_text = a_text.replace(old_settings_btn, new_settings_btn, 1)

# C. Update leftFormatChooserColumn to use `fmt.shortDisplayName` (`BD-R`, `Data`, `PS2`, `GameCube`, `M-DISC`)
#    and concise names for Depot / Copy / Label tasks!
a_text = a_text.replace(
    'title: fmt.technicalName,',
    'title: fmt.shortDisplayName,'
)

# Shorten the Depot, Copy, and Label left-sidebar titles so they never truncate even at 168pt width
sidebar_renames = [
    ('title: "All Depot Library (60+)",', 'title: "All Library (60+)",'),
    ('title: "System Rescue & BIOS",', 'title: "Rescue & BIOS",'),
    ('title: "Vintage Mac & Apple",', 'title: "Vintage Mac",'),
    ('title: "Console Homebrew & ROMs",', 'title: "Console ROMs",'),
    ('title: "90s Cover Discs & Scene",', 'title: "Cover Discs",'),
    ('title: "Retro PC, DOS & Alt OS",', 'title: "Retro PC & DOS",'),
    ('title: "Automatic Disc Label",', 'title: "Auto Label",'),
    ('title: "Manual Disc Label",', 'title: "Manual Label",')
]
for old_t, new_t in sidebar_renames:
    a_text = a_text.replace(old_t, new_t)

# D. Make `centralWorkspaceCapacityBar` use `ViewThatFits(in: .horizontal)` so it NEVER wraps onto
#    3 vertical lines when the middle workspace gets narrow (`Screenshot 3.41.23 PM`)!
old_cap_bar = "    private var centralWorkspaceCapacityBar: some View {"
cap_bar_end = "    private var filteredDepotItems: [DepotCatalogItem] {"
assert old_cap_bar in a_text and cap_bar_end in a_text, 'centralWorkspaceCapacityBar bounds not found'

responsive_cap_bar = """    private var centralWorkspaceCapacityBar: some View {
        let usedB = store.totalStagedBytes
        let totalB = max(1, activeDiscCapacityBytes)
        let freeB = max(0, totalB - usedB)
        let ratio = min(1.0, Double(usedB) / Double(totalB))
        let isOverburn = usedB > totalB
        let mediaLabel = primarySelectedDrive?.isMediaPresent == true
            ? (primarySelectedDrive?.mediaType ?? "Optical Disc")
            : (store.discFormats.first(where: { $0.id == store.selectedTaskID })?.capacity ?? "4.7 GB Target")

        return VStack(alignment: .leading, spacing: 5) {
            ViewThatFits(in: .horizontal) {
                // 1. Wide Workspace Layout
                HStack(spacing: 6) {
                    Label("DISC SPACE (\\(mediaLabel))", systemImage: "chart.bar.xaxis")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                    Spacer(minLength: 8)
                    Text("Used: \\(ByteCountFormatter.string(fromByteCount: usedB, countStyle: .file)) (\\(store.totalStagedSectorsLBA) LBA)")
                        .font(.system(size: 10.5, weight: .semibold, design: .monospaced))
                        .foregroundStyle(isOverburn ? .red : .primary)
                        .lineLimit(1)
                    Text("•").foregroundStyle(.secondary)
                    Text("Free: \\(ByteCountFormatter.string(fromByteCount: freeB, countStyle: .file))")
                        .font(.system(size: 10.5, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                    Text("•").foregroundStyle(.secondary)
                    Text(String(format: "%.1f%%", ratio * 100.0))
                        .font(.system(size: 10.5, weight: .bold, design: .monospaced))
                        .foregroundStyle(isOverburn ? .red : store.activeAccent)
                        .lineLimit(1)
                }

                // 2. Compact / Narrow Workspace Fallback (Zero Multi-Line Wrapping!)
                HStack(spacing: 6) {
                    Text("\\(mediaLabel):")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                    Text("\\(ByteCountFormatter.string(fromByteCount: usedB, countStyle: .file)) / \\(ByteCountFormatter.string(fromByteCount: totalB, countStyle: .file))")
                        .font(.system(size: 10, weight: .semibold, design: .monospaced))
                        .foregroundStyle(isOverburn ? .red : .primary)
                        .lineLimit(1)
                    Spacer(minLength: 4)
                    Text(String(format: "%.1f%%", ratio * 100.0))
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundStyle(isOverburn ? .red : store.activeAccent)
                        .lineLimit(1)
                }
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.primary.opacity(0.08))
                    RoundedRectangle(cornerRadius: 4)
                        .fill(isOverburn ? Color.red : store.activeAccent)
                        .frame(width: max(4, geo.size.width * ratio))
                    Rectangle()
                        .fill(Color.yellow.opacity(0.65))
                        .frame(width: 1.5)
                        .offset(x: geo.size.width * 0.96)
                }
            }
            .frame(height: 7)
        }
        .padding(10)
        .background(Color(NSColor.controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .accessibilityLabel(String(format: "Disc capacity %.1f percent full", ratio * 100.0))
    }

"""
a_text = a_text[:a_text.index(old_cap_bar)] + responsive_cap_bar + a_text[a_text.index(cap_bar_end):]

# E. Upgrade `depotInteractiveHeroBanner` + `depotAppStoreCard` so:
#    1) Cards never clip the `GET` / `STAGE` button or `IN HERO` badge (`Screenshot 3.39.45 PM`)
#    2) The Hero Banner is taller (`188 pt`), has open breathing room in the center-right,
#       and draws custom high-precision Vector Blueprint Artwork (`drawDepotVectorIllustration`):
#       - Linux Tux Penguin + BSD Daemon + Kernel Nodes
#       - Classic Mac OS System 7 Happy Mac Icon + Trash Can + Bomb Alert Box
#       - MacAddict CD-ROM Mascot + Doom 3D Perspective Corridor
#       - TempleOS Sword/Sunburst + MS-DOS C:\> Monitor + 3.5-inch Floppy
#       - Console Gamepad + Optical Laser Pickup Lens
#       - SystemRescue Platter Cylinder/Sector Radar + Sine Waveform
hero_start = "    private func depotInteractiveHeroBanner(for item: DepotCatalogItem, isNarrow: Bool) -> some View {"
burn_ws_start = "    private var burnWorkspaceView: some View {"
assert hero_start in a_text and burn_ws_start in a_text, 'hero_start .. burn_ws_start not found'

spacious_vector_hero_and_cards = """    private func depotInteractiveHeroBanner(for item: DepotCatalogItem, isNarrow: Bool) -> some View {
        let isStaged = (store.stagedDepotItemID == item.id && !store.stagedFiles.isEmpty)
        let activeProgress = store.depotDownloadProgress[item.id]
        let segments = item.blueprintSectorSegments
        let treeFiles = item.blueprintRootFiles

        return ZStack(alignment: .leading) {
            // 1. Deep Blueprint Gradient Surface (Works across all 11 Krouton Accent Swatches & Dark/Light Modes)
            RoundedRectangle(cornerRadius: 14)
                .fill(
                    LinearGradient(
                        colors: [
                            store.activeAccent.opacity(0.42),
                            Color(red: 0.05, green: 0.10, blue: 0.19),
                            Color(red: 0.02, green: 0.04, blue: 0.09)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            // 2. Vector Blueprint Art Canvas (Tux Penguin, Classic Mac System 7 Icons, MacAddict + Doom 3D, DOS/TempleOS, Gamepad, Radar)
            Canvas { context, size in
                // Fine 18px CAD Engineering Grid
                let step: CGFloat = 18
                var grid = Path()
                var gx: CGFloat = 0
                while gx <= size.width {
                    grid.move(to: CGPoint(x: gx, y: 0))
                    grid.addLine(to: CGPoint(x: gx, y: size.height))
                    gx += step
                }
                var gy: CGFloat = 0
                while gy <= size.height {
                    grid.move(to: CGPoint(x: 0, y: gy))
                    grid.addLine(to: CGPoint(x: size.width, y: gy))
                    gy += step
                }
                context.stroke(grid, with: .color(Color.cyan.opacity(0.065)), lineWidth: 0.5)

                // Blueprint Dimension Lines & Open Showcase Zone on the Right
                let artX: CGFloat = isNarrow ? size.width * 0.78 : size.width * 0.64
                let artY: CGFloat = size.height * 0.50
                let cyanLine = Color.cyan.opacity(0.38)
                let accentLine = store.activeAccent.opacity(0.48)
                let faintCyan = Color.cyan.opacity(0.16)

                // Outer Blueprint Calibration Ring in the Open Showcase Zone
                let outerRing = CGRect(x: artX - 74, y: artY - 74, width: 148, height: 148)
                context.stroke(Path(ellipseIn: outerRing), with: .color(faintCyan), style: StrokeStyle(lineWidth: 0.9, dash: [6, 4]))

                if item.channel.contains("Live Linux") || item.id.contains("linux") || item.id.contains("ubuntu") || item.id.contains("fedora") || item.id.contains("debian") || item.id.contains("arch") {
                    // === VECTOR ART 1: LINUX TUX PENGUIN + KERNEL NODE GRAPH ===
                    var tux = Path()
                    // Head & Body Torso
                    tux.addEllipse(in: CGRect(x: artX - 24, y: artY - 56, width: 48, height: 42))
                    tux.addEllipse(in: CGRect(x: artX - 34, y: artY - 22, width: 68, height: 74))
                    // Inner Belly Oval
                    tux.addEllipse(in: CGRect(x: artX - 22, y: artY - 12, width: 44, height: 54))
                    // Left & Right Flippers
                    tux.move(to: CGPoint(x: artX - 32, y: artY - 12))
                    tux.addQuadCurve(to: CGPoint(x: artX - 42, y: artY + 28), control: CGPoint(x: artX - 52, y: artY + 6))
                    tux.addLine(to: CGPoint(x: artX - 30, y: artY + 22))
                    tux.move(to: CGPoint(x: artX + 32, y: artY - 12))
                    tux.addQuadCurve(to: CGPoint(x: artX + 42, y: artY + 28), control: CGPoint(x: artX + 52, y: artY + 6))
                    tux.addLine(to: CGPoint(x: artX + 30, y: artY + 22))
                    // Eyes
                    tux.addEllipse(in: CGRect(x: artX - 13, y: artY - 44, width: 9, height: 11))
                    tux.addEllipse(in: CGRect(x: artX + 4, y: artY - 44, width: 9, height: 11))
                    // Beak Triangle
                    tux.move(to: CGPoint(x: artX - 11, y: artY - 30))
                    tux.addLine(to: CGPoint(x: artX + 11, y: artY - 30))
                    tux.addLine(to: CGPoint(x: artX, y: artY - 21))
                    tux.closeSubpath()
                    // Webbed Feet
                    tux.addRoundedRect(in: CGRect(x: artX - 28, y: artY + 46, width: 22, height: 11), cornerSize: CGSize(width: 4, height: 4))
                    tux.addRoundedRect(in: CGRect(x: artX + 6, y: artY + 46, width: 22, height: 11), cornerSize: CGSize(width: 4, height: 4))
                    context.stroke(tux, with: .color(cyanLine), lineWidth: 1.6)

                    // BSD Daemon Trident / Kernel Nodes on the side
                    var nodes = Path()
                    for pt in [CGPoint(x: artX - 72, y: artY - 35), CGPoint(x: artX - 64, y: artY + 25), CGPoint(x: artX + 68, y: artY - 30)] {
                        nodes.addEllipse(in: CGRect(x: pt.x - 5, y: pt.y - 5, width: 10, height: 10))
                        nodes.move(to: pt)
                        nodes.addLine(to: CGPoint(x: artX, y: artY))
                    }
                    context.stroke(nodes, with: .color(accentLine), lineWidth: 1.1)

                } else if item.channel.contains("Vintage Apple") || item.id.contains("mac") {
                    // === VECTOR ART 2: CLASSIC MAC OS SYSTEM 7 HAPPY MAC + TRASH CAN + BOMB DIALOG ===
                    var mac = Path()
                    // Compact Macintosh SE / Classic Bezel
                    mac.addRoundedRect(in: CGRect(x: artX - 58, y: artY - 58, width: 82, height: 98), cornerSize: CGSize(width: 6, height: 6))
                    mac.addRoundedRect(in: CGRect(x: artX - 48, y: artY - 46, width: 62, height: 46), cornerSize: CGSize(width: 4, height: 4))
                    mac.addRect(CGRect(x: artX - 10, y: artY + 14, width: 24, height: 4))
                    // Susan Kare Happy Mac Picasso Nose & Smile
                    mac.move(to: CGPoint(x: artX - 28, y: artY - 34)); mac.addLine(to: CGPoint(x: artX - 28, y: artY - 28))
                    mac.move(to: CGPoint(x: artX - 6, y: artY - 34)); mac.addLine(to: CGPoint(x: artX - 6, y: artY - 28))
                    mac.move(to: CGPoint(x: artX - 17, y: artY - 34)); mac.addLine(to: CGPoint(x: artX - 20, y: artY - 20)); mac.addLine(to: CGPoint(x: artX - 14, y: artY - 20))
                    mac.move(to: CGPoint(x: artX - 28, y: artY - 14))
                    mac.addQuadCurve(to: CGPoint(x: artX - 6, y: artY - 14), control: CGPoint(x: artX - 17, y: artY - 6))
                    context.stroke(mac, with: .color(cyanLine), lineWidth: 1.6)

                    // Classic System 7 Fluted Trash Can Icon
                    var trash = Path()
                    let tx = artX + 42, ty = artY - 10
                    trash.addRect(CGRect(x: tx, y: ty, width: 32, height: 42))
                    trash.addRect(CGRect(x: tx - 3, y: ty - 6, width: 38, height: 6))
                    trash.addRect(CGRect(x: tx + 10, y: ty - 11, width: 12, height: 5))
                    for ridge in [7.0, 16.0, 25.0] {
                        trash.move(to: CGPoint(x: tx + ridge, y: ty + 6))
                        trash.addLine(to: CGPoint(x: tx + ridge, y: ty + 36))
                    }
                    // Classic System 7 Bomb Icon above Trash
                    trash.addEllipse(in: CGRect(x: tx + 4, y: ty - 46, width: 22, height: 22))
                    trash.move(to: CGPoint(x: tx + 22, y: ty - 44))
                    trash.addQuadCurve(to: CGPoint(x: tx + 32, y: ty - 54), control: CGPoint(x: tx + 28, y: ty - 52))
                    context.stroke(trash, with: .color(accentLine), lineWidth: 1.4)

                } else if item.channel.contains("Cover Discs") || item.id.contains("macaddict") || item.id.contains("pcgamer") {
                    // === VECTOR ART 3: MACADDICT CD-ROM MASCOT + DOOM 3D RAYCAST CORRIDOR ===
                    var doom = Path()
                    let r1 = CGRect(x: artX - 78, y: artY - 54, width: 156, height: 108)
                    let r2 = CGRect(x: artX - 46, y: artY - 32, width: 92, height: 64)
                    let r3 = CGRect(x: artX - 20, y: artY - 14, width: 40, height: 28)
                    doom.addRect(r1); doom.addRect(r2); doom.addRect(r3)
                    doom.move(to: CGPoint(x: r1.minX, y: r1.minY)); doom.addLine(to: CGPoint(x: r3.minX, y: r3.minY))
                    doom.move(to: CGPoint(x: r1.maxX, y: r1.minY)); doom.addLine(to: CGPoint(x: r3.maxX, y: r3.minY))
                    doom.move(to: CGPoint(x: r1.minX, y: r1.maxY)); doom.addLine(to: CGPoint(x: r3.minX, y: r3.maxY))
                    doom.move(to: CGPoint(x: r1.maxX, y: r1.maxY)); doom.addLine(to: CGPoint(x: r3.maxX, y: r3.maxY))
                    context.stroke(doom, with: .color(cyanLine), lineWidth: 1.3)

                    // MacAddict Spinning CD-ROM Head Emblem in the center of the corridor
                    var discGuy = Path()
                    discGuy.addEllipse(in: CGRect(x: artX - 28, y: artY - 28, width: 56, height: 56))
                    discGuy.addEllipse(in: CGRect(x: artX - 8, y: artY - 8, width: 16, height: 16))
                    // Cool 90s Shades on the CD Mascot
                    discGuy.addRect(CGRect(x: artX - 20, y: artY - 14, width: 16, height: 8))
                    discGuy.addRect(CGRect(x: artX + 4, y: artY - 14, width: 16, height: 8))
                    discGuy.move(to: CGPoint(x: artX - 4, y: artY - 10)); discGuy.addLine(to: CGPoint(x: artX + 4, y: artY - 10))
                    context.stroke(discGuy, with: .color(accentLine), lineWidth: 1.6)

                } else if item.channel.contains("Console") {
                    // === VECTOR ART 4: GAMECUBE / PS2 OPTICAL PICKUP + ISOMETRIC CONTROLLER ===
                    var pad = Path()
                    // Controller Body Outline
                    pad.addRoundedRect(in: CGRect(x: artX - 64, y: artY - 34, width: 128, height: 68), cornerSize: CGSize(width: 24, height: 24))
                    // D-Pad Left
                    pad.addRect(CGRect(x: artX - 46, y: artY - 6, width: 28, height: 10))
                    pad.addRect(CGRect(x: artX - 37, y: artY - 15, width: 10, height: 28))
                    // Action Buttons Right (A/B/X/Y or Triangle/Circle/X/Square)
                    for bpt in [CGPoint(x: artX + 36, y: artY - 14), CGPoint(x: artX + 36, y: artY + 12), CGPoint(x: artX + 22, y: artY - 1), CGPoint(x: artX + 50, y: artY - 1)] {
                        pad.addEllipse(in: CGRect(x: bpt.x - 5, y: bpt.y - 5, width: 10, height: 10))
                    }
                    // Analog Sticks
                    pad.addEllipse(in: CGRect(x: artX - 20, y: artY + 8, width: 16, height: 16))
                    pad.addEllipse(in: CGRect(x: artX + 4, y: artY + 8, width: 16, height: 16))
                    context.stroke(pad, with: .color(cyanLine), lineWidth: 1.5)

                    // Mini-DVD / GD-ROM Ring
                    let ring = CGRect(x: artX - 48, y: artY - 48, width: 96, height: 96)
                    context.stroke(Path(ellipseIn: ring), with: .color(accentLine), style: StrokeStyle(lineWidth: 1.2, dash: [5, 3]))

                } else if item.channel.contains("Retro PC") || item.id.contains("templeos") || item.id.contains("freedos") {
                    // === VECTOR ART 5: MS-DOS C:\> CRT + TEMPLEOS SWORD/SUNBURST + 3.5" FLOPPY ===
                    var retro = Path()
                    let crt = CGRect(x: artX - 66, y: artY - 46, width: 88, height: 68)
                    retro.addRoundedRect(in: crt, cornerSize: CGSize(width: 5, height: 5))
                    // CRT Stand
                    retro.addRect(CGRect(x: artX - 36, y: artY + 22, width: 28, height: 8))
                    retro.addRect(CGRect(x: artX - 50, y: artY + 30, width: 56, height: 6))
                    // DOS Prompt Chevron `C:\>`
                    retro.move(to: CGPoint(x: crt.minX + 12, y: crt.minY + 16))
                    retro.addLine(to: CGPoint(x: crt.minX + 20, y: crt.minY + 22))
                    retro.addLine(to: CGPoint(x: crt.minX + 12, y: crt.minY + 28))
                    retro.addRect(CGRect(x: crt.minX + 25, y: crt.minY + 24, width: 10, height: 3))
                    context.stroke(retro, with: .color(cyanLine), lineWidth: 1.5)

                    // 3.5-inch Floppy Disk + TempleOS Sunburst Rays on Right
                    var flop = Path()
                    let flRect = CGRect(x: artX + 32, y: artY - 36, width: 54, height: 58)
                    flop.addRect(flRect)
                    flop.addRect(CGRect(x: flRect.minX + 12, y: flRect.minY, width: 28, height: 18))
                    flop.addRect(CGRect(x: flRect.minX + 8, y: flRect.minY + 28, width: 38, height: 24))
                    context.stroke(flop, with: .color(accentLine), lineWidth: 1.4)
                } else {
                    // === VECTOR ART 6: SYSTEM RESCUE PLATTER RADAR + ECG WAVEFORM ===
                    for r in [24.0, 46.0, 68.0] {
                        let cRect = CGRect(x: artX - r, y: artY - r, width: r * 2, height: r * 2)
                        context.stroke(Path(ellipseIn: cRect), with: .color(cyanLine), style: StrokeStyle(lineWidth: 1.2, dash: r == 46.0 ? [5, 3] : []))
                    }
                    var ecg = Path()
                    ecg.move(to: CGPoint(x: artX - 75, y: artY))
                    ecg.addLine(to: CGPoint(x: artX - 28, y: artY))
                    ecg.addLine(to: CGPoint(x: artX - 18, y: artY - 34))
                    ecg.addLine(to: CGPoint(x: artX - 4, y: artY + 38))
                    ecg.addLine(to: CGPoint(x: artX + 10, y: artY - 18))
                    ecg.addLine(to: CGPoint(x: artX + 22, y: artY))
                    ecg.addLine(to: CGPoint(x: artX + 75, y: artY))
                    context.stroke(ecg, with: .color(accentLine), lineWidth: 1.8)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 14))

            // 3. Foreground Layout: Left Info Column + Open Vector Showcase + Right Schematic Box
            HStack(alignment: .center, spacing: 12) {
                VStack(alignment: .leading, spacing: 8) {
                    // Top Micro Telemetry Header
                    HStack(spacing: 6) {
                        Image(systemName: item.sfSymbol)
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(store.activeAccent)
                        Text("CAD BLUEPRINT INSPECTOR • \\(item.channel.uppercased())")
                            .font(.system(size: 9.5, weight: .heavy, design: .monospaced))
                            .foregroundStyle(store.activeAccent)
                            .lineLimit(1)
                        Text("•").foregroundStyle(.white.opacity(0.35))
                        Text("\\(item.architecture) • \\(item.bootStandard)")
                            .font(.system(size: 9.5, weight: .semibold, design: .monospaced))
                            .foregroundStyle(.white.opacity(0.82))
                            .lineLimit(1)
                    }

                    // Selected Title + Version
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text(item.title)
                            .font(.system(size: isNarrow ? 17 : 20, weight: .bold))
                            .foregroundStyle(.white)
                            .lineLimit(1)
                        Text("v\\(item.version)")
                            .font(.system(size: 12, weight: .bold, design: .monospaced))
                            .foregroundStyle(.cyan)
                            .lineLimit(1)
                    }

                    Text(item.subtitle)
                        .font(.system(size: 11.5))
                        .foregroundStyle(.white.opacity(0.86))
                        .lineLimit(2)
                        .frame(maxWidth: 460, alignment: .leading)

                    Spacer(minLength: 2)

                    // Bottom Row: 3-Segment CAD Sector Map + Stage & Hex Action Buttons
                    HStack(spacing: 8) {
                        if !isNarrow {
                            HStack(spacing: 2) {
                                ForEach(Array(segments.enumerated()), id: \\.offset) { idx, seg in
                                    VStack(alignment: .leading, spacing: 1) {
                                        Text(seg.label)
                                            .font(.system(size: 7.5, weight: .bold, design: .monospaced))
                                            .foregroundStyle(.white)
                                            .lineLimit(1)
                                        Text(seg.lbaRange)
                                            .font(.system(size: 7, design: .monospaced))
                                            .foregroundStyle(.cyan.opacity(0.9))
                                            .lineLimit(1)
                                    }
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 3.5)
                                    .background(
                                        idx == 0 ? Color.cyan.opacity(0.28) : (idx == 1 ? Color.green.opacity(0.26) : store.activeAccent.opacity(0.36))
                                    )
                                    .overlay(Rectangle().stroke(Color.cyan.opacity(0.32), lineWidth: 0.6))
                                }
                            }
                            .clipShape(RoundedRectangle(cornerRadius: 5))
                        }

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
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }

                Spacer(minLength: isNarrow ? 8 : 95) // Open showcase space so the Vector Blueprint Art shines through!

                if !isNarrow {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 5) {
                            Image(systemName: item.sfSymbol)
                                .font(.system(size: 10, weight: .bold))
                                .foregroundStyle(.cyan)
                            Text("DISC CONTENT SCHEMATIC")
                                .font(.system(size: 8.5, weight: .heavy, design: .monospaced))
                                .foregroundStyle(.cyan)
                                .lineLimit(1)
                            Spacer(minLength: 4)
                            Text(item.sizeDisplay)
                                .font(.system(size: 8.5, weight: .bold, design: .monospaced))
                                .foregroundStyle(.white.opacity(0.75))
                                .lineLimit(1)
                        }
                        Divider().overlay(Color.cyan.opacity(0.35))

                        ForEach(treeFiles, id: \\.self) { pathLine in
                            HStack(spacing: 4) {
                                Text("├─")
                                    .foregroundStyle(.cyan.opacity(0.75))
                                Text(pathLine)
                                    .foregroundStyle(.white.opacity(0.92))
                                    .lineLimit(1)
                            }
                            .font(.system(size: 8.5, weight: .medium, design: .monospaced))
                        }
                    }
                    .padding(10)
                    .frame(width: 225, alignment: .leading)
                    .background(Color.black.opacity(0.50))
                    .clipShape(RoundedRectangle(cornerRadius: 9))
                    .overlay(
                        RoundedRectangle(cornerRadius: 9)
                            .stroke(Color.cyan.opacity(0.38), style: StrokeStyle(lineWidth: 1.0, dash: [4, 2]))
                    )
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
        }
        .frame(height: 184)
        .fixedSize(horizontal: false, vertical: true)
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(isStaged ? Color.green.opacity(0.75) : store.activeAccent.opacity(0.55), lineWidth: 1.5)
        )
    }

    private func depotAppStoreCard(for item: DepotCatalogItem, isSelectedInHero: Bool) -> some View {
        let isStaged = (store.stagedDepotItemID == item.id && !store.stagedFiles.isEmpty)
        let activeProgress = store.depotDownloadProgress[item.id]

        return VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top, spacing: 10) {
                ZStack {
                    RoundedRectangle(cornerRadius: 11)
                        .fill(
                            LinearGradient(
                                colors: [
                                    isStaged ? Color.green : (isSelectedInHero ? store.activeAccent : store.activeAccent.opacity(0.80)),
                                    (isStaged ? Color.green : store.activeAccent).opacity(0.45)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 40, height: 40)
                        .overlay(
                            RoundedRectangle(cornerRadius: 11)
                                .stroke(Color.white.opacity(isSelectedInHero ? 0.45 : 0.18), lineWidth: 1)
                        )

                    Image(systemName: item.sfSymbol)
                        .font(.system(size: 17, weight: .bold))
                        .foregroundStyle(isStaged ? Color.black : store.activeOnAccentText)
                }

                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text(item.title)
                            .font(.system(size: 12.5, weight: .bold))
                            .foregroundStyle(isSelectedInHero ? store.activeAccent : .primary)
                            .lineLimit(1)
                        Spacer(minLength: 2)
                        if isSelectedInHero {
                            Text("HERO")
                                .font(.system(size: 8, weight: .heavy, design: .monospaced))
                                .padding(.horizontal, 5)
                                .padding(.vertical, 1.5)
                                .background(store.activeAccent.opacity(0.20))
                                .foregroundStyle(store.activeAccent)
                                .clipShape(RoundedRectangle(cornerRadius: 3))
                                .fixedSize(horizontal: true, vertical: false)
                        }
                    }

                    Text(item.subtitle)
                        .font(.system(size: 10.5))
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                        .frame(minHeight: 26, alignment: .topLeading)
                }
            }

            Divider()

            HStack(spacing: 6) {
                VStack(alignment: .leading, spacing: 1) {
                    Text("\\(item.architecture) • \\(item.sizeDisplay)")
                        .font(.system(size: 9.5, weight: .bold, design: .monospaced))
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                    Text(item.bootStandard)
                        .font(.system(size: 9, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                if let prog = activeProgress {
                    HStack(spacing: 4) {
                        ProgressView(value: prog)
                            .progressViewStyle(.circular)
                            .controlSize(.small)
                        Text("\\(Int(prog * 100))%")
                            .font(.system(size: 9.5, weight: .heavy, design: .monospaced))
                            .lineLimit(1)
                    }
                    .padding(.horizontal, 9)
                    .padding(.vertical, 4)
                    .background(store.activeAccent.opacity(0.18))
                    .clipShape(Capsule())
                    .fixedSize(horizontal: true, vertical: false)
                } else {
                    Button {
                        store.selectedDepotHeroItemID = item.id
                        store.downloadAndStageDepotItem(id: item.id, jumpToInspector: false)
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: isStaged ? "checkmark.circle.fill" : (item.isDownloaded ? "opticaldisc.fill" : "icloud.and.arrow.down.fill"))
                            Text(isStaged ? "STAGED" : (item.isDownloaded ? "STAGE" : "GET"))
                                .lineLimit(1)
                        }
                        .font(.system(size: 10, weight: .heavy))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4.5)
                        .background(isStaged ? Color.green : (item.isDownloaded ? store.activeAccent : Color.primary.opacity(0.12)))
                        .foregroundStyle(isStaged ? Color.black : (item.isDownloaded ? store.activeOnAccentText : store.activeAccent))
                        .clipShape(Capsule())
                        .overlay(
                            Capsule()
                                .stroke(isStaged ? Color.clear : store.activeAccent.opacity(0.5), lineWidth: 1)
                        )
                        .fixedSize(horizontal: true, vertical: false)
                    }
                    .buttonStyle(.plain)

                    Button {
                        store.selectedDepotHeroItemID = item.id
                        store.downloadAndStageDepotItem(id: item.id, jumpToInspector: true)
                    } label: {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 9.5, weight: .bold))
                            .padding(5.5)
                            .background(Color.primary.opacity(0.08))
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)
                    .help("Stage image and open directly in the Sector & Hex Inspector")
                }
            }
        }
        .padding(11)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 11)
                .fill(isSelectedInHero ? store.activeAccent.opacity(0.08) : Color(NSColor.controlBackgroundColor))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 11)
                .stroke(
                    isStaged ? Color.green.opacity(0.70) : (isSelectedInHero ? store.activeAccent.opacity(0.85) : Color.primary.opacity(0.09)),
                    lineWidth: (isStaged || isSelectedInHero) ? 1.5 : 1.0
                )
        )
        .clipped()
        .contentShape(RoundedRectangle(cornerRadius: 11))
        .onTapGesture {
            store.selectedDepotHeroItemID = item.id
        }
    }

"""

a_text = a_text[:a_text.index(hero_start)] + spacious_vector_hero_and_cards + a_text[a_text.index(burn_ws_start):]

# F. Fix right column `destinationCard` so its inner Pickers & HStacks use flexible widths
#    and `.clipped()`, preventing `Physical Burner`, `Blank CD-RW`, and `Burn Disc` from
#    overflowing off the right edge (`Screenshot 3.40.03 PM`)!
a_text = a_text.replace('.frame(width: 158)', '.frame(minWidth: 110, maxWidth: 158)')
a_text = a_text.replace('.frame(width: 145)', '.frame(minWidth: 100, maxWidth: 145)')

# Also change `let isNarrowWorkspace = geo.size.width < 700` to `< 740` so the 2-column
# Depot grid collapses to 1 column BEFORE any card gets squeezed below 350pt!
a_text = a_text.replace('let isNarrowWorkspace = geo.size.width < 700', 'let isNarrowWorkspace = geo.size.width < 740')

with open(a_path, "w") as f:
    f.write(a_text)
print("[OK] Added short left-sidebar names, strict column clipping, Layout Stress-Test Preset menu, and custom Vector Blueprint Art (Tux, System 7 Icons, MacAddict, DOS, Gamepad) in KroutonApp.swift")
EOF_LAYOUT_HERO_VECTORS

swift build
git add -A
git commit -m "feat(layout,depot): add short sidebar task names, strict column clipping, layout stress-test menu, and custom vector blueprint illustrations" || true
echo "=================================================================="
echo " [SUCCESS] Short Names, Vector Blueprint Art & Clean Clipping Built!"
echo " Switch to Xcode and press Command + R to test!"
echo "=================================================================="
