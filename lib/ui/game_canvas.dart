import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import '../engine/asset_cache.dart';
import '../engine/audio_manager.dart';
import '../engine/game_controller.dart';
import '../models/brick.dart';
import '../models/game_state.dart';
import '../models/ball.dart';
import '../models/powerup.dart';
import 'pixel_art.dart';
import '../models/cosmetics.dart';

class GameCanvas extends StatefulWidget {
  final GameController controller;

  const GameCanvas({super.key, required this.controller});

  @override
  State<GameCanvas> createState() => _GameCanvasState();
}

class _GameCanvasState extends State<GameCanvas> with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  Duration _lastElapsed = Duration.zero;
  double _pointerStartX = 0;
  bool _pointerMoved = false;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker((elapsed) {
      if (_lastElapsed == Duration.zero) {
        _lastElapsed = elapsed;
        return;
      }
      if (!AudioManager.instance.appInForeground) {
        _lastElapsed = Duration.zero;
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

        return Listener(
          behavior: HitTestBehavior.opaque,
          onPointerDown: (event) {
            _pointerStartX = event.localPosition.dx;
            _pointerMoved = false;
          },
          onPointerMove: (event) {
            final dx = event.delta.dx;
            if (!_pointerMoved && (event.localPosition.dx - _pointerStartX).abs() < 8) {
              return;
            }
            _pointerMoved = true;
            widget.controller.movePaddleBy(dx);
          },
          onPointerUp: (_) {
            final controller = widget.controller;
            if (!_pointerMoved &&
                (controller.status == GameStatus.ready || controller.hasStuckBall)) {
              controller.launchBall();
            }
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
  static final Path _sparkPath = Path();
  static final Path _tempPath = Path();
  static final TextPainter _tp = TextPainter(textDirection: TextDirection.ltr);

  static final Path _splatPath1 = Path();
  static final Path _splatPath2 = Path();
  static final Path _splatPath3 = Path();
  static bool _splatPathsInitialized = false;
  static final Map<int, Color> _alphaColors = {};
  static final Map<int, Shader> _skinShaders = {};
  static final Map<int, Shader> _holeShaders = {};

  static Color _ca(Color color, double alpha) {
    final bucket = (alpha * 32).round().clamp(0, 32);
    final key = (color.toARGB32() << 6) ^ bucket;
    final cached = _alphaColors[key];
    if (cached != null) return cached;
    final made = color.withValues(alpha: bucket / 32.0);
    if (_alphaColors.length > 512) {
      _alphaColors.remove(_alphaColors.keys.first);
    }
    _alphaColors[key] = made;
    return made;
  }

  static void _ensureSplatPaths() {
    if (_splatPathsInitialized) return;
    _splatPathsInitialized = true;
    const pixelSize = 1.6;
    final matrix = PixelArt.bugSplatMatrix;
    for (int r = 0; r < matrix.length; r++) {
      for (int c = 0; c < matrix[r].length; c++) {
        final val = matrix[r][c];
        if (val == 0) continue;
        final rect = Rect.fromLTWH(c * pixelSize, r * pixelSize, pixelSize, pixelSize);
        if (val == 1) {
          _splatPath1.addRect(rect);
        } else if (val == 2) {
          _splatPath2.addRect(rect);
        } else if (val == 3) {
          _splatPath3.addRect(rect);
        }
      }
    }
  }

  static String? _cachedBgTheme;
  static Size? _cachedBgSize;
  static Shader? _cachedBgShader;
  static Shader? _cachedSunGlowShader;
  static Shader? _cachedSunPaintShader;

  _GameWorldPainter(this.c) : super(repaint: c.frameTick);

  double get time => c.gameTime;

  @override
  void paint(Canvas canvas, Size size) {
    final shake = c.particles.getShakeOffset();
    canvas.save();
    canvas.translate(shake.dx, shake.dy);

    _drawBackground(canvas, size);
    _drawBlackHoles(canvas);
    _drawPortals(canvas);
    _drawBricks(canvas);
    _drawNet(canvas, size);
    _drawPaddle(canvas);
    _drawCapsules(canvas);
    _drawProjectiles(canvas);
    _drawBalls(canvas);
    _drawBee(canvas);
    _drawDrone(canvas);
    _drawDice(canvas);
    _drawParticles(canvas);

    canvas.restore();

    _drawWindshieldSplat(canvas, size);
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

      _fill.color = _ca((i % 3 == 0 ? const Color(0xFF80D8FF) : Colors.white), alpha);
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
      _fill.color = _ca((i % 2 == 0 ? const Color(0xFFC084FC) : const Color(0xFFF472B6)), 0.1);
      canvas.drawCircle(Offset(cloudX, cloudY), 65.0 + 10 * sin(time + i), _fill);
    }

    for (int i = 0; i < 38; i++) {
      final speed = 12.0 + (i % 3) * 5.0;
      final x = ((i * 113 + 17) % size.width.toInt()).toDouble();
      final y = ((i * 157 + time * speed) % size.height);
      final twinkle = 0.2 * sin(time * 3.0 + i);
      final alpha = (0.3 + (i % 4) * 0.15 + twinkle).clamp(0.1, 0.9);
      final color = i % 3 == 0 ? const Color(0xFFE879F9) : (i % 3 == 1 ? const Color(0xFFA855F7) : Colors.white);
      _fill.color = _ca(color, alpha);
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
      ..color = _ca(const Color(0xFF10B981), 0.18)
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
        _stroke.color = _ca(const Color(0xFF10B981), (0.05 + progress * 0.2).clamp(0.0, 0.3));
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
      _fill.color = _ca(const Color(0xFF34D399), alpha);
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
      ..color = _ca(const Color(0xFF00E5FF), 0.1)
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
      _fill.color = _ca(pColor, alpha);
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
          _ca(const Color(0xFFFF5376), 0.35),
          _ca(const Color(0xFFFFB74D), 0.1),
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
      _fill.color = _ca(color, alpha);
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

    _fill.color = _ca(const Color(0xFFFF5722), 0.1);
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
      _fill.color = _ca(color, alpha);
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
        _fill.color = b.tuftFilled ? b.tuftColor : _ca(b.tuftColor, 0.25);
        canvas.drawRRect(rrect, _fill);

        // Yarn thread stitches
        _stroke
          ..color = b.tuftFilled ? Colors.white70 : _ca(b.tuftColor, 0.6)
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
        switch (c.save.activeBrickStyle) {
          case 'brick_gloss':
            _drawGlossBrick(canvas, b, rect, rrect, halfW, halfH);
            break;
          case 'brick_neu':
            _drawNeuBrick(canvas, b, rrect);
            break;
          case 'brick_pixel':
            _drawPixelBrick(canvas, b, rect, halfW, halfH);
            break;
          case 'brick_cyber':
            _drawCyberBrick(canvas, b, rrect, halfW, halfH);
            break;
          case 'brick_cosmic':
            _drawCosmicBrick(canvas, b, rrect, halfW, halfH);
            break;
          default:
            _drawNeonBrick(canvas, b, rrect);
            break;
        }

        // Damage Cracks (drawn on top of the base brick, without numbers or dots)
        if (b.hp < b.maxHp && b.maxHp > 1 && b.hp > 0) {
          _stroke..color = _ca(Colors.white, 0.85)..strokeWidth = 1.5;
          _crackPath.reset();
          _crackPath.moveTo(0, -halfH + 2);
          _crackPath.lineTo(-halfW * 0.3, -halfH * 0.2);
          _crackPath.lineTo(halfW * 0.2, halfH * 0.1);
          _crackPath.lineTo(-halfW * 0.1, halfH - 2);
          if (b.hp <= b.maxHp - 2) {
            _crackPath.moveTo(-halfW + 2, 0);
            _crackPath.lineTo(-halfW * 0.2, -halfH * 0.3);
            _crackPath.lineTo(halfW - 2, -halfH * 0.1);
          }
          canvas.drawPath(_crackPath, _stroke);
        }

        if (b.isDynamite) {
          final pulse = sin(time * 8) * 0.5 + 0.5;
          _fill.color = Color.lerp(Colors.redAccent, Colors.orangeAccent, pulse)!;
          canvas.drawCircle(Offset.zero, 6.0 + pulse * 2.0, _fill);
          _fill.color = Colors.yellow;
          canvas.drawCircle(Offset.zero, 3.0, _fill);
          _stroke..color = Colors.black54..strokeWidth = 2.0;
          _tempPath
            ..reset()
            ..moveTo(0, -6)
            ..quadraticBezierTo(5, -12, -4, -16);
          canvas.drawPath(_tempPath, _stroke);
          _fill.color = Colors.redAccent;
          canvas.drawCircle(const Offset(-4, -16), 1.5, _fill);
        }

        if (b.isIce) {
          _stroke..color = _ca(Colors.cyanAccent, 0.6)..strokeWidth = 2.0;
          canvas.drawRect(Rect.fromCenter(center: Offset.zero, width: b.width - 6, height: b.height - 6), _stroke);
          _fill.color = _ca(Colors.white, 0.3);
          canvas.drawCircle(Offset.zero, 4.0, _fill);
          canvas.drawLine(const Offset(-6, -6), const Offset(6, 6), _stroke);
          canvas.drawLine(const Offset(6, -6), const Offset(-6, 6), _stroke);
        }

        if (b.isFrozen) {
          _fill.color = const Color(0x6680D8FF);
          canvas.drawRRect(rrect, _fill);
          _stroke..color = Colors.white..strokeWidth = 2.0;
          canvas.drawRRect(rrect, _stroke);
          _stroke..color = const Color(0xFFE0F7FA)..strokeWidth = 1.0;
          canvas.drawLine(Offset(-halfW + 4, -halfH + 2), Offset(halfW - 4, -halfH + 2), _stroke);
          canvas.drawLine(Offset(halfW - 2, -halfH + 4), Offset(halfW - 2, halfH - 4), _stroke);
        }
      }

      canvas.restore();
    }
  }

  void _drawNeonBrick(Canvas canvas, Brick b, RRect rrect) {
    final base = b.color;
    // Dark crystal glass backing
    _fill.color = const Color(0xFF070913);
    canvas.drawRRect(rrect, _fill);

    // Inner subtle glow tint
    _fill.color = _ca(base, 0.15);
    canvas.drawRRect(rrect.deflate(2.0), _fill);

    // Broad outer neon tube bloom
    _stroke
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5.5
      ..color = _ca(base, 0.25)
      ..maskFilter = null;
    canvas.drawRRect(rrect, _stroke);

    // Main vibrant neon tube
    _stroke
      ..strokeWidth = 2.2
      ..color = _ca(base, 0.95);
    canvas.drawRRect(rrect, _stroke);

    // Ultra-bright white neon cathode core
    _stroke
      ..strokeWidth = 1.0
      ..color = _ca(Colors.white, 0.9);
    canvas.drawRRect(rrect.deflate(0.5), _stroke);

    // Neon corner bracket accents
    final rect = rrect.outerRect;
    final bracketLen = min(rect.width * 0.22, 9.0);
    _stroke
      ..strokeWidth = 2.0
      ..color = Colors.white;
    // Top-left bracket
    canvas.drawLine(Offset(rect.left + 3, rect.top + 3 + bracketLen), Offset(rect.left + 3, rect.top + 3), _stroke);
    canvas.drawLine(Offset(rect.left + 3, rect.top + 3), Offset(rect.left + 3 + bracketLen, rect.top + 3), _stroke);
    // Bottom-right bracket
    canvas.drawLine(Offset(rect.right - 3 - bracketLen, rect.bottom - 3), Offset(rect.right - 3, rect.bottom - 3), _stroke);
    canvas.drawLine(Offset(rect.right - 3, rect.bottom - 3), Offset(rect.right - 3, rect.bottom - 3 - bracketLen), _stroke);
  }

  void _drawGlossBrick(Canvas canvas, Brick b, Rect rect, RRect rrect, double halfW, double halfH) {
    final hsl = HSLColor.fromColor(b.color);
    final dark = hsl.withLightness((hsl.lightness * 0.4).clamp(0.08, 0.35)).toColor();
    final bright = hsl.withLightness((hsl.lightness * 1.35).clamp(0.65, 0.98)).toColor();

    // 3D bottom extrusion drop shadow
    final bottomRRect = RRect.fromRectAndRadius(rect.translate(0, 2.5), const Radius.circular(6.0));
    _fill.color = dark;
    canvas.drawRRect(bottomRRect, _fill);

    // Main vibrant candy body gradient
    _fill.shader = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [bright, b.color, dark],
      stops: const [0.0, 0.55, 1.0],
    ).createShader(rect);
    canvas.drawRRect(rrect, _fill);
    _fill.shader = null;

    // Curved convex glassy reflection dome on upper half
    final glossRect = Rect.fromLTWH(rect.left + 3, rect.top + 1.5, rect.width - 6, rect.height * 0.44);
    final glossRRect = RRect.fromRectAndRadius(glossRect, const Radius.circular(4.0));
    _fill.shader = const LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [Color(0xCCFFFFFF), Color(0x00FFFFFF)],
    ).createShader(glossRect);
    canvas.drawRRect(glossRRect, _fill);
    _fill.shader = null;

    // Specular rim shine
    _stroke
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..color = _ca(Colors.white, 0.65);
    canvas.drawRRect(rrect, _stroke);

    // Subtle bottom bounce highlight
    _stroke
      ..strokeWidth = 1.0
      ..color = _ca(bright, 0.5);
    canvas.drawLine(Offset(rect.left + 6, rect.bottom - 2), Offset(rect.right - 6, rect.bottom - 2), _stroke);
  }

  void _drawNeuBrick(Canvas canvas, Brick b, RRect rrect) {
    // Neumorphic soft embossed stone/clay button
    final hsl = HSLColor.fromColor(b.color);
    final softLight = hsl.withLightness((hsl.lightness * 1.4).clamp(0.6, 0.95)).toColor();
    final softDark = hsl.withLightness((hsl.lightness * 0.55).clamp(0.12, 0.45)).toColor();

    // Upper-left soft light bloom
    canvas.save();
    canvas.translate(-2.0, -2.0);
    _stroke
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0
      ..color = _ca(softLight, 0.45)
      ..maskFilter = null;
    canvas.drawRRect(rrect, _stroke);
    canvas.restore();

    // Lower-right deep soft shadow
    canvas.save();
    canvas.translate(2.5, 2.5);
    _stroke
      ..color = _ca(Colors.black, 0.35)
      ..maskFilter = null;
    canvas.drawRRect(rrect, _stroke);
    canvas.restore();

    // Main tactile bevel body
    _fill.color = b.color;
    canvas.drawRRect(rrect, _fill);

    // Recessed matte inner face plate
    final innerRRect = rrect.deflate(2.5);
    _fill.shader = LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [_ca(softDark, 0.35), _ca(softLight, 0.25)],
    ).createShader(innerRRect.outerRect);
    canvas.drawRRect(innerRRect, _fill);
    _fill.shader = null;

    // Subtle crisp tactile rim
    _stroke
      ..strokeWidth = 1.0
      ..color = _ca(softLight, 0.45);
    canvas.drawRRect(innerRRect, _stroke);
  }

  void _drawPixelBrick(Canvas canvas, Brick b, Rect rect, double halfW, double halfH) {
    _fill.isAntiAlias = false;
    _stroke.isAntiAlias = false;

    // Authentic retro 8-bit chunky block!
    final light = Color.lerp(b.color, Colors.white, 0.55)!;
    final dark = Color.lerp(b.color, Colors.black, 0.55)!;

    // 1. Black outer retro border (2px)
    _fill.color = const Color(0xFF000000);
    canvas.drawRect(rect, _fill);

    // 2. Main color body
    _fill.color = b.color;
    canvas.drawRect(rect.deflate(2), _fill);

    // 3. Stepped 8-bit bevels:
    // Top highlight line (2px thick)
    _fill.color = light;
    canvas.drawRect(Rect.fromLTWH(-halfW + 2, -halfH + 2, b.width - 6, 2.5), _fill);
    // Left highlight line (2px thick)
    canvas.drawRect(Rect.fromLTWH(-halfW + 2, -halfH + 2, 2.5, b.height - 6), _fill);

    // Bottom shadow line (2px thick)
    _fill.color = dark;
    canvas.drawRect(Rect.fromLTWH(-halfW + 4, halfH - 4.5, b.width - 6, 2.5), _fill);
    // Right shadow line (2px thick)
    canvas.drawRect(Rect.fromLTWH(halfW - 4.5, -halfH + 4, 2.5, b.height - 6), _fill);

    // 4. Retro 3x3 pixel specular glint at top-left
    _fill.color = Colors.white;
    canvas.drawRect(Rect.fromLTWH(-halfW + 5, -halfH + 5, 3.5, 3.5), _fill);

    // 5. Classic 2x2 retro dither blocks in corners
    _fill.color = _ca(dark, 0.5);
    canvas.drawRect(Rect.fromLTWH(-halfW + 6, halfH - 8, 2.5, 2.5), _fill);
    canvas.drawRect(Rect.fromLTWH(halfW - 8, -halfH + 6, 2.5, 2.5), _fill);

    _fill.isAntiAlias = true;
    _stroke.isAntiAlias = true;
  }

  void _drawCyberBrick(Canvas canvas, Brick b, RRect rrect, double halfW, double halfH) {
    // High-tech cybernetic armor block
    // 1. Dark titanium hull
    _fill.color = const Color(0xFF080D15);
    canvas.drawRRect(rrect, _fill);

    // 2. Brushed cyber plating
    _fill.color = _ca(b.color, 0.28);
    canvas.drawRRect(rrect.deflate(1.5), _fill);

    // 3. Central glowing energy conduit with animated pulse
    final conduitPulse = 0.6 + 0.4 * sin(time * 5.0);
    _stroke
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.square
      ..strokeWidth = 2.0
      ..color = _ca(const Color(0xFF00E5FF), conduitPulse);
    canvas.drawLine(Offset(-halfW + 12, 0), Offset(halfW - 12, 0), _stroke);

    // 4. Corner cyber circuit traces
    _stroke
      ..strokeWidth = 1.5
      ..color = _ca(const Color(0xFF00E5FF), 0.85);
    // Top-left circuit trace
    canvas.drawLine(Offset(-halfW + 4, -halfH + 9), Offset(-halfW + 4, -halfH + 4), _stroke);
    canvas.drawLine(Offset(-halfW + 4, -halfH + 4), Offset(-halfW + 9, -halfH + 4), _stroke);
    // Bottom-right circuit trace
    canvas.drawLine(Offset(halfW - 9, halfH - 4), Offset(halfW - 4, halfH - 4), _stroke);
    canvas.drawLine(Offset(halfW - 4, halfH - 4), Offset(halfW - 4, halfH - 9), _stroke);

    // 5. Corner hex rivets with cyan LED center
    final hexPositions = [
      Offset(-halfW + 5, -halfH + 5),
      Offset(halfW - 5, -halfH + 5),
      Offset(-halfW + 5, halfH - 5),
      Offset(halfW - 5, halfH - 5),
    ];
    for (final p in hexPositions) {
      _fill.color = const Color(0xFF1E2836);
      canvas.drawCircle(p, 2.0, _fill);
      _fill.color = _ca(const Color(0xFF00E5FF), conduitPulse);
      canvas.drawCircle(p, 1.0, _fill);
    }

    // Outer cybernetic armor border
    _stroke
      ..strokeWidth = 1.0
      ..color = _ca(const Color(0xFF80D8FF), 0.6);
    canvas.drawRRect(rrect, _stroke);
  }

  void _drawCosmicBrick(Canvas canvas, Brick b, RRect rrect, double halfW, double halfH) {
    // 1. Deep cosmic void core
    _fill.color = const Color(0xFF0A0518);
    canvas.drawRRect(rrect, _fill);

    // 2. Prismatic nebula crystal body
    _fill.shader = LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [
        _ca(b.color, 0.65),
        _ca(const Color(0xFF240046), 0.85),
        _ca(const Color(0xFF00E5FF), 0.55),
      ],
      stops: const [0.0, 0.55, 1.0],
    ).createShader(rrect.outerRect);
    canvas.drawRRect(rrect.deflate(1.5), _fill);
    _fill.shader = null;

    // 3. Faceted crystal cleavage lines
    _stroke
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..color = _ca(const Color(0xFFE040FB), 0.65);
    canvas.drawLine(Offset(-halfW + 6, -halfH + 3), Offset(halfW - 6, halfH - 3), _stroke);
    canvas.drawLine(Offset(-halfW + 12, halfH - 3), Offset(halfW - 12, -halfH + 3), _stroke);

    // 4. Glowing chromatic crystal rim with animated pulse
    final pulse = 0.75 + 0.25 * sin(time * 6.0);
    _stroke
      ..strokeWidth = 2.0
      ..color = _ca(const Color(0xFF18FFFF), pulse);
    canvas.drawRRect(rrect, _stroke);

    // 5. Pulsating celestial starburst glint at center
    final sa = time * 2.5;
    final slen = min(halfH * 0.75, 7.0);
    _stroke
      ..strokeWidth = 1.5
      ..color = _ca(Colors.white, 0.95);
    canvas.drawLine(Offset(-cos(sa) * slen, -sin(sa) * slen), Offset(cos(sa) * slen, sin(sa) * slen), _stroke);
    canvas.drawLine(Offset(-cos(sa + pi / 2) * slen * 0.6, -sin(sa + pi / 2) * slen * 0.6), Offset(cos(sa + pi / 2) * slen * 0.6, sin(sa + pi / 2) * slen * 0.6), _stroke);

    // Mini star sparkle pips
    _fill.color = Colors.white;
    canvas.drawCircle(Offset(-halfW * 0.5, 0), 1.2, _fill);
    canvas.drawCircle(Offset(halfW * 0.5, 0), 1.2, _fill);
  }

  void _drawBoss(Canvas canvas, Brick b, double time, double halfW, double halfH) {
    final hpPct = (b.hp / b.maxHp).clamp(0.0, 1.0);

    // 1. Dual Thruster Glow / Exhaust
    final thrustPulse = 3.5 + sin(time * 12.0) * 2.0;
    _fill.color = _ca(const Color(0xFFFF5722), 0.85);
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
    _fill.color = _ca(const Color(0xFFFF1744), 0.75 + sin(time * 8.0) * 0.25);
    canvas.drawCircle(Offset(-halfW * 0.5, halfH + 9), 3.0, _fill);
    // Right Cannon
    _fill.color = const Color(0xFF37474F);
    canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromCenter(center: Offset(halfW * 0.5, halfH + 4), width: 10, height: 12), const Radius.circular(2)), _fill);
    _fill.color = _ca(const Color(0xFFFF1744), 0.75 + sin(time * 8.0) * 0.25);
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
      ..color = _ca(const Color(0xFF00E5FF), 0.6)
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
      ..color = _ca(const Color(0xFFFF1744), 0.35 * shieldPulse)
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
      ..color = _ca(const Color(0xFF8BC34A), 0.75)
      ..strokeWidth = 3.0;
    canvas.drawLine(Offset(0, y), Offset(size.width, y), _stroke);

    _stroke
      ..color = const Color(0x338BC34A)
      ..strokeWidth = 6.0;
    canvas.drawLine(Offset(0, y), Offset(size.width, y), _stroke);
  }

  void _drawDashedLine(Canvas canvas, Offset p1, Offset p2, Paint paint, {double dashWidth = 3.0, double dashSpace = 3.0}) {
    final dx = p2.dx - p1.dx;
    final dy = p2.dy - p1.dy;
    final distance = sqrt(dx * dx + dy * dy);
    if (distance == 0) return;
    final dirX = dx / distance;
    final dirY = dy / distance;
    double current = 0.0;
    while (current < distance) {
      final length = min(dashWidth, distance - current);
      final start = Offset(p1.dx + dirX * current, p1.dy + dirY * current);
      final end = Offset(p1.dx + dirX * (current + length), p1.dy + dirY * (current + length));
      canvas.drawLine(start, end, paint);
      current += dashWidth + dashSpace;
    }
  }

  void _drawPaddle(Canvas canvas) {
    final p = c.paddle;
    final rect = p.rect;

    canvas.save();

    if (p.isGhost) {
      final wingW = rect.width * 0.25;
      final centerW = rect.width * 0.50;

      final leftRect = Rect.fromLTWH(rect.left, rect.top, wingW, rect.height);
      final centerRect = Rect.fromLTWH(rect.left + wingW, rect.top, centerW, rect.height);
      final rightRect = Rect.fromLTWH(rect.right - wingW, rect.top, wingW, rect.height);

      final leftRRect = RRect.fromRectAndCorners(
        leftRect,
        topLeft: Radius.circular(rect.height / 2),
        bottomLeft: Radius.circular(rect.height / 2),
        topRight: const Radius.circular(3),
        bottomRight: const Radius.circular(3),
      );
      final rightRRect = RRect.fromRectAndCorners(
        rightRect,
        topRight: Radius.circular(rect.height / 2),
        bottomRight: Radius.circular(rect.height / 2),
        topLeft: const Radius.circular(3),
        bottomLeft: const Radius.circular(3),
      );

      // --- Hollow / Ghost Center (Middle 50%) ---
      // Faint transparent ghost tint
      _fill.color = _ca(Colors.cyanAccent, 0.05);
      canvas.drawRect(centerRect, _fill);

      // Soluk ve kesik çizgili hayalet çerçeve (alpha = 0.2, 3x3 dash pattern)
      _stroke
        ..color = _ca(Colors.white, 0.20)
        ..strokeWidth = 1.5;
      _drawDashedLine(canvas, Offset(centerRect.left, centerRect.top), Offset(centerRect.right, centerRect.top), _stroke, dashWidth: 3.0, dashSpace: 3.0);
      _drawDashedLine(canvas, Offset(centerRect.left, centerRect.bottom), Offset(centerRect.right, centerRect.bottom), _stroke, dashWidth: 3.0, dashSpace: 3.0);
      _drawDashedLine(canvas, Offset(centerRect.left, centerRect.top), Offset(centerRect.left, centerRect.bottom), _stroke, dashWidth: 3.0, dashSpace: 3.0);
      _drawDashedLine(canvas, Offset(centerRect.right, centerRect.top), Offset(centerRect.right, centerRect.bottom), _stroke, dashWidth: 3.0, dashSpace: 3.0);

      // --- Left Solid Wing (25%) ---
      // Outer glow
      _stroke
        ..color = _ca(c.activePaddleSkin.glowColor, 0.85)
        ..strokeWidth = 3.5;
      canvas.drawRRect(leftRRect.inflate(1.5), _stroke);

      // Solid body gradient
      _paddlePaint.shader = LinearGradient(
        colors: [
          c.activePaddleSkin.color1,
          c.activePaddleSkin.color2,
        ],
        begin: Alignment.centerLeft,
        end: Alignment.centerRight,
      ).createShader(leftRect);
      canvas.drawRRect(leftRRect, _paddlePaint);

      // Specular gloss highlight
      final leftGloss = Rect.fromLTWH(leftRect.left + 2, leftRect.top + 2, leftRect.width - 4, leftRect.height * 0.38);
      _fill.color = _ca(Colors.white, 0.50);
      canvas.drawRRect(RRect.fromRectAndRadius(leftGloss, const Radius.circular(2)), _fill);

      // --- Right Solid Wing (25%) ---
      // Outer glow
      _stroke
        ..color = _ca(c.activePaddleSkin.glowColor, 0.85)
        ..strokeWidth = 3.5;
      canvas.drawRRect(rightRRect.inflate(1.5), _stroke);

      // Solid body gradient
      _paddlePaint.shader = LinearGradient(
        colors: [
          c.activePaddleSkin.color1,
          c.activePaddleSkin.color2,
        ],
        begin: Alignment.centerLeft,
        end: Alignment.centerRight,
      ).createShader(rightRect);
      canvas.drawRRect(rightRRect, _paddlePaint);

      // Specular gloss highlight
      final rightGloss = Rect.fromLTWH(rightRect.left + 2, rightRect.top + 2, rightRect.width - 4, rightRect.height * 0.38);
      _fill.color = _ca(Colors.white, 0.50);
      canvas.drawRRect(RRect.fromRectAndRadius(rightGloss, const Radius.circular(2)), _fill);

      // Ice (Clumsy) effect on wings
      if (p.isClumsy) {
        _fill.color = _ca(Colors.cyanAccent, 0.35);
        canvas.drawRRect(leftRRect, _fill);
        canvas.drawRRect(rightRRect, _fill);
        _stroke
          ..color = _ca(Colors.white, 0.70)
          ..strokeWidth = 2.0;
        canvas.drawRRect(leftRRect, _stroke);
        canvas.drawRRect(rightRRect, _stroke);
      }
    } else {
      final rrect = RRect.fromRectAndRadius(rect, Radius.circular(rect.height / 2));

      // Outer glow ring (high-performance crisp stroke)
      _stroke
        ..color = _ca(c.activePaddleSkin.glowColor, 0.35)
        ..strokeWidth = 4.0;
      canvas.drawRRect(rrect.inflate(2.0), _stroke);

      // Paddle body gradient
      _paddlePaint.shader = LinearGradient(
        colors: [
          c.activePaddleSkin.color1,
          c.activePaddleSkin.color2,
        ],
        begin: Alignment.centerLeft,
        end: Alignment.centerRight,
      ).createShader(rect);
      canvas.drawRRect(rrect, _paddlePaint);

      // Specular highlight
      final gloss = Rect.fromLTWH(rect.left + 4, rect.top + 2, rect.width - 8, rect.height * 0.38);
      _fill.color = _ca(Colors.white, 0.35);
      canvas.drawRRect(RRect.fromRectAndRadius(gloss, const Radius.circular(4)), _fill);

      // Distinctive Paddle Skin Cosmetic Features
      _drawPaddleSkinDetails(canvas, rect, rrect, c.activePaddleSkin, time);

            // --- ICE (Clumsy) EFFECT OVERLAY WITH FROST SPIKES ---
      if (p.isClumsy) {
        _fill.color = const Color(0x6680D8FF);
        canvas.drawRRect(rrect, _fill);
        _stroke
          ..color = _ca(Colors.white, 0.8)
          ..strokeWidth = 2.0;
        canvas.drawRRect(rrect, _stroke);

                // Frost icicles / spikes hanging below paddle
        _fill.color = const Color(0xCCB2EBF2);
        for (double ix = 6; ix < rect.width - 6; ix += 12) {
          final spike = Path()
            ..moveTo(rect.left + ix, rect.bottom)
            ..lineTo(rect.left + ix + 3, rect.bottom + 6)
            ..lineTo(rect.left + ix + 6, rect.bottom)
            ..close();
          canvas.drawPath(spike, _fill);
        }
      }
    }

    // Laser cannons
    if (p.hasLaser) {
      _fill.color = const Color(0xFFFFD740);
      canvas.drawRect(Rect.fromLTWH(rect.left + 2, rect.top - 5, 5, 5), _fill);
      canvas.drawRect(Rect.fromLTWH(rect.right - 7, rect.top - 5, 5, 5), _fill);
    }

    canvas.restore();
  }

  void _drawPaddleSkinDetails(Canvas canvas, Rect rect, RRect rrect, PaddleSkin skin, double time) {
    final cx = rect.center.dx;
    final cy = rect.center.dy;
    final h = rect.height;
    final w = rect.width;

    switch (skin.id) {
      case 'pclassic':
        // Cyber Chassis: Side thruster exhausts & central 5-segment cyan LED meter
        _fill.color = _ca(const Color(0xFF00E5FF), 0.8 + 0.2 * sin(time * 12.0));
        canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(rect.left + 2, rect.top + 3, 5, h - 6), const Radius.circular(2)), _fill);
        canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(rect.right - 7, rect.top + 3, 5, h - 6), const Radius.circular(2)), _fill);

        const barW = 5.0;
        const barSpacing = 3.0;
        const totalW = 5 * barW + 4 * barSpacing;
        final startX = cx - totalW / 2;
        for (int i = 0; i < 5; i++) {
          final barPulse = (sin(time * 8.0 - i * 0.7) * 0.5 + 0.5);
          _fill.color = Color.lerp(const Color(0xFF00E5FF), Colors.white, barPulse)!;
          canvas.drawRRect(
            RRect.fromRectAndRadius(Rect.fromLTWH(startX + i * (barW + barSpacing), cy - 2, barW, 4), const Radius.circular(1.5)),
            _fill,
          );
        }
        break;

      case 'ppink':
        // Synthwave racer: glowing neon rails & central audio equalizer bars
        _stroke
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5
          ..color = _ca(const Color(0xFFFF80AB), 0.9);
        canvas.drawLine(Offset(rect.left + 12, rect.top + 2), Offset(rect.right - 12, rect.top + 2), _stroke);
        canvas.drawLine(Offset(rect.left + 12, rect.bottom - 2), Offset(rect.right - 12, rect.bottom - 2), _stroke);

        for (int i = -3; i <= 3; i++) {
          final barH = (sin(time * 10.0 + i.abs() * 1.2).abs() * (h * 0.5) + 3.0).clamp(2.0, h - 4.0);
          _fill.color = _ca(Colors.white, 0.85);
          canvas.drawRRect(
            RRect.fromRectAndRadius(Rect.fromCenter(center: Offset(cx + i * 5.0, cy), width: 2.2, height: barH), const Radius.circular(1)),
            _fill,
          );
        }
        break;

      case 'pice':
        // Glacial crystal: faceted ice shards & subzero frost sparkles
        _stroke
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.2
          ..color = _ca(Colors.white, 0.85);
        for (double x = rect.left + 14; x < rect.right - 14; x += 14) {
          canvas.drawLine(Offset(x, rect.top + 2), Offset(x + 5, cy), _stroke);
          canvas.drawLine(Offset(x + 5, cy), Offset(x, rect.bottom - 2), _stroke);
        }
        final glintX = cx + sin(time * 3.0) * (w * 0.35);
        _fill.color = Colors.white;
        canvas.drawCircle(Offset(glintX, cy), 1.8, _fill);
        break;

      case 'pbat':
        // Stealth Night Bat: wingtip crimson exhausts & stealth chevron emblem
        _fill.color = const Color(0xFFFF1744);
        canvas.drawRect(Rect.fromLTWH(rect.left + 3, rect.top + 4, 4, h - 8), _fill);
        canvas.drawRect(Rect.fromLTWH(rect.right - 7, rect.top + 4, 4, h - 8), _fill);

        _stroke
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.6
          ..color = const Color(0xFFFF5252);
        final chevPath = Path()
          ..moveTo(cx - 10, cy - 3)
          ..lineTo(cx, cy + 3)
          ..lineTo(cx + 10, cy - 3);
        canvas.drawPath(chevPath, _stroke);
        break;

      case 'pcyber':
        // Cyberpunk 2099: neon cyan & magenta PCB circuit traces
        _stroke
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.3
          ..color = const Color(0xFF00E5FF);
        final pcbLeft = Path()
          ..moveTo(rect.left + 12, cy)
          ..lineTo(rect.left + 22, cy)
          ..lineTo(rect.left + 26, rect.top + 3);
        canvas.drawPath(pcbLeft, _stroke);
        _stroke.color = const Color(0xFFD500F9);
        final pcbRight = Path()
          ..moveTo(rect.right - 12, cy)
          ..lineTo(rect.right - 22, cy)
          ..lineTo(rect.right - 26, rect.bottom - 3);
        canvas.drawPath(pcbRight, _stroke);

        final cyberPulse = 0.6 + 0.4 * sin(time * 8.0);
        _fill.color = _ca(const Color(0xFF00E5FF), cyberPulse);
        canvas.drawCircle(Offset(cx, cy), 3.0, _fill);
        _fill.color = Colors.white;
        canvas.drawCircle(Offset(cx, cy), 1.2, _fill);
        break;

      case 'pgold':
        // Royal Gold: gilded metallic border, filigree inlays, imperial diamond
        _stroke
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.4
          ..color = const Color(0xFFFFF9C4);
        canvas.drawRRect(rrect.deflate(2.0), _stroke);

        _tempPath.reset();
        _tempPath.moveTo(cx, cy - 4.5);
        _tempPath.lineTo(cx + 4.5, cy);
        _tempPath.lineTo(cx, cy + 4.5);
        _tempPath.lineTo(cx - 4.5, cy);
        _tempPath.close();
        _fill.color = const Color(0xFFFFD54F);
        canvas.drawPath(_tempPath, _fill);
        _fill.color = Colors.white;
        canvas.drawCircle(Offset(cx, cy), 1.2, _fill);

        _stroke.strokeWidth = 1.0;
        _stroke.color = const Color(0xFFFFD54F);
        canvas.drawLine(Offset(cx - 8, cy), Offset(cx - 18, cy), _stroke);
        canvas.drawLine(Offset(cx + 8, cy), Offset(cx + 18, cy), _stroke);
        break;

      case 'pdark':
        // Toxic Venom: glowing bio-fluid conduits & venom nodes
        final venomPulse = 0.7 + 0.3 * sin(time * 6.0);
        _stroke
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.5
          ..color = _ca(const Color(0xFF00E676), venomPulse);
        canvas.drawLine(Offset(rect.left + 14, cy), Offset(rect.right - 14, cy), _stroke);

        for (double x = rect.left + 20; x < rect.right - 20; x += 18) {
          _fill.color = const Color(0xFFB9F6CA);
          canvas.drawCircle(Offset(x, cy), 2.2, _fill);
        }
        break;

      case 'pnebula':
        // Deep Nebula: starry cosmic dust window inside the paddle body
        final nebPulse = 0.7 + 0.3 * sin(time * 4.0);
        _stroke
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.4
          ..color = _ca(const Color(0xFFE040FB), nebPulse);
        canvas.drawRRect(rrect.deflate(2.0), _stroke);

        for (int i = 0; i < 6; i++) {
          final starX = rect.left + 14 + (i * ((w - 28) / 5));
          final starY = cy + sin(time * 3.0 + i * 1.5) * (h * 0.22);
          final twinkle = 0.5 + 0.5 * sin(time * 7.0 + i * 2.0);
          _fill.color = _ca((i % 2 == 0 ? const Color(0xFF80D8FF) : Colors.white), twinkle);
          canvas.drawCircle(Offset(starX, starY), 1.3, _fill);
        }
        break;
    }
  }

  void _drawBlackHoles(Canvas canvas) {
    for (final bh in c.blackHoles) {
      canvas.save();
      canvas.translate(bh.x, bh.y);
      canvas.rotate(bh.rotation);

      // 1. Broad Gravitational Lensing & Warped Photon Halo
      final holeKey = Object.hash(bh.isVortexTrap, (bh.radius * 2).round());
      _fill
        ..style = PaintingStyle.fill
        ..maskFilter = null
        ..shader = _holeShaders.putIfAbsent(holeKey, () {
          final vortexColors = bh.isVortexTrap
              ? [
                  Colors.black,
                  const Color(0xFF1A0000),
                  _ca(const Color(0xFFB71C1C), 0.95),
                  _ca(const Color(0xFFFF1744), 0.75),
                  _ca(const Color(0xFFFF80AB), 0.35),
                  Colors.transparent,
                ]
              : [
                  Colors.black,
                  const Color(0xFF0D0318),
                  _ca(const Color(0xFF4A148C), 0.95),
                  _ca(const Color(0xFF7C4DFF), 0.6),
                  _ca(const Color(0xFFE040FB), 0.25),
                  Colors.transparent,
                ];
          return RadialGradient(
            colors: vortexColors,
            stops: const [0.25, 0.42, 0.60, 0.78, 0.92, 1.0],
          ).createShader(Rect.fromCircle(
            center: Offset.zero,
            radius: bh.radius * (bh.isVortexTrap ? 3.4 : 2.8),
          ));
        });
      
      canvas.drawCircle(Offset.zero, bh.radius * (bh.isVortexTrap ? 3.4 : 2.8), _fill);
      _fill.shader = null;

      // 2. Swirling Relativistic Accretion Disk Arms (Infalling stellar matter)
      final armCount = bh.isVortexTrap ? 8 : 5;
      for (int i = 0; i < armCount; i++) {
        final angleOffset = (pi * 2 / armCount) * i + sin(time * 3.0 + i) * 0.15;
        final r = bh.radius * (0.55 + 0.35 * (i % 5));
        final armColor = bh.isVortexTrap
            ? ((i % 2 == 0) ? const Color(0xFFFF1744) : const Color(0xFFFF80AB))
            : ((i % 2 == 0) ? const Color(0xFFE040FB) : const Color(0xFF7C4DFF));
        _stroke
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..maskFilter = null
          ..color = _ca(armColor, 0.65 - (i * 0.05))
          ..strokeWidth = 2.2 - (i * 0.15);
        canvas.drawArc(
          Rect.fromCircle(center: Offset.zero, radius: r),
          angleOffset,
          pi * (bh.isVortexTrap ? 1.6 : 1.35),
          false,
          _stroke,
        );
      }

      // 3. Photon Sphere Incandescent Border (Relativistic light ring)
      _stroke
        ..strokeWidth = 3.2
        ..maskFilter = null
        ..color = _ca(const Color(0xFFB388FF), 0.45);
      canvas.drawCircle(Offset.zero, bh.radius * 0.48, _stroke);

      _stroke
        ..strokeWidth = 1.2
        ..color = _ca(Colors.white, 0.95);
      canvas.drawCircle(Offset.zero, bh.radius * 0.48, _stroke);

      // 4. Absolute Singularity Event Horizon (Infinite Black Void)
      _fill
        ..style = PaintingStyle.fill
        ..maskFilter = null
        ..color = Colors.black;
      canvas.drawCircle(Offset.zero, bh.radius * 0.45, _fill);

      canvas.restore();
    }
  }

  void _drawPortals(Canvas canvas) {
    for (final p in c.portals) {
      canvas.save();
      canvas.translate(p.x, p.y);
      canvas.rotate(p.rotation);

      // Portal Outer Ring
      _stroke
        ..color = p.color
        ..strokeWidth = 3.0;
      canvas.drawCircle(Offset.zero, p.radius, _stroke);
      
      // Portal Inner Swirls
      final swirlCount = 4;
      for (int i = 0; i < swirlCount; i++) {
        final angle = (i * 2 * pi) / swirlCount;
        final x = cos(angle) * (p.radius * 0.5);
        final y = sin(angle) * (p.radius * 0.5);
        
        _fill.color = _ca(p.color, 0.8);
        canvas.drawCircle(Offset(x, y), p.radius * 0.3, _fill);
      }

      // Center Void
      _fill.color = const Color(0xFF111111);
      canvas.drawCircle(Offset.zero, p.radius * 0.4, _fill);

      canvas.restore();
    }
  }

  void _drawBalls(Canvas canvas) {
    for (final ball in c.balls) {
      final isFireball = ball.isFireball;
      final isCornerBoost = ball.cornerBoostTimer > 0;
      final skinGlow = c.activeBallSkin.glowColor;
      final skinMain = c.activeBallSkin.mainColor;

      if (ball.trail.length > 1) {
        final trailStyle = c.activeTrailSkin.style;
        final trailCount = ball.trail.length;
        if (trailStyle == TrailStyle.dot) {
          // === ELEVATED DOT TRAIL: Celestial Starlight Constellation (Tapering to needle tip) ===
          final dotColor = isFireball
              ? const Color(0xFFFF1744)
              : (isCornerBoost ? const Color(0xFFFFD600) : skinGlow);
          final coreColor = isFireball
              ? const Color(0xFFFF8A80)
              : (isCornerBoost ? const Color(0xFFFFFDE7) : skinMain);

          // Precompute undulating positions along transverse wave
          final dotPositions = <Offset>[];
          for (int i = 0; i < trailCount; i++) {
            final progress = trailCount > 1 ? i / (trailCount - 1) : 0.0;
            final taper = (1.0 - progress).clamp(0.0, 1.0);
            double nx = 0.0, ny = 1.0;
            if (i < trailCount - 1) {
              final dx = ball.trail[i + 1].position.dx - ball.trail[i].position.dx;
              final dy = ball.trail[i + 1].position.dy - ball.trail[i].position.dy;
              final segLen = sqrt(dx * dx + dy * dy);
              if (segLen > 0.001) {
                nx = -dy / segLen;
                ny = dx / segLen;
              }
            } else if (i > 0) {
              final dx = ball.trail[i].position.dx - ball.trail[i - 1].position.dx;
              final dy = ball.trail[i].position.dy - ball.trail[i - 1].position.dy;
              final segLen = sqrt(dx * dx + dy * dy);
              if (segLen > 0.001) {
                nx = -dy / segLen;
                ny = dx / segLen;
              }
            }
            final wave = sin(time * 12.0 + i * 0.8) * (ball.radius * 0.5 * taper);
            dotPositions.add(Offset(ball.trail[i].position.dx + nx * wave, ball.trail[i].position.dy + ny * wave));
          }

          // 1. Connecting undulating starlight filament between dots (tapering)
          _stroke
            ..style = PaintingStyle.stroke
            ..strokeCap = StrokeCap.round
            ..strokeJoin = StrokeJoin.round
            ..maskFilter = null;
          for (int i = 0; i < dotPositions.length - 1; i++) {
            final progress = (i + 0.5) / (dotPositions.length - 1);
            final taper = (1.0 - progress).clamp(0.0, 1.0);
            _stroke
              ..strokeWidth = (ball.radius * 0.55 * taper).clamp(0.4, ball.radius)
              ..color = _ca(dotColor, 0.45 * taper);
            canvas.drawLine(dotPositions[i], dotPositions[i + 1], _stroke);
          }

          // 2. Shimmering Starlight Orbs (smoothly tapering down to 0 at the tail, NO blur lag)
          _fill
            ..style = PaintingStyle.fill
            ..maskFilter = null;
          for (int i = 0; i < dotPositions.length; i++) {
            final progress = dotPositions.length > 1 ? i / (dotPositions.length - 1) : 0.0;
            final taper = (1.0 - progress).clamp(0.0, 1.0);
            final shimmer = 0.82 + 0.18 * sin(time * 10 + i * 0.7);
            final baseR = ball.radius * taper * shimmer;
            if (baseR <= 0.2) continue;
            final pos = dotPositions[i];

            // Soft diffuse halo (2-pass alpha, zero blur overhead)
            _fill.color = _ca(dotColor, 0.22 * taper);
            canvas.drawCircle(pos, baseR * 1.6, _fill);

            // Luminous bead
            _fill.color = _ca(coreColor, 0.85 * taper);
            canvas.drawCircle(pos, baseR, _fill);

            // Starlight white core
            _fill.color = _ca(Colors.white, 0.95 * taper);
            canvas.drawCircle(pos, baseR * 0.4, _fill);

            // Rotating 4-point micro-glint star on alternating beads
            if (i % 3 == 0 && baseR > 2.0) {
              final spAngle = time * 3.5 + i * 1.2;
              final spLen = baseR * 1.6;
              _stroke
                ..strokeWidth = 1.0
                ..color = _ca(Colors.white, 0.75 * taper);
              canvas.drawLine(
                Offset(pos.dx - cos(spAngle) * spLen, pos.dy - sin(spAngle) * spLen),
                Offset(pos.dx + cos(spAngle) * spLen, pos.dy + sin(spAngle) * spLen),
                _stroke,
              );
              canvas.drawLine(
                Offset(pos.dx - cos(spAngle + pi / 2) * (spLen * 0.6), pos.dy - sin(spAngle + pi / 2) * (spLen * 0.6)),
                Offset(pos.dx + cos(spAngle + pi / 2) * (spLen * 0.6), pos.dy - sin(spAngle + pi / 2) * (spLen * 0.6)),
                _stroke,
              );
            }
          }
        } else if (trailStyle == TrailStyle.spark) {
          // === ELEVATED SPARK TRAIL: High-Voltage Lightning & Charged Sparks (Tapering to needle tip) ===
          final sparkBaseColor = isFireball
              ? const Color(0xFFFF3D00)
              : (isCornerBoost ? const Color(0xFFFFAB00) : skinMain);
          final sparkGlowColor = isFireball
              ? const Color(0xFFFF1744)
              : (isCornerBoost ? const Color(0xFFFFEA00) : skinGlow);

          final sparkPositions = <Offset>[Offset(ball.x, ball.y)];
          for (int i = 0; i < trailCount - 1; i++) {
            final p1 = ball.trail[i].position;
            final p2 = ball.trail[i + 1].position;
            final progress = i / (trailCount - 1);
            final taper = (1.0 - progress).clamp(0.0, 1.0);

            final dx = p2.dx - p1.dx;
            final dy = p2.dy - p1.dy;
            final segLen = sqrt(dx * dx + dy * dy);
            if (segLen > 0.001) {
              final nx = -dy / segLen;
              final ny = dx / segLen;
              final jitter = sin(time * 38 + i * 4.3) * (ball.radius * 0.65 * taper);
              final mid = Offset((p1.dx + p2.dx) * 0.5 + nx * jitter, (p1.dy + p2.dy) * 0.5 + ny * jitter);
              sparkPositions.add(mid);
            }
            sparkPositions.add(p2);
          }

          _stroke
            ..style = PaintingStyle.stroke
            ..strokeCap = StrokeCap.round
            ..strokeJoin = StrokeJoin.round
            ..maskFilter = null;

          // Layer 1: Electric outer bloom segments (tapering, NO blur)
          for (int i = 0; i < sparkPositions.length - 1; i++) {
            final progress = (i + 0.5) / (sparkPositions.length - 1);
            final taper = (1.0 - progress).clamp(0.0, 1.0);
            _stroke
              ..strokeWidth = (ball.radius * 2.2 * taper).clamp(0.8, ball.radius * 2.2)
              ..color = _ca(sparkGlowColor, 0.28 * taper);
            canvas.drawLine(sparkPositions[i], sparkPositions[i + 1], _stroke);
          }

          // Layer 2: Main energetic lightning bolt segments (tapering)
          for (int i = 0; i < sparkPositions.length - 1; i++) {
            final progress = (i + 0.5) / (sparkPositions.length - 1);
            final taper = (1.0 - progress).clamp(0.0, 1.0);
            _stroke
              ..strokeWidth = (ball.radius * 1.1 * taper).clamp(0.6, ball.radius * 1.1)
              ..color = _ca(sparkBaseColor, 0.88 * taper);
            canvas.drawLine(sparkPositions[i], sparkPositions[i + 1], _stroke);
          }

          // Layer 3: Blinding white electric core (tapering)
          for (int i = 0; i < sparkPositions.length - 1; i++) {
            final progress = (i + 0.5) / (sparkPositions.length - 1);
            final taper = (1.0 - progress).clamp(0.0, 1.0);
            _stroke
              ..strokeWidth = (ball.radius * 0.42 * taper).clamp(0.4, ball.radius * 0.42)
              ..color = _ca(Colors.white, 0.95 * taper);
            canvas.drawLine(sparkPositions[i], sparkPositions[i + 1], _stroke);
          }

          // Layer 4: Electric spark cross glints along the path (scaling down with taper)
          for (int i = 0; i < trailCount; i += 2) {
            final progress = trailCount > 1 ? i / (trailCount - 1) : 0.0;
            final taper = (1.0 - progress).clamp(0.0, 1.0);
            final pt = ball.trail[i].position;
            final sparkSize = ball.radius * (0.8 + 0.3 * sin(time * 24 + i)) * taper;
            if (sparkSize <= 0.5) continue;
            final a = time * 8 + i * 2;
            _stroke
              ..strokeWidth = 1.0
              ..color = _ca(Colors.white, 0.85 * taper);
            canvas.drawLine(
              Offset(pt.dx - cos(a) * sparkSize, pt.dy - sin(a) * sparkSize),
              Offset(pt.dx + cos(a) * sparkSize, pt.dy + sin(a) * sparkSize),
              _stroke,
            );
            canvas.drawLine(
              Offset(pt.dx - cos(a + pi / 2) * (sparkSize * 0.5), pt.dy - sin(a + pi / 2) * (sparkSize * 0.5)),
              Offset(pt.dx + cos(a + pi / 2) * (sparkSize * 0.5), pt.dy - sin(a + pi / 2) * (sparkSize * 0.5)),
              _stroke,
            );
          }
        } else if (trailStyle == TrailStyle.ghost) {
          // === ELEVATED GHOST TRAIL: Ethereal Phantom Echoes (Tapering to fine spirit tip) ===
          final ghostBaseColor = isFireball
              ? const Color(0xFFFF5252)
              : (isCornerBoost ? const Color(0xFFFFE082) : skinMain);
          final ghostGlowColor = isFireball
              ? const Color(0xFFFF1744)
              : (isCornerBoost ? const Color(0xFFFFD600) : skinGlow);

          _stroke
            ..style = PaintingStyle.stroke
            ..strokeCap = StrokeCap.round
            ..strokeJoin = StrokeJoin.round
            ..maskFilter = null;

          // 1. Flowing ethereal spirit ribbon segments (tapering smoothly)
          for (int i = 0; i < trailCount - 1; i++) {
            final progress = (i + 0.5) / (trailCount - 1);
            final taper = (1.0 - progress).clamp(0.0, 1.0);
            final p1 = ball.trail[i].position;
            final p2 = ball.trail[i + 1].position;

            // Outer mist
            _stroke
              ..strokeWidth = (ball.radius * 1.5 * taper).clamp(0.6, ball.radius * 1.5)
              ..color = _ca(ghostGlowColor, 0.22 * taper);
            canvas.drawLine(p1, p2, _stroke);

            // Inner core ribbon
            _stroke
              ..strokeWidth = (ball.radius * 0.7 * taper).clamp(0.4, ball.radius * 0.7)
              ..color = _ca(ghostBaseColor, 0.45 * taper);
            canvas.drawLine(p1, p2, _stroke);
          }

          // 2. Spectral Phantom Clones (tapering smoothly down to 0)
          _fill
            ..style = PaintingStyle.fill
            ..maskFilter = null;
          for (int i = 1; i < trailCount; i += 2) {
            final progress = i / (trailCount - 1);
            final taper = (1.0 - progress).clamp(0.0, 1.0);
            final wave = sin(time * 8.0 + i * 0.7) * (2.0 * taper);
            final pt = Offset(ball.trail[i].position.dx + wave, ball.trail[i].position.dy - wave * 0.5);
            final ghostRadius = ball.radius * taper;
            if (ghostRadius <= 0.4) continue;

            // Ethereal diffuse mist aura (NO blur lag)
            _fill.color = _ca(ghostGlowColor, 0.20 * taper);
            canvas.drawCircle(pt, ghostRadius * 1.4, _fill);

            // Spectral body
            _fill.color = _ca(ghostBaseColor, 0.35 * taper);
            canvas.drawCircle(pt, ghostRadius, _fill);

            // Spectral rim ring
            _stroke
              ..strokeWidth = 1.0
              ..color = _ca(Colors.white, 0.55 * taper);
            canvas.drawCircle(pt, ghostRadius, _stroke);

            // Specular reflection echo
            _fill.color = _ca(Colors.white, 0.7 * taper);
            canvas.drawCircle(Offset(pt.dx - ghostRadius * 0.3, pt.dy - ghostRadius * 0.3), ghostRadius * 0.25, _fill);
          }
        } else if (trailStyle == TrailStyle.rainbow) {
          // === ELEVATED RAINBOW TRAIL: Prismatic Aurora Borealis Ribbon (Tapering to needle tip) ===
          _stroke
            ..style = PaintingStyle.stroke
            ..strokeCap = StrokeCap.round
            ..strokeJoin = StrokeJoin.round
            ..maskFilter = null;

          for (int i = 0; i < trailCount - 1; i++) {
            final progress = (i + 0.5) / (trailCount - 1);
            final taper = (1.0 - progress).clamp(0.0, 1.0);
            final hue = (time * 120 + i * 16) % 360;
            final color = HSLColor.fromAHSL(1.0, hue, 1.0, 0.55).toColor();
            final wave = sin(time * 9.0 + i * 0.45) * (1.5 * taper);

            final p1 = Offset(ball.trail[i].position.dx + wave, ball.trail[i].position.dy);
            final p2 = Offset(ball.trail[i + 1].position.dx, ball.trail[i + 1].position.dy);

            // Outer chromatic bloom (tapering, NO blur)
            _stroke
              ..strokeWidth = (ball.radius * 2.5 * taper).clamp(0.8, ball.radius * 2.5)
              ..color = _ca(color, 0.22 * taper);
            canvas.drawLine(p1, p2, _stroke);

            // Vibrant aurora ribbon (tapering)
            _stroke
              ..strokeWidth = (ball.radius * 1.3 * taper).clamp(0.6, ball.radius * 1.3)
              ..color = _ca(color, 0.85 * taper);
            canvas.drawLine(p1, p2, _stroke);

            // Pure luminous core filament (tapering)
            _stroke
              ..strokeWidth = (ball.radius * 0.42 * taper).clamp(0.4, ball.radius * 0.42)
              ..color = _ca(Colors.white, 0.90 * taper);
            canvas.drawLine(p1, p2, _stroke);

            // Prismatic star sparkle on crests
            if (i % 5 == 0 && taper > 0.3) {
              final spSize = ball.radius * (0.85 + 0.25 * sin(time * 16 + i)) * taper;
              final a = time * 4 + i;
              _stroke
                ..strokeWidth = 1.0
                ..color = _ca(Colors.white, 0.8 * taper);
              canvas.drawLine(
                Offset(p1.dx - cos(a) * spSize, p1.dy - sin(a) * spSize),
                Offset(p1.dx + cos(a) * spSize, p1.dy + sin(a) * spSize),
                _stroke,
              );
              canvas.drawLine(
                Offset(p1.dx - cos(a + pi / 2) * (spSize * 0.6), p1.dy - sin(a + pi / 2) * (spSize * 0.6)),
                Offset(p1.dx + cos(a + pi / 2) * (spSize * 0.6), p1.dy - sin(a + pi / 2) * (spSize * 0.6)),
                _stroke,
              );
            }
          }
        } else if (trailStyle == TrailStyle.plasma) {
          // === ELEVATED PLASMA TRAIL: Quantum Plasma Vortex & Cosmic Beam (Tapering to needle tip) ===
          _stroke
            ..style = PaintingStyle.stroke
            ..strokeCap = StrokeCap.round
            ..strokeJoin = StrokeJoin.round
            ..maskFilter = null;

          final helix1Pts = <Offset>[Offset(ball.x, ball.y)];
          final helix2Pts = <Offset>[Offset(ball.x, ball.y)];
          for (int i = 0; i < trailCount - 1; i++) {
            final p1 = ball.trail[i].position;
            final p2 = ball.trail[i + 1].position;
            final progress = i / (trailCount - 1);
            final taper = (1.0 - progress).clamp(0.0, 1.0);

            final dx = p2.dx - p1.dx;
            final dy = p2.dy - p1.dy;
            final segLen = sqrt(dx * dx + dy * dy);
            if (segLen > 0.001) {
              final nx = -dy / segLen;
              final ny = dx / segLen;
              final helix = sin(time * 18.0 + i * 0.8) * (ball.radius * 0.95 * taper);
              helix1Pts.add(Offset(p2.dx + nx * helix, p2.dy + ny * helix));
              helix2Pts.add(Offset(p2.dx - nx * helix, p2.dy - ny * helix));
            } else {
              helix1Pts.add(p2);
              helix2Pts.add(p2);
            }
          }

          // 1. Deep cosmic cyan coronal glow segments (tapering, NO blur)
          for (int i = 0; i < trailCount - 1; i++) {
            final progress = (i + 0.5) / (trailCount - 1);
            final taper = (1.0 - progress).clamp(0.0, 1.0);
            _stroke
              ..strokeWidth = (ball.radius * 2.8 * taper).clamp(0.8, ball.radius * 2.8)
              ..color = _ca(const Color(0xFF00E5FF), 0.25 * taper);
            canvas.drawLine(ball.trail[i].position, ball.trail[i + 1].position, _stroke);
          }

          // 2. Twin helical plasma streamers (tapering)
          for (int i = 0; i < helix1Pts.length - 1; i++) {
            final progress = (i + 0.5) / (helix1Pts.length - 1);
            final taper = (1.0 - progress).clamp(0.0, 1.0);
            _stroke
              ..strokeWidth = (ball.radius * 0.55 * taper).clamp(0.4, ball.radius * 0.55)
              ..color = _ca(const Color(0xFF18FFFF), 0.85 * taper);
            canvas.drawLine(helix1Pts[i], helix1Pts[i + 1], _stroke);

            _stroke.color = _ca(const Color(0xFFB388FF), 0.85 * taper);
            canvas.drawLine(helix2Pts[i], helix2Pts[i + 1], _stroke);
          }

          // 3. High-intensity focused plasma core beam segments (tapering)
          for (int i = 0; i < trailCount - 1; i++) {
            final progress = (i + 0.5) / (trailCount - 1);
            final taper = (1.0 - progress).clamp(0.0, 1.0);
            _stroke
              ..strokeWidth = (ball.radius * 1.0 * taper).clamp(0.6, ball.radius * 1.0)
              ..color = _ca(const Color(0xFFE0F7FA), 0.90 * taper);
            canvas.drawLine(ball.trail[i].position, ball.trail[i + 1].position, _stroke);

            _stroke
              ..strokeWidth = (ball.radius * 0.45 * taper).clamp(0.4, ball.radius * 0.45)
              ..color = _ca(Colors.white, 0.95 * taper);
            canvas.drawLine(ball.trail[i].position, ball.trail[i + 1].position, _stroke);
          }

          // 4. Quantum containment rings along the beam (scaling down with taper)
          for (int i = 2; i < trailCount; i += 4) {
            final progress = i / (trailCount - 1);
            final taper = (1.0 - progress).clamp(0.0, 1.0);
            final pt = ball.trail[i].position;
            final r = ball.radius * (1.1 + 0.3 * sin(time * 14 + i)) * taper;
            if (r <= 0.5) continue;
            _stroke
              ..strokeWidth = 1.2
              ..color = _ca(const Color(0xFF00E5FF), 0.75 * taper);
            canvas.drawCircle(pt, r, _stroke);
          }
        } else if (trailStyle == TrailStyle.fire) {
          // === ELEVATED FIRE TRAIL: Blazing Inferno Wake (Tapering to flickering tips) ===
          final firePts = <Offset>[Offset(ball.x, ball.y)];
          for (int i = 0; i < trailCount - 1; i++) {
            final p1 = ball.trail[i].position;
            final p2 = ball.trail[i + 1].position;
            final progress = i / (trailCount - 1);
            final taper = (1.0 - progress).clamp(0.0, 1.0);

            final dx = p2.dx - p1.dx;
            final dy = p2.dy - p1.dy;
            final segLen = sqrt(dx * dx + dy * dy);
            if (segLen > 0.001) {
              final nx = -dy / segLen;
              final ny = dx / segLen;
              final wave = sin(time * 16.0 + i * 0.9) * (ball.radius * 0.65 * taper);
              firePts.add(Offset((p1.dx + p2.dx) * 0.5 + nx * wave, (p1.dy + p2.dy) * 0.5 + ny * wave));
            }
            firePts.add(p2);
          }

          _stroke
            ..style = PaintingStyle.stroke
            ..strokeCap = StrokeCap.round
            ..strokeJoin = StrokeJoin.round
            ..maskFilter = null;

          // Layer 1: Outer billowing heat haze (tapering, NO blur)
          for (int i = 0; i < firePts.length - 1; i++) {
            final progress = (i + 0.5) / (firePts.length - 1);
            final taper = (1.0 - progress).clamp(0.0, 1.0);
            _stroke
              ..strokeWidth = (ball.radius * 2.8 * taper).clamp(0.8, ball.radius * 2.8)
              ..color = _ca(const Color(0xFFFF1744), 0.28 * taper);
            canvas.drawLine(firePts[i], firePts[i + 1], _stroke);
          }

          // Layer 2: Roaring orange/amber flame ribbon (tapering)
          for (int i = 0; i < firePts.length - 1; i++) {
            final progress = (i + 0.5) / (firePts.length - 1);
            final taper = (1.0 - progress).clamp(0.0, 1.0);
            _stroke
              ..strokeWidth = (ball.radius * 1.5 * taper).clamp(0.6, ball.radius * 1.5)
              ..color = _ca(const Color(0xFFFF6D00), 0.85 * taper);
            canvas.drawLine(firePts[i], firePts[i + 1], _stroke);
          }

          // Layer 3: Blinding incandescent yellow-white core (tapering)
          for (int i = 0; i < firePts.length - 1; i++) {
            final progress = (i + 0.5) / (firePts.length - 1);
            final taper = (1.0 - progress).clamp(0.0, 1.0);
            _stroke
              ..strokeWidth = (ball.radius * 0.6 * taper).clamp(0.4, ball.radius * 0.6)
              ..color = _ca(const Color(0xFFFFF9C4), 0.95 * taper);
            canvas.drawLine(firePts[i], firePts[i + 1], _stroke);
          }

          // Layer 4: Fiery ember sparks (scaling down with taper)
          _fill
            ..style = PaintingStyle.fill
            ..maskFilter = null;
          for (int i = 0; i < trailCount; i += 2) {
            final progress = trailCount > 1 ? i / (trailCount - 1) : 0.0;
            final taper = (1.0 - progress).clamp(0.0, 1.0);
            final pt = ball.trail[i].position;
            final emberPulse = sin(time * 22.0 + i * 1.8) * (ball.radius * 0.5 * taper);
            final emberSize = ball.radius * (0.55 + 0.3 * sin(time * 14 + i)) * taper;
            if (emberSize <= 0.4) continue;
            _fill.color = _ca((i % 4 == 0 ? const Color(0xFFFFEB3B) : const Color(0xFFFF3D00)), 0.9 * taper);
            canvas.drawCircle(Offset(pt.dx + emberPulse, pt.dy - emberPulse), emberSize, _fill);
          }
        } else {
          // Standard / Fireball / CornerBoost trail (Tapering to aerodynamic tip)
          if (isFireball) {
            // Intense blazing multi-stage inferno (layered tapering passes, NO blur)
            _stroke
              ..style = PaintingStyle.stroke
              ..strokeCap = StrokeCap.round
              ..strokeJoin = StrokeJoin.round
              ..maskFilter = null;

            // Pass 1: Outer scarlet flame
            for (int i = 0; i < trailCount - 1; i++) {
              final progress = (i + 0.5) / (trailCount - 1);
              final taper = (1.0 - progress).clamp(0.0, 1.0);
              _stroke
                ..strokeWidth = (ball.radius * 3.0 * taper).clamp(0.8, ball.radius * 3.0)
                ..color = _ca(const Color(0xFFFF1744), 0.28 * taper);
              canvas.drawLine(ball.trail[i].position, ball.trail[i + 1].position, _stroke);
            }

            // Pass 2: Mid amber flame
            for (int i = 0; i < trailCount - 1; i++) {
              final progress = (i + 0.5) / (trailCount - 1);
              final taper = (1.0 - progress).clamp(0.0, 1.0);
              _stroke
                ..strokeWidth = (ball.radius * 1.7 * taper).clamp(0.6, ball.radius * 1.7)
                ..color = _ca(const Color(0xFFFF6D00), 0.85 * taper);
              canvas.drawLine(ball.trail[i].position, ball.trail[i + 1].position, _stroke);
            }

            // Pass 3: Incandescent yellow core
            for (int i = 0; i < trailCount - 1; i++) {
              final progress = (i + 0.5) / (trailCount - 1);
              final taper = (1.0 - progress).clamp(0.0, 1.0);
              _stroke
                ..strokeWidth = (ball.radius * 0.75 * taper).clamp(0.4, ball.radius * 0.75)
                ..color = _ca(const Color(0xFFFFEB3B), 0.95 * taper);
              canvas.drawLine(ball.trail[i].position, ball.trail[i + 1].position, _stroke);
            }

            // Pass 4: White core needle
            for (int i = 0; i < trailCount - 1; i++) {
              final progress = (i + 0.5) / (trailCount - 1);
              final taper = (1.0 - progress).clamp(0.0, 1.0);
              _stroke
                ..strokeWidth = (ball.radius * 0.35 * taper).clamp(0.4, ball.radius * 0.35)
                ..color = _ca(Colors.white, 0.98 * taper);
              canvas.drawLine(ball.trail[i].position, ball.trail[i + 1].position, _stroke);
            }
          } else if (isCornerBoost) {
            // Supersonic golden Mach wake (layered tapering passes, NO blur!)
            _stroke
              ..style = PaintingStyle.stroke
              ..strokeCap = StrokeCap.round
              ..strokeJoin = StrokeJoin.round
              ..maskFilter = null;

            // Pass 1: Outer golden jet haze
            for (int i = 0; i < trailCount - 1; i++) {
              final progress = (i + 0.5) / (trailCount - 1);
              final taper = (1.0 - progress).clamp(0.0, 1.0);
              _stroke
                ..strokeWidth = (ball.radius * 2.6 * taper).clamp(0.8, ball.radius * 2.6)
                ..color = _ca(const Color(0xFFFFAB00), 0.26 * taper);
              canvas.drawLine(ball.trail[i].position, ball.trail[i + 1].position, _stroke);
            }

            // Pass 2: Mid plasma thrust ribbon
            for (int i = 0; i < trailCount - 1; i++) {
              final progress = (i + 0.5) / (trailCount - 1);
              final taper = (1.0 - progress).clamp(0.0, 1.0);
              _stroke
                ..strokeWidth = (ball.radius * 1.4 * taper).clamp(0.6, ball.radius * 1.4)
                ..color = _ca(const Color(0xFFFFD600), 0.85 * taper);
              canvas.drawLine(ball.trail[i].position, ball.trail[i + 1].position, _stroke);
            }

            // Pass 3: Blinding white-gold core needle
            for (int i = 0; i < trailCount - 1; i++) {
              final progress = (i + 0.5) / (trailCount - 1);
              final taper = (1.0 - progress).clamp(0.0, 1.0);
              _stroke
                ..strokeWidth = (ball.radius * 0.55 * taper).clamp(0.4, ball.radius * 0.55)
                ..color = _ca(const Color(0xFFFFFDE7), 0.96 * taper);
              canvas.drawLine(ball.trail[i].position, ball.trail[i + 1].position, _stroke);
            }

            // Embedded Mach shock diamond pulses along the trail (tapering)
            _fill
              ..style = PaintingStyle.fill
              ..maskFilter = null;
            for (int i = 2; i < trailCount; i += 3) {
              final progress = i / (trailCount - 1);
              final taper = (1.0 - progress).clamp(0.0, 1.0);
              final pt = ball.trail[i].position;
              final dSize = ball.radius * (0.8 + 0.25 * sin(time * 30 + i)) * taper;
              if (dSize <= 0.5) continue;

              _tempPath.reset();
              _tempPath.moveTo(pt.dx, pt.dy - dSize * 1.2);
              _tempPath.lineTo(pt.dx + dSize * 0.7, pt.dy);
              _tempPath.lineTo(pt.dx, pt.dy + dSize * 1.2);
              _tempPath.lineTo(pt.dx - dSize * 0.7, pt.dy);
              _tempPath.close();

              _fill.color = _ca(const Color(0xFFFFD600), 0.85 * taper);
              canvas.drawPath(_tempPath, _fill);

              _fill.color = _ca(Colors.white, 0.95 * taper);
              canvas.drawCircle(pt, dSize * 0.35, _fill);
            }
          } else {
            // === VIBRANT UNDULATING ENERGY RIBBON (Default / Standard Trail, Tapering to fine tip) ===
            final wavePts = <Offset>[Offset(ball.x, ball.y)];
            for (int i = 0; i < trailCount - 1; i++) {
              final p1 = ball.trail[i].position;
              final p2 = ball.trail[i + 1].position;
              final progress = i / (trailCount - 1);
              final taper = (1.0 - progress).clamp(0.0, 1.0);

              final dx = p2.dx - p1.dx;
              final dy = p2.dy - p1.dy;
              final segLen = sqrt(dx * dx + dy * dy);
              if (segLen > 0.001) {
                final nx = -dy / segLen;
                final ny = dx / segLen;
                final wave = sin(time * 12.0 + i * 0.75) * (ball.radius * 0.38 * taper);
                wavePts.add(Offset((p1.dx + p2.dx) * 0.5 + nx * wave, (p1.dy + p2.dy) * 0.5 + ny * wave));
              }
              wavePts.add(p2);
            }

            _stroke
              ..style = PaintingStyle.stroke
              ..strokeCap = StrokeCap.round
              ..strokeJoin = StrokeJoin.round
              ..maskFilter = null;

            // Layer 1: Outer pulsating luminous bloom segments (tapering, NO blur)
            for (int i = 0; i < wavePts.length - 1; i++) {
              final progress = (i + 0.5) / (wavePts.length - 1);
              final taper = (1.0 - progress).clamp(0.0, 1.0);
              _stroke
                ..strokeWidth = (ball.radius * 2.2 * taper).clamp(0.8, ball.radius * 2.2)
                ..color = _ca(skinGlow, 0.25 * taper);
              canvas.drawLine(wavePts[i], wavePts[i + 1], _stroke);
            }

            // Layer 2: Main energetic fluid ribbon segments (tapering)
            for (int i = 0; i < wavePts.length - 1; i++) {
              final progress = (i + 0.5) / (wavePts.length - 1);
              final taper = (1.0 - progress).clamp(0.0, 1.0);
              _stroke
                ..strokeWidth = (ball.radius * 1.1 * taper).clamp(0.6, ball.radius * 1.1)
                ..color = _ca(skinMain, 0.85 * taper);
              canvas.drawLine(wavePts[i], wavePts[i + 1], _stroke);
            }

            // Layer 3: Pure starlight white core filament segments (tapering)
            for (int i = 0; i < wavePts.length - 1; i++) {
              final progress = (i + 0.5) / (wavePts.length - 1);
              final taper = (1.0 - progress).clamp(0.0, 1.0);
              _stroke
                ..strokeWidth = (ball.radius * 0.4 * taper).clamp(0.4, ball.radius * 0.4)
                ..color = _ca(Colors.white, 0.85 * taper);
              canvas.drawLine(wavePts[i], wavePts[i + 1], _stroke);
            }

            // Drifting stardust sparkles along the undulating trail (scaling down with taper)
            _fill
              ..style = PaintingStyle.fill
              ..maskFilter = null;
            for (int i = 0; i < trailCount; i += 3) {
              final progress = trailCount > 1 ? i / (trailCount - 1) : 0.0;
              final taper = (1.0 - progress).clamp(0.0, 1.0);
              final pt = ball.trail[i].position;
              final sparkSize = ball.radius * (0.4 + 0.25 * sin(time * 18 + i)) * taper;
              if (sparkSize <= 0.4) continue;
              _fill.color = _ca(Colors.white, 0.8 * taper);
              canvas.drawCircle(pt, sparkSize, _fill);
            }
          }
        }
      }

      canvas.save();
      canvas.translate(ball.x, ball.y);

      if (ball.squashTimer > 0) {
        canvas.rotate(ball.squashAngle);
        final factor = 1.0 + (ball.squashTimer / 0.22) * 0.4;
        canvas.scale(factor, 1.0 / factor);
        canvas.rotate(-ball.squashAngle);
      }

      if (isFireball) {
        // === CAPSULE FIREBALL: Omnidirectional Blazing Crimson Inferno (ZERO BLUR LAG) ===
        final flick = 0.65 + 0.35 * sin(time * 28);

        // 1. Deep scarlet outer heat haze
        _fill
          ..style = PaintingStyle.fill
          ..maskFilter = null
          ..color = _ca(const Color(0xFFFF1744), 0.22 * flick);
        canvas.drawCircle(Offset.zero, ball.radius + 13 + flick * 4, _fill);

        // 2. Fiery crimson inner blaze
        _fill.color = _ca(const Color(0xFFFF3D00), 0.45 * flick);
        canvas.drawCircle(Offset.zero, ball.radius + 7 + flick * 2, _fill);

        // 3. Swirling crimson/orange flame spikes
        _stroke
          ..strokeWidth = 2.5
          ..strokeCap = StrokeCap.round
          ..maskFilter = null
          ..color = _ca(const Color(0xFFFFD54F), 0.92);

        for (int f = 0; f < 8; f++) {
          final a = time * 10 + f * (pi * 2 / 8) + (sin(time * 18 + f) * 0.25);
          final len = ball.radius * (1.7 + flick * 0.8);
          canvas.drawLine(
            Offset(cos(a) * ball.radius * 0.4, sin(a) * ball.radius * 0.4),
            Offset(cos(a) * len, sin(a) * len),
            _stroke,
          );
        }
      } else if (isCornerBoost) {
        // === CORNER SHOT (Köşe Vuruşu): Supersonic Jet Afterburners & Electric Mach Wake (ZERO BLUR LAG) ===
        // Supersonic jet alevleri, bow shock arc ve mach shock diamonds:
        // High-performance geometric rendering to guarantee rock-solid 60/120 FPS!
        final spd = ball.speed;
        final backAngle = (spd > 15.0) ? atan2(-ball.vy, -ball.vx) : (pi / 2);
        final fwdAngle = backAngle + pi;
        final flick = 0.82 + 0.18 * sin(time * 36);
        final hyperFlick = sin(time * 55);

        // Unit directional vectors relative to ball center
        final backX = cos(backAngle);
        final backY = sin(backAngle);
        final perpX = -backY;
        final perpY = backX;

        // 1. Blinding Golden-White Corona Glow & Radiant Heat Haze (2-pass alpha, NO blur)
        _fill
          ..style = PaintingStyle.fill
          ..maskFilter = null
          ..color = _ca(const Color(0xFFFFAB00), 0.20 * flick);
        canvas.drawCircle(Offset.zero, ball.radius * 2.2, _fill);

        _fill.color = _ca(const Color(0xFFFFD600), 0.42 * flick);
        canvas.drawCircle(Offset.zero, ball.radius * 1.5, _fill);

        // 2. Supersonic Aerodynamic Bow Shock Arc & Mach Shock Streamers (Ahead of Ball)
        final fwdX = cos(fwdAngle);
        final fwdY = sin(fwdAngle);
        final bowCenter = Offset(fwdX * (ball.radius * 0.7), fwdY * (ball.radius * 0.7));

        _stroke
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round
          ..maskFilter = null
          ..strokeWidth = 3.6
          ..color = _ca(const Color(0xFFFFF9C4), 0.30 * flick);
        canvas.drawArc(
          Rect.fromCircle(center: bowCenter, radius: ball.radius + 3.5),
          fwdAngle - pi / 2.8,
          pi / 1.4,
          false,
          _stroke,
        );

        _stroke
          ..strokeWidth = 1.8
          ..color = _ca(const Color(0xFFFFF9C4), 0.90 * flick);
        canvas.drawArc(
          Rect.fromCircle(center: bowCenter, radius: ball.radius + 3.5),
          fwdAngle - pi / 2.8,
          pi / 1.4,
          false,
          _stroke,
        );

        // Swept Mach lines slicing backwards from bow shock
        final machLeftStart = bowCenter + Offset(cos(fwdAngle - pi / 3.0) * (ball.radius + 3.5), sin(fwdAngle - pi / 3.0) * (ball.radius + 3.5));
        final machRightStart = bowCenter + Offset(cos(fwdAngle + pi / 3.0) * (ball.radius + 3.5), sin(fwdAngle + pi / 3.0) * (ball.radius + 3.5));
        _stroke
          ..strokeWidth = 1.3
          ..color = _ca(const Color(0xFFFFE082), 0.6 * flick);
        canvas.drawLine(
          machLeftStart,
          machLeftStart + Offset(backX * (ball.radius * 1.8) + perpX * (ball.radius * 0.8), backY * (ball.radius * 1.8) + perpY * (ball.radius * 0.8)),
          _stroke,
        );
        canvas.drawLine(
          machRightStart,
          machRightStart + Offset(backX * (ball.radius * 1.8) - perpX * (ball.radius * 0.8), backY * (ball.radius * 1.8) - perpY * (ball.radius * 0.8)),
          _stroke,
        );

        // 3. Supersonic Jet Exhaust Plume (Opposite to velocity vector)
        final mainFlameLen = ball.radius * (3.8 + flick * 1.4);
        final baseWidth = ball.radius * 0.85;

        // Outer amber supersonic exhaust cone
        _tempPath.reset();
        _tempPath.moveTo(perpX * baseWidth, perpY * baseWidth);
        _tempPath.lineTo(-perpX * baseWidth, -perpY * baseWidth);
        _tempPath.lineTo(backX * mainFlameLen, backY * mainFlameLen);
        _tempPath.close();

        _fill
          ..style = PaintingStyle.fill
          ..maskFilter = null
          ..color = _ca(const Color(0xFFFF6D00), 0.35);
        canvas.drawPath(_tempPath, _fill);

        // Mid golden plasma thrust cone
        _tempPath.reset();
        _tempPath.moveTo(perpX * (baseWidth * 0.7), perpY * (baseWidth * 0.7));
        _tempPath.lineTo(-perpX * (baseWidth * 0.7), -perpY * (baseWidth * 0.7));
        _tempPath.lineTo(backX * (mainFlameLen * 0.85), backY * (mainFlameLen * 0.85));
        _tempPath.close();

        _fill.color = _ca(const Color(0xFFFFD600), 0.85);
        canvas.drawPath(_tempPath, _fill);

        // Hyper-dense white-gold core jet needle
        _tempPath.reset();
        _tempPath.moveTo(perpX * (baseWidth * 0.35), perpY * (baseWidth * 0.35));
        _tempPath.lineTo(-perpX * (baseWidth * 0.35), -perpY * (baseWidth * 0.35));
        _tempPath.lineTo(backX * (mainFlameLen * 0.55), backY * (mainFlameLen * 0.55));
        _tempPath.close();

        _fill.color = _ca(const Color(0xFFFFFDE7), 0.98);
        canvas.drawPath(_tempPath, _fill);

        // 4. Twin Vector Flanking Jets (Secondary Nozzles at ±22°)
        for (final angleOffset in [-0.38, 0.38]) {
          final sideAngle = backAngle + angleOffset;
          final sideDirX = cos(sideAngle);
          final sideDirY = sin(sideAngle);
          final sideFlameLen = ball.radius * (2.2 + flick * 0.9 + hyperFlick * 0.3);
          final nozzleOffset = Offset(
            (angleOffset > 0 ? perpX : -perpX) * (ball.radius * 0.5),
            (angleOffset > 0 ? perpY : -perpY) * (ball.radius * 0.5),
          );

          _stroke
            ..strokeWidth = 3.6
            ..strokeCap = StrokeCap.round
            ..maskFilter = null
            ..color = _ca(const Color(0xFFFF9100), 0.35);
          canvas.drawLine(nozzleOffset, nozzleOffset + Offset(sideDirX * sideFlameLen, sideDirY * sideFlameLen), _stroke);

          _stroke
            ..strokeWidth = 1.3
            ..color = _ca(const Color(0xFFFFF9C4), 0.95);
          canvas.drawLine(nozzleOffset, nozzleOffset + Offset(sideDirX * (sideFlameLen * 0.65), sideDirY * (sideFlameLen * 0.65)), _stroke);
        }

        // 5. Mach Shock Diamonds along the central exhaust plume
        final diamondDistances = [1.3, 2.1, 2.9, 3.7];
        final diamondSizes = [ball.radius * 0.52, ball.radius * 0.42, ball.radius * 0.32, ball.radius * 0.22];

        for (int d = 0; d < diamondDistances.length; d++) {
          final dist = ball.radius * diamondDistances[d];
          final dCenter = Offset(backX * dist, backY * dist);
          final dSize = diamondSizes[d] * (0.88 + 0.22 * sin(time * 38 + d * 1.7));

          _tempPath.reset();
          // Axial tip forward
          _tempPath.moveTo(dCenter.dx - backX * (dSize * 1.25), dCenter.dy - backY * (dSize * 1.25));
          // Lateral wing right
          _tempPath.lineTo(dCenter.dx + perpX * (dSize * 0.75), dCenter.dy + perpY * (dSize * 0.75));
          // Axial tip backward
          _tempPath.lineTo(dCenter.dx + backX * (dSize * 1.25), dCenter.dy + backY * (dSize * 1.25));
          // Lateral wing left
          _tempPath.lineTo(dCenter.dx - perpX * (dSize * 0.75), dCenter.dy - perpY * (dSize * 0.75));
          _tempPath.close();

          // Shock diamond glowing amber rim (NO blur lag!)
          _fill
            ..style = PaintingStyle.fill
            ..maskFilter = null
            ..color = _ca(const Color(0xFFFFD600), 0.85);
          canvas.drawPath(_tempPath, _fill);

          // Shock diamond blinding white plasma nucleus
          _fill.color = _ca(Colors.white, 0.96);
          canvas.drawCircle(dCenter, dSize * 0.35, _fill);
        }

        // 6. Vibrant Electric Velocity Sparks & Charged Arc Streamers
        for (int s = 0; s < 3; s++) {
          final arcSign = (s % 2 == 0) ? 1.0 : -1.0;
          final arcSeed = s * 2.3;
          final arcLen = ball.radius * (1.6 + s * 0.8);
          final arcOffset = sin(time * 42 + arcSeed) * (ball.radius * 0.6);

          final p1 = Offset(perpX * (arcSign * ball.radius * 0.6), perpY * (arcSign * ball.radius * 0.6));
          final pMid = Offset(
            backX * (arcLen * 0.5) + perpX * (arcSign * ball.radius * 0.8 + arcOffset),
            backY * (arcLen * 0.5) + perpY * (arcSign * ball.radius * 0.8 + arcOffset),
          );
          final pEnd = Offset(
            backX * arcLen + perpX * (arcSign * ball.radius * 0.4 - arcOffset * 0.5),
            backY * arcLen + perpY * (arcSign * ball.radius * 0.4 - arcOffset * 0.5),
          );

          _stroke
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.4
            ..strokeCap = StrokeCap.round
            ..maskFilter = null
            ..color = _ca(const Color(0xFFFFEA00), 0.85);
          canvas.drawLine(p1, pMid, _stroke);

          _stroke
            ..strokeWidth = 1.0
            ..color = Colors.white;
          canvas.drawLine(pMid, pEnd, _stroke);
        }

        // Rotating velocity star glints trailing in the slipstream
        for (int g = 0; g < 2; g++) {
          final gDist = ball.radius * (1.8 + g * 1.5 + sin(time * 12 + g) * 0.3);
          final gLat = sin(time * 20 + g * 3.1) * (ball.radius * 0.6);
          final gPos = Offset(backX * gDist + perpX * gLat, backY * gDist + perpY * gLat);
          final gAngle = time * 8 + g * 2.5;
          final gSize = ball.radius * 0.5;

          _stroke
            ..strokeWidth = 1.1
            ..color = _ca(const Color(0xFFFFF9C4), 0.9);
          canvas.drawLine(
            Offset(gPos.dx - cos(gAngle) * gSize, gPos.dy - sin(gAngle) * gSize),
            Offset(gPos.dx + cos(gAngle) * gSize, gPos.dy + sin(gAngle) * gSize),
            _stroke,
          );
          canvas.drawLine(
            Offset(gPos.dx - cos(gAngle + pi / 2) * (gSize * 0.5), gPos.dy - sin(gAngle + pi / 2) * (gSize * 0.5)),
            Offset(gPos.dx + cos(gAngle + pi / 2) * (gSize * 0.5), gPos.dy + sin(gAngle + pi / 2) * (gSize * 0.5)),
            _stroke,
          );
        }
      }

      if (!isFireball && !isCornerBoost && !ball.isPurple && !ball.isBomb) {
        _drawBallSkinDetails(canvas, ball, c.activeBallSkin, time);
      } else {
        // Base ball glow ring
        final glowColor = ball.isPurple
            ? const Color(0xFFE040FB)
            : (isFireball
                ? const Color(0xFFFF1744)
                : (isCornerBoost ? const Color(0xFFFFD600) : skinGlow));
        _fill
          ..style = PaintingStyle.fill
          ..maskFilter = null
          ..color = _ca(glowColor, 0.32);
        canvas.drawCircle(Offset.zero, ball.radius + 3.5, _fill);

        // Ball Core
        final coreColor = ball.isPurple
            ? const Color(0xFFAA00FF)
            : (isFireball
                ? const Color(0xFFD50000)
                : (isCornerBoost
                    ? const Color(0xFFFFC107)
                    : (ball.isBomb ? const Color(0xFFFF5252) : skinMain)));
        _fill.color = coreColor;
        canvas.drawCircle(Offset.zero, ball.radius, _fill);

        // Specular shine
        _fill.color = _ca(Colors.white, (isFireball || isCornerBoost) ? 0.85 : 0.55);
        canvas.drawCircle(Offset(-ball.radius * 0.28, -ball.radius * 0.28), ball.radius * 0.38, _fill);
        _fill.color = _ca(Colors.white, 0.95);
        canvas.drawCircle(Offset(-ball.radius * 0.38, -ball.radius * 0.38), ball.radius * 0.16, _fill);
      }

      canvas.restore();
    }
  }

  void _drawBallSkinDetails(Canvas canvas, Ball ball, BallSkin skin, double time) {
    final r = ball.radius;

    // Outer glow halo
    _fill
      ..style = PaintingStyle.fill
      ..maskFilter = null
      ..color = _ca(skin.glowColor, 0.35);
    canvas.drawCircle(Offset.zero, r + 3.5, _fill);

    // 1. Skin-specific base body with radial gradient
    final skinKey = Object.hash(skin.id, (r * 2).round());
    _fill.shader = _skinShaders.putIfAbsent(skinKey, () {
      return RadialGradient(
        center: const Alignment(-0.35, -0.35),
        radius: 0.95,
        colors: [skin.mainColor, skin.darkColor],
      ).createShader(Rect.fromCircle(center: Offset.zero, radius: r));
    });
    canvas.drawCircle(Offset.zero, r, _fill);
    _fill.shader = null;

    // 2. Specific Signature Effects for each Ball Skin
    switch (skin.id) {
      case 'classic':
        // Pearl chrome: futuristic glowing cyan energy equator ring
        _stroke
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.2
          ..color = _ca(const Color(0xFF80D8FF), 0.85);
        canvas.drawOval(Rect.fromCenter(center: Offset.zero, width: r * 1.85, height: r * 0.38), _stroke);
        break;

      case 'pembe':
        // Neon Pembe: glowing cyber core & rotating energy cross-arcs
        _fill.color = const Color(0xFF4A0E2E);
        canvas.drawCircle(Offset.zero, r * 0.55, _fill);
        _fill.color = const Color(0xFFFF4081);
        canvas.drawCircle(Offset.zero, r * 0.32, _fill);
        _stroke
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.2
          ..color = const Color(0xFFFF80AB);
        final a = time * 3.0;
        canvas.drawLine(Offset(cos(a) * r * 0.7, sin(a) * r * 0.7), Offset(-cos(a) * r * 0.7, -sin(a) * r * 0.7), _stroke);
        canvas.drawLine(Offset(cos(a + pi / 2) * r * 0.7, sin(a + pi / 2) * r * 0.7), Offset(-cos(a + pi / 2) * r * 0.7, -sin(a + pi / 2) * r * 0.7), _stroke);
        break;

      case 'plazma':
        // Plazma Mavi: crackling core & tilted 3D orbiting electron ring
        _stroke
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.3
          ..color = const Color(0xFF00E5FF);
        canvas.save();
        canvas.rotate(time * 3.5);
        canvas.drawOval(Rect.fromCenter(center: Offset.zero, width: r * 2.1, height: r * 0.75), _stroke);
        _fill.color = Colors.white;
        canvas.drawCircle(Offset(r * 1.05, 0), 1.8, _fill);
        canvas.restore();
        break;

      case 'zumrut':
        // Zümrüt: Faceted emerald crystal lines & sharp diamond glint
        _stroke
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.0
          ..color = _ca(const Color(0xFFB9F6CA), 0.75);
        canvas.drawLine(Offset(-r * 0.6, 0), Offset(0, -r * 0.6), _stroke);
        canvas.drawLine(Offset(0, -r * 0.6), Offset(r * 0.6, 0), _stroke);
        canvas.drawLine(Offset(r * 0.6, 0), Offset(0, r * 0.6), _stroke);
        canvas.drawLine(Offset(0, r * 0.6), Offset(-r * 0.6, 0), _stroke);
        break;

      case 'golge':
        // Gölge Mor: Occult singularity, dark void center & rotating rune pips
        _fill.color = const Color(0xFF120320);
        canvas.drawCircle(Offset.zero, r * 0.7, _fill);
        for (int i = 0; i < 4; i++) {
          final ra = time * 2.2 + i * (pi / 2);
          final rx = cos(ra) * (r * 0.52);
          final ry = sin(ra) * (r * 0.52);
          _fill.color = const Color(0xFFD500F9);
          canvas.drawCircle(Offset(rx, ry), 1.4, _fill);
        }
        break;

      case 'ates':
        // Ateş: Molten magma ball with pulsing volcanic veins
        final magmaPulse = 0.7 + 0.3 * sin(time * 8.0);
        _fill.color = _ca(const Color(0xFFFFD54F), magmaPulse);
        canvas.drawCircle(Offset.zero, r * 0.45, _fill);
        _stroke
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.2
          ..color = const Color(0xFFFF3D00);
        canvas.drawLine(Offset(-r * 0.5, -r * 0.2), Offset(0, r * 0.4), _stroke);
        canvas.drawLine(Offset(0, r * 0.4), Offset(r * 0.4, 0), _stroke);
        break;

      case 'isilti':
        // Yıldız Işıltısı: Rotating 4-point golden starlight cross glint
        final sa = time * 2.5;
        final slen = r * 1.35;
        _stroke
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.4
          ..color = const Color(0xFFFFF9C4);
        canvas.drawLine(Offset(-cos(sa) * slen, -sin(sa) * slen), Offset(cos(sa) * slen, sin(sa) * slen), _stroke);
        canvas.drawLine(Offset(-cos(sa + pi / 2) * slen * 0.65, -sin(sa + pi / 2) * slen * 0.65), Offset(cos(sa + pi / 2) * slen * 0.65, sin(sa + pi / 2) * slen * 0.65), _stroke);
        break;

      case 'altin':
        // Saf Altın: Metallic royal engraved gold band & diamond reflection
        _stroke
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.0
          ..color = const Color(0xFFFFF176);
        canvas.drawOval(Rect.fromCenter(center: Offset.zero, width: r * 1.8, height: r * 0.4), _stroke);
        _fill.color = Colors.white;
        canvas.drawCircle(Offset(0, -r * 0.2), 1.5, _fill);
        break;

      case 'kara_delik_top':
        // Void Singularity: Pitch black inner horizon & swirling magenta accretion disk
        _fill.color = Colors.black;
        canvas.drawCircle(Offset.zero, r * 0.75, _fill);
        _stroke
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5
          ..color = const Color(0xFFE040FB);
        canvas.save();
        canvas.rotate(-time * 4.0);
        canvas.drawOval(Rect.fromCenter(center: Offset.zero, width: r * 2.0, height: r * 0.65), _stroke);
        canvas.restore();
        break;

      case 'elmas_top':
        // Prizmatik Elmas: Prismatic rainbow refraction ring & multifaceted crystal sparkles
        _stroke
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.2
          ..color = const Color(0xFF18FFFF);
        canvas.drawCircle(Offset.zero, r * 0.88, _stroke);
        final da = time * 2.0;
        _stroke.color = Colors.white;
        _stroke.strokeWidth = 1.3;
        canvas.drawLine(Offset(-cos(da) * r * 0.8, -sin(da) * r * 0.8), Offset(cos(da) * r * 0.8, sin(da) * r * 0.8), _stroke);
        canvas.drawLine(Offset(-cos(da + pi / 2) * r * 0.8, -sin(da + pi / 2) * r * 0.8), Offset(cos(da + pi / 2) * r * 0.8, sin(da + pi / 2) * r * 0.8), _stroke);
        break;
    }

    // 3. Specular highlights
    _fill.color = _ca(Colors.white, 0.60);
    canvas.drawCircle(Offset(-r * 0.28, -r * 0.28), r * 0.36, _fill);
    _fill.color = _ca(Colors.white, 0.95);
    canvas.drawCircle(Offset(-r * 0.38, -r * 0.38), r * 0.16, _fill);
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

  void _drawDice(Canvas canvas) {
    if (!c.isDiceActive) return;

    final centerY = c.paddle.y - 75.0;
    final centerX = c.paddle.x + c.paddle.width / 2;

    if (!c.isDoubleDice) {
      _drawSingleDie(
        canvas: canvas,
        center: Offset(centerX, centerY),
        value: c.diceDisplay1,
        isGold: false,
        time: time,
        isRolling: c.isDiceRolling,
      );
    } else {
      // 2 Dice (Jackpot!)
      _drawSingleDie(
        canvas: canvas,
        center: Offset(centerX - 28.0, centerY),
        value: c.diceDisplay1,
        isGold: false,
        time: time,
        isRolling: c.isDiceRolling,
      );
      _drawSingleDie(
        canvas: canvas,
        center: Offset(centerX + 28.0, centerY),
        value: c.diceDisplay2,
        isGold: true,
        time: time,
        isRolling: c.isDiceRolling,
      );
    }

    // Result badge below dice when stopped
    if (!c.isDiceRolling && c.diceDisplayTimer > 0) {
      final total = c.diceTotal;
      final badgeColor = total == 12
          ? const Color(0xFFFFD700)
          : (total == 11
              ? const Color(0xFFFF5722)
              : (total == 10 ? const Color(0xFF00E5FF) : Colors.white));

      final text = total == 12
          ? '🌟 12 - MEGA JACKPOT! 🌟'
          : (total == 11
              ? '🔥 11 - EPİK ŞANS! 🔥'
              : (total == 10 ? '💎 10 - BÜYÜK KAZANÇ! 💎' : '🎲  X SALVO 🎲'));

      _tp.text = TextSpan(
        text: text,
        style: TextStyle(
          color: badgeColor,
          fontSize: 12,
          fontWeight: FontWeight.w900,
          shadows: [
            Shadow(color: _ca(badgeColor, 0.8), offset: const Offset(0, 1)),
            const Shadow(color: Colors.black, offset: Offset(1, 1)),
          ],
        ),
      );
      _tp.layout();
      _tp.paint(canvas, Offset(centerX - _tp.width / 2, centerY - 38.0));
    }
  }

  void _drawSingleDie({
    required Canvas canvas,
    required Offset center,
    required int value,
    required bool isGold,
    required double time,
    required bool isRolling,
  }) {
    canvas.save();
    canvas.translate(center.dx, center.dy);

    if (isRolling) {
      final rollAngle = sin(time * 26.0 + (isGold ? 1.57 : 0.0)) * 0.45;
      canvas.rotate(rollAngle);
      final bounce = (sin(time * 32.0).abs() * 6.0);
      canvas.translate(0, -bounce);
    }

    const diceSize = 42.0;
    const radius = 8.0;
    final rrect = RRect.fromRectAndRadius(
      Rect.fromCenter(center: Offset.zero, width: diceSize, height: diceSize),
      const Radius.circular(radius),
    );

    // 1. Soft 3D drop shadow
    _fill
      ..style = PaintingStyle.fill
      ..maskFilter = null
      ..color = _ca(Colors.black, 0.35);
    canvas.drawRRect(rrect.shift(const Offset(2.0, 3.5)), _fill);

    // 2. Die Body (Pearl Ivory or Radiant Gold)
    if (isGold) {
      _stroke
        ..color = _ca(const Color(0xFFFFD700), 0.35 + sin(time * 10) * 0.15)
        ..strokeWidth = 4.5
        ..maskFilter = null;
      canvas.drawRRect(rrect, _stroke);

      _fill.shader = const LinearGradient(
        colors: [Color(0xFFFFF9C4), Color(0xFFFFD700), Color(0xFFFFA000)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ).createShader(rrect.outerRect);
      canvas.drawRRect(rrect, _fill);
      _fill.shader = null;

      _stroke
        ..color = const Color(0xFFFFB300)
        ..strokeWidth = 2.0;
      canvas.drawRRect(rrect, _stroke);
    } else {
      _fill.shader = const LinearGradient(
        colors: [Color(0xFFFFFFFF), Color(0xFFF0F0F0), Color(0xFFE0E0E0)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ).createShader(rrect.outerRect);
      canvas.drawRRect(rrect, _fill);
      _fill.shader = null;

      _stroke
        ..color = const Color(0xFFBDBDBD)
        ..strokeWidth = 1.5;
      canvas.drawRRect(rrect, _stroke);
    }

    // 3. Specular top gloss
    final glossRect = Rect.fromLTWH(-diceSize / 2 + 3, -diceSize / 2 + 2, diceSize - 6, diceSize * 0.38);
    _fill.color = _ca(Colors.white, isGold ? 0.6 : 0.7);
    canvas.drawRRect(RRect.fromRectAndRadius(glossRect, const Radius.circular(4)), _fill);

    // 4. Pips (Dots)
    final pipColor = (value == 1)
        ? const Color(0xFFD50000)
        : (isGold ? const Color(0xFF3E2723) : const Color(0xFF212121));
    _fill.color = pipColor;

    const d = 10.0;
    final rPip = (value == 1) ? 4.5 : 3.0;

    void drawPip(double x, double y) {
      canvas.drawCircle(Offset(x, y), rPip, _fill);
    }

    switch (value) {
      case 1:
        drawPip(0, 0);
        break;
      case 2:
        drawPip(-d, -d);
        drawPip(d, d);
        break;
      case 3:
        drawPip(-d, -d);
        drawPip(0, 0);
        drawPip(d, d);
        break;
      case 4:
        drawPip(-d, -d);
        drawPip(d, -d);
        drawPip(-d, d);
        drawPip(d, d);
        break;
      case 5:
        drawPip(-d, -d);
        drawPip(d, -d);
        drawPip(0, 0);
        drawPip(-d, d);
        drawPip(d, d);
        break;
      case 6:
        drawPip(-d, -d);
        drawPip(d, -d);
        drawPip(-d, 0);
        drawPip(d, 0);
        drawPip(-d, d);
        drawPip(d, d);
        break;
    }

    canvas.restore();
  }

  void _drawCapsules(Canvas canvas) {
    for (final cap in c.capsules) {
      canvas.save();
      canvas.translate(cap.x, cap.y);
      final bob = sin(cap.animTimer * 6.0) * 2.5;
      canvas.translate(0, bob);

      if (cap.type == PowerUpType.life) {
        final pulse = 1.0 + sin(cap.animTimer * 7.0) * 0.12;
        PixelArt.drawPixelHeart(canvas, Offset.zero, 34.0, pulse: pulse);
      } else {
        final img = AssetCache.instance.getSkillImage(cap.type);
        if (img != null) {
          // Draw skill pixel art enlarged directly, NO circular backgrounds
          final src = Rect.fromLTWH(0, 0, img.width.toDouble(), img.height.toDouble());
          final dst = Rect.fromCenter(center: Offset.zero, width: 34.0, height: 34.0);
          canvas.drawImageRect(img, src, dst, _imgPaint);
        } else {
          PixelArt.draw(canvas, cap.type, Offset.zero, 34.0);
        }
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
      _fill.color = _ca(p.color, progress);
      canvas.drawCircle(Offset(p.x, p.y), p.size * progress, _fill);
    }

    for (final s in c.particles.shockwaves) {
      final alpha = (1.0 - s.progress).clamp(0.0, 1.0);
      _stroke
        ..color = _ca(s.color, alpha * 0.75)
        ..strokeWidth = 2.5 * (1.0 - s.progress) + 0.5;
      canvas.drawCircle(Offset(s.x, s.y), s.currentRadius, _stroke);
    }

    for (final f in c.particles.floatingTexts) {
      final alpha = (f.life / f.maxLife).clamp(0.0, 1.0);
      _tp.text = TextSpan(
        text: f.text,
        style: TextStyle(
          color: _ca(f.color, alpha),
          fontSize: f.isLarge ? 22.0 : 13.0,
          fontWeight: FontWeight.w900,
          shadows: const [
            Shadow(color: Colors.black87, offset: Offset(1, 1.5)),
          ],
        ),
      );
      _tp.layout();
      _tp.paint(canvas, Offset(f.x - _tp.width / 2, f.y));
    }
  }

  void _drawBee(Canvas canvas) {
    final bee = c.activeBee;
    if (bee == null || !bee.isAlive) return;

    canvas.save();
    canvas.translate(bee.x, bee.y);
    canvas.scale(0.58, 0.58);
    canvas.rotate(bee.tiltAngle);

    // Flip horizontally if facing left
    if (!bee.isFacingRight) {
      canvas.scale(-1.0, 1.0);
    }

    // === CUTE CHIBI BEE (Directly referencing User Image 1) ===
    // 1. Triangular Stinger at the rear
    final stingerPath = Path()
      ..moveTo(-15.0, -2.0)
      ..lineTo(-23.0, 0.0)
      ..lineTo(-15.0, 2.0)
      ..close();
    _fill
      ..style = PaintingStyle.fill
      ..maskFilter = null
      ..color = const Color(0xFF1B1B1B);
    canvas.drawPath(stingerPath, _fill);

    // 2. Dangling Little Legs (3 bent black legs underneath)
    _stroke
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..maskFilter = null
      ..strokeWidth = 2.0
      ..color = const Color(0xFF1B1B1B);

    for (final legX in [-5.0, 1.0, 7.0]) {
      final legPath = Path()
        ..moveTo(legX, 10.0)
        ..lineTo(legX - 2.0, 14.5)
        ..lineTo(legX - 5.0, 17.5);
      canvas.drawPath(legPath, _stroke);
    }

    // 3. Plump Oval Body
    final bodyRect = Rect.fromCenter(center: Offset.zero, width: 32.0, height: 24.0);
    _fill.color = const Color(0xFFFFD600);
    canvas.drawOval(bodyRect, _fill);

    // 4. Bold Black Stripes (Curved within body contour)
    canvas.save();
    canvas.clipPath(Path()..addOval(bodyRect));
    _fill.color = const Color(0xFF1B1B1B);
    // Stripe 1 (rear)
    canvas.drawRect(const Rect.fromLTWH(-7.0, -14.0, 5.0, 28.0), _fill);
    // Stripe 2 (front)
    canvas.drawRect(const Rect.fromLTWH(2.0, -14.0, 5.0, 28.0), _fill);
    canvas.restore();

    // Body Outline
    _stroke
      ..strokeWidth = 2.2
      ..color = const Color(0xFF1B1B1B);
    canvas.drawOval(bodyRect, _stroke);

    // 5. Delicate Fluttering Wings on Back (Rapid vibration oscillation)
    final flap = bee.wingFlap; // -1.0 to 1.0
    final wingAngle1 = -0.32 + flap * 0.28;
    final wingAngle2 = -0.12 - flap * 0.25;

    // Rear Wing
    canvas.save();
    canvas.translate(-4.0, -10.0);
    canvas.rotate(wingAngle1);
    _fill.color = const Color(0xDDE2E8F0);
    _stroke
      ..strokeWidth = 1.4
      ..color = const Color(0xFF78909C);
    final wing1Rect = Rect.fromLTWH(-6.0, -14.0, 12.0, 14.0);
    canvas.drawOval(wing1Rect, _fill);
    canvas.drawOval(wing1Rect, _stroke);
    canvas.restore();

    // Front Wing
    canvas.save();
    canvas.translate(2.0, -10.0);
    canvas.rotate(wingAngle2);
    _fill.color = const Color(0xEEEDF2F7);
    final wing2Rect = Rect.fromLTWH(-6.0, -16.0, 13.0, 16.0);
    canvas.drawOval(wing2Rect, _fill);
    canvas.drawOval(wing2Rect, _stroke);
    canvas.restore();

    // 6. Cute Chibi Face (Dot Eyes with Catchlights & Curved Smile)
    _fill.color = const Color(0xFF1B1B1B);
    // Left eye
    canvas.drawCircle(const Offset(10.0, -2.5), 1.6, _fill);
    // Right eye
    canvas.drawCircle(const Offset(13.5, -2.0), 1.4, _fill);

    // Tiny white eye glint catchlights
    _fill.color = Colors.white;
    canvas.drawCircle(const Offset(9.6, -3.0), 0.6, _fill);
    canvas.drawCircle(const Offset(13.1, -2.5), 0.5, _fill);

    // Smiling curved mouth
    final smilePath = Path()
      ..moveTo(9.8, 1.8)
      ..quadraticBezierTo(11.8, 4.2, 13.8, 1.8);
    _stroke
      ..strokeWidth = 1.4
      ..color = const Color(0xFF1B1B1B);
    canvas.drawPath(smilePath, _stroke);

    // Rosy cheek
    _fill.color = const Color(0x55FF8A80);
    canvas.drawCircle(const Offset(11.5, 3.8), 2.2, _fill);

    canvas.restore();
  }

  void _drawWindshieldSplat(Canvas canvas, Size size) {
    final splat = c.activeSplat;
    if (splat == null || splat.isDead) return;

    _ensureSplatPaths();

    final alpha = splat.alpha;
    const pixelSize = 1.6;
    const cols = 26;
    const rows = 26;
    const splatWidth = cols * pixelSize;
    const splatHeight = rows * pixelSize;

    final left = splat.x - splatWidth / 2;
    final top = splat.y - splatHeight / 2;

    // 1. Wet glass smudge halo on the windshield (subtle, smaller)
    _fill
      ..style = PaintingStyle.fill
      ..maskFilter = null
      ..shader = null
      ..color = _ca(const Color(0x22CC1122), 0.10 * alpha);
    canvas.drawCircle(Offset(splat.x, splat.y), splatWidth * 0.32, _fill);

    // 2. Pixel Art Bug Splat (Matching Image 2 directly with batched paths)
    canvas.save();
    canvas.translate(left, top);

    _fill.color = _ca(const Color(0xFFCC1122), alpha);
    canvas.drawPath(_splatPath1, _fill);

    _fill.color = _ca(const Color(0xFF8E070D), alpha);
    canvas.drawPath(_splatPath2, _fill);

    _fill.color = _ca(const Color(0xFFFF2E3D), alpha);
    canvas.drawPath(_splatPath3, _fill);

    canvas.restore();

    // 3. Subtle glass smear reflection sheen across the splat
    _stroke
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..maskFilter = null
      ..strokeWidth = 1.3
      ..color = _ca(Colors.white, 0.35 * alpha);
    canvas.drawLine(
      Offset(splat.x - 14.0, splat.y - 12.0),
      Offset(splat.x + 8.0, splat.y + 10.0),
      _stroke,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}











