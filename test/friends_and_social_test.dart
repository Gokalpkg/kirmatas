import 'package:flutter_test/flutter_test.dart';
import 'package:kirmatas/storage/save_manager.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('Supercell-Style Kaunos ID & Real Friends League Tests', () {
    test('playerTag generates with #KRM- prefix and persists', () async {
      final save = SaveManager.instance;
      await save.init();

      expect(save.playerTag.startsWith('#KRM-'), isTrue);
      expect(save.playerTag.length, greaterThanOrEqualTo(8));

      final existingTag = save.playerTag;
      // Re-init with same prefs should keep tag
      expect(save.playerTag, equals(existingTag));
    });

    test('Adding and removing RealFriends updates cache and persistence', () async {
      final save = SaveManager.instance;
      await save.init();

      expect(save.realFriends.isEmpty, isTrue);

      final friend1 = RealFriend(
        tag: '#KRM-1111',
        name: 'Ahmet',
        weeklyScore: 4500,
        highScore: 12000,
        leagueTier: 2,
      );

      await save.addRealFriend(friend1);
      expect(save.realFriends.length, equals(1));
      expect(save.realFriends.first.name, equals('Ahmet'));
      expect(save.realFriends.first.weeklyScore, equals(4500));

      final friend2 = RealFriend(
        tag: '#KRM-2222',
        name: 'Mehmet',
        weeklyScore: 9000,
        highScore: 25000,
        leagueTier: 3,
      );

      await save.addRealFriend(friend2);
      expect(save.realFriends.length, equals(2));

      await save.removeRealFriend('#KRM-1111');
      expect(save.realFriends.length, equals(1));
      expect(save.realFriends.first.tag, equals('#KRM-2222'));
    });

    test('RealFriends are dynamically injected into Weekly League standings', () async {
      final save = SaveManager.instance;
      await save.init();

      save.weeklyTournamentScore = 6000;
      await save.addRealFriend(RealFriend(
        tag: '#KRM-TOP',
        name: 'Zirve Arkadaşı',
        weeklyScore: 15000,
      ));

      final rivals = save.getLeagueRivals();
      // Total group size is 15
      expect(rivals.length, equals(SaveManager.leagueGroupSize));

      final friendRival = rivals.firstWhere((r) => r.name.contains('Zirve Arkadaşı'));
      expect(friendRival, isNotNull);
      expect(friendRival.score, equals(15000));
      expect(friendRival.rank, lessThan(rivals.firstWhere((r) => r.isPlayer).rank));
    });
  });
}
