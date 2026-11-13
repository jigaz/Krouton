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

struct KroutonDiscImageInspectorWorkspaceView: View {
    @ObservedObject var store: KroutonStateStore
    let spec: KroutonRecipeSpec
    @Binding var isDropTargeted: Bool
    let onPromptToAddFiles: () -> Void
    let onHandleFinderDrop: ([NSItemProvider]) -> Bool

    @State private var discImageWriteMethod: String = "DAO / SAO Sector-Exact (Preserve System Area & Boot Catalog)"
    @State private var verifyImageSHA256BeforeBurn: Bool = true
    @State private var inspectedImageLBA: Int = 17
    @State private var computedImageSHA256: String = ""
    @State private var imageActionStatusBanner: String = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Top Mastering Bar
            KroutonMasteringDeckCard(store: store) {
                VStack(alignment: .leading, spacing: 8) {
                    ViewThatFits(in: .horizontal) {
                        HStack(spacing: 8) {
                            Image(systemName: "opticaldisc.fill")
                                .foregroundStyle(store.activeAccent)
                                .accessibilityHidden(true)
                            Text(KroutonL10n.tr("SECTOR-EXACT DISC IMAGE INSPECTOR & BOOTABLE OS BURNER"))
                                .font(.system(size: 10, weight: .heavy, design: .monospaced))
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                                .fixedSize(horizontal: true, vertical: false)
                            Spacer(minLength: 8)
                            Text(imageActionStatusBanner.isEmpty ? "FORMATS: .ISO • .DMG • .CDR • .BIN/.CUE • .IMG • .TOAST" : "[ \(imageActionStatusBanner) ]")
                                .font(.system(size: 9, weight: .bold, design: .monospaced))
                                .foregroundStyle(imageActionStatusBanner.isEmpty ? .secondary : store.activeAccent)
                                .lineLimit(1)
                                .fixedSize(horizontal: true, vertical: false)
                        }

                        HStack(spacing: 6) {
                            Image(systemName: "opticaldisc.fill")
                                .foregroundStyle(store.activeAccent)
                                .accessibilityHidden(true)
                            Text(KroutonL10n.tr("DISC IMAGE INSPECTOR"))
                                .font(.system(size: 10, weight: .heavy, design: .monospaced))
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                            Spacer(minLength: 4)
                            Text(".ISO • .DMG • .BIN")
                                .font(.system(size: 9, weight: .bold, design: .monospaced))
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                                .fixedSize(horizontal: true, vertical: false)
                        }
                    }

                    ViewThatFits(in: .horizontal) {
                        HStack(spacing: 14) {
                            HStack(spacing: 6) {
                                Text(KroutonL10n.tr("Laser Write Topology:")).font(.caption.bold()).lineLimit(1)
                                Picker("", selection: $discImageWriteMethod) {
                                    Text("DAO / SAO Sector-Exact (Preserve System Area & Boot Catalog)").tag("DAO / SAO Sector-Exact (Preserve System Area & Boot Catalog)")
                                    Text("RAW DAO/96 (2,352 B/sec + Subchannel PQ/RW Intact)").tag("RAW DAO/96 (2,352 B/sec + Subchannel PQ/RW Intact)")
                                    Text("DVD+R / BD-R Seamless Layer Break (16-Sector ECC Aligned)").tag("DVD+R / BD-R Seamless Layer Break (16-Sector ECC Aligned)")
                                }
                                .labelsHidden()
                                .fixedSize(horizontal: true, vertical: false)
                                .font(.caption)
                                .accessibilityLabel(KroutonL10n.tr("Laser Write Topology"))
                            }

                            Toggle(KroutonL10n.tr("Verify SHA-256 Digest Before Write"), isOn: $verifyImageSHA256BeforeBurn)
                                .toggleStyle(.checkbox)
                                .font(.caption.bold())
                                .lineLimit(1)
                                .fixedSize(horizontal: true, vertical: false)
                            Spacer(minLength: 0)
                        }

                        VStack(alignment: .leading, spacing: 6) {
                            HStack(spacing: 6) {
                                Text(KroutonL10n.tr("Write:")).font(.caption.bold()).lineLimit(1)
                                Picker("", selection: $discImageWriteMethod) {
                                    Text("DAO / SAO Sector-Exact").tag("DAO / SAO Sector-Exact (Preserve System Area & Boot Catalog)")
                                    Text("RAW DAO/96 (2,352B + SubQ)").tag("RAW DAO/96 (2,352 B/sec + Subchannel PQ/RW Intact)")
                                    Text("Seamless Layer Break (16-Sec ECC)").tag("DVD+R / BD-R Seamless Layer Break (16-Sector ECC Aligned)")
                                }
                                .labelsHidden()
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .font(.caption)
                                .accessibilityLabel(KroutonL10n.tr("Write Mode"))
                            }

                            Toggle(KroutonL10n.tr("Verify SHA-256 Digest Before Write"), isOn: $verifyImageSHA256BeforeBurn)
                                .toggleStyle(.checkbox)
                                .font(.caption.bold())
                                .lineLimit(1)
                        }
                    }
                }
            }

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
                    KroutonEmptyDropZoneView(
                        store: store,
                        isDropTargeted: isDropTargeted,
                        sfSymbol: "opticaldisc.fill",
                        symbolSize: 46,
                        headline: "Drop a Disc Image (.ISO, .DMG, .BIN/.CUE, .IMG, or .TOAST)",
                        subtitle: "Displays radial track geometry, live LBA 0/16/17/256 hexadecimal sector dumps, El Torito / APM boot records, and 1-Click .BIN <-> .ISO framing conversion.",
                        actionTitle: "Choose Disc Image File...",
                        onAction: onPromptToAddFiles
                    )
                }
            }
            .onDrop(of: [.fileURL], isTargeted: $isDropTargeted) { providers in
                // When in single-image mode, dropping a new disc image replaces the old one cleanly
                store.clearStagedFiles()
                computedImageSHA256 = ""
                imageActionStatusBanner = ""
                return onHandleFinderDrop(providers)
            }
        }
    }

}
