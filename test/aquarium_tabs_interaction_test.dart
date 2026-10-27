import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kirmatas/storage/save_manager.dart';
import 'package:kirmatas/ui/aquarium_view.dart';
import 'package:kirmatas/ui/eco_tank_background.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Aquarium Control Tabs Interaction Tests', () {
    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      await SaveManager.instance.init();
    });

    testWidgets('Renders Yem, Parmak, and Katalog tabs cleanly', (tester) async {
      final save = SaveManager.instance;

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AquariumView(),
          ),
        ),
      );
      await tester.pump();

      // Check tab existence
      expect(find.textContaining('Yem (${save.fishFood})'), findsOneWidget);
      expect(find.text('Parmak'), findsOneWidget);
      expect(find.text('Katalog'), findsOneWidget);
    });

    testWidgets('Tapping Yem or Parmak tabs switches mode without consuming food immediately', (tester) async {
      final save = SaveManager.instance;

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AquariumView(),
          ),
        ),
      );
      await tester.pump();

      final initialFood = save.fishFood;
      expect(initialFood > 0, isTrue);

      // Tap Parmak tab -> switches mode, does not consume food
      await tester.tap(find.text('Parmak'));
      await tester.pump();

      expect(save.fishFood, initialFood, reason: 'Tapping mode tabs must not consume food');

      // Tap Yem tab -> switches mode back to feed, does not consume food
      await tester.tap(find.textContaining('Yem'));
      await tester.pump();

      expect(save.fishFood, initialFood, reason: 'Tapping Yem tab directly must only select the tab, not drop food');
    });
  });
}
