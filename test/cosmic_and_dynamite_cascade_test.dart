import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kirmatas/engine/game_controller.dart';
import 'package:kirmatas/models/ball.dart';
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

  group('Kozmik Kristal & Cascading Dynamite Domino Tests', () {
    test('Chained dynamites prime with delay and explode in sequence with rising pitch', () {
      final ctrl = GameController();
      ctrl.screenWidth = 400;
      ctrl.screenHeight = 800;
      ctrl.status = GameStatus.playing;
      ctrl.balls.add(Ball(x: 200, y: 700, vx: 0, vy: -200, radius: 6));
      ctrl.loadLevelBricks();
      ctrl.status = GameStatus.playing;
      ctrl.balls.add(Ball(x: 200, y: 700, vx: 0, vy: -200, radius: 6));

      // Create a chain of 3 dynamites in a line
      final dyn1 = Brick(x: 100, y: 100, width: 40, height: 20, color: Colors.red)
        ..isDynamite = true
        ..hp = 1
        ..maxHp = 1;

      final dyn2 = Brick(x: 135, y: 100, width: 40, height: 20, color: Colors.red)
        ..isDynamite = true
        ..hp = 1
        ..maxHp = 1;

      final dyn3 = Brick(x: 205, y: 100, width: 40, height: 20, color: Colors.red)
        ..isDynamite = true
        ..hp = 1
        ..maxHp = 1;

      ctrl.bricks = [dyn1, dyn2, dyn3];

      // Detonate dyn1
      ctrl.destroyBrickForTest(dyn1);

      // Frame 0: dyn1 is dead, dyn2 is primed (isPrimedDynamite = true), dyn3 is still not primed
      expect(dyn1.isAlive, isFalse);
      expect(dyn2.isAlive, isTrue);
      expect(dyn2.isPrimedDynamite, isTrue);
      expect(dyn3.isAlive, isTrue);
      expect(dyn3.isPrimedDynamite, isFalse);

      // Advance by 0.12s (120ms) to trigger dyn2
      ctrl.update(0.12);

      // Now dyn2 should have exploded and primed dyn3!
      expect(dyn2.isAlive, isFalse);
      expect(dyn3.isAlive, isTrue);
      expect(dyn3.isPrimedDynamite, isTrue);
      expect(dyn3.chainExplosionDepth, equals(2));

      // Advance past hit-stop and countdown to trigger dyn3
      ctrl.update(0.06); // clears 0.045s hit-stop crunch
      ctrl.update(0.15); // advances primed timer

      // Now dyn3 should have exploded
      expect(dyn3.isAlive, isFalse);
    });

    test('Direct ball hit on primed dynamite explodes immediately without waiting', () {
      final ctrl = GameController();
      ctrl.screenWidth = 400;
      ctrl.screenHeight = 800;
      ctrl.loadLevelBricks();

      final dyn = Brick(x: 100, y: 100, width: 40, height: 20, color: Colors.red)
        ..isDynamite = true
        ..hp = 1
        ..maxHp = 1;

      ctrl.bricks = [dyn];
      dyn.primeDynamite(delay: 0.1, depth: 1);

      expect(dyn.isPrimedDynamite, isTrue);
      expect(dyn.isAlive, isTrue);

      // Hit brick directly
      ctrl.hitBrickForTest(dyn, null);

      expect(dyn.isAlive, isFalse);
      expect(dyn.isPrimedDynamite, isFalse);
    });
  });
}
