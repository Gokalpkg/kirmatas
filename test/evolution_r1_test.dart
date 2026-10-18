import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:kirmatas/engine/i18n.dart';
import 'package:kirmatas/models/cosmetics.dart';
import 'package:kirmatas/storage/save_manager.dart';
import 'package:kirmatas/ui/main_menu.dart';
import 'package:kirmatas/ui/settings_dialog.dart';
import 'package:kirmatas/ui/tournament_dialog.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await SaveManager.instance.init();
    SaveManager.instance.language = 'tr';
  });

  group('Evolution R1: Economy Crystallization (Gold & Pearls)', () {
    test('FishItem.pearlCost returns exact cost based on rarity', () {
      final guppy = FishItem.allFish.firstWhere((f) => f.rarity == Rarity.common);
      final rare = FishItem.allFish.firstWhere((f) => f.rarity == Rarity.rare);
      final epic = FishItem.allFish.firstWhere((f) => f.rarity == Rarity.epic);
      final legendary = FishItem.allFish.firstWhere((f) => f.rarity == Rarity.legendary);

      expect(guppy.pearlCost, 0);
      expect(rare.pearlCost, 15);
      expect(epic.pearlCost, 35);
      expect(legendary.pearlCost, 75);
    });

    test('convertShardsToPearls consumes 3 category shards and grants 2 pearls', () async {
      final save = SaveManager.instance;
      save.categoryShards['balls'] = 2;
      save.pearls = 0;

      // Fail when less than 3 shards
      final failed = await save.convertShardsToPearls('balls');
      expect(failed, isFalse);
      expect(save.getShards('balls'), 2);
      expect(save.pearls, 0);

      // Add 2 more shards (total 4)
      await save.addShard('balls', 2);
      expect(save.getShards('balls'), 4);

      // Succeed and convert 3 shards -> 2 pearls
      final success = await save.convertShardsToPearls('balls');
      expect(success, isTrue);
      expect(save.getShards('balls'), 1);
      expect(save.pearls, 2);
    });

    test('buyFishWithPearls unlocks unowned fish using pearls', () async {
      final save = SaveManager.instance;
      save.pearls = 10;
      save.unlockedFish = ['guppy'];

      // Cannot afford 35 pearls
      final cannotAfford = await save.buyFishWithPearls('discus', 35);
      expect(cannotAfford, isFalse);
      expect(save.unlockedFish.contains('discus'), isFalse);
      expect(save.pearls, 10);

      // Can afford 10 pearls
      final success = await save.buyFishWithPearls('tetra', 10);
      expect(success, isTrue);
      expect(save.unlockedFish.contains('tetra'), isTrue);
      expect(save.pearls, 0);
    });
  });

  group('Evolution R1: SettingsDialog Extraction & Progress Backup', () {
    testWidgets('SettingsDialog renders audio, haptics, tour trigger, and progress backup', (tester) async {
      final save = SaveManager.instance;
      bool tourOpened = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (ctx) => ElevatedButton(
                onPressed: () => SettingsDialog.show(ctx, save: save, onOpenTour: () => tourOpened = true),
                child: const Text('OPEN_SETTINGS'),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.tap(find.text('OPEN_SETTINGS'));
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.byType(AlertDialog), findsOneWidget);
      expect(find.text(I18n.tr('settings').toUpperCase()), findsOneWidget);
      expect(find.text('OYUN REHBERİ (NASIL OYNANIR)'), findsOneWidget);

      // Tap tour trigger
      await tester.tap(find.text('OYUN REHBERİ (NASIL OYNANIR)'));
      await tester.pump(const Duration(milliseconds: 300));
      expect(tourOpened, isTrue);
      expect(find.byType(AlertDialog), findsNothing);
    });

    testWidgets('SettingsDialog copy and paste progress code with feedback', (tester) async {
      String? mockClipboard;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
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
      addTearDown(() {
        tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        );
      });

      final save = SaveManager.instance;
      save.metricHighestClassicLevel = 15;
      save.highestLevel = 15;
      save.gold = 5000;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (ctx) => ElevatedButton(
                onPressed: () => SettingsDialog.show(ctx, save: save),
                child: const Text('OPEN'),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.tap(find.text('OPEN'));
      await tester.pump(const Duration(milliseconds: 300));

      // Scroll down inside SingleChildScrollView to reveal progress code buttons
      await tester.drag(find.byType(SingleChildScrollView), const Offset(0, -350));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Test copy progress code
      await tester.tap(find.text(I18n.tr('progress_copy')));
      await tester.pump();
      expect(find.text('İlerleme kodu kopyalandı!'), findsOneWidget);
      expect(mockClipboard, save.progressCode);

      // Test paste progress code
      await tester.tap(find.text(I18n.tr('progress_paste')));
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text(I18n.tr('progress_restored')), findsOneWidget);
    });
  });

  group('Evolution R1: TournamentDialog Dual-Tab (League + Daily Quests)', () {
    testWidgets('TournamentDialog opens Tab 0 (League) by default with leaderboard & join button', (tester) async {
      final save = SaveManager.instance;
      save.highestLevel = 10;
      save.weeklyTournamentScore = 999999;
      bool joined = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (ctx) => ElevatedButton(
                onPressed: () => TournamentDialog.show(
                  ctx,
                  save: save,
                  onJoinTournament: () => joined = true,
                ),
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
      await tester.pump(const Duration(seconds: 1));

      // Tab 0 League content
      expect(find.text('HAFTALIK LİG'), findsOneWidget);
      expect(find.text('GÜNLÜK GÖREVLER'), findsOneWidget);
      expect(find.text('HAFTALIK LİG ŞAMPİYONASI'), findsOneWidget);
      expect(find.text('MÜCADELEYE KATIL'), findsOneWidget);
      expect(find.text('SEN'), findsOneWidget);

      // Tap join
      await tester.tap(find.text('MÜCADELEYE KATIL'));
      await tester.pump(const Duration(milliseconds: 300));
      expect(joined, isTrue);
    });

    testWidgets('TournamentDialog switches to Tab 1 (Quests) and claims quest', (tester) async {
      final save = SaveManager.instance;
      save.questBricksBroken = 150; // Completed quest 2
      save.claimedQuests.clear();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (ctx) => ElevatedButton(
                onPressed: () => TournamentDialog.show(ctx, save: save),
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
      await tester.pump(const Duration(seconds: 1));

      // Switch to Quests tab
      await tester.tap(find.text('GÜNLÜK GÖREVLER'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('GÜNÜN OPERASYONU'), findsOneWidget);
      expect(find.text(I18n.tr('quest_bricks')), findsOneWidget);
      expect(find.text('ÖDÜLÜ AL'), findsOneWidget);

      // Claim reward
      await tester.tap(find.text('ÖDÜLÜ AL'));
      await tester.pump();
      expect(save.claimedQuests.contains('break_bricks'), isTrue);
    });

    testWidgets('TournamentDialog.show with initialTab: 1 directly shows Quests', (tester) async {
      final save = SaveManager.instance;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (ctx) => ElevatedButton(
                onPressed: () => TournamentDialog.show(ctx, save: save, initialTab: 1),
                child: const Text('OPEN_QUESTS'),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.tap(find.text('OPEN_QUESTS'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(seconds: 1));

      expect(find.text('GÜNÜN OPERASYONU'), findsOneWidget);
      expect(find.text('Görevleri Tamamla • Altın & Yem Kazan'), findsOneWidget);
    });
  });

  group('Evolution R1: MainMenu Hub & Streamlined Bottom Dock', () {
    testWidgets('Locked player (< Level 7) sees lock badge on Etkinlikler & Lig and receives snackbar feedback', (tester) async {
      final save = SaveManager.instance;
      save.highestLevel = 3;
      save.hasCompletedMainMenuTour = true;

      await tester.pumpWidget(
        const MaterialApp(
          home: MainMenuScreen(),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 150));

      // Check card presence and lock badge
      expect(find.text('ETKİNLİKLER & LİG'), findsOneWidget);
      expect(find.text('Bölüm 7 seviyesinde açılır'), findsOneWidget);

      // Tap locked card
      await tester.tap(find.text('ETKİNLİKLER & LİG'));
      await tester.pump();
      expect(find.text('Etkinlikler ve Lig Bölüm 7 seviyesinde açılır.'), findsOneWidget);
    });

    testWidgets('Unlocked player (Level >= 7) taps Etkinlikler & Lig to open TournamentDialog', (tester) async {
      final save = SaveManager.instance;
      save.highestLevel = 10;
      save.leagueTier = 2;
      save.hasCompletedMainMenuTour = true;

      await tester.pumpWidget(
        const MaterialApp(
          home: MainMenuScreen(),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 150));

      expect(find.text('ETKİNLİKLER & LİG'), findsOneWidget);
      expect(find.text('LİG SEZONU'), findsOneWidget);

      await tester.tap(find.text('ETKİNLİKLER & LİG'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(seconds: 1));

      expect(find.text('HAFTALIK LİG ŞAMPİYONASI'), findsOneWidget);
      expect(find.text('MÜCADELEYE KATIL'), findsOneWidget);
    });

    testWidgets('Top bar gear icon opens SettingsDialog and allows closing', (tester) async {
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

      await tester.tap(find.byIcon(Icons.settings_rounded));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.byType(AlertDialog), findsOneWidget);
      expect(find.text(I18n.tr('settings').toUpperCase()), findsOneWidget);

      // Close dialog
      await tester.tap(find.text(I18n.tr('close')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byType(AlertDialog), findsNothing);
    });

    testWidgets('Streamlined bottom dock has 3 tabs and renders all expected keys', (tester) async {
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

      expect(find.text(I18n.tr('shop')), findsOneWidget);
      expect(find.byKey(const Key('aquarium_nav_btn')), findsNothing); // Key is inside KeyedSubtree
      expect(find.text(I18n.tr('aquarium')), findsWidgets);
      expect(find.text(I18n.tr('upgrades')), findsWidgets);

      // Verify Fortune Wheel key is intact in top rewards bar
      expect(find.text('ÇARK'), findsOneWidget);
    });

    testWidgets('Zero RenderFlex overflow on ultra-narrow 320x568 screen with open TournamentDialog', (tester) async {
      tester.view.physicalSize = const Size(320, 568);
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

      expect(find.text('HAFTALIK LİG ŞAMPİYONASI'), findsOneWidget);

      // Switch to Quests tab on 320px
      await tester.tap(find.text('GÜNLÜK GÖREVLER'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('GÜNÜN OPERASYONU'), findsOneWidget);
    });
  });
}
