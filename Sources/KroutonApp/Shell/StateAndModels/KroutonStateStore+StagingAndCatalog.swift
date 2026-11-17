import DriveKit
import CryptoKit
import SwiftUI
import Foundation
import UniformTypeIdentifiers
import OpticalCore
import AudioKit
import VideoKit
import ImageKit
import LabelKit
import RescueKit

// MARK: - KroutonStateStore Staging, Depot Catalog & Culinary Module Bridges

@MainActor
extension KroutonStateStore {
    public func toggleFormatVisibility(id: String) {
        if let idx = discFormats.firstIndex(where: { $0.id == id }) {
            discFormats[idx].showInTaskChooser.toggle()
        }
    }

    public func activeFormatSpec() -> KroutonOpticalWorkflowSpec {
        discFormats.first(where: { $0.id == selectedTaskID }) ?? discFormats[0]
    }

    public func expandAudioFilesInDirectory(_ dirURL: URL, allowedExtensions: Set<String>) -> [URL] {
        guard let children = try? FileManager.default.contentsOfDirectory(
            at: dirURL,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) else { return [] }

        let sorted = children.sorted {
            $0.lastPathComponent.localizedStandardCompare($1.lastPathComponent) == .orderedAscending
        }

        var directFiles: [URL] = []
        var subDirs: [URL] = []
        for child in sorted {
            var isSubDir: ObjCBool = false
            if FileManager.default.fileExists(atPath: child.path, isDirectory: &isSubDir), isSubDir.boolValue {
                subDirs.append(child)
            } else if allowedExtensions.isEmpty || allowedExtensions.contains(child.pathExtension.lowercased()) {
                directFiles.append(child)
            }
        }

        var result = directFiles
        for subDir in subDirs {
            result.append(contentsOf: expandAudioFilesInDirectory(subDir, allowedExtensions: allowedExtensions))
        }
        return result
    }

    public func isURLCompatible(_ url: URL, for spec: KroutonOpticalWorkflowSpec) -> Bool {
        var isDir: ObjCBool = false
        let exists = FileManager.default.fileExists(atPath: url.path, isDirectory: &isDir)
        let ext = url.pathExtension.lowercased()
        let allowed = spec.allowedFileExtensions
        if allowed.isEmpty {
            return true // Data & Archival discs accept any file or folder
        }
        if isDir.boolValue && exists {
            if spec.filterGroup == .audio {
                return !expandAudioFilesInDirectory(url, allowedExtensions: Set(allowed)).isEmpty
            }
            if !spec.allowsDirectorySelection { return false }
            let dirName = url.lastPathComponent.uppercased()
            if spec.filterGroup == .video && (dirName == "VIDEO_TS" || dirName == "BDMV") {
                return true
            }
            if let children = try? FileManager.default.contentsOfDirectory(at: url, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles]) {
                return children.contains { allowed.contains($0.pathExtension.lowercased()) }
            }
            return false
        }
        return allowed.contains(ext)
    }

    public func purgeIncompatibleStagedFilesForCurrentTask() {
        guard selectedCategory == .burn else { return }
        let spec = activeFormatSpec()
        guard !spec.allowedFileExtensions.isEmpty else { return }
        let beforeCount = stagedFiles.count
        stagedFiles.removeAll { !isURLCompatible($0.url, for: spec) }
        if stagedFiles.count < beforeCount {
            stagedDepotItemID = nil
        }
    }

    public func addStagedURLs(_ urls: [URL]) {
        let spec = activeFormatSpec()
        let allowedSet = Set(spec.allowedFileExtensions)
        var compatibleURLs: [URL] = []
        var rejectedNames: [String] = []
        let sortedInput = urls.sorted {
            $0.lastPathComponent.localizedStandardCompare($1.lastPathComponent) == .orderedAscending
        }
        for u in sortedInput {
            var isDir: ObjCBool = false
            let exists = FileManager.default.fileExists(atPath: u.path, isDirectory: &isDir)
            if selectedCategory == .burn && spec.filterGroup == .audio && exists && isDir.boolValue {
                let expanded = expandAudioFilesInDirectory(u, allowedExtensions: allowedSet)
                if expanded.isEmpty {
                    rejectedNames.append(u.lastPathComponent)
                } else {
                    compatibleURLs.append(contentsOf: expanded)
                }
            } else if selectedCategory == .burn && !isURLCompatible(u, for: spec) {
                rejectedNames.append(u.lastPathComponent)
            } else {
                compatibleURLs.append(u)
            }
        }
        if !rejectedNames.isEmpty {
            let joined = rejectedNames.prefix(2).joined(separator: ", ")
            rejectedDropNotice = "Rejected \(joined): \(spec.technicalName) only accepts \(spec.expectedMediaDescription)."
            KroutonOSDesktopBridge.playAcousticCue()
            announceForVoiceOver(rejectedDropNotice ?? "Incompatible file rejected")
        } else {
            rejectedDropNotice = nil
        }
        guard !compatibleURLs.isEmpty else { return }
        if spec.id == "image-burn" || spec.filterGroup == .console {
            stagedFiles.removeAll()
        }
        for url in compatibleURLs {
            if !stagedFiles.contains(where: { $0.url == url }) {
                let entry = KroutonOpticalDriveBank.inspectFileOrFolder(url: url)
                stagedFiles.append(entry)
            }
        }
        if spec.filterGroup == .audio {
            audioController.add(compatibleURLs)
        }
    }

    public var totalRedBookFramesLBA: Int64 {
        audioController.project.totalFrames ?? redBookTracks.reduce(Int64(0)) { $0 + $1.totalRedBookFrames }
    }

    public var totalRedBookBytes: Int64 {
        totalRedBookFramesLBA * 2352
    }

    public func removeStagedFile(id: UUID) {
        stagedFiles.removeAll { $0.id == id }
        audioController.remove(id)
    }

    public func toggleMacVisibility(id: UUID) {
        guard let idx = stagedFiles.firstIndex(where: { $0.id == id }) else { return }
        stagedFiles[idx].showOnMac.toggle()
        if !stagedFiles[idx].showOnMac && !stagedFiles[idx].showOnPC {
            stagedFiles[idx].showOnPC = true
        }
    }

    public func togglePCVisibility(id: UUID) {
        guard let idx = stagedFiles.firstIndex(where: { $0.id == id }) else { return }
        stagedFiles[idx].showOnPC.toggle()
        if !stagedFiles[idx].showOnPC && !stagedFiles[idx].showOnMac {
            stagedFiles[idx].showOnMac = true
        }
    }

    public func enableCurrentTaskChooserFormat() {
        if let idx = discFormats.firstIndex(where: { $0.id == selectedTaskID }) {
            discFormats[idx].showInTaskChooser = true
        }
    }

    public var resolvedFolderIconColor: Color {
        folderColorMode.resolvedFolderColor(accent: activeAccent)
    }

    public func announceForVoiceOver(_ message: String) {
        guard voiceOverSpokenTelemetry else { return }
        KroutonOSDesktopBridge.postVoiceOverAnnouncement(message)
    }

    /// Forwards localization lookup to the single KroutonL10n.tr implementation
    public func tr(_ key: String) -> String {
        KroutonL10n.activeISOCode = appLanguage.isoCode
        return KroutonL10n.tr(key)
    }


    public func parseSizeDisplayToBytes(_ sizeDisplay: String) -> Int64 {
        let parts = sizeDisplay.split(separator: " ")
        guard let val = Double(parts.first ?? "0") else { return 0 }
        if sizeDisplay.uppercased().contains("GB") {
            return Int64(val * 1_000_000_000)
        } else if sizeDisplay.uppercased().contains("MB") {
            return Int64(val * 1_000_000)
        }
        return 0
    }

    public func convertStagedBinOrIso(id: UUID) {
        guard let idx = stagedFiles.firstIndex(where: { $0.id == id }) else { return }
        let entry = stagedFiles[idx]
        let lower = entry.name.lowercased()
        Task { @MainActor in
            if lower.hasSuffix(".dmg") || lower.hasSuffix(".cdr") {
                let outExt = lower.hasSuffix(".dmg") ? "iso" : "dmg"
                let outURL = entry.url.deletingPathExtension().appendingPathExtension(outExt)
                do {
                    _ = try await Task.detached(priority: .userInitiated) {
                        try DiscImageDepotOperations.convertDiskImageWithHdiutil(sourceURL: entry.url, outputURL: outURL)
                    }.value
                    if let currentIdx = stagedFiles.firstIndex(where: { $0.id == id }) {
                        stagedFiles[currentIdx] = KroutonOpticalDriveBank.inspectFileOrFolder(url: outURL)
                        announceForVoiceOver("Converted to \(outURL.lastPathComponent)")
                    }
                } catch {
                    rejectedDropNotice = error.localizedDescription
                }
                return
            }
            let (outputURL, report) = await KroutonWindowManager.shared.driveManager.convertBinAndIsoSectorImage(sourceURL: entry.url)
            guard report.isSuccess, let outURL = outputURL, FileManager.default.fileExists(atPath: outURL.path) else {
                rejectedDropNotice = report.summary
                return
            }
            if let currentIdx = stagedFiles.firstIndex(where: { $0.id == id }) {
                stagedFiles[currentIdx] = KroutonOpticalDriveBank.inspectFileOrFolder(url: outURL)
                announceForVoiceOver(report.title)
            }
        }
    }

    public func downloadAndStageDepotItem(id: String, jumpToInspector: Bool = false) {
        guard let idx = depotItems.firstIndex(where: { $0.id == id }) else { return }
        let item = depotItems[idx]
        let cacheDir = URL(fileURLWithPath: "/tmp/KroutonDepotCache", isDirectory: true)
        try? FileManager.default.createDirectory(at: cacheDir, withIntermediateDirectories: true)
        let safeFilename = item.id + "-" + item.version.replacingOccurrences(of: " ", with: "_") + ".iso"
        let isoURL = cacheDir.appendingPathComponent(safeFilename)

        if FileManager.default.fileExists(atPath: isoURL.path) {
            depotItems[idx].isDownloaded = true
            stageDepotItemForBurning(depotItems[idx], jumpToInspector: jumpToInspector)
            return
        }

        if depotDownloadProgress[id] != nil { return }
        depotDownloadProgress[id] = 0.08
        rejectedDropNotice = nil

        Task { @MainActor in
            for step in [0.22, 0.48, 0.76, 0.94] {
                try? await Task.sleep(nanoseconds: 70_000_000)
                if self.depotDownloadProgress[id] != nil {
                    self.depotDownloadProgress[id] = step
                }
            }

            do {
                try await Self.materializeDepotImageToCache(item: item, destinationURL: isoURL)
                self.depotDownloadProgress.removeValue(forKey: id)
                if let currentIdx = self.depotItems.firstIndex(where: { $0.id == id }) {
                    self.depotItems[currentIdx].isDownloaded = true
                    self.stageDepotItemForBurning(self.depotItems[currentIdx], jumpToInspector: jumpToInspector)
                    self.announceForVoiceOver("Staged \(item.title) into burn queue.")
                }
            } catch {
                self.depotDownloadProgress.removeValue(forKey: id)
                self.rejectedDropNotice = "Failed to prepare '\(item.title)': \(error.localizedDescription)"
            }
        }
    }

    public func stageDepotItemForBurning(_ item: KroutonDepotCatalogItem, jumpToInspector: Bool = false) {
        let cacheDir = URL(fileURLWithPath: "/tmp/KroutonDepotCache", isDirectory: true)
        let safeFilename = item.id + "-" + item.version.replacingOccurrences(of: " ", with: "_") + ".iso"
        let isoURL = cacheDir.appendingPathComponent(safeFilename)
        guard FileManager.default.fileExists(atPath: isoURL.path) else {
            downloadAndStageDepotItem(id: item.id, jumpToInspector: jumpToInspector)
            return
        }
        stagedFiles = [KroutonOpticalDriveBank.inspectFileOrFolder(url: isoURL)]
        stagedDepotItemID = item.id
        discVolumeTitle = String(item.id.uppercased().replacingOccurrences(of: "-", with: "_").prefix(32))
        if jumpToInspector {
            selectedCategory = .burn
            selectedTaskID = "image-burn"
        }
    }


}

// MARK: - Functional Icon & Widget Style Renderer (Default / Dark / Clear / Tinted)
public struct KroutonStyledIconBadge: View {
    public let sfSymbol: String
    public let tintColor: Color
    public let style: KroutonGarnishStyleMode
    public var isSelectedRow: Bool = false
    public var onAccentText: Color = .white
    public var size: CGFloat = 24
    public var symbolSize: CGFloat = 13

    public init(
        sfSymbol: String,
        tintColor: Color,
        style: KroutonGarnishStyleMode,
        isSelectedRow: Bool = false,
        onAccentText: Color = .white,
        size: CGFloat = 24,
        symbolSize: CGFloat = 13
    ) {
        self.sfSymbol = sfSymbol
        self.tintColor = tintColor
        self.style = style
        self.isSelectedRow = isSelectedRow
        self.onAccentText = onAccentText
        self.size = size
        self.symbolSize = symbolSize
    }

    public var body: some View {
        let activeStore = KroutonStateStore.shared
        let isLight = (activeStore?.resolvedColorScheme == .light)
        let useHarmonyBg = (style == .tinted && (activeStore?.enableSecondaryAccentUITints ?? false))
        // In Light Mode, use the bright neon P3 harmony color for the tile fill so yellows/mints look luminous instead of muddy,
        // while using the deep Light Mode harmony color for the crisp border ring!
        let presetID = activeStore?.selectedAccentIndex ?? 6
        let effectiveID = presetID >= 0 ? presetID : (activeStore.map { $0.multicolorPresetID(forTaskID: $0.selectedTaskID, category: $0.selectedCategory) } ?? 6)
        let brightHarmony = KroutonStateStore.secondaryHarmonyForPresetID(effectiveID, scheme: .dark)
        let strokeHarmony = activeStore?.activeSecondaryAccent ?? tintColor.perceptualSplitComplement

        ZStack {
            RoundedRectangle(cornerRadius: size * 0.26, style: .continuous)
                .fill(badgeBackgroundGradient(isLight: isLight))
                .overlay(
                    Group {
                        if useHarmonyBg {
                            RoundedRectangle(cornerRadius: size * 0.26, style: .continuous)
                                .fill(isLight ? brightHarmony.opacity(0.38) : strokeHarmony.opacity(0.28))
                        } else if style == .tinted && isLight {
                            RoundedRectangle(cornerRadius: size * 0.26, style: .continuous)
                                .fill(tintColor.opacity(0.15))
                        }
                    }
                )
                .frame(width: size, height: size)
                .overlay(
                    RoundedRectangle(cornerRadius: size * 0.26, style: .continuous)
                        .stroke(
                            useHarmonyBg
                                ? strokeHarmony.opacity(isLight ? 0.65 : 0.55)
                                : (isSelectedRow ? Color.white.opacity(0.35) : Color.primary.opacity(isLight ? 0.16 : 0.12)),
                            lineWidth: useHarmonyBg ? 1.25 : 0.8
                        )
                )

            Image(systemName: sfSymbol)
                .font(.system(size: symbolSize, weight: .semibold))
                .foregroundStyle(symbolForeground(isLight: isLight))
        }
    }

    private func badgeBackgroundGradient(isLight: Bool) -> LinearGradient {
        switch style {
        case .defaultStyle:
            if isSelectedRow {
                return LinearGradient(
                    colors: [Color.white.opacity(0.24), Color.white.opacity(0.10)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            }
            return LinearGradient(
                colors: [tintColor, tintColor.opacity(0.76)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case .dark:
            return LinearGradient(
                colors: [Color(white: 0.18), Color(white: 0.09)],
                startPoint: .top,
                endPoint: .bottom
            )
        case .clear:
            return LinearGradient(
                colors: [
                    Color.primary.opacity(isLight ? 0.10 : 0.14),
                    Color.primary.opacity(isLight ? 0.04 : 0.05)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        case .tinted:
            if isLight {
                // Crisp alabaster/ivory workspace tile in Light Mode so bright Harmony washes + deep Primary icons pop!
                return LinearGradient(
                    colors: [Color(white: 0.98), Color(white: 0.93)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            }
            return LinearGradient(
                colors: [Color(white: 0.15), Color(white: 0.08)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }

    private func symbolForeground(isLight: Bool) -> Color {
        switch style {
        case .defaultStyle:
            return onAccentText
        case .dark:
            return .white
        case .clear:
            return isSelectedRow ? onAccentText : .primary
        case .tinted:
            return tintColor
        }
    }
}

// MARK: - Staged files -> hybrid disc image

@MainActor
extension KroutonStateStore {
    /// Masters the staged files into a mountable ISO-9660 + Joliet + UDF image with `hdiutil makehybrid`
    /// and records its location and SHA-256. On failure both are cleared, so nothing downstream
    /// (the LAN spool client, the Depot) can pick up a stale or partial image.
    func masterStagedFilesToHybridISO() async {
        burnQueueSubStore.lastMasteredISOURL = nil
        burnQueueSubStore.lastMasteredSHA256 = ""
        guard !stagedFiles.isEmpty else { return }

        let fm = FileManager.default
        let stagingRoot = fm.temporaryDirectory.appendingPathComponent("KroutonDepotStaging", isDirectory: true)
        let treeURL = stagingRoot.appendingPathComponent("Tree_\(UUID().uuidString)", isDirectory: true)
        let outputURL = stagingRoot.appendingPathComponent("Krouton_Master_Output.iso")
        defer {
            Task.detached(priority: .utility) { try? FileManager.default.removeItem(at: treeURL) }
        }

        let items = stagedFiles.map { KroutonBurnStageItem(source: $0.url, name: $0.name) }
        if let stagingError = await KroutonBurnStager.stage(items, into: treeURL) {
            KroutonDiagnostics.masteringLogger.error("Image staging failed: \(stagingError, privacy: .public)")
            return
        }
        do {
            let image = try await KroutonHybridImageBuilder.build(
                sourceDirectory: treeURL,
                outputURL: outputURL,
                options: KroutonHybridImageOptions(volumeName: discVolumeTitle, includeHFSPlus: true, finderLayout: finderLayoutBlueprint)
            )
            burnQueueSubStore.lastMasteredISOURL = image.url
            burnQueueSubStore.lastMasteredSHA256 = "sha256:" + image.sha256Hex
        } catch {
            KroutonDiagnostics.masteringLogger.error("Image mastering failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    // MARK: - Shared Data Disc Spanning Helpers

    public func resolvedDataDiscMedium(forFormatID formatID: String) -> KroutonSpanningDiscMedium {
        let allowed = KroutonSpanningDiscMedium.allowedMedia(forFormatID: formatID)
        let spec = discFormats.first(where: { $0.id == formatID })
        if spec?.workspaceKind == .redBookAudio {
            let audioMed = audioController.project.targetDiscMedium
            if allowed.contains(audioMed) { return audioMed }
        }
        if let saved = targetDiscMediumByTask[formatID], allowed.contains(saved) {
            return saved
        }
        let def = KroutonSpanningDiscMedium.defaultMedium(forFormatID: formatID)
        if allowed.contains(def) { return def }
        return allowed.first ?? .dvd5Single
    }

    public func setTargetDiscMedium(_ medium: KroutonSpanningDiscMedium, forFormatID formatID: String) {
        let allowed = KroutonSpanningDiscMedium.allowedMedia(forFormatID: formatID)
        let resolved = allowed.contains(medium) ? medium : KroutonSpanningDiscMedium.defaultMedium(forFormatID: formatID)
        targetDiscMediumByTask[formatID] = resolved
        dataTargetDiscMedium = resolved
        let spec = discFormats.first(where: { $0.id == formatID })
        if spec?.workspaceKind == .redBookAudio {
            audioController.targetDiscMediumBinding.wrappedValue = resolved
        }
        objectWillChange.send()
    }

    public func targetDiscMediumBinding(forFormatID formatID: String) -> Binding<KroutonSpanningDiscMedium> {
        Binding(
            get: { [weak self] in
                self?.resolvedDataDiscMedium(forFormatID: formatID) ?? KroutonSpanningDiscMedium.defaultMedium(forFormatID: formatID)
            },
            set: { [weak self] newMed in
                self?.setTargetDiscMedium(newMed, forFormatID: formatID)
            }
        )
    }

    public func dataDiscPlan(forFormatID formatID: String) -> DiscPlan<KroutonStagedFileEntry> {
        let medium = resolvedDataDiscMedium(forFormatID: formatID)
        return DiscSpanningEngine.planDataDiscs(stagedFiles, medium: medium)
    }

    public func toggleDataManualDiscBreak(before entryID: UUID) {
        DiscSpanningEngine.toggleManualDiscBreak(before: entryID, in: &stagedFiles)
    }

    public func dataDiscVolumeBinding(forDisc discNumber: Int) -> Binding<String> {
        Binding(
            get: { [weak self] in self?.dataDiscVolumeOverrides[discNumber] ?? "" },
            set: { [weak self] newValue in
                let trimmed = newValue.trimmingCharacters(in: .whitespacesAndNewlines)
                if trimmed.isEmpty {
                    self?.dataDiscVolumeOverrides.removeValue(forKey: discNumber)
                } else {
                    self?.dataDiscVolumeOverrides[discNumber] = newValue
                }
            }
        )
    }
}
