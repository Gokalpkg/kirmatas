import '../storage/save_manager.dart';

/// Passive buffs applied to the paddle and ball during gameplay,
/// calculated from the fish unlocked in the player's Eco-Tank.
class FishSynergyBuffs {
  final double extraPaddleWidth;
  final double critChanceBonus;
  final double goldMultiplier;
  final int startingLaserAmmoBonus;
  final List<String> activeBuffDescriptions;

  const FishSynergyBuffs({
    required this.extraPaddleWidth,
    required this.critChanceBonus,
    required this.goldMultiplier,
    required this.startingLaserAmmoBonus,
    required this.activeBuffDescriptions,
  });

  /// Computes the accumulated synergies from all unlocked fish.
  static FishSynergyBuffs calculate(SaveManager save) {
    double width = 0.0;
    double crit = 0.0;
    double goldMult = 1.0;
    int laserAmmo = 0;
    final descs = <String>[];

    final unlocked = save.unlockedFish;

    // 1. Guppy & Neon Diskus: Paddle Extension
    double paddleBonus = 0.0;
    if (unlocked.contains('guppy')) paddleBonus += 4.0;
    if (unlocked.contains('guppy_blue')) paddleBonus += 3.0;
    if (unlocked.contains('guppy_green')) paddleBonus += 3.0;
    if (unlocked.contains('tetra')) paddleBonus += 3.0;
    if (unlocked.contains('tetra_gold')) paddleBonus += 3.0;
    if (unlocked.contains('tetra_purple')) paddleBonus += 3.0;
    if (paddleBonus > 0) {
      width = paddleBonus;
      descs.add('+${paddleBonus.round()} px Raket Boyutu');
    }

    // 2. Angelfish: Critical Strike Mastery
    double critBonus = 0.0;
    if (unlocked.contains('angel')) critBonus += 0.03;
    if (unlocked.contains('angel_aqua')) critBonus += 0.04;
    if (unlocked.contains('angel_ruby')) critBonus += 0.05;
    if (critBonus > 0) {
      crit = critBonus;
      descs.add('+${(crit * 100).round()}% Kritik Vuruş Şansı');
    }

    // 3. Betta & Royal Betta: Tactical Laser Charges
    int ammoBonus = 0;
    if (unlocked.contains('betta') || unlocked.contains('betta_blue') || unlocked.contains('betta_orange')) {
      ammoBonus += 1;
    }
    if (unlocked.contains('discus') || unlocked.contains('discus_blue') || unlocked.contains('discus_green')) {
      ammoBonus += 1;
    }
    if (ammoBonus > 0) {
      laserAmmo = ammoBonus;
      descs.add('+$laserAmmo Ekstra Lazer Cephanesi');
    }

    // 4. Dragon Arowana: Imperial Wealth (Gold Multiplier)
    double extraGold = 0.0;
    if (unlocked.contains('arowana')) extraGold += 0.10;
    if (unlocked.contains('arowana_red')) extraGold += 0.15;
    if (unlocked.contains('arowana_silver')) extraGold += 0.20;
    if (extraGold > 0) {
      goldMult += extraGold;
      descs.add('+${(extraGold * 100).round()}% Seviye Altını');
    }

    return FishSynergyBuffs(
      extraPaddleWidth: width,
      critChanceBonus: crit,
      goldMultiplier: goldMult,
      startingLaserAmmoBonus: laserAmmo,
      activeBuffDescriptions: descs,
    );
  }
}
