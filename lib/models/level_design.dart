import 'dart:math';
import 'package:flutter/material.dart';
import 'brick.dart';

class LevelDesign {
  static const List<List<int>> shapeSmiley = [
    [0, 1, 1, 1, 1, 1, 0],
    [1, 0, 1, 0, 1, 0, 1],
    [1, 0, 0, 0, 0, 0, 1],
    [1, 0, 1, 0, 1, 0, 1],
    [1, 0, 0, 1, 0, 0, 1],
    [0, 1, 1, 0, 1, 1, 0]
  ];

  static const List<List<int>> shapeSword = [
    [0, 0, 0, 1, 0, 0, 0],
    [0, 0, 0, 1, 0, 0, 0],
    [0, 0, 0, 1, 0, 0, 0],
    [0, 1, 1, 1, 1, 1, 0],
    [0, 0, 0, 1, 0, 0, 0],
    [0, 0, 1, 1, 1, 0, 0]
  ];

  static const List<List<int>> shapeHeart = [
    [0, 1, 1, 0, 1, 1, 0],
    [1, 1, 1, 1, 1, 1, 1],
    [1, 1, 1, 1, 1, 1, 1],
    [0, 1, 1, 1, 1, 1, 0],
    [0, 0, 1, 1, 1, 0, 0],
    [0, 0, 0, 1, 0, 0, 0]
  ];

  static const List<List<int>> shapeDiamond = [
    [0, 0, 0, 1, 0, 0, 0],
    [0, 0, 1, 1, 1, 0, 0],
    [0, 1, 1, 1, 1, 1, 0],
    [1, 1, 1, 1, 1, 1, 1],
    [0, 1, 1, 1, 1, 1, 0],
    [0, 0, 1, 1, 1, 0, 0],
    [0, 0, 0, 1, 0, 0, 0]
  ];

  static const List<Color> magmaPalette = [
    Color(0xFFFF3D00),
    Color(0xFFFF6D00),
    Color(0xFFFF9100),
    Color(0xFFD84315),
    Color(0xFFBF360C),
    Color(0xFFFF5722),
  ];

  static const List<Color> icePalette = [
    Color(0xFFE1F5FE),
    Color(0xFF81D4FA),
    Color(0xFF4FC3F7),
    Color(0xFF29B6F6),
    Color(0xFFB3E5FC),
    Color(0xFF80DEEA),
  ];

  static const List<Color> candyPalette = [
    Color(0xFFFF4081),
    Color(0xFFE040FB),
    Color(0xFF7C4DFF),
    Color(0xFFFF80AB),
    Color(0xFFEA80FC),
    Color(0xFFB388FF),
  ];

  static const List<Color> tuftPalette = [
    Color(0xFFFF7043),
    Color(0xFFFFD54F),
    Color(0xFF4DD0E1),
    Color(0xFF81C784),
    Color(0xFFBA68C8),
    Color(0xFFFF8A80),
    Color(0xFF4FC3F7),
    Color(0xFFAED581),
  ];

  static const List<Color> neonPalette = [
    Color(0xFF00E5FF),
    Color(0xFFFF007F),
    Color(0xFFFFD600),
    Color(0xFF00E676),
    Color(0xFF7C4DFF),
    Color(0xFFFF6D00),
  ];

  static const double baseTopMargin = 105.0;

  static int getWorldIndex(int level) {
    if (level <= 35) return 1;
    if (level <= 75) return 2;
    if (level <= 115) return 3;
    if (level <= 155) return 4;
    if (level <= 195) return 5;
    return 6;
  }

  static String getWorldName(int level) {
    switch (getWorldIndex(level)) {
      case 1:
        return 'Neon Başlangıç';
      case 2:
        return 'Siber Bastion';
      case 3:
        return 'Manyetik Girdap';
      case 4:
        return 'Kristal Labirent';
      case 5:
        return 'Lav Çölü & Titanyum';
      case 6:
      default:
        return 'Kuantum Zirvesi';
    }
  }

  static List<Color> getWorldPalette(int worldIndex) {
    switch (worldIndex) {
      case 1:
        return const [
          Color(0xFF00E5FF), // Cyber Cyan
          Color(0xFFFF007F), // Electric Magenta
          Color(0xFFFFD600), // Bright Yellow
          Color(0xFF00E676), // Neon Green
          Color(0xFF7C4DFF), // Vivid Purple
          Color(0xFFFF6D00), // Neon Orange
        ];
      case 2:
        return const [
          Color(0xFF2979FF), // Cobalt Blue
          Color(0xFFFF5252), // Bright Coral
          Color(0xFFFFB300), // Amber Gold
          Color(0xFF1DE9B6), // Mint
          Color(0xFF3D5AFE), // Deep Indigo
          Color(0xFFFF1744), // Crimson
        ];
      case 3:
        return const [
          Color(0xFF651FFF), // Electric Violet
          Color(0xFFFF1744), // Neon Magenta
          Color(0xFF00E5FF), // Pulsar Cyan
          Color(0xFF304FFE), // Twilight Indigo
          Color(0xFFFFEA00), // Electric Yellow
          Color(0xFFE040FB), // Plasma Purple
        ];
      case 4:
        return const [
          Color(0xFF00E676), // Emerald
          Color(0xFF00B0FF), // Deep Azure
          Color(0xFFAA00FF), // Radiant Amethyst
          Color(0xFFFFC400), // Gold Amber
          Color(0xFFFF4081), // Rose Quartz
          Color(0xFF18FFFF), // Electric Diamond
        ];
      case 5:
        return const [
          Color(0xFFFF3D00), // Molten Orange
          Color(0xFFD50000), // Lava Crimson
          Color(0xFFFFAB00), // Fiery Gold
          Color(0xFFDD2C00), // Burning Ochre
          Color(0xFFFF6D00), // Solar Flare
          Color(0xFFFF1744), // Magma Red
        ];
      case 6:
      default:
        return const [
          Color(0xFF2979FF), // Quantum Sapphire
          Color(0xFF7C4DFF), // Astral Purple
          Color(0xFFFFD700), // Solar Gold
          Color(0xFFFF1493), // Plasma Pink
          Color(0xFF00F5FF), // Pure Cyan
          Color(0xFFFF6E40), // Singularity Coral
        ];
    }
  }

  static int _selectArchetype(int level, int world, int step) {
    if (level == 238) return 29; // OmegaFinal Apex
    final cycleIndex = level ~/ 10;
    switch (step) {
      case 1:
        return (cycleIndex % 2 == 0) ? 0 : 1; // Checkerboard or DominoChain
      case 2:
        return [2, 3, 4, 12][cycleIndex % 4]; // DiamondMine, SpiralGalaxy, IceAvalanche, StarOfDestiny
      case 3:
        return [5, 6, 7][cycleIndex % 3]; // CastleFortress, Honeycomb, PillarsOfHercules
      case 4:
        return [8, 9, 10, 11][cycleIndex % 4]; // SymmetricTotem, AlienInvader, DoubleHelix, Arrowhead
      case 6:
        return [13, 14, 15][cycleIndex % 3]; // PrecisionSlit, IronCurtain, DualConvoys
      case 7:
        return [16, 17, 18, 19][cycleIndex % 4]; // BunkerVault, ZigzagMaze, TheGauntlet, TheFunnel
      case 8:
        return [20, 21, 22, 23][cycleIndex % 4]; // TargetBullseye, TwinTowers, SkullFortress, ShieldAndCrown
      case 9:
        return [24, 25, 26, 27, 28][cycleIndex % 5]; // SwordOfJustice, Hourglass, HeartOfStone, QuantumMatrix, Eclipse
      default:
        return 0;
    }
  }

  static bool _getArchetypeCell(int archetype, int r, int c, int rows, int cols, int level) {
    switch (archetype) {
      case 0: // Checkerboard
        return (r + c) % 2 == 0;
      case 1: // DominoChain
        return (r % 2 == 0 && c % 2 == 0) || (r % 2 == 1 && c % 2 == 1 && c > 0 && c < cols - 1);
      case 2: // DiamondMine
        final dr = (r - rows / 2.0).abs() / (rows / 2.0);
        final dc = (c - cols / 2.0).abs() / (cols / 2.0);
        return (dr + dc) <= 1.08;
      case 3: // SpiralGalaxy
        return (r == 0 && c < cols - 1) ||
            (c == cols - 1 && r < rows - 1) ||
            (r == rows - 1 && c > 0) ||
            (c == 0 && r > 1) ||
            (r >= 2 && r <= rows - 3 && c >= 2 && c <= cols - 3 && ((r + c) % 2 == 0));
      case 4: // IceAvalanche
        final midC = cols ~/ 2;
        return r >= (c - midC).abs();
      case 5: // CastleFortress
        return c == 0 ||
            c == cols - 1 ||
            (r == 0 && c % 2 == 0) ||
            (r >= rows - 2) ||
            (r >= 2 && (c == 2 || c == cols - 3));
      case 6: // Honeycomb
        return r % 2 == 0 ? (c % 2 == 0) : (c % 2 == 1);
      case 7: // PillarsOfHercules
        return (c % 3 != 1) || (r == 0) || (r == rows - 1);
      case 8: // SymmetricTotem
        final dc = (c - cols / 2.0).abs();
        final dr = (r - rows / 2.0).abs();
        return (dc + dr <= (rows + cols) * 0.38) && !(r % 2 == 1 && dc < 0.8);
      case 9: // AlienInvader
        final cNorm = (c < cols / 2) ? c : (cols - 1 - c);
        return (r == 0 && cNorm == 1) ||
            (r == 1 && (cNorm == 0 || cNorm == 2)) ||
            (r == 2 && cNorm >= 0) ||
            (r == 3 && cNorm != 1) ||
            (r >= 4 && (cNorm == 0 || cNorm == cols ~/ 2));
      case 10: // DoubleHelix
        final h1 = ((r * 1.3).round()) % cols;
        final h2 = cols - 1 - (((r * 1.3).round()) % cols);
        return c == h1 || c == h2 || (r % 3 == 0 && c >= min(h1, h2) && c <= max(h1, h2));
      case 11: // Arrowhead
        final midC = cols ~/ 2;
        return r <= (rows - 1 - ((c - midC).abs() * 1.5).round());
      case 12: // StarOfDestiny
        return r == rows ~/ 2 ||
            c == cols ~/ 2 ||
            (r == (c * rows / cols).round()) ||
            (r == ((cols - 1 - c) * rows / cols).round());
      case 13: // PrecisionSlit
        final slitCol = cols ~/ 2;
        return !(r == rows - 2 && c == slitCol);
      case 14: // IronCurtain
        return r % 2 == 0 || (c != (r * 2) % cols && c != (r * 2 + 1) % cols);
      case 15: // DualConvoys
        return r % 2 == 0 || (c > 0 && c < cols - 1);
      case 16: // BunkerVault
        return r == 0 || r == rows - 1 || c == 0 || c == cols - 1 || (r == rows ~/ 2 && c == cols ~/ 2);
      case 17: // ZigzagMaze
        return r % 2 == 0 || (r % 4 == 1 && c == cols - 1) || (r % 4 == 3 && c == 0);
      case 18: // TheGauntlet
        return c <= 1 || c >= cols - 2 || (r % 2 == 0 && c == cols ~/ 2);
      case 19: // TheFunnel
        final midC = cols ~/ 2;
        return r <= (((c - midC).abs() * 1.8).round());
      case 20: // TargetBullseye
        final dr = (r - rows / 2.0) / (rows / 2.0);
        final dc = (c - cols / 2.0) / (cols / 2.0);
        final dist = sqrt(dr * dr + dc * dc);
        return dist < 0.38 || (dist > 0.65 && dist < 1.05);
      case 21: // TwinTowers
        return c <= 1 || c >= cols - 2 || (r == 0 && (c == cols ~/ 2 || c == cols ~/ 2 - 1));
      case 22: // SkullFortress
        if (r < rows - 2) {
          final isEye = (r == rows ~/ 3) && (c == cols ~/ 3 || c == cols - 1 - cols ~/ 3);
          return !isEye;
        } else {
          return c >= 1 && c <= cols - 2 && c % 2 == 0;
        }
      case 23: // ShieldAndCrown
        if (r <= 1) {
          return c == 0 || c == cols - 1 || c == cols ~/ 2;
        } else {
          return c >= (r - 2) && c <= (cols - 1 - (r - 2));
        }
      case 24: // SwordOfJustice
        final center = cols ~/ 2;
        if (r < rows - 2) return c == center || (r == 0 && (c == center - 1 || c == center + 1));
        if (r == rows - 2) return true;
        return c == center;
      case 25: // Hourglass
        final midR = rows / 2.0;
        final waist = (1.0 - (r - midR).abs() / midR);
        return (c - cols / 2.0).abs() >= (waist * (cols / 3.0));
      case 26: // HeartOfStone
        final halfC = cols / 2.0;
        if (r == 0) return c == 1 || c == 2 || c == cols - 2 || c == cols - 3;
        if (r == 1) return true;
        final t = (r - 2) / max(1, rows - 2);
        return (c - halfC).abs() <= (halfC * (1.0 - t * 0.85));
      case 27: // QuantumMatrix
        return (r % 2 == 0) || (c % 2 == 0) || (r == rows ~/ 2 && c == cols ~/ 2);
      case 28: // Eclipse
        final dr = (r - rows / 2.0) / (rows / 2.0);
        final dc = (c - cols / 2.0) / (cols / 2.0);
        final dist = sqrt(dr * dr + dc * dc);
        return dist <= 1.05 && !(dr > 0.1 && dc > 0.1 && dist < 0.85);
      case 29: // OmegaFinal
        final dr = (r - rows / 2.5) / (rows / 2.5);
        final dc = (c - cols / 2.0) / (cols / 2.0);
        final dist = sqrt(dr * dr + dc * dc);
        if (r < rows - 1) return dist >= 0.55 && dist <= 1.15 && (dr < 0.6 || dc.abs() > 0.35);
        return c <= 1 || c >= cols - 2;
      default:
        return true;
    }
  }

  static bool isBossLevelNumber(int level) {
    if (level <= 0) return false;
    // Bosslar 10-15 bölümde bir gelir: 12, 25, 37, 50, 62, 75, 87, 100, 112, 125, 137, 150, 162, 175, 187, 200, 212, 225, 237...
    const bossSequence = [
      12, 25, 37, 50, 62, 75, 87, 100, 112, 125, 137, 150, 162, 175, 187, 200, 212, 225, 237
    ];
    return bossSequence.contains(level);
  }

  static List<Brick> buildClassicLevel(int level, double screenWidth, double screenHeight) {
    final List<Brick> bricks = [];
    final bool isBossLevel = isBossLevelNumber(level);
    final world = getWorldIndex(level);
    const padding = 16.0;

    if (isBossLevel) {
      final isMajorBoss = (level % 25 == 0 || level == 100 || level == 200);
      final bossW = screenWidth * (isMajorBoss ? 0.54 : 0.48);
      final bossH = isMajorBoss ? 40.0 : 36.0;
      final bossX = (screenWidth - bossW) / 2;
      final bossHp = isMajorBoss ? (25 + (level * 3.2).round()) : (20 + (level * 2.5).round());

      // Boss Brick
      bricks.add(
        Brick(
          x: bossX,
          y: baseTopMargin + 10,
          width: bossW,
          height: bossH,
          hp: bossHp,
          maxHp: bossHp,
          isBoss: true,
          bossVx: 75.0 + level * 1.8,
          minX: padding,
          maxX: screenWidth - padding,
          color: isMajorBoss ? const Color(0xFFD50000) : const Color(0xFFFF1744),
          points: isMajorBoss ? 1000 : 500,
        ),
      );

      // Front guard row
      final guardCols = isMajorBoss ? 7 : 6;
      const gap = 6.0;
      final bw = (screenWidth - (padding * 2) - gap * (guardCols - 1)) / guardCols;
      final totalW = guardCols * bw + gap * (guardCols - 1);
      final startX = (screenWidth - totalW) / 2;
      final guardHp = 2 + (world ~/ 2);

      for (int c = 0; c < guardCols; c++) {
        bricks.add(
          Brick(
            x: startX + c * (bw + gap),
            y: baseTopMargin + bossH + 26.0,
            width: bw,
            height: 20.0,
            hp: guardHp,
            maxHp: guardHp,
            color: isMajorBoss ? const Color(0xFFFF6D00) : const Color(0xFFFF9100),
            points: 25 * guardHp,
          ),
        );
      }

      // In World 2+ (level >= 35): Add moving satellite shield interceptors
      if (world >= 2) {
        if (isMajorBoss) {
          // 2 Moving satellite shields sliding in opposite directions
          const satW = 48.0;
          const satH = 18.0;
          bricks.add(
            Brick(
              x: padding,
              y: baseTopMargin + bossH + 52.0,
              width: satW,
              height: satH,
              hp: 3 + world,
              maxHp: 3 + world,
              isMover: true,
              moverVx: 85.0 + level * 0.4,
              minX: padding,
              maxX: screenWidth - padding,
              color: const Color(0xFF00E5FF),
              points: 75,
            ),
          );
          bricks.add(
            Brick(
              x: screenWidth - padding - satW,
              y: baseTopMargin + bossH + 52.0,
              width: satW,
              height: satH,
              hp: 3 + world,
              maxHp: 3 + world,
              isMover: true,
              moverVx: -(85.0 + level * 0.4),
              minX: padding,
              maxX: screenWidth - padding,
              color: const Color(0xFFFF007F),
              points: 75,
            ),
          );
        } else if (level >= 35) {
          // 1 Moving satellite shield for mid-bosses in later worlds
          const satW = 54.0;
          const satH = 18.0;
          bricks.add(
            Brick(
              x: (screenWidth - satW) / 2,
              y: baseTopMargin + bossH + 52.0,
              width: satW,
              height: satH,
              hp: 2 + world,
              maxHp: 2 + world,
              isMover: true,
              moverVx: 80.0 + level * 0.3,
              minX: padding,
              maxX: screenWidth - padding,
              color: const Color(0xFFFFD600),
              points: 50,
            ),
          );
        }
      }

      return bricks;
    }

    // Kishōtenketsu Procedural Progression (Worlds 1 - 6, Levels 1 - 238)
    int rows;
    int cols;
    switch (world) {
      case 1:
        rows = min(7, 5 + (level ~/ 12));
        cols = 6 + (level % 2);
        break;
      case 2:
        rows = min(8, 6 + ((level - 35) ~/ 15));
        cols = 7 + (level % 2);
        break;
      case 3:
        rows = min(9, 7 + ((level - 75) ~/ 15));
        cols = 7 + ((level ~/ 2) % 3);
        break;
      case 4:
        rows = min(10, 7 + ((level - 115) ~/ 12));
        cols = 8 + (level % 2);
        break;
      case 5:
        rows = min(11, 8 + ((level - 155) ~/ 12));
        cols = 8 + ((level ~/ 2) % 3);
        break;
      case 6:
      default:
        rows = min(12, 9 + ((level - 195) ~/ 12));
        cols = 8 + ((level ~/ 2) % 3);
        break;
    }

    const gap = 5.0;
    final bw = (screenWidth - (padding * 2) - gap * (cols - 1)) / cols;
    const bh = 22.0;
    final step = level % 10;
    final archetype = _selectArchetype(level, world, step);
    final palette = getWorldPalette(world);

    for (int r = 0; r < rows; r++) {
      for (int c = 0; c < cols; c++) {
        if (!_getArchetypeCell(archetype, r, c, rows, cols, level)) continue;

        // Progressive Difficulty & Steel Placement
        bool isSteel = false;
        bool isHeavySteel = false;
        bool isMover = false;

        if (world == 1 && level >= 20) {
          isSteel = (r == 0 && (c == 0 || c == cols - 1));
        } else if (world == 2) {
          isSteel = (r == 0 && (c == 0 || c == cols - 1) && level % 2 == 0);
          isMover = (r == rows - 1 && c % 3 == 0);
        } else if (world == 3) {
          isSteel = (step >= 6 && r == 0 && (c == 1 || c == cols - 2));
          isMover = (r == rows - 1 && c % 2 == 1);
        } else if (world == 4) {
          isSteel = (step >= 6 && r == rows ~/ 2 && (c == 0 || c == cols - 1));
          isMover = ((r == rows - 1 || r == rows - 2) && (r + c) % 4 == 0);
        } else if (world == 5) {
          isSteel = (step >= 6 && (r == 0 || r == 1) && (c == 0 || c == cols - 1));
          isHeavySteel = isSteel && (level % 3 == 0);
          isMover = (r == rows - 1 && (c % 2 == 0));
        } else if (world == 6) {
          isSteel = (step >= 6 && r == 1 && c % 3 == 0);
          isHeavySteel = isSteel && (level % 2 == 0);
          isMover = ((r == rows - 1 || r == rows - 3) && c % 2 == 1);
        }

        // Dual convoys archetype specific mover setup
        if (archetype == 15 && (r == rows - 1 || r == rows - 3) && !isSteel && !isHeavySteel) {
          isMover = true;
        }

        // Dynamite placement (strategic detonators)
        bool isDynamite = false;
        if (!isSteel && !isHeavySteel) {
          if (archetype == 1) { // DominoChain
            isDynamite = (r + c) % 3 == 0;
          } else if (archetype == 16 && r == rows ~/ 2 && c == cols ~/ 2) { // Vault core
            isDynamite = true;
          } else if (level >= 3 && ((r * 7 + c * 13 + level * 5) % 23 == 0)) {
            isDynamite = true;
          }
        }

        // Ice placement (chain freeze cascade)
        bool isIce = false;
        if (!isSteel && !isHeavySteel && !isDynamite) {
          if (archetype == 4 && (r == 0 || r == 1)) { // Ice Avalanche
            isIce = true;
          } else if (level >= 4 && ((r * 11 + c * 17 + level * 7) % 27 == 0)) {
            isIce = true;
          }
        }

        // HP Scaling
        int hp = 1;
        if (isSteel) {
          hp = 999;
        } else if (isHeavySteel) {
          hp = 9999;
        } else if (isIce || isDynamite) {
          hp = 1;
        } else {
          switch (world) {
            case 1:
              hp = (r < 2 && level > 15) ? 2 : 1;
              break;
            case 2:
              hp = (r < 2) ? 2 : ((r == 2 && c % 2 == 0) ? 3 : 1);
              break;
            case 3:
              hp = (r < 3) ? 2 : ((c % 2 == 1) ? 3 : 2);
              break;
            case 4:
              hp = (r < 2) ? 3 : ((r < 4) ? 2 : (((r + c) % 3 == 0) ? 4 : 2));
              break;
            case 5:
              hp = (r < 3) ? 3 : (((r + c) % 2 == 0) ? 4 : 3);
              if (r == rows ~/ 2 && c == cols ~/ 2) hp = 5;
              break;
            case 6:
            default:
              hp = (r < 4) ? 4 : (((r + c) % 2 == 0) ? 5 : 3);
              break;
          }
        }

        final color = isSteel
            ? const Color(0xFF78909C)
            : isHeavySteel
                ? const Color(0xFF37474F)
                : palette[(r + c + (level ~/ 10)) % palette.length];

        final brickX = padding + c * (bw + gap);
        final brickY = baseTopMargin + r * (bh + gap);
        final moverDirection = (r % 2 == 0) ? 1.0 : -1.0;

        bricks.add(
          Brick(
            x: brickX,
            y: brickY,
            width: bw,
            height: bh,
            hp: hp,
            maxHp: hp,
            isSteel: isSteel,
            isHeavySteel: isHeavySteel,
            isMover: isMover,
            moverVx: (60.0 + world * 10.0) * moverDirection,
            isDynamite: isDynamite,
            isIce: isIce,
            minX: padding,
            maxX: screenWidth - padding,
            color: (hp > 1 && !isSteel && !isHeavySteel) ? color.withValues(alpha: 0.85) : color,
            points: (isSteel || isHeavySteel) ? 0 : (25 * hp),
          ),
        );
      }
    }

    // Safety check: ensure at least 6 breakable bricks exist on every level!
    final breakableCount = bricks.where((b) => !b.isSteel && !b.isHeavySteel).length;
    if (breakableCount < 6) {
      final safeRow = rows ~/ 2;
      for (int c = 0; c < cols; c++) {
        final brickX = padding + c * (bw + gap);
        final brickY = baseTopMargin + safeRow * (bh + gap);
        bricks.add(
          Brick(
            x: brickX,
            y: brickY,
            width: bw,
            height: bh,
            hp: 1,
            maxHp: 1,
            minX: padding,
            maxX: screenWidth - padding,
            color: palette[c % palette.length],
            points: 25,
          ),
        );
      }
    }

    // Ensure all bricks are safely clamped within screen width
    for (final b in bricks) {
      if (b.x < padding) b.x = padding;
      if (b.x + b.width > screenWidth - padding) {
        b.x = screenWidth - padding - b.width;
      }
      b.minX = padding;
      b.maxX = screenWidth - padding;
    }

    return bricks;
  }

  static final Random _descendRand = Random();

  static List<Brick> buildZenLevel(double screenWidth, double screenHeight, [Random? optionalRand]) {
    final rand = optionalRand ?? Random();
    final List<Brick> bricks = [];
    const rows = 4;
    const cols = 6;
    const gap = 8.0;
    final bw = (screenWidth - 36 - gap * (cols - 1)) / cols;
    final totalW = cols * bw + gap * (cols - 1);
    final startX = (screenWidth - totalW) / 2;
    const bh = 24.0;

    // Pick 2 dynamite and 2 ice blocks across the 24 bricks
    final totalBricks = rows * cols;
    final dyn1 = rand.nextInt(totalBricks);
    final dyn2 = (dyn1 + 11) % totalBricks;
    final ice1 = (dyn1 + 5) % totalBricks;
    final ice2 = (dyn1 + 17) % totalBricks;

    for (int r = 0; r < rows; r++) {
      for (int c = 0; c < cols; c++) {
        final index = r * cols + c;
        final color = candyPalette[index % candyPalette.length];
        final isDynamite = (index == dyn1 || index == dyn2);
        final isIce = !isDynamite && (index == ice1 || index == ice2);

        bricks.add(
          Brick(
            x: startX + c * (bw + gap),
            y: baseTopMargin + r * (bh + gap),
            width: bw,
            height: bh,
            hp: 1,
            maxHp: 1,
            isDynamite: isDynamite,
            isIce: isIce,
            color: color,
            points: 10,
          ),
        );
      }
    }
    return bricks;
  }

  static List<Brick> buildDescendInitial(double screenWidth, double screenHeight) {
    final List<Brick> bricks = [];
    const rows = 4;
    for (int r = 0; r < rows; r++) {
      bricks.addAll(buildDescendRow(r, screenWidth, screenHeight));
    }
    return bricks;
  }

  static List<Brick> buildDescendRow(int rowIndex, double screenWidth, double screenHeight, [Random? optionalRand]) {
    final rand = optionalRand ?? _descendRand;
    final List<Brick> rowBricks = [];
    const cols = 7;
    const gap = 6.0;
    final bw = (screenWidth - 32 - gap * (cols - 1)) / cols;
    final totalW = cols * bw + gap * (cols - 1);
    final startX = (screenWidth - totalW) / 2;
    const bh = 22.0;
    const rowStep = bh + gap; // 28.0

    final color = magmaPalette[rowIndex % magmaPalette.length];

    // Balanced chance for dynamite and ice blocks (~28% each per row)
    final spawnDynamite = rand.nextDouble() < 0.28;
    final spawnIce = rand.nextDouble() < 0.28;
    final dynCol = spawnDynamite ? rand.nextInt(cols) : -1;
    final iceCol = spawnIce ? ((dynCol + 1 + rand.nextInt(cols - 1)) % cols) : -1;

    for (int c = 0; c < cols; c++) {
      final isDynamite = c == dynCol;
      final isIce = !isDynamite && c == iceCol;

      rowBricks.add(
        Brick(
          x: startX + c * (bw + gap),
          y: baseTopMargin + rowIndex * rowStep,
          width: bw,
          height: bh,
          hp: 1,
          maxHp: 1,
          isDynamite: isDynamite,
          isIce: isIce,
          color: color,
          points: 15,
        ),
      );
    }
    return rowBricks;
  }

  static const double chaosGap = 8.0;
  static const double chaosMargin = 12.0;
  static const int chaosCols = 7;
  static const double chaosBrickH = 26.0;
  static const double chaosStep = chaosBrickH + chaosGap;

  static List<Brick> buildChaosLevel(int wave, double screenWidth, double screenHeight) {
    final bricks = <Brick>[];
    const initialRows = 4;
    for (int row = 0; row < initialRows; row++) {
      bricks.addAll(buildChaosRow(wave, row, screenWidth, isInitialBoard: true));
    }
    return bricks;
  }

  static List<Brick> buildChaosRow(int wave, int row, double screenWidth, {bool isInitialBoard = false}) {
    final rand = Random(wave * 20011 + row * 101 + 7);
    final bw = (screenWidth - chaosMargin * 2 - chaosGap * (chaosCols - 1)) / chaosCols;
    final y = baseTopMargin + row * chaosStep;
    final bricks = <Brick>[];

    // Pick 1 column for guaranteed +1 Ball pickup per row
    final pickupCol = rand.nextInt(chaosCols);
    // Pick 1-2 empty corridor columns for trick shot ricochets
    final emptyCol1 = (pickupCol + 2) % chaosCols;
    final emptyCol2 = (pickupCol + 4) % chaosCols;

    for (int c = 0; c < chaosCols; c++) {
      if (c == pickupCol) {
        // Collectible +1 Ball Orb
        bricks.add(
          Brick(
            x: chaosMargin + c * (bw + chaosGap),
            y: y,
            width: bw,
            height: chaosBrickH,
            hp: 1,
            maxHp: 1,
            isBallPickup: true,
            color: const Color(0xFF00E5FF),
            points: 10,
          ),
        );
        continue;
      }

      if (c == emptyCol1 || (rand.nextDouble() < 0.20 && c != emptyCol2)) {
        // Open lane / corridor for trick shots
        continue;
      }

      // Balanced HP for 3-ball gameplay progression
      final int hp;
      if (wave <= 1) {
        hp = (row == 0) ? (1 + rand.nextInt(2)) : (1 + rand.nextInt(3));
      } else if (wave <= 3) {
        hp = 2 + rand.nextInt(3);
      } else {
        hp = (wave - 1) + rand.nextInt(4);
      }

      final colorIndex = (wave * 3 + row * 2 + c) % neonPalette.length;
      final color = neonPalette[colorIndex];

      bricks.add(
        Brick(
          x: chaosMargin + c * (bw + chaosGap),
          y: y,
          width: bw,
          height: chaosBrickH,
          hp: hp,
          maxHp: hp,
          color: color,
          points: 5,
        ),
      );
    }
    return bricks;
  }

  static List<Brick> buildDailyLevel(DateTime date, double screenWidth, double screenHeight) {
    final seed = date.year * 1000 + date.month * 100 + date.day;
    final rand = Random(seed);
    final List<Brick> bricks = [];
    const rows = 5;
    const cols = 7;
    const gap = 6.0;
    final bw = (screenWidth - 36 - gap * (cols - 1)) / cols;
    final totalW = cols * bw + gap * (cols - 1);
    final startX = (screenWidth - totalW) / 2;
    final bh = 22.0;

    for (int r = 0; r < rows; r++) {
      for (int c = 0; c < cols; c++) {
        if (rand.nextDouble() > 0.18) {
          final isSteel = (r == 1 && (c == 2 || c == 4));
          final color = icePalette[rand.nextInt(icePalette.length)];
          bricks.add(
            Brick(
              x: startX + c * (bw + gap),
              y: baseTopMargin + r * (bh + gap),
              width: bw,
              height: bh,
              hp: isSteel ? 999 : (rand.nextBool() ? 2 : 1),
              maxHp: isSteel ? 999 : 2,
              isSteel: isSteel,
              color: isSteel ? const Color(0xFFCFD8DC) : color,
              points: 25,
            ),
          );
        }
      }
    }
    return bricks;
  }

  static List<Brick> buildShapesLevel(int level, double screenWidth, double screenHeight) {
    final List<Brick> bricks = [];
    final shapes = [shapeHeart, shapeSword, shapeSmiley, shapeDiamond];
    final shapeIndex = (level - 1) % shapes.length;
    final matrix = shapes[shapeIndex];
    final rows = matrix.length;
    final cols = matrix[0].length;
    const gap = 6.0;
    final bw = (screenWidth - 40 - gap * (cols - 1)) / cols;
    final totalW = cols * bw + gap * (cols - 1);
    final startX = (screenWidth - totalW) / 2;
    final bh = 22.0;

    for (int r = 0; r < rows; r++) {
      for (int c = 0; c < cols; c++) {
        if (matrix[r][c] == 1) {
          final color = magmaPalette[(r + c) % magmaPalette.length];
          bricks.add(
            Brick(
              x: startX + c * (bw + gap),
              y: baseTopMargin + r * (bh + gap),
              width: bw,
              height: bh,
              hp: 1,
              maxHp: 1,
              color: color,
              points: 20,
            ),
          );
        }
      }
    }
    return bricks;
  }
}
