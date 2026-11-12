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
      controller.antiStallLightningDelay = 6.5;
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

    test('Anti-Stall: Smart Lightning completely destroys stubborn multi-HP brick', () {
      controller.status = GameStatus.playing;
      controller.antiStallLightningDelay = 6.5;
      controller.bricks.clear();
      controller.balls.clear();

      final multiHpBrick = Brick(
        x: 100,
        y: 80,
        width: 40,
        height: 20,
        color: Colors.red,
        hp: 5,
        maxHp: 5,
        points: 100,
      );
      controller.bricks.add(multiHpBrick);

      final ball = Ball(x: 180, y: 400, vx: 100, vy: 100, radius: 7);
      controller.balls.add(ball);

      controller.endgameStallTimer = 6.5;
      controller.update(0.05);
      expect(multiHpBrick.isAlive, isFalse, reason: 'Stubborn multi-HP brick must be destroyed to prevent stalling');
    });

    test('Anti-Stall: Ignores immune bricks (steel/heavy steel) and targets breakable brick', () {
      controller.status = GameStatus.playing;
      controller.antiStallLightningDelay = 6.5;
      controller.bricks.clear();
      controller.balls.clear();

      final steelBrick = Brick(x: 50, y: 80, width: 40, height: 20, isSteel: true, color: Colors.grey);
      final heavySteel = Brick(x: 150, y: 80, width: 40, height: 20, isHeavySteel: true, color: Colors.blueGrey);
      final breakableBrick = Brick(x: 100, y: 80, width: 40, height: 20, hp: 2, maxHp: 2, color: Colors.yellow);

      controller.bricks.addAll([steelBrick, heavySteel, breakableBrick]);
      final ball = Ball(x: 180, y: 400, vx: 100, vy: 100, radius: 7);
      controller.balls.add(ball);

      controller.endgameStallTimer = 6.5;
      controller.update(0.05);

      expect(steelBrick.isAlive, isTrue);
      expect(heavySteel.isAlive, isTrue);
      expect(breakableBrick.isAlive, isFalse, reason: 'Lightning must target breakable brick and ignore steel');
    });

    test('Anti-Stall: Boss brick takes damage without instakill', () {
      controller.status = GameStatus.playing;
      controller.antiStallLightningDelay = 6.5;
      controller.bricks.clear();
      controller.balls.clear();

      final bossBrick = Brick(
        x: 100,
        y: 80,
        width: 80,
        height: 40,
        hp: 50,
        maxHp: 50,
        isBoss: true,
        color: Colors.red,
      );
      controller.bricks.add(bossBrick);
      final ball = Ball(x: 180, y: 400, vx: 100, vy: 100, radius: 7);
      controller.balls.add(ball);

      controller.endgameStallTimer = 6.5;
      controller.update(0.05);

      expect(bossBrick.isAlive, isTrue, reason: 'Boss must not be instakilled by anti-stall lightning');
      expect(bossBrick.hp, lessThan(50));
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
