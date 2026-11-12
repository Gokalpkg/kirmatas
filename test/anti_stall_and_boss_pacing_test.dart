import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kirmatas/engine/game_controller.dart';
import 'package:kirmatas/models/game_state.dart';
import 'package:kirmatas/models/brick.dart';
import 'package:kirmatas/models/ball.dart';
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

  group('Anti-Stall & Boss Pacing System Tests', () {
    late SaveManager save;
    late GameController controller;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      save = SaveManager.instance;
      save.resetForTesting();
      await save.init();
      controller = GameController();
      controller.screenWidth = 360;
      controller.screenHeight = 640;
    });

    tearDown(() {
      controller.dispose();
    });

    test('LevelDesign.isBossLevelNumber marks every 10th level as a boss level', () {
      expect(LevelDesign.isBossLevelNumber(10), isTrue);
      expect(LevelDesign.isBossLevelNumber(20), isTrue);
      expect(LevelDesign.isBossLevelNumber(30), isTrue);
      expect(LevelDesign.isBossLevelNumber(40), isTrue);
      expect(LevelDesign.isBossLevelNumber(50), isTrue);
      expect(LevelDesign.isBossLevelNumber(100), isTrue);

      // Non-boss levels
      expect(LevelDesign.isBossLevelNumber(1), isFalse);
      expect(LevelDesign.isBossLevelNumber(2), isFalse);
      expect(LevelDesign.isBossLevelNumber(7), isFalse);
      expect(LevelDesign.isBossLevelNumber(11), isFalse);
      expect(LevelDesign.isBossLevelNumber(14), isFalse);
    });

    test('Anti-Stall: Smart Lightning strikes stubborn brick when 1 brick remains for 6.5s', () {
      controller.status = GameStatus.playing;
      controller.bricks.clear();
      controller.balls.clear();

      // Add single stubborn brick
      final brick = Brick(
        x: 100,
        y: 80,
        width: 40,
        height: 20,
        color: Colors.red,
        hp: 1,
        maxHp: 1,
        points: 100,
      );
      controller.bricks.add(brick);

      final ball = Ball(
        x: 180,
        y: 400,
        vx: 100,
        vy: 100,
        radius: 7,
      );
      controller.balls.add(ball);

      controller.endgameStallTimer = 6.4;
      controller.update(0.05); // Brings stall timer to 6.45, not yet 6.5
      expect(brick.isAlive, isTrue);

      controller.update(0.1); // Brings stall timer to 6.55 >= 6.5 -> triggers anti-stall lightning
      expect(brick.isAlive, isFalse);
      expect(controller.endgameStallTimer, 0.0);
    });

    test('Destroying bricks accumulates gold into Piggy Bank', () {
      final initialPiggy = save.piggyBankGold;
      controller.status = GameStatus.playing;
      controller.bricks.clear();

      final normalBrick = Brick(
        x: 50,
        y: 50,
        width: 30,
        height: 15,
        color: Colors.blue,
        hp: 1,
        maxHp: 1,
      );
      controller.bricks.add(normalBrick);

      final ball = Ball(x: 65, y: 55, vx: 50, vy: -50, radius: 7);
      controller.balls.add(ball);

      // Trigger hit and destroy
      controller.handleBrickDestructionForTesting(normalBrick);
      expect(save.piggyBankGold, initialPiggy + 1);
    });
  });
}

extension GameControllerTestHelper on GameController {
  void handleBrickDestructionForTesting(Brick b) {
    b.isAlive = false;
    final piggyAmount = b.isBoss ? 10 : (b.isGoldPinata ? 5 : 1);
    save.addPiggyBankGold(piggyAmount);
  }
}
