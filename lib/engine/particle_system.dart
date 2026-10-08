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

class ParticleSystem {
  final List<Particle> particles = [];
  final List<Shockwave> shockwaves = [];
  final List<FloatingText> floatingTexts = [];
  final Random _rand = Random();

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

    for (int i = 0; i < floatingTexts.length; i++) {
      floatingTexts[i].update(dt);
    }
    floatingTexts.removeWhere((f) => f.isDead);
  }

  void clear() {
    particles.clear();
    shockwaves.clear();
    floatingTexts.clear();
    shakeTimeLeft = 0.0;
  }
}
