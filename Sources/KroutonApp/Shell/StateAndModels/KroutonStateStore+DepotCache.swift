import Foundation
import ImageKit
import OpticalCore

// MARK: - KroutonStateStore — DepotCache

extension KroutonStateStore {
    /// Downloads an Internet Archive search result's disc image. Depot feed items go through
    /// `KroutonDepotDownloader`, which checks every file against the feed's SHA-256.
    static func materializeDepotImageToCache(item: KroutonDepotCatalogItem, destinationURL: URL) async throws {
        if item.id.hasPrefix("ia-") {
            let identifier = String(item.id.dropFirst(3))
            if let metaURL = URL(string: "https://archive.org/metadata/\(identifier)") {
                let (metaData, _) = try await URLSession.shared.data(from: metaURL)
                if let root = try JSONSerialization.jsonObject(with: metaData) as? [String: Any],
                   let files = root["files"] as? [[String: Any]],
                   let isoEntry = files.first(where: {
                       let name = (($0["name"] as? String) ?? "").lowercased()
                       return name.hasSuffix(".iso") || name.hasSuffix(".cdr") || name.hasSuffix(".bin") || name.hasSuffix(".img")
                   }),
                   let remoteName = isoEntry["name"] as? String,
                   let encodedName = remoteName.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed),
                   let dlURL = URL(string: "https://archive.org/download/\(identifier)/\(encodedName)") {
                    let (tempFileURL, _) = try await URLSession.shared.download(from: dlURL)
                    if FileManager.default.fileExists(atPath: destinationURL.path) {
                        try? FileManager.default.removeItem(at: destinationURL)
                    }
                    try FileManager.default.moveItem(at: tempFileURL, to: destinationURL)
                    return
                }
            }
        }

        throw CocoaError(.fileNoSuchFile, userInfo: [
            NSLocalizedDescriptionKey: "\(item.title) has no disc image on the Internet Archive that Krouton can download.",
        ])
    }

    /// Queries the live Internet Archive REST API (archive.org/advancedsearch.php) for optical ISO / CDR / BIN-CUE items
    func queryInternetArchiveLive(query: String) {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        let searchTerm = trimmed.isEmpty ? "macaddict OR systemrescue OR freedos OR homebrew iso" : trimmed
        self.isSearchingInternetArchive = true

        let rawQ = "(\(searchTerm)) AND mediatype:(software OR image) AND (format:(ISO Image) OR format:(BIN) OR title:(CD-ROM) OR title:(DVD))"
        guard let encodedQ = rawQ.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let url = URL(string: "https://archive.org/advancedsearch.php?q=\(encodedQ)&fl[]=identifier&fl[]=title&fl[]=description&fl[]=creator&fl[]=year&rows=8&page=1&output=json") else {
            self.isSearchingInternetArchive = false
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
                        let descRaw = (doc["description"] as? String) ?? "Internet Archive item (archive.org/details/\(ident)); not checked by the Depot"
                        let cleanDesc = descRaw.components(separatedBy: .newlines).joined(separator: " ").prefix(135)
                        let newItem = KroutonDepotCatalogItem(
                            id: String(itemID),
                            title: title,
                            subtitle: String(cleanDesc),
                            channel: "Internet Archive Live",
                            version: year,
                            sizeDisplay: "—",
                            architecture: "Archive.org Optical",
                            bootStandard: "ISO9660 / HFS / Raw Sector",
                            sha256Short: "",
                            sfSymbol: "building.columns.fill",
                            isDownloaded: false
                        )
                        self.depotItems.insert(newItem, at: 0)
                        addedCount += 1
                    }
                    self.announceForVoiceOver("Loaded \(addedCount) optical disc images from Internet Archive.")
                }
            } catch {
                self.announceForVoiceOver("The Internet Archive search didn't answer.")
            }
        }
    }

    func clearStagedFiles() {
        stagedFiles.removeAll()
        audioController.clearAll()
    }

}
