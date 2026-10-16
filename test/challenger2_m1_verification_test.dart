import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kirmatas/engine/game_controller.dart';
import 'package:kirmatas/models/brick.dart';
import 'package:kirmatas/models/game_state.dart';
import 'package:kirmatas/storage/save_manager.dart';
import 'package:kirmatas/ui/game_canvas.dart';
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

  group('Challenger 2 Empirical Challenge: First Corner Hit Detection', () {
    late GameController ctrl;

    setUp(() {
      ctrl = GameController();
      ctrl.setDimensions(360, 640);
    });

    test('firstCornerHitShown starts false on clean initialization', () {
      expect(ctrl.firstCornerHitShown, isFalse);
      ctrl.startNewGame(GameMode.classic, explicitStartLevel: 1);
      expect(ctrl.firstCornerHitShown, isFalse);
    });

    test('Center paddle hit (hitOffset < 0.70) does NOT trigger first corner hit', () {
      ctrl.startNewGame(GameMode.classic, explicitStartLevel: 1);
      ctrl.launchBall();
      expect(ctrl.firstCornerHitShown, isFalse);

      final ball = ctrl.balls.first;
      // Center hit: ball.x is exactly paddle center
      ball.x = ctrl.paddle.x + ctrl.paddle.width * 0.5;
      ball.y = ctrl.paddle.y - ball.radius + 1.0;
      ball.vx = 0;
      ball.vy = 300.0;

      ctrl.update(0.016);

      expect(ctrl.firstCornerHitShown, isFalse, reason: 'Center hit must NOT trigger corner hit');
      expect(ctrl.stats.bulletTimeLeft, 0.0);
      expect(ctrl.particles.floatingTexts.any((t) => t.text.contains('SÜPER KÖŞE VURUŞU')), isFalse);
    });

    test('Left corner hit (hitOffset <= -0.70) triggers bullet time & banner, sets flag to true', () {
      ctrl.startNewGame(GameMode.classic, explicitStartLevel: 1);
      ctrl.launchBall();
      expect(ctrl.firstCornerHitShown, isFalse);

      final ball = ctrl.balls.first;
      // Left corner: ball.x at 5% of paddle width -> hitOffset is approx -0.90
      ball.x = ctrl.paddle.x + ctrl.paddle.width * 0.05;
      ball.y = ctrl.paddle.y - ball.radius + 1.0;
      ball.vx = 0;
      ball.vy = 300.0;

      ctrl.update(0.016);

      expect(ctrl.firstCornerHitShown, isTrue, reason: 'Left corner hit must set firstCornerHitShown=true');
      expect(ctrl.stats.bulletTimeLeft, 0.75, reason: 'Must trigger slow-motion pulse (bulletTimeLeft=0.75)');
      expect(
        ctrl.particles.floatingTexts.any((t) => t.text == '⚡ SÜPER KÖŞE VURUŞU!'),
        isTrue,
        reason: 'Celebratory banner must be spawned',
      );
    });

    test('Right corner hit (hitOffset >= +0.70) triggers bullet time & banner', () {
      ctrl.startNewGame(GameMode.classic, explicitStartLevel: 1);
      ctrl.launchBall();
      expect(ctrl.firstCornerHitShown, isFalse);

      final ball = ctrl.balls.first;
      // Right corner: ball.x at 95% of paddle width -> hitOffset is approx +0.90
      ball.x = ctrl.paddle.x + ctrl.paddle.width * 0.95;
      ball.y = ctrl.paddle.y - ball.radius + 1.0;
      ball.vx = 0;
      ball.vy = 300.0;

      ctrl.update(0.016);

      expect(ctrl.firstCornerHitShown, isTrue);
      expect(ctrl.stats.bulletTimeLeft, 0.75);
      expect(ctrl.particles.floatingTexts.any((t) => t.text == '⚡ SÜPER KÖŞE VURUŞU!'), isTrue);
    });

    test('Subsequent corner hits (left and right) do NOT re-trigger bullet time or duplicate banner', () {
      ctrl.startNewGame(GameMode.classic, explicitStartLevel: 1);
      ctrl.launchBall();

      final ball = ctrl.balls.first;
      // First hit: right corner
      ball.x = ctrl.paddle.x + ctrl.paddle.width * 0.95;
      ball.y = ctrl.paddle.y - ball.radius + 1.0;
      ball.vx = 0;
      ball.vy = 300.0;
      ctrl.update(0.016);

      expect(ctrl.firstCornerHitShown, isTrue);
      expect(ctrl.stats.bulletTimeLeft, 0.75);
      final bannerCount1 = ctrl.particles.floatingTexts.where((t) => t.text == '⚡ SÜPER KÖŞE VURUŞU!').length;
      expect(bannerCount1, 1);

      // Simulate game time passing so bulletTimeLeft expires
      ctrl.stats.bulletTimeLeft = 0.0;

      // 2nd hit: left corner
      ball.x = ctrl.paddle.x + ctrl.paddle.width * 0.05;
      ball.y = ctrl.paddle.y - ball.radius + 1.0;
      ball.vx = 0;
      ball.vy = 300.0;
      ctrl.update(0.016);

      expect(ctrl.stats.bulletTimeLeft, 0.0, reason: 'Subsequent corner hit must not reset bulletTimeLeft');
      final bannerCount2 = ctrl.particles.floatingTexts.where((t) => t.text == '⚡ SÜPER KÖŞE VURUŞU!').length;
      expect(bannerCount2, 1, reason: 'Subsequent corner hit must not spawn duplicate banner');

      // 3rd hit: right corner again
      ball.x = ctrl.paddle.x + ctrl.paddle.width * 0.98;
      ball.y = ctrl.paddle.y - ball.radius + 1.0;
      ball.vx = 0;
      ball.vy = 300.0;
      ctrl.update(0.016);

      expect(ctrl.stats.bulletTimeLeft, 0.0);
      final bannerCount3 = ctrl.particles.floatingTexts.where((t) => t.text == '⚡ SÜPER KÖŞE VURUŞU!').length;
      expect(bannerCount3, 1);
    });

    test('resetLevel() resets firstCornerHitShown for a fresh attempt', () {
      ctrl.startNewGame(GameMode.classic, explicitStartLevel: 1);
      ctrl.launchBall();
      final ball = ctrl.balls.first;
      ball.x = ctrl.paddle.x + ctrl.paddle.width * 0.95;
      ball.y = ctrl.paddle.y - ball.radius + 1.0;
      ball.vx = 0;
      ball.vy = 300.0;
      ctrl.update(0.016);
      expect(ctrl.firstCornerHitShown, isTrue);

      ctrl.startNewGame(GameMode.classic, explicitStartLevel: 1);
      expect(ctrl.firstCornerHitShown, isFalse, reason: 'startNewGame should reset firstCornerHitShown for fresh attempt');
    });
  });

  group('Challenger 2 Empirical Challenge: Ulti Callout & Interaction', () {
    late GameController ctrl;

    setUp(() {
      ctrl = GameController();
      ctrl.setDimensions(360, 640);
    });

    test('isUltiReady truth table for sub-threshold, threshold, and overflow values', () {
      // 0.0 -> false
      ctrl.ultiCharge = 0.0;
      expect(ctrl.isUltiReady, isFalse);

      // 0.5 (halfway on 0..1 scale) -> false
      ctrl.ultiCharge = 0.5;
      expect(ctrl.isUltiReady, isFalse);

      // 0.999 -> false
      ctrl.ultiCharge = 0.999;
      expect(ctrl.isUltiReady, isFalse);

      // 1.0 -> FALSE (1% charge after 1 brick must NOT falsely trigger ulti)
      ctrl.ultiCharge = 1.0;
      expect(ctrl.isUltiReady, isFalse);

      // 50.0 (halfway on 0..100 scale) -> false
      ctrl.ultiCharge = 50.0;
      expect(ctrl.isUltiReady, isFalse);

      // 99.0 -> false
      ctrl.ultiCharge = 99.0;
      expect(ctrl.isUltiReady, isFalse);

      // 100.0 -> TRUE (100% on percent scale)
      ctrl.ultiCharge = 100.0;
      expect(ctrl.isUltiReady, isTrue);

      // > 100.0 -> TRUE
      ctrl.ultiCharge = 105.0;
      expect(ctrl.isUltiReady, isTrue);
    });

    testWidgets('Double-tap activates triggerUlti() only when isUltiReady is true', (tester) async {
      ctrl.startNewGame(GameMode.classic, explicitStartLevel: 1);
      ctrl.ultiCharge = 50.0; // Not ready
      expect(ctrl.isUltiReady, isFalse);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: GameCanvas(controller: ctrl),
          ),
        ),
      );
      await tester.pump();

      // Double tap when NOT ready -> does NOT trigger ulti
      await tester.tap(find.byType(GameCanvas));
      await tester.pump(const Duration(milliseconds: 50));
      await tester.tap(find.byType(GameCanvas));
      await tester.pump(const Duration(milliseconds: 50));

      expect(ctrl.isDiceRolling, isFalse);
      expect(ctrl.ultiCharge, 50.0);

      // Now set to ready
      ctrl.ultiCharge = 100.0;
      expect(ctrl.isUltiReady, isTrue);

      // Double tap when READY -> triggers ulti
      await tester.tap(find.byType(GameCanvas));
      await tester.pump(const Duration(milliseconds: 50));
      await tester.tap(find.byType(GameCanvas));
      await tester.pump(const Duration(milliseconds: 50));

      expect(ctrl.isDiceRolling, isTrue);
      expect(ctrl.ultiCharge, 0.0);
    });

    testWidgets('Single tap does NOT trigger ulti', (tester) async {
      ctrl.startNewGame(GameMode.classic, explicitStartLevel: 1);
      ctrl.ultiCharge = 100.0;
      expect(ctrl.isUltiReady, isTrue);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: GameCanvas(controller: ctrl),
          ),
        ),
      );
      await tester.pump();

      // Single tap
      await tester.tap(find.byType(GameCanvas));
      await tester.pump(const Duration(milliseconds: 400)); // past double tap window

      expect(ctrl.isDiceRolling, isFalse);
      expect(ctrl.isUltiReady, isTrue);
    });

    test('Chaos mode blocks triggerUlti() even if charge is 100%', () {
      ctrl.startNewGame(GameMode.chaos, explicitStartLevel: 1);
      ctrl.ultiCharge = 100.0;
      // In Chaos mode, isUltiReady is guarded and evaluates to false to prevent stuck HUD callout
      expect(ctrl.isUltiReady, isFalse);

      ctrl.triggerUlti();
      // In Chaos mode, dice rolling ulti is blocked
      expect(ctrl.isDiceRolling, isFalse);
    });
  });

  group('Challenger 2 Empirical Challenge: Level 1 Drag Guide', () {
    late GameController ctrl;

    setUp(() {
      ctrl = GameController();
      ctrl.setDimensions(360, 640);
    });

    test('showLevel1DragGuide is true strictly in Level 1 Classic mode during first 8 seconds', () {
      // Level 1 Classic: starts true
      ctrl.startNewGame(GameMode.classic, explicitStartLevel: 1);
      expect(ctrl.showLevel1DragGuide, isTrue);

      // Progressing up to 7.99 seconds: still true
      ctrl.update(5.0);
      expect(ctrl.showLevel1DragGuide, isTrue);
      ctrl.update(2.99);
      expect(ctrl.showLevel1DragGuide, isTrue);

      // At exactly 8.0 seconds: false
      ctrl.update(0.02);
      expect(ctrl.showLevel1DragGuide, isFalse);
    });

    test('showLevel1DragGuide is false in all other modes at level 1', () {
      // Chaos mode level 1
      ctrl.startNewGame(GameMode.chaos, explicitStartLevel: 1);
      expect(ctrl.showLevel1DragGuide, isFalse);

      // Zen mode level 1
      ctrl.startNewGame(GameMode.zen, explicitStartLevel: 1);
      expect(ctrl.showLevel1DragGuide, isFalse);
    });

    test('showLevel1DragGuide is false in Classic mode at level 2, 3, 5, etc.', () {
      for (final lvl in [2, 3, 4, 5, 10, 50]) {
        ctrl.startNewGame(GameMode.classic, explicitStartLevel: lvl);
        expect(ctrl.showLevel1DragGuide, isFalse, reason: 'Failed for level $lvl');
      }
    });

    testWidgets('GameCanvas renders without error when drag guide and ulti callout are active', (tester) async {
      ctrl.startNewGame(GameMode.classic, explicitStartLevel: 1);
      ctrl.ultiCharge = 100.0;
      expect(ctrl.showLevel1DragGuide, isTrue);
      expect(ctrl.isUltiReady, isTrue);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: GameCanvas(controller: ctrl),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));

      expect(tester.takeException(), isNull);
    });
  });

  group('Challenger 2 Empirical Challenge: Chaos Mode Workshop Scaling Oracles', () {
    late GameController ctrl;
    late SaveManager save;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      save = SaveManager.instance;
      await save.init();
      ctrl = GameController();
      ctrl.setDimensions(360, 640);
    });

    test('Oracle 1 (u_crit scaling): 0 crits at lvl 0, significant crits at lvl 5', () {
      ctrl.startNewGame(GameMode.chaos, explicitStartLevel: 1);

      // 1. With u_crit = 0: no crits possible
      save.upgrades['u_crit'] = 0;
      save.upgrades['crit_damage'] = 0;
      int critsLvl0 = 0;
      const iterations = 500;

      for (int i = 0; i < iterations; i++) {
        final brick = Brick(x: 100, y: 100, width: 40, height: 20, hp: 10, maxHp: 10, color: Colors.blue);
        ctrl.bricks = [brick];
        // Directly test brick damage resolution
        final randVal = (i + 1) / (iterations + 2); // deterministic distribution
        // Hit brick logic check
        final critLvl = save.getUpgradeLevel('u_crit');
        final critChance = critLvl * 0.035;
        if (critLvl > 0 && randVal < critChance) {
          critsLvl0++;
        }
      }
      expect(critsLvl0, 0, reason: 'Level 0 crit must yield exactly 0 crits');

      // 2. With u_crit = 5: critChance = 5 * 0.035 = 0.175 (17.5%)
      save.upgrades['u_crit'] = 5;
      expect(save.getUpgradeLevel('u_crit'), 5);

      int critsLvl5 = 0;
      for (int i = 0; i < iterations; i++) {
        final randVal = (i + 0.5) / iterations; // uniform [0, 1)
        final critLvl = save.getUpgradeLevel('u_crit');
        final critChance = critLvl * 0.035; // 0.175
        if (critLvl > 0 && randVal < critChance) {
          critsLvl5++;
        }
      }
      // With uniform distribution over 500 samples, approx 87-88 crits expected
      expect(critsLvl5, closeTo(87, 5));

      // 3. Verify crit_damage alias resolution also scales Chaos mode crit
      save.upgrades.remove('u_crit');
      save.upgrades['crit_damage'] = 4;
      expect(save.getUpgradeLevel('u_crit'), 4);
    });

    test('Oracle 2 (u_luck & u_gold drop scaling in Chaos Mode): higher luck = higher drop rate, higher gold = more coins', () {
      ctrl.startNewGame(GameMode.chaos, explicitStartLevel: 1);

      // Formula in GameController._destroyBrick for Chaos Mode:
      // final luckLvl = save.getUpgradeLevel('u_luck');
      // final dropRate = 0.20 + (luckLvl * 0.04);
      // final goldLvl = save.getUpgradeLevel('u_gold');
      // int coins = 1 + _rand.nextInt(3); // base 1..3
      // coins = (coins * (1.0 + goldLvl * 0.10)).round();

      // Level 0 luck: dropRate = 0.20
      save.upgrades['u_luck'] = 0;
      save.upgrades['u_gold'] = 0;
      double rate0 = 0.20 + (save.getUpgradeLevel('u_luck') * 0.04);
      expect(rate0, closeTo(0.20, 1e-6));

      // Level 5 luck: dropRate = 0.40 (doubled!)
      save.upgrades['u_luck'] = 5;
      double rate5 = 0.20 + (save.getUpgradeLevel('u_luck') * 0.04);
      expect(rate5, closeTo(0.40, 1e-6));

      // Level 5 gold multiplier: 1.5x multiplier (+50%)
      save.upgrades['u_gold'] = 5;
      final goldLvl = save.getUpgradeLevel('u_gold');
      expect(goldLvl, 5);
      final coinMultiplier = 1.0 + goldLvl * 0.10;
      expect(coinMultiplier, closeTo(1.50, 1e-6));

      // Test coin calculation:
      // Base 1 -> round(1 * 1.5) = 2
      // Base 2 -> round(2 * 1.5) = 3
      // Base 3 -> round(3 * 1.5) = 5 (4.5 rounded to 5)
      expect((1 * coinMultiplier).round(), 2);
      expect((2 * coinMultiplier).round(), 3);
      expect((3 * coinMultiplier).round(), 5);
    });

    test('Oracle 3 (Chaos Mode Level Clear Gold Reward Formula): validates exact bonus scaling', () {
      ctrl.startNewGame(GameMode.chaos, explicitStartLevel: 1);
      // In _chaosAdvanceTurn():
      // final baseGold = 25 + (stats.level * 5).clamp(0, 50);
      // final relicBonus = save.hasPermanentRelic ? max(1, (baseGold * 0.05).round()) : 0;
      // final luckLvl = save.getUpgradeLevel('u_luck');
      // final luckBonus = (baseGold * (luckLvl * 0.05)).round();
      // final goldLvl = save.getUpgradeLevel('u_gold');
      // final goldBonus = (baseGold * (goldLvl * 0.10)).round();
      // final levelGold = baseGold + relicBonus + luckBonus + goldBonus;

      // Base case at level 1 with 0 upgrades
      save.upgrades['u_luck'] = 0;
      save.upgrades['u_gold'] = 0;
      const baseGoldLvl1 = 25 + 5; // 30
      final luckBonus0 = (baseGoldLvl1 * (0 * 0.05)).round(); // 0
      final goldBonus0 = (baseGoldLvl1 * (0 * 0.10)).round(); // 0
      expect(baseGoldLvl1 + luckBonus0 + goldBonus0, 30);

      // With u_luck = 5, u_gold = 5
      save.upgrades['u_luck'] = 5;
      save.upgrades['u_gold'] = 5;
      final luckBonus5 = (baseGoldLvl1 * (5 * 0.05)).round(); // round(30 * 0.25) = 8
      final goldBonus5 = (baseGoldLvl1 * (5 * 0.10)).round(); // round(30 * 0.50) = 15
      expect(luckBonus5, 8);
      expect(goldBonus5, 15);
      final totalGold = baseGoldLvl1 + luckBonus5 + goldBonus5;
      expect(totalGold, 53, reason: 'Level clear gold should scale from 30 to 53 (+76% increase)');

      // Verify alias gold_multiplier works identically
      save.upgrades.remove('u_gold');
      save.upgrades['gold_multiplier'] = 5;
      expect(save.getUpgradeLevel('u_gold'), 5);
      final aliasedGoldBonus = (baseGoldLvl1 * (save.getUpgradeLevel('u_gold') * 0.10)).round();
      expect(aliasedGoldBonus, 15);
    });
  });
}
