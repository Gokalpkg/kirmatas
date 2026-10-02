import 'dart:math';
import 'package:flutter/material.dart';

class TrailPoint {
  final Offset position;
  final double time;
  TrailPoint(this.position, this.time);
}

class Ball {
  double x;
  double y;
  double vx;
  double vy;
  double radius;
  bool isStuck;
  double stuckOffsetX;
  final List<TrailPoint> trail = [];
  bool isFireball;
  int fireballPierceCount = 0;
  int fireballPaddleBounces = 0;
  bool isBomb;
  bool isPierce;
  bool isMirror;
  int overload;
  double squashTimer;
  double squashAngle;
  double stuckTimer;
  double cornerBoostTimer;
  int cornerHitCount = 0;
  bool isPurple = false;
  double anomalyCooldown = 0.0;

  Ball({
    required this.x,
    required this.y,
    this.vx = 0.0,
    this.vy = 0.0,
    this.radius = 7.5,
    this.isStuck = true,
    this.stuckOffsetX = 0.0,
    this.isFireball = false,
    this.isBomb = false,
    this.isPierce = false,
    this.isMirror = false,
    this.overload = 0,
    this.squashTimer = 0.0,
    this.squashAngle = 0.0,
    this.stuckTimer = 0.0,
    this.cornerBoostTimer = 0.0,
  });

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

  void update(double dt, {int trailLength = 24}) {
    if (squashTimer > 0) {
      squashTimer -= dt;
      if (squashTimer < 0) squashTimer = 0;
    }
    if (cornerBoostTimer > 0) {
      cornerBoostTimer -= dt;
      if (cornerBoostTimer < 0) cornerBoostTimer = 0.0;
    }
    if (anomalyCooldown > 0) {
      anomalyCooldown -= dt;
      if (anomalyCooldown < 0) anomalyCooldown = 0.0;
    }

    if (!isStuck) {
      x += vx * dt;
      y += vy * dt;

      trail.insert(0, TrailPoint(Offset(x, y), dt));
      final cap = cornerBoostTimer > 0
          ? 56
          : (isFireball ? (trailLength + 12) : trailLength);
      while (trail.length > cap) {
        trail.removeLast();
      }
    }
  }
}
