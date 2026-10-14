import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

import '../engine/audio_manager.dart';
import '../storage/save_manager.dart';

/// Small aquarium hoard. It fills while fed fish earn gold, and a tap
/// pours the ready coins into the account, leaving the chest empty.
class FishHoardChest extends StatefulWidget {
  final SaveManager save;

  const FishHoardChest({super.key, required this.save});

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
    final ready = widget.save.currentAvailableFishGold > 0 || (_busy && (from ?? 0) > 0);

    return GestureDetector(
      onTap: _onTap,
      child: AnimatedBuilder(
        animation: Listenable.merge([_glow, _pour, _nudge]),
        builder: (context, _) {
          final wobble = sin(_nudge.value * pi) * 0.08 * (1 - _nudge.value);
          return Transform.rotate(
            angle: wobble,
            child: SizedBox(
              width: 74,
              height: 86,
              child: CustomPaint(
                painter: _HoardChestPainter(
                  fill: shown.clamp(0.0, 1.0),
                  pour: _pour.value,
                  glow: _glow.value,
                  ready: ready,
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
  static const _deep = Color(0xFF050811);

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final open = (fill * 0.72 + pour * 0.4).clamp(0.0, 1.0);
    final pulse = ready ? 0.08 * glow : 0.03 * glow;

    canvas.drawCircle(
      Offset(w * 0.5, h * 0.62),
      w * (0.28 + fill * 0.08),
      Paint()
        ..color = _gold.withValues(alpha: (0.08 + fill * 0.22 + pulse).clamp(0.0, 0.45))
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, w * 0.08),
    );

    canvas.drawOval(
      Rect.fromCenter(center: Offset(w * 0.5, h * 0.9), width: w * 0.62, height: h * 0.08),
      Paint()..color = const Color(0x66000000),
    );

    final body = Rect.fromLTWH(w * 0.16, h * 0.5, w * 0.68, h * 0.32);
    _drawPlate(canvas, body, w * 0.08, openMouth: true);

    final cavity = Rect.fromLTWH(body.left + w * 0.06, body.top + h * 0.02, body.width - w * 0.12, body.height * 0.55);
    canvas.save();
    canvas.clipRRect(RRect.fromRectAndRadius(cavity, Radius.circular(w * 0.04)));
    _drawCoins(canvas, cavity, fill);
    canvas.restore();

    final lid = Rect.fromLTWH(w * 0.12, h * 0.3, w * 0.76, h * 0.22);
    canvas.save();
    final pivot = Offset(lid.center.dx, lid.bottom);
    canvas.translate(pivot.dx, pivot.dy);
    canvas.rotate(-open * 1.05);
    canvas.translate(-pivot.dx, -pivot.dy - open * h * 0.02);
    _drawPlate(canvas, lid, w * 0.1, openMouth: false);
    canvas.restore();

    _drawFlyingCoins(canvas, w, h, pour);
  }

  void _drawPlate(Canvas canvas, Rect rect, double radius, {required bool openMouth}) {
    final rr = RRect.fromRectAndRadius(rect, Radius.circular(radius));
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect.shift(Offset(0, rect.height * 0.08)), Radius.circular(radius)),
      Paint()..color = const Color(0xFF3A2A08).withValues(alpha: 0.85),
    );
    canvas.drawRRect(
      rr,
      Paint()
        ..shader = RadialGradient(
          colors: [
            Color.lerp(_gold, const Color(0xFF1A1408), 0.55)!,
            Color.lerp(_gold, _deep, 0.82)!,
          ],
        ).createShader(rect),
    );
    canvas.save();
    canvas.clipRRect(rr);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(rect.left + rect.width * 0.1, rect.top + rect.height * 0.14, rect.width * 0.8, rect.height * 0.22),
        Radius.circular(radius * 0.4),
      ),
      Paint()..color = Colors.white.withValues(alpha: 0.14),
    );
    canvas.restore();

    final tube = rr.deflate(max(1.0, rect.shortestSide * 0.08));
    canvas.drawRRect(
      tube,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = max(1.4, rect.shortestSide * 0.14)
        ..color = _gold.withValues(alpha: 0.34 + fill * 0.2),
    );
    canvas.drawRRect(
      tube,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = max(0.8, rect.shortestSide * 0.07)
        ..color = _gold,
    );
    canvas.drawRRect(
      tube,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = max(0.4, rect.shortestSide * 0.03)
        ..color = Colors.white.withValues(alpha: 0.9),
    );

    if (openMouth) return;
    final gem = rect.center;
    canvas.drawCircle(gem, rect.height * 0.16, Paint()..color = _gold);
    canvas.drawCircle(gem, rect.height * 0.07, Paint()..color = Colors.white);
  }

  void _drawCoins(Canvas canvas, Rect cavity, double amount) {
    if (amount <= 0.02) return;
    final count = (amount * 5).ceil().clamp(1, 5);
    for (var i = 0; i < count; i++) {
      final col = i % 3;
      final row = i ~/ 3;
      final cx = cavity.left + cavity.width * (0.28 + col * 0.22);
      final cy = cavity.bottom - cavity.height * (0.28 + row * 0.34) ;
      final coin = Rect.fromCenter(center: Offset(cx, cy), width: cavity.width * 0.28, height: cavity.height * 0.42);
      canvas.drawOval(coin.shift(const Offset(0, 1.2)), Paint()..color = const Color(0xFF8D6E00));
      canvas.drawOval(
        coin,
        Paint()
          ..shader = const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFFFF3C4), _gold, Color(0xFFE6A100)],
          ).createShader(coin),
      );
      canvas.drawCircle(Offset(cx - coin.width * 0.12, cy - coin.height * 0.1), coin.width * 0.08, Paint()..color = Colors.white);
    }
  }

  void _drawFlyingCoins(Canvas canvas, double w, double h, double progress) {
    if (progress <= 0) return;
    for (var i = 0; i < 6; i++) {
      final t = ((progress - i * 0.07) / 0.72).clamp(0.0, 1.0);
      if (t <= 0) continue;
      final x = w * (0.42 + (i % 3) * 0.08) + t * w * 0.22;
      final y = h * 0.48 - Curves.easeIn.transform(t) * h * 0.42;
      final coin = Rect.fromCenter(center: Offset(x, y), width: w * 0.12, height: h * 0.07);
      final paint = Paint()..color = _gold.withValues(alpha: (1 - t) * 0.95);
      canvas.drawOval(coin, paint);
      canvas.drawCircle(
        Offset(x - coin.width * 0.15, y - coin.height * 0.1),
        coin.width * 0.12,
        Paint()..color = Colors.white.withValues(alpha: (1 - t) * 0.9),
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
