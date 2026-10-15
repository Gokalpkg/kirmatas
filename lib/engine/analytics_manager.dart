import 'dart:async';
import 'package:firebase_analytics/firebase_analytics.dart';

class AnalyticsManager {
  static final AnalyticsManager instance = AnalyticsManager._internal();
  AnalyticsManager._internal();

  FirebaseAnalytics? _analytics;
  bool _initialized = false;

  Future<void> init() async {
    if (_initialized) return;
    try {
      _analytics = FirebaseAnalytics.instance;
      _initialized = true;
    } catch (_) {}
  }

  Future<void> logLevelStart(int level, String mode) async {
    try {
      await _analytics?.logEvent(
        name: 'level_start',
        parameters: {
          'level_number': level,
          'game_mode': mode,
        },
      );
    } catch (_) {}
  }

  Future<void> logLevelComplete(int level, String mode, {required int score}) async {
    try {
      await _analytics?.logEvent(
        name: 'level_complete',
        parameters: {
          'level_number': level,
          'game_mode': mode,
          'score': score,
        },
      );
    } catch (_) {}
  }

  Future<void> logLevelFail(int level, String mode, {int bricksLeft = 0}) async {
    try {
      await _analytics?.logEvent(
        name: 'level_fail',
        parameters: {
          'level_number': level,
          'game_mode': mode,
          'bricks_remaining': bricksLeft,
        },
      );
    } catch (_) {}
  }

  Future<void> logAdWatched({required String adType, required String placement}) async {
    try {
      await _analytics?.logEvent(
        name: 'ad_reward_claimed',
        parameters: {
          'ad_type': adType,
          'placement': placement,
        },
      );
    } catch (_) {}
  }

  Future<void> logStatUpgraded(String statId, int newLevel) async {
    try {
      await _analytics?.logEvent(
        name: 'stat_upgrade_purchased',
        parameters: {
          'stat_id': statId,
          'target_level': newLevel,
        },
      );
    } catch (_) {}
  }
}
