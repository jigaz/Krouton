# Krouton architecture

Krouton is one Swift package (`Package.swift`, Swift 6 language mode, warnings as errors) with ten library modules, the macOS app and a verification harness, plus Krouton Server in Rust. This page says what each part does and which rules hold them together. [CONTRIBUTING.md](CONTRIBUTING.md) says how to check a change against them.

## 1. 11 Core Modules (`KroutonDomainIdentity.Module`)
1. **`OpticalCore`** — Domain models, 28 optical format recipes, `BurnClaimLedger`, `SpanManifest` (BagIt files for every disc of a set), `KroutonDomainIdentity` (bundle identifier, folders, URLs), and the MMC command codec (`MMCCommand`, `MMCTransport`, `MMCDriveReport`). Zero external dependencies.
2. **`DriveKit`** — Optical hardware discovery, DiscRecording / IOKit arbitration, and media preflight; data, image and audio CD burns (`KroutonPCMTrackProducer` feeds rendered PCM to DiscRecording, session-at-once, with CD-Text and ISRCs). Also the read-only direct drive prototype (`KroutonMMCDirectAccess`, `KroutonMMCDeviceSession`): MMC commands sent through IOKit's SCSITaskLib, a possible fallback if DiscRecording is ever withdrawn.
3. **`BurnKit`** — `BurnSetScheduler` (multi-drive, with `BurnPowerAndBandwidthArbiter` staggering spin-ups), `BurnSetStager` (APFS `fclonefileat` CoW staging), `BusArbitrationState`.
4. **`ImageKit`** — Hybrid ISO-9660 / Joliet / UDF / El Torito LBA planner (PVD LBA 16, El Torito LBA 17, UDF LBA 256), `.cue/.bin` parser, SHA-256 sector inspector, `hdiutil makehybrid` image builder, and `KroutonUDFImageWriter` (UDF 2.50 with a metadata partition for Blu-ray, AVCHD and large-file data; ISO 9660 + UDF 1.02 in player order for DVD-Video; byte-identical to Krouton Server's writer), and `KroutonHFSImageWriter` (classic HFS in an Apple Partition Map, resource forks and Finder info kept, for Mac OS 9 and earlier).
5. **`AudioKit`** — Red Book CD-DA 75 fps (2,352 B/frame) mastering, lock-free `CrossfadeParameterMailbox`, CD-Text CRC-16, CUE sheet compiler, and `KroutonAudioDiscRenderer`, which renders a project (pauses, crossfades, trims) to one PCM file per track for the burn, or to a BIN/CUE pair.
6. **`VideoKit`** — DVD-5/DVD-9/BD-25/BD-50 bitrate budgeting, menu-preserving DVD-9 -> DVD-5 shrink, `.IFO` sector relinking, title extraction (MKV remux / MPEG copy), and AVCHD authoring (`M2TSStreamAnalyzer`, `BDMVNavigationWriter`, `AVCHDOnDVDAuthoringEngine`).
7. **`RescueKit`** — `KroutonDiscRescuer` (ddrescue's copy, trim, scrape and retry passes over any `KroutonSectorSource`), `KroutonRescueMap` (reads and writes GNU ddrescue mapfiles) and archival disc quality grading. The drive side is `MMCSectorSource` in `OpticalCore` (READ CAPACITY, READ(10)) over the `DriveKit` session; a disc without a C1/C2 scan is reported as not measured.
8. **`LabelKit`** — 300-DPI polar disc label geometry and 1:1 vector PDF print sheet generation.
9. **`NetworkSpool`** — Client for Krouton Server: `KRSP` 64-byte wire framing, RFC 6962 Merkle manifests, resumable uploads, commit-then-reveal pairing, pinned mutual TLS 1.3 with Ed25519 session proofs, Bonjour discovery, and folder bundles (`SpoolBundleWriter`) for discs the server builds itself.
10. **`Persistence`** — `SessionStore`, `RunLock` (`flock` crash recovery), localization catalog.
11. **`KroutonApp`** — Pure-SwiftUI macOS application (`Shell/App/KroutonAppKitBridge.swift` is its one AppKit file). `Shell/` holds the app, windows, menus, settings, state stores and services; `Features/` holds the workspaces (Data, AudioCD, Depot, Label, Retro, Rip, Video). `Resources/Manual/` is the user manual in Markdown, shown by `KroutonUserManualWindowView` and rendered for the web by `Scripts/build-manual.py`.

## 2. Dependency rules

- `OpticalCore` depends on nothing. Every other library depends on it; beyond that, `BurnKit` uses `DriveKit` and `ImageKit`, and `LabelKit` uses `AudioKit` and `RescueKit`. Nothing else crosses between libraries.
- `DriveKit` talks to hardware and never imports UI or networking frameworks.
- The portable six (`OpticalCore`, `AudioKit`, `LabelKit`, `RescueKit`, `Persistence`, `NetworkSpool`) depend only on each other and compile for iPadOS.
- Only `KroutonApp` and `KroutonVerify` see every module.

## 3. Verification Gates (`krouton-verify`)
- **Suite 1 & 2:** 11-module DAG isolation, Pure-SwiftUI Gate (zero `AppKit`/`NSColor`/`NSImage`/`NSView`, and no runtime AppKit lookups, in `Features/` and `Shell/` apart from `KroutonAppKitBridge.swift`), 400-LOC view ceiling, 500-LOC non-view ceiling, 200-LOC function ceiling, canonical `// MARK: -` headers, and `+Role.swift` naming.
- **Suite 3–27:** Domain math, sector formatting, 500-frame telemetry fuzzing, APFS CoW staging, lock-free audio parameter mailbox, and SplitMix64 distributed spool fault recovery.
- **Suite 28:** Integration Reachability Ratchet (`PENDING_INTEGRATION.md`), ensuring unwired public library types can only shrink over time.
- **Suite 29:** KRSP golden vectors, shared byte for byte with Krouton Server's Rust tests.
- **Suite 30:** `BurnSetScheduler` with scripted drives (retry only what failed, one disc per drive, staggered spin-up).
- **Suite 31:** Portable core. `OpticalCore`, `AudioKit`, `LabelKit`, `RescueKit`, `Persistence` and `NetworkSpool` depend only on each other and use no macOS-only framework or symbol outside `#if os(macOS)`, so an iPad app can share them. CI also compiles them for iPadOS (`ipados-portable-core` in `ci.yml`). `DriveKit`, `BurnKit`, `ImageKit` and `VideoKit` stay macOS-only: they drive burners and run `hdiutil`/`ffmpeg`. On iPad, burning goes through Krouton Server, which can build the disc from a folder (`burnFolder`).
- **Suite 32:** Direct drive access. The MMC codec decodes INQUIRY, GET CONFIGURATION, READ DISC INFORMATION and sense data from a scripted drive, including short and malformed replies.
- **Suite 33:** Published formats. The set index and `.krut` that Krouton writes are encoded and their keys compared with the JSON Schemas in `docs/schema/` (served at krouton.app/schema), so the published schemas can't drift from the code.
- **Suite 34:** Rescue. A scripted scratched disc (dead runs, a lone dead sector, a sector that reads on the third try) is rescued into memory; the suite checks the image, the bad-byte count, a bound on drive reads, the mapfile round trip (including a real ddrescue mapfile), that a resumed rescue re-reads only the bad sectors, and the READ(10)/READ CAPACITY command blocks.
- **Suite 36:** AVCHD on DVD. The M2TS analyzer on a synthetic stream (PIDs, key frames, times, AC-3 channels), `index.bdmv`, `MovieObject.bdmv`, the playlist and clip files read back field by field (the EP map decoded with libbluray's arithmetic), and the Swift UDF 2.50 writer against `Vectors/udf-bd-v1.sha256`, the Rust writer's image of the same folder. In CI (`avchd-real-encode`) it also converts real clips with ffmpeg, and libbluray opens, lists and seeks the result.
- **Suite 37:** Audio CD rendering. Three tones with a 2-second pause and a 1-second crossfade are rendered from an `AudioProject` by `KroutonAudioDiscRenderer`: the pause must land in track 2's pregap, the crossfade must overlap with no gap, every PCM file must be whole 2,352-byte frames, and the BIN/CUE export must carry the catalog number, the ISRC and INDEX 00/01 at the right times. DiscRecording's audio burn itself (`KroutonOpticalDriveBank+AudioBurn.swift`) needs a drive and a blank CD-R.
- **Suite 38:** Classic HFS. A folder with a resource fork, Finder types and a System Folder is written by `KroutonHFSImageWriter`; the suite checks the partition map, MDB, blessing and boot blocks, CI reads the image with an independent parser (`Scripts/check-hfs-image.py`, which also checks catalog order) and mounts it with Linux's HFS driver.
- **Suite 35:** Console discs. `KroutonConsoleDiscIdentifier` on synthetic headers for Wii, GameCube, Xbox, Dreamcast, Saturn and PlayStation (2048- and 2352-byte sectors), and the burnable/unburnable verdicts.

## 4. Krouton Server (`krouton-server/`)
A headless Rust server that burns discs for Krouton on another computer (Raspberry Pi, Linux, Proxmox, NAS, Windows 10/11, macOS 12+). Three crates: `krsp` (protocol, no dependencies), `server-core` (sessions, staging, jobs, burn backends, no dependencies) and `krouton-server` (TLS via rustls/ring, CLI). See `krouton-server/README.md`.

Two formats are shared between the app and the server and pinned by vectors in `Vectors/`, which both sides test against:

- **KRSP v1** (`krsp-control-v1.txt`): 64-byte frame headers, JSON control messages (hello, welcome, submit, job events), and extents checked against an RFC 6962 Merkle manifest.
- **Folder bundles v1** (`krsp-bundle-v1.tar`, `krsp-bundle-names-v1.txt`): a strict ustar/pax subset carrying only files and folders, with NFC names, sorted entries and the name rules of the most restrictive target (Windows and ISO 9660 with Joliet). The server turns a bundle into `tree/`, masters it, and burns the result.

## 5. Documentation

| Audience | Where |
|---|---|
| People burning discs | The manual, `Sources/KroutonApp/Resources/Manual/` → in the app (⌘?) and at krouton.app/manual |
| Server operators | `krouton-server/README.md`, krouton.app/server |
| Contributors | `README.md`, this file, `CONTRIBUTING.md`, `PENDING_INTEGRATION.md`, `CLAUDE.md` |
| Security researchers | `SECURITY.md`, krouton.app/.well-known/security.txt |
| History | `CHANGELOG.md`, `dev-notes/` |
