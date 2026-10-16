import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kirmatas/engine/game_controller.dart';
import 'package:kirmatas/models/game_state.dart';
import 'package:kirmatas/storage/save_manager.dart';
import 'package:kirmatas/ui/game_canvas.dart';
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

  group('Milestone 1 Recheck Challenger Suite: isUltiReady Empirical Verification', () {
    late GameController controller;

    setUp(() {
      controller = GameController();
      controller.setDimensions(360, 640);
    });

    test('isUltiReady does NOT trigger when ultiCharge < 100.0 in Classic Mode', () {
      controller.startNewGame(GameMode.classic, explicitStartLevel: 1);
      controller.stats.diceChargeMax = 0;
      controller.stats.diceCharge = 0;

      final subThresholdCharges = [
        -100.0,
        -1.0,
        0.0,
        0.0001,
        0.5,
        0.9999,
        1.0, // EXACT 1% BUG CHECK
        1.0001,
        2.0,
        15.5,
        50.0,
        75.0,
        99.0,
        99.9,
        99.9999,
      ];

      for (final charge in subThresholdCharges) {
        controller.ultiCharge = charge;
        expect(
          controller.isUltiReady,
          isFalse,
          reason: 'Charge $charge must NOT evaluate isUltiReady to true',
        );
      }
    });

    test('isUltiReady triggers at and above 100.0 in Classic Mode', () {
      controller.startNewGame(GameMode.classic, explicitStartLevel: 1);
      controller.stats.diceChargeMax = 0;

      final thresholdAndAbove = [100.0, 100.0001, 101.0, 150.0, 999.0];

      for (final charge in thresholdAndAbove) {
        controller.ultiCharge = charge;
        expect(
          controller.isUltiReady,
          isTrue,
          reason: 'Charge $charge must evaluate isUltiReady to true in Classic Mode',
        );
      }
    });

    test('isUltiReady respects diceChargeMax threshold', () {
      controller.startNewGame(GameMode.classic, explicitStartLevel: 1);
      controller.ultiCharge = 0.0;

      // When diceChargeMax is 0, diceCharge alone must NOT trigger
      controller.stats.diceChargeMax = 0;
      controller.stats.diceCharge = 0;
      expect(controller.isUltiReady, isFalse);

      controller.stats.diceCharge = 10;
      expect(controller.isUltiReady, isFalse);

      // When diceChargeMax > 0
      controller.stats.diceChargeMax = 6;
      controller.stats.diceCharge = 0;
      expect(controller.isUltiReady, isFalse);

      controller.stats.diceCharge = 5;
      expect(controller.isUltiReady, isFalse);

      controller.stats.diceCharge = 6;
      expect(controller.isUltiReady, isTrue);

      controller.stats.diceCharge = 12;
      expect(controller.isUltiReady, isTrue);
    });

    test('isUltiReady is ALWAYS false in Chaos Mode regardless of charge', () {
      controller.startNewGame(GameMode.chaos, explicitStartLevel: 1);
      expect(controller.isChaosMode, isTrue);

      final chaosTestCharges = [
        0.0,
        1.0,
        50.0,
        99.9,
        100.0,
        150.0,
        1000.0,
      ];

      for (final charge in chaosTestCharges) {
        controller.ultiCharge = charge;
        expect(
          controller.isUltiReady,
          isFalse,
          reason: 'In Chaos Mode, ultiCharge $charge must NOT activate isUltiReady',
        );
      }

      // Even with maximum dice charge
      controller.stats.diceChargeMax = 5;
      controller.stats.diceCharge = 10;
      controller.ultiCharge = 100.0;
      expect(controller.isUltiReady, isFalse);
    });

    test('Switching between Classic and Chaos dynamically updates isUltiReady', () {
      controller.startNewGame(GameMode.classic, explicitStartLevel: 1);
      controller.ultiCharge = 100.0;
      expect(controller.isUltiReady, isTrue);

      // Switch to Chaos
      controller.startNewGame(GameMode.chaos, explicitStartLevel: 1);
      controller.ultiCharge = 100.0;
      expect(controller.isUltiReady, isFalse);

      // Switch back to Classic
      controller.startNewGame(GameMode.classic, explicitStartLevel: 1);
      controller.ultiCharge = 100.0;
      expect(controller.isUltiReady, isTrue);
    });

    testWidgets('GameCanvas double-tap handling respects isUltiReady in Chaos vs Classic', (tester) async {
      controller.startNewGame(GameMode.chaos, explicitStartLevel: 1);
      controller.ultiCharge = 100.0;
      expect(controller.isUltiReady, isFalse);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: GameCanvas(controller: controller),
          ),
        ),
      );
      await tester.pump();

      // Double tap in Chaos Mode should NOT trigger ulti or change charge
      await tester.tap(find.byType(GameCanvas));
      await tester.pump(const Duration(milliseconds: 50));
      await tester.tap(find.byType(GameCanvas));
      await tester.pump(const Duration(milliseconds: 100));

      expect(controller.isDiceRolling, isFalse);
      expect(controller.ultiCharge, 100.0);
    });
  });

  group('Milestone 1 Recheck Challenger Suite: SaveManager getUpgradeLevel Alias Resolution', () {
    late SaveManager save;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      save = SaveManager.instance;
      await save.init();
      save.upgrades.clear();
    });

    test('Resolves u_crit and crit_damage with math.max without key shadowing', () {
      // 1. Both absent
      expect(save.getUpgradeLevel('u_crit'), 0);
      expect(save.getUpgradeLevel('crit_damage'), 0);

      // 2. Primary key only
      save.upgrades['u_crit'] = 3;
      expect(save.getUpgradeLevel('u_crit'), 3);
      expect(save.getUpgradeLevel('crit_damage'), 3);

      // 3. Alias key only
      save.upgrades.clear();
      save.upgrades['crit_damage'] = 4;
      expect(save.getUpgradeLevel('u_crit'), 4);
      expect(save.getUpgradeLevel('crit_damage'), 4);

      // 4. Both present: primary > alias
      save.upgrades['u_crit'] = 5;
      save.upgrades['crit_damage'] = 2;
      expect(save.getUpgradeLevel('u_crit'), 5);
      expect(save.getUpgradeLevel('crit_damage'), 5);

      // 5. Both present: alias > primary (adversarial test for shadowing)
      save.upgrades['u_crit'] = 1;
      save.upgrades['crit_damage'] = 6;
      expect(save.getUpgradeLevel('u_crit'), 6);
      expect(save.getUpgradeLevel('crit_damage'), 6);

      // 6. Both present and equal
      save.upgrades['u_crit'] = 4;
      save.upgrades['crit_damage'] = 4;
      expect(save.getUpgradeLevel('u_crit'), 4);
      expect(save.getUpgradeLevel('crit_damage'), 4);
    });

    test('Resolves u_luck and luck with math.max without key shadowing', () {
      // 1. Both absent
      expect(save.getUpgradeLevel('u_luck'), 0);
      expect(save.getUpgradeLevel('luck'), 0);

      // 2. Primary key only
      save.upgrades['u_luck'] = 2;
      expect(save.getUpgradeLevel('u_luck'), 2);
      expect(save.getUpgradeLevel('luck'), 2);

      // 3. Alias key only
      save.upgrades.clear();
      save.upgrades['luck'] = 5;
      expect(save.getUpgradeLevel('u_luck'), 5);
      expect(save.getUpgradeLevel('luck'), 5);

      // 4. Both present: primary > alias
      save.upgrades['u_luck'] = 4;
      save.upgrades['luck'] = 1;
      expect(save.getUpgradeLevel('u_luck'), 4);
      expect(save.getUpgradeLevel('luck'), 4);

      // 5. Both present: alias > primary
      save.upgrades['u_luck'] = 2;
      save.upgrades['luck'] = 7;
      expect(save.getUpgradeLevel('u_luck'), 7);
      expect(save.getUpgradeLevel('luck'), 7);
    });

    test('Resolves u_gold and gold_multiplier with math.max without key shadowing', () {
      // 1. Both absent
      expect(save.getUpgradeLevel('u_gold'), 0);
      expect(save.getUpgradeLevel('gold_multiplier'), 0);

      // 2. Primary key only
      save.upgrades['u_gold'] = 3;
      expect(save.getUpgradeLevel('u_gold'), 3);
      expect(save.getUpgradeLevel('gold_multiplier'), 3);

      // 3. Alias key only
      save.upgrades.clear();
      save.upgrades['gold_multiplier'] = 6;
      expect(save.getUpgradeLevel('u_gold'), 6);
      expect(save.getUpgradeLevel('gold_multiplier'), 6);

      // 4. Both present: primary > alias
      save.upgrades['u_gold'] = 8;
      save.upgrades['gold_multiplier'] = 3;
      expect(save.getUpgradeLevel('u_gold'), 8);
      expect(save.getUpgradeLevel('gold_multiplier'), 8);

      // 5. Both present: alias > primary
      save.upgrades['u_gold'] = 3;
      save.upgrades['gold_multiplier'] = 9;
      expect(save.getUpgradeLevel('u_gold'), 9);
      expect(save.getUpgradeLevel('gold_multiplier'), 9);
    });

    test('Non-aliased upgrades and unknown keys behave normally', () {
      save.upgrades['paddle_width'] = 2;
      expect(save.getUpgradeLevel('paddle_width'), 2);

      expect(save.getUpgradeLevel('non_existent_key'), 0);
      expect(save.getUpgradeLevel(''), 0);
    });

    test('buyStatUpgrade integrates smoothly with alias resolution', () async {
      save.gold = 5000;
      // Start with legacy key at level 2
      save.upgrades['crit_damage'] = 2;
      expect(save.getUpgradeLevel('u_crit'), 2);

      // Buying 'u_crit' should use current level 2 and set 'u_crit' to 3
      final success = await save.buyStatUpgrade('u_crit', 100);
      expect(success, isTrue);
      expect(save.upgrades['u_crit'], 3);
      expect(save.upgrades['crit_damage'], 2);

      // Both keys return 3
      expect(save.getUpgradeLevel('u_crit'), 3);
      expect(save.getUpgradeLevel('crit_damage'), 3);
    });
  });
}
