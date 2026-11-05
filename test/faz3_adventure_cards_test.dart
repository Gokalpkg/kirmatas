import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:kirmatas/engine/game_controller.dart';
import 'package:kirmatas/models/adventure_card.dart';
import 'package:kirmatas/models/ball.dart';
import 'package:kirmatas/models/brick.dart';
import 'package:kirmatas/models/cosmetics.dart';
import 'package:kirmatas/models/game_state.dart';
import 'package:kirmatas/models/powerup.dart';
import 'package:kirmatas/storage/save_manager.dart';
import 'package:kirmatas/ui/level_clear_card.dart';

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

  group('Faz 3 - Macera Kartları ve Pre-Match Boosts (Problem 1 & 4)', () {
    test('AdventureCard model list has 4 distinct adventure cards', () {
      expect(AdventureCard.allCards.length, 4);
      final ids = AdventureCard.allCards.map((c) => c.id).toSet();
      expect(ids.contains('risk_double'), isTrue);
      expect(ids.contains('overcharged_speed'), isTrue);
      expect(ids.contains('pinata_heaven'), isTrue);
      expect(ids.contains('golden_octopus'), isTrue);
    });

    test('Risk Bahsi (risk_double): Doubles brick HP and activates x4 gold multiplier', () async {
      final ctrl = GameController();
      ctrl.setDimensions(400, 800);
      ctrl.startNewGame(GameMode.classic, explicitStartLevel: 1);
      final save = SaveManager.instance;
      await save.addGold(1000);

      final brick = Brick(x: 100, y: 100, width: 40, height: 20, hp: 3, maxHp: 3, color: Colors.blue);
      ctrl.bricks = [brick];

      final activated = await ctrl.buyAndActivatePreMatchBoost('risk_double');
      expect(activated, isTrue);
      expect(ctrl.isRiskDoubleActive, isTrue);
      expect(ctrl.matchGoldMultiplier, 4);
      expect(brick.hp, 6);
      expect(brick.maxHp, 6);
    });

    test('Lazer Top (overcharged_speed): Grants +40% speed and paddle laser', () async {
      final ctrl = GameController();
      ctrl.setDimensions(400, 800);
      ctrl.startNewGame(GameMode.classic, explicitStartLevel: 1);
      final save = SaveManager.instance;
      await save.addGold(1000);

      final baseSpd = ctrl.getBaseBallSpeed();
      final activated = await ctrl.buyAndActivatePreMatchBoost('overcharged_speed');
      expect(activated, isTrue);
      expect(ctrl.isOverchargedSpeedActive, isTrue);
      expect(ctrl.paddle.hasLaser, isTrue);
      expect(ctrl.paddle.laserAmmo, 99);
      expect(ctrl.getBaseBallSpeed(), closeTo(baseSpd * 1.4, 0.01));
    });

    test('Pinata Cenneti (pinata_heaven): Inserts 2 isGoldPinata bricks at top row', () async {
      final ctrl = GameController();
      ctrl.setDimensions(400, 800);
      ctrl.startNewGame(GameMode.classic, explicitStartLevel: 1);
      final save = SaveManager.instance;
      await save.addGold(1000);

      final initialPinatas = ctrl.bricks.where((b) => b.isGoldPinata).length;
      final activated = await ctrl.buyAndActivatePreMatchBoost('pinata_heaven');
      expect(activated, isTrue);
      expect(ctrl.isPinataHeavenActive, isTrue);
      final newPinatas = ctrl.bricks.where((b) => b.isGoldPinata).length;
      expect(newPinatas, initialPinatas + 2);
    });

    test('Altin Ahtapot (golden_octopus): Costs 1 Pearl, grants x5 gold, intercepts ball loss without losing life', () async {
      final ctrl = GameController();
      ctrl.setDimensions(400, 800);
      ctrl.startNewGame(GameMode.classic, explicitStartLevel: 1);
      final save = SaveManager.instance;
      save.addPearls(2);

      final activated = await ctrl.buyAndActivatePreMatchBoost('golden_octopus');
      expect(activated, isTrue);
      expect(ctrl.isGoldenOctopusActive, isTrue);
      expect(ctrl.matchGoldMultiplier, 5);
      expect(save.pearls, 1);

      ctrl.status = GameStatus.playing;
      ctrl.stats.lives = 3;
      ctrl.balls.clear();
      final ball = Ball(x: 200, y: 790, isStuck: false);
      ball.vy = 300.0;
      ctrl.balls.add(ball);

      // Trigger ball loss below screen
      ctrl.update(0.1);

      // Octopus should intercept! Lives should remain 3!
      expect(ctrl.octopusRescueUsed, isTrue);
      expect(ctrl.stats.lives, 3);
      expect(ctrl.balls.isNotEmpty, isTrue);
      expect(ctrl.balls.first.vy < 0, isTrue); // Bounced upwards!
    });
  });

  group('Faz 3 - Sinerjiler ve Perkler (Problem 2, 7 & 9)', () {
    test('Mini Kara Delik: Exploding area with active magnet sets vacuumStormTimer = 3.5', () {
      final ctrl = GameController();
      ctrl.setDimensions(400, 800);
      ctrl.startNewGame(GameMode.classic, explicitStartLevel: 1);
      ctrl.status = GameStatus.playing;
      ctrl.paddle.hasVortex = true;

      // Create a dynamite brick to explode
      final dyn = Brick(
        x: 150,
        y: 200,
        width: 40,
        height: 20,
        hp: 1,
        maxHp: 1,
        color: Colors.red,
        isDynamite: true,
      );
      ctrl.bricks = [dyn, Brick(x: 10, y: 10, width: 40, height: 20, hp: 10, maxHp: 10, color: Colors.blue)];

      // Detonate dynamite
      ctrl.destroyBrickForTest(dyn);

      expect(ctrl.vacuumStormTimer, 3.5);
    });

    test('Magnet Level >= 5: Pulled capsule dealing damage to intersecting brick', () async {
      final ctrl = GameController();
      ctrl.setDimensions(400, 800);
      final save = SaveManager.instance;
      save.upgrades['magnet'] = 5;

      ctrl.startNewGame(GameMode.classic, explicitStartLevel: 1);
      ctrl.status = GameStatus.playing;

      final brick = Brick(x: 190, y: 390, width: 40, height: 20, hp: 5, maxHp: 5, color: Colors.blue);
      ctrl.bricks = [brick];

      final cap = FallingCapsule(x: 200, y: 400, type: PowerUpType.laser);
      ctrl.capsules.add(cap);

      ctrl.update(0.01);
      expect(brick.hp, 4); // Took 1 damage!
    });

    test('Boss Enrage Phase 3: Spawns bonus Gold Pinata brick below boss', () {
      final ctrl = GameController();
      ctrl.setDimensions(400, 800);
      ctrl.startNewGame(GameMode.classic, explicitStartLevel: 1);

      final boss = Brick(
        x: 150,
        y: 100,
        width: 100,
        height: 40,
        hp: 100,
        maxHp: 100,
        color: Colors.purple,
        isBoss: true,
      );
      ctrl.bricks = [boss];

      // Ball hits boss dropping HP below 35%
      ctrl.balls.clear();
      final ball = Ball(x: 170, y: 130, isStuck: false);
      ball.vx = 0;
      ball.vy = -100;
      ctrl.balls.add(ball);

      // Reduce boss hp directly to trigger enrage on hit
      boss.hp = 30; // 30% <= 35%
      ctrl.update(0.05);

      final hasBonusPinata = ctrl.bricks.any((b) => b.isGoldPinata && b.y > boss.y);
      expect(hasBonusPinata, isTrue);
    });
  });

  group('Faz 3 - Törensel Kilit Açılış Rozetleri (Problem 6 & 11)', () {
    testWidgets('LevelClearCard renders feature unlock badge on Level 3 (Wheel)', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: LevelClearCard(
              level: 3,
              stars: 3,
              score: 500,
              goldEarned: 150,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('YENİ ÖZELLİK AÇILDI!'), findsOneWidget);
      expect(find.text('Şans Çarkı artık Ana Menüde seni bekliyor!'), findsOneWidget);
    });

    testWidgets('LevelClearCard renders feature unlock badge on Level 5 (Aquarium)', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: LevelClearCard(
              level: 5,
              stars: 3,
              score: 800,
              goldEarned: 200,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('YENİ ÖZELLİK AÇILDI!'), findsOneWidget);
      expect(find.text('Kaunos Akvaryumu kilitleri kalktı!'), findsOneWidget);
    });

    testWidgets('LevelClearCard renders feature unlock badge on Level 10 (Tournament)', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: LevelClearCard(
              level: 10,
              stars: 3,
              score: 1500,
              goldEarned: 350,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('YENİ ÖZELLİK AÇILDI!'), findsOneWidget);
      expect(find.text('Haftalık Kaunos Turnuvası aktifleşti!'), findsOneWidget);
    });
  });
}
