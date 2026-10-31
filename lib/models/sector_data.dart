import 'package:flutter/material.dart';

/// Klasik Mod bölüm serileri: 238 bölüm, 8'er bölümlük seriler hâlinde.
/// Her seri, ilk bölümünün ait olduğu temanın kimliğini taşır.
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

  /// The 14 world themes series inherit from (ascension from deep ocean abyss to earth, space, and the ultimate Kaunos Tapınağı).
  static const List<SectorData> _themes = [
    SectorData(
      sectorIndex: 1,
      startLevel: 1,
      endLevel: 16,
      nameTr: 'Karanlık Abis (Başlangıç)',
      nameEn: 'Dark Abyss (Genesis)',
      descriptionTr: 'Okyanusun en derin karanlığı. Refleksleri ısıt, temel taşları parçala ve yukarı tırmanışa başla.',
      descriptionEn: 'The deepest ocean trenches. Warm up your reflexes, crush the foundation bricks and begin your ascent.',
      icon: Icons.waves_rounded,
      primaryColor: Color(0xFF00B0FF),
      accentColor: Color(0xFF80D8FF),
      gradientColors: [Color(0xFF0077B6), Color(0xFF00B4D8)],
    ),
    SectorData(
      sectorIndex: 2,
      startLevel: 17,
      endLevel: 33,
      nameTr: 'Batık Resif',
      nameEn: 'Sunken Reef',
      descriptionTr: 'Biyolüminesans denizaltı mercanları, parıldayan sualtı taşları ve akıntı blokları.',
      descriptionEn: 'Bioluminescent coral beds, glowing underwater stones and current blocks.',
      icon: Icons.water_drop_rounded,
      primaryColor: Color(0xFF00E5FF),
      accentColor: Color(0xFF18FFFF),
      gradientColors: [Color(0xFF0097A7), Color(0xFF00E5FF)],
    ),
    SectorData(
      sectorIndex: 3,
      startLevel: 34,
      endLevel: 50,
      nameTr: 'Kristal Buzul',
      nameEn: 'Crystal Glacier',
      descriptionTr: 'Dondurucu kutup denizi, kaygan buz blokları ve keskin sekme açıları.',
      descriptionEn: 'Freezing polar ocean, slippery ice blocks and razor bounce angles.',
      icon: Icons.ac_unit_rounded,
      primaryColor: Color(0xFF80D8FF),
      accentColor: Color(0xFFE1F5FE),
      gradientColors: [Color(0xFF0288D1), Color(0xFF80D8FF)],
    ),
    SectorData(
      sectorIndex: 4,
      startLevel: 51,
      endLevel: 67,
      nameTr: 'Zümrüt Vadi',
      nameEn: 'Emerald Valley',
      descriptionTr: 'Denizden karaya ilk adım. Yemyeşil kıyılar, kadim taşlar ve serin yeryüzü rüzgarları.',
      descriptionEn: 'First step from sea to land. Lush green shores, ancient stones and earth breezes.',
      icon: Icons.park_rounded,
      primaryColor: Color(0xFF00E676),
      accentColor: Color(0xFFB9F6CA),
      gradientColors: [Color(0xFF00796B), Color(0xFF00E676)],
    ),
    SectorData(
      sectorIndex: 5,
      startLevel: 68,
      endLevel: 84,
      nameTr: 'Kadim Taş Kanyonu',
      nameEn: 'Ancient Stone Canyon',
      descriptionTr: 'Sert granit tabakalar, yüksek kanyon duvarları ve dar geçit açıları.',
      descriptionEn: 'Hard granite layers, towering canyon walls and narrow channel precision.',
      icon: Icons.terrain_rounded,
      primaryColor: Color(0xFFFFB300),
      accentColor: Color(0xFFFFE082),
      gradientColors: [Color(0xFFE65100), Color(0xFFFFB300)],
    ),
    SectorData(
      sectorIndex: 6,
      startLevel: 85,
      endLevel: 101,
      nameTr: 'Volkanik Magma',
      nameEn: 'Volcanic Magma',
      descriptionTr: 'Yerkabuğunun kaynayan zirvesi. Akkor lav blokları ve patlayıcı reaksiyonlar.',
      descriptionEn: 'Boiling continental apex. Incandescent lava blocks and explosive reactions.',
      icon: Icons.local_fire_department_rounded,
      primaryColor: Color(0xFFFF3D00),
      accentColor: Color(0xFFFF8A80),
      gradientColors: [Color(0xFFBF360C), Color(0xFFFF5722)],
    ),
    SectorData(
      sectorIndex: 7,
      startLevel: 102,
      endLevel: 118,
      nameTr: 'Fırtına Bulutları',
      nameEn: 'Storm Stratosphere',
      descriptionTr: 'Yeryüzünü geride bırakan fırtınalı gökyüzü, şimşek deşarjları ve Mach rüzgarları.',
      descriptionEn: 'Stormy skies leaving earth behind, lightning discharges and Mach winds.',
      icon: Icons.bolt_rounded,
      primaryColor: Color(0xFFFFD600),
      accentColor: Color(0xFFFFFF8D),
      gradientColors: [Color(0xFFFF6D00), Color(0xFFFFD600)],
    ),
    SectorData(
      sectorIndex: 8,
      startLevel: 119,
      endLevel: 135,
      nameTr: 'Yerçekimsiz Yörünge',
      nameEn: 'Orbital Zero-G',
      descriptionTr: 'Atmosferin bittiği sınır. Yerçekimsiz süzülen bloklar ve uzay boşluğuna açılan pencere.',
      descriptionEn: 'The edge of atmosphere. Floating zero-g bricks and the space frontier.',
      icon: Icons.satellite_alt_rounded,
      primaryColor: Color(0xFF00B0FF),
      accentColor: Color(0xFF80D8FF),
      gradientColors: [Color(0xFF0D47A1), Color(0xFF00B0FF)],
    ),
    SectorData(
      sectorIndex: 9,
      startLevel: 136,
      endLevel: 152,
      nameTr: 'Yıldız Tozu Kuşağı',
      nameEn: 'Stardust Belt',
      descriptionTr: 'Göktaşı yağmurları, parıldayan elmas tozları ve serbest meteorlar.',
      descriptionEn: 'Meteor showers, glittering diamond stardust and free asteroids.',
      icon: Icons.auto_awesome_rounded,
      primaryColor: Color(0xFFFFAB40),
      accentColor: Color(0xFFFFE57F),
      gradientColors: [Color(0xFFFF6F00), Color(0xFFFFD54F)],
    ),
    SectorData(
      sectorIndex: 10,
      startLevel: 153,
      endLevel: 169,
      nameTr: 'Kozmik Nebula',
      nameEn: 'Cosmic Nebula',
      descriptionTr: 'Yıldızlararası gaz bulutları, parlayan plazma ve bükülen uzay-zaman dalgaları.',
      descriptionEn: 'Interstellar gas nebulae, glowing plasma and bent space-time waves.',
      icon: Icons.grain_rounded,
      primaryColor: Color(0xFFE040FB),
      accentColor: Color(0xFFEA80FC),
      gradientColors: [Color(0xFF8E24AA), Color(0xFFE040FB)],
    ),
    SectorData(
      sectorIndex: 11,
      startLevel: 170,
      endLevel: 186,
      nameTr: 'Girdap Boşluğu',
      nameEn: 'Singularity Void',
      descriptionTr: 'Karanlık maddenin ve devasa yerçekimli karadeliklerin uzayı yuttuğu sınır.',
      descriptionEn: 'Massive gravitational black holes and dark matter swallowing space.',
      icon: Icons.cyclone_rounded,
      primaryColor: Color(0xFF7C4DFF),
      accentColor: Color(0xFFB388FF),
      gradientColors: [Color(0xFF311B92), Color(0xFF7C4DFF)],
    ),
    SectorData(
      sectorIndex: 12,
      startLevel: 187,
      endLevel: 203,
      nameTr: 'Kuantum Boyutu',
      nameEn: 'Beyond The Cosmos',
      descriptionTr: 'Fizik yasalarının çözüldüğü, bilinen uzayın ve evrenin bittiği hiper-uzay boyutu.',
      descriptionEn: 'Beyond all known space. Hyper-space dimensions where quantum laws rule.',
      icon: Icons.all_inclusive_rounded,
      primaryColor: Color(0xFF00E5FF),
      accentColor: Color(0xFF84FFFF),
      gradientColors: [Color(0xFF006064), Color(0xFF00E5FF)],
    ),
    SectorData(
      sectorIndex: 13,
      startLevel: 204,
      endLevel: 220,
      nameTr: 'Kaunos Kapısı',
      nameEn: 'Kaunos Gateway',
      descriptionTr: 'Uzayın da ötesinde beliren efsanevi kaya krallığının kutsal eşiği.',
      descriptionEn: 'Sacred threshold of the legendary rock kingdom beyond all cosmos.',
      icon: Icons.vpn_key_rounded,
      primaryColor: Color(0xFFFFB300),
      accentColor: Color(0xFFFFD54F),
      gradientColors: [Color(0xFFE65100), Color(0xFFFFB300)],
    ),
    SectorData(
      sectorIndex: 14,
      startLevel: 221,
      endLevel: 238,
      nameTr: 'Kaunos Tapınağı',
      nameEn: 'Kaunos Sanctum',
      descriptionTr: 'Uzayın ve boyutların ötesindeki nihai kadim kaya tapınağı. 238. Bölüm nihai zafer tahtı!',
      descriptionEn: 'The supreme ancient rock temple beyond space and dimensions. Level 238 ultimate throne!',
      icon: Icons.account_balance_rounded,
      primaryColor: Color(0xFFFF1744),
      accentColor: Color(0xFFFFD700),
      gradientColors: [Color(0xFFFF1744), Color(0xFFFFD700)],
    ),
  ];

  /// Levels per series: the campaign is grouped into runs of 8.
  static const int seriesSize = 8;
  static const int totalLevels = 238;

  /// All series in order. Series k covers (k-1)*8+1 .. min(k*8, 238)
  /// and inherits the theme (name root, colors, icon, description) of
  /// the legacy sector its first level belonged to, with a stage
  /// suffix (I, II, III). Level numbers never change, so saves and
  /// checkpoints keep working exactly as before.
  static final List<SectorData> allSectors = _buildSeries();

  static String _roman(int n) {
    const numerals = ['I', 'II', 'III', 'IV', 'V', 'VI'];
    return (n >= 1 && n <= numerals.length) ? numerals[n - 1] : '$n';
  }

  static SectorData _themeForLevel(int level) {
    for (final t in _themes) {
      if (level >= t.startLevel && level <= t.endLevel) return t;
    }
    return level > totalLevels ? _themes.last : _themes.first;
  }

  static List<SectorData> _buildSeries() {
    final out = <SectorData>[];
    final themeStage = <int, int>{};
    for (var start = 1; start <= totalLevels; start += seriesSize) {
      final theme = _themeForLevel(start);
      final stage = (themeStage[theme.sectorIndex] ?? 0) + 1;
      themeStage[theme.sectorIndex] = stage;
      final end = (start + seriesSize - 1 > totalLevels)
          ? totalLevels
          : start + seriesSize - 1;
      out.add(SectorData(
        sectorIndex: out.length + 1,
        startLevel: start,
        endLevel: end,
        nameTr: '${theme.nameTr} ${_roman(stage)}',
        nameEn: '${theme.nameEn} ${_roman(stage)}',
        descriptionTr: theme.descriptionTr,
        descriptionEn: theme.descriptionEn,
        icon: theme.icon,
        primaryColor: theme.primaryColor,
        accentColor: theme.accentColor,
        gradientColors: theme.gradientColors,
      ));
    }
    return out;
  }

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
