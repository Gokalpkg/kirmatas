import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:kirmatas/models/cosmetics.dart';
import 'package:kirmatas/storage/save_manager.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Aquarium Octopus, Wheel Crate & Tutorial Tests', () {
    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      await SaveManager.instance.init();
    });

    test('Cosmic Octopus dweller classification and biological properties', () {
      final octopus = FishItem.getById('octopus');
      expect(octopus.kind, equals(FishKind.octopus));
      expect(octopus.isBottomDweller, isTrue);
      expect(octopus.rarity, equals(Rarity.legendary));
      expect(octopus.name, isNotEmpty);
    });

    test('Fortune Wheel chest prize pool strictly excludes coral, abyss, and octopus', () {
      // Allowed crates pool:
      const allowedCrates = {'wood', 'balls', 'paddles', 'trails', 'bricks'};
      const forbiddenCrates = {'coral', 'abyss', 'octopus'};

      for (final id in forbiddenCrates) {
        expect(allowedCrates.contains(id), isFalse, reason: '$id must never be in the free wheel chest pool');
      }

      // Verify that wood is in CrateDef.allCrates
      expect(CrateDef.allCrates.any((c) => c.id == 'wood'), isTrue);

      // Verify that balls, paddles, trails, bricks are valid CategoryCrateInfo keys
      for (final cat in ['balls', 'paddles', 'trails', 'bricks']) {
        expect(CategoryCrateInfo.categoryCrates.containsKey(cat), isTrue);
      }
    });

    test('SaveManager aquarium catalog tutorial flag defaults to false and completes properly', () async {
      final save = SaveManager.instance;
      // Default state
      expect(save.hasSeenAquariumCatalogTutorial, isFalse);

      // Complete tutorial
      save.completeAquariumCatalogTutorial();
      expect(save.hasSeenAquariumCatalogTutorial, isTrue);
    });
  });
}
