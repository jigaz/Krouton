# Security

## Reporting a vulnerability

Email **jorgen@krouton.app** with a description, the version or commit, and steps to reproduce. Please don't open a public issue for a security problem. You can also use GitHub's private vulnerability reporting on [jigaz/Krouton](https://github.com/jigaz/Krouton/security/advisories/new).

You'll get a reply within a week. Fixes go into `main` first and into the next release; the advisory is published once a fix is available, crediting you unless you'd rather not be named. The contact is also published at [krouton.app/.well-known/security.txt](https://krouton.app/.well-known/security.txt).

## Scope

- The Krouton app and its command-line tool.
- Krouton Server (`krouton-server/`) and its installers.
- The KRSP protocol and the folder bundle format, including the shared vectors in `Vectors/`.
- The krouton.app and archive.krouton.app websites.

Out of scope: bugs in macOS, drive firmware or third-party tools Krouton runs (`hdiutil`, `xorriso`, `ffmpeg`, IMAPI2), unless Krouton uses them unsafely.

## How Krouton Server and the app protect each other

- **Local networks only.** The app checks the address a connection actually reached (`SpoolEndpointPolicy`, against DNS rebinding and `.local` tricks), and the server refuses public source addresses before TLS starts. VPN, Tailscale and other ranges are opt-in on the server (`allow_cgnat`, `allow_range`).
- **Mutual authentication without a certificate authority.** Each side has a P-256 TLS key and an Ed25519 identity. Pairing (`SpoolPairing`, commit-then-reveal over X25519, a six-digit code both people confirm) stores the other side's key pin and identity. Every later session requires the pinned TLS key on both sides plus Ed25519 signatures over the TLS 1.3 exporter (`SpoolSessionProof`), so a proof can't be replayed on another connection. The app keeps its keys in the login keychain.
- **Bounded input.** Frames are capped at 8 MiB and JSON at 256 KiB with bounded depth; identifiers are limited to `[A-Za-z0-9._-]`; every uploaded extent is checked against a Merkle manifest before it is used; each Mac sees only its own jobs.
- **Folder bundles can't escape.** The server accepts only plain files and folders in a bundle, and refuses absolute paths, `..`, links, device files, names Windows or a disc can't hold, case-insensitive duplicates and over-deep trees before extracting anything.
- **No shells.** `krouton-verify` Suite 18 bans shell invocations in the app; burn and mastering tools on the server receive arguments as separate parameters, never through a shell.

The design is described in full in [krouton-server/README.md](krouton-server/README.md).

## Supported versions

Krouton has no release yet. Until 1.0 ships, only `main` receives fixes.
