import '../engine/analytics_manager.dart';
import 'dart:convert';
import 'dart:math' as math;
import 'dart:ui' show Color;
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/game_state.dart';
import '../models/cosmetics.dart';

class LeagueRival {
  final String name;
  final int score;
  final bool isPlayer;
  int rank;

  LeagueRival({
    required this.name,
    required this.score,
    required this.isPlayer,
    this.rank = 0,
  });
}

class PendingCrate {
  final String crateType; // 'aquarium', 'category', 'guaranteed'
  final String? crateId;
  final String? category;
  final String rewardType; // 'fish', 'ball', 'paddle', 'trail', 'brick', 'gold'
  final String rewardId;
  final String rewardTitle;
  final String rewardSubtitle;
  final int rarityIndex;
  final bool isDuplicate;
  final bool isShardReward;
  final bool isFoodBonus;
  final int bonusFoodCount;
  final int bonusGoldCount;

  PendingCrate({
    required this.crateType,
    this.crateId,
    this.category,
    required this.rewardType,
    required this.rewardId,
    required this.rewardTitle,
    required this.rewardSubtitle,
    required this.rarityIndex,
    this.isDuplicate = false,
    this.isShardReward = false,
    this.isFoodBonus = false,
    this.bonusFoodCount = 0,
    this.bonusGoldCount = 0,
  });

  Map<String, dynamic> toJson() => {
    'crateType': crateType,
    'crateId': crateId,
    'category': category,
    'rewardType': rewardType,
    'rewardId': rewardId,
    'rewardTitle': rewardTitle,
    'rewardSubtitle': rewardSubtitle,
    'rarityIndex': rarityIndex,
    'isDuplicate': isDuplicate,
    'isShardReward': isShardReward,
    'isFoodBonus': isFoodBonus,
    'bonusFoodCount': bonusFoodCount,
    'bonusGoldCount': bonusGoldCount,
  };

  factory PendingCrate.fromJson(Map<String, dynamic> json) => PendingCrate(
    crateType: json['crateType'] as String? ?? 'aquarium',
    crateId: json['crateId'] as String?,
    category: json['category'] as String?,
    rewardType: json['rewardType'] as String? ?? 'fish',
    rewardId: json['rewardId'] as String? ?? '',
    rewardTitle: json['rewardTitle'] as String? ?? '',
    rewardSubtitle: json['rewardSubtitle'] as String? ?? '',
    rarityIndex: json['rarityIndex'] as int? ?? 0,
    isDuplicate: json['isDuplicate'] as bool? ?? false,
    isShardReward: json['isShardReward'] as bool? ?? false,
    isFoodBonus: json['isFoodBonus'] as bool? ?? false,
    bonusFoodCount: json['bonusFoodCount'] as int? ?? 0,
    bonusGoldCount: json['bonusGoldCount'] as int? ?? 0,
  );
}

class SaveManager extends ChangeNotifier {
  static final SaveManager instance = SaveManager._internal();
  SaveManager._internal();

  SharedPreferences? _prefs;
  bool _initialized = false;
  static const String _kPendingCrate = 'pending_unopened_crate';

  PendingCrate? pendingCrate;

  int gold = 300;
  int sfxVolume = 8;
  int bgmVolume = 3;
  int vibrationLevel = 8;
  Map<String, int> highScores = {
    'classic': 0,
    'zen': 0,
    'descend': 0,
    'daily': 0,
    'chaos': 0,
    'tuft': 0,
  };

  Set<String> unlockedBalls = {'classic'};
  Set<String> unlockedPaddles = {'pclassic'};
  Set<String> unlockedTrails = {'t1'};

  String activeBall = 'classic';
  String activePaddle = 'pclassic';
  String activeTrail = 't1';

  Map<String, int> upgrades = {'battery': 0, 'magnet': 0, 'luck': 0};
  Map<String, int> boostStocks = {'life': 0, 'wide': 0, 'multi': 0};
  Map<String, int> categoryShards = {'balls': 0, 'paddles': 0, 'trails': 0, 'bricks': 0};

  // --- KALICI LÜKS YADİGAR (PERMANENT RELIC) ---
  bool hasPermanentRelic = false;
  bool adsRemoved = false;
  bool removeAdsOfferSeen = false;

  // --- KAYITLI OYUN DEVAM ET (SAVE PROGRESSION - CLASSIC & CHAOS) ---
  int? classicSavedLevel;
  int? classicSavedScore;
  int? classicSavedLives;

  int? chaosSavedLevel;
  int? chaosSavedScore;
  int? chaosSavedStock;

  List<String> unlockedFish = ['guppy', 'tetra'];
  int aquariumSand = 1;
  int aquariumMoss = 2;
  int aquariumKelp = 1;
  int aquariumAnubias = 1;

  // --- ECO-TANK PER-FISH FEEDING & 6-HOUR GOLD PAYOUT ---
  int fishFood = 5;
  int lastFishFedTimestamp = 0;
  String? lastFishFedDay;
  Map<String, int> fishFedTimestamps = {}; // fishId -> epoch ms when 6h cycle started
  static const int fishFedDurationHours = 6;
  static const int fishSatietyDurationHours = 3;
  static const int fishPayoutDurationMs = fishFedDurationHours * 3600 * 1000;
  static const int fishSatietyDurationMs = fishSatietyDurationHours * 3600 * 1000;
  String? lastDailyFishFoodAdDate;

  // --- 7-DAY LOGIN STREAK ---
  String? lastDailyClaimDate;
  int dailyStreak = 1;
  int dailyLoginStreak = 1; // 1 to 7
  String? lastDailyLoginClaimDate;
  String? lastDailyLoginAdClaimDate;
  int dailyLoginClaimedDay = 1;

  // --- FORTUNE WHEEL (3 SPINS PER DAY) ---
  static const int maxDailyWheelSpins = 3;
  String? lastFortuneWheelDate;
  int fortuneWheelSpinsToday = 0;

  // --- DAILY QUESTS ---
  String? currentQuestDate;
  int questBricksBroken = 0;
  bool questFishFed = false;
  bool questAdOrWinDone = false;
  Set<String> claimedQuests = {};

  int lastAdWatchTime = 0;

  bool seenFirstShot = false;
  bool seenFoodLink = false;
  int bricksUntilFood = 8;
  Set<String> seenTips = {};

  int metricSessions = 0;
  String? metricFirstDay;
  String? metricLastDay;
  bool metricDay2 = false;
  int metricLevel1Leaves = 0;
  int metricAdCloses = 0;
  int metricHighestClassicLevel = 1;

  int get highestLevel => metricHighestClassicLevel;
  set highestLevel(int val) {
    metricHighestClassicLevel = val;
    _prefs?.setInt('metricHighestClassicLevel', val);
    notifyListeners();
  }

  int get totalGold => gold;
  set totalGold(int val) {
    gold = val;
    _prefs?.setInt('gold', val);
    notifyListeners();
  }

  bool get isShopUnlocked => highestLevel >= 2 || totalGold >= 100;
  bool get isWorkshopUnlocked => highestLevel >= 3;
  bool get isAquariumUnlocked => highestLevel >= 5;
  bool get isChaosUnlocked => highestLevel >= 5;
  bool get isLeagueUnlocked => highestLevel >= 7;

  // --- R5: COSMIC MASTERY & PEARLS ---
  int _pearls = 0;
  int get pearls => _pearls;
  set pearls(int val) {
    _pearls = val;
    _prefs?.setInt('pearls', val);
    notifyListeners();
  }

  int cosmicGoldMasteryLevel = 0;
  int cosmicPearlMasteryLevel = 0;

  int get cosmicGoldMasteryCost => 1000 + cosmicGoldMasteryLevel * 500;
  int get cosmicPearlMasteryCost => 5 + cosmicPearlMasteryLevel * 3;

  void addPearls(int amount) {
    if (amount <= 0) return;
    pearls += amount;
  }

  bool spendPearls(int amount) {
    if (amount <= 0) return true;
    if (_pearls < amount) return false;
    pearls -= amount;
    return true;
  }

  bool upgradeCosmicGoldMastery() {
    final cost = cosmicGoldMasteryCost;
    if (gold < cost) return false;
    gold -= cost;
    _prefs?.setInt('gold', gold);
    cosmicGoldMasteryLevel++;
    _prefs?.setInt('cosmicGoldMasteryLevel', cosmicGoldMasteryLevel);
    notifyListeners();
    return true;
  }

  bool upgradeCosmicPearlMastery() {
    final cost = cosmicPearlMasteryCost;
    if (_pearls < cost) return false;
    _pearls -= cost;
    _prefs?.setInt('pearls', _pearls);
    cosmicPearlMasteryLevel++;
    _prefs?.setInt('cosmicPearlMasteryLevel', cosmicPearlMasteryLevel);
    notifyListeners();
    return true;
  }

  // --- R6: DAILY BLITZ & PRESTIGE ---
  String? lastDailyBlitzDate;

  static String formatDailyDate(DateTime d) {
    final m = d.month.toString().padLeft(2, '0');
    final day = d.day.toString().padLeft(2, '0');
    return '${d.year}-$m-$day';
  }

  bool get isDailyBlitzCompletedToday {
    final today = formatDailyDate(DateTime.now());
    return lastDailyBlitzDate == today;
  }

  bool claimDailyBlitzReward({DateTime? date}) {
    final d = date ?? DateTime.now();
    final today = formatDailyDate(d);
    if (lastDailyBlitzDate == today) return false;
    lastDailyBlitzDate = today;
    _prefs?.setString('lastDailyBlitzDate', today);
    addGold(250);
    addPearls(3);
    addShard('balls', 1);
    notifyListeners();
    return true;
  }

  int get prestigeTier {
    final lvl = classicSavedLevel ?? metricHighestClassicLevel;
    return lvl > 238 ? ((lvl - 239) ~/ 17) + 1 : 0;
  }

  static int calculatePrestigeTier(int level) => level > 238 ? ((level - 239) ~/ 17) + 1 : 0;

  // --- R7: SEASONAL TITLES & DYNAMIC RIVALS ---
  int _leagueTier = 0;
  int get leagueTier => _leagueTier;
  set leagueTier(int val) {
    _leagueTier = val.clamp(0, 4);
    _prefs?.setInt('leagueTier', _leagueTier);
    notifyListeners();
  }

  void setLeagueTier(int tier) {
    leagueTier = tier;
  }

  int _weeklyTournamentScore = 0;
  int get weeklyTournamentScore => _weeklyTournamentScore;
  set weeklyTournamentScore(int val) {
    _weeklyTournamentScore = val;
    _prefs?.setInt('weeklyTournamentScore', _weeklyTournamentScore);
    notifyListeners();
  }

  void addTournamentScore(int points) {
    if (points <= 0) return;
    weeklyTournamentScore += points;
  }

  void addTournamentPoints(int points) => addTournamentScore(points);

  static const List<String> seasonalTitles = [
    'Çaylak Kırıcı',
    'Neon Avcısı',
    'Plazma Lordu',
    'Elmas Hükümdarı',
    'Kozmik İmparator',
  ];

  String get seasonalTitle => seasonalTitles[leagueTier.clamp(0, seasonalTitles.length - 1)];

  Color get leagueTierColor {
    switch (leagueTier) {
      case 1:
        return const Color(0xFF00E5FF);
      case 2:
        return const Color(0xFFE040FB);
      case 3:
        return const Color(0xFF80D8FF);
      case 4:
        return const Color(0xFFFFD700);
      default:
        return const Color(0xFFCD7F32);
    }
  }

  List<LeagueRival> getLeagueRivals() {
    final rng = math.Random(DateTime.now().year * 100 + DateTime.now().month);
    final rivalNames = [
      'DemirBilek', 'PikselUsta', 'NeonFırtına', 'KozmikGezgin',
      'YıldızAvcısı', 'GlitchKing', 'AuraBreaker', 'GölgeSavaşçı',
      'NovaKıran', 'SiberPence', 'KuvarsGozu', 'EterYolcusu',
      'FotonUstası', 'ZirveBekçisi'
    ];

    final minScores = [600, 2500, 8000, 20000, 50000];
    final maxScores = [2800, 9500, 24000, 55000, 130000];
    final tierIdx = leagueTier.clamp(0, 4);
    final minScore = minScores[tierIdx];
    final maxScore = maxScores[tierIdx];

    final List<LeagueRival> list = [];
    for (int i = 0; i < rivalNames.length; i++) {
      final score = minScore + rng.nextInt(maxScore - minScore);
      list.add(LeagueRival(name: rivalNames[i], score: score, isPlayer: false));
    }

    list.add(LeagueRival(name: 'SEN', score: weeklyTournamentScore, isPlayer: true));
    list.sort((a, b) => b.score.compareTo(a.score));

    for (int i = 0; i < list.length; i++) {
      list[i].rank = i + 1;
    }
    return list;
  }

  bool usedFreeContinue = false;
  String? dayBlessingDate;
  List<String> playEvents = [];

  SpeedSetting speed = SpeedSetting.medium;
  bool sfxEnabled = true;
  bool hapticsEnabled = true;
  HapticIntensity hapticIntensity = HapticIntensity.strong;

  String language = 'tr';
  Set<String> unlockedBackgrounds = {'bg_default'};
  String activeBackground = 'bg_default';
  Set<String> unlockedBrickStyles = {'brick_gloss'};
  String activeBrickStyle = 'brick_gloss';

  Future<void> init() async {
    if (_initialized) return;
    _prefs = await SharedPreferences.getInstance();

    gold = _prefs?.getInt('gold') ?? 300;
    sfxVolume = _prefs?.getInt('sfxVolume') ?? 8;
    bgmVolume = _prefs?.getInt('bgmVolume') ?? 3;
    vibrationLevel = _prefs?.getInt('vibrationLevel') ?? 8;

    final hsStr = _prefs?.getString('highScores');
    if (hsStr != null) {
      try {
        final Map<String, dynamic> decoded = jsonDecode(hsStr);
        highScores = decoded.map((k, v) => MapEntry(k, v as int));
      } catch (_) {}
    }

    unlockedBalls = (_prefs?.getStringList('unlockedBalls') ?? ['classic']).toSet();
    unlockedPaddles = (_prefs?.getStringList('unlockedPaddles') ?? ['pclassic']).toSet();
    unlockedTrails = (_prefs?.getStringList('unlockedTrails') ?? ['t1']).toSet();

    activeBall = _prefs?.getString('activeBall') ?? 'classic';
    activePaddle = _prefs?.getString('activePaddle') ?? 'pclassic';
    activeTrail = _prefs?.getString('activeTrail') ?? 't1';

    final upStr = _prefs?.getString('upgrades');
    if (upStr != null) {
      try {
        final Map<String, dynamic> decoded = jsonDecode(upStr);
        upgrades = decoded.map((k, v) => MapEntry(k, v as int));
      } catch (_) {}
    }

    final boostStr = _prefs?.getString('boostStocks');
    if (boostStr != null) {
      try {
        final Map<String, dynamic> decoded = jsonDecode(boostStr);
        boostStocks = decoded.map((k, v) => MapEntry(k, v as int));
      } catch (_) {}
    }

    final shardsStr = _prefs?.getString('categoryShards');
    if (shardsStr != null) {
      try {
        final Map<String, dynamic> decoded = jsonDecode(shardsStr);
        categoryShards = decoded.map((k, v) => MapEntry(k, v as int));
      } catch (_) {}
    }

    unlockedFish = _prefs?.getStringList('unlockedFish') ?? ['guppy', 'tetra'];
    aquariumSand = _prefs?.getInt('aquariumSand') ?? 1;
    aquariumMoss = _prefs?.getInt('aquariumMoss') ?? 2;
    aquariumKelp = _prefs?.getInt('aquariumKelp') ?? 1;
    aquariumAnubias = _prefs?.getInt('aquariumAnubias') ?? 1;

    fishFood = _prefs?.getInt('fishFood') ?? 5;
    seenFirstShot = _prefs?.getBool('seenFirstShot') ?? false;
    seenFoodLink = _prefs?.getBool('seenFoodLink') ?? false;
    seenTips = (_prefs?.getStringList('seenTips') ?? []).toSet();
    bricksUntilFood = _prefs?.getInt('bricksUntilFood') ?? 8;
    metricSessions = _prefs?.getInt('metricSessions') ?? 0;
    metricFirstDay = _prefs?.getString('metricFirstDay');
    metricLastDay = _prefs?.getString('metricLastDay');
    metricDay2 = _prefs?.getBool('metricDay2') ?? false;
    metricLevel1Leaves = _prefs?.getInt('metricLevel1Leaves') ?? 0;
    metricAdCloses = _prefs?.getInt('metricAdCloses') ?? 0;
    usedFreeContinue = _prefs?.getBool('usedFreeContinue') ?? false;
    dayBlessingDate = _prefs?.getString('dayBlessingDate');
    playEvents = _prefs?.getStringList('playEvents') ?? [];
    lastFishFedTimestamp = _prefs?.getInt('lastFishFedTimestamp') ?? 0;
    lastFishFedDay = _prefs?.getString('lastFishFedDay');
    final fedMapStr = _prefs?.getString('fishFedTimestamps');
    if (fedMapStr != null) {
      try {
        final Map<String, dynamic> decoded = jsonDecode(fedMapStr);
        fishFedTimestamps = decoded.map((k, v) => MapEntry(k, v as int));
      } catch (_) {}
    }

    lastDailyClaimDate = _prefs?.getString('lastDailyClaimDate');
    dailyStreak = _prefs?.getInt('dailyStreak') ?? 1;
    dailyLoginStreak = _prefs?.getInt('dailyLoginStreak') ?? 1;
    lastDailyLoginClaimDate = _prefs?.getString('lastDailyLoginClaimDate');
    lastDailyLoginAdClaimDate = _prefs?.getString('lastDailyLoginAdClaimDate');
    dailyLoginClaimedDay = _prefs?.getInt('dailyLoginClaimedDay') ?? 1;

    lastFortuneWheelDate = _prefs?.getString('lastFortuneWheelDate');
    fortuneWheelSpinsToday = _prefs?.getInt('fortuneWheelSpinsToday') ?? 0;
    final todayStr = DateTime.now().toIso8601String().substring(0, 10);
    if (lastFortuneWheelDate != todayStr) {
      fortuneWheelSpinsToday = 0;
    }

    currentQuestDate = _prefs?.getString('currentQuestDate');
    questBricksBroken = _prefs?.getInt('questBricksBroken') ?? 0;
    questFishFed = _prefs?.getBool('questFishFed') ?? false;
    questAdOrWinDone = _prefs?.getBool('questAdOrWinDone') ?? false;
    claimedQuests = (_prefs?.getStringList('claimedQuests') ?? []).toSet();
    _checkAndResetQuests();

    final speedIndex = _prefs?.getInt('speedSetting') ?? 0;
    speed = SpeedSetting.values[speedIndex.clamp(0, SpeedSetting.values.length - 1)];

    sfxEnabled = _prefs?.getBool('sfxEnabled') ?? true;
    final hIndex = _prefs?.getInt('hapticIntensity') ?? HapticIntensity.strong.index;
    hapticIntensity = HapticIntensity.values[hIndex.clamp(0, HapticIntensity.values.length - 1)];
    hapticsEnabled = hapticIntensity != HapticIntensity.off;

    language = _prefs?.getString('language') ?? 'tr';
    unlockedBackgrounds = (_prefs?.getStringList('unlockedBackgrounds') ?? ['bg_default']).toSet();
    activeBackground = _prefs?.getString('activeBackground') ?? 'bg_default';
    unlockedBrickStyles = (_prefs?.getStringList('unlockedBrickStyles') ?? ['brick_gloss']).toSet();
    activeBrickStyle = _prefs?.getString('activeBrickStyle') ?? 'brick_gloss';
    lastAdWatchTime = _prefs?.getInt('lastAdWatchTime') ?? 0;
    hasPermanentRelic = _prefs?.getBool('hasPermanentRelic') ?? false;
    adsRemoved = _prefs?.getBool('adsRemoved') ?? false;
    removeAdsOfferSeen = _prefs?.getBool('removeAdsOfferSeen') ?? false;

    classicSavedLevel = _prefs?.getInt('classicSavedLevel');
    classicSavedScore = _prefs?.getInt('classicSavedScore');
    classicSavedLives = _prefs?.getInt('classicSavedLives');
    metricHighestClassicLevel = _prefs?.getInt('metricHighestClassicLevel') ?? classicSavedLevel ?? 1;

    chaosSavedLevel = _prefs?.getInt('chaosSavedLevel');
    chaosSavedScore = _prefs?.getInt('chaosSavedScore');
    chaosSavedStock = _prefs?.getInt('chaosSavedStock');
    lastDailyFishFoodAdDate = _prefs?.getString('lastDailyFishFoodAdDate');

    _pearls = _prefs?.getInt('pearls') ?? 0;
    cosmicGoldMasteryLevel = _prefs?.getInt('cosmicGoldMasteryLevel') ?? 0;
    cosmicPearlMasteryLevel = _prefs?.getInt('cosmicPearlMasteryLevel') ?? 0;
    lastDailyBlitzDate = _prefs?.getString('lastDailyBlitzDate');
    _leagueTier = (_prefs?.getInt('leagueTier') ?? 0).clamp(0, 4);
    _weeklyTournamentScore = _prefs?.getInt('weeklyTournamentScore') ?? 0;

    final pendingJson = _prefs?.getString(_kPendingCrate);
    if (pendingJson != null && pendingJson.isNotEmpty) {
      try {
        final Map<String, dynamic> decoded = jsonDecode(pendingJson);
        pendingCrate = PendingCrate.fromJson(decoded);
      } catch (e) {
        debugPrint('Error loading pending crate: $e');
        pendingCrate = null;
      }
    }

    _initialized = true;
    notifyListeners();
  }

  Future<void> savePendingCrate(PendingCrate crate) async {
    pendingCrate = crate;
    await _prefs?.setString(_kPendingCrate, jsonEncode(crate.toJson()));
    notifyListeners();
  }

  Future<void> clearPendingCrate() async {
    pendingCrate = null;
    await _prefs?.remove(_kPendingCrate);
    notifyListeners();
  }

  Future<void> claimPendingCrate() async {
    final crate = pendingCrate;
    if (crate == null) return;

    switch (crate.rewardType) {
      case 'fish':
        await addFish(crate.rewardId);
        if (crate.isFoodBonus && crate.bonusFoodCount > 0) {
          await addFishFood(crate.bonusFoodCount);
        }
        break;
      case 'ball':
        if (crate.isShardReward) {
          await addShard(crate.category ?? 'balls', 1);
        } else {
          await unlockBall(crate.rewardId);
        }
        break;
      case 'paddle':
        if (crate.isShardReward) {
          await addShard(crate.category ?? 'paddles', 1);
        } else {
          await unlockPaddle(crate.rewardId);
        }
        break;
      case 'trail':
        if (crate.isShardReward) {
          await addShard(crate.category ?? 'trails', 1);
        } else {
          await unlockTrail(crate.rewardId);
        }
        break;
      case 'brick':
        if (crate.isShardReward) {
          await addShard(crate.category ?? 'bricks', 1);
        } else {
          await unlockBrickStyle(crate.rewardId);
        }
        break;
      case 'gold':
        if (crate.bonusGoldCount > 0) {
          await addGold(crate.bonusGoldCount);
        }
        break;
    }

    await clearPendingCrate();
  }

  Future<void> setLastAdWatchTime(int time) async {
    lastAdWatchTime = time;
    await _prefs?.setInt('lastAdWatchTime', time);
    notifyListeners();
  }

  Future<void> addGold(int amount) async {
    gold += amount;
    await _prefs?.setInt('gold', gold);
    notifyListeners();
  }

  Future<bool> spendGold(int amount) async {
    if (gold < amount) return false;
    gold -= amount;
    await _prefs?.setInt('gold', gold);
    notifyListeners();
    return true;
  }

  Future<void> updateHighScore(GameMode mode, int score) async {
    final key = mode.name;
    final current = highScores[key] ?? 0;
    if (score > current) {
      highScores[key] = score;
      await _prefs?.setString('highScores', jsonEncode(highScores));
      notifyListeners();
    }
  }

  int getHighScore(GameMode mode) => highScores[mode.name] ?? 0;

  Future<void> unlockBall(String id) async {
    unlockedBalls.add(id);
    await _prefs?.setStringList('unlockedBalls', unlockedBalls.toList());
    notifyListeners();
  }

  Future<void> equipBall(String id) async {
    activeBall = id;
    await _prefs?.setString('activeBall', id);
    notifyListeners();
  }

  Future<void> unlockPaddle(String id) async {
    unlockedPaddles.add(id);
    await _prefs?.setStringList('unlockedPaddles', unlockedPaddles.toList());
    notifyListeners();
  }

  Future<void> equipPaddle(String id) async {
    activePaddle = id;
    await _prefs?.setString('activePaddle', id);
    notifyListeners();
  }

  Future<void> unlockTrail(String id) async {
    unlockedTrails.add(id);
    await _prefs?.setStringList('unlockedTrails', unlockedTrails.toList());
    notifyListeners();
  }

  Future<void> equipTrail(String id) async {
    activeTrail = id;
    await _prefs?.setString('activeTrail', id);
    notifyListeners();
  }

  int getUpgradeLevel(String id) {
    if (id == 'u_crit' || id == 'crit_damage') {
      return math.max(upgrades['u_crit'] ?? 0, upgrades['crit_damage'] ?? 0);
    }
    if (id == 'u_luck' || id == 'luck') {
      return math.max(upgrades['u_luck'] ?? 0, upgrades['luck'] ?? 0);
    }
    if (id == 'u_gold' || id == 'gold_multiplier') {
      return math.max(upgrades['u_gold'] ?? 0, upgrades['gold_multiplier'] ?? 0);
    }
    return upgrades[id] ?? 0;
  }

  Future<bool> buyStatUpgrade(String id, int cost) async {
    final cur = getUpgradeLevel(id);
    if (cur >= 5) return false;
    if (gold < cost) return false;
    final ok = await spendGold(cost);
    if (!ok) return false;
    upgrades[id] = cur + 1;
    await _prefs?.setString('upgrades', jsonEncode(upgrades));
    AnalyticsManager.instance.logStatUpgraded(id, cur + 1);
    notifyListeners();
    return true;
  }

  Future<void> upgradeSkill(String id) async {
    final cur = upgrades[id] ?? 0;
    upgrades[id] = cur + 1;
    await _prefs?.setString('upgrades', jsonEncode(upgrades));
    notifyListeners();
  }

  Future<void> addBoostStock(String id, int count) async {
    final cur = boostStocks[id] ?? 0;
    boostStocks[id] = cur + count;
    await _prefs?.setString('boostStocks', jsonEncode(boostStocks));
    notifyListeners();
  }

  Future<bool> consumeBoost(String id) async {
    final cur = boostStocks[id] ?? 0;
    if (cur <= 0) return false;
    boostStocks[id] = cur - 1;
    await _prefs?.setString('boostStocks', jsonEncode(boostStocks));
    notifyListeners();
    return true;
  }

  int getShards(String category) => categoryShards[category] ?? 0;

  Future<void> addShard(String category, [int count = 1]) async {
    final cur = categoryShards[category] ?? 0;
    categoryShards[category] = cur + count;
    await _prefs?.setString('categoryShards', jsonEncode(categoryShards));
    notifyListeners();
  }

  Future<bool> consumeShards(String category, [int count = 3]) async {
    final cur = categoryShards[category] ?? 0;
    if (cur < count) return false;
    categoryShards[category] = cur - count;
    await _prefs?.setString('categoryShards', jsonEncode(categoryShards));
    notifyListeners();
    return true;
  }

  /// Convert 3 category shards into 2 Pearls
  Future<bool> convertShardsToPearls(String category) async {
    if (getShards(category) < 3) return false;
    final success = await consumeShards(category, 3);
    if (!success) return false;
    addPearls(2);
    return true;
  }

  Future<void> unlockFish(String fishId) async {
    if (!unlockedFish.contains(fishId)) {
      unlockedFish.add(fishId);
      await _prefs?.setStringList('unlockedFish', unlockedFish);
      notifyListeners();
    }
  }

  Future<void> addFish(String fishId) async {
    await unlockFish(fishId);
  }

  /// Spend pearls to directly unlock a fish in Eco-Tank
  Future<bool> buyFishWithPearls(String fishId, int pearlCost) async {
    if (unlockedFish.contains(fishId)) return false;
    if (pearlCost > 0 && !spendPearls(pearlCost)) return false;
    await unlockFish(fishId);
    return true;
  }

  // --- ECO-TANK PER-FISH FEEDING (3H SATIETY & 6H GOLD PAYOUT) ---

  /// Fixed gold reward for a specific fish after 6 hours
  int getFishGoldValue(String fishId) {
    return FishItem.getById(fishId).goldReward;
  }

  /// Total gold reward if all currently unlocked fish are fed
  double get totalFishGoldPerHour {
    double total = 0;
    for (final id in unlockedFish) {
      total += getFishGoldValue(id);
    }
    return total;
  }

  /// Whether this specific fish has an active 6-hour feeding cycle
  bool isFishProducing(String fishId) {
    return (fishFedTimestamps[fishId] ?? 0) > 0;
  }

  /// Whether this specific fish is in its 3-hour satiety cooldown (cannot eat)
  bool isFishInSatietyCooldown(String fishId) {
    final fedAt = fishFedTimestamps[fishId] ?? 0;
    if (fedAt <= 0) return false;
    final elapsed = DateTime.now().millisecondsSinceEpoch - fedAt;
    return elapsed >= 0 && elapsed < fishSatietyDurationMs;
  }

  /// Whether this specific fish has completed its 6-hour cycle and its gold is ready
  bool isFishGoldReady(String fishId) {
    final fedAt = fishFedTimestamps[fishId] ?? 0;
    if (fedAt <= 0) return false;
    final elapsed = DateTime.now().millisecondsSinceEpoch - fedAt;
    return elapsed >= fishPayoutDurationMs;
  }

  /// Milliseconds remaining until this specific fish's 6-hour gold is ready
  int remainingFishPayoutMs(String fishId) {
    final fedAt = fishFedTimestamps[fishId] ?? 0;
    if (fedAt <= 0) return 0;
    final elapsed = DateTime.now().millisecondsSinceEpoch - fedAt;
    final remaining = fishPayoutDurationMs - elapsed;
    return remaining > 0 ? remaining : 0;
  }

  /// Milliseconds remaining in this specific fish's 3-hour satiety cooldown
  int remainingFishSatietyMs(String fishId) {
    final fedAt = fishFedTimestamps[fishId] ?? 0;
    if (fedAt <= 0) return 0;
    final elapsed = DateTime.now().millisecondsSinceEpoch - fedAt;
    final remaining = fishSatietyDurationMs - elapsed;
    return remaining > 0 ? remaining : 0;
  }

  /// Number of fish currently fed (in 6-hour cycle or ready to claim)
  int get fedFishCount {
    int count = 0;
    for (final id in unlockedFish) {
      if (isFishProducing(id)) count++;
    }
    return count;
  }

  /// Total gold that will be earned by all currently fed fish once their 6 hours finish
  int get pendingFishGold {
    int total = 0;
    for (final id in unlockedFish) {
      if (isFishProducing(id)) {
        total += getFishGoldValue(id);
      }
    }
    return total;
  }

  /// Milliseconds remaining until the next fed fish finishes its 6-hour cycle
  int get remainingFedDurationMs {
    int? minRemaining;
    for (final id in unlockedFish) {
      if (isFishProducing(id) && !isFishGoldReady(id)) {
        final rem = remainingFishPayoutMs(id);
        if (rem > 0 && (minRemaining == null || rem < minRemaining)) {
          minRemaining = rem;
        }
      }
    }
    return minRemaining ?? 0;
  }

  bool get isFishFed => fedFishCount > 0;

  /// Never emit hunger warning signals ("Balıklar aç diye sinyal vermesin")
  bool get isFishHungry => false;

  /// Gold ready to be paid out (only from fish that were fed >= 6 hours ago)
  int get currentAvailableFishGold {
    int total = 0;
    for (final id in unlockedFish) {
      if (isFishGoldReady(id)) {
        total += getFishGoldValue(id);
      }
    }
    return total;
  }

  /// Called when a specific fish eats a food pellet.
  /// - If the fish ate within the last 3 hours, it cannot eat (returns false).
  /// - If the fish is not currently in a 6h cycle, starts its 6h gold timer and 3h satiety cooldown.
  /// - If the fish is between 3h and 6h, it eats freely without changing its 6h timer or payout!
  Future<bool> onFishAtePellet(String fishId) async {
    if (isFishInSatietyCooldown(fishId)) {
      return false;
    }

    final existingStart = fishFedTimestamps[fishId] ?? 0;
    if (existingStart <= 0) {
      final now = DateTime.now().millisecondsSinceEpoch;
      fishFedTimestamps[fishId] = now;
      lastFishFedTimestamp = now;
      await _prefs?.setString('fishFedTimestamps', jsonEncode(fishFedTimestamps));
      await _prefs?.setInt('lastFishFedTimestamp', lastFishFedTimestamp);
    }

    recordFishFedQuest();
    final fedDay = DateTime.now().toIso8601String().substring(0, 10);
    if (lastFishFedDay != fedDay) {
      lastFishFedDay = fedDay;
      _prefs?.setString('lastFishFedDay', fedDay);
    }
    notifyListeners();
    return true;
  }

  /// Feeds a single eligible fish (prioritizing unfed fish, then fish past 3h cooldown).
  /// Consumes 1 food pellet. Returns false if no food or all fish are in their 3h satiety window.
  Future<bool> feedFish([String? targetFishId]) async {
    if (fishFood <= 0) return false;

    String? chosenId = targetFishId;
    if (chosenId != null) {
      if (isFishInSatietyCooldown(chosenId)) return false;
    } else {
      // 1st priority: unfed fish
      for (final id in unlockedFish) {
        if (!isFishProducing(id)) {
          chosenId = id;
          break;
        }
      }
      // 2nd priority: fish whose 3-hour satiety cooldown has expired
      if (chosenId == null) {
        for (final id in unlockedFish) {
          if (!isFishInSatietyCooldown(id)) {
            chosenId = id;
            break;
          }
        }
      }
    }

    if (chosenId == null) return false;

    fishFood--;
    await _prefs?.setInt('fishFood', fishFood);
    await onFishAtePellet(chosenId);
    return true;
  }

  /// Pays out all fish that have completed their 6-hour cycle and resets their timers
  Future<int> collectFishGold() async {
    int goldToCollect = 0;
    bool anyCollected = false;

    for (final id in unlockedFish) {
      if (isFishGoldReady(id)) {
        goldToCollect += getFishGoldValue(id);
        fishFedTimestamps.remove(id);
        anyCollected = true;
      }
    }

    if (!anyCollected || goldToCollect <= 0) return 0;

    await addGold(goldToCollect);
    await _prefs?.setString('fishFedTimestamps', jsonEncode(fishFedTimestamps));
    if (fishFedTimestamps.isEmpty) {
      lastFishFedTimestamp = 0;
      await _prefs?.setInt('lastFishFedTimestamp', 0);
    }
    notifyListeners();
    return goldToCollect;
  }

  Future<void> addFishFood(int count) async {
    fishFood += count;
    await _prefs?.setInt('fishFood', fishFood);
    notifyListeners();
  }

  /// First broken brick teaches the aquarium link. After that, every 8th brick drops one pellet.
  /// Drops pause once the pantry is full so the shop still matters.
  String? grantFoodFromBrick() {
    if (fishFood >= 24) return null;
    if (!seenFoodLink) {
      seenFoodLink = true;
      bricksUntilFood = 8;
      fishFood += 1;
      _prefs?.setBool('seenFoodLink', true);
      _prefs?.setInt('bricksUntilFood', bricksUntilFood);
      _prefs?.setInt('fishFood', fishFood);
      notifyListeners();
      return 'food_to_tank';
    }
    bricksUntilFood -= 1;
    if (bricksUntilFood > 0) {
      _prefs?.setInt('bricksUntilFood', bricksUntilFood);
      return null;
    }
    bricksUntilFood = 8;
    fishFood += 1;
    _prefs?.setInt('bricksUntilFood', bricksUntilFood);
    _prefs?.setInt('fishFood', fishFood);
    notifyListeners();
    return 'food_drop';
  }

  void noteAppOpen() {
    final today = DateTime.now().toIso8601String().substring(0, 10);
    metricSessions += 1;
    metricFirstDay ??= today;
    if (metricFirstDay != today) metricDay2 = true;
    metricLastDay = today;
    _prefs?.setInt('metricSessions', metricSessions);
    _prefs?.setString('metricFirstDay', metricFirstDay!);
    _prefs?.setString('metricLastDay', today);
    _prefs?.setBool('metricDay2', metricDay2);
  }

  void noteLevel1Left() {
    metricLevel1Leaves += 1;
    _prefs?.setInt('metricLevel1Leaves', metricLevel1Leaves);
    _notePlayEvent('leave', classicSavedLevel ?? 1);
  }

  void noteAdClosed() {
    metricAdCloses += 1;
    _prefs?.setInt('metricAdCloses', metricAdCloses);
    _notePlayEvent('ad', metricHighestClassicLevel);
  }

  void noteClassicProgress(int level) {
    final stored = _prefs?.getInt('metricHighestClassicLevel');
    if (stored == null) {
      metricHighestClassicLevel = level;
      _prefs?.setInt('metricHighestClassicLevel', level);
      _notePlayEvent('level', level);
      return;
    }
    if (level <= metricHighestClassicLevel) return;
    metricHighestClassicLevel = level;
    _prefs?.setInt('metricHighestClassicLevel', level);
    _notePlayEvent('level', level);
  }

  /// 14 Sektörden kilidi açılmış en yüksek sektör indeksi (1..14)
  int get highestUnlockedSector {
    final highest = metricHighestClassicLevel;
    if (highest < 17) return 1;
    final sec = (highest ~/ 17) + 1;
    return sec.clamp(1, 14);
  }

  /// Belirli bir sektörün kilidi açılmış mı?
  bool isSectorUnlocked(int sectorIndex) {
    if (sectorIndex <= 1) return true;
    return sectorIndex <= highestUnlockedSector;
  }

  /// Sektörün başlangıç checkpoint seviyesini döner
  int getSectorCheckpoint(int sectorIndex) {
    if (sectorIndex <= 1) return 1;
    return (sectorIndex - 1) * 17;
  }

  void markDayBlessed(String day) {
    dayBlessingDate = day;
    _prefs?.setString('dayBlessingDate', day);
  }

  void markFreeContinueUsed() {
    if (usedFreeContinue) return;
    usedFreeContinue = true;
    _prefs?.setBool('usedFreeContinue', true);
  }

  void _notePlayEvent(String kind, int level) {
    final day = DateTime.now().toIso8601String().substring(0, 10);
    playEvents.add('$day|$kind|$level');
    if (playEvents.length > 40) {
      playEvents = playEvents.sublist(playEvents.length - 40);
    }
    _prefs?.setStringList('playEvents', playEvents);
  }

  void markFirstShotSeen() {
    if (seenFirstShot) return;
    seenFirstShot = true;
    _prefs?.setBool('seenFirstShot', true);
  }

  bool hasSeenTip(String tipId) => seenTips.contains(tipId);

  void markTipSeen(String tipId) {
    if (seenTips.add(tipId)) {
      _prefs?.setStringList('seenTips', seenTips.toList());
      notifyListeners();
    }
  }

  bool get hasCompletedMainMenuTour => _prefs?.getBool('hasCompletedMainMenuTour') ?? false;
  set hasCompletedMainMenuTour(bool val) {
    _prefs?.setBool('hasCompletedMainMenuTour', val);
    notifyListeners();
  }

  /// Directly saves fishFood to persistent storage and notifies listeners
  void saveFishFoodDirectly() {
    _prefs?.setInt('fishFood', fishFood);
    notifyListeners();
  }

  /// Consumes 1 food pellet for tap feeding. Returns true if successful.
  bool consumeFishFoodOne() {
    if (fishFood <= 0) return false;
    fishFood--;
    saveFishFoodDirectly();
    return true;
  }

  Future<bool> buyFishFoodWithGold({int count = 2, int cost = 80}) async {
    if (gold < cost) return false;
    await spendGold(cost);
    await addFishFood(count);
    return true;
  }

  bool get canClaimDailyFishFoodAd {
    final today = DateTime.now().toIso8601String().substring(0, 10);
    return lastDailyFishFoodAdDate != today;
  }

  Future<bool> recordDailyFishFoodAdClaimed() async {
    final today = DateTime.now().toIso8601String().substring(0, 10);
    if (lastDailyFishFoodAdDate == today) return false;
    lastDailyFishFoodAdDate = today;
    await _prefs?.setString('lastDailyFishFoodAdDate', today);
    notifyListeners();
    return true;
  }

  // --- 7-DAY LOGIN STREAK REWARDS ---

  bool canClaimDaily() => canClaimDailyLogin();

  bool canClaimDailyLogin() {
    final today = DateTime.now().toIso8601String().substring(0, 10);
    return lastDailyLoginClaimDate != today;
  }

  bool canClaimDailyLoginAd() {
    final today = DateTime.now().toIso8601String().substring(0, 10);
    return lastDailyLoginAdClaimDate != today;
  }

  int get currentDailyLoginDay {
    if (canClaimDailyLogin()) {
      return dailyLoginStreak.clamp(1, 7);
    }
    return dailyLoginClaimedDay.clamp(1, 7);
  }

  int getBaseGoldForDailyDay(int day) {
    switch (day) {
      case 1:
        return 50;
      case 2:
        return 100;
      case 3:
        return 150;
      case 4:
        return 200;
      case 5:
        return 300;
      case 6:
        return 400;
      case 7:
        return 600;
      default:
        return 50;
    }
  }

  Future<int> claimDailyReward() async {
    final result = await claimDailyLoginReward();
    return result['gold'] as int? ?? 0;
  }

  /// Claims today's 7-Day login reward. Supports optional 2X reward on video ad.
  Future<Map<String, dynamic>> claimDailyLoginReward({bool doubleWithAd = false}) async {
    if (!canClaimDailyLogin()) return {'claimed': false};
    final today = DateTime.now().toIso8601String().substring(0, 10);
    lastDailyLoginClaimDate = today;
    lastDailyClaimDate = today;
    await _prefs?.setString('lastDailyLoginClaimDate', today);
    await _prefs?.setString('lastDailyClaimDate', today);

    int currentDay = dailyLoginStreak.clamp(1, 7);
    dailyLoginClaimedDay = currentDay;
    await _prefs?.setInt('dailyLoginClaimedDay', dailyLoginClaimedDay);

    if (doubleWithAd) {
      lastDailyLoginAdClaimDate = today;
      await _prefs?.setString('lastDailyLoginAdClaimDate', today);
    }

    int baseGold = getBaseGoldForDailyDay(currentDay);
    int foodReward = 0;
    String? bonusItem;

    switch (currentDay) {
      case 1:
        baseGold = 50;
        break;
      case 2:
        baseGold = 100;
        foodReward = 2;
        break;
      case 3:
        baseGold = 150;
        bonusItem = 'shard_balls';
        await addShard('balls', 1);
        break;
      case 4:
        baseGold = 200;
        bonusItem = 'boost_life';
        await addBoostStock('life', 1);
        break;
      case 5:
        baseGold = 300;
        bonusItem = 'shard_paddles';
        await addShard('paddles', 1);
        break;
      case 6:
        baseGold = 400;
        foodReward = 3;
        break;
      case 7:
        baseGold = 600;
        bonusItem = 'legendary_shard';
        await addShard('trails', 2);
        break;
    }

    if (foodReward > 0) {
      await addFishFood(foodReward);
    }

    final totalGold = doubleWithAd ? (baseGold * 2) : baseGold;
    await addGold(totalGold);

    dailyStreak++;
    dailyLoginStreak = (currentDay >= 7) ? 1 : (currentDay + 1);
    await _prefs?.setInt('dailyStreak', dailyStreak);
    await _prefs?.setInt('dailyLoginStreak', dailyLoginStreak);

    notifyListeners();
    return {
      'claimed': true,
      'day': currentDay,
      'gold': totalGold,
      'food': foodReward,
      'bonusItem': bonusItem,
      'isDoubled': doubleWithAd,
    };
  }

  /// Claims the 2X ad bonus for today after base reward has ALREADY been collected.
  /// Awards that day's base gold amount ("o gün kaçıncı gündeysek o kadar para versin 2 katını değil").
  Future<Map<String, dynamic>> claimDailyLoginAdBonus() async {
    if (!canClaimDailyLoginAd()) return {'claimed': false};
    final today = DateTime.now().toIso8601String().substring(0, 10);
    lastDailyLoginAdClaimDate = today;
    await _prefs?.setString('lastDailyLoginAdClaimDate', today);

    // If base hasn't been claimed today yet, claim both together
    if (canClaimDailyLogin()) {
      return claimDailyLoginReward(doubleWithAd: true);
    }

    final day = dailyLoginClaimedDay.clamp(1, 7);
    final bonusGold = getBaseGoldForDailyDay(day);
    await addGold(bonusGold);

    notifyListeners();
    return {
      'claimed': true,
      'day': day,
      'gold': bonusGold,
      'isDoubled': true,
    };
  }

  // --- FORTUNE WHEEL (3 SPINS PER DAY) ---

  int get remainingWheelSpins {
    final today = DateTime.now().toIso8601String().substring(0, 10);
    if (lastFortuneWheelDate != today) {
      return maxDailyWheelSpins;
    }
    return (maxDailyWheelSpins - fortuneWheelSpinsToday).clamp(0, maxDailyWheelSpins);
  }

  bool get canSpinFortuneWheel => remainingWheelSpins > 0;

  Future<bool> recordWheelSpin() async {
    final today = DateTime.now().toIso8601String().substring(0, 10);
    if (lastFortuneWheelDate != today) {
      lastFortuneWheelDate = today;
      fortuneWheelSpinsToday = 0;
    }
    if (fortuneWheelSpinsToday >= maxDailyWheelSpins) {
      return false;
    }
    fortuneWheelSpinsToday++;
    await _prefs?.setString('lastFortuneWheelDate', today);
    await _prefs?.setInt('fortuneWheelSpinsToday', fortuneWheelSpinsToday);
    notifyListeners();
    return true;
  }

  // --- DAILY QUESTS ---

  void _checkAndResetQuests() {
    final today = DateTime.now().toIso8601String().substring(0, 10);
    if (currentQuestDate != today) {
      currentQuestDate = today;
      questBricksBroken = 0;
      questFishFed = false;
      questAdOrWinDone = false;
      claimedQuests = {};
      _prefs?.setString('currentQuestDate', today);
      _prefs?.setInt('questBricksBroken', 0);
      _prefs?.setBool('questFishFed', false);
      _prefs?.setBool('questAdOrWinDone', false);
      _prefs?.setStringList('claimedQuests', []);
    }
  }

  void recordBrickBrokenQuest([int count = 1]) {
    _checkAndResetQuests();
    questBricksBroken += count;
    _prefs?.setInt('questBricksBroken', questBricksBroken);
    notifyListeners();
  }

  void recordFishFedQuest() {
    _checkAndResetQuests();
    questFishFed = true;
    _prefs?.setBool('questFishFed', true);
    notifyListeners();
  }

  void recordAdOrWinQuest() {
    _checkAndResetQuests();
    questAdOrWinDone = true;
    _prefs?.setBool('questAdOrWinDone', true);
    notifyListeners();
  }

  Future<int> claimQuestReward(String questId) async {
    _checkAndResetQuests();
    if (claimedQuests.contains(questId)) return 0;
    int reward = 0;
    bool grantFood = false;
    if (questId == 'feed_fish' && questFishFed) {
      reward = 60;
      grantFood = true;
    } else if (questId == 'break_bricks' && questBricksBroken >= 100) {
      reward = 120;
    } else if (questId == 'ad_or_win' && questAdOrWinDone) {
      reward = 150;
    }

    if (reward > 0) {
      // Synchronously register claim before any await to eliminate async gap race conditions
      if (!claimedQuests.add(questId)) return 0;
      if (grantFood) {
        await addFishFood(1);
      }
      await _prefs?.setStringList('claimedQuests', claimedQuests.toList());
      await addGold(reward);
      notifyListeners();
    }
    return reward;
  }

  Future<void> setSpeed(SpeedSetting s) async {
    speed = s;
    await _prefs?.setInt('speedSetting', s.index);
    notifyListeners();
  }

  Future<void> setSfx(bool val) async {
    sfxEnabled = val;
    await _prefs?.setBool('sfxEnabled', val);
    notifyListeners();
  }

  Future<void> setHapticIntensity(HapticIntensity val) async {
    hapticIntensity = val;
    hapticsEnabled = val != HapticIntensity.off;
    await _prefs?.setInt('hapticIntensity', val.index);
    await _prefs?.setBool('hapticsEnabled', hapticsEnabled);
    notifyListeners();
  }

  Future<void> setHaptics(bool val) async {
    hapticsEnabled = val;
    hapticIntensity = val ? HapticIntensity.strong : HapticIntensity.off;
    await _prefs?.setBool('hapticsEnabled', val);
    await _prefs?.setInt('hapticIntensity', hapticIntensity.index);
    notifyListeners();
  }

  Future<void> setLanguage(String lang) async {
    language = lang;
    await _prefs?.setString('language', lang);
    notifyListeners();
  }

  Future<bool> unlockBackground(String id, int cost) async {
    if (unlockedBackgrounds.contains(id)) return true;
    if (cost > 0 && gold < cost) return false;
    await spendGold(cost);
    unlockedBackgrounds.add(id);
    await _prefs?.setStringList('unlockedBackgrounds', unlockedBackgrounds.toList());
    notifyListeners();
    return true;
  }

  Future<void> selectBackground(String id) async {
    if (id == 'random' || unlockedBackgrounds.contains(id)) {
      activeBackground = id;
      await _prefs?.setString('activeBackground', id);
      notifyListeners();
    }
  }

  Future<void> unlockBrickStyle(String id) async {
    unlockedBrickStyles.add(id);
    await _prefs?.setStringList('unlockedBrickStyles', unlockedBrickStyles.toList());
    notifyListeners();
  }

  Future<void> equipBrickStyle(String id) async {
    activeBrickStyle = id;
    await _prefs?.setString('activeBrickStyle', id);
    notifyListeners();
  }

  Future<void> setBgmVolume(int level) async {
    bgmVolume = level.clamp(0, 8);
    await _prefs?.setInt('bgmVolume', bgmVolume);
    notifyListeners();
  }

  Future<void> setSfxVolume(int level) async {
    sfxVolume = level.clamp(0, 8);
    sfxEnabled = sfxVolume > 0;
    await _prefs?.setInt('sfxVolume', sfxVolume);
    await _prefs?.setBool('sfxEnabled', sfxEnabled);
    notifyListeners();
  }

  Future<void> setVibrationLevel(int level) async {
    vibrationLevel = level.clamp(0, 8);
    await _prefs?.setInt('vibrationLevel', vibrationLevel);
    notifyListeners();
  }

  // --- PERMANENT RELIC (KALICI YADİGAR: MİDAS'IN MİKRO ÇEKİMİ) ---
  Future<bool> buyPermanentRelic({int cost = 25000}) async {
    if (hasPermanentRelic) return true;
    if (gold < cost) return false;
    final success = await spendGold(cost);
    if (!success) return false;
    hasPermanentRelic = true;
    await _prefs?.setBool('hasPermanentRelic', true);
    notifyListeners();
    return true;
  }

  bool get shouldOfferRemoveAds =>
      !adsRemoved && !removeAdsOfferSeen && metricHighestClassicLevel >= 100;

  Future<void> grantRemoveAds() async {
    if (adsRemoved) return;
    adsRemoved = true;
    await _prefs?.setBool('adsRemoved', true);
    notifyListeners();
  }

  Future<void> markRemoveAdsOfferSeen() async {
    if (removeAdsOfferSeen) return;
    removeAdsOfferSeen = true;
    await _prefs?.setBool('removeAdsOfferSeen', true);
  }

  // --- SAVED PROGRESSION (DEVAM ET - KLASİK & KAOS) ---
  bool hasSavedGame(GameMode mode) {
    if (mode == GameMode.classic) {
      return (classicSavedLevel != null && classicSavedLevel! > 1) ||
          (classicSavedLevel == 1 && (classicSavedScore ?? 0) > 0);
    } else if (mode == GameMode.chaos) {
      return (chaosSavedLevel != null && chaosSavedLevel! > 1) ||
          (chaosSavedLevel == 1 && (chaosSavedScore ?? 0) > 0);
    }
    return false;
  }

  String get progressCode {
    final level = classicSavedLevel ?? metricHighestClassicLevel;
    return 'KT1|$metricHighestClassicLevel|$level|$gold|$fishFood';
  }

  Future<bool> applyProgressCode(String raw) async {
    final parts = raw.trim().split('|');
    if (parts.length != 5 || parts[0] != 'KT1') return false;
    final highest = int.tryParse(parts[1]);
    final level = int.tryParse(parts[2]);
    final nextGold = int.tryParse(parts[3]);
    final food = int.tryParse(parts[4]);
    if (highest == null || level == null || nextGold == null || food == null) return false;
    if (highest < 1 || highest > 238 || level < 1 || level > 238) return false;
    if (nextGold < 0 || nextGold > 2000000 || food < 0 || food > 99) return false;
    metricHighestClassicLevel = highest;
    gold = nextGold;
    fishFood = food;
    await _prefs?.setInt('metricHighestClassicLevel', highest);
    await _prefs?.setInt('gold', gold);
    await _prefs?.setInt('fishFood', fishFood);
    await saveClassicSession(level: level, score: 0, lives: 3);
    return true;
  }

  Future<void> saveClassicSession({
    required int level,
    required int score,
    required int lives,
  }) async {
    classicSavedLevel = level;
    classicSavedScore = score;
    classicSavedLives = lives;
    await _prefs?.setInt('classicSavedLevel', level);
    await _prefs?.setInt('classicSavedScore', score);
    await _prefs?.setInt('classicSavedLives', lives);
    notifyListeners();
  }

  Future<void> clearClassicSession() async {
    classicSavedLevel = null;
    classicSavedScore = null;
    classicSavedLives = null;
    await _prefs?.remove('classicSavedLevel');
    await _prefs?.remove('classicSavedScore');
    await _prefs?.remove('classicSavedLives');
    notifyListeners();
  }

  Future<void> saveChaosSession({
    required int level,
    required int score,
    required int stock,
  }) async {
    chaosSavedLevel = level;
    chaosSavedScore = score;
    chaosSavedStock = stock;
    await _prefs?.setInt('chaosSavedLevel', level);
    await _prefs?.setInt('chaosSavedScore', score);
    await _prefs?.setInt('chaosSavedStock', stock);
    notifyListeners();
  }

  Future<void> clearChaosSession() async {
    chaosSavedLevel = null;
    chaosSavedScore = null;
    chaosSavedStock = null;
    await _prefs?.remove('chaosSavedLevel');
    await _prefs?.remove('chaosSavedScore');
    await _prefs?.remove('chaosSavedStock');
    notifyListeners();
  }
}
