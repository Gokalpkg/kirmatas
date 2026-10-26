import 'dart:math';
import 'dart:ui';

/// What the octopus is doing right now.
enum OctState {
  /// Settled on the sand (or hovering): breathing, arms exploring.
  rest,

  /// Arm-over-arm crawl along the floor.
  crawl,

  /// Mantle contraction pulse: a fast burst, arms trailing behind.
  jet,

  /// Coasting after a pulse, arms opening, slowly sinking.
  glide,

  /// Hovering near the player's finger, front arms stretched toward it.
  reach,

  /// Wrapping a food pellet under the body.
  grab,
}

/// Locomotion + soft-body arm simulation of the aquarium octopus.
///
/// The rig owns the world position while it runs: the host copies
/// `x`/`y` in before [step] and reads them back afterwards (so tank-wide
/// separation steering still applies). Everything is expressed in the
/// aquarium's 410x800 world; arms live in the body's local frame
/// (origin = body centre, facing +x, +y = down).
class OctopusRig {
  static const int armCount = 8;
  static const int joints = 9;

  /// Local y of the sand surface under the body (before drawing scale).
  static const double localFloor = 15.5;
  static const double minX = 35.0;
  static const double maxX = 375.0;
  static const double minY = 120.0;

  final Random rand;

  OctState state = OctState.rest;
  double stateTime = 0.0;

  // World kinematics
  double x = 0.0;
  double y = 0.0;
  double vx = 0.0;
  double vy = 0.0;
  bool facingRight = true;
  double pitch = 0.0;

  // Gait / pulse bookkeeping
  double stepPhase = 0.0;
  double mantle = 0.0; // 0 relaxed .. 1 fully contracted
  double ground = 1.0; // 1 on the sand, 0 floating free
  int pulsesLeft = 0;
  double _jetGoalX = 0.0;
  double _jetGoalY = 0.0;
  double jetCooldown = 0.0;
  double _idleTimer = 1.0;
  double _idleJetTimer = 8.0;
  bool _idleMoving = false;

  // Face
  double lookX = 0.0;
  double lookY = 0.0;
  double blinkTimer = 3.0;
  double blink = 0.0;

  // Reach target in the body's local frame
  double reachLX = 0.0;
  double reachLY = 0.0;

  /// Arm joint positions in the body's local frame.
  final List<List<Offset>> arms = List.generate(
    armCount,
    (_) => List<Offset>.filled(joints, Offset.zero),
  );
  bool _armsReady = false;

  OctopusRig([Random? random]) : rand = random ?? Random() {
    _idleJetTimer = 7.0 + rand.nextDouble() * 9.0;
  }

  bool get isAirborne => state == OctState.jet || state == OctState.glide;

  double get speed => sqrt(vx * vx + vy * vy);

  void _enter(OctState s) {
    if (state == s) return;
    state = s;
    stateTime = 0.0;
  }

  /// Starts a jet series toward the given world point.
  void startJet(double goalX, double goalY, {int? pulses}) {
    _jetGoalX = goalX.clamp(minX, maxX);
    _jetGoalY = goalY.clamp(minY, 9999.0);
    final dist = sqrt(pow(_jetGoalX - x, 2) + pow(_jetGoalY - y, 2));
    pulsesLeft = pulses ?? (dist / 95.0).ceil().clamp(1, 4);
    _firePulse();
  }

  void _firePulse() {
    final dx = _jetGoalX - x;
    final dy = _jetGoalY - y;
    final d = max(1.0, sqrt(dx * dx + dy * dy));
    const v0 = 175.0;
    vx = dx / d * v0;
    vy = dy / d * v0;
    if (dx.abs() > 6.0) facingRight = dx > 0;
    pulsesLeft--;
    _enter(OctState.jet);
    stateTime = 0.0;
  }

  /// Advances the octopus by [dt] seconds.
  void step(
    double dt,
    double time, {
    required double floorY,
    Offset? finger,
    Offset? food,
    bool hungry = true,
    bool grabbing = false,
  }) {
    stateTime += dt;
    jetCooldown -= dt;
    ground = (1.0 - (floorY - y) / 14.0).clamp(0.0, 1.0);

    // Mantle contraction follows the pulse.
    final mTarget = state == OctState.jet ? 1.0 : 0.0;
    mantle += (mTarget - mantle) * min(1.0, dt * (mTarget > mantle ? 16.0 : 4.5));

    _updateFace(dt, time, finger, food);

    if (grabbing) {
      _enter(OctState.grab);
      vx = 0.0;
      vy = 0.0;
      pitch += (0.0 - pitch) * min(1.0, dt * 8.0);
      _updateArms(dt, time);
      return;
    }
    if (state == OctState.grab) {
      _enter(y < floorY - 2.0 ? OctState.glide : OctState.rest);
      pulsesLeft = 0;
    }

    switch (state) {
      case OctState.jet:
        x += vx * dt;
        y += vy * dt;
        vx *= exp(-dt * 1.0);
        vy *= exp(-dt * 1.0);
        if (stateTime >= 0.28) _enter(OctState.glide);
        break;
      case OctState.glide:
        x += vx * dt;
        y += vy * dt;
        final drag = exp(-dt * 2.6);
        vx *= drag;
        vy *= drag;
        if (pulsesLeft <= 0) {
          // Final coast: slowly sink back to the sand.
          vy = min(48.0, vy + 70.0 * dt);
        } else if (stateTime >= 0.62) {
          _firePulse();
        }
        if (y >= floorY) {
          y = floorY;
          vx = 0.0;
          vy = 0.0;
          pulsesLeft = 0;
          jetCooldown = 1.2;
          _enter(OctState.rest);
        }
        break;
      case OctState.rest:
      case OctState.crawl:
      case OctState.reach:
      case OctState.grab:
        _groundBehaviour(dt, floorY, finger, food, hungry);
        break;
    }

    // World limits.
    if (x < minX) {
      x = minX;
      if (vx < 0) vx = 0;
    } else if (x > maxX) {
      x = maxX;
      if (vx > 0) vx = 0;
    }
    if (y < minY) {
      y = minY;
      if (vy < 0) vy = 0;
    }
    if (y > floorY) y = floorY;

    // Body axis follows the travel direction while jetting (mantle first).
    var pitchTarget = 0.0;
    if (isAirborne && speed > 28.0) {
      pitchTarget = atan2(vx.abs(), -vy).clamp(0.0, 2.0);
    }
    pitch += (pitchTarget - pitch) * min(1.0, dt * 9.0);

    _updateArms(dt, time);
  }

  void _groundBehaviour(
    double dt,
    double floorY,
    Offset? finger,
    Offset? food,
    bool hungry,
  ) {
    // Settle onto the floor when hovering.
    if (y < floorY - 0.5) {
      if (state == OctState.reach && finger != null) {
        // keep hovering by the finger
      } else {
        vy = min(48.0, vy + 70.0 * dt);
        y += vy * dt;
        if (y >= floorY) {
          y = floorY;
          vy = 0.0;
        }
      }
    }

    final Offset? target = finger ?? (hungry ? food : null);

    if (target != null) {
      final dx = target.dx - x;
      final dy = target.dy - y;
      final dist = sqrt(dx * dx + dy * dy);
      if (dx.abs() > 4.0) facingRight = dx >= 0;

      if (finger != null && dist < 72.0) {
        _enter(OctState.reach);
        reachLX = facingRight ? dx : -dx;
        reachLY = dy;
        return;
      }
      final waterTarget = target.dy < floorY - 70.0;
      if (waterTarget && jetCooldown <= 0.0 && dist > 55.0) {
        startJet(target.dx, target.dy);
        jetCooldown = 0.9;
        return;
      }
      final adx = target.dx - x;
      if (adx.abs() > 14.0 && y >= floorY - 1.0) {
        _crawl(dt, adx > 0 ? 1.0 : -1.0, finger != null ? 38.0 : 34.0);
        return;
      }
      _enter(OctState.rest);
      return;
    }

    if (state == OctState.reach) _enter(OctState.rest);

    // Idle life: crawl bursts, pauses and the odd jet across the tank.
    _idleTimer -= dt;
    if (_idleTimer <= 0.0) {
      _idleMoving = !_idleMoving;
      _idleTimer = _idleMoving
          ? 0.9 + rand.nextDouble() * 1.1
          : 0.8 + rand.nextDouble() * 1.8;
      if (!_idleMoving && rand.nextDouble() < 0.35) facingRight = !facingRight;
    }
    _idleJetTimer -= dt;
    if (_idleJetTimer <= 0.0 && y >= floorY - 1.0) {
      _idleJetTimer = 9.0 + rand.nextDouble() * 10.0;
      if (rand.nextDouble() < 0.6) {
        final dir = rand.nextBool() ? 1.0 : -1.0;
        final gx = (x + dir * (60.0 + rand.nextDouble() * 90.0)).clamp(minX + 10, maxX - 10);
        final gy = floorY - (130.0 + rand.nextDouble() * 170.0);
        startJet(gx, gy);
        return;
      }
    }
    if (_idleMoving && y >= floorY - 1.0) {
      _crawl(dt, facingRight ? 1.0 : -1.0, 26.0);
    } else {
      _enter(OctState.rest);
    }
  }

  void _crawl(double dt, double dir, double spd) {
    _enter(OctState.crawl);
    facingRight = dir > 0;
    stepPhase += dt * 3.0 * (spd / 30.0);
    final surge = 0.85 + 0.15 * cos(stepPhase * 2.0);
    x += dir * spd * surge * dt;
    if (x < minX) {
      x = minX;
      facingRight = true;
    } else if (x > maxX) {
      x = maxX;
      facingRight = false;
    }
  }

  void _updateFace(double dt, double time, Offset? finger, Offset? food) {
    double tx;
    double ty;
    final t = finger ?? food;
    if (t != null) {
      final dx = t.dx - x;
      final dy = t.dy - y;
      final d = max(1.0, sqrt(dx * dx + dy * dy));
      tx = (facingRight ? dx : -dx) / d;
      ty = dy / d;
    } else {
      tx = sin(time * 0.7) * 0.6;
      ty = sin(time * 0.43 + 1.0) * 0.4;
    }
    lookX += (tx - lookX) * min(1.0, dt * 6.0);
    lookY += (ty - lookY) * min(1.0, dt * 6.0);

    blinkTimer -= dt;
    if (blinkTimer <= 0.0) {
      blink = 0.16;
      blinkTimer = 2.0 + rand.nextDouble() * 4.5;
    }
    if (blink > 0.0) blink = max(0.0, blink - dt);
  }

  // --- Arms ---------------------------------------------------------------

  double armRootX(int i) => -12.0 + i * (24.0 / (armCount - 1));
  double armRootY(int i) {
    final u = (i - 3.5) / 3.5;
    return 8.0 + (1.0 - u * u) * 1.5;
  }

  Offset _restPose(int i, int k, double time) {
    final s = k / (joints - 1);
    final u = (i - 3.5) / 3.5;
    final rx = armRootX(i);
    final ry = armRootY(i);

    // On the sand: arms fan out flat, tips curling up a little.
    final curl = 3.0 + 4.0 * sin(i * 2.3);
    final wave = sin(time * 1.7 + i * 0.8 - s * 3.0) * 2.4 * s;
    final fx = rx + u * (5.0 + s * 21.0) + wave;
    var fy = ry + (localFloor - ry) * min(1.0, s * 2.2);
    fy -= s * s * s * curl * (0.6 + 0.4 * sin(time * 0.9 + i));
    fy = min(fy, localFloor);

    // Floating: arms hang down and sway.
    final hx = rx * (1.0 - s * 0.3) + u * s * s * 6.0 + sin(time * 2.4 + i * 0.9 - s * 3.5) * 3.0 * s;
    final hy = ry + s * 27.0;

    final g = ground;
    return Offset(hx + (fx - hx) * g, hy + (fy - hy) * g);
  }

  Offset _crawlPose(int i, int k, double time) {
    final s = k / (joints - 1);
    final u = (i - 3.5) / 3.5;
    final rx = armRootX(i);
    final ry = armRootY(i);
    const amp = 13.0;
    final phi = stepPhase + i * (pi / 4.0);
    final sinP = sin(phi);
    final lift = max(0.0, -(sinP + 0.2)) * (12.0 / 0.8);

    final tipX = rx + u * 14.0 + 4.0 + cos(phi) * amp;
    final tipY = localFloor - lift;
    final px = rx + (tipX - rx) * s;
    var py = ry + (tipY - ry) * s;
    py -= sin(s * pi) * (2.5 + lift * 0.55);
    return Offset(px, min(py, localFloor));
  }

  Offset _jetPose(int i, int k, double time) {
    final s = k / (joints - 1);
    final rx = armRootX(i);
    final ry = armRootY(i);
    final px = rx * (0.45 - 0.3 * s) + sin(time * 18.0 - s * 4.0 + i) * 0.9 * s;
    final py = ry + s * 36.0;
    return Offset(px, py);
  }

  Offset _glidePose(int i, int k, double time) {
    final s = k / (joints - 1);
    final u = (i - 3.5) / 3.5;
    final rx = armRootX(i);
    final ry = armRootY(i);
    final px = rx + u * s * s * 14.0 + sin(time * 3.0 - s * 3.0 + i) * 2.2 * s;
    final py = ry + s * 31.0 - sin(s * pi) * 2.0;
    return Offset(px, py);
  }

  Offset _grabPose(int i, int k, double time) {
    final s = k / (joints - 1);
    final rx = armRootX(i);
    final ry = armRootY(i);
    final px = rx * (1.0 - s * 0.85) + sin(time * 10.0 + i) * 0.8 * s;
    var py = ry + (localFloor + 1.0 - ry) * pow(s, 0.7);
    py -= sin(s * pi) * 3.0;
    return Offset(px, py);
  }

  Offset _reachPose(int i, int k, double time) {
    if (i < 4) return _restPose(i, k, time);
    final s = k / (joints - 1);
    final rx = armRootX(i);
    final ry = armRootY(i);
    var tx = reachLX;
    var ty = reachLY - 6.0;
    final dx = tx - rx;
    final dy = ty - ry;
    final d = sqrt(dx * dx + dy * dy);
    const maxLen = 40.0;
    if (d > maxLen) {
      tx = rx + dx / d * maxLen;
      ty = ry + dy / d * maxLen;
    }
    final fan = (i - 5.5) * 2.6;
    final wave = sin(time * 6.0 + i - s * 4.0) * 2.5 * sin(s * pi);
    return Offset(
      rx + (tx - rx) * s + wave * 0.4,
      ry + (ty - ry) * s + fan * s + wave,
    );
  }

  Offset _pose(int i, int k, double time) {
    switch (state) {
      case OctState.rest:
        return _restPose(i, k, time);
      case OctState.crawl:
        return _crawlPose(i, k, time);
      case OctState.jet:
        return _jetPose(i, k, time);
      case OctState.glide:
        return _glidePose(i, k, time);
      case OctState.reach:
        return _reachPose(i, k, time);
      case OctState.grab:
        return _grabPose(i, k, time);
    }
  }

  void _updateArms(double dt, double time) {
    final snap = !_armsReady;
    final follow = state == OctState.crawl ? 2.2 : 1.0;
    for (int i = 0; i < armCount; i++) {
      final chain = arms[i];
      for (int k = 0; k < joints; k++) {
        final target = _pose(i, k, time);
        if (snap || k == 0) {
          chain[k] = target;
        } else {
          final a = 1.0 - exp(-dt * (26.0 - 2.0 * k) * follow);
          chain[k] = Offset(
            chain[k].dx + (target.dx - chain[k].dx) * a,
            chain[k].dy + (target.dy - chain[k].dy) * a,
          );
        }
      }
    }
    _armsReady = true;
  }
}

/// Draws an [OctopusRig] procedurally: egg mantle, slit-pupil eyes, siphon
/// and eight tapering suckered arms.
class OctopusPainter {
  OctopusPainter._();

  static final Paint _fill = Paint()..style = PaintingStyle.fill;
  static final Paint _mantlePaint = Paint();
  static Shader? _mantleShader;
  static int _shaderKey = 0;

  static const List<Offset> _stars = [
    Offset(-9, -20),
    Offset(-2, -26),
    Offset(8, -22),
    Offset(13, -12),
    Offset(-13, -9),
    Offset(2, -14),
    Offset(-6, -5),
  ];

  static final Path _mantlePath = Path()
    ..moveTo(-14, 8)
    ..cubicTo(-21, -2, -16, -31, 3, -31)
    ..cubicTo(22, -31, 23, -2, 14, 8)
    ..cubicTo(8, 12, -8, 12, -14, 8)
    ..close();

  static Color _mix(Color a, Color b, double t) => Color.lerp(a, b, t)!;

  static void paint(
    Canvas c,
    OctopusRig r,
    double time,
    Color base,
  ) {
    final light = _mix(base, const Color(0xFFFFFFFF), 0.35);
    final deep = _mix(base, const Color(0xFF1A0033), 0.45);
    final key = base.toARGB32();
    if (_mantleShader == null || _shaderKey != key) {
      _shaderKey = key;
      _mantleShader = Gradient.radial(
        const Offset(-5, -18),
        34,
        [light, base, deep],
        const [0.0, 0.55, 1.0],
      );
      _mantlePaint.shader = _mantleShader;
    }

    final backArm = _mix(deep, const Color(0xFF000000), 0.2);
    final frontArm = _mix(base, deep, 0.25);

    // 1. Far arms
    for (int i = 0; i < OctopusRig.armCount; i += 2) {
      _drawArm(c, r.arms[i], backArm, false);
    }

    // 2. Web skirt between the arm roots
    final web = Path()..moveTo(r.arms[0][0].dx, r.arms[0][0].dy);
    for (int i = 1; i < OctopusRig.armCount; i++) {
      web.lineTo(r.arms[i][0].dx, r.arms[i][0].dy);
    }
    for (int i = OctopusRig.armCount - 1; i >= 0; i--) {
      web.lineTo(r.arms[i][2].dx, r.arms[i][2].dy);
    }
    web.close();
    _fill.color = _mix(deep, base, 0.4);
    c.drawPath(web, _fill);

    // 3. Mantle (squash & stretch anchored at the bottom)
    final breath = sin(time * 2.2) * 0.035;
    var sx = 1.0 + breath;
    var sy = 1.0 - breath;
    if (r.state == OctState.crawl) {
      final bob = sin(r.stepPhase * 2.0);
      sy += bob * 0.02;
      sx -= bob * 0.02;
    }
    sx -= 0.16 * r.mantle;
    sy += 0.10 * r.mantle;
    if (r.state == OctState.grab) {
      sx = 1.1;
      sy = 0.88 + sin(time * 10.0) * 0.02;
    }
    c.save();
    c.translate(0, 8);
    c.scale(sx, sy);
    c.translate(0, -8);
    c.drawPath(_mantlePath, _mantlePaint);

    // flush of colour while contracting
    if (r.mantle > 0.05) {
      _fill.color = const Color(0xFFF48FB1).withValues(alpha: 0.28 * r.mantle);
      c.drawPath(_mantlePath, _fill);
    }

    // mottles & cosmic stars
    for (int i = 0; i < _stars.length; i++) {
      final p = _stars[i];
      if (i.isEven) {
        _fill.color = deep.withValues(alpha: 0.22);
        c.drawCircle(p + const Offset(1.5, 1.0), 2.4, _fill);
      }
      final tw = 0.35 + 0.3 * sin(time * 2.0 + i * 1.7);
      _fill.color = const Color(0xFFFFFFFF).withValues(alpha: tw);
      c.drawCircle(p, 0.8 + (i % 3) * 0.3, _fill);
    }

    // glossy highlight
    c.save();
    c.translate(-6, -23);
    c.rotate(-0.55);
    _fill.color = const Color(0xFFFFFFFF).withValues(alpha: 0.32);
    c.drawOval(const Rect.fromLTWH(-5, -2.2, 10, 4.4), _fill);
    c.restore();
    c.restore();

    // 4. Siphon (glows during a pulse)
    c.save();
    c.translate(-13, 3);
    c.rotate(-0.7);
    _fill.color = _mix(base, deep, 0.5);
    c.drawRRect(
      RRect.fromRectAndRadius(const Rect.fromLTWH(-6, -1.8, 8, 3.6), const Radius.circular(1.8)),
      _fill,
    );
    if (r.mantle > 0.1) {
      _fill.color = const Color(0xFF80DEEA).withValues(alpha: 0.55 * r.mantle);
      c.drawCircle(const Offset(-6.5, 0), 2.6, _fill);
    }
    c.restore();

    // 5. Eyes: horizontal slit pupils that follow the target
    _drawEye(c, r, const Offset(3.5, -3.5), 1.0, base, deep);
    _drawEye(c, r, const Offset(13.0, -2.5), 0.88, base, deep);

    // 6. Near arms
    for (int i = 1; i < OctopusRig.armCount; i += 2) {
      _drawArm(c, r.arms[i], frontArm, true);
    }
  }

  static void _drawEye(Canvas c, OctopusRig r, Offset p, double sc, Color base, Color deep) {
    c.save();
    c.translate(p.dx, p.dy);
    c.scale(sc, sc);
    _fill.color = const Color(0xFFFFF8E1);
    c.drawOval(const Rect.fromLTWH(-3.8, -3.0, 7.6, 6.0), _fill);
    final px = r.lookX * 1.5;
    final py = r.lookY * 0.9;
    _fill.color = const Color(0xFF1A0A2B);
    c.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(px - 2.4, py - 0.9, 4.8, 1.8),
        const Radius.circular(0.9),
      ),
      _fill,
    );
    // eyelid
    final lid = r.blink > 0 ? 1.0 : 0.28;
    _fill.color = _mix(base, deep, 0.2);
    c.save();
    c.clipRect(const Rect.fromLTWH(-4.5, -3.6, 9.0, 7.2));
    c.drawOval(Rect.fromLTWH(-4.4, -3.9 - (1 - lid) * 3.0, 8.8, 6.9 * lid + 1.0), _fill);
    c.restore();
    c.restore();
  }

  static void _drawArm(Canvas c, List<Offset> j, Color color, bool front) {
    final n = j.length;
    final left = <Offset>[];
    final right = <Offset>[];
    for (int k = 0; k < n; k++) {
      final a = j[max(k - 1, 0)];
      final b = j[min(k + 1, n - 1)];
      var tx = b.dx - a.dx;
      var ty = b.dy - a.dy;
      final len = max(0.0001, sqrt(tx * tx + ty * ty));
      tx /= len;
      ty /= len;
      final s = k / (n - 1);
      final w = 3.1 * pow(1.0 - s, 0.9) + 0.45;
      left.add(Offset(j[k].dx - ty * w, j[k].dy + tx * w));
      right.add(Offset(j[k].dx + ty * w, j[k].dy - tx * w));
    }
    final path = Path()..moveTo(left[0].dx, left[0].dy);
    for (int k = 1; k < n; k++) {
      path.lineTo(left[k].dx, left[k].dy);
    }
    for (int k = n - 1; k >= 0; k--) {
      path.lineTo(right[k].dx, right[k].dy);
    }
    path.close();
    _fill.color = color;
    c.drawPath(path, _fill);
    c.drawCircle(j[n - 1], 0.6, _fill);

    if (!front) return;

    // soft ridge highlight + suckers on the underside
    final ridge = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.9
      ..strokeCap = StrokeCap.round
      ..color = const Color(0xFFE1BEE7).withValues(alpha: 0.28);
    final rp = Path()..moveTo(j[1].dx, j[1].dy);
    for (int k = 2; k < n - 1; k++) {
      rp.lineTo(j[k].dx, j[k].dy);
    }
    c.drawPath(rp, ridge);

    for (int k = 2; k < n - 1; k++) {
      final s = k / (n - 1);
      final l = left[k];
      final rr = right[k];
      final under = l.dy > rr.dy ? l : rr;
      final p = Offset((under.dx * 0.6 + j[k].dx * 0.4), (under.dy * 0.6 + j[k].dy * 0.4));
      _fill.color = const Color(0xFFEDE7F6).withValues(alpha: 0.85);
      c.drawCircle(p, 1.0 * (1.0 - s) + 0.35, _fill);
    }
  }
}
