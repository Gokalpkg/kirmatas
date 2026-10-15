import Foundation

public struct Tier4_RealWorldScenarios {
    public static func runTests(reporter: TestReporter = .shared) {
        reporter.startTier("Tier 4: Real-World Application Scenarios (5 Player Sessions)")
        
        // ====================================================================
        // SCENARIO 1: NEW PLAYER ONBOARDING & DAY 1 GAMEPLAY SESSION
        // ====================================================================
        do {
            print("    [Scenario 1] New Player Onboarding & Day 1 Session")
            let player = PlayerSaveState(initialGold: 300)
            
            // 1. Check default loadout
            reporter.assertEqual(player.gold, 300, "S1: Initial gold is 300")
            reporter.assertEqual(player.equippedBall, "classic", "S1: Default ball equipped")
            reporter.assertEqual(player.equippedPaddle, "pclassic", "S1: Default paddle equipped")
            reporter.assertEqual(player.aquarium.unlockedFishIds.count, 2, "S1: Initial 2 starter fish in aquarium")
            
            // 2. Player visits Aquarium and feeds fish
            var pellet = FoodPellet(x: 180.0, y: 120.0)
            pellet.update(dt: 0.1)
            let feedResult = player.aquarium.feed(at: Date())
            reporter.assertEqual(feedResult.comebackBonusAwarded, 0, "S1: No comeback bonus needed for freshly fed starter fish")
            reporter.assertFalse(player.aquarium.isHungry(at: Date()), "S1: Starter fish are well fed")
            
            // 3. Player plays 1 match and destroys 35 bricks
            var paddle = PaddlePhysics(x: 150.0, y: 700.0, width: 100.0, height: 18.0)
            paddle.trackTouch(touchX: 180.0, tankWidth: 400.0)
            reporter.assertEqual(paddle.x, 130.0, "S1: Paddle tracks finger smoothly during gameplay")
            
            // Record match progress to daily quests
            if let bIdx = player.quests.firstIndex(where: { $0.type == .q_bricks }) {
                player.quests[bIdx].addProgress(35)
                reporter.assertEqual(player.quests[bIdx].progress, 35, "S1: Daily brick quest progress updated to 35")
            }
            if let mIdx = player.quests.firstIndex(where: { $0.type == .q_matches }) {
                player.quests[mIdx].addProgress(1)
                reporter.assertEqual(player.quests[mIdx].progress, 1, "S1: Daily match quest progress updated to 1")
            }
            
            // 4. Player claims Day 1 login streak
            let claim = player.loginStreak.claim(today: "2026-10-09", isConsecutive: true)
            player.addGold(claim.reward)
            reporter.assertEqual(claim.reward, 50 + (1 % 7) * 15, "S1: Day 1 streak claimed successfully")
            reporter.assertEqual(player.gold, 300 + claim.reward, "S1: Total gold updated with streak reward")
        }
        
        // ====================================================================
        // SCENARIO 2: IDLE FARMER 4-HOUR ECONOMY & COMEBACK SESSION
        // ====================================================================
        do {
            print("    [Scenario 2] Idle Farmer 4-Hour Economy & Comeback Session")
            let player = PlayerSaveState(initialGold: 1000)
            // Player has 12 fish species
            let twelveFish = Array(FishSpecies.all18Species.prefix(12)).map { $0.id }
            player.aquarium.unlockedFishIds = Set(twelveFish)
            
            let morningTime = Date(timeIntervalSince1970: 100000)
            player.aquarium.lastFedTime = morningTime
            
            // Player goes offline for 5.5 hours (19,800s)
            let returnTime = morningTime.addingTimeInterval(5.5 * 3600.0)
            
            // 1. Verify hunger alert
            let isHungry = player.aquarium.isHungry(at: returnTime)
            reporter.assertTrue(isHungry, "S2: Fish are hungry after 5.5 hours offline")
            
            // 2. Verify 4-hour accumulation cap halted gold at 4h
            let passiveGoldEarned = player.aquarium.calculateAccumulatedGold(from: morningTime, to: returnTime)
            let rate = player.aquarium.totalRatePerHour()
            let expectedMaxGold = Int(floor(rate * 4.0)) // Strictly 4 hours
            reporter.assertEqual(passiveGoldEarned, expectedMaxGold, "S2: Passive earnings capped at exact 4-hour window")
            
            player.aquarium.accumulatedBank = passiveGoldEarned
            let collected = player.aquarium.collectBank()
            player.addGold(collected)
            reporter.assertEqual(player.aquarium.accumulatedBank, 0, "S2: Aquarium bank cleared to 0 after collection")
            
            // 3. Player feeds starving fish and receives comeback bonus
            let feedResult = player.aquarium.feed(at: returnTime)
            reporter.assertTrue(feedResult.hungerCleared, "S2: Feeding hungry fish clears hunger")
            reporter.assertEqual(feedResult.comebackBonusAwarded, 20, "S2: Player receives +20 gold comeback bonus")
            
            player.addGold(feedResult.comebackBonusAwarded)
            reporter.assertEqual(player.gold, 1000 + expectedMaxGold + 20, "S2: Player balance reflects passive gold + comeback bonus")
            reporter.assertFalse(player.aquarium.isHungry(at: returnTime), "S2: TopRewardsBar hunger alert dismissed")
        }
        
        // ====================================================================
        // SCENARIO 3: SHOP SPREE, CRATE OPENING & COSMETIC CUSTOMIZER
        // ====================================================================
        do {
            print("    [Scenario 3] Shop Spree, Crate Opening & Cosmetic Customizer")
            let player = PlayerSaveState(initialGold: 8000)
            
            // 1. Buy Wood Crate (900)
            let woodDrop = player.openCrate(tier: CrateTierDef.wood, rolledRarity: .common, candidateSkinId: "classic")
            reporter.assertEqual(woodDrop.duplicateRefund, 150, "S3: Duplicate starter ball yields 150 gold refund")
            
            // 2. Buy Coral Crate (1800) -> unlocks rare 'plazma'
            let coralDrop = player.openCrate(tier: CrateTierDef.coral, rolledRarity: .rare, candidateSkinId: "plazma")
            reporter.assertEqual(coralDrop.duplicateRefund, 0, "S3: New skin plazma unlocked with 0 refund")
            reporter.assertTrue(player.unlockedBalls.contains("plazma"), "S3: 'plazma' ball skin added to inventory")
            
            // 3. Buy Abyss Crate (3200) -> unlocks legendary 'isilti'
            let abyssDrop = player.openCrate(tier: CrateTierDef.abyss, rolledRarity: .legendary, candidateSkinId: "isilti")
            reporter.assertEqual(abyssDrop.duplicateRefund, 0, "S3: Legendary 'isilti' ball unlocked")
            reporter.assertTrue(player.unlockedBalls.contains("isilti"), "S3: 'isilti' ball skin added to inventory")
            
            // 4. Buy Battery upgrade level 1 (900)
            let boughtBattery = player.buyUpgrade("battery")
            reporter.assertTrue(boughtBattery, "S3: Battery level 1 acquired")
            
            // 5. Equip custom cosmetics
            player.equippedBall = "isilti"
            player.unlockedPaddles.insert("ppink")
            player.equippedPaddle = "ppink"
            player.unlockedTrails.insert("spark")
            player.equippedTrail = "spark"
            player.unlockedBackgrounds.insert("bg_matrix")
            player.equippedBackground = "bg_matrix"
            
            reporter.assertEqual(player.equippedBall, "isilti", "S3: Equipped ball is 'isilti'")
            reporter.assertEqual(player.equippedPaddle, "ppink", "S3: Equipped paddle is 'ppink'")
            reporter.assertEqual(player.equippedTrail, "spark", "S3: Equipped trail is 'spark'")
            reporter.assertEqual(player.equippedBackground, "bg_matrix", "S3: Equipped background is 'bg_matrix'")
        }
        
        // ====================================================================
        // SCENARIO 4: ARCADE MASTER FAST MATCH, CORNER BOOSTS & SFX THROTTLING
        // ====================================================================
        do {
            print("    [Scenario 4] Arcade Master Fast Match & Corner Boosts")
            let player = PlayerSaveState()
            player.equippedBall = "rainbow"
            
            var ball = BallPhysics(x: 110.0, y: 690.0, vx: 200.0, vy: 350.0, radius: 8.0)
            let paddle = PaddlePhysics(x: 100.0, y: 700.0, width: 100.0, height: 18.0)
            
            // Ball strikes left corner of paddle (hitX = 110 -> rel = 0.10)
            let cornerBoost = paddle.cornerBoostMultiplier(hitX: ball.x)
            reporter.assertTrue(cornerBoost.isCorner, "S4: Fast arcade ball strikes paddle corner")
            
            // Apply 1.45x boost factor to ball speed
            let initialSpeed = ball.speed
            ball.vx = -ball.vx * cornerBoost.factor
            ball.vy = -ball.vy * cornerBoost.factor
            let boostedSpeed = ball.speed
            reporter.assertApprox(boostedSpeed, initialSpeed * 1.45, tolerance: 0.01, "S4: Ball speed increased by 1.45x after corner boost")
            
            // Ball hits brick cluster: 4 bricks in 25 milliseconds
            let throttler = AudioThrottler()
            var sfxTriggers = 0
            for dt in [0.000, 0.008, 0.016, 0.024] {
                if throttler.shouldPlay(currentTime: dt) {
                    sfxTriggers += 1
                }
            }
            reporter.assertEqual(sfxTriggers, 1, "S4: 40ms audio throttle prevents ear fatigue, playing only 1 sound during 25ms cascade")
            
            // Player wins match and updates clutch quest
            if let cIdx = player.quests.firstIndex(where: { $0.type == .q_clutch }) {
                player.quests[cIdx].addProgress(1)
                reporter.assertTrue(player.quests[cIdx].isCompleted, "S4: Clutch win completes clutch quest")
            }
        }
        
        // ====================================================================
        // SCENARIO 5: 7-DAY VETERAN FULL PROGRESSION & MAX UPGRADES
        // ====================================================================
        do {
            print("    [Scenario 5] 7-Day Veteran Full Progression & Max Upgrades")
            let player = PlayerSaveState(initialGold: 30000)
            
            // 1. Simulate 7 consecutive daily logins
            var totalStreakGold = 0
            for day in 1...7 {
                let todayStr = "2026-10-0\(day)"
                let claim = player.loginStreak.claim(today: todayStr, isConsecutive: true)
                totalStreakGold += claim.reward
            }
            player.addGold(totalStreakGold)
            reporter.assertEqual(player.loginStreak.currentStreak, 7, "S5: Veteran achieves 7-day login streak")
            reporter.assertTrue(totalStreakGold > 500, "S5: 7-day streak rewards total exceeds 500 gold")
            
            // 2. Max out all 3 permanent upgrades (Battery 3, Magnet 3, Luck 3)
            for _ in 1...3 { _ = player.buyUpgrade("battery") }
            for _ in 1...3 { _ = player.buyUpgrade("magnet") }
            for _ in 1...3 { _ = player.buyUpgrade("luck") }
            
            reporter.assertEqual(player.upgrades["battery"], 3, "S5: Battery maxed to Level 3")
            reporter.assertEqual(player.upgrades["magnet"], 3, "S5: Magnet maxed to Level 3")
            reporter.assertEqual(player.upgrades["luck"], 3, "S5: Luck maxed to Level 3")
            
            // 3. Unlock all 18 fish species in the aquarium
            player.aquarium.unlockedFishIds = Set(FishSpecies.all18Species.map { $0.id })
            reporter.assertEqual(player.aquarium.unlockedFishIds.count, 18, "S5: Veteran owns all 18 fish species")
            
            // 4. Complete and claim all 5 daily quests in a single day
            for i in 0..<player.quests.count {
                player.quests[i].addProgress(100)
                reporter.assertTrue(player.quests[i].isCompleted, "S5: Quest \(player.quests[i].type) is completed")
                player.addGold(player.quests[i].type.goldReward)
                player.quests[i].isClaimed = true
            }
            
            let allClaimed = player.quests.allSatisfy { $0.isClaimed }
            reporter.assertTrue(allClaimed, "S5: All 5 daily quests successfully claimed")
            reporter.assertTrue(player.gold > 0, "S5: Veteran player state fully consistent and solvent")
        }
        
        reporter.endTier()
    }
}
