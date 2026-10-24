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
          y: item.isBottomDweller
              ? 726.0
              : 180.0 + (i * 70.0) % 360.0,
          vx: (_rand.nextBool() ? 1 : -1) * (26.0 + _rand.nextDouble() * 18.0),
          vy: (_rand.nextDouble() * 2 - 1) * 8.0,
          facingRight: _rand.nextBool(),
          tailPhase: _rand.nextDouble() * pi * 2,
        ),
      );
      _simFish.last.dartTimer = 2.0 + _rand.nextDouble() * 4.0;
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
    // A pellet an octopus is still tucking under itself counts as eaten too.
    for (final f in _simFish) {
      if (f.grabbedPellet != null) {
        save.onFishAtePellet(f.item.id);
        f.grabbedPellet = null;
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

  /// Drops 1 pellet from the top of the tank (used by the bottom button).
  /// Refuses (without consuming food) while every fish is already in its
  /// production cycle — a pellet then would sink uneaten and waste food.
  bool dropSinglePellet() {
    final save = SaveManager.instance;
    if (!save.hasWaitingFish) {
      AudioManager.instance.playSfx(GameSfx.hitWall);
      return false;
    }
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

  void _onTankTap(Offset rawPos) {
    if (!widget.interactive) return;

    // The simulation lives in a fixed 410x800 world; convert the real
    // tap position into world coordinates before hit-testing.
    final box = context.findRenderObject() as RenderBox?;
    if (box == null || box.size.isEmpty) return;
    final pos = Offset(
      rawPos.dx * 410.0 / box.size.width,
      rawPos.dy * 800.0 / box.size.height,
    );

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
    // Bütün balıklar üretimdeyse yem boşa gitmesin: tüketme, animasyon da yok
    if (!save.hasWaitingFish) {
      AudioManager.instance.playSfx(GameSfx.hitWall);
      return;
    }
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

  void _eatPellet(_SimFish f, _FoodPellet pellet, SaveManager save) {
    _foodPellets.remove(pellet);
    _creditMeal(f, save, sparkleDy: -6.0);
  }

  /// Shared meal bookkeeping + sparkles once a pellet is truly eaten.
  void _creditMeal(_SimFish f, SaveManager save, {required double sparkleDy}) {
    f.eatCooldown = 1.0;
    f.satiatedTimer = 14.0;
    save.onFishAtePellet(f.item.id);

    // Spawn eat sparkles
    for (int k = 0; k < 5; k++) {
      _eatParticles.add(
        _EatParticle(
          x: f.x + (_rand.nextDouble() * 2 - 1) * 8.0,
          y: f.y + sparkleDy,
          maxLife: 0.9 + _rand.nextDouble() * 0.4,
          color: const Color(0xFFFFD54F),
        ),
      );
    }
    AudioManager.instance.playSfx(GameSfx.bubble);
  }

  /// An octopus never gulps a pellet mid-water like a fish: it wraps its
  /// arms around the pellet and tucks it underneath its body, to the beak.
  /// The meal only counts once it has actually eaten down there.
  void _startGrabbing(_SimFish f, _FoodPellet pellet) {
    _foodPellets.remove(pellet);
    f.grabbedPellet = pellet;
    f.grabTimer = 0.85;
    AudioManager.instance.playSfx(GameSfx.bubble);
  }

  /// Tucks the grabbed pellet to the beak under the body and munches it.
  /// Returns true while the meal ritual is still running.
  bool _updateGrabbedMeal(_SimFish f, double dt, SaveManager save) {
    final gp = f.grabbedPellet;
    if (gp == null) return false;
    f.isMoving = false;
    f.grabTimer -= dt;
    // Arms drag the pellet to the centre of the underside and pin it.
    gp.x += (f.x - gp.x) * min(1.0, dt * 7.0);
    gp.y += ((f.y + 13.0) - gp.y) * min(1.0, dt * 7.0);
    if (f.grabTimer <= 0) {
      f.grabbedPellet = null;
      _creditMeal(f, save, sparkleDy: 9.0);
    }
    return true;
  }

  /// Snails glide, crabs scuttle and the octopus crawls along the sand.
  /// They move toward a sinking pellet and eat it once it reaches the
  /// bottom — the octopus first tucks it under its body (see
  /// [_startGrabbing]).
  /// [floorY] is the creature centre line in world coordinates; the
  /// sand surface sits at ~y=745, so bodies rest on the floor instead
  /// of hovering above it.
  void _updateBottomDweller(
      _SimFish f, _FoodPellet? pellet, double dt, SaveManager save) {
    const floorY = 726.0;
    f.y += (floorY - f.y) * min(1.0, dt * 3.0);
    f.pitchAngle = 0.0;
    final isSnail = f.item.kind == FishKind.snail;
    final isOctopus = f.item.kind == FishKind.octopus;

    // A tucked-under meal pauses everything until it is eaten.
    if (isOctopus && _updateGrabbedMeal(f, dt, save)) {
      return;
    }

    if (pellet != null && !f.isSatiated) {
      final dx = pellet.x - f.x;
      f.facingRight = dx >= 0;
      f.isMoving = true;
      final speed = isSnail ? 20.0 : (isOctopus ? 34.0 : 46.0);
      final step = speed * dt;
      f.x += dx.abs() < step ? dx : (dx > 0 ? step : -step);
      if (isOctopus) f.stepPhase += dt * 5.2;
      if (dx.abs() < 20.0 && pellet.y > 600.0) {
        if (isOctopus) {
          // Reached it: wrap the arms around it and tuck it underneath.
          _startGrabbing(f, pellet);
        } else {
          _eatPellet(f, pellet, save);
        }
      }
    } else if (isSnail) {
      f.isMoving = true;
      f.x += (f.facingRight ? 10.0 : -10.0) * dt;
    } else if (isOctopus) {
      // Arm-over-arm crawl: flowing pull bursts, then the octopus
      // gathers its arms and sits still for a beat before moving on.
      f.stepTimer -= dt;
      if (f.stepTimer <= 0) {
        f.isMoving = !f.isMoving;
        f.stepTimer = f.isMoving
            ? 0.9 + _rand.nextDouble() * 0.9
            : 0.7 + _rand.nextDouble() * 1.6;
        if (!f.isMoving && _rand.nextDouble() < 0.35) {
          f.facingRight = !f.facingRight;
        }
      }
      if (f.isMoving) {
        // Speed swells mid-stride and eases at both ends of each pull.
        f.stepPhase += dt * 5.0;
        final stride = 0.55 + 0.45 * sin(f.stepPhase * 2.0).abs();
        f.x += (f.facingRight ? 26.0 : -26.0) * stride * dt;
      }
    } else {
      // Crab scuttle: short sideways bursts with pauses between.
      f.stepTimer -= dt;
      if (f.stepTimer <= 0) {
        f.isMoving = !f.isMoving;
        f.stepTimer = f.isMoving ? 0.55 : 0.4;
        if (!f.isMoving && _rand.nextDouble() < 0.3) {
          f.facingRight = !f.facingRight;
        }
      }
      if (f.isMoving) {
        f.x += (f.facingRight ? 30.0 : -30.0) * dt;
      }
    }

    if (f.x < 35.0) {
      f.x = 35.0;
      f.facingRight = true;
    } else if (f.x > 375.0) {
      f.x = 375.0;
      f.facingRight = false;
    }
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

      if (f.item.isBottomDweller) {
        _updateBottomDweller(f, targetPellet, dt, save);
        continue;
      }

      if (targetPellet != null && !f.isSatiated) {
        // Eagerly swim towards assigned food pellet
        final dx = targetPellet.x - f.x;
        final dy = targetPellet.y - f.y;
        final dist = max(0.001, sqrt(dx * dx + dy * dy));

        if (dist < 22.0) {
          _eatPellet(f, targetPellet, save);
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
        var vx = (f.facingRight ? speed : -speed);
        var bobAmp = 12.0;

        if (f.item.kind == FishKind.shrimp) {
          // Tail-flick dash: every few seconds the shrimp snaps backward
          // without turning around, just like the real animal.
          f.dartTimer -= dt;
          if (f.dartTimer <= 0 && f.dartTime <= 0) {
            f.dartTime = 0.32;
            f.dartTimer = 3.5 + _rand.nextDouble() * 4.0;
          }
          if (f.dartTime > 0) {
            f.dartTime -= dt;
            vx = (f.facingRight ? -1.0 : 1.0) * 235.0;
            f.pitchAngle = (f.facingRight ? -0.35 : 0.35);
          }
        } else if (f.item.kind == FishKind.jellyfish) {
          // Pulse propulsion: the bell contracts to push up, then
          // relaxes and the jelly drifts slowly back down.
          bobAmp = 5.0;
          vx *= 0.35;
          final thrust = sin(_animTime * 2.2 + f.tailPhase);
          if (thrust > 0.2) {
            f.y -= 30.0 * dt;
          } else {
            f.y += 8.0 * dt;
          }
          // Lives in the upper-mid water column.
          if (f.y < 130.0) f.y += 20.0 * dt;
        }

        f.x += vx * dt;
        f.y += sin(_animTime * 1.5 + f.tailPhase) * bobAmp * dt;
        if (f.dartTime <= 0) {
          f.pitchAngle = sin(_animTime * 1.6 + f.tailPhase) * 0.08;
        }

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
          f1.x += pushX;
          f2.x -= pushX;

          // Vertical separation only between swimmers: bottom dwellers
          // stay glued to the floor (their update re-pins y anyway).
          if (!f1.item.isBottomDweller && !f2.item.isBottomDweller) {
            final pushY = (dy / dist) * overlap * 30.0 * dt;
            f1.y += pushY;
            f2.y -= pushY;
            if (f1.y < f2.y) {
              f1.y -= 16.0 * dt;
              f2.y += 16.0 * dt;
            } else {
              f1.y += 16.0 * dt;
              f2.y -= 16.0 * dt;
            }
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
  // Creature locomotion state
  double dartTimer = 0.0; // shrimp: time until the next tail-flick dash
  double dartTime = 0.0; // shrimp: remaining dash time
  double stepTimer = 0.0; // crab/octopus: walk burst / pause cycling
  double stepPhase = 0.0; // octopus: arm-over-arm stride cycle
  bool isMoving = true;
  // Octopus meal ritual: a pellet tucked under the body, eaten slowly.
  _FoodPellet? grabbedPellet;
  double grabTimer = 0.0;

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

    // The simulation runs in a fixed 410x800 world. Scale it onto the
    // real canvas so the sand, plants and bottom dwellers always sit
    // on the drawn floor, whatever the screen size.
    canvas.scale(size.width / 410.0, size.height / 800.0);

    // 1b. Soft underwater surface caustics filtering down from surface
    final causticPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          const Color(0xFF80D8FF).withValues(alpha: 0.05 + 0.02 * sin(time * 0.8)),
          const Color(0x0080D8FF),
        ],
        stops: const [0.0, 0.45],
      ).createShader(const Rect.fromLTWH(0, 0, 410, 360));
    canvas.drawRect(const Rect.fromLTWH(0, 0, 410, 360), causticPaint);

    // 2. Sand layer at the bottom of the world (surface ~y=745)
    _sandPath ??= Path()
      ..moveTo(0, 752)
      ..quadraticBezierTo(205, 738, 410, 756)
      ..lineTo(410, 800)
      ..lineTo(0, 800)
      ..close();
    _sandPaint.shader ??= const LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [Color(0x38C2A86E), Color(0x665C4628)],
    ).createShader(const Rect.fromLTWH(0, 738, 410, 62));
    canvas.drawPath(_sandPath!, _sandPaint);

    // 3. Plant clusters rooted in the sand: several blades per cluster
    // in two greens, each swaying on its own phase.
    const clusterX = [36.0, 128.0, 236.0, 330.0, 392.0];
    for (int c = 0; c < clusterX.length; c++) {
      final bx = clusterX[c];
      for (int blade = 0; blade < 4; blade++) {
        final lean = (blade - 1.5) * 7.0;
        final height = 64.0 + ((c * 37 + blade * 29) % 55);
        final sway = sin(time * 1.3 + c * 1.7 + blade * 0.9) * (6.0 + blade * 1.6);
        _plantPaint.color = blade.isEven
            ? const Color(0x6643A047)
            : const Color(0x8866BB6A);
        _plantPaint.strokeWidth = 4.5 + (blade % 2) * 1.4;
        _plantPath
          ..reset()
          ..moveTo(bx + lean * 0.4, 762)
          ..quadraticBezierTo(
            bx + lean + sway * 0.4, 762 - height * 0.55,
            bx + lean + sway, 762 - height,
          );
        canvas.drawPath(_plantPath, _plantPaint);
      }
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
    // Pellets an octopus has tucked underneath itself: drawn before the
    // creatures, so the body sits on top of the meal while it eats.
    for (final f in simFish) {
      final gp = f.grabbedPellet;
      if (gp == null) continue;
      canvas.drawCircle(Offset(gp.x, gp.y), 4.0, _foodGlow);
      canvas.drawCircle(Offset(gp.x, gp.y), 2.5, _foodPaint);
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

      // Creature motion language on top of the shared swim transform
      switch (f.item.kind) {
        case FishKind.snail:
          // Slow contented rocking as it glides
          canvas.rotate(sin(time * 2.0 + f.tailPhase) * 0.03);
          break;
        case FishKind.crab:
          // Little scuttle hops while it walks
          if (f.isMoving) {
            canvas.translate(0, -sin(time * 16.0 + f.tailPhase).abs() * 2.2);
          }
          canvas.rotate(sin(time * 8.0 + f.tailPhase) * 0.045);
          break;
        case FishKind.shrimp:
          // Constant gentle body curl sway
          canvas.rotate(sin(time * 6.0 + f.tailPhase) * 0.07);
          break;
        case FishKind.octopus:
          if (f.grabbedPellet != null) {
            // Hunched over the meal tucked under its body: pressed down
            // onto the sand, mantle pulsing with each bite at the beak.
            final bite = sin(time * 10.0 + f.tailPhase);
            canvas.scale(1.07, 0.90 + bite * 0.02);
            canvas.translate(0, 3.0 + bite * 0.4);
          } else if (f.isMoving) {
            // Arm-over-arm crawl: the mantle rides up once per stride
            // and leans into the pull, on top of its slow breathing.
            final stride = sin(f.stepPhase * 2.0);
            canvas.translate(0, -stride.abs() * 2.6);
            canvas.rotate(stride * 0.05);
            final pulse = 1.0 + sin(time * 2.4 + f.tailPhase) * 0.04;
            canvas.scale(pulse, 2.0 - pulse);
          } else {
            // Settled on the sand: breathing squash-and-stretch.
            final pulse = 1.0 + sin(time * 2.4 + f.tailPhase) * 0.05;
            canvas.scale(pulse, 2.0 - pulse);
            canvas.translate(0, sin(time * 1.8 + f.tailPhase) * 1.6);
          }
          break;
        case FishKind.jellyfish:
          // Bell pulse synced with the sim thrust: squeeze wide and
          // short on contraction, stretch tall as it relaxes.
          final bell = sin(time * 2.2 + f.tailPhase);
          canvas.scale(1.0 - bell * 0.06, 1.0 + bell * 0.09);
          canvas.rotate(sin(time * 1.4 + f.tailPhase) * 0.06);
          break;
        case FishKind.fish:
          break;
      }

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

      // 8. Status marker above fed fish: a bouncing gold coin once the
      // 6h gold is ready to collect, otherwise a thin 6h progress bar.
      if (f.isProducing || f.satiatedTimer > 0) {
        final save = SaveManager.instance;
        final floatY = -18.0 + sin(time * 3.5 + f.tailPhase) * 2.5;
        final pulse = 0.65 + 0.35 * sin(time * 4.0 + f.tailPhase);
        if (save.isFishGoldReady(f.item.id)) {
          // Ready coin: collect me from the hoard chest!
          _sparkPaint.color = const Color(0xFFFFD54F).withValues(alpha: 0.95);
          canvas.drawCircle(Offset(0, floatY), 5.6, _sparkPaint);
          _sparkPaint.color = const Color(0xFFFF8F00).withValues(alpha: 0.9);
          canvas.drawCircle(Offset(0, floatY), 3.4, _sparkPaint);
          _sparkPaint.color = Colors.white.withValues(alpha: 0.9 * pulse);
          canvas.drawCircle(Offset(-1.4, floatY - 1.4), 1.3, _sparkPaint);
        } else {
          _sparkPaint.color = const Color(0xFFFFD54F).withValues(alpha: 0.65 * pulse);
          canvas.drawCircle(Offset(0, floatY), 2.2, _sparkPaint);
          _sparkPaint.color = Colors.white.withValues(alpha: 0.85 * pulse);
          canvas.drawCircle(Offset(0, floatY), 1.0, _sparkPaint);
          if (f.isProducing) {
            // Production progress: fills up over the 6-hour cycle.
            final remain = save.remainingFishPayoutMs(f.item.id);
            final frac = (1.0 - remain / SaveManager.fishPayoutDurationMs).clamp(0.0, 1.0);
            const barW = 30.0;
            _sparkPaint.color = const Color(0x59000000);
            canvas.drawRRect(
              RRect.fromRectAndRadius(const Rect.fromLTWH(-barW / 2, -27, barW, 3.6), const Radius.circular(2)),
              _sparkPaint,
            );
            _sparkPaint.color = const Color(0xFF4FC3F7).withValues(alpha: 0.9);
            canvas.drawRRect(
              RRect.fromRectAndRadius(Rect.fromLTWH(-barW / 2, -27, barW * frac, 3.6), const Radius.circular(2)),
              _sparkPaint,
            );
          }
        }
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
