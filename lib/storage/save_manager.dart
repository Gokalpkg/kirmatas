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

  // --- KALICI LÜKS YADİGAR (PERMANENT RELIC) ---
  bool hasPermanentRelic = false;

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
  Map<String, int> fishFedTimestamps = {}; // fishId -> epoch ms when 6h cycle started
  static const int fishFedDurationHours = 6;
  static const int fishSatietyDurationHours = 3;
  static const int fishPayoutDurationMs = fishFedDurationHours * 3600 * 1000;
  static const int fishSatietyDurationMs = fishSatietyDurationHours * 3600 * 1000;

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

  int metricSessions = 0;
  String? metricFirstDay;
  String? metricLastDay;
  bool metricDay2 = false;
  int metricLevel1Leaves = 0;
  int metricAdCloses = 0;

  SpeedSetting speed = SpeedSetting.medium;
  bool sfxEnabled = false;
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
    bricksUntilFood = _prefs?.getInt('bricksUntilFood') ?? 8;
    metricSessions = _prefs?.getInt('metricSessions') ?? 0;
    metricFirstDay = _prefs?.getString('metricFirstDay');
    metricLastDay = _prefs?.getString('metricLastDay');
    metricDay2 = _prefs?.getBool('metricDay2') ?? false;
    metricLevel1Leaves = _prefs?.getInt('metricLevel1Leaves') ?? 0;
    metricAdCloses = _prefs?.getInt('metricAdCloses') ?? 0;
    lastFishFedTimestamp = _prefs?.getInt('lastFishFedTimestamp') ?? 0;
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

    final speedIndex = _prefs?.getInt('speedSetting') ?? 1;
    speed = SpeedSetting.values[speedIndex.clamp(0, SpeedSetting.values.length - 1)];

    sfxEnabled = false;
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

    classicSavedLevel = _prefs?.getInt('classicSavedLevel');
    classicSavedScore = _prefs?.getInt('classicSavedScore');
    classicSavedLives = _prefs?.getInt('classicSavedLives');

    chaosSavedLevel = _prefs?.getInt('chaosSavedLevel');
    chaosSavedScore = _prefs?.getInt('chaosSavedScore');
    chaosSavedStock = _prefs?.getInt('chaosSavedStock');

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
  }

  void noteAdClosed() {
    metricAdCloses += 1;
    _prefs?.setInt('metricAdCloses', metricAdCloses);
  }

  void markFirstShotSeen() {
    if (seenFirstShot) return;
    seenFirstShot = true;
    _prefs?.setBool('seenFirstShot', true);
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
