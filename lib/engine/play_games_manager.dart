import 'dart:async';
import 'dart:io' show Platform;

import 'package:cloud_firestore/cloud_firestore.dart';
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
  String? _playerId;
  String? _playerName;
  String _statusText = 'Play Games kapalı';
  DateTime? _lastSync;
  bool _autoRestoreAttempted = false;
  bool _wasCloudRestored = false;
  Timer? _debounceSaveTimer;

  bool get signedIn => _signedIn;
  @visibleForTesting
  set mockSignedIn(bool value) {
    _signedIn = value;
    notifyListeners();
  }
  String? get playerId => _playerId;
  String? get playerName => _playerName;
  String get statusText => _statusText;
  DateTime? get lastSync => _lastSync;
  bool get wasCloudRestored => _wasCloudRestored;

  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;
    if (kIsWeb || !Platform.isAndroid) {
      _statusText = 'Oyun Servisleri kapalı';
      return;
    }
    try {
      GameAuth.player.listen((data) {
        _signedIn = data != null;
        _playerName = data?.displayName;
        if (data?.playerID != null && data!.playerID!.isNotEmpty) {
          _playerId = data.playerID;
        }
        _statusText = _signedIn
            ? (_playerName ?? 'Oyuncu bağlı')
            : 'Play Games kapalı';
        notifyListeners();
      });

      _signedIn = await GameAuth.isSignedIn;
      if (!_signedIn) {
        // Otomatik sessiz giriş: Oyunu silip tekrar yükleyen oyuncular için anında Play Games'e bağlanır.
        try {
          final res = await GameAuth.signIn();
          _signedIn = (res != null && res.isNotEmpty) || await GameAuth.isSignedIn;
        } catch (_) {}
      }

      if (_signedIn) {
        _statusText = 'Play Games bağlı';
        // Yeni kurulumda veya bulut verisi daha yeniyse otomatik geri yükle!
        final restored = await tryAutoRestore();
        if (!restored) {
          // Yerel veride ilerleme varsa ve bulut boşsa hemen buluta yedekle
          scheduleAutoSave();
        }
        await submitBestScores(SaveManager.instance);
      }

      // Oyundaki her kayıt ve ilerleme değişikliğini otomatik olarak buluta senkronize et
      SaveManager.instance.addListener(() {
        if (_signedIn) {
          scheduleAutoSave();
        }
      });

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

  /// Schedules a debounced auto-save to cloud so rapid actions don't spam network
  void scheduleAutoSave([SaveManager? save]) {
    _debounceSaveTimer?.cancel();
    _debounceSaveTimer = Timer(const Duration(seconds: 4), () {
      autoSaveToCloud(save);
    });
  }

  /// Automatically saves the entire game progress to Google Play Games cloud snapshot
  /// and Firestore redundancy silently in the background.
  Future<void> autoSaveToCloud([SaveManager? save]) async {
    if (!_signedIn) return;
    final manager = save ?? SaveManager.instance;
    // Don't overwrite an existing cloud save with an empty fresh local game
    if (manager.highestLevel <= 1 && manager.gold == 0 && manager.getHighScore(GameMode.classic) == 0) {
      return;
    }
    await saveToCloud(manager);
    await submitBestScores(manager);
  }

  Future<String> saveToCloud(SaveManager save) async {
    if (!_signedIn) return 'Önce giriş yap';
    try {
      final payload = await save.exportAllToJson();

      // 1. Google Play Games Saved Games Snapshot
      try {
        await SaveGame.saveGame(data: payload, name: _snapshotName);
      } catch (_) {}

      // 2. Firebase Firestore Dual-Redundancy Snapshot
      try {
        final batch = FirebaseFirestore.instance.batch();
        if (_playerId != null && _playerId!.isNotEmpty) {
          final docRef = FirebaseFirestore.instance.collection('kirmatas_cloud_saves').doc(_playerId);
          batch.set(docRef, {
            'payload': payload,
            'savedAtMs': DateTime.now().millisecondsSinceEpoch,
            'playerTag': save.playerTag,
            'playerName': save.playerName,
            'highestLevel': save.highestLevel,
            'gold': save.gold,
            'updatedAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));
        }
        final cleanTag = save.playerTag.replaceAll('#', '').trim().toUpperCase();
        if (cleanTag.isNotEmpty) {
          final tagDocRef = FirebaseFirestore.instance.collection('kirmatas_cloud_saves').doc('tag_$cleanTag');
          batch.set(tagDocRef, {
            'payload': payload,
            'savedAtMs': DateTime.now().millisecondsSinceEpoch,
            'playerTag': save.playerTag,
            'playerName': save.playerName,
            'highestLevel': save.highestLevel,
            'gold': save.gold,
            'updatedAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));
        }
        await batch.commit().timeout(const Duration(seconds: 4));
      } catch (_) {}

      await save.markLocalSavedNow();
      _lastSync = DateTime.now();
      _statusText = 'Buluta kaydedildi';
      notifyListeners();
      return 'Buluta kaydedildi';
    } catch (_) {
      _statusText = 'Bulut kaydı başarısız';
      notifyListeners();
      return 'Bulut kaydı başarısız';
    }
  }

  Future<String> loadFromCloud(SaveManager save) async {
    if (!_signedIn) return 'Önce giriş yap';
    try {
      String? raw;
      try {
        raw = await SaveGame.loadGame(name: _snapshotName);
      } catch (_) {}

      // Fallback to Firestore redundancy if needed
      if ((raw == null || raw.isEmpty) && _playerId != null && _playerId!.isNotEmpty) {
        try {
          final doc = await FirebaseFirestore.instance
              .collection('kirmatas_cloud_saves')
              .doc(_playerId)
              .get()
              .timeout(const Duration(seconds: 4));
          if (doc.exists) {
            raw = doc.data()?['payload'] as String?;
          }
        } catch (_) {}
      }

      if (raw == null || raw.isEmpty) return 'Bulutta kayıt bulunamadı';
      final ok = await save.importAllFromJson(raw);
      if (!ok) return 'Kayıt okunamadı';
      _lastSync = DateTime.now();
      _statusText = 'Buluttan yüklendi';
      notifyListeners();
      return 'Buluttan yüklendi';
    } catch (_) {
      return 'Buluttan yüklenemedi';
    }
  }

  /// Restores the cloud save only when it is newer than the local one
  /// or when this is a fresh install (e.g. after reinstalling the app).
  Future<bool> tryAutoRestore({SaveManager? save}) async {
    if (_autoRestoreAttempted) return false;
    _autoRestoreAttempted = true;
    try {
      final manager = save ?? SaveManager.instance;
      String? raw;

      // 1. First attempt: Google Play Games cloud snapshot
      try {
        raw = await SaveGame.loadGame(name: _snapshotName);
      } catch (_) {}

      // 2. Second attempt: Firestore cloud snapshot by Play Games playerId
      if ((raw == null || raw.isEmpty) && _playerId != null && _playerId!.isNotEmpty) {
        try {
          final doc = await FirebaseFirestore.instance
              .collection('kirmatas_cloud_saves')
              .doc(_playerId)
              .get()
              .timeout(const Duration(seconds: 4));
          if (doc.exists) {
            raw = doc.data()?['payload'] as String?;
          }
        } catch (_) {}
      }

      // 3. Third attempt: Firestore cloud snapshot by playerTag (preserved by Android backup)
      if (raw == null || raw.isEmpty) {
        try {
          final cleanTag = manager.playerTag.replaceAll('#', '').trim().toUpperCase();
          if (cleanTag.isNotEmpty) {
            final doc = await FirebaseFirestore.instance
                .collection('kirmatas_cloud_saves')
                .doc('tag_$cleanTag')
                .get()
                .timeout(const Duration(seconds: 4));
            if (doc.exists) {
              raw = doc.data()?['payload'] as String?;
            }
          }
        } catch (_) {}
      }

      if (raw == null || raw.isEmpty) return false;
      final cloudMs = SaveManager.cloudSavedAtMs(raw);
      if (cloudMs == null) return false;
      final localMs = manager.localSavedAtMs;
      final freshLocal = manager.highestLevel <= 1 && manager.gold == 0;
      final newer = cloudMs > localMs;

      if ((freshLocal || newer) && (freshLocal || cloudMs > 0)) {
        final ok = await manager.importAllFromJson(raw);
        if (ok) {
          _lastSync = DateTime.now();
          _statusText = 'Bulut kaydı geri yüklendi';
          _wasCloudRestored = true;
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
