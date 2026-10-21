import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kirmatas/engine/game_controller.dart';
import 'package:kirmatas/models/game_state.dart';
import 'package:kirmatas/models/powerup.dart';

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

  group('Fireball / Frost mutual exclusion', () {
    test('frost cannot be taken while fireball is active', () {
      final ctrl = GameController();
      ctrl.startNewGame(GameMode.classic, explicitStartLevel: 1);
      ctrl.status = GameStatus.playing;

      ctrl.applyPowerUp(PowerUpType.fireball);
      expect(ctrl.balls.first.isFireball, isTrue);

      // Trying to take frost now must not frost the ball (converts to multi).
      ctrl.applyPowerUp(PowerUpType.frost);
      expect(ctrl.balls.any((b) => b.isFrost), isFalse);
      expect(ctrl.activePowerUps.any((p) => p.type == PowerUpType.frost), isFalse);
      expect(ctrl.balls.first.isFireball, isTrue, reason: 'fireball stays untouched');
    });

    test('fireball cannot be taken while frost is active', () {
      final ctrl = GameController();
      ctrl.startNewGame(GameMode.classic, explicitStartLevel: 1);
      ctrl.status = GameStatus.playing;

      ctrl.applyPowerUp(PowerUpType.frost);
      expect(ctrl.balls.first.isFrost, isTrue);

      ctrl.applyPowerUp(PowerUpType.fireball);
      expect(ctrl.balls.any((b) => b.isFireball), isFalse);
      expect(ctrl.activePowerUps.any((p) => p.type == PowerUpType.fireball), isFalse);
      expect(ctrl.balls.first.isFrost, isTrue, reason: 'frost stays untouched');
    });

    test('each still applies normally on its own', () {
      final fire = GameController();
      fire.startNewGame(GameMode.classic, explicitStartLevel: 1);
      fire.status = GameStatus.playing;
      fire.applyPowerUp(PowerUpType.fireball);
      expect(fire.balls.first.isFireball, isTrue);

      final frost = GameController();
      frost.startNewGame(GameMode.classic, explicitStartLevel: 1);
      frost.status = GameStatus.playing;
      frost.applyPowerUp(PowerUpType.frost);
      expect(frost.balls.first.isFrost, isTrue);
    });
  });
}
