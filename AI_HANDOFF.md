# AI Handoff & Change Log — Krouton

This file tracks proposed and completed changes across AI coding sessions (Claude Code & Gemini).

## Current Status & Active Context
- **App Icons:** Updated 4 variants (`ColorB`, `lightB`, `DarkB`, `TranparentB`) in `Resources/Assets.xcassets/AppIcon.appiconset` and `Resources/AppIcon*.icns`.
- **Dock Appearance Switching:** Updated `KroutonAppDelegate.swift` (`applyDynamicDockIcon` & `tintMonochromeIcon`) so `"default"` delegates to macOS `Assets.car` (`NSApplication.shared.applicationIconImage = nil`) and manual tinting uses `.sourceAtop`.
- **Next Up:** Fine-tune icon plate zoom/alpha layers in Icon Composer.

## Proposed Changes
- *(Claude: List upcoming or proposed multi-file changes here before executing)*

## Completed Changes
- **2026-11-17:** Initialized `CLAUDE.md` and `AI_HANDOFF.md`; updated `KroutonAppDelegate.swift` icon switching and generated `.icns` / `Assets.car` resources.

- **2026-11-17 01:40 [commit 3ac10cc]:** Configure macOS appearance icon switching, Assets.car, and AI handoff tracking  
  - `AI_HANDOFF.md` (A)
  - `CLAUDE.md` (A)
  - `Resources/AppIcon-Clear.icns` (A)
  - `Resources/AppIcon-Color.icns` (A)
  - `Resources/AppIcon-Dark.icns` (A)
  - `Resources/AppIcon-Light.icns` (A)
  - `Resources/AppIcon-Tinted.icns` (A)
  - `Resources/AppIcon-Transparent.icns` (A)
  - `Resources/AppIcon.icns` (A)
  - `Resources/Assets.xcassets/AppIcon.appiconset/AppIcon-Color.png` (A)
  - `Resources/Assets.xcassets/AppIcon.appiconset/AppIcon-Dark.png` (A)
  - `Resources/Assets.xcassets/AppIcon.appiconset/AppIcon-Light.png` (A)
  - `Resources/Assets.xcassets/AppIcon.appiconset/AppIcon-Transparent.png` (A)
  - `Resources/Assets.xcassets/AppIcon.appiconset/Contents.json` (A)
  - `Resources/Assets.xcassets/AppIcon.appiconset/icon_128x128_1x.png` (A)
  - `Resources/Assets.xcassets/AppIcon.appiconset/icon_128x128_2x.png` (A)
  - `Resources/Assets.xcassets/AppIcon.appiconset/icon_16x16_1x.png` (A)
  - `Resources/Assets.xcassets/AppIcon.appiconset/icon_16x16_2x.png` (A)
  - `Resources/Assets.xcassets/AppIcon.appiconset/icon_256x256_1x.png` (A)
  - `Resources/Assets.xcassets/AppIcon.appiconset/icon_256x256_2x.png` (A)
  - `Resources/Assets.xcassets/AppIcon.appiconset/icon_32x32_1x.png` (A)
  - `Resources/Assets.xcassets/AppIcon.appiconset/icon_32x32_2x.png` (A)
  - `Resources/Assets.xcassets/AppIcon.appiconset/icon_512x512_1x.png` (A)
  - `Resources/Assets.xcassets/AppIcon.appiconset/icon_512x512_2x.png` (A)
  - `Resources/Assets.xcassets/AppIcon.appiconset/icon_dark_128x128_1x.png` (A)
  - `Resources/Assets.xcassets/AppIcon.appiconset/icon_dark_128x128_2x.png` (A)
  - `Resources/Assets.xcassets/AppIcon.appiconset/icon_dark_16x16_1x.png` (A)
  - `Resources/Assets.xcassets/AppIcon.appiconset/icon_dark_16x16_2x.png` (A)
  - `Resources/Assets.xcassets/AppIcon.appiconset/icon_dark_256x256_1x.png` (A)
  - `Resources/Assets.xcassets/AppIcon.appiconset/icon_dark_256x256_2x.png` (A)
  - `Resources/Assets.xcassets/AppIcon.appiconset/icon_dark_32x32_1x.png` (A)
  - `Resources/Assets.xcassets/AppIcon.appiconset/icon_dark_32x32_2x.png` (A)
  - `Resources/Assets.xcassets/AppIcon.appiconset/icon_dark_512x512_1x.png` (A)
  - `Resources/Assets.xcassets/AppIcon.appiconset/icon_dark_512x512_2x.png` (A)
  - `Resources/Assets.xcassets/AppIcon.appiconset/icon_light_128x128_1x.png` (A)
  - `Resources/Assets.xcassets/AppIcon.appiconset/icon_light_128x128_2x.png` (A)
  - `Resources/Assets.xcassets/AppIcon.appiconset/icon_light_16x16_1x.png` (A)
  - `Resources/Assets.xcassets/AppIcon.appiconset/icon_light_16x16_2x.png` (A)
  - `Resources/Assets.xcassets/AppIcon.appiconset/icon_light_256x256_1x.png` (A)
  - `Resources/Assets.xcassets/AppIcon.appiconset/icon_light_256x256_2x.png` (A)
  - `Resources/Assets.xcassets/AppIcon.appiconset/icon_light_32x32_1x.png` (A)
  - `Resources/Assets.xcassets/AppIcon.appiconset/icon_light_32x32_2x.png` (A)
  - `Resources/Assets.xcassets/AppIcon.appiconset/icon_light_512x512_1x.png` (A)
  - `Resources/Assets.xcassets/AppIcon.appiconset/icon_light_512x512_2x.png` (A)
  - `Resources/Assets.xcassets/AppIcon.appiconset/icon_tinted_128x128_1x.png` (A)
  - `Resources/Assets.xcassets/AppIcon.appiconset/icon_tinted_128x128_2x.png` (A)
  - `Resources/Assets.xcassets/AppIcon.appiconset/icon_tinted_16x16_1x.png` (A)
  - `Resources/Assets.xcassets/AppIcon.appiconset/icon_tinted_16x16_2x.png` (A)
  - `Resources/Assets.xcassets/AppIcon.appiconset/icon_tinted_256x256_1x.png` (A)
  - `Resources/Assets.xcassets/AppIcon.appiconset/icon_tinted_256x256_2x.png` (A)
  - `Resources/Assets.xcassets/AppIcon.appiconset/icon_tinted_32x32_1x.png` (A)
  - `Resources/Assets.xcassets/AppIcon.appiconset/icon_tinted_32x32_2x.png` (A)
  - `Resources/Assets.xcassets/AppIcon.appiconset/icon_tinted_512x512_1x.png` (A)
  - `Resources/Assets.xcassets/AppIcon.appiconset/icon_tinted_512x512_2x.png` (A)
  - `Resources/Assets.xcassets/Contents.json` (A)
  - `Resources/PrivacyInfo.xcprivacy` (A)
  - `Sources/KroutonApp/Shell/App/KroutonAppDelegate.swift` (A)
  - `ai-sync.sh` (A)
