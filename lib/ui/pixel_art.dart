import 'dart:math';
import 'package:flutter/material.dart';
import '../models/powerup.dart';

class PixelArt {
  // 8x8 bitmap matrices for each powerup type
  static const Map<PowerUpType, List<List<int>>> bitmaps = {
    PowerUpType.life: [
      [0, 1, 1, 0, 0, 1, 1, 0],
      [1, 2, 1, 1, 1, 1, 1, 1],
      [1, 1, 1, 1, 1, 1, 1, 1],
      [1, 1, 1, 1, 1, 1, 1, 1],
      [0, 1, 1, 1, 1, 1, 1, 0],
      [0, 0, 1, 1, 1, 1, 0, 0],
      [0, 0, 0, 1, 1, 0, 0, 0],
      [0, 0, 0, 0, 0, 0, 0, 0],
    ],
    PowerUpType.fireball: [
      [0, 0, 0, 1, 0, 0, 0, 0],
      [0, 0, 1, 2, 0, 1, 0, 0],
      [0, 1, 1, 2, 1, 1, 0, 0],
      [0, 1, 2, 2, 1, 1, 1, 0],
      [1, 1, 2, 2, 2, 1, 1, 0],
      [1, 1, 2, 2, 2, 1, 1, 0],
      [0, 1, 1, 2, 1, 1, 0, 0],
      [0, 0, 1, 1, 1, 0, 0, 0],
    ],
    PowerUpType.laser: [
      [0, 0, 0, 1, 1, 0, 0, 0],
      [0, 0, 1, 2, 1, 0, 0, 0],
      [0, 1, 1, 2, 0, 0, 0, 0],
      [1, 1, 2, 2, 1, 1, 0, 0],
      [0, 0, 0, 2, 2, 1, 1, 0],
      [0, 0, 1, 2, 1, 0, 0, 0],
      [0, 1, 1, 0, 0, 0, 0, 0],
      [0, 1, 0, 0, 0, 0, 0, 0],
    ],
    PowerUpType.lightning: [
      [0, 0, 0, 1, 1, 0, 0, 0],
      [0, 0, 1, 2, 0, 0, 0, 0],
      [0, 1, 2, 0, 0, 0, 0, 0],
      [1, 1, 2, 2, 1, 1, 0, 0],
      [0, 0, 1, 2, 0, 0, 0, 0],
      [0, 1, 2, 0, 0, 0, 0, 0],
      [0, 1, 0, 0, 0, 0, 0, 0],
      [0, 0, 0, 0, 0, 0, 0, 0],
    ],
    PowerUpType.bomb: [
      [0, 0, 0, 0, 2, 1, 0, 0],
      [0, 0, 0, 1, 0, 0, 0, 0],
      [0, 0, 1, 1, 1, 0, 0, 0],
      [0, 1, 2, 1, 1, 1, 0, 0],
      [1, 2, 1, 1, 1, 1, 1, 0],
      [1, 1, 1, 1, 1, 1, 1, 0],
      [0, 1, 1, 1, 1, 1, 0, 0],
      [0, 0, 1, 1, 1, 0, 0, 0],
    ],
    PowerUpType.doublescore: [
      [0, 0, 0, 1, 1, 0, 0, 0],
      [0, 0, 0, 2, 2, 0, 0, 0],
      [1, 1, 1, 2, 2, 1, 1, 1],
      [0, 1, 2, 2, 2, 2, 1, 0],
      [0, 0, 1, 2, 2, 1, 0, 0],
      [0, 1, 2, 0, 0, 2, 1, 0],
      [1, 1, 0, 0, 0, 0, 1, 1],
      [1, 0, 0, 0, 0, 0, 0, 1],
    ],
    PowerUpType.shield: [
      [1, 1, 1, 1, 1, 1, 1, 1],
      [1, 2, 2, 2, 2, 2, 2, 1],
      [1, 2, 1, 1, 1, 1, 2, 1],
      [0, 1, 2, 1, 1, 2, 1, 0],
      [0, 1, 2, 1, 1, 2, 1, 0],
      [0, 0, 1, 2, 2, 1, 0, 0],
      [0, 0, 0, 1, 1, 0, 0, 0],
      [0, 0, 0, 0, 0, 0, 0, 0],
    ],
    PowerUpType.net: [
      [1, 0, 1, 0, 1, 0, 1, 0],
      [0, 1, 0, 1, 0, 1, 0, 1],
      [1, 1, 1, 1, 1, 1, 1, 1],
      [0, 1, 0, 1, 0, 1, 0, 1],
      [1, 0, 1, 0, 1, 0, 1, 0],
      [1, 1, 1, 1, 1, 1, 1, 1],
      [0, 1, 0, 1, 0, 1, 0, 1],
      [1, 0, 1, 0, 1, 0, 1, 0],
    ],
    PowerUpType.wide: [
      [0, 0, 0, 0, 0, 0, 0, 0],
      [1, 0, 0, 0, 0, 0, 0, 1],
      [1, 1, 0, 0, 0, 0, 1, 1],
      [1, 1, 1, 1, 1, 1, 1, 1],
      [1, 1, 1, 1, 1, 1, 1, 1],
      [1, 1, 0, 0, 0, 0, 1, 1],
      [1, 0, 0, 0, 0, 0, 0, 1],
      [0, 0, 0, 0, 0, 0, 0, 0],
    ],
    PowerUpType.shrink: [
      [0, 0, 0, 0, 0, 0, 0, 0],
      [0, 0, 1, 0, 0, 1, 0, 0],
      [0, 0, 0, 1, 1, 0, 0, 0],
      [0, 0, 1, 1, 1, 1, 0, 0],
      [0, 0, 1, 1, 1, 1, 0, 0],
      [0, 0, 0, 1, 1, 0, 0, 0],
      [0, 0, 1, 0, 0, 1, 0, 0],
      [0, 0, 0, 0, 0, 0, 0, 0],
    ],
    PowerUpType.multi: [
      [0, 0, 1, 1, 0, 0, 0, 0],
      [0, 0, 1, 1, 0, 0, 0, 0],
      [0, 0, 0, 0, 0, 0, 0, 0],
      [1, 1, 0, 0, 0, 0, 1, 1],
      [1, 1, 0, 0, 0, 0, 1, 1],
      [0, 0, 0, 0, 0, 0, 0, 0],
      [0, 0, 0, 1, 1, 0, 0, 0],
      [0, 0, 0, 1, 1, 0, 0, 0],
    ],
    PowerUpType.slow: [
      [1, 1, 1, 1, 1, 1, 1, 1],
      [0, 1, 2, 2, 2, 2, 1, 0],
      [0, 0, 1, 2, 2, 1, 0, 0],
      [0, 0, 0, 1, 1, 0, 0, 0],
      [0, 0, 1, 2, 2, 1, 0, 0],
      [0, 1, 2, 2, 2, 2, 1, 0],
      [1, 1, 1, 1, 1, 1, 1, 1],
      [0, 0, 0, 0, 0, 0, 0, 0],
    ],
    PowerUpType.fastball: [
      [0, 0, 1, 0, 0, 1, 0, 0],
      [0, 0, 0, 1, 0, 0, 1, 0],
      [1, 1, 1, 1, 1, 1, 1, 1],
      [0, 0, 0, 1, 0, 0, 1, 0],
      [0, 0, 1, 0, 0, 1, 0, 0],
      [0, 0, 0, 0, 0, 0, 0, 0],
      [1, 1, 1, 1, 1, 1, 1, 1],
      [0, 0, 0, 0, 0, 0, 0, 0],
    ],
    PowerUpType.sticky: [
      [1, 1, 0, 0, 0, 0, 1, 1],
      [1, 2, 0, 0, 0, 0, 2, 1],
      [1, 1, 0, 0, 0, 0, 1, 1],
      [1, 1, 0, 0, 0, 0, 1, 1],
      [1, 1, 1, 1, 1, 1, 1, 1],
      [0, 1, 2, 2, 2, 2, 1, 0],
      [0, 0, 1, 1, 1, 1, 0, 0],
      [0, 0, 0, 0, 0, 0, 0, 0],
    ],
    PowerUpType.rocket: [
      [0, 0, 0, 1, 1, 0, 0, 0],
      [0, 0, 1, 2, 2, 1, 0, 0],
      [0, 0, 1, 2, 2, 1, 0, 0],
      [0, 1, 1, 2, 2, 1, 1, 0],
      [0, 1, 1, 1, 1, 1, 1, 0],
      [1, 1, 1, 1, 1, 1, 1, 1],
      [1, 0, 0, 2, 2, 0, 0, 1],
      [0, 0, 0, 1, 1, 0, 0, 0],
    ],
    PowerUpType.invis: [
      [0, 0, 1, 1, 1, 1, 0, 0],
      [0, 1, 1, 1, 1, 1, 1, 0],
      [1, 1, 0, 1, 1, 0, 1, 1],
      [1, 1, 0, 1, 1, 0, 1, 1],
      [1, 1, 1, 1, 1, 1, 1, 1],
      [1, 1, 1, 1, 1, 1, 1, 1],
      [1, 0, 1, 0, 0, 1, 0, 1],
      [0, 0, 0, 0, 0, 0, 0, 0],
    ],
    PowerUpType.clumsy: [
      [0, 0, 0, 1, 1, 0, 0, 0],
      [1, 0, 0, 1, 1, 0, 0, 1],
      [0, 1, 0, 1, 1, 0, 1, 0],
      [1, 1, 1, 2, 2, 1, 1, 1],
      [0, 1, 0, 1, 1, 0, 1, 0],
      [1, 0, 0, 1, 1, 0, 0, 1],
      [0, 0, 0, 1, 1, 0, 0, 0],
      [0, 0, 0, 0, 0, 0, 0, 0],
    ],
    PowerUpType.drone: [
      [0, 1, 0, 0, 0, 0, 1, 0],
      [0, 0, 1, 0, 0, 1, 0, 0],
      [0, 0, 1, 1, 1, 1, 0, 0],
      [1, 1, 1, 2, 2, 1, 1, 1],
      [0, 0, 1, 1, 1, 1, 0, 0],
      [0, 0, 1, 0, 0, 1, 0, 0],
      [0, 1, 0, 0, 0, 0, 1, 0],
      [0, 0, 0, 0, 0, 0, 0, 0],
    ],
    PowerUpType.chrono: [
      [0, 1, 1, 1, 1, 1, 1, 0],
      [1, 2, 2, 2, 2, 2, 2, 1],
      [1, 2, 0, 1, 0, 0, 2, 1],
      [1, 2, 0, 1, 1, 0, 2, 1],
      [1, 2, 0, 0, 0, 0, 2, 1],
      [1, 2, 2, 2, 2, 2, 2, 1],
      [0, 1, 1, 1, 1, 1, 1, 0],
      [0, 0, 0, 0, 0, 0, 0, 0],
    ],
    PowerUpType.reverse: [
      [0, 0, 1, 1, 1, 1, 0, 0],
      [0, 1, 0, 0, 0, 0, 1, 0],
      [1, 1, 0, 0, 0, 0, 1, 1],
      [1, 0, 0, 0, 0, 0, 0, 1],
      [1, 1, 1, 1, 0, 0, 0, 0],
      [0, 0, 0, 0, 1, 1, 1, 1],
      [0, 0, 0, 0, 0, 0, 0, 0],
      [0, 0, 0, 0, 0, 0, 0, 0],
    ],
    PowerUpType.vortex: [
      [0, 1, 1, 1, 1, 1, 0, 0],
      [1, 0, 0, 0, 0, 0, 1, 0],
      [1, 0, 1, 1, 1, 0, 1, 0],
      [1, 0, 1, 2, 1, 0, 1, 0],
      [1, 0, 1, 1, 1, 0, 1, 0],
      [1, 0, 0, 0, 0, 0, 1, 0],
      [0, 1, 1, 1, 1, 1, 0, 0],
      [0, 0, 0, 0, 0, 0, 0, 0],
    ],
    PowerUpType.pierce: [
      [0, 0, 0, 1, 1, 0, 0, 0],
      [0, 0, 1, 2, 2, 1, 0, 0],
      [0, 1, 1, 2, 2, 1, 1, 0],
      [1, 1, 0, 2, 2, 0, 1, 1],
      [0, 0, 0, 2, 2, 0, 0, 0],
      [0, 0, 0, 2, 2, 0, 0, 0],
      [0, 0, 0, 1, 1, 0, 0, 0],
      [0, 0, 0, 0, 0, 0, 0, 0],
    ],
  };

  static const List<List<int>> heartMatrix = [
    [0, 0, 1, 1, 1, 0, 0, 1, 1, 1, 0, 0],
    [0, 1, 4, 5, 4, 1, 1, 3, 3, 3, 1, 0],
    [1, 4, 5, 5, 4, 3, 3, 3, 3, 3, 3, 1],
    [1, 4, 4, 3, 3, 3, 3, 3, 3, 3, 2, 1],
    [1, 3, 3, 3, 3, 3, 3, 3, 3, 2, 2, 1],
    [0, 1, 3, 3, 3, 3, 3, 3, 2, 2, 1, 0],
    [0, 0, 1, 3, 3, 3, 3, 2, 2, 1, 0, 0],
    [0, 0, 0, 1, 3, 3, 2, 2, 1, 0, 0, 0],
    [0, 0, 0, 0, 1, 3, 2, 1, 0, 0, 0, 0],
    [0, 0, 0, 0, 0, 1, 1, 0, 0, 0, 0, 0],
  ];

  static final Paint _heartGlowPaint = Paint()..style = PaintingStyle.fill..isAntiAlias = true;
  static final Paint _heartPxPaint = Paint()..style = PaintingStyle.fill..isAntiAlias = false;

  static void drawPixelHeart(Canvas canvas, Offset center, double size, {double pulse = 1.0}) {
    canvas.save();
    canvas.translate(center.dx, center.dy);
    if (pulse != 1.0) {
      canvas.scale(pulse, pulse);
    }

    final rows = heartMatrix.length;
    final cols = heartMatrix[0].length;
    final pixelSize = size / max(rows, cols);

    final left = - (cols * pixelSize) / 2;
    final top = - (rows * pixelSize) / 2;

    // Glowing aura behind heart (2-pass concentric alpha layering, ZERO blur overhead)
    _heartGlowPaint.color = const Color(0xFFFF1744).withValues(alpha: 0.18);
    canvas.drawCircle(Offset.zero, size * 0.55, _heartGlowPaint);
    _heartGlowPaint.color = const Color(0xFFFF1744).withValues(alpha: 0.38);
    canvas.drawCircle(Offset.zero, size * 0.42, _heartGlowPaint);
    for (int r = 0; r < rows; r++) {
      for (int c = 0; c < cols; c++) {
        final val = heartMatrix[r][c];
        if (val == 0) continue;

        Color col;
        switch (val) {
          case 1:
            col = const Color(0xFF2B0007);
            break;
          case 2:
            col = const Color(0xFF8E001A);
            break;
          case 3:
            col = const Color(0xFFFF1744);
            break;
          case 4:
            col = const Color(0xFFFF6188);
            break;
          case 5:
            col = Colors.white;
            break;
          default:
            col = const Color(0xFFFF1744);
        }

        _heartPxPaint.color = col;
        final px = left + c * pixelSize;
        final py = top + r * pixelSize;
        canvas.drawRect(Rect.fromLTWH(px, py, pixelSize + 0.2, pixelSize + 0.2), _heartPxPaint);
      }
    }
    canvas.restore();
  }

  static void draw(Canvas canvas, PowerUpType type, Offset center, double size) {
    if (type == PowerUpType.life) {
      drawPixelHeart(canvas, center, size);
      return;
    }

    final matrix = bitmaps[type] ?? bitmaps[PowerUpType.life]!;
    final rows = matrix.length;
    final cols = matrix[0].length;
    final pixelSize = size / cols;

    final primaryColor = type.color;
    final highlightColor = Colors.white;

    final left = center.dx - size / 2;
    final top = center.dy - size / 2;

    // Outer backing tile
    final tileRect = Rect.fromCenter(center: center, width: size + 8, height: size + 8);
    final tileRRect = RRect.fromRectAndRadius(tileRect, const Radius.circular(8));
    final tilePaint = Paint()..color = const Color(0xDD0C0F1A);
    canvas.drawRRect(tileRRect, tilePaint);

    final borderPaint = Paint()
      ..color = primaryColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;
    canvas.drawRRect(tileRRect, borderPaint);

    // Glow aura around tile
    final glowPaint = Paint()
      ..color = primaryColor.withValues(alpha: 0.35)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.5;
    canvas.drawRRect(tileRRect.inflate(2.0), glowPaint);

    // Draw pixels
    for (int r = 0; r < rows; r++) {
      for (int c = 0; c < cols; c++) {
        final val = matrix[r][c];
        if (val == 0) continue;

        final px = left + c * pixelSize;
        final py = top + r * pixelSize;
        final rect = Rect.fromLTWH(px, py, pixelSize - 0.5, pixelSize - 0.5);

        final paint = Paint()..color = (val == 2) ? highlightColor : primaryColor;
        canvas.drawRect(rect, paint);
      }
    }
  }

  // 26x26 Pixel Art Splat Matrix directly matching Image 2 bug splat reference:
  // 0: transparent, 1: primary red, 2: dark clot red, 3: bright droplet red
  static const List<List<int>> bugSplatMatrix = [
    [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0],
    [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 3, 0, 3, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0],
    [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0],
    [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0],
    [0, 0, 0, 0, 0, 0, 0, 3, 0, 0, 0, 0, 0, 0, 1, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0],
    [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 1, 0, 0, 0, 0, 0, 0, 0],
    [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 1, 0, 1, 1, 1, 1, 0, 3, 0, 0, 0, 0],
    [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 0, 3, 0, 0, 0],
    [0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 1, 2, 2, 2, 2, 2, 2, 1, 1, 1, 1, 0, 0, 0, 0, 0],
    [0, 0, 0, 0, 0, 0, 3, 0, 1, 1, 2, 2, 2, 2, 2, 2, 2, 2, 1, 1, 1, 1, 0, 3, 0, 0],
    [0, 0, 0, 0, 0, 0, 0, 0, 1, 1, 2, 2, 2, 2, 2, 2, 2, 2, 2, 1, 1, 1, 0, 0, 0, 0],
    [0, 0, 0, 0, 0, 0, 0, 1, 1, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 1, 1, 0, 0, 3, 0, 0],
    [0, 0, 0, 0, 0, 3, 0, 0, 1, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 1, 1, 0, 0, 0, 0],
    [0, 0, 0, 0, 0, 3, 0, 1, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 1, 0, 0, 0, 0],
    [0, 0, 0, 0, 0, 0, 0, 0, 1, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 1, 0, 0, 3, 0, 0],
    [0, 0, 0, 0, 0, 3, 0, 0, 1, 2, 2, 2, 2, 2, 2, 2, 2, 2, 1, 1, 0, 0, 0, 0, 0, 0],
    [0, 0, 0, 0, 0, 3, 3, 1, 0, 1, 2, 2, 2, 2, 2, 2, 1, 1, 0, 1, 1, 0, 0, 0, 0, 0],
    [0, 0, 0, 0, 0, 0, 0, 0, 1, 1, 1, 1, 2, 2, 2, 1, 1, 1, 1, 0, 0, 0, 3, 0, 0, 0],
    [0, 0, 0, 0, 0, 0, 0, 3, 0, 1, 1, 0, 1, 1, 1, 1, 1, 0, 1, 1, 3, 0, 0, 0, 0, 0],
    [0, 0, 0, 0, 0, 0, 3, 0, 0, 1, 0, 1, 1, 0, 1, 1, 0, 1, 1, 0, 0, 0, 0, 0, 0, 0],
    [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 1, 0, 1, 0, 1, 0, 0, 3, 0, 0, 0, 0, 0],
    [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 3, 0, 1, 1, 0, 3, 0, 0, 0, 0, 0, 0, 0],
    [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 3, 0, 3, 0, 3, 0, 0, 0, 0, 0, 0, 0, 0],
    [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 3, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0],
    [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0],
    [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0],
  ];
}

class PixelHeart extends StatelessWidget {
  final double size;
  const PixelHeart({super.key, this.size = 16.0});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _PixelHeartWidgetPainter(),
      ),
    );
  }
}

class _PixelHeartWidgetPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    PixelArt.drawPixelHeart(canvas, Offset(size.width / 2, size.height / 2), size.width);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
