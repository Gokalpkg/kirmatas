import 'dart:math';
import 'package:flutter/material.dart';

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
  bool isTuft;
  bool tuftFilled;
  Color tuftColor;
  double jelly; // wobble deformation amount (0.0 to 1.0)
  Color color;
  int points;
  bool isAlive;

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
    this.moverVx = 60.0,
    this.minX = 10.0,
    this.maxX = 380.0,
    this.isBoss = false,
    this.bossVx = 70.0,
    this.shootTimer = 2.0,
    this.isTuft = false,
    this.tuftFilled = false,
    this.tuftColor = const Color(0xFFFF7043),
    this.jelly = 0.0,
    required this.color,
    this.points = 10,
    this.isAlive = true,
  }) : targetY = targetY ?? y;

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
      x += bossVx * dt;
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
}
