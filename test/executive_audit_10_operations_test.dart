import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kirmatas/engine/ad_manager.dart';
import 'package:kirmatas/engine/audio_manager.dart';
import 'package:kirmatas/engine/game_controller.dart';
import 'package:kirmatas/engine/lucky_fish_notification_manager.dart';
import 'package:kirmatas/models/ball.dart';
import 'package:kirmatas/models/brick.dart';
import 'package:kirmatas/models/fish_synergy.dart';
import 'package:kirmatas/models/game_state.dart';
import 'package:kirmatas/storage/save_manager.dart';
import 'package:kirmatas/ui/game_canvas.dart';
import 'package:kirmatas/ui/hud_overlay.dart';
import 'package:kirmatas/ui/pause_game_over.dart';
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

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await SaveManager.instance.init();
  });

  group('Operation 1: FTUE Speed Scaling', () {
    test('Base speed starts at 420.0 px/s at Level 1 and scales to 510.0 px/s without penalty', () {
      final ctrl = GameController();
      ctrl.setDimensions(360, 640);

      // Level 1: exactly 420.0
      ctrl.startNewGame(GameMode.classic, explicitStartLevel: 1);
      expect(ctrl.getBaseBallSpeed(), closeTo(420.0, 1e-6));

      // Level 5: 420.0 + 40.0 = 460.0 (no 1.15x boost)
      ctrl.startNewGame(GameMode.classic, explicitStartLevel: 5);
      expect(ctrl.getBaseBallSpeed(), closeTo(460.0, 1e-6));

      // Level 10: 420.0 + 90.0 = 510.0
      ctrl.startNewGame(GameMode.classic, explicitStartLevel: 10);
      expect(ctrl.getBaseBallSpeed(), closeTo(510.0, 1e-6));

      // Beyond level 10: clamped at 510.0
      ctrl.startNewGame(GameMode.classic, explicitStartLevel: 25);
      expect(ctrl.getBaseBallSpeed(), closeTo(510.0, 1e-6));
    });
  });

  group('Operation 2 & 10: Game Canvas Ulti Radius & Zero-Lag Paddle', () {
    testWidgets('Double-tap within 25px triggers Ulti, while taps further apart do NOT', (tester) async {
      final ctrl = GameController();
      ctrl.setDimensions(360, 640);
      ctrl.startNewGame(GameMode.classic);
      ctrl.stats.ultiCharge = 100.0;
      expect(ctrl.isUltiReady, isTrue);

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: GameCanvas(controller: ctrl),
        ),
      ));
      await tester.pump(const Duration(milliseconds: 50));

      // Tap far apart: (50, 100) then (150, 100) -> distance = 100px >= 25px
      await tester.tapAt(const Offset(50, 100));
      await tester.pump(const Duration(milliseconds: 100));
      await tester.tapAt(const Offset(150, 100));
      await tester.pump(const Duration(milliseconds: 50));

      expect(ctrl.stats.ultiActiveLeft, 0.0, reason: 'Ulti must not trigger if taps are far apart');

      // Now tap close together: (150, 100) then (155, 104) -> distance ~ 6.4px < 25px
      await tester.tapAt(const Offset(150, 100));
      await tester.pump(const Duration(milliseconds: 100));
      await tester.tapAt(const Offset(155, 104));
      await tester.pump(const Duration(milliseconds: 50));

      expect(ctrl.stats.ultiActiveLeft, greaterThan(0.0), reason: 'Ulti should trigger on close double-tap');
    });

    testWidgets('Paddle responds immediately to drag without 8px deadband delay', (tester) async {
      final ctrl = GameController();
      ctrl.setDimensions(360, 640);
      ctrl.startNewGame(GameMode.classic);
      ctrl.status = GameStatus.playing;
      final initialPaddleX = ctrl.paddle.x;

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: GameCanvas(controller: ctrl),
        ),
      ));
      await tester.pump(const Duration(milliseconds: 50));

      // Drag by only 3 pixels (less than old 8px deadband)
      final gesture = await tester.startGesture(const Offset(180, 500));
      await gesture.moveBy(const Offset(3.0, 0));
      await tester.pump(const Duration(milliseconds: 16));

      expect(ctrl.paddle.x, isNot(equals(initialPaddleX)), reason: 'Paddle must move with < 8px drag');
      await gesture.up();
      await tester.pump(const Duration(milliseconds: 16));
    });
  });

  group('Operation 3: Collision Seam Optimization', () {
    test('Seam collision properly resolves vertical gap between adjacent bricks', () {
      final ctrl = GameController();
      ctrl.setDimensions(360, 640);
      ctrl.startNewGame(GameMode.classic);
      ctrl.bricks.clear();

      final b1 = Brick(x: 100, y: 100, width: 60, height: 20, hp: 2, maxHp: 2, color: Colors.blue);
      final b2 = Brick(x: 100, y: 125, width: 60, height: 20, hp: 2, maxHp: 2, color: Colors.blue);
      ctrl.bricks.addAll([b1, b2]);

      final ball = Ball(x: 95, y: 122, vx: 200, vy: 10);
      ctrl.balls.clear();
      ctrl.balls.add(ball);

      // Updating collision with nearby seam filter
      ctrl.update(0.016);
      expect(ball.vx, lessThan(0.0), reason: 'Ball should bounce off seam barrier horizontally');
    });
  });

  group('Operation 4: AdManager Non-blocking Background Load', () {
    testWidgets('watchSkippableAd falls through within 1s without blocking PopScope dialog', (tester) async {
      final am = AdManager.instance;
      bool successCalled = false;

      await tester.pumpWidget(MaterialApp(
        home: Builder(
          builder: (context) {
            return ElevatedButton(
              onPressed: () {
                am.watchSkippableAd(
                  context,
                  onSuccess: () => successCalled = true,
                );
              },
              child: const Text('Watch'),
            );
          },
        ),
      ));

      await tester.tap(find.text('Watch'));
      // Step through 100ms ticks until the 1000ms timeout expires
      for (int i = 0; i < 15; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }

      // No PopScope dialog should be present in widget tree
      expect(find.byType(PopScope), findsNothing);
      expect(successCalled, isTrue, reason: 'Google Play compliance: player proceeds smoothly');
    });
  });

  group('Operation 5: Pentatonic Pitch Scale', () {
    test('AudioManager uses major pentatonic scale by default', () {
      expect(AudioManager.usePentatonicScale, isTrue);

      final am = AudioManager.instance;
      am.playSfx(GameSfx.hitBrick, combo: 1);
      expect(am.lastPlaybackRate, closeTo(1.000, 1e-4)); // C

      am.playSfx(GameSfx.hitBrick, combo: 2);
      expect(am.lastPlaybackRate, closeTo(1.125, 1e-4)); // D

      am.playSfx(GameSfx.hitBrick, combo: 3);
      expect(am.lastPlaybackRate, closeTo(1.250, 1e-4)); // E

      am.playSfx(GameSfx.hitBrick, combo: 4);
      expect(am.lastPlaybackRate, closeTo(1.500, 1e-4)); // G

      am.playSfx(GameSfx.hitBrick, combo: 5);
      expect(am.lastPlaybackRate, closeTo(1.667, 1e-4)); // A

      am.playSfx(GameSfx.hitBrick, combo: 6);
      expect(am.lastPlaybackRate, closeTo(2.000, 1e-4)); // C Octave
    });
  });

  group('Operation 6: Game Over Screen Hierarchy & 5s Countdown', () {
    testWidgets('Game Over screen places Revive CTA at top with 5s countdown above Restart', (tester) async {
      final ctrl = GameController();
      ctrl.setDimensions(360, 640);
      ctrl.startNewGame(GameMode.classic);
      ctrl.stats.lives = 0;
      ctrl.triggerGameOverForTest();
      expect(ctrl.canRevive, isTrue);

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: PauseGameOverOverlay(
            controller: ctrl,
            onResume: () {},
            onRestart: () {},
            onMainMenu: () {},
          ),
        ),
      ));
      await tester.pump();

      // Verify CANLAN / Revive button is present with 5s countdown badge
      expect(find.textContaining('CANLAN'), findsOneWidget);
      expect(find.text('5s'), findsOneWidget);

      // Verify hierarchy: Revive CTA is visually above Restart button
      final reviveTop = tester.getTopLeft(find.textContaining('CANLAN')).dy;
      final restartTop = tester.getTopLeft(find.byIcon(Icons.replay)).dy;
      expect(reviveTop, lessThan(restartTop), reason: 'Revive CTA must be at top of button list');
    });
  });

  group('Operation 7: Aquarium Satiety Synergy Multiplier', () {
    test('Buffs are 50% when hungry and 100% when satiated', () {
      final save = SaveManager.instance;
      save.unlockedFish = ['guppy', 'angel', 'arowana'];
      final now = DateTime.now().millisecondsSinceEpoch;

      // 1. Hungry state (unfed)
      save.fishFedTimestamps.clear();
      final hungry = FishSynergyBuffs.calculate(save);
      expect(hungry.extraPaddleWidth, closeTo(2.0, 1e-4)); // 4.0 * 0.5
      expect(hungry.critChanceBonus, closeTo(0.015, 1e-4)); // 0.03 * 0.5
      expect(hungry.goldMultiplier, closeTo(1.05, 1e-4)); // 1.0 + (0.10 * 0.5)

      // 2. Satiated state (fed)
      save.fishFedTimestamps['guppy'] = now;
      save.fishFedTimestamps['angel'] = now;
      save.fishFedTimestamps['arowana'] = now;
      final full = FishSynergyBuffs.calculate(save);
      expect(full.extraPaddleWidth, closeTo(4.0, 1e-4)); // 4.0 * 1.0
      expect(full.critChanceBonus, closeTo(0.03, 1e-4)); // 0.03 * 1.0
      expect(full.goldMultiplier, closeTo(1.10, 1e-4)); // 1.0 + (0.10 * 1.0)
    });
  });

  group('Operation 8: Wall Bounce Speed Ceiling', () {
    test('8 side wall bounces boosts by 1.15x and caps at 620.0 px/s ceiling', () {
      final ctrl = GameController();
      ctrl.setDimensions(360, 640);
      ctrl.startNewGame(GameMode.classic, explicitStartLevel: 1);
      ctrl.launchBall();

      final ball = ctrl.balls.first;
      ball.sideWallBounceCount = 7;
      ball.x = 2.0;
      ball.vx = -400.0;
      ball.vy = 300.0;
      ctrl.status = GameStatus.playing;

      ctrl.update(0.016);
      expect(ball.sideWallBounceCount, 8);
      expect(ball.isWallSpeedBoosted, isTrue);
      expect(ball.speed, lessThanOrEqualTo(620.0), reason: 'Speed must never exceed 620.0 px/s ceiling');
    });
  });

  group('Operation 9: Daily Return Retention Loops', () {
    test('LuckyFishNotificationManager manages lucky fish, aquarium feed, and wheel loops', () {
      final mgr = LuckyFishNotificationManager.instance;
      final save = SaveManager.instance;
      save.highestLevel = 5;

      save.unlockedFish = ['guppy'];
      save.fishFedTimestamps.clear();
      expect(mgr.shouldRemindAquariumFeeding, isTrue);
      final feedPayload = mgr.getAquariumFeedingNotificationPayload();
      expect(feedPayload, isNotNull);
      expect(feedPayload!['title'], contains('Yem'));

      expect(mgr.shouldRemindFortuneWheel, isTrue);
      final wheelPayload = mgr.getFortuneWheelNotificationPayload();
      expect(wheelPayload, isNotNull);
      expect(wheelPayload!['title'], contains('Çark'));

      final all = mgr.getAllPendingDailyNotificationPayloads();
      expect(all.length, greaterThanOrEqualTo(2));
    });
  });

  group('Operation 10: HUD Bar 48x48 Touch Target Standard', () {
    testWidgets('Pause button has at least 48x48 dp touch target', (tester) async {
      final ctrl = GameController();
      ctrl.setDimensions(360, 640);
      ctrl.startNewGame(GameMode.classic);

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: HudOverlay(
            controller: ctrl,
            onPause: () {},
          ),
        ),
      ));
      await tester.pumpAndSettle();

      final pauseFinder = find.byIcon(Icons.pause);
      expect(pauseFinder, findsOneWidget);
      final inkWellFinder = find.ancestor(of: pauseFinder, matching: find.byType(InkWell)).first;
      final pauseSize = tester.getSize(inkWellFinder);
      expect(pauseSize.width, greaterThanOrEqualTo(48.0));
      expect(pauseSize.height, greaterThanOrEqualTo(48.0));
    });
  });
}
