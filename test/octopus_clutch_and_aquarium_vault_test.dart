import 'package:flutter_test/flutter_test.dart';
import 'package:kirmatas/engine/game_controller.dart';
import 'package:kirmatas/models/game_state.dart';
import 'package:kirmatas/models/fish_synergy.dart';
import 'package:kirmatas/storage/save_manager.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Ahtapot Vantuz Kurtarışı & Akvaryum Pasif Altın Kasası Tests', () {
    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      SaveManager.instance.resetForTesting();
      await SaveManager.instance.init();
    });

    test('Octopus clutch save daily restriction and ownership', () async {
      final save = SaveManager.instance;
      // Initially, user does not have octopus
      expect(save.hasOctopus, isFalse);
      expect(save.canUseDailyOctopusClutch, isFalse);

      // Unlock octopus
      await save.unlockFish('octopus');
      expect(save.hasOctopus, isTrue);
      expect(save.canUseDailyOctopusClutch, isTrue);

      // Record daily clutch used
      await save.recordDailyOctopusClutchUsed();
      // Should be false for the rest of today
      expect(save.canUseDailyOctopusClutch, isFalse);
    });

    test('Aquarium Passive Gold Vault income curve is balanced', () {
      final save = SaveManager.instance;
      save.highestLevel = 1;
      final lowLevelVal = save.getFishGoldValue('guppy', applyLucky: false);
      expect(lowLevelVal, greaterThanOrEqualTo(10));
      expect(lowLevelVal, lessThan(30));

      save.highestLevel = 50;
      final midLevelVal = save.getFishGoldValue('guppy', applyLucky: false);
      expect(midLevelVal, greaterThan(lowLevelVal));
      expect(midLevelVal, lessThan(100)); // Controlled growth, not inflated

      save.highestLevel = 200; // Capped at 100 internally
      final cappedVal = save.getFishGoldValue('guppy', applyLucky: false);
      expect(cappedVal, lessThanOrEqualTo(60)); // 10 * (1 + 100 * 0.035) = 45
    });

    test('FishSynergyBuffs only exposes Octopus clutch and Passive Vault', () async {
      final save = SaveManager.instance;
      await save.unlockFish('octopus');

      final buffs = FishSynergyBuffs.calculate(save);
      // Micro synergies retired
      expect(buffs.extraPaddleWidth, equals(0.0));
      expect(buffs.critChanceBonus, equals(0.0));
      expect(buffs.startingLaserAmmoBonus, equals(0));
      // Octopus clutch active
      expect(buffs.hasOctopusClutchSave, isTrue);
      expect(buffs.activeBuffDescriptions.any((d) => d.contains('Ahtapot Vantuz Kurtarışı')), isTrue);
    });

    test('GameController triggers octopus clutch ONLY on last life and once per day', () async {
      final save = SaveManager.instance;
      await save.unlockFish('octopus');
      expect(save.canUseDailyOctopusClutch, isTrue);

      final controller = GameController();
      controller.setDimensions(360, 640);
      controller.startNewGame(GameMode.classic);
      controller.launchBall();

      // Case 1: lives > 1 -> octopus clutch must NOT trigger
      controller.stats.lives = 2;
      final ball1 = controller.balls.first;
      ball1.y = 700; // below screen
      controller.update(0.016);
      expect(controller.octopusClutchAnimTimer, equals(0.0));
      expect(save.canUseDailyOctopusClutch, isTrue);

      // Case 2: last life (lives == 1) -> octopus clutch triggers!
      controller.stats.lives = 1;
      controller.balls.clear();
      controller.balls.add(ball1);
      ball1.y = 700;
      controller.update(0.016);

      expect(controller.octopusClutchAnimTimer, greaterThan(0.0));
      expect(save.canUseDailyOctopusClutch, isFalse); // consumed for the day
      expect(ball1.vy, lessThan(0)); // propelled upward!
    });
  });
}
