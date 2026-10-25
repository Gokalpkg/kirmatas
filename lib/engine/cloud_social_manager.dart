import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/services.dart';
import '../models/game_state.dart';
import '../storage/save_manager.dart';

/// Supercell-style Social & Live Friends Manager powered by Firebase Firestore.
///
/// Features:
/// 1. Unique Kaunos ID / Friend Tag (#KRM-XXXX)
/// 2. Real-time cloud sync for player profile and scores
/// 3. Add friends via Friend Tag
/// 4. Live friend leaderboard with real scores
/// 5. Fully defensive: silent offline fallback on connectivity or permission limits
class CloudSocialManager {
  CloudSocialManager._();
  static final CloudSocialManager instance = CloudSocialManager._();

  static const String _collectionName = 'kirmatas_players';

  bool _syncing = false;
  bool get isSyncing => _syncing;

  /// Copies the player's Kaunos ID / Friend Tag to clipboard.
  Future<bool> copyPlayerTagToClipboard() async {
    try {
      final tag = SaveManager.instance.playerTag;
      await Clipboard.setData(ClipboardData(text: tag));
      HapticFeedback.lightImpact();
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Syncs player's current scores, rank, and name to Firestore.
  Future<void> syncProfileToCloud() async {
    if (_syncing) return;
    _syncing = true;
    try {
      final save = SaveManager.instance;
      final cleanTag = save.playerTag.replaceAll('#', '').trim().toUpperCase();
      if (cleanTag.isEmpty) return;

      await FirebaseFirestore.instance.collection(_collectionName).doc(cleanTag).set({
        'tag': save.playerTag,
        'name': save.playerName,
        'weeklyScore': save.weeklyTournamentScore,
        'highScore': save.getHighScore(GameMode.classic),
        'chaosHighScore': save.getHighScore(GameMode.chaos),
        'leagueTier': save.leagueTier,
        'highestLevel': save.highestLevel,
        'prestigeTier': save.prestigeTier,
        'activeBall': save.activeBall,
        'activePaddle': save.activePaddle,
        'lastActiveMs': DateTime.now().millisecondsSinceEpoch,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true)).timeout(const Duration(seconds: 4));
    } catch (_) {
      // Defensive fallback: runs smoothly offline or if Firestore is unprovisioned
    } finally {
      _syncing = false;
    }
  }

  /// Searches for a player by Friend Tag in Firestore and adds them as a friend.
  Future<({bool success, String message, RealFriend? friend})> addFriendByTag(String inputTag) async {
    final save = SaveManager.instance;
    var clean = inputTag.trim().toUpperCase().replaceAll(' ', '');
    if (clean.isEmpty) {
      return (success: false, message: 'Lütfen geçerli bir Oyuncu Kodu girin!', friend: null);
    }
    final fullTag = clean.startsWith('#') ? clean : '#$clean';

    if (fullTag == save.playerTag) {
      return (success: false, message: 'Kendi kodunu arkadaş olarak ekleyemezsin!', friend: null);
    }

    if (save.realFriends.any((f) => f.tag.toUpperCase() == fullTag)) {
      return (success: false, message: 'Bu oyuncu zaten arkadaş listenizde!', friend: null);
    }

    // Attempt cloud lookup via Firestore
    try {
      final docId = fullTag.replaceAll('#', '');
      final doc = await FirebaseFirestore.instance
          .collection(_collectionName)
          .doc(docId)
          .get()
          .timeout(const Duration(seconds: 5));

      if (doc.exists && doc.data() != null) {
        final data = doc.data()!;
        final rawName = data['name'] as String?;
        final friend = RealFriend(
          tag: fullTag,
          name: (rawName != null && rawName.trim().isNotEmpty) ? rawName.trim() : 'Oyuncu $fullTag',
          weeklyScore: (data['weeklyScore'] as num?)?.toInt() ?? 0,
          highScore: (data['highScore'] as num?)?.toInt() ?? 0,
          leagueTier: (data['leagueTier'] as num?)?.toInt() ?? 0,
          lastSeen: DateTime.now(),
        );
        await save.addRealFriend(friend);
        return (success: true, message: '${friend.name} arkadaş listene eklendi!', friend: friend);
      }
    } catch (_) {
      // Cloud query failed or offline
    }

    // Fallback: If cloud document isn't created yet or player is offline, add friend tag
    final fallbackFriend = RealFriend(
      tag: fullTag,
      name: 'Oyuncu $fullTag',
      weeklyScore: 0,
      highScore: 0,
      leagueTier: 0,
      lastSeen: DateTime.now(),
    );
    await save.addRealFriend(fallbackFriend);
    return (
      success: true,
      message: '$fullTag arkadaş listene eklendi! (Oyuncu oyuna girdiğinde skoru senkronize edilecek)',
      friend: fallbackFriend,
    );
  }

  /// Refreshes all added friends' scores from Firestore.
  Future<void> refreshFriendsFromCloud() async {
    final save = SaveManager.instance;
    if (save.realFriends.isEmpty) return;

    try {
      bool anyUpdated = false;
      for (final friend in save.realFriends) {
        final docId = friend.tag.replaceAll('#', '').toUpperCase();
        final doc = await FirebaseFirestore.instance
            .collection(_collectionName)
            .doc(docId)
            .get()
            .timeout(const Duration(seconds: 3));

        if (doc.exists && doc.data() != null) {
          final data = doc.data()!;
          final rawName = data['name'] as String?;
          if (rawName != null && rawName.trim().isNotEmpty) {
            friend.name = rawName.trim();
          }
          friend.weeklyScore = (data['weeklyScore'] as num?)?.toInt() ?? friend.weeklyScore;
          friend.highScore = (data['highScore'] as num?)?.toInt() ?? friend.highScore;
          friend.leagueTier = (data['leagueTier'] as num?)?.toInt() ?? friend.leagueTier;
          friend.lastSeen = DateTime.now();
          anyUpdated = true;
        }
      }
      if (anyUpdated) {
        await save.persistRealFriends();
      }
    } catch (_) {
      // Offline fallback
    }
  }
}
