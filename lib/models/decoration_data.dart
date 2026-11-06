import 'package:flutter/material.dart';

/// Represents a visual decoration in the player's aquarium with tangible passive buffs.
class AquariumDecoration {
  final String id;
  final String name;
  final String description;
  final String passiveBuffText;
  final int cost;
  final bool isPearlCost;
  final double goldBonusMultiplier;
  final IconData icon;
  final Color primaryColor;
  final Color accentColor;

  const AquariumDecoration({
    required this.id,
    required this.name,
    required this.description,
    required this.passiveBuffText,
    required this.cost,
    this.isPearlCost = false,
    this.goldBonusMultiplier = 0.05,
    required this.icon,
    required this.primaryColor,
    required this.accentColor,
  });

  static const List<AquariumDecoration> all = [
    AquariumDecoration(
      id: 'shipwreck',
      name: 'Batık Korsan Gemisi',
      description: 'Derin deniz kumlarına saplanmış kadim ahşap kalyon enkazı.',
      passiveBuffText: 'Akvaryum Sandığı: +%10 Altın Kapasitesi',
      cost: 350,
      goldBonusMultiplier: 0.05,
      icon: Icons.sailing_rounded,
      primaryColor: Color(0xFF8D6E63),
      accentColor: Color(0xFFFFD54F),
    ),
    AquariumDecoration(
      id: 'neon_corals',
      name: 'Biyolüminesans Mercanlar',
      description: 'Karanlık sularda parıldayan neon mercan kolonisi.',
      passiveBuffText: 'Akvaryum Canlılığı: +%8 Balık Yüzme Hızı',
      cost: 600,
      goldBonusMultiplier: 0.08,
      icon: Icons.wb_twilight_rounded,
      primaryColor: Color(0xFF00E5FF),
      accentColor: Color(0xFFFF4081),
    ),
    AquariumDecoration(
      id: 'submerged_temple',
      name: 'Kaunos Batık Tapınağı',
      description: 'Mermer sütunlar ve sualtı rünleriyle antik Likya tapınağı.',
      passiveBuffText: 'Antik Bereket: +%12 Akvaryum Altın Üretimi',
      cost: 1000,
      goldBonusMultiplier: 0.12,
      icon: Icons.account_balance_rounded,
      primaryColor: Color(0xFF80DEEA),
      accentColor: Color(0xFF69F0AE),
    ),
    AquariumDecoration(
      id: 'glowing_anemone',
      name: 'Işıltılı Deniz Şakayığı',
      description: 'Akıntıyla ritmik salınan mor ve turkuaz anemon bahçesi.',
      passiveBuffText: 'Biyolojik Işıma: +%15 Yem Doygunluk Süresi',
      cost: 1500,
      goldBonusMultiplier: 0.15,
      icon: Icons.flare_rounded,
      primaryColor: Color(0xFFE040FB),
      accentColor: Color(0xFF7C4DFF),
    ),
    AquariumDecoration(
      id: 'atlantis_obelisk',
      name: 'Atlantis Kristal Dikilitaşı',
      description: 'Deniz tabanında havada süzülen kadim enerji monolit kristali.',
      passiveBuffText: 'Kozmik Rezonans: +%20 Akvaryum Altın Üretimi',
      cost: 2200,
      goldBonusMultiplier: 0.20,
      icon: Icons.diamond_rounded,
      primaryColor: Color(0xFF64FFDA),
      accentColor: Color(0xFF00B0FF),
    ),
    AquariumDecoration(
      id: 'poseidon_trident',
      name: 'Poseidon Üçlü Zıpkını',
      description: 'Kayalıklara saplanmış altın işlemeli mitolojik deniz zıpkını.',
      passiveBuffText: 'Fırtına Bereketi: +%25 Pasif Altın ve Hazine Çekimi',
      cost: 3500,
      goldBonusMultiplier: 0.25,
      icon: Icons.flash_on_rounded,
      primaryColor: Color(0xFFFFD700),
      accentColor: Color(0xFFFF9100),
    ),
    AquariumDecoration(
      id: 'pearl_clam',
      name: 'Kozmik İnci İstiridyesi',
      description: 'Aralıklı açılıp parıldayan dev mor sedef istiridye.',
      passiveBuffText: 'Sedef Zenginliği: +%30 Akvaryum Altın Üretimi',
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
      description: 'Dip yarığından lav ve neon mineraller püskürten termal baca.',
      passiveBuffText: 'Termal Enerji: +%35 Tüm Akvaryum Üretimi',
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
