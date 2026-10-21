import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kirmatas/ui/kaunos_ui.dart';

void main() {
  testWidgets('shared reward reveal renders lines and closes via button', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () => showKaunosRewardReveal(
                  context: context,
                  accent: const Color(0xFFF59E0B),
                  headline: 'GÜNLÜK ÖDÜL!',
                  visualBuilder: (_) => const Icon(Icons.card_giftcard_rounded, size: 46),
                  lines: const [
                    KaunosRewardLine(icon: Icons.monetization_on, color: Color(0xFFFFD54F), text: '+150 Altın'),
                    KaunosRewardLine(icon: Icons.set_meal, color: Color(0xFF4FC3F7), text: '+2 Balık Yemi'),
                  ],
                  footnote: 'Seriyi bozma, yarın yine gel!',
                  buttonLabel: 'HARİKA!',
                ),
                child: const Text('aç'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('aç'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));

    expect(find.text('GÜNLÜK ÖDÜL!'), findsOneWidget);
    expect(find.text('+150 Altın'), findsOneWidget);
    expect(find.text('+2 Balık Yemi'), findsOneWidget);
    expect(find.text('HARİKA!'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.tap(find.text('HARİKA!'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    expect(find.text('GÜNLÜK ÖDÜL!'), findsNothing);
    expect(tester.takeException(), isNull);

    // Drain the repeating ray/pulse animation's scheduled frames.
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('spectacle reveal shows the BÜYÜK ÖDÜL badge', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () => showKaunosRewardReveal(
                  context: context,
                  accent: const Color(0xFFE040FB),
                  headline: 'TEBRİKLER!',
                  title: 'KASA',
                  spectacle: true,
                  visualBuilder: (_) => const Icon(Icons.lock_rounded, size: 46),
                  buttonLabel: 'KASAYI AÇ!',
                ),
                child: const Text('aç'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('aç'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));

    expect(find.text('BÜYÜK ÖDÜL'), findsOneWidget);
    expect(find.text('KASA'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.tap(find.text('KASAYI AÇ!'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
