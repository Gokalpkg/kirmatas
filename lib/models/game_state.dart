import '../engine/i18n.dart';

enum GameMode {
  classic,
  zen,
  descend,
  daily,
  tuft;

  String get displayName => I18n.tr(name);
  String get description => I18n.tr('${name}_desc');
}

enum GameStatus {
  ready,
  playing,
  paused,
  gameOver,
  victory,
}

enum SpeedSetting {
  slow(1.05),
  medium(1.48),
  fast(2.05);

  final double multiplier;
  const SpeedSetting(this.multiplier);

  String get label => I18n.tr(name);
}

class MatchStats {
  int score = 0;
  int lives = 3;
  int maxLives = 3;
  int level = 1;
  int combo = 0;
  int maxCombo = 0;
  int bricksBroken = 0;
  int goldCollected = 0;
  double ultiCharge = 0.0; // 0.0 to 100.0
  bool isFever = false;
  double feverTimeLeft = 0.0;
  double bulletTimeLeft = 0.0;
  double ultiActiveLeft = 0.0;

  void reset({int initialLives = 3, int startLevel = 1}) {
    score = 0;
    lives = initialLives;
    maxLives = initialLives;
    level = startLevel;
    combo = 0;
    maxCombo = 0;
    bricksBroken = 0;
    goldCollected = 0;
    ultiCharge = 0.0;
    isFever = false;
    feverTimeLeft = 0.0;
    bulletTimeLeft = 0.0;
    ultiActiveLeft = 0.0;
  }
}

enum HapticIntensity {
  off,
  light,
  medium,
  strong;

  String get label => I18n.tr('haptic_$name');
}

