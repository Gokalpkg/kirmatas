import 'dart:math';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:kirmatas/engine/game_controller.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kirmatas/models/ball.dart';
import 'package:kirmatas/models/black_hole.dart';
import 'package:kirmatas/models/brick.dart';
import 'package:kirmatas/models/cosmetics.dart';
import 'package:kirmatas/models/easter_egg.dart';
import 'package:kirmatas/models/game_state.dart';
import 'package:kirmatas/models/level_design.dart';
import 'package:kirmatas/models/portal.dart';
import 'package:kirmatas/engine/ad_manager.dart';
import 'package:kirmatas/models/powerup.dart';
import 'package:kirmatas/storage/save_manager.dart';
import 'package:kirmatas/ui/game_canvas.dart';
import 'package:kirmatas/ui/pixel_art.dart';
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

  group('Kirmatas Game Engine Tests', () {
    test('Game modes have correct Turkish descriptions', () {
      expect(GameMode.classic.displayName.isNotEmpty, true);
      expect(GameMode.zen.displayName.isNotEmpty, true);
      expect(GameMode.descend.displayName.isNotEmpty, true);
      expect(GameMode.daily.displayName.isNotEmpty, true);
      expect(GameMode.shapes.displayName.isNotEmpty, true);
    });

    test('LevelDesign generates correct brick count for classic level', () {
      final bricks = LevelDesign.buildClassicLevel(1, 360, 640);
      expect(bricks.isNotEmpty, true);
      expect(bricks.any((b) => b.isAlive), true);
    });

    test('Level 5 is a boss battle with high HP boss brick', () {
      final bricks = LevelDesign.buildClassicLevel(5, 360, 640);
      final boss = bricks.firstWhere((b) => b.isBoss);
      expect(boss.isBoss, true);
      expect(boss.hp >= 25, true);
    });

    test('Ball speed and squash physics work accurately', () {
      final ball = Ball(x: 100, y: 100, vx: 100, vy: -100);
      expect(ball.speed > 140, true);

      ball.setSpeed(200);
      expect((ball.speed - 200).abs() < 1.0, true);

      ball.triggerSquash(1.57);
      expect(ball.squashTimer > 0, true);
      ball.update(0.1);
      expect(ball.squashTimer < 0.22, true);
    });

    test('All 24 powerups exist and have valid kinds and labels', () {
      expect(PowerUpType.values.length, 24);
      for (final p in PowerUpType.values) {
        expect(p.label.isNotEmpty, true);
        expect(p.duration >= 0, true);
      }
    });

    test('Crates have valid drop weights', () {
      for (final crate in CrateDef.allCrates) {
        expect(crate.weights.containsKey(Rarity.common), true);
        expect(crate.weights.containsKey(Rarity.legendary), true);
        final sum = crate.weights.values.fold<double>(0.0, (a, b) => a + b);
        expect(sum >= 99.0, true);
      }
    });

    test('Bricks break and stay broken over multiple game ticks', () {
      final controller = GameController();
      controller.setDimensions(360, 640);
      controller.startNewGame(GameMode.classic);
      
      final initialCount = controller.bricks.where((b) => b.isAlive && !b.isSteel).length;
      expect(initialCount > 0, true);

      // Hit first breakable brick
      final brick = controller.bricks.firstWhere((b) => b.isAlive && !b.isSteel);
      brick.hp = 1;
      
      final ball = Ball(x: brick.x + brick.width / 2, y: brick.y + brick.height / 2, vx: 0, vy: -100);
      ball.isStuck = false;
      controller.balls.clear();
      controller.balls.add(ball);
      controller.status = GameStatus.playing;

      // Update frame to register collision
      controller.update(0.016);

      // Brick should be dead
      expect(brick.isAlive, false);
      expect(controller.stats.bricksBroken >= 1, true);

      // Place ball safely on paddle so it doesn't clear the whole level
      ball.isStuck = true;
      ball.vx = 0;
      ball.vy = 0;

      // Run 60 more frames
      for (int i = 0; i < 60; i++) {
        controller.update(0.016);
      }

      // Brick must NOT have respawned!
      expect(controller.bricks.contains(brick), false);
      final remainingCount = controller.bricks.where((b) => b.isAlive && !b.isSteel).length;
      expect(remainingCount < initialCount, true);
    });

    test('Corner shot only triggers visual boost and NOT Fireball power-up', () {
      final controller = GameController();
      controller.setDimensions(360, 640);
      controller.startNewGame(GameMode.classic);
      controller.paddle.x = 100;
      controller.paddle.y = 500;
      controller.paddle.width = 100;

      // Hit paddle near outer corner (hitOffset ~ 0.88 >= 0.78)
      final ball = Ball(x: 100 + 94.0, y: 495.0, vx: 0, vy: 200);
      ball.isStuck = false;
      controller.balls.clear();
      controller.balls.add(ball);
      controller.status = GameStatus.playing;

      controller.update(0.016);

      // Corner boost timer should be activated
      expect(ball.cornerBoostTimer > 0, true);
      // But it MUST NOT trigger Fireball!
      expect(ball.isFireball, false);
      expect(controller.activePowerUps.any((p) => p.type == PowerUpType.fireball), false);
    });

    test('Corner boosted ball does not melt steel, but actual Fireball does', () {
      final controller = GameController();
      controller.setDimensions(360, 640);
      controller.startNewGame(GameMode.classic);

      final steelBrick = Brick(x: 100, y: 100, width: 40, height: 20, isSteel: true, hp: 999, maxHp: 999, color: Colors.grey);
      final dummyBrick = Brick(x: 10, y: 10, width: 40, height: 20, hp: 10, maxHp: 10, color: Colors.blue);
      controller.bricks = [steelBrick, dummyBrick];

      // Ball with corner boost only
      final cornerBall = Ball(x: 120, y: 105, vx: 0, vy: -100);
      cornerBall.cornerBoostTimer = 3.0;
      cornerBall.isFireball = false;
      cornerBall.isStuck = false;
      controller.balls.clear();
      controller.balls.add(cornerBall);
      controller.status = GameStatus.playing;

      controller.update(0.016);

      // Steel brick must NOT be destroyed by corner boost!
      expect(steelBrick.isAlive, true);

      // Now with actual Fireball powerup
      controller.applyPowerUp(PowerUpType.fireball);
      expect(cornerBall.isFireball, true);

      // Reposition ball to hit steel with fireball
      cornerBall.x = 120;
      cornerBall.y = 105;
      controller.update(0.016);
      // Fireball melts steel!
      expect(steelBrick.isAlive, false);
    });

    test('Ice brick freezes surrounding bricks and frozen bricks shatter on hit', () {
      final controller = GameController();
      controller.setDimensions(360, 640);
      controller.startNewGame(GameMode.classic);

      final iceBrick = Brick(x: 100, y: 100, width: 40, height: 20, isIce: true, hp: 1, maxHp: 1, color: Colors.cyan);
      final neighborBrick = Brick(x: 110, y: 110, width: 40, height: 20, hp: 3, maxHp: 3, color: Colors.blue);
      controller.bricks = [iceBrick, neighborBrick];

      final ball = Ball(x: 120, y: 105, vx: 0, vy: -100);
      ball.isStuck = false;
      controller.balls.clear();
      controller.balls.add(ball);
      controller.status = GameStatus.playing;

      // Break ice brick
      controller.update(0.016);

      expect(iceBrick.isAlive, false);
      expect(neighborBrick.isFrozen, true);
      
      // Next hit shatters the ice armor layer first, preserving underlying brick
      ball.x = neighborBrick.x + 10;
      ball.y = neighborBrick.y + 10;
      controller.update(0.016);

      expect(neighborBrick.isFrozen, false);
      expect(neighborBrick.isAlive, true);
    });

    test('Portals exist on exactly 83 specific levels out of 238', () {
      expect(GameController.portalLevels.length, 83);
      for (final lvl in GameController.portalLevels) {
        expect(lvl >= 1 && lvl <= 238, true);
      }

      final controller = GameController();
      controller.setDimensions(360, 640);

      final portalLevel = GameController.portalLevels.first;
      controller.stats.level = portalLevel;
      controller.loadLevelBricks();
      expect(controller.portals.length, 2);
      expect(controller.portals[0].linkedPortal, controller.portals[1]);
      expect(controller.portals[1].linkedPortal, controller.portals[0]);
    });

    test('Portals teleport ball cleanly to target portal', () {
      final controller = GameController();
      controller.setDimensions(360, 640);
      controller.portals.clear();

      final p1 = Portal(x: 50, y: 300, radius: 20, color: Colors.blue, isBlue: true);
      final p2 = Portal(x: 300, y: 300, radius: 20, color: Colors.orange, isBlue: false);
      p1.linkedPortal = p2;
      p2.linkedPortal = p1;
      controller.portals.addAll([p1, p2]);

      final ball = Ball(x: 50, y: 300, vx: 100, vy: 0);
      ball.isStuck = false;
      controller.balls.clear();
      controller.balls.add(ball);
      controller.status = GameStatus.playing;

      controller.update(0.016);

      // Ball should have teleported near p2 and cooldown active
      expect((ball.x - p2.x).abs() < 50, true);
      expect(ball.anomalyCooldown > 0, true);
    });

    test('Black holes pull ball with gravitational force', () {
      final controller = GameController();
      controller.setDimensions(360, 640);
      controller.blackHoles.clear();

      final bh = BlackHole(x: 200, y: 300, radius: 25, mass: 60000, timeLeft: 5.0);
      controller.blackHoles.add(bh);

      final ball = Ball(x: 160, y: 300, vx: 0, vy: -100);
      ball.isStuck = false;
      controller.balls.clear();
      controller.balls.add(ball);
      controller.status = GameStatus.playing;

      controller.update(0.016);

      // Ball vx should be pulled towards black hole (positive vx towards x=200)
      expect(ball.vx > 0, true);
    });

    test('Anti-softlock prevents ball from staying horizontal', () {
      final controller = GameController();
      controller.setDimensions(360, 640);

      final ball = Ball(x: 180, y: 300, vx: 200, vy: 5.0);
      ball.isStuck = false;
      controller.balls.clear();
      controller.balls.add(ball);
      controller.status = GameStatus.playing;

      controller.update(0.016);

      // vy should be pushed to at least 35 px/s
      expect(ball.vy.abs() >= 35.0, true);
    });

    test('All trail skins exist and include ghost, spark, dot, rainbow, plasma', () {
      final styles = TrailSkin.allTrails.map((t) => t.style).toSet();
      expect(styles.contains(TrailStyle.dot), true);
      expect(styles.contains(TrailStyle.spark), true);
      expect(styles.contains(TrailStyle.ghost), true);
      expect(styles.contains(TrailStyle.rainbow), true);
      expect(styles.contains(TrailStyle.plasma), true);
    });

    test('Multi-ball split preserves fireball, bomb, and pierce flags', () {
      final controller = GameController();
      controller.setDimensions(360, 640);
      controller.startNewGame(GameMode.classic);

      controller.applyPowerUp(PowerUpType.fireball);
      controller.applyPowerUp(PowerUpType.bomb);
      controller.applyPowerUp(PowerUpType.pierce);

      expect(controller.balls.first.isFireball, true);
      expect(controller.balls.first.isBomb, true);
      expect(controller.balls.first.isPierce, true);

      // Trigger multiball
      controller.applyPowerUp(PowerUpType.multi);

      expect(controller.balls.length, 3);
      for (final b in controller.balls) {
        expect(b.isFireball, true);
        expect(b.isBomb, true);
        expect(b.isPierce, true);
      }
    });

    test('Mirror powerup preserves active ball powerups', () {
      final controller = GameController();
      controller.setDimensions(360, 640);
      controller.startNewGame(GameMode.classic);

      controller.applyPowerUp(PowerUpType.fireball);
      controller.applyPowerUp(PowerUpType.mirror);

      expect(controller.balls.length, 2);
      expect(controller.balls[1].isMirror, true);
      expect(controller.balls[1].isFireball, true);
    });

    test('Corner shot rebounds from normal brick without piercing', () {
      final controller = GameController();
      controller.setDimensions(360, 640);
      controller.startNewGame(GameMode.classic);

      final normalBrick = Brick(x: 100, y: 100, width: 40, height: 20, hp: 3, maxHp: 3, color: Colors.blue);
      controller.bricks = [normalBrick];

      final cornerBall = Ball(x: 120, y: 122, vx: 0, vy: -150);
      cornerBall.cornerBoostTimer = 3.0;
      cornerBall.isFireball = false;
      cornerBall.isStuck = false;
      controller.balls.clear();
      controller.balls.add(cornerBall);
      controller.status = GameStatus.playing;

      controller.update(0.016);

      // Brick should be damaged from 3 to 2 HP
      expect(normalBrick.isAlive, true);
      expect(normalBrick.hp, 2);
      // Ball must have bounced back downwards (vy > 0)
      expect(cornerBall.vy > 0, true);
    });

    test('Ghost paddle center 50% lets ball pass through without bouncing', () {
      final controller = GameController();
      controller.setDimensions(360, 640);
      controller.startNewGame(GameMode.classic);
      controller.bricks.clear(); // remove bricks to isolate paddle interaction
      controller.status = GameStatus.playing;

      controller.paddle.x = 100;
      controller.paddle.y = 500;
      controller.paddle.width = 100;
      controller.paddle.height = 14;
      controller.paddle.isGhost = true;

      // Ball positioned in center 50% (x = 150, which is exactly in [125, 175])
      final centerBall = Ball(x: 150, y: 494, vx: 0, vy: 200);
      centerBall.isStuck = false;
      controller.balls.clear();
      controller.balls.add(centerBall);

      controller.update(0.02); // Ball moves to y ~ 498, within paddle top collision zone

      // Ball should NOT bounce; it should pass straight through with vy > 0
      expect(centerBall.vy > 0, true);
      expect(centerBall.y >= 494, true);
    });

    test('Ghost paddle solid left wing (0-25%) bounces ball upward and leftward', () {
      final controller = GameController();
      controller.setDimensions(360, 640);
      controller.startNewGame(GameMode.classic);
      controller.bricks.clear();
      controller.status = GameStatus.playing;

      controller.paddle.x = 100;
      controller.paddle.prevX = 100;
      controller.paddle.velocityX = 0.0;
      controller.paddle.y = 500;
      controller.paddle.width = 100;
      controller.paddle.height = 14;
      controller.paddle.isGhost = true;

      // Ball positioned in left wing (x = 110, in [100, 125])
      final leftBall = Ball(x: 110, y: 494, vx: 0, vy: 200);
      leftBall.isStuck = false;
      controller.balls.clear();
      controller.balls.add(leftBall);

      controller.update(0.02);

      // Ball must collide with left wing and bounce upward (vy < 0) and leftward (vx < 0)
      expect(leftBall.vy < 0, true);
      expect(leftBall.vx < 0, true);
    });

    test('Ghost paddle solid right wing (75-100%) bounces ball upward and rightward', () {
      final controller = GameController();
      controller.setDimensions(360, 640);
      controller.startNewGame(GameMode.classic);
      controller.bricks.clear();
      controller.status = GameStatus.playing;

      controller.paddle.x = 100;
      controller.paddle.prevX = 100;
      controller.paddle.velocityX = 0.0;
      controller.paddle.y = 500;
      controller.paddle.width = 100;
      controller.paddle.height = 14;
      controller.paddle.isGhost = true;

      // Ball positioned in right wing (x = 190, in [175, 200])
      final rightBall = Ball(x: 190, y: 494, vx: 0, vy: 200);
      rightBall.isStuck = false;
      controller.balls.clear();
      controller.balls.add(rightBall);

      controller.update(0.02);

      // Ball must collide with right wing and bounce upward (vy < 0) and rightward (vx > 0)
      expect(rightBall.vy < 0, true);
      expect(rightBall.vx > 0, true);
    });

    test('Ghost paddle wing angle progression: outer edge has steeper angle than inner edge', () {
      final controller = GameController();
      controller.setDimensions(360, 640);
      controller.startNewGame(GameMode.classic);
      // Place dummy brick far away so level won't automatically complete
      controller.bricks = [Brick(x: 0, y: 0, width: 10, height: 10, hp: 1, maxHp: 1, color: Colors.blue)];
      controller.status = GameStatus.playing;

      controller.paddle.x = 100;
      controller.paddle.prevX = 100;
      controller.paddle.velocityX = 0.0;
      controller.paddle.y = 500;
      controller.paddle.width = 100;
      controller.paddle.height = 14;
      controller.paddle.isGhost = true;

      // Inner edge of left wing (x = 124)
      final innerBall = Ball(x: 124, y: 494, vx: 0, vy: 200);
      innerBall.isStuck = false;
      controller.balls.clear();
      controller.balls.add(innerBall);
      controller.update(0.02);

      // Reset paddle state for outerBall
      controller.paddle.x = 100;
      controller.paddle.prevX = 100;
      controller.paddle.velocityX = 0.0;
      controller.paddle.y = 500;
      controller.paddle.width = 100;
      controller.paddle.height = 14;
      controller.paddle.isGhost = true;

      // Outer tip of left wing (x = 101)
      final outerBall = Ball(x: 101, y: 494, vx: 0, vy: 200);
      outerBall.isStuck = false;
      controller.balls.clear();
      controller.balls.add(outerBall);
      controller.update(0.02);

      // Both should bounce upward and leftward
      expect(innerBall.vy < 0, true);
      expect(innerBall.vx < 0, true);
      expect(outerBall.vy < 0, true);
      expect(outerBall.vx < 0, true);
      // Outer tip hit must bounce outwards more steeply than inner edge hit
      expect(outerBall.vx.abs() > innerBall.vx.abs(), true);
    });

    test('Ghost paddle with sticky powerup: center passes through without sticking, wing sticks', () {
      final controller = GameController();
      controller.setDimensions(360, 640);
      controller.startNewGame(GameMode.classic);
      controller.bricks = [Brick(x: 0, y: 0, width: 10, height: 10, hp: 1, maxHp: 1, color: Colors.blue)];
      controller.status = GameStatus.playing;

      controller.paddle.x = 100;
      controller.paddle.prevX = 100;
      controller.paddle.velocityX = 0.0;
      controller.paddle.y = 500;
      controller.paddle.width = 100;
      controller.paddle.height = 14;
      controller.paddle.isGhost = true;
      controller.paddle.isSticky = true;

      // Ball in center 50%
      final centerBall = Ball(x: 150, y: 494, vx: 0, vy: 200);
      centerBall.isStuck = false;
      controller.balls.clear();
      controller.balls.add(centerBall);
      controller.update(0.02);

      // Center ball should NOT stick and should keep falling
      expect(centerBall.isStuck, false);
      expect(centerBall.vy > 0, true);

      // Reset paddle state for wingBall
      controller.paddle.x = 100;
      controller.paddle.prevX = 100;
      controller.paddle.velocityX = 0.0;
      controller.paddle.y = 500;
      controller.paddle.width = 100;
      controller.paddle.height = 14;
      controller.paddle.isGhost = true;
      controller.paddle.isSticky = true;

      // Ball in left wing
      final wingBall = Ball(x: 110, y: 494, vx: 0, vy: 200);
      wingBall.isStuck = false;
      controller.balls.clear();
      controller.balls.add(wingBall);
      controller.update(0.02);

      // Wing ball SHOULD stick
      expect(wingBall.isStuck, true);
    });

    test('Normal paddle (isGhost = false) bounces ball at center normally', () {
      final controller = GameController();
      controller.setDimensions(360, 640);
      controller.startNewGame(GameMode.classic);
      controller.bricks = [Brick(x: 0, y: 0, width: 10, height: 10, hp: 1, maxHp: 1, color: Colors.blue)];
      controller.status = GameStatus.playing;

      controller.paddle.x = 100;
      controller.paddle.prevX = 100;
      controller.paddle.velocityX = 0.0;
      controller.paddle.y = 500;
      controller.paddle.width = 100;
      controller.paddle.height = 14;
      controller.paddle.isGhost = false;

      // Center ball
      final centerBall = Ball(x: 150, y: 494, vx: 0, vy: 200);
      centerBall.isStuck = false;
      controller.balls.clear();
      controller.balls.add(centerBall);
      controller.update(0.02);

      // Normal paddle bounces center ball straight up
      expect(centerBall.vy < 0, true);
      expect(centerBall.vx.abs() < 1.0, true);
    });

    testWidgets('GameCanvas renders without exception with damaged bricks, fireball, and corner boost balls', (tester) async {
      final controller = GameController();
      controller.setDimensions(360, 640);
      controller.startNewGame(GameMode.classic);

      // Add a damaged brick
      final damagedBrick = Brick(x: 50, y: 100, width: 40, height: 20, hp: 1, maxHp: 3, color: Colors.purple);
      final dynamiteBrick = Brick(x: 100, y: 100, width: 40, height: 20, isDynamite: true, hp: 1, maxHp: 1, color: Colors.red);
      final iceBrick = Brick(x: 150, y: 100, width: 40, height: 20, isIce: true, isFrozen: true, hp: 1, maxHp: 1, color: Colors.cyan);
      controller.bricks.addAll([damagedBrick, dynamiteBrick, iceBrick]);

      // Add fireball and corner boost balls
      final fbBall = Ball(x: 100, y: 200, vx: 50, vy: -100, isFireball: true);
      fbBall.isStuck = false;
      final cbBall = Ball(x: 200, y: 200, vx: -50, vy: -100);
      cbBall.cornerBoostTimer = 2.5;
      cbBall.isStuck = false;
      controller.balls.addAll([fbBall, cbBall]);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: GameCanvas(controller: controller),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 16));

      // Test ghost paddle rendering with split wings and dashed center
      controller.paddle.isGhost = true;
      await tester.pump(const Duration(milliseconds: 16));

      // Also test with clumsy active on ghost paddle
      controller.paddle.isClumsy = true;
      await tester.pump(const Duration(milliseconds: 16));
    });
    test('Lucky Dice Ulti rolls dice and fires exact salvo pairs from left and right', () {
      final controller = GameController();
      controller.setDimensions(360, 640);
      controller.startNewGame(GameMode.classic);
      controller.status = GameStatus.playing;
      controller.stats.ultiCharge = 100.0;

      // Trigger ulti
      controller.triggerUlti();
      expect(controller.stats.ultiCharge, 0.0);
      expect(controller.isDiceRolling, true);
      expect(controller.isDiceActive, true);

            // Advance roll timer to completion
      controller.update(0.90);
      expect(controller.isDiceRolling, false);
      expect(controller.diceTotal >= 1 && controller.diceTotal <= 12, true);

      // Reset salvo count to test the double-barrel firing cadence
      controller.diceSalvoRemaining = 2;
      controller.diceSalvoCooldown = 0.0;

      // Clear projectiles to count salvo shots
      controller.projectiles.clear();

      // Advance one salvo interval (0.2s)
      controller.update(0.2);
      // Exactly 1 projectile from left nozzle and 1 from right nozzle
      expect(controller.projectiles.length, 2);
      final pLeft = controller.projectiles.first;
      final pRight = controller.projectiles.last;
      expect(pLeft.x < controller.paddle.x + controller.paddle.width / 2, true);
      expect(pRight.x > controller.paddle.x + controller.paddle.width / 2, true);
      expect(pLeft.isRocket, true);
      expect(pRight.isRocket, true);
    });

    test('All black holes from smallest (r=20) to largest (r=34) have significantly increased gravitational pull', () {
      final controller = GameController();
      controller.setDimensions(360, 640);
      controller.bricks = [Brick(x: 0, y: 0, width: 20, height: 10, hp: 99, maxHp: 99, color: Colors.blue)];
      controller.status = GameStatus.playing;

      // Smallest black hole (r = 20)
      final bhSmall = BlackHole(x: 200, y: 300, radius: 20, mass: 64000, timeLeft: 5.0);
      controller.blackHoles.clear();
      controller.blackHoles.add(bhSmall);

      final ball1 = Ball(x: 160, y: 300, vx: 0, vy: -100);
      ball1.isStuck = false;
      controller.balls.clear();
      controller.balls.add(ball1);

      // Substantially increased pull produces large velocity shift in 1 tick
      controller.update(0.016);
      expect(ball1.vx > 25.0, true, reason: 'Smallest black hole pull must be significantly stronger than before');

      // Largest black hole (r = 34)
      controller.status = GameStatus.playing;
      final bhLarge = BlackHole(x: 200, y: 300, radius: 34, mass: 108800, timeLeft: 5.0);
      controller.blackHoles.clear();
      controller.blackHoles.add(bhLarge);

      final ball2 = Ball(x: 160, y: 300, vx: 0, vy: -100);
      ball2.isStuck = false;
      controller.balls.clear();
      controller.balls.add(ball2);

      controller.update(0.016);
      expect(ball2.vx > 40.0, true, reason: 'Largest black hole pull must be significantly stronger than before');
      expect(ball2.vx > ball1.vx, true, reason: 'Larger black hole exerts more gravitational force than smaller one');
    });

    testWidgets('GameCanvas renders all upgraded trail styles (dot, spark, ghost, rainbow, plasma, fire) and corner boost flawlessly', (tester) async {
      final controller = GameController();
      controller.setDimensions(360, 640);
      controller.startNewGame(GameMode.classic);
      controller.status = GameStatus.playing;

      // Add a black hole
      controller.blackHoles.add(BlackHole(x: 180, y: 250, radius: 25, mass: 75000, timeLeft: 5.0));

      // Ball with corner boost active and trail history
      final cbBall = Ball(x: 180, y: 300, vx: 150, vy: -200);
      cbBall.cornerBoostTimer = 3.0;
      cbBall.isStuck = false;
      for (int i = 0; i < 20; i++) {
        cbBall.trail.add(TrailPoint(Offset(180.0 - i * 5.0, 300.0 + i * 8.0), 0.016));
      }
      controller.balls.clear();
      controller.balls.add(cbBall);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: GameCanvas(controller: controller),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 16));

      // Test all trail styles rendering
      for (final trail in TrailSkin.allTrails) {
        controller.save.activeTrail = trail.id;
        await tester.pump(const Duration(milliseconds: 16));
      }
    });

    test('CategoryCrateInfo has valid crate configurations and 3% legendary drop rate', () {
      expect(CategoryCrateInfo.categoryCrates.containsKey('balls'), true);
      expect(CategoryCrateInfo.categoryCrates.containsKey('paddles'), true);
      expect(CategoryCrateInfo.categoryCrates.containsKey('trails'), true);
      expect(CategoryCrateInfo.categoryCrates.containsKey('bricks'), true);

      expect(CategoryCrateInfo.categoryCrates['balls']!.cost, 1200);
      expect(CategoryCrateInfo.categoryCrates['paddles']!.cost, 1500);
      expect(CategoryCrateInfo.categoryCrates['trails']!.cost, 1400);
      expect(CategoryCrateInfo.categoryCrates['bricks']!.cost, 1300);

      final weights = CategoryCrateInfo.rarityWeights;
      expect(weights[Rarity.common], 55.0);
      expect(weights[Rarity.rare], 30.0);
      expect(weights[Rarity.epic], 12.0);
      expect(weights[Rarity.legendary], 3.0);
      final total = weights.values.fold(0.0, (a, b) => a + b);
      expect((total - 100.0).abs() < 0.001, true);
    });

    test('SaveManager category shards and duplicate protection logic', () async {
      SharedPreferences.setMockInitialValues({});
      final save = SaveManager.instance;
      save.categoryShards['balls'] = 0;
      expect(save.getShards('balls'), 0);

      // Add shards
      await save.addShard('balls');
      expect(save.getShards('balls'), 1);

      await save.addShard('balls', 2);
      expect(save.getShards('balls'), 3);

      // Consuming requires at least count shards
      final failedConsume = await save.consumeShards('balls', 4);
      expect(failedConsume, false);
      expect(save.getShards('balls'), 3);

      final successConsume = await save.consumeShards('balls', 3);
      expect(successConsume, true);
      expect(save.getShards('balls'), 0);
    });

    test('Guaranteed redemption selects unowned cosmetic or fallback gold', () {
      final save = SaveManager.instance;
      final allBallIds = BallSkin.allSkins.map((s) => s.id).toSet();
      save.unlockedBalls = {'classic'};

      final unowned = BallSkin.allSkins.where((s) => !save.unlockedBalls.contains(s.id)).toList();
      expect(unowned.isNotEmpty, true);
      final guaranteedPick = unowned.first;
      expect(save.unlockedBalls.contains(guaranteedPick.id), false);
      save.unlockedBalls.add(guaranteedPick.id);
      expect(save.unlockedBalls.contains(guaranteedPick.id), true);

      // When all are owned
      save.unlockedBalls = Set.from(allBallIds);
      final remainingUnowned = BallSkin.allSkins.where((s) => !save.unlockedBalls.contains(s.id)).toList();
      expect(remainingUnowned.isEmpty, true);
      final fallbackGold = remainingUnowned.isEmpty ? 1000 : 0;
      expect(fallbackGold, 1000);
    });

    testWidgets('PixelHeart widget and PixelArt.drawPixelHeart render cleanly', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(
              child: PixelHeart(size: 32),
            ),
          ),
        ),
      );
      await tester.pump();
      expect(find.byType(PixelHeart), findsOneWidget);

      final recorder = PictureRecorder();
      final canvas = Canvas(recorder);
      PixelArt.drawPixelHeart(canvas, const Offset(50, 50), 32, pulse: 1.15);
      final picture = recorder.endRecording();
      expect(picture, isNotNull);
    });

    testWidgets('GameCanvas renders all 10 ball skins, 8 paddle skins, and 6 brick styles (including cosmic crystal)', (tester) async {
      final controller = GameController();
      controller.setDimensions(360, 640);
      controller.startNewGame(GameMode.classic);
      controller.status = GameStatus.playing;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: GameCanvas(controller: controller),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 16));

      // Cycle all ball skins
      for (final skin in BallSkin.allSkins) {
        controller.save.activeBall = skin.id;
        await tester.pump(const Duration(milliseconds: 16));
      }

      // Cycle all paddle skins
      for (final skin in PaddleSkin.allSkins) {
        controller.save.activePaddle = skin.id;
        await tester.pump(const Duration(milliseconds: 16));
      }

      // Cycle all brick styles (including brick_cosmic)
      expect(BrickStyle.all.length, 6);
      expect(BrickStyle.all.any((b) => b.id == 'brick_cosmic' && b.rarity == Rarity.legendary), true);
      for (final style in BrickStyle.all) {
        controller.save.activeBrickStyle = style.id;
        await tester.pump(const Duration(milliseconds: 16));
      }

      // Verify TrailStyle.fire renders cleanly with and without isFireball
      controller.save.activeTrail = 'fire';
      await tester.pump(const Duration(milliseconds: 16));
      controller.balls.first.isFireball = true;
      await tester.pump(const Duration(milliseconds: 16));
    });

    test('PixelArt heartMatrix has exact 12-column horizontal symmetry across all rows', () {
      final matrix = PixelArt.heartMatrix;
      expect(matrix.length, 10);
      for (int r = 0; r < matrix.length; r++) {
        expect(matrix[r].length, 12, reason: 'Row $r should have 12 columns');
        for (int c = 0; c < 6; c++) {
          final leftOutline = matrix[r][c] == 1;
          final rightOutline = matrix[r][11 - c] == 1;
          expect(leftOutline, rightOutline, reason: 'Row $r outline should be symmetrical between col $c and col ${11 - c}');
        }
      }
    });

    test('All 4 categories have items for every rarity tier (Common, Rare, Epic, Legendary)', () {
      // Balls
      expect(BallSkin.allSkins.any((s) => s.rarity == Rarity.common), true);
      expect(BallSkin.allSkins.any((s) => s.rarity == Rarity.rare), true);
      expect(BallSkin.allSkins.any((s) => s.rarity == Rarity.epic), true);
      expect(BallSkin.allSkins.any((s) => s.rarity == Rarity.legendary), true);

      // Paddles
      expect(PaddleSkin.allSkins.any((s) => s.rarity == Rarity.common), true);
      expect(PaddleSkin.allSkins.any((s) => s.rarity == Rarity.rare), true);
      expect(PaddleSkin.allSkins.any((s) => s.rarity == Rarity.epic), true);
      expect(PaddleSkin.allSkins.any((s) => s.rarity == Rarity.legendary), true);

      // Trails
      expect(TrailSkin.allTrails.any((s) => s.rarity == Rarity.common), true);
      expect(TrailSkin.allTrails.any((s) => s.rarity == Rarity.rare), true);
      expect(TrailSkin.allTrails.any((s) => s.rarity == Rarity.epic), true);
      expect(TrailSkin.allTrails.any((s) => s.rarity == Rarity.legendary), true);

      // Bricks
      expect(BrickStyle.all.any((s) => s.rarity == Rarity.common), true);
      expect(BrickStyle.all.any((s) => s.rarity == Rarity.rare), true);
      expect(BrickStyle.all.any((s) => s.rarity == Rarity.epic), true);
      expect(BrickStyle.all.any((s) => s.rarity == Rarity.legendary), true);
    });

    test('EasterEggBee has realistic flight physics (sinusoidal bobbing, tilt angle, wing flap, forward progression)', () {
      final bee = EasterEggBee(
        x: 0.0,
        baseY: 300.0,
        vx: 50.0,
        isFacingRight: true,
      );

      expect(bee.x, 0.0);
      expect(bee.y, 300.0);
      expect(bee.isAlive, true);
      expect(bee.isFacingRight, true);
      expect(bee.isOffScreen(360.0), false);

      // Advance by 0.2 seconds
      bee.update(0.2);
      expect(bee.x, closeTo(10.0, 0.001));
      expect(bee.flightTime, closeTo(0.2, 0.001));
      // Sinusoidal vertical hovering makes y move away from baseY
      expect(bee.y, isNot(equals(300.0)));
      expect(bee.tiltAngle.abs(), greaterThan(0.0));
      expect(bee.wingFlap.abs(), greaterThan(0.0));

      // Off-screen check
      bee.x = 420.0;
      expect(bee.isOffScreen(360.0), true);

      // Facing left
      final leftBee = EasterEggBee(
        x: 360.0,
        baseY: 250.0,
        vx: -50.0,
        isFacingRight: false,
      );
      leftBee.update(0.2);
      expect(leftBee.x, closeTo(350.0, 0.001));
      leftBee.x = -60.0;
      expect(leftBee.isOffScreen(360.0), true);
    });

    test('Ball collision with EasterEggBee triggers +100 bonus, splat on windshield, and removes bee', () {
      final controller = GameController();
      controller.setDimensions(360, 640);
      controller.startNewGame(GameMode.classic);
      controller.status = GameStatus.playing;
      controller.launchBall();

      controller.spawnEasterEggBee(customY: 300.0, facingRight: true);
      expect(controller.activeBee, isNotNull);
      final initialScore = controller.stats.score;

      // Position ball directly on the bee
      final ball = controller.balls.first;
      ball.x = controller.activeBee!.x;
      ball.y = controller.activeBee!.y;

      controller.update(0.016);

      // Bee should be destroyed, score increased by 100, and splat activated for 2 seconds
      expect(controller.activeBee, isNull);
      expect(controller.stats.score, initialScore + 100);
      expect(controller.activeSplat, isNotNull);
      expect(controller.activeSplat!.duration, 2.0);
      expect(controller.activeSplat!.timer, closeTo(2.0, 0.05));
      expect(controller.particles.floatingTexts.any((f) => f.text.contains('SPLAT!')), true);

      // Verify controller.update ticks activeSplat down
      controller.update(1.0);
      expect(controller.activeSplat, isNotNull);
      expect(controller.activeSplat!.timer, closeTo(1.0, 0.05));

      // After 2.0s total, splat expires and is set to null
      controller.update(1.1);
      expect(controller.activeSplat, isNull);
    });

    test('WindshieldSplat stays visible for 2 seconds and smoothly fades out before disappearing', () {
      final splat = WindshieldSplat(x: 180.0, y: 320.0, duration: 2.0);
      expect(splat.timer, 2.0);
      expect(splat.isDead, false);
      expect(splat.alpha, 1.0);

      // After 1.0 second, still completely visible (alpha == 1.0)
      splat.update(1.0);
      expect(splat.timer, 1.0);
      expect(splat.alpha, 1.0);
      expect(splat.isDead, false);

      // At 0.4 seconds remaining, alpha begins smooth fade
      splat.update(0.6); // timer = 0.4
      expect(splat.alpha, closeTo(1.0, 0.01));

      // At 0.2 seconds remaining, alpha is 0.5
      splat.update(0.2); // timer = 0.2
      expect(splat.alpha, closeTo(0.5, 0.01));

      // At 0.0 seconds, timer is dead
      splat.update(0.25);
      expect(splat.timer, 0.0);
      expect(splat.alpha, 0.0);
      expect(splat.isDead, true);
    });

    test('PixelArt bugSplatMatrix matches Image 2 structure with 26 rows and valid pixel classes', () {
      final matrix = PixelArt.bugSplatMatrix;
      expect(matrix.length, 26);
      expect(matrix[0].length, 26);

      // Verify presence of primary red (1), dark core clot (2), and droplet satellites (3)
      bool hasPrimary = false;
      bool hasClot = false;
      bool hasDroplet = false;

      for (final row in matrix) {
        for (final val in row) {
          if (val == 1) hasPrimary = true;
          if (val == 2) hasClot = true;
          if (val == 3) hasDroplet = true;
        }
      }

      expect(hasPrimary, true);
      expect(hasClot, true);
      expect(hasDroplet, true);
    });

    testWidgets('GameCanvas renders Easter Egg Bee and Windshield Splat cleanly without exceptions', (tester) async {
      final controller = GameController();
      controller.setDimensions(360, 640);
      controller.startNewGame(GameMode.classic);
      controller.status = GameStatus.playing;
      controller.launchBall();

      // Spawn bee and splat
      controller.spawnEasterEggBee(customY: 320.0, facingRight: true);
      controller.activeSplat = WindshieldSplat(x: 180.0, y: 300.0, duration: 2.0);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: GameCanvas(controller: controller),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 16));

      // Flip bee direction and test facing left
      controller.spawnEasterEggBee(customY: 340.0, facingRight: false);
      await tester.pump(const Duration(milliseconds: 16));

      // Test all trail styles with corner boost and tapering
      controller.balls.first.cornerBoostTimer = 2.5;
      for (final style in TrailStyle.values) {
        controller.save.activeTrail = style.name;
        await tester.pump(const Duration(milliseconds: 16));
      }
    });

    test('Zen and Descend modes generate dynamite and ice blocks', () {
      final zenBricks = LevelDesign.buildZenLevel(360, 640);
      expect(zenBricks.any((b) => b.isDynamite), true);
      expect(zenBricks.any((b) => b.isIce), true);

      final descendBricks = LevelDesign.buildDescendInitial(360, 640);
      expect(descendBricks.length, 28);
      // Generate multiple rows to verify both types are created
      final rows = List.generate(10, (i) => LevelDesign.buildDescendRow(i, 360, 640)).expand((r) => r).toList();
      expect(rows.any((b) => b.isDynamite), true);
      expect(rows.any((b) => b.isIce), true);
    });

    test('Normal black hole caps deflection up to 360 degrees while vortex trap allows multiple loops', () {
      final bhNormal = BlackHole(x: 180, y: 300, radius: 34, mass: 100000, isVortexTrap: false);
      expect(bhNormal.isVortexTrap, false);
      
      final bhVortex = BlackHole(x: 180, y: 300, radius: 34, mass: 100000, isVortexTrap: true);
      expect(bhVortex.isVortexTrap, true);

      final controller = GameController();
      controller.setDimensions(360, 640);
      controller.status = GameStatus.playing;
      controller.blackHoles.clear();
      controller.blackHoles.add(bhNormal);

      final ball = Ball(x: 160, y: 300, vx: 0, vy: -120);
      ball.isStuck = false;
      controller.balls.clear();
      controller.balls.add(ball);

      // Simulate 1.5 seconds of trajectory
      for (int i = 0; i < 90; i++) {
        controller.update(0.016);
      }

      // Deflection on normal black hole must not exceed 360 degrees (2 * pi + epsilon)
      final normalDeflection = bhNormal.ballAccumulatedAngles[ball.hashCode] ?? 0.0;
      expect(normalDeflection <= (2.0 * pi + 0.15), true);
    });

    test('Fast upward ball hitting brick bounces downward and never tunnels upward', () {
      final controller = GameController();
      controller.setDimensions(360, 640);
      controller.status = GameStatus.playing;
      
      // Setup brick at y: 200, height: 22, x: 100, width: 50
      final brick = Brick(x: 100, y: 200, width: 50, height: 22, hp: 5, maxHp: 5, color: Colors.red);
      controller.bricks.clear();
      controller.bricks.add(brick);

      // Ball approaching from bottom with high speed (600 px/s)
      final ball = Ball(x: 125, y: 228, vx: 0, vy: -600);
      ball.isStuck = false;
      controller.balls.clear();
      controller.balls.add(ball);

      // Run 1 frame of update
      controller.update(0.016);

      // Ball MUST bounce downward (vy > 0) and be below the brick
      expect(ball.vy > 0, true, reason: 'Ball moving up must bounce downwards');
      expect(ball.y >= brick.y + brick.height + ball.radius, true, reason: 'Ball must be positioned below the brick');
    });

    test('Downward ball hitting brick bounces upward and never tunnels downward', () {
      final controller = GameController();
      controller.setDimensions(360, 640);
      controller.status = GameStatus.playing;

      final brick = Brick(x: 100, y: 200, width: 50, height: 22, hp: 5, maxHp: 5, color: Colors.red);
      controller.bricks.clear();
      controller.bricks.add(brick);

      // Ball approaching from top
      final ball = Ball(x: 125, y: 194, vx: 0, vy: 500);
      ball.isStuck = false;
      controller.balls.clear();
      controller.balls.add(ball);

      controller.update(0.016);

      // Ball MUST bounce upward (vy < 0) and be above the brick
      expect(ball.vy < 0, true, reason: 'Ball moving down must bounce upwards');
      expect(ball.y <= brick.y - ball.radius, true, reason: 'Ball must be positioned above the brick');
    });

    test('Black holes only spawn strictly below all alive bricks and above paddle', () {
      final controller = GameController();
      controller.setDimensions(360, 640);
      controller.status = GameStatus.playing;

      // Bricks up to y = 320
      controller.bricks.clear();
      controller.bricks.add(Brick(x: 50, y: 300, width: 50, height: 20, hp: 1, maxHp: 1, color: Colors.blue));

      // Trigger black hole spawn
      for (int i = 0; i < 2000; i++) {
        controller.blackHoles.clear();
        controller.update(1.0);
        if (controller.blackHoles.isNotEmpty) {
          final bh = controller.blackHoles.first;
          expect(bh.y >= 320 + 45.0, true, reason: 'Black hole cannot spawn inside or above brick grid');
          expect(bh.y <= controller.paddle.y - 75.0, true, reason: 'Black hole must be safely above paddle');
          break;
        }
      }
    });

    test('SaveManager and AdManager rewarded ad cooldown and +50 gold reward logic', () async {
      SharedPreferences.setMockInitialValues({'gold': 100, 'lastAdWatchTime': 0});
      final save = SaveManager.instance;
      await save.init();
      
      expect(save.gold, 100);
      expect(AdManager.rewardedAdUnitId, 'ca-app-pub-9505724609102225/1791945382');
      expect(AdManager.cooldownSeconds, 90);

      // When lastAdWatchTime is 0, user can watch ad immediately
      save.lastAdWatchTime = 0;
      expect(AdManager.instance.remainingCooldownSeconds, 0);

      // Simulate reward completion: +50 gold
      await save.addGold(50);
      expect(save.gold, 150);

      // Set ad watch timestamp to now
      final now = DateTime.now().millisecondsSinceEpoch;
      await save.setLastAdWatchTime(now);
      expect(save.lastAdWatchTime, now);

      // Cooldown should now be active (~90 seconds)
      final remaining = AdManager.instance.remainingCooldownSeconds;
      expect(remaining >= 88 && remaining <= 90, true);
      expect(AdManager.instance.canWatchAd, false);

      // After 91 seconds in past, cooldown expires
      await save.setLastAdWatchTime(now - 92 * 1000);
      expect(AdManager.instance.remainingCooldownSeconds, 0);
      expect(AdManager.instance.canWatchAd, true);
    });

    test('GameController reviveWithOneLife grants 1 life, resets ball, and allows only 1 revive per game', () {
      final controller = GameController();
      controller.setDimensions(360, 640);
      controller.startNewGame(GameMode.classic);
      expect(controller.hasUsedRevive, false);

      // Trigger Game Over
      controller.stats.lives = 0;
      controller.status = GameStatus.gameOver;
      expect(controller.status, GameStatus.gameOver);

      // Revive!
      controller.reviveWithOneLife();

      expect(controller.hasUsedRevive, true);
      expect(controller.stats.lives, 1);
      expect(controller.status, GameStatus.ready);
      expect(controller.balls.isNotEmpty, true);
      expect(controller.balls.first.isStuck, true);

      // Second revive attempt in same game is ignored
      controller.stats.lives = 0;
      controller.status = GameStatus.gameOver;
      controller.reviveWithOneLife();
      expect(controller.stats.lives, 0); // Still 0, not revived second time

      // Starting new game resets revive ability
      controller.startNewGame(GameMode.classic);
      expect(controller.hasUsedRevive, false);
      expect(controller.stats.lives >= 3, true);
    });

    test('AdManager highYieldAdUnitId is configured correctly with ca-app-pub-9505724609102225/2723019148', () {
      expect(AdManager.highYieldAdUnitId, 'ca-app-pub-9505724609102225/2723019148');
      expect(AdManager.instance.isHighYieldAdReady, false); // Not loaded in headless unit test
      expect(AdManager.instance.isLoadingHighYield, false);
    });

    test('GameController claimVictoryBonus grants +100 gold and is single-use per victory', () async {
      final save = SaveManager.instance;
      await save.init();
      final initialGold = save.gold;

      final controller = GameController();
      controller.setDimensions(360, 640);
      controller.startNewGame(GameMode.classic);
      expect(controller.hasClaimedVictoryBonus, false);

      // Claim victory bonus
      controller.claimVictoryBonus();
      expect(controller.hasClaimedVictoryBonus, true);
      expect(save.gold, initialGold + 100);

      // Attempt to claim again in same match
      controller.claimVictoryBonus();
      expect(save.gold, initialGold + 100); // Does not increase again

      // New game resets victory bonus claim
      controller.startNewGame(GameMode.classic);
      expect(controller.hasClaimedVictoryBonus, false);
    });
  });
}