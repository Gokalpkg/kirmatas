import '../storage/save_manager.dart';

/// Passive buffs applied to the paddle and ball during gameplay,
/// calculated from the fish unlocked in the player's Eco-Tank.
class FishSynergyBuffs {
  final double extraPaddleWidth;
  final double critChanceBonus;
  final double goldMultiplier;
  final int startingLaserAmmoBonus;
  final bool hasOctopusClutchSave;
  final bool hasArowanaRicochet;
  final bool hasTetraSwarm;
  final bool hasDiscusBlast;
  final double foodDropBonus;
  final List<String> activeBuffDescriptions;

  const FishSynergyBuffs({
    required this.extraPaddleWidth,
    required this.critChanceBonus,
    required this.goldMultiplier,
    required this.startingLaserAmmoBonus,
    this.hasOctopusClutchSave = false,
    this.hasArowanaRicochet = false,
    this.hasTetraSwarm = false,
    this.hasDiscusBlast = false,
    this.foodDropBonus = 0.0,
    required this.activeBuffDescriptions,
  });

  /// Computes the active aquarium perks.
  /// Confusing micro-synergies (+3px paddle, +3% crit) are retired in favor of
  /// the Cozy Passive Gold Vault and the iconic Octopus Clutch Save.
  static FishSynergyBuffs calculate(SaveManager save) {
    final descs = <String>[];

    // Sadece Ahtapot için özel yetenek: Günde 1 kez son canda vantuz kurtarışı
    final hasOctopus = save.canUseDailyOctopusClutch;
    if (save.hasOctopus) {
      if (save.canUseDailyOctopusClutch) {
        descs.add('Ahtapot Vantuz Kurtarışı (1/1 Günlük - Hazır)');
      } else {
        descs.add('Ahtapot Vantuz Kurtarışı (Bugün Kullanıldı)');
      }
    }

    if (save.unlockedFish.isNotEmpty) {
      descs.add('Pasif Altın Fabrikası (${save.unlockedFish.length} Balık Üretimde)');
    }

    return FishSynergyBuffs(
      extraPaddleWidth: 0.0,
      critChanceBonus: 0.0,
      goldMultiplier: 1.0,
      startingLaserAmmoBonus: 0,
      hasOctopusClutchSave: hasOctopus,
      hasArowanaRicochet: false,
      hasTetraSwarm: false,
      hasDiscusBlast: false,
      foodDropBonus: 0.0,
      activeBuffDescriptions: descs,
    );
  }
}
