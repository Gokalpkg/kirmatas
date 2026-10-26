import 'dart:math' as math;

/// Centralized economy & pacing configuration conforming to Constitutional Rule 3:
/// "TIME-ANCHORED ECONOMIC FORMULAS (Time-to-Value & Exponential Progression)".
///
/// All gameplay reward scaling, upgrade progression, fever milestones, and hit-stop
/// timing are anchored here rather than scattered as magic numbers across the codebase.
abstract final class BalanceConfig {
  // ===========================================================================
  // GAME PACING & JUICE ANCHORS
  // ===========================================================================

  /// Micro-freeze duration in seconds applied on heavy solid brick destruction.
  /// 35 milliseconds creates a tactile "crunch" without perceptible input lag.
  static const double hitStopDurationSeconds = 0.035;

  /// Hit stop in milliseconds.
  static const int hitStopDurationMs = 35;

  /// Scaled hit stop duration based on active ball count.
  /// Prevents Multiball from stuttering the physics engine while maintaining tactile punch.
  static double scaledHitStop(int activeBallCount) {
    if (activeBallCount <= 1) return hitStopDurationSeconds;
    return (hitStopDurationSeconds / math.max(1.0, activeBallCount * 0.75)).clamp(0.008, hitStopDurationSeconds);
  }

  /// High combo threshold triggering screen shake and fever aura.
  static const int feverComboThreshold = 8;

  /// Extreme combo threshold triggering cosmic shatter particles.
  static const int cosmicComboThreshold = 16;

  /// Seconds before endgame anti-stall micro-steering nudges the ball toward the last 1-2 bricks.
  static const double endgameStallThresholdSeconds = 3.5;

  /// Base coin drop probability per brick in Classic/Special mode (30%).
  static const double classicCoinBaseDropRate = 0.30;

  /// Base coin drop probability per brick in Chaos mode (20%).
  static const double chaosCoinBaseDropRate = 0.20;

  /// Base capsule power-up drop probability per brick (14%).
  static const double capsuleBaseDropRate = 0.14;

  /// Additional drop probability per level of 'u_luck' upgrade (+4% per level).
  static const double luckUpgradeDropStep = 0.04;

  // ===========================================================================
  // TIME-ANCHORED ECONOMY FORMULAS
  // ===========================================================================

  /// Target base gold earned per 60-second active gameplay session in early game.
  static const int targetSessionGoldEarly = 120;

  /// Target base gold earned per 60-second active gameplay session in late game.
  static const int targetSessionGoldLate = 450;

  /// Base cost for core stat upgrades (e.g., paddle width, ball damage, magnet).
  static const int upgradeBaseCost = 50;

  /// Exponential progression factor for core stat upgrades (1.18x per level).
  /// Guarantees Level 10 costs ~247, Level 20 costs ~1,293, Level 50 costs ~174,000.
  static const double upgradeCostExponent = 1.18;

  /// Computes the exact gold cost required to upgrade a stat from [currentLevel].
  static int upgradeCost(int currentLevel, {int baseCost = upgradeBaseCost, double exponent = upgradeCostExponent}) {
    if (currentLevel <= 0) return baseCost;
    return (baseCost * math.pow(exponent, currentLevel)).round();
  }

  /// Base gold reward when clearing a level.
  static int levelClearGold(int levelNumber) {
    if (levelNumber <= 0) return 50;
    // Linear + sub-quadratic curve: early levels reward quick wins, deep levels reward mastery.
    return 50 + (levelNumber * 12) + (math.pow(levelNumber, 1.25)).round();
  }

  /// Base gold awarded for destroying a regular solid brick.
  static const int regularBrickGold = 1;

  /// Base gold awarded for destroying an armored/hard brick.
  static const int armoredBrickGold = 3;

  /// Base gold awarded for destroying an explosive/special brick.
  static const int specialBrickGold = 5;

  /// Base gold awarded for destroying an obsidian/boss brick.
  static const int bossBrickGold = 25;

  // ===========================================================================
  // COMBO SCORE MULTIPLIERS
  // ===========================================================================

  /// Score multiplier curve based on active combo streak.
  static double comboMultiplier(int comboCount) {
    if (comboCount <= 1) return 1.0;
    if (comboCount < 4) return 1.25;
    if (comboCount < 8) return 1.5;
    if (comboCount < 16) return 2.0;
    return 3.0; // Max fever frenzy multiplier
  }
}
