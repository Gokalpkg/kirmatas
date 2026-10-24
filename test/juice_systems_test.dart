import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kirmatas/engine/game_controller.dart';
import 'package:kirmatas/engine/particle_system.dart';
import 'package:kirmatas/models/game_state.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(
      const MethodChannel('xyz.luan/audioplayers.global'),
      (MethodCall methodCall) async => 1,
    );
    messenger.setMockMethodCallHandler(
      const MethodChannel('xyz.luan/audioplayers'),
      (MethodCall methodCall) async => 1,
    );
  });

  group('Coin magnet orbs', () {
    test('orbs scatter, then fly to the counter and arrive one by one', () {
      final ps = ParticleSystem();
      ps.spawnCoinOrbs(100, 200, count: 4);
      expect(ps.coinOrbs.length, 4);

      var arrivals = 0;
      // Scatter + glow phase: no arrivals yet.
      for (var i = 0; i < 5; i++) {
        ps.updateCoinOrbs(0.05, const Offset(330, 30), (_) => arrivals++);
      }
      expect(arrivals, 0);
      expect(ps.coinOrbs.isNotEmpty, true);

      // Fly phase: all orbs eventually arrive and are removed.
      for (var i = 0; i < 40 && ps.coinOrbs.isNotEmpty; i++) {
        ps.updateCoinOrbs(0.05, const Offset(330, 30), (_) => arrivals++);
      }
      expect(arrivals, 4);
      expect(ps.coinOrbs, isEmpty);
    });

    test('coin arrivals punch the HUD counter in game', () {
      final ctrl = GameController();
      ctrl.setDimensions(360, 640);
      ctrl.startNewGame(GameMode.classic);
      ctrl.status = GameStatus.playing;

      ctrl.particles.spawnCoinOrbs(180, 200, count: 3);
      for (var i = 0; i < 60 && ctrl.coinArrivalCount < 3; i++) {
        for (final b in ctrl.balls) {
          b.isStuck = true;
          b.stuckTimer = 0.0;
        }
        ctrl.update(0.05);
      }
      expect(ctrl.coinArrivalCount, 3);
      expect(ctrl.hudGoldPunchTimer, greaterThan(0.0));
    });

    test('orb values split the brick gold and HUD gold rises only on landing', () {
      final ps = ParticleSystem();
      ps.spawnCoinOrbs(100, 200, count: 3, totalValue: 10);
      final values = ps.coinOrbs.map((o) => o.value).toList();
      expect(values.fold<int>(0, (a, b) => a + b), 10);

      var delivered = 0;
      for (var i = 0; i < 60 && ps.coinOrbs.isNotEmpty; i++) {
        ps.updateCoinOrbs(0.05, const Offset(128, 58), (v) => delivered += v);
      }
      expect(delivered, 10);

      final ctrl = GameController();
      ctrl.setDimensions(360, 640);
      ctrl.startNewGame(GameMode.classic);
      ctrl.status = GameStatus.playing;
      final shownAtStart = ctrl.hudGoldShown;

      // Mirror the real flow: gold is banked instantly, orbs carry it home.
      ctrl.save.addGold(7);
      ctrl.particles.spawnCoinOrbs(180, 200, count: 3, totalValue: 7);
      for (final b in ctrl.balls) {
        b.isStuck = true;
        b.stuckTimer = 0.0;
      }
      ctrl.update(0.05);
      expect(ctrl.hudGoldShown, shownAtStart, reason: 'counter must not rise before orbs land');

      for (var i = 0; i < 80 && ctrl.particles.coinOrbs.isNotEmpty; i++) {
        for (final b in ctrl.balls) {
          b.isStuck = true;
          b.stuckTimer = 0.0;
        }
        ctrl.update(0.05);
      }
      expect(ctrl.hudGoldShown, shownAtStart + 7);
    });
  });
}
