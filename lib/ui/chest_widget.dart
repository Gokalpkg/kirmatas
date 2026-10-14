import 'dart:math';
import 'package:flutter/material.dart';

/// Highly detailed, authentic Neo-Vault Treasure Chest widget.
/// Inspired by the satisfying, weighty feel of classic chest archetypes
/// (arched domed lid, solid wood/obsidian chassis, reinforced metal bands with rivets,
/// heavy front lock clasp, and volumetric light shafts) seamlessly harmonized with
/// Kırmataş's dark cyber-arcade neon aesthetic.
class ChestWidget extends StatelessWidget {
  final double size;
  final Color primaryColor;
  final Color secondaryColor;
  final bool isOpened;
  final double openProgress; // 0.0 (closed) to 1.0 (fully open)
  final bool showGlow;
  final double time;

  const ChestWidget({
    super.key,
    this.size = 64,
    this.primaryColor = const Color(0xFFFFD54F),
    this.secondaryColor = const Color(0xFF5D4037),
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
    final pulse = 0.92 + 0.08 * sin(time * 2.8);

    // -------------------------------------------------------------
    // 0. AMBIENT GLOW / OUTER BLOOM
    // -------------------------------------------------------------
    if (showGlow) {
      final glowPaint = Paint()
        ..color = primaryColor.withValues(alpha: (0.22 + effectiveOpen * 0.20) * pulse)
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
      _drawVolumetricRays(canvas, w, h, effectiveOpen, pulse);
    }

    // -------------------------------------------------------------
    // 1. CHEST BASE (LOWER CHASSIS / WOOD & OBSIDIAN PLANKS)
    // -------------------------------------------------------------
    final baseRect = Rect.fromLTWH(w * 0.14, h * 0.44, w * 0.72, h * 0.42);
    final baseRRect = RRect.fromRectAndCorners(
      baseRect,
      bottomLeft: Radius.circular(w * 0.09),
      bottomRight: Radius.circular(w * 0.09),
    );

    // Deep rich wood/obsidian plank shading
    final bodyBase = Color.lerp(const Color(0xFF10131E), secondaryColor, 0.40)!;
    final bodyMid = Color.lerp(const Color(0xFF1E2333), secondaryColor, 0.65)!;
    final bodyDark = Color.lerp(const Color(0xFF070910), secondaryColor, 0.25)!;

    final baseGrad = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [bodyMid, bodyBase, bodyDark],
      stops: const [0.0, 0.55, 1.0],
    );
    canvas.drawRRect(baseRRect, Paint()..shader = baseGrad.createShader(baseRect));

    // Vertical plank separator seams (giving 3 distinct planks)
    final seamPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.55)
      ..strokeWidth = max(1.1, w * 0.016);
    canvas.drawLine(Offset(w * 0.38, h * 0.44), Offset(w * 0.38, h * 0.84), seamPaint);
    canvas.drawLine(Offset(w * 0.62, h * 0.44), Offset(w * 0.62, h * 0.84), seamPaint);

    // Plank highlight grain
    final grainPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.10)
      ..strokeWidth = max(0.8, w * 0.010);
    canvas.drawLine(Offset(w * 0.395, h * 0.44), Offset(w * 0.395, h * 0.84), grainPaint);
    canvas.drawLine(Offset(w * 0.635, h * 0.44), Offset(w * 0.635, h * 0.84), grainPaint);

    // Inside chest cavity glow when open
    if (effectiveOpen > 0.05) {
      final innerRect = Rect.fromLTWH(w * 0.16, h * 0.44, w * 0.68, h * 0.18 * effectiveOpen);
      canvas.drawRect(innerRect, Paint()..color = const Color(0xFF060810));

      final innerGlowPaint = Paint()
        ..shader = RadialGradient(
          colors: [
            Colors.white,
            primaryColor,
            primaryColor.withValues(alpha: 0.0),
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
    final bandGradient = LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [
        Color.lerp(primaryColor, Colors.white, 0.45)!,
        primaryColor,
        Color.lerp(primaryColor, Colors.black, 0.45)!,
      ],
      stops: const [0.0, 0.45, 1.0],
    );
    final bandPaint = Paint()..shader = bandGradient.createShader(baseRect);

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

    // Base Rivets
    final rivetR = max(1.4, w * 0.024);
    final rivetBase = Paint()..color = Color.lerp(primaryColor, Colors.black, 0.60)!;
    final rivetNeon = Paint()..color = primaryColor;
    final rivetGlint = Paint()..color = Colors.white;

    final baseRivets = [
      Offset(w * 0.195, h * 0.51),
      Offset(w * 0.195, h * 0.72),
      Offset(w * 0.805, h * 0.51),
      Offset(w * 0.805, h * 0.72),
      Offset(w * 0.500, h * 0.73),
    ];
    for (final pos in baseRivets) {
      canvas.drawCircle(pos, rivetR, rivetBase);
      canvas.drawCircle(pos, rivetR * 0.65, rivetNeon);
      canvas.drawCircle(Offset(pos.dx - rivetR * 0.32, pos.dy - rivetR * 0.32), rivetR * 0.35, rivetGlint);
    }

    // -------------------------------------------------------------
    // 3. ARCHED DOMED LID (Kavisli Kubbe Kapak)
    // -------------------------------------------------------------
    canvas.save();

    final lidW = w * 0.78;
    final lidH = h * 0.28;
    final lidLeft = w * 0.11;
    final lidTop = h * 0.18;

    if (effectiveOpen > 0.03) {
      final pivot = Offset(w * 0.5, h * 0.44);
      canvas.translate(pivot.dx, pivot.dy);
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

    // Domed Lid body shading with specular curve highlight on top
    final lidGrad = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [
        Color.lerp(bodyMid, Colors.white, 0.24)!,
        bodyMid,
        bodyBase,
        bodyDark,
      ],
      stops: const [0.0, 0.30, 0.75, 1.0],
    );
    canvas.drawRRect(lidRRect, Paint()..shader = lidGrad.createShader(lidRect));

    // Lid vertical seams
    canvas.drawLine(Offset(w * 0.38, lidTop + h * 0.02), Offset(w * 0.38, lidTop + lidH), seamPaint);
    canvas.drawLine(Offset(w * 0.62, lidTop + h * 0.02), Offset(w * 0.62, lidTop + lidH), seamPaint);

    // Arched metal brackets on lid
    final lidBandPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Color.lerp(primaryColor, Colors.white, 0.50)!,
          primaryColor,
          Color.lerp(primaryColor, Colors.black, 0.45)!,
        ],
      ).createShader(lidRect);

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

    // Emissive neon crest line across lid rim (Kırmataş neon signature)
    final neonTrimPaint = Paint()
      ..color = primaryColor.withValues(alpha: 0.85 * pulse)
      ..strokeWidth = max(1.3, w * 0.016);
    canvas.drawLine(
      Offset(lidLeft + w * 0.02, lidTop + lidH - h * 0.028),
      Offset(lidLeft + lidW - w * 0.02, lidTop + lidH - h * 0.028),
      neonTrimPaint,
    );

    // Lid Rivets
    final lidRivets = [
      Offset(lidLeft + w * 0.060, lidTop + h * 0.08),
      Offset(lidLeft + w * 0.060, lidTop + h * 0.19),
      Offset(lidLeft + lidW - w * 0.060, lidTop + h * 0.08),
      Offset(lidLeft + lidW - w * 0.060, lidTop + h * 0.19),
      Offset(w * 0.500, lidTop + h * 0.07),
    ];
    for (final pos in lidRivets) {
      canvas.drawCircle(pos, rivetR, rivetBase);
      canvas.drawCircle(pos, rivetR * 0.65, rivetNeon);
      canvas.drawCircle(Offset(pos.dx - rivetR * 0.32, pos.dy - rivetR * 0.32), rivetR * 0.35, rivetGlint);
    }

    // Top Crest Handle / Filigree (subtle arched handle on top of lid)
    final handlePaint = Paint()
      ..shader = bandGradient.createShader(Rect.fromCenter(center: Offset(w * 0.5, lidTop), width: w * 0.22, height: h * 0.06))
      ..style = PaintingStyle.stroke
      ..strokeWidth = max(1.8, w * 0.028)
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(
      Rect.fromCenter(center: Offset(w * 0.5, lidTop + h * 0.025), width: w * 0.20, height: h * 0.05),
      pi,
      pi,
      false,
      handlePaint,
    );

    canvas.restore(); // restore lid rotation

    // -------------------------------------------------------------
    // 4. FRONT LOCK & REACTOR CLASP (Centerpiece)
    // -------------------------------------------------------------
    final lockCenter = Offset(w * 0.5, h * 0.46);
    final lockW = w * 0.19;
    final lockH = h * 0.19;

    // Lock plate drop shadow
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset(lockCenter.dx, lockCenter.dy + 2.0), width: lockW, height: lockH),
        Radius.circular(w * 0.04),
      ),
      Paint()..color = const Color(0x99000000),
    );

    // Beveled metallic escutcheon shield plate
    final lockPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Colors.white,
          primaryColor,
          Color.lerp(primaryColor, Colors.black, 0.45)!,
        ],
        stops: const [0.0, 0.50, 1.0],
      ).createShader(Rect.fromCenter(center: lockCenter, width: lockW, height: lockH));

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: lockCenter, width: lockW, height: lockH),
        Radius.circular(w * 0.04),
      ),
      lockPaint,
    );

    // Inner Dark Core Chamber
    final innerCorePaint = Paint()..color = const Color(0xFF0A0C14);
    canvas.drawCircle(lockCenter, lockW * 0.35, innerCorePaint);

    // Glowing Power Gem in center of lock
    final coreGlowPaint = Paint()
      ..color = primaryColor.withValues(alpha: 0.85 * pulse)
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, max(1.0, w * 0.035));
    canvas.drawCircle(lockCenter, lockW * 0.24, coreGlowPaint);

    // Diamond / Prism Energy Crystal in lock
    final crystalPath = Path()
      ..moveTo(lockCenter.dx, lockCenter.dy - lockH * 0.22)
      ..lineTo(lockCenter.dx + lockW * 0.18, lockCenter.dy)
      ..lineTo(lockCenter.dx, lockCenter.dy + lockH * 0.22)
      ..lineTo(lockCenter.dx - lockW * 0.18, lockCenter.dy)
      ..close();
    final crystalPaint = Paint()
      ..shader = RadialGradient(
        colors: [Colors.white, primaryColor],
        stops: const [0.1, 1.0],
      ).createShader(Rect.fromCenter(center: lockCenter, width: lockW * 0.36, height: lockH * 0.44));
    canvas.drawPath(crystalPath, crystalPaint);

    // Specular Glint on Lock Core
    final lockGlint = Paint()..color = Colors.white.withValues(alpha: 0.95);
    canvas.drawCircle(
      Offset(lockCenter.dx - lockW * 0.06, lockCenter.dy - lockH * 0.06),
      max(0.9, w * 0.016),
      lockGlint,
    );
  }

  void _drawVolumetricRays(Canvas canvas, double w, double h, double progress, double pulse) {
    final rayPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.bottomCenter,
        end: Alignment.topCenter,
        colors: [
          primaryColor.withValues(alpha: 0.75 * progress * pulse),
          primaryColor.withValues(alpha: 0.25 * progress),
          primaryColor.withValues(alpha: 0.0),
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
        oldDelegate.time != time;
  }
}
