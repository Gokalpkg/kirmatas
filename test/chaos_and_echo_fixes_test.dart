import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:kirmatas/engine/game_controller.dart';
import 'package:kirmatas/models/brick.dart';
import 'package:kirmatas/models/game_state.dart';
import 'package:kirmatas/models/level_design.dart';
import 'package:kirmatas/models/sector_blessing.dart';
import 'package:kirmatas/storage/save_manager.dart';

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

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await SaveManager.instance.init();
  });

  group('Ghost Echo Non-Recursive Safety Tests', () {
    test('Ghost Echo triggers only 1 neighbor jump and never creates infinite chain reaction', () {
      final ctrl = GameController();
      ctrl.screenWidth = 360;
      ctrl.screenHeight = 640;
      ctrl.startNewGame(GameMode.classic);

      // Set ghost echo blessing
      ctrl.activeSectorBlessing = const SectorBlessing(
        type: SectorBlessingType.ghostEcho,
        id: 'ghost_echo',
        icon: Icons.blur_on,
        titleKey: 'blessing_ghost_title',
        descKey: 'blessing_ghost_desc',
        primaryColor: Color(0xFFB388FF),
        secondaryColor: Color(0xFF7C4DFF),
      );

      // Create a grid of 5 contiguous 1-HP bricks
      ctrl.bricks = [
        Brick(x: 100, y: 100, width: 40, height: 20, hp: 1, maxHp: 1, color: Colors.blue),
        Brick(x: 142, y: 100, width: 40, height: 20, hp: 1, maxHp: 1, color: Colors.blue),
        Brick(x: 184, y: 100, width: 40, height: 20, hp: 1, maxHp: 1, color: Colors.blue),
        Brick(x: 226, y: 100, width: 40, height: 20, hp: 1, maxHp: 1, color: Colors.blue),
        Brick(x: 268, y: 100, width: 40, height: 20, hp: 1, maxHp: 1, color: Colors.blue),
      ];

      expect(ctrl.bricks.where((b) => b.isAlive).length, equals(5));

      // Hit first brick
      ctrl.hitBrickForTest(ctrl.bricks[0]);

      // Exactly 2 bricks should be destroyed (target + 1 echo neighbor), NOT all 5!
      final aliveCount = ctrl.bricks.where((b) => b.isAlive).length;
      expect(aliveCount, equals(3), reason: 'Echo should destroy exactly 1 neighbor, leaving 3 bricks alive');
    });
  });

  group('Chaos Mode (BBTAN Loop) Stock Preservation Tests', () {
    test('Clearing remaining solid bricks preserves accumulated ball stock instead of resetting to 3', () {
      final ctrl = GameController();
      ctrl.screenWidth = 360;
      ctrl.screenHeight = 640;
      ctrl.startNewGame(GameMode.chaos);

      // Player has accumulated 45 balls from pickups
      ctrl.chaosStock = 45;
      ctrl.chaosPendingExtraBalls = 5;

      // Single brick remains on board
      final lastBrick = Brick(x: 100, y: 100, width: 40, height: 20, hp: 1, maxHp: 1, color: Colors.blue);
      ctrl.bricks = [lastBrick];

      // Simulate volley finish and turn advance
      ctrl.status = GameStatus.playing;
      ctrl.chaosToLaunch = 0;
      ctrl.chaosReturned = 1;
      ctrl.balls.clear();

      // Hit last brick to trigger level clear
      ctrl.hitBrickForTest(lastBrick);

      // Trigger chaos volley / advance logic
      ctrl.update(0.016);

      // Verify ball stock is PRESERVED (45 + 5 = 50), strictly NOT reset to 3!
      expect(ctrl.chaosStock, equals(50), reason: 'Chaos stock must preserve 45 + 5 = 50 balls on board clear');
      expect(ctrl.stats.level, equals(2));
    });

    test('Chaos bricks scale dynamically with wave progression and spawn tank bricks', () {
      final rowWave1 = LevelDesign.buildChaosRow(1, 0, 360);
      final solidWave1 = rowWave1.where((b) => !b.isBallPickup).toList();
      for (final b in solidWave1) {
        expect(b.hp, lessThanOrEqualTo(3));
      }

      // Wave 60 should have significantly higher HP bricks (50-130 HP)
      final rowWave60 = LevelDesign.buildChaosRow(60, 0, 360);
      final solidWave60 = rowWave60.where((b) => !b.isBallPickup).toList();
      expect(solidWave60.any((b) => b.hp >= 50), isTrue, reason: 'High wave bricks must have challenging HP');
    });
  });
}
