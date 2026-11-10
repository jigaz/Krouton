# Krouton Project History & Architecture Log

## Current Version: `v0.3.0-alpha.1` (Sprint 3 Complete — WaveBurner Audio, Bootable El Torito Inspector & Pre-Flight Sanity Suite)
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
