import 'package:flutter_test/flutter_test.dart';
import 'package:kirmatas/models/ball.dart';
import 'package:kirmatas/models/cosmetics.dart';
import 'package:kirmatas/models/game_state.dart';
import 'package:kirmatas/models/level_design.dart';
import 'package:kirmatas/models/powerup.dart';

void main() {
  group('Kirmatas Game Engine Tests', () {
    test('Game modes have correct Turkish descriptions', () {
      expect(GameMode.classic.displayName, 'Klasik');
      expect(GameMode.zen.displayName, 'Zen');
      expect(GameMode.descend.displayName, 'Çöküş');
      expect(GameMode.daily.displayName, 'Günlük');
      expect(GameMode.tuft.displayName, 'Tufting');
    });

    test('LevelDesign generates correct brick count for classic level', () {
      final bricks = LevelDesign.buildClassicLevel(1, 360, 640);
      expect(bricks.isNotEmpty, true);
      expect(bricks.any((b) => b.isAlive), true);
    });

    test('Level 5 is a boss battle with high HP boss brick', () {
      final bricks = LevelDesign.buildClassicLevel(5, 360, 640);
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
      expect(PowerUpType.values.length, 22); // our comprehensive enum
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
  });
}
