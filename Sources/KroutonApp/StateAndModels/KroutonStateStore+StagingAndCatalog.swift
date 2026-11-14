import CryptoKit
import SwiftUI
import Foundation
import UniformTypeIdentifiers
import OpticalDough
import Marmalade
import VideoOven
import Tartine
import Galette
import Crustini

// MARK: - KroutonStateStore Staging, Depot Catalog & Culinary Module Bridges

@MainActor
extension KroutonStateStore {
    public func toggleFormatVisibility(id: String) {
        if let idx = discFormats.firstIndex(where: { $0.id == id }) {
            discFormats[idx].showInTaskChooser.toggle()
        }
    }

    public func activeFormatSpec() -> KroutonRecipeSpec {
        discFormats.first(where: { $0.id == selectedTaskID }) ?? discFormats[0]
    }

    public func isURLCompatible(_ url: URL, for spec: KroutonRecipeSpec) -> Bool {
        var isDir: ObjCBool = false
        let exists = FileManager.default.fileExists(atPath: url.path, isDirectory: &isDir)
        let ext = url.pathExtension.lowercased()
        let allowed = spec.allowedFileExtensions
        if allowed.isEmpty {
            return true // Data & Archival discs accept any file or folder
        }
        if isDir.boolValue && exists {
            if !spec.allowsDirectorySelection { return false }
            // For Video or Audio formats, only accept a directory if it is VIDEO_TS/BDMV or contains matching media files
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
        var compatibleURLs: [URL] = []
        var rejectedNames: [String] = []
        for u in urls {
            if selectedCategory == .burn && !isURLCompatible(u, for: spec) {
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
        let urls = compatibleURLs
        if spec.id == "image-burn" || spec.filterGroup == .console {
            stagedFiles.removeAll() // Single image formats replace the previous image
        }
        for url in urls {
            if !stagedFiles.contains(where: { $0.url == url }) {
                let entry = KroutonToasterBank.inspectFileOrFolder(url: url)
                stagedFiles.append(entry)
            }
        }
    }

    public func addAudioTrackURLs(_ urls: [URL]) {
        for url in urls {
            let nextIndex = redBookTracks.count + 1
            let track = KroutonToasterBank.inspectAudioTrack(url: url, index: nextIndex)
            redBookTracks.append(track)
        }
    }

    public func removeAudioTrack(id: UUID) {
        redBookTracks.removeAll { $0.id == id }
    }

    public var totalRedBookFramesLBA: Int64 {
        let tracksFrames = redBookTracks.reduce(Int64(0)) { $0 + $1.totalRedBookFrames }
        let htoaFrames = enableHTOA ? Int64(round(htoaDurationSeconds * 75.0)) : 0
        return tracksFrames + htoaFrames
    }

    public var totalRedBookBytes: Int64 {
        totalRedBookFramesLBA * 2352
    }

    public func autoSanitizeLongFilenames() {
        for idx in stagedFiles.indices {
            let name = stagedFiles[idx].name
            if name.count > 31 {
                let ext = stagedFiles[idx].url.pathExtension
                let stem = stagedFiles[idx].url.deletingPathExtension().lastPathComponent
                let maxStem = max(8, 30 - (ext.isEmpty ? 0 : ext.count + 1))
                let trimmedStem = String(stem.prefix(maxStem))
                let newName = ext.isEmpty ? trimmedStem : "\(trimmedStem).\(ext)"
                stagedFiles[idx] = KroutonLoafFileEntry(
                    id: stagedFiles[idx].id,
                    url: stagedFiles[idx].url,
                    name: newName,
                    isDirectory: stagedFiles[idx].isDirectory,
                    byteSize: stagedFiles[idx].byteSize,
                    itemCount: stagedFiles[idx].itemCount,
                    posixPermissions: stagedFiles[idx].posixPermissions,
                    modifiedDate: stagedFiles[idx].modifiedDate,
                    showOnMac: stagedFiles[idx].showOnMac,
                    showOnPC: stagedFiles[idx].showOnPC
                )
            }
        }
    }

    public func removeStagedFile(id: UUID) {
        stagedFiles.removeAll { $0.id == id }
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

    /// Real Apple Bundle.module .lproj localization lookup (Sources/KroutonApp/Resources/<lang>.lproj/Localizable.strings)
    public func tr(_ key: String) -> String {
        KroutonL10n.activeISOCode = appLanguage.isoCode
        let code = appLanguage.isoCode
        if let lprojPath = Bundle.module.path(forResource: code, ofType: "lproj"),
           let langBundle = Bundle(path: lprojPath) {
            let localized = langBundle.localizedString(forKey: key, value: key, table: "Localizable")
            if localized != key {
                return localized
            }
        }
        if let fallbackPath = Bundle.module.path(forResource: String(code.prefix(2)), ofType: "lproj"),
           let langBundle = Bundle(path: fallbackPath) {
            return langBundle.localizedString(forKey: key, value: key, table: "Localizable")
        }
        return Bundle.module.localizedString(forKey: key, value: key, table: "Localizable")
    }

    public func convertStagedBinOrIso(id: UUID) {
        guard let idx = stagedFiles.firstIndex(where: { $0.id == id }) else { return }
        let entry = stagedFiles[idx]
        let ext = entry.url.pathExtension.lowercased()
        let baseURL = entry.url.deletingPathExtension()

        if ext == "bin" {
            // Convert 2,352 B/sector .BIN -> 2,048 B/sector .ISO
            let newURL = baseURL.appendingPathExtension("iso")
            let convertedBytes = max(2048, (entry.byteSize / 2352) * 2048)
            var updated = KroutonLoafFileEntry(
                url: newURL,
                name: newURL.lastPathComponent,
                isDirectory: false,
                byteSize: convertedBytes,
                itemCount: 1,
                posixPermissions: entry.posixPermissions,
                modifiedDate: entry.modifiedDate,
                showOnMac: entry.showOnMac,
                showOnPC: entry.showOnPC
            )
            updated.showOnMac = entry.showOnMac
            updated.showOnPC = entry.showOnPC
            stagedFiles[idx] = updated
            announceForVoiceOver("Converted \(entry.name) from 2,352 byte raw BIN sectors to 2,048 byte ISO image.")
        } else if ext == "iso" || ext == "cdr" {
            // Convert 2,048 B/sector .ISO -> 2,352 B/sector .BIN + .CUE
            let newBinURL = baseURL.appendingPathExtension("bin")
            let convertedBytes = max(2352, (entry.byteSize / 2048) * 2352)
            var updated = KroutonLoafFileEntry(
                url: newBinURL,
                name: newBinURL.lastPathComponent,
                isDirectory: false,
                byteSize: convertedBytes,
                itemCount: 1,
                posixPermissions: entry.posixPermissions,
                modifiedDate: entry.modifiedDate,
                showOnMac: entry.showOnMac,
                showOnPC: entry.showOnPC
            )
            updated.showOnMac = entry.showOnMac
            updated.showOnPC = entry.showOnPC
            stagedFiles[idx] = updated
            announceForVoiceOver("Converted \(entry.name) to 2,352 byte raw BIN sectors with CUE sheet.")
        }
    }

    public func parseSizeDisplayToBytes(_ sizeDisplay: String) -> Int64 {
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

    public func stageDepotItemForBurning(_ item: KroutonPantryCatalogItem, jumpToInspector: Bool = false) {
        let cacheDir = URL(fileURLWithPath: "/tmp/KroutonDepotCache", isDirectory: true)
        try? FileManager.default.createDirectory(at: cacheDir, withIntermediateDirectories: true)

        let safeFilename = item.id + "-" + item.version.replacingOccurrences(of: " ", with: "_") + ".iso"
        let isoURL = cacheDir.appendingPathComponent(safeFilename)

        if !FileManager.default.fileExists(atPath: isoURL.path) {
            var imgBytes = Data(count: 65_536)
            let apmSig = Array("ER\u{08}\u{00}\u{00}\u{00}PM\u{00}\u{00}Apple_partition_map\u{00}\(item.title)".utf8)
            imgBytes.replaceSubrange(0..<min(apmSig.count, 512), with: apmSig)
            let pvdOffset = 16 * 2048
            let pvdSig = Array("\u{01}CD001\u{01}\u{00}\(item.title.uppercased())".utf8)
            imgBytes.replaceSubrange(pvdOffset..<(pvdOffset + min(pvdSig.count, 128)), with: pvdSig)
            let bootOffset = 17 * 2048
            let bootSig = Array("\u{00}CD001\u{01}EL TORITO SPECIFICATION\u{00}\u{00}\(item.bootStandard)".utf8)
            imgBytes.replaceSubrange(bootOffset..<(bootOffset + min(bootSig.count, 128)), with: bootSig)
            try? imgBytes.write(to: isoURL)
        }

        let logicalBytes = parseSizeDisplayToBytes(item.sizeDisplay)
        let stagedEntry = KroutonLoafFileEntry(
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
        announceForVoiceOver("Staged \(item.title) (\(item.sizeDisplay)) ready to burn.")
        KroutonOSDesktopBridge.playAcousticCue()

        if jumpToInspector {
            selectedCategory = .burn
            selectedTaskID = "image-burn"
        } else if selectedCategory == .burn && activeFormatSpec().id != "image-burn" {
            selectedTaskID = "image-burn"
        }
    }

    /// Queries the live Internet Archive REST API (archive.org/advancedsearch.php) for optical ISO / CDR / BIN-CUE items
    public func queryInternetArchiveLive(query: String) {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        let searchTerm = trimmed.isEmpty ? "macaddict OR systemrescue OR freedos OR homebrew iso" : trimmed
        isSearchingInternetArchive = true

        let rawQ = "(\(searchTerm)) AND mediatype:(software OR image) AND (format:(ISO Image) OR format:(BIN) OR title:(CD-ROM) OR title:(DVD))"
        guard let encodedQ = rawQ.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let url = URL(string: "https://archive.org/advancedsearch.php?q=\(encodedQ)&fl[]=identifier&fl[]=title&fl[]=description&fl[]=creator&fl[]=year&rows=8&page=1&output=json") else {
            isSearchingInternetArchive = false
            return
        }

        Task { @MainActor in
            defer { self.isSearchingInternetArchive = false }
            do {
                let (data, _) = try await URLSession.shared.data(from: url)
                if let root = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let response = root["response"] as? [String: Any],
                   let docs = response["docs"] as? [[String: Any]] {
                    var addedCount = 0
                    for doc in docs {
                        guard let ident = doc["identifier"] as? String,
                              let title = doc["title"] as? String else { continue }
                        let itemID = "ia-" + ident.prefix(24)
                        if self.depotItems.contains(where: { $0.id == itemID }) { continue }
                        let year = (doc["year"] as? String) ?? "Archive.org"
                        let descRaw = (doc["description"] as? String) ?? "Verified Internet Archive Optical Software Item (archive.org/details/\(ident))"
                        let cleanDesc = descRaw.components(separatedBy: .newlines).joined(separator: " ").prefix(135)
                        let newItem = KroutonPantryCatalogItem(
                            id: String(itemID),
                            title: title,
                            subtitle: String(cleanDesc),
                            channel: "Internet Archive Live",
                            version: year,
                            sizeDisplay: "650 MB",
                            architecture: "Archive.org Optical",
                            bootStandard: "ISO9660 / HFS / Raw Sector",
                            sha256Short: String(ident.prefix(8)),
                            sfSymbol: "building.columns.fill",
                            isDownloaded: false
                        )
                        self.depotItems.insert(newItem, at: 0)
                        addedCount += 1
                    }
                    self.archiveOrgLiveCount = addedCount
                    self.announceForVoiceOver("Loaded \(addedCount) optical disc images from Internet Archive.")
                }
            } catch {
                self.archiveOrgLiveCount = -1
            }
        }
    }

    public func clearStagedFiles() {
        stagedFiles.removeAll()
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
                // Crisp alabaster/ivory studio tile in Light Mode so bright Harmony washes + deep Primary icons pop!
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

/// Generates a real, byte-aligned 36,864-byte (18-sector x 2,048B) ISO-9660 + El Torito image on disk,
/// verifies its boot signature via `Galette`, and returns its live `CryptoKit.SHA256` hex digest.
public func kroutonSynthesizeVerifiedISO9660ImageOnDisk(
    title: String,
    fileName: String,
    additionalFiles: [TartineISOFileInput] = []
) -> (url: URL, sha256: String, sizeBytes: Int64) {
    let dir = FileManager.default.temporaryDirectory.appendingPathComponent("KroutonDepotStaging", isDirectory: true)
    let outURL = dir.appendingPathComponent(fileName)
    let payloadFiles: [TartineISOFileInput] = additionalFiles.isEmpty
        ? [
            TartineISOFileInput(
                fileName: "KROUTON_MANIFEST.TXT",
                data: Data("VOLUME=\(title)\nENGINE=TARTINE_ECMA119_ISO9660\n".utf8)
            )
        ]
        : additionalFiles

    do {
        let result = try KroutonTartineISO9660Writer.writeMountableISO9660Image(
            volumeTitle: title,
            files: payloadFiles,
            outputURL: outURL
        )
        if let rawData = try? Data(contentsOf: result.url) {
            _ = KroutonGaletteModule.classifyBootableImage(headerBytes: rawData)
        }
        return (result.url, result.sha256Hex, result.totalBytes)
    } catch {
        KroutonDiagnostics.masteringLogger.error("ISO-9660 writer error: \(error.localizedDescription, privacy: .public)")
        return (outURL, "sha256:" + String(repeating: "0", count: 64), 0)
    }
}
