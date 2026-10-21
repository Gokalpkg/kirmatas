import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:kirmatas/models/cosmetics.dart';
import 'package:kirmatas/storage/save_manager.dart';
import 'package:kirmatas/ui/fortune_wheel_dialog.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Octopus Vault', () {
    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      await SaveManager.instance.init();
    });

    test('vault is premium, pearl-gated, and never sold in the shop', () {
      final vault = CrateDef.octopusVault;
      expect(vault.id, 'octopus');
      expect(vault.tier, Rarity.legendary);
      expect(CrateDef.octopusVaultPearlCost, 3);
      expect(CrateDef.allCrates.any((c) => c.id == 'octopus'), isFalse,
          reason: 'Vault must not appear among shop crates');
      final total = vault.weights.values.fold(0.0, (a, b) => a + b);
      expect(total, closeTo(100.0, 0.01));
      // Premium odds: epic+legendary dominate the vault.
      expect((vault.weights[Rarity.epic] ?? 0) + (vault.weights[Rarity.legendary] ?? 0),
          greaterThan(50.0));
    });

    testWidgets('winning the wheel KASA sector saves a vault pending crate', (tester) async {
      late BuildContext ctx;
      await tester.pumpWidget(MaterialApp(
        home: Builder(builder: (c) {
          ctx = c;
          return const SizedBox();
        }),
      ));

      final save = SaveManager.instance;
      await save.clearPendingCrate();
      final kasa = FortuneWheelDialog.rewards.firstWhere((r) => r.label == 'KASA');
      kasa.onClaim(ctx, save);
      // onClaim is fire-and-forget async; let its save land.
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 120)));

      final pending = save.pendingCrate;
      expect(pending, isNotNull);
      expect(pending!.crateId, 'octopus');
      expect(pending.rewardType, 'fish');
      // For now the vault always hands out the octopus itself.
      expect(pending.rewardId, 'octopus');
      expect(pending.rarityIndex, Rarity.legendary.index);
    });

    test('vaultRewardFish currently guarantees the octopus', () {
      final save = SaveManager.instance;
      expect(FortuneWheelDialog.vaultRewardFish(save).id, 'octopus');
      expect(FortuneWheelDialog.vaultRewardFish(save).rarity, Rarity.legendary);
    });

    test('pearl gate math: 3 pearls unlock, fewer do not', () {
      final save = SaveManager.instance;
      save.pearls = 2;
      expect(save.spendPearls(CrateDef.octopusVaultPearlCost), isFalse);
      expect(save.pearls, 2);
      save.pearls = 5;
      expect(save.spendPearls(CrateDef.octopusVaultPearlCost), isTrue);
      expect(save.pearls, 2);
    });
  });
}
