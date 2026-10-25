import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:kirmatas/storage/save_manager.dart';
import 'package:kirmatas/engine/audio_manager.dart';
import 'package:kirmatas/engine/game_controller.dart';
import 'package:kirmatas/models/game_state.dart';
import 'package:kirmatas/models/cosmetics.dart';
import 'package:kirmatas/models/black_hole.dart';
import 'package:kirmatas/models/easter_egg.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('xyz.luan/audioplayers.global'),
      (MethodCall methodCall) async => 1,
    );
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('xyz.luan/audioplayers'),
      (MethodCall methodCall) async => 1,
    );

    SharedPreferences.setMockInitialValues({});
    await SaveManager.instance.init();
  });

  group('Yetenek Ağacı Sıfırlama ve %100 Altın İadesi (Respec)', () {
    test('calculateTotalSpentOnUpgrades ve resetAllUpgrades kuruşu kuruşuna iade eder', () async {
      final save = SaveManager.instance;
      await save.resetAllUpgrades();
      await save.addGold(50000);

      expect(save.calculateTotalSpentOnUpgrades(), 0);

      // Statları farklı seviyelere yükselt
      // paddle_width lvl 1 cost: 600
      await save.buyStatUpgrade('paddle_width', 600);
      // paddle_width lvl 2 cost: 1500
      await save.buyStatUpgrade('paddle_width', 1500);

      // crit_damage lvl 1 cost: 800
      await save.buyStatUpgrade('crit_damage', 800);

      // magnet lvl 1 cost: 500
      await save.buyStatUpgrade('magnet', 500);

      // Toplam harcanan: 600 + 1500 + 800 + 500 = 3400 Altın
      final totalSpent = save.calculateTotalSpentOnUpgrades();
      expect(totalSpent, equals(3400));

      final goldBeforeRefund = save.gold;
      final refunded = await save.resetAllUpgrades();

      expect(refunded, equals(3400));
      expect(save.gold, equals(goldBeforeRefund + 3400));

      // Tüm seviyeler sıfırlandı mı?
      expect(save.getUpgradeLevel('paddle_width'), equals(0));
      expect(save.getUpgradeLevel('crit_damage'), equals(0));
      expect(save.getUpgradeLevel('magnet'), equals(0));
      expect(save.calculateTotalSpentOnUpgrades(), equals(0));
    });
  });

  group('Ses Mikseri & Bağımsız Kanal Kontrolleri', () {
    test('paddleVolume, ballVolume ve brickVolume kaydedilir ve okunur', () async {
      final save = SaveManager.instance;

      await save.setPaddleVolume(4);
      await save.setBallVolume(2);
      await save.setBrickVolume(0);

      expect(save.paddleVolume, equals(4));
      expect(save.ballVolume, equals(2));
      expect(save.brickVolume, equals(0));

      // Sınır kontrolleri
      await save.setPaddleVolume(10);
      expect(save.paddleVolume, equals(8));

      await save.setBallVolume(-5);
      expect(save.ballVolume, equals(0));
    });

    test('AudioManager hitPaddle skin tınısını doğru ayarlar', () {
      final audio = AudioManager.instance;
      final save = SaveManager.instance;

      // Ateş paddle tonu
      save.activePaddle = 'p_fire';
      audio.playSfx(GameSfx.hitPaddle);
      expect(audio.lastPlaybackRate, closeTo(0.88, 0.01));

      // Buz paddle tonu
      save.activePaddle = 'p_ice';
      audio.playSfx(GameSfx.hitPaddle);
      expect(audio.lastPlaybackRate, closeTo(1.26, 0.01));

      // Klasik paddle tonu
      save.activePaddle = 'pclassic';
      audio.playSfx(GameSfx.hitPaddle);
      expect(audio.lastPlaybackRate, closeTo(1.0, 0.01));
    });
  });

  group('Kozmik Ustalık & Ham Emoji Temizliği', () {
    test('ChaosPerkType ve CosmeticSynergy isimlerinde ham emoji bulunmaz', () {
      final emojiRegex = RegExp(r'[\u{1F300}-\u{1F9FF}\u{2600}-\u{27BF}]', unicode: true);

      for (final perk in ChaosPerkType.values) {
        expect(emojiRegex.hasMatch(perk.titleTr), isFalse,
            reason: '${perk.name} başlığında emoji tespit edildi: ${perk.titleTr}');
      }

      for (final syn in CosmeticSynergy.values) {
        expect(emojiRegex.hasMatch(syn.nameTr), isFalse,
            reason: '${syn.name} başlığında emoji tespit edildi: ${syn.nameTr}');
      }
    });
  });

  group('Arı & Karadelik Sifon Etkileşimi', () {
    test('Büyük karadelik arıyı içine çeker, yutar ve boyutu büyür', () {
      final controller = GameController();
      controller.setDimensions(360, 640);
      controller.startNewGame(GameMode.classic);
      controller.levelTransitionTimer = 0.0;
      controller.status = GameStatus.playing;

      // Karadelik oluştur (yarıçap 18.0 >= 16.0 eşiği)
      final bh = BlackHole(x: 180, y: 200, radius: 18.0, mass: 100);
      controller.blackHoles.add(bh);

      // Arıyı karadeliğin tam yanına koy
      controller.activeBee = EasterEggBee(
        x: 180.0,
        baseY: 205.0,
        vx: 30.0,
        isFacingRight: true,
      );
      expect(controller.activeBee, isNotNull);

      final initialScore = controller.stats.score;
      final initialRadius = bh.radius;

      // 1 frame fizik güncellemesi
      controller.update(0.016);

      // Arı yutuldu mu?
      expect(controller.activeBee, isNull);
      // Karadelik boyutu büyüdü mü?
      expect(bh.radius, greaterThan(initialRadius));
      expect(bh.radius, closeTo(initialRadius * 1.25, 0.01));
      // Skor eklendi mi?
      expect(controller.stats.score, equals(initialScore + 250));
    });
  });
}
