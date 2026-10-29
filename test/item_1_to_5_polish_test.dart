import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kirmatas/engine/audio_manager.dart';
import 'package:kirmatas/engine/game_controller.dart';
import 'package:kirmatas/models/game_state.dart';
import 'package:kirmatas/models/powerup.dart';
import 'package:kirmatas/storage/save_manager.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('xyz.luan/audioplayers'),
      (MethodCall methodCall) async => 1,
    );
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('xyz.luan/audioplayers.global'),
      (MethodCall methodCall) async => 1,
    );
  });

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await SaveManager.instance.init();
  });

  group('Item 1 & 2: Level Stars & Pre-Match Boosts', () {
    test('SaveManager persists and retrieves level stars correctly', () async {
      final save = SaveManager.instance;
      expect(save.getLevelStars(1), 0);
      await save.saveLevelStars(1, 3);
      expect(save.getLevelStars(1), 3);

      // Higher stars override, lower stars do not downgrade
      await save.saveLevelStars(1, 2);
      expect(save.getLevelStars(1), 3);

      await save.saveLevelStars(2, 2);
      expect(save.getLevelStars(2), 2);
    });

    test('GameController activates pre-match boosts properly', () async {
      final save = SaveManager.instance;
      final controller = GameController();
      controller.status = GameStatus.ready;

      // 1. Life boost
      save.boostStocks['life'] = 1;
      final initialLives = controller.stats.lives;
      controller.activatePreMatchBoost('life');
      expect(controller.stats.lives, initialLives + 1);
      expect(save.boostStocks['life'], 0);
      expect(controller.usedPreMatchBoosts.contains('life'), isTrue);

      // 2. Wide paddle boost
      save.boostStocks['wide'] = 1;
      controller.activatePreMatchBoost('wide');
      expect(controller.activePowerUps.any((p) => p.type == PowerUpType.wide), isTrue);
      expect(save.boostStocks['wide'], 0);
      expect(controller.usedPreMatchBoosts.contains('wide'), isTrue);

      // 3. Multi-ball boost
      save.boostStocks['multi'] = 1;
      controller.activatePreMatchBoost('multi');
      expect(controller.balls.length, greaterThan(1));
      expect(save.boostStocks['multi'], 0);
      expect(controller.usedPreMatchBoosts.contains('multi'), isTrue);
    });
  });

  group('Item 5: AudioManager active brick style dynamic loading', () {
    test('AudioManager resolves brick style key and switches cleanly', () async {
      final audio = AudioManager.instance;
      await audio.init();

      expect(audio.resolveSoundKey(GameSfx.breakBrick), startsWith('brick_'));
      expect(audio.resolveSoundKey(GameSfx.laser), 'laser');
      expect(audio.resolveSoundKey(GameSfx.bubble), 'bubble');
    });
  });
}
