import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kirmatas/storage/save_manager.dart';
import 'package:kirmatas/ui/main_menu.dart';
import 'package:kirmatas/ui/aquarium_view.dart';
import 'package:kirmatas/ui/shop_view.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('KaunosLockedScrollPhysics Unit Tests', () {
    test('Boundary conditions clamp accurately between minPage and maxPage', () {
      const physics = KaunosLockedScrollPhysics(minPage: 0, maxPage: 1);
      final metrics = FixedScrollMetrics(
        minScrollExtent: 0.0,
        maxScrollExtent: 1200.0,
        pixels: 400.0,
        viewportDimension: 400.0,
        axisDirection: AxisDirection.right,
        devicePixelRatio: 1.0,
      );

      // Within allowed range [0, 400]
      expect(physics.applyBoundaryConditions(metrics, 300.0), 0.0);
      expect(physics.applyBoundaryConditions(metrics, 0.0), 0.0);
      expect(physics.applyBoundaryConditions(metrics, 400.0), 0.0);

      // Attempting to scroll past maxPage (towards Aquarium at > 400)
      expect(physics.applyBoundaryConditions(metrics, 450.0), 50.0);
      expect(physics.applyBoundaryConditions(metrics, 800.0), 400.0);

      // Attempting to scroll past minPage (< 0)
      final metricsAtZero = FixedScrollMetrics(
        minScrollExtent: 0.0,
        maxScrollExtent: 1200.0,
        pixels: 0.0,
        viewportDimension: 400.0,
        axisDirection: AxisDirection.right,
        devicePixelRatio: 1.0,
      );
      expect(physics.applyBoundaryConditions(metricsAtZero, -50.0), -50.0);
    });

    test('Equality and hash code test', () {
      const p1 = KaunosLockedScrollPhysics(minPage: 0, maxPage: 1);
      const p2 = KaunosLockedScrollPhysics(minPage: 0, maxPage: 1);
      const p3 = KaunosLockedScrollPhysics(minPage: 1, maxPage: 1);

      expect(p1, equals(p2));
      expect(p1.hashCode, equals(p2.hashCode));
      expect(p1, isNot(equals(p3)));
    });
  });

  group('MainMenu Locked Tabs & Aquarium Protection Widget Tests', () {
    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      await SaveManager.instance.init();
    });

    testWidgets('Fresh Level 1 start with default gold: AquariumView is NOT present, maxPage clamped to 1', (tester) async {
      final save = SaveManager.instance;
      save.highestLevel = 1;
      expect(save.highestLevel, 1);
      expect(save.isAquariumUnlocked, isFalse);

      await tester.pumpWidget(
        const MaterialApp(
          home: MainMenuScreen(),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Verify AquariumView is NOT in the tree
      expect(find.byType(AquariumView), findsNothing);

      // Verify PageView uses KaunosLockedScrollPhysics with maxPage = 1 (cannot scroll to Aquarium)
      final pageViewFinder = find.byType(PageView);
      expect(pageViewFinder, findsOneWidget);
      final PageView pageView = tester.widget(pageViewFinder);
      expect(pageView.physics, isA<KaunosLockedScrollPhysics>());
      final KaunosLockedScrollPhysics physics = pageView.physics as KaunosLockedScrollPhysics;
      expect(physics.maxPage, 1);

      // Drag horizontally to the left (trying to peek right towards Aquarium)
      await tester.drag(pageViewFinder, const Offset(-200, 0));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // AquariumView must still NOT be in the tree
      expect(find.byType(AquariumView), findsNothing);
    });

    testWidgets('Zero gold Level 1: both adjacent tabs locked -> NeverScrollableScrollPhysics', (tester) async {
      final save = SaveManager.instance;
      save.highestLevel = 1;
      save.totalGold = 0;
      expect(save.isShopUnlocked, isFalse);
      expect(save.isAquariumUnlocked, isFalse);

      await tester.pumpWidget(
        const MaterialApp(
          home: MainMenuScreen(),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Verify AquariumView is NOT in the tree
      expect(find.byType(AquariumView), findsNothing);
      expect(find.byType(ShopView), findsNothing);

      // Verify PageView uses NeverScrollableScrollPhysics
      final pageViewFinder = find.byType(PageView);
      expect(pageViewFinder, findsOneWidget);
      final PageView pageView = tester.widget(pageViewFinder);
      expect(pageView.physics, isA<NeverScrollableScrollPhysics>());
    });

    testWidgets('Level 5 reached: user can navigate to AquariumView and it renders properly', (tester) async {
      final save = SaveManager.instance;
      save.highestLevel = 5;
      expect(save.isAquariumUnlocked, isTrue);

      await tester.pumpWidget(
        const MaterialApp(
          home: MainMenuScreen(),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // PageView physics allows scrolling to Aquarium (maxPage >= 2)
      final pageViewFinder = find.byType(PageView);
      final PageView pageView = tester.widget(pageViewFinder);
      expect(pageView.physics, isA<KaunosLockedScrollPhysics>());
      final KaunosLockedScrollPhysics physics = pageView.physics as KaunosLockedScrollPhysics;
      expect(physics.maxPage, greaterThanOrEqualTo(2));

      // Tap the Akvaryum button in bottom dock
      await tester.tap(find.text('AKVARYUM').first);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      // Verify AquariumView IS now mounted and visible
      expect(find.byType(AquariumView), findsOneWidget);
    });
  });
}
