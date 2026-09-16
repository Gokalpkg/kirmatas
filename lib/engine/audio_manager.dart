import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/services.dart';

enum GameSfx {
  hitPaddle,
  hitWall,
  hitBrick,
  breakBrick,
  steel,
  powerupBuff,
  powerupDebuff,
  laser,
  explosion,
  ulti,
  bubble,
  click,
  gameOver,
  victory,
}

class AudioManager {
  static final AudioManager instance = AudioManager._internal();
  AudioManager._internal();

  bool sfxEnabled = true;
  bool hapticsEnabled = true;
  double sfxVolume = 1.0;

  final AudioPlayer _sfxPlayer = AudioPlayer();
  final AudioPlayer _laserPlayer = AudioPlayer();
  final AudioPlayer _breakPlayer = AudioPlayer();

  Future<void> init() async {
    await _sfxPlayer.setReleaseMode(ReleaseMode.stop);
    await _laserPlayer.setReleaseMode(ReleaseMode.stop);
    await _breakPlayer.setReleaseMode(ReleaseMode.stop);
  }

  Future<void> playSfx(GameSfx sfx) async {
    if (!sfxEnabled) return;

    String assetName;
    switch (sfx) {
      case GameSfx.hitPaddle:
        assetName = 'click1.mp3';
        triggerHaptic(HapticFeedback.lightImpact);
        break;
      case GameSfx.hitWall:
        assetName = 'crystal_tap.mp3';
        triggerHaptic(HapticFeedback.lightImpact);
        break;
      case GameSfx.hitBrick:
        assetName = 'chip1.mp3';
        triggerHaptic(HapticFeedback.lightImpact);
        break;
      case GameSfx.breakBrick:
        assetName = 'crystal_block.mp3';
        triggerHaptic(HapticFeedback.mediumImpact);
        _breakPlayer.play(AssetSource('audio/$assetName'), volume: sfxVolume);
        return;
      case GameSfx.steel:
        assetName = 'ui_c3.mp3';
        triggerHaptic(HapticFeedback.mediumImpact);
        break;
      case GameSfx.powerupBuff:
        assetName = 'ui1.mp3';
        triggerHaptic(HapticFeedback.mediumImpact);
        break;
      case GameSfx.powerupDebuff:
        assetName = 'ui_b4.mp3';
        triggerHaptic(HapticFeedback.mediumImpact);
        break;
      case GameSfx.laser:
        assetName = 'glass_neon1.mp3';
        _laserPlayer.play(AssetSource('audio/$assetName'), volume: sfxVolume * 0.75);
        return;
      case GameSfx.explosion:
        assetName = 'digital_explo1.mp3';
        triggerHaptic(HapticFeedback.heavyImpact);
        break;
      case GameSfx.ulti:
        assetName = 'y2k_digital1.mp3';
        triggerHaptic(HapticFeedback.heavyImpact);
        break;
      case GameSfx.bubble:
        assetName = 'bubble2.mp3';
        break;
      case GameSfx.click:
        assetName = 'ui4.mp3';
        triggerHaptic(HapticFeedback.selectionClick);
        break;
      case GameSfx.gameOver:
        assetName = 'ui_a4.mp3';
        triggerHaptic(HapticFeedback.vibrate);
        break;
      case GameSfx.victory:
        assetName = 'ui_fx1.mp3';
        triggerHaptic(HapticFeedback.heavyImpact);
        break;
    }

    try {
      await _sfxPlayer.play(AssetSource('audio/$assetName'), volume: sfxVolume);
    } catch (_) {}
  }

  void triggerHaptic(Future<void> Function() hapticFunc) {
    if (hapticsEnabled) {
      hapticFunc();
    }
  }

  void dispose() {
    _sfxPlayer.dispose();
    _laserPlayer.dispose();
    _breakPlayer.dispose();
  }
}
