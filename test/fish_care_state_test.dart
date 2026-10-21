import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:kirmatas/storage/save_manager.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Fish care states', () {
    late SaveManager save;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      save = SaveManager.instance;
      await save.init();
      save.fishFedTimestamps.clear();
      save.fishFood = 10;
    });

    test('unfed fish is waiting and counts agree', () {
      expect(save.unlockedFish, isNotEmpty);
      final id = save.unlockedFish.first;
      expect(save.fishCareState(id), FishCareState.waiting);
      expect(save.waitingFishCount, save.unlockedFish.length);
      expect(save.producingFishCount, 0);
      expect(save.readyFishCount, 0);
      expect(save.hasWaitingFish, isTrue);
    });

    test('feeding moves a fish to producing, then ready after 6h', () async {
      final id = save.unlockedFish.first;
      final fed = await save.feedFish(id);
      expect(fed, isTrue);
      expect(save.fishCareState(id), FishCareState.producing);
      expect(save.producingFishCount, 1);
      expect(save.waitingFishCount, save.unlockedFish.length - 1);

      // Age the feeding past the 6h payout window.
      save.fishFedTimestamps[id] =
          DateTime.now().millisecondsSinceEpoch - SaveManager.fishPayoutDurationMs - 1000;
      expect(save.fishCareState(id), FishCareState.ready);
      expect(save.readyFishCount, 1);
      expect(save.producingFishCount, 0);
      expect(save.currentAvailableFishGold, greaterThan(0));
    });

    test('collecting ready gold returns the fish to waiting', () async {
      final id = save.unlockedFish.first;
      save.fishFedTimestamps[id] =
          DateTime.now().millisecondsSinceEpoch - SaveManager.fishPayoutDurationMs - 1000;
      expect(save.fishCareState(id), FishCareState.ready);

      final collected = await save.collectFishGold();
      expect(collected, greaterThan(0));
      expect(save.fishCareState(id), FishCareState.waiting);
      expect(save.hasWaitingFish, isTrue);
    });

    test('hasWaitingFish is false while every fish is in a cycle', () async {
      for (final id in save.unlockedFish) {
        save.fishFedTimestamps[id] = DateTime.now().millisecondsSinceEpoch;
      }
      expect(save.waitingFishCount, 0);
      expect(save.hasWaitingFish, isFalse);
      expect(save.producingFishCount, save.unlockedFish.length);
    });
  });
}
