import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

void writeWav(String filename, List<double> samples, {int sampleRate = 44100}) {
  int numSamples = samples.length;
  int byteRate = sampleRate * 2;
  var builder = BytesBuilder();
  builder.add('RIFF'.codeUnits);
  builder.add(_int32ToBytes(36 + numSamples * 2));
  builder.add('WAVE'.codeUnits);
  builder.add('fmt '.codeUnits);
  builder.add(_int32ToBytes(16));
  builder.add(_int16ToBytes(1));
  builder.add(_int16ToBytes(1));
  builder.add(_int32ToBytes(sampleRate));
  builder.add(_int32ToBytes(byteRate));
  builder.add(_int16ToBytes(2));
  builder.add(_int16ToBytes(16));
  builder.add('data'.codeUnits);
  builder.add(_int32ToBytes(numSamples * 2));
  for (var sample in samples) {
    int s = (sample * 32767).clamp(-32768, 32767).toInt();
    builder.add(_int16ToBytes(s));
  }
  File('assets/audio/' + filename).writeAsBytesSync(builder.toBytes());
  print('Generated ' + filename);
}

List<int> _int32ToBytes(int value) => [value & 0xff, (value >> 8) & 0xff, (value >> 16) & 0xff, (value >> 24) & 0xff];
List<int> _int16ToBytes(int value) => [value & 0xff, (value >> 8) & 0xff];

void main() {
  List<double> laser = [];
  double phase = 0;
  for (int i = 0; i < 11025; i++) {
    double t = i / 44100;
    double freq = 1200.0 * exp(-15.0 * t);
    phase += freq * 2 * pi / 44100;
    laser.add((sin(phase) > 0 ? 0.3 : -0.3) * (1 - t/0.25));
  }
  writeWav('custom_laser.wav', laser);

  List<double> explosion = [];
  var rand = Random();
  for (int i = 0; i < 22050; i++) {
    double t = i / 44100;
    double env = exp(-10.0 * t);
    double noise = (rand.nextDouble() * 2 - 1) * env;
    explosion.add(noise * 0.8);
  }
  writeWav('custom_explosion.wav', explosion);
  
  List<double> bounce = [];
  phase = 0;
  for (int i = 0; i < 4410; i++) {
    double t = i / 44100;
    double freq = 600.0 + 400.0 * sin(t * pi * 10);
    phase += freq * 2 * pi / 44100;
    bounce.add(sin(phase) * (1 - t/0.1) * 0.5);
  }
  writeWav('custom_bounce.wav', bounce);
}
