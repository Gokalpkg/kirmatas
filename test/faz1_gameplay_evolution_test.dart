import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kirmatas/engine/audio_manager.dart';
import 'package:kirmatas/engine/game_controller.dart';
import 'package:kirmatas/models/ball.dart';
import 'package:kirmatas/models/brick.dart';
import 'package:kirmatas/models/game_state.dart';
import 'package:kirmatas/models/paddle.dart';
import 'package:kirmatas/storage/save_manager.dart';
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

  group('Faz 1 - Mekanik 1: Manyetik Darbe (Gravity Pulse) & Açı Bükme', () {
    test('PulseWave expands and expires when radius exceeds maxRadius', () {
      final wave = PulseWave(x: 200, y: 500, radius: 10, maxRadius: 300, speed: 1000);
      expect(wave.isAlive, isTrue);
      expect(wave.progress, closeTo(10 / 300, 0.01));

      wave.update(0.15); // +150px => 160px
      expect(wave.radius, closeTo(160, 1.0));
      expect(wave.progress, closeTo(160 / 300, 0.01));
      expect(wave.isAlive, isTrue);

      wave.update(0.20); // +200px => 360px >= 300
      expect(wave.isAlive, isFalse);
    });

    test('PulseWave conical intersection detects balls inside cone and rejects balls outside', () {
      final wave = PulseWave(
        x: 200,
        y: 600,
        radius: 200,
        aimAngle: -math.pi / 2,
        spreadAngle: 1.15,
      );

      // Ball right above the paddle at (200, 420): distance is 180, inside [radius - 55, radius + 20]
      expect(wave.intersectsBall(200, 420, 8.0), isTrue);

      // Ball behind the paddle (below it at 200, 700)
      expect(wave.intersectsBall(200, 700, 8.0), isFalse);

      // Ball far to the side outside conical angle
      expect(wave.intersectsBall(400, 600, 8.0), isFalse);

      // Ball too far from wavefront radius (e.g. y = 100, dist = 500)
      expect(wave.intersectsBall(200, 100, 8.0), isFalse);
    });

    test('triggerGravityPulse adds a pulse wave and bends ball velocity vector by 25% towards target', () {
      final ctrl = GameController();
      ctrl.setDimensions(400, 800);
      ctrl.startNewGame(GameMode.classic, explicitStartLevel: 1);
      ctrl.launchBall();

      expect(ctrl.status, GameStatus.playing);
      expect(ctrl.pulseWaves.isEmpty, isTrue);

      // Place a ball above the paddle moving purely rightward (vx = 200, vy = 0)
      ctrl.balls.clear();
      final ball = Ball(x: ctrl.paddle.centerX, y: ctrl.paddle.y - 80, isStuck: false);
      ball.vx = 200.0;
      ball.vy = 0.0;
      final originalSpeed = ball.speed;
      ctrl.balls.add(ball);

      // Trigger pulse pointing straight up (-pi / 2)
      ctrl.triggerGravityPulse(aimAngle: -math.pi / 2);
      expect(ctrl.pulseWaves.length, 1);
      final wave = ctrl.pulseWaves.first;
      expect(wave.aimAngle, -math.pi / 2);

      // Update controller so wave expands and hits the ball
      ctrl.update(0.09);

      // Ball should have been affected
      expect(wave.affectedBallIds.contains(ball.hashCode), isTrue);

      // Target direction was straight up: (0, -1)
      // Original direction was right: (1, 0)
      // 25% blend: 0.75 * (1, 0) + 0.25 * (0, -1) = (0.75, -0.25)
      // vy must now be significantly negative (bent upward)!
      expect(ball.vy, lessThan(-10.0));
      expect(ball.vx, greaterThan(10.0));
      expect(ball.speed, closeTo(originalSpeed, 1.0)); // Speed preserved!
    });

    test('Manyetik Darbe prioritizes alive Boss brick when bending ball velocity', () {
      final ctrl = GameController();
      ctrl.setDimensions(400, 800);
      ctrl.startNewGame(GameMode.classic, explicitStartLevel: 1);
      ctrl.launchBall();

      // Add a boss brick at the top-left (50, 100)
      final bossBrick = Brick(
        x: 50,
        y: 100,
        width: 60,
        height: 30,
        hp: 10,
        maxHp: 10,
        color: Colors.red,
        isBoss: true,
      );
      ctrl.bricks = [bossBrick];

      // Ball at center moving downwards (vx = 0, vy = 250)
      ctrl.balls.clear();
      final ball = Ball(x: 200, y: 500, isStuck: false);
      ball.vx = 0.0;
      ball.vy = 250.0;
      ctrl.balls.add(ball);

      ctrl.triggerGravityPulse();
      expect(ctrl.pulseWaves.isNotEmpty, isTrue);

      // Advance time frame-by-frame so wave naturally intersects ball
      for (int i = 0; i < 25; i++) {
        ctrl.update(0.016);
        if (ball.vx < -10.0) break;
      }

      // Ball should be bent towards the top-left (vx < 0)
      expect(ball.vx, lessThan(-10.0), reason: 'Ball should be bent towards top-left boss');
    });

    test('3-Stage Overdrive: Edge hit increases streak and Stage 3 fires piercing laser', () {
      final ctrl = GameController();
      ctrl.setDimensions(400, 800);
      ctrl.startNewGame(GameMode.classic, explicitStartLevel: 1);
      ctrl.launchBall();

      ctrl.balls.clear();
      final ball = Ball(x: ctrl.paddle.x + ctrl.paddle.width * 0.96, y: ctrl.paddle.y - 4, isStuck: false);
      ball.vx = 0;
      ball.vy = 200.0;
      ctrl.balls.add(ball);

      // Stage 1 edge hit
      ctrl.update(0.016);
      expect(ball.overdriveStreak, 1);

      // Reset position for second edge hit
      ball.x = ctrl.paddle.x + ctrl.paddle.width * 0.96;
      ball.y = ctrl.paddle.y - 4;
      ball.vx = 0;
      ball.vy = 200.0;
      ctrl.update(0.016);
      expect(ball.overdriveStreak, 2);

      // Reset position for third edge hit (Stage 3!)
      ball.x = ctrl.paddle.x + ctrl.paddle.width * 0.96;
      ball.y = ctrl.paddle.y - 4;
      ball.vx = 0;
      ball.vy = 200.0;
      ctrl.update(0.016);
      expect(ball.overdriveStreak, 3);
      expect(ball.isPierce, isTrue);

      // A straight piercing golden laser must be fired!
      expect(ctrl.projectiles.any((p) => p.isPiercingLaser), isTrue);
      final piercingLaser = ctrl.projectiles.firstWhere((p) => p.isPiercingLaser);
      expect(piercingLaser.vx, 0.0);
      expect(piercingLaser.vy, lessThan(-400.0));
    });

    test('Piercing laser pierces through multiple bricks without being removed on first hit', () {
      final ctrl = GameController();
      ctrl.setDimensions(400, 800);
      ctrl.startNewGame(GameMode.classic, explicitStartLevel: 1);
      ctrl.launchBall();

      // Stack two 1-HP bricks vertically in laser line, plus an extra 10-HP brick so level doesn't end
      final b1 = Brick(x: 180, y: 300, width: 40, height: 20, hp: 1, maxHp: 1, color: Colors.blue);
      final b2 = Brick(x: 180, y: 250, width: 40, height: 20, hp: 1, maxHp: 1, color: Colors.blue);
      final b3 = Brick(x: 180, y: 100, width: 40, height: 20, hp: 10, maxHp: 10, color: Colors.blue);
      ctrl.bricks = [b1, b2, b3];

      // Add a piercing laser right below b1 heading straight up
      final laser = Projectile(x: 200, y: 320, vx: 0, vy: -500, radius: 5, isLaser: true, isPiercingLaser: true);
      ctrl.projectiles.clear();
      ctrl.projectiles.add(laser);

      // Step laser through b1
      ctrl.update(0.02);
      expect(b1.hp, lessThanOrEqualTo(0));
      expect(ctrl.projectiles.contains(laser), isTrue, reason: 'Piercing laser must not be destroyed on first brick');

      // Step laser through b2
      ctrl.update(0.10);
      expect(b2.hp, lessThanOrEqualTo(0));
      expect(ctrl.projectiles.contains(laser), isTrue, reason: 'Piercing laser continues upward');
    });
  });

  group('Faz 1 - Adrenalin 8: Zero-Lag Clutch Kurtarışı', () {
    test('Zero-Lag: Clutch save never triggers slow-motion (_nearMissSlowLeft remains 0.0)', () {
      final ctrl = GameController();
      ctrl.setDimensions(400, 800);
      ctrl.startNewGame(GameMode.classic, explicitStartLevel: 1);
      ctrl.launchBall();

      ctrl.balls.clear();
      final ball = Ball(
        x: ctrl.paddle.x + ctrl.paddle.width * 0.95,
        y: ctrl.paddle.y - 3.0,
        isStuck: false,
      );
      ball.vx = 0;
      ball.vy = 260.0;
      ctrl.balls.add(ball);

      ctrl.update(0.016);

      // Verify zero-lag: NO slow motion!
      expect(ctrl.stats.bulletTimeLeft, 0.0);
      // Floating text "CLUTCH SAVE!" was spawned
      expect(ctrl.particles.floatingTexts.any((ft) => ft.text == 'CLUTCH SAVE!'), isTrue);
    });

    test('Clutch save spawns upward golden lightning sparks across screen', () {
      final ctrl = GameController();
      ctrl.setDimensions(400, 800);
      ctrl.startNewGame(GameMode.classic, explicitStartLevel: 1);
      ctrl.launchBall();

      ctrl.balls.clear();
      final ball = Ball(
        x: ctrl.paddle.x + ctrl.paddle.width * 0.92,
        y: ctrl.paddle.y - 3.0,
        isStuck: false,
      );
      ball.vx = 0;
      ball.vy = 200.0;
      ctrl.balls.add(ball);

      ctrl.update(0.016);

      // Check for upward blazing lightning particles (vy < -400)
      final upwardSparks = ctrl.particles.particles.where((p) => p.vy < -400.0);
      expect(upwardSparks.isNotEmpty, isTrue, reason: 'Golden lightning sparks must shoot upward across screen');
    });

    test('Clutch save turns ball into Aşırı Yüklü Altın Gülle (4s timer, 3-brick instabreak, x2 gold)', () {
      final ctrl = GameController();
      ctrl.setDimensions(400, 800);
      ctrl.startNewGame(GameMode.classic, explicitStartLevel: 1);
      ctrl.launchBall();

      ctrl.balls.clear();
      final ball = Ball(
        x: ctrl.paddle.x + ctrl.paddle.width * 0.94,
        y: ctrl.paddle.y - 3.0,
        isStuck: false,
      );
      ball.vx = 0;
      ball.vy = 220.0;
      ctrl.balls.add(ball);

      ctrl.update(0.016);

      expect(ball.isClutchOvercharged, isTrue);
      expect(ball.clutchOverchargeTimer, closeTo(4.0, 0.05));
      expect(ball.clutchPierceRemaining, 3);

      // Test instabreak on high-HP brick:
      final heavyBrick = Brick(
        x: 150,
        y: 200,
        width: 40,
        height: 20,
        hp: 15, // 15 HP!
        maxHp: 15,
        color: Colors.purple,
      );
      ctrl.bricks = [heavyBrick];

      final preGold = SaveManager.instance.gold;
      // Position ball right at brick to test instabreak
      ball.x = heavyBrick.rect.center.dx;
      ball.y = heavyBrick.rect.top - 2.0;
      ball.vx = 0;
      ball.vy = 200.0;
      ctrl.update(0.016);

      // Brick with 15 HP should be instantly broken (hp <= 0)
      expect(heavyBrick.hp, lessThanOrEqualTo(0), reason: 'Aşırı Yüklü Altın Gülle must instabreak first 3 bricks regardless of HP');
      expect(ball.clutchPierceRemaining, 2);
      expect(SaveManager.instance.gold, greaterThan(preGold), reason: 'Clutch save grants x2 gold reward');
    });
  });

  group('Faz 1 - Audio 11: Pentatonik Kombo Merdiveni', () {
    test('majorPentatonicScale contains exact C Major Pentatonic ratios', () {
      expect(AudioManager.majorPentatonicScale, [
        1.000, // C
        1.125, // D
        1.250, // E
        1.500, // G
        1.667, // A
        2.000, // Upper C
        2.250, // Upper D
        2.500, // Upper E
      ]);
    });

    test('getPentatonicPitch climbs through pentatonic ladder as combo increases', () {
      expect(AudioManager.getPentatonicPitch(1), 1.000); // Do
      expect(AudioManager.getPentatonicPitch(2), 1.125); // Re
      expect(AudioManager.getPentatonicPitch(3), 1.250); // Mi
      expect(AudioManager.getPentatonicPitch(4), 1.500); // Sol
      expect(AudioManager.getPentatonicPitch(5), 1.667); // La
      expect(AudioManager.getPentatonicPitch(6), 2.000); // Upper Do
      expect(AudioManager.getPentatonicPitch(7), 2.250); // Upper Re
      expect(AudioManager.getPentatonicPitch(8), 2.500); // Upper Mi
    });

    test('AudioManager playSfx uses pentatonic pitch for brick hits by default', () {
      expect(AudioManager.usePentatonicScale, isTrue);
      final audio = AudioManager.instance;
      audio.playSfx(GameSfx.hitBrick, combo: 4);
      expect(audio.lastPlaybackRate, AudioManager.getPentatonicPitch(4));
    });
  });
}
