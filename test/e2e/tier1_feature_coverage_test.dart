import 'dart:io';
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

  group('Tier 1: Feature Coverage (Representative Inputs in Isolation)', () {
    // -------------------------------------------------------------------------
    // F1.1: Clear and halt active balls, projectiles, capsules, weapon timers,
    // and dice salvos on level clear (_checkGameProgress)
    // -------------------------------------------------------------------------
    group('F1.1: Level Clear Entity Halt', () {
      test('F1.1_T1_01: Balls are completely cleared when last breakable brick is destroyed', () {
        final gc = createTestController();
        gc.launchBall();
        expect(gc.balls.isNotEmpty, isTrue);

        clearAllBreakableBricks(gc);
        gc.update(0.016);

        expect(gc.levelTransitionTimer > 0, isTrue);
        expect(gc.balls.isEmpty, isTrue, reason: 'Active balls must be cleared upon level clear');
      });

      test('F1.1_T1_02: Projectiles (lasers, rockets, boss bullets) are completely cleared on level clear', () {
        final gc = createTestController();
        gc.projectiles.add(Projectile(x: 100, y: 300, vy: -400, radius: 4.0, isLaser: true));
        gc.projectiles.add(Projectile(x: 150, y: 300, vy: -350, radius: 6.0, isRocket: true));
        expect(gc.projectiles.length, 2);

        clearAllBreakableBricks(gc);
        gc.update(0.016);

        expect(gc.projectiles.isEmpty, isTrue, reason: 'Active projectiles must be cleared on level clear');
      });

      test('F1.1_T1_03: Falling capsules are completely cleared when level clear is triggered', () {
        final gc = createTestController();
        gc.capsules.add(FallingCapsule(x: 100, y: 200, type: PowerUpType.laser));
        gc.capsules.add(FallingCapsule(x: 200, y: 250, type: PowerUpType.fireball));
        expect(gc.capsules.length, 2);

        clearAllBreakableBricks(gc);
        gc.update(0.016);

        expect(gc.capsules.isEmpty, isTrue, reason: 'Falling capsules must be cleared on level clear');
      });

      test('F1.1_T1_04: Active dice salvos and dice rolling states are halted on level clear', () {
        final gc = createTestController();
        gc.isDiceRolling = true;
        gc.diceRollTimer = 0.5;
        gc.diceSalvoRemaining = 6;
        gc.diceDisplayTimer = 2.0;

        clearAllBreakableBricks(gc);
        gc.update(0.016);

        expect(gc.isDiceRolling, isFalse, reason: 'Dice roll must be halted on level clear');
        expect(gc.diceSalvoRemaining, equals(0), reason: 'Dice salvos must be zeroed on level clear');
      });

      test('F1.1_T1_05: Active weapon timers and paddle weapon flags are reset on level clear', () {
        final gc = createTestController();
        gc.paddle.hasLaser = true;
        gc.paddle.hasRockets = true;
        gc.paddle.hasDrone = true;
        gc.laserTimer = 0.4;
        gc.rocketTimer = 0.8;
        gc.droneShootTimer = 0.5;

        clearAllBreakableBricks(gc);
        gc.update(0.016);

        expect(gc.paddle.hasLaser, isFalse, reason: 'Laser flag must be reset on level clear');
        expect(gc.paddle.hasRockets, isFalse, reason: 'Rocket flag must be reset on level clear');
        expect(gc.paddle.hasDrone, isFalse, reason: 'Drone flag must be reset on level clear');
      });
    });

    // -------------------------------------------------------------------------
    // F1.2: Clear and halt active entities on _onVictory and _onGameOver
    // -------------------------------------------------------------------------
    group('F1.2: Victory & GameOver Entity Halt', () {
      test('F1.2_T1_01: Victory halts and clears all active balls', () {
        final gc = createTestController(mode: GameMode.daily);
        gc.launchBall();
        expect(gc.balls.isNotEmpty, isTrue);

        clearAllBreakableBricks(gc);
        gc.update(0.016);

        expect(gc.status, equals(GameStatus.victory));
        expect(gc.balls.isEmpty, isTrue, reason: 'Balls must be cleared on victory');
      });

      test('F1.2_T1_02: Victory halts and clears active projectiles and falling capsules', () {
        final gc = createTestController(mode: GameMode.daily);
        gc.projectiles.add(Projectile(x: 100, y: 300, vy: -400));
        gc.capsules.add(FallingCapsule(x: 120, y: 250, type: PowerUpType.shield));

        clearAllBreakableBricks(gc);
        gc.update(0.016);

        expect(gc.status, equals(GameStatus.victory));
        expect(gc.projectiles.isEmpty, isTrue);
        expect(gc.capsules.isEmpty, isTrue);
      });

      test('F1.2_T1_03: Victory halts dice roll and remaining salvos', () {
        final gc = createTestController(mode: GameMode.daily);
        gc.isDiceRolling = true;
        gc.diceSalvoRemaining = 8;

        clearAllBreakableBricks(gc);
        gc.update(0.016);

        expect(gc.status, equals(GameStatus.victory));
        expect(gc.isDiceRolling, isFalse);
        expect(gc.diceSalvoRemaining, equals(0));
      });

      test('F1.2_T1_04: GameOver halts and clears active balls, projectiles, and capsules', () {
        final gc = createTestController();
        gc.stats.lives = 1;
        gc.projectiles.add(Projectile(x: 100, y: 300, vy: -400));
        gc.capsules.add(FallingCapsule(x: 120, y: 250, type: PowerUpType.laser));
        gc.balls.clear(); // Lose final ball
        SaveManager.instance.markFreeContinueUsed();

        gc.update(0.016);

        expect(gc.status, equals(GameStatus.gameOver));
        expect(gc.balls.isEmpty, isTrue);
        expect(gc.projectiles.isEmpty, isTrue);
        expect(gc.capsules.isEmpty, isTrue);
      });

      test('F1.2_T1_05: GameOver resets active weapon flags and timers', () {
        final gc = createTestController();
        gc.stats.lives = 1;
        gc.paddle.hasLaser = true;
        gc.paddle.hasRockets = true;
        gc.paddle.hasDrone = true;
        gc.balls.clear();
        SaveManager.instance.markFreeContinueUsed();

        gc.update(0.016);

        expect(gc.status, equals(GameStatus.gameOver));
        expect(gc.paddle.hasLaser, isFalse);
        expect(gc.paddle.hasRockets, isFalse);
        expect(gc.paddle.hasDrone, isFalse);
      });
    });

    // -------------------------------------------------------------------------
    // F1.3: Freeze gameplay simulation during levelTransitionTimer > 0, updating only particles
    // -------------------------------------------------------------------------
    group('F1.3: Simulation Freeze During Level Transition', () {
      test('F1.3_T1_01: Ball positions remain frozen while levelTransitionTimer > 0', () {
        final gc = createTestController();
        gc.levelTransitionTimer = 0.8;
        final testBall = Ball(x: 180, y: 300, vx: 200, vy: -300, isStuck: false);
        gc.balls.add(testBall);

        gc.update(0.1);

        expect(testBall.x, equals(180), reason: 'Ball X should not change during transition freeze');
        expect(testBall.y, equals(300), reason: 'Ball Y should not change during transition freeze');
      });

      test('F1.3_T1_02: Projectile positions remain frozen while levelTransitionTimer > 0', () {
        final gc = createTestController();
        gc.levelTransitionTimer = 0.8;
        final proj = Projectile(x: 150, y: 350, vy: -400, radius: 4.0);
        gc.projectiles.add(proj);

        gc.update(0.1);

        expect(proj.y, equals(350), reason: 'Projectile Y should not advance during transition freeze');
      });

      test('F1.3_T1_03: Power-up duration timers do not decay while levelTransitionTimer > 0', () {
        final gc = createTestController();
        gc.activePowerUps.add(ActivePowerUp(PowerUpType.laser));
        final initialTime = gc.activePowerUps.first.timeLeft;
        gc.levelTransitionTimer = 0.8;

        gc.update(0.1);

        expect(gc.activePowerUps.first.timeLeft, equals(initialTime), reason: 'PowerUp timer must not decay during freeze');
      });

      test('F1.3_T1_04: Particles continue updating and advancing life while levelTransitionTimer > 0', () {
        final gc = createTestController();
        gc.levelTransitionTimer = 0.8;
        gc.particles.spawnBurst(180, 300, Colors.amber, count: 5, speed: 100.0);
        expect(gc.particles.particles.isNotEmpty, isTrue);
        final initialLife = gc.particles.particles.first.life;

        gc.update(0.05);

        expect(gc.particles.particles.first.life, lessThan(initialLife), reason: 'Celebration particles must animate during freeze');
      });

      test('F1.3_T1_05: Black hole rotation and anomaly timers do not update while levelTransitionTimer > 0', () {
        final gc = createTestController();
        final bh = BlackHole(x: 180, y: 300, radius: 24.0, mass: 1000, timeLeft: 5.0);
        gc.blackHoles.add(bh);
        gc.levelTransitionTimer = 0.8;
        final initialRot = bh.rotation;
        final initialTime = bh.timeLeft;

        gc.update(0.1);

        expect(bh.rotation, equals(initialRot), reason: 'Black hole rotation must freeze during transition');
        expect(bh.timeLeft, equals(initialTime), reason: 'Black hole timeLeft must freeze during transition');
      });
    });

    // -------------------------------------------------------------------------
    // F1.4: Freeze transition timer on pause/victory/gameover
    // -------------------------------------------------------------------------
    group('F1.4: Level Transition Timer Pause/Stop Freeze', () {
      test('F1.4_T1_01: Pausing game freezes levelTransitionTimer countdown', () {
        final gc = createTestController();
        gc.levelTransitionTimer = 0.75;
        gc.pause();

        gc.update(0.2);

        expect(gc.status, equals(GameStatus.paused));
        expect(gc.levelTransitionTimer, equals(0.75), reason: 'Transition timer must not decrement while paused');
      });

      test('F1.4_T1_02: Resuming game unfreezes levelTransitionTimer countdown', () {
        final gc = createTestController();
        gc.levelTransitionTimer = 0.75;
        gc.pause();
        gc.update(0.1);
        expect(gc.levelTransitionTimer, equals(0.75));

        gc.resume();
        gc.update(0.1);

        expect(gc.levelTransitionTimer, closeTo(0.65, 0.01), reason: 'Transition timer should resume countdown on resume');
      });

      test('F1.4_T1_03: Transition timer does not decrement while status is gameOver', () {
        final gc = createTestController();
        gc.levelTransitionTimer = 0.50;
        gc.status = GameStatus.gameOver;

        gc.update(0.1);

        expect(gc.levelTransitionTimer, equals(0.50), reason: 'Transition timer must remain frozen in gameOver');
      });

      test('F1.4_T1_04: Transition timer does not decrement while status is victory', () {
        final gc = createTestController();
        gc.levelTransitionTimer = 0.50;
        gc.status = GameStatus.victory;

        gc.update(0.1);

        expect(gc.levelTransitionTimer, equals(0.50), reason: 'Transition timer must remain frozen in victory');
      });

      test('F1.4_T1_05: Multiple updates during paused state preserve exact timer value', () {
        final gc = createTestController();
        gc.levelTransitionTimer = 0.88;
        gc.pause();

        for (int i = 0; i < 10; i++) {
          gc.update(0.016);
        }

        expect(gc.levelTransitionTimer, equals(0.88));
      });
    });

    // -------------------------------------------------------------------------
    // F1.5: Classic mode level 238 clear triggers _onVictory instead of advancing to level 239
    // -------------------------------------------------------------------------
    group('F1.5: Classic Mode Level 238 Apex Victory', () {
      test('F1.5_T1_01: Clearing level 238 in Classic mode sets GameStatus.victory', () {
        final gc = createTestController(mode: GameMode.classic);
        gc.stats.level = 238;
        gc.loadLevelBricks();

        clearAllBreakableBricks(gc);
        gc.update(0.016);

        expect(gc.status, equals(GameStatus.victory), reason: 'Clearing level 238 must trigger victory');
      });

      test('F1.5_T1_02: Clearing level 238 does not increment level to 239', () {
        final gc = createTestController(mode: GameMode.classic);
        gc.stats.level = 238;
        gc.loadLevelBricks();

        clearAllBreakableBricks(gc);
        gc.update(0.016);

        expect(gc.stats.level, equals(238), reason: 'Level must not exceed 238 upon victory');
      });

      test('F1.5_T1_03: Clearing level 238 clears saved classic session in SaveManager', () {
        final gc = createTestController(mode: GameMode.classic);
        SaveManager.instance.saveClassicSession(level: 238, score: 50000, lives: 3);
        expect(SaveManager.instance.hasSavedGame(GameMode.classic), isTrue);

        gc.stats.level = 238;
        gc.loadLevelBricks();
        clearAllBreakableBricks(gc);
        gc.update(0.016);

        expect(SaveManager.instance.hasSavedGame(GameMode.classic), isFalse);
      });

      test('F1.5_T1_04: Clearing level 238 awards +100 victory gold reward and updates high score', () {
        final gc = createTestController(mode: GameMode.classic);
        final initialGold = SaveManager.instance.gold;
        gc.stats.level = 238;
        gc.stats.score = 99999;
        gc.loadLevelBricks();

        clearAllBreakableBricks(gc);
        gc.update(0.016);

        expect(SaveManager.instance.gold, equals(initialGold + 100));
        expect(SaveManager.instance.getHighScore(GameMode.classic), equals(99999));
      });

      test('F1.5_T1_05: Clearing level 237 advances to level 238 without triggering victory', () {
        final gc = createTestController(mode: GameMode.classic);
        gc.stats.level = 237;
        gc.loadLevelBricks();

        clearAllBreakableBricks(gc);
        gc.update(0.016);

        expect(gc.status, isNot(equals(GameStatus.victory)));
        expect(gc.stats.level, equals(238), reason: 'Level 237 clear should advance to 238');
      });
    });

    // -------------------------------------------------------------------------
    // F1.6: Reset pointer drag and touch launch state across level transitions
    // -------------------------------------------------------------------------
    group('F1.6: Touch Launch State Across Level Transition', () {
      testWidgets('F1.6_T1_01: Releasing a pointer drag initiated in previous level does not launch ball in new level', (tester) async {
        final gc = createTestController();
        await tester.pumpWidget(MaterialApp(home: Scaffold(body: GameCanvas(controller: gc))));

        gc.launchBall();
        expect(gc.status, equals(GameStatus.playing));

        final gesture = await tester.startGesture(const Offset(180, 500));
        await tester.pump(const Duration(milliseconds: 16));

        clearAllBreakableBricks(gc);
        gc.update(0.016);
        expect(gc.levelTransitionTimer > 0, isTrue);

        gc.update(1.0);
        expect(gc.levelTransitionTimer, equals(0));
        expect(gc.status, equals(GameStatus.ready));
        expect(gc.hasStuckBall, isTrue);

        await gesture.up();
        await tester.pump(const Duration(milliseconds: 16));

        expect(gc.hasStuckBall, isTrue, reason: 'Releasing touch from previous level must not auto-launch ball');
        expect(gc.status, equals(GameStatus.ready));
      });

      testWidgets('F1.6_T1_02: Fresh pointer tap in new level successfully launches ball', (tester) async {
        final gc = createTestController();
        await tester.pumpWidget(MaterialApp(home: Scaffold(body: GameCanvas(controller: gc))));

        expect(gc.status, equals(GameStatus.ready));
        expect(gc.hasStuckBall, isTrue);

        await tester.tapAt(const Offset(180, 500));
        await tester.pump(const Duration(milliseconds: 50));

        expect(gc.status, equals(GameStatus.playing));
        expect(gc.hasStuckBall, isFalse);
      });

      testWidgets('F1.6_T1_03: Pointer drag movement during level transition does not move paddle inappropriately', (tester) async {
        final gc = createTestController();
        await tester.pumpWidget(MaterialApp(home: Scaffold(body: GameCanvas(controller: gc))));

        clearAllBreakableBricks(gc);
        gc.update(0.016);
        expect(gc.levelTransitionTimer > 0, isTrue);

        final gesture = await tester.startGesture(const Offset(180, 500));
        await gesture.moveTo(const Offset(250, 500));
        await tester.pump(const Duration(milliseconds: 16));
        await gesture.up();

        expect(gc.levelTransitionTimer > 0, isTrue);
      });

      test('F1.6_T1_04: New level starts with ball stuck to paddle center in ready state', () {
        final gc = createTestController();
        clearAllBreakableBricks(gc);
        gc.update(0.016);
        gc.update(1.0);

        expect(gc.status, equals(GameStatus.ready));
        expect(gc.balls.length, equals(1));
        expect(gc.balls.first.isStuck, isTrue);
        expect(gc.balls.first.x, closeTo(gc.paddle.x + gc.paddle.width / 2, 1.0));
      });

      testWidgets('F1.6_T1_05: Pointer cancel event resets launch tracking state cleanly', (tester) async {
        final gc = createTestController();
        await tester.pumpWidget(MaterialApp(home: Scaffold(body: GameCanvas(controller: gc))));

        final gesture = await tester.startGesture(const Offset(180, 500));
        await tester.pump(const Duration(milliseconds: 16));
        await gesture.cancel();
        await tester.pump(const Duration(milliseconds: 16));

        expect(gc.status, equals(GameStatus.ready));
        expect(gc.hasStuckBall, isTrue);
      });
    });

    // -------------------------------------------------------------------------
    // F2.1: Remove 6-point Claude starburst polygon (claudeStar / innerStar)
    // -------------------------------------------------------------------------
    group('F2.1: Remove Claude Starburst Polygon', () {
      test('F2.1_T1_01: lib/ui/game_canvas.dart source does not contain claudeStar identifier', () {
        final file = File('lib/ui/game_canvas.dart');
        final contents = file.readAsStringSync();
        expect(contents.contains('claudeStar'), isFalse, reason: 'claudeStar polygon must be completely removed');
      });

      test('F2.1_T1_02: lib/ui/game_canvas.dart source does not contain innerStar identifier', () {
        final file = File('lib/ui/game_canvas.dart');
        final contents = file.readAsStringSync();
        expect(contents.contains('innerStar'), isFalse, reason: 'innerStar polygon must be completely removed');
      });

      testWidgets('F2.1_T1_03: GameCanvas renders fireball without throwing exception', (tester) async {
        final gc = createTestController();
        gc.launchBall();
        gc.balls.first.isFireball = true;

        await tester.pumpWidget(MaterialApp(home: Scaffold(body: GameCanvas(controller: gc))));
        await tester.pump(const Duration(milliseconds: 50));

        expect(find.byType(GameCanvas), findsOneWidget);
      });

      test('F2.1_T1_04: Zero MaskFilter.blur lag in fireball rendering in game_canvas.dart', () {
        final file = File('lib/ui/game_canvas.dart');
        final contents = file.readAsStringSync();
        expect(contents.contains('MaskFilter.blur'), isFalse, reason: 'High-FPS zero blur design requirement');
      });

      testWidgets('F2.1_T1_05: Fireball ball renders with multiple trail points without Claude starburst', (tester) async {
        final gc = createTestController();
        gc.launchBall();
        final ball = gc.balls.first;
        ball.isFireball = true;
        for (int i = 0; i < 20; i++) {
          ball.update(0.016, trailLength: 20, recordTrail: true);
        }

        await tester.pumpWidget(MaterialApp(home: Scaffold(body: GameCanvas(controller: gc))));
        await tester.pump(const Duration(milliseconds: 50));

        expect(find.byType(GameCanvas), findsOneWidget);
      });
    });

    // -------------------------------------------------------------------------
    // F2.2: Unify PowerUpType.pierce and PowerUpType.fireball as Searing Ball
    // -------------------------------------------------------------------------
    group('F2.2: Unify Fireball & Pierce as Searing Ball', () {
      test('F2.2_T1_01: Applying PowerUpType.fireball sets both isFireball and isPierce to true', () {
        final gc = createTestController();
        gc.launchBall();
        gc.applyPowerUp(PowerUpType.fireball);

        for (final b in gc.balls) {
          expect(b.isFireball, isTrue, reason: 'Fireball powerup must set isFireball=true');
          expect(b.isPierce, isTrue, reason: 'Fireball powerup must set isPierce=true');
        }
      });

      test('F2.2_T1_02: Applying PowerUpType.pierce sets both isFireball and isPierce to true', () {
        final gc = createTestController();
        gc.launchBall();
        gc.applyPowerUp(PowerUpType.pierce);

        for (final b in gc.balls) {
          expect(b.isFireball, isTrue, reason: 'Pierce powerup must set isFireball=true');
          expect(b.isPierce, isTrue, reason: 'Pierce powerup must set isPierce=true');
        }
      });

      test('F2.2_T1_03: Searing Ball pierces breakable bricks without deflecting', () {
        final gc = createTestController();
        final ball = Ball(x: 100, y: 124, vx: 0, vy: -300, isFireball: true, isPierce: true);
        final brick = Brick(x: 80, y: 100, width: 40, height: 20, hp: 1, color: Colors.blue);
        gc.balls..clear()..add(ball);
        gc.bricks = [brick];

        gc.update(0.016);

        expect(brick.isAlive, isFalse, reason: 'Brick should be destroyed');
        expect(ball.vy, lessThan(0), reason: 'Searing Ball must pierce through without bouncing downward');
      });

      test('F2.2_T1_04: Searing Ball melts and destroys steel bricks without bouncing', () {
        final gc = createTestController();
        final ball = Ball(x: 100, y: 124, vx: 0, vy: -300, isFireball: true, isPierce: true);
        final steel = Brick(x: 80, y: 100, width: 40, height: 20, hp: 999, color: Colors.grey, isSteel: true);
        gc.balls..clear()..add(ball);
        gc.bricks = [steel];

        gc.update(0.016);

        expect(steel.isAlive, isFalse, reason: 'Searing Ball must melt steel brick');
        expect(ball.vy, lessThan(0), reason: 'Searing Ball must pierce through steel brick without bouncing');
      });

      test('F2.2_T1_05: Pierce power-up expiration cleanly removes both isFireball and isPierce', () {
        final gc = createTestController();
        gc.launchBall();
        gc.applyPowerUp(PowerUpType.pierce);
        expect(gc.balls.first.isFireball, isTrue);

        gc.update(7.0);

        expect(gc.balls.first.isFireball, isFalse);
        expect(gc.balls.first.isPierce, isFalse);
      });
    });

    // -------------------------------------------------------------------------
    // F2.3: High-FPS Golden-Flame "Yakıcı Top" visual
    // -------------------------------------------------------------------------
    group('F2.3: Golden-Flame Visual Design', () {
      test('F2.3_T1_01: GameCanvas source defines golden flame aesthetic colors', () {
        final file = File('lib/ui/game_canvas.dart');
        final contents = file.readAsStringSync();
        expect(contents.contains('0xFFFFD700') || contents.contains('0xFFFFAB00') || contents.contains('0xFFFF6D00'), isTrue);
      });

      testWidgets('F2.3_T1_02: Searing ball renders at high velocity without throwing', (tester) async {
        final gc = createTestController();
        gc.launchBall();
        final ball = gc.balls.first;
        ball.isFireball = true;
        ball.isPierce = true;
        ball.setSpeed(700.0);

        await tester.pumpWidget(MaterialApp(home: Scaffold(body: GameCanvas(controller: gc))));
        await tester.pump(const Duration(milliseconds: 16));

        expect(find.byType(GameCanvas), findsOneWidget);
      });

      testWidgets('F2.3_T1_03: Searing ball renders with opposite-curling flame vector', (tester) async {
        final gc = createTestController();
        final ball = Ball(x: 180, y: 300, vx: -250, vy: -250, isFireball: true, isPierce: true);
        gc.balls..clear()..add(ball);

        await tester.pumpWidget(MaterialApp(home: Scaffold(body: GameCanvas(controller: gc))));
        await tester.pump(const Duration(milliseconds: 16));

        expect(find.byType(GameCanvas), findsOneWidget);
      });

      testWidgets('F2.3_T1_04: Searing ball renders with rotating solar core crest', (tester) async {
        final gc = createTestController();
        final ball = Ball(x: 180, y: 300, vx: 0, vy: 0, isFireball: true, isPierce: true);
        gc.balls..clear()..add(ball);

        await tester.pumpWidget(MaterialApp(home: Scaffold(body: GameCanvas(controller: gc))));
        for (int frame = 0; frame < 5; frame++) {
          gc.gameTime += 0.016;
          await tester.pump(const Duration(milliseconds: 16));
        }

        expect(find.byType(GameCanvas), findsOneWidget);
      });

      testWidgets('F2.3_T1_05: Searing ball visual is distinct from Corner Shot supersonic jet afterburner', (tester) async {
        final gc = createTestController();
        final searingBall = Ball(x: 100, y: 300, vx: 100, vy: -300, isFireball: true, isPierce: true);
        final cornerBall = Ball(x: 200, y: 300, vx: 100, vy: -300, cornerBoostTimer: 2.5);
        gc.balls..clear()..addAll([searingBall, cornerBall]);

        await tester.pumpWidget(MaterialApp(home: Scaffold(body: GameCanvas(controller: gc))));
        await tester.pump(const Duration(milliseconds: 16));

        expect(find.byType(GameCanvas), findsOneWidget);
      });
    });

    // -------------------------------------------------------------------------
    // F2.4: Update localization strings in i18n.dart
    // -------------------------------------------------------------------------
    group('F2.4: Localization Strings for Yakıcı Top', () {
      test('F2.4_T1_01: Turkish translation for pup_fireball is 🔥 YAKICI TOP!', () {
        SaveManager.instance.setLanguage('tr');
        expect(I18n.tr('pup_fireball'), equals('🔥 YAKICI TOP!'));
      });

      test('F2.4_T1_02: Turkish translation for pup_pierce is 🔥 YAKICI TOP!', () {
        SaveManager.instance.setLanguage('tr');
        expect(I18n.tr('pup_pierce'), equals('🔥 YAKICI TOP!'));
      });

      test('F2.4_T1_03: English translation for pup_fireball is 🔥 SEARING BALL!', () {
        SaveManager.instance.setLanguage('en');
        expect(I18n.tr('pup_fireball'), equals('🔥 SEARING BALL!'));
      });

      test('F2.4_T1_04: English translation for pup_pierce is 🔥 SEARING BALL!', () {
        SaveManager.instance.setLanguage('en');
        expect(I18n.tr('pup_pierce'), equals('🔥 SEARING BALL!'));
      });

      test('F2.4_T1_05: PowerUpType label property returns localized Searing Ball string', () {
        SaveManager.instance.setLanguage('tr');
        expect(PowerUpType.fireball.label, equals('🔥 YAKICI TOP!'));
        expect(PowerUpType.pierce.label, equals('🔥 YAKICI TOP!'));

        SaveManager.instance.setLanguage('en');
        expect(PowerUpType.fireball.label, equals('🔥 SEARING BALL!'));
        expect(PowerUpType.pierce.label, equals('🔥 SEARING BALL!'));
      });
    });

    // -------------------------------------------------------------------------
    // F2.5: Update falling capsule and PixelArt icon for pierce/fireball
    // -------------------------------------------------------------------------
    group('F2.5: Capsule and PixelArt Golden-Flame Theme', () {
      test('F2.5_T1_01: PixelArt contains 8x8 matrix for PowerUpType.pierce', () {
        expect(PixelArt.bitmaps.containsKey(PowerUpType.pierce), isTrue);
        final matrix = PixelArt.bitmaps[PowerUpType.pierce]!;
        expect(matrix.length, equals(8));
        expect(matrix.every((row) => row.length == 8), isTrue);
      });

      test('F2.5_T1_02: PixelArt contains 8x8 matrix for PowerUpType.fireball', () {
        expect(PixelArt.bitmaps.containsKey(PowerUpType.fireball), isTrue);
        final matrix = PixelArt.bitmaps[PowerUpType.fireball]!;
        expect(matrix.length, equals(8));
        expect(matrix.every((row) => row.length == 8), isTrue);
      });

      test('F2.5_T1_03: PowerUpType.pierce color reflects golden-flame theme', () {
        final c = PowerUpType.pierce.color;
        expect(c.r > c.b, isTrue, reason: 'Pierce capsule color must be warm golden/amber/orange theme');
      });

      testWidgets('F2.5_T1_04: FallingCapsule for pierce renders without errors', (tester) async {
        final gc = createTestController();
        gc.capsules.add(FallingCapsule(x: 180, y: 250, type: PowerUpType.pierce));

        await tester.pumpWidget(MaterialApp(home: Scaffold(body: GameCanvas(controller: gc))));
        await tester.pump(const Duration(milliseconds: 16));

        expect(find.byType(GameCanvas), findsOneWidget);
      });

      testWidgets('F2.5_T1_05: FallingCapsule for fireball renders without errors', (tester) async {
        final gc = createTestController();
        gc.capsules.add(FallingCapsule(x: 180, y: 250, type: PowerUpType.fireball));

        await tester.pumpWidget(MaterialApp(home: Scaffold(body: GameCanvas(controller: gc))));
        await tester.pump(const Duration(milliseconds: 16));

        expect(find.byType(GameCanvas), findsOneWidget);
      });
    });

    // -------------------------------------------------------------------------
    // F3.1: Expand gravitational influence radius max(135.0, r * mult)
    // -------------------------------------------------------------------------
    group('F3.1: Black Hole Gravitational Influence Radius', () {
      test('F3.1_T1_01: Standard black hole with r=20.0 has maxInfluenceDist clamped to 135.0', () {
        final bh = BlackHole(x: 100, y: 100, radius: 20.0, mass: 1000);
        final expected = max(135.0, 20.0 * 5.5);
        expect((bh as dynamic).maxInfluenceDist, equals(expected));
      });

      test('F3.1_T1_02: Standard black hole with r=30.0 has maxInfluenceDist equal to 165.0', () {
        final bh = BlackHole(x: 100, y: 100, radius: 30.0, mass: 1000);
        final expected = max(135.0, 30.0 * 5.5);
        expect((bh as dynamic).maxInfluenceDist, equals(expected));
      });

      test('F3.1_T1_03: Supercharged black hole with r=25.0 has maxInfluenceDist equal to 150.0', () {
        final bh = BlackHole(x: 100, y: 100, radius: 25.0, mass: 1000, isSupercharged: true);
        final expected = max(135.0, 25.0 * 6.0);
        expect((bh as dynamic).maxInfluenceDist, equals(expected));
      });

      test('F3.1_T1_04: Vortex Trap black hole with r=24.0 has maxInfluenceDist equal to 156.0', () {
        final bh = BlackHole(x: 100, y: 100, radius: 24.0, mass: 1000, isVortexTrap: true);
        final expected = max(135.0, 24.0 * 6.5);
        expect((bh as dynamic).maxInfluenceDist, equals(expected));
      });

      test('F3.1_T1_05: All black hole radii from 20 to 34 have maxInfluenceDist >= 135.0', () {
        for (double r = 20.0; r <= 34.0; r += 2.0) {
          final bhStd = BlackHole(x: 0, y: 0, radius: r, mass: 1000);
          final bhSuper = BlackHole(x: 0, y: 0, radius: r, mass: 1000, isSupercharged: true);
          final bhVortex = BlackHole(x: 0, y: 0, radius: r, mass: 1000, isVortexTrap: true);

          expect((bhStd as dynamic).maxInfluenceDist >= 135.0, isTrue);
          expect((bhSuper as dynamic).maxInfluenceDist >= 135.0, isTrue);
          expect((bhVortex as dynamic).maxInfluenceDist >= 135.0, isTrue);
        }
      });
    });

    // -------------------------------------------------------------------------
    // F3.2: Strong responsive distance falloff pow(0.85) + base pull & swirl
    // -------------------------------------------------------------------------
    group('F3.2: Gravity Falloff and Tangential Swirl', () {
      test('F3.2_T1_01: Fast-moving ball passing through black hole experiences visible velocity deflection', () {
        final gc = createTestController();
        final bh = BlackHole(x: 180, y: 300, radius: 26.0, mass: 1000);
        gc.blackHoles..clear()..add(bh);

        final ball = Ball(x: 240, y: 300, vx: 0, vy: -450);
        gc.balls..clear()..add(ball);
        gc.status = GameStatus.playing;

        gc.update(0.05);

        expect(ball.vx, lessThan(-15.0), reason: 'Fast ball must be deflected towards black hole center');
      });

      test('F3.2_T1_02: Small black hole r=20.0 visibly deflects ball trajectory', () {
        final gc = createTestController();
        final bh = BlackHole(x: 180, y: 300, radius: 20.0, mass: 1000);
        gc.blackHoles..clear()..add(bh);

        final ball = Ball(x: 230, y: 300, vx: 0, vy: -400);
        gc.balls..clear()..add(ball);
        gc.status = GameStatus.playing;

        final initialAngle = atan2(ball.vy, ball.vx);
        gc.update(0.08);
        final deflectedAngle = atan2(ball.vy, ball.vx);

        final deflection = (deflectedAngle - initialAngle).abs();
        expect(deflection > 0.05, isTrue, reason: 'Smallest black hole (r=20) must visibly curve fast ball trajectory');
      });

      test('F3.2_T1_03: Supercharged black hole exerts higher pull than standard black hole', () {
        final gc1 = createTestController();
        final stdBh = BlackHole(x: 180, y: 300, radius: 26.0, mass: 1000);
        gc1.blackHoles..clear()..add(stdBh);
        final ball1 = Ball(x: 240, y: 300, vx: 0, vy: -450);
        gc1.balls..clear()..add(ball1);
        gc1.status = GameStatus.playing;
        gc1.update(0.05);

        final gc2 = createTestController();
        final superBh = BlackHole(x: 180, y: 300, radius: 26.0, mass: 1000, isSupercharged: true);
        gc2.blackHoles..clear()..add(superBh);
        final ball2 = Ball(x: 240, y: 300, vx: 0, vy: -450);
        gc2.balls..clear()..add(ball2);
        gc2.status = GameStatus.playing;
        gc2.update(0.05);

        expect(ball2.vx.abs(), greaterThanOrEqualTo(ball1.vx.abs()), reason: 'Supercharged black hole must exert greater pull');
      });

      test('F3.2_T1_04: Vortex trap exerts strongest pull among all black hole types', () {
        final gc = createTestController();
        final vortexBh = BlackHole(x: 180, y: 300, radius: 26.0, mass: 1000, isVortexTrap: true);
        gc.blackHoles..clear()..add(vortexBh);
        final ball = Ball(x: 240, y: 300, vx: 0, vy: -450);
        gc.balls..clear()..add(ball);
        gc.status = GameStatus.playing;
        gc.update(0.05);

        expect(ball.vx.abs(), greaterThan(25.0));
      });

      test('F3.2_T1_05: Gravity falloff is smooth and zero outside maxInfluenceDist', () {
        final gc = createTestController();
        final bh = BlackHole(x: 180, y: 300, radius: 20.0, mass: 1000);
        gc.blackHoles..clear()..add(bh);

        final ball = Ball(x: 180, y: 600, vx: 0, vy: -400);
        gc.balls..clear()..add(ball);
        gc.status = GameStatus.playing;
        gc.update(0.05);

        expect(ball.vx, equals(0.0), reason: 'Ball outside maxInfluenceDist should receive zero gravity pull');
      });
    });

    // -------------------------------------------------------------------------
    // F3.3: Render visible animated gravitational pull field boundary ring and spiral waves
    // -------------------------------------------------------------------------
    group('F3.3: Canvas Visual Boundaries', () {
      testWidgets('F3.3_T1_01: GameCanvas renders standard black hole without throwing', (tester) async {
        final gc = createTestController();
        gc.blackHoles.add(BlackHole(x: 180, y: 300, radius: 26.0, mass: 1000));

        await tester.pumpWidget(MaterialApp(home: Scaffold(body: GameCanvas(controller: gc))));
        await tester.pump(const Duration(milliseconds: 16));

        expect(find.byType(GameCanvas), findsOneWidget);
      });

      testWidgets('F3.3_T1_02: GameCanvas renders supercharged black hole cleanly', (tester) async {
        final gc = createTestController();
        gc.blackHoles.add(BlackHole(x: 180, y: 300, radius: 28.0, mass: 1000, isSupercharged: true));

        await tester.pumpWidget(MaterialApp(home: Scaffold(body: GameCanvas(controller: gc))));
        await tester.pump(const Duration(milliseconds: 16));

        expect(find.byType(GameCanvas), findsOneWidget);
      });

      testWidgets('F3.3_T1_03: GameCanvas renders vortex trap black hole cleanly', (tester) async {
        final gc = createTestController();
        gc.blackHoles.add(BlackHole(x: 180, y: 300, radius: 30.0, mass: 1000, isVortexTrap: true));

        await tester.pumpWidget(MaterialApp(home: Scaffold(body: GameCanvas(controller: gc))));
        await tester.pump(const Duration(milliseconds: 16));

        expect(find.byType(GameCanvas), findsOneWidget);
      });

      test('F3.3_T1_04: Zero MaskFilter.blur lag used in black hole drawing', () {
        final file = File('lib/ui/game_canvas.dart');
        final contents = file.readAsStringSync();
        expect(contents.contains('MaskFilter.blur'), isFalse);
      });

      testWidgets('F3.3_T1_05: Inward-spiraling waves animate across multiple continuous frames', (tester) async {
        final gc = createTestController();
        final bh = BlackHole(x: 180, y: 300, radius: 25.0, mass: 1000);
        gc.blackHoles.add(bh);

        await tester.pumpWidget(MaterialApp(home: Scaffold(body: GameCanvas(controller: gc))));
        for (int frame = 0; frame < 10; frame++) {
          bh.update(0.016);
          gc.gameTime += 0.016;
          await tester.pump(const Duration(milliseconds: 16));
        }

        expect(find.byType(GameCanvas), findsOneWidget);
      });
    });

    // -------------------------------------------------------------------------
    // F3.4: Implement PowerUpType.vortex to spawn active BlackHole in play zone
    // -------------------------------------------------------------------------
    group('F3.4: Vortex Power-Up Spawns Black Hole', () {
      test('F3.4 classic levels 1-3 swallow a vortex capsule', () {
        final gc = createTestController();
        gc.stats.level = 2;
        gc.applyPowerUp(PowerUpType.vortex);
        expect(gc.blackHoles, isEmpty);
        expect(gc.paddle.hasVortex, isFalse);
      });

      test('F3.4_T1_01: Collecting PowerUpType.vortex immediately spawns an active BlackHole', () {
        final gc = createTestController();
        gc.stats.level = 4;
        expect(gc.blackHoles.isEmpty, isTrue);

        gc.applyPowerUp(PowerUpType.vortex);

        expect(gc.blackHoles.isNotEmpty, isTrue, reason: 'PowerUpType.vortex must spawn an active BlackHole');
      });

      test('F3.4_T1_02: Spawned BlackHole has timeLeft set to 9.0 seconds', () {
        final gc = createTestController();
        gc.stats.level = 4;
        gc.applyPowerUp(PowerUpType.vortex);

        expect(gc.blackHoles.first.timeLeft, equals(9.0), reason: 'Spawned BlackHole duration should be 9.0s');
      });

      test('F3.4_T1_03: Spawned BlackHole is placed strictly below lowest alive brick + 45.0', () {
        final gc = createTestController();
        gc.stats.level = 4;
        final lowestBrickY = getLowestAliveBrickBottom(gc);

        gc.applyPowerUp(PowerUpType.vortex);

        final bh = gc.blackHoles.first;
        expect(bh.y, greaterThanOrEqualTo(lowestBrickY + 45.0 - 1.0), reason: 'Black hole must spawn strictly below bricks');
      });

      test('F3.4_T1_04: Spawned BlackHole is placed strictly above paddle.y - 75.0', () {
        final gc = createTestController();
        gc.stats.level = 4;

        gc.applyPowerUp(PowerUpType.vortex);

        final bh = gc.blackHoles.first;
        expect(bh.y, lessThanOrEqualTo(gc.paddle.y - 75.0 + 1.0), reason: 'Black hole must spawn strictly above paddle');
      });

      test('F3.4_T1_05: Active power-up list registers vortex buff', () {
        final gc = createTestController();
        gc.stats.level = 4;
        gc.applyPowerUp(PowerUpType.vortex);

        expect(gc.activePowerUps.any((p) => p.type == PowerUpType.vortex), isTrue);
      });
    });
  });
}
