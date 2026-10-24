import 'package:flutter/material.dart';
import '../engine/i18n.dart';

enum SectorBlessingType {
  resonanceTether,
  prismaticSplitter,
  chronoSmash,
  ghostEcho,
  springboard,
  gravityPin,
  sonicRipple,
  emergencyClutch,
}

class SectorBlessing {
  final SectorBlessingType type;
  final String id;
  final String titleKey;
  final String descKey;
  final IconData icon;
  final Color primaryColor;
  final Color secondaryColor;

  const SectorBlessing({
    required this.type,
    required this.id,
    required this.titleKey,
    required this.descKey,
    required this.icon,
    required this.primaryColor,
    required this.secondaryColor,
  });

  String get title => I18n.tr(titleKey);
  String get description => I18n.tr(descKey);

  static const List<SectorBlessing> all = [
    SectorBlessing(
      type: SectorBlessingType.resonanceTether,
      id: 'resonance_tether',
      titleKey: 'blessing_tether_title',
      descKey: 'blessing_tether_desc',
      icon: Icons.gesture_rounded,
      primaryColor: Color(0xFF00E5FF),
      secondaryColor: Color(0xFF0091EA),
    ),
    SectorBlessing(
      type: SectorBlessingType.prismaticSplitter,
      id: 'prismatic_splitter',
      titleKey: 'blessing_prismatic_title',
      descKey: 'blessing_prismatic_desc',
      icon: Icons.change_history_rounded,
      primaryColor: Color(0xFFE040FB),
      secondaryColor: Color(0xFF7B1FA2),
    ),
    SectorBlessing(
      type: SectorBlessingType.chronoSmash,
      id: 'chrono_smash',
      titleKey: 'blessing_chrono_title',
      descKey: 'blessing_chrono_desc',
      icon: Icons.radar_rounded,
      primaryColor: Color(0xFFFFD54F),
      secondaryColor: Color(0xFFFF8F00),
    ),
    SectorBlessing(
      type: SectorBlessingType.ghostEcho,
      id: 'ghost_echo',
      titleKey: 'blessing_ghost_title',
      descKey: 'blessing_ghost_desc',
      icon: Icons.blur_on_rounded,
      primaryColor: Color(0xFFB388FF),
      secondaryColor: Color(0xFF651FFF),
    ),
    SectorBlessing(
      type: SectorBlessingType.springboard,
      id: 'springboard',
      titleKey: 'blessing_spring_title',
      descKey: 'blessing_spring_desc',
      icon: Icons.vertical_align_top_rounded,
      primaryColor: Color(0xFFFF6D00),
      secondaryColor: Color(0xFFBF360C),
    ),
    SectorBlessing(
      type: SectorBlessingType.gravityPin,
      id: 'gravity_pin',
      titleKey: 'blessing_pin_title',
      descKey: 'blessing_pin_desc',
      icon: Icons.cyclone_rounded,
      primaryColor: Color(0xFF00E676),
      secondaryColor: Color(0xFF1B5E20),
    ),
    SectorBlessing(
      type: SectorBlessingType.sonicRipple,
      id: 'sonic_ripple',
      titleKey: 'blessing_sonic_title',
      descKey: 'blessing_sonic_desc',
      icon: Icons.graphic_eq_rounded,
      primaryColor: Color(0xFFFF4081),
      secondaryColor: Color(0xFFC51162),
    ),
    SectorBlessing(
      type: SectorBlessingType.emergencyClutch,
      id: 'emergency_clutch',
      titleKey: 'blessing_clutch_title',
      descKey: 'blessing_clutch_desc',
      icon: Icons.shield_rounded,
      primaryColor: Color(0xFF76FF03),
      secondaryColor: Color(0xFF33691E),
    ),
  ];

  static SectorBlessing? getById(String? id) {
    if (id == null) return null;
    try {
      return all.firstWhere((b) => b.id == id);
    } catch (_) {
      return null;
    }
  }
}
