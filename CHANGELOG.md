# Changelog

## [1.0.1] - 2026-11-17
- Updated macOS app icon suite (`Color`, `Light`, `Dark`, `Transparent`/`Tinted`/`Clear`) in `Resources/Assets.xcassets` and compiled `Assets.car`.
- Refactored `KroutonAppDelegate.applyDynamicDockIcon` to delegate `"default"` icon appearance directly to macOS `Assets.car` (`NSApplication.shared.applicationIconImage = nil`) for native System Settings switching.
- Fixed monochrome icon tinting (`tintMonochromeIcon`) to use `.sourceAtop` compositing so alpha transparency is preserved on unplated icons.
- Added multi-agent handoff tracking (`CLAUDE.md`, `AI_HANDOFF.md`, `ai-sync.sh`, and `.git/hooks/post-commit`).

## [1.0.0] - 2026-11-16
- Added unified Disc Size header selector (650 MB CD-R to 128 GB BDXL) with live multi-disc spanning.
- Added adaptive macOS Dock icon suite (Default, Dark, Clear Glass, Tinted) with monochrome reliefs.
- Added IOKit sleep/App-Nap prevention during active burns, live Dock progress badge, and quit guard.
- Added Apple Shortcuts (AppIntents) and dual-mode headless CLI (krouton).
- Completed HIG 9pt typography floor, VoiceOver accessibility labels, and 10-language localization.
