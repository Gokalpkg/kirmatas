import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:games_services/games_services.dart';

import '../models/game_state.dart';
import '../storage/save_manager.dart';

/// Google Play Games bridge: silent sign-in + whole-save cloud snapshots.
///
/// Fully defensive: when Play Games is not configured yet (project id /
/// OAuth client missing on the developer console side) every call simply
/// fails silently and the game runs exactly as before.
class PlayGamesManager extends ChangeNotifier {
  PlayGamesManager._();
  static final PlayGamesManager instance = PlayGamesManager._();

  static const String _snapshotName = 'kirmatas_main';

  /// Play Games leaderboard ids (Play Console > Play Games services >
  /// Leaderboards > leaderboard details). An empty id makes every
  /// leaderboard call below no-op gracefully.
  /// classic: 'En Yüksek Skor', chaos: 'Kaos Skor'
  /// (both created 2026-10-21).
  static const String classicLeaderboardId = 'CgkIwf_oppkBEAIQAA';
  static const String chaosLeaderboardId = 'CgkIwf_oppkBEAIQAQ';

  bool get hasLeaderboard => classicLeaderboardId.isNotEmpty;

  bool _initialized = false;
  bool _signedIn = false;
  String? _playerName;
  String _statusText = 'Play Games kapalı';
  DateTime? _lastSync;

  bool get signedIn => _signedIn;
  @visibleForTesting
  set mockSignedIn(bool value) {
    _signedIn = value;
    notifyListeners();
  }
  String? get playerName => _playerName;
  String get statusText => _statusText;
  DateTime? get lastSync => _lastSync;

  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;
    try {
      GameAuth.player.listen((data) {
        _signedIn = data != null;
        _playerName = data?.displayName;
        _statusText = _signedIn
            ? (_playerName ?? 'Oyuncu bağlı')
            : 'Play Games kapalı';
        notifyListeners();
      });
      _signedIn = await GameAuth.isSignedIn;
      if (_signedIn) {
        _statusText = 'Play Games bağlı';
        // Only auto-restore when the cloud save is clearly newer/newer
        // equipment than a fresh local install.
        await tryAutoRestore();
        await submitBestScores(SaveManager.instance);
      }
      notifyListeners();
    } catch (_) {
      _signedIn = false;
      _statusText = 'Play Games kapalı';
    }
  }

  Future<String> signIn() async {
    try {
      final result = await GameAuth.signIn();
      _signedIn = (result != null && result.isNotEmpty) ||
          await GameAuth.isSignedIn;
      _statusText = _signedIn ? 'Bağlandın!' : 'Bağlantı kurulamadı';
      if (_signedIn) {
        await tryAutoRestore();
        await submitBestScores(SaveManager.instance);
      }
      notifyListeners();
      return _statusText;
    } catch (_) {
      _statusText = 'Play Games henüz hazır değil';
      notifyListeners();
      return _statusText;
    }
  }

  /// Pushes the player's best classic & chaos scores to Play Games
  /// leaderboards (real global ranking). Silent no-op while signed out
  /// or while the leaderboard ids are not filled in yet.
  Future<void> submitBestScores(SaveManager save) async {
    if (!_signedIn) return;
    try {
      if (classicLeaderboardId.isNotEmpty) {
        final best = save.getHighScore(GameMode.classic);
        if (best > 0) {
          await Leaderboards.submitScore(
            score: Score(androidLeaderboardID: classicLeaderboardId, value: best),
          );
        }
      }
      if (chaosLeaderboardId.isNotEmpty) {
        final best = save.getHighScore(GameMode.chaos);
        if (best > 0) {
          await Leaderboards.submitScore(
            score: Score(androidLeaderboardID: chaosLeaderboardId, value: best),
          );
        }
      }
    } catch (_) {}
  }

  /// Opens the native Play Games leaderboard screen.
  /// If [mode] is specified, opens that board directly; otherwise opens all leaderboards.
  Future<String> showLeaderboard({GameMode? mode}) async {
    if (!_signedIn) return 'Önce giriş yap';
    final targetId = mode == GameMode.chaos
        ? chaosLeaderboardId
        : (mode == GameMode.classic ? classicLeaderboardId : null);
    try {
      if (targetId != null && targetId.isNotEmpty) {
        await Leaderboards.showLeaderboards(androidLeaderboardID: targetId);
      } else {
        await Leaderboards.showLeaderboards();
      }
      return 'Sıralama açıldı';
    } catch (_) {
      return 'Sıralama açılamadı';
    }
  }

  /// Opens the native Play Games achievements screen.
  Future<String> showAchievements() async {
    if (!_signedIn) return 'Önce giriş yap';
    try {
      await Achievements.showAchievements();
      return 'Başarımlar açıldı';
    } catch (_) {
      return 'Başarımlar açılamadı';
    }
  }

  /// Unlocks an achievement on Google Play Games Services defensively.
  Future<void> unlockAchievement(String androidId) async {
    if (!_signedIn || androidId.isEmpty) return;
    try {
      await Achievements.unlock(
        achievement: Achievement(androidID: androidId),
      );
    } catch (_) {}
  }

  /// Increments an incremental achievement on Google Play Games Services defensively.
  Future<void> incrementAchievement(String androidId, {int steps = 1}) async {
    if (!_signedIn || androidId.isEmpty || steps <= 0) return;
    try {
      await Achievements.increment(
        achievement: Achievement(androidID: androidId, steps: steps),
      );
    } catch (_) {}
  }

  Future<String> saveToCloud(SaveManager save) async {
    if (!_signedIn) return 'Önce giriş yap';
    try {
      final payload = await save.exportAllToJson();
      await SaveGame.saveGame(data: payload, name: _snapshotName);
      await save.markLocalSavedNow();
      _lastSync = DateTime.now();
      _statusText = 'Buluta kaydedildi';
      notifyListeners();
      return 'Buluta kaydedildi ✓';
    } catch (_) {
      _statusText = 'Bulut kaydı başarısız';
      notifyListeners();
      return 'Bulut kaydı başarısız';
    }
  }

  Future<String> loadFromCloud(SaveManager save) async {
    if (!_signedIn) return 'Önce giriş yap';
    try {
      final raw = await SaveGame.loadGame(name: _snapshotName);
      if (raw == null || raw.isEmpty) return 'Bulutta kayıt bulunamadı';
      final ok = await save.importAllFromJson(raw);
      if (!ok) return 'Kayıt okunamadı';
      _lastSync = DateTime.now();
      _statusText = 'Buluttan yüklendi';
      notifyListeners();
      return 'Buluttan yüklendi ✓';
    } catch (_) {
      return 'Buluttan yüklenemedi';
    }
  }

  /// Restores the cloud save only when it is newer than the local one
  /// and actually contains progress (never clobbers a real local game
  /// with an older cloud stub).
  Future<bool> tryAutoRestore({SaveManager? save}) async {
    try {
      final manager = save ?? SaveManager.instance;
      final raw = await SaveGame.loadGame(name: _snapshotName);
      if (raw == null || raw.isEmpty) return false;
      final cloudMs = SaveManager.cloudSavedAtMs(raw);
      if (cloudMs == null) return false;
      final localMs = manager.localSavedAtMs;
      final freshLocal = manager.highestLevel <= 1;
      final newer = cloudMs > localMs;
      if ((freshLocal || newer) && (freshLocal || cloudMs > 0)) {
        final ok = await manager.importAllFromJson(raw);
        if (ok) {
          _lastSync = DateTime.now();
          _statusText = 'Bulut kaydı geri yüklendi';
          notifyListeners();
        }
        return ok;
      }
      return false;
    } catch (_) {
      return false;
    }
  }
}
