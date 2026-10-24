import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:kirmatas/config/balance_config.dart';
import 'package:kirmatas/engine/audio_manager.dart';
import 'package:kirmatas/engine/game_controller.dart';
import 'package:kirmatas/models/brick.dart';
import 'package:kirmatas/models/game_state.dart';
import 'package:kirmatas/storage/save_manager.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(
      const MethodChannel('xyz.luan/audioplayers.global'),
      (MethodCall methodCall) async => 1,
    );
    messenger.setMockMethodCallHandler(
      const MethodChannel('xyz.luan/audioplayers'),
      (MethodCall methodCall) async => 1,
    );
  });

  group('Pixel Art Brick Destruction Choreography (5 Steps)', () {
    late GameController controller;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      final save = SaveManager.instance;
      await save.init();
      controller = GameController();
      controller.setDimensions(360, 640);
      controller.startNewGame(GameMode.classic);
    });

    test('Step 1: Hit-Stop & Pure White Flash on Destruction/Hit', () {
      final brick = Brick(
        x: 100,
        y: 100,
        width: 40,
        height: 20,
        hp: 1,
        color: const Color(0xFF00E5FF),
      );

      // Initially no flash
      expect(brick.flashTimer, 0.0);

      // Trigger hit flash
      brick.triggerWhiteFlash(0.035);
      expect(brick.flashTimer, closeTo(0.035, 0.001));

      // Updating counts down flash
      brick.update(0.02);
      expect(brick.flashTimer, closeTo(0.015, 0.001));
      brick.update(0.03);
      expect(brick.flashTimer, 0.0);

      // Hit-stop duration matches BalanceConfig
      expect(BalanceConfig.hitStopDurationSeconds, 0.035);
    });

    test('Step 2: Left-to-Right Pixel Shockwave Wave Spawns & Progresses', () {
      final particles = controller.particles;
      particles.clear();
      expect(particles.pixelShockwaves.isEmpty, isTrue);

      // Spawn pixel wave
      particles.spawnPixelWave(100, 100, 60, 24, const Color(0xFF00E5FF));
      expect(particles.pixelShockwaves.length, 1);

      final wave = particles.pixelShockwaves.first;
      expect(wave.progress, 0.0);
      expect(wave.isDead, isFalse);

      // Progress advances with time
      particles.update(0.14);
      expect(wave.progress, closeTo(0.5, 0.05));
      expect(wave.isDead, isFalse);

      // Once finished, removed cleanly
      particles.update(0.20);
      expect(particles.pixelShockwaves.isEmpty, isTrue);
    });

    test('Step 3: Crisp Square Pixel Chunks Spawn and Bounce', () {
      final particles = controller.particles;
      particles.clear();
      expect(particles.shards.isEmpty, isTrue);

      particles.spawnBrickShards(100, 100, 50, 20, const Color(0xFFFFB800), count: 6);
      expect(particles.shards.length, 6);

      final shard = particles.shards.first;
      // Dimensions are square/rectangular pixel chunks
      expect(shard.width, greaterThan(3.0));
      expect(shard.height, greaterThan(3.0));
      expect(shard.floorY, greaterThan(shard.y));
      expect(shard.bounceCount, 0);

      // Simulate physics until shard hits floor and bounces
      shard.vy = 80.0;
      shard.y = shard.floorY - 0.5;
      shard.update(0.02);
      expect(shard.bounceCount, 1);
      expect(shard.vy, lessThan(0.0)); // Inverted upwards bounce velocity
    });

    test('Step 4: Chiptune Ascending Pitch Arpeggio & Haptic Scaling', () {
      final audio = AudioManager.instance;

      // Base hit with no combo
      audio.playSfx(GameSfx.hitBrick, combo: 0);
      expect(audio.lastPlayedCombo, 0);
      expect(audio.lastPlaybackRate, 1.0);

      // Ascending combo hits progressively raise pitch
      audio.playSfx(GameSfx.breakBrick, combo: 1);
      expect(audio.lastPlaybackRate, closeTo(1.05, 0.01));

      audio.playSfx(GameSfx.breakBrick, combo: 3);
      expect(audio.lastPlaybackRate, closeTo(1.15, 0.01));

      audio.playSfx(GameSfx.breakBrick, combo: 6);
      expect(audio.lastPlaybackRate, closeTo(1.30, 0.01));

      audio.playSfx(GameSfx.breakBrick, combo: 10);
      expect(audio.lastPlaybackRate, closeTo(1.50, 0.01));
    });

    test('Step 5: Remaining Bricks Settle with Elastic Overshoot', () {
      final brickA = Brick(
        x: 50,
        y: 100,
        width: 40,
        height: 20,
        color: const Color(0xFF00E5FF),
      );
      final brickB = Brick(
        x: 95, // Neighbor in same row
        y: 100,
        width: 40,
        height: 20,
        color: const Color(0xFFFFB800),
      );

      controller.bricks.clear();
      controller.bricks.addAll([brickA, brickB]);

      // Brick B is destroyed
      brickB.hp = 0;
      controller.destroyBrickForTest(brickB);

      // Brick A must have received elastic settle impulse
      expect(brickA.bounceVy, greaterThan(0.0));
      expect(brickA.jelly, greaterThan(0.0));

      // Over consecutive updates, brick A oscillates and settles back to 0 displacement
      for (int i = 0; i < 40; i++) {
        brickA.update(0.016);
      }
      expect(brickA.bounceOffsetY, closeTo(0.0, 0.05));
      expect(brickA.bounceVy, closeTo(0.0, 0.5));
    });
  });
}
