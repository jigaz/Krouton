# Contributing to Krouton

## Verification Gate
Every pull request must pass both commands with zero warnings and zero failures:

```bash
swift test && swift run krouton-verify
```

## Code Hygiene Rules
1. **Pure-SwiftUI in `Features/`:** Never import `AppKit` or reference `NSColor`, `NSImage`, or `NSView` inside `Sources/KroutonApp/Features/`.
2. **File & Function Ceilings:**
   - View files: max **400 LOC**
   - Non-view files: max **500 LOC**
   - Functions / computed bodies: max **200 LOC**
   - Files over 120 LOC must include `// MARK: -` section headers.
3. **Integration Reachability Ratchet (Suite 28):**
   - Nothing merges unwired. New `public` library types must have a production caller or a dated entry in `PENDING_INTEGRATION.md`.
   - When wiring a type from `PENDING_INTEGRATION.md`, delete its entry in the same commit.
