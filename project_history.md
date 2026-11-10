# Krouton Project History & Architecture Log

## Current Version: `v0.2.0-alpha.6` (Per-File Mac/PC Visibility, Pre-Flight Sanity & Retro Console ROM Mastering)
* **Target OS:** macOS 26 (Tahoe) / Apple Silicon (`arm64`)
* **Domain:** [krouton.app](https://krouton.app)

### Completed Milestones
* **Step 2A–2C (`v0.2.0-alpha.3` .. `alpha.5`):**
  - Fixed `ContiguousArrayBuffer` removal crash with UUID-safe destination bindings.
  - Built textured **Disc Media Inspector Popover** with media-accurate disc icons (`CD-RW`, `CD-R`, `DVD-R`, `BD-R`, `M-DISC`, `DVD-RAM`) and mounted volume/file scanning.
  - Built per-burner auto-hiding **Inline Mini Phase Scope** and click-to-pop-out **Floating Phase Scope Window** with 5-layer telemetry.
* **Step 2D (`v0.2.0-alpha.6` — Current Commit):**
  1. **LiquidCD-Inspired Per-File Mac (`HFS+`) & PC (`ISO9660 / Joliet / UDF`) Visibility Toggles:**
     - Added `showOnMac` and `showOnPC` flags to `StagedFileEntry`.
     - Added interactive `[ Mac]` and `[⊞ PC]` pill buttons on every row in the Data Disc File List.
     - Wired `startPhysicalDataBurn` and `createDiscImageFile` to set per-item `DRFSObject.setExplicitFilesystemMask(...)` so Mac-only files are hidden on Windows and PC-only files (`autorun.inf`, `.exe`) are hidden on macOS Finder.
  2. **K3b / ImgBurn Pre-Flight Sanity & Compatibility Banner:**
     - Automatically inspects staged files for `> 4 GB` single-file ISO9660 overflow (requiring UDF), Joliet `> 64 char` filename truncation, and ATIP overburn risks.
  3. **Retro Console ROM & Preservation Mastering Bar (PS1, PS2, GameCube, Wii, Xbox/360):**
     - **PS1 / Saturn / Sega CD (`CD-ROM XA Mode 2 Form 1/2`):** Raw 2,352-byte sector `.cue/.bin` verification, `DAO/96` subchannel Q (`+SubQ` / LibCrypt), and `4x–8x CLV` laser reflection guard (warns if `CD-RW` is inserted since retro pickups cannot read phase-change reflectivity).
     - **PS2 (`DVD / CD`):** `FreeDVDBoot` / `ESR` UDF 1.02 + ISO9660 descriptor verification and `DVD+R -> DVD-ROM` Book Type bitsetting.
     - **GameCube (`RVZ / GCM`) & Wii (`WBFS / ISO`):** `1,459,978,240 byte` (`1.35 GiB`) Mini-DVD and `4,699,979,776 byte` Wii scrubber/padding verification + `32 KB` ECC alignment.
     - **Xbox / Xbox 360 (`XDVDFS`):** Exact layer-break sector lock (`1913760` for `XGD2`, `2133520` for `XGD3` with `.dvd` descriptor parser) + `Perform OPC Before Write`.
