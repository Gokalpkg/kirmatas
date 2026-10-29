import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import '../engine/asset_cache.dart';
import '../engine/audio_manager.dart';
import '../models/cosmetics.dart';
import '../storage/save_manager.dart';
import 'fish_rig.dart';
import 'octopus_rig.dart';
import 'plant_system.dart';

class EcoTankBackground extends StatefulWidget {
  final bool interactive;
  final Widget? child;
  final void Function(Offset worldPos, int gold)? onBubblePopped;
  final VoidCallback? onOutOfFood;
  final VoidCallback? onAllFishFed;
  final void Function(bool isZoomed, double zoom)? onCameraZoomChanged;

  const EcoTankBackground({
    super.key,
    this.interactive = false,
    this.child,
    this.onBubblePopped,
    this.onOutOfFood,
    this.onAllFishFed,
    this.onCameraZoomChanged,
  });

  @override
  State<EcoTankBackground> createState() => EcoTankBackgroundState();
}

class EcoTankBackgroundState extends State<EcoTankBackground> with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  Duration _lastElapsed = Duration.zero;

  final TankCamera camera = TankCamera();
  bool get isCameraZoomed => camera.isZoomed;
  double get cameraZoom => camera.zoom;

  double _startScale = 1.0;
  Offset? _lastFocalPoint;
  bool _hasMovedSignificantly = false;

  void toggleCameraZoom({Offset? focalPoint}) {
    camera.toggleZoom(focalWorldPoint: focalPoint);
    widget.onCameraZoomChanged?.call(camera.isZoomed, camera.targetZoom);
  }

  void zoomIn({Offset? focalPoint}) {
    camera.zoomIn(focalWorldPoint: focalPoint);
    widget.onCameraZoomChanged?.call(camera.isZoomed, camera.targetZoom);
  }

  void zoomOut() {
    camera.zoomOut();
    widget.onCameraZoomChanged?.call(camera.isZoomed, camera.targetZoom);
  }

  final List<_SimFish> _simFish = [];
  final List<_Bubble> _bubbles = [];
  final List<_FoodPellet> _foodPellets = [];
  final List<_EatParticle> _eatParticles = [];
  final List<_InkCloud> _inkClouds = [];
  final List<AquariumPlant> _plants = [];
  final List<PlantOxygenBubble> _plantBubbles = [];
  final Random _rand = Random();
  double _animTime = 0.0;
  final _TankFrame _frame = _TankFrame();

  bool _isFingerMode = false;
  bool get isFingerMode => _isFingerMode;
  Offset? _fingerWorldPos;
  Offset? get fingerWorldPos => _fingerWorldPos;

  void setFingerMode(bool enabled) {
    setState(() {
      _isFingerMode = enabled;
      if (!enabled) _fingerWorldPos = null;
    });
  }

  Offset _toWorldPos(Offset rawPos) {
    final box = context.findRenderObject() as RenderBox?;
    if (box == null || box.size.isEmpty) return rawPos;
    final w = box.size.width;
    final h = box.size.height;
    final z = max(0.5, camera.zoom);
    final worldX = 205.0 - camera.pan.dx + ((rawPos.dx - w / 2.0) * (410.0 / w)) / z;
    final worldY = 400.0 - camera.pan.dy + ((rawPos.dy - h / 2.0) * (800.0 / h)) / z;
    return Offset(
      worldX.clamp(15.0, 395.0),
      worldY.clamp(70.0, 740.0),
    );
  }

  void _onFingerDown(Offset rawPos) {
    if (!widget.interactive) return;
    _fingerWorldPos = _toWorldPos(rawPos);
  }

  void _onFingerMove(Offset rawPos) {
    if (!widget.interactive || !_isFingerMode) return;
    _fingerWorldPos = _toWorldPos(rawPos);
  }

  void _onFingerUp() {
    _fingerWorldPos = null;
  }

  @override
  void initState() {
    super.initState();
    _initFish();
    _initPlants();
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
      camera.update(clampedDt);
      _updateSimulation(clampedDt);
      _frame.ping();
    })..start();
  }

  void _initFish() {
    final save = SaveManager.instance;
    final fishIds = save.allOwnedFishInstances;
    for (int i = 0; i < fishIds.length; i++) {
      final item = FishItem.getById(fishIds[i]);
      final isBg = (i % 3 == 0) && !item.isBottomDweller;
      final zDepth = isBg ? 0.74 : 1.0;
      _simFish.add(
        _SimFish(
          item: item,
          zDepth: zDepth,
          x: 50.0 + (i * 65.0) % 280.0,
          y: item.isBottomDweller
              ? 728.0
              : 190.0 + (i * 68.0) % 340.0,
          vx: (_rand.nextBool() ? 1 : -1) * (26.0 + _rand.nextDouble() * 18.0) * (isBg ? 0.82 : 1.0),
          vy: (_rand.nextDouble() * 2 - 1) * 8.0,
          facingRight: _rand.nextBool(),
          tailPhase: _rand.nextDouble() * pi * 2,
        ),
      );
      _simFish.last.dartTimer = 2.0 + _rand.nextDouble() * 4.0;
      final rig = _simFish.last.rig;
      if (rig != null) {
        // The octopus starts at rest on the sand (its rig owns velocity).
        _simFish.last.vx = 0.0;
        _simFish.last.vy = 0.0;
        rig.x = _simFish.last.x;
        rig.y = _simFish.last.y;
        rig.facingRight = _simFish.last.facingRight;
      }
    }
  }

  void _initPlants() {
    _plants.addAll([
      // Left background: tall flowing Vallisneria ribbon grass
      AquariumPlant(
        species: PlantSpecies.vallisneria,
        baseX: 34.0,
        baseY: 756.0,
        scale: 1.15,
        isForeground: false,
      ),
      // Left midground: vibrant Rotala stem cluster with coral/ruby tops
      AquariumPlant(
        species: PlantSpecies.rotala,
        baseX: 95.0,
        baseY: 752.0,
        scale: 1.05,
        isForeground: false,
      ),
      // Center-left foreground: broad waxy Anubias Nana
      AquariumPlant(
        species: PlantSpecies.anubias,
        baseX: 165.0,
        baseY: 748.0,
        scale: 1.0,
        isForeground: true,
      ),
      // Center-right foreground: broad lush Anubias Nana
      AquariumPlant(
        species: PlantSpecies.anubias,
        baseX: 245.0,
        baseY: 746.0,
        scale: 1.1,
        isForeground: true,
      ),
      // Right midground: lush Rotala stem cluster
      AquariumPlant(
        species: PlantSpecies.rotala,
        baseX: 315.0,
        baseY: 752.0,
        scale: 1.1,
        isForeground: false,
      ),
      // Right background: tall flowing Vallisneria ribbon grass
      AquariumPlant(
        species: PlantSpecies.vallisneria,
        baseX: 382.0,
        baseY: 758.0,
        scale: 1.2,
        isForeground: false,
      ),
    ]);
  }

  void _initBubbles() {
    // Subtle, calm ambient bubbles (kept minimal for clean aquarium aesthetic)
    for (int i = 0; i < 5; i++) {
      _bubbles.add(
        _Bubble(
          x: _rand.nextDouble() * 380.0,
          y: _rand.nextDouble() * 720.0,
          radius: 1.5 + _rand.nextDouble() * 2.2,
          speed: 14.0 + _rand.nextDouble() * 16.0,
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

    // 0. Check if tap directly hits any rising plant oxygen bubble (reward with 1 gold)
    PlantOxygenBubble? hitBubble;
    double minBubbleDist = 28.0;
    int hitBubbleIndex = -1;
    for (int i = _plantBubbles.length - 1; i >= 0; i--) {
      final b = _plantBubbles[i];
      final d = sqrt((pos.dx - b.x) * (pos.dx - b.x) + (pos.dy - b.y) * (pos.dy - b.y));
      if (d < minBubbleDist) {
        minBubbleDist = d;
        hitBubble = b;
        hitBubbleIndex = i;
      }
    }

    if (hitBubble != null && hitBubbleIndex >= 0) {
      final popX = hitBubble.x;
      final popY = hitBubble.y;
      _plantBubbles.removeAt(hitBubbleIndex);

      // Pop splash: 8 tiny sparkling droplets scattering outwards
      for (int i = 0; i < 8; i++) {
        final ang = _rand.nextDouble() * pi * 2;
        _eatParticles.add(
          _EatParticle(
            x: popX + cos(ang) * 4.0,
            y: popY + sin(ang) * 4.0,
            maxLife: 0.45 + _rand.nextDouble() * 0.35,
            color: i % 2 == 0 ? const Color(0xFF80D8FF) : Colors.white,
          ),
        );
      }

      // Sparkle reward particle
      _eatParticles.add(
        _EatParticle(
          x: popX,
          y: popY - 6.0,
          maxLife: 0.85,
          color: const Color(0xFFFFD54F),
        ),
      );

      AudioManager.instance.playSfx(GameSfx.bubble);
      SaveManager.instance.addGold(1);
      widget.onBubblePopped?.call(Offset(popX, popY), 1);
      return;
    }

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
      if (hitFish.rig != null) {
        // The octopus startles: mantle pulse jet away (sometimes with ink).
        _startleOctopus(hitFish, pos);
      } else {
        hitFish.flipTimer = 0.65;
        final dartDirX = hitFish.x >= pos.dx ? 1.0 : -1.0;
        final dartDirY = hitFish.y >= pos.dy ? 0.6 : -0.6;
        hitFish.vx = dartDirX * (85.0 + _rand.nextDouble() * 45.0);
        hitFish.vy = dartDirY * (40.0 + _rand.nextDouble() * 30.0);
        hitFish.facingRight = dartDirX > 0;
      }

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
      widget.onAllFishFed?.call();
      return;
    }
    // Yem yoksa yem atılma animasyonu olmasın
    if (!save.consumeFishFoodOne()) {
      AudioManager.instance.playSfx(GameSfx.hitWall);
      widget.onOutOfFood?.call();
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
    if (f.isSatiated || save.isFishProducing(f.item.id)) return;
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
  void _startGrabbing(_SimFish f, _FoodPellet pellet, [SaveManager? save]) {
    final s = save ?? SaveManager.instance;
    if (f.isSatiated || s.isFishProducing(f.item.id)) return;
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

  /// Snails glide and crabs scuttle along the sand. They move toward a
  /// sinking pellet and eat it once it reaches the bottom. (The octopus
  /// has its own locomotion: see [_updateOctopus].)
  /// [floorY] is the creature centre line in world coordinates; the
  /// sand surface sits at ~y=745, so bodies rest on the floor instead
  /// of hovering above it.
  void _updateBottomDweller(
      _SimFish f, _FoodPellet? pellet, double dt, SaveManager save) {
    const floorY = 726.0;
    if (f.rig != null) {
      _updateOctopus(f, pellet, dt, save);
      return;
    }
    f.y += (floorY - f.y) * min(1.0, dt * 3.0);
    f.pitchAngle = 0.0;
    final isSnail = f.item.kind == FishKind.snail;

    if (_fingerWorldPos != null) {
      final dx = _fingerWorldPos!.dx - f.x;
      f.facingRight = dx >= 0;
      final dist = dx.abs();
      f.isMoving = dist > 14.0;
      if (f.isMoving) {
        final speed = isSnail ? 22.0 : 48.0;
        final step = speed * dt;
        f.x += dx > 0 ? min(step, dx) : max(-step, dx);
      }
      _syncFishRig(f, dt, target: _fingerWorldPos, isFinger: true);
      return;
    }

    if (pellet != null && !f.isSatiated && !save.isFishProducing(f.item.id)) {
      final dx = pellet.x - f.x;
      f.facingRight = dx >= 0;
      f.isMoving = true;
      final speed = isSnail ? 20.0 : 46.0;
      final step = speed * dt;
      f.x += dx.abs() < step ? dx : (dx > 0 ? step : -step);
      if (dx.abs() < 20.0 && pellet.y > 600.0) {
        _eatPellet(f, pellet, save);
      }
    } else if (isSnail) {
      f.isMoving = true;
      f.x += (f.facingRight ? 10.0 : -10.0) * dt;
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

    _syncFishRig(
      f,
      dt,
      target: pellet == null ? null : Offset(pellet.x, pellet.y),
      isFood: pellet != null && !f.isSatiated && !save.isFishProducing(f.item.id),
    );
  }

  void _syncFishRig(
    _SimFish f,
    double dt, {
    Offset? target,
    bool isFood = false,
    bool isFinger = false,
  }) {
    final fr = f.fishRig;
    if (fr == null) return;
    fr.x = f.x;
    fr.y = f.y;
    fr.vx = f.vx;
    fr.vy = f.vy;
    fr.faceToward(f.facingRight);
    if (f.item.kind == FishKind.shrimp) {
      fr.specialActive = f.dartTime > 0 ? 1.0 : 0.0;
    }
    fr.step(
      dt,
      _animTime,
      target: target,
      isFoodTarget: isFood,
      isFingerTarget: isFinger,
      satiated: f.isSatiated,
      isMovingOverride: f.isMoving,
    );
  }

  /// The octopus: crawls arm-over-arm on the sand, jets through the water
  /// with mantle pulses, reaches for the player's finger and wraps food
  /// under its body. Locomotion lives in [OctopusRig].
  void _updateOctopus(_SimFish f, _FoodPellet? pellet, double dt, SaveManager save) {
    const floorY = 726.0;
    final rig = f.rig!;
    final grabbing = f.grabbedPellet != null;
    final hungry = pellet != null && !f.isSatiated && !save.isFishProducing(f.item.id);

    rig.x = f.x;
    rig.y = f.y;
    rig.step(
      dt,
      _animTime,
      floorY: floorY,
      finger: _fingerWorldPos,
      food: pellet == null ? null : Offset(pellet.x, pellet.y),
      hungry: hungry,
      grabbing: grabbing,
    );
    f.x = rig.x;
    f.y = rig.y;
    f.facingRight = rig.facingRight;
    f.pitchAngle = rig.pitch;
    f.isMoving = rig.state == OctState.crawl;
    f.stepPhase = rig.stepPhase;

    // A tucked-under meal pauses everything until it is eaten.
    if (_updateGrabbedMeal(f, dt, save)) return;

    if (hungry && !rig.isAirborne) {
      final dx = pellet.x - f.x;
      final dy = pellet.y - f.y;
      if (dx * dx + dy * dy < 26.0 * 26.0) {
        _startGrabbing(f, pellet, save);
      }
    }
  }

  /// Squirts a cloud of ink behind the octopus.
  void _spawnInk(double x, double y) {
    for (int i = 0; i < 7; i++) {
      _inkClouds.add(
        _InkCloud(
          x: x + (_rand.nextDouble() * 22.0 - 11.0),
          y: y + (_rand.nextDouble() * 18.0 - 9.0),
          radius: 5.0 + _rand.nextDouble() * 5.0,
          maxLife: 1.6 + _rand.nextDouble() * 0.9,
        ),
      );
    }
  }

  /// Tap reaction: the octopus startles, jets away and sometimes inks.
  void _startleOctopus(_SimFish f, Offset tapPos) {
    final rig = f.rig!;
    final dir = f.x >= tapPos.dx ? 1.0 : -1.0;
    rig.x = f.x;
    rig.y = f.y;
    if (_rand.nextDouble() < 0.3) _spawnInk(f.x, f.y);
    rig.startJet(f.x + dir * (70.0 + _rand.nextDouble() * 60.0), f.y - (90.0 + _rand.nextDouble() * 90.0), pulses: 2);
    rig.jetCooldown = 1.5;
  }

  void _updateSimulation(double dt) {
    final save = SaveManager.instance;

    // Update procedural plants & photosynthetic pearling bubbles (capped at strictly max 8 on screen)
    for (final p in _plants) {
      p.update(dt, _animTime, onEmitOxygen: (ox, oy, oradius) {
        if (_plantBubbles.length < 8) {
          _plantBubbles.add(
            PlantOxygenBubble(
              x: ox,
              y: oy,
              initialRadius: 0.6,
              maxRadius: 2.8 + _rand.nextDouble() * 1.4,
              speed: 18.0 + _rand.nextDouble() * 12.0,
              wobblePhase: _rand.nextDouble() * pi * 2,
              isForming: true,
              growDuration: 2.6 + _rand.nextDouble() * 1.8,
            ),
          );
        }
      });
    }
    for (int i = _plantBubbles.length - 1; i >= 0; i--) {
      if (_plantBubbles[i].update(dt)) {
        _plantBubbles.removeAt(i);
      }
    }

    // 1. Update bubbles (gentle rising)
    for (final b in _bubbles) {
      b.y -= b.speed * dt * 0.75;
      if (b.y < -10) {
        b.y = 800.0;
        b.x = _rand.nextDouble() * 400.0;
      }
    }

    // 2. Update food pellets (persist on the sand bed so no food is wasted)
    for (int i = _foodPellets.length - 1; i >= 0; i--) {
      final p = _foodPellets[i];
      p.update(dt);
      if (p.bottomRestTimer > 60.0 || p.life > 90.0 || p.y > 750.0) {
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
    for (int i = _inkClouds.length - 1; i >= 0; i--) {
      final ink = _inkClouds[i];
      ink.life += dt;
      ink.y -= 6.0 * dt;
      ink.x += sin(ink.life * 2.0 + i) * 5.0 * dt;
      if (ink.life >= ink.maxLife) _inkClouds.removeAt(i);
    }
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
          if (save.isFishProducing(f.item.id)) continue;
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

      if (_fingerWorldPos != null) {
        // Finger attraction: swim eagerly toward the player's touch!
        final dx = _fingerWorldPos!.dx - f.x;
        final dy = _fingerWorldPos!.dy - f.y;
        final dist = max(0.001, sqrt(dx * dx + dy * dy));

        if (dist > 30.0) {
          final swimSpeed = (dist > 120 ? 145.0 : 100.0) * (1.0 + f.item.size * 0.1);
          f.x += (dx / dist) * swimSpeed * dt;
          f.y += (dy / dist) * swimSpeed * dt;
          f.facingRight = dx >= 0;
          f.pitchAngle = (dy / dist * 0.45).clamp(-0.5, 0.5);
        } else {
          // Playful schooling/orbiting around finger!
          final orbitAngle = _animTime * 3.6 + f.tailPhase;
          f.x += cos(orbitAngle) * 36.0 * dt;
          f.y += sin(orbitAngle) * 22.0 * dt;
          f.facingRight = cos(orbitAngle) >= 0;
          f.pitchAngle = (sin(orbitAngle) * 0.25).clamp(-0.35, 0.35);
        }
        f.x = f.x.clamp(35.0, 375.0);
        f.y = f.y.clamp(148.0, 700.0);
        _syncFishRig(f, dt, target: _fingerWorldPos, isFinger: true);
        continue;
      }

      if (targetPellet != null && !f.isSatiated && !save.isFishProducing(f.item.id)) {
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
        _syncFishRig(f, dt, target: Offset(targetPellet.x, targetPellet.y), isFood: true);
      } else {
        // Calm ambient swimming with burst & glide rhythm and species character
        final fr = f.fishRig;
        final burstMult = fr?.currentSwimSpeedMultiplier ?? 1.0;
        final speedMult = (f.isSatiated ? 0.8 : 1.0) * burstMult;
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
            f.y -= 26.0 * dt;
          } else {
            f.y += 8.0 * dt;
          }
          // Lives in mid-upper water column safely below UI bar
          if (f.y < 170.0) f.y += 24.0 * dt;
          if (f.y > 440.0) f.y -= 20.0 * dt;
        } else if (fr?.style.species == FishSpecies.arowana) {
          // Arowana patrols the upper water column with level poise below top UI
          bobAmp = 4.5;
          if (f.y > 270.0) {
            f.y -= 18.0 * dt;
          } else if (f.y < 165.0) {
            f.y += 18.0 * dt;
          }
        } else if (fr?.style.species == FishSpecies.tetra) {
          // Tetra schooling cohesion: align direction and depth with nearby tetras
          int neighbors = 0;
          double avgY = 0.0;
          int rightVotes = 0;
          for (final other in _simFish) {
            if (other == f || other.fishRig?.style.species != FishSpecies.tetra) continue;
            final d = sqrt(pow(other.x - f.x, 2) + pow(other.y - f.y, 2));
            if (d < 135.0) {
              neighbors++;
              avgY += other.y;
              if (other.facingRight) rightVotes++;
            }
          }
          if (neighbors > 0) {
            avgY /= neighbors;
            f.y += (avgY - f.y) * min(1.0, dt * 1.6);
            if (_rand.nextDouble() < 0.02) {
              f.facingRight = rightVotes * 2 >= neighbors;
            }
          }
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
        f.y = f.y.clamp(148.0, 680.0);
        _syncFishRig(f, dt);
      }
    }

    // 6. Fish Collision Avoidance (Separation steering / Boids repulsion)
    for (int i = 0; i < _simFish.length; i++) {
      for (int j = i + 1; j < _simFish.length; j++) {
        final f1 = _simFish[i];
        final f2 = _simFish[j];
        final dx = f1.x - f2.x;
        final dy = f1.y - f2.y;
        final dist = sqrt(dx * dx + dy * dy);
        const minDistance = 56.0;

        if (dist < minDistance && dist > 0.001) {
          final overlap = (minDistance - dist) / minDistance;
          final pushX = (dx / dist) * overlap * 120.0 * dt;
          f1.x += pushX;
          f2.x -= pushX;

          // Vertical separation only between free swimmers
          if (!f1.item.isBottomDweller && !f2.item.isBottomDweller) {
            final pushY = (dy / dist) * overlap * 95.0 * dt;
            f1.y += pushY;
            f2.y -= pushY;
            final vDisperse = overlap * 40.0 * dt;
            if (f1.y < f2.y) {
              f1.y -= vDisperse;
              f2.y += vDisperse;
            } else {
              f1.y += vDisperse;
              f2.y -= vDisperse;
            }
            f1.y = f1.y.clamp(148.0, 680.0);
            f2.y = f2.y.clamp(148.0, 680.0);
          }

          // Gentle steering evasion when approaching head-on
          if (dist < 32.0 && _rand.nextDouble() < 0.15) {
            if (dx.abs() > 4.0) {
              f1.facingRight = dx > 0;
              f2.facingRight = dx < 0;
            }
          }
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onDoubleTapDown: (details) {
        if (!widget.interactive) return;
        final worldPos = _toWorldPos(details.localPosition);
        camera.toggleZoom(focalWorldPoint: worldPos);
        widget.onCameraZoomChanged?.call(camera.isZoomed, camera.targetZoom);
        AudioManager.instance.playSfx(GameSfx.click);
      },
      onTapUp: (details) {
        if (!widget.interactive) return;
        if (_hasMovedSignificantly) return;
        if (_isFingerMode) {
          _onFingerUp();
        } else {
          _onTankTap(details.localPosition);
        }
      },
      onScaleStart: (details) {
        if (!widget.interactive) return;
        _startScale = camera.zoom;
        _lastFocalPoint = details.localFocalPoint;
        _hasMovedSignificantly = false;
        if (_isFingerMode && details.pointerCount == 1) {
          _onFingerDown(details.localFocalPoint);
        }
      },
      onScaleUpdate: (details) {
        if (!widget.interactive) return;
        final box = context.findRenderObject() as RenderBox?;
        if (box == null || box.size.isEmpty) return;

        if (details.pointerCount >= 2) {
          // Pinch-to-zoom (two fingers)
          final newTargetZoom = (_startScale * details.scale).clamp(1.0, 2.0);
          camera.targetZoom = newTargetZoom;
          if (newTargetZoom <= 1.05) {
            camera.zoomOut();
          } else {
            camera.setTargetPan(camera.targetPan);
          }
          _hasMovedSignificantly = true;
          widget.onCameraZoomChanged?.call(camera.isZoomed, camera.targetZoom);
        } else if (details.pointerCount == 1) {
          if (_isFingerMode) {
            _onFingerMove(details.localFocalPoint);
          } else if (camera.isZoomed && _lastFocalPoint != null) {
            // Single finger drag to pan around zoomed tank
            final delta = details.localFocalPoint - _lastFocalPoint!;
            if (delta.distanceSquared > 16.0) {
              _hasMovedSignificantly = true;
            }
            final scaleX = 410.0 / box.size.width;
            final scaleY = 800.0 / box.size.height;
            final worldDeltaX = (delta.dx * scaleX) / camera.zoom;
            final worldDeltaY = (delta.dy * scaleY) / camera.zoom;
            camera.setTargetPan(camera.targetPan + Offset(worldDeltaX, worldDeltaY));
          }
        }
        _lastFocalPoint = details.localFocalPoint;
      },
      onScaleEnd: (details) {
        if (!widget.interactive) return;
        if (_isFingerMode) {
          _onFingerUp();
        }
        if (camera.targetZoom < 1.06) {
          camera.zoomOut();
          widget.onCameraZoomChanged?.call(false, 1.0);
        }
        _lastFocalPoint = null;
      },
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

/// Dynamic aquarium camera controller managing smooth lerp zoom,
/// panning limits (preventing off-tank scrolling), and Macro vs Micro modes.
class TankCamera {
  double zoom = 1.0;
  double targetZoom = 1.0;
  Offset pan = Offset.zero;
  Offset targetPan = Offset.zero;

  static const double minZoom = 1.0;
  static const double maxZoom = 2.0;

  bool get isZoomed => targetZoom > 1.05;

  void toggleZoom({Offset? focalWorldPoint}) {
    if (isZoomed) {
      zoomOut();
    } else {
      zoomIn(focalWorldPoint: focalWorldPoint);
    }
  }

  void zoomIn({Offset? focalWorldPoint}) {
    targetZoom = 1.85;
    if (focalWorldPoint != null) {
      setTargetPan(Offset(205.0 - focalWorldPoint.dx, 400.0 - focalWorldPoint.dy));
    } else {
      setTargetPan(targetPan);
    }
  }

  void zoomOut() {
    targetZoom = 1.0;
    targetPan = Offset.zero;
  }

  void setTargetPan(Offset newPan) {
    if (targetZoom <= 1.02) {
      targetPan = Offset.zero;
      return;
    }
    // Allowable pan so camera cannot view beyond aquarium borders
    final maxPanX = 205.0 * (1.0 - 1.0 / targetZoom);
    final maxPanY = 400.0 * (1.0 - 1.0 / targetZoom);
    targetPan = Offset(
      newPan.dx.clamp(-maxPanX, maxPanX),
      newPan.dy.clamp(-maxPanY, maxPanY),
    );
  }

  void update(double dt) {
    final t = min(1.0, dt * 8.5);
    zoom += (targetZoom - zoom) * t;
    pan = Offset(
      pan.dx + (targetPan.dx - pan.dx) * t,
      pan.dy + (targetPan.dy - pan.dy) * t,
    );
    if (targetZoom <= 1.01 && (zoom - 1.0).abs() < 0.004) {
      zoom = 1.0;
      pan = Offset.zero;
    }
  }
}

class _SimFish {
  final FishItem item;
  final double zDepth;
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
  // Octopus only: soft-body arms + jet/crawl state machine.
  final OctopusRig? rig;
  // All other procedural fish & creatures: spine, fins, face & gait rig.
  final FishRig? fishRig;

  /// True while the fish is in its 3-hour post-feeding satiety window
  bool get isSatiated => SaveManager.instance.isFishInSatietyCooldown(item.id);
  bool get isProducing => SaveManager.instance.isFishProducing(item.id);
  bool get isBackground => zDepth < 0.9;

  _SimFish({
    required this.item,
    required this.x,
    required this.y,
    required this.vx,
    required this.vy,
    required this.facingRight,
    required this.tailPhase,
    this.zDepth = 1.0,
  })  : rig = item.kind == FishKind.octopus ? OctopusRig() : null,
        fishRig = item.kind == FishKind.octopus
            ? null
            : FishRig(
                fishId: item.id,
                x: x,
                y: y,
                vx: vx,
                vy: vy,
                facingRight: facingRight,
              );
}

/// A drifting puff of octopus ink (world coordinates).
class _InkCloud {
  double x;
  double y;
  final double radius;
  final double maxLife;
  double life = 0.0;

  _InkCloud({required this.x, required this.y, required this.radius, required this.maxLife});
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
  bool isOnBottom = false;
  double bottomRestTimer = 0.0;

  _FoodPellet({required this.x, required this.y, required this.vy, required this.swayPhase});

  void update(double dt) {
    if (isOnBottom) {
      bottomRestTimer += dt;
      life += dt;
      return;
    }
    y += vy * dt;
    swayPhase += dt * 3.0;
    x += sin(swayPhase) * 12.0 * dt;
    life += dt;
    if (y >= 740.0) {
      y = 740.0;
      isOnBottom = true;
    }
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
  final Paint _bubblePaint = Paint()..color = const Color(0x2881D4FA);
  final Paint _foodPaint = Paint()..color = const Color(0xFFFFD54F);
  final Paint _foodGlow = Paint()..color = const Color(0x44FFD54F);
  final Paint _sparkPaint = Paint();
  final Paint _fingerRipplePaint1 = Paint()
    ..color = const Color(0x6600E5FF)
    ..style = PaintingStyle.stroke
    ..strokeWidth = 2.0;
  final Paint _fingerRipplePaint2 = Paint()
    ..color = const Color(0x334FC3F7)
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1.4;
  final Paint _fingerGlowPaint = Paint()
    ..color = const Color(0x9900E5FF)
    ..style = PaintingStyle.fill;
  final Paint _fingerCorePaint = Paint()
    ..color = Colors.white
    ..style = PaintingStyle.fill;
  final Paint _imgPaint = Paint()..filterQuality = FilterQuality.none;
  final Paint _bodyPaint = Paint()..style = PaintingStyle.fill;
  final Paint _tailPaint = Paint()..style = PaintingStyle.fill;
  final Paint _eyeWhite = Paint()..color = Colors.white;
  final Paint _eyeBlack = Paint()..color = Colors.black;
  final Path _tailPath = Path();

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
      _waterShader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Color(0xFF0F384C), // Petrol turquoise top
          Color(0xFF0B2637), // Vibrant mid ocean blue
          Color(0xFF071824), // Deep aquatic blue
          Color(0xFF030C14), // Abyssal seabed dark
        ],
        stops: [0.0, 0.32, 0.68, 1.0],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));
    }
    _waterPaint.shader = _waterShader;
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), _waterPaint);

    // The simulation runs in a fixed 410x800 world. Scale it onto the
    // real canvas so the sand, plants and bottom dwellers always sit
    // on the drawn floor, whatever the screen size.
    // Apply Camera Matrix Transform (Smooth Zoom & Pan)
    canvas.save();
    canvas.translate(size.width / 2.0, size.height / 2.0);
    canvas.scale(host.camera.zoom, host.camera.zoom);
    canvas.scale(size.width / 410.0, size.height / 800.0);
    canvas.translate(-205.0 + host.camera.pan.dx, -400.0 + host.camera.pan.dy);

    // 1b. Soft underwater surface caustics filtering down from surface
    final causticPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          const Color(0xFF80D8FF).withValues(alpha: 0.06 + 0.02 * sin(time * 0.8)),
          const Color(0x0080D8FF),
        ],
        stops: const [0.0, 0.45],
      ).createShader(const Rect.fromLTWH(0, 0, 410, 360));
    canvas.drawRect(const Rect.fromLTWH(0, 0, 410, 360), causticPaint);

    // 1c. Surface Sunlight Beams (God Rays) piercing down through water
    _drawGodRays(canvas, time);

    // 2. Rising ambient bubbles
    for (final b in bubbles) {
      canvas.drawCircle(Offset(b.x + sin(time + b.radius) * 3, b.y), b.radius, _bubblePaint);
    }

    // 3. Far background procedural plants (Tall Vallisneria ribbon grass)
    for (final p in host._plants) {
      if (!p.isForeground && p.species == PlantSpecies.vallisneria) {
        p.paint(canvas, time);
      }
    }

    // 4. Background swimming fish (Z-depth ~0.74, swimming behind midground plants)
    for (final f in simFish) {
      if (!f.item.isBottomDweller && f.isBackground) {
        _drawFish(canvas, f);
      }
    }

    // 5. Midground procedural plants (Rotala stem clusters)
    for (final p in host._plants) {
      if (!p.isForeground && p.species != PlantSpecies.vallisneria) {
        p.paint(canvas, time);
      }
    }

    // 6. Food Pellets
    for (final p in foodPellets) {
      canvas.drawCircle(Offset(p.x, p.y), 4.0, _foodGlow);
      canvas.drawCircle(Offset(p.x, p.y), 2.5, _foodPaint);
    }

    // 7. Foreground swimming fish (Z-depth 1.0, swimming in front of midground plants)
    for (final f in simFish) {
      if (!f.item.isBottomDweller && !f.isBackground) {
        _drawFish(canvas, f);
      }
    }

    // 8. Foreground procedural plants (Broad Anubias Nana)
    for (final p in host._plants) {
      if (p.isForeground) {
        p.paint(canvas, time);
      }
    }

    // 9. Substrate / Seabed (Deep sediment + warm contoured sand dune + crest highlight + river pebbles)
    _drawSubstrate(canvas);

    // 10. Pellets an octopus has tucked underneath itself
    for (final f in simFish) {
      final gp = f.grabbedPellet;
      if (gp == null) continue;
      canvas.drawCircle(Offset(gp.x, gp.y), 4.0, _foodGlow);
      canvas.drawCircle(Offset(gp.x, gp.y), 2.5, _foodPaint);
    }

    // 11. Bottom dwellers (Crab, snail, octopus) walking ON the seabed
    for (final f in simFish) {
      if (f.item.isBottomDweller) {
        _drawFish(canvas, f);
      }
    }

    // 12. Rising photosynthetic oxygen bubbles (pearling)
    for (final b in host._plantBubbles) {
      PlantOxygenPainter.paintBubble(canvas, b);
    }

    // 13. Eat particles & tap reaction hearts
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

    // 14. Finger Attraction Touch Wave & Ripple
    if (host.fingerWorldPos != null) {
      final fp = host.fingerWorldPos!;
      final r1 = 14.0 + sin(time * 8.0) * 4.0;
      final r2 = 26.0 + sin(time * 8.0 + 1.2) * 6.0;
      canvas.drawCircle(fp, r1, _fingerRipplePaint1);
      canvas.drawCircle(fp, r2, _fingerRipplePaint2);
      canvas.drawCircle(fp, 5.0, _fingerGlowPaint);
      canvas.drawCircle(fp, 2.2, _fingerCorePaint);
    }

    // 15. Octopus ink drifts
    for (final ink in host._inkClouds) {
      final t = (ink.life / ink.maxLife).clamp(0.0, 1.0);
      _sparkPaint.color = const Color(0xFF2A0A3D).withValues(alpha: 0.55 * (1.0 - t));
      canvas.drawCircle(Offset(ink.x, ink.y), ink.radius * (1.0 + t * 1.8), _sparkPaint);
    }

    canvas.restore();
  }

  void _drawGodRays(Canvas canvas, double time) {
    final rayPaint = Paint()
      ..blendMode = BlendMode.screen
      ..style = PaintingStyle.fill;

    // 4 diagonal light shafts from surface penetrating down into the tank
    const rays = [
      (x1: 20.0, w1: 36.0, x2: 95.0, w2: 110.0, len: 650.0, phase: 0.0, speed: 0.65),
      (x1: 110.0, w1: 44.0, x2: 215.0, w2: 135.0, len: 730.0, phase: 1.4, speed: 0.80),
      (x1: 215.0, w1: 38.0, x2: 305.0, w2: 125.0, len: 700.0, phase: 2.7, speed: 0.72),
      (x1: 320.0, w1: 34.0, x2: 395.0, w2: 100.0, len: 620.0, phase: 3.9, speed: 0.85),
    ];

    for (final r in rays) {
      final sway = sin(time * r.speed + r.phase) * 8.0;
      final alphaPulse = (0.045 + 0.02 * sin(time * (r.speed * 0.7) + r.phase)).clamp(0.02, 0.08);

      final path = Path()
        ..moveTo(r.x1 + sway * 0.3, 0)
        ..lineTo(r.x1 + r.w1 + sway * 0.3, 0)
        ..lineTo(r.x2 + r.w2 + sway, r.len)
        ..lineTo(r.x2 + sway, r.len)
        ..close();

      rayPaint.shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          const Color(0xFFC8F0FF).withValues(alpha: alphaPulse),
          const Color(0xFF80D8FF).withValues(alpha: alphaPulse * 0.55),
          const Color(0x0080D8FF),
        ],
        stops: const [0.0, 0.45, 1.0],
      ).createShader(Rect.fromLTWH(0, 0, 410, r.len));

      canvas.drawPath(path, rayPaint);
    }
  }

  void _drawSubstrate(Canvas canvas) {
    // 1. Deep sediment layer at the very bottom
    final deepBedPath = Path()
      ..moveTo(0, 744)
      ..cubicTo(110, 734, 230, 746, 410, 738)
      ..lineTo(410, 800)
      ..lineTo(0, 800)
      ..close();
    final deepBedPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xFF5E4327), Color(0xFF2C1E10), Color(0xFF140D07)],
        stops: [0.0, 0.5, 1.0],
      ).createShader(const Rect.fromLTWH(0, 734, 410, 66));
    canvas.drawPath(deepBedPath, deepBedPaint);

    // 2. Main warm sand dune layer with natural contours
    final dunePath = Path()
      ..moveTo(0, 748)
      ..cubicTo(90, 738, 170, 732, 250, 740)
      ..cubicTo(320, 747, 370, 736, 410, 742)
      ..lineTo(410, 800)
      ..lineTo(0, 800)
      ..close();
    final dunePaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xFFB38F5C), Color(0xFF7A5833), Color(0xFF3B2816)],
        stops: [0.0, 0.4, 1.0],
      ).createShader(const Rect.fromLTWH(0, 732, 410, 68));
    canvas.drawPath(dunePath, dunePaint);

    // 3. Sand crest highlight catching light
    final crestPath = Path()
      ..moveTo(0, 748)
      ..cubicTo(90, 738, 170, 732, 250, 740)
      ..cubicTo(320, 747, 370, 736, 410, 742);
    final crestPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0
      ..shader = const LinearGradient(
        colors: [Color(0x55FFE082), Color(0x88FFD54F), Color(0x55FFE082)],
      ).createShader(const Rect.fromLTWH(0, 732, 410, 16));
    canvas.drawPath(crestPath, crestPaint);

    // 4. Smooth river pebbles resting on the seabed
    _drawSeabedPebbles(canvas);
  }

  void _drawSeabedPebbles(Canvas canvas) {
    final stonePaint = Paint()..style = PaintingStyle.fill;
    final highlightPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0
      ..color = const Color(0x44FFFFFF);

    const pebbles = [
      (x: 48.0, y: 764.0, rx: 7.0, ry: 4.0, rot: -0.15, color: Color(0xFF4A5559)),
      (x: 88.0, y: 756.0, rx: 5.5, ry: 3.2, rot: 0.22, color: Color(0xFF384245)),
      (x: 138.0, y: 768.0, rx: 8.5, ry: 4.8, rot: 0.1, color: Color(0xFF5C5247)),
      (x: 215.0, y: 759.0, rx: 6.0, ry: 3.5, rot: -0.2, color: Color(0xFF454E52)),
      (x: 280.0, y: 766.0, rx: 7.5, ry: 4.2, rot: 0.18, color: Color(0xFF52483D)),
      (x: 345.0, y: 758.0, rx: 5.0, ry: 3.0, rot: -0.12, color: Color(0xFF3B464A)),
      (x: 388.0, y: 766.0, rx: 6.8, ry: 3.8, rot: 0.25, color: Color(0xFF4C5558)),
    ];

    for (final p in pebbles) {
      canvas.save();
      canvas.translate(p.x, p.y);
      canvas.rotate(p.rot);
      stonePaint.color = p.color;
      canvas.drawOval(Rect.fromCenter(center: Offset.zero, width: p.rx * 2, height: p.ry * 2), stonePaint);
      canvas.drawArc(
        Rect.fromCenter(center: const Offset(0, -0.5), width: p.rx * 1.8, height: p.ry * 1.6),
        pi * 1.1,
        pi * 0.8,
        false,
        highlightPaint,
      );
      canvas.restore();
    }
  }

  void _drawFish(Canvas canvas, _SimFish f) {
    canvas.save();
    canvas.translate(f.x, f.y);

    final isBg = f.isBackground && !f.item.isBottomDweller;
    if (isBg) {
      canvas.scale(f.zDepth, f.zDepth);
    }

    final rollAngle = f.flipTimer > 0 ? (f.flipProgress * pi * 2.0) : 0.0;
    if (!f.facingRight) {
      canvas.scale(-1, 1);
    }
    canvas.rotate(f.pitchAngle + rollAngle);

    // Creature motion language & natural swimming dynamics
    switch (f.item.kind) {
      case FishKind.snail:
        canvas.rotate(sin(time * 2.0 + f.tailPhase) * 0.03);
        break;
      case FishKind.crab:
        if (f.isMoving) {
          canvas.translate(0, -sin(time * 16.0 + f.tailPhase).abs() * 2.2);
        }
        canvas.rotate(sin(time * 8.0 + f.tailPhase) * 0.045);
        break;
      case FishKind.shrimp:
        canvas.rotate(sin(time * 6.0 + f.tailPhase) * 0.07);
        break;
      case FishKind.octopus:
        if (f.grabbedPellet != null) {
          final bite = sin(time * 10.0 + f.tailPhase);
          canvas.scale(1.07, 0.90 + bite * 0.02);
          canvas.translate(0, 3.0 + bite * 0.4);
        } else if (f.isMoving) {
          final stride = sin(f.stepPhase * 2.0);
          canvas.translate(0, -stride.abs() * 2.6);
          canvas.rotate(stride * 0.05);
          final pulse = 1.0 + sin(time * 2.4 + f.tailPhase) * 0.04;
          canvas.scale(pulse, 2.0 - pulse);
        } else {
          final pulse = 1.0 + sin(time * 2.4 + f.tailPhase) * 0.05;
          canvas.scale(pulse, 2.0 - pulse);
          canvas.translate(0, sin(time * 1.8 + f.tailPhase) * 1.6);
        }
        break;
      case FishKind.jellyfish:
        final bell = sin(time * 2.2 + f.tailPhase);
        canvas.scale(1.0 - bell * 0.06, 1.0 + bell * 0.09);
        canvas.rotate(sin(time * 1.4 + f.tailPhase) * 0.06);
        break;
      case FishKind.fish:
        final wag = sin(time * 4.5 + f.tailPhase) * 0.05;
        canvas.rotate(wag);
        final breath = 1.0 + sin(time * 3.0 + f.tailPhase) * 0.02;
        canvas.scale(breath, 2.0 - breath);
        break;
    }

    final alpha = isBg ? 0.68 : 1.0;
    _imgPaint.color = Colors.white.withValues(alpha: alpha);

    final img = AssetCache.instance.getFishImage(f.item.id);
    if (img != null) {
      final fishScale = f.item.size * 0.14;
      canvas.scale(fishScale, fishScale);

      final src = Rect.fromLTWH(0, 0, img.width.toDouble(), img.height.toDouble());
      final dst = Rect.fromCenter(
        center: Offset.zero,
        width: img.width.toDouble(),
        height: img.height.toDouble(),
      );
      canvas.drawImageRect(img, src, dst, _imgPaint);
      canvas.scale(1.0 / fishScale, 1.0 / fishScale);
    } else {
      final fishScale = f.item.size * 0.7;
      canvas.scale(fishScale, fishScale);
      final bodyRect = Rect.fromCenter(center: Offset.zero, width: 26, height: 13);
      _bodyPaint.color = f.item.color.withValues(alpha: alpha);
      canvas.drawOval(bodyRect, _bodyPaint);

      final tailWag = sin(time * 5 + f.tailPhase) * 4.0;
      _tailPath
        ..reset()
        ..moveTo(-11, 0)
        ..lineTo(-22, -7 + tailWag)
        ..lineTo(-18, 0)
        ..lineTo(-22, 7 + tailWag)
        ..close();
      _tailPaint.color = f.item.secondaryColor.withValues(alpha: alpha);
      canvas.drawPath(_tailPath, _tailPaint);

      canvas.drawCircle(const Offset(7, -2), 2.0, _eyeWhite);
      canvas.drawCircle(const Offset(8, -2), 0.9, _eyeBlack);
      canvas.scale(1.0 / fishScale, 1.0 / fishScale);
    }

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _TankPainter oldDelegate) => false;
}
