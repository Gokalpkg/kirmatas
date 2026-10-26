import 'dart:math';
import 'package:flutter/material.dart';

/// The 3 distinct procedural aquarium plant species.
enum PlantSpecies {
  /// Tall ribbon-like eelgrass that flows towards the water surface.
  vallisneria,

  /// Stem plant with opposite oval leaves transitioning from green to ruby red tips.
  rotala,

  /// Broad-leafed, sturdy anubias with prominent veins and glossy waxy leaves.
  anubias,
}

/// A pearling oxygen bubble generated photosynthetically by aquarium plants.
class PlantOxygenBubble {
  double x;
  double y;
  double radius;
  double speed;
  double wobblePhase;
  double wobbleSpeed;
  double life = 0.0;
  final double maxRadius;

  /// True while the bubble is gently forming and swelling attached to the plant tip.
  bool isForming;
  double growTimer = 0.0;
  final double growDuration;
  final double anchorX;
  final double anchorY;

  PlantOxygenBubble({
    required this.x,
    required this.y,
    required double initialRadius,
    required this.maxRadius,
    required this.speed,
    required this.wobblePhase,
    this.wobbleSpeed = 4.5,
    this.isForming = false,
    this.growDuration = 2.8,
  })  : radius = initialRadius,
        anchorX = x,
        anchorY = y;

  bool update(double dt) {
    life += dt;

    if (isForming) {
      growTimer += dt;
      final t = (growTimer / growDuration).clamp(0.0, 1.0);
      // Soft organic ease-out growth curve: bubble gradually swells to its full target size
      final growEased = 1.0 - pow(1.0 - t, 2.0);
      radius = max(0.5, 0.6 + (maxRadius - 0.6) * growEased);
      // Delicate surface tension quiver on the leaf tip
      x = anchorX + sin(life * 3.2) * 0.35;
      y = anchorY + cos(life * 2.8) * 0.35;

      if (growTimer >= growDuration) {
        // Detaches from plant leaf and begins natural ascension
        isForming = false;
      }
      return false;
    }

    // Buoyant acceleration as it rises gently towards the surface
    y -= speed * dt;
    speed = min(speed + 5.0 * dt, 36.0);

    // Organic lateral wobble
    wobblePhase += wobbleSpeed * dt;
    x += sin(wobblePhase) * 11.0 * dt;

    // Slight expansion as water pressure decreases near surface
    if (radius < maxRadius) {
      radius = min(maxRadius, radius + 0.35 * dt);
    }

    // Returns true when bubble pops at or near the surface
    return y < 65.0;
  }
}

/// An individual blade of Vallisneria (ribbon grass).
class _VallisneriaBlade {
  final double length;
  final double lean;
  final double phaseOffset;
  final double width;
  final Color baseColor;
  final Color tipColor;
  double pearlingTimer = 0.0;

  _VallisneriaBlade({
    required this.length,
    required this.lean,
    required this.phaseOffset,
    required this.width,
    required this.baseColor,
    required this.tipColor,
  });
}

/// An individual stem of Rotala (stem plant with oval leaves).
class _RotalaStem {
  final double height;
  final double lean;
  final double phaseOffset;
  final int leafPairs;
  double pearlingTimer = 0.0;

  _RotalaStem({
    required this.height,
    required this.lean,
    required this.phaseOffset,
    required this.leafPairs,
  });
}

/// An individual broad leaf of Anubias.
class _AnubiasLeaf {
  final double angle;
  final double length;
  final double leafWidth;
  final double phaseOffset;
  double pearlingTimer = 0.0;
  double pearlingProgress = 0.0; // 0..1 swelling on leaf before release

  _AnubiasLeaf({
    required this.angle,
    required this.length,
    required this.leafWidth,
    required this.phaseOffset,
  });
}

/// A cluster of aquarium plants rooted in the sand.
class AquariumPlant {
  final PlantSpecies species;
  final double baseX;
  final double baseY;
  final bool isForeground;
  final double scale;

  final List<_VallisneriaBlade> _vallisBlades = [];
  final List<_RotalaStem> _rotalaStems = [];
  final List<_AnubiasLeaf> _anubiasLeaves = [];

  final Random _rand;
  double _plantPearlCooldown = 0.0;

  AquariumPlant({
    required this.species,
    required this.baseX,
    required this.baseY,
    this.isForeground = false,
    this.scale = 1.0,
    int? seed,
  }) : _rand = Random(seed ?? (baseX * 100 + baseY).toInt()) {
    _plantPearlCooldown = 1.0 + _rand.nextDouble() * 2.0;
    _initPlantStructure();
  }

  void _initPlantStructure() {
    switch (species) {
      case PlantSpecies.vallisneria:
        final bladeCount = 5 + _rand.nextInt(3);
        for (int i = 0; i < bladeCount; i++) {
          final len = (160.0 + _rand.nextDouble() * 120.0) * scale;
          final lean = (i - bladeCount / 2.0) * 8.0 + (_rand.nextDouble() * 6.0 - 3.0);
          final phase = _rand.nextDouble() * pi * 2;
          final w = (4.0 + _rand.nextDouble() * 2.2) * scale;
          final bColor = Color.lerp(
            const Color(0xFF2E7D32),
            const Color(0xFF388E3C),
            _rand.nextDouble(),
          )!;
          final tColor = Color.lerp(
            const Color(0xFF66BB6A),
            const Color(0xFF81C784),
            _rand.nextDouble(),
          )!;
          final blade = _VallisneriaBlade(
            length: len,
            lean: lean,
            phaseOffset: phase,
            width: w,
            baseColor: bColor,
            tipColor: tColor,
          );
          blade.pearlingTimer = 1.0 + _rand.nextDouble() * 4.0;
          _vallisBlades.add(blade);
        }
        break;

      case PlantSpecies.rotala:
        final stemCount = 3 + _rand.nextInt(2);
        for (int i = 0; i < stemCount; i++) {
          final h = (110.0 + _rand.nextDouble() * 70.0) * scale;
          final lean = (i - stemCount / 2.0) * 11.0 + (_rand.nextDouble() * 6.0 - 3.0);
          final phase = _rand.nextDouble() * pi * 2;
          final pairs = 5 + _rand.nextInt(4);
          final stem = _RotalaStem(
            height: h,
            lean: lean,
            phaseOffset: phase,
            leafPairs: pairs,
          );
          stem.pearlingTimer = 1.5 + _rand.nextDouble() * 3.5;
          _rotalaStems.add(stem);
        }
        break;

      case PlantSpecies.anubias:
        final leafCount = 6 + _rand.nextInt(3);
        for (int i = 0; i < leafCount; i++) {
          final spread = (i / (leafCount - 1.0) - 0.5) * 1.6;
          final angle = -pi / 2.0 + spread * 0.85 + (_rand.nextDouble() * 0.2 - 0.1);
          final len = (42.0 + _rand.nextDouble() * 30.0) * scale;
          final w = (18.0 + _rand.nextDouble() * 9.0) * scale;
          final phase = _rand.nextDouble() * pi * 2;
          final leaf = _AnubiasLeaf(
            angle: angle,
            length: len,
            leafWidth: w,
            phaseOffset: phase,
          );
          leaf.pearlingTimer = 2.0 + _rand.nextDouble() * 4.5;
          _anubiasLeaves.add(leaf);
        }
        break;
    }
  }

  /// Updates photosynthesis timer and gently emits oxygen pearls one tip at a time.
  void update(
    double dt,
    double time, {
    required void Function(double x, double y, double radius) onEmitOxygen,
  }) {
    _plantPearlCooldown -= dt;
    if (_plantPearlCooldown > 0) return;

    _plantPearlCooldown = 4.0 + _rand.nextDouble() * 3.5;

    switch (species) {
      case PlantSpecies.vallisneria:
        if (_vallisBlades.isEmpty) return;
        final blade = _vallisBlades[_rand.nextInt(_vallisBlades.length)];
        final sway = sin(time * 1.2 + blade.phaseOffset) * 16.0;
        final tipX = baseX + blade.lean * 1.6 + sway;
        final tipY = baseY - blade.length * 0.92;
        final r = 1.8 + _rand.nextDouble() * 1.4;
        onEmitOxygen(tipX, tipY, r);
        break;

      case PlantSpecies.rotala:
        if (_rotalaStems.isEmpty) return;
        final stem = _rotalaStems[_rand.nextInt(_rotalaStems.length)];
        final sway = sin(time * 1.4 + stem.phaseOffset) * 11.0;
        final tipX = baseX + stem.lean * 1.2 + sway;
        final tipY = baseY - stem.height;
        final r = 1.6 + _rand.nextDouble() * 1.4;
        onEmitOxygen(tipX, tipY, r);
        break;

      case PlantSpecies.anubias:
        if (_anubiasLeaves.isEmpty) return;
        final leaf = _anubiasLeaves[_rand.nextInt(_anubiasLeaves.length)];
        final sway = sin(time * 0.9 + leaf.phaseOffset) * 0.08;
        final rad = leaf.angle + sway;
        final tipX = baseX + cos(rad) * leaf.length * 0.85;
        final tipY = baseY + sin(rad) * leaf.length * 0.85;
        final r = 1.9 + _rand.nextDouble() * 1.6;
        onEmitOxygen(tipX, tipY, r);
        break;
    }
  }

  /// Paints the plant species with lush procedural shaders and organic curvature.
  void paint(Canvas canvas, double time) {
    switch (species) {
      case PlantSpecies.vallisneria:
        _paintVallisneria(canvas, time);
        break;
      case PlantSpecies.rotala:
        _paintRotala(canvas, time);
        break;
      case PlantSpecies.anubias:
        _paintAnubias(canvas, time);
        break;
    }
  }

  // --- Vallisneria (Tall ribbon grass with curling tips & veins) ---
  void _paintVallisneria(Canvas canvas, double time) {
    final bladePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final veinPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..color = const Color(0x55E8F5E9)
      ..strokeWidth = 1.0;

    final path = Path();

    for (final blade in _vallisBlades) {
      final sway1 = sin(time * 1.1 + blade.phaseOffset) * 14.0;
      final sway2 = sin(time * 1.5 + blade.phaseOffset + 1.0) * 22.0;

      final p0 = Offset(baseX, baseY);
      final p1 = Offset(baseX + blade.lean * 0.4 + sway1 * 0.4, baseY - blade.length * 0.38);
      final p2 = Offset(baseX + blade.lean * 0.9 + sway1, baseY - blade.length * 0.72);
      final p3 = Offset(baseX + blade.lean * 1.5 + sway2, baseY - blade.length);

      path.reset();
      path.moveTo(p0.dx, p0.dy);
      path.cubicTo(p1.dx, p1.dy, p2.dx, p2.dy, p3.dx, p3.dy);

      // Gradient along the blade
      bladePaint.strokeWidth = blade.width;
      bladePaint.shader = LinearGradient(
        begin: Alignment.bottomCenter,
        end: Alignment.topCenter,
        colors: [
          blade.baseColor.withValues(alpha: 0.88),
          blade.tipColor.withValues(alpha: 0.75),
          const Color(0x99C8E6C9),
        ],
        stops: const [0.0, 0.75, 1.0],
      ).createShader(Rect.fromPoints(p0, p3));

      canvas.drawPath(path, bladePaint);
      bladePaint.shader = null;

      // Longitudinal center vein
      canvas.drawPath(path, veinPaint);
    }
  }

  // --- Rotala (Stem plant: green base -> vibrant ruby-coral crown) ---
  void _paintRotala(Canvas canvas, double time) {
    final stemPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final leafFill = Paint()..style = PaintingStyle.fill;
    final leafStroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8;

    final stemPath = Path();

    for (final stem in _rotalaStems) {
      final sway = sin(time * 1.3 + stem.phaseOffset) * 12.0;
      final p0 = Offset(baseX, baseY);
      final p1 = Offset(baseX + stem.lean * 0.5 + sway * 0.4, baseY - stem.height * 0.5);
      final p2 = Offset(baseX + stem.lean + sway, baseY - stem.height);

      stemPath.reset();
      stemPath.moveTo(p0.dx, p0.dy);
      stemPath.quadraticBezierTo(p1.dx, p1.dy, p2.dx, p2.dy);

      // Stem shader: green at bottom -> amber/coral at top
      stemPaint.strokeWidth = 2.4 * scale;
      stemPaint.shader = const LinearGradient(
        begin: Alignment.bottomCenter,
        end: Alignment.topCenter,
        colors: [Color(0xFF388E3C), Color(0xFF81C784), Color(0xFFFF7043)],
        stops: [0.0, 0.55, 1.0],
      ).createShader(Rect.fromPoints(p0, p2));

      canvas.drawPath(stemPath, stemPaint);
      stemPaint.shader = null;

      // Draw opposite leaf pairs along the stem
      for (int i = 0; i < stem.leafPairs; i++) {
        final t = (i + 1) / (stem.leafPairs + 1.0);
        // Position along quadratic curve
        final lx = (1 - t) * (1 - t) * p0.dx + 2 * (1 - t) * t * p1.dx + t * t * p2.dx;
        final ly = (1 - t) * (1 - t) * p0.dy + 2 * (1 - t) * t * p1.dy + t * t * p2.dy;

        // Tangent angle
        final dx = 2 * (1 - t) * (p1.dx - p0.dx) + 2 * t * (p2.dx - p1.dx);
        final dy = 2 * (1 - t) * (p1.dy - p0.dy) + 2 * t * (p2.dy - p1.dy);
        final stemAngle = atan2(dy, dx);

        // Color transition: lower leaves green, upper leaves ruby/coral
        final leafColor = Color.lerp(
          const Color(0xFF43A047),
          const Color(0xFFE53935),
          pow(t, 1.3).toDouble(),
        )!;
        final leafRimColor = Color.lerp(
          const Color(0xFF81C784),
          const Color(0xFFFFAB91),
          pow(t, 1.3).toDouble(),
        )!;

        leafFill.color = leafColor.withValues(alpha: 0.90);
        leafStroke.color = leafRimColor.withValues(alpha: 0.85);

        final leafSize = (8.0 + t * 4.0) * scale;
        final leafW = (4.0 + t * 2.2) * scale;

        for (final sign in [-1.0, 1.0]) {
          final leafAngle = stemAngle + sign * (pi / 2.4) + sin(time * 2.0 + i) * 0.1;
          canvas.save();
          canvas.translate(lx, ly);
          canvas.rotate(leafAngle);

          final ovalRect = Rect.fromLTWH(0, -leafW / 2, leafSize, leafW);
          canvas.drawOval(ovalRect, leafFill);
          canvas.drawOval(ovalRect, leafStroke);
          canvas.restore();
        }
      }
    }
  }

  // --- Anubias Nana (Broad waxy leaves with midrib & lateral veins) ---
  void _paintAnubias(Canvas canvas, double time) {
    final petiolePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0 * scale
      ..strokeCap = StrokeCap.round
      ..color = const Color(0xFF1B5E20);

    final leafFill = Paint()..style = PaintingStyle.fill;
    final leafBorder = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0
      ..color = const Color(0xFF43A047);
    final veinPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.9
      ..color = const Color(0x66C8E6C9);

    final leafPath = Path();

    // Rhizome / Root anchor cluster at the base
    final rhizomePaint = Paint()..color = const Color(0xFF1B3B1D);
    canvas.drawOval(
      Rect.fromCenter(center: Offset(baseX, baseY + 2), width: 28 * scale, height: 11 * scale),
      rhizomePaint,
    );

    for (final leaf in _anubiasLeaves) {
      final sway = sin(time * 0.85 + leaf.phaseOffset) * 0.06;
      final curAngle = leaf.angle + sway;

      final petioleLen = leaf.length * 0.42;
      final stemEndX = baseX + cos(curAngle) * petioleLen;
      final stemEndY = baseY + sin(curAngle) * petioleLen;

      // Draw sturdy petiole stem
      canvas.drawLine(Offset(baseX, baseY), Offset(stemEndX, stemEndY), petiolePaint);

      // Draw wide ovate leaf blade attached to petiole
      final bladeLen = leaf.length * 0.68;
      final bladeW = leaf.leafWidth;

      canvas.save();
      canvas.translate(stemEndX, stemEndY);
      canvas.rotate(curAngle);

      leafPath.reset();
      leafPath.moveTo(0, 0);
      leafPath.cubicTo(
        bladeLen * 0.28, -bladeW * 0.65,
        bladeLen * 0.75, -bladeW * 0.55,
        bladeLen, 0,
      );
      leafPath.cubicTo(
        bladeLen * 0.75, bladeW * 0.55,
        bladeLen * 0.28, bladeW * 0.65,
        0, 0,
      );
      leafPath.close();

      // Deep waxy green gradient with specular surface sheen
      leafFill.shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: const [
          Color(0xFF2E7D32),
          Color(0xFF1B5E20),
          Color(0xFF0F3813),
        ],
      ).createShader(Rect.fromLTWH(0, -bladeW / 2, bladeLen, bladeW));

      canvas.drawPath(leafPath, leafFill);
      leafFill.shader = null;
      canvas.drawPath(leafPath, leafBorder);

      // Prominent center midrib
      canvas.drawLine(Offset.zero, Offset(bladeLen * 0.92, 0), veinPaint);

      // Curved lateral veins branching from midrib
      const veinPairs = 4;
      for (int v = 1; v <= veinPairs; v++) {
        final vx = bladeLen * (v / (veinPairs + 1.2));
        final vy = bladeW * 0.38 * (1.0 - (v / (veinPairs + 1.5)));
        canvas.drawLine(Offset(vx, 0), Offset(vx + 5, -vy), veinPaint);
        canvas.drawLine(Offset(vx, 0), Offset(vx + 5, vy), veinPaint);
      }

      // Specular wax highlight
      final highlightPaint = Paint()
        ..color = const Color(0x33FFFFFF)
        ..style = PaintingStyle.fill;
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(bladeLen * 0.48, -bladeW * 0.18),
          width: bladeLen * 0.45,
          height: bladeW * 0.22,
        ),
        highlightPaint,
      );

      canvas.restore();
    }
  }
}

/// Paints the pearling oxygen bubbles with realistic gleam & glass reflections.
class PlantOxygenPainter {
  PlantOxygenPainter._();

  static final Paint _outerGlow = Paint()
    ..style = PaintingStyle.fill
    ..color = const Color(0x5580D8FF);

  static final Paint _bubbleRim = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1.0
    ..color = const Color(0xCCB3E5FC);

  static final Paint _bubbleCore = Paint()
    ..style = PaintingStyle.fill
    ..color = const Color(0x22FFFFFF);

  static final Paint _specularHighlight = Paint()
    ..style = PaintingStyle.fill
    ..color = const Color(0xEEFFFFFF);

  static void paintBubble(Canvas canvas, PlantOxygenBubble b) {
    final center = Offset(b.x, b.y);

    // 1. Soft atmospheric water glow
    canvas.drawCircle(center, b.radius + 1.4, _outerGlow);

    // 2. Translucent oxygen sphere
    canvas.drawCircle(center, b.radius, _bubbleCore);

    // 3. Crisp refractive rim
    canvas.drawCircle(center, b.radius, _bubbleRim);

    // 4. Crescent specular gleam in upper-left corner
    final hlRadius = max(0.6, b.radius * 0.32);
    final hlOffset = Offset(center.dx - b.radius * 0.35, center.dy - b.radius * 0.35);
    canvas.drawCircle(hlOffset, hlRadius, _specularHighlight);
  }
}
