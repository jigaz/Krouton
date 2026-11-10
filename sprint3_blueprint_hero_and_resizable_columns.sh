#!/bin/zsh
set -e

cd ~/Developer/krouton

python3 - << 'EOF_BLUEPRINT_AND_SPLIT'
import re

# ==============================================================================
# 1. Update Sources/KroutonApp/KroutonModels.swift
#    - Adds `blueprintSectorSegments` and `blueprintRootFiles` computed helpers
#      on DepotCatalogItem so the CAD Blueprint Hero card renders the ACTUAL
#      directory structure & sector partition map of the selected disc image!
# ==============================================================================
m_path = "Sources/KroutonApp/KroutonModels.swift"
with open(m_path, "r") as f:
    m_text = f.read()

if "public var blueprintRootFiles: [String]" not in m_text:
    blueprint_ext = """
// MARK: - DepotCatalogItem CAD Blueprint & Volume Structure Schematic Helpers
extension DepotCatalogItem {
    public var blueprintSectorSegments: [(label: String, lbaRange: String)] {
        if bootStandard.contains("APM") || bootStandard.contains("HFS") {
            return [
                ("BLK 0..1: Driver + APM", "LBA 00..63"),
                ("HFS Catalog & Extents", "LBA 64..1024"),
                ("Blessed System + Payload", "LBA 1025..END")
            ]
        } else if bootStandard.contains("DOL-006") || bootStandard.contains("RVL-006") {
            return [
                ("boot.bin + bi2.bin", "0x0000..2440"),
                ("apploader.img", "0x2440..FST"),
                ("Game FST + main.dol", "32KB ECC..END")
            ]
        } else if bootStandard.contains("MIL-CD") || bootStandard.contains("Mode 2") {
            return [
                ("S1: Audio / Pre-Gap", "LBA 0..11400"),
                ("IP.BIN Bootstrap", "LBA 45000+16"),
                ("1ST_READ.BIN + XA", "LBA 45017..END")
            ]
        } else {
            return [
                ("SYS AREA / MBR", "LBA 00..15"),
                ("PVD + EL TORITO", "LBA 16..31"),
                ("UDF / ISO9660 TREE", "LBA 32..END")
            ]
        }
    }

    public var blueprintRootFiles: [String] {
        switch channel {
        case "Rescue & Diagnostics":
            return [
                "/EFI/BOOT/BOOTX64.EFI",
                "/boot/grub/grub.cfg",
                "/sysresccd/boot/x86_64/vmlinuz",
                "/sysresccd/x86_64/airootfs.sfs",
                "/NVME_SMART_DIAG.IMG"
            ]
        case "Live Linux & BSD":
            return [
                "/EFI/BOOT/grubx64.efi",
                "/boot/vmlinuz-linux-lts",
                "/live/filesystem.squashfs",
                "/dists/stable/Release.gpg",
                "/SHA256SUMS.SIGN"
            ]
        case "Vintage Apple (archive.org)":
            return [
                ":Apple_partition_map (Block 1)",
                ":System Folder:Mac OS ROM",
                ":System Folder:System",
                ":System Folder:Finder",
                ":Applications:Apple HD SC Setup"
            ]
        case "Console Homebrew & ROMs":
            return [
                "/SYSTEM.CNF (BOOT=cdrom:\\\\MAIN.EXE;1)",
                "/APPLOADER.IMG + /BOOT.DOL",
                "/VIDEO_TS/VIDEO_TS.IFO (FreeDVDBoot)",
                "/240P_SUITE/PATTERNS.TIM",
                "/REDUMP_SHA1_VERIFIED.DAT"
            ]
        case "Cover Discs & Demoscene":
            return [
                ":MacAddict_036_Interface",
                "/DEMOS/FUTURE_CREW/2ND_REAL.EXE",
                "/S3M_MOD_ARCHIVE/CHIPTUNE.XM",
                "/QUICKTIME_4_INSTALLER.HQX",
                "/AUTORUN.INF + /README.TXT"
            ]
        default:
            return [
                "/FDOS/BIN/COMMAND.COM",
                "/AUTOBOOT/KERNEL.SYS",
                "/BIOS_FLASH/AWDFLASH.EXE",
                "/SYSTEM/SERVERS/APP_SERVER",
                "/BOOT/CATALOG.BIN"
            ]
        }
    }
}
"""
    m_text = m_text + "\n" + blueprint_ext
    with open(m_path, "w") as f:
        f.write(m_text)
    print("[OK] Added blueprintSectorSegments and blueprintRootFiles to DepotCatalogItem in KroutonModels.swift")

# ==============================================================================
# 2. Update Sources/KroutonApp/KroutonApp.swift
#    - Relaxes HSplitView column constraints & window minWidth so all 3 columns
#      can be smoothly dragged skinny or wide
#    - Adds leftColumnLiveWidth and rightColumnLiveWidth progressive hiding
#    - Replaces depotInteractiveHeroBanner with a compact (fixed height: 122 pt)
#      CAD Blueprint / Engineering Schematic Hero Card
# ==============================================================================
a_path = "Sources/KroutonApp/KroutonApp.swift"
with open(a_path, "r") as f:
    a_text = f.read()

if "leftColumnLiveWidth" not in a_text:
    a_text = a_text.replace(
        '@State private var depotSearchQuery: String = ""',
        '@State private var depotSearchQuery: String = ""\n    @State private var leftColumnLiveWidth: CGFloat = 265\n    @State private var rightColumnLiveWidth: CGFloat = 360'
    )

old_hsplit = """            HSplitView {
                leftFormatChooserColumn
                    .frame(minWidth: 265, idealWidth: 285, maxWidth: 325)

                centerAdaptableWorkspace
                    .frame(minWidth: 600, maxWidth: .infinity, maxHeight: .infinity)

                rightDestinationColumn
                    .frame(minWidth: 380, idealWidth: 400, maxWidth: 450)
            }
        }
        .frame(minWidth: 1320, idealWidth: 1420, minHeight: 840, idealHeight: 900)"""

new_hsplit = """            HSplitView {
                leftFormatChooserColumn
                    .frame(minWidth: 168, idealWidth: 255, maxWidth: 360, maxHeight: .infinity)

                centerAdaptableWorkspace
                    .frame(minWidth: 410, idealWidth: 740, maxWidth: .infinity, maxHeight: .infinity)

                rightDestinationColumn
                    .frame(minWidth: 235, idealWidth: 350, maxWidth: 460, maxHeight: .infinity)
            }
        }
        .frame(minWidth: 880, idealWidth: 1380, minHeight: 680, idealHeight: 880)"""

if old_hsplit in a_text:
    a_text = a_text.replace(old_hsplit, new_hsplit, 1)
    print("[OK] Updated HSplitView & window bounds for smooth 3-column resizing")

old_left_header = """            HStack {
                Label(KroutonL10n.tr("FORMAT CHOOSER"), systemImage: "list.bullet.rectangle")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(.secondary)
                Spacer()"""

new_left_header = """            HStack {
                Label(leftColumnLiveWidth < 195 ? KroutonL10n.tr("FORMATS") : KroutonL10n.tr("FORMAT CHOOSER"), systemImage: "list.bullet.rectangle")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                Spacer(minLength: 4)"""

if old_left_header in a_text:
    a_text = a_text.replace(old_left_header, new_left_header, 1)

old_left_bg = """        .background(Color(NSColor.controlBackgroundColor))
    }

    private func taskRowButton("""

new_left_bg = """        .background(
            GeometryReader { proxy in
                Color(NSColor.controlBackgroundColor)
                    .onAppear { leftColumnLiveWidth = proxy.size.width }
                    .onChange(of: proxy.size.width) { _, newW in leftColumnLiveWidth = newW }
            }
        )
    }

    private func taskRowButton("""

if old_left_bg in a_text:
    a_text = a_text.replace(old_left_bg, new_left_bg, 1)

old_task_vstack = """                VStack(alignment: .leading, spacing: 1) {
                    Text(KroutonL10n.tr(title))
                        .font(.system(size: store.sidebarIconSize.titleFontSize, weight: .semibold))
                        .foregroundStyle(isSelected ? store.activeOnAccentText : .primary)
                        .lineLimit(1)
                    Text(KroutonL10n.tr(colloquial))
                        .font(.system(size: max(9.5, store.sidebarIconSize.titleFontSize - 2.0)))
                        .foregroundStyle(isSelected ? store.activeOnAccentText.opacity(0.82) : .secondary)
                        .lineLimit(1)
                }"""

new_task_vstack = """                VStack(alignment: .leading, spacing: 1) {
                    Text(KroutonL10n.tr(title))
                        .font(.system(size: store.sidebarIconSize.titleFontSize, weight: .semibold))
                        .foregroundStyle(isSelected ? store.activeOnAccentText : .primary)
                        .lineLimit(1)
                    if leftColumnLiveWidth >= 215 {
                        Text(KroutonL10n.tr(colloquial))
                            .font(.system(size: max(9.5, store.sidebarIconSize.titleFontSize - 2.0)))
                            .foregroundStyle(isSelected ? store.activeOnAccentText.opacity(0.82) : .secondary)
                            .lineLimit(1)
                    }
                }"""

if old_task_vstack in a_text:
    a_text = a_text.replace(old_task_vstack, new_task_vstack, 1)

old_right_hdr = """            HStack {
                Label("DESTINATIONS (\\(store.destinationQueue.count))", systemImage: "arrow.right.doc.on.clipboard")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(.secondary)
                Spacer()
                Button {
                    appendContextAwareDestination()
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "plus")
                        Text(KroutonL10n.tr("Add Output"))
                    }
                    .font(.system(size: 11, weight: .semibold))
                    .padding(.horizontal, 9)
                    .padding(.vertical, 4)
                    .background(store.activeAccent.opacity(0.2))
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }"""

new_right_hdr = """            HStack(spacing: 6) {
                Label(
                    rightColumnLiveWidth < 265 ? "QUEUE (\\(store.destinationQueue.count))" : "DESTINATIONS (\\(store.destinationQueue.count))",
                    systemImage: "arrow.right.doc.on.clipboard"
                )
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(.secondary)
                .lineLimit(1)
                Spacer(minLength: 4)
                Button {
                    appendContextAwareDestination()
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "plus")
                        if rightColumnLiveWidth >= 255 {
                            Text(KroutonL10n.tr("Add Output"))
                                .lineLimit(1)
                        }
                    }
                    .font(.system(size: 11, weight: .semibold))
                    .padding(.horizontal, 9)
                    .padding(.vertical, 4)
                    .background(store.activeAccent.opacity(0.2))
                    .clipShape(Capsule())
                    .fixedSize(horizontal: true, vertical: false)
                }
                .buttonStyle(.plain)
            }"""

if old_right_hdr in a_text:
    a_text = a_text.replace(old_right_hdr, new_right_hdr, 1)

old_right_scroll = """            // Iterating directly over store.destinationQueue by UUID (Zero raw array indices = Zero crashes!)
            ScrollView {"""

new_right_scroll = """            // Iterating directly over store.destinationQueue by UUID (Zero raw array indices = Zero crashes!)
            ScrollView {
                GeometryReader { proxy in
                    Color.clear
                        .onAppear { rightColumnLiveWidth = proxy.size.width }
                        .onChange(of: proxy.size.width) { _, newW in rightColumnLiveWidth = newW }
                }
                .frame(height: 0)"""

if old_right_scroll in a_text:
    a_text = a_text.replace(old_right_scroll, new_right_scroll, 1)

a_text = a_text.replace(
    'Text(KroutonL10n.tr("Scope"))',
    'if rightColumnLiveWidth >= 285 { Text(KroutonL10n.tr("Scope")).lineLimit(1) }'
)
a_text = a_text.replace(
    'Text(KroutonL10n.tr("Eject"))',
    'if rightColumnLiveWidth >= 285 { Text(KroutonL10n.tr("Eject")).lineLimit(1) }'
)
a_text = a_text.replace(
    'Text(KroutonL10n.tr("Write Speed:"))',
    'Text(rightColumnLiveWidth < 280 ? "Speed:" : KroutonL10n.tr("Write Speed:")).lineLimit(1)'
)
a_text = a_text.replace(
    'Text(KroutonL10n.tr("DVD-ROM Bitset"))',
    'Text(rightColumnLiveWidth < 295 ? "DVD-ROM" : KroutonL10n.tr("DVD-ROM Bitset")).lineLimit(1)'
)

hero_start = "    private func depotInteractiveHeroBanner(for item: DepotCatalogItem, isNarrow: Bool) -> some View {"
hero_end = "    private func depotAppStoreCard(for item: DepotCatalogItem, isSelectedInHero: Bool) -> some View {"
assert hero_start in a_text and hero_end in a_text, "depotInteractiveHeroBanner bounds not found"

compact_blueprint_hero = """    private func depotInteractiveHeroBanner(for item: DepotCatalogItem, isNarrow: Bool) -> some View {
        let isStaged = (store.stagedDepotItemID == item.id && !store.stagedFiles.isEmpty)
        let activeProgress = store.depotDownloadProgress[item.id]
        let showBlueprintPanel = !isNarrow
        let segments = item.blueprintSectorSegments
        let treeFiles = item.blueprintRootFiles

        return ZStack(alignment: .leading) {
            // 1. Adaptive Gradient + CAD Blueprint Grid & Schematic Background
            RoundedRectangle(cornerRadius: 12)
                .fill(
                    LinearGradient(
                        colors: [
                            store.activeAccent.opacity(0.38),
                            Color(red: 0.08, green: 0.11, blue: 0.17),
                            Color(red: 0.04, green: 0.06, blue: 0.10)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            // CAD Engineering Blueprint Mesh + Radial Platter Wireframe (SwiftUI Canvas)
            Canvas { context, size in
                let step: CGFloat = 18
                var gridPath = Path()
                var x: CGFloat = 0
                while x <= size.width {
                    gridPath.move(to: CGPoint(x: x, y: 0))
                    gridPath.addLine(to: CGPoint(x: x, y: size.height))
                    x += step
                }
                var y: CGFloat = 0
                while y <= size.height {
                    gridPath.move(to: CGPoint(x: 0, y: y))
                    gridPath.addLine(to: CGPoint(x: size.width, y: y))
                    y += step
                }
                context.stroke(gridPath, with: .color(Color.white.opacity(0.055)), lineWidth: 0.6)

                var majorPath = Path()
                majorPath.move(to: CGPoint(x: size.width * 0.54, y: 0))
                majorPath.addLine(to: CGPoint(x: size.width * 0.54, y: size.height))
                majorPath.move(to: CGPoint(x: 0, y: size.height * 0.5))
                majorPath.addLine(to: CGPoint(x: size.width, y: size.height * 0.5))
                context.stroke(majorPath, with: .color(store.activeAccent.opacity(0.18)), style: StrokeStyle(lineWidth: 0.8, dash: [4, 3]))

                let center = CGPoint(x: size.width - 115, y: size.height * 0.52)
                for radius in [28.0, 52.0, 76.0, 98.0] {
                    let rect = CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2)
                    context.stroke(
                        Path(ellipseIn: rect),
                        with: .color(store.activeAccent.opacity(radius == 52.0 ? 0.30 : 0.15)),
                        style: StrokeStyle(lineWidth: radius == 52.0 ? 1.5 : 0.8, dash: radius == 76.0 ? [5, 3] : [])
                    )
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 12))

            // 2. Foreground Content: Left Title/Specs/Actions + Right Live Disc Content Blueprint Schematic
            HStack(alignment: .center, spacing: 14) {
                VStack(alignment: .leading, spacing: 5) {
                    HStack(spacing: 6) {
                        Image(systemName: item.sfSymbol)
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(store.activeAccent)
                        Text("BLUEPRINT INSPECTOR • \\(item.channel.uppercased())")
                            .font(.system(size: 9, weight: .heavy, design: .monospaced))
                            .foregroundStyle(store.activeAccent)
                            .lineLimit(1)
                        Text("•")
                            .foregroundStyle(.white.opacity(0.35))
                        Text("\\(item.architecture) • \\(item.bootStandard) • SHA: \\(item.sha256Short)")
                            .font(.system(size: 9, weight: .semibold, design: .monospaced))
                            .foregroundStyle(.white.opacity(0.78))
                            .lineLimit(1)
                    }

                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text(item.title)
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(.white)
                            .lineLimit(1)
                        Text("v\\(item.version)")
                            .font(.system(size: 11, weight: .bold, design: .monospaced))
                            .foregroundStyle(store.activeAccent)
                            .lineLimit(1)
                        Spacer(minLength: 0)
                    }

                    Text(item.subtitle)
                        .font(.system(size: 11))
                        .foregroundStyle(.white.opacity(0.82))
                        .lineLimit(1)

                    HStack(spacing: 8) {
                        // Mini CAD Sector Partition Map of the Disc Image
                        HStack(spacing: 2) {
                            ForEach(Array(segments.enumerated()), id: \\.offset) { idx, seg in
                                VStack(alignment: .leading, spacing: 0) {
                                    Text(seg.label)
                                        .font(.system(size: 7.5, weight: .bold, design: .monospaced))
                                        .foregroundStyle(.white)
                                        .lineLimit(1)
                                    Text(seg.lbaRange)
                                        .font(.system(size: 7, design: .monospaced))
                                        .foregroundStyle(.white.opacity(0.70))
                                        .lineLimit(1)
                                }
                                .padding(.horizontal, 6)
                                .padding(.vertical, 3)
                                .background(
                                    idx == 0 ? Color.cyan.opacity(0.28) : (idx == 1 ? Color.green.opacity(0.28) : store.activeAccent.opacity(0.34))
                                )
                                .overlay(
                                    Rectangle()
                                        .stroke(Color.white.opacity(0.22), lineWidth: 0.6)
                                )
                            }
                        }
                        .clipShape(RoundedRectangle(cornerRadius: 4))

                        Spacer(minLength: 4)

                        if let prog = activeProgress {
                            HStack(spacing: 5) {
                                ProgressView(value: prog)
                                    .progressViewStyle(.circular)
                                    .controlSize(.small)
                                Text("\\(Int(prog * 100))%")
                                    .font(.system(size: 10, weight: .heavy, design: .monospaced))
                                    .foregroundStyle(.white)
                                    .lineLimit(1)
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 5)
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
                                .font(.system(size: 10.5, weight: .heavy))
                                .padding(.horizontal, 12)
                                .padding(.vertical, 5)
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
                                .font(.system(size: 10, weight: .bold))
                                .padding(.horizontal, 10)
                                .padding(.vertical, 5)
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

                // RIGHT SIDE: Live CAD Blueprint of the Actual On-Disc File Tree (Auto-hides when narrow!)
                if showBlueprintPanel {
                    VStack(alignment: .leading, spacing: 2.5) {
                        HStack {
                            Image(systemName: "cpu")
                                .font(.system(size: 8.5, weight: .bold))
                                .foregroundStyle(.cyan)
                            Text("ON-DISC VOLUME BLUEPRINT")
                                .font(.system(size: 8, weight: .heavy, design: .monospaced))
                                .foregroundStyle(.cyan)
                                .lineLimit(1)
                            Spacer()
                            Text(item.sizeDisplay)
                                .font(.system(size: 8, weight: .bold, design: .monospaced))
                                .foregroundStyle(.white.opacity(0.65))
                                .lineLimit(1)
                        }
                        Divider().overlay(Color.cyan.opacity(0.3))

                        ForEach(treeFiles, id: \\.self) { pathLine in
                            HStack(spacing: 4) {
                                Text("├─")
                                    .foregroundStyle(.cyan.opacity(0.65))
                                Text(pathLine)
                                    .foregroundStyle(.white.opacity(0.88))
                                    .lineLimit(1)
                            }
                            .font(.system(size: 8.5, weight: .medium, design: .monospaced))
                        }
                    }
                    .padding(8)
                    .frame(width: 240, alignment: .leading)
                    .background(Color.black.opacity(0.42))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.cyan.opacity(0.32), style: StrokeStyle(lineWidth: 0.9, dash: [4, 2]))
                    )
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
        }
        .frame(height: 120)
        .fixedSize(horizontal: false, vertical: true)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(isStaged ? Color.green.opacity(0.75) : store.activeAccent.opacity(0.55), lineWidth: 1.5)
        )
    }

"""

a_text = a_text[:a_text.index(hero_start)] + compact_blueprint_hero + a_text[a_text.index(hero_end):]

with open(a_path, "w") as f:
    f.write(a_text)
print("[OK] Built compact CAD Blueprint Hero card (120pt fixed height) & smooth 3-column resizing with progressive disclosure")
EOF_BLUEPRINT_AND_SPLIT

swift build
git add -A
git commit -m "feat(depot,layout): add compact CAD blueprint Hero schematic and smooth 3-column resizing with progressive element hiding" || true
echo "=================================================================="
echo " [SUCCESS] Compact Blueprint Hero & 3-Column Resizing Built!"
echo " Switch to Xcode and press Command + R to test!"
echo "=================================================================="
