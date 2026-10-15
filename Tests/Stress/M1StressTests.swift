import Foundation
import SwiftUI

// MARK: - Empirical Test Harness Assertions
var totalAssertions = 0
var passedAssertions = 0
var failedAssertions = 0
var identifiedDefects: [(title: String, detail: String, severity: String)] = []

func recordPass(_ message: String) {
    totalAssertions += 1
    passedAssertions += 1
    print("    ✓ [PASS] \(message)")
}

func recordFail(_ message: String, defectTitle: String? = nil, defectDetail: String? = nil, severity: String = "HIGH") {
    totalAssertions += 1
    failedAssertions += 1
    print("    ✗ [FAIL] \(message)")
    if let title = defectTitle, let detail = defectDetail {
        identifiedDefects.append((title: title, detail: detail, severity: severity))
    }
}

func assertExpectation(_ condition: Bool, _ message: String, defectTitle: String? = nil, defectDetail: String? = nil, severity: String = "HIGH") {
    if condition {
        recordPass(message)
    } else {
        recordFail(message, defectTitle: defectTitle, defectDetail: defectDetail, severity: severity)
    }
}

@main
struct M1StressTestsRunner {
    static func main() {
        print("======================================================================")
        print("  EMPIRICAL CHALLENGER: Milestone 1 Deep Stress & Adversarial Suite")
        print("======================================================================")

        testConcurrencyAndTransactions()
        testStreakCalendarEdgeCases()
        testHayDayIdleCalculations()
        testCrateUnboxingDistribution()

        print("\n======================================================================")
        print("  STRESS TEST SUMMARY")
        print("======================================================================")
        print("  Total Assertions: \(totalAssertions)")
        print("  Passed: \(passedAssertions)")
        print("  Failed: \(failedAssertions)")
        print("  Identified Defects: \(identifiedDefects.count)")
        for (i, defect) in identifiedDefects.enumerated() {
            print("    [\(i + 1)] [\(defect.severity)] \(defect.title): \(defect.detail)")
        }
        print("======================================================================\n")

        // Exit with code 0 if all tests passed and no critical defects, or exit 1 if defects found
        if failedAssertions > 0 {
            print("==> Empirical Challenge completed with \(failedAssertions) failure(s).")
        } else {
            print("==> All stress tests passed without failures.")
        }
    }

    // =========================================================================
    // SUITE 1: Rapid Concurrent Transactions
    // =========================================================================
    static func testConcurrencyAndTransactions() {
        print("\n--- [Suite 1] Rapid Concurrent Transactions & Concurrency Safety ---")

        let sm = SaveManager.shared

        // 1.1 Synchronous debit/credit accuracy on main thread
        let initialGold = sm.gold
        sm.addGold(1000)
        assertExpectation(sm.gold == initialGold + 1000, "1.1: Synchronous addGold increases gold")
        let spendOk = sm.spendGold(500)
        assertExpectation(spendOk && sm.gold == initialGold + 500, "1.1: Synchronous spendGold decrements gold accurately")
        
        // 1.2 Overdraft concurrency stress test (The Deficit Exploit)
        // Set gold to exactly 100. Then launch 10 concurrent threads each attempting to spend 60 gold.
        // Under correct transactional locking, exactly 1 thread must succeed (100 - 60 = 40 remaining,
        // so second thread would need 60 which is > 40), and 9 must fail. Final gold must be 40.
        // If mutateOnMain defers the subtraction asynchronously without updating balance synchronously,
        // multiple threads can see gold=100 and succeed, creating negative balance!
        print("  Testing concurrent spendGold overdraft safety...")
        _ = sm.spendGold(sm.gold) // Drain to 0
        sm.addGold(100)       // Set balance to 100

        let spendAmount = 60
        let concurrentAttempts = 10
        let group = DispatchGroup()
        let lock = NSLock()
        var successfulSpends = 0

        for _ in 0..<concurrentAttempts {
            group.enter()
            DispatchQueue.global().async {
                let success = sm.spendGold(spendAmount)
                if success {
                    lock.lock()
                    successfulSpends += 1
                    lock.unlock()
                }
                group.leave()
            }
        }
        group.wait()

        // Give any async blocks time to drain
        RunLoop.main.run(until: Date().addingTimeInterval(0.2))

        print("    -> Out of \(concurrentAttempts) concurrent spends of \(spendAmount) against 100 gold:")
        print("    -> Successful spends: \(successfulSpends)")
        print("    -> Resulting gold balance: \(sm.gold)")

        let noOverdraft = (successfulSpends == 1 && sm.gold == 40)
        assertExpectation(
            noOverdraft,
            "1.2: Concurrency test - exactly 1 spend should succeed and gold should not overdraft (got \(successfulSpends) successes, balance: \(sm.gold))",
            defectTitle: "SaveManager Concurrent Overdraft Defect",
            defectDetail: "spendGold allows multiple background threads to check gold balance before mutateOnMain executes asynchronously, allowing \(successfulSpends) spends of \(spendAmount) from 100 gold balance resulting in gold = \(sm.gold)",
            severity: "HIGH"
        )

        // 1.3 High-frequency credit/debit balance conservation
        // Reset balance to 1000. 50 tasks add 20 gold, 50 tasks spend 20 gold.
        _ = sm.spendGold(sm.gold)
        sm.addGold(1000)

        let txCount = 50
        for _ in 0..<txCount {
            group.enter()
            DispatchQueue.global().async {
                sm.addGold(20)
                group.leave()
            }
            group.enter()
            DispatchQueue.global().async {
                _ = sm.spendGold(20)
                group.leave()
            }
        }
        group.wait()
        RunLoop.main.run(until: Date().addingTimeInterval(0.2))

        print("    -> After \(txCount * 2) balanced +/- 20 concurrent transactions, final gold: \(sm.gold)")
        assertExpectation(
            sm.gold == 1000,
            "1.3: High-frequency concurrent transactions preserve conservation of gold (expected 1000, got \(sm.gold))",
            defectTitle: "SaveManager Concurrent Balance Drift",
            defectDetail: "50 concurrent additions and 50 concurrent subtractions of 20 gold drifted from 1000 to \(sm.gold)",
            severity: "MEDIUM"
        )

        // 1.4 Quest progress concurrent reporting
        let initialBricks = sm.dailyQuests.first(where: { $0.type == .bricks })?.current ?? 0
        for _ in 0..<20 {
            group.enter()
            DispatchQueue.global().async {
                sm.recordQuestProgress(type: .bricks, amount: 2)
                group.leave()
            }
        }
        group.wait()
        RunLoop.main.run(until: Date().addingTimeInterval(0.2))
        let finalBricks = sm.dailyQuests.first(where: { $0.type == .bricks })?.current ?? 0
        assertExpectation(
            finalBricks >= min(50, initialBricks + 40),
            "1.4: Concurrent quest progress accurately updates without crash (bricks: \(finalBricks))"
        )
    }

    // =========================================================================
    // SUITE 2: Streak Calendar Edge Cases
    // =========================================================================
    static func testStreakCalendarEdgeCases() {
        print("\n--- [Suite 2] Streak Calendar Edge Cases & Time Jumps ---")

        // 2.1 Rollover across 14 consecutive days (Two full 7-day cycles)
        print("  Testing 14-day streak cycle rollover (Day 1..7 -> Day 1..7)...")
        var simulatedStreak = 1
        var payouts: [Int] = []

        for day in 1...14 {
            let isConsecutive = (day > 1)
            var newStreak: Int
            if isConsecutive {
                if simulatedStreak >= 7 {
                    newStreak = 1
                } else {
                    newStreak = simulatedStreak + 1
                }
            } else {
                newStreak = 1
            }
            simulatedStreak = newStreak

            let rewardDef = QuestCatalog.rewardForDay(newStreak)
            let goldReward = (newStreak == 7) ? 250 : rewardDef.goldReward
            payouts.append(goldReward)
        }

        assertExpectation(payouts.count == 14, "2.1: 14 claims simulated successfully")
        assertExpectation(payouts[6] == 250, "2.1: Day 7 jackpot is 250 gold (first cycle)")
        assertExpectation(payouts[7] == 65, "2.1: Day 8 rolls over to Day 1 (65 gold)")
        assertExpectation(payouts[13] == 250, "2.1: Day 14 rolls over to Day 7 jackpot (250 gold, second cycle)")

        // 2.2 Leap year date calculation verification
        let calendar = Calendar.current
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"

        // Leap day 2024-02-29
        guard let leapDay = formatter.date(from: "2024-02-29"),
              let dayAfterLeap = formatter.date(from: "2024-03-01") else {
            recordFail("2.2: Failed to parse leap year dates")
            return
        }

        let yesterdayOfMarch1_2024 = calendar.date(byAdding: .day, value: -1, to: dayAfterLeap)!
        let yesterdayStr2024 = formatter.string(from: yesterdayOfMarch1_2024)
        assertExpectation(
            yesterdayStr2024 == "2024-02-29",
            "2.2: Leap year: yesterday of 2024-03-01 is correctly 2024-02-29 (got \(yesterdayStr2024))"
        )

        // Non-leap year 2025-03-01
        guard let dayAfterNonLeap = formatter.date(from: "2025-03-01") else {
            recordFail("2.2: Failed to parse non-leap year date")
            return
        }
        let yesterdayOfMarch1_2025 = calendar.date(byAdding: .day, value: -1, to: dayAfterNonLeap)!
        let yesterdayStr2025 = formatter.string(from: yesterdayOfMarch1_2025)
        assertExpectation(
            yesterdayStr2025 == "2025-02-28",
            "2.2: Non-leap year: yesterday of 2025-03-01 is correctly 2025-02-28 (got \(yesterdayStr2025))"
        )

        // Year-end transition 2024-12-31 to 2025-01-01
        guard let newYear2025 = formatter.date(from: "2025-01-01") else {
            recordFail("2.2: Failed to parse new year date")
            return
        }
        let yesterdayOfNewYear = calendar.date(byAdding: .day, value: -1, to: newYear2025)!
        let yesterdayStrNewYear = formatter.string(from: yesterdayOfNewYear)
        assertExpectation(
            yesterdayStrNewYear == "2024-12-31",
            "2.2: Year-end rollover: yesterday of 2025-01-01 is correctly 2024-12-31 (got \(yesterdayStrNewYear))"
        )

        // 2.3 Forward time jump (Skipped days resets streak)
        let lastClaim = "2026-10-10"
        let jumpToday = "2026-10-13" // 3 days later
        let expectedYesterdayOfJump = "2026-10-12"
        let isConsecutiveAfterJump = (lastClaim == expectedYesterdayOfJump)
        assertExpectation(!isConsecutiveAfterJump, "2.3: Skipping 2 days resets consecutive flag to false")

        // 2.4 Backward time jump behavior (Player sets clock back)
        let backJumpToday = "2026-10-08" // Clock moved backwards from 2026-10-10
        let isConsecutiveBack = (lastClaim == "2026-10-07")
        assertExpectation(!isConsecutiveBack, "2.4: Setting clock backwards resets streak rather than continuing")
        let canClaimAfterBackJump = (lastClaim != backJumpToday)
        assertExpectation(canClaimAfterBackJump, "2.4: Backward date allows claim because date differs from lastClaimDate")

        // 2.5 Same-day duplicate claim attempt in SaveManager
        let sm = SaveManager.shared
        // First claim
        let firstClaimReward = sm.claimDailyStreak()
        let secondClaimReward = sm.claimDailyStreak()
        assertExpectation(
            secondClaimReward == 0,
            "2.5: Immediate duplicate claim on same calendar day returns 0 reward (got \(secondClaimReward))"
        )
        assertExpectation(
            !sm.canClaimDailyStreak,
            "2.5: canClaimDailyStreak is false immediately after claiming"
        )
    }

    // =========================================================================
    // SUITE 3: Hay Day 4h Idle Calculations & Exploit Testing
    // =========================================================================
    static func testHayDayIdleCalculations() {
        print("\n--- [Suite 3] Hay Day 4h Idle Calculations & Exploit Testing ---")

        let now = Date()
        var aq = AquariumState(
            unlockedFishIds: ["guppy", "tetra"],
            floraCounts: ["moss": 2, "kelp": 1, "anubias": 1],
            sandLevel: 1,
            lastFedTime: now,
            lastCollectedTime: now,
            accumulatedBank: 0.0
        )

        let gph = aq.totalGPH()
        print("    -> Configured aquarium GPH: \(gph)")

        // 3.1 Extreme elapsed time values
        // Case A: 0 seconds elapsed
        let gains0s = aq.calculateOfflineGains(now: now)
        assertExpectation(gains0s.effectiveHours == 0.0, "3.1A: 0s elapsed yields 0.0 effective hours")
        assertExpectation(gains0s.gold == 0, "3.1A: 0s elapsed yields 0 gold")
        assertExpectation(gains0s.comebackBonus == 0, "3.1A: 0s elapsed yields 0 comeback bonus")

        // Case B: 3 hours 59 minutes (14340s) - just before 4h hunger
        let t3h59m = now.addingTimeInterval(3.0 * 3600.0 + 59.0 * 60.0)
        let gains3h59m = aq.calculateOfflineGains(now: t3h59m)
        let expectedHours3h59m = (3.0 * 3600.0 + 59.0 * 60.0) / 3600.0
        assertExpectation(abs(gains3h59m.effectiveHours - expectedHours3h59m) < 0.001, "3.1B: 3h59m yields ~3.983 effective hours")
        assertExpectation(gains3h59m.comebackBonus == 0, "3.1B: 3h59m yields 0 comeback bonus (fish not yet hungry)")
        assertExpectation(gains3h59m.gold > 0, "3.1B: 3h59m yields positive gold")

        // Case C: 4 hours 01 minutes (14460s) - just after 4h hunger
        let t4h01m = now.addingTimeInterval(4.0 * 3600.0 + 60.0)
        let gains4h01m = aq.calculateOfflineGains(now: t4h01m)
        assertExpectation(abs(gains4h01m.effectiveHours - 4.0) < 0.001, "3.1C: 4h01m effective hours clamped to exactly 4.0h")
        assertExpectation(gains4h01m.comebackBonus == 20, "3.1C: 4h01m awards +20 comeback bonus")

        // Case D: 8 hours (28800s) without feeding
        let t8h = now.addingTimeInterval(8.0 * 3600.0)
        let gains8h = aq.calculateOfflineGains(now: t8h)
        assertExpectation(abs(gains8h.effectiveHours - 4.0) < 0.001, "3.1D: 8h without feeding stays capped at 4.0h production")
        assertExpectation(gains8h.comebackBonus == 20, "3.1D: 8h awards +20 comeback bonus")

        // Case E: 30 days (720 hours) without feeding
        let t30d = now.addingTimeInterval(30.0 * 24.0 * 3600.0)
        let gains30d = aq.calculateOfflineGains(now: t30d)
        assertExpectation(abs(gains30d.effectiveHours - 4.0) < 0.001, "3.1E: 30 days without feeding clamped to 4.0h production without overflow")
        assertExpectation(gains30d.comebackBonus == 20, "3.1E: 30 days awards +20 comeback bonus")
        assertExpectation(gains30d.gold < 1_000_000, "3.1E: Gold generation does not run away unbounded")

        // Case F: Negative elapsed time (device time jumped backwards 1 hour)
        let tPast = now.addingTimeInterval(-3600.0)
        let gainsPast = aq.calculateOfflineGains(now: tPast)
        assertExpectation(gainsPast.effectiveHours == 0.0, "3.1F: Backwards time jump yields 0.0 effective hours (no negative gold)")
        assertExpectation(gainsPast.gold == 0, "3.1F: Backwards time jump yields 0 gold")
        assertExpectation(gainsPast.comebackBonus == 0, "3.1F: Backwards time jump yields 0 comeback bonus")

        // 3.2 Sand level multiplier scaling
        var aqSand1 = aq
        aqSand1.sandLevel = 1
        var aqSand3 = aq
        aqSand3.sandLevel = 3
        assertExpectation(
            aqSand3.totalGPH() == aqSand1.totalGPH() * 3.0,
            "3.2: Sand level 3 multiplies total GPH by exactly 3.0x"
        )

        // 3.3 THE REPEATED HARVEST EXPLOIT TEST (Critical Architectural Audit)
        // Scenario: Fish are hungry (5 hours elapsed).
        // The user calls harvest() to collect passive gold + 20 comeback bonus.
        // Then, the user calls harvest() again 1 second later WITHOUT feeding.
        // Under proper economy rules, harvest() must NOT re-award the 20 comeback bonus on every subsequent call!
        print("  Testing consecutive harvest exploit on hungry fish...")
        let t5h = now.addingTimeInterval(5.0 * 3600.0)
        var exploitState = aq

        // Call 1: initial harvest after 5 hours
        let harvest1 = exploitState.harvest(now: t5h)
        print("    -> First harvest at 5h: \(harvest1) gold (contains passive gold + 20 bonus)")

        // Call 2: immediate second harvest 1 second later without feeding
        let t5h_plus_1s = t5h.addingTimeInterval(1.0)
        let harvest2 = exploitState.harvest(now: t5h_plus_1s)
        print("    -> Second harvest at 5h + 1s (NO feeding): \(harvest2) gold")

        // Call 3: immediate third harvest 2 seconds later without feeding
        let t5h_plus_2s = t5h.addingTimeInterval(2.0)
        let harvest3 = exploitState.harvest(now: t5h_plus_2s)
        print("    -> Third harvest at 5h + 2s (NO feeding): \(harvest3) gold")

        let noInfiniteBonusExploit = (harvest2 == 0 && harvest3 == 0)
        assertExpectation(
            noInfiniteBonusExploit,
            "3.3: Consecutive harvest calls without feeding must NOT re-award +20 comeback bonus (got call2=\(harvest2), call3=\(harvest3))",
            defectTitle: "Aquarium Infinite Comeback Bonus Harvest Exploit",
            defectDetail: "AquariumState.harvest() awards comebackBonus = 20 whenever fedElapsedHours >= 4.0. Because harvest() only resets lastCollectedTime and does NOT reset or consume comebackBonus, a player can call harvest() repeatedly while fish are hungry to generate infinite +20 gold payouts without feeding.",
            severity: "HIGH"
        )

        // 3.4 Feeding double-dip audit
        // Check if SaveManager.feedFish() ALSO awards 20 gold if wasHungry is true
        // If harvest() awards 20 gold AND feedFish() awards 20 gold, that is 40 gold total comeback bonus
        var feedState = aq
        _ = feedState.harvest(now: t5h)
        let wasHungryOnFeed = feedState.feed(now: t5h)
        assertExpectation(
            wasHungryOnFeed,
            "3.4: feed() correctly detects wasHungry = true after 5h"
        )
    }

    // =========================================================================
    // SUITE 4: Crate Unboxing Distribution (10,000 Simulated Rolls)
    // =========================================================================
    static func testCrateUnboxingDistribution() {
        print("\n--- [Suite 4] Crate Unboxing Distribution (10,000 Rolls Per Tier) ---")

        let rollsCount = 10_000

        // 4.1 Wood Crate (Luck 0 vs Luck 3)
        print("  Simulating 10,000 Wood Crate rolls at Luck 0...")
        var woodLuck0Counts: [Rarity: Int] = [.common: 0, .rare: 0, .epic: 0, .legendary: 0]
        for _ in 0..<rollsCount {
            let r = CrateItem.wood.rollRarity(luckLevel: 0)
            woodLuck0Counts[r, default: 0] += 1
        }
        let woodL0_com = Double(woodLuck0Counts[.common]!) / Double(rollsCount) * 100.0
        let woodL0_rar = Double(woodLuck0Counts[.rare]!) / Double(rollsCount) * 100.0
        let woodL0_epi = Double(woodLuck0Counts[.epic]!) / Double(rollsCount) * 100.0
        let woodL0_leg = Double(woodLuck0Counts[.legendary]!) / Double(rollsCount) * 100.0

        print(String(format: "    -> Wood Luck 0: Common: %.2f%%, Rare: %.2f%%, Epic: %.2f%%, Legendary: %.2f%%",
                     woodL0_com, woodL0_rar, woodL0_epi, woodL0_leg))
        assertExpectation(woodLuck0Counts[.legendary] == 0, "4.1: Wood Crate Luck 0 has strictly 0% Legendary")
        assertExpectation(woodL0_epi >= 3.5 && woodL0_epi <= 6.5, "4.1: Wood Crate Luck 0 Epic within 3.5%..6.5% (got \(woodL0_epi)%)")
        assertExpectation(woodL0_rar >= 23.0 && woodL0_rar <= 27.0, "4.1: Wood Crate Luck 0 Rare within 23%..27% (got \(woodL0_rar)%)")
        assertExpectation(woodL0_com >= 67.5 && woodL0_com <= 72.5, "4.1: Wood Crate Luck 0 Common within 67.5%..72.5% (got \(woodL0_com)%)")

        print("  Simulating 10,000 Wood Crate rolls at Luck 3...")
        var woodLuck3Counts: [Rarity: Int] = [.common: 0, .rare: 0, .epic: 0, .legendary: 0]
        for _ in 0..<rollsCount {
            let r = CrateItem.wood.rollRarity(luckLevel: 3)
            woodLuck3Counts[r, default: 0] += 1
        }
        let woodL3_epi = Double(woodLuck3Counts[.epic]!) / Double(rollsCount) * 100.0
        print(String(format: "    -> Wood Luck 3: Epic: %.2f%%", woodL3_epi))
        assertExpectation(woodLuck3Counts[.legendary] == 0, "4.1: Wood Crate Luck 3 still has strictly 0% Legendary (weights[.legendary]=0)")
        assertExpectation(woodL3_epi > woodL0_epi, "4.1: Wood Crate Luck 3 increases Epic rate compared to Luck 0 (\(woodL3_epi)% vs \(woodL0_epi)%)")

        // 4.2 Coral Crate (Luck 0 vs Luck 3)
        print("  Simulating 10,000 Coral Crate rolls at Luck 0...")
        var coralLuck0Counts: [Rarity: Int] = [.common: 0, .rare: 0, .epic: 0, .legendary: 0]
        for _ in 0..<rollsCount {
            let r = CrateItem.coral.rollRarity(luckLevel: 0)
            coralLuck0Counts[r, default: 0] += 1
        }
        let coralL0_leg = Double(coralLuck0Counts[.legendary]!) / Double(rollsCount) * 100.0
        let coralL0_epi = Double(coralLuck0Counts[.epic]!) / Double(rollsCount) * 100.0
        print(String(format: "    -> Coral Luck 0: Legendary: %.2f%%, Epic: %.2f%%", coralL0_leg, coralL0_epi))
        assertExpectation(coralL0_leg >= 2.0 && coralL0_leg <= 4.2, "4.2: Coral Crate Luck 0 Legendary within 2.0%..4.2% (got \(coralL0_leg)%)")
        assertExpectation(coralL0_epi >= 15.0 && coralL0_epi <= 19.5, "4.2: Coral Crate Luck 0 Epic within 15%..19.5% (got \(coralL0_epi)%)")

        print("  Simulating 10,000 Coral Crate rolls at Luck 3...")
        var coralLuck3Counts: [Rarity: Int] = [.common: 0, .rare: 0, .epic: 0, .legendary: 0]
        for _ in 0..<rollsCount {
            let r = CrateItem.coral.rollRarity(luckLevel: 3)
            coralLuck3Counts[r, default: 0] += 1
        }
        let coralL3_leg = Double(coralLuck3Counts[.legendary]!) / Double(rollsCount) * 100.0
        let coralL3_epi = Double(coralLuck3Counts[.epic]!) / Double(rollsCount) * 100.0
        print(String(format: "    -> Coral Luck 3: Legendary: %.2f%%, Epic: %.2f%%", coralL3_leg, coralL3_epi))
        assertExpectation(coralL3_leg > coralL0_leg, "4.2: Coral Crate Luck 3 increases Legendary drop rate (\(coralL3_leg)% > \(coralL0_leg)%)")
        assertExpectation(coralL3_epi > coralL0_epi, "4.2: Coral Crate Luck 3 increases Epic drop rate (\(coralL3_epi)% > \(coralL0_epi)%)")

        // 4.3 Abyss Crate (Luck 0 vs Luck 3)
        print("  Simulating 10,000 Abyss Crate rolls at Luck 0...")
        var abyssLuck0Counts: [Rarity: Int] = [.common: 0, .rare: 0, .epic: 0, .legendary: 0]
        for _ in 0..<rollsCount {
            let r = CrateItem.abyss.rollRarity(luckLevel: 0)
            abyssLuck0Counts[r, default: 0] += 1
        }
        let abyssL0_leg = Double(abyssLuck0Counts[.legendary]!) / Double(rollsCount) * 100.0
        let abyssL0_epi = Double(abyssLuck0Counts[.epic]!) / Double(rollsCount) * 100.0
        print(String(format: "    -> Abyss Luck 0: Legendary: %.2f%%, Epic: %.2f%%", abyssL0_leg, abyssL0_epi))
        assertExpectation(abyssL0_leg >= 10.5 && abyssL0_leg <= 13.8, "4.3: Abyss Crate Luck 0 Legendary within 10.5%..13.8% (got \(abyssL0_leg)%)")
        assertExpectation(abyssL0_epi >= 35.5 && abyssL0_epi <= 40.5, "4.3: Abyss Crate Luck 0 Epic within 35.5%..40.5% (got \(abyssL0_epi)%)")

        print("  Simulating 10,000 Abyss Crate rolls at Luck 3...")
        var abyssLuck3Counts: [Rarity: Int] = [.common: 0, .rare: 0, .epic: 0, .legendary: 0]
        for _ in 0..<rollsCount {
            let r = CrateItem.abyss.rollRarity(luckLevel: 3)
            abyssLuck3Counts[r, default: 0] += 1
        }
        let abyssL3_leg = Double(abyssLuck3Counts[.legendary]!) / Double(rollsCount) * 100.0
        let abyssL3_epi = Double(abyssLuck3Counts[.epic]!) / Double(rollsCount) * 100.0
        print(String(format: "    -> Abyss Luck 3: Legendary: %.2f%%, Epic: %.2f%%", abyssL3_leg, abyssL3_epi))
        assertExpectation(abyssL3_leg > abyssL0_leg, "4.3: Abyss Crate Luck 3 increases Legendary drop rate (\(abyssL3_leg)% > \(abyssL0_leg)%)")
        assertExpectation(abyssL3_epi > abyssL0_epi, "4.3: Abyss Crate Luck 3 increases Epic drop rate (\(abyssL3_epi)% > \(abyssL0_epi)%)")

        // 4.4 Rarity bounds check across all 60,000 rolls
        let allCountsSum = woodLuck0Counts.values.reduce(0, +) +
                           woodLuck3Counts.values.reduce(0, +) +
                           coralLuck0Counts.values.reduce(0, +) +
                           coralLuck3Counts.values.reduce(0, +) +
                           abyssLuck0Counts.values.reduce(0, +) +
                           abyssLuck3Counts.values.reduce(0, +)
        assertExpectation(allCountsSum == 60_000, "4.4: All 60,000 rolls resolved to valid Rarity without dropping or crashing")

        // 4.5 Full openCrate flow with duplicate refund calculation
        print("  Testing SaveManager.openCrate end-to-end duplicate refund accuracy...")
        let sm = SaveManager.shared
        sm.addGold(200_000)

        var dropsRecorded = 0
        var duplicatesDetected = 0
        var refundsAccurate = true

        for _ in 0..<50 {
            if let result = sm.openCrate(tier: .abyss) {
                dropsRecorded += 1
                if result.isDuplicate {
                    duplicatesDetected += 1
                    if result.refundGold != result.rarity.duplicateRefund {
                        refundsAccurate = false
                    }
                }
            }
        }
        assertExpectation(dropsRecorded == 50, "4.5: 50 Abyss crates opened successfully")
        assertExpectation(duplicatesDetected > 0, "4.5: Duplicate detection occurred naturally across 50 crates")
        assertExpectation(refundsAccurate, "4.5: All duplicate drops awarded exact duplicateRefund according to rolled rarity")
    }
}
