
class BlackHole {
  double x;
  double y;
  double radius;
  double mass; // Affects gravity strength
  double rotation = 0.0;
  double timeLeft;

  BlackHole({
    required this.x,
    required this.y,
    required this.radius,
    required this.mass,
    this.timeLeft = 5.0,
  });

  void update(double dt) {
    rotation += 2.0 * dt;
    timeLeft -= dt;
  }
}

