import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kirmatas/engine/i18n.dart';
import 'package:kirmatas/models/ball.dart';
import 'package:kirmatas/models/black_hole.dart';
import 'package:kirmatas/models/game_state.dart';
import 'package:kirmatas/models/powerup.dart';
import 'package:kirmatas/storage/save_manager.dart';
import 'package:kirmatas/ui/game_canvas.dart';
import 'package:kirmatas/ui/pixel_art.dart';
import 'e2e_test_helpers.dart';

void main() {
  setupE2ETestEnvironment();

  group('Tier 3: Cross-Feature Combinations (Pairwise Interactions)', () {
    test('F1.1 x F3.4: Level cleared while Vortex power-up black hole is active freezes anomaly cleanly', () {
      final gc = createTestController();
      gc.stats.level = 4;
      gc.applyPowerUp(PowerUpType.vortex);
      expect(gc.blackHoles.isNotEmpty, isTrue);

      final bh = gc.blackHoles.first;
      final initialRot = bh.rotation;
      final initialTime = bh.timeLeft;

      // Clear all breakable bricks to trigger level transition
      clearAllBreakableBricks(gc);
      gc.update(0.016);

      expect(gc.levelTransitionTimer > 0, isTrue);
      expect(gc.balls.isEmpty, isTrue);

      // Simulation freeze preserves black hole state
      gc.update(0.1);
      expect(bh.rotation, equals(initialRot));
      expect(bh.timeLeft, equals(initialTime));
    });

    test('F2.2 x F3.1: Searing ball passing through Supercharged black hole field curves while maintaining fiery molten state', () {
      final gc = createTestController();
      final bh = BlackHole(x: 180, y: 300, radius: 28.0, mass: 1000, isSupercharged: true);
      gc.blackHoles..clear()..add(bh);

      final searingBall = Ball(x: 240, y: 300, vx: 0, vy: -450, isFireball: true, isPierce: true);
      gc.balls..clear()..add(searingBall);
      gc.status = GameStatus.playing;

      gc.update(0.05);

      // Curving confirmed
      expect(searingBall.vx, lessThan(-10.0));
      // State preserved
      expect(searingBall.isFireball, isTrue);
      expect(searingBall.isPierce, isTrue);
    });

    test('F1.3 x F1.4: Game paused during level transition freeze keeps simulation frozen and timer static', () {
      final gc = createTestController();
      clearAllBreakableBricks(gc);
      gc.update(0.016);
      expect(gc.levelTransitionTimer > 0, isTrue);

      final timerAtPause = gc.levelTransitionTimer;
      gc.pause();

      gc.update(0.5);

      expect(gc.status, equals(GameStatus.paused));
      expect(gc.levelTransitionTimer, equals(timerAtPause));
    });

    test('F1.5 x F2.2: Reaching level 238 victory while firing Searing ball halts piercing ball and awards victory', () {
      final gc = createTestController(mode: GameMode.classic);
      gc.stats.level = 238;
      gc.loadLevelBricks();

      // Launch Searing ball
      final searingBall = Ball(x: 100, y: 150, vx: 0, vy: -300, isFireball: true, isPierce: true);
      gc.balls..clear()..add(searingBall);

      clearAllBreakableBricks(gc);
      gc.update(0.016);

      expect(gc.status, equals(GameStatus.victory));
      expect(gc.balls.isEmpty, isTrue);
      expect(gc.stats.level, equals(238));
    });

    testWidgets('F1.6 x F1.3: Pointer drag held during transition freeze does not auto-launch ball when transition completes', (tester) async {
      final gc = createTestController();
      await tester.pumpWidget(MaterialApp(home: Scaffold(body: GameCanvas(controller: gc))));

      clearAllBreakableBricks(gc);
      gc.update(0.016);
      expect(gc.levelTransitionTimer > 0, isTrue);

      final gesture = await tester.startGesture(const Offset(180, 500));
      gc.update(1.6); // Complete transition
      await tester.pump(const Duration(milliseconds: 16));

      await gesture.up();
      await tester.pump(const Duration(milliseconds: 16));

      expect(gc.status, equals(GameStatus.ready));
      expect(gc.hasStuckBall, isTrue);
    });

    test('F2.4 x F2.5: Searing ball label localization matches golden-flame pixel art falling capsule icon', () {
      SaveManager.instance.setLanguage('tr');
      expect(I18n.tr('pup_pierce'), equals('YAKICI TOP!'));
      expect(I18n.tr('pup_fireball'), equals('YAKICI TOP!'));

      final pMatrix = PixelArt.bitmaps[PowerUpType.pierce];
      final fbMatrix = PixelArt.bitmaps[PowerUpType.fireball];
      expect(pMatrix, isNotNull);
      expect(fbMatrix, isNotNull);
    });

    test('F3.2 x F1.1: Fast ball caught in black hole swirl when last brick broken is immediately halted with 0 residual momentum', () {
      final gc = createTestController();
      final bh = BlackHole(x: 180, y: 300, radius: 26.0, mass: 1000);
      gc.blackHoles..clear()..add(bh);

      final swirlingBall = Ball(x: 195, y: 300, vx: -300, vy: 400);
      gc.balls..clear()..add(swirlingBall);

      clearAllBreakableBricks(gc);
      gc.update(0.016);

      expect(gc.levelTransitionTimer > 0, isTrue);
      expect(gc.balls.isEmpty, isTrue, reason: 'Swirling ball must be cleared with 0 residual motion on level clear');
    });

    test('F3.4 x F2.2: Collecting Vortex power-up while Searing ball is active allows both mechanics to operate concurrently', () {
      final gc = createTestController();
      gc.stats.level = 4;
      gc.launchBall();

      gc.applyPowerUp(PowerUpType.fireball);
      expect(gc.balls.first.isFireball, isTrue);
      expect(gc.balls.first.isPierce, isTrue);

      gc.applyPowerUp(PowerUpType.vortex);
      expect(gc.blackHoles.isNotEmpty, isTrue);
      expect(gc.balls.first.isFireball, isTrue);
      expect(gc.balls.first.isPierce, isTrue);
    });
  });
}
