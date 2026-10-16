import 'dart:math';
import 'package:flutter/material.dart';

enum PortalType {
  standard,     // Classic quantum wormhole (Cyan / Solar Amber)
  moving,       // Kinetic moving portal (oscillates smoothly)
  accelerator,  // Hyper-drive accelerator (supercharges ball speed & momentum)
  gravity,      // Gravitational pulsar (subtly bends nearby trajectories)
  quantumPhase, // Phase-shifting portal (pulses with harmonic chromatic resonance)
}

class Portal {
  double x;
  double y;
  double radius;
  Color color;
  double rotation = 0.0;
  bool isBlue; // true for primary, false for linked
  Portal? linkedPortal;
  final PortalType type;

  // Kinetic movement parameters for PortalType.moving
  double originX;
  double originY;
  double moveSpeed;
  double moveAmplitude;
  double movePhase;
  double moveTime = 0.0;

  Portal({
    required this.x,
    required this.y,
    required this.radius,
    required this.color,
    required this.isBlue,
    this.type = PortalType.standard,
    double? originX,
    double? originY,
    this.moveSpeed = 1.6,
    this.moveAmplitude = 55.0,
    this.movePhase = 0.0,
  })  : originX = originX ?? x,
        originY = originY ?? y;

  void update(double dt, {double screenWidth = 360.0}) {
    rotation += 2.8 * dt;

    if (type == PortalType.moving) {
      moveTime += dt;
      // Smooth sinusoidal horizontal oscillation
      x = (originX + sin(moveTime * moveSpeed + movePhase) * moveAmplitude)
          .clamp(radius + 20.0, screenWidth - radius - 20.0);
    }
  }
}
