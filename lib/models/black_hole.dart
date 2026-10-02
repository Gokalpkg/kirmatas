
class BlackHole {
  double x;
  double y;
  double radius;
  double mass; // Affects gravity strength
  double rotation = 0.0;
  double timeLeft;
  final bool isVortexTrap; // 1% rare vortex that spins ball multiple times
  final Map<int, double> ballAngles = {};
  final Map<int, double> ballAccumulatedAngles = {};

  BlackHole({
    required this.x,
    required this.y,
    required this.radius,
    required this.mass,
    this.timeLeft = 5.0,
    this.isVortexTrap = false,
  });

  void update(double dt) {
    rotation += (isVortexTrap ? 4.5 : 2.0) * dt;
    timeLeft -= dt;
  }
}

