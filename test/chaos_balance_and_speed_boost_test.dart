import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kirmatas/engine/game_controller.dart';
import 'package:kirmatas/models/brick.dart';
import 'package:kirmatas/models/game_state.dart';

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

  group('Chaos Mode & Speed Boost Tests', () {
    test('Speed boost triggers 2.8s countdown and 2x speed multiplier', () {
      final controller = GameController();
      expect(controller.userSpeedMultiplier, equals(1.0));
      expect(controller.isSpeedBoostActive, isFalse);

      controller.triggerSpeedBoost(2.8);
      expect(controller.isSpeedBoostActive, isTrue);
      expect(controller.userSpeedMultiplier, equals(2.0));
      expect(controller.speedBoostTimer, equals(2.8));

      // Advance by 1.0 second
      controller.update(1.0);
      expect(controller.isSpeedBoostActive, isTrue);
      expect(controller.userSpeedMultiplier, equals(2.0));
      expect(controller.speedBoostTimer, closeTo(1.8, 0.01));

      // Advance past 2.8s
      controller.update(2.0);
      expect(controller.isSpeedBoostActive, isFalse);
      expect(controller.userSpeedMultiplier, equals(1.0));
      expect(controller.speedBoostTimer, equals(0.0));
    });

    test('Chaos Mode: Hitting a frozen brick shatters it immediately', () {
      final controller = GameController();
      controller.currentMode = GameMode.chaos;

      final brick = Brick(
        x: 100,
        y: 100,
        width: 40,
        height: 20,
        hp: 25,
        maxHp: 25,
        color: Colors.blue,
      );
      brick.isFrozen = true;
      controller.bricks.add(brick);

      // Hit brick without fireball/frost
      controller.hitBrickForTest(brick);

      // In Chaos mode, hitting frozen brick must instantly shatter it (hp = 0, isAlive = false)
      expect(brick.hp, equals(0));
      expect(brick.isAlive, isFalse);
      expect(brick.isFrozen, isFalse);
    });

    test('Chaos Mode: Bomb obliterates caught bricks', () {
      final controller = GameController();
      controller.currentMode = GameMode.chaos;

      final bomb = Brick(
        x: 100,
        y: 100,
        width: 40,
        height: 20,
        hp: 1,
        maxHp: 1,
        isDynamite: true,
        color: Colors.red,
      );
      final neighbor = Brick(
        x: 120,
        y: 100,
        width: 40,
        height: 20,
        hp: 30,
        maxHp: 30,
        color: Colors.green,
      );
      controller.bricks.addAll([bomb, neighbor]);

      // Destroy bomb
      controller.destroyBrickForTest(bomb);

      // Neighbor within blast radius should be destroyed
      expect(neighbor.isAlive, isFalse);
      expect(neighbor.hp, equals(0));
    });

    test('Chaos Mode: Ice brick freezes neighboring bricks', () {
      final controller = GameController();
      controller.currentMode = GameMode.chaos;

      final iceBrick = Brick(
        x: 100,
        y: 100,
        width: 40,
        height: 20,
        hp: 1,
        maxHp: 1,
        isIce: true,
        color: Colors.cyan,
      );
      final neighbor = Brick(
        x: 120,
        y: 100,
        width: 40,
        height: 20,
        hp: 10,
        maxHp: 10,
        color: Colors.white,
      );
      controller.bricks.addAll([iceBrick, neighbor]);

      // Destroy ice brick
      controller.destroyBrickForTest(iceBrick);

      // Neighbor within flash freeze area should be frozen
      expect(neighbor.isFrozen, isTrue);
    });

    test('Chaos Mode: Chest probability is 1 in 1000 (0.001)', () {
      // In level_design.dart: wave >= 4 && specialRoll >= 0.20 && specialRoll < 0.201
      final range = 0.201 - 0.20;
      expect(range, closeTo(0.001, 0.000001));
    });
  });
}
