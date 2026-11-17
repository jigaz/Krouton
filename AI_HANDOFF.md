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
