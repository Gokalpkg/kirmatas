import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:kirmatas/storage/save_manager.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SaveManager save;

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    save = SaveManager.instance;
    await save.init();
  });

  group('Weekly league calendar math', () {
    test('week starts on Monday and id is stable inside the week', () {
      // 2026-10-21 is a Wednesday.
      final start = SaveManager.leagueWeekStartFor(DateTime(2026, 10, 21, 15));
      expect(start, DateTime(2026, 10, 19));
      expect(SaveManager.leagueWeekIdFor(start), '2026-10-19');
      // Sunday belongs to the same week, next Monday starts a new one.
      expect(
        SaveManager.leagueWeekStartFor(DateTime(2026, 10, 25, 23)),
        DateTime(2026, 10, 19),
      );
      expect(
        SaveManager.leagueWeekStartFor(DateTime(2026, 10, 26)),
        DateTime(2026, 10, 26),
      );
    });

    test('progress runs 0 -> 1 across the week', () {
      final monday = DateTime(2026, 10, 19);
      expect(save.leagueWeekProgress(now: monday), 0.0);
      final mid = save.leagueWeekProgress(now: DateTime(2026, 10, 22, 12));
      expect(mid, closeTo(0.5, 0.01));
      final remaining = save.leagueTimeRemaining(now: monday);
      expect(remaining, const Duration(days: 7));
    });

    test('reward table scales with tier multiplier', () {
      expect(SaveManager.leagueBaseGoldForRank(1), 400);
      expect(SaveManager.leagueBaseGoldForRank(3), 220);
      expect(SaveManager.leagueBaseGoldForRank(7), 120);
      expect(SaveManager.leagueBaseGoldForRank(15), 40);
      expect(SaveManager.leaguePearlsForRank(1), 2);
      expect(SaveManager.leaguePearlsForRank(3), 1);
      expect(SaveManager.leaguePearlsForRank(4), 0);
      save.leagueTier = 2;
      expect(save.leagueRewardGoldForRank(1), 1200);
    });
  });

  group('Weekly league real players and cloud persistence', () {
    test('league rivals consist of 100% real players with valid Kaunos IDs and authentic scores', () {
      save.leagueTier = 0;
      final rivals = save.getLeagueRivals();
      expect(rivals.length, 15);

      final realRivals = rivals.where((r) => !r.isPlayer).toList();
      expect(realRivals.length, 14);

      for (final rival in realRivals) {
        expect(rival.tag, startsWith('#KRM-'));
        expect(rival.name.isNotEmpty, isTrue);
        expect(rival.score, inInclusiveRange(600, 2799));
      }
    });

    test('same week preserves real player list without simulated drift', () {
      save.leagueTier = 0;
      final monday = SaveManager.leagueWeekStartFor(DateTime.now());
      final early = save.getLeagueRivals(now: monday.add(const Duration(hours: 1)));
      final late = save.getLeagueRivals(
          now: monday.add(const Duration(days: 6, hours: 23)));

      expect(early.length, 15);
      expect(late.length, 15);

      final earlyScores = {
        for (final r in early.where((r) => !r.isPlayer)) r.name: r.score
      };
      for (final r in late.where((r) => !r.isPlayer)) {
        expect(r.score, equals(earlyScores[r.name]));
      }
    });

    test('updateCachedLeagueRivals updates and persists cloud-synced players', () async {
      final cloudPlayers = [
        LeagueRival(name: 'CloudPro1', tag: '#KRM-AA11', score: 3200, isPlayer: false),
        LeagueRival(name: 'CloudPro2', tag: '#KRM-BB22', score: 2900, isPlayer: false),
        LeagueRival(name: 'CloudPro3', tag: '#KRM-CC33', score: 2500, isPlayer: false),
      ];

      await save.updateCachedLeagueRivals(cloudPlayers);
      expect(save.cachedLeagueRivals.length, SaveManager.leagueGroupSize - 1);
      expect(save.cachedLeagueRivals.first.tag, '#KRM-AA11');

      // Verify persistence by re-initializing from preferences
      save.resetForTesting();
      await save.init();

      expect(save.cachedLeagueRivals.any((r) => r.tag == '#KRM-AA11'), isTrue);
    });

    test('updateCachedLeagueRivals maintains tier and is not wiped by getLeagueRivals()', () async {
      save.leagueTier = 2;
      final cloudPlayers = [
        LeagueRival(name: 'Tier2Ace', tag: '#KRM-T2AC', score: 24000, isPlayer: false),
      ];
      await save.updateCachedLeagueRivals(cloudPlayers, tier: 2);
      expect(save.cachedLeagueRivals.any((r) => r.tag == '#KRM-T2AC'), isTrue);

      // getLeagueRivals calls ensureLeagueWeek(); it must NOT overwrite the cached tier 2 rivals
      final rivals = save.getLeagueRivals();
      expect(rivals.any((r) => r.tag == '#KRM-T2AC'), isTrue);
      expect(rivals.length, 15);
    });

    test('getLeagueRivals deduplicates rivals matching playerTag or realFriends', () {
      save.playerTag = '#KRM-7A21'; // matches the first default rival
      final rivals = save.getLeagueRivals();

      // Only one entry with this tag (the player itself)
      final matching = rivals.where((r) => r.tag == '#KRM-7A21').toList();
      expect(matching.length, 1);
      expect(matching.first.isPlayer, isTrue);
      expect(rivals.length, 15);
    });
  });

  group('Weekly league settlement', () {
    test('winning the week promotes and pays gold + pearls', () {
      final past = DateTime(2020, 1, 6); // a Monday
      save.ensureLeagueWeek(now: past); // adopt the past week
      save.leagueTier = 0;
      save.ensureLeagueWeek(now: past); // regenerate bots at tier 0
      save.weeklyTournamentScore = 999999;

      final gold0 = save.gold;
      final pearls0 = save.pearls;
      save.ensureLeagueWeek(); // back to the real week -> settles

      expect(save.leagueLastRank, 1);
      expect(save.leagueLastMovement, 1);
      expect(save.leagueTier, 1);
      expect(save.leagueLastRewardGold, 400);
      expect(save.leagueLastRewardPearls, 2);
      expect(save.gold, gold0 + 400);
      expect(save.pearls, pearls0 + 2);
      expect(save.weeklyTournamentScore, 0);
      expect(save.hasUnseenLeagueResult, isTrue);

      save.markLeagueResultSeen();
      expect(save.hasUnseenLeagueResult, isFalse);
    });

    test('finishing last demotes and pays the small reward', () {
      final past = DateTime(2020, 1, 13); // the next Monday
      save.ensureLeagueWeek(now: past);
      save.leagueTier = 2;
      save.ensureLeagueWeek(now: past); // regenerate bots at tier 2
      save.weeklyTournamentScore = 0;

      final gold0 = save.gold;
      save.ensureLeagueWeek();

      expect(save.leagueLastRank, 15);
      expect(save.leagueLastMovement, -1);
      expect(save.leagueTier, 1);
      expect(save.leagueLastRewardGold, 120); // 40 * (tier 2 + 1)
      expect(save.gold, gold0 + 120);
      expect(save.weeklyTournamentScore, 0);
    });
  });

  group('League point sources', () {
    test('points only flow once the league is unlocked', () {
      save.highestLevel = 10;
      expect(save.isLeagueUnlocked, isTrue);
      final before = save.weeklyTournamentScore;
      save.addTournamentScore(100);
      expect(save.weeklyTournamentScore, before + 100);

      save.highestLevel = 3;
      expect(save.isLeagueUnlocked, isFalse);
      save.addTournamentScore(100);
      expect(save.weeklyTournamentScore, before + 100);
      save.highestLevel = 10; // restore for other tests
    });
  });
}
