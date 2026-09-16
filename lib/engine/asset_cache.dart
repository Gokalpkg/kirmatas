import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import '../models/cosmetics.dart';
import '../models/powerup.dart';

class AssetCache {
  static final AssetCache instance = AssetCache._();
  AssetCache._();

  final Map<PowerUpType, ui.Image> _skillImages = {};
  final Map<String, ui.Image> _fishImages = {};
  bool _isReady = false;
  bool get isReady => _isReady;

  ui.Image? getSkillImage(PowerUpType type) => _skillImages[type];
  ui.Image? getFishImage(String id) => _fishImages[id];

  Future<void> init() async {
    // Load skills
    for (final type in PowerUpType.values) {
      try {
        final data = await rootBundle.load(type.assetPath);
        final bytes = data.buffer.asUint8List();
        final codec = await ui.instantiateImageCodec(bytes);
        final frame = await codec.getNextFrame();
        _skillImages[type] = frame.image;
      } catch (e) {
        debugPrint('Error loading skill image ${type.name}: $e');
      }
    }

    // Load fishes
    for (final fish in FishItem.allFish) {
      try {
        final data = await rootBundle.load(fish.assetPath);
        final bytes = data.buffer.asUint8List();
        final codec = await ui.instantiateImageCodec(bytes);
        final frame = await codec.getNextFrame();
        _fishImages[fish.id] = frame.image;
      } catch (e) {
        debugPrint('Error loading fish image ${fish.id}: $e');
      }
    }

    _isReady = true;
  }
}
