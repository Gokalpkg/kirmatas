import 'dart:math';

/// What the bee is currently doing. Different balls end its flight in
/// different ways: fire burns it to ash, frost freezes it solid, and an
/// active Vortex power-up drags it onto the paddle, where it is crushed
/// flat and dies. Nothing else ever pulls the bee toward the paddle.
enum BeeState { flying, burning, frozenFalling, stuckToPaddle }

class EasterEggBee {
  double x;
  double y;
  double baseY;
  final double vx;
  final bool isFacingRight;
  double flightTime = 0.0;
  bool isAlive = true;
  final double hitRadius;

  BeeState state = BeeState.flying;
  double stateTime = 0.0;

  /// Vertical velocity while falling (burning / frozen states).
  double vy = 0.0;

  /// Tumble angle while falling frozen.
  double fallSpin = 0.0;

  /// Where along the paddle the bee is pinned (offset from paddle.x).
  double stuckOffsetX = 0.0;

  EasterEggBee({
    required this.x,
    required this.baseY,
    required this.vx,
    required this.isFacingRight,
    this.hitRadius = 10.0,
  }) : y = baseY;

  void update(double dt) {
    flightTime += dt;
    x += vx * dt;
    // Realistic bee flight physics:
    // Gentle primary sinusoidal vertical bobbing + subtle secondary harmonic
    final verticalOscillation = sin(flightTime * 3.6) * 11.0 + sin(flightTime * 7.5) * 3.2;
    y = baseY + verticalOscillation;
  }

  // Tilt/pitch angle in radians based on vertical velocity
  double get tiltAngle {
    final verticalVelocity = cos(flightTime * 3.6) * 39.6 + cos(flightTime * 7.5) * 24.0;
    final tilt = (verticalVelocity / 350.0).clamp(-0.16, 0.16);
    return isFacingRight ? tilt : -tilt;
  }

  // Rapid wing flutter vibration (-1.0 to 1.0)
  double get wingFlap => sin(flightTime * 52.0);

  bool isOffScreen(double screenWidth) {
    if (vx > 0 && x > screenWidth + 50.0) return true;
    if (vx < 0 && x < -50.0) return true;
    return false;
  }
}

class WindshieldSplat {
  final double x;
  final double y;
  double timer;
  final double duration;

  WindshieldSplat({
    required this.x,
    required this.y,
    this.duration = 2.0,
  }) : timer = duration;

  bool get isDead => timer <= 0;

  void update(double dt) {
    timer -= dt;
    if (timer < 0) timer = 0.0;
  }

  // Alpha factor: stays completely visible for ~1.6s, then fades out smoothly over final 0.4s
  double get alpha {
    if (timer > 0.4) return 1.0;
    return (timer / 0.4).clamp(0.0, 1.0);
  }
}
