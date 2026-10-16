import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kirmatas/engine/game_controller.dart';
import 'package:kirmatas/models/game_state.dart';
import 'package:kirmatas/models/sector_data.dart';
import 'package:kirmatas/storage/save_manager.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('xyz.luan/audioplayers.global'),
      (MethodCall methodCall) async => 1,
    );
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('xyz.luan/audioplayers'),
      (MethodCall methodCall) async => 1,
    );
  });

  group('Challenger M2 Adversarial Test Suite', () {
    // =========================================================================
    // 1. COSMIC MASTERY UPGRADE MATH & AFFORDABILITY
    // =========================================================================
    group('1. Cosmic Mastery Math & Affordability', () {
      late SaveManager save;

      setUp(() async {
        SharedPreferences.setMockInitialValues({});
        save = SaveManager.instance;
        await save.init();
        save.gold = 0;
        save.pearls = 0;
        save.cosmicGoldMasteryLevel = 0;
        save.cosmicPearlMasteryLevel = 0;
      });

      test('Gold mastery cost formula: 1000 + level * 500 across wide level spectrum', () {
        for (int lvl = 0; lvl <= 100; lvl++) {
          save.cosmicGoldMasteryLevel = lvl;
          final expectedCost = 1000 + lvl * 500;
          expect(
            save.cosmicGoldMasteryCost,
            expectedCost,
            reason: 'Level $lvl expected cost $expectedCost but got ${save.cosmicGoldMasteryCost}',
          );
        }

        // Stress check on extreme endgame levels
        save.cosmicGoldMasteryLevel = 1000;
        expect(save.cosmicGoldMasteryCost, 1000 + 1000 * 500); // 501,000
      });

      test('Pearl mastery cost formula: 5 + level * 3 across wide level spectrum', () {
        for (int lvl = 0; lvl <= 100; lvl++) {
          save.cosmicPearlMasteryLevel = lvl;
          final expectedCost = 5 + lvl * 3;
          expect(
            save.cosmicPearlMasteryCost,
            expectedCost,
            reason: 'Level $lvl expected cost $expectedCost but got ${save.cosmicPearlMasteryCost}',
          );
        }

        // Stress check on extreme endgame levels
        save.cosmicPearlMasteryLevel = 1000;
        expect(save.cosmicPearlMasteryCost, 5 + 1000 * 3); // 3,005
      });

      test('Gold mastery purchasing requires exact or surplus gold and fails on cost - 1', () {
        save.cosmicGoldMasteryLevel = 0;
        final cost0 = save.cosmicGoldMasteryCost; // 1000
        expect(cost0, 1000);

        // Insufficient by 1
        save.gold = cost0 - 1; // 999
        final failAttempt = save.upgradeCosmicGoldMastery();
        expect(failAttempt, false);
        expect(save.gold, 999);
        expect(save.cosmicGoldMasteryLevel, 0);

        // Exact match
        save.gold = cost0; // 1000
        final successExact = save.upgradeCosmicGoldMastery();
        expect(successExact, true);
        expect(save.gold, 0);
        expect(save.cosmicGoldMasteryLevel, 1);
        expect(save.cosmicGoldMasteryCost, 1500);

        // Surplus match
        save.gold = 1800; // cost is 1500, leaves 300
        final successSurplus = save.upgradeCosmicGoldMastery();
        expect(successSurplus, true);
        expect(save.gold, 300);
        expect(save.cosmicGoldMasteryLevel, 2);
        expect(save.cosmicGoldMasteryCost, 2000);
      });

      test('Pearl mastery purchasing requires exact or surplus pearls and fails on cost - 1', () {
        save.cosmicPearlMasteryLevel = 0;
        final cost0 = save.cosmicPearlMasteryCost; // 5
        expect(cost0, 5);

        // Insufficient by 1
        save.pearls = cost0 - 1; // 4
        final failAttempt = save.upgradeCosmicPearlMastery();
        expect(failAttempt, false);
        expect(save.pearls, 4);
        expect(save.cosmicPearlMasteryLevel, 0);

        // Exact match
        save.pearls = cost0; // 5
        final successExact = save.upgradeCosmicPearlMastery();
        expect(successExact, true);
        expect(save.pearls, 0);
        expect(save.cosmicPearlMasteryLevel, 1);
        expect(save.cosmicPearlMasteryCost, 8);

        // Surplus match
        save.pearls = 15; // cost is 8, leaves 7
        final successSurplus = save.upgradeCosmicPearlMastery();
        expect(successSurplus, true);
        expect(save.pearls, 7);
        expect(save.cosmicPearlMasteryLevel, 2);
        expect(save.cosmicPearlMasteryCost, 11);
      });

      test('Pearls addition and spending edge cases (zero, negative, overspend)', () {
        save.pearls = 10;

        // Zero addition should be no-op
        save.addPearls(0);
        expect(save.pearls, 10);

        // Negative addition should be rejected
        save.addPearls(-5);
        expect(save.pearls, 10);

        // Normal addition
        save.addPearls(7);
        expect(save.pearls, 17);

        // Zero or negative spend should return true without deduction
        final spentZero = save.spendPearls(0);
        expect(spentZero, true);
        expect(save.pearls, 17);

        final spentNeg = save.spendPearls(-10);
        expect(spentNeg, true);
        expect(save.pearls, 17);

        // Overspend should fail and preserve balance
        final spentTooMuch = save.spendPearls(18);
        expect(spentTooMuch, false);
        expect(save.pearls, 17);

        // Valid spend
        final spentValid = save.spendPearls(17);
        expect(spentValid, true);
        expect(save.pearls, 0);
      });

      test('SaveManager persistence roundtrip for Cosmic Mastery and Pearls', () async {
        save.gold = 50000;
        save.pearls = 120;
        save.cosmicGoldMasteryLevel = 4;
        save.cosmicPearlMasteryLevel = 6;

        // Buy one of each
        expect(save.upgradeCosmicGoldMastery(), true); // cost 1000 + 4*500 = 3000 -> lvl 5
        expect(save.upgradeCosmicPearlMastery(), true); // cost 5 + 6*3 = 23 -> lvl 7

        expect(save.cosmicGoldMasteryLevel, 5);
        expect(save.cosmicPearlMasteryLevel, 7);
        expect(save.pearls, 120 - 23);

        // Re-initialize SaveManager from the same mock prefs
        await save.init();
        expect(save.cosmicGoldMasteryLevel, 5);
        expect(save.cosmicPearlMasteryLevel, 7);
        expect(save.pearls, 97);
      });

      test('GameController multipliers scale exactly with Cosmic Mastery levels', () {
        final ctrl = GameController();

        for (final lvl in [0, 1, 5, 10, 25, 50]) {
          save.cosmicGoldMasteryLevel = lvl;
          save.cosmicPearlMasteryLevel = lvl;

          final expectedDamageMult = 1.0 + lvl * 0.02;
          final expectedRewardMult = 1.0 + lvl * 0.02;
          final expectedUltiMult = 1.0 + lvl * 0.02;
          final expectedLuckBonus = lvl * 0.01;

          expect(ctrl.cosmicGoldDamageMultiplier, closeTo(expectedDamageMult, 1e-6));
          expect(ctrl.cosmicGoldRewardMultiplier, closeTo(expectedRewardMult, 1e-6));
          expect(ctrl.cosmicPearlUltiMultiplier, closeTo(expectedUltiMult, 1e-6));
          expect(ctrl.cosmicPearlLuckBonus, closeTo(expectedLuckBonus, 1e-6));
        }
      });
    });

    // =========================================================================
    // 2. DAILY BLITZ REWARD CLAIMING & IDEMPOTENCY
    // =========================================================================
    group('2. Daily Blitz Reward Claiming', () {
      late SaveManager save;

      setUp(() async {
        SharedPreferences.setMockInitialValues({});
        save = SaveManager.instance;
        await save.init();
        save.totalGold = 100;
        save.pearls = 0;
        save.lastDailyBlitzDate = null;
      });

      test('Format date produces exact YYYY-MM-DD pattern', () {
        expect(SaveManager.formatDailyDate(DateTime(2026, 1, 5)), '2026-01-05');
        expect(SaveManager.formatDailyDate(DateTime(2026, 10, 16)), '2026-10-16');
        expect(SaveManager.formatDailyDate(DateTime(2026, 12, 31)), '2026-12-31');
      });

      test('Claiming awards exactly 250 Gold + 3 Pearls + 1 Ball shard on first claim', () {
        final d = DateTime(2026, 10, 16);
        final initialBalls = save.getShards('balls');
        final initialGold = save.totalGold;
        final initialPearls = save.pearls;

        final success = save.claimDailyBlitzReward(date: d);
        expect(success, true);
        expect(save.totalGold, initialGold + 250);
        expect(save.pearls, initialPearls + 3);
        expect(save.getShards('balls'), initialBalls + 1);
        expect(save.lastDailyBlitzDate, '2026-10-16');
      });

      test('Duplicate claim on same date is rejected and does not award resources', () {
        final d = DateTime(2026, 10, 16);
        expect(save.claimDailyBlitzReward(date: d), true);

        final goldAfterFirst = save.totalGold;
        final pearlsAfterFirst = save.pearls;
        final shardsAfterFirst = save.getShards('balls');

        // Repeated duplicate attempts
        for (int attempt = 1; attempt <= 10; attempt++) {
          final repeat = save.claimDailyBlitzReward(date: d);
          expect(repeat, false, reason: 'Attempt $attempt on same date should return false');
          expect(save.totalGold, goldAfterFirst);
          expect(save.pearls, pearlsAfterFirst);
          expect(save.getShards('balls'), shardsAfterFirst);
        }
      });

      test('Different calendar days allow 1 claim per day sequentially', () {
        final initialBalls = save.getShards('balls');

        for (int day = 1; day <= 10; day++) {
          final date = DateTime(2026, 10, day);
          expect(save.claimDailyBlitzReward(date: date), true);
          expect(save.claimDailyBlitzReward(date: date), false);
          expect(save.totalGold, 100 + day * 250);
          expect(save.pearls, day * 3);
          expect(save.getShards('balls'), initialBalls + day);
        }
      });

      test('Midnight boundary roll-over (23:59:59 to 00:00:01)', () {
        final lateNight = DateTime(2026, 10, 16, 23, 59, 59);
        final earlyMorning = DateTime(2026, 10, 17, 0, 0, 1);

        expect(save.claimDailyBlitzReward(date: lateNight), true);
        expect(save.claimDailyBlitzReward(date: lateNight), false);

        expect(save.claimDailyBlitzReward(date: earlyMorning), true);
        expect(save.claimDailyBlitzReward(date: earlyMorning), false);
      });

      test('isDailyBlitzCompletedToday reflects current system date', () {
        final now = DateTime.now();
        expect(save.isDailyBlitzCompletedToday, false);

        save.claimDailyBlitzReward(date: now);
        expect(save.isDailyBlitzCompletedToday, true);

        // Yesterday's date does not satisfy completed today
        save.lastDailyBlitzDate = '2020-01-01';
        expect(save.isDailyBlitzCompletedToday, false);
      });

      test('GameController startDailyBlitz generates deterministic seeded layout per date', () {
        final dateA = DateTime(2026, 10, 16);
        final ctrl1 = GameController();
        final ctrl2 = GameController();

        ctrl1.startDailyBlitz(date: dateA);
        ctrl2.startDailyBlitz(date: dateA);

        expect(ctrl1.currentMode, GameMode.daily);
        expect(ctrl2.currentMode, GameMode.daily);
        expect(ctrl1.bricks.length, ctrl2.bricks.length);

        for (int i = 0; i < ctrl1.bricks.length; i++) {
          expect(ctrl1.bricks[i].x, ctrl2.bricks[i].x);
          expect(ctrl1.bricks[i].y, ctrl2.bricks[i].y);
          expect(ctrl1.bricks[i].hp, ctrl2.bricks[i].hp);
          expect(ctrl1.bricks[i].maxHp, ctrl2.bricks[i].maxHp);
          expect(ctrl1.bricks[i].isBoss, ctrl2.bricks[i].isBoss);
        }
      });
    });

    // =========================================================================
    // 3. POST-238 PRESTIGE SCALING & SECTOR INVARIANTS
    // =========================================================================
    group('3. Post-238 Prestige Scaling', () {
      test('Prestige tier exact boundaries: 238=0, 239=1, 255=1, 256=2', () {
        // Levels <= 238 are non-prestige
        expect(SaveManager.calculatePrestigeTier(1), 0);
        expect(SaveManager.calculatePrestigeTier(50), 0);
        expect(SaveManager.calculatePrestigeTier(237), 0);
        expect(SaveManager.calculatePrestigeTier(238), 0);

        // Prestige Tier 1: levels 239 to 255 (17 levels)
        expect(SaveManager.calculatePrestigeTier(239), 1);
        expect(SaveManager.calculatePrestigeTier(240), 1);
        expect(SaveManager.calculatePrestigeTier(245), 1);
        expect(SaveManager.calculatePrestigeTier(254), 1);
        expect(SaveManager.calculatePrestigeTier(255), 1);

        // Prestige Tier 2: levels 256 to 272 (17 levels)
        expect(SaveManager.calculatePrestigeTier(256), 2);
        expect(SaveManager.calculatePrestigeTier(257), 2);
        expect(SaveManager.calculatePrestigeTier(272), 2);

        // Prestige Tier 3: levels 273 to 289
        expect(SaveManager.calculatePrestigeTier(273), 3);
        expect(SaveManager.calculatePrestigeTier(289), 3);

        // Prestige Tier 4: level 290
        expect(SaveManager.calculatePrestigeTier(290), 4);

        // High level stress check
        expect(SaveManager.calculatePrestigeTier(1000), ((1000 - 239) ~/ 17) + 1);
      });

      test('SectorData.allSectors length remains exactly 14 and spans levels 1 to 238', () {
        expect(SectorData.allSectors.length, 14);

        for (int i = 0; i < SectorData.allSectors.length; i++) {
          final sector = SectorData.allSectors[i];
          expect(sector.sectorIndex, i + 1);
          if (i > 0) {
            final prevSector = SectorData.allSectors[i - 1];
            expect(sector.startLevel, prevSector.endLevel + 1);
          } else {
            expect(sector.startLevel, 1);
          }
        }
        expect(SectorData.allSectors.first.startLevel, 1);
        expect(SectorData.allSectors.last.endLevel, 238);
      });

      test('SectorData.getSectorForLevel returns last sector for post-238 levels safely', () {
        final lastSector = SectorData.allSectors.last;
        expect(SectorData.getSectorForLevel(238), lastSector);
        expect(SectorData.getSectorForLevel(239), lastSector);
        expect(SectorData.getSectorForLevel(255), lastSector);
        expect(SectorData.getSectorForLevel(256), lastSector);
        expect(SectorData.getSectorForLevel(999), lastSector);
      });

      test('GameController prestige tier and gold multiplier scaling on post-238 levels', () {
        final ctrl = GameController();

        // Level 238 (Classic Apex)
        ctrl.startNewGame(GameMode.classic, explicitStartLevel: 238);
        expect(ctrl.prestigeTier, 0);
        expect(ctrl.prestigeGoldMultiplier, closeTo(1.0, 1e-6));

        // Level 239 (Prestige Tier 1)
        ctrl.startNewGame(GameMode.classic, explicitStartLevel: 239);
        expect(ctrl.prestigeTier, 1);
        expect(ctrl.prestigeGoldMultiplier, closeTo(1.20, 1e-6));

        // Level 255 (Prestige Tier 1 max)
        ctrl.startNewGame(GameMode.classic, explicitStartLevel: 255);
        expect(ctrl.prestigeTier, 1);
        expect(ctrl.prestigeGoldMultiplier, closeTo(1.20, 1e-6));

        // Level 256 (Prestige Tier 2)
        ctrl.startNewGame(GameMode.classic, explicitStartLevel: 256);
        expect(ctrl.prestigeTier, 2);
        expect(ctrl.prestigeGoldMultiplier, closeTo(1.40, 1e-6));

        // Level 273 (Prestige Tier 3)
        ctrl.startNewGame(GameMode.classic, explicitStartLevel: 273);
        expect(ctrl.prestigeTier, 3);
        expect(ctrl.prestigeGoldMultiplier, closeTo(1.60, 1e-6));
      });

      test('GameController scales brick HP on prestige levels (> 238)', () {
        final ctrlP0 = GameController();
        ctrlP0.startNewGame(GameMode.classic, explicitStartLevel: 238);

        final ctrlP2 = GameController();
        ctrlP2.startNewGame(GameMode.classic, explicitStartLevel: 256); // Tier 2

        expect(ctrlP2.prestigeTier, 2);
        final p2NormalBricks = ctrlP2.bricks.where((b) => !b.isBoss && !b.isSteel && !b.isDynamite && !b.isIce && !b.isTuft).toList();
        expect(p2NormalBricks.isNotEmpty, true);
        for (final b in p2NormalBricks) {
          expect(b.maxHp >= 1 + 2, true);
        }
      });
    });

    // =========================================================================
    // 4. SEASONAL TITLES & LEAGUE RIVALS (R7 VERIFICATION)
    // =========================================================================
    group('4. Seasonal Titles & Dynamic League Rivals', () {
      late SaveManager save;

      setUp(() async {
        SharedPreferences.setMockInitialValues({});
        save = SaveManager.instance;
        await save.init();
      });

      test('League tier clamped [0..4] with exact title mappings', () {
        expect(SaveManager.seasonalTitles, [
          'Çaylak Kırıcı',
          'Neon Avcısı',
          'Plazma Lordu',
          'Elmas Hükümdarı',
          'Kozmik İmparator',
        ]);

        save.leagueTier = 0;
        expect(save.seasonalTitle, 'Çaylak Kırıcı');

        save.leagueTier = 1;
        expect(save.seasonalTitle, 'Neon Avcısı');

        save.leagueTier = 2;
        expect(save.seasonalTitle, 'Plazma Lordu');

        save.leagueTier = 3;
        expect(save.seasonalTitle, 'Elmas Hükümdarı');

        save.leagueTier = 4;
        expect(save.seasonalTitle, 'Kozmik İmparator');

        // Clamping check
        save.leagueTier = -1;
        expect(save.leagueTier, 0);

        save.leagueTier = 99;
        expect(save.leagueTier, 4);
      });

      test('League rivals list is strictly 15 players, exactly 1 player SEN, strictly sorted', () {
        save.leagueTier = 2;
        save.weeklyTournamentScore = 15400;

        final rivals = save.getLeagueRivals();
        expect(rivals.length, 15);

        final player = rivals.singleWhere((r) => r.isPlayer);
        expect(player.name, 'SEN');
        expect(player.score, 15400);

        for (int i = 0; i < rivals.length - 1; i++) {
          expect(rivals[i].score >= rivals[i + 1].score, true);
          expect(rivals[i].rank, i + 1);
        }
        expect(rivals.last.rank, 15);
      });
    });
  });
}
