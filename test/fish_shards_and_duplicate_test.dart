import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:kirmatas/storage/save_manager.dart';
import 'package:kirmatas/models/cosmetics.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    SaveManager.instance.resetForTesting();
    await SaveManager.instance.init();
  });

  group('Fish Shards & Max Copies Per Color/Species Rule', () {
    test('Default fish start with count 1 and can acquire copies', () {
      final save = SaveManager.instance;
      expect(save.getFishCount('guppy'), equals(1));
      expect(save.canAcquireFish('guppy'), isTrue);

      expect(save.getFishCount('tetra'), equals(1));
      expect(save.canAcquireFish('tetra'), isTrue);

      expect(save.getFishCount('guppy_blue'), equals(0));
      expect(save.canAcquireFish('guppy_blue'), isTrue);
    });

    test('Acquiring copies up to max (5) allowed, beyond returns false', () async {
      final save = SaveManager.instance;
      expect(save.getFishCount('guppy'), equals(1));

      for (int i = 2; i <= 5; i++) {
        final added = await save.addFishInstance('guppy');
        expect(added, isTrue);
        expect(save.getFishCount('guppy'), equals(i));
      }
      expect(save.canAcquireFish('guppy'), isFalse);

      final addedSixth = await save.addFishInstance('guppy');
      expect(addedSixth, isFalse);
      expect(save.getFishCount('guppy'), equals(5));
    });

    test('allOwnedFishInstances includes duplicated fish (count = 2)', () async {
      final save = SaveManager.instance;
      await save.addFishInstance('guppy'); // Now guppy is 2
      final instances = save.allOwnedFishInstances;
      final guppyCopies = instances.where((id) => id == 'guppy').length;
      expect(guppyCopies, equals(2));
    });

    test('Fish shards add, consume, and guaranteed chest works correctly', () async {
      final save = SaveManager.instance;
      expect(save.fishShards, equals(0));

      // Add 1 common shard
      await save.addFishShards(1);
      expect(save.fishShards, equals(1));

      // Add 2 rare shards
      await save.addFishShards(2);
      expect(save.fishShards, equals(3));

      // Add more to reach 8
      await save.addFishShards(5);
      expect(save.fishShards, equals(8));

      // Cannot consume more than 8
      expect(await save.consumeFishShards(9), isFalse);

      // Consume 8 successfully
      expect(await save.consumeFishShards(8), isTrue);
      expect(save.fishShards, equals(0));
    });

    test('claimPendingCrate grants shards when isShardReward is true', () async {
      final save = SaveManager.instance;
      expect(save.fishShards, equals(0));

      // Claim a crate with 2 fish shards
      await save.savePendingCrate(PendingCrate(
        crateType: 'aquarium',
        category: 'fish',
        rewardType: 'fish',
        rewardId: 'guppy',
        rewardTitle: 'Mercan Lepistes',
        rewardSubtitle: 'Bu balıktan 2 adede sahipsin! +2 Balık Eklentisi eklendi (2/8).',
        rarityIndex: Rarity.rare.index,
        isDuplicate: true,
        isShardReward: true,
        shardCount: 2,
      ));

      await save.claimPendingCrate();
      expect(save.fishShards, equals(2));
      // Guppy count shouldn't have exceeded 5
      expect(save.getFishCount('guppy') <= 5, isTrue);
    });
  });
}
