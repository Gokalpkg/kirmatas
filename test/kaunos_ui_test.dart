import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kirmatas/ui/kaunos_ui.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('KaunosPalette Design Tokens', () {
    test('verifies 75% 1.1 Cosmic Crystal obsidian color tokens', () {
      expect(KaunosPalette.obsidianBase, const Color(0xFF05070F));
      expect(KaunosPalette.obsidianGlassSurface, const Color(0xDF070B18));
      expect(KaunosPalette.obsidianGlassElevated, const Color(0xEA0B1024));
      expect(KaunosPalette.obsidianGlassModal, const Color(0xF2050711));
      expect(KaunosPalette.crystalBorderStarlight, const Color(0x5538BDF8));
      expect(KaunosPalette.crystalBorderViolet, const Color(0x40A78BFA));
      expect(KaunosPalette.crystalBorderMuted, const Color(0x2480D8FF));
      expect(KaunosPalette.crystalSpecularRim, const Color(0x80FFFFFF));
      expect(KaunosPalette.crystalBevelShadow, const Color(0xFF020308));
    });

    test('verifies 25% 1.3 3D Forged Gold and Bevel tokens', () {
      expect(KaunosPalette.goldGlint, const Color(0xFFFFF9E6));
      expect(KaunosPalette.goldHighlight, const Color(0xFFFDE68A));
      expect(KaunosPalette.goldPrimary, const Color(0xFFF59E0B));
      expect(KaunosPalette.goldDeep, const Color(0xFFD97706));
      expect(KaunosPalette.goldBevelBottom, const Color(0xFF451A03));
      expect(KaunosPalette.goldBorder, const Color(0xFFFFD54F));
      expect(KaunosPalette.amberGlow, const Color(0x40F59E0B));
    });

    test('verifies mode identity semantic tokens', () {
      expect(KaunosPalette.classicSunsetTop, const Color(0xFF96381B));
      expect(KaunosPalette.classicSunsetBottom, const Color(0xFF5A1C0A));
      expect(KaunosPalette.terracottaPrimary, const Color(0xFFC85A32));
      expect(KaunosPalette.terracottaBorder, const Color(0xFFF5B041));
      expect(KaunosPalette.chaosJadeTop, const Color(0xFF133E47));
      expect(KaunosPalette.chaosJadeBottom, const Color(0xFF0A2228));
      expect(KaunosPalette.chaosJadeBorder, const Color(0xFF2DD4BF));
      expect(KaunosPalette.deepJadePrimary, const Color(0xFF1E4D58));
      expect(KaunosPalette.deepJadeBorder, const Color(0xFF48A9A6));
      expect(KaunosPalette.pearlAstral, const Color(0xFFE040FB));
    });
  });

  group('KaunosPanel & KaunosCard Widgets', () {
    testWidgets('KaunosPanel renders child and default borders', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: KaunosPanel(
              child: Text('Panel Content'),
            ),
          ),
        ),
      );

      expect(find.text('Panel Content'), findsOneWidget);
      expect(find.byType(KaunosPanel), findsOneWidget);
      expect(find.byType(CustomPaint), findsWidgets);
    });

    testWidgets('KaunosPanel with custom background, bevel, and constraints', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: KaunosPanel(
              width: 200,
              height: 120,
              borderRadius: 16,
              bottomBevelDepth: 4.0,
              backgroundColor: Color(0xFF101828),
              borderColor: Color(0xFF38BDF8),
              showSpecularRim: true,
              showCornerBrackets: true,
              child: Center(child: Text('Custom Panel')),
            ),
          ),
        ),
      );

      expect(find.text('Custom Panel'), findsOneWidget);
      final size = tester.getSize(find.byType(KaunosPanel));
      expect(size.width, 200);
      expect(size.height, 120);
    });

    testWidgets('KaunosCard renders with elevated styling and bottom bevel', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: KaunosCard(
              child: Text('Card Content'),
            ),
          ),
        ),
      );

      expect(find.text('Card Content'), findsOneWidget);
      expect(find.byType(KaunosCard), findsOneWidget);
      expect(find.byType(KaunosPanel), findsOneWidget);
    });

    test('KaunosPanelPainter shouldRepaint triggers correctly', () {
      const p1 = KaunosPanelPainter(
        borderRadius: 20,
        backgroundColor: Colors.black,
        borderColor: Colors.blue,
        showSpecularRim: true,
        showCornerBrackets: true,
        bottomBevelDepth: 4.0,
        bevelColor: Colors.black,
      );
      const p2 = KaunosPanelPainter(
        borderRadius: 20,
        backgroundColor: Colors.black,
        borderColor: Colors.blue,
        showSpecularRim: true,
        showCornerBrackets: true,
        bottomBevelDepth: 4.0,
        bevelColor: Colors.black,
      );
      const p3 = KaunosPanelPainter(
        borderRadius: 24,
        backgroundColor: Colors.black,
        borderColor: Colors.blue,
        showSpecularRim: true,
        showCornerBrackets: true,
        bottomBevelDepth: 4.0,
        bevelColor: Colors.black,
      );

      expect(p1.shouldRepaint(p2), isFalse);
      expect(p1.shouldRepaint(p3), isTrue);
    });
  });

  group('KaunosTactileButton', () {
    testWidgets('KaunosTactileButton renders and handles tap gesture', (tester) async {
      bool tapped = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: KaunosTactileButton(
                onTap: () => tapped = true,
                child: const Text('BAŞLA'),
              ),
            ),
          ),
        ),
      );

      expect(find.text('BAŞLA'), findsOneWidget);
      expect(tapped, isFalse);

      // Tap the button
      await tester.tap(find.text('BAŞLA'));
      await tester.pumpAndSettle();

      expect(tapped, isTrue);
    });

    testWidgets('KaunosTactileButton press depression animation state', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: KaunosTactileButton(
                bevelDepth: 5.0,
                onTap: () {},
                child: const Text('DOKUN'),
              ),
            ),
          ),
        ),
      );

      // Press down without releasing
      final gesture = await tester.startGesture(tester.getCenter(find.text('DOKUN')));
      await tester.pump();

      // State is pressed; release
      await gesture.up();
      await tester.pumpAndSettle();
    });

    testWidgets('KaunosTactileButton disabled state does not trigger tap', (tester) async {
      bool tapped = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: KaunosTactileButton(
                enabled: false,
                onTap: () => tapped = true,
                child: const Text('KİLİTLİ'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('KİLİTLİ'));
      await tester.pumpAndSettle();

      expect(tapped, isFalse);
    });

    testWidgets('KaunosTactileButton factory variants render correctly', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                KaunosTactileButton.gold(
                  onTap: () {},
                  child: const Text('Gold'),
                ),
                KaunosTactileButton.sunset(
                  onTap: () {},
                  child: const Text('Sunset'),
                ),
                KaunosTactileButton.jade(
                  onTap: () {},
                  child: const Text('Jade'),
                ),
                KaunosTactileButton.obsidian(
                  onTap: () {},
                  child: const Text('Obsidian'),
                ),
              ],
            ),
          ),
        ),
      );

      expect(find.text('Gold'), findsOneWidget);
      expect(find.text('Sunset'), findsOneWidget);
      expect(find.text('Jade'), findsOneWidget);
      expect(find.text('Obsidian'), findsOneWidget);
    });

    testWidgets('KaunosTactileButton renders in Row without explicit width without crash', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Row(
              children: [
                KaunosTactileButton(
                  onTap: () {},
                  child: const Text('AUTO_WIDTH'),
                ),
              ],
            ),
          ),
        ),
      );

      expect(find.text('AUTO_WIDTH'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('KaunosTactileButton explicit width (200px) stretches face container and bevel to full width', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: KaunosTactileButton(
                width: 200,
                onTap: () {},
                child: const Text('OK'),
              ),
            ),
          ),
        ),
      );

      final buttonFinder = find.byType(KaunosTactileButton);
      final faceFinder = find.descendant(
        of: find.descendant(of: buttonFinder, matching: find.byType(Padding)),
        matching: find.byType(Container),
      );
      final bevelFinder = find.descendant(
        of: find.descendant(of: buttonFinder, matching: find.byType(Positioned)),
        matching: find.byType(Container),
      );

      final buttonSize = tester.getSize(buttonFinder);
      final faceSize = tester.getSize(faceFinder);
      final bevelSize = tester.getSize(bevelFinder);

      expect(buttonSize.width, 200.0);
      expect(faceSize.width, 200.0);
      expect(bevelSize.width, 200.0);
      expect(tester.takeException(), isNull);
    });

    testWidgets('KaunosTactileButton inside Expanded (400px Row) stretches face container and bevel to full width', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 400,
                child: Row(
                  children: [
                    Expanded(
                      child: KaunosTactileButton(
                        onTap: () {},
                        child: const Text('EXPANDED_OK'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );

      final buttonFinder = find.byType(KaunosTactileButton);
      final faceFinder = find.descendant(
        of: find.descendant(of: buttonFinder, matching: find.byType(Padding)),
        matching: find.byType(Container),
      );
      final bevelFinder = find.descendant(
        of: find.descendant(of: buttonFinder, matching: find.byType(Positioned)),
        matching: find.byType(Container),
      );

      final buttonSize = tester.getSize(buttonFinder);
      final faceSize = tester.getSize(faceFinder);
      final bevelSize = tester.getSize(bevelFinder);

      expect(buttonSize.width, 400.0);
      expect(faceSize.width, 400.0);
      expect(bevelSize.width, 400.0);
      expect(tester.takeException(), isNull);
    });

    testWidgets('KaunosTactileButton in unconstrained Row matches intrinsic face and bevel without error', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Row(
              children: [
                KaunosTactileButton(
                  onTap: () {},
                  child: const Text('NATURAL_FIT'),
                ),
              ],
            ),
          ),
        ),
      );

      final buttonFinder = find.byType(KaunosTactileButton);
      final faceFinder = find.descendant(
        of: find.descendant(of: buttonFinder, matching: find.byType(Padding)),
        matching: find.byType(Container),
      );
      final bevelFinder = find.descendant(
        of: find.descendant(of: buttonFinder, matching: find.byType(Positioned)),
        matching: find.byType(Container),
      );

      final buttonSize = tester.getSize(buttonFinder);
      final faceSize = tester.getSize(faceFinder);
      final bevelSize = tester.getSize(bevelFinder);

      expect(faceSize.width, buttonSize.width);
      expect(bevelSize.width, buttonSize.width);
      expect(buttonSize.width, greaterThan(0));
      expect(tester.takeException(), isNull);
    });

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
                  key: const Key('btn'),
                  enabled: isEnabled,
                  onTap: () {},
                  child: const Text('BTN'),
                );
              },
            ),
          ),
        ),
      );

      final gesture = await tester.startGesture(tester.getCenter(find.text('BTN')));
      await tester.pump();

      parentSetState(() => isEnabled = false);
      await tester.pump();

      await gesture.up();
      await tester.pump();

      parentSetState(() => isEnabled = true);
      await tester.pump();

      final padding = tester.widget<Padding>(
        find.descendant(
          of: find.byKey(const Key('btn')),
          matching: find.byWidgetPredicate(
            (w) => w is Padding && w.padding is EdgeInsets && w.child is Container,
          ),
        ),
      );
      expect((padding.padding as EdgeInsets).top, 0.0);
    });
  });

  group('KaunosHeroPlayButton', () {
    testWidgets('KaunosHeroPlayButton renders outer frame and inner trigger', (tester) async {
      bool tapped = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: KaunosHeroPlayButton(
                size: 64.0,
                onTap: () => tapped = true,
              ),
            ),
          ),
        ),
      );

      expect(find.byType(KaunosHeroPlayButton), findsOneWidget);
      expect(find.byType(CustomPaint), findsWidgets);
      expect(tapped, isFalse);

      await tester.tap(find.byType(KaunosHeroPlayButton));
      await tester.pumpAndSettle();

      expect(tapped, isTrue);
    });

    testWidgets('KaunosHeroPlayButton press down and release animation', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: KaunosHeroPlayButton(
                size: 64.0,
                onTap: () {},
              ),
            ),
          ),
        ),
      );

      final gesture = await tester.startGesture(tester.getCenter(find.byType(KaunosHeroPlayButton)));
      await tester.pump();
      await gesture.up();
      await tester.pumpAndSettle();
    });

    test('KaunosPlayChevronPainter repaints only when color changes', () {
      const p1 = KaunosPlayChevronPainter();
      const p2 = KaunosPlayChevronPainter();
      const p3 = KaunosPlayChevronPainter(color: Colors.red);

      expect(p1.shouldRepaint(p2), isFalse);
      expect(p1.shouldRepaint(p3), isTrue);
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
                  key: const Key('hero'),
                  enabled: isEnabled,
                  onTap: () {},
                );
              },
            ),
          ),
        ),
      );

      final gesture = await tester.startGesture(tester.getCenter(find.byKey(const Key('hero'))));
      await tester.pump();

      parentSetState(() => isEnabled = false);
      await tester.pump();

      await gesture.up();
      await tester.pump();

      parentSetState(() => isEnabled = true);
      await tester.pump();

      final trigger = tester.widget<Positioned>(
        find.descendant(
          of: find.byKey(const Key('hero')),
          matching: find.byWidgetPredicate(
            (w) => w is Positioned && w.width == 52.0 && w.height == 52.0,
          ),
        ),
      );
      expect(trigger.top, 5.0);
    });
  });

  group('KaunosEmblem & CustomPainters', () {
    testWidgets('renders all KaunosEmblem variants without exception', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Row(
              children: [
                KaunosEmblem.coin(size: 24),
                KaunosEmblem.pearl(size: 20),
                KaunosEmblem.padlock(size: 18),
                KaunosEmblem.astrolabe(size: 20),
                KaunosEmblem.anvil(size: 20),
                KaunosEmblem.crest(size: 22),
                KaunosEmblem.wheel(size: 20),
              ],
            ),
          ),
        ),
      );

      expect(find.byType(KaunosEmblem), findsNWidgets(7));
    });

    testWidgets('renders generic KaunosEmblem with enum type', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: KaunosEmblem(
              type: KaunosEmblemType.coin,
              size: 32,
              color: Colors.amber,
            ),
          ),
        ),
      );

      expect(find.byType(KaunosEmblem), findsOneWidget);
    });

    test('KaunosEmblemPainter shouldRepaint responds to parameter changes', () {
      const p1 = KaunosEmblemPainter(type: KaunosEmblemType.coin);
      const p2 = KaunosEmblemPainter(type: KaunosEmblemType.coin);
      const p3 = KaunosEmblemPainter(type: KaunosEmblemType.pearl);
      const p4 = KaunosEmblemPainter(type: KaunosEmblemType.coin, color: Colors.blue);

      expect(p1.shouldRepaint(p2), isFalse);
      expect(p1.shouldRepaint(p3), isTrue);
      expect(p1.shouldRepaint(p4), isTrue);
    });
  });

  group('KaunosBadge', () {
    testWidgets('KaunosBadge renders text and lock icon cleanly', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: KaunosBadge.lock(text: 'Bölüm 2'),
            ),
          ),
        ),
      );

      expect(find.text('Bölüm 2'), findsOneWidget);
      expect(find.byType(KaunosBadge), findsOneWidget);
      expect(find.byType(KaunosEmblem), findsOneWidget);
    });

    testWidgets('KaunosBadge handles tight constraints with clean ellipsis', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 80,
              child: KaunosBadge(
                text: 'Çok Uzun Kilit Açıklama Metni',
              ),
            ),
          ),
        ),
      );

      expect(find.byType(KaunosBadge), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('KaunosBadge.lock works inside const widget tree', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(
              child: KaunosBadge.lock(text: 'BÖLÜM 1'),
            ),
          ),
        ),
      );

      expect(find.text('BÖLÜM 1'), findsOneWidget);
      expect(find.byType(KaunosBadge), findsOneWidget);
    });
  });

  group('Layout & Viewport Stress Test', () {
    final testSizes = [
      const Size(300, 700),
      const Size(320, 480),
      const Size(360, 640),
      const Size(390, 844),
    ];

    for (final size in testSizes) {
      testWidgets('Renders Kaunos UI suite at ${size.width}x${size.height} with 1.3x text scaling',
          (tester) async {
        tester.view.physicalSize = Size(size.width * 2.0, size.height * 2.0);
        tester.view.devicePixelRatio = 2.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await tester.pumpWidget(
          MediaQuery(
            data: MediaQueryData(
              size: size,
              textScaler: const TextScaler.linear(1.3),
            ),
            child: MaterialApp(
              home: Scaffold(
                body: SingleChildScrollView(
                  child: Column(
                    children: [
                      KaunosPanel(
                        child: Row(
                          children: [
                            const KaunosEmblem.coin(size: 20),
                            const SizedBox(width: 8),
                            const Expanded(child: Text('Obsidian Crystal Bar')),
                            KaunosBadge.lock(text: 'BÖLÜM 5'),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      KaunosCard(
                        child: Column(
                          children: [
                            const Text('3D Card with Bevel'),
                            const SizedBox(height: 8),
                            KaunosHeroPlayButton(
                              size: 58,
                              onTap: () {},
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: KaunosTactileButton.gold(
                              onTap: () {},
                              child: const Text('OYNA'),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: KaunosTactileButton.jade(
                              onTap: () {},
                              child: const Text('ÖZEL'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );

        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      });
    }
  });

  group('Kaunos Juicy 6-Layer Tactile Feedback Tests', () {
    testWidgets('KaunosTactileButton.highStakes renders and triggers 6-layer feedback', (tester) async {
      bool tapped = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: KaunosTactileButton.highStakes(
                onTap: () => tapped = true,
                child: const Text('KASA AÇ'),
              ),
            ),
          ),
        ),
      );

      expect(find.text('KASA AÇ'), findsOneWidget);

      // Press down (test Layer 1 tilt, Layer 2 compression, Layer 4 haptic pop)
      final center = tester.getCenter(find.text('KASA AÇ'));
      final gesture = await tester.startGesture(center + const Offset(10, 5));
      await tester.pump(const Duration(milliseconds: 50));

      // Release (test Layer 2 elastic snap, Layer 3 neon wave, Layer 5 particle shower, Layer 6 shake)
      await gesture.up();
      await tester.pump(const Duration(milliseconds: 100));
      expect(tapped, isTrue);

      // Settle animations
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });

    testWidgets('KaunosJuicyInteractive wraps arbitrary widgets with full tactile effects', (tester) async {
      bool tapped = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: KaunosJuicyInteractive(
                onTap: () => tapped = true,
                isHighStakes: true,
                child: Container(
                  width: 80,
                  height: 80,
                  color: Colors.blue,
                  child: const Text('TILE'),
                ),
              ),
            ),
          ),
        ),
      );

      expect(find.text('TILE'), findsOneWidget);

      // Tap and animate through elastic snap, shockwave, and particles
      await tester.tap(find.text('TILE'));
      await tester.pump(const Duration(milliseconds: 50));
      expect(tapped, isTrue);

      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  });
}
