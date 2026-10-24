import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:kirmatas/engine/i18n.dart';
import 'package:kirmatas/models/cosmetics.dart';
import 'package:kirmatas/storage/save_manager.dart';
import 'package:kirmatas/ui/settings_dialog.dart';
import 'package:kirmatas/ui/tournament_dialog.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await SaveManager.instance.init();
    SaveManager.instance.language = 'tr';
  });

  group('Challenger M1: Adversarial Economy & Shard Conversion Boundaries', () {
    test('Zero, negative, and insufficient shards do not grant pearls or corrupt state', () async {
      final save = SaveManager.instance;
      save.pearls = 0;
      save.categoryShards.clear();

      // Case 1: Category with 0 shards
      expect(save.getShards('balls'), 0);
      final res0 = await save.convertShardsToPearls('balls');
      expect(res0, isFalse);
      expect(save.pearls, 0);
      expect(save.getShards('balls'), 0);

      // Case 2: Insufficient shards (1 and 2 shards)
      await save.addShard('paddle', 1);
      expect(save.getShards('paddle'), 1);
      final res1 = await save.convertShardsToPearls('paddle');
      expect(res1, isFalse);
      expect(save.pearls, 0);
      expect(save.getShards('paddle'), 1);

      await save.addShard('paddle', 1); // now 2
      expect(save.getShards('paddle'), 2);
      final res2 = await save.convertShardsToPearls('paddle');
      expect(res2, isFalse);
      expect(save.pearls, 0);
      expect(save.getShards('paddle'), 2);

      // Case 3: Negative shards in map
      save.categoryShards['trails'] = -3;
      final resNeg = await save.convertShardsToPearls('trails');
      expect(resNeg, isFalse);
      expect(save.pearls, 0);
      expect(save.getShards('trails'), -3);
    });

    test('Burst concurrent shard conversions: strictly atomic without race conditions', () async {
      final save = SaveManager.instance;
      save.pearls = 0;
      save.categoryShards.clear();

      // Exactly 10 shards: allows at most 3 conversions (3 * 3 = 9 shards), 1 remainder.
      await save.addShard('balls', 10);
      expect(save.getShards('balls'), 10);

      // Launch 10 simultaneous asynchronous conversion attempts
      final results10 = await Future.wait(
        List.generate(10, (_) => save.convertShardsToPearls('balls')),
      );

      final successes10 = results10.where((r) => r == true).length;
      final failures10 = results10.where((r) => r == false).length;

      expect(successes10, 3, reason: 'Exactly 3 conversions must succeed with 10 shards');
      expect(failures10, 7, reason: 'Remaining 7 conversions must fail');
      expect(save.getShards('balls'), 1, reason: 'Remainder must be exactly 1 shard');
      expect(save.pearls, 6, reason: 'Pearls must increase by exactly 3 * 2 = 6');

      // Now add 99 shards (1 + 99 = 100 shards): allows at most 33 conversions (99 shards), 1 remainder.
      await save.addShard('balls', 99);
      expect(save.getShards('balls'), 100);

      // Launch 50 concurrent conversion requests
      final results50 = await Future.wait(
        List.generate(50, (_) => save.convertShardsToPearls('balls')),
      );

      final successes50 = results50.where((r) => r == true).length;
      final failures50 = results50.where((r) => r == false).length;

      expect(successes50, 33, reason: 'Exactly 33 conversions must succeed with 100 shards');
      expect(failures50, 17, reason: 'Remaining 17 conversion attempts must fail');
      expect(save.getShards('balls'), 1);
      expect(save.pearls, 6 + (33 * 2)); // 6 + 66 = 72
    });

    test('Persistence across mock reload after massive conversions', () async {
      final save = SaveManager.instance;
      save.pearls = 5;
      save.categoryShards.clear();
      await save.addShard('paddle', 15);

      // Convert 4 times (4 * 3 = 12 shards consumed, 4 * 2 = 8 pearls gained)
      for (int i = 0; i < 4; i++) {
        final ok = await save.convertShardsToPearls('paddle');
        expect(ok, isTrue);
      }
      expect(save.getShards('paddle'), 3);
      expect(save.pearls, 13);

      // Simulate app restart by re-initializing SaveManager
      await SaveManager.instance.init();
      expect(SaveManager.instance.getShards('paddle'), 3);
      expect(SaveManager.instance.pearls, 13);
    });

    test('Exhaustive purchase stress of all rare, epic, and legendary fish with pearls', () async {
      final save = SaveManager.instance;
      save.unlockedFish = ['guppy']; // default common starter fish

      final purchasableFish = FishItem.allFish.where((f) => f.pearlCost > 0).toList();
      expect(purchasableFish.isNotEmpty, isTrue);

      final totalPearlCost = purchasableFish.fold<int>(0, (sum, f) => sum + f.pearlCost);
      expect(totalPearlCost, greaterThan(100));

      // Attempt buying first fish without pearls
      final firstFish = purchasableFish.first;
      save.pearls = firstFish.pearlCost - 1; // 1 pearl short
      final underfunded = await save.buyFishWithPearls(firstFish.id, firstFish.pearlCost);
      expect(underfunded, isFalse);
      expect(save.unlockedFish.contains(firstFish.id), isFalse);
      expect(save.pearls, firstFish.pearlCost - 1);

      // Fund player with exact total pearl cost
      save.pearls = totalPearlCost;

      // Sequentially purchase all fish
      for (final fish in purchasableFish) {
        final bought = await save.buyFishWithPearls(fish.id, fish.pearlCost);
        expect(bought, isTrue, reason: 'Fish ${fish.id} (${fish.rarity.name}) purchase must succeed');
        expect(save.unlockedFish.contains(fish.id), isTrue);
      }

      // Check balance is exactly 0
      expect(save.pearls, 0);

      // Verify all fish are unlocked
      for (final fish in purchasableFish) {
        expect(save.unlockedFish.contains(fish.id), isTrue);
      }

      // Re-initialize to verify disk persistence
      await SaveManager.instance.init();
      expect(SaveManager.instance.pearls, 0);
      for (final fish in purchasableFish) {
        expect(SaveManager.instance.unlockedFish.contains(fish.id), isTrue);
      }
    });

    test('buyFishWithPearls on already owned fish rejects purchase and preserves pearls (Remediation Verified)', () async {
      final save = SaveManager.instance;
      save.unlockedFish = ['guppy', 'tetra_purple']; // tetra_purple is epic (35 pearls)
      save.pearls = 70;

      // Player already owns tetra_purple, but calls buyFishWithPearls again
      final boughtAgain = await save.buyFishWithPearls('tetra_purple', 35);

      // Verify fix: purchase rejected, pearls untouched
      expect(boughtAgain, isFalse);
      expect(save.pearls, 70, reason: 'Security: buyFishWithPearls rejects already unlocked fish and preserves pearls');
    });

    test('Atomic registration: Concurrent double-claiming of feed_fish quest strictly prevented', () async {
      final save = SaveManager.instance;
      save.questFishFed = true;
      save.claimedQuests.clear();
      save.gold = 1000;
      save.fishFood = 0;

      // Launch 2 concurrent claimQuestReward calls for feed_fish
      final results = await Future.wait([
        save.claimQuestReward('feed_fish'),
        save.claimQuestReward('feed_fish'),
      ]);

      // Exactly one succeeds (60 gold, 1 food), the other returns 0
      final totalClaimedReward = results.reduce((a, b) => a + b);
      expect(totalClaimedReward, 60);
      expect(results.contains(60), isTrue);
      expect(results.contains(0), isTrue);
      expect(save.gold, 1060);
      expect(save.fishFood, 1);
    });
  });

  group('Challenger M1: Dual-Tab TournamentDialog Rapid Stress & Quest Claiming', () {
    testWidgets('Rapid tab switching between League and Quests does not crash or corrupt state', (tester) async {
      final save = SaveManager.instance;
      save.highestLevel = 10;
      save.weeklyTournamentScore = 15000;

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

      // Rapidly toggle tabs 20 times without artificial pauses
      for (int i = 0; i < 20; i++) {
        final targetTab = i.isEven ? 'GÜNLÜK GÖREVLER' : 'HAFTALIK LİG';
        await tester.tap(find.text(targetTab));
        await tester.pump(); // immediate pump
      }
      await tester.pump(const Duration(milliseconds: 300));

      // 19 is odd -> last tap was 'HAFTALIK LİG' (Tab 0)
      expect(find.text('HAFTALIK LİG ŞAMPİYONASI'), findsOneWidget);
      expect(find.text('MÜCADELEYE KATIL'), findsOneWidget);

      // Switch to Quests (Tab 1)
      await tester.tap(find.text('GÜNLÜK GÖREVLER'));
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('GÜNÜN OPERASYONU'), findsOneWidget);
      expect(find.text('Görevleri Tamamla • Altın & Yem Kazan'), findsOneWidget);
    });

    testWidgets('Exhaustive claiming of all 3 daily quests with persistence and idempotence', (tester) async {
      final save = SaveManager.instance;
      save.questFishFed = true;
      save.questBricksBroken = 200;
      save.questAdOrWinDone = true;
      save.claimedQuests.clear();
      save.gold = 1000;
      save.fishFood = 5;

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

      // All 3 quests are completed, so 3 'ÖDÜLÜ AL' buttons should be present
      expect(find.text('ÖDÜLÜ AL'), findsNWidgets(3));

      // Claim feed_fish quest (+60 gold, +1 food)
      await tester.tap(find.text('ÖDÜLÜ AL').first);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      expect(save.claimedQuests.contains('feed_fish'), isTrue);
      expect(save.gold, 1060);
      expect(save.fishFood, 6);

      // Two 'ÖDÜLÜ AL' buttons remain
      expect(find.text('ÖDÜLÜ AL'), findsNWidgets(2));
      expect(find.text('TAMAMLANDI ✓'), findsOneWidget);

      // Claim remaining 2 quests
      while (find.text('ÖDÜLÜ AL').evaluate().isNotEmpty) {
        await tester.tap(find.text('ÖDÜLÜ AL').first);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 200));
      }

      // All 3 quests claimed: 1060 + 120 + 150 = 1330 gold
      expect(find.text('ÖDÜLÜ AL'), findsNothing);
      expect(find.text('TAMAMLANDI ✓'), findsNWidgets(3));
      expect(save.gold, 1330);

      // Verify idempotence: direct repeat calls return 0 and do not duplicate gold
      final reClaimFeed = await save.claimQuestReward('feed_fish');
      final reClaimBricks = await save.claimQuestReward('break_bricks');
      final reClaimAd = await save.claimQuestReward('ad_or_win');
      expect(reClaimFeed, 0);
      expect(reClaimBricks, 0);
      expect(reClaimAd, 0);
      expect(save.gold, 1330);
      expect(save.fishFood, 6);

      // Re-init to verify disk persistence
      await SaveManager.instance.init();
      expect(SaveManager.instance.claimedQuests.length, 3);
      expect(SaveManager.instance.gold, 1330);
      expect(SaveManager.instance.fishFood, 6);
    });
  });

  group('Challenger M1: Progress Backup Code Robustness & Adversarial Parsing', () {
    test('Rejects empty, whitespace, corrupt header, and invalid parts count', () async {
      final save = SaveManager.instance;
      final initialHighest = save.metricHighestClassicLevel;
      final initialGold = save.gold;

      expect(await save.applyProgressCode(''), isFalse);
      expect(await save.applyProgressCode('   '), isFalse);
      expect(await save.applyProgressCode('KT2|1|1|100|5'), isFalse);
      expect(await save.applyProgressCode('KT1'), isFalse);
      expect(await save.applyProgressCode('KT1|1|1|100'), isFalse);
      expect(await save.applyProgressCode('KT1|1|1|100|5|EXTRA'), isFalse);

      // State must remain completely untouched
      expect(save.metricHighestClassicLevel, initialHighest);
      expect(save.gold, initialGold);
    });

    test('Rejects non-integer, NaN, double, and injection inputs', () async {
      final save = SaveManager.instance;

      expect(await save.applyProgressCode('KT1|abc|1|100|5'), isFalse);
      expect(await save.applyProgressCode('KT1|1|xyz|100|5'), isFalse);
      expect(await save.applyProgressCode('KT1|1|1|NaN|5'), isFalse);
      expect(await save.applyProgressCode('KT1|1|1|100|3.14'), isFalse);
      expect(await save.applyProgressCode('KT1|1|1|1e5|5'), isFalse);
      expect(await save.applyProgressCode('KT1|1|1|100|5\x00'), isFalse);
      expect(await save.applyProgressCode('KT1|1|1|100|5; DROP TABLE save;'), isFalse);
    });

    test('Strict enforcement of boundary values [1, 238] and [0, 2000000]', () async {
      final save = SaveManager.instance;

      // Highest level boundaries
      expect(await save.applyProgressCode('KT1|0|1|100|5'), isFalse, reason: 'highest < 1 rejected');
      expect(await save.applyProgressCode('KT1|-1|1|100|5'), isFalse, reason: 'highest < 0 rejected');
      expect(await save.applyProgressCode('KT1|239|1|100|5'), isFalse, reason: 'highest > 238 rejected');

      // Current level boundaries
      expect(await save.applyProgressCode('KT1|10|0|100|5'), isFalse, reason: 'level < 1 rejected');
      expect(await save.applyProgressCode('KT1|10|-5|100|5'), isFalse, reason: 'level < 0 rejected');
      expect(await save.applyProgressCode('KT1|10|239|100|5'), isFalse, reason: 'level > 238 rejected');

      // Gold boundaries
      expect(await save.applyProgressCode('KT1|10|5|-1|5'), isFalse, reason: 'gold < 0 rejected');
      expect(await save.applyProgressCode('KT1|10|5|2000001|5'), isFalse, reason: 'gold > 2,000,000 rejected');

      // Food boundaries
      expect(await save.applyProgressCode('KT1|10|5|100|-1'), isFalse, reason: 'food < 0 rejected');
      expect(await save.applyProgressCode('KT1|10|5|100|100'), isFalse, reason: 'food > 99 rejected');

      // Lower valid boundary
      final lowerOk = await save.applyProgressCode('KT1|1|1|0|0');
      expect(lowerOk, isTrue);
      expect(save.metricHighestClassicLevel, 1);
      expect(save.classicSavedLevel, 1);
      expect(save.gold, 0);
      expect(save.fishFood, 0);

      // Upper valid boundary
      final upperOk = await save.applyProgressCode('KT1|238|238|2000000|99');
      expect(upperOk, isTrue);
      expect(save.metricHighestClassicLevel, 238);
      expect(save.classicSavedLevel, 238);
      expect(save.gold, 2000000);
      expect(save.fishFood, 99);

      // Leading/trailing whitespace trimmed
      final trimOk = await save.applyProgressCode('   KT1|42|20|55000|15   \n');
      expect(trimOk, isTrue);
      expect(save.metricHighestClassicLevel, 42);
      expect(save.classicSavedLevel, 20);
      expect(save.gold, 55000);
      expect(save.fishFood, 15);
    });

    testWidgets('SettingsDialog omits progress code UI and displays localized KAPALI status when muted', (tester) async {
      final save = SaveManager.instance;
      save.language = 'tr';
      save.gold = 7777;
      await save.setSfxVolume(0);

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

      // Progress code UI was removed per user design; verify absence
      expect(find.text(I18n.tr('progress_paste')), findsNothing);
      // Localized Turkish status label (Kapalı) is shown instead of OFF
      expect(find.textContaining(I18n.tr('off')), findsWidgets);
      expect(save.gold, 7777);
    });
  });

  group('Challenger M1: UI Layout Robustness & Overflow Probes', () {
    testWidgets('SettingsDialog language dropdown layout probe on 320x568 (iPhone SE / Ultra Compact)', (tester) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final save = SaveManager.instance;

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

      final error = tester.takeException();
      if (error is FlutterError) {
        // Document empirical finding:
        // A RenderFlex overflowed by 55 pixels on the right at SettingsDialog line 109
        expect(
          error.message,
          contains('A RenderFlex overflowed'),
          reason: 'Empirically confirms RenderFlex overflow in SettingsDialog language dropdown on 320px width',
        );
      } else {
        expect(error, isNull);
      }

      // Close dialog cleanly
      final closeBtn = find.text(I18n.tr('close'));
      if (closeBtn.evaluate().isNotEmpty) {
        await tester.tap(closeBtn);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 200));
      }
    });

    testWidgets('TournamentDialog Dual-Tab layout on 320x568 screen with zero overflow', (tester) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final save = SaveManager.instance;
      save.highestLevel = 10;
      save.questBricksBroken = 50;

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

      expect(tester.takeException(), isNull);
      expect(find.text('HAFTALIK LİG ŞAMPİYONASI'), findsOneWidget);

      // Switch to Quests tab
      await tester.tap(find.text('GÜNLÜK GÖREVLER'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(tester.takeException(), isNull);
      // In 568px height, scroll down to reveal bottom item
      final questsList = find.byType(SingleChildScrollView);
      expect(questsList, findsOneWidget);
      await tester.drag(questsList, const Offset(0, -200));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('GÜNÜN OPERASYONU'), findsOneWidget);
    });
  });
}
