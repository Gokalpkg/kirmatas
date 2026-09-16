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

    // Pick shape or grid based on level
    final shapes = [shapeHeart, shapeSword, shapeSmiley, shapeDiamond];
    final shapeIndex = (level - 1) % (shapes.length + 1);

    if (shapeIndex < shapes.length) {
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
            final isSteel = (level > 3 && r == 0 && (c == 0 || c == cols - 1));
            final isMover = (level > 6 && r == rows - 1 && c == 2);

            bricks.add(
              Brick(
                x: startX + c * (bw + gap),
                y: baseTopMargin + r * (bh + gap),
                width: bw,
                height: bh,
                hp: isSteel ? 999 : (level > 2 ? (r % 2 + 1) : 1),
                maxHp: isSteel ? 999 : (level > 2 ? (r % 2 + 1) : 1),
                isSteel: isSteel,
                isMover: isMover,
                minX: 16.0,
                maxX: screenWidth - 16.0,
                color: isSteel ? const Color(0xFFCFD8DC) : color,
                points: isSteel ? 0 : 20,
              ),
            );
          }
        }
      }
    } else {
      // Standard grid layout
      final rows = min(6, 4 + (level ~/ 3));
      const cols = 7;
      const gap = 6.0;
      final bw = (screenWidth - 36 - gap * (cols - 1)) / cols;
      final totalW = cols * bw + gap * (cols - 1);
      final startX = (screenWidth - totalW) / 2;
      final bh = 22.0;

      for (int r = 0; r < rows; r++) {
        for (int c = 0; c < cols; c++) {
          final color = icePalette[(r + c) % icePalette.length];
          bricks.add(
            Brick(
              x: startX + c * (bw + gap),
              y: baseTopMargin + r * (bh + gap),
              width: bw,
              height: bh,
              hp: (r < 2 && level > 2) ? 2 : 1,
              maxHp: (r < 2 && level > 2) ? 2 : 1,
              color: color,
              points: 15,
            ),
          );
        }
      }
    }

    return bricks;
  }

  static List<Brick> buildZenLevel(double screenWidth, double screenHeight) {
    final List<Brick> bricks = [];
    const rows = 4;
    const cols = 6;
    const gap = 8.0;
    final bw = (screenWidth - 36 - gap * (cols - 1)) / cols;
    final totalW = cols * bw + gap * (cols - 1);
    final startX = (screenWidth - totalW) / 2;
    final bh = 24.0;

    for (int r = 0; r < rows; r++) {
      for (int c = 0; c < cols; c++) {
        final color = candyPalette[(r * cols + c) % candyPalette.length];
        bricks.add(
          Brick(
            x: startX + c * (bw + gap),
            y: baseTopMargin + r * (bh + gap),
            width: bw,
            height: bh,
            hp: 1,
            maxHp: 1,
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

  static List<Brick> buildDescendRow(int rowIndex, double screenWidth, double screenHeight) {
    final List<Brick> rowBricks = [];
    const cols = 7;
    const gap = 6.0;
    final bw = (screenWidth - 32 - gap * (cols - 1)) / cols;
    final totalW = cols * bw + gap * (cols - 1);
    final startX = (screenWidth - totalW) / 2;
    const bh = 22.0;
    const rowStep = bh + gap; // 28.0

    final color = magmaPalette[rowIndex % magmaPalette.length];
    for (int c = 0; c < cols; c++) {
      rowBricks.add(
        Brick(
          x: startX + c * (bw + gap),
          y: baseTopMargin + rowIndex * rowStep,
          width: bw,
          height: bh,
          hp: 1,
          maxHp: 1,
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

  static List<Brick> buildTuftLevel(double screenWidth, double screenHeight) {
    final List<Brick> bricks = [];
    const rows = 5;
    const cols = 5;
    const gap = 8.0;
    final bw = (screenWidth - 40 - gap * (cols - 1)) / cols;
    final totalW = cols * bw + gap * (cols - 1);
    final startX = (screenWidth - totalW) / 2;
    final bh = 30.0;

    for (int r = 0; r < rows; r++) {
      for (int c = 0; c < cols; c++) {
        final color = tuftPalette[(r + c) % tuftPalette.length];
        bricks.add(
          Brick(
            x: startX + c * (bw + gap),
            y: baseTopMargin + r * (bh + gap),
            width: bw,
            height: bh,
            hp: 1,
            maxHp: 1,
            isTuft: true,
            tuftFilled: false,
            tuftColor: color,
            color: color.withValues(alpha: 0.25),
            points: 15,
          ),
        );
      }
    }
    return bricks;
  }
}
