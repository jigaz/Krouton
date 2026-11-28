## What this changes

<!-- One or two sentences. Link the issue or open question it addresses, if any. -->

## How I tested it

<!-- For anything that touches burning or reading: which drive, which discs, and what you checked on the result. -->

## Checks

- [ ] `swift test && swift run krouton-verify`
- [ ] `python3 Scripts/build-manual.py --check`
- [ ] `python3 Scripts/extract-strings.py --check`
- [ ] For `krouton-server/` or `Vectors/`: `cargo test --workspace`, `cargo clippy --workspace --all-targets` and `cargo fmt --all --check`
- [ ] Vectors regenerated and committed, if the wire format, bundle format or UDF writer output changed
- [ ] A line under **Unreleased** in `CHANGELOG.md`, if a user or server operator would notice
- [ ] The manual describes only what works today, if this changes what a user sees
- [ ] `PENDING_INTEGRATION.md` updated, if this adds or wires a public library type
