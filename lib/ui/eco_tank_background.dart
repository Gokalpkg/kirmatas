import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import '../engine/asset_cache.dart';
import '../engine/audio_manager.dart';
import '../models/cosmetics.dart';
import '../storage/save_manager.dart';

class EcoTankBackground extends StatefulWidget {
  final bool interactive;
  final Widget? child;

  const EcoTankBackground({super.key, this.interactive = false, this.child});

  @override
  State<EcoTankBackground> createState() => _EcoTankBackgroundState();
}

class _EcoTankBackgroundState extends State<EcoTankBackground> with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  Duration _lastElapsed = Duration.zero;

  final List<_SimFish> _simFish = [];
  final List<_Bubble> _bubbles = [];
  final List<_FoodPellet> _foodPellets = [];
  final List<_EatParticle> _eatParticles = [];
  final Random _rand = Random();
  double _animTime = 0.0;

  @override
  void initState() {
    super.initState();
    _initFish();
    _initBubbles();

    _ticker = createTicker((elapsed) {
      if (_lastElapsed == Duration.zero) {
        _lastElapsed = elapsed;
        return;
      }
      final dt = (elapsed - _lastElapsed).inMicroseconds / 1000000.0;
      _lastElapsed = elapsed;
      final clampedDt = dt.clamp(0.001, 0.05);

      _updateSimulation(clampedDt);
      setState(() {
        _animTime += clampedDt;
      });
    })..start();
  }

  void _initFish() {
    final save = SaveManager.instance;
    final fishIds = save.unlockedFish;
    for (int i = 0; i < fishIds.length; i++) {
      final item = FishItem.getById(fishIds[i]);
      _simFish.add(
        _SimFish(
          item: item,
          x: 50.0 + (i * 65.0) % 280.0,
          y: 180.0 + (i * 70.0) % 360.0,
          vx: (_rand.nextBool() ? 1 : -1) * (26.0 + _rand.nextDouble() * 18.0),
          vy: (_rand.nextDouble() * 2 - 1) * 8.0,
          facingRight: _rand.nextBool(),
          tailPhase: _rand.nextDouble() * pi * 2,
        ),
      );
    }
  }

  void _initBubbles() {
    for (int i = 0; i < 22; i++) {
      _bubbles.add(
        _Bubble(
          x: _rand.nextDouble() * 380.0,
          y: _rand.nextDouble() * 720.0,
          radius: 1.5 + _rand.nextDouble() * 2.8,
          speed: 18.0 + _rand.nextDouble() * 24.0,
        ),
      );
    }
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  void _addFood(Offset pos) {
    if (!widget.interactive) return;
    // Spawn 2 food pellets near tap
    for (int i = 0; i < 2; i++) {
      final offsetX = (_rand.nextDouble() * 2 - 1) * 12.0;
      final offsetY = (_rand.nextDouble() * 2 - 1) * 8.0;
      _foodPellets.add(
        _FoodPellet(
          x: pos.dx + offsetX,
          y: pos.dy + offsetY,
          vy: 32.0 + _rand.nextDouble() * 18.0,
          swayPhase: _rand.nextDouble() * pi * 2,
        ),
      );
    }
    AudioManager.instance.playSfx(GameSfx.click);
  }

  void _updateSimulation(double dt) {
    // 1. Update bubbles (gentle rising)
    for (final b in _bubbles) {
      b.y -= b.speed * dt * 0.75;
      if (b.y < -10) {
        b.y = 800.0;
        b.x = _rand.nextDouble() * 400.0;
      }
    }

    // 2. Update food pellets
    for (int i = _foodPellets.length - 1; i >= 0; i--) {
      final p = _foodPellets[i];
      p.update(dt);
      if (p.y > 800.0 || p.life > 14.0) {
        _foodPellets.removeAt(i);
      }
    }

    // 3. Update eat particles
    for (int i = _eatParticles.length - 1; i >= 0; i--) {
      final ep = _eatParticles[i];
      ep.y -= 25.0 * dt;
      ep.life -= dt;
      if (ep.life <= 0) {
        _eatParticles.removeAt(i);
      }
    }

    // 4. Assign each pellet to the single closest fish
    final Map<_SimFish, _FoodPellet> fishTargetPellet = {};
    for (final pellet in _foodPellets) {
      _SimFish? closestFish;
      double minDist = 999999.0;
      for (final f in _simFish) {
        final dist = sqrt((pellet.x - f.x) * (pellet.x - f.x) + (pellet.y - f.y) * (pellet.y - f.y));
        if (dist < minDist) {
          minDist = dist;
          closestFish = f;
        }
      }
      if (closestFish != null) {
        if (!fishTargetPellet.containsKey(closestFish)) {
          fishTargetPellet[closestFish] = pellet;
        } else {
          final existing = fishTargetPellet[closestFish]!;
          final existingDist = sqrt((existing.x - closestFish.x) * (existing.x - closestFish.x) + (existing.y - closestFish.y) * (existing.y - closestFish.y));
          if (minDist < existingDist) {
            fishTargetPellet[closestFish] = pellet;
          }
        }
      }
    }

    // 5. Update fish swimming
    for (final f in _simFish) {
      f.tailPhase += dt * 4.5;
      if (f.eatCooldown > 0) {
        f.eatCooldown -= dt;
      }

      final targetPellet = fishTargetPellet[f];

      if (targetPellet != null) {
        // Eagerly swim towards assigned food pellet
        final dx = targetPellet.x - f.x;
        final dy = targetPellet.y - f.y;
        final dist = max(0.001, sqrt(dx * dx + dy * dy));

        if (dist < 22.0) {
          // Eat pellet!
          _foodPellets.remove(targetPellet);
          f.eatCooldown = 0.5;

          // Spawn eat sparkles
          for (int k = 0; k < 4; k++) {
            _eatParticles.add(
              _EatParticle(
                x: f.x + (_rand.nextDouble() * 2 - 1) * 8.0,
                y: f.y - 6.0,
                maxLife: 0.8 + _rand.nextDouble() * 0.4,
                color: const Color(0xFFFFD54F),
              ),
            );
          }
          AudioManager.instance.playSfx(GameSfx.bubble);
        } else {
          final swimSpeed = (dist > 140 ? 105.0 : 80.0) * (1.0 + f.item.size * 0.1);
          f.x += (dx / dist) * swimSpeed * dt;
          f.y += (dy / dist) * swimSpeed * dt;
          f.facingRight = dx >= 0;
          f.pitchAngle = (dy / dist * 0.4).clamp(-0.45, 0.45);
        }
      } else {
        // Calm ambient swimming
        final speed = f.vx.abs();
        f.x += (f.facingRight ? speed : -speed) * dt;
        f.y += sin(_animTime * 1.5 + f.tailPhase) * 12.0 * dt;
        f.pitchAngle = sin(_animTime * 1.6 + f.tailPhase) * 0.08;

        if (f.x < 35.0) {
          f.x = 35.0;
          f.facingRight = true;
        } else if (f.x > 375.0) {
          f.x = 375.0;
          f.facingRight = false;
        }
        f.y = f.y.clamp(90.0, 710.0);
      }
    }

    // 6. Fish Collision Avoidance (Separation steering)
    for (int i = 0; i < _simFish.length; i++) {
      for (int j = i + 1; j < _simFish.length; j++) {
        final f1 = _simFish[i];
        final f2 = _simFish[j];
        final dx = f1.x - f2.x;
        final dy = f1.y - f2.y;
        final dist = sqrt(dx * dx + dy * dy);
        const minDistance = 42.0;

        if (dist < minDistance && dist > 0.001) {
          final overlap = (minDistance - dist) / minDistance;
          final pushX = (dx / dist) * overlap * 30.0 * dt;
          final pushY = (dy / dist) * overlap * 30.0 * dt;

          f1.x += pushX;
          f1.y += pushY;
          f2.x -= pushX;
          f2.y -= pushY;

          // Steer vertically away from each other
          if (f1.y < f2.y) {
            f1.y -= 16.0 * dt;
            f2.y += 16.0 * dt;
          } else {
            f1.y += 16.0 * dt;
            f2.y -= 16.0 * dt;
          }

          // If overlapping head-on, steer one away
          if (dist < 25.0 && _rand.nextDouble() < 0.08) {
            f2.facingRight = !f2.facingRight;
          }
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (details) => _addFood(details.localPosition),
      child: Stack(
        children: [
          Positioned.fill(
            child: CustomPaint(
              painter: _TankPainter(
                simFish: _simFish,
                bubbles: _bubbles,
                foodPellets: _foodPellets,
                eatParticles: _eatParticles,
                time: _animTime,
              ),
            ),
          ),
          if (widget.child != null) widget.child!,
        ],
      ),
    );
  }
}

class _SimFish {
  final FishItem item;
  double x;
  double y;
  double vx;
  double vy;
  double pitchAngle = 0.0;
  bool facingRight;
  double tailPhase;
  double eatCooldown = 0.0;

  _SimFish({
    required this.item,
    required this.x,
    required this.y,
    required this.vx,
    required this.vy,
    required this.facingRight,
    required this.tailPhase,
  });
}

class _Bubble {
  double x;
  double y;
  double radius;
  double speed;

  _Bubble({required this.x, required this.y, required this.radius, required this.speed});
}

class _FoodPellet {
  double x;
  double y;
  double vy;
  double swayPhase;
  double life = 0.0;

  _FoodPellet({required this.x, required this.y, required this.vy, required this.swayPhase});

  void update(double dt) {
    y += vy * dt;
    swayPhase += dt * 3.0;
    x += sin(swayPhase) * 12.0 * dt;
    life += dt;
  }
}

class _EatParticle {
  double x;
  double y;
  double life;
  final double maxLife;
  final Color color;

  _EatParticle({required this.x, required this.y, required this.maxLife, required this.color}) : life = maxLife;
}

class _TankPainter extends CustomPainter {
  final List<_SimFish> simFish;
  final List<_Bubble> bubbles;
  final List<_FoodPellet> foodPellets;
  final List<_EatParticle> eatParticles;
  final double time;

  _TankPainter({
    required this.simFish,
    required this.bubbles,
    required this.foodPellets,
    required this.eatParticles,
    required this.time,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // 1. Water gradient
    final waterShader = const LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [Color(0xFF0C1726), Color(0xFF09131F), Color(0xFF040A10)],
    ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), Paint()..shader = waterShader);

    // 2. Sand layer at bottom
    final sandPath = Path()
      ..moveTo(0, size.height - 48)
      ..quadraticBezierTo(size.width * 0.5, size.height - 62, size.width, size.height - 44)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    final sandPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0x38C2A86E), Color(0x665C4628)],
      ).createShader(Rect.fromLTWH(0, size.height - 62, size.width, 62));
    canvas.drawPath(sandPath, sandPaint);

    // 3. Kelp & Moss plants swaying gently
    final plantPaint = Paint()
      ..color = const Color(0x5543A047)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4.5
      ..strokeCap = StrokeCap.round;

    for (int i = 0; i < 5; i++) {
      final bx = 25.0 + i * (size.width - 50) / 4;
      final sway = sin(time * 1.5 + i) * 11.0;
      final plantPath = Path()
        ..moveTo(bx, size.height - 44)
        ..quadraticBezierTo(bx + sway * 0.5, size.height - 95, bx + sway, size.height - 145);
      canvas.drawPath(plantPath, plantPaint);
    }

    // 4. Rising bubbles
    final bubblePaint = Paint()..color = const Color(0x2881D4FA);
    for (final b in bubbles) {
      canvas.drawCircle(Offset(b.x + sin(time + b.radius) * 3, b.y), b.radius, bubblePaint);
    }

    // 5. Food Pellets
    final foodPaint = Paint()..color = const Color(0xFFFFD54F);
    final foodGlow = Paint()..color = const Color(0x44FFD54F);
    for (final p in foodPellets) {
      canvas.drawCircle(Offset(p.x, p.y), 4.0, foodGlow);
      canvas.drawCircle(Offset(p.x, p.y), 2.5, foodPaint);
    }

    // 6. Eat particles (sparkles and bubbles)
    for (final ep in eatParticles) {
      final alpha = (ep.life / ep.maxLife).clamp(0.0, 1.0);
      final pPaint = Paint()..color = ep.color.withValues(alpha: alpha);
      canvas.drawCircle(Offset(ep.x, ep.y), 2.0 * alpha, pPaint);
    }

    // 7. Fish drawing (Scaled down to realistic proportion)
    for (final f in simFish) {
      canvas.save();
      canvas.translate(f.x, f.y);

      if (!f.facingRight) {
        canvas.scale(-1, 1);
      }
      canvas.rotate(f.pitchAngle);

      final img = AssetCache.instance.getFishImage(f.item.id);
      if (img != null) {
        // Scaled down: ~45-60px width
        final fishScale = f.item.size * 0.14;
        canvas.scale(fishScale, fishScale);

        final src = Rect.fromLTWH(0, 0, img.width.toDouble(), img.height.toDouble());
        final dst = Rect.fromCenter(
          center: Offset.zero,
          width: img.width.toDouble(),
          height: img.height.toDouble(),
        );
        canvas.drawImageRect(img, src, dst, Paint()..filterQuality = FilterQuality.medium);
      } else {
        // Fallback procedural fish
        final fishScale = f.item.size * 0.7;
        canvas.scale(fishScale, fishScale);
        final bodyRect = Rect.fromCenter(center: Offset.zero, width: 26, height: 13);
        canvas.drawOval(bodyRect, Paint()..color = f.item.color);

        final tailWag = sin(time * 5 + f.tailPhase) * 4.0;
        final tailPath = Path()
          ..moveTo(-11, 0)
          ..lineTo(-22, -7 + tailWag)
          ..lineTo(-18, 0)
          ..lineTo(-22, 7 + tailWag)
          ..close();
        canvas.drawPath(tailPath, Paint()..color = f.item.secondaryColor);

        canvas.drawCircle(const Offset(7, -2), 2.0, Paint()..color = Colors.white);
        canvas.drawCircle(const Offset(8, -2), 0.9, Paint()..color = Colors.black);
      }

      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
