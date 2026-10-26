import 'dart:ui';
import 'package:flutter_test/flutter_test.dart';
import 'package:kirmatas/ui/plant_system.dart';

void main() {
  group('Aquarium Plant & Photosynthesis Pearling Tests', () {
    test('All 3 species initialize with distinct blade, stem, and leaf structures', () {
      final vallis = AquariumPlant(
        species: PlantSpecies.vallisneria,
        baseX: 40.0,
        baseY: 750.0,
      );
      final rotala = AquariumPlant(
        species: PlantSpecies.rotala,
        baseX: 120.0,
        baseY: 750.0,
      );
      final anubias = AquariumPlant(
        species: PlantSpecies.anubias,
        baseX: 200.0,
        baseY: 750.0,
        isForeground: true,
      );

      expect(vallis.species, equals(PlantSpecies.vallisneria));
      expect(rotala.species, equals(PlantSpecies.rotala));
      expect(anubias.species, equals(PlantSpecies.anubias));
      expect(anubias.isForeground, isTrue);
    });

    test('Plant photosynthesis update regularly emits oxygen bubbles over time', () {
      final plants = [
        AquariumPlant(species: PlantSpecies.vallisneria, baseX: 40.0, baseY: 750.0),
        AquariumPlant(species: PlantSpecies.rotala, baseX: 120.0, baseY: 750.0),
        AquariumPlant(species: PlantSpecies.anubias, baseX: 200.0, baseY: 750.0),
      ];

      final emittedBubbles = <PlantOxygenBubble>[];

      // Simulate 12 seconds of aquarium time
      const dt = 1.0 / 60.0;
      for (double t = 0.0; t < 12.0; t += dt) {
        for (final p in plants) {
          p.update(dt, t, onEmitOxygen: (x, y, radius) {
            emittedBubbles.add(
              PlantOxygenBubble(
                x: x,
                y: y,
                initialRadius: radius * 0.7,
                maxRadius: radius * 1.5,
                speed: 30.0,
                wobblePhase: 0.0,
              ),
            );
          });
        }
      }

      // Over 12 seconds, multiple pearling bubbles must have been produced
      expect(emittedBubbles.length, greaterThan(3));

      // Each emitted bubble starts near plant height
      for (final b in emittedBubbles) {
        expect(b.y, lessThan(760.0));
        expect(b.y, greaterThan(300.0));
        expect(b.radius, greaterThan(0.5));
      }
    });

    test('PlantOxygenBubble accelerates upward, wobbles, and pops near the surface', () {
      final bubble = PlantOxygenBubble(
        x: 100.0,
        y: 600.0,
        initialRadius: 1.5,
        maxRadius: 3.0,
        speed: 25.0,
        wobblePhase: 0.0,
      );

      const dt = 0.1;
      var popped = false;
      var previousY = bubble.y;
      var previousSpeed = bubble.speed;

      for (int step = 0; step < 300; step++) {
        popped = bubble.update(dt);
        expect(bubble.y, lessThan(previousY)); // must rise
        expect(bubble.speed, greaterThanOrEqualTo(previousSpeed)); // must accelerate
        previousY = bubble.y;
        previousSpeed = bubble.speed;
        if (popped) break;
      }

      expect(popped, isTrue);
      expect(bubble.y, lessThan(65.0)); // popped near water surface
      expect(bubble.radius, greaterThan(1.5)); // expanded
    });

    testWidgets('PlantPainter & PlantOxygenPainter render on canvas without errors', (tester) async {
      final recorder = PictureRecorder();
      final canvas = Canvas(recorder);

      final plants = [
        AquariumPlant(species: PlantSpecies.vallisneria, baseX: 40.0, baseY: 750.0),
        AquariumPlant(species: PlantSpecies.rotala, baseX: 120.0, baseY: 750.0),
        AquariumPlant(species: PlantSpecies.anubias, baseX: 200.0, baseY: 750.0),
      ];

      for (final p in plants) {
        p.paint(canvas, 1.5);
      }

      final bubble = PlantOxygenBubble(
        x: 100.0,
        y: 400.0,
        initialRadius: 2.0,
        maxRadius: 3.5,
        speed: 30.0,
        wobblePhase: 1.0,
      );
      PlantOxygenPainter.paintBubble(canvas, bubble);

      final picture = recorder.endRecording();
      expect(picture, isNotNull);
    });
  });
}
