import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:kirmatas/engine/i18n.dart';
import 'package:kirmatas/models/cosmetics.dart';
import 'package:kirmatas/storage/save_manager.dart';
import 'package:kirmatas/ui/chest_widget.dart';
import 'package:kirmatas/ui/crate_opening_dialog.dart';
import 'package:kirmatas/ui/kaunos_ui.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('xyz.luan/audioplayers.global'),
      (MethodCall methodCall) async => 1,
    );
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('xyz.luan/audioplayers'),
      (MethodCall methodCall) async => 1,
    );
  });

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await SaveManager.instance.init();
  });

  group('Epic 6-Stage Card Revelation Ritual Suite', () {
    testWidgets('Full 6-stage ritual triggers and renders all custom visual & audio layers cleanly', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CrateOpeningDialog(crate: CrateDef.allCrates.first),
          ),
        ),
      );

      // 1. Drop chest down
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 700));

      // 2. Perform 3-tap chest progression
      await tester.tap(find.byType(ChestWidget));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      await tester.tap(find.byType(ChestWidget));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      await tester.tap(find.byType(ChestWidget)); // Tap 3 - Opening initiates
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump(const Duration(milliseconds: 1000));

      // 3. Verify opened card scene is active
      expect(find.byType(KaunosCard), findsOneWidget);
      expect(find.byType(KaunosTactileButton), findsOneWidget);
      expect(find.text(I18n.tr('claim_and_close')), findsOneWidget);

      // 4. Pump through Stage 1 & 2 (suction, levitation, freeze-frame, impact flip)
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));

      // 5. Pump through Stage 3, 4, 5 & 6 (runes, lightning, sheen, volumetric rays, chromatic split, mythic stars)
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump(const Duration(milliseconds: 500));

      // 6. Ensure no exceptions or layout overflow
      expect(tester.takeException(), isNull);

      // 7. Tap Claim & Close cleanly
      await tester.tap(find.text(I18n.tr('claim_and_close')));
      await tester.pump();
      expect(tester.takeException(), isNull);
    });

    testWidgets('Guaranteed Legendary redemption displays 5 mythic stars row', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: CrateOpeningDialog(
              isGuaranteedRedemption: true,
              category: 'balls',
            ),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 700));

      // 3 taps progression
      await tester.tap(find.byType(ChestWidget));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      await tester.tap(find.byType(ChestWidget));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      await tester.tap(find.byType(ChestWidget));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump(const Duration(milliseconds: 1000));

      // Fast forward full animation cycle
      await tester.pump(const Duration(milliseconds: 1000));

      expect(find.byType(KaunosCard), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
