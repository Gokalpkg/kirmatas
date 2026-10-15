import 'package:flutter/material.dart';

/// 238 bölümlük Klasik Mod için 17'şer bölümlük 14 Checkpoint Sektörü
class SectorData {
  final int sectorIndex; // 1..14
  final int startLevel;
  final int endLevel;
  final String nameTr;
  final String nameEn;
  final String descriptionTr;
  final String descriptionEn;
  final IconData icon;
  final Color primaryColor;
  final Color accentColor;
  final List<Color> gradientColors;

  const SectorData({
    required this.sectorIndex,
    required this.startLevel,
    required this.endLevel,
    required this.nameTr,
    required this.nameEn,
    required this.descriptionTr,
    required this.descriptionEn,
    required this.icon,
    required this.primaryColor,
    required this.accentColor,
    required this.gradientColors,
  });

  /// Bu sektörün başlangıç checkpoint seviyesi
  /// Sektör 1 -> 1, Sektör 2 -> 17, Sektör 3 -> 34, ...
  int get checkpointLevel => startLevel;

  /// Bu sektörün kilidi açılmış mı?
  bool isUnlocked(int highestLevel) {
    if (sectorIndex == 1) return true;
    return highestLevel >= startLevel;
  }

  /// Bu sektör tamamen tamamlanmış mı?
  bool isCompleted(int highestLevel) {
    return highestLevel > endLevel;
  }

  /// Oyuncu şu an bu sektörün içinde mi oynuyor?
  bool isCurrent(int currentOrHighestLevel) {
    return currentOrHighestLevel >= startLevel && currentOrHighestLevel <= endLevel;
  }

  String getName(String lang) => lang == 'en' ? nameEn : nameTr;
  String getDescription(String lang) => lang == 'en' ? descriptionEn : descriptionTr;

  static const List<SectorData> allSectors = [
    SectorData(
      sectorIndex: 1,
      startLevel: 1,
      endLevel: 16,
      nameTr: 'Başlangıç Vadisi',
      nameEn: 'Genesis Valley',
      descriptionTr: 'Refleksleri ısıt, temel taşları parçala ve ilk ivmeyi yakala.',
      descriptionEn: 'Warm up your reflexes, crush the foundation bricks and build momentum.',
      icon: Icons.explore_rounded,
      primaryColor: Color(0xFF00E676),
      accentColor: Color(0xFF69F0AE),
      gradientColors: [Color(0xFF00B0FF), Color(0xFF00E676)],
    ),
    SectorData(
      sectorIndex: 2,
      startLevel: 17,
      endLevel: 33,
      nameTr: 'Kristal Buzul',
      nameEn: 'Crystal Glacier',
      descriptionTr: 'Dondurucu buz blokları ve kaygan sekme açıları.',
      descriptionEn: 'Freezing ice blocks and slippery bounce angles.',
      icon: Icons.ac_unit_rounded,
      primaryColor: Color(0xFF00E5FF),
      accentColor: Color(0xFF80D8FF),
      gradientColors: [Color(0xFF0091EA), Color(0xFF00E5FF)],
    ),
    SectorData(
      sectorIndex: 3,
      startLevel: 34,
      endLevel: 50,
      nameTr: 'Alev Çekirdeği',
      nameEn: 'Inferno Core',
      descriptionTr: 'Supersonik köşe vuruşları ve akkor çelik bloklar.',
      descriptionEn: 'Supersonic corner boosts and incandescent steel bricks.',
      icon: Icons.local_fire_department_rounded,
      primaryColor: Color(0xFFFF5722),
      accentColor: Color(0xFFFFAB40),
      gradientColors: [Color(0xFFD50000), Color(0xFFFF9100)],
    ),
    SectorData(
      sectorIndex: 4,
      startLevel: 51,
      endLevel: 67,
      nameTr: 'Kozmik Portal',
      nameEn: 'Cosmic Gateway',
      descriptionTr: 'Uzay-zaman portalları arasında teleport olan toplar.',
      descriptionEn: 'Balls teleporting through deep space-time rifts.',
      icon: Icons.all_inclusive_rounded,
      primaryColor: Color(0xFFD500F9),
      accentColor: Color(0xFFEA80FC),
      gradientColors: [Color(0xFF651FFF), Color(0xFFD500F9)],
    ),
    SectorData(
      sectorIndex: 5,
      startLevel: 68,
      endLevel: 84,
      nameTr: 'Girdap Boşluğu',
      nameEn: 'Vortex Abyss',
      descriptionTr: 'Yörüngeleri büken devasa yerçekimli karadelikler.',
      descriptionEn: 'Massive gravitational black holes bending trajectories.',
      icon: Icons.cyclone_rounded,
      primaryColor: Color(0xFF7C4DFF),
      accentColor: Color(0xFFB388FF),
      gradientColors: [Color(0xFF304FFE), Color(0xFF7C4DFF)],
    ),
    SectorData(
      sectorIndex: 6,
      startLevel: 85,
      endLevel: 101,
      nameTr: 'Siber Şehir',
      nameEn: 'Cyber Matrix',
      descriptionTr: 'Yüksek frekanslı devre desenleri ve lazer hızlanmaları.',
      descriptionEn: 'High frequency circuits and laser acceleration matrices.',
      icon: Icons.memory_rounded,
      primaryColor: Color(0xFFFF007F),
      accentColor: Color(0xFFFF4081),
      gradientColors: [Color(0xFFC51162), Color(0xFFFF007F)],
    ),
    SectorData(
      sectorIndex: 7,
      startLevel: 102,
      endLevel: 118,
      nameTr: 'Zümrüt Labirent',
      nameEn: 'Emerald Labyrinth',
      descriptionTr: 'Çok katmanlı zırhlı tuğlalar ve dar geçit açıları.',
      descriptionEn: 'Multi-layer armored bricks and narrow channel precision.',
      icon: Icons.grid_view_rounded,
      primaryColor: Color(0xFF00C853),
      accentColor: Color(0xFFB9F6CA),
      gradientColors: [Color(0xFF00796B), Color(0xFF00E676)],
    ),
    SectorData(
      sectorIndex: 8,
      startLevel: 119,
      endLevel: 135,
      nameTr: 'Volkanik Magma',
      nameEn: 'Volcanic Magma',
      descriptionTr: 'Eriyen zırhlar, patlayan blok zincirleri ve lav akıntıları.',
      descriptionEn: 'Melting armor, explosive chain reactions and lava flows.',
      icon: Icons.whatshot_rounded,
      primaryColor: Color(0xFFFF3D00),
      accentColor: Color(0xFFFF6E40),
      gradientColors: [Color(0xFFBF360C), Color(0xFFFF3D00)],
    ),
    SectorData(
      sectorIndex: 9,
      startLevel: 136,
      endLevel: 152,
      nameTr: 'Supersonik Hız',
      nameEn: 'Supersonic Mach',
      descriptionTr: 'Ses duvarını aşan Mach elmasları ve şok dalgaları.',
      descriptionEn: 'Mach shock diamonds breaking the sound barrier.',
      icon: Icons.speed_rounded,
      primaryColor: Color(0xFFFFD600),
      accentColor: Color(0xFFFFFF00),
      gradientColors: [Color(0xFFFF6D00), Color(0xFFFFD600)],
    ),
    SectorData(
      sectorIndex: 10,
      startLevel: 153,
      endLevel: 169,
      nameTr: 'Plazma Fırtınası',
      nameEn: 'Plasma Storm',
      descriptionTr: 'Yüksek voltajlı kıvılcımlar ve elektrik yüklü raket darbeleri.',
      descriptionEn: 'High voltage sparks and electrified paddle discharges.',
      icon: Icons.flash_on_rounded,
      primaryColor: Color(0xFF00B0FF),
      accentColor: Color(0xFF80D8FF),
      gradientColors: [Color(0xFF2979FF), Color(0xFF00E5FF)],
    ),
    SectorData(
      sectorIndex: 11,
      startLevel: 170,
      endLevel: 186,
      nameTr: 'Kuantum Çöküşü',
      nameEn: 'Quantum Collapse',
      descriptionTr: 'Belirsizlik alanı, hayalet raket geçişleri ve çift yarıklar.',
      descriptionEn: 'Uncertainty fields, ghost paddle gaps and split trajectories.',
      icon: Icons.grain_rounded,
      primaryColor: Color(0xFFAA00FF),
      accentColor: Color(0xFFE040FB),
      gradientColors: [Color(0xFF4A148C), Color(0xFFAA00FF)],
    ),
    SectorData(
      sectorIndex: 12,
      startLevel: 187,
      endLevel: 203,
      nameTr: 'Antimadde Rezonansı',
      nameEn: 'Antimatter Nexus',
      descriptionTr: 'Maddenin anti-maddeye dönüştüğü yıkıcı temas rezonansı.',
      descriptionEn: 'Destructive contact resonance where matter turns to void.',
      icon: Icons.blur_on_rounded,
      primaryColor: Color(0xFF00E676),
      accentColor: Color(0xFF1DE9B6),
      gradientColors: [Color(0xFF00BFA5), Color(0xFF64FFDA)],
    ),
    SectorData(
      sectorIndex: 13,
      startLevel: 204,
      endLevel: 220,
      nameTr: 'Kaunos Tapınağı',
      nameEn: 'Kaunos Sanctum',
      descriptionTr: 'Kadim kaya blokları ve efsanevi kaya tapınağının muhafızları.',
      descriptionEn: 'Ancient monolith bricks and guardians of the rock temple.',
      icon: Icons.account_balance_rounded,
      primaryColor: Color(0xFFFFB300),
      accentColor: Color(0xFFFFE082),
      gradientColors: [Color(0xFFFF6F00), Color(0xFFFFD54F)],
    ),
    SectorData(
      sectorIndex: 14,
      startLevel: 221,
      endLevel: 238,
      nameTr: 'Son Zirve (Apex Zenith)',
      nameEn: 'Apex Zenith',
      descriptionTr: '238. Bölüm nihai zafer kapısı. Efsanelerin tahtı.',
      descriptionEn: 'Level 238 ultimate victory gate. The throne of legends.',
      icon: Icons.military_tech_rounded,
      primaryColor: Color(0xFFFF1744),
      accentColor: Color(0xFFFF80AB),
      gradientColors: [Color(0xFFFF1744), Color(0xFFFFD700)],
    ),
  ];

  /// Belirli bir bölüme denk gelen sektörü getirir
  static SectorData getSectorForLevel(int level) {
    for (final s in allSectors) {
      if (level >= s.startLevel && level <= s.endLevel) {
        return s;
      }
    }
    return level > 238 ? allSectors.last : allSectors.first;
  }
}
