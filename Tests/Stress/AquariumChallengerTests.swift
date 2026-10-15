import Foundation

// MARK: - Empirical Challenger Harness for AquariumState & SaveManager
final class AquariumChallengerHarness {
    private static var totalAssertions = 0
    private static var passedAssertions = 0
    private static var failedAssertions = 0
    private static var failures: [String] = []

    static func assertTest(
        _ condition: Bool,
        _ message: String,
        file: String = #file,
        line: Int = #line
    ) {
        totalAssertions += 1
        if condition {
            passedAssertions += 1
            print("    ✓ [PASS] \(message)")
        } else {
            failedAssertions += 1
            let failMsg = "✗ [FAIL] \(message) (at \(URL(fileURLWithPath: file).lastPathComponent):\(line))"
            print("    \(failMsg)")
            failures.append(failMsg)
        }
    }

    static func summary() -> Int {
        print("\n" + String(repeating: "=", count: 70))
        print("  CHALLENGER HARNESS EMPIRICAL VERIFICATION SUMMARY")
        print(String(repeating: "=", count: 70))
        print("  Total Assertions: \(totalAssertions)")
        print("  Passed:           \(passedAssertions)")
        print("  Failed:           \(failedAssertions)")
        if !failures.isEmpty {
            print("\n  FAILURES:")
            for f in failures {
                print("    - \(f)")
            }
        }
        print(String(repeating: "=", count: 70) + "\n")
        return failedAssertions == 0 ? 0 : 1
    }
}

// MARK: - Suite 1: Mathematical Formula & Boundary Edge Cases
func runMathematicalEdgeCaseSuite() {
    print("\n======================================================================")
    print("  SUITE 1: AquariumState Idle Formulas & Extreme Boundary Conditions")
    print("======================================================================")

    let t0 = Date()
    var state = AquariumState(
        unlockedFishIds: ["guppy", "tetra"],
        floraCounts: ["moss": 2, "kelp": 1, "anubias": 1],
        sandLevel: 1,
        lastFedTime: t0,
        lastCollectedTime: t0,
        accumulatedBank: 0.0,
        hasClaimedComebackBonus: false
    )
    let gph = state.totalGPH()
    print("  Baseline Aquarium GPH: \(gph)")

    // 1.1: Exact 0.0s elapsed
    print("  [1.1] Testing 0.0s elapsed...")
    let g0 = state.calculateOfflineGains(now: t0)
    AquariumChallengerHarness.assertTest(g0.effectiveHours == 0.0, "1.1a: 0.0s elapsed yields exactly 0.0 effective hours")
    AquariumChallengerHarness.assertTest(g0.gold == 0, "1.1b: 0.0s elapsed yields 0 gold")
    AquariumChallengerHarness.assertTest(g0.comebackBonus == 0, "1.1c: 0.0s elapsed yields 0 comeback bonus")
    AquariumChallengerHarness.assertTest(!state.isHungry(at: t0), "1.1d: Fish are not hungry at 0s")
    AquariumChallengerHarness.assertTest(state.hungerProgress(at: t0) == 0.0, "1.1e: Hunger progress is 0.0 at 0s")
    AquariumChallengerHarness.assertTest(abs(state.remainingFullSeconds(at: t0) - 14400.0) < 0.01, "1.1f: Exactly 14400s remaining full")

    // 1.2: Boundary before hunger: 3h 59m 0s (14340s) and 3h 59m 59.9s (14399.9s)
    print("  [1.2] Testing 3h 59m and 3h 59m 59.9s (just before 4h cutoff)...")
    let t3h59m = t0.addingTimeInterval(3.0 * 3600.0 + 59.0 * 60.0)
    let g3h59m = state.calculateOfflineGains(now: t3h59m)
    let expectedH3h59m = (3.0 * 3600.0 + 59.0 * 60.0) / 3600.0
    AquariumChallengerHarness.assertTest(abs(g3h59m.effectiveHours - expectedH3h59m) < 0.0001, "1.2a: 3h59m effective hours ~3.9833h")
    AquariumChallengerHarness.assertTest(g3h59m.comebackBonus == 0, "1.2b: 3h59m awards 0 comeback bonus")
    AquariumChallengerHarness.assertTest(g3h59m.gold == Int(floor(expectedH3h59m * gph)), "1.2c: 3h59m gold matches floor(effectiveHours * gph)")
    AquariumChallengerHarness.assertTest(!state.isHungry(at: t3h59m), "1.2d: Fish not hungry at 3h59m")

    let t3h59m59 = t0.addingTimeInterval(14399.9)
    let g3h59m59 = state.calculateOfflineGains(now: t3h59m59)
    AquariumChallengerHarness.assertTest(g3h59m59.comebackBonus == 0, "1.2e: 3h59m59.9s awards 0 comeback bonus")
    AquariumChallengerHarness.assertTest(!state.isHungry(at: t3h59m59), "1.2f: Fish not hungry at 3h59m59.9s")
    AquariumChallengerHarness.assertTest(state.remainingFullSeconds(at: t3h59m59) > 0.0, "1.2g: Remaining full seconds > 0 at 3h59m59.9s")

    // 1.3: Exact 4h 0m 0s (14400.0s)
    print("  [1.3] Testing exact 4h boundary...")
    let t4h = t0.addingTimeInterval(4.0 * 3600.0)
    let g4h = state.calculateOfflineGains(now: t4h)
    AquariumChallengerHarness.assertTest(abs(g4h.effectiveHours - 4.0) < 0.0001, "1.3a: Exactly 4h yields 4.0 effective hours")
    AquariumChallengerHarness.assertTest(g4h.comebackBonus == 20, "1.3b: Exactly 4h awards +20 comeback bonus")
    AquariumChallengerHarness.assertTest(g4h.gold == Int(floor(4.0 * gph)), "1.3c: 4h gold equals floor(4.0 * gph)")
    AquariumChallengerHarness.assertTest(state.isHungry(at: t4h), "1.3d: Fish are hungry at exactly 4h")
    AquariumChallengerHarness.assertTest(state.hungerProgress(at: t4h) == 1.0, "1.3e: Hunger progress is 1.0 at 4h")
    AquariumChallengerHarness.assertTest(state.remainingFullSeconds(at: t4h) == 0.0, "1.3f: Remaining full seconds is 0.0 at 4h")

    // 1.4: 4h 0m 1s (14401s)
    print("  [1.4] Testing 4h 0m 1s...")
    let t4h1s = t0.addingTimeInterval(4.0 * 3600.0 + 1.0)
    let g4h1s = state.calculateOfflineGains(now: t4h1s)
    AquariumChallengerHarness.assertTest(abs(g4h1s.effectiveHours - 4.0) < 0.0001, "1.4a: 4h1s effective hours strictly clamped to 4.0h")
    AquariumChallengerHarness.assertTest(g4h1s.comebackBonus == 20, "1.4b: 4h1s awards +20 comeback bonus")
    AquariumChallengerHarness.assertTest(g4h1s.gold == Int(floor(4.0 * gph)), "1.4c: 4h1s gold strictly capped at 4.0h production")

    // 1.5: 8h 0m 0s (28800s) unfed
    print("  [1.5] Testing 8h unfed...")
    let t8h = t0.addingTimeInterval(8.0 * 3600.0)
    let g8h = state.calculateOfflineGains(now: t8h)
    AquariumChallengerHarness.assertTest(abs(g8h.effectiveHours - 4.0) < 0.0001, "1.5a: 8h unfed stays clamped at 4.0 effective hours")
    AquariumChallengerHarness.assertTest(g8h.comebackBonus == 20, "1.5b: 8h unfed awards +20 comeback bonus")
    AquariumChallengerHarness.assertTest(g8h.gold == Int(floor(4.0 * gph)), "1.5c: 8h unfed gold matches 4.0h production")

    // 1.6: 30 days (2,592,000s) unfed
    print("  [1.6] Testing 30 days unfed...")
    let t30d = t0.addingTimeInterval(30.0 * 24.0 * 3600.0)
    let g30d = state.calculateOfflineGains(now: t30d)
    AquariumChallengerHarness.assertTest(abs(g30d.effectiveHours - 4.0) < 0.0001, "1.6a: 30 days unfed clamped at 4.0 effective hours")
    AquariumChallengerHarness.assertTest(g30d.comebackBonus == 20, "1.6b: 30 days unfed awards +20 comeback bonus")
    AquariumChallengerHarness.assertTest(g30d.gold == Int(floor(4.0 * gph)), "1.6c: 30 days unfed gold matches 4.0h production without runaway")

    // 1.7: 10 years (315,360,000s) extreme future
    print("  [1.7] Testing 10 years extreme future...")
    let t10y = t0.addingTimeInterval(10.0 * 365.0 * 24.0 * 3600.0)
    let g10y = state.calculateOfflineGains(now: t10y)
    AquariumChallengerHarness.assertTest(abs(g10y.effectiveHours - 4.0) < 0.0001, "1.7a: 10 years unfed clamped to 4.0 effective hours")
    AquariumChallengerHarness.assertTest(g10y.gold == Int(floor(4.0 * gph)), "1.7b: 10 years unfed gold is stable")

    // 1.8: Negative time jump (clock set backwards)
    print("  [1.8] Testing backwards time jumps...")
    let tPast1m = t0.addingTimeInterval(-60.0)
    let gPast1m = state.calculateOfflineGains(now: tPast1m)
    AquariumChallengerHarness.assertTest(gPast1m.effectiveHours == 0.0, "1.8a: Backwards -60s yields 0.0 effective hours")
    AquariumChallengerHarness.assertTest(gPast1m.gold == 0, "1.8b: Backwards -60s yields 0 gold")
    AquariumChallengerHarness.assertTest(gPast1m.comebackBonus == 0, "1.8c: Backwards -60s yields 0 comeback bonus")

    let tPast30d = t0.addingTimeInterval(-30.0 * 24.0 * 3600.0)
    let gPast30d = state.calculateOfflineGains(now: tPast30d)
    AquariumChallengerHarness.assertTest(gPast30d.effectiveHours == 0.0, "1.8d: Backwards -30d yields 0.0 effective hours")
    AquariumChallengerHarness.assertTest(gPast30d.gold == 0, "1.8e: Backwards -30d yields 0 gold")

    // 1.9: Intermediate harvest midway through 4h window
    print("  [1.9] Testing intermediate harvest midway at 2h, then check at 5h...")
    var midwayState = state
    let t2h = t0.addingTimeInterval(2.0 * 3600.0)
    let harvested2h = midwayState.harvest(now: t2h)
    AquariumChallengerHarness.assertTest(harvested2h == Int(floor(2.0 * gph)), "1.9a: Harvest at 2h returns exactly 2h of gold")
    AquariumChallengerHarness.assertTest(midwayState.accumulatedBank == 0.0, "1.9b: Harvest resets accumulatedBank to 0")

    let t5h = t0.addingTimeInterval(5.0 * 3600.0)
    let g5hFromMidway = midwayState.calculateOfflineGains(now: t5h)
    // Between 2h and 5h, 3h elapsed, but hunger hit at 4h (2h after collection).
    // So exactly 2.0h production allowed!
    AquariumChallengerHarness.assertTest(abs(g5hFromMidway.effectiveHours - 2.0) < 0.0001, "1.9c: Post-midway harvest at 5h yields exactly 2.0h production")
    AquariumChallengerHarness.assertTest(g5hFromMidway.comebackBonus == 20, "1.9d: Comeback bonus awarded at 5h")
    let harvestedRemaining = midwayState.harvest(now: t5h)
    AquariumChallengerHarness.assertTest(harvestedRemaining == Int(floor(2.0 * gph)) + 20, "1.9e: Second harvest yields 2.0h gold + 20 bonus")
    AquariumChallengerHarness.assertTest(harvested2h + harvestedRemaining == Int(floor(4.0 * gph)) + 20, "1.9f: Total gold across both harvests equals single 4h harvest (conservation of passive gold)")
}

// MARK: - Suite 2: SaveManager Ordering Invariance & Exploit Resilience
func runOrderingInvarianceSuite() {
    print("\n======================================================================")
    print("  SUITE 2: SaveManager Ordering Invariance & Sequential Exploit Tests")
    print("======================================================================")

    let sm = SaveManager.shared

    // Helper to reset SaveManager to a known state
    func resetSM(initialGold: Int = 1000, hoursAgoFed: Double, hoursAgoCollected: Double) {
        sm.gold = initialGold
        let now = Date()
        var aq = AquariumState(
            unlockedFishIds: ["guppy", "tetra"],
            floraCounts: ["moss": 2, "kelp": 1, "anubias": 1],
            sandLevel: 1,
            lastFedTime: now.addingTimeInterval(-hoursAgoFed * 3600.0),
            lastCollectedTime: now.addingTimeInterval(-hoursAgoCollected * 3600.0),
            accumulatedBank: 0.0,
            hasClaimedComebackBonus: false
        )
        sm.aquariumState = aq
    }

    // 2.1: Invariance at t = 5 hours (Fish are hungry)
    print("  [2.1] Testing Ordering Invariance at 5h (Fish Hungry)...")
    // Order A: collectAquariumGold() then feedFish()
    resetSM(initialGold: 1000, hoursAgoFed: 5.0, hoursAgoCollected: 5.0)
    let gph = sm.aquariumState.totalGPH()
    let expectedPassive = Int(floor(4.0 * gph))
    let expectedTotalGoldIncrease = expectedPassive + 20

    let goldCollectedA = sm.collectAquariumGold()
    let feedResultA = sm.feedFish()
    let finalGoldA = sm.gold
    let bankA = sm.aquariumState.accumulatedBank
    let bonusClaimedA = sm.aquariumState.hasClaimedComebackBonus
    let isHungryA = sm.aquariumState.isFishHungry

    AquariumChallengerHarness.assertTest(goldCollectedA == expectedTotalGoldIncrease, "2.1a (Order A): collectAquariumGold returned passive + 20 bonus (\(goldCollectedA))")
    AquariumChallengerHarness.assertTest(feedResultA.comebackBonus == 0, "2.1b (Order A): feedFish returned 0 bonus (already claimed)")
    AquariumChallengerHarness.assertTest(feedResultA.hungerCleared == true, "2.1c (Order A): feedFish cleared hunger")
    AquariumChallengerHarness.assertTest(finalGoldA == 1000 + expectedTotalGoldIncrease, "2.1d (Order A): Wallet increased by exactly \(expectedTotalGoldIncrease)")

    // Order B: feedFish() then collectAquariumGold()
    resetSM(initialGold: 1000, hoursAgoFed: 5.0, hoursAgoCollected: 5.0)
    let feedResultB = sm.feedFish()
    let goldCollectedB = sm.collectAquariumGold()
    let finalGoldB = sm.gold
    let bankB = sm.aquariumState.accumulatedBank
    let bonusClaimedB = sm.aquariumState.hasClaimedComebackBonus
    let isHungryB = sm.aquariumState.isFishHungry

    AquariumChallengerHarness.assertTest(feedResultB.comebackBonus == 20, "2.1e (Order B): feedFish awarded +20 comeback bonus")
    AquariumChallengerHarness.assertTest(feedResultB.hungerCleared == true, "2.1f (Order B): feedFish cleared hunger")
    AquariumChallengerHarness.assertTest(goldCollectedB == expectedPassive, "2.1g (Order B): collectAquariumGold collected banked passive gold (\(expectedPassive))")
    AquariumChallengerHarness.assertTest(finalGoldB == 1000 + expectedTotalGoldIncrease, "2.1h (Order B): Wallet increased by exactly \(expectedTotalGoldIncrease)")

    // Mathematical equivalence assertions
    AquariumChallengerHarness.assertTest(finalGoldA == finalGoldB, "2.1i (Invariance): finalGoldA (\(finalGoldA)) == finalGoldB (\(finalGoldB))")
    AquariumChallengerHarness.assertTest(bankA == bankB && bankA == 0.0, "2.1j (Invariance): Both banks cleared to 0.0")
    AquariumChallengerHarness.assertTest(bonusClaimedA == bonusClaimedB && bonusClaimedA == false, "2.1k (Invariance): Both hasClaimedComebackBonus reset to false for next cycle")
    AquariumChallengerHarness.assertTest(isHungryA == isHungryB && isHungryA == false, "2.1l (Invariance): Fish are well fed in both")

    // 2.2: Invariance at t = 2 hours (Fish NOT hungry)
    print("  [2.2] Testing Ordering Invariance at 2h (Fish NOT Hungry)...")
    let expectedPassive2h = Int(floor(2.0 * gph))

    // Order A at 2h: collect then feed
    resetSM(initialGold: 1000, hoursAgoFed: 2.0, hoursAgoCollected: 2.0)
    let coll2hA = sm.collectAquariumGold()
    let feed2hA = sm.feedFish()
    let gold2hA = sm.gold

    AquariumChallengerHarness.assertTest(coll2hA == expectedPassive2h, "2.2a (Order A 2h): collect returned 2h passive gold (\(coll2hA))")
    AquariumChallengerHarness.assertTest(feed2hA.comebackBonus == 0, "2.2b (Order A 2h): feed returned 0 bonus")
    AquariumChallengerHarness.assertTest(feed2hA.hungerCleared == false, "2.2c (Order A 2h): feed reported hunger was not present")
    AquariumChallengerHarness.assertTest(gold2hA == 1000 + expectedPassive2h, "2.2d (Order A 2h): Wallet increased by \(expectedPassive2h)")

    // Order B at 2h: feed then collect
    resetSM(initialGold: 1000, hoursAgoFed: 2.0, hoursAgoCollected: 2.0)
    let feed2hB = sm.feedFish()
    let coll2hB = sm.collectAquariumGold()
    let gold2hB = sm.gold

    AquariumChallengerHarness.assertTest(feed2hB.comebackBonus == 0, "2.2e (Order B 2h): feed returned 0 bonus")
    AquariumChallengerHarness.assertTest(feed2hB.hungerCleared == false, "2.2f (Order B 2h): feed reported hunger was not present")
    AquariumChallengerHarness.assertTest(coll2hB == expectedPassive2h, "2.2g (Order B 2h): collect harvested banked 2h gold (\(coll2hB))")
    AquariumChallengerHarness.assertTest(gold2hB == 1000 + expectedPassive2h, "2.2h (Order B 2h): Wallet increased by \(expectedPassive2h)")

    AquariumChallengerHarness.assertTest(gold2hA == gold2hB, "2.2i (Invariance 2h): gold2hA (\(gold2hA)) == gold2hB (\(gold2hB))")

    // 2.3: Invariance at t = 8 hours
    print("  [2.3] Testing Ordering Invariance at 8h...")
    resetSM(initialGold: 1000, hoursAgoFed: 8.0, hoursAgoCollected: 8.0)
    _ = sm.collectAquariumGold()
    _ = sm.feedFish()
    let gold8hA = sm.gold

    resetSM(initialGold: 1000, hoursAgoFed: 8.0, hoursAgoCollected: 8.0)
    _ = sm.feedFish()
    _ = sm.collectAquariumGold()
    let gold8hB = sm.gold

    AquariumChallengerHarness.assertTest(gold8hA == gold8hB, "2.3 (Invariance 8h): gold8hA (\(gold8hA)) == gold8hB (\(gold8hB))")

    // 2.4: Invariance at t = 30 days
    print("  [2.4] Testing Ordering Invariance at 30 days...")
    resetSM(initialGold: 1000, hoursAgoFed: 30.0 * 24.0, hoursAgoCollected: 30.0 * 24.0)
    _ = sm.collectAquariumGold()
    _ = sm.feedFish()
    let gold30dA = sm.gold

    resetSM(initialGold: 1000, hoursAgoFed: 30.0 * 24.0, hoursAgoCollected: 30.0 * 24.0)
    _ = sm.feedFish()
    _ = sm.collectAquariumGold()
    let gold30dB = sm.gold

    AquariumChallengerHarness.assertTest(gold30dA == gold30dB, "2.4 (Invariance 30d): gold30dA (\(gold30dA)) == gold30dB (\(gold30dB))")

    // 2.5: Invariance across Sand Level 2 & 3
    print("  [2.5] Testing Ordering Invariance across sand levels 2 and 3...")
    for sLevel in [2, 3] {
        resetSM(initialGold: 1000, hoursAgoFed: 6.0, hoursAgoCollected: 6.0)
        sm.aquariumState.sandLevel = sLevel
        _ = sm.collectAquariumGold()
        _ = sm.feedFish()
        let gA = sm.gold

        resetSM(initialGold: 1000, hoursAgoFed: 6.0, hoursAgoCollected: 6.0)
        sm.aquariumState.sandLevel = sLevel
        _ = sm.feedFish()
        _ = sm.collectAquariumGold()
        let gB = sm.gold

        AquariumChallengerHarness.assertTest(gA == gB, "2.5 (Sand Level \(sLevel)): Order A (\(gA)) == Order B (\(gB))")
    }

    // 2.6: Consecutive Collect Spamming Exploit Test
    print("  [2.6] Testing consecutive collect spamming...")
    resetSM(initialGold: 1000, hoursAgoFed: 5.0, hoursAgoCollected: 5.0)
    let c1 = sm.collectAquariumGold()
    let c2 = sm.collectAquariumGold()
    let c3 = sm.collectAquariumGold()
    let c4 = sm.collectAquariumGold()

    AquariumChallengerHarness.assertTest(c1 > 0, "2.6a: First collect yields positive gold (\(c1))")
    AquariumChallengerHarness.assertTest(c2 == 0 && c3 == 0 && c4 == 0, "2.6b: Subsequent collects yield strictly 0 (c2=\(c2), c3=\(c3), c4=\(c4))")
    AquariumChallengerHarness.assertTest(sm.gold == 1000 + c1, "2.6c: Total gold strictly equals initial + c1")

    // 2.7: Consecutive Feed Spamming Exploit Test
    print("  [2.7] Testing consecutive feed spamming...")
    resetSM(initialGold: 1000, hoursAgoFed: 5.0, hoursAgoCollected: 5.0)
    let f1 = sm.feedFish()
    let f2 = sm.feedFish()
    let f3 = sm.feedFish()

    AquariumChallengerHarness.assertTest(f1.comebackBonus == 20 && f1.hungerCleared == true, "2.7a: First feed awards +20 bonus and clears hunger")
    AquariumChallengerHarness.assertTest(f2.comebackBonus == 0 && f2.hungerCleared == false, "2.7b: Second feed awards 0 bonus and reports not hungry")
    AquariumChallengerHarness.assertTest(f3.comebackBonus == 0 && f3.hungerCleared == false, "2.7c: Third feed awards 0 bonus and reports not hungry")

    // 2.8: Interleaving spam: Collect -> Collect -> Feed -> Collect
    print("  [2.8] Testing interleaving spam: Collect -> Collect -> Feed -> Collect...")
    resetSM(initialGold: 1000, hoursAgoFed: 5.0, hoursAgoCollected: 5.0)
    let ic1 = sm.collectAquariumGold()
    let ic2 = sm.collectAquariumGold()
    let if1 = sm.feedFish()
    let ic3 = sm.collectAquariumGold()

    AquariumChallengerHarness.assertTest(ic1 == expectedTotalGoldIncrease, "2.8a: First collect yields full payout")
    AquariumChallengerHarness.assertTest(ic2 == 0, "2.8b: Second collect yields 0")
    AquariumChallengerHarness.assertTest(if1.comebackBonus == 0 && if1.hungerCleared == true, "2.8c: Feed awards 0 bonus (already collected) and clears hunger")
    AquariumChallengerHarness.assertTest(ic3 == 0, "2.8d: Third collect yields 0")
    AquariumChallengerHarness.assertTest(sm.gold == 1000 + expectedTotalGoldIncrease, "2.8e: Total wallet exactly matches expected payout")
}

// MARK: - Suite 3: Codable Serialization & Schema Backward Compatibility
func runCodableSchemaSuite() {
    print("\n======================================================================")
    print("  SUITE 3: Codable Serialization & Schema Backward Compatibility")
    print("======================================================================")

    let original = AquariumState(
        unlockedFishIds: ["guppy", "tetra", "arowana"],
        floraCounts: ["moss": 3, "shrimp": 2],
        sandLevel: 2,
        lastFedTime: Date(timeIntervalSince1970: 1700000000),
        lastCollectedTime: Date(timeIntervalSince1970: 1700001000),
        accumulatedBank: 45.5,
        hasClaimedComebackBonus: true
    )

    // 3.1: Full roundtrip serialization
    print("  [3.1] Testing full JSON roundtrip...")
    do {
        let encoder = JSONEncoder()
        let data = try encoder.encode(original)
        let decoder = JSONDecoder()
        let decoded = try decoder.decode(AquariumState.self, from: data)

        AquariumChallengerHarness.assertTest(decoded.unlockedFishIds == original.unlockedFishIds, "3.1a: Fish IDs preserved")
        AquariumChallengerHarness.assertTest(decoded.floraCounts == original.floraCounts, "3.1b: Flora counts preserved")
        AquariumChallengerHarness.assertTest(decoded.sandLevel == original.sandLevel, "3.1c: Sand level preserved")
        AquariumChallengerHarness.assertTest(abs(decoded.lastFedTime.timeIntervalSince(original.lastFedTime)) < 0.001, "3.1d: lastFedTime preserved")
        AquariumChallengerHarness.assertTest(abs(decoded.lastCollectedTime.timeIntervalSince(original.lastCollectedTime)) < 0.001, "3.1e: lastCollectedTime preserved")
        AquariumChallengerHarness.assertTest(decoded.accumulatedBank == original.accumulatedBank, "3.1f: accumulatedBank preserved")
        AquariumChallengerHarness.assertTest(decoded.hasClaimedComebackBonus == original.hasClaimedComebackBonus, "3.1g: hasClaimedComebackBonus preserved")
    } catch {
        AquariumChallengerHarness.assertTest(false, "3.1: Roundtrip failed with error: \(error)")
    }

    // 3.2: Backward compatibility when JSON lacks hasClaimedComebackBonus
    print("  [3.2] Testing backward compatibility with legacy JSON lacking hasClaimedComebackBonus...")
    let legacyJSON = """
    {
        "unlockedFishIds": ["guppy"],
        "floraCounts": {"moss": 1},
        "sandLevel": 1,
        "lastFedTime": 1700000000,
        "lastCollectedTime": 1700000000,
        "accumulatedBank": 10.0
    }
    """
    do {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .secondsSince1970
        let decoded = try decoder.decode(AquariumState.self, from: Data(legacyJSON.utf8))
        AquariumChallengerHarness.assertTest(decoded.hasClaimedComebackBonus == false, "3.2a: Missing hasClaimedComebackBonus safely defaults to false")
        AquariumChallengerHarness.assertTest(decoded.unlockedFishIds == ["guppy"], "3.2b: Fish IDs decoded correctly from legacy JSON")
        AquariumChallengerHarness.assertTest(decoded.accumulatedBank == 10.0, "3.2c: accumulatedBank decoded correctly from legacy JSON")
    } catch {
        AquariumChallengerHarness.assertTest(false, "3.2: Legacy JSON decoding failed: \(error)")
    }
}

// MARK: - Main Entrypoint
@main
struct ChallengerMain {
    static func main() {
        print("**********************************************************************")
        print("    EMPIRICAL CHALLENGER: AQUARIUM STATE & SAVE MANAGER VERIFIER    ")
        print("**********************************************************************")

        runMathematicalEdgeCaseSuite()
        runOrderingInvarianceSuite()
        runCodableSchemaSuite()

        let exitCode = AquariumChallengerHarness.summary()
        exit(Int32(exitCode))
    }
}
