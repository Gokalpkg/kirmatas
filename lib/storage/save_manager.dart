import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/game_state.dart';
import '../models/cosmetics.dart';

class SaveManager extends ChangeNotifier {
  static final SaveManager instance = SaveManager._internal();
  SaveManager._internal();

  SharedPreferences? _prefs;
  bool _initialized = false;

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

  List<String> unlockedFish = ['guppy', 'tetra'];
  int aquariumSand = 1;
  int aquariumMoss = 2;
  int aquariumKelp = 1;
  int aquariumAnubias = 1;

  // --- ECO-TANK FEEDING & PASSIVE GOLD (HAY DAY SYSTEM) ---
  int fishFood = 5;
  int lastFishFedTimestamp = 0; // ms epoch, 0 = hungry
  static const int fishFedDurationHours = 4;

  // --- 7-DAY LOGIN STREAK ---
  String? lastDailyClaimDate;
  int dailyStreak = 1;
  int dailyLoginStreak = 1; // 1 to 7
  String? lastDailyLoginClaimDate;

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

  SpeedSetting speed = SpeedSetting.medium;
  bool sfxEnabled = false;
  bool hapticsEnabled = true;
  HapticIntensity hapticIntensity = HapticIntensity.strong;

  String language = 'en';
  Set<String> unlockedBackgrounds = {'bg_default'};
  String activeBackground = 'bg_default';
  Set<String> unlockedBrickStyles = {'brick_neon'};
  String activeBrickStyle = 'brick_neon';

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
    lastFishFedTimestamp = _prefs?.getInt('lastFishFedTimestamp') ?? 0;

    lastDailyClaimDate = _prefs?.getString('lastDailyClaimDate');
    dailyStreak = _prefs?.getInt('dailyStreak') ?? 1;
    dailyLoginStreak = _prefs?.getInt('dailyLoginStreak') ?? 1;
    lastDailyLoginClaimDate = _prefs?.getString('lastDailyLoginClaimDate');

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

    final speedIndex = _prefs?.getInt('speedSetting') ?? 1;
    speed = SpeedSetting.values[speedIndex.clamp(0, SpeedSetting.values.length - 1)];

    sfxEnabled = false;
    final hIndex = _prefs?.getInt('hapticIntensity') ?? HapticIntensity.strong.index;
    hapticIntensity = HapticIntensity.values[hIndex.clamp(0, HapticIntensity.values.length - 1)];
    hapticsEnabled = hapticIntensity != HapticIntensity.off;

    language = _prefs?.getString('language') ?? 'en';
    unlockedBackgrounds = (_prefs?.getStringList('unlockedBackgrounds') ?? ['bg_default']).toSet();
    activeBackground = _prefs?.getString('activeBackground') ?? 'bg_default';
    unlockedBrickStyles = (_prefs?.getStringList('unlockedBrickStyles') ?? ['brick_neon']).toSet();
    activeBrickStyle = _prefs?.getString('activeBrickStyle') ?? 'brick_neon';
    lastAdWatchTime = _prefs?.getInt('lastAdWatchTime') ?? 0;

    _initialized = true;
    notifyListeners();
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

  Future<void> addFish(String fishId) async {
    unlockedFish.add(fishId);
    await _prefs?.setStringList('unlockedFish', unlockedFish);
    notifyListeners();
  }

  // --- ECO-TANK IDLE PRODUCTION & FEEDING (HAY DAY CYCLE) ---

  /// Total gold produced per hour by all currently unlocked fish
  double get totalFishGoldPerHour {
    double total = 0;
    for (final id in unlockedFish) {
      final fish = FishItem.getById(id);
      switch (fish.rarity) {
        case Rarity.common:
          total += 6.0;
          break;
        case Rarity.rare:
          total += 14.0;
          break;
        case Rarity.epic:
          total += 28.0;
          break;
        case Rarity.legendary:
          total += 60.0;
          break;
      }
    }
    return total;
  }

  /// Milliseconds remaining until the fed session expires
  int get remainingFedDurationMs {
    if (lastFishFedTimestamp <= 0) return 0;
    const maxMs = fishFedDurationHours * 3600 * 1000;
    final elapsed = DateTime.now().millisecondsSinceEpoch - lastFishFedTimestamp;
    final remaining = maxMs - elapsed;
    return remaining > 0 ? remaining : 0;
  }

  bool get isFishFed => remainingFedDurationMs > 0;
  bool get isFishHungry => !isFishFed;

  /// Gold generated during the current fed session
  int get currentAvailableFishGold {
    if (lastFishFedTimestamp <= 0) return 0;
    const maxMs = fishFedDurationHours * 3600 * 1000;
    final elapsed = DateTime.now().millisecondsSinceEpoch - lastFishFedTimestamp;
    final activeMs = elapsed.clamp(0, maxMs);
    final hours = activeMs / (3600.0 * 1000.0);
    return (hours * totalFishGoldPerHour).floor();
  }

  /// Feed the fish: consumes 1 food pellet, starts 4-hour active production
  Future<bool> feedFish() async {
    if (fishFood <= 0) return false;
    // If fish already have uncollected gold, player must harvest first (Hay Day oat/milk rule)
    if (currentAvailableFishGold > 0) return false;

    fishFood--;
    lastFishFedTimestamp = DateTime.now().millisecondsSinceEpoch;
    await _prefs?.setInt('fishFood', fishFood);
    await _prefs?.setInt('lastFishFedTimestamp', lastFishFedTimestamp);

    recordFishFedQuest();
    notifyListeners();
    return true;
  }

  /// Harvest the accumulated gold, resetting fish back to hungry state (Hay Day cycle)
  Future<int> collectFishGold() async {
    final goldToCollect = currentAvailableFishGold;
    if (goldToCollect <= 0) return 0;

    await addGold(goldToCollect);
    // Milk taken: cows are hungry again and need more oats!
    lastFishFedTimestamp = 0;
    await _prefs?.setInt('lastFishFedTimestamp', 0);
    notifyListeners();
    return goldToCollect;
  }

  Future<void> addFishFood(int count) async {
    fishFood += count;
    await _prefs?.setInt('fishFood', fishFood);
    notifyListeners();
  }

  Future<bool> buyFishFoodWithGold({int count = 2, int cost = 80}) async {
    if (gold < cost) return false;
    await spendGold(cost);
    await addFishFood(count);
    return true;
  }

  // --- 7-DAY LOGIN STREAK REWARDS ---

  bool canClaimDaily() => canClaimDailyLogin();

  bool canClaimDailyLogin() {
    final today = DateTime.now().toIso8601String().substring(0, 10);
    return lastDailyLoginClaimDate != today;
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

    int currentDay = dailyLoginStreak;
    if (currentDay < 1 || currentDay > 7) currentDay = 1;

    int baseGold = 50;
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
    if (questId == 'feed_fish' && questFishFed) {
      reward = 60;
      await addFishFood(1);
    } else if (questId == 'break_bricks' && questBricksBroken >= 100) {
      reward = 120;
    } else if (questId == 'ad_or_win' && questAdOrWinDone) {
      reward = 150;
    }

    if (reward > 0) {
      claimedQuests.add(questId);
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
    await _prefs?.setInt('sfxVolume', sfxVolume);
    notifyListeners();
  }

  Future<void> setVibrationLevel(int level) async {
    vibrationLevel = level.clamp(0, 8);
    await _prefs?.setInt('vibrationLevel', vibrationLevel);
    notifyListeners();
  }
}
