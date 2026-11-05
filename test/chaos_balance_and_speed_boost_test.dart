import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kirmatas/engine/game_controller.dart';
import 'package:kirmatas/models/brick.dart';
import 'package:kirmatas/models/game_state.dart';
import 'package:kirmatas/models/level_design.dart';

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

    test('Chaos Mode: Bomb deals damage equal to its maxHp only to adjacent 1-block neighbors', () {
      final controller = GameController();
      controller.currentMode = GameMode.chaos;

      final bomb2Hp = Brick(
        x: 100,
        y: 100,
        width: 40,
        height: 20,
        hp: 2,
        maxHp: 2,
        isDynamite: true,
        color: Colors.orange,
      );
      final neighborAdjacentTough = Brick(
        x: 140, // Adjacent horizontally (1 block away)
        y: 100,
        width: 40,
        height: 20,
        hp: 30,
        maxHp: 30,
        color: Colors.green,
      );
      final neighborAdjacentWeak = Brick(
        x: 100,
        y: 128, // Adjacent vertically (1 block away)
        width: 40,
        height: 20,
        hp: 2,
        maxHp: 2,
        color: Colors.blue,
      );
      final distantBrick = Brick(
        x: 220, // 2+ blocks away
        y: 100,
        width: 40,
        height: 20,
        hp: 10,
        maxHp: 10,
        color: Colors.purple,
      );
      controller.bricks.addAll([bomb2Hp, neighborAdjacentTough, neighborAdjacentWeak, distantBrick]);

      // Destroy 2-HP bomb
      controller.destroyBrickForTest(bomb2Hp);

      // 1-block tough neighbor takes 2 damage: 30 - 2 = 28 HP, still alive!
      expect(neighborAdjacentTough.isAlive, isTrue);
      expect(neighborAdjacentTough.hp, equals(28));

      // 1-block weak neighbor takes 2 damage: 2 - 2 = 0 HP, destroyed!
      expect(neighborAdjacentWeak.isAlive, isFalse);
      expect(neighborAdjacentWeak.hp, equals(0));

      // Distant brick beyond 1 block radius takes NO damage!
      expect(distantBrick.isAlive, isTrue);
      expect(distantBrick.hp, equals(10));
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

    test('Chaos Mode: Colors change distinctly as HP increases', () {
      // Normal bricks HP progression colors
      final c1 = LevelDesign.getChaosBrickColor(1);
      final c2 = LevelDesign.getChaosBrickColor(2);
      final c5 = LevelDesign.getChaosBrickColor(5);
      final c10 = LevelDesign.getChaosBrickColor(10);
      final c25 = LevelDesign.getChaosBrickColor(25);
      final c50 = LevelDesign.getChaosBrickColor(50);
      final c100 = LevelDesign.getChaosBrickColor(100);

      expect(c1 != c2, isTrue, reason: '1 HP and 2 HP have distinct colors');
      expect(c2 != c5, isTrue, reason: '2 HP and 5 HP have distinct colors');
      expect(c5 != c10, isTrue, reason: '5 HP and 10 HP have distinct colors');
      expect(c10 != c25, isTrue, reason: '10 HP and 25 HP have distinct colors');
      expect(c25 != c50, isTrue, reason: '25 HP and 50 HP have distinct colors');
      expect(c50 != c100, isTrue, reason: '50 HP and 100 HP have distinct colors');

      // Dynamite HP base colors
      final dynC1 = LevelDesign.getChaosDynamiteBaseColor(1);
      final dynC2 = LevelDesign.getChaosDynamiteBaseColor(2);
      final dynC4 = LevelDesign.getChaosDynamiteBaseColor(4);
      final dynC6 = LevelDesign.getChaosDynamiteBaseColor(6);
      expect(dynC1 != dynC2, isTrue);
      expect(dynC2 != dynC4, isTrue);
      expect(dynC4 != dynC6, isTrue);
    });

    test('Chaos Mode: Initial 4-row board has only 1 ball pickup (nerfed from 4)', () {
      final initialBoard = LevelDesign.buildChaosLevel(1, 360, 640);
      final pickups = initialBoard.where((b) => b.isBallPickup).toList();
      expect(pickups.length, equals(1), reason: 'Initial board must not spawn 4 ball pickups');
    });

    test('Chaos Mode: Ball hits dynamically update brick color to match new HP', () {
      final controller = GameController();
      controller.currentMode = GameMode.chaos;

      final brick = Brick(
        x: 100,
        y: 100,
        width: 40,
        height: 20,
        hp: 5,
        maxHp: 5,
        color: LevelDesign.getChaosBrickColor(5),
      );
      controller.bricks.add(brick);

      // Hit brick for 1 damage
      controller.hitBrickForTest(brick);
      expect(brick.hp, equals(4));
      expect(brick.color, equals(LevelDesign.getChaosBrickColor(4)));
    });

    test('Chaos Mode: 3-HP dynamite survives first 2 hits and deals 3 damage to neighbors upon 3rd hit', () {
      final controller = GameController();
      controller.currentMode = GameMode.chaos;

      final dyn3Hp = Brick(
        x: 100,
        y: 100,
        width: 40,
        height: 20,
        hp: 3,
        maxHp: 3,
        isDynamite: true,
        color: LevelDesign.getChaosDynamiteBaseColor(3),
      );
      final neighbor = Brick(
        x: 140,
        y: 100,
        width: 40,
        height: 20,
        hp: 10,
        maxHp: 10,
        color: Colors.green,
      );
      controller.bricks.addAll([dyn3Hp, neighbor]);

      // 1st hit: drops to 2 HP, does NOT explode
      controller.hitBrickForTest(dyn3Hp);
      expect(dyn3Hp.isAlive, isTrue);
      expect(dyn3Hp.hp, equals(2));
      expect(dyn3Hp.color, equals(LevelDesign.getChaosDynamiteBaseColor(2)));
      expect(neighbor.hp, equals(10)); // neighbor untouched

      // 2nd hit: drops to 1 HP, does NOT explode
      controller.hitBrickForTest(dyn3Hp);
      expect(dyn3Hp.isAlive, isTrue);
      expect(dyn3Hp.hp, equals(1));
      expect(dyn3Hp.color, equals(LevelDesign.getChaosDynamiteBaseColor(1)));
      expect(neighbor.hp, equals(10)); // neighbor untouched

      // 3rd hit: drops to 0 HP, EXPLODES and deals 3 damage to neighbor!
      controller.hitBrickForTest(dyn3Hp);
      expect(dyn3Hp.isAlive, isFalse);
      expect(neighbor.isAlive, isTrue);
      expect(neighbor.hp, equals(7)); // 10 - 3 = 7
    });

    test('Chaos Mode: 4-HP dynamite survives _explodeArea splash with 2 HP remaining', () {
      final controller = GameController();
      controller.currentMode = GameMode.chaos;

      final dyn4Hp = Brick(
        x: 100,
        y: 100,
        width: 40,
        height: 20,
        hp: 4,
        maxHp: 4,
        isDynamite: true,
        color: LevelDesign.getChaosDynamiteBaseColor(4),
      );
      controller.bricks.add(dyn4Hp);

      // Area blast centered on (100, 100)
      controller.explodeArea(120, 110, radius: 60.0);

      // Survives at 2 HP in Chaos Mode instead of being instantly detonated!
      expect(dyn4Hp.isAlive, isTrue);
      expect(dyn4Hp.hp, equals(2));
      expect(dyn4Hp.color, equals(LevelDesign.getChaosDynamiteBaseColor(2)));
    });
  });
}
