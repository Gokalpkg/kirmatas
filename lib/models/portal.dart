import 'package:flutter/material.dart';

class Portal {
  double x;
  double y;
  double radius;
  Color color;
  double rotation = 0.0;
  bool isBlue; // true for blue, false for orange
  Portal? linkedPortal;

  Portal({
    required this.x,
    required this.y,
    required this.radius,
    required this.color,
    required this.isBlue,
  });

  void update(double dt) {
    rotation += 3.0 * dt; // Fast spin
  }
}
