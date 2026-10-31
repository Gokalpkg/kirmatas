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

  /// Base coin drop probability per brick in Classic/Special mode (7%).
  static const double classicCoinBaseDropRate = 0.07;

  /// Base coin drop probability per brick in Chaos mode (4.5%).
  static const double chaosCoinBaseDropRate = 0.045;

  /// Base capsule power-up drop probability per brick (14%).
  static const double capsuleBaseDropRate = 0.14;

  /// Additional drop probability per level of 'u_luck' upgrade (+4% per level).
  static const double luckUpgradeDropStep = 0.04;

  // ===========================================================================
  // TIME-ANCHORED ECONOMY FORMULAS
  // ===========================================================================

  /// Target base gold earned per 60-second active gameplay session in early game.
  static const int targetSessionGoldEarly = 75;

  /// Target base gold earned per 60-second active gameplay session in late game.
  static const int targetSessionGoldLate = 280;

  /// Base cost for core stat upgrades (e.g., paddle width, ball damage, magnet).
  static const int upgradeBaseCost = 100;

  /// Sub-polynomial progression factor kept for backward compatibility reference.
  static const double upgradeCostExponent = 1.18;

  /// Computes the exact gold cost required to upgrade a stat from [currentLevel]
  /// using the sub-polynomial balanced formula:
  /// `upgradeCost(L) = (100 * (1 + 0.20 * L + 0.03 * math.pow(L, 1.85))).round()`
  ///
  /// Prevents exponential walls while maintaining satisfying progression across all levels.
  static int upgradeCost(int currentLevel, {int baseCost = upgradeBaseCost, double? exponent}) {
    if (currentLevel <= 0) return baseCost;
    return (baseCost * (1.0 + 0.20 * currentLevel + 0.03 * math.pow(currentLevel, 1.85))).round();
  }

  /// Base gold reward when clearing a level.
  static int levelClearGold(int levelNumber) {
    if (levelNumber <= 0) return 30;
    // Sıkılaştırılmış ve hak edilmiş ödül eğrisi:
    return 30 + (levelNumber * 7) + (math.pow(levelNumber, 1.15)).round();
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

  // ===========================================================================
  // INTEREST VAULT & COMBO GOLD MULTIPLIERS
  // ===========================================================================

  /// Computes interest earnings from the Interest Vault based on [currentGold].
  /// +15 gold for every 250 gold held, capped at a maximum of +120 gold per level clear.
  static int calculateInterest(int currentGold) {
    if (currentGold <= 0) return 0;
    final interest = (currentGold ~/ 250) * 15;
    return interest.clamp(0, 120);
  }

  /// Combo gold multiplier curve applied to coin drops from destroyed bricks:
  /// combo < 5: 1.0x, combo < 10: 1.5x, combo < 20: 2.0x, combo >= 20: 3.0x (Fever).
  static double comboGoldMultiplier(int comboCount) {
    if (comboCount < 5) return 1.0;
    if (comboCount < 10) return 1.5;
    if (comboCount < 20) return 2.0;
    return 3.0;
  }

  // ===========================================================================
  // OVERDRIVE EDGE RISK, GOLD PIÑATA & SPEED-PAR ANCHORS
  // ===========================================================================

  /// Outer paddle edge threshold (85%) triggering Overdrive risk-reward streak.
  static const double overdriveEdgeThreshold = 0.85;

  /// Speed boost per Overdrive streak tier (+15% per tier).
  static const double overdriveSpeedStep = 0.15;

  /// Maximum Overdrive streak tier (Tier 3 unlocks piercing gold bullet).
  static const int overdriveMaxStreak = 3;

  /// Target par duration in seconds for flawless speed-clear bonus.
  static const double speedParDurationSeconds = 25.0;

  /// Bonus gold awarded when clearing a level within [speedParDurationSeconds] without losing a life.
  static const int speedParBonusGold = 100;

  /// Gold orbs dropped per hit on a Gold Piñata brick.
  static const int goldPinataHitGold = 3;

  /// Bonus gold burst when shattering a Gold Piñata brick.
  static const int goldPinataDestroyGold = 60;

  /// Bonus pearls awarded when shattering a Gold Piñata brick.
  static const int goldPinataDestroyPearls = 1;
}

