import Foundation
import SwiftUI

// MARK: - Empirical Challenger Deep Stress Harness
var totalTests = 0
var passedTests = 0
var failedTests = 0

func recordPass(_ msg: String) {
    totalTests += 1
    passedTests += 1
    print("    ✓ [CHALLENGER-PASS] \(msg)")
}

func recordFail(_ msg: String) {
    totalTests += 1
    failedTests += 1
    print("    ✗ [CHALLENGER-FAIL] \(msg)")
}

func assertCondition(_ cond: Bool, _ msg: String) {
    if cond {
        recordPass(msg)
    } else {
        recordFail(msg)
    }
}

@main
struct ChallengerStressRunner {
    static func main() {
        print("======================================================================")
        print("  EMPIRICAL CHALLENGER: Deep Adversarial Stress & Invariance Suite")
        print("======================================================================")

        testExtreme100ThreadOverdraft()
        testMixedConcurrencySafety()
        testBoundaryGoldTransactions()
        testOrderingInvarianceFeedAndHarvest()
        testConcurrentFeedAndHarvestRace()
        testAquariumCodableBackwardsCompatibility()
        testExactHungerTimeBoundaries()

        print("\n======================================================================")
        print("  CHALLENGER SUMMARY: Total: \(totalTests), Passed: \(passedTests), Failed: \(failedTests)")
        print("======================================================================")

        if failedTests > 0 {
            print("==> CHALLENGER: Failures detected!")
            exit(1)
        } else {
            print("==> CHALLENGER: All adversarial checks strictly passed.")
            exit(0)
        }
    }

    // 1. Extreme 100-thread Overdraft Test
    static func testExtreme100ThreadOverdraft() {
        print("\n--- [Adversarial 1] 100 Concurrent Threads Overdraft Attack ---")
        let sm = SaveManager.shared
        _ = sm.spendGold(sm.gold)
        sm.addGold(100)

        let threadCount = 100
        let spendAmt = 15
        let group = DispatchGroup()
        let lock = NSLock()
        var successes = 0

        for _ in 0..<threadCount {
            group.enter()
            DispatchQueue.global().async {
                if sm.spendGold(spendAmt) {
                    lock.lock()
                    successes += 1
                    lock.unlock()
                }
                group.leave()
            }
        }
        group.wait()
        RunLoop.main.run(until: Date().addingTimeInterval(0.2))

        print("    -> 100 threads spending 15 from 100 balance. Successes: \(successes), Final balance: \(sm.gold)")
        assertCondition(successes == 6, "Exactly 6 spends succeeded out of 100 attempts (100 / 15 = 6)")
        assertCondition(sm.gold == 10, "Final balance is strictly 10 (100 - 6 * 15 = 10)")
        assertCondition(sm.gold >= 0, "No negative balance/overdraft occurred")
    }

    // 2. Mixed Concurrency Safety (200 threads)
    static func testMixedConcurrencySafety() {
        print("\n--- [Adversarial 2] 200 Mixed Concurrent Threads Stress ---")
        let sm = SaveManager.shared
        _ = sm.spendGold(sm.gold)
        sm.addGold(5000)

        let group = DispatchGroup()
        for _ in 0..<50 {
            group.enter()
            DispatchQueue.global().async {
                sm.addGold(10)
                group.leave()
            }
            group.enter()
            DispatchQueue.global().async {
                _ = sm.spendGold(10)
                group.leave()
            }
            group.enter()
            DispatchQueue.global().async {
                _ = sm.gold
                group.leave()
            }
            group.enter()
            DispatchQueue.global().async {
                _ = sm.canAfford(500)
                group.leave()
            }
        }
        group.wait()
        RunLoop.main.run(until: Date().addingTimeInterval(0.2))

        print("    -> Final gold after 200 mixed operations: \(sm.gold)")
        assertCondition(sm.gold == 5000, "200 mixed operations preserved exact gold balance of 5000")
    }

    // 3. Boundary Gold Transactions
    static func testBoundaryGoldTransactions() {
        print("\n--- [Adversarial 3] Boundary & Negative Value Injection ---")
        let sm = SaveManager.shared
        _ = sm.spendGold(sm.gold)
        sm.addGold(200)

        // Negative add
        sm.addGold(-50)
        assertCondition(sm.gold == 200, "Negative addGold(-50) ignored, balance stays 200")

        // Zero add
        sm.addGold(0)
        assertCondition(sm.gold == 200, "Zero addGold(0) ignored, balance stays 200")

        // Negative spend
        let spentNeg = sm.spendGold(-50)
        assertCondition(!spentNeg && sm.gold == 200, "Negative spendGold(-50) rejected, balance stays 200")

        // Zero spend
        let spentZero = sm.spendGold(0)
        assertCondition(spentZero && sm.gold == 200, "Zero spendGold(0) succeeds without changing balance")

        // Spend exact balance
        let spentAll = sm.spendGold(200)
        assertCondition(spentAll && sm.gold == 0, "Exact spendGold(200) succeeds and zeroes balance")

        // Spend from 0
        let spentOver = sm.spendGold(1)
        assertCondition(!spentOver && sm.gold == 0, "spendGold(1) from 0 balance rejected, balance stays 0")
    }

    // 4. Ordering Invariance of Feed and Harvest (SaveManager level)
    static func testOrderingInvarianceFeedAndHarvest() {
        print("\n--- [Adversarial 4] Feed vs Harvest Ordering Invariance (SaveManager) ---")
        let sm = SaveManager.shared
        _ = sm.spendGold(sm.gold)

        let t0 = Date().addingTimeInterval(-5.0 * 3600.0)

        // Scenario 1: Collect first, then Feed
        sm.aquariumState = AquariumState(
            unlockedFishIds: ["guppy", "tetra"],
            floraCounts: ["moss": 2],
            sandLevel: 1,
            lastFedTime: t0,
            lastCollectedTime: t0,
            accumulatedBank: 0.0,
            hasClaimedComebackBonus: false
        )
        let goldBefore1 = sm.gold
        let collected1 = sm.collectAquariumGold()
        let feedRes1 = sm.feedFish()
        let goldAfter1 = sm.gold
        let totalGain1 = goldAfter1 - goldBefore1

        print("    -> Sequence 1 (Collect then Feed): Collected: \(collected1), Feed bonus: \(feedRes1.comebackBonus), Total gain: \(totalGain1)")

        // Scenario 2: Feed first, then Collect
        _ = sm.spendGold(sm.gold)
        sm.aquariumState = AquariumState(
            unlockedFishIds: ["guppy", "tetra"],
            floraCounts: ["moss": 2],
            sandLevel: 1,
            lastFedTime: t0,
            lastCollectedTime: t0,
            accumulatedBank: 0.0,
            hasClaimedComebackBonus: false
        )
        let goldBefore2 = sm.gold
        let feedRes2 = sm.feedFish()
        let collected2 = sm.collectAquariumGold()
        let goldAfter2 = sm.gold
        let totalGain2 = goldAfter2 - goldBefore2

        print("    -> Sequence 2 (Feed then Collect): Feed bonus: \(feedRes2.comebackBonus), Collected: \(collected2), Total gain: \(totalGain2)")

        assertCondition(feedRes1.hungerCleared && feedRes2.hungerCleared, "Both sequences clear hunger")
        assertCondition(totalGain1 == totalGain2, "SaveManager total gold gained is strictly invariant to call order (\(totalGain1) == \(totalGain2))")
        assertCondition(totalGain1 > 0, "Positive earnings achieved in both sequences")
    }

    // 5. Concurrent Feed and Harvest Race Condition
    static func testConcurrentFeedAndHarvestRace() {
        print("\n--- [Adversarial 5] Concurrent feedFish() and collectAquariumGold() Race ---")
        let sm = SaveManager.shared
        _ = sm.spendGold(sm.gold)

        // Setup hungry fish state in SaveManager
        let t0 = Date().addingTimeInterval(-5.0 * 3600.0)
        sm.aquariumState = AquariumState(
            unlockedFishIds: ["guppy", "tetra"],
            floraCounts: [:],
            sandLevel: 1,
            lastFedTime: t0,
            lastCollectedTime: t0,
            accumulatedBank: 0.0,
            hasClaimedComebackBonus: false
        )

        let group = DispatchGroup()
        let lock = NSLock()
        var totalComebackBonuses = 0

        for _ in 0..<20 {
            group.enter()
            DispatchQueue.global().async {
                let res = sm.feedFish()
                if res.comebackBonus > 0 {
                    lock.lock()
                    totalComebackBonuses += res.comebackBonus
                    lock.unlock()
                }
                group.leave()
            }
            group.enter()
            DispatchQueue.global().async {
                _ = sm.collectAquariumGold()
                group.leave()
            }
        }
        group.wait()
        RunLoop.main.run(until: Date().addingTimeInterval(0.2))

        print("    -> Total comeback bonuses awarded across 40 concurrent feed/collect calls: \(totalComebackBonuses)")
        // In SaveManager, comeback bonus is 20 either via feedFish() or collectAquariumGold()
        // It must NOT be awarded more than once for that hunger event
        assertCondition(totalComebackBonuses <= 20, "Comeback bonus awarded at most once (got \(totalComebackBonuses))")
    }

    // 6. AquariumState Codable Backwards Compatibility
    static func testAquariumCodableBackwardsCompatibility() {
        print("\n--- [Adversarial 6] AquariumState Backward Compatibility (Missing Key) ---")
        // JSON without hasClaimedComebackBonus key
        let legacyJson = """
        {
            "unlockedFishIds": ["guppy", "tetra"],
            "floraCounts": {"moss": 1},
            "sandLevel": 2,
            "lastFedTime": 700000000.0,
            "lastCollectedTime": 700000000.0,
            "accumulatedBank": 15.5
        }
        """.data(using: .utf8)!

        do {
            let decoded = try JSONDecoder().decode(AquariumState.self, from: legacyJson)
            assertCondition(decoded.hasClaimedComebackBonus == false, "Decoded legacy JSON without key defaults hasClaimedComebackBonus to false")
            assertCondition(decoded.unlockedFishIds == ["guppy", "tetra"], "Decoded fish IDs match")
            assertCondition(decoded.sandLevel == 2, "Decoded sand level matches")

            // Re-encode and verify key exists
            let reEncoded = try JSONEncoder().encode(decoded)
            let jsonString = String(data: reEncoded, encoding: .utf8)!
            assertCondition(jsonString.contains("hasClaimedComebackBonus"), "Re-encoded JSON contains hasClaimedComebackBonus key")
        } catch {
            recordFail("Failed to decode legacy JSON: \(error)")
        }
    }

    // 7. Exact Hunger Time Boundaries
    static func testExactHungerTimeBoundaries() {
        print("\n--- [Adversarial 7] Sub-second Hunger Threshold Boundaries ---")
        let t0 = Date()
        var aq = AquariumState(
            unlockedFishIds: ["guppy"],
            floraCounts: [:],
            sandLevel: 1,
            lastFedTime: t0,
            lastCollectedTime: t0,
            accumulatedBank: 0.0
        )

        // 3h 59m 59s
        let tJustBefore = t0.addingTimeInterval(4.0 * 3600.0 - 1.0)
        assertCondition(!aq.isHungry(at: tJustBefore), "At 3h 59m 59s fish are NOT hungry")
        let gainsBefore = aq.calculateOfflineGains(now: tJustBefore)
        assertCondition(gainsBefore.comebackBonus == 0, "No comeback bonus at 3h 59m 59s")

        // Exactly 4h 00m 00s
        let tExact4h = t0.addingTimeInterval(4.0 * 3600.0)
        assertCondition(aq.isHungry(at: tExact4h), "At exactly 4h 00m 00s fish ARE hungry")
        let gainsExact = aq.calculateOfflineGains(now: tExact4h)
        assertCondition(gainsExact.comebackBonus == 20, "Comeback bonus +20 granted at exactly 4h 00m 00s")

        // 8 hours cap
        let t8h = t0.addingTimeInterval(8.0 * 3600.0)
        let gains8h = aq.calculateOfflineGains(now: t8h)
        assertCondition(abs(gains8h.effectiveHours - 4.0) < 0.001, "At 8h without feeding, generation remains capped at 4.0h")
    }
}
