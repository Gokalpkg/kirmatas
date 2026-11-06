import 'package:flutter/material.dart';
import '../engine/i18n.dart';

/// Represents a visual decoration in the player's aquarium with tangible passive buffs.
class AquariumDecoration {
  final String id;
  final String _nameTr;
  final String _nameEn;
  final String _descTr;
  final String _descEn;
  final String _buffTr;
  final String _buffEn;
  final int cost;
  final bool isPearlCost;
  final double goldBonusMultiplier;
  final IconData icon;
  final Color primaryColor;
  final Color accentColor;

  String get name => I18n.bi(_nameTr, _nameEn);
  String get description => I18n.bi(_descTr, _descEn);
  String get passiveBuffText => I18n.bi(_buffTr, _buffEn);

  const AquariumDecoration({
    required this.id,
    required String name,
    String? nameEn,
    required String description,
    String? descriptionEn,
    required String passiveBuffText,
    String? passiveBuffTextEn,
    required this.cost,
    this.isPearlCost = false,
    this.goldBonusMultiplier = 0.05,
    required this.icon,
    required this.primaryColor,
    required this.accentColor,
  })  : _nameTr = name,
        _nameEn = nameEn ?? name,
        _descTr = description,
        _descEn = descriptionEn ?? description,
        _buffTr = passiveBuffText,
        _buffEn = passiveBuffTextEn ?? passiveBuffText;

  static const List<AquariumDecoration> all = [
    AquariumDecoration(
      id: 'shipwreck',
      name: 'Batık Korsan Gemisi',
      nameEn: 'Sunken Pirate Galleon',
      description: 'Derin deniz kumlarına saplanmış kadim ahşap kalyon enkazı.',
      descriptionEn: 'An ancient wooden galleon wreck resting in the deep sea sands.',
      passiveBuffText: 'Akvaryum Sandığı: +%10 Altın Kapasitesi',
      passiveBuffTextEn: 'Aquarium Vault: +10% Gold Capacity',
      cost: 350,
      goldBonusMultiplier: 0.05,
      icon: Icons.sailing_rounded,
      primaryColor: Color(0xFF8D6E63),
      accentColor: Color(0xFFFFD54F),
    ),
    AquariumDecoration(
      id: 'neon_corals',
      name: 'Biyolüminesans Mercanlar',
      nameEn: 'Bioluminescent Corals',
      description: 'Karanlık sularda parıldayan neon mercan kolonisi.',
      descriptionEn: 'A glowing neon coral colony illuminating the dark waters.',
      passiveBuffText: 'Akvaryum Canlılığı: +%8 Balık Yüzme Hızı',
      passiveBuffTextEn: 'Vitality: +8% Fish Swim Speed & Gold Yield',
      cost: 600,
      goldBonusMultiplier: 0.08,
      icon: Icons.wb_twilight_rounded,
      primaryColor: Color(0xFF00E5FF),
      accentColor: Color(0xFFFF4081),
    ),
    AquariumDecoration(
      id: 'submerged_temple',
      name: 'Kaunos Batık Tapınağı',
      nameEn: 'Submerged Kaunos Temple',
      description: 'Mermer sütunlar ve sualtı rünleriyle antik Likya tapınağı.',
      descriptionEn: 'Ancient Lycian temple with marble columns and glowing underwater runes.',
      passiveBuffText: 'Antik Bereket: +%12 Akvaryum Altın Üretimi',
      passiveBuffTextEn: 'Ancient Blessing: +12% Aquarium Gold Production',
      cost: 1000,
      goldBonusMultiplier: 0.12,
      icon: Icons.account_balance_rounded,
      primaryColor: Color(0xFF80DEEA),
      accentColor: Color(0xFF69F0AE),
    ),
    AquariumDecoration(
      id: 'glowing_anemone',
      name: 'Işıltılı Deniz Şakayığı',
      nameEn: 'Luminous Sea Anemone',
      description: 'Akıntıyla ritmik salınan mor ve turkuaz anemon bahçesi.',
      descriptionEn: 'Violet and turquoise anemone garden swaying rhythmically with the current.',
      passiveBuffText: 'Biyolojik Işıma: +%15 Yem Doygunluk Süresi',
      passiveBuffTextEn: 'Bio-Glow: +15% Feed Duration & Gold Production',
      cost: 1500,
      goldBonusMultiplier: 0.15,
      icon: Icons.flare_rounded,
      primaryColor: Color(0xFFE040FB),
      accentColor: Color(0xFF7C4DFF),
    ),
    AquariumDecoration(
      id: 'atlantis_obelisk',
      name: 'Atlantis Kristal Dikilitaşı',
      nameEn: 'Atlantis Crystal Obelisk',
      description: 'Deniz tabanında havada süzülen kadim enerji monolit kristali.',
      descriptionEn: 'Ancient levitating energy monolith crystal above the seabed.',
      passiveBuffText: 'Kozmik Rezonans: +%20 Akvaryum Altın Üretimi',
      passiveBuffTextEn: 'Cosmic Resonance: +20% Aquarium Gold Production',
      cost: 2200,
      goldBonusMultiplier: 0.20,
      icon: Icons.diamond_rounded,
      primaryColor: Color(0xFF64FFDA),
      accentColor: Color(0xFF00B0FF),
    ),
    AquariumDecoration(
      id: 'poseidon_trident',
      name: 'Poseidon Üçlü Zıpkını',
      nameEn: 'Trident of Poseidon',
      description: 'Kayalıklara saplanmış altın işlemeli mitolojik deniz zıpkını.',
      descriptionEn: 'Mythological golden trident embedded in the abyssal rock.',
      passiveBuffText: 'Fırtına Bereketi: +%25 Pasif Altın ve Hazine Çekimi',
      passiveBuffTextEn: 'Storm Blessing: +25% Passive Gold & Treasure Pull',
      cost: 3500,
      goldBonusMultiplier: 0.25,
      icon: Icons.flash_on_rounded,
      primaryColor: Color(0xFFFFD700),
      accentColor: Color(0xFFFF9100),
    ),
    AquariumDecoration(
      id: 'pearl_clam',
      name: 'Kozmik İnci İstiridyesi',
      nameEn: 'Cosmic Pearl Clam',
      description: 'Aralıklı açılıp parıldayan dev mor sedef istiridye.',
      descriptionEn: 'Giant mother-of-pearl clam revealing a radiant cosmic pearl.',
      passiveBuffText: 'Sedef Zenginliği: +%30 Akvaryum Altın Üretimi',
      passiveBuffTextEn: 'Nacre Wealth: +30% Aquarium Gold Production',
      cost: 2800,
      isPearlCost: false,
      goldBonusMultiplier: 0.30,
      icon: Icons.bubble_chart_rounded,
      primaryColor: Color(0xFFE040FB),
      accentColor: Color(0xFF00E5FF),
    ),
    AquariumDecoration(
      id: 'submarine_volcano',
      name: 'Neon Denizaltı Volkanı',
      nameEn: 'Neon Submarine Volcano',
      description: 'Dip yarığından lav ve neon mineraller püskürten termal baca.',
      descriptionEn: 'Hydrothermal vent erupting with magma and glowing neon minerals.',
      passiveBuffText: 'Termal Enerji: +%35 Tüm Akvaryum Üretimi',
      passiveBuffTextEn: 'Thermal Surge: +35% Total Aquarium Production',
      cost: 5000,
      goldBonusMultiplier: 0.35,
      icon: Icons.volcano_rounded,
      primaryColor: Color(0xFFFF1744),
      accentColor: Color(0xFFFF9100),
    ),
  ];

  static AquariumDecoration? findById(String id) {
    for (final d in all) {
      if (d.id == id) return d;
    }
    return null;
  }
}
