import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:kirmatas/engine/game_controller.dart';
import 'package:kirmatas/models/game_state.dart';
import 'package:kirmatas/storage/save_manager.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SaveManager save;

  setUpAll(() async {
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(
      const MethodChannel('xyz.luan/audioplayers.global'),
      (MethodCall methodCall) async => 1,
    );
    messenger.setMockMethodCallHandler(
      const MethodChannel('xyz.luan/audioplayers'),
      (MethodCall methodCall) async => 1,
    );
    SharedPreferences.setMockInitialValues({});
    save = SaveManager.instance;
    await save.init();
  });

  group('Side-mode daily quests (save level)', () {
    test('zen time quest pays 80 once', () async {
      save.addQuestZenSeconds(600);
      expect(save.questZenSeconds, greaterThanOrEqualTo(600));
      expect(await save.claimQuestReward('zen_time'), 80);
      expect(await save.claimQuestReward('zen_time'), 0);
    });

    test('shapes clear quest pays 100', () async {
      save.recordShapesClearQuest();
      expect(save.questShapesClears, greaterThanOrEqualTo(1));
      expect(await save.claimQuestReward('shapes_clear'), 100);
    });

    test('descend rows quest pays 90 at 10 rows', () async {
      for (var i = 0; i < 10; i++) {
        save.recordDescendRowQuest();
      }
      expect(save.questDescendRows, greaterThanOrEqualTo(10));
      expect(await save.claimQuestReward('descend_rows'), 90);
    });

    test('unfinished quests pay nothing', () async {
      final fresh = SaveManager.instance;
      // zen_time etc. already claimed above; use a never-completed check
      // on a quest id with unmet progress in a fresh-ish state:
      expect(await fresh.claimQuestReward('does_not_exist'), 0);
    });
  });

  group('Side-mode controller hooks', () {
    test('descend march increments survived rows and quest progress', () {
      final rows0 = save.questDescendRows;
      final ctrl = GameController();
      ctrl.startNewGame(GameMode.descend);
      ctrl.status = GameStatus.playing;
      ctrl.launchBall();
      ctrl.status = GameStatus.playing;
      expect(ctrl.descendRowsSurvived, 0);

      ctrl.descendTimer = 0.01;
      ctrl.update(0.05);
      expect(ctrl.descendRowsSurvived, 1);
      expect(save.questDescendRows, rows0 + 1);
      ctrl.descendTimer = 5.5; // halfway to the next drop
      expect(ctrl.descendDropProgress, closeTo(0.5, 0.01));
    });

    test('zen play time feeds the zen quest in chunks', () {
      final before = save.questZenSeconds;
      final ctrl = GameController();
      ctrl.startNewGame(GameMode.zen);
      ctrl.status = GameStatus.playing;
      ctrl.launchBall();
      ctrl.status = GameStatus.playing;
      ctrl.update(2.5);
      expect(save.questZenSeconds, greaterThanOrEqualTo(before + 2));
    });
  });
}
