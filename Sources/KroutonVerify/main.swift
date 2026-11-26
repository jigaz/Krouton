import Foundation

// MARK: - Krouton Verify Executable Entry Point

print("=== KROUTON ARCHITECTURE & CORE INVARIANT SUITE (krouton-verify) ===")
var harness = KroutonTestHarness()

harness.runVerifyArchitectureAndShellSuites()
harness.runVerifyImageAndSectorSuites()
harness.runVerifyAudioAndVideoSuites()
harness.runVerifyMasteringDomainModelsSuite()
harness.runVerifyHardwareAndBurnSuites()
harness.runVerifyBurnSetSchedulerSuite()
harness.runVerifyPortableCoreSuite()
harness.runVerifyDirectDriveSuite()
harness.runVerifyPublishedFormatsSuite()
harness.runVerifyLabelAndPersistenceSuites()
harness.runVerifyIntegrationReachabilitySuite()
harness.runVerifySpooldGoldenVectorSuite()

print("\n🎯 SUMMARY: \(harness.passed) behaviour assertions and \(harness.lintPassed) source-rule checks passed, \(harness.failed) failed.")
if harness.failed > 0 {
    exit(1)
}
