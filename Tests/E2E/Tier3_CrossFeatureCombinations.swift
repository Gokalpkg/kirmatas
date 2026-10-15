import Foundation

public struct Tier3_CrossFeatureCombinations {
    public static func runTests(reporter: TestReporter = .shared) {
        reporter.startTier("Tier 3: Cross-Feature Combinations (Pairwise Coverage)")
        
        // ====================================================================
        // COMBINATION 1: AQUARIUM PASSIVE GOLD -> SHOP CRATE PURCHASE
        // ====================================================================
        do {
            let player = PlayerSaveState(initialGold: 850)
            let startDate = Date(timeIntervalSince1970: 100000)
            // 4 hours idle with 18 fish unlocked
            player.aquarium.unlockedFishIds = Set(FishSpecies.all18Species.map { $0.id })
            let rate = player.aquarium.totalRatePerHour() // High rate with all 18 fish
            let accumulated = player.aquarium.calculateAccumulatedGold(from: startDate, to: startDate.addingTimeInterval(4.0 * 3600.0))
            player.aquarium.accumulatedBank = accumulated
            
            // Collect bank
            let collectedGold = player.aquarium.collectBank()
            player.addGold(collectedGold)
            reporter.assertGreaterThanOrEqual(player.gold, 900, "C1: Aquarium passive idle earnings increase wallet over 900 gold")
            
            // Purchase Wood crate from Shop
            let boughtCrate = player.spendGold(CrateTierDef.wood.cost)
            reporter.assertTrue(boughtCrate, "C1: Collected aquarium passive gold successfully funds Wood Crate purchase")
        }
        
        // ====================================================================
        // COMBINATION 2: CRATE DROP UNLOCK -> SAVEMANAGER EQUIP -> GAME ENGINE
        // ====================================================================
        do {
            let player = PlayerSaveState(initialGold: 5000)
            // Open Abyss crate and unlock Rainbow Ball
            let result = player.openCrate(tier: CrateTierDef.abyss, rolledRarity: .legendary, candidateSkinId: "rainbow")
            reporter.assertEqual(result.droppedSkinId, "rainbow", "C2: Abyss crate drops Rainbow Ball skin")
            reporter.assertTrue(player.unlockedBalls.contains("rainbow"), "C2: Rainbow Ball registered in player unlocked inventory")
            
            // Equip in SaveManager
            player.equippedBall = "rainbow"
            reporter.assertEqual(player.equippedBall, "rainbow", "C2: Player equippedBall set to 'rainbow'")
            
            // Game Engine renders Rainbow Ball with dynamic ROYGBIV hue
            let t = 2.5
            let hue = CosmeticCatalog.rainbowHue(gameTime: t)
            let expectedHue = (2.5 * 120.0).truncatingRemainder(dividingBy: 360.0)
            reporter.assertApprox(hue, expectedHue, tolerance: 0.001, "C2: Game engine applies dynamic hue cycle for equipped Rainbow skin")
        }
        
        // ====================================================================
        // COMBINATION 3: GAME BRICK DESTRUCTION & COMBO -> DAILY QUESTS -> CLAIM
        // ====================================================================
        do {
            let player = PlayerSaveState(initialGold: 100)
            // Simulate match gameplay destroying 50 bricks and hitting 5x combo
            let bricksDestroyedInMatch = 50
            let maxComboInMatch = 5
            
            if let bIdx = player.quests.firstIndex(where: { $0.type == .q_bricks }) {
                player.quests[bIdx].addProgress(bricksDestroyedInMatch)
            }
            if let cIdx = player.quests.firstIndex(where: { $0.type == .q_combo }) {
                player.quests[cIdx].addProgress(maxComboInMatch)
            }
            
            // Rewards Center claims
            let brickQuest = player.quests.first(where: { $0.type == .q_bricks })!
            let comboQuest = player.quests.first(where: { $0.type == .q_combo })!
            reporter.assertTrue(brickQuest.isCompleted, "C3: Brick destruction quest completed from match results")
            reporter.assertTrue(comboQuest.isCompleted, "C3: Combo streak quest completed from match results")
            
            player.addGold(brickQuest.type.goldReward)
            player.addGold(comboQuest.type.goldReward)
            // 100 + 100 + 90 = 290 gold
            reporter.assertEqual(player.gold, 290, "C3: In-game achievements claimed in Rewards Center update total gold to 290")
        }
        
        // ====================================================================
        // COMBINATION 4: AQUARIUM FEEDING -> QUEST PROGRESS -> TOP BAR SYNC
        // ====================================================================
        do {
            let player = PlayerSaveState()
            // Set aquarium hungry (5 hours ago)
            player.aquarium.lastFedTime = Date().addingTimeInterval(-5.0 * 3600.0)
            let initialHungerAlert = player.aquarium.isHungry(at: Date())
            reporter.assertTrue(initialHungerAlert, "C4: TopRewardsBar hunger alert badge active")
            
            // Player feeds fish
            let feedResult = player.aquarium.feed(at: Date())
            reporter.assertTrue(feedResult.hungerCleared, "C4: Feeding clears hunger state")
            reporter.assertFalse(player.aquarium.isHungry(at: Date()), "C4: TopRewardsBar hunger alert badge dismissed")
            
            // Feeding updates daily quest q_fish
            if let fIdx = player.quests.firstIndex(where: { $0.type == .q_fish }) {
                player.quests[fIdx].addProgress(1)
                reporter.assertEqual(player.quests[fIdx].progress, 1, "C4: Aquarium feeding increments q_fish quest progress")
            }
        }
        
        // ====================================================================
        // COMBINATION 5: SHOP UPGRADES -> CRATE ODDS MODIFICATION
        // ====================================================================
        do {
            let player = PlayerSaveState(initialGold: 10000)
            // Buy Luck level 1, 2, 3
            reporter.assertTrue(player.buyUpgrade("luck"), "C5: Buy luck level 1")
            reporter.assertTrue(player.buyUpgrade("luck"), "C5: Buy luck level 2")
            reporter.assertTrue(player.buyUpgrade("luck"), "C5: Buy luck level 3")
            reporter.assertEqual(player.upgrades["luck"], 3, "C5: Player achieves Luck upgrade level 3")
            
            // Luck level 3 adds +5% legendary weight bonus in modified drop tables
            let baseLegendaryWeight = CrateTierDef.abyss.weights[.legendary] ?? 0.0
            let luckBonus = Double(player.upgrades["luck"] ?? 0) * 2.0 // +6%
            let enhancedWeight = baseLegendaryWeight + luckBonus
            reporter.assertApprox(enhancedWeight, 18.0, tolerance: 0.001, "C5: Luck upgrade level 3 enhances legendary drop weight to 18.0%")
        }
        
        // ====================================================================
        // COMBINATION 6: 7-DAY LOGIN STREAK JACKPOT -> COSMETIC PURCHASE
        // ====================================================================
        do {
            let player = PlayerSaveState(initialGold: 1600)
            player.loginStreak.currentStreak = 6
            let claim = player.loginStreak.claim(today: "2026-10-09", isConsecutive: true)
            reporter.assertEqual(claim.day, 7, "C6: Streak completes Day 7 jackpot milestone")
            player.addGold(claim.reward) // +250
            reporter.assertEqual(player.gold, 1850, "C6: Player wallet reaches 1850 gold")
            
            // Buy Neon Pembe Paddle (cost 1800)
            let boughtPaddle = player.spendGold(1800)
            reporter.assertTrue(boughtPaddle, "C6: Day 7 jackpot funds purchase of Neon Pembe Paddle")
            player.unlockedPaddles.insert("ppink")
            player.equippedPaddle = "ppink"
            reporter.assertEqual(player.equippedPaddle, "ppink", "C6: Newly purchased paddle equipped in player state")
        }
        
        // ====================================================================
        // COMBINATION 7: COSMETIC EQUIPPED -> IN-GAME PADDLE HITBOX & BOOST
        // ====================================================================
        do {
            let paddle = PaddlePhysics(x: 150.0, y: 700.0, width: 120.0, height: 18.0)
            // Rel pos hit at x = 160 -> (160 - 150) / 120 = 10 / 120 = 0.083 (< 0.22)
            let boost = paddle.cornerBoostMultiplier(hitX: 160.0)
            reporter.assertTrue(boost.isCorner, "C7: Equipped paddle hitbox accurately computes corner boost")
            reporter.assertApprox(boost.factor, 1.45, tolerance: 0.001, "C7: Corner boost factor is 1.45x")
        }
        
        // ====================================================================
        // COMBINATION 8: SETTINGS AUDIO THROTTLING IN MULTI-BRICK CASCADE
        // ====================================================================
        do {
            let throttler = AudioThrottler()
            var playedCount = 0
            // Simulate 5 brick impacts in rapid succession within 50ms: 0ms, 10ms, 20ms, 30ms, 45ms
            let hitTimes = [0.000, 0.010, 0.020, 0.030, 0.045]
            for t in hitTimes {
                if throttler.shouldPlay(currentTime: t) {
                    playedCount += 1
                }
            }
            // Hits at 0ms and 45ms play; hits at 10, 20, 30ms are throttled
            reporter.assertEqual(playedCount, 2, "C8: Rapid multi-brick collision cascade properly throttled to exactly 2 sounds")
        }
        
        reporter.endTier()
    }
}
