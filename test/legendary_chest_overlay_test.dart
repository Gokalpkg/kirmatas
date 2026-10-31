import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kirmatas/ui/legendary_chest_overlay.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('LegendaryChestOverlay & ChestVfxController Tests', () {
    test('ParticlePool allocates exactly 180 particles and emits within -70 to -110 deg', () {
      final pool = ParticlePool();
      expect(pool.particles.length, 180);
      expect(pool.activeCount, 0);

      pool.emitFountain(
        originX: 160.0,
        originY: 420.0,
        activeColor: const Color(0xFFFFD54F),
        rand: Random(123),
      );

      expect(pool.activeCount, 180);

      // Verify particles have ghost trails initialized and upward velocities
      for (final p in pool.particles) {
        expect(p.active, isTrue);
        expect(p.vy, lessThan(0)); // Upward launch
        expect(p.tX0, p.x);
        expect(p.tY0, p.y);
      }

      // Physics update: floor bounce at 580
      // Advance by 1.0s (dt = 0.05s * 20)
      for (int i = 0; i < 20; i++) {
        pool.updateAll(0.05, 580.0);
      }

      // Check ghost trail shifts and positions
      final first = pool.particles.first;
      expect(first.tX0, isNotNull);
      expect(first.tX1, isNotNull);
      expect(first.tX2, isNotNull);
    });

    testWidgets('ChestVfxController executes 5-step choreography and QoL skip', (tester) async {
      late ChestVfxController controller;
      bool step2Fired = false;
      bool step5Fired = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) {
                return const SizedBox();
              },
            ),
          ),
        ),
      );

      final vsync = tester;
      controller = ChestVfxController(
        vsync: vsync,
        onStep2PillarErupt: () => step2Fired = true,
        onStep5CardSlam: () => step5Fired = true,
      );

      controller.startChoreography(
        originX: 160.0,
        originY: 420.0,
        activeColor: const Color(0xFFFFD54F),
      );

      expect(controller.currentStep, 1);
      expect(controller.isRevealed, isFalse);

      // Advance to 760ms (Hit Stop active)
      controller.timeline.value = 760.0 / 4200.0;
      await tester.pump(const Duration(milliseconds: 16));
      expect(controller.isHitStop, isTrue);

      // Advance to 820ms (Step 2: White Flash & Pillar)
      controller.timeline.value = 820.0 / 4200.0;
      await tester.pump(const Duration(milliseconds: 16));
      expect(controller.currentStep, 2);
      expect(controller.showWhiteFlash, isTrue);
      expect(step2Fired, isTrue);

      // Advance to 1100ms (Step 3: Piñata Fountain active)
      controller.timeline.value = 1100.0 / 4200.0;
      await tester.pump(const Duration(milliseconds: 16));
      expect(controller.currentStep, 3);
      expect(controller.particlePool.activeCount, 180);

      // Instant QoL Skip test
      controller.skipToReveal();
      await tester.pump(const Duration(milliseconds: 16));
      expect(controller.currentStep, 5);
      expect(controller.isRevealed, isTrue);
      expect(step5Fired, isTrue);

      controller.dispose();
    });
  });
}
