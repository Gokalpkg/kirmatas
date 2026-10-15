import Foundation

public struct Tier2_BoundaryCornerCases {
    public static func runTests(reporter: TestReporter = .shared) {
        reporter.startTier("Tier 2: Boundary & Corner Cases (>=5 Tests Per Feature)")
        
        // ====================================================================
        // FEATURE 1: ECO-TANK AQUARIUM BOUNDARIES
        // ====================================================================
        
        // B1.1: 0 Seconds Passive Accumulation
        do {
            let base = Date()
            let eco = AquariumEconomy(lastFedTime: base)
            let zeroGold = eco.calculateAccumulatedGold(from: base, to: base)
            reporter.assertEqual(zeroGold, 0, "B1.1: Exactly 0 gold accumulated at t = 0 seconds")
        }
        
        // B1.2: 3h 59m 59s Hunger Boundary (1 second before 4 hours)
        do {
            let base = Date(timeIntervalSince1970: 50000)
            let eco = AquariumEconomy(lastFedTime: base)
            let timeBefore4h = base.addingTimeInterval(3.0 * 3600.0 + 59.0 * 60.0 + 59.0) // 14,399s
            reporter.assertFalse(eco.isHungry(at: timeBefore4h), "B1.2: Fish are NOT hungry at t = 3h 59m 59s")
        }
        
        // B1.3: Exactly 4h 00m 00s Hunger State Transition (14,400s)
        do {
            let base = Date(timeIntervalSince1970: 50000)
            let eco = AquariumEconomy(lastFedTime: base)
            let timeAt4h = base.addingTimeInterval(4.0 * 3600.0) // 14,400s
            reporter.assertTrue(eco.isHungry(at: timeAt4h), "B1.3: Fish transition to HUNGRY at exactly t = 4h 00m 00s")
            
            // Gold production halts: gold at 4h equals gold at 6h because fish are hungry
            let goldAt4h = eco.calculateAccumulatedGold(from: base, to: timeAt4h)
            let goldAt6h = eco.calculateAccumulatedGold(from: base, to: base.addingTimeInterval(6.0 * 3600.0))
            reporter.assertEqual(goldAt4h, goldAt6h, "B1.3: Gold production halts after 4 hours of hunger")
        }
        
        // B1.4: 8-Hour Maximum Accumulation Cap Clamp (28,800s)
        do {
            let base = Date(timeIntervalSince1970: 50000)
            let eco = AquariumEconomy(lastFedTime: base)
            // Even if fed continuously or during calculation, accumulation past 8h cap is strictly clamped
            let goldAt8h = eco.calculateAccumulatedGold(from: base, to: base.addingTimeInterval(8.0 * 3600.0))
            let goldAt24h = eco.calculateAccumulatedGold(from: base, to: base.addingTimeInterval(24.0 * 3600.0))
            let goldAt100h = eco.calculateAccumulatedGold(from: base, to: base.addingTimeInterval(100.0 * 3600.0))
            reporter.assertEqual(goldAt8h, goldAt24h, "B1.4: 24h accumulation strictly clamped to 8h maximum cap")
            reporter.assertEqual(goldAt8h, goldAt100h, "B1.4: 100h accumulation strictly clamped to 8h maximum cap")
        }
        
        // B1.5: Comeback Bonus Starvation Recovery
        do {
            let base = Date(timeIntervalSince1970: 50000)
            var hungryEco = AquariumEconomy(lastFedTime: base)
            let returnTime = base.addingTimeInterval(6 * 3600) // 6h elapsed
            let feedResult = hungryEco.feed(at: returnTime)
            reporter.assertTrue(feedResult.hungerCleared, "B1.5: Feeding clears hunger state")
            reporter.assertEqual(feedResult.comebackBonusAwarded, 20, "B1.5: Starvation recovery awards exactly +20 comeback bonus")
            
            // Feeding again immediately awards 0 comeback bonus
            let immediateFeed = hungryEco.feed(at: returnTime.addingTimeInterval(10))
            reporter.assertEqual(immediateFeed.comebackBonusAwarded, 0, "B1.5: Non-hungry feeding awards 0 comeback bonus")
        }
        
        // ====================================================================
        // FEATURE 2: 6-TAB SHOP & COSMETICS BOUNDARIES
        // ====================================================================
        
        // B2.1: Insufficient Funds Purchase Protection
        do {
            let player = PlayerSaveState(initialGold: 0)
            let success = player.spendGold(900)
            reporter.assertFalse(success, "B2.1: Purchase with 0 gold strictly rejected")
            reporter.assertEqual(player.gold, 0, "B2.1: Balance remains unchanged at 0 gold")
            
            player.gold = 899
            let failBy1 = player.spendGold(900)
            reporter.assertFalse(failBy1, "B2.1: Purchase with 1 gold below required cost rejected")
            reporter.assertEqual(player.gold, 899, "B2.1: Balance remains unchanged at 899 gold")
        }
        
        // B2.2: Exact Cost Deduction Boundary
        do {
            let player = PlayerSaveState(initialGold: 1800)
            let success = player.spendGold(1800)
            reporter.assertTrue(success, "B2.2: Purchase with exact gold balance succeeds")
            reporter.assertEqual(player.gold, 0, "B2.2: Balance reaches exactly 0 without negative underflow")
        }
        
        // B2.3: Zero Legendary Odds in Wood Crate & Sum to 100%
        do {
            let woodWeights = CrateTierDef.wood.weights
            reporter.assertEqual(woodWeights[.legendary], 0.0, "B2.3: Wood Crate has strictly 0.0% Legendary drop probability")
            
            let abyssWeights = CrateTierDef.abyss.weights
            reporter.assertEqual(abyssWeights[.legendary], 12.0, "B2.3: Abyss Crate has 12.0% Legendary drop probability")
            
            let total = abyssWeights.values.reduce(0.0, +)
            reporter.assertApprox(total, 100.0, tolerance: 0.00001, "B2.3: Abyss weights sum to exactly 100.0%")
        }
        
        // B2.4: 100% Duplicate Compensation Refund Across All Rarities
        do {
            reporter.assertEqual(CosmeticRarity.common.duplicateRefund, 150, "B2.4: Common duplicate compensation is 150 gold")
            reporter.assertEqual(CosmeticRarity.rare.duplicateRefund, 350, "B2.4: Rare duplicate compensation is 350 gold")
            reporter.assertEqual(CosmeticRarity.epic.duplicateRefund, 700, "B2.4: Epic duplicate compensation is 700 gold")
            reporter.assertEqual(CosmeticRarity.legendary.duplicateRefund, 1200, "B2.4: Legendary duplicate compensation is 1200 gold")
            
            let player = PlayerSaveState(initialGold: 5000)
            player.unlockedBalls.insert("rainbow")
            let crateResult = player.openCrate(tier: CrateTierDef.abyss, rolledRarity: .legendary, candidateSkinId: "rainbow")
            reporter.assertEqual(crateResult.duplicateRefund, 1200, "B2.4: Opening duplicate Rainbow skin yields 1200 gold refund")
            reporter.assertEqual(player.gold, 5000 - 3200 + 1200, "B2.4: Net gold after duplicate crate reflects cost minus refund")
        }
        
        // B2.5: Upgrades Max Level Cap (Level 3 Clamp)
        do {
            let player = PlayerSaveState(initialGold: 100000)
            // Buy Level 1
            reporter.assertTrue(player.buyUpgrade("battery"), "B2.5: Upgrade battery to level 1")
            // Buy Level 2
            reporter.assertTrue(player.buyUpgrade("battery"), "B2.5: Upgrade battery to level 2")
            // Buy Level 3
            reporter.assertTrue(player.buyUpgrade("battery"), "B2.5: Upgrade battery to level 3")
            reporter.assertEqual(player.upgrades["battery"], 3, "B2.5: Battery is at max level 3")
            
            // Attempt to buy Level 4 (must fail)
            let attemptLvl4 = player.buyUpgrade("battery")
            reporter.assertFalse(attemptLvl4, "B2.5: Buying battery upgrade beyond level 3 strictly rejected")
            reporter.assertEqual(player.upgrades["battery"], 3, "B2.5: Battery remains clamped at level 3")
        }
        
        // ====================================================================
        // FEATURE 3: REWARDS CENTER & DAILY PROGRESSION BOUNDARIES
        // ====================================================================
        
        // B3.1: Daily Claim Idempotency On Same Date
        do {
            var streak = LoginStreakModel(currentStreak: 3, lastClaimDate: "2026-10-09")
            reporter.assertFalse(streak.canClaim(today: "2026-10-09"), "B3.1: Claim rejected on same calendar date")
            let reward = streak.claim(today: "2026-10-09", isConsecutive: true)
            reporter.assertEqual(reward.reward, 0, "B3.1: Attempted duplicate claim awards 0 gold")
        }
        
        // B3.2: Non-Consecutive Day Login Streak Reset
        do {
            var streak = LoginStreakModel(currentStreak: 5, lastClaimDate: "2026-10-01")
            // Player logs in 8 days later (non-consecutive)
            let result = streak.claim(today: "2026-10-09", isConsecutive: false)
            reporter.assertEqual(result.day, 1, "B3.2: Missed day resets streak to Day 1")
            reporter.assertEqual(result.reward, 50 + (1 % 7) * 15, "B3.2: Reset day 1 reward formula applied")
        }
        
        // B3.3: Day 7 Jackpot & Rollover to Day 1
        do {
            var streak = LoginStreakModel(currentStreak: 6, lastClaimDate: "2026-10-08")
            let day7Result = streak.claim(today: "2026-10-09", isConsecutive: true)
            reporter.assertEqual(day7Result.day, 7, "B3.3: Consecutive claim reaches Day 7")
            reporter.assertEqual(day7Result.reward, 250, "B3.3: Day 7 awards 250 gold jackpot")
            
            // Next day rollover
            let rolloverResult = streak.claim(today: "2026-10-10", isConsecutive: true)
            reporter.assertEqual(rolloverResult.day, 1, "B3.3: Streak wraps cleanly to Day 1 after Day 7")
        }
        
        // B3.4: Quest Negative Increment & Target Cap Clamp
        do {
            var quest = DailyQuestModel(type: .q_bricks, progress: 40)
            quest.addProgress(-15) // Negative input
            reporter.assertEqual(quest.progress, 40, "B3.4: Negative progress increment strictly rejected")
            
            quest.addProgress(100) // Overshoot target (50)
            reporter.assertEqual(quest.progress, 50, "B3.4: Progress strictly clamped at target maximum (50)")
        }
        
        // B3.5: Simultaneous 5-Quest Claim Stress
        do {
            var quests = QuestType.allCases.map { DailyQuestModel(type: $0) }
            for i in 0..<quests.count {
                quests[i].addProgress(1000) // Max out all
                reporter.assertTrue(quests[i].canClaim, "B3.5: Quest \(quests[i].type) is ready to claim")
            }
            
            var totalClaimedGold = 0
            for i in 0..<quests.count {
                if quests[i].canClaim {
                    quests[i].isClaimed = true
                    totalClaimedGold += quests[i].type.goldReward
                }
            }
            // 100 + 80 + 120 + 90 + 150 = 540 gold
            reporter.assertEqual(totalClaimedGold, 540, "B3.5: All 5 quests simultaneously claimed award exactly 540 gold")
            
            // Second sweep: 0 gold claimable
            let secondSweep = quests.filter { $0.canClaim }.count
            reporter.assertEqual(secondSweep, 0, "B3.5: Second sweep has 0 claimable quests")
        }
        
        // ====================================================================
        // FEATURE 4: IN-GAME PHYSICS & ENGINE BOUNDARIES
        // ====================================================================
        
        // B4.1: Paddle Corner Boost Exact 22% Threshold
        do {
            let paddle = PaddlePhysics(x: 100.0, y: 700.0, width: 100.0, height: 18.0)
            // Just inside left corner: rel = 0.219 (hitX = 121.9)
            let insideLeft = paddle.cornerBoostMultiplier(hitX: 121.9)
            reporter.assertTrue(insideLeft.isCorner, "B4.1: Hit at rel = 0.219 is within corner boost zone")
            reporter.assertApprox(insideLeft.factor, 1.45, tolerance: 0.001, "B4.1: Factor is 1.45x")
            
            // Just outside left corner: rel = 0.221 (hitX = 122.1)
            let outsideLeft = paddle.cornerBoostMultiplier(hitX: 122.1)
            reporter.assertFalse(outsideLeft.isCorner, "B4.1: Hit at rel = 0.221 is outside corner boost zone")
            reporter.assertApprox(outsideLeft.factor, 1.0, tolerance: 0.001, "B4.1: Factor is 1.0x")
        }
        
        // B4.2: Paddle Right Corner Exact 78% Threshold
        do {
            let paddle = PaddlePhysics(x: 100.0, y: 700.0, width: 100.0, height: 18.0)
            // Just outside right corner: rel = 0.779 (hitX = 177.9)
            let outsideRight = paddle.cornerBoostMultiplier(hitX: 177.9)
            reporter.assertFalse(outsideRight.isCorner, "B4.2: Hit at rel = 0.779 is outside right corner zone")
            
            // Just inside right corner: rel = 0.781 (hitX = 178.1)
            let insideRight = paddle.cornerBoostMultiplier(hitX: 178.1)
            reporter.assertTrue(insideRight.isCorner, "B4.2: Hit at rel = 0.781 is within right corner zone")
            reporter.assertApprox(insideRight.factor, 1.45, tolerance: 0.001, "B4.2: Factor is 1.45x")
        }
        
        // B4.3: High Velocity Minkowski Collision Resolution
        do {
            // High velocity ball traveling towards brick
            var fastBall = BallPhysics(x: 100.0, y: 150.0, vx: 0.0, vy: -600.0, radius: 8.0)
            let hit = MinkowskiCollision.resolveBallBrick(ball: &fastBall, brickX: 80.0, brickY: 100.0, brickW: 60.0, brickH: 46.0)
            reporter.assertTrue(hit, "B4.3: Fast-moving ball correctly resolved by Minkowski difference")
            reporter.assertTrue(fastBall.vy > 0, "B4.3: Fast-moving ball rebounds with positive vy")
        }
        
        // B4.4: Touch Drag Extreme Coordinates Clamping
        do {
            var paddle = PaddlePhysics(x: 100.0, y: 700.0, width: 100.0, height: 18.0)
            // Touch at negative infinity (-10,000)
            paddle.trackTouch(touchX: -10000.0, tankWidth: 400.0)
            reporter.assertEqual(paddle.x, 0.0, "B4.4: Negative extreme touch clamps to minX = 0.0")
            
            // Touch at positive infinity (+50,000)
            paddle.trackTouch(touchX: 50000.0, tankWidth: 400.0)
            reporter.assertEqual(paddle.x, 300.0, "B4.4: Positive extreme touch clamps to maxX = 300.0")
        }
        
        // B4.5: Exact 40ms Audio Throttle Boundary
        do {
            let throttler = AudioThrottler()
            let t0 = 10.000
            reporter.assertTrue(throttler.shouldPlay(currentTime: t0), "B4.5: Initial sound at t=10.000s plays")
            
            // Sub-40ms: exactly 39ms later (t = 10.039)
            reporter.assertFalse(throttler.shouldPlay(currentTime: t0 + 0.039), "B4.5: Sound at +39ms strictly rejected")
            
            // Exactly 40ms or greater: 41ms later (t = 10.041)
            reporter.assertTrue(throttler.shouldPlay(currentTime: t0 + 0.041), "B4.5: Sound at +41ms successfully accepted")
        }
        
        reporter.endTier()
    }
}
