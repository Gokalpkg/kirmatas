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

  group('Target Lock & Slippery Ground Tests', () {
    test('PowerUpType.lock acquires target brick and targets ball with timer', () {
      final ctrl = GameController();
      ctrl.startNewGame(GameMode.classic, explicitStartLevel: 1);
      ctrl.status = GameStatus.playing;

      expect(ctrl.bricks.isNotEmpty, isTrue);
      expect(ctrl.lockedTargetBrick, isNull);

      // Apply target lock power-up
      ctrl.applyPowerUp(PowerUpType.lock);

      expect(ctrl.lockedTargetBrick, isNotNull);
      expect(ctrl.targetLockTimer, greaterThan(0.0));
      expect(ctrl.targetLockingBall, isNotNull);

      // Updating frames decays the timer
      final initialTimer = ctrl.targetLockTimer;
      ctrl.update(0.1);
      expect(ctrl.targetLockTimer, lessThan(initialTimer));
    });

    test('Target lock ball homing guides ball towards locked brick', () {
      final ctrl = GameController();
      ctrl.startNewGame(GameMode.classic, explicitStartLevel: 1);
      ctrl.status = GameStatus.playing;

      ctrl.applyPowerUp(PowerUpType.lock);
      final target = ctrl.lockedTargetBrick!;
      final ball = ctrl.targetLockingBall!;

      // Position ball below target and moving away to the right
      ball.x = target.x;
      ball.y = target.y + 200.0;
      ball.vx = 200.0;
      ball.vy = 0.0;

      // Update physics
      ctrl.update(0.05);

      // Homing steering should steer ball towards negative y (upwards towards target)
      expect(ball.vy, lessThan(0.0));
    });

    test('Slippery ground (clumsy) deflects ball randomly on paddle hit', () {
      final ctrl = GameController();
      ctrl.startNewGame(GameMode.classic, explicitStartLevel: 1);
      ctrl.status = GameStatus.playing;

      ctrl.paddle.isClumsy = true;
      expect(ctrl.paddle.isClumsy, isTrue);

      final ball = ctrl.balls.first;
      ball.x = ctrl.paddle.x;
      ball.y = ctrl.paddle.y - ball.radius;
      ball.vy = 200.0;

      // Update frame causing paddle collision
      ctrl.update(0.016);

      // Ball should have bounced upward (vy < 0)
      expect(ball.vy, lessThan(0.0));
    });

    test('Power-up rebalances & shortened debuff durations', () {
      expect(PowerUpType.reverse.duration, equals(4.0));
      expect(PowerUpType.shrink.duration, equals(5.5));
      expect(PowerUpType.fastball.duration, equals(5.0));
      expect(PowerUpType.clumsy.duration, equals(4.5));
      expect(PowerUpType.invis.duration, equals(4.0));
    });

    test('Frost Ball freezes bricks and frozen brick shatters in 1 hit', () {
      final ctrl = GameController();
      ctrl.startNewGame(GameMode.classic, explicitStartLevel: 1);
      ctrl.status = GameStatus.playing;

      ctrl.applyPowerUp(PowerUpType.frost);
      expect(ctrl.balls.first.isFrost, isTrue);

      final brick = ctrl.bricks.firstWhere((b) => b.isAlive && !b.isSteel);
      brick.isFrozen = true;
      expect(brick.isFrozen, isTrue);

      final ball = ctrl.balls.first;
      ball.isStuck = false;
      ball.x = brick.x + brick.width / 2;
      ball.y = brick.y + brick.height + ball.radius;
      ball.vx = 0.0;
      ball.vy = -200.0;

      // Update collision
      ctrl.update(0.02);

      // Frozen brick must shatter and die in 1 hit!
      expect(brick.isAlive, isFalse);
    });

    test('Shrapnel powerup spawns piercing pellet projectiles upon impact', () {
      final ctrl = GameController();
      ctrl.startNewGame(GameMode.classic, explicitStartLevel: 1);
      ctrl.status = GameStatus.playing;

      ctrl.applyPowerUp(PowerUpType.shrapnel);
      expect(ctrl.balls.first.isShrapnel, isTrue);

      final brick = ctrl.bricks.firstWhere((b) => b.isAlive && !b.isSteel);
      final ball = ctrl.balls.first;
      ball.isStuck = false;
      ball.x = brick.x + brick.width / 2;
      ball.y = brick.y + brick.height + ball.radius;
      ball.vx = 0.0;
      ball.vy = -200.0;

      final initialProjCount = ctrl.projectiles.length;
      ctrl.update(0.02);

      // Shrapnel pellets should be spawned
      expect(ctrl.projectiles.length, greaterThan(initialProjCount));
      expect(ctrl.projectiles.any((p) => p.isShrapnel), isTrue);
    });
  });
}
