import 'package:flutter/material.dart';

class Paddle {
  double x;
  double y;
  double width;
  double height;
  double baseWidth;
  bool isSticky;
  bool hasLaser;
  double laserCooldown;
  bool hasRockets;
  double rocketCooldown;
  bool hasDrone;
  double droneAngle;
  bool hasNet;
  int netHitsRemaining;
  bool isGhost;
  bool isReversed;
  bool isClumsy;
  double prevX;
  double velocityX;

  Paddle({
    required this.x,
    required this.y,
    this.width = 88.0,
    this.height = 14.0,
    this.baseWidth = 88.0,
    this.isSticky = false,
    this.hasLaser = false,
    this.laserCooldown = 0.0,
    this.hasRockets = false,
    this.rocketCooldown = 0.0,
    this.hasDrone = false,
    this.droneAngle = 0.0,
    this.hasNet = false,
    this.netHitsRemaining = 2,
    this.isGhost = false,
    this.isReversed = false,
    this.isClumsy = false,
    this.prevX = 0.0,
    this.velocityX = 0.0,
  });

  Rect get rect => Rect.fromLTWH(x, y, width, height);

  void update(double dt) {
    velocityX = (x - prevX) / (dt > 0.0001 ? dt : 0.016);
    prevX = x;

    if (laserCooldown > 0) laserCooldown -= dt;
    if (rocketCooldown > 0) rocketCooldown -= dt;
    if (hasDrone) {
      droneAngle += dt * 3.0;
    }
  }

  void resetWidth() {
    width = baseWidth;
  }
}

class Projectile {
  double x;
  double y;
  double vx;
  double vy;
  double radius;
  bool isLaser;
  bool isRocket;
  bool isBossBullet;
  bool isAlive;

  Projectile({
    required this.x,
    required this.y,
    this.vx = 0.0,
    this.vy = -450.0,
    this.radius = 4.0,
    this.isLaser = false,
    this.isRocket = false,
    this.isBossBullet = false,
    this.isAlive = true,
  });

  Rect get rect => Rect.fromCenter(center: Offset(x, y), width: radius * 2, height: radius * 2);

  void update(double dt) {
    x += vx * dt;
    y += vy * dt;
  }
}
