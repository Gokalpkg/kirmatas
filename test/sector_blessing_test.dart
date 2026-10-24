import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kirmatas/engine/game_controller.dart';
import 'package:kirmatas/models/ball.dart';
import 'package:kirmatas/models/game_state.dart';
import 'package:kirmatas/models/sector_blessing.dart';
import 'package:kirmatas/models/paddle.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

  late GameController c;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    c = GameController();
    c.setDimensions(360, 640);
  });

  group('Sector Blessings & Option C Mechanics', () {
    test('Corner-Hit Mega Ball expands effectiveRadius and sets megaTimer', () {
      final ball = Ball(x: 100, y: 100, radius: 7.5);
      expect(ball.megaTimer, 0.0);
      expect(ball.effectiveRadius, 7.5);

      ball.megaTimer = 2.5;
      expect(ball.effectiveRadius, greaterThan(13.0));

      ball.update(1.0);
      expect(ball.megaTimer, closeTo(1.5, 0.01));
      expect(ball.effectiveRadius, greaterThan(13.0));

      ball.update(1.6);
      expect(ball.megaTimer, 0.0);
      expect(ball.effectiveRadius, 7.5);
    });

    test('Sector Blessing offer and selection mechanics', () {
      expect(c.offeredSectorBlessings, isEmpty);
      expect(c.awaitingSectorBlessingSelection, isFalse);
      expect(c.activeSectorBlessing, isNull);

      c.offerSectorBlessings();
      expect(c.offeredSectorBlessings.length, 3);
      expect(c.awaitingSectorBlessingSelection, isTrue);

      final chosen = c.offeredSectorBlessings.first;
      c.selectSectorBlessing(chosen);

      expect(c.awaitingSectorBlessingSelection, isFalse);
      expect(c.offeredSectorBlessings, isEmpty);
      expect(c.activeSectorBlessing, chosen);
    });

    test('Boss bullet tennis deflects projectile upward as player rocket', () {
      c.startNewGame(GameMode.classic);
      c.status = GameStatus.playing;

      // Add a boss bullet falling towards paddle
      final bullet = Projectile(
        x: c.paddle.x + c.paddle.width / 2,
        y: c.paddle.y + 4.0,
        vx: 0,
        vy: 120.0,
        radius: 6.0,
        isBossBullet: true,
      );
      c.projectiles.add(bullet);

      expect(bullet.isBossBullet, isTrue);
      expect(bullet.isRocket, isFalse);

      c.update(0.016);

      // Bullet should be deflected into rocket moving upward
      expect(bullet.isBossBullet, isFalse);
      expect(bullet.isRocket, isTrue);
      expect(bullet.vy, lessThan(0.0));
    });

    test('Emergency Clutch rescues falling ball once per stage', () {
      c.startNewGame(GameMode.classic);
      c.status = GameStatus.playing;
      c.activeSectorBlessing = SectorBlessing.getById('emergency_clutch');
      c.emergencyClutchUsedThisStage = false;

      expect(c.balls.length, 1);
      final ball = c.balls.first;
      ball.isStuck = false;
      ball.x = c.paddle.x + c.paddle.width / 2;
      ball.y = c.screenHeight + 10.0; // falling out of bounds
      ball.vy = 200.0;

      c.update(0.016);

      // Ball should NOT be lost, clutch rescues it!
      expect(c.balls.isNotEmpty, isTrue);
      expect(c.emergencyClutchUsedThisStage, isTrue);
      expect(c.balls.first.vy, lessThan(0.0)); // deflected upward
    });
  });
}
