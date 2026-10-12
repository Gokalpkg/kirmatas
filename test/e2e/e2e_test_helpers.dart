import 'dart:math';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kirmatas/engine/game_controller.dart';
import 'package:kirmatas/models/game_state.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Common E2E Test Setup and Helpers for Kırmataş Quality & Visual Overhaul.
void setupE2ETestEnvironment() {
  TestWidgetsFlutterBinding.ensureInitialized();
  SharedPreferences.setMockInitialValues({});

  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
    const MethodChannel('xyz.luan/audioplayers.global'),
    (MethodCall methodCall) async => 1,
  );
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
    const MethodChannel('xyz.luan/audioplayers'),
    (MethodCall methodCall) async => 1,
  );
}

/// Creates a standard initialized [GameController] for testing with standard dimensions.
GameController createTestController({
  GameMode mode = GameMode.classic,
  double width = 360.0,
  double height = 640.0,
}) {
  final gc = GameController();
  gc.setDimensions(width, height);
  gc.startNewGame(mode);
  return gc;
}

/// Marks all breakable (non-steel, non-filled tuft) bricks as dead in the controller.
void clearAllBreakableBricks(GameController gc) {
  for (final b in gc.bricks) {
    if (!b.isSteel && !(b.isTuft && b.tuftFilled)) {
      b.hp = 0;
      b.isAlive = false;
    }
  }
}

/// Computes the bottom-most Y coordinate of any alive brick currently on the board.
double getLowestAliveBrickBottom(GameController gc) {
  double lowest = 0.0;
  for (final b in gc.bricks) {
    if (b.isAlive && (b.y + b.height) > lowest) {
      lowest = b.y + b.height;
    }
  }
  return lowest;
}

/// Computes the angular deflection in radians between two 2D velocity vectors.
double computeDeflectionAngle(double vx1, double vy1, double vx2, double vy2) {
  final angle1 = atan2(vy1, vx1);
  final angle2 = atan2(vy2, vx2);
  var diff = (angle2 - angle1).abs();
  while (diff > pi) {
    diff = (2 * pi - diff).abs();
  }
  return diff;
}
