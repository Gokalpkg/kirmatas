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

  group('Milestone 2 — 3D Crates Quality & Architectural Tiers', () {
    testWidgets('ChestWidget renders all 4 architectural tiers with 3D depth', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: Column(
                children: [
                  // Normal / Common (Basalt & Raw Iron)
                  ChestWidget(
                    size: 64,
                    tier: Rarity.common,
                    openProgress: 0.0,
                  ),
                  // Rare (Oceanic Jade-Obsidian & Bronze-Teal)
                  ChestWidget(
                    size: 80,
                    tier: Rarity.rare,
                    openProgress: 0.3,
                  ),
                  // Epic (Midnight Violet Obsidian & Violet-Gold Filigree)
                  ChestWidget(
                    size: 96,
                    tier: Rarity.epic,
                    openProgress: 0.7,
                  ),
                  // Legendary (24k Sun-Gold Leaf Armor & Star Solar Crystal)
                  ChestWidget(
                    size: 120,
                    tier: Rarity.legendary,
                    isOpened: true,
                    openProgress: 1.0,
                  ),
                ],
              ),
            ),
          ),
        ),
      );

      await tester.pump();
      expect(find.byType(ChestWidget), findsNWidgets(4));
      expect(tester.takeException(), isNull);
    });

    testWidgets('ChestWidget constructor retains 100% backwards compatibility', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                ChestWidget(),
                ChestWidget(size: 48),
                ChestWidget(size: 72, openProgress: 0.5),
                ChestWidget(size: 96, isOpened: true),
              ],
            ),
          ),
        ),
      );

      await tester.pump();
      expect(find.byType(ChestWidget), findsNWidgets(4));
      expect(tester.takeException(), isNull);
    });

    test('ChestWidget.inferTier accurately infers tiers across all palette colors', () {
      // Common colors
      expect(ChestWidget.inferTier(const Color(0xFF90A4AE)), Rarity.common);
      expect(ChestWidget.inferTier(const Color(0xFF8D6E63)), Rarity.common);
      expect(ChestWidget.inferTier(const Color(0xFF455A64)), Rarity.common);

      // Rare colors
      expect(ChestWidget.inferTier(const Color(0xFF00E5FF)), Rarity.rare);
      expect(ChestWidget.inferTier(const Color(0xFF00BCD4)), Rarity.rare);
      expect(ChestWidget.inferTier(const Color(0xFF40C4FF)), Rarity.rare);

      // Epic colors
      expect(ChestWidget.inferTier(const Color(0xFFE040FB)), Rarity.epic);
      expect(ChestWidget.inferTier(const Color(0xFF7C4DFF)), Rarity.epic);
      expect(ChestWidget.inferTier(const Color(0xFFFF7EB3)), Rarity.epic);

      // Legendary colors
      expect(ChestWidget.inferTier(const Color(0xFFFFD54F)), Rarity.legendary);
      expect(ChestWidget.inferTier(const Color(0xFFFFB300)), Rarity.legendary);
      expect(ChestWidget.inferTier(const Color(0xFFFF8F00)), Rarity.legendary);
    });
  });

  group('Milestone 2 — CrateOpeningDialog Tactile Opening Sequence', () {
    testWidgets('Aquarium CrateOpeningDialog completes 3-tap progression and presents 3D obsidian crystal reward card', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CrateOpeningDialog(crate: CrateDef.allCrates.first),
          ),
        ),
      );

      // 1. Initial drop animation completes
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 700));

      expect(find.byType(ChestWidget), findsOneWidget);
      expect(find.text('SIRADAN'), findsOneWidget);
      expect(find.text('Sandığa Dokun (1/3)'), findsOneWidget);

      // 2. Tap 1: Trigger tactile squash, wobble, and shockwave
      await tester.tap(find.byType(ChestWidget));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('Tekrar Dokun (2/3)'), findsOneWidget);

      // 3. Tap 2: Trigger second tactile compression and upgrade check
      await tester.tap(find.byType(ChestWidget));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('Açmak İçin Dokun! (3/3)'), findsOneWidget);

      // 4. Tap 3: Grand opening, volumetric rays, lid damping bounce, and pillar of light
      await tester.tap(find.byType(ChestWidget));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump(const Duration(milliseconds: 1000));

      // 5. Reward Scene: 3D Obsidian Crystal Tablet & 3D Tactile Claim Button
      expect(find.byType(KaunosCard), findsOneWidget);
      expect(find.byType(KaunosTactileButton), findsOneWidget);
      expect(find.text(I18n.tr('claim_and_close')), findsOneWidget);

      // Tap claim button to close cleanly
      await tester.tap(find.text(I18n.tr('claim_and_close')));
      await tester.pump();
      expect(tester.takeException(), isNull);
    });

    testWidgets('Category CrateOpeningDialog renders properly for balls crate', (tester) async {
      final ballCrate = CategoryCrateInfo.categoryCrates['balls']!;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CrateOpeningDialog(categoryCrate: ballCrate),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 700));

      expect(find.byType(ChestWidget), findsOneWidget);
      expect(find.text('Sandığa Dokun (1/3)'), findsOneWidget);

      // 3 taps progression
      await tester.tap(find.byType(ChestWidget));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('Tekrar Dokun (2/3)'), findsOneWidget);

      await tester.tap(find.byType(ChestWidget));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('Açmak İçin Dokun! (3/3)'), findsOneWidget);

      await tester.tap(find.byType(ChestWidget));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump(const Duration(milliseconds: 1000));

      expect(find.text(I18n.tr('claim_and_close')), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('Guaranteed Redemption CrateOpeningDialog opens directly without crashing', (tester) async {
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

      expect(find.byType(ChestWidget), findsOneWidget);
      expect(find.text('Sandığa Dokun (1/3)'), findsOneWidget);

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

      expect(find.text(I18n.tr('claim_and_close')), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
