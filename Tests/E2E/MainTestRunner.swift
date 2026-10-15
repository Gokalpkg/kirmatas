import Foundation

@main
public struct MainTestRunner {
    public static func main() {
        print("\n" + String(repeating: "*", count: 70))
        print("          KIRMATAS IOS — END-TO-END (E2E) TEST SUITE RUNNER")
        print("          Philosophy: Opaque-Box, Requirement-Driven Verification")
        print("          Architecture: 4-Tier Test Matrix (Tiers 1-4)")
        print(String(repeating: "*", count: 70))
        
        let reporter = TestReporter.shared
        
        // Execute Tier 1
        Tier1_FeatureCoverage.runTests(reporter: reporter)
        
        // Execute Tier 2
        Tier2_BoundaryCornerCases.runTests(reporter: reporter)
        
        // Execute Tier 3
        Tier3_CrossFeatureCombinations.runTests(reporter: reporter)
        
        // Execute Tier 4
        Tier4_RealWorldScenarios.runTests(reporter: reporter)
        
        // Summary & Exit Code
        let exitCode = reporter.printSummary()
        exit(Int32(exitCode))
    }
}
