import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/services.dart';
import 'package:kirmatas/engine/audio_manager.dart';
import 'package:kirmatas/engine/game_controller.dart';
import 'package:kirmatas/engine/lucky_fish_notification_manager.dart';
import 'package:kirmatas/models/brick.dart';
import 'package:kirmatas/models/cosmetics.dart';
import 'package:kirmatas/models/game_state.dart';
import 'package:kirmatas/storage/save_manager.dart';
import 'package:kirmatas/ui/pause_game_over.dart';

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

  late SaveManager save;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    save = SaveManager.instance;
    await save.init();
    save.winStreak = 0;
    save.gold = 0;
    save.pearls = 0;
  });

  group('Madde A: Alevli Çerçeve & Seri Koruma', () {
    test('winStreak >= 5 enables fiery border flag logic', () {
      final gc = GameController();
      gc.setDimensions(360, 640);
      gc.startNewGame(GameMode.classic);
      gc.status = GameStatus.playing;

      save.winStreak = 4;
      expect(save.winStreak >= 5, isFalse);

      save.winStreak = 5;
      expect(save.winStreak >= 5, isTrue);
    });

    test('GameOver preserves streak in streakBeforeGameOver when winStreak >= 2', () {
      final gc = GameController();
      gc.setDimensions(360, 640);
      gc.startNewGame(GameMode.classic);
      save.winStreak = 4;
      gc.status = GameStatus.playing;
      gc.stats.lives = 0;

      // Trigger game over
      gc.triggerGameOverForTest();

      expect(gc.status, GameStatus.gameOver);
      expect(save.winStreak, 0, reason: 'Actual save.winStreak resets initially');
      expect(gc.streakBeforeGameOver, 4, reason: 'Lost streak is captured for ad protection');
      expect(gc.streakProtected, isFalse);

      // Protect streak via rewarded ad simulation
      gc.protectStreak();

      expect(gc.streakProtected, isTrue);
      expect(save.winStreak, 4, reason: 'Streak is restored after rewarded protection');

      // Idempotent: cannot double protect
      gc.protectStreak();
      expect(save.winStreak, 4);
    });

    test('Revive with one life restores lost win streak', () {
      final gc = GameController();
      gc.setDimensions(360, 640);
      gc.startNewGame(GameMode.classic);
      save.winStreak = 3;
      gc.status = GameStatus.playing;
      gc.stats.lives = 0;

      gc.triggerGameOverForTest();
      expect(gc.status, GameStatus.gameOver);
      expect(save.winStreak, 0);
      expect(gc.streakBeforeGameOver, 3);

      gc.reviveWithOneLife();
      expect(gc.status, GameStatus.ready);
      expect(save.winStreak, 3, reason: 'Reviving continues run and restores streak');
    });

    testWidgets('PauseGameOverDialog displays streak protect button on GameOver with streak >= 2', (tester) async {
      final gc = GameController();
      gc.setDimensions(360, 640);
      gc.startNewGame(GameMode.classic);
      save.winStreak = 3;
      gc.stats.lives = 0;
      gc.triggerGameOverForTest();

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: PauseGameOverOverlay(
            controller: gc,
            onResume: () {},
            onRestart: () {},
            onMainMenu: () {},
          ),
        ),
      ));
      await tester.pumpAndSettle();

      // Verify streak protect button is rendered
      expect(find.textContaining('SERİNİ KORU'), findsOneWidget);

      // Simulate protection
      gc.protectStreak();
      await tester.pumpAndSettle();

      expect(find.textContaining('SERİ KORUNDU!'), findsOneWidget);
    });
  });

  group('Madde B: Hazine Sandığı İncisi, Ahtapot Sandığı & Açılma Efekti', () {
    test('Chest brick breaking defaults to +40 gold and spawns lid particle', () {
      final gc = GameController();
      gc.setDimensions(360, 640);
      gc.startNewGame(GameMode.classic);
      gc.forceNextChestPearl = false;

      final chest = Brick(
        x: 100,
        y: 100,
        width: 40,
        height: 20,
        hp: 1,
        maxHp: 1,
        color: Colors.amber,
        isChest: true,
      );

      final initialGold = save.gold;
      final initialPearls = save.pearls;

      gc.destroyBrickForTest(chest);

      expect(save.gold, initialGold + 40);
      expect(save.pearls, initialPearls);
      expect(gc.particles.chestLids.isNotEmpty, isTrue, reason: 'Flying chest lid particle was spawned');
      expect(gc.particles.chestLids.first.vy, lessThan(0), reason: 'Lid moves upward initially');
    });

    test('Chest brick breaking awards 1 pearl when pearl drop is triggered', () {
      final gc = GameController();
      gc.setDimensions(360, 640);
      gc.startNewGame(GameMode.classic);
      gc.forceNextChestPearl = true;

      final chest = Brick(
        x: 100,
        y: 100,
        width: 40,
        height: 20,
        hp: 1,
        maxHp: 1,
        color: Colors.amber,
        isChest: true,
      );

      final initialPearls = save.pearls;

      gc.destroyBrickForTest(chest);

      expect(save.pearls, initialPearls + 1, reason: '1 Pearl awarded from chest');
      expect(gc.particles.chestLids.isNotEmpty, isTrue);
      expect(gc.particles.floatingTexts.any((f) => f.text.contains('1 İNCİ BULDUN')), isTrue);
    });

    test('ChestLidParticle updates with gravity arc and expires', () {
      final gc = GameController();
      gc.particles.spawnChestLid(100, 100, 40, 20);

      expect(gc.particles.chestLids.length, 1);
      final lid = gc.particles.chestLids.first;
      final initialVy = lid.vy;

      gc.particles.update(0.1);
      expect(lid.vy, greaterThan(initialVy), reason: 'Gravity pulls lid down over time');

      // Update past maxLife
      gc.particles.update(1.2);
      expect(gc.particles.chestLids.isEmpty, isTrue, reason: 'Expired lid particle removed');
    });

    test('Octopus Vault pearl cost is set to 8 and pearl gate works', () {
      expect(CrateDef.octopusVaultPearlCost, 8);

      save.pearls = 7;
      expect(save.spendPearls(CrateDef.octopusVaultPearlCost), isFalse);
      expect(save.pearls, 7);

      save.pearls = 9;
      expect(save.spendPearls(CrateDef.octopusVaultPearlCost), isTrue);
      expect(save.pearls, 1);
    });
  });

  group('Madde C: Günün Şanslı Balığı Bildirimi', () {
    test('Lucky fish reminder payload generates properly', () {
      final mgr = LuckyFishNotificationManager.instance;
      final payload = mgr.getDailyNotificationPayload();

      expect(payload, isNotNull);
      expect(payload!['title'], isNotEmpty);
      expect(payload['body'], isNotEmpty);
      expect(payload['fishId'], isNotEmpty);
      expect(save.unlockedFish.contains(payload['fishId']), isTrue);
    });

    test('Lucky fish reminder triggers once per calendar day', () async {
      final mgr = LuckyFishNotificationManager.instance;
      save.lastLuckyFishReminderDate = '';

      expect(mgr.shouldRemindToday, isTrue);

      save.lastLuckyFishReminderDate = mgr.todayDateKey;
      expect(mgr.shouldRemindToday, isFalse);
    });
  });

  group('Madde D: Dinamik Müzik & Tansiyon Katmanı', () {
    test('remainingBreakable <= 5 triggers music tension tempo (1.07x)', () {
      final gc = GameController();
      gc.setDimensions(360, 640);
      gc.startNewGame(GameMode.classic);
      gc.status = GameStatus.playing;

      // 6 breakable bricks: tension should NOT be active
      gc.bricks = List.generate(
        6,
        (i) => Brick(x: i * 20.0, y: 50, width: 18, height: 10, hp: 1, maxHp: 1, color: Colors.blue),
      );

      gc.update(0.016);
      expect(gc.isMusicTensionActive, isFalse);
      expect(AudioManager.instance.currentBgmPlaybackRate, 1.0);

      // Kill 2 bricks -> 4 remaining breakables: tension SHOULD be active
      gc.bricks[0].isAlive = false;
      gc.bricks[1].isAlive = false;

      gc.update(0.016);
      expect(gc.isMusicTensionActive, isTrue);
      expect(AudioManager.instance.currentBgmPlaybackRate, 1.07);

      // Level cleared (0 remaining): tension resets to 1.0
      for (final b in gc.bricks) {
        b.isAlive = false;
      }
      gc.update(0.016);
      expect(gc.isMusicTensionActive, isFalse);
      expect(AudioManager.instance.currentBgmPlaybackRate, 1.0);
    });
  });
}
