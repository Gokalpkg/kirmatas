import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:kirmatas/config/balance_config.dart';
import 'package:kirmatas/engine/game_controller.dart';
import 'package:kirmatas/models/ball.dart';
import 'package:kirmatas/models/brick.dart';
import 'package:kirmatas/models/game_state.dart';
import 'package:kirmatas/storage/save_manager.dart';
import 'package:kirmatas/ui/kaunos_ui.dart';

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
    SaveManager.instance.resetForTesting();
    await SaveManager.instance.init();
  });

  group('FAZ 2, 3 & 4 Master Verification Suite', () {
    test('FAZ 4.2: FixedTrailRingBuffer O(1) pushFront, insert(0), and capacity wrap-around', () {
      final ring = FixedTrailRingBuffer();
      expect(ring.isEmpty, isTrue);

      for (int i = 1; i <= 6; i++) {
        ring.pushFront(TrailPoint(Offset(i.toDouble(), i * 10.0), 1.0), 4);
      }

      // Max cap passed is 4, so newest 4 elements (6, 5, 4, 3) remain in order
      expect(ring.length, 4);
      expect(ring[0].position.dx, 6.0);
      expect(ring[1].position.dx, 5.0);
      expect(ring[2].position.dx, 4.0);
      expect(ring[3].position.dx, 3.0);

      final last = ring.removeLast();
      expect(last.position.dx, 3.0);
      expect(ring.length, 3);
    });

    test('MEKANİK FAZ 1.1 & 3.3: Fast-Forward Speed Toggle cycles 1x -> 2x -> 4x -> 1x', () {
      final controller = GameController();
      expect(controller.userSpeedMultiplier, 1.0);

      controller.cycleFastForwardSpeed();
      expect(controller.userSpeedMultiplier, 2.0);

      controller.cycleFastForwardSpeed();
      expect(controller.userSpeedMultiplier, 4.0);

      controller.cycleFastForwardSpeed();
      expect(controller.userSpeedMultiplier, 1.0);
      controller.dispose();
    });

    test('MEKANİK FAZ 1.2: Tag & Trigger Synergy 1 (Termal Şok) shatters frozen brick and blasts neighbors', () {
      final controller = GameController();
      controller.screenWidth = 400;
      controller.screenHeight = 700;
      controller.startNewGame(GameMode.classic);
      controller.status = GameStatus.playing;

      final frozenTarget = Brick(
        x: 150,
        y: 200,
        width: 48,
        height: 22,
        hp: 10,
        maxHp: 10,
        color: Colors.cyan,
        isFrozen: true,
        frozenTimer: 5.0,
      );

      final neighbor = Brick(
        x: 205,
        y: 200,
        width: 48,
        height: 22,
        hp: 5,
        maxHp: 5,
        color: Colors.blue,
      );

      final farAnchor = Brick(
        x: 10,
        y: 50,
        width: 48,
        height: 22,
        hp: 20,
        maxHp: 20,
        color: Colors.grey,
      );

      controller.bricks
        ..clear()
        ..addAll([frozenTarget, neighbor, farAnchor]);

      final fireBall = Ball(
        x: 174,
        y: 225,
        vx: 0,
        vy: -300,
        radius: 7,
        isStuck: false,
        isFireball: true,
      );
      controller.balls
        ..clear()
        ..add(fireBall);

      controller.update(0.016);

      // Frozen brick should be shattered immediately (!isAlive) and neighbor should take 3 splash damage
      expect(frozenTarget.isAlive, isFalse);
      expect(neighbor.hp, lessThanOrEqualTo(2));
      controller.dispose();
    });

    test('MEKANİK FAZ 2.2: Gold Piñata leaks gold on hit and bursts +60 gold + 1 pearl on destroy', () {
      final controller = GameController();
      controller.screenWidth = 400;
      controller.screenHeight = 700;
      controller.startNewGame(GameMode.classic);
      controller.status = GameStatus.playing;

      final pinata = Brick(
        x: 150,
        y: 200,
        width: 48,
        height: 22,
        hp: 1,
        maxHp: 3,
        color: const Color(0xFFFFD54F),
        isGoldPinata: true,
      );
      final anchor = Brick(
        x: 10,
        y: 50,
        width: 48,
        height: 22,
        hp: 10,
        maxHp: 10,
        color: Colors.blue,
      );
      controller.bricks
        ..clear()
        ..addAll([pinata, anchor]);

      final startGold = SaveManager.instance.gold;
      final startPearls = SaveManager.instance.pearls;

      final b = Ball(x: 174, y: 224, vx: 0, vy: -300, radius: 7, isStuck: false);
      controller.balls
        ..clear()
        ..add(b);

      controller.update(0.016);

      expect(pinata.isAlive, isFalse);
      expect(
        SaveManager.instance.gold - startGold,
        greaterThanOrEqualTo(BalanceConfig.goldPinataHitGold + BalanceConfig.goldPinataDestroyGold),
      );
      expect(SaveManager.instance.pearls, startPearls + BalanceConfig.goldPinataDestroyPearls);
      controller.dispose();
    });

    test('FAZ 4.3 & Yasa 6: SaveManager buyMaxStatUpgrade & cratePityCounter work atomically', () async {
      final save = SaveManager.instance;
      save.totalGold = 5000;

      final calc = save.calculateMaxAffordableUpgrades('paddle_width');
      expect(calc.levels, greaterThan(1));
      expect(calc.totalCost, lessThanOrEqualTo(5000));

      final bought = await save.buyMaxStatUpgrade('paddle_width');
      expect(bought, calc.levels);
      expect(save.getUpgradeLevel('paddle_width'), bought);
      expect(save.gold, 5000 - calc.totalCost);

      // Crate Pity Counter verification
      expect(save.cratePityCounter, 0);
      for (int i = 0; i < 14; i++) {
        await save.updateCratePity(wasLegendary: false);
      }
      expect(save.cratePityCounter, 14);
      await save.updateCratePity(wasLegendary: true);
      expect(save.cratePityCounter, 0);
    });

    testWidgets('FAZ 2.3: KaunosPixelButton renders tactile bevel and fires onTap', (tester) async {
      bool tapped = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: KaunosPixelButton(
                onTap: () => tapped = true,
                child: const Text('HEMEN OYNA'),
              ),
            ),
          ),
        ),
      );

      expect(find.text('HEMEN OYNA'), findsOneWidget);
      await tester.tap(find.byType(KaunosPixelButton));
      await tester.pump();
      expect(tapped, isTrue);
    });
  });
}
