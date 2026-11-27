import AudioKit
import CryptoKit
import DriveKit
import Foundation
import ImageKit
import OpticalCore
import SwiftUI
import UniformTypeIdentifiers

// MARK: - KroutonStateStore Staging, Depot Catalog & Culinary Module Bridges

@MainActor
extension KroutonStateStore {
    func toggleFormatVisibility(id: String) {
        if let idx = discFormats.firstIndex(where: { $0.id == id }) {
            discFormats[idx].showInTaskChooser.toggle()
        }
    }

    func activeFormatSpec() -> KroutonOpticalWorkflowSpec {
        discFormats.first(where: { $0.id == selectedTaskID }) ?? discFormats[0]
    }

    func expandAudioFilesInDirectory(_ dirURL: URL, allowedExtensions: Set<String>) -> [URL] {
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

    func isURLCompatible(_ url: URL, for spec: KroutonOpticalWorkflowSpec) -> Bool {
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

    func purgeIncompatibleStagedFilesForCurrentTask() {
        guard selectedCategory == .burn else { return }
        let spec = activeFormatSpec()
        guard !spec.allowedFileExtensions.isEmpty else { return }
        let beforeCount = stagedFiles.count
        stagedFiles.removeAll { !isURLCompatible($0.url, for: spec) }
        if stagedFiles.count < beforeCount {
            self.stagedDepotItemID = nil
        }
    }

    func addStagedURLs(_ urls: [URL]) {
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

    var totalRedBookFramesLBA: Int64 {
        audioController.project.totalFrames ?? redBookTracks.reduce(Int64(0)) { $0 + $1.totalRedBookFrames }
    }

    func removeStagedFile(id: UUID) {
        stagedFiles.removeAll { $0.id == id }
        audioController.remove(id)
    }

    func toggleMacVisibility(id: UUID) {
        guard let idx = stagedFiles.firstIndex(where: { $0.id == id }) else { return }
        stagedFiles[idx].showOnMac.toggle()
        if !stagedFiles[idx].showOnMac && !stagedFiles[idx].showOnPC {
            stagedFiles[idx].showOnPC = true
        }
    }

    func togglePCVisibility(id: UUID) {
        guard let idx = stagedFiles.firstIndex(where: { $0.id == id }) else { return }
        stagedFiles[idx].showOnPC.toggle()
        if !stagedFiles[idx].showOnPC && !stagedFiles[idx].showOnMac {
            stagedFiles[idx].showOnMac = true
        }
    }

    func enableCurrentTaskChooserFormat() {
        if let idx = discFormats.firstIndex(where: { $0.id == selectedTaskID }) {
            discFormats[idx].showInTaskChooser = true
        }
    }

    var resolvedFolderIconColor: Color {
        self.folderColorMode.resolvedFolderColor(accent: activeAccent)
    }

    func announceForVoiceOver(_ message: String) {
        guard self.voiceOverSpokenTelemetry else { return }
        KroutonOSDesktopBridge.postVoiceOverAnnouncement(message)
    }


    func parseSizeDisplayToBytes(_ sizeDisplay: String) -> Int64 {
        let parts = sizeDisplay.split(separator: " ")
        guard let val = Double(parts.first ?? "0") else { return 0 }
        if sizeDisplay.uppercased().contains("GB") {
            return Int64(val * 1_000_000_000)
        } else if sizeDisplay.uppercased().contains("MB") {
            return Int64(val * 1_000_000)
        }
        return 0
    }

    func convertStagedBinOrIso(id: UUID) {
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

    // Depot downloads and staging live in KroutonStateStore+DepotFeed.swift.
}

// MARK: - Staged files -> hybrid disc image

@MainActor
extension KroutonStateStore {
    // MARK: - Shared Data Disc Spanning Helpers

    func resolvedDataDiscMedium(forFormatID formatID: String) -> KroutonSpanningDiscMedium {
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

    func setTargetDiscMedium(_ medium: KroutonSpanningDiscMedium, forFormatID formatID: String) {
        let allowed = KroutonSpanningDiscMedium.allowedMedia(forFormatID: formatID)
        let resolved = allowed.contains(medium) ? medium : KroutonSpanningDiscMedium.defaultMedium(forFormatID: formatID)
        targetDiscMediumByTask[formatID] = resolved
        let spec = discFormats.first(where: { $0.id == formatID })
        if spec?.workspaceKind == .redBookAudio {
            audioController.targetDiscMediumBinding.wrappedValue = resolved
        }
    }

    func targetDiscMediumBinding(forFormatID formatID: String) -> Binding<KroutonSpanningDiscMedium> {
        Binding(
            get: { [weak self] in
                self?.resolvedDataDiscMedium(forFormatID: formatID) ?? KroutonSpanningDiscMedium.defaultMedium(forFormatID: formatID)
            },
            set: { [weak self] newMed in
                self?.setTargetDiscMedium(newMed, forFormatID: formatID)
            }
        )
    }

    func dataDiscPlan(forFormatID formatID: String) -> DiscPlan<KroutonStagedFileEntry> {
        let medium = resolvedDataDiscMedium(forFormatID: formatID)
        return DiscSpanningEngine.planDataDiscs(stagedFiles, medium: medium)
    }

    func toggleDataManualDiscBreak(before entryID: UUID) {
        DiscSpanningEngine.toggleManualDiscBreak(before: entryID, in: &stagedFiles)
    }

    func dataDiscVolumeBinding(forDisc discNumber: Int) -> Binding<String> {
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
