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

  group('Chaos pacing balance', () {
    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      await SaveManager.instance.init();
    });

    GameController freshChaos() {
      final gc = GameController();
      gc.setDimensions(360, 640);
      gc.startNewGame(GameMode.chaos, explicitStartLevel: 1);
      gc.capsules.clear();
      return gc;
    }

    /// Lines up one ball per brick so a single update breaks them all,
    /// leaving one tough dummy alive so the wave does not end.
    void breakBricks(GameController gc, int count) {
      final bricks = <Brick>[];
      final balls = <Ball>[];
      for (var i = 0; i < count; i++) {
        final bx = 20.0 + (i % 6) * 55.0;
        final by = 90.0 + (i ~/ 6) * 34.0;
        bricks.add(Brick(x: bx, y: by, width: 44, height: 20, hp: 1, maxHp: 1, color: Colors.blue));
        final ball = Ball(x: bx + 22, y: by + 10, vx: 0, vy: -100);
        ball.isStuck = false;
        balls.add(ball);
      }
      bricks.add(Brick(x: 320, y: 420, width: 30, height: 20, hp: 999, maxHp: 999, color: Colors.green));
      gc.bricks = bricks;
      gc.balls
        ..clear()
        ..addAll(balls);
      gc.status = GameStatus.playing;
      gc.update(0.016);
    }

    test('a bulk volley drops at most one capsule and starts the cooldown', () {
      final gc = freshChaos();
      expect(gc.chaosCapsuleCooldown, 0);

      breakBricks(gc, 24);

      expect(gc.capsules.length, lessThanOrEqualTo(1),
          reason: 'Chaos capsules are serialized: never a rain of capsules');
      if (gc.capsules.isNotEmpty) {
        expect(gc.chaosCapsuleCooldown, greaterThan(0),
            reason: 'A dropped capsule starts the breathing-room cooldown');
      }
    });

    test('no second capsule while one is falling or cooldown runs', () {
      final gc = freshChaos();

      // Force the paced state: a capsule in the air + cooldown running.
      breakBricks(gc, 24);
      final afterFirst = gc.capsules.length;

      breakBricks(gc, 24);
      expect(gc.capsules.length, lessThanOrEqualTo(afterFirst + 0),
          reason: 'While a capsule falls / cooldown runs, no new capsule drops');
      expect(gc.capsules.length, lessThanOrEqualTo(1));
    });

    test('cooldown ticks down over time', () {
      final gc = freshChaos();
      breakBricks(gc, 24);
      final start = gc.chaosCapsuleCooldown;
      if (start == 0) return; // The volley rolled no drop this run; nothing to tick.
      gc.update(0.5);
      expect(gc.chaosCapsuleCooldown, lessThan(start));
    });

    test('chaos perks are unique: each perk can be earned only once', () {
      final gc = freshChaos();

      for (var i = 0; i < 12; i++) {
        gc.offerChaosPerksForWave();
        if (gc.offeredChaosPerks.isEmpty) break;
        expect(gc.offeredChaosPerks.toSet().length, gc.offeredChaosPerks.length,
            reason: 'Offered perks are unique');
        for (final p in gc.offeredChaosPerks) {
          expect(gc.activeChaosPerks.contains(p), isFalse,
              reason: 'Already-owned perks are never offered again');
        }
        gc.selectChaosPerk(gc.offeredChaosPerks.first);
      }

      expect(gc.activeChaosPerks.toSet().length, gc.activeChaosPerks.length,
          reason: 'Active perks never stack duplicates');
      expect(gc.activeChaosPerks.length, lessThanOrEqualTo(5),
          reason: 'A run tops out at the five distinct perks');
    });

    test('chaos boss HP is toned down at wave 10', () {
      final gc = GameController();
      gc.setDimensions(360, 640);
      gc.startNewGame(GameMode.chaos, explicitStartLevel: 10);
      final boss = gc.bricks.firstWhere((b) => b.isBoss);
      expect(boss.maxHp, 43, reason: 'Wave-10 boss: 25 + 1*18 (was 70)');
    });

    test('chaos revive clears the bottom 3 rows so death does not loop', () {
      final gc = freshChaos();
      // Six stacked rows marching on the player.
      final bricks = <Brick>[];
      for (var row = 0; row < 6; row++) {
        for (var col = 0; col < 3; col++) {
          bricks.add(Brick(
            x: 20.0 + col * 55.0,
            y: 100.0 + row * 34.0,
            width: 44,
            height: 26,
            hp: 3,
            maxHp: 3,
            color: Colors.blue,
          ));
        }
      }
      gc.bricks = bricks;
      final cleared = gc.clearChaosBottomRows(3);
      expect(cleared, 9, reason: 'Bottom 3 rows x 3 cols wiped');
      final aliveRows = gc.bricks.where((b) => b.isAlive).map((b) => b.y).toSet();
      expect(aliveRows.length, 3, reason: 'Top 3 rows survive');
      expect(gc.bricks.where((b) => b.isAlive).every((b) => b.y < 250), isTrue,
          reason: 'Nothing alive remains in the kill zone');
    });

    test('reviveWithOneLife in chaos also clears the bottom rows', () {
      final gc = freshChaos();
      final bricks = <Brick>[];
      for (var row = 0; row < 5; row++) {
        bricks.add(Brick(x: 40, y: 120.0 + row * 34.0, width: 44, height: 26, hp: 3, maxHp: 3, color: Colors.red));
      }
      gc.bricks = bricks;
      gc.status = GameStatus.gameOver;
      gc.reviveWithOneLife();
      expect(gc.bricks.where((b) => b.isAlive).length, 2,
          reason: 'Bottom 3 of 5 rows cleared by the revive rescue');
    });

    test('wave-5 offer still shows 3 fresh perks', () {
      final gc = GameController();
      gc.setDimensions(360, 640);
      gc.startNewGame(GameMode.chaos, explicitStartLevel: 5);
      expect(gc.offeredChaosPerks.length, 3);
    });
  });
}
