import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';

import '../engine/audio_manager.dart';

/// Centralized design tokens for the 75% 1.1 "Kozmik Kristal & Gözlemevi" +
/// 25% 1.3 "3D Kristal & Dövme Altın/Bevel" hybrid visual identity of Kırmataş.
abstract final class KaunosPalette {
  // ===========================================================================
  // 75% 1.1 KOZMİK KRİSTAL & GÖZLEMEVİ (OBSIDIAN CRYSTAL BASE)
  // ===========================================================================

  /// Deep obsidian base background (#05070F).
  static const Color obsidianBase = Color(0xFF05070F);

  /// 87% translucent deep smoke / obsidian crystal glass surface.
  static const Color obsidianGlassSurface = Color(0xDF070B18);

  /// 92% elevated translucent crystal card surface.
  static const Color obsidianGlassElevated = Color(0xEA0B1024);

  /// 95% modal and dialog crystal backdrop.
  static const Color obsidianGlassModal = Color(0xF2050711);

  /// Celestial starlight cyan crystal border (1.0px).
  static const Color crystalBorderStarlight = Color(0x5538BDF8);

  /// Cosmic nebula violet crystal border.
  static const Color crystalBorderViolet = Color(0x40A78BFA);

  /// Subtle muted crystal border.
  static const Color crystalBorderMuted = Color(0x2480D8FF);

  /// Top-edge micro-refraction specular highlight rim.
  static const Color crystalSpecularRim = Color(0x80FFFFFF);

  /// Physical 3D obsidian bottom bevel lip shadow.
  static const Color crystalBevelShadow = Color(0xFF020308);

  // ===========================================================================
  // 25% 1.3 3D KRİSTAL & DÖVME ALTIN/BEVEL (TACTILE ACCENTS & TRIGGERS)
  // ===========================================================================

  /// Pure specular glint for forged gold highlights.
  static const Color goldGlint = Color(0xFFFFF9E6);

  /// Upper face gradient highlight for forged gold.
  static const Color goldHighlight = Color(0xFFFDE68A);

  /// Primary forged gold face tone (#F59E0B / #F5B041).
  static const Color goldPrimary = Color(0xFFF59E0B);

  /// Lower face gradient shadow for forged gold.
  static const Color goldDeep = Color(0xFFD97706);

  /// Physical 5px 3D bottom bevel extruded lip (#451A03).
  static const Color goldBevelBottom = Color(0xFF451A03);

  /// Golden bezel outline / border (#FFD54F).
  static const Color goldBorder = Color(0xFFFFD54F);

  /// Ambient warm amber bloom glow.
  static const Color amberGlow = Color(0x40F59E0B);

  // ===========================================================================
  // MODE IDENTITY & SEMANTIC ACCENT TOKENS
  // ===========================================================================

  /// Classic Mode (Ana Macera) warm terracotta-amber top.
  static const Color classicSunsetTop = Color(0xFF96381B);

  /// Classic Mode warm terracotta-amber bottom.
  static const Color classicSunsetBottom = Color(0xFF5A1C0A);

  /// Classic Mode terracotta primary tone.
  static const Color terracottaPrimary = Color(0xFFC85A32);

  /// Classic Mode terracotta border tone.
  static const Color terracottaBorder = Color(0xFFF5B041);

  /// Chaos Mode (Özel Mod) deep abyssal jade top.
  static const Color chaosJadeTop = Color(0xFF133E47);

  /// Chaos Mode deep abyssal jade bottom.
  static const Color chaosJadeBottom = Color(0xFF0A2228);

  /// Chaos Mode jade glowing border tone.
  static const Color chaosJadeBorder = Color(0xFF2DD4BF);

  /// Deep sea jade primary tone.
  static const Color deepJadePrimary = Color(0xFF1E4D58);

  /// Deep sea jade border tone.
  static const Color deepJadeBorder = Color(0xFF48A9A6);

  /// Astral Pearl purple/magenta accent.
  static const Color pearlAstral = Color(0xFFE040FB);
}

// =============================================================================
// KAUNOS PANEL (DUAL-PASS OBSERVATORY CRYSTAL GLASS CONTAINER)
// =============================================================================

/// A high-performance translucent obsidian crystal glass container with dual-pass
/// custom painting, delicate 1.0px starlight border, specular top rim reflection,
/// observatory geometric corner brackets, and optional physical 3D bottom bevel.
class KaunosPanel extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final double borderRadius;
  final Color? backgroundColor;
  final Color borderColor;
  final bool showSpecularRim;
  final bool showCornerBrackets;
  final double bottomBevelDepth;
  final Color bevelColor;
  final double? width;
  final double? height;
  final EdgeInsetsGeometry? margin;
  final AlignmentGeometry? alignment;
  final Clip clipBehavior;

  const KaunosPanel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(14),
    this.borderRadius = 20,
    this.backgroundColor,
    this.borderColor = KaunosPalette.crystalBorderStarlight,
    this.showSpecularRim = true,
    this.showCornerBrackets = true,
    this.bottomBevelDepth = 0.0,
    this.bevelColor = KaunosPalette.crystalBevelShadow,
    this.width,
    this.height,
    this.margin,
    this.alignment,
    this.clipBehavior = Clip.none,
  });

  @override
  Widget build(BuildContext context) {
    Widget content = CustomPaint(
      painter: KaunosPanelPainter(
        borderRadius: borderRadius,
        backgroundColor: backgroundColor ?? KaunosPalette.obsidianGlassSurface,
        borderColor: borderColor,
        showSpecularRim: showSpecularRim,
        showCornerBrackets: showCornerBrackets,
        bottomBevelDepth: bottomBevelDepth,
        bevelColor: bevelColor,
      ),
      child: Padding(
        padding: padding,
        child: child,
      ),
    );

    if (clipBehavior != Clip.none) {
      content = ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        clipBehavior: clipBehavior,
        child: content,
      );
    }

    if (width != null || height != null || alignment != null || margin != null) {
      content = Container(
        width: width,
        height: height,
        margin: margin,
        alignment: alignment,
        child: content,
      );
    }

    return content;
  }
}

/// Dual-pass custom painter rendering the obsidian glass surface, starlight
/// border, specular rim refraction line, observatory brackets, and physical bevel.
class KaunosPanelPainter extends CustomPainter {
  final double borderRadius;
  final Color backgroundColor;
  final Color borderColor;
  final bool showSpecularRim;
  final bool showCornerBrackets;
  final double bottomBevelDepth;
  final Color bevelColor;

  const KaunosPanelPainter({
    required this.borderRadius,
    required this.backgroundColor,
    required this.borderColor,
    required this.showSpecularRim,
    required this.showCornerBrackets,
    required this.bottomBevelDepth,
    required this.bevelColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0 || size.height <= 0) return;

    final r = Radius.circular(borderRadius);
    final rect = Rect.fromLTWH(0, 0, size.width, size.height);
    final rrect = RRect.fromRectAndRadius(rect, r);

    // 1. Physical Bottom 3D Bevel Lip (Extruded bottom lip)
    if (bottomBevelDepth > 0) {
      final bevelRect = Rect.fromLTWH(0, bottomBevelDepth, size.width, size.height);
      final bevelRRect = RRect.fromRectAndRadius(bevelRect, r);
      canvas.drawRRect(bevelRRect, Paint()..color = bevelColor);
    }

    // 2. Translucent Obsidian Crystal Glass Surface
    final bgPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          backgroundColor,
          backgroundColor.withValues(alpha: (backgroundColor.a * 0.92).clamp(0.0, 1.0)),
          const Color(0xFB020408),
        ],
        stops: const [0.0, 0.6, 1.0],
      ).createShader(rect);
    canvas.drawRRect(rrect, bgPaint);

    // 3. Delicate Crystal Border (1.0px)
    final borderPaint = Paint()
      ..color = borderColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;
    canvas.drawRRect(rrect, borderPaint);

    // 4. Specular Top Rim (Micro-refraction Glint)
    if (showSpecularRim && size.width > (borderRadius * 2 + 12)) {
      final rimWidth = size.width - (borderRadius * 2);
      final rimPaint = Paint()
        ..shader = LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: const [
            Colors.transparent,
            KaunosPalette.crystalSpecularRim,
            KaunosPalette.crystalBorderStarlight,
            Colors.transparent,
          ],
          stops: const [0.05, 0.35, 0.65, 0.95],
        ).createShader(Rect.fromLTWH(borderRadius, 0, rimWidth, 1.5))
        ..strokeWidth = 1.2
        ..style = PaintingStyle.stroke;

      canvas.drawLine(
        Offset(borderRadius + 4, 1.0),
        Offset(size.width - borderRadius - 4, 1.0),
        rimPaint,
      );
    }

    // 5. Observatory Geometric Corner Brackets
    if (showCornerBrackets && size.width >= 48 && size.height >= 48) {
      final bracketPaint = Paint()
        ..color = borderColor.withValues(alpha: 0.75)
        ..strokeWidth = 1.4
        ..style = PaintingStyle.stroke;
      const bLen = 6.0;
      const bInset = 4.0;

      // Top-Left bracket
      canvas.drawLine(
        const Offset(bInset, bInset + bLen),
        const Offset(bInset, bInset),
        bracketPaint,
      );
      canvas.drawLine(
        const Offset(bInset, bInset),
        const Offset(bInset + bLen, bInset),
        bracketPaint,
      );

      // Top-Right bracket
      canvas.drawLine(
        Offset(size.width - bInset, bInset + bLen),
        Offset(size.width - bInset, bInset),
        bracketPaint,
      );
      canvas.drawLine(
        Offset(size.width - bInset, bInset),
        Offset(size.width - bInset - bLen, bInset),
        bracketPaint,
      );

      // Bottom-Left bracket
      canvas.drawLine(
        Offset(bInset, size.height - bInset - bLen),
        Offset(bInset, size.height - bInset),
        bracketPaint,
      );
      canvas.drawLine(
        Offset(bInset, size.height - bInset),
        Offset(bInset + bLen, size.height - bInset),
        bracketPaint,
      );

      // Bottom-Right bracket
      canvas.drawLine(
        Offset(size.width - bInset, size.height - bInset - bLen),
        Offset(size.width - bInset, size.height - bInset),
        bracketPaint,
      );
      canvas.drawLine(
        Offset(size.width - bInset, size.height - bInset),
        Offset(size.width - bInset - bLen, size.height - bInset),
        bracketPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant KaunosPanelPainter oldDelegate) =>
      oldDelegate.borderRadius != borderRadius ||
      oldDelegate.backgroundColor != backgroundColor ||
      oldDelegate.borderColor != borderColor ||
      oldDelegate.showSpecularRim != showSpecularRim ||
      oldDelegate.showCornerBrackets != showCornerBrackets ||
      oldDelegate.bottomBevelDepth != bottomBevelDepth ||
      oldDelegate.bevelColor != bevelColor;
}

/// Convenience card widget specialized from [KaunosPanel] with elevated surface
/// and default 3D bottom bevel lip depth.
class KaunosCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final double borderRadius;
  final Color? backgroundColor;
  final Color borderColor;
  final double bottomBevelDepth;
  final Color bevelColor;
  final double? width;
  final double? height;
  final EdgeInsetsGeometry? margin;
  final bool showSpecularRim;
  final bool showCornerBrackets;

  const KaunosCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(14),
    this.borderRadius = 18,
    this.backgroundColor,
    this.borderColor = KaunosPalette.crystalBorderStarlight,
    this.bottomBevelDepth = 4.0,
    this.bevelColor = KaunosPalette.crystalBevelShadow,
    this.width,
    this.height,
    this.margin,
    this.showSpecularRim = true,
    this.showCornerBrackets = false,
  });

  @override
  Widget build(BuildContext context) {
    return KaunosPanel(
      padding: padding,
      borderRadius: borderRadius,
      backgroundColor: backgroundColor ?? KaunosPalette.obsidianGlassElevated,
      borderColor: borderColor,
      bottomBevelDepth: bottomBevelDepth,
      bevelColor: bevelColor,
      width: width,
      height: height,
      margin: margin,
      showSpecularRim: showSpecularRim,
      showCornerBrackets: showCornerBrackets,
      child: child,
    );
  }
}

// =============================================================================
// KAUNOS JUICY FEEDBACK (PARTICLES, NEON WAVES, PERSPECTIVE & KINETICS)
// =============================================================================

/// Individual spark particle for celebratory button release showers.
class _KaunosSparkParticle {
  final double angle;
  final double distance;
  final double size;
  final Color color;
  final double speedMultiplier;

  _KaunosSparkParticle({
    required this.angle,
    required this.distance,
    required this.size,
    required this.color,
    required this.speedMultiplier,
  });
}

/// CustomPainter that renders:
/// 1. Expanding neon perimeter shockwave ring along the exact button outline
/// 2. Glowing radial particle burst shower
/// 3. High-stakes radial energy meter aura
class _KaunosJuicyOverlayPainter extends CustomPainter {
  final double waveProgress;
  final double particleProgress;
  final List<_KaunosSparkParticle> particles;
  final Color waveColor;
  final double borderRadius;
  final bool isCircle;
  final bool isHighStakes;

  _KaunosJuicyOverlayPainter({
    required this.waveProgress,
    required this.particleProgress,
    required this.particles,
    required this.waveColor,
    required this.borderRadius,
    this.isCircle = false,
    this.isHighStakes = false,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0 || size.height <= 0) return;

    // 1. Layer 3: Expanding Neon Perimeter Wave
    if (waveProgress > 0.0 && waveProgress < 1.0) {
      final waveAlpha = ((1.0 - waveProgress) * 0.95).clamp(0.0, 1.0);
      final expand = waveProgress * (isHighStakes ? 26.0 : 18.0);
      final strokeW = (2.6 * (1.0 - waveProgress) + 0.6).clamp(0.6, 3.2);

      final wavePaint = Paint()
        ..color = waveColor.withValues(alpha: waveAlpha)
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeW
        ..maskFilter = MaskFilter.blur(BlurStyle.solid, 2.5 + (1.0 - waveProgress) * 3.5);

      final rect = Rect.fromLTWH(-expand, -expand, size.width + expand * 2, size.height + expand * 2);
      if (isCircle) {
        canvas.drawOval(rect, wavePaint);
      } else {
        final r = Radius.circular(borderRadius + expand * 0.45);
        canvas.drawRRect(RRect.fromRectAndRadius(rect, r), wavePaint);
      }
    }

    // 2. Layer 5: Glowing Particle Burst Shower Outward
    if (particleProgress > 0.0 && particleProgress < 1.0 && particles.isNotEmpty) {
      final particleAlpha = ((1.0 - particleProgress) * 1.0).clamp(0.0, 1.0);
      final center = Offset(size.width / 2, size.height / 2);
      final halfW = size.width / 2;
      final halfH = size.height / 2;

      for (final p in particles) {
        final curvedT = Curves.easeOutCubic.transform(particleProgress);
        final currentDist = p.distance * curvedT * p.speedMultiplier;

        final cosA = math.cos(p.angle);
        final sinA = math.sin(p.angle);

        final basePerimeterDist = isCircle
            ? halfW
            : math.min(
                (halfW / (cosA.abs() > 0.001 ? cosA.abs() : 1.0)),
                (halfH / (sinA.abs() > 0.001 ? sinA.abs() : 1.0)),
              );

        final posX = center.dx + cosA * (basePerimeterDist + currentDist);
        final posY = center.dy + sinA * (basePerimeterDist + currentDist);

        final currentSize = (p.size * (1.0 - particleProgress * 0.6)).clamp(0.8, 6.0);
        final sparkPaint = Paint()
          ..color = p.color.withValues(alpha: particleAlpha)
          ..style = PaintingStyle.fill
          ..maskFilter = const MaskFilter.blur(BlurStyle.solid, 1.5);

        canvas.drawCircle(Offset(posX, posY), currentSize, sparkPaint);

        // Bright specular core glint
        final corePaint = Paint()
          ..color = Colors.white.withValues(alpha: particleAlpha * 0.95)
          ..style = PaintingStyle.fill;
        canvas.drawCircle(Offset(posX, posY), currentSize * 0.4, corePaint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _KaunosJuicyOverlayPainter oldDelegate) =>
      oldDelegate.waveProgress != waveProgress ||
      oldDelegate.particleProgress != particleProgress ||
      oldDelegate.waveColor != waveColor;
}

/// Universal 6-layer juicy interactive wrapper that endows any widget with:
/// 1. 3D perspective hover & touch tilt
/// 2. Physical compression + elastic snap-back
/// 3. Perimeter expanding neon shockwave
/// 4. Dual tactile pop on press & warm rewarding chime on release
/// 5. Radial glowing particle burst shower
/// 6. High-stakes kinetic shake & radial energy
class KaunosJuicyInteractive extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final double borderRadius;
  final bool isCircle;
  final Color waveColor;
  final bool isHighStakes;
  final bool enabled;

  const KaunosJuicyInteractive({
    super.key,
    required this.child,
    this.onTap,
    this.onLongPress,
    this.borderRadius = 16.0,
    this.isCircle = false,
    this.waveColor = KaunosPalette.goldHighlight,
    this.isHighStakes = false,
    this.enabled = true,
  });

  @override
  State<KaunosJuicyInteractive> createState() => _KaunosJuicyInteractiveState();
}

class _KaunosJuicyInteractiveState extends State<KaunosJuicyInteractive> with TickerProviderStateMixin {
  bool _isPressed = false;
  Offset _pointerPos = Offset.zero;

  late final AnimationController _elasticController;
  late final Animation<double> _elasticAnimation;

  late final AnimationController _waveController;
  late final Animation<double> _waveAnimation;

  late final AnimationController _particleController;
  late final Animation<double> _particleAnimation;

  late final AnimationController _shakeController;
  late final Animation<double> _shakeAnimation;

  List<_KaunosSparkParticle> _particles = [];
  final math.Random _random = math.Random();

  bool get _isClickable => widget.enabled && widget.onTap != null;

  @override
  void initState() {
    super.initState();
    _elasticController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 380),
    );
    _elasticAnimation = CurvedAnimation(
      parent: _elasticController,
      curve: Curves.elasticOut,
    );

    _waveController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 460),
    );
    _waveAnimation = CurvedAnimation(
      parent: _waveController,
      curve: Curves.easeOutQuad,
    );

    _particleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 420),
    );
    _particleAnimation = CurvedAnimation(
      parent: _particleController,
      curve: Curves.easeOutCubic,
    );

    _shakeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 180),
    );
    _shakeAnimation = CurvedAnimation(
      parent: _shakeController,
      curve: Curves.linear,
    );
  }

  @override
  void dispose() {
    _elasticController.dispose();
    _waveController.dispose();
    _particleController.dispose();
    _shakeController.dispose();
    super.dispose();
  }

  void _generateParticles() {
    final count = widget.isHighStakes ? 22 : 14;
    final particles = <_KaunosSparkParticle>[];
    for (int i = 0; i < count; i++) {
      final angle = (i * (2 * math.pi / count)) + (_random.nextDouble() * 0.4 - 0.2);
      final distance = 16.0 + _random.nextDouble() * (widget.isHighStakes ? 32.0 : 20.0);
      final size = 1.8 + _random.nextDouble() * (widget.isHighStakes ? 2.8 : 2.0);
      final colors = [
        widget.waveColor,
        KaunosPalette.goldGlint,
        KaunosPalette.goldHighlight,
        Colors.white,
      ];
      particles.add(_KaunosSparkParticle(
        angle: angle,
        distance: distance,
        size: size,
        color: colors[_random.nextInt(colors.length)],
        speedMultiplier: 0.85 + _random.nextDouble() * 0.45,
      ));
    }
    _particles = particles;
  }

  void _handleTapDown(Offset localPos) {
    if (!_isClickable) return;
    setState(() {
      _isPressed = true;
      _pointerPos = localPos;
    });
    // Layer 4: Snappy tactile pop on press
    HapticFeedback.lightImpact();
  }

  void _handleTapUp(Offset localPos) {
    if (_isPressed) {
      setState(() {
        _isPressed = false;
        _pointerPos = localPos;
      });

      // Layer 2: Elastic snap back on release
      _elasticController.forward(from: 0.0);

      // Layer 3: Perimeter expanding neon wave
      _waveController.forward(from: 0.0);

      // Layer 5: Particle burst shower
      _generateParticles();
      _particleController.forward(from: 0.0);

      // Layer 6: High-stakes kinetic screen shake
      if (widget.isHighStakes) {
        _shakeController.forward(from: 0.0);
        HapticFeedback.heavyImpact();
        AudioManager.instance.playSfx(GameSfx.ulti, playbackRate: 1.25);
      } else {
        // Layer 4: Warm rewarding chime on release
        HapticFeedback.mediumImpact();
        AudioManager.instance.playSfx(GameSfx.click);
        AudioManager.instance.playSfx(GameSfx.powerupBuff, playbackRate: 1.35);
      }

      widget.onTap?.call();
    }
  }

  void _handleTapCancel() {
    if (_isPressed) {
      setState(() => _isPressed = false);
    }
  }

  Matrix4 _buildPerspectiveMatrix(Size size) {
    final matrix = Matrix4.identity();
    if (size.width <= 0 || size.height <= 0) return matrix;

    matrix.setEntry(3, 2, 0.0016);
    final nx = ((_pointerPos.dx / size.width) * 2.0 - 1.0).clamp(-1.0, 1.0);
    final ny = ((_pointerPos.dy / size.height) * 2.0 - 1.0).clamp(-1.0, 1.0);

    final tiltFactor = _isPressed ? 1.0 : 0.0;
    matrix.rotateX(-ny * 0.12 * tiltFactor);
    matrix.rotateY(nx * 0.12 * tiltFactor);
    return matrix;
  }

  double _computeScale() {
    if (_isPressed) return 0.94;
    if (_elasticController.isAnimating) {
      return 0.94 + 0.06 * _elasticAnimation.value;
    }
    return 1.0;
  }

  Offset _computeShakeOffset() {
    if (!widget.isHighStakes || !_shakeController.isAnimating) {
      return Offset.zero;
    }
    final t = _shakeAnimation.value;
    final intensity = (1.0 - t) * 3.5;
    final dx = math.sin(t * math.pi * 8.0) * intensity;
    final dy = math.cos(t * math.pi * 6.0) * (intensity * 0.5);
    return Offset(dx, dy);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return GestureDetector(
          onTapDown: (d) => _handleTapDown(d.localPosition),
          onTapUp: (d) => _handleTapUp(d.localPosition),
          onTapCancel: _handleTapCancel,
          onLongPress: _isClickable ? widget.onLongPress : null,
          behavior: HitTestBehavior.opaque,
          child: AnimatedBuilder(
            animation: Listenable.merge([
              _elasticController,
              _waveController,
              _particleController,
              _shakeController,
            ]),
            builder: (context, child) {
              final scale = _computeScale();
              final shakeOffset = _computeShakeOffset();

              return Transform.translate(
                offset: shakeOffset,
                child: CustomPaint(
                  foregroundPainter: _KaunosJuicyOverlayPainter(
                    waveProgress: _waveAnimation.value,
                    particleProgress: _particleAnimation.value,
                    particles: _particles,
                    waveColor: widget.waveColor,
                    borderRadius: widget.borderRadius,
                    isCircle: widget.isCircle,
                    isHighStakes: widget.isHighStakes,
                  ),
                  child: Transform(
                    transform: _buildPerspectiveMatrix(constraints.biggest)
                      ..multiply(Matrix4.diagonal3Values(scale, scale, 1.0)),
                    alignment: Alignment.center,
                    child: widget.child,
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }
}

/// Hafif, jest-yarışına girmeyen basma efekti: mevcut butonları (IconButton,
/// ElevatedButton, TextButton...) sarmak için tasarlandı. Listener ile basıncı
/// izler; çocuk kendi onTap'ini çalıştırmaya devam ederken ölçek ezilmesi +
/// bırakışta neon dalga ve kıvılcım patlaması verir.
class KaunosPressGlow extends StatefulWidget {
  final Widget child;
  final double borderRadius;
  final bool isCircle;
  final Color waveColor;
  final double pressedScale;

  const KaunosPressGlow({
    super.key,
    required this.child,
    this.borderRadius = 14.0,
    this.isCircle = false,
    this.waveColor = KaunosPalette.goldHighlight,
    this.pressedScale = 0.93,
  });

  @override
  State<KaunosPressGlow> createState() => _KaunosPressGlowState();
}

class _KaunosPressGlowState extends State<KaunosPressGlow> with SingleTickerProviderStateMixin {
  bool _pressed = false;
  late final AnimationController _burst;
  List<_KaunosSparkParticle> _particles = const [];
  final math.Random _random = math.Random();

  @override
  void initState() {
    super.initState();
    _burst = AnimationController(vsync: this, duration: const Duration(milliseconds: 420));
  }

  @override
  void dispose() {
    _burst.dispose();
    super.dispose();
  }

  void _spawnParticles() {
    const count = 12;
    _particles = List.generate(count, (i) {
      final angle = (i * (2 * math.pi / count)) + (_random.nextDouble() * 0.4 - 0.2);
      return _KaunosSparkParticle(
        angle: angle,
        distance: 14.0 + _random.nextDouble() * 18.0,
        size: 1.8 + _random.nextDouble() * 2.0,
        color: [widget.waveColor, KaunosPalette.goldGlint, Colors.white][_random.nextInt(3)],
        speedMultiplier: 0.85 + _random.nextDouble() * 0.45,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerDown: (_) {
        if (!_pressed) {
          setState(() => _pressed = true);
          HapticFeedback.lightImpact();
        }
      },
      onPointerUp: (_) {
        if (_pressed) {
          setState(() => _pressed = false);
          _spawnParticles();
          _burst.forward(from: 0.0);
        }
      },
      onPointerCancel: (_) {
        if (_pressed) setState(() => _pressed = false);
      },
      child: AnimatedScale(
        scale: _pressed ? widget.pressedScale : 1.0,
        duration: const Duration(milliseconds: 90),
        curve: Curves.easeOut,
        child: AnimatedBuilder(
          animation: _burst,
          builder: (context, child) => CustomPaint(
            foregroundPainter: _KaunosJuicyOverlayPainter(
              waveProgress: _burst.value,
              particleProgress: _burst.value,
              particles: _particles,
              waveColor: widget.waveColor,
              borderRadius: widget.borderRadius,
              isCircle: widget.isCircle,
            ),
            child: child,
          ),
          child: widget.child,
        ),
      ),
    );
  }
}

/// Animasyonlu sayı sayacı: değer değiştiğinde aradaki sayıları tek tek,
/// hızla sayarak ilerler (kazanınca yukarı, harcayınca aşağı). Küçük
/// farklarda her tam sayı görünür; büyük sıçramalar ~0.55 sn'de tamamlanır.
class RollingNumberText extends StatefulWidget {
  final int value;
  final TextStyle? style;
  final String Function(int value)? format;

  const RollingNumberText({
    super.key,
    required this.value,
    this.style,
    this.format,
  });

  @override
  State<RollingNumberText> createState() => _RollingNumberTextState();
}

class _RollingNumberTextState extends State<RollingNumberText> with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  double _shown = 0;
  int _target = 0;
  Duration _lastElapsed = Duration.zero;

  @override
  void initState() {
    super.initState();
    _shown = widget.value.toDouble();
    _target = widget.value;
    _ticker = createTicker(_onTick);
  }

  @override
  void didUpdateWidget(covariant RollingNumberText oldWidget) {
    super.didUpdateWidget(oldWidget);
    _target = widget.value;
    if (_target != _shown.round() && !_ticker.isActive) {
      _lastElapsed = Duration.zero;
      _ticker.start();
    }
  }

  void _onTick(Duration elapsed) {
    final dt = _lastElapsed == Duration.zero
        ? 0.016
        : (elapsed - _lastElapsed).inMicroseconds / 1000000.0;
    _lastElapsed = elapsed;
    final diff = _target - _shown;
    if (diff == 0) {
      _ticker.stop();
      return;
    }
    final speed = math.max(80.0, diff.abs() / 0.55);
    final step = speed * math.min(dt, 0.05);
    setState(() {
      if (diff.abs() <= step) {
        _shown = _target.toDouble();
      } else {
        _shown += step * diff.sign;
      }
    });
    if (_shown == _target.toDouble()) {
      _ticker.stop();
    }
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final v = _shown.round();
    return Text(
      widget.format?.call(v) ?? '$v',
      style: widget.style,
    );
  }
}

// =============================================================================
// KAUNOS TACTILE BUTTON (3D PHYSICAL BEVEL & PRESS DEPRESSION)
// =============================================================================

/// Universal 3D tactile button featuring:
/// 1. Subtle 3D perspective tilt following pointer position & smooth scale
/// 2. Mechanical downward compression + elastic spring snap-back
/// 3. Expanding perimeter neon wave on trigger
/// 4. Snappy tactile pop on press & warm rewarding chime on release
/// 5. Radial particle burst shower of glowing energy sparks
/// 6. Optional high-stakes radial energy meter & kinetic screen shake
class KaunosTactileButton extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final double height;
  final double? width;
  final List<Color> gradientColors;
  final Color bevelColor;
  final Color borderColor;
  final double bevelDepth;
  final double borderRadius;
  final EdgeInsetsGeometry padding;
  final bool enabled;

  // Juicy enhancements
  final bool enableTilt;
  final bool enableElasticSnap;
  final bool enableNeonWave;
  final bool enableParticles;
  final bool isHighStakes;
  final Color? waveColor;
  final double maxTiltAngle;

  const KaunosTactileButton({
    super.key,
    required this.child,
    this.onTap,
    this.onLongPress,
    this.height = 46,
    this.width,
    this.gradientColors = const [
      KaunosPalette.goldHighlight,
      KaunosPalette.goldPrimary,
      KaunosPalette.goldDeep,
    ],
    this.bevelColor = KaunosPalette.goldBevelBottom,
    this.borderColor = KaunosPalette.goldBorder,
    this.bevelDepth = 5.0,
    this.borderRadius = 14,
    this.padding = const EdgeInsets.symmetric(horizontal: 14),
    this.enabled = true,
    this.enableTilt = true,
    this.enableElasticSnap = true,
    this.enableNeonWave = true,
    this.enableParticles = true,
    this.isHighStakes = false,
    this.waveColor,
    this.maxTiltAngle = 0.10,
  });

  /// Factory for 1.3 Forged Gold tactile button.
  factory KaunosTactileButton.gold({
    Key? key,
    required Widget child,
    VoidCallback? onTap,
    VoidCallback? onLongPress,
    double height = 46,
    double? width,
    double bevelDepth = 5.0,
    double borderRadius = 14,
    EdgeInsetsGeometry padding = const EdgeInsets.symmetric(horizontal: 14),
    bool enabled = true,
    bool isHighStakes = false,
  }) {
    return KaunosTactileButton(
      key: key,
      onTap: onTap,
      onLongPress: onLongPress,
      height: height,
      width: width,
      gradientColors: const [
        KaunosPalette.goldHighlight,
        KaunosPalette.goldPrimary,
        KaunosPalette.goldDeep,
      ],
      bevelColor: KaunosPalette.goldBevelBottom,
      borderColor: KaunosPalette.goldBorder,
      bevelDepth: bevelDepth,
      borderRadius: borderRadius,
      padding: padding,
      enabled: enabled,
      isHighStakes: isHighStakes,
      waveColor: KaunosPalette.goldHighlight,
      child: child,
    );
  }

  /// Factory for high-stakes decisive action buttons with extra juicy kinetics,
  /// screen shake, and massive spark shower.
  factory KaunosTactileButton.highStakes({
    Key? key,
    required Widget child,
    VoidCallback? onTap,
    VoidCallback? onLongPress,
    double height = 52,
    double? width,
    double bevelDepth = 6.0,
    double borderRadius = 16,
    EdgeInsetsGeometry padding = const EdgeInsets.symmetric(horizontal: 18),
    bool enabled = true,
  }) {
    return KaunosTactileButton(
      key: key,
      onTap: onTap,
      onLongPress: onLongPress,
      height: height,
      width: width,
      gradientColors: const [
        Color(0xFFFFFBEB),
        KaunosPalette.goldHighlight,
        KaunosPalette.goldPrimary,
        KaunosPalette.goldDeep,
      ],
      bevelColor: const Color(0xFF381202),
      borderColor: const Color(0xFFFFF9E6),
      bevelDepth: bevelDepth,
      borderRadius: borderRadius,
      padding: padding,
      enabled: enabled,
      isHighStakes: true,
      waveColor: const Color(0xFFFFF59D),
      maxTiltAngle: 0.14,
      child: child,
    );
  }

  /// Factory for Classic Mode (Ana Macera) warm terracotta-amber tactile button.
  factory KaunosTactileButton.sunset({
    Key? key,
    required Widget child,
    VoidCallback? onTap,
    VoidCallback? onLongPress,
    double height = 46,
    double? width,
    double bevelDepth = 5.0,
    double borderRadius = 14,
    EdgeInsetsGeometry padding = const EdgeInsets.symmetric(horizontal: 14),
    bool enabled = true,
    bool isHighStakes = false,
  }) {
    return KaunosTactileButton(
      key: key,
      onTap: onTap,
      onLongPress: onLongPress,
      height: height,
      width: width,
      gradientColors: const [
        Color(0xFFD97706),
        Color(0xFFC85A32),
        Color(0xFF96381B),
      ],
      bevelColor: const Color(0xFF4A1808),
      borderColor: const Color(0xFFF5B041),
      bevelDepth: bevelDepth,
      borderRadius: borderRadius,
      padding: padding,
      enabled: enabled,
      isHighStakes: isHighStakes,
      waveColor: const Color(0xFFF59E0B),
      child: child,
    );
  }

  /// Factory for Chaos Mode (Özel Mod) deep abyssal jade tactile button.
  factory KaunosTactileButton.jade({
    Key? key,
    required Widget child,
    VoidCallback? onTap,
    VoidCallback? onLongPress,
    double height = 46,
    double? width,
    double bevelDepth = 5.0,
    double borderRadius = 14,
    EdgeInsetsGeometry padding = const EdgeInsets.symmetric(horizontal: 14),
    bool enabled = true,
    bool isHighStakes = false,
  }) {
    return KaunosTactileButton(
      key: key,
      onTap: onTap,
      onLongPress: onLongPress,
      height: height,
      width: width,
      gradientColors: const [
        Color(0xFF2DD4BF),
        Color(0xFF1E4D58),
        Color(0xFF13333B),
      ],
      bevelColor: const Color(0xFF091C20),
      borderColor: const Color(0xFF48A9A6),
      bevelDepth: bevelDepth,
      borderRadius: borderRadius,
      padding: padding,
      enabled: enabled,
      isHighStakes: isHighStakes,
      waveColor: const Color(0xFF2DD4BF),
      child: child,
    );
  }

  /// Factory for dark obsidian crystal tactile button.
  factory KaunosTactileButton.obsidian({
    Key? key,
    required Widget child,
    VoidCallback? onTap,
    VoidCallback? onLongPress,
    double height = 46,
    double? width,
    double bevelDepth = 4.0,
    double borderRadius = 14,
    EdgeInsetsGeometry padding = const EdgeInsets.symmetric(horizontal: 14),
    bool enabled = true,
    bool isHighStakes = false,
  }) {
    return KaunosTactileButton(
      key: key,
      onTap: onTap,
      onLongPress: onLongPress,
      height: height,
      width: width,
      gradientColors: const [
        Color(0xFF1E2640),
        Color(0xFF0F1424),
        Color(0xFF070B18),
      ],
      bevelColor: const Color(0xFF020308),
      borderColor: KaunosPalette.crystalBorderStarlight,
      bevelDepth: bevelDepth,
      borderRadius: borderRadius,
      padding: padding,
      enabled: enabled,
      isHighStakes: isHighStakes,
      waveColor: KaunosPalette.crystalBorderStarlight,
      child: child,
    );
  }

  @override
  State<KaunosTactileButton> createState() => _KaunosTactileButtonState();
}

class _KaunosTactileButtonState extends State<KaunosTactileButton> with TickerProviderStateMixin {
  bool _isPressed = false;
  Offset _pointerPos = Offset.zero;

  late final AnimationController _elasticController;
  late final Animation<double> _elasticAnimation;

  late final AnimationController _waveController;
  late final Animation<double> _waveAnimation;

  late final AnimationController _particleController;
  late final Animation<double> _particleAnimation;

  late final AnimationController _shakeController;
  late final Animation<double> _shakeAnimation;

  List<_KaunosSparkParticle> _particles = [];
  final math.Random _random = math.Random();

  bool get _isClickable => widget.enabled && widget.onTap != null;

  @override
  void initState() {
    super.initState();
    _elasticController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 380),
    );
    _elasticAnimation = CurvedAnimation(
      parent: _elasticController,
      curve: Curves.elasticOut,
    );

    _waveController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 460),
    );
    _waveAnimation = CurvedAnimation(
      parent: _waveController,
      curve: Curves.easeOutQuad,
    );

    _particleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 420),
    );
    _particleAnimation = CurvedAnimation(
      parent: _particleController,
      curve: Curves.easeOutCubic,
    );

    _shakeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 180),
    );
    _shakeAnimation = CurvedAnimation(
      parent: _shakeController,
      curve: Curves.linear,
    );
  }

  @override
  void dispose() {
    _elasticController.dispose();
    _waveController.dispose();
    _particleController.dispose();
    _shakeController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant KaunosTactileButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.enabled || widget.onTap == null) {
      _isPressed = false;
    }
  }

  void _generateParticles() {
    final count = widget.isHighStakes ? 22 : 14;
    final particles = <_KaunosSparkParticle>[];
    final baseColor = widget.waveColor ?? widget.borderColor;

    for (int i = 0; i < count; i++) {
      final angle = (i * (2 * math.pi / count)) + (_random.nextDouble() * 0.4 - 0.2);
      final distance = 16.0 + _random.nextDouble() * (widget.isHighStakes ? 34.0 : 22.0);
      final size = 1.8 + _random.nextDouble() * (widget.isHighStakes ? 3.0 : 2.2);
      final colors = [
        baseColor,
        KaunosPalette.goldGlint,
        KaunosPalette.goldHighlight,
        Colors.white,
      ];
      particles.add(_KaunosSparkParticle(
        angle: angle,
        distance: distance,
        size: size,
        color: colors[_random.nextInt(colors.length)],
        speedMultiplier: 0.85 + _random.nextDouble() * 0.45,
      ));
    }
    _particles = particles;
  }

  void _handleTapDown(TapDownDetails details) {
    if (!_isClickable) return;
    setState(() {
      _isPressed = true;
      _pointerPos = details.localPosition;
    });
    // Layer 4: Snappy tactile pop on press
    HapticFeedback.lightImpact();
  }

  void _handleTapUp(TapUpDetails details) {
    if (_isPressed) {
      setState(() {
        _isPressed = false;
        _pointerPos = details.localPosition;
      });

      // Layer 2: Elastic spring snap-back on release
      if (widget.enableElasticSnap) {
        _elasticController.forward(from: 0.0);
      }

      // Layer 3: Perimeter expanding neon wave
      if (widget.enableNeonWave) {
        _waveController.forward(from: 0.0);
      }

      // Layer 5: Glowing particle burst shower
      if (widget.enableParticles) {
        _generateParticles();
        _particleController.forward(from: 0.0);
      }

      // Layer 6: High-stakes kinetic screen shake & sound
      if (widget.isHighStakes) {
        _shakeController.forward(from: 0.0);
        HapticFeedback.heavyImpact();
        AudioManager.instance.playSfx(GameSfx.ulti, playbackRate: 1.25);
      } else {
        // Layer 4: Warm rewarding chime on release
        HapticFeedback.mediumImpact();
        AudioManager.instance.playSfx(GameSfx.click);
        AudioManager.instance.playSfx(GameSfx.powerupBuff, playbackRate: 1.35);
      }

      widget.onTap?.call();
    }
  }

  void _handleTapCancel() {
    if (_isPressed) {
      setState(() => _isPressed = false);
    }
  }

  Matrix4 _buildPerspectiveMatrix(Size size) {
    final matrix = Matrix4.identity();
    if (!widget.enableTilt || size.width <= 0 || size.height <= 0) {
      return matrix;
    }

    matrix.setEntry(3, 2, 0.0016);
    final nx = ((_pointerPos.dx / size.width) * 2.0 - 1.0).clamp(-1.0, 1.0);
    final ny = ((_pointerPos.dy / size.height) * 2.0 - 1.0).clamp(-1.0, 1.0);

    final tiltFactor = _isPressed ? 1.0 : 0.0;
    matrix.rotateX(-ny * widget.maxTiltAngle * tiltFactor);
    matrix.rotateY(nx * widget.maxTiltAngle * tiltFactor);
    return matrix;
  }

  double _computeScale() {
    if (!widget.enableElasticSnap) {
      return _isPressed ? 0.94 : 1.0;
    }
    if (_isPressed) {
      return 0.94;
    }
    if (_elasticController.isAnimating) {
      return 0.94 + 0.06 * _elasticAnimation.value;
    }
    return 1.0;
  }

  Offset _computeShakeOffset() {
    if (!widget.isHighStakes || !_shakeController.isAnimating) {
      return Offset.zero;
    }
    final t = _shakeAnimation.value;
    final intensity = (1.0 - t) * 3.5;
    final dx = math.sin(t * math.pi * 8.0) * intensity;
    final dy = math.cos(t * math.pi * 6.0) * (intensity * 0.5);
    return Offset(dx, dy);
  }

  @override
  Widget build(BuildContext context) {
    final depth = _isClickable ? widget.bevelDepth : 2.0;
    final currentOffset = _isPressed ? (depth - 1.0).clamp(0.0, depth) : 0.0;
    final currentBevel = _isPressed ? 1.0 : depth;

    return LayoutBuilder(
      builder: (context, constraints) {
        final hasBoundedWidth = constraints.maxWidth.isFinite;
        final resolvedWidth = widget.width ?? (hasBoundedWidth ? constraints.maxWidth : null);

        return GestureDetector(
          onTapDown: _handleTapDown,
          onTapUp: _handleTapUp,
          onTapCancel: _handleTapCancel,
          onLongPress: _isClickable ? widget.onLongPress : null,
          behavior: HitTestBehavior.opaque,
          child: AnimatedBuilder(
            animation: Listenable.merge([
              _elasticController,
              _waveController,
              _particleController,
              _shakeController,
            ]),
            builder: (context, child) {
              final scale = _computeScale();
              final shakeOffset = _computeShakeOffset();
              final totalSize = Size(resolvedWidth ?? 120.0, widget.height + depth);

              return Transform.translate(
                offset: shakeOffset,
                child: CustomPaint(
                  foregroundPainter: _KaunosJuicyOverlayPainter(
                    waveProgress: _waveAnimation.value,
                    particleProgress: _particleAnimation.value,
                    particles: _particles,
                    waveColor: widget.waveColor ?? widget.borderColor,
                    borderRadius: widget.borderRadius,
                    isCircle: false,
                    isHighStakes: widget.isHighStakes,
                  ),
                  child: Transform(
                    transform: _buildPerspectiveMatrix(totalSize)
                      ..multiply(Matrix4.diagonal3Values(scale, scale, 1.0)),
                    alignment: Alignment.center,
                    child: SizedBox(
                      width: resolvedWidth,
                      height: widget.height + depth,
                      child: Stack(
                        clipBehavior: Clip.none,
                        children: [
                          // 1. Static Bottom Physical Bevel Lip (Zero-blur Bevel Shadow)
                          Positioned(
                            left: 0,
                            right: 0,
                            top: currentBevel,
                            bottom: 0,
                            child: Container(
                              decoration: BoxDecoration(
                                color: _isClickable ? widget.bevelColor : const Color(0xFF1A1D24),
                                borderRadius: BorderRadius.circular(widget.borderRadius),
                              ),
                            ),
                          ),

                          // 2. Depressing Button Face (Compress Down on Press)
                          Padding(
                            padding: EdgeInsets.only(top: currentOffset, bottom: depth - currentOffset),
                            child: Container(
                              width: resolvedWidth,
                              height: widget.height,
                              padding: widget.padding,
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                  colors: _isClickable
                                      ? widget.gradientColors
                                      : const [Color(0x33FFFFFF), Color(0x1AFFFFFF)],
                                ),
                                borderRadius: BorderRadius.circular(widget.borderRadius),
                                border: Border.all(
                                  color: _isClickable ? widget.borderColor : const Color(0x33FFFFFF),
                                  width: 1.2,
                                ),
                                boxShadow: [
                                  // Top inner specular rim glint
                                  BoxShadow(
                                    color: Colors.white.withValues(alpha: _isClickable ? 0.35 : 0.1),
                                    offset: const Offset(0, 1.2),
                                    blurRadius: 0,
                                    spreadRadius: 0,
                                  ),
                                  // High stakes ambient bloom
                                  if (widget.isHighStakes)
                                    BoxShadow(
                                      color: (widget.waveColor ?? KaunosPalette.goldHighlight).withValues(alpha: 0.30),
                                      blurRadius: 10,
                                      spreadRadius: 1,
                                    ),
                                ],
                              ),
                              child: Center(
                                widthFactor: resolvedWidth == null ? 1.0 : null,
                                child: DefaultTextStyle(
                                  style: TextStyle(
                                    fontFamily: 'Rajdhani',
                                    fontWeight: FontWeight.w700,
                                    color: _isClickable ? Colors.white : Colors.white54,
                                  ),
                                  child: widget.child,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }
}

// =============================================================================
// KAUNOS HERO PLAY BUTTON (HYBRID 1.1 CRYSTAL SOCKET + 1.3 3D FORGED GOLD TRIGGER)
// =============================================================================

/// Dedicated hybrid Hero OYNA button uniting the 75% 1.1 "Kozmik Kristal & Gözlemevi"
/// outer celestial crystal ring with the 25% 1.3 "3D Kristal & Dövme Altın/Bevel"
/// inner forged gold trigger that mechanically depresses 3.5px into the crystal socket,
/// featuring full 6-layer juicy physics, 3D tilt, elastic snap, neon wave,
/// glowing particle burst, and kinetic screen shake.
class KaunosHeroPlayButton extends StatefulWidget {
  final VoidCallback onTap;
  final double size;
  final bool enabled;

  const KaunosHeroPlayButton({
    super.key,
    required this.onTap,
    this.size = 62.0,
    this.enabled = true,
  });

  @override
  State<KaunosHeroPlayButton> createState() => _KaunosHeroPlayButtonState();
}

class _KaunosHeroPlayButtonState extends State<KaunosHeroPlayButton> with TickerProviderStateMixin {
  bool _isPressed = false;
  Offset _pointerPos = Offset.zero;

  late final AnimationController _elasticController;
  late final Animation<double> _elasticAnimation;

  late final AnimationController _waveController;
  late final Animation<double> _waveAnimation;

  late final AnimationController _particleController;
  late final Animation<double> _particleAnimation;

  late final AnimationController _shakeController;
  late final Animation<double> _shakeAnimation;

  List<_KaunosSparkParticle> _particles = [];
  final math.Random _random = math.Random();

  @override
  void initState() {
    super.initState();
    _elasticController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _elasticAnimation = CurvedAnimation(
      parent: _elasticController,
      curve: Curves.elasticOut,
    );

    _waveController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 480),
    );
    _waveAnimation = CurvedAnimation(
      parent: _waveController,
      curve: Curves.easeOutQuad,
    );

    _particleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 450),
    );
    _particleAnimation = CurvedAnimation(
      parent: _particleController,
      curve: Curves.easeOutCubic,
    );

    _shakeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    _shakeAnimation = CurvedAnimation(
      parent: _shakeController,
      curve: Curves.linear,
    );
  }

  @override
  void dispose() {
    _elasticController.dispose();
    _waveController.dispose();
    _particleController.dispose();
    _shakeController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant KaunosHeroPlayButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.enabled) {
      _isPressed = false;
    }
  }

  void _generateParticles() {
    const count = 20;
    final particles = <_KaunosSparkParticle>[];
    for (int i = 0; i < count; i++) {
      final angle = (i * (2 * math.pi / count)) + (_random.nextDouble() * 0.3 - 0.15);
      final distance = 18.0 + _random.nextDouble() * 32.0;
      final size = 2.0 + _random.nextDouble() * 2.8;
      const colors = [
        KaunosPalette.goldGlint,
        KaunosPalette.goldHighlight,
        KaunosPalette.goldPrimary,
        KaunosPalette.crystalBorderStarlight,
        Colors.white,
      ];
      particles.add(_KaunosSparkParticle(
        angle: angle,
        distance: distance,
        size: size,
        color: colors[_random.nextInt(colors.length)],
        speedMultiplier: 0.9 + _random.nextDouble() * 0.4,
      ));
    }
    _particles = particles;
  }

  void _handleTapDown(TapDownDetails details) {
    if (!widget.enabled) return;
    setState(() {
      _isPressed = true;
      _pointerPos = details.localPosition;
    });
    // Layer 4: Snappy tactile pop on press
    HapticFeedback.lightImpact();
  }

  void _handleTapUp(TapUpDetails details) {
    if (_isPressed) {
      setState(() {
        _isPressed = false;
        _pointerPos = details.localPosition;
      });

      // Layer 2: Elastic spring snap-back
      _elasticController.forward(from: 0.0);

      // Layer 3: Perimeter expanding neon wave
      _waveController.forward(from: 0.0);

      // Layer 5: Particle burst shower
      _generateParticles();
      _particleController.forward(from: 0.0);

      // Layer 6: High-stakes kinetic screen shake & warm rewarding chime
      _shakeController.forward(from: 0.0);
      HapticFeedback.heavyImpact();
      AudioManager.instance.playSfx(GameSfx.click);
      AudioManager.instance.playSfx(GameSfx.powerupBuff, playbackRate: 1.35);

      widget.onTap();
    }
  }

  void _handleTapCancel() {
    if (_isPressed) {
      setState(() => _isPressed = false);
    }
  }

  Matrix4 _buildPerspectiveMatrix(Size size) {
    final matrix = Matrix4.identity();
    if (size.width <= 0 || size.height <= 0) return matrix;

    matrix.setEntry(3, 2, 0.0016);
    final nx = ((_pointerPos.dx / size.width) * 2.0 - 1.0).clamp(-1.0, 1.0);
    final ny = ((_pointerPos.dy / size.height) * 2.0 - 1.0).clamp(-1.0, 1.0);

    final tiltFactor = _isPressed ? 1.0 : 0.0;
    matrix.rotateX(-ny * 0.14 * tiltFactor);
    matrix.rotateY(nx * 0.14 * tiltFactor);
    return matrix;
  }

  double _computeScale() {
    if (_isPressed) return 0.93;
    if (_elasticController.isAnimating) {
      return 0.93 + 0.07 * _elasticAnimation.value;
    }
    return 1.0;
  }

  Offset _computeShakeOffset() {
    if (!_shakeController.isAnimating) return Offset.zero;
    final t = _shakeAnimation.value;
    final intensity = (1.0 - t) * 3.5;
    final dx = math.sin(t * math.pi * 8.0) * intensity;
    final dy = math.cos(t * math.pi * 6.0) * (intensity * 0.5);
    return Offset(dx, dy);
  }

  @override
  Widget build(BuildContext context) {
    const bevelDepth = 5.0;
    final depressY = _isPressed ? 3.5 : 0.0;
    final currentBevel = _isPressed ? 1.5 : bevelDepth;
    final innerDiameter = widget.size - 10.0;
    final totalSize = Size(widget.size, widget.size + bevelDepth);

    return GestureDetector(
      onTapDown: _handleTapDown,
      onTapUp: _handleTapUp,
      onTapCancel: _handleTapCancel,
      behavior: HitTestBehavior.opaque,
      child: AnimatedBuilder(
        animation: Listenable.merge([
          _elasticController,
          _waveController,
          _particleController,
          _shakeController,
        ]),
        builder: (context, child) {
          final scale = _computeScale();
          final shakeOffset = _computeShakeOffset();

          return Transform.translate(
            offset: shakeOffset,
            child: CustomPaint(
              foregroundPainter: _KaunosJuicyOverlayPainter(
                waveProgress: _waveAnimation.value,
                particleProgress: _particleAnimation.value,
                particles: _particles,
                waveColor: KaunosPalette.goldHighlight,
                borderRadius: widget.size / 2,
                isCircle: true,
                isHighStakes: true,
              ),
              child: Transform(
                transform: _buildPerspectiveMatrix(totalSize)
                  ..multiply(Matrix4.diagonal3Values(scale, scale, 1.0)),
                alignment: Alignment.center,
                child: SizedBox(
                  width: widget.size,
                  height: widget.size + bevelDepth,
                  child: Stack(
                    alignment: Alignment.center,
                    clipBehavior: Clip.none,
                    children: [
                      // -------------------------------------------------------------
                      // 75% 1.1: FIXED OUTER OBSERVATORY CRYSTAL FRAME
                      // -------------------------------------------------------------
                      Positioned.fill(
                        bottom: bevelDepth,
                        child: Container(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: const RadialGradient(
                              colors: [
                                Color(0xEE0B1224),
                                Color(0xFA05070F),
                              ],
                            ),
                            border: Border.all(
                              color: KaunosPalette.crystalBorderStarlight,
                              width: 1.8,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: KaunosPalette.crystalBorderStarlight.withValues(alpha: 0.35),
                                blurRadius: 10,
                                spreadRadius: 1,
                              ),
                              // High stakes golden glow pulse
                              const BoxShadow(
                                color: Color(0x40F59E0B),
                                blurRadius: 14,
                                spreadRadius: 2,
                              ),
                            ],
                          ),
                        ),
                      ),

                      // -------------------------------------------------------------
                      // 25% 1.3: INNER 3D FORGED GOLD TRIGGER (DEPRESSES INTO SOCKET)
                      // -------------------------------------------------------------
                      Positioned(
                        top: 5.0 + depressY,
                        width: innerDiameter,
                        height: innerDiameter,
                        child: Stack(
                          clipBehavior: Clip.none,
                          children: [
                            // Bottom bevel lip (zero-blur extruded gold shadow)
                            Positioned(
                              left: 0,
                              right: 0,
                              top: currentBevel,
                              bottom: 0,
                              child: Container(
                                decoration: const BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: KaunosPalette.goldBevelBottom,
                                ),
                              ),
                            ),

                            // Forged Gold Trigger Face
                            Positioned.fill(
                              bottom: currentBevel,
                              child: Container(
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  gradient: const LinearGradient(
                                    begin: Alignment.topCenter,
                                    end: Alignment.bottomCenter,
                                    colors: [
                                      KaunosPalette.goldGlint,
                                      KaunosPalette.goldPrimary,
                                      KaunosPalette.goldDeep,
                                    ],
                                  ),
                                  border: Border.all(
                                    color: const Color(0xFFFFFBEB),
                                    width: 1.2,
                                  ),
                                  boxShadow: const [
                                    BoxShadow(
                                      color: Color(0x66F59E0B),
                                      blurRadius: 8,
                                      offset: Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: Center(
                                  child: CustomPaint(
                                    size: Size(innerDiameter * 0.45, innerDiameter * 0.45),
                                    painter: const KaunosPlayChevronPainter(),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}


/// Handcrafted CustomPainter for the carved forged gold chevron play icon.
class KaunosPlayChevronPainter extends CustomPainter {
  final Color? color;

  const KaunosPlayChevronPainter({this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    if (w <= 0 || h <= 0) return;

    final path = Path()
      ..moveTo(w * 0.32, h * 0.20)
      ..lineTo(w * 0.80, h * 0.50)
      ..lineTo(w * 0.32, h * 0.80)
      ..close();

    // 1. Recessed drop shadow inside carved face
    canvas.drawPath(
      path.shift(const Offset(0, 1.4)),
      Paint()..color = const Color(0x99451A03),
    );

    // 2. Carved Forged Gold Surface
    final fillPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: color != null
            ? [Colors.white, color!, color!.withValues(alpha: 0.8)]
            : const [Colors.white, Color(0xFFFEF3C7), Color(0xFFD97706)],
      ).createShader(Rect.fromLTWH(0, 0, w, h));
    canvas.drawPath(path, fillPaint);

    // 3. Delicate highlight stroke
    final strokePaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.6)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8;
    canvas.drawPath(path, strokePaint);
  }

  @override
  bool shouldRepaint(covariant KaunosPlayChevronPainter oldDelegate) =>
      oldDelegate.color != color;
}

// =============================================================================
// KAUNOS EMBLEM (HANDCRAFTED VECTOR GAME ICONOGRAPHY)
// =============================================================================

/// Emblem category types for custom vector game symbols.
enum KaunosEmblemType {
  coin,
  pearl,
  padlock,
  astrolabe,
  anvil,
  crest,
  wheel,
}

/// Handcrafted vector CustomPainter game emblem replacing generic emojis and
/// business Material icons with authentic game art.
class KaunosEmblem extends StatelessWidget {
  final KaunosEmblemType type;
  final double size;
  final Color? color;
  final Color? secondaryColor;

  const KaunosEmblem({
    super.key,
    required this.type,
    this.size = 18,
    this.color,
    this.secondaryColor,
  });

  /// Factory for the Stamped Gold Coin emblem.
  const KaunosEmblem.coin({
    super.key,
    this.size = 18,
    Color? primaryColor,
    Color? rimColor,
  })  : type = KaunosEmblemType.coin,
        color = primaryColor,
        secondaryColor = rimColor;

  /// Factory for the Astral Pearl emblem.
  const KaunosEmblem.pearl({
    super.key,
    this.size = 16,
    Color? auraColor,
  })  : type = KaunosEmblemType.pearl,
        color = auraColor,
        secondaryColor = null;

  /// Factory for the Carved Padlock emblem.
  const KaunosEmblem.padlock({
    super.key,
    this.size = 16,
    Color? bodyColor,
    Color? shackleColor,
  })  : type = KaunosEmblemType.padlock,
        color = bodyColor,
        secondaryColor = shackleColor;

  /// Factory for the Celestial Astrolabe / Sector Compass emblem.
  const KaunosEmblem.astrolabe({
    super.key,
    this.size = 16,
    Color? ringColor,
    Color? starColor,
  })  : type = KaunosEmblemType.astrolabe,
        color = ringColor,
        secondaryColor = starColor;

  /// Factory for the Craftsman Anvil emblem.
  const KaunosEmblem.anvil({
    super.key,
    this.size = 16,
    Color? steelColor,
    Color? sparkColor,
  })  : type = KaunosEmblemType.anvil,
        color = steelColor,
        secondaryColor = sparkColor;

  /// Factory for the Kaunos Diamond Crest emblem.
  const KaunosEmblem.crest({
    super.key,
    this.size = 20,
    Color? crestColor,
  })  : type = KaunosEmblemType.crest,
        color = crestColor,
        secondaryColor = null;

  /// Factory for the 8-Spoke Fortune Wheel emblem.
  const KaunosEmblem.wheel({
    super.key,
    this.size = 16,
    Color? wheelColor,
  })  : type = KaunosEmblemType.wheel,
        color = wheelColor,
        secondaryColor = null;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        size: Size(size, size),
        painter: KaunosEmblemPainter(
          type: type,
          color: color,
          secondaryColor: secondaryColor,
        ),
      ),
    );
  }
}

/// Vector CustomPainter rendering each [KaunosEmblemType] with meticulous detail.
class KaunosEmblemPainter extends CustomPainter {
  final KaunosEmblemType type;
  final Color? color;
  final Color? secondaryColor;

  const KaunosEmblemPainter({
    required this.type,
    this.color,
    this.secondaryColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    if (w <= 0 || h <= 0) return;

    switch (type) {
      case KaunosEmblemType.coin:
        _paintCoin(canvas, size);
        break;
      case KaunosEmblemType.pearl:
        _paintPearl(canvas, size);
        break;
      case KaunosEmblemType.padlock:
        _paintPadlock(canvas, size);
        break;
      case KaunosEmblemType.astrolabe:
        _paintAstrolabe(canvas, size);
        break;
      case KaunosEmblemType.anvil:
        _paintAnvil(canvas, size);
        break;
      case KaunosEmblemType.crest:
        _paintCrest(canvas, size);
        break;
      case KaunosEmblemType.wheel:
        _paintWheel(canvas, size);
        break;
    }
  }

  // ---------------------------------------------------------------------------
  // 1. STAMPED GOLD COIN
  // ---------------------------------------------------------------------------
  void _paintCoin(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final r = math.min(cx, cy) - 0.5;
    if (r <= 0) return;

    final rect = Rect.fromCircle(center: Offset(cx, cy), radius: r);

    // Milled Outer Rim
    final rimPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          secondaryColor ?? KaunosPalette.goldBorder,
          secondaryColor ?? KaunosPalette.goldBevelBottom,
        ],
      ).createShader(rect);
    canvas.drawCircle(Offset(cx, cy), r, rimPaint);

    // Golden Recessed Face
    final facePaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          color ?? KaunosPalette.goldGlint,
          color ?? KaunosPalette.goldPrimary,
          color ?? KaunosPalette.goldDeep,
        ],
      ).createShader(rect);
    canvas.drawCircle(Offset(cx, cy), r * 0.82, facePaint);

    // Inner Stamped Bezel Ring
    final innerBezelPaint = Paint()
      ..color = const Color(0x66451A03)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8;
    canvas.drawCircle(Offset(cx, cy), r * 0.76, innerBezelPaint);

    // Center 8-Point Stamped Star / Diamond
    final starPath = Path();
    const points = 8;
    final outerR = r * 0.48;
    final innerR = r * 0.22;
    for (int i = 0; i < points * 2; i++) {
      final rad = (i * math.pi / points) - (math.pi / 2);
      final currentR = (i.isEven) ? outerR : innerR;
      final px = cx + currentR * math.cos(rad);
      final py = cy + currentR * math.sin(rad);
      if (i == 0) {
        starPath.moveTo(px, py);
      } else {
        starPath.lineTo(px, py);
      }
    }
    starPath.close();

    // Shadow & highlight for stamped star
    canvas.drawPath(
      starPath.shift(const Offset(0, 0.8)),
      Paint()..color = const Color(0x66451A03),
    );
    canvas.drawPath(
      starPath,
      Paint()..color = Colors.white.withValues(alpha: 0.9),
    );
  }

  // ---------------------------------------------------------------------------
  // 2. ASTRAL PEARL
  // ---------------------------------------------------------------------------
  void _paintPearl(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final r = math.min(cx, cy) - 0.5;
    if (r <= 0) return;

    // Ambient Purple Glow Aura
    final auraPaint = Paint()
      ..color = (color ?? KaunosPalette.pearlAstral).withValues(alpha: 0.35)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.5);
    canvas.drawCircle(Offset(cx, cy), r, auraPaint);

    // Spherical Pearl with Radial Shading
    final pearlRect = Rect.fromCircle(center: Offset(cx, cy), radius: r * 0.85);
    final pearlPaint = Paint()
      ..shader = RadialGradient(
        center: const Alignment(-0.35, -0.35),
        radius: 0.9,
        colors: [
          Colors.white,
          const Color(0xFFF3E8FF),
          color ?? const Color(0xFFC084FC),
          const Color(0xFF6B21A8),
          const Color(0xFF3B0764),
        ],
        stops: const [0.0, 0.25, 0.60, 0.85, 1.0],
      ).createShader(pearlRect);
    canvas.drawCircle(Offset(cx, cy), r * 0.85, pearlPaint);

    // Starlight Specular Glint (4-point cross)
    final glintCx = cx - (r * 0.32);
    final glintCy = cy - (r * 0.32);
    final glintPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.95)
      ..strokeWidth = 0.8
      ..style = PaintingStyle.stroke;
    canvas.drawLine(
      Offset(glintCx - r * 0.25, glintCy),
      Offset(glintCx + r * 0.25, glintCy),
      glintPaint,
    );
    canvas.drawLine(
      Offset(glintCx, glintCy - r * 0.25),
      Offset(glintCx, glintCy + r * 0.25),
      glintPaint,
    );
    canvas.drawCircle(
      Offset(glintCx, glintCy),
      0.8,
      Paint()..color = Colors.white,
    );
  }

  // ---------------------------------------------------------------------------
  // 3. CARVED PADLOCK
  // ---------------------------------------------------------------------------
  void _paintPadlock(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // Upper Arch Shackle
    final shacklePaint = Paint()
      ..color = secondaryColor ?? const Color(0xFFD1D5DB)
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * 0.14
      ..strokeCap = StrokeCap.round;

    final shacklePath = Path()
      ..moveTo(w * 0.30, h * 0.48)
      ..lineTo(w * 0.30, h * 0.28)
      ..arcToPoint(
        Offset(w * 0.70, h * 0.28),
        radius: Radius.circular(w * 0.20),
      )
      ..lineTo(w * 0.70, h * 0.48);
    canvas.drawPath(shacklePath, shacklePaint);

    // Bevelled Padlock Body
    final bodyRect = Rect.fromLTWH(w * 0.18, h * 0.42, w * 0.64, h * 0.48);
    final bodyRRect = RRect.fromRectAndRadius(bodyRect, Radius.circular(w * 0.12));

    // Shadow lip
    canvas.drawRRect(
      bodyRRect.shift(const Offset(0, 1.2)),
      Paint()..color = const Color(0x992B1506),
    );

    // Gradient Body
    final bodyPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          color ?? KaunosPalette.goldHighlight,
          color ?? KaunosPalette.goldPrimary,
          color ?? KaunosPalette.goldDeep,
        ],
      ).createShader(bodyRect);
    canvas.drawRRect(bodyRRect, bodyPaint);

    // Top rim highlight on body
    canvas.drawLine(
      Offset(w * 0.24, h * 0.44),
      Offset(w * 0.76, h * 0.44),
      Paint()
        ..color = Colors.white.withValues(alpha: 0.65)
        ..strokeWidth = 0.8,
    );

    // Keyhole (Recessed dark circle + slot)
    final keyholePaint = Paint()..color = const Color(0xFF1F130A);
    final keyholeCenter = Offset(w * 0.50, h * 0.60);
    canvas.drawCircle(keyholeCenter, w * 0.08, keyholePaint);

    final slotPath = Path()
      ..moveTo(w * 0.46, h * 0.60)
      ..lineTo(w * 0.54, h * 0.60)
      ..lineTo(w * 0.56, h * 0.76)
      ..lineTo(w * 0.44, h * 0.76)
      ..close();
    canvas.drawPath(slotPath, keyholePaint);
  }

  // ---------------------------------------------------------------------------
  // 4. CELESTIAL ASTROLABE / SECTOR COMPASS
  // ---------------------------------------------------------------------------
  void _paintAstrolabe(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final r = math.min(cx, cy) - 0.5;
    if (r <= 0) return;

    final primary = color ?? KaunosPalette.crystalBorderStarlight;
    final secondary = secondaryColor ?? KaunosPalette.goldHighlight;

    // Outer Celestial Ring
    final ringPaint = Paint()
      ..color = primary
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;
    canvas.drawCircle(Offset(cx, cy), r * 0.90, ringPaint);

    // Inner Tilted Ring (Elliptical Astrolabe Axis)
    canvas.save();
    canvas.translate(cx, cy);
    canvas.rotate(math.pi / 4);
    final ellipseRect = Rect.fromCenter(
      center: Offset.zero,
      width: r * 1.5,
      height: r * 0.75,
    );
    canvas.drawOval(
      ellipseRect,
      Paint()
        ..color = primary.withValues(alpha: 0.7)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.8,
    );
    canvas.restore();

    // Central 4-Point Cardinal Star
    final starPath = Path()
      ..moveTo(cx, cy - r * 0.50)
      ..lineTo(cx + r * 0.12, cy - r * 0.12)
      ..lineTo(cx + r * 0.50, cy)
      ..lineTo(cx + r * 0.12, cy + r * 0.12)
      ..lineTo(cx, cy + r * 0.50)
      ..lineTo(cx - r * 0.12, cy + r * 0.12)
      ..lineTo(cx - r * 0.50, cy)
      ..lineTo(cx - r * 0.12, cy - r * 0.12)
      ..close();

    canvas.drawPath(starPath, Paint()..color = secondary);
    canvas.drawCircle(Offset(cx, cy), 1.2, Paint()..color = Colors.white);
  }

  // ---------------------------------------------------------------------------
  // 5. CRAFTSMAN ANVIL
  // ---------------------------------------------------------------------------
  void _paintAnvil(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final steel = color ?? const Color(0xFF94A3B8);
    final spark = secondaryColor ?? KaunosPalette.goldHighlight;

    final path = Path()
      // Left horn tip
      ..moveTo(w * 0.10, h * 0.36)
      // Horn upper curve to flat face
      ..quadraticBezierTo(w * 0.22, h * 0.34, w * 0.32, h * 0.34)
      // Working flat top face
      ..lineTo(w * 0.88, h * 0.34)
      // Right face drop
      ..lineTo(w * 0.88, h * 0.44)
      // Waist indent right
      ..quadraticBezierTo(w * 0.65, h * 0.48, w * 0.60, h * 0.62)
      // Right foot flare
      ..lineTo(w * 0.78, h * 0.84)
      // Base bottom
      ..lineTo(w * 0.22, h * 0.84)
      // Left foot flare
      ..lineTo(w * 0.40, h * 0.62)
      // Waist indent left
      ..quadraticBezierTo(w * 0.35, h * 0.48, w * 0.28, h * 0.44)
      // Horn underside
      ..lineTo(w * 0.10, h * 0.36)
      ..close();

    // Shadow
    canvas.drawPath(
      path.shift(const Offset(0, 1.2)),
      Paint()..color = const Color(0x66000000),
    );

    // Steel Gradient
    final anvilPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Colors.white, steel, const Color(0xFF334155)],
      ).createShader(Rect.fromLTWH(0, 0, w, h));
    canvas.drawPath(path, anvilPaint);

    // Strike Spark (Glint) above anvil face
    final sparkPaint = Paint()..color = spark;
    canvas.drawCircle(Offset(w * 0.62, h * 0.24), 1.2, sparkPaint);
    canvas.drawLine(
      Offset(w * 0.62, h * 0.16),
      Offset(w * 0.62, h * 0.32),
      Paint()
        ..color = spark
        ..strokeWidth = 0.8,
    );
    canvas.drawLine(
      Offset(w * 0.54, h * 0.24),
      Offset(w * 0.70, h * 0.24),
      Paint()
        ..color = spark
        ..strokeWidth = 0.8,
    );
  }

  // ---------------------------------------------------------------------------
  // 6. KAUNOS DIAMOND CREST
  // ---------------------------------------------------------------------------
  void _paintCrest(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final w = size.width;
    final h = size.height;
    final crestColor = color ?? KaunosPalette.goldPrimary;

    // Outer Faceted Diamond
    final outerPath = Path()
      ..moveTo(cx, h * 0.08)
      ..lineTo(w * 0.92, cy)
      ..lineTo(cx, h * 0.92)
      ..lineTo(w * 0.08, cy)
      ..close();

    canvas.drawPath(
      outerPath.shift(const Offset(0, 1.2)),
      Paint()..color = const Color(0x66451A03),
    );

    final outerPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [KaunosPalette.goldGlint, crestColor, KaunosPalette.goldDeep],
      ).createShader(Rect.fromLTWH(0, 0, w, h));
    canvas.drawPath(outerPath, outerPaint);

    // Inner Concentric Stepped Diamond
    final innerPath = Path()
      ..moveTo(cx, h * 0.26)
      ..lineTo(w * 0.74, cy)
      ..lineTo(cx, h * 0.74)
      ..lineTo(w * 0.26, cy)
      ..close();

    canvas.drawPath(
      innerPath,
      Paint()
        ..color = const Color(0xDD070B18)
        ..style = PaintingStyle.fill,
    );

    // Center Crystal Gem
    canvas.drawCircle(
      Offset(cx, cy),
      w * 0.12,
      Paint()..color = KaunosPalette.crystalBorderStarlight,
    );
  }

  // ---------------------------------------------------------------------------
  // 7. CELESTIAL FORTUNE WHEEL
  // ---------------------------------------------------------------------------
  void _paintWheel(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final r = math.min(cx, cy) - 0.5;
    if (r <= 0) return;

    final wheelColor = color ?? KaunosPalette.goldPrimary;

    // Outer Rim
    final rimPaint = Paint()
      ..color = wheelColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    canvas.drawCircle(Offset(cx, cy), r * 0.88, rimPaint);

    // 8 Spokes
    const spokes = 8;
    final spokePaint = Paint()
      ..color = wheelColor.withValues(alpha: 0.75)
      ..strokeWidth = 0.8;
    for (int i = 0; i < spokes; i++) {
      final rad = i * 2 * math.pi / spokes;
      final px = cx + (r * 0.88) * math.cos(rad);
      final py = cy + (r * 0.88) * math.sin(rad);
      canvas.drawLine(Offset(cx, cy), Offset(px, py), spokePaint);
    }

    // Central Hub
    canvas.drawCircle(
      Offset(cx, cy),
      r * 0.26,
      Paint()..color = KaunosPalette.goldGlint,
    );
    canvas.drawCircle(
      Offset(cx, cy),
      r * 0.12,
      Paint()..color = KaunosPalette.goldBevelBottom,
    );
  }

  @override
  bool shouldRepaint(covariant KaunosEmblemPainter oldDelegate) =>
      oldDelegate.type != type ||
      oldDelegate.color != color ||
      oldDelegate.secondaryColor != secondaryColor;
}

// =============================================================================
// KAUNOS BADGE (TACTILE LOCK / STATUS BADGE)
// =============================================================================

/// Tactile status or lock pill badge designed for clean typography hierarchy,
/// zero RenderFlex overflow risk across compact viewports, and full test compatibility.
class KaunosBadge extends StatelessWidget {
  final String text;
  final Widget? icon;
  final Color? backgroundColor;
  final Color? borderColor;
  final Color? textColor;
  final double fontSize;
  final FontWeight fontWeight;
  final EdgeInsetsGeometry padding;
  final double borderRadius;
  final bool showGlow;

  const KaunosBadge({
    super.key,
    required this.text,
    this.icon,
    this.backgroundColor,
    this.borderColor,
    this.textColor,
    this.fontSize = 11.0,
    this.fontWeight = FontWeight.w700,
    this.padding = const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    this.borderRadius = 10.0,
    this.showGlow = false,
  });

  /// Const named constructor for a locked chapter badge (e.g. "🔒 Bölüm 2", "🔒 BÖLÜM 5").
  const KaunosBadge.lock({
    super.key,
    required this.text,
    this.fontSize = 11.0,
    Color? borderColor,
  })  : icon = const KaunosEmblem.padlock(size: 12),
        backgroundColor = const Color(0xCC05070F),
        borderColor = borderColor ?? const Color(0x5538BDF8),
        textColor = const Color(0xFFF3F4F6),
        fontWeight = FontWeight.w700,
        padding = const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
        borderRadius = 10.0,
        showGlow = false;

  @override
  Widget build(BuildContext context) {
    final bg = backgroundColor ?? const Color(0xCC05070F);
    final border = borderColor ?? KaunosPalette.crystalBorderStarlight;
    final fg = textColor ?? Colors.white;

    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(color: border, width: 1.0),
        boxShadow: showGlow
            ? [
                BoxShadow(
                  color: border.withValues(alpha: 0.3),
                  blurRadius: 6,
                  spreadRadius: 0.5,
                ),
              ]
            : null,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          if (icon != null) ...[
            icon!,
            const SizedBox(width: 4),
          ],
          Flexible(
            child: Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontFamily: 'Rajdhani',
                fontSize: fontSize,
                fontWeight: fontWeight,
                color: fg,
                letterSpacing: 0.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
