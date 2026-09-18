import 'package:flutter/services.dart';
import '../models/game_state.dart';
import '../storage/save_manager.dart';

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

  bool sfxEnabled = false;
  bool get hapticsEnabled => SaveManager.instance.hapticsEnabled;
  HapticIntensity get hapticIntensity => SaveManager.instance.hapticIntensity;

  Future<void> init() async {}

  Future<void> playSfx(GameSfx sfx) async {
    final intensity = hapticIntensity;
    if (intensity == HapticIntensity.off) return;

    switch (sfx) {
      case GameSfx.hitPaddle:
      case GameSfx.hitWall:
      case GameSfx.hitBrick:
        if (intensity == HapticIntensity.light) {
          HapticFeedback.lightImpact();
        } else if (intensity == HapticIntensity.medium) {
          HapticFeedback.mediumImpact();
        } else {
          HapticFeedback.heavyImpact();
        }
        break;

      case GameSfx.breakBrick:
      case GameSfx.steel:
      case GameSfx.powerupBuff:
      case GameSfx.powerupDebuff:
      case GameSfx.laser:
        if (intensity == HapticIntensity.light) {
          HapticFeedback.lightImpact();
        } else if (intensity == HapticIntensity.medium) {
          HapticFeedback.mediumImpact();
        } else {
          HapticFeedback.heavyImpact();
          HapticFeedback.vibrate();
        }
        break;

      case GameSfx.explosion:
      case GameSfx.ulti:
      case GameSfx.gameOver:
      case GameSfx.victory:
        if (intensity == HapticIntensity.light) {
          HapticFeedback.mediumImpact();
        } else if (intensity == HapticIntensity.medium) {
          HapticFeedback.heavyImpact();
        } else {
          HapticFeedback.vibrate();
          HapticFeedback.heavyImpact();
        }
        break;

      case GameSfx.click:
        if (intensity == HapticIntensity.light) {
          HapticFeedback.selectionClick();
        } else if (intensity == HapticIntensity.medium) {
          HapticFeedback.lightImpact();
        } else {
          HapticFeedback.mediumImpact();
        }
        break;

      case GameSfx.bubble:
        break;
    }
  }

  void triggerTestHaptic(HapticIntensity intensity) {
    switch (intensity) {
      case HapticIntensity.off:
        break;
      case HapticIntensity.light:
        HapticFeedback.lightImpact();
        break;
      case HapticIntensity.medium:
        HapticFeedback.mediumImpact();
        break;
      case HapticIntensity.strong:
        HapticFeedback.vibrate();
        HapticFeedback.heavyImpact();
        break;
    }
  }

  void triggerHaptic(Future<void> Function() hapticFunc) {
    if (hapticsEnabled) {
      hapticFunc();
    }
  }

  void dispose() {}
}

