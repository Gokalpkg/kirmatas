import 'package:flutter/material.dart';
import '../engine/i18n.dart';

enum Rarity {
  common(Color(0xFF90A4AE), Color(0xFF37474F)),
  rare(Color(0xFF40C4FF), Color(0xFF0277BD)),
  epic(Color(0xFFE040FB), Color(0xFF7B1FA2)),
  legendary(Color(0xFFFFD54F), Color(0xFFFF8F00));

  final Color primaryColor;
  final Color darkColor;
  const Rarity(this.primaryColor, this.darkColor);

  String get label => I18n.tr(name);
}

class BallSkin {
  final String id;
  final String? _name;
  final int cost;
  final Rarity rarity;
  final Color mainColor;
  final Color glowColor;
  final Color darkColor;
  final bool hasAura;

  const BallSkin({
    required this.id,
    String? name,
    required this.cost,
    required this.rarity,
    required this.mainColor,
    required this.glowColor,
    required this.darkColor,
    this.hasAura = false,
  }) : _name = name;

  String get name => _name != null ? I18n.tr(id) : I18n.tr(id);

  static const List<BallSkin> allSkins = [
    BallSkin(
      id: 'classic',
      name: 'Klasik Beyaz',
      cost: 0,
      rarity: Rarity.common,
      mainColor: Colors.white,
      glowColor: Color(0xCCFFFFFF),
      darkColor: Color(0xFF90A4AE),
    ),
    BallSkin(
      id: 'pembe',
      name: 'Neon Pembe',
      cost: 1500,
      rarity: Rarity.rare,
      mainColor: Color(0xFFFF7EB3),
      glowColor: Color(0xFFAA147B),
      darkColor: Color(0xFFAD1457),
      hasAura: true,
    ),
    BallSkin(
      id: 'plazma',
      name: 'Plazma Mavi',
      cost: 1800,
      rarity: Rarity.rare,
      mainColor: Color(0xFF40C4FF),
      glowColor: Color(0xE640C4FF),
      darkColor: Color(0xFF01579B),
      hasAura: true,
    ),
    BallSkin(
      id: 'zumrut',
      name: 'Zümrüt Yeşil',
      cost: 2000,
      rarity: Rarity.rare,
      mainColor: Color(0xFF69F0AE),
      glowColor: Color(0xE669F0AE),
      darkColor: Color(0xFF1B5E20),
    ),
    BallSkin(
      id: 'golge',
      name: 'Gölge Mor',
      cost: 2400,
      rarity: Rarity.epic,
      mainColor: Color(0xFFB388FF),
      glowColor: Color(0xE6B388FF),
      darkColor: Color(0xFF311B92),
    ),
    BallSkin(
      id: 'ates',
      name: 'Ateş Topu',
      cost: 2800,
      rarity: Rarity.epic,
      mainColor: Color(0xFFFF6D00),
      glowColor: Color(0xE6FF6D00),
      darkColor: Color(0xFFBF360C),
      hasAura: true,
    ),
    BallSkin(
      id: 'isilti',
      name: 'Yıldız Işıltısı',
      cost: 3200,
      rarity: Rarity.legendary,
      mainColor: Color(0xFFFFD54F),
      glowColor: Color(0xE6FFD54F),
      darkColor: Color(0xFFF57F17),
      hasAura: true,
    ),
    BallSkin(
      id: 'altin',
      name: 'Saf Altın',
      cost: 4500,
      rarity: Rarity.legendary,
      mainColor: Color(0xFFFFEA00),
      glowColor: Color(0xFFFFD600),
      darkColor: Color(0xFFFF8F00),
      hasAura: true,
    ),
  ];

  static BallSkin getById(String id) {
    return allSkins.firstWhere((s) => s.id == id, orElse: () => allSkins.first);
  }
}

class PaddleSkin {
  final String id;
  final String? _name;
  final int cost;
  final Rarity rarity;
  final Color color1;
  final Color color2;
  final Color glowColor;

  const PaddleSkin({
    required this.id,
    String? name,
    required this.cost,
    required this.rarity,
    required this.color1,
    required this.color2,
    required this.glowColor,
  }) : _name = name;

  String get name => _name != null ? I18n.tr(id) : I18n.tr(id);

  static const List<PaddleSkin> allSkins = [
    PaddleSkin(
      id: 'pclassic',
      name: 'Siber Klasik',
      cost: 0,
      rarity: Rarity.common,
      color1: Color(0xFF40C4FF),
      color2: Color(0xFF7C4DFF),
      glowColor: Color(0x6640C4FF),
    ),
    PaddleSkin(
      id: 'ppink',
      name: 'Neon Pembe',
      cost: 1800,
      rarity: Rarity.rare,
      color1: Color(0xFFFF80AB),
      color2: Color(0xFFC2185B),
      glowColor: Color(0x80FF80AB),
    ),
    PaddleSkin(
      id: 'pice',
      name: 'Buzul Kristali',
      cost: 2400,
      rarity: Rarity.rare,
      color1: Color(0xFFE0F7FA),
      color2: Color(0xFF00ACC1),
      glowColor: Color(0x66B2EBF2),
    ),
    PaddleSkin(
      id: 'pbat',
      name: 'Gece Yarasa',
      cost: 2800,
      rarity: Rarity.epic,
      color1: Color(0xFFFF5252),
      color2: Color(0xFF212121),
      glowColor: Color(0x80FF5252),
    ),
    PaddleSkin(
      id: 'pcyber',
      name: 'Siberpunk 2099',
      cost: 3200,
      rarity: Rarity.epic,
      color1: Color(0xFF00E5FF),
      color2: Color(0xFFD500F9),
      glowColor: Color(0x9900E5FF),
    ),
    PaddleSkin(
      id: 'pgold',
      name: 'Kraliyet Altını',
      cost: 4200,
      rarity: Rarity.legendary,
      color1: Color(0xFFFFE082),
      color2: Color(0xFFFF8F00),
      glowColor: Color(0x99FFD54F),
    ),
  ];

  static PaddleSkin getById(String id) {
    return allSkins.firstWhere((s) => s.id == id, orElse: () => allSkins.first);
  }
}

enum TrailStyle { dot, spark, fire, rainbow, plasma, ghost }

class TrailSkin {
  final String id;
  final String? _name;
  final int cost;
  final Rarity rarity;
  final TrailStyle style;
  final int length;

  const TrailSkin({
    required this.id,
    String? name,
    required this.cost,
    required this.rarity,
    required this.style,
    required this.length,
  }) : _name = name;

  String get name => _name != null ? I18n.tr(id) : I18n.tr(id);

  static const List<TrailSkin> allTrails = [
    TrailSkin(
      id: 't1',
      name: 'Kısa İz',
      cost: 0,
      rarity: Rarity.common,
      style: TrailStyle.dot,
      length: 6,
    ),
    TrailSkin(
      id: 't2',
      name: 'Neon Kuyruk',
      cost: 1600,
      rarity: Rarity.rare,
      style: TrailStyle.dot,
      length: 16,
    ),
    TrailSkin(
      id: 'spark',
      name: 'Kıvılcım İzi',
      cost: 2200,
      rarity: Rarity.rare,
      style: TrailStyle.spark,
      length: 22,
    ),
    TrailSkin(
      id: 'fire',
      name: 'Alev İzi',
      cost: 2800,
      rarity: Rarity.epic,
      style: TrailStyle.fire,
      length: 26,
    ),
    TrailSkin(
      id: 'rainbow',
      name: 'Gökkuşağı',
      cost: 3400,
      rarity: Rarity.epic,
      style: TrailStyle.rainbow,
      length: 28,
    ),
    TrailSkin(
      id: 'plasma',
      name: 'Kozmik Plazma',
      cost: 4200,
      rarity: Rarity.legendary,
      style: TrailStyle.plasma,
      length: 32,
    ),
  ];

  static TrailSkin getById(String id) {
    return allTrails.firstWhere((s) => s.id == id, orElse: () => allTrails.first);
  }
}

class FishItem {
  final String id;
  final String? _name;
  final Rarity rarity;
  final double size;
  final Color color;
  final Color secondaryColor;

  const FishItem({
    required this.id,
    String? name,
    required this.rarity,
    required this.size,
    required this.color,
    required this.secondaryColor,
  }) : _name = name;

  String get name => _name != null ? I18n.tr(id) : I18n.tr(id);
  String get assetPath => 'assets/images/fishes/$id.png';

  static const List<FishItem> allFish = [
    FishItem(
      id: 'guppy',
      name: 'Mercan Lepistes',
      rarity: Rarity.common,
      size: 1.0,
      color: Color(0xFFFF8A80),
      secondaryColor: Color(0xFFFF5252),
    ),
    FishItem(
      id: 'tetra',
      name: 'Neon Tetra',
      rarity: Rarity.common,
      size: 1.1,
      color: Color(0xFF4FC3F7),
      secondaryColor: Color(0xFF0288D1),
    ),
    FishItem(
      id: 'angel',
      name: 'Altın Melek Balığı',
      rarity: Rarity.rare,
      size: 1.45,
      color: Color(0xFFFFF59D),
      secondaryColor: Color(0xFFFBC02D),
    ),
    FishItem(
      id: 'betta',
      name: 'Kral Betta',
      rarity: Rarity.rare,
      size: 1.4,
      color: Color(0xFFE040FB),
      secondaryColor: Color(0xFF8E24AA),
    ),
    FishItem(
      id: 'discus',
      name: 'Alev Diskus',
      rarity: Rarity.epic,
      size: 1.6,
      color: Color(0xFFFFAB40),
      secondaryColor: Color(0xFFFF6D00),
    ),
    FishItem(
      id: 'arowana',
      name: 'Efsanevi Ejder Arowana',
      rarity: Rarity.legendary,
      size: 1.9,
      color: Color(0xFFFFD700),
      secondaryColor: Color(0xFFFFAB00),
    ),
  ];

  static FishItem getById(String id) {
    return allFish.firstWhere((f) => f.id == id, orElse: () => allFish.first);
  }
}

class CrateDef {
  final String id;
  final String? _name;
  final int cost;
  final Rarity tier;
  final Color primaryColor;
  final Map<Rarity, double> weights;

  const CrateDef({
    required this.id,
    String? name,
    required this.cost,
    required this.tier,
    required this.primaryColor,
    required this.weights,
  }) : _name = name;

  String get name => _name != null ? I18n.tr(id) : I18n.tr(id);

  static const List<CrateDef> allCrates = [
    CrateDef(
      id: 'wood',
      name: 'Ahşap Sandık',
      cost: 900,
      tier: Rarity.common,
      primaryColor: Color(0xFF8D6E63),
      weights: {
        Rarity.common: 72.0,
        Rarity.rare: 22.0,
        Rarity.epic: 5.5,
        Rarity.legendary: 0.5,
      },
    ),
    CrateDef(
      id: 'coral',
      name: 'Mercan Sandığı',
      cost: 1800,
      tier: Rarity.rare,
      primaryColor: Color(0xFF00BCD4),
      weights: {
        Rarity.common: 42.0,
        Rarity.rare: 38.0,
        Rarity.epic: 17.0,
        Rarity.legendary: 3.0,
      },
    ),
    CrateDef(
      id: 'abyss',
      name: 'Derinlik Sandığı',
      cost: 3200,
      tier: Rarity.legendary,
      primaryColor: Color(0xFF7C4DFF),
      weights: {
        Rarity.common: 12.0,
        Rarity.rare: 38.0,
        Rarity.epic: 38.0,
        Rarity.legendary: 12.0,
      },
    ),
  ];
}

class UpgradeDef {
  final String id;
  final String? _name;
  final String? _description;
  final IconData icon;
  final int maxLevel;
  final List<int> costs;

  const UpgradeDef({
    required this.id,
    String? name,
    String? description,
    required this.icon,
    required this.maxLevel,
    required this.costs,
  }) : _name = name, _description = description;

  String get name => _name != null ? I18n.tr('${id}_title') : I18n.tr('${id}_title');
  String get description => _description != null ? I18n.tr('${id}_desc') : I18n.tr('${id}_desc');

  static const List<UpgradeDef> allUpgrades = [
    UpgradeDef(
      id: 'battery',
      name: 'Kozmik Batarya',
      description: 'Ulti göstergesi her seviyede %25 daha hızlı dolar.',
      icon: Icons.bolt,
      maxLevel: 3,
      costs: [900, 1800, 3200],
    ),
    UpgradeDef(
      id: 'magnet',
      name: 'Plazma Mıknatısı',
      description: 'Düşen tüm güçlendirmeleri otomatik olarak rakete çeker.',
      icon: Icons.filter_tilt_shift,
      maxLevel: 3,
      costs: [1100, 2100, 3600],
    ),
    UpgradeDef(
      id: 'luck',
      name: 'Şans Yıldızı',
      description: 'Sandıklardan nadir eşya ve oyunda pozitif buff çıkma şansını artırır.',
      icon: Icons.auto_awesome,
      maxLevel: 3,
      costs: [1400, 2600, 4200],
    ),
  ];
}

class BoostItem {
  final String id;
  final String? _name;
  final String? _description;
  final int cost;
  final IconData icon;
  final Color color;

  const BoostItem({
    required this.id,
    String? name,
    String? description,
    required this.cost,
    required this.icon,
    required this.color,
  }) : _name = name, _description = description;

  String get name => _name != null ? I18n.tr('${id}_boost_title') : I18n.tr('${id}_boost_title');
  String get description => _description != null ? I18n.tr('${id}_boost_desc') : I18n.tr('${id}_boost_desc');

  static const List<BoostItem> allBoosts = [
    BoostItem(
      id: 'life',
      name: '+1 Ekstra Can',
      description: 'Maça 1 fazladan can ile başlayın.',
      cost: 900,
      icon: Icons.favorite,
      color: Color(0xFFFF5252),
    ),
    BoostItem(
      id: 'wide',
      name: 'Geniş Raket',
      description: 'Maça doğrudan genişletilmiş raket ile başlayın.',
      cost: 1100,
      icon: Icons.aspect_ratio,
      color: Color(0xFF40C4FF),
    ),
    BoostItem(
      id: 'multi',
      name: 'Çoklu Başlangıç',
      description: 'Maça tek top yerine 3 topla aynı anda başlayın.',
      cost: 1700,
      icon: Icons.blur_on,
      color: Color(0xFFFF9800),
    ),
  ];
}

class BackgroundTheme {
  final String id;
  final String nameKey;
  final String descKey;
  final int cost;
  final IconData icon;
  final Color primaryColor;
  final Color secondaryColor;
  final Color accentColor;

  const BackgroundTheme({
    required this.id,
    required this.nameKey,
    required this.descKey,
    required this.cost,
    required this.icon,
    required this.primaryColor,
    required this.secondaryColor,
    required this.accentColor,
  });

  static const List<BackgroundTheme> allThemes = [
    BackgroundTheme(
      id: 'bg_default',
      nameKey: 'bg_default',
      descKey: 'bg_default_desc',
      cost: 0,
      icon: Icons.stars,
      primaryColor: Color(0xFF0D1B2A),
      secondaryColor: Color(0xFF1B263B),
      accentColor: Color(0xFF415A77),
    ),
    BackgroundTheme(
      id: 'bg_nebula',
      nameKey: 'bg_nebula',
      descKey: 'bg_nebula_desc',
      cost: 2000,
      icon: Icons.blur_circular,
      primaryColor: Color(0xFF1A0B2E),
      secondaryColor: Color(0xFF2E1065),
      accentColor: Color(0xFFC084FC),
    ),
    BackgroundTheme(
      id: 'bg_matrix',
      nameKey: 'bg_matrix',
      descKey: 'bg_matrix_desc',
      cost: 2000,
      icon: Icons.grid_4x4,
      primaryColor: Color(0xFF030712),
      secondaryColor: Color(0xFF022C22),
      accentColor: Color(0xFF10B981),
    ),
    BackgroundTheme(
      id: 'bg_abyss',
      nameKey: 'bg_abyss',
      descKey: 'bg_abyss_desc',
      cost: 2000,
      icon: Icons.water,
      primaryColor: Color(0xFF020E1C),
      secondaryColor: Color(0xFF03254C),
      accentColor: Color(0xFF00E5FF),
    ),
    BackgroundTheme(
      id: 'bg_sunset',
      nameKey: 'bg_sunset',
      descKey: 'bg_sunset_desc',
      cost: 2000,
      icon: Icons.wb_twilight,
      primaryColor: Color(0xFF1E0B24),
      secondaryColor: Color(0xFF3B0764),
      accentColor: Color(0xFFFF5376),
    ),
    BackgroundTheme(
      id: 'bg_inferno',
      nameKey: 'bg_inferno',
      descKey: 'bg_inferno_desc',
      cost: 2000,
      icon: Icons.local_fire_department,
      primaryColor: Color(0xFF1A0800),
      secondaryColor: Color(0xFF431407),
      accentColor: Color(0xFFFF7A00),
    ),
  ];
}

