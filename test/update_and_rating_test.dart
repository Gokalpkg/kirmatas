import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:kirmatas/storage/save_manager.dart';
import 'package:kirmatas/engine/i18n.dart';
import 'package:kirmatas/engine/app_update_manager.dart';
import 'package:kirmatas/engine/in_app_review_manager.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('Update and Rating Systems Verification', () {
    test('1. AppUpdateManager constants and configuration', () {
      expect(AppUpdateManager.currentVersionCode, 119);
      expect(AppUpdateManager.currentVersionName, '1.0.118');
      expect(AppUpdateManager.defaultStoreUrl, contains('com.kaunos.kirmatas'));
      expect(AppUpdateManager.marketUrl, contains('com.kaunos.kirmatas'));
    });

    test('2. SaveManager review cadence logic (2-3 days & rated status)', () async {
      final save = SaveManager.instance;
      await save.init();

      // Initially unrated and eligible
      expect(save.hasRatedGame, isFalse);
      expect(save.canPromptForReview(), isTrue);

      // Record prompt display
      await save.recordReviewPromptShown();
      expect(save.lastReviewPromptMs, greaterThan(0));
      // Immediately after, cooldown is active (cannot prompt again)
      expect(save.canPromptForReview(), isFalse);

      // Simulate 49 hours passing (more than 48 hours / 2 days)
      save.lastReviewPromptMs = DateTime.now().millisecondsSinceEpoch - (49 * 60 * 60 * 1000);
      expect(save.canPromptForReview(), isTrue);

      // Mark as rated: should never be eligible again
      await save.markGameRated();
      expect(save.hasRatedGame, isTrue);
      expect(save.hasRequestedReview, isTrue);
      expect(save.canPromptForReview(), isFalse);
    });

    test('3. SaveManager update postponement logic', () async {
      final save = SaveManager.instance;
      await save.init();

      expect(save.isUpdatePostponedRecently(), isFalse);
      await save.postponeUpdate();
      expect(save.isUpdatePostponedRecently(), isTrue);
    });

    test('4. All 10 supported languages provide update and rating translations without emojis', () async {
      final save = SaveManager.instance;
      await save.init();

      final requiredKeys = [
        'update_available_title',
        'update_available_desc',
        'update_btn',
        'update_postpone_btn',
        'rate_us_title',
        'rate_us_desc',
        'rate_us_5_stars_btn',
        'rate_us_later_btn',
      ];

      // Regex checking for common emoji ranges
      final emojiRegex = RegExp(r'[\u{1F300}-\u{1F9FF}\u{2600}-\u{26FF}\u{2700}-\u{27BF}]', unicode: true);

      for (final lang in I18n.supportedLanguages) {
        await save.setLanguage(lang.code);
        for (final key in requiredKeys) {
          final translated = I18n.tr(key);
          expect(translated, isNotEmpty, reason: 'Key $key must not be empty in ${lang.code}');
          expect(translated, isNot(equals(key)), reason: 'Key $key must be translated in ${lang.code}');
          expect(emojiRegex.hasMatch(translated), isFalse, reason: 'Key $key must not have emojis in ${lang.code}');
        }
      }
    });

    testWidgets('5. Five-star rating dialog renders and shows interactive stars', (tester) async {
      await SaveManager.instance.init();
      await SaveManager.instance.setLanguage('tr');

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: ElevatedButton(
                  onPressed: () => InAppReviewManager.instance.showFiveStarRatingDialog(context, level: 5),
                  child: const Text('Show Rating'),
                ),
              ),
            ),
          ),
        ),
      );

      // Tap to open dialog
      await tester.tap(find.text('Show Rating'));
      await tester.pumpAndSettle();

      // Check title and buttons render
      expect(find.text(I18n.tr('rate_us_title')), findsOneWidget);
      expect(find.text(I18n.tr('rate_us_5_stars_btn')), findsOneWidget);
      expect(find.text(I18n.tr('rate_us_later_btn')), findsOneWidget);
      // Check 5 stars are rendered
      expect(find.byIcon(Icons.star_rounded), findsNWidgets(6)); // 1 big header + 5 row stars
    });

    testWidgets('6. AppUpdateDialog renders with Update and Postpone buttons', (tester) async {
      await SaveManager.instance.init();
      await SaveManager.instance.setLanguage('tr');

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: ElevatedButton(
                  onPressed: () => AppUpdateManager.instance.showUpdateDialog(context),
                  child: const Text('Show Update'),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Show Update'));
      await tester.pumpAndSettle();

      expect(find.text(I18n.tr('update_available_title')), findsOneWidget);
      expect(find.text(I18n.tr('update_btn')), findsOneWidget);
      expect(find.text(I18n.tr('update_postpone_btn')), findsOneWidget);
    });
  });
}
