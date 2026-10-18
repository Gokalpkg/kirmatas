import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:kirmatas/models/fish_synergy.dart';
import 'package:kirmatas/storage/save_manager.dart';
import 'package:kirmatas/ui/offline_earnings_dialog.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('xyz.luan/audioplayers.global'),
      (call) async => 1,
    );
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('xyz.luan/audioplayers'),
      (call) async => 1,
    );
  });

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await SaveManager.instance.init();
  });

  group('Evolution R4: Aquarium Synergies', () {
    test('Empty tank grants baseline values', () async {
      final save = SaveManager.instance;
      save.unlockedFish = [];

      final buffs = FishSynergyBuffs.calculate(save);
      expect(buffs.extraPaddleWidth, 0.0);
      expect(buffs.critChanceBonus, 0.0);
      expect(buffs.goldMultiplier, 1.0);
      expect(buffs.startingLaserAmmoBonus, 0);
      expect(buffs.activeBuffDescriptions, isEmpty);
    });

    test('Guppy & Tetra species grant paddle width bonus', () async {
      final save = SaveManager.instance;
      save.unlockedFish = ['guppy', 'guppy_blue', 'tetra'];

      final buffs = FishSynergyBuffs.calculate(save);
      expect(buffs.extraPaddleWidth, 10.0); // 4 + 3 + 3
      expect(buffs.activeBuffDescriptions.any((d) => d.contains('Raket Boyutu')), isTrue);
    });

    test('Angelfish species grant critical strike bonus', () async {
      final save = SaveManager.instance;
      save.unlockedFish = ['angel', 'angel_ruby'];

      final buffs = FishSynergyBuffs.calculate(save);
      expect(buffs.critChanceBonus, closeTo(0.08, 0.001)); // 0.03 + 0.05
      expect(buffs.activeBuffDescriptions.any((d) => d.contains('Kritik Vuruş Şansı')), isTrue);
    });

    test('Betta & Discus grant laser ammo bonus', () async {
      final save = SaveManager.instance;
      save.unlockedFish = ['betta', 'discus'];

      final buffs = FishSynergyBuffs.calculate(save);
      expect(buffs.startingLaserAmmoBonus, 2); // 1 from betta + 1 from discus
      expect(buffs.activeBuffDescriptions.any((d) => d.contains('Lazer Cephanesi')), isTrue);
    });

    test('Arowana species grant gold multiplier', () async {
      final save = SaveManager.instance;
      save.unlockedFish = ['arowana', 'arowana_red'];

      final buffs = FishSynergyBuffs.calculate(save);
      expect(buffs.goldMultiplier, closeTo(1.25, 0.001)); // 1.0 + 0.10 + 0.15
      expect(buffs.activeBuffDescriptions.any((d) => d.contains('Seviye Altını')), isTrue);
    });
  });

  group('Evolution R5: Offline Aquarium Earnings Dialog', () {
    testWidgets('OfflineEarningsDialog renders ready gold and collects normally', (tester) async {
      SharedPreferences.setMockInitialValues({
        'gold': 100,
      });
      final save = SaveManager.instance;
      await save.init();
      save.unlockedFish = ['guppy'];

      // Set fish as fed > 6 hours ago so gold is ready
      final now = DateTime.now().millisecondsSinceEpoch;
      save.fishFedTimestamps['guppy'] = now - (SaveManager.fishPayoutDurationMs + 1000);

      expect(save.currentAvailableFishGold, greaterThan(0));
      final readyGold = save.currentAvailableFishGold;
      final initialGold = save.gold;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (ctx) => ElevatedButton(
                onPressed: () => OfflineEarningsDialog.show(ctx, save: save),
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open'));
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Akvaryum Hasadı!'), findsOneWidget);
      expect(find.text('+$readyGold'), findsOneWidget);
      expect(find.text('Normal Topla'), findsOneWidget);
      expect(find.text('2X Katla (Reklam)'), findsOneWidget);

      // Tap Normal Claim
      await tester.tap(find.text('Normal Topla'));
      await tester.pump(const Duration(milliseconds: 300));

      // Dialog should close and gold added to save
      expect(find.text('Akvaryum Hasadı!'), findsNothing);
      expect(save.gold, initialGold + readyGold);
    });
  });
}
