import 'dart:math';
import 'package:flutter/material.dart';

/// Highly detailed, game-ready Fantasy/Sci-Fi Treasure Chest widget.
/// Draws a realistic chest with wood/metal planks, steel/gold banded trims,
/// reinforced iron corner brackets with rivets, keyhole lock, and glowing magical seam.
class ChestWidget extends StatelessWidget {
  final double size;
  final Color primaryColor;
  final Color secondaryColor;
  final bool isOpened;
  final double openProgress; // 0.0 (closed) to 1.0 (fully open)
  final bool showGlow;

  const ChestWidget({
    super.key,
    this.size = 64,
    this.primaryColor = const Color(0xFFFFD54F),
    this.secondaryColor = const Color(0xFF8D6E63),
    this.isOpened = false,
    this.openProgress = 0.0,
    this.showGlow = true,
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

  _ChestPainter({
    required this.primaryColor,
    required this.secondaryColor,
    required this.isOpened,
    required this.openProgress,
    required this.showGlow,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // Outer magical aura / bloom
    if (showGlow) {
      final glowPaint = Paint()
        ..color = primaryColor.withValues(alpha: 0.28)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, w * 0.18);
      canvas.drawCircle(Offset(w * 0.5, h * 0.52), w * 0.42, glowPaint);
    }

    // Cast ground drop shadow under chest
    final shadowPaint = Paint()..color = const Color(0x77000000);
    canvas.drawOval(
      Rect.fromCenter(center: Offset(w * 0.5, h * 0.88), width: w * 0.82, height: h * 0.22),
      shadowPaint,
    );

    final effectiveOpen = isOpened ? 1.0 : openProgress.clamp(0.0, 1.0);

    // -------------------------------------------------------------
    // CHEST BASE (LOWER BODY)
    // -------------------------------------------------------------
    final baseRect = Rect.fromLTWH(w * 0.14, h * 0.44, w * 0.72, h * 0.42);
    final baseRRect = RRect.fromRectAndCorners(
      baseRect,
      bottomLeft: Radius.circular(w * 0.08),
      bottomRight: Radius.circular(w * 0.08),
    );

    // Base body fill (Polished Wood Planks / Obsidian Metallic)
    final baseGrad = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [
        secondaryColor,
        Color.lerp(secondaryColor, Colors.black, 0.45)!,
        Color.lerp(secondaryColor, Colors.black, 0.70)!,
      ],
      stops: const [0.0, 0.55, 1.0],
    );
    final basePaint = Paint()..shader = baseGrad.createShader(baseRect);
    canvas.drawRRect(baseRRect, basePaint);

    // Vertical plank separator seams
    final seamPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.40)
      ..strokeWidth = max(1.0, w * 0.015);
    canvas.drawLine(Offset(w * 0.38, h * 0.46), Offset(w * 0.38, h * 0.84), seamPaint);
    canvas.drawLine(Offset(w * 0.62, h * 0.46), Offset(w * 0.62, h * 0.84), seamPaint);

    // Subtle plank grain specular highlight
    final grainPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.10)
      ..strokeWidth = max(0.8, w * 0.012);
    canvas.drawLine(Offset(w * 0.395, h * 0.46), Offset(w * 0.395, h * 0.84), grainPaint);
    canvas.drawLine(Offset(w * 0.635, h * 0.46), Offset(w * 0.635, h * 0.84), grainPaint);

    // Inside chest cavity glow when open
    if (effectiveOpen > 0.05) {
      final innerGlowPaint = Paint()
        ..shader = RadialGradient(
          colors: [
            Colors.white,
            primaryColor,
            primaryColor.withValues(alpha: 0.0),
          ],
          stops: const [0.0, 0.45, 1.0],
        ).createShader(Rect.fromLTWH(w * 0.18, h * 0.30, w * 0.64, h * 0.40));
      canvas.drawRect(Rect.fromLTWH(w * 0.16, h * 0.40, w * 0.68, h * 0.18 * effectiveOpen), innerGlowPaint);
    }

    // -------------------------------------------------------------
    // CHEST BASE METAL CORNER BANDS & RIVETS (Reinforcements)
    // -------------------------------------------------------------
    final bandPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Color.lerp(primaryColor, Colors.white, 0.40)!,
          primaryColor,
          Color.lerp(primaryColor, Colors.black, 0.45)!,
        ],
      ).createShader(baseRect);

    // Left vertical bracket
    canvas.drawRRect(
      RRect.fromRectAndCorners(
        Rect.fromLTWH(w * 0.14, h * 0.44, w * 0.11, h * 0.42),
        bottomLeft: Radius.circular(w * 0.08),
      ),
      bandPaint,
    );

    // Right vertical bracket
    canvas.drawRRect(
      RRect.fromRectAndCorners(
        Rect.fromLTWH(w * 0.75, h * 0.44, w * 0.11, h * 0.42),
        bottomRight: Radius.circular(w * 0.08),
      ),
      bandPaint,
    );

    // Bottom horizontal reinforcing plate
    canvas.drawRRect(
      RRect.fromRectAndCorners(
        Rect.fromLTWH(w * 0.14, h * 0.78, w * 0.72, h * 0.08),
        bottomLeft: Radius.circular(w * 0.08),
        bottomRight: Radius.circular(w * 0.08),
      ),
      bandPaint,
    );

    // Rivets (metallic pins) on base brackets
    final rivetBase = Paint()..color = const Color(0xFF1A1A1A);
    final rivetGlint = Paint()..color = Colors.white.withValues(alpha: 0.85);
    final rivetR = max(1.0, w * 0.018);

    final rivetPositions = [
      Offset(w * 0.195, h * 0.50),
      Offset(w * 0.195, h * 0.68),
      Offset(w * 0.195, h * 0.81),
      Offset(w * 0.805, h * 0.50),
      Offset(w * 0.805, h * 0.68),
      Offset(w * 0.805, h * 0.81),
      Offset(w * 0.38, h * 0.82),
      Offset(w * 0.62, h * 0.82),
    ];
    for (final pos in rivetPositions) {
      canvas.drawCircle(pos, rivetR, rivetBase);
      canvas.drawCircle(Offset(pos.dx - rivetR * 0.35, pos.dy - rivetR * 0.35), rivetR * 0.5, rivetGlint);
    }

    // -------------------------------------------------------------
    // CHEST LID (TOP ARCH) - Animates opening upward & tilting
    // -------------------------------------------------------------
    canvas.save();

    final lidH = h * 0.28;
    final lidW = w * 0.76;
    final lidLeft = w * 0.12;
    final lidTop = h * 0.22;

    if (effectiveOpen > 0) {
      // Hinge at top-back of chest
      final pivotX = w * 0.5;
      final pivotY = h * 0.42;
      canvas.translate(pivotX, pivotY);
      canvas.rotate(-effectiveOpen * 0.75); // tilt backwards/upwards
      canvas.translate(-pivotX, -pivotY - effectiveOpen * (h * 0.16));
    }

    final lidRect = Rect.fromLTWH(lidLeft, lidTop, lidW, lidH);
    final lidRRect = RRect.fromRectAndCorners(
      lidRect,
      topLeft: Radius.circular(w * 0.16),
      topRight: Radius.circular(w * 0.16),
      bottomLeft: Radius.circular(w * 0.03),
      bottomRight: Radius.circular(w * 0.03),
    );

    // Lid wooden/obsidian fill
    final lidGrad = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [
        Color.lerp(secondaryColor, Colors.white, 0.20)!,
        secondaryColor,
        Color.lerp(secondaryColor, Colors.black, 0.50)!,
      ],
    );
    final lidPaint = Paint()..shader = lidGrad.createShader(lidRect);
    canvas.drawRRect(lidRRect, lidPaint);

    // Lid vertical seams
    canvas.drawLine(Offset(w * 0.38, lidTop + h * 0.02), Offset(w * 0.38, lidTop + lidH), seamPaint);
    canvas.drawLine(Offset(w * 0.62, lidTop + h * 0.02), Offset(w * 0.62, lidTop + lidH), seamPaint);

    // Lid reinforcing metal arch bands
    final lidBandPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Color.lerp(primaryColor, Colors.white, 0.45)!,
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
      canvas.drawCircle(Offset(pos.dx - rivetR * 0.35, pos.dy - rivetR * 0.35), rivetR * 0.5, rivetGlint);
    }

    canvas.restore(); // restore lid rotation

    // -------------------------------------------------------------
    // CHEST GOLD LOCK HASP & KEYHOLE (Centerpiece)
    // -------------------------------------------------------------
    final lockCenter = Offset(w * 0.5, h * 0.47);
    final lockW = w * 0.16;
    final lockH = h * 0.17;

    // Lock plate shadow
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset(lockCenter.dx, lockCenter.dy + 1.5), width: lockW, height: lockH),
        Radius.circular(w * 0.04),
      ),
      Paint()..color = const Color(0x99000000),
    );

    // Lock plate golden shield/escutcheon
    final lockPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Colors.white,
          primaryColor,
          Color.lerp(primaryColor, Colors.black, 0.40)!,
        ],
      ).createShader(Rect.fromCenter(center: lockCenter, width: lockW, height: lockH));

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: lockCenter, width: lockW, height: lockH),
        Radius.circular(w * 0.04),
      ),
      lockPaint,
    );

    // Keyhole (Black dot + trapezoid slot)
    final keyholePaint = Paint()..color = const Color(0xFF10121A);
    canvas.drawCircle(Offset(lockCenter.dx, lockCenter.dy - lockH * 0.15), lockW * 0.16, keyholePaint);
    final keyholePath = Path()
      ..moveTo(lockCenter.dx - lockW * 0.10, lockCenter.dy - lockH * 0.10)
      ..lineTo(lockCenter.dx + lockW * 0.10, lockCenter.dy - lockH * 0.10)
      ..lineTo(lockCenter.dx + lockW * 0.14, lockCenter.dy + lockH * 0.25)
      ..lineTo(lockCenter.dx - lockW * 0.14, lockCenter.dy + lockH * 0.25)
      ..close();
    canvas.drawPath(keyholePath, keyholePaint);

    // Gem / Keyhole magical gleam
    final lockGlint = Paint()..color = Colors.white.withValues(alpha: 0.90);
    canvas.drawCircle(Offset(lockCenter.dx - lockW * 0.22, lockCenter.dy - lockH * 0.22), max(0.8, w * 0.012), lockGlint);
  }

  @override
  bool shouldRepaint(covariant _ChestPainter oldDelegate) {
    return oldDelegate.primaryColor != primaryColor ||
        oldDelegate.secondaryColor != secondaryColor ||
        oldDelegate.isOpened != isOpened ||
        oldDelegate.openProgress != openProgress ||
        oldDelegate.showGlow != showGlow;
  }
}
