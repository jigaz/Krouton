import DriveKit
import Foundation
import ImageKit
import OpticalCore
import SwiftUI
import VideoKit

/// Headless command-line interface for Krouton (`krouton` / `Krouton`).
// MARK: - KroutonCLIRunner

enum KroutonCLIRunner {
    static let versionString = "1.0.0"

    private static let cliSubcommands: Set<String> = [
        "--help", "-h", "help",
        "--version", "-v", "version",
        "drives", "formats", "inspect", "span", "iso", "completions"
    ]

    static func shouldRunHeadlessCLI(arguments: [String] = CommandLine.arguments) -> Bool {
        let userArgs = arguments.dropFirst().filter { arg in
            !arg.hasPrefix("-NS") && !arg.hasPrefix("-Apple") && !arg.hasPrefix("-psn_")
        }
        guard let first = userArgs.first else { return false }
        return cliSubcommands.contains(first.lowercased())
    }

    @MainActor
    static func evaluate(arguments: [String]) -> (exitCode: Int32, output: String) {
        let args = Array(arguments.dropFirst().filter {
            !$0.hasPrefix("-NS") && !$0.hasPrefix("-Apple") && !$0.hasPrefix("-psn_")
        })
        guard let sub = args.first?.lowercased() else {
            return (0, helpText)
        }
        let rest = Array(args.dropFirst())
        let wantsJSON = rest.contains("--json")

        switch sub {
        case "--help", "-h", "help":
            return (0, helpText)

        case "--version", "-v", "version":
            if wantsJSON {
                return (0, "{\"name\":\"krouton\",\"version\":\"\(versionString)\"}")
            }
            return (0, "krouton \(versionString) (macOS Optical Media Mastering Suite)")

        case "formats":
            let specs = KroutonOpticalWorkflowCatalog.defaultFormats
            if wantsJSON {
                let items = specs.map { s -> [String: Any] in
                    let media = KroutonSpanningDiscMedium.allowedMedia(forFormatID: s.id).map(\.rawValue)
                    return [
                        "id": s.id,
                        "technicalName": s.technicalName,
                        "colloquialName": s.colloquialName,
                        "laserType": s.laserType,
                        "bookOrFileSystem": s.bookOrFileSystem,
                        "supportsTargetDiscSize": KroutonSpanningDiscMedium.supportsTargetDiscSizeSelection(forFormatID: s.id),
                        "allowedMedia": media
                    ]
                }
                if let data = try? JSONSerialization.data(withJSONObject: items, options: [.prettyPrinted, .sortedKeys]),
                   let str = String(data: data, encoding: .utf8) {
                    return (0, str)
                }
            }
            let lines = specs.map { s in
                let mediaCount = KroutonSpanningDiscMedium.allowedMedia(forFormatID: s.id).count
                return "\(s.id.padding(toLength: 18, withPad: " ", startingAt: 0))  \(s.technicalName.padding(toLength: 38, withPad: " ", startingAt: 0))  [\(s.laserType)] (\(mediaCount) disc sizes)"
            }
            return (0, (["ID                  TECHNICAL FORMAT                        LASER & SIZES"] + lines).joined(separator: "\n"))

        case "drives":
            let bank = KroutonOpticalDriveBank()
            bank.refreshDrives()
            let drives = bank.availableDrives
            if wantsJSON {
                let items = drives.map { d -> [String: Any] in
                    [
                        "id": d.id,
                        "displayName": d.displayName,
                        "firmware": d.firmware,
                        "bsdDeviceNode": d.bsdDeviceNode,
                        "mediaType": d.mediaType,
                        "isMediaPresent": d.isMediaPresent,
                        "isMediaBlank": d.isMediaBlank,
                        "freeSectorsLBA": d.freeSectorsLBA,
                        "freeBytes": d.freeBytes,
                        "mediaManufacturer": d.mediaManufacturer
                    ]
                }
                if let data = try? JSONSerialization.data(withJSONObject: items, options: [.prettyPrinted, .sortedKeys]),
                   let str = String(data: data, encoding: .utf8) {
                    return (0, str)
                }
            }
            if drives.isEmpty {
                return (0, "No optical drives detected.")
            }
            let lines = drives.map { d in
                "\(d.displayName) [FW \(d.firmware)] (\(d.bsdDeviceNode)) — \(d.statusBadgeText) • Free: \(d.freeSectorsLBA) LBA • MID: \(d.mediaManufacturer)"
            }
            return (0, lines.joined(separator: "\n"))

        case "inspect":
            let paths = rest.filter { !$0.hasPrefix("-") }
            guard let rawPath = paths.first else {
                return (2, "Usage: krouton inspect <image-path> [--sha256] [--json]")
            }
            let url = URL(fileURLWithPath: (rawPath as NSString).expandingTildeInPath)
            guard FileManager.default.fileExists(atPath: url.path) else {
                return (1, "Error: File not found at \(url.path)")
            }
            let rep = DiscImageDepotOperations.inspectImageFile(at: url)
            let c = rep.classification
            let sha = rest.contains("--sha256") ? KroutonElToritoBootInspector.computeSHA256Hex(url: url) : ""
            if wantsJSON {
                var dict: [String: Any] = [
                    "path": url.path,
                    "filesystems": c.detectedFilesystems,
                    "isBootable": c.isBootable,
                    "bootStandard": c.bootStandard,
                    "totalSectors2048": c.totalSectors2048,
                    "recommendedMedia": c.recommendedMediaBadge,
                    "cueTrackCount": rep.cueTracks.count
                ]
                if !sha.isEmpty { dict["sha256"] = sha }
                if let data = try? JSONSerialization.data(withJSONObject: dict, options: [.prettyPrinted, .sortedKeys]),
                   let str = String(data: data, encoding: .utf8) {
                    return (0, str)
                }
            }
            var out = [
                "File:             \(url.path)",
                "Filesystems:      \(c.detectedFilesystems.joined(separator: ", "))",
                "Bootable:         \(c.isBootable ? "Yes (\(c.bootStandard))" : "No")",
                "Sectors (2048B):  \(c.totalSectors2048) LBA",
                "Recommended Disc: \(c.recommendedMediaBadge)"
            ]
            if !sha.isEmpty { out.append("SHA-256:          \(sha)") }
            return (0, out.joined(separator: "\n"))

        case "span":
            var medium: KroutonSpanningDiscMedium = .dvd5Single
            var paths: [String] = []
            var idx = 0
            while idx < rest.count {
                let tok = rest[idx]
                if (tok == "--medium" || tok == "-m"), idx + 1 < rest.count {
                    medium = Self.parseMediumToken(rest[idx + 1])
                    idx += 2
                    continue
                } else if !tok.hasPrefix("-") {
                    paths.append(tok)
                }
                idx += 1
            }
            guard !paths.isEmpty else {
                return (2, "Usage: krouton span [--medium cd650|cd700|dvd5|dvd9|bd25|bd50|bdxl100|bdxl128] <files...> [--json]")
            }
            let entries: [KroutonStagedFileEntry] = paths.compactMap { p in
                let u = URL(fileURLWithPath: (p as NSString).expandingTildeInPath)
                guard FileManager.default.fileExists(atPath: u.path) else { return nil }
                return KroutonOpticalDriveBank.inspectFileOrFolder(url: u)
            }
            let plan = DiscSpanningEngine.planDataDiscs(entries, medium: medium)
            if wantsJSON {
                let dict: [String: Any] = [
                    "medium": medium.rawValue,
                    "capacitySectorsLBA": medium.maxDataSectors2048,
                    "capacityBytes": medium.maxPayloadBytes,
                    "discCount": plan.discs.count,
                    "isBurnable": plan.isBurnable
                ]
                if let data = try? JSONSerialization.data(withJSONObject: dict, options: [.prettyPrinted, .sortedKeys]),
                   let str = String(data: data, encoding: .utf8) {
                    return (0, str)
                }
            }
            var lines = ["Target Medium: \(medium.rawValue) (\(medium.maxDataSectors2048) LBA / disc) — \(plan.discs.count) Disc(s)"]
            for d in plan.discs {
                lines.append("  Disc \(d.number): \(d.items.count) item(s) • \(d.usedUnits) / \(d.capacityUnits) LBA")
            }
            return (0, lines.joined(separator: "\n"))

        case "iso":
            var volName = "KROUTON_DISC"
            var outPath = "~/Desktop/KROUTON_DISC.iso"
            var srcPath: String? = nil
            var i = 0
            while i < rest.count {
                let t = rest[i]
                if (t == "--volume" || t == "-V"), i + 1 < rest.count {
                    volName = rest[i + 1]; i += 2; continue
                } else if (t == "--out" || t == "-o"), i + 1 < rest.count {
                    outPath = rest[i + 1]; i += 2; continue
                } else if !t.hasPrefix("-") {
                    srcPath = t
                }
                i += 1
            }
            guard let src = srcPath else {
                return (2, "Usage: krouton iso --volume <TITLE> --out <output.iso> <source-folder>")
            }
            let srcURL = URL(fileURLWithPath: (src as NSString).expandingTildeInPath)
            let outURL = URL(fileURLWithPath: (outPath as NSString).expandingTildeInPath)
            do {
                let bytes = try OpticalDiscVolumeScanner.buildOpticalISOImage(sourceDirectory: srcURL, outputISOURL: outURL, volumeName: volName)
                return (0, "Mastered \(outURL.path) (\(bytes) bytes, \(bytes / 2048) LBA)")
            } catch {
                return (1, "Error: \(error.localizedDescription)")
            }

        case "completions":
            let shell = rest.first?.lowercased() ?? "zsh"
            return (0, completionScript(for: shell))

        default:
            return (2, "Unknown subcommand '\(sub)'. Run 'krouton --help' for usage.")
        }
    }

    static func parseMediumToken(_ raw: String) -> KroutonSpanningDiscMedium {
        let l = raw.lowercased()
        if l.contains("650") || l.contains("74") { return .cd74Min650MB }
        if l.contains("700") || l.contains("80") || l == "cd" { return .cd80Min700MB }
        if l.contains("800") || l.contains("90") { return .cd90Min800MB }
        if l.contains("mini") || l.contains("1.46") { return .miniDVD80mm }
        if l.contains("dvd9") || l.contains("dvd-9") || l.contains("8.5") { return .dvd9Dual }
        if l.contains("bd25") || l.contains("bd-25") || l.contains("25") { return .bd25Single }
        if l.contains("bd50") || l.contains("bd-50") || l.contains("50") { return .bd50Dual }
        if l.contains("100") { return .bdxl100Triple }
        if l.contains("128") { return .bdxl128Quad }
        return .dvd5Single
    }

    static let helpText = """
    KROUTON — macOS Optical Media Mastering Suite & CLI (v\(versionString))

    USAGE:
      krouton                           Launch the interactive macOS SwiftUI workspace
      krouton <subcommand> [options]    Run headless optical mastering & inspection tools

    SUBCOMMANDS:
      drives [--json]                   List connected optical drives, firmware & ATIP/MID media status
      formats [--json]                  List all optical mastering workflows & supported disc sizes
      inspect <file> [--sha256] [--json] Inspect .iso/.dmg/.bin/.cue bootability, LBA sectors & SHA-256
      span [--medium <size>] <files...> Calculate multi-disc spanning plan (cd650..bdxl128)
      iso -V <title> -o <out.iso> <dir> Build a hybrid UDF + ISO-9660 + Joliet optical disc image
      completions <zsh|bash|fish>       Generate shell tab-completion script
      --version, -v                     Print version information
      --help, -h                        Print this help message
    """

    static func completionScript(for shell: String) -> String {
        switch shell {
        case "bash":
            return "complete -W 'drives formats inspect span iso completions --help --version --json' krouton Krouton"
        case "fish":
            return [
                "complete -c krouton -f -a 'drives formats inspect span iso completions'",
                "complete -c krouton -l json -d 'Output structured JSON'",
                "complete -c krouton -l help -s h -d 'Show help'",
                "complete -c krouton -l version -s v -d 'Show version'"
            ].joined(separator: "\n")
        default:
            return """
            #compdef krouton Krouton
            _krouton() {
              local -a commands
              commands=(
                'drives:List connected optical drives and media status'
                'formats:List optical workflows and allowed disc sizes'
                'inspect:Inspect an optical disc image (.iso, .dmg, .bin, .cue)'
                'span:Calculate multi-disc spanning plan across 650MB..128GB media'
                'iso:Build a hybrid UDF/ISO-9660/Joliet disc image'
                'completions:Generate shell completion script'
              )
              _describe 'command' commands
            }
            _krouton "$@"
            """
        }
    }
}

/// Where the app starts: a headless CLI run, or the windowed app. Called by `Sources/KroutonMain`
/// (`swift run Krouton`) and by the Xcode project's app target.
public enum KroutonEntryPoint {
    @MainActor
    public static func main() {
        if KroutonCLIRunner.shouldRunHeadlessCLI() {
            let result = KroutonCLIRunner.evaluate(arguments: CommandLine.arguments)
            print(result.output)
            Foundation.exit(result.exitCode)
        }
        KroutonApp.main()
    }
}
