import 'dart:math';
import 'package:flutter/material.dart';

/// Highly detailed, arcade-futuristic Cyber Vault / Treasure Chest widget.
/// Renders an isometric perspective obsidian chassis with emissive neon circuit conduits,
/// metallic titanium armor bands with luminous energy rivets, an animated pulsing reactor core lock,
/// inner velvet/metallic treasure cavity with deep shading, and dynamic volumetric god-ray light shafts.
class ChestWidget extends StatelessWidget {
  final double size;
  final Color primaryColor;
  final Color secondaryColor;
  final bool isOpened;
  final double openProgress; // 0.0 (closed) to 1.0 (fully open)
  final bool showGlow;
  final double time; // for continuous breathing / circuit shimmer

  const ChestWidget({
    super.key,
    this.size = 64,
    this.primaryColor = const Color(0xFFFFD54F),
    this.secondaryColor = const Color(0xFF8D6E63),
    this.isOpened = false,
    this.openProgress = 0.0,
    this.showGlow = true,
    this.time = 0.0,
  });

  @override
  Widget build(BuildContext context) {
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

  _ChestPainter({
    required this.primaryColor,
    required this.secondaryColor,
    required this.isOpened,
    required this.openProgress,
    required this.showGlow,
    this.time = 0.0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final effectiveOpen = isOpened ? 1.0 : openProgress.clamp(0.0, 1.0);

    // -------------------------------------------------------------
    // 0. AMBIENT NEON GLOW / OUTER BLOOM
    // -------------------------------------------------------------
    if (showGlow) {
      final pulse = (sin(time * 3.0) * 0.06).clamp(-0.1, 0.1);
      final glowPaint = Paint()
        ..color = primaryColor.withValues(alpha: (0.32 + effectiveOpen * 0.22 + pulse).clamp(0.0, 0.8))
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, w * (0.20 + effectiveOpen * 0.10));
      canvas.drawCircle(Offset(w * 0.5, h * 0.52), w * 0.44, glowPaint);
    }

    // Volumetric God Rays bursting from inside chest when opening
    if (effectiveOpen > 0.03) {
      _drawVolumetricRays(canvas, w, h, effectiveOpen);
    }

    // Cast realistic ground drop shadow with perspective oval under chest
    final shadowScale = 1.0 - effectiveOpen * 0.12;
    final shadowPaint = Paint()..color = const Color(0xAA000000);
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(w * 0.5, h * 0.90 + effectiveOpen * 2.0),
        width: w * 0.86 * shadowScale,
        height: h * 0.22 * shadowScale,
      ),
      shadowPaint,
    );

    // -------------------------------------------------------------
    // 1. CHEST INTERIOR CAVITY (When Opened - Vault Lining & Treasure Core)
    // -------------------------------------------------------------
    if (effectiveOpen > 0.05) {
      final cavityRect = Rect.fromLTWH(w * 0.16, h * 0.38, w * 0.68, h * 0.26 * effectiveOpen);
      final cavityRRect = RRect.fromRectAndCorners(
        cavityRect,
        topLeft: Radius.circular(w * 0.04),
        topRight: Radius.circular(w * 0.04),
      );

      // Deep obsidian void shading
      final cavityGrad = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          const Color(0xFF040508),
          const Color(0xFF0D0F18),
          Color.lerp(const Color(0xFF151824), secondaryColor, 0.2)!,
        ],
      );
      canvas.drawRRect(cavityRRect, Paint()..shader = cavityGrad.createShader(cavityRect));

      // Golden / Prismatic Core Aura radiating from inside the vault
      final innerGlowPaint = Paint()
        ..shader = RadialGradient(
          colors: [
            Colors.white,
            primaryColor,
            primaryColor.withValues(alpha: 0.4),
            Colors.transparent,
          ],
          stops: const [0.0, 0.35, 0.70, 1.0],
        ).createShader(Rect.fromCenter(center: Offset(w * 0.5, h * 0.42), width: w * 0.64, height: h * 0.32));
      canvas.drawRect(cavityRect, innerGlowPaint);
    }

    // -------------------------------------------------------------
    // 2. CHEST BASE (LOWER CHASSIS)
    // -------------------------------------------------------------
    final baseRect = Rect.fromLTWH(w * 0.14, h * 0.44, w * 0.72, h * 0.42);
    final baseRRect = RRect.fromRectAndCorners(
      baseRect,
      bottomLeft: Radius.circular(w * 0.09),
      bottomRight: Radius.circular(w * 0.09),
    );

    // Cyber Obsidian / Dark Carbon plating blended with theme secondary color
    final bodyBaseColor = Color.lerp(const Color(0xFF10131E), secondaryColor, 0.20)!;
    final bodyMidColor = Color.lerp(const Color(0xFF181D2E), secondaryColor, 0.32)!;
    final bodyBottomColor = Color.lerp(const Color(0xFF080A10), secondaryColor, 0.15)!;

    final baseGrad = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [bodyMidColor, bodyBaseColor, bodyBottomColor],
      stops: const [0.0, 0.50, 1.0],
    );
    canvas.drawRRect(baseRRect, Paint()..shader = baseGrad.createShader(baseRect));

    // Vertical armor plate seams
    final seamPaint = Paint()
      ..color = const Color(0xFF05070A)
      ..strokeWidth = max(1.0, w * 0.016);
    canvas.drawLine(Offset(w * 0.38, h * 0.46), Offset(w * 0.38, h * 0.84), seamPaint);
    canvas.drawLine(Offset(w * 0.62, h * 0.46), Offset(w * 0.62, h * 0.84), seamPaint);

    // Specular plate bevel highlight lines
    final bevelPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.14)
      ..strokeWidth = max(0.8, w * 0.010);
    canvas.drawLine(Offset(w * 0.395, h * 0.46), Offset(w * 0.395, h * 0.84), bevelPaint);
    canvas.drawLine(Offset(w * 0.635, h * 0.46), Offset(w * 0.635, h * 0.84), bevelPaint);

    // Emissive Neon Circuit Traces on chest body panels
    _drawCircuitTraces(canvas, w, h, primaryColor);

    // -------------------------------------------------------------
    // 3. CHEST BASE METALLIC CORNER BANDS & RIVETS
    // -------------------------------------------------------------
    final bandGrad = LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [
        Color.lerp(primaryColor, Colors.white, 0.55)!,
        primaryColor,
        Color.lerp(primaryColor, Colors.black, 0.45)!,
      ],
      stops: const [0.0, 0.5, 1.0],
    );
    final bandPaint = Paint()..shader = bandGrad.createShader(baseRect);

    // Left vertical bracket
    canvas.drawRRect(
      RRect.fromRectAndCorners(
        Rect.fromLTWH(w * 0.14, h * 0.44, w * 0.11, h * 0.42),
        bottomLeft: Radius.circular(w * 0.09),
      ),
      bandPaint,
    );

    // Right vertical bracket
    canvas.drawRRect(
      RRect.fromRectAndCorners(
        Rect.fromLTWH(w * 0.75, h * 0.44, w * 0.11, h * 0.42),
        bottomRight: Radius.circular(w * 0.09),
      ),
      bandPaint,
    );

    // Bottom horizontal reinforcing plate
    canvas.drawRRect(
      RRect.fromRectAndCorners(
        Rect.fromLTWH(w * 0.14, h * 0.78, w * 0.72, h * 0.08),
        bottomLeft: Radius.circular(w * 0.09),
        bottomRight: Radius.circular(w * 0.09),
      ),
      bandPaint,
    );

    // Glowing Cyber-Rivets on base brackets
    final rivetBase = Paint()..color = const Color(0xFF11141C);
    final rivetGlint = Paint()..color = Colors.white.withValues(alpha: 0.90);
    final rivetNeon = Paint()..color = primaryColor.withValues(alpha: 0.85);
    final rivetR = max(1.2, w * 0.018);

    final rivetPositions = [
      Offset(w * 0.195, h * 0.50),
      Offset(w * 0.195, h * 0.66),
      Offset(w * 0.195, h * 0.81),
      Offset(w * 0.805, h * 0.50),
      Offset(w * 0.805, h * 0.66),
      Offset(w * 0.805, h * 0.81),
      Offset(w * 0.38, h * 0.82),
      Offset(w * 0.62, h * 0.82),
    ];
    for (final pos in rivetPositions) {
      canvas.drawCircle(pos, rivetR, rivetBase);
      canvas.drawCircle(pos, rivetR * 0.55, rivetNeon);
      canvas.drawCircle(Offset(pos.dx - rivetR * 0.35, pos.dy - rivetR * 0.35), rivetR * 0.35, rivetGlint);
    }

    // -------------------------------------------------------------
    // 4. CHEST LID (TOP ARCH) - Animates opening upward & tilting with 3D Depth
    // -------------------------------------------------------------
    canvas.save();

    final lidH = h * 0.28;
    final lidW = w * 0.76;
    final lidLeft = w * 0.12;
    final lidTop = h * 0.22;

    if (effectiveOpen > 0) {
      // Hinge pivot at back-top of chest
      final pivotX = w * 0.5;
      final pivotY = h * 0.42;
      canvas.translate(pivotX, pivotY);
      // Perspective backwards rotation + upward lift
      canvas.rotate(-effectiveOpen * 0.85);
      canvas.translate(-pivotX, -pivotY - effectiveOpen * (h * 0.22));

      // Draw Lid Inner Underbelly Panel (Perspective Depth)
      final innerLidRect = Rect.fromLTWH(lidLeft + w * 0.03, lidTop + lidH * 0.10, lidW - w * 0.06, lidH * 0.85);
      final innerLidGrad = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          const Color(0xFF0A0C14),
          Color.lerp(const Color(0xFF141826), primaryColor, 0.25)!,
          Colors.white.withValues(alpha: 0.4),
        ],
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(innerLidRect, Radius.circular(w * 0.06)),
        Paint()..shader = innerLidGrad.createShader(innerLidRect),
      );
    }

    final lidRect = Rect.fromLTWH(lidLeft, lidTop, lidW, lidH);
    final lidRRect = RRect.fromRectAndCorners(
      lidRect,
      topLeft: Radius.circular(w * 0.16),
      topRight: Radius.circular(w * 0.16),
      bottomLeft: Radius.circular(w * 0.03),
      bottomRight: Radius.circular(w * 0.03),
    );

    // Lid Obsidian Plating
    final lidGrad = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [
        Color.lerp(bodyMidColor, Colors.white, 0.22)!,
        bodyMidColor,
        bodyBaseColor,
      ],
    );
    canvas.drawRRect(lidRRect, Paint()..shader = lidGrad.createShader(lidRect));

    // Lid vertical seams
    canvas.drawLine(Offset(w * 0.38, lidTop + h * 0.02), Offset(w * 0.38, lidTop + lidH), seamPaint);
    canvas.drawLine(Offset(w * 0.62, lidTop + h * 0.02), Offset(w * 0.62, lidTop + lidH), seamPaint);

    // Lid metal arch bands
    final lidBandPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Color.lerp(primaryColor, Colors.white, 0.55)!,
          primaryColor,
          Color.lerp(primaryColor, Colors.black, 0.40)!,
        ],
      ).createShader(lidRect);

    // Left lid curved bracket
    canvas.drawRRect(
      RRect.fromRectAndCorners(
        Rect.fromLTWH(lidLeft, lidTop, w * 0.11, lidH),
        topLeft: Radius.circular(w * 0.16),
        bottomLeft: Radius.circular(w * 0.03),
      ),
      lidBandPaint,
    );

    // Right lid curved bracket
    canvas.drawRRect(
      RRect.fromRectAndCorners(
        Rect.fromLTWH(lidLeft + lidW - w * 0.11, lidTop, w * 0.11, lidH),
        topRight: Radius.circular(w * 0.16),
        bottomRight: Radius.circular(w * 0.03),
      ),
      lidBandPaint,
    );

    // Center metallic band on lid
    canvas.drawRect(
      Rect.fromLTWH(w * 0.44, lidTop, w * 0.12, lidH),
      lidBandPaint,
    );

    // Lid lower trim rim
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(lidLeft - w * 0.01, lidTop + lidH - h * 0.06, lidW + w * 0.02, h * 0.06),
        Radius.circular(w * 0.03),
      ),
      lidBandPaint,
    );

    // Emissive neon crest line across lid rim
    final neonTrimPaint = Paint()
      ..color = primaryColor.withValues(alpha: 0.90)
      ..strokeWidth = max(1.2, w * 0.014);
    canvas.drawLine(
      Offset(lidLeft + w * 0.02, lidTop + lidH - h * 0.03),
      Offset(lidLeft + lidW - w * 0.02, lidTop + lidH - h * 0.03),
      neonTrimPaint,
    );

    // Lid Rivets
    final lidRivets = [
      Offset(lidLeft + w * 0.055, lidTop + h * 0.08),
      Offset(lidLeft + w * 0.055, lidTop + h * 0.20),
      Offset(lidLeft + lidW - w * 0.055, lidTop + h * 0.08),
      Offset(lidLeft + lidW - w * 0.055, lidTop + h * 0.20),
      Offset(w * 0.5, lidTop + h * 0.07),
    ];
    for (final pos in lidRivets) {
      canvas.drawCircle(pos, rivetR, rivetBase);
      canvas.drawCircle(pos, rivetR * 0.55, rivetNeon);
      canvas.drawCircle(Offset(pos.dx - rivetR * 0.35, pos.dy - rivetR * 0.35), rivetR * 0.35, rivetGlint);
    }

    canvas.restore(); // restore lid rotation

    // -------------------------------------------------------------
    // 5. CHEST POWER CORE REACTOR LOCK (Centerpiece)
    // -------------------------------------------------------------
    // Lock drops/separates down smoothly when opening
    final lockCenterY = h * 0.47 + effectiveOpen * (h * 0.08);
    final lockCenter = Offset(w * 0.5, lockCenterY);
    final lockW = w * 0.19;
    final lockH = h * 0.19;

    // Lock plate shadow
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset(lockCenter.dx, lockCenter.dy + 2.5), width: lockW, height: lockH),
        Radius.circular(w * 0.04),
      ),
      Paint()..color = const Color(0xAA000000),
    );

    // Lock plate cyber escutcheon with metallic sheen
    final lockPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Colors.white,
          primaryColor,
          Color.lerp(primaryColor, Colors.black, 0.45)!,
        ],
      ).createShader(Rect.fromCenter(center: lockCenter, width: lockW, height: lockH));

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: lockCenter, width: lockW, height: lockH),
        Radius.circular(w * 0.04),
      ),
      lockPaint,
    );

    // Inner Dark Core Housing
    final innerCorePaint = Paint()..color = const Color(0xFF07090F);
    canvas.drawCircle(lockCenter, lockW * 0.34, innerCorePaint);

    // Glowing Power Core Reactor / Crystal
    final corePulse = (sin(time * 5.0) * 0.12).clamp(-0.2, 0.2);
    final coreGlowPaint = Paint()
      ..color = primaryColor.withValues(alpha: (0.85 + effectiveOpen * 0.15 + corePulse).clamp(0.0, 1.0))
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, max(1.0, w * 0.035));
    canvas.drawCircle(lockCenter, lockW * (0.24 + effectiveOpen * 0.08), coreGlowPaint);

    // Octagonal / Diamond Prismatic Crystal Core
    final crystalPath = Path()
      ..moveTo(lockCenter.dx, lockCenter.dy - lockH * 0.24)
      ..lineTo(lockCenter.dx + lockW * 0.20, lockCenter.dy)
      ..lineTo(lockCenter.dx, lockCenter.dy + lockH * 0.24)
      ..lineTo(lockCenter.dx - lockW * 0.20, lockCenter.dy)
      ..close();
    final crystalPaint = Paint()
      ..shader = RadialGradient(
        colors: [Colors.white, primaryColor],
        stops: const [0.15, 1.0],
      ).createShader(Rect.fromCenter(center: lockCenter, width: lockW * 0.40, height: lockH * 0.48));
    canvas.drawPath(crystalPath, crystalPaint);

    // If opening, draw energy crack lines across the lock core
    if (effectiveOpen > 0.1) {
      final crackPaint = Paint()
        ..color = Colors.white.withValues(alpha: (effectiveOpen * 0.95).clamp(0.0, 1.0))
        ..strokeWidth = max(0.8, w * 0.012)
        ..style = PaintingStyle.stroke;
      canvas.drawLine(
        Offset(lockCenter.dx - lockW * 0.12, lockCenter.dy - lockH * 0.12),
        Offset(lockCenter.dx + lockW * 0.12, lockCenter.dy + lockH * 0.12),
        crackPaint,
      );
      canvas.drawLine(
        Offset(lockCenter.dx - lockW * 0.10, lockCenter.dy + lockH * 0.08),
        Offset(lockCenter.dx + lockW * 0.14, lockCenter.dy - lockH * 0.06),
        crackPaint,
      );
    }

    // Specular Glint on Core
    final lockGlint = Paint()..color = Colors.white.withValues(alpha: 0.95);
    canvas.drawCircle(Offset(lockCenter.dx - lockW * 0.07, lockCenter.dy - lockH * 0.07), max(0.9, w * 0.016), lockGlint);
  }

  void _drawCircuitTraces(Canvas canvas, double w, double h, Color color) {
    final circuitPaint = Paint()
      ..color = color.withValues(alpha: 0.50)
      ..strokeWidth = max(1.0, w * 0.012)
      ..style = PaintingStyle.stroke;

    // Left circuit trace
    final leftPath = Path()
      ..moveTo(w * 0.26, h * 0.54)
      ..lineTo(w * 0.32, h * 0.54)
      ..lineTo(w * 0.35, h * 0.62)
      ..lineTo(w * 0.35, h * 0.72);
    canvas.drawPath(leftPath, circuitPaint);

    // Right circuit trace
    final rightPath = Path()
      ..moveTo(w * 0.74, h * 0.54)
      ..lineTo(w * 0.68, h * 0.54)
      ..lineTo(w * 0.65, h * 0.62)
      ..lineTo(w * 0.65, h * 0.72);
    canvas.drawPath(rightPath, circuitPaint);

    // Small node dots
    final nodePaint = Paint()
      ..color = color.withValues(alpha: 0.75)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(Offset(w * 0.35, h * 0.72), max(1.0, w * 0.014), nodePaint);
    canvas.drawCircle(Offset(w * 0.65, h * 0.72), max(1.0, w * 0.014), nodePaint);
  }

  void _drawVolumetricRays(Canvas canvas, double w, double h, double progress) {
    final rayPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.bottomCenter,
        end: Alignment.topCenter,
        colors: [
          Colors.white.withValues(alpha: 0.85 * progress),
          primaryColor.withValues(alpha: 0.65 * progress),
          primaryColor.withValues(alpha: 0.20 * progress),
          primaryColor.withValues(alpha: 0.0),
        ],
        stops: const [0.0, 0.25, 0.65, 1.0],
      ).createShader(Rect.fromLTWH(0, 0, w, h * 0.95));

    // Fan of 9 volumetric light rays projecting up
    for (int i = -4; i <= 4; i++) {
      final angle = i * 0.22;
      final rayPath = Path();
      final originX = w * 0.5 + i * (w * 0.045);
      final originY = h * 0.44 - progress * (h * 0.06);
      final reach = (h * 0.70) * (0.65 + progress * 0.35);
      rayPath.moveTo(originX - w * 0.02, originY);
      rayPath.lineTo(originX + sin(angle - 0.08) * reach, originY - cos(angle) * reach);
      rayPath.lineTo(originX + sin(angle + 0.08) * reach, originY - cos(angle) * reach);
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
        oldDelegate.time != time;
  }
}
