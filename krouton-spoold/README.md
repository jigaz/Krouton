# krouton-spoold

Headless remote burn, extraction and rescue node for [Krouton](https://krouton.app) (`app.krouton`). It speaks KRSP v1, the binary spool protocol of Krouton's Swift `NetworkSpool` module.

**Status:** milestone 1 of 4. The protocol core and verification harness are done. Networking, storage and drive hardware are next (see `docs/ROADMAP.md`).

## Layout

| Crate | What | Dependencies |
|---|---|---|
| `spoold-proto` | Sans-I/O protocol core: KRSP framing, Merkle manifest, extent bitmap, 44-byte commit journal, extent pipeline (sender + receiver), fenced leases, endpoint policy, cutover policy, telemetry conflation, node ID / TXT / mTLS pin | **none** (optional `sha2` feature for accelerated hashing) |
| `spoold-crypto` | Pairing (commit-then-reveal 6-digit code) and per-session identity proofs | RustCrypto `sha2`, `hkdf`; dalek `x25519`, `ed25519` |
| `spoold-verify` | `krouton-spoold-verify`: the deterministic gate (no drive, network or disk) | `spoold-proto` |

## Everyday commands

```sh
cargo run --release -p spoold-verify      # the gate: must print "0 failed; second run identical: yes"
cargo test --workspace                    # unit tests + golden pairing vectors
cargo clippy --workspace --all-targets    # zero warnings is the bar
```

## Parity with the Swift client

`vectors/krsp-golden-v1.txt` holds byte-exact vectors for frames, the Merkle manifest, bitmap, journal, node ID, mTLS pin, pairing code and key, and session proofs. **An independent Python implementation** (`tools/gen_golden_vectors.py`, using `hashlib` + `cryptography`) generates the file. Rust (`spoold-verify` S1, `spoold-crypto/tests/golden.rs`) and Swift (`krouton-verify` Suite 29) both check it. Never edit the file by hand. Change the generator, regenerate, and both sides must pass.

## Rules

- `spoold-proto` stays pure: no sockets, files, threads or clocks. Time and bytes are passed in.
- Byte offsets are `u64`, never `usize` (armv7 has a 32-bit `usize`). Clippy denies truncating casts.
- `unsafe` is forbidden workspace-wide. The hardware and storage crates will allow it per module, with a `// SAFETY:` comment on every block.
- Every bug fix lands with a check in `spoold-verify` that fails without the fix.
