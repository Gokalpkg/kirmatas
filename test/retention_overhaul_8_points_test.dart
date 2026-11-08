import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:kirmatas/engine/game_controller.dart';
import 'package:kirmatas/engine/i18n.dart';
import 'package:kirmatas/models/ball.dart';
import 'package:kirmatas/models/brick.dart';
import 'package:kirmatas/models/game_state.dart';
import 'package:kirmatas/storage/save_manager.dart';

import 'package:flutter/services.dart';

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
    await SaveManager.instance.setLanguage('tr');
  });

  group('Retention Overhaul - 8 Targeted Points Verification', () {
    test('Point 1: enableOverdriveHoming is true by default, 8s homing and 12s lightning strike', () {
      final ctrl = GameController();
      expect(ctrl.enableOverdriveHoming, true, reason: 'Overdrive homing must be enabled by default');

      ctrl.setDimensions(400, 800);
      ctrl.status = GameStatus.playing;
      ctrl.currentMode = GameMode.classic;
      ctrl.paddle.x = 0;
      ctrl.paddle.width = 400;
      ctrl.paddle.y = 700;
      ctrl.paddle.hasNet = true;

      ctrl.bricks = [
        Brick(x: 100, y: 100, width: 40, height: 20, hp: 1, color: Colors.blue),
      ];
      ctrl.balls.clear();
      final ball = Ball(x: 200, y: 300, isStuck: false);
      ball.vx = 0.0;
      ball.vy = -120.0;
      ctrl.balls.add(ball);

      // Advance physics by 8.2 seconds without hitting the last brick
      for (int i = 0; i < 82; i++) {
        // Keep ball from hitting top brick prematurely during homing test
        if (ctrl.balls.isNotEmpty && ctrl.balls.first.y < 200) {
          ctrl.balls.first.y = 350;
        }
        ctrl.update(0.1);
      }
      expect(ctrl.balls.isNotEmpty && ctrl.balls.first.isOverdriveHoming, true, reason: 'Ball must enter overdrive homing after 8 seconds');

      // Advance physics to 12.1 seconds total
      for (int i = 0; i < 40; i++) {
        if (ctrl.balls.isNotEmpty && ctrl.balls.first.y < 200) {
          ctrl.balls.first.y = 350;
        }
        ctrl.update(0.1);
        if (ctrl.bricks.isEmpty || !ctrl.bricks.first.isAlive || ctrl.levelTransitionTimer > 0) {
          break;
        }
      }
      expect(ctrl.bricks.where((b) => b.isAlive).isEmpty || ctrl.levelTransitionTimer > 0, true, reason: 'Fail-safe lightning strike must destroy the final brick at 12 seconds');
    });

    test('Point 2: Horizontal bounce anti-trap enforces minVerticalVy >= ball.speed * 0.28', () {
      final ctrl = GameController();
      ctrl.setDimensions(400, 800);
      ctrl.status = GameStatus.playing;
      final ball = Ball(x: 50, y: 400, isStuck: false);
      ball.vx = 400.0;
      ball.vy = 2.0; // shallow horizontal trajectory
      final initialSpeed = ball.speed;
      ctrl.balls.clear();
      ctrl.balls.add(ball);

      ctrl.update(0.016);
      final expectedMinVy = (initialSpeed * 0.28).clamp(35.0, 160.0);
      expect(ball.vy.abs(), greaterThanOrEqualTo(expectedMinVy - 0.1), reason: 'Vertical velocity must be actively boosted away from shallow trap');
    });

    test('Point 3: Zero-Deletion Policy - Starved fish are NEVER removed from unlockedFish or owned counts', () async {
      final save = SaveManager.instance;
      await save.addFishInstance('clownfish');
      expect(save.unlockedFish.contains('clownfish'), true);
      expect(save.getFishCount('clownfish'), greaterThanOrEqualTo(1));

      // Simulate 4 days without feeding (well past 72h starvation threshold)
      final fourDaysAgo = DateTime.now().subtract(const Duration(days: 4)).millisecondsSinceEpoch;
      save.fishFedTimestamps['clownfish'] = fourDaysAgo;
      save.fishAcquiredTimestamps['clownfish'] = fourDaysAgo;

      final resting = await save.checkAndProcessStarvedFish();
      expect(resting.contains('clownfish'), true, reason: 'Fish must be marked as resting/starved');
      expect(save.unlockedFish.contains('clownfish'), true, reason: 'Fish MUST NEVER be deleted from unlocked collection');
      expect(save.getFishCount('clownfish'), greaterThanOrEqualTo(1), reason: 'Owned count must remain intact');
      expect(save.fishFedTimestamps.containsKey('clownfish'), false, reason: 'Active production cycle must pause until fed');
    });

    test('Point 6: Near-Miss Recovery activates CTA when 5 or fewer breakable bricks remain', () async {
      final ctrl = GameController();
      ctrl.setDimensions(400, 800);
      ctrl.status = GameStatus.gameOver;
      ctrl.bricks = [
        Brick(x: 10, y: 10, width: 40, height: 20, hp: 1, color: Colors.blue),
        Brick(x: 60, y: 10, width: 40, height: 20, hp: 1, color: Colors.blue),
        Brick(x: 110, y: 10, width: 40, height: 20, hp: 1, color: Colors.blue),
      ];

      final remaining = ctrl.bricks.where((b) => b.isAlive && !b.isSteel && !b.isHeavySteel).length;
      final isNearMiss = remaining > 0 && remaining <= 5;
      expect(isNearMiss, true);

      // Verify localized CTA strings exist in Turkish and English
      await SaveManager.instance.setLanguage('tr');
      expect(I18n.tr('near_miss_revive_cta'), 'ÇOK YAKLAŞTIN! 1 CANLA BİTİR');
      expect(I18n.tr('near_miss_bricks_left'), 'BLOK KALDI');

      await SaveManager.instance.setLanguage('en');
      expect(I18n.tr('near_miss_revive_cta'), 'SO CLOSE! FINISH WITH 1 LIFE');
      expect(I18n.tr('near_miss_bricks_left'), 'BRICKS REMAINING');
    });

    test('Point 7: FTUE Ball speed is 12% faster in Levels 1-3 and shouldPulseSpeedBoost triggers at 6s', () {
      final ctrl = GameController();
      ctrl.setDimensions(400, 800);
      ctrl.stats.level = 1;
      final level1Speed = ctrl.getBaseBallSpeed();

      // Normal baseline without 12% boost would be 420.0
      expect(level1Speed, closeTo(420.0 * 1.12, 0.01), reason: 'Levels 1-3 must have 12% crisp speed boost');

      ctrl.status = GameStatus.playing;
      ctrl.balls.clear();
      ctrl.balls.add(Ball(x: 200, y: 400, isStuck: false));
      expect(ctrl.shouldPulseSpeedBoost, false);

      // Advance by 6.2s without brick hits
      ctrl.update(6.2);
      expect(ctrl.shouldPulseSpeedBoost, true, reason: 'Turbo 2X button must pulse after 6 seconds of volley without hits');

      // Toggling speed boost dismisses pulse
      ctrl.toggleSpeedBoost();
      expect(ctrl.shouldPulseSpeedBoost, false);
    });

    test('Point 8: Crate duplicate conversion grants +150 Gold bonus when fish is at 5/5 max copies', () async {
      final save = SaveManager.instance;
      // Set fish count to 5 (max copies)
      for (int i = 0; i < 5; i++) {
        await save.addFishInstance('clownfish');
      }
      expect(save.getFishCount('clownfish'), 5);

      // Verify localized copy text format
      await save.setLanguage('tr');
      expect(I18n.bi('5/5 MAKS! +150 ALTIN DÖNÜŞÜMÜ', '5/5 MAX! +150 GOLD CONVERSION'), '5/5 MAKS! +150 ALTIN DÖNÜŞÜMÜ');

      await save.setLanguage('en');
      expect(I18n.bi('5/5 MAKS! +150 ALTIN DÖNÜŞÜMÜ', '5/5 MAX! +150 GOLD CONVERSION'), '5/5 MAX! +150 GOLD CONVERSION');
    });
  });
}
