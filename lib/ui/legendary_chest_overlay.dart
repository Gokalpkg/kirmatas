import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../engine/audio_manager.dart';
import '../engine/i18n.dart';
import '../models/cosmetics.dart';
import 'chest_widget.dart';

// ============================================================================
// VAMPIRE SURVIVORS STYLE: LEGENDARY JACKPOT CHEST OVERLAY & VFX CONTROLLER
// MOD A: Modern Crisp Pixel Art (Zero blur, integer coords, drawRect, pooling)
// ============================================================================

/// Particle types for the 150+ Object-Pooled Loot Piñata Fountain.
enum PixelLootType {
  coin, // Golden square with dark border
  gem, // Cyan or Magenta diamond crystal (pixel cross)
  confetti // Stepped square celebratory flakes
}

/// Pre-allocated, zero-allocation particle for the loot fountain.
class PixelLootParticle {
  double x = 0;
  double y = 0;
  double vx = 0;
  double vy = 0;
  double gravity = 620.0;
  int bounceCount = 0;
  PixelLootType type = PixelLootType.coin;
  Color color = const Color(0xFFFFD54F);
  Color secondaryColor = const Color(0xFFFFA000);
  double size = 4.0;
  bool active = false;
  double age = 0.0;
  double maxLife = 2.4;

  // 3-stepped ghost trail positions
  double tX0 = 0, tY0 = 0;
  double tX1 = 0, tY1 = 0;
  double tX2 = 0, tY2 = 0;

  void spawn({
    required double startX,
    required double startY,
    required double velocityX,
    required double velocityY,
    required double grav,
    required PixelLootType pType,
    required Color primary,
    required Color secondary,
    required double pSize,
    required double life,
  }) {
    x = startX;
    y = startY;
    vx = velocityX;
    vy = velocityY;
    gravity = grav;
    bounceCount = 0;
    type = pType;
    color = primary;
    secondaryColor = secondary;
    size = pSize;
    active = true;
    age = 0.0;
    maxLife = life;

    tX0 = x;
    tY0 = y;
    tX1 = x;
    tY1 = y;
    tX2 = x;
    tY2 = y;
  }

  void update(double dt, double floorY) {
    if (!active) return;
    age += dt;
    if (age >= maxLife) {
      active = false;
      return;
    }

    // Shift 3-stepped ghost trail
    tX2 = tX1;
    tY2 = tY1;
    tX1 = tX0;
    tY1 = tY0;
    tX0 = x;
    tY0 = y;

    // Physics step
    x += vx * dt;
    vy += gravity * dt;
    y += vy * dt;

    // Single floor bounce
    if (y >= floorY) {
      y = floorY;
      if (bounceCount == 0) {
        bounceCount++;
        vy = -vy * 0.46; // Elastic restitution
        vx = vx * 0.72; // Floor friction
      } else {
        vy = 0;
        vx = vx * 0.85;
      }
    }
  }
}

/// High-performance Object Pool holding exactly 180 particles.
class ParticlePool {
  static const int poolCapacity = 180;
  final List<PixelLootParticle> particles = List.generate(
    poolCapacity,
    (_) => PixelLootParticle(),
    growable: false,
  );
  int _activeCount = 0;

  int get activeCount => _activeCount;

  void reset() {
    for (int i = 0; i < poolCapacity; i++) {
      particles[i].active = false;
    }
    _activeCount = 0;
  }

  void emitFountain({
    required double originX,
    required double originY,
    required Color activeColor,
    required Random rand,
  }) {
    reset();
    final goldColors = [
      const Color(0xFFFFD54F),
      const Color(0xFFFFC107),
      const Color(0xFFFFF176),
      const Color(0xFFFFE082),
    ];
    final gemColors = [
      const Color(0xFF00E5FF),
      const Color(0xFFE040FB),
      const Color(0xFF76FF03),
      const Color(0xFFFF1744),
    ];

    for (int i = 0; i < poolCapacity; i++) {
      // Angles strictly concentrated between -70° and -110° (-1.22 rad to -1.92 rad)
      final angle = -pi * 0.5 + (rand.nextDouble() - 0.5) * 0.75;
      final speed = 280.0 + rand.nextDouble() * 320.0;
      final vx = cos(angle) * speed;
      final vy = sin(angle) * speed;

      PixelLootType type;
      Color primary;
      Color secondary;
      double size;

      if (i < 90) {
        // Pixel Coin
        type = PixelLootType.coin;
        primary = goldColors[rand.nextInt(goldColors.length)];
        secondary = const Color(0xFFE65100);
        size = 5.0 + (i % 3 == 0 ? 2.0 : 0.0);
      } else if (i < 140) {
        // Pixel Diamond/Gem
        type = PixelLootType.gem;
        primary = gemColors[rand.nextInt(gemColors.length)];
        secondary = Colors.white;
        size = 6.0;
      } else {
        // Square Confetti
        type = PixelLootType.confetti;
        primary = (i % 2 == 0) ? activeColor : Colors.white;
        secondary = const Color(0xFFFFD54F);
        size = 4.0;
      }

      particles[i].spawn(
        startX: originX + (rand.nextDouble() - 0.5) * 24.0,
        startY: originY,
        velocityX: vx,
        velocityY: vy,
        grav: 620.0 + rand.nextDouble() * 120.0,
        pType: type,
        primary: primary,
        secondary: secondary,
        pSize: size,
        life: 2.1 + rand.nextDouble() * 0.7,
      );
    }
    _activeCount = poolCapacity;
  }

  void updateAll(double dt, double floorY) {
    int active = 0;
    for (int i = 0; i < poolCapacity; i++) {
      if (particles[i].active) {
        particles[i].update(dt, floorY);
        if (particles[i].active) active++;
      }
    }
    _activeCount = active;
  }
}

/// Controller managing the exact millisecond choreography and audio/haptic events.
class ChestVfxController extends ChangeNotifier {
  final TickerProvider vsync;
  late final AnimationController timeline;

  // Particle pool
  final ParticlePool particlePool = ParticlePool();
  final Random _rand = Random();

  // State flags
  bool isHitStop = false;
  bool showWhiteFlash = false;
  int currentStep = 1;
  bool isRevealed = false;

  // Sound/Haptic pacing counters
  int _lastRumbleTick = -1;
  int _lastArpeggioTick = -1;
  double _lastTime = 0.0;

  // Callbacks
  final VoidCallback? onStep2PillarErupt;
  final VoidCallback? onStep5CardSlam;

  ChestVfxController({
    required this.vsync,
    this.onStep2PillarErupt,
    this.onStep5CardSlam,
  }) {
    // Total master timeline: 4200ms
    timeline = AnimationController(
      vsync: vsync,
      duration: const Duration(milliseconds: 4200),
    );
    timeline.addListener(_onTimelineTick);
  }

  void startChoreography({required double originX, required double originY, required Color activeColor}) {
    timeline.forward(from: 0.0);
    _lastTime = 0.0;
    _lastRumbleTick = -1;
    _lastArpeggioTick = -1;
    isHitStop = false;
    showWhiteFlash = false;
    currentStep = 1;
    isRevealed = false;
    particlePool.reset();
  }

  /// Instant skip to Adım 5 (Reveal) for 100-hour veteran players.
  void skipToReveal() {
    if (isRevealed) return;
    timeline.value = 3000.0 / 4200.0; // Directly land at 3000ms
    currentStep = 5;
    isRevealed = true;
    isHitStop = false;
    showWhiteFlash = false;
    notifyListeners();
    AudioManager.instance.playSfx(GameSfx.victory);
    HapticFeedback.heavyImpact();
  }

  void _onTimelineTick() {
    final ms = timeline.value * 4200.0;
    final dt = (timeline.value - _lastTime) * 4.2;
    _lastTime = timeline.value;

    // Update particle pool physics
    if (currentStep >= 3) {
      particlePool.updateAll(dt > 0 ? dt : 0.016, 580.0);
    }

    // -------------------------------------------------------------
    // ADIM 1: GERİLİM (0ms - 800ms)
    // -------------------------------------------------------------
    if (ms < 800.0) {
      currentStep = 1;
      isHitStop = false;
      showWhiteFlash = false;

      // Escalating rumble sound ticks + machine gun haptic ticks
      final rumbleIndex = ((ms / 800.0) * 8).floor();
      if (rumbleIndex != _lastRumbleTick && rumbleIndex >= 0 && rumbleIndex < 8) {
        _lastRumbleTick = rumbleIndex;
        final pitch = 0.75 + rumbleIndex * 0.12;
        AudioManager.instance.playSfx(GameSfx.hitBrick, playbackRate: pitch);
        HapticFeedback.selectionClick();
      }

      // 60ms Hit-Stop (740ms - 800ms) right before popping!
      if (ms >= 740.0 && !isHitStop) {
        isHitStop = true;
        AudioManager.instance.playSfx(GameSfx.steel, playbackRate: 0.70);
        HapticFeedback.heavyImpact();
      }
    }
    // -------------------------------------------------------------
    // ADIM 2: KIRILMA VE GÖKYÜZÜ SÜTUNU (800ms - 1000ms)
    // -------------------------------------------------------------
    else if (ms < 1000.0) {
      if (currentStep < 2) {
        currentStep = 2;
        isHitStop = false;
        showWhiteFlash = true; // 2 frames pure white flash
        AudioManager.instance.playSfx(GameSfx.explosion, playbackRate: 0.85);
        AudioManager.instance.playSfx(GameSfx.bossHit, playbackRate: 0.95);
        HapticFeedback.heavyImpact();
        onStep2PillarErupt?.call();
      }

      // White flash turns off after 2 frames (~45ms)
      if (ms >= 845.0 && showWhiteFlash) {
        showWhiteFlash = false;
      }
    }
    // -------------------------------------------------------------
    // ADIM 3: PİKSEL HAZİNE FISKİYESİ (1000ms - 3200ms)
    // -------------------------------------------------------------
    else if (ms < 1200.0) {
      if (currentStep < 3) {
        currentStep = 3;
        showWhiteFlash = false;
        particlePool.emitFountain(
          originX: 160.0,
          originY: 420.0,
          activeColor: const Color(0xFFFFD54F),
          rand: _rand,
        );
      }
    }
    // -------------------------------------------------------------
    // ADIM 4: NADİR ÖDÜLÜN YÜKSELİŞİ (1200ms - 3000ms)
    // -------------------------------------------------------------
    else if (ms < 3000.0) {
      if (currentStep < 4) {
        currentStep = 4;
      }

      // Ascending 80ms chiptune arpeggio ticks
      final arpeggioIndex = (((ms - 1200.0) / 1800.0) * 12).floor();
      if (arpeggioIndex != _lastArpeggioTick && arpeggioIndex >= 0 && arpeggioIndex < 12) {
        _lastArpeggioTick = arpeggioIndex;
        final notes = [1.0, 1.125, 1.25, 1.33, 1.5, 1.66, 1.75, 2.0, 2.25, 2.5, 2.66, 3.0];
        final pitch = notes[arpeggioIndex.clamp(0, notes.length - 1)];
        AudioManager.instance.playSfx(GameSfx.powerupBuff, playbackRate: pitch);
        if (arpeggioIndex.isEven) {
          AudioManager.instance.playSfx(GameSfx.bubble, playbackRate: pitch * 1.1);
        }
        HapticFeedback.selectionClick();
      }
    }
    // -------------------------------------------------------------
    // ADIM 5: MÜJDE KARTI VE QoL (3000ms+)
    // -------------------------------------------------------------
    else {
      if (currentStep < 5) {
        currentStep = 5;
        isRevealed = true;
        AudioManager.instance.playSfx(GameSfx.victory);
        HapticFeedback.heavyImpact();
        onStep5CardSlam?.call();
      }
    }

    notifyListeners();
  }

  @override
  void dispose() {
    timeline.removeListener(_onTimelineTick);
    timeline.dispose();
    super.dispose();
  }
}

// ============================================================================
// MOD A PIXEL ART CUSTOM PAINTERS (ZERO BLUR, INTEGER COORDS, DRAWS RECT)
// ============================================================================

/// Step 1: Leaking crisp gold pixel motes seeping through chest seams.
class _ChestPixelLeakPainter extends CustomPainter {
  final double progress; // 0.0 to 1.0 during Step 1
  _ChestPixelLeakPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0.1) return;
    final rand = Random(77);
    final paint = Paint()..style = PaintingStyle.fill;
    final goldColors = [
      const Color(0xFFFFD54F),
      const Color(0xFFFFC107),
      const Color(0xFFFFF59D),
    ];

    final count = (progress * 18).floor();
    for (int i = 0; i < count; i++) {
      final side = rand.nextBool();
      final rx = side
          ? (size.width * 0.5 - 38.0 - rand.nextDouble() * 20.0 * progress).roundToDouble()
          : (size.width * 0.5 + 38.0 + rand.nextDouble() * 20.0 * progress).roundToDouble();
      final ry = (size.height * 0.5 + (rand.nextDouble() - 0.5) * 44.0).roundToDouble();
      final pSize = (2.0 + (i % 2)).roundToDouble();

      paint.color = goldColors[i % goldColors.length];
      canvas.drawRect(Rect.fromLTWH(rx, ry, pSize, pSize), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _ChestPixelLeakPainter old) => old.progress != progress;
}

/// Step 2: 3-Layered Stepped Pixel Light Pillar with 12 FPS Palette Cycling.
class SteppedLightPillarPainter extends CustomPainter {
  final double progress; // 0.0 to 1.0
  final double time; // For 12 FPS palette cycling
  final Color activeColor;

  SteppedLightPillarPainter({
    required this.progress,
    required this.time,
    required this.activeColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0.0) return;
    final cx = (size.width * 0.5).roundToDouble();
    final bottomY = (size.height * 0.78).roundToDouble();

    // 12 FPS Palette Cycling Color Selection
    final frame = (time * 12.0).floor();
    final outerPalette = [
      const Color(0xFFFFD54F),
      const Color(0xFFFFB300),
      const Color(0xFFFFA000),
      const Color(0xFFFF8F00),
    ];
    final midPalette = [
      const Color(0xFF00E5FF),
      const Color(0xFF00B0FF),
      const Color(0xFFE040FB),
      const Color(0xFFD500F9),
    ];

    final outerColor = outerPalette[frame % outerPalette.length];
    final midColor = midPalette[(frame + 1) % midPalette.length];
    const innerColor = Color(0xFFFFFDE7); // Pure Cream White

    final paint = Paint()..style = PaintingStyle.fill;

    // Pillar width expands with stepped snap
    final outerW = (80.0 + (progress * 50.0)).roundToDouble();
    final midW = (54.0 + (progress * 34.0)).roundToDouble();
    final innerW = (28.0 + (progress * 18.0)).roundToDouble();

    // Layer 1: Outer Gold Stepped Beam
    paint.color = outerColor.withValues(alpha: 0.85);
    canvas.drawRect(Rect.fromLTWH(cx - outerW * 0.5, 0, outerW, bottomY), paint);

    // Layer 2: Mid Cyan/Magenta Stepped Beam
    paint.color = midColor.withValues(alpha: 0.90);
    canvas.drawRect(Rect.fromLTWH(cx - midW * 0.5, 0, midW, bottomY), paint);

    // Layer 3: Inner Pure Cream White Core
    paint.color = innerColor;
    canvas.drawRect(Rect.fromLTWH(cx - innerW * 0.5, 0, innerW, bottomY), paint);

    // Stepped pixel side teeth (horizontal notch blocks on borders)
    final rand = Random(42);
    paint.color = outerColor;
    for (int y = 0; y < bottomY; y += 12) {
      final toothW = (rand.nextInt(3) * 4.0).roundToDouble();
      canvas.drawRect(Rect.fromLTWH(cx - outerW * 0.5 - toothW, y.toDouble(), toothW, 8), paint);
      canvas.drawRect(Rect.fromLTWH(cx + outerW * 0.5, y.toDouble(), toothW, 8), paint);
    }
  }

  @override
  bool shouldRepaint(covariant SteppedLightPillarPainter old) =>
      old.progress != progress || old.time != time || old.activeColor != activeColor;
}

/// Step 3: 150+ Object-Pooled Pixel Loot Piñata Fountain with 3 Stepped Ghost Trails.
class ParticlePoolPainter extends CustomPainter {
  final ParticlePool pool;
  ParticlePoolPainter({required this.pool});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.fill;
    final strokePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    for (int i = 0; i < ParticlePool.poolCapacity; i++) {
      final p = pool.particles[i];
      if (!p.active) continue;

      final px = p.x.roundToDouble();
      final py = p.y.roundToDouble();
      final s = p.size.roundToDouble();

      // 3-Stepped Ghost Trails
      // Trail 2 (Oldest, smallest, 25% alpha)
      paint.color = p.color.withValues(alpha: 0.22);
      canvas.drawRect(Rect.fromCenter(center: Offset(p.tX2.roundToDouble(), p.tY2.roundToDouble()), width: s * 0.45, height: s * 0.45), paint);

      // Trail 1 (Mid, 45% alpha)
      paint.color = p.color.withValues(alpha: 0.45);
      canvas.drawRect(Rect.fromCenter(center: Offset(p.tX1.roundToDouble(), p.tY1.roundToDouble()), width: s * 0.70, height: s * 0.70), paint);

      // Trail 0 (Recent, 70% alpha)
      paint.color = p.color.withValues(alpha: 0.70);
      canvas.drawRect(Rect.fromCenter(center: Offset(p.tX0.roundToDouble(), p.tY0.roundToDouble()), width: s * 0.85, height: s * 0.85), paint);

      // Current Particle Body
      paint.color = p.color;
      switch (p.type) {
        case PixelLootType.coin:
          // Crisp square coin with 1px dark border
          canvas.drawRect(Rect.fromCenter(center: Offset(px, py), width: s, height: s), paint);
          strokePaint.color = p.secondaryColor;
          canvas.drawRect(Rect.fromCenter(center: Offset(px, py), width: s, height: s), strokePaint);
          break;

        case PixelLootType.gem:
          // Diamond / Crystal cross (stepped 5-pixel diamond)
          canvas.drawRect(Rect.fromLTWH(px - s * 0.5, py - s * 0.5, s, s), paint);
          paint.color = Colors.white;
          canvas.drawRect(Rect.fromLTWH(px - 1.0, py - 1.0, 2.0, 2.0), paint);
          break;

        case PixelLootType.confetti:
          canvas.drawRect(Rect.fromCenter(center: Offset(px, py), width: s, height: s), paint);
          break;
      }
    }
  }

  @override
  bool shouldRepaint(covariant ParticlePoolPainter old) => true;
}

/// Step 4: 8-Bit Pixel Cross Stars (+) and (x) orbiting the rising reward.
class PixelCrossStarsPainter extends CustomPainter {
  final double angle;
  final Color color;

  PixelCrossStarsPainter({required this.angle, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final cx = (size.width * 0.5).roundToDouble();
    final cy = (size.height * 0.5).roundToDouble();
    final radius = 64.0;
    final paint = Paint()..style = PaintingStyle.fill;

    // 8 Orbiting pixel stars
    for (int i = 0; i < 8; i++) {
      final a = angle + (i * pi / 4.0);
      final sx = (cx + cos(a) * radius).roundToDouble();
      final sy = (cy + sin(a) * radius).roundToDouble();

      paint.color = (i.isEven ? color : Colors.white);
      final isCross = i % 2 == 0;

      if (isCross) {
        // (+) Plus Shape (5 square pixels)
        canvas.drawRect(Rect.fromLTWH(sx - 1, sy - 4, 3, 9), paint);
        canvas.drawRect(Rect.fromLTWH(sx - 4, sy - 1, 9, 3), paint);
      } else {
        // (x) Cross Shape
        canvas.drawRect(Rect.fromLTWH(sx - 3, sy - 3, 3, 3), paint);
        canvas.drawRect(Rect.fromLTWH(sx + 1, sy - 3, 3, 3), paint);
        canvas.drawRect(Rect.fromLTWH(sx - 1, sy - 1, 3, 3), paint);
        canvas.drawRect(Rect.fromLTWH(sx - 3, sy + 1, 3, 3), paint);
        canvas.drawRect(Rect.fromLTWH(sx + 1, sy + 1, 3, 3), paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant PixelCrossStarsPainter old) => old.angle != angle || old.color != color;
}

/// Step 4: 3 Stepped Pixel Square Shockwaves expanding outward.
class SteppedPixelShockwavePainter extends CustomPainter {
  final double progress; // 0.0 to 1.0
  final Color color;

  SteppedPixelShockwavePainter({required this.progress, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0.0 || progress >= 1.0) return;
    final cx = (size.width * 0.5).roundToDouble();
    final cy = (size.height * 0.5).roundToDouble();
    final strokePaint = Paint()..style = PaintingStyle.stroke;

    final alpha = (1.0 - progress).clamp(0.0, 1.0);

    for (int w = 0; w < 3; w++) {
      final waveP = (progress - w * 0.20).clamp(0.0, 1.0);
      if (waveP <= 0.0) continue;

      final s = (140.0 * waveP).roundToDouble();
      strokePaint.color = (w == 0 ? color : (w == 1 ? const Color(0xFF00E5FF) : Colors.white))
          .withValues(alpha: alpha * 0.85);
      strokePaint.strokeWidth = (4.0 - w * 1.0).roundToDouble();

      // Sharp pixel-stepped square shockwave
      canvas.drawRect(Rect.fromCenter(center: Offset(cx, cy), width: s * 2, height: s * 2), strokePaint);
    }
  }

  @override
  bool shouldRepaint(covariant SteppedPixelShockwavePainter old) =>
      old.progress != progress || old.color != color;
}

/// Step 5: 45-degree Crisp Pixel Gleam sweeping across reward card.
class PixelGleamPainter extends CustomPainter {
  final double progress; // 0.0 to 1.0
  PixelGleamPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0.0 || progress >= 1.0) return;
    final w = size.width;
    final h = size.height;
    final offset = (progress * (w + h) - h * 0.5).roundToDouble();

    final paint = Paint()..style = PaintingStyle.fill;

    // Stepped 45-degree diagonal blocks
    for (double y = 0; y < h; y += 4.0) {
      final x = (offset - y).roundToDouble();
      if (x >= -20 && x <= w + 20) {
        paint.color = Colors.white.withValues(alpha: 0.90);
        canvas.drawRect(Rect.fromLTWH(x, y, 6.0, 4.0), paint);

        paint.color = const Color(0xFFFFD54F).withValues(alpha: 0.60);
        canvas.drawRect(Rect.fromLTWH(x - 5.0, y, 4.0, 4.0), paint);
        canvas.drawRect(Rect.fromLTWH(x + 7.0, y, 4.0, 4.0), paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant PixelGleamPainter old) => old.progress != progress;
}

// ============================================================================
// MAIN WIDGET: LEGENDARY CHEST OVERLAY
// ============================================================================

class LegendaryChestOverlay extends StatefulWidget {
  final String title;
  final String subtitle;
  final Rarity rarity;
  final Widget rewardIcon;
  final VoidCallback? onClaimed;

  const LegendaryChestOverlay({
    super.key,
    required this.title,
    required this.subtitle,
    this.rarity = Rarity.legendary,
    required this.rewardIcon,
    this.onClaimed,
  });

  /// 1-Line static invocation helper to show this jackpot celebration anywhere!
  static Future<void> show(
    BuildContext context, {
    required String title,
    required String subtitle,
    Rarity rarity = Rarity.legendary,
    required Widget rewardIcon,
    VoidCallback? onClaimed,
  }) async {
    await showDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.transparent, // Handled inside overlay with #141020 85%
      builder: (_) => LegendaryChestOverlay(
        title: title,
        subtitle: subtitle,
        rarity: rarity,
        rewardIcon: rewardIcon,
        onClaimed: onClaimed,
      ),
    );
  }

  @override
  State<LegendaryChestOverlay> createState() => _LegendaryChestOverlayState();
}

class _LegendaryChestOverlayState extends State<LegendaryChestOverlay> with SingleTickerProviderStateMixin {
  late final ChestVfxController _controller;
  int _tapCount = 0; // 1st tap: Skip to Step 5, 2nd tap: Claim and close

  @override
  void initState() {
    super.initState();
    _controller = ChestVfxController(
      vsync: this,
      onStep2PillarErupt: () {
        if (mounted) setState(() {});
      },
      onStep5CardSlam: () {
        if (mounted) setState(() {});
      },
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _controller.startChoreography(
        originX: 160.0,
        originY: 420.0,
        activeColor: widget.rarity.primaryColor,
      );
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleScreenTap() {
    _tapCount++;
    if (_tapCount == 1 && !_controller.isRevealed) {
      // KRİTİK QoL: 1. dokunuş anında Adım 5'e atlar
      _controller.skipToReveal();
    } else if (_controller.isRevealed) {
      // 2. dokunuş ödülü toplayıp kapatır
      widget.onClaimed?.call();
      if (mounted) Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final activeColor = widget.rarity.primaryColor;

    return PopScope(
      canPop: false,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _handleScreenTap,
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, _) {
            final ms = _controller.timeline.value * 4200.0;
            final isStep1 = ms < 800.0;
            final isStep2 = ms >= 800.0 && ms < 1000.0;
            final isStep3 = ms >= 1000.0 && ms < 1200.0;
            final isStep4 = ms >= 1200.0 && ms < 3000.0;
            final isStep5 = ms >= 3000.0 || _controller.isRevealed;

            // Step 2 & 3: Screen shake ±8px integer snap
            final shakeMagnitude = (isStep2 || (isStep3 && ms < 1100.0)) ? 8.0 : 0.0;
            final shakeX = (shakeMagnitude > 0)
                ? (sin(ms * 0.05) * shakeMagnitude).roundToDouble()
                : 0.0;
            final shakeY = (shakeMagnitude > 0)
                ? (cos(ms * 0.04) * shakeMagnitude * 0.75).roundToDouble()
                : 0.0;

            return Transform.translate(
              offset: Offset(shakeX, shakeY),
              child: Scaffold(
                backgroundColor: const Color(0xD9141020), // Step 1: #141020 at 85% opacity
                body: Stack(
                  alignment: Alignment.center,
                  children: [
                    // Step 2: 2-Frame Pure White Flash
                    if (_controller.showWhiteFlash)
                      Positioned.fill(
                        child: Container(color: Colors.white),
                      ),

                    // Step 2: 3-Layered Stepped Pixel Light Pillar straight to top
                    if (ms >= 800.0 && ms < 3200.0 && !_controller.isRevealed)
                      Positioned(
                        top: 0,
                        bottom: screenSize.height * 0.22,
                        width: 220,
                        child: CustomPaint(
                          painter: SteppedLightPillarPainter(
                            progress: ((ms - 800.0) / 400.0).clamp(0.0, 1.0),
                            time: ms * 0.001,
                            activeColor: activeColor,
                          ),
                        ),
                      ),

                    // Step 3: 150+ Object-Pooled Pixel Loot Piñata Fountain
                    if (ms >= 1000.0)
                      Positioned.fill(
                        child: RepaintBoundary(
                          child: CustomPaint(
                            painter: ParticlePoolPainter(pool: _controller.particlePool),
                          ),
                        ),
                      ),

                    // Step 4: Stepped Pixel Square Shockwaves
                    if (isStep4)
                      Positioned.fill(
                        child: CustomPaint(
                          painter: SteppedPixelShockwavePainter(
                            progress: ((ms - 1200.0) / 1800.0).clamp(0.0, 1.0),
                            color: activeColor,
                          ),
                        ),
                      ),

                    // CHEST CONTAINER (Bottom-Center Placed)
                    if (!isStep5)
                      Positioned(
                        bottom: screenSize.height * 0.16,
                        child: _buildAnimatedChest(ms, isStep1, isStep2),
                      ),

                    // Step 4 & 5: Rare Item Ascent & Reveal Card
                    if (ms >= 1200.0)
                      _buildRewardPresentation(screenSize, ms, isStep4, isStep5, activeColor),

                    // QoL Fast Skip Prompt Badge
                    if (!isStep5)
                      Positioned(
                        top: 48,
                        right: 20,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.5),
                            border: Border.all(color: Colors.white30, width: 1.0),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                'GEÇ (DOKUN)',
                                style: TextStyle(
                                  color: Colors.white70,
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 0.6,
                                ),
                              ),
                              SizedBox(width: 4),
                              Icon(Icons.fast_forward_rounded, color: Colors.white70, size: 13),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildAnimatedChest(double ms, bool isStep1, bool isStep2) {
    double scaleX = 1.0;
    double scaleY = 1.0;
    double tremorX = 0.0;
    double openProgress = 0.0;

    if (isStep1) {
      if (_controller.isHitStop) {
        // Step 1: %25 Squash compression + 60ms Hit Stop
        scaleX = 1.25;
        scaleY = 0.75;
        tremorX = 0.0;
      } else {
        // Step 1: Escalating tremor ±2px -> ±4px -> ±6px
        final intensity = (ms / 800.0);
        final mag = (2.0 + intensity * 4.0).roundToDouble();
        tremorX = (sin(ms * 0.08) * mag).roundToDouble();
        scaleX = 1.0 + sin(ms * 0.04) * 0.05;
        scaleY = 1.0 - sin(ms * 0.04) * 0.05;
      }
    } else if (isStep2) {
      // Explosive upward snap on lid pop
      scaleX = 0.90;
      scaleY = 1.15;
      openProgress = ((ms - 800.0) / 200.0).clamp(0.0, 1.0);
    } else {
      openProgress = 1.0;
    }

    return Transform.translate(
      offset: Offset(tremorX, 0),
      child: Transform.scale(
        scaleX: scaleX,
        scaleY: scaleY,
        alignment: Alignment.bottomCenter,
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Leaking square gold pixels during Step 1
            if (isStep1)
              CustomPaint(
                size: const Size(160, 130),
                painter: _ChestPixelLeakPainter(progress: (ms / 800.0).clamp(0.0, 1.0)),
              ),
            ChestWidget(
              size: 132,
              primaryColor: widget.rarity.primaryColor,
              secondaryColor: const Color(0xFF5D4037),
              openProgress: openProgress,
              tier: widget.rarity,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRewardPresentation(
    Size screenSize,
    double ms,
    bool isStep4,
    bool isStep5,
    Color activeColor,
  ) {
    double translateY = 0.0;
    double scale = 1.0;

    if (isStep4 && !_controller.isRevealed) {
      // Step 4: Item floats slowly up center of light beam from chest mouth to center screen
      final p = ((ms - 1200.0) / 1800.0).clamp(0.0, 1.0);
      final smoothP = Curves.easeOutCubic.transform(p);
      translateY = (screenSize.height * 0.28 * (1.0 - smoothP)).roundToDouble();
      scale = 0.70 + 0.30 * smoothP;
    } else {
      // Step 5: ElasticOut slam of item card
      final p = _controller.isRevealed ? 1.0 : ((ms - 3000.0) / 600.0).clamp(0.0, 1.0);
      final elastic = Curves.elasticOut.transform(p);
      scale = 0.85 + 0.15 * elastic;
      translateY = 0.0;
    }

    return Positioned(
      child: Transform.translate(
        offset: Offset(0, translateY),
        child: Transform.scale(
          scale: scale,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Rotating 8-Bit Pixel Cross Stars (+) and (x)
              Stack(
                alignment: Alignment.center,
                children: [
                  CustomPaint(
                    size: const Size(140, 140),
                    painter: PixelCrossStarsPainter(
                      angle: ms * 0.003,
                      color: activeColor,
                    ),
                  ),

                  // Item Presentation Card
                  Container(
                    width: 136,
                    height: 136,
                    decoration: BoxDecoration(
                      color: const Color(0xFF0F1422),
                      border: Border.all(color: activeColor, width: 2.4),
                    ),
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        Center(child: widget.rewardIcon),

                        // Step 5: 45-degree Crisp Pixel Gleam
                        if (isStep5)
                          Positioned.fill(
                            child: CustomPaint(
                              painter: PixelGleamPainter(
                                progress: ((ms - 3000.0) / 800.0).clamp(0.0, 1.0),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // Rarity Tag
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                decoration: BoxDecoration(
                  color: activeColor.withValues(alpha: 0.20),
                  border: Border.all(color: activeColor, width: 1.5),
                ),
                child: Text(
                  widget.rarity.label.toUpperCase(),
                  style: TextStyle(
                    color: activeColor,
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.5,
                  ),
                ),
              ),

              const SizedBox(height: 10),

              // Title
              Text(
                widget.title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.6,
                ),
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 6),

              // Subtitle
              Text(
                widget.subtitle,
                style: const TextStyle(
                  color: Color(0xFFFFD54F),
                  fontSize: 13.5,
                  fontWeight: FontWeight.w700,
                ),
                textAlign: TextAlign.center,
              ),

              if (isStep5) ...[
                const SizedBox(height: 20),
                // Claim Button
                ElevatedButton(
                  onPressed: () {
                    widget.onClaimed?.call();
                    Navigator.of(context).pop();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: activeColor,
                    foregroundColor: const Color(0xFF141020),
                    shape: const BeveledRectangleBorder(),
                    padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                  ),
                  child: Text(
                    I18n.tr('claim_and_close').toUpperCase(),
                    style: const TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 13.5,
                      letterSpacing: 1.0,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
