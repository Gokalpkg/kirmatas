import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kirmatas/engine/game_controller.dart';
import 'package:kirmatas/models/game_state.dart';
import 'package:kirmatas/storage/save_manager.dart';
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

  group('Reviewer 2 Stress Tests: UI Layout & Overflow on Narrow Screens', () {
    testWidgets('UpgradesView layout on narrow screens (360x780, 320x568)', (tester) async {
      SharedPreferences.setMockInitialValues({});
      final save = SaveManager.instance;
      await save.init();
      save.gold = 999999;
      save.pearls = 9999;
      save.cosmicGoldMasteryLevel = 99;
      save.cosmicPearlMasteryLevel = 99;

      for (final size in [const Size(390, 844), const Size(360, 780), const Size(320, 568)]) {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1.0;

        await tester.pumpWidget(
          const MaterialApp(
            home: UpgradesView(),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        // Scroll to bottom to ensure Cosmic Mastery is rendered and layout checked
        final scrollable = find.byType(Scrollable);
        if (scrollable.evaluate().isNotEmpty) {
          await tester.scrollUntilVisible(find.text('KOZMİK USTALIK (SONSUZ SEVİYE)'), 300, scrollable: scrollable.first);
          await tester.pump();
        }

        final err = tester.takeException();
        if (err != null) {
          debugPrint('>>> UPGRADES VIEW ERROR AT $size: $err');
        }
        expect(err, isNull, reason: 'Overflow occurred on UpgradesView at $size');
      }
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
      // Finding 2: UpgradesView Cosmic Mastery header and cards overflow on narrow viewports (lines 498, 546, 635)
    });

    testWidgets('SectorMapView layout with Prestige Omega Card on narrow screens', (tester) async {
      SharedPreferences.setMockInitialValues({});
      final save = SaveManager.instance;
      await save.init();
      save.highestLevel = 250;

      for (final size in [const Size(390, 844), const Size(360, 780), const Size(320, 568)]) {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1.0;

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SectorMapView(save: save),
            ),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        await tester.scrollUntilVisible(find.text('PRESTİJ SEKTÖR OMEGA'), 400);
        await tester.pump();

        expect(tester.takeException(), isNull, reason: 'Overflow occurred on SectorMapView at $size');
      }
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    testWidgets('TournamentDialog layout on narrow screens', (tester) async {
      SharedPreferences.setMockInitialValues({});
      final save = SaveManager.instance;
      await save.init();
      save.leagueTier = 4;
      save.weeklyTournamentScore = 125000;

      for (final size in [const Size(390, 844), const Size(360, 780), const Size(320, 568)]) {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1.0;

        FlutterErrorDetails? caughtDetails;
        final origOnError = FlutterError.onError;
        FlutterError.onError = (details) {
          caughtDetails = details;
          origOnError?.call(details);
        };

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => ElevatedButton(
                  onPressed: () => TournamentDialog.show(context, save: save),
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

        FlutterError.onError = origOnError;
        if (caughtDetails != null) {
          debugPrint('>>> FULL ERROR DETAILS: ${caughtDetails?.exceptionAsString()}');
          debugPrint('>>> INFORMATION COLLECTOR: ${caughtDetails?.informationCollector?.call().map((e) => e.toString()).join('\n')}');
        }

        final err = tester.takeException();
        if (err != null) {
          debugPrint('>>> TOURNAMENT DIALOG ERROR AT $size: $err');
        }
        expect(err, isNull, reason: 'Overflow occurred on TournamentDialog at $size');

        // Close dialog
        await tester.tap(find.byIcon(Icons.close_rounded));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));
      }
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
      // Finding 3: TournamentDialog overflows bottom by 104px on 320x568 small screen
    });

    testWidgets('MainMenu profile header and arcade cards on narrow screens', (tester) async {
      SharedPreferences.setMockInitialValues({});
      final save = SaveManager.instance;
      await save.init();
      save.highestLevel = 10;
      save.leagueTier = 3;

      for (final size in [const Size(390, 844), const Size(360, 780), const Size(320, 568)]) {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1.0;

        await tester.pumpWidget(
          const MaterialApp(
            home: MainMenuScreen(),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        expect(tester.takeException(), isNull, reason: 'Overflow occurred on MainMenu at $size');
        await tester.pump(const Duration(seconds: 1));
      }
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
      // Finding 1: MainMenu top bar overflows right by 64px on narrow mobile viewports
    });
  });

  group('Reviewer 2 Stress Tests: Boundary Conditions & Edge Cases', () {
    test('Prestige Tier formula boundaries (1 to 1000)', () {
      expect(SaveManager.calculatePrestigeTier(-10), 0);
      expect(SaveManager.calculatePrestigeTier(0), 0);
      expect(SaveManager.calculatePrestigeTier(1), 0);
      expect(SaveManager.calculatePrestigeTier(237), 0);
      expect(SaveManager.calculatePrestigeTier(238), 0);
      expect(SaveManager.calculatePrestigeTier(239), 1);
      expect(SaveManager.calculatePrestigeTier(255), 1);
      expect(SaveManager.calculatePrestigeTier(256), 2);
      expect(SaveManager.calculatePrestigeTier(272), 2);
      expect(SaveManager.calculatePrestigeTier(273), 3);
      expect(SaveManager.calculatePrestigeTier(289), 3);
      expect(SaveManager.calculatePrestigeTier(290), 4);
      // Large level
      expect(SaveManager.calculatePrestigeTier(1000), ((1000 - 239) ~/ 17) + 1);
    });

    test('Cosmic Mastery extreme values, clamping, and zero-checks', () async {
      SharedPreferences.setMockInitialValues({});
      final save = SaveManager.instance;
      await save.init();

      // Zero and negative adds
      save.pearls = 10;
      save.addPearls(0);
      expect(save.pearls, 10);
      save.addPearls(-5);
      expect(save.pearls, 10);

      expect(save.spendPearls(0), true);
      expect(save.spendPearls(-10), true);
      expect(save.pearls, 10);

      // Exact cost spend
      expect(save.spendPearls(10), true);
      expect(save.pearls, 0);

      // Insufficient spend
      expect(save.spendPearls(1), false);
      expect(save.pearls, 0);

      // Upgrade costs with high levels
      save.cosmicGoldMasteryLevel = 100;
      expect(save.cosmicGoldMasteryCost, 1000 + 100 * 500); // 51000
      save.cosmicPearlMasteryLevel = 50;
      expect(save.cosmicPearlMasteryCost, 5 + 50 * 3); // 155

      // Controller stat scaling at high levels
      final ctrl = GameController();
      expect(ctrl.cosmicGoldDamageMultiplier, closeTo(3.0, 0.001));
      expect(ctrl.cosmicGoldRewardMultiplier, closeTo(3.0, 0.001));
      expect(ctrl.cosmicPearlUltiMultiplier, closeTo(2.0, 0.001));
      expect(ctrl.cosmicPearlLuckBonus, closeTo(0.50, 0.001));
    });

    test('Daily Blitz date formatting across year/month/day boundaries', () {
      expect(SaveManager.formatDailyDate(DateTime(2026, 1, 1)), '2026-01-01');
      expect(SaveManager.formatDailyDate(DateTime(2026, 12, 31)), '2026-12-31');
      expect(SaveManager.formatDailyDate(DateTime(2028, 2, 29)), '2028-02-29'); // Leap year
      expect(SaveManager.formatDailyDate(DateTime(2030, 9, 9)), '2030-09-09');
    });

    test('League rivals ranking integrity across all 5 tiers and scores', () async {
      SharedPreferences.setMockInitialValues({});
      final save = SaveManager.instance;
      await save.init();

      for (int tier = 0; tier <= 4; tier++) {
        save.leagueTier = tier;
        // Test with 0 score, medium score, ultra-high score
        for (final playerScore in [0, 5000, 1000000]) {
          save.weeklyTournamentScore = playerScore;
          final rivals = save.getLeagueRivals();

          expect(rivals.length, 15, reason: 'Must have exactly 15 rivals at tier $tier');
          final playerList = rivals.where((r) => r.isPlayer).toList();
          expect(playerList.length, 1, reason: 'Must have exactly 1 player');
          expect(playerList.first.score, playerScore);

          // Verify strict descending order
          for (int i = 0; i < rivals.length - 1; i++) {
            expect(rivals[i].score >= rivals[i + 1].score, true,
                reason: 'Scores must be descending at index $i (tier $tier, score $playerScore)');
            expect(rivals[i].rank, i + 1, reason: 'Ranks must be 1..15 sequentially');
          }
          expect(rivals.last.rank, 15);
        }
      }
    });

    test('Progression past level 238 in Classic Mode: bricks HP, prestige scaling, victory check', () {
      final ctrl = GameController();
      // Level 238 victory condition
      ctrl.startNewGame(GameMode.classic, explicitStartLevel: 238);
      expect(ctrl.level, 238);
      expect(ctrl.prestigeTier, 0);

      // Level 239 prestige tier 1
      ctrl.startNewGame(GameMode.classic, explicitStartLevel: 239);
      expect(ctrl.level, 239);
      expect(ctrl.prestigeTier, 1);
      expect(ctrl.prestigeGoldMultiplier, closeTo(1.20, 0.001));

      // Level 256 prestige tier 2
      ctrl.startNewGame(GameMode.classic, explicitStartLevel: 256);
      expect(ctrl.level, 256);
      expect(ctrl.prestigeTier, 2);
      expect(ctrl.prestigeGoldMultiplier, closeTo(1.40, 0.001));

      // Level 273 prestige tier 3
      ctrl.startNewGame(GameMode.classic, explicitStartLevel: 273);
      expect(ctrl.level, 273);
      expect(ctrl.prestigeTier, 3);
      expect(ctrl.prestigeGoldMultiplier, closeTo(1.60, 0.001));
    });
  });
}
