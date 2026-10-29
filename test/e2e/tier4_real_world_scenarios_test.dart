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
import 'e2e_test_helpers.dart';

void main() {
  setupE2ETestEnvironment();

  group('Tier 4: Real-World Application Workload Scenarios', () {
    testWidgets('Tier 4 Scenario 1: Full Level Clear & Transition Safety (F1.1, F1.3, F1.4, F1.6)', (tester) async {
      // Step 1: Start level 5 with active multiballs, lasers, falling capsules, active dice salvo
      final gc = createTestController();
      gc.stats.level = 5;
      gc.loadLevelBricks();
      await tester.pumpWidget(MaterialApp(home: Scaffold(body: GameCanvas(controller: gc))));

      gc.launchBall();
      gc.balls.add(Ball(x: 100, y: 300, vx: 50, vy: -200, isStuck: false));
      gc.projectiles.add(Projectile(x: 150, y: 350, vy: -450, isLaser: true));
      gc.capsules.add(FallingCapsule(x: 180, y: 250, type: PowerUpType.laser));
      gc.isDiceRolling = true;
      gc.diceSalvoRemaining = 4;
      gc.paddle.hasLaser = true;

      // Step 2: Destroy last breakable brick to trigger level clear
      clearAllBreakableBricks(gc);
      gc.update(0.016);
      await tester.pump(const Duration(milliseconds: 16));

      // Verify immediate halt
      expect(gc.levelTransitionTimer > 0, isTrue);
      expect(gc.balls.isEmpty, isTrue, reason: 'Active balls must be cleared immediately upon level clear');
      expect(gc.projectiles.isEmpty, isTrue, reason: 'Active projectiles must be cleared on level clear');
      expect(gc.capsules.isEmpty, isTrue, reason: 'Falling capsules must be cleared on level clear');
      expect(gc.diceSalvoRemaining, equals(0), reason: 'Dice salvos must be halted');
      expect(gc.paddle.hasLaser, isFalse, reason: 'Weapons must be disarmed');

      // Step 3: Advance time during levelTransitionTimer > 0, verifying simulation is frozen
      gc.particles.spawnBurst(180, 300, Colors.amber, count: 5);
      final initialParticleLife = gc.particles.particles.first.life;
      gc.update(0.1);
      await tester.pump(const Duration(milliseconds: 100));

      // Particles animate while simulation remains frozen
      expect(gc.particles.particles.first.life, lessThan(initialParticleLife));

      // Step 4: Pause during transition, verify timer freezes. Resume, verify countdown continues
      final timerBeforePause = gc.levelTransitionTimer;
      gc.pause();
      gc.update(0.2);
      expect(gc.levelTransitionTimer, equals(timerBeforePause));

      gc.resume();
      gc.update(0.2);
      expect(gc.levelTransitionTimer, lessThan(timerBeforePause));

      // Step 5: Touch gesture held across transition end
      final gesture = await tester.startGesture(const Offset(180, 500));
      gc.update(1.6); // Complete transition
      await tester.pump(const Duration(milliseconds: 16));

      await gesture.up();
      await tester.pump(const Duration(milliseconds: 16));

      // Verify ball stays safely stuck on paddle in level 6
      expect(gc.status, equals(GameStatus.ready));
      expect(gc.hasStuckBall, isTrue);
      expect(gc.stats.level, equals(6));
    });

    test('Tier 4 Scenario 2: Victory Apex at Level 238 in Classic Mode (F1.2, F1.4, F1.5)', () {
      // Step 1: Initialize Classic mode at level 238
      final gc = createTestController(mode: GameMode.classic);
      gc.stats.level = 238;
      gc.stats.score = 75000;
      gc.loadLevelBricks();
      final initialGold = SaveManager.instance.gold;

      // Step 2: Spawn active balls, laser projectiles, falling capsules
      gc.launchBall();
      gc.balls.add(Ball(x: 100, y: 300, vx: 50, vy: -200, isStuck: false));
      gc.projectiles.add(Projectile(x: 150, y: 350, vy: -450, isLaser: true));
      gc.capsules.add(FallingCapsule(x: 180, y: 250, type: PowerUpType.shield));

      // Step 3: Break final breakable brick in level 238
      clearAllBreakableBricks(gc);
      gc.update(0.016);

      // Step 4: Verify victory status and entity halt
      expect(gc.status, equals(GameStatus.victory), reason: 'Level 238 clear must trigger GameStatus.victory');
      expect(gc.stats.level, equals(238), reason: 'Level must not advance to 239');
      expect(gc.balls.isEmpty, isTrue, reason: 'Balls must be halted on victory');
      expect(gc.projectiles.isEmpty, isTrue, reason: 'Projectiles must be halted on victory');
      expect(gc.capsules.isEmpty, isTrue, reason: 'Capsules must be halted on victory');

      // Step 5: Verify high score update and gold reward
      expect(SaveManager.instance.getHighScore(GameMode.classic), greaterThanOrEqualTo(75000));
      expect(SaveManager.instance.gold, equals(initialGold + 100));

      // Step 6: Verify transition timer does not decrement while in victory
      gc.update(0.5);
      expect(gc.status, equals(GameStatus.victory));
    });

    testWidgets('Tier 4 Scenario 3: Searing Ball Steel Melt & Multi-Brick Destruction (F2.2, F2.3, F2.4)', (tester) async {
      // Step 1: Start game and set language
      final gc = createTestController();
      SaveManager.instance.setLanguage('tr');
      await tester.pumpWidget(MaterialApp(home: Scaffold(body: GameCanvas(controller: gc))));

      // Step 2: Collect PowerUpType.pierce / fireball
      gc.launchBall();
      gc.applyPowerUp(PowerUpType.pierce);

      // Step 3: Verify localized label
      expect(I18n.tr('pup_pierce'), equals('YAKICI TOP!'));
      expect(PowerUpType.pierce.label, equals('YAKICI TOP!'));

      // Step 4: Verify ball has unified Searing Ball state
      final ball = gc.balls.first;
      expect(ball.isFireball, isTrue);
      expect(ball.isPierce, isTrue);

      // Step 5: Place 2 regular bricks and 2 steel bricks in flight path
      ball.x = 180;
      ball.y = 350;
      ball.vx = 0;
      ball.vy = -400;

      final reg1 = Brick(x: 160, y: 300, width: 40, height: 20, hp: 1, color: Colors.blue);
      final steel1 = Brick(x: 160, y: 260, width: 40, height: 20, hp: 999, color: Colors.grey, isSteel: true);
      final reg2 = Brick(x: 160, y: 220, width: 40, height: 20, hp: 1, color: Colors.green);
      final steel2 = Brick(x: 160, y: 180, width: 40, height: 20, hp: 999, color: Colors.grey, isSteel: true);
      gc.bricks = [reg1, steel1, reg2, steel2];

      // Simulate flight through all 4 bricks
      for (int step = 0; step < 30; step++) {
        gc.update(0.016);
      }

      // Verify all bricks destroyed and steel melted without deflection
      expect(reg1.isAlive, isFalse, reason: 'Regular brick 1 must be destroyed');
      expect(steel1.isAlive, isFalse, reason: 'Steel brick 1 must be melted');
      expect(reg2.isAlive, isFalse, reason: 'Regular brick 2 must be destroyed');
      expect(steel2.isAlive, isFalse, reason: 'Steel brick 2 must be melted');
      expect(ball.vy, lessThan(0), reason: 'Searing ball must pierce straight through without bouncing downward');

      // Step 6: Render frame with GameCanvas and verify clean rendering
      await tester.pump(const Duration(milliseconds: 16));
      expect(find.byType(GameCanvas), findsOneWidget);
    });

    testWidgets('Tier 4 Scenario 4: Gravitational Slingshot & Black Hole Deflection across Sizes (F3.1, F3.2, F3.3)', (tester) async {
      final gc = createTestController();
      await tester.pumpWidget(MaterialApp(home: Scaffold(body: GameCanvas(controller: gc))));

      // Test across small (r=20), mid (r=26), and large (r=34) black holes
      final radii = [20.0, 26.0, 34.0];
      for (final r in radii) {
        // Standard black hole
        final bh = BlackHole(x: 180, y: 300, radius: r, mass: 1000);
        gc.blackHoles..clear()..add(bh);

        // Verify influence radius calculation
        final expectedInfluence = max(135.0, r * 5.5);
        expect((bh as dynamic).maxInfluenceDist, equals(expectedInfluence));

        // Fast ball passing 50px away
        final ball = Ball(x: 230, y: 300, vx: 0, vy: -450);
        gc.balls..clear()..add(ball);
        gc.status = GameStatus.playing;

        final initialVx = ball.vx;
        final initialVy = ball.vy;

        gc.update(0.05);

        // Verify deflection
        final deflection = computeDeflectionAngle(initialVx, initialVy, ball.vx, ball.vy);
        expect(deflection, greaterThan(0.04), reason: 'Deflection must be significant for radius $r');

        await tester.pump(const Duration(milliseconds: 16));
        expect(find.byType(GameCanvas), findsOneWidget);
      }
    });

    test('Tier 4 Scenario 5: Vortex Power-Up Capsule Collect & Hazard Navigation (F3.1, F3.4, F1.1)', () {
      // Step 1: Start game with bricks
      final gc = createTestController();
      gc.stats.level = 4;
      expect(gc.blackHoles.isEmpty, isTrue);

      // Step 2: Collect PowerUpType.vortex capsule
      gc.applyPowerUp(PowerUpType.vortex);

      // Verify active BlackHole spawned in open zone with 9.0s duration
      expect(gc.blackHoles.isNotEmpty, isTrue);
      final spawnedBh = gc.blackHoles.first;
      expect(spawnedBh.timeLeft, equals(9.0));

      final lowestBrickY = getLowestAliveBrickBottom(gc);
      expect(spawnedBh.y, greaterThanOrEqualTo(lowestBrickY + 45.0 - 1.0));
      expect(spawnedBh.y, lessThanOrEqualTo(gc.paddle.y - 75.0 + 1.0));

      // Step 3: Fast ball maneuvers around spawned black hole, curving via gravitational field
      final ball = Ball(x: spawnedBh.x + 50.0, y: spawnedBh.y, vx: 0, vy: -400);
      gc.balls..clear()..add(ball);
      gc.status = GameStatus.playing;

      gc.update(0.05);
      expect(ball.vx, lessThan(-10.0), reason: 'Ball must curve towards spawned black hole');

      // Step 4: Clear remaining breakable bricks to trigger level clear
      clearAllBreakableBricks(gc);
      gc.update(0.016);

      // Step 5: Verify level clear halts active balls and transitions cleanly
      expect(gc.levelTransitionTimer > 0, isTrue);
      expect(gc.balls.isEmpty, isTrue, reason: 'Active balls must be cleared on level clear during active vortex');
    });
  });
}
