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
  bool isBomb;
  bool isPierce;
  bool isMirror;
  int overload;
  double squashTimer;
  double squashAngle;
  double stuckTimer;

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

  void update(double dt) {
    if (squashTimer > 0) {
      squashTimer -= dt;
      if (squashTimer < 0) squashTimer = 0;
    }

    if (!isStuck) {
      x += vx * dt;
      y += vy * dt;

      trail.insert(0, TrailPoint(Offset(x, y), dt));
      if (trail.length > 16) {
        trail.removeLast();
      }
    }
  }
}
