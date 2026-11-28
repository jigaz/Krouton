> **Archived 2026-11-28. Not maintained.** An early version-by-version summary, written for
> 1.0.1 (2026-11-17). Parts are out of date: Krouton targets macOS 14 and later (not only
> macOS 26), `krouton-verify` has 40 suites, there has been no public release
> (1.0.0 and 1.0.1 were development milestones), and the product names in the headings
> (WaveBurner, UltraISO, PowerISO, K3b, ImgBurn, LiquidCD) name the tools a feature was modelled
> on, not anything Krouton includes. For history, read `CHANGELOG.md`.

# Krouton Project History & Architecture Log

## Current Version: `v1.0.1` (11-Target Swift 6 Architecture, Native macOS Appearance Icons & Verification Gate)
* **Target OS:** macOS 26 (Tahoe) / Apple Silicon (`arm64`)
* **Domain:** [krouton.app](https://krouton.app)

### Completed Milestones
* **Sprint 1 & 2 (`v0.1.0` .. `v0.2.0-alpha.6`):**
  - Real `DRBurn` / `DRErase` / `hdiutil` hardware engine, per-drive **Phase Scope** (inline + floating 5-layer window), textured **Disc Media Inspector** with media-accurate disc icons, and LiquidCD `[ Mac]` / `[⊞ PC]` per-file visibility masks.
* **Sprint 3 (`v0.3.0-alpha.1` — Current Commit):**
  1. **WaveBurner Red Book CD-DA & Car-Safe MP3 Studio (`sprint3_part1`):**
     - Per-track `INDEX 00` Pre-Gap stepper (`0.0s Gapless` to `6.0s`), `ISRC` (`ISO 3901`) code editor, `MCN / UPC` 13-digit barcode, and **Hidden Track One Audio (`HTOA`)** inside Track 01 `INDEX 00`.
     - **7-Bit ASCII `CD-TEXT` Sanitizer** (`CDTextSanitizer`) that transliterates smart quotes/dashes so hardware car stereos never display garbled subcode strings.
     - **5-Second Transition Audition Preview (`RedBookAuditionEngine`)** to hear how Track $N$ flows across the `INDEX 00` gap or **Jam Equal-Power Crossfade** into Track $N+1$ before firing the laser.
     - **Car-Safe MP3/FLAC CD Hygiene:** Zero-padded `001 - ` prefixes, `.DS_Store` / `._AppleDouble` stripping, and root `000_CAR_PLAYLIST.M3U` generation.
  2. **UltraISO / PowerISO Bootable Sector Inspector & `.BIN/.CUE` <-> `.ISO` Converter (`sprint3_part2`):**
     - Binary inspection of **Sector 17 (`0x8800`) El Torito Boot Record Volume Descriptors** (`x86_64 UEFI + BIOS`) and **Sector 0 Apple Partition Map (`ER`/`PM`)** (`PowerPC / 68k Apple Partition Map` for Mac OS 9 / OS X Tiger installers) plus GameCube/Wii magic words.
     - One-click **`.BIN/.CUE (2,352 B/sector) <-> .ISO (2,048 B/sector)`** sector transcoder right on staged image rows.
  3. **K3b & ImgBurn Pre-Flight Sanity & Overburn Guard Suite (`sprint3_part3`):**
     - **4 GiB Single-File ISO9660 Limit Check:** Warns if a file `>= 4 GiB` is staged without UDF enabled and provides a 1-click **Enable UDF 2.60 Bridge** fix.
     - **Joliet 64-Character UTF-16 & ISO9660 Level 2 31-Character Filename Check:** Lists offending filenames and provides a 1-click **Auto-Sanitize Filenames** button.
     - **ATIP Overburn Lead-Out Guard:** Compares staged LBA sectors (both Data `2,048 B` and Red Book Audio `75 fps` frames) against the physical disc's ATIP/ADIP capacity, turns the allocation bar red on overburn, and intercepts `Burn` with an explicit **ATIP Overburn Pre-Flight Confirmation Alert**.
     - **ImgBurn Visual Dual-Layer Break Picker (`DVD±R DL` & `BD-R DL`):** Enforces `Layer 0 >= Layer 1` and `16-sector (32 KB) ECC boundary` alignment.
  4. **v1.0.0 — 11-Target Swift 6 Modularization & Verification Gate (`2026-11-16`):**
     - Split monolithic engine into 11 strict Swift 6 targets (`OpticalCore`, `DriveKit`, `ImageKit`, `AudioKit`, `VideoKit`, `BurnKit`, `RescueKit`, `LabelKit`, `NetworkSpool`, `Persistence`, `KroutonApp`) plus the 22-suite `krouton-verify` executable and 9 unit test targets.
     - Added unified Disc Size header selector (`650 MB CD-R` to `128 GB BDXL`) with live multi-disc spanning, Apple Shortcuts (`AppIntents`), headless CLI (`krouton`), IOKit sleep/App-Nap burn guards, and 10-language localization.
  5. **v1.0.1 — Native `Assets.car` Appearance Switching & Multi-Agent Sync (`2026-11-17`):**
     - Generated alpha-masked 1x/2x icon sets (`Color`, `Light`, `Dark`, `Transparent`/`Clear`/`Tinted`), compiled `Assets.car`, and updated `KroutonAppDelegate.swift` so `"default"` delegates to macOS native icon switching while manual tinting uses `.sourceAtop`.
     - Added `CLAUDE.md`, `AI_HANDOFF.md`, `ai-sync.sh`, and a Git `post-commit` hook for seamless Claude Code / Gemini collaboration.
