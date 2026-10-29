import 'package:flutter_test/flutter_test.dart';
import 'package:kirmatas/engine/achievement_manager.dart';
import 'package:kirmatas/storage/save_manager.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('Google Play Games Services Compliance Tests', () {
    test('1. Total achievement count is 42 (meets recommended >= 40)', () {
      expect(AchievementManager.catalog.length, equals(42));
    });

    test('2. Total points equal 1,750, leaving 250 reserve for 2,000 PGS limit', () {
      final total = AchievementManager.totalPoints;
      expect(total, equals(1750));
      expect(total, lessThanOrEqualTo(2000));
      expect(2000 - total, equals(250)); // 250 point reserve
      expect(AchievementManager.totalXp, equals(175000));
    });

    test('3. All point values are multiples of 5 and <= 200', () {
      for (final a in AchievementManager.catalog) {
        expect(
          a.pointValue % 5,
          equals(0),
          reason: '${a.id} pointValue (${a.pointValue}) must be a multiple of 5',
        );
        expect(
          a.pointValue,
          greaterThan(0),
          reason: '${a.id} pointValue must be > 0',
        );
        expect(
          a.pointValue,
          lessThanOrEqualTo(200),
          reason: '${a.id} pointValue cannot exceed 200',
        );
        expect(
          a.xpValue,
          equals(a.pointValue * 100),
          reason: '${a.id} XP must be 100 * pointValue',
        );
      }
    });

    test('4. All IDs, names, and descriptions are unique and within length constraints', () {
      final ids = <String>{};
      final names = <String>{};
      final descriptions = <String>{};

      for (final a in AchievementManager.catalog) {
        expect(ids.add(a.id), isTrue, reason: 'Duplicate ID: ${a.id}');
        expect(names.add(a.name), isTrue, reason: 'Duplicate name: ${a.name}');
        expect(
          descriptions.add(a.description),
          isTrue,
          reason: 'Duplicate description for ${a.id}',
        );

        expect(
          a.name.length,
          lessThanOrEqualTo(100),
          reason: 'Name too long: ${a.name}',
        );
        expect(
          a.description.length,
          lessThanOrEqualTo(500),
          reason: 'Description too long for ${a.id}',
        );

        // Verify zero raw emojis
        final hasEmoji = RegExp(r'[\u{1F300}-\u{1F9FF}]', unicode: true).hasMatch(a.name) ||
            RegExp(r'[\u{1F300}-\u{1F9FF}]', unicode: true).hasMatch(a.description);
        expect(hasEmoji, isFalse, reason: 'Achievement text contains raw emoji: ${a.id}');
      }
    });

    test('5. At least 4 achievements are first-hour friendly (PGS eligibility)', () {
      final firstHourList = AchievementManager.catalog.where((a) => a.isFirstHourFriendly).toList();
      expect(
        firstHourList.length,
        greaterThanOrEqualTo(4),
        reason: 'Must have at least 4 first-hour achievements',
      );
      expect(firstHourList.length, equals(6));
    });

    test('6. Incremental achievements have maxSteps > 1', () {
      final incremental = AchievementManager.catalog
          .where((a) => a.type == AchievementType.incremental)
          .toList();
      expect(incremental.length, equals(11));
      for (final a in incremental) {
        expect(
          a.maxSteps,
          greaterThan(1),
          reason: '${a.id} incremental achievement must have maxSteps > 1',
        );
      }
    });

    test('7. Secret achievements exist for surprise & delight (7 total)', () {
      final secret = AchievementManager.catalog
          .where((a) => a.type == AchievementType.secret)
          .toList();
      expect(secret.length, equals(7));
    });

    test('8. All 42 achievements have distinct, valid Google Play Games CgkI... IDs', () {
      final consoleIds = <String>{};
      for (final a in AchievementManager.catalog) {
        expect(a.playConsoleId, startsWith('CgkIwf_oppkBEAIQ'));
        expect(consoleIds.add(a.playConsoleId), isTrue,
            reason: 'Duplicate Play Console ID: ${a.playConsoleId}');
      }
      expect(consoleIds.length, equals(42));
    });
  });

  group('AchievementManager Runtime & Persistence Tests', () {
    test('Unlocking standard achievement marks it in SaveManager', () async {
      final save = SaveManager.instance;
      await save.init();
      final manager = AchievementManager.instance;
      manager.init(save: save);

      expect(save.unlockedAchievements.contains('achievement_first_strike'), isFalse);

      final unlocked = await manager.unlock('achievement_first_strike');
      expect(unlocked, isTrue);
      expect(save.unlockedAchievements.contains('achievement_first_strike'), isTrue);

      // Duplicate unlock returns false
      final unlockedAgain = await manager.unlock('achievement_first_strike');
      expect(unlockedAgain, isFalse);
    });

    test('Incrementing achievement advances steps and auto-unlocks at maxSteps', () async {
      final save = SaveManager.instance;
      await save.init();
      final manager = AchievementManager.instance;
      manager.init(save: save);

      // achievement_pearl_collector has 10 steps
      const id = 'achievement_pearl_collector';
      expect(save.unlockedAchievements.contains(id), isFalse);

      await manager.increment(id, steps: 5);
      expect(save.achievementSteps[id], equals(5));
      expect(save.unlockedAchievements.contains(id), isFalse);

      await manager.increment(id, steps: 5);
      expect(save.achievementSteps[id], equals(10));
      expect(save.unlockedAchievements.contains(id), isTrue);
    });

    test('Evaluating lifetime stats retroactively unlocks earned achievements', () async {
      final save = SaveManager.instance;
      await save.init();
      save.statBricksBrokenTotal = 25000;
      save.highestLevel = 55;
      save.bestChaosWave = 16;
      save.gold = 55000;

      final manager = AchievementManager.instance;
      manager.init(save: save);

      expect(save.unlockedAchievements.contains('achievement_first_strike'), isTrue);
      expect(save.unlockedAchievements.contains('achievement_bricks_500'), isTrue);
      expect(save.unlockedAchievements.contains('achievement_bricks_2500'), isTrue);
      expect(save.unlockedAchievements.contains('achievement_bricks_10000'), isTrue);
      expect(save.unlockedAchievements.contains('achievement_level_50'), isTrue);
      expect(save.unlockedAchievements.contains('achievement_chaos_survivor_1'), isTrue);
      expect(save.unlockedAchievements.contains('achievement_chaos_survivor_2'), isTrue);
      expect(save.unlockedAchievements.contains('achievement_gold_10000'), isTrue);
      expect(save.unlockedAchievements.contains('achievement_gold_50000'), isTrue);
    });
  });
}
