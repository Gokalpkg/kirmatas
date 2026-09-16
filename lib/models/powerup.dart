import 'package:flutter/material.dart';
import '../engine/i18n.dart';

enum PowerUpKind { buff, debuff }

enum PowerUpType {
  // Buffs
  wide('Geniş', Color(0xFF40C4FF), 10.0, PowerUpKind.buff, Icons.unfold_more),
  slow('Yavaş', Color(0xFF69F0AE), 8.0, PowerUpKind.buff, Icons.slow_motion_video),
  sticky('Yapışkan', Color(0xFFB388FF), 10.0, PowerUpKind.buff, Icons.pan_tool_alt),
  laser('Lazer', Color(0xFFFFD740), 8.0, PowerUpKind.buff, Icons.flash_on),
  fireball('Ateş', Color(0xFFFF6D00), 7.0, PowerUpKind.buff, Icons.local_fire_department),
  bomb('Bomba', Color(0xFF8D6E63), 7.0, PowerUpKind.buff, Icons.lens_blur),
  doublescore('x2 Puan', Color(0xFFEC407A), 10.0, PowerUpKind.buff, Icons.star),
  multi('Çoklu Top', Color(0xFFFF9800), 0.0, PowerUpKind.buff, Icons.hub),
  life('Can', Color(0xFFFF5252), 0.0, PowerUpKind.buff, Icons.favorite),
  shield('Kalkan', Color(0xFF26C6DA), 0.0, PowerUpKind.buff, Icons.shield),
  pierce('Delici', Color(0xFF00E5FF), 6.0, PowerUpKind.buff, Icons.arrow_upward),
  rocket('Roket', Color(0xFFFF5722), 9.0, PowerUpKind.buff, Icons.rocket_launch),
  net('Güvenlik Ağı', Color(0xFF8BC34A), 10.0, PowerUpKind.buff, Icons.grid_goldenratio),
  lightning('Yıldırım', Color(0xFF00E5FF), 8.0, PowerUpKind.buff, Icons.bolt),
  drone('Drone', Color(0xFF00E676), 12.0, PowerUpKind.buff, Icons.smart_toy),
  chrono('Zaman', Color(0xFF80D8FF), 5.0, PowerUpKind.buff, Icons.timer),
  vortex('Girdap', Color(0xFFE040FB), 9.0, PowerUpKind.buff, Icons.cyclone),
  mirror('Ayna', Color(0xFFF48FB1), 0.0, PowerUpKind.buff, Icons.flip),
  lock('Kilit', Color(0xFFFFAB00), 0.0, PowerUpKind.buff, Icons.lock),

  // Debuffs
  shrink('Dar Raket', Color(0xFF90A4AE), 8.0, PowerUpKind.debuff, Icons.unfold_less),
  fastball('Hızlı Top', Color(0xFFFFB74D), 8.0, PowerUpKind.debuff, Icons.speed),
  reverse('Ters Kontrol', Color(0xFFCE93D8), 7.0, PowerUpKind.debuff, Icons.sync_problem),
  clumsy('Buz / Kayma', Color(0xFF80CBC4), 7.0, PowerUpKind.debuff, Icons.skateboarding),
  invis('Hayalet Raket', Color(0xFFCFD8DC), 4.5, PowerUpKind.debuff, Icons.visibility_off);

  final String _label;
  final Color color;
  final double duration; // in seconds (0 = instant)
  final PowerUpKind kind;
  final IconData icon;

  const PowerUpType(this._label, this.color, this.duration, this.kind, this.icon);

  String get label => _label.isNotEmpty ? I18n.tr('pup_$name') : I18n.tr('pup_$name');

  bool get isInstant => duration <= 0;

  String get assetPath => 'assets/images/skills/$name.png';
}

class FallingCapsule {
  double x;
  double y;
  double vy;
  final PowerUpType type;
  double width = 28.0;
  double height = 14.0;
  double animTimer = 0.0;

  FallingCapsule({
    required this.x,
    required this.y,
    required this.type,
    this.vy = 180.0,
  });

  void update(double dt) {
    y += vy * dt;
    animTimer += dt;
  }
}

class ActivePowerUp {
  final PowerUpType type;
  double timeLeft;
  final double totalTime;

  ActivePowerUp(this.type)
      : timeLeft = type.duration,
        totalTime = type.duration;

  double get progress => totalTime > 0 ? (timeLeft / totalTime).clamp(0.0, 1.0) : 0.0;
}
