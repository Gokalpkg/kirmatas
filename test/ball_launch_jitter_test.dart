import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kirmatas/engine/game_controller.dart';
import 'package:kirmatas/models/game_state.dart';
import 'package:kirmatas/storage/save_manager.dart';
import 'package:kirmatas/ui/game_canvas.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

  Future<GameController> pumpReadyGame(WidgetTester tester) async {
    final ctrl = GameController();
    ctrl.setDimensions(360, 640);
    ctrl.startNewGame(GameMode.classic);
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: GameCanvas(controller: ctrl)),
    ));
    await tester.pump(const Duration(milliseconds: 50));
    return ctrl;
  }

  group('Ball launch from paddle', () {
    testWidgets('Plain tap launches the stuck ball', (tester) async {
      final ctrl = await pumpReadyGame(tester);
      expect(ctrl.hasStuckBall, isTrue);

      await tester.tapAt(const Offset(180, 300));
      await tester.pump(const Duration(milliseconds: 50));

      expect(ctrl.hasStuckBall, isFalse, reason: 'Tap must release the ball');
      expect(ctrl.balls.first.vy, lessThan(0.0), reason: 'Ball must travel upward');
    });

    testWidgets('Tap with finger jitter (<10px travel) still launches the ball', (tester) async {
      final ctrl = await pumpReadyGame(tester);
      expect(ctrl.hasStuckBall, isTrue);

      final gesture = await tester.startGesture(const Offset(180, 300));
      await gesture.moveBy(const Offset(2.0, 1.0));
      await gesture.moveBy(const Offset(-1.0, 0.0));
      await gesture.moveBy(const Offset(3.0, 0.0));
      await gesture.up();
      await tester.pump(const Duration(milliseconds: 50));

      expect(ctrl.hasStuckBall, isFalse, reason: 'Jittery tap must not cancel launch');
    });

    testWidgets('Real drag (>=10px) moves paddle and does NOT launch on release', (tester) async {
      final ctrl = await pumpReadyGame(tester);
      final startX = ctrl.paddle.x;

      final gesture = await tester.startGesture(const Offset(180, 300));
      await gesture.moveBy(const Offset(30.0, 0.0));
      await gesture.up();
      await tester.pump(const Duration(milliseconds: 50));

      expect(ctrl.paddle.x, isNot(startX), reason: 'Paddle must follow drag');
      expect(ctrl.hasStuckBall, isTrue, reason: 'Drag release must not launch');
    });
  });
}
