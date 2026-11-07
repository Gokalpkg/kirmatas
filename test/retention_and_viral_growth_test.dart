import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:kirmatas/engine/in_app_review_manager.dart';
import 'package:kirmatas/engine/notification_service.dart';
import 'package:kirmatas/storage/save_manager.dart';
import 'package:kirmatas/ui/kaunos_ui.dart';
import 'package:kirmatas/ui/level_clear_card.dart';
import 'package:kirmatas/ui/offline_earnings_dialog.dart';
import 'package:kirmatas/ui/tournament_dialog.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final List<Map<String, dynamic>> scheduledNotifications = [];

  setUpAll(() {
    AndroidFlutterLocalNotificationsPlugin.registerWith();
    tz.initializeTimeZones();
    tz.setLocalLocation(tz.UTC);
    NotificationService.instance.isInitializedForTest = true;

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('dexterous.com/flutter/local_notifications'),
      (call) async {
        if (call.method == 'zonedSchedule') {
          scheduledNotifications.add(Map<String, dynamic>.from(call.arguments as Map));
          return null;
        }
        return true;
      },
    );

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('xyz.luan/audioplayers.global'),
      (call) async => 1,
    );
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('xyz.luan/audioplayers'),
      (call) async => 1,
    );
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/url_launcher'),
      (call) async => true,
    );
    String? mockClipboard;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (methodCall) async {
      if (methodCall.method == 'Clipboard.setData') {
        mockClipboard = (methodCall.arguments as Map)['text'] as String?;
        return null;
      } else if (methodCall.method == 'Clipboard.getData') {
        return <String, dynamic>{'text': mockClipboard};
      }
      return null;
    });
  });

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await SaveManager.instance.init();
    scheduledNotifications.clear();
  });

  group('Step 1: Retention Engine Tests', () {
    test('1. Akvaryum unlocks at Level 3 and 4-hour countdown initialized', () async {
      final save = SaveManager.instance;
      save.highestLevel = 1;
      expect(save.isAquariumUnlocked, isFalse);

      save.highestLevel = 2;
      expect(save.isAquariumUnlocked, isFalse);

      save.highestLevel = 3;
      expect(save.isAquariumUnlocked, isTrue);

      save.highestLevel = 4;
      expect(save.isAquariumUnlocked, isTrue);

      save.highestLevel = 5;
      expect(save.isAquariumUnlocked, isTrue);

    });

    test('2. Level 2 clear triggers notification scheduling with exact copies', () async {
      final save = SaveManager.instance;
      scheduledNotifications.clear();
      await save.recordClassicLevelCleared(2);

      // Allow asynchronous unawaited call to complete
      await Future<void>.delayed(const Duration(milliseconds: 50));

      // Verify notification service scheduled retention loops with exact copies
      expect(scheduledNotifications.isNotEmpty, isTrue);

      final bodies = scheduledNotifications
          .map((n) => n['body'] as String?)
          .whereType<String>()
          .toList();

      expect(bodies.any((b) => b == 'Balıkların acıktı, incilerini toplamayı unutma!'), isTrue);
      expect(bodies.any((b) => b == 'Günün Şanslı Balığı seni bekliyor (3x Altın)!'), isTrue);
    });

    testWidgets('3. OfflineEarningsDialog displays exact copy when offline gold > 0', (tester) async {
      final save = SaveManager.instance;
      save.unlockedFish = ['guppy'];
      final now = DateTime.now().millisecondsSinceEpoch;
      save.fishFedTimestamps['guppy'] = now - (SaveManager.fishPayoutDurationMs + 1000);

      expect(save.currentAvailableFishGold, greaterThan(0));
      final readyGold = save.currentAvailableFishGold;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (ctx) => ElevatedButton(
                onPressed: () => OfflineEarningsDialog.show(ctx, save: save),
                child: const Text('SHOW'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('SHOW'));
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Akvaryum Hasadı!'), findsOneWidget);
      expect(find.text('Yokken balıkların $readyGold altın biriktirdi!'), findsOneWidget);
      expect(find.text('+$readyGold'), findsOneWidget);
    });

    testWidgets('4. In-App Review fallback prompt displays for Level 6 or 10 3-star victory', (tester) async {
      final save = SaveManager.instance;
      save.language = 'tr';
      save.hasRequestedReview = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (ctx) => ElevatedButton(
                onPressed: () => InAppReviewManager.instance.showFallbackRatingDialog(ctx, level: 6),
                child: const Text('RATE'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('RATE'));
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text("Kırmataş'ı Sevdin mi?"), findsOneWidget);
      expect(find.text('Puan Ver'), findsOneWidget);
      expect(find.text('Daha Sonra'), findsOneWidget);

      await tester.tap(find.text('Daha Sonra'));
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text("Kırmataş'ı Sevdin mi?"), findsNothing);
    });

    testWidgets('4b. LevelClearCard triggers review check on 3-star clear at Level 6', (tester) async {
      final save = SaveManager.instance;
      save.language = 'tr';
      save.hasRequestedReview = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: LevelClearCard(
              level: 6,
              stars: 3,
              score: 5000,
              goldEarned: 100,
              onNextLevel: () {},
            ),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // After Level 6 with 3 stars, save has marked review as requested
      expect(save.hasRequestedReview, isTrue);
    });

    testWidgets('4c. Rate-limiting prevents multiple review requests', (tester) async {
      final save = SaveManager.instance;
      save.language = 'tr';
      save.hasRequestedReview = true;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: LevelClearCard(
              level: 10,
              stars: 3,
              score: 10000,
              goldEarned: 200,
              onNextLevel: () {},
            ),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      // Fallback dialog must not show because already requested
      expect(find.text("Kırmataş'ı Sevdin mi?"), findsNothing);
    });
  });

  group('Step 3: Viral Loop Tests', () {
    test('5. Claiming friend invite reward awards +150 gold', () async {
      final save = SaveManager.instance;
      final initialGold = save.gold;
      final initialInvites = save.friendInvitesSent;

      final ok = await save.claimFriendInviteReward(amount: 150);
      expect(ok, isTrue);
      expect(save.gold, initialGold + 150);
      expect(save.friendInvitesSent, initialInvites + 1);
    });

    testWidgets('5b. TournamentDialog renders viral invite card with player tag and +150 Gold reward', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final save = SaveManager.instance;
      save.playerTag = '#KRM-TEST';

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (ctx) => ElevatedButton(
                onPressed: () => TournamentDialog.show(ctx, save: save, initialTab: 0),
                child: const Text('OPEN'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('OPEN'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.text('Arkadaşını Getir (+150 Altın)'), findsWidgets);
      expect(find.text('"Kırmataş\'ta skorumu geçebilir misin? Beni ekle: #KRM-TEST"'), findsWidgets);
      expect(find.text('WhatsApp'), findsWidgets);
      expect(find.text('Hikaye / Paylaş'), findsWidgets);
    });

    testWidgets('5c. Tapping share button awards +150 Gold and copies invite message', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final save = SaveManager.instance;
      save.playerTag = '#KRM-VIRAL';
      final initialGold = save.gold;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (ctx) => ElevatedButton(
                onPressed: () => TournamentDialog.show(ctx, save: save, initialTab: 0),
                child: const Text('OPEN'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('OPEN'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      final shareBtn = find.widgetWithText(KaunosTactileButton, 'Hikaye / Paylaş').first;
      await tester.tap(shareBtn);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Gold increased by 150
      expect(save.gold, initialGold + 150);

      // Clipboard has invite text
      final clip = await Clipboard.getData(Clipboard.kTextPlain);
      expect(clip?.text, contains('Kırmataş\'ta skorumu geçebilir misin? Beni ekle: #KRM-VIRAL'));
      expect(clip?.text, contains('https://play.google.com/store/apps/details?id=com.kaunos.kirmatas'));

      // Settle SnackBar timer
      await tester.pump(const Duration(seconds: 4));
    });
  });
}
