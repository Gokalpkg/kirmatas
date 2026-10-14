import 'dart:math';
import 'package:flutter/material.dart';

/// Crate built from the same neon bricks as the board: dark acrylic plates,
/// phosphor tubes with a white core, and a ball-core lock.
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

  Color get _tube {
    final hsl = HSLColor.fromColor(primaryColor);
    final light = hsl.lightness < 0.48 ? 0.58 : hsl.lightness;
    final sat = hsl.saturation < 0.35 ? 0.50 : hsl.saturation;
    return hsl.withLightness(light.clamp(0.0, 0.78)).withSaturation(sat.clamp(0.0, 1.0)).toColor();
  }

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final open = isOpened ? 1.0 : openProgress.clamp(0.0, 1.0);
    final neon = _tube;
    final flicker = 0.94 + 0.06 * sin(time * 2.4);

    if (showGlow) {
      canvas.drawCircle(
        Offset(w * 0.5, h * 0.56),
        w * 0.36,
        Paint()
          ..color = neon.withValues(alpha: (0.22 + open * 0.16).clamp(0.0, 0.5))
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, w * 0.12),
      );
    }

    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(w * 0.5, h * 0.90),
        width: w * 0.72,
        height: h * 0.12,
      ),
      Paint()..color = const Color(0x88000000),
    );

    if (open > 0.04) {
      _drawCavity(canvas, w, h, open, neon);
    }

    final radius = w * 0.075;
    final lower = Rect.fromLTWH(w * 0.16, h * 0.64, w * 0.68, h * 0.20);
    final upper = Rect.fromLTWH(w * 0.16, h * 0.44, w * 0.68, h * 0.18);
    _drawPlate(canvas, lower, radius, neon, flicker, innerFilament: true);
    _drawPlate(canvas, upper, radius, neon, flicker, innerFilament: false);
    _drawCore(
      canvas,
      upper.center,
      w * 0.074,
      neon,
      flicker,
      open,
    );

    final lid = Rect.fromLTWH(w * 0.10, h * 0.18, w * 0.80, h * 0.24);
    canvas.save();
    if (open > 0.08) {
      final pivot = Offset(lid.center.dx, lid.bottom);
      canvas.translate(pivot.dx, pivot.dy);
      canvas.rotate(-open * 1.05);
      canvas.translate(-pivot.dx, -pivot.dy - open * h * 0.05);
      _drawPlate(
        canvas,
        lid.shift(Offset(0, lid.height * 0.08)),
        radius,
        Color.lerp(neon, const Color(0xFF050811), 0.55)!,
        flicker,
        innerFilament: false,
        faceOnly: true,
      );
    }
    _drawPlate(canvas, lid, radius * 1.15, neon, flicker, innerFilament: true);
    canvas.restore();
  }

  void _drawPlate(
    Canvas canvas,
    Rect rect,
    double radius,
    Color neon,
    double flicker, {
    required bool innerFilament,
    bool faceOnly = false,
  }) {
    if (rect.width < 4 || rect.height < 4) return;
    final rr = RRect.fromRectAndRadius(rect, Radius.circular(radius));

    if (!faceOnly) {
      final shadow = RRect.fromRectAndRadius(
        rect.shift(Offset(0, max(1.4, rect.height * 0.12))),
        Radius.circular(radius),
      );
      canvas.drawRRect(
        shadow,
        Paint()..color = Color.lerp(neon, const Color(0xFF04060C), 0.82)!.withValues(alpha: 0.85),
      );
    }

    final tint = Color.lerp(neon, secondaryColor, 0.18)!;
    final body = Paint()
      ..shader = RadialGradient(
        colors: [
          Color.lerp(tint, const Color(0xFF10182A), 0.34)!,
          Color.lerp(tint, const Color(0xFF050811), 0.82)!,
        ],
      ).createShader(rect);
    canvas.drawRRect(rr, body);

    canvas.save();
    canvas.clipRRect(rr);
    final gloss = RRect.fromRectAndRadius(
      Rect.fromLTWH(
        rect.left + rect.width * 0.08,
        rect.top + rect.height * 0.14,
        rect.width * 0.84,
        max(2.0, rect.height * 0.22),
      ),
      Radius.circular(radius * 0.45),
    );
    canvas.drawRRect(
      gloss,
      Paint()..color = Colors.white.withValues(alpha: faceOnly ? 0.05 : 0.16),
    );
    final slash = Path()
      ..moveTo(rect.left + rect.width * 0.08, rect.top + rect.height * 0.18)
      ..lineTo(rect.left + rect.width * 0.22, rect.top + rect.height * 0.18)
      ..lineTo(rect.left + rect.width * 0.12, rect.bottom - rect.height * 0.18)
      ..lineTo(rect.left + rect.width * 0.02, rect.bottom - rect.height * 0.18)
      ..close();
    canvas.drawPath(slash, Paint()..color = Colors.white.withValues(alpha: faceOnly ? 0.04 : 0.12));
    canvas.restore();

    if (!faceOnly) {
      final cap = Paint()..color = const Color(0xFF263238);
      final capH = max(3.0, rect.height * 0.36);
      final capW = max(1.6, rect.width * 0.035);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(center: Offset(rect.left + capW, rect.center.dy), width: capW, height: capH),
          const Radius.circular(1.2),
        ),
        cap,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(center: Offset(rect.right - capW, rect.center.dy), width: capW, height: capH),
          const Radius.circular(1.2),
        ),
        cap,
      );
    }

    final tube = rr.deflate(max(1.0, rect.shortestSide * 0.08));
    canvas.drawRRect(
      tube,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = max(1.3, rect.shortestSide * 0.16)
        ..color = neon.withValues(alpha: 0.36 * flicker),
    );
    canvas.drawRRect(
      tube,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = max(0.9, rect.shortestSide * 0.075)
        ..color = neon.withValues(alpha: 0.98 * flicker),
    );
    canvas.drawRRect(
      tube,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = max(0.45, rect.shortestSide * 0.03)
        ..color = Colors.white.withValues(alpha: 0.92 * flicker),
    );

    if (!innerFilament) return;
    final inner = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: rect.center,
        width: rect.width * 0.62,
        height: rect.height * 0.46,
      ),
      Radius.circular(radius * 0.45),
    );
    if (inner.width < 6 || inner.height < 3) return;
    canvas.drawRRect(
      inner,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = max(0.6, rect.shortestSide * 0.045)
        ..color = neon.withValues(alpha: 0.62 * flicker),
    );
    canvas.drawRRect(
      inner,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = max(0.35, rect.shortestSide * 0.02)
        ..color = Colors.white.withValues(alpha: 0.55 * flicker),
    );
  }

  void _drawCore(Canvas canvas, Offset c, double r, Color neon, double flicker, double open) {
    final glow = r * (1.55 + open * 0.35);
    canvas.drawCircle(c, glow, Paint()..color = neon.withValues(alpha: (0.30 + open * 0.2) * flicker));
    canvas.drawCircle(c, r, Paint()..color = neon);
    canvas.drawCircle(c, r * 0.42, Paint()..color = Colors.white.withValues(alpha: 0.96));
    canvas.drawCircle(
      Offset(c.dx - r * 0.28, c.dy - r * 0.30),
      r * 0.16,
      Paint()..color = Colors.white,
    );
    canvas.drawCircle(
      c,
      r * 1.28,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = max(0.8, r * 0.16)
        ..color = Colors.white.withValues(alpha: 0.82 * flicker),
    );
  }

  void _drawCavity(Canvas canvas, double w, double h, double open, Color neon) {
    final rect = Rect.fromLTWH(w * 0.20, h * 0.40, w * 0.60, h * 0.16 * open.clamp(0.2, 1.0));
    final rr = RRect.fromRectAndRadius(rect, Radius.circular(w * 0.04));
    canvas.drawRRect(
      rr,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            const Color(0xFF04060C),
            Color.lerp(const Color(0xFF0A1020), neon, 0.35)!,
          ],
        ).createShader(rect),
    );
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
