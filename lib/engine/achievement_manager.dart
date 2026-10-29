import 'dart:async';
import 'package:flutter/foundation.dart';

import '../models/game_state.dart';
import '../storage/save_manager.dart';
import 'game_event_bus.dart';
import 'play_games_manager.dart';

/// The type of achievement as per Google Play Games Services specification.
enum AchievementType {
  /// Standard one-step achievement.
  standard,

  /// Incremental multi-step achievement with progress tracking.
  incremental,

  /// Secret achievement whose details and icon are hidden until discovered.
  secret,
}

/// Logical grouping of achievements for display and organization.
enum AchievementCategory {
  firstSteps,
  classicProgress,
  destruction,
  skillAndCombo,
  economyAquarium,
  chaosMode,
  secretDiscoveries,
}

/// Definition model for a Play Games achievement in KIPKIRMATAS.
class AchievementDefinition {
  final String id;
  final String playConsoleId;
  final String name;
  final String description;
  final AchievementType type;
  final AchievementCategory category;
  final int pointValue;
  final int maxSteps;
  final bool isFirstHourFriendly;

  int get xpValue => pointValue * 100;

  const AchievementDefinition({
    required this.id,
    String? playConsoleId,
    required this.name,
    required this.description,
    required this.type,
    required this.category,
    required this.pointValue,
    this.maxSteps = 1,
    this.isFirstHourFriendly = false,
  }) : playConsoleId = playConsoleId ?? id;
}

/// Central manager orchestrating achievement tracking, persistence, and Play Games synchronization.
class AchievementManager extends ChangeNotifier {
  AchievementManager._();
  static final AchievementManager instance = AchievementManager._();

  bool _initialized = false;
  SaveManager? _save;

  /// Complete catalog of all 42 PGS achievements.
  static const List<AchievementDefinition> catalog = [
    // --- Kategori 1: İlk Adımlar (İlk 1 saatte kazanılanlar) ---
    AchievementDefinition(
      id: 'achievement_first_strike',
      playConsoleId: 'CgkIwf_oppkBEAIQBA',
      name: 'İlk Kıvılcım',
      description: 'Herhangi bir oyun modunda ilk tuğlayı kır ve parçala.',
      type: AchievementType.standard,
      category: AchievementCategory.firstSteps,
      pointValue: 10,
      isFirstHourFriendly: true,
    ),
    AchievementDefinition(
      id: 'achievement_first_chest',
      playConsoleId: 'CgkIwf_oppkBEAIQBQ',
      name: 'Kaunos Hazinesi',
      description: 'Oyun içinde gizlenmiş ilk hazine sandığı bloğunu patlat ve ganimeti topla.',
      type: AchievementType.standard,
      category: AchievementCategory.firstSteps,
      pointValue: 10,
      isFirstHourFriendly: true,
    ),
    AchievementDefinition(
      id: 'achievement_first_fish',
      playConsoleId: 'CgkIwf_oppkBEAIQBg',
      name: 'Akvaryumun İlk Sakini',
      description: 'Akvaryumuna ilk süs balığını ekle ve akvaryumunda yüzdür.',
      type: AchievementType.standard,
      category: AchievementCategory.firstSteps,
      pointValue: 10,
      isFirstHourFriendly: true,
    ),
    AchievementDefinition(
      id: 'achievement_combo_starter',
      playConsoleId: 'CgkIwf_oppkBEAIQBw',
      name: 'Ritim Ustası',
      description: 'Topu düşürmeden peş peşe 5 tuğla kırarak 5x kombo serisi yakala.',
      type: AchievementType.standard,
      category: AchievementCategory.firstSteps,
      pointValue: 10,
      isFirstHourFriendly: true,
    ),
    AchievementDefinition(
      id: 'achievement_sector_1_clear',
      playConsoleId: 'CgkIwf_oppkBEAIQCA',
      name: 'Lagün Kaşifi',
      description: 'Klasik modda Sektör 1\'i (Bölüm 1 - 5) başarıyla tamamla.',
      type: AchievementType.standard,
      category: AchievementCategory.firstSteps,
      pointValue: 15,
      isFirstHourFriendly: true,
    ),
    AchievementDefinition(
      id: 'achievement_first_upgrade',
      playConsoleId: 'CgkIwf_oppkBEAIQCQ',
      name: 'Güçlenme',
      description: 'Yetenek Ağacında herhangi bir kalıcı geliştirmeyi altınla aç.',
      type: AchievementType.standard,
      category: AchievementCategory.firstSteps,
      pointValue: 10,
      isFirstHourFriendly: true,
    ),

    // --- Kategori 2: Klasik Mod & Sektörler ---
    AchievementDefinition(
      id: 'achievement_sector_2_clear',
      playConsoleId: 'CgkIwf_oppkBEAIQCg',
      name: 'Mercan Fatihi',
      description: 'Klasik modda Sektör 2\'nin tüm bölümlerini bitir.',
      type: AchievementType.standard,
      category: AchievementCategory.classicProgress,
      pointValue: 20,
    ),
    AchievementDefinition(
      id: 'achievement_sector_3_clear',
      playConsoleId: 'CgkIwf_oppkBEAIQCw',
      name: 'Abis Derinliği',
      description: 'Klasik modda Sektör 3\'ün tüm bölümlerini tamamla.',
      type: AchievementType.standard,
      category: AchievementCategory.classicProgress,
      pointValue: 25,
    ),
    AchievementDefinition(
      id: 'achievement_sector_4_clear',
      playConsoleId: 'CgkIwf_oppkBEAIQDA',
      name: 'Volkanik Basınç',
      description: 'Klasik modda Sektör 4\'ün tüm bölümlerini aş.',
      type: AchievementType.standard,
      category: AchievementCategory.classicProgress,
      pointValue: 30,
    ),
    AchievementDefinition(
      id: 'achievement_sector_5_clear',
      playConsoleId: 'CgkIwf_oppkBEAIQDQ',
      name: 'Kozmik Vorteks',
      description: 'Klasik modda Sektör 5\'in tüm zorlu bölümlerini geç.',
      type: AchievementType.standard,
      category: AchievementCategory.classicProgress,
      pointValue: 50,
    ),
    AchievementDefinition(
      id: 'achievement_boss_hunter',
      playConsoleId: 'CgkIwf_oppkBEAIQDg',
      name: 'Gözcü Avcısı',
      description: 'Klasik modda karşına çıkan ilk boss\'u yenilgiye uğrat.',
      type: AchievementType.standard,
      category: AchievementCategory.classicProgress,
      pointValue: 25,
    ),
    AchievementDefinition(
      id: 'achievement_boss_master',
      playConsoleId: 'CgkIwf_oppkBEAIQDw',
      name: 'Titan Yıkıcı',
      description: 'Klasik modda toplam 5 boss savaşını zaferle bitir.',
      type: AchievementType.standard,
      category: AchievementCategory.classicProgress,
      pointValue: 75,
    ),
    AchievementDefinition(
      id: 'achievement_level_50',
      playConsoleId: 'CgkIwf_oppkBEAIQEA',
      name: 'Yarım Asır',
      description: 'Klasik modda Bölüm 50\'ye ulaşarak galakside iz bırak.',
      type: AchievementType.standard,
      category: AchievementCategory.classicProgress,
      pointValue: 50,
    ),
    AchievementDefinition(
      id: 'achievement_level_100',
      playConsoleId: 'CgkIwf_oppkBEAIQEQ',
      name: 'Kozmosun Zirvesi',
      description: 'Klasik modda Bölüm 100\'e ulaş ve efsanevi ustalığını kanıtla.',
      type: AchievementType.standard,
      category: AchievementCategory.classicProgress,
      pointValue: 120,
    ),
    AchievementDefinition(
      id: 'achievement_prestige_1',
      playConsoleId: 'CgkIwf_oppkBEAIQEg',
      name: 'Yeniden Doğuş',
      description: 'İlk Prestij yükseltmesini yaparak kozmik yolculuğuna yeni bir seviyede başla.',
      type: AchievementType.standard,
      category: AchievementCategory.classicProgress,
      pointValue: 100,
    ),

    // --- Kategori 3: Tuğla & Yıkım Maratonu (Artımlı) ---
    AchievementDefinition(
      id: 'achievement_bricks_500',
      playConsoleId: 'CgkIwf_oppkBEAIQEw',
      name: 'Tuğla Çırağı',
      description: 'Oyun boyunca toplam 500 tuğla kırarak yıkım yolculuğuna başla.',
      type: AchievementType.incremental,
      category: AchievementCategory.destruction,
      pointValue: 15,
      maxSteps: 500,
    ),
    AchievementDefinition(
      id: 'achievement_bricks_2500',
      playConsoleId: 'CgkIwf_oppkBEAIQFA',
      name: 'Kaya Kırıcı',
      description: 'Oyun boyunca toplam 2.500 tuğla kırarak ustalığa yaklaş.',
      type: AchievementType.incremental,
      category: AchievementCategory.destruction,
      pointValue: 30,
      maxSteps: 2500,
    ),
    AchievementDefinition(
      id: 'achievement_bricks_10000',
      playConsoleId: 'CgkIwf_oppkBEAIQFQ',
      name: 'Usta Yıkıcı',
      description: 'Oyun boyunca toplam 10.000 tuğla kırarak gerçek bir kırıcı ol.',
      type: AchievementType.incremental,
      category: AchievementCategory.destruction,
      pointValue: 60,
      maxSteps: 10000,
    ),
    AchievementDefinition(
      id: 'achievement_bricks_50000',
      playConsoleId: 'CgkIwf_oppkBEAIQFg',
      name: 'Kozmik Parçalayıcı',
      description: 'Oyun boyunca toplam 50.000 tuğla kırarak Kaunos efsanesine adını yazdır.',
      type: AchievementType.incremental,
      category: AchievementCategory.destruction,
      pointValue: 150,
      maxSteps: 50000,
    ),

    // --- Kategori 4: Kombo, Fever & Beceri ---
    AchievementDefinition(
      id: 'achievement_combo_15',
      playConsoleId: 'CgkIwf_oppkBEAIQFw',
      name: 'Ateşli Ritim',
      description: 'Tek bir rauntta hiç top kaybetmeden 15x kombo serisine ulaş.',
      type: AchievementType.standard,
      category: AchievementCategory.skillAndCombo,
      pointValue: 20,
    ),
    AchievementDefinition(
      id: 'achievement_combo_30',
      playConsoleId: 'CgkIwf_oppkBEAIQGA',
      name: 'Durdurulamaz Akış',
      description: 'Tek bir rauntta aralıksız vuruşlarla 30x kombo serisi yakala.',
      type: AchievementType.standard,
      category: AchievementCategory.skillAndCombo,
      pointValue: 60,
    ),
    AchievementDefinition(
      id: 'achievement_fever_master',
      playConsoleId: 'CgkIwf_oppkBEAIQGQ',
      name: 'Fever Fırtınası',
      description: 'Fever modunu oyunlar boyunca toplam 25 kez aktif et.',
      type: AchievementType.incremental,
      category: AchievementCategory.skillAndCombo,
      pointValue: 40,
      maxSteps: 25,
    ),
    AchievementDefinition(
      id: 'achievement_corner_strikes',
      playConsoleId: 'CgkIwf_oppkBEAIQGg',
      name: 'Köşe Virtüözü',
      description: 'Paddle\'ın uç kenarlarıyla 50 kez Süper Köşe Vuruşu yap.',
      type: AchievementType.incremental,
      category: AchievementCategory.skillAndCombo,
      pointValue: 35,
      maxSteps: 50,
    ),
    AchievementDefinition(
      id: 'achievement_perfect_round',
      playConsoleId: 'CgkIwf_oppkBEAIQGw',
      name: 'Kusursuz Zafer',
      description: 'Herhangi bir bölümü hiç can kaybetmeden ve darbe almadan bitir.',
      type: AchievementType.standard,
      category: AchievementCategory.skillAndCombo,
      pointValue: 25,
    ),

    // --- Kategori 5: Ekonomi, Sandık & Akvaryum ---
    AchievementDefinition(
      id: 'achievement_gold_10000',
      playConsoleId: 'CgkIwf_oppkBEAIQHA',
      name: 'Kozmik Tüccar',
      description: 'Kariyerin boyunca toplam 10.000 altın topla.',
      type: AchievementType.incremental,
      category: AchievementCategory.economyAquarium,
      pointValue: 25,
      maxSteps: 10000,
    ),
    AchievementDefinition(
      id: 'achievement_gold_50000',
      playConsoleId: 'CgkIwf_oppkBEAIQHQ',
      name: 'Hazine Baronu',
      description: 'Kariyerin boyunca toplam 50.000 altın biriktir.',
      type: AchievementType.incremental,
      category: AchievementCategory.economyAquarium,
      pointValue: 60,
      maxSteps: 50000,
    ),
    AchievementDefinition(
      id: 'achievement_pearl_collector',
      playConsoleId: 'CgkIwf_oppkBEAIQHg',
      name: 'İnci Avcısı',
      description: 'Sandıklardan veya ödüllerden toplam 10 inci kazan.',
      type: AchievementType.incremental,
      category: AchievementCategory.economyAquarium,
      pointValue: 30,
      maxSteps: 10,
    ),
    AchievementDefinition(
      id: 'achievement_aquarium_5_species',
      playConsoleId: 'CgkIwf_oppkBEAIQHw',
      name: 'Denizler İmparatorluğu',
      description: 'Akvaryumunda aynı anda en az 5 farklı balık türünü yüzdür.',
      type: AchievementType.standard,
      category: AchievementCategory.economyAquarium,
      pointValue: 40,
    ),
    AchievementDefinition(
      id: 'achievement_fish_feeder_50',
      playConsoleId: 'CgkIwf_oppkBEAIQIA',
      name: 'Şef Bakıcı',
      description: 'Akvaryumundaki balıkları toplam 50 kez besle.',
      type: AchievementType.incremental,
      category: AchievementCategory.economyAquarium,
      pointValue: 25,
      maxSteps: 50,
    ),
    AchievementDefinition(
      id: 'achievement_wheel_spins_20',
      playConsoleId: 'CgkIwf_oppkBEAIQIQ',
      name: 'Kader Çarkı',
      description: 'Şans Çarkını toplam 20 kez çevir.',
      type: AchievementType.incremental,
      category: AchievementCategory.economyAquarium,
      pointValue: 30,
      maxSteps: 20,
    ),
    AchievementDefinition(
      id: 'achievement_octopus_vault',
      playConsoleId: 'CgkIwf_oppkBEAIQIg',
      name: 'Kraken\'in Sandığı',
      description: 'Ahtapot Kasasını aç ve efsanevi Ahtapotu akvaryumuna ekle.',
      type: AchievementType.standard,
      category: AchievementCategory.economyAquarium,
      pointValue: 75,
    ),
    AchievementDefinition(
      id: 'achievement_skill_tree_max',
      playConsoleId: 'CgkIwf_oppkBEAIQIw',
      name: 'Bilgelik Doruğu',
      description: 'Yetenek Ağacında herhangi bir yükseltmeyi son seviyesine ulaştır.',
      type: AchievementType.standard,
      category: AchievementCategory.economyAquarium,
      pointValue: 45,
    ),

    // --- Kategori 6: Kaos Modu & Sonsuz Hayatta Kalma ---
    AchievementDefinition(
      id: 'achievement_chaos_survivor_1',
      playConsoleId: 'CgkIwf_oppkBEAIQJA',
      name: 'Kaos Kaşifi',
      description: 'Kaos modunda 5. dalgaya ulaşarak hayatta kal.',
      type: AchievementType.standard,
      category: AchievementCategory.chaosMode,
      pointValue: 25,
    ),
    AchievementDefinition(
      id: 'achievement_chaos_survivor_2',
      playConsoleId: 'CgkIwf_oppkBEAIQJQ',
      name: 'Kaos Savaşçısı',
      description: 'Kaos modunda 15. dalgaya ulaşarak yıkıma meydan oku.',
      type: AchievementType.standard,
      category: AchievementCategory.chaosMode,
      pointValue: 50,
    ),
    AchievementDefinition(
      id: 'achievement_chaos_score_100k',
      playConsoleId: 'CgkIwf_oppkBEAIQJg',
      name: 'Kaosun Efendisi',
      description: 'Kaos modunda tek bir koşuda 100.000 puan barajını aş.',
      type: AchievementType.standard,
      category: AchievementCategory.chaosMode,
      pointValue: 75,
    ),

    // --- Kategori 7: Gizli Başarımlar (Secret Achievements) ---
    AchievementDefinition(
      id: 'achievement_secret_blackhole_bee',
      playConsoleId: 'CgkIwf_oppkBEAIQJw',
      name: 'Olay Ufku Şöleni',
      description: 'Kozmik arının bir karadelik tarafından sifon gibi çekilip yutulmasına tanık ol.',
      type: AchievementType.secret,
      category: AchievementCategory.secretDiscoveries,
      pointValue: 60,
    ),
    AchievementDefinition(
      id: 'achievement_secret_miracle_save',
      playConsoleId: 'CgkIwf_oppkBEAIQKA',
      name: 'Mucizevi Sıçrayış',
      description: 'Son topun düşerken Balık Kurtarışı özelliğiyle topu son anda kurtar.',
      type: AchievementType.secret,
      category: AchievementCategory.secretDiscoveries,
      pointValue: 50,
    ),
    AchievementDefinition(
      id: 'achievement_secret_reset_tree',
      playConsoleId: 'CgkIwf_oppkBEAIQKQ',
      name: 'Zamanı Geri Sar',
      description: 'Yetenek Ağacını sıfırla ve harcadığın tüm altınları geri al.',
      type: AchievementType.secret,
      category: AchievementCategory.secretDiscoveries,
      pointValue: 30,
    ),
    AchievementDefinition(
      id: 'achievement_secret_freeze_shatter',
      playConsoleId: 'CgkIwf_oppkBEAIQKg',
      name: 'Buzul Patlaması',
      description: 'Tek bir atışta 8 veya daha fazla donmuş bloğu aynı anda parçala.',
      type: AchievementType.secret,
      category: AchievementCategory.secretDiscoveries,
      pointValue: 40,
    ),
    AchievementDefinition(
      id: 'achievement_secret_super_chest',
      playConsoleId: 'CgkIwf_oppkBEAIQKw',
      name: 'Midas Dokunuşu',
      description: 'Tek bir hazine sandığı bloğundan 100 veya daha fazla altın fışkırt.',
      type: AchievementType.secret,
      category: AchievementCategory.secretDiscoveries,
      pointValue: 30,
    ),
    AchievementDefinition(
      id: 'achievement_secret_night_owl',
      playConsoleId: 'CgkIwf_oppkBEAIQLA',
      name: 'Gece Mesaisi',
      description: 'Gece yarısından sonra (00:00 - 05:00) bir bölümü zaferle tamamla.',
      type: AchievementType.secret,
      category: AchievementCategory.secretDiscoveries,
      pointValue: 25,
    ),
    AchievementDefinition(
      id: 'achievement_secret_speedrunner',
      playConsoleId: 'CgkIwf_oppkBEAIQLQ',
      name: 'Şimşek Hızı',
      description: 'Herhangi bir standart bölümü 20 saniyenin altında tamamla.',
      type: AchievementType.secret,
      category: AchievementCategory.secretDiscoveries,
      pointValue: 40,
    ),
  ];

  static final Map<String, AchievementDefinition> _catalogMap = {
    for (final a in catalog) a.id: a,
  };

  /// Total point value across all achievements (must equal 1,750, leaving 250 reserve for 2,000 max).
  static int get totalPoints => catalog.fold<int>(0, (sum, a) => sum + a.pointValue);

  /// Total XP value across all achievements (100 * totalPoints = 175,000 XP).
  static int get totalXp => totalPoints * 100;

  AchievementDefinition? getById(String id) => _catalogMap[id];

  /// Initializes the manager and retroactively scans stats.
  void init({SaveManager? save}) {
    if (_initialized && save == null) return;
    _save = save ?? SaveManager.instance;
    _initialized = true;

    // Scan lifetime stats in case player already unlocked milestones
    evaluateLifetimeStats(_save!);

    // If Play Games is signed in, sync unlocked achievements to cloud
    PlayGamesManager.instance.addListener(_onPlayGamesStateChanged);
    if (PlayGamesManager.instance.signedIn) {
      syncAllWithPlayGames();
    }
  }

  void _onPlayGamesStateChanged() {
    if (PlayGamesManager.instance.signedIn) {
      syncAllWithPlayGames();
    }
  }

  /// Evaluates existing player progress and unlocks corresponding milestones retroactively.
  void evaluateLifetimeStats(SaveManager save) {
    // Bricks broken milestones
    final bricks = save.statBricksBrokenTotal;
    if (bricks >= 1) unlock('achievement_first_strike');
    if (bricks >= 500) increment('achievement_bricks_500', currentAbsoluteSteps: bricks);
    if (bricks >= 2500) increment('achievement_bricks_2500', currentAbsoluteSteps: bricks);
    if (bricks >= 10000) increment('achievement_bricks_10000', currentAbsoluteSteps: bricks);
    if (bricks >= 50000) increment('achievement_bricks_50000', currentAbsoluteSteps: bricks);

    // Level progression
    final maxLvl = save.highestLevel;
    if (maxLvl > 5) unlock('achievement_sector_1_clear');
    if (maxLvl > 10) unlock('achievement_sector_2_clear');
    if (maxLvl > 15) unlock('achievement_sector_3_clear');
    if (maxLvl > 20) unlock('achievement_sector_4_clear');
    if (maxLvl > 25) unlock('achievement_sector_5_clear');
    if (maxLvl >= 50) unlock('achievement_level_50');
    if (maxLvl >= 100) unlock('achievement_level_100');

    // Prestige
    if (save.prestigeTier > 0 || save.highestLevel > 238) unlock('achievement_prestige_1');

    // Economy & Aquarium
    if (save.statGoldEarnedTotal >= 10000 || save.gold >= 10000) {
      increment('achievement_gold_10000', currentAbsoluteSteps: save.statGoldEarnedTotal > 0 ? save.statGoldEarnedTotal : save.gold);
    }
    if (save.statGoldEarnedTotal >= 50000 || save.gold >= 50000) {
      increment('achievement_gold_50000', currentAbsoluteSteps: save.statGoldEarnedTotal > 0 ? save.statGoldEarnedTotal : save.gold);
    }
    if (save.pearls >= 10) {
      increment('achievement_pearl_collector', currentAbsoluteSteps: save.pearls);
    }
    if (save.unlockedFish.isNotEmpty) {
      unlock('achievement_first_fish');
    }
    if (save.unlockedFish.length >= 5) {
      unlock('achievement_aquarium_5_species');
    }
    if (save.unlockedFish.contains('octopus') || save.ownedFishCounts.containsKey('octopus')) {
      unlock('achievement_octopus_vault');
    }

    // Stats
    if (save.statChestBricksBroken >= 1) unlock('achievement_first_chest');
    if (save.statCornerStrikes > 0) increment('achievement_corner_strikes', currentAbsoluteSteps: save.statCornerStrikes);
    if (save.statFeverCount > 0) increment('achievement_fever_master', currentAbsoluteSteps: save.statFeverCount);
    if (save.statFishFedTotal > 0) increment('achievement_fish_feeder_50', currentAbsoluteSteps: save.statFishFedTotal);
    if (save.statWheelSpins > 0) increment('achievement_wheel_spins_20', currentAbsoluteSteps: save.statWheelSpins);
    if (save.statBossesDefeated >= 1) unlock('achievement_boss_hunter');
    if (save.statBossesDefeated >= 5) unlock('achievement_boss_master');

    // Chaos
    if (save.bestChaosWave >= 5) unlock('achievement_chaos_survivor_1');
    if (save.bestChaosWave >= 15) unlock('achievement_chaos_survivor_2');
    if (save.getHighScore(GameMode.chaos) >= 100000) unlock('achievement_chaos_score_100k');

    // Skill tree
    if (save.upgrades.values.any((lvl) => lvl > 0)) {
      unlock('achievement_first_upgrade');
    }
    if (save.upgrades.values.any((lvl) => lvl >= 5)) {
      unlock('achievement_skill_tree_max');
    }
  }

  /// Unlocks an achievement by ID.
  Future<bool> unlock(String id) async {
    final def = _catalogMap[id];
    if (def == null) return false;
    final save = _save ?? SaveManager.instance;

    if (save.unlockedAchievements.contains(id)) return false;

    // Synchronously register in memory so callers see unlocked state immediately
    save.unlockedAchievements.add(id);
    save.recordAchievementUnlocked(id);

    // Send to Google Play Games Services
    PlayGamesManager.instance.unlockAchievement(def.playConsoleId);

    // Notify in-game listeners & event bus
    GameEventBus().fire(
      AchievementUnlockedEvent(
        achievementId: id,
        name: def.name,
        description: def.description,
        points: def.pointValue,
      ),
    );
    notifyListeners();
    return true;
  }

  /// Increments an incremental achievement.
  Future<void> increment(String id, {int steps = 1, int? currentAbsoluteSteps}) async {
    final def = _catalogMap[id];
    if (def == null || def.type != AchievementType.incremental) return;
    final save = _save ?? SaveManager.instance;

    final currentSteps = currentAbsoluteSteps ?? ((save.achievementSteps[id] ?? 0) + steps);
    save.achievementSteps[id] = currentSteps;
    save.setAchievementSteps(id, currentSteps);

    // Auto-unlock immediately if target reached
    if (currentSteps >= def.maxSteps) {
      unlock(id);
    }

    // Increment on Google Play Games
    if (steps > 0) {
      PlayGamesManager.instance.incrementAchievement(def.playConsoleId, steps: steps);
    }
    notifyListeners();
  }

  /// Synchronizes all currently unlocked achievements and steps with Google Play Games.
  Future<void> syncAllWithPlayGames() async {
    final save = _save ?? SaveManager.instance;
    if (!PlayGamesManager.instance.signedIn) return;

    for (final id in save.unlockedAchievements) {
      final def = _catalogMap[id];
      if (def != null) {
        PlayGamesManager.instance.unlockAchievement(def.playConsoleId);
      }
    }

    for (final entry in save.achievementSteps.entries) {
      final def = _catalogMap[entry.key];
      if (def != null && def.type == AchievementType.incremental && entry.value > 0) {
        PlayGamesManager.instance.incrementAchievement(def.playConsoleId, steps: entry.value);
      }
    }
  }

  // --- Specific Gameplay Event Handlers ---

  void onBrickHit({bool isChest = false, int gold = 0, bool isFrozen = false}) {
    final save = _save ?? SaveManager.instance;
    unlock('achievement_first_strike');
    increment('achievement_bricks_500');
    increment('achievement_bricks_2500');
    increment('achievement_bricks_10000');
    increment('achievement_bricks_50000');

    if (isChest) {
      save.incrementChestBricks();
      unlock('achievement_first_chest');
      if (gold >= 100) {
        unlock('achievement_secret_super_chest');
      }
    }
  }

  void onCombo(int combo) {
    final save = _save ?? SaveManager.instance;
    save.recordMaxCombo(combo);
    if (combo >= 5) unlock('achievement_combo_starter');
    if (combo >= 15) unlock('achievement_combo_15');
    if (combo >= 30) unlock('achievement_combo_30');
  }

  void onFever() {
    final save = _save ?? SaveManager.instance;
    save.incrementFeverCount();
    increment('achievement_fever_master');
  }

  void onCornerStrike() {
    final save = _save ?? SaveManager.instance;
    save.incrementCornerStrikes();
    increment('achievement_corner_strikes');
  }

  void onLevelCompleted({
    required int levelNumber,
    required bool noDamage,
    required double durationSec,
  }) {
    if (noDamage) {
      unlock('achievement_perfect_round');
    }
    if (durationSec > 0 && durationSec <= 20.0) {
      unlock('achievement_secret_speedrunner');
    }

    final now = DateTime.now();
    if (now.hour >= 0 && now.hour < 5) {
      unlock('achievement_secret_night_owl');
    }

    if (levelNumber >= 5) unlock('achievement_sector_1_clear');
    if (levelNumber >= 10) unlock('achievement_sector_2_clear');
    if (levelNumber >= 15) unlock('achievement_sector_3_clear');
    if (levelNumber >= 20) unlock('achievement_sector_4_clear');
    if (levelNumber >= 25) unlock('achievement_sector_5_clear');
    if (levelNumber >= 50) unlock('achievement_level_50');
    if (levelNumber >= 100) unlock('achievement_level_100');
  }

  void onBossDefeated(int bossIndex) {
    final save = _save ?? SaveManager.instance;
    save.incrementBossesDefeated();
    unlock('achievement_boss_hunter');
    if (save.statBossesDefeated >= 5) {
      unlock('achievement_boss_master');
    }
  }

  void onGoldEarned(int amount) {
    final save = _save ?? SaveManager.instance;
    final total = save.statGoldEarnedTotal > 0 ? save.statGoldEarnedTotal : save.gold;
    increment('achievement_gold_10000', steps: amount, currentAbsoluteSteps: total);
    increment('achievement_gold_50000', steps: amount, currentAbsoluteSteps: total);
  }

  void onPearlsEarned(int count) {
    final save = _save ?? SaveManager.instance;
    increment('achievement_pearl_collector', steps: count, currentAbsoluteSteps: save.pearls);
  }

  void onFishAcquired(String fishId) {
    final save = _save ?? SaveManager.instance;
    unlock('achievement_first_fish');
    if (save.unlockedFish.length >= 5) {
      unlock('achievement_aquarium_5_species');
    }
    if (fishId == 'octopus') {
      unlock('achievement_octopus_vault');
    }
  }

  void onFishFed() {
    final save = _save ?? SaveManager.instance;
    save.incrementFishFed();
    increment('achievement_fish_feeder_50');
  }

  void onWheelSpun() {
    final save = _save ?? SaveManager.instance;
    save.incrementWheelSpins();
    increment('achievement_wheel_spins_20');
  }

  void onSkillUpgraded({required String skillId, required int newLevel, required bool isMax}) {
    unlock('achievement_first_upgrade');
    if (isMax || newLevel >= 10) {
      unlock('achievement_skill_tree_max');
    }
  }

  void onSkillTreeReset() {
    unlock('achievement_secret_reset_tree');
  }

  void onPrestige() {
    unlock('achievement_prestige_1');
  }

  void onChaosWave(int wave, int score) {
    if (wave >= 5) unlock('achievement_chaos_survivor_1');
    if (wave >= 15) unlock('achievement_chaos_survivor_2');
    if (score >= 100000) unlock('achievement_chaos_score_100k');
  }

  void onBlackholeSwallowedBee() {
    unlock('achievement_secret_blackhole_bee');
  }

  void onMiracleDolphinSave() {
    unlock('achievement_secret_miracle_save');
  }

  void onFrozenBlocksShattered(int count) {
    if (count >= 8) {
      unlock('achievement_secret_freeze_shatter');
    }
  }
}
