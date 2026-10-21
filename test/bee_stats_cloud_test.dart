import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:kirmatas/engine/game_controller.dart';
import 'package:kirmatas/models/black_hole.dart';
import 'package:kirmatas/models/easter_egg.dart';
import 'package:kirmatas/models/game_state.dart';
import 'package:kirmatas/models/portal.dart';
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

    test('vortex drags the bee onto the paddle, where it is crushed dead',
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
      expect(stuck, isTrue, reason: 'bee should get pinned to the paddle');
      expect(ctrl.beePaddleMarkTimer, greaterThan(0));
      // No points yet: the +50 lands when the crush actually kills it.
      expect(ctrl.stats.score, scoreBefore);

      var crushed = false;
      for (var i = 0; i < 600 && !crushed; i++) {
        pinBall(ctrl);
        ctrl.update(0.016);
        if (ctrl.activeBee == null) crushed = true;
      }
      expect(crushed, isTrue, reason: 'pinned bee must be crushed dead');
      expect(ctrl.stats.score, scoreBefore + 50);
    });

    test('black hole bends the bee lane but can never pin it to the paddle',
        () {
      final ctrl = startedController();
      ctrl.paddle.hasVortex = false;
      ctrl.blackHoles.add(BlackHole(
        x: ctrl.screenWidth / 2,
        y: 320,
        radius: 30,
        mass: 30.0 * 5000.0,
        timeLeft: 30.0,
        isSupercharged: true,
      ));
      ctrl.spawnEasterEggBee(customY: 200, facingRight: true);
      final beeY = ctrl.activeBee!.baseY;

      var deflected = false;
      var touchedPaddle = false;
      for (var i = 0; i < 900; i++) {
        pinBall(ctrl);
        ctrl.update(0.016);
        final bee = ctrl.activeBee;
        if (bee == null) break; // flew off screen on its own — fine
        if (bee.state == BeeState.stuckToPaddle) touchedPaddle = true;
        if ((bee.baseY - beeY).abs() > 6.0) deflected = true;
        // Even at its lowest, the bee stays far above the paddle: the
        // hole bends its lane, it never hauls it down.
        expect(bee.y, lessThan(ctrl.paddle.y - 120.0));
      }
      expect(deflected, isTrue,
          reason: 'the hole should visibly bend the bee off its lane');
      expect(touchedPaddle, isFalse,
          reason: 'only a Vortex power-up may pin the bee to the paddle');
    });

    test('bee flies into a portal and out of the linked one', () {
      final ctrl = startedController();
      final entry = Portal(
        x: 120,
        y: 220,
        radius: 26,
        color: const Color(0xFF00E5FF),
        isBlue: true,
      );
      final exit = Portal(
        x: 300,
        y: 260,
        radius: 26,
        color: const Color(0xFFFFAB00),
        isBlue: false,
      );
      entry.linkedPortal = exit;
      exit.linkedPortal = entry;
      ctrl.portals.addAll([entry, exit]);

      ctrl.spawnEasterEggBee(customY: 220, facingRight: true);

      var hopped = false;
      for (var i = 0; i < 900 && !hopped; i++) {
        pinBall(ctrl);
        ctrl.update(0.016);
        final bee = ctrl.activeBee;
        if (bee == null) break;
        if (bee.x > 290 && bee.state == BeeState.flying) hopped = true;
      }
      expect(hopped, isTrue,
          reason: 'bee should emerge beside the linked portal');
      expect(ctrl.activeBee, isNotNull);
      expect((ctrl.activeBee!.baseY - 260).abs(), lessThan(1.0),
          reason: 'bee adopts the exit portal lane');
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
