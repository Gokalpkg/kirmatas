import 'package:audioplayers/audioplayers.dart';
import 'package:vibration/vibration.dart';
import '../models/game_state.dart';
import '../storage/save_manager.dart';

enum GameSfx {
  hitPaddle, hitWall, hitBrick, breakBrick, steel,
  powerupBuff, powerupDebuff, laser, explosion, ulti,
  bubble, click, gameOver, victory
}

class AudioManager {
  static final AudioManager instance = AudioManager._internal();
  AudioManager._internal();

  final Map<String, List<AudioPlayer>> _pools = {};
  final Map<String, int> _poolIndices = {};
  final AudioPlayer _bgmPlayer = AudioPlayer();

  bool _hasVib = false;
  bool _hasAmp = false;
  int _lastVibTime = 0;
  int _lastSfxTime = 0;
  bool appInForeground = true;

  Future<void> _loadPool(String key, String path, int count) async {
    try {
      final list = <AudioPlayer>[];
      for (int i = 0; i < count; i++) {
        final p = AudioPlayer();
        p.setReleaseMode(ReleaseMode.stop);
        p.setSource(AssetSource(path.replaceFirst('assets/', '')));
        list.add(p);
      }
      _pools[key] = list;
      _poolIndices[key] = 0;
    } catch (_) {}
  }

  Future<void> init() async {
    await _loadPool('bounce', 'assets/audio/custom_bounce.wav', 3);
    await _loadPool('brick_neon', 'assets/audio/glass_neon1.mp3', 1);
    await _loadPool('brick_pixel', 'assets/audio/chip1.mp3', 1);
    await _loadPool('brick_gloss', 'assets/audio/y2k_digital1.mp3', 1);
    await _loadPool('brick_neu', 'assets/audio/pop2.mp3', 1);
    await _loadPool('brick_cyber', 'assets/audio/glass_shatter.mp3', 1);
    await _loadPool('laser', 'assets/audio/custom_laser.wav', 1);
    await _loadPool('explosion', 'assets/audio/custom_explosion.wav', 2);
    await _loadPool('ulti', 'assets/audio/ui_fx1.mp3', 1);
    try {
      _hasVib = await Vibration.hasVibrator();
      if (_hasVib) {
        _hasAmp = await Vibration.hasAmplitudeControl();
      }
    } catch (e) {
      _hasVib = false;
    }
    try {
      _bgmPlayer.setReleaseMode(ReleaseMode.loop);
      _bgmPlayer.play(AssetSource('audio/bgm.wav'), volume: SaveManager.instance.bgmVolume / 8.0 * 0.5);
    } catch (_) {}
  }

  Future<void> stopAll() async {
    for (final pool in _pools.values) {
      for (final p in pool) {
        try {
          await p.stop();
        } catch (_) {}
      }
    }
    try {
      await _bgmPlayer.pause();
    } catch (_) {}
    if (_hasVib) {
      try {
        await Vibration.cancel();
      } catch (_) {}
    }
  }

  bool isBgmAllowed = true;
  Future<void> pauseBgm() async { try { await _bgmPlayer.pause(); } catch (_) {} }
  Future<void> resumeBgm() async { if (!isBgmAllowed) return; try { await _bgmPlayer.resume(); } catch (_) {} }

  void updateBgmVolume() {
    _bgmPlayer.setVolume(SaveManager.instance.bgmVolume / 8.0 * 0.5);
  }

  void playSfx(GameSfx sfx) {
    if (!appInForeground) return;

    final now = DateTime.now().millisecondsSinceEpoch;
    if (now - _lastSfxTime < 40) {
      _maybeVibrate(sfx, now);
      return;
    }

    final volLevel = SaveManager.instance.sfxVolume;
    if (volLevel > 0) {
      _lastSfxTime = now;
      
      String soundKey = 'bounce';
      double gain = 0.4;
      
      switch (sfx) {
        case GameSfx.breakBrick:
          soundKey = SaveManager.instance.activeBrickStyle;
          gain = 0.65;
          break;
        case GameSfx.laser:
          soundKey = 'laser';
          gain = 0.5;
          break;
        case GameSfx.explosion:
          soundKey = 'explosion';
          gain = 0.8;
          break;
        case GameSfx.ulti:
          soundKey = 'ulti';
          gain = 0.9;
          break;
        case GameSfx.hitPaddle:
          soundKey = 'bounce';
          gain = 0.55;
          break;
        case GameSfx.hitWall:
        case GameSfx.hitBrick:
          soundKey = 'bounce';
          gain = 0.4;
          break;
        case GameSfx.bubble:
          soundKey = 'bounce';
          gain = 0.3;
          break;
        default:
          soundKey = 'bounce';
          gain = 0.45;
          break;
      }
      
      if (!_pools.containsKey(soundKey) || _pools[soundKey]!.isEmpty) soundKey = 'bounce';
      
      final pool = _pools[soundKey];
      if (pool != null && pool.isNotEmpty) {
        final volume = (volLevel / 8.0) * gain;
        int idx = _poolIndices[soundKey] ?? 0;
        final p = pool[idx];
        _poolIndices[soundKey] = (idx + 1) % pool.length;
        
        p.setVolume(volume);
        p.seek(Duration.zero);
        p.resume();
      }
    }

    _maybeVibrate(sfx, now);
  }

  void _maybeVibrate(GameSfx sfx, int now) {
    if (!appInForeground || !_hasVib) return;
    final vibLevel = SaveManager.instance.vibrationLevel;
    if (vibLevel <= 0) return;
    const felt = {GameSfx.hitPaddle, GameSfx.breakBrick, GameSfx.powerupBuff};
    if (!felt.contains(sfx)) return;
    if (now - _lastVibTime < 160) return;
    _lastVibTime = now;

    final dur = 12 + vibLevel * 2;
    final amp = (vibLevel * 18).clamp(1, 160);
    if (_hasAmp) {
      Vibration.vibrate(duration: dur, amplitude: amp);
    } else {
      Vibration.vibrate(duration: dur);
    }
  }

  void triggerTestHaptic(HapticIntensity h) {}
  void triggerHaptic(Future<void> Function() func) {
    func();
  }

  void dispose() {}
}



