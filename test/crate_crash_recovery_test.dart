import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:kirmatas/engine/i18n.dart';
import 'package:kirmatas/models/cosmetics.dart';
import 'package:kirmatas/storage/save_manager.dart';
import 'package:kirmatas/ui/chest_widget.dart';
import 'package:kirmatas/ui/crate_opening_dialog.dart';
import 'package:kirmatas/ui/main_menu.dart';

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
    await SaveManager.instance.clearPendingCrate();
  });

  group('Crate Crash Recovery & Atomic Unopened State Tests', () {
    test('PendingCrate JSON serialization and deserialization roundtrip', () {
      final original = PendingCrate(
        crateType: 'category',
        crateId: null,
        category: 'balls',
        rewardType: 'ball',
        rewardId: 'ball_fire',
        rewardTitle: 'Ateş Topu',
        rewardSubtitle: 'Yeni Top Açıldı!',
        rarityIndex: Rarity.epic.index,
        isDuplicate: false,
        isShardReward: false,
        isFoodBonus: false,
        bonusFoodCount: 0,
        bonusGoldCount: 0,
      );

      final json = original.toJson();
      final restored = PendingCrate.fromJson(json);

      expect(restored.crateType, original.crateType);
      expect(restored.category, original.category);
      expect(restored.rewardType, original.rewardType);
      expect(restored.rewardId, original.rewardId);
      expect(restored.rewardTitle, original.rewardTitle);
      expect(restored.rewardSubtitle, original.rewardSubtitle);
      expect(restored.rarityIndex, original.rarityIndex);
      expect(restored.isDuplicate, original.isDuplicate);
      expect(restored.isShardReward, original.isShardReward);
    });

    testWidgets('Chest roll creates pendingCrate but does NOT unlock inventory before opening', (tester) async {
      final save = SaveManager.instance;
      expect(save.pendingCrate, isNull);

      // Start opening an aquarium crate
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CrateOpeningDialog(crate: CrateDef.allCrates.first),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 700));

      // 1. Pending crate is created and saved
      expect(save.pendingCrate, isNotNull);
      final rolledRewardId = save.pendingCrate!.rewardId;
      expect(rolledRewardId.isNotEmpty, isTrue);

      // 2. But the reward is NOT in unlockedFish yet because chest is unopened!
      // (Except the default starter fish 'guppy' and 'tetra')
      if (rolledRewardId != 'guppy' && rolledRewardId != 'tetra') {
        expect(save.unlockedFish.contains(rolledRewardId), isFalse);
      }

      // 3. Chest is unopened and waiting at (1/3)
      expect(find.byType(ChestWidget), findsOneWidget);
      expect(find.text('Sandığa Dokun (1/3)'), findsOneWidget);
    });

    testWidgets('App re-entry preserves unopened chest and yields IDENTICAL reward without charging', (tester) async {
      final save = SaveManager.instance;

      // Simulate a saved pending crate from a previous session that crashed/exited before opening
      final savedCrate = PendingCrate(
        crateType: 'category',
        category: 'paddles',
        rewardType: 'paddle',
        rewardId: 'paddle_neon',
        rewardTitle: 'Neon Raket',
        rewardSubtitle: 'Yeni Raket Açıldı!',
        rarityIndex: Rarity.rare.index,
        isDuplicate: false,
      );
      await save.savePendingCrate(savedCrate);

      // Open dialog using the pending crate
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CrateOpeningDialog(pendingCrate: save.pendingCrate),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 700));

      // Verify chest is unopened (1/3)
      expect(find.byType(ChestWidget), findsOneWidget);
      expect(find.text('Sandığa Dokun (1/3)'), findsOneWidget);

      // Inventory does NOT have the item yet
      expect(save.unlockedPaddles.contains('paddle_neon'), isFalse);

      // Tap 1
      await tester.tap(find.byType(ChestWidget));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('Tekrar Dokun (2/3)'), findsOneWidget);

      // Tap 2
      await tester.tap(find.byType(ChestWidget));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('Açmak İçin Dokun! (3/3)'), findsOneWidget);

      // Tap 3 - Chest pops open!
      await tester.tap(find.byType(ChestWidget));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump(const Duration(milliseconds: 1000));

      // The reward is IDENTICAL to what was rolled before!
      expect(find.text('Neon Raket'), findsOneWidget);

      // Item is now unlocked in inventory atomically upon opening
      expect(save.unlockedPaddles.contains('paddle_neon'), isTrue);

      // Pending crate is cleared
      expect(save.pendingCrate, isNull);
    });

    testWidgets('MainMenu auto-shows unopened CrateOpeningDialog on boot if pending crate exists', (tester) async {
      final save = SaveManager.instance;

      // Pre-save pending crate in storage
      final savedCrate = PendingCrate(
        crateType: 'aquarium',
        crateId: 'wood',
        rewardType: 'fish',
        rewardId: 'clownfish',
        rewardTitle: 'Palyaço Balığı',
        rewardSubtitle: 'Yeni Balık Keşfedildi!',
        rarityIndex: Rarity.rare.index,
      );
      await save.savePendingCrate(savedCrate);

      // Launch MainMenu
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: MainMenuScreen(),
          ),
        ),
      );

      // Allow post-frame callbacks to run
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // CrateOpeningDialog is automatically presented to the player
      expect(find.byType(CrateOpeningDialog), findsOneWidget);
      expect(find.byType(ChestWidget), findsOneWidget);
      expect(find.text('Sandığa Dokun (1/3)'), findsOneWidget);
    });
  });
}
