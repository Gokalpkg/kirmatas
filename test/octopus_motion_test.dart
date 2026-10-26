import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:kirmatas/ui/octopus_rig.dart';

void main() {
  const floorY = 726.0;

  OctopusRig makeRig() {
    final r = OctopusRig(Random(7));
    r.x = 200;
    r.y = floorY;
    return r;
  }

  void run(OctopusRig r, double seconds,
      {Offset? finger, Offset? food, bool hungry = true, bool grabbing = false}) {
    const dt = 1 / 60;
    var t = 0.0;
    while (t < seconds) {
      r.step(dt, t, floorY: floorY, finger: finger, food: food, hungry: hungry, grabbing: grabbing);
      t += dt;
    }
  }

  test('jet launches into the water, then glides and sinks back to the sand', () {
    final r = makeRig();
    r.startJet(260, 450, pulses: 2);
    expect(r.state, OctState.jet);
    run(r, 0.2);
    expect(r.y, lessThan(floorY - 10));
    expect(r.mantle, greaterThan(0.5));
    run(r, 8.0);
    expect(r.y, floorY);
    expect(r.state, anyOf(OctState.rest, OctState.crawl));
    expect(r.x, inInclusiveRange(OctopusRig.minX, OctopusRig.maxX));
  });

  test('arm segments keep a sane length in every state', () {
    final r = makeRig();
    double maxSeg() {
      var m = 0.0;
      for (final arm in r.arms) {
        for (int k = 1; k < arm.length; k++) {
          m = max(m, (arm[k] - arm[k - 1]).distance);
        }
      }
      return m;
    }

    run(r, 0.5);
    expect(maxSeg(), lessThan(12.0));
    run(r, 3.0, food: const Offset(330, floorY));
    expect(r.state, OctState.crawl);
    expect(maxSeg(), lessThan(12.0));
    r.startJet(150, 400, pulses: 2);
    run(r, 0.4);
    expect(maxSeg(), lessThan(12.0));
    run(r, 0.5, finger: Offset(r.x + 30, r.y - 10));
    expect(maxSeg(), lessThan(14.0));
  });

  test('crawls toward food on the floor', () {
    final r = makeRig();
    run(r, 4.0, food: const Offset(330, floorY));
    expect(r.x, greaterThan(260));
    expect(r.facingRight, isTrue);
  });

  test('jets up toward a pellet floating in mid-water', () {
    final r = makeRig();
    run(r, 0.1, food: const Offset(220, 400));
    expect(r.isAirborne, isTrue);
    run(r, 3.0, food: const Offset(220, 400));
    expect(r.y, lessThan(520));
  });

  test('reaches for a nearby finger and stays put', () {
    final r = makeRig();
    r.x = 200;
    run(r, 0.3, finger: const Offset(235, floorY - 25));
    expect(r.state, OctState.reach);
    final x0 = r.x;
    run(r, 1.0, finger: const Offset(235, floorY - 25));
    expect((r.x - x0).abs(), lessThan(1.0));
  });

  test('grab pins the octopus and releases back to rest', () {
    final r = makeRig();
    run(r, 0.2, grabbing: true);
    expect(r.state, OctState.grab);
    run(r, 0.2);
    expect(r.state, isNot(OctState.grab));
  });

  test('idle octopus eventually makes a mid-water jet and stays inside the tank', () {
    final r = makeRig();
    var sawJet = false;
    const dt = 1 / 60;
    for (int i = 0; i < 60 * 90; i++) {
      r.step(dt, i * dt, floorY: floorY, hungry: false);
      if (r.state == OctState.jet) sawJet = true;
      expect(r.x, inInclusiveRange(OctopusRig.minX, OctopusRig.maxX));
      expect(r.y, inInclusiveRange(OctopusRig.minY, floorY));
    }
    expect(sawJet, isTrue);
  });
}
