import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:kirmatas/engine/i18n.dart';
import 'package:kirmatas/models/cosmetics.dart';
import 'package:kirmatas/storage/save_manager.dart';
import 'package:kirmatas/ui/level_clear_card.dart';
import 'package:kirmatas/ui/hud_overlay.dart';
import 'package:kirmatas/ui/tournament_dialog.dart';
import 'package:kirmatas/ui/chest_widget.dart';
import 'package:kirmatas/engine/game_controller.dart';
import 'package:kirmatas/models/game_state.dart';

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
  });

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await SaveManager.instance.init();
    await SaveManager.instance.setLanguage('tr');
  });

  group('User Request Polish & New Features Verification', () {
    test('1. Octopus is mythic rarity with bioluminescent colors and custom reward', () {
      final octoFish = FishItem.getById('octopus');
      expect(octoFish.rarity, Rarity.mythic);
      expect(octoFish.color, const Color(0xFFFF2A6D));
      expect(octoFish.secondaryColor, const Color(0xFF9C27B0));
      expect(octoFish.goldReward, 320);
      expect(octoFish.pearlCost, 150);

      expect(CrateDef.octopusVault.tier, Rarity.mythic);
      expect(CrateDef.octopusVault.primaryColor, const Color(0xFFFF2A6D));
      expect(CrateDef.octopusVault.weights[Rarity.mythic], 20.0);
    });

    test('2. Wood vs Abyss crate balance: Abyss has 0% commons, Wood has 0% legendaries', () {
      final woodCrate = CrateDef.allCrates.firstWhere((c) => c.id == 'wood');
      final abyssCrate = CrateDef.allCrates.firstWhere((c) => c.id == 'abyss');

      expect(woodCrate.cost, 750);
      expect(woodCrate.weights[Rarity.common], 82.0);
      expect(woodCrate.weights[Rarity.legendary], 0.0);

      expect(abyssCrate.cost, 2400);
      expect(abyssCrate.weights[Rarity.common], 0.0);
      expect(abyssCrate.weights[Rarity.epic]! > 50.0, true);
      expect(abyssCrate.weights[Rarity.legendary]! > 15.0, true);
    });

    test('3. Fish 5-copy limit strictly enforced', () async {
      final save = SaveManager.instance;
      const testFishId = 'discus_green';

      // Initially 0 for unowned fish
      expect(save.getFishCount(testFishId), 0);
      expect(save.canAcquireFish(testFishId), true);

      // Add up to 5 copies
      for (int i = 1; i <= 5; i++) {
        expect(save.canAcquireFish(testFishId), true);
        await save.addFishInstance(testFishId);
        expect(save.getFishCount(testFishId), i);
      }

      // At 5 copies, cannot acquire more
      expect(save.getFishCount(testFishId), 5);
      expect(save.canAcquireFish(testFishId), false);

      // Attempting to add 6th copy clamps to 5
      await save.addFishInstance(testFishId);
      expect(save.getFishCount(testFishId), 5);
    });

    test('4. 3-day (72-hour) fish starvation logic departs unfed fish', () async {
      final save = SaveManager.instance;
      const testFishId = 'angel_ruby';

      await save.addFishInstance(testFishId);
      expect(save.getFishCount(testFishId), 1);

      // If checked immediately, no fish departs
      final noneDeparted = await save.checkAndProcessStarvedFish();
      expect(noneDeparted.isEmpty, true);
      expect(save.getFishCount(testFishId), 1);

      // Backdate last fed timestamp to 73 hours ago (> 72h)
      final pastMs = DateTime.now().millisecondsSinceEpoch - (73 * 3600 * 1000);
      save.fishFedTimestamps[testFishId] = pastMs;

      // Process starvation (Zero-Deletion Policy: fish enters resting state, counts preserved)
      final departed = await save.checkAndProcessStarvedFish();
      expect(departed.contains(testFishId), true);
      expect(save.getFishCount(testFishId), 1, reason: 'Zero-Deletion Policy: fish is not deleted');
      expect(save.fishFedTimestamps.containsKey(testFishId), false, reason: 'Feeding production cycle pauses');
    });

    test('5. Upgrades & boosts i18n keys resolve cleanly without raw developer strings', () async {
      final save = SaveManager.instance;
      await save.setLanguage('en');
      final riskBoost = BoostItem.allBoosts.firstWhere((b) => b.id == 'risk_double');
      final octoBoost = BoostItem.allBoosts.firstWhere((b) => b.id == 'golden_octopus');

      expect(riskBoost.name, 'Risk Double');
      expect(riskBoost.description.contains('HP'), true);
      expect(octoBoost.name, 'Golden Octopus');
      expect(I18n.tr('cosmic_mastery_title'), 'COSMIC MASTERY (INFINITE TIER)');
      expect(I18n.tr('cosmic_gold_mastery_title'), 'Cosmic Gold Mastery');

      await save.setLanguage('tr');
      expect(riskBoost.name, 'Risk Bahsi');
      expect(octoBoost.name, 'Altın Ahtapot');
      expect(I18n.tr('cosmic_mastery_title'), 'KOZMİK USTALIK (SONSUZ SEVİYE)');
      expect(I18n.tr('cosmic_gold_mastery_title'), 'Kozmik Altın Ustalığı');
      expect(I18n.tr('mythic'), 'Mistik');
    });

    testWidgets('6. LevelClearCard renders Main Menu button and invokes callback', (tester) async {
      bool mainMenuPressed = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: LevelClearCard(
              level: 5,
              score: 1200,
              stars: 3,
              goldEarned: 100,
              onNextLevel: () {},
              onMainMenu: () {
                mainMenuPressed = true;
              },
            ),
          ),
        ),
      );

      // Look for the Menu button
      final menuFinder = find.text(I18n.tr('menu'));
      expect(menuFinder, findsOneWidget);

      await tester.tap(menuFinder);
      await tester.pump();
      expect(mainMenuPressed, true);
    });

    testWidgets('7. Speed boost button renders 2X turbo label with fast forward icon', (tester) async {
      final controller = GameController();
      controller.status = GameStatus.playing;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: HudOverlay(
              controller: controller,
              onPause: () {},
            ),
          ),
        ),
      );

      expect(find.text('2X'), findsOneWidget);
      expect(find.byIcon(Icons.fast_forward_rounded), findsOneWidget);

      // Tap speed boost button
      expect(controller.isSpeedBoostActive, false);
      await tester.tap(find.text('2X'));
      await tester.pump();
      expect(controller.isSpeedBoostActive, true);
    });

    testWidgets('8. Tournament dialog does NOT render JOIN TOURNAMENT button', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TournamentDialog(
              save: SaveManager.instance,
            ),
          ),
        ),
      );

      expect(find.text('JOIN TOURNAMENT'), findsNothing);
      expect(find.text('MÜCADELEYE KATIL'), findsNothing);
    });

    testWidgets('9. ChestWidget renders with wrapping tentacles for octopus crate', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ChestWidget(
              size: 100,
              tier: Rarity.mythic,
              crateType: 'octopus',
            ),
          ),
        ),
      );

      expect(find.byType(ChestWidget), findsOneWidget);
    });
  });
}
