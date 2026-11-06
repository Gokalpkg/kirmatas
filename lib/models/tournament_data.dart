import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'game_state.dart';
import '../storage/save_manager.dart';

/// Represents a single player's entry on the global weekly leaderboard.
class TournamentLeaderboardEntry {
  final String tag;
  final String name;
  final int weeklyScore;
  final int highScore;
  final int leagueTier;
  final bool isPlayer;
  int rank;
  final DateTime? lastActive;

  TournamentLeaderboardEntry({
    required this.tag,
    required this.name,
    required this.weeklyScore,
    this.highScore = 0,
    this.leagueTier = 0,
    this.isPlayer = false,
    this.rank = 0,
    this.lastActive,
  });

  Map<String, dynamic> toJson() => {
        'tag': tag,
        'name': name,
        'weeklyScore': weeklyScore,
        'highScore': highScore,
        'leagueTier': leagueTier,
        'isPlayer': isPlayer,
        'rank': rank,
        'lastActive': lastActive?.millisecondsSinceEpoch,
      };

  factory TournamentLeaderboardEntry.fromJson(Map<String, dynamic> json) =>
      TournamentLeaderboardEntry(
        tag: (json['tag'] as String?) ?? '',
        name: (json['name'] as String?) ?? 'Kaunos Pilotu',
        weeklyScore: (json['weeklyScore'] as num?)?.toInt() ?? 0,
        highScore: (json['highScore'] as num?)?.toInt() ?? 0,
        leagueTier: (json['leagueTier'] as num?)?.toInt() ?? 0,
        isPlayer: (json['isPlayer'] as bool?) ?? false,
        rank: (json['rank'] as num?)?.toInt() ?? 0,
        lastActive: json['lastActive'] != null
            ? DateTime.fromMillisecondsSinceEpoch((json['lastActive'] as num).toInt())
            : null,
      );
}

/// Service that coordinates real-time synchronization with Firebase Firestore
/// for the Global Leaderboard, with robust offline fallback.
class TournamentLeaderboardService {
  TournamentLeaderboardService._();
  static final TournamentLeaderboardService instance =
      TournamentLeaderboardService._();

  static const String _collectionName = 'kirmatas_players';

  /// True only when the most recent [fetchGlobalLeaderboard] call retrieved
  /// live records from Firebase Firestore rather than offline fallback data.
  bool lastFetchWasLiveCloud = false;

  /// Synchronizes the current player's score and profile to Firestore.
  Future<void> syncPlayerScore(SaveManager save) async {
    final cleanTag = save.playerTag.replaceAll('#', '').trim().toUpperCase();
    if (cleanTag.isEmpty) return;
    final docId = save.playerUuid.length >= 8
        ? '${cleanTag}_${save.playerUuid.substring(0, 8)}'
        : cleanTag;

    try {
      if (Firebase.apps.isEmpty) return;
      await FirebaseFirestore.instance.collection(_collectionName).doc(docId).set({
        'tag': save.playerTag,
        'uuid': save.playerUuid,
        'name': save.playerName,
        'weeklyScore': save.weeklyTournamentScore,
        'highScore': save.getHighScore(GameMode.classic),
        'chaosHighScore': save.getHighScore(GameMode.chaos),
        'leagueTier': save.leagueTier,
        'highestLevel': save.highestLevel,
        'prestigeTier': save.prestigeTier,
        'lastActiveMs': DateTime.now().millisecondsSinceEpoch,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true)).timeout(const Duration(seconds: 4));
    } catch (_) {
      // Offline fallback: ignore Firestore network errors
    }
  }

  /// Fetches the global top scores from Firestore.
  /// If offline or unavailable, falls back to simulated league champions.
  Future<List<TournamentLeaderboardEntry>> fetchGlobalLeaderboard({
    required SaveManager save,
    int limit = 50,
  }) async {
    final myCleanTag = save.playerTag.replaceAll('#', '').trim().toUpperCase();
    final List<TournamentLeaderboardEntry> list = [];

    try {
      if (Firebase.apps.isEmpty) {
        lastFetchWasLiveCloud = false;
        return getOfflineFallbackLeaderboard(save);
      }

      // 1. Sync current player first
      await syncPlayerScore(save);

      // 2. Query Firestore top weekly scores
      final snapshot = await FirebaseFirestore.instance
          .collection(_collectionName)
          .orderBy('weeklyScore', descending: true)
          .limit(limit)
          .get()
          .timeout(const Duration(seconds: 4));

      bool playerFoundInTop = false;

      for (final doc in snapshot.docs) {
        final data = doc.data();
        final rawTag = (data['tag'] as String?) ?? '#${doc.id}';
        final docUuid = (data['uuid'] as String?) ?? '';
        final cleanDocTag = rawTag.replaceAll('#', '').trim().toUpperCase();
        final isMe = (save.playerUuid.isNotEmpty && docUuid.isNotEmpty)
            ? docUuid == save.playerUuid
            : cleanDocTag == myCleanTag;
        if (isMe) playerFoundInTop = true;

        final rawName = data['name'] as String?;
        final name = isMe
            ? save.playerName
            : ((rawName != null && rawName.trim().isNotEmpty)
                ? rawName.trim()
                : 'Pilot $rawTag');

        final score = isMe
            ? save.weeklyTournamentScore
            : ((data['weeklyScore'] as num?)?.toInt() ?? 0);

        final hs = (data['highScore'] as num?)?.toInt() ?? 0;
        final tier = (data['leagueTier'] as num?)?.toInt() ?? 0;

        list.add(TournamentLeaderboardEntry(
          tag: isMe ? save.playerTag : rawTag,
          name: name,
          weeklyScore: score,
          highScore: hs,
          leagueTier: tier,
          isPlayer: isMe,
        ));
      }

      // If player wasn't in the top N, append player
      if (!playerFoundInTop) {
        list.add(TournamentLeaderboardEntry(
          tag: save.playerTag,
          name: save.playerName,
          weeklyScore: save.weeklyTournamentScore,
          highScore: save.getHighScore(GameMode.classic),
          leagueTier: save.leagueTier,
          isPlayer: true,
        ));
      }
      lastFetchWasLiveCloud = snapshot.docs.isNotEmpty;
    } catch (_) {
      // Firestore offline or unconfigured: fall back to simulated global rivals
      lastFetchWasLiveCloud = false;
      return getOfflineFallbackLeaderboard(save);
    }

    if (list.isEmpty) {
      lastFetchWasLiveCloud = false;
      return getOfflineFallbackLeaderboard(save);
    }

    // Sort descending by score
    list.sort((a, b) => b.weeklyScore.compareTo(a.weeklyScore));
    for (int i = 0; i < list.length; i++) {
      list[i].rank = i + 1;
    }
    return list;
  }

  /// Authentic simulated global leaderboard players when offline.
  List<TournamentLeaderboardEntry> getOfflineFallbackLeaderboard(SaveManager save) {
    const fallbackMasters = [
      ('Orion', '#KRM-9901', 14200, 4),
      ('VortexKral', '#KRM-8820', 12850, 4),
      ('NebulaViper', '#KRM-7731', 11400, 4),
      ('SolarisX', '#KRM-6612', 10100, 3),
      ('KozmikBalyoz', '#KRM-5544', 9450, 3),
      ('AstraGlaive', '#KRM-4489', 8800, 3),
      ('EgeFirtinasi', '#KRM-3310', 8100, 2),
      ('HyperNova', '#KRM-2299', 7500, 2),
      ('PulsarRider', '#KRM-1982', 6900, 2),
      ('AkdenizKartali', '#KRM-1744', 6250, 1),
      ('ZenithBreaker', '#KRM-1620', 5700, 1),
      ('QuantumEdge', '#KRM-1505', 5100, 1),
      ('KaunosKorsani', '#KRM-1422', 4500, 0),
      ('TitanGok', '#KRM-1311', 3900, 0),
      ('LapisLazuli', '#KRM-1204', 3200, 0),
    ];

    final myClean = save.playerTag.replaceAll('#', '').toUpperCase();
    final List<TournamentLeaderboardEntry> list = [];

    for (final m in fallbackMasters) {
      if (m.$2.replaceAll('#', '').toUpperCase() == myClean) continue;
      list.add(TournamentLeaderboardEntry(
        name: m.$1,
        tag: m.$2,
        weeklyScore: m.$3,
        highScore: m.$3 + 1500,
        leagueTier: m.$4,
        isPlayer: false,
      ));
    }

    // Add current player
    list.add(TournamentLeaderboardEntry(
      name: save.playerName,
      tag: save.playerTag,
      weeklyScore: save.weeklyTournamentScore,
      highScore: save.getHighScore(GameMode.classic),
      leagueTier: save.leagueTier,
      isPlayer: true,
    ));

    list.sort((a, b) => b.weeklyScore.compareTo(a.weeklyScore));
    for (int i = 0; i < list.length; i++) {
      list[i].rank = i + 1;
    }
    return list;
  }
}
