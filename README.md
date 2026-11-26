# Krouton

Krouton is a Mac app for making CDs, DVDs and Blu-ray discs: data discs that open on any computer, already-authored DVD and Blu-ray video, high-definition video on DVD (AVCHD), audio CDs with CD-Text and shaped crossfades, MP3 CDs for the car, copies of existing disc images, and printable disc labels. It can also burn on a drive attached to another computer, through **Krouton Server**, and it is meant to keep working long after the big disc-burning apps have gone.

- Website: [krouton.app](https://krouton.app)
- User manual: [krouton.app/manual](https://krouton.app/manual/), also built into the app (Help › Krouton User Manual, ⌘?)
- Optical disc archive (specs, drivers, longevity data): [archive.krouton.app](https://archive.krouton.app)

## Status

Krouton has no published release yet. Data discs, audio CDs, MP3 CDs, disc-image burns, sector-for-sector disc copies, Blu-ray video, ripping (tagged), video extraction, damaged-disc rescue, AVCHD, labels, the Depot, Krouton Server, the `krouton` command and the Shortcuts actions work. Several legacy formats (CD-Extra, CD+G, Video CD, Mac OS 9) and DVD/Blu-ray menu authoring are still being built, and Krouton refuses to burn those formats rather than write the wrong disc. The manual's [Getting started](https://krouton.app/manual/getting-started/) chapter keeps the current list.

## Requirements

- macOS 14 Sonoma or later, Apple silicon or Intel
- To build: Xcode 26 (Swift 6.2 toolchain). CI builds on `macos-26`.
- Optional: `ffmpeg` (Homebrew) for the video workflows
- Krouton Server: Rust 1.88 or later

## Build and run

```bash
swift build                 # all targets
swift run Krouton           # the app
swift run Krouton --help    # the command-line tool
```

Before sending a change, run the full gate (see [CONTRIBUTING.md](CONTRIBUTING.md)):

```bash
swift test && swift run krouton-verify
python3 Scripts/build-manual.py --check
```

## Packaging the app

```bash
./Scripts/bundle-app.sh                   # this Mac's architecture
ARCH=x86_64 VERSION=1.1.0 ./Scripts/bundle-app.sh
```

This writes `dist/macos-<arch>/Krouton.app` and `dist/Krouton-<version>-macOS-<arch>.zip`, signs with a Developer ID certificate when one is in the keychain (ad hoc otherwise), and prints the zip's SHA-256 for the Homebrew cask in `Packaging/Homebrew/Casks/`. The formula in `Packaging/Homebrew/Formula/` installs the command-line tool and its man page.

## Krouton Server

`krouton-server/` is a small Rust server for a Raspberry Pi, Linux box, Proxmox host, NAS, Windows 10/11 PC or older Mac with a burner attached. Pair it once from **Settings › Burners & Network**, then add it as a destination. It burns disc images, and builds discs from folders the app sends. See [krouton-server/README.md](krouton-server/README.md).

```bash
cd krouton-server && cargo test --workspace && cargo clippy --workspace --all-targets
```

## Repository map

| Path | What it is |
|---|---|
| `Sources/` | The Swift package: ten library modules, the app (`KroutonApp`) and the verification harness (`KroutonVerify`). See [ARCHITECTURE.md](ARCHITECTURE.md). |
| `Sources/KroutonApp/Resources/Manual/` | The user manual in Markdown. The app shows it; `Scripts/build-manual.py` renders it into `docs/manual/`. |
| `Tests/` | XCTest targets, one per module. |
| `krouton-server/` | Krouton Server (Rust): `krsp` protocol crate, `server-core`, the binary, installers. |
| `Vectors/` | Golden test vectors for the KRSP protocol and folder bundles, checked by both Swift and Rust. |
| `docs/` | The krouton.app website (GitHub Pages). |
| `Packaging/` | Homebrew cask and formula, man page. |
| `Scripts/` | `bundle-app.sh`, `build-server.sh`, `build-manual.py`. |
| `XcodeHost/` | The app's Info.plist and entitlements. |
| `KroutonPaletteKit/` | The locked colour palette the interface is drawn from. |
| `dev-notes/` | Working logs and the original specification (historical). |
| `PENDING_INTEGRATION.md` | Public types that have no caller yet, each with an owner and a date. |

## Documentation

- [ARCHITECTURE.md](ARCHITECTURE.md): modules, dependency rules and the verification suites
- [CONTRIBUTING.md](CONTRIBUTING.md): how to build, test and send a change
- [SECURITY.md](SECURITY.md): reporting vulnerabilities and the network threat model
- [CHANGELOG.md](CHANGELOG.md)
- [CLAUDE.md](CLAUDE.md): the same rules, written for AI coding agents

## License

MIT. See [LICENSE](LICENSE).
