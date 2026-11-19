//! `krouton-spoold-verify`: the deterministic gate for the Rust daemon, mirroring Swift's
//! `krouton-verify`. Run `cargo run -p spoold-verify` before every commit; CI runs it on every
//! target in the matrix (it needs no drive, network or disk).
#![allow(clippy::unwrap_used, clippy::expect_used, clippy::indexing_slicing, clippy::cast_possible_truncation)]

mod faulty_link;
mod harness;
mod hygiene_and_hal_suites;
mod suites;
mod suites_policy;

use std::time::Instant;

fn main() {
    println!("=== KROUTON-SPOOLD VERIFY (deterministic, no hardware, no network) ===");
    let started = Instant::now();
    let mut first = harness::Harness::default();
    suites::run_all(&mut first);

    // Determinism gate: a second full run must produce a byte-identical check log.
    let mut second = harness::Harness::default();
    second.quiet = true;
    suites::run_all(&mut second);
    let deterministic = first.log == second.log;

    let elapsed = started.elapsed();
    println!(
        "\n🎯 SUMMARY: {} checks passed, {} failed; second run identical: {}; both runs took {} ms.",
        first.passed,
        first.failed,
        if deterministic { "yes" } else { "NO" },
        elapsed.as_millis()
    );
    if first.failed > 0 || !deterministic {
        std::process::exit(1);
    }
}
