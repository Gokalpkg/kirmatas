import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kirmatas/engine/game_controller.dart';
import 'package:kirmatas/models/ball.dart';
import 'package:kirmatas/models/brick.dart';
import 'package:kirmatas/models/game_state.dart';
import 'package:kirmatas/models/powerup.dart';
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

  group('Milestone 1 Adversarial Suite: SaveManager Progression Boundary Matrix', () {
    late SaveManager save;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      save = SaveManager.instance;
      await save.init();
    });

    test('Boundary Matrix: highestLevel [1..7] & totalGold [0, 99, 100]', () {
      final levelsToTest = [-1, 0, 1, 2, 3, 4, 5, 6, 7, 8, 238];
      final goldsToTest = [-5, 0, 50, 99, 100, 101, 1000];

      for (final lvl in levelsToTest) {
        for (final g in goldsToTest) {
          save.highestLevel = lvl;
          save.totalGold = g;

          final expectedShop = (lvl >= 2) || (g >= 100);
          final expectedWorkshop = lvl >= 3;
          final expectedAquarium = lvl >= 5;
          final expectedChaos = lvl >= 5;
          final expectedLeague = lvl >= 7;

          expect(
            save.isShopUnlocked,
            expectedShop,
            reason: 'Failed at highestLevel=$lvl, totalGold=$g for isShopUnlocked',
          );
          expect(
            save.isWorkshopUnlocked,
            expectedWorkshop,
            reason: 'Failed at highestLevel=$lvl, totalGold=$g for isWorkshopUnlocked',
          );
          expect(
            save.isAquariumUnlocked,
            expectedAquarium,
            reason: 'Failed at highestLevel=$lvl, totalGold=$g for isAquariumUnlocked',
          );
          expect(
            save.isChaosUnlocked,
            expectedChaos,
            reason: 'Failed at highestLevel=$lvl, totalGold=$g for isChaosUnlocked',
          );
          expect(
            save.isLeagueUnlocked,
            expectedLeague,
            reason: 'Failed at highestLevel=$lvl, totalGold=$g for isLeagueUnlocked',
          );
        }
      }
    });

    test('Exact Contract Verification for Levels 1 through 7', () {
      // Level 1, Gold 0: Everything locked
      save.highestLevel = 1;
      save.totalGold = 0;
      expect(save.isShopUnlocked, isFalse);
      expect(save.isWorkshopUnlocked, isFalse);
      expect(save.isAquariumUnlocked, isFalse);
      expect(save.isChaosUnlocked, isFalse);
      expect(save.isLeagueUnlocked, isFalse);

      // Level 1, Gold 99: Still everything locked
      save.totalGold = 99;
      expect(save.isShopUnlocked, isFalse);
      expect(save.isWorkshopUnlocked, isFalse);

      // Level 1, Gold 100: ONLY Shop unlocks via 100 Gold rule
      save.totalGold = 100;
      expect(save.isShopUnlocked, isTrue);
      expect(save.isWorkshopUnlocked, isFalse);
      expect(save.isAquariumUnlocked, isFalse);
      expect(save.isChaosUnlocked, isFalse);
      expect(save.isLeagueUnlocked, isFalse);

      // Level 2, Gold 0: ONLY Shop unlocks via Level 2 rule
      save.highestLevel = 2;
      save.totalGold = 0;
      expect(save.isShopUnlocked, isTrue);
      expect(save.isWorkshopUnlocked, isFalse);
      expect(save.isAquariumUnlocked, isFalse);
      expect(save.isChaosUnlocked, isFalse);
      expect(save.isLeagueUnlocked, isFalse);

      // Level 3, Gold 0: Shop and Workshop unlocked
      save.highestLevel = 3;
      expect(save.isShopUnlocked, isTrue);
      expect(save.isWorkshopUnlocked, isTrue);
      expect(save.isAquariumUnlocked, isFalse);
      expect(save.isChaosUnlocked, isFalse);
      expect(save.isLeagueUnlocked, isFalse);

      // Level 4, Gold 0: Same as Level 3
      save.highestLevel = 4;
      expect(save.isShopUnlocked, isTrue);
      expect(save.isWorkshopUnlocked, isTrue);
      expect(save.isAquariumUnlocked, isFalse);
      expect(save.isChaosUnlocked, isFalse);
      expect(save.isLeagueUnlocked, isFalse);

      // Level 5, Gold 0: Shop, Workshop, Aquarium, and Chaos unlocked; League locked
      save.highestLevel = 5;
      expect(save.isShopUnlocked, isTrue);
      expect(save.isWorkshopUnlocked, isTrue);
      expect(save.isAquariumUnlocked, isTrue);
      expect(save.isChaosUnlocked, isTrue);
      expect(save.isLeagueUnlocked, isFalse);

      // Level 6, Gold 0: Same as Level 5
      save.highestLevel = 6;
      expect(save.isShopUnlocked, isTrue);
      expect(save.isWorkshopUnlocked, isTrue);
      expect(save.isAquariumUnlocked, isTrue);
      expect(save.isChaosUnlocked, isTrue);
      expect(save.isLeagueUnlocked, isFalse);

      // Level 7, Gold 0: ALL unlocked
      save.highestLevel = 7;
      expect(save.isShopUnlocked, isTrue);
      expect(save.isWorkshopUnlocked, isTrue);
      expect(save.isAquariumUnlocked, isTrue);
      expect(save.isChaosUnlocked, isTrue);
      expect(save.isLeagueUnlocked, isTrue);
    });

    test('Persistence & SharedPreferences synchronization', () async {
      save.highestLevel = 9;
      save.totalGold = 450;

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getInt('metricHighestClassicLevel'), 9);
      expect(prefs.getInt('gold'), 450);
      expect(save.highestLevel, 9);
      expect(save.totalGold, 450);
    });
  });

  group('Milestone 1 Adversarial Suite: Ball Speed Scaling & Mode Isolation', () {
    late GameController ctrl;

    setUp(() {
      ctrl = GameController();
      ctrl.setDimensions(360, 640);
    });

    test('Classic mode speed multiplier applies strictly to levels 1 through 5', () {
      const pace = 1.48;
      const base = 350.0 * pace;

      for (int lvl = 1; lvl <= 15; lvl++) {
        ctrl.startNewGame(GameMode.classic, explicitStartLevel: lvl);
        final actualSpeed = ctrl.getBaseBallSpeed();
        final levelSpeed = base + math.min(lvl * 10.0, 90.0);

        if (lvl <= 5) {
          final expectedSpeed = levelSpeed * 1.15;
          expect(
            actualSpeed,
            closeTo(expectedSpeed, 1e-6),
            reason: 'Level $lvl in Classic mode should receive exactly 1.15x speed boost',
          );
          expect(actualSpeed, greaterThan(levelSpeed));
        } else {
          expect(
            actualSpeed,
            closeTo(levelSpeed, 1e-6),
            reason: 'Level $lvl in Classic mode should NOT receive 1.15x speed boost',
          );
        }
      }
    });

    test('Level 6 does NOT have speed multiplier (boundary check)', () {
      ctrl.startNewGame(GameMode.classic, explicitStartLevel: 6);
      final speed6 = ctrl.getBaseBallSpeed();
      const pace = 1.48;
      const unboostedSpeed6 = 350.0 * pace + 60.0;
      final boostedSpeed6 = unboostedSpeed6 * 1.15;

      expect(speed6, closeTo(unboostedSpeed6, 1e-6));
      expect(speed6, isNot(closeTo(boostedSpeed6, 0.1)));
    });

    test('Chaos mode ignores level speed multiplier across all levels', () {
      const pace = 1.48;
      const expectedChaosSpeed = 420.0 * pace; // 621.6

      for (int lvl = 1; lvl <= 10; lvl++) {
        ctrl.startNewGame(GameMode.chaos, explicitStartLevel: lvl);
        final speed = ctrl.getBaseBallSpeed();
        expect(
          speed,
          closeTo(expectedChaosSpeed, 1e-6),
          reason: 'Chaos mode at level $lvl should have fixed 420 * 1.48 speed without FTUE multiplier',
        );
      }
    });

    test('Zen mode ignores level speed multiplier across all levels', () {
      const pace = 1.48;
      const base = 350.0 * pace;

      for (int lvl = 1; lvl <= 6; lvl++) {
        ctrl.startNewGame(GameMode.zen, explicitStartLevel: lvl);
        final speed = ctrl.getBaseBallSpeed();
        final unboostedLevelSpeed = base + math.min(lvl * 10.0, 90.0);
        expect(
          speed,
          closeTo(unboostedLevelSpeed, 1e-6),
          reason: 'Zen mode at level $lvl must not receive FTUE speed boost',
        );
      }
    });
  });

  group('Milestone 1 Adversarial Suite: Guaranteed Action Capsule Drops', () {
    late GameController ctrl;

    setUp(() {
      ctrl = GameController();
      ctrl.setDimensions(360, 640);
    });

    test('Levels 1 to 5 guarantee an action capsule on or before 3rd brick broken', () {
      for (int lvl = 1; lvl <= 5; lvl++) {
        ctrl.startNewGame(GameMode.classic, explicitStartLevel: lvl);
        ctrl.capsules.clear();
        expect(ctrl.earlyActionDropGranted, isFalse, reason: 'Level $lvl should start with earlyActionDropGranted=false');
        expect(ctrl.levelBricksBroken, 0);

        // Break 1st brick (leave dummy brick alive so level does not clear)
        final b1 = Brick(x: 100, y: 100, width: 40, height: 20, hp: 1, maxHp: 1, color: Colors.blue);
        final b2 = Brick(x: 150, y: 100, width: 40, height: 20, hp: 1, maxHp: 1, color: Colors.blue);
        final b3 = Brick(x: 200, y: 100, width: 40, height: 20, hp: 1, maxHp: 1, color: Colors.blue);
        ctrl.bricks = [b1, b2, b3];

        final ball = Ball(x: 120, y: 110, vx: 0, vy: -100);
        ball.isStuck = false;
        ctrl.balls.clear();
        ctrl.balls.add(ball);
        ctrl.status = GameStatus.playing;

        // Destroy brick 1
        ctrl.update(0.016);

        expect(b1.isAlive, isFalse);
        expect(ctrl.earlyActionDropGranted, isTrue, reason: 'Level $lvl: action drop must be granted on 1st brick');
        expect(ctrl.capsules.isNotEmpty, isTrue);

        final drop = ctrl.capsules.first;
        expect(
          drop.type == PowerUpType.multiBall || drop.type == PowerUpType.fireball,
          isTrue,
          reason: 'Level $lvl: drop must be PowerUpType.multiBall or PowerUpType.fireball',
        );

        // Subsequent bricks broken in same level do not re-trigger earlyActionDropGranted
        ctrl.balls.first.x = 170;
        ctrl.balls.first.y = 110;
        ctrl.update(0.016); // Destroy brick 2
        expect(ctrl.earlyActionDropGranted, isTrue);
      }
    });

    test('Level 6 does NOT grant guaranteed early action drop', () {
      ctrl.startNewGame(GameMode.classic, explicitStartLevel: 6);
      ctrl.capsules.clear();
      expect(ctrl.earlyActionDropGranted, isFalse);

      final b1 = Brick(x: 100, y: 100, width: 40, height: 20, hp: 1, maxHp: 1, color: Colors.blue);
      final b2 = Brick(x: 150, y: 100, width: 40, height: 20, hp: 1, maxHp: 1, color: Colors.blue);
      final b3 = Brick(x: 200, y: 100, width: 40, height: 20, hp: 1, maxHp: 1, color: Colors.blue);
      ctrl.bricks = [b1, b2, b3];

      final ball = Ball(x: 120, y: 110, vx: 0, vy: -100);
      ball.isStuck = false;
      ctrl.balls.clear();
      ctrl.balls.add(ball);
      ctrl.status = GameStatus.playing;
      ctrl.update(0.016);

      // In Level 6, earlyActionDropGranted must remain false
      expect(ctrl.earlyActionDropGranted, isFalse);
    });

    test('Chaos mode does NOT grant guaranteed early action drop', () {
      ctrl.startNewGame(GameMode.chaos, explicitStartLevel: 1);
      ctrl.capsules.clear();
      expect(ctrl.earlyActionDropGranted, isFalse);

      final b1 = Brick(x: 100, y: 100, width: 40, height: 20, hp: 1, maxHp: 1, color: Colors.blue);
      final b2 = Brick(x: 150, y: 100, width: 40, height: 20, hp: 5, maxHp: 5, color: Colors.green);
      ctrl.bricks = [b1, b2];
      final ball = Ball(x: 120, y: 110, vx: 0, vy: -100);
      ball.isStuck = false;
      ctrl.balls.clear();
      ctrl.balls.add(ball);
      ctrl.status = GameStatus.playing;
      ctrl.update(0.016);

      expect(ctrl.earlyActionDropGranted, isFalse);
    });

    test('Zen mode does NOT grant guaranteed early action drop', () {
      ctrl.startNewGame(GameMode.zen, explicitStartLevel: 1);
      ctrl.capsules.clear();
      expect(ctrl.earlyActionDropGranted, isFalse);

      final b1 = Brick(x: 100, y: 100, width: 40, height: 20, hp: 1, maxHp: 1, color: Colors.blue);
      final b2 = Brick(x: 150, y: 100, width: 40, height: 20, hp: 5, maxHp: 5, color: Colors.green);
      ctrl.bricks = [b1, b2];
      final ball = Ball(x: 120, y: 110, vx: 0, vy: -100);
      ball.isStuck = false;
      ctrl.balls.clear();
      ctrl.balls.add(ball);
      ctrl.status = GameStatus.playing;
      ctrl.update(0.016);

      expect(ctrl.earlyActionDropGranted, isFalse);
    });

    test('Advancing from level 1 to level 2 resets earlyActionDropGranted for next level', () {
      ctrl.startNewGame(GameMode.classic, explicitStartLevel: 1);
      final b1 = Brick(x: 100, y: 100, width: 40, height: 20, hp: 1, maxHp: 1, color: Colors.blue);
      final dummyBrick = Brick(x: 300, y: 300, width: 40, height: 20, hp: 5, maxHp: 5, color: Colors.green);
      ctrl.bricks = [b1, dummyBrick];
      final ball = Ball(x: 120, y: 110, vx: 0, vy: -100);
      ball.isStuck = false;
      ctrl.balls.clear();
      ctrl.balls.add(ball);
      ctrl.status = GameStatus.playing;
      ctrl.update(0.016);

      expect(ctrl.earlyActionDropGranted, isTrue);

      // Load Level 2 bricks via loadLevelBricks
      ctrl.level = 2;
      ctrl.loadLevelBricks();
      expect(ctrl.level, 2);
      expect(ctrl.levelBricksBroken, 0);
      expect(ctrl.earlyActionDropGranted, isFalse);
    });
  });

  group('Milestone 1 Adversarial Suite: Onboarding & UI HUD Edge Cases', () {
    late GameController ctrl;

    setUp(() {
      ctrl = GameController();
      ctrl.setDimensions(360, 640);
    });

    test('showLevel1DragGuide lifetime: exactly 8 seconds in Level 1 Classic only', () {
      ctrl.startNewGame(GameMode.classic, explicitStartLevel: 1);
      expect(ctrl.showLevel1DragGuide, isTrue);

      // After 7.9 seconds, still visible
      ctrl.update(7.9);
      expect(ctrl.showLevel1DragGuide, isTrue);

      // At/after 8.0 seconds, dismissed
      ctrl.update(0.2);
      expect(ctrl.showLevel1DragGuide, isFalse);

      // Mode exclusions
      ctrl.startNewGame(GameMode.chaos, explicitStartLevel: 1);
      expect(ctrl.showLevel1DragGuide, isFalse);

      ctrl.startNewGame(GameMode.zen, explicitStartLevel: 1);
      expect(ctrl.showLevel1DragGuide, isFalse);

      ctrl.startNewGame(GameMode.classic, explicitStartLevel: 2);
      expect(ctrl.showLevel1DragGuide, isFalse);
    });

    test('isUltiReady boundary values: handles 0, 1.0 (1% charge), 99.9, and 100.0', () {
      ctrl.ultiCharge = 0.0;
      expect(ctrl.isUltiReady, isFalse);

      ctrl.ultiCharge = 0.5;
      expect(ctrl.isUltiReady, isFalse);

      ctrl.ultiCharge = 0.99;
      expect(ctrl.isUltiReady, isFalse);

      // 1% charge after 1 brick must NOT falsely trigger isUltiReady
      ctrl.ultiCharge = 1.0;
      expect(ctrl.isUltiReady, isFalse);

      // Normal 0..100 scale
      ctrl.ultiCharge = 99.9;
      expect(ctrl.isUltiReady, isFalse);

      ctrl.ultiCharge = 100.0;
      expect(ctrl.isUltiReady, isTrue);

      ctrl.ultiCharge = 120.0;
      expect(ctrl.isUltiReady, isTrue);
    });

    test('firstCornerHitShown triggers slow motion pulse only once per game session', () {
      ctrl.startNewGame(GameMode.classic, explicitStartLevel: 1);
      ctrl.launchBall();
      expect(ctrl.firstCornerHitShown, isFalse);

      // First corner hit
      final ball = ctrl.balls.first;
      ball.x = ctrl.paddle.x + ctrl.paddle.width * 0.97;
      ball.y = ctrl.paddle.y - ball.radius + 1.0;
      ball.vx = 0;
      ball.vy = 300.0;

      ctrl.update(0.016);
      expect(ctrl.firstCornerHitShown, isTrue);
      expect(ctrl.stats.bulletTimeLeft, 0.75);
      final initialBanners = ctrl.particles.floatingTexts.where((t) => t.text.contains('SÜPER KÖŞE VURUŞU')).length;
      expect(initialBanners, 1);

      // Reset bulletTime to test that 2nd corner hit does not re-trigger banner or 0.75 pulse
      ctrl.stats.bulletTimeLeft = 0.0;
      ball.x = ctrl.paddle.x + ctrl.paddle.width * 0.97;
      ball.y = ctrl.paddle.y - ball.radius + 1.0;
      ball.vx = 0;
      ball.vy = 300.0;

      ctrl.update(0.016);
      expect(ctrl.stats.bulletTimeLeft, 0.0);
      final secondBanners = ctrl.particles.floatingTexts.where((t) => t.text.contains('SÜPER KÖŞE VURUŞU')).length;
      expect(secondBanners, initialBanners);
    });
  });
}
