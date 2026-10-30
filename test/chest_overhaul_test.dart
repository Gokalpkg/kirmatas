import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kirmatas/engine/game_controller.dart';
import 'package:kirmatas/models/brick.dart';
import 'package:kirmatas/models/game_state.dart';
import 'package:kirmatas/models/level_design.dart';
import 'package:kirmatas/storage/save_manager.dart';
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

  late SaveManager save;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    save = SaveManager.instance;
    await save.init();
    save.gold = 100;
    save.pearls = 0;
  });

  group('Hazine Sandığı Bloğu & Ödül Hissi Testleri', () {
    test('LevelDesign places sturdy chest bricks with 2 HP in early worlds', () {
      final bricks = LevelDesign.buildClassicLevel(2, 400, 800);
      final chests = bricks.where((b) => b.isChest).toList();
      expect(chests.isNotEmpty, isTrue, reason: 'Level 2 should contain a tactical chest');
      expect(chests.first.hp, 2, reason: 'World 1 chests have 2 HP for multi-hit suspense');
    });

    test('Chaos Mode row generator can spawn chest bricks', () {
      bool foundChest = false;
      for (int wave = 1; wave <= 50; wave++) {
        final row = LevelDesign.buildChaosRow(wave, 0, 400);
        if (row.any((b) => b.isChest)) {
          foundChest = true;
          break;
        }
      }
      expect(foundChest, isTrue, reason: 'Chaos Mode rows should periodically feature treasure chests');
    });

    test('Hitting chest before death leaks gold and plays tactile feedback', () {
      final gc = GameController();
      gc.setDimensions(360, 640);
      gc.startNewGame(GameMode.classic);

      final chest = Brick(
        x: 100,
        y: 100,
        width: 40,
        height: 20,
        hp: 2,
        maxHp: 2,
        color: Colors.amber,
        isChest: true,
      );

      final initialGold = save.gold;
      gc.hitBrickForTest(chest);

      expect(chest.hp, 1);
      expect(chest.isAlive, isTrue);
      expect(save.gold, initialGold + 1, reason: 'Chest should leak +1 gold on mid-hit');
      expect(gc.particles.coinOrbs.isNotEmpty, isTrue, reason: 'Coin orbs should spawn on hit');
    });

    test('Destroying chest in Classic awards big scaled gold and drops action capsule', () {
      final gc = GameController();
      gc.setDimensions(360, 640);
      gc.startNewGame(GameMode.classic);
      gc.stats.level = 15; // World 2

      final chest = Brick(
        x: 100,
        y: 100,
        width: 40,
        height: 20,
        hp: 1,
        maxHp: 1,
        color: Colors.amber,
        isChest: true,
      );

      final initialGold = save.gold;
      final initialCapsules = gc.capsules.length;

      gc.destroyBrickForTest(chest);

      expect(save.gold, greaterThanOrEqualTo(initialGold + 30), reason: 'Classic chest gold should be rebalanced scaled gold');
      expect(gc.capsules.length, initialCapsules + 1, reason: 'Chest must guarantee an action power-up capsule drop');
      expect(gc.particles.chestLids.isNotEmpty, isTrue);
    });

    test('Destroying chest in Chaos mode adds extra balls directly to chaosStock', () {
      final gc = GameController();
      gc.setDimensions(360, 640);
      gc.startNewGame(GameMode.chaos);
      gc.chaosStock = 10;

      final chest = Brick(
        x: 100,
        y: 100,
        width: 40,
        height: 20,
        hp: 1,
        maxHp: 1,
        color: Colors.amber,
        isChest: true,
      );

      gc.destroyBrickForTest(chest);

      expect(gc.chaosStock, greaterThanOrEqualTo(13), reason: 'Chaos chest must award extra balls');
      expect(gc.particles.chestLids.isNotEmpty, isTrue);
    });
  });
}
