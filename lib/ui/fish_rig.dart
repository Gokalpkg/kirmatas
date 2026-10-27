import 'dart:math';
import 'package:flutter/material.dart';
import '../models/cosmetics.dart';
import 'octopus_rig.dart';

/// Base procedural species for the 23 Eco-Tank dwellers.
enum FishSpecies {
  guppy,
  tetra,
  angel,
  betta,
  discus,
  arowana,
  shrimp,
  crab,
  snail,
  jellyfish,
  octopus,
}

/// Decorative body pattern rendered over the spline body.
enum FishPattern {
  fanSpots,
  neonStripe,
  verticalBars,
  iridescentVeil,
  waveRipples,
  dragonScales,
  segmentedShell,
  carapaceMottle,
  spiralBands,
  translucentRings,
}

/// Colour and anatomy style for a procedural fish / creature variant.
class FishStyle {
  final FishSpecies species;
  final FishPattern pattern;
  final Color primary;
  final Color secondary;
  final Color accent;
  final Color finColor;
  final Color bellyColor;

  /// Body half-length in local rig units (snout at +length, tail root at -length).
  final double bodyLength;

  /// Maximum body half-height in local rig units.
  final double bodyHeight;

  /// Baseline cruising speed in tank world coordinates.
  final double baseSpeed;

  /// Burst multiplier during a swim kick.
  final double burstMult;

  /// Tail beat frequency multiplier.
  final double tailFreq;

  const FishStyle({
    required this.species,
    required this.pattern,
    required this.primary,
    required this.secondary,
    required this.accent,
    required this.finColor,
    required this.bellyColor,
    required this.bodyLength,
    required this.bodyHeight,
    required this.baseSpeed,
    required this.burstMult,
    required this.tailFreq,
  });

  /// Resolves the exact procedural [FishStyle] for any [FishItem.id].
  static FishStyle forId(String id) {
    switch (id) {
      // --- 1. Guppy ×3 (Small body, huge patterned fan tail, lively) ---
      case 'guppy':
        return const FishStyle(
          species: FishSpecies.guppy,
          pattern: FishPattern.fanSpots,
          primary: Color(0xFFFF8A65),
          secondary: Color(0xFFFF3D00),
          accent: Color(0xFFFFEAA7),
          finColor: Color(0xFFFF5252),
          bellyColor: Color(0xFFFFF3E0),
          bodyLength: 11.5,
          bodyHeight: 4.8,
          baseSpeed: 38.0,
          burstMult: 1.55,
          tailFreq: 7.5,
        );
      case 'guppy_blue':
        return const FishStyle(
          species: FishSpecies.guppy,
          pattern: FishPattern.fanSpots,
          primary: Color(0xFF40C4FF),
          secondary: Color(0xFF01579B),
          accent: Color(0xFF80D8FF),
          finColor: Color(0xFF00B0FF),
          bellyColor: Color(0xFFE1F5FE),
          bodyLength: 11.5,
          bodyHeight: 4.8,
          baseSpeed: 38.0,
          burstMult: 1.55,
          tailFreq: 7.5,
        );
      case 'guppy_green':
        return const FishStyle(
          species: FishSpecies.guppy,
          pattern: FishPattern.fanSpots,
          primary: Color(0xFF69F0AE),
          secondary: Color(0xFF00695C),
          accent: Color(0xFFB9F6CA),
          finColor: Color(0xFF00E676),
          bellyColor: Color(0xFFE8F5E9),
          bodyLength: 11.5,
          bodyHeight: 4.8,
          baseSpeed: 38.0,
          burstMult: 1.55,
          tailFreq: 7.5,
        );

      // --- 2. Tetra ×3 (Sleek torpedo, glowing lateral neon stripe, schooling) ---
      case 'tetra':
        return const FishStyle(
          species: FishSpecies.tetra,
          pattern: FishPattern.neonStripe,
          primary: Color(0xFF1E88E5),
          secondary: Color(0xFFFF1744),
          accent: Color(0xFF00E5FF),
          finColor: Color(0x9980D8FF),
          bellyColor: Color(0xFFCFD8DC),
          bodyLength: 12.5,
          bodyHeight: 4.4,
          baseSpeed: 44.0,
          burstMult: 1.75,
          tailFreq: 8.2,
        );
      case 'tetra_gold':
        return const FishStyle(
          species: FishSpecies.tetra,
          pattern: FishPattern.neonStripe,
          primary: Color(0xFFFFB300),
          secondary: Color(0xFFFF1744),
          accent: Color(0xFFFFEA00),
          finColor: Color(0xAAFFD54F),
          bellyColor: Color(0xFFFFF8E1),
          bodyLength: 12.5,
          bodyHeight: 4.4,
          baseSpeed: 44.0,
          burstMult: 1.75,
          tailFreq: 8.2,
        );
      case 'tetra_purple':
        return const FishStyle(
          species: FishSpecies.tetra,
          pattern: FishPattern.neonStripe,
          primary: Color(0xFF8E24AA),
          secondary: Color(0xFF00E676),
          accent: Color(0xFFEA80FC),
          finColor: Color(0xAAB388FF),
          bellyColor: Color(0xFFF3E5F5),
          bodyLength: 12.5,
          bodyHeight: 4.4,
          baseSpeed: 44.0,
          burstMult: 1.75,
          tailFreq: 8.2,
        );

      // --- 3. Angelfish ×3 (Tall diamond body, long trailing dorsal/ventral fins) ---
      case 'angel':
        return const FishStyle(
          species: FishSpecies.angel,
          pattern: FishPattern.verticalBars,
          primary: Color(0xFFFFF176),
          secondary: Color(0xFFF57F17),
          accent: Color(0xFF3E2723),
          finColor: Color(0xFFFFD54F),
          bellyColor: Color(0xFFFFFDE7),
          bodyLength: 13.5,
          bodyHeight: 11.5,
          baseSpeed: 22.0,
          burstMult: 1.35,
          tailFreq: 4.2,
        );
      case 'angel_aqua':
        return const FishStyle(
          species: FishSpecies.angel,
          pattern: FishPattern.verticalBars,
          primary: Color(0xFF4DD0E1),
          secondary: Color(0xFF006064),
          accent: Color(0xFF00251A),
          finColor: Color(0xFF84FFFF),
          bellyColor: Color(0xFFE0F7FA),
          bodyLength: 13.5,
          bodyHeight: 11.5,
          baseSpeed: 22.0,
          burstMult: 1.35,
          tailFreq: 4.2,
        );
      case 'angel_ruby':
        return const FishStyle(
          species: FishSpecies.angel,
          pattern: FishPattern.verticalBars,
          primary: Color(0xFFFF5252),
          secondary: Color(0xFF880E4F),
          accent: Color(0xFF311B92),
          finColor: Color(0xFFFF8A80),
          bellyColor: Color(0xFFFFEBEE),
          bodyLength: 13.5,
          bodyHeight: 11.5,
          baseSpeed: 22.0,
          burstMult: 1.35,
          tailFreq: 4.2,
        );

      // --- 4. Betta ×3 (Compact body, lavish flowing veil tail & fins) ---
      case 'betta':
        return const FishStyle(
          species: FishSpecies.betta,
          pattern: FishPattern.iridescentVeil,
          primary: Color(0xFFD500F9),
          secondary: Color(0xFF4A148C),
          accent: Color(0xFF00E5FF),
          finColor: Color(0xFFFF4081),
          bellyColor: Color(0xFFF3E5F5),
          bodyLength: 12.0,
          bodyHeight: 5.2,
          baseSpeed: 24.0,
          burstMult: 1.85,
          tailFreq: 4.8,
        );
      case 'betta_blue':
        return const FishStyle(
          species: FishSpecies.betta,
          pattern: FishPattern.iridescentVeil,
          primary: Color(0xFF00B0FF),
          secondary: Color(0xFF1A237E),
          accent: Color(0xFFFF3D00),
          finColor: Color(0xFF18FFFF),
          bellyColor: Color(0xFFE1F5FE),
          bodyLength: 12.0,
          bodyHeight: 5.2,
          baseSpeed: 24.0,
          burstMult: 1.85,
          tailFreq: 4.8,
        );
      case 'betta_orange':
        return const FishStyle(
          species: FishSpecies.betta,
          pattern: FishPattern.iridescentVeil,
          primary: Color(0xFFFF6D00),
          secondary: Color(0xFFBF360C),
          accent: Color(0xFF00E676),
          finColor: Color(0xFFFFAB00),
          bellyColor: Color(0xFFFFF3E0),
          bodyLength: 12.0,
          bodyHeight: 5.2,
          baseSpeed: 24.0,
          burstMult: 1.85,
          tailFreq: 4.8,
        );

      // --- 5. Discus ×3 (Round regal disc body, turquoise/wave patterns) ---
      case 'discus':
        return const FishStyle(
          species: FishSpecies.discus,
          pattern: FishPattern.waveRipples,
          primary: Color(0xFFFF7043),
          secondary: Color(0xFFBF360C),
          accent: Color(0xFF00E5FF),
          finColor: Color(0xFF29B6F6),
          bellyColor: Color(0xFFFFCCBC),
          bodyLength: 14.5,
          bodyHeight: 13.0,
          baseSpeed: 21.0,
          burstMult: 1.30,
          tailFreq: 4.0,
        );
      case 'discus_blue':
        return const FishStyle(
          species: FishSpecies.discus,
          pattern: FishPattern.waveRipples,
          primary: Color(0xFF2979FF),
          secondary: Color(0xFF0D47A1),
          accent: Color(0xFF84FFFF),
          finColor: Color(0xFF00E5FF),
          bellyColor: Color(0xFFBBDEFB),
          bodyLength: 14.5,
          bodyHeight: 13.0,
          baseSpeed: 21.0,
          burstMult: 1.30,
          tailFreq: 4.0,
        );
      case 'discus_green':
        return const FishStyle(
          species: FishSpecies.discus,
          pattern: FishPattern.waveRipples,
          primary: Color(0xFF00C853),
          secondary: Color(0xFF1B5E20),
          accent: Color(0xFFFFEA00),
          finColor: Color(0xFF69F0AE),
          bellyColor: Color(0xFFC8E6C9),
          bodyLength: 14.5,
          bodyHeight: 13.0,
          baseSpeed: 21.0,
          burstMult: 1.30,
          tailFreq: 4.0,
        );

      // --- 6. Arowana ×3 (Long dragon body, metallic scales, barbels, surface cruiser) ---
      case 'arowana':
        return const FishStyle(
          species: FishSpecies.arowana,
          pattern: FishPattern.dragonScales,
          primary: Color(0xFFFFD54F),
          secondary: Color(0xFFFF8F00),
          accent: Color(0xFFFFF8E1),
          finColor: Color(0xFFFFB300),
          bellyColor: Color(0xFFFFECB3),
          bodyLength: 22.0,
          bodyHeight: 5.5,
          baseSpeed: 34.0,
          burstMult: 1.45,
          tailFreq: 4.6,
        );
      case 'arowana_red':
        return const FishStyle(
          species: FishSpecies.arowana,
          pattern: FishPattern.dragonScales,
          primary: Color(0xFFFF1744),
          secondary: Color(0xFF880E4F),
          accent: Color(0xFFFFD54F),
          finColor: Color(0xFFD50000),
          bellyColor: Color(0xFFFFCDD2),
          bodyLength: 22.0,
          bodyHeight: 5.5,
          baseSpeed: 34.0,
          burstMult: 1.45,
          tailFreq: 4.6,
        );
      case 'arowana_silver':
        return const FishStyle(
          species: FishSpecies.arowana,
          pattern: FishPattern.dragonScales,
          primary: Color(0xFFECEFF1),
          secondary: Color(0xFF607D8B),
          accent: Color(0xFF80D8FF),
          finColor: Color(0xFFB0BEC5),
          bellyColor: Color(0xFFFFFFFF),
          bodyLength: 22.0,
          bodyHeight: 5.5,
          baseSpeed: 34.0,
          burstMult: 1.45,
          tailFreq: 4.6,
        );

      // --- 7. Special Reef & Bottom Dwellers ---
      case 'shrimp':
        return const FishStyle(
          species: FishSpecies.shrimp,
          pattern: FishPattern.segmentedShell,
          primary: Color(0xFFFF5722),
          secondary: Color(0xFFBF360C),
          accent: Color(0xFFFFFFFF),
          finColor: Color(0xFFFF8A65),
          bellyColor: Color(0xFFFFCCBC),
          bodyLength: 12.0,
          bodyHeight: 4.2,
          baseSpeed: 28.0,
          burstMult: 2.2,
          tailFreq: 9.0,
        );
      case 'crab':
        return const FishStyle(
          species: FishSpecies.crab,
          pattern: FishPattern.carapaceMottle,
          primary: Color(0xFFFF5252),
          secondary: Color(0xFFB71C1C),
          accent: Color(0xFFFFCDD2),
          finColor: Color(0xFFD32F2F),
          bellyColor: Color(0xFFFFAB91),
          bodyLength: 12.0,
          bodyHeight: 8.5,
          baseSpeed: 30.0,
          burstMult: 1.4,
          tailFreq: 6.0,
        );
      case 'snail':
        return const FishStyle(
          species: FishSpecies.snail,
          pattern: FishPattern.spiralBands,
          primary: Color(0xFFFFCA28),
          secondary: Color(0xFF8D6E63),
          accent: Color(0xFF4E342E),
          finColor: Color(0xFFFFE082),
          bellyColor: Color(0xFFFFF8E1),
          bodyLength: 11.0,
          bodyHeight: 8.0,
          baseSpeed: 12.0,
          burstMult: 1.1,
          tailFreq: 2.5,
        );
      case 'jellyfish':
        return const FishStyle(
          species: FishSpecies.jellyfish,
          pattern: FishPattern.translucentRings,
          primary: Color(0xFFF48FB1),
          secondary: Color(0xFFAB47BC),
          accent: Color(0xFF80DEEA),
          finColor: Color(0xFFE1BEE7),
          bellyColor: Color(0xFFFCE4EC),
          bodyLength: 12.0,
          bodyHeight: 14.0,
          baseSpeed: 16.0,
          burstMult: 1.5,
          tailFreq: 3.0,
        );
      case 'octopus':
        return const FishStyle(
          species: FishSpecies.octopus,
          pattern: FishPattern.fanSpots,
          primary: Color(0xFFB388FF),
          secondary: Color(0xFF7E57C2),
          accent: Color(0xFF80DEEA),
          finColor: Color(0xFF9575CD),
          bellyColor: Color(0xFFEDE7F6),
          bodyLength: 15.0,
          bodyHeight: 15.0,
          baseSpeed: 26.0,
          burstMult: 1.8,
          tailFreq: 3.0,
        );
      default:
        return const FishStyle(
          species: FishSpecies.guppy,
          pattern: FishPattern.fanSpots,
          primary: Color(0xFFFF8A65),
          secondary: Color(0xFFFF3D00),
          accent: Color(0xFFFFEAA7),
          finColor: Color(0xFFFF5252),
          bellyColor: Color(0xFFFFF3E0),
          bodyLength: 11.5,
          bodyHeight: 4.8,
          baseSpeed: 36.0,
          burstMult: 1.5,
          tailFreq: 7.0,
        );
    }
  }
}

/// Procedural spine, fin, eye, mouth and locomotion rig for any fish / creature.
class FishRig {
  static const int spineJoints = 9;
  static const double minX = 35.0;
  static const double maxX = 375.0;
  static const double minY = 92.0;
  static const double maxY = 710.0;

  final String fishId;
  final FishStyle style;
  final Random rand;

  // World position & velocity
  double x;
  double y;
  double vx;
  double vy;
  bool facingRight;
  double pitch = 0.0;

  /// Smooth horizontal turn scale: +1.0 when facing right, -1.0 when facing left.
  /// Transitions smoothly through 0 during U-turns instead of snapping!
  double turnScale = 1.0;

  /// Extra body C-bend during a U-turn (-1..+1).
  double turnBend = 0.0;

  // Burst & glide cycle
  double _burstTimer = 1.2;
  double _burstBoost = 0.0; // 0 = gliding, 1 = active kick

  // Spine wave & fin phase
  double wavePhase = 0.0;
  double finPhase = 0.0;
  double tailAmp = 1.0;

  // Face & expression
  double lookX = 0.2;
  double lookY = 0.0;
  double blinkTimer = 2.5;
  double blink = 0.0; // >0 while blinking
  double mouthOpen = 0.0; // 0..1 opens when approaching food

  // Special creature states (shrimp dart, crab claw threat, jellyfish bell, snail wave)
  double specialTimer = 3.0;
  double specialActive = 0.0;
  double legPhase = 0.0;
  double bellPulse = 0.0;

  /// Spine joints in local body coordinates: index 0 = snout/head, index 8 = tail base.
  final List<Offset> spine = List<Offset>.filled(spineJoints, Offset.zero);

  /// Secondary trailing points for flowing fins / tentacles.
  final List<Offset> dorsalTrail = List<Offset>.filled(5, Offset.zero);
  final List<Offset> ventralTrail = List<Offset>.filled(5, Offset.zero);
  final List<List<Offset>> tentacles = List.generate(
    6,
    (_) => List<Offset>.filled(6, Offset.zero),
  );

  bool _spineReady = false;

  FishRig({
    required this.fishId,
    this.x = 200.0,
    this.y = 360.0,
    this.vx = 30.0,
    this.vy = 0.0,
    this.facingRight = true,
    Random? random,
  })  : style = FishStyle.forId(fishId),
        rand = random ?? Random() {
    turnScale = facingRight ? 1.0 : -1.0;
    wavePhase = rand.nextDouble() * pi * 2;
    finPhase = rand.nextDouble() * pi * 2;
    _burstTimer = 0.8 + rand.nextDouble() * 2.2;
    blinkTimer = 1.8 + rand.nextDouble() * 3.5;
    specialTimer = 2.5 + rand.nextDouble() * 3.5;
    _computeSpine(0.016, 0.0, snap: true);
  }

  double get speed => sqrt(vx * vx + vy * vy);

  /// Initiates a smooth U-turn toward [right].
  void faceToward(bool right) {
    if (facingRight != right) {
      facingRight = right;
      // Add an expressive C-bend kick when turning around
      turnBend = right ? 0.85 : -0.85;
      _burstBoost = max(_burstBoost, 0.7);
    }
  }

  /// Advances locomotion, burst-glide rhythm, schooling, face and spine kinematics.
  void step(
    double dt,
    double time, {
    Offset? target,
    bool isFoodTarget = false,
    bool isFingerTarget = false,
    bool satiated = false,
    bool isMovingOverride = true,
    List<FishRig>? peers,
  }) {
    // 1. Smooth U-turn interpolation
    final targetScale = facingRight ? 1.0 : -1.0;
    final turnRate = style.species == FishSpecies.tetra
        ? 11.0
        : (style.species == FishSpecies.angel || style.species == FishSpecies.discus ? 6.5 : 8.5);
    turnScale += (targetScale - turnScale) * min(1.0, dt * turnRate);
    turnBend *= exp(-dt * 5.5);

    // 2. Burst & glide rhythm
    _burstTimer -= dt;
    if (_burstTimer <= 0.0) {
      if (style.species == FishSpecies.betta) {
        // Betta pauses to flaunt its veil, then makes a graceful lunge
        _burstBoost = 1.0;
        _burstTimer = 1.6 + rand.nextDouble() * 2.2;
      } else if (style.species == FishSpecies.angel || style.species == FishSpecies.discus) {
        // Gentle slow glides
        _burstBoost = 0.65;
        _burstTimer = 2.0 + rand.nextDouble() * 2.4;
      } else if (style.species == FishSpecies.tetra || style.species == FishSpecies.guppy) {
        // Quick energetic kicks
        _burstBoost = 1.0;
        _burstTimer = 0.75 + rand.nextDouble() * 1.3;
      } else {
        _burstBoost = 0.8;
        _burstTimer = 1.4 + rand.nextDouble() * 1.8;
      }
    }
    final decayRate = style.species == FishSpecies.betta ? 2.4 : 1.9;
    _burstBoost *= exp(-dt * decayRate);

    // 3. Target / Ambient kinematics for swimming species
    _updateFaceAndMouth(dt, time, target, isFoodTarget);

    // Advance wave and fin phases proportional to current speed & burst
    final spdRatio = (speed / max(12.0, style.baseSpeed)).clamp(0.35, 2.4);
    final freq = style.tailFreq * (0.65 + 0.55 * spdRatio + 0.45 * _burstBoost);
    wavePhase += dt * freq;
    finPhase += dt * (4.2 + 2.5 * spdRatio);

    if (isMovingOverride) {
      legPhase += dt * (style.species == FishSpecies.crab ? 11.0 : 8.0);
    }

    // Special creature timers
    if (style.species == FishSpecies.jellyfish) {
      bellPulse = sin(time * 2.2 + finPhase);
    } else if (style.species == FishSpecies.crab) {
      specialTimer -= dt;
      if (specialTimer <= 0.0) {
        specialActive = 0.75; // Claw threat raise!
        specialTimer = 3.2 + rand.nextDouble() * 4.0;
      }
      if (specialActive > 0.0) specialActive = max(0.0, specialActive - dt);
    }

    // Tail amplitude responds to burst, turn bend, and speed
    final targetAmp = (0.55 + 0.45 * spdRatio + 0.5 * _burstBoost + turnBend.abs() * 0.6).clamp(0.4, 2.1);
    tailAmp += (targetAmp - tailAmp) * min(1.0, dt * 8.0);

    _computeSpine(dt, time, snap: !_spineReady);
  }

  /// Computes theburst-glide speed multiplier at the current instant.
  double get currentSwimSpeedMultiplier {
    if (style.species == FishSpecies.betta) {
      // Betta hovers softly then surges
      return 0.42 + _burstBoost * style.burstMult;
    }
    if (style.species == FishSpecies.angel || style.species == FishSpecies.discus) {
      return 0.78 + _burstBoost * (style.burstMult - 0.65);
    }
    return 0.72 + _burstBoost * (style.burstMult - 0.65);
  }

  void _updateFaceAndMouth(double dt, double time, Offset? target, bool isFoodTarget) {
    double tx = 0.28;
    double ty = 0.0;
    double targetMouth = 0.0;

    if (target != null) {
      final dx = target.dx - x;
      final dy = target.dy - y;
      final d = max(1.0, sqrt(dx * dx + dy * dy));
      final localDx = facingRight ? dx : -dx;
      tx = (localDx / d).clamp(-0.6, 0.9);
      ty = (dy / d).clamp(-0.7, 0.7);

      if (isFoodTarget && d < 68.0) {
        // Open mouth eagerly as the fish closes in on a food pellet!
        targetMouth = ((68.0 - d) / 48.0).clamp(0.0, 1.0) *
            (0.65 + 0.35 * sin(time * 16.0));
      }
    } else {
      tx = 0.25 + sin(time * 0.8 + finPhase) * 0.25;
      ty = sin(time * 0.55 + finPhase) * 0.22;
    }

    lookX += (tx - lookX) * min(1.0, dt * 7.0);
    lookY += (ty - lookY) * min(1.0, dt * 7.0);
    mouthOpen += (targetMouth - mouthOpen) * min(1.0, dt * 12.0);

    blinkTimer -= dt;
    if (blinkTimer <= 0.0) {
      blink = 0.14;
      blinkTimer = 2.4 + rand.nextDouble() * 4.5;
    }
    if (blink > 0.0) {
      blink = max(0.0, blink - dt);
    }
  }

  void _computeSpine(double dt, double time, {bool snap = false}) {
    final len = style.bodyLength;
    for (int i = 0; i < spineJoints; i++) {
      final s = i / (spineJoints - 1); // 0 at head/snout, 1 at tail root
      final lx = len * (1.0 - 2.0 * s);

      // Lateral wave grows quadratically from head (0) toward tail (1)
      final env = s * s;
      final wave = sin(wavePhase - s * 3.4) * (style.bodyHeight * 0.34) * env * tailAmp;
      final bend = sin(s * pi) * turnBend * (style.bodyHeight * 0.55);

      var ly = wave + bend;
      if (style.species == FishSpecies.shrimp && specialActive > 0) {
        // Shrimp tail-snap curl
        ly += sin(s * pi) * 4.5;
      }

      spine[i] = Offset(lx, ly);
    }

    // Update secondary trailing fin chains (used by Angel, Betta, Jellyfish)
    for (int k = 0; k < dorsalTrail.length; k++) {
      final u = k / (dorsalTrail.length - 1);
      final target = Offset(
        -style.bodyLength * (0.2 + u * 0.95),
        -style.bodyHeight * (0.95 + u * 0.85) +
            sin(wavePhase - u * 2.6) * (2.5 + u * 4.0) * tailAmp,
      );
      if (snap || k == 0) {
        dorsalTrail[k] = target;
      } else {
        final a = 1.0 - exp(-dt * (20.0 - k * 2.5));
        dorsalTrail[k] = Offset.lerp(dorsalTrail[k], target, a)!;
      }
    }

    for (int k = 0; k < ventralTrail.length; k++) {
      final u = k / (ventralTrail.length - 1);
      final target = Offset(
        -style.bodyLength * (0.15 + u * 0.95),
        style.bodyHeight * (0.95 + u * 0.90) +
            sin(wavePhase - u * 2.6 + 0.5) * (2.5 + u * 4.0) * tailAmp,
      );
      if (snap || k == 0) {
        ventralTrail[k] = target;
      } else {
        final a = 1.0 - exp(-dt * (20.0 - k * 2.5));
        ventralTrail[k] = Offset.lerp(ventralTrail[k], target, a)!;
      }
    }

    // Update jellyfish tentacles
    if (style.species == FishSpecies.jellyfish) {
      for (int t = 0; t < tentacles.length; t++) {
        final chain = tentacles[t];
        final rootX = -8.0 + t * (16.0 / (tentacles.length - 1));
        for (int k = 0; k < chain.length; k++) {
          final s = k / (chain.length - 1);
          final sway = sin(time * 2.6 + t * 0.9 - s * 3.2) * (3.5 * s);
          final squeeze = bellPulse * 2.2 * (1.0 - s);
          final target = Offset(
            rootX * (1.0 - s * 0.15) + sway + (rootX > 0 ? -squeeze : squeeze) * 0.25,
            3.0 + s * 22.0 - bellPulse * 1.8 * s,
          );
          if (snap || k == 0) {
            chain[k] = target;
          } else {
            final a = 1.0 - exp(-dt * (18.0 - k * 2.0));
            chain[k] = Offset.lerp(chain[k], target, a)!;
          }
        }
      }
    }

    _spineReady = true;
  }
}

/// Renders any [FishRig] procedurally on a [Canvas].
class FishPainter {
  FishPainter._();

  static final Paint _fill = Paint()..style = PaintingStyle.fill;
  static final Paint _stroke = Paint()
    ..style = PaintingStyle.stroke
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round;

  static Color _mix(Color a, Color b, double t) => Color.lerp(a, b, t)!;

  /// Paints the procedural creature in its local coordinate frame
  /// (origin = body centre, snout facing +X, +Y = down).
  static void paint(Canvas c, FishRig r, double time) {
    switch (r.style.species) {
      case FishSpecies.guppy:
      case FishSpecies.tetra:
      case FishSpecies.angel:
      case FishSpecies.betta:
      case FishSpecies.discus:
      case FishSpecies.arowana:
        _paintSpineFish(c, r, time);
        break;
      case FishSpecies.shrimp:
        _paintShrimp(c, r, time);
        break;
      case FishSpecies.crab:
        _paintCrab(c, r, time);
        break;
      case FishSpecies.snail:
        _paintSnail(c, r, time);
        break;
      case FishSpecies.jellyfish:
        _paintJellyfish(c, r, time);
        break;
      case FishSpecies.octopus:
        final oct = OctopusRig(Random(7));
        oct.x = 200.0;
        oct.y = 726.0;
        oct.step(0.016, time, floorY: 726.0, hungry: false);
        OctopusPainter.paint(c, oct, time, r.style.primary);
        break;
    }
  }

  // ===========================================================================
  // 1..6: SPINE-BASED SWIMMING FISH (Guppy, Tetra, Angel, Betta, Discus, Arowana)
  // ===========================================================================

  static double _halfHeightProfile(FishSpecies sp, double s, double maxH) {
    // s = 0 at snout, s = 1 at caudal peduncle (tail root)
    switch (sp) {
      case FishSpecies.guppy:
        return maxH * sin(pow(s, 0.75) * pi) * (1.0 - 0.35 * s) + 1.1 * (1.0 - s * 0.3);
      case FishSpecies.tetra:
        return maxH * sin(pow(s, 0.72) * pi) * (1.0 - 0.30 * s) + 1.0;
      case FishSpecies.angel:
        // Steep diamond peak near the middle-front
        final peak = sin(pow(s, 0.68) * pi);
        return maxH * pow(peak, 0.85) * (1.0 - 0.25 * s) + 1.2;
      case FishSpecies.betta:
        return maxH * sin(pow(s, 0.70) * pi) * (1.0 - 0.22 * s) + 1.3;
      case FishSpecies.discus:
        // Full circular/oval disc silhouette
        final disc = sqrt(max(0.0, 1.0 - pow(s * 2.0 - 0.96, 2)));
        return maxH * disc * 0.95 + 1.4;
      case FishSpecies.arowana:
        // Long sleek dragon body, flat back, muscular tail stock
        final body = sin(pow(s, 0.62) * pi);
        return maxH * (0.28 + 0.72 * body) * (1.0 - 0.18 * s) + 1.2;
      default:
        return maxH * sin(s * pi) + 1.0;
    }
  }

  static void _paintSpineFish(Canvas c, FishRig r, double time) {
    final st = r.style;
    final sp = st.species;
    final n = FishRig.spineJoints;

    // Apply smooth horizontal turn scaling (with slight perspective thickness so 0 never vanishes)
    c.save();
    final sx = r.turnScale.abs() < 0.14 ? (r.turnScale >= 0 ? 0.14 : -0.14) : r.turnScale;
    c.scale(sx, 1.0);

    // Compute upper (dorsal) and lower (ventral) outline points along the spine
    final topPts = <Offset>[];
    final botPts = <Offset>[];
    for (int i = 0; i < n; i++) {
      final s = i / (n - 1);
      final p = r.spine[i];
      final a = r.spine[max(0, i - 1)];
      final b = r.spine[min(n - 1, i + 1)];
      var tx = b.dx - a.dx;
      var ty = b.dy - a.dy;
      final d = max(0.0001, sqrt(tx * tx + ty * ty));
      tx /= d;
      ty /= d;
      // Normal pointing upward (-Y in local space when swimming along +X)
      final nx = -ty;
      final ny = tx;

      final hh = _halfHeightProfile(sp, s, st.bodyHeight);
      // Slight asymmetry for Arowana (flatter dorsal back, deeper belly) and Angel
      final topH = sp == FishSpecies.arowana ? hh * 0.78 : hh;
      final botH = sp == FishSpecies.arowana ? hh * 1.18 : hh;

      topPts.add(Offset(p.dx + nx * topH, p.dy - ny.abs() * topH));
      botPts.add(Offset(p.dx - nx * botH, p.dy + ny.abs() * botH));
    }

    // 1. Draw Caudal (Tail) Fin behind body
    _drawTailFin(c, r, time, r.spine[n - 1], r.spine[n - 2]);

    // 2. Draw Dorsal & Ventral / Anal Fins behind body
    _drawDorsalAndVentralFins(c, r, time, topPts, botPts);

    // 3. Build & fill the main body contour
    final bodyPath = Path();
    final snout = r.spine[0] + const Offset(2.2, 0.2);
    bodyPath.moveTo(snout.dx, snout.dy);
    for (int i = 0; i < n; i++) {
      bodyPath.lineTo(topPts[i].dx, topPts[i].dy);
    }
    for (int i = n - 1; i >= 0; i--) {
      bodyPath.lineTo(botPts[i].dx, botPts[i].dy);
    }
    bodyPath.close();

    final dark = _mix(st.primary, st.secondary, 0.65);
    final light = _mix(st.primary, Colors.white, 0.32);
    final bounds = Rect.fromCenter(
      center: Offset.zero,
      width: st.bodyLength * 2.4,
      height: st.bodyHeight * 2.4,
    );
    _fill.shader = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [dark, st.primary, st.bellyColor],
      stops: const [0.0, 0.58, 1.0],
    ).createShader(bounds);
    c.drawPath(bodyPath, _fill);
    _fill.shader = null;

    // 4. Clipped body patterns (stripes, scales, bars, waves)
    c.save();
    c.clipPath(bodyPath);
    _drawBodyPattern(c, r, time, topPts, botPts, light, dark);

    // Glossy dorsal highlight
    _fill.color = Colors.white.withValues(alpha: 0.24);
    final glossPath = Path()..moveTo(snout.dx - 1.0, snout.dy - 0.5);
    for (int i = 0; i < n - 2; i++) {
      glossPath.lineTo(topPts[i].dx, topPts[i].dy + 0.6);
    }
    for (int i = n - 3; i >= 0; i--) {
      glossPath.lineTo(
        topPts[i].dx,
        topPts[i].dy + (botPts[i].dy - topPts[i].dy) * 0.28,
      );
    }
    glossPath.close();
    c.drawPath(glossPath, _fill);
    c.restore();

    // 5. Gill cover (operculum) & Arowana barbels + mouth
    _drawHeadDetails(c, r, time, snout);

    // 6. Pectoral (side) fin with independent delayed flutter
    _drawPectoralFin(c, r, time);

    // 7. Expressive eye (follows target + blinks)
    _drawFishEye(c, r, snout);

    c.restore();
  }

  static void _drawTailFin(Canvas c, FishRig r, double time, Offset tailRoot, Offset prevJoint) {
    final st = r.style;
    final sp = st.species;
    final wag = sin(r.wavePhase - 2.9) * r.tailAmp;
    final wag2 = cos(r.wavePhase - 3.3) * r.tailAmp;

    final path = Path()..moveTo(tailRoot.dx + 1.0, tailRoot.dy);

    switch (sp) {
      case FishSpecies.guppy:
        // Large showy delta fan tail with spots/stripes
        final fanLen = 14.5;
        final fanSpread = 11.0;
        final tipTop = Offset(tailRoot.dx - fanLen, tailRoot.dy - fanSpread + wag * 4.5);
        final tipMid = Offset(tailRoot.dx - fanLen * 1.12, tailRoot.dy + wag * 5.2 + wag2 * 1.5);
        final tipBot = Offset(tailRoot.dx - fanLen, tailRoot.dy + fanSpread + wag * 4.5);
        path.quadraticBezierTo(
          tailRoot.dx - fanLen * 0.45,
          tailRoot.dy - fanSpread * 0.65 + wag * 2.0,
          tipTop.dx,
          tipTop.dy,
        );
        path.quadraticBezierTo(
          tipMid.dx - 1.5,
          tipMid.dy,
          tipBot.dx,
          tipBot.dy,
        );
        path.quadraticBezierTo(
          tailRoot.dx - fanLen * 0.45,
          tailRoot.dy + fanSpread * 0.65 + wag * 2.0,
          tailRoot.dx + 1.0,
          tailRoot.dy,
        );
        path.close();

        _fill.shader = RadialGradient(
          center: const Alignment(0.6, 0.0),
          radius: 1.1,
          colors: [
            st.primary,
            st.finColor,
            st.secondary.withValues(alpha: 0.85),
          ],
        ).createShader(Rect.fromCircle(center: tailRoot, radius: fanLen));
        c.drawPath(path, _fill);
        _fill.shader = null;

        // Fan tail spots & rays
        _fill.color = st.accent.withValues(alpha: 0.85);
        for (int i = -2; i <= 2; i++) {
          final spotPos = Offset(
            tailRoot.dx - 8.5 - (i.abs() * 0.6),
            tailRoot.dy + i * 3.1 + wag * 3.6,
          );
          c.drawCircle(spotPos, 1.35, _fill);
        }
        _stroke
          ..color = st.secondary.withValues(alpha: 0.45)
          ..strokeWidth = 0.7;
        for (int i = -3; i <= 3; i++) {
          c.drawLine(
            tailRoot,
            Offset(tailRoot.dx - fanLen * 0.92, tailRoot.dy + i * 2.6 + wag * 4.2),
            _stroke,
          );
        }
        break;

      case FishSpecies.tetra:
        // Crisp forked torpedo tail
        const forkLen = 8.5;
        const spread = 6.2;
        final topTip = Offset(tailRoot.dx - forkLen, tailRoot.dy - spread + wag * 3.0);
        final notch = Offset(tailRoot.dx - forkLen * 0.48, tailRoot.dy + wag * 2.2);
        final botTip = Offset(tailRoot.dx - forkLen, tailRoot.dy + spread + wag * 3.0);
        path
          ..lineTo(topTip.dx, topTip.dy)
          ..lineTo(notch.dx, notch.dy)
          ..lineTo(botTip.dx, botTip.dy)
          ..close();
        _fill.color = st.finColor;
        c.drawPath(path, _fill);
        _fill.color = st.secondary.withValues(alpha: 0.75);
        c.drawCircle(Offset(tailRoot.dx - 2.0, tailRoot.dy + wag * 0.8), 1.8, _fill);
        break;

      case FishSpecies.angel:
        // Lyretail with delicate trailing filaments
        const len = 11.0;
        const spread = 8.5;
        final topTip = Offset(tailRoot.dx - len * 1.35, tailRoot.dy - spread * 1.2 + wag * 3.8);
        final notch = Offset(tailRoot.dx - len * 0.65, tailRoot.dy + wag * 2.5);
        final botTip = Offset(tailRoot.dx - len * 1.35, tailRoot.dy + spread * 1.2 + wag * 3.8);
        path
          ..quadraticBezierTo(tailRoot.dx - 5, tailRoot.dy - spread * 0.8, topTip.dx, topTip.dy)
          ..quadraticBezierTo(notch.dx, notch.dy - 2, notch.dx, notch.dy)
          ..quadraticBezierTo(notch.dx, notch.dy + 2, botTip.dx, botTip.dy)
          ..quadraticBezierTo(tailRoot.dx - 5, tailRoot.dy + spread * 0.8, tailRoot.dx + 1.0, tailRoot.dy)
          ..close();
        _fill.color = st.finColor.withValues(alpha: 0.78);
        c.drawPath(path, _fill);
        break;

      case FishSpecies.betta:
        // Extravagant halfmoon / veil tail with ruffled multi-layered ribbon rays
        const veilLen = 19.5;
        const veilSpread = 15.5;
        final top = Offset(tailRoot.dx - veilLen * 0.85, tailRoot.dy - veilSpread + wag * 5.0);
        final mid = Offset(tailRoot.dx - veilLen * 1.08, tailRoot.dy + wag * 6.5 + wag2 * 2.5);
        final bot = Offset(tailRoot.dx - veilLen * 0.85, tailRoot.dy + veilSpread + wag * 5.0);
        path
          ..cubicTo(
            tailRoot.dx - 4.0,
            tailRoot.dy - veilSpread * 0.9,
            top.dx + 3.0,
            top.dy - 2.0,
            top.dx,
            top.dy,
          )
          ..cubicTo(
            mid.dx - 2.0,
            top.dy + 4.0,
            mid.dx - 2.0,
            bot.dy - 4.0,
            bot.dx,
            bot.dy,
          )
          ..cubicTo(
            bot.dx + 3.0,
            bot.dy + 2.0,
            tailRoot.dx - 4.0,
            tailRoot.dy + veilSpread * 0.9,
            tailRoot.dx + 1.0,
            tailRoot.dy,
          )
          ..close();

        _fill.shader = RadialGradient(
          center: const Alignment(0.55, 0.0),
          radius: 1.15,
          colors: [
            st.secondary,
            st.primary,
            st.finColor,
            st.accent.withValues(alpha: 0.9),
          ],
          stops: const [0.0, 0.42, 0.78, 1.0],
        ).createShader(Rect.fromCircle(center: tailRoot, radius: veilLen));
        c.drawPath(path, _fill);
        _fill.shader = null;

        // Iridescent fin rays
        _stroke
          ..color = st.accent.withValues(alpha: 0.55)
          ..strokeWidth = 0.85;
        for (int i = -4; i <= 4; i++) {
          final a = i * 0.24;
          final rLen = veilLen * (0.95 - (i.abs() * 0.03));
          final rx = tailRoot.dx - cos(a) * rLen;
          final ry = tailRoot.dy + sin(a) * veilSpread * 0.95 + wag * 5.2;
          c.drawLine(tailRoot, Offset(rx, ry), _stroke);
        }
        break;

      case FishSpecies.discus:
        // Broad rounded fan paddle tail
        const len = 8.5;
        const spread = 6.5;
        path
          ..quadraticBezierTo(
            tailRoot.dx - len,
            tailRoot.dy - spread + wag * 2.5,
            tailRoot.dx - len,
            tailRoot.dy + wag * 2.8,
          )
          ..quadraticBezierTo(
            tailRoot.dx - len,
            tailRoot.dy + spread + wag * 2.5,
            tailRoot.dx + 1.0,
            tailRoot.dy,
          )
          ..close();
        _fill.color = st.finColor.withValues(alpha: 0.85);
        c.drawPath(path, _fill);
        break;

      case FishSpecies.arowana:
        // Spear-shaped dragon tail that merges seamlessly with dorsal/anal fins
        const len = 11.5;
        const spread = 6.8;
        final tip = Offset(tailRoot.dx - len, tailRoot.dy + wag * 3.8);
        path
          ..quadraticBezierTo(
            tailRoot.dx - len * 0.55,
            tailRoot.dy - spread + wag * 2.0,
            tip.dx,
            tip.dy,
          )
          ..quadraticBezierTo(
            tailRoot.dx - len * 0.55,
            tailRoot.dy + spread + wag * 2.0,
            tailRoot.dx + 1.5,
            tailRoot.dy,
          )
          ..close();
        _fill.shader = LinearGradient(
          colors: [st.secondary, st.finColor, st.accent],
        ).createShader(Rect.fromCircle(center: tailRoot, radius: len));
        c.drawPath(path, _fill);
        _fill.shader = null;
        break;

      default:
        break;
    }
  }

  static void _drawDorsalAndVentralFins(
    Canvas c,
    FishRig r,
    double time,
    List<Offset> topPts,
    List<Offset> botPts,
  ) {
    final st = r.style;
    final sp = st.species;
    final sway = sin(r.finPhase - 1.1) * 1.8 * r.tailAmp;

    switch (sp) {
      case FishSpecies.angel:
        // Iconic tall sweeping sickle dorsal & ventral fins using trailing chain
        final dRoot1 = topPts[2];
        final dRoot2 = topPts[5];
        final dTip = r.dorsalTrail.last;
        final dMid = r.dorsalTrail[2];
        final dPath = Path()
          ..moveTo(dRoot1.dx, dRoot1.dy + 1.0)
          ..quadraticBezierTo(dMid.dx + 4.0, dMid.dy, dTip.dx, dTip.dy)
          ..quadraticBezierTo(dMid.dx - 2.0, dMid.dy + 4.0, dRoot2.dx, dRoot2.dy + 1.0)
          ..close();
        _fill.color = st.finColor.withValues(alpha: 0.88);
        c.drawPath(dPath, _fill);

        final vRoot1 = botPts[2];
        final vRoot2 = botPts[6];
        final vTip = r.ventralTrail.last;
        final vMid = r.ventralTrail[2];
        final vPath = Path()
          ..moveTo(vRoot1.dx, vRoot1.dy - 1.0)
          ..quadraticBezierTo(vMid.dx + 4.0, vMid.dy, vTip.dx, vTip.dy)
          ..quadraticBezierTo(vMid.dx - 2.0, vMid.dy - 4.0, vRoot2.dx, vRoot2.dy - 1.0)
          ..close();
        c.drawPath(vPath, _fill);

        // Long feeler pelvic threads under the chest
        _stroke
          ..color = st.bellyColor.withValues(alpha: 0.85)
          ..strokeWidth = 1.0;
        final chest = botPts[1];
        final threadPath = Path()
          ..moveTo(chest.dx, chest.dy - 0.5)
          ..quadraticBezierTo(
            chest.dx - 4.0,
            chest.dy + 9.0,
            chest.dx - 11.0 + sway,
            chest.dy + 15.0,
          );
        c.drawPath(threadPath, _stroke);
        break;

      case FishSpecies.betta:
        // Lavish flowing dorsal & anal curtain fins
        final dPath = Path()
          ..moveTo(topPts[2].dx, topPts[2].dy + 0.8)
          ..cubicTo(
            topPts[3].dx + 2.0,
            topPts[3].dy - 9.5 + sway,
            topPts[6].dx - 6.0,
            topPts[6].dy - 11.0 - sway,
            topPts[7].dx - 7.0,
            topPts[7].dy - 3.0 + sway,
          )
          ..lineTo(topPts[7].dx, topPts[7].dy + 0.8)
          ..close();
        _fill.color = st.finColor.withValues(alpha: 0.86);
        c.drawPath(dPath, _fill);

        final vPath = Path()
          ..moveTo(botPts[2].dx, botPts[2].dy - 0.8)
          ..cubicTo(
            botPts[3].dx + 1.0,
            botPts[3].dy + 11.0 + sway,
            botPts[6].dx - 7.0,
            botPts[6].dy + 13.0 - sway,
            botPts[7].dx - 8.0,
            botPts[7].dy + 4.0 + sway,
          )
          ..lineTo(botPts[7].dx, botPts[7].dy - 0.8)
          ..close();
        _fill.color = _mix(st.finColor, st.secondary, 0.3).withValues(alpha: 0.88);
        c.drawPath(vPath, _fill);
        break;

      case FishSpecies.discus:
        // Continuous rounded dorsal & anal crest wrapping the disc
        final dPath = Path()
          ..moveTo(topPts[1].dx, topPts[1].dy + 1.0)
          ..quadraticBezierTo(
            topPts[4].dx - 2.0,
            topPts[4].dy - 6.5 + sway * 0.5,
            topPts[7].dx - 2.0,
            topPts[7].dy - 2.2,
          )
          ..lineTo(topPts[7].dx, topPts[7].dy + 1.0)
          ..close();
        _fill.color = st.finColor.withValues(alpha: 0.85);
        c.drawPath(dPath, _fill);

        final vPath = Path()
          ..moveTo(botPts[1].dx, botPts[1].dy - 1.0)
          ..quadraticBezierTo(
            botPts[4].dx - 2.0,
            botPts[4].dy + 6.5 + sway * 0.5,
            botPts[7].dx - 2.0,
            botPts[7].dy + 2.2,
          )
          ..lineTo(botPts[7].dx, botPts[7].dy - 1.0)
          ..close();
        c.drawPath(vPath, _fill);
        break;

      case FishSpecies.arowana:
        // Posterior ribbon dorsal & anal fins sweeping back toward the tail
        final dPath = Path()
          ..moveTo(topPts[4].dx, topPts[4].dy + 0.8)
          ..quadraticBezierTo(
            topPts[6].dx - 2.0,
            topPts[6].dy - 5.2 + sway * 0.6,
            topPts[8].dx - 3.0,
            topPts[8].dy - 3.5 + sway,
          )
          ..lineTo(topPts[8].dx, topPts[8].dy + 0.8)
          ..close();
        _fill.color = st.finColor.withValues(alpha: 0.9);
        c.drawPath(dPath, _fill);

        final vPath = Path()
          ..moveTo(botPts[3].dx, botPts[3].dy - 0.8)
          ..quadraticBezierTo(
            botPts[6].dx - 2.0,
            botPts[6].dy + 5.8 + sway * 0.6,
            botPts[8].dx - 3.0,
            botPts[8].dy + 3.8 + sway,
          )
          ..lineTo(botPts[8].dx, botPts[8].dy - 0.8)
          ..close();
        c.drawPath(vPath, _fill);
        break;

      case FishSpecies.guppy:
      case FishSpecies.tetra:
      default:
        // Neat dorsal flag & small anal fin
        final dPath = Path()
          ..moveTo(topPts[2].dx, topPts[2].dy + 0.6)
          ..quadraticBezierTo(
            topPts[3].dx - 2.5,
            topPts[3].dy - 4.8 + sway * 0.6,
            topPts[5].dx - 2.0,
            topPts[5].dy - 2.2 + sway,
          )
          ..lineTo(topPts[5].dx, topPts[5].dy + 0.6)
          ..close();
        _fill.color = st.finColor.withValues(alpha: 0.82);
        c.drawPath(dPath, _fill);

        final vPath = Path()
          ..moveTo(botPts[4].dx, botPts[4].dy - 0.6)
          ..quadraticBezierTo(
            botPts[5].dx - 1.5,
            botPts[5].dy + 3.6 + sway * 0.5,
            botPts[6].dx - 1.5,
            botPts[6].dy + 1.5,
          )
          ..lineTo(botPts[6].dx, botPts[6].dy - 0.6)
          ..close();
        c.drawPath(vPath, _fill);
        break;
    }
  }

  static void _drawBodyPattern(
    Canvas c,
    FishRig r,
    double time,
    List<Offset> topPts,
    List<Offset> botPts,
    Color light,
    Color dark,
  ) {
    final st = r.style;
    final n = FishRig.spineJoints;

    switch (st.pattern) {
      case FishPattern.neonStripe:
        // Tetra: brilliant glowing neon lateral stripe + crimson posterior belly patch
        final bellyPatch = Path()..moveTo(r.spine[3].dx, r.spine[3].dy);
        for (int i = 3; i < n; i++) {
          bellyPatch.lineTo(r.spine[i].dx, r.spine[i].dy);
        }
        for (int i = n - 1; i >= 3; i--) {
          bellyPatch.lineTo(botPts[i].dx, botPts[i].dy);
        }
        bellyPatch.close();
        _fill.color = st.secondary.withValues(alpha: 0.85);
        c.drawPath(bellyPatch, _fill);

        final stripe = Path()..moveTo(r.spine[1].dx, r.spine[1].dy - 0.5);
        for (int i = 2; i < n - 1; i++) {
          stripe.lineTo(r.spine[i].dx, r.spine[i].dy - 0.6);
        }
        _stroke
          ..color = st.accent.withValues(alpha: 0.45)
          ..strokeWidth = 3.2;
        c.drawPath(stripe, _stroke);
        _stroke
          ..color = st.accent
          ..strokeWidth = 1.45;
        c.drawPath(stripe, _stroke);
        break;

      case FishPattern.verticalBars:
        // Angelfish: bold dark vertical zebra bars across the diamond body
        _stroke
          ..color = st.accent.withValues(alpha: 0.55)
          ..strokeWidth = 2.2;
        for (final idx in [2, 4, 6]) {
          final pTop = topPts[idx];
          final pMid = r.spine[idx];
          final pBot = botPts[idx];
          final bar = Path()
            ..moveTo(pTop.dx, pTop.dy - 2.0)
            ..quadraticBezierTo(pMid.dx - 1.2, pMid.dy, pBot.dx, pBot.dy + 2.0);
          c.drawPath(bar, _stroke);
        }
        break;

      case FishPattern.waveRipples:
        // Discus: neon turquoise vermiculated wave stripes along the round body
        _stroke
          ..color = st.accent.withValues(alpha: 0.62)
          ..strokeWidth = 1.25;
        for (int row = -2; row <= 2; row++) {
          final wave = Path();
          for (int i = 1; i < n - 1; i++) {
            final p = r.spine[i];
            final wy = p.dy + row * 3.2 + sin(i * 1.4 + row) * 0.9;
            if (i == 1) {
              wave.moveTo(p.dx, wy);
            } else {
              wave.lineTo(p.dx, wy);
            }
          }
          c.drawPath(wave, _stroke);
        }
        break;

      case FishPattern.dragonScales:
        // Arowana: large metallic crescent scales in 3 rows
        _stroke
          ..color = st.accent.withValues(alpha: 0.65)
          ..strokeWidth = 0.9;
        _fill.color = st.secondary.withValues(alpha: 0.35);
        for (int i = 1; i < n - 1; i++) {
          final p = r.spine[i];
          for (final dy in [-2.2, 0.0, 2.2]) {
            final scRect = Rect.fromCenter(
              center: Offset(p.dx, p.dy + dy),
              width: 3.8,
              height: 2.6,
            );
            c.drawArc(scRect, pi * 0.55, pi * 0.9, false, _stroke);
          }
        }
        break;

      case FishPattern.iridescentVeil:
        // Betta: metallic shimmer dots along the flank
        _fill.color = st.accent.withValues(alpha: 0.5);
        for (int i = 2; i < n - 1; i++) {
          final p = r.spine[i];
          c.drawCircle(Offset(p.dx, p.dy - 0.8), 1.1, _fill);
          c.drawCircle(Offset(p.dx - 1.2, p.dy + 1.0), 0.9, _fill);
        }
        break;

      case FishPattern.fanSpots:
      default:
        // Guppy: colourful flank spots near the tail peduncle
        _fill.color = st.secondary.withValues(alpha: 0.65);
        c.drawCircle(r.spine[4] + const Offset(0, -0.5), 1.6, _fill);
        _fill.color = st.accent.withValues(alpha: 0.75);
        c.drawCircle(r.spine[6] + const Offset(0, 0.4), 1.3, _fill);
        break;
    }
  }

  static void _drawHeadDetails(Canvas c, FishRig r, double time, Offset snout) {
    final st = r.style;
    final head = r.spine[1];

    // Subtle gill arch (operculum)
    _stroke
      ..color = st.secondary.withValues(alpha: 0.55)
      ..strokeWidth = 1.0;
    c.drawArc(
      Rect.fromCenter(center: Offset(head.dx - 1.2, head.dy + 0.3), width: 4.5, height: 6.5),
      -pi * 0.38,
      pi * 0.76,
      false,
      _stroke,
    );

    // Mouth (opens when approaching a food pellet!)
    final mouthY = snout.dy + 0.9;
    if (r.mouthOpen > 0.05) {
      _fill.color = const Color(0xFF260E14);
      c.drawOval(
        Rect.fromCenter(
          center: Offset(snout.dx - 0.4, mouthY),
          width: 2.2,
          height: 1.0 + r.mouthOpen * 2.4,
        ),
        _fill,
      );
    } else {
      _stroke
        ..color = st.secondary.withValues(alpha: 0.7)
        ..strokeWidth = 0.85;
      c.drawLine(
        Offset(snout.dx, mouthY),
        Offset(snout.dx - 1.8, mouthY + 0.4),
        _stroke,
      );
    }

    // Dragon Arowana twin sensory barbels protruding delicately from the lower jaw tip
    if (st.species == FishSpecies.arowana) {
      final sway = sin(time * 5.0 + r.finPhase) * 0.6;
      _stroke
        ..color = st.finColor
        ..strokeWidth = 0.75;
      final b1 = Path()
        ..moveTo(snout.dx - 0.1, mouthY + 0.2)
        ..quadraticBezierTo(snout.dx + 2.2, mouthY + 0.9, snout.dx + 4.4, mouthY + 1.8 + sway);
      final b2 = Path()
        ..moveTo(snout.dx - 0.4, mouthY + 0.4)
        ..quadraticBezierTo(snout.dx + 1.8, mouthY + 1.5, snout.dx + 3.8, mouthY + 2.7 - sway);
      c.drawPath(b1, _stroke);
      c.drawPath(b2, _stroke);
    }
  }

  static void _drawPectoralFin(Canvas c, FishRig r, double time) {
    final st = r.style;
    final p = r.spine[2];
    final flutter = sin(r.finPhase * 1.4) * 0.35;

    c.save();
    c.translate(p.dx + 0.5, p.dy + 1.6);
    c.rotate(flutter);
    final pec = Path()
      ..moveTo(0, 0)
      ..quadraticBezierTo(-3.8, -1.8, -5.2, 0.8)
      ..quadraticBezierTo(-3.2, 3.2, 0, 1.2)
      ..close();
    _fill.color = st.finColor.withValues(alpha: 0.65);
    c.drawPath(pec, _fill);
    c.restore();
  }

  static void _drawFishEye(Canvas c, FishRig r, Offset snout) {
    final st = r.style;
    final eyeCenter = Offset(snout.dx - 3.6, snout.dy - 1.1);
    final eyeR = (st.species == FishSpecies.angel || st.species == FishSpecies.discus) ? 2.3 : 2.0;

    c.save();
    c.translate(eyeCenter.dx, eyeCenter.dy);

    // Sclera / golden iris rim
    _fill.color = const Color(0xFFFFFDE7);
    c.drawCircle(Offset.zero, eyeR, _fill);

    // Pupil tracking lookX / lookY
    final px = (r.lookX * 0.75).clamp(-0.8, 0.9);
    final py = (r.lookY * 0.65).clamp(-0.7, 0.7);
    _fill.color = const Color(0xFF0D1117);
    c.drawCircle(Offset(px, py), eyeR * 0.58, _fill);

    // Specular glint
    _fill.color = Colors.white;
    c.drawCircle(Offset(px - 0.45, py - 0.5), eyeR * 0.24, _fill);

    // Blink eyelid
    if (r.blink > 0.0) {
      _fill.color = st.primary;
      c.drawCircle(Offset.zero, eyeR * 1.05, _fill);
    }
    c.restore();
  }

  // ===========================================================================
  // 7: FIRE SHRIMP (Segmented curved abdomen, long antennae, busy legs, tail fan)
  // ===========================================================================

  static void _paintShrimp(Canvas c, FishRig r, double time) {
    final st = r.style;
    c.save();
    final sx = r.turnScale.abs() < 0.15 ? (r.turnScale >= 0 ? 0.15 : -0.15) : r.turnScale;
    c.scale(sx, 1.0);

    // 1. Busy swimmerets & walking legs underneath
    _stroke
      ..color = st.finColor.withValues(alpha: 0.85)
      ..strokeWidth = 0.95;
    for (int i = 0; i < 6; i++) {
      final p = r.spine[i + 1];
      final swing = sin(time * 14.0 + i * 1.1) * 2.2;
      c.drawLine(
        Offset(p.dx, p.dy + 1.8),
        Offset(p.dx + swing - 1.0, p.dy + 6.5),
        _stroke,
      );
    }

    // 2. Tail fan (uropods) at rear
    final tail = r.spine.last;
    final fanPath = Path()
      ..moveTo(tail.dx, tail.dy)
      ..lineTo(tail.dx - 6.0, tail.dy - 3.5)
      ..lineTo(tail.dx - 7.0, tail.dy + 0.5)
      ..lineTo(tail.dx - 5.5, tail.dy + 4.2)
      ..close();
    _fill.color = st.finColor.withValues(alpha: 0.85);
    c.drawPath(fanPath, _fill);

    // 3. Segmented curved shell plates (alternating fire red & white bands)
    for (int i = FishRig.spineJoints - 2; i >= 0; i--) {
      final p = r.spine[i];
      final s = i / (FishRig.spineJoints - 1);
      final rad = (3.6 * (1.0 - s * 0.45)).clamp(1.6, 3.8);
      final archY = p.dy - sin(s * pi) * 2.4;

      _fill.color = (i == 2 || i == 5) ? st.accent : st.primary;
      c.drawOval(
        Rect.fromCenter(center: Offset(p.dx, archY), width: rad * 2.1, height: rad * 1.85),
        _fill,
      );
    }

    // 4. Rostrum (pointed nosehorn) & long sweeping antennae
    final head = r.spine[0];
    _stroke
      ..color = st.accent.withValues(alpha: 0.9)
      ..strokeWidth = 0.9;
    final antSway1 = sin(time * 3.2 + r.finPhase) * 3.0;
    final antSway2 = cos(time * 2.7 + r.finPhase) * 3.5;

    final ant1 = Path()
      ..moveTo(head.dx + 2.0, head.dy - 1.0)
      ..quadraticBezierTo(head.dx + 12.0, head.dy - 8.0, head.dx + 20.0, head.dy - 5.0 + antSway1);
    final ant2 = Path()
      ..moveTo(head.dx + 2.0, head.dy - 0.2)
      ..quadraticBezierTo(head.dx + 9.0, head.dy - 11.0, head.dx - 6.0, head.dy - 12.0 + antSway2);
    c.drawPath(ant1, _stroke);
    c.drawPath(ant2, _stroke);

    // Stalked compound eye
    _fill.color = const Color(0xFF111111);
    c.drawCircle(Offset(head.dx + 2.2, head.dy - 2.0), 1.4, _fill);
    _fill.color = Colors.white;
    c.drawCircle(Offset(head.dx + 2.5, head.dy - 2.3), 0.45, _fill);

    c.restore();
  }

  // ===========================================================================
  // 8: RUBY CRAB (Broad armored carapace, 8 jointed walking legs, raised claws)
  // ===========================================================================

  static void _paintCrab(Canvas c, FishRig r, double time) {
    final st = r.style;
    c.save();

    // 1. Eight jointed walking legs (4 on each side)
    _stroke
      ..color = st.secondary
      ..strokeWidth = 1.9;
    for (final side in [-1.0, 1.0]) {
      for (int leg = 0; leg < 4; leg++) {
        final step = sin(r.legPhase + leg * 1.3 + (side > 0 ? 0.0 : pi)) * 2.2;
        final lift = max(0.0, cos(r.legPhase + leg * 1.3)) * 2.0;
        final rx = side * (6.5 + leg * 1.5);
        final ry = 1.0 + leg * 1.1;
        final knee = Offset(rx + side * (5.5 + leg * 0.6), ry - 3.2 - lift * 0.5);
        final foot = Offset(rx + side * (9.5 + leg * 0.8) + step, 8.5 - lift);
        final path = Path()
          ..moveTo(rx * 0.7, ry)
          ..lineTo(knee.dx, knee.dy)
          ..lineTo(foot.dx, foot.dy);
        c.drawPath(path, _stroke);
      }
    }

    // 2. Twin pincer claws (chelipeds) that raise and snap
    final threat = r.specialActive > 0 ? sin(r.specialActive * pi) * 4.5 : sin(time * 2.5) * 1.0;
    for (final side in [-1.0, 1.0]) {
      c.save();
      c.translate(side * 8.5, -2.5);
      c.rotate(side * (-0.35 - threat * 0.08));
      // Arm segment
      _stroke
        ..color = st.secondary
        ..strokeWidth = 2.4;
      c.drawLine(Offset.zero, Offset(side * 4.5, -5.5), _stroke);
      // Pincer claw
      c.translate(side * 4.5, -5.5);
      _fill.color = st.primary;
      final claw = Path()
        ..moveTo(0, 0)
        ..quadraticBezierTo(side * 5.5, -4.5, side * 2.2, -8.5)
        ..lineTo(side * 0.6, -4.5)
        ..lineTo(-side * 1.4, -7.8)
        ..quadraticBezierTo(-side * 3.8, -3.5, 0, 0)
        ..close();
      c.drawPath(claw, _fill);
      c.restore();
    }

    // 3. Broad hexagonal ruby carapace shell
    final shellRect = Rect.fromCenter(center: const Offset(0, 0), width: 20.0, height: 13.0);
    _fill.shader = RadialGradient(
      center: const Alignment(-0.2, -0.35),
      radius: 0.85,
      colors: [st.accent, st.primary, st.secondary],
      stops: const [0.0, 0.55, 1.0],
    ).createShader(shellRect);
    final shell = Path()
      ..moveTo(-7.5, -5.5)
      ..quadraticBezierTo(0, -7.5, 7.5, -5.5)
      ..lineTo(10.5, -0.5)
      ..quadraticBezierTo(7.0, 6.2, 0, 6.2)
      ..quadraticBezierTo(-7.0, 6.2, -10.5, -0.5)
      ..close();
    c.drawPath(shell, _fill);
    _fill.shader = null;

    // Carapace ridges
    _fill.color = st.secondary.withValues(alpha: 0.35);
    c.drawCircle(const Offset(-3.5, -1.0), 1.8, _fill);
    c.drawCircle(const Offset(3.5, -1.0), 1.8, _fill);

    // 4. Stalked eyes on top of the carapace
    for (final side in [-1.0, 1.0]) {
      final ex = side * 3.6;
      _stroke
        ..color = st.secondary
        ..strokeWidth = 1.4;
      c.drawLine(Offset(ex, -5.0), Offset(ex, -7.8), _stroke);
      _fill.color = Colors.white;
      c.drawCircle(Offset(ex, -8.2), 1.7, _fill);
      _fill.color = const Color(0xFF111111);
      c.drawCircle(Offset(ex + r.lookX * 0.5, -8.2 + r.lookY * 0.4), 0.95, _fill);
    }

    c.restore();
  }

  // ===========================================================================
  // 9: GOLDEN APPLE SNAIL (Rippling muscular foot, feelers, golden spiral shell)
  // ===========================================================================

  static void _paintSnail(Canvas c, FishRig r, double time) {
    final st = r.style;
    c.save();
    final sx = r.turnScale.abs() < 0.15 ? (r.turnScale >= 0 ? 0.15 : -0.15) : r.turnScale;
    c.scale(sx, 1.0);

    // 1. Soft muscular foot with travelling pedal wave along the sand
    final foot = Path()..moveTo(-11.0, 6.5);
    for (int i = 0; i <= 10; i++) {
      final u = i / 10.0;
      final fx = -11.0 + u * 23.0;
      final wave = sin(time * 5.5 - u * 4.5) * 0.75;
      foot.lineTo(fx, 6.5 + wave);
    }
    foot
      ..quadraticBezierTo(13.5, 4.0, 10.5, 1.5)
      ..quadraticBezierTo(4.0, 0.5, -9.5, 3.0)
      ..close();
    _fill.color = st.bellyColor;
    c.drawPath(foot, _fill);

    // 2. Feelers / eyestalks at the front of the head
    final sway = sin(time * 3.0 + r.finPhase) * 1.1;
    _stroke
      ..color = _mix(st.bellyColor, st.secondary, 0.35)
      ..strokeWidth = 1.2;
    c.drawLine(const Offset(9.5, 2.2), Offset(14.0, -2.5 + sway), _stroke);
    c.drawLine(const Offset(10.2, 3.2), Offset(14.8, 1.2 - sway * 0.6), _stroke);
    _fill.color = const Color(0xFF1A1A1A);
    c.drawCircle(Offset(14.0, -2.5 + sway), 0.95, _fill);

    // 3. Golden spiral shell perched on the back
    const shellCenter = Offset(-1.5, -2.2);
    final shellRect = Rect.fromCircle(center: shellCenter, radius: 8.5);
    _fill.shader = RadialGradient(
      center: const Alignment(-0.3, -0.35),
      radius: 0.9,
      colors: [st.finColor, st.primary, st.secondary],
      stops: const [0.0, 0.55, 1.0],
    ).createShader(shellRect);
    c.drawOval(Rect.fromCenter(center: shellCenter, width: 16.5, height: 14.5), _fill);
    _fill.shader = null;

    // Logarithmic spiral whorl inside the shell
    final spiral = Path();
    for (int i = 0; i <= 36; i++) {
      final a = i * 0.32;
      final rad = 0.35 + i * 0.19;
      final px = shellCenter.dx - 1.0 + cos(a) * rad;
      final py = shellCenter.dy + sin(a) * rad * 0.88;
      if (i == 0) {
        spiral.moveTo(px, py);
      } else {
        spiral.lineTo(px, py);
      }
    }
    _stroke
      ..color = st.accent.withValues(alpha: 0.65)
      ..strokeWidth = 1.15;
    c.drawPath(spiral, _stroke);

    // Shell gloss highlight
    _fill.color = Colors.white.withValues(alpha: 0.38);
    c.drawOval(
      Rect.fromCenter(center: shellCenter + const Offset(-2.8, -3.2), width: 5.5, height: 2.8),
      _fill,
    );

    c.restore();
  }

  // ===========================================================================
  // 10: MOON JELLYFISH (Bioluminescent pulsing bell, four clover gonads, tentacles)
  // ===========================================================================

  static void _paintJellyfish(Canvas c, FishRig r, double time) {
    final st = r.style;
    final pulse = r.bellPulse;
    final bellW = 13.5 * (1.0 - pulse * 0.08);
    final bellH = 11.5 * (1.0 + pulse * 0.10);

    c.save();

    // 1. Trailing translucent oral arms & tentacles
    for (int t = 0; t < r.tentacles.length; t++) {
      final chain = r.tentacles[t];
      final path = Path()..moveTo(chain[0].dx, chain[0].dy);
      for (int k = 1; k < chain.length; k++) {
        path.lineTo(chain[k].dx, chain[k].dy);
      }
      final isOralArm = (t == 2 || t == 3);
      _stroke
        ..color = (isOralArm ? st.primary : st.accent).withValues(alpha: isOralArm ? 0.62 : 0.48)
        ..strokeWidth = isOralArm ? 2.1 : 1.05;
      c.drawPath(path, _stroke);
    }

    // 2. Outer bioluminescent bell glow
    final bellRect = Rect.fromCenter(center: const Offset(0, -4.0), width: bellW * 2, height: bellH * 2);
    final bellPath = Path()
      ..moveTo(-bellW, 2.5)
      ..cubicTo(-bellW * 1.08, -bellH * 1.15, bellW * 1.08, -bellH * 1.15, bellW, 2.5);
    // Scalloped bell margin
    const lobes = 6;
    for (int i = lobes; i >= 1; i--) {
      final x1 = -bellW + (i - 0.5) * (2 * bellW / lobes);
      final x0 = -bellW + (i - 1) * (2 * bellW / lobes);
      bellPath.quadraticBezierTo(x1, 4.2 - pulse * 0.8, x0, 2.5);
    }
    bellPath.close();

    _fill.shader = RadialGradient(
      center: const Alignment(0.0, -0.35),
      radius: 0.95,
      colors: [
        Colors.white.withValues(alpha: 0.78),
        st.primary.withValues(alpha: 0.65),
        st.secondary.withValues(alpha: 0.45),
        st.accent.withValues(alpha: 0.55),
      ],
      stops: const [0.0, 0.42, 0.78, 1.0],
    ).createShader(bellRect);
    c.drawPath(bellPath, _fill);
    _fill.shader = null;

    // 3. Signature four-leaf clover moon-jelly rings inside the dome
    _stroke
      ..color = st.secondary.withValues(alpha: 0.55)
      ..strokeWidth = 1.0;
    for (final off in const [
      Offset(-2.4, -4.5),
      Offset(2.4, -4.5),
      Offset(0.0, -6.6),
      Offset(0.0, -2.4),
    ]) {
      c.drawCircle(off, 1.6, _stroke);
    }

    // Rim highlight
    _stroke
      ..color = st.accent.withValues(alpha: 0.7)
      ..strokeWidth = 1.1;
    c.drawPath(bellPath, _stroke);

    c.restore();
  }
}

/// Reusable Flutter widget that renders any [FishItem] procedurally
/// (used in the Aquarium Catalog, Crate Opening reveal cards, etc.).
class ProceduralFishPreview extends StatelessWidget {
  final String fishId;
  final double size;
  final double time;
  final bool lockedSilhouette;

  const ProceduralFishPreview({
    super.key,
    required this.fishId,
    this.size = 48.0,
    this.time = 0.6,
    this.lockedSilhouette = false,
  });

  @override
  Widget build(BuildContext context) {
    final fish = FishItem.getById(fishId);
    final child = SizedBox(
      width: size,
      height: size,
      child: Image.asset(
        fish.assetPath,
        fit: BoxFit.contain,
        filterQuality: FilterQuality.none,
        errorBuilder: (context, error, stackTrace) => const Icon(
          Icons.set_meal_rounded,
          size: 28,
          color: Colors.amber,
        ),
      ),
    );
    if (!lockedSilhouette) return child;
    return ColorFiltered(
      colorFilter: const ColorFilter.mode(Colors.black54, BlendMode.srcATop),
      child: Opacity(opacity: 0.38, child: child),
    );
  }
}
