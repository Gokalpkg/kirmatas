
import 'dart:math';

class BlackHole {
  double x;
  double y;
  double radius;
  double mass; // Affects gravity strength
  double rotation = 0.0;
  double timeLeft;
  final bool isVortexTrap; // 1% rare vortex that spins ball multiple times
  final bool isSupercharged; // Exotic hyper-charged singularity that spins and slingshots balls forward
  final Map<int, double> ballAngles = {};
  final Map<int, double> ballAccumulatedAngles = {};
  final Map<int, int> ballOrbitLaps = {};

  BlackHole({
    required this.x,
    required this.y,
    required this.radius,
    required this.mass,
    this.timeLeft = 5.0,
    this.isVortexTrap = false,
    this.isSupercharged = false,
  });

  double get maxInfluenceDist => max(135.0, radius * (isVortexTrap ? 6.5 : (isSupercharged ? 6.0 : 5.5)));

  void update(double dt) {
    final speedMultiplier = isVortexTrap ? 4.5 : (isSupercharged ? 3.6 : 2.0);
    rotation += speedMultiplier * dt;
    timeLeft -= dt;
  }
}

