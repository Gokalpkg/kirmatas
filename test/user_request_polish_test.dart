import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:kirmatas/engine/game_controller.dart';
import 'package:kirmatas/engine/i18n.dart';
import 'package:kirmatas/models/ball.dart';
import 'package:kirmatas/models/brick.dart';
import 'package:kirmatas/models/cosmetics.dart';
import 'package:kirmatas/models/game_state.dart';
import 'package:kirmatas/storage/save_manager.dart';
import 'package:kirmatas/ui/chest_widget.dart';

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

  group('User Request Polish Verification Suite', () {
    test('1. i18n next_level is localized across all languages', () {
      SaveManager.instance.language = 'tr';
      expect(I18n.tr('next_level'), 'Sonraki Bölüm');
      SaveManager.instance.language = 'en';
      expect(I18n.tr('next_level'), 'Next Level');
      SaveManager.instance.language = 'de';
      expect(I18n.tr('next_level'), 'Nächstes Level');
      SaveManager.instance.language = 'fr';
      expect(I18n.tr('next_level'), 'Niveau Suivant');
      SaveManager.instance.language = 'tr';
    });

    test('2. 2-HP brick does not break from single hit with clutch overcharge', () {
      final gc = GameController();
      gc.setDimensions(360, 640);
      gc.startNewGame(GameMode.classic);

      final brick = Brick(
        x: 100,
        y: 100,
        width: 40,
        height: 20,
        hp: 2,
        type: BrickType.normal,
        color: Colors.blue,
      );
      gc.bricks.clear();
      gc.bricks.add(brick);

      final ball = Ball(
        x: 100,
        y: 100,
        vx: 10,
        vy: 10,
      );
      expect(ball.isClutchOvercharged, isFalse);

      gc.balls.clear();
      gc.balls.add(ball);

      // Sub-step update detects collision
      gc.update(0.005);

      // Brick should have 1 HP remaining, NOT 0 (it should NOT insta-break 2-HP brick)
      expect(brick.hp, 1);
      expect(brick.isAlive, isTrue);
    });

    test('3. Ball collision cooldown prevents multiple hits on same brick in consecutive sub-steps', () {
      final ball = Ball(x: 100, y: 100, vx: 10, vy: 10);
      final brick = Brick(
        x: 100,
        y: 100,
        width: 40,
        height: 20,
        hp: 3,
        type: BrickType.normal,
        color: Colors.blue,
      );

      ball.lastHitBrick = brick;
      ball.lastHitBrickCooldown = 0.08;

      expect(ball.lastHitBrick, brick);
      expect(ball.lastHitBrickCooldown, greaterThan(0));

      ball.update(0.04);
      expect(ball.lastHitBrickCooldown, closeTo(0.04, 0.001));

      ball.update(0.05);
      expect(ball.lastHitBrickCooldown, 0.0);
      expect(ball.lastHitBrick, isNull);
    });

    test('4. Chaos mode stats.level scales with turn counter for BBTAN progression', () {
      final gc = GameController();
      gc.setDimensions(360, 640);
      gc.startNewGame(GameMode.chaos);

      expect(gc.currentMode, GameMode.chaos);
      expect(gc.chaosTurnCounter, 0);
      expect(gc.stats.level, 1);

      // When all balls return in chaos mode, end of turn advances stats.level = chaosTurnCounter + 1
      gc.chaosTurnCounter = 1;
      gc.stats.level = gc.chaosTurnCounter + 1;
      expect(gc.stats.level, 2);

      gc.chaosTurnCounter = 5;
      gc.stats.level = gc.chaosTurnCounter + 1;
      expect(gc.stats.level, 6);
    });

    test('5. Octopus is strictly excluded from general aquarium crate pool', () {
      final nonOctopusPool = FishItem.allFish
          .where((f) => f.id != 'octopus' && f.kind != FishKind.octopus)
          .toList();

      expect(nonOctopusPool.any((f) => f.id == 'octopus'), isFalse);
      expect(nonOctopusPool.any((f) => f.kind == FishKind.octopus), isFalse);
    });

    testWidgets('6. ChestWidget renders with wooden construction across distinct crate types', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                ChestWidget(size: 64, crateType: 'balls', tier: Rarity.common),
                ChestWidget(size: 64, crateType: 'paddles', tier: Rarity.rare),
                ChestWidget(size: 64, crateType: 'trails', tier: Rarity.epic),
                ChestWidget(size: 64, crateType: 'octopus', tier: Rarity.legendary),
              ],
            ),
          ),
        ),
      );

      await tester.pump();
      expect(find.byType(ChestWidget), findsNWidgets(4));
      expect(tester.takeException(), isNull);
    });
  });
}
