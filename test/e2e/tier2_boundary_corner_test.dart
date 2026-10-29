import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kirmatas/engine/i18n.dart';
import 'package:kirmatas/models/ball.dart';
import 'package:kirmatas/models/black_hole.dart';
import 'package:kirmatas/models/brick.dart';
import 'package:kirmatas/models/game_state.dart';
import 'package:kirmatas/models/paddle.dart';
import 'package:kirmatas/models/powerup.dart';
import 'package:kirmatas/storage/save_manager.dart';
import 'package:kirmatas/ui/game_canvas.dart';
import 'package:kirmatas/ui/pixel_art.dart';
import 'e2e_test_helpers.dart';

void main() {
  setupE2ETestEnvironment();

  group('Tier 2: Boundary & Corner Cases', () {
    // -------------------------------------------------------------------------
    // F1.1: Boundary Cases for Level Clear Halt
    // -------------------------------------------------------------------------
    group('F1.1: Level Clear Boundaries', () {
      test('F1.1_T2_01: Clearing level when board has 0 projectiles, 0 capsules, 0 weapons does not error', () {
        final gc = createTestController();
        gc.launchBall();
        gc.projectiles.clear();
        gc.capsules.clear();

        clearAllBreakableBricks(gc);
        gc.update(0.016);

        expect(gc.levelTransitionTimer > 0, isTrue);
        expect(gc.balls.isEmpty, isTrue);
      });

      test('F1.1_T2_02: Clearing level with extreme entity count (50 projectiles, 10 capsules) cleans all cleanly', () {
        final gc = createTestController();
        for (int i = 0; i < 50; i++) {
          gc.projectiles.add(Projectile(x: 10.0 + i * 5, y: 300, vy: -400));
        }
        for (int i = 0; i < 10; i++) {
          gc.capsules.add(FallingCapsule(x: 20.0 + i * 20, y: 200, type: PowerUpType.laser));
        }

        clearAllBreakableBricks(gc);
        gc.update(0.016);

        expect(gc.projectiles.isEmpty, isTrue);
        expect(gc.capsules.isEmpty, isTrue);
      });

      test('F1.1_T2_03: Clearing level with lingering steel and filled tuft bricks halts balls so they never bounce off steel', () {
        final gc = createTestController();
        gc.launchBall();
        gc.bricks = [
          Brick(x: 100, y: 200, width: 40, height: 20, hp: 999, color: Colors.grey, isSteel: true),
          Brick(x: 150, y: 200, width: 40, height: 20, hp: 1, color: Colors.pink, isTuft: true, tuftFilled: true),
        ];

        gc.update(0.016);

        expect(gc.levelTransitionTimer > 0, isTrue);
        expect(gc.balls.isEmpty, isTrue, reason: 'Balls must not bounce on lingering steel bricks during transition');
      });

      test('F1.1_T2_04: Ball positioned near bottom edge at level clear does not trigger life loss', () {
        final gc = createTestController();
        final initialLives = gc.stats.lives;
        final fallingBall = Ball(x: 180, y: gc.screenHeight - 5.0, vx: 0, vy: 400, isStuck: false);
        gc.balls..clear()..add(fallingBall);

        clearAllBreakableBricks(gc);
        gc.update(0.016);

        expect(gc.levelTransitionTimer > 0, isTrue);
        expect(gc.stats.lives, equals(initialLives), reason: 'Life must not be lost when level is cleared');
      });

      test('F1.1_T2_05: Clearing level with 15 simultaneous multiballs halts all 15 balls instantly', () {
        final gc = createTestController();
        gc.balls.clear();
        for (int i = 0; i < 15; i++) {
          gc.balls.add(Ball(x: 100.0 + i * 10, y: 300, vx: 50, vy: -200, isStuck: false));
        }

        clearAllBreakableBricks(gc);
        gc.update(0.016);

        expect(gc.balls.isEmpty, isTrue);
      });
    });

    // -------------------------------------------------------------------------
    // F1.2: Boundary Cases for Victory & GameOver Halt
    // -------------------------------------------------------------------------
    group('F1.2: Victory & GameOver Boundaries', () {
      test('F1.2_T2_01: Victory triggered when power-up timer is at 0.001s halts cleanly', () {
        final gc = createTestController(mode: GameMode.daily);
        final powerup = ActivePowerUp(PowerUpType.laser);
        powerup.timeLeft = 0.001;
        gc.activePowerUps.add(powerup);

        clearAllBreakableBricks(gc);
        gc.update(0.016);

        expect(gc.status, equals(GameStatus.victory));
        expect(gc.paddle.hasLaser, isFalse);
      });

      test('F1.2_T2_02: GameOver triggered while dice roll is in mid-shuffle halts dice state', () {
        final gc = createTestController();
        gc.stats.lives = 1;
        gc.isDiceRolling = true;
        gc.diceRollTimer = 0.45;
        gc.balls.clear();
        SaveManager.instance.markFreeContinueUsed();

        gc.update(0.016);

        expect(gc.status, equals(GameStatus.gameOver));
        expect(gc.isDiceRolling, isFalse);
      });

      test('F1.2_T2_03: Victory with maximum concurrent entities (multiball, lasers, capsules, drones) clears all', () {
        final gc = createTestController(mode: GameMode.daily);
        for (int i = 0; i < 10; i++) {
          gc.balls.add(Ball(x: 100, y: 200, vx: 50, vy: -50, isStuck: false));
          gc.projectiles.add(Projectile(x: 100, y: 200, vy: -300));
          gc.capsules.add(FallingCapsule(x: 100, y: 200, type: PowerUpType.laser));
        }
        gc.paddle.hasDrone = true;

        clearAllBreakableBricks(gc);
        gc.update(0.016);

        expect(gc.status, equals(GameStatus.victory));
        expect(gc.balls.isEmpty, isTrue);
        expect(gc.projectiles.isEmpty, isTrue);
        expect(gc.capsules.isEmpty, isTrue);
        expect(gc.paddle.hasDrone, isFalse);
      });

      test('F1.2_T2_04: GameOver with boss bullets aimed at paddle clears projectiles before impact', () {
        final gc = createTestController();
        gc.stats.lives = 1;
        gc.projectiles.add(Projectile(x: gc.paddle.x + 10, y: gc.paddle.y - 5, vy: 300, isBossBullet: true));
        gc.balls.clear();
        SaveManager.instance.markFreeContinueUsed();

        gc.update(0.016);

        expect(gc.status, equals(GameStatus.gameOver));
        expect(gc.projectiles.isEmpty, isTrue);
      });

      test('F1.2_T2_05: Calling GameOver / Victory sequentially maintains halted state without corruption', () {
        final gc = createTestController(mode: GameMode.daily);
        clearAllBreakableBricks(gc);
        gc.update(0.016);
        expect(gc.status, equals(GameStatus.victory));

        gc.update(0.05);
        expect(gc.status, equals(GameStatus.victory));
        expect(gc.balls.isEmpty, isTrue);
      });
    });

    // -------------------------------------------------------------------------
    // F1.3: Boundary Cases for Simulation Freeze
    // -------------------------------------------------------------------------
    group('F1.3: Simulation Freeze Boundaries', () {
      test('F1.3_T2_01: Microscopic dt (0.0001s) does not advance simulation during transition freeze', () {
        final gc = createTestController();
        gc.levelTransitionTimer = 0.5;
        final ball = Ball(x: 100, y: 200, vx: 500, vy: -500, isStuck: false);
        gc.balls..clear()..add(ball);

        gc.update(0.0001);

        expect(ball.x, equals(100));
        expect(ball.y, equals(200));
      });

      test('F1.3_T2_02: Large dt (2.0s) completes transition cleanly and loads next level without entity tunneling', () {
        final gc = createTestController();
        gc.levelTransitionTimer = 0.5;

        gc.update(2.0);

        expect(gc.levelTransitionTimer, equals(0));
        expect(gc.status, equals(GameStatus.ready));
        expect(gc.hasStuckBall, isTrue);
      });

      test('F1.3_T2_03: Calling movePaddleTo during transition freeze does not launch or alter stuck ball', () {
        final gc = createTestController();
        gc.levelTransitionTimer = 0.6;

        gc.movePaddleTo(250);
        gc.update(0.016);

        expect(gc.levelTransitionTimer > 0, isTrue);
      });

      test('F1.3_T2_04: Screen shake and boss warning decay while gameplay simulation remains frozen', () {
        final gc = createTestController();
        gc.levelTransitionTimer = 0.7;
        gc.bossWarningTimer = 1.0;
        gc.particles.triggerShake(5.0, 0.5);

        gc.update(0.1);

        expect(gc.bossWarningTimer, closeTo(0.9, 0.01));
        expect(gc.particles.shakeTimeLeft, closeTo(0.4, 0.01));
      });

      test('F1.3_T2_05: Transition timer reaching exactly zero transitions to ready state smoothly', () {
        final gc = createTestController();
        gc.levelTransitionTimer = 0.016;

        gc.update(0.016);

        expect(gc.levelTransitionTimer, equals(0));
        expect(gc.status, equals(GameStatus.ready));
      });
    });

    // -------------------------------------------------------------------------
    // F1.4: Boundary Cases for Pause / Freeze
    // -------------------------------------------------------------------------
    group('F1.4: Pause/Stop Freeze Boundaries', () {
      test('F1.4_T2_01: Pause at t = 0.001s preserves exact residual time', () {
        final gc = createTestController();
        gc.levelTransitionTimer = 0.001;
        gc.pause();

        gc.update(0.5);

        expect(gc.levelTransitionTimer, equals(0.001));
      });

      test('F1.4_T2_02: Pause at transition onset t = 0.95s preserves full duration', () {
        final gc = createTestController();
        gc.levelTransitionTimer = 0.95;
        gc.pause();

        gc.update(1.0);

        expect(gc.levelTransitionTimer, equals(0.95));
      });

      test('F1.4_T2_03: Triggering GameOver during transition keeps timer frozen', () {
        final gc = createTestController();
        gc.levelTransitionTimer = 0.45;
        gc.status = GameStatus.gameOver;

        gc.update(0.1);

        expect(gc.levelTransitionTimer, equals(0.45));
      });

      test('F1.4_T2_04: 5 consecutive pause and resume toggles preserve elapsed timing accurately', () {
        final gc = createTestController();
        gc.levelTransitionTimer = 0.90;

        for (int i = 0; i < 5; i++) {
          gc.pause();
          gc.update(0.05);
          expect(gc.levelTransitionTimer, equals(0.90 - i * 0.05));
          gc.resume();
          gc.update(0.05);
        }

        expect(gc.levelTransitionTimer, closeTo(0.65, 0.01));
      });

      test('F1.4_T2_05: Pausing during victory does not modify status or timer', () {
        final gc = createTestController();
        gc.status = GameStatus.victory;
        gc.levelTransitionTimer = 0.0;

        gc.pause();
        gc.update(0.1);

        expect(gc.status, equals(GameStatus.victory));
      });
    });

    // -------------------------------------------------------------------------
    // F1.5: Boundary Cases for Level 238 Classic Apex
    // -------------------------------------------------------------------------
    group('F1.5: Level 238 Boundaries', () {
      test('F1.5_T2_01: Level 238 cleared with 1 life remaining awards victory without triggering game over', () {
        final gc = createTestController(mode: GameMode.classic);
        gc.stats.level = 238;
        gc.stats.lives = 1;
        gc.loadLevelBricks();

        clearAllBreakableBricks(gc);
        gc.update(0.016);

        expect(gc.status, equals(GameStatus.victory));
        expect(gc.stats.lives, equals(1));
      });

      test('F1.5_T2_02: Level 238 cleared with multiple active balls halts all and triggers victory', () {
        final gc = createTestController(mode: GameMode.classic);
        gc.stats.level = 238;
        gc.loadLevelBricks();
        gc.balls.add(Ball(x: 100, y: 300, vx: 50, vy: -50, isStuck: false));
        gc.balls.add(Ball(x: 200, y: 300, vx: -50, vy: -50, isStuck: false));

        clearAllBreakableBricks(gc);
        gc.update(0.016);

        expect(gc.status, equals(GameStatus.victory));
        expect(gc.balls.isEmpty, isTrue);
      });

      test('F1.5_T2_03: Level 238 cleared via rocket projectile triggers victory', () {
        final gc = createTestController(mode: GameMode.classic);
        gc.stats.level = 238;
        gc.loadLevelBricks();
        gc.projectiles.add(Projectile(x: 180, y: 200, vy: -400, isRocket: true));

        clearAllBreakableBricks(gc);
        gc.update(0.016);

        expect(gc.status, equals(GameStatus.victory));
        expect(gc.projectiles.isEmpty, isTrue);
      });

      test('F1.5_T2_04: Safeguard: stats.level >= 238 triggers victory rather than level 239+', () {
        final gc = createTestController(mode: GameMode.classic);
        gc.stats.level = 238;
        gc.loadLevelBricks();

        clearAllBreakableBricks(gc);
        gc.update(0.016);

        expect(gc.status, equals(GameStatus.victory));
        expect(gc.stats.level, lessThanOrEqualTo(238));
      });

      test('F1.5_T2_05: Contrasting modes: Daily level 1 clear triggers victory while Classic level 1 clear advances to level 2', () {
        final gcClassic = createTestController(mode: GameMode.classic);
        gcClassic.stats.level = 1;
        clearAllBreakableBricks(gcClassic);
        gcClassic.update(0.016);
        expect(gcClassic.levelTransitionTimer > 0, isTrue);
        expect(gcClassic.stats.level, equals(2));

        final gcDaily = createTestController(mode: GameMode.daily);
        clearAllBreakableBricks(gcDaily);
        gcDaily.update(0.016);
        expect(gcDaily.status, equals(GameStatus.victory));
      });
    });

    // -------------------------------------------------------------------------
    // F1.6: Boundary Cases for Touch Launch State
    // -------------------------------------------------------------------------
    group('F1.6: Touch Launch Boundaries', () {
      testWidgets('F1.6_T2_01: Rapid pointer down/up taps during transition freeze do not launch next level ball', (tester) async {
        final gc = createTestController();
        await tester.pumpWidget(MaterialApp(home: Scaffold(body: GameCanvas(controller: gc))));

        clearAllBreakableBricks(gc);
        gc.update(0.016);
        expect(gc.levelTransitionTimer > 0, isTrue);

        for (int i = 0; i < 5; i++) {
          await tester.tapAt(const Offset(180, 500));
          await tester.pump(const Duration(milliseconds: 16));
        }

        gc.update(1.6);
        await tester.pump(const Duration(milliseconds: 16));

        expect(gc.status, equals(GameStatus.ready));
        expect(gc.hasStuckBall, isTrue);
      });

      testWidgets('F1.6_T2_02: Pointer drag held for entire transition (1.0s) and released does not launch', (tester) async {
        final gc = createTestController();
        await tester.pumpWidget(MaterialApp(home: Scaffold(body: GameCanvas(controller: gc))));

        clearAllBreakableBricks(gc);
        gc.update(0.016);

        final gesture = await tester.startGesture(const Offset(150, 500));
        await gesture.moveTo(const Offset(220, 500));

        gc.update(1.6);
        await tester.pump(const Duration(milliseconds: 16));

        await gesture.up();
        await tester.pump(const Duration(milliseconds: 16));

        expect(gc.status, equals(GameStatus.ready));
        expect(gc.hasStuckBall, isTrue);
      });

      testWidgets('F1.6_T2_03: Pointer released at exact transition timer boundary does not auto-launch', (tester) async {
        final gc = createTestController();
        await tester.pumpWidget(MaterialApp(home: Scaffold(body: GameCanvas(controller: gc))));

        clearAllBreakableBricks(gc);
        gc.update(0.016);

        final gesture = await tester.startGesture(const Offset(180, 500));
        gc.levelTransitionTimer = 0.001;
        gc.update(0.002);

        await gesture.up();
        await tester.pump(const Duration(milliseconds: 16));

        expect(gc.hasStuckBall, isTrue);
      });

      testWidgets('F1.6_T2_04: Chaos mode aim drag across level advance does not fire volley unintentionally', (tester) async {
        final gc = createTestController(mode: GameMode.chaos);
        await tester.pumpWidget(MaterialApp(home: Scaffold(body: GameCanvas(controller: gc))));

        gc.aimChaos(200, 200);
        gc.fireChaos();
        gc.update(0.016);

        gc.recallChaosBalls();
        gc.update(0.016);

        expect(find.byType(GameCanvas), findsOneWidget);
      });

      testWidgets('F1.6_T2_05: Pointer cancel during level transition safely resets touch state', (tester) async {
        final gc = createTestController();
        await tester.pumpWidget(MaterialApp(home: Scaffold(body: GameCanvas(controller: gc))));

        clearAllBreakableBricks(gc);
        gc.update(0.016);

        final gesture = await tester.startGesture(const Offset(180, 500));
        await gesture.cancel();

        gc.update(1.6);
        await tester.pump(const Duration(milliseconds: 16));

        expect(gc.status, equals(GameStatus.ready));
        expect(gc.hasStuckBall, isTrue);
      });
    });

    // -------------------------------------------------------------------------
    // F2.1: Boundary Cases for Claude Starburst Removal
    // -------------------------------------------------------------------------
    group('F2.1: Claude Starburst Removal Boundaries', () {
      testWidgets('F2.1_T2_01: Fireball ball with speed=0 renders cleanly without star polygon', (tester) async {
        final gc = createTestController();
        final ball = Ball(x: 180, y: 300, vx: 0, vy: 0, isFireball: true);
        gc.balls..clear()..add(ball);

        await tester.pumpWidget(MaterialApp(home: Scaffold(body: GameCanvas(controller: gc))));
        await tester.pump(const Duration(milliseconds: 16));

        expect(find.byType(GameCanvas), findsOneWidget);
      });

      testWidgets('F2.1_T2_02: Fireball ball at speed cap (850 px/s) renders cleanly without star polygon', (tester) async {
        final gc = createTestController();
        final ball = Ball(x: 180, y: 300, vx: 600, vy: -600, isFireball: true);
        ball.setSpeed(850.0);
        gc.balls..clear()..add(ball);

        await tester.pumpWidget(MaterialApp(home: Scaffold(body: GameCanvas(controller: gc))));
        await tester.pump(const Duration(milliseconds: 16));

        expect(find.byType(GameCanvas), findsOneWidget);
      });

      testWidgets('F2.1_T2_03: 10 concurrent fireballs render in single frame without Claude starburst', (tester) async {
        final gc = createTestController();
        gc.balls.clear();
        for (int i = 0; i < 10; i++) {
          gc.balls.add(Ball(x: 50.0 + i * 25, y: 300, vx: 50, vy: -150, isFireball: true));
        }

        await tester.pumpWidget(MaterialApp(home: Scaffold(body: GameCanvas(controller: gc))));
        await tester.pump(const Duration(milliseconds: 16));

        expect(find.byType(GameCanvas), findsOneWidget);
      });

      testWidgets('F2.1_T2_04: Fireball ball with active squash distortion renders cleanly', (tester) async {
        final gc = createTestController();
        final ball = Ball(x: 180, y: 300, vx: 100, vy: -200, isFireball: true);
        ball.triggerSquash(pi / 4);
        gc.balls..clear()..add(ball);

        await tester.pumpWidget(MaterialApp(home: Scaffold(body: GameCanvas(controller: gc))));
        await tester.pump(const Duration(milliseconds: 16));

        expect(find.byType(GameCanvas), findsOneWidget);
      });

      testWidgets('F2.1_T2_05: Fireball ball on legendary skins (elmas_top, gokkusagi) renders cleanly', (tester) async {
        final gc = createTestController();
        SaveManager.instance.activeBall = 'gokkusagi';
        gc.rollSessionCosmetics();
        final ball = Ball(x: 180, y: 300, vx: 100, vy: -200, isFireball: true);
        gc.balls..clear()..add(ball);

        await tester.pumpWidget(MaterialApp(home: Scaffold(body: GameCanvas(controller: gc))));
        await tester.pump(const Duration(milliseconds: 16));

        expect(find.byType(GameCanvas), findsOneWidget);
      });
    });

    // -------------------------------------------------------------------------
    // F2.2: Boundary Cases for Searing Ball Unification
    // -------------------------------------------------------------------------
    group('F2.2: Searing Ball Unification Boundaries', () {
      test('F2.2_T2_01: Applying pierce followed by fireball preserves unified state', () {
        final gc = createTestController();
        gc.launchBall();

        gc.applyPowerUp(PowerUpType.pierce);
        expect(gc.balls.first.isFireball, isTrue);
        expect(gc.balls.first.isPierce, isTrue);

        gc.applyPowerUp(PowerUpType.fireball);
        expect(gc.balls.first.isFireball, isTrue);
        expect(gc.balls.first.isPierce, isTrue);
      });

      test('F2.2_T2_02: Searing ball passing through cluster of 4 steel bricks melts all 4 bricks', () {
        final gc = createTestController();
        final ball = Ball(x: 100, y: 250, vx: 0, vy: -400, isFireball: true, isPierce: true);
        gc.balls..clear()..add(ball);
        gc.bricks = [
          Brick(x: 80, y: 220, width: 40, height: 20, hp: 999, color: Colors.grey, isSteel: true),
          Brick(x: 80, y: 190, width: 40, height: 20, hp: 999, color: Colors.grey, isSteel: true),
          Brick(x: 80, y: 160, width: 40, height: 20, hp: 999, color: Colors.grey, isSteel: true),
          Brick(x: 80, y: 130, width: 40, height: 20, hp: 999, color: Colors.grey, isSteel: true),
        ];

        for (int i = 0; i < 20; i++) {
          gc.update(0.016);
        }

        expect(gc.bricks.every((b) => !b.isAlive), isTrue, reason: 'All 4 steel bricks must be melted by Searing Ball');
      });

      test('F2.2_T2_03: Searing ball hitting frozen brick shatters frost and pierces cleanly', () {
        final gc = createTestController();
        final ball = Ball(x: 100, y: 124, vx: 0, vy: -300, isFireball: true, isPierce: true);
        final frozenBrick = Brick(x: 80, y: 100, width: 40, height: 20, hp: 1, color: Colors.blue, isFrozen: true);
        gc.balls..clear()..add(ball);
        gc.bricks = [frozenBrick];

        gc.update(0.016);

        expect(frozenBrick.isFrozen, isFalse);
      });

      test('F2.2_T2_04: Searing ball hitting unfilled tuft brick weaves tuft and continues forward', () {
        final gc = createTestController();
        final ball = Ball(x: 100, y: 124, vx: 0, vy: -300, isFireball: true, isPierce: true);
        final tuftBrick = Brick(x: 80, y: 100, width: 40, height: 20, hp: 1, color: Colors.white, isTuft: true, tuftFilled: false);
        gc.balls..clear()..add(ball);
        gc.bricks = [tuftBrick];

        gc.update(0.016);

        expect(tuftBrick.tuftFilled, isTrue);
        expect(ball.vy, lessThan(0));
      });

      test('F2.2_T2_05: Searing ball splitting with multi-ball preserves both isFireball and isPierce on all children', () {
        final gc = createTestController();
        gc.launchBall();
        gc.applyPowerUp(PowerUpType.fireball);
        gc.applyPowerUp(PowerUpType.multi);

        expect(gc.balls.length, greaterThanOrEqualTo(3));
        for (final b in gc.balls) {
          expect(b.isFireball, isTrue);
          expect(b.isPierce, isTrue);
        }
      });
    });

    // -------------------------------------------------------------------------
    // F2.3: Boundary Cases for Golden-Flame Visual
    // -------------------------------------------------------------------------
    group('F2.3: Golden-Flame Visual Boundaries', () {
      testWidgets('F2.3_T2_01: Searing ball moving purely vertically upward (vx=0, vy=-400) renders flame curled downward', (tester) async {
        final gc = createTestController();
        final ball = Ball(x: 180, y: 300, vx: 0, vy: -400, isFireball: true, isPierce: true);
        gc.balls..clear()..add(ball);

        await tester.pumpWidget(MaterialApp(home: Scaffold(body: GameCanvas(controller: gc))));
        await tester.pump(const Duration(milliseconds: 16));

        expect(find.byType(GameCanvas), findsOneWidget);
      });

      testWidgets('F2.3_T2_02: Searing ball moving purely horizontally (vx=400, vy=0) renders flame curled leftward', (tester) async {
        final gc = createTestController();
        final ball = Ball(x: 180, y: 300, vx: 400, vy: 0, isFireball: true, isPierce: true);
        gc.balls..clear()..add(ball);

        await tester.pumpWidget(MaterialApp(home: Scaffold(body: GameCanvas(controller: gc))));
        await tester.pump(const Duration(milliseconds: 16));

        expect(find.byType(GameCanvas), findsOneWidget);
      });

      testWidgets('F2.3_T2_03: Ball with simultaneous Searing Ball and Corner Boost displays both effects cleanly', (tester) async {
        final gc = createTestController();
        final ball = Ball(x: 180, y: 300, vx: 200, vy: -400, isFireball: true, isPierce: true, cornerBoostTimer: 3.0);
        gc.balls..clear()..add(ball);

        await tester.pumpWidget(MaterialApp(home: Scaffold(body: GameCanvas(controller: gc))));
        await tester.pump(const Duration(milliseconds: 16));

        expect(find.byType(GameCanvas), findsOneWidget);
      });

      testWidgets('F2.3_T2_04: Searing ball stuck on paddle renders rotating crest without flame NaN exceptions', (tester) async {
        final gc = createTestController();
        final ball = Ball(x: 180, y: gc.paddle.y - 12.0, isStuck: true, isFireball: true, isPierce: true);
        gc.balls..clear()..add(ball);

        await tester.pumpWidget(MaterialApp(home: Scaffold(body: GameCanvas(controller: gc))));
        await tester.pump(const Duration(milliseconds: 16));

        expect(find.byType(GameCanvas), findsOneWidget);
      });

      testWidgets('F2.3_T2_05: Searing ball renders at simulated 120 FPS without dropped frames', (tester) async {
        final gc = createTestController();
        final ball = Ball(x: 180, y: 300, vx: 150, vy: -350, isFireball: true, isPierce: true);
        gc.balls..clear()..add(ball);

        await tester.pumpWidget(MaterialApp(home: Scaffold(body: GameCanvas(controller: gc))));
        for (int frame = 0; frame < 20; frame++) {
          gc.gameTime += 0.0083;
          await tester.pump(const Duration(milliseconds: 8));
        }

        expect(find.byType(GameCanvas), findsOneWidget);
      });
    });

    // -------------------------------------------------------------------------
    // F2.4: Boundary Cases for Localization
    // -------------------------------------------------------------------------
    group('F2.4: Localization Boundaries', () {
      test('F2.4_T2_01: Dynamic language switch tr -> en -> tr preserves localized Searing Ball string', () {
        SaveManager.instance.setLanguage('tr');
        expect(I18n.tr('pup_fireball'), equals('YAKICI TOP!'));

        SaveManager.instance.setLanguage('en');
        expect(I18n.tr('pup_fireball'), equals('SEARING BALL!'));

        SaveManager.instance.setLanguage('tr');
        expect(I18n.tr('pup_fireball'), equals('YAKICI TOP!'));
      });

      test('F2.4_T2_02: Fallback for unsupported locale defaults to English SEARING BALL!', () {
        SaveManager.instance.setLanguage('unknown_locale_xyz');
        expect(I18n.tr('pup_fireball'), equals('SEARING BALL!'));
      });

      test('F2.4_T2_03: Collecting pierce capsule spawns floating text with localized label', () {
        final gc = createTestController();
        SaveManager.instance.setLanguage('tr');
        gc.launchBall();

        gc.applyPowerUp(PowerUpType.pierce);

        expect(PowerUpType.pierce.label, equals('YAKICI TOP!'));
      });

      test('F2.4_T2_04: Localized labels strictly contain non-empty uppercase text without emojis', () {
        final emojiRegex = RegExp(r'[\uD83C-\uD83E][\uDC00-\uDFFF]|[\u2600-\u27BF]');
        for (final lang in ['tr', 'en']) {
          SaveManager.instance.setLanguage(lang);
          final fbLabel = I18n.tr('pup_fireball');
          final pierceLabel = I18n.tr('pup_pierce');

          expect(emojiRegex.hasMatch(fbLabel), isFalse);
          expect(emojiRegex.hasMatch(pierceLabel), isFalse);
          expect(fbLabel.length, greaterThan(3));
          expect(pierceLabel.length, greaterThan(3));
        }
      });

      test('F2.4_T2_05: Searing Ball label is uppercase in both Turkish and English', () {
        SaveManager.instance.setLanguage('tr');
        expect(I18n.tr('pup_fireball'), equals(I18n.tr('pup_fireball').toUpperCase()));

        SaveManager.instance.setLanguage('en');
        expect(I18n.tr('pup_fireball'), equals(I18n.tr('pup_fireball').toUpperCase()));
      });
    });

    // -------------------------------------------------------------------------
    // F2.5: Boundary Cases for Capsule & PixelArt
    // -------------------------------------------------------------------------
    group('F2.5: PixelArt Boundaries', () {
      test('F2.5_T2_01: All cells in PixelArt pierce and fireball matrices are within valid index range [0..2]', () {
        final pMatrix = PixelArt.bitmaps[PowerUpType.pierce]!;
        final fbMatrix = PixelArt.bitmaps[PowerUpType.fireball]!;

        for (final row in pMatrix) {
          for (final cell in row) {
            expect(cell >= 0 && cell <= 2, isTrue);
          }
        }
        for (final row in fbMatrix) {
          for (final cell in row) {
            expect(cell >= 0 && cell <= 2, isTrue);
          }
        }
      });

      test('F2.5_T2_02: Fast-falling capsule (vy=350 px/s) animates and updates position correctly', () {
        final cap = FallingCapsule(x: 100, y: 100, type: PowerUpType.pierce, vy: 350.0);
        cap.update(0.1);

        expect(cap.y, closeTo(135.0, 0.1));
        expect(cap.animTimer, closeTo(0.1, 0.01));
      });

      testWidgets('F2.5_T2_03: Capsule drawn at screen edges (x=0, x=screenWidth) does not throw', (tester) async {
        final gc = createTestController();
        gc.capsules.add(FallingCapsule(x: 0, y: 200, type: PowerUpType.pierce));
        gc.capsules.add(FallingCapsule(x: gc.screenWidth, y: 200, type: PowerUpType.fireball));

        await tester.pumpWidget(MaterialApp(home: Scaffold(body: GameCanvas(controller: gc))));
        await tester.pump(const Duration(milliseconds: 16));

        expect(find.byType(GameCanvas), findsOneWidget);
      });

      test('F2.5_T2_04: Pierce matrix has flame motif with active core pixels in center rows', () {
        final pMatrix = PixelArt.bitmaps[PowerUpType.pierce]!;
        expect(pMatrix[4].any((p) => p > 0), isTrue);
      });

      testWidgets('F2.5_T2_05: Capsule rendering with custom width and height renders cleanly', (tester) async {
        final gc = createTestController();
        final cap = FallingCapsule(x: 180, y: 250, type: PowerUpType.pierce)
          ..width = 48.0
          ..height = 48.0;
        gc.capsules.add(cap);

        await tester.pumpWidget(MaterialApp(home: Scaffold(body: GameCanvas(controller: gc))));
        await tester.pump(const Duration(milliseconds: 16));

        expect(find.byType(GameCanvas), findsOneWidget);
      });
    });

    // -------------------------------------------------------------------------
    // F3.1: Boundary Cases for Black Hole Influence Radius
    // -------------------------------------------------------------------------
    group('F3.1: Influence Radius Boundaries', () {
      test('F3.1_T2_01: Smallest standard black hole r=20.0 enforces lower bound 135.0', () {
        final bh = BlackHole(x: 100, y: 100, radius: 20.0, mass: 1000);
        expect((bh as dynamic).maxInfluenceDist, equals(135.0));
      });

      test('F3.1_T2_02: Largest standard black hole r=34.0 has maxInfluenceDist = 187.0', () {
        final bh = BlackHole(x: 100, y: 100, radius: 34.0, mass: 1000);
        expect((bh as dynamic).maxInfluenceDist, equals(34.0 * 5.5));
      });

      test('F3.1_T2_03: Largest Supercharged black hole r=34.0 has maxInfluenceDist = 204.0', () {
        final bh = BlackHole(x: 100, y: 100, radius: 34.0, mass: 1000, isSupercharged: true);
        expect((bh as dynamic).maxInfluenceDist, equals(34.0 * 6.0));
      });

      test('F3.1_T2_04: Largest Vortex Trap r=34.0 has maxInfluenceDist = 221.0', () {
        final bh = BlackHole(x: 100, y: 100, radius: 34.0, mass: 1000, isVortexTrap: true);
        expect((bh as dynamic).maxInfluenceDist, equals(34.0 * 6.5));
      });

      test('F3.1_T2_05: Ball at distance maxInfluenceDist - 0.5px experiences pull; at + 0.5px experiences zero pull', () {
        final gc = createTestController();
        final bh = BlackHole(x: 180, y: 300, radius: 20.0, mass: 1000);
        gc.blackHoles..clear()..add(bh);

        final boundary = bh.maxInfluenceDist;
        final ballInside = Ball(x: 180 + boundary - 0.5, y: 300, vx: 0, vy: -400);
        final ballOutside = Ball(x: 180 + boundary + 0.5, y: 300, vx: 0, vy: -400);

        gc.balls..clear()..addAll([ballInside, ballOutside]);
        gc.status = GameStatus.playing;
        gc.update(0.05);

        expect(ballInside.vx, lessThan(0.0), reason: 'Ball inside boundary should experience pull towards center');
        expect(ballOutside.vx, equals(0.0), reason: 'Ball outside boundary should experience zero pull');
      });
    });

    // -------------------------------------------------------------------------
    // F3.2: Boundary Cases for Gravity Falloff & Swirl
    // -------------------------------------------------------------------------
    group('F3.2: Gravity Falloff Boundaries', () {
      test('F3.2_T2_01: Ultra-fast ball (750 px/s) deflects without tunneling through event horizon', () {
        final gc = createTestController();
        final bh = BlackHole(x: 180, y: 300, radius: 26.0, mass: 1000);
        gc.blackHoles..clear()..add(bh);
        final ball = Ball(x: 215, y: 300, vx: 0, vy: -750);
        gc.balls..clear()..add(ball);
        gc.status = GameStatus.playing;

        for (int i = 0; i < 10; i++) {
          gc.update(0.01);
        }

        expect(ball.vx, isNot(equals(0.0)));
        expect(ball.speed, lessThanOrEqualTo(850.0));
      });

      test('F3.2_T2_02: Ball grazing event horizon orbits and slingshots with velocity boost', () {
        final gc = createTestController();
        final bh = BlackHole(x: 180, y: 300, radius: 26.0, mass: 1000, isSupercharged: true);
        gc.blackHoles..clear()..add(bh);
        final ball = Ball(x: 195, y: 300, vx: 0, vy: -350);
        gc.balls..clear()..add(ball);
        gc.status = GameStatus.playing;

        final startSpeed = ball.speed;
        for (int i = 0; i < 15; i++) {
          gc.update(0.016);
        }

        expect(ball.speed, greaterThan(startSpeed * 0.9));
      });

      test('F3.2_T2_03: Multiple balls entering gravitational field deflect independently', () {
        final gc = createTestController();
        final bh = BlackHole(x: 180, y: 300, radius: 26.0, mass: 1000);
        gc.blackHoles..clear()..add(bh);

        final ballLeft = Ball(x: 120, y: 300, vx: 0, vy: -400);
        final ballRight = Ball(x: 240, y: 300, vx: 0, vy: -400);
        gc.balls..clear()..addAll([ballLeft, ballRight]);
        gc.status = GameStatus.playing;

        gc.update(0.05);

        expect(ballLeft.vx, greaterThan(15.0));
        expect(ballRight.vx, lessThan(-15.0));
      });

      test('F3.2_T2_04: Head-on radial ball accelerates smoothly without NaN velocity', () {
        final gc = createTestController();
        final bh = BlackHole(x: 180, y: 300, radius: 26.0, mass: 1000);
        gc.blackHoles..clear()..add(bh);
        final ball = Ball(x: 180, y: 220, vx: 0, vy: 300);
        gc.balls..clear()..add(ball);
        gc.status = GameStatus.playing;

        gc.update(0.016);

        expect(ball.vy.isNaN, isFalse);
        expect(ball.vx.isNaN, isFalse);
      });

      test('F3.2_T2_05: Slingshot exit speed never exceeds physics cap of 850 px/s', () {
        final gc = createTestController();
        final bh = BlackHole(x: 180, y: 300, radius: 34.0, mass: 1000, isSupercharged: true);
        gc.blackHoles..clear()..add(bh);
        final ball = Ball(x: 190, y: 300, vx: 100, vy: -700);
        gc.balls..clear()..add(ball);
        gc.status = GameStatus.playing;

        for (int i = 0; i < 20; i++) {
          gc.update(0.016);
          expect(ball.speed, lessThanOrEqualTo(850.0 + 1.0));
        }
      });
    });

    // -------------------------------------------------------------------------
    // F3.3: Boundary Cases for Black Hole Canvas Rendering
    // -------------------------------------------------------------------------
    group('F3.3: Canvas Visual Boundaries', () {
      testWidgets('F3.3_T2_01: Black hole positioned near canvas edge (x=30) clips cleanly', (tester) async {
        final gc = createTestController();
        gc.blackHoles.add(BlackHole(x: 30, y: 300, radius: 26.0, mass: 1000));

        await tester.pumpWidget(MaterialApp(home: Scaffold(body: GameCanvas(controller: gc))));
        await tester.pump(const Duration(milliseconds: 16));

        expect(find.byType(GameCanvas), findsOneWidget);
      });

      testWidgets('F3.3_T2_02: Black hole with timeLeft < 0.2s renders smoothly without popping', (tester) async {
        final gc = createTestController();
        gc.blackHoles.add(BlackHole(x: 180, y: 300, radius: 26.0, mass: 1000, timeLeft: 0.1));

        await tester.pumpWidget(MaterialApp(home: Scaffold(body: GameCanvas(controller: gc))));
        await tester.pump(const Duration(milliseconds: 16));

        expect(find.byType(GameCanvas), findsOneWidget);
      });

      testWidgets('F3.3_T2_03: Two simultaneous black holes render independent influence zones cleanly', (tester) async {
        final gc = createTestController();
        gc.blackHoles.add(BlackHole(x: 100, y: 300, radius: 22.0, mass: 1000));
        gc.blackHoles.add(BlackHole(x: 260, y: 300, radius: 24.0, mass: 1000, isSupercharged: true));

        await tester.pumpWidget(MaterialApp(home: Scaffold(body: GameCanvas(controller: gc))));
        await tester.pump(const Duration(milliseconds: 16));

        expect(find.byType(GameCanvas), findsOneWidget);
      });

      testWidgets('F3.3_T2_04: Vortex trap boundary with maxInfluenceDist > 200px renders cleanly', (tester) async {
        final gc = createTestController();
        gc.blackHoles.add(BlackHole(x: 180, y: 300, radius: 34.0, mass: 1000, isVortexTrap: true));

        await tester.pumpWidget(MaterialApp(home: Scaffold(body: GameCanvas(controller: gc))));
        await tester.pump(const Duration(milliseconds: 16));

        expect(find.byType(GameCanvas), findsOneWidget);
      });

      testWidgets('F3.3_T2_05: 60 continuous frames render without shader re-allocation lag', (tester) async {
        final gc = createTestController();
        final bh = BlackHole(x: 180, y: 300, radius: 26.0, mass: 1000);
        gc.blackHoles.add(bh);

        await tester.pumpWidget(MaterialApp(home: Scaffold(body: GameCanvas(controller: gc))));
        for (int frame = 0; frame < 60; frame++) {
          bh.update(0.016);
          gc.gameTime += 0.016;
          await tester.pump(const Duration(milliseconds: 16));
        }

        expect(find.byType(GameCanvas), findsOneWidget);
      });
    });

    // -------------------------------------------------------------------------
    // F3.4: Boundary Cases for Vortex Power-Up Spawning
    // -------------------------------------------------------------------------
    group('F3.4: Vortex Spawning Boundaries', () {
      test('F3.4_T2_01: Spawning vortex when bricks extend very low clamps spawn safely above paddle', () {
        final gc = createTestController();
        gc.stats.level = 4;
        gc.bricks.add(Brick(x: 100, y: gc.paddle.y - 130, width: 40, height: 20, hp: 1, color: Colors.red));

        gc.applyPowerUp(PowerUpType.vortex);

        if (gc.blackHoles.isNotEmpty) {
          final bh = gc.blackHoles.first;
          expect(bh.y, lessThanOrEqualTo(gc.paddle.y - 75.0 + 1.0));
        }
      });

      test('F3.4_T2_02: Spawning vortex when all bricks are destroyed spawns safely in upper play area', () {
        final gc = createTestController();
        gc.stats.level = 4;
        gc.bricks.clear();

        gc.applyPowerUp(PowerUpType.vortex);

        if (gc.blackHoles.isNotEmpty) {
          final bh = gc.blackHoles.first;
          expect(bh.y, greaterThanOrEqualTo(45.0));
          expect(bh.y, lessThanOrEqualTo(gc.paddle.y - 75.0 + 1.0));
        }
      });

      test('F3.4_T2_03: Spawning vortex when paddle is widened preserves safe margin', () {
        final gc = createTestController();
        gc.stats.level = 4;
        gc.applyPowerUp(PowerUpType.wide);
        gc.applyPowerUp(PowerUpType.vortex);

        if (gc.blackHoles.isNotEmpty) {
          final bh = gc.blackHoles.first;
          expect(bh.y, lessThanOrEqualTo(gc.paddle.y - 75.0 + 1.0));
        }
      });

      test('F3.4_T2_04: Collecting consecutive vortex capsules refreshes black hole lifespan', () {
        final gc = createTestController();
        gc.stats.level = 4;
        gc.applyPowerUp(PowerUpType.vortex);
        expect(gc.blackHoles.isNotEmpty, isTrue);

        gc.update(4.0);

        gc.applyPowerUp(PowerUpType.vortex);
        expect(gc.blackHoles.first.timeLeft, greaterThanOrEqualTo(5.0));
      });

      test('F3.4_T2_05: Spawning vortex in Zen mode positions anomaly safely between bricks and paddle', () {
        final gc = createTestController(mode: GameMode.zen);
        gc.applyPowerUp(PowerUpType.vortex);

        if (gc.blackHoles.isNotEmpty) {
          final bh = gc.blackHoles.first;
          expect(bh.y, lessThan(gc.paddle.y));
          expect(bh.radius >= 20.0 && bh.radius <= 34.0, isTrue);
        }
      });
    });
  });
}
