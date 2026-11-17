# Krouton — macOS Optical Media Mastering Studio & CLI

Krouton is a native Swift 6 / SwiftUI optical media authoring, multi-disc spanning, archival rescue, and disc-label studio for macOS 14 Sonoma and later, featuring a built-in headless CLI (`krouton`), Apple Shortcuts (`AppIntents`) integration, and remote network spooling (`NetworkSpool` / Port `7420`).

- **Author & Maintainer:** Jorgen Thompquist
- **Apple Developer Team ID:** `D3BJL3F92P`
- **Bundle Identifier:** `com.krouton.opticalstudio`

## Key Capabilities
- **Data & Hybrid Image Mastering (`ImageKit`, `BurnKit`):** ISO-9660 / Joliet / UDF 2.60 / HFS+ hybrid filesystems, El Torito (UEFI + BIOS) & Apple Partition Map bootable sector inspection, `.BIN/.CUE` <-> `.ISO` transcoding, and live multi-disc spanning (`650 MB CD-R` to `128 GB BDXL`).
- **Red Book CD-DA & Car-Safe Audio Studio (`AudioKit`):** Per-track `INDEX 00` pre-gaps, Hidden Track One Audio (HTOA), 18-byte `CD-TEXT` CRC-16 encoding with 7-bit ASCII sanitization, ISRC/MCN barcodes, equal-power crossfade DSP, and 5-second transition auditioning.
- **Video & Optical Shrink (`VideoKit`):** Optical bitrate budgeting, DVD-9 to DVD-5 requantization, IFO relinking, Dual-Layer ECC break alignment, and AVCHD muxing.
- **Archival Rescue & Grading (`RescueKit`):** Multi-pass bad-sector optical recovery and archival media quality grading.
- **Polar 300-DPI Disc Label Studio (`LabelKit`):** 120mm / 80mm polar geometry engine and 1:1 vector PDF print sheet generation.
- **Zero-Coaster Network Spooling (`NetworkSpool`):** Spool-and-burn remote mastering over Port `7420` (`_krumb._tcp.local.`).
- **Adaptive macOS Experience (`KroutonApp`):** Native `Assets.car` + dynamic `.icns` Dock icon switching (Default, Dark, Tinted, Clear), 10-preset Display-P3 dual-polarity color harmony engine, IOKit burn sleep guards, and 10-language localization.

## Installation

    brew install --cask Packaging/Homebrew/Casks/krouton.rb
    brew install --formula Packaging/Homebrew/Formula/krouton.rb

## Build & Verification

    swift build -c release
    swift test
    swift run krouton-verify

## Headless CLI Usage

    krouton --version
    krouton drives --json
    krouton formats
    krouton inspect ~/Downloads/archive.iso --sha256
    krouton span --medium dvd5 ~/Documents/ProjectArchive/*
    krouton iso --volume ARCHIVE_2026 --out ~/Desktop/Archive.iso ~/Documents/Payload
