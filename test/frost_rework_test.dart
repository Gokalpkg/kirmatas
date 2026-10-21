import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kirmatas/engine/game_controller.dart';
import 'package:kirmatas/models/brick.dart';
import 'package:kirmatas/models/game_state.dart';
import 'package:kirmatas/models/powerup.dart';

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

  GameController makeCtrl() {
    final ctrl = GameController();
    ctrl.startNewGame(GameMode.classic, explicitStartLevel: 1);
    ctrl.status = GameStatus.playing;
    return ctrl;
  }

  Brick firstPlainBrick(GameController ctrl) {
    return ctrl.bricks.firstWhere((b) => b.isAlive && !b.isSteel && !b.isBoss);
  }

  void aimBallUpAt(GameController ctrl, Brick brick) {
    final ball = ctrl.balls.first;
    ball.isStuck = false;
    ball.x = brick.x + brick.width / 2;
    ball.y = brick.y + brick.height + ball.radius;
    ball.vx = 0.0;
    ball.vy = -200.0;
  }

  double centerDist(Brick a, Brick b) {
    final dx = (a.x + a.width / 2) - (b.x + b.width / 2);
    final dy = (a.y + a.height / 2) - (b.y + b.height / 2);
    return (dx * dx + dy * dy);
  }

  group('Frost rework (Gökalp feedback)', () {
    test('Frost ball shatters the whole connected frozen chain', () {
      final ctrl = makeCtrl();
      ctrl.applyPowerUp(PowerUpType.frost);
      expect(ctrl.balls.first.isFrost, isTrue);

      final target = firstPlainBrick(ctrl);
      // Freeze the target and every brick touching it (same threshold as BFS).
      final chain = <Brick>[target];
      for (final b in ctrl.bricks) {
        if (identical(b, target) || !b.isAlive || b.isSteel) continue;
        final dx = ((b.x + b.width / 2) - (target.x + target.width / 2)).abs();
        final dy = ((b.y + b.height / 2) - (target.y + target.height / 2)).abs();
        if (dx <= (b.width + target.width) / 2 + 10 && dy <= (b.height + target.height) / 2 + 10) {
          chain.add(b);
        }
      }
      expect(chain.length, greaterThan(1), reason: 'level 1 grid should give neighbours');
      for (final b in chain) {
        b.isFrozen = true;
      }

      aimBallUpAt(ctrl, target);
      ctrl.update(0.02);

      for (final b in chain) {
        expect(b.isAlive, isFalse, reason: 'frozen chain brick should shatter');
      }
    });

    test('Frost ball can never detonate dynamite: it freezes it instead', () {
      final ctrl = makeCtrl();
      ctrl.applyPowerUp(PowerUpType.frost);

      final dyn = firstPlainBrick(ctrl);
      dyn.isDynamite = true;
      dyn.hp = 5;
      dyn.maxHp = 5;

      final aliveBefore = ctrl.bricks.where((b) => b.isAlive).length;

      aimBallUpAt(ctrl, dyn);
      ctrl.update(0.02);

      expect(dyn.isAlive, isTrue, reason: 'dynamite must not explode under frost');
      expect(dyn.isFrozen, isTrue, reason: 'frost hit should freeze the dynamite solid');
      expect(ctrl.bricks.where((b) => b.isAlive).length, aliveBefore,
          reason: 'no brick may die from a frost-vs-dynamite hit');
    });

    test('Frost hitting a true ice brick flash-freezes a huge area', () {
      final ctrl = makeCtrl();
      ctrl.applyPowerUp(PowerUpType.frost);

      final ice = firstPlainBrick(ctrl);
      ice.isIce = true;
      ice.hp = 50;
      ice.maxHp = 50;

      aimBallUpAt(ctrl, ice);
      ctrl.update(0.02);

      final candidates = ctrl.bricks.where((b) {
        if (identical(b, ice) || !b.isAlive || b.isSteel || b.isTuft || b.isDynamite) return false;
        return centerDist(b, ice) <= 210.0 * 210.0;
      }).toList();
      expect(candidates.length, greaterThan(3), reason: 'radius 210 should cover many bricks');
      for (final b in candidates) {
        expect(b.isFrozen, isTrue, reason: 'ice-brick hit must freeze ALL bricks in the big radius');
      }
    });

    test('Fireball makes dynamite explode at double radius', () {
      final ctrl = makeCtrl();
      ctrl.applyPowerUp(PowerUpType.fireball);
      expect(ctrl.balls.first.isFireball, isTrue);

      final dyn = firstPlainBrick(ctrl);
      dyn.isDynamite = true;
      dyn.hp = 1;
      dyn.maxHp = 1;

      Brick? farNeighbour;
      for (final b in ctrl.bricks) {
        if (identical(b, dyn) || !b.isAlive || b.isSteel) continue;
        final d2 = centerDist(b, dyn);
        if (d2 > 90.0 * 90.0 && d2 < 150.0 * 150.0) {
          farNeighbour = b;
          break;
        }
      }
      expect(farNeighbour, isNotNull, reason: 'need a brick between 90 and 150 px away');
      farNeighbour!.hp = 1;
      farNeighbour.maxHp = 1;

      aimBallUpAt(ctrl, dyn);
      ctrl.update(0.02);

      expect(dyn.isAlive, isFalse);
      expect(farNeighbour.isAlive, isFalse,
          reason: 'fireball dynamite blast (160) must reach beyond the normal 80 radius');
    });

    test('Plain ball dynamite keeps the normal blast radius (control)', () {
      final ctrl = makeCtrl();

      final dyn = firstPlainBrick(ctrl);
      dyn.isDynamite = true;
      dyn.hp = 1;
      dyn.maxHp = 1;

      Brick? farNeighbour;
      for (final b in ctrl.bricks) {
        if (identical(b, dyn) || !b.isAlive || b.isSteel) continue;
        final d2 = centerDist(b, dyn);
        if (d2 > 90.0 * 90.0 && d2 < 150.0 * 150.0) {
          farNeighbour = b;
          break;
        }
      }
      expect(farNeighbour, isNotNull);
      farNeighbour!.hp = 1;
      farNeighbour.maxHp = 1;

      aimBallUpAt(ctrl, dyn);
      ctrl.update(0.02);

      expect(dyn.isAlive, isFalse);
      expect(farNeighbour.isAlive, isTrue,
          reason: 'normal dynamite blast (80) must not reach 90-150 px away');
    });
  });
}
