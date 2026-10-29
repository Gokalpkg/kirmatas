import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kirmatas/storage/save_manager.dart';
import 'package:kirmatas/ui/main_menu.dart';
import 'package:kirmatas/ui/main_menu_tour_overlay.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('MainMenu FTUE Onboarding Tour Tests', () {
    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      await SaveManager.instance.init();
    });

    testWidgets('Fresh Level 1 player: Tour overlay appears automatically on launch', (tester) async {
      final save = SaveManager.instance;
      save.highestLevel = 1;
      save.totalGold = 0;
      save.hasCompletedMainMenuTour = false;

      await tester.pumpWidget(
        const MaterialApp(
          home: MainMenuScreen(),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Tour overlay is visible
      expect(find.byType(MainMenuTourOverlay), findsOneWidget);
      expect(find.text('KIRMATAS DÜNYASINA\nHOŞ GELDİN!'), findsOneWidget);
      expect(find.text('HIZLI TURU BAŞLAT'), findsOneWidget);

      // Start the tour
      await tester.tap(find.text('HIZLI TURU BAŞLAT'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Step 1: OYNA
      expect(find.text('ADIM 1 / 4'), findsOneWidget);
      expect(find.text('OYNA (Klasik Macera)'), findsOneWidget);

      // Step 2: Yükseltmeler
      await tester.tap(find.text('SONRAKİ'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text('ADIM 2 / 4'), findsOneWidget);
      expect(find.text('Atölye & Yükseltmeler'), findsOneWidget);

      // Step 3: Akvaryum
      await tester.tap(find.text('SONRAKİ'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text('ADIM 3 / 4'), findsOneWidget);
      expect(find.text('Kaunos Akvaryumu (Bölüm 5)'), findsOneWidget);

      // Step 4: Çark & Görevler
      await tester.tap(find.text('SONRAKİ'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text('ADIM 4 / 4'), findsOneWidget);
      expect(find.text('Şans Çarkı ve Görevler'), findsOneWidget);
      expect(find.descendant(of: find.byType(MainMenuTourOverlay), matching: find.text('MACERAYA BAŞLA!')), findsOneWidget);

      // Finish tour
      await tester.tap(find.descendant(of: find.byType(MainMenuTourOverlay), matching: find.text('MACERAYA BAŞLA!')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Overlay dismissed, tour marked completed in save
      expect(find.byType(MainMenuTourOverlay), findsNothing);
      expect(save.hasCompletedMainMenuTour, isTrue);
    });

    testWidgets('Tour can be skipped directly from welcome card', (tester) async {
      final save = SaveManager.instance;
      save.highestLevel = 1;
      save.totalGold = 0;
      save.hasCompletedMainMenuTour = false;

      await tester.pumpWidget(
        const MaterialApp(
          home: MainMenuScreen(),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byType(MainMenuTourOverlay), findsOneWidget);

      // Tap ATLA
      await tester.tap(find.text('ATLA (Biliyorum)'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byType(MainMenuTourOverlay), findsNothing);
      expect(save.hasCompletedMainMenuTour, isTrue);
    });

    testWidgets('Settings dialog allows manually re-triggering the tour anytime', (tester) async {
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
      await tester.pump(const Duration(milliseconds: 100));

      // Tour should NOT appear automatically since hasCompletedMainMenuTour is true
      expect(find.byType(MainMenuTourOverlay), findsNothing);

      // Open settings
      final settingsIcon = find.byIcon(Icons.settings_rounded);
      expect(settingsIcon, findsOneWidget);
      await tester.tap(settingsIcon);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      // Debug: print dialog widgets
      final alertDialog = find.byType(AlertDialog);
      expect(alertDialog, findsOneWidget);

      final guideButton = find.text('OYUN REHBERİ (NASIL OYNANIR)');
      expect(guideButton, findsOneWidget);

      // Tap guide button
      await tester.tap(guideButton);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      // Tour is now launched!
      expect(find.byType(MainMenuTourOverlay), findsOneWidget);
    });
  });
}
