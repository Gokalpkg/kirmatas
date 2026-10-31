import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kirmatas/engine/particle_system.dart';
import 'package:kirmatas/storage/save_manager.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

  group('Level Clear Confetti & Star Tier Tests', () {
    test('ParticleSystem spawns tiered confetti based on stars', () {
      final ps = ParticleSystem();

      // 3 Stars -> 48 particles (Büyük konfeti)
      ps.spawnLevelClearConfetti(3, 400.0, 800.0);
      expect(ps.confetti.length, equals(48));

      ps.clear();
      expect(ps.confetti, isEmpty);

      // 2 Stars -> 22 particles (Daha az konfeti)
      ps.spawnLevelClearConfetti(2, 400.0, 800.0);
      expect(ps.confetti.length, equals(22));

      ps.clear();

      // 1 Star -> 8 particles (Çok az konfeti)
      ps.spawnLevelClearConfetti(1, 400.0, 800.0);
      expect(ps.confetti.length, equals(8));
    });

    test('Confetti updates position, wobble, and expires correctly', () {
      final ps = ParticleSystem();
      ps.spawnLevelClearConfetti(3, 400.0, 800.0);
      expect(ps.confetti.isNotEmpty, isTrue);

      final initialY = ps.confetti.first.y;
      ps.update(0.1);

      // Gravity and velocity updated
      expect(ps.confetti.first.y, isNot(equals(initialY)));

      // Fast forward life expiration
      ps.update(3.0);
      expect(ps.confetti, isEmpty);
    });
  });
}
