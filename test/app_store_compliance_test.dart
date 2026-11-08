import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kirmatas/engine/i18n.dart';
import 'package:kirmatas/engine/remove_ads_billing.dart';
import 'package:kirmatas/storage/save_manager.dart';
import 'package:kirmatas/ui/settings_dialog.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await SaveManager.instance.init();
  });

  group('App Store Compliance & IAP Tests', () {
    test('RemoveAdsBilling has restorePurchasesManually method and does not crash', () async {
      final billing = RemoveAdsBilling.instance;
      // Should complete without crashing even when store backend is absent
      final result = await billing.restorePurchasesManually();
      expect(result, isA<bool>());
    });

    test('PrivacyInfo.xcprivacy has NSPrivacyTracking false and DeviceID tracking false', () {
      final file = File('ios/Runner/PrivacyInfo.xcprivacy');
      expect(file.existsSync(), isTrue);
      final content = file.readAsStringSync();
      final trackingRegex = RegExp(r'<key>NSPrivacyTracking<\/key>\s*<false\/>');
      expect(trackingRegex.hasMatch(content), isTrue);
      final deviceTrackingRegex = RegExp(r'<key>NSPrivacyCollectedDataTypeTracking<\/key>\s*<false\/>');
      expect(deviceTrackingRegex.hasMatch(content), isTrue);
    });

    test('Info.plist has UIRequiresFullScreen true', () {
      final file = File('ios/Runner/Info.plist');
      expect(file.existsSync(), isTrue);
      final content = file.readAsStringSync();
      final regex = RegExp(r'<key>UIRequiresFullScreen<\/key>\s*<true\/>');
      expect(regex.hasMatch(content), isTrue);
    });

    test('Info.plist does NOT include NSUserTrackingUsageDescription to avoid ATT rejection without prompt', () {
      final file = File('ios/Runner/Info.plist');
      expect(file.existsSync(), isTrue);
      final content = file.readAsStringSync();
      expect(content.contains('NSUserTrackingUsageDescription'), isFalse);
    });

    test('RemoveAdsBilling.isIapEnabled is false', () {
      expect(RemoveAdsBilling.isIapEnabled, isFalse);
    });

    test('Info.plist has iOS AdMob App ID and does not have Android AdMob App ID', () {
      final file = File('ios/Runner/Info.plist');
      expect(file.existsSync(), isTrue);
      final content = file.readAsStringSync();
      expect(content.contains('ca-app-pub-3940256099942544~1458002511'), isTrue);
      expect(content.contains('ca-app-pub-9694275729123906~2311223088'), isFalse);
    });

    test('project.pbxproj sets TARGETED_DEVICE_FAMILY to 1,2 (Apple QA1623 mandatory update rule)', () {
      final file = File('ios/Runner.xcodeproj/project.pbxproj');
      expect(file.existsSync(), isTrue);
      final content = file.readAsStringSync();
      expect(content.contains('TARGETED_DEVICE_FAMILY = "1,2";'), isTrue);
    });

    testWidgets('SettingsDialog does not render Remove Ads or Restore Purchases buttons when disabled', (tester) async {
      final save = SaveManager.instance;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SettingsDialog(save: save),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Check that Remove Ads and Restore Purchases are cleanly removed
      expect(find.textContaining('REKLAMLARI KALDIR'), findsNothing);
      expect(find.text('SATIN ALIMLARI GERİ YÜKLE'), findsNothing);
      expect(find.text('REKLAMLAR KALDIRILDI'), findsNothing);
    });

    test('I18n rate_us_desc does not reference Google Play in any locale', () {
      final file = File('lib/engine/i18n.dart');
      expect(file.existsSync(), isTrue);
      final content = file.readAsStringSync();
      expect(content.contains('Google Play'), isFalse);
    });

    test('SettingsDialog privacy policy does not contain IDFA or store mentions', () {
      final file = File('lib/ui/settings_dialog.dart');
      expect(file.existsSync(), isTrue);
      final content = file.readAsStringSync();
      expect(content.contains('IDFA'), isFalse);
      expect(content.contains('Google Play In-App Billing'), isFalse);
      expect(content.contains('Apple StoreKit'), isFalse);
    });
  });
}
