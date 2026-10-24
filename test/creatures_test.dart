import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:kirmatas/models/cosmetics.dart';
import 'package:kirmatas/storage/save_manager.dart';
import 'package:kirmatas/ui/eco_tank_background.dart';

void main() {
  group('Aquarium creatures', () {
    test('snail, shrimp, crab and octopus joined the collection', () {
      final byId = {for (final f in FishItem.allFish) f.id: f};
      expect(byId.keys,
          containsAll(['snail', 'shrimp', 'crab', 'octopus', 'jellyfish']));
      expect(FishItem.allFish.length, 23);

      expect(byId['snail']!.kind, FishKind.snail);
      expect(byId['shrimp']!.kind, FishKind.shrimp);
      expect(byId['crab']!.kind, FishKind.crab);
      expect(byId['octopus']!.kind, FishKind.octopus);
      expect(byId['jellyfish']!.kind, FishKind.jellyfish);
      expect(byId['guppy']!.kind, FishKind.fish);
    });

    test('bottom dwellers are only the snail and the crab', () {
      expect(FishItem.getById('snail').isBottomDweller, isTrue);
      expect(FishItem.getById('crab').isBottomDweller, isTrue);
      expect(FishItem.getById('shrimp').isBottomDweller, isFalse);
      expect(FishItem.getById('octopus').isBottomDweller, isTrue);
      expect(FishItem.getById('jellyfish').isBottomDweller, isFalse);
      expect(FishItem.getById('arowana').isBottomDweller, isFalse);
    });

    test('creature economy follows their rarity', () {
      expect(FishItem.getById('snail').goldReward, 15);
      expect(FishItem.getById('shrimp').goldReward, 35);
      expect(FishItem.getById('crab').goldReward, 75);
      expect(FishItem.getById('octopus').goldReward, 160);

      expect(FishItem.getById('snail').pearlCost, 0);
      expect(FishItem.getById('shrimp').pearlCost, 15);
      expect(FishItem.getById('crab').pearlCost, 35);
      expect(FishItem.getById('octopus').pearlCost, 75);
      expect(FishItem.getById('jellyfish').goldReward, 75);
      expect(FishItem.getById('jellyfish').pearlCost, 35);
    });

    testWidgets('tank renders owned creatures without errors', (tester) async {
      SharedPreferences.setMockInitialValues({});
      final save = SaveManager.instance;
      await save.init();
      save.ownedFishCounts['snail'] = 1;
      save.ownedFishCounts['shrimp'] = 1;
      save.ownedFishCounts['crab'] = 1;
      save.ownedFishCounts['octopus'] = 1;
      save.ownedFishCounts['jellyfish'] = 1;

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: EcoTankBackground(interactive: true)),
        ),
      );
      // Let the simulation run: swims, crawls, dashes, pulses.
      for (var i = 0; i < 40; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }
      expect(tester.takeException(), isNull);

      await tester.pumpWidget(const SizedBox.shrink());
    });

    test('creature assets and names resolve', () {
      for (final id in ['snail', 'shrimp', 'crab', 'octopus', 'jellyfish']) {
        final item = FishItem.getById(id);
        expect(item.assetPath, 'assets/images/fishes/$id.png');
        expect(item.name, isNot(id)); // localized display name exists
      }
      expect(FishItem.getById('snail').name, 'Altın Elma Salyangozu');
      expect(FishItem.getById('octopus').name, 'Kozmik Ahtapot');
      expect(FishItem.getById('jellyfish').name, 'Ay Denizanası');
    });
  });
}
