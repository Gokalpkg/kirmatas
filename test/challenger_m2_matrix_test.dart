import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:kirmatas/models/cosmetics.dart';
import 'package:kirmatas/storage/save_manager.dart';
import 'package:kirmatas/ui/chest_widget.dart';
import 'package:kirmatas/ui/crate_opening_dialog.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('xyz.luan/audioplayers.global'),
      (MethodCall methodCall) async => 1,
    );
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('xyz.luan/audioplayers'),
      (MethodCall methodCall) async => 1,
    );
  });

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await SaveManager.instance.init();
  });

  group('Milestone 2 Challenger — Matrix Viewport & Scale Comprehensive Stress Test', () {
    const viewports = <Size>[
      Size(300, 700),
      Size(320, 480),
      Size(360, 640),
      Size(390, 844),
    ];

    const scales = <double>[1.0, 1.3];

    for (final size in viewports) {
      for (final scale in scales) {
        testWidgets(
          'Standard Crate on ${size.width.toInt()}x${size.height.toInt()} at ${scale}x scale has zero RenderFlex overflows across full lifecycle',
          (tester) async {
            tester.view.physicalSize = size;
            tester.view.devicePixelRatio = 1.0;
            addTearDown(tester.view.resetPhysicalSize);
            addTearDown(tester.view.resetDevicePixelRatio);

            final caughtErrors = <FlutterErrorDetails>[];
            final oldOnError = FlutterError.onError;
            FlutterError.onError = (details) {
              caughtErrors.add(details);
              oldOnError?.call(details);
            };

            await tester.pumpWidget(
              MaterialApp(
                builder: (context, child) => MediaQuery(
                  data: MediaQuery.of(context).copyWith(
                    textScaler: TextScaler.linear(scale),
                  ),
                  child: child!,
                ),
                home: Scaffold(
                  body: CrateOpeningDialog(crate: CrateDef.allCrates.first),
                ),
              ),
            );

            // Initial drop
            await tester.pump();
            await tester.pump(const Duration(milliseconds: 750));

            // Tap 1
            await tester.tap(find.byType(ChestWidget));
            await tester.pump();
            await tester.pump(const Duration(milliseconds: 400));

            // Tap 2
            await tester.tap(find.byType(ChestWidget));
            await tester.pump();
            await tester.pump(const Duration(milliseconds: 400));

            // Tap 3 (Opening & Reveal)
            await tester.tap(find.byType(ChestWidget));
            await tester.pump();
            await tester.pump(const Duration(milliseconds: 500));
            await tester.pump(const Duration(milliseconds: 1200));

            FlutterError.onError = oldOnError;

            final overflows = caughtErrors.where((e) =>
                e.exceptionAsString().contains('RenderFlex overflowed') ||
                e.exceptionAsString().contains('A RenderFlex overflowed')).toList();

            expect(
              overflows,
              isEmpty,
              reason: 'Overflow on ${size.width}x${size.height} @ ${scale}x: '
                  '${overflows.map((e) => e.exceptionAsString()).join('\n')}',
            );
          },
        );

        testWidgets(
          'Shard Duplicate & Food Bonus Scenario on ${size.width.toInt()}x${size.height.toInt()} at ${scale}x scale has zero RenderFlex overflows',
          (tester) async {
            tester.view.physicalSize = size;
            tester.view.devicePixelRatio = 1.0;
            addTearDown(tester.view.resetPhysicalSize);
            addTearDown(tester.view.resetDevicePixelRatio);

            final save = SaveManager.instance;
            // Unlock all skins in category to force duplicate + shard + food bonus
            for (final p in PaddleSkin.allSkins) {
              save.unlockPaddle(p.id);
            }
            save.addShard('paddles', 3);

            final paddleCrate = CategoryCrateInfo.categoryCrates['paddles']!;

            final caughtErrors = <FlutterErrorDetails>[];
            final oldOnError = FlutterError.onError;
            FlutterError.onError = (details) {
              caughtErrors.add(details);
              oldOnError?.call(details);
            };

            await tester.pumpWidget(
              MaterialApp(
                builder: (context, child) => MediaQuery(
                  data: MediaQuery.of(context).copyWith(
                    textScaler: TextScaler.linear(scale),
                  ),
                  child: child!,
                ),
                home: Scaffold(
                  body: CrateOpeningDialog(
                    categoryCrate: paddleCrate,
                    category: 'paddles',
                  ),
                ),
              ),
            );

            // Drop
            await tester.pump();
            await tester.pump(const Duration(milliseconds: 750));

            // Tap 1, 2, 3
            await tester.tap(find.byType(ChestWidget));
            await tester.pump();
            await tester.pump(const Duration(milliseconds: 400));
            await tester.tap(find.byType(ChestWidget));
            await tester.pump();
            await tester.pump(const Duration(milliseconds: 400));
            await tester.tap(find.byType(ChestWidget));
            await tester.pump();
            await tester.pump(const Duration(milliseconds: 500));
            await tester.pump(const Duration(milliseconds: 1200));

            FlutterError.onError = oldOnError;

            final overflows = caughtErrors.where((e) =>
                e.exceptionAsString().contains('RenderFlex overflowed') ||
                e.exceptionAsString().contains('A RenderFlex overflowed')).toList();

            expect(
              overflows,
              isEmpty,
              reason: 'Shard/Bonus Overflow on ${size.width}x${size.height} @ ${scale}x: '
                  '${overflows.map((e) => e.exceptionAsString()).join('\n')}',
            );
          },
        );
      }
    }
  });
}
