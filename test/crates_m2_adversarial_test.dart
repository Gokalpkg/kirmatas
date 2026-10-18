import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:kirmatas/engine/i18n.dart';
import 'package:kirmatas/models/cosmetics.dart';
import 'package:kirmatas/storage/save_manager.dart';
import 'package:kirmatas/ui/chest_widget.dart';
import 'package:kirmatas/ui/crate_opening_dialog.dart';
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
    await SaveManager.instance.init();
  });

  group('Adversarial Stress Suite: ChestWidget Edge Cases & Degenerate Values', () {
    testWidgets('Size 0x0 degenerate rendering', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ChestWidget(
              size: 0,
              tier: Rarity.common,
            ),
          ),
        ),
      );
      await tester.pump();
      expect(find.byType(ChestWidget), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('Extremely large size (1000x1000) rendering across all tiers', (tester) async {
      for (final tier in Rarity.values) {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: ChestWidget(
                size: 1000,
                tier: tier,
                openProgress: 1.0,
                isOpened: true,
                showGlow: true,
                time: 9999.0,
              ),
            ),
          ),
        );
        await tester.pump();
        expect(tester.takeException(), isNull);
      }
    });

    testWidgets('Extreme openProgress values: negative (-5.0), boundary (0.0, 1.0, 1.18), and extreme overshoot (100.0)', (tester) async {
      final testValues = [-5.0, -1.0, -0.001, 0.0, 0.5, 1.0, 1.18, 1.19, 2.5, 100.0];
      for (final val in testValues) {
        for (final tier in Rarity.values) {
          await tester.pumpWidget(
            MaterialApp(
              home: Scaffold(
                body: ChestWidget(
                  size: 64,
                  tier: tier,
                  openProgress: val,
                  showGlow: true,
                ),
              ),
            ),
          );
          await tester.pump();
          expect(tester.takeException(), isNull);
        }
      }
    });

    testWidgets('Extreme time values: negative time, zero, huge numbers', (tester) async {
      final times = [-1000.0, -0.5, 0.0, 1.0, 100000.0];
      for (final t in times) {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: ChestWidget(
                size: 64,
                time: t,
                tier: Rarity.legendary,
              ),
            ),
          ),
        );
        await tester.pump();
        expect(tester.takeException(), isNull);
      }
    });

    testWidgets('showGlow false and true transitions', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ChestWidget(
              size: 64,
              showGlow: false,
              tier: Rarity.rare,
            ),
          ),
        ),
      );
      await tester.pump();
      expect(tester.takeException(), isNull);
    });
  });

  group('Adversarial Stress Suite: CrateOpeningDialog Tap Barrage & Rapid Interactions', () {
    testWidgets('Rapid tap barrage before drop finishes (drops ignore early taps)', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CrateOpeningDialog(crate: CrateDef.allCrates.first),
          ),
        ),
      );

      // Dialog just mounted, drop not finished (<0.80)
      await tester.pump(const Duration(milliseconds: 100));

      // Spam 20 taps rapidly
      for (int i = 0; i < 20; i++) {
        await tester.tap(find.byType(ChestWidget), warnIfMissed: false);
      }
      await tester.pump();

      // Ensure tap count is still 0
      expect(find.text('Sandığa Dokun (1/3)'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('Rapid barrage of 50 simultaneous taps during shake animation', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CrateOpeningDialog(crate: CrateDef.allCrates.first),
          ),
        ),
      );

      // Complete drop
      await tester.pump(const Duration(milliseconds: 750));
      expect(find.text('Sandığa Dokun (1/3)'), findsOneWidget);

      // Trigger Tap 1
      await tester.tap(find.byType(ChestWidget));
      await tester.pump(const Duration(milliseconds: 50)); // Mid-shake

      // Spam 50 taps during shake
      for (int i = 0; i < 50; i++) {
        await tester.tap(find.byType(ChestWidget), warnIfMissed: false);
      }
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350)); // Shake completes

      // Should cleanly be at Tap 2
      expect(find.text('Tekrar Dokun (2/3)'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('Rapid barrage of 50 taps during opening sequence', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CrateOpeningDialog(crate: CrateDef.allCrates.first),
          ),
        ),
      );

      await tester.pump(const Duration(milliseconds: 750));

      // Tap 1
      await tester.tap(find.byType(ChestWidget));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      // Tap 2
      await tester.tap(find.byType(ChestWidget));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      // Tap 3 (Opening)
      await tester.tap(find.byType(ChestWidget));
      await tester.pump(const Duration(milliseconds: 100)); // Opening in progress

      // Spam 50 taps while opening is in progress
      for (int i = 0; i < 50; i++) {
        await tester.tap(find.byType(ChestWidget), warnIfMissed: false);
      }

      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump(const Duration(milliseconds: 1200));
      expect(find.byType(KaunosCard), findsOneWidget);
      expect(find.text(I18n.tr('claim_and_close')), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('Adversarial Stress Suite: Lifecycle, Early Pop & Disposal Safety', () {
    testWidgets('Popping dialog mid-drop does not throw setState/ticker error', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (ctx) => ElevatedButton(
                onPressed: () {
                  showDialog(
                    context: ctx,
                    builder: (_) => CrateOpeningDialog(crate: CrateDef.allCrates.first),
                  );
                },
                child: const Text('OPEN'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('OPEN'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 150)); // Mid drop

      // Pop dialog while drop is animating
      Navigator.of(tester.element(find.byType(CrateOpeningDialog))).pop();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 700));

      expect(tester.takeException(), isNull);
    });

    testWidgets('Popping dialog mid-shake (Tap 1) does not throw setState/ticker error', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (ctx) => ElevatedButton(
                onPressed: () {
                  showDialog(
                    context: ctx,
                    builder: (_) => CrateOpeningDialog(crate: CrateDef.allCrates.first),
                  );
                },
                child: const Text('OPEN'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('OPEN'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 750));

      // Tap 1
      await tester.tap(find.byType(ChestWidget));
      await tester.pump(const Duration(milliseconds: 80)); // Mid-shake

      // Pop while shake is awaiting
      Navigator.of(tester.element(find.byType(CrateOpeningDialog))).pop();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(tester.takeException(), isNull);
    });

    testWidgets('Popping dialog mid-opening (Tap 3) does not throw setState/ticker error', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (ctx) => ElevatedButton(
                onPressed: () {
                  showDialog(
                    context: ctx,
                    builder: (_) => CrateOpeningDialog(crate: CrateDef.allCrates.first),
                  );
                },
                child: const Text('OPEN'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('OPEN'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 750));

      // Tap 1
      await tester.tap(find.byType(ChestWidget));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      // Tap 2
      await tester.tap(find.byType(ChestWidget));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      // Tap 3
      await tester.tap(find.byType(ChestWidget));
      await tester.pump(const Duration(milliseconds: 200)); // Mid open

      // Pop while openController is awaiting
      Navigator.of(tester.element(find.byType(CrateOpeningDialog))).pop();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 1000));

      expect(tester.takeException(), isNull);
    });
  });

  group('Adversarial Stress Suite: Economy Edge Cases & Viewport Constraints', () {
    testWidgets('Guaranteed redemption when all category items are already unlocked', (tester) async {
      final save = SaveManager.instance;
      // Pre-unlock all balls
      for (final ball in BallSkin.allSkins) {
        save.unlockBall(ball.id);
      }
      final initialGold = save.gold;

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: CrateOpeningDialog(
              isGuaranteedRedemption: true,
              category: 'balls',
            ),
          ),
        ),
      );

      await tester.pump(const Duration(milliseconds: 750));

      // 3 Taps
      await tester.tap(find.byType(ChestWidget));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      await tester.tap(find.byType(ChestWidget));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      await tester.tap(find.byType(ChestWidget));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump(const Duration(milliseconds: 1200));

      // Should display all items unlocked text and +1000 gold
      expect(find.text(I18n.tr('all_items_unlocked')), findsOneWidget);
      expect(find.text('+1000 Gold'), findsOneWidget);
      expect(save.gold, initialGold + 1000);
      expect(tester.takeException(), isNull);
    });

    testWidgets('Shard redemption button flow when duplicate rolls with >= 3 shards', (tester) async {
      final save = SaveManager.instance;
      // Unlock all paddle skins so any drop is duplicate
      for (final p in PaddleSkin.allSkins) {
        save.unlockPaddle(p.id);
      }
      // Give player 3 shards
      save.addShard('paddles', 3);

      final paddleCrate = CategoryCrateInfo.categoryCrates['paddles']!;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (ctx) => ElevatedButton(
                onPressed: () {
                  showDialog(
                    context: ctx,
                    builder: (_) => CrateOpeningDialog(
                      categoryCrate: paddleCrate,
                      category: 'paddles',
                    ),
                  );
                },
                child: const Text('OPEN'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('OPEN'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 750));

      // Tap through opening
      await tester.tap(find.byType(ChestWidget));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      await tester.tap(find.byType(ChestWidget));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      await tester.tap(find.byType(ChestWidget));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump(const Duration(milliseconds: 1200));

      // Since player has 3 shards and it was a duplicate, the shard redemption button should appear
      expect(find.text(I18n.tr('use_shards_guaranteed')), findsOneWidget);
      expect(find.byType(KaunosTactileButton), findsNWidgets(2));
      expect(find.text(I18n.tr('claim_and_close')), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('Aquarium duplicate food bonus badge on 360x640 viewport at 1.0x text scale', (tester) async {
      final save = SaveManager.instance;
      // Pre-unlock all fish so the drop is guaranteed to be a duplicate and trigger _isFoodBonus
      for (final fish in FishItem.allFish) {
        save.unlockedFish.add(fish.id);
      }

      tester.view.physicalSize = const Size(360 * 2.0, 640 * 2.0);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(
              size: Size(360, 640),
              textScaler: TextScaler.linear(1.0),
            ),
            child: Scaffold(
              body: SingleChildScrollView(
                child: CrateOpeningDialog(crate: CrateDef.allCrates.first),
              ),
            ),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 750));

      // Tap through to open
      await tester.tap(find.byType(ChestWidget));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      await tester.tap(find.byType(ChestWidget));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      await tester.tap(find.byType(ChestWidget));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump(const Duration(milliseconds: 1200));

      final error = tester.takeException();
      expect(error, isNull);
    });

    testWidgets('Shard redemption button on 360x640 viewport at 1.3x text scale renders cleanly without RenderFlex overflow', (tester) async {
      final save = SaveManager.instance;
      for (final p in PaddleSkin.allSkins) {
        save.unlockPaddle(p.id);
      }
      save.addShard('paddles', 3);

      final paddleCrate = CategoryCrateInfo.categoryCrates['paddles']!;

      tester.view.physicalSize = const Size(360 * 2.0, 640 * 2.0);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(
              size: Size(360, 640),
              textScaler: TextScaler.linear(1.3),
            ),
            child: Scaffold(
              body: SingleChildScrollView(
                child: CrateOpeningDialog(
                  categoryCrate: paddleCrate,
                  category: 'paddles',
                ),
              ),
            ),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 750));

      // Tap through opening
      await tester.tap(find.byType(ChestWidget));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      await tester.tap(find.byType(ChestWidget));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      await tester.tap(find.byType(ChestWidget));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump(const Duration(milliseconds: 1200));

      final error = tester.takeException();
      expect(error, isNull);
    });
  });
}

