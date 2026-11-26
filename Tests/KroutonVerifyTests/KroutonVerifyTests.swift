#if canImport(XCTest)
import XCTest
#else
import Foundation
open class XCTestCase { public init() {} }
public func XCTAssertEqual<T: Equatable>(_ a: T, _ b: T, _ msg: String = "", file: StaticString = #file, line: UInt = #line) { precondition(a == b, msg, file: file, line: line) }
public func XCTAssertTrue(_ cond: Bool, _ msg: String = "", file: StaticString = #file, line: UInt = #line) { precondition(cond, msg, file: file, line: line) }
public func XCTAssertFalse(_ cond: Bool, _ msg: String = "", file: StaticString = #file, line: UInt = #line) { precondition(!cond, msg, file: file, line: line) }
public func XCTAssertGreaterThan<T: Comparable>(_ a: T, _ b: T, _ msg: String = "", file: StaticString = #file, line: UInt = #line) { precondition(a > b, msg, file: file, line: line) }
public func XCTFail(_ msg: String = "", file: StaticString = #file, line: UInt = #line) { preconditionFailure(msg, file: file, line: line) }
#endif
@testable import KroutonVerify

/// Runs the `krouton-verify` suites under `swift test`, so one command covers everything.
/// Each failed check in a suite becomes its own XCTest failure with the suite's message.
final class KroutonVerifyTests: XCTestCase {
    private func runSuites(
        _ suites: (inout KroutonTestHarness) -> Void,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        var harness = KroutonTestHarness()
        harness.printsProgress = false
        suites(&harness)
        for failure in harness.failures {
            XCTFail(failure, file: file, line: line)
        }
        XCTAssertGreaterThan(harness.passed + harness.lintPassed, 0, "The suites ran no checks", file: file, line: line)
    }

    func testArchitectureAndShellSuites() { runSuites { $0.runVerifyArchitectureAndShellSuites() } }
    func testImageAndSectorSuites() { runSuites { $0.runVerifyImageAndSectorSuites() } }
    func testAudioAndVideoSuites() { runSuites { $0.runVerifyAudioAndVideoSuites() } }
    func testMasteringDomainModelsSuite() { runSuites { $0.runVerifyMasteringDomainModelsSuite() } }
    func testHardwareAndBurnSuites() { runSuites { $0.runVerifyHardwareAndBurnSuites() } }
    func testBurnSetSchedulerSuite() { runSuites { $0.runVerifyBurnSetSchedulerSuite() } }
    func testPortableCoreSuite() { runSuites { $0.runVerifyPortableCoreSuite() } }
    func testDirectDriveSuite() { runSuites { $0.runVerifyDirectDriveSuite() } }
    func testPublishedFormatsSuite() { runSuites { $0.runVerifyPublishedFormatsSuite() } }
    func testRescueSuite() { runSuites { $0.runVerifyRescueSuite() } }
    func testLabelAndPersistenceSuites() { runSuites { $0.runVerifyLabelAndPersistenceSuites() } }

    // MARK: - The function-length scanner itself

    func testScannerMeasuresBodiesAndIgnoresBracesInStringsAndComments() {
        let source = #"""
        protocol P {
            func requirement(_ x: Int) -> Int
        }
        struct S {
            init(value: Int) {
                self.value = value
            }
            // func commentedOut() {
            func described(
                _ a: Int,
                b: Int
            ) -> String {
                let text = "} not a brace {"
                /* { */
                if a > b {
                    return text
                }
                return "\(a) }"
            }
            var computed: Int { 1 }
        }
        """#
        let found = VerifyFunctionLengthScanner.functions(in: source)
        XCTAssertEqual(found.map(\.name), ["init", "func described"])
        XCTAssertEqual(found.map(\.lineCount), [3, 11])
        XCTAssertEqual(found.map(\.startLine), [5, 9])
    }

    func testScannerFlagsAFunctionOverTheCeiling() {
        let body = (0..<205).map { "    let v\($0) = \($0)" }.joined(separator: "\n")
        let source = "func long() {\n\(body)\n}\nfunc short() {\n}\n"
        let over = VerifyFunctionLengthScanner.functions(in: source).filter { $0.lineCount > 200 }
        XCTAssertEqual(over.map(\.name), ["func long"])
        XCTAssertEqual(over.first?.lineCount, 207)
    }
}
