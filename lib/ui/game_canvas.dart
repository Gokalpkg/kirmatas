import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import '../engine/ad_manager.dart';
import '../engine/asset_cache.dart';
import '../engine/audio_manager.dart';
import '../engine/game_controller.dart';
import '../engine/i18n.dart';
import '../models/brick.dart';
import '../models/game_state.dart';
import '../models/ball.dart';
import '../models/powerup.dart';
import 'pixel_art.dart';
import '../models/cosmetics.dart';
import '../models/sector_data.dart';
import '../models/sector_blessing.dart';
import '../models/portal.dart';
import '../models/easter_egg.dart';

class GameCanvas extends StatefulWidget {
  final GameController controller;

  const GameCanvas({super.key, required this.controller});

  @override
  State<GameCanvas> createState() => _GameCanvasState();
}

class _GameCanvasState extends State<GameCanvas> with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late final Ticker _ticker;
  Duration _lastElapsed = Duration.zero;
  double _pointerStartX = 0;
  bool _pointerMoved = false;
  Offset? _chaosPointerDownPos;
  int? _touchStartLevel;
  bool _canLaunchOnUp = false;
  int _lastPointerDownMs = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _ticker = createTicker((elapsed) {
      if (_lastElapsed == Duration.zero) {
        _lastElapsed = elapsed;
        return;
      }
      if (!AudioManager.instance.appInForeground || AdManager.instance.isShowing) {
        if (widget.controller.status == GameStatus.playing || widget.controller.status == GameStatus.ready) {
          widget.controller.pause();
        }
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
    WidgetsBinding.instance.removeObserver(this);
    _ticker.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive ||
        state == AppLifecycleState.hidden) {
      if (widget.controller.status == GameStatus.playing || widget.controller.status == GameStatus.ready) {
        widget.controller.pause();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        widget.controller.setDimensions(constraints.maxWidth, constraints.maxHeight);

        return Listener(
          behavior: HitTestBehavior.opaque,
          onPointerDown: (event) {
            final c = widget.controller;
            final nowMs = DateTime.now().millisecondsSinceEpoch;
            if (nowMs - _lastPointerDownMs < 350 && c.isUltiReady) {
              c.triggerUlti();
            }
            _lastPointerDownMs = nowMs;

            if (c.levelTransitionTimer > 0) {
              _canLaunchOnUp = false;
              _touchStartLevel = null;
              return;
            }
            _touchStartLevel = c.stats.level;
            _canLaunchOnUp = true;

            if (c.currentMode == GameMode.chaos) {
              if (c.status == GameStatus.playing) {
                // Direct Recall button
                const btnW = 110.0;
                const btnH = 38.0;
                final rightBtnRect = Rect.fromLTWH(c.screenWidth - btnW - 14.0, c.screenHeight - btnH - 12.0, btnW, btnH);
                if (rightBtnRect.contains(event.localPosition)) {
                  c.recallChaosBalls();
                  return;
                }
              }

              if (c.status == GameStatus.ready) {
                _chaosPointerDownPos = event.localPosition;
                if (event.localPosition.dy >= c.chaosFloorY - 24.0) {
                  c.aimChaos(c.chaosHomeX, c.chaosFloorY - 120.0);
                } else {
                  c.aimChaos(event.localPosition.dx, event.localPosition.dy);
                }
              }
              return;
            }
            _pointerStartX = event.localPosition.dx;
            _pointerMoved = false;
          },
          onPointerMove: (event) {
            final c = widget.controller;
            if (c.levelTransitionTimer > 0) {
              _canLaunchOnUp = false;
              return;
            }
            if (c.currentMode == GameMode.chaos) {
              if (c.status == GameStatus.ready) {
                _chaosPointerDownPos ??= event.localPosition;
                _touchStartLevel = c.stats.level;
                _canLaunchOnUp = true;
                _pointerMoved = false;
                if (_chaosPointerDownPos!.dy >= c.chaosFloorY - 24.0) {
                  // Ergonomic Slingshot drag from bottom
                  final dragX = event.localPosition.dx - _chaosPointerDownPos!.dx;
                  final dragY = event.localPosition.dy - _chaosPointerDownPos!.dy;
                  final aimX = c.chaosHomeX - dragX * 1.6;
                  final aimY = c.chaosFloorY - max(dragY.abs() * 1.8, 60.0);
                  c.aimChaos(aimX, aimY);
                } else {
                  // Direct field aim
                  c.aimChaos(event.localPosition.dx, event.localPosition.dy);
                }
              }
              return;
            }
            if (_touchStartLevel != c.stats.level) {
              _canLaunchOnUp = false;
              _pointerMoved = true;
            }
            final dx = event.delta.dx;
            if (!_pointerMoved && (event.localPosition.dx - _pointerStartX).abs() < 8) {
              return;
            }
            _pointerMoved = true;
            c.movePaddleBy(dx);
          },
          onPointerUp: (_) {
            final controller = widget.controller;
            final isEligible = _canLaunchOnUp &&
                !_pointerMoved &&
                controller.levelTransitionTimer <= 0 &&
                _touchStartLevel == controller.stats.level;
            _canLaunchOnUp = false;
            _touchStartLevel = null;

            if (controller.currentMode == GameMode.chaos) {
              _chaosPointerDownPos = null;
              if (isEligible && controller.status == GameStatus.ready) {
                controller.fireChaos();
              }
              return;
            }
            if (isEligible &&
                (controller.status == GameStatus.ready || controller.hasStuckBall)) {
              controller.launchBall();
            }
          },
          onPointerCancel: (_) {
            _canLaunchOnUp = false;
            _touchStartLevel = null;
            _pointerMoved = false;
            _chaosPointerDownPos = null;
          },
          child: Stack(
            children: [
              RepaintBoundary(
                child: CustomPaint(
                  size: Size(constraints.maxWidth, constraints.maxHeight),
                  painter: _GameWorldPainter(widget.controller),
                ),
              ),
              Positioned.fill(
                child: IgnorePointer(
                  child: RepaintBoundary(
                    child: CustomPaint(
                      key: const Key('screen_vignette_overlay'),
                      painter: _ScreenVignettePainter(widget.controller),
                    ),
                  ),
                ),
              ),
              ListenableBuilder(
                listenable: widget.controller,
                builder: (context, _) {
                  final c = widget.controller;
                  if (c.currentMode != GameMode.chaos &&
                      c.activeSectorBlessing == null &&
                      c.offeredSectorBlessings.isEmpty) {
                    return const SizedBox.shrink();
                  }
                  return Stack(
                    children: [
                      if (c.activeSectorBlessing != null)
                        Positioned(
                          top: 8,
                          right: 12,
                          child: IgnorePointer(
                            child: Container(
                              key: const Key('active_sector_blessing_hud'),
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: const Color(0xCC101424),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: c.activeSectorBlessing!.primaryColor.withValues(alpha: 0.8),
                                  width: 1.4,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: c.activeSectorBlessing!.primaryColor.withValues(alpha: 0.3),
                                    blurRadius: 8,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(c.activeSectorBlessing!.icon, color: c.activeSectorBlessing!.primaryColor, size: 14),
                                  const SizedBox(width: 5),
                                  Text(
                                    c.activeSectorBlessing!.title,
                                    style: TextStyle(
                                      color: c.activeSectorBlessing!.primaryColor,
                                      fontSize: 10.5,
                                      fontWeight: FontWeight.w900,
                                      letterSpacing: 0.3,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      if (c.activeChaosPerks.isNotEmpty)
                        Positioned(
                          top: 8,
                          left: 10,
                          right: 10,
                          child: IgnorePointer(
                            child: Wrap(
                              key: const Key('active_chaos_perks_hud'),
                              spacing: 6,
                              runSpacing: 4,
                              children: c.activeChaosPerks.toSet().map((perk) {
                                final count = c.activeChaosPerks.where((p) => p == perk).length;
                                return Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: const Color(0xCC101424),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: perk.color.withValues(alpha: 0.7)),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(perk.icon, color: perk.color, size: 12),
                                      const SizedBox(width: 4),
                                      Text(
                                        count > 1 ? 'x$count' : perk.titleTr.split(' ').last,
                                        style: TextStyle(
                                          color: perk.color,
                                          fontSize: 10,
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              }).toList(),
                            ),
                          ),
                        ),
                      if (c.offeredChaosPerks.isNotEmpty)
                        Positioned.fill(
                          child: Container(
                            key: const Key('chaos_perk_selection_overlay'),
                            color: Colors.black.withValues(alpha: 0.72),
                            alignment: Alignment.center,
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
                            child: SingleChildScrollView(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Text(
                                    'KAOS GÜÇLENDİRMESİ SEÇ',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      color: Color(0xFFFFD54F),
                                      fontSize: 16,
                                      fontWeight: FontWeight.w900,
                                      letterSpacing: 1.0,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Dalga ${c.stats.level} Ödülü — Bu koşu boyunca birikir',
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(
                                      color: Colors.white70,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  ...c.offeredChaosPerks.map((perk) {
                                    return Padding(
                                      padding: const EdgeInsets.only(bottom: 8),
                                      child: InkWell(
                                        key: Key('chaos_perk_card_${perk.name}'),
                                        onTap: () => c.selectChaosPerk(perk),
                                        borderRadius: BorderRadius.circular(14),
                                        child: Container(
                                          width: double.infinity,
                                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFF14192B),
                                            borderRadius: BorderRadius.circular(14),
                                            border: Border.all(
                                              color: perk.color.withValues(alpha: 0.8),
                                              width: 1.5,
                                            ),
                                          ),
                                          child: Row(
                                            children: [
                                              Container(
                                                width: 36,
                                                height: 36,
                                                decoration: BoxDecoration(
                                                  color: perk.color.withValues(alpha: 0.18),
                                                  shape: BoxShape.circle,
                                                ),
                                                child: Icon(perk.icon, color: perk.color, size: 20),
                                              ),
                                              const SizedBox(width: 10),
                                              Expanded(
                                                child: Column(
                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                  children: [
                                                    Text(
                                                      perk.cleanTitleTr,
                                                      maxLines: 1,
                                                      overflow: TextOverflow.ellipsis,
                                                      style: const TextStyle(
                                                        color: Colors.white,
                                                        fontWeight: FontWeight.w900,
                                                        fontSize: 13,
                                                      ),
                                                    ),
                                                    const SizedBox(height: 2),
                                                    Text(
                                                      perk.descriptionTr,
                                                      maxLines: 2,
                                                      overflow: TextOverflow.ellipsis,
                                                      style: const TextStyle(
                                                        color: Colors.white70,
                                                        fontSize: 11,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                              const SizedBox(width: 6),
                                              Icon(Icons.chevron_right_rounded, color: perk.color, size: 22),
                                            ],
                                          ),
                                        ),
                                      ),
                                    );
                                  }),
                                ],
                              ),
                            ),
                          ),
                        ),
                      if (c.offeredSectorBlessings.isNotEmpty)
                        Positioned.fill(
                          child: Container(
                            key: const Key('sector_blessing_selection_overlay'),
                            color: Colors.black.withValues(alpha: 0.82),
                            alignment: Alignment.center,
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
                            child: SingleChildScrollView(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    I18n.tr('sector_blessing_title'),
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(
                                      color: Color(0xFFFFD54F),
                                      fontSize: 17,
                                      fontWeight: FontWeight.w900,
                                      letterSpacing: 1.0,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    I18n.tr('sector_blessing_subtitle'),
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(
                                      color: Colors.white70,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(height: 14),
                                  ...c.offeredSectorBlessings.map((blessing) {
                                    return Padding(
                                      padding: const EdgeInsets.only(bottom: 10),
                                      child: InkWell(
                                        key: Key('sector_blessing_card_${blessing.id}'),
                                        onTap: () => c.selectSectorBlessing(blessing),
                                        borderRadius: BorderRadius.circular(16),
                                        child: Container(
                                          width: double.infinity,
                                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                          decoration: BoxDecoration(
                                            gradient: const LinearGradient(
                                              begin: Alignment.topLeft,
                                              end: Alignment.bottomRight,
                                              colors: [
                                                Color(0xFF1E2337),
                                                Color(0xFF14192B),
                                              ],
                                            ),
                                            borderRadius: BorderRadius.circular(16),
                                            border: Border.all(
                                              color: blessing.primaryColor.withValues(alpha: 0.85),
                                              width: 1.8,
                                            ),
                                            boxShadow: [
                                              BoxShadow(
                                                color: blessing.primaryColor.withValues(alpha: 0.22),
                                                blurRadius: 10,
                                                offset: const Offset(0, 4),
                                              ),
                                            ],
                                          ),
                                          child: Row(
                                            children: [
                                              Container(
                                                width: 44,
                                                height: 44,
                                                decoration: BoxDecoration(
                                                  color: blessing.primaryColor.withValues(alpha: 0.18),
                                                  shape: BoxShape.circle,
                                                  border: Border.all(
                                                    color: blessing.primaryColor.withValues(alpha: 0.5),
                                                    width: 1.2,
                                                  ),
                                                ),
                                                child: Icon(blessing.icon, color: blessing.primaryColor, size: 24),
                                              ),
                                              const SizedBox(width: 12),
                                              Expanded(
                                                child: Column(
                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                  children: [
                                                    Text(
                                                      blessing.title,
                                                      maxLines: 1,
                                                      overflow: TextOverflow.ellipsis,
                                                      style: TextStyle(
                                                        color: blessing.primaryColor,
                                                        fontWeight: FontWeight.w900,
                                                        fontSize: 14,
                                                      ),
                                                    ),
                                                    const SizedBox(height: 3),
                                                    Text(
                                                      blessing.description,
                                                      maxLines: 2,
                                                      overflow: TextOverflow.ellipsis,
                                                      style: const TextStyle(
                                                        color: Colors.white,
                                                        fontSize: 11,
                                                        fontWeight: FontWeight.w500,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                              const SizedBox(width: 6),
                                              Icon(Icons.chevron_right_rounded, color: blessing.primaryColor, size: 22),
                                            ],
                                          ),
                                        ),
                                      ),
                                    );
                                  }),
                                ],
                              ),
                            ),
                          ),
                        ),
                    ],
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Edge vignette: a slow red heartbeat on the last life and a short cyan flash
/// right after a near-miss paddle save. Paints nothing when neither is active.
class _ScreenVignettePainter extends CustomPainter {
  final GameController c;

  _ScreenVignettePainter(this.c) : super(repaint: c.frameTick);

  @override
  void paint(Canvas canvas, Size size) {
    double redAlpha = 0.0;
    if (c.isLowLifeAlertActive) {
      // ~72 bpm double-beat envelope: sharp thump then softer echo.
      final t = (c.gameTime * 1.2) % 1.0;
      final beat = t < 0.12
          ? t / 0.12
          : t < 0.30
              ? 1.0 - (t - 0.12) / 0.18
              : (t > 0.36 && t < 0.52)
                  ? 0.55 * (1.0 - (t - 0.36) / 0.16)
                  : 0.0;
      final fade = (c.lowLifeAlertTimer / 0.8).clamp(0.0, 1.0);
      redAlpha = (0.05 + 0.10 * beat.clamp(0.0, 1.0)) * fade;
    }
    final flash = (c.nearMissFlashTimer / 0.55).clamp(0.0, 1.0);
    if (redAlpha <= 0.0 && flash <= 0.0) return;

    final rect = Offset.zero & size;
    void edge(Color color, double alpha) {
      final paint = Paint()
        ..shader = RadialGradient(
          radius: 0.95,
          colors: [
            color.withValues(alpha: 0.0),
            color.withValues(alpha: 0.0),
            color.withValues(alpha: alpha),
          ],
          stops: const [0.0, 0.78, 1.0],
        ).createShader(rect);
      canvas.drawRect(rect, paint);
    }

    if (redAlpha > 0.0) edge(const Color(0xFFFF1744), redAlpha);
    if (flash > 0.0) edge(const Color(0xFF00E5FF), 0.55 * flash);
  }

  @override
  bool shouldRepaint(covariant _ScreenVignettePainter oldDelegate) => false;
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
  static final Path _tempPath = Path();
  static final TextPainter _tp = TextPainter(textDirection: TextDirection.ltr);

  static final Path _splatPath1 = Path();
  static final Path _splatPath2 = Path();
  static final Path _splatPath3 = Path();
  static bool _splatPathsInitialized = false;
  static final Map<int, Color> _alphaColors = {};
  static final Map<int, Shader> _skinShaders = {};
  static final Map<int, Shader> _brickShaders = {};
  static final Map<int, Shader> _bgShaders = {};
  static final Map<int, Color> _hslDerivedColors = {};

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
    _drawAmbientPointLight(canvas, size);
    _drawBlackHoles(canvas);
    _drawPortals(canvas);
    _drawBricks(canvas);
    _drawTargetLock(canvas);
    _drawPixelShockwaves(canvas);
    _drawShards(canvas);
    _drawNet(canvas, size);
    _drawPaddle(canvas);
    _drawChaosAim(canvas);
    _drawChronoLaser(canvas);
    _drawCapsules(canvas);
    _drawProjectiles(canvas);
    _drawBalls(canvas);
    _drawBee(canvas);
    _drawDrone(canvas);
    _drawDice(canvas);
    _drawParticles(canvas);
    _drawCoinOrbs(canvas);
    if (c.stats.isFever) {
      _drawFeverEdges(canvas, size);
    }
    if (c.reviveFlashTimer > 0) {
      _drawReviveFlash(canvas, size);
    }

    _drawBossWarningBanner(canvas, size);
    _drawLevelClearCelebration(canvas, size);
    if (c.showLevel1DragGuide) {
      _drawLevel1DragGuide(canvas, c.paddle.rect, time);
    }
    if (c.isUltiReady) {
      _drawUltiReadyCallout(canvas, size, time);
    }

    _drawPlayfieldBorder(canvas, size);

    canvas.restore();

    _drawWindshieldSplat(canvas, size);
  }

  void _drawBackground(Canvas canvas, Size size) {
    final bgTheme = c.activeBackground;

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

    // Sektör Ambiyans Aurası (Klasik Modda her sektörün kendine has atmosferik ışığı - önbelleklenmiş shader)
    if (c.currentMode == GameMode.classic) {
      final sector = SectorData.getSectorForLevel(c.stats.level);
      final key = Object.hash('sector_aura', sector.primaryColor.toARGB32(), size.width.round(), size.height.round());
      _fill.shader = _bgShaders.putIfAbsent(key, () {
        return RadialGradient(
          center: const Alignment(0, -0.65),
          radius: 1.15,
          colors: [
            sector.primaryColor.withValues(alpha: 0.12),
            sector.accentColor.withValues(alpha: 0.04),
            Colors.transparent,
          ],
          stops: const [0.0, 0.45, 1.0],
        ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));
      });
      canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), _fill);
      _fill.shader = null;
    }

    // Side-mode ambience: each mode gets the same atmospheric love as
    // the classic sectors, tinted to its own identity.
    if (c.currentMode == GameMode.zen) {
      // Zen breathes in the main adventure's sunset tone.
      _drawModeAura(canvas, size, const Color(0xFFC85A32), const Color(0xFFF5B041));
      _drawZenMotes(canvas, size);
    } else if (c.currentMode == GameMode.shapes) {
      // Amber-bronze, sunset family.
      _drawModeAura(canvas, size, const Color(0xFFD97706), const Color(0xFFF5B041));
    } else if (c.currentMode == GameMode.descend) {
      // Deep-teal jade family.
      _drawModeAura(canvas, size, const Color(0xFF2E6E7E), const Color(0xFF48A9A6));
      _drawDescendDanger(canvas, size);
    }
  }

  void _drawModeAura(Canvas canvas, Size size, Color primary, Color accent) {
    final key = Object.hash('mode_aura', primary.toARGB32(), size.width.round(), size.height.round());
    _fill.shader = _bgShaders.putIfAbsent(key, () {
      return RadialGradient(
        center: const Alignment(0, -0.65),
        radius: 1.15,
        colors: [
          primary.withValues(alpha: 0.14),
          accent.withValues(alpha: 0.05),
          Colors.transparent,
        ],
        stops: const [0.0, 0.45, 1.0],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));
    });
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), _fill);
    _fill.shader = null;
  }

  static double _fract(double v) => v - v.floorToDouble();

  /// Slow drifting dust motes that give Zen its calm, breathing air.
  void _drawZenMotes(Canvas canvas, Size size) {
    _fill.shader = null;
    _fill.style = PaintingStyle.fill;
    for (var i = 0; i < 16; i++) {
      final fx = _fract(sin(i * 127.1) * 43758.5453);
      final fy = _fract(sin(i * 311.7) * 12543.123);
      final fallSpeed = 4.0 + (i % 5) * 1.6;
      final y = ((fy * size.height + time * fallSpeed) % (size.height + 24.0)) - 12.0;
      final x = fx * size.width + sin(time * 0.6 + i * 1.7) * 10.0;
      final r = 1.2 + (i % 3) * 0.7;
      _fill.color = _ca(const Color(0xFFFFCCBC), 0.08 + (i % 4) * 0.03);
      canvas.drawCircle(Offset(x, y), r, _fill);
    }
  }

  /// Descend telegraphing: a filling next-drop bar plus a bottom danger
  /// glow and warning line as the wall closes in on the paddle.
  void _drawDescendDanger(Canvas canvas, Size size) {
    if (c.status == GameStatus.gameOver) return;
    _fill.shader = null;
    _fill.style = PaintingStyle.fill;

    // Next-drop countdown bar, just under the HUD pills.
    final progress = c.descendDropProgress;
    const barY = 66.0;
    _fill.color = _ca(Colors.white, 0.10);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
          Rect.fromLTWH(10, barY, size.width - 20, 3), const Radius.circular(2)),
      _fill,
    );
    _fill.color = _ca(
        progress > 0.75 ? const Color(0xFFFF5252) : const Color(0xFF48A9A6),
        0.85);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
          Rect.fromLTWH(10, barY, (size.width - 20) * progress, 3),
          const Radius.circular(2)),
      _fill,
    );

    // Proximity of the lowest live brick to the paddle line.
    var lowest = 0.0;
    for (final b in c.bricks) {
      if (!b.isAlive) continue;
      final bottom = b.targetY + b.height;
      if (bottom > lowest) lowest = bottom;
    }
    if (lowest <= 0) return;
    final gap = c.paddle.y - lowest;
    if (gap >= 150) return;

    final intensity = (1.0 - (gap / 150.0)).clamp(0.0, 1.0);
    final pulse = 0.6 + 0.4 * sin(time * (4.0 + intensity * 5.0));

    // Rising red glow from the bottom edge.
    final glowH = 90.0 + intensity * 60.0;
    final glow = LinearGradient(
      begin: Alignment.bottomCenter,
      end: Alignment.topCenter,
      colors: [
        _ca(const Color(0xFFFF1744), 0.05 + 0.16 * intensity * pulse),
        Colors.transparent,
      ],
    ).createShader(Rect.fromLTWH(0, size.height - glowH, size.width, glowH));
    _fill.shader = glow;
    canvas.drawRect(
        Rect.fromLTWH(0, size.height - glowH, size.width, glowH), _fill);
    _fill.shader = null;

    // Pulsing danger line on the paddle row.
    _stroke
      ..strokeWidth = 2.0
      ..color = _ca(const Color(0xFFFF1744), 0.25 + 0.55 * intensity * pulse);
    canvas.drawLine(
        Offset(8, c.paddle.y - 6), Offset(size.width - 8, c.paddle.y - 6), _stroke);

    if (gap < 78 && c.status == GameStatus.playing) {
      _tp.text = TextSpan(
        text: '⚠ DUVAR YAKLAŞIYOR!',
        style: TextStyle(
          fontFamily: 'Rajdhani',
          fontFamilyFallback: const ['Segoe UI Emoji', 'Segoe UI Symbol'],
          color: _ca(const Color(0xFFFF5252), 0.55 + 0.45 * pulse),
          fontSize: 13.0,
          fontWeight: FontWeight.w900,
          letterSpacing: 1.6,
          shadows: [
            Shadow(
                color: _ca(const Color(0xFFFF1744), 0.7 * pulse),
                blurRadius: 10.0),
            const Shadow(color: Colors.black, offset: Offset(0, 2), blurRadius: 4.0),
          ],
        ),
      );
      _tp.layout();
      _tp.paint(
          canvas, Offset((size.width - _tp.width) / 2, c.paddle.y - 44));
    }
  }

  void _drawAmbientPointLight(Canvas canvas, Size size) {
    if (c.balls.isEmpty) return;
    for (final ball in c.balls) {
      if (ball.isStuck) continue;
      final ballColor = ball.isFireball
          ? const Color(0xFFFF1744)
          : (ball.isPurple ? const Color(0xFFD500F9) : c.activeBallSkin.glowColor);
      final glowRadius = (ball.radius * 3.5).clamp(24.0, 52.0);
      final glowShader = RadialGradient(
        colors: [
          _ca(ballColor, 0.18),
          _ca(ballColor, 0.06),
          Colors.transparent,
        ],
        stops: const [0.0, 0.45, 1.0],
      ).createShader(Rect.fromCircle(center: Offset(ball.x, ball.y), radius: glowRadius));
      _fill.shader = glowShader;
      canvas.drawCircle(Offset(ball.x, ball.y), glowRadius, _fill);
      _fill.shader = null;
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

    // Subtle paddle parallax offset (-1.0 to 1.0 based on center)
    final paddleNorm = size.width > 0 ? ((c.paddle.x + c.paddle.width / 2) / size.width - 0.5) * 2.0 : 0.0;

    // Üç katmanlı kayan yıldız alanı: uzak (soluk/yavaş) -> yakın (parlak/hızlı).
    // Seeded pseudo-random dağılım; yıldızlar ışıltılı ve bir kısmı 4 köşeli
    // parıltı (sparkle) formunda çizilir — düz nokta ızgarası görünümü yok.
    _drawStarLayer(canvas, size,
        count: 42, speed: 7.0, radius: 0.8, parallax: 6.0, paddleNorm: paddleNorm, seed: 11, sparkleEvery: 0);
    _drawStarLayer(canvas, size,
        count: 30, speed: 15.0, radius: 1.25, parallax: 12.0, paddleNorm: paddleNorm, seed: 47, sparkleEvery: 7);
    _drawStarLayer(canvas, size,
        count: 16, speed: 26.0, radius: 1.7, parallax: 20.0, paddleNorm: paddleNorm, seed: 83, sparkleEvery: 4);

    // Ara ara geçen kayan yıldız (her ~8 saniyede bir, 0.9 sn sürer).
    final shootCycle = time % 8.0;
    if (shootCycle < 0.9 && size.width > 10 && size.height > 10) {
      final shootSeed = (time / 8.0).floor();
      final rand = Random(shootSeed * 31 + 7);
      final startX = size.width * (0.15 + rand.nextDouble() * 0.6);
      final startY = size.height * (0.05 + rand.nextDouble() * 0.25);
      final t = shootCycle / 0.9;
      final headX = startX + t * size.width * 0.42;
      final headY = startY + t * size.height * 0.20;
      final tailX = headX - size.width * 0.16;
      final tailY = headY - size.height * 0.075;
      final fade = (1.0 - t) * (t < 0.15 ? t / 0.15 : 1.0);
      _stroke
        ..strokeWidth = 1.8
        ..strokeCap = StrokeCap.round
        ..color = _ca(const Color(0xFFB3E5FC), 0.75 * fade);
      canvas.drawLine(Offset(tailX, tailY), Offset(headX, headY), _stroke);
      _fill.color = _ca(Colors.white, 0.9 * fade);
      canvas.drawCircle(Offset(headX, headY), 1.9, _fill);
      _stroke.strokeCap = StrokeCap.butt;
    }
  }

  /// Bir yıldız katmanı çizer: aşağı kayan, titreyen (twinkle) yıldızlar.
  /// [sparkleEvery] > 0 ise her N'inci yıldız 4 köşeli parıltı olarak çizilir.
  void _drawStarLayer(Canvas canvas, Size size,
      {required int count,
      required double speed,
      required double radius,
      required double parallax,
      required double paddleNorm,
      required int seed,
      required int sparkleEvery}) {
    if (size.width < 10 || size.height < 10) return;
    final rand = Random(seed);
    for (int i = 0; i < count; i++) {
      final fx = rand.nextDouble();
      final fy = rand.nextDouble();
      final phase = rand.nextDouble() * pi * 2;
      final tintPick = rand.nextDouble();
      final jitter = 0.75 + rand.nextDouble() * 0.5;
      final rawX = fx * size.width - paddleNorm * parallax * jitter;
      final x = (rawX % size.width + size.width) % size.width;
      final y = (fy * size.height + time * speed * jitter) % size.height;
      final twinkle = 0.5 + 0.5 * sin(time * (1.8 + jitter) + phase);
      final alpha = (0.28 + 0.62 * twinkle).clamp(0.15, 0.95);
      final color = tintPick < 0.22
          ? const Color(0xFF80D8FF)
          : (tintPick < 0.36 ? const Color(0xFFFFF9C4) : Colors.white);
      final pos = Offset(x, y);
      if (sparkleEvery > 0 && i % sparkleEvery == 0) {
        // 4 köşeli ışıltı yıldızı: merkez + ince çapraz kollar, nabız atan boy.
        final r = radius * (1.6 + 1.1 * twinkle);
        _fill.color = _ca(color, alpha);
        canvas.drawCircle(pos, radius * 0.85, _fill);
        _stroke
          ..strokeWidth = 1.1
          ..color = _ca(color, alpha * 0.85);
        canvas.drawLine(Offset(x - r, y), Offset(x + r, y), _stroke);
        canvas.drawLine(Offset(x, y - r), Offset(x, y + r), _stroke);
      } else {
        _fill.color = _ca(color, alpha);
        canvas.drawCircle(pos, radius * (0.8 + 0.5 * twinkle), _fill);
      }
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

    final paddleNorm = size.width > 0 ? ((c.paddle.x + c.paddle.width / 2) / size.width - 0.5) * 2.0 : 0.0;

    for (int i = 0; i < 3; i++) {
      final cloudParallax = paddleNorm * (6.0 + i * 4.0);
      final cloudX = size.width * (0.25 + 0.5 * sin(time * 0.15 + i * 1.5)) - cloudParallax;
      final cloudY = size.height * (0.2 + 0.3 * cos(time * 0.12 + i * 2.0));
      _fill.color = _ca((i % 2 == 0 ? const Color(0xFFC084FC) : const Color(0xFFF472B6)), 0.1);
      canvas.drawCircle(Offset(cloudX, cloudY), 65.0 + 10 * sin(time + i), _fill);
    }

    for (int i = 0; i < 38; i++) {
      final speed = 12.0 + (i % 3) * 5.0;
      final parallaxDepth = 0.4 + (i % 3) * 0.5;
      final parallaxDx = paddleNorm * 16.0 * parallaxDepth;
      final rawX = ((i * 113 + 17) % size.width.toInt()).toDouble() - parallaxDx;
      final x = (rawX % size.width + size.width) % size.width;
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
      final cy = b.y + b.height / 2 + b.bounceOffsetY;
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

      // Step 1: 1-frame pure white flash on hit / destruction
      if (b.flashTimer > 0) {
        _fill
          ..shader = null
          ..maskFilter = null
          ..color = Colors.white;
        canvas.drawRect(rect, _fill);
        _stroke
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5
          ..color = const Color(0xFF0B1021);
        canvas.drawRect(rect, _stroke);
        canvas.restore();
        continue;
      }

      if (c.currentMode == GameMode.chaos && b.isBallPickup) {
        // Collectible +1 Ball Orb
        final pulse = sin(time * 6.0) * 1.5;
        final orbR = (b.height * 0.40 + pulse).clamp(7.0, 13.0);

        // Glowing aura
        _fill
          ..shader = null
          ..maskFilter = null
          ..color = _ca(const Color(0xFF00E5FF), 0.35);
        canvas.drawCircle(Offset.zero, orbR * 1.6, _fill);

        // Inner orb fill
        _fill.color = const Color(0xFF00E5FF);
        canvas.drawCircle(Offset.zero, orbR, _fill);
        _fill.color = Colors.white;
        canvas.drawCircle(Offset.zero, orbR * 0.45, _fill);

        // Specular glint
        _fill.color = Colors.white;
        canvas.drawCircle(Offset(-orbR * 0.35, -orbR * 0.35), orbR * 0.22, _fill);

        // Pulsating outer ring
        _stroke
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.4
          ..color = _ca(Colors.white, 0.85);
        canvas.drawCircle(Offset.zero, orbR * 1.35, _stroke);

        // Center "+1" text
        _tp.text = const TextSpan(
          text: '+1',
          style: TextStyle(
            fontFamily: 'Rajdhani',
            fontFamilyFallback: ['Segoe UI Emoji', 'Segoe UI Symbol'],
            color: Color(0xFF004D40),
            fontSize: 10,
            fontWeight: FontWeight.w900,
          ),
        );
        _tp.layout();
        _tp.paint(canvas, Offset(-_tp.width / 2, -_tp.height / 2));

        canvas.restore();
        continue;
      }

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
        _drawSteelBrick(canvas, rect, halfW, halfH);
      } else if (b.isBoss) {
        _drawBoss(canvas, b, time, halfW, halfH);
      } else {
        if (b.isDynamite) {
          _drawDynamiteBrick(canvas, b, rect, halfW, halfH);
        } else if (b.isIce) {
          _drawIceBrick(canvas, rect, rrect, halfW, halfH, c.activeIceVariant);
        } else {
          switch (c.activeBrickStyle) {
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
        }

        // Retro-Modern Crisp Pixel Art Mandate:
        // Enforce 1.5px sharp dark pixel outer contour (#0B1021) across all brick styles
        _stroke
          ..isAntiAlias = false
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5
          ..color = const Color(0xFF0B1021);
        canvas.drawRect(rect, _stroke);
        _stroke.isAntiAlias = true;

        // Organic Crystalline Damage Cracks (tactile fractures that match brick depth)
        if (b.hp < b.maxHp && b.maxHp > 1 && b.hp > 0) {
          _crackPath.reset();
          _crackPath.moveTo(halfW * 0.1, -halfH + 2);
          _crackPath.lineTo(-halfW * 0.15, -halfH * 0.3);
          _crackPath.lineTo(halfW * 0.25, halfH * 0.05);
          _crackPath.lineTo(-halfW * 0.05, halfH - 2);

          // Secondary fracture branch for more damage
          if (b.hp <= b.maxHp - 1) {
            _crackPath.moveTo(-halfW * 0.15, -halfH * 0.3);
            _crackPath.lineTo(-halfW * 0.55, -halfH * 0.1);
          }
          if (b.hp <= b.maxHp - 2) {
            _crackPath.moveTo(halfW * 0.25, halfH * 0.05);
            _crackPath.lineTo(halfW * 0.7, halfH * 0.35);
            _crackPath.moveTo(-halfW + 3, -halfH * 0.2);
            _crackPath.lineTo(-halfW * 0.4, 0);
          }

          // 1. Deep shadow underlayer giving genuine 3D crevice depth
          _stroke
            ..style = PaintingStyle.stroke
            ..color = const Color(0x99000000)
            ..strokeWidth = 2.4;
          canvas.drawPath(_crackPath, _stroke);

          // 2. High-contrast luminous glass fracture core
          _stroke
            ..color = _ca(Colors.white, 0.92)
            ..strokeWidth = 1.1;
          canvas.drawPath(_crackPath, _stroke);

          // 3. Stress impact micro-glint at primary fracture vertex
          _fill
            ..style = PaintingStyle.fill
            ..color = _ca(Colors.white, 0.95);
          canvas.drawCircle(Offset(-halfW * 0.15, -halfH * 0.3), 1.2, _fill);
        }

        if (b.isFrozen) {
          _drawFrozenOverlay(canvas, rect, rrect, halfW, halfH, c.activeIceVariant);
        }

        if (c.currentMode == GameMode.chaos) {
          _tp.text = TextSpan(
            text: '${b.hp}',
            style: const TextStyle(
              fontFamily: 'Rajdhani',
              fontFamilyFallback: ['Segoe UI Emoji', 'Segoe UI Symbol'],
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w900,
              shadows: [
                Shadow(color: Colors.black, offset: Offset(0, 1), blurRadius: 3.0),
              ],
            ),
          );
          _tp.layout();
          _tp.paint(canvas, Offset(-_tp.width / 2, -_tp.height / 2));
        }
      }

      canvas.restore();
    }
  }

  void _addChamferRect(Path path, double x, double y, double w, double h, double c) {
    path
      ..reset()
      ..moveTo(x + c, y)
      ..lineTo(x + w - c, y)
      ..lineTo(x + w, y + c)
      ..lineTo(x + w, y + h - c)
      ..lineTo(x + w - c, y + h)
      ..lineTo(x + c, y + h)
      ..lineTo(x, y + h - c)
      ..lineTo(x, y + c)
      ..close();
  }

  void _drawSteelBrick(Canvas canvas, Rect rect, double halfW, double halfH) {
    // === STİL A: Ağır Kasa Zırhı (Çapraz X-Kiriş + Krom Çerçeve + Sarı/Siyah Tehlike Bantları) ===
    final w = rect.width;
    final h = rect.height;

    // 1. 3D heavy drop shadow
    _addChamferRect(_tempPath, -halfW, -halfH + 2.6, w, h, 4.0);
    _fill
      ..style = PaintingStyle.fill
      ..shader = null
      ..color = const Color(0xFF070A0E);
    canvas.drawPath(_tempPath, _fill);

    // 2. Outer Brushed Chrome Bevel
    _addChamferRect(_tempPath, -halfW, -halfH, w, h, 4.0);
    final steelOuterKey = Object.hash('steel_a_outer', w.round(), h.round());
    _fill.shader = _brickShaders.putIfAbsent(steelOuterKey, () {
      return const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Color(0xFFECEFF1),
          Color(0xFF90A4AE),
          Color(0xFF455A64),
          Color(0xFF1C262B),
        ],
        stops: [0.0, 0.35, 0.70, 1.0],
      ).createShader(rect);
    });
    canvas.drawPath(_tempPath, _fill);
    _fill.shader = null;

    // 3. Recessed Dark Gunmetal Vault Core
    _addChamferRect(_tempPath, -halfW + 3.0, -halfH + 3.0, w - 6.0, h - 6.0, 2.5);
    _fill.color = const Color(0xFF161F24);
    canvas.drawPath(_tempPath, _fill);

    // 4. Left & Right Yellow/Black Industrial Hazard Bars
    _fill.color = const Color(0xFFFFB300);
    canvas.drawRect(Rect.fromLTWH(-halfW + 4.2, -halfH + 4.2, 4.2, h - 8.4), _fill);
    canvas.drawRect(Rect.fromLTWH(halfW - 8.4, -halfH + 4.2, 4.2, h - 8.4), _fill);
    _fill.color = const Color(0xFF161F24);
    for (double y = -halfH + 4.8; y < halfH - 4.8; y += 4.2) {
      canvas.drawRect(Rect.fromLTWH(-halfW + 4.2, y, 4.2, 1.9), _fill);
      canvas.drawRect(Rect.fromLTWH(halfW - 8.4, y, 4.2, 1.9), _fill);
    }

    // 5. Raised Steel X-Cross Bracing Girder in Center
    _stroke
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..color = const Color(0xFF10161A)
      ..strokeWidth = 3.8;
    canvas.drawLine(Offset(-halfW + 11.0, -halfH + 4.0), Offset(halfW - 11.0, halfH - 4.0), _stroke);
    canvas.drawLine(Offset(-halfW + 11.0, halfH - 4.0), Offset(halfW - 11.0, -halfH + 4.0), _stroke);

    _stroke
      ..color = const Color(0xFF90A4AE)
      ..strokeWidth = 2.1;
    canvas.drawLine(Offset(-halfW + 11.0, -halfH + 4.0), Offset(halfW - 11.0, halfH - 4.0), _stroke);
    canvas.drawLine(Offset(-halfW + 11.0, halfH - 4.0), Offset(halfW - 11.0, -halfH + 4.0), _stroke);

    // 6. Center Titanium Lock Hub
    _fill.color = const Color(0xFF263238);
    canvas.drawCircle(Offset.zero, 4.0, _fill);
    _stroke
      ..color = const Color(0xFFCFD8DC)
      ..strokeWidth = 1.1;
    canvas.drawCircle(Offset.zero, 4.0, _stroke);
    _fill.color = const Color(0xFFECEFF1);
    canvas.drawCircle(Offset.zero, 1.5, _fill);

    // 7. Top Specular Chrome Edge
    _stroke
      ..color = Colors.white
      ..strokeWidth = 1.1;
    canvas.drawLine(Offset(-halfW + 4.0, -halfH + 1.1), Offset(halfW - 4.0, -halfH + 1.1), _stroke);
  }

  void _drawFrozenDynamiteBrick(Canvas canvas, Brick b, Rect rect, double halfW, double halfH) {
    // === FROZEN TNT BRICK: Buz Tutmuş Dinamit Lokumu + Donmuş Fitil + Buz Sarkıtları + Kristal TNT Rozeti ===
    final w = rect.width;
    final h = rect.height;
    final shimmer = sin(time * 3.5) * 0.5 + 0.5;

    // 1. 3D Frost Arctic Shadow
    _fill
      ..style = PaintingStyle.fill
      ..shader = null
      ..color = const Color(0xFF031627);
    canvas.drawRRect(RRect.fromRectAndRadius(rect.translate(0, 2.5), const Radius.circular(5.5)), _fill);

    // 2. 3 Horizontal Chilled Arctic Dynamite Cylinders (Frosted Ice-Cyan / Deep Glacial Blue)
    final stickH = h / 3.0;
    for (int s = 0; s < 3; s++) {
      final sy = -halfH + s * stickH;
      final stickRect = Rect.fromLTWH(-halfW, sy + 0.3, w, stickH - 0.6);
      final stickKey = Object.hash('frozen_dyn_stick', s, w.round(), h.round());
      _fill.shader = _brickShaders.putIfAbsent(stickKey, () {
        return const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xFFE0F7FA), // Frosted rime highlight
            Color(0xFF4FC3F7), // Glacial cyan
            Color(0xFF0288D1), // Cold deep ice blue
          ],
          stops: [0.0, 0.45, 1.0],
        ).createShader(stickRect);
      });
      canvas.drawRRect(RRect.fromRectAndRadius(stickRect, const Radius.circular(3.2)), _fill);
    }
    _fill.shader = null;

    // 3. Frozen Cyan & Silver Straps
    for (final bx in [-halfW * 0.55, halfW * 0.55]) {
      _fill.color = const Color(0xFF1A3044);
      canvas.drawRect(Rect.fromLTWH(bx - 2.8, -halfH, 5.6, h), _fill);
      _fill.color = const Color(0xFF80DEEA);
      canvas.drawRect(Rect.fromLTWH(bx - 2.8, -halfH + 1.8, 5.6, 2.6), _fill);
      canvas.drawRect(Rect.fromLTWH(bx - 2.8, halfH - 4.4, 5.6, 2.6), _fill);
    }

    // 4. Center Frosted Badge
    final badgeRect = Rect.fromCenter(center: Offset.zero, width: 22.0, height: h - 4.0);
    final badgeRRect = RRect.fromRectAndRadius(badgeRect, const Radius.circular(3.8));
    _fill.color = const Color(0xFF081B2D);
    canvas.drawRRect(badgeRRect, _fill);
    _stroke
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.3
      ..color = const Color(0xFF80D8FF);
    canvas.drawRRect(badgeRRect, _stroke);

    // Cyan Frozen "TNT" vector glyph inside badge
    _stroke
      ..color = Color.lerp(const Color(0xFF00E5FF), Colors.white, shimmer)!
      ..strokeWidth = 1.4
      ..strokeCap = StrokeCap.square;
    // Left 'T'
    canvas.drawLine(const Offset(-7.2, -2.5), const Offset(-3.8, -2.5), _stroke);
    canvas.drawLine(const Offset(-5.5, -2.5), const Offset(-5.5, 2.6), _stroke);
    // Middle 'N'
    canvas.drawLine(const Offset(-1.8, 2.6), const Offset(-1.8, -2.5), _stroke);
    canvas.drawLine(const Offset(-1.8, -2.5), const Offset(1.8, 2.6), _stroke);
    canvas.drawLine(const Offset(1.8, 2.6), const Offset(1.8, -2.5), _stroke);
    // Right 'T'
    canvas.drawLine(const Offset(3.8, -2.5), const Offset(7.2, -2.5), _stroke);
    canvas.drawLine(const Offset(5.5, -2.5), const Offset(5.5, 2.6), _stroke);

    // 5. Frozen Extinguished Wick with Ice Spike on Tip (NO fire)
    _stroke
      ..color = const Color(0xFFB0BEC5)
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 1.6;
    _tempPath
      ..reset()
      ..moveTo(0, -halfH + 1.5)
      ..quadraticBezierTo(5.5, -halfH - 4.5, 11.0, -halfH - 2.5);
    canvas.drawPath(_tempPath, _stroke);

    // Ice crystal tip on fuse (sharp frozen diamond, not fire spark)
    final iceTipPos = Offset(11.0, -halfH - 2.5);
    _fill.color = const Color(0xFFE0F7FA);
    _tempPath
      ..reset()
      ..moveTo(iceTipPos.dx, iceTipPos.dy - 3.2)
      ..lineTo(iceTipPos.dx + 2.4, iceTipPos.dy)
      ..lineTo(iceTipPos.dx, iceTipPos.dy + 3.2)
      ..lineTo(iceTipPos.dx - 2.4, iceTipPos.dy)
      ..close();
    canvas.drawPath(_tempPath, _fill);
    _fill.color = Colors.white;
    canvas.drawCircle(iceTipPos, 1.2, _fill);

    // 6. Hanging Icicles from bottom edge
    _fill.color = const Color(0xCCB3E5FC);
    _tempPath
      ..reset()
      ..moveTo(-halfW + 4, halfH)
      ..lineTo(-halfW + 7, halfH + 4.5)
      ..lineTo(-halfW + 10, halfH)
      ..moveTo(halfW - 10, halfH)
      ..lineTo(halfW - 7, halfH + 5.0)
      ..lineTo(halfW - 4, halfH)
      ..close();
    canvas.drawPath(_tempPath, _fill);
  }

  void _drawDynamiteBrick(Canvas canvas, Brick b, Rect rect, double halfW, double halfH) {
    if (b.isFrozen) {
      _drawFrozenDynamiteBrick(canvas, b, rect, halfW, halfH);
      return;
    }
    // === STİL A: Üçlü Bağlanmış Kırmızı Dinamit Lokumu + Sarı/Siyah Kemer + TNT Rozeti + Kıvılcımlı Fitil ===
    final w = rect.width;
    final h = rect.height;
    final pulse = sin(time * 10.0) * 0.5 + 0.5;

    // 1. 3D Drop Shadow
    _fill
      ..style = PaintingStyle.fill
      ..shader = null
      ..color = const Color(0xFF240404);
    canvas.drawRRect(RRect.fromRectAndRadius(rect.translate(0, 2.5), const Radius.circular(5.5)), _fill);

    // 2. 3 Horizontal Crimson Dynamite Cylinders
    final stickH = h / 3.0;
    for (int s = 0; s < 3; s++) {
      final sy = -halfH + s * stickH;
      final stickRect = Rect.fromLTWH(-halfW, sy + 0.3, w, stickH - 0.6);
      final stickKey = Object.hash('dyn_stick', s, w.round(), h.round());
      _fill.shader = _brickShaders.putIfAbsent(stickKey, () {
        return const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xFFFF5252),
            Color(0xFFD50000),
            Color(0xFF7F0000),
          ],
          stops: [0.0, 0.45, 1.0],
        ).createShader(stickRect);
      });
      canvas.drawRRect(RRect.fromRectAndRadius(stickRect, const Radius.circular(3.2)), _fill);
    }
    _fill.shader = null;

    // 3. Vertical Black & Yellow Binding Straps on Left and Right
    for (final bx in [-halfW * 0.55, halfW * 0.55]) {
      _fill.color = const Color(0xFF1A1A1A);
      canvas.drawRect(Rect.fromLTWH(bx - 2.8, -halfH, 5.6, h), _fill);
      _fill.color = const Color(0xFFFFD600);
      canvas.drawRect(Rect.fromLTWH(bx - 2.8, -halfH + 1.8, 5.6, 2.6), _fill);
      canvas.drawRect(Rect.fromLTWH(bx - 2.8, halfH - 4.4, 5.6, 2.6), _fill);
    }

    // 4. Center Glowing Detonator Core Badge
    final badgeRect = Rect.fromCenter(center: Offset.zero, width: 22.0, height: h - 4.0);
    final badgeRRect = RRect.fromRectAndRadius(badgeRect, const Radius.circular(3.8));
    _fill.color = const Color(0xFF140404);
    canvas.drawRRect(badgeRRect, _fill);
    _stroke
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.3
      ..color = pulse > 0.5 ? const Color(0xFFFFD600) : const Color(0xFFFF3D00);
    canvas.drawRRect(badgeRRect, _stroke);

    // Crisp vector "TNT" micro-glyph inside badge
    _stroke
      ..color = pulse > 0.5 ? const Color(0xFFFFEA00) : const Color(0xFFFF1744)
      ..strokeWidth = 1.4
      ..strokeCap = StrokeCap.square;
    // Left 'T' canvas.drawLine(const Offset(-7.2, -2.5), const Offset(-3.8, -2.5), _stroke);
    canvas.drawLine(const Offset(-5.5, -2.5), const Offset(-5.5, 2.6), _stroke);
    // Middle 'N' canvas.drawLine(const Offset(-1.8, 2.6), const Offset(-1.8, -2.5), _stroke);
    canvas.drawLine(const Offset(-1.8, -2.5), const Offset(1.8, 2.6), _stroke);
    canvas.drawLine(const Offset(1.8, 2.6), const Offset(1.8, -2.5), _stroke);
    // Right 'T' canvas.drawLine(const Offset(3.8, -2.5), const Offset(7.2, -2.5), _stroke);
    canvas.drawLine(const Offset(5.5, -2.5), const Offset(5.5, 2.6), _stroke);

    // 5. Sizzling Fuse & Star Spark on Right/Top
    _stroke
      ..color = const Color(0xFFD7CCC8)
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 1.6;
    _tempPath
      ..reset()
      ..moveTo(0, -halfH + 1.5)
      ..quadraticBezierTo(5.5, -halfH - 4.5, 11.0, -halfH - 2.5);
    canvas.drawPath(_tempPath, _stroke);

    final sparkPos = Offset(11.0, -halfH - 2.5);
    _fill.color = const Color(0xFFFF6D00);
    canvas.drawCircle(sparkPos, 2.8 + pulse * 1.3, _fill);
    _fill.color = const Color(0xFFFFFF00);
    canvas.drawCircle(sparkPos, 1.8, _fill);
    _fill.color = Colors.white;
    canvas.drawCircle(sparkPos, 0.9, _fill);
  }

  void _drawCornerFrost(Canvas canvas, double w, double h, double halfW, double halfH, double lengthScale) {
    _stroke
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 1.3
      ..color = const Color(0xEBFFFFFF);

    final l1 = w * 0.22 * lengthScale;
    final l2 = w * 0.15 * lengthScale;
    const corners = [
      [-1.0, -1.0, 1.0, 1.0],
      [1.0, -1.0, -1.0, 1.0],
      [-1.0, 1.0, 1.0, -1.0],
      [1.0, 1.0, -1.0, -1.0],
    ];
    for (final c in corners) {
      final cx = c[0] * (halfW - 2.2);
      final cy = c[1] * (halfH - 2.2);
      final dx = c[2];
      final dy = c[3];
      // Horizontal-ish spike
      canvas.drawLine(Offset(cx, cy), Offset(cx + dx * l1, cy + dy * (h * 0.14)), _stroke);
      // Diagonal main spike towards center
      canvas.drawLine(Offset(cx, cy), Offset(cx + dx * l2, cy + dy * (h * 0.36 * lengthScale)), _stroke);
      // Side barb on diagonal spike
      canvas.drawLine(
        Offset(cx + dx * (l2 * 0.55), cy + dy * (h * 0.20 * lengthScale)),
        Offset(cx + dx * (l2 * 0.95), cy + dy * (h * 0.12 * lengthScale)),
        _stroke,
      );
      // Vertical-ish spike
      canvas.drawLine(Offset(cx, cy), Offset(cx + dx * (w * 0.06), cy + dy * (h * 0.40 * lengthScale)), _stroke);
    }
  }

  void _drawIceBrick(Canvas canvas, Rect rect, RRect rrect, double halfW, double halfH, int variant) {
    // === STİL 3 (3A / 3B / 3C / 3D): Crisp Pixel Art Arctic Ice Block ===
    _fill.isAntiAlias = false;
    _stroke.isAntiAlias = false;
    final w = rect.width;
    final h = rect.height;

    // 1. Pixel-stepped Arctic Drop Shadow
    _fill
      ..style = PaintingStyle.fill
      ..shader = null
      ..color = const Color(0xFF0B1021);
    canvas.drawRect(rect.translate(2.0, 2.5), _fill);

    // 2. Stepped Frozen Arctic Pixel Ramp (3 distinct tone bands, no blurry gradient)
    _fill.color = const Color(0xFF005B8E);
    canvas.drawRect(rect, _fill);
    _fill.color = const Color(0xFF1AD1FF);
    canvas.drawRect(Rect.fromLTWH(-halfW + 1.5, -halfH + 1.5, w - 3.0, h - 4.0), _fill);
    _fill.color = const Color(0xFFB8F2FF);
    canvas.drawRect(Rect.fromLTWH(-halfW + 2.0, -halfH + 1.5, w - 4.0, h * 0.42), _fill);

    // Top-left 2px pure white pixel highlight
    _fill.color = Colors.white;
    canvas.drawRect(Rect.fromLTWH(-halfW + 2.0, -halfH + 2.0, w - 5.0, 2.0), _fill);
    canvas.drawRect(Rect.fromLTWH(-halfW + 2.0, -halfH + 2.0, 2.0, h - 5.0), _fill);

    // Stepped pixel diagonal frost glint
    _fill.color = const Color(0xD9FFFFFF);
    for (int step = 0; step < 4; step++) {
      final px = -halfW + 6.0 + step * 3.0;
      final py = -halfH + 3.5 + step * 2.2;
      if (px + 4.0 < halfW - 3.0 && py + 2.2 < halfH - 3.0) {
        canvas.drawRect(Rect.fromLTWH(px, py, 3.5, 2.2), _fill);
      }
    }

    // Variant pixel details (icicles / crystal core / snowcap / corner pixel teeth)
    final v = variant % 4;
    if (v == 0) {
      _fill.color = const Color(0xFFF0FCFF);
      for (int i = 0; i < 5; i++) {
        final ix = -halfW + 3.0 + i * ((w - 8.0) / 4.0);
        final ih = (i.isEven ? h * 0.36 : h * 0.22);
        canvas.drawRect(Rect.fromLTWH(ix, -halfH + 1.5, 2.2, ih), _fill);
      }
    } else if (v == 1) {
      _fill.color = Colors.white;
      canvas.drawRect(Rect.fromCenter(center: Offset.zero, width: 6.0, height: 2.0), _fill);
      canvas.drawRect(Rect.fromCenter(center: Offset.zero, width: 2.0, height: 6.0), _fill);
    } else if (v == 2) {
      _fill.color = const Color(0xFFF8FEFF);
      canvas.drawRect(Rect.fromLTWH(-halfW + 1.5, -halfH + 1.5, w - 3.0, 3.8), _fill);
      canvas.drawRect(Rect.fromLTWH(-halfW + 4.0, -halfH + 5.3, w * 0.35, 2.0), _fill);
    } else {
      _fill.color = Colors.white;
      canvas.drawRect(Rect.fromLTWH(-halfW + 2.0, -halfH + 2.0, 4.0, 4.0), _fill);
      canvas.drawRect(Rect.fromLTWH(halfW - 6.0, -halfH + 2.0, 4.0, 4.0), _fill);
      canvas.drawRect(Rect.fromLTWH(-halfW + 2.0, halfH - 6.0, 4.0, 4.0), _fill);
      canvas.drawRect(Rect.fromLTWH(halfW - 6.0, halfH - 6.0, 4.0, 4.0), _fill);
    }

    _stroke
      ..style = PaintingStyle.stroke
      ..color = const Color(0xFF0B1021)
      ..strokeWidth = 1.6;
    canvas.drawRect(rect, _stroke);
    _fill.isAntiAlias = true;
    _stroke.isAntiAlias = true;
  }

  void _drawFrozenOverlay(Canvas canvas, Rect rect, RRect rrect, double halfW, double halfH, int variant) {
    // === STİL 3 (3A / 3B / 3C / 3D) FROZEN NEIGHBOR OVERLAY ===
    final w = rect.width;
    final h = rect.height;
    final v = variant % 4;

    // 1. Translucent Ice Encasement Coat
    final frozenCoatKey = Object.hash('frozen_coat_3', w.round(), h.round());
    _fill
      ..style = PaintingStyle.fill
      ..shader = _brickShaders.putIfAbsent(frozenCoatKey, () {
        return const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xC7E0F7FA),
            Color(0x7A00E5FF),
            Color(0xAD0091EA),
          ],
          stops: [0.0, 0.5, 1.0],
        ).createShader(rect);
      });
    canvas.drawRRect(rrect, _fill);
    _fill.shader = null;

    // 2. Variant-specific frost details on frozen neighbor bricks
    canvas.save();
    canvas.clipRRect(rrect.deflate(1.0));
    if (v == 0) {
      // 3A icicle fringe
      _tempPath
        ..reset()
        ..moveTo(-halfW, -halfH);
      const icicles = [
        [0.10, 0.42], [0.22, 0.20], [0.35, 0.50], [0.50, 0.22],
        [0.65, 0.48], [0.80, 0.20], [0.90, 0.42], [1.0, 0.25],
      ];
      for (final pt in icicles) {
        _tempPath.lineTo(-halfW + w * pt[0], -halfH + h * pt[1]);
      }
      _tempPath
        ..lineTo(halfW, -halfH)
        ..close();
      _fill.color = const Color(0xE0FFFFFF);
      canvas.drawPath(_tempPath, _fill);
    } else if (v == 1) {
      // 3B deep fracture line
      _stroke
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2
        ..color = const Color(0xD9FFFFFF);
      _tempPath
        ..reset()
        ..moveTo(-halfW + w * 0.10, -halfH + h * 0.70)
        ..lineTo(-halfW + w * 0.40, -halfH + h * 0.35)
        ..lineTo(-halfW + w * 0.70, -halfH + h * 0.60)
        ..lineTo(-halfW + w * 0.90, -halfH + h * 0.25);
      canvas.drawPath(_tempPath, _stroke);
    } else if (v == 2) {
      // 3C snowcap crust
      _tempPath
        ..reset()
        ..moveTo(-halfW, -halfH + h * 0.42)
        ..quadraticBezierTo(-halfW + w * 0.25, -halfH + h * 0.18, -halfW + w * 0.50, -halfH + h * 0.28)
        ..quadraticBezierTo(-halfW + w * 0.75, -halfH + h * 0.16, halfW, -halfH + h * 0.40)
        ..lineTo(halfW, -halfH)
        ..lineTo(-halfW, -halfH)
        ..close();
      _fill.color = const Color(0xE6FFFFFF);
      canvas.drawPath(_tempPath, _fill);
    } else {
      // 3D corner crystal triangles
      _fill.color = const Color(0xB8FFFFFF);
      const tris = [
        [[0.0, 0.0], [0.24, 0.0], [0.0, 0.42]],
        [[1.0, 0.0], [0.76, 0.0], [1.0, 0.42]],
        [[0.0, 1.0], [0.24, 1.0], [0.0, 0.58]],
        [[1.0, 1.0], [0.76, 1.0], [1.0, 0.58]],
      ];
      for (final pts in tris) {
        _tempPath
          ..reset()
          ..moveTo(-halfW + w * pts[0][0], -halfH + h * pts[0][1])
          ..lineTo(-halfW + w * pts[1][0], -halfH + h * pts[1][1])
          ..lineTo(-halfW + w * pts[2][0], -halfH + h * pts[2][1])
          ..close();
        canvas.drawPath(_tempPath, _fill);
      }
    }
    canvas.restore();

    _drawCornerFrost(canvas, w, h, halfW, halfH, 0.95);

    _stroke
      ..style = PaintingStyle.stroke
      ..color = Colors.white
      ..strokeWidth = 1.6;
    canvas.drawRRect(rrect, _stroke);
  }

  void _drawNeonBrick(Canvas canvas, Brick b, RRect rrect) {
    // === 1. "NEON TABELA": Crisp Pixel Art Arcade Neon Tube Block ===
    _fill.isAntiAlias = false;
    _stroke.isAntiAlias = false;
    final base = b.color;
    final rect = rrect.outerRect;
    final halfW = rect.width / 2;

    // 1. Stepped dark arcade pixel drop shadow
    _fill
      ..style = PaintingStyle.fill
      ..shader = null
      ..color = const Color(0xFF0B1021);
    canvas.drawRect(rect.translate(2.0, 2.5), _fill);

    // 2. Stepped dark obsidian pixel housing (2-step pixel ramp, no radial gradient)
    final deepEdge = Color.lerp(base, const Color(0xFF050811), 0.88)!;
    final centerGlow = Color.lerp(base, const Color(0xFF0A1020), 0.62)!;
    _fill.color = deepEdge;
    canvas.drawRect(rect, _fill);
    _fill.color = centerGlow;
    canvas.drawRect(rect.deflate(2.5), _fill);

    // 3. Left & right pixel metal electrode brackets
    _fill.color = const Color(0xFF263238);
    canvas.drawRect(Rect.fromCenter(center: Offset(-halfW + 3.0, 0), width: 3.0, height: 6.0), _fill);
    canvas.drawRect(Rect.fromCenter(center: Offset(halfW - 3.0, 0), width: 3.0, height: 6.0), _fill);

    // 4. Stepped Pixel Neon Phosphor Tube Frame + White Pixel Core
    final flicker = 0.95 + 0.05 * sin(time * 16.0 + halfW);
    final tubeRect = rect.deflate(2.0);
    _stroke
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0
      ..color = _ca(base, 0.45 * flicker);
    canvas.drawRect(tubeRect, _stroke);

    _stroke
      ..strokeWidth = 1.8
      ..color = _ca(base, 0.98 * flicker);
    canvas.drawRect(tubeRect, _stroke);

    _stroke
      ..strokeWidth = 1.0
      ..color = _ca(Colors.white, 0.94 * flicker);
    canvas.drawRect(tubeRect, _stroke);

    // 5. Inner pixel neon filament bar
    final innerBar = Rect.fromCenter(center: Offset.zero, width: rect.width - 14.0, height: rect.height - 10.0);
    _stroke
      ..strokeWidth = 1.2
      ..color = _ca(base, 0.80 * flicker);
    canvas.drawRect(innerBar, _stroke);

    _fill.isAntiAlias = true;
    _stroke.isAntiAlias = true;
  }

  void _drawGlossBrick(Canvas canvas, Brick b, Rect rect, RRect rrect, double halfW, double halfH) {
    // === 2. "SİBER KRİSTAL": Crisp Pixel Art 5-Facet Cut Gemstone Block ===
    _fill.isAntiAlias = false;
    _stroke.isAntiAlias = false;
    final dark = Color.lerp(b.color, const Color(0xFF0B1021), 0.65)!;
    final bright = Color.lerp(b.color, Colors.white, 0.45)!;
    final ultraBright = Color.lerp(b.color, Colors.white, 0.78)!;

    // 1. Stepped pixel drop shadow
    _fill
      ..style = PaintingStyle.fill
      ..shader = null
      ..color = const Color(0xFF0B1021);
    canvas.drawRect(rect.translate(2.0, 2.5), _fill);

    // 2. Stepped 5-Facet Pixel Gemstone Body (no smooth gradients)
    const insetX = 5.5;
    const insetY = 4.0;
    _fill.color = b.color;
    canvas.drawRect(rect, _fill);

    // Top Crown Facet (lightest pixel ramp)
    _fill.color = ultraBright;
    canvas.drawRect(Rect.fromLTRB(-halfW + 1.5, -halfH + 1.5, halfW - 1.5, -halfH + insetY), _fill);

    // Left Facet (mid-bright pixel ramp)
    _fill.color = bright;
    canvas.drawRect(Rect.fromLTRB(-halfW + 1.5, -halfH + insetY, -halfW + insetX, halfH - insetY), _fill);

    // Right & Bottom Facets (shadow pixel ramp)
    _fill.color = dark;
    canvas.drawRect(Rect.fromLTRB(halfW - insetX, -halfH + insetY, halfW - 1.5, halfH - 1.5), _fill);
    canvas.drawRect(Rect.fromLTRB(-halfW + 1.5, halfH - insetY, halfW - 1.5, halfH - 1.5), _fill);

    // Central Raised Pixel Jewel Table
    final tableRect = Rect.fromLTRB(-halfW + insetX, -halfH + insetY, halfW - insetX, halfH - insetY);
    _fill.color = b.color;
    canvas.drawRect(tableRect, _fill);
    _fill.color = bright;
    canvas.drawRect(Rect.fromLTRB(tableRect.left, tableRect.top, tableRect.right, tableRect.top + 2.0), _fill);

    // Crisp 1px pixel facet ridge frame
    _stroke
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0
      ..color = Colors.white.withValues(alpha: 0.75);
    canvas.drawRect(tableRect, _stroke);

    // Crisp 2x2 white pixel glint at top-left facet vertex
    _fill.color = Colors.white;
    canvas.drawRect(Rect.fromLTWH(-halfW + insetX + 1.0, -halfH + insetY + 1.0, 2.5, 2.5), _fill);

    _fill.isAntiAlias = true;
    _stroke.isAntiAlias = true;
  }

  void _drawNeuBrick(Canvas canvas, Brick b, RRect rrect) {
    // === 3. "RETRO KASET / BLOK": Crisp Stepped Pixel Bevel Block (Replaces Non-Pixel Jelly Pillow) ===
    _fill.isAntiAlias = false;
    _stroke.isAntiAlias = false;
    final base = b.color;
    final rect = rrect.outerRect;
    final halfW = rect.width / 2;
    final halfH = rect.height / 2;

    final light = Color.lerp(base, Colors.white, 0.52)!;
    final dark = Color.lerp(base, const Color(0xFF0B1021), 0.55)!;
    final deepDark = Color.lerp(base, const Color(0xFF0B1021), 0.78)!;

    // 1. Stepped pixel drop shadow
    _fill
      ..style = PaintingStyle.fill
      ..shader = null
      ..color = const Color(0xFF0B1021);
    canvas.drawRect(rect.translate(2.0, 2.5), _fill);

    // 2. Stepped 3-Band Pixel Cushion Body (Zero RadialGradient, Zero Round Pillow)
    _fill.color = deepDark;
    canvas.drawRect(rect, _fill);

    _fill.color = dark;
    canvas.drawRect(rect.deflate(1.5), _fill);

    _fill.color = base;
    canvas.drawRect(Rect.fromLTRB(-halfW + 2.5, -halfH + 2.5, halfW - 3.0, halfH - 3.5), _fill);

    // 3. Stepped Pixel Top-Left Highlight Bar
    _fill.color = light;
    canvas.drawRect(Rect.fromLTWH(-halfW + 3.5, -halfH + 3.0, rect.width - 9.0, 2.5), _fill);
    _fill.color = Colors.white;
    canvas.drawRect(Rect.fromLTWH(-halfW + 4.5, -halfH + 3.5, 5.0, 2.0), _fill);
    canvas.drawRect(Rect.fromLTWH(halfW - 7.5, -halfH + 3.5, 2.2, 2.0), _fill);

    _fill.isAntiAlias = true;
    _stroke.isAntiAlias = true;
  }

  void _drawPixelBrick(Canvas canvas, Brick b, Rect rect, double halfW, double halfH) {
    // === 4. "8-BİT PİKSEL": Authentic 16-Bit SNES Arcade Treasure Block ===
    _fill.isAntiAlias = false;
    _stroke.isAntiAlias = false;

    final light = Color.lerp(b.color, Colors.white, 0.58)!;
    final midLight = Color.lerp(b.color, Colors.white, 0.25)!;
    final dark = Color.lerp(b.color, Colors.black, 0.52)!;
    final deepDark = Color.lerp(b.color, Colors.black, 0.75)!;

    // 1. Pixel-stepped 3D drop shadow
    _fill
      ..style = PaintingStyle.fill
      ..shader = null
      ..color = const Color(0xAA000000);
    canvas.drawRect(rect.translate(2.0, 2.5), _fill);

    // 2. Crisp 2px jet-black pixel outer frame with notched arcade corners
    _fill.color = const Color(0xFF050508);
    canvas.drawRect(rect, _fill);

    // 3. Deep shadow inner border (bottom & right stepped bevel)
    _fill.color = deepDark;
    canvas.drawRect(rect.deflate(1.8), _fill);

    // 4. Main vibrant 16-bit body
    _fill.color = b.color;
    canvas.drawRect(Rect.fromLTRB(-halfW + 3.6, -halfH + 3.6, halfW - 3.6, halfH - 3.6), _fill);

    // 5. Stepped 16-Bit Top & Left Highlight Bevels
    _fill.color = light;
    canvas.drawRect(Rect.fromLTWH(-halfW + 2.0, -halfH + 2.0, b.width - 5.6, 2.2), _fill);
    canvas.drawRect(Rect.fromLTWH(-halfW + 2.0, -halfH + 2.0, 2.2, b.height - 5.6), _fill);

    // Bottom & Right Shadow Bevels
    _fill.color = dark;
    canvas.drawRect(Rect.fromLTWH(-halfW + 3.6, halfH - 4.2, b.width - 5.6, 2.2), _fill);
    canvas.drawRect(Rect.fromLTWH(halfW - 4.2, -halfH + 3.6, 2.2, b.height - 5.6), _fill);

    // 6. Diagonal 8-Bit Pixel Sheen Stripe across the block face
    _fill.color = midLight;
    for (int step = 0; step < 4; step++) {
      final px = -halfW + 8.0 + step * 3.0;
      final py = -halfH + 4.2 + step * 2.4;
      if (px + 4.0 < halfW - 5.0 && py + 2.4 < halfH - 4.5) {
        canvas.drawRect(Rect.fromLTWH(px, py, 4.5, 2.4), _fill);
      }
    }

    // 7. Crisp White Pixel Specular Glint (top-left) + 4 Retro Corner Rivet Pixels
    _fill.color = Colors.white;
    canvas.drawRect(Rect.fromLTWH(-halfW + 4.5, -halfH + 4.5, 3.0, 3.0), _fill);

    _fill.color = deepDark;
    canvas.drawRect(Rect.fromLTWH(halfW - 6.8, -halfH + 4.5, 2.2, 2.2), _fill);
    canvas.drawRect(Rect.fromLTWH(-halfW + 4.5, halfH - 6.8, 2.2, 2.2), _fill);
    canvas.drawRect(Rect.fromLTWH(halfW - 6.8, halfH - 6.8, 2.2, 2.2), _fill);

    _fill.isAntiAlias = true;
    _stroke.isAntiAlias = true;
  }

  void _drawCyberBrick(Canvas canvas, Brick b, RRect rrect, double halfW, double halfH) {
    // === 5. "SİBERPUNK 2099": Crisp Pixel Art Mecha Reactor Block ===
    _fill.isAntiAlias = false;
    _stroke.isAntiAlias = false;
    final base = b.color;
    final rect = rrect.outerRect;
    final w = rect.width;
    final h = rect.height;
    final light = Color.lerp(base, Colors.white, 0.50)!;
    final pulse = 0.75 + 0.25 * sin(time * 7.0);

    // 1. Stepped Pixel Drop Shadow
    _fill
      ..style = PaintingStyle.fill
      ..shader = null
      ..color = const Color(0xFF0B1021);
    canvas.drawRect(rect.translate(2.0, 2.5), _fill);

    // 2. Stepped Gunmetal Pixel Armor Plates (No smooth LinearGradient)
    _fill.color = const Color(0xFF070B14);
    canvas.drawRect(rect, _fill);
    _fill.color = const Color(0xFF141E30);
    canvas.drawRect(rect.deflate(1.8), _fill);
    _fill.color = Color.lerp(base, const Color(0xFF1C2638), 0.60)!;
    canvas.drawRect(Rect.fromLTWH(-halfW + 2.0, -halfH + 2.0, w - 4.0, h * 0.42), _fill);

    // 3. Crisp Pixel Side Plasma Vents
    _fill.color = _ca(light, 0.90 * pulse);
    for (int v = 0; v < 2; v++) {
      final lx = -halfW + 4.5 + v * 3.6;
      canvas.drawRect(Rect.fromLTWH(lx, -halfH + 4.0, 2.0, h - 8.0), _fill);
      final rx = halfW - 6.5 - v * 3.6;
      canvas.drawRect(Rect.fromLTWH(rx, -halfH + 4.0, 2.0, h - 8.0), _fill);
    }

    // 4. Central Pixel Reactor Core Window
    final cw = (w * 0.25).clamp(9.0, 13.0);
    final ch = halfH - 3.0;
    final coreRect = Rect.fromCenter(center: Offset.zero, width: cw * 2, height: ch * 2);
    _fill.color = base;
    canvas.drawRect(coreRect, _fill);
    _fill.color = light;
    canvas.drawRect(coreRect.deflate(2.0), _fill);
    _fill.color = Colors.white;
    canvas.drawRect(coreRect.deflate(4.0), _fill);

    _stroke
      ..style = PaintingStyle.stroke
      ..color = const Color(0xFF0B1021)
      ..strokeWidth = 1.4;
    canvas.drawRect(coreRect, _stroke);

    // 5. Scanning horizontal pixel laser line inside reactor
    final scanY = (sin(time * 5.0) * (ch - 2.2)).roundToDouble();
    _fill.color = Colors.white;
    canvas.drawRect(Rect.fromLTRB(-cw + 2.0, scanY - 0.8, cw - 2.0, scanY + 0.8), _fill);

    // 6. Top & Bottom tactical pixel HUD notches
    _fill.color = base;
    canvas.drawRect(Rect.fromLTWH(-7.5, -halfH, 15.0, 2.0), _fill);
    canvas.drawRect(Rect.fromLTWH(-7.5, halfH - 2.0, 15.0, 2.0), _fill);

    _fill.isAntiAlias = true;
    _stroke.isAntiAlias = true;
  }

  void _drawCosmicBrick(Canvas canvas, Brick b, RRect rrect, double halfW, double halfH) {
    // === 6. "KOZMİK KRİSTAL": Crisp Pixel Art Astral Nebula & Star Block ===
    _fill.isAntiAlias = false;
    _stroke.isAntiAlias = false;
    final base = b.color;
    final rect = rrect.outerRect;
    const deepVoid = Color(0xFF070114);
    const abyss = Color(0xFF130429);
    final magenta = Color.lerp(base, const Color(0xFFE040FB), 0.55)!;
    final cyan = Color.lerp(base, const Color(0xFF00E5FF), 0.55)!;
    final violet = Color.lerp(base, const Color(0xFF7C4DFF), 0.60)!;

    // 1. Stepped astral void pixel drop shadow
    _fill
      ..style = PaintingStyle.fill
      ..shader = null
      ..color = const Color(0xFF0B1021);
    canvas.drawRect(rect.translate(2.0, 2.5), _fill);

    // 2. Stepped Deep Space Pixel Bands (Zero Radial/Linear Gradients)
    _fill.color = deepVoid;
    canvas.drawRect(rect, _fill);
    _fill.color = abyss;
    canvas.drawRect(rect.deflate(2.0), _fill);

    // Stepped diagonal pixel nebula clusters
    _fill.color = violet;
    canvas.drawRect(Rect.fromLTWH(-halfW + 3.0, -halfH + 3.0, rect.width * 0.55, rect.height * 0.50), _fill);
    _fill.color = magenta;
    canvas.drawRect(Rect.fromLTWH(-halfW + 5.0, -halfH + 4.0, rect.width * 0.35, rect.height * 0.35), _fill);
    _fill.color = cyan;
    canvas.drawRect(Rect.fromLTWH(0, 0, halfW - 3.0, halfH - 3.0), _fill);

    // 3. Crisp Pixel Cross-Star & Micro-Pixel Stars
    final majorTwinkle = 0.78 + 0.22 * sin(time * 3.5);
    _fill.color = Colors.white.withValues(alpha: majorTwinkle);
    final sx = (-halfW * 0.22).roundToDouble();
    final sy = (-halfH * 0.18).roundToDouble();
    canvas.drawRect(Rect.fromCenter(center: Offset(sx, sy), width: 6.0, height: 2.0), _fill);
    canvas.drawRect(Rect.fromCenter(center: Offset(sx, sy), width: 2.0, height: 6.0), _fill);
    canvas.drawRect(Rect.fromLTWH(halfW * 0.32, halfH * 0.20, 2.2, 2.2), _fill);
    canvas.drawRect(Rect.fromLTWH(-halfW * 0.55, halfH * 0.28, 2.0, 2.0), _fill);

    // 4. Inner Pixel Gem Table Frame & Stepped Top Highlight
    final innerW = halfW * 1.25;
    final innerH = halfH * 1.15;
    _stroke
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..color = Colors.white.withValues(alpha: 0.70);
    canvas.drawRect(Rect.fromCenter(center: Offset.zero, width: innerW, height: innerH), _stroke);

    // Outer stepped cyan/magenta pixel rim inside the #0B1021 outline
    _stroke
      ..strokeWidth = 1.5
      ..color = cyan;
    canvas.drawRect(rect.deflate(1.5), _stroke);

    _fill.isAntiAlias = true;
    _stroke.isAntiAlias = true;
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

    // 4. Dual Plasma Cannons on Gun Mounts (with Pre-fire Telegraphing Flash)
    final isTelegraphing = b.shootTimer <= 0.6;
    final cannonMuzzleColor = isTelegraphing
        ? (sin(time * 24.0) > 0 ? const Color(0xFFFFEB3B) : const Color(0xFFFF1744))
        : const Color(0xFFFF1744);
    final muzzleRadius = isTelegraphing ? 5.0 : 3.0;

    _fill.color = const Color(0xFF37474F);
    // Left Cannon
    canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromCenter(center: Offset(-halfW * 0.5, halfH + 4), width: 10, height: 12), const Radius.circular(2)), _fill);
    _fill.color = _ca(cannonMuzzleColor, isTelegraphing ? 1.0 : (0.75 + sin(time * 8.0) * 0.25));
    canvas.drawCircle(Offset(-halfW * 0.5, halfH + 9), muzzleRadius, _fill);
    if (isTelegraphing) {
      _fill.color = _ca(Colors.white, 0.85);
      canvas.drawCircle(Offset(-halfW * 0.5, halfH + 9), 2.2, _fill);
    }

    // Right Cannon
    _fill.color = const Color(0xFF37474F);
    canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromCenter(center: Offset(halfW * 0.5, halfH + 4), width: 10, height: 12), const Radius.circular(2)), _fill);
    _fill.color = _ca(cannonMuzzleColor, isTelegraphing ? 1.0 : (0.75 + sin(time * 8.0) * 0.25));
    canvas.drawCircle(Offset(halfW * 0.5, halfH + 9), muzzleRadius, _fill);
    if (isTelegraphing) {
      _fill.color = _ca(Colors.white, 0.85);
      canvas.drawCircle(Offset(halfW * 0.5, halfH + 9), 2.2, _fill);
    }

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

    // 7. Outer Pulsing Shield / Forcefield & Enrage Aura
    if (b.isEnraged) {
      final enragePulse = (sin(time * 18.0) * 0.5 + 0.5);
      _stroke
        ..color = _ca(const Color(0xFFFF1744), 0.75 + enragePulse * 0.25)
        ..strokeWidth = 3.5;
      canvas.drawRRect(hullRRect.inflate(2.5 + enragePulse * 3.0), _stroke);
    } else {
      final shieldPulse = sin(time * 4.0) * 0.2 + 0.8;
      _stroke
        ..color = _ca(const Color(0xFFFF1744), 0.35 * shieldPulse)
        ..strokeWidth = 2.0;
      canvas.drawRRect(hullRRect, _stroke);
    }

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

    // 9. Boss Critical Damage: Electric Crack Arcs & Smoke Flicker (When HP < 55%)
    if (hpPct < 0.55) {
      final crackCycle = (time * 16.0).floor();
      final rSeed = (crackCycle % 7);
      _stroke
        ..color = _ca(rSeed % 2 == 0 ? const Color(0xFF00E5FF) : const Color(0xFFFF5252), 0.85)
        ..strokeWidth = 1.6;

      // Arc 1
      _tempPath
        ..reset()
        ..moveTo(-halfW * 0.4, -halfH * 0.2)
        ..lineTo(-halfW * 0.15 + (rSeed * 2.0 - 6.0), 2.0)
        ..lineTo(-halfW * 0.35, halfH * 0.4);
      canvas.drawPath(_tempPath, _stroke);

      // Arc 2
      _tempPath
        ..reset()
        ..moveTo(halfW * 0.3, -halfH * 0.3)
        ..lineTo(halfW * 0.1 - (rSeed * 2.0 - 5.0), 0.0)
        ..lineTo(halfW * 0.45, halfH * 0.3);
      canvas.drawPath(_tempPath, _stroke);

      // Central core electrical spark pip
      _fill.color = Colors.white;
      canvas.drawCircle(Offset((rSeed - 3) * 4.0, (rSeed % 3 - 1) * 3.0), 1.8, _fill);
    }
  }

  void _drawPlayfieldBorder(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    const ceilingY = 36.0;

    // 1. Edge Vignette Gradients: Left, Right, and Top subtle shadow fades (cached shaders)
    final hKey = h.round();
    final wKey = w.round();

    // Left edge shadow (8px)
    _fill
      ..shader = _bgShaders.putIfAbsent(
        Object.hash('border_left', hKey),
        () => const LinearGradient(
          colors: [Color(0x99000000), Colors.transparent],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ).createShader(Rect.fromLTWH(0, 0, 10, h)),
      )
      ..color = Colors.black;
    canvas.drawRect(Rect.fromLTWH(0, 0, 10, h), _fill);

    // Right edge shadow (8px)
    _fill.shader = _bgShaders.putIfAbsent(
      Object.hash('border_right', wKey, hKey),
      () => const LinearGradient(
        colors: [Colors.transparent, Color(0x99000000)],
        begin: Alignment.centerLeft,
        end: Alignment.centerRight,
      ).createShader(Rect.fromLTWH(w - 10, 0, 10, h)),
    );
    canvas.drawRect(Rect.fromLTWH(w - 10, 0, 10, h), _fill);

    // Top ceiling shadow (12px)
    _fill.shader = _bgShaders.putIfAbsent(
      Object.hash('border_top', wKey),
      () => const LinearGradient(
        colors: [Color(0xBB000000), Colors.transparent],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      ).createShader(Rect.fromLTWH(0, 0, w, ceilingY + 12)),
    );
    canvas.drawRect(Rect.fromLTWH(0, 0, w, ceilingY + 12), _fill);
    _fill.shader = null;

    // 2. Playfield Border Frame Line (Left, Top Ceiling, Right)
    final glowColor = c.activePaddleSkin.glowColor;
    _stroke
      ..shader = null
      ..color = _ca(glowColor, 0.22)
      ..strokeWidth = 2.0;

    // Ceiling bar line
    canvas.drawLine(const Offset(0, ceilingY), Offset(w, ceilingY), _stroke);
    // Left border line
    canvas.drawLine(const Offset(0.5, ceilingY), Offset(0.5, h), _stroke);
    // Right border line
    canvas.drawLine(Offset(w - 0.5, ceilingY), Offset(w - 0.5, h), _stroke);

    // 3. Cyber Arc / Tech Brackets at Top-Left & Top-Right Corners
    _stroke
      ..color = _ca(Colors.white, 0.7)
      ..strokeWidth = 1.5;

    // Top-Left corner bracket
    canvas.drawLine(const Offset(0, ceilingY), const Offset(16, ceilingY), _stroke);
    canvas.drawLine(const Offset(0, ceilingY), const Offset(0, ceilingY + 16), _stroke);

    // Top-Right corner bracket
    canvas.drawLine(Offset(w - 16, ceilingY), Offset(w, ceilingY), _stroke);
    canvas.drawLine(Offset(w, ceilingY), Offset(w, ceilingY + 16), _stroke);

    // Corner pip lights
    _fill.color = _ca(glowColor, 0.9);
    canvas.drawCircle(const Offset(3, ceilingY + 3), 1.8, _fill);
    canvas.drawCircle(Offset(w - 3, ceilingY + 3), 1.8, _fill);
  }

  void _drawNet(Canvas canvas, Size size) {
    final hasClutch = c.activeSectorBlessing?.type == SectorBlessingType.emergencyClutch && !c.emergencyClutchUsedThisStage;
    if (!c.paddle.hasNet && !hasClutch) return;
    final y = size.height - 22.0;
    final netColor = hasClutch ? const Color(0xFF76FF03) : const Color(0xFF8BC34A);
    _stroke
      ..color = _ca(netColor, 0.85)
      ..strokeWidth = 3.2;
    canvas.drawLine(Offset(0, y), Offset(size.width, y), _stroke);

    _stroke
      ..color = _ca(netColor, 0.28)
      ..strokeWidth = 7.0;
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

  void _drawChaosAim(Canvas canvas) {
    if (c.currentMode != GameMode.chaos) return;
    final ox = c.chaosHomeX;
    final oy = c.chaosFloorY;

    // 1. Floor guard boundary line
    _stroke
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6
      ..color = const Color(0x6600E5FF);
    canvas.drawLine(Offset(0, oy), Offset(c.screenWidth, oy), _stroke);
    _stroke
      ..strokeWidth = 0.8
      ..color = const Color(0x33FFFFFF);
    _drawDashedLine(canvas, Offset(0, oy), Offset(c.screenWidth, oy), _stroke, dashWidth: 8.0, dashSpace: 8.0);

    // 2. Base platform node at chaosHomeX
    _fill
      ..style = PaintingStyle.fill
      ..shader = null
      ..color = const Color(0x8800E5FF);
    canvas.drawCircle(Offset(ox, oy), 8.0, _fill);
    _fill.color = Colors.white;
    canvas.drawCircle(Offset(ox, oy), 3.2, _fill);

    // 3. Ball count badge (e.g. x3) above launcher
    final displayCount = c.status == GameStatus.ready ? c.chaosStock : (c.chaosStock - c.chaosReturned).clamp(0, c.chaosStock);
    _tp.text = TextSpan(
      text: 'x$displayCount',
      style: const TextStyle(
        fontFamily: 'Rajdhani',
        fontFamilyFallback: ['Segoe UI Emoji', 'Segoe UI Symbol'],
        color: Color(0xFF00E5FF),
        fontSize: 12,
        fontWeight: FontWeight.w900,
        shadows: [
          Shadow(color: Colors.black, offset: Offset(0, 1), blurRadius: 3),
        ],
      ),
    );
    _tp.layout();
    _tp.paint(canvas, Offset(ox - _tp.width / 2, oy + 8.0));

    // 4. Grounded Direct Recall Button in Chaos Mode
    if (c.status == GameStatus.playing) {
      const btnW = 120.0;
      const btnH = 38.0;
      final pulse = 0.82 + 0.18 * sin(time * 6.0);

      // --- DIRECT RECALL BUTTON ---
      final rightBtnX = c.screenWidth - btnW - 14.0;
      final rightBtnY = c.screenHeight - btnH - 12.0;
      final rightRRect = RRect.fromRectAndRadius(Rect.fromLTWH(rightBtnX, rightBtnY, btnW, btnH), const Radius.circular(19.0));
      final isRecall = c.chaosRecallActive;

      _fill
        ..style = PaintingStyle.fill
        ..shader = null
        ..color = isRecall ? const Color(0xEE00B0FF) : const Color(0xEE311B92);
      canvas.drawRRect(rightRRect, _fill);

      _stroke
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..color = (isRecall ? Colors.white : const Color(0xFFE040FB)).withValues(alpha: pulse);
      canvas.drawRRect(rightRRect, _stroke);

      final rightLabel = isRecall ? 'TOPLANIYOR' : '⤹ GERİ ÇAĞIR';

      _tp.text = TextSpan(
        text: rightLabel,
        style: TextStyle(
          fontFamily: 'Rajdhani',
          fontFamilyFallback: const ['Segoe UI Emoji', 'Segoe UI Symbol'],
          color: isRecall ? Colors.black87 : Colors.white,
          fontSize: 10.5,
          fontWeight: FontWeight.w900,
          letterSpacing: 0.5,
        ),
      );
      _tp.layout();
      _tp.paint(canvas, Offset(rightBtnX + (btnW - _tp.width) / 2, rightBtnY + (btnH - _tp.height) / 2));

      return;
    }

    if (c.status != GameStatus.ready) return;

    // 5. Raycast Trajectory with 1st Bounce Reflection
    var dx = c.chaosAimX - ox;
    var dy = c.chaosAimY - oy;
    if (!c.chaosAiming || dy >= -10) {
      dx = 0;
      dy = -1;
    }
    final angle = atan2(dy, dx);
    final clampedAngle = angle.clamp(-pi + 0.16, -0.16);
    final rayDirX = cos(clampedAngle);
    final rayDirY = sin(clampedAngle);

    const ballR = 5.2;
    final leftWallX = ballR;
    final rightWallX = c.screenWidth - ballR;
    const ceilingY = 36.0 + ballR;

    double closestT = double.infinity;
    double hitNormX = 0.0;
    double hitNormY = 1.0;

    // Ray vs Left Wall
    if (rayDirX < 0) {
      final t = (leftWallX - ox) / rayDirX;
      if (t > 1.0 && t < closestT) {
        closestT = t;
        hitNormX = 1.0;
        hitNormY = 0.0;
      }
    }
    // Ray vs Right Wall
    if (rayDirX > 0) {
      final t = (rightWallX - ox) / rayDirX;
      if (t > 1.0 && t < closestT) {
        closestT = t;
        hitNormX = -1.0;
        hitNormY = 0.0;
      }
    }
    // Ray vs Ceiling
    if (rayDirY < 0) {
      final t = (ceilingY - oy) / rayDirY;
      if (t > 1.0 && t < closestT) {
        closestT = t;
        hitNormX = 0.0;
        hitNormY = 1.0;
      }
    }

    // Ray vs Bricks
    for (final b in c.bricks) {
      if (!b.isAlive || b.isBallPickup) continue;
      final minX = b.x - ballR;
      final maxX = b.x + b.width + ballR;
      final minY = b.y - ballR;
      final maxY = b.y + b.height + ballR;

      double tNear = -double.infinity;
      double tFar = double.infinity;
      double nx = 0, ny = 0;

      // X-slab
      if (rayDirX.abs() > 0.0001) {
        double tx1 = (minX - ox) / rayDirX;
        double tx2 = (maxX - ox) / rayDirX;
        double normX1 = -1.0;
        if (tx1 > tx2) {
          final temp = tx1; tx1 = tx2; tx2 = temp;
          normX1 = 1.0;
        }
        if (tx1 > tNear) {
          tNear = tx1;
          nx = normX1;
          ny = 0;
        }
        tFar = min(tFar, tx2);
      } else if (ox < minX || ox > maxX) {
        continue;
      }

      // Y-slab
      if (rayDirY.abs() > 0.0001) {
        double ty1 = (minY - oy) / rayDirY;
        double ty2 = (maxY - oy) / rayDirY;
        double normY1 = -1.0;
        if (ty1 > ty2) {
          final temp = ty1; ty1 = ty2; ty2 = temp;
          normY1 = 1.0;
        }
        if (ty1 > tNear) {
          tNear = ty1;
          nx = 0;
          ny = normY1;
        }
        tFar = min(tFar, ty2);
      } else if (oy < minY || oy > maxY) {
        continue;
      }

      if (tFar >= tNear && tNear > 2.0 && tNear < closestT) {
        closestT = tNear;
        hitNormX = nx;
        hitNormY = ny;
      }
    }

    if (closestT.isInfinite || closestT <= 0) return;

    final hitX = ox + rayDirX * closestT;
    final hitY = oy + rayDirY * closestT;

    // Reflected ray direction: v' = v - 2*(v.n)*n
    final dot = rayDirX * hitNormX + rayDirY * hitNormY;
    final bounceDirX = rayDirX - 2.0 * dot * hitNormX;
    final bounceDirY = rayDirY - 2.0 * dot * hitNormY;

    // A) Draw Primary Aim Laser (Origin -> Hit)
    for (double t = 16.0; t < closestT; t += 13.0) {
      final p = (t / closestT).clamp(0.0, 1.0);
      final alpha = (0.95 - p * 0.20).clamp(0.3, 0.95);
      _fill.color = _ca(const Color(0xFF00E5FF), alpha);
      canvas.drawCircle(Offset(ox + rayDirX * t, oy + rayDirY * t), 2.2, _fill);
    }

    // B) Glowing Impact Reticle at Hit Point
    final reticlePulse = 1.0 + 0.18 * sin(time * 16.0);
    _stroke
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6
      ..color = const Color(0xFF00E5FF);
    canvas.drawCircle(Offset(hitX, hitY), 6.0 * reticlePulse, _stroke);
    _fill
      ..style = PaintingStyle.fill
      ..color = Colors.white;
    canvas.drawCircle(Offset(hitX, hitY), 2.2, _fill);

    // C) Draw Secondary Reflected Beam (Hit -> Bounce Direction)
    const bounceLength = 135.0;
    for (double t = 10.0; t < bounceLength; t += 12.0) {
      final p = (t / bounceLength).clamp(0.0, 1.0);
      final alpha = (0.75 * (1.0 - p)).clamp(0.08, 0.75);
      _fill.color = _ca(const Color(0xFFFFD54F), alpha);
      canvas.drawCircle(Offset(hitX + bounceDirX * t, hitY + bounceDirY * t), 1.7 * (1.0 - p * 0.4), _fill);
    }
  }

  void _drawChronoLaser(Canvas canvas) {
    if (c.chronoBulletTimeTimer <= 0 || c.balls.isEmpty) return;
    final ball = c.balls.first;
    if (ball.isStuck) return;
    final spd = ball.speed;
    if (spd < 1.0) return;
    final dx = ball.vx / spd;
    final dy = ball.vy / spd;
    final start = Offset(ball.x, ball.y);
    final end = Offset(ball.x + dx * 280.0, ball.y + dy * 280.0);

    _stroke
      ..color = const Color(0xFFFFD54F).withValues(alpha: 0.70)
      ..strokeWidth = 2.4
      ..style = PaintingStyle.stroke;
    _drawDashedLine(canvas, start, end, _stroke, dashWidth: 7.0, dashSpace: 5.0);

    _fill
      ..color = const Color(0xFFFFD54F)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(end, 3.8, _fill);
  }

  void _drawPaddle(Canvas canvas) {
    if (c.currentMode == GameMode.chaos) return;
    final p = c.paddle;
    final rect = p.rect;

    canvas.save();
    final pcx = rect.center.dx;
    final pcy = rect.center.dy + p.bounceOffsetY;
    canvas.translate(pcx, pcy);
    canvas.scale(p.squashScaleX, p.squashScaleY);
    canvas.translate(-rect.center.dx, -rect.center.dy);

    if (p.flashTimer > 0) {
      _fill
        ..style = PaintingStyle.fill
        ..shader = null
        ..maskFilter = null
        ..color = Colors.white;
      canvas.drawRect(rect, _fill);
      _stroke
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..color = const Color(0xFF0B1021);
      canvas.drawRect(rect, _stroke);
      canvas.restore();
      return;
    }

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

    // Swirling Purple/Cyan Gravitational Vortex Funnel above paddle
    if (p.hasVortex) {
      final vx = rect.center.dx;
      final vy = rect.top - 8.0;
      // 3 Concentric tilted vortex rings narrowing towards the paddle
      for (int ring = 0; ring < 3; ring++) {
        final ringY = vy - ring * 5.5;
        final rw = (rect.width * (0.48 + ring * 0.22)).clamp(28.0, 120.0);
        final rh = 7.0 + ring * 2.2;
        final pulse = 0.65 + 0.35 * sin(p.vortexAngle * 1.4 - ring * 0.9);
        _stroke
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.8 - ring * 0.3
          ..color = _ca(ring.isEven ? const Color(0xFFE040FB) : const Color(0xFF00E5FF), 0.78 * pulse);
        canvas.drawOval(Rect.fromCenter(center: Offset(vx, ringY), width: rw, height: rh), _stroke);

        // Orbiting vortex energy nodes along each ring
        final a1 = p.vortexAngle * (1.2 + ring * 0.3) + ring * 1.1;
        final a2 = a1 + pi;
        _fill
          ..style = PaintingStyle.fill
          ..shader = null
          ..color = ring.isEven ? const Color(0xFF18FFFF) : const Color(0xFFEA80FC);
        canvas.drawCircle(Offset(vx + cos(a1) * (rw / 2), ringY + sin(a1) * (rh / 2)), 2.0, _fill);
        canvas.drawCircle(Offset(vx + cos(a2) * (rw / 2), ringY + sin(a2) * (rh / 2)), 2.0, _fill);
      }

      // Central vortex core singularity on top of paddle
      _fill.color = const Color(0x99E040FB);
      canvas.drawCircle(Offset(vx, rect.top - 2.0), 5.5, _fill);
      _fill.color = Colors.white;
      canvas.drawCircle(Offset(vx, rect.top - 2.0), 2.4, _fill);
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

      // Pull is active only while dist < maxInfluenceDist. The ring's outer
      // edge stops half a pixel inside that, so the line itself is still pull.
      final maxDist = bh.maxInfluenceDist;
      final double limit = maxDist - 0.5;
      canvas.clipPath(
        Path()..addOval(Rect.fromCircle(center: Offset.zero, radius: limit)),
        doAntiAlias: false,
      );

      final bool vortex = bh.isVortexTrap;
      final bool exotic = bh.isSupercharged;
      final Color accent = vortex
          ? const Color(0xFFFF1744)
          : (exotic ? const Color(0xFF00E5FF) : const Color(0xFFB388FF));
      final Color deep = vortex
          ? const Color(0xFF2A0010)
          : (exotic ? const Color(0xFF042833) : const Color(0xFF14042E));
      final Color mid = vortex
          ? const Color(0xFFFF5252)
          : (exotic ? const Color(0xFF18FFFF) : const Color(0xFF7C4DFF));
      final Color rim = vortex
          ? const Color(0xFFFF8A80)
          : (exotic ? const Color(0xFFFFD54F) : const Color(0xFFE040FB));
      final double pulse = 0.5 + 0.5 * sin(time * 2.4);

      // Quiet field wash without outer boundary line.
      _fill
        ..style = PaintingStyle.fill
        ..maskFilter = null
        ..shader = RadialGradient(
          colors: [
            _ca(accent, 0.20 + 0.05 * pulse),
            _ca(mid, 0.07),
            Colors.transparent,
          ],
          stops: const [0.0, 0.46, 1.0],
        ).createShader(Rect.fromCircle(center: Offset.zero, radius: maxDist));
      canvas.drawCircle(Offset.zero, limit, _fill);
      _fill.shader = null;

      // Round body with a slow side wave, smoothed so it stays a circle.
      canvas.save();
      canvas.rotate(bh.rotation * 0.32);
      final double baseRadius = min(bh.radius * 1.85, maxDist * 0.58);
      const int segments = 28;
      final List<Offset> pts = List<Offset>.generate(segments, (i) {
        final double angle = (pi * 2 / segments) * i;
        final double wave = sin(angle * 5.0 + time * 2.2) * 0.042 + cos(angle * 3.0 - time * 1.5) * 0.022;
        final double r = baseRadius * (1.0 + wave);
        return Offset(cos(angle) * r, sin(angle) * r);
      });
      _tempPath.reset();
      final Offset start = Offset(
        (pts[0].dx + pts[1].dx) * 0.5,
        (pts[0].dy + pts[1].dy) * 0.5,
      );
      _tempPath.moveTo(start.dx, start.dy);
      for (int i = 1; i < segments; i++) {
        final Offset next = pts[(i + 1) % segments];
        final Offset mid = Offset((pts[i].dx + next.dx) * 0.5, (pts[i].dy + next.dy) * 0.5);
        _tempPath.quadraticBezierTo(pts[i].dx, pts[i].dy, mid.dx, mid.dy);
      }
      _tempPath.close();

      _fill.shader = RadialGradient(
          colors: [
            const Color(0xFF05060C),
            deep,
            _ca(mid, 0.96),
            _ca(rim, 0.78),
            _ca(rim, 0.0),
          ],
          stops: const [0.16, 0.36, 0.60, 0.82, 1.0],
        ).createShader(Rect.fromCircle(center: Offset.zero, radius: baseRadius * 1.06));
      canvas.drawPath(_tempPath, _fill);
      _fill.shader = null;

      // Glass crescent so the disk has a lit face, same language as the neon tubes.
      _stroke
        ..strokeWidth = 1.5
        ..color = _ca(Colors.white, 0.22 + 0.10 * pulse);
      canvas.drawArc(
        Rect.fromCircle(center: Offset(-baseRadius * 0.16, -baseRadius * 0.14), radius: baseRadius * 0.70),
        -2.35,
        1.35,
        false,
        _stroke,
      );
      canvas.restore();

      // Event horizon: one phosphor ring, then the void.
      final double photonR = bh.radius * 0.50;
      _stroke
        ..strokeWidth = 2.4
        ..color = _ca(rim, 0.78 + 0.16 * pulse);
      canvas.drawCircle(Offset.zero, photonR, _stroke);
      _stroke
        ..strokeWidth = 0.7
        ..color = _ca(Colors.white, 0.92);
      canvas.drawCircle(Offset.zero, photonR, _stroke);

      _fill.color = const Color(0xFF020308);
      canvas.drawCircle(Offset.zero, photonR * 0.76, _fill);

      // Three sparks on a circular orbit. No spiral arms.
      final double sparkR = baseRadius * 0.62;
      final double spin = bh.rotation * (exotic ? 2.2 : 1.45);
      for (int i = 0; i < 3; i++) {
        final double a = spin + i * (pi * 2 / 3);
        _fill.color = _ca(i == 0 ? Colors.white : rim, 0.9);
        canvas.drawCircle(Offset(cos(a) * sparkR, sin(a) * sparkR), i == 0 ? 1.6 : 1.15, _fill);
      }

      canvas.restore();
    }
  }

  void _drawPortals(Canvas canvas) {
    if (c.portals.isEmpty) return;

    // 1. Quantum Resonance Conduit with flowing energy packets between linked portals
    if (c.portals.length >= 2 && c.portals[0].linkedPortal != null) {
      final p1 = c.portals[0];
      final p2 = c.portals[1];
      final beamPulse = 0.28 + 0.16 * sin(time * 3.6);
      _stroke
        ..shader = LinearGradient(
          colors: [
            _ca(p1.color, beamPulse),
            _ca(Colors.white, beamPulse * 1.35),
            _ca(p2.color, beamPulse),
          ],
        ).createShader(Rect.fromPoints(Offset(p1.x, p1.y), Offset(p2.x, p2.y)))
        ..strokeWidth = 2.0;
      _drawDashedLine(
        canvas,
        Offset(p1.x, p1.y),
        Offset(p2.x, p2.y),
        _stroke,
        dashWidth: 6.0,
        dashSpace: 8.0,
      );
      _stroke.shader = null;

      // Traveling quantum energy packets flowing along the conduit
      for (int k = 0; k < 2; k++) {
        final double t = (time * 0.45 + k * 0.5) % 1.0;
        final double qx = p1.x + (p2.x - p1.x) * t;
        final double qy = p1.y + (p2.y - p1.y) * t;
        final Color qCol = Color.lerp(p1.color, p2.color, t)!;
        _fill.color = _ca(qCol, 0.45);
        canvas.drawCircle(Offset(qx, qy), 4.2, _fill);
        _fill.color = Colors.white;
        canvas.drawCircle(Offset(qx, qy), 1.8, _fill);
      }
    }

    // 2. Black-Hole Harmonized Cosmic Portals
    for (final p in c.portals) {
      canvas.save();
      canvas.translate(p.x, p.y);

      final double pulse = 0.5 + 0.5 * sin(time * 2.6 + (p.isBlue ? 0.0 : pi));
      final double effRadius = p.radius * (1.0 + 0.06 * pulse);

      // Outer field aura wash with soft breathing pulse
      _fill
        ..style = PaintingStyle.fill
        ..maskFilter = null
        ..shader = RadialGradient(
          colors: [
            _ca(p.color, 0.22 + 0.06 * pulse),
            _ca(p.color, 0.06),
            Colors.transparent,
          ],
          stops: const [0.0, 0.48, 1.0],
        ).createShader(Rect.fromCircle(center: Offset.zero, radius: effRadius * 1.95));
      canvas.drawCircle(Offset.zero, effRadius * 1.90, _fill);
      _fill.shader = null;

      // Type-specific background ripple effects
      if (p.type == PortalType.gravity) {
        final double rip1 = (time * 0.7) % 1.0;
        final double rip2 = (time * 0.7 + 0.5) % 1.0;
        _stroke
          ..strokeWidth = 1.2
          ..color = _ca(p.color, (1.0 - rip1) * 0.40);
        canvas.drawCircle(Offset.zero, effRadius * (1.1 + rip1 * 0.8), _stroke);
        _stroke.color = _ca(p.color, (1.0 - rip2) * 0.40);
        canvas.drawCircle(Offset.zero, effRadius * (1.1 + rip2 * 0.8), _stroke);
      } else if (p.type == PortalType.moving) {
        final double vxSign = cos(p.moveTime * p.moveSpeed + p.movePhase);
        final double ghostOffset = -vxSign * 10.0;
        _stroke
          ..strokeWidth = 1.2
          ..color = _ca(p.color, 0.22);
        canvas.drawCircle(Offset(ghostOffset, 0), effRadius * 0.9, _stroke);
        canvas.drawCircle(Offset(ghostOffset * 1.8, 0), effRadius * 0.8, _stroke);
      } else if (p.type == PortalType.quantumPhase) {
        final double phaseShift = sin(time * 3.5) * 4.0;
        _stroke
          ..strokeWidth = 1.4
          ..color = _ca(const Color(0xFF18FFFF), 0.45);
        canvas.drawCircle(Offset(phaseShift, 0), effRadius * 1.08, _stroke);
        _stroke.color = _ca(const Color(0xFFFF4081), 0.45);
        canvas.drawCircle(Offset(-phaseShift, 0), effRadius * 1.08, _stroke);
      }

      // Organic undulating accretion disk with smoothed wave contour (matching black hole language)
      canvas.save();
      canvas.rotate(p.rotation * 0.35);
      final double baseRadius = effRadius * 1.35;
      const int segments = 24;
      final List<Offset> pts = List<Offset>.generate(segments, (i) {
        final double angle = (pi * 2 / segments) * i;
        final double wave = sin(angle * 4.0 + time * 2.5) * 0.038 + cos(angle * 2.0 - time * 1.6) * 0.020;
        final double r = baseRadius * (1.0 + wave);
        return Offset(cos(angle) * r, sin(angle) * r);
      });
      _tempPath.reset();
      final Offset start = Offset((pts[0].dx + pts[1].dx) * 0.5, (pts[0].dy + pts[1].dy) * 0.5);
      _tempPath.moveTo(start.dx, start.dy);
      for (int i = 1; i < segments; i++) {
        final Offset next = pts[(i + 1) % segments];
        final Offset mid = Offset((pts[i].dx + next.dx) * 0.5, (pts[i].dy + next.dy) * 0.5);
        _tempPath.quadraticBezierTo(pts[i].dx, pts[i].dy, mid.dx, mid.dy);
      }
      _tempPath.close();

      _fill.shader = RadialGradient(
        colors: [
          const Color(0xFF03050C),
          _ca(p.color, 0.35),
          _ca(p.color, 0.90),
          _ca(Colors.white, 0.75),
          _ca(p.color, 0.0),
        ],
        stops: const [0.15, 0.38, 0.65, 0.84, 1.0],
      ).createShader(Rect.fromCircle(center: Offset.zero, radius: baseRadius * 1.06));
      canvas.drawPath(_tempPath, _fill);
      _fill.shader = null;

      // Lit glass crescent arc matching black hole and neon tubes
      _stroke
        ..strokeWidth = 1.6
        ..color = _ca(Colors.white, 0.30 + 0.12 * pulse);
      canvas.drawArc(
        Rect.fromCircle(center: Offset(-baseRadius * 0.15, -baseRadius * 0.13), radius: baseRadius * 0.72),
        -2.35,
        1.40,
        false,
        _stroke,
      );
      canvas.restore();

      // Accelerator outward energy chevrons
      if (p.type == PortalType.accelerator) {
        canvas.save();
        canvas.rotate(p.rotation * 0.8);
        _stroke
          ..strokeWidth = 1.8
          ..color = _ca(const Color(0xFFFFD700), 0.75 + 0.25 * pulse);
        for (int i = 0; i < 3; i++) {
          final double ca = i * (2 * pi / 3);
          final double cr = effRadius * 1.25;
          final cx = cos(ca) * cr;
          final cy = sin(ca) * cr;
          canvas.save();
          canvas.translate(cx, cy);
          canvas.rotate(ca + pi / 2);
          _tempPath.reset();
          _tempPath.moveTo(-4, -3);
          _tempPath.lineTo(0, 3);
          _tempPath.lineTo(4, -3);
          canvas.drawPath(_tempPath, _stroke);
          canvas.restore();
        }
        canvas.restore();
      }

      // Event horizon: Dual photon ring
      final double photonR = effRadius * 0.52;
      _stroke
        ..strokeWidth = 2.4
        ..color = _ca(p.color, 0.85 + 0.15 * pulse);
      canvas.drawCircle(Offset.zero, photonR, _stroke);
      _stroke
        ..strokeWidth = 0.8
        ..color = _ca(Colors.white, 0.95);
      canvas.drawCircle(Offset.zero, photonR, _stroke);

      // Deep cosmic void center
      _fill.color = const Color(0xFF020308);
      canvas.drawCircle(Offset.zero, photonR * 0.78, _fill);

      // Pulsing quantum singularity core dot
      _fill.color = _ca(p.color, 0.95);
      canvas.drawCircle(Offset.zero, 3.2 * (0.8 + 0.2 * pulse), _fill);
      _fill.color = Colors.white;
      canvas.drawCircle(Offset.zero, 1.5, _fill);

      // Orbiting quantum sparks / motes
      final double sparkR = baseRadius * 0.60;
      final double spin = p.rotation * 1.4;
      for (int i = 0; i < 3; i++) {
        final double a = spin + i * (pi * 2 / 3);
        _fill.color = _ca(i == 0 ? Colors.white : p.color, 0.92);
        canvas.drawCircle(Offset(cos(a) * sparkR, sin(a) * sparkR), i == 0 ? 1.6 : 1.15, _fill);
      }

      canvas.restore();
    }
  }

  void _drawBalls(Canvas canvas) {
    // Kaos modunda hazır/hedefleme durumunda üst üste yığılmış toplar yerine tek bir top çizilir
    final Iterable<Ball> ballsToDraw = (c.currentMode == GameMode.chaos && c.status == GameStatus.ready)
        ? (c.balls.isNotEmpty ? [c.balls.first] : const <Ball>[])
        : c.balls;

    for (final ball in ballsToDraw) {
      final isFireball = ball.isFireball;
      final isComboFever = c.stats.combo >= 5;
      final isCornerBoost = ball.cornerBoostTimer > 0 || isComboFever;
      final skinGlow = c.activeBallSkin.glowColor;
      final skinMain = c.activeBallSkin.mainColor;
      final isLegendaryBall = c.activeBallSkin.rarity == Rarity.legendary;
      final ballSkinId = c.activeBallSkin.id;
      final isRainbowBall = ballSkinId == 'gokkusagi';

      // Trail Skin Colors (User's equipped trail skin)
      final trailPrimary = c.activeTrailSkin.primaryColor;
      final trailGlow = c.activeTrailSkin.glowColor;

      // Normal trail color provider: User rule:
      // "efsanevi toplar sadece köşe vuruşu olduğunda kendi renkleri ile gitsin, onun dışındaki diğer toplar normal hangi iz seçildiyse onu kullansın."
      // Normal trail uses equipped trail skin colors (with subtle animated shimmer)
      Color getBallTrailColor(int index, int total, {bool isGlow = false}) {
        if (c.activeTrailSkin.id == 't1') {
          final progress = total > 1 ? index / (total - 1) : 0.0;
          if (progress < 0.45) {
            final t = progress / 0.45;
            return Color.lerp(const Color(0xFFFF3D00), const Color(0xFFFF8F00), t)!;
          } else {
            final t = (progress - 0.45) / 0.55;
            return Color.lerp(const Color(0xFFFF8F00), const Color(0xFFFFEE58), t)!;
          }
        }
        return isGlow ? trailGlow : trailPrimary;
      }

      // Corner boost flame colors:
      // Only legendary balls use their own ball colors on corner boost!
      // Other balls use their equipped trail skin color on corner boost!
      final Color cbFlameBase = isLegendaryBall
          ? (isRainbowBall
              ? HSLColor.fromAHSL(1.0, (time * 24.0) % 360.0, 0.70, 0.58).toColor()
              : skinMain)
          : trailPrimary;
      final Color cbFlameGlow = isLegendaryBall
          ? (isRainbowBall
              ? HSLColor.fromAHSL(1.0, (time * 24.0 + 40.0) % 360.0, 0.65, 0.62).toColor()
              : skinGlow)
          : trailGlow;

      Color getCornerBoostColor(int index, int total) {
        if (isLegendaryBall) {
          if (isRainbowBall) {
            // Smooth, soft spectrum gradient along the length without blinding strobe
            final progress = total > 1 ? index / (total - 1) : 0.0;
            final hue = ((time * 20.0) + progress * 160.0) % 360.0;
            return HSLColor.fromAHSL(1.0, hue, 0.68, 0.60).toColor();
          }
          return cbFlameBase;
        }
        return (index % 2 == 0) ? trailPrimary : trailGlow;
      }

      final cbFlameDeepKey = Object.hash(cbFlameBase.toARGB32(), 301);
      final cbFlameDeep = _hslDerivedColors.putIfAbsent(cbFlameDeepKey, () {
        final hsl = HSLColor.fromColor(cbFlameBase);
        return hsl.withLightness((hsl.lightness * 0.65).clamp(0.12, 0.55)).toColor();
      });
      final cbFlameBright = Color.lerp(cbFlameBase, Colors.white, 0.55)!;
      final cbFlameCore = Color.lerp(cbFlameBase, Colors.white, 0.88)!;

      if (!ball.isStuck && ball.trail.length > 1) {
        final trailStyle = c.activeTrailSkin.style;
        final trailCount = ball.trail.length;
        // Smooth aerodynamic taper: rich near ball, gracefully tapering down to a fine tip at the tail
        double majesticTaper(double progress) =>
            pow((1.0 - progress).clamp(0.0, 1.0), 1.25).toDouble();

        if (trailStyle == TrailStyle.dot) {
          // === ELEVATED DOT TRAIL: Celestial Starlight Constellation (Full-bodied & Majestic) ===
          final dotPositions = <Offset>[];
          for (int i = 0; i < trailCount; i++) {
            final progress = trailCount > 1 ? i / (trailCount - 1) : 0.0;
            final taper = majesticTaper(progress);
            final headPin = (i / 4.0).clamp(0.0, 1.0);
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
            final wave = sin(time * 12.0 + i * 0.8) * (ball.radius * 0.30 * taper * headPin);
            dotPositions.add(Offset(ball.trail[i].position.dx + nx * wave, ball.trail[i].position.dy + ny * wave));
          }

          // 1. Connecting undulating starlight filament between dots (thick & luminous)
          _stroke
            ..style = PaintingStyle.stroke
            ..strokeCap = StrokeCap.round
            ..strokeJoin = StrokeJoin.round
            ..maskFilter = null;
          for (int i = 0; i < dotPositions.length - 1; i++) {
            final progress = (i + 0.5) / (dotPositions.length - 1);
            final taper = majesticTaper(progress);
            final segColor = isFireball
                ? const Color(0xFFFFAB00)
                : (isCornerBoost ? getCornerBoostColor(i, dotPositions.length) : getBallTrailColor(i, dotPositions.length, isGlow: true));
            _stroke
              ..strokeWidth = (ball.radius * 1.50 * taper).clamp(1.6, ball.radius * 2.0)
              ..color = _ca(segColor, 0.65 * taper);
            canvas.drawLine(dotPositions[i], dotPositions[i + 1], _stroke);
          }

          // 2. Shimmering Starlight Orbs
          _fill
            ..style = PaintingStyle.fill
            ..maskFilter = null;
          for (int i = 1; i < dotPositions.length; i++) {
            final progress = dotPositions.length > 1 ? i / (dotPositions.length - 1) : 0.0;
            final taper = majesticTaper(progress);
            final shimmer = 0.85 + 0.15 * sin(time * 10 + i * 0.7);
            final baseR = ball.radius * 0.95 * taper * shimmer;
            if (baseR <= 0.3) continue;
            final pos = dotPositions[i];

            final dotColor = isFireball
                ? const Color(0xFFFF6D00)
                : (isCornerBoost ? getCornerBoostColor(i, dotPositions.length) : getBallTrailColor(i, dotPositions.length, isGlow: true));
            final coreColor = isFireball
                ? const Color(0xFFFFD700)
                : (isCornerBoost ? (isRainbowBall ? getCornerBoostColor(i, dotPositions.length) : cbFlameCore) : getBallTrailColor(i, dotPositions.length));

            // Soft diffuse halo
            _fill.color = _ca(dotColor, 0.34 * taper);
            canvas.drawCircle(pos, baseR * 1.55, _fill);

            // Luminous bead
            _fill.color = _ca(coreColor, 0.90 * taper);
            canvas.drawCircle(pos, baseR, _fill);

            // Starlight core
            _fill.color = _ca(isCornerBoost ? cbFlameCore : Colors.white, 0.96 * taper);
            canvas.drawCircle(pos, baseR * 0.45, _fill);

            // Rotating 4-point micro-glint star on alternating beads
            if (i % 3 == 0 && baseR > 2.0) {
              final spAngle = time * 3.5 + i * 1.2;
              final spLen = baseR * 1.75;
              _stroke
                ..strokeWidth = 1.5
                ..color = _ca(isCornerBoost ? cbFlameBright : Colors.white, 0.85 * taper);
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
          // === ELEVATED SPARK TRAIL: High-Voltage Lightning & Charged Sparks (Full-Bodied) ===
          final sparkPositions = <Offset>[Offset(ball.x, ball.y)];
          for (int i = 0; i < trailCount - 1; i++) {
            final p1 = ball.trail[i].position;
            final p2 = ball.trail[i + 1].position;
            final progress = i / (trailCount - 1);
            final taper = majesticTaper(progress);
            final headPin = (i / 3.0).clamp(0.0, 1.0);

            final dx = p2.dx - p1.dx;
            final dy = p2.dy - p1.dy;
            final segLen = sqrt(dx * dx + dy * dy);
            if (segLen > 0.001) {
              final nx = -dy / segLen;
              final ny = dx / segLen;
              final jitter = sin(time * 12.0 + i * 1.5) * (ball.radius * 0.38 * taper * headPin);
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

          // Layer 1: Electric outer bloom segments
          for (int i = 0; i < sparkPositions.length - 1; i++) {
            final progress = (i + 0.5) / (sparkPositions.length - 1);
            final taper = majesticTaper(progress);
            final segGlowColor = isFireball
                ? const Color(0xFFFF6D00)
                : (isCornerBoost ? getCornerBoostColor(i, sparkPositions.length) : getBallTrailColor(i, sparkPositions.length, isGlow: true));
            _stroke
              ..strokeWidth = (ball.radius * 3.8 * taper).clamp(2.0, ball.radius * 3.8)
              ..color = _ca(segGlowColor, 0.40 * taper);
            canvas.drawLine(sparkPositions[i], sparkPositions[i + 1], _stroke);
          }

          // Layer 2: Main energetic lightning bolt segments
          for (int i = 0; i < sparkPositions.length - 1; i++) {
            final progress = (i + 0.5) / (sparkPositions.length - 1);
            final taper = majesticTaper(progress);
            final segBaseColor = isFireball
                ? const Color(0xFFFFAB00)
                : (isCornerBoost ? getCornerBoostColor(i, sparkPositions.length) : getBallTrailColor(i, sparkPositions.length));
            _stroke
              ..strokeWidth = (ball.radius * 2.15 * taper).clamp(1.3, ball.radius * 2.15)
              ..color = _ca(segBaseColor, 0.94 * taper);
            canvas.drawLine(sparkPositions[i], sparkPositions[i + 1], _stroke);
          }

          // Layer 3: Blinding electric core
          for (int i = 0; i < sparkPositions.length - 1; i++) {
            final progress = (i + 0.5) / (sparkPositions.length - 1);
            final taper = majesticTaper(progress);
            _stroke
              ..strokeWidth = (ball.radius * 0.95 * taper).clamp(1.0, ball.radius * 0.95)
              ..color = _ca(isCornerBoost ? (isRainbowBall ? getCornerBoostColor(i, sparkPositions.length) : cbFlameCore) : Colors.white, 0.98 * taper);
            canvas.drawLine(sparkPositions[i], sparkPositions[i + 1], _stroke);
          }

          // Layer 4: Electric spark cross glints along the path
          for (int i = 0; i < trailCount; i += 2) {
            final progress = trailCount > 1 ? i / (trailCount - 1) : 0.0;
            final taper = majesticTaper(progress);
            final pt = ball.trail[i].position;
            final sparkSize = ball.radius * (1.05 + 0.35 * sin(time * 24 + i)) * taper;
            if (sparkSize <= 0.5) continue;
            final a = time * 8 + i * 2;
            _stroke
              ..strokeWidth = 1.4
              ..color = _ca(isCornerBoost ? (isRainbowBall ? getCornerBoostColor(i, trailCount) : cbFlameBright) : Colors.white, 0.88 * taper);
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
          // === ELEVATED GHOST TRAIL: Ethereal Phantom Echoes (Full-Bodied) ===
          _stroke
            ..style = PaintingStyle.stroke
            ..strokeCap = StrokeCap.round
            ..strokeJoin = StrokeJoin.round
            ..maskFilter = null;

          // 1. Flowing ethereal spirit ribbon segments
          for (int i = 0; i < trailCount - 1; i++) {
            final progress = (i + 0.5) / (trailCount - 1);
            final taper = majesticTaper(progress);
            final p1 = ball.trail[i].position;
            final p2 = ball.trail[i + 1].position;
            final ghostGlow = isFireball
                ? const Color(0xFFFF6D00)
                : (isCornerBoost ? getCornerBoostColor(i, trailCount) : getBallTrailColor(i, trailCount, isGlow: true));
            final ghostBase = isFireball
                ? const Color(0xFFFFD700)
                : (isCornerBoost ? getCornerBoostColor(i, trailCount) : getBallTrailColor(i, trailCount));

            // Outer mist
            _stroke
              ..strokeWidth = (ball.radius * 2.85 * taper).clamp(1.5, ball.radius * 2.85)
              ..color = _ca(ghostGlow, 0.36 * taper);
            canvas.drawLine(p1, p2, _stroke);

            // Inner core ribbon
            _stroke
              ..strokeWidth = (ball.radius * 1.45 * taper).clamp(1.0, ball.radius * 1.45)
              ..color = _ca(ghostBase, 0.68 * taper);
            canvas.drawLine(p1, p2, _stroke);
          }

          // 2. Spectral Phantom Clones
          _fill
            ..style = PaintingStyle.fill
            ..maskFilter = null;
          for (int i = 2; i < trailCount; i += 2) {
            final progress = i / (trailCount - 1);
            final taper = majesticTaper(progress);
            final headPin = (i / 4.0).clamp(0.0, 1.0);
            final wave = sin(time * 8.0 + i * 0.7) * (2.2 * taper * headPin);
            final pt = Offset(ball.trail[i].position.dx + wave, ball.trail[i].position.dy - wave * 0.5);
            final ghostRadius = ball.radius * 0.85 * taper;
            if (ghostRadius <= 0.4) continue;
            final ghostGlow = isFireball
                ? const Color(0xFFFF6D00)
                : (isCornerBoost ? getCornerBoostColor(i, trailCount) : getBallTrailColor(i, trailCount, isGlow: true));
            final ghostBase = isFireball
                ? const Color(0xFFFFD700)
                : (isCornerBoost ? getCornerBoostColor(i, trailCount) : getBallTrailColor(i, trailCount));

            // Ethereal diffuse mist aura
            _fill.color = _ca(ghostGlow, 0.28 * taper);
            canvas.drawCircle(pt, ghostRadius * 1.45, _fill);

            // Spectral body
            _fill.color = _ca(ghostBase, 0.48 * taper);
            canvas.drawCircle(pt, ghostRadius, _fill);

            // Spectral rim ring
            _stroke
              ..strokeWidth = 1.4
              ..color = _ca(isCornerBoost ? (isRainbowBall ? getCornerBoostColor(i, trailCount) : cbFlameBright) : Colors.white, 0.68 * taper);
            canvas.drawCircle(pt, ghostRadius, _stroke);

            // Specular reflection echo
            _fill.color = _ca(isCornerBoost ? (isRainbowBall ? getCornerBoostColor(i, trailCount) : cbFlameCore) : Colors.white, 0.80 * taper);
            canvas.drawCircle(Offset(pt.dx - ghostRadius * 0.3, pt.dy - ghostRadius * 0.3), ghostRadius * 0.28, _fill);
          }
        } else if (trailStyle == TrailStyle.rainbow) {
          // === GENTLE PRISMATIC AURORA (Full-Bodied Smooth Rainbow Ribbon) ===
          _stroke
            ..style = PaintingStyle.stroke
            ..strokeCap = StrokeCap.round
            ..strokeJoin = StrokeJoin.round
            ..maskFilter = null;

          final baseHue = (time * 18.0) % 360.0;

          for (int i = 0; i < trailCount - 1; i++) {
            final progress = (i + 0.5) / (trailCount - 1);
            final taper = majesticTaper(progress);
            
            final hue = (baseHue + progress * 240.0) % 360.0;
            final sereneRainbowColor = HSLColor.fromAHSL(1.0, hue, 0.72, 0.60).toColor();

            final color = isCornerBoost
                ? getCornerBoostColor(i, trailCount)
                : sereneRainbowColor;

            final headPin = (i / 3.0).clamp(0.0, 1.0);
            final wave = sin(time * 3.0 + i * 0.25) * (1.1 * taper * headPin);
            final p1 = Offset(ball.trail[i].position.dx + wave, ball.trail[i].position.dy);
            final p2 = Offset(ball.trail[i + 1].position.dx, ball.trail[i + 1].position.dy);

            // Layer 1: Soft, soothing ambient glow
            _stroke
              ..strokeWidth = (ball.radius * 3.6 * taper).clamp(1.8, ball.radius * 3.6)
              ..color = _ca(isCornerBoost ? cbFlameDeep : color, 0.32 * taper);
            canvas.drawLine(p1, p2, _stroke);

            // Layer 2: Main harmonious pastel ribbon
            _stroke
              ..strokeWidth = (ball.radius * 2.15 * taper).clamp(1.3, ball.radius * 2.15)
              ..color = _ca(color, 0.92 * taper);
            canvas.drawLine(p1, p2, _stroke);

            // Layer 3: Soft silk core
            _stroke
              ..strokeWidth = (ball.radius * 0.90 * taper).clamp(0.8, ball.radius * 0.90)
              ..color = _ca(isCornerBoost ? cbFlameCore : Colors.white, 0.94 * taper);
            canvas.drawLine(p1, p2, _stroke);

            if (i % 5 == 0 && taper > 0.35) {
              final spSize = ball.radius * 0.85 * taper;
              _fill
                ..style = PaintingStyle.fill
                ..color = _ca(Colors.white, 0.72 * taper);
              canvas.drawCircle(p1, spSize * 0.45, _fill);
            }
          }
        } else if (trailStyle == TrailStyle.plasma) {
          // === ELEVATED PLASMA TRAIL: Quantum Plasma Vortex & Cosmic Beam (Full-Bodied) ===
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
            final taper = majesticTaper(progress);
            final headPin = (i / 3.0).clamp(0.0, 1.0);

            final dx = p2.dx - p1.dx;
            final dy = p2.dy - p1.dy;
            final segLen = sqrt(dx * dx + dy * dy);
            if (segLen > 0.001) {
              final nx = -dy / segLen;
              final ny = dx / segLen;
              final helix = sin(time * 6.0 + i * 0.4) * (ball.radius * 0.58 * taper * headPin);
              helix1Pts.add(Offset(p2.dx + nx * helix, p2.dy + ny * helix));
              helix2Pts.add(Offset(p2.dx - nx * helix, p2.dy - ny * helix));
            } else {
              helix1Pts.add(p2);
              helix2Pts.add(p2);
            }
          }

          // 1. Deep coronal glow segments
          for (int i = 0; i < trailCount - 1; i++) {
            final progress = (i + 0.5) / (trailCount - 1);
            final taper = majesticTaper(progress);
            final deepGlow = isFireball
                ? const Color(0xFFFF6D00)
                : (isCornerBoost ? (isRainbowBall ? getCornerBoostColor(i, trailCount) : cbFlameDeep) : trailGlow);
            _stroke
              ..strokeWidth = (ball.radius * 4.2 * taper).clamp(2.0, ball.radius * 4.2)
              ..color = _ca(deepGlow, 0.38 * taper);
            canvas.drawLine(ball.trail[i].position, ball.trail[i + 1].position, _stroke);
          }

          // 2. Twin helical plasma streamers
          for (int i = 0; i < helix1Pts.length - 1; i++) {
            final progress = (i + 0.5) / (helix1Pts.length - 1);
            final taper = majesticTaper(progress);
            final h1Color = isFireball
                ? const Color(0xFFFFD700)
                : (isCornerBoost ? getCornerBoostColor(i, helix1Pts.length) : trailPrimary);
            final h2Color = isFireball
                ? const Color(0xFFFF6D00)
                : (isCornerBoost ? (isRainbowBall ? getCornerBoostColor(i + 3, helix1Pts.length) : cbFlameGlow) : trailGlow);
            _stroke
              ..strokeWidth = (ball.radius * 1.20 * taper).clamp(0.9, ball.radius * 1.20)
              ..color = _ca(h1Color, 0.92 * taper);
            canvas.drawLine(helix1Pts[i], helix1Pts[i + 1], _stroke);

            _stroke.color = _ca(h2Color, 0.92 * taper);
            canvas.drawLine(helix2Pts[i], helix2Pts[i + 1], _stroke);
          }

          // 3. High-intensity focused plasma core beam segments
          for (int i = 0; i < trailCount - 1; i++) {
            final progress = (i + 0.5) / (trailCount - 1);
            final taper = majesticTaper(progress);
            final beamCore = isFireball
                ? const Color(0xFFFFF9C4)
                : (isCornerBoost ? (isRainbowBall ? getCornerBoostColor(i, trailCount) : cbFlameBright) : trailPrimary);
            _stroke
              ..strokeWidth = (ball.radius * 2.05 * taper).clamp(1.3, ball.radius * 2.05)
              ..color = _ca(beamCore, 0.95 * taper);
            canvas.drawLine(ball.trail[i].position, ball.trail[i + 1].position, _stroke);

            _stroke
              ..strokeWidth = (ball.radius * 0.95 * taper).clamp(0.8, ball.radius * 0.95)
              ..color = _ca(isCornerBoost ? (isRainbowBall ? getCornerBoostColor(i, trailCount) : cbFlameCore) : Colors.white, 0.98 * taper);
            canvas.drawLine(ball.trail[i].position, ball.trail[i + 1].position, _stroke);
          }

          // 4. Quantum containment rings along the beam
          for (int i = 2; i < trailCount; i += 4) {
            final progress = i / (trailCount - 1);
            final taper = majesticTaper(progress);
            final pt = ball.trail[i].position;
            final r = ball.radius * (1.28 + 0.32 * sin(time * 14 + i)) * taper;
            if (r <= 0.5) continue;
            final ringColor = isFireball
                ? const Color(0xFFFFD700)
                : (isCornerBoost ? (isRainbowBall ? getCornerBoostColor(i, trailCount) : cbFlameGlow) : trailGlow);
            _stroke
              ..strokeWidth = 1.6
              ..color = _ca(ringColor, 0.82 * taper);
            canvas.drawCircle(pt, r, _stroke);
          }
        } else if (trailStyle == TrailStyle.fire) {
          // === ELEVATED FIRE TRAIL: Blazing Inferno Wake (Full-Bodied) ===
          final firePts = <Offset>[Offset(ball.x, ball.y)];
          for (int i = 0; i < trailCount - 1; i++) {
            final p1 = ball.trail[i].position;
            final p2 = ball.trail[i + 1].position;
            final progress = i / (trailCount - 1);
            final taper = majesticTaper(progress);
            final headPin = (i / 3.0).clamp(0.0, 1.0);

            final dx = p2.dx - p1.dx;
            final dy = p2.dy - p1.dy;
            final segLen = sqrt(dx * dx + dy * dy);
            if (segLen > 0.001) {
              final nx = -dy / segLen;
              final ny = dx / segLen;
              final wave = sin(time * 16.0 + i * 0.9) * (ball.radius * 0.62 * taper * headPin);
              firePts.add(Offset((p1.dx + p2.dx) * 0.5 + nx * wave, (p1.dy + p2.dy) * 0.5 + ny * wave));
            }
            firePts.add(p2);
          }

          _stroke
            ..style = PaintingStyle.stroke
            ..strokeCap = StrokeCap.round
            ..strokeJoin = StrokeJoin.round
            ..maskFilter = null;

          // Layer 1: Outer billowing heat haze
          for (int i = 0; i < firePts.length - 1; i++) {
            final progress = (i + 0.5) / (firePts.length - 1);
            final taper = majesticTaper(progress);
            final hazeColor = isCornerBoost
                ? (isRainbowBall ? getCornerBoostColor(i, firePts.length) : cbFlameDeep)
                : trailGlow;
            _stroke
              ..strokeWidth = (ball.radius * 4.4 * taper).clamp(2.0, ball.radius * 4.4)
              ..color = _ca(hazeColor, 0.40 * taper);
            canvas.drawLine(firePts[i], firePts[i + 1], _stroke);
          }

          // Layer 2: Roaring flame ribbon
          for (int i = 0; i < firePts.length - 1; i++) {
            final progress = (i + 0.5) / (firePts.length - 1);
            final taper = majesticTaper(progress);
            final ribbonColor = isCornerBoost
                ? (isRainbowBall ? getCornerBoostColor(i, firePts.length) : cbFlameBase)
                : trailPrimary;
            _stroke
              ..strokeWidth = (ball.radius * 2.65 * taper).clamp(1.4, ball.radius * 2.65)
              ..color = _ca(ribbonColor, 0.92 * taper);
            canvas.drawLine(firePts[i], firePts[i + 1], _stroke);
          }

          // Layer 3: Blinding incandescent core
          for (int i = 0; i < firePts.length - 1; i++) {
            final progress = (i + 0.5) / (firePts.length - 1);
            final taper = majesticTaper(progress);
            _stroke
              ..strokeWidth = (ball.radius * 1.25 * taper).clamp(0.9, ball.radius * 1.25)
              ..color = _ca(isCornerBoost ? (isRainbowBall ? getCornerBoostColor(i, firePts.length) : cbFlameCore) : Color.lerp(trailPrimary, Colors.white, 0.75)!, 0.98 * taper);
            canvas.drawLine(firePts[i], firePts[i + 1], _stroke);
          }

          // Layer 4: Fiery ember sparks
          _fill
            ..style = PaintingStyle.fill
            ..maskFilter = null;
          for (int i = 2; i < trailCount; i += 2) {
            final progress = trailCount > 1 ? i / (trailCount - 1) : 0.0;
            final taper = majesticTaper(progress);
            final pt = ball.trail[i].position;
            final emberPulse = sin(time * 22.0 + i * 1.8) * (ball.radius * 0.50 * taper);
            final emberSize = ball.radius * (0.58 + 0.28 * sin(time * 14 + i)) * taper;
            if (emberSize <= 0.4) continue;
            final emberColor = isCornerBoost
                ? (isRainbowBall ? getCornerBoostColor(i, trailCount) : (i % 4 == 0 ? cbFlameBright : cbFlameBase))
                : (i % 4 == 0 ? trailPrimary : trailGlow);
            _fill.color = _ca(emberColor, 0.92 * taper);
            canvas.drawCircle(Offset(pt.dx + emberPulse, pt.dy - emberPulse), emberSize, _fill);
          }
        } else {
          // Standard / Fireball / CornerBoost trail (Full-bodied & Majestic)
          if (isFireball) {
            // Golden-Flame Searing Ball ("Yakıcı Top") multi-stage inferno trail
            _stroke
              ..style = PaintingStyle.stroke
              ..strokeCap = StrokeCap.round
              ..strokeJoin = StrokeJoin.round
              ..maskFilter = null;

            // Pass 1: Outer blazing orange-amber heat wake
            for (int i = 0; i < trailCount - 1; i++) {
              final progress = (i + 0.5) / (trailCount - 1);
              final taper = majesticTaper(progress);
              _stroke
                ..strokeWidth = (ball.radius * 4.4 * taper).clamp(2.0, ball.radius * 4.4)
                ..color = _ca(const Color(0xFFFF6D00), 0.40 * taper);
              canvas.drawLine(ball.trail[i].position, ball.trail[i + 1].position, _stroke);
            }

            // Pass 2: Mid rich golden-amber flame
            for (int i = 0; i < trailCount - 1; i++) {
              final progress = (i + 0.5) / (trailCount - 1);
              final taper = majesticTaper(progress);
              _stroke
                ..strokeWidth = (ball.radius * 2.75 * taper).clamp(1.4, ball.radius * 2.75)
                ..color = _ca(const Color(0xFFFFAB00), 0.92 * taper);
              canvas.drawLine(ball.trail[i].position, ball.trail[i + 1].position, _stroke);
            }

            // Pass 3: Incandescent pure gold core
            for (int i = 0; i < trailCount - 1; i++) {
              final progress = (i + 0.5) / (trailCount - 1);
              final taper = majesticTaper(progress);
              _stroke
                ..strokeWidth = (ball.radius * 1.45 * taper).clamp(1.0, ball.radius * 1.45)
                ..color = _ca(const Color(0xFFFFD700), 0.98 * taper);
              canvas.drawLine(ball.trail[i].position, ball.trail[i + 1].position, _stroke);
            }

            // Pass 4: White-gold core filament
            for (int i = 0; i < trailCount - 1; i++) {
              final progress = (i + 0.5) / (trailCount - 1);
              final taper = majesticTaper(progress);
              _stroke
                ..strokeWidth = (ball.radius * 0.75 * taper).clamp(0.7, ball.radius * 0.75)
                ..color = _ca(Colors.white, 0.98 * taper);
              canvas.drawLine(ball.trail[i].position, ball.trail[i + 1].position, _stroke);
            }
          } else if (isCornerBoost) {
            // Supersonic Mach wake (Full-bodied, NO blur!)
            _stroke
              ..style = PaintingStyle.stroke
              ..strokeCap = StrokeCap.round
              ..strokeJoin = StrokeJoin.round
              ..maskFilter = null;

            // Pass 1: Outer jet haze
            for (int i = 0; i < trailCount - 1; i++) {
              final progress = (i + 0.5) / (trailCount - 1);
              final taper = majesticTaper(progress);
              final hazeColor = isRainbowBall ? getCornerBoostColor(i, trailCount) : cbFlameDeep;
              _stroke
                ..strokeWidth = (ball.radius * 4.2 * taper).clamp(2.0, ball.radius * 4.2)
                ..color = _ca(hazeColor, 0.38 * taper);
              canvas.drawLine(ball.trail[i].position, ball.trail[i + 1].position, _stroke);
            }

            // Pass 2: Mid plasma thrust ribbon
            for (int i = 0; i < trailCount - 1; i++) {
              final progress = (i + 0.5) / (trailCount - 1);
              final taper = majesticTaper(progress);
              final thrustColor = isRainbowBall ? getCornerBoostColor(i, trailCount) : cbFlameBase;
              _stroke
                ..strokeWidth = (ball.radius * 2.45 * taper).clamp(1.3, ball.radius * 2.45)
                ..color = _ca(thrustColor, 0.92 * taper);
              canvas.drawLine(ball.trail[i].position, ball.trail[i + 1].position, _stroke);
            }

            // Pass 3: Blinding core needle
            for (int i = 0; i < trailCount - 1; i++) {
              final progress = (i + 0.5) / (trailCount - 1);
              final taper = majesticTaper(progress);
              final needleColor = isRainbowBall ? getCornerBoostColor(i, trailCount) : cbFlameCore;
              _stroke
                ..strokeWidth = (ball.radius * 1.15 * taper).clamp(0.8, ball.radius * 1.15)
                ..color = _ca(needleColor, 0.98 * taper);
              canvas.drawLine(ball.trail[i].position, ball.trail[i + 1].position, _stroke);
            }

            // Embedded Mach shock diamond pulses along the trail
            _fill
              ..style = PaintingStyle.fill
              ..maskFilter = null;
            for (int i = 2; i < trailCount; i += 3) {
              final progress = i / (trailCount - 1);
              final taper = majesticTaper(progress);
              final pt = ball.trail[i].position;
              final dSize = ball.radius * (1.15 + 0.35 * sin(time * 30 + i)) * taper;
              if (dSize <= 0.5) continue;

              _tempPath.reset();
              _tempPath.moveTo(pt.dx, pt.dy - dSize * 1.2);
              _tempPath.lineTo(pt.dx + dSize * 0.7, pt.dy);
              _tempPath.lineTo(pt.dx, pt.dy + dSize * 1.2);
              _tempPath.lineTo(pt.dx - dSize * 0.7, pt.dy);
              _tempPath.close();

              final dColor = isRainbowBall ? getCornerBoostColor(i, trailCount) : cbFlameBase;
              _fill.color = _ca(dColor, 0.88 * taper);
              canvas.drawPath(_tempPath, _fill);

              _fill.color = _ca(Colors.white, 0.96 * taper);
              canvas.drawCircle(pt, dSize * 0.38, _fill);
            }
          } else {
            // === VIBRANT UNDULATING ENERGY RIBBON (Default / Standard Trail, Full-Bodied & Majestic) ===
            final wavePts = <Offset>[Offset(ball.x, ball.y)];
            for (int i = 0; i < trailCount - 1; i++) {
              final p1 = ball.trail[i].position;
              final p2 = ball.trail[i + 1].position;
              final progress = i / (trailCount - 1);
              final taper = majesticTaper(progress);
              final headPin = (i / 3.0).clamp(0.0, 1.0);

              final dx = p2.dx - p1.dx;
              final dy = p2.dy - p1.dy;
              final segLen = sqrt(dx * dx + dy * dy);
              if (segLen > 0.001) {
                final nx = -dy / segLen;
                final ny = dx / segLen;
                final wave = sin(time * 12.0 + i * 0.75) * (ball.radius * 0.36 * taper * headPin);
                wavePts.add(Offset((p1.dx + p2.dx) * 0.5 + nx * wave, (p1.dy + p2.dy) * 0.5 + ny * wave));
              }
              wavePts.add(p2);
            }

            _stroke
              ..style = PaintingStyle.stroke
              ..strokeCap = StrokeCap.round
              ..strokeJoin = StrokeJoin.round
              ..maskFilter = null;

            // Layer 1: Outer pulsating luminous bloom segments (thick & rich)
            for (int i = 0; i < wavePts.length - 1; i++) {
              final progress = (i + 0.5) / (wavePts.length - 1);
              final taper = majesticTaper(progress);
              final bloomColor = getBallTrailColor(i, wavePts.length, isGlow: true);
              _stroke
                ..strokeWidth = (ball.radius * 3.9 * taper).clamp(1.8, ball.radius * 3.9)
                ..color = _ca(bloomColor, 0.40 * taper);
              canvas.drawLine(wavePts[i], wavePts[i + 1], _stroke);
            }

            // Layer 2: Main energetic fluid ribbon segments (bold & vibrant)
            for (int i = 0; i < wavePts.length - 1; i++) {
              final progress = (i + 0.5) / (wavePts.length - 1);
              final taper = majesticTaper(progress);
              final coreColor = getBallTrailColor(i, wavePts.length);
              _stroke
                ..strokeWidth = (ball.radius * 2.25 * taper).clamp(1.3, ball.radius * 2.25)
                ..color = _ca(coreColor, 0.94 * taper);
              canvas.drawLine(wavePts[i], wavePts[i + 1], _stroke);
            }

            // Layer 3: Pure starlight white core filament segments
            for (int i = 0; i < wavePts.length - 1; i++) {
              final progress = (i + 0.5) / (wavePts.length - 1);
              final taper = majesticTaper(progress);
              _stroke
                ..strokeWidth = (ball.radius * 0.95 * taper).clamp(0.7, ball.radius * 0.95)
                ..color = _ca(Colors.white, 0.96 * taper);
              canvas.drawLine(wavePts[i], wavePts[i + 1], _stroke);
            }

            // Drifting stardust sparkles along the undulating trail
            _fill
              ..style = PaintingStyle.fill
              ..maskFilter = null;
            for (int i = 0; i < trailCount; i += 3) {
              final progress = trailCount > 1 ? i / (trailCount - 1) : 0.0;
              final taper = majesticTaper(progress);
              final pt = ball.trail[i].position;
              final sparkSize = ball.radius * (0.52 + 0.28 * sin(time * 18 + i)) * taper;
              if (sparkSize <= 0.4) continue;
              final sparkColor = isRainbowBall ? getBallTrailColor(i, trailCount) : Colors.white;
              _fill.color = _ca(sparkColor, 0.88 * taper);
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
        // === CAPSULE SEARING BALL ("YAKICI TOP"): High-FPS Golden-Flame Inferno & Solar Crest (ZERO BLUR LAG) ===
        final flick = 0.78 + 0.22 * sin(time * 28);
        final spd = ball.speed;
        final backAngle = (spd > 15.0) ? atan2(-ball.vy, -ball.vx) : (pi / 2);
        final backX = cos(backAngle);
        final backY = sin(backAngle);
        final perpX = -backY;
        final perpY = backX;

        // 1. Multi-ring Golden-Amber-Orange Heat Corona
        _fill
          ..style = PaintingStyle.fill
          ..maskFilter = null
          ..color = _ca(const Color(0xFFFF6D00), 0.28 * flick);
        canvas.drawCircle(Offset.zero, ball.radius * 2.35 + flick * 3.0, _fill);

        _fill.color = _ca(const Color(0xFFFFAB00), 0.42 * flick);
        canvas.drawCircle(Offset.zero, ball.radius * 1.75 + flick * 2.0, _fill);

        // 2. Opposite-Curling Golden Flame Plume (Trailing Behind Velocity Vector)
        final plumeLen = ball.radius * (3.2 + 0.9 * flick);
        final plumeSpread = ball.radius * 1.15;
        final curlWave = sin(time * 32.0) * (ball.radius * 0.45);

        _tempPath.reset();
        _tempPath.moveTo(perpX * plumeSpread, perpY * plumeSpread);
        _tempPath.quadraticBezierTo(
          backX * (plumeLen * 0.55) + perpX * (plumeSpread * 0.65 + curlWave),
          backY * (plumeLen * 0.55) + perpY * (plumeSpread * 0.65 + curlWave),
          backX * plumeLen + perpX * curlWave,
          backY * plumeLen + perpY * curlWave,
        );
        _tempPath.quadraticBezierTo(
          backX * (plumeLen * 0.55) - perpX * (plumeSpread * 0.65 - curlWave),
          backY * (plumeLen * 0.55) - perpY * (plumeSpread * 0.65 - curlWave),
          -perpX * plumeSpread,
          -perpY * plumeSpread,
        );
        _tempPath.close();

        _fill.color = _ca(const Color(0xFFFF6D00), 0.58 * flick);
        canvas.drawPath(_tempPath, _fill);

        // Inner golden tongue
        _tempPath.reset();
        _tempPath.moveTo(perpX * (plumeSpread * 0.65), perpY * (plumeSpread * 0.65));
        _tempPath.lineTo(
          backX * (plumeLen * 0.72) - perpX * (curlWave * 0.5),
          backY * (plumeLen * 0.72) - perpY * (curlWave * 0.5),
        );
        _tempPath.lineTo(-perpX * (plumeSpread * 0.65), -perpY * (plumeSpread * 0.65));
        _tempPath.close();

        _fill.color = _ca(const Color(0xFFFFD700), 0.88 * flick);
        canvas.drawPath(_tempPath, _fill);

        // 3. Rotating Solar Core Crest (8 Curling Flame Tongues Around Ball)
        const int crestCount = 8;
        final double crestRot = time * 4.2;
        _stroke
          ..style = PaintingStyle.stroke
          ..maskFilter = null
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round
          ..strokeWidth = 2.2;

        for (int i = 0; i < crestCount; i++) {
          final double a = crestRot + i * (2 * pi / crestCount);
          final double tongueR = ball.radius * (1.42 + 0.22 * sin(time * 24.0 + i * 1.5));
          final double baseA1 = a - 0.22;
          final double baseA2 = a + 0.22;
          final double tipA = a + 0.18 * sin(time * 18.0 + i);

          _tempPath.reset();
          _tempPath.moveTo(cos(baseA1) * (ball.radius * 0.92), sin(baseA1) * (ball.radius * 0.92));
          _tempPath.lineTo(cos(tipA) * tongueR, sin(tipA) * tongueR);
          _tempPath.lineTo(cos(baseA2) * (ball.radius * 0.92), sin(baseA2) * (ball.radius * 0.92));
          _tempPath.close();

          _fill.color = _ca(i.isEven ? const Color(0xFFFFD700) : const Color(0xFFFFAB00), 0.82 * flick);
          canvas.drawPath(_tempPath, _fill);
        }

        // Solar crest ring
        _stroke.color = _ca(const Color(0xFFFFD700), 0.95 * flick);
        canvas.drawCircle(Offset.zero, ball.radius * 1.18, _stroke);
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

        // 1. Blinding Corona Glow & Radiant Heat Haze (2-pass alpha, NO blur)
        _fill
          ..style = PaintingStyle.fill
          ..maskFilter = null
          ..color = _ca(cbFlameDeep, 0.22 * flick);
        canvas.drawCircle(Offset.zero, ball.radius * 2.2, _fill);

        _fill.color = _ca(cbFlameBase, 0.44 * flick);
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
          ..color = _ca(cbFlameBright, 0.32 * flick);
        canvas.drawArc(
          Rect.fromCircle(center: bowCenter, radius: ball.radius + 3.5),
          fwdAngle - pi / 2.8,
          pi / 1.4,
          false,
          _stroke,
        );

        _stroke
          ..strokeWidth = 1.8
          ..color = _ca(cbFlameCore, 0.92 * flick);
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
          ..color = _ca(cbFlameBright, 0.65 * flick);
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

        // Outer supersonic exhaust cone
        _tempPath.reset();
        _tempPath.moveTo(perpX * baseWidth, perpY * baseWidth);
        _tempPath.lineTo(-perpX * baseWidth, -perpY * baseWidth);
        _tempPath.lineTo(backX * mainFlameLen, backY * mainFlameLen);
        _tempPath.close();

        _fill
          ..style = PaintingStyle.fill
          ..maskFilter = null
          ..color = _ca(cbFlameDeep, 0.38);
        canvas.drawPath(_tempPath, _fill);

        // Mid plasma thrust cone
        _tempPath.reset();
        _tempPath.moveTo(perpX * (baseWidth * 0.7), perpY * (baseWidth * 0.7));
        _tempPath.lineTo(-perpX * (baseWidth * 0.7), -perpY * (baseWidth * 0.7));
        _tempPath.lineTo(backX * (mainFlameLen * 0.85), backY * (mainFlameLen * 0.85));
        _tempPath.close();

        _fill.color = _ca(cbFlameBase, 0.85);
        canvas.drawPath(_tempPath, _fill);

        // Hyper-dense core jet needle
        _tempPath.reset();
        _tempPath.moveTo(perpX * (baseWidth * 0.35), perpY * (baseWidth * 0.35));
        _tempPath.lineTo(-perpX * (baseWidth * 0.35), -perpY * (baseWidth * 0.35));
        _tempPath.lineTo(backX * (mainFlameLen * 0.55), backY * (mainFlameLen * 0.55));
        _tempPath.close();

        _fill.color = _ca(cbFlameCore, 0.98);
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
            ..color = _ca(cbFlameDeep, 0.38);
          canvas.drawLine(nozzleOffset, nozzleOffset + Offset(sideDirX * sideFlameLen, sideDirY * sideFlameLen), _stroke);

          _stroke
            ..strokeWidth = 1.3
            ..color = _ca(cbFlameCore, 0.95);
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

          // Shock diamond glowing rim (NO blur lag!)
          _fill
            ..style = PaintingStyle.fill
            ..maskFilter = null
            ..color = _ca(cbFlameBase, 0.88);
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
            ..color = _ca(cbFlameBright, 0.88);
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
            ..color = _ca(cbFlameCore, 0.92);
          canvas.drawLine(
            Offset(gPos.dx - cos(gAngle) * gSize, gPos.dy - sin(gAngle) * gSize),
            Offset(gPos.dx + cos(gAngle) * gSize, gPos.dy + sin(gAngle) * gSize),
            _stroke,
          );
          canvas.drawLine(
            Offset(gPos.dx - cos(gAngle + pi / 2) * (gSize * 0.5), gPos.dy - sin(gAngle + pi / 2) * (gSize * 0.5)),
            Offset(gPos.dx + cos(gAngle + pi / 2) * (gSize * 0.5), gPos.dy - sin(gAngle + pi / 2) * (gSize * 0.5)),
            _stroke,
          );
        }

        // 7. YILDIZ IŞILTISI KÖŞEVURUŞU: Kayan Yıldız (Shooting Star / Celestial Comet)
        if (c.activeBallSkin.id == 'isilti') {
          final cometLen = ball.radius * (5.5 + flick * 2.2);
          final cometWidth = ball.radius * 1.25;

          // Dış süzülen altın elmas kuyruk
          _tempPath.reset();
          _tempPath.moveTo(fwdX * (ball.radius * 0.6), fwdY * (ball.radius * 0.6));
          _tempPath.lineTo(perpX * (cometWidth * 0.8), perpY * (cometWidth * 0.8));
          _tempPath.lineTo(backX * cometLen, backY * cometLen);
          _tempPath.lineTo(-perpX * (cometWidth * 0.8), -perpY * (cometWidth * 0.8));
          _tempPath.close();

          _fill
            ..style = PaintingStyle.fill
            ..maskFilter = null
            ..color = _ca(const Color(0xFFFFD54F), 0.38 * flick);
          canvas.drawPath(_tempPath, _fill);

          // İç gümüş/altın yıldız tozu huzmesi
          _tempPath.reset();
          _tempPath.moveTo(fwdX * (ball.radius * 0.4), fwdY * (ball.radius * 0.4));
          _tempPath.lineTo(perpX * (cometWidth * 0.35), perpY * (cometWidth * 0.35));
          _tempPath.lineTo(backX * (cometLen * 0.7), backY * (cometLen * 0.7));
          _tempPath.lineTo(-perpX * (cometWidth * 0.35), -perpY * (cometWidth * 0.35));
          _tempPath.close();

          _fill.color = _ca(Colors.white, 0.85 * flick);
          canvas.drawPath(_tempPath, _fill);

          // Kayan yıldızın arkasında süzülen ışıltılı yıldız tozları
          for (int sp = 0; sp < 5; sp++) {
            final pDist = ball.radius * (1.5 + sp * 1.1 + sin(time * 24 + sp * 1.8) * 0.3);
            final pLat = sin(time * 28 + sp * 2.3) * (ball.radius * 0.55);
            final pPos = Offset(backX * pDist + perpX * pLat, backY * pDist + perpY * pLat);
            final pStarSize = ball.radius * (0.35 - sp * 0.04).clamp(0.15, 0.45);

            _stroke
              ..style = PaintingStyle.stroke
              ..strokeWidth = 1.2
              ..color = _ca(const Color(0xFFFFF9C4), (0.9 - sp * 0.12).clamp(0.2, 1.0));
            canvas.drawLine(Offset(pPos.dx - pStarSize, pPos.dy), Offset(pPos.dx + pStarSize, pPos.dy), _stroke);
            canvas.drawLine(Offset(pPos.dx, pPos.dy - pStarSize), Offset(pPos.dx, pPos.dy + pStarSize), _stroke);

            _fill.color = _ca(Colors.white, 0.95);
            canvas.drawCircle(pPos, 1.2, _fill);
          }
        }
      }

      if (!isFireball && !isCornerBoost && !ball.isPurple && !ball.isBomb && !ball.isFrost && !ball.isShrapnel) {
        _drawBallSkinDetails(canvas, ball, c.activeBallSkin, time);
      } else {
        // Base ball glow ring
        final glowColor = ball.isPurple
            ? const Color(0xFFE040FB)
            : (isFireball
                ? const Color(0xFFFFAB00)
                : (isCornerBoost
                    ? cbFlameGlow
                    : (ball.isFrost
                        ? const Color(0xFF80D8FF)
                        : (ball.isShrapnel ? const Color(0xFFCFD8DC) : (ball.isBomb ? const Color(0xFFFF5252) : skinGlow)))));
        _fill
          ..style = PaintingStyle.fill
          ..maskFilter = null
          ..color = _ca(glowColor, 0.42);
        canvas.drawCircle(Offset.zero, ball.radius + 4.8, _fill);

        // Ball Core
        final coreColor = ball.isPurple
            ? const Color(0xFFAA00FF)
            : (isFireball
                ? const Color(0xFFFF6D00)
                : (isCornerBoost
                    ? cbFlameBase
                    : (ball.isFrost
                        ? const Color(0xFF00B0FF)
                        : (ball.isShrapnel ? const Color(0xFF78909C) : (ball.isBomb ? const Color(0xFFFF5252) : skinMain)))));
        _fill.color = coreColor;
        canvas.drawCircle(Offset.zero, ball.radius, _fill);

        if (isFireball) {
          // Blazing golden-solar center
          _fill.color = const Color(0xFFFFD700);
          canvas.drawCircle(Offset.zero, ball.radius * 0.68, _fill);
          _fill.color = const Color(0xFFFFF9C4);
          canvas.drawCircle(Offset.zero, ball.radius * 0.45, _fill);
          _fill.color = Colors.white;
          canvas.drawCircle(Offset.zero, ball.radius * 0.25, _fill);
        } else if (isCornerBoost) {
          // Luminous flame core glint
          _fill.color = _ca(cbFlameCore, 0.85);
          canvas.drawCircle(Offset.zero, ball.radius * 0.55, _fill);
          _fill.color = Colors.white;
          canvas.drawCircle(Offset.zero, ball.radius * 0.30, _fill);
        } else if (ball.isFrost) {
          // Multi-layer Sub-zero Crystal Aura with radiant frost star
          _fill.color = const Color(0xFF00E5FF).withValues(alpha: 0.35 + 0.12 * sin(time * 8.0));
          canvas.drawCircle(Offset.zero, ball.radius * 1.65, _fill);
          _fill.color = const Color(0xFF80D8FF).withValues(alpha: 0.50);
          canvas.drawCircle(Offset.zero, ball.radius * 1.25, _fill);
          _fill.color = const Color(0xFFE0F7FA);
          canvas.drawCircle(Offset.zero, ball.radius * 0.70, _fill);
          _stroke
            ..color = const Color(0xFFB3E5FC)
            ..strokeWidth = 1.5
            ..style = PaintingStyle.stroke;
          final flakeSpin = time * 2.8;
          for (int spoke = 0; spoke < 6; spoke++) {
            final a = flakeSpin + spoke * pi / 3;
            final tipX = cos(a) * ball.radius * 0.65;
            final tipY = sin(a) * ball.radius * 0.65;
            canvas.drawLine(Offset.zero, Offset(tipX, tipY), _stroke);
            final branchA1 = a + pi / 4;
            final branchA2 = a - pi / 4;
            final midX = cos(a) * ball.radius * 0.40;
            final midY = sin(a) * ball.radius * 0.40;
            canvas.drawLine(Offset(midX, midY), Offset(midX + cos(branchA1) * 3.5, midY + sin(branchA1) * 3.5), _stroke);
            canvas.drawLine(Offset(midX, midY), Offset(midX + cos(branchA2) * 3.5, midY + sin(branchA2) * 3.5), _stroke);
          }
          _fill.color = Colors.white;
          canvas.drawCircle(Offset.zero, ball.radius * 0.28, _fill);
        } else if (ball.isShrapnel) {
          // Metallic steel core
          _fill.color = const Color(0xFFECEFF1);
          canvas.drawCircle(Offset.zero, ball.radius * 0.55, _fill);
          _fill.color = Colors.white;
          canvas.drawCircle(Offset.zero, ball.radius * 0.28, _fill);
        }

        // Specular shine
        final rEff = ball.effectiveRadius;
        _fill.color = _ca(Colors.white, (isFireball || isCornerBoost || ball.megaTimer > 0) ? 0.90 : 0.55);
        canvas.drawCircle(Offset(-rEff * 0.28, -rEff * 0.28), rEff * 0.38, _fill);
        _fill.color = _ca(Colors.white, 0.95);
        canvas.drawCircle(Offset(-rEff * 0.38, -rEff * 0.38), rEff * 0.16, _fill);
      }

      if (ball.isDayBlessed) {
        _stroke
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.6
          ..shader = null
          ..color = const Color(0xCCFFD54F);
        canvas.drawCircle(Offset.zero, ball.radius + 5.2, _stroke);
      }

      canvas.restore();
    }
  }

  void _drawBallSkinDetails(Canvas canvas, Ball ball, BallSkin skin, double time) {
    final r = ball.effectiveRadius;

    // Mega Ball solar flare corona
    if (ball.megaTimer > 0) {
      final pulse = 0.82 + 0.18 * sin(time * 16.0);
      _fill
        ..style = PaintingStyle.fill
        ..color = const Color(0xFFFFD700).withValues(alpha: 0.35 * pulse);
      canvas.drawCircle(Offset.zero, r * 1.55, _fill);
      _stroke
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.4
        ..color = const Color(0xFFFF9100).withValues(alpha: 0.90 * pulse);
      canvas.drawCircle(Offset.zero, r * 1.25, _stroke);
    }

    // Outer glow halo (rich & prominent)
    _fill
      ..style = PaintingStyle.fill
      ..maskFilter = null
      ..color = _ca(skin.glowColor, 0.45);
    canvas.drawCircle(Offset.zero, r + 4.8, _fill);

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

    // Crisp luminous outer rim stroke for majestic ball presence
    _stroke
      ..style = PaintingStyle.stroke
      ..maskFilter = null
      ..strokeWidth = 1.6
      ..color = _ca(skin.glowColor, 0.85);
    canvas.drawCircle(Offset.zero, r, _stroke);

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
        // Yıldız Işıltısı (Epic): Radiant celestial starlight core, 8-point rotating crystalline flare & orbiting stardust
        final sa = time * 2.2;
        final pulse = 0.85 + sin(time * 6.0) * 0.15;
        
        // 1. Radiant celestial starlight halo corona
        _stroke
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.6
          ..color = _ca(const Color(0xFFFFE082), 0.70 * pulse);
        canvas.drawCircle(Offset.zero, r * 1.15, _stroke);

        // 2. Primary 4-point radiant stellar flare rays
        final rayLen1 = r * 1.55 * pulse;
        _stroke
          ..strokeWidth = 2.2
          ..color = const Color(0xFFFFFDE7);
        canvas.drawLine(Offset(-cos(sa) * rayLen1, -sin(sa) * rayLen1), Offset(cos(sa) * rayLen1, sin(sa) * rayLen1), _stroke);
        canvas.drawLine(Offset(-cos(sa + pi / 2) * rayLen1, -sin(sa + pi / 2) * rayLen1), Offset(cos(sa + pi / 2) * rayLen1, sin(sa + pi / 2) * rayLen1), _stroke);

        // 3. Secondary 4-point diagonal diamond glint rays (offset by 45 degrees)
        final rayLen2 = r * 0.90 * pulse;
        _stroke
          ..strokeWidth = 1.3
          ..color = const Color(0xFFFFD54F);
        canvas.drawLine(Offset(-cos(sa + pi / 4) * rayLen2, -sin(sa + pi / 4) * rayLen2), Offset(cos(sa + pi / 4) * rayLen2, sin(sa + pi / 4) * rayLen2), _stroke);
        canvas.drawLine(Offset(-cos(sa + 3 * pi / 4) * rayLen2, -sin(sa + 3 * pi / 4) * rayLen2), Offset(cos(sa + 3 * pi / 4) * rayLen2, sin(sa + 3 * pi / 4) * rayLen2), _stroke);

        // 4. Brilliant center diamond core glint
        _fill.color = Colors.white;
        canvas.drawCircle(Offset.zero, 2.2 * pulse, _fill);

        // 5. Four orbiting celestial stardust embers
        for (int i = 0; i < 4; i++) {
          final oa = -time * 3.0 + i * (pi / 2);
          final od = r * (0.65 + 0.15 * sin(time * 4.0 + i));
          _fill.color = (i.isEven) ? const Color(0xFFFFF9C4) : const Color(0xFFFFCA28);
          canvas.drawCircle(Offset(cos(oa) * od, sin(oa) * od), 1.2, _fill);
        }
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
        // === PRIZMATIK ELMAS (Multifaceted Brilliant Diamond Cut & Prismatic Refractions) ===
        // Çok yüzeyli parlak pırlanta fasetleri (octagonal table + crown facets)
        final diamondAngle = time * 1.4;
        canvas.save();
        canvas.rotate(diamondAngle);

        // 1. Dış 8-gen pırlanta faset çerçevesi (Octagonal Facet Border)
        final outerHex = Path();
        const int numSides = 8;
        for (int i = 0; i < numSides; i++) {
          final a = i * (2 * pi / numSides);
          final px = cos(a) * (r * 0.88);
          final py = sin(a) * (r * 0.88);
          if (i == 0) {
            outerHex.moveTo(px, py);
          } else {
            outerHex.lineTo(px, py);
          }
        }
        outerHex.close();

        _stroke
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.4
          ..color = const Color(0xFF00E5FF);
        canvas.drawPath(outerHex, _stroke);

        // 2. İç faset tablası (Inner Diamond Table Face)
        final innerHex = Path();
        for (int i = 0; i < numSides; i++) {
          final a = i * (2 * pi / numSides) + (pi / numSides);
          final px = cos(a) * (r * 0.48);
          final py = sin(a) * (r * 0.48);
          if (i == 0) {
            innerHex.moveTo(px, py);
          } else {
            innerHex.lineTo(px, py);
          }
        }
        innerHex.close();

        _stroke
          ..strokeWidth = 1.1
          ..color = const Color(0xFFB2EBF2);
        canvas.drawPath(innerHex, _stroke);

        // 3. Faset birleşim çizgileri (Crown to Table Kite Facet Radiants)
        for (int i = 0; i < numSides; i++) {
          final a1 = i * (2 * pi / numSides);
          final a2 = i * (2 * pi / numSides) + (pi / numSides);
          canvas.drawLine(
            Offset(cos(a1) * (r * 0.88), sin(a1) * (r * 0.88)),
            Offset(cos(a2) * (r * 0.48), sin(a2) * (r * 0.48)),
            _stroke,
          );
        }
        canvas.restore();

        // 4. Işık Kırılmalı Gökkuşağı Parıltıları (Prismatic Spectral Refraction Flare)
        final hueShift = (time * 180) % 360;
        final prismColor = HSLColor.fromAHSL(0.85, hueShift, 1.0, 0.70).toColor();
        _stroke
          ..strokeWidth = 1.3
          ..color = prismColor;
        canvas.drawCircle(Offset.zero, r * 0.65, _stroke);

        // 5. Blinding Diamond Sparkle Star (8-point brilliant cut star gleam)
        final gleamLen = r * 1.4;
        final gleamShort = r * 0.65;
        final ga = time * 2.8;
        _stroke
          ..strokeWidth = 1.6
          ..color = Colors.white;
        canvas.drawLine(Offset(-cos(ga) * gleamLen, -sin(ga) * gleamLen), Offset(cos(ga) * gleamLen, sin(ga) * gleamLen), _stroke);
        canvas.drawLine(Offset(-cos(ga + pi / 2) * gleamLen, -sin(ga + pi / 2) * gleamLen), Offset(cos(ga + pi / 2) * gleamLen, sin(ga + pi / 2) * gleamLen), _stroke);
        _stroke
          ..strokeWidth = 1.0
          ..color = const Color(0xFFE0F7FA);
        canvas.drawLine(Offset(-cos(ga + pi / 4) * gleamShort, -sin(ga + pi / 4) * gleamShort), Offset(cos(ga + pi / 4) * gleamShort, sin(ga + pi / 4) * gleamShort), _stroke);
        canvas.drawLine(Offset(-cos(ga - pi / 4) * gleamShort, -sin(ga - pi / 4) * gleamShort), Offset(cos(ga - pi / 4) * gleamShort, sin(ga - pi / 4) * gleamShort), _stroke);
        break;

      case 'gokkusagi':
        // === GÖKKUŞAĞI TOPU (Smooth Celestial Pastel Spectrum Ball - Eye-Friendly) ===
        // 1. Dingin, yumuşak renk geçişli dış aura halkası (15 deg/s yavaş ve göz yormayan geçiş)
        final rainbowHue = (time * 15.0) % 360.0;
        final rColor1 = HSLColor.fromAHSL(1.0, rainbowHue, 0.65, 0.60).toColor();
        final rColor2 = HSLColor.fromAHSL(1.0, (rainbowHue + 120) % 360, 0.60, 0.62).toColor();
        final rColor3 = HSLColor.fromAHSL(1.0, (rainbowHue + 240) % 360, 0.60, 0.62).toColor();

        _stroke
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.4
          ..color = _ca(rColor1, 0.80);
        canvas.drawCircle(Offset.zero, r * 0.82, _stroke);

        // 2. Yavaş, sakin dönen çift spektrum yörünge halkası (0.6 rad/s huzurlu salınım)
        canvas.save();
        canvas.rotate(time * 0.6);
        _stroke
          ..strokeWidth = 1.1
          ..color = _ca(rColor2, 0.70);
        canvas.drawOval(Rect.fromCenter(center: Offset.zero, width: r * 1.6, height: r * 0.50), _stroke);

        canvas.rotate(pi / 3);
        _stroke.color = _ca(rColor3, 0.70);
        canvas.drawOval(Rect.fromCenter(center: Offset.zero, width: r * 1.6, height: r * 0.50), _stroke);
        canvas.restore();

        // 3. Dingin sedefli inci çekirdeği (göz almayan saf beyaz-pastel ışıltı)
        _fill
          ..style = PaintingStyle.fill
          ..color = const Color(0xFFF8F9FA);
        canvas.drawCircle(Offset.zero, r * 0.28, _fill);

        final rStarAngle = -time * 0.5;
        final rStarLen = r * 0.90;
        _stroke
          ..strokeWidth = 1.0
          ..color = _ca(Colors.white, 0.80);
        canvas.drawLine(Offset(-cos(rStarAngle) * rStarLen, -sin(rStarAngle) * rStarLen), Offset(cos(rStarAngle) * rStarLen, sin(rStarAngle) * rStarLen), _stroke);
        canvas.drawLine(Offset(-cos(rStarAngle + pi / 2) * rStarLen, -sin(rStarAngle + pi / 2) * rStarLen), Offset(cos(rStarAngle + pi / 2) * rStarLen, sin(rStarAngle + pi / 2) * rStarLen), _stroke);
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
          ? ' 12 - MEGA JACKPOT! ' : (total == 11
              ? ' 11 - EPİK ŞANS! ' : (total == 10 ? ' 10 - BÜYÜK KAZANÇ! ' : ' X SALVO '));

      _tp.text = TextSpan(
        text: text,
        style: TextStyle(
          fontFamily: 'Rajdhani',
          fontFamilyFallback: const ['Segoe UI Emoji', 'Segoe UI Symbol'],
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

      // Glowing aura around falling capsule matching powerup color (or crimson hazard halo for debuffs)
      final pulse = sin(cap.animTimer * 7.0);
      final isDebuff = cap.type.kind == PowerUpKind.debuff;
      if (isDebuff) {
        final dangerPulse = 0.75 + 0.25 * sin(cap.animTimer * 12.0);
        _fill.color = const Color(0xFFFF1744).withValues(alpha: 0.28 * dangerPulse);
        canvas.drawCircle(Offset.zero, 22.0 + pulse * 2.5, _fill);
        _fill.color = const Color(0xFFD50000).withValues(alpha: 0.14);
        canvas.drawCircle(Offset.zero, 27.0, _fill);

        _stroke
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.0
          ..color = const Color(0xFFFF5252).withValues(alpha: 0.85 * dangerPulse);
        canvas.drawCircle(Offset.zero, 20.5 + pulse * 1.5, _stroke);
      } else {
        _fill.color = cap.type.color.withValues(alpha: 0.24 + 0.08 * pulse);
        canvas.drawCircle(Offset.zero, 19.0 + pulse * 2.0, _fill);
        _fill.color = cap.type.color.withValues(alpha: 0.12);
        canvas.drawCircle(Offset.zero, 25.0, _fill);
      }

      if (cap.type == PowerUpType.life) {
        final heartPulse = 1.0 + sin(cap.animTimer * 7.0) * 0.12;
        PixelArt.drawPixelHeart(canvas, Offset.zero, 34.0, pulse: heartPulse);
      } else {
        final img = AssetCache.instance.getSkillImage(cap.type);
        if (img != null) {
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
      } else if (p.isShrapnel) {
        _fill.color = const Color(0xFFCFD8DC);
        canvas.drawCircle(Offset(p.x, p.y), p.radius, _fill);
        _fill.color = Colors.white;
        canvas.drawCircle(Offset(p.x - 0.7, p.y - 0.7), p.radius * 0.45, _fill);
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

  void _drawCoinOrbs(Canvas canvas) {
    for (final orb in c.particles.coinOrbs) {
      // Glowing motion trail while flying to the counter
      for (int i = 0; i < orb.trail.length; i++) {
        final t = orb.trail[i];
        final a = (i + 1) / orb.trail.length;
        _fill.color = orb.color.withValues(alpha: 0.10 + a * 0.22);
        canvas.drawCircle(t, 3.0 + a * 3.5, _fill);
      }
      final glow = orb.isGlowing ? 1.0 + sin(time * 18.0) * 0.25 : 1.0;
      final r = orb.size * glow;
      // Soft halo
      _fill.color = orb.color.withValues(alpha: 0.28);
      canvas.drawCircle(Offset(orb.x, orb.y), r * 1.7, _fill);
      // Coin body with a darker forged rim
      _fill.color = const Color(0xFFFF8F00);
      canvas.drawCircle(Offset(orb.x, orb.y), r, _fill);
      _fill.color = orb.color;
      canvas.drawCircle(Offset(orb.x, orb.y), r * 0.78, _fill);
      // Rotating shine sweep across the face
      final sx = orb.x + cos(orb.spin) * r * 0.38;
      final sy = orb.y + sin(orb.spin) * r * 0.38;
      _fill.color = const Color(0xFFFFF9C4);
      canvas.drawCircle(Offset(sx - r * 0.18, sy - r * 0.18), r * 0.30, _fill);
      _fill.color = Colors.white.withValues(alpha: 0.85);
      canvas.drawCircle(Offset(orb.x - r * 0.28, orb.y - r * 0.30), r * 0.16, _fill);
    }
  }

  void _drawFeverEdges(Canvas canvas, Size size) {
    // Cinematic organic fever warmth: natural breathing vignette without hard borders or abrupt cutoffs
    final pulse = 0.75 + sin(time * 5.5) * 0.25;
    final w = size.width;
    final h = size.height;
    final rect = Offset.zero & size;

    // 1. Smooth omnidirectional radial crimson vignette
    _fill
      ..style = PaintingStyle.fill
      ..shader = RadialGradient(
        center: Alignment.center,
        radius: 1.05,
        colors: [
          Colors.transparent,
          const Color(0x05FF3D00),
          Color.lerp(const Color(0x18FF1744), const Color(0x28FF3D00), pulse)!,
          Color.lerp(const Color(0x32D50000), const Color(0x48FF1744), pulse)!,
          Color.lerp(const Color(0x50880E4F), const Color(0x65B71C1C), pulse)!,
        ],
        stops: const [0.28, 0.52, 0.74, 0.90, 1.0],
      ).createShader(rect);
    canvas.drawRect(rect, _fill);

    // 2. Soft atmospheric top & bottom perimeter glows (blends seamlessly on tall phone screens)
    final topH = h * 0.16;
    _fill.shader = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [
        Color.lerp(const Color(0x40D50000), const Color(0x55FF1744), pulse)!,
        Colors.transparent,
      ],
      stops: const [0.0, 1.0],
    ).createShader(Rect.fromLTWH(0, 0, w, topH));
    canvas.drawRect(Rect.fromLTWH(0, 0, w, topH), _fill);

    final botH = h * 0.16;
    _fill.shader = LinearGradient(
      begin: Alignment.bottomCenter,
      end: Alignment.topCenter,
      colors: [
        Color.lerp(const Color(0x45D50000), const Color(0x60FF1744), pulse)!,
        Colors.transparent,
      ],
      stops: const [0.0, 1.0],
    ).createShader(Rect.fromLTWH(0, h - botH, w, botH));
    canvas.drawRect(Rect.fromLTWH(0, h - botH, w, botH), _fill);

    // 3. Soft lateral side vignettes (left & right)
    final sideW = w * 0.12;
    _fill.shader = LinearGradient(
      begin: Alignment.centerLeft,
      end: Alignment.centerRight,
      colors: [
        Color.lerp(const Color(0x35D50000), const Color(0x45FF3D00), pulse)!,
        Colors.transparent,
      ],
    ).createShader(Rect.fromLTWH(0, 0, sideW, h));
    canvas.drawRect(Rect.fromLTWH(0, 0, sideW, h), _fill);

    _fill.shader = LinearGradient(
      begin: Alignment.centerRight,
      end: Alignment.centerLeft,
      colors: [
        Color.lerp(const Color(0x35D50000), const Color(0x45FF3D00), pulse)!,
        Colors.transparent,
      ],
    ).createShader(Rect.fromLTWH(w - sideW, 0, sideW, h));
    canvas.drawRect(Rect.fromLTWH(w - sideW, 0, sideW, h), _fill);
    _fill.shader = null;
  }

  void _drawReviveFlash(Canvas canvas, Size size) {
    if (c.reviveFlashTimer <= 0.01) return;
    // Grayscale shatters outward into full color on revive.
    final t = c.reviveFlashTimer.clamp(0.0, 1.0);
    if (t <= 0.01) return;
    final radius = (1.0 - t) * size.width * 0.75 + 40.0;
    _stroke
      ..color = const Color(0xFFFFD54F).withValues(alpha: (t * 0.9).clamp(0.0, 1.0))
      ..strokeWidth = 4.0 + t * 5.0
      ..style = PaintingStyle.stroke;
    canvas.drawCircle(Offset(size.width / 2, size.height * 0.72), radius, _stroke);
    _fill.color = Colors.white.withValues(alpha: (t * 0.16).clamp(0.0, 1.0));
    canvas.drawRect(Offset.zero & size, _fill);
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
          fontFamily: 'Rajdhani',
          fontFamilyFallback: const ['Segoe UI Emoji', 'Segoe UI Symbol'],
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

  void _drawTargetLock(Canvas canvas) {
    final target = c.lockedTargetBrick;
    if (target == null || !target.isAlive) return;

    final tx = target.x + target.width / 2;
    final ty = target.y + target.height / 2;
    final ball = c.targetLockingBall ?? (c.balls.isNotEmpty ? c.balls.first : null);

    // 1. Animated Dashed Trajectory Line from Ball to Target ("çizgi çizgi izi takip etsin")
    if (ball != null && !ball.isStuck) {
      final dx = tx - ball.x;
      final dy = ty - ball.y;
      final dist = sqrt(dx * dx + dy * dy);
      if (dist > 15.0) {
        final dirX = dx / dist;
        final dirY = dy / dist;
        const dashLen = 9.0;
        const gapLen = 7.0;
        const step = dashLen + gapLen;
        final phase = (time * 52.0) % step;

        _stroke
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..maskFilter = null;

        double d = phase;
        while (d < dist - 10.0) {
          final segEnd = min(d + dashLen, dist - 10.0);
          final p1 = Offset(ball.x + dirX * d, ball.y + dirY * d);
          final p2 = Offset(ball.x + dirX * segEnd, ball.y + dirY * segEnd);

          // Outer cyan laser glow
          _stroke
            ..strokeWidth = 3.2
            ..color = const Color(0xFF00E5FF).withValues(alpha: 0.35);
          canvas.drawLine(p1, p2, _stroke);

          // Inner bright core
          _stroke
            ..strokeWidth = 1.5
            ..color = Colors.white.withValues(alpha: 0.90);
          canvas.drawLine(p1, p2, _stroke);

          d += step;
        }

        // Animated laser tracking pulse traveling along the trajectory line
        final pulseProgress = (time * 1.8) % 1.0;
        final pulseX = ball.x + dirX * (dist * pulseProgress);
        final pulseY = ball.y + dirY * (dist * pulseProgress);
        _fill.color = const Color(0xFF00E5FF).withValues(alpha: 0.85);
        canvas.drawCircle(Offset(pulseX, pulseY), 3.5, _fill);
        _fill.color = Colors.white;
        canvas.drawCircle(Offset(pulseX, pulseY), 1.8, _fill);
      }
    }

    // 2. High-Tech Cyber Reticle (Nişangah) on Target Brick
    canvas.save();
    canvas.translate(tx, ty);

    final pulse = 1.0 + 0.08 * sin(time * 10.0);
    final reticleW = (target.width * 0.55 + 8.0) * pulse;
    final reticleH = (target.height * 0.55 + 8.0) * pulse;
    const cornerArm = 7.0;

    _stroke
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.square
      ..maskFilter = null;

    final lockColor = ((time * 8.0).floor() % 2 == 0)
        ? const Color(0xFF00E5FF)
        : const Color(0xFFFF1744);

    _stroke.color = lockColor;

    // Top-Left bracket
    canvas.drawLine(Offset(-reticleW, -reticleH), Offset(-reticleW + cornerArm, -reticleH), _stroke);
    canvas.drawLine(Offset(-reticleW, -reticleH), Offset(-reticleW, -reticleH + cornerArm), _stroke);

    // Top-Right bracket
    canvas.drawLine(Offset(reticleW, -reticleH), Offset(reticleW - cornerArm, -reticleH), _stroke);
    canvas.drawLine(Offset(reticleW, -reticleH), Offset(reticleW, -reticleH + cornerArm), _stroke);

    // Bottom-Left bracket
    canvas.drawLine(Offset(-reticleW, reticleH), Offset(-reticleW + cornerArm, reticleH), _stroke);
    canvas.drawLine(Offset(-reticleW, reticleH), Offset(-reticleW, reticleH - cornerArm), _stroke);

    // Bottom-Right bracket
    canvas.drawLine(Offset(reticleW, reticleH), Offset(reticleW - cornerArm, reticleH), _stroke);
    canvas.drawLine(Offset(reticleW, reticleH), Offset(reticleW, reticleH - cornerArm), _stroke);

    // Rotating radar tick ring
    canvas.save();
    canvas.rotate(time * 2.5);
    final ringRadius = max(reticleW, reticleH) * 0.85;
    _stroke
      ..strokeWidth = 1.2
      ..color = const Color(0xFF00E5FF).withValues(alpha: 0.5);
    for (int i = 0; i < 4; i++) {
      final a = i * (pi / 2);
      canvas.drawLine(
        Offset(cos(a) * (ringRadius - 3.0), sin(a) * (ringRadius - 3.0)),
        Offset(cos(a) * (ringRadius + 3.0), sin(a) * (ringRadius + 3.0)),
        _stroke,
      );
    }
    canvas.restore();

    // Center crosshair ticks
    _stroke
      ..strokeWidth = 1.4
      ..color = const Color(0xFFFF1744);
    canvas.drawLine(const Offset(-4, 0), const Offset(4, 0), _stroke);
    canvas.drawLine(const Offset(0, -4), const Offset(0, 4), _stroke);

    // Center pulsing target pip
    _fill.color = const Color(0xFFFF1744).withValues(alpha: 0.9);
    canvas.drawCircle(Offset.zero, 2.2 * pulse, _fill);

    // Tech Badge Label above the target
    _tp.text = const TextSpan(
      text: 'LOCK-ON',
      style: TextStyle(
        color: Color(0xFF00E5FF),
        fontSize: 8.5,
        fontWeight: FontWeight.w900,
        letterSpacing: 1.2,
      ),
    );
    _tp.layout();
    _tp.paint(canvas, Offset(-_tp.width / 2, -reticleH - 12.0));

    canvas.restore();
  }

  void _drawShards(Canvas canvas) {
    if (c.particles.shards.isEmpty) return;
    for (final s in c.particles.shards) {
      final alpha = (s.life / s.maxLife).clamp(0.0, 1.0);
      if (alpha <= 0) continue;

      canvas.save();
      canvas.translate(s.x, s.y);
      canvas.rotate(s.rotation);

      // Step 3: Bloklar etrafa küçük, sert keskin piksel parçacıkları (pixel chunks) halinde zıplayarak dağılır
      final hw = s.width / 2;
      final hh = s.height / 2;
      final chunkRect = Rect.fromLTRB(-hw, -hh, hw, hh);

      // Main pixel chunk fill
      _fill
        ..shader = null
        ..maskFilter = null
        ..color = _ca(s.color, alpha);
      canvas.drawRect(chunkRect, _fill);

      // Top-left 1.2px crisp pixel highlight
      _fill.color = _ca(Colors.white, alpha * 0.9);
      canvas.drawRect(Rect.fromLTWH(-hw, -hh, hw, 1.2), _fill);
      canvas.drawRect(Rect.fromLTWH(-hw, -hh, 1.2, hh), _fill);

      // 1px Dark solid retro outline
      _stroke
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0
        ..color = _ca(const Color(0xFF0B1021), alpha * 0.95);
      canvas.drawRect(chunkRect, _stroke);

      canvas.restore();
    }
  }

  /// Step 2: Soldan sağa doğru kare piksellerden oluşan bir dalga yayılır
  void _drawPixelShockwaves(Canvas canvas) {
    if (c.particles.pixelShockwaves.isEmpty) return;
    for (final pw in c.particles.pixelShockwaves) {
      final p = pw.progress.clamp(0.0, 1.0);
      final alpha = (1.0 - p).clamp(0.0, 1.0);
      if (alpha <= 0) continue;

      const totalCols = 7;
      final stepW = pw.width / totalCols;
      const pxSize = 4.0;

      for (int col = 0; col < totalCols; col++) {
        // Staggered column progress from left to right (soldan sağa dalga)
        final colDelay = (col / totalCols) * 0.35;
        final colP = ((p - colDelay) / (1.0 - colDelay)).clamp(0.0, 1.0);
        if (colP <= 0 || colP >= 1.0) continue;

        final colAlpha = (1.0 - colP) * alpha;
        final colX = pw.x + col * stepW;
        final spreadY = pw.height * (0.5 + colP * 0.85);

        for (double dy = -spreadY; dy <= spreadY; dy += 6.0) {
          final chunkRect = Rect.fromCenter(
            center: Offset(colX + stepW / 2, pw.y + pw.height / 2 + dy),
            width: pxSize,
            height: pxSize,
          );

          _fill
            ..shader = null
            ..maskFilter = null
            ..color = _ca(pw.color, colAlpha);
          canvas.drawRect(chunkRect, _fill);

          _stroke
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.0
            ..color = _ca(const Color(0xFF0B1021), colAlpha * 0.85);
          canvas.drawRect(chunkRect, _stroke);
        }
      }
    }
  }

  void _drawBossWarningBanner(Canvas canvas, Size size) {
    if (c.bossWarningTimer <= 0) return;
    final timer = c.bossWarningTimer;
    // Fade in during first 0.3s, fade out in last 0.3s
    final alpha = (timer < 0.3 ? timer / 0.3 : (2.2 - timer < 0.3 ? (2.2 - timer) / 0.3 : 1.0)).clamp(0.0, 1.0);

    final bannerH = 54.0;
    final bannerY = size.height * 0.32;
    final bannerRect = Rect.fromLTWH(0, bannerY - bannerH / 2, size.width, bannerH);

    // Dark translucent backdrop
    _fill.color = _ca(const Color(0xDD0B0D18), alpha);
    canvas.drawRect(bannerRect, _fill);

    // Animated hazard stripes along top and bottom border
    final stripeOffset = (time * 48.0) % 24.0;
    _stroke
      ..strokeWidth = 3.0
      ..color = _ca(const Color(0xFFFFD54F), alpha * 0.9);

    for (double sx = -24.0 + stripeOffset; sx < size.width + 24.0; sx += 24.0) {
      canvas.drawLine(Offset(sx, bannerRect.top), Offset(sx + 10, bannerRect.top + 5), _stroke);
      canvas.drawLine(Offset(sx, bannerRect.bottom - 5), Offset(sx + 10, bannerRect.bottom), _stroke);
    }

    // Glowing border lines
    _stroke
      ..strokeWidth = 2.0
      ..color = _ca(const Color(0xFFFF1744), alpha);
    canvas.drawLine(Offset(0, bannerRect.top), Offset(size.width, bannerRect.top), _stroke);
    canvas.drawLine(Offset(0, bannerRect.bottom), Offset(size.width, bannerRect.bottom), _stroke);

    // Pulsating Warning Text
    final textPulse = 1.0 + 0.06 * sin(time * 12.0);
    _tp.text = TextSpan(
      text: I18n.tr('boss_incoming_warning'),
      style: TextStyle(
        fontFamily: 'Rajdhani',
        fontFamilyFallback: const ['Segoe UI Emoji', 'Segoe UI Symbol'],
        color: _ca(const Color(0xFFFF1744), alpha),
        fontSize: 16.0 * textPulse,
        fontWeight: FontWeight.w900,
        letterSpacing: 2.0,
        shadows: [
          Shadow(color: _ca(const Color(0xFFFF1744), alpha * 0.7), blurRadius: 12.0),
          const Shadow(color: Colors.black, offset: Offset(0, 2), blurRadius: 4.0),
        ],
      ),
    );
    _tp.layout();
    _tp.paint(canvas, Offset((size.width - _tp.width) / 2, bannerY - _tp.height / 2));
  }

  void _drawLevelClearCelebration(Canvas canvas, Size size) {
    if (c.levelTransitionTimer <= 0) return;
    final timer = c.levelTransitionTimer;
    final progress = (1.0 - timer / 0.95).clamp(0.0, 1.0);
    final alpha = (progress < 0.2 ? progress / 0.2 : (progress > 0.8 ? (1.0 - progress) / 0.2 : 1.0)).clamp(0.0, 1.0);

    final bannerH = 60.0;
    final bannerY = size.height * 0.38;
    final bannerRect = Rect.fromLTWH(0, bannerY - bannerH / 2, size.width, bannerH);

    // Holographic celebration container
    _fill.color = _ca(const Color(0xEE0B1A24), alpha * 0.95);
    canvas.drawRect(bannerRect, _fill);

    // Glowing cyan / gold celebratory border lines
    _stroke
      ..strokeWidth = 2.5
      ..color = _ca(const Color(0xFF00E5FF), alpha);
    canvas.drawLine(Offset(0, bannerRect.top), Offset(size.width, bannerRect.top), _stroke);
    _stroke.color = _ca(const Color(0xFFFFD54F), alpha);
    canvas.drawLine(Offset(0, bannerRect.bottom), Offset(size.width, bannerRect.bottom), _stroke);

    // Sparkling confetti particles across banner
    for (int i = 0; i < 16; i++) {
      final cx = (i * 47.0 + time * 60.0) % size.width;
      final cy = bannerRect.top + 8.0 + (i * 17.0) % (bannerH - 16.0);
      final cColor = (i % 3 == 0) ? const Color(0xFFFFD54F) : ((i % 3 == 1) ? const Color(0xFF00E5FF) : const Color(0xFFFF4081));
      _fill.color = _ca(cColor, alpha * (0.6 + 0.4 * sin(time * 8.0 + i)));
      canvas.drawCircle(Offset(cx, cy), 2.2, _fill);
    }

    // Celebration Text
    _tp.text = TextSpan(
      text: I18n.tr('level_clear_banner'),
      style: TextStyle(
        fontFamily: 'Rajdhani',
        fontFamilyFallback: const ['Segoe UI Emoji', 'Segoe UI Symbol'],
        color: _ca(const Color(0xFFFFD54F), alpha),
        fontSize: 18.0,
        fontWeight: FontWeight.w900,
        letterSpacing: 2.2,
        shadows: [
          Shadow(color: _ca(const Color(0xFFFFD54F), alpha * 0.8), blurRadius: 14.0),
          const Shadow(color: Colors.black, offset: Offset(0, 2), blurRadius: 4.0),
        ],
      ),
    );
    _tp.layout();
    _tp.paint(canvas, Offset((size.width - _tp.width) / 2, bannerY - _tp.height / 2));
  }

  void _drawLevel1DragGuide(Canvas canvas, Rect paddleRect, double time) {
    final pulse = (sin(time * 5.0) * 0.25 + 0.75).clamp(0.0, 1.0);
    const text = '<< KAYDIR >>';
    _tp.text = TextSpan(
      text: text,
      style: TextStyle(
        fontFamily: 'Rajdhani',
        fontFamilyFallback: const ['Segoe UI Emoji', 'Segoe UI Symbol'],
        color: _ca(const Color(0xFFFFD54F), pulse),
        fontSize: 12.0,
        fontWeight: FontWeight.w900,
        letterSpacing: 2.0,
        shadows: [
          Shadow(
            color: _ca(const Color(0xFFFF8F00), 0.8 * pulse),
            blurRadius: 8.0,
          ),
          const Shadow(
            color: Colors.black,
            offset: Offset(0, 1.5),
            blurRadius: 3.0,
          ),
        ],
      ),
    );
    _tp.layout();

    final x = paddleRect.center.dx - _tp.width / 2;
    final y = paddleRect.bottom + 12.0;
    _tp.paint(canvas, Offset(x, y));
  }

  void _drawUltiReadyCallout(Canvas canvas, Size size, double time) {
    final pulse = (sin(time * 6.0) * 0.3 + 0.7).clamp(0.0, 1.0);
    const text = '⚡ ULTİ HAZIR! ÇİFT DOKUN!';
    _tp.text = TextSpan(
      text: text,
      style: TextStyle(
        fontFamily: 'Rajdhani',
        fontFamilyFallback: const ['Segoe UI Emoji', 'Segoe UI Symbol'],
        color: _ca(const Color(0xFFFFD700), pulse),
        fontSize: 13.0,
        fontWeight: FontWeight.w900,
        letterSpacing: 1.2,
        shadows: [
          Shadow(
            color: _ca(const Color(0xFFFF6D00), 0.9 * pulse),
            blurRadius: 10.0,
          ),
          const Shadow(
            color: Colors.black,
            offset: Offset(0, 2),
            blurRadius: 4.0,
          ),
        ],
      ),
    );
    _tp.layout();

    final bannerW = _tp.width + 28.0;
    final bannerH = _tp.height + 12.0;
    final bannerX = (size.width - bannerW) / 2;
    final bannerY = size.height * 0.22;
    final bannerRRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(bannerX, bannerY, bannerW, bannerH),
      const Radius.circular(16.0),
    );

    // Glowing pill background
    _fill
      ..style = PaintingStyle.fill
      ..shader = null
      ..maskFilter = null
      ..color = _ca(const Color(0xDD12162A), 0.92);
    canvas.drawRRect(bannerRRect, _fill);

    _stroke
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0
      ..shader = null
      ..maskFilter = null
      ..color = _ca(const Color(0xFFFFD700), pulse);
    canvas.drawRRect(bannerRRect, _stroke);

    _tp.paint(canvas, Offset(bannerX + 14.0, bannerY + 6.0));
  }

  void _drawBee(Canvas canvas) {
    // Amber scorch mark where the bee slammed into the paddle (fades out).
    if (c.beePaddleMarkTimer > 0) {
      final fade = (c.beePaddleMarkTimer / 1.2).clamp(0.0, 1.0);
      _fill
        ..style = PaintingStyle.fill
        ..maskFilter = null
        ..shader = null
        ..color = _ca(const Color(0xFFFF8F00), 0.30 * fade);
      canvas.drawOval(
        Rect.fromCenter(center: Offset(c.beePaddleMarkX, c.paddle.y + 4), width: 30, height: 7),
        _fill,
      );
      _fill.color = _ca(const Color(0xFF4E2600), 0.55 * fade);
      canvas.drawOval(
        Rect.fromCenter(center: Offset(c.beePaddleMarkX, c.paddle.y + 4), width: 17, height: 4),
        _fill,
      );
      _fill.color = _ca(const Color(0xFFFFD54F), 0.7 * fade);
      canvas.drawCircle(Offset(c.beePaddleMarkX - 7, c.paddle.y + 2.5), 1.4, _fill);
      canvas.drawCircle(Offset(c.beePaddleMarkX + 6, c.paddle.y + 5.5), 1.1, _fill);
    }

    final bee = c.activeBee;
    if (bee == null || !bee.isAlive) return;

    final isBurning = bee.state == BeeState.burning;
    final isFrozen = bee.state == BeeState.frozenFalling;
    final isStuck = bee.state == BeeState.stuckToPaddle;

    canvas.save();
    final stuckJitter = isStuck ? sin(bee.stateTime * 30.0) * 1.6 : 0.0;
    canvas.translate(bee.x + stuckJitter, bee.y);
    canvas.scale(0.58, 0.58);
    if (isStuck) {
      // Squash flat over the crush duration as the paddle flattens it.
      final crush = (bee.stateTime / 0.45).clamp(0.0, 1.0);
      canvas.scale(1.0 + 0.30 * crush, 1.0 - 0.60 * crush);
    }
    if (isFrozen) {
      canvas.rotate(bee.fallSpin);
    } else if (isStuck) {
      canvas.rotate(sin(bee.stateTime * 24.0) * 0.16);
    }
    canvas.rotate(bee.tiltAngle);

    if (isBurning) {
      // Flickering ember glow behind the charred body (layered soft
      // circles — canvas code keeps a strict zero-blur perf rule).
      final flicker = 15.0 + sin(time * 42.0) * 3.5;
      _fill.style = PaintingStyle.fill;
      for (final (r, a) in [(1.25, 0.10), (1.0, 0.22), (0.72, 0.45)]) {
        _fill.color = _ca(const Color(0xFFFF6D00), a);
        canvas.drawCircle(Offset.zero, flicker * r, _fill);
      }
    }
    if (isStuck) {
      // Amber glue glow while it struggles on the paddle.
      _fill.style = PaintingStyle.fill;
      final pulse = 0.40 + 0.12 * sin(time * 10.0);
      for (final (r, a) in [(1.3, 0.10), (1.0, pulse * 0.6), (0.7, pulse)]) {
        _fill.color = _ca(const Color(0xFFFFB300), a);
        canvas.drawCircle(Offset.zero, 17.0 * r, _fill);
      }
    }

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

    // 3. Plump Oval Body (charred when burning, pale blue when frozen)
    final bodyRect = Rect.fromCenter(center: Offset.zero, width: 32.0, height: 24.0);
    _fill.color = isBurning
        ? const Color(0xFF263238)
        : (isFrozen ? const Color(0xFFB3E5FC) : const Color(0xFFFFD600));
    canvas.drawOval(bodyRect, _fill);

    // 4. Bold Black Stripes (Curved within body contour)
    canvas.save();
    canvas.clipPath(Path()..addOval(bodyRect));
    _fill.color = isFrozen ? const Color(0xFF0277BD) : const Color(0xFF1B1B1B);
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

    // Ice casing while frozen solid
    if (isFrozen) {
      final iceRect = Rect.fromCenter(center: Offset.zero, width: 46, height: 38);
      _fill
        ..style = PaintingStyle.fill
        ..color = _ca(const Color(0xFF81D4FA), 0.35);
      canvas.drawRRect(RRect.fromRectAndRadius(iceRect, const Radius.circular(10)), _fill);
      _stroke
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6
        ..color = _ca(const Color(0xFFE1F5FE), 0.9);
      canvas.drawRRect(RRect.fromRectAndRadius(iceRect, const Radius.circular(10)), _stroke);
      _fill.color = _ca(Colors.white, 0.85);
      canvas.drawCircle(const Offset(-14, -10), 1.5, _fill);
      canvas.drawCircle(const Offset(12, 8), 1.2, _fill);
      canvas.drawCircle(const Offset(6, -13), 1.0, _fill);
    }

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











