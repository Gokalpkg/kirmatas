import 'dart:async';
import 'dart:io' show Platform;
import 'dart:math' as math;

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:vibration/vibration.dart';
import '../models/game_state.dart';
import '../storage/save_manager.dart';

enum GameSfx {
  hitPaddle, hitWall, hitBrick, breakBrick, steel,
  powerupBuff, powerupDebuff, laser, explosion, ulti,
  bubble, click, gameOver, victory,
  cornerBoost, bossHit, wallBounce8
}

class AudioManager {
  static final AudioManager instance = AudioManager._internal();
  AudioManager._internal() {
    _bgmLead = _bgmA;
    _bgmNext = _bgmB;
    if (!kIsWeb && Platform.environment.containsKey('FLUTTER_TEST')) {
      _bgmA.positionUpdater = null;
      _bgmB.positionUpdater = null;
    }
    _bindBgm(_bgmA);
    _bindBgm(_bgmB);
  }

  final Map<String, List<AudioPlayer>> _pools = {};
  final Map<String, String> _poolAssets = {};
  final Map<String, int> _poolIndices = {};
  final Map<AudioPlayer, int> _playToken = {};
  final Map<GameSfx, int> _lastSfxAt = {};
  final AudioPlayer _bgmA = AudioPlayer();
  final AudioPlayer _bgmB = AudioPlayer();
  late AudioPlayer _bgmLead;
  late AudioPlayer _bgmNext;
  Duration _bgmDuration = Duration.zero;
  bool _seamArmed = false;
  bool _bgmNextReady = false;
  Timer? _seamTimer;

  bool _hasVib = false;
  bool _hasAmp = false;
  int _lastVibTime = 0;
  bool appInForeground = true;
  bool isBgmAllowed = true;
  double playDuck = 1.0;

  double get _bgmGain => (SaveManager.instance.bgmVolume / 8.0) * 0.32 * playDuck;

  Future<void> _loadPool(String key, String path, int count) async {
    try {
      final asset = path.replaceFirst('assets/', '');
      _poolAssets[key] = asset;
      final list = <AudioPlayer>[];
      for (int i = 0; i < count; i++) {
        final p = AudioPlayer();
        p.positionUpdater = null;
        await p.setPlayerMode(PlayerMode.lowLatency);
        await p.setReleaseMode(ReleaseMode.stop);
        await p.setSource(AssetSource(asset));
        list.add(p);
      }
      _pools[key] = list;
      _poolIndices[key] = 0;
    } catch (_) {}
  }

  Future<void> init() async {
    try {
      final mix = AudioContext(
        android: AudioContextAndroid(
          isSpeakerphoneOn: false,
          stayAwake: false,
          contentType: AndroidContentType.sonification,
          usageType: AndroidUsageType.game,
          audioFocus: AndroidAudioFocus.none,
        ),
        iOS: AudioContextIOS(
          category: AVAudioSessionCategory.ambient,
          options: {AVAudioSessionOptions.mixWithOthers},
        ),
      );
      await AudioPlayer.global.setAudioContext(mix);
    } catch (_) {}

    await _loadPool('bounce', 'assets/audio/custom_bounce.wav', 4);
    await _loadPool('brick_neon', 'assets/audio/glass_neon1.mp3', 2);
    await _loadPool('brick_pixel', 'assets/audio/chip1.mp3', 2);
    await _loadPool('brick_gloss', 'assets/audio/y2k_digital1.mp3', 2);
    await _loadPool('brick_neu', 'assets/audio/pop2.mp3', 2);
    await _loadPool('brick_cyber', 'assets/audio/glass_shatter.mp3', 2);
    await _loadPool('laser', 'assets/audio/custom_laser.wav', 2);
    await _loadPool('explosion', 'assets/audio/custom_explosion.wav', 2);
    await _loadPool('ulti', 'assets/audio/ui_fx1.mp3', 2);
    try {
      _hasVib = await Vibration.hasVibrator();
      if (_hasVib) {
        _hasAmp = await Vibration.hasAmplitudeControl();
      }
    } catch (e) {
      _hasVib = false;
    }
    try {
      await _primeBgm(_bgmA);
      await _primeBgm(_bgmB);
      _bgmLead = _bgmA;
      _bgmNext = _bgmB;
      _bgmNextReady = true;
      _seamArmed = false;
      if (isBgmAllowed && appInForeground && SaveManager.instance.bgmVolume > 0) {
        await _bgmLead.setVolume(_bgmGain);
        await _bgmLead.resume();
        if (!isBgmAllowed || !appInForeground) {
          await _bgmLead.pause();
        }
      }
    } catch (_) {}
  }

  void _bindBgm(AudioPlayer player) {
    if (!kIsWeb && Platform.environment.containsKey('FLUTTER_TEST')) {
      return;
    }
    player.onDurationChanged.listen((d) {
      if (d > _bgmDuration) _bgmDuration = d;
    });
    player.onPositionChanged.listen((pos) {
      if (!identical(player, _bgmLead) || _seamArmed || !_bgmNextReady) return;
      if (!isBgmAllowed || !appInForeground || SaveManager.instance.bgmVolume <= 0) return;
      if (_bgmDuration == Duration.zero || pos < const Duration(seconds: 2)) return;
      final left = _bgmDuration - pos;
      if (left <= const Duration(milliseconds: 320) && left > Duration.zero) {
        _beginSeam();
      }
    });
    player.onPlayerComplete.listen((_) {
      _onLeadComplete(player);
    });
  }

  Future<void> _primeBgm(AudioPlayer player) async {
    await player.setReleaseMode(ReleaseMode.stop);
    await player.setVolume(0);
    await player.play(AssetSource('audio/bgm.wav'), volume: 0);
    await player.pause();
    await player.seek(Duration.zero);
    await player.setVolume(0);
  }

  Future<void> _beginSeam() async {
    if (_seamArmed || !_bgmNextReady) return;
    _seamArmed = true;
    try {
      await _bgmNext.seek(Duration.zero);
      await _bgmNext.setVolume(0);
      await _bgmNext.resume();
      _crossfade();
    } catch (_) {
      _seamArmed = false;
    }
  }

  void _crossfade() {
    _seamTimer?.cancel();
    final outgoing = _bgmLead;
    final incoming = _bgmNext;
    const steps = 10;
    var i = 0;
    _seamTimer = Timer.periodic(const Duration(milliseconds: 28), (t) {
      i++;
      final f = (i / steps).clamp(0.0, 1.0);
      final g = _bgmGain;
      outgoing.setVolume(g * math.cos(f * math.pi / 2));
      incoming.setVolume(g * math.sin(f * math.pi / 2));
      if (i >= steps) t.cancel();
    });
  }

  void _onLeadComplete(AudioPlayer player) {
    if (!identical(player, _bgmLead)) return;
    _seamTimer?.cancel();
    final handoffStarted = _seamArmed;
    final done = _bgmLead;
    final next = _bgmNext;
    _bgmLead = next;
    _bgmNext = done;
    _seamArmed = false;
    _bgmNextReady = true;
    final g = _bgmGain;
    _bgmNext.setVolume(0);
    if (handoffStarted) {
      _bgmLead.setVolume(g);
      return;
    }
    _bgmLead.setVolume(g);
    final lead = _bgmLead;
    unawaited(() async {
      try {
        await lead.seek(Duration.zero);
        await lead.resume();
      } catch (_) {}
    }());
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
      _seamTimer?.cancel();
      await _bgmA.pause();
      await _bgmB.pause();
    } catch (_) {}
    if (_hasVib) {
      try {
        await Vibration.cancel();
      } catch (_) {}
    }
  }
  Future<void> pauseBgm() async {
    try {
      _seamTimer?.cancel();
      if (_seamArmed) {
        final done = _bgmLead;
        _bgmLead = _bgmNext;
        _bgmNext = done;
        _seamArmed = false;
        _bgmNextReady = true;
      }
      await _bgmLead.pause();
      await _bgmNext.pause();
      await _bgmNext.setVolume(0);
      if (isBgmAllowed && appInForeground && SaveManager.instance.bgmVolume > 0) {
        await resumeBgm();
      }
    } catch (_) {}
  }

  Future<void> resumeBgm() async {
    if (!isBgmAllowed || !appInForeground) return;
    final vol = SaveManager.instance.bgmVolume;
    if (vol <= 0) {
      await pauseBgm();
      return;
    }
    final targetVolume = _bgmGain;
    try {
      await _bgmNext.setVolume(0);
      if (_bgmLead.state == PlayerState.playing) {
        await _bgmLead.setVolume(targetVolume);
        return;
      }
      await _bgmLead.setVolume(targetVolume);
      if (_bgmLead.state == PlayerState.paused || _bgmLead.state == PlayerState.completed) {
        await _bgmLead.resume();
        return;
      }
      await _bgmLead.setReleaseMode(ReleaseMode.stop);
      await _bgmLead.play(AssetSource('audio/bgm.wav'), volume: targetVolume);
    } catch (_) {}
  }

  void updateBgmVolume() {
    final vol = SaveManager.instance.bgmVolume;
    if (vol <= 0) {
      pauseBgm();
    } else {
      if (!_seamArmed) {
        _bgmLead.setVolume(_bgmGain);
        _bgmNext.setVolume(0);
      }
      if (_bgmLead.state != PlayerState.playing && appInForeground && isBgmAllowed) {
        resumeBgm();
      }
    }
  }

  void playSfx(GameSfx sfx) {
    if (!appInForeground) return;
    if (!SaveManager.instance.sfxEnabled) return;

    final now = DateTime.now().millisecondsSinceEpoch;
    final lastSame = _lastSfxAt[sfx] ?? 0;
    if (now - lastSame < 28) {
      _maybeVibrate(sfx, now);
      return;
    }
    _lastSfxAt[sfx] = now;

    final volLevel = SaveManager.instance.sfxVolume;
    if (volLevel > 0) {
      
      String soundKey = 'bounce';
      double gain = 0.4;
      
      switch (sfx) {
        case GameSfx.breakBrick:
          final curStyle = SaveManager.instance.activeBrickStyle;
          soundKey = curStyle == 'random' ? 'brick_neon' : curStyle;
          gain = 0.65;
          break;
        case GameSfx.laser:
          soundKey = 'laser';
          gain = 0.5;
          break;
        case GameSfx.cornerBoost:
          soundKey = 'laser';
          gain = 0.85;
          break;
        case GameSfx.bossHit:
          soundKey = 'explosion';
          gain = 0.75;
          break;
        case GameSfx.wallBounce8:
          soundKey = 'ulti';
          gain = 0.8;
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
      final asset = _poolAssets[soundKey] ?? 'audio/custom_bounce.wav';
      if (pool != null && pool.isNotEmpty) {
        final volume = (volLevel / 8.0) * gain;
        int idx = _poolIndices[soundKey] ?? 0;
        final p = pool[idx];
        _poolIndices[soundKey] = (idx + 1) % pool.length;
        
        final token = (_playToken[p] ?? 0) + 1;
        _playToken[p] = token;
        _restart(p, asset, volume, token);
      }
    }

    _maybeVibrate(sfx, now);
  }

  Future<void> _restart(AudioPlayer player, String asset, double volume, int token) async {
    try {
      await player.stop();
    } catch (_) {}
    if (_playToken[player] != token) return;
    try {
      await player.play(
        AssetSource(asset),
        volume: volume,
        mode: PlayerMode.lowLatency,
      );
    } catch (_) {}
  }

  void _maybeVibrate(GameSfx sfx, int now) {
    if (!appInForeground) return;
    final save = SaveManager.instance;
    if (!save.hapticsEnabled || save.vibrationLevel <= 0) return;

    final minInterval = (sfx == GameSfx.bossHit || sfx == GameSfx.cornerBoost || sfx == GameSfx.wallBounce8) ? 60 : 85;
    if (now - _lastVibTime < minInterval) return;
    _lastVibTime = now;

    // 1. Native Flutter Haptic Feedback (Works universally on all mobile platforms)
    try {
      switch (sfx) {
        case GameSfx.explosion:
        case GameSfx.gameOver:
        case GameSfx.bossHit:
          HapticFeedback.heavyImpact();
          break;
        case GameSfx.powerupBuff:
        case GameSfx.powerupDebuff:
        case GameSfx.ulti:
        case GameSfx.laser:
        case GameSfx.victory:
        case GameSfx.cornerBoost:
        case GameSfx.wallBounce8:
          HapticFeedback.mediumImpact();
          break;
        case GameSfx.hitPaddle:
        case GameSfx.breakBrick:
        case GameSfx.bubble:
        case GameSfx.steel:
          HapticFeedback.lightImpact();
          break;
        case GameSfx.click:
        case GameSfx.hitBrick:
        case GameSfx.hitWall:
          HapticFeedback.selectionClick();
          break;
      }
    } catch (_) {}

    // 2. Hardware vibration with custom amplitude tuning
    if (_hasVib) {
      final vibLevel = save.vibrationLevel;
      int dur;
      int amp;
      switch (sfx) {
        case GameSfx.bossHit:
        case GameSfx.explosion:
          dur = 32 + vibLevel * 5;
          amp = (vibLevel * 35).clamp(1, 255);
          break;
        case GameSfx.cornerBoost:
        case GameSfx.wallBounce8:
        case GameSfx.ulti:
          dur = 22 + vibLevel * 4;
          amp = (vibLevel * 30).clamp(1, 240);
          break;
        case GameSfx.breakBrick:
          dur = 14 + vibLevel * 3;
          amp = (vibLevel * 20).clamp(1, 180);
          break;
        case GameSfx.hitPaddle:
          dur = 11 + vibLevel * 2;
          amp = (vibLevel * 16).clamp(1, 150);
          break;
        default:
          dur = 9 + vibLevel * 2;
          amp = (vibLevel * 14).clamp(1, 130);
          break;
      }
      try {
        if (_hasAmp) {
          Vibration.vibrate(duration: dur, amplitude: amp);
        } else {
          Vibration.vibrate(duration: dur);
        }
      } catch (_) {}
    }
  }

  void triggerTestHaptic(HapticIntensity h) {}
  void triggerHaptic(Future<void> Function() func) {
    func();
  }

  void dispose() {}
}



