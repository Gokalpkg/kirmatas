import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kirmatas/engine/game_controller.dart';
import 'package:kirmatas/models/ball.dart';
import 'package:kirmatas/models/brick.dart';
import 'package:kirmatas/models/game_state.dart';
import 'package:kirmatas/models/powerup.dart';
import 'package:kirmatas/models/sector_blessing.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(
      const MethodChannel('xyz.luan/audioplayers.global'),
      (MethodCall methodCall) async => 1,
    );
    messenger.setMockMethodCallHandler(
      const MethodChannel('xyz.luan/audioplayers'),
      (MethodCall methodCall) async => 1,
    );
  });

  group('Dynamite Balance & 1-Damage Neighbor Tests (Non-Chaos Modes)', () {
    test('Non-chaos dynamite deals strictly 1 damage to immediate adjacent neighbors only', () {
      final ctrl = GameController();
      ctrl.setDimensions(400, 800);
      ctrl.startNewGame(GameMode.classic, explicitStartLevel: 1);
      ctrl.status = GameStatus.playing;

      // Center dynamite at (100, 100)
      final centerDyn = Brick(x: 100, y: 100, width: 40, height: 20, color: Colors.red, isDynamite: true, hp: 1, maxHp: 1);

      // Immediate neighbor 1: right neighbor (x: 145, y: 100) with 3 HP
      final rightNeighbor = Brick(x: 145, y: 100, width: 40, height: 20, color: Colors.blue, hp: 3, maxHp: 3);

      // Immediate neighbor 2: bottom neighbor (x: 100, y: 125) with 2 HP
      final bottomNeighbor = Brick(x: 100, y: 125, width: 40, height: 20, color: Colors.green, hp: 2, maxHp: 2);

      // Far brick: 3 blocks away (x: 250, y: 100) with 2 HP
      final farBrick = Brick(x: 250, y: 100, width: 40, height: 20, color: Colors.yellow, hp: 2, maxHp: 2);

      ctrl.bricks = [centerDyn, rightNeighbor, bottomNeighbor, farBrick];

      // Detonate center dynamite
      ctrl.destroyBrickForTest(centerDyn);

      // Center dynamite is destroyed
      expect(centerDyn.isAlive, isFalse);

      // Immediate neighbors must have lost EXACTLY 1 HP and survived
      expect(rightNeighbor.isAlive, isTrue);
      expect(rightNeighbor.hp, equals(2), reason: '3-HP neighbor should lose exactly 1 HP');

      expect(bottomNeighbor.isAlive, isTrue);
      expect(bottomNeighbor.hp, equals(1), reason: '2-HP neighbor should lose exactly 1 HP');

      // Far brick must NOT take any damage
      expect(farBrick.isAlive, isTrue);
      expect(farBrick.hp, equals(2), reason: 'Far brick must not be affected by local explosion');
    });

    test('Non-chaos dynamite does not wipe multi-HP dynamites in one hit', () {
      final ctrl = GameController();
      ctrl.setDimensions(400, 800);
      ctrl.startNewGame(GameMode.classic, explicitStartLevel: 1);
      ctrl.status = GameStatus.playing;

      final dyn1 = Brick(x: 100, y: 100, width: 40, height: 20, color: Colors.red, isDynamite: true, hp: 1, maxHp: 1);
      final dyn2 = Brick(x: 145, y: 100, width: 40, height: 20, color: Colors.red, isDynamite: true, hp: 3, maxHp: 3);

      ctrl.bricks = [dyn1, dyn2];

      ctrl.destroyBrickForTest(dyn1);

      expect(dyn1.isAlive, isFalse);
      expect(dyn2.isAlive, isTrue, reason: '3-HP dynamite should take 1 damage and stay alive');
      expect(dyn2.hp, equals(2));
      expect(dyn2.isPrimedDynamite, isFalse, reason: 'Non-dead dynamite must not prime');
    });
  });

  group('Ball Proliferation & Multiball Cap Tests', () {
    test('applyPowerUp(PowerUpType.multi) caps at 3 balls in Classic mode', () {
      final ctrl = GameController();
      ctrl.setDimensions(360, 640);
      ctrl.startNewGame(GameMode.classic, explicitStartLevel: 1);
      ctrl.status = GameStatus.playing;

      expect(ctrl.balls.length, equals(1));

      // 1st multi: 1 -> 3 balls
      ctrl.applyPowerUp(PowerUpType.multi);
      expect(ctrl.balls.length, equals(3));

      final scoreBefore = ctrl.stats.score;

      // 2nd multi: already at 3 balls, must remain 3 balls and award bonus score
      ctrl.applyPowerUp(PowerUpType.multi);
      expect(ctrl.balls.length, equals(3), reason: 'Classic mode must hard cap at 3 balls');
      expect(ctrl.stats.score, greaterThan(scoreBefore));

      // Mirror powerup must also respect the 3-ball cap
      ctrl.applyPowerUp(PowerUpType.mirror);
      expect(ctrl.balls.length, equals(3), reason: 'Mirror powerup must not exceed 3 balls cap');
    });

    test('Opposite element powerup converts to multi without exceeding 3-ball cap and preserves primary element', () {
      final ctrl = GameController();
      ctrl.setDimensions(360, 640);
      ctrl.startNewGame(GameMode.classic, explicitStartLevel: 1);
      ctrl.status = GameStatus.playing;

      // Apply Fireball
      ctrl.applyPowerUp(PowerUpType.fireball);
      expect(ctrl.balls.first.isFireball, isTrue);
      expect(ctrl.balls.length, equals(1));

      // Apply Frost: converts to multi without giving frost, stays fireball, capped at 3
      ctrl.applyPowerUp(PowerUpType.frost);
      expect(ctrl.balls.first.isFireball, isTrue);
      expect(ctrl.balls.any((b) => b.isFrost), isFalse);
      expect(ctrl.balls.length, equals(3), reason: 'Opposite element capsule converts to multi-ball');

      // Subsequent opposite element powerups must not exceed 3 balls cap
      ctrl.applyPowerUp(PowerUpType.frost);
      expect(ctrl.balls.length, equals(3), reason: 'Must not exceed 3 balls cap in classic mode');
    });

    test('Prismatic Splitter blessing does not spontaneously clone balls on paddle hit', () {
      final ctrl = GameController();
      ctrl.setDimensions(360, 640);
      ctrl.startNewGame(GameMode.classic, explicitStartLevel: 1);
      ctrl.status = GameStatus.playing;

      final blessing = SectorBlessing.all.firstWhere((b) => b.type == SectorBlessingType.prismaticSplitter);
      ctrl.activeSectorBlessing = blessing;

      ctrl.balls.clear();
      final loneBall = Ball(
        x: ctrl.paddle.x + ctrl.paddle.width / 2,
        y: ctrl.paddle.y - 7.0,
        vx: 50.0,
        vy: 200.0,
        radius: 7.0,
      );
      ctrl.balls.add(loneBall);

      // Simulate 10 paddle bounces
      for (int i = 0; i < 10; i++) {
        loneBall.x = ctrl.paddle.x + ctrl.paddle.width / 2;
        loneBall.y = ctrl.paddle.y - 7.0;
        loneBall.vy = 200.0;
        ctrl.checkBallPaddleCollisionForTest(loneBall);
      }

      // Ball count must strictly remain 1
      expect(ctrl.balls.length, equals(1), reason: 'Ball must never clone spontaneously on paddle bounces');
    });
  });
}
