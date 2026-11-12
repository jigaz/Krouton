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

struct KroutonRetroConsoleWorkspaceView: View {
    @ObservedObject var store: KroutonStateStore
    let spec: KroutonRecipeSpec
    let isCenterWorkspaceNarrow: Bool
    @Binding var isDropTargeted: Bool
    let onHandleFinderDrop: ([NSItemProvider]) -> Bool

    @State private var romWriteModeDAO96SubQ: Bool = true
    @State private var romBitsetDVDROM: Bool = true
    @State private var romPerformOPCBeforeWrite: Bool = true
    @State private var xboxLayerBreakPreset: String = "Auto (.dvd / Calculate Optimal)"
    @State private var ps1AutoMergeMultiBinAndCHD: Bool = true
    @State private var ps2ApplyESRPatch: Bool = false
    @State private var gcPadToOuterEdge3GB: Bool = true
    @State private var wiiLayerMode: String = "Auto-Detect (DVD5 4.7GB / DVD9 LBA 2084960)"
    @State private var xboxVerifyStealthSectors: Bool = true

    var body: some View {
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
                    let consoleHeadline: String = {
                        if isCenterWorkspaceNarrow { return KroutonL10n.tr("Drop Console Disc Image") }
                        switch spec.id {
                        case "console-wii": return KroutonL10n.tr("Drop Nintendo Wii Disc Image (.RVZ, .WBFS, .ISO)")
                        case "console-gc": return KroutonL10n.tr("Drop GameCube Mini-DVD Image (.RVZ, .GCM, .ISO)")
                        case "console-ps2": return KroutonL10n.tr("Drop PlayStation 2 Disc Image (.ISO, .CHD, .CUE + .BIN)")
                        case "console-ps1": return KroutonL10n.tr("Drop PlayStation 1 Disc Image (.CUE + .BIN, .CHD, .CCD)")
                        case "console-xbox": return KroutonL10n.tr("Drop Xbox Disc Image (.ISO, .XISO, .DVD)")
                        default: return KroutonL10n.tr("Drop Console Disc Image")
                        }
                    }()
                    let consoleSubtext: String = {
                        switch spec.id {
                        case "console-wii":
                            return KroutonL10n.tr("Krouton verifies RVL-006 partition tables, rebuilds scrubbed sectors on the fly, and aligns Dual-Layer DVD9 break LBA 2084960.")
                        case "console-gc":
                            return KroutonL10n.tr("Krouton verifies 1,459,978,240-byte (712,880 LBA) DOL-006 layout, 32 KB ECC alignment, and optional 3.0 GB outer-edge laser padding.")
                        case "console-ps2":
                            return KroutonL10n.tr("Krouton auto-detects PS2 CD-ROM (<700 MB Mode 2 XA) vs PS2 DVD-ROM (UDF 1.02 + ISO9660 Bridge), SYSTEM.CNF boot ID, and ESR patching.")
                        case "console-ps1":
                            return KroutonL10n.tr("Krouton verifies 2,352-byte Mode 2 Form 1/2 XA sectors, System Area license strings, Red Book CD-DA pre-gaps, and LibCrypt Subchannel Q.")
                        case "console-xbox":
                            return KroutonL10n.tr("Krouton verifies Microsoft XDVDFS partition headers, SS/DMI/PFI stealth security sectors, and XGD2 (1913760) / XGD3 (2133520) layer breaks.")
                        default:
                            return KroutonL10n.tr("Krouton verifies 2,352-byte Mode 2 XA sector headers, System Area boot licenses, and Dual-Layer XGD break offsets.")
                        }
                    }()
                    KroutonEmptyDropZoneView(
                        store: store,
                        isDropTargeted: isDropTargeted,
                        sfSymbol: spec.sfSymbol,
                        headline: consoleHeadline,
                        subtitle: consoleSubtext
                    )
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
                onHandleFinderDrop(providers)
            }
        }
    }

    func retroConsoleROMMasteringDeck(for spec: KroutonRecipeSpec) -> some View {
        KroutonMasteringDeckCard(store: store, paddingAmount: 12) {
            VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "gamecontroller.fill")
                    .foregroundStyle(store.activeAccent)
                Text(isCenterWorkspaceNarrow ? KroutonL10n.tr("CONSOLE MASTERING PROFILE") : KroutonL10n.tr("RETRO CONSOLE HARDWARE MASTERING PROFILE"))
                    .font(.system(size: 10, weight: .heavy, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                Spacer(minLength: 4)
                Toggle(isCenterWorkspaceNarrow ? KroutonL10n.tr("OPC Calibration") : KroutonL10n.tr("Perform OPC Before Write"), isOn: $romPerformOPCBeforeWrite)
                    .toggleStyle(.checkbox)
                    .font(.caption)
                    .fixedSize()
            }

            Divider().opacity(0.5)

            if spec.id == "console-ps1" {
                VStack(alignment: .leading, spacing: 6) {
                    ViewThatFits(in: .horizontal) {
                        HStack(spacing: 14) {
                            Toggle(KroutonL10n.tr("DAO/96 Raw Mode 2 XA (2,352 B/sec + SubQ LibCrypt)"), isOn: $romWriteModeDAO96SubQ)
                                .toggleStyle(.checkbox)
                                .font(.caption.bold())
                            Toggle(KroutonL10n.tr("Auto-Decompress .CHD & Merge Multi-Track .BIN/.CUE"), isOn: $ps1AutoMergeMultiBinAndCHD)
                                .toggleStyle(.checkbox)
                                .font(.caption)
                            Spacer(minLength: 0)
                        }
                        VStack(alignment: .leading, spacing: 6) {
                            Toggle(KroutonL10n.tr("DAO/96 Raw Mode 2 XA (2,352 B/sec + SubQ)"), isOn: $romWriteModeDAO96SubQ)
                                .toggleStyle(.checkbox)
                                .font(.caption.bold())
                            Toggle(KroutonL10n.tr("Auto-Expand .CHD & Merge Multi-BIN"), isOn: $ps1AutoMergeMultiBinAndCHD)
                                .toggleStyle(.checkbox)
                                .font(.caption)
                        }
                    }
                    HStack(spacing: 6) {
                        Image(systemName: "laser.burst")
                            .font(.system(size: 10))
                            .foregroundStyle(store.uiSecondaryAccent)
                        Text(KroutonL10n.tr("4x–8x CLV Guard Active • High-Reflectivity 700 MB CD-R Only (Preserves 2s Pre-Gaps & Red Book CD-DA)"))
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
            } else if spec.id == "console-ps2" {
                VStack(alignment: .leading, spacing: 6) {
                    ViewThatFits(in: .horizontal) {
                        HStack(spacing: 14) {
                            Toggle(KroutonL10n.tr("Stamp Book Type as DVD-ROM (PS2 Mechacon Bitsetting)"), isOn: $romBitsetDVDROM)
                                .toggleStyle(.checkbox)
                                .font(.caption.bold())
                            Toggle(KroutonL10n.tr("Apply ESR DVD-Video Descriptor Patch (FMCB / Softmod)"), isOn: $ps2ApplyESRPatch)
                                .toggleStyle(.checkbox)
                                .font(.caption)
                            Spacer(minLength: 0)
                        }
                        VStack(alignment: .leading, spacing: 6) {
                            Toggle(KroutonL10n.tr("Stamp Book Type as DVD-ROM (Mechacon)"), isOn: $romBitsetDVDROM)
                                .toggleStyle(.checkbox)
                                .font(.caption.bold())
                            Toggle(KroutonL10n.tr("Apply ESR DVD-Video Patch (FMCB)"), isOn: $ps2ApplyESRPatch)
                                .toggleStyle(.checkbox)
                                .font(.caption)
                        }
                    }
                    HStack(spacing: 6) {
                        Image(systemName: "opticaldisc")
                            .font(.system(size: 10))
                            .foregroundStyle(store.uiSecondaryAccent)
                        Text(KroutonL10n.tr("Auto-Detects PS2 CD (<700 MB Mode 2 XA) vs PS2 DVD (>700 MB UDF 1.02 + ISO9660 Bridge) + .CHD Support"))
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
            } else if spec.id == "console-gc" {
                VStack(alignment: .leading, spacing: 6) {
                    ViewThatFits(in: .horizontal) {
                        HStack(spacing: 14) {
                            Toggle(KroutonL10n.tr("DVD-ROM Book Type + 32 KB ECC Boundary Alignment"), isOn: $romBitsetDVDROM)
                                .toggleStyle(.checkbox)
                                .font(.caption.bold())
                            Toggle(KroutonL10n.tr("Pad 1.46 GB Image to 3.0 GB Outer Edge (120mm DVD-R Laser Helper)"), isOn: $gcPadToOuterEdge3GB)
                                .toggleStyle(.checkbox)
                                .font(.caption)
                            Spacer(minLength: 0)
                        }
                        VStack(alignment: .leading, spacing: 6) {
                            Toggle(KroutonL10n.tr("DVD-ROM Bitset + 32 KB ECC Alignment"), isOn: $romBitsetDVDROM)
                                .toggleStyle(.checkbox)
                                .font(.caption.bold())
                            Toggle(KroutonL10n.tr("Pad 1.46 GB to 3.0 GB (120mm DVD-R Helper)"), isOn: $gcPadToOuterEdge3GB)
                                .toggleStyle(.checkbox)
                                .font(.caption)
                        }
                    }
                    HStack(spacing: 6) {
                        Image(systemName: "cpu")
                            .font(.system(size: 10))
                            .foregroundStyle(store.uiSecondaryAccent)
                        Text(KroutonL10n.tr("Exact 80mm Mini-DVD Target: 1,459,978,240 Bytes (712,880 LBA) • Native .GCM / .ISO / .RVZ Auto-Expand"))
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
            } else if spec.id == "console-wii" {
                VStack(alignment: .leading, spacing: 6) {
                    ViewThatFits(in: .horizontal) {
                        HStack(spacing: 12) {
                            Picker("Layer Mode:", selection: $wiiLayerMode) {
                                Text("Auto (DVD5 4.7GB / DVD9 DL)").tag("Auto-Detect (DVD5 4.7GB / DVD9 LBA 2084960)")
                                Text("Single-Layer DVD5 (2,294,912 LBA)").tag("Single-Layer DVD5")
                                Text("Dual-Layer DVD9 (Break LBA 2084960)").tag("Dual-Layer DVD9")
                            }
                            .font(.caption)
                            .frame(maxWidth: 280)

                            Toggle(KroutonL10n.tr("DVD-ROM Bitset + 32 KB ECC Alignment"), isOn: $romBitsetDVDROM)
                                .toggleStyle(.checkbox)
                                .font(.caption.bold())
                            Spacer(minLength: 0)
                        }
                        VStack(alignment: .leading, spacing: 6) {
                            Picker("Layer Mode:", selection: $wiiLayerMode) {
                                Text("Auto (DVD5 / DVD9 DL)").tag("Auto-Detect (DVD5 4.7GB / DVD9 LBA 2084960)")
                                Text("Single-Layer DVD5").tag("Single-Layer DVD5")
                                Text("Dual-Layer DVD9 (LBA 2084960)").tag("Dual-Layer DVD9")
                            }
                            .font(.caption)
                            Toggle(KroutonL10n.tr("DVD-ROM Bitset + 32 KB ECC Alignment"), isOn: $romBitsetDVDROM)
                                .toggleStyle(.checkbox)
                                .font(.caption.bold())
                        }
                    }
                    HStack(spacing: 6) {
                        Image(systemName: "arrow.triangle.2.circlepath")
                            .font(.system(size: 10))
                            .foregroundStyle(store.uiSecondaryAccent)
                        Text(KroutonL10n.tr("Accepts .ISO, .WBFS & Dolphin .RVZ (Auto-Rebuilds Partition Tables & Scrubbed Sectors on Burn)"))
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
            } else if spec.id == "console-xbox" {
                VStack(alignment: .leading, spacing: 6) {
                    ViewThatFits(in: .horizontal) {
                        HStack(spacing: 12) {
                            Picker("Layer Break:", selection: $xboxLayerBreakPreset) {
                                Text(KroutonL10n.tr("Auto (.dvd Descriptor)")).tag("Auto (.dvd / Calculate Optimal)")
                                Text(KroutonL10n.tr("XGD2 Lock (LBA 1913760)")).tag("XGD2 (1913760)")
                                Text(KroutonL10n.tr("XGD3 Lock (LBA 2133520)")).tag("XGD3 (2133520)")
                            }
                            .font(.caption)
                            .frame(maxWidth: 245)

                            Toggle(KroutonL10n.tr("DVD+R DL → DVD-ROM Bitset"), isOn: $romBitsetDVDROM)
                                .toggleStyle(.checkbox)
                                .font(.caption.bold())

                            Toggle(KroutonL10n.tr("Verify SS/DMI/PFI Stealth"), isOn: $xboxVerifyStealthSectors)
                                .toggleStyle(.checkbox)
                                .font(.caption)
                            Spacer(minLength: 0)
                        }
                        VStack(alignment: .leading, spacing: 6) {
                            Picker("Layer Break:", selection: $xboxLayerBreakPreset) {
                                Text(KroutonL10n.tr("Auto (.dvd Descriptor)")).tag("Auto (.dvd / Calculate Optimal)")
                                Text(KroutonL10n.tr("XGD2 Lock (LBA 1913760)")).tag("XGD2 (1913760)")
                                Text(KroutonL10n.tr("XGD3 Lock (LBA 2133520)")).tag("XGD3 (2133520)")
                            }
                            .font(.caption)
                            HStack(spacing: 12) {
                                Toggle(KroutonL10n.tr("DVD-ROM Bitset"), isOn: $romBitsetDVDROM)
                                    .toggleStyle(.checkbox)
                                    .font(.caption.bold())
                                Toggle(KroutonL10n.tr("Verify SS/DMI/PFI"), isOn: $xboxVerifyStealthSectors)
                                    .toggleStyle(.checkbox)
                                    .font(.caption)
                            }
                        }
                    }
                    HStack(spacing: 6) {
                        Image(systemName: "checkmark.shield.fill")
                            .font(.system(size: 10))
                            .foregroundStyle(store.uiSecondaryAccent)
                        Text(KroutonL10n.tr("XDVDFS / XISO Topology • Locks Layer 0→1 Transition Sector & Verifies Stealth Security Sectors"))
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
            }
            }
        }
    }


}
