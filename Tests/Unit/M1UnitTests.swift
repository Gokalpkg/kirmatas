import Foundation
import SwiftUI

// MARK: - Minimal Test Assertions
func assertTest(_ condition: Bool, _ message: String) {
    if condition {
        print("    ✓ [PASS] \(message)")
    } else {
        print("    ✗ [FAIL] \(message)")
        exit(1)
    }
}

func assertEqual<T: Equatable>(_ a: T, _ b: T, _ message: String) {
    if a == b {
        print("    ✓ [PASS] \(message)")
    } else {
        print("    ✗ [FAIL] \(message) -> Expected: \(b), got: \(a)")
        exit(1)
    }
}

@main
struct M1UnitTestsRunner {
    static func main() {
        print("======================================================================")
        print("  RUNNING: Milestone 1 Native Models, Audio & Persistence Tests")
        print("======================================================================")

        // --------------------------------------------------------------------
        // TEST SUITE 1: Cosmetics Models (Cosmetics.swift)
        // --------------------------------------------------------------------
        print("\n--- [Suite 1] Cosmetics.swift Verification ---")

        // 1.1 Crates
        let crates = Cosmetics.allCrates
        assertEqual(crates.count, 3, "Cosmetics: Exactly 3 crates defined")
        assertEqual(crates[0].id, "wood", "Cosmetics: Wood crate ID matches")
        assertEqual(crates[0].cost, 900, "Cosmetics: Wood crate cost 900")
        assertEqual(crates[1].id, "coral", "Cosmetics: Coral crate ID matches")
        assertEqual(crates[1].cost, 1800, "Cosmetics: Coral crate cost 1800")
        assertEqual(crates[2].id, "abyss", "Cosmetics: Abyss crate ID matches")
        assertEqual(crates[2].cost, 3200, "Cosmetics: Abyss crate cost 3200")

        // 1.2 Ball Skins
        let ballSkins = Cosmetics.allBallSkins
        assertEqual(ballSkins.count, 12, "Cosmetics: Exactly 12 ball skins cataloged")
        assertTest(ballSkins.contains(where: { $0.id == "rainbow" && $0.isRainbow }), "Cosmetics: Rainbow ball skin is present and flagged as isRainbow")
        assertTest(ballSkins.contains(where: { $0.id == "classic" && $0.cost == 0 }), "Cosmetics: Classic free starter skin is present")
        let rainbowSkin = Cosmetics.ballSkin(byId: "rainbow")
        let hueAt0 = rainbowSkin.currentMainColor(time: 0.0)
        let hueAt1 = rainbowSkin.currentMainColor(time: 1.0)
        assertTest(hueAt0 != hueAt1, "Cosmetics: Rainbow ball dynamically cycles colors over time")
        assertEqual(Cosmetics.rainbowHue(gameTime: 3.0), (3.0 * 120.0).truncatingRemainder(dividingBy: 360.0), "Cosmetics: rainbowHue formula matches 360-degree cycle")

        // 1.3 Paddles
        let paddles = Cosmetics.allPaddleSkins
        assertEqual(paddles.count, 6, "Cosmetics: Exactly 6 paddle skins cataloged")
        assertEqual(paddles[0].id, "pclassic", "Cosmetics: Starter paddle is pclassic")
        assertTest(paddles.contains(where: { $0.id == "pgold" && $0.rarity == .legendary }), "Cosmetics: Royal gold paddle is legendary")

        // 1.4 Trails
        let trails = Cosmetics.allTrailSkins
        assertEqual(trails.count, 6, "Cosmetics: Exactly 6 trail skins cataloged")
        assertEqual(trails[0].length, 6, "Cosmetics: Starter trail length 6")
        assertEqual(trails[5].length, 32, "Cosmetics: Cosmic plasma trail length 32")

        // 1.5 Bricks
        let bricks = Cosmetics.allBrickSkins
        assertEqual(bricks.count, 6, "Cosmetics: Exactly 6 brick themes cataloged")
        assertEqual(bricks[0].id, "brick_classic", "Cosmetics: Starter brick theme is brick_classic")

        // 1.6 Backgrounds
        let backgrounds = Cosmetics.allBackgroundThemes
        assertEqual(backgrounds.count, 6, "Cosmetics: Exactly 6 background themes cataloged")
        assertEqual(backgrounds[0].id, "bg_default", "Cosmetics: Starter background is bg_default")

        // 1.7 Permanent Upgrades & Boosts
        let upgrades = Cosmetics.allUpgrades
        assertEqual(upgrades.count, 3, "Cosmetics: Exactly 3 permanent upgrades cataloged")
        for upg in upgrades {
            assertEqual(upg.maxLevel, 3, "Cosmetics: Upgrade \(upg.id) has maxLevel 3")
            assertEqual(upg.costs.count, 3, "Cosmetics: Upgrade \(upg.id) has 3 tier costs")
        }
        let boosts = Cosmetics.allBoosts
        assertEqual(boosts.count, 3, "Cosmetics: Exactly 3 pre-match boosts cataloged")
        for bst in boosts {
            assertEqual(bst.maxStock, 20, "Cosmetics: Boost \(bst.id) has maxStock 20")
        }

        // 1.8 Duplicate compensation
        for type in CrateDropType.allCases {
            let comp = Cosmetics.duplicateCompensation(for: type)
            assertTest(comp >= 100 && comp <= 350, "Cosmetics: Duplicate compensation for \(type) is within 100..350")
        }

        // --------------------------------------------------------------------
        // TEST SUITE 2: Aquarium Models (AquariumModel.swift)
        // --------------------------------------------------------------------
        print("\n--- [Suite 2] AquariumModel.swift Verification ---")

        // 2.1 18 Species & 6 Families
        let allFish = FishSpecies.allSpecies
        assertEqual(allFish.count, 18, "Aquarium: Exactly 18 fish species registered")
        let families = Set(allFish.map { $0.family })
        assertEqual(families.count, 6, "Aquarium: Exactly 6 fish families registered")
        for sp in allFish {
            assertTest(!sp.assetName.isEmpty, "Aquarium: Species \(sp.id) has assetName")
            assertTest(sp.passiveGPH > 0, "Aquarium: Species \(sp.id) has positive passive GPH")
        }

        // 2.2 Flora bonuses
        let allFlora = FloraBonus.allFlora
        assertEqual(allFlora.count, 6, "Aquarium: Exactly 6 flora bonus items registered")

        // 2.3 Entities
        var pellet = FoodPellet(x: 200, y: 100, vy: 36)
        pellet.update(dt: 1.0)
        assertTest(pellet.y > 100, "Aquarium: Food pellet descends with vy")
        assertTest(!pellet.isExpired, "Aquarium: Fresh pellet not expired")

        var bubble = AmbientBubble(x: 100, y: 500, radius: 5, speed: 20)
        bubble.update(dt: 1.0)
        assertTest(bubble.y < 500, "Aquarium: Bubble rises upwards")

        var simFish = SimulatedFish(
            species: allFish[0],
            x: 50,
            y: 200,
            vx: 30,
            vy: 0
        )
        simFish.update(dt: 0.5, tankWidth: 400, tankHeight: 800)
        assertTest(simFish.x > 50, "Aquarium: Simulated fish advances along velocity")

        // 2.4 Hay Day 4-hour economy
        let now = Date()
        var aqState = AquariumState(
            unlockedFishIds: ["guppy", "tetra"],
            floraCounts: ["moss": 2, "kelp": 1, "anubias": 1],
            sandLevel: 1,
            lastFedTime: now,
            lastCollectedTime: now
        )
        assertTest(!aqState.isFishHungry, "Aquarium: Freshly fed fish are not hungry")
        assertTest(aqState.hungerProgress < 0.001, "Aquarium: Hunger progress is ~0.0 at t=0")

        // Simulate 4.5 hours passed
        let after4_5h = now.addingTimeInterval(4.5 * 3600.0)
        let offlineGains = aqState.calculateOfflineGains(now: after4_5h)
        assertTest(offlineGains.effectiveHours <= 4.0, "Aquarium: Passive generation stops at 4.0h without feeding")
        assertEqual(offlineGains.comebackBonus, 20, "Aquarium: Away >= 4h awards +20 comeback bonus")
        assertTest(offlineGains.gold > 0, "Aquarium: Offline passive gold accumulated")

        let harvested = aqState.harvest(now: after4_5h)
        assertEqual(harvested, offlineGains.gold + offlineGains.comebackBonus, "Aquarium: Harvest returns passive gold + comeback bonus")
        assertEqual(aqState.accumulatedBank, 0.0, "Aquarium: Harvest resets bank to 0")

        // --------------------------------------------------------------------
        // TEST SUITE 3: Quest Models (QuestModel.swift)
        // --------------------------------------------------------------------
        print("\n--- [Suite 3] QuestModel.swift Verification ---")

        let defaultQuests = QuestCatalog.defaultDailyQuests
        assertEqual(defaultQuests.count, 5, "Quests: Exactly 5 daily quests defined")
        let types = Set(defaultQuests.map { $0.type })
        assertEqual(types.count, 5, "Quests: All 5 quest types are distinct")

        var testQuest = defaultQuests[0] // 50 bricks
        assertEqual(testQuest.progressFraction, 0.0, "Quests: Progress fraction starts at 0.0")
        testQuest.addProgress(25)
        assertEqual(testQuest.current, 25, "Quests: Progress increments to 25")
        assertEqual(testQuest.progressFraction, 0.5, "Quests: Progress fraction is 0.5 at 25/50")
        assertTest(!testQuest.isCompleted, "Quests: Quest not yet completed at 25/50")
        assertTest(!testQuest.canClaim, "Quests: Cannot claim incomplete quest")

        testQuest.addProgress(30) // Overcap test
        assertEqual(testQuest.current, 50, "Quests: Progress clamps to target 50")
        assertTest(testQuest.isCompleted, "Quests: Quest completed at 50/50")
        assertTest(testQuest.canClaim, "Quests: Can claim completed quest")

        // 7-day streak calendar
        let streakRewards = QuestCatalog.streakRewards
        assertEqual(streakRewards.count, 7, "Streak: Exactly 7 daily rewards cataloged")
        assertEqual(streakRewards[6].day, 7, "Streak: Day 7 is final jackpot")
        assertEqual(streakRewards[6].bonusType, .jackpot, "Streak: Day 7 has jackpot bonus")

        // --------------------------------------------------------------------
        // TEST SUITE 4: SaveManager Integration & Concurrency
        // --------------------------------------------------------------------
        print("\n--- [Suite 4] SaveManager.swift Verification ---")

        let sm = SaveManager.shared
        let initialGold = sm.gold
        sm.addGold(500)
        assertEqual(sm.gold, initialGold + 500, "SaveManager: addGold increments gold")

        let canSpend = sm.spendGold(200)
        assertTest(canSpend, "SaveManager: spendGold succeeds with sufficient funds")
        assertEqual(sm.gold, initialGold + 300, "SaveManager: spendGold deducts correct amount")

        let failSpend = sm.spendGold(999999)
        assertTest(!failSpend, "SaveManager: spendGold fails when funds insufficient")

        // Cosmetics unlocking and equipping
        sm.unlock(cosmeticId: "pembe")
        assertTest(sm.isUnlocked(cosmeticId: "pembe"), "SaveManager: Unlocked skin is registered")
        sm.equip(cosmeticId: "pembe")
        assertEqual(sm.equippedBallSkin, "pembe", "SaveManager: Equipping ball skin updates equippedBallSkin")

        // Legacy paddle sync
        sm.unlockPaddle(index: 2)
        sm.equipPaddle(index: 2)
        assertEqual(sm.equippedPaddleIndex, 2, "SaveManager: Legacy paddle index 2 equipped")
        assertEqual(sm.equippedPaddleSkin, "pice", "SaveManager: Equipped paddle skin synced to 'pice'")

        sm.unlockPaddle(index: 1)
        sm.equipPaddle(id: "ppink")
        assertEqual(sm.equippedPaddleSkin, "ppink", "SaveManager: Equipped paddle skin 'ppink'")
        assertEqual(sm.equippedPaddleIndex, 1, "SaveManager: Legacy paddle index synced to 1")

        // Quests tracking in SaveManager
        sm.recordQuestProgress(type: .bricks, amount: 10)
        let bricksQuest = sm.dailyQuests.first(where: { $0.type == .bricks })
        assertTest(bricksQuest != nil && bricksQuest!.current >= 10, "SaveManager: recordQuestProgress updates brick quest")

        print("\n======================================================================")
        print("  ALL MILESTONE 1 UNIT & INTEGRATION TESTS PASSED (100%)")
        print("======================================================================\n")
    }
}
