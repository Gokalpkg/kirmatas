import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:kirmatas/engine/game_controller.dart';
import 'package:kirmatas/engine/game_event_bus.dart';
import 'package:kirmatas/engine/i18n.dart';
import 'package:kirmatas/models/game_state.dart';
import 'package:kirmatas/storage/save_manager.dart';
import 'package:kirmatas/ui/level_clear_card.dart';
import 'package:kirmatas/ui/pause_game_over.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('xyz.luan/audioplayers'),
      (MethodCall methodCall) async => 1,
    );
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('xyz.luan/audioplayers.global'),
      (MethodCall methodCall) async => 1,
    );
  });

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await SaveManager.instance.init();
  });

  group('Level Stars Calculation & Lifecycle Tests', () {
    test('calculateLevelStars rules: 0 lost -> 3, 1 lost -> 2, >=2 lost -> 1 (never 0)', () {
      final gc = GameController();

      // Default initial state
      expect(gc.livesLostThisLevel, 0);
      expect(gc.calculateLevelStars(), 3);

      // 1 life lost
      gc.livesLostThisLevelForTesting = 1;
      expect(gc.calculateLevelStars(), 2);

      // 2 lives lost
      gc.livesLostThisLevelForTesting = 2;
      expect(gc.calculateLevelStars(), 1);

      // 5 lives lost
      gc.livesLostThisLevelForTesting = 5;
      expect(gc.calculateLevelStars(), 1);

      // Negative edge case guard
      gc.livesLostThisLevelForTesting = -1;
      expect(gc.calculateLevelStars(), 3);
    });

    test('Losing lives increments livesLostThisLevel and resets on loadLevelBricks', () {
      final gc = GameController();
      gc.setDimensions(360, 640);
      gc.startNewGame(GameMode.classic);
      gc.launchBall();
      expect(gc.status, GameStatus.playing);
      expect(gc.livesLostThisLevel, 0);

      // Drop ball below screen
      for (final ball in gc.balls) {
        ball.y = gc.screenHeight + 100;
      }
      gc.update(0.016);

      // Should have lost 1 life
      expect(gc.livesLostThisLevel, 1);
      expect(gc.calculateLevelStars(), 2);

      // Next level load resets livesLostThisLevel
      gc.loadLevelBricks();
      expect(gc.livesLostThisLevel, 0);
      expect(gc.calculateLevelStars(), 3);
    });

    test('Bug Fix Verification: Low lives in previous level does NOT lock subsequent levels to 1 star', () {
      final gc = GameController();
      gc.setDimensions(360, 640);
      gc.startNewGame(GameMode.classic);
      gc.launchBall();

      // Simulate losing 2 lives in Level 1 -> stats.lives is now 1
      gc.stats.lives = 1;
      gc.livesLostThisLevelForTesting = 2;
      expect(gc.calculateLevelStars(), 1);

      // Transition to Level 2
      gc.stats.level = 2;
      gc.loadLevelBricks();

      // In Level 2, stats.lives is still 1, but livesLostThisLevel was reset to 0!
      expect(gc.stats.lives, 1);
      expect(gc.livesLostThisLevel, 0);

      // Player completes Level 2 without losing a life
      expect(gc.calculateLevelStars(), 3);

      // Clear all bricks in Level 2
      for (final b in gc.bricks) {
        b.hp = 0;
        b.isAlive = false;
      }
      gc.status = GameStatus.playing;
      gc.update(0.016);

      // Stars awarded for Level 2 must be 3 (Kusursuz)
      expect(gc.lastClearedLevelStars, 3);
      expect(SaveManager.instance.getLevelStars(2), 3);
    });

    test('LevelClearedEvent is dispatched with correct star count upon level clear', () async {
      final gc = GameController();
      gc.setDimensions(360, 640);
      gc.startNewGame(GameMode.classic);
      gc.launchBall();

      LevelClearedEvent? capturedEvent;
      final sub = GameEventBus().on<LevelClearedEvent>().listen((event) {
        capturedEvent = event;
      });

      // Clear level with 1 life lost
      gc.livesLostThisLevelForTesting = 1;
      for (final b in gc.bricks) {
        b.hp = 0;
        b.isAlive = false;
      }
      gc.status = GameStatus.playing;
      gc.update(0.016);
      await Future<void>.delayed(Duration.zero);

      expect(capturedEvent, isNotNull);
      expect(capturedEvent!.starsAwarded, 2);
      expect(gc.lastClearedLevelStars, 2);

      sub.cancel();
    });
  });

  group('LevelClearCard & FlawlessVictoryBadge Widget Tests', () {
    testWidgets('LevelClearCard renders 3 stars, subtitle, and FlawlessVictoryBadge when stars=3',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: LevelClearCard(
              stars: 3,
              level: 4,
              score: 1250,
              goldEarned: 50,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Flawless badge must be present
      expect(find.byType(FlawlessVictoryBadge), findsOneWidget);
      expect(find.text(I18n.tr('flawless_victory_badge')), findsOneWidget);
      expect(find.text(I18n.tr('stars_3_subtitle')), findsOneWidget);
    });

    testWidgets('LevelClearCard does NOT show FlawlessVictoryBadge when stars=2 or 1',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: LevelClearCard(
              stars: 2,
              level: 3,
              score: 800,
              goldEarned: 30,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(FlawlessVictoryBadge), findsNothing);
      expect(find.text(I18n.tr('stars_2_subtitle')), findsOneWidget);
    });

    testWidgets('PauseGameOverOverlay shows FlawlessVictoryBadge on 3-star victory',
        (tester) async {
      final gc = GameController();
      gc.setDimensions(360, 640);
      gc.startNewGame(GameMode.classic);
      gc.status = GameStatus.victory;
      gc.lastClearedLevelStars = 3;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PauseGameOverOverlay(
              controller: gc,
              onResume: () {},
              onRestart: () {},
              onMainMenu: () {},
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.byType(FlawlessVictoryBadge), findsOneWidget);
      expect(find.text(I18n.tr('flawless_victory_badge')), findsOneWidget);
      expect(find.text(I18n.tr('stars_3_subtitle')), findsOneWidget);
    });

    testWidgets('PauseGameOverOverlay does NOT show FlawlessVictoryBadge on 1-star victory',
        (tester) async {
      final gc = GameController();
      gc.setDimensions(360, 640);
      gc.startNewGame(GameMode.classic);
      gc.status = GameStatus.victory;
      gc.lastClearedLevelStars = 1;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PauseGameOverOverlay(
              controller: gc,
              onResume: () {},
              onRestart: () {},
              onMainMenu: () {},
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.byType(FlawlessVictoryBadge), findsNothing);
      expect(find.text(I18n.tr('stars_1_subtitle')), findsOneWidget);
    });
  });
}
