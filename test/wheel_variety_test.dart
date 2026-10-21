import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:kirmatas/storage/save_manager.dart';
import 'package:kirmatas/ui/fortune_wheel_dialog.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Fortune wheel variety sectors', () {
    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      await SaveManager.instance.init();
    });

    test('wheel has 10 sectors and weights sum to 100', () {
      expect(FortuneWheelDialog.rewards.length, 10);
      expect(FortuneWheelDialog.spinWeights.length, 10);
      final total = FortuneWheelDialog.spinWeights.reduce((a, b) => a + b);
      expect(total, closeTo(100.0, 0.01));
    });

    testWidgets('pearl sector grants +1 pearl, food sector grants +4 food', (tester) async {
      late BuildContext ctx;
      await tester.pumpWidget(MaterialApp(
        home: Builder(builder: (c) {
          ctx = c;
          return const SizedBox();
        }),
      ));

      final save = SaveManager.instance;
      final pearlReward = FortuneWheelDialog.rewards.firstWhere((r) => r.label == '+1 İNCİ');
      final foodReward = FortuneWheelDialog.rewards.firstWhere((r) => r.label == '+4 YEM');

      final pearlsBefore = save.pearls;
      pearlReward.onClaim(ctx, save);
      expect(save.pearls, pearlsBefore + 1);

      final foodBefore = save.fishFood;
      foodReward.onClaim(ctx, save);
      await tester.pump();
      expect(save.fishFood, foodBefore + 4);
    });
  });
}
