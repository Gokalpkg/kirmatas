import 'dart:math';
import 'package:flutter/material.dart';

enum BrickType {
  normal,
  boss,
  steel,
  heavySteel,
  ice,
  dynamite,
  tuft,
  ballPickup,
}

class Brick {
  double x;
  double y;
  double targetY;
  double width;
  double height;
  int hp;
  int maxHp;
  bool isSteel;
  bool isHeavySteel;
  bool isMover;
  double moverVx;
  double minX;
  double maxX;
  bool isBoss;
  double bossVx;
  double shootTimer;
  bool isDynamite;
  bool isIce;
  bool isFrozen;
  double frozenTimer;
  bool isTuft;
  bool tuftFilled;
  Color tuftColor;
  bool isBallPickup;
  double jelly; // wobble deformation amount (0.0 to 1.0)
  double flashTimer = 0.0; // 1-frame pure white flash on hit / destruction
  double bounceOffsetY = 0.0; // Elastic overshoot settling displacement
  double bounceVy = 0.0; // Elastic overshoot settling velocity
  Color color;
  Color? originalColor;
  int points;
  bool isAlive;
  BrickType? _explicitType;

  Brick({
    required this.x,
    required this.y,
    double? targetY,
    required this.width,
    required this.height,
    this.hp = 1,
    this.maxHp = 1,
    this.isSteel = false,
    this.isHeavySteel = false,
    this.isMover = false,
    this.isDynamite = false,
    this.isIce = false,
    this.isFrozen = false,
    this.frozenTimer = 0.0,
    this.moverVx = 60.0,
    this.minX = 10.0,
    this.maxX = 380.0,
    bool isBoss = false,
    this.bossVx = 70.0,
    this.shootTimer = 3.4,
    this.isTuft = false,
    this.tuftFilled = false,
    this.tuftColor = const Color(0xFFFF7043),
    this.isBallPickup = false,
    this.jelly = 0.0,
    required this.color,
    this.points = 10,
    this.isAlive = true,
    BrickType? type,
  })  : targetY = targetY ?? y,
        isBoss = isBoss || type == BrickType.boss,
        _explicitType = type;

  BrickType get type {
    if (_explicitType != null) return _explicitType!;
    if (isBoss) return BrickType.boss;
    if (isHeavySteel) return BrickType.heavySteel;
    if (isSteel) return BrickType.steel;
    if (isIce) return BrickType.ice;
    if (isDynamite) return BrickType.dynamite;
    if (isTuft) return BrickType.tuft;
    if (isBallPickup) return BrickType.ballPickup;
    return BrickType.normal;
  }

  set type(BrickType v) {
    _explicitType = v;
    if (v == BrickType.boss) isBoss = true;
  }

  bool get isEnraged => isBoss && hp <= maxHp * 0.35 && hp > 0;

  Rect get rect => Rect.fromLTWH(x, y, width, height);

  void update(double dt) {
    if (!isAlive) return;

    // Smooth Y sliding for descend mode
    if ((targetY - y).abs() > 0.2) {
      y += (targetY - y) * (1.0 - exp(-12.0 * dt));
    } else {
      y = targetY;
    }

    // Jelly decay
    if (jelly > 0) {
      jelly -= dt * 3.5;
      if (jelly < 0) jelly = 0;
    }

    // Step 1: 1-frame pure white flash countdown
    if (flashTimer > 0) {
      flashTimer -= dt;
      if (flashTimer < 0) flashTimer = 0.0;
    }

    // Step 5: Elastic overshoot settling spring physics
    if (bounceOffsetY != 0.0 || bounceVy != 0.0) {
      final springForce = -240.0 * bounceOffsetY;
      final damping = -18.0 * bounceVy;
      bounceVy += (springForce + damping) * dt;
      bounceOffsetY += bounceVy * dt;
      if (bounceOffsetY.abs() < 0.05 && bounceVy.abs() < 0.5) {
        bounceOffsetY = 0.0;
        bounceVy = 0.0;
      }
    }

    // Moving brick horizontal oscillation
    if (isMover) {
      x += moverVx * dt;
      if (x <= minX) {
        x = minX;
        moverVx = moverVx.abs();
      } else if (x + width >= maxX) {
        x = maxX - width;
        moverVx = -moverVx.abs();
      }
    }

    // Boss brick logic
    if (isBoss) {
      final currentVx = (hp <= maxHp * 0.35 && hp > 0) ? bossVx * 1.5 : bossVx;
      x += currentVx * dt;
      if (x <= minX) {
        x = minX;
        bossVx = bossVx.abs();
      } else if (x + width >= maxX) {
        x = maxX - width;
        bossVx = -bossVx.abs();
      }
      shootTimer -= dt;
    }
  }

  /// Step 1: Trigger 1-frame pure white flash (35ms duration)
  void triggerWhiteFlash([double duration = 0.035]) {
    flashTimer = duration;
  }

  /// Step 5: Trigger elastic overshoot settling bounce
  void triggerElasticSettle({double impulse = 5.0}) {
    bounceVy = impulse;
    jelly = 0.6;
  }
}

