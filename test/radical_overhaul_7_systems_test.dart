import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kirmatas/models/brick.dart';
import 'package:kirmatas/models/fish_synergy.dart';
import 'package:kirmatas/models/powerup.dart';
import 'package:kirmatas/storage/save_manager.dart';
import 'e2e/e2e_test_helpers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    setupE2ETestEnvironment();
  });

  group('System 1: Live Aquarium Synergy & Fish Food Loop', () {
    test('FishSynergyBuffs computes active passives correctly', () async {
      final save = SaveManager.instance;
      await save.init();
      save.unlockedFish = ['guppy', 'tetra', 'arowana', 'discus', 'octopus'];
      save.ownedFishCounts['octopus'] = 1;

      final buffs = FishSynergyBuffs.calculate(save);
      expect(buffs.hasArowanaRicochet, isTrue);
      expect(buffs.hasOctopusClutchSave, isTrue);
      expect(buffs.hasTetraSwarm, isTrue);
      expect(buffs.hasDiscusBlast, isTrue);
      expect(buffs.foodDropBonus, greaterThan(0.0));
      expect(buffs.activeBuffDescriptions, isNotEmpty);
    });

    test('Collecting PowerUpType.food grants fishFood directly to aquarium', () async {
      final save = SaveManager.instance;
      await save.init();
      final initialFood = save.fishFood;

      final controller = createTestController();
      controller.applyPowerUp(PowerUpType.food);

      expect(save.fishFood, equals(initialFood + 1));
      controller.dispose();
    });
  });

  group('System 2: Brick HP Ceiling & Sonar Smart Guidance', () {
    test('Smart Sonar Angle Guidance guides ball towards last remaining brick', () {
      final controller = createTestController();
      controller.paddle.x = 100;
      controller.paddle.width = 100;
      controller.paddle.y = 500;
      // Set only 1 remaining brick to the right
      controller.bricks.clear();
      final targetBrick = Brick(
        x: 300,
        y: 100,
        width: 40,
        height: 20,
        hp: 3,
        maxHp: 3,
        color: Colors.blue,
      );
      controller.bricks.add(targetBrick);

      controller.launchBall();
      final ball = controller.balls.first;
      ball.isStuck = false;
      // Hit right half of paddle with angled offset
      ball.x = 175;
      ball.y = 495;
      ball.vy = 200;
      ball.vx = 50;

      controller.update(0.016);

      // Ball should have upward velocity and rightward inclination guided towards target brick
      expect(ball.vy, lessThan(0.0));
      expect(ball.vx, greaterThan(0.0));
      controller.dispose();
    });

    test('Boss bricks preserve their full HP above 12', () {
      final bossBrick = Brick(
        x: 10,
        y: 10,
        width: 100,
        height: 40,
        hp: 50,
        maxHp: 50,
        isBoss: true,
        color: Colors.purple,
      );

      expect(bossBrick.hp, equals(50));
      expect(bossBrick.maxHp, equals(50));
    });
  });

  group('System 4: Architecture & Safe Atomic Persistence', () {
    test('SaveManager dirty tracking and flush work properly', () async {
      final save = SaveManager.instance;
      await save.init();

      expect(save.isDirty, isFalse);
      save.markDirty();
      expect(save.isDirty, isTrue);

      await save.flush();
      expect(save.isDirty, isFalse);
    });

    test('safeSave executes transactional persistence block', () async {
      final save = SaveManager.instance;
      await save.init();

      bool executed = false;
      await save.safeSave(() async {
        executed = true;
      });

      expect(executed, isTrue);
      expect(save.isDirty, isFalse);
    });
  });

  group('System 5: Kaunos Championship League Tier Integrity', () {
    test('League tier thresholds and rivals function seamlessly', () async {
      final save = SaveManager.instance;
      await save.init();

      save.leagueTier = 0; // Bronze
      final bronzeRivals = save.getLeagueRivals();
      expect(bronzeRivals.length, equals(15));
      expect(bronzeRivals.any((r) => r.isPlayer), isTrue);

      save.leagueTier = 4; // Kaunos Champions
      final championRivals = save.getLeagueRivals();
      expect(championRivals.length, equals(15));
      expect(championRivals.first.score, greaterThan(bronzeRivals.first.score));
    });
  });

  group('System 6: Physics Paddle Edge Protection & Object Pooling', () {
    test('GameController paddle collision clamps vy upwards on tip hits', () {
      final controller = createTestController();
      controller.paddle.x = 100;
      controller.paddle.width = 100;
      controller.paddle.y = 500;

      controller.launchBall();
      // Create a ball right on the left tip of paddle (hitOffset ~ -0.9)
      final tipBall = controller.balls.first;
      tipBall.isStuck = false;
      tipBall.x = 105;
      tipBall.y = 502;
      tipBall.vy = 200;
      tipBall.vx = -50;

      // Step physics
      controller.update(0.016);

      // Vy must be negative (firm upward deflection)
      expect(tipBall.vy, lessThan(0.0));
      controller.dispose();
    });
  });
}
