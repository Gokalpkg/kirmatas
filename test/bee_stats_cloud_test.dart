import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:kirmatas/engine/game_controller.dart';
import 'package:kirmatas/models/easter_egg.dart';
import 'package:kirmatas/models/game_state.dart';
import 'package:kirmatas/models/powerup.dart';
import 'package:kirmatas/storage/save_manager.dart';
import 'package:kirmatas/ui/kaunos_ui.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(
      const MethodChannel('xyz.luan/audioplayers.global'),
      (MethodCall methodCall) async => 1,
    );
    messenger.setMockMethodCallHandler(
      const MethodChannel('xyz.luan/audioplayers'),
      (MethodCall methodCall) async => 1,
    );
  });

  GameController startedController() {
    final ctrl = GameController();
    ctrl.startNewGame(GameMode.classic, explicitStartLevel: 1);
    // Park a single brick in a corner the ball never visits: an empty
    // board would instantly count as a cleared level.
    final keep = ctrl.bricks.last;
    ctrl.bricks.removeWhere((b) => !identical(b, keep));
    keep.x = ctrl.screenWidth - 26;
    keep.y = 84;
    ctrl.status = GameStatus.playing;
    ctrl.launchBall();
    ctrl.status = GameStatus.playing;
    return ctrl;
  }

  void pinBall(GameController ctrl, {double x = 24, double y = 60}) {
    final ball = ctrl.balls.first;
    ball.isStuck = false;
    ball.x = x;
    ball.y = y;
    ball.vx = 12;
    ball.vy = -40;
  }

  group('Bee interactions', () {
    test('fireball burns the bee and it falls off screen', () {
      final ctrl = startedController();
      ctrl.spawnEasterEggBee(customY: 220, facingRight: true);
      ctrl.applyPowerUp(PowerUpType.fireball);
      final bee = ctrl.activeBee!;
      final ball = ctrl.balls.first;
      ball.isStuck = false;
      ball.x = bee.x;
      ball.y = bee.y;

      ctrl.update(0.016);
      expect(ctrl.activeBee, isNotNull);
      expect(ctrl.activeBee!.state, BeeState.burning);

      var gone = false;
      for (var i = 0; i < 900 && !gone; i++) {
        pinBall(ctrl);
        ctrl.update(0.016);
        if (ctrl.activeBee == null) gone = true;
      }
      expect(gone, isTrue, reason: 'burned bee should fall away');
    });

    test('frost freezes the bee, then it shatters for +100', () {
      final ctrl = startedController();
      ctrl.spawnEasterEggBee(customY: 220, facingRight: true);
      ctrl.applyPowerUp(PowerUpType.frost);
      final bee = ctrl.activeBee!;
      final ball = ctrl.balls.first;
      ball.isStuck = false;
      ball.x = bee.x;
      ball.y = bee.y;

      ctrl.update(0.016);
      expect(ctrl.activeBee, isNotNull);
      expect(ctrl.activeBee!.state, BeeState.frozenFalling);

      final scoreBefore = ctrl.stats.score;
      var gone = false;
      for (var i = 0; i < 900 && !gone; i++) {
        pinBall(ctrl);
        ctrl.update(0.016);
        if (ctrl.activeBee == null) gone = true;
      }
      expect(gone, isTrue, reason: 'frozen bee should shatter away');
      expect(ctrl.stats.score, greaterThan(scoreBefore));
    });

    test('vortex drags the bee onto the paddle, marks it, then it escapes',
        () {
      final ctrl = startedController();
      ctrl.paddle.hasVortex = true;
      ctrl.spawnEasterEggBee(customY: 200, facingRight: true);
      final scoreBefore = ctrl.stats.score;

      var stuck = false;
      for (var i = 0; i < 1200 && !stuck; i++) {
        pinBall(ctrl);
        ctrl.update(0.016);
        if (ctrl.activeBee?.state == BeeState.stuckToPaddle) stuck = true;
      }
      expect(stuck, isTrue, reason: 'bee should get stuck to the paddle');
      expect(ctrl.beePaddleMarkTimer, greaterThan(0));
      expect(ctrl.stats.score, scoreBefore + 50);

      var escaped = false;
      for (var i = 0; i < 600 && !escaped; i++) {
        pinBall(ctrl);
        ctrl.update(0.016);
        final bee = ctrl.activeBee;
        if (bee != null &&
            bee.state == BeeState.flying &&
            bee.escapeVy < 0) {
          escaped = true;
        }
        if (bee == null) escaped = true; // already flew off the top
      }
      expect(escaped, isTrue, reason: 'bee should shake loose and escape');
    });
  });

  group('Lifetime stats + cloud envelope', () {
    test('records runs, deaths, clears, chaos rank and round-trips JSON',
        () async {
      SharedPreferences.setMockInitialValues({});
      final save = SaveManager.instance;
      await save.init();

      final runs0 = save.statTotalRuns;
      await save.recordRunStarted();
      expect(save.statTotalRuns, runs0 + 1);

      await save.recordClassicLevelFailed(7);
      await save.recordClassicLevelFailed(7);
      expect(save.statDeathsByLevel[7], 2);

      await save.recordClassicLevelCleared(7);
      expect(save.statClearsByLevel[7], 1);

      final bricks0 = save.statBricksBrokenTotal;
      final seconds0 = save.statPlaySeconds;
      await save.addLifetimeRunStats(bricks: 40, seconds: 90);
      expect(save.statBricksBrokenTotal, bricks0 + 40);
      expect(save.statPlaySeconds, seconds0 + 90);

      final goldEarned0 = save.statGoldEarnedTotal;
      await save.addGold(50);
      expect(save.statGoldEarnedTotal, goldEarned0 + 50);

      await save.noteBestChaosWave(12);
      expect(save.bestChaosWave, greaterThanOrEqualTo(12));
      expect(save.chaosRankTier, greaterThanOrEqualTo(2));
      expect(save.chaosRankTitle, SaveManager.chaosRankTitles[save.chaosRankTier]);

      // Cloud envelope round-trip: mutate, then import the snapshot back.
      final raw = await save.exportAllToJson();
      expect(SaveManager.cloudSavedAtMs(raw), isNotNull);

      await save.recordClassicLevelFailed(99);
      expect(save.statDeathsByLevel[99], 1);

      final ok = await save.importAllFromJson(raw);
      expect(ok, isTrue);
      expect(save.statDeathsByLevel[99], isNull);
      expect(save.statDeathsByLevel[7], 2);
    });
  });

  group('RollingNumberText', () {
    testWidgets('rolls up and down to the new value', (tester) async {
      Widget app(int v) => MaterialApp(
            home: Scaffold(body: RollingNumberText(value: v)),
          );
      await tester.pumpWidget(app(100));
      expect(find.text('100'), findsOneWidget);

      await tester.pumpWidget(app(138));
      await tester.pumpAndSettle();
      expect(find.text('138'), findsOneWidget);

      await tester.pumpWidget(app(90));
      await tester.pumpAndSettle();
      expect(find.text('90'), findsOneWidget);
    });
  });
}
