import VideoOven
import Tartine
import Marmalade
//
//  KroutonMasteringWorkspaces.swift
//  Krouton — Optical Media Mastering Studio
//
//  Format-Specific Mastering Workspaces (Data/Archival, Red Book Audio, Video Authoring, Car-Safe Audio, Retro Console ROMs, and Disc Image Inspector).
//

import OpticalDough
import SwiftUI
import UniformTypeIdentifiers
import Foundation
import Combine

extension KroutonMainWorkspaceView {
    func discImageInspectorWorkspace(for spec: KroutonRecipeSpec) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            // Top Mastering Bar
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 10) {
                    Image(systemName: "opticaldisc.fill")
                        .foregroundStyle(store.activeAccent)
                    Text(KroutonL10n.tr("SECTOR-EXACT DISC IMAGE INSPECTOR & BOOTABLE OS BURNER"))
                        .font(.system(size: 10, weight: .heavy, design: .monospaced))
                        .foregroundStyle(.secondary)
                    Spacer()
                    if !imageActionStatusBanner.isEmpty {
                        Text("[ \(imageActionStatusBanner) ]")
                            .font(.system(size: 9.5, weight: .bold, design: .monospaced))
                            .foregroundStyle(store.activeAccent)
                    } else {
                        Text("FORMATS: .ISO • .DMG • .CDR • .BIN/.CUE • .IMG • .TOAST • .NRG • .MDS")
                            .font(.system(size: 9, weight: .bold, design: .monospaced))
                            .foregroundStyle(.secondary)
                    }
                }

                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 14) {
                        Picker(KroutonL10n.tr("Laser Write Topology:"), selection: $discImageWriteMethod) {
                            Text("DAO / SAO Sector-Exact (Preserve System Area & Boot Catalog)").tag("DAO / SAO Sector-Exact (Preserve System Area & Boot Catalog)")
                            Text("RAW DAO/96 (2,352 B/sec + Subchannel PQ/RW Intact)").tag("RAW DAO/96 (2,352 B/sec + Subchannel PQ/RW Intact)")
                            Text("DVD+R / BD-R Seamless Layer Break (16-Sector ECC Aligned)").tag("DVD+R / BD-R Seamless Layer Break (16-Sector ECC Aligned)")
                        }
                        .frame(maxWidth: 420)
                        .font(.caption)

                        Toggle(KroutonL10n.tr("Verify SHA-256 Digest Before Write"), isOn: $verifyImageSHA256BeforeBurn)
                            .toggleStyle(.checkbox)
                            .font(.caption.bold())
                            .lineLimit(1)
                        Spacer(minLength: 0)
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        Picker(KroutonL10n.tr("Write Mode:"), selection: $discImageWriteMethod) {
                            Text("DAO / SAO Sector-Exact (Preserve Boot Catalog)").tag("DAO / SAO Sector-Exact (Preserve System Area & Boot Catalog)")
                            Text("RAW DAO/96 (2,352 B/sec + Subchannel PQ/RW)").tag("RAW DAO/96 (2,352 B/sec + Subchannel PQ/RW Intact)")
                            Text("DVD+R / BD-R Seamless Layer Break (16-Sector ECC)").tag("DVD+R / BD-R Seamless Layer Break (16-Sector ECC Aligned)")
                        }
                        .font(.caption)

                        Toggle(KroutonL10n.tr("Compute & Verify SHA-256 Digest Before Write"), isOn: $verifyImageSHA256BeforeBurn)
                            .toggleStyle(.checkbox)
                            .font(.caption.bold())
                    }
                }
            }
            .padding(10)
            .background(store.enableSecondaryAccentUITints ? store.activeAccent.opacity(0.11) : Color.clear)
            .background(Color.kroutonControlSurface)
            .clipShape(RoundedRectangle(cornerRadius: 9))
            .overlay(RoundedRectangle(cornerRadius: 9).stroke(store.activeAccent.opacity(0.30), lineWidth: 1))

            // Full-Workspace Single Disc Image Deck
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color.kroutonControlSurface)
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .strokeBorder(
                                isDropTargeted ? store.activeAccent : Color.primary.opacity(0.08),
                                style: StrokeStyle(lineWidth: isDropTargeted ? 2.5 : 1.0, dash: store.stagedFiles.isEmpty ? [6, 4] : [])
                            )
                    )

                if let entry = store.stagedFiles.first {
                    let ext = entry.url.pathExtension.lowercased()
                    let isRaw2352 = (ext == "bin" || ext == "cue")
                    let sectorByteSize = isRaw2352 ? 2352 : 2048
                    let bootReadout = entry.bootabilityBadge ?? "Non-Bootable Data Volume (Sectors 0..15 Unbooted)"
                    let hexRows = KroutonLoafBootInspector.readSectorHexDump(url: entry.url, lba: inspectedImageLBA, sectorSize: sectorByteSize)

                    VStack(alignment: .leading, spacing: 12) {
                        // 1. Top Identity Banner + Interactive Action Pill Bar (EVERY pill is a button!)
                        HStack(alignment: .center, spacing: 12) {
                            KroutonStyledIconBadge(
                                sfSymbol: "opticaldisc.fill",
                                tintColor: store.activeAccent,
                                style: store.iconWidgetStyle,
                                size: 38,
                                symbolSize: 20
                            )

                            VStack(alignment: .leading, spacing: 2) {
                                HStack(spacing: 8) {
                                    Text(entry.name)
                                        .font(.system(size: 16, weight: .bold, design: .monospaced))
                                        .lineLimit(1)
                                    Text("[ \(ext.uppercased()) VOLUME ]")
                                        .font(.system(size: 10, weight: .heavy, design: .monospaced))
                                        .foregroundStyle(store.activeAccent)
                                }
                                Text("\(entry.url.path)  —  \(ByteCountFormatter.string(fromByteCount: entry.byteSize, countStyle: .file)) (\(entry.sectorsLBA) LBA Blocks @ \(sectorByteSize) B/sec)")
                                    .font(.system(size: 10.5, design: .monospaced))
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                            }

                            Spacer()

                            // Interactive Action Pill Buttons (100% clickable buttons!)
                            HStack(spacing: 7) {
                                if entry.isConvertibleBinOrIso {
                                    Button {
                                        store.convertStagedBinOrIso(id: entry.id)
                                        imageActionStatusBanner = "Converted Sector Framing for \(entry.name)"
                                    } label: {
                                        HStack(spacing: 4) {
                                            Image(systemName: "arrow.left.arrow.right.circle.fill")
                                            Text(entry.conversionTargetLabel)
                                        }
                                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 5)
                                        .background(store.activeAccent)
                                        .foregroundStyle(store.activeOnAccentText)
                                        .clipShape(Capsule())
                                    }
                                    .buttonStyle(.plain)
                                    .help("Convert between 2,352 B/sec Raw .BIN/.CUE and 2,048 B/sec .ISO")
                                }

                                Button {
                                    let hash = KroutonLoafBootInspector.computeSHA256Hex(url: entry.url)
                                    computedImageSHA256 = hash
                                    KroutonOSDesktopBridge.copyTextToClipboard(hash)
                                    imageActionStatusBanner = "SHA-256 Copied to Clipboard"
                                    KroutonOSDesktopBridge.playAcousticCue()
                                } label: {
                                    HStack(spacing: 4) {
                                        Image(systemName: computedImageSHA256.isEmpty ? "checkmark.shield.fill" : "doc.on.clipboard.fill")
                                        Text(computedImageSHA256.isEmpty ? "Compute SHA-256" : "SHA-256: \(computedImageSHA256.prefix(10))… (Copy)")
                                    }
                                    .font(.system(size: 10, weight: .semibold, design: .monospaced))
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 5)
                                    .background(Color.primary.opacity(0.09))
                                    .clipShape(Capsule())
                                    .overlay(Capsule().stroke(store.activeAccent.opacity(0.45), lineWidth: 1))
                                }
                                .buttonStyle(.plain)
                                .help("Compute cryptographic SHA-256 digest of the image file and copy to clipboard")

                                Button {
                                    let proc = Process()
                                    proc.executableURL = URL(fileURLWithPath: "/usr/bin/hdiutil")
                                    proc.arguments = ["attach", entry.url.path]
                                    try? proc.run()
                                    imageActionStatusBanner = "Mounting \(entry.name) via hdiutil..."
                                } label: {
                                    HStack(spacing: 4) {
                                        Image(systemName: "externaldrive.connected.to.line.below.fill")
                                        Text("Mount in Finder")
                                    }
                                    .font(.system(size: 10, weight: .semibold))
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 5)
                                    .background(Color.primary.opacity(0.09))
                                    .clipShape(Capsule())
                                    .overlay(Capsule().stroke(Color.primary.opacity(0.18), lineWidth: 1))
                                }
                                .buttonStyle(.plain)
                                .help("Mount this disc image on the macOS Desktop using hdiutil")

                                Button {
                                    KroutonOSDesktopBridge.revealURLsInFinder([entry.url])
                                } label: {
                                    HStack(spacing: 4) {
                                        Image(systemName: "folder.fill")
                                        Text("Reveal")
                                    }
                                    .font(.system(size: 10, weight: .semibold))
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 5)
                                    .background(Color.primary.opacity(0.09))
                                    .clipShape(Capsule())
                                    .overlay(Capsule().stroke(Color.primary.opacity(0.18), lineWidth: 1))
                                }
                                .buttonStyle(.plain)
                                .help("Reveal disc image file in macOS Finder")
                            }
                        }
                        .padding(.horizontal, 14)
                        .padding(.top, 12)

                        Divider()

                        // 2. Main Engineering Split: Radial Platter Schematic (Left) + Live Sector Hex Scope (Right)
                        HStack(alignment: .top, spacing: 14) {
                            // LEFT COLUMN: Radial Optical Track Map + 2,352B / 2,048B Sector Framing Diagram
                            VStack(alignment: .leading, spacing: 10) {
                                Text("OPTICAL PLATTER & TRACK ZONE TOPOLOGY")
                                    .font(.system(size: 9.5, weight: .heavy, design: .monospaced))
                                    .foregroundStyle(.secondary)

                                ZStack {
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(Color.black.opacity(0.28))
                                        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.primary.opacity(0.10), lineWidth: 1))

                                    VStack(spacing: 10) {
                                        // Concentric Optical Platter Graphic
                                        ZStack {
                                            // Outer Polycarbonate Substrate (120mm)
                                            Circle()
                                                .fill(
                                                    RadialGradient(
                                                        colors: [
                                                            Color.black.opacity(0.9),
                                                            store.activeAccent.opacity(0.28),
                                                            store.uiSecondaryAccent.opacity(0.24),
                                                            store.activeAccent.opacity(0.38),
                                                            Color.black.opacity(0.85)
                                                        ],
                                                        center: .center,
                                                        startRadius: 18,
                                                        endRadius: 92
                                                    )
                                                )
                                                .frame(width: 184, height: 184)
                                                .overlay(Circle().stroke(Color.white.opacity(0.22), lineWidth: 1.5))

                                            // Outer Lead-Out Ring
                                            Circle()
                                                .stroke(store.uiSecondaryAccent.opacity(0.75), style: StrokeStyle(lineWidth: 3, dash: [5, 3]))
                                                .frame(width: 174, height: 174)

                                            // User Data Zone Ring (LBA 32..End)
                                            Circle()
                                                .stroke(store.activeAccent.opacity(0.85), lineWidth: 18)
                                                .frame(width: 136, height: 136)

                                            // Boot Catalog & PVD Ring (LBA 16..31) — Highlights when LBA 16/17 inspected!
                                            Circle()
                                                .stroke(
                                                    (inspectedImageLBA == 16 || inspectedImageLBA == 17) ? Color.green : store.uiSecondaryAccent.opacity(0.85),
                                                    lineWidth: (inspectedImageLBA == 16 || inspectedImageLBA == 17) ? 6 : 4
                                                )
                                                .frame(width: 96, height: 96)

                                            // System Area / Lead-In Ring (LBA 0..15)
                                            Circle()
                                                .stroke(inspectedImageLBA == 0 ? Color.yellow : Color.white.opacity(0.45), lineWidth: 4)
                                                .frame(width: 72, height: 72)

                                            // Clamping Hub & 15mm Spindle Hole
                                            Circle()
                                                .fill(Color.kroutonWindowSurface)
                                                .frame(width: 34, height: 34)
                                                .overlay(Circle().stroke(Color.secondary.opacity(0.5), lineWidth: 1.5))

                                            // Laser Read-Head Crosshair Vector
                                            Path { path in
                                                path.move(to: CGPoint(x: 92, y: 92))
                                                path.addLine(to: CGPoint(x: 168, y: 36))
                                            }
                                            .stroke(Color.green.opacity(0.85), style: StrokeStyle(lineWidth: 1.2, dash: [3, 2]))
                                            .frame(width: 184, height: 184)
                                        }
                                        .padding(.top, 6)

                                        // Platter Zone Legend (Sharp Terminal Readouts — Not Fake Pills)
                                        VStack(alignment: .leading, spacing: 3) {
                                            HStack {
                                                Rectangle().fill(Color.yellow).frame(width: 8, height: 8)
                                                Text("LBA 00..15   : 32 KB System Area / APM / MBR")
                                                Spacer()
                                            }
                                            HStack {
                                                Rectangle().fill(Color.green).frame(width: 8, height: 8)
                                                Text("LBA 16..31   : ISO9660 PVD & El Torito Catalog")
                                                Spacer()
                                            }
                                            HStack {
                                                Rectangle().fill(store.activeAccent).frame(width: 8, height: 8)
                                                Text("LBA 32..\(entry.sectorsLBA) : User Data Extent (\(sectorByteSize) B/sec)")
                                                Spacer()
                                            }
                                            HStack {
                                                Rectangle().fill(store.uiSecondaryAccent).frame(width: 8, height: 8)
                                                Text("LEAD-OUT     : PMA / TOC / Session Closure")
                                                Spacer()
                                            }
                                        }
                                        .font(.system(size: 9.5, weight: .medium, design: .monospaced))
                                        .foregroundStyle(.secondary)
                                        .padding(.horizontal, 12)
                                        .padding(.bottom, 8)
                                    }
                                }

                                // Physical Sector Byte Framing Schematic Bar
                                VStack(alignment: .leading, spacing: 5) {
                                    Text("PHYSICAL SECTOR FRAMING (\(sectorByteSize) BYTES / BLOCK)")
                                        .font(.system(size: 9, weight: .heavy, design: .monospaced))
                                        .foregroundStyle(.secondary)

                                    if isRaw2352 {
                                        HStack(spacing: 2) {
                                            Text("SYNC 12B")
                                                .frame(width: 52, height: 22)
                                                .background(Color.purple.opacity(0.32))
                                            Text("HDR 4B")
                                                .frame(width: 44, height: 22)
                                                .background(Color.cyan.opacity(0.32))
                                            Text("USER PAYLOAD 2,048 B")
                                                .frame(maxWidth: .infinity)
                                                .frame(height: 22)
                                                .background(store.activeAccent.opacity(0.38))
                                            Text("EDC/ECC 288B")
                                                .frame(width: 78, height: 22)
                                                .background(Color.orange.opacity(0.32))
                                        }
                                        .font(KroutonDesign.Typography.microMono)
                                        .clipShape(RoundedRectangle(cornerRadius: 4))
                                    } else {
                                        HStack(spacing: 2) {
                                            Text("HW DRIVE SYNC/HDR (16B)")
                                                .frame(width: 118, height: 22)
                                                .background(Color.secondary.opacity(0.18))
                                                .foregroundStyle(.secondary)
                                            Text("COOKED BLOCK PAYLOAD (2,048 BYTES)")
                                                .frame(maxWidth: .infinity)
                                                .frame(height: 22)
                                                .background(store.activeAccent.opacity(0.38))
                                            Text("HW RSPC ECC (288B)")
                                                .frame(width: 102, height: 22)
                                                .background(Color.secondary.opacity(0.18))
                                                .foregroundStyle(.secondary)
                                        }
                                        .font(KroutonDesign.Typography.microMono)
                                        .clipShape(RoundedRectangle(cornerRadius: 4))
                                    }
                                }
                            }
                            .frame(width: 310)

                            // RIGHT COLUMN: Volume Descriptor Telemetry Grid + Interactive LBA Hex/ASCII Inspector
                            VStack(alignment: .leading, spacing: 10) {
                                // Rectangular Telemetry Matrix (Non-clickable readouts use sharp terminal boxes, never pills!)
                                HStack(spacing: 8) {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("BOOT RECORD SIGNATURE")
                                            .font(KroutonDesign.Typography.microMono)
                                            .foregroundStyle(.secondary)
                                        Text(bootReadout)
                                            .font(KroutonDesign.Typography.telemetryMono)
                                            .foregroundStyle(entry.bootabilityBadge != nil ? .green : .primary)
                                            .lineLimit(1)
                                    }
                                    .padding(8)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .background(ZStack { Color.black.opacity(0.24); store.sidebarTintOverlay })
                                    .overlay(Rectangle().stroke(Color.primary.opacity(0.12), lineWidth: 1))

                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("LOGICAL BLOCKS & ECC")
                                            .font(KroutonDesign.Typography.microMono)
                                            .foregroundStyle(.secondary)
                                        Text("\(entry.sectorsLBA) LBA  |  16-Sec ECC: \(entry.sectorsLBA % 16 == 0 ? "ALIGNED" : "+\(16 - (entry.sectorsLBA % 16)) PAD")")
                                            .font(KroutonDesign.Typography.telemetryMono)
                                            .foregroundStyle(store.activeAccent)
                                            .lineLimit(1)
                                    }
                                    .padding(8)
                                    .frame(width: 235, alignment: .leading)
                                    .background(ZStack { Color.black.opacity(0.24); store.sidebarTintOverlay })
                                    .overlay(Rectangle().stroke(Color.primary.opacity(0.12), lineWidth: 1))
                                }

                                // Interactive Sector Jump Pill Buttons (Every pill jumps the Hex Reader to that LBA!)
                                HStack(spacing: 6) {
                                    Text("JUMP READ HEAD:")
                                        .font(.system(size: 9, weight: .heavy, design: .monospaced))
                                        .foregroundStyle(.secondary)

                                    ForEach([
                                        (0, "LBA 00 • System / APM"),
                                        (16, "LBA 16 • ISO9660 PVD"),
                                        (17, "LBA 17 • El Torito Boot"),
                                        (256, "LBA 256 • UDF Anchor")
                                    ], id: \.0) { lbaTarget, label in
                                        let isCurrentLBA = (inspectedImageLBA == lbaTarget)
                                        Button {
                                            inspectedImageLBA = lbaTarget
                                            imageActionStatusBanner = "Read Head -> LBA \(lbaTarget) (Byte Offset \(String(format: "0x%08X", lbaTarget * sectorByteSize)))"
                                        } label: {
                                            Text(label)
                                                .font(.system(size: 9.5, weight: .bold, design: .monospaced))
                                                .padding(.horizontal, 9)
                                                .padding(.vertical, 4)
                                                .background(isCurrentLBA ? store.activeAccent : Color.primary.opacity(0.08))
                                                .foregroundStyle(isCurrentLBA ? store.activeOnAccentText : .primary)
                                                .clipShape(Capsule())
                                                .overlay(Capsule().stroke(isCurrentLBA ? Color.clear : Color.primary.opacity(0.15), lineWidth: 1))
                                        }
                                        .buttonStyle(.plain)
                                    }
                                    Spacer()
                                }

                                // Live Sector Hexadecimal + ASCII Inspector Terminal
                                VStack(alignment: .leading, spacing: 0) {
                                    HStack {
                                        Text("OFFSET    00 01 02 03 04 05 06 07  08 09 0A 0B 0C 0D 0E 0F   ASCII DECODED")
                                            .font(.system(size: 9.5, weight: .heavy, design: .monospaced))
                                            .foregroundStyle(store.activeAccent)
                                        Spacer()
                                        Text("SECTOR LBA \(inspectedImageLBA)")
                                            .font(.system(size: 9, weight: .bold, design: .monospaced))
                                            .foregroundStyle(.green)
                                    }
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 5)
                                    .background(Color.black.opacity(0.45))

                                    Divider()

                                    ScrollView {
                                        VStack(alignment: .leading, spacing: 2) {
                                            ForEach(hexRows) { hRow in
                                                HStack(spacing: 12) {
                                                    Text(hRow.offsetHex)
                                                        .foregroundStyle(.secondary)
                                                    Text(hRow.hexBytes)
                                                        .foregroundStyle(.primary)
                                                    Text(hRow.asciiText)
                                                        .foregroundStyle(.green)
                                                    Spacer(minLength: 0)
                                                }
                                                .font(.system(size: 10.5, weight: .medium, design: .monospaced))
                                            }
                                        }
                                        .padding(10)
                                    }
                                }
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                                .background(ZStack { Color.black.opacity(0.32); store.sidebarTintOverlay })
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.primary.opacity(0.14), lineWidth: 1))
                            }
                        }
                        .padding(.horizontal, 14)
                        .padding(.bottom, 14)
                    }
                } else {
                    // Empty State: Interactive Drop Zone & Quick Image Picker
                    VStack(spacing: 12) {
                        Image(systemName: "opticaldisc.fill")
                            .font(.system(size: 46))
                            .foregroundStyle(store.uiSecondaryAccent.opacity(0.85))
                        Text(KroutonL10n.tr("Drop a Disc Image (.ISO, .DMG, .BIN/.CUE, .CDR, .IMG, or .TOAST) to Launch the Sector & Hex Inspector"))
                            .font(.headline)
                        Text(KroutonL10n.tr("Displays radial track geometry, live LBA 0/16/17/256 hexadecimal sector dumps, El Torito / APM boot records, and 1-Click .BIN <-> .ISO framing conversion."))
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        Button {
                            promptToAddFiles()
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: "folder.badge.plus")
                                Text("Choose Disc Image File...")
                            }
                            .font(.system(size: 12, weight: .bold))
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(store.activeAccent)
                            .foregroundStyle(store.activeOnAccentText)
                            .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
                        .padding(.top, 4)
                    }
                }
            }
            .onDrop(of: [.fileURL], isTargeted: $isDropTargeted) { providers in
                // When in single-image mode, dropping a new disc image replaces the old one cleanly
                store.clearStagedFiles()
                computedImageSHA256 = ""
                imageActionStatusBanner = ""
                return handleFinderDrop(providers: providers)
            }
        }
    }

    func dataAndArchivalMasteringWorkspace(for activeSpec: KroutonRecipeSpec) -> some View {
        let isUniversalHybrid = (activeSpec.id == "data-hybrid" || activeSpec.id == "mdisc-vault")
        let isAppleOnly = (activeSpec.id == "data-apple-apfs")
        let isRetro83 = (activeSpec.id == "data-retro-iso")

        return VStack(alignment: .leading, spacing: 10) {
            // File System Topology & Universal Compatibility Deck
            VStack(alignment: .leading, spacing: 8) {
                if activeSpec.isMDiscParityFormat {
                    HStack(spacing: 14) {
                        Image(systemName: "lock.shield.fill")
                            .foregroundStyle(store.activeAccent)
                        Text(KroutonL10n.tr("M-DISC INORGANIC ROCK-LAYER VAULT + PAR2 SURFACE PARITY:"))
                            .font(.system(size: 10, weight: .heavy, design: .monospaced))
                            .foregroundStyle(.secondary)
                        Text("PAR2 Redundancy: \(Int(mdiscPar2RedundancyPct))%")
                            .font(.caption.bold())
                            .foregroundStyle(store.activeAccent)
                        Slider(value: $mdiscPar2RedundancyPct, in: 5...30, step: 5)
                            .frame(width: 150)
                        Text(KroutonL10n.tr("• Generates .par2 Reed-Solomon recovery blocks + SHA-256 manifest"))
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundStyle(.secondary)
                        Spacer()
                    }
                    Divider()
                }

                ViewThatFits(in: .horizontal) {
                    // 1. Wide Horizontal Bar
                    HStack(spacing: 12) {
                        HStack(spacing: 6) {
                            Image(systemName: "opticaldisc")
                                .foregroundStyle(store.activeAccent)
                            Text(KroutonL10n.tr("Disc Title:"))
                                .font(.caption.bold())
                                .lineLimit(1)
                            TextField("KROUTON_DISC", text: $store.discVolumeTitle)
                                .textFieldStyle(.roundedBorder)
                                .frame(width: 145)
                        }
                        .fixedSize(horizontal: true, vertical: false)

                        if activeSpec.id == "data-udf-modern" {
                            Label("Pure UDF 2.60 (Files >4 GiB up to 128 GB)", systemImage: "checkmark.seal.fill")
                                .font(.caption.bold())
                                .foregroundStyle(.green)
                                .lineLimit(1)
                        } else if isAppleOnly {
                            Toggle(KroutonL10n.tr("Preserve macOS Extended Attributes (xattr) & Resource Forks"), isOn: $preserveMacExtendedAttributes)
                                .toggleStyle(.checkbox)
                                .font(.caption.bold())
                                .lineLimit(1)
                        } else if isRetro83 {
                            Toggle(KroutonL10n.tr("Enforce Strict 8.3 Uppercase Filenames (DOS / Win95 / System 7)"), isOn: $enforce8Dot3RetroCompatibility)
                                .toggleStyle(.checkbox)
                                .font(.caption.bold())
                                .lineLimit(1)
                        } else {
                            Label("4-Way Universal Bridge (macOS HFS+ • Windows Joliet/UDF • Linux Rock Ridge)", systemImage: "globe")
                                .font(.caption.bold())
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }

                        Spacer(minLength: 4)

                        Button {
                            showTartineLBAMapPopover.toggle()
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "memorychip.fill")
                                Text(KroutonL10n.tr("Tartine LBA Map"))
                            }
                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(store.activeAccent.opacity(0.16))
                            .foregroundStyle(store.activeAccent)
                            .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
                        .popover(isPresented: $showTartineLBAMapPopover, arrowEdge: .bottom) {
                            tartineHybridLBAMapPopoverView(for: activeSpec)
                        }

                        if !isRetro83 {
                            Toggle(KroutonL10n.tr("Customize Finder Layout"), isOn: $enableCustomFinderLayoutTab)
                                .toggleStyle(.checkbox)
                                .font(.caption)
                                .lineLimit(1)
                                .fixedSize(horizontal: true, vertical: false)
                                .onChange(of: enableCustomFinderLayoutTab) { _, enabled in
                                    activeDataWorkspaceTab = enabled ? 1 : 0
                                }
                        }
                    }

                    // 2. Narrow Stacked Fallback (Zero Vertical Word-Towers!)
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(spacing: 8) {
                            Image(systemName: "opticaldisc")
                                .foregroundStyle(store.activeAccent)
                            Text(KroutonL10n.tr("Disc Title:"))
                                .font(.caption.bold())
                                .lineLimit(1)
                            TextField("KROUTON_DISC", text: $store.discVolumeTitle)
                                .textFieldStyle(.roundedBorder)
                                .frame(maxWidth: 180)
                            Spacer()
                            if !isRetro83 {
                                Toggle(KroutonL10n.tr("Finder Layout"), isOn: $enableCustomFinderLayoutTab)
                                    .toggleStyle(.checkbox)
                                    .font(.caption)
                                    .lineLimit(1)
                                    .onChange(of: enableCustomFinderLayoutTab) { _, enabled in
                                        activeDataWorkspaceTab = enabled ? 1 : 0
                                    }
                            }
                        }

                        if activeSpec.id == "data-udf-modern" {
                            Label("Pure UDF 2.60 (Files >4 GiB up to 128 GB)", systemImage: "checkmark.seal.fill")
                                .font(.caption.bold())
                                .foregroundStyle(.green)
                                .lineLimit(1)
                        } else if isAppleOnly {
                            Toggle(KroutonL10n.tr("Preserve macOS xattr & Resource Forks"), isOn: $preserveMacExtendedAttributes)
                                .toggleStyle(.checkbox)
                                .font(.caption.bold())
                                .lineLimit(1)
                        } else if isRetro83 {
                            Toggle(KroutonL10n.tr("Enforce 8.3 Uppercase Filenames"), isOn: $enforce8Dot3RetroCompatibility)
                                .toggleStyle(.checkbox)
                                .font(.caption.bold())
                                .lineLimit(1)
                        } else {
                            Label("4-Way Bridge: macOS (HFS+), Windows (UDF) & Linux (Rock Ridge)", systemImage: "globe")
                                .font(.caption.bold())
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                    }
                }
            }
            .padding(10)
            .background(store.enableSecondaryAccentUITints ? store.activeAccent.opacity(0.11) : Color.clear)
            .background(Color.kroutonControlSurface)
            .clipShape(RoundedRectangle(cornerRadius: 9))
            .overlay(RoundedRectangle(cornerRadius: 9).stroke(store.activeAccent.opacity(0.30), lineWidth: 1))

            if activeDataWorkspaceTab == 1 && enableCustomFinderLayoutTab {
                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 20) {
                        ColorPicker(KroutonL10n.tr("Finder Window Background:"), selection: $finderBgColor)
                        HStack {
                            Text("Icon Size: \(Int(finderIconSize)) px")
                                .font(.caption)
                            Slider(value: $finderIconSize, in: 64...512, step: 32)
                                .frame(width: 160)
                        }
                    }
                    RoundedRectangle(cornerRadius: 12)
                        .fill(finderBgColor)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .overlay(
                            ScrollView {
                                LazyVGrid(columns: [GridItem(.adaptive(minimum: 120))], spacing: 24) {
                                    ForEach(store.stagedFiles) { item in
                                        VStack(spacing: 6) {
                                            Image(systemName: item.isDirectory ? "folder.fill" : "doc.fill")
                                                .font(.system(size: min(finderIconSize * 0.25, 84)))
                                                .foregroundStyle(item.isDirectory ? store.resolvedFolderIconColor : .white)
                                            Text(item.name)
                                                .font(.caption.bold())
                                                .foregroundStyle(.white)
                                                .lineLimit(1)
                                        }
                                    }
                                }
                                .padding(24)
                            }
                        )
                }
            } else {
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color.kroutonControlSurface)
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .strokeBorder(
                                    isDropTargeted ? store.activeAccent : Color.primary.opacity(0.08),
                                    style: StrokeStyle(lineWidth: isDropTargeted ? 2.5 : 1.0, dash: store.stagedFiles.isEmpty ? [6, 4] : [])
                                )
                        )

                    if store.stagedFiles.isEmpty {
                        VStack(spacing: 10) {
                            Image(systemName: "folder.badge.plus")
                                .font(.system(size: 34))
                                .foregroundStyle(store.uiSecondaryAccent.opacity(0.85))
                            Text(KroutonL10n.tr("Drag & Drop Files or Folders Here to Author a New Data Disc"))
                                .font(.headline)
                            Text(isUniversalHybrid
                                 ? KroutonL10n.tr("Shared data extents are linked into HFS+ (Mac), Joliet/UDF (Windows), and Rock Ridge (Linux) simultaneously. Toggle [Mac] / [PC] to hide platform-specific installers.")
                                 : KroutonL10n.tr("Add files and directories from Finder to build the optical volume directory tree."))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    } else {
                        VStack(spacing: 0) {
                            HStack(spacing: 12) {
                                Text(KroutonL10n.tr("ITEM NAME & PATH"))
                                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                                    .foregroundStyle(.secondary)
                                    .padding(.leading, 36)
                                Spacer()
                                if isUniversalHybrid {
                                    Text(KroutonL10n.tr("OS VISIBILITY"))
                                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                                        .foregroundStyle(.secondary)
                                        .frame(width: 112, alignment: .center)
                                }
                                Text(KroutonL10n.tr("SECTORS"))
                                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                                    .foregroundStyle(.secondary)
                                    .frame(width: 86, alignment: .trailing)
                                Text(KroutonL10n.tr("SIZE"))
                                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                                    .foregroundStyle(.secondary)
                                    .frame(width: 72, alignment: .trailing)
                                Spacer().frame(width: 22)
                            }
                            .padding(.horizontal, 14)
                            .padding(.vertical, 6)
                            .background(ZStack { Color.black.opacity(0.18); store.sidebarTintOverlay })
                            Divider()

                            ScrollView {
                                LazyVStack(spacing: 0) {
                                    ForEach(store.stagedFiles) { entry in
                                        HStack(spacing: 12) {
                                            Image(systemName: entry.isDirectory ? "folder.fill" : "doc.fill")
                                                .foregroundStyle(entry.isDirectory ? store.resolvedFolderIconColor : store.activeAccent)
                                                .font(.system(size: 15))
                                                .frame(width: 24)

                                            VStack(alignment: .leading, spacing: 2) {
                                                Text(isRetro83 ? entry.iso9660Level1Name : entry.name)
                                                    .font(.system(size: 12, weight: .semibold, design: isRetro83 ? .monospaced : .default))
                                                Text("\(entry.url.path) • Perms: \(entry.posixPermissions) • \(entry.isDirectory ? "\(entry.itemCount) items inside" : "Single file")")
                                                    .font(.system(size: 10))
                                                    .foregroundStyle(.secondary)
                                                    .lineLimit(1)
                                            }

                                            Spacer()

                                            if isUniversalHybrid {
                                                HStack(spacing: 5) {
                                                    Button {
                                                        store.toggleMacVisibility(id: entry.id)
                                                    } label: {
                                                        HStack(spacing: 3) {
                                                            Image(systemName: "apple.logo")
                                                                .font(.system(size: 9))
                                                            Text(KroutonL10n.tr("Mac"))
                                                                .font(.system(size: 9, weight: .bold))
                                                        }
                                                        .padding(.horizontal, 7)
                                                        .padding(.vertical, 3)
                                                        .background(entry.showOnMac ? store.activeAccent.opacity(0.22) : Color.secondary.opacity(0.10))
                                                        .foregroundStyle(entry.showOnMac ? store.activeAccent : .secondary.opacity(0.55))
                                                        .clipShape(Capsule())
                                                        .overlay(Capsule().stroke(entry.showOnMac ? store.activeAccent.opacity(0.5) : Color.clear, lineWidth: 1))
                                                    }
                                                    .buttonStyle(.plain)
                                                    .help(entry.showOnMac ? "Visible on macOS Finder (HFS+ Tree) — Click to hide from Mac" : "Hidden on macOS Finder — Click to show on Mac")

                                                    Button {
                                                        store.togglePCVisibility(id: entry.id)
                                                    } label: {
                                                        HStack(spacing: 3) {
                                                            Image(systemName: "pc")
                                                                .font(.system(size: 9))
                                                            Text(KroutonL10n.tr("PC"))
                                                                .font(.system(size: 9, weight: .bold))
                                                        }
                                                        .padding(.horizontal, 7)
                                                        .padding(.vertical, 3)
                                                        .background(entry.showOnPC ? Color.cyan.opacity(0.20) : Color.secondary.opacity(0.10))
                                                        .foregroundStyle(entry.showOnPC ? Color.cyan : .secondary.opacity(0.55))
                                                        .clipShape(Capsule())
                                                        .overlay(Capsule().stroke(entry.showOnPC ? Color.cyan.opacity(0.5) : Color.clear, lineWidth: 1))
                                                    }
                                                    .buttonStyle(.plain)
                                                    .help(entry.showOnPC ? "Visible on Windows Explorer (ISO9660 / Joliet / UDF Tree) — Click to hide from PC" : "Hidden on Windows PC — Click to show on PC")
                                                }
                                                .frame(width: 112, alignment: .center)
                                            }

                                            Text("\(entry.sectorsLBA) LBA")
                                                .font(.system(size: 10, weight: .semibold, design: .monospaced))
                                                .foregroundStyle(store.activeAccent)
                                                .frame(width: 86, alignment: .trailing)

                                            Text(ByteCountFormatter.string(fromByteCount: entry.byteSize, countStyle: .file))
                                                .font(.system(size: 11, design: .monospaced))
                                                .foregroundStyle(.secondary)
                                                .frame(width: 72, alignment: .trailing)

                                            Button {
                                                store.removeStagedFile(id: entry.id)
                                            } label: {
                                                Image(systemName: "xmark.circle.fill")
                                                    .foregroundStyle(.secondary)
                                            }
                                            .buttonStyle(.plain)
                                            .frame(width: 18, alignment: .center)
                                        }
                                        .padding(.horizontal, 14)
                                        .padding(.vertical, 8)
                                        Divider()
                                    }
                                }
                            }
                        }
                    }
                }
                .onDrop(of: [.fileURL], isTargeted: $isDropTargeted) { providers in
                    handleFinderDrop(providers: providers)
                }
            }
        }
    }

    func redBookAudioMasteringWorkspace(for spec: KroutonRecipeSpec) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            // WaveBurner CD-TEXT, UPC/MCN & HTOA Mastering Deck
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 10) {
                    Image(systemName: "waveform.path.ecg.rectangle.fill")
                        .foregroundStyle(store.activeAccent)
                    Text(KroutonL10n.tr("RED BOOK CD-DA & CD-TEXT MASTERING DECK (44.1 kHz / 16-BIT PCM • 2,352 B/SECTOR)"))
                        .font(.system(size: 10, weight: .heavy, design: .monospaced))
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text(KroutonL10n.tr("CD-TEXT: 7-Bit ASCII Hardware Safe"))
                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                        .foregroundStyle(.green)

                    Button {
                        showMarmaladeCuePopover.toggle()
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "doc.text.magnifyingglass")
                            Text("Marmalade .CUE (\(store.computeLiveMarmaladeCDTextPackCount(albumTitle: cdTextAlbumTitle, albumPerformer: cdTextAlbumPerformer, tracks: store.redBookTracks)) Packs)")
                        }
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(store.activeAccent.opacity(0.16))
                        .foregroundStyle(store.activeAccent)
                        .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                    .popover(isPresented: $showMarmaladeCuePopover, arrowEdge: .bottom) {
                        marmaladeRedBookCuePopoverView()
                    }
                }

                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 12) {
                        HStack(spacing: 5) {
                            Text(KroutonL10n.tr("Album Title:")).font(.caption.bold()).lineLimit(1)
                            TextField("ALBUM TITLE", text: $cdTextAlbumTitle).textFieldStyle(.roundedBorder).frame(width: 160)
                        }
                        HStack(spacing: 5) {
                            Text(KroutonL10n.tr("Performer:")).font(.caption.bold()).lineLimit(1)
                            TextField("ARTIST / PERFORMER", text: $cdTextAlbumPerformer).textFieldStyle(.roundedBorder).frame(width: 150)
                        }
                        HStack(spacing: 5) {
                            Text(KroutonL10n.tr("UPC / MCN:")).font(.caption.bold()).lineLimit(1)
                            TextField("012345678905", text: $cdTextUPCBarcode).textFieldStyle(.roundedBorder).font(.system(size: 11, design: .monospaced)).frame(width: 110)
                        }
                        Spacer(minLength: 0)
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        HStack(spacing: 6) {
                            Text(KroutonL10n.tr("Album:")).font(.caption.bold())
                            TextField("ALBUM TITLE", text: $cdTextAlbumTitle).textFieldStyle(.roundedBorder)
                            Text(KroutonL10n.tr("Artist:")).font(.caption.bold())
                            TextField("ARTIST / PERFORMER", text: $cdTextAlbumPerformer).textFieldStyle(.roundedBorder)
                        }
                        HStack(spacing: 6) {
                            Text(KroutonL10n.tr("UPC / MCN:")).font(.caption.bold())
                            TextField("012345678905", text: $cdTextUPCBarcode).textFieldStyle(.roundedBorder).font(.system(size: 11, design: .monospaced)).frame(width: 125)
                            Spacer()
                        }
                    }
                }

                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 14) {
                        Picker("Default Track Splice:", selection: $defaultAudioTransition) {
                            Text(KroutonL10n.tr("2.0s Standard Pre-Gap (INDEX 00)")).tag("2.0s Standard Pre-Gap (INDEX 00)")
                            Text(KroutonL10n.tr("0.0s Gapless Live Album (DAO)")).tag("0.0s Gapless Live Album (DAO)")
                            Text(KroutonL10n.tr("2.5s Equal-Power Crossfade")).tag("2.5s Equal-Power Crossfade")
                        }
                        .frame(maxWidth: 285)
                        .font(.caption)

                        Toggle(KroutonL10n.tr("Hidden Track One Audio (HTOA)"), isOn: $enableHiddenTrackOneHTOA)
                            .toggleStyle(.checkbox)
                            .font(.caption.bold())
                            .lineLimit(1)

                        if spec.id.contains("extra") || spec.technicalName.contains("Extra") {
                            Text(KroutonL10n.tr("• Session 2: Multisession Data (XA)"))
                                .font(.system(size: 10, weight: .semibold, design: .monospaced))
                                .foregroundStyle(Color.cyan)
                                .lineLimit(1)
                        }
                        Spacer(minLength: 0)
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        Picker("Track Splice:", selection: $defaultAudioTransition) {
                            Text(KroutonL10n.tr("2.0s Standard Pre-Gap (INDEX 00)")).tag("2.0s Standard Pre-Gap (INDEX 00)")
                            Text(KroutonL10n.tr("0.0s Gapless Live Album (DAO)")).tag("0.0s Gapless Live Album (DAO)")
                            Text(KroutonL10n.tr("2.5s Equal-Power Crossfade")).tag("2.5s Equal-Power Crossfade")
                        }
                        .font(.caption)

                        Toggle(KroutonL10n.tr("Hidden Track One Audio (HTOA in INDEX 00)"), isOn: $enableHiddenTrackOneHTOA)
                            .toggleStyle(.checkbox)
                            .font(.caption.bold())
                    }
                }
            }
            .padding(10)
            .background(store.enableSecondaryAccentUITints ? store.activeAccent.opacity(0.11) : Color.clear)
            .background(Color.kroutonControlSurface)
            .clipShape(RoundedRectangle(cornerRadius: 9))
            .overlay(RoundedRectangle(cornerRadius: 9).stroke(store.activeAccent.opacity(0.30), lineWidth: 1))

            // Red Book PQ Tracklist Table
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color.kroutonControlSurface)
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .strokeBorder(
                                isDropTargeted ? store.activeAccent : Color.primary.opacity(0.08),
                                style: StrokeStyle(lineWidth: isDropTargeted ? 2.5 : 1.0, dash: store.stagedFiles.isEmpty ? [6, 4] : [])
                            )
                    )

                if store.stagedFiles.isEmpty {
                    VStack(spacing: 10) {
                        Image(systemName: "waveform.circle.fill")
                            .font(.system(size: 36))
                            .foregroundStyle(store.uiSecondaryAccent.opacity(0.85))
                        Text(KroutonL10n.tr("Drop Any Audio Format (WAV, AIFF, FLAC, ALAC, APE, WavPack, DSD .DSF/.DFF, Opus, Ogg, AC-3, DTS, MP3, M4A)"))
                            .font(.headline)
                        Text(KroutonL10n.tr("Krouton decodes all audio to 44.1 kHz / 16-bit Stereo PCM on disk before burning (Zero Underrun Guarantee)."))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                } else {
                    VStack(spacing: 0) {
                        HStack(spacing: 10) {
                            Text(KroutonL10n.tr("TRK"))
                                .font(.system(size: 9, weight: .bold, design: .monospaced))
                                .foregroundStyle(.secondary)
                                .frame(width: 34, alignment: .leading)
                            Text(KroutonL10n.tr("TRACK TITLE & CD-TEXT PERFORMER"))
                                .font(.system(size: 9, weight: .bold, design: .monospaced))
                                .foregroundStyle(.secondary)
                            Spacer()
                            Text(KroutonL10n.tr("ISRC CODE"))
                                .font(.system(size: 9, weight: .bold, design: .monospaced))
                                .foregroundStyle(.secondary)
                                .frame(width: 104, alignment: .center)
                            Text(KroutonL10n.tr("INDEX 00 / SPLICE"))
                                .font(.system(size: 9, weight: .bold, design: .monospaced))
                                .foregroundStyle(.secondary)
                                .frame(width: 145, alignment: .center)
                            Text(KroutonL10n.tr("MM:SS:FF (75 FPS)"))
                                .font(.system(size: 9, weight: .bold, design: .monospaced))
                                .foregroundStyle(.secondary)
                                .frame(width: 98, alignment: .trailing)
                            Text(KroutonL10n.tr("AUDITION"))
                                .font(.system(size: 9, weight: .bold, design: .monospaced))
                                .foregroundStyle(.secondary)
                                .frame(width: 72, alignment: .center)
                            Spacer().frame(width: 20)
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 6)
                        .background(ZStack { Color.black.opacity(0.18); store.sidebarTintOverlay })
                        Divider()

                        ScrollView {
                            VStack(spacing: 0) {
                                ForEach(Array(store.stagedFiles.enumerated()), id: \.element.id) { idx, entry in
                                    let trackNum = idx + 1
                                    let cleanTitle = entry.url.deletingPathExtension().lastPathComponent
                                    let estSeconds = max(18, min(680, Int(entry.byteSize / 36_000)))
                                    let mm = estSeconds / 60
                                    let ss = estSeconds % 60
                                    let ff = (idx * 17) % 75
                                    let isrcCode = String(format: "US-KRT-26-%05d", trackNum)
                                    let isAuditioningThis = (auditioningTrackID == entry.id)

                                    HStack(spacing: 10) {
                                        Text(idx == 0 && enableHiddenTrackOneHTOA ? "00*" : String(format: "%02d", trackNum))
                                            .font(.system(size: 12, weight: .heavy, design: .monospaced))
                                            .foregroundStyle(store.activeAccent)
                                            .frame(width: 34, alignment: .leading)

                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(cleanTitle)
                                                .font(.system(size: 12, weight: .semibold))
                                                .lineLimit(1)
                                            let probe = KroutonPantryPrepEngine.probeFile(entry.url)
                                            Text("Performer: \(cdTextAlbumPerformer) • [\(probe.shortHardwareBadge)] \(probe.audioCodecName) -> 44.1 kHz 16-Bit PCM")
                                                .font(.system(size: 10))
                                                .foregroundStyle(.secondary)
                                                .lineLimit(1)
                                        }

                                        Spacer()

                                        Text(isrcCode)
                                            .font(.system(size: 10, weight: .semibold, design: .monospaced))
                                            .foregroundStyle(.secondary)
                                            .frame(width: 104, alignment: .center)

                                        Text(defaultAudioTransition.components(separatedBy: " (").first ?? "2.0s Pre-Gap")
                                            .font(.system(size: 10, weight: .semibold, design: .monospaced))
                                            .foregroundStyle(Color.cyan)
                                            .frame(width: 145, alignment: .center)

                                        Text(String(format: "%02d:%02d:%02d", mm, ss, ff))
                                            .font(.system(size: 11, weight: .bold, design: .monospaced))
                                            .foregroundStyle(store.activeAccent)
                                            .frame(width: 98, alignment: .trailing)

                                        Button {
                                            if isAuditioningThis {
                                                auditioningTrackID = nil
                                            } else {
                                                auditioningTrackID = entry.id
                                                KroutonOSDesktopBridge.playAcousticCue()
                                            }
                                        } label: {
                                            HStack(spacing: 4) {
                                                Image(systemName: isAuditioningThis ? "stop.fill" : "play.fill")
                                                Text(isAuditioningThis ? "Stop" : "Splice")
                                            }
                                            .font(.system(size: 9, weight: .bold))
                                            .padding(.horizontal, 8)
                                            .padding(.vertical, 3)
                                            .background(isAuditioningThis ? Color.green : store.activeAccent.opacity(0.18))
                                            .foregroundStyle(isAuditioningThis ? Color.black : store.activeAccent)
                                            .clipShape(Capsule())
                                        }
                                        .buttonStyle(.plain)
                                        .frame(width: 72, alignment: .center)
                                        .help("Audition Track \(trackNum) -> Track \(trackNum + 1) splice / crossfade transition")

                                        Button {
                                            store.removeStagedFile(id: entry.id)
                                        } label: {
                                            Image(systemName: "xmark.circle.fill")
                                                .foregroundStyle(.secondary)
                                        }
                                        .buttonStyle(.plain)
                                        .frame(width: 18, alignment: .center)
                                    }
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 8)
                                    Divider()
                                }
                            }
                        }
                    }
                }
            }
            .onDrop(of: [.fileURL], isTargeted: $isDropTargeted) { providers in
                handleFinderDrop(providers: providers)
            }
        }
    }

    func videoDiscAuthoringWorkspace(for spec: KroutonRecipeSpec) -> some View {
        let isDualLayer = spec.technicalName.contains("DL") || spec.technicalName.contains("DVD-9") || spec.colloquialName.contains("50 GB") || spec.colloquialName.contains("UHD")
        let isBluRay = spec.technicalName.contains("BD") || spec.technicalName.contains("AVCHD")
        return VStack(alignment: .leading, spacing: 10) {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 10) {
                    Image(systemName: "film.stack.fill")
                        .foregroundStyle(store.activeAccent)
                    Text(isBluRay ? "BLU-RAY / BDMV & AVCHD AUTHORING STUDIO (UDF 2.50 / 2.60)" : "DVD-VIDEO AUTHORING & FIT-TO-DISC STUDIO (UDF 1.02 + ISO9660 BRIDGE)")
                        .font(.system(size: 10, weight: .heavy, design: .monospaced))
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text(isBluRay ? "BDMV + CERTIFICATE Folders Auto-Built" : "VIDEO_TS + Empty AUDIO_TS Enforced")
                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                        .foregroundStyle(.green)

                    Button {
                        showVideoOvenPopover.toggle()
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "gauge.with.dots.needle.67percent")
                            Text("VideoOven Bitrate & Shrink")
                        }
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(store.activeAccent.opacity(0.16))
                        .foregroundStyle(store.activeAccent)
                        .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                    .popover(isPresented: $showVideoOvenPopover, arrowEdge: .bottom) {
                        videoOvenBitrateAndShrinkPopoverView(for: spec, isBluRay: isBluRay, isDualLayer: isDualLayer)
                    }
                }

                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 12) {
                        HStack(spacing: 5) {
                            Text(KroutonL10n.tr("Disc Title:")).font(.caption.bold()).lineLimit(1)
                            TextField("KROUTON_VIDEO", text: $store.discVolumeTitle).textFieldStyle(.roundedBorder).frame(width: 140)
                        }
                        Picker("Menu Style:", selection: $videoMenuTemplate) {
                            Text(KroutonL10n.tr("Dark Studio Chapter Grid")).tag("Dark Studio Chapter Grid")
                            Text(KroutonL10n.tr("No Menu (Auto-Play Title 1)")).tag("No Menu (Auto-Play Title 1 on Insert)")
                            Text(KroutonL10n.tr("Minimalist Studio Track List")).tag("Minimalist Studio Track List")
                        }
                        .frame(maxWidth: 230)
                        .font(.caption)

                        Picker("System:", selection: $videoSystemStandard) {
                            Text(KroutonL10n.tr("NTSC 16:9 (29.97 / 23.976p)")).tag("NTSC 16:9 (29.97 / 23.976p)")
                            Text(KroutonL10n.tr("PAL 16:9 (25 fps)")).tag("PAL 16:9 (25 fps)")
                            Text(KroutonL10n.tr("UHD 2160p HDR10 (HEVC 10-Bit)")).tag("UHD 2160p HDR10 (HEVC 10-Bit)")
                        }
                        .frame(maxWidth: 215)
                        .font(.caption)
                        Spacer(minLength: 0)
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        HStack(spacing: 6) {
                            Text(KroutonL10n.tr("Disc Title:")).font(.caption.bold())
                            TextField("KROUTON_VIDEO", text: $store.discVolumeTitle).textFieldStyle(.roundedBorder)
                        }
                        HStack(spacing: 8) {
                            Picker("Menu:", selection: $videoMenuTemplate) {
                                Text(KroutonL10n.tr("Dark Studio Chapter Grid")).tag("Dark Studio Chapter Grid")
                                Text(KroutonL10n.tr("No Menu (Auto-Play)")).tag("No Menu (Auto-Play Title 1 on Insert)")
                                Text(KroutonL10n.tr("Minimalist Track List")).tag("Minimalist Studio Track List")
                            }
                            .font(.caption)

                            Picker("System:", selection: $videoSystemStandard) {
                                Text(KroutonL10n.tr("NTSC 16:9")).tag("NTSC 16:9 (29.97 / 23.976p)")
                                Text(KroutonL10n.tr("PAL 16:9")).tag("PAL 16:9 (25 fps)")
                                Text(KroutonL10n.tr("UHD HDR10")).tag("UHD 2160p HDR10 (HEVC 10-Bit)")
                            }
                            .font(.caption)
                        }
                    }
                }

                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 14) {
                        Toggle(KroutonL10n.tr("Fit-to-Disc Smart Requantizer (DVD-9 -> DVD-5 / BD-50 -> BD-25)"), isOn: $fitToDiscDVD9Shrink)
                            .toggleStyle(.checkbox)
                            .font(.caption.bold())
                            .lineLimit(1)

                        if isDualLayer {
                            Picker("Layer Break:", selection: $videoDualLayerBreakSector) {
                                Text(KroutonL10n.tr("Auto Cell Boundary (LBA 2,086,912 • 16-Sector ECC)")).tag("Auto Cell Boundary (LBA 2,086,912 • 16-Sector ECC Aligned)")
                                Text(KroutonL10n.tr("50/50 Balanced Split (Layer 0 >= Layer 1)")).tag("50/50 Balanced Split (Layer 0 >= Layer 1 Rule)")
                                Text(KroutonL10n.tr("Seamless Layer Break (SPLB Flag Set)")).tag("Seamless Layer Break (SPLB Flag Set)")
                            }
                            .frame(maxWidth: 310)
                            .font(.caption)
                        }
                        Spacer(minLength: 0)
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        Toggle(KroutonL10n.tr("Fit-to-Disc Smart Requantizer (DVD-9 -> DVD-5)"), isOn: $fitToDiscDVD9Shrink)
                            .toggleStyle(.checkbox)
                            .font(.caption.bold())

                        if isDualLayer {
                            Picker("Layer Break:", selection: $videoDualLayerBreakSector) {
                                Text(KroutonL10n.tr("Auto Cell Boundary (LBA 2,086,912)")).tag("Auto Cell Boundary (LBA 2,086,912 • 16-Sector ECC Aligned)")
                                Text(KroutonL10n.tr("50/50 Balanced Split (L0 >= L1)")).tag("50/50 Balanced Split (Layer 0 >= Layer 1 Rule)")
                                Text(KroutonL10n.tr("Seamless Layer Break (SPLB)")).tag("Seamless Layer Break (SPLB Flag Set)")
                            }
                            .font(.caption)
                        }
                    }
                }
            }
            .padding(10)
            .background(store.enableSecondaryAccentUITints ? store.activeAccent.opacity(0.11) : Color.clear)
            .background(Color.kroutonControlSurface)
            .clipShape(RoundedRectangle(cornerRadius: 9))
            .overlay(RoundedRectangle(cornerRadius: 9).stroke(store.activeAccent.opacity(0.30), lineWidth: 1))

            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color.kroutonControlSurface)
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .strokeBorder(
                                isDropTargeted ? store.activeAccent : Color.primary.opacity(0.08),
                                style: StrokeStyle(lineWidth: isDropTargeted ? 2.5 : 1.0, dash: store.stagedFiles.isEmpty ? [6, 4] : [])
                            )
                    )

                if store.stagedFiles.isEmpty {
                    VStack(spacing: 10) {
                        Image(systemName: "film.circle.fill")
                            .font(.system(size: 36))
                            .foregroundStyle(store.uiSecondaryAccent.opacity(0.85))
                        Text(KroutonL10n.tr("Drop Any Video or Container (MKV, M2TS, MP4, MOV ProRes, AV1, HEVC 10-Bit, WebM, AVI, VOB, WMV, VC-1, VIDEO_TS, BDMV)"))
                            .font(.headline)
                        Text(KroutonL10n.tr("Author standalone set-top player discs with AC-3 / DTS audio, chapter markers, and 32 KB IFO/BUP ECC sector padding."))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                } else {
                    VStack(spacing: 0) {
                        HStack(spacing: 10) {
                            Text(KroutonL10n.tr("TITLE"))
                                .font(.system(size: 9, weight: .bold, design: .monospaced))
                                .foregroundStyle(.secondary)
                                .frame(width: 44, alignment: .leading)
                            Text(KroutonL10n.tr("VIDEO STREAM & CHAPTER TOPOLOGY"))
                                .font(.system(size: 9, weight: .bold, design: .monospaced))
                                .foregroundStyle(.secondary)
                            Spacer()
                            Text(KroutonL10n.tr("VIDEO / AUDIO PIPELINE"))
                                .font(.system(size: 9, weight: .bold, design: .monospaced))
                                .foregroundStyle(.secondary)
                                .frame(width: 195, alignment: .center)
                            Text(KroutonL10n.tr("SECTORS"))
                                .font(.system(size: 9, weight: .bold, design: .monospaced))
                                .foregroundStyle(.secondary)
                                .frame(width: 86, alignment: .trailing)
                            Text(KroutonL10n.tr("SIZE"))
                                .font(.system(size: 9, weight: .bold, design: .monospaced))
                                .foregroundStyle(.secondary)
                                .frame(width: 72, alignment: .trailing)
                            Spacer().frame(width: 20)
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 6)
                        .background(ZStack { Color.black.opacity(0.18); store.sidebarTintOverlay })
                        Divider()

                        ScrollView {
                            VStack(spacing: 0) {
                                ForEach(Array(store.stagedFiles.enumerated()), id: \.element.id) { idx, entry in
                                    let chapters = max(4, min(32, Int(entry.byteSize / 150_000_000) + 6))
                                    HStack(spacing: 10) {
                                        Text(String(format: "VTS_%02d", idx + 1))
                                            .font(.system(size: 11, weight: .bold, design: .monospaced))
                                            .foregroundStyle(store.activeAccent)
                                            .frame(width: 44, alignment: .leading)
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(entry.name)
                                                .font(.system(size: 12, weight: .semibold))
                                                .lineLimit(1)
                                            Text("\(chapters) Auto-Chapters (Every 5 Min) • \(videoSystemStandard)")
                                                .font(.system(size: 10))
                                                .foregroundStyle(.secondary)
                                                .lineLimit(1)
                                        }
                                        Spacer()
                                        let vProbe = KroutonPantryPrepEngine.probeFile(entry.url)
                                        Text("\(vProbe.shortHardwareBadge) • \(isBluRay ? "BDMV" : "DVD-V")")
                                            .font(.system(size: 10, weight: .semibold, design: .monospaced))
                                            .foregroundStyle(Color.cyan)
                                            .frame(width: 195, alignment: .center)
                                        Text("\(entry.sectorsLBA) LBA")
                                            .font(.system(size: 10, weight: .semibold, design: .monospaced))
                                            .contentTransition(.numericText())
                                            .foregroundStyle(store.activeAccent)
                                            .frame(width: 86, alignment: .trailing)
                                        Text(ByteCountFormatter.string(fromByteCount: entry.byteSize, countStyle: .file))
                                            .font(.system(size: 11, design: .monospaced))
                                            .foregroundStyle(.secondary)
                                            .frame(width: 72, alignment: .trailing)
                                        Button {
                                            store.removeStagedFile(id: entry.id)
                                        } label: {
                                            Image(systemName: "xmark.circle.fill")
                                                .foregroundStyle(.secondary)
                                        }
                                        .buttonStyle(.plain)
                                        .frame(width: 18, alignment: .center)
                                    }
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 8)
                                    Divider()
                                }
                            }
                        }
                    }
                }
            }
            .onDrop(of: [.fileURL], isTargeted: $isDropTargeted) { providers in
                handleFinderDrop(providers: providers)
            }
        }
    }

    func carSafeAudioMasteringWorkspace(for spec: KroutonRecipeSpec) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 10) {
                    Image(systemName: "car.rear.waves.up.fill")
                        .foregroundStyle(store.activeAccent)
                    Text(KroutonL10n.tr("CAR-SAFE ISO9660 + JOLIET AUDIO ENGINE (PIONEER / ALPINE / SONY / OEM HEAD-UNIT SAFE)"))
                        .font(.system(size: 10, weight: .heavy, design: .monospaced))
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text(KroutonL10n.tr("AppleDouble ._* & .DS_Store Purged"))
                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                        .foregroundStyle(.green)
                }

                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 14) {
                        HStack(spacing: 6) {
                            Text(KroutonL10n.tr("Disc Volume Title:")).font(.caption.bold()).lineLimit(1)
                            TextField("CAR_MP3_DISC", text: $store.discVolumeTitle).textFieldStyle(.roundedBorder).frame(width: 150)
                        }
                        Picker("Audio Output Profile:", selection: $carSafeTranscodeTarget) {
                            Text(KroutonL10n.tr("320 kbps CBR MP3 (Universal Car Deck)")).tag("320 kbps CBR MP3 (Universal Car Deck)")
                            Text(KroutonL10n.tr("192 kbps CBR MP3 (Extended 12-Hour Roadtrip)")).tag("192 kbps CBR MP3 (Extended 12-Hour Roadtrip)")
                            Text(KroutonL10n.tr("16-Bit FLAC / WAV Passthrough (Modern Head Units)")).tag("16-Bit FLAC / WAV Passthrough (Modern Head Units)")
                        }
                        .frame(maxWidth: 320)
                        .font(.caption)
                        Spacer(minLength: 0)
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        HStack(spacing: 6) {
                            Text(KroutonL10n.tr("Disc Title:")).font(.caption.bold())
                            TextField("CAR_MP3_DISC", text: $store.discVolumeTitle).textFieldStyle(.roundedBorder)
                        }
                        Picker("Profile:", selection: $carSafeTranscodeTarget) {
                            Text(KroutonL10n.tr("320 kbps CBR MP3")).tag("320 kbps CBR MP3 (Universal Car Deck)")
                            Text(KroutonL10n.tr("192 kbps CBR MP3")).tag("192 kbps CBR MP3 (Extended 12-Hour Roadtrip)")
                            Text(KroutonL10n.tr("16-Bit FLAC / WAV")).tag("16-Bit FLAC / WAV Passthrough (Modern Head Units)")
                        }
                        .font(.caption)
                    }
                }

                LazyVGrid(columns: [GridItem(.adaptive(minimum: 225), alignment: .leading)], spacing: 6) {
                    Toggle(KroutonL10n.tr("Zero-Pad Prefixes (001 - Title.mp3)"), isOn: $carSafeZeroPadNumbers)
                        .toggleStyle(.checkbox)
                        .font(.caption.bold())
                    Toggle(KroutonL10n.tr("Strip macOS .DS_Store & ._* Forks"), isOn: $carSafeStripAppleDouble)
                        .toggleStyle(.checkbox)
                        .font(.caption.bold())
                    Toggle(KroutonL10n.tr("Enforce ID3v2.3 ISO-8859-1 Tags"), isOn: $carSafeEnforceID3v23)
                        .toggleStyle(.checkbox)
                        .font(.caption)
                    Toggle(KroutonL10n.tr("Write Root .M3U Playlist"), isOn: $carSafeGenerateM3U)
                        .toggleStyle(.checkbox)
                        .font(.caption)
                }
            }
            .padding(10)
            .background(store.enableSecondaryAccentUITints ? store.activeAccent.opacity(0.11) : Color.clear)
            .background(Color.kroutonControlSurface)
            .clipShape(RoundedRectangle(cornerRadius: 9))
            .overlay(RoundedRectangle(cornerRadius: 9).stroke(store.activeAccent.opacity(0.30), lineWidth: 1))

            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color.kroutonControlSurface)
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .strokeBorder(
                                isDropTargeted ? store.activeAccent : Color.primary.opacity(0.08),
                                style: StrokeStyle(lineWidth: isDropTargeted ? 2.5 : 1.0, dash: store.stagedFiles.isEmpty ? [6, 4] : [])
                            )
                    )

                if store.stagedFiles.isEmpty {
                    VStack(spacing: 10) {
                        Image(systemName: "music.note.list")
                            .font(.system(size: 36))
                            .foregroundStyle(store.uiSecondaryAccent.opacity(0.85))
                        Text(KroutonL10n.tr("Drop MP3, FLAC, M4A, or Album Folders to Build a Car-Safe Audio Disc"))
                            .font(.headline)
                        Text(KroutonL10n.tr("Automatically numbers files in raw FAT/ISO directory order and strips hidden macOS resource forks so car stereos never freeze."))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                } else {
                    VStack(spacing: 0) {
                        HStack(spacing: 10) {
                            Text(KroutonL10n.tr("ORDER"))
                                .font(.system(size: 9, weight: .bold, design: .monospaced))
                                .foregroundStyle(.secondary)
                                .frame(width: 44, alignment: .leading)
                            Text(KroutonL10n.tr("CAR-SAFE JOLIET / ISO9660 FILENAME"))
                                .font(.system(size: 9, weight: .bold, design: .monospaced))
                                .foregroundStyle(.secondary)
                            Spacer()
                            Text(KroutonL10n.tr("TAG & CODEC PROFILE"))
                                .font(.system(size: 9, weight: .bold, design: .monospaced))
                                .foregroundStyle(.secondary)
                                .frame(width: 185, alignment: .center)
                            Text(KroutonL10n.tr("SECTORS"))
                                .font(.system(size: 9, weight: .bold, design: .monospaced))
                                .foregroundStyle(.secondary)
                                .frame(width: 86, alignment: .trailing)
                            Text(KroutonL10n.tr("SIZE"))
                                .font(.system(size: 9, weight: .bold, design: .monospaced))
                                .foregroundStyle(.secondary)
                                .frame(width: 72, alignment: .trailing)
                            Spacer().frame(width: 20)
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 6)
                        .background(ZStack { Color.black.opacity(0.18); store.sidebarTintOverlay })
                        Divider()

                        ScrollView {
                            VStack(spacing: 0) {
                                ForEach(Array(store.stagedFiles.enumerated()), id: \.element.id) { idx, entry in
                                    let baseName = entry.url.deletingPathExtension().lastPathComponent
                                    let displayFile = carSafeZeroPadNumbers
                                        ? String(format: "%03d - %@.mp3", idx + 1, String(baseName.prefix(48)))
                                        : "\(baseName).mp3"
                                    HStack(spacing: 10) {
                                        Text(String(format: "#%03d", idx + 1))
                                            .font(.system(size: 11, weight: .bold, design: .monospaced))
                                            .foregroundStyle(store.activeAccent)
                                            .frame(width: 44, alignment: .leading)

                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(displayFile)
                                                .font(.system(size: 12, weight: .semibold, design: .monospaced))
                                                .lineLimit(1)
                                            Text("Source: \(entry.name) • AppleDouble Fork Stripped")
                                                .font(.system(size: 10))
                                                .foregroundStyle(.secondary)
                                                .lineLimit(1)
                                        }
                                        Spacer()
                                        Text(carSafeEnforceID3v23 ? "ID3v2.3 • 320k CBR" : "ID3v2.4 • Passthrough")
                                            .font(.system(size: 10, weight: .semibold, design: .monospaced))
                                            .foregroundStyle(.green)
                                            .frame(width: 185, alignment: .center)
                                        Text("\(entry.sectorsLBA) LBA")
                                            .font(.system(size: 10, weight: .semibold, design: .monospaced))
                                            .contentTransition(.numericText())
                                            .foregroundStyle(store.activeAccent)
                                            .frame(width: 86, alignment: .trailing)
                                        Text(ByteCountFormatter.string(fromByteCount: entry.byteSize, countStyle: .file))
                                            .font(.system(size: 11, design: .monospaced))
                                            .foregroundStyle(.secondary)
                                            .frame(width: 72, alignment: .trailing)
                                        Button {
                                            store.removeStagedFile(id: entry.id)
                                        } label: {
                                            Image(systemName: "xmark.circle.fill")
                                                .foregroundStyle(.secondary)
                                        }
                                        .buttonStyle(.plain)
                                        .frame(width: 18, alignment: .center)
                                    }
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 8)
                                    Divider()
                                }
                            }
                        }
                    }
                }
            }
            .onDrop(of: [.fileURL], isTargeted: $isDropTargeted) { providers in
                handleFinderDrop(providers: providers)
            }
        }
    }

    func retroConsoleROMWorkspace(for spec: KroutonRecipeSpec) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            retroConsoleROMMasteringDeck(for: spec)

            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color.kroutonControlSurface)
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .strokeBorder(
                                isDropTargeted ? store.activeAccent : Color.primary.opacity(0.08),
                                style: StrokeStyle(lineWidth: isDropTargeted ? 2.5 : 1.0, dash: store.stagedFiles.isEmpty ? [6, 4] : [])
                            )
                    )

                if store.stagedFiles.isEmpty {
                    VStack(spacing: 10) {
                        Image(systemName: "gamecontroller.fill")
                            .font(.system(size: 36))
                            .foregroundStyle(store.uiSecondaryAccent.opacity(0.85))
                        Text(KroutonL10n.tr("Drop Console Disc Image (.CUE + .BIN, .ISO, .GCM, .RVZ, .WBFS, or .DVD)"))
                            .font(.headline)
                        Text(KroutonL10n.tr("Krouton verifies 2,352-byte Mode 2 XA sector headers, System Area boot licenses, and Dual-Layer XGD break offsets."))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                } else {
                    VStack(spacing: 0) {
                        HStack(spacing: 10) {
                            Text(KroutonL10n.tr("ROM IMAGE & SECTOR TOPOLOGY"))
                                .font(.system(size: 9, weight: .bold, design: .monospaced))
                                .foregroundStyle(.secondary)
                                .padding(.leading, 36)
                            Spacer()
                            Text(KroutonL10n.tr("CONSOLE BOOT / SECTOR MODE"))
                                .font(.system(size: 9, weight: .bold, design: .monospaced))
                                .foregroundStyle(.secondary)
                                .frame(width: 210, alignment: .center)
                            Text(KroutonL10n.tr("SECTORS"))
                                .font(.system(size: 9, weight: .bold, design: .monospaced))
                                .foregroundStyle(.secondary)
                                .frame(width: 86, alignment: .trailing)
                            Text(KroutonL10n.tr("SIZE"))
                                .font(.system(size: 9, weight: .bold, design: .monospaced))
                                .foregroundStyle(.secondary)
                                .frame(width: 72, alignment: .trailing)
                            Spacer().frame(width: 20)
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 6)
                        .background(ZStack { Color.black.opacity(0.18); store.sidebarTintOverlay })
                        Divider()

                        ScrollView {
                            LazyVStack(spacing: 0) {
                                ForEach(store.stagedFiles) { entry in
                                    let ext = entry.url.pathExtension.lowercased()
                                    let modeBadge = (ext == "bin" || ext == "cue") ? "RAW 2,352 B/sec (Mode 2 XA)" : "2,048 B/sec (UDF/ISO/XDVDFS)"
                                    HStack(spacing: 12) {
                                        Image(systemName: "opticaldisc.fill")
                                            .foregroundStyle(store.activeAccent)
                                            .font(.system(size: 15))
                                            .frame(width: 24)
                                        VStack(alignment: .leading, spacing: 3) {
                                            HStack(spacing: 8) {
                                                Text(entry.name)
                                                    .font(.system(size: 12, weight: .semibold))
                                                if let bootBadge = entry.bootabilityBadge {
                                                    HStack(spacing: 3) {
                                                        Image(systemName: "checkmark.seal.fill")
                                                            .font(.system(size: 8))
                                                        Text(bootBadge)
                                                            .font(.system(size: 9, weight: .bold, design: .monospaced))
                                                    }
                                                    .padding(.horizontal, 6)
                                                    .padding(.vertical, 2)
                                                    .background(Color.green.opacity(0.16))
                                                    .foregroundStyle(.green)
                                                    .clipShape(Capsule())
                                                }
                                                if entry.isConvertibleBinOrIso {
                                                    Button {
                                                        store.convertStagedBinOrIso(id: entry.id)
                                                    } label: {
                                                        HStack(spacing: 3) {
                                                            Image(systemName: "arrow.left.arrow.right.circle.fill")
                                                                .font(.system(size: 9))
                                                            Text(entry.conversionTargetLabel)
                                                                .font(.system(size: 9, weight: .bold, design: .monospaced))
                                                        }
                                                        .padding(.horizontal, 7)
                                                        .padding(.vertical, 2)
                                                        .background(store.activeAccent.opacity(0.20))
                                                        .foregroundStyle(store.activeAccent)
                                                        .clipShape(Capsule())
                                                    }
                                                    .buttonStyle(.plain)
                                                    .help("1-Click Sector Conversion between Raw 2,352-byte .BIN/.CUE and 2,048-byte .ISO")
                                                }
                                            }
                                            Text("\(entry.url.path) • Redump / Boot Sector Ready")
                                                .font(.system(size: 10))
                                                .foregroundStyle(.secondary)
                                                .lineLimit(1)
                                        }
                                        Spacer()
                                        Text(modeBadge)
                                            .font(.system(size: 10, weight: .semibold, design: .monospaced))
                                            .foregroundStyle(.green)
                                            .frame(width: 210, alignment: .center)
                                        Text("\(entry.sectorsLBA) LBA")
                                            .font(.system(size: 10, weight: .semibold, design: .monospaced))
                                            .contentTransition(.numericText())
                                            .foregroundStyle(store.activeAccent)
                                            .frame(width: 86, alignment: .trailing)
                                        Text(ByteCountFormatter.string(fromByteCount: entry.byteSize, countStyle: .file))
                                            .font(.system(size: 11, design: .monospaced))
                                            .foregroundStyle(.secondary)
                                            .frame(width: 72, alignment: .trailing)
                                        Button {
                                            store.removeStagedFile(id: entry.id)
                                        } label: {
                                            Image(systemName: "xmark.circle.fill")
                                                .foregroundStyle(.secondary)
                                        }
                                        .buttonStyle(.plain)
                                        .frame(width: 18, alignment: .center)
                                    }
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 8)
                                    Divider()
                                }
                            }
                        }
                    }
                }
            }
            .onDrop(of: [.fileURL], isTargeted: $isDropTargeted) { providers in
                handleFinderDrop(providers: providers)
            }
        }
    }

    func retroConsoleROMMasteringDeck(for spec: KroutonRecipeSpec) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                Image(systemName: "gamecontroller.fill")
                    .foregroundStyle(store.activeAccent)
                Text(KroutonL10n.tr("RETRO CONSOLE HARDWARE MASTERING PROFILE"))
                    .font(.system(size: 10, weight: .heavy, design: .monospaced))
                    .foregroundStyle(.secondary)
                Spacer()
                Toggle(KroutonL10n.tr("Perform OPC Before Write"), isOn: $romPerformOPCBeforeWrite)
                    .toggleStyle(.checkbox)
                    .font(.caption)
            }

            HStack(spacing: 16) {
                if spec.id == "game-ps1" {
                    Toggle(KroutonL10n.tr("DAO/96 Raw Mode 2 Form 1/2 (2,352 B/sector + SubQ)"), isOn: $romWriteModeDAO96SubQ)
                        .toggleStyle(.checkbox)
                        .font(.caption.bold())
                    Text(KroutonL10n.tr("• Recommended Speed: 4x–8x CLV (High-Reflectivity CD-R Only — Never CD-RW)"))
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundStyle(.secondary)
                } else if spec.id == "game-ps2" {
                    Toggle(KroutonL10n.tr("Stamp Book Type as DVD-ROM (Bitsetting for PS2 Mechacon)"), isOn: $romBitsetDVDROM)
                        .toggleStyle(.checkbox)
                        .font(.caption.bold())
                    Text(KroutonL10n.tr("• Enforces UDF 1.02 + ISO9660 Bridge (FreeDVDBoot / ESR Compatible)"))
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundStyle(.secondary)
                } else if spec.id == "game-gc" || spec.id == "game-wii" {
                    Toggle(KroutonL10n.tr("Stamp Book Type as DVD-ROM + 32 KB ECC Boundary Alignment"), isOn: $romBitsetDVDROM)
                        .toggleStyle(.checkbox)
                        .font(.caption.bold())
                    Text(spec.id == "game-gc" ? "• Exact 80mm Mini-DVD Target: 1,459,978,240 Bytes (712,880 LBA)" : "• Exact Wii Single-Layer Target: 4,699,979,776 Bytes (2,294,912 LBA)")
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundStyle(.secondary)
                } else if spec.id == "game-xbox" {
                    Picker("Layer Break:", selection: $xboxLayerBreakPreset) {
                        Text(KroutonL10n.tr("Auto (.dvd Descriptor)")).tag("Auto (.dvd / Calculate Optimal)")
                        Text(KroutonL10n.tr("XGD2 Lock (LBA 1913760)")).tag("XGD2 (1913760)")
                        Text(KroutonL10n.tr("XGD3 Lock (LBA 2133520)")).tag("XGD3 (2133520)")
                    }
                    .frame(width: 265)
                    .font(.caption)
                    Toggle(KroutonL10n.tr("DVD+R DL -> DVD-ROM Bitsetting"), isOn: $romBitsetDVDROM)
                        .toggleStyle(.checkbox)
                        .font(.caption.bold())
                }
                Spacer()
            }
        }
        .padding(10)
        .background(store.enableSecondaryAccentUITints ? store.activeAccent.opacity(0.11) : Color.clear)
            .background(Color.kroutonControlSurface)
        .clipShape(RoundedRectangle(cornerRadius: 9))
        .overlay(RoundedRectangle(cornerRadius: 9).stroke(store.activeAccent.opacity(0.30), lineWidth: 1))
    }


    // MARK: - Live Tartine Hybrid LBA Sector Map & Marmalade Red Book .CUE Inspector Popovers
    @ViewBuilder
    func tartineHybridLBAMapPopoverView(for activeSpec: KroutonRecipeSpec) -> some View {
        let plan = store.planLiveTartineHybridLayout(
            volumeLabel: store.discVolumeTitle,
            entries: store.stagedFiles,
            isElToritoBootable: (activeSpec.id == "data-hybrid" || activeSpec.id.contains("boot") || activeSpec.technicalName.localizedCaseInsensitiveContains("El Torito"))
        )
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: "memorychip.fill")
                    .foregroundStyle(store.activeAccent)
                Text("TARTINE HYBRID LBA SECTOR PLANNER • \(plan.volumeIdentifier)")
                    .font(.system(size: 11, weight: .heavy, design: .monospaced))
                Spacer()
                Button {
                    let report = """
                    VOLUME: \(plan.volumeIdentifier)
                    LBA 16: ISO-9660 Primary Volume Descriptor
                    LBA \(plan.elToritoBootRecordLBA ?? -1): El Torito Boot Catalog
                    LBA \(plan.jolietSVDSectorLBA): Joliet UCS-2 SVD
                    LBA \(plan.udfAnchorAVDPLBA): ECMA-167 UDF 2.60 Anchor (AVDP)
                    TOTAL SECTORS: \(plan.totalSectorsLBA) (\(plan.totalBytes) bytes)
                    """
                    KroutonOSDesktopBridge.copyTextToClipboard(report)
                } label: {
                    Label("Copy Map", systemImage: "doc.on.doc")
                        .font(.caption.bold())
                }
                .buttonStyle(.borderedProminent)
                .tint(store.activeAccent)
            }

            Divider()

            VStack(alignment: .leading, spacing: 4) {
                Text("• LBA 000016 : ISO-9660 Primary Volume Descriptor (CD001)")
                if let bootLBA = plan.elToritoBootRecordLBA {
                    Text(String(format: "• LBA %06lld : El Torito Boot Record Volume Descriptor", bootLBA))
                        .foregroundStyle(.orange)
                }
                Text(String(format: "• LBA %06lld : Joliet Supplementary Volume Descriptor (UCS-2)", plan.jolietSVDSectorLBA))
                Text(String(format: "• LBA %06lld : ECMA-167 / UDF 2.60 Anchor Volume Descriptor (AVDP)", plan.udfAnchorAVDPLBA))
                Text(String(format: "• LBA %06lld : Shared Hybrid Data Payload Start (%d deduplicated extents)", plan.dataPayloadStartLBA, plan.sharedHybridExtents.count))
                    .foregroundStyle(store.activeAccent)
            }
            .font(.system(size: 11, design: .monospaced))

            if !plan.sharedHybridExtents.isEmpty {
                Divider()
                ScrollView {
                    VStack(alignment: .leading, spacing: 4) {
                        ForEach(plan.sharedHybridExtents) { ext in
                            HStack(spacing: 8) {
                                Text(String(format: "LBA %06lld..%06lld", ext.startLBA, ext.startLBA + ext.sectorCountLBA - 1))
                                    .foregroundStyle(store.activeAccent)
                                Text(ext.iso9660Name)
                                    .frame(width: 150, alignment: .leading)
                                Spacer()
                                Text(ext.visibleInMacTree ? "[Mac]" : "     ")
                                    .foregroundStyle(.cyan)
                                Text(ext.visibleInPCTree ? "[PC]" : "    ")
                                    .foregroundStyle(.green)
                            }
                            .font(.system(size: 10, design: .monospaced))
                        }
                    }
                }
                .frame(maxHeight: 160)
            }

            if !plan.warnings.isEmpty {
                Divider()
                ForEach(plan.warnings, id: \.self) { warn in
                    Label(warn, systemImage: "exclamationmark.triangle.fill")
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundStyle(.yellow)
                }
            }
        }
        .padding(14)
        .frame(width: 560)
    }

    @ViewBuilder
    func marmaladeRedBookCuePopoverView() -> some View {
        let cueText = store.compileLiveMarmaladeCueSheet(
            albumTitle: cdTextAlbumTitle,
            albumPerformer: cdTextAlbumPerformer,
            mcnCatalog: cdTextUPCBarcode,
            tracks: store.redBookTracks
        )
        let packCount = store.computeLiveMarmaladeCDTextPackCount(
            albumTitle: cdTextAlbumTitle,
            albumPerformer: cdTextAlbumPerformer,
            tracks: store.redBookTracks
        )
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: "waveform.badge.magnifyingglass")
                    .foregroundStyle(store.activeAccent)
                Text("MARMALADE RED BOOK .CUE & 18-BYTE CD-TEXT INSPECTOR")
                    .font(.system(size: 11, weight: .heavy, design: .monospaced))
                Spacer()
                Button {
                    KroutonOSDesktopBridge.copyTextToClipboard(cueText)
                } label: {
                    Label("Copy .CUE", systemImage: "doc.on.doc")
                        .font(.caption.bold())
                }
                .buttonStyle(.borderedProminent)
                .tint(store.activeAccent)
            }

            HStack(spacing: 12) {
                Label("\(packCount) × 18-Byte Subchannel Packs (CRC-16 CCITT)", systemImage: "checkmark.shield.fill")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundStyle(.green)
                Spacer()
                Text("\(store.redBookTracks.count) Audio Tracks • 75 fps (2,352 B/sector)")
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(.secondary)
            }

            Divider()

            ScrollView {
                Text(cueText)
                    .font(.system(size: 11, design: .monospaced))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .textSelection(.enabled)
            }
            .frame(height: 220)
            .padding(8)
            .background(Color.black.opacity(0.22))
            .clipShape(RoundedRectangle(cornerRadius: 6))
        }
        .padding(14)
        .frame(width: 560)
    }



    @ViewBuilder
    func videoOvenBitrateAndShrinkPopoverView(
        for spec: KroutonRecipeSpec,
        isBluRay: Bool,
        isDualLayer: Bool
    ) -> some View {
        let medium: KroutonVideoTargetMedium = {
            if isBluRay {
                return isDualLayer ? .bd50DualLayer : .bd25SingleLayer
            } else {
                return isDualLayer ? .dvd9DualLayer : .dvd5SingleLayer
            }
        }()
        let stagedBytes = store.stagedFiles.reduce(Int64(0)) { $0 + $1.byteSize }
        // Estimate program duration from staged files (or default to 110-min feature film = 6,600s)
        let estimatedDurationSec: Double = stagedBytes > 0
            ? max(300.0, min(14_400.0, Double(stagedBytes) / 750_000.0))
            : 6_600.0
        let budget = store.computeLiveVideoOvenBitrateBudget(
            durationSeconds: estimatedDurationSec,
            audioKbps: isBluRay ? 1_536 : 448,
            medium: medium
        )
        let mainBytes: Int64 = stagedBytes > 4_700_372_992 ? stagedBytes : 6_850_000_000
        let extrasBytes: Int64 = 880_000_000
        let shrinkPlan = KroutonVideoOvenModule.planDVD9ToDVD5Shrink(
            mainFeatureBytes: mainBytes,
            menusAndExtrasBytes: extrasBytes,
            preserveMenusAndExtras: store.fitToDiscPreserveMenus
        )

        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: "film.stack.fill")
                    .foregroundStyle(store.activeAccent)
                Text("VIDEOOVEN BITRATE BUDGET & REQUIEM SHRINK INSPECTOR")
                    .font(.system(size: 11, weight: .heavy, design: .monospaced))
                Spacer()
                Button {
                    let summary = """
                    MEDIUM: \(medium.rawValue) (\(medium.totalSectorsLBA) LBA sectors / \(medium.capacityBytes) B)
                    TARGET VIDEO BITRATE: \(budget.targetVideoKbps) kbps (Max Ceiling: \(budget.maxHardwareCeilingKbps) kbps)
                    VBV BUFFER: \(budget.vbvBufferKilobits) kilobits • Audio: \(budget.audioBitrateKbps) kbps
                    DVD-9 -> DVD-5 REQUIEM SHRINK RATIO: \(String(format: "%.1f%%", shrinkPlan.requantizationRatio * 100.0))
                    ESTIMATED OUTPUT: \(shrinkPlan.estimatedOutputBytes) bytes (Preserve Menus: \(shrinkPlan.preserveMenusAndExtras))
                    """
                    KroutonOSDesktopBridge.copyTextToClipboard(summary)
                } label: {
                    Label("Copy Budget", systemImage: "doc.on.doc")
                        .font(.caption.bold())
                }
                .buttonStyle(.borderedProminent)
                .tint(store.activeAccent)
            }

            Divider()

            VStack(alignment: .leading, spacing: 5) {
                Text("• Target Optical Medium : \(medium.rawValue) (\(medium.totalSectorsLBA) × 2048-B sectors)")
                Text("• Target Video Bitrate  : \(budget.targetVideoKbps) kbps (Hardware Spec Ceiling: \(budget.maxHardwareCeilingKbps) kbps)")
                    .foregroundStyle(store.activeAccent)
                Text("• VBV Decoder Buffer    : \(budget.vbvBufferKilobits) kilobits • Audio Stream: \(budget.audioBitrateKbps) kbps")
                Text(String(format: "• Usable Video Payload  : %.2f GB (Est. Disc Fill: %.1f%%)", Double(budget.usableVideoBytes) / 1_000_000_000.0, budget.estimatedDiscFillRatio * 100.0))
                    .foregroundStyle(.green)
            }
            .font(.system(size: 11, design: .monospaced))

            Divider()

            VStack(alignment: .leading, spacing: 5) {
                HStack {
                    Image(systemName: "arrow.down.right.and.arrow.up.left")
                        .foregroundStyle(.orange)
                    Text("DVD-9 (8.54 GB DL) -> DVD-5 (4.70 GB SL) REQUIEM DCT REQUANTIZATION PLAN")
                        .font(.system(size: 10, weight: .heavy, design: .monospaced))
                        .foregroundStyle(.orange)
                }
                Text(String(format: "• Main Feature DCT Retention : %.1f%% (%@)", shrinkPlan.requantizationRatio * 100.0, fitToDiscDVD9Shrink ? "ACTIVE" : "STANDBY"))
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                Text(String(format: "• Menus & Bonus Features     : %@ (%.2f GB source)", shrinkPlan.preserveMenusAndExtras ? "Preserved at 90% Fidelity" : "Stripped (Main Movie Only)", Double(shrinkPlan.sourceMenusAndExtrasBytes) / 1_000_000_000.0))
                    .font(.system(size: 10, design: .monospaced))
                Text(String(format: "• Requantized VTS Output     : %.3f GB / %.3f GB DVD-5 Safe Ceiling", Double(shrinkPlan.estimatedOutputBytes) / 1_000_000_000.0, Double(shrinkPlan.targetUsableDVD5Bytes) / 1_000_000_000.0))
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(.secondary)
            }
            .padding(8)
            .background(Color.black.opacity(0.20))
            .clipShape(RoundedRectangle(cornerRadius: 6))

            let sampleCells = [
                KroutonDVD9CellDescriptor(cellID: 1, originalStartSectorLBA: 0, originalSectorCountLBA: 1_100_000, hadDualLayerBreakPause: false),
                KroutonDVD9CellDescriptor(cellID: 2, originalStartSectorLBA: 1_100_000, originalSectorCountLBA: 1_050_000, hadDualLayerBreakPause: true),
                KroutonDVD9CellDescriptor(cellID: 3, originalStartSectorLBA: 2_150_000, originalSectorCountLBA: 1_190_000, hadDualLayerBreakPause: false)
            ]
            let blueprint = KroutonVideoOvenModule.buildDVD9ToDVD5MenuShrinkBlueprint(
                menuVobBytes: extrasBytes,
                preserveMenus: store.fitToDiscPreserveMenus,
                sourceCells: sampleCells
            )

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Image(systemName: "MenuCard" == "" ? "list.bullet.rectangle.fill" : "menubar.rectangle")
                        .foregroundStyle(.cyan)
                    Text("DVD-9 -> DVD-5 MENU BUTTONS, .IFO RELINKING & LAYER-BREAK REMOVAL")
                        .font(.system(size: 10, weight: .heavy, design: .monospaced))
                        .foregroundStyle(.cyan)
                }
                Text("• Menu NV_PCK & SPU Highlights : 100% Bit-Exact Passthrough (Menu Video @ \(Int(blueprint.menuVobRetentionRatio * 100))%)")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundStyle(.green)
                Text("• VTS_01_0.IFO / .BUP Pointers : \(blueprint.relinkedCells.count) PGC Cells Relinked to Shrunk VOBU Sectors (32K ECC Guarded)")
                    .font(.system(size: 10, design: .monospaced))
                Text("• Former DVD-9 Layer-Break Cell: \(blueprint.layerBreakPauseRemoved ? "SPLB Pause Flag Cleared -> 100% Seamless DVD-5 Playback" : "Seamless")")
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(store.activeAccent)
            }
            .padding(8)
            .background(Color.black.opacity(0.20))
            .clipShape(RoundedRectangle(cornerRadius: 6))
        }
        .padding(14)
        .frame(width: 575)
    }

}
