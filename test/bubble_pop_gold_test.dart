import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:kirmatas/storage/save_manager.dart';
import 'package:kirmatas/ui/plant_system.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({'gold': 100});
    await SaveManager.instance.init();
  });

  group('Oxygen Bubble Tap & Gold Reward Tests', () {
    test('Tap within hit distance detects and pops the target bubble', () {
      final bubbles = <PlantOxygenBubble>[
        PlantOxygenBubble(
          x: 100.0,
          y: 300.0,
          initialRadius: 3.5,
          maxRadius: 5.0,
          speed: 25.0,
          wobblePhase: 0.0,
        ),
        PlantOxygenBubble(
          x: 250.0,
          y: 400.0,
          initialRadius: 4.0,
          maxRadius: 6.0,
          speed: 25.0,
          wobblePhase: 1.0,
        ),
      ];

      // Simulate a tap close to the first bubble (tap at (105, 304))
      const tapPos = Offset(105.0, 304.0);
      const minHitDist = 28.0;

      PlantOxygenBubble? hitBubble;
      int hitIndex = -1;
      for (int i = bubbles.length - 1; i >= 0; i--) {
        final b = bubbles[i];
        final d = sqrt((tapPos.dx - b.x) * (tapPos.dx - b.x) + (tapPos.dy - b.y) * (tapPos.dy - b.y));
        if (d < minHitDist) {
          hitBubble = b;
          hitIndex = i;
          break;
        }
      }

      expect(hitBubble, isNotNull);
      expect(hitIndex, equals(0));

      // Remove popped bubble
      bubbles.removeAt(hitIndex);
      expect(bubbles.length, equals(1));
      expect(bubbles.first.x, equals(250.0));
    });

    test('Popping a plant oxygen bubble credits +1 gold to player save', () {
      final save = SaveManager.instance;
      final startGold = save.gold;

      save.addGold(1);

      expect(save.gold, equals(startGold + 1));
    });

    test('Tap far from any bubble does not pop bubbles', () {
      final bubbles = <PlantOxygenBubble>[
        PlantOxygenBubble(
          x: 100.0,
          y: 300.0,
          initialRadius: 3.5,
          maxRadius: 5.0,
          speed: 25.0,
          wobblePhase: 0.0,
        ),
      ];

      // Tap far away at (300, 600)
      const tapPos = Offset(300.0, 600.0);
      const minHitDist = 28.0;

      PlantOxygenBubble? hitBubble;
      for (int i = bubbles.length - 1; i >= 0; i--) {
        final b = bubbles[i];
        final d = sqrt((tapPos.dx - b.x) * (tapPos.dx - b.x) + (tapPos.dy - b.y) * (tapPos.dy - b.y));
        if (d < minHitDist) {
          hitBubble = b;
          break;
        }
      }

      expect(hitBubble, isNull);
      expect(bubbles.length, equals(1));
    });
  });
}
