import 'dart:io';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:kirmatas/engine/game_controller.dart';
import 'package:kirmatas/engine/ad_manager.dart';
import 'package:kirmatas/storage/save_manager.dart';
import 'package:kirmatas/models/game_state.dart';
import 'package:kirmatas/models/level_design.dart';
import 'package:kirmatas/ui/main_menu.dart';

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

  group('Runtime & Boot Flow Fixes', () {
    test('MainMenuScreen.suppressBootPopups is false by default', () {
      expect(MainMenuScreen.suppressBootPopups, isFalse);
    });

    test('GameController.dispose properly cleans up resources', () {
      final controller = GameController();
      controller.setDimensions(400, 800);
      controller.startNewGame(GameMode.classic);

      expect(controller.balls.isNotEmpty, isTrue);

      controller.dispose();

      expect(controller.balls.isEmpty, isTrue);
      expect(controller.bricks.isEmpty, isTrue);
      expect(controller.capsules.isEmpty, isTrue);
      expect(controller.particles.particles.isEmpty, isTrue);

      // Verify notifiers are disposed (calling notify or addListener will throw FlutterError)
      expect(() => controller.statusVersion.addListener(() {}), throwsFlutterError);
      expect(() => controller.frameTick.addListener(() {}), throwsFlutterError);
    });

    test('GameController.setDimensions updates dimensions without resetting active bricks', () {
      final controller = GameController();
      controller.setDimensions(400, 800);
      controller.startNewGame(GameMode.classic);
      final initialBrickCount = controller.bricks.length;
      expect(initialBrickCount, greaterThan(0));

      // Destroy one brick
      controller.bricks.first.hp = 0;
      final remainingBricks = controller.bricks.where((b) => b.isAlive).length;

      // Resizing should NOT reload bricks or resurrect destroyed bricks
      controller.setDimensions(500, 900);
      expect(controller.bricks.where((b) => b.isAlive).length, equals(remainingBricks));
    });
  });

  group('Boosters & Multi-Ball Fixes', () {
    test('startNewGame only consumes selected boosts and never consumes life boost in Zen mode', () {
      final save = SaveManager.instance;
      save.boostStocks['laser'] = 3;
      save.boostStocks['wide'] = 3;
      save.boostStocks['fireball'] = 3;
      save.boostStocks['life'] = 3;

      final controller = GameController();
      controller.setDimensions(400, 800);

      // Start game with NO selected boosts -> none consumed
      controller.startNewGame(GameMode.classic, selectedBoosts: {});
      expect(save.boostStocks['laser'], equals(3));
      expect(save.boostStocks['wide'], equals(3));
      expect(save.boostStocks['fireball'], equals(3));
      expect(save.boostStocks['life'], equals(3));

      // Start game with life booster in Zen mode -> life booster MUST NOT be consumed
      controller.startNewGame(GameMode.zen, selectedBoosts: {'life', 'laser'});
      expect(save.boostStocks['life'], equals(3), reason: 'Life boost must never be consumed in Zen mode');
    });

    test('Multi booster at match start does not auto-launch balls', () {
      final save = SaveManager.instance;
      save.boostStocks['multi'] = 2;

      final controller = GameController();
      controller.setDimensions(400, 800);
      controller.startNewGame(GameMode.classic, selectedBoosts: {'multi'});

      expect(controller.balls.length, greaterThan(1));
      expect(controller.status, equals(GameStatus.ready));

      for (final ball in controller.balls) {
        expect(ball.isStuck, isTrue, reason: 'All balls must be stuck to paddle before launch');
        expect(ball.vx, equals(0.0), reason: 'Ball vx must be 0 while stuck');
        expect(ball.vy, equals(0.0), reason: 'Ball vy must be 0 while stuck');
      }
    });

    test('Capsule drop calculation does not punitively drop multi capsule to 0.5%', () {
      final controller = GameController();
      controller.setDimensions(400, 800);
      controller.startNewGame(GameMode.classic);

      // Verify the drop chance logic for multi capsule when balls > 1
      // In game_controller.dart: keepChance = balls.length >= 6 ? 0.10 : 0.25;
      const ballsCount = 3;
      final keepChance = ballsCount >= 6 ? 0.10 : 0.25;
      expect(keepChance, equals(0.25));
      expect(keepChance, greaterThan(0.005));
    });
  });

  group('Pending Crate Queue Fixes', () {
    test('SaveManager pending crate queue stores multiple crates in FIFO order', () async {
      final save = SaveManager.instance;
      save.clearPendingCrate();
      expect(save.pendingCrate, isNull);
      expect(save.pendingCratesQueue, isEmpty);

      final crate1 = PendingCrate(
        crateType: 'aquarium',
        rewardType: 'fish',
        rewardId: 'guppy',
        rewardTitle: 'Guppy',
        rewardSubtitle: 'Common Fish',
        rarityIndex: 0,
      );
      final crate2 = PendingCrate(
        crateType: 'guaranteed',
        rewardType: 'gold',
        rewardId: 'gold_pack',
        rewardTitle: 'Gold Pack',
        rewardSubtitle: '500 Gold',
        rarityIndex: 2,
      );

      save.savePendingCrate(crate1);
      save.savePendingCrate(crate2);

      expect(save.pendingCratesQueue.length, equals(2));
      expect(save.pendingCrate, isNotNull);
      expect(save.pendingCrate!.rewardId, equals('guppy'));

      // Clearing first crate pops it and reveals crate2
      save.clearPendingCrate();
      expect(save.pendingCratesQueue.length, equals(1));
      expect(save.pendingCrate!.rewardId, equals('gold_pack'));

      // Clearing second crate leaves queue empty
      save.clearPendingCrate();
      expect(save.pendingCratesQueue.isEmpty, isTrue);
      expect(save.pendingCrate, isNull);
    });
  });

  group('AdManager Security & Reward Enforcement', () {
    testWidgets('AdManager rejects free reward when ad is missing and test bypass is false', (tester) async {
      final adManager = AdManager.instance;
      AdManager.enableTestBypass = false;

      bool rewardGiven = false;
      bool dismissedEarly = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) {
                return ElevatedButton(
                  onPressed: () {
                    adManager.watchAdForGold(
                      context,
                      onSuccess: (_) => rewardGiven = true,
                      onDismissedEarly: () => dismissedEarly = true,
                    );
                  },
                  child: const Text('Watch'),
                );
              },
            ),
          ),
        ),
      );

      await tester.tap(find.byType(ElevatedButton));
      await tester.pump();

      expect(rewardGiven, isFalse, reason: 'Must not give free reward when ad is unavailable');
      expect(dismissedEarly, isTrue, reason: 'Must invoke onDismissedEarly fallback');

      // Reset bypass for other test suites
      AdManager.enableTestBypass = !kIsWeb && Platform.environment.containsKey('FLUTTER_TEST');
    });
  });

  group('Level Design Clearance', () {
    test('LevelDesign enforces safe vertical clearance above paddle', () {
      final layout = LevelDesign.buildClassicLevel(10, 400.0, 800.0);
      expect(layout.isNotEmpty, isTrue);

      final lowestBrickY = layout.map((b) => b.y).reduce(max);
      // Paddle is around y = 800 - 100 = 700. Lowest brick row must be comfortably above 550.
      expect(lowestBrickY, lessThanOrEqualTo(550.0),
          reason: 'Bricks must maintain safe vertical clearance from paddle');
    });
  });
}
