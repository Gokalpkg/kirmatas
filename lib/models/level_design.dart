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

  static const double baseTopMargin = 105.0;

  static List<Brick> buildClassicLevel(int level, double screenWidth, double screenHeight) {
    final List<Brick> bricks = [];
    final bool isBossLevel = (level % 5 == 0);

    if (isBossLevel) {
      // Boss stage!
      final bossW = screenWidth * 0.52;
      final bossH = 38.0;
      final bossX = (screenWidth - bossW) / 2;
      final bossHp = 15 + level * 3;

      bricks.add(
        Brick(
          x: bossX,
          y: baseTopMargin + 10,
          width: bossW,
          height: bossH,
          hp: bossHp,
          maxHp: bossHp,
          isBoss: true,
          bossVx: 75.0 + level * 2,
          minX: 16.0,
          maxX: screenWidth - 16.0,
          color: const Color(0xFFFF1744),
          points: 500,
        ),
      );

      // Add guard bricks in front of the boss
      const cols = 6;
      const gap = 6.0;
      final bw = (screenWidth - 48 - gap * (cols - 1)) / cols;
      final totalW = cols * bw + gap * (cols - 1);
      final startX = (screenWidth - totalW) / 2;

      for (int c = 0; c < cols; c++) {
        bricks.add(
          Brick(
            x: startX + c * (bw + gap),
            y: baseTopMargin + bossH + 30,
            width: bw,
            height: 20.0,
            hp: 2,
            maxHp: 2,
            color: const Color(0xFFFF9100),
            points: 25,
          ),
        );
      }
      return bricks;
    }

    // Classic Mode: Advanced Procedural Generation (238 distinct levels)
    final rows = min(12, 4 + (level ~/ 10)); // Progressive rows
    final cols = 6 + ((level ~/ 15) % 4); // 6, 7, 8, or 9 columns
    const gap = 5.0;
    final padding = 16.0;
    final bw = (screenWidth - (padding * 2) - gap * (cols - 1)) / cols;
    final bh = 22.0;

    int pattern = level % 12; // 12 distinct base patterns
    if (level <= 5) {
      pattern = 0; // Standard Checkerboard
    } else if (level <= 10) {
      pattern = 7; // Dotted grid
    } else if (level <= 15) {
      pattern = 9; // Spaced rows
    }
    
    final hueOffset = (level * 23.0) % 360.0; // Color shift

    for (int r = 0; r < rows; r++) {
      for (int c = 0; c < cols; c++) {
        bool skip = false;
        
        // Procedural structural rules based on the 12 patterns
        switch (pattern) {
          case 0: skip = (r % 2 == 0 && c % 2 != 0) || (r % 2 != 0 && c % 2 == 0); break; // Checkerboard
          case 1: skip = (c == cols ~/ 2); break; // Split down the middle
          case 2: skip = (r + c) % 3 == 0; break; // Diagonal stripes
          case 3: skip = (r > c && r > (cols - c - 1)); break; // Pyramid
          case 4: skip = (r < c && r < (cols - c - 1)); break; // V-shape
          case 5: skip = (r == c || r == cols - c - 1); break; // X-shape
          case 6: skip = (r == 0 || r == rows - 1) && (c > 0 && c < cols - 1); break; // Bracket
          case 7: skip = (r.isEven && c.isEven); break; // Dotted
          case 8: skip = (c % 3 == 1); break; // Pillars
          case 9: skip = (r % 3 == 1); break; // Rows
          case 10: skip = (r > 1 && r < rows - 2 && c > 1 && c < cols - 2); break; // Hollow box
          case 11: skip = (r + c).isOdd && r > 2; break; // Half-checkerboard
        }

        if (skip) continue;

        // Colors using HSL to generate 238 unique palettes
        final hue = (hueOffset + (r * 15.0) + (c * 10.0)) % 360.0;
        final color = HSLColor.fromAHSL(1.0, hue, 0.8, 0.55).toColor();

        // Progressive Difficulty Rules
        final isSteel = (level > 4 && r == 0 && (c == 0 || c == cols - 1));
        final isMover = (level > 10 && r == rows - 1 && c % 4 == 0);
        final isHeavySteel = (level > 40 && isSteel && level % 3 == 0);

        final isDynamite = !isSteel && !isHeavySteel && level >= 3 && ((r * 7 + c * 13 + level * 5) % 29 == 0);
        final isIce = !isSteel && !isHeavySteel && !isDynamite && level >= 4 && ((r * 11 + c * 17 + level * 7) % 31 == 0);
        
        int hp = 1;
        if (!isSteel && !isHeavySteel) {
          if (isIce || isDynamite) {
            hp = 1;
          } else if (level > 15 && r < 2) {
            hp = 2; // Top rows have 2 HP
          } else if (level > 50 && (r + c) % 4 == 0) {
            hp = 3; // Occasional 3 HP
          }
        }
        if (isSteel) hp = 999;
        if (isHeavySteel) hp = 9999;

        bricks.add(
          Brick(
            x: padding + c * (bw + gap),
            y: baseTopMargin + r * (bh + gap),
            width: bw,
            height: bh,
            hp: hp,
            maxHp: hp,
            isSteel: isSteel,
            isHeavySteel: isHeavySteel,
            isMover: isMover,
            isDynamite: isDynamite,
            isIce: isIce,
            minX: padding,
            maxX: screenWidth - padding,
            color: isSteel ? const Color(0xFF78909C) : (hp > 1 ? color.withValues(alpha: 0.7) : color),
            points: isSteel ? 0 : (25 * hp),
          ),
        );
      }
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
