import SwiftUI
import Foundation
import OpticalCore

// MARK: - Static Disc Image Depot Feed Subscriptions & Curated Optical Catalog
public enum KroutonDepotStaticCatalog {
    public static let defaultChannels: [KroutonPantryFeedSubscription] = [
        KroutonPantryFeedSubscription(id: "rescue", name: "System Rescue, Partitioning & Hardware Diagnostics", description: "SystemRescue, GParted Live, Rescuezilla, Memtest86+, FreeDOS 1.4 BIOS Room", itemCount: 14, isEnabled: true, sfSymbol: "cross.case.fill"),
        KroutonPantryFeedSubscription(id: "linux", name: "Live Linux & BSD Official Optical Releases", description: "Ubuntu LTS, Fedora Workstation, Debian Live, Arch, FreeBSD Boot-Only & DVD", itemCount: 28, isEnabled: true, sfSymbol: "terminal.fill"),
        KroutonPantryFeedSubscription(id: "windows", name: "Microsoft Windows & DOS Official ISO API", description: "Direct Microsoft token downloader for Windows 11 (w/ DVD-5 Splitter) & Windows 10", itemCount: 8, isEnabled: true, sfSymbol: "window.ceiling"),
        KroutonPantryFeedSubscription(id: "vintage-mac", name: "Internet Archive — Vintage Apple & Classic Mac OS", description: "Mac OS 9.2.2 Universal, System 7.5.3, Apple Hardware Test, PowerPC Restore Discs", itemCount: 42, isEnabled: true, sfSymbol: "desktopcomputer"),
        KroutonPantryFeedSubscription(id: "shareware", name: "Internet Archive — 90s Cover Discs & Shareware Vault", description: "MacAddict, Macworld, Next Generation, and classic demo CDs", itemCount: 65, isEnabled: false, sfSymbol: "opticaldisc.fill")
    ]

    public static let defaultItems: [KroutonPantryCatalogItem] = [
        // =====================================================================
        // 1. System Rescue & BIOS ("Rescue & Diagnostics" — 10 Titles)
        // =====================================================================
        KroutonPantryCatalogItem(id: "sysrescue-11", title: "SystemRescue 11.03 Live", subtitle: "Complete ZFS/Btrfs/APFS recovery, GParted, ddrescue, TestDisk & network diagnostics", channel: "Rescue & Diagnostics", version: "11.03", sizeDisplay: "854 MB", architecture: "x86_64 / UEFI", bootStandard: "El Torito BIOS + UEFI", sha256Short: "8f4a...e91c", sfSymbol: "cross.case.fill", isDownloaded: true),
        KroutonPantryCatalogItem(id: "gparted-live", title: "GParted Live 1.6 Partition Workspace", subtitle: "Standalone bootable partition table editor for GPT, MBR, APM, NVMe & RAID arrays", channel: "Rescue & Diagnostics", version: "1.6.0-3", sizeDisplay: "518 MB", architecture: "x86_64 / i686", bootStandard: "El Torito ISOLINUX + UEFI", sha256Short: "5d82...110a", sfSymbol: "externaldrive.fill.badge.timemachine", isDownloaded: false),
        KroutonPantryCatalogItem(id: "memtest86-pro", title: "Memtest86+ v7.20 ECC & DDR5 Analyzer", subtitle: "Bare-metal RAM, timings & CPU cache stress tester for Intel, AMD & UEFI workstations", channel: "Rescue & Diagnostics", version: "7.20", sizeDisplay: "48 MB", architecture: "x86_64 / Legacy", bootStandard: "El Torito + EFI Stub", sha256Short: "9b04...c4e2", sfSymbol: "memorychip.fill", isDownloaded: true),
        KroutonPantryCatalogItem(id: "clonezilla-live", title: "Clonezilla Live 3.2.0 Bare-Metal Imager", subtitle: "Bit-for-bit NVMe/SSD/HDD disk cloning, multicast deployment & zstd image compression", channel: "Rescue & Diagnostics", version: "3.2.0-5", sizeDisplay: "426 MB", architecture: "x86_64 / ARM64", bootStandard: "UEFI SecureBoot + BIOS", sha256Short: "2a7c...804f", sfSymbol: "doc.on.doc.fill", isDownloaded: true),
        KroutonPantryCatalogItem(id: "rescuezilla-25", title: "Rescuezilla 2.5.1 GUI Disk Recovery", subtitle: "Point-and-click bare-metal backup, Clonezilla restore & bad-sector file carver", channel: "Rescue & Diagnostics", version: "2.5.1", sizeDisplay: "1.18 GB", architecture: "x86_64 / UEFI", bootStandard: "El Torito GRUB2 + EFI", sha256Short: "61d9...42b1", sfSymbol: "lifepreserver.fill", isDownloaded: false),
        KroutonPantryCatalogItem(id: "supergrub2-disk", title: "Super GRUB2 Disk 2.06s4 Universal Bootloader", subtitle: "Boots stranded Linux, Windows, BSD & macOS partitions when EFI/MBR bootloaders fail", channel: "Rescue & Diagnostics", version: "2.06s4", sizeDisplay: "24 MB", architecture: "i386 / x86_64 / EFI", bootStandard: "Hybrid El Torito + ESP", sha256Short: "0f3e...99a4", sfSymbol: "arrow.triangle.2.circlepath.circle.fill", isDownloaded: true),
        KroutonPantryCatalogItem(id: "refind-boot-cd", title: "rEFInd 0.14.2 Boot Manager Optical Rescue", subtitle: "Graphical UEFI & Mac EFI multi-boot selector for Mac Pro, iMac & triple-boot rigs", channel: "Rescue & Diagnostics", version: "0.14.2", sizeDisplay: "32 MB", architecture: "x86_64 / ARM64 EFI", bootStandard: "UEFI El Torito ESP", sha256Short: "7c11...38d0", sfSymbol: "power.circle.fill", isDownloaded: false),
        KroutonPantryCatalogItem(id: "shredos-nwipe", title: "ShredOS 2026.01 (nwipe DoD / NIST Sanitizer)", subtitle: "Bootable DoD 5220.22-M, Gutmann & PRNG cryptographic drive erasure with PDF certificates", channel: "Rescue & Diagnostics", version: "2026.01", sizeDisplay: "64 MB", architecture: "x86_64", bootStandard: "El Torito BIOS + UEFI", sha256Short: "b48a...117e", sfSymbol: "flame.fill", isDownloaded: false),
        KroutonPantryCatalogItem(id: "ubcd-539", title: "Ultimate Boot CD (UBCD) v5.3.9 Hardware Suite", subtitle: "Over 100 bare-metal acoustic, SMART, CPU, VESA, PCI bus & optical drive diagnostic utilities", channel: "Rescue & Diagnostics", version: "5.3.9", sizeDisplay: "692 MB", architecture: "x86 Real/Protected", bootStandard: "El Torito Syslinux", sha256Short: "4e90...c301", sfSymbol: "wrench.and.screwdriver.fill", isDownloaded: true),
        KroutonPantryCatalogItem(id: "SpinRite-freedos", title: "Optical & SATA Bus SMART Surface Scanner CD", subtitle: "Low-level AHCI/IDE surface refresh, magnetic sector reallocation & ATAPI drive analyzer", channel: "Rescue & Diagnostics", version: "6.1-FreeDOS", sizeDisplay: "112 MB", architecture: "x86 Real Mode", bootStandard: "El Torito Floppy Emulation", sha256Short: "d108...55f2", sfSymbol: "waveform.path.ecg", isDownloaded: false),

        // =====================================================================
        // 2. Live Linux & BSD ("Live Linux & BSD" — 10 Titles)
        // =====================================================================
        KroutonPantryCatalogItem(id: "ubuntu-2604", title: "Ubuntu Desktop 26.04 LTS Live DVD", subtitle: "Official Canonical Live Desktop & Installer (ARM64 Apple Silicon VM & x86_64 hybrid)", channel: "Live Linux & BSD", version: "26.04 LTS", sizeDisplay: "4.48 GB", architecture: "ARM64 / x86_64", bootStandard: "UEFI ESP + El Torito", sha256Short: "e901...772a", sfSymbol: "terminal.fill", isDownloaded: false),
        KroutonPantryCatalogItem(id: "fedora-43-ws", title: "Fedora Workstation 43 Live Media", subtitle: "Pure GNOME Wayland live environment, PipeWire workspace audio & Btrfs installer", channel: "Live Linux & BSD", version: "43.1", sizeDisplay: "2.18 GB", architecture: "x86_64 / ARM64", bootStandard: "UEFI + El Torito Hybrid", sha256Short: "44c8...901b", sfSymbol: "opticaldisc.fill", isDownloaded: true),
        KroutonPantryCatalogItem(id: "debian-13-net", title: "Debian 13 'Trixie' Multi-Arch DVD-1", subtitle: "Rock-solid universal server & workstation installer with complete offline firmware bundle", channel: "Live Linux & BSD", version: "13.1.0", sizeDisplay: "3.72 GB", architecture: "Multi-Arch", bootStandard: "El Torito GRUB2 + EFI", sha256Short: "71f0...33a9", sfSymbol: "server.rack", isDownloaded: false),
        KroutonPantryCatalogItem(id: "freebsd-15-dvd", title: "FreeBSD 15.0-RELEASE Bootable DVD", subtitle: "Complete OpenZFS root-on-ZFS installer, BSD jails & UNIX rescue shell", channel: "Live Linux & BSD", version: "15.0", sizeDisplay: "4.12 GB", architecture: "amd64 / aarch64", bootStandard: "El Torito loader.efi", sha256Short: "12e7...88d1", sfSymbol: "network.badge.shield.half.filled", isDownloaded: false),
        KroutonPantryCatalogItem(id: "archlinux-2026", title: "Arch Linux 2026.11 Baseline Live ISO", subtitle: "Rolling-release kernel 6.14 live environment withiwctl, archinstall & bcachefs tools", channel: "Live Linux & BSD", version: "2026.11.01", sizeDisplay: "1.12 GB", architecture: "x86_64", bootStandard: "systemd-boot UEFI + BIOS", sha256Short: "99a3...04c8", sfSymbol: "chevron.left.forwardslash.chevron.right", isDownloaded: true),
        KroutonPantryCatalogItem(id: "linuxmint-22-cin", title: "Linux Mint 22.1 'Xia' Cinnamon Live DVD", subtitle: "Familiar desktop workstation with flatpak, Timeshift snapshots & multimedia codecs", channel: "Live Linux & BSD", version: "22.1", sizeDisplay: "2.84 GB", architecture: "x86_64", bootStandard: "El Torito ISOLINUX + EFI", sha256Short: "3b21...70e4", sfSymbol: "desktopcomputer", isDownloaded: false),
        KroutonPantryCatalogItem(id: "openbsd-78-cd", title: "OpenBSD 7.8 Official Bootable install78.iso", subtitle: "Security-focused UNIX with pledge/unveil, LibreSSL, pf firewall & clean base system", channel: "Live Linux & BSD", version: "7.8", sizeDisplay: "642 MB", architecture: "amd64 / macppc", bootStandard: "El Torito CDBOOT", sha256Short: "c841...19a0", sfSymbol: "lock.shield.fill", isDownloaded: true),
        KroutonPantryCatalogItem(id: "netbsd-101-uni", title: "NetBSD 10.1 Universal Multi-Platform CD", subtitle: "Of course it runs NetBSD — boots on x86, PowerPC Mac, SPARC, VAX, Amiga & Dreamcast", channel: "Live Linux & BSD", version: "10.1", sizeDisplay: "588 MB", architecture: "54 Architectures", bootStandard: "Multi-Catalog El Torito + APM", sha256Short: "f012...63b7", sfSymbol: "globe", isDownloaded: false),
        KroutonPantryCatalogItem(id: "tails-69-amnesic", title: "Tails 6.9 Amnesic Incognito Live DVD", subtitle: "Zero-trace RAM-only live operating system with Tor routing & LUKS encrypted persistence", channel: "Live Linux & BSD", version: "6.9", sizeDisplay: "1.42 GB", architecture: "x86_64", bootStandard: "El Torito Read-Only Live", sha256Short: "5a9e...881c", sfSymbol: "eye.slash.fill", isDownloaded: false),
        KroutonPantryCatalogItem(id: "alpine-321-ext", title: "Alpine Linux 3.21 Extended Optical ISO", subtitle: "Ultra-fast musl libc & BusyBox live CD-ROM with Podman, Docker, ZFS & KVM packages", channel: "Live Linux & BSD", version: "3.21.2", sizeDisplay: "684 MB", architecture: "x86_64 / aarch64", bootStandard: "El Torito Syslinux + EFI", sha256Short: "11d4...92f0", sfSymbol: "bolt.shield.fill", isDownloaded: true),

        // =====================================================================
        // 3. Vintage Mac & Apple ("Vintage Apple (archive.org)" — 10 Titles)
        // =====================================================================
        KroutonPantryCatalogItem(id: "macos922-uni", title: "Mac OS 9.2.2 Universal Boot CD (Classic APM)", subtitle: "Bootable HFS Standard + Apple Partition Map for PowerMac G3/G4, iMac & Titanium PowerBook", channel: "Vintage Apple (archive.org)", version: "9.2.2 (2002)", sizeDisplay: "618 MB", architecture: "PowerPC G3/G4", bootStandard: "Apple Partition Map (APM)", sha256Short: "a72e...441f", sfSymbol: "desktopcomputer", isDownloaded: true),
        KroutonPantryCatalogItem(id: "system753-cd", title: "Macintosh System 7.5.3 Revision 2 CD", subtitle: "Classic 68040 & PowerPC bootable CD-ROM with Apple HD SC Setup & Disk First Aid", channel: "Vintage Apple (archive.org)", version: "7.5.3 Rev 2", sizeDisplay: "340 MB", architecture: "68k / PowerPC", bootStandard: "Apple Partition Map + Blessed HFS", sha256Short: "c019...558e", sfSymbol: "externaldrive.fill", isDownloaded: false),
        KroutonPantryCatalogItem(id: "aht-ppc-suite", title: "Apple Hardware Test (PowerMac G4/G5 & iBook)", subtitle: "Factory Apple logic board, VRAM, Airport & optical bus diagnostic CD collection", channel: "Vintage Apple (archive.org)", version: "2.5.2", sizeDisplay: "184 MB", architecture: "PowerPC OpenFirmware", bootStandard: "APM CHRP Boot Script", sha256Short: "66a1...09f3", sfSymbol: "stethoscope", isDownloaded: true),
        KroutonPantryCatalogItem(id: "macos86-rom-cd", title: "Mac OS 8.6 Clean Install CD (New World ROM)", subtitle: "Rock-solid Nanokernel release for tray-loading iMac G3, Beige G3 & PowerBook G3 Lombard", channel: "Vintage Apple (archive.org)", version: "8.6 (1999)", sizeDisplay: "542 MB", architecture: "PowerPC G3", bootStandard: "APM + Mac OS ROM 1.4", sha256Short: "81b0...44d2", sfSymbol: "cpu.fill", isDownloaded: false),
        KroutonPantryCatalogItem(id: "system71-univ", title: "Macintosh System 7.1 Universal CD + System Enablers", subtitle: "Complete 68000/020/030/040 bootable HFS CD with QuickTime 1.6, HyperCard & TrueType fonts", channel: "Vintage Apple (archive.org)", version: "7.1 Pro", sizeDisplay: "265 MB", architecture: "Motorola 680x0", bootStandard: "APM + Blessed System Folder", sha256Short: "39e1...77c5", sfSymbol: "internaldrive", isDownloaded: true),
        KroutonPantryCatalogItem(id: "mklinux-dr3-ppc", title: "MkLinux DR3 (Apple / OSF Mach Microkernel Linux)", subtitle: "Historic Apple-sponsored Linux on Mach 3.0 microkernel for NuBus & PCI Power Macintosh", channel: "Vintage Apple (archive.org)", version: "DR3 (1998)", sizeDisplay: "638 MB", architecture: "PowerPC 601/604", bootStandard: "HFS + Mach Boot Extension", sha256Short: "52c8...901a", sfSymbol: "terminal", isDownloaded: false),
        KroutonPantryCatalogItem(id: "au-x-311-aws", title: "Apple A/UX 3.1.1 UNIX System V Release 2 CD", subtitle: "Apple's classic hybrid UNIX + Macintosh Finder environment for Quadra & SE/30", channel: "Vintage Apple (archive.org)", version: "3.1.1 (1995)", sizeDisplay: "490 MB", architecture: "68030 / 68040 + FPU", bootStandard: "APM + A/UX Slice Table", sha256Short: "e401...12b8", sfSymbol: "server.rack", isDownloaded: false),
        KroutonPantryCatalogItem(id: "rhapsody-dr2-ppc", title: "Apple Rhapsody DR2 (OS X Server 1.0 Precursor)", subtitle: "NeXTSTEP / OPENSTEP Platinum UI fusion with Yellow Box & Blue Box for Power Macintosh", channel: "Vintage Apple (archive.org)", version: "DR2 (1998)", sizeDisplay: "612 MB", architecture: "PowerPC / x86", bootStandard: "APM + UFS Bootx", sha256Short: "90f4...33e1", sfSymbol: "cube.box.fill", isDownloaded: false),
        KroutonPantryCatalogItem(id: "apple-dev-cd-97", title: "Apple Developer Connection (ADC) Reference Library CD", subtitle: "Inside Macintosh PDFs, CodeWarrior MPW tools, ResEdit 2.1.3, MacsBug & QuickDraw 3D SDK", channel: "Vintage Apple (archive.org)", version: "May 1997", sizeDisplay: "644 MB", architecture: "68k / PowerPC", bootStandard: "HFS Standard Volume", sha256Short: "17a9...66d0", sfSymbol: "hammer.fill", isDownloaded: true),
        KroutonPantryCatalogItem(id: "apple-iigs-sys6", title: "Apple IIgs System 6.0.4 High-Speed SCSI CD-ROM", subtitle: "ProDOS 16 / GS/OS HFS & High Sierra CD-ROM image for Apple IIgs with Apple II SCSI Card", channel: "Vintage Apple (archive.org)", version: "6.0.4", sizeDisplay: "148 MB", architecture: "65C816 16-Bit", bootStandard: "ProDOS / HFS Hybrid Partition", sha256Short: "44b2...08c9", sfSymbol: "keyboard.fill", isDownloaded: false),

        // =====================================================================
        // 4. Console Homebrew & Boot ROMs ("Console Homebrew & ROMs" — 10 Titles)
        // =====================================================================
        KroutonPantryCatalogItem(id: "swiss-gc-boot", title: "Swiss v0.6r1780 Bootable Mini-DVD (GameCube)", subtitle: "Official GameCube & QOOB/XenoGC optical boot Swiss army knife, 480p/576p force & SD/SP2 loader", channel: "Console Homebrew & ROMs", version: "v0.6r1780", sizeDisplay: "1.46 GB (80mm)", architecture: "IBM Gekko PPC", bootStandard: "DOL-006 Apploader + 32KB ECC", sha256Short: "d41e...882b", sfSymbol: "gamecontroller.fill", isDownloaded: true),
        KroutonPantryCatalogItem(id: "freedvdboot-ps2", title: "FreeDVDBoot + uLaunchELF / OPL Master DVD (PS2)", subtitle: "Self-booting PlayStation 2 DVD-Video exploit disc — boots homebrew & diagnostics on unmodded PS2 Slim/Fat", channel: "Console Homebrew & ROMs", version: "3.10 Hybrid", sizeDisplay: "4.37 GB", architecture: "MIPS R5900 EE", bootStandard: "UDF 1.02 + VIDEO_TS Exploit", sha256Short: "77a0...19c4", sfSymbol: "opticaldisc.fill", isDownloaded: true),
        KroutonPantryCatalogItem(id: "unirom-ps1-cd", title: "UniROM 8.0.K + Tonyhax International Boot CD (PS1)", subtitle: "Bootable PS1 CD-ROM XA utility suite, memory card manager, region-free loader & hardware debugger", channel: "Console Homebrew & ROMs", version: "8.0.K", sizeDisplay: "650 MB", architecture: "MIPS R3000A", bootStandard: "Mode 2 Form 1/2 + SubQ", sha256Short: "19f3...60a8", sfSymbol: "cpu", isDownloaded: false),
        KroutonPantryCatalogItem(id: "240p-test-suite", title: "240p Test Suite Multi-Console Optical Bundle (DC / PS1 / PCE / SCD)", subtitle: "Artemio Urbina CRT geometry, lag, linearity, PVM/BVM calibration & audio sync test suite on CD-R", channel: "Console Homebrew & ROMs", version: "2.04 Master", sizeDisplay: "540 MB", architecture: "SH-4 / MIPS / 68k", bootStandard: "MIL-CD / Mode 1 + Audio Tracks", sha256Short: "88c2...4e10", sfSymbol: "tv.and.mediabox", isDownloaded: true),
        KroutonPantryCatalogItem(id: "dreamshell-rc4", title: "DreamShell 4.0 RC4 + Dreamsky Boot CD (Dreamcast)", subtitle: "Self-booting Sega Dreamcast MIL-CD operating system, GD-ROM ripper, BIOS flasher & SD loader", channel: "Console Homebrew & ROMs", version: "4.0 RC4", sizeDisplay: "680 MB", architecture: "Hitachi SH-4", bootStandard: "MIL-CD Multi-Session IP.BIN", sha256Short: "2c91...74e5", sfSymbol: "hurricane", isDownloaded: true),
        KroutonPantryCatalogItem(id: "pseudo-saturn-kai", title: "Pseudo Saturn Kai v6.545 All-in-One Boot CD (Saturn)", subtitle: "Sega Saturn cartridge flasher, save data manager, cheat engine & homebrew CD-R loader", channel: "Console Homebrew & ROMs", version: "v6.545", sizeDisplay: "512 MB", architecture: "Dual Hitachi SH-2", bootStandard: "Saturn System Area Ring", sha256Short: "63a0...11d8", sfSymbol: "circle.grid.cross.fill", isDownloaded: false),
        KroutonPantryCatalogItem(id: "gc-memory-mgr", title: "GCMM 1.5 + CleanRip Optical Verification Disc (GC / Wii)", subtitle: "GameCube & Wii raw memory card `.gci`/`.raw` backup utility and Redump CRC32/SHA-1 optical verifier", channel: "Console Homebrew & ROMs", version: "1.5.2", sizeDisplay: "1.46 GB (80mm)", architecture: "Gekko / Broadway PPC", bootStandard: "DOL-006 / RVL-006 Boot", sha256Short: "09e4...52b3", sfSymbol: "sdcard.fill", isDownloaded: false),
        KroutonPantryCatalogItem(id: "ps2-rom-diag", title: "PS2 RDRAM, Mechacon Laser & Controller Diagnostic DVD", subtitle: "Tests Sony PlayStation 2 Emotion Engine, Graphics Synthesizer, DualShock 2 pressure & Mechacon EEPROM", channel: "Console Homebrew & ROMs", version: "2.4 Pro", sizeDisplay: "1.12 GB", architecture: "MIPS R5900 EE", bootStandard: "UDF 1.02 + FreeDVDBoot", sha256Short: "a18c...9902", sfSymbol: "waveform.badge.magnifyingglass", isDownloaded: false),
        KroutonPantryCatalogItem(id: "dc-indie-showcase", title: "Dreamcast Indie Homebrew & VMU Game Anthology CD", subtitle: "Curated collection of open-source KallistiOS 3D homebrew games, chiptune players & VMU mini-games", channel: "Console Homebrew & ROMs", version: "2026 Ed.", sizeDisplay: "700 MB", architecture: "Hitachi SH-4", bootStandard: "2,352B Mode 2 XA MIL-CD", sha256Short: "74f2...30c1", sfSymbol: "ArcadeStick", isDownloaded: false),
        KroutonPantryCatalogItem(id: "og-xbox-heinz", title: "OG Xbox OpenXDK Hardware & XDVDFS Test Disc", subtitle: "Legal OpenXDK diagnostic suite for Original Xbox MCPX, NV2A GPU, HDD SMART & DVD Thompson/Philips drives", channel: "Console Homebrew & ROMs", version: "1.9 XISO", sizeDisplay: "820 MB", architecture: "Pentium III Coppermine", bootStandard: "XDVDFS default.xbe", sha256Short: "e550...81a7", sfSymbol: "xmark.circle.fill", isDownloaded: true),

        // =====================================================================
        // 5. 90s Cover Discs & Demoscene ("Cover Discs & Demoscene" — 10 Titles)
        // =====================================================================
        KroutonPantryCatalogItem(id: "macaddict-1999", title: "MacAddict Disc #036 (August 1999 Vault)", subtitle: "Interactive QuickTime 4 CD-ROM interface, classic shareware games, Kaleidoscope schemes & demos", channel: "Cover Discs & Demoscene", version: "Issue #36", sizeDisplay: "648 MB", architecture: "68k / PPC HFS", bootStandard: "HFS Standard Custom Icon Volume", sha256Short: "f83b...2210", sfSymbol: "sparkles.tv.fill", isDownloaded: true),
        KroutonPantryCatalogItem(id: "pcgamer-1998-06", title: "PC Gamer CD-ROM Issue 5.06 (June 1998 Coconut Monkey)", subtitle: "Classic interactive 3D Gravitation browser, Quake II / Unreal playable demos, patches & total conversions", channel: "Cover Discs & Demoscene", version: "Vol 5 No 6", sizeDisplay: "682 MB", architecture: "Win95/98 / DOS", bootStandard: "ISO9660 + Joliet Autorun", sha256Short: "55b1...7c09", sfSymbol: "sparkles.tv.fill", isDownloaded: false),
        KroutonPantryCatalogItem(id: "sceneorg-demos-cd", title: "Scene.org & Pouët 64k / CD-ROM Demoscene Anthology", subtitle: "Award-winning real-time hardware shader intros, tracker music discs & Assembly/Revision winners", channel: "Cover Discs & Demoscene", version: "2026 Vault", sizeDisplay: "700 MB", architecture: "Multi-Platform", bootStandard: "Hybrid ISO9660 + Red Book Audio", sha256Short: "e04d...319f", sfSymbol: "waveform.path.ecg.rectangle.fill", isDownloaded: true),
        KroutonPantryCatalogItem(id: "macworld-1996-cd", title: "Macworld Interactive Starware & Ambrosia Showcase CD", subtitle: "Escape Velocity, Maelstrom, Apeiron, Harry the Handsome Executive & Greg's Browser shareware", channel: "Cover Discs & Demoscene", version: "Nov 1996", sizeDisplay: "620 MB", architecture: "68k / PowerPC", bootStandard: "HFS Standard Custom Layout", sha256Short: "30a9...44c2", sfSymbol: "star.circle.fill", isDownloaded: true),
        KroutonPantryCatalogItem(id: "nextgen-mag-1997", title: "Next Generation Magazine Disc #28 (April 1997)", subtitle: "Exclusive 32-bit/64-bit developer video interviews, E3 1997 QuickTime trailers & Saturn/PS1 tech reels", channel: "Cover Discs & Demoscene", version: "Issue #28", sizeDisplay: "660 MB", architecture: "Mac / Win95 Hybrid", bootStandard: "Hybrid HFS + ISO9660", sha256Short: "82d1...19f4", sfSymbol: "film.stack.fill", isDownloaded: false),
        KroutonPantryCatalogItem(id: "amiga-format-cd32", title: "Amiga Format CD #42 (Aminet & OctaMED Soundworkspace)", subtitle: "Hundreds of Amiga AGA demos, MOD/XM tracker modules, LightWave 3D objects & CD32 bootable menu", channel: "Cover Discs & Demoscene", version: "Issue #42", sizeDisplay: "645 MB", architecture: "Motorola 68020/060", bootStandard: "ISO9660 + Rock Ridge + CDTV/CD32", sha256Short: "c190...77a3", sfSymbol: "music.quarternote.3", isDownloaded: false),
        KroutonPantryCatalogItem(id: "cnet-gamecenter-99", title: "CNET Gamecenter & Download.com 1999 Mega-Shareware CD", subtitle: "3dfx Glide / OpenGL benchmarks, Winamp 2.x skins, ICQ utilities & 1999 indie shareware vault", channel: "Cover Discs & Demoscene", version: "Winter 1999", sizeDisplay: "694 MB", architecture: "Win95/98/NT", bootStandard: "ISO9660 + Joliet", sha256Short: "49b2...00e8", sfSymbol: "bolt.horizontal.circle.fill", isDownloaded: false),
        KroutonPantryCatalogItem(id: "assembly-94-04", title: "Assembly '94–'04 Ten-Year Demoscene Optical Time Capsule", subtitle: "Future Crew (Second Reality), Triton, Farbrausch (fr-08 .the .product) & Orange DOS/Win32 demos", channel: "Cover Discs & Demoscene", version: "10th Anniv", sizeDisplay: "698 MB", architecture: "DOS GUS/SB16 + Win32", bootStandard: "El Torito FreeDOS + ISO9660", sha256Short: "91e8...55d0", sfSymbol: "sparkles", isDownloaded: true),
        KroutonPantryCatalogItem(id: "modarchive-tracker", title: "The Mod Archive & HVSC Sidplay Chiptune Audio/Data CD-Extra", subtitle: "Session 1: 60 minutes of mastered Red Book synth tracks; Session 2: 15,000 .MOD/.S3M/.XM/.SID files", channel: "Cover Discs & Demoscene", version: "Vol. 4", sizeDisplay: "700 MB", architecture: "CD-Extra (Blue Book)", bootStandard: "Multi-Session Audio + ISO9660", sha256Short: "67c4...21b9", sfSymbol: "waveform.circle.fill", isDownloaded: false),
        KroutonPantryCatalogItem(id: "hypercard-stacks-95", title: "BMUG (Berkeley Macintosh Users Group) PD-ROM 1995", subtitle: "Over 4,000 HyperCard stacks, After Dark screensaver modules, System 7 extensions & ZTerm BBS tools", channel: "Cover Discs & Demoscene", version: "Fall 1995", sizeDisplay: "635 MB", architecture: "68k / PowerPC HFS", bootStandard: "HFS Standard Volume", sha256Short: "02f7...88a1", sfSymbol: "rectangle.stack.fill", isDownloaded: true),

        // =====================================================================
        // 6. Retro PC, DOS & Alternative OS Vault ("Retro PC & Alt OS" — 10 Titles)
        // =====================================================================
        KroutonPantryCatalogItem(id: "freedos-14", title: "FreeDOS 1.4 Live + BIOS Flasher Room", subtitle: "Real-mode DOS environment with 600 MB open space for motherboard & optical drive firmware flashing", channel: "Retro PC & Alt OS", version: "1.4 Final", sizeDisplay: "412 MB", architecture: "x86 Real Mode", bootStandard: "El Torito Floppy Emulation", sha256Short: "3c19...b04d", sfSymbol: "cpu.fill", isDownloaded: true),
        KroutonPantryCatalogItem(id: "haiku-r1b5-dvd", title: "Haiku OS R1/beta5 Bootable Live Anyboot DVD", subtitle: "Open-source spiritual successor to BeOS with blazing-fast pervasive multithreading & BFS file system", channel: "Retro PC & Alt OS", version: "R1/beta5", sizeDisplay: "1.34 GB", architecture: "x86_64 / i386", bootStandard: "El Torito BIOS + UEFI + BFS", sha256Short: "78a2...19c0", sfSymbol: "leaf.fill", isDownloaded: true),
        KroutonPantryCatalogItem(id: "beos-r5-pe-max", title: "BeOS Release 5 Personal Edition + Max Drivers CD", subtitle: "Legendary 2000 Media OS for dual-Pentium III workstations & PowerPC with real-time audio/video nodes", channel: "Retro PC & Alt OS", version: "R5.0.3", sizeDisplay: "580 MB", architecture: "x86 / PowerPC", bootStandard: "El Torito + Be File System (BFS)", sha256Short: "41d0...66e3", sfSymbol: "slider.horizontal.below.rectangle", isDownloaded: false),
        KroutonPantryCatalogItem(id: "os2-warp4-upd", title: "IBM OS/2 Warp 4.52 (Merlin Convenience Pack 2) CD", subtitle: "32-bit Workplace Shell object-oriented desktop with HPFS/JFS, Win-OS/2 & classic DOS VDM support", channel: "Retro PC & Alt OS", version: "4.52 MCP2", sizeDisplay: "668 MB", architecture: "i386 / Pentium", bootStandard: "El Torito OS/2 Boot Manager", sha256Short: "90c1...44a8", sfSymbol: "window.ceiling", isDownloaded: false),
        KroutonPantryCatalogItem(id: "aros-icaros-dvd", title: "Icaros Desktop 2.3 (AROS AmigaOS 3.1 API Compatible)", subtitle: "Bootable x86 Amiga Research Operating System with Wanderer desktop, Zune MUI & classic UAE integration", channel: "Retro PC & Alt OS", version: "2.3 Live", sizeDisplay: "1.88 GB", architecture: "x86 / x86_64", bootStandard: "El Torito GRUB + SFS", sha256Short: "23f8...09b1", sfSymbol: "checkerboard.rectangle", isDownloaded: false),
        KroutonPantryCatalogItem(id: "reactos-0415-live", title: "ReactOS 0.4.15 Live & Setup CD-ROM", subtitle: "Clean-room open-source Windows NT 5.2 (Server 2003 / XP) binary-compatible operating system", channel: "Retro PC & Alt OS", version: "0.4.15", sizeDisplay: "164 MB", architecture: "i586 / x86_64", bootStandard: "El Torito FreeLoader", sha256Short: "55e2...71c9", sfSymbol: "atom", isDownloaded: true),
        KroutonPantryCatalogItem(id: "kolibrios-asm-cd", title: "KolibriOS 2026 FASM 100% x86 Assembly Live CD", subtitle: "Entire GUI operating system, TCP/IP stack, Doom port & media player written in pure x86 assembly", channel: "Retro PC & Alt OS", version: "0.7.7.0+", sizeDisplay: "38 MB", architecture: "x86 32-Bit ASM", bootStandard: "El Torito 1.44MB Memdisk", sha256Short: "10b4...88e2", sfSymbol: "bird.fill", isDownloaded: true),
        KroutonPantryCatalogItem(id: "templeos-503-iso", title: "TempleOS v5.03 (64-Bit Ring-0 HolyC Live CD)", subtitle: "Terry A. Davis's public-domain 64-bit non-preemptive multi-cored flight simulator & HolyC compiler", channel: "Retro PC & Alt OS", version: "5.03 Final", sizeDisplay: "18 MB", architecture: "x86_64 Ring-0", bootStandard: "El Torito RedSea ISO9660", sha256Short: "f771...00c3", sfSymbol: "sun.max.fill", isDownloaded: false),
        KroutonPantryCatalogItem(id: "plan9-4th-bell", title: "Plan 9 from Bell Labs (9front 'acciaio' Live CD)", subtitle: "Ken Thompson & Rob Pike's distributed UNIX successor where every network & graphics resource is a file", channel: "Retro PC & Alt OS", version: "9front-2026", sizeDisplay: "496 MB", architecture: "amd64 / 386 / arm", bootStandard: "El Torito 9bootiso + hjfs", sha256Short: "68d3...12f0", sfSymbol: "hare.fill", isDownloaded: false),
        KroutonPantryCatalogItem(id: "sgi-irix-65-boot", title: "SGI IRIX 6.5.30 Foundation & EFS Boot Diagnostic CD", subtitle: "Silicon Graphics MIPS PROM bootable Sash/fx disk setup & OpenGL workstation diagnostic media", channel: "Retro PC & Alt OS", version: "6.5.30", sizeDisplay: "640 MB", architecture: "MIPS R4k/R10k/R12k", bootStandard: "SGI Volume Header + EFS/XFS", sha256Short: "c304...99e1", sfSymbol: "cube.transparent.fill", isDownloaded: false)
    ]
}

// MARK: - KroutonPantryCatalogItem CAD Blueprint & Volume Structure Schematic Helpers
extension KroutonPantryCatalogItem {
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
                "/SYSTEM.CNF (BOOT=cdrom:\\MAIN.EXE;1)",
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

