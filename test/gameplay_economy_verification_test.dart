import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kirmatas/config/balance_config.dart';
import 'package:kirmatas/engine/audio_manager.dart';
import 'package:kirmatas/engine/game_controller.dart';
import 'package:kirmatas/models/ball.dart';
import 'package:kirmatas/models/cosmetics.dart';
import 'package:kirmatas/models/level_design.dart';
import 'package:kirmatas/models/powerup.dart';

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

  group('Gameplay, Economy, Audio & Level Geometry Verification', () {
    test('Level 4 and Level 5 have right gap <= 8.0px and no open corridor', () {
      for (final lvl in [4, 5]) {
        final bricks = LevelDesign.buildClassicLevel(lvl, 400.0, 800.0);
        final rows = bricks.map((b) => b.y).toSet().toList()..sort();
        for (final rowY in rows) {
          final rowBricks = bricks.where((b) => (b.y - rowY).abs() < 2).toList()..sort((a, b) => a.x.compareTo(b.x));
          final rightmost = rowBricks.last.x + rowBricks.last.width;
          final rightGap = 400.0 - rightmost;
          final leftmost = rowBricks.first.x;
          expect(rightGap, equals(8.0), reason: 'Level $lvl, row at y=$rowY right gap must be 8.0px');
          expect(leftmost, equals(8.0), reason: 'Level $lvl, row at y=$rowY left gap must be 8.0px');
        }
      }
    });

    test('Upgrade prices match 2x-3x balance specification', () {
      final paddle = StatUpgrade.all.firstWhere((u) => u.id == 'paddle_width');
      expect(paddle.costs, equals([1800, 4500, 9000, 16500, 28000]));

      final magnet = StatUpgrade.all.firstWhere((u) => u.id == 'magnet');
      expect(magnet.costs, equals([1500, 3600, 7500, 14400, 25000]));

      final uGold = StatUpgrade.all.firstWhere((u) => u.id == 'u_gold');
      expect(uGold.costs, equals([1600, 3800, 8000, 16000, 30000]));

      final crit = StatUpgrade.all.firstWhere((u) => u.id == 'crit_damage');
      expect(crit.costs, equals([1600, 3600, 7000, 13000, 22000]));
    });

    test('Balance config economy is tightened', () {
      expect(BalanceConfig.classicCoinBaseDropRate, equals(0.07));
      expect(BalanceConfig.chaosCoinBaseDropRate, equals(0.045));
      expect(BalanceConfig.targetSessionGoldEarly, equals(75));
      expect(BalanceConfig.targetSessionGoldLate, equals(280));
      expect(BalanceConfig.upgradeBaseCost, equals(100));
    });

    test('Fireball activation gives balanced pierce count of 4', () {
      final ctrl = GameController();
      ctrl.balls.clear();
      ctrl.balls.add(Ball(x: 200, y: 300, vx: 0, vy: -200));
      expect(ctrl.balls.isNotEmpty, isTrue);

      ctrl.applyPowerUp(PowerUpType.fireball);
      expect(ctrl.balls.first.isFireball, isTrue);
      expect(ctrl.balls.first.fireballPierceCount, equals(4));
    });

    test('AudioManager throttles identical rapid-fire SFX without crash', () {
      final audio = AudioManager.instance;
      audio.appInForeground = true;
      audio.playSfx(GameSfx.hitBrick);
      audio.playSfx(GameSfx.hitBrick); // Should be safely throttled
      expect(audio.lastPlayedCombo, equals(0));
    });
  });
}
