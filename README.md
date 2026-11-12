# Krouton — Optical Media Mastering, Sector Inspection & LAN Burning Suite for macOS

**Krouton** is a pure-SwiftUI macOS optical disc authoring, sector inspection, archival rescue, and distributed LAN burning studio built with Swift Package Manager. It combines local `IOKit` / `DiscRecording` hardware orchestration with **Krumb** (Port `7420`), a signed LAN spool-and-burn daemon protocol for remote USB/SATA optical drive banks.

---

## Architectural Highlights & Engineering Gates

* **100% Pure SwiftUI Desktop Architecture:** Zero `AppKit` / `NSWindow` / `NSPanel` / `NSViewRepresentable` symbols across all targets (enforced by automated AST/source gate in **Suite 1**).
* **Strict Global `<= 600 LOC` File Ceiling:** All **56 `.swift` files** across `Sources/` strictly obey a **600-LOC ceiling** (current repository max: **575 LOC**), continuously enforced by **Suite 21** of `krouton-verify`.
* **8-Target Modular SwiftPM Graph:** Clean separation between the hardware/wire core (`OpticalDough`), the 5 specialized culinary domain engines (`Marmalade`, `VideoOven`, `Tartine`, `Galette`, `Crustini`), the SwiftUI studio shell (`KroutonApp`), and the 21-suite invariant test harness (`KroutonVerify`).
* **Shared Studio UI Primitives:** All standalone mastering workspaces share `KroutonMasteringDeckCard` and `KroutonEmptyDropZoneView` (`Sources/KroutonApp/DesignSystem/KroutonSharedWorkspaceComponents.swift`) for uniform Display-P3 accent harmony, drop targeting, and localization.
* **213,290+ Automated Invariant Assertions:** Verified in under 1 second via `swift run krouton-verify`.

---

## 8-Target SwiftPM Module Graph

| Target | Type | Role & Core Responsibilities |
| :--- | :--- | :--- |
| **`OpticalDough`** | Library | Core hardware & domain foundation: `IOKit` / `DiscRecording` drive polling (`KroutonToasterBank`), Red Book audio preview (`KroutonCubeTasterEngine`), VideoToolbox hardware decode matrix (`KroutonPantryPrepEngine`), 2,048-byte/2,352-byte sector & hex inspection, Display-P3 color harmony math, and the **Krumb Port 7420** LAN client & security engine. |
| **`Marmalade`** | Library | **Red Book CD-DA & Audio Mastering Engine:** 75 fps (`2,352 B/frame`) MSF addressing, DAO `.cue` sheet compiler, 18-byte CD-Text pack generator with ITU-T CRC-16 (`0x1021`), ISRC (`ISO 3901`) & MCN/UPC barcode sanitizers, and equal-power trigonometric track crossfades. |
| **`VideoOven`** | Library | **DVD-Video, Blu-ray (BDMV) & Fit-to-Disc Shrink Engine:** Optical bitrate budget planner (`DVD-5`, `DVD-9`, `BD-25`, `BD-50`, `BD-100 XL`), menu-preserving `DVD-9 -> DVD-5` VOB quantization, `.IFO` / `.BUP` 32 KB ECC padding, and dual-layer seamless break removal. |
| **`Tartine`** | Library | **Hybrid File System & Archival LBA Planner:** Deterministic sector allocator for ISO-9660 Primary Volume Descriptor (`LBA 16`), El Torito Boot Record (`LBA 17`), UDF Anchor Volume Descriptor Pointer (`LBA 256`), SHA-256 content deduplication, and M-DISC Reed-Solomon `.par2` parity sizing. |
| **`Galette`** | Library | **Disc Image Depot & Sector Framing Engine:** Multi-track `.cue` parser, raw `2,352-byte` Mode 1 / Mode 2 XA `.bin` to `2,048-byte` `.iso` user-data payload extractor, and bootable OS/console signature classifier (El Torito, Apple Partition Map, Sega Saturn, PlayStation, Dreamcast, Xbox XDVDFS). |
| **`Crustini`** | Library | **Optical Rescue Copy & 300-DPI Polar Label Studio:** Adaptive bad-sector rescue reader (normal burst -> 1-sector step -> backwards retry) with rescue map logs, plus 120 mm / 80 mm CD/DVD/BD polar label geometry (`r = 24 mm..58 mm` safe printable annulus at 300 DPI). |
| **`KroutonApp`** | Executable (`Krouton`) | **3-Column SwiftUI Studio Application:** Left Format Chooser sidebar, central context-sensitive Mastering Workspace & Depot browser, right multi-drive Destination Rack, 120 Hz inline & floating Phase Scope oscilloscopes, and 9-pane Settings window. |
| **`KroutonVerify`** | Executable (`krouton-verify`) | **21-Suite Architectural & Mathematical Verification Harness:** Executes 213,290+ deterministic assertions covering module isolation, sector math, cryptography, fuzzing, and the global 600-LOC ceiling gate. |

---

## Repository Directory Tree

```text
Sources/
├── KroutonApp/
│   ├── App/
│   │   ├── KroutonApp.swift                            # 3-column SwiftUI studio shell & window scenes
│   │   └── KroutonStageImporter.swift                  # Drag-and-drop & file importer orchestration
│   ├── DesignSystem/
│   │   ├── KroutonThemeTokens.swift                    # Display-P3 surface tokens & adaptive color modifiers
│   │   ├── KroutonSharedWorkspaceComponents.swift      # KroutonMasteringDeckCard & KroutonEmptyDropZoneView
│   │   └── KroutonSplitDividerView.swift               # Interactive column resize handle
│   ├── NavigationAndRack/
│   │   ├── KroutonNavigationAndTelemetryBars.swift     # Left Format Chooser & central capacity bar
│   │   ├── KroutonBurnStationWorkspaceView.swift       # Dedicated Burn Station overview workspace
│   │   ├── KroutonDestinationRackViews.swift           # Right Destination Rack cards & per-drive controls
│   │   └── KroutonDestinationSubViews.swift            # Destination rack column & Krumb LAN toaster cards
│   ├── Workspaces/
│   │   ├── AudioMasteringWorkspaces.swift              # Red Book CD-DA & Car-Safe MP3/FLAC workspaces
│   │   ├── VideoAuthoringWorkspaces.swift              # DVD-Video, BDMV & Fit-to-Disc authoring studio
│   │   ├── DataAndArchivalWorkspaces.swift             # Hybrid HFS+/Joliet/UDF & M-DISC PAR2 vault studio
│   │   ├── RetroConsoleWorkspaces.swift                # PS1, PS2, Dreamcast, Saturn, GameCube, Wii & Xbox deck
│   │   ├── DiscImageInspectorWorkspace.swift           # LBA 0/16/17/256 hex inspector & .BIN <-> .ISO converter
│   │   ├── CopyAndRipWorkspaces.swift                  # Optical Rescue Copy, CD Ripper & MKV/MP4 Remuxer
│   │   ├── DiscLabelStudioWorkspace.swift              # 120mm / 80mm 300-DPI polar disc label designer
│   │   └── MasteringTelemetryPopovers.swift            # Live Tartine LBA, Marmalade CUE & VideoOven popovers
│   ├── Depot/
│   │   ├── KroutonDepotWorkspaceView.swift             # Built-in Linux, BSD, Retro & Rescue ISO Depot browser
│   │   ├── KroutonDepotCatalogViews.swift              # Filterable cards, SHA-256 verification & direct staging
│   │   ├── KroutonDepotHeroStudio.swift                # Metal-accelerated .drawingGroup hero vector canvas
│   │   ├── KroutonDepotHeroSonic.swift                 # Vector hero artwork renderer (16-bit era)
│   │   ├── KroutonDepotHeroMario.swift                 # Vector hero artwork renderer (platformer era)
│   │   └── KroutonDepotHeroConsoleEmblems.swift        # Vector optical hardware & console emblem renderers
│   ├── ModalsAndSettings/
│   │   ├── KroutonFloatingPhaseScopeWindow.swift       # 120Hz P-CAV / CLV phosphor phase scope window
│   │   ├── KroutonPhaseScopeMiniViews.swift            # Inline mini scopes & 6-channel telemetry grid
│   │   ├── KroutonAuxModalsAndScopes.swift             # Optical media inspector modal & completion report
│   │   ├── KroutonSettingsWindow.swift                 # 9-pane Settings window shell & Appearance/Hardware tabs
│   │   ├── KroutonSettingsWindow+Panes.swift           # Audio, Video, File System & Console settings panes
│   │   └── KroutonSettingsWindow+AdvancedPanes.swift   # Krumb LAN, Codec Matrix & Bakery Glossary panes
│   ├── Services/
│   │   └── KroutonHardwareAndVerifyServices.swift      # Background SHA-256 & optical media verification helpers
│   ├── StateAndModels/
│   │   ├── KroutonStateDomainModels.swift              # App-level enums, appearance modes & batch queue models
│   │   ├── KroutonStateStore.swift                     # Core @MainActor ObservableObject store & localization
│   │   ├── KroutonStateStore+StagingAndCatalog.swift   # File staging, Internet Archive query & engine bridges
│   │   ├── KroutonStateStore+DestinationQueue.swift    # Multi-drive queue assignment & execution orchestration
│   │   ├── KroutonDepotStaticCatalog.swift             # Curated optical archival & rescue image catalog
│   │   └── KroutonBakeryGlossary.swift                 # Searchable optical engineering & culinary glossary
│   └── Resources/
│       └── *.lproj/Localizable.strings                 # Multi-language localization bundles
├── OpticalDough/
│   ├── Models/
│   │   ├── OpticalDriveAndAudioModels.swift            # KroutonToasterInfo, KroutonAudioCube & CubeTasterEngine
│   │   ├── OpticalSectorAndTelemetryModels.swift       # Boot inspector, LBA file entry & thermometer models
│   │   ├── OpticalMasteringDomainModels.swift          # Shared TOC, video title & mastering config structs
│   │   └── OpticalRecipeCatalog.swift                  # Type-safe recipe catalog & file extension routing rules
│   ├── ToasterBank/
│   │   ├── KroutonToasterBank.swift                    # IOKit / DiscRecording bus scanner & drive state bank
│   │   ├── KroutonToasterBank+DiscOperations.swift     # Phase scope test sweep, eject, erase & image creation
│   │   └── KroutonToasterBank+BurnAndSector.swift      # Physical DRBurn execution & .BIN/.CUE <-> .ISO converter
│   ├── InspectorsAndPrep/
│   │   └── KroutonPantryPrepAndColorEngine.swift       # VideoToolbox hardware matrix, hex reader & Display-P3 math
│   └── Krumb/
│       ├── KrumbWireModels.swift                       # Port 7420 wire models, mDNS discovery & WebSocket client
│       └── KrumbSpoolAndSecurityEngine.swift           # Spool-and-burn pipeline, HMAC-SHA256 & anti-replay guard
├── Marmalade/
│   └── MarmaladeEngine.swift                           # Red Book CUE compiler, 18B CD-Text CRC-16 & crossfade DSP
├── VideoOven/
│   └── VideoOvenEngine.swift                           # DVD/BD bitrate budgeting, DVD-9 shrink & .IFO relinking
├── Tartine/
│   └── TartineEngine.swift                             # ISO-9660 / El Torito / UDF LBA planner & deduplication
├── Galette/
│   └── GaletteEngine.swift                             # .CUE parser, 2352B->2048B extractor & boot classifier
├── Crustini/
│   └── CrustiniEngine.swift                            # Optical rescue copy state machine & 300-DPI label math
└── KroutonVerify/
    ├── main.swift                                      # Test harness runner & summary reporter
    ├── KroutonVerifySuites01To10.swift                 # Suites 1–10 (Architecture, Red Book, LBA, Hex, Krumb, Color)
    └── KroutonVerifySuites11To21.swift                 # Suites 11–21 (Culinary engines, Fuzzing & Global 600-LOC Gate)
```

---

## Krumb Port 7420 Distributed LAN Burning Protocol

**Krumb** allows Krouton to treat remote Linux/macOS/Raspberry Pi optical drive appliances on the local network as first-class destinations alongside local USB/Thunderbolt drives:

1. **ZeroConf Discovery (`_krumb._tcp.local.` on Port `7420`):** Automatically discovers LAN toaster nodes via `NWBrowser` and sanitizes RFC-1123 hostnames.
2. **Pantry Pre-Flight & `1.0 GiB` Free Space Guard (`POST /api/v1/pantry/slot`):** Reserves staging storage on the remote node and enforces a strict `>= 1,073,741,824` byte headroom floor before spooling.
3. **Chunked Loaf Spooling & SHA-256 Seal (`PUT /api/v1/pantry/loaf/{id}`):** Streams the mastered image with end-to-end SHA-256 verification and `2,500 ms` staggered multi-drive spin-up protection.
4. **RFC-1918 Private Subnet & HMAC-SHA256 Anti-Replay Security (`KrumbLANSecurityEngine`):**
   * Rejects non-private/WAN targets outside `127.0.0.0/8`, `10.0.0.0/8`, `172.16.0.0/12`, `192.168.0.0/16`, `169.254.0.0/16`, `::1`, `fc00::/7`, `fe80::/10`, and `.local`.
   * Signs dispatches with **HMAC-SHA256** over canonical `<timestamp>.<nonce>.<sha256(body)>` payloads with a `±300s` clock-skew window and bounded nonce replay cache.
5. **Monotonic WebSocket Telemetry Sanitizer (`KrumbTelemetrySanitizer`):** Clamps NaN/out-of-bounds speeds and FIFO percentages, blocks terminal state regressions (`FRESH_OUT_OF_OVEN`, `BURNT_TOAST`, `CANCELLED`), and guarantees monotonic progress across UDP/WebSocket frames.

---

## Building, Running & Verifying

### 1. Build the Studio App & Run All 21 Verification Suites

```zsh
swift build --product Krouton
swift run krouton-verify
```

### 2. Update the macOS `.app` Bundle

```zsh
cp -f .build/debug/Krouton build/Krouton.app/Contents/MacOS/Krouton
chmod +x build/Krouton.app/Contents/MacOS/Krouton
codesign --force --deep --sign - build/Krouton.app 2>/dev/null || true
open build/Krouton.app
```

### 3. Check the Repository-Wide File Size Leaderboard (Global 600-LOC Ceiling)

```zsh
python3 -c 'import glob; files = sorted([(len(open(p).readlines()), p) for p in glob.glob("Sources/**/*.swift", recursive=True)], reverse=True); print("\n".join(f"{c:4d} LOC | {p}" for c, p in files[:15])); print(f"\nTotal files: {len(files)} | Max LOC: {files[0][0]} (Ceiling: 600)")'
```

---

## The 21 Automated Verification Suites (`krouton-verify`)

| Suite | Verification Scope |
| :--- | :--- |
| **Suite 1** | 100% AppKit-Free Clean Modular Architecture & Zero Banned Symbols Gate |
| **Suite 2** | Specialized Bakery Sub-Modules (`Marmalade`, `VideoOven`, `Tartine`, `Galette`, `Crustini`) |
| **Suite 3** | Red Book CD-Text, ISRC (`ISO 3901`) & MCN Sanitizer Constraints |
| **Suite 4** | Red Book Audio Cube Frame (`75 fps`) & PCM Byte (`2,352 B/frame`) Math |
| **Suite 5** | ISO-9660 / Joliet / UDF File Entry Limits & `2,048-Byte` LBA Math |
| **Suite 6** | SHA-256 Digest & `2,048-Byte` Sector Hex Dump Inspector |
| **Suite 7** | Hardware Acceleration Codec Matrix & Container Stream Probing (`VideoToolbox`) |
| **Suite 8** | Krumb Wire Protocol `Codable` Round-Trip & mDNS Host Sanitization |
| **Suite 9** | IEEE-754 `RGB <-> HSB` Round-Trip & 10-Swatch Display-P3 Harmony Polarity |
| **Suite 10** | Krumb LAN Security Engine (RFC-1918 Subnet Guard, HMAC-SHA256 & Anti-Replay) |
| **Suite 11** | `Marmalade` Red Book CUE Sheet Compiler, 18B CD-Text CRC-16 & Equal-Power Crossfade |
| **Suite 12** | `Tartine` Hybrid Data LBA Planner (PVD LBA 16, El Torito LBA 17, UDF LBA 256 & Deduplication) |
| **Suite 13** | `VideoOven` Optical Bitrate Budget (`DVD-5`/`DVD-9`/`BD-25`/`BD-50`) & DVD-9 Shrink Math |
| **Suite 14** | `Galette` Disc Image Depot (`.cue` Parser, `2352B->2048B` BIN Extractor & Boot Classifier) |
| **Suite 15** | `Crustini` Optical Rescue Copy Engine & Polar 300-DPI Label Geometry |
| **Suite 16** | Zero Shell-Injection Process Gate & 500-Frame Telemetry State Machine Fuzzing |
| **Suite 17** | End-to-End 5-Module Mastering & LAN Signed Dispatch Integration Pipeline |
| **Suite 18** | `VideoOven` `DVD-9 -> DVD-5` Menu-Preserving Shrink, `.IFO` Relinking & Layer-Break Removal |
| **Suite 19** | Type-Safe Optical Recipe Catalog, Workspace Routing & File Extension Invariants |
| **Suite 20** | Mastering & Extraction Domain Models (TOC, Video Titles & Config `Codable` Round-Trip) |
| **Suite 21** | Phase 4 Workspace Modularization, Shared UI Primitives & Global `<= 600 LOC` Ceiling Gate |
