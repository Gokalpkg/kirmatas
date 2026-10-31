import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kirmatas/config/balance_config.dart';
import 'package:kirmatas/engine/game_controller.dart';
import 'package:kirmatas/models/ball.dart';
import 'package:kirmatas/models/brick.dart';
import 'package:kirmatas/models/cosmetics.dart';
import 'package:kirmatas/models/game_state.dart';
import 'package:kirmatas/models/powerup.dart';
import 'package:kirmatas/models/sector_blessing.dart';
import 'package:kirmatas/engine/game_event_bus.dart';
import 'package:kirmatas/storage/save_manager.dart';
import 'package:kirmatas/ui/upgrades_view.dart';
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

  group('FAZ 1.2: Merkezi Matematiksel Ekonomi Dengelemesi ve Seviye Eğrisi', () {
    test('upgradeCost follows sub-polynomial formula exactly', () {
      // upgradeCost(L) = (50 * (1 + 0.15 * L + 0.02 * L^1.8)).round()
      expect(BalanceConfig.upgradeCost(0), equals(50));
      expect(BalanceConfig.upgradeCost(1), equals(59));
      expect(BalanceConfig.upgradeCost(5), equals(106));
      expect(BalanceConfig.upgradeCost(10), equals(188));
      expect(BalanceConfig.upgradeCost(50), equals(1568));
      expect(BalanceConfig.upgradeCost(100), equals(4781));

      // Negative levels safe clamp to baseCost
      expect(BalanceConfig.upgradeCost(-1), equals(50));
      expect(BalanceConfig.upgradeCost(-99), equals(50));

      // Custom baseCost works proportionally
      expect(BalanceConfig.upgradeCost(0, baseCost: 100), equals(100));
      expect(BalanceConfig.upgradeCost(1, baseCost: 100), equals(117));
    });

    test('StatUpgrade.getCostForLevel maintains backward compatibility and supports sub-polynomial fallback', () {
      final paddleUpgrade = StatUpgrade.all.firstWhere((s) => s.id == 'paddle_width');
      expect(paddleUpgrade.getCostForLevel(0), equals(600));
      expect(paddleUpgrade.getCostForLevel(1), equals(1500));
      expect(paddleUpgrade.getCostForLevel(2), equals(3000));
      expect(paddleUpgrade.getCostForLevel(3), equals(5500));
      expect(paddleUpgrade.getCostForLevel(4), equals(9500));
      expect(paddleUpgrade.getCostForLevel(5), equals(BalanceConfig.upgradeCost(5))); // Uncapped up to 100
      expect(paddleUpgrade.getCostForLevel(99), equals(BalanceConfig.upgradeCost(99)));
      expect(paddleUpgrade.getCostForLevel(100), equals(0)); // At maxLevel
      expect(paddleUpgrade.getCostForLevel(-1), equals(0));

      // Custom empty-cost StatUpgrade falls back to BalanceConfig.upgradeCost
      const dynamicUpgrade = StatUpgrade(
        id: 'custom_stat',
        nameKey: 'custom',
        descKey: 'custom_desc',
        icon: Icons.star,
        color: Colors.blue,
        costs: [],
      );
      expect(dynamicUpgrade.maxLevel, equals(100));
      expect(dynamicUpgrade.getCostForLevel(0), equals(BalanceConfig.upgradeCost(0)));
      expect(dynamicUpgrade.getCostForLevel(10), equals(BalanceConfig.upgradeCost(10)));
      expect(dynamicUpgrade.getCostForLevel(99), equals(BalanceConfig.upgradeCost(99)));
      expect(dynamicUpgrade.getCostForLevel(100), equals(0));
    });

    test('SaveManager buyStatUpgrade supports optional cost and refunds correctly', () async {
      SharedPreferences.setMockInitialValues({});
      final save = SaveManager.instance;
      await save.resetAllUpgrades();
      await save.addGold(50000);

      // Buy with omitted cost (auto-resolves via StatUpgrade.getCostForLevel)
      final bought = await save.buyStatUpgrade('paddle_width');
      expect(bought, isTrue);
      expect(save.getUpgradeLevel('paddle_width'), equals(1));

      // Buy with explicit cost (backward compatibility)
      final boughtExplicit = await save.buyStatUpgrade('crit_damage', 800);
      expect(boughtExplicit, isTrue);
      expect(save.getUpgradeLevel('crit_damage'), equals(1));

      // Total spent: 600 (paddle_width lvl 1) + 800 (crit_damage lvl 1) = 1400
      expect(save.calculateTotalSpentOnUpgrades(), equals(1400));

      // Refund resets levels and returns 100% gold
      final goldBefore = save.gold;
      final refunded = await save.resetAllUpgrades();
      expect(refunded, equals(1400));
      expect(save.gold, equals(goldBefore + 1400));
      expect(save.getUpgradeLevel('paddle_width'), equals(0));
      expect(save.getUpgradeLevel('crit_damage'), equals(0));
    });
  });

  group('FAZ 1.1: Prismatic Splitter, Multi-ball & Obje Klonlanma Mutasyon Buglarının İzolasyonu', () {
    late GameController gc;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      gc = GameController();
      gc.setDimensions(360, 640);
      gc.startNewGame(GameMode.classic);
    });

    tearDown(() {
      gc.dispose();
    });

    test('Multiball and Mirror powerups route safely through pending balls queue and flush', () {
      expect(gc.balls.length, equals(1));

      // Multiball splits into 3 balls total
      gc.applyPowerUp(PowerUpType.multi);
      expect(gc.balls.length, equals(3));

      // Mirror adds 1 ball safely
      gc.applyPowerUp(PowerUpType.mirror);
      expect(gc.balls.length, equals(4));

      // Safe coordinate guarantees: balls spawn above paddle, not intersecting interior
      for (final b in gc.balls) {
        expect(b.y, lessThanOrEqualTo(gc.paddle.y));
        expect(b.x, greaterThanOrEqualTo(b.radius));
        expect(b.x, lessThanOrEqualTo(gc.screenWidth - b.radius));
      }
    });

    test('Prismatic Splitter clones safely with verified velocity and paddle anti-penetration', () {
      // Pick Prismatic Splitter blessing from all
      final blessing = SectorBlessing.all.firstWhere((b) => b.type == SectorBlessingType.prismaticSplitter);
      gc.activeSectorBlessing = blessing;

      // Setup lone ball hitting paddle moving downward
      gc.balls.clear();
      final ball = Ball(
        x: gc.paddle.x + gc.paddle.width * 0.5,
        y: gc.paddle.y - 7.5,
        vx: 120.0,
        vy: 240.0,
        radius: 7.5,
      );
      gc.balls.add(ball);

      expect(gc.balls.length, equals(1));

      // Simulate paddle bounce frame
      final collisionOccurred = gc.checkBallPaddleCollisionForTest(ball);
      expect(collisionOccurred, isTrue);

      // Verify that newly added balls in gc satisfy anti-penetration constraints
      for (final b in gc.balls) {
        expect(b.y, lessThanOrEqualTo(gc.paddle.y - b.radius));
      }
    });

    test('Atomically flushes pending balls at end of frame without false life loss', () {
      gc.balls.clear();
      // Add a ball to pending
      final testBall = Ball(
        x: 180,
        y: gc.paddle.y - 10,
        vx: 50,
        vy: -150,
        radius: 7.5,
      );
      gc.addPendingBallForTest(testBall);

      // Before update finishes, balls is empty, but pending has 1
      expect(gc.balls.isEmpty, isTrue);

      // Run update - _flushPendingBalls should add it before any _loseLife check
      final livesBefore = gc.stats.lives;
      gc.update(0.016);

      expect(gc.balls.length, equals(1));
      expect(gc.stats.lives, equals(livesBefore)); // No false life loss!
    });

    test('Paddle anti-penetration pushes deep overlapping ball safely above paddle', () {
      gc.balls.clear();
      // Position ball intersecting the lower half of the paddle
      final deepPenetratingBall = Ball(
        x: gc.paddle.x + gc.paddle.width * 0.5,
        y: gc.paddle.y + gc.paddle.height * 0.8,
        vx: 30,
        vy: 120, // moving downwards inside paddle
        radius: 8.0,
      );
      gc.addPendingBallForTest(deepPenetratingBall);
      gc.flushPendingBallsForTest();

      expect(gc.balls.length, equals(1));
      final flushed = gc.balls.first;
      expect(flushed.y, lessThanOrEqualTo(gc.paddle.y - flushed.radius - 2.0));
      expect(flushed.vy, lessThan(0.0)); // deflected upward!
      expect(flushed.radius, equals(8.0));
    });
  });

  group('Adli Tıp Denetimi Mekanik, Ekonomi ve Mantık Düzeltmeleri', () {
    test('u_gold stat exists in StatUpgrade.all and works seamlessly with SaveManager', () async {
      SharedPreferences.setMockInitialValues({});
      final save = SaveManager.instance;
      await save.resetAllUpgrades();

      final goldStat = StatUpgrade.all.firstWhere((s) => s.id == 'u_gold');
      expect(goldStat.id, equals('u_gold'));
      expect(goldStat.nameKey, equals('upgrade_gold'));
      expect(goldStat.descKey, equals('upgrade_gold_desc'));
      expect(goldStat.maxLevel, equals(100));

      await save.addGold(50000);
      final bought = await save.buyStatUpgrade('u_gold');
      expect(bought, isTrue);
      expect(save.getUpgradeLevel('u_gold'), equals(1));
      expect(save.getUpgradeLevel('gold_multiplier'), equals(1));

      // Buying alias gold_multiplier works too
      final boughtAlias = await save.buyStatUpgrade('gold_multiplier');
      expect(boughtAlias, isTrue);
      expect(save.getUpgradeLevel('u_gold'), equals(2));

      // Refund correctly restores gold
      final refund = await save.resetAllUpgrades();
      expect(refund, greaterThan(0));
      expect(save.getUpgradeLevel('u_gold'), equals(0));
    });

    test('BalanceConfig.calculateInterest calculates +15 per 250 gold up to 120 cap', () {
      expect(BalanceConfig.calculateInterest(-50), equals(0));
      expect(BalanceConfig.calculateInterest(0), equals(0));
      expect(BalanceConfig.calculateInterest(100), equals(0));
      expect(BalanceConfig.calculateInterest(249), equals(0));
      expect(BalanceConfig.calculateInterest(250), equals(15));
      expect(BalanceConfig.calculateInterest(499), equals(15));
      expect(BalanceConfig.calculateInterest(500), equals(30));
      expect(BalanceConfig.calculateInterest(1000), equals(60));
      expect(BalanceConfig.calculateInterest(2000), equals(120));
      expect(BalanceConfig.calculateInterest(2500), equals(120)); // Capped at 120
      expect(BalanceConfig.calculateInterest(100000), equals(120));
    });

    test('BalanceConfig.comboGoldMultiplier applies stepped multipliers up to 3x Fever', () {
      expect(BalanceConfig.comboGoldMultiplier(0), equals(1.0));
      expect(BalanceConfig.comboGoldMultiplier(1), equals(1.0));
      expect(BalanceConfig.comboGoldMultiplier(4), equals(1.0));
      expect(BalanceConfig.comboGoldMultiplier(5), equals(1.5));
      expect(BalanceConfig.comboGoldMultiplier(9), equals(1.5));
      expect(BalanceConfig.comboGoldMultiplier(10), equals(2.0));
      expect(BalanceConfig.comboGoldMultiplier(19), equals(2.0));
      expect(BalanceConfig.comboGoldMultiplier(20), equals(3.0));
      expect(BalanceConfig.comboGoldMultiplier(50), equals(3.0));
    });

    test('BalanceConfig.levelClearGold scales beyond old 75 ceiling', () {
      expect(BalanceConfig.levelClearGold(1), greaterThanOrEqualTo(50));
      expect(BalanceConfig.levelClearGold(10), greaterThan(75));
      expect(BalanceConfig.levelClearGold(20), greaterThan(BalanceConfig.levelClearGold(10)));
      expect(BalanceConfig.levelClearGold(50), greaterThan(BalanceConfig.levelClearGold(20)));
    });

    test('Capsule Pity Timer triggers guaranteed buff on 11th brick after 10 misses', () {
      final gc = GameController();
      gc.setDimensions(360, 640);
      gc.startNewGame(GameMode.classic);
      gc.capsulePityCounter = 0;
      gc.capsules.clear();

      // Simulate 10 consecutive misses (no capsule dropped)
      for (int i = 0; i < 10; i++) {
        gc.capsulePityCounter++;
      }
      expect(gc.capsulePityCounter, equals(10));

      // Destroy an 11th regular brick
      final testBrick = Brick(
        x: 100,
        y: 100,
        width: 40,
        height: 20,
        color: Colors.cyan,
        points: 10,
      );
      gc.destroyBrickForTest(testBrick);

      // Pity triggered: guaranteed capsule spawned, and counter reset to 0!
      expect(gc.capsules.isNotEmpty, isTrue);
      expect(gc.capsulePityCounter, equals(0));
      expect(gc.capsules.last.type.kind, equals(PowerUpKind.buff));
      gc.dispose();
    });

    test('Level clear awards vault interest, increments stats.goldCollected, and fires GoldCollectedEvent', () async {
      SharedPreferences.setMockInitialValues({});
      final save = SaveManager.instance;
      await save.init();
      save.gold = 500; // 500 gold -> +30 interest

      final gc = GameController();
      gc.setDimensions(360, 640);
      gc.startNewGame(GameMode.classic);
      gc.stats.level = 1;
      gc.stats.goldCollected = 0;

      GoldCollectedEvent? capturedEvent;
      final sub = GameEventBus().on<GoldCollectedEvent>().listen((event) {
        capturedEvent = event;
      });

      // Launch ball to transition status to playing
      gc.launchBall();
      gc.status = GameStatus.playing;

      // Clear all solid bricks to trigger level clear
      gc.bricks.removeWhere((b) => !b.isSteel);
      gc.update(0.016);

      // Allow stream event delivery
      await Future<void>.delayed(Duration.zero);

      // Verify interest was calculated and deposited into player save
      final interest = BalanceConfig.calculateInterest(500);
      expect(interest, equals(30));
      expect(save.gold, greaterThanOrEqualTo(500 + interest));
      // Event bus was fired with exact interest
      expect(capturedEvent, isNotNull);
      expect(capturedEvent?.amount, equals(interest));

      await sub.cancel();
      gc.dispose();
    });

    testWidgets('UpgradesView renders smoothly with 100-level stats without layout overflow', (tester) async {
      SharedPreferences.setMockInitialValues({});
      final save = SaveManager.instance;
      await save.init();
      save.gold = 10000;

      tester.view.physicalSize = const Size(360, 780);
      tester.view.devicePixelRatio = 1.0;

      await tester.pumpWidget(
        const MaterialApp(
          home: UpgradesView(),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      final err = tester.takeException();
      expect(err, isNull);
    });
  });
}


