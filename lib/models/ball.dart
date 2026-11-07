import 'dart:collection';
import 'dart:math';
import 'package:flutter/material.dart';

class TrailPoint {
  final Offset position;
  final double time;
  const TrailPoint(this.position, this.time);
}

/// Fixed-capacity O(1) circular ring buffer implementing [List<TrailPoint>]
/// so prepending at index 0 (`insert(0, point)`) and trimming (`removeLast()`)
/// execute in constant time without O(N) array shifting in 100-ball Chaos mode.
class FixedTrailRingBuffer extends ListBase<TrailPoint> {
  static const int _capacity = 128; // Power of 2 for bitmasking
  static const int _mask = _capacity - 1;
  static const TrailPoint _zero = TrailPoint(Offset.zero, 0.0);

  final List<TrailPoint> _buffer = List<TrailPoint>.filled(_capacity, _zero, growable: false);
  int _head = 0;
  int _length = 0;

  @override
  int get length => _length;

  @override
  set length(int newLength) {
    if (newLength < 0) newLength = 0;
    if (newLength > _capacity) newLength = _capacity;
    _length = newLength;
  }

  @override
  TrailPoint operator [](int index) {
    return _buffer[(_head + index) & _mask];
  }

  @override
  void operator []=(int index, TrailPoint value) {
    _buffer[(_head + index) & _mask] = value;
  }

  /// O(1) front insertion used on every physics frame.
  void pushFront(TrailPoint point, int maxCap) {
    _head = (_head - 1) & _mask;
    _buffer[_head] = point;
    final effectiveCap = maxCap < _capacity ? maxCap : _capacity;
    if (_length < effectiveCap) {
      _length++;
    } else {
      _length = effectiveCap;
    }
  }

  @override
  void insert(int index, TrailPoint element) {
    if (index == 0) {
      _head = (_head - 1) & _mask;
      _buffer[_head] = element;
      if (_length < _capacity) _length++;
      return;
    }
    super.insert(index, element);
  }

  @override
  TrailPoint removeLast() {
    if (_length == 0) return _zero;
    _length--;
    return _buffer[(_head + _length) & _mask];
  }

  @override
  void clear() {
    _length = 0;
    _head = 0;
  }
}

class Ball {
  double x;
  double y;
  double vx;
  double vy;
  double radius;
  bool isStuck;
  double stuckOffsetX;
  final FixedTrailRingBuffer trail = FixedTrailRingBuffer();
  bool isFireball;
  int fireballPierceCount = 0;
  int fireballPaddleBounces = 0;
  bool isBomb;
  bool isPierce;
  bool isMirror;
  bool isFrost;
  bool isShrapnel;
  int overload;
  double squashTimer;
  double squashAngle;
  double stuckTimer;
  double cornerBoostTimer;
  double megaTimer = 0.0;
  int cornerHitCount = 0;
  int overdriveStreak = 0;
  bool isPurple = false;
  double anomalyCooldown = 0.0;
  int sideWallBounceCount = 0;
  bool isWallSpeedBoosted = false;
  bool isDayBlessed = false;
  int rapidBounceCount = 0;
  double rapidBounceTimer = 0.0;
  bool isOverdriveHoming = false;
  double clutchOverchargeTimer = 0.0;
  int clutchPierceRemaining = 0;
  double pulseBoostTimer = 0.0;
  dynamic lastHitBrick;
  double lastHitBrickCooldown = 0.0;

  bool get isClutchOvercharged => clutchOverchargeTimer > 0;
  bool get isPulseBoosted => pulseBoostTimer > 0;

  Ball({
    required this.x,
    required this.y,
    this.vx = 0.0,
    this.vy = 0.0,
    this.radius = 7.5,
    bool? isStuck,
    this.stuckOffsetX = 0.0,
    this.isFireball = false,
    int? fireballPierceCount,
    this.fireballPaddleBounces = 0,
    this.isBomb = false,
    this.isPierce = false,
    this.isMirror = false,
    this.isFrost = false,
    this.isShrapnel = false,
    this.overload = 0,
    this.squashTimer = 0.0,
    this.squashAngle = 0.0,
    this.stuckTimer = 0.0,
    this.cornerBoostTimer = 0.0,
    this.megaTimer = 0.0,
  }) : isStuck = isStuck ?? (vx == 0.0 && vy == 0.0),
       fireballPierceCount = fireballPierceCount ?? ((isFireball || isPierce) ? 12 : 0);

  double get effectiveRadius => megaTimer > 0 ? (radius * 1.85).clamp(13.0, 16.0) : radius;

  double get speed => sqrt(vx * vx + vy * vy);

  void setSpeed(double targetSpeed) {
    final currentSpeed = speed;
    if (currentSpeed > 0.001) {
      final factor = targetSpeed / currentSpeed;
      vx *= factor;
      vy *= factor;
    } else {
      vx = targetSpeed * 0.5;
      vy = -targetSpeed * 0.866;
    }
  }

  void triggerSquash(double angle) {
    squashTimer = 0.22;
    squashAngle = angle;
  }

  void update(double dt, {int trailLength = 24, bool recordTrail = true}) {
    if (squashTimer > 0) {
      squashTimer -= dt;
      if (squashTimer < 0) squashTimer = 0;
    }
    if (cornerBoostTimer > 0) {
      cornerBoostTimer -= dt;
      if (cornerBoostTimer < 0) cornerBoostTimer = 0.0;
    }
    if (megaTimer > 0) {
      megaTimer -= dt;
      if (megaTimer < 0) megaTimer = 0.0;
    }
    if (anomalyCooldown > 0) {
      anomalyCooldown -= dt;
      if (anomalyCooldown < 0) anomalyCooldown = 0.0;
    }
    if (rapidBounceTimer > 0) {
      rapidBounceTimer -= dt;
      if (rapidBounceTimer <= 0) {
        rapidBounceTimer = 0.0;
        rapidBounceCount = 0;
      }
    }
    if (clutchOverchargeTimer > 0) {
      clutchOverchargeTimer -= dt;
      if (clutchOverchargeTimer <= 0) {
        clutchOverchargeTimer = 0.0;
        clutchPierceRemaining = 0;
      }
    }
    if (pulseBoostTimer > 0) {
      pulseBoostTimer -= dt;
      if (pulseBoostTimer < 0) pulseBoostTimer = 0.0;
    }
    if (lastHitBrickCooldown > 0) {
      lastHitBrickCooldown -= dt;
      if (lastHitBrickCooldown <= 0) {
        lastHitBrickCooldown = 0.0;
        lastHitBrick = null;
      }
    }

    if (!isStuck) {
      x += vx * dt;
      y += vy * dt;

      if (recordTrail) {
        final cap = cornerBoostTimer > 0
            ? 120
            : (isFireball ? (trailLength + 16) : trailLength);
        trail.pushFront(TrailPoint(Offset(x, y), dt), cap);
      }
    }
  }
}
