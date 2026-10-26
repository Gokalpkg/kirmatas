import 'dart:math';
import 'dart:ui';

import 'package:flutter/material.dart' hide Image;
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:kirmatas/models/cosmetics.dart';
import 'package:kirmatas/storage/save_manager.dart';
import 'package:kirmatas/ui/eco_tank_background.dart';
import 'package:kirmatas/ui/fish_rig.dart';

void main() {
  group('Procedural FishRig & FishStyle System', () {
    test('every FishItem id maps to its distinct species and palette style', () {
      expect(FishItem.allFish.length, 23);

      final seenStyles = <String, FishStyle>{};
      for (final fish in FishItem.allFish) {
        final style = FishStyle.forId(fish.id);
        seenStyles[fish.id] = style;
        expect(style.bodyLength, greaterThan(0));
        expect(style.bodyHeight, greaterThan(0));
        expect(style.baseSpeed, greaterThan(0));
      }

      // Check 6 fish body species × 3 variants
      expect(seenStyles['guppy']!.species, FishSpecies.guppy);
      expect(seenStyles['guppy_blue']!.species, FishSpecies.guppy);
      expect(seenStyles['guppy_green']!.species, FishSpecies.guppy);
      expect(seenStyles['guppy']!.primary, isNot(seenStyles['guppy_blue']!.primary));

      expect(seenStyles['tetra']!.species, FishSpecies.tetra);
      expect(seenStyles['tetra_gold']!.species, FishSpecies.tetra);
      expect(seenStyles['tetra_purple']!.species, FishSpecies.tetra);

      expect(seenStyles['angel']!.species, FishSpecies.angel);
      expect(seenStyles['angel_aqua']!.species, FishSpecies.angel);
      expect(seenStyles['angel_ruby']!.species, FishSpecies.angel);

      expect(seenStyles['betta']!.species, FishSpecies.betta);
      expect(seenStyles['betta_blue']!.species, FishSpecies.betta);
      expect(seenStyles['betta_orange']!.species, FishSpecies.betta);

      expect(seenStyles['discus']!.species, FishSpecies.discus);
      expect(seenStyles['discus_blue']!.species, FishSpecies.discus);
      expect(seenStyles['discus_green']!.species, FishSpecies.discus);

      expect(seenStyles['arowana']!.species, FishSpecies.arowana);
      expect(seenStyles['arowana_red']!.species, FishSpecies.arowana);
      expect(seenStyles['arowana_silver']!.species, FishSpecies.arowana);

      // Check 5 special creatures
      expect(seenStyles['shrimp']!.species, FishSpecies.shrimp);
      expect(seenStyles['crab']!.species, FishSpecies.crab);
      expect(seenStyles['snail']!.species, FishSpecies.snail);
      expect(seenStyles['jellyfish']!.species, FishSpecies.jellyfish);
      expect(seenStyles['octopus']!.species, FishSpecies.octopus);
    });

    test('9-joint spine propagates wave from head to tail and keeps sane segment lengths', () {
      for (final fish in FishItem.allFish) {
        final rig = FishRig(fishId: fish.id, random: Random(11));
        for (int i = 0; i < 60; i++) {
          rig.step(1 / 60, i / 60);
        }
        expect(rig.spine.length, FishRig.spineJoints);
        // Snout (0) has near-zero lateral wave compared to tail (last)
        expect(rig.spine.first.dy.abs(), lessThan(0.5));
        for (int k = 1; k < rig.spine.length; k++) {
          final dist = (rig.spine[k] - rig.spine[k - 1]).distance;
          expect(dist, greaterThan(0.5));
          expect(dist, lessThan(15.0));
        }
      }
    });

    test('smooth U-turn interpolates turnScale and C-bends the spine instead of instant snap', () {
      final rig = FishRig(fishId: 'betta', facingRight: true, random: Random(3));
      expect(rig.turnScale, closeTo(1.0, 0.01));

      // Trigger U-turn to the left
      rig.faceToward(false);
      expect(rig.facingRight, isFalse);
      expect(rig.turnBend.abs(), greaterThan(0.5));

      // After 2 frames (~33ms), turnScale should be mid-transition, not snapped to -1.0
      rig.step(1 / 60, 0.016);
      rig.step(1 / 60, 0.032);
      expect(rig.turnScale, greaterThan(-0.85));
      expect(rig.turnScale, lessThan(0.95));

      // After 1.2 seconds, turnScale settles smoothly at -1.0 and turnBend decays
      for (int i = 0; i < 72; i++) {
        rig.step(1 / 60, (i + 3) / 60);
      }
      expect(rig.turnScale, closeTo(-1.0, 0.02));
      expect(rig.turnBend.abs(), lessThan(0.05));
    });

    test('eye tracks target, blinks periodically, and mouth opens near food pellets', () {
      final rig = FishRig(fishId: 'arowana', x: 200, y: 300, facingRight: true, random: Random(9));
      expect(rig.mouthOpen, closeTo(0.0, 0.01));

      // Step with a nearby food pellet in front of the snout
      for (int i = 0; i < 20; i++) {
        rig.step(
          1 / 60,
          i / 60,
          target: const Offset(222, 290),
          isFoodTarget: true,
        );
      }
      expect(rig.mouthOpen, greaterThan(0.25));
      expect(rig.lookX, greaterThan(0.3));

      // Step without food: mouth closes and blink eventually triggers
      bool sawBlink = false;
      for (int i = 0; i < 60 * 8; i++) {
        rig.step(1 / 60, (i + 20) / 60);
        if (rig.blink > 0) sawBlink = true;
      }
      expect(rig.mouthOpen, lessThan(0.05));
      expect(sawBlink, isTrue);
    });

    test('burst & glide rhythm modulates swimming speed multiplier over time', () {
      final rig = FishRig(fishId: 'guppy', random: Random(5));
      double minMult = 999.0;
      double maxMult = 0.0;
      for (int i = 0; i < 60 * 5; i++) {
        rig.step(1 / 60, i / 60);
        minMult = min(minMult, rig.currentSwimSpeedMultiplier);
        maxMult = max(maxMult, rig.currentSwimSpeedMultiplier);
      }
      expect(maxMult - minMult, greaterThan(0.25));
    });

    test('FishPainter paints all 23 species and variants onto Canvas without exceptions', () {
      final recorder = PictureRecorder();
      final canvas = Canvas(recorder);
      for (final fish in FishItem.allFish) {
        final rig = FishRig(fishId: fish.id, random: Random(19));
        rig.step(1 / 60, 0.5, target: const Offset(230, 350), isFoodTarget: true);
        FishPainter.paint(canvas, rig, 0.5);
      }
      final picture = recorder.endRecording();
      picture.dispose();
    });

    testWidgets('ProceduralFishPreview and EcoTankBackground render all 23 species cleanly', (tester) async {
      SharedPreferences.setMockInitialValues({});
      final save = SaveManager.instance;
      await save.init();
      for (final fish in FishItem.allFish) {
        save.ownedFishCounts[fish.id] = 1;
      }

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Stack(
              children: [
                const EcoTankBackground(interactive: true),
                Wrap(
                  children: [
                    for (final fish in FishItem.allFish)
                      ProceduralFishPreview(fishId: fish.id, size: 32),
                  ],
                ),
              ],
            ),
          ),
        ),
      );

      for (int i = 0; i < 30; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  });
}
