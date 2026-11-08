import SwiftUI
import OpticalDough

public enum KroutonWorkspaceTab: String, CaseIterable, Identifiable {
    case data = "Data"
    case audio = "Audio"
    case video = "Video"
    case copyShrink = "Copy / Shrink"
    case boot = "Tartine Boot"
    case label = "Galette Label"
    case crustini = "Crustini"

    public var id: String { rawValue }

    public var sfSymbol: String {
        switch self {
        case .data: return "externaldrive.fill.badge.plus"
        case .audio: return "waveform.circle.fill"
        case .video: return "film.stack.fill"
        case .copyShrink: return "opticaldisc.fill"
        case .boot: return "terminal.fill"
        case .label: return "printer.dotmatrix.fill"
        case .crustini: return "cpu.fill"
        }
    }
}

@main
struct KroutonApp: App {
    @StateObject private var driveManager = DriveManager()
    @State private var selectedTab: KroutonWorkspaceTab = .data
    @State private var selectedDiscCapacityGB: Double = 4.7
    @State private var usedCapacityGB: Double = 3.42
    @State private var finderBgColor: Color = Color(red: 0.12, green: 0.16, blue: 0.24)
    @State private var finderIconSize: Double = 256
    @State private var carSafeMP3Mode: Bool = true
    @State private var autoJamCrossfade: Bool = true
    @State private var dvd9ToDvd5Shrink: Bool = true

    var body: some Scene {
        WindowGroup("Krouton v0.1.0-alpha.1") {
            VStack(spacing: 0) {
                HStack(spacing: 12) {
                    HStack(spacing: 8) {
                        Image(systemName: "opticaldisc.fill")
                            .font(.system(size: 22, weight: .bold))
                            .foregroundStyle(.orange)
                        VStack(alignment: .leading, spacing: 1) {
                            Text("KROUTON")
                                .font(.system(size: 13, weight: .heavy, design: .rounded))
                            Text("v0.1.0-alpha.1")
                                .font(.system(size: 10, design: .monospaced))
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.trailing, 8)

                    ForEach(KroutonWorkspaceTab.allCases) { tab in
                        Button {
                            selectedTab = tab
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: tab.sfSymbol)
                                Text(tab.rawValue)
                                    .font(.system(size: 12, weight: .semibold))
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(selectedTab == tab ? Color.orange.opacity(0.22) : Color.clear)
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                        }
                        .buttonStyle(.plain)
                    }
                    Spacer()
                }
                .padding(12)
                .background(.ultraThinMaterial)

                Divider()

                HSplitView {
                    VStack(alignment: .leading, spacing: 16) {
                        Text("\(selectedTab.rawValue.uppercased()) OPTIONS")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(.secondary)

                        switch selectedTab {
                        case .data:
                            Toggle("Hybrid Mac (HFS+) & PC (UDF/ISO)", isOn: .constant(true))
                            Divider()
                            Text("Finder Window Customization")
                                .font(.headline)
                            ColorPicker("Finder Background Color", selection: $finderBgColor)
                            VStack(alignment: .leading) {
                                Text("Finder Icon Size: \(Int(finderIconSize)) px")
                                    .font(.caption)
                                Slider(value: $finderIconSize, in: 64...512, step: 32)
                            }
                            Toggle("Generate Windows autorun.inf", isOn: .constant(true))
                        case .audio:
                            Toggle("Write CD-TEXT & ISRC Subcodes", isOn: .constant(true))
                            Toggle("ML Auto-Jam Beat Crossfades", isOn: $autoJamCrossfade)
                            Toggle("Car-Stereo Safe MP3 Mode", isOn: $carSafeMP3Mode)
                            Text("Strips macOS ._* AppleDouble files and locks ID3v2.3 tags.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        case .video, .copyShrink:
                            Toggle("Fit DVD-9 (8.5 GB) to DVD-5 (4.7 GB)", isOn: $dvd9ToDvd5Shrink)
                            Toggle("Preserve Original Menus & Extras", isOn: .constant(true))
                            Toggle("Allow Blu-ray BDMV on DVD (BD-5/9)", isOn: .constant(true))
                        case .boot:
                            Text("Tartine Verified Sources")
                                .font(.headline)
                            Label("FreeDOS 1.4 Live + BIOS Room", systemImage: "checkmark.shield.fill")
                            Label("SystemRescue 11 (x86_64/ARM)", systemImage: "checkmark.shield.fill")
                            Label("Internet Archive (archive.org)", systemImage: "globe")
                        case .label:
                            Text("Epson EcoTank Photo ET-8550")
                                .font(.headline)
                            Text("Outer Diameter: 120.0 mm\nInner Hub Hole: 18.0 mm\nColor Profile: Claria ET 6-Ink")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        case .crustini:
                            Text("Crustini Experimental Vault")
                                .font(.headline)
                            Toggle("Classic Mac OS 9 Bootable HFS", isOn: .constant(true))
                            Toggle("Console ROM Sector Rebuilder", isOn: .constant(true))
                            Toggle("Hidden Track One Audio (HTOA)", isOn: .constant(false))
                        }
                        Spacer()
                    }
                    .padding(16)
                    .frame(minWidth: 250, maxWidth: 290)
                    .background(Color(NSColor.controlBackgroundColor))

                    VStack(alignment: .leading, spacing: 14) {
                        HStack {
                            Label("Project Staging Area — \(selectedTab.rawValue)", systemImage: selectedTab.sfSymbol)
                                .font(.title3.bold())
                            Spacer()
                            Button {
                            } label: {
                                Label("Add Files or Drop Folders", systemImage: "plus.rectangle.on.folder.fill")
                            }
                        }

                        RoundedRectangle(cornerRadius: 10)
                            .fill(selectedTab == .data ? finderBgColor : Color(NSColor.textBackgroundColor))
                            .overlay(
                                VStack(spacing: 12) {
                                    Image(systemName: selectedTab.sfSymbol)
                                        .font(.system(size: 42))
                                        .foregroundStyle(.orange)
                                    Text("Drop media, folders, or disc images here")
                                        .font(.headline)
                                    Text("Active target: \(driveManager.selectedDrive?.displayName ?? "No Drive")")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            )
                    }
                    .padding(18)
                }

                Divider()

                HStack(spacing: 16) {
                    HStack(spacing: 8) {
                        Image(systemName: (driveManager.selectedDrive?.isNetworkNode == true) ? "network" : "internaldrive.fill")
                            .foregroundStyle(.orange)
                        Picker("Recorder:", selection: $driveManager.selectedDrive) {
                            ForEach(driveManager.availableDrives) { drive in
                                Text(drive.displayName).tag(Optional(drive))
                            }
                        }
                        .frame(width: 280)

                        Button {
                            driveManager.refreshDrives()
                        } label: {
                            Image(systemName: "arrow.clockwise")
                        }
                        .help("Rescan Local & krouton-node Network Drives")

                        Button {
                        } label: {
                            Image(systemName: "eject.fill")
                        }
                        .help("Eject Disc")
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text(String(format: "%.2f GB of %.1f GB used", usedCapacityGB, selectedDiscCapacityGB))
                                .font(.system(size: 11, weight: .medium, design: .monospaced))
                            Spacer()
                            Picker("", selection: $selectedDiscCapacityGB) {
                                Text("CD (700 MB)").tag(0.7)
                                Text("DVD-5 (4.7 GB)").tag(4.7)
                                Text("DVD-9 (8.5 GB)").tag(8.5)
                                Text("BD-25 (25 GB)").tag(25.0)
                                Text("BD-50 (50 GB)").tag(50.0)
                            }
                            .labelsHidden()
                            .frame(width: 135)
                        }
                        ProgressView(value: min(usedCapacityGB, selectedDiscCapacityGB), total: selectedDiscCapacityGB)
                            .tint(.orange)
                    }

                    Button {
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "flame.fill")
                            Text("BURN")
                                .font(.system(size: 13, weight: .heavy))
                        }
                        .padding(.horizontal, 18)
                        .padding(.vertical, 10)
                        .background(Color.orange)
                        .foregroundStyle(.black)
                        .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(.ultraThinMaterial)
            }
            .frame(minWidth: 980, minHeight: 620)
        }
    }
}
