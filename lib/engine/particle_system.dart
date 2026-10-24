import 'dart:math';
import 'package:flutter/material.dart';

class Particle {
  double x;
  double y;
  double vx;
  double vy;
  double size;
  Color color;
  double life;
  final double maxLife;

  Particle({
    required this.x,
    required this.y,
    required this.vx,
    required this.vy,
    required this.size,
    required this.color,
    required this.maxLife,
  }) : life = maxLife;

  bool get isDead => life <= 0;

  void update(double dt) {
    x += vx * dt;
    y += vy * dt;
    life -= dt;
  }
}

class Shockwave {
  final double x;
  final double y;
  final Color color;
  final double maxRadius;
  double currentRadius;
  final double duration;
  double progress;

  Shockwave({
    required this.x,
    required this.y,
    required this.color,
    this.maxRadius = 45.0,
    this.duration = 0.35,
  })  : currentRadius = 4.0,
        progress = 0.0;

  bool get isDead => progress >= 1.0;

  void update(double dt) {
    progress += dt / duration;
    currentRadius = maxRadius * Curves.easeOutCubic.transform(progress.clamp(0.0, 1.0));
  }
}

class FloatingText {
  double x;
  double y;
  final String text;
  final Color color;
  final bool isLarge;
  double life;
  final double maxLife;

  FloatingText({
    required this.x,
    required this.y,
    required this.text,
    required this.color,
    this.isLarge = false,
    this.maxLife = 0.75,
  }) : life = maxLife;

  bool get isDead => life <= 0;

  void update(double dt) {
    y -= 35.0 * dt;
    life -= dt;
  }
}

class BrickShard {
  double x;
  double y;
  double vx;
  double vy;
  double rotation;
  double vRot;
  double width;
  double height;
  Color color;
  double life;
  final double maxLife;
  int bounceCount = 0;
  final double floorY;

  BrickShard({
    required this.x,
    required this.y,
    required this.vx,
    required this.vy,
    required this.rotation,
    required this.vRot,
    required this.width,
    required this.height,
    required this.color,
    required this.maxLife,
    double? floorY,
  })  : life = maxLife,
        floorY = floorY ?? (y + 110.0);

  bool get isDead => life <= 0;

  void update(double dt) {
    x += vx * dt;
    y += vy * dt;
    vy += 420.0 * dt; // Gravity
    vx *= 0.98; // Air resistance
    rotation += vRot * dt;
    // Step 3: Zıplayarak dağılma (bounce off floor/air)
    if (y >= floorY && bounceCount < 2) {
      y = floorY;
      vy = -vy.abs() * 0.55;
      bounceCount++;
    }
    life -= dt;
  }
}

/// Step 2: Left-to-right sweeping retro square pixel wave
class PixelShockwave {
  final double x;
  final double y;
  final double width;
  final double height;
  final Color color;
  final double duration;
  double progress = 0.0;

  PixelShockwave({
    required this.x,
    required this.y,
    this.width = 65.0,
    this.height = 24.0,
    required this.color,
    this.duration = 0.28,
  });

  bool get isDead => progress >= 1.0;

  void update(double dt) {
    progress += dt / duration;
  }
}

/// A collectible coin/energy orb: bursts outward, bounces on its floor,
/// glows for a beat, then flies to the HUD counter on a curved path.
class CoinOrb {
  double x;
  double y;
  double vx;
  double vy;
  final double floorY;
  final double staggerDelay;
  final Color color;
  final double size;
  double age = 0.0;
  double spin = 0.0;
  double flyT = -1.0; // -1 = scatter/glow phase, 0..1 = flying
  double startX = 0.0;
  double startY = 0.0;
  bool arrived = false;

  /// Gold value this orb delivers to the HUD counter when it lands.
  final int value;
  final List<Offset> trail = [];

  CoinOrb({
    required this.x,
    required this.y,
    required this.vx,
    required this.vy,
    required this.floorY,
    required this.staggerDelay,
    this.color = const Color(0xFFFFD54F),
    this.size = 6.0,
    this.value = 0,
  });

  static const double scatterDuration = 0.30;
  static const double glowDuration = 0.16;
  static const double flyDuration = 0.42;

  bool get isFlying => flyT >= 0.0;
  bool get isGlowing => !isFlying && age > scatterDuration;

  void update(double dt, Offset target) {
    age += dt;
    spin += dt * (isFlying ? 14.0 : 5.0);
    if (!isFlying) {
      if (age <= scatterDuration) {
        vy += 900.0 * dt;
        x += vx * dt;
        y += vy * dt;
        if (y > floorY) {
          y = floorY;
          vy = -vy.abs() * 0.45;
          vx *= 0.7;
          if (vy.abs() < 40.0) vy = 0.0;
        }
      }
      if (age >= scatterDuration + glowDuration + staggerDelay) {
        flyT = 0.0;
        startX = x;
        startY = y;
      }
      return;
    }
    trail.add(Offset(x, y));
    if (trail.length > 7) trail.removeAt(0);
    flyT += dt / flyDuration;
    if (flyT >= 1.0) {
      flyT = 1.0;
      arrived = true;
      x = target.dx;
      y = target.dy;
      return;
    }
    final t = flyT;
    // Magnet pull: slow release, then accelerating snap into the counter.
    final ease = t * t * t * (t * (t * 6 - 15) + 10);
    final ctrlX = (startX + target.dx) / 2;
    final ctrlY = min(startY, target.dy) - 90.0;
    final inv = 1 - ease;
    x = inv * inv * startX + 2 * inv * ease * ctrlX + ease * ease * target.dx;
    y = inv * inv * startY + 2 * inv * ease * ctrlY + ease * ease * target.dy;
  }
}

class ParticleSystem {
  final List<Particle> particles = [];
  final List<Shockwave> shockwaves = [];
  final List<PixelShockwave> pixelShockwaves = [];
  final List<FloatingText> floatingTexts = [];
  final List<BrickShard> shards = [];
  final List<CoinOrb> coinOrbs = [];
  final Random _rand = Random();

  static const int maxCoinOrbs = 22;

  void spawnCoinOrbs(double x, double y,
      {int count = 3, Color color = const Color(0xFFFFD54F), int totalValue = 0}) {
    final safeCount = count < 1 ? 1 : count;
    for (int i = 0; i < safeCount; i++) {
      if (coinOrbs.length >= maxCoinOrbs) coinOrbs.removeAt(0);
      final angle = -pi / 2 + (_rand.nextDouble() - 0.5) * 2.2;
      final spd = 130.0 + _rand.nextDouble() * 170.0;
      // Split the brick's gold across its orbs (remainder lands first).
      final orbValue = totalValue <= 0
          ? 0
          : (totalValue ~/ safeCount) + (i < totalValue % safeCount ? 1 : 0);
      coinOrbs.add(
        CoinOrb(
          x: x,
          y: y,
          vx: cos(angle) * spd,
          vy: sin(angle) * spd,
          floorY: y + 55.0 + _rand.nextDouble() * 45.0,
          staggerDelay: i * 0.055,
          color: color,
          size: 5.0 + _rand.nextDouble() * 2.6,
          value: orbValue,
        ),
      );
    }
  }

  /// Advances coin orbs toward [target]; calls [onArrive] with each orb's
  /// gold value as it lands.
  void updateCoinOrbs(double dt, Offset target, void Function(int value) onArrive) {
    for (final orb in coinOrbs) {
      orb.update(dt, target);
      if (orb.arrived) onArrive(orb.value);
    }
    coinOrbs.removeWhere((o) => o.arrived);
  }

  double shakeTimeLeft = 0.0;
  double shakeMagnitude = 0.0;

  void triggerShake(double magnitude, double duration) {
    shakeMagnitude = magnitude;
    shakeTimeLeft = duration;
  }

  Offset getShakeOffset() {
    if (shakeTimeLeft <= 0) return Offset.zero;
    final dx = (_rand.nextDouble() * 2 - 1) * shakeMagnitude;
    final dy = (_rand.nextDouble() * 2 - 1) * shakeMagnitude;
    return Offset(dx, dy);
  }

  static const int maxParticles = 50;
  static const int maxShockwaves = 6;
  static const int maxFloatingTexts = 5;
  static const int maxShards = 24;

  void spawnBurst(double x, double y, Color color, {int count = 10, double speed = 150.0}) {
    final toAdd = min(count, maxParticles - particles.length + 8);
    if (toAdd <= 0) return;

    final overflow = (particles.length + toAdd) - maxParticles;
    if (overflow > 0) {
      final removeCount = min(overflow, particles.length);
      particles.removeRange(0, removeCount);
    }

    for (int i = 0; i < toAdd; i++) {
      final angle = _rand.nextDouble() * 2 * pi;
      final spd = speed * (0.4 + _rand.nextDouble() * 0.8);
      particles.add(
        Particle(
          x: x,
          y: y,
          vx: cos(angle) * spd,
          vy: sin(angle) * spd,
          size: 2.0 + _rand.nextDouble() * 2.5,
          color: color,
          maxLife: 0.25 + _rand.nextDouble() * 0.25,
        ),
      );
    }
  }

  void spawnBurnEmber(double x, double y, {Color? color}) {
    if (particles.length >= maxParticles) {
      particles.removeAt(0);
    }
    final angle = _rand.nextDouble() * 2 * pi;
    final spd = 4.0 + _rand.nextDouble() * 12.0;
    final Color chosenColor;
    if (color != null) {
      chosenColor = _rand.nextBool() ? color : Color.lerp(color, Colors.white, 0.45)!;
    } else {
      const colors = [
        Color(0xFFFFD54F),
        Color(0xFFFFB300),
        Color(0xFFFF8F00),
        Color(0xFFFFF9C4),
      ];
      chosenColor = colors[_rand.nextInt(colors.length)];
    }
    particles.add(
      Particle(
        x: x + (_rand.nextDouble() * 4 - 2),
        y: y + (_rand.nextDouble() * 4 - 2),
        vx: cos(angle) * spd,
        vy: sin(angle) * spd - 6.0,
        size: 3.0 + _rand.nextDouble() * 2.2,
        color: chosenColor,
        maxLife: 0.65 + _rand.nextDouble() * 0.35,
      ),
    );
  }

  void spawnShockwave(double x, double y, Color color, {double maxRadius = 45.0}) {
    if (shockwaves.length >= maxShockwaves) {
      shockwaves.removeAt(0);
    }
    shockwaves.add(
      Shockwave(x: x, y: y, color: color, maxRadius: maxRadius),
    );
  }

  void spawnFloatingText(double x, double y, String text, Color color, {bool isLarge = false}) {
    if (floatingTexts.length >= maxFloatingTexts) {
      floatingTexts.removeAt(0);
    }
    floatingTexts.add(
      FloatingText(x: x, y: y, text: text, color: color, isLarge: isLarge),
    );
  }

  /// Step 2: Spawns a left-to-right sweeping retro square pixel wave
  void spawnPixelWave(double bx, double by, double bw, double bh, Color color) {
    if (pixelShockwaves.length >= 8) {
      pixelShockwaves.removeAt(0);
    }
    pixelShockwaves.add(
      PixelShockwave(
        x: bx,
        y: by,
        width: bw,
        height: bh,
        color: color,
      ),
    );
  }

  void spawnBrickShards(double bx, double by, double bw, double bh, Color color, {int count = 6}) {
    if (shards.length + count > maxShards) {
      final overflow = (shards.length + count) - maxShards;
      shards.removeRange(0, min(overflow, shards.length));
    }
    for (int i = 0; i < count; i++) {
      final angle = -pi * 0.85 + _rand.nextDouble() * pi * 0.7; // Spread upwards and outwards
      final speed = 80.0 + _rand.nextDouble() * 140.0;
      shards.add(
        BrickShard(
          x: bx + (_rand.nextDouble() * 0.8 + 0.1) * bw,
          y: by + (_rand.nextDouble() * 0.8 + 0.1) * bh,
          vx: cos(angle) * speed,
          vy: sin(angle) * speed,
          rotation: (_rand.nextInt(4) * pi / 2), // Stepped 90-degree pixel art rotation
          vRot: (_rand.nextDouble() * 6.0 - 3.0),
          width: 4.5 + _rand.nextDouble() * 3.5, // Crisp square pixel chunk
          height: 4.5 + _rand.nextDouble() * 3.5,
          color: color,
          maxLife: 0.55 + _rand.nextDouble() * 0.30,
          floorY: by + bh + 45.0 + _rand.nextDouble() * 55.0,
        ),
      );
    }
  }

  void update(double dt) {
    if (shakeTimeLeft > 0) {
      shakeTimeLeft -= dt;
      if (shakeTimeLeft < 0) shakeTimeLeft = 0;
    }

    for (int i = 0; i < particles.length; i++) {
      particles[i].update(dt);
    }
    particles.removeWhere((p) => p.isDead);

    for (int i = 0; i < shockwaves.length; i++) {
      shockwaves[i].update(dt);
    }
    shockwaves.removeWhere((s) => s.isDead);

    for (int i = 0; i < pixelShockwaves.length; i++) {
      pixelShockwaves[i].update(dt);
    }
    pixelShockwaves.removeWhere((p) => p.isDead);

    for (int i = 0; i < floatingTexts.length; i++) {
      floatingTexts[i].update(dt);
    }
    floatingTexts.removeWhere((f) => f.isDead);

    for (int i = 0; i < shards.length; i++) {
      shards[i].update(dt);
    }
    shards.removeWhere((s) => s.isDead);
  }

  void clear() {
    particles.clear();
    shockwaves.clear();
    pixelShockwaves.clear();
    floatingTexts.clear();
    shards.clear();
    coinOrbs.clear();
    shakeTimeLeft = 0.0;
  }
}
