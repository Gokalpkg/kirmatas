import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kirmatas/engine/game_controller.dart';
import 'package:kirmatas/models/game_state.dart';
import 'package:kirmatas/storage/save_manager.dart';
import 'package:kirmatas/ui/hud_overlay.dart';
import 'package:kirmatas/ui/kaunos_ui.dart';
import 'package:kirmatas/ui/main_menu.dart';
import 'package:kirmatas/ui/pause_game_over.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await SaveManager.instance.init();
    MainMenuScreen.suppressBootPopups = true;
  });

  group('FTUE & Magnetic Re-Entry: KaunosMagneticHeroButton Tests', () {
    testWidgets('renders 88px height, default texts for level 1-2', (tester) async {
      bool tapped = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: KaunosMagneticHeroButton(
              level: 1,
              onTap: () => tapped = true,
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 50));

      expect(find.text('HAZIRSAN DOKUN'), findsOneWidget);
      expect(find.text('MACERAYA BAŞLA!'), findsOneWidget);
      expect(find.text('Dokun ve Tuğlaları Parçala!'), findsOneWidget);
      expect(find.byIcon(Icons.play_arrow_rounded), findsOneWidget);

      final sizedBox = tester.widget<SizedBox>(
        find.descendant(
          of: find.byType(KaunosMagneticHeroButton),
          matching: find.byWidgetPredicate((w) => w is SizedBox && w.height == 88),
        ),
      );
      expect(sizedBox.height, 88);
      expect(sizedBox.width, double.infinity);

      await tester.tap(find.byType(KaunosMagneticHeroButton));
      await tester.pump(const Duration(milliseconds: 50));
      expect(tapped, isTrue);

      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('renders dynamic re-entry title for level >= 3', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: KaunosMagneticHeroButton(
              level: 7,
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 50));

      expect(find.text('DEVAM ET: BÖLÜM 7'), findsOneWidget);
      expect(find.text('MACERAYA BAŞLA!'), findsNothing);

      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('triggerFocus invokes bounce and sonar pulse without error', (tester) async {
      final key = GlobalKey<KaunosMagneticHeroButtonState>();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: KaunosMagneticHeroButton(
              key: key,
              level: 2,
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 50));

      expect(key.currentState, isNotNull);
      key.currentState!.triggerFocus();
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.byType(KaunosMagneticHeroButton), findsOneWidget);

      await tester.pumpWidget(const SizedBox());
    });
  });

  group('FTUE Progressive Disclosure & Gürültü Filtresi: MainMenuScreen', () {
    testWidgets('level < 3 hides Kaos, League, Roadmap and shows KaunosMagneticHeroButton', (tester) async {
      SaveManager.instance.highestLevel = 1;
      await tester.binding.setSurfaceSize(const Size(430, 932));

      await tester.pumpWidget(
        const MaterialApp(
          home: MainMenuScreen(),
        ),
      );
      await tester.pump(const Duration(milliseconds: 200));

      // Magnetic Hero button should be visible
      expect(find.byType(KaunosMagneticHeroButton), findsOneWidget);
      expect(find.text('MACERAYA BAŞLA!'), findsOneWidget);

      // Noise elements should NOT exist
      expect(find.text('Bölüm 2: Mağaza ve Sandıklar'), findsNothing);
      expect(find.text('TÜM OYUN MODLARI'), findsNothing);
      expect(find.text('DEVAM ET: BÖLÜM 1'), findsNothing);

      await tester.pumpWidget(const SizedBox());
      await tester.binding.setSurfaceSize(null);
    });

    testWidgets('level >= 3 shows dynamic re-entry text and unlocks progressive cards', (tester) async {
      SaveManager.instance.highestLevel = 5;
      await tester.binding.setSurfaceSize(const Size(430, 932));

      await tester.pumpWidget(
        const MaterialApp(
          home: MainMenuScreen(),
        ),
      );
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.textContaining('DEVAM ET: BÖLÜM 5'), findsOneWidget);
      expect(find.byType(KaunosMagneticHeroButton), findsNothing);

      await tester.pumpWidget(const SizedBox());
      await tester.binding.setSurfaceSize(null);
    });
  });

  group('FTUE HUD Overlay: Pre-match Booster Tray', () {
    testWidgets('level <= 2 hides pre-match booster tray completely', (tester) async {
      await tester.binding.setSurfaceSize(const Size(430, 932));
      final controller = GameController();
      controller.stats.level = 1;
      controller.status = GameStatus.ready;
      controller.isMatchStart = true;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: HudOverlay(
              controller: controller,
              onPause: () {},
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 50));

      expect(find.text('+1 Can'), findsNothing);
      expect(find.text('Geniş'), findsNothing);
      expect(find.text('Çift Top'), findsNothing);

      await tester.pumpWidget(const SizedBox());
      await tester.binding.setSurfaceSize(null);
    });

    testWidgets('level > 2 displays pre-match booster tray', (tester) async {
      await tester.binding.setSurfaceSize(const Size(430, 932));
      final controller = GameController();
      controller.stats.level = 3;
      controller.status = GameStatus.ready;
      controller.isMatchStart = true;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: HudOverlay(
              controller: controller,
              onPause: () {},
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 50));

      expect(find.text('+1 Can'), findsOneWidget);
      expect(find.text('Geniş'), findsOneWidget);
      expect(find.text('Çift Top'), findsOneWidget);

      await tester.pumpWidget(const SizedBox());
      await tester.binding.setSurfaceSize(null);
    });
  });

  group('PauseGameOverOverlay: Reaction Buttons', () {
    testWidgets('victory state displays "SONRAKİ BÖLÜM ➔" green/gold neon button', (tester) async {
      final controller = GameController();
      controller.status = GameStatus.victory;
      bool restarted = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PauseGameOverOverlay(
              controller: controller,
              onResume: () {},
              onRestart: () => restarted = true,
              onMainMenu: () {},
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 50));

      final victoryBtn = find.text('SONRAKİ BÖLÜM ➔');
      expect(victoryBtn, findsOneWidget);

      await tester.tap(victoryBtn);
      await tester.pump(const Duration(milliseconds: 50));
      expect(restarted, isTrue);

      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('game over state displays "BİR EL DAHA! (RÖVANŞ)" 62px pulsing button', (tester) async {
      final controller = GameController();
      controller.status = GameStatus.gameOver;
      bool restarted = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PauseGameOverOverlay(
              controller: controller,
              onResume: () {},
              onRestart: () => restarted = true,
              onMainMenu: () {},
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 50));

      final rematchBtn = find.text('BİR EL DAHA! (RÖVANŞ)');
      expect(rematchBtn, findsOneWidget);

      // Verify 62px height on the press glow container
      final glowFinder = find.ancestor(
        of: rematchBtn,
        matching: find.byType(KaunosPressGlow),
      );
      expect(glowFinder, findsOneWidget);
      final size = tester.getSize(glowFinder);
      expect(size.height, 62.0);

      await tester.tap(rematchBtn);
      await tester.pump(const Duration(milliseconds: 50));
      expect(restarted, isTrue);

      await tester.pumpWidget(const SizedBox());
    });
  });
}
