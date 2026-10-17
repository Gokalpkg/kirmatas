import 'dart:math';
import 'package:flutter/material.dart';
import '../models/cosmetics.dart';

/// Highly detailed, authentic Neo-Vault Treasure Chest widget.
/// Implements 4 distinct, handcrafted 3D depth architectural tiers:
/// - Normal / Sıradan: Matte dark basalt stone, forged raw iron straps, ember core keyhole, 5px bottom bevel shadow.
/// - Rare / Nadir: Deep oceanic jade-obsidian, forged bronze-teal bands, raw aquamarine crystal shard lock.
/// - Epic / Destansı: Midnight violet obsidian, forged violet-gold filigree armor, 4-claw amethyst gem.
/// - Legendary / Efsanevi: Celestial forged 24k sun-gold leaf armor, 3D stepped bevels, royal crown filigree handle, star-cut solar crystal.
class ChestWidget extends StatelessWidget {
  final double size;
  final Color primaryColor;
  final Color secondaryColor;
  final bool isOpened;
  final double openProgress; // 0.0 (closed) to 1.0 (fully open)
  final bool showGlow;
  final double time;
  final Rarity? tier;

  const ChestWidget({
    super.key,
    this.size = 64,
    this.primaryColor = const Color(0xFFFFD54F),
    this.secondaryColor = const Color(0xFF5D4037),
    this.isOpened = false,
    this.openProgress = 0.0,
    this.showGlow = true,
    this.time = 0.0,
    this.tier,
  });

  /// Intelligently infers rarity tier from primary color when tier is unspecified.
  static Rarity inferTier(Color color) {
    final hsl = HSLColor.fromColor(color);
    final h = hsl.hue;
    final s = hsl.saturation;

    if (s < 0.20) {
      return Rarity.common;
    }
    if (h >= 160 && h <= 220) {
      return Rarity.rare;
    }
    if (h >= 240 && h <= 345) {
      return Rarity.epic;
    }
    if (h >= 30 && h <= 65) {
      return Rarity.legendary;
    }
    if (h < 30) {
      return Rarity.common;
    }
    return Rarity.common;
  }

  @override
  Widget build(BuildContext context) {
    final effectiveTier = tier ?? inferTier(primaryColor);
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _ChestPainter(
          primaryColor: primaryColor,
          secondaryColor: secondaryColor,
          isOpened: isOpened,
          openProgress: openProgress,
          showGlow: showGlow,
          time: time,
          tier: effectiveTier,
        ),
      ),
    );
  }
}

class _ChestPainter extends CustomPainter {
  final Color primaryColor;
  final Color secondaryColor;
  final bool isOpened;
  final double openProgress;
  final bool showGlow;
  final double time;
  final Rarity tier;

  _ChestPainter({
    required this.primaryColor,
    required this.secondaryColor,
    required this.isOpened,
    required this.openProgress,
    required this.showGlow,
    required this.tier,
    this.time = 0.0,
  });

  Color get _tierAccentColor {
    switch (tier) {
      case Rarity.common:
        return const Color(0xFFFF9800); // Warm ember core
      case Rarity.rare:
        return const Color(0xFF00E5FF); // Aquatic cyan crystal
      case Rarity.epic:
        return const Color(0xFFE040FB); // Astral amethyst
      case Rarity.legendary:
        return const Color(0xFFFFD54F); // 24k Sun gold
    }
  }

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final effectiveOpen = isOpened ? 1.0 : openProgress.clamp(0.0, 1.18);
    final pulse = 0.92 + 0.08 * sin(time * 2.8);
    final accent = _tierAccentColor;

    // -------------------------------------------------------------
    // 0. AMBIENT GLOW / OUTER BLOOM
    // -------------------------------------------------------------
    if (showGlow) {
      final glowPaint = Paint()
        ..color = accent.withValues(alpha: (0.22 + effectiveOpen * 0.20) * pulse)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, w * (0.16 + effectiveOpen * 0.10));
      canvas.drawCircle(Offset(w * 0.5, h * 0.52), w * 0.44, glowPaint);
    }

    // Ground Drop Shadow
    final shadowPaint = Paint()..color = const Color(0x99000000);
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(w * 0.5, h * 0.90),
        width: w * 0.86,
        height: h * 0.20,
      ),
      shadowPaint,
    );

    // Volumetric God-Rays bursting from inside when chest opens
    if (effectiveOpen > 0.04) {
      _drawVolumetricRays(canvas, w, h, effectiveOpen, pulse, accent);
    }

    // -------------------------------------------------------------
    // 1. CHEST BASE (LOWER CHASSIS & 3 PLANKS WITH 3D DEPTH)
    // -------------------------------------------------------------
    final baseRect = Rect.fromLTWH(w * 0.14, h * 0.44, w * 0.72, h * 0.42);
    final baseRRect = RRect.fromRectAndCorners(
      baseRect,
      bottomLeft: Radius.circular(w * 0.09),
      bottomRight: Radius.circular(w * 0.09),
    );

    // Physical 3D Bottom Bevel Shadow Lip (Extruded chassis depth)
    final bevelDepth = max(3.5, w * 0.048);
    final bevelColor = switch (tier) {
      Rarity.common => const Color(0xFF020308),
      Rarity.rare => const Color(0xFF031014),
      Rarity.epic => const Color(0xFF07020E),
      Rarity.legendary => const Color(0xFF381403),
    };
    final bevelRect = Rect.fromLTWH(w * 0.14, h * 0.44 + bevelDepth, w * 0.72, h * 0.42);
    final bevelRRect = RRect.fromRectAndCorners(
      bevelRect,
      bottomLeft: Radius.circular(w * 0.09),
      bottomRight: Radius.circular(w * 0.09),
    );
    canvas.drawRRect(bevelRRect, Paint()..color = bevelColor);

    // Tier-specific Plank Shading
    _drawBasePlanks(canvas, baseRect, baseRRect, w, h, pulse);

    // Inside chest cavity glow when open
    if (effectiveOpen > 0.05) {
      final innerRect = Rect.fromLTWH(w * 0.16, h * 0.44, w * 0.68, h * 0.18 * effectiveOpen);
      canvas.drawRect(innerRect, Paint()..color = const Color(0xFF060810));

      final innerGlowPaint = Paint()
        ..shader = RadialGradient(
          colors: [
            Colors.white,
            accent,
            accent.withValues(alpha: 0.0),
          ],
          stops: const [0.0, 0.45, 1.0],
        ).createShader(Rect.fromCenter(
          center: Offset(w * 0.5, h * 0.46),
          width: w * 0.64,
          height: h * 0.26,
        ));
      canvas.drawRect(innerRect, innerGlowPaint);
    }

    // -------------------------------------------------------------
    // 2. METAL REINFORCING BANDS & CORNER BRACKETS (BASE)
    // -------------------------------------------------------------
    _drawArmorBands(canvas, baseRect, w, h, pulse);

    // -------------------------------------------------------------
    // 3. ARCHED DOMED LID (Kavisli Kubbe Kapak)
    // -------------------------------------------------------------
    _drawDomedLid(canvas, w, h, effectiveOpen, pulse);

    // -------------------------------------------------------------
    // 4. FRONT LOCK & REACTOR CLASP (Centerpiece)
    // -------------------------------------------------------------
    _drawLockClasp(canvas, w, h, pulse);
  }

  void _drawBasePlanks(Canvas canvas, Rect baseRect, RRect baseRRect, double w, double h, double pulse) {
    switch (tier) {
      case Rarity.common:
        // Matte dark basalt stone slabs
        final basaltGrad = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xFF1E2333),
            Color(0xFF141724),
            Color(0xFF0C0E17),
          ],
          stops: [0.0, 0.55, 1.0],
        );
        canvas.drawRRect(baseRRect, Paint()..shader = basaltGrad.createShader(baseRect));

        // 3 chiseled basalt slabs with deep seam bevels
        final seamPaint = Paint()
          ..color = const Color(0xFF04060A)
          ..strokeWidth = max(1.4, w * 0.020);
        canvas.drawLine(Offset(w * 0.38, h * 0.44), Offset(w * 0.38, h * 0.84), seamPaint);
        canvas.drawLine(Offset(w * 0.62, h * 0.44), Offset(w * 0.62, h * 0.84), seamPaint);

        // Chiseled stone highlight seam lines
        final grainPaint = Paint()
          ..color = Colors.white.withValues(alpha: 0.12)
          ..strokeWidth = max(0.8, w * 0.010);
        canvas.drawLine(Offset(w * 0.395, h * 0.44), Offset(w * 0.395, h * 0.84), grainPaint);
        canvas.drawLine(Offset(w * 0.635, h * 0.44), Offset(w * 0.635, h * 0.84), grainPaint);
        break;

      case Rarity.rare:
        // Deep oceanic jade-obsidian with crystalline refraction veins
        final jadeGrad = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xFF0F2E36),
            Color(0xFF0A1E24),
            Color(0xFF040F13),
          ],
          stops: [0.0, 0.55, 1.0],
        );
        canvas.drawRRect(baseRRect, Paint()..shader = jadeGrad.createShader(baseRect));

        // Deep seam grooves
        final seamPaint = Paint()
          ..color = const Color(0xFF02090C)
          ..strokeWidth = max(1.4, w * 0.020);
        canvas.drawLine(Offset(w * 0.38, h * 0.44), Offset(w * 0.38, h * 0.84), seamPaint);
        canvas.drawLine(Offset(w * 0.62, h * 0.44), Offset(w * 0.62, h * 0.84), seamPaint);

        // Translucent aquamarine crystalline refraction veins
        final veinPaint = Paint()
          ..color = const Color(0xFF00E5FF).withValues(alpha: 0.28)
          ..strokeWidth = max(0.9, w * 0.012);
        canvas.drawLine(Offset(w * 0.27, h * 0.48), Offset(w * 0.35, h * 0.78), veinPaint);
        canvas.drawLine(Offset(w * 0.50, h * 0.50), Offset(w * 0.56, h * 0.80), veinPaint);
        canvas.drawLine(Offset(w * 0.65, h * 0.46), Offset(w * 0.72, h * 0.76), veinPaint);
        break;

      case Rarity.epic:
        // Glossy midnight violet obsidian slabs with specular highlights
        final epicGrad = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF281340),
            Color(0xFF180B28),
            Color(0xFF090312),
          ],
          stops: [0.0, 0.50, 1.0],
        );
        canvas.drawRRect(baseRRect, Paint()..shader = epicGrad.createShader(baseRect));

        // Deep seam grooves
        final seamPaint = Paint()
          ..color = const Color(0xFF05010A)
          ..strokeWidth = max(1.4, w * 0.020);
        canvas.drawLine(Offset(w * 0.38, h * 0.44), Offset(w * 0.38, h * 0.84), seamPaint);
        canvas.drawLine(Offset(w * 0.62, h * 0.44), Offset(w * 0.62, h * 0.84), seamPaint);

        // Specular purple nebula rim highlight
        final rimPaint = Paint()
          ..color = const Color(0xFFE040FB).withValues(alpha: 0.35 * pulse)
          ..strokeWidth = max(0.9, w * 0.012);
        canvas.drawLine(Offset(w * 0.395, h * 0.44), Offset(w * 0.395, h * 0.84), rimPaint);
        canvas.drawLine(Offset(w * 0.635, h * 0.44), Offset(w * 0.635, h * 0.84), rimPaint);

        // Diagonal mirror specular highlight across obsidian slab
        final mirrorPaint = Paint()
          ..shader = LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.white.withValues(alpha: 0.18),
              Colors.transparent,
            ],
            stops: const [0.0, 0.45],
          ).createShader(baseRect);
        canvas.drawRRect(baseRRect, mirrorPaint);
        break;

      case Rarity.legendary:
        // Deep carved obsidian chassis bordered by warm terracotta-amber underglow
        final goldBaseGrad = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xFF2E190E),
            Color(0xFF1C0D05),
            Color(0xFF0B0401),
          ],
          stops: [0.0, 0.50, 1.0],
        );
        canvas.drawRRect(baseRRect, Paint()..shader = goldBaseGrad.createShader(baseRect));

        // Warm terracotta-amber underglow along bottom seam
        final underglowPaint = Paint()
          ..shader = RadialGradient(
            center: const Alignment(0.0, 0.9),
            radius: 0.8,
            colors: [
              const Color(0xFFFFB300).withValues(alpha: 0.45 * pulse),
              Colors.transparent,
            ],
          ).createShader(baseRect);
        canvas.drawRRect(baseRRect, underglowPaint);

        // Seams
        final seamPaint = Paint()
          ..color = const Color(0xFF050200)
          ..strokeWidth = max(1.4, w * 0.020);
        canvas.drawLine(Offset(w * 0.38, h * 0.44), Offset(w * 0.38, h * 0.84), seamPaint);
        canvas.drawLine(Offset(w * 0.62, h * 0.44), Offset(w * 0.62, h * 0.84), seamPaint);

        // 24k gold leaf seam reflection
        final goldSeamPaint = Paint()
          ..color = const Color(0xFFFFD54F).withValues(alpha: 0.45)
          ..strokeWidth = max(0.9, w * 0.012);
        canvas.drawLine(Offset(w * 0.395, h * 0.44), Offset(w * 0.395, h * 0.84), goldSeamPaint);
        canvas.drawLine(Offset(w * 0.635, h * 0.44), Offset(w * 0.635, h * 0.84), goldSeamPaint);
        break;
    }
  }

  void _drawArmorBands(Canvas canvas, Rect baseRect, double w, double h, double pulse) {
    // Generate tier-specific band shader
    final Shader bandShader;
    switch (tier) {
      case Rarity.common:
        // Forged raw iron bands
        bandShader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF607D8B),
            Color(0xFF455A64),
            Color(0xFF263238),
          ],
          stops: [0.0, 0.50, 1.0],
        ).createShader(baseRect);
        break;

      case Rarity.rare:
        // Forged antique bronze-teal bands
        bandShader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF00E5FF),
            Color(0xFF00B4D8),
            Color(0xFF0077B6),
            Color(0xFF023E8A),
          ],
          stops: [0.0, 0.35, 0.70, 1.0],
        ).createShader(baseRect);
        break;

      case Rarity.epic:
        // Forged violet-gold filigree armor
        bandShader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFFE040FB),
            Color(0xFFAB47BC),
            Color(0xFF7B1FA2),
            Color(0xFF4A148C),
          ],
          stops: [0.0, 0.30, 0.65, 1.0],
        ).createShader(baseRect);
        break;

      case Rarity.legendary:
        // Celestial forged 24k sun-gold leaf armor
        bandShader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFFFFF9E6),
            Color(0xFFFFE082),
            Color(0xFFFFB300),
            Color(0xFFB78103),
            Color(0xFF451A03),
          ],
          stops: [0.0, 0.25, 0.55, 0.82, 1.0],
        ).createShader(baseRect);
        break;
    }

    final bandPaint = Paint()..shader = bandShader;

    // Physical 3D Stepped Bevel for armor bands (especially prominent on Legendary & Epic)
    if (tier == Rarity.legendary || tier == Rarity.epic) {
      final bevelShadowPaint = Paint()..color = const Color(0xFF050302);
      canvas.drawRRect(
        RRect.fromRectAndCorners(
          Rect.fromLTWH(w * 0.135, h * 0.44 + 1.5, w * 0.12, h * 0.42),
          bottomLeft: Radius.circular(w * 0.09),
        ),
        bevelShadowPaint,
      );
      canvas.drawRRect(
        RRect.fromRectAndCorners(
          Rect.fromLTWH(w * 0.745, h * 0.44 + 1.5, w * 0.12, h * 0.42),
          bottomRight: Radius.circular(w * 0.09),
        ),
        bevelShadowPaint,
      );
      canvas.drawRect(
        Rect.fromLTWH(w * 0.435, h * 0.44 + 1.5, w * 0.13, h * 0.42),
        bevelShadowPaint,
      );
    }

    // Left vertical metal armor strap
    canvas.drawRRect(
      RRect.fromRectAndCorners(
        Rect.fromLTWH(w * 0.14, h * 0.44, w * 0.11, h * 0.42),
        bottomLeft: Radius.circular(w * 0.09),
      ),
      bandPaint,
    );

    // Right vertical metal armor strap
    canvas.drawRRect(
      RRect.fromRectAndCorners(
        Rect.fromLTWH(w * 0.75, h * 0.44, w * 0.11, h * 0.42),
        bottomRight: Radius.circular(w * 0.09),
      ),
      bandPaint,
    );

    // Center vertical strap on base
    canvas.drawRect(
      Rect.fromLTWH(w * 0.44, h * 0.44, w * 0.12, h * 0.42),
      bandPaint,
    );

    // Bottom horizontal base trim
    canvas.drawRRect(
      RRect.fromRectAndCorners(
        Rect.fromLTWH(w * 0.14, h * 0.81, w * 0.72, h * 0.05),
        bottomLeft: Radius.circular(w * 0.09),
        bottomRight: Radius.circular(w * 0.09),
      ),
      bandPaint,
    );

    // Golden Filigree Edging on Epic Armor Straps
    if (tier == Rarity.epic) {
      final filigreePaint = Paint()
        ..color = const Color(0xFFFFD54F).withValues(alpha: 0.85)
        ..strokeWidth = max(0.8, w * 0.010)
        ..style = PaintingStyle.stroke;
      canvas.drawLine(Offset(w * 0.14, h * 0.44), Offset(w * 0.14, h * 0.81), filigreePaint);
      canvas.drawLine(Offset(w * 0.25, h * 0.44), Offset(w * 0.25, h * 0.81), filigreePaint);
      canvas.drawLine(Offset(w * 0.75, h * 0.44), Offset(w * 0.75, h * 0.81), filigreePaint);
      canvas.drawLine(Offset(w * 0.86, h * 0.44), Offset(w * 0.86, h * 0.81), filigreePaint);
      canvas.drawLine(Offset(w * 0.44, h * 0.44), Offset(w * 0.44, h * 0.81), filigreePaint);
      canvas.drawLine(Offset(w * 0.56, h * 0.44), Offset(w * 0.56, h * 0.81), filigreePaint);
    }

    // 24k Stepped Bevel Highlight on Legendary Straps
    if (tier == Rarity.legendary) {
      final goldRimPaint = Paint()
        ..color = const Color(0xFFFFF9E6).withValues(alpha: 0.90)
        ..strokeWidth = max(1.0, w * 0.014)
        ..style = PaintingStyle.stroke;
      canvas.drawLine(Offset(w * 0.15, h * 0.44), Offset(w * 0.15, h * 0.81), goldRimPaint);
      canvas.drawLine(Offset(w * 0.76, h * 0.44), Offset(w * 0.76, h * 0.81), goldRimPaint);
      canvas.drawLine(Offset(w * 0.45, h * 0.44), Offset(w * 0.45, h * 0.81), goldRimPaint);
    }

    // Base Rivets (Tier-themed craftsmanship)
    final rivetR = max(1.4, w * 0.024);
    final Paint rivetBasePaint;
    final Paint rivetCorePaint;
    final Paint rivetGlintPaint = Paint()..color = Colors.white;

    switch (tier) {
      case Rarity.common:
        rivetBasePaint = Paint()..color = const Color(0xFF1A2126);
        rivetCorePaint = Paint()..color = const Color(0xFF78909C);
        break;
      case Rarity.rare:
        rivetBasePaint = Paint()..color = const Color(0xFF004D40);
        rivetCorePaint = Paint()..color = const Color(0xFF00E5FF);
        break;
      case Rarity.epic:
        rivetBasePaint = Paint()..color = const Color(0xFF311B92);
        rivetCorePaint = Paint()..color = const Color(0xFFE040FB);
        break;
      case Rarity.legendary:
        rivetBasePaint = Paint()..color = const Color(0xFF451A03);
        rivetCorePaint = Paint()..color = const Color(0xFFFFD54F);
        break;
    }

    final baseRivets = [
      Offset(w * 0.195, h * 0.51),
      Offset(w * 0.195, h * 0.72),
      Offset(w * 0.805, h * 0.51),
      Offset(w * 0.805, h * 0.72),
      Offset(w * 0.500, h * 0.73),
    ];
    for (final pos in baseRivets) {
      canvas.drawCircle(pos, rivetR, rivetBasePaint);
      canvas.drawCircle(pos, rivetR * 0.65, rivetCorePaint);
      canvas.drawCircle(Offset(pos.dx - rivetR * 0.32, pos.dy - rivetR * 0.32), rivetR * 0.35, rivetGlintPaint);
    }
  }

  void _drawDomedLid(Canvas canvas, double w, double h, double effectiveOpen, double pulse) {
    canvas.save();

    final lidW = w * 0.78;
    final lidH = h * 0.28;
    final lidLeft = w * 0.11;
    final lidTop = h * 0.18;

    if (effectiveOpen > 0.03) {
      final pivot = Offset(w * 0.5, h * 0.44);
      canvas.translate(pivot.dx, pivot.dy);
      // Realistic lid opening swing
      canvas.rotate(-effectiveOpen * 1.10);
      canvas.translate(-pivot.dx, -pivot.dy - effectiveOpen * h * 0.08);
    }

    final lidRect = Rect.fromLTWH(lidLeft, lidTop, lidW, lidH);
    final lidRRect = RRect.fromRectAndCorners(
      lidRect,
      topLeft: Radius.circular(w * 0.18),
      topRight: Radius.circular(w * 0.18),
      bottomLeft: Radius.circular(w * 0.03),
      bottomRight: Radius.circular(w * 0.03),
    );

    // Domed Lid body shading per tier
    final Shader lidShader;
    switch (tier) {
      case Rarity.common:
        lidShader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xFF2C3246),
            Color(0xFF1E2333),
            Color(0xFF141724),
            Color(0xFF0C0E17),
          ],
          stops: [0.0, 0.30, 0.70, 1.0],
        ).createShader(lidRect);
        break;

      case Rarity.rare:
        lidShader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xFF1A4550),
            Color(0xFF0F2E36),
            Color(0xFF0A1E24),
            Color(0xFF040F13),
          ],
          stops: [0.0, 0.30, 0.70, 1.0],
        ).createShader(lidRect);
        break;

      case Rarity.epic:
        lidShader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xFF3D1F5E),
            Color(0xFF281340),
            Color(0xFF180B28),
            Color(0xFF090312),
          ],
          stops: [0.0, 0.30, 0.70, 1.0],
        ).createShader(lidRect);
        break;

      case Rarity.legendary:
        lidShader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xFF452718),
            Color(0xFF2E190E),
            Color(0xFF1C0D05),
            Color(0xFF0B0401),
          ],
          stops: [0.0, 0.30, 0.70, 1.0],
        ).createShader(lidRect);
        break;
    }
    canvas.drawRRect(lidRRect, Paint()..shader = lidShader);

    // Lid vertical seams
    final seamPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.60)
      ..strokeWidth = max(1.2, w * 0.016);
    canvas.drawLine(Offset(w * 0.38, lidTop + h * 0.02), Offset(w * 0.38, lidTop + lidH), seamPaint);
    canvas.drawLine(Offset(w * 0.62, lidTop + h * 0.02), Offset(w * 0.62, lidTop + lidH), seamPaint);

    // Arched metal brackets on lid
    final Shader lidBandShader;
    switch (tier) {
      case Rarity.common:
        lidBandShader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF78909C),
            Color(0xFF455A64),
            Color(0xFF263238),
          ],
        ).createShader(lidRect);
        break;
      case Rarity.rare:
        lidBandShader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF80DEEA),
            Color(0xFF00B4D8),
            Color(0xFF0077B6),
          ],
        ).createShader(lidRect);
        break;
      case Rarity.epic:
        lidBandShader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFFEA80FC),
            Color(0xFFAB47BC),
            Color(0xFF4A148C),
          ],
        ).createShader(lidRect);
        break;
      case Rarity.legendary:
        lidBandShader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFFFFF9E6),
            Color(0xFFFFD54F),
            Color(0xFFFFB300),
            Color(0xFFB78103),
          ],
        ).createShader(lidRect);
        break;
    }
    final lidBandPaint = Paint()..shader = lidBandShader;

    // Left curved lid bracket
    canvas.drawRRect(
      RRect.fromRectAndCorners(
        Rect.fromLTWH(lidLeft, lidTop, w * 0.12, lidH),
        topLeft: Radius.circular(w * 0.18),
        bottomLeft: Radius.circular(w * 0.03),
      ),
      lidBandPaint,
    );

    // Right curved lid bracket
    canvas.drawRRect(
      RRect.fromRectAndCorners(
        Rect.fromLTWH(lidLeft + lidW - w * 0.12, lidTop, w * 0.12, lidH),
        topRight: Radius.circular(w * 0.18),
        bottomRight: Radius.circular(w * 0.03),
      ),
      lidBandPaint,
    );

    // Center metallic band on lid
    canvas.drawRect(
      Rect.fromLTWH(w * 0.44, lidTop, w * 0.12, lidH),
      lidBandPaint,
    );

    // Bottom horizontal rim bar on lid
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(lidLeft - w * 0.01, lidTop + lidH - h * 0.055, lidW + w * 0.02, h * 0.055),
        Radius.circular(w * 0.025),
      ),
      lidBandPaint,
    );

    // Emissive neon crest line across lid rim
    final neonColor = switch (tier) {
      Rarity.common => const Color(0xFFFF9800),
      Rarity.rare => const Color(0xFF00E5FF),
      Rarity.epic => const Color(0xFFE040FB),
      Rarity.legendary => const Color(0xFFFFD54F),
    };
    final neonTrimPaint = Paint()
      ..color = neonColor.withValues(alpha: 0.88 * pulse)
      ..strokeWidth = max(1.4, w * 0.018);
    canvas.drawLine(
      Offset(lidLeft + w * 0.02, lidTop + lidH - h * 0.028),
      Offset(lidLeft + lidW - w * 0.02, lidTop + lidH - h * 0.028),
      neonTrimPaint,
    );

    // Lid Rivets
    final rivetR = max(1.4, w * 0.024);
    final lidRivets = [
      Offset(lidLeft + w * 0.060, lidTop + h * 0.08),
      Offset(lidLeft + w * 0.060, lidTop + h * 0.19),
      Offset(lidLeft + lidW - w * 0.060, lidTop + h * 0.08),
      Offset(lidLeft + lidW - w * 0.060, lidTop + h * 0.19),
      Offset(w * 0.500, lidTop + h * 0.07),
    ];
    final Paint rivetBasePaint;
    final Paint rivetCorePaint;
    switch (tier) {
      case Rarity.common:
        rivetBasePaint = Paint()..color = const Color(0xFF1A2126);
        rivetCorePaint = Paint()..color = const Color(0xFF78909C);
        break;
      case Rarity.rare:
        rivetBasePaint = Paint()..color = const Color(0xFF004D40);
        rivetCorePaint = Paint()..color = const Color(0xFF00E5FF);
        break;
      case Rarity.epic:
        rivetBasePaint = Paint()..color = const Color(0xFF311B92);
        rivetCorePaint = Paint()..color = const Color(0xFFE040FB);
        break;
      case Rarity.legendary:
        rivetBasePaint = Paint()..color = const Color(0xFF451A03);
        rivetCorePaint = Paint()..color = const Color(0xFFFFD54F);
        break;
    }
    for (final pos in lidRivets) {
      canvas.drawCircle(pos, rivetR, rivetBasePaint);
      canvas.drawCircle(pos, rivetR * 0.65, rivetCorePaint);
      canvas.drawCircle(Offset(pos.dx - rivetR * 0.32, pos.dy - rivetR * 0.32), rivetR * 0.35, Paint()..color = Colors.white);
    }

    // Top Crest Handle (Distinct architectural silhouette per tier)
    _drawTopHandle(canvas, w, h, lidTop, lidBandShader, pulse);

    canvas.restore(); // restore lid rotation
  }

  void _drawTopHandle(Canvas canvas, double w, double h, double lidTop, Shader bandShader, double pulse) {
    switch (tier) {
      case Rarity.common:
        // Arched heavy forged iron handle
        final handlePaint = Paint()
          ..shader = bandShader
          ..style = PaintingStyle.stroke
          ..strokeWidth = max(2.0, w * 0.030)
          ..strokeCap = StrokeCap.round;
        canvas.drawArc(
          Rect.fromCenter(center: Offset(w * 0.5, lidTop + h * 0.025), width: w * 0.20, height: h * 0.05),
          pi,
          pi,
          false,
          handlePaint,
        );
        break;

      case Rarity.rare:
        // Antique bronze-teal handle with aquamarine core
        final handlePaint = Paint()
          ..shader = bandShader
          ..style = PaintingStyle.stroke
          ..strokeWidth = max(2.2, w * 0.032)
          ..strokeCap = StrokeCap.round;
        canvas.drawArc(
          Rect.fromCenter(center: Offset(w * 0.5, lidTop + h * 0.025), width: w * 0.22, height: h * 0.055),
          pi,
          pi,
          false,
          handlePaint,
        );
        // Central aquamarine crystal bead
        canvas.drawCircle(
          Offset(w * 0.5, lidTop - h * 0.003),
          max(1.8, w * 0.026),
          Paint()..color = const Color(0xFF00E5FF),
        );
        break;

      case Rarity.epic:
        // Ornate violet-gold filigree crest handle
        final crestPath = Path()
          ..moveTo(w * 0.38, lidTop + h * 0.02)
          ..cubicTo(w * 0.42, lidTop - h * 0.025, w * 0.46, lidTop - h * 0.015, w * 0.50, lidTop - h * 0.035)
          ..cubicTo(w * 0.54, lidTop - h * 0.015, w * 0.58, lidTop - h * 0.025, w * 0.62, lidTop + h * 0.02);
        final crestPaint = Paint()
          ..shader = bandShader
          ..style = PaintingStyle.stroke
          ..strokeWidth = max(2.2, w * 0.032)
          ..strokeCap = StrokeCap.round;
        canvas.drawPath(crestPath, crestPaint);

        // Amethyst gem inlay at crest peak
        canvas.drawCircle(
          Offset(w * 0.5, lidTop - h * 0.035),
          max(2.2, w * 0.030),
          Paint()..color = const Color(0xFFE040FB),
        );
        canvas.drawCircle(
          Offset(w * 0.5 - 0.6, lidTop - h * 0.035 - 0.6),
          max(0.9, w * 0.012),
          Paint()..color = Colors.white,
        );
        break;

      case Rarity.legendary:
        // Ornate 3D carved Royal Crown Filigree Handle
        final crownPath = Path()
          ..moveTo(w * 0.36, lidTop + h * 0.02)
          ..lineTo(w * 0.40, lidTop - h * 0.025) // Left crown peak
          ..lineTo(w * 0.45, lidTop - h * 0.010) // Left valley
          ..lineTo(w * 0.50, lidTop - h * 0.045) // Royal Center Peak
          ..lineTo(w * 0.55, lidTop - h * 0.010) // Right valley
          ..lineTo(w * 0.60, lidTop - h * 0.025) // Right crown peak
          ..lineTo(w * 0.64, lidTop + h * 0.02);
        final crownPaint = Paint()
          ..shader = bandShader
          ..style = PaintingStyle.stroke
          ..strokeWidth = max(2.6, w * 0.038)
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round;
        canvas.drawPath(crownPath, crownPaint);

        // Crown Jewels / Solar Crystals atop the 3 peaks
        final leftPeak = Offset(w * 0.40, lidTop - h * 0.025);
        final centerPeak = Offset(w * 0.50, lidTop - h * 0.045);
        final rightPeak = Offset(w * 0.60, lidTop - h * 0.025);

        final jewelBase = Paint()..color = const Color(0xFF451A03);
        final jewelGold = Paint()..color = const Color(0xFFFFD54F);
        final jewelWhite = Paint()..color = Colors.white;

        for (final peak in [leftPeak, rightPeak]) {
          canvas.drawCircle(peak, max(1.8, w * 0.024), jewelBase);
          canvas.drawCircle(peak, max(1.2, w * 0.016), jewelGold);
        }
        // Center Imperial Solar Gem
        canvas.drawCircle(centerPeak, max(2.6, w * 0.036), jewelBase);
        canvas.drawCircle(centerPeak, max(2.0, w * 0.028), Paint()..color = const Color(0xFFFFB300));
        canvas.drawCircle(centerPeak, max(1.2, w * 0.016), jewelWhite);

        // Star glint cross on imperial peak
        final glintPaint = Paint()
          ..color = Colors.white.withValues(alpha: 0.95 * pulse)
          ..strokeWidth = max(1.0, w * 0.014);
        final gLen = w * 0.040;
        canvas.drawLine(Offset(centerPeak.dx - gLen, centerPeak.dy), Offset(centerPeak.dx + gLen, centerPeak.dy), glintPaint);
        canvas.drawLine(Offset(centerPeak.dx, centerPeak.dy - gLen), Offset(centerPeak.dx, centerPeak.dy + gLen), glintPaint);
        break;
    }
  }

  void _drawLockClasp(Canvas canvas, double w, double h, double pulse) {
    final lockCenter = Offset(w * 0.5, h * 0.46);
    final lockW = w * 0.20;
    final lockH = h * 0.20;

    // Escutcheon drop shadow
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset(lockCenter.dx, lockCenter.dy + 2.5), width: lockW, height: lockH),
        Radius.circular(w * 0.04),
      ),
      Paint()..color = const Color(0xAA000000),
    );

    switch (tier) {
      case Rarity.common:
        // Solid square forged iron clasp with circular keyhole emitting warm ember glow
        final escutcheonPaint = Paint()
          ..shader = LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: const [
              Color(0xFF78909C),
              Color(0xFF455A64),
              Color(0xFF263238),
            ],
            stops: const [0.0, 0.50, 1.0],
          ).createShader(Rect.fromCenter(center: lockCenter, width: lockW, height: lockH));
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromCenter(center: lockCenter, width: lockW, height: lockH),
            Radius.circular(w * 0.035),
          ),
          escutcheonPaint,
        );

        // Inner dark keyhole chamber
        canvas.drawCircle(lockCenter, lockW * 0.35, Paint()..color = const Color(0xFF080B10));

        // Warm Ember Core Glow
        final emberGlow = Paint()
          ..color = const Color(0xFFFF8F00).withValues(alpha: (0.75 + 0.20 * sin(time * 3.2)) * pulse)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, max(1.2, w * 0.038));
        canvas.drawCircle(lockCenter, lockW * 0.24, emberGlow);

        // Keyhole aperture (Circle + tapered keyhole slot)
        final keyholePath = Path()
          ..addOval(Rect.fromCircle(center: Offset(lockCenter.dx, lockCenter.dy - lockH * 0.05), radius: lockW * 0.12))
          ..moveTo(lockCenter.dx - lockW * 0.08, lockCenter.dy - lockH * 0.02)
          ..lineTo(lockCenter.dx + lockW * 0.08, lockCenter.dy - lockH * 0.02)
          ..lineTo(lockCenter.dx + lockW * 0.05, lockCenter.dy + lockH * 0.16)
          ..lineTo(lockCenter.dx - lockW * 0.05, lockCenter.dy + lockH * 0.16)
          ..close();
        canvas.drawPath(keyholePath, Paint()..color = const Color(0xFFFFB300));
        canvas.drawCircle(Offset(lockCenter.dx - lockW * 0.04, lockCenter.dy - lockH * 0.08), max(0.8, w * 0.012), Paint()..color = Colors.white);
        break;

      case Rarity.rare:
        // Hexagonal bronze-teal escutcheon plate with raw Aquamarine crystal shard
        final hexPath = Path();
        for (int i = 0; i < 6; i++) {
          final angle = (i * 60) * pi / 180;
          final px = lockCenter.dx + cos(angle) * (lockW * 0.52);
          final py = lockCenter.dy + sin(angle) * (lockH * 0.52);
          if (i == 0) {
            hexPath.moveTo(px, py);
          } else {
            hexPath.lineTo(px, py);
          }
        }
        hexPath.close();

        final hexPaint = Paint()
          ..shader = LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: const [
              Color(0xFF80DEEA),
              Color(0xFF00B4D8),
              Color(0xFF0077B6),
              Color(0xFF023E8A),
            ],
            stops: const [0.0, 0.35, 0.70, 1.0],
          ).createShader(Rect.fromCenter(center: lockCenter, width: lockW, height: lockH));
        canvas.drawPath(hexPath, hexPaint);

        // Inner dark chamber
        canvas.drawCircle(lockCenter, lockW * 0.34, Paint()..color = const Color(0xFF031014));

        // Runic glow
        final aquaGlow = Paint()
          ..color = const Color(0xFF00E5FF).withValues(alpha: 0.85 * pulse)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, max(1.2, w * 0.040));
        canvas.drawCircle(lockCenter, lockW * 0.25, aquaGlow);

        // Raw Aquamarine Crystal Shard (Facet-cut diamond crystal)
        final shardPath = Path()
          ..moveTo(lockCenter.dx, lockCenter.dy - lockH * 0.24)
          ..lineTo(lockCenter.dx + lockW * 0.19, lockCenter.dy)
          ..lineTo(lockCenter.dx, lockCenter.dy + lockH * 0.24)
          ..lineTo(lockCenter.dx - lockW * 0.19, lockCenter.dy)
          ..close();
        final shardPaint = Paint()
          ..shader = RadialGradient(
            colors: const [Colors.white, Color(0xFF00E5FF), Color(0xFF0077B6)],
            stops: const [0.1, 0.65, 1.0],
          ).createShader(Rect.fromCenter(center: lockCenter, width: lockW * 0.38, height: lockH * 0.48));
        canvas.drawPath(shardPath, shardPaint);

        // Specular Glint
        canvas.drawCircle(Offset(lockCenter.dx - lockW * 0.06, lockCenter.dy - lockH * 0.07), max(1.0, w * 0.016), Paint()..color = Colors.white);
        break;

      case Rarity.epic:
        // Rhombus escutcheon with 4-claw set Amethyst crystal gem
        final rhombusPath = Path()
          ..moveTo(lockCenter.dx, lockCenter.dy - lockH * 0.54)
          ..lineTo(lockCenter.dx + lockW * 0.54, lockCenter.dy)
          ..lineTo(lockCenter.dx, lockCenter.dy + lockH * 0.54)
          ..lineTo(lockCenter.dx - lockW * 0.54, lockCenter.dy)
          ..close();

        final rhombusPaint = Paint()
          ..shader = LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: const [
              Color(0xFFFFD54F),
              Color(0xFFAB47BC),
              Color(0xFF4A148C),
            ],
            stops: const [0.0, 0.45, 1.0],
          ).createShader(Rect.fromCenter(center: lockCenter, width: lockW, height: lockH));
        canvas.drawPath(rhombusPath, rhombusPaint);

        // Dark astral chamber
        canvas.drawCircle(lockCenter, lockW * 0.34, Paint()..color = const Color(0xFF090312));

        // Amethyst bloom
        final purpleGlow = Paint()
          ..color = const Color(0xFFE040FB).withValues(alpha: 0.88 * pulse)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, max(1.4, w * 0.045));
        canvas.drawCircle(lockCenter, lockW * 0.26, purpleGlow);

        // Faceted Amethyst Gem
        final gemPath = Path()
          ..moveTo(lockCenter.dx, lockCenter.dy - lockH * 0.22)
          ..lineTo(lockCenter.dx + lockW * 0.22, lockCenter.dy)
          ..lineTo(lockCenter.dx, lockCenter.dy + lockH * 0.22)
          ..lineTo(lockCenter.dx - lockW * 0.22, lockCenter.dy)
          ..close();
        final gemPaint = Paint()
          ..shader = RadialGradient(
            colors: const [Colors.white, Color(0xFFE040FB), Color(0xFF4A148C)],
            stops: const [0.15, 0.70, 1.0],
          ).createShader(Rect.fromCenter(center: lockCenter, width: lockW * 0.44, height: lockH * 0.44));
        canvas.drawPath(gemPath, gemPaint);

        // 4-Claw Forged Gold Setting
        final clawPaint = Paint()..color = const Color(0xFFFFD54F);
        const cOffset = 0.20;
        canvas.drawCircle(Offset(lockCenter.dx, lockCenter.dy - lockH * cOffset), max(1.2, w * 0.016), clawPaint);
        canvas.drawCircle(Offset(lockCenter.dx, lockCenter.dy + lockH * cOffset), max(1.2, w * 0.016), clawPaint);
        canvas.drawCircle(Offset(lockCenter.dx - lockW * cOffset, lockCenter.dy), max(1.2, w * 0.016), clawPaint);
        canvas.drawCircle(Offset(lockCenter.dx + lockW * cOffset, lockCenter.dy), max(1.2, w * 0.016), clawPaint);

        // Specular Glint
        canvas.drawCircle(Offset(lockCenter.dx - lockW * 0.07, lockCenter.dy - lockH * 0.07), max(1.0, w * 0.016), Paint()..color = Colors.white);
        break;

      case Rarity.legendary:
        // Magnificent Sun-Crest / Astral Compass clasp with star-cut Kaunos Solar Crystal
        // 8-point radiating golden sunburst petals
        final rayPaint = Paint()
          ..shader = const LinearGradient(
            colors: [Color(0xFFFFF9E6), Color(0xFFFFB300), Color(0xFFB78103)],
          ).createShader(Rect.fromCenter(center: lockCenter, width: lockW * 1.2, height: lockH * 1.2));

        for (int i = 0; i < 8; i++) {
          final angle = (i * 45) * pi / 180;
          final cosA = cos(angle);
          final sinA = sin(angle);
          final pTip = Offset(lockCenter.dx + cosA * (lockW * 0.60), lockCenter.dy + sinA * (lockH * 0.60));
          final pL = Offset(lockCenter.dx + cos(angle - 0.28) * (lockW * 0.28), lockCenter.dy + sin(angle - 0.28) * (lockH * 0.28));
          final pR = Offset(lockCenter.dx + cos(angle + 0.28) * (lockW * 0.28), lockCenter.dy + sin(angle + 0.28) * (lockH * 0.28));
          final petal = Path()
            ..moveTo(pL.dx, pL.dy)
            ..lineTo(pTip.dx, pTip.dy)
            ..lineTo(pR.dx, pR.dy)
            ..close();
          canvas.drawPath(petal, rayPaint);
        }

        // Circular 24k Sun Shield Escutcheon Plate
        final platePaint = Paint()
          ..shader = const RadialGradient(
            colors: [
              Color(0xFFFFF9E6),
              Color(0xFFFFD54F),
              Color(0xFFFFB300),
              Color(0xFF451A03),
            ],
            stops: [0.1, 0.45, 0.80, 1.0],
          ).createShader(Rect.fromCenter(center: lockCenter, width: lockW, height: lockH));
        canvas.drawCircle(lockCenter, lockW * 0.38, platePaint);

        // Dark astral sun core
        canvas.drawCircle(lockCenter, lockW * 0.28, Paint()..color = const Color(0xFF0F0602));

        // Radiant Solar Aura
        final solarAura = Paint()
          ..color = const Color(0xFFFFB300).withValues(alpha: 0.95 * pulse)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, max(1.5, w * 0.050));
        canvas.drawCircle(lockCenter, lockW * 0.22, solarAura);

        // Multi-faceted Star-Cut Kaunos Solar Crystal Gem
        final starPath = Path();
        for (int i = 0; i < 8; i++) {
          final outerAngle = (i * 45) * pi / 180;
          final innerAngle = ((i * 45) + 22.5) * pi / 180;
          final ox = lockCenter.dx + cos(outerAngle) * (lockW * 0.24);
          final oy = lockCenter.dy + sin(outerAngle) * (lockH * 0.24);
          final ix = lockCenter.dx + cos(innerAngle) * (lockW * 0.12);
          final iy = lockCenter.dy + sin(innerAngle) * (lockH * 0.12);
          if (i == 0) {
            starPath.moveTo(ox, oy);
          } else {
            starPath.lineTo(ox, oy);
          }
          starPath.lineTo(ix, iy);
        }
        starPath.close();

        final starPaint = Paint()
          ..shader = const RadialGradient(
            colors: [Colors.white, Color(0xFFFFF59D), Color(0xFFFFB300), Color(0xFFFF6F00)],
            stops: [0.15, 0.45, 0.80, 1.0],
          ).createShader(Rect.fromCenter(center: lockCenter, width: lockW * 0.48, height: lockH * 0.48));
        canvas.drawPath(starPath, starPaint);

        // 4-Point High-Intensity Chromatic Lens Flare
        final flarePaint = Paint()
          ..color = Colors.white.withValues(alpha: 0.95 * pulse)
          ..strokeWidth = max(1.2, w * 0.016);
        final flareLen = lockW * 0.50;
        canvas.drawLine(Offset(lockCenter.dx - flareLen, lockCenter.dy), Offset(lockCenter.dx + flareLen, lockCenter.dy), flarePaint);
        canvas.drawLine(Offset(lockCenter.dx, lockCenter.dy - flareLen), Offset(lockCenter.dx, lockCenter.dy + flareLen), flarePaint);
        canvas.drawCircle(lockCenter, max(1.2, w * 0.018), Paint()..color = Colors.white);
        break;
    }
  }

  void _drawVolumetricRays(Canvas canvas, double w, double h, double progress, double pulse, Color accent) {
    final rayPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.bottomCenter,
        end: Alignment.topCenter,
        colors: [
          accent.withValues(alpha: 0.75 * progress * pulse),
          accent.withValues(alpha: 0.25 * progress),
          accent.withValues(alpha: 0.0),
        ],
        stops: const [0.0, 0.45, 1.0],
      ).createShader(Rect.fromLTWH(0, 0, w, h * 0.9));

    // Fan of 7 volumetric light rays projecting up
    for (int i = -3; i <= 3; i++) {
      final angle = i * 0.24;
      final rayPath = Path();
      final originX = w * 0.5 + i * (w * 0.05);
      final originY = h * 0.44 - progress * (h * 0.05);
      final reach = (h * 0.65) * (0.6 + progress * 0.4);
      rayPath.moveTo(originX - w * 0.02, originY);
      rayPath.lineTo(originX + sin(angle - 0.09) * reach, originY - cos(angle) * reach);
      rayPath.lineTo(originX + sin(angle + 0.09) * reach, originY - cos(angle) * reach);
      rayPath.lineTo(originX + w * 0.02, originY);
      rayPath.close();
      canvas.drawPath(rayPath, rayPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _ChestPainter oldDelegate) {
    return oldDelegate.primaryColor != primaryColor ||
        oldDelegate.secondaryColor != secondaryColor ||
        oldDelegate.isOpened != isOpened ||
        oldDelegate.openProgress != openProgress ||
        oldDelegate.showGlow != showGlow ||
        oldDelegate.time != time ||
        oldDelegate.tier != tier;
  }
}
