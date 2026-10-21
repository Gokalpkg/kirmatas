# Smooth BGM renderer for Kirmatas.
# Same harmonic skeleton as the original track (Cm - Eb - Ab - Bb,
# C-minor), re-arranged as a warm, low-register ambient loop:
# sine pads with slow attacks, a soft felt-keys melody and a gentle
# sub bass. Pure sines + a whisper of 2nd harmonic keep the top end
# calm for long sessions. Output: assets/audio/bgm.wav (mono 44.1k).
$code = @'
using System;
using System.IO;

public static class BgmRender {
  static double Freq(int midi){ return 440.0*Math.Pow(2.0,(midi-69)/12.0); }

  static void AddSine(double[] buf, double sr, double t0, double dur, int midi,
                      double gain, double attack, double release, double harm2){
    int s=(int)(t0*sr), n=(int)(dur*sr);
    double f=Freq(midi);
    for(int i=0;i<n && s+i<buf.Length;i++){
      double t=i/sr;
      double env=1.0;
      if(t<attack) env=t/attack;
      double rem=dur-t;
      if(rem<release) env=Math.Min(env, rem/release);
      env=env*env*(3-2*env); // smoothstep envelope, no clicks
      double v=Math.Sin(2*Math.PI*f*t)+harm2*Math.Sin(4*Math.PI*f*t);
      buf[s+i]+=gain*env*v;
    }
  }

  // Soft keys note: quick-ish but rounded attack, exponential decay tail.
  static void AddKey(double[] mix, double sr, double t0, int midi, double gain){
    double dur=2.6; int s=(int)(t0*sr), n=(int)(dur*sr);
    double f=Freq(midi);
    for(int i=0;i<n && s+i<mix.Length;i++){
      double t=i/sr;
      double a=Math.Min(1.0, t/0.03);
      double env=a*Math.Exp(-t*1.9);
      double v=Math.Sin(2*Math.PI*f*t)+0.32*Math.Sin(4*Math.PI*f*t)+0.10*Math.Sin(6*Math.PI*f*t);
      mix[s+i]+=gain*env*v;
    }
  }

  public static void Run(string outPath){
    double sr=44100.0;
    double bpm=72.0, beat=60.0/bpm, bar=4*beat;
    int bars=8;
    double total=bars*bar; // 26.67s seamless loop
    int len=(int)(total*sr)+ (int)(sr*3); // tail room for key decays
    var pad=new double[len]; var key=new double[len]; var bass=new double[len];

    // Chord roots (midi) and triads: Cm, Eb, Ab, Bb
    int[] roots={48, 51, 44, 46};            // C3 Eb3 Ab2 Bb2
    int[][] triads={
      new[]{60,63,67}, new[]{63,67,70}, new[]{56,60,63}, new[]{58,62,65}
    };
    for(int b=0;b<bars;b++){
      int c=b%4; double t0=b*bar;
      // pad triad + root/fifth warmth an octave below the triad
      foreach(int m in triads[c]) AddSine(pad, sr, t0, bar+0.9, m, 0.055, 1.1, 1.2, 0.10);
      AddSine(pad, sr, t0, bar+0.9, roots[c], 0.045, 1.1, 1.2, 0.06);
      AddSine(pad, sr, t0, bar+0.9, roots[c]+7, 0.028, 1.3, 1.2, 0.05);
      // gentle sub bass on beats 1 and 3
      AddSine(bass, sr, t0, beat*1.8, roots[c]-12, 0.16, 0.05, 0.5, 0.0);
      AddSine(bass, sr, t0+2*beat, beat*1.8, roots[c]-12, 0.12, 0.05, 0.5, 0.0);
    }

    // Melody (midi, bar, beatInBar): calm line over the same chords
    int[][] mel={
      new[]{63,0,0}, new[]{67,0,2},
      new[]{70,1,0}, new[]{67,1,2},
      new[]{72,2,0}, new[]{70,2,2},
      new[]{67,3,0}, new[]{65,3,3},
      new[]{63,4,0}, new[]{60,4,2},
      new[]{67,5,0}, new[]{70,5,2},
      new[]{68,6,0}, new[]{67,6,2},
      new[]{65,7,0}, new[]{63,7,2},
    };
    foreach(var nd in mel) AddKey(key, sr, nd[1]*bar + nd[2]*beat, nd[0], 0.20);

    // Dotted-eighth echo on the keys only, mixed low for space.
    var mix=new double[len];
    int dly=(int)(beat*0.75*sr);
    for(int i=0;i<len;i++){
      double e = key[i] + (i>dly ? 0.28*key[i-dly] : 0) + (i>2*dly ? 0.12*key[i-2*dly] : 0);
      mix[i]=pad[i]+bass[i]+e;
    }

    // Seamless loop: crossfade the last 2s into a copy of the head so
    // pad releases and key decays wrap without a click.
    int loopLen=(int)(total*sr);
    int fade=(int)(sr*2.0);
    for(int i=0;i<fade;i++){
      double w=(double)i/fade;
      int tailIdx=loopLen-fade+i;
      mix[tailIdx]= mix[tailIdx]*(1-w) + mix[i]*w;
    }
    double peak=0; for(int i=0;i<loopLen;i++) peak=Math.Max(peak, Math.Abs(mix[i]));
    double g = peak>0.9 ? 0.9/peak : 1.0;

    using(var fs=new FileStream(outPath, FileMode.Create))
    using(var bw=new BinaryWriter(fs)){
      int dataBytes=loopLen*2;
      bw.Write(new char[]{'R','I','F','F'}); bw.Write(36+dataBytes);
      bw.Write(new char[]{'W','A','V','E'}); bw.Write(new char[]{'f','m','t',' '});
      bw.Write(16); bw.Write((short)1); bw.Write((short)1);
      bw.Write((int)sr); bw.Write((int)sr*2); bw.Write((short)2); bw.Write((short)16);
      bw.Write(new char[]{'d','a','t','a'}); bw.Write(dataBytes);
      for(int i=0;i<loopLen;i++){
        double v=Math.Tanh(mix[i]*g*1.1)*0.85;
        short s=(short)Math.Max(short.MinValue, Math.Min(short.MaxValue, v*32767));
        bw.Write(s);
      }
    }
    Console.WriteLine("bgm written: "+total.ToString("0.0")+"s peak="+peak.ToString("0.00"));
  }
}
'@
Add-Type -TypeDefinition $code
[BgmRender]::Run('assets\audio\bgm.wav')
