import Foundation
import NetworkSpool
import OpticalCore
import SwiftUI
import UniformTypeIdentifiers

// MARK: - Settings: Krouton Servers (remote burners)

extension KroutonSettingsWindowView {
    var burnServersCard: some View {
        settingsCard(title: "Krouton Servers (Burners on Other Computers)") {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(spoolClient.statusBannerText)
                        .font(.system(size: 12, weight: .bold, design: .monospaced))
                        .foregroundStyle(store.uiSecondaryAccent)
                    Text(KroutonL10n.tr("Burn on a Raspberry Pi, PC, NAS or another Mac running Krouton Server. To add one, run `krouton-server pair` on it, then choose Pair here. Both screens show the same 6-digit code."))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer()
                pillToggleButton(title: "Look Again", sfSymbol: "antenna.radiowaves.left.and.right", isSelected: false) {
                    spoolClient.startZeroConfDiscovery()
                }
            }
            Divider()
            pairedServersSection
            serverJobsSection
            nearbyServersSection
            Divider()
            HStack(spacing: 8) {
                TextField(KroutonL10n.tr("Address, e.g. burner.local or 192.168.1.20"), text: $burnServerAddressDraft)
                    .textFieldStyle(.roundedBorder)
                    .frame(maxWidth: 280)
                pillToggleButton(title: "Pair by Address", sfSymbol: "link.badge.plus", isSelected: false) {
                    let (host, port) = Self.splitHostPort(burnServerAddressDraft)
                    guard !host.isEmpty else { return }
                    Task {
                        if await spoolClient.pair(host: host, port: port) != nil { burnServerAddressDraft = "" }
                    }
                }
                Spacer()
                pillToggleButton(title: "Save Log…", sfSymbol: "doc.text", isSelected: false) {
                    let artifact = spoolClient.exportEventLog()
                    spoolExportDocument = SpoolPlainTextFileDocument(text: artifact.contentText)
                    spoolExportDefaultFilename = artifact.defaultFilename
                    isShowingSpoolFileExporter = true
                }
            }
        }
        .fileExporter(
            isPresented: $isShowingSpoolFileExporter,
            document: spoolExportDocument,
            contentType: .plainText,
            defaultFilename: spoolExportDefaultFilename
        ) { _ in }
        .sheet(item: Binding(
            get: { spoolClient.pairingPrompt },
            set: { if $0 == nil, spoolClient.pairingPrompt != nil { spoolClient.confirmPairingCode(false) } }
        )) { prompt in
            KroutonPairingCodeSheet(prompt: prompt, accent: store.activeAccent) { matches in
                spoolClient.confirmPairingCode(matches)
            }
        }
    }

    // MARK: - Paired

    @ViewBuilder
    private var pairedServersSection: some View {
        if spoolClient.pairedServers.isEmpty {
            Text(KroutonL10n.tr("No servers paired yet."))
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        ForEach(spoolClient.pairedServers) { server in
            let connected = spoolClient.connectedServerID == server.nodeID
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 10) {
                    Image(systemName: "server.rack")
                        .foregroundStyle(connected ? store.activeAccent : .secondary)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(server.name).font(.system(size: 12, weight: .bold))
                        Text("\(server.bonjourName != nil ? "Bonjour" : server.hostPort) • node \(server.nodeID.prefix(8))"
                             + (connected ? spoolClient.serverWelcome.map { " • Krouton Server \($0.version)" } ?? "" : ""))
                            .font(.system(size: 10.5, design: .monospaced))
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    pillToggleButton(title: connected ? "Refresh" : "Connect", sfSymbol: "arrow.clockwise", isSelected: connected) {
                        Task { await spoolClient.refreshRemoteDrives(serverID: server.nodeID) }
                    }
                    pillToggleButton(title: "Forget", sfSymbol: "minus.circle", isSelected: false) {
                        Task { await spoolClient.forgetServer(server.nodeID) }
                    }
                }
                if connected {
                    ForEach(spoolClient.remoteDrives) { drive in
                        HStack(spacing: 8) {
                            Image(systemName: "opticaldiscdrive")
                                .foregroundStyle(drive.busy ? store.activeAccent : .secondary)
                            Text(drive.name).font(.system(size: 11.5, weight: .semibold))
                            Text(Self.describe(drive))
                                .font(.system(size: 10.5, design: .monospaced))
                                .foregroundStyle(.secondary)
                            Spacer()
                            pillToggleButton(title: "Eject", sfSymbol: "eject.fill", isSelected: false) {
                                Task { await spoolClient.ejectRemoteDrive(drive.id, serverID: server.nodeID) }
                            }
                            .disabled(drive.busy)
                        }
                        .padding(.leading, 26)
                    }
                }
            }
        }
    }

    // MARK: - Jobs on the Connected Server

    @ViewBuilder
    private var serverJobsSection: some View {
        let visible = spoolClient.jobs.filter { !$0.state.isTerminal || $0.state == .failed }
        if spoolClient.connectedServerID != nil, !visible.isEmpty {
            Divider()
            ForEach(visible) { job in
                HStack(spacing: 8) {
                    Image(systemName: Self.symbol(for: job.state))
                        .foregroundStyle(job.state == .failed ? Color.red : store.activeAccent)
                    Text(job.label).font(.system(size: 11.5, weight: .semibold))
                    Text(Self.describe(job))
                        .font(.system(size: 10.5, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                    Spacer()
                    if !job.state.isTerminal {
                        pillToggleButton(title: "Cancel", sfSymbol: "xmark.circle", isSelected: false) {
                            Task { await spoolClient.cancelJob(job.job) }
                        }
                    }
                }
            }
        }
    }

    static func symbol(for state: SpoolJobState) -> String {
        switch state {
        case .receiving: "arrow.up.circle"
        case .queued: "clock"
        case .burning: "flame"
        case .verifying: "checkmark.magnifyingglass"
        case .done: "checkmark.circle.fill"
        case .failed: "exclamationmark.triangle.fill"
        case .cancelled: "xmark.circle"
        }
    }

    static func describe(_ job: SpoolJobInfo) -> String {
        let percent = job.fraction.map { String(format: " %.0f%%", $0 * 100) } ?? ""
        switch job.state {
        case .queued: return job.queueAhead == 0 ? "next" : "\(job.queueAhead) ahead"
        case .failed: return job.message
        default: return job.message + percent
        }
    }

    // MARK: - Nearby

    @ViewBuilder
    private var nearbyServersSection: some View {
        ForEach(spoolClient.nearbyUnpaired) { node in
            HStack(spacing: 10) {
                Image(systemName: "dot.radiowaves.left.and.right")
                    .foregroundStyle(.secondary)
                VStack(alignment: .leading, spacing: 2) {
                    Text(node.name).font(.system(size: 12, weight: .semibold))
                    Text(KroutonL10n.tr("Nearby, not paired"))
                        .font(.system(size: 10.5))
                        .foregroundStyle(.secondary)
                }
                Spacer()
                pillToggleButton(title: "Pair…", sfSymbol: "link.badge.plus", isSelected: false) {
                    Task { await spoolClient.pair(host: node.name, bonjourName: node.bonjourName) }
                }
            }
        }
    }

    static func describe(_ drive: SpoolDriveInfo) -> String {
        let state: SpoolMediaState = drive.media
        let media: String = switch state {
        case .blank: "blank disc"
        case .appendable: "appendable disc"
        case .complete: "written disc"
        case .noDisc: "no disc"
        case .unknown: "disc unknown"
        }
        return drive.queue > 0 ? "\(media) • \(drive.queue) in queue" : media
    }

    static func splitHostPort(_ text: String) -> (String, UInt16) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.hasPrefix("["), let colon = trimmed.lastIndex(of: ":"), trimmed.filter({ $0 == ":" }).count == 1,
           let port = UInt16(trimmed[trimmed.index(after: colon)...]) {
            return (String(trimmed[..<colon]), port)
        }
        return (trimmed, 7420)
    }
}

// MARK: - Pairing Code Sheet

struct KroutonPairingCodeSheet: View {
    let prompt: SpoolPairingPrompt
    let accent: Color
    let decide: (Bool) -> Void

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "lock.shield")
                .font(.system(size: 34))
                .foregroundStyle(accent)
            Text(KroutonL10n.tr("Pair with \(prompt.serverLabel)"))
                .font(.title3.bold())
            Text(prompt.code)
                .font(.system(size: 40, weight: .bold, design: .monospaced))
                .kerning(4)
            Text(KroutonL10n.tr("Check that the server shows the same code, then confirm on both. The server's operator types y in the `krouton-server pair` window."))
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 360)
            HStack(spacing: 12) {
                Button(KroutonL10n.tr("The Codes Differ"), role: .cancel) { decide(false) }
                Button(KroutonL10n.tr("The Codes Match")) { decide(true) }
                    .keyboardShortcut(.defaultAction)
            }
        }
        .padding(28)
        .frame(minWidth: 420)
    }
}
