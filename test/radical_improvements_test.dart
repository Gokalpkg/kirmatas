import 'package:flutter_test/flutter_test.dart';
import 'package:kirmatas/config/balance_config.dart';
import 'package:kirmatas/models/cosmetics.dart';
import 'package:kirmatas/models/fish_synergy.dart';
import 'package:kirmatas/storage/save_manager.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Radical 10 Improvements System Verification', () {
    test('Hit-stop scales smoothly down with active ball count to prevent FPS stutter', () {
      final singleBallHitStop = BalanceConfig.scaledHitStop(1);
      final fiveBallsHitStop = BalanceConfig.scaledHitStop(5);
      final tenBallsHitStop = BalanceConfig.scaledHitStop(10);

      expect(singleBallHitStop, equals(BalanceConfig.hitStopDurationSeconds));
      expect(fiveBallsHitStop, lessThan(singleBallHitStop));
      expect(tenBallsHitStop, lessThan(fiveBallsHitStop));
      expect(tenBallsHitStop, greaterThanOrEqualTo(0.008));
    });

    test('Anti-stall threshold is tightened to 3.5s for fast recovery', () {
      expect(BalanceConfig.endgameStallThresholdSeconds, equals(3.5));
    });

    test('Aquarium fish gold payout dynamically scales with player campaign progression', () async {
      SharedPreferences.setMockInitialValues({
        'highestLevel': 1,
        'unlockedFish': ['guppy', 'arowana'],
      });
      final save = SaveManager.instance;
      await save.init();

      final level1Gold = save.getFishGoldValue('arowana');

      // Now simulate player reaching Level 50
      save.highestLevel = 50;
      final level50Gold = save.getFishGoldValue('arowana');

      // Now simulate player reaching Level 100
      save.highestLevel = 100;
      final level100Gold = save.getFishGoldValue('arowana');

      expect(level50Gold, greaterThan(level1Gold * 5));
      expect(level100Gold, greaterThan(level50Gold));
    });

    test('Active fish synergy buffs calculate correctly and format descriptions', () async {
      final save = SaveManager.instance;
      save.unlockedFish = ['guppy', 'angel', 'betta'];
      save.ownedFishCounts = {'guppy': 1, 'angel': 1, 'betta': 1};

      final buffs = FishSynergyBuffs.calculate(save);
      expect(buffs.extraPaddleWidth, greaterThan(0));
      expect(buffs.critChanceBonus, greaterThan(0));
      expect(buffs.startingLaserAmmoBonus, greaterThan(0));
      expect(buffs.activeBuffDescriptions, isNotEmpty);
    });
  });
}
