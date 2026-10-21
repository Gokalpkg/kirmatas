import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:kirmatas/engine/play_games_manager.dart';
import 'package:kirmatas/storage/save_manager.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Play Games leaderboard wiring', () {
    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      await SaveManager.instance.init();
    });

    test('submitting scores is a safe no-op while signed out', () async {
      final games = PlayGamesManager.instance;
      expect(games.signedIn, isFalse);
      // Must complete without throwing even though nothing is connected.
      await games.submitBestScores(SaveManager.instance);
    });

    test('leaderboard screen asks for sign-in first', () async {
      final games = PlayGamesManager.instance;
      expect(await games.showLeaderboard(), 'Önce giriş yap');
    });
  });
}
