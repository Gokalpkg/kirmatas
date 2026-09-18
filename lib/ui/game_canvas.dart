import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import '../engine/asset_cache.dart';
import '../engine/game_controller.dart';
import '../models/brick.dart';
import '../models/game_state.dart';
import 'pixel_art.dart';

class GameCanvas extends StatefulWidget {
  final GameController controller;

  const GameCanvas({super.key, required this.controller});

  @override
  State<GameCanvas> createState() => _GameCanvasState();
}

class _GameCanvasState extends State<GameCanvas> with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  Duration _lastElapsed = Duration.zero;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker((elapsed) {
      if (_lastElapsed == Duration.zero) {
        _lastElapsed = elapsed;
        return;
      }
      final dt = (elapsed - _lastElapsed).inMicroseconds / 1000000.0;
      _lastElapsed = elapsed;
      widget.controller.update(dt.clamp(0.001, 0.05));
    });
    _ticker.start();
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        widget.controller.setDimensions(constraints.maxWidth, constraints.maxHeight);

        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onHorizontalDragUpdate: (details) {
            widget.controller.movePaddleBy(details.primaryDelta ?? 0);
          },
          onTapDown: (details) {
            if (widget.controller.status == GameStatus.ready || widget.controller.hasStuckBall) {
              widget.controller.launchBall();
            }
          },
          onDoubleTap: () {
            widget.controller.triggerUlti();
          },
          child: CustomPaint(
            size: Size(constraints.maxWidth, constraints.maxHeight),
            painter: _GameWorldPainter(widget.controller),
          ),
        );
      },
    );
  }
}

class _GameWorldPainter extends CustomPainter {
  final GameController c;

  static final Paint _fill = Paint()..isAntiAlias = true;
  static final Paint _stroke = Paint()
    ..isAntiAlias = true
    ..style = PaintingStyle.stroke;
  static final Paint _bgPaint = Paint()..style = PaintingStyle.fill;
  static final Paint _paddlePaint = Paint()..style = PaintingStyle.fill;
  static final Paint _imgPaint = Paint()..filterQuality = FilterQuality.medium;
  static final Path _crackPath = Path();
  static final TextPainter _tp = TextPainter(textDirection: TextDirection.ltr);

  static String? _cachedBgTheme;
  static Size? _cachedBgSize;
  static Shader? _cachedBgShader;
  static Shader? _cachedSunGlowShader;
  static Shader? _cachedSunPaintShader;

  _GameWorldPainter(this.c) : super(repaint: c);

  double get time => c.gameTime;

  @override
  void paint(Canvas canvas, Size size) {
    final shake = c.particles.getShakeOffset();
    canvas.save();
    canvas.translate(shake.dx, shake.dy);

    _drawBackground(canvas, size);
    _drawBricks(canvas);
    _drawNet(canvas, size);
    _drawPaddle(canvas);
    _drawCapsules(canvas);
    _drawProjectiles(canvas);
    _drawBalls(canvas);
    _drawDrone(canvas);
    _drawParticles(canvas);

    canvas.restore();
  }

  void _drawBackground(Canvas canvas, Size size) {
    final bgTheme = c.save.activeBackground;

    switch (bgTheme) {
      case 'bg_nebula':
        _drawNebulaBackground(canvas, size);
        break;
      case 'bg_matrix':
        _drawMatrixBackground(canvas, size);
        break;
      case 'bg_abyss':
        _drawAbyssBackground(canvas, size);
        break;
      case 'bg_sunset':
        _drawSunsetBackground(canvas, size);
        break;
      case 'bg_inferno':
        _drawInfernoBackground(canvas, size);
        break;
      case 'bg_default':
      default:
        _drawDefaultBackground(canvas, size);
        break;
    }
  }

  void _drawDefaultBackground(Canvas canvas, Size size) {
    if (_cachedBgShader == null || _cachedBgTheme != 'bg_default' || _cachedBgSize != size) {
      _cachedBgTheme = 'bg_default';
      _cachedBgSize = size;
      _cachedBgShader = const RadialGradient(
        center: Alignment(0, -0.3),
        radius: 1.25,
        colors: [Color(0xFF161B30), Color(0xFF090B14), Color(0xFF040508)],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));
    }
    _bgPaint.shader = _cachedBgShader;
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), _bgPaint);

    for (int i = 0; i < 36; i++) {
      final speed = 10.0 + (i % 4) * 4.0;
      final x = ((i * 97 + 23) % size.width.toInt()).toDouble();
      final y = ((i * 139 + time * speed) % size.height);
      final twinkle = 0.15 * sin(time * 2.5 + i);
      final alpha = (0.25 + (i % 4) * 0.15 + twinkle).clamp(0.1, 0.85);
      final isLarge = (i % 5 == 0);

      _fill.color = (i % 3 == 0 ? const Color(0xFF80D8FF) : Colors.white).withValues(alpha: alpha);
      canvas.drawCircle(Offset(x, y), isLarge ? 1.8 : 1.0, _fill);
    }
  }

  void _drawNebulaBackground(Canvas canvas, Size size) {
    if (_cachedBgShader == null || _cachedBgTheme != 'bg_nebula' || _cachedBgSize != size) {
      _cachedBgTheme = 'bg_nebula';
      _cachedBgSize = size;
      _cachedBgShader = const RadialGradient(
        center: Alignment(0, -0.2),
        radius: 1.3,
        colors: [Color(0xFF3B0764), Color(0xFF1E0B38), Color(0xFF0D031A)],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));
    }
    _bgPaint.shader = _cachedBgShader;
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), _bgPaint);

    for (int i = 0; i < 3; i++) {
      final cloudX = size.width * (0.25 + 0.5 * sin(time * 0.15 + i * 1.5));
      final cloudY = size.height * (0.2 + 0.3 * cos(time * 0.12 + i * 2.0));
      _fill.color = (i % 2 == 0 ? const Color(0xFFC084FC) : const Color(0xFFF472B6)).withValues(alpha: 0.1);
      canvas.drawCircle(Offset(cloudX, cloudY), 65.0 + 10 * sin(time + i), _fill);
    }

    for (int i = 0; i < 38; i++) {
      final speed = 12.0 + (i % 3) * 5.0;
      final x = ((i * 113 + 17) % size.width.toInt()).toDouble();
      final y = ((i * 157 + time * speed) % size.height);
      final twinkle = 0.2 * sin(time * 3.0 + i);
      final alpha = (0.3 + (i % 4) * 0.15 + twinkle).clamp(0.1, 0.9);
      final color = i % 3 == 0 ? const Color(0xFFE879F9) : (i % 3 == 1 ? const Color(0xFFA855F7) : Colors.white);
      _fill.color = color.withValues(alpha: alpha);
      canvas.drawCircle(Offset(x, y), (i % 6 == 0) ? 2.0 : 1.1, _fill);
    }
  }

  void _drawMatrixBackground(Canvas canvas, Size size) {
    if (_cachedBgShader == null || _cachedBgTheme != 'bg_matrix' || _cachedBgSize != size) {
      _cachedBgTheme = 'bg_matrix';
      _cachedBgSize = size;
      _cachedBgShader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xFF02130C), Color(0xFF010A06), Color(0xFF000503)],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));
    }
    _bgPaint.shader = _cachedBgShader;
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), _bgPaint);

    final vpX = size.width / 2;
    final vpY = size.height * 0.45;
    _stroke
      ..color = const Color(0xFF10B981).withValues(alpha: 0.18)
      ..strokeWidth = 1.0;

    for (int col = -6; col <= 6; col++) {
      final targetX = vpX + col * (size.width / 5);
      canvas.drawLine(Offset(vpX + col * 12, vpY), Offset(targetX, size.height), _stroke);
    }

    const scrollSpeed = 24.0;
    final cycle = (time * scrollSpeed) % 40.0;
    for (double y = vpY; y <= size.height; y += 20) {
      final progress = (y - vpY) / (size.height - vpY);
      final animatedY = vpY + pow(progress, 1.6) * (size.height - vpY) + cycle * progress * 0.5;
      if (animatedY <= size.height) {
        _stroke.color = const Color(0xFF10B981).withValues(alpha: (0.05 + progress * 0.2).clamp(0.0, 0.3));
        canvas.drawLine(
          Offset(0, animatedY),
          Offset(size.width, animatedY),
          _stroke,
        );
      }
    }

    for (int i = 0; i < 30; i++) {
      final speed = 18.0 + (i % 4) * 6.0;
      final x = ((i * 73 + 11) % size.width.toInt()).toDouble();
      final y = size.height - ((i * 127 + time * speed) % size.height);
      final alpha = (0.2 + (i % 3) * 0.2 + 0.1 * sin(time * 2 + i)).clamp(0.1, 0.8);
      _fill.color = const Color(0xFF34D399).withValues(alpha: alpha);
      canvas.drawRect(
        Rect.fromCenter(center: Offset(x, y), width: 2.0, height: 4.0),
        _fill,
      );
    }
  }

  void _drawAbyssBackground(Canvas canvas, Size size) {
    if (_cachedBgShader == null || _cachedBgTheme != 'bg_abyss' || _cachedBgSize != size) {
      _cachedBgTheme = 'bg_abyss';
      _cachedBgSize = size;
      _cachedBgShader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xFF03162C), Color(0xFF020D1A), Color(0xFF01060E)],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));
    }
    _bgPaint.shader = _cachedBgShader;
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), _bgPaint);

    final wavePath = Path();
    wavePath.moveTo(0, size.height * 0.3);
    for (double wx = 0; wx <= size.width; wx += 24) {
      wavePath.lineTo(wx, size.height * 0.3 + sin(wx * 0.015 + time * 0.8) * 24);
    }
    _stroke
      ..color = const Color(0xFF00E5FF).withValues(alpha: 0.1)
      ..strokeWidth = 14.0;
    canvas.drawPath(wavePath, _stroke);

    for (int i = 0; i < 35; i++) {
      final speed = 14.0 + (i % 4) * 5.0;
      final sway = sin(time * 1.5 + i) * 6.0;
      final x = (((i * 89 + 15) % size.width.toInt()) + sway).clamp(0.0, size.width);
      final y = size.height - ((i * 149 + time * speed) % size.height);
      final alpha = (0.25 + (i % 3) * 0.2 + 0.15 * sin(time * 2.0 + i)).clamp(0.1, 0.85);
      final isBubble = (i % 4 == 0);
      final pColor = i % 2 == 0 ? const Color(0xFF38BDF8) : const Color(0xFF2DD4BF);
      _fill.color = pColor.withValues(alpha: alpha);
      canvas.drawCircle(Offset(x, y), isBubble ? 2.2 : 1.2, _fill);
    }
  }

  void _drawSunsetBackground(Canvas canvas, Size size) {
    final sunY = size.height * 0.65;
    final sunRadius = size.width * 0.28;
    final sunCenter = Offset(size.width / 2, sunY);

    if (_cachedBgShader == null || _cachedBgTheme != 'bg_sunset' || _cachedBgSize != size) {
      _cachedBgTheme = 'bg_sunset';
      _cachedBgSize = size;
      _cachedBgShader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xFF1E072B), Color(0xFF3B0B47), Color(0xFF5B1647), Color(0xFF2B092B)],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));

      _cachedSunGlowShader = RadialGradient(
        colors: [
          const Color(0xFFFF5376).withValues(alpha: 0.35),
          const Color(0xFFFFB74D).withValues(alpha: 0.1),
          Colors.transparent,
        ],
      ).createShader(Rect.fromCircle(center: sunCenter, radius: sunRadius * 1.8));

      _cachedSunPaintShader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xFFFFEE58), Color(0xFFFF7043), Color(0xFFE91E63)],
      ).createShader(Rect.fromCircle(center: sunCenter, radius: sunRadius));
    }
    _bgPaint.shader = _cachedBgShader;
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), _bgPaint);

    _fill.shader = _cachedSunGlowShader;
    canvas.drawCircle(sunCenter, sunRadius * 1.8, _fill);
    _fill.shader = null;

    _fill.shader = _cachedSunPaintShader;
    canvas.drawCircle(sunCenter, sunRadius, _fill);
    _fill.shader = null;

    for (int i = 0; i < 30; i++) {
      final speed = 15.0 + (i % 3) * 6.0;
      final sway = sin(time * 1.8 + i) * 8.0;
      final x = (((i * 83 + 29) % size.width.toInt()) + sway).clamp(0.0, size.width);
      final y = size.height - ((i * 137 + time * speed) % size.height);
      final alpha = (0.2 + (i % 4) * 0.18 + 0.12 * sin(time * 3 + i)).clamp(0.1, 0.85);
      final color = i % 2 == 0 ? const Color(0xFFFFD54F) : const Color(0xFFFF7043);
      _fill.color = color.withValues(alpha: alpha);
      canvas.drawCircle(Offset(x, y), (i % 5 == 0) ? 2.0 : 1.2, _fill);
    }
  }

  void _drawInfernoBackground(Canvas canvas, Size size) {
    if (_cachedBgShader == null || _cachedBgTheme != 'bg_inferno' || _cachedBgSize != size) {
      _cachedBgTheme = 'bg_inferno';
      _cachedBgSize = size;
      _cachedBgShader = const RadialGradient(
        center: Alignment(0, 0.4),
        radius: 1.15,
        colors: [Color(0xFF330900), Color(0xFF1E0400), Color(0xFF0A0200)],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));
    }
    _bgPaint.shader = _cachedBgShader;
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), _bgPaint);

    _fill.color = const Color(0xFFFF5722).withValues(alpha: 0.1);
    canvas.drawCircle(Offset(size.width * 0.5, size.height * 0.8), size.width * 0.55 + sin(time * 1.5) * 15, _fill);

    for (int i = 0; i < 40; i++) {
      final speed = 20.0 + (i % 4) * 8.0;
      final sway = sin(time * 2.2 + i * 1.3) * 12.0;
      final x = (((i * 79 + 17) % size.width.toInt()) + sway).clamp(0.0, size.width);
      final y = size.height - ((i * 163 + time * speed) % size.height);
      final twinkle = 0.2 * sin(time * 4.0 + i);
      final alpha = (0.3 + (i % 4) * 0.15 + twinkle).clamp(0.1, 0.95);
      final isSpark = (i % 5 == 0);
      final color = i % 3 == 0 ? const Color(0xFFFFC107) : (i % 3 == 1 ? const Color(0xFFFF6D00) : const Color(0xFFFF3D00));
      _fill.color = color.withValues(alpha: alpha);
      canvas.drawCircle(Offset(x, y), isSpark ? 2.2 : 1.3, _fill);
    }
  }

  void _drawBricks(Canvas canvas) {
    for (final b in c.bricks) {
      if (!b.isAlive) continue;

      canvas.save();
      final cx = b.x + b.width / 2;
      final cy = b.y + b.height / 2;
      canvas.translate(cx, cy);

      // Jelly wobble
      if (b.jelly > 0) {
        final scale = 1.0 + sin(b.jelly * pi * 3) * 0.15;
        canvas.scale(scale, 1.0 / scale);
      }

      final halfW = b.width / 2;
      final halfH = b.height / 2;
      final rect = Rect.fromCenter(center: Offset.zero, width: b.width, height: b.height);
      final rrect = RRect.fromRectAndRadius(rect, const Radius.circular(6.0));

      if (b.isTuft) {
        // Tufting yarn cell: textured canvas with cross-stitches
        _fill.color = b.tuftFilled ? b.tuftColor : b.tuftColor.withValues(alpha: 0.25);
        canvas.drawRRect(rrect, _fill);

        // Yarn thread stitches
        _stroke
          ..color = b.tuftFilled ? Colors.white70 : b.tuftColor.withValues(alpha: 0.6)
          ..strokeWidth = 1.5;
        canvas.drawLine(Offset(-halfW + 4, -halfH + 4), Offset(halfW - 4, halfH - 4), _stroke);
        canvas.drawLine(Offset(-halfW + 4, halfH - 4), Offset(halfW - 4, -halfH + 4), _stroke);

        _stroke
          ..color = b.tuftColor
          ..strokeWidth = 1.8;
        canvas.drawRRect(rrect, _stroke);

      } else if (b.isSteel) {
        // Heavy Industrial Titanium Plate
        _fill.color = const Color(0xFF37474F);
        canvas.drawRRect(rrect, _fill);

        // 3D Bevel highlight and shadow
        _stroke
          ..color = const Color(0xFF78909C)
          ..strokeWidth = 2.0;
        canvas.drawLine(Offset(-halfW + 2, -halfH + 1), Offset(halfW - 2, -halfH + 1), _stroke);
        _stroke.color = const Color(0xFF1C2833);
        canvas.drawLine(Offset(-halfW + 2, halfH - 1), Offset(halfW - 2, halfH - 1), _stroke);

        // Heavy steel diagonal hazard pattern
        _stroke
          ..color = const Color(0x33CFD8DC)
          ..strokeWidth = 3.0;
        for (double sx = -halfW + 4; sx < halfW; sx += 12) {
          canvas.drawLine(Offset(sx, halfH - 3), Offset(sx + 8, -halfH + 3), _stroke);
        }

        // Heavy corner rivets
        _fill.color = Colors.white70;
        canvas.drawCircle(Offset(-halfW + 4, -halfH + 4), 1.5, _fill);
        canvas.drawCircle(Offset(halfW - 4, -halfH + 4), 1.5, _fill);
        canvas.drawCircle(Offset(-halfW + 4, halfH - 4), 1.5, _fill);
        canvas.drawCircle(Offset(halfW - 4, halfH - 4), 1.5, _fill);

      } else if (b.isBoss) {
        _drawBoss(canvas, b, time, halfW, halfH);
      } else {
        // MODERN ARCADE CRYSTAL TILE
        // Base Gem Body
        _fill.color = b.color;
        canvas.drawRRect(rrect, _fill);

        // Chamfered 3D edge lines (light top-left, dark bottom-right)
        _stroke
          ..color = Colors.white.withValues(alpha: 0.45)
          ..strokeWidth = 1.5;
        canvas.drawLine(Offset(-halfW + 3, -halfH + 1.5), Offset(halfW - 3, -halfH + 1.5), _stroke);
        canvas.drawLine(Offset(-halfW + 1.5, -halfH + 3), Offset(-halfW + 1.5, halfH - 3), _stroke);

        _stroke.color = Colors.black.withValues(alpha: 0.45);
        canvas.drawLine(Offset(-halfW + 3, halfH - 1.5), Offset(halfW - 3, halfH - 1.5), _stroke);
        canvas.drawLine(Offset(halfW - 1.5, -halfH + 3), Offset(halfW - 1.5, halfH - 3), _stroke);

        // Inner crystal core
        final innerRect = Rect.fromCenter(center: Offset.zero, width: b.width - 4, height: b.height - 4);
        final innerRRect = RRect.fromRectAndRadius(innerRect, const Radius.circular(4.0));
        _fill.color = b.color.withValues(alpha: 0.85);
        canvas.drawRRect(innerRRect, _fill);

        // MULTI-HIT INDICATOR & DAMAGE CRACKS
        if (b.maxHp >= 2) {
          // Cyber Armored Corner Brackets
          _stroke
            ..color = Colors.white.withValues(alpha: 0.75)
            ..strokeWidth = 1.5;
          // Top-Left bracket
          canvas.drawLine(Offset(-halfW + 2, -halfH + 5), Offset(-halfW + 2, -halfH + 2), _stroke);
          canvas.drawLine(Offset(-halfW + 2, -halfH + 2), Offset(-halfW + 5, -halfH + 2), _stroke);
          // Top-Right bracket
          canvas.drawLine(Offset(halfW - 5, -halfH + 2), Offset(halfW - 2, -halfH + 2), _stroke);
          canvas.drawLine(Offset(halfW - 2, -halfH + 2), Offset(halfW - 2, -halfH + 5), _stroke);
          // Bottom-Left bracket
          canvas.drawLine(Offset(-halfW + 2, halfH - 5), Offset(-halfW + 2, halfH - 2), _stroke);
          canvas.drawLine(Offset(-halfW + 2, halfH - 2), Offset(-halfW + 5, halfH - 2), _stroke);
          // Bottom-Right bracket
          canvas.drawLine(Offset(halfW - 5, halfH - 2), Offset(halfW - 2, halfH - 2), _stroke);
          canvas.drawLine(Offset(halfW - 2, halfH - 2), Offset(halfW - 2, halfH - 5), _stroke);

          // Center Health Pips (dots indicating remaining HP)
          const pipSpacing = 10.0;
          final totalPipsW = (b.maxHp - 1) * pipSpacing;
          final startPipX = -totalPipsW / 2;

          for (int p = 0; p < b.maxHp; p++) {
            final pipX = startPipX + p * pipSpacing;
            final isFull = p < b.hp;
            _fill.color = isFull ? Colors.white : Colors.black45;
            canvas.drawCircle(Offset(pipX, 0), isFull ? 2.5 : 2.0, _fill);
            if (isFull) {
              _fill.color = const Color(0xFFFFD54F);
              canvas.drawCircle(Offset(pipX, 0), 1.2, _fill);
            }
          }

          // Dynamic Damage Crack Lines if damaged
          if (b.hp < b.maxHp) {
            _crackPath.reset();
            _crackPath.moveTo(-halfW * 0.45, -halfH * 0.6);
            _crackPath.lineTo(-halfW * 0.15, -halfH * 0.1);
            _crackPath.lineTo(-halfW * 0.35, halfH * 0.2);
            _crackPath.lineTo(-halfW * 0.1, halfH * 0.65);
            _crackPath.moveTo(-halfW * 0.15, -halfH * 0.1);
            _crackPath.lineTo(halfW * 0.25, -halfH * 0.3);
            _crackPath.lineTo(halfW * 0.45, -halfH * 0.65);

            _stroke
              ..color = Colors.white.withValues(alpha: 0.9)
              ..strokeWidth = 1.6
              ..strokeCap = StrokeCap.round;
            canvas.drawPath(_crackPath, _stroke);
            _stroke.strokeCap = StrokeCap.butt;
          }
        }
      }

      canvas.restore();
    }
  }

  void _drawBoss(Canvas canvas, Brick b, double time, double halfW, double halfH) {
    final hpPct = (b.hp / b.maxHp).clamp(0.0, 1.0);

    // 1. Dual Thruster Glow / Exhaust
    final thrustPulse = 3.5 + sin(time * 12.0) * 2.0;
    _fill.color = const Color(0xFFFF5722).withValues(alpha: 0.85);
    canvas.drawOval(Rect.fromCenter(center: Offset(-halfW * 0.65, -halfH - 2), width: 14, height: thrustPulse), _fill);
    canvas.drawOval(Rect.fromCenter(center: Offset(halfW * 0.65, -halfH - 2), width: 14, height: thrustPulse), _fill);

    // 2. Heavy Armored Hull Base (Dark Titanium Mecha)
    final hullRRect = RRect.fromRectAndRadius(
      Rect.fromCenter(center: Offset.zero, width: b.width, height: b.height),
      const Radius.circular(8.0),
    );
    _fill.color = const Color(0xFF141724);
    canvas.drawRRect(hullRRect, _fill);

    // 3. Wing Armor Plates & Hazard Stripes
    final wingW = halfW * 0.35;
    _fill.color = const Color(0xFF1F2538);
    // Left Wing
    final leftWingRect = Rect.fromLTWH(-halfW, -halfH, wingW, b.height);
    canvas.drawRRect(RRect.fromRectAndRadius(leftWingRect, const Radius.circular(6.0)), _fill);
    // Right Wing
    final rightWingRect = Rect.fromLTWH(halfW - wingW, -halfH, wingW, b.height);
    canvas.drawRRect(RRect.fromRectAndRadius(rightWingRect, const Radius.circular(6.0)), _fill);

    // Hazard Stripes on wing panels (black and yellow arcade stripes)
    _stroke
      ..color = const Color(0xFFFFC107)
      ..strokeWidth = 2.0;
    for (int s = -1; s <= 1; s++) {
      canvas.drawLine(Offset(-halfW + 10 + s * 6, -halfH + 4), Offset(-halfW + 16 + s * 6, halfH - 4), _stroke);
      canvas.drawLine(Offset(halfW - wingW + 10 + s * 6, -halfH + 4), Offset(halfW - wingW + 16 + s * 6, halfH - 4), _stroke);
    }

    // 4. Dual Plasma Cannons on Gun Mounts
    _fill.color = const Color(0xFF37474F);
    // Left Cannon
    canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromCenter(center: Offset(-halfW * 0.5, halfH + 4), width: 10, height: 12), const Radius.circular(2)), _fill);
    _fill.color = const Color(0xFFFF1744).withValues(alpha: 0.75 + sin(time * 8.0) * 0.25);
    canvas.drawCircle(Offset(-halfW * 0.5, halfH + 9), 3.0, _fill);
    // Right Cannon
    _fill.color = const Color(0xFF37474F);
    canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromCenter(center: Offset(halfW * 0.5, halfH + 4), width: 10, height: 12), const Radius.circular(2)), _fill);
    _fill.color = const Color(0xFFFF1744).withValues(alpha: 0.75 + sin(time * 8.0) * 0.25);
    canvas.drawCircle(Offset(halfW * 0.5, halfH + 9), 3.0, _fill);

    // 5. Central Reactor Chassis
    final centerW = halfW * 0.65;
    final centerRect = Rect.fromCenter(center: Offset.zero, width: centerW * 2, height: b.height - 4);
    _fill.color = const Color(0xFF262D42);
    canvas.drawRRect(RRect.fromRectAndRadius(centerRect, const Radius.circular(5.0)), _fill);

    // Beveled armor highlight
    _stroke
      ..color = const Color(0xFF5C6B8A)
      ..strokeWidth = 1.2;
    canvas.drawLine(Offset(-centerW + 2, -halfH + 3), Offset(centerW - 2, -halfH + 3), _stroke);

    // 6. Central Cyber Robotic Visor / Laser Eye
    final eyeW = centerW * 0.7;
    final eyeRect = Rect.fromCenter(center: const Offset(0, 1), width: eyeW * 2, height: 13.0);
    _fill.color = const Color(0xFF0A0D14);
    canvas.drawRRect(RRect.fromRectAndRadius(eyeRect, const Radius.circular(3.0)), _fill);

    // Scanning red laser beam across visor
    final scanX = sin(time * 5.0) * (eyeW - 6.0);
    _fill.color = const Color(0xFFFF1744);
    canvas.drawCircle(Offset(scanX, 1), 4.5, _fill);
    _fill.color = Colors.white;
    canvas.drawCircle(Offset(scanX, 1), 2.0, _fill);

    // Neon Circuit Energy Conduits
    _stroke
      ..color = const Color(0xFF00E5FF).withValues(alpha: 0.6)
      ..strokeWidth = 1.2;
    canvas.drawLine(Offset(-eyeW, -halfH + 7), Offset(-centerW + 5, -halfH + 7), _stroke);
    canvas.drawLine(Offset(eyeW, -halfH + 7), Offset(centerW - 5, -halfH + 7), _stroke);

    // Rivets / Bolts
    _fill.color = const Color(0xFF90A4AE);
    canvas.drawCircle(Offset(-halfW + 5, -halfH + 5), 1.2, _fill);
    canvas.drawCircle(Offset(halfW - 5, -halfH + 5), 1.2, _fill);
    canvas.drawCircle(Offset(-halfW + 5, halfH - 5), 1.2, _fill);
    canvas.drawCircle(Offset(halfW - 5, halfH - 5), 1.2, _fill);

    // 7. Outer Pulsing Shield / Forcefield
    final shieldPulse = sin(time * 4.0) * 0.2 + 0.8;
    _stroke
      ..color = const Color(0xFFFF1744).withValues(alpha: 0.35 * shieldPulse)
      ..strokeWidth = 2.0;
    canvas.drawRRect(hullRRect, _stroke);

    // 8. Armored Floating Boss Health Bar
    final barW = b.width;
    const barH = 5.5;
    final barY = -halfH - 12.0;
    // Bar frame container
    _fill.color = const Color(0xDD000000);
    canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(-halfW, barY, barW, barH), const Radius.circular(2.5)), _fill);
    // Bar gradient fill (Green to Yellow to Red depending on HP)
    final hpColor = hpPct > 0.5
        ? Color.lerp(const Color(0xFFFFEB3B), const Color(0xFF00E676), (hpPct - 0.5) * 2)!
        : Color.lerp(const Color(0xFFFF1744), const Color(0xFFFFEB3B), hpPct * 2)!;
    _fill.color = hpColor;
    canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(-halfW, barY, barW * hpPct, barH), const Radius.circular(2.5)), _fill);
    // Segment dividers
    _stroke
      ..color = const Color(0x66000000)
      ..strokeWidth = 1.0;
    for (int d = 1; d < 5; d++) {
      final divX = -halfW + (barW * d / 5);
      canvas.drawLine(Offset(divX, barY), Offset(divX, barY + barH), _stroke);
    }
  }

  void _drawNet(Canvas canvas, Size size) {
    if (!c.paddle.hasNet) return;
    final y = size.height - 22.0;
    _stroke
      ..color = const Color(0xFF8BC34A).withValues(alpha: 0.75)
      ..strokeWidth = 3.0;
    canvas.drawLine(Offset(0, y), Offset(size.width, y), _stroke);

    _stroke
      ..color = const Color(0x338BC34A)
      ..strokeWidth = 6.0;
    canvas.drawLine(Offset(0, y), Offset(size.width, y), _stroke);
  }

  void _drawPaddle(Canvas canvas) {
    final p = c.paddle;
    final rect = p.rect;
    final rrect = RRect.fromRectAndRadius(rect, Radius.circular(rect.height / 2));
    final alphaMul = p.isGhost ? 0.35 : 1.0;

    canvas.save();

    // Outer glow ring (high-performance crisp stroke)
    _stroke
      ..color = c.activePaddleSkin.glowColor.withValues(alpha: 0.35 * alphaMul)
      ..strokeWidth = 4.0;
    canvas.drawRRect(rrect.inflate(2.0), _stroke);

    // Paddle body gradient
    _paddlePaint.shader = LinearGradient(
      colors: [
        c.activePaddleSkin.color1.withValues(alpha: alphaMul),
        c.activePaddleSkin.color2.withValues(alpha: alphaMul),
      ],
      begin: Alignment.centerLeft,
      end: Alignment.centerRight,
    ).createShader(rect);
    canvas.drawRRect(rrect, _paddlePaint);

    // Specular highlight
    final gloss = Rect.fromLTWH(rect.left + 4, rect.top + 2, rect.width - 8, rect.height * 0.38);
    _fill.color = Colors.white.withValues(alpha: 0.35 * alphaMul);
    canvas.drawRRect(RRect.fromRectAndRadius(gloss, const Radius.circular(4)), _fill);

    // Laser cannons
    if (p.hasLaser) {
      _fill.color = const Color(0xFFFFD740);
      canvas.drawRect(Rect.fromLTWH(rect.left + 2, rect.top - 5, 5, 5), _fill);
      canvas.drawRect(Rect.fromLTWH(rect.right - 7, rect.top - 5, 5, 5), _fill);
    }

    canvas.restore();
  }

  void _drawBalls(Canvas canvas) {
    for (final ball in c.balls) {
      // Trail
      for (int i = 0; i < ball.trail.length; i++) {
        final pt = ball.trail[i];
        final progress = 1.0 - (i / ball.trail.length);
        final trailColor = c.activeBallSkin.glowColor.withValues(alpha: progress * 0.55);
        final trailRadius = ball.radius * progress * 0.75;
        _fill.color = trailColor;
        canvas.drawCircle(pt.position, trailRadius, _fill);
      }

      canvas.save();
      canvas.translate(ball.x, ball.y);

      // Squash & Stretch
      if (ball.squashTimer > 0) {
        canvas.rotate(ball.squashAngle);
        final factor = 1.0 + (ball.squashTimer / 0.22) * 0.4;
        canvas.scale(factor, 1.0 / factor);
        canvas.rotate(-ball.squashAngle);
      }

      // Corner speed boost aura
      if (ball.cornerBoostTimer > 0) {
        _fill.color = const Color(0xFFFFD54F).withValues(alpha: 0.45);
        canvas.drawCircle(Offset.zero, ball.radius + 6.0, _fill);
        _stroke
          ..color = const Color(0xFFFFEA00)
          ..strokeWidth = 1.8;
        canvas.drawCircle(Offset.zero, ball.radius + 4.5, _stroke);
      }

      // Ball Aura/Glow (fast concentric alpha)
      final glowColor = ball.isFireball ? const Color(0xFFFF6D00) : c.activeBallSkin.glowColor;
      _fill.color = glowColor.withValues(alpha: 0.28);
      canvas.drawCircle(Offset.zero, ball.radius + 3.0, _fill);

      // Ball Core
      final coreColor = ball.isFireball
          ? const Color(0xFFFFD54F)
          : (ball.isBomb ? const Color(0xFFFF5252) : c.activeBallSkin.mainColor);
      _fill.color = coreColor;
      canvas.drawCircle(Offset.zero, ball.radius, _fill);

      // Specular dot
      _fill.color = Colors.white.withValues(alpha: 0.85);
      canvas.drawCircle(Offset(-ball.radius * 0.35, -ball.radius * 0.35), ball.radius * 0.35, _fill);

      canvas.restore();
    }
  }

  void _drawDrone(Canvas canvas) {
    if (!c.paddle.hasDrone) return;
    final p = c.paddle;
    final dx = p.x + p.width / 2 + cos(p.droneAngle) * 44.0;
    final dy = p.y - 20.0 + sin(p.droneAngle) * 16.0;

    _fill.color = const Color(0xFF00E676);
    canvas.drawCircle(Offset(dx, dy), 6.0, _fill);
    _fill.color = Colors.white;
    canvas.drawCircle(Offset(dx, dy), 2.5, _fill);
  }

  void _drawCapsules(Canvas canvas) {
    for (final cap in c.capsules) {
      canvas.save();
      canvas.translate(cap.x, cap.y);
      final bob = sin(cap.animTimer * 6.0) * 2.5;
      canvas.translate(0, bob);

      final img = AssetCache.instance.getSkillImage(cap.type);
      if (img != null) {
        // Draw skill pixel art enlarged directly, NO circular backgrounds
        final src = Rect.fromLTWH(0, 0, img.width.toDouble(), img.height.toDouble());
        final dst = Rect.fromCenter(center: Offset.zero, width: 34.0, height: 34.0);
        canvas.drawImageRect(img, src, dst, _imgPaint);
      } else {
        PixelArt.draw(canvas, cap.type, Offset.zero, 34.0);
      }

      canvas.restore();
    }
  }

  void _drawProjectiles(Canvas canvas) {
    for (final p in c.projectiles) {
      if (p.isBossBullet) {
        _fill.color = const Color(0xFFFF1744);
        canvas.drawCircle(Offset(p.x, p.y), p.radius, _fill);
      } else if (p.isRocket) {
        _fill.color = const Color(0xFFFF5722);
        canvas.drawOval(Rect.fromCenter(center: Offset(p.x, p.y), width: 6, height: 14), _fill);
      } else {
        // Laser
        _stroke
          ..color = const Color(0xFFFFD740)
          ..strokeWidth = 3.5
          ..strokeCap = StrokeCap.round;
        canvas.drawLine(Offset(p.x, p.y), Offset(p.x, p.y - 14), _stroke);
      }
    }
  }

  void _drawParticles(Canvas canvas) {
    for (final p in c.particles.particles) {
      final progress = (p.life / p.maxLife).clamp(0.0, 1.0);
      _fill.color = p.color.withValues(alpha: progress);
      canvas.drawCircle(Offset(p.x, p.y), p.size * progress, _fill);
    }

    for (final s in c.particles.shockwaves) {
      final alpha = (1.0 - s.progress).clamp(0.0, 1.0);
      _stroke
        ..color = s.color.withValues(alpha: alpha * 0.75)
        ..strokeWidth = 2.5 * (1.0 - s.progress) + 0.5;
      canvas.drawCircle(Offset(s.x, s.y), s.currentRadius, _stroke);
    }

    for (final f in c.particles.floatingTexts) {
      final alpha = (f.life / f.maxLife).clamp(0.0, 1.0);
      _tp.text = TextSpan(
        text: f.text,
        style: TextStyle(
          color: f.color.withValues(alpha: alpha),
          fontSize: f.isLarge ? 22.0 : 13.0,
          fontWeight: FontWeight.w900,
          shadows: const [
            Shadow(color: Colors.black87, blurRadius: 4, offset: Offset(1, 2)),
          ],
        ),
      );
      _tp.layout();
      _tp.paint(canvas, Offset(f.x - _tp.width / 2, f.y));
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
