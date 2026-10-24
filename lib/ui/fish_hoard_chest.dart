import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

import '../engine/audio_manager.dart';
import '../storage/save_manager.dart';

/// Small aquarium hoard. It fills while fed fish earn gold, and a tap
/// pours the ready coins into the account, leaving the chest empty.
class FishHoardChest extends StatefulWidget {
  final SaveManager save;

  /// Fired the moment a collect starts, so the aquarium screen can
  /// fly coins from the chest up to the gold counter.
  final VoidCallback? onCollectStart;

  const FishHoardChest({super.key, required this.save, this.onCollectStart});

  @override
  State<FishHoardChest> createState() => _FishHoardChestState();
}

class _FishHoardChestState extends State<FishHoardChest> with TickerProviderStateMixin {
  late final AnimationController _glow;
  late final AnimationController _pour;
  late final AnimationController _nudge;
  Timer? _tick;
  bool _busy = false;
  double? _fromFill;

  @override
  void initState() {
    super.initState();
    _glow = AnimationController(vsync: this, duration: const Duration(milliseconds: 1600))
      ..repeat(reverse: true);
    _pour = AnimationController(vsync: this, duration: const Duration(milliseconds: 860));
    _nudge = AnimationController(vsync: this, duration: const Duration(milliseconds: 280));
    _tick = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _tick?.cancel();
    _glow.dispose();
    _pour.dispose();
    _nudge.dispose();
    super.dispose();
  }

  double _fillOf(SaveManager save) {
    var weight = 0.0;
    var acc = 0.0;
    final now = DateTime.now().millisecondsSinceEpoch;
    for (final id in save.unlockedFish) {
      final fedAt = save.fishFedTimestamps[id] ?? 0;
      if (fedAt <= 0) continue;
      final value = save.getFishGoldValue(id).toDouble();
      final elapsed = now - fedAt;
      final progress = (elapsed / SaveManager.fishPayoutDurationMs).clamp(0.0, 1.0);
      acc += value * progress;
      weight += value;
    }
    if (weight <= 0) return 0;
    return (acc / weight).clamp(0.0, 1.0);
  }

  Future<void> _onTap() async {
    if (_busy) return;
    final ready = widget.save.currentAvailableFishGold;
    if (ready <= 0) {
      _nudge.forward(from: 0);
      return;
    }
    widget.onCollectStart?.call();
    _busy = true;
    _fromFill = _fillOf(widget.save);
    var paid = false;
    void midPour() {
      if (paid || _pour.value < 0.28) return;
      paid = true;
      widget.save.collectFishGold().then((amount) {
        if (amount > 0) AudioManager.instance.playSfx(GameSfx.victory);
      });
    }

    _pour.addListener(midPour);
    await _pour.forward(from: 0);
    _pour.removeListener(midPour);
    if (!paid) {
      final amount = await widget.save.collectFishGold();
      if (amount > 0) AudioManager.instance.playSfx(GameSfx.victory);
    }
    _fromFill = null;
    _busy = false;
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final live = _fillOf(widget.save);
    final from = _fromFill;
    final shown = (from != null && _pour.value > 0)
        ? from + (live - from) * Curves.easeIn.transform(_pour.value)
        : live;
    final available = widget.save.currentAvailableFishGold;
    final ready = available > 0 || (_busy && (from ?? 0) > 0);
    return GestureDetector(
      onTap: _onTap,
      child: AnimatedBuilder(
        animation: Listenable.merge([_glow, _pour, _nudge]),
        builder: (context, _) {
          final wobble = sin(_nudge.value * pi) * 0.08 * (1 - _nudge.value);
          // "Pop" as the lid snaps open at the start of a collect.
          final pop = _pour.value > 0 && _pour.value < 0.2
              ? sin((_pour.value / 0.2) * pi) * 0.07
              : 0.0;
          return Transform.scale(
            scale: 1.0 + pop,
            child: Transform.rotate(
            angle: wobble,
            child: SizedBox(
              width: 82,
              height: 82,
              child: Stack(
                clipBehavior: Clip.none,
                alignment: Alignment.center,
                children: [
                  Positioned.fill(
                    child: CustomPaint(
                      painter: _HoardChestPainter(
                        fill: shown.clamp(0.0, 1.0),
                        pour: _pour.value,
                        glow: _glow.value,
                        ready: ready,
                      ),
                    ),
                  ),
                  if (ready && available > 0 && _pour.value == 0)
                    Positioned(
                      top: -4 + sin(_glow.value * pi * 2) * 2,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFFFFF9C4), Color(0xFFFFD54F), Color(0xFFFF8F00)],
                          ),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.white, width: 0.8),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFFFFB300).withValues(alpha: 0.6),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.monetization_on, color: Color(0xFF3E230D), size: 11),
                            const SizedBox(width: 3),
                            Text(
                              '+$available',
                              style: const TextStyle(
                                color: Color(0xFF3E230D),
                                fontWeight: FontWeight.w900,
                                fontSize: 10,
                                height: 1.1,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
            ),
          );
        },
      ),
    );
  }
}

class _HoardChestPainter extends CustomPainter {
  final double fill;
  final double pour;
  final double glow;
  final bool ready;

  const _HoardChestPainter({
    required this.fill,
    required this.pour,
    required this.glow,
    required this.ready,
  });

  static const _gold = Color(0xFFFFD54F);
  static const _goldBright = Color(0xFFFFF176);
  static const _goldDark = Color(0xFFC67D00);
  static const _brass = Color(0xFFD4AF37);
  static const _brassDark = Color(0xFF6E4D1B);

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    // When filling, lid cracks open gently up to ~32%. When pouring, swings wide open.
    final openProgress = (fill * 0.42 + pour * 0.75).clamp(0.0, 1.0);

    // 1. Ambient Golden Aura & Sand Bedding Mound
    _drawSandMoundAndAura(canvas, w, h);

    // 2. Rising aquarium micro-bubbles
    _drawBubbles(canvas, w, h);

    // 3. Chest Body Base (Sturdy dark oak with vertical planks)
    final body = Rect.fromLTWH(w * 0.14, h * 0.44, w * 0.72, h * 0.38);
    _drawChestBody(canvas, body);

    // 4. Chest Interior Cavity & Stacked Gold Coins
    _drawCoinsInside(canvas, body, fill, openProgress);

    // 5. Vaulted Arched Lid (Barreled Dome Top with Hinge)
    _drawVaultedLid(canvas, body, openProgress);

    // 6. Brass Lock Escutcheon & Keyhole
    _drawLockPlate(canvas, body, openProgress);

    // 7. Flying Golden Coin Burst during collection
    _drawFlyingCoins(canvas, w, h, pour);
  }

  void _drawSandMoundAndAura(Canvas canvas, double w, double h) {
    // Under-chest contact shadow
    canvas.drawOval(
      Rect.fromCenter(center: Offset(w * 0.5, h * 0.86), width: w * 0.76, height: h * 0.16),
      Paint()..color = const Color(0x77000000),
    );

    // Sand silt mound embracing bottom of chest
    final sandPath = Path()
      ..moveTo(w * 0.08, h * 0.90)
      ..quadraticBezierTo(w * 0.5, h * 0.82, w * 0.92, h * 0.90)
      ..lineTo(w * 0.92, h * 0.96)
      ..lineTo(w * 0.08, h * 0.96)
      ..close();
    canvas.drawPath(
      sandPath,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0x55C2A86E), Color(0x884E3A20)],
        ).createShader(Rect.fromLTWH(0, h * 0.82, w, h * 0.14)),
    );

    // Crisp stepped pixel golden treasure halo when gold is inside (Zero Blur)
    if (fill > 0.05 || ready) {
      final pulse = ready ? (0.18 + 0.14 * glow) : (0.08 + fill * 0.12);
      final haloRect = Rect.fromCenter(
        center: Offset(w * 0.5, h * 0.58),
        width: w * (0.72 + fill * 0.12),
        height: h * (0.56 + fill * 0.10),
      );
      canvas.drawRect(
        haloRect,
        Paint()
          ..isAntiAlias = false
          ..color = _gold.withValues(alpha: (pulse * 0.65).clamp(0.0, 0.32)),
      );
      canvas.drawRect(
        haloRect.deflate(3.0),
        Paint()
          ..isAntiAlias = false
          ..color = _goldBright.withValues(alpha: pulse.clamp(0.0, 0.42)),
      );
    }
  }

  void _drawBubbles(Canvas canvas, double w, double h) {
    final b1Y = h * (0.75 - ((glow * 1.2) % 1.0) * 0.55);
    final b2Y = h * (0.80 - (((glow + 0.5) * 1.1) % 1.0) * 0.60);
    final bPaint = Paint()..color = const Color(0x3580D8FF);
    canvas.drawCircle(Offset(w * 0.20, b1Y), 1.8, bPaint);
    canvas.drawCircle(Offset(w * 0.82, b2Y), 1.5, bPaint);
  }

  void _drawChestBody(Canvas canvas, Rect body) {
    final bodyRRect = RRect.fromRectAndCorners(
      body,
      bottomLeft: Radius.circular(body.width * 0.12),
      bottomRight: Radius.circular(body.width * 0.12),
      topLeft: Radius.circular(body.width * 0.04),
      topRight: Radius.circular(body.width * 0.04),
    );

    // Deep wooden oak planks
    canvas.drawRRect(
      bodyRRect,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xFF5D381B), // rich warm walnut/oak
            Color(0xFF3F230E), // deep wood
            Color(0xFF241306), // dark timber base
          ],
        ).createShader(body),
    );

    // Vertical plank grooves (3 distinct wood planks)
    final p1 = body.left + body.width * 0.33;
    final p2 = body.left + body.width * 0.67;
    final groovePaint = Paint()
      ..color = const Color(0xFF180B03)
      ..strokeWidth = 1.2;
    final highlightPaint = Paint()
      ..color = const Color(0x33A66A38)
      ..strokeWidth = 0.8;

    canvas.drawLine(Offset(p1, body.top), Offset(p1, body.bottom), groovePaint);
    canvas.drawLine(Offset(p1 + 0.9, body.top), Offset(p1 + 0.9, body.bottom), highlightPaint);
    canvas.drawLine(Offset(p2, body.top), Offset(p2, body.bottom), groovePaint);
    canvas.drawLine(Offset(p2 + 0.9, body.top), Offset(p2 + 0.9, body.bottom), highlightPaint);

    // Forged Brass/Iron corner and edge bands
    _drawMetalBand(canvas, Rect.fromLTWH(body.left, body.top, body.width * 0.12, body.height), isVertical: true);
    _drawMetalBand(canvas, Rect.fromLTWH(body.right - body.width * 0.12, body.top, body.width * 0.12, body.height), isVertical: true);
    _drawMetalBand(canvas, Rect.fromLTWH(body.left + body.width * 0.44, body.top, body.width * 0.12, body.height), isVertical: true);
    _drawMetalBand(canvas, Rect.fromLTWH(body.left, body.bottom - body.height * 0.14, body.width, body.height * 0.14), isVertical: false);

    // Studded Rivets on the metal straps
    _drawRivet(canvas, Offset(body.left + body.width * 0.06, body.top + body.height * 0.22));
    _drawRivet(canvas, Offset(body.left + body.width * 0.06, body.bottom - body.height * 0.22));
    _drawRivet(canvas, Offset(body.right - body.width * 0.06, body.top + body.height * 0.22));
    _drawRivet(canvas, Offset(body.right - body.width * 0.06, body.bottom - body.height * 0.22));
    _drawRivet(canvas, Offset(body.left + body.width * 0.50, body.bottom - body.height * 0.22));
  }

  void _drawCoinsInside(Canvas canvas, Rect body, double fillAmount, double open) {
    if (fillAmount <= 0.01 && open <= 0.01) return;

    final cavity = Rect.fromLTWH(
      body.left + body.width * 0.10,
      body.top - body.height * 0.04,
      body.width * 0.80,
      body.height * 0.52,
    );

    canvas.save();
    canvas.clipRect(Rect.fromLTWH(body.left, body.top - body.height * 0.35, body.width, body.height * 0.9));

    // Dark shadow inside cavity
    canvas.drawRRect(
      RRect.fromRectAndRadius(cavity, Radius.circular(body.width * 0.06)),
      Paint()..color = const Color(0xFF140802),
    );

    // Crisp stepped golden pixel rim inside the chest cavity (Zero Blur)
    canvas.drawRect(
      cavity.deflate(1.5),
      Paint()
        ..isAntiAlias = false
        ..color = _gold.withValues(alpha: (0.18 + fillAmount * 0.32).clamp(0.0, 0.5)),
    );

    // Tiered stack of 3D embossed gold coins
    final totalCoins = (fillAmount * 14).ceil().clamp(1, 14);
    // Relative coordinates for coins in 3 organic layers
    final coinPositions = [
      // Bottom layer
      Offset(cavity.left + cavity.width * 0.20, cavity.bottom - 4),
      Offset(cavity.left + cavity.width * 0.45, cavity.bottom - 3),
      Offset(cavity.left + cavity.width * 0.72, cavity.bottom - 4),
      Offset(cavity.left + cavity.width * 0.32, cavity.bottom - 6),
      Offset(cavity.left + cavity.width * 0.58, cavity.bottom - 6),
      // Mid layer
      Offset(cavity.left + cavity.width * 0.22, cavity.bottom - 9),
      Offset(cavity.left + cavity.width * 0.42, cavity.bottom - 10),
      Offset(cavity.left + cavity.width * 0.65, cavity.bottom - 9),
      Offset(cavity.left + cavity.width * 0.80, cavity.bottom - 8),
      Offset(cavity.left + cavity.width * 0.34, cavity.bottom - 12),
      Offset(cavity.left + cavity.width * 0.54, cavity.bottom - 13),
      // Top overflowing heap
      Offset(cavity.left + cavity.width * 0.26, cavity.bottom - 15),
      Offset(cavity.left + cavity.width * 0.48, cavity.bottom - 16),
      Offset(cavity.left + cavity.width * 0.68, cavity.bottom - 15),
    ];

    final coinW = cavity.width * 0.26;
    final coinH = cavity.height * 0.30;

    for (var i = 0; i < totalCoins; i++) {
      final pos = coinPositions[i];
      final coinRect = Rect.fromCenter(center: pos, width: coinW, height: coinH);

      // 3D edge / rim
      canvas.drawOval(
        coinRect.shift(const Offset(0, 1.2)),
        Paint()..color = _goldDark,
      );

      // Gold coin face with metallic gradient
      canvas.drawOval(
        coinRect,
        Paint()
          ..shader = const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [_goldBright, _gold, _goldDark],
          ).createShader(coinRect),
      );

      // Specular highlight gleam
      canvas.drawCircle(
        Offset(pos.dx - coinW * 0.18, pos.dy - coinH * 0.12),
        coinW * 0.10,
        Paint()..color = Colors.white.withValues(alpha: 0.85),
      );
    }

    canvas.restore();
  }

  void _drawVaultedLid(Canvas canvas, Rect body, double openProgress) {
    final lidW = body.width * 1.06;
    final lidH = body.height * 0.54;
    final lidLeft = body.left - body.width * 0.03;
    final lidBottom = body.top + 2.0;
    final lidTop = lidBottom - lidH;
    final lidRect = Rect.fromLTWH(lidLeft, lidTop, lidW, lidH);

    canvas.save();
    // Hinge pivot at back top-left corner
    final pivot = Offset(lidLeft + 4.0, lidBottom);
    canvas.translate(pivot.dx, pivot.dy);
    // Hinge back: open progress rotates lid upwards-backwards
    canvas.rotate(-openProgress * 0.85);
    canvas.translate(-pivot.dx, -pivot.dy);

    // Vaulted Arched Lid Path
    final archPath = Path()
      ..moveTo(lidLeft, lidBottom)
      ..lineTo(lidLeft, lidTop + lidH * 0.40)
      ..quadraticBezierTo(lidLeft + lidW * 0.5, lidTop - lidH * 0.18, lidLeft + lidW, lidTop + lidH * 0.40)
      ..lineTo(lidLeft + lidW, lidBottom)
      ..close();

    // Wood texture curved barrel shader
    canvas.drawPath(
      archPath,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: const [
            Color(0xFF754522), // bright oak highlight on curved top
            Color(0xFF4E2C13), // mid wood
            Color(0xFF2C1607), // rim shadow
          ],
        ).createShader(lidRect),
    );

    // Curved wood plank horizontal seam line
    final seamY = lidTop + lidH * 0.50;
    canvas.drawLine(
      Offset(lidLeft + 3, seamY),
      Offset(lidLeft + lidW - 3, seamY),
      Paint()
        ..color = const Color(0x33000000)
        ..strokeWidth = 1.0,
    );

    // Lid Metal Bands (Left, Center, Right) conforming to the arch
    _drawLidMetalBand(canvas, lidLeft, lidBottom, lidTop, lidH, lidW * 0.12);
    _drawLidMetalBand(canvas, lidLeft + lidW * 0.44, lidBottom, lidTop, lidH, lidW * 0.12);
    _drawLidMetalBand(canvas, lidLeft + lidW - lidW * 0.12, lidBottom, lidTop, lidH, lidW * 0.12);

    // Bottom rim band of lid
    final lidLipRect = Rect.fromLTWH(lidLeft, lidBottom - lidH * 0.18, lidW, lidH * 0.18);
    _drawMetalBand(canvas, lidLipRect, isVertical: false);

    // Lid Rivets
    _drawRivet(canvas, Offset(lidLeft + lidW * 0.06, lidBottom - lidH * 0.10));
    _drawRivet(canvas, Offset(lidLeft + lidW * 0.50, lidBottom - lidH * 0.10));
    _drawRivet(canvas, Offset(lidLeft + lidW * 0.94, lidBottom - lidH * 0.10));

    // Brass Hasp/Latch hanging from lid center
    final haspW = lidW * 0.14;
    final haspH = lidH * 0.42;
    final haspRect = Rect.fromLTWH(lidLeft + (lidW - haspW) * 0.5, lidBottom - lidH * 0.12, haspW, haspH);
    final haspRRect = RRect.fromRectAndRadius(haspRect, Radius.circular(haspW * 0.3));
    canvas.drawRRect(
      haspRRect,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [_goldBright, _brass, _brassDark],
        ).createShader(haspRect),
    );
    canvas.drawCircle(Offset(haspRect.center.dx, haspRect.bottom - haspH * 0.25), 1.5, Paint()..color = const Color(0xFF1B0F03));

    canvas.restore();
  }

  void _drawLidMetalBand(Canvas canvas, double x, double bottom, double top, double h, double width) {
    final bandRect = Rect.fromLTWH(x, top, width, h);
    final bandPath = Path()
      ..moveTo(x, bottom)
      ..lineTo(x, top + h * 0.40)
      ..quadraticBezierTo(x + width * 0.5, top - h * 0.12, x + width, top + h * 0.40)
      ..lineTo(x + width, bottom)
      ..close();

    canvas.drawPath(
      bandPath,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: const [_brassDark, _goldBright, _brass, _brassDark],
        ).createShader(bandRect),
    );
    _drawRivet(canvas, Offset(x + width * 0.5, top + h * 0.42));
  }

  void _drawMetalBand(Canvas canvas, Rect rect, {required bool isVertical}) {
    canvas.drawRect(
      rect,
      Paint()
        ..shader = LinearGradient(
          begin: isVertical ? Alignment.centerLeft : Alignment.topCenter,
          end: isVertical ? Alignment.centerRight : Alignment.bottomCenter,
          colors: const [_brassDark, _goldBright, _brass, _brassDark],
        ).createShader(rect),
    );
  }

  void _drawRivet(Canvas canvas, Offset pos) {
    canvas.drawCircle(pos + const Offset(0, 0.6), 1.5, Paint()..color = const Color(0xFF2E1705));
    canvas.drawCircle(
      pos,
      1.5,
      Paint()
        ..shader = const RadialGradient(
          colors: [Colors.white, _gold, _brassDark],
        ).createShader(Rect.fromCircle(center: pos, radius: 1.5)),
    );
  }

  void _drawLockPlate(Canvas canvas, Rect body, double openProgress) {
    // Only draw lock escutcheon on body
    final plateW = body.width * 0.18;
    final plateH = body.height * 0.28;
    final plateCenter = Offset(body.center.dx, body.top + body.height * 0.24);
    final plateRect = Rect.fromCenter(center: plateCenter, width: plateW, height: plateH);

    // Ornate shield / diamond lock escutcheon
    final lockPath = Path()
      ..moveTo(plateCenter.dx, plateRect.top)
      ..lineTo(plateRect.right, plateRect.top + plateH * 0.35)
      ..lineTo(plateCenter.dx, plateRect.bottom)
      ..lineTo(plateRect.left, plateRect.top + plateH * 0.35)
      ..close();

    canvas.drawPath(
      lockPath,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [_goldBright, _brass, _brassDark],
        ).createShader(plateRect),
    );

    // Keyhole cutout
    final keyholeY = plateCenter.dy;
    canvas.drawCircle(Offset(plateCenter.dx, keyholeY - 1.2), 1.6, Paint()..color = const Color(0xFF140802));
    final khPath = Path()
      ..moveTo(plateCenter.dx - 1.1, keyholeY - 0.5)
      ..lineTo(plateCenter.dx + 1.1, keyholeY - 0.5)
      ..lineTo(plateCenter.dx + 1.5, keyholeY + 2.4)
      ..lineTo(plateCenter.dx - 1.5, keyholeY + 2.4)
      ..close();
    canvas.drawPath(khPath, Paint()..color = const Color(0xFF140802));
  }

  void _drawFlyingCoins(Canvas canvas, double w, double h, double progress) {
    if (progress <= 0) return;
    for (var i = 0; i < 8; i++) {
      final t = ((progress - i * 0.06) / 0.70).clamp(0.0, 1.0);
      if (t <= 0) continue;
      // Arc fountain upwards and towards top left/center
      final spreadX = (i - 3.5) * (w * 0.08);
      final x = w * 0.5 + spreadX - Curves.easeOut.transform(t) * (w * 0.20);
      final y = h * 0.40 - Curves.easeOutQuad.transform(t) * (h * 0.65);
      final coinW = w * (0.13 * (1.0 - t * 0.25));
      final coinH = h * (0.08 * (1.0 - t * 0.25));
      final coin = Rect.fromCenter(center: Offset(x, y), width: coinW, height: coinH);

      final alpha = (1.0 - t).clamp(0.0, 1.0);
      canvas.drawOval(
        coin,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              _goldBright.withValues(alpha: alpha),
              _gold.withValues(alpha: alpha),
              _goldDark.withValues(alpha: alpha),
            ],
          ).createShader(coin),
      );
      canvas.drawCircle(
        Offset(x - coinW * 0.18, y - coinH * 0.12),
        coinW * 0.12,
        Paint()..color = Colors.white.withValues(alpha: alpha * 0.9),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _HoardChestPainter oldDelegate) {
    return oldDelegate.fill != fill ||
        oldDelegate.pour != pour ||
        oldDelegate.glow != glow ||
        oldDelegate.ready != ready;
  }
}

