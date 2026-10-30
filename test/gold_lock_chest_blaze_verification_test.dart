import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:kirmatas/config/balance_config.dart';
import 'package:kirmatas/engine/game_controller.dart';
import 'package:kirmatas/models/brick.dart';
import 'package:kirmatas/models/cosmetics.dart';
import 'package:kirmatas/models/game_state.dart';
import 'package:kirmatas/models/level_design.dart';
import 'package:kirmatas/models/powerup.dart';
import 'package:kirmatas/storage/save_manager.dart';

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

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await SaveManager.instance.init();
  });

  GameController createCtrl(GameMode mode) {
    final ctrl = GameController();
    ctrl.setDimensions(410, 800);
    ctrl.startNewGame(mode, explicitStartLevel: 1);
    return ctrl;
  }

  group('Requirement 1 & 2: Gold Reward Gating and Rebalancing', () {
    test('Zen, Descend, and Shapes modes completely disable gold rewards', () {
      final zenController = createCtrl(GameMode.zen);
      expect(zenController.allowsGoldReward, isFalse);

      final descendController = createCtrl(GameMode.descend);
      expect(descendController.allowsGoldReward, isFalse);

      final shapesController = createCtrl(GameMode.shapes);
      expect(shapesController.allowsGoldReward, isFalse);
    });

    test('Classic and Chaos modes allow gold rewards with reduced drop rates', () {
      final classicController = createCtrl(GameMode.classic);
      expect(classicController.allowsGoldReward, isTrue);

      final chaosController = createCtrl(GameMode.chaos);
      expect(chaosController.allowsGoldReward, isTrue);

      expect(BalanceConfig.classicCoinBaseDropRate, equals(0.12));
      expect(BalanceConfig.chaosCoinBaseDropRate, equals(0.08));
    });

    test('rollEndGameGoldDice returns 0 when gold is not allowed', () {
      final zenController = createCtrl(GameMode.zen);
      final initialGold = SaveManager.instance.gold;
      final rolled = zenController.rollEndGameGoldDice(forcedDice: 6);
      expect(rolled, equals(0));
      expect(SaveManager.instance.gold, equals(initialGold));
    });
  });

  group('Requirement 3: Target Lock Power-Up Reachability', () {
    test('applyPowerUp(PowerUpType.lock) targets reachable front-row brick, not occluded brick', () {
      final controller = createCtrl(GameMode.classic);

      // Create two bricks: one in the front row and one hidden directly behind it
      final frontBrick = Brick(x: 100, y: 300, width: 60, height: 20, hp: 1, maxHp: 1, color: Colors.blue, type: BrickType.normal);
      final backBrick = Brick(x: 100, y: 250, width: 60, height: 20, hp: 1, maxHp: 1, color: Colors.red, type: BrickType.normal);
      controller.bricks
        ..clear()
        ..addAll([frontBrick, backBrick]);

      controller.applyPowerUp(PowerUpType.lock);

      expect(controller.lockedTargetBrick, isNotNull);
      // It must lock onto the front brick, not the occluded back brick
      expect(controller.lockedTargetBrick, equals(frontBrick));
    });

    test('Colliding with intermediate brick clears target lock to prevent plowing through', () {
      final controller = createCtrl(GameMode.classic);

      final obstacleBrick = Brick(x: 100, y: 350, width: 60, height: 20, hp: 2, maxHp: 2, color: Colors.amber, type: BrickType.normal);
      final targetBrick = Brick(x: 200, y: 200, width: 60, height: 20, hp: 1, maxHp: 1, color: Colors.green, type: BrickType.normal);
      controller.bricks
        ..clear()
        ..addAll([obstacleBrick, targetBrick]);

      controller.lockedTargetBrick = targetBrick;
      controller.targetLockTimer = 5.0;

      // Ball hits obstacleBrick instead of targetBrick
      controller.hitBrickForTest(obstacleBrick);

      // Lock must be cleared immediately so ball doesn't drill through
      expect(controller.lockedTargetBrick, isNull);
      expect(controller.targetLockTimer, equals(0.0));
    });
  });

  group('Requirement 4: Chest Tiers and Generation', () {
    test('Classic mode generates chest tiers 0, 1, 2, 3 according to world', () {
      final lvl2 = LevelDesign.buildClassicLevel(2, 410, 800);
      final chestLvl2 = lvl2.where((b) => b.isChest).toList();
      expect(chestLvl2, isNotEmpty);
      for (final c in chestLvl2) {
        expect(c.chestTier, equals(0)); // World 1
      }

      final lvl45 = LevelDesign.buildClassicLevel(45, 410, 800);
      final chestLvl45 = lvl45.where((b) => b.isChest).toList();
      expect(chestLvl45, isNotEmpty);
      for (final c in chestLvl45) {
        expect(c.chestTier, equals(1)); // World 2
      }

      final lvl85 = LevelDesign.buildClassicLevel(85, 410, 800);
      final chestLvl85 = lvl85.where((b) => b.isChest).toList();
      expect(chestLvl85, isNotEmpty);
      for (final c in chestLvl85) {
        expect(c.chestTier, equals(2)); // World 3
      }

      final lvl126 = LevelDesign.buildClassicLevel(126, 410, 800);
      final chestLvl126 = lvl126.where((b) => b.isChest).toList();
      expect(chestLvl126, isNotEmpty);
      for (final c in chestLvl126) {
        expect(c.chestTier, equals(3)); // World 4+
      }
    });

    test('Chaos mode generates chest tiers based on wave milestone', () {
      for (int wave = 1; wave <= 40; wave++) {
        for (int r = 0; r < 10; r++) {
          final row = LevelDesign.buildChaosRow(wave, r, 410);
          for (final b in row) {
            if (b.isChest) {
              final expectedTier = (wave >= 30) ? 3 : ((wave >= 18) ? 2 : ((wave >= 8) ? 1 : 0));
              expect(b.chestTier, equals(expectedTier));
            }
          }
        }
      }
    });
  });

  group('Requirement 5: Blaze Effect Consecutive Paddle Returns', () {
    test('isBlazeActive triggers at 3 consecutive paddle returns and resets on ball loss', () {
      final controller = createCtrl(GameMode.classic);

      expect(controller.consecutivePaddleHits, equals(0));
      expect(controller.isBlazeActive, isFalse);

      controller.consecutivePaddleHits = 1;
      expect(controller.isBlazeActive, isFalse);

      controller.consecutivePaddleHits = 2;
      expect(controller.isBlazeActive, isFalse);

      controller.consecutivePaddleHits = 3;
      expect(controller.isBlazeActive, isTrue);

      controller.consecutivePaddleHits = 5;
      expect(controller.isBlazeActive, isTrue);

      // When ball drops / paddle resets, blaze extinguishes immediately
      controller.resetPaddleAndBall();
      expect(controller.consecutivePaddleHits, equals(0));
      expect(controller.isBlazeActive, isFalse);
    });
  });

  group('Requirement 6: Pre-Game Boosters Pricing and Match Start Restriction', () {
    test('Boosters have updated costs: 400, 550, 750', () {
      final lifeBoost = BoostItem.allBoosts.firstWhere((b) => b.id == 'life');
      final wideBoost = BoostItem.allBoosts.firstWhere((b) => b.id == 'wide');
      final multiBoost = BoostItem.allBoosts.firstWhere((b) => b.id == 'multi');

      expect(lifeBoost.cost, equals(400));
      expect(wideBoost.cost, equals(550));
      expect(multiBoost.cost, equals(750));
    });

    test('controller.isMatchStart is true initially and becomes false when playing starts', () {
      final controller = createCtrl(GameMode.classic);

      expect(controller.isMatchStart, isTrue);
      expect(controller.status, equals(GameStatus.ready));

      // Launch ball
      controller.launchBall();
      expect(controller.status, equals(GameStatus.playing));
      expect(controller.isMatchStart, isFalse);
    });

    test('buyAndActivatePreMatchBoost deducts proper cost and activates boost', () async {
      final save = SaveManager.instance;
      save.gold = 1000;
      final controller = createCtrl(GameMode.classic);

      final ok = await controller.buyAndActivatePreMatchBoost('life');
      expect(ok, isTrue);
      expect(save.gold, equals(600)); // 1000 - 400
      expect(controller.stats.lives, equals(4)); // 3 + 1
      expect(controller.usedPreMatchBoosts.contains('life'), isTrue);
    });
  });
}
