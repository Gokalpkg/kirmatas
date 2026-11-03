import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
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
  });
}
