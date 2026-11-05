import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:kirmatas/engine/game_controller.dart';
import 'package:kirmatas/models/ball.dart';
import 'package:kirmatas/models/brick.dart';
import 'package:kirmatas/models/game_state.dart';
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

  group('Faz 2 - Taktiksel Bulmaca Tuğlaları (Problem 5)', () {
    test('Prism Deflector: Deflects ball velocity vector by 90 degrees', () {
      final ctrl = GameController();
      ctrl.setDimensions(400, 800);
      ctrl.startNewGame(GameMode.classic, explicitStartLevel: 1);
      ctrl.launchBall();

      // Place a Prism Deflector at (180, 300) with prismAngle > 0
      final prism = Brick(
        x: 180,
        y: 300,
        width: 40,
        height: 20,
        hp: 5,
        maxHp: 5,
        color: Colors.cyan,
        isPrism: true,
        prismAngle: pi / 4,
      );
      ctrl.bricks = [prism];

      // Ball heading straight up (vx = 0, vy = -300)
      ctrl.balls.clear();
      final ball = Ball(x: 200, y: 325, isStuck: false);
      ball.vx = 0.0;
      ball.vy = -300.0;
      ctrl.balls.add(ball);

      // Advance physics into prism
      ctrl.update(0.05);

      // Ball should have bounced and deflected 90 degrees: vx != 0
      expect(ball.vx.abs(), greaterThan(100.0), reason: 'Prism should redirect ball 90 degrees horizontally');
      expect(prism.hp, lessThan(5), reason: 'Prism takes damage');
    });

    test('Beacon Generator: Shields nearby bricks from all damage until Beacon is broken', () {
      final ctrl = GameController();
      ctrl.setDimensions(400, 800);
      ctrl.startNewGame(GameMode.classic, explicitStartLevel: 1);
      ctrl.launchBall();

      // Beacon at (200, 200), radius 95
      final beacon = Brick(
        x: 180,
        y: 200,
        width: 40,
        height: 20,
        hp: 3,
        maxHp: 3,
        color: Colors.blue,
        isBeacon: true,
        beaconRadius: 95.0,
      );

      // Target brick within beacon radius (dx = 30px, dy = 0)
      final protectedBrick = Brick(
        x: 230,
        y: 200,
        width: 40,
        height: 20,
        hp: 2,
        maxHp: 2,
        color: Colors.green,
      );
      ctrl.bricks = [beacon, protectedBrick];

      // Hit protected brick directly with a ball
      ctrl.balls.clear();
      final ball = Ball(x: 250, y: 225, isStuck: false);
      ball.vx = 0.0;
      ball.vy = -300.0;
      ctrl.balls.add(ball);

      ctrl.update(0.05);

      // Protected brick must NOT take damage because Beacon is still alive!
      expect(protectedBrick.hp, equals(2), reason: 'Protected brick must take 0 damage while Beacon is alive');

      // Now destroy the Beacon!
      beacon.hp = 0;
      beacon.isAlive = false;

      // Ball hits protected brick again
      ball.y = 225;
      ball.vy = -300.0;
      ctrl.update(0.05);

      // Now protected brick takes damage!
      expect(protectedBrick.hp, lessThan(2), reason: 'Protected brick takes damage once Beacon is destroyed');
    });

    test('Chain Core: Breaking Key brick instantly detonates all connected Locked bricks', () {
      final ctrl = GameController();
      ctrl.setDimensions(400, 800);
      ctrl.startNewGame(GameMode.classic, explicitStartLevel: 1);
      ctrl.launchBall();

      final keyBrick = Brick(
        x: 180,
        y: 300,
        width: 40,
        height: 20,
        hp: 1,
        maxHp: 1,
        color: Colors.amber,
        isChainKey: true,
        chainKeyId: 1,
      );

      final locked1 = Brick(
        x: 50,
        y: 100,
        width: 40,
        height: 20,
        hp: 5,
        maxHp: 5,
        color: Colors.grey,
        isChainLocked: true,
        chainKeyId: 1,
      );

      final locked2 = Brick(
        x: 300,
        y: 100,
        width: 40,
        height: 20,
        hp: 5,
        maxHp: 5,
        color: Colors.grey,
        isChainLocked: true,
        chainKeyId: 1,
      );

      // Extra steel brick so level does not immediately transition
      final steel = Brick(x: 10, y: 10, width: 40, height: 20, hp: 999, maxHp: 999, color: Colors.grey, isSteel: true);

      ctrl.bricks = [keyBrick, locked1, locked2, steel];

      // Hit Key brick
      ctrl.balls.clear();
      final ball = Ball(x: 200, y: 325, isStuck: false);
      ball.vx = 0.0;
      ball.vy = -300.0;
      ctrl.balls.add(ball);

      ctrl.update(0.05);

      // Key brick is destroyed
      expect(keyBrick.isAlive, isFalse);
      // Both locked bricks must be destroyed simultaneously!
      expect(locked1.isAlive, isFalse, reason: 'Locked brick 1 must detonate when Key is broken');
      expect(locked2.isAlive, isFalse, reason: 'Locked brick 2 must detonate when Key is broken');
    });

    test('Ticker Bomb: Breaking before 15s timer awards +100 gold bonus', () {
      final ctrl = GameController();
      ctrl.setDimensions(400, 800);
      ctrl.startNewGame(GameMode.classic, explicitStartLevel: 1);
      ctrl.launchBall();

      final ticker = Brick(
        x: 180,
        y: 300,
        width: 40,
        height: 20,
        hp: 1,
        maxHp: 1,
        color: Colors.orange,
        isTicker: true,
        tickerTimer: 15.0,
      );
      final regular = Brick(x: 10, y: 10, width: 40, height: 20, hp: 5, maxHp: 5, color: Colors.blue);
      ctrl.bricks = [ticker, regular];

      final startingGold = ctrl.stats.goldCollected;

      // Hit ticker while timer is still 15s
      ctrl.balls.clear();
      final ball = Ball(x: 200, y: 325, isStuck: false);
      ball.vx = 0.0;
      ball.vy = -300.0;
      ctrl.balls.add(ball);

      ctrl.update(0.05);

      // Ticker destroyed and awarded +100 bonus gold!
      expect(ticker.isAlive, isFalse);
      expect(ctrl.stats.goldCollected, greaterThanOrEqualTo(startingGold + 100));
    });

    test('Ticker Bomb: Expired timer crystallizes into obsidian steel obstacle', () {
      final ctrl = GameController();
      ctrl.setDimensions(400, 800);
      ctrl.startNewGame(GameMode.classic, explicitStartLevel: 1);
      ctrl.launchBall();

      final expiringTicker = Brick(
        x: 180,
        y: 400,
        width: 40,
        height: 20,
        hp: 1,
        maxHp: 1,
        color: Colors.orange,
        isTicker: true,
        tickerTimer: 0.1,
      );
      final regular = Brick(x: 10, y: 10, width: 40, height: 20, hp: 5, maxHp: 5, color: Colors.blue);
      ctrl.bricks = [expiringTicker, regular];

      // Advance time by 0.2s so timer expires
      ctrl.update(0.2);

      expect(expiringTicker.tickerExpired, isTrue);
      expect(expiringTicker.isSteel, isTrue, reason: 'Expired ticker crystallizes into obsidian steel obstacle');
    });
  });
}
