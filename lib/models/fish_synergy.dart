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
  /// Tok balıklar %100 buff sağlarken, aç balıklar %50 (yarıya düşürülmüş) buff verir.
  static FishSynergyBuffs calculate(SaveManager save) {
    double width = 0.0;
    double crit = 0.0;
    double goldMult = 1.0;
    int laserAmmo = 0;
    final descs = <String>[];

    final unlocked = save.unlockedFish;

    // Tokluk faktörü: Balık tokken (satiety cooldown içinde) %100, açken %50 buff
    double factor(String id) => save.isFishInSatietyCooldown(id) ? 1.0 : 0.5;

    // 1. Guppy & Neon Diskus: Paddle Extension
    double paddleBonus = 0.0;
    if (unlocked.contains('guppy')) paddleBonus += 4.0 * factor('guppy');
    if (unlocked.contains('guppy_blue')) paddleBonus += 3.0 * factor('guppy_blue');
    if (unlocked.contains('guppy_green')) paddleBonus += 3.0 * factor('guppy_green');
    if (unlocked.contains('tetra')) paddleBonus += 3.0 * factor('tetra');
    if (unlocked.contains('tetra_gold')) paddleBonus += 3.0 * factor('tetra_gold');
    if (unlocked.contains('tetra_purple')) paddleBonus += 3.0 * factor('tetra_purple');
    if (paddleBonus > 0) {
      width = paddleBonus;
      final display = paddleBonus.toStringAsFixed(paddleBonus.truncateToDouble() == paddleBonus ? 0 : 1);
      descs.add('+$display px Raket Boyutu');
    }

    // 2. Angelfish: Critical Strike Mastery
    double critBonus = 0.0;
    if (unlocked.contains('angel')) critBonus += 0.03 * factor('angel');
    if (unlocked.contains('angel_aqua')) critBonus += 0.04 * factor('angel_aqua');
    if (unlocked.contains('angel_ruby')) critBonus += 0.05 * factor('angel_ruby');
    if (critBonus > 0) {
      crit = critBonus;
      final display = (crit * 100).toStringAsFixed((crit * 100).truncateToDouble() == (crit * 100) ? 0 : 1);
      descs.add('+$display% Kritik Vuruş Şansı');
    }

    // 3. Betta & Royal Betta: Tactical Laser Charges
    double ammoPoints = 0.0;
    final bettaGroup = ['betta', 'betta_blue', 'betta_orange'].where(unlocked.contains).toList();
    if (bettaGroup.isNotEmpty) {
      ammoPoints += bettaGroup.any((id) => save.isFishInSatietyCooldown(id)) ? 1.0 : 0.5;
    }
    final discusGroup = ['discus', 'discus_blue', 'discus_green'].where(unlocked.contains).toList();
    if (discusGroup.isNotEmpty) {
      ammoPoints += discusGroup.any((id) => save.isFishInSatietyCooldown(id)) ? 1.0 : 0.5;
    }
    laserAmmo = ammoPoints.round();
    if (laserAmmo > 0) {
      descs.add('+$laserAmmo Ekstra Lazer Cephanesi');
    }

    // 4. Dragon Arowana: Imperial Wealth (Gold Multiplier)
    double extraGold = 0.0;
    if (unlocked.contains('arowana')) extraGold += 0.10 * factor('arowana');
    if (unlocked.contains('arowana_red')) extraGold += 0.15 * factor('arowana_red');
    if (unlocked.contains('arowana_silver')) extraGold += 0.20 * factor('arowana_silver');
    if (extraGold > 0) {
      goldMult += extraGold;
      final display = (extraGold * 100).toStringAsFixed((extraGold * 100).truncateToDouble() == (extraGold * 100) ? 0 : 1);
      descs.add('+$display% Seviye Altını');
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
