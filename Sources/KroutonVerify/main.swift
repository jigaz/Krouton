import SwiftUI
import Foundation
import OpticalCore
import AudioKit
import VideoKit
import ImageKit
import LabelKit
import RescueKit

struct KroutonTestHarness {
    var passed = 0
    var failed = 0

    mutating func check(_ condition: @autoclosure () -> Bool, _ message: String) {
        if condition() {
            passed += 1
        } else {
            failed += 1
            print("  ❌ FAIL: \(message)")
        }
    }

    mutating func runSuite(_ title: String, _ block: (inout KroutonTestHarness) throws -> Void) {
        let beforeFail = failed
        do {
            try block(&self)
            if failed == beforeFail {
                print("  ✅ PASS: \(title)")
            }
        } catch {
            failed += 1
            print("  ❌ ERROR in \(title): \(error)")
        }
    }
}

print("=== KROUTON ARCHITECTURE & CORE INVARIANT SUITE (krouton-verify) ===")
var harness = KroutonTestHarness()


runKroutonVerifySuites01To10(&harness)
runKroutonVerifySuites11To21(&harness)

print("\n🎯 SUMMARY: \(harness.passed) assertions passed, \(harness.failed) failed.")
if harness.failed > 0 {
    exit(1)
}
