import 'package:flutter_test/flutter_test.dart';
import 'package:kirmatas/engine/audio_manager.dart';

void main() {
  group('Long-session BGM duck curve', () {
    double gainAt(int seconds) =>
        AudioManager.duckGainForElapsed(Duration(seconds: seconds));

    test('full volume until the 2 minute mark', () {
      expect(gainAt(0), 1.0);
      expect(gainAt(60), 1.0);
      expect(gainAt(119), 1.0);
      expect(gainAt(120), 1.0);
      expect(gainAt(149), 1.0, reason: 'First step lands at 2:30');
    });

    test('steps down a notch every 30 seconds', () {
      expect(gainAt(150), closeTo(0.9625, 1e-9));
      expect(gainAt(180), closeTo(0.925, 1e-9));
      expect(gainAt(270), closeTo(0.8125, 1e-9));
      // Constant inside each 30s window:
      expect(gainAt(151), gainAt(179));
    });

    test('reaches the floor at 8 minutes and rests there', () {
      expect(gainAt(479), closeTo(0.5875, 1e-9));
      expect(gainAt(480), AudioManager.duckFloor);
      expect(gainAt(1200), AudioManager.duckFloor);
      expect(gainAt(3600), AudioManager.duckFloor);
    });

    test('curve is monotonic and never silent', () {
      var prev = gainAt(0);
      for (var s = 30; s <= 1800; s += 30) {
        final g = gainAt(s);
        expect(g, lessThanOrEqualTo(prev), reason: 'gain rose at ${s}s');
        expect(g, greaterThanOrEqualTo(AudioManager.duckFloor));
        prev = g;
      }
    });
  });
}
