import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:kirmatas/engine/i18n.dart';
import 'package:kirmatas/storage/save_manager.dart';
import 'package:kirmatas/ui/main_menu.dart';
import 'package:kirmatas/ui/settings_dialog.dart';
import 'package:kirmatas/ui/tournament_dialog.dart';

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
    SaveManager.instance.language = 'tr';
  });

  const stressViewports = <String, Size>{
    '320x480 (Ultra-Narrow Legacy)': Size(320, 480),
    '320x568 (iPhone 5/SE1)': Size(320, 568),
    '360x640 (Compact Android)': Size(360, 640),
    '390x844 (iPhone 14)': Size(390, 844),
  };

  const textScales = <double>[1.0, 1.3, 1.5];

  // Helper to run widget within isolated overflow detector
  Future<void> runWithOverflowCheck(
    WidgetTester tester, {
    required Size size,
    required double textScale,
    required Widget child,
    String? scenarioDescription,
    Future<void> Function()? interaction,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final caughtErrors = <FlutterErrorDetails>[];
    final oldOnError = FlutterError.onError;
    FlutterError.onError = (details) {
      caughtErrors.add(details);
      oldOnError?.call(details);
    };

    try {
      await tester.pumpWidget(
        MaterialApp(
          builder: (context, c) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
              textScaler: TextScaler.linear(textScale),
            ),
            child: c!,
          ),
          home: child,
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 150));

      if (interaction != null) {
        await interaction();
      }

      await tester.pump(const Duration(milliseconds: 150));
    } finally {
      FlutterError.onError = oldOnError;
    }

    final overflowErrors = caughtErrors.where((e) {
      final msg = e.exceptionAsString();
      return msg.contains('RenderFlex overflowed') ||
          msg.contains('A RenderFlex overflowed');
    }).toList();

    expect(
      overflowErrors,
      isEmpty,
      reason: 'RenderFlex overflow in $scenarioDescription at viewport ${size.width}x${size.height} '
          'with text scale ${textScale}x:\n'
          '${overflowErrors.map((e) => e.exceptionAsString()).join("\n")}',
    );

    expect(tester.takeException(), isNull);
  }

  // ===========================================================================
  // GROUP 1: SETTINGS DIALOG VIEWPORT & TEXT SCALE STRESS MATRIX
  // ===========================================================================
  group('Empirical Challenge: SettingsDialog Responsive & Text Scaling Stress', () {
    String? mockClipboard;

    setUp(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (MethodCall methodCall) async {
          if (methodCall.method == 'Clipboard.setData') {
            mockClipboard = (methodCall.arguments as Map)['text'] as String?;
            return null;
          } else if (methodCall.method == 'Clipboard.getData') {
            return <String, dynamic>{'text': mockClipboard};
          }
          return null;
        },
      );
    });

    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      );
    });

    for (final vpEntry in stressViewports.entries) {
      for (final scale in textScales) {
        testWidgets(
          'SettingsDialog renders & scrolls with zero overflow on ${vpEntry.key} @ ${scale}x',
          (tester) async {
            final save = SaveManager.instance;
            save.highestLevel = 15;
            save.gold = 5000;
            save.pearls = 40;

            await runWithOverflowCheck(
              tester,
              size: vpEntry.value,
              textScale: scale,
              scenarioDescription: 'SettingsDialog on ${vpEntry.key} scale ${scale}x',
              child: Scaffold(
                body: Builder(
                  builder: (ctx) => ElevatedButton(
                    onPressed: () => SettingsDialog.show(ctx, save: save),
                    child: const Text('OPEN_SETTINGS'),
                  ),
                ),
              ),
              interaction: () async {
                // Open dialog
                await tester.tap(find.text('OPEN_SETTINGS'));
                await tester.pump();
                await tester.pump(const Duration(milliseconds: 250));

                expect(find.byType(AlertDialog), findsOneWidget);

                // Scroll through the entire content to test every row and widget under layout constraints
                final scrollable = find.byType(SingleChildScrollView);
                expect(scrollable, findsOneWidget);

                // Scroll down
                await tester.drag(scrollable, const Offset(0, -250));
                await tester.pump();
                await tester.pump(const Duration(milliseconds: 100));

                await tester.drag(scrollable, const Offset(0, -300));
                await tester.pump();
                await tester.pump(const Duration(milliseconds: 100));

                // Verify backup buttons are visible and functional
                final copyBtn = find.text(I18n.tr('progress_copy'));
                if (copyBtn.evaluate().isNotEmpty) {
                  await tester.tap(copyBtn, warnIfMissed: false);
                  await tester.pump();
                }

                // Scroll back up
                await tester.drag(scrollable, const Offset(0, 500));
                await tester.pump();
                await tester.pump(const Duration(milliseconds: 100));

                // Close dialog
                final closeBtn = find.text(I18n.tr('close'));
                if (closeBtn.evaluate().isNotEmpty) {
                  await tester.tap(closeBtn);
                  await tester.pump();
                }
              },
            );
          },
        );
      }
    }
  });

  // ===========================================================================
  // GROUP 2: TOURNAMENT DIALOG VIEWPORT & TEXT SCALE STRESS MATRIX
  // ===========================================================================
  group('Empirical Challenge: TournamentDialog (Dual Tab) Responsive & Text Scaling Stress', () {
    for (final vpEntry in stressViewports.entries) {
      for (final scale in textScales) {
        testWidgets(
          'TournamentDialog (Tabs 0 & 1) renders with zero overflow on ${vpEntry.key} @ ${scale}x',
          (tester) async {
            final save = SaveManager.instance;
            save.highestLevel = 12;
            save.leagueTier = 3;
            save.weeklyTournamentScore = 88400;
            save.questFishFed = true;
            save.questBricksBroken = 120;
            save.claimedQuests.clear();

            bool joinTriggered = false;

            await runWithOverflowCheck(
              tester,
              size: vpEntry.value,
              textScale: scale,
              scenarioDescription: 'TournamentDialog on ${vpEntry.key} scale ${scale}x',
              child: Scaffold(
                body: Builder(
                  builder: (ctx) => ElevatedButton(
                    onPressed: () => TournamentDialog.show(
                      ctx,
                      save: save,
                      onJoinTournament: () => joinTriggered = true,
                    ),
                    child: const Text('OPEN_TOURNAMENT'),
                  ),
                ),
              ),
              interaction: () async {
                // Open dialog
                await tester.tap(find.text('OPEN_TOURNAMENT'));
                await tester.pump();
                await tester.pump(const Duration(milliseconds: 300));
                await tester.pump(const Duration(seconds: 1));

                // Tab 0: League checks
                expect(find.text('HAFTALIK LİG'), findsOneWidget);
                expect(find.text('GÜNLÜK GÖREVLER'), findsOneWidget);
                expect(find.text('HAFTALIK LİG ŞAMPİYONASI'), findsOneWidget);

                // Switch to Tab 1: Quests
                await tester.tap(find.text('GÜNLÜK GÖREVLER'));
                await tester.pump();
                await tester.pump(const Duration(milliseconds: 300));

                expect(find.text(I18n.tr('quest_feed')), findsOneWidget);

                // Claim quest if available
                final claimBtn = find.text('ÖDÜLÜ AL');
                if (claimBtn.evaluate().isNotEmpty) {
                  await tester.tap(claimBtn.first);
                  await tester.pump();
                  await tester.pump(const Duration(milliseconds: 200));
                }

                // Switch back to Tab 0: League
                await tester.tap(find.text('HAFTALIK LİG'));
                await tester.pump();
                await tester.pump(const Duration(milliseconds: 300));

                // Tap join button
                final joinBtn = find.text('MÜCADELEYE KATIL');
                expect(joinBtn, findsOneWidget);
                await tester.tap(joinBtn);
                await tester.pump();
                await tester.pump(const Duration(milliseconds: 300));

                expect(joinTriggered, isTrue);
              },
            );
          },
        );
      }
    }
  });

  // ===========================================================================
  // GROUP 3: MAIN MENU SCREEN VIEWPORT & TEXT SCALE STRESS MATRIX
  // ===========================================================================
  group('Empirical Challenge: MainMenuScreen Responsive & Text Scaling Stress', () {
    for (final vpEntry in stressViewports.entries) {
      for (final scale in textScales) {
        testWidgets(
          'MainMenuScreen renders with zero overflow on ${vpEntry.key} @ ${scale}x (Locked State)',
          (tester) async {
            final save = SaveManager.instance;
            save.highestLevel = 1;
            save.totalGold = 0;
            save.hasCompletedMainMenuTour = true;

            await runWithOverflowCheck(
              tester,
              size: vpEntry.value,
              textScale: scale,
              scenarioDescription: 'MainMenuScreen (Locked) on ${vpEntry.key} scale ${scale}x',
              child: const MainMenuScreen(),
              interaction: () async {
                // Check essential lock elements
                expect(find.text('ETKİNLİKLER & LİG'), findsOneWidget);
                expect(find.text('Bölüm 7 seviyesinde açılır'), findsOneWidget);

                // Scroll the main menu column up and down to check full default hub layout
                final menuScroll = find.byType(SingleChildScrollView);
                if (menuScroll.evaluate().isNotEmpty) {
                  await tester.drag(menuScroll, const Offset(0, -300));
                  await tester.pump();
                  await tester.pump(const Duration(milliseconds: 100));
                  await tester.drag(menuScroll, const Offset(0, 300));
                  await tester.pump();
                }
              },
            );
          },
        );

        testWidgets(
          'MainMenuScreen renders with zero overflow on ${vpEntry.key} @ ${scale}x (Unlocked State)',
          (tester) async {
            final save = SaveManager.instance;
            save.highestLevel = 15;
            save.totalGold = 8500;
            save.pearls = 45;
            save.leagueTier = 3;
            save.hasCompletedMainMenuTour = true;

            await runWithOverflowCheck(
              tester,
              size: vpEntry.value,
              textScale: scale,
              scenarioDescription: 'MainMenuScreen (Unlocked) on ${vpEntry.key} scale ${scale}x',
              child: const MainMenuScreen(),
              interaction: () async {
                expect(find.text('ETKİNLİKLER & LİG'), findsOneWidget);
                expect(find.text('LİG SEZONU'), findsOneWidget);

                final menuScroll = find.byType(SingleChildScrollView);
                if (menuScroll.evaluate().isNotEmpty) {
                  await tester.drag(menuScroll, const Offset(0, -250));
                  await tester.pump();
                  await tester.pump(const Duration(milliseconds: 100));
                  await tester.drag(menuScroll, const Offset(0, 250));
                  await tester.pump();
                }
              },
            );
          },
        );

        testWidgets(
          'MainMenuScreen with expanded collapsible arcade modes on ${vpEntry.key} @ ${scale}x',
          (tester) async {
            final save = SaveManager.instance;
            save.highestLevel = 1;
            save.totalGold = 0;
            save.hasCompletedMainMenuTour = true;

            await runWithOverflowCheck(
              tester,
              size: vpEntry.value,
              textScale: scale,
              scenarioDescription: 'MainMenuScreen (Expanded Arcade Modes) on ${vpEntry.key} scale ${scale}x',
              child: const MainMenuScreen(),
              interaction: () async {
                final menuScroll = find.byType(SingleChildScrollView);
                if (menuScroll.evaluate().isNotEmpty) {
                  await tester.drag(menuScroll, const Offset(0, -300));
                  await tester.pump();

                  final arcadeToggle = find.byIcon(Icons.sports_esports_rounded);
                  if (arcadeToggle.evaluate().isNotEmpty) {
                    await tester.tap(arcadeToggle);
                    await tester.pump();
                    await tester.pump(const Duration(milliseconds: 200));
                  }
                }
              },
            );
          },
        );
      }
    }
  });

  // ===========================================================================
  // GROUP 4: ADVERSARIAL RAPID TAP SPAMMING ON LOCKED CARDS & BUTTONS
  // ===========================================================================
  group('Empirical Challenge: Rapid Tap Spamming Robustness', () {
    testWidgets('Rapid tap spamming on locked Etkinlikler & Lig card does not crash or flood unhandled errors',
        (tester) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final save = SaveManager.instance;
      save.highestLevel = 2; // Locked (< 7)
      save.hasCompletedMainMenuTour = true;

      await tester.pumpWidget(
        const MaterialApp(
          home: MainMenuScreen(),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 150));

      final eventsCard = find.text('ETKİNLİKLER & LİG');
      expect(eventsCard, findsOneWidget);

      // Rapidly spam 25 taps with minimal micro-delays
      for (int i = 0; i < 25; i++) {
        await tester.tap(eventsCard, warnIfMissed: false);
        await tester.pump(const Duration(milliseconds: 10));
      }

      await tester.pump(const Duration(milliseconds: 100));

      // Must display feedback snackbar cleanly
      expect(find.text('Etkinlikler ve Lig Bölüm 7 seviyesinde açılır.'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('Rapid tap spamming across locked bottom dock tabs (Shop, Aquarium, Workshop)',
        (tester) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final save = SaveManager.instance;
      save.highestLevel = 1; // All locked
      save.totalGold = 0;
      save.hasCompletedMainMenuTour = true;

      await tester.pumpWidget(
        const MaterialApp(
          home: MainMenuScreen(),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 150));

      final shopTab = find.text(I18n.tr('shop'));
      final aquariumTab = find.text(I18n.tr('aquarium')).first;
      final workshopTab = find.text(I18n.tr('upgrades')).first;

      // Spam round-robin across locked tabs 10 cycles (30 total taps)
      for (int i = 0; i < 10; i++) {
        await tester.tap(shopTab, warnIfMissed: false);
        await tester.pump(const Duration(milliseconds: 5));
        await tester.tap(aquariumTab, warnIfMissed: false);
        await tester.pump(const Duration(milliseconds: 5));
        await tester.tap(workshopTab, warnIfMissed: false);
        await tester.pump(const Duration(milliseconds: 5));
      }

      await tester.pump(const Duration(milliseconds: 200));

      // UI remains fully functional and intact
      expect(find.byType(MainMenuScreen), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('Rapid tap spamming on locked Fortune Wheel button in top rewards bar',
        (tester) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final save = SaveManager.instance;
      save.highestLevel = 1;
      save.totalGold = 0;
      save.hasCompletedMainMenuTour = true;

      await tester.pumpWidget(
        const MaterialApp(
          home: MainMenuScreen(),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 150));

      final wheelBtn = find.text('ÇARK');
      expect(wheelBtn, findsOneWidget);

      for (int i = 0; i < 20; i++) {
        await tester.tap(wheelBtn, warnIfMissed: false);
        await tester.pump(const Duration(milliseconds: 10));
      }

      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text('Bu özellik Bölüm 2 seviyesinde açılır.'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('Rapid dual-tab switching spam in TournamentDialog',
        (tester) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final save = SaveManager.instance;
      save.highestLevel = 10;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (ctx) => ElevatedButton(
                onPressed: () => TournamentDialog.show(ctx, save: save),
                child: const Text('OPEN'),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.tap(find.text('OPEN'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(seconds: 1));

      final leagueTab = find.text('HAFTALIK LİG');
      final questsTab = find.text('GÜNLÜK GÖREVLER');

      // Rapidly toggle back and forth 15 times (30 tab changes)
      for (int i = 0; i < 15; i++) {
        await tester.tap(questsTab);
        await tester.pump(const Duration(milliseconds: 15));
        await tester.tap(leagueTab);
        await tester.pump(const Duration(milliseconds: 15));
      }

      await tester.pump(const Duration(milliseconds: 200));

      expect(find.text('HAFTALIK LİG ŞAMPİYONASI'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('Rapid open & close cycles of SettingsDialog',
        (tester) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final save = SaveManager.instance;
      save.highestLevel = 10;
      save.hasCompletedMainMenuTour = true;

      await tester.pumpWidget(
        const MaterialApp(
          home: MainMenuScreen(),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 150));

      // Rapid open and close 5 cycles
      for (int i = 0; i < 5; i++) {
        final gearIcon = find.byIcon(Icons.settings_rounded).first;
        await tester.tap(gearIcon);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 200));

        final closeIcon = find.byIcon(Icons.close_rounded);
        expect(closeIcon, findsOneWidget);
        await tester.tap(closeIcon);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 200));
      }

      expect(find.byType(AlertDialog), findsNothing);
      expect(tester.takeException(), isNull);
    });
  });
}
