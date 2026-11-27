import Foundation
import SwiftUI

// MARK: - AVCHD Panel

/// Makes a high-definition disc image from the staged video files (see `KroutonAVCHDController`).
struct KroutonAVCHDPanelView: View {
    var store: KroutonStateStore

    var body: some View {
        let avchd = store.avchd
        let sources = store.stagedFiles.filter { !$0.isDirectory }.map(\.url)
        KroutonMasteringDeckCard(store: store) {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    Image(systemName: "sparkles.tv.fill").foregroundStyle(store.activeAccent)
                    Text("High-definition video on a DVD").font(.system(size: 12, weight: .semibold))
                    Spacer(minLength: 4)
                    Picker("Disc", selection: Bindable(avchd).dualLayer) {
                        Text("DVD, 4.7 GB").tag(false)
                        Text("Dual-layer DVD, 8.5 GB").tag(true)
                    }
                    .labelsHidden().fixedSize().disabled(avchd.isRunning)
                    if avchd.isRunning {
                        Button("Stop") { avchd.stop() }.controlSize(.small)
                    } else {
                        Button("Make Disc Image") {
                            avchd.start(sources: sources, label: store.discVolumeTitle) { image in
                                store.stageImageForBurning(image)
                            }
                        }
                        .buttonStyle(.borderedProminent).controlSize(.small)
                        .disabled(sources.isEmpty || !avchd.ffmpegInstalled)
                    }
                }
                Text("The videos play one after another as a single title, with a chapter at each video and every five minutes. Each is converted to 1080p or 720p H.264 with Dolby Digital sound, at up to 18 Mbit/s or less if needed to fit.")
                    .font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                if avchd.isRunning {
                    ProgressView(value: avchd.fraction)
                }
                Text(avchd.ffmpegInstalled ? avchd.status : "Needs ffmpeg: install it (for example: brew install ffmpeg), then come back to this workspace.")
                    .font(.caption).foregroundStyle(avchd.ffmpegInstalled ? Color.primary : Color.orange)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .contextMenu {
            if let image = avchd.lastImage {
                Button("Burn the Last Image Again") { store.stageImageForBurning(image) }
            }
        }
    }
}
