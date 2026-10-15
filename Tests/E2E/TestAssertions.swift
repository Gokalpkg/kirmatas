import Foundation

public final class TestReporter {
    public static let shared = TestReporter()
    
    public private(set) var totalAssertions: Int = 0
    public private(set) var passedAssertions: Int = 0
    public private(set) var failedAssertions: Int = 0
    public private(set) var currentTierName: String = ""
    
    private var failures: [String] = []
    private var tierStats: [(name: String, passed: Int, failed: Int)] = []
    private var currentTierPassed: Int = 0
    private var currentTierFailed: Int = 0
    
    private init() {}
    
    public func startTier(_ name: String) {
        currentTierName = name
        currentTierPassed = 0
        currentTierFailed = 0
        print("\n" + String(repeating: "=", count: 70))
        print("  RUNNING: \(name)")
        print(String(repeating: "=", count: 70))
    }
    
    public func endTier() {
        tierStats.append((name: currentTierName, passed: currentTierPassed, failed: currentTierFailed))
        let status = currentTierFailed == 0 ? "PASSED" : "FAILED"
        let symbol = currentTierFailed == 0 ? "✓" : "✗"
        print("----------------------------------------------------------------------")
        print("  [\(status)] \(currentTierName): \(currentTierPassed) passed, \(currentTierFailed) failed \(symbol)")
        print("----------------------------------------------------------------------\n")
    }
    
    public func recordPass(_ message: String) {
        totalAssertions += 1
        passedAssertions += 1
        currentTierPassed += 1
        print("    ✓ \(message)")
    }
    
    public func recordFail(_ message: String, file: String, line: Int) {
        totalAssertions += 1
        failedAssertions += 1
        currentTierFailed += 1
        let failMsg = "[\(currentTierName)] \(file.components(separatedBy: "/").last ?? file):\(line) - \(message)"
        failures.append(failMsg)
        print("    ✗ FAIL: \(message)")
    }
    
    public func assertEqual<T: Equatable>(_ actual: T, _ expected: T, _ message: String, file: String = #file, line: Int = #line) {
        if actual == expected {
            recordPass(message)
        } else {
            recordFail("\(message) | Expected: [\(expected)], got: [\(actual)]", file: file, line: line)
        }
    }
    
    public func assertTrue(_ condition: Bool, _ message: String, file: String = #file, line: Int = #line) {
        if condition {
            recordPass(message)
        } else {
            recordFail("\(message) | Expected true, got false", file: file, line: line)
        }
    }
    
    public func assertFalse(_ condition: Bool, _ message: String, file: String = #file, line: Int = #line) {
        if !condition {
            recordPass(message)
        } else {
            recordFail("\(message) | Expected false, got true", file: file, line: line)
        }
    }
    
    public func assertApprox(_ actual: Double, _ expected: Double, tolerance: Double = 0.0001, _ message: String, file: String = #file, line: Int = #line) {
        if abs(actual - expected) <= tolerance {
            recordPass(message)
        } else {
            recordFail("\(message) | Expected approx [\(expected)] ± \(tolerance), got [\(actual)]", file: file, line: line)
        }
    }
    
    public func assertNotNil<T>(_ value: T?, _ message: String, file: String = #file, line: Int = #line) {
        if value != nil {
            recordPass(message)
        } else {
            recordFail("\(message) | Expected non-nil value", file: file, line: line)
        }
    }
    
    public func assertNil<T>(_ value: T?, _ message: String, file: String = #file, line: Int = #line) {
        if value == nil {
            recordPass(message)
        } else {
            recordFail("\(message) | Expected nil, got non-nil", file: file, line: line)
        }
    }
    
    public func assertGreaterThanOrEqual<T: Comparable>(_ actual: T, _ threshold: T, _ message: String, file: String = #file, line: Int = #line) {
        if actual >= threshold {
            recordPass(message)
        } else {
            recordFail("\(message) | Expected >= [\(threshold)], got [\(actual)]", file: file, line: line)
        }
    }
    
    public func assertLessThanOrEqual<T: Comparable>(_ actual: T, _ threshold: T, _ message: String, file: String = #file, line: Int = #line) {
        if actual <= threshold {
            recordPass(message)
        } else {
            recordFail("\(message) | Expected <= [\(threshold)], got [\(actual)]", file: file, line: line)
        }
    }
    
    public func printSummary() -> Int {
        print("\n" + String(repeating: "#", count: 70))
        print("                      E2E TEST SUITE EXECUTION SUMMARY")
        print(String(repeating: "#", count: 70))
        for stat in tierStats {
            let symbol = stat.failed == 0 ? "✓" : "✗"
            let status = stat.failed == 0 ? "PASSED" : "FAILED"
            let paddedName = stat.name.padding(toLength: 48, withPad: " ", startingAt: 0)
            print("  \(paddedName) [\(status)]  \(stat.passed) passed, \(stat.failed) failed  \(symbol)")
        }
        print(String(repeating: "-", count: 70))
        print("  TOTAL ASSERTIONS: \(totalAssertions)  |  PASSED: \(passedAssertions)  |  FAILED: \(failedAssertions)")
        
        if failedAssertions > 0 {
            print("\n  FAILURES:")
            for f in failures {
                print("    - \(f)")
            }
            print("\n[E2E SUITE FAILED] Exit code: 1\n")
            return 1
        } else {
            print("\n[E2E SUITE PASSED] All 4 tiers verified with 100% pass rate. Exit code: 0\n")
            return 0
        }
    }
}
