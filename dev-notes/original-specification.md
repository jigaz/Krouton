> **Historical document.** This is the brief Krouton was first built from, kept for the record. The "Bakery" vocabulary (Toaster, Slice, Loaf, Krumb) and the REST/WebSocket daemon it describes were never adopted: the network side became Krouton Server and KRSP v1 (see `krouton-server/README.md`), and the code uses plain optical terms apart from a few leftover names such as `KroutonBakeBatchItem`. For how Krouton works today, read `ARCHITECTURE.md`.

# Krouton & Krumb ("The Bakery") — Master Architecture & Rebuild Specification


## 1. Product Vision & Ecosystem Overview
**Krouton** is a native macOS (SwiftUI + AppKit + Metal) optical disc mastering, archival, ripping, and label-printing application. It pairs with **Krumb**, a headless cross-platform Rust daemon that exposes physical optical drives over the local network via mDNS (`_krumb._tcp.local.`, Port `7420`), REST, and WebSockets.

### Core Design Principles
1. **Zero Coasters (Spool-and-Burn):** Network burns never stream raw sectors over Wi-Fi directly to a live laser. Krouton spools the compiled image/tracks ("Loaf" / "Cubes") to Krumb's local temp directory ("Pantry", enforcing >= 1 GiB free space) before initiating DAO/SAO laser writing.
2. **4-Mode Display-P3 Color Harmony:** Every surface, vector graphic, and oscilloscope trace adapts dynamically across 4 visual states:
   - **Dark Mode — Primary Only:** Obsidian surfaces with primary accent highlights.
   - **Dark Mode — Primary + Harmony:** Window background tinted with `11%` primary accent; borders, badges, and secondary curves rendered in a locked split-complementary Display-P3 harmony color.
   - **Light Mode — Primary Only:** High-contrast daylight alabaster paper surfaces with deep plotter-ink accents.
   - **Light Mode — Primary + Harmony:** Warm `8.5%` primary paper tint with high-contrast light-mode harmony ink borders (`42%` opacity) and dual-tone graphics.
3. **Low Background CPU & RAM Footprint:** Waveform paths cap vertex counts (`<= 64` quadratic spline control points), graticules batch into single `Path` draw calls, and ephemeral burn caches purge automatically after verification.

---

## 2. Ubiquitous Language ("The Bakery")
All internal models, API payloads, and UI telemetry share a strict culinary domain vocabulary:

| Optical Concept | Bakery Term | Swift Type (`Krouton`) | Rust Type (`Krumb`) |
| :--- | :--- | :--- | :--- |
| **Optical Burner / Drive** | **Toaster** | `KroutonToasterInfo` | `ToasterInfo` |
| **Multi-Drive Controller** | **ToasterBank** | `KroutonToasterBank` | `ToasterBank` |
| **Drive Tray State** | **Rack** | `KrumbRackState` (`Closed`, `Open`, `Locked`) | `RackState` |
| **Inserted Disc Media** | **Slice** | `KrumbSliceMedia` (`Empty`, `BlankCdR`, `BlankCdvdR`, `ToastedCrouton`) | `SliceMedia` |
| **Finished Burned Disc** | **Crouton** | `ToastedCrouton` | `SliceMedia::ToastedCrouton` |
| **Failed Burn (Coaster)** | **BurntToast** | `KroutonBurntToastSeverity` | `KitchenEvent::BurntToast` |
| **Compiled Disc Job** | **Loaf / Batch** | `KroutonBakeBatchItem` | `BakeRequest` |
| **Audio Track (CD-DA)** | **Cube** | `KroutonAudioCube` | `Cube` |
| **CD-TEXT / ISRC / MCN** | **Seasoning** | `KrumbSeasoning` | `Seasoning` |
| **Remote Spool Directory** | **Pantry** | `KrumbPantryCalibrationResult` | `Pantry` |
| **Write Speed Multiplier** | **Heat** | `heatX: UInt8` | `heat_x: u8` |
| **Simulation vs. Real Burn**| **ProofOnly / Toast**| `KrumbBakeMode` | `BakeMode` |
| **Virtual Test Burner** | **EasyBake** | `isEasyBake: Bool` | `--easy-bake --slots N` |
| **Crash / Debug Bundle** | **DoggyBag** | `KrumbDoggyBagPolicy` | `DoggyBagPolicy` |
| **Phase Scope & Flight Log**| **Thermometer** | `KroutonKitchenThermometer` | `KitchenThermometer` |

---

## 3. Application Architecture & Module Layout (11-Target Swift 6 Package)
- **Core & Engine Modules (`Sources/`):**
  - `OpticalCore`: Domain models, LBA math, Red Book 75-fps math, `KroutonSpanningDiscMedium`.
  - `DriveKit`: Hardware discovery (`IOKit` / `DiscRecording` / `DiskArbitration` / `hdiutil`), ATIP/MID media inspection, and MMC bitsetting.
  - `ImageKit`: Hybrid ISO-9660/UDF/El Torito LBA planner, CUE/BIN extractor, SHA-256 & hex inspector.
  - `AudioKit`: Red Book CUE compiler, 18B CD-TEXT CRC-16 encoder, equal-power crossfade DSP.
  - `VideoKit`: Optical bitrate budgeter, DVD-9 to DVD-5 shrink engine, IFO relinker, AVCHD muxer.
  - `BurnKit`: `DiscSpanningEngine`, frozen `BurnSet` state machine, single-read stager.
  - `RescueKit`: Bad-sector optical rescue engine and archival disc quality grader.
  - `LabelKit`: Polar 300-DPI disc geometry engine and 1:1 vector PDF print sheet generator.
  - `NetworkSpool`: Port `7420` remote optical burn server (`Krumb`) and spool telemetry.
  - `Persistence`: `SessionStore`, `RunLock` crash recovery, and security-scoped bookmark vault.
  - `KroutonVerify`: Automated 22-suite architectural verification gate (`krouton-verify`).
- **`Sources/KroutonApp` (SwiftUI Studio Interface, AppIntents & Headless CLI):**
  - `KroutonApp.swift`: Window management (`NSWindow` delegates for main studio, settings, and pop-out floating Phase Scope).
  - `KroutonModels.swift` & `KroutonThemeEngine.swift`: `@Published` state store backed by `UserDefaults` persistence and the 10-preset Display-P3 Color Harmony Look-Up Table (LUT).
  - `KroutonNavigationAndTelemetryBars.swift`: Top status bar, bottom capacity/LBA fuel gauge bar, and 120mm Disc Label Studio canvas.
  - `KroutonMasteringWorkspaces.swift`, `KroutonDepotCatalogViews.swift`, `KroutonDepotHeroStudio.swift`: Central adaptive workspaces.
  - `KroutonDestinationRackViews.swift`: Right-hand multi-destination output rack.
  - `KroutonAuxModalsAndScopes.swift`: Inline mini and floating GPU Phase Scopes ("Thermometers").
  - `KroutonSettingsWindow.swift`: 8-pane `NavigationSplitView` Settings window.

---

## 4. Detailed Feature Set & UI Layout
- **Left Sidebar (`NavigationSplitView`):** `FORMATS`, `DISC IMAGE DEPOT`, `COPY`, and `LABEL` (`Auto Label` / `Manual Label`).
- **Central Adaptive Workspace:** Data & Console Mastering, Red Book Audio CD (`CD-DA`) Mastering Studio, Disc Image Depot & CAD Blueprint Hero, and 120mm Disc Label Studio.
- **Right-Hand Destination Queue Rack:** Simultaneous Physical Burner, Network Burner (`Krumb` LAN Node on Port `7420`), and Disc Image File cards.
- **The "Jewel" Phase Scope:** Inline mini and pop-out floating oscilloscope with Transport Chrono bar, `Speed` / `Motor RPM` / `Target P-CAV` / `Buffer` traces, and 6 bottom channel-strip cards.
- **Settings Window (8 Panes):** `General`, `Format Chooser`, `Disc Image Depot`, `Audio & Video`, `Ripping & Transcoding`, `Burners & Network`, `Labels & Printers`, and `Notifications & Accessibility`.
