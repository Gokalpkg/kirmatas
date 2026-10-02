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

double noteToFreq(int note) => 440.0 * pow(2.0, (note - 69) / 12.0);

void main() {
  int sampleRate = 44100;
  double bpm = 115.0;
  double beatDuration = 60.0 / bpm; // duration of one beat in seconds
  int totalBeats = 16 * 20; // 8.34 seconds loop
  int totalSamples = (beatDuration * totalBeats * sampleRate).toInt();
  
  List<double> track = List.filled(totalSamples, 0.0);
  Random rand = Random();
  
  // Notes: C minor pentatonic
  int bassNote1 = 36; // C2
  int bassNote2 = 39; // Eb2
  int bassNote3 = 43; // G2
  int bassNote4 = 46; // Bb2
  
  List<int> bassPattern = [
    bassNote1, bassNote1, bassNote1, bassNote1, 
    bassNote2, bassNote2, bassNote3, bassNote4
  ];
  
  for (int b = 0; b < totalBeats * 2; b++) { // 8th notes
    int note = bassPattern[b % bassPattern.length];
    double freq = noteToFreq(note);
    int startSample = (b * beatDuration / 2 * sampleRate).toInt();
    int endSample = ((b + 1) * beatDuration / 2 * sampleRate).toInt();
    
    double phase = 0;
    for (int i = startSample; i < endSample; i++) {
      if (i >= totalSamples) break;
      double t = (i - startSample) / sampleRate;
      double env = exp(-3.0 * t); // Decaying envelope
      phase += freq * 2 * pi / sampleRate;
      
      // Sawtooth
      double val = 2.0 * (phase / (2 * pi) - (phase / (2 * pi)).floor()) - 1.0;
      // Simple Low-pass filter approximation by dampening high frequencies
      track[i] += val * 0.4 * env;
    }
  }
  
  // 2. Arpeggio (Square wave)
  List<int> arpPattern = [60, 63, 67, 70, 67, 63, 72, 67];
  for (int b = 0; b < totalBeats * 4; b++) { // 16th notes
    int note = arpPattern[b % arpPattern.length];
    double freq = noteToFreq(note);
    int startSample = (b * beatDuration / 4 * sampleRate).toInt();
    int endSample = ((b + 1) * beatDuration / 4 * sampleRate).toInt();
    
    double phase = 0;
    for (int i = startSample; i < endSample; i++) {
      if (i >= totalSamples) break;
      double t = (i - startSample) / sampleRate;
      double env = exp(-8.0 * t);
      phase += freq * 2 * pi / sampleRate;
      
      double val = sin(phase) > 0 ? 0.25 : -0.25;
      track[i] += val * env;
    }
  }
  
  // 3. Kick Drum (Sine sweep)
  for (int b = 0; b < totalBeats; b++) {
    int startSample = (b * beatDuration * sampleRate).toInt();
    int endSample = startSample + (0.2 * sampleRate).toInt();
    
    double phase = 0;
    for (int i = startSample; i < endSample; i++) {
      if (i >= totalSamples) break;
      double t = (i - startSample) / sampleRate;
      double freq = 150.0 * exp(-20.0 * t); // Pitch drop
      double env = exp(-10.0 * t);
      phase += freq * 2 * pi / sampleRate;
      track[i] += sin(phase) * 0.7 * env;
    }
  }
  
  // 4. Snare Drum (Noise)
  for (int b = 0; b < totalBeats; b++) {
    if (b % 2 == 0) continue; // Snare on beats 2 and 4
    int startSample = (b * beatDuration * sampleRate).toInt();
    int endSample = startSample + (0.25 * sampleRate).toInt();
    
    for (int i = startSample; i < endSample; i++) {
      if (i >= totalSamples) break;
      double t = (i - startSample) / sampleRate;
      double env = exp(-15.0 * t);
      double noise = rand.nextDouble() * 2.0 - 1.0;
      track[i] += noise * 0.4 * env;
    }
  }

  // Normalize
  double maxVal = 0.0;
  for (var val in track) {
    if (val.abs() > maxVal) maxVal = val.abs();
  }
  if (maxVal > 0) {
    for (int i = 0; i < track.length; i++) {
      track[i] = track[i] / maxVal * 0.7; // Leave headroom
    }
  }

  writeWav('bgm.wav', track);
}

