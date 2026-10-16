import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kirmatas/storage/save_manager.dart';
import 'package:kirmatas/ui/fortune_wheel_dialog.dart';
import 'package:kirmatas/ui/main_menu.dart';
import 'package:kirmatas/ui/sector_map_view.dart';
import 'package:kirmatas/ui/tournament_dialog.dart';
import 'package:kirmatas/ui/upgrades_view.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

  // Target viewports from task specification + extreme edge dimensions
  const testDimensions = <String, Size>{
    'iPhone SE 1st Gen (320x568)': Size(320, 568),
    'Standard Compact Android (360x640)': Size(360, 640),
    'Modern Mobile (390x844)': Size(390, 844),
    'Ultra-Narrow Foldable (300x700)': Size(300, 700),
    'Ultra-Compact Height (320x480)': Size(320, 480),
  };

  group('Challenger M2 Recheck: Adversarial Layout & Overflow Stress Suite', () {
    group('1. UpgradesView Layout & Overflow Diagnostics', () {
    for (final size in [const Size(320, 568), const Size(360, 640), const Size(390, 844)]) {
      testWidgets('UpgradesView at $size with standard endgame (gold=999999, pearls=9999)', (tester) async {
        SharedPreferences.setMockInitialValues({});
        final save = SaveManager.instance;
        await save.init();
        save.gold = 999999;
        save.pearls = 9999;
        save.cosmicGoldMasteryLevel = 99;
        save.cosmicPearlMasteryLevel = 99;

        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1.0;

        final caughtErrors = <FlutterErrorDetails>[];
        final oldOnError = FlutterError.onError;
        FlutterError.onError = (details) {
          caughtErrors.add(details);
          oldOnError?.call(details);
        };

        await tester.pumpWidget(
          const MaterialApp(
            home: UpgradesView(),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        final scrollable = find.byType(Scrollable);
        if (scrollable.evaluate().isNotEmpty) {
          try {
            await tester.scrollUntilVisible(
              find.text('🌌 KOZMİK USTALIK (SONSUZ SEVİYE)'),
              250,
            );
            await tester.pump();
          } catch (_) {}
        }

        FlutterError.onError = oldOnError;
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();

        final overflows = caughtErrors.where((e) =>
            e.exceptionAsString().contains('RenderFlex overflowed') ||
            e.exceptionAsString().contains('A RenderFlex overflowed')).toList();

        for (final o in overflows) {
          debugPrint('>>> [OVERFLOW DIAGNOSTIC] UpgradesView at $size: ${o.exceptionAsString()}');
        }

        expect(overflows, isEmpty,
            reason: 'RenderFlex overflow occurred on UpgradesView at $size: ${overflows.map((e) => e.exceptionAsString()).join("; ")}');
      });

      testWidgets('UpgradesView at $size with extreme endgame (gold=999999999, pearls=999999)', (tester) async {
        SharedPreferences.setMockInitialValues({});
        final save = SaveManager.instance;
        await save.init();
        save.gold = 999999999;
        save.pearls = 999999;
        save.cosmicGoldMasteryLevel = 999;
        save.cosmicPearlMasteryLevel = 999;

        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1.0;

        final caughtErrors = <FlutterErrorDetails>[];
        final oldOnError = FlutterError.onError;
        FlutterError.onError = (details) {
          caughtErrors.add(details);
          oldOnError?.call(details);
        };

        await tester.pumpWidget(
          const MaterialApp(
            home: UpgradesView(),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        final scrollable = find.byType(Scrollable);
        if (scrollable.evaluate().isNotEmpty) {
          try {
            await tester.scrollUntilVisible(
              find.text('🌌 KOZMİK USTALIK (SONSUZ SEVİYE)'),
              250,
            );
            await tester.pump();
          } catch (_) {}
        }

        FlutterError.onError = oldOnError;
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();

        final overflows = caughtErrors.where((e) =>
            e.exceptionAsString().contains('RenderFlex overflowed') ||
            e.exceptionAsString().contains('A RenderFlex overflowed')).toList();

        for (final o in overflows) {
          debugPrint('>>> [OVERFLOW DIAGNOSTIC] UpgradesView extreme at $size: ${o.exceptionAsString()}');
        }

        expect(overflows, isEmpty,
            reason: 'RenderFlex overflow occurred on UpgradesView extreme at $size: ${overflows.map((e) => e.exceptionAsString()).join("; ")}');
      });
    }
  });

    testWidgets('2. MainMenuScreen: Zero RenderFlex overflow with extreme seasonal titles & arcade expansion', (tester) async {
      SharedPreferences.setMockInitialValues({});
      final save = SaveManager.instance;
      await save.init();

      // Stress state: large stats, unlocked prestige & tier 4
      save.highestLevel = 250;
      save.leagueTier = 4;
      save.gold = 99999999;

      for (final entry in testDimensions.entries) {
        final label = entry.key;
        final size = entry.value;

        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1.0;

        final caughtErrors = <FlutterErrorDetails>[];
        final oldOnError = FlutterError.onError;
        FlutterError.onError = (details) {
          caughtErrors.add(details);
          oldOnError?.call(details);
        };

        await tester.pumpWidget(
          const MaterialApp(
            home: MainMenuScreen(),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        // Test expanding arcade modes if button is visible
        final arcadeToggle = find.text('DİĞER MODLAR');
        if (arcadeToggle.evaluate().isNotEmpty) {
          try {
            await tester.tap(arcadeToggle.first);
            await tester.pump();
            await tester.pump(const Duration(milliseconds: 200));
          } catch (_) {}
        }

        FlutterError.onError = oldOnError;

        final hasOverflow = caughtErrors.any((e) =>
            e.exceptionAsString().contains('RenderFlex overflowed') ||
            e.exceptionAsString().contains('A RenderFlex overflowed'));

        expect(hasOverflow, isFalse,
            reason: 'RenderFlex overflow occurred on MainMenuScreen at $label ($size): ${caughtErrors.map((e) => e.exceptionAsString()).join("; ")}');
        expect(tester.takeException(), isNull,
            reason: 'Exception thrown on MainMenuScreen at $label ($size)');
      }

      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    testWidgets('3. TournamentDialog: Zero RenderFlex overflow across all tiers and compact viewports', (tester) async {
      SharedPreferences.setMockInitialValues({});
      final save = SaveManager.instance;
      await save.init();

      for (final tier in [0, 2, 4]) {
        save.leagueTier = tier;
        save.weeklyTournamentScore = 9999999;

        for (final entry in testDimensions.entries) {
          final label = entry.key;
          final size = entry.value;

          tester.view.physicalSize = size;
          tester.view.devicePixelRatio = 1.0;

          final caughtErrors = <FlutterErrorDetails>[];
          final oldOnError = FlutterError.onError;
          FlutterError.onError = (details) {
            caughtErrors.add(details);
            oldOnError?.call(details);
          };

          await tester.pumpWidget(
            MaterialApp(
              home: Scaffold(
                body: Builder(
                  builder: (context) => ElevatedButton(
                    onPressed: () => TournamentDialog.show(context, save: save),
                    child: const Text('OPEN_TOURNAMENT'),
                  ),
                ),
              ),
            ),
          );
          await tester.pump();
          await tester.tap(find.text('OPEN_TOURNAMENT'));
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 300));

          // Try scrolling the leaderboard inside modal bottom sheet
          final listFinder = find.byType(ListView);
          if (listFinder.evaluate().isNotEmpty) {
            try {
              await tester.drag(listFinder.first, const Offset(0, -200));
              await tester.pump();
            } catch (_) {}
          }

          FlutterError.onError = oldOnError;

          final hasOverflow = caughtErrors.any((e) =>
              e.exceptionAsString().contains('RenderFlex overflowed') ||
              e.exceptionAsString().contains('A RenderFlex overflowed'));

          expect(hasOverflow, isFalse,
              reason: 'RenderFlex overflow occurred on TournamentDialog (Tier $tier) at $label ($size): ${caughtErrors.map((e) => e.exceptionAsString()).join("; ")}');
          expect(tester.takeException(), isNull,
              reason: 'Exception on TournamentDialog at $label ($size)');

          // Dismiss dialog
          final closeButton = find.byIcon(Icons.close_rounded);
          if (closeButton.evaluate().isNotEmpty) {
            await tester.tap(closeButton.first);
            await tester.pump();
            await tester.pump(const Duration(milliseconds: 300));
          }
        }
      }

      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    testWidgets('4. SectorMapView: Zero RenderFlex overflow with Prestige Omega card on narrow screens', (tester) async {
      SharedPreferences.setMockInitialValues({});
      final save = SaveManager.instance;
      await save.init();
      save.highestLevel = 500; // Deep into prestige territory

      for (final entry in testDimensions.entries) {
        final label = entry.key;
        final size = entry.value;

        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1.0;

        final caughtErrors = <FlutterErrorDetails>[];
        final oldOnError = FlutterError.onError;
        FlutterError.onError = (details) {
          caughtErrors.add(details);
          oldOnError?.call(details);
        };

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SectorMapView(save: save),
            ),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        try {
          await tester.scrollUntilVisible(find.text('PRESTİJ SEKTÖR OMEGA 🌌'), 400);
          await tester.pump();
        } catch (_) {}

        FlutterError.onError = oldOnError;

        final hasOverflow = caughtErrors.any((e) =>
            e.exceptionAsString().contains('RenderFlex overflowed') ||
            e.exceptionAsString().contains('A RenderFlex overflowed'));

        expect(hasOverflow, isFalse,
            reason: 'RenderFlex overflow on SectorMapView at $label ($size)');
        expect(tester.takeException(), isNull);
      }

      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    group('5. FortuneWheelDialog Layout Diagnostics', () {
      for (final size in [const Size(320, 568), const Size(360, 640), const Size(390, 844), const Size(320, 480)]) {
        testWidgets('FortuneWheelDialog at $size', (tester) async {
          SharedPreferences.setMockInitialValues({});
          final save = SaveManager.instance;
          await save.init();

          tester.view.physicalSize = size;
          tester.view.devicePixelRatio = 1.0;

          final caughtErrors = <FlutterErrorDetails>[];
          final oldOnError = FlutterError.onError;
          FlutterError.onError = (details) {
            caughtErrors.add(details);
            oldOnError?.call(details);
          };

          await tester.pumpWidget(
            MaterialApp(
              home: Scaffold(
                body: Builder(
                  builder: (context) => ElevatedButton(
                    onPressed: () => showDialog(
                      context: context,
                      builder: (_) => const FortuneWheelDialog(),
                    ),
                    child: const Text('OPEN_WHEEL'),
                  ),
                ),
              ),
            ),
          );
          await tester.pump();
          await tester.tap(find.text('OPEN_WHEEL'));
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 200));

          FlutterError.onError = oldOnError;
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();

          final overflows = caughtErrors.where((e) =>
              e.exceptionAsString().contains('RenderFlex overflowed') ||
              e.exceptionAsString().contains('A RenderFlex overflowed')).toList();

          for (final o in overflows) {
            debugPrint('>>> [OVERFLOW DIAGNOSTIC] FortuneWheelDialog at $size: ${o.exceptionAsString()}');
          }

          expect(overflows, isEmpty,
              reason: 'RenderFlex overflow on FortuneWheelDialog at $size: ${overflows.map((e) => e.exceptionAsString()).join("; ")}');
        });
      }
    });

    testWidgets('6. Accessibility Text Scaling: Zero RenderFlex overflow at 1.3x scale factor', (tester) async {
      SharedPreferences.setMockInitialValues({});
      final save = SaveManager.instance;
      await save.init();
      save.gold = 50000;
      save.pearls = 200;
      save.highestLevel = 240;
      save.leagueTier = 3;

      // Test 320x568 and 360x640 with textScaler: 1.3
      for (final size in [const Size(320, 568), const Size(360, 640)]) {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1.0;

        final caughtErrors = <FlutterErrorDetails>[];
        final oldOnError = FlutterError.onError;
        FlutterError.onError = (details) {
          caughtErrors.add(details);
          oldOnError?.call(details);
        };

        // Test MainMenuScreen
        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData(
              textTheme: const TextTheme(),
            ),
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context).copyWith(
                textScaler: const TextScaler.linear(1.3),
              ),
              child: child!,
            ),
            home: const MainMenuScreen(),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        FlutterError.onError = oldOnError;

        final hasOverflow = caughtErrors.any((e) =>
            e.exceptionAsString().contains('RenderFlex overflowed') ||
            e.exceptionAsString().contains('A RenderFlex overflowed'));

        expect(hasOverflow, isFalse,
            reason: 'RenderFlex overflow on MainMenu with 1.3x TextScale at $size: ${caughtErrors.map((e) => e.exceptionAsString()).join("; ")}');
        expect(tester.takeException(), isNull);
      }

      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
  });
}
