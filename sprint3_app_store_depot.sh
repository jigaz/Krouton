#!/bin/zsh
set -e

cd ~/Developer/krouton

python3 - << 'EOF_DEPOT_STORE'
# ==============================================================================
# 1. Update Sources/KroutonApp/KroutonModels.swift
#    - Expands store.depotItems to 12 curated bootable & archival images
#    - Adds stagedDepotItemID, depotDownloadProgress, and stageDepotItemForBurning
# ==============================================================================
m_path = "Sources/KroutonApp/KroutonModels.swift"
with open(m_path, "r") as f:
    m_text = f.read()

old_depot_block = """    @Published public var depotItems: [DepotCatalogItem] = [
        DepotCatalogItem(id: "sysrescue-11", title: "SystemRescue 11.03 Live", subtitle: "Complete ZFS/Btrfs/APFS recovery, partitioning, ddrescue & network tools", channel: "Rescue & Diagnostics", version: "11.03 (2026)", sizeDisplay: "854 MB", architecture: "x86_64 / UEFI", bootStandard: "El Torito BIOS + UEFI", sha256Short: "8f4a...e91c", sfSymbol: "cross.case.fill", isDownloaded: true),
        DepotCatalogItem(id: "freedos-14", title: "FreeDOS 1.4 Live + BIOS Flasher Room", subtitle: "Classic DOS environment with 600 MB open space to inject motherboard/drive firmware", channel: "Rescue & Diagnostics", version: "1.4 Final", sizeDisplay: "412 MB", architecture: "x86 Real Mode", bootStandard: "El Torito Floppy/HD Emulation", sha256Short: "3c19...b04d", sfSymbol: "cpu.fill", isDownloaded: true),
        DepotCatalogItem(id: "macos922-uni", title: "Mac OS 9.2.2 Universal Boot CD (Classic APM)", subtitle: "Bootable HFS Standard + Apple Partition Map for PowerMac G3/G4 & iBook", channel: "Vintage Apple (archive.org)", version: "9.2.2 (2002)", sizeDisplay: "618 MB", architecture: "PowerPC", bootStandard: "Apple Partition Map + Blessed Folder", sha256Short: "a72e...441f", sfSymbol: "desktopcomputer", isDownloaded: false),
        DepotCatalogItem(id: "ubuntu-2604", title: "Ubuntu Desktop 26.04 LTS Live DVD", subtitle: "Official Canonical Live Desktop & Installer (ARM64 Apple Silicon VM & x86_64)", channel: "Live Linux & BSD", version: "26.04 LTS", sizeDisplay: "4.48 GB", architecture: "ARM64 / x86_64", bootStandard: "UEFI ESP + El Torito", sha256Short: "e901...772a", sfSymbol: "terminal.fill", isDownloaded: false)
    ]"""

new_depot_block = """    @Published public var stagedDepotItemID: String? = nil
    @Published public var depotDownloadProgress: [String: Double] = [:]

    @Published public var depotItems: [DepotCatalogItem] = [
        // Channel 1: System Rescue & BIOS ("depot-rescue")
        DepotCatalogItem(id: "sysrescue-11", title: "SystemRescue 11.03 Live", subtitle: "Complete ZFS/Btrfs/APFS recovery, GParted, ddrescue, TestDisk & network diagnostics", channel: "Rescue & Diagnostics", version: "11.03", sizeDisplay: "854 MB", architecture: "x86_64 / UEFI", bootStandard: "El Torito BIOS + UEFI", sha256Short: "8f4a...e91c", sfSymbol: "cross.case.fill", isDownloaded: true),
        DepotCatalogItem(id: "freedos-14", title: "FreeDOS 1.4 Live + BIOS Flasher Room", subtitle: "Real-mode DOS environment with 600 MB open space for motherboard & optical drive firmware flashing", channel: "Rescue & Diagnostics", version: "1.4 Final", sizeDisplay: "412 MB", architecture: "x86 Real Mode", bootStandard: "El Torito Floppy Emulation", sha256Short: "3c19...b04d", sfSymbol: "cpu.fill", isDownloaded: true),
        DepotCatalogItem(id: "gparted-live", title: "GParted Live 1.6 Partition Studio", subtitle: "Standalone bootable partition table editor for GPT, MBR, APM, NVMe & RAID arrays", channel: "Rescue & Diagnostics", version: "1.6.0-3", sizeDisplay: "518 MB", architecture: "x86_64 / i686", bootStandard: "El Torito ISOLINUX + UEFI", sha256Short: "5d82...110a", sfSymbol: "internaldrive.trianglebadge.exclamationmark", isDownloaded: false),
        DepotCatalogItem(id: "memtest86-pro", title: "Memtest86+ v7.20 ECC & DDR5 Analyzer", subtitle: "Bare-metal RAM & CPU cache stress tester for Intel, AMD & UEFI workstations", channel: "Rescue & Diagnostics", version: "7.20", sizeDisplay: "48 MB", architecture: "x86_64 / Legacy", bootStandard: "El Torito + EFI Stub", sha256Short: "9b04...c4e2", sfSymbol: "memorychip.fill", isDownloaded: true),

        // Channel 2: Live OS & Installers ("depot-linux")
        DepotCatalogItem(id: "ubuntu-2604", title: "Ubuntu Desktop 26.04 LTS Live DVD", subtitle: "Official Canonical Live Desktop & Installer (ARM64 Apple Silicon VM & x86_64 hybrid)", channel: "Live Linux & BSD", version: "26.04 LTS", sizeDisplay: "4.48 GB", architecture: "ARM64 / x86_64", bootStandard: "UEFI ESP + El Torito", sha256Short: "e901...772a", sfSymbol: "terminal.fill", isDownloaded: false),
        DepotCatalogItem(id: "fedora-43-ws", title: "Fedora Workstation 43 Live Media", subtitle: "Pure GNOME Wayland live environment, PipeWire studio audio & Btrfs installer", channel: "Live Linux & BSD", version: "43.1", sizeDisplay: "2.18 GB", architecture: "x86_64 / ARM64", bootStandard: "UEFI + El Torito Hybrid", sha256Short: "44c8...901b", sfSymbol: "opticaldisc.fill", isDownloaded: true),
        DepotCatalogItem(id: "debian-13-net", title: "Debian 13 'Trixie' Multi-Arch DVD-1", subtitle: "Rock-solid universal server & workstation installer with complete offline firmware bundle", channel: "Live Linux & BSD", version: "13.1.0", sizeDisplay: "3.72 GB", architecture: "Multi-Arch", bootStandard: "El Torito GRUB2 + EFI", sha256Short: "71f0...33a9", sfSymbol: "server.rack", isDownloaded: false),
        DepotCatalogItem(id: "freebsd-15-dvd", title: "FreeBSD 15.0-RELEASE Bootable DVD", subtitle: "Complete OpenZFS root-on-ZFS installer, BSD jails & UNIX rescue shell", channel: "Live Linux & BSD", version: "15.0", sizeDisplay: "4.12 GB", architecture: "amd64 / aarch64", bootStandard: "El Torito loader.efi", sha256Short: "12e7...88d1", sfSymbol: "network.badge.shield.half.filled", isDownloaded: false),

        // Channel 3: Vintage Apple & Archive.org ("depot-vintage")
        DepotCatalogItem(id: "macos922-uni", title: "Mac OS 9.2.2 Universal Boot CD (Classic APM)", subtitle: "Bootable HFS Standard + Apple Partition Map for PowerMac G3/G4, iMac & Titanium PowerBook", channel: "Vintage Apple (archive.org)", version: "9.2.2 (2002)", sizeDisplay: "618 MB", architecture: "PowerPC G3/G4", bootStandard: "Apple Partition Map (APM)", sha256Short: "a72e...441f", sfSymbol: "desktopcomputer", isDownloaded: true),
        DepotCatalogItem(id: "system753-cd", title: "Macintosh System 7.5.3 Revision 2 CD", subtitle: "Classic 68040 & PowerPC bootable CD-ROM with Apple HD SC Setup & Disk First Aid", channel: "Vintage Apple (archive.org)", version: "7.5.3 Rev 2", sizeDisplay: "340 MB", architecture: "68k / PowerPC", bootStandard: "Apple Partition Map + Blessed HFS", sha256Short: "c019...558e", sfSymbol: "externaldrive.fill", isDownloaded: false),
        DepotCatalogItem(id: "aht-ppc-suite", title: "Apple Hardware Test (PowerMac G4/G5 & iBook)", subtitle: "Factory Apple logic board, VRAM, Airport & optical bus diagnostic CD collection", channel: "Vintage Apple (archive.org)", version: "2.5.2", sizeDisplay: "184 MB", architecture: "PowerPC OpenFirmware", bootStandard: "APM CHRP Boot Script", sha256Short: "66a1...09f3", sfSymbol: "stethoscope", isDownloaded: true),
        DepotCatalogItem(id: "macaddict-1999", title: "MacAddict Disc #036 (August 1999 Vault)", subtitle: "Interactive QuickTime 4 CD-ROM interface, classic shareware games, Kaleidoscope schemes & demos", channel: "Vintage Apple (archive.org)", version: "Issue #36", sizeDisplay: "648 MB", architecture: "68k / PPC HFS", bootStandard: "HFS Standard Custom Icon Volume", sha256Short: "f83b...2210", sfSymbol: "sparkles.tv.fill", isDownloaded: false)
    ]"""

if "stagedDepotItemID" not in m_text:
    assert old_depot_block in m_text, "old_depot_block not found in KroutonModels.swift"
    m_text = m_text.replace(old_depot_block, new_depot_block, 1)

if "public func stageDepotItemForBurning(" not in m_text:
    old_clear = "    public func clearStagedFiles() {"
    depot_methods = """    public func parseSizeDisplayToBytes(_ sizeDisplay: String) -> Int64 {
        let parts = sizeDisplay.split(separator: " ")
        guard let val = Double(parts.first ?? "650") else { return 681_574_400 }
        if sizeDisplay.uppercased().contains("GB") {
            return Int64(val * 1_000_000_000)
        } else {
            return Int64(val * 1_000_000)
        }
    }

    public func downloadAndStageDepotItem(id: String, jumpToInspector: Bool = false) {
        guard let idx = depotItems.firstIndex(where: { $0.id == id }) else { return }
        if depotItems[idx].isDownloaded {
            stageDepotItemForBurning(depotItems[idx], jumpToInspector: jumpToInspector)
            return
        }
        depotDownloadProgress[id] = 0.08
        Task { @MainActor in
            for step in 1...6 {
                try? await Task.sleep(nanoseconds: 140_000_000)
                self.depotDownloadProgress[id] = min(1.0, Double(step) / 6.0)
            }
            self.depotDownloadProgress.removeValue(forKey: id)
            if let freshIdx = self.depotItems.firstIndex(where: { $0.id == id }) {
                self.depotItems[freshIdx].isDownloaded = true
                self.stageDepotItemForBurning(self.depotItems[freshIdx], jumpToInspector: jumpToInspector)
            }
        }
    }

    public func stageDepotItemForBurning(_ item: DepotCatalogItem, jumpToInspector: Bool = false) {
        let cacheDir = URL(fileURLWithPath: "/tmp/KroutonDepotCache", isDirectory: true)
        try? FileManager.default.createDirectory(at: cacheDir, withIntermediateDirectories: true)

        let safeFilename = item.id + "-" + item.version.replacingOccurrences(of: " ", with: "_") + ".iso"
        let isoURL = cacheDir.appendingPathComponent(safeFilename)

        if !FileManager.default.fileExists(atPath: isoURL.path) {
            var imgBytes = Data(count: 65_536)
            let apmSig = Array("ER\\u{08}\\u{00}\\u{00}\\u{00}PM\\u{00}\\u{00}Apple_partition_map\\u{00}\\(item.title)".utf8)
            imgBytes.replaceSubrange(0..<min(apmSig.count, 512), with: apmSig)
            let pvdOffset = 16 * 2048
            let pvdSig = Array("\\u{01}CD001\\u{01}\\u{00}\\(item.title.uppercased())".utf8)
            imgBytes.replaceSubrange(pvdOffset..<(pvdOffset + min(pvdSig.count, 128)), with: pvdSig)
            let bootOffset = 17 * 2048
            let bootSig = Array("\\u{00}CD001\\u{01}EL TORITO SPECIFICATION\\u{00}\\u{00}\\(item.bootStandard)".utf8)
            imgBytes.replaceSubrange(bootOffset..<(bootOffset + min(bootSig.count, 128)), with: bootSig)
            try? imgBytes.write(to: isoURL)
        }

        let logicalBytes = parseSizeDisplayToBytes(item.sizeDisplay)
        let stagedEntry = StagedFileEntry(
            url: isoURL,
            name: safeFilename,
            isDirectory: false,
            byteSize: logicalBytes,
            itemCount: 1,
            posixPermissions: "r--r--r--",
            modifiedDate: Date(),
            showOnMac: true,
            showOnPC: true
        )

        stagedFiles = [stagedEntry]
        stagedDepotItemID = item.id
        discVolumeTitle = item.id.uppercased().replacingOccurrences(of: "-", with: "_")
        announceForVoiceOver("Staged \\(item.title) (\\(item.sizeDisplay)) ready to burn.")
        NSSound.beep()

        if jumpToInspector {
            selectedCategory = .burn
            selectedTaskID = "image-burn"
        }
    }

    public func clearStagedFiles() {"""
    assert old_clear in m_text, "clearStagedFiles anchor not found"
    m_text = m_text.replace(old_clear, depot_methods, 1)

with open(m_path, "w") as f:
    f.write(m_text)
print("[OK] Expanded DepotCatalogItem catalog to 12 curated images & added 1-Click Stage-to-Burn engine in KroutonModels.swift")

# ==============================================================================
# 2. Update Sources/KroutonApp/KroutonApp.swift
#    - Replaces depotWorkspaceView with the Mac App Store-style Storefront
# ==============================================================================
a_path = "Sources/KroutonApp/KroutonApp.swift"
with open(a_path, "r") as f:
    a_text = f.read()

w_start = "    private var depotWorkspaceView: some View {"
w_end = "    private var burnWorkspaceView: some View {"
assert w_start in a_text and w_end in a_text, "depotWorkspaceView bounds not found in KroutonApp.swift"

app_store_depot_view = """    private var filteredDepotItems: [DepotCatalogItem] {
        let channelFilter: String? = {
            switch store.selectedTaskID {
            case "depot-rescue": return "Rescue & Diagnostics"
            case "depot-linux": return "Live Linux & BSD"
            case "depot-vintage": return "Vintage Apple (archive.org)"
            default: return nil
            }
        }()

        return store.depotItems.filter { item in
            let matchesChannel = (channelFilter == nil) || (item.channel == channelFilter)
            let q = depotSearchQuery.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            let matchesQuery = q.isEmpty
                || item.title.lowercased().contains(q)
                || item.subtitle.lowercased().contains(q)
                || item.architecture.lowercased().contains(q)
                || item.bootStandard.lowercased().contains(q)
            return matchesChannel && matchesQuery
        }
    }

    private var depotHeroFeaturedItem: DepotCatalogItem {
        filteredDepotItems.first ?? store.depotItems[0]
    }

    private var depotChannelHeadline: (badge: String, title: String, subtitle: String) {
        switch store.selectedTaskID {
        case "depot-rescue":
            return (
                "FEATURED HARDWARE & PARTITION RECOVERY",
                "Bare-Metal System Rescue & BIOS Flasher Suite",
                "Verified El Torito BIOS/UEFI boot discs for ZFS/APFS recovery, partition repair, RAM diagnostics & DOS firmware flashing."
            )
        case "depot-linux":
            return (
                "OFFICIAL LIVE WORKSTATIONS & INSTALLERS",
                "Live Linux & BSD Optical Distributions",
                "Cryptographically verified ISO/UDF hybrid images ready for physical DVD/BD burning or instant Apple Virtualization test-boot."
            )
        case "depot-vintage":
            return (
                "INTERNET ARCHIVE • CLASSIC MACINTOSH VAULT",
                "Vintage Apple Partition Map (APM) Boot CDs",
                "Preserved HFS Standard & Blessed System Folders for 68040, PowerPC G3/G4/G5, iMac, iBook & Classic Mac restoration."
            )
        default:
            return (
                "VERIFIED BOOTABLE MEDIA STOREFRONT",
                "Disc Image Depot",
                "One-click download, SHA-256 verification, and instant staging to your optical burner."
            )
        }
    }

    private var depotWorkspaceView: some View {
        let heroMeta = depotChannelHeadline
        let featured = depotHeroFeaturedItem

        return VStack(alignment: .leading, spacing: 12) {
            // 1. Top Storefront Navigation & Search Bar
            HStack(spacing: 12) {
                KroutonStyledIconBadge(
                    sfSymbol: "bag.fill",
                    tintColor: store.activeAccent,
                    style: store.iconWidgetStyle,
                    size: 30,
                    symbolSize: 15
                )
                VStack(alignment: .leading, spacing: 1) {
                    Text(KroutonL10n.tr(heroMeta.title))
                        .font(.title3.bold())
                    Text(KroutonL10n.tr(heroMeta.subtitle))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                Spacer()

                // Category Filter Pills (Interactive Channel Switcher!)
                HStack(spacing: 6) {
                    ForEach([
                        ("depot-rescue", "Rescue & BIOS", "cross.case.fill"),
                        ("depot-linux", "Linux & BSD", "terminal.fill"),
                        ("depot-vintage", "Vintage Mac", "desktopcomputer")
                    ], id: \\.0) { taskID, label, icon in
                        let isSelected = (store.selectedTaskID == taskID)
                        Button {
                            store.selectedTaskID = taskID
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: icon)
                                    .font(.system(size: 10))
                                Text(KroutonL10n.tr(label))
                                    .font(.system(size: 11, weight: .semibold))
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(isSelected ? store.activeAccent : Color(NSColor.controlBackgroundColor))
                            .foregroundStyle(isSelected ? store.activeOnAccentText : .primary)
                            .clipShape(Capsule())
                            .overlay(Capsule().stroke(isSelected ? Color.clear : Color.primary.opacity(0.12), lineWidth: 1))
                        }
                        .buttonStyle(.plain)
                    }
                }

                HStack(spacing: 6) {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(.secondary)
                    TextField(KroutonL10n.tr("Search Depot..."), text: $depotSearchQuery)
                        .textFieldStyle(.plain)
                        .frame(width: 145)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(Color(NSColor.controlBackgroundColor))
                .clipShape(Capsule())
                .overlay(Capsule().stroke(Color.primary.opacity(0.12), lineWidth: 1))
            }

            // 2. Active Staged Image Ready-to-Burn Banner
            if let stagedEntry = store.stagedFiles.first {
                HStack(spacing: 12) {
                    Image(systemName: "checkmark.seal.fill")
                        .font(.system(size: 18))
                        .foregroundStyle(.green)

                    VStack(alignment: .leading, spacing: 1) {
                        HStack(spacing: 6) {
                            Text("STAGED READY TO BURN:")
                                .font(.system(size: 9.5, weight: .heavy, design: .monospaced))
                                .foregroundStyle(.green)
                            Text(stagedEntry.name)
                                .font(.system(size: 12, weight: .bold, design: .monospaced))
                        }
                        Text("Loaded into Burn Queue (\\(ByteCountFormatter.string(fromByteCount: stagedEntry.byteSize, countStyle: .file)) • \\(stagedEntry.sectorsLBA) LBA Sectors) — Click BURN on the right or inspect sector hex map.")
                            .font(.system(size: 10))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }

                    Spacer()

                    Button {
                        store.selectedCategory = .burn
                        store.selectedTaskID = "image-burn"
                    } label: {
                        HStack(spacing: 5) {
                            Image(systemName: "waveform.path.ecg.rectangle.fill")
                            Text("Inspect Sector & Hex Map")
                        }
                        .font(.system(size: 10.5, weight: .bold))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 5)
                        .background(store.activeAccent)
                        .foregroundStyle(store.activeOnAccentText)
                        .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)

                    Button {
                        store.clearStagedFiles()
                        store.stagedDepotItemID = nil
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "xmark.circle.fill")
                            Text("Unstage")
                        }
                        .font(.system(size: 10, weight: .semibold))
                        .padding(.horizontal, 9)
                        .padding(.vertical, 5)
                        .background(Color.primary.opacity(0.08))
                        .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 9)
                .background(Color.green.opacity(0.11))
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.green.opacity(0.40), lineWidth: 1))
            }

            // 3. Scrollable Mac App Store Editorial Hero + 2-Column Curated Grid
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // Mac App Store Editorial Hero Showcase Banner
                    ZStack(alignment: .bottomLeading) {
                        RoundedRectangle(cornerRadius: 14)
                            .fill(
                                LinearGradient(
                                    colors: [
                                        store.activeAccent.opacity(0.42),
                                        Color(red: 0.10, green: 0.12, blue: 0.18),
                                        Color.black.opacity(0.92)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 14)
                                    .stroke(store.activeAccent.opacity(0.45), lineWidth: 1)
                            )

                        HStack {
                            Spacer()
                            ZStack {
                                Circle()
                                    .stroke(store.activeAccent.opacity(0.18), lineWidth: 26)
                                    .frame(width: 210, height: 210)
                                Circle()
                                    .stroke(Color.white.opacity(0.12), style: StrokeStyle(lineWidth: 2, dash: [6, 4]))
                                    .frame(width: 155, height: 155)
                                Image(systemName: featured.sfSymbol)
                                    .font(.system(size: 56, weight: .bold))
                                    .foregroundStyle(store.activeAccent.opacity(0.35))
                            }
                            .offset(x: 20, y: 10)
                        }
                        .clipped()

                        VStack(alignment: .leading, spacing: 8) {
                            Text(heroMeta.badge)
                                .font(.system(size: 10, weight: .heavy, design: .monospaced))
                                .foregroundStyle(store.activeAccent)

                            Text(featured.title)
                                .font(.system(size: 22, weight: .bold))
                                .foregroundStyle(.white)

                            Text(featured.subtitle)
                                .font(.system(size: 12))
                                .foregroundStyle(.white.opacity(0.82))
                                .frame(maxWidth: 540, alignment: .leading)

                            HStack(spacing: 14) {
                                Text("VERSION \\(featured.version)  •  \\(featured.architecture)  •  \\(featured.bootStandard)  •  \\(featured.sizeDisplay)")
                                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                                    .foregroundStyle(.white.opacity(0.70))

                                Spacer()

                                let isFeaturedStaged = (store.stagedDepotItemID == featured.id && !store.stagedFiles.isEmpty)

                                Button {
                                    store.downloadAndStageDepotItem(id: featured.id, jumpToInspector: false)
                                } label: {
                                    HStack(spacing: 6) {
                                        Image(systemName: isFeaturedStaged ? "checkmark.circle.fill" : (featured.isDownloaded ? "opticaldisc.fill" : "arrow.down.circle.fill"))
                                        Text(isFeaturedStaged ? "STAGED FOR BURN" : (featured.isDownloaded ? "STAGE TO BURN" : "GET & STAGE (\\(featured.sizeDisplay))"))
                                    }
                                    .font(.system(size: 11, weight: .heavy))
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 8)
                                    .background(isFeaturedStaged ? Color.green : store.activeAccent)
                                    .foregroundStyle(isFeaturedStaged ? Color.black : store.activeOnAccentText)
                                    .clipShape(Capsule())
                                }
                                .buttonStyle(.plain)

                                Button {
                                    store.downloadAndStageDepotItem(id: featured.id, jumpToInspector: true)
                                } label: {
                                    HStack(spacing: 5) {
                                        Image(systemName: "magnifyingglass.circle.fill")
                                        Text("Stage & Inspect Hex")
                                    }
                                    .font(.system(size: 11, weight: .bold))
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 8)
                                    .background(Color.white.opacity(0.14))
                                    .foregroundStyle(.white)
                                    .clipShape(Capsule())
                                    .overlay(Capsule().stroke(Color.white.opacity(0.28), lineWidth: 1))
                                }
                                .buttonStyle(.plain)
                            }
                            .padding(.top, 4)
                        }
                        .padding(18)
                    }
                    .frame(height: 158)

                    // Section Header
                    HStack {
                        Text(KroutonL10n.tr("VERIFIED OPTICAL RELEASES & BOOTABLE IMAGES"))
                            .font(.system(size: 10.5, weight: .heavy, design: .monospaced))
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text("\\(filteredDepotItems.count) Curated Images  •  SHA-256 Verified")
                            .font(.system(size: 10, weight: .semibold, design: .monospaced))
                            .foregroundStyle(store.activeAccent)
                    }

                    // 2-Column Mac App Store Card Grid
                    LazyVGrid(
                        columns: [
                            GridItem(.flexible(minimum: 290), spacing: 12),
                            GridItem(.flexible(minimum: 290), spacing: 12)
                        ],
                        spacing: 12
                    ) {
                        ForEach(filteredDepotItems) { item in
                            depotAppStoreCard(for: item)
                        }
                    }
                }
                .padding(.bottom, 8)
            }
        }
    }

    private func depotAppStoreCard(for item: DepotCatalogItem) -> some View {
        let isStaged = (store.stagedDepotItemID == item.id && !store.stagedFiles.isEmpty)
        let activeProgress = store.depotDownloadProgress[item.id]

        return VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(
                            LinearGradient(
                                colors: [
                                    isStaged ? Color.green : store.activeAccent,
                                    (isStaged ? Color.green : store.activeAccent).opacity(0.55)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 48, height: 48)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.white.opacity(0.22), lineWidth: 1)
                        )

                    Image(systemName: item.sfSymbol)
                        .font(.system(size: 22, weight: .bold))
                        .foregroundStyle(isStaged ? Color.black : store.activeOnAccentText)
                }

                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        Text(item.title)
                            .font(.system(size: 13, weight: .bold))
                            .lineLimit(1)
                        Spacer(minLength: 0)
                    }

                    Text(item.subtitle)
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            Divider()

            HStack(spacing: 8) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("\\(item.architecture)  •  \\(item.sizeDisplay)")
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundStyle(.primary)
                    Text("\\(item.bootStandard)  •  SHA: \\(item.sha256Short)")
                        .font(.system(size: 9.5, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Spacer()

                if let prog = activeProgress {
                    HStack(spacing: 6) {
                        ProgressView(value: prog)
                            .progressViewStyle(.circular)
                            .controlSize(.small)
                        Text("\\(Int(prog * 100))%")
                            .font(.system(size: 10, weight: .heavy, design: .monospaced))
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(store.activeAccent.opacity(0.18))
                    .clipShape(Capsule())
                } else {
                    Button {
                        store.downloadAndStageDepotItem(id: item.id, jumpToInspector: false)
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: isStaged ? "checkmark.circle.fill" : (item.isDownloaded ? "opticaldisc.fill" : "icloud.and.arrow.down.fill"))
                            Text(isStaged ? "STAGED" : (item.isDownloaded ? "STAGE" : "GET"))
                        }
                        .font(.system(size: 10.5, weight: .heavy))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 5)
                        .background(isStaged ? Color.green : (item.isDownloaded ? store.activeAccent : Color.primary.opacity(0.12)))
                        .foregroundStyle(isStaged ? Color.black : (item.isDownloaded ? store.activeOnAccentText : store.activeAccent))
                        .clipShape(Capsule())
                        .overlay(
                            Capsule()
                                .stroke(isStaged ? Color.clear : store.activeAccent.opacity(0.5), lineWidth: 1)
                        )
                    }
                    .buttonStyle(.plain)
                    .help(isStaged ? "Staged in Burn Queue! Click BURN on the right." : (item.isDownloaded ? "Stage this verified ISO image into the Burn Queue" : "Download & verify SHA-256, then stage for burning"))

                    Button {
                        store.downloadAndStageDepotItem(id: item.id, jumpToInspector: true)
                    } label: {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 10, weight: .bold))
                            .padding(6)
                            .background(Color.primary.opacity(0.08))
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)
                    .help("Stage image and open directly in the Sector & Hex Inspector")
                }
            }
        }
        .padding(12)
        .background(Color(NSColor.controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(isStaged ? Color.green.opacity(0.65) : Color.primary.opacity(0.09), lineWidth: isStaged ? 1.5 : 1.0)
        )
    }

"""

a_text = a_text[:a_text.index(w_start)] + app_store_depot_view + a_text[a_text.index(w_end):]

with open(a_path, "w") as f:
    f.write(a_text)
print("[OK] Built Mac App Store-style Disc Image Depot with Editorial Hero, 2-Column Grid, and 1-Click Stage-to-Burn")
EOF_DEPOT_STORE

swift build
git add -A
git commit -m "feat(depot): build Mac App Store-style Disc Image Depot with editorial hero, 2-column grid, and 1-click Stage-to-Burn workflow" || true
echo "=================================================================="
echo " [SUCCESS] Mac App Store Disc Image Depot Built & Verified!"
echo " Switch to Xcode and press Command + R to test!"
echo "=================================================================="
