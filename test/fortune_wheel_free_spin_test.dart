import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:kirmatas/storage/save_manager.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Fortune Wheel Free Spin Logic', () {
    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      await SaveManager.instance.init();
    });

    test('First spin of the day is free, spins 2-5 require ads', () async {
      final save = SaveManager.instance;

      // 1. Initial State: 5 spins available, 1st spin is FREE
      expect(save.remainingWheelSpins, equals(5));
      expect(save.canSpinFortuneWheel, isTrue);
      expect(save.isNextWheelSpinFree, isTrue);

      // 2. Perform 1st Spin (Free spin)
      final spin1Ok = await save.recordWheelSpin();
      expect(spin1Ok, isTrue);
      expect(save.remainingWheelSpins, equals(4));
      expect(save.fortuneWheelSpinsToday, equals(1));
      // Next spin is 2nd spin -> NOT free (requires ad)
      expect(save.isNextWheelSpinFree, isFalse);

      // 3. Spins 2-5 are ad-backed and all succeed
      for (var spin = 2; spin <= 5; spin++) {
        final ok = await save.recordWheelSpin();
        expect(ok, isTrue, reason: 'spin $spin should succeed');
        expect(save.fortuneWheelSpinsToday, equals(spin));
        expect(save.remainingWheelSpins, equals(5 - spin));
        expect(save.isNextWheelSpinFree, isFalse);
      }
      expect(save.canSpinFortuneWheel, isFalse);

      // 4. 6th spin should fail as daily limit reached
      final spin6Ok = await save.recordWheelSpin();
      expect(spin6Ok, isFalse);
    });

    test('A new day resets daily spins and makes 1st spin free again', () async {
      final save = SaveManager.instance;

      // Complete all 5 spins today
      for (var i = 0; i < 5; i++) {
        await save.recordWheelSpin();
      }
      expect(save.canSpinFortuneWheel, isFalse);

      // Simulate yesterday's date
      save.lastFortuneWheelDate = '2026-01-01';

      // Next spin is now free and available!
      expect(save.remainingWheelSpins, equals(5));
      expect(save.canSpinFortuneWheel, isTrue);
      expect(save.isNextWheelSpinFree, isTrue);
    });
  });
}
