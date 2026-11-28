import DriveKit
import SwiftUI

// MARK: - Live Progress in the Menu Bar

/// The menu bar item's label: a disc and the progress of what's running.
struct KroutonMenuBarStatusLabel: View {
    var store: KroutonStateStore
    var driveManager: KroutonOpticalDriveBank

    var body: some View {
        let items = KroutonLiveStatus.items(store: store, driveManager: driveManager)
        let text = KroutonLiveStatus.labelText(items)
        HStack(spacing: 3) {
            Image(systemName: items.isEmpty ? "opticaldisc" : "opticaldisc.fill")
            if !text.isEmpty { Text(verbatim: text).monospacedDigit() }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(items.isEmpty ? KroutonL10n.tr("Krouton") : String(format: KroutonL10n.tr("Krouton: %@"), items.map(\.title).joined(separator: ", ")))
    }
}

/// What opens from the menu bar item: each task with its progress, and a way back to the window.
struct KroutonMenuBarStatusView: View {
    var store: KroutonStateStore
    var driveManager: KroutonOpticalDriveBank
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        let items = KroutonLiveStatus.items(store: store, driveManager: driveManager)
        VStack(alignment: .leading, spacing: 12) {
            if items.isEmpty {
                Label(KroutonL10n.tr("Nothing is running"), systemImage: "checkmark.circle")
                    .foregroundStyle(.secondary)
            }
            ForEach(items) { item in
                VStack(alignment: .leading, spacing: 4) {
                    Label(item.title, systemImage: item.symbol)
                        .font(.headline)
                        .lineLimit(1)
                    if let fraction = item.fraction {
                        ProgressView(value: fraction)
                            .accessibilityValue(Text(verbatim: "\(Int((fraction * 100).rounded()))%"))
                    } else {
                        ProgressView().progressViewStyle(.linear)
                    }
                    if !item.detail.isEmpty {
                        Text(item.detail)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                    }
                }
                .contextMenu {
                    Button(KroutonL10n.tr("Open Krouton")) { openMain() }
                }
            }
            Divider()
            HStack {
                Button(KroutonL10n.tr("Open Krouton")) { openMain() }
                Spacer()
                Button(KroutonL10n.tr("Menu Bar Settings…")) {
                    store.selectedSettingsPane = .notifications
                    openWindow(id: "settings")
                    KroutonOSDesktopBridge.bringKroutonForward()
                }
            }
            .buttonStyle(.borderless)
        }
        .padding(14)
        .frame(width: 300)
    }

    private func openMain() {
        openWindow(id: "main")
        KroutonOSDesktopBridge.bringKroutonForward()
    }
}
