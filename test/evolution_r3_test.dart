import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kirmatas/engine/game_controller.dart';
import 'package:kirmatas/models/game_state.dart';

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

  group('R3: last-life tension & near-miss state', () {
    test('isLastLife is true only while playing with exactly 1 life', () {
      final ctrl = GameController();
      ctrl.startNewGame(GameMode.classic, explicitStartLevel: 2);
      ctrl.status = GameStatus.playing;

      ctrl.stats.lives = 3;
      expect(ctrl.isLastLife, isFalse);
      ctrl.stats.lives = 2;
      expect(ctrl.isLastLife, isFalse);
      ctrl.stats.lives = 1;
      expect(ctrl.isLastLife, isTrue);

      // Regaining a life returns to normal.
      ctrl.stats.lives = 2;
      expect(ctrl.isLastLife, isFalse);

      // Not shown outside active play (e.g. game over).
      ctrl.stats.lives = 1;
      ctrl.status = GameStatus.gameOver;
      expect(ctrl.isLastLife, isFalse);
    });

    test('near-miss flash starts inactive and decays to zero on update', () {
      final ctrl = GameController();
      ctrl.startNewGame(GameMode.classic, explicitStartLevel: 2);
      ctrl.status = GameStatus.playing;
      expect(ctrl.nearMissFlashTimer, 0.0);

      ctrl.nearMissFlashTimer = 0.55;
      ctrl.update(0.2);
      expect(ctrl.nearMissFlashTimer, closeTo(0.35, 0.001));
      ctrl.update(1.0);
      expect(ctrl.nearMissFlashTimer, 0.0);
    });
  });
}
