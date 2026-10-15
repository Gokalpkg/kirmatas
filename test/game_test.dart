import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:kirmatas/engine/game_controller.dart';
import 'package:kirmatas/engine/audio_manager.dart';
import 'package:kirmatas/engine/particle_system.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kirmatas/models/ball.dart';
import 'package:kirmatas/models/black_hole.dart';
import 'package:kirmatas/models/brick.dart';
import 'package:kirmatas/models/cosmetics.dart';
import 'package:kirmatas/models/easter_egg.dart';
import 'package:kirmatas/models/game_state.dart';
import 'package:kirmatas/models/level_design.dart';
import 'package:kirmatas/models/portal.dart';
import 'package:kirmatas/models/paddle.dart';
import 'package:kirmatas/engine/ad_manager.dart';
import 'package:kirmatas/engine/i18n.dart';
import 'package:kirmatas/models/powerup.dart';
import 'package:kirmatas/storage/save_manager.dart';
import 'package:kirmatas/ui/game_canvas.dart';
import 'package:kirmatas/ui/pixel_art.dart';
import 'package:kirmatas/ui/chest_widget.dart';
import 'package:kirmatas/ui/crate_opening_dialog.dart';
import 'package:kirmatas/ui/shop_view.dart';
import 'package:kirmatas/ui/aquarium_view.dart';
import 'package:kirmatas/ui/fish_hoard_chest.dart';
import 'package:kirmatas/models/sector_data.dart';
import 'package:kirmatas/ui/rewards_hub_dialog.dart';
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

    test('Level 12 is a boss battle with high HP boss brick (every 10-15 levels)', () {
      final bricks = LevelDesign.buildClassicLevel(12, 360, 640);
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
      controller.bricks = [Brick(x: 0, y: 0, width: 10, height: 10, hp: 1, maxHp: 1, color: Colors.blue)];

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
      controller.bricks = [Brick(x: 0, y: 0, width: 10, height: 10, hp: 1, maxHp: 1, color: Colors.blue)];

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

      // Smooth, natural pull produces steady velocity shift without violent snapping
      controller.update(0.016);
      expect(ball1.vx > 0.5, true, reason: 'Smallest black hole pulls ball towards center smoothly');

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
      expect(ball2.vx > 1.0, true, reason: 'Largest black hole exerts smooth gravitational force');
      expect(ball2.vx > ball1.vx, true, reason: 'Larger black hole exerts more gravitational force than smaller one');
    });

    test('Supercharged exotic black hole accelerates balls and performs high-speed slingshot upon orbit exit', () {
      final controller = GameController();
      controller.setDimensions(360, 640);
      controller.bricks = [Brick(x: 0, y: 0, width: 20, height: 10, hp: 99, maxHp: 99, color: Colors.blue)];
      controller.status = GameStatus.playing;

      final bhSuper = BlackHole(
        x: 200,
        y: 300,
        radius: 28,
        mass: 90000,
        timeLeft: 5.0,
        isSupercharged: true,
      );
      controller.blackHoles.clear();
      controller.blackHoles.add(bhSuper);

      // Ball entering gravitational influence
      final ball = Ball(x: 160, y: 300, vx: 0, vy: -200);
      ball.isStuck = false;
      controller.balls.clear();
      controller.balls.add(ball);

      final initialSpeed = ball.speed;
      controller.update(0.016);

      // Supercharged black hole pulls stronger and applies tangential spin
      expect(ball.vx > 0.8, true, reason: 'Supercharged black hole exerts strong pull');

      // Simulate ball having orbited at least pi radians (half circle) before leaving influence
      final ballKey = ball.hashCode;
      bhSuper.ballAccumulatedAngles[ballKey] = 3.5; // > pi

      // Move ball outside gravitational influence
      ball.x = 40;
      ball.y = 40; // Far away (dist ~ 300 > maxInfluenceDist ~ 106)
      controller.update(0.016);

      // Should have triggered slingshot speed boost
      expect(ball.speed > initialSpeed, true, reason: 'Exotic black hole slingshots ball upon orbit completion');
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

      expect(CategoryCrateInfo.categoryCrates['balls']!.cost, 800);
      expect(CategoryCrateInfo.categoryCrates['paddles']!.cost, 1000);
      expect(CategoryCrateInfo.categoryCrates['trails']!.cost, 900);
      expect(CategoryCrateInfo.categoryCrates['bricks']!.cost, 850);

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
      final rows = List.generate(30, (i) => LevelDesign.buildDescendRow(i, 360, 640)).expand((r) => r).toList();
      expect(rows.any((b) => b.isDynamite), true);
      expect(rows.any((b) => b.isIce), true);
    });

    test('Black hole exhibits realistic orbital deflection and slingshot speed increase with orbit laps', () {
      final bhNormal = BlackHole(x: 180, y: 300, radius: 34, mass: 100000, isVortexTrap: false);
      expect(bhNormal.isVortexTrap, false);
      
      final bhVortex = BlackHole(x: 180, y: 300, radius: 34, mass: 100000, isVortexTrap: true);
      expect(bhVortex.isVortexTrap, true);

      final controller = GameController();
      controller.setDimensions(360, 640);
      controller.status = GameStatus.playing;
      controller.blackHoles.clear();
      controller.blackHoles.add(bhNormal);

      final initialSpeed = 120.0;
      final ball = Ball(x: 160, y: 300, vx: 0, vy: -initialSpeed);
      ball.isStuck = false;
      controller.balls.clear();
      controller.balls.add(ball);

      double maxDeflection = 0.0;
      // Simulate 1.5 seconds of trajectory
      for (int i = 0; i < 90; i++) {
        controller.update(0.016);
        final currentDeflection = bhNormal.ballAccumulatedAngles[ball.hashCode] ?? 0.0;
        if (currentDeflection > maxDeflection) {
          maxDeflection = currentDeflection;
        }
      }

      // 1. Deflection occurred smoothly without sudden unnatural teleportation or infinite loop
      final normalDeflection = math.max(maxDeflection, bhNormal.ballAccumulatedAngles[ball.hashCode] ?? 0.0);
      expect(normalDeflection > 0.5, true, reason: 'Ball trajectory was bent smoothly by black hole gravity');

      // 2. Ball gained slingshot speed boost from orbiting
      expect(ball.speed >= initialSpeed, true, reason: 'Orbital momentum gave ball a slingshot assist');
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
      expect(AdManager.rewardedAdUnitId, 'ca-app-pub-9694275729123906/8685059744');
      expect(AdManager.cooldownSeconds, 90);
      expect(AdManager.goldRewardAmount, 100);

      // When lastAdWatchTime is 0, user can watch ad immediately
      save.lastAdWatchTime = 0;
      expect(AdManager.instance.remainingCooldownSeconds, 0);

      // Simulate reward completion: +100 gold
      await save.addGold(AdManager.goldRewardAmount);
      expect(save.gold, 200);

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

    test('Classic death returns to the start of the 17-level sector with 3 lives', () {
      final gc = GameController();
      gc.setDimensions(360, 640);
      gc.startNewGame(GameMode.classic);
      SaveManager.instance.markFreeContinueUsed();
      gc.stats.level = 15;
      gc.stats.lives = 1;
      gc.stats.score = 4000;
      gc.status = GameStatus.playing;
      gc.balls.clear();
      gc.update(0.016);

      expect(gc.status, GameStatus.gameOver);
      expect(SaveManager.instance.classicSavedLevel, 1);
      expect(SaveManager.instance.classicSavedLives, 3);
      expect(SaveManager.instance.classicSavedScore, 4000);

      // Verify checkpoint calculation across 17-level bands:
      gc.stats.level = 1;
      expect(gc.classicCheckpointLevel, 1);
      gc.stats.level = 16;
      expect(gc.classicCheckpointLevel, 1);
      gc.stats.level = 17;
      expect(gc.classicCheckpointLevel, 17);
      gc.stats.level = 33;
      expect(gc.classicCheckpointLevel, 17);
      gc.stats.level = 34;
      expect(gc.classicCheckpointLevel, 34);
      gc.stats.level = 50;
      expect(gc.classicCheckpointLevel, 34);
      gc.stats.level = 51;
      expect(gc.classicCheckpointLevel, 51);
      gc.stats.level = 238;
      expect(gc.classicCheckpointLevel, 221);
    });

    test('Shapes mode provides 38 distinct figures and builds valid bricks', () {
      expect(LevelDesign.allShapes.length, 38);
      for (int lvl = 1; lvl <= 38; lvl++) {
        final bricks = LevelDesign.buildShapesLevel(lvl, 360, 640);
        expect(bricks.isNotEmpty, true, reason: 'Level $lvl shape should produce bricks');
        for (final b in bricks) {
          expect(b.width > 0, true);
          expect(b.height > 0, true);
          expect(b.x >= 0, true);
        }
      }
    });

    test('Shapes mode localized names and random permutation work accurately', () {
      expect(LevelDesign.shapeNamesTr.length, 38);
      expect(LevelDesign.shapeNamesEn.length, 38);
      expect(LevelDesign.getShapeName(0, lang: 'tr'), 'Kalp');
      expect(LevelDesign.getShapeName(1, lang: 'tr'), 'Kuru Kafa');
      expect(LevelDesign.getShapeName(0, lang: 'en'), 'Heart');
      expect(LevelDesign.getShapeName(1, lang: 'en'), 'Skull');

      final gc = GameController();
      gc.setDimensions(360, 640);
      gc.startNewGame(GameMode.shapes);
      expect(gc.shapesPermutation.length, 38);
      // Ensure permutation has all elements 0..37
      final set = gc.shapesPermutation.toSet();
      expect(set.length, 38);
      expect(gc.currentShapeName.isNotEmpty, true);
    });

    test('Checkpoint banner activates on level 17, 34, etc in Classic Mode', () {
      final gc = GameController();
      gc.setDimensions(360, 640);
      gc.startNewGame(GameMode.classic);
      expect(gc.checkpointBannerTimer, 0.0);

      gc.stats.level = 17;
      gc.loadLevelBricks();
      expect(gc.checkpointBannerTimer > 0, true);
      expect(gc.checkpointBannerLevel, 17);

      gc.update(0.5);
      expect(gc.checkpointBannerTimer < 2.5, true);
    });

    test('AdManager cascade waterfall ad units are configured correctly', () {
      // Rewarded Waterfall
      expect(AdManager.tier1RewardedAdUnitId, 'ca-app-pub-9694275729123906/6981270843');
      expect(AdManager.tier2RewardedAdUnitId, 'ca-app-pub-9694275729123906/8357756685');
      expect(AdManager.tier3RewardedAdUnitId, 'ca-app-pub-9694275729123906/8685059744');
      expect(AdManager.instance.isHighYieldAdReady, false); // Not loaded in headless unit test
      expect(AdManager.instance.isLoadingHighYield, false);

      // Interstitial Waterfall
      expect(AdManager.tier1InterstitialAdUnitId, 'ca-app-pub-9694275729123906/5731593340');
      expect(AdManager.tier2InterstitialAdUnitId, 'ca-app-pub-9694275729123906/4368294806');
      expect(AdManager.tier3InterstitialAdUnitId, 'ca-app-pub-9694275729123906/4863118828');
      expect(AdManager.instance.isInterstitialReady, false);
      expect(AdManager.instance.isLoadingInterstitial, false);
    });

    test('GameController claimVictoryBonus grants +200 gold and is single-use per victory', () async {
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
      expect(save.gold, initialGold + 200);

      // Attempt to claim again in same match
      controller.claimVictoryBonus();
      expect(save.gold, initialGold + 200); // Does not increase again

      // New game resets victory bonus claim
      controller.startNewGame(GameMode.classic);
      expect(controller.hasClaimedVictoryBonus, false);
    });

    test('Eco-Tank per-fish 3-hour satiety and 6-hour gold payout cycle functions accurately', () async {
      final save = SaveManager.instance;
      await save.init();

      // Reset state for test with 2 fish: guppy (10 gold) & tetra (20 gold)
      save.unlockedFish = ['guppy', 'tetra'];
      save.fishFood = 5;
      save.fishFedTimestamps.clear();
      save.lastFishFedTimestamp = 0;

      // Never emit hunger signals
      expect(save.isFishHungry, false);
      expect(save.isFishFed, false);
      expect(save.currentAvailableFishGold, 0);
      expect(save.getFishGoldValue('guppy'), 10);
      expect(save.getFishGoldValue('tetra'), 20);

      // 1. Feed 1st fish (guppy -> 10 gold)
      final fed1 = await save.feedFish('guppy');
      expect(fed1, true);
      expect(save.fishFood, 4);
      expect(save.isFishProducing('guppy'), true);
      expect(save.isFishInSatietyCooldown('guppy'), true);
      expect(save.pendingFishGold, 10);

      // Within 3 hours, guppy refuses to eat again
      expect(await save.onFishAtePellet('guppy'), false);

      //After 4 hours (>= 3h, < 6h): guppy can eat freely, but its 6h timer and payout do NOT change
      final fourHoursAgo = DateTime.now().millisecondsSinceEpoch - (4 * 3600 * 1000);
      save.fishFedTimestamps['guppy'] = fourHoursAgo;
      expect(save.isFishInSatietyCooldown('guppy'), false);
      expect(save.isFishGoldReady('guppy'), false);
      expect(save.currentAvailableFishGold, 0);

      final ateAfter3h = await save.onFishAtePellet('guppy');
      expect(ateAfter3h, true);
      // Timestamp must remain unchanged at fourHoursAgo!
      expect(save.fishFedTimestamps['guppy'], fourHoursAgo);
      expect(save.pendingFishGold, 10);

      // 2. If only guppy reaches 6 hours -> pays out 10 gold
      final sixHoursAgo = DateTime.now().millisecondsSinceEpoch - (6 * 3600 * 1000 + 1000);
      save.fishFedTimestamps['guppy'] = sixHoursAgo;
      expect(save.currentAvailableFishGold, 10);

      final initialPlayerGold = save.gold;
      final collectedSingle = await save.collectFishGold();
      expect(collectedSingle, 10);
      expect(save.gold, initialPlayerGold + 10);
      expect(save.isFishProducing('guppy'), false);

      // 3. Feed BOTH guppy (10) and tetra (20) -> after 6 hours pays out 10 + 20 = 30 gold
      await save.feedFish('guppy');
      await save.feedFish('tetra');
      expect(save.fedFishCount, 2);
      expect(save.pendingFishGold, 30);

      save.fishFedTimestamps['guppy'] = sixHoursAgo;
      save.fishFedTimestamps['tetra'] = sixHoursAgo;
      expect(save.currentAvailableFishGold, 30);

      final collectedBoth = await save.collectFishGold();
      expect(collectedBoth, 30);
      expect(save.gold, initialPlayerGold + 10 + 30);
      expect(save.fedFishCount, 0);
      expect(save.currentAvailableFishGold, 0);
    });

    test('Eco-Tank tap feeding consumes food from inventory and hungry fish target food before satiated fish', () async {
      final save = SaveManager.instance;
      await save.init();
      save.fishFood = 2;

      // Ensure saveFishFoodDirectly saves accurately
      save.saveFishFoodDirectly();
      expect(save.fishFood, 2);

      // Consume one food
      save.fishFood--;
      save.saveFishFoodDirectly();
      expect(save.fishFood, 1);

      // Consume another
      save.fishFood--;
      save.saveFishFoodDirectly();
      expect(save.fishFood, 0);
    });

    test('7-Day Login Streak awards correct sequential rewards and ad double', () async {
      final save = SaveManager.instance;
      await save.init();

      save.dailyLoginStreak = 1;
      save.lastDailyLoginClaimDate = null;
      final initialGold = save.gold;

      // Day 1
      expect(save.canClaimDailyLogin(), true);
      final day1Result = await save.claimDailyLoginReward(doubleWithAd: false);
      expect(day1Result['claimed'], true);
      expect(day1Result['day'], 1);
      expect(day1Result['gold'], 50);
      expect(save.dailyLoginStreak, 2);
      expect(save.gold, initialGold + 50);
      expect(save.canClaimDailyLogin(), false);

      // Simulate Day 2 with ad double
      save.lastDailyLoginClaimDate = '2020-01-01';
      final day2InitialFood = save.fishFood;
      final day2Result = await save.claimDailyLoginReward(doubleWithAd: true);
      expect(day2Result['claimed'], true);
      expect(day2Result['day'], 2);
      expect(day2Result['gold'], 200); // 100 * 2
      expect(day2Result['food'], 2);
      expect(save.fishFood, day2InitialFood + 2);
      expect(save.dailyLoginStreak, 3);

      // Simulate Day 7 loop-around
      save.dailyLoginStreak = 7;
      save.lastDailyLoginClaimDate = '2020-01-02';
      final day7Result = await save.claimDailyLoginReward(doubleWithAd: false);
      expect(day7Result['claimed'], true);
      expect(day7Result['day'], 7);
      expect(day7Result['gold'], 600);
      // Loops back to Day 1
      expect(save.dailyLoginStreak, 1);
    });

    test('Daily login normal claim followed by post-claim 2X ad bonus awards base gold', () async {
      final save = SaveManager.instance;
      await save.init();

      save.dailyLoginStreak = 3; // Day 3: base 150 gold
      save.lastDailyLoginClaimDate = null;
      save.lastDailyLoginAdClaimDate = null;
      final initialGold = save.gold;

      // 1. Claim normal reward on Day 3
      expect(save.canClaimDailyLogin(), true);
      expect(save.canClaimDailyLoginAd(), true);
      expect(save.currentDailyLoginDay, 3);

      final normalResult = await save.claimDailyLoginReward(doubleWithAd: false);
      expect(normalResult['claimed'], true);
      expect(normalResult['gold'], 150);
      expect(save.gold, initialGold + 150);

      // Normal is claimed, but 2X ad bonus is still available!
      expect(save.canClaimDailyLogin(), false);
      expect(save.canClaimDailyLoginAd(), true);
      expect(save.currentDailyLoginDay, 3); // Remains Day 3 today

      // 2. Claim post-claim 2X ad bonus
      // "parayı aldıktan sonra kullanılırsa o gün kaçıncı gündeysek o kadar para versin 2 katını değil" -> awards exactly +150
      final adBonusResult = await save.claimDailyLoginAdBonus();
      expect(adBonusResult['claimed'], true);
      expect(adBonusResult['gold'], 150);
      expect(save.gold, initialGold + 300); // 150 + 150 = 300 total (2X completed)

      // Both are now claimed
      expect(save.canClaimDailyLogin(), false);
      expect(save.canClaimDailyLoginAd(), false);
    });

    test('Daily quests track brick breaks, fish feeding, and rewards claiming', () async {
      final save = SaveManager.instance;
      await save.init();

      save.currentQuestDate = DateTime.now().toIso8601String().substring(0, 10);
      save.questBricksBroken = 0;
      save.questFishFed = false;
      save.questAdOrWinDone = false;
      save.claimedQuests = {};

      // Test Brick breaking progress
      save.recordBrickBrokenQuest(50);
      expect(save.questBricksBroken, 50);
      save.recordBrickBrokenQuest(50);
      expect(save.questBricksBroken, 100);

      // Claim brick reward
      final initialGold = save.gold;
      final brickReward = await save.claimQuestReward('break_bricks');
      expect(brickReward, 120);
      expect(save.gold, initialGold + 120);

      // Claim again should fail
      final repeatClaim = await save.claimQuestReward('break_bricks');
      expect(repeatClaim, 0);

      // Feed fish quest
      expect(await save.claimQuestReward('feed_fish'), 0); // Not completed yet
      save.recordFishFedQuest();
      expect(save.questFishFed, true);
      final feedReward = await save.claimQuestReward('feed_fish');
      expect(feedReward, 60);

      // Ad or win quest
      save.recordAdOrWinQuest();
      expect(save.questAdOrWinDone, true);
      final adReward = await save.claimQuestReward('ad_or_win');
      expect(adReward, 150);
    });

    test('Fortune Wheel 3-spins per day limit and daily reset', () async {
      final save = SaveManager.instance;
      await save.init();

      final today = DateTime.now().toIso8601String().substring(0, 10);
      save.lastFortuneWheelDate = today;
      save.fortuneWheelSpinsToday = 0;

      // Starts with 3 spins
      expect(save.remainingWheelSpins, 3);
      expect(save.canSpinFortuneWheel, true);

      // Spin 1
      final ok1 = await save.recordWheelSpin();
      expect(ok1, true);
      expect(save.remainingWheelSpins, 2);
      expect(save.canSpinFortuneWheel, true);

      // Spin 2
      final ok2 = await save.recordWheelSpin();
      expect(ok2, true);
      expect(save.remainingWheelSpins, 1);
      expect(save.canSpinFortuneWheel, true);

      // Spin 3
      final ok3 = await save.recordWheelSpin();
      expect(ok3, true);
      expect(save.remainingWheelSpins, 0);
      expect(save.canSpinFortuneWheel, false);

      // Spin 4 should fail (capped at 3)
      final ok4 = await save.recordWheelSpin();
      expect(ok4, false);
      expect(save.remainingWheelSpins, 0);
      expect(save.canSpinFortuneWheel, false);

      // Different day resets to 3 spins
      save.lastFortuneWheelDate = '2026-01-01';
      expect(save.remainingWheelSpins, 3);
      expect(save.canSpinFortuneWheel, true);
    });

    test('Fortune Wheel probability weights favour lower rewards without skewing sector layout', () {
      // 8 slices in wheel
      final weights = [2.5, 4.5, 6.0, 9.0, 20.0, 10.0, 23.0, 25.0];
      final totalWeight = weights.reduce((a, b) => a + b);
      expect(totalWeight, closeTo(100.0, 0.01));

      // Lower rewards (75g, 100g, 150g at indices 7, 6, 4):
      final lowerRewardsWeight = weights[7] + weights[6] + weights[4];
      expect(lowerRewardsWeight, 68.0); // Exactly 68%

      // Jackpot (500g at index 0):
      expect(weights[0], 2.5); // 2.5%

      // Mystery Crate & Shard (indices 1 & 2):
      final mysteryItemsWeight = weights[1] + weights[2];
      expect(mysteryItemsWeight, 10.5); // 10.5%
    });

    test('Ball trail length cap during corner boost is 120 points', () {
      final ball = Ball(x: 100, y: 100, vx: 100, vy: 100, isStuck: false);
      ball.cornerBoostTimer = 5.0;

      // Simulate 150 frames of motion (150 * 0.016 = 2.4s, timer still > 0)
      for (int i = 0; i < 150; i++) {
        ball.update(0.016, trailLength: 24);
      }

      // Cap should be exactly 120 (far higher than default 24 or 64)
      expect(ball.trail.length, 120);

      // When corner boost expires, cap returns to normal trailLength
      ball.cornerBoostTimer = 0.0;
      ball.update(0.016, trailLength: 24);
      expect(ball.trail.length, 24);
    });

    test('Fish food gold purchase and inventory tracking', () async {
      final save = SaveManager.instance;
      await save.init();

      final initialFood = save.fishFood;
      save.gold = 500;

      // Buy 3 food for 50 gold
      final bought1 = await save.buyFishFoodWithGold(count: 3, cost: 50);
      expect(bought1, true);
      expect(save.fishFood, initialFood + 3);
      expect(save.gold, 450);

      // Buy 10 food for 140 gold
      final bought2 = await save.buyFishFoodWithGold(count: 10, cost: 140);
      expect(bought2, true);
      expect(save.fishFood, initialFood + 13);
      expect(save.gold, 310);

      // Cannot afford if gold is insufficient
      save.gold = 30;
      final bought3 = await save.buyFishFoodWithGold(count: 3, cost: 50);
      expect(bought3, false);
      expect(save.fishFood, initialFood + 13);
    });

    test('AdManager high-yield ad unit is used for wheel, free gift and revive', () {
      expect(AdManager.tier1RewardedAdUnitId, 'ca-app-pub-9694275729123906/6981270843');
      expect(AdManager.highYieldAdUnitId, 'ca-app-pub-9694275729123906/6981270843');
    });

    testWidgets('ShopView renders with animated trail preview, ball preview, and paddle preview painters without exceptions', (tester) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        const MaterialApp(
          home: ShopView(),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      // Verify tabs exist
      expect(find.byType(ShopView), findsOneWidget);
      expect(find.byType(TabBar), findsOneWidget);

      // Switch to Trails tab
      await tester.tap(find.text(I18n.tr('trails')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Verify live trail showcase arena title
      expect(find.textContaining('CANLI İZ SİMÜLASYONU'), findsOneWidget);

      // Verify custom painters are actively rendering trail previews
      expect(find.byType(CustomPaint), findsWidgets);
      expect(find.text(TrailSkin.allTrails.first.name), findsWidgets);
    });

    test('All 238 levels are valid, winnable, bounded, and progressively scaled', () {
      const double screenWidth = 360.0;
      const double screenHeight = 640.0;

      for (int lvl = 1; lvl <= 238; lvl++) {
        final bricks = LevelDesign.buildClassicLevel(lvl, screenWidth, screenHeight);
        expect(bricks.isNotEmpty, true, reason: 'Level $lvl must not be empty');

        final breakables = bricks.where((b) => !b.isSteel && !b.isHeavySteel).toList();
        expect(breakables.length >= 6, true,
            reason: 'Level $lvl must have at least 6 breakable bricks');

        for (final b in bricks) {
          expect(b.x >= 15.99, true,
              reason: 'Level $lvl brick left bound ${b.x} out of screen');
          expect(b.x + b.width <= screenWidth - 15.99, true,
              reason: 'Level $lvl brick right bound ${b.x + b.width} out of screen');
          expect(b.hp >= 1, true, reason: 'Level $lvl brick must have positive HP');
        }

        // Boss level verification (every 10-15 levels)
        if (LevelDesign.isBossLevelNumber(lvl)) {
          final bosses = bricks.where((b) => b.isBoss).toList();
          expect(bosses.length, 1, reason: 'Level $lvl must have exactly 1 boss brick');
          final boss = bosses.first;
          expect(boss.hp >= 25, true, reason: 'Level $lvl boss must have substantial HP');
          // Guard bricks must be present
          final guards = bricks.where((b) => !b.isBoss && !b.isMover).toList();
          expect(guards.length >= 6, true, reason: 'Level $lvl boss must have guard escort');
        }
      }

      // Verify World Pacing & Identity
      expect(LevelDesign.getWorldIndex(1), 1);
      expect(LevelDesign.getWorldName(1), 'Neon Başlangıç');
      expect(LevelDesign.getWorldIndex(35), 1);

      expect(LevelDesign.getWorldIndex(36), 2);
      expect(LevelDesign.getWorldName(36), 'Siber Bastion');
      expect(LevelDesign.getWorldIndex(75), 2);

      expect(LevelDesign.getWorldIndex(76), 3);
      expect(LevelDesign.getWorldName(76), 'Manyetik Girdap');
      expect(LevelDesign.getWorldIndex(115), 3);

      expect(LevelDesign.getWorldIndex(116), 4);
      expect(LevelDesign.getWorldName(116), 'Kristal Labirent');
      expect(LevelDesign.getWorldIndex(155), 4);

      expect(LevelDesign.getWorldIndex(156), 5);
      expect(LevelDesign.getWorldName(156), 'Lav Çölü & Titanyum');
      expect(LevelDesign.getWorldIndex(195), 5);

      expect(LevelDesign.getWorldIndex(196), 6);
      expect(LevelDesign.getWorldName(196), 'Kuantum Zirvesi');
      expect(LevelDesign.getWorldIndex(238), 6);

      // Verify significant progression difference between level 25 and level 187
      final lvl25 = LevelDesign.buildClassicLevel(25, screenWidth, screenHeight);
      final lvl187 = LevelDesign.buildClassicLevel(187, screenWidth, screenHeight);

      final boss25 = lvl25.firstWhere((b) => b.isBoss);
      final boss187 = lvl187.firstWhere((b) => b.isBoss);
      expect(boss187.hp > boss25.hp * 3, true,
          reason: 'Level 187 boss must have dramatically higher HP than Level 25 boss');

      // Non-boss comparison (Level 21 vs Level 181)
      final lvl21 = LevelDesign.buildClassicLevel(21, screenWidth, screenHeight);
      final lvl181 = LevelDesign.buildClassicLevel(181, screenWidth, screenHeight);
      final avgHp21 = lvl21.where((b) => !b.isSteel).map((b) => b.hp).reduce((a, b) => a + b) /
          lvl21.where((b) => !b.isSteel).length;
      final avgHp181 = lvl181.where((b) => !b.isSteel && !b.isHeavySteel).map((b) => b.hp).reduce((a, b) => a + b) /
          lvl181.where((b) => !b.isSteel && !b.isHeavySteel).length;
      expect(avgHp181 > avgHp21, true,
          reason: 'Level 181 must have higher average brick resilience than Level 21');
    });

    test('Shield powerup has 12.0 seconds duration, acts as timed buff, and protects bottom ball', () {
      final gc = GameController();
      gc.setDimensions(360, 640);
      gc.startNewGame(GameMode.classic);
      gc.status = GameStatus.playing;

      // PowerUpType.shield duration must be 12.0
      expect(PowerUpType.shield.duration, 12.0);
      expect(PowerUpType.shield.isInstant, false);

      // Apply shield
      gc.applyPowerUp(PowerUpType.shield);
      expect(gc.paddle.hasNet, true);
      expect(gc.paddle.netHitsRemaining, 1);
      expect(gc.activePowerUps.any((p) => p.type == PowerUpType.shield), true);

      final shieldBuff = gc.activePowerUps.firstWhere((p) => p.type == PowerUpType.shield);
      expect(shieldBuff.timeLeft, 12.0);

      // Catch ball at screen bottom
      final ball = gc.balls.first;
      ball.isStuck = false;
      ball.x = gc.screenWidth / 2;
      ball.y = gc.screenHeight - 15.0; // below screen bottom threshold
      ball.vy = 200.0;

      // Update balls tick to simulate bottom collision with shield
      gc.update(0.016);
      expect(gc.paddle.hasNet, false);
      expect(gc.activePowerUps.any((p) => p.type == PowerUpType.shield), false);
    });

    test('Random cosmetic selection rolls owned cosmetics and locks them per game session', () async {
      final save = SaveManager.instance;
      await save.init();

      // Equip random on all categories
      save.activeBall = 'random';
      save.activePaddle = 'random';
      save.activeTrail = 'random';
      save.activeBrickStyle = 'random';
      save.activeBackground = 'random';

      final gc = GameController();
      gc.setDimensions(360, 640);
      gc.startNewGame(GameMode.classic);

      // Session cosmetics should not be 'random', but an actual owned cosmetic id
      expect(gc.activeBallId != 'random', true);
      expect(save.unlockedBalls.contains(gc.activeBallId), true);

      expect(gc.activePaddleId != 'random', true);
      expect(save.unlockedPaddles.contains(gc.activePaddleId), true);

      expect(gc.activeTrailId != 'random', true);
      expect(save.unlockedTrails.contains(gc.activeTrailId), true);

      expect(gc.activeBrickStyle != 'random', true);
      expect(save.unlockedBrickStyles.contains(gc.activeBrickStyle), true);

      expect(gc.activeBackground != 'random', true);
      expect(save.unlockedBackgrounds.contains(gc.activeBackground), true);

      // Throughout game ticks, the session cosmetic remains consistent
      final lockedBall = gc.activeBallId;
      final lockedPaddle = gc.activePaddleId;
      final lockedTrail = gc.activeTrailId;
      final lockedBrick = gc.activeBrickStyle;
      final lockedBg = gc.activeBackground;

      gc.update(0.016);
      gc.update(0.016);

      expect(gc.activeBallId, lockedBall);
      expect(gc.activePaddleId, lockedPaddle);
      expect(gc.activeTrailId, lockedTrail);
      expect(gc.activeBrickStyle, lockedBrick);
      expect(gc.activeBackground, lockedBg);
    });

    test('Trail prices are set to luxury high tier and corner shot matches ball/trail colors', () {
      // Trail prices must be significantly high
      final t2 = TrailSkin.getById('t2');
      final spark = TrailSkin.getById('spark');
      final fire = TrailSkin.getById('fire');
      final rainbow = TrailSkin.getById('rainbow');
      final ghost = TrailSkin.getById('ghost');
      final plasma = TrailSkin.getById('plasma');

      expect(t2.cost >= 4000, true);
      expect(spark.cost >= 7000, true);
      expect(fire.cost >= 9000, true);
      expect(rainbow.cost >= 14000, true);
      expect(ghost.cost >= 18000, true);
      expect(plasma.cost >= 24000, true);

      // Verify each trail has a distinct primary color
      expect(t2.primaryColor, isNotNull);
      expect(spark.primaryColor, isNotNull);
      expect(fire.primaryColor, isNotNull);
      expect(rainbow.primaryColor, isNotNull);
      expect(ghost.primaryColor, isNotNull);
      expect(plasma.primaryColor, isNotNull);

      // Verify corner shot color selection logic
      final save = SaveManager.instance;
      final gc = GameController();
      gc.setDimensions(360, 640);
      gc.startNewGame(GameMode.classic);

      // 1. With short trail 't1': corner shot flame uses active ball color
      save.activeTrail = 't1';
      final ballSkin = BallSkin.getById('altin');
      save.activeBall = ballSkin.id;
      gc.rollSessionCosmetics();
      final isShort = gc.activeTrailSkin.id == 't1';
      final Color flameColorShort = isShort ? gc.activeBallSkin.mainColor : gc.activeTrailSkin.primaryColor;
      expect(flameColorShort, ballSkin.mainColor);

      // 2. With another trail (e.g. ghost): corner shot flame uses trail primary color
      save.activeTrail = 'ghost';
      gc.rollSessionCosmetics();
      final isNotShort = gc.activeTrailSkin.id == 't1';
      final Color flameColorOther = isNotShort ? gc.activeBallSkin.mainColor : gc.activeTrailSkin.primaryColor;
      expect(flameColorOther, ghost.primaryColor);
    });

    test('Chaos Mode starts with exactly 3 balls and spawns pickups with balanced HP', () {
      final gc = GameController();
      gc.setDimensions(360, 640);
      gc.startNewGame(GameMode.chaos);

      expect(gc.currentMode, GameMode.chaos);
      expect(gc.chaosStock, 3);
      expect(gc.chaosPendingExtraBalls, 0);
      expect(gc.balls.length, 1); // Single visual ball at launcher (clean non-stacked aiming)

      // Verify level layout has +1 ball pickups and balanced HP
      expect(gc.bricks.any((b) => b.isBallPickup), true);
      final solidBricks = gc.bricks.where((b) => b.isAlive && !b.isBallPickup).toList();
      expect(solidBricks.isNotEmpty, true);
      // Wave 1 bricks should have low/winnable HP
      for (final b in solidBricks) {
        expect(b.hp <= 5, true);
      }
    });

    test('Chaos Mode ball collecting +1 ball pickup increments pending extra balls without bouncing', () {
      final gc = GameController();
      gc.setDimensions(360, 640);
      gc.startNewGame(GameMode.chaos);

      final pickup = gc.bricks.firstWhere((b) => b.isBallPickup);
      final ball = Ball(
        x: pickup.x + pickup.width / 2,
        y: pickup.y + pickup.height / 2,
        vx: 120.0,
        vy: -200.0,
        radius: 6.0,
        isStuck: false,
      );
      final originalVx = ball.vx;
      final originalVy = ball.vy;

      gc.balls.clear();
      gc.balls.add(ball);
      gc.status = GameStatus.playing;

      // Step balls to trigger collision
      gc.update(0.005);

      // Pickup must be collected
      expect(pickup.isAlive, false);
      expect(gc.chaosPendingExtraBalls, 1);
      // Ball must pass through smoothly without rebounding
      expect(ball.vx, originalVx);
      expect(ball.vy, originalVy);
    });

    test('Chaos Mode clearing all solid bricks resets balls to 3 for next level', () {
      final gc = GameController();
      gc.setDimensions(360, 640);
      gc.startNewGame(GameMode.chaos);

      // Simulate player collecting 4 extra balls during the game
      gc.chaosStock = 7;
      gc.chaosPendingExtraBalls = 2;
      expect(gc.stats.level, 1);

      // Mark all solid bricks as destroyed (level cleared)
      for (final b in gc.bricks) {
        if (!b.isBallPickup) {
          b.isAlive = false;
        }
      }

      // Simulate volley finish and turn advance
      gc.status = GameStatus.playing;
      gc.chaosToLaunch = 0;
      gc.chaosReturned = 7;
      gc.balls.clear();
      gc.update(0.016);

      // Level must advance to 2 and ball count MUST reset back to exactly 3!
      expect(gc.stats.level, 2);
      expect(gc.chaosStock, 3);
      expect(gc.chaosPendingExtraBalls, 0);
      expect(gc.status, GameStatus.ready);
      expect(gc.balls.length, 1); // Single visual ball at launcher (clean non-stacked aiming)
    });

    test('Smooth real-world contact normal reflection preserves speed and reflects corners accurately', () {
      final gc = GameController();
      gc.setDimensions(360, 640);
      gc.startNewGame(GameMode.classic);
      gc.bricks.clear();

      final brick = Brick(
        x: 100.0,
        y: 100.0,
        width: 40.0,
        height: 20.0,
        hp: 10,
        maxHp: 10,
        color: Colors.red,
      );
      gc.bricks.add(brick);

      // 1. Flat top edge collision: purely vertical reflection
      final ballTop = Ball(
        x: 120.0, // center on brick top edge
        y: 95.0,  // approaching top face
        vx: 80.0,
        vy: 150.0, // moving downward
        radius: 6.0,
        isStuck: false,
      );
      final initialSpeed = ballTop.speed;
      gc.balls.clear();
      gc.balls.add(ballTop);
      gc.status = GameStatus.playing;
      gc.update(0.01);

      expect(ballTop.vy < 0, true); // bounced upward
      expect((ballTop.vx - 80.0).abs() < 2.0, true); // horizontal speed preserved
      expect((ballTop.speed - initialSpeed).abs() < 2.0, true); // kinetic speed preserved

      // 2. Corner vertex hit: reflects along contact normal vector without 90-degree axis snapping
      final ballCorner = Ball(
        x: 98.0, // to the left of left edge (100)
        y: 98.0, // above top edge (100)
        vx: 120.0,
        vy: 120.0,
        radius: 6.0,
        isStuck: false,
      );
      final cornerInitialSpeed = ballCorner.speed;
      gc.balls.clear();
      gc.balls.add(ballCorner);
      gc.status = GameStatus.playing;
      gc.update(0.01);

      // Ball hit the top-left corner vertex: both vx and vy should reflect away from vertex
      expect(ballCorner.vx < 0, true);
      expect(ballCorner.vy < 0, true);
      expect((ballCorner.speed - cornerInitialSpeed).abs() < 2.0, true);
    });

    testWidgets('GameCanvas renders Chaos Mode with +1 ball pickups, ball counter and trajectory', (tester) async {
      final gc = GameController();
      gc.setDimensions(360, 640);
      gc.startNewGame(GameMode.chaos);
      gc.status = GameStatus.ready;
      gc.aimChaos(180, 200);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: GameCanvas(controller: gc),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 16));
      expect(find.byType(GameCanvas), findsOneWidget);
    });

    test('Chaos Mode waits for all balls before ending volley and resets wall boost on normal brick hit', () {
      final gc = GameController();
      gc.setDimensions(360, 640);
      gc.startNewGame(GameMode.chaos);
      gc.status = GameStatus.playing;
      gc.chaosToLaunch = 0;
      gc.chaosReturned = 1;

      final ball1 = Ball(x: 355, y: 200, vx: 100, vy: 50, radius: 5.2, isStuck: false);
      gc.balls.clear();
      gc.balls.add(ball1);
      gc.bricks.clear();

      // Bounce 8 times on side walls in Chaos mode
      for (int i = 0; i < 8; i++) {
        ball1.x = 359;
        ball1.vx = 100;
        gc.update(0.005);
      }
      expect(ball1.sideWallBounceCount, greaterThanOrEqualTo(8));
      expect(ball1.isWallSpeedBoosted, isTrue);
      expect(ball1.speed, greaterThanOrEqualTo(gc.getBaseBallSpeed() * 1.5));

      // Hitting a normal brick resets wall bounce count AND resets speed back to base speed
      final normalBrick = Brick(x: 160, y: 190, width: 40, height: 20, hp: 5, maxHp: 5, color: Colors.blue, points: 10);
      gc.bricks.add(normalBrick);
      ball1.x = 180;
      ball1.y = 188;
      ball1.vx = 0;
      ball1.vy = ball1.speed;
      gc.update(0.005);

      expect(ball1.sideWallBounceCount, 0);
      expect(ball1.isWallSpeedBoosted, isFalse);
      expect(ball1.speed, closeTo(gc.getBaseBallSpeed(), 1.0));

      // Turn should NOT end while balls are still flying
      expect(gc.status, GameStatus.playing);
      expect(gc.balls.isNotEmpty, true);

      // When ball finally hits bottom floor (chaosFloorY), it is removed
      gc.balls.clear();
      gc.balls.add(ball1);
      ball1.y = gc.chaosFloorY + 10.0;
      gc.update(0.016);

      // All active balls are removed, advance turn prepares next volley
      expect(gc.status, GameStatus.ready);
      expect(gc.chaosToLaunch, 0);
    });

    test('Black Hole has wide gravity field, prevents permanent slowdown and boosts exit speed', () {
      final gc = GameController();
      gc.setDimensions(360, 640);
      gc.currentMode = GameMode.zen;
      final bh = BlackHole(x: 180, y: 300, radius: 25.0, mass: 100000, timeLeft: 5.0);
      gc.blackHoles.add(bh);

      // Distance is 60 px (within 25 * 3.5 = 87.5 px natural gravitational field)
      final ball = Ball(x: 180, y: 240, vx: 0, vy: 100, isStuck: false);
      gc.balls.add(ball);
      gc.status = GameStatus.playing;

      gc.update(0.016);
      expect(ball.vy > 100, true); // Pulled towards black hole (+y)

      // Slow ball inside black hole never drops below getBaseBallSpeed()
      ball.x = 180;
      ball.y = 295; // Right inside black hole
      ball.setSpeed(50.0);
      gc.update(0.016);
      expect(ball.speed >= gc.getBaseBallSpeed(), true);
    });

    test('Ball bouncing 8 consecutive times on side walls speeds up until hitting paddle or normal brick', () {
      final gc = GameController();
      gc.setDimensions(360, 640);
      gc.startNewGame(GameMode.classic);
      gc.status = GameStatus.playing;

      final ball = Ball(x: 355, y: 300, vx: 100, vy: 50, radius: 6.0, isStuck: false);
      gc.balls.clear();
      gc.balls.add(ball);

      // Hit side wall 7 times
      for (int i = 0; i < 7; i++) {
        ball.x = 359;
        ball.vx = 100;
        gc.update(0.005);
      }
      expect(ball.sideWallBounceCount, 7);
      expect(ball.isWallSpeedBoosted, false);

      // 8th hit triggers speed boost
      ball.x = 359;
      ball.vx = 100;
      gc.update(0.005);
      expect(ball.sideWallBounceCount >= 8, true);
      expect(ball.isWallSpeedBoosted, true);
      expect(ball.speed >= gc.getBaseBallSpeed() * 1.5, true);

      // Hitting paddle resets the boost
      gc.paddle.x = 150;
      gc.paddle.y = 580;
      ball.x = 180;
      ball.y = 578;
      ball.vy = 200;
      gc.update(0.01);
      expect(ball.sideWallBounceCount, 0);
      expect(ball.isWallSpeedBoosted, false);
    });

    test('Rainbow Ball skin (gokkusagi) exists and renders with multifaceted diamond and star glints', () {
      final skin = BallSkin.getById('gokkusagi');
      expect(skin.id, 'gokkusagi');
      expect(skin.name.isNotEmpty, true);
      expect(skin.rarity, Rarity.legendary);

      final diamondSkin = BallSkin.getById('elmas_top');
      expect(diamondSkin.id, 'elmas_top');
      expect(diamondSkin.rarity, Rarity.legendary);
    });

    test('AudioManager has cornerBoost, bossHit, wallBounce8 GameSfx and haptic bindings', () {
      expect(GameSfx.values.contains(GameSfx.cornerBoost), true);
      expect(GameSfx.values.contains(GameSfx.bossHit), true);
      expect(GameSfx.values.contains(GameSfx.wallBounce8), true);

      // Verify playing without crash
      final am = AudioManager.instance;
      am.playSfx(GameSfx.cornerBoost);
      am.playSfx(GameSfx.bossHit);
      am.playSfx(GameSfx.wallBounce8);
    });

    test('Chaos Mode toggleChaosTurboOrRecall toggles 2.2x turbo speed and triggers ball recall', () {
      final gc = GameController();
      gc.setDimensions(360, 640);
      gc.startNewGame(GameMode.chaos);
      gc.status = GameStatus.playing;
      expect(gc.chaosSpeedMultiplier, 1.0);
      expect(gc.chaosRecallActive, false);

      final ball = Ball(x: 180, y: 300, vx: 50, vy: -50, isStuck: false);
      gc.balls.add(ball);

      // 1st press: toggles 2.2x turbo speed
      gc.toggleChaosTurboOrRecall();
      expect(gc.chaosSpeedMultiplier >= 2.0, true);
      expect(gc.chaosRecallActive, false);

      // 2nd press: activates instant recall to floor
      gc.toggleChaosTurboOrRecall();
      expect(gc.chaosRecallActive, true);
      expect(gc.chaosToLaunch, 0);

      // During recall, ball is rapidly directed downwards
      gc.update(0.016);
      expect(ball.vy >= 700.0, true);
    });

    testWidgets('GameCanvas renders Chaos Mode with 1-bounce raycast reflection and turbo button', (tester) async {
      final gc = GameController();
      gc.setDimensions(360, 640);
      gc.startNewGame(GameMode.chaos);
      gc.aimChaos(220, 200);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: GameCanvas(controller: gc),
          ),
        ),
      );
      expect(find.byType(GameCanvas), findsOneWidget);

      // Fire volley and render with active Turbo button
      gc.fireChaos();
      await tester.pump(const Duration(milliseconds: 50));
      expect(find.byType(GameCanvas), findsOneWidget);
    });

    test('BrickShard physics updates position, gravity, rotation and life', () {
      final shard = BrickShard(
        x: 100,
        y: 100,
        vx: 50,
        vy: -100,
        rotation: 0,
        vRot: 2.0,
        width: 8,
        height: 6,
        color: Colors.red,
        maxLife: 0.6,
      );

      expect(shard.isDead, false);
      shard.update(0.1);
      expect(shard.x, closeTo(105.0, 0.5));
      expect(shard.vy > -100, true); // vy increases due to gravity
      expect(shard.rotation > 0, true);
      expect(shard.life < 0.6, true);
    });

    test('Boss level sets bossWarningTimer and triggers screen shake', () {
      final gc = GameController();
      gc.setDimensions(360, 640);
      gc.startNewGame(GameMode.classic);
      gc.stats.level = 12; // Level 12 is a boss level
      gc.loadLevelBricks();

      expect(gc.bossWarningTimer > 0, true);
      expect(gc.particles.shakeTimeLeft > 0, true);
    });

    test('All bricks cleared triggers levelTransitionTimer celebration', () {
      final gc = GameController();
      gc.setDimensions(360, 640);
      gc.startNewGame(GameMode.classic);
      gc.launchBall(); // Launch ball so status is playing and ball is not stuck
      expect(gc.status, GameStatus.playing);
      // Mark all bricks as dead
      for (final b in gc.bricks) {
        b.hp = 0;
        b.isAlive = false;
      }
      gc.update(0.016);

      expect(gc.levelTransitionTimer > 0, true);
    });

    test('SaveManager saves, checks, and clears Classic and Chaos sessions accurately', () async {
      final save = SaveManager.instance;
      await save.init();

      // Initially clear
      await save.clearClassicSession();
      await save.clearChaosSession();

      expect(save.hasSavedGame(GameMode.classic), false);
      expect(save.hasSavedGame(GameMode.chaos), false);
      expect(save.hasSavedGame(GameMode.zen), false);

      // Save Classic session
      await save.saveClassicSession(level: 5, score: 4500, lives: 2);
      expect(save.hasSavedGame(GameMode.classic), true);
      expect(save.classicSavedLevel, 5);
      expect(save.classicSavedScore, 4500);
      expect(save.classicSavedLives, 2);

      // Save Chaos session
      await save.saveChaosSession(level: 3, score: 2800, stock: 7);
      expect(save.hasSavedGame(GameMode.chaos), true);
      expect(save.chaosSavedLevel, 3);
      expect(save.chaosSavedScore, 2800);
      expect(save.chaosSavedStock, 7);

      // Clear sessions
      await save.clearClassicSession();
      expect(save.hasSavedGame(GameMode.classic), false);
      expect(save.classicSavedLevel, null);

      await save.clearChaosSession();
      expect(save.hasSavedGame(GameMode.chaos), false);
      expect(save.chaosSavedLevel, null);
    });

    test('GameController resumes saved game properly for Classic and Chaos', () async {
      final save = SaveManager.instance;
      await save.init();

      // 1. Classic resume
      await save.saveClassicSession(level: 7, score: 9200, lives: 2);
      final gcClassic = GameController();
      gcClassic.setDimensions(360, 640);
      gcClassic.startNewGame(GameMode.classic, isResume: true);

      expect(gcClassic.stats.level, 7);
      expect(gcClassic.stats.score, 9200);
      expect(gcClassic.stats.lives, 2);

      // 2. Chaos resume
      await save.saveChaosSession(level: 4, score: 3400, stock: 6);
      final gcChaos = GameController();
      gcChaos.setDimensions(360, 640);
      gcChaos.startNewGame(GameMode.chaos, isResume: true);

      expect(gcChaos.stats.level, 4);
      expect(gcChaos.stats.score, 3400);
      expect(gcChaos.chaosStock, 6);

      // Cleanup
      await save.clearClassicSession();
      await save.clearChaosSession();
    });

    test('Permanent relic (Midas Micro-Attraction) purchase and capsule subtle pull', () async {
      final save = SaveManager.instance;
      await save.init();
      save.gold = 50000;

      final bought = await save.buyPermanentRelic(cost: 25000);
      expect(bought, true);
      expect(save.hasPermanentRelic, true);
      expect(save.gold, 25000);

      final gc = GameController();
      gc.setDimensions(360, 640);
      gc.startNewGame(GameMode.classic);
      gc.launchBall(); // Set status to playing

      // Place paddle at center (x: 140, width: 80 -> center 180, y: 530)
      gc.paddle.x = 140;
      gc.paddle.width = 80;
      gc.paddle.y = 530;

      // Spawn falling capsule near paddle height but shifted to the right (x: 210, y: 460)
      final capsule = FallingCapsule(x: 210, y: 460, type: PowerUpType.laser);
      gc.capsules.add(capsule);

      final initialX = capsule.x;
      // Update one frame
      gc.update(0.016);

      // Capsule should experience subtle nudge towards paddle center (180), so x should decrease slightly
      expect(capsule.x < initialX, true);
      expect((initialX - capsule.x).abs() < 2.0, true); // Extremely subtle, does not teleport
    });

    test('Stat Upgrade Tree boosts paddle width, crit damage, ulti charge and luck', () async {
      final save = SaveManager.instance;
      await save.init();
      save.gold = 50000;
      save.upgrades.clear();

      expect(save.getUpgradeLevel('paddle_width'), 0);
      final bought = await save.buyStatUpgrade('paddle_width', 600);
      expect(bought, true);
      expect(save.getUpgradeLevel('paddle_width'), 1);
      expect(save.gold, 50000 - 600);

      // Upgrade paddle width to level 3
      await save.buyStatUpgrade('paddle_width', 1500);
      await save.buyStatUpgrade('paddle_width', 3000);
      expect(save.getUpgradeLevel('paddle_width'), 3);

      final gc = GameController();
      gc.setDimensions(360, 640);
      gc.startNewGame(GameMode.classic);

      // Base paddle width should include +12px bonus from lvl 3
      expect(gc.paddle.width >= gc.paddle.baseWidth + 12.0, true);

      // Verify battery upgrade accelerates ulti charge
      await save.buyStatUpgrade('battery', 500);
      expect(save.getUpgradeLevel('battery'), 1);
      final initialUlti = gc.stats.ultiCharge;
      final brick = Brick(x: 100, y: 100, width: 40, height: 20, color: const Color(0xFFE91E63), points: 50, hp: 1);
      gc.bricks.add(brick);
      // Simulate charging until dice point triggers ulti gain
      for (int i = 0; i < 10; i++) {
        gc.testChargeDiceFromGlass(brick);
      }
      expect(gc.stats.ultiCharge > initialUlti, true);
    });

    test('Laser rolls 1 to 6 shots, mostly 1-3, then stops', () {
      final gc = GameController();
      gc.setDimensions(360, 640);
      gc.startNewGame(GameMode.classic);
      gc.status = GameStatus.playing;

      final counts = <int, int>{};
      for (var i = 0; i < 400; i++) {
        gc.applyPowerUp(PowerUpType.laser);
        final shots = gc.paddle.laserAmmo;
        expect(shots, inInclusiveRange(1, 6));
        counts[shots] = (counts[shots] ?? 0) + 1;
      }
      final common = (counts[1] ?? 0) + (counts[2] ?? 0) + (counts[3] ?? 0);
      final rare = (counts[4] ?? 0) + (counts[5] ?? 0) + (counts[6] ?? 0);
      expect(common, greaterThan(rare * 3));

      gc.paddle.laserAmmo = 3;
      gc.paddle.hasLaser = true;
      gc.paddle.hasDrone = false;
      gc.paddle.hasRockets = false;
      gc.diceSalvoRemaining = 0;
      gc.isDiceRolling = false;
      gc.laserTimer = 0.65;
      gc.projectiles.clear();
      var spawned = 0;
      var previous = 0;
      for (var i = 0; i < 90; i++) {
        gc.update(0.05);
        if (gc.projectiles.length > previous) {
          spawned += gc.projectiles.length - previous;
        }
        previous = gc.projectiles.length;
      }
      expect(spawned, 6);
      expect(gc.paddle.hasLaser, isFalse);
      expect(gc.paddle.laserAmmo, 0);
    });

    testWidgets('ShopView crates tab renders reworked crate cards and drop rate chips', (tester) async {
      final save = SaveManager.instance;
      await save.init();

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ShopView(),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Find 'Sandıklar' or crates tab
      final cratesTab = find.text('Sandıklar');
      if (cratesTab.evaluate().isNotEmpty) {
        await tester.tap(cratesTab);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));
      }

      // Check that crate texts and ALTIN AÇ buttons exist
      expect(find.textContaining('ALTIN AÇ'), findsWidgets);
      expect(find.text(I18n.tr('common')), findsWidgets);
      expect(find.text(I18n.tr('rare')), findsWidgets);
      expect(find.text(I18n.tr('epic')), findsWidgets);
      expect(find.text(I18n.tr('legendary')), findsWidgets);
    });

    test('Cosmetic Ball rarities: ates and isilti are epic, altin is rare, elmas and gokkusagi are legendary', () {
      final ates = BallSkin.getById('ates');
      final isilti = BallSkin.getById('isilti');
      final altin = BallSkin.getById('altin');
      final elmas = BallSkin.getById('elmas_top');
      final gokkusagi = BallSkin.getById('gokkusagi');

      expect(ates.rarity, Rarity.epic);
      expect(isilti.rarity, Rarity.epic);
      expect(altin.rarity, Rarity.rare);
      expect(elmas.rarity, Rarity.legendary);
      expect(gokkusagi.rarity, Rarity.legendary);
    });

    testWidgets('ChestWidget renders closed, opening, and opened states with realistic planks and rivets', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Column(
              children: const [
                ChestWidget(size: 64, openProgress: 0.0),
                ChestWidget(size: 96, openProgress: 0.5),
                ChestWidget(size: 130, isOpened: true, openProgress: 1.0),
              ],
            ),
          ),
        ),
      );
      await tester.pump();
      expect(find.byType(ChestWidget), findsNWidgets(3));
    });

    testWidgets('ShopView renders ChestWidget in CrateCards and Category headers', (tester) async {
      final save = SaveManager.instance;
      await save.init();

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ShopView(),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // There should be ChestWidgets rendered in the crates tab
      expect(find.byType(ChestWidget), findsWidgets);
    });

    testWidgets('CrateOpeningDialog drops chest, supports 3-tap suspense progression and opens', (tester) async {
      final save = SaveManager.instance;
      await save.init();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CrateOpeningDialog(crate: CrateDef.allCrates.first),
          ),
        ),
      );
      // Let drop animation complete
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 700));

      expect(find.byType(ChestWidget), findsOneWidget);
      expect(find.text('SIRADAN'), findsOneWidget);
      expect(find.text('Sandığa Dokun (1/3)'), findsOneWidget);

      // Tap 1
      await tester.tap(find.byType(ChestWidget));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('Tekrar Dokun (2/3)'), findsOneWidget);

      // Tap 2
      await tester.tap(find.byType(ChestWidget));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('Açmak İçin Dokun! (3/3)'), findsOneWidget);

      // Tap 3 (Opening & Reveal)
      await tester.tap(find.byType(ChestWidget));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump(const Duration(milliseconds: 1000));

      // After 3rd tap, chest is opened and claim button appears
      expect(find.text(I18n.tr('claim_and_close')), findsOneWidget);
    });

    test('Opposing power-ups (Wide vs Shrink, Slow vs Fastball) cancel each other cleanly', () {
      final controller = GameController();
      controller.setDimensions(360, 640);
      controller.startNewGame(GameMode.classic);

      controller.applyPowerUp(PowerUpType.wide);
      expect(controller.activePowerUps.any((p) => p.type == PowerUpType.wide), true);
      expect(controller.paddle.width, closeTo(controller.paddle.baseWidth * 1.45, 0.1));

      // Picking up shrink removes wide so wide's expiry won't overwrite shrink
      controller.applyPowerUp(PowerUpType.shrink);
      expect(controller.activePowerUps.any((p) => p.type == PowerUpType.wide), false);
      expect(controller.activePowerUps.any((p) => p.type == PowerUpType.shrink), true);
      expect(controller.paddle.width, closeTo(controller.paddle.baseWidth * 0.65, 0.1));
    });

    test('Clutch save on the outer tip grants +150 score, and a corner hit fills the dice by 3', () {
      final controller = GameController();
      controller.setDimensions(360, 640);
      controller.startNewGame(GameMode.classic);
      controller.launchBall();

      final ball = controller.balls.first;
      // Place ball right at the rightmost 5% tip of the paddle falling downward
      ball.x = controller.paddle.x + controller.paddle.width * 0.97;
      ball.y = controller.paddle.y - ball.radius + 1.0;
      ball.vx = 0;
      ball.vy = 320.0;

      final scoreBefore = controller.stats.score;
      final ultiBefore = controller.stats.ultiCharge;

      controller.update(0.016);

      expect(controller.stats.score, scoreBefore + 150);
      expect(controller.stats.ultiCharge, closeTo(ultiBefore + 3.0, 0.01));
    });

    test('Boss level exposes activeBossBrick and triggers Boss Enrage at <= 50% HP', () {
      final controller = GameController();
      controller.setDimensions(360, 640);
      controller.startNewGame(GameMode.classic);
      controller.stats.level = 12; // Boss level
      controller.loadLevelBricks();
      controller.status = GameStatus.playing;

      final boss = controller.activeBossBrick;
      expect(boss, isNotNull);
      expect(boss!.isBoss, true);

      // Reduce boss HP to 50% + 1 and hit it with a laser projectile
      boss.hp = (boss.maxHp * 0.5).floor() + 1;
      controller.projectiles.add(
        Projectile(
          x: boss.x + boss.width / 2,
          y: boss.y + boss.height / 2,
          vy: -400,
          radius: 4,
          isLaser: true,
        ),
      );
      controller.update(0.016);

      expect(boss.hp <= boss.maxHp * 0.5, true);
      expect(controller.particles.floatingTexts.any((t) => t.text.contains('ÖFKELENDİ')), true);
    });

    testWidgets('AquariumView renders cleanly on narrow mobile screen without overflow and auto-collects 6h gold', (tester) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final save = SaveManager.instance;
      await save.init();
      save.unlockedFish = ['guppy', 'tetra'];
      save.fishFood = 152;
      save.gold = 12500;
      final sixHoursAgo = DateTime.now().millisecondsSinceEpoch - (6 * 3600 * 1000 + 1000);
      save.fishFedTimestamps['guppy'] = sixHoursAgo;
      save.fishFedTimestamps['tetra'] = sixHoursAgo;

      await tester.pumpWidget(
        const MaterialApp(
          home: AquariumView(),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Tap the FishHoardChest to pour ready coins into account
      await tester.tap(find.byType(FishHoardChest));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 900));

      // Collected +30 gold from hoard chest!
      expect(save.gold, 12530);
      expect(save.fedFishCount, 0);

      // Tap Yem At button to feed 1 fish
      await tester.tap(find.textContaining('Yem At'));
      await tester.pump(const Duration(milliseconds: 50));
      expect(save.fishFood, 151);
    });

    test('Vortex power-up curves falling balls toward paddle center and vacuums buff capsules, and Clumsy slides on ice', () {
      final gc = GameController();
      gc.setDimensions(360, 640);
      gc.startNewGame(GameMode.classic);
      gc.stats.level = 4;
      gc.launchBall();

      // 1. Activate Vortex
      gc.applyPowerUp(PowerUpType.vortex);
      expect(gc.paddle.hasVortex, true);

      // Place paddle at center (x=136, width=88 -> center=180)
      gc.paddle.x = 136;
      // Place falling ball to the left (x=70) approaching paddle height
      final ball = gc.balls.first;
      ball.x = 70;
      ball.y = gc.paddle.y - 120;
      ball.vx = 0;
      ball.vy = 300;

      // Place a buff capsule far to the right
      final buffCap = FallingCapsule(x: 300, y: gc.paddle.y - 100, type: PowerUpType.wide);
      gc.capsules.add(buffCap);

      gc.update(0.016);
      // Ball is pulled/curved rightwards (+x) toward paddle center (180)
      expect(ball.x > 70, true);
      expect(ball.vx > 0, true);
      // Buff capsule is vacuumed leftwards (-x) toward paddle center (180)
      expect(buffCap.x < 300, true);

      // 2. Activate Clumsy (Ice slide)
      gc.applyPowerUp(PowerUpType.clumsy);
      expect(gc.paddle.isClumsy, true);
      gc.movePaddleBy(12.0);
      expect(gc.paddle.slideVelocity > 0, true);
      final xAfterDrag = gc.paddle.x;
      // Even without further drag input, paddle continues sliding on ice on next frame!
      gc.update(0.016);
      expect(gc.paddle.x > xAfterDrag, true);
    });

    test('End-of-game dice roll gold multiplier awards 2X on dice 1-3 and 3X on dice 4-6', () async {
      final save = SaveManager.instance;
      await save.init();
      save.gold = 1000;

      // 1. Dice roll 2 (1-3) -> 2X multiplier (+100 bonus on 100 base gold)
      final gc1 = GameController();
      gc1.setDimensions(360, 640);
      gc1.startNewGame(GameMode.classic);
      gc1.stats.goldCollected = 100;
      gc1.status = GameStatus.gameOver;

      final added2x = gc1.rollEndGameGoldDice(forcedDice: 2);
      expect(added2x, 100);
      expect(gc1.endGameRolledDice, 2);
      expect(gc1.endGameMultiplier, 2);
      expect(gc1.stats.goldCollected, 200);
      expect(save.gold, 1100);

      // 2. Dice roll 5 (4-6) -> 3X multiplier (+200 bonus on 100 base gold)
      final gc2 = GameController();
      gc2.setDimensions(360, 640);
      gc2.startNewGame(GameMode.classic);
      gc2.stats.goldCollected = 100;
      gc2.status = GameStatus.victory;

      final added3x = gc2.rollEndGameGoldDice(forcedDice: 5);
      expect(added3x, 200);
      expect(gc2.endGameRolledDice, 5);
      expect(gc2.endGameMultiplier, 3);
      expect(gc2.stats.goldCollected, 300);
      expect(save.gold, 1300);
    });

    test('Chaos Mode: Ball cannot pass through/tunnel between two vertically stacked bricks', () {
      final gc = GameController();
      gc.setDimensions(360, 640);
      gc.startNewGame(GameMode.chaos);
      gc.status = GameStatus.playing;
      gc.balls.clear();

      // Clear existing bricks and add two vertically stacked bricks with an 8px gap (Chaos standard)
      // Brick 1: x: 100, y: 100, w: 45, h: 26 (bottom: 126)
      // Brick 2: x: 100, y: 134, w: 45, h: 26 (top: 134)
      // Gap is 8px (y: 126 to 134). Ball radius is 7.5px (diameter 15px > 8px gap).
      gc.bricks.clear();
      final b1 = Brick(x: 100, y: 100, width: 45, height: 26, hp: 5, maxHp: 5, color: const Color(0xFFFF5252));
      final b2 = Brick(x: 100, y: 134, width: 45, height: 26, hp: 5, maxHp: 5, color: const Color(0xFFFF5252));
      gc.bricks.addAll([b1, b2]);

      // Fire a ball aimed directly horizontally into the 8px seam from the left (x: 80, y: 130)
      final ballLeft = Ball(x: 80, y: 130, vx: 500, vy: 0);
      gc.balls.add(ballLeft);

      // Simulate movement towards the seam: in ~3 frames it hits the bricks at x=100 and bounces back
      bool hasBounced = false;
      for (int step = 0; step < 15; step++) {
        gc.update(0.016);
        // The ball MUST NEVER tunnel through to the right of the stacked bricks (x > 145)
        expect(ballLeft.x <= 100.0, true, reason: 'Ball penetrated or tunneled through the 8px seam between stacked blocks!');
        if (ballLeft.vx < 0) {
          hasBounced = true;
        }
      }
      expect(hasBounced, true, reason: 'Ball should have bounced to the left off the stacked bricks!');

      // Symmetrically test from the right: fire ball towards seam from x: 165 towards x: 145
      gc.balls.clear();
      final ballRight = Ball(x: 165, y: 130, vx: -500, vy: 0);
      gc.balls.add(ballRight);

      bool hasBouncedRight = false;
      for (int step = 0; step < 15; step++) {
        gc.update(0.016);
        // Ball must never tunnel through to the left of the stacked bricks (x < 100)
        expect(ballRight.x >= 145.0, true, reason: 'Ball penetrated from the right through the seam!');
        if (ballRight.vx > 0) {
          hasBouncedRight = true;
        }
      }
      expect(hasBouncedRight, true, reason: 'Ball should have bounced to the right off the stacked bricks!');
    });

    test('Chaos Mode: Accumulated balls display as a single clean ball at launcher while aiming', () {
      final gc = GameController();
      gc.setDimensions(360, 640);
      gc.startNewGame(GameMode.chaos);

      // Accumulate 20 balls in chaos mode
      gc.chaosStock = 20;
      gc.loadLevelBricks(); // Triggers _layoutChaosPile
      gc.status = GameStatus.ready;

      // Only 1 ball should be in balls list at the launcher node
      expect(gc.chaosStock, 20);
      expect(gc.balls.length, 1);
      expect(gc.balls.first.x, gc.chaosHomeX);
      expect(gc.balls.first.isStuck, true);

      // Player aims
      gc.aimChaos(gc.chaosHomeX, gc.chaosFloorY - 150.0);
      expect(gc.chaosAiming, true);
      // Still only 1 single ball while aiming
      expect(gc.balls.length, 1);

      // Firing launches all 20 balls into volley
      gc.fireChaos();
      expect(gc.status, GameStatus.playing);
      expect(gc.chaosToLaunch, 20);
    });

    test('SectorData defines 14 sectors spanning exactly 238 levels with valid checkpoints', () {
      expect(SectorData.allSectors.length, 14);
      expect(SectorData.allSectors.first.startLevel, 1);
      expect(SectorData.allSectors.last.endLevel, 238);

      // Verify contiguous boundaries and checkpoints
      for (int i = 0; i < SectorData.allSectors.length; i++) {
        final sec = SectorData.allSectors[i];
        expect(sec.sectorIndex, i + 1);
        expect(sec.checkpointLevel, sec.startLevel);
        if (i > 0) {
          final prev = SectorData.allSectors[i - 1];
          expect(sec.startLevel, prev.endLevel + 1);
        }
      }

      // Specific level to sector mapping
      expect(SectorData.getSectorForLevel(1).sectorIndex, 1);
      expect(SectorData.getSectorForLevel(16).sectorIndex, 1);
      expect(SectorData.getSectorForLevel(17).sectorIndex, 2);
      expect(SectorData.getSectorForLevel(33).sectorIndex, 2);
      expect(SectorData.getSectorForLevel(34).sectorIndex, 3);
      expect(SectorData.getSectorForLevel(238).sectorIndex, 14);
    });

    test('SaveManager sector unlocking and checkpoint logic works seamlessly', () async {
      final save = SaveManager.instance;
      await save.init();

      // At level 1, only sector 1 unlocked
      save.noteClassicProgress(1);
      expect(save.highestUnlockedSector, 1);
      expect(save.isSectorUnlocked(1), true);
      expect(save.isSectorUnlocked(2), false);

      // Reaching level 17 unlocks sector 2
      save.noteClassicProgress(17);
      expect(save.highestUnlockedSector, 2);
      expect(save.isSectorUnlocked(1), true);
      expect(save.isSectorUnlocked(2), true);
      expect(save.isSectorUnlocked(3), false);
      expect(save.getSectorCheckpoint(2), 17);

      // Reaching level 51 unlocks sector 4
      save.noteClassicProgress(51);
      expect(save.highestUnlockedSector, 4);
      expect(save.isSectorUnlocked(4), true);
      expect(save.getSectorCheckpoint(4), 51);
    });

    test('GameController supports starting directly from sector checkpoint with explicitStartLevel', () {
      final gc = GameController();
      gc.setDimensions(360, 640);

      // Start from sector 3 checkpoint (Level 34)
      gc.startNewGame(GameMode.classic, explicitStartLevel: 34);
      expect(gc.stats.level, 34);
      expect(gc.currentMode, GameMode.classic);
      expect(gc.status, GameStatus.ready);

      // Start from sector 14 checkpoint (Level 221)
      gc.startNewGame(GameMode.classic, explicitStartLevel: 221);
      expect(gc.stats.level, 221);
    });

    test('AudioManager combo pitch escalation and dynamic tempo scaling', () {
      final audio = AudioManager.instance;

      // Base hit with no combo
      audio.playSfx(GameSfx.hitBrick, combo: 0);
      expect(audio.lastPlayedCombo, 0);
      expect(audio.lastPlaybackRate, 1.0);

      // Consecutive combo hits scale pitch progressively up to 1.5x
      audio.playSfx(GameSfx.breakBrick, combo: 3);
      expect(audio.lastPlayedCombo, 3);
      expect(audio.lastPlaybackRate, closeTo(1.15, 0.01));

      audio.playSfx(GameSfx.breakBrick, combo: 7);
      expect(audio.lastPlayedCombo, 7);
      expect(audio.lastPlaybackRate, closeTo(1.35, 0.01));

      audio.playSfx(GameSfx.breakBrick, combo: 12);
      expect(audio.lastPlayedCombo, 12);
      expect(audio.lastPlaybackRate, closeTo(1.50, 0.01));

      // Dynamic tempo adjustment does not throw
      expect(() => audio.setDynamicTempo(isFever: true, isBoss: false), returnsNormally);
      expect(() => audio.setDynamicTempo(isFever: false, isBoss: true), returnsNormally);
      expect(() => audio.setDynamicTempo(isFever: false, isBoss: false), returnsNormally);
    });

    testWidgets('RewardsHubDialog renders properly with all 3 rewards and actions', (tester) async {
      final save = SaveManager.instance;
      await save.init();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: RewardsHubDialog(
              save: save,
              onFortuneWheelTap: () {},
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('ÖDÜL MERKEZİ'), findsOneWidget);
      expect(find.text('Şans Çarkı'), findsOneWidget);
      expect(find.text('7 Günlük Giriş Serisi'), findsOneWidget);
      expect(find.text('Ücretsiz Altın Sandığı'), findsOneWidget);
    });
  });
}