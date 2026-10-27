import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kirmatas/ui/kaunos_ui.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Challenger 1: Unconstrained / Flex Layout Stress for KaunosTactileButton', () {
    testWidgets('KaunosTactileButton with explicit width in Row renders cleanly', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Row(
              children: [
                KaunosTactileButton(
                  width: 120,
                  onTap: () {},
                  child: const Text('BTN'),
                ),
              ],
            ),
          ),
        ),
      );
      expect(find.text('BTN'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('KaunosTactileButton inside Expanded in Row renders cleanly', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Row(
              children: [
                Expanded(
                  child: KaunosTactileButton(
                    onTap: () {},
                    child: const Text('EXPANDED'),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
      expect(find.text('EXPANDED'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('KaunosTactileButton renders cleanly with unconstrained infinite width in Row when width is null', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Row(
              children: [
                KaunosTactileButton(
                  onTap: () {},
                  child: const Text('NO_WIDTH'),
                ),
              ],
            ),
          ),
        ),
      );
      final exception = tester.takeException();
      expect(exception, isNull);
      expect(find.text('NO_WIDTH'), findsOneWidget);
    });
  });

  group('Challenger 2: Button State Retention & Stuck-Depressed Inspection', () {
    testWidgets('KaunosTactileButton resets depressed state when disabled while pressed down', (tester) async {
      bool isEnabled = true;
      late StateSetter parentSetState;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) {
                parentSetState = setState;
                return KaunosTactileButton(
                  key: const Key('tactile_btn'),
                  enabled: isEnabled,
                  bevelDepth: 5.0,
                  onTap: () {},
                  child: const Text('PRESS_ME'),
                );
              },
            ),
          ),
        ),
      );

      Padding getFacePadding() => tester.widget<Padding>(
        find.descendant(
          of: find.byKey(const Key('tactile_btn')),
          matching: find.byWidgetPredicate(
            (w) => w is Padding && w.padding is EdgeInsets && w.child is Container,
          ),
        ),
      );

      // Verify initial position (unpressed: top = 0.0)
      expect((getFacePadding().padding as EdgeInsets).top, 0.0);

      // Press down (depressed: top = 4.0)
      final gesture = await tester.startGesture(tester.getCenter(find.text('PRESS_ME')));
      await tester.pump();

      expect((getFacePadding().padding as EdgeInsets).top, 4.0);

      // Disable button while pointer is still down
      parentSetState(() {
        isEnabled = false;
      });
      await tester.pump();

      // Release pointer
      await gesture.up();
      await tester.pump();

      // Re-enable button
      parentSetState(() {
        isEnabled = true;
      });
      await tester.pump();

      // Verified: _isPressed was reset to false (top = 0.0)
      expect((getFacePadding().padding as EdgeInsets).top, 0.0, reason: 'Proves _isPressed reset cleanly on tap up / cancel');
    });

    testWidgets('KaunosHeroPlayButton resets depressed state when disabled while pressed down', (tester) async {
      bool isEnabled = true;
      late StateSetter parentSetState;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) {
                parentSetState = setState;
                return KaunosHeroPlayButton(
                  key: const Key('hero_btn'),
                  enabled: isEnabled,
                  size: 62.0,
                  onTap: () {},
                );
              },
            ),
          ),
        ),
      );

      Positioned getTrigger() => tester.widget<Positioned>(
        find.descendant(
          of: find.byKey(const Key('hero_btn')),
          matching: find.byWidgetPredicate(
            (w) => w is Positioned && w.width == 52.0 && w.height == 52.0,
          ),
        ),
      );

      expect(getTrigger().top, 5.0);

      // Press down (depressed: top = 8.5)
      final gesture = await tester.startGesture(tester.getCenter(find.byKey(const Key('hero_btn'))));
      await tester.pump();
      expect(getTrigger().top, 8.5);

      // Disable while pointer is down
      parentSetState(() {
        isEnabled = false;
      });
      await tester.pump();

      // Lift gesture
      await gesture.up();
      await tester.pump();

      // Re-enable
      parentSetState(() {
        isEnabled = true;
      });
      await tester.pump();

      // Verified: getTrigger().top resets to 5.0 (not stuck at 8.5)
      expect(getTrigger().top, 5.0, reason: 'Proves _isPressed reset cleanly on tap up / cancel');
    });
  });

  group('Challenger 3: Painter Performance & Allocation Microbenchmarks', () {
    test('KaunosPanelPainter: 10,000 paint cycles benchmark', () {
      const painter = KaunosPanelPainter(
        borderRadius: 20,
        backgroundColor: KaunosPalette.obsidianGlassSurface,
        borderColor: KaunosPalette.crystalBorderStarlight,
        showSpecularRim: true,
        showCornerBrackets: true,
        bottomBevelDepth: 4.0,
        bevelColor: KaunosPalette.crystalBevelShadow,
      );

      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      const size = Size(320, 160);

      final stopwatch = Stopwatch()..start();
      for (int i = 0; i < 10000; i++) {
        painter.paint(canvas, size);
      }
      stopwatch.stop();

      final totalMs = stopwatch.elapsedMilliseconds;
      final perCallUs = (stopwatch.elapsedMicroseconds / 10000);
      debugPrint('Benchmark: KaunosPanelPainter 10,000 calls = ${totalMs}ms (${perCallUs.toStringAsFixed(2)} µs/call)');
      expect(totalMs, lessThan(1200), reason: 'Painter must execute 10,000 cycles well within 1200ms (<120µs/call)');
    });

    test('KaunosEmblemPainter: 10,000 paint cycles benchmark for all 7 emblems', () {
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      const size = Size(32, 32);

      for (final type in KaunosEmblemType.values) {
        final painter = KaunosEmblemPainter(type: type);
        final sw = Stopwatch()..start();
        for (int i = 0; i < 5000; i++) {
          painter.paint(canvas, size);
        }
        sw.stop();
        final perCallUs = sw.elapsedMicroseconds / 5000;
        debugPrint('Benchmark: KaunosEmblemPainter ($type) 5,000 calls = ${sw.elapsedMilliseconds}ms (${perCallUs.toStringAsFixed(2)} µs/call)');
        expect(sw.elapsedMilliseconds, lessThan(1500));
      }
    });

    test('KaunosPlayChevronPainter: 10,000 paint cycles benchmark', () {
      const painter = KaunosPlayChevronPainter();
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      const size = Size(28, 28);

      final sw = Stopwatch()..start();
      for (int i = 0; i < 10000; i++) {
        painter.paint(canvas, size);
      }
      sw.stop();
      final perCallUs = sw.elapsedMicroseconds / 10000;
      debugPrint('Benchmark: KaunosPlayChevronPainter 10,000 calls = ${sw.elapsedMilliseconds}ms (${perCallUs.toStringAsFixed(2)} µs/call)');
      expect(sw.elapsedMilliseconds, lessThan(800));
    });
  });

  group('Challenger 4: Boundary & Degenerate Sizes in CustomPainters', () {
    test('Painters handle extreme / degenerate sizes without throwing', () {
      final degenerateSizes = [
        Size.zero,
        const Size(-10, -10),
        const Size(0, 50),
        const Size(50, 0),
        const Size(0.001, 0.001),
        const Size(1, 1),
        const Size(5, 5),
        const Size(20, 10),
        const Size(48, 48),
        const Size(10000, 10000),
      ];

      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);

      const panelPainter = KaunosPanelPainter(
        borderRadius: 20,
        backgroundColor: KaunosPalette.obsidianGlassSurface,
        borderColor: KaunosPalette.crystalBorderStarlight,
        showSpecularRim: true,
        showCornerBrackets: true,
        bottomBevelDepth: 4.0,
        bevelColor: KaunosPalette.crystalBevelShadow,
      );

      const chevronPainter = KaunosPlayChevronPainter();

      for (final s in degenerateSizes) {
        expect(() => panelPainter.paint(canvas, s), returnsNormally);
        expect(() => chevronPainter.paint(canvas, s), returnsNormally);

        for (final type in KaunosEmblemType.values) {
          final emblemPainter = KaunosEmblemPainter(type: type);
          expect(() => emblemPainter.paint(canvas, s), returnsNormally);
        }
      }
    });
  });

  group('Challenger 5: shouldRepaint Exhaustive Field Permutations', () {
    test('KaunosPanelPainter shouldRepaint responds to each individual field change', () {
      const base = KaunosPanelPainter(
        borderRadius: 10,
        backgroundColor: Colors.black,
        borderColor: Colors.blue,
        showSpecularRim: false,
        showCornerBrackets: false,
        bottomBevelDepth: 0,
        bevelColor: Colors.black,
      );

      expect(base.shouldRepaint(base), isFalse);

      expect(base.shouldRepaint(const KaunosPanelPainter(
        borderRadius: 12,
        backgroundColor: Colors.black,
        borderColor: Colors.blue,
        showSpecularRim: false,
        showCornerBrackets: false,
        bottomBevelDepth: 0,
        bevelColor: Colors.black,
      )), isTrue);

      expect(base.shouldRepaint(const KaunosPanelPainter(
        borderRadius: 10,
        backgroundColor: Colors.red,
        borderColor: Colors.blue,
        showSpecularRim: false,
        showCornerBrackets: false,
        bottomBevelDepth: 0,
        bevelColor: Colors.black,
      )), isTrue);

      expect(base.shouldRepaint(const KaunosPanelPainter(
        borderRadius: 10,
        backgroundColor: Colors.black,
        borderColor: Colors.red,
        showSpecularRim: false,
        showCornerBrackets: false,
        bottomBevelDepth: 0,
        bevelColor: Colors.black,
      )), isTrue);

      expect(base.shouldRepaint(const KaunosPanelPainter(
        borderRadius: 10,
        backgroundColor: Colors.black,
        borderColor: Colors.blue,
        showSpecularRim: true,
        showCornerBrackets: false,
        bottomBevelDepth: 0,
        bevelColor: Colors.black,
      )), isTrue);

      expect(base.shouldRepaint(const KaunosPanelPainter(
        borderRadius: 10,
        backgroundColor: Colors.black,
        borderColor: Colors.blue,
        showSpecularRim: false,
        showCornerBrackets: true,
        bottomBevelDepth: 0,
        bevelColor: Colors.black,
      )), isTrue);

      expect(base.shouldRepaint(const KaunosPanelPainter(
        borderRadius: 10,
        backgroundColor: Colors.black,
        borderColor: Colors.blue,
        showSpecularRim: false,
        showCornerBrackets: false,
        bottomBevelDepth: 2,
        bevelColor: Colors.black,
      )), isTrue);

      expect(base.shouldRepaint(const KaunosPanelPainter(
        borderRadius: 10,
        backgroundColor: Colors.black,
        borderColor: Colors.blue,
        showSpecularRim: false,
        showCornerBrackets: false,
        bottomBevelDepth: 0,
        bevelColor: Colors.red,
      )), isTrue);
    });

    test('KaunosEmblemPainter shouldRepaint responds to secondaryColor', () {
      const p1 = KaunosEmblemPainter(
        type: KaunosEmblemType.coin,
        color: Colors.amber,
        secondaryColor: Colors.yellow,
      );
      const p2 = KaunosEmblemPainter(
        type: KaunosEmblemType.coin,
        color: Colors.amber,
        secondaryColor: Colors.orange,
      );
      expect(p1.shouldRepaint(p2), isTrue);
    });
  });

  group('Challenger 6: Rapid Tap & Churn Stress', () {
    testWidgets('KaunosTactileButton withstands 50 rapid taps without state desync', (tester) async {
      int tapCount = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: KaunosTactileButton(
                onTap: () => tapCount++,
                child: const Text('RAPID'),
              ),
            ),
          ),
        ),
      );

      for (int i = 0; i < 50; i++) {
        await tester.tap(find.text('RAPID'));
      }
      await tester.pumpAndSettle();

      expect(tapCount, 50);
    });

    testWidgets('KaunosHeroPlayButton withstands rapid gesture churn', (tester) async {
      int tapCount = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: KaunosHeroPlayButton(
                onTap: () => tapCount++,
              ),
            ),
          ),
        ),
      );

      for (int i = 0; i < 30; i++) {
        final g = await tester.startGesture(tester.getCenter(find.byType(KaunosHeroPlayButton)));
        await tester.pump(const Duration(milliseconds: 10));
        await g.up();
        await tester.pump(const Duration(milliseconds: 10));
      }
      await tester.pumpAndSettle();

      expect(tapCount, 30);
    });
  });

  group('Challenger 7: Extreme Text Scaling & Compact Screen Boundaries', () {
    testWidgets('KaunosBadge under 3.0x text scaling does not throw RenderFlex overflow', (tester) async {
      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(
            size: Size(240, 320),
            textScaler: TextScaler.linear(3.0),
          ),
          child: const MaterialApp(
            home: Scaffold(
              body: SizedBox(
                width: 150,
                child: KaunosBadge(
                  text: 'GÖREV BÖLÜMÜ 10 ULTRA EXTRA LONG TEXT',
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  });
}
