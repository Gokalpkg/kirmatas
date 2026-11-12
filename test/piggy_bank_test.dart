import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kirmatas/storage/save_manager.dart';
import 'package:kirmatas/ui/piggy_bank_dialog.dart';
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

  group('Piggy Bank (Altın Kumbara) System Tests', () {
    late SaveManager save;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      save = SaveManager.instance;
      save.resetForTesting();
      await save.init();
      save.gold = 100;
      save.piggyBankGold = 0;
      save.piggyBankFullCount = 0;
    });

    test('addPiggyBankGold accumulates gold and clamps at piggyBankMax (500)', () {
      expect(save.piggyBankGold, 0);
      expect(save.isPiggyBankFull, isFalse);
      expect(save.canSmashPiggyBank, isFalse);

      save.addPiggyBankGold(40);
      expect(save.piggyBankGold, 40);
      expect(save.canSmashPiggyBank, isFalse);

      save.addPiggyBankGold(30);
      expect(save.piggyBankGold, 70);
      expect(save.canSmashPiggyBank, isTrue);
      expect(save.isPiggyBankFull, isFalse);

      // Add exceeding max
      save.addPiggyBankGold(500);
      expect(save.piggyBankGold, SaveManager.piggyBankMax);
      expect(save.isPiggyBankFull, isTrue);
      expect(save.canSmashPiggyBank, isTrue);
    });

    test('smashPiggyBank awards 100% gold and resets vault', () async {
      save.gold = 200;
      save.piggyBankGold = 350;

      final awarded = await save.smashPiggyBank(doubleReward: false);
      expect(awarded, 350);
      expect(save.gold, 550);
      expect(save.piggyBankGold, 0);
      expect(save.piggyBankFullCount, 1);
      expect(save.canSmashPiggyBank, isFalse);
      expect(save.isPiggyBankFull, isFalse);
    });

    test('smashPiggyBank with doubleReward awards 200% gold', () async {
      save.gold = 100;
      save.piggyBankGold = 250;

      final awarded = await save.smashPiggyBank(doubleReward: true);
      expect(awarded, 500);
      expect(save.gold, 600);
      expect(save.piggyBankGold, 0);
      expect(save.piggyBankFullCount, 1);
    });

    testWidgets('PiggyBankDialog renders correctly and displays current progress', (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      save.piggyBankGold = 250;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (ctx) => ElevatedButton(
                onPressed: () => PiggyBankDialog.show(ctx, save: save),
                child: const Text('OPEN_PIGGY'),
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      await tester.tap(find.text('OPEN_PIGGY'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('ALTIN KUMBARA'), findsOneWidget);
      expect(find.text('250 / 500'), findsOneWidget);
      expect(find.textContaining('KUMBARAYI KIR & 250 ALTIN AL'), findsOneWidget);
      expect(find.textContaining('2X İLE BOŞALT: +500 ALTIN'), findsOneWidget);

      // Tap standard smash button
      await tester.tap(find.textContaining('KUMBARAYI KIR & 250 ALTIN AL'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(save.piggyBankGold, 0);
      expect(save.gold, 350);
    });
  });
}
