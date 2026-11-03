import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kirmatas/engine/play_games_manager.dart';
import 'package:kirmatas/storage/save_manager.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    SharedPreferences.setMockInitialValues({});
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('xyz.luan/audioplayers.global'),
      (MethodCall methodCall) async => 1,
    );
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('xyz.luan/audioplayers'),
      (MethodCall methodCall) async => 1,
    );
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('games_services'),
      (MethodCall methodCall) async {
        if (methodCall.method == 'isSignedIn') {
          return true;
        }
        if (methodCall.method == 'signIn') {
          return 'mock_player_id';
        }
        if (methodCall.method == 'saveGame') {
          return 'success';
        }
        if (methodCall.method == 'loadGame') {
          // Return a mock saved envelope with high progress
          return '{"app":"kirmatas","version":1,"savedAtMs":1730700000000,"data":{"metricHighestClassicLevel":42,"gold":9999,"diamonds":50,"playerTag":"#KRM-TEST"}}';
        }
        return null;
      },
    );
  });

  group('Automatic Cloud Save & Restore Tests', () {
    test('tryAutoRestore automatically restores on fresh local install', () async {
      SharedPreferences.setMockInitialValues({});
      final save = SaveManager.instance;
      await save.init();
      final games = PlayGamesManager.instance;
      games.mockSignedIn = true;

      // Ensure local state looks like a fresh install
      expect(save.highestLevel, lessThanOrEqualTo(1));

      final restored = await games.tryAutoRestore(save: save);
      expect(restored, isTrue);
      expect(games.wasCloudRestored, isTrue);
      expect(save.highestLevel, equals(42));
      expect(save.gold, equals(9999));
      expect(save.playerTag, equals('#KRM-TEST'));
    });

    test('autoSaveToCloud executes silently without throwing when signed in', () async {
      final save = SaveManager.instance;
      final games = PlayGamesManager.instance;
      games.mockSignedIn = true;

      // Must not throw
      await games.autoSaveToCloud(save);
      expect(games.statusText, contains('Buluta kaydedildi'));
    });
  });
}
