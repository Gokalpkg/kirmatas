import 'package:flutter/material.dart';

enum AdventureCardType {
  riskDouble,
  overchargedSpeed,
  pinataHeaven,
  goldenOctopus,
}

class AdventureCard {
  final AdventureCardType type;
  final String id;
  final String nameTr;
  final String descTr;
  final int costGold;
  final int costPearls;
  final IconData icon;
  final Color primaryColor;

  const AdventureCard({
    required this.type,
    required this.id,
    required this.nameTr,
    required this.descTr,
    this.costGold = 200,
    this.costPearls = 0,
    required this.icon,
    required this.primaryColor,
  });

  static const List<AdventureCard> allCards = [
    AdventureCard(
      type: AdventureCardType.riskDouble,
      id: 'risk_double',
      nameTr: 'Risk Bahsi',
      descTr: 'Tüm tuğlaların canı 2 katına çıkar, ancak el sonu altın kazancı x4 olur!',
      costGold: 200,
      icon: Icons.casino_rounded,
      primaryColor: Color(0xFFFF1744),
    ),
    AdventureCard(
      type: AdventureCardType.overchargedSpeed,
      id: 'overcharged_speed',
      nameTr: 'Ateşli Yıldırım',
      descTr: 'Top hızı +%40 artar ve palet sürekli delici lazer fırlatır!',
      costGold: 200,
      icon: Icons.flash_on_rounded,
      primaryColor: Color(0xFFFFD700),
    ),
    AdventureCard(
      type: AdventureCardType.pinataHeaven,
      id: 'pinata_heaven',
      nameTr: 'Piñata Cenneti',
      descTr: 'Sahaya başlangıçta 2 ekstra Altın Piñata eklenir!',
      costGold: 200,
      icon: Icons.card_giftcard_rounded,
      primaryColor: Color(0xFF00E5FF),
    ),
    AdventureCard(
      type: AdventureCardType.goldenOctopus,
      id: 'golden_octopus',
      nameTr: 'Altın Ahtapot Dokunaçları',
      descTr: 'Düşen ilk topu otomatik kurtarır ve o eldeki TÜM altınları x5 yapar!',
      costGold: 0,
      costPearls: 1,
      icon: Icons.bubble_chart_rounded,
      primaryColor: Color(0xFFE040FB),
    ),
  ];
}
