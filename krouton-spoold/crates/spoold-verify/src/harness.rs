//! Minimal harness with the same contract as Swift's `krouton-verify`: synchronous suites,
//! named checks, a summary line, and a non-zero exit code on any failure. No test framework,
//! no threads, no clocks: identical output on every machine and every run.

use std::fmt::Write as _;

#[derive(Debug, Default)]
pub struct Harness {
    pub passed: usize,
    pub failed: usize,
    current: String,
    /// Every check in order (`suite | pass/FAIL | message`). Two runs must produce identical logs.
    pub log: String,
    /// Suppresses console output (used for the determinism re-run).
    pub quiet: bool,
}

impl Harness {
    pub fn suite(&mut self, title: &str, body: impl FnOnce(&mut Self)) {
        self.current = title.to_owned();
        if !self.quiet {
            println!("\n▶ {title}");
        }
        body(self);
    }

    pub fn check(&mut self, condition: bool, message: &str) {
        let verdict = if condition { "pass" } else { "FAIL" };
        let _ = writeln!(self.log, "{} | {verdict} | {message}", self.current);
        if condition {
            self.passed += 1;
        } else {
            self.failed += 1;
            if !self.quiet {
                println!("  ✗ {message}");
            }
        }
    }
}
