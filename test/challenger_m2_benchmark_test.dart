import 'dart:ui' as ui;
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

  group('Milestone 2 Challenger — _ChestPainter Efficiency Benchmarks', () {
    testWidgets('Benchmark _ChestPainter 1,000 paint cycles across all 4 tiers and open states', (tester) async {
      final benchmarkResults = <String, double>{};

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              const testTiers = [
                Rarity.common,
                Rarity.rare,
                Rarity.epic,
                Rarity.legendary,
              ];
              const testProgresses = [0.0, 0.5, 1.0];

              for (final tier in testTiers) {
                for (final prog in testProgresses) {
                  final chest = ChestWidget(
                    size: 128,
                    tier: tier,
                    openProgress: prog,
                    isOpened: prog == 1.0,
                    showGlow: true,
                    time: 1.5,
                  );
                  final sizedBox = chest.build(context) as SizedBox;
                  final customPaint = sizedBox.child as CustomPaint;
                  final painter = customPaint.painter!;
                  const testSize = Size(128, 128);

                  // Warm-up
                  for (int i = 0; i < 50; i++) {
                    final recorder = ui.PictureRecorder();
                    final canvas = Canvas(recorder);
                    painter.paint(canvas, testSize);
                    final pic = recorder.endRecording();
                    pic.dispose();
                  }

                  // Timed 1,000 iterations
                  final sw = Stopwatch()..start();
                  const iterations = 1000;
                  for (int i = 0; i < iterations; i++) {
                    final recorder = ui.PictureRecorder();
                    final canvas = Canvas(recorder);
                    painter.paint(canvas, testSize);
                    final pic = recorder.endRecording();
                    pic.dispose();
                  }
                  sw.stop();

                  final avgUsPerPaint = sw.elapsedMicroseconds / iterations;
                  final key = '${tier.name}_prog_${(prog * 100).toInt()}';
                  benchmarkResults[key] = avgUsPerPaint;

                  // High-performance threshold check:
                  // 60 FPS frame budget is 16,666 µs total.
                  // A painter alone MUST NOT take more than 3,500 µs (3.5 ms) per paint
                  // (relaxed for CI environments that may run slower than device hardware).
                  expect(avgUsPerPaint, lessThan(3500.0),
                      reason: 'Painter $key is too slow: ${avgUsPerPaint.toStringAsFixed(2)} µs/paint');
                }
              }

              return Container();
            },
          ),
        ),
      );

      // ignore: avoid_print
      print('=== _ChestPainter Benchmark Results (µs per paint) ===');
      benchmarkResults.forEach((key, us) {
        // ignore: avoid_print
        print('  $key: ${us.toStringAsFixed(2)} µs');
      });
      // ignore: avoid_print
      print('======================================================');
    });
  });

  group('Milestone 2 Challenger — Responsive Viewport & Text Scale Stress Test', () {
    final viewports = [
      const Size(300, 700),
      const Size(320, 480),
      const Size(360, 640),
      const Size(390, 844),
    ];

    for (final size in viewports) {
      testWidgets('CrateOpeningDialog renders and completes opening at ${size.width.toInt()}x${size.height.toInt()} with 1.3x text scale',
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
                textScaler: const TextScaler.linear(1.3),
              ),
              child: child!,
            ),
            home: Scaffold(
              body: CrateOpeningDialog(crate: CrateDef.allCrates.first),
            ),
          ),
        );

        await tester.pump();
        await tester.pump(const Duration(milliseconds: 700));

        await tester.tap(find.byType(ChestWidget));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));

        await tester.tap(find.byType(ChestWidget));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));

        await tester.tap(find.byType(ChestWidget));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));
        await tester.pump(const Duration(milliseconds: 1000));

        FlutterError.onError = oldOnError;

        final overflows = caughtErrors.where((e) =>
            e.exceptionAsString().contains('RenderFlex overflowed') ||
            e.exceptionAsString().contains('A RenderFlex overflowed')).toList();

        expect(overflows, isEmpty,
            reason: 'RenderFlex overflow detected at 1.3x scale on ${size.width}x${size.height}: ${overflows.map((e) => e.exceptionAsString()).join('\n')}');
      });
    }
  });
}
