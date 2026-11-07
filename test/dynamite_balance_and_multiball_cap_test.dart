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
    test('applyPowerUp(PowerUpType.multi) and mirror are functional even when 3 balls are active', () {
      final ctrl = GameController();
      ctrl.setDimensions(360, 640);
      ctrl.startNewGame(GameMode.classic, explicitStartLevel: 1);
      ctrl.status = GameStatus.playing;

      expect(ctrl.balls.length, equals(1));

      // 1st multi: 1 -> 3 balls
      ctrl.applyPowerUp(PowerUpType.multi);
      expect(ctrl.balls.length, equals(3));

      // 2nd multi: ekranda 3 top varken alınan çoklu top kapsülü İŞLEVLİ OLMALIDIR (top eklemelidir)
      ctrl.applyPowerUp(PowerUpType.multi);
      expect(ctrl.balls.length, greaterThan(3), reason: 'Multi-ball must remain functional when taken with 3 balls');

      // Mirror powerup: ekranda 3+ top varken de İŞLEVLİ OLMALIDIR (ayna topu eklemelidir)
      final countBeforeMirror = ctrl.balls.length;
      ctrl.applyPowerUp(PowerUpType.mirror);
      expect(ctrl.balls.length, equals(countBeforeMirror + 1), reason: 'Mirror powerup must add a mirrored ball');
    });

    test('Frost and Fireball powerups smoothly replace each other without converting to multiBall', () {
      final ctrl = GameController();
      ctrl.setDimensions(360, 640);
      ctrl.startNewGame(GameMode.classic, explicitStartLevel: 1);
      ctrl.status = GameStatus.playing;

      // Apply Fireball
      ctrl.applyPowerUp(PowerUpType.fireball);
      expect(ctrl.balls.first.isFireball, isTrue);
      expect(ctrl.balls.length, equals(1));

      // Apply Frost: smoothly extinguishes Fireball and applies Frost without converting to multi-ball
      ctrl.applyPowerUp(PowerUpType.frost);
      expect(ctrl.balls.any((b) => b.isFireball), isFalse, reason: 'Fireball should be extinguished');
      expect(ctrl.balls.any((b) => b.isFrost), isTrue, reason: 'Frost should be active');
      expect(ctrl.balls.length, equals(1), reason: 'Must not create extra balls when opposing elements meet');

      // Apply Fireball again: extinguishes Frost and applies Fireball
      ctrl.applyPowerUp(PowerUpType.fireball);
      expect(ctrl.balls.any((b) => b.isFrost), isFalse, reason: 'Frost should be extinguished');
      expect(ctrl.balls.any((b) => b.isFireball), isTrue, reason: 'Fireball should be active');
      expect(ctrl.balls.length, equals(1), reason: 'Must not create extra balls when opposing elements meet');
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

    test('Multi and Mirror drop chances decrease drastically as ball count increases', () {
      final ctrl = GameController();
      ctrl.setDimensions(360, 640);
      ctrl.startNewGame(GameMode.classic, explicitStartLevel: 5);
      ctrl.status = GameStatus.playing;

      // Helper to count multi and mirror drops out of N rolls
      int countBallMultiplierDrops(int ballCount, int totalTrials) {
        ctrl.balls.clear();
        for (int i = 0; i < ballCount; i++) {
          ctrl.balls.add(Ball(x: 100.0 + i * 20, y: 300.0, vx: 50.0, vy: -100.0));
        }

        int count = 0;
        for (int i = 0; i < totalTrials; i++) {
          ctrl.capsules.clear();
          ctrl.activePowerUps.clear();
          final dropped = ctrl.rollCapsuleDropForTest(180, 200, force: true, forceBuff: true);
          if (dropped && ctrl.capsules.isNotEmpty) {
            final type = ctrl.capsules.first.type;
            if (type == PowerUpType.multi || type == PowerUpType.mirror) {
              count++;
            }
          }
        }
        return count;
      }

      // 1000 trials each
      final dropsWith1Ball = countBallMultiplierDrops(1, 1000);
      final dropsWith2Balls = countBallMultiplierDrops(2, 1000);
      final dropsWith3Balls = countBallMultiplierDrops(3, 1000);

      // Verify steep reduction
      expect(dropsWith1Ball, greaterThan(dropsWith2Balls), reason: 'Drop rate must decrease significantly with 2 balls');
      expect(dropsWith2Balls, greaterThan(dropsWith3Balls), reason: 'Drop rate must decrease drastically with 3 balls');
      expect(dropsWith3Balls, lessThanOrEqualTo(10), reason: 'Drop rate with 3 balls must be extremely rare (< 1%)');
    });
  });
}
