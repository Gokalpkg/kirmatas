import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:kirmatas/storage/save_manager.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Player name', () {
    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      await SaveManager.instance.init();
      await SaveManager.instance.setPlayerName(SaveManager.defaultPlayerName);
    });

    test('defaults to SEN and shows up in the league table', () {
      final save = SaveManager.instance;
      expect(save.playerName, 'SEN');
      final player = save.getLeagueRivals().firstWhere((r) => r.isPlayer);
      expect(player.name, 'SEN');
    });

    test('rename trims, collapses spaces and reaches the league table', () async {
      final save = SaveManager.instance;
      await save.setPlayerName('  Kaptan   Neon ');
      expect(save.playerName, 'Kaptan Neon');
      final player = save.getLeagueRivals().firstWhere((r) => r.isPlayer);
      expect(player.name, 'Kaptan Neon');
    });

    test('empty names fall back and long names are capped', () async {
      final save = SaveManager.instance;
      await save.setPlayerName('   ');
      expect(save.playerName, SaveManager.defaultPlayerName);
      await save.setPlayerName('12345678901234567890');
      expect(save.playerName.length, SaveManager.maxPlayerNameLength);
    });
  });
}
