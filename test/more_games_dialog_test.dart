import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kirmatas/engine/i18n.dart';
import 'package:kirmatas/storage/save_manager.dart';
import 'package:kirmatas/ui/main_menu.dart';
import 'package:kirmatas/ui/more_games_dialog.dart';
import 'package:kirmatas/ui/settings_dialog.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await SaveManager.instance.init();
  });

  group('MoreGamesDialog Model & Constants Verification', () {
    test('Features exactly the 4 active Kaunos Games production titles', () {
      expect(MoreGamesDialog.games.length, equals(4));

      final ids = MoreGamesDialog.games.map((g) => g.id).toList();
      expect(ids, containsAll(['kirmatas', 'planetmatch', 'blockfreeze', 'neonspace']));

      final titles = MoreGamesDialog.games.map((g) => g.title).toList();
      expect(titles, containsAll(['Kırmataş', 'Planet Match', 'Block Freeze', 'Neon Space']));

      final packages = MoreGamesDialog.games.map((g) => g.packageName).toList();
      expect(packages, containsAll([
        'com.kaunos.kirmatas',
        'com.kaunos.planetmatch',
        'com.kaunos.blockfreeze',
        'com.kaunos.neonspace',
      ]));
    });

    test('Kırmataş is uniquely marked as currently playing', () {
      final currentGames = MoreGamesDialog.games.where((g) => g.isCurrent).toList();
      expect(currentGames.length, equals(1));
      expect(currentGames.first.id, equals('kirmatas'));
      expect(currentGames.first.title, equals('Kırmataş'));
    });

    test('Store launcher handles package names and empty query safely without throwing', () async {
      expect(
        () async => await MoreGamesDialog.launchGameStore('com.kaunos.planetmatch'),
        returnsNormally,
      );
      expect(
        () async => await MoreGamesDialog.launchGameStore(''),
        returnsNormally,
      );
    });
  });

  group('MoreGamesDialog UI & Localization Tests', () {
    testWidgets('Renders modal dialog with 4 games, active badge, and install buttons in TR', (tester) async {
      SaveManager.instance.setLanguage('tr');

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () => MoreGamesDialog.show(context),
              child: const Text('OPEN'),
            ),
          ),
        ),
      );

      await tester.tap(find.text('OPEN'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));

      expect(find.byType(MoreGamesDialog), findsOneWidget);
      expect(find.text(I18n.tr('more_games').toUpperCase()), findsOneWidget);
      expect(find.text(I18n.tr('more_games_subtitle')), findsOneWidget);

      // Verify all 4 game titles
      expect(find.text('Kırmataş'), findsOneWidget);
      expect(find.text('Planet Match'), findsOneWidget);
      expect(find.text('Block Freeze'), findsOneWidget);
      expect(find.text('Neon Space'), findsOneWidget);

      // Verify Kırmataş currently playing badge
      expect(find.text('Şu An Oynanıyor'), findsOneWidget);

      // Verify 3 Install/Play buttons for other games
      expect(find.text('Yükle / Oyna'), findsNWidgets(3));

      // Verify footer button
      expect(find.text('Tüm Oyunlarımızı Gör'), findsOneWidget);

      // Close dialog
      await tester.tap(find.byIcon(Icons.close_rounded));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));
      expect(find.byType(MoreGamesDialog), findsNothing);
    });

    testWidgets('Renders localized strings correctly in English', (tester) async {
      SaveManager.instance.setLanguage('en');

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () => MoreGamesDialog.show(context),
              child: const Text('OPEN'),
            ),
          ),
        ),
      );

      await tester.tap(find.text('OPEN'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));

      expect(find.text('OTHER GAMES'), findsOneWidget);
      expect(find.text('Kaunos Games Universe'), findsOneWidget);
      expect(find.text('Playing Now'), findsOneWidget);
      expect(find.text('Install / Play'), findsNWidgets(3));
      expect(find.text('View All Games'), findsOneWidget);
    });
  });

  group('Main Menu Header Integration Tests', () {
    testWidgets('Header bar contains esports icon and opens MoreGamesDialog on tap', (tester) async {
      final save = SaveManager.instance;
      save.highestLevel = 5;
      save.hasCompletedMainMenuTour = true;

      await tester.pumpWidget(
        const MaterialApp(
          home: MainMenuScreen(),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      // Find the esports button in header
      final esportsButton = find.byKey(const Key('btn_more_games_header'));
      expect(esportsButton, findsOneWidget);

      // Tap esports button
      await tester.tap(esportsButton);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));

      // MoreGamesDialog appears
      expect(find.byType(MoreGamesDialog), findsOneWidget);
      expect(find.text('Kırmataş'), findsOneWidget);
      expect(find.text('Planet Match'), findsOneWidget);
    });

    testWidgets('Responsive header layout test on narrow 320px screen without crate', (tester) async {
      tester.view.physicalSize = const Size(320 * 2, 568 * 2);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final save = SaveManager.instance;
      save.highestLevel = 10;
      save.hasCompletedMainMenuTour = true;
      save.pendingCrate = null;

      await tester.pumpWidget(
        const MaterialApp(
          home: MainMenuScreen(),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      expect(tester.takeException(), isNull);
      expect(find.byKey(const Key('btn_settings_header')), findsOneWidget);
      expect(find.byKey(const Key('btn_more_games_header')), findsOneWidget);
    });

    testWidgets('Responsive header layout test on narrow 320px screen WITH pending crate', (tester) async {
      tester.view.physicalSize = const Size(320 * 2, 568 * 2);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final save = SaveManager.instance;
      save.highestLevel = 10;
      save.hasCompletedMainMenuTour = true;
      save.pendingCrate = PendingCrate(
        crateType: 'chest',
        rewardType: 'gold',
        rewardId: 'gold_pack',
        rewardTitle: 'Gold Pack',
        rewardSubtitle: '500 Gold',
        rarityIndex: 1,
      );

      await tester.pumpWidget(
        const MaterialApp(
          home: MainMenuScreen(),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      // Ensure no overflow occurred on 320px width even with settings + esports + crate + title + gold
      expect(tester.takeException(), isNull);
      expect(find.byKey(const Key('btn_settings_header')), findsOneWidget);
      expect(find.byKey(const Key('btn_more_games_header')), findsOneWidget);
      expect(find.byIcon(Icons.inventory_2_rounded), findsOneWidget);
    });
  });

  group('Settings Dialog Shortcut Integration Tests', () {
    testWidgets('Settings dialog contains More Games row and opens MoreGamesDialog on tap', (tester) async {
      SaveManager.instance.setLanguage('tr');

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () => SettingsDialog.show(context),
              child: const Text('OPEN_SETTINGS'),
            ),
          ),
        ),
      );

      await tester.tap(find.text('OPEN_SETTINGS'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));

      expect(find.byType(SettingsDialog), findsOneWidget);

      // Verify the More Games shortcut button text in settings
      final moreGamesShortcut = find.text('DİĞER OYUNLARIMIZ (KAUNOS GAMES)');
      expect(moreGamesShortcut, findsOneWidget);

      // Tap the shortcut button
      await tester.tap(moreGamesShortcut);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));

      // Settings dialog was popped and MoreGamesDialog opened
      expect(find.byType(SettingsDialog), findsNothing);
      expect(find.byType(MoreGamesDialog), findsOneWidget);
      expect(find.text('Planet Match'), findsOneWidget);
    });
  });
}
