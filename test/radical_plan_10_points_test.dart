import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kirmatas/engine/audio_manager.dart';
import 'package:kirmatas/engine/game_controller.dart';
import 'package:kirmatas/models/brick.dart';
import 'package:kirmatas/models/game_state.dart';
import 'package:kirmatas/models/level_design.dart';
import 'package:kirmatas/models/paddle.dart';
import 'package:kirmatas/models/powerup.dart';
import 'package:kirmatas/storage/save_manager.dart';
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
    GameController.enableHitStopInTests = true;
  });

  tearDown(() {
    GameController.enableHitStopInTests = false;
  });

  group('Radical Plan Item 1: Squash & Stretch and Graduated Hit-Stop', () {
    test('Graduated hit-stop durations are configured properly', () {
      final ctrl = GameController();
      ctrl.setDimensions(360, 640);
      ctrl.startNewGame(GameMode.classic, explicitStartLevel: 1);
      ctrl.bricks.clear();

      // Normal brick hit-stop: 15ms
      final normalBrick = Brick(x: 50, y: 100, width: 40, height: 20, hp: 1, maxHp: 1, color: Colors.blue);
      ctrl.destroyBrickForTest(normalBrick);
      expect(ctrl.hitStopTimer, closeTo(0.015, 0.001));

      // Combo x5+ hit-stop: 25ms
      ctrl.stats.combo = 5;
      final combo5Brick = Brick(x: 100, y: 100, width: 40, height: 20, hp: 1, maxHp: 1, color: Colors.blue);
      ctrl.destroyBrickForTest(combo5Brick);
      expect(ctrl.hitStopTimer, closeTo(0.025, 0.001));

      // Combo x10+ hit-stop: 40ms
      ctrl.stats.combo = 10;
      final combo10Brick = Brick(x: 150, y: 100, width: 40, height: 20, hp: 1, maxHp: 1, color: Colors.blue);
      ctrl.destroyBrickForTest(combo10Brick);
      expect(ctrl.hitStopTimer, closeTo(0.040, 0.001));

      // Dynamite brick hit-stop: 45ms
      ctrl.stats.combo = 0;
      final dynamiteBrick = Brick(x: 200, y: 100, width: 40, height: 20, hp: 1, maxHp: 1, color: Colors.red, isDynamite: true);
      ctrl.destroyBrickForTest(dynamiteBrick);
      expect(ctrl.hitStopTimer, closeTo(0.045, 0.001));

      // Boss brick hit-stop: 60ms
      final bossBrick = Brick(x: 100, y: 150, width: 80, height: 40, hp: 1, maxHp: 1, color: Colors.purple, isBoss: true);
      ctrl.destroyBrickForTest(bossBrick);
      expect(ctrl.hitStopTimer, closeTo(0.060, 0.001));
    });

    test('Screen shake in ParticleSystem decays with time', () {
      final ctrl = GameController();
      ctrl.particles.triggerShake(10.0, 0.5);
      expect(ctrl.particles.shakeTimeLeft, 0.5);
      expect(ctrl.particles.shakeDuration, 0.5);

      ctrl.particles.update(0.25);
      expect(ctrl.particles.shakeTimeLeft, closeTo(0.25, 0.01));

      final offset = ctrl.particles.getShakeOffset();
      // Current magnitude decayed to half (5.0)
      expect(offset.dx.abs(), lessThanOrEqualTo(5.0));
      expect(offset.dy.abs(), lessThanOrEqualTo(5.0));
    });
  });

  group('Radical Plan Item 2: Last Brick Torture & Overdrive Homing Failsafe', () {
    test('Overdrive homing is disabled by default in normal gameplay', () {
      final ctrl = GameController();
      expect(ctrl.enableOverdriveHoming, isFalse);
    });

    test('Overdrive homing activates after 18s when enabled and exactly 1 breakable brick remains', () {
      final ctrl = GameController();
      ctrl.enableOverdriveHoming = true;
      ctrl.setDimensions(360, 640);
      ctrl.startNewGame(GameMode.classic, explicitStartLevel: 1);
      ctrl.enableOverdriveHoming = true;
      ctrl.launchBall();
      final ball = ctrl.balls.first;
      ball.x = 100;
      ball.y = 250;
      ball.vx = 80;
      ball.vy = 0;

      // Leave exactly 1 breakable brick
      ctrl.bricks.clear();
      final brick1 = Brick(x: 100, y: 100, width: 40, height: 20, hp: 1, maxHp: 1, color: Colors.cyan);
      ctrl.bricks.add(brick1);

      expect(ctrl.balls.first.isOverdriveHoming, isFalse);

      // Simulate 17.5 seconds: not yet homing
      for (int i = 0; i < 175; i++) {
        ctrl.update(0.1);
      }
      expect(ctrl.balls.first.isOverdriveHoming, isFalse);

      // Advance past 18.0 seconds: homing engages
      for (int i = 0; i < 10; i++) {
        ctrl.update(0.1);
      }
      expect(ctrl.balls.first.isOverdriveHoming, isTrue);
    });

    test('Paddle hit resets overdrive homing timer', () {
      final ctrl = GameController();
      ctrl.enableOverdriveHoming = true;
      ctrl.setDimensions(360, 640);
      ctrl.startNewGame(GameMode.classic, explicitStartLevel: 1);
      ctrl.enableOverdriveHoming = true;
      ctrl.launchBall();
      final ball = ctrl.balls.first;
      ball.x = 100;
      ball.y = 250;
      ball.vx = 80;
      ball.vy = 0;

      ctrl.bricks.clear();
      ctrl.bricks.add(Brick(x: 100, y: 100, width: 40, height: 20, hp: 1, maxHp: 1, color: Colors.cyan));

      // Advance 18.2 seconds: homing is active
      for (int i = 0; i < 182; i++) {
        ctrl.update(0.1);
      }
      expect(ctrl.balls.first.isOverdriveHoming, isTrue);

      // Simulate ball hitting paddle
      ball.x = ctrl.paddle.x + ctrl.paddle.width * 0.5;
      ball.y = ctrl.paddle.y - ball.radius + 1.0;
      ball.vx = 0;
      ball.vy = 250.0;
      ctrl.update(0.016);

      // Homing deactivated on paddle hit
      expect(ball.isOverdriveHoming, isFalse);
    });

    test('25.0s fail-safe destroys brick and spawns lightning strike text and effects', () {
      final ctrl = GameController();
      ctrl.enableOverdriveHoming = true;
      ctrl.setDimensions(360, 640);
      ctrl.startNewGame(GameMode.classic, explicitStartLevel: 1);
      ctrl.enableOverdriveHoming = true;
      ctrl.launchBall();
      final ball = ctrl.balls.first;
      ball.x = 100;
      ball.y = 250;
      ball.vx = 80;
      ball.vy = 0;

      ctrl.bricks.clear();
      final targetBrick = Brick(x: 100, y: 100, width: 40, height: 20, hp: 1, maxHp: 1, color: Colors.cyan);
      ctrl.bricks.add(targetBrick);

      // Simulate 25.5 seconds without paddle hit
      for (int i = 0; i < 255; i++) {
        ctrl.update(0.1);
      }

      // Brick destroyed by lightning strike
      expect(targetBrick.isAlive, isFalse);
      expect(ctrl.particles.floatingTexts.any((t) => t.text.contains('YILDIRIM VURUŞU')), isTrue);
    });
  });

  group('Radical Plan Item 3: Major Pentatonic Musical Scale', () {
    test('Major pentatonic scale frequency table values', () {
      expect(AudioManager.majorPentatonicScale, [1.000, 1.125, 1.250, 1.500, 1.667, 2.000, 2.250, 2.500]);
    });

    test('getPentatonicPitch maps combo index cyclically to major pentatonic scale', () {
      expect(AudioManager.getPentatonicPitch(0), 1.000);
      expect(AudioManager.getPentatonicPitch(1), 1.000);
      expect(AudioManager.getPentatonicPitch(2), 1.125);
      expect(AudioManager.getPentatonicPitch(3), 1.250);
      expect(AudioManager.getPentatonicPitch(4), 1.500);
      expect(AudioManager.getPentatonicPitch(5), 1.667);
      expect(AudioManager.getPentatonicPitch(6), 2.000);
      expect(AudioManager.getPentatonicPitch(7), 2.250);
      expect(AudioManager.getPentatonicPitch(8), 2.500);
      // Wraps around on combo 9
      expect(AudioManager.getPentatonicPitch(9), 1.000);
      expect(AudioManager.getPentatonicPitch(10), 1.125);
    });
  });

  group('Radical Plan Item 5: 3-Phase Boss Mechanics', () {
    test('Boss enraged HP threshold is strictly 35%', () {
      final boss = Brick(x: 50, y: 50, width: 100, height: 40, hp: 100, maxHp: 100, color: Colors.red, isBoss: true);
      expect(boss.isEnraged, isFalse);

      boss.hp = 50; // 50% HP
      expect(boss.isEnraged, isFalse, reason: '50% HP must NOT be enraged');

      boss.hp = 36; // 36% HP
      expect(boss.isEnraged, isFalse, reason: '36% HP must NOT be enraged');

      boss.hp = 35; // 35% HP
      expect(boss.isEnraged, isTrue, reason: '35% HP must be enraged (Phase 3)');

      boss.hp = 20;
      expect(boss.isEnraged, isTrue);
    });

    test('Phase 2 boss shoots laser-targeted hazard projectile that shrinks paddle on contact', () {
      final ctrl = GameController();
      ctrl.setDimensions(360, 640);
      ctrl.startNewGame(GameMode.classic, explicitStartLevel: 10);
      ctrl.launchBall();

      ctrl.bricks.clear();
      // Boss at 60% HP (Phase 2)
      final boss = Brick(x: 140, y: 80, width: 80, height: 35, hp: 60, maxHp: 100, color: Colors.purple, isBoss: true);
      boss.shootTimer = 0.0;
      ctrl.bricks.add(boss);

      ctrl.update(0.016);

      // Verify targeted hazard projectile was spawned
      final hazardProj = ctrl.projectiles.where((p) => p.isBossBullet && p.isHazard).toList();
      expect(hazardProj.isNotEmpty, isTrue);

      // Position hazard projectile on paddle
      final proj = hazardProj.first;
      proj.x = ctrl.paddle.x + ctrl.paddle.width * 0.5;
      proj.y = ctrl.paddle.y + 2.0;

      final initialWidth = ctrl.paddle.width;
      ctrl.update(0.016);

      // Paddle shrunk by hazard projectile
      expect(ctrl.paddle.width, lessThan(initialWidth));
      expect(ctrl.particles.floatingTexts.any((t) => t.text.contains('RAKET KÜÇÜLDÜ') || t.text.contains('SHRUNK')), isTrue);
    });
  });

  group('Radical Plan Item 6: World Palettes Simplification', () {
    test('Every world palette consists of strictly 1 dark base + 3 accent tones', () {
      for (int world = 1; world <= 6; world++) {
        final colors = LevelDesign.getWorldPalette(world);
        expect(colors.length, 4, reason: 'World $world palette must have 4 colors (1 base + 3 accents)');
        // First color is dark base
        final base = colors.first;
        expect(base.computeLuminance(), lessThan(0.12), reason: 'First color in world $world must be dark base');
      }
    });
  });

  group('Radical Plan Item 7: Aquarium Dolphin Leap Bridge', () {
    test('Dolphin Leap saves lone falling ball once per run until restart if fish are unlocked', () {
      final save = SaveManager.instance;
      save.unlockedFish = ['guppy', 'tetra'];

      final ctrl = GameController();
      ctrl.setDimensions(360, 640);
      ctrl.startNewGame(GameMode.classic, explicitStartLevel: 1);
      ctrl.launchBall();

      final ball = ctrl.balls.first;
      expect(ctrl.fishSaveUsedThisRun, isFalse);

      // Move ball below screen bottom
      ball.y = ctrl.screenHeight + ball.radius + 2.0;
      ball.vy = 300.0;

      ctrl.update(0.016);

      // Ball rescued by Dolphin Leap
      expect(ctrl.fishSaveUsedThisRun, isTrue);
      expect(ctrl.stats.lives, 3, reason: 'Player must not lose a life on Dolphin Leap');
      expect(ball.vy, lessThan(0.0), reason: 'Ball should be bouncing upward');
      expect(ctrl.particles.floatingTexts.any((t) => t.text.contains('BALIK KURTARIŞI')), isTrue);

      // Second drop in the same level cannot be rescued by Dolphin Leap
      ball.y = ctrl.screenHeight + ball.radius + 2.0;
      ball.vy = 300.0;
      ctrl.update(0.016);
      expect(ctrl.stats.lives, 2);

      // Advancing level does NOT reset Dolphin Leap (it is once per entire game run)
      ctrl.loadLevelBricks();
      expect(ctrl.fishSaveUsedThisRun, isTrue);

      // Restarting new game resets Dolphin Leap
      ctrl.startNewGame(GameMode.classic, explicitStartLevel: 1);
      expect(ctrl.fishSaveUsedThisRun, isFalse);
    });

    test('Life powerup hard-caps at maxLivesCap (5) and converts extra hearts to gold', () {
      final ctrl = GameController();
      ctrl.setDimensions(360, 640);
      ctrl.startNewGame(GameMode.classic);
      ctrl.stats.lives = 4;

      ctrl.applyPowerUp(PowerUpType.life);
      expect(ctrl.stats.lives, 5);

      // Subsequent life powerup when already at 5 does not exceed 5
      final initialGold = ctrl.save.gold;
      ctrl.applyPowerUp(PowerUpType.life);
      expect(ctrl.stats.lives, 5);
      expect(ctrl.save.gold, initialGold + 50);
    });
  });

  group('Radical Plan Item 8: Paddle Lerp Inertia & Near-Miss Shockwave', () {
    test('Near-miss save triggers outward shockwave ring', () {
      final ctrl = GameController();
      ctrl.setDimensions(360, 640);
      ctrl.startNewGame(GameMode.classic, explicitStartLevel: 1);
      ctrl.launchBall();

      final ball = ctrl.balls.first;
      // Tip hit (hitOffset >= 0.90)
      ball.x = ctrl.paddle.x + ctrl.paddle.width * 0.97;
      ball.y = ctrl.paddle.y - ball.radius + 1.0;
      ball.vx = 0;
      ball.vy = 280.0;

      ctrl.update(0.016);

      expect(ctrl.nearMissFlashTimer > 0, isTrue);
      expect(ctrl.particles.shockwaves.any((s) => s.color == const Color(0xFF00E5FF)), isTrue);
    });

    test('Paddle remains rock-solid without wobbly tilt during rapid motion', () {
      final paddle = Paddle(x: 100, y: 550);
      paddle.prevX = 100;
      paddle.x = 180; // Rapid rightward motion
      paddle.update(0.016);

      // User requested rock-solid flat paddle without annoying wobbly tilt
      expect(paddle.tiltAngle, equals(0.0));

      paddle.prevX = 180;
      paddle.x = 20; // Rapid leftward motion
      paddle.update(0.016);

      expect(paddle.tiltAngle, equals(0.0));
    });
  });

  group('Radical Plan Item 9: Two-Currency Economy (Shard Conversion)', () {
    test('Initialization converts legacy shards to pearls at 2 shards = 1 pearl', () async {
      SharedPreferences.setMockInitialValues({
        'pearls': 5,
        'fishShards': 3,
        'categoryShards': '{"balls": 2, "paddles": 1}',
      });

      final save = SaveManager.instance;
      save.resetForTesting();
      await save.init();

      // Total shards: 3 + 2 + 1 = 6 shards -> 3 pearls
      // New pearls: 5 + 3 = 8
      expect(save.pearls, 8);
      expect(save.fishShards, 0);
      expect(save.categoryShards.values.every((v) => v == 0), isTrue);
    });
  });

  group('Radical Plan Item 10: Victory Ritual & Rolling Numbers', () {
    testWidgets('PauseGameOverOverlay renders victory stars and rolling numbers', (tester) async {
      final ctrl = GameController();
      ctrl.setDimensions(360, 640);
      ctrl.startNewGame(GameMode.classic, explicitStartLevel: 1);
      ctrl.status = GameStatus.victory;
      ctrl.stats.lives = 3;
      ctrl.stats.score = 2500;
      ctrl.stats.maxCombo = 12;
      ctrl.stats.bricksBroken = 45;
      ctrl.stats.goldCollected = 150;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PauseGameOverOverlay(
              controller: ctrl,
              onResume: () {},
              onRestart: () {},
              onMainMenu: () {},
            ),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 1300));

      // Stars present
      expect(find.byIcon(Icons.star_rounded), findsNWidgets(3));
      // Numbers rolling to final values
      expect(find.text('2500'), findsOneWidget);
      expect(find.text('x12'), findsOneWidget);
      expect(find.text('45'), findsOneWidget);
      expect(find.text('+150'), findsOneWidget);
    });
  });
}
