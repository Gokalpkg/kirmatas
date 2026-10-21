import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:kirmatas/storage/save_manager.dart';
import 'package:kirmatas/engine/game_controller.dart';
import 'package:kirmatas/models/game_state.dart';
import 'package:kirmatas/models/brick.dart';
import 'package:kirmatas/models/ball.dart';
import 'package:kirmatas/ui/tournament_dialog.dart';

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

  group('Challenger 2 Empirical Verification: Milestone 2', () {
    late SaveManager save;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      save = SaveManager.instance;
      await save.init();
      save.cosmicGoldMasteryLevel = 0;
      save.cosmicPearlMasteryLevel = 0;
      save.gold = 1000;
      save.pearls = 100;
      save.leagueTier = 0;
      save.weeklyTournamentScore = 0;
    });

    // =========================================================================
    // 1. TOURNAMENT & RIVAL GENERATION EMPIRICAL TESTS
    // =========================================================================
    group('1. Tournament & League Rivals Verification', () {
      test('getLeagueRivals returns exactly 15 rivals across all league tiers', () {
        for (int tier = 0; tier <= 4; tier++) {
          save.leagueTier = tier;
          final rivals = save.getLeagueRivals();
          expect(rivals.length, 15, reason: 'Tier $tier must produce exactly 15 rivals');
        }
      });

      test('getLeagueRivals is sorted strictly descending by score with sequential ranks 1..15', () {
        for (int tier = 0; tier <= 4; tier++) {
          save.leagueTier = tier;
          save.weeklyTournamentScore = 5000 * (tier + 1);
          final rivals = save.getLeagueRivals();

          for (int i = 0; i < rivals.length - 1; i++) {
            expect(
              rivals[i].score >= rivals[i + 1].score,
              isTrue,
              reason: 'Tier $tier rival at index $i (${rivals[i].score}) must be >= index ${i + 1} (${rivals[i + 1].score})',
            );
            expect(
              rivals[i].rank,
              i + 1,
              reason: 'Tier $tier rival at index $i must have rank ${i + 1}',
            );
          }
          expect(rivals.last.rank, 15);
        }
      });

      test('getLeagueRivals includes exactly one player labeled "SEN" with matching weekly score', () {
        save.leagueTier = 2;
        save.weeklyTournamentScore = 14500;

        final rivals = save.getLeagueRivals();
        final playerEntries = rivals.where((r) => r.isPlayer).toList();

        expect(playerEntries.length, 1, reason: 'There must be exactly 1 player in the leaderboard');
        final player = playerEntries.first;
        expect(player.name, 'SEN');
        expect(player.score, 14500);
        expect(player.rank, inInclusiveRange(1, 15));
      });

      test('Rival scores scale realistically and monotonically across league tiers 0..4', () {
        final expectedMin = [600, 2500, 8000, 20000, 50000];
        final expectedMax = [2800, 9500, 24000, 55000, 130000];

        for (int tier = 0; tier <= 4; tier++) {
          save.leagueTier = tier;
          save.weeklyTournamentScore = 0;
          final rivals = save.getLeagueRivals();
          final botRivals = rivals.where((r) => !r.isPlayer).toList();
          expect(botRivals.length, 14);

          for (final bot in botRivals) {
            expect(
              bot.score >= expectedMin[tier] && bot.score < expectedMax[tier],
              isTrue,
              reason: 'Tier $tier bot score ${bot.score} must be within [${expectedMin[tier]}, ${expectedMax[tier]})',
            );
          }
        }

        // Verify tier boundary monotonicity: tier N max score strictly < tier N+1 max score
        for (int tier = 0; tier < 4; tier++) {
          expect(expectedMax[tier] < expectedMax[tier + 1], isTrue);
          expect(expectedMin[tier] < expectedMin[tier + 1], isTrue);
        }
      });

      testWidgets('TournamentDialog displays division info, player status badges, and join callback', (tester) async {
        tester.view.physicalSize = const Size(800, 1600);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());
        addTearDown(() => tester.view.resetDevicePixelRatio());

        // Case A: High score -> Promotion rank <= 3
        save.leagueTier = 1;
        save.weeklyTournamentScore = 999999;

        bool joinCalled = false;
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => ElevatedButton(
                  onPressed: () => TournamentDialog.show(
                    context,
                    save: save,
                    onJoinTournament: () => joinCalled = true,
                  ),
                  child: const Text('SHOW'),
                ),
              ),
            ),
          ),
        );
        await tester.pump();
        await tester.tap(find.text('SHOW'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        expect(find.text('HAFTALIK LİG ŞAMPİYONASI'), findsOneWidget);
        expect(find.textContaining('Kişilik Lig Grubu'), findsOneWidget);
        expect(find.text('Neon Avcısı'), findsWidgets);
        expect(find.text('YÜKSELME ⬆️'), findsOneWidget);
        expect(find.text('SEN'), findsWidgets);

        // Tap Join
        await tester.tap(find.text('MÜCADELEYE KATIL'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));
        expect(joinCalled, isTrue);

        // Case B: Score 0 -> Demotion rank > 10
        save.weeklyTournamentScore = 0;
        await tester.tap(find.text('SHOW'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));
        expect(find.text('DÜŞME ⬇️'), findsOneWidget);

        // Close via close button
        await tester.tap(find.byIcon(Icons.close_rounded));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));
      });
    });

    // =========================================================================
    // 2. SEASONAL TITLE MAPPING & CLAMPING TESTS
    // =========================================================================
    group('2. Seasonal Title and Tier Mapping Verification', () {
      test('seasonalTitle maps accurately across tiers 0..4', () {
        final expectedTitles = {
          0: 'Çaylak Kırıcı',
          1: 'Neon Avcısı',
          2: 'Plazma Lordu',
          3: 'Elmas Hükümdarı',
          4: 'Kozmik İmparator',
        };

        for (final entry in expectedTitles.entries) {
          save.leagueTier = entry.key;
          expect(save.seasonalTitle, entry.value, reason: 'Tier ${entry.key} title mismatch');
        }
      });

      test('seasonalTitle clamps gracefully on underflow and overflow tiers', () {
        save.leagueTier = -1;
        expect(save.seasonalTitle, 'Çaylak Kırıcı');

        save.leagueTier = -100;
        expect(save.seasonalTitle, 'Çaylak Kırıcı');

        save.leagueTier = 5;
        expect(save.seasonalTitle, 'Kozmik İmparator');

        save.leagueTier = 999;
        expect(save.seasonalTitle, 'Kozmik İmparator');
      });

      test('leagueTierColor maps distinct vibrant colors for tiers 0..4', () {
        save.leagueTier = 0;
        expect(save.leagueTierColor, const Color(0xFFCD7F32)); // Bronze

        save.leagueTier = 1;
        expect(save.leagueTierColor, const Color(0xFF00E5FF)); // Cyan

        save.leagueTier = 2;
        expect(save.leagueTierColor, const Color(0xFFE040FB)); // Purple

        save.leagueTier = 3;
        expect(save.leagueTierColor, const Color(0xFF80D8FF)); // Light blue

        save.leagueTier = 4;
        expect(save.leagueTierColor, const Color(0xFFFFD700)); // Gold
      });
    });

    // =========================================================================
    // 3. GAMECONTROLLER MASTERY BONUS APPLICATION TESTS
    // =========================================================================
    group('3. GameController Cosmic Mastery Bonus Application', () {
      test('Cosmic Gold Mastery multipliers scale strictly by +2% per level', () {
        final gc = GameController();

        save.cosmicGoldMasteryLevel = 0;
        expect(gc.cosmicGoldDamageMultiplier, 1.0);
        expect(gc.cosmicGoldRewardMultiplier, 1.0);

        save.cosmicGoldMasteryLevel = 10;
        expect(gc.cosmicGoldDamageMultiplier, closeTo(1.20, 1e-5));
        expect(gc.cosmicGoldRewardMultiplier, closeTo(1.20, 1e-5));

        save.cosmicGoldMasteryLevel = 50;
        expect(gc.cosmicGoldDamageMultiplier, closeTo(2.00, 1e-5));
        expect(gc.cosmicGoldRewardMultiplier, closeTo(2.00, 1e-5));

        save.cosmicGoldMasteryLevel = 100;
        expect(gc.cosmicGoldDamageMultiplier, closeTo(3.00, 1e-5));
        expect(gc.cosmicGoldRewardMultiplier, closeTo(3.00, 1e-5));
      });

      test('Cosmic Pearl Mastery multipliers scale strictly by +2% ulti and +1% luck per level', () {
        final gc = GameController();

        save.cosmicPearlMasteryLevel = 0;
        expect(gc.cosmicPearlUltiMultiplier, 1.0);
        expect(gc.cosmicPearlLuckBonus, 0.0);

        save.cosmicPearlMasteryLevel = 10;
        expect(gc.cosmicPearlUltiMultiplier, closeTo(1.20, 1e-5));
        expect(gc.cosmicPearlLuckBonus, closeTo(0.10, 1e-5));

        save.cosmicPearlMasteryLevel = 25;
        expect(gc.cosmicPearlUltiMultiplier, closeTo(1.50, 1e-5));
        expect(gc.cosmicPearlLuckBonus, closeTo(0.25, 1e-5));

        save.cosmicPearlMasteryLevel = 50;
        expect(gc.cosmicPearlUltiMultiplier, closeTo(2.00, 1e-5));
        expect(gc.cosmicPearlLuckBonus, closeTo(0.50, 1e-5));
      });

      test('Cosmic Gold Mastery guarantees bonus damage at level 50 in Classic Mode', () {
        final gc = GameController();
        gc.setDimensions(360, 640);
        gc.startNewGame(GameMode.classic, explicitStartLevel: 1);

        // At level 50, cosmicBonus = 50 * 0.02 = 1.0 (100% chance of >= 2 damage)
        save.cosmicGoldMasteryLevel = 50;
        save.upgrades.clear(); // zero base crit upgrade

        final brick = Brick(x: 100, y: 100, width: 40, height: 20, hp: 2, maxHp: 2, color: Colors.blue);
        gc.bricks = [brick];

        final ball = Ball(x: brick.x + brick.width / 2, y: brick.y + brick.height / 2, vx: 0, vy: -100);
        ball.isStuck = false;
        gc.balls.clear();
        gc.balls.add(ball);
        gc.status = GameStatus.playing;

        gc.update(0.016);

        // 2 HP brick must be destroyed in 1 hit due to 100% cosmic bonus damage
        expect(brick.isAlive, isFalse, reason: 'Brick with 2 HP should be destroyed in single hit with 100% cosmic bonus');
      });

      test('Cosmic Gold Mastery guarantees bonus damage at level 50 in Chaos Mode', () {
        final gc = GameController();
        gc.setDimensions(360, 640);
        gc.startNewGame(GameMode.chaos, explicitStartLevel: 1);

        save.cosmicGoldMasteryLevel = 50;
        save.upgrades.clear();

        final brick = Brick(x: 100, y: 100, width: 40, height: 20, hp: 2, maxHp: 2, color: Colors.purple);
        gc.bricks = [brick];

        final ball = Ball(x: brick.x + brick.width / 2, y: brick.y + brick.height / 2, vx: 0, vy: -100);
        ball.isStuck = false;
        gc.balls.clear();
        gc.balls.add(ball);
        gc.status = GameStatus.playing;

        gc.update(0.016);

        expect(brick.isAlive, isFalse, reason: 'Chaos Mode brick with 2 HP should be destroyed in single hit with 100% cosmic bonus');
      });

      test('Cosmic Gold Mastery multiplies gold rewards on level clear and game victory', () {
        final gc = GameController();
        gc.setDimensions(360, 640);
        gc.startNewGame(GameMode.classic, explicitStartLevel: 10);
        gc.status = GameStatus.playing;

        // Baseline level clear without mastery
        save.cosmicGoldMasteryLevel = 0;
        save.gold = 0;
        save.upgrades.clear();
        gc.stats.level = 10;
        // Non-empty list with all bricks cleared triggers level completion reward
        final dummyCleared = Brick(x: 10, y: 10, width: 10, height: 10, hp: 1, maxHp: 1, color: Colors.blue);
        dummyCleared.isAlive = false;
        gc.bricks = [dummyCleared];
        gc.update(0.016);
        final baseLevelGold = gc.stats.goldCollected;
        expect(baseLevelGold, greaterThan(0));

        // Level clear with level 50 mastery (+100% -> 2x gold)
        final gc2 = GameController();
        gc2.setDimensions(360, 640);
        gc2.startNewGame(GameMode.classic, explicitStartLevel: 10);
        save.cosmicGoldMasteryLevel = 50;
        gc2.stats.level = 10;
        gc2.stats.goldCollected = 0;
        gc2.status = GameStatus.playing;
        final dummyCleared2 = Brick(x: 10, y: 10, width: 10, height: 10, hp: 1, maxHp: 1, color: Colors.blue);
        dummyCleared2.isAlive = false;
        gc2.bricks = [dummyCleared2];
        gc2.update(0.016);
        final masteredLevelGold = gc2.stats.goldCollected;

        expect(
          masteredLevelGold,
          closeTo(baseLevelGold * 2.0, 2),
          reason: 'Mastery Level 50 should double the level clear gold',
        );

        // Victory gold bonus on Apex Level 238 victory:
        // With level 0 mastery: victoryGold = 100
        save.cosmicGoldMasteryLevel = 0;
        final gcVic0 = GameController();
        gcVic0.setDimensions(360, 640);
        gcVic0.startNewGame(GameMode.classic, explicitStartLevel: 238);
        gcVic0.stats.goldCollected = 0;
        gcVic0.status = GameStatus.playing;
        final dummyCleared3 = Brick(x: 10, y: 10, width: 10, height: 10, hp: 1, maxHp: 1, color: Colors.blue);
        dummyCleared3.isAlive = false;
        gcVic0.bricks = [dummyCleared3];
        gcVic0.update(0.016);
        expect(gcVic0.status, GameStatus.victory);
        expect(gcVic0.stats.goldCollected, 100);

        // With level 50 mastery: victoryGold = 100 * 2.0 = 200
        save.cosmicGoldMasteryLevel = 50;
        final gcVic50 = GameController();
        gcVic50.setDimensions(360, 640);
        gcVic50.startNewGame(GameMode.classic, explicitStartLevel: 238);
        gcVic50.stats.goldCollected = 0;
        gcVic50.status = GameStatus.playing;
        final dummyCleared4 = Brick(x: 10, y: 10, width: 10, height: 10, hp: 1, maxHp: 1, color: Colors.blue);
        dummyCleared4.isAlive = false;
        gcVic50.bricks = [dummyCleared4];
        gcVic50.update(0.016);
        expect(gcVic50.status, GameStatus.victory);
        expect(gcVic50.stats.goldCollected, 200);
      });

      test('Cosmic Pearl Mastery accelerates Ulti charge on outer tip clutch saves', () {
        final gc = GameController();
        gc.setDimensions(360, 640);

        // Level 0 pearl mastery: base tip clutch save awards 3.0 * 1.0 = 3.0
        save.cosmicPearlMasteryLevel = 0;
        gc.startNewGame(GameMode.classic, explicitStartLevel: 1);
        gc.status = GameStatus.playing;
        gc.launchBall();

        final ball = gc.balls.first;
        // Outer 10% tip hit: paddle x is centered, offset >= 0.90
        ball.x = gc.paddle.x + gc.paddle.width * 0.95;
        ball.y = gc.paddle.y - ball.radius + 1.0;
        ball.vx = 0;
        ball.vy = 300.0;
        gc.stats.ultiCharge = 0.0;

        gc.update(0.016);
        final baseCharge = gc.stats.ultiCharge;
        expect(baseCharge, closeTo(3.0, 0.1));

        // Level 50 pearl mastery (+100% ulti multiplier): awards 3.0 * 2.0 = 6.0
        save.cosmicPearlMasteryLevel = 50;
        gc.startNewGame(GameMode.classic, explicitStartLevel: 1);
        gc.status = GameStatus.playing;
        gc.launchBall();

        final ball2 = gc.balls.first;
        ball2.x = gc.paddle.x + gc.paddle.width * 0.95;
        ball2.y = gc.paddle.y - ball2.radius + 1.0;
        ball2.vx = 0;
        ball2.vy = 300.0;
        gc.stats.ultiCharge = 0.0;

        gc.update(0.016);
        final masteredCharge = gc.stats.ultiCharge;
        expect(masteredCharge, closeTo(6.0, 0.1));
        expect(masteredCharge, closeTo(baseCharge * 2.0, 0.1));
      });

      test('Cosmic Pearl Mastery luck bonus boosts jackpot double dice chance to 100%', () {
        final gc = GameController();
        gc.setDimensions(360, 640);
        gc.startNewGame(GameMode.classic, explicitStartLevel: 1);

        // Base jackpot chance is 0.25. Level 75 gives +0.75 luck bonus -> 1.00 (100% chance)
        save.cosmicPearlMasteryLevel = 75;
        expect(gc.cosmicPearlLuckBonus, 0.75);

        for (int trial = 0; trial < 20; trial++) {
          gc.stats.ultiCharge = 100.0;
          gc.triggerUlti();
          expect(gc.isDoubleDice, isTrue, reason: 'With 100% jackpot chance, every dice roll must be double dice');
          gc.isDiceRolling = false;
        }
      });
    });
  });
}
