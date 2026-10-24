import 'package:flutter/material.dart';

class Paddle {
  double x;
  double y;
  double width;
  double height;
  double baseWidth;
  bool isSticky;
  bool hasLaser;
  int laserAmmo;
  double laserCooldown;
  bool hasRockets;
  int rocketAmmo = 0;
  double rocketCooldown;
  bool hasDrone;
  double droneAngle;
  bool hasNet;
  int netHitsRemaining;
  bool isGhost;
  bool isReversed;
  bool isClumsy;
  bool hasVortex;
  double vortexAngle;
  double slideVelocity;
  double prevX;
  double velocityX;

  /// Pixel Art Phase 2: 1-frame white/cyan impact flash & elastic squash-and-bounce
  double flashTimer = 0.0;
  double bounceOffsetY = 0.0;
  double bounceVy = 0.0;
  double squashScaleX = 1.0;
  double squashScaleY = 1.0;

  Paddle({
    required this.x,
    required this.y,
    this.width = 88.0,
    this.height = 14.0,
    this.baseWidth = 88.0,
    this.isSticky = false,
    this.hasLaser = false,
    this.laserAmmo = 0,
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
    this.hasVortex = false,
    this.vortexAngle = 0.0,
    this.slideVelocity = 0.0,
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
    if (hasVortex) {
      vortexAngle += dt * 7.5;
    }

    if (flashTimer > 0) {
      flashTimer = (flashTimer - dt).clamp(0.0, 1.0);
    }

    // Damped spring oscillator for vertical impact recoil (bounceOffsetY)
    if (bounceOffsetY.abs() > 0.01 || bounceVy.abs() > 0.01) {
      final springForce = -260.0 * bounceOffsetY;
      final damping = -18.0 * bounceVy;
      bounceVy += (springForce + damping) * dt;
      bounceOffsetY += bounceVy * dt;
      if (bounceOffsetY.abs() < 0.05 && bounceVy.abs() < 0.5) {
        bounceOffsetY = 0.0;
        bounceVy = 0.0;
      }
    }

    // Elastic recovery of squash & stretch scales back to 1.0
    if ((squashScaleX - 1.0).abs() > 0.002) {
      squashScaleX += (1.0 - squashScaleX) * (dt * 16.0).clamp(0.0, 1.0);
    } else {
      squashScaleX = 1.0;
    }
    if ((squashScaleY - 1.0).abs() > 0.002) {
      squashScaleY += (1.0 - squashScaleY) * (dt * 16.0).clamp(0.0, 1.0);
    } else {
      squashScaleY = 1.0;
    }
  }

  /// Triggers a 1-frame pixel flash and downward elastic squash-and-stretch impulse
  void triggerHitReaction({bool isCorner = false}) {
    flashTimer = 0.035;
    bounceVy = isCorner ? 75.0 : 52.0;
    squashScaleX = isCorner ? 1.14 : 1.08;
    squashScaleY = isCorner ? 0.78 : 0.84;
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
  bool isShrapnel;
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
    this.isShrapnel = false,
    this.isAlive = true,
  });

  Rect get rect => Rect.fromCenter(center: Offset(x, y), width: radius * 2, height: radius * 2);

  void update(double dt) {
    x += vx * dt;
    y += vy * dt;
  }
}
