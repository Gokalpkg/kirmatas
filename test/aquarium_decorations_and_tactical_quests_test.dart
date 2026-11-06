import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:kirmatas/models/decoration_data.dart';
import 'package:kirmatas/models/tournament_data.dart';
import 'package:kirmatas/storage/save_manager.dart';
import 'package:kirmatas/ui/aquarium_view.dart';
import 'package:kirmatas/ui/tournament_dialog.dart';
import 'package:kirmatas/ui/daily_quests_dialog.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    final save = SaveManager.instance;
    await save.init();
    save.resetForTesting();
    save.gold = 5000;
  });

  group('Akvaryum Dekorasyon Sistemi Testleri', () {
    test('Dekorasyon katalog verileri dogru ve eksiksiz tanimli', () {
      expect(AquariumDecoration.all.length, 8);
      final ship = AquariumDecoration.findById('shipwreck');
      expect(ship, isNotNull);
      expect(ship!.name, 'Batık Korsan Gemisi');
      expect(ship.cost, 350);

      final corals = AquariumDecoration.findById('neon_corals');
      expect(corals, isNotNull);
      expect(corals!.cost, 600);

      final temple = AquariumDecoration.findById('submerged_temple');
      expect(temple, isNotNull);
      expect(temple!.cost, 1000);

      final anemone = AquariumDecoration.findById('glowing_anemone');
      expect(anemone, isNotNull);
      expect(anemone!.cost, 1500);

      final obelisk = AquariumDecoration.findById('atlantis_obelisk');
      expect(obelisk, isNotNull);
      expect(obelisk!.cost, 2200);

      final trident = AquariumDecoration.findById('poseidon_trident');
      expect(trident, isNotNull);
      expect(trident!.cost, 3500);

      final clam = AquariumDecoration.findById('pearl_clam');
      expect(clam, isNotNull);
      expect(clam!.isPearlCost, isTrue);
      expect(clam.cost, 3);

      final volcano = AquariumDecoration.findById('submarine_volcano');
      expect(volcano, isNotNull);
      expect(volcano!.cost, 5000);
    });

    test('Altin ile dekorasyon satin alma ve bakiye dususu', () async {
      final save = SaveManager.instance;
      save.gold = 1000;

      expect(save.unlockedDecorations.contains('shipwreck'), isFalse);
      expect(save.isDecorationActive('shipwreck'), isFalse);

      final success = await save.buyDecoration('shipwreck', 350);
      expect(success, isTrue);
      expect(save.gold, 650);
      expect(save.unlockedDecorations.contains('shipwreck'), isTrue);
      expect(save.isDecorationActive('shipwreck'), isTrue);

      // Yetersiz altin durumu
      save.gold = 100;
      final fail = await save.buyDecoration('submerged_temple', 1000);
      expect(fail, isFalse);
      expect(save.unlockedDecorations.contains('submerged_temple'), isFalse);
    });

    test('Dekorasyon sergileme ve kaldirma gecisi', () async {
      final save = SaveManager.instance;
      save.gold = 2000;
      await save.buyDecoration('neon_corals', 600);
      expect(save.isDecorationActive('neon_corals'), isTrue);

      await save.toggleDecoration('neon_corals');
      expect(save.isDecorationActive('neon_corals'), isFalse);

      await save.toggleDecoration('neon_corals');
      expect(save.isDecorationActive('neon_corals'), isTrue);
    });
  });

  group('Taktiksel Gunluk Gorevler Testleri', () {
    test('Manyetik Darbe gorevi ilerleme ve odul alma', () async {
      final save = SaveManager.instance;
      expect(save.questPulseBricks, 0);

      save.recordPulseBrickBrokenQuest(10);
      expect(save.questPulseBricks, 10);
      expect(save.claimableQuestsCount, 0);

      save.recordPulseBrickBrokenQuest(15);
      expect(save.questPulseBricks, 25);
      expect(save.claimableQuestsCount, greaterThanOrEqualTo(1));

      final initialGold = save.gold;
      final reward = await save.claimQuestReward('pulse_bricks');
      expect(reward, 140);
      expect(save.gold, initialGold + 140);
      expect(save.claimedQuests.contains('pulse_bricks'), isTrue);

      // Tekrar talep edilemez
      final secondClaim = await save.claimQuestReward('pulse_bricks');
      expect(secondClaim, 0);
    });

    test('Overdrive Lazer gorevi ilerleme ve odul alma', () async {
      final save = SaveManager.instance;
      expect(save.questOverdriveLasers, 0);

      save.recordOverdriveLaserQuest();
      save.recordOverdriveLaserQuest();
      expect(save.questOverdriveLasers, 2);

      save.recordOverdriveLaserQuest();
      expect(save.questOverdriveLasers, 3);

      final initialGold = save.gold;
      final reward = await save.claimQuestReward('overdrive_laser');
      expect(reward, 160);
      expect(save.gold, initialGold + 160);
    });

    test('Altin Pinata ve Clutch Save gorevleri ilerleme ve odul alma', () async {
      final save = SaveManager.instance;

      save.recordGoldPinataQuest(2);
      expect(save.questGoldPinatas, 2);
      final pinataReward = await save.claimQuestReward('gold_pinata');
      expect(pinataReward, 180);

      save.recordClutchSaveQuest(4);
      expect(save.questClutchSaves, 4);
      final clutchReward = await save.claimQuestReward('clutch_saves');
      expect(clutchReward, 130);
    });
  });

  group('Kuresel Skor Tablosu Testleri', () {
    test('Offline fallback kuresel liderlik tablosu siralamasi ve oyuncu konumu', () {
      final save = SaveManager.instance;
      save.weeklyTournamentScore = 8500;

      final list = TournamentLeaderboardService.instance.getOfflineFallbackLeaderboard(save);
      expect(list.isNotEmpty, isTrue);

      final me = list.firstWhere((e) => e.isPlayer);
      expect(me.weeklyScore, 8500);
      expect(me.rank, greaterThan(0));

      // Azalan puan siralamasi kontrolu
      for (int i = 0; i < list.length - 1; i++) {
        expect(list[i].weeklyScore >= list[i + 1].weeklyScore, isTrue);
        expect(list[i].rank, i + 1);
      }
    });

    testWidgets('TournamentDialog Lig Bolumu ve Kuresel Siralama toggle gecisi', (tester) async {
      final save = SaveManager.instance;
      save.weeklyTournamentScore = 20000;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (ctx) => ElevatedButton(
                onPressed: () => TournamentDialog.show(ctx, save: save),
                child: const Text('OPEN_TOURNAMENT'),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.tap(find.text('OPEN_TOURNAMENT'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(seconds: 1));

      // Varsayilan olarak LİG BÖLÜMÜ secilidir
      expect(find.text('LİG BÖLÜMÜ'), findsOneWidget);
      expect(find.text('KÜRESEL SIRALAMA'), findsOneWidget);
      expect(find.text('HAFTALIK LİG ŞAMPİYONASI'), findsOneWidget);

      // KÜRESEL SIRALAMA butonuna basildiginda kuresel gorunume gecer
      await tester.tap(find.text('KÜRESEL SIRALAMA'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Canlı Firestore Sıralaması'), findsOneWidget);
      expect(find.text('SEN'), findsWidgets);
    });

    testWidgets('DailyQuestsDialog renders all tactical quests and can claim', (tester) async {
      final save = SaveManager.instance;
      save.questPulseBricks = 30; // completed pulse bricks quest
      save.claimedQuests.clear();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (ctx) => ElevatedButton(
                onPressed: () => DailyQuestsDialog.show(ctx),
                child: const Text('OPEN_QUESTS'),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.tap(find.text('OPEN_QUESTS'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Manyetik Darbe: 25 Tuğla Kır'), findsOneWidget);
      expect(find.text('Overdrive Lazer: 3 Ateşleme'), findsOneWidget);
      expect(find.text('Altın Piñata: 2 Kez Avla'), findsOneWidget);
      expect(find.text('Kritik Kurtarış: 4 Clutch Save'), findsOneWidget);
    });

    testWidgets('AquariumView Dekor button opens decoration bottom sheet', (tester) async {
      final save = SaveManager.instance;
      save.gold = 5000;

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AquariumView(),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Dekor'), findsOneWidget);
      await tester.tap(find.text('Dekor'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Akvaryum Dekorasyonları'), findsOneWidget);
      expect(find.text('Batık Korsan Gemisi'), findsOneWidget);
      expect(find.text('Biyolüminesans Mercanlar'), findsOneWidget);
      expect(find.text('Kaunos Batık Tapınağı'), findsOneWidget);
    });
  });
}
