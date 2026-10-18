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
  State<EcoTankBackground> createState() => EcoTankBackgroundState();
}

class EcoTankBackgroundState extends State<EcoTankBackground> with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  Duration _lastElapsed = Duration.zero;

  final List<_SimFish> _simFish = [];
  final List<_Bubble> _bubbles = [];
  final List<_FoodPellet> _foodPellets = [];
  final List<_EatParticle> _eatParticles = [];
  final Random _rand = Random();
  double _animTime = 0.0;
  final _TankFrame _frame = _TankFrame();

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

      _animTime += clampedDt;
      _updateSimulation(clampedDt);
      _frame.ping();
    })..start();
  }

  void _initFish() {
    final save = SaveManager.instance;
    final fishIds = save.allOwnedFishInstances;
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
    // If user leaves screen while dropped pellets are still falling, apply them to eligible fish
    final save = SaveManager.instance;
    for (int i = 0; i < _foodPellets.length; i++) {
      _SimFish? target;
      for (final f in _simFish) {
        if (!save.isFishProducing(f.item.id)) {
          target = f;
          break;
        }
      }
      target ??= _simFish.cast<_SimFish?>().firstWhere(
            (f) => f != null && !save.isFishInSatietyCooldown(f.item.id),
            orElse: () => null,
          );
      if (target != null) {
        save.onFishAtePellet(target.item.id);
      }
    }
    _foodPellets.clear();
    _ticker.dispose();
    _frame.dispose();
    super.dispose();
  }

  void spawnFeast() {
    dropSinglePellet();
  }

  /// Drops 1 pellet from the top of the tank (used by the bottom button)
  bool dropSinglePellet() {
    final save = SaveManager.instance;
    if (!save.consumeFishFoodOne()) {
      AudioManager.instance.playSfx(GameSfx.hitWall);
      return false;
    }
    _foodPellets.add(
      _FoodPellet(
        x: 60.0 + _rand.nextDouble() * 260.0,
        y: 90.0 + _rand.nextDouble() * 40.0,
        vy: 30.0 + _rand.nextDouble() * 16.0,
        swayPhase: _rand.nextDouble() * pi * 2,
      ),
    );
    AudioManager.instance.playSfx(GameSfx.bubble);
    return true;
  }

  void _onTankTap(Offset pos) {
    if (!widget.interactive) return;

    // 1. Check if tap directly touches any fish
    _SimFish? hitFish;
    double minHitDist = 36.0;
    for (final f in _simFish) {
      final d = sqrt((pos.dx - f.x) * (pos.dx - f.x) + (pos.dy - f.y) * (pos.dy - f.y));
      if (d < minHitDist) {
        minHitDist = d;
        hitFish = f;
      }
    }

    if (hitFish != null) {
      // Tap on fish: barrel roll / flip, dart away playfully, spawn hearts!
      hitFish.flipTimer = 0.65;
      final dartDirX = hitFish.x >= pos.dx ? 1.0 : -1.0;
      final dartDirY = hitFish.y >= pos.dy ? 0.6 : -0.6;
      hitFish.vx = dartDirX * (85.0 + _rand.nextDouble() * 45.0);
      hitFish.vy = dartDirY * (40.0 + _rand.nextDouble() * 30.0);
      hitFish.facingRight = dartDirX > 0;

      // Spawn 3 floating hearts & bubbles
      for (int i = 0; i < 3; i++) {
        _eatParticles.add(
          _EatParticle(
            x: hitFish.x + (_rand.nextDouble() * 20.0 - 10.0),
            y: hitFish.y - 12.0 - (_rand.nextDouble() * 12.0),
            maxLife: 0.9 + _rand.nextDouble() * 0.4,
            color: const Color(0xFFFF4081),
            isHeart: true,
          ),
        );
      }
      AudioManager.instance.playSfx(GameSfx.bubble);
      return;
    }

    // 2. Open water tap: drop food pellet!
    _addFood(pos);
  }

  void _addFood(Offset pos) {
    if (!widget.interactive) return;
    final save = SaveManager.instance;
    // Yem yoksa yem atılma animasyonu olmasın
    if (!save.consumeFishFoodOne()) {
      AudioManager.instance.playSfx(GameSfx.hitWall);
      return;
    }

    // Spawn 1 food pellet exactly at tap position
    _foodPellets.add(
      _FoodPellet(
        x: pos.dx,
        y: pos.dy,
        vy: 30.0 + _rand.nextDouble() * 16.0,
        swayPhase: _rand.nextDouble() * pi * 2,
      ),
    );
    AudioManager.instance.playSfx(GameSfx.click);
  }

  void _updateSimulation(double dt) {
    final save = SaveManager.instance;

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

    // 4. Update fish tail animation, flip roll, and short bite cooldowns
    for (final f in _simFish) {
      f.tailPhase += dt * 4.5;
      if (f.eatCooldown > 0) {
        f.eatCooldown -= dt;
      }
      if (f.satiatedTimer > 0) {
        f.satiatedTimer -= dt;
      }
      if (f.flipTimer > 0) {
        f.flipTimer -= dt;
        f.flipProgress = (1.0 - (f.flipTimer / 0.65)).clamp(0.0, 1.0);
      }
    }

    // 5. Assign each pellet to an eligible fish:
    // Rule: Fish fed within the last 3 hours NEVER eat ("beslenen balık 3 saat boyunca bişi yemesin").
    // Priority 1: Unfed fish (not yet in 6h production cycle).
    // Priority 2: Fish whose 3-hour satiety cooldown has expired ("3 saat sonra istediği kadar yesin ama bişi değişmesin").
    final Map<_SimFish, _FoodPellet> fishTargetPellet = {};
    for (final pellet in _foodPellets) {
      _SimFish? chosenFish;
      double minDist = 999999.0;

      // Priority 1: Unfed fish not yet assigned to another pellet
      for (final f in _simFish) {
        if (f.eatCooldown > 0 || f.isSatiated) continue;
        if (save.isFishProducing(f.item.id)) continue;
        if (fishTargetPellet.containsKey(f)) continue;
        final dist = sqrt((pellet.x - f.x) * (pellet.x - f.x) + (pellet.y - f.y) * (pellet.y - f.y));
        if (dist < minDist) {
          minDist = dist;
          chosenFish = f;
        }
      }

      // Priority 2: Any fish past its 3-hour satiety cooldown not yet assigned to another pellet
      if (chosenFish == null) {
        for (final f in _simFish) {
          if (f.eatCooldown > 0 || f.isSatiated) continue;
          if (fishTargetPellet.containsKey(f)) continue;
          final dist = sqrt((pellet.x - f.x) * (pellet.x - f.x) + (pellet.y - f.y) * (pellet.y - f.y));
          if (dist < minDist) {
            minDist = dist;
            chosenFish = f;
          }
        }
      }

      if (chosenFish != null) {
        fishTargetPellet[chosenFish] = pellet;
      }
    }

    // 6. Update fish swimming towards target or ambient patrol
    for (final f in _simFish) {
      final targetPellet = fishTargetPellet[f];

      if (targetPellet != null && !f.isSatiated) {
        // Eagerly swim towards assigned food pellet
        final dx = targetPellet.x - f.x;
        final dy = targetPellet.y - f.y;
        final dist = max(0.001, sqrt(dx * dx + dy * dy));

        if (dist < 22.0) {
          // Eat pellet!
          _foodPellets.remove(targetPellet);
          f.eatCooldown = 1.0;
          f.satiatedTimer = 14.0;
          save.onFishAtePellet(f.item.id);

          // Spawn eat sparkles
          for (int k = 0; k < 5; k++) {
            _eatParticles.add(
              _EatParticle(
                x: f.x + (_rand.nextDouble() * 2 - 1) * 8.0,
                y: f.y - 6.0,
                maxLife: 0.9 + _rand.nextDouble() * 0.4,
                color: const Color(0xFFFFD54F),
              ),
            );
          }
          AudioManager.instance.playSfx(GameSfx.bubble);
        } else {
          final swimSpeed = (dist > 140 ? 115.0 : 88.0) * (1.0 + f.item.size * 0.1);
          f.x += (dx / dist) * swimSpeed * dt;
          f.y += (dy / dist) * swimSpeed * dt;
          f.facingRight = dx >= 0;
          f.pitchAngle = (dy / dist * 0.4).clamp(-0.45, 0.45);
        }
      } else {
        // Calm ambient swimming (satiated fish swim slower and happier)
        final speedMult = f.isSatiated ? 0.8 : 1.0;
        final speed = f.vx.abs() * speedMult;
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
      onTapDown: (details) => _onTankTap(details.localPosition),
      child: Stack(
        children: [
          Positioned.fill(
            child: RepaintBoundary(
              child: CustomPaint(
                painter: _TankPainter(this),
              ),
            ),
          ),
          if (widget.child != null)
            RepaintBoundary(
              child: widget.child!,
            ),
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
  double satiatedTimer = 0.0;
  double flipTimer = 0.0;
  double flipProgress = 0.0;

  /// True while the fish is in its 3-hour post-feeding satiety window
  bool get isSatiated => SaveManager.instance.isFishInSatietyCooldown(item.id);
  bool get isProducing => SaveManager.instance.isFishProducing(item.id);

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
  final bool isHeart;

  _EatParticle({
    required this.x,
    required this.y,
    required this.maxLife,
    required this.color,
    this.isHeart = false,
  }) : life = maxLife;
}

class _TankFrame extends ChangeNotifier {
  void ping() => notifyListeners();
}

class _TankPainter extends CustomPainter {
  final EcoTankBackgroundState host;
  Size? _shaderSize;
  Shader? _waterShader;
  final Paint _waterPaint = Paint();
  final Paint _sandPaint = Paint();
  final Paint _plantPaint = Paint()
    ..color = const Color(0x5543A047)
    ..style = PaintingStyle.stroke
    ..strokeWidth = 4.5
    ..strokeCap = StrokeCap.round;
  final Paint _bubblePaint = Paint()..color = const Color(0x2881D4FA);
  final Paint _foodPaint = Paint()..color = const Color(0xFFFFD54F);
  final Paint _foodGlow = Paint()..color = const Color(0x44FFD54F);
  final Paint _sparkPaint = Paint();
  final Paint _imgPaint = Paint()..filterQuality = FilterQuality.low;
  final Paint _bodyPaint = Paint();
  final Paint _tailPaint = Paint();
  final Paint _eyeWhite = Paint()..color = const Color(0xFFFFFFFF);
  final Paint _eyeBlack = Paint()..color = const Color(0xFF000000);
  final Path _tailPath = Path();
  final Path _plantPath = Path();
  Path? _sandPath;

  _TankPainter(this.host) : super(repaint: host._frame);

  List<_SimFish> get simFish => host._simFish;
  List<_Bubble> get bubbles => host._bubbles;
  List<_FoodPellet> get foodPellets => host._foodPellets;
  List<_EatParticle> get eatParticles => host._eatParticles;
  double get time => host._animTime;

  @override
  void paint(Canvas canvas, Size size) {
    if (_waterShader == null || _shaderSize != size) {
      _shaderSize = size;
      _sandPath = null;
      _sandPaint.shader = null;
      _waterShader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xFF0C1726), Color(0xFF09131F), Color(0xFF040A10)],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));
    }
    _waterPaint.shader = _waterShader;
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), _waterPaint);

    // 2. Sand layer at bottom
    _sandPath ??= Path()
      ..moveTo(0, size.height - 48)
      ..quadraticBezierTo(size.width * 0.5, size.height - 62, size.width, size.height - 44)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    _sandPaint.shader ??= const LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [Color(0x38C2A86E), Color(0x665C4628)],
    ).createShader(Rect.fromLTWH(0, size.height - 62, size.width, 62));
    canvas.drawPath(_sandPath!, _sandPaint);

    // 3. Kelp & Moss plants swaying gently

    for (int i = 0; i < 5; i++) {
      final bx = 25.0 + i * (size.width - 50) / 4;
      final sway = sin(time * 1.5 + i) * 11.0;
      _plantPath
        ..reset()
        ..moveTo(bx, size.height - 44)
        ..quadraticBezierTo(bx + sway * 0.5, size.height - 95, bx + sway, size.height - 145);
      canvas.drawPath(_plantPath, _plantPaint);
    }

    // 4. Rising bubbles
    for (final b in bubbles) {
      canvas.drawCircle(Offset(b.x + sin(time + b.radius) * 3, b.y), b.radius, _bubblePaint);
    }

    // 5. Food Pellets
    for (final p in foodPellets) {
      canvas.drawCircle(Offset(p.x, p.y), 4.0, _foodGlow);
      canvas.drawCircle(Offset(p.x, p.y), 2.5, _foodPaint);
    }

    // 6. Eat particles & tap reaction hearts
    for (final ep in eatParticles) {
      final alpha = (ep.life / ep.maxLife).clamp(0.0, 1.0);
      _sparkPaint.color = ep.color.withValues(alpha: alpha);
      if (ep.isHeart) {
        final r = 3.4 * alpha;
        canvas.drawCircle(Offset(ep.x - r * 0.45, ep.y - r * 0.3), r * 0.60, _sparkPaint);
        canvas.drawCircle(Offset(ep.x + r * 0.45, ep.y - r * 0.3), r * 0.60, _sparkPaint);
        _tailPath
          ..reset()
          ..moveTo(ep.x - r * 1.0, ep.y - r * 0.1)
          ..lineTo(ep.x + r * 1.0, ep.y - r * 0.1)
          ..lineTo(ep.x, ep.y + r * 1.2)
          ..close();
        canvas.drawPath(_tailPath, _sparkPaint);
      } else {
        canvas.drawCircle(Offset(ep.x, ep.y), 2.0 * alpha, _sparkPaint);
      }
    }

    // 7. Fish drawing (Scaled down to realistic proportion)
    for (final f in simFish) {
      canvas.save();
      canvas.translate(f.x, f.y);

      if (!f.facingRight) {
        canvas.scale(-1, 1);
      }
      final rollAngle = f.flipTimer > 0 ? (f.flipProgress * pi * 2.0) : 0.0;
      canvas.rotate(f.pitchAngle + rollAngle);

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
        canvas.drawImageRect(img, src, dst, _imgPaint);
      } else {
        // Fallback procedural fish
        final fishScale = f.item.size * 0.7;
        canvas.scale(fishScale, fishScale);
        final bodyRect = Rect.fromCenter(center: Offset.zero, width: 26, height: 13);
        _bodyPaint.color = f.item.color;
        canvas.drawOval(bodyRect, _bodyPaint);

        final tailWag = sin(time * 5 + f.tailPhase) * 4.0;
        _tailPath
          ..reset()
          ..moveTo(-11, 0)
          ..lineTo(-22, -7 + tailWag)
          ..lineTo(-18, 0)
          ..lineTo(-22, 7 + tailWag)
          ..close();
        _tailPaint.color = f.item.secondaryColor;
        canvas.drawPath(_tailPath, _tailPaint);

        canvas.drawCircle(const Offset(7, -2), 2.0, _eyeWhite);
        canvas.drawCircle(const Offset(8, -2), 0.9, _eyeBlack);
      }

      // 8. Golden sparkle indicator above fed/producing fish
      if (f.isProducing || f.satiatedTimer > 0) {
        final floatY = -18.0 + sin(time * 3.5 + f.tailPhase) * 2.5;
        final pulse = 0.65 + 0.35 * sin(time * 4.0 + f.tailPhase);
        _sparkPaint.color = const Color(0xFFFFD54F).withValues(alpha: 0.65 * pulse);
        canvas.drawCircle(Offset(0, floatY), 2.2, _sparkPaint);
        _sparkPaint.color = Colors.white.withValues(alpha: 0.85 * pulse);
        canvas.drawCircle(Offset(0, floatY), 1.0, _sparkPaint);
      }

      canvas.restore();
    }

    // 9. Premium Aquarium Tank Frame & Edge Vignette
    // Left edge shadow (12px)
    _sandPaint.shader = const LinearGradient(
      colors: [Color(0xBB03080E), Colors.transparent],
      begin: Alignment.centerLeft,
      end: Alignment.centerRight,
    ).createShader(Rect.fromLTWH(0, 0, 14, size.height));
    canvas.drawRect(Rect.fromLTWH(0, 0, 14, size.height), _sandPaint);

    // Right edge shadow (12px)
    _sandPaint.shader = const LinearGradient(
      colors: [Colors.transparent, Color(0xBB03080E)],
      begin: Alignment.centerLeft,
      end: Alignment.centerRight,
    ).createShader(Rect.fromLTWH(size.width - 14, 0, 14, size.height));
    canvas.drawRect(Rect.fromLTWH(size.width - 14, 0, 14, size.height), _sandPaint);

    // Top edge shadow (16px)
    _sandPaint.shader = const LinearGradient(
      colors: [Color(0xAA03080E), Colors.transparent],
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
    ).createShader(Rect.fromLTWH(0, 0, size.width, 18));
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, 18), _sandPaint);
    _sandPaint.shader = null;

    // Subtle cyan edge glass reflection line on left and right
    final borderPaint = Paint()
      ..color = const Color(0x2280D8FF)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;
    canvas.drawLine(const Offset(0.5, 0), Offset(0.5, size.height), borderPaint);
    canvas.drawLine(Offset(size.width - 0.5, 0), Offset(size.width - 0.5, size.height), borderPaint);
  }

  @override
  bool shouldRepaint(covariant _TankPainter oldDelegate) => false;
}
