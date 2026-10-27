import 'dart:async';
import 'package:flutter/material.dart';

/// Base class for all decoupled game events.
abstract class GameEvent {
  final DateTime timestamp;
  GameEvent() : timestamp = DateTime.now();
}

/// Dispatched whenever a brick is hit or destroyed.
class BrickDestroyedEvent extends GameEvent {
  final Offset position;
  final int brickTypeIndex;
  final int comboCount;
  final bool wasSolid;
  final int goldAwarded;

  BrickDestroyedEvent({
    required this.position,
    required this.brickTypeIndex,
    required this.comboCount,
    required this.wasSolid,
    required this.goldAwarded,
  });
}

/// Dispatched when the player reaches a significant combo streak.
class ComboMilestoneEvent extends GameEvent {
  final int comboCount;
  final bool isFever;
  final Offset triggerPosition;

  ComboMilestoneEvent({
    required this.comboCount,
    required this.isFever,
    required this.triggerPosition,
  });
}

/// Dispatched upon victorious completion of a level.
class LevelClearedEvent extends GameEvent {
  final int levelNumber;
  final int score;
  final int goldEarned;
  final int starsAwarded;

  LevelClearedEvent({
    required this.levelNumber,
    required this.score,
    required this.goldEarned,
    required this.starsAwarded,
  });
}

/// Dispatched when coins are earned in-game, orchestrating the 5-step juicy vacuum.
class GoldCollectedEvent extends GameEvent {
  final int amount;
  final Offset sourcePosition;

  GoldCollectedEvent({
    required this.amount,
    required this.sourcePosition,
  });
}

/// Dispatched when an achievement is successfully unlocked.
class AchievementUnlockedEvent extends GameEvent {
  final String achievementId;
  final String name;
  final String description;
  final int points;

  AchievementUnlockedEvent({
    required this.achievementId,
    required this.name,
    required this.description,
    required this.points,
  });
}

/// High-performance, lightweight singleton event bus providing pub/sub decoupling
/// between GameController physics/loop and UI/Audio/VFX feedback systems.
class GameEventBus {
  static final GameEventBus _instance = GameEventBus._internal();
  factory GameEventBus() => _instance;
  GameEventBus._internal();

  final StreamController<GameEvent> _eventStream = StreamController<GameEvent>.broadcast();

  /// Stream of all published game events.
  Stream<GameEvent> get stream => _eventStream.stream;

  /// Typed listener for specific event subclasses.
  Stream<T> on<T extends GameEvent>() {
    return _eventStream.stream.where((event) => event is T).cast<T>();
  }

  /// Publishes an event to all active listeners.
  void fire(GameEvent event) {
    if (!_eventStream.isClosed) {
      _eventStream.add(event);
    }
  }

  /// Disposes stream controller when resetting.
  void dispose() {
    _eventStream.close();
  }
}
