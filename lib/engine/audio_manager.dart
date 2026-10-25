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
  final Map<AudioPlayer, double> _playerRate = {};
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
  bool _appInForeground = true;
  bool get appInForeground => _appInForeground;
  set appInForeground(bool value) {
    if (_appInForeground == value) return;
    _appInForeground = value;
    if (!_appInForeground) {
      _bgmSessionStart = null;
      _longSessionDuck = 1.0;
      stopAll();
    } else {
      if (isBgmAllowed && SaveManager.instance.bgmVolume > 0) {
        resumeBgm();
      }
    }
  }
  bool isBgmAllowed = true;
  double playDuck = 1.0;

  DateTime? _bgmSessionStart;
  double _longSessionDuck = 1.0;

  double get _bgmGain =>
      (SaveManager.instance.bgmVolume / 8.0) * 0.32 * playDuck * _longSessionDuck;

  /// The same loop gets tiring over a long sitting, so the music gently
  /// steps itself down — never off, never abruptly. Full volume for the
  /// first [duckStartSeconds], then one small step every
  /// [duckStepSeconds], reaching [duckFloor] at [duckFullSeconds] and
  /// resting there. Pausing resets the session.
  static const int duckStartSeconds = 120; // 2:00
  static const int duckStepSeconds = 30;
  static const int duckFullSeconds = 480; // 8:00
  static const double duckFloor = 0.55;

  static double duckGainForElapsed(Duration elapsed) {
    final s = elapsed.inSeconds;
    if (s <= duckStartSeconds) return 1.0;
    if (s >= duckFullSeconds) return duckFloor;
    final steps = (s - duckStartSeconds) ~/ duckStepSeconds;
    final totalSteps = (duckFullSeconds - duckStartSeconds) ~/ duckStepSeconds;
    return 1.0 - (1.0 - duckFloor) * steps / totalSteps;
  }

  void _updateLongSessionDuck() {
    final start = _bgmSessionStart;
    if (start == null) return;
    final target = duckGainForElapsed(DateTime.now().difference(start));
    if (target != _longSessionDuck) {
      _longSessionDuck = target;
      try {
        _bgmLead.setVolume(_bgmGain);
      } catch (_) {}
    }
  }

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
          audioFocus: AndroidAudioFocus.gainTransientMayDuck,
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
    await _loadPool('brick_jelly', 'assets/audio/pop2.mp3', 2);
    await _loadPool('brick_cyber', 'assets/audio/glass_shatter.mp3', 2);
    await _loadPool('brick_cosmic', 'assets/audio/glass_glow.mp3', 2);
    await _loadPool('steel', 'assets/audio/crystal_block.mp3', 2);
    await _loadPool('bubble', 'assets/audio/bubble2.mp3', 2);
    await _loadPool('click', 'assets/audio/click1.mp3', 2);
    await _loadPool('powerup_buff', 'assets/audio/ui_a4.mp3', 2);
    await _loadPool('powerup_debuff', 'assets/audio/ui_b3.mp3', 2);
    await _loadPool('victory', 'assets/audio/ui_fx4.mp3', 1);
    await _loadPool('game_over', 'assets/audio/digital_explo2.mp3', 1);
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
        _bgmSessionStart ??= DateTime.now();
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
      _updateLongSessionDuck();
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
    if (_seamArmed || !_bgmNextReady || !_appInForeground || !isBgmAllowed || SaveManager.instance.bgmVolume <= 0) return;
    _seamArmed = true;
    try {
      await _bgmNext.seek(Duration.zero);
      await _bgmNext.setVolume(0);
      if (!_appInForeground || !isBgmAllowed) {
        _seamArmed = false;
        return;
      }
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
      if (!_appInForeground || !isBgmAllowed) {
        t.cancel();
        outgoing.setVolume(0);
        incoming.setVolume(0);
        return;
      }
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
    if (!_appInForeground || !isBgmAllowed || SaveManager.instance.bgmVolume <= 0) {
      _bgmLead.setVolume(0);
      _bgmNext.setVolume(0);
      return;
    }
    if (handoffStarted) {
      _bgmLead.setVolume(g);
      return;
    }
    _bgmLead.setVolume(g);
    final lead = _bgmLead;
    unawaited(() async {
      try {
        if (!_appInForeground || !isBgmAllowed) return;
        await lead.seek(Duration.zero);
        await lead.resume();
      } catch (_) {}
    }());
  }

  Future<void> stopAll() async {
    _seamTimer?.cancel();
    _seamArmed = false;
    try {
      _bgmA.setVolume(0);
      _bgmB.setVolume(0);
      _bgmLead.setVolume(0);
      _bgmNext.setVolume(0);
      await _bgmA.pause();
      await _bgmB.pause();
    } catch (_) {}
    for (final pool in _pools.values) {
      for (final p in pool) {
        try {
          p.setVolume(0);
          await p.stop();
        } catch (_) {}
      }
    }
    if (_hasVib) {
      try {
        await Vibration.cancel();
      } catch (_) {}
    }
  }

  Future<void> pauseBgm() async {
    _bgmSessionStart = null;
    _longSessionDuck = 1.0;
    try {
      _seamTimer?.cancel();
      if (_seamArmed) {
        final done = _bgmLead;
        _bgmLead = _bgmNext;
        _bgmNext = done;
        _seamArmed = false;
        _bgmNextReady = true;
      }
      _bgmLead.setVolume(0);
      _bgmNext.setVolume(0);
      await _bgmLead.pause();
      await _bgmNext.pause();
    } catch (_) {}
  }

  Future<void> resumeBgm() async {
    if (!isBgmAllowed || !appInForeground) return;
    _bgmSessionStart ??= DateTime.now();
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

  int lastPlayedCombo = 0;
  double lastPlaybackRate = 1.0;
  String lastResolvedSoundKey = 'bounce';

  void setDynamicTempo({bool isFever = false, bool isBoss = false}) {
    try {
      double rate = 1.0;
      if (isFever) {
        rate = 1.08;
      } else if (isBoss) {
        rate = 1.04;
      }
      _bgmLead.setPlaybackRate(rate);
      _bgmNext.setPlaybackRate(rate);
    } catch (_) {}
  }

  /// Resolves the canonical sound pool key for a given [GameSfx] and active brick style.
  String resolveSoundKey(GameSfx sfx) {
    switch (sfx) {
      case GameSfx.breakBrick:
        final curStyle = SaveManager.instance.activeBrickStyle;
        if (curStyle == 'random' || curStyle.isEmpty) {
          return 'brick_neon';
        }
        return curStyle.startsWith('brick_') ? curStyle : 'brick_$curStyle';
      case GameSfx.laser:
      case GameSfx.cornerBoost:
        return 'laser';
      case GameSfx.bossHit:
      case GameSfx.explosion:
        return 'explosion';
      case GameSfx.wallBounce8:
      case GameSfx.ulti:
        return 'ulti';
      case GameSfx.steel:
        return 'steel';
      case GameSfx.bubble:
        return 'bubble';
      case GameSfx.click:
        return 'click';
      case GameSfx.powerupBuff:
        return 'powerup_buff';
      case GameSfx.powerupDebuff:
        return 'powerup_debuff';
      case GameSfx.victory:
        return 'victory';
      case GameSfx.gameOver:
        return 'game_over';
      case GameSfx.hitPaddle:
      case GameSfx.hitWall:
      case GameSfx.hitBrick:
        return 'bounce';
    }
  }

  double _resolveGain(GameSfx sfx) {
    switch (sfx) {
      case GameSfx.breakBrick:
        return 0.65;
      case GameSfx.laser:
        return 0.50;
      case GameSfx.cornerBoost:
        return 0.85;
      case GameSfx.bossHit:
        return 0.75;
      case GameSfx.wallBounce8:
        return 0.80;
      case GameSfx.explosion:
        return 0.80;
      case GameSfx.ulti:
        return 0.90;
      case GameSfx.steel:
        return 0.60;
      case GameSfx.bubble:
        return 0.45;
      case GameSfx.click:
        return 0.50;
      case GameSfx.powerupBuff:
        return 0.60;
      case GameSfx.powerupDebuff:
        return 0.60;
      case GameSfx.victory:
        return 0.80;
      case GameSfx.gameOver:
        return 0.75;
      case GameSfx.hitPaddle:
        return 0.55;
      case GameSfx.hitWall:
      case GameSfx.hitBrick:
        return 0.40;
    }
  }

  void playSfx(GameSfx sfx, {int combo = 0, double? playbackRate}) {
    lastPlayedCombo = combo;
    double effectiveRate = playbackRate ?? 1.0;
    if (playbackRate == null && (sfx == GameSfx.hitBrick || sfx == GameSfx.breakBrick) && combo > 0) {
      // Step 4: 8-bit chiptune ascending pitch arpeggio:
      // Scales pitch progressively with combo hits (1.05x -> 1.50x)
      final step = combo.clamp(0, 10);
      effectiveRate = 1.0 + (step * 0.05);
    } else if (playbackRate == null && sfx == GameSfx.hitPaddle) {
      // Thematic Paddle Timbre: vary acoustic pitch & resonance by equipped paddle skin
      final paddleSkin = SaveManager.instance.activePaddle.toLowerCase();
      if (paddleSkin.contains('fire') || paddleSkin.contains('inferno') || paddleSkin.contains('flame')) {
        effectiveRate = 0.88; // Deep crackling impact tone
      } else if (paddleSkin.contains('ice') || paddleSkin.contains('frost') || paddleSkin.contains('crystal')) {
        effectiveRate = 1.26; // High crystalline resonant chime
      } else if (paddleSkin.contains('cyber') || paddleSkin.contains('neon') || paddleSkin.contains('laser')) {
        effectiveRate = 1.15; // Crisp synth bite
      } else if (paddleSkin.contains('cosmic') || paddleSkin.contains('gold') || paddleSkin.contains('void')) {
        effectiveRate = 1.06; // Mellow harmonic resonance
      } else {
        effectiveRate = 1.0;
      }
    }
    lastPlaybackRate = effectiveRate;
    final resolvedKey = resolveSoundKey(sfx);
    lastResolvedSoundKey = resolvedKey;
    if (!appInForeground) return;
    if (!SaveManager.instance.sfxEnabled) return;

    // Independent Audio Mixer channels for Paddle, Ball, and Bricks
    double categoryMultiplier = 1.0;
    if (sfx == GameSfx.hitPaddle) {
      categoryMultiplier = SaveManager.instance.paddleVolume / 8.0;
    } else if (sfx == GameSfx.hitWall) {
      categoryMultiplier = SaveManager.instance.ballVolume / 8.0;
    } else if (sfx == GameSfx.hitBrick || sfx == GameSfx.breakBrick || sfx == GameSfx.steel) {
      categoryMultiplier = SaveManager.instance.brickVolume / 8.0;
    }
    if (categoryMultiplier <= 0) return;

    final now = DateTime.now().millisecondsSinceEpoch;
    final lastSame = _lastSfxAt[sfx] ?? 0;
    // Throttle identical SFX to 42ms to prevent Android AudioPlayer platform channel queue saturation
    if (now - lastSame < 42) {
      _maybeVibrate(sfx, now);
      return;
    }
    _lastSfxAt[sfx] = now;

    final volLevel = SaveManager.instance.sfxVolume;
    if (volLevel > 0) {
      String soundKey = resolvedKey;
      final double gain = _resolveGain(sfx);

      if (!_pools.containsKey(soundKey) || _pools[soundKey]!.isEmpty) soundKey = 'bounce';
      
      final pool = _pools[soundKey];
      final asset = _poolAssets[soundKey] ?? 'audio/custom_bounce.wav';
      if (pool != null && pool.isNotEmpty) {
        final volume = (volLevel / 8.0) * categoryMultiplier * gain;
        int idx = _poolIndices[soundKey] ?? 0;
        final p = pool[idx];
        _poolIndices[soundKey] = (idx + 1) % pool.length;
        
        final token = (_playToken[p] ?? 0) + 1;
        _playToken[p] = token;
        _restart(p, asset, volume, token, playbackRate: effectiveRate);
      }
    }

    _maybeVibrate(sfx, now);
  }

  Future<void> _restart(AudioPlayer player, String asset, double volume, int token, {double playbackRate = 1.0}) async {
    try {
      await player.stop();
    } catch (_) {}
    if (_playToken[player] != token) return;
    try {
      final targetRate = (playbackRate - 1.0).abs() > 0.02 ? playbackRate.clamp(0.5, 2.0) : 1.0;
      final currentRate = _playerRate[player] ?? 1.0;
      if (currentRate != targetRate) {
        _playerRate[player] = targetRate;
        await player.setPlaybackRate(targetRate);
      }
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



