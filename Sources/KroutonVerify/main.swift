import SwiftUI
import Foundation
import OpticalCore
import AudioKit
import VideoKit
import ImageKit
import LabelKit
import RescueKit

print("=== KROUTON ARCHITECTURE & CORE INVARIANT SUITE (krouton-verify) ===")
var harness = KroutonTestHarness()


runVerifyArchitectureAndShellSuites(&harness)
runVerifyImageAndSectorSuites(&harness)
runVerifyAudioAndVideoSuites(&harness)
runVerifyMasteringDomainModelsSuite(&harness)
runVerifyHardwareBurnLabelAndPersistenceSuites(&harness)

print("\n🎯 SUMMARY: \(harness.passed) behaviour assertions and \(harness.lintPassed) source-rule checks passed, \(harness.failed) failed.")
if harness.failed > 0 {
    exit(1)
}
