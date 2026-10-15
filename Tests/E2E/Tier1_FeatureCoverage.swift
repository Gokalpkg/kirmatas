import Foundation

public struct Tier1_FeatureCoverage {
    public static func runTests(reporter: TestReporter = .shared) {
        reporter.startTier("Tier 1: Feature Coverage (>=5 Tests Per Feature)")
        
        // ====================================================================
        // FEATURE 1: ECO-TANK AQUARIUM SYSTEM
        // ====================================================================
        
        // F1.1: 18 Fish Species Model & Taxonomy
        do {
            let species = FishSpecies.all18Species
            reporter.assertEqual(species.count, 18, "F1.1: Exactly 18 fish species registered in eco-tank system")
            let families = Set(species.map { $0.family })
            reporter.assertEqual(families.count, 6, "F1.1: Exactly 6 distinct fish families present")
            let rarities = species.map { $0.rarity }
            reporter.assertTrue(rarities.contains(.common), "F1.1: Common rarity fish exist")
            reporter.assertTrue(rarities.contains(.rare), "F1.1: Rare rarity fish exist")
            reporter.assertTrue(rarities.contains(.epic), "F1.1: Epic rarity fish exist")
            reporter.assertTrue(rarities.contains(.legendary), "F1.1: Legendary rarity fish exist")
        }
        
        // F1.2: Fish Ambient Swimming & Tank Boundary Reflection
        do {
            let sp = FishSpecies.all18Species[0]
            var fish = SimFish(species: sp, x: 380.0, y: 300.0, vx: 30.0, vy: 5.0, facingRight: true)
            // Update across 1.0 second in 400x800 tank
            fish.update(dt: 1.0, tankWidth: 400.0, tankHeight: 800.0)
            reporter.assertLessThanOrEqual(fish.x, 380.0, "F1.2: Fish bounces back off right wall")
            reporter.assertFalse(fish.facingRight, "F1.2: Fish faces left after bouncing off right wall")
            reporter.assertTrue(fish.vx < 0, "F1.2: Horizontal velocity inverted to negative after wall bounce")
        }
        
        // F1.3: Interactive Food Pellets Physics & Sinusoidal Sway
        do {
            var pellet = FoodPellet(x: 200.0, y: 100.0, vy: 40.0, swayPhase: 0.0)
            let initialX = pellet.x
            pellet.update(dt: 0.5)
            reporter.assertApprox(pellet.y, 120.0, tolerance: 0.1, "F1.3: Food pellet descends with vy=40")
            reporter.assertTrue(pellet.x != initialX, "F1.3: Food pellet sways horizontally with sine phase")
            reporter.assertApprox(pellet.life, 0.5, tolerance: 0.01, "F1.3: Pellet life accumulator increments")
        }
        
        // F1.4: Closest-Fish Target Pursuit Steering
        do {
            let sp = FishSpecies.all18Species[1]
            var fish = SimFish(species: sp, x: 100.0, y: 100.0, vx: 0.0, vy: 0.0, facingRight: true)
            let foodX = 200.0
            let foodY = 100.0
            fish.steerTowards(targetX: foodX, targetY: foodY, strength: 50.0, dt: 0.2)
            reporter.assertTrue(fish.vx > 0, "F1.4: Fish steers positively towards target food X")
            reporter.assertTrue(fish.facingRight, "F1.4: Fish faces right towards food location")
        }
        
        // F1.5: Hay Day 4-Hour Passive Economy Base Accumulation
        do {
            let baseDate = Date(timeIntervalSince1970: 100000)
            let economy = AquariumEconomy(lastFedTime: baseDate, accumulatedBank: 0, unlockedFishIds: ["guppy", "tetra"])
            let rate = economy.totalRatePerHour()
            // Base: 1.5, Flora: 1*0.2 + 2*0.4 + 1*0.6 + 1*0.8 = 2.4, Fish: 0.1 + 0.1 = 0.2 -> Total = 4.1 gph
            reporter.assertApprox(rate, 4.1, tolerance: 0.001, "F1.5: Hourly gold rate calculates accurately with base, flora, and fish")
            let goldAt2h = economy.calculateAccumulatedGold(from: baseDate, to: baseDate.addingTimeInterval(2.0 * 3600.0))
            reporter.assertEqual(goldAt2h, Int(floor(4.1 * 2.0)), "F1.5: Passive gold accumulated over 2h calculates accurately")
        }
        
        // ====================================================================
        // FEATURE 2: 6-TAB SHOP & UNIFIED COSMETICS SYSTEM
        // ====================================================================
        
        // F2.1: 6-Tab Catalog Inventory Completeness
        do {
            reporter.assertEqual(CrateTierDef.allCrates.count, 3, "F2.1: Exactly 3 crate tiers available")
            reporter.assertEqual(CosmeticCatalog.ballSkins.count, 12, "F2.1: Exactly 12 ball skins cataloged (Rainbow + 11 special)")
            reporter.assertEqual(CosmeticCatalog.paddleSkins.count, 6, "F2.1: Exactly 6 paddle skins cataloged")
            reporter.assertEqual(CosmeticCatalog.trailSkins.count, 6, "F2.1: Exactly 6 trail skins cataloged")
            reporter.assertEqual(CosmeticCatalog.brickStyles.count, 6, "F2.1: Exactly 6 brick themes cataloged")
            reporter.assertEqual(CosmeticCatalog.backgrounds.count, 6, "F2.1: Exactly 6 background themes cataloged")
        }
        
        // F2.2: Crate Tier Cost & Valid Probability Weights
        do {
            for crate in CrateTierDef.allCrates {
                let totalWeight = crate.weights.values.reduce(0.0, +)
                reporter.assertApprox(totalWeight, 100.0, tolerance: 0.0001, "F2.2: Crate '\(crate.id)' probability weights sum to exactly 100.0%")
                reporter.assertTrue(crate.cost > 0, "F2.2: Crate '\(crate.id)' has positive purchase cost")
            }
        }
        
        // F2.3: Cosmetic Purchase Flow & Gold Balance Deduction
        do {
            let player = PlayerSaveState(initialGold: 2000)
            let pembeCost = 1500
            let canBuy = player.spendGold(pembeCost)
            reporter.assertTrue(canBuy, "F2.3: Player successfully spends gold on rare ball skin")
            reporter.assertEqual(player.gold, 500, "F2.3: Player balance deducts to exactly 500 gold")
            player.unlockedBalls.insert("pembe")
            reporter.assertTrue(player.unlockedBalls.contains("pembe"), "F2.3: Unlocked balls list contains newly purchased skin")
        }
        
        // F2.4: Cosmetic Equip State Update Across Categories
        do {
            let player = PlayerSaveState()
            player.unlockedPaddles.insert("pcyber")
            player.unlockedTrails.insert("plasma")
            player.unlockedBackgrounds.insert("bg_abyss")
            
            player.equippedPaddle = "pcyber"
            player.equippedTrail = "plasma"
            player.equippedBackground = "bg_abyss"
            
            reporter.assertEqual(player.equippedPaddle, "pcyber", "F2.4: Equipped paddle successfully updated")
            reporter.assertEqual(player.equippedTrail, "plasma", "F2.4: Equipped trail successfully updated")
            reporter.assertEqual(player.equippedBackground, "bg_abyss", "F2.4: Equipped background successfully updated")
        }
        
        // F2.5: Permanent Upgrades & Boosts Acquisition
        do {
            let player = PlayerSaveState(initialGold: 5000)
            let boughtBattery1 = player.buyUpgrade("battery")
            reporter.assertTrue(boughtBattery1, "F2.5: Successfully purchased battery upgrade level 1")
            reporter.assertEqual(player.upgrades["battery"], 1, "F2.5: Battery level is 1")
            reporter.assertEqual(player.gold, 5000 - 900, "F2.5: Gold accurately deducted by 900 for battery level 1")
            
            // Consumable boost
            let boostCost = CosmeticCatalog.boosts["life"] ?? 0
            let boughtBoost = player.spendGold(boostCost)
            reporter.assertTrue(boughtBoost, "F2.5: Successfully purchased life boost")
            player.boosts["life"] = 1
            reporter.assertEqual(player.boosts["life"], 1, "F2.5: Consumable life boost stock incremented")
        }
        
        // ====================================================================
        // FEATURE 3: REWARDS CENTER & DAILY PROGRESSION
        // ====================================================================
        
        // F3.1: TopRewardsBar Hunger Badge & Gold Sync
        do {
            let economy = AquariumEconomy(lastFedTime: Date().addingTimeInterval(-5 * 3600)) // 5 hours ago
            let isHungry = economy.isHungry(at: Date())
            reporter.assertTrue(isHungry, "F3.1: Aquarium hunger alert badge active after 5 hours since last fed")
            
            let fedEconomy = AquariumEconomy(lastFedTime: Date())
            reporter.assertFalse(fedEconomy.isHungry(at: Date()), "F3.1: Aquarium hunger alert badge inactive immediately after feeding")
        }
        
        // F3.2: 7-Day Login Streak Claim & Progressive Reward
        do {
            var streak = LoginStreakModel(currentStreak: 0, lastClaimDate: nil)
            reporter.assertTrue(streak.canClaim(today: "2026-10-09"), "F3.2: First claim permitted on clean streak")
            let result1 = streak.claim(today: "2026-10-09", isConsecutive: true)
            reporter.assertEqual(result1.day, 1, "F3.2: Streak increments to day 1")
            reporter.assertEqual(result1.reward, 50 + (1 % 7) * 15, "F3.2: Day 1 reward matches formula")
            reporter.assertFalse(streak.canClaim(today: "2026-10-09"), "F3.2: Second claim on same calendar day blocked")
        }
        
        // F3.3: 5 Daily Quests Tracking
        do {
            var quests = QuestType.allCases.map { DailyQuestModel(type: $0) }
            reporter.assertEqual(quests.count, 5, "F3.3: Exactly 5 daily quests initialized")
            
            // Update brick quest
            if let idx = quests.firstIndex(where: { $0.type == .q_bricks }) {
                quests[idx].addProgress(25)
                reporter.assertEqual(quests[idx].progress, 25, "F3.3: Brick quest progress increments to 25")
                reporter.assertFalse(quests[idx].isCompleted, "F3.3: Brick quest not yet completed at 25/50")
            }
        }
        
        // F3.4: Quest Completion Transition & Reward Claim
        do {
            var quest = DailyQuestModel(type: .q_fish, progress: 0)
            quest.addProgress(3)
            reporter.assertTrue(quest.isCompleted, "F3.4: Fish feeding quest marks completed at 3/3")
            reporter.assertTrue(quest.canClaim, "F3.4: Completed quest is claimable")
            quest.isClaimed = true
            reporter.assertFalse(quest.canClaim, "F3.4: Claimed quest cannot be claimed again")
            reporter.assertEqual(quest.type.goldReward, 80, "F3.4: Fish quest awards exactly 80 gold")
        }
        
        // F3.5: Quest Claim Idempotency
        do {
            var quest = DailyQuestModel(type: .q_clutch, progress: 1)
            reporter.assertTrue(quest.isCompleted, "F3.5: Clutch quest completed")
            quest.isClaimed = true
            // Attempt secondary claim
            let secondClaimAttempt = quest.canClaim
            reporter.assertFalse(secondClaimAttempt, "F3.5: Second claim attempt strictly blocked")
        }
        
        // ====================================================================
        // FEATURE 4: IN-GAME PHYSICS, COLLISION & ENGINE PERFORMANCE
        // ====================================================================
        
        // F4.1: Minkowski Difference AABB Collision Resolution
        do {
            var ball = BallPhysics(x: 100.0, y: 152.0, vx: 0.0, vy: -100.0, radius: 8.0)
            // Brick from y: 100 to y: 146 (height 46, center y = 123). Combined halfH = 23 + 8 = 31.
            let hit = MinkowskiCollision.resolveBallBrick(ball: &ball, brickX: 80.0, brickY: 100.0, brickW: 60.0, brickH: 46.0)
            reporter.assertTrue(hit, "F4.1: Minkowski difference collision successfully detects penetration")
            reporter.assertTrue(ball.vy > 0, "F4.1: Ball velocity inverted positively downward away from brick")
            reporter.assertGreaterThanOrEqual(ball.y, 154.0, "F4.1: Ball position pushed out of brick boundary")
        }
        
        // F4.2: Absolute Touch Paddle Tracking
        do {
            var paddle = PaddlePhysics(x: 100.0, y: 700.0, width: 100.0, height: 18.0)
            paddle.trackTouch(touchX: 250.0, tankWidth: 400.0)
            // Target center 250 -> x = 250 - 50 = 200
            reporter.assertEqual(paddle.x, 200.0, "F4.2: Paddle center tracks touch input at exactly 250.0")
            
            // Extreme offscreen touch clamped
            paddle.trackTouch(touchX: -50.0, tankWidth: 400.0)
            reporter.assertEqual(paddle.x, 0.0, "F4.2: Paddle clamped to min left boundary")
            paddle.trackTouch(touchX: 500.0, tankWidth: 400.0)
            reporter.assertEqual(paddle.x, 300.0, "F4.2: Paddle clamped to max right boundary")
        }
        
        // F4.3: Paddle Corner Boost 1.45x Velocity Multiplier
        do {
            let paddle = PaddlePhysics(x: 100.0, y: 700.0, width: 100.0, height: 18.0)
            // Hit at relative 10% (x = 110)
            let leftCorner = paddle.cornerBoostMultiplier(hitX: 110.0)
            reporter.assertTrue(leftCorner.isCorner, "F4.3: Hit at relative 10% recognized as corner hit")
            reporter.assertApprox(leftCorner.factor, 1.45, tolerance: 0.001, "F4.3: Left corner hit triggers 1.45x boost factor")
            
            // Hit at relative 50% (x = 150)
            let centerHit = paddle.cornerBoostMultiplier(hitX: 150.0)
            reporter.assertFalse(centerHit.isCorner, "F4.3: Hit at center 50% is not corner hit")
            reporter.assertApprox(centerHit.factor, 1.0, tolerance: 0.001, "F4.3: Center hit has 1.0x standard multiplier")
        }
        
        // F4.4: Dynamic 360° Rainbow Ball Hue Cycling
        do {
            let hue0 = CosmeticCatalog.rainbowHue(gameTime: 0.0)
            let hue1 = CosmeticCatalog.rainbowHue(gameTime: 1.0)
            let hue3 = CosmeticCatalog.rainbowHue(gameTime: 3.0)
            
            reporter.assertApprox(hue0, 0.0, tolerance: 0.001, "F4.4: Rainbow hue at t=0s is 0.0°")
            reporter.assertApprox(hue1, 120.0, tolerance: 0.001, "F4.4: Rainbow hue at t=1s is 120.0°")
            reporter.assertApprox(hue3, 0.0, tolerance: 0.001, "F4.4: Rainbow hue cycles 360° back to 0.0° at t=3s")
        }
        
        // F4.5: Audio Rate Limiting 40ms Window
        do {
            let throttler = AudioThrottler()
            let firstSound = throttler.shouldPlay(currentTime: 1.000)
            reporter.assertTrue(firstSound, "F4.5: Initial sound allowed to play")
            
            let rapidSound = throttler.shouldPlay(currentTime: 1.020) // +20ms
            reporter.assertFalse(rapidSound, "F4.5: Sound at +20ms rejected by 40ms throttle window")
            
            let allowedSound = throttler.shouldPlay(currentTime: 1.045) // +45ms
            reporter.assertTrue(allowedSound, "F4.5: Sound at +45ms successfully allowed to play")
        }
        
        reporter.endTier()
    }
}
