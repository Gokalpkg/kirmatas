import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kirmatas/engine/audio_manager.dart';
import 'package:kirmatas/engine/game_controller.dart';
import 'package:kirmatas/models/game_state.dart';
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

  group('Audio Lifecycle & Background Mute Tests', () {
    test('Background lifecycle states immediately mute audio manager', () {
      final audio = AudioManager.instance;
      audio.appInForeground = true;
      audio.isBgmAllowed = true;

      // Simulate app minimizing / backgrounding
      audio.didChangeAppLifecycleState(AppLifecycleState.paused);
      expect(audio.appInForeground, isFalse);

      audio.didChangeAppLifecycleState(AppLifecycleState.inactive);
      expect(audio.appInForeground, isFalse);

      audio.didChangeAppLifecycleState(AppLifecycleState.hidden);
      expect(audio.appInForeground, isFalse);

      // PlaySfx should be safely blocked when in background
      audio.playSfx(GameSfx.hitBrick);

      // Restore to foreground
      audio.didChangeAppLifecycleState(AppLifecycleState.resumed);
      expect(audio.appInForeground, isTrue);
    });

    test('GameController.pause() does not enable BGM when in background', () {
      final controller = GameController();
      final audio = AudioManager.instance;

      audio.appInForeground = false;
      controller.status = GameStatus.playing;

      controller.pause();

      expect(controller.status, equals(GameStatus.paused));
      expect(audio.isBgmAllowed, isFalse);
    });
  });
}
